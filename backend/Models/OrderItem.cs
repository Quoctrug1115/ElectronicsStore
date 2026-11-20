namespace backend.Models;

public class OrderItem
{
    public long Id { get; set; }
    public long OrderId { get; set; }
    public long VariantId { get; set; }

    // Snapshot thông tin sản phẩm tại thời điểm mua
    public string ProductName { get; set; } = string.Empty;
    public string SKU { get; set; } = string.Empty;

    public decimal UnitPrice { get; set; }
    public int Quantity { get; set; }
    public decimal TotalPrice { get; set; }

    public Order Order { get; set; } = null!;
    public ProductVariant Variant { get; set; } = null!;
}