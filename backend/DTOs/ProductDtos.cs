using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Http;

namespace backend.DTOs;

public class ProductListItemDto
{
    public long Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public long CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public long BrandId { get; set; }
    public string BrandName { get; set; } = string.Empty;
    public decimal Price { get; set; }
    public decimal? CompareAtPrice { get; set; }
    public string? PrimaryImageUrl { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class ProductDetailDto
{
    public long Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public long CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public long BrandId { get; set; }
    public string BrandName { get; set; } = string.Empty;
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public List<ProductImageDto> Images { get; set; } = new();
    public List<ProductVariantDto> Variants { get; set; } = new();
}

public class ProductImageDto
{
    public long Id { get; set; }
    public string ImageUrl { get; set; } = string.Empty;
    public bool IsPrimary { get; set; }
    public int SortOrder { get; set; }
}

public class ProductVariantDto
{
    public long Id { get; set; }
    public string SKU { get; set; } = string.Empty;
    public string? Color { get; set; }
    public string? Storage { get; set; }
    public decimal Price { get; set; }
    public decimal? CompareAtPrice { get; set; }
    public bool IsActive { get; set; }
}

public class CreateProductRequest
{
    [Required]
    public long CategoryId { get; set; }

    [Required]
    public long BrandId { get; set; }

    [Required(ErrorMessage = "Tên sản phẩm không được để trống")]
    [MaxLength(255)]
    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;

    // Thông tin phiên bản (Variant) mặc định ban đầu
    [Required(ErrorMessage = "Mã SKU không được để trống")]
    [MaxLength(100)]
    public string SKU { get; set; } = string.Empty;

    [MaxLength(50)]
    public string? Color { get; set; }

    [MaxLength(50)]
    public string? Storage { get; set; }

    [Range(0, double.MaxValue, ErrorMessage = "Giá bán phải >= 0")]
    public decimal Price { get; set; }

    public decimal? CompareAtPrice { get; set; }

    // Nhận 1 hoặc nhiều file ảnh qua multipart/form-data
    public List<IFormFile>? ImageFiles { get; set; }
}

public class UpdateProductRequest
{
    [Required]
    public long CategoryId { get; set; }

    [Required]
    public long BrandId { get; set; }

    [Required(ErrorMessage = "Tên sản phẩm không được để trống")]
    [MaxLength(255)]
    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;

    // Cập nhật biến thể chính (nếu truyền lên)
    [MaxLength(100)]
    public string? SKU { get; set; }
    [MaxLength(50)]
    public string? Color { get; set; }
    [MaxLength(50)]
    public string? Storage { get; set; }
    public decimal? Price { get; set; }
    public decimal? CompareAtPrice { get; set; }

    // Khi người dùng upload ảnh mới lúc sửa -> xóa ảnh cũ trong wwwroot và thay bằng bộ ảnh mới
    public List<IFormFile>? ImageFiles { get; set; }
}