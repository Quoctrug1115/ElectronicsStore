using backend.Data;
using backend.DTOs;
using backend.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CategoriesController : ControllerBase
{
    private readonly ElectronicsStoreContext _context;
    private readonly IWebHostEnvironment _env;

    public CategoriesController(ElectronicsStoreContext context, IWebHostEnvironment env)
    {
        _context = context;
        _env = env;
    }

    // 1. LẤY DANH SÁCH DANH MỤC (Hỗ trợ lọc isActive & search)
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] bool? isActive, [FromQuery] string? search = null)
    {
        var query = _context.Categories
            .AsNoTracking()
            .Include(c => c.Parent)
            .AsQueryable();

        if (isActive.HasValue)
        {
            query = query.Where(c => c.IsActive == isActive.Value);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var pattern = $"%{search.Trim()}%";
            query = query.Where(c => EF.Functions.Like(c.Name, pattern));
        }

        var categories = await query
            .OrderBy(c => c.Id)
            .Select(c => new CategoryResponseDto
            {
                Id = c.Id,
                Name = c.Name,
                ParentId = c.ParentId,
                ParentName = c.Parent != null ? c.Parent.Name : null,
                Description = c.Description,
                ImageUrl = c.ImageUrl,
                IsActive = c.IsActive,
                CreatedAt = c.CreatedAt,
                ProductCount = c.Products.Count(p => !p.IsDeleted && p.IsActive)
            })
            .ToListAsync();

        return Ok(categories);
    }

    // 1b. LẤY DANH SÁCH DANH MỤC ĐANG HOẠT ĐỘNG
    [HttpGet("active")]
    public Task<IActionResult> GetActiveCategories() => GetAll(isActive: true);

    // 2. LẤY CHI TIẾT DANH MỤC THEO ID
    [HttpGet("{id:long}")]
    public async Task<IActionResult> GetById(long id)
    {
        var category = await _context.Categories
            .AsNoTracking()
            .Include(c => c.Parent)
            .Where(c => c.Id == id)
            .Select(c => new CategoryResponseDto
            {
                Id = c.Id,
                Name = c.Name,
                ParentId = c.ParentId,
                ParentName = c.Parent != null ? c.Parent.Name : null,
                Description = c.Description,
                ImageUrl = c.ImageUrl,
                IsActive = c.IsActive,
                CreatedAt = c.CreatedAt,
                ProductCount = c.Products.Count(p => !p.IsDeleted && p.IsActive)
            })
            .FirstOrDefaultAsync();

        if (category == null)
            return NotFound(new { message = "Không tìm thấy danh mục." });

        return Ok(category);
    }

    // 3. THÊM DANH MỤC MỚI (Chỉ Admin)
    [Authorize(Roles = "Admin")]
    [HttpPost]
    public async Task<IActionResult> Create([FromForm] CreateCategoryRequest request)
    {
        string? parentName = null;
        if (request.ParentId.HasValue)
        {
            var parent = await _context.Categories.FindAsync(request.ParentId.Value);
            if (parent == null)
                return BadRequest(new { message = "Danh mục cha không tồn tại." });

            parentName = parent.Name;
        }

        string? imageUrl = null;
        if (request.ImageFile != null)
        {
            var saveResult = await SaveImageAsync(request.ImageFile);
            if (!saveResult.Success)
                return BadRequest(new { message = saveResult.ErrorMessage });

            imageUrl = saveResult.RelativePath;
        }

        var category = new Category
        {
            Name = request.Name.Trim(),
            ParentId = request.ParentId,
            Description = request.Description?.Trim(),
            ImageUrl = imageUrl,
            IsActive = request.IsActive,
            CreatedAt = DateTime.UtcNow
        };

        _context.Categories.Add(category);
        await _context.SaveChangesAsync();

        var responseDto = new CategoryResponseDto
        {
            Id = category.Id,
            Name = category.Name,
            ParentId = category.ParentId,
            ParentName = parentName,
            Description = category.Description,
            ImageUrl = category.ImageUrl,
            IsActive = category.IsActive,
            CreatedAt = category.CreatedAt,
            ProductCount = 0
        };

        return CreatedAtAction(nameof(GetById), new { id = category.Id }, new
        {
            message = "Tạo danh mục thành công.",
            data = responseDto
        });
    }

    // 4. CẬP NHẬT DANH MỤC (Chỉ Admin)
    [Authorize(Roles = "Admin")]
    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromForm] UpdateCategoryRequest request)
    {
        var category = await _context.Categories.FindAsync(id);
        if (category == null)
            return NotFound(new { message = "Không tìm thấy danh mục." });

        string? parentName = null;
        if (request.ParentId.HasValue)
        {
            if (request.ParentId.Value == id)
                return BadRequest(new { message = "Danh mục không thể chọn chính nó làm danh mục cha." });

            var parent = await _context.Categories.FindAsync(request.ParentId.Value);
            if (parent == null)
                return BadRequest(new { message = "Danh mục cha không tồn tại." });

            parentName = parent.Name;
        }

        if (request.ImageFile != null)
        {
            var saveResult = await SaveImageAsync(request.ImageFile);
            if (!saveResult.Success)
                return BadRequest(new { message = saveResult.ErrorMessage });

            DeletePhysicalImage(category.ImageUrl);
            category.ImageUrl = saveResult.RelativePath;
        }

        category.Name = request.Name.Trim();
        category.ParentId = request.ParentId;
        category.Description = request.Description?.Trim();
        category.IsActive = request.IsActive;

        await _context.SaveChangesAsync();

        var productCount = await _context.Products.CountAsync(p => p.CategoryId == id && !p.IsDeleted);

        var responseDto = new CategoryResponseDto
        {
            Id = category.Id,
            Name = category.Name,
            ParentId = category.ParentId,
            ParentName = parentName,
            Description = category.Description,
            ImageUrl = category.ImageUrl,
            IsActive = category.IsActive,
            CreatedAt = category.CreatedAt,
            ProductCount = productCount
        };

        return Ok(new
        {
            message = "Cập nhật danh mục thành công.",
            data = responseDto
        });
    }

    // 5. XÓA DANH MỤC (Chỉ Admin - Bắt buộc chặn xóa nếu đã có sản phẩm)
    [Authorize(Roles = "Admin")]
    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id)
    {
        var category = await _context.Categories.FindAsync(id);
        if (category == null)
            return NotFound(new { message = "Không tìm thấy danh mục." });

        bool hasProducts = await _context.Products.AnyAsync(p => p.CategoryId == id);
        if (hasProducts)
        {
            return BadRequest(new
            {
                message = "Không thể xóa danh mục này vì đã có sản phẩm thuộc danh mục."
            });
        }

        bool hasSubCategories = await _context.Categories.AnyAsync(c => c.ParentId == id);
        if (hasSubCategories)
        {
            return BadRequest(new
            {
                message = "Không thể xóa danh mục này vì đang chứa danh mục con."
            });
        }

        DeletePhysicalImage(category.ImageUrl);

        _context.Categories.Remove(category);
        await _context.SaveChangesAsync();

        return Ok(new { message = "Xóa danh mục thành công." });
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
        var uploadFolder = Path.Combine(webRoot, "images", "categories");
        Directory.CreateDirectory(uploadFolder);

        var fileName = $"{Guid.NewGuid()}{ext}";
        var fullPath = Path.Combine(uploadFolder, fileName);

        await using var stream = new FileStream(fullPath, FileMode.Create);
        await file.CopyToAsync(stream);

        return (true, $"/images/categories/{fileName}", null);
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