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