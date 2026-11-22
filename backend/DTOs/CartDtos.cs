using System.ComponentModel.DataAnnotations;

namespace backend.DTOs;

public class AddToCartRequest
{
    [Required(ErrorMessage = "Vui lòng chọn phiên bản sản phẩm.")]
    public long VariantId { get; set; }

    [Range(1, 100, ErrorMessage = "Số lượng thêm vào giỏ phải từ 1 đến 100.")]
    public int Quantity { get; set; } = 1;
}

public class UpdateCartItemQuantityRequest
{
    [Required(ErrorMessage = "Vui lòng nhập số lượng.")]
    [Range(1, 100, ErrorMessage = "Số lượng sản phẩm phải từ 1 đến 100.")]
    public int Quantity { get; set; }
}

public class CartItemDto
{
    public long Id { get; set; }
    public long ProductId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public long VariantId { get; set; }
    public string SKU { get; set; } = string.Empty;
    public string? Color { get; set; }
    public string? Storage { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal? CompareAtPrice { get; set; }
    public int Quantity { get; set; }
    public decimal LineTotal { get; set; }
    public string? PrimaryImageUrl { get; set; }
    public int StockQuantity { get; set; }
    public bool IsAvailable { get; set; }
}

public class CartResponseDto
{
    public long Id { get; set; }
    public long UserId { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int TotalItems { get; set; }
    public decimal Subtotal { get; set; }
    public List<CartItemDto> Items { get; set; } = new();
}