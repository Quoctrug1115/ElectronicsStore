using System.ComponentModel.DataAnnotations;

namespace backend.DTOs;

public class CheckoutRequest
{
    [Required(ErrorMessage = "Vui lòng nhập tên người nhận.")]
    [MaxLength(150)]
    public string RecipientName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập số điện thoại nhận hàng.")]
    [MaxLength(20)]
    public string PhoneNumber { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập địa chỉ giao hàng.")]
    [MaxLength(500)]
    public string ShippingAddress { get; set; } = string.Empty;

    public long? AddressId { get; set; }

    [MaxLength(30)]
    public string PaymentMethod { get; set; } = "COD";

    [Range(0, double.MaxValue)]
    public decimal ShippingFee { get; set; } = 0;

    [MaxLength(500)]
    public string? Note { get; set; }
}

public class OrderItemDetailDto
{
    public long Id { get; set; }
    public long ProductId { get; set; }
    public long VariantId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public string SKU { get; set; } = string.Empty;
    public string? Color { get; set; }
    public string? Storage { get; set; }
    public string? PrimaryImageUrl { get; set; }
    public decimal UnitPrice { get; set; }
    public int Quantity { get; set; }
    public decimal TotalPrice { get; set; }
}

public class OrderStatusHistoryDto
{
    public long Id { get; set; }
    public string? OldStatus { get; set; }
    public string NewStatus { get; set; } = string.Empty;
    public string? Note { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class OrderListItemDto
{
    public long Id { get; set; }
    public string OrderCode { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string PaymentMethod { get; set; } = string.Empty;
    public string PaymentStatus { get; set; } = string.Empty;
    public int TotalQuantity { get; set; }
    public decimal TotalAmount { get; set; }
    public string? FirstProductName { get; set; }
    public string? FirstProductImageUrl { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class OrderDetailDto
{
    public long Id { get; set; }
    public string OrderCode { get; set; } = string.Empty;
    public long UserId { get; set; }
    public string RecipientName { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public string ShippingAddress { get; set; } = string.Empty;
    public decimal Subtotal { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal ShippingFee { get; set; }
    public decimal TotalAmount { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? Note { get; set; }
    public string PaymentMethod { get; set; } = string.Empty;
    public string PaymentStatus { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public List<OrderItemDetailDto> Items { get; set; } = new();
    public List<OrderStatusHistoryDto> StatusHistory { get; set; } = new();
    public string? VietQrUrl { get; set; }
    public VietQrInfoDto? VietQr { get; set; }
}

public class VietQrInfoDto
{
    public string BankId { get; set; } = string.Empty;
    public string AccountNo { get; set; } = string.Empty;
    public string AccountName { get; set; } = string.Empty;
    public long Amount { get; set; }
    public string AddInfo { get; set; } = string.Empty;
    public string QrImageUrl { get; set; } = string.Empty;
}