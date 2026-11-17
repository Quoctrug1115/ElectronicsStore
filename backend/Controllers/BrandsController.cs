using backend.Data;
using backend.DTOs;
using backend.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BrandsController : ControllerBase
{
    private readonly ElectronicsStoreContext _context;
    private readonly IWebHostEnvironment _env;

    public BrandsController(ElectronicsStoreContext context, IWebHostEnvironment env)
    {
        _context = context;
        _env = env;
    }

    // 1. LẤY DANH SÁCH THƯƠNG HIỆU
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] bool? isActive)
    {
        var query = _context.Brands.AsQueryable();

        if (isActive.HasValue)
        {
            query = query.Where(b => b.IsActive == isActive.Value);
        }

        var brands = await query
            .OrderByDescending(b => b.CreatedAt)
            .Select(b => new BrandResponseDto
            {
                Id = b.Id,
                Name = b.Name,
                Description = b.Description,
                LogoUrl = b.LogoUrl,
                IsActive = b.IsActive,
                CreatedAt = b.CreatedAt,
                ProductCount = b.Products.Count(p => !p.IsDeleted)
            })
            .ToListAsync();

        return Ok(brands);
    }

    // 2. LẤY CHI TIẾT THƯƠNG HIỆU THEO ID
    [HttpGet("{id:long}")]
    public async Task<IActionResult> GetById(long id)
    {
        var brand = await _context.Brands
            .Where(b => b.Id == id)
            .Select(b => new BrandResponseDto
            {
                Id = b.Id,
                Name = b.Name,
                Description = b.Description,
                LogoUrl = b.LogoUrl,
                IsActive = b.IsActive,
                CreatedAt = b.CreatedAt,
                ProductCount = b.Products.Count(p => !p.IsDeleted)
            })
            .FirstOrDefaultAsync();

        if (brand == null)
            return NotFound(new { message = "Không tìm thấy thương hiệu." });

        return Ok(brand);
    }

    // 3. THÊM THƯƠNG HIỆU MỚI (Chỉ Admin)
    [Authorize(Roles = "Admin")]
    [HttpPost]
    public async Task<IActionResult> Create([FromForm] CreateBrandRequest request)
    {
        string? logoUrl = null;
        if (request.LogoFile != null)
        {
            var saveResult = await SaveImageAsync(request.LogoFile);
            if (!saveResult.Success)
                return BadRequest(new { message = saveResult.ErrorMessage });

            logoUrl = saveResult.RelativePath;
        }

        var brand = new Brand
        {
            Name = request.Name.Trim(),
            Description = request.Description?.Trim(),
            LogoUrl = logoUrl,
            IsActive = request.IsActive,
            CreatedAt = DateTime.UtcNow
        };

        _context.Brands.Add(brand);
        await _context.SaveChangesAsync();

        var responseDto = new BrandResponseDto
        {
            Id = brand.Id,
            Name = brand.Name,
            Description = brand.Description,
            LogoUrl = brand.LogoUrl,
            IsActive = brand.IsActive,
            CreatedAt = brand.CreatedAt,
            ProductCount = 0
        };

        return CreatedAtAction(nameof(GetById), new { id = brand.Id }, new
        {
            message = "Tạo thương hiệu thành công.",
            data = responseDto
        });
    }

    // 4. CẬP NHẬT THƯƠNG HIỆU (Chỉ Admin)
    [Authorize(Roles = "Admin")]
    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromForm] UpdateBrandRequest request)
    {
        var brand = await _context.Brands.FindAsync(id);
        if (brand == null)
            return NotFound(new { message = "Không tìm thấy thương hiệu." });

        if (request.LogoFile != null)
        {
            var saveResult = await SaveImageAsync(request.LogoFile);
            if (!saveResult.Success)
                return BadRequest(new { message = saveResult.ErrorMessage });

            DeletePhysicalImage(brand.LogoUrl);
            brand.LogoUrl = saveResult.RelativePath;
        }

        brand.Name = request.Name.Trim();
        brand.Description = request.Description?.Trim();
        brand.IsActive = request.IsActive;

        await _context.SaveChangesAsync();

        var productCount = await _context.Products.CountAsync(p => p.BrandId == id && !p.IsDeleted);

        var responseDto = new BrandResponseDto
        {
            Id = brand.Id,
            Name = brand.Name,
            Description = brand.Description,
            LogoUrl = brand.LogoUrl,
            IsActive = brand.IsActive,
            CreatedAt = brand.CreatedAt,
            ProductCount = productCount
        };

        return Ok(new
        {
            message = "Cập nhật thương hiệu thành công.",
            data = responseDto
        });
    }

    // 5. XÓA THƯƠNG HIỆU (Chỉ Admin - chặn xóa nếu đã có sản phẩm)
    [Authorize(Roles = "Admin")]
    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id)
    {
        var brand = await _context.Brands.FindAsync(id);
        if (brand == null)
            return NotFound(new { message = "Không tìm thấy thương hiệu." });

        bool hasProducts = await _context.Products.AnyAsync(p => p.BrandId == id);
        if (hasProducts)
        {
            return BadRequest(new
            {
                message = "Không thể xóa thương hiệu này vì đã có sản phẩm thuộc thương hiệu."
            });
        }

        DeletePhysicalImage(brand.LogoUrl);

        _context.Brands.Remove(brand);
        await _context.SaveChangesAsync();

        return Ok(new { message = "Xóa thương hiệu thành công." });
    }

    private async Task<(bool Success, string? RelativePath, string? ErrorMessage)> SaveImageAsync(IFormFile file)
    {
        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".webp" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();

        if (!allowedExtensions.Contains(ext))
            return (false, null, "Chỉ chấp nhận file ảnh (.jpg, .jpeg, .png, .webp).");

        if (file.Length > 5 * 1024 * 1024)
            return (false, null, "Kích thước ảnh tối đa 5MB.");

        var webRoot = _env.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
        var uploadFolder = Path.Combine(webRoot, "images", "brands");
        Directory.CreateDirectory(uploadFolder);

        var fileName = $"{Guid.NewGuid()}{ext}";
        var fullPath = Path.Combine(uploadFolder, fileName);

        await using var stream = new FileStream(fullPath, FileMode.Create);
        await file.CopyToAsync(stream);

        return (true, $"/images/brands/{fileName}", null);
    }

    private void DeletePhysicalImage(string? relativeUrl)
    {
        if (string.IsNullOrWhiteSpace(relativeUrl))
            return;

        var webRoot = _env.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
        var fullPath = Path.Combine(webRoot, relativeUrl.TrimStart('/').Replace('/', Path.DirectorySeparatorChar));

        if (System.IO.File.Exists(fullPath))
        {
            System.IO.File.Delete(fullPath);
        }
    }
}
