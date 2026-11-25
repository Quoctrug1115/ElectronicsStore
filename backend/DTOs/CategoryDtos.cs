using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Http;

namespace backend.DTOs;

public class CategoryResponseDto
{
    public long Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public long? ParentId { get; set; }
    public string? ParentName { get; set; }
    public string? Description { get; set; }
    public string? ImageUrl { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public int ProductCount { get; set; }
}

public class CreateCategoryRequest
{
    [Required(ErrorMessage = "Tên danh mục không được để trống")]
    [MaxLength(150)]
    public string Name { get; set; } = string.Empty;

    public long? ParentId { get; set; }

    [MaxLength(500)]
    public string? Description { get; set; }

    public bool IsActive { get; set; } = true;

    public IFormFile? ImageFile { get; set; }
}

public class UpdateCategoryRequest
{
    [Required(ErrorMessage = "Tên danh mục không được để trống")]
    [MaxLength(150)]
    public string Name { get; set; } = string.Empty;

    public long? ParentId { get; set; }

    [MaxLength(500)]
    public string? Description { get; set; }

    public bool IsActive { get; set; } = true;

    public bool RemoveImage { get; set; }

    public IFormFile? ImageFile { get; set; }
}