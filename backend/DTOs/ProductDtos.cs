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
    public int StockQuantity { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class ProductSpecificationDto
{
    public long Id { get; set; }
    public string SpecificationName { get; set; } = string.Empty;
    public string SpecificationValue { get; set; } = string.Empty;
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
    public decimal MinPrice { get; set; }
    public decimal MaxPrice { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public List<ProductImageDto> Images { get; set; } = new();
    public List<ProductVariantDto> Variants { get; set; } = new();
    public List<ProductSpecificationDto> Specifications { get; set; } = new();
    public List<ProductListItemDto> RelatedProducts { get; set; } = new();
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
    public int StockQuantity { get; set; }
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

    [Range(0, 1000000, ErrorMessage = "Số lượng tồn kho phải từ 0 đến 1.000.000")]
    public int StockQuantity { get; set; }

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

    [MaxLength(100)]
    public string? SKU { get; set; }
    [MaxLength(50)]
    public string? Color { get; set; }
    [MaxLength(50)]
    public string? Storage { get; set; }
    public decimal? Price { get; set; }
    public decimal? CompareAtPrice { get; set; }

    [Range(0, 1000000, ErrorMessage = "Số lượng tồn kho phải từ 0 đến 1.000.000")]
    public int? StockQuantity { get; set; }

    public List<IFormFile>? ImageFiles { get; set; }
}