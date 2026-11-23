using System.Security.Claims;
using backend.Data;
using backend.DTOs;
using backend.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

[ApiController]
[Route("api/admin/users")]
[Authorize(Roles = "Admin")]
public class AdminUsersController : ControllerBase
{
    private readonly ElectronicsStoreContext _context;

    public AdminUsersController(ElectronicsStoreContext context)
    {
        _context = context;
    }

    // 1. DANH SÁCH MEMBER / USER (Có tìm kiếm, lọc role & phân trang)
    [HttpGet]
    public async Task<IActionResult> GetUsers(
        [FromQuery] int? page = null,
        [FromQuery] int pageIndex = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] string? search = null,
        [FromQuery] string? role = null,
        [FromQuery] bool? isActive = null)
    {
        int currentPage = page ?? pageIndex;

        var query = _context.Users
            .AsNoTracking()
            .Include(u => u.UserRoles)
                .ThenInclude(ur => ur.Role)
            .Where(u => !u.IsDeleted)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var pattern = $"%{search.Trim()}%";
            query = query.Where(u =>
                EF.Functions.Like(u.FullName, pattern) ||
                EF.Functions.Like(u.Email, pattern) ||
                (u.PhoneNumber != null && EF.Functions.Like(u.PhoneNumber, pattern)));
        }

        if (!string.IsNullOrWhiteSpace(role))
        {
            var normalizedRole = role.Trim();
            query = query.Where(u => u.UserRoles.Any(ur => ur.Role.Name == normalizedRole));
        }

        if (isActive.HasValue)
        {
            query = query.Where(u => u.IsActive == isActive.Value);
        }

        query = query.OrderByDescending(u => u.CreatedAt);

        var pagedUsers = await PagedResult<User>.CreateAsync(query, currentPage, pageSize);

        var result = new PagedResult<AdminUserDto>
        {
            TotalCount = pagedUsers.TotalCount,
            PageIndex = pagedUsers.PageIndex,
            PageSize = pagedUsers.PageSize,
            Items = pagedUsers.Items.Select(u =>
            {
                var roleNames = u.UserRoles.Select(ur => ur.Role.Name).ToList();
                var primaryRole = roleNames.Contains("Admin") ? "Admin" : (roleNames.FirstOrDefault() ?? "Member");

                return new AdminUserDto
                {
                    Id = u.Id,
                    FullName = u.FullName,
                    Email = u.Email,
                    PhoneNumber = u.PhoneNumber,
                    EmailConfirmed = u.EmailConfirmed,
                    IsActive = u.IsActive,
                    LockoutEnd = u.LockoutEnd,
                    Role = primaryRole,
                    Roles = roleNames,
                    CreatedAt = u.CreatedAt
                };
            }).ToList()
        };

        return Ok(result);
    }

    // 2. KHÓA / MỞ KHÓA TÀI KHOẢN
    [HttpPut("{id:long}/toggle-lock")]
    public async Task<IActionResult> ToggleLock(long id)
    {
        if (TryGetCurrentUserId(out var currentAdminId) && currentAdminId == id)
            return BadRequest(new { message = "Không thể tự khóa tài khoản Admin đang đăng nhập." });

        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == id && !u.IsDeleted);
        if (user == null)
            return NotFound(new { message = "Không tìm thấy người dùng." });

        var now = DateTime.UtcNow;
        bool currentlyLocked = !user.IsActive || (user.LockoutEnd.HasValue && user.LockoutEnd > now);

        if (currentlyLocked)
        {
            // Mở khóa tài khoản
            user.IsActive = true;
            user.LockoutEnd = null;
        }
        else
        {
            // Khóa tài khoản & thu hồi toàn bộ RefreshToken đang hiệu lực
            user.IsActive = false;
            user.LockoutEnd = DateTime.UtcNow.AddYears(100);

            var activeTokens = await _context.RefreshTokens
                .Where(rt => rt.UserId == user.Id && rt.RevokedAt == null && rt.ExpiresAt > now)
                .ToListAsync();

            foreach (var token in activeTokens)
            {
                token.RevokedAt = now;
            }
        }

        user.UpdatedAt = now;
        await _context.SaveChangesAsync();

        bool isLockedNow = !user.IsActive;
        return Ok(new
        {
            message = isLockedNow ? "Đã khóa tài khoản thành công." : "Đã mở khóa tài khoản thành công.",
            userId = user.Id,
            isActive = user.IsActive,
            isLocked = isLockedNow
        });
    }

    // 3. ĐỔI ROLE (Member <-> Admin)
    [HttpPut("{id:long}/role")]
    public async Task<IActionResult> ChangeRole(long id, [FromBody] ChangeUserRoleRequest request)
    {
        var targetRoleName = request.Role.Trim();
        if (!targetRoleName.Equals("Member", StringComparison.OrdinalIgnoreCase) &&
            !targetRoleName.Equals("Admin", StringComparison.OrdinalIgnoreCase))
        {
            return BadRequest(new { message = "Role không hợp lệ. Chỉ chấp nhận 'Member' hoặc 'Admin'." });
        }

        // Chuẩn hóa đúng chữ hoa/thường theo bảng Roles
        targetRoleName = targetRoleName.Equals("Admin", StringComparison.OrdinalIgnoreCase) ? "Admin" : "Member";

        if (TryGetCurrentUserId(out var currentAdminId) && currentAdminId == id && targetRoleName != "Admin")
            return BadRequest(new { message = "Không thể tự hạ quyền Admin của chính mình." });

        var user = await _context.Users
            .Include(u => u.UserRoles)
            .FirstOrDefaultAsync(u => u.Id == id && !u.IsDeleted);

        if (user == null)
            return NotFound(new { message = "Không tìm thấy người dùng." });

        var targetRole = await _context.Roles.FirstOrDefaultAsync(r => r.Name == targetRoleName);
        if (targetRole == null)
            return StatusCode(500, new { message = $"Hệ thống chưa khởi tạo Role '{targetRoleName}'." });

        // Xóa role cũ và gán role mới trong bảng trung gian UserRoles
        _context.UserRoles.RemoveRange(user.UserRoles);
        _context.UserRoles.Add(new UserRole
        {
            UserId = user.Id,
            RoleId = targetRole.Id
        });

        user.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = $"Đã cập nhật quyền người dùng thành '{targetRole.Name}'.",
            userId = user.Id,
            role = targetRole.Name
        });
    }

    private bool TryGetCurrentUserId(out long userId)
    {
        var claimValue = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return long.TryParse(claimValue, out userId);
    }
}