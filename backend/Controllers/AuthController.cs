using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using backend.Data;
using backend.DTOs;
using backend.Models;
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