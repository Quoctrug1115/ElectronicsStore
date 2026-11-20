namespace backend.Models;

public class Order
{
    public long Id { get; set; }
    public string OrderCode { get; set; } = string.Empty;
    public long UserId { get; set; }
    public long? AddressId { get; set; }

    // Snapshot thông tin giao hàng tại thời điểm đặt
    public string RecipientName { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public string ShippingAddress { get; set; } = string.Empty;

    public decimal Subtotal { get; set; }
    public decimal DiscountAmount { get; set; } = 0;
    public decimal ShippingFee { get; set; } = 0;
    public decimal TotalAmount { get; set; }

    public string Status { get; set; } = "Pending";
    public string? Note { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }

    public User User { get; set; } = null!;
    public ICollection<OrderItem> OrderItems { get; set; } = new List<OrderItem>();
    public ICollection<OrderStatusHistory> StatusHistories { get; set; } = new List<OrderStatusHistory>();
    public ICollection<Payment> Payments { get; set; } = new List<Payment>();
}