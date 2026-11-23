using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using backend.Data;
using backend.DTOs;
using backend.Models;
using Google.Apis.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly ElectronicsStoreContext _context;
    private readonly IConfiguration _configuration;

    public AuthController(ElectronicsStoreContext context, IConfiguration configuration)
    {
        _context = context;
        _configuration = configuration;
    }

    // 1. ĐĂNG KÝ
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        var email = request.Email.Trim().ToLower();

        bool emailExists = await _context.Users
            .AnyAsync(u => u.Email == email && !u.IsDeleted);

        if (emailExists)
            return BadRequest(new { message = "Email này đã được sử dụng." });

        var memberRole = await _context.Roles.FirstOrDefaultAsync(r => r.Name == "Member");
        if (memberRole == null)
            return StatusCode(500, new { message = "Hệ thống chưa khởi tạo Role 'Member'." });

        var user = new User
        {
            FullName = request.FullName.Trim(),
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            PhoneNumber = request.PhoneNumber?.Trim(),
            IsActive = true,
            IsDeleted = false,
            CreatedAt = DateTime.UtcNow
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        _context.UserRoles.Add(new UserRole
        {
            UserId = user.Id,
            RoleId = memberRole.Id
        });
        await _context.SaveChangesAsync();

        var roles = new List<string> { memberRole.Name };
        var authResult = await GenerateAuthResponseAsync(user, roles);

        return Ok(authResult);
    }

    // 2. ĐĂNG NHẬP (Trả về JWT chứa Claim Role)
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        var email = request.Email.Trim().ToLower();

        var user = await _context.Users
            .Include(u => u.UserRoles)
                .ThenInclude(ur => ur.Role)
            .FirstOrDefaultAsync(u => u.Email == email && !u.IsDeleted);

        if (user == null || string.IsNullOrEmpty(user.PasswordHash))
            return Unauthorized(new { message = "Email hoặc mật khẩu không chính xác." });

        if (!user.IsActive)
            return StatusCode(403, new { message = "Tài khoản đã bị vô hiệu hóa." });

        if (user.LockoutEnd.HasValue && user.LockoutEnd > DateTime.UtcNow)
            return StatusCode(403, new { message = $"Tài khoản đang bị khóa đến {user.LockoutEnd:dd/MM/yyyy HH:mm} UTC." });

        bool isPasswordValid = BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash);
        if (!isPasswordValid)
            return Unauthorized(new { message = "Email hoặc mật khẩu không chính xác." });

        var roles = user.UserRoles.Select(ur => ur.Role.Name).ToList();
        var authResult = await GenerateAuthResponseAsync(user, roles);

        return Ok(authResult);
    }

    // 2b. ĐĂNG NHẬP GOOGLE: Flutter gửi idToken, backend xác thực với Google rồi cấp JWT của hệ thống
    [HttpPost("google")]
    public async Task<IActionResult> GoogleLogin([FromBody] GoogleLoginRequest request)
    {
        var clientIds = _configuration.GetSection("Google:ClientIds").Get<string[]>() ?? Array.Empty<string>();
        if (clientIds.Length == 0)
            return StatusCode(500, new { message = "Chưa cấu hình Google:ClientIds." });

        GoogleJsonWebSignature.Payload payload;
        try
        {
            payload = await GoogleJsonWebSignature.ValidateAsync(
                request.IdToken,
                new GoogleJsonWebSignature.ValidationSettings { Audience = clientIds });
        }
        catch (InvalidJwtException)
        {
            return Unauthorized(new { message = "Token Google không hợp lệ hoặc đã hết hạn." });
        }

        if (string.IsNullOrEmpty(payload.Email) || !payload.EmailVerified)
            return BadRequest(new { message = "Email Google chưa được xác minh." });

        var email = payload.Email.Trim().ToLower();

        var user = await _context.Users
            .Include(u => u.UserRoles)
                .ThenInclude(ur => ur.Role)
            .FirstOrDefaultAsync(u => u.Email == email && !u.IsDeleted);

        if (user == null)
        {
            var memberRole = await _context.Roles.FirstOrDefaultAsync(r => r.Name == "Member");
            if (memberRole == null)
                return StatusCode(500, new { message = "Hệ thống chưa khởi tạo Role 'Member'." });

            user = new User
            {
                FullName = string.IsNullOrWhiteSpace(payload.Name) ? email : payload.Name.Trim(),
                Email = email,
                PasswordHash = null, // tài khoản mạng xã hội chưa có mật khẩu
                EmailConfirmed = true,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };
            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            _context.UserRoles.Add(new UserRole { UserId = user.Id, RoleId = memberRole.Id });
            await _context.SaveChangesAsync();

            return Ok(await GenerateAuthResponseAsync(user, new List<string> { memberRole.Name }));
        }
        else
        {
            if (!user.IsActive)
                return StatusCode(403, new { message = "Tài khoản đã bị vô hiệu hóa." });

            if (user.LockoutEnd.HasValue && user.LockoutEnd > DateTime.UtcNow)
                return StatusCode(403, new { message = $"Tài khoản đang bị khóa đến {user.LockoutEnd:dd/MM/yyyy HH:mm} UTC." });

            if (!user.EmailConfirmed)
            {
                user.EmailConfirmed = true; // Google đã xác minh email
                user.UpdatedAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();
            }
        }

        var roles = user.UserRoles.Select(ur => ur.Role.Name).ToList();
        return Ok(await GenerateAuthResponseAsync(user, roles));
    }

    // 2c. ĐĂNG NHẬP ZALO: Flutter (Zalo SDK) gửi access token, backend hỏi Zalo để lấy thông tin người dùng
    [HttpPost("zalo")]
    public async Task<IActionResult> ZaloLogin([FromBody] ZaloLoginRequest request)
    {
        string zaloId;
        string zaloName;
        try
        {
            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
            using var req = new HttpRequestMessage(HttpMethod.Get, "https://graph.zalo.me/v2.0/me?fields=id,name");
            req.Headers.Add("access_token", request.AccessToken);
            using var res = await http.SendAsync(req);
            using var doc = JsonDocument.Parse(await res.Content.ReadAsStringAsync());
            var root = doc.RootElement;

            if (root.TryGetProperty("error", out var err) && err.ValueKind == JsonValueKind.Number && err.GetInt32() != 0)
                return Unauthorized(new { message = "Token Zalo không hợp lệ hoặc đã hết hạn." });
            if (!root.TryGetProperty("id", out var idEl) || string.IsNullOrWhiteSpace(idEl.ToString()))
                return Unauthorized(new { message = "Không lấy được thông tin tài khoản Zalo." });

            zaloId = idEl.ToString();
            zaloName = root.TryGetProperty("name", out var nameEl) ? nameEl.GetString() ?? "" : "";
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
        {
            return StatusCode(502, new { message = "Không kết nối được máy chủ Zalo." });
        }

        // Zalo không trả email -> dùng email giả định danh theo Zalo ID
        var email = $"zalo_{zaloId}@zalo.local";

        var user = await _context.Users
            .Include(u => u.UserRoles)
                .ThenInclude(ur => ur.Role)
            .FirstOrDefaultAsync(u => u.Email == email && !u.IsDeleted);

        if (user == null)
        {
            var memberRole = await _context.Roles.FirstOrDefaultAsync(r => r.Name == "Member");
            if (memberRole == null)
                return StatusCode(500, new { message = "Hệ thống chưa khởi tạo Role 'Member'." });

            user = new User
            {
                FullName = string.IsNullOrWhiteSpace(zaloName) ? $"Zalo {zaloId}" : zaloName.Trim(),
                Email = email,
                PasswordHash = null,
                EmailConfirmed = false,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };
            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            _context.UserRoles.Add(new UserRole { UserId = user.Id, RoleId = memberRole.Id });
            await _context.SaveChangesAsync();

            return Ok(await GenerateAuthResponseAsync(user, new List<string> { memberRole.Name }));
        }

        if (!user.IsActive)
            return StatusCode(403, new { message = "Tài khoản đã bị vô hiệu hóa." });
        if (user.LockoutEnd.HasValue && user.LockoutEnd > DateTime.UtcNow)
            return StatusCode(403, new { message = $"Tài khoản đang bị khóa đến {user.LockoutEnd:dd/MM/yyyy HH:mm} UTC." });

        var roles = user.UserRoles.Select(ur => ur.Role.Name).ToList();
        return Ok(await GenerateAuthResponseAsync(user, roles));
    }

    // 2d. ĐĂNG NHẬP FACEBOOK: xác minh token thuộc đúng app của mình rồi lấy thông tin người dùng
    [HttpPost("facebook")]
    public async Task<IActionResult> FacebookLogin([FromBody] FacebookLoginRequest request)
    {
        var appId = _configuration["Facebook:AppId"];
        var appSecret = _configuration["Facebook:AppSecret"];
        if (string.IsNullOrEmpty(appId) || string.IsNullOrEmpty(appSecret))
            return StatusCode(500, new { message = "Chưa cấu hình Facebook:AppId / Facebook:AppSecret." });

        string fbId;
        string fbName;
        string? fbEmail;
        try
        {
            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };

            // 1) debug_token: chống dùng token của app khác
            var debugUrl = "https://graph.facebook.com/debug_token"
                + $"?input_token={Uri.EscapeDataString(request.AccessToken)}"
                + $"&access_token={Uri.EscapeDataString($"{appId}|{appSecret}")}";
            using (var debugDoc = JsonDocument.Parse(await http.GetStringAsync(debugUrl)))
            {
                if (!debugDoc.RootElement.TryGetProperty("data", out var data)
                    || !data.TryGetProperty("is_valid", out var valid) || !valid.GetBoolean()
                    || data.GetProperty("app_id").ToString() != appId)
                    return Unauthorized(new { message = "Token Facebook không hợp lệ hoặc đã hết hạn." });
            }

            // 2) Lấy thông tin người dùng
            var meUrl = "https://graph.facebook.com/v19.0/me?fields=id,name,email"
                + $"&access_token={Uri.EscapeDataString(request.AccessToken)}";
            using var meDoc = JsonDocument.Parse(await http.GetStringAsync(meUrl));
            var me = meDoc.RootElement;
            fbId = me.GetProperty("id").ToString();
            fbName = me.TryGetProperty("name", out var n) ? n.GetString() ?? "" : "";
            fbEmail = me.TryGetProperty("email", out var e) ? e.GetString() : null;
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException or KeyNotFoundException)
        {
            return Unauthorized(new { message = "Không xác minh được tài khoản Facebook." });
        }

        // Facebook có thể không trả email -> dùng email giả định danh theo Facebook ID
        var email = string.IsNullOrWhiteSpace(fbEmail)
            ? $"fb_{fbId}@facebook.local"
            : fbEmail.Trim().ToLower();

        var user = await _context.Users
            .Include(u => u.UserRoles)
                .ThenInclude(ur => ur.Role)
            .FirstOrDefaultAsync(u => u.Email == email && !u.IsDeleted);

        if (user == null)
        {
            var memberRole = await _context.Roles.FirstOrDefaultAsync(r => r.Name == "Member");
            if (memberRole == null)
                return StatusCode(500, new { message = "Hệ thống chưa khởi tạo Role 'Member'." });

            user = new User
            {
                FullName = string.IsNullOrWhiteSpace(fbName) ? $"Facebook {fbId}" : fbName.Trim(),
                Email = email,
                PasswordHash = null,
                EmailConfirmed = !string.IsNullOrWhiteSpace(fbEmail),
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };
            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            _context.UserRoles.Add(new UserRole { UserId = user.Id, RoleId = memberRole.Id });
            await _context.SaveChangesAsync();

            return Ok(await GenerateAuthResponseAsync(user, new List<string> { memberRole.Name }));
        }

        if (!user.IsActive)
            return StatusCode(403, new { message = "Tài khoản đã bị vô hiệu hóa." });
        if (user.LockoutEnd.HasValue && user.LockoutEnd > DateTime.UtcNow)
            return StatusCode(403, new { message = $"Tài khoản đang bị khóa đến {user.LockoutEnd:dd/MM/yyyy HH:mm} UTC." });

        var roles = user.UserRoles.Select(ur => ur.Role.Name).ToList();
        return Ok(await GenerateAuthResponseAsync(user, roles));
    }

    // 3. ĐỔI MẬT KHẨU
    [Authorize]
    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        var userIdClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!long.TryParse(userIdClaim, out var userId))
            return Unauthorized();

        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId && !u.IsDeleted);
        if (user == null)
            return NotFound(new { message = "Không tìm thấy người dùng." });

        if (string.IsNullOrEmpty(user.PasswordHash))
            return BadRequest(new { message = "Tài khoản đăng nhập mạng xã hội chưa thiết lập mật khẩu." });

        if (!BCrypt.Net.BCrypt.Verify(request.OldPassword, user.PasswordHash))
            return BadRequest(new { message = "Mật khẩu hiện tại không đúng." });

        if (request.OldPassword == request.NewPassword)
            return BadRequest(new { message = "Mật khẩu mới không được trùng mật khẩu cũ." });

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);
        user.UpdatedAt = DateTime.UtcNow;

        // Thu hồi toàn bộ Refresh Token đang hoạt động để buộc đăng nhập lại trên thiết bị khác
        var activeTokens = await _context.RefreshTokens
            .Where(rt => rt.UserId == user.Id && rt.RevokedAt == null && rt.ExpiresAt > DateTime.UtcNow)
            .ToListAsync();

        foreach (var token in activeTokens)
        {
            token.RevokedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();

        return Ok(new { message = "Đổi mật khẩu thành công." });
    }

    // 4. ENDPOINT MẪU KIỂM TRA QUYỀN ADMIN
    [Authorize(Roles = "Admin")]
    [HttpGet("admin-only")]
    public IActionResult AdminOnlyEndpoint()
    {
        var adminEmail = User.FindFirstValue(ClaimTypes.Email);
        return Ok(new
        {
            message = "Xác thực quyền Admin thành công!",
            email = adminEmail
        });
    }

    // --- HÀM HỖ TRỢ SINH JWT + REFRESH TOKEN ---
    private async Task<AuthResponse> GenerateAuthResponseAsync(User user, List<string> roles)
    {
        var secretKey = _configuration["Jwt:Key"]
            ?? throw new KeyNotFoundException("Thiếu cấu hình Jwt:Key");

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Email, user.Email),
            new(ClaimTypes.Name, user.FullName),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        // Gắn từng Role vào Claim để [Authorize(Roles = "...")] hoạt động
        foreach (var role in roles)
        {
            claims.Add(new Claim(ClaimTypes.Role, role));
        }

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var expiresAt = DateTime.UtcNow.AddHours(24);

        var tokenDescriptor = new JwtSecurityToken(
            issuer: _configuration["Jwt:Issuer"],
            audience: _configuration["Jwt:Audience"],
            claims: claims,
            expires: expiresAt,
            signingCredentials: creds
        );

        var accessToken = new JwtSecurityTokenHandler().WriteToken(tokenDescriptor);

        // Sinh Refresh Token lưu xuống bảng RefreshTokens
        var refreshTokenValue = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
        var refreshToken = new RefreshToken
        {
            UserId = user.Id,
            Token = refreshTokenValue,
            ExpiresAt = DateTime.UtcNow.AddDays(7),
            CreatedAt = DateTime.UtcNow
        };

        _context.RefreshTokens.Add(refreshToken);
        await _context.SaveChangesAsync();

        return new AuthResponse
        {
            AccessToken = accessToken,
            RefreshToken = refreshTokenValue,
            ExpiresAt = expiresAt,
            User = new UserInfoDto
            {
                Id = user.Id,
                FullName = user.FullName,
                Email = user.Email,
                PhoneNumber = user.PhoneNumber,
                Roles = roles
            }
        };
    }
}