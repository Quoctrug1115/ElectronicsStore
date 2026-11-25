using System.ComponentModel.DataAnnotations;

namespace backend.DTOs;

public class AdminUserDto
{
    public long Id { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? PhoneNumber { get; set; }
    public bool EmailConfirmed { get; set; }
    public bool IsActive { get; set; }
    public DateTime? LockoutEnd { get; set; }
    public bool IsLocked => !IsActive || (LockoutEnd.HasValue && LockoutEnd > DateTime.UtcNow);
    public string Role { get; set; } = "Member";
    public List<string> Roles { get; set; } = new();
    public DateTime CreatedAt { get; set; }
}

public class ChangeUserRoleRequest
{
    [Required(ErrorMessage = "Vui lòng chọn quyền (Member hoặc Admin).")]
    public string Role { get; set; } = string.Empty;
}

public class UpdateOrderStatusRequest
{
    [Required(ErrorMessage = "Vui lòng truyền trạng thái mới của đơn hàng.")]
    public string Status { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? Note { get; set; }
}

public class AdminOrderListItemDto
{
    public long Id { get; set; }
    public string OrderCode { get; set; } = string.Empty;
    public long UserId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string CustomerEmail { get; set; } = string.Empty;
    public string RecipientName { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public string ShippingAddress { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string PaymentMethod { get; set; } = string.Empty;
    public string PaymentStatus { get; set; } = string.Empty;
    public int TotalQuantity { get; set; }
    public decimal TotalAmount { get; set; }
    public string? FirstProductName { get; set; }
    public string? FirstProductImageUrl { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public class UserOrderSummaryDto
{
    public long Id { get; set; }
    public string OrderCode { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public decimal TotalAmount { get; set; }
    public string PaymentMethod { get; set; } = "COD";
    public string PaymentStatus { get; set; } = "Pending";
    public DateTime CreatedAt { get; set; }
}

/// <summary>Thông tin tài khoản + thống kê hoạt động, dùng cho màn chi tiết người dùng của Admin.</summary>
public class AdminUserDetailDto : AdminUserDto
{
    public int OrderCount { get; set; }

    /// <summary>Tổng tiền các đơn không bị Hủy / Trả hàng.</summary>
    public decimal TotalSpent { get; set; }
    public DateTime? LastOrderAt { get; set; }

    /// <summary>Thời điểm đăng nhập gần nhất (lấy từ thời điểm tạo RefreshToken).</summary>
    public DateTime? LastLoginAt { get; set; }
    public int LoginCount { get; set; }
    public int CartItemCount { get; set; }
    public Dictionary<string, int> OrdersByStatus { get; set; } = new();
    public List<UserOrderSummaryDto> RecentOrders { get; set; } = new();
}

public class DailyRevenueDto
{
    /// <summary>Ngày theo múi giờ của client, định dạng yyyy-MM-dd.</summary>
    public string Date { get; set; } = string.Empty;
    public decimal Revenue { get; set; }
    public int Orders { get; set; }
}

/// <summary>Thống kê doanh thu cho màn Tổng quan của Admin. Doanh thu = tổng tiền các đơn đã giao (Delivered).</summary>
public class RevenueStatsDto
{
    public decimal TotalRevenue { get; set; }
    public int DeliveredOrders { get; set; }
    public decimal TodayRevenue { get; set; }
    public int TodayOrders { get; set; }
    public decimal MonthRevenue { get; set; }
    public int MonthOrders { get; set; }

    /// <summary>Tổng tiền các đơn chưa giao xong (Chờ xác nhận, Đã xác nhận, Đang xử lý, Đang giao): doanh thu dự kiến.</summary>
    public decimal InProgressRevenue { get; set; }
    public int InProgressOrders { get; set; }
    public int CancelledOrders { get; set; }
    public Dictionary<string, int> OrdersByStatus { get; set; } = new();
    public List<DailyRevenueDto> DailyRevenue { get; set; } = new();
}
