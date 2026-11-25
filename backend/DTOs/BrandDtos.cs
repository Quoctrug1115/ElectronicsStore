using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Http;

namespace backend.DTOs;

public class BrandResponseDto
{
    public long Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? LogoUrl { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public int ProductCount { get; set; }
}

public class CreateBrandRequest
{
    [Required(ErrorMessage = "Tên thương hiệu không được để trống")]
    [MaxLength(150)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? Description { get; set; }

    public bool IsActive { get; set; } = true;

    public IFormFile? LogoFile { get; set; }
}

public class UpdateBrandRequest
{
    [Required(ErrorMessage = "Tên thương hiệu không được để trống")]
    [MaxLength(150)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? Description { get; set; }

    public bool IsActive { get; set; } = true;

    public bool RemoveLogo { get; set; }

    public IFormFile? LogoFile { get; set; }
}
