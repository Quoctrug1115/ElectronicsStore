using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly ElectronicsStoreContext _context;
    private readonly FileStorageService _fileStorage;

    public ProductsController(ElectronicsStoreContext context, FileStorageService fileStorage)
    {
        _context = context;
        _fileStorage = fileStorage;
    }

    // 1. LẤY DANH SÁCH SẢN PHẨM CÓ PHÂN TRANG, LỌC & TÌM KIẾM
    [HttpGet]
    public async Task<IActionResult> GetPaged(
        [FromQuery] int pageIndex = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] string? search = null,
        [FromQuery] long? categoryId = null,
        [FromQuery] long? brandId = null,
        [FromQuery] string? sortBy = "newest")
    {
        var query = _context.Products
            .Include(p => p.Category)
            .Include(p => p.Brand)
            .Include(p => p.Variants)
            .Include(p => p.Images)
            .Where(p => !p.IsDeleted)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var keyword = search.Trim();
            query = query.Where(p => EF.Functions.Like(p.Name, $"%{keyword}%"));
        }

        if (categoryId.HasValue)
            query = query.Where(p => p.CategoryId == categoryId.Value);

        if (brandId.HasValue)
            query = query.Where(p => p.BrandId == brandId.Value);

        // Sắp xếp (Ép sang double? để tương thích hoàn toàn với SQLite khi sort theo decimal)
        query = sortBy switch
        {
            "price_asc" => query.OrderBy(p => p.Variants.Where(v => v.IsActive).Min(v => (double?)v.Price) ?? 0),
            "price_desc" => query.OrderByDescending(p => p.Variants.Where(v => v.IsActive).Min(v => (double?)v.Price) ?? 0),
            _ => query.OrderByDescending(p => p.CreatedAt)
        };

        var pagedEntities = await PagedResult<Product>.CreateAsync(query, pageIndex, pageSize);

        var result = new PagedResult<ProductListItemDto>
        {
            TotalCount = pagedEntities.TotalCount,
            PageIndex = pagedEntities.PageIndex,
            PageSize = pagedEntities.PageSize,
            Items = pagedEntities.Items.Select(p =>
            {
                var defaultVariant = p.Variants.FirstOrDefault(v => v.IsActive) ?? p.Variants.FirstOrDefault();
                var primaryImage = p.Images.FirstOrDefault(i => i.IsPrimary) ?? p.Images.OrderBy(i => i.SortOrder).FirstOrDefault();

                return new ProductListItemDto
                {
                    Id = p.Id,
                    Name = p.Name,
                    CategoryId = p.CategoryId,
                    CategoryName = p.Category.Name,
                    BrandId = p.BrandId,
                    BrandName = p.Brand.Name,
                    Price = defaultVariant?.Price ?? 0,
                    CompareAtPrice = defaultVariant?.CompareAtPrice,
                    PrimaryImageUrl = primaryImage?.ImageUrl,
                    IsActive = p.IsActive,
                    CreatedAt = p.CreatedAt
                };
            }).ToList()
        };

        return Ok(result);
    }

    // 2. LẤY CHI TIẾT SẢN PHẨM
    [HttpGet("{id:long}")]
    public async Task<IActionResult> GetById(long id)
    {
        var product = await _context.Products
            .Include(p => p.Category)
            .Include(p => p.Brand)
            .Include(p => p.Images)
            .Include(p => p.Variants)
            .FirstOrDefaultAsync(p => p.Id == id && !p.IsDeleted);

        if (product == null)
            return NotFound(new { message = "Không tìm thấy sản phẩm." });

        var dto = new ProductDetailDto
        {
            Id = product.Id,
            Name = product.Name,
            Description = product.Description,
            CategoryId = product.CategoryId,
            CategoryName = product.Category.Name,
            BrandId = product.BrandId,
            BrandName = product.Brand.Name,
            IsActive = product.IsActive,
            CreatedAt = product.CreatedAt,
            Images = product.Images.OrderBy(i => i.SortOrder).Select(i => new ProductImageDto
            {
                Id = i.Id,
                ImageUrl = i.ImageUrl,
                IsPrimary = i.IsPrimary,
                SortOrder = i.SortOrder
            }).ToList(),
            Variants = product.Variants.Select(v => new ProductVariantDto
            {
                Id = v.Id,
                SKU = v.SKU,
                Color = v.Color,
                Storage = v.Storage,
                Price = v.Price,
                CompareAtPrice = v.CompareAtPrice,
                IsActive = v.IsActive
            }).ToList()
        };

        return Ok(dto);
    }

    // 3. THÊM SẢN PHẨM MỚI (Nhận multipart/form-data + IFormFile)
    [Authorize(Roles = "Admin")]
    [HttpPost]
    public async Task<IActionResult> Create([FromForm] CreateProductRequest request)
    {
        if (!await _context.Categories.AnyAsync(c => c.Id == request.CategoryId))
            return BadRequest(new { message = "Danh mục không tồn tại." });

        if (!await _context.Brands.AnyAsync(b => b.Id == request.BrandId))
            return BadRequest(new { message = "Thương hiệu không tồn tại." });

        var sku = request.SKU.Trim().ToUpper();
        if (await _context.ProductVariants.AnyAsync(v => v.SKU == sku))
            return BadRequest(new { message = $"Mã SKU '{sku}' đã tồn tại." });

        // Lưu các file ảnh mới vào wwwroot/images/products
        var savedPaths = new List<string>();
        if (request.ImageFiles != null && request.ImageFiles.Count > 0)
        {
            foreach (var file in request.ImageFiles)
            {
                var uploadResult = await _fileStorage.SaveImageAsync(file, "products");
                if (!uploadResult.Success)
                {
                    // Hoàn tác xóa các file đã lưu trước đó nếu có 1 file bị lỗi
                    _fileStorage.DeletePhysicalFiles(savedPaths);
                    return BadRequest(new { message = uploadResult.ErrorMessage });
                }
                savedPaths.Add(uploadResult.RelativePath!);
            }
        }

        var product = new Product
        {
            CategoryId = request.CategoryId,
            BrandId = request.BrandId,
            Name = request.Name.Trim(),
            Description = request.Description?.Trim(),
            IsActive = request.IsActive,
            CreatedAt = DateTime.UtcNow
        };

        product.Variants.Add(new ProductVariant
        {
            SKU = sku,
            Color = request.Color?.Trim(),
            Storage = request.Storage?.Trim(),
            Price = request.Price,
            CompareAtPrice = request.CompareAtPrice,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        });

        for (int i = 0; i < savedPaths.Count; i++)
        {
            product.Images.Add(new ProductImage
            {
                ImageUrl = savedPaths[i],
                IsPrimary = (i == 0), // Ảnh đầu tiên mặc định là ảnh chính
                SortOrder = i
            });
        }

        _context.Products.Add(product);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = product.Id }, new
        {
            message = "Thêm sản phẩm thành công.",
            productId = product.Id,
            images = savedPaths
        });
    }

    // 4. CẬP NHẬT SẢN PHẨM (Xóa file ảnh cũ trong wwwroot khi upload ảnh mới)
    [Authorize(Roles = "Admin")]
    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromForm] UpdateProductRequest request)
    {
        var product = await _context.Products
            .Include(p => p.Images)
            .Include(p => p.Variants)
            .FirstOrDefaultAsync(p => p.Id == id && !p.IsDeleted);

        if (product == null)
            return NotFound(new { message = "Không tìm thấy sản phẩm." });

        if (!await _context.Categories.AnyAsync(c => c.Id == request.CategoryId))
            return BadRequest(new { message = "Danh mục không tồn tại." });

        if (!await _context.Brands.AnyAsync(b => b.Id == request.BrandId))
            return BadRequest(new { message = "Thương hiệu không tồn tại." });

        // Cập nhật biến thể chính nếu có truyền dữ liệu
        var primaryVariant = product.Variants.FirstOrDefault();
        if (primaryVariant != null)
        {
            if (!string.IsNullOrWhiteSpace(request.SKU))
            {
                var newSku = request.SKU.Trim().ToUpper();
                bool skuConflict = await _context.ProductVariants
                    .AnyAsync(v => v.SKU == newSku && v.Id != primaryVariant.Id);

                if (skuConflict)
                    return BadRequest(new { message = $"Mã SKU '{newSku}' đã được dùng cho biến thể khác." });

                primaryVariant.SKU = newSku;
            }

            if (request.Color != null) primaryVariant.Color = request.Color.Trim();
            if (request.Storage != null) primaryVariant.Storage = request.Storage.Trim();
            if (request.Price.HasValue) primaryVariant.Price = request.Price.Value;
            if (request.CompareAtPrice.HasValue) primaryVariant.CompareAtPrice = request.CompareAtPrice.Value;
        }

        // Xử lý ảnh: Nếu người dùng upload ảnh mới -> lưu ảnh mới, xóa ảnh vật lý cũ trong wwwroot
        if (request.ImageFiles != null && request.ImageFiles.Count > 0)
        {
            var newSavedPaths = new List<string>();
            foreach (var file in request.ImageFiles)
            {
                var uploadResult = await _fileStorage.SaveImageAsync(file, "products");
                if (!uploadResult.Success)
                {
                    _fileStorage.DeletePhysicalFiles(newSavedPaths);
                    return BadRequest(new { message = uploadResult.ErrorMessage });
                }
                newSavedPaths.Add(uploadResult.RelativePath!);
            }

            // Lưu lại đường dẫn ảnh cũ để xóa vật lý
            var oldImageUrls = product.Images.Select(i => i.ImageUrl).ToList();

            // Xóa bản ghi ảnh cũ trong DB trước khi thêm bản ghi ảnh mới (tránh đụng index IsPrimary = 1)
            _context.ProductImages.RemoveRange(product.Images);
            await _context.SaveChangesAsync();

            for (int i = 0; i < newSavedPaths.Count; i++)
            {
                _context.ProductImages.Add(new ProductImage
                {
                    ProductId = product.Id,
                    ImageUrl = newSavedPaths[i],
                    IsPrimary = (i == 0),
                    SortOrder = i
                });
            }

            // Xóa các file ảnh cũ trong wwwroot
            _fileStorage.DeletePhysicalFiles(oldImageUrls);
        }

        product.CategoryId = request.CategoryId;
        product.BrandId = request.BrandId;
        product.Name = request.Name.Trim();
        product.Description = request.Description?.Trim();
        product.IsActive = request.IsActive;
        product.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return Ok(new { message = "Cập nhật sản phẩm thành công." });
    }

    // 5. XÓA SẢN PHẨM (Xóa sạch file ảnh vật lý trong wwwroot)
    [Authorize(Roles = "Admin")]
    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id)
    {
        var product = await _context.Products
            .Include(p => p.Images)
            .FirstOrDefaultAsync(p => p.Id == id && !p.IsDeleted);

        if (product == null)
            return NotFound(new { message = "Không tìm thấy sản phẩm." });

        // Xóa toàn bộ file ảnh vật lý của sản phẩm trong wwwroot
        var imageUrls = product.Images.Select(i => i.ImageUrl).ToList();
        _fileStorage.DeletePhysicalFiles(imageUrls);

        _context.ProductImages.RemoveRange(product.Images);
        _context.Products.Remove(product);
        await _context.SaveChangesAsync();

        return Ok(new { message = "Xóa sản phẩm và toàn bộ ảnh đính kèm thành công." });
    }
}