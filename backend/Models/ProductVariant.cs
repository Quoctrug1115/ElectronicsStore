namespace backend.Models;

public class ProductVariant
{
    public long Id { get; set; }
    public long ProductId { get; set; }
    public string SKU { get; set; } = string.Empty;
    public string? Color { get; set; }
    public string? Storage { get; set; }
    public decimal Price { get; set; }
    public decimal? CompareAtPrice { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public Product Product { get; set; } = null!;
}