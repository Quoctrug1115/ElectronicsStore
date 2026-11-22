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

    // 1. LẤY SẢN PHẨM MỚI NHẤT CÓ PHÂN TRANG (OrderByDescending(p => p.CreatedAt))
    // Hỗ trợ cả ?page=1 lẫn ?pageIndex=1
    [HttpGet("newest")]
    public async Task<IActionResult> GetNewest(
        [FromQuery] int? page = null,
        [FromQuery] int pageIndex = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] long? categoryId = null)
    {
        int currentPage = page ?? pageIndex;

        var query = _context.Products
            .AsNoTracking()
            .Include(p => p.Category)
            .Include(p => p.Brand)
            .Include(p => p.Variants)
            .Include(p => p.Images)
            .Where(p => !p.IsDeleted && p.IsActive)
            .AsQueryable();

        if (categoryId.HasValue)
        {
            query = query.Where(p =>
                p.CategoryId == categoryId.Value ||
                p.Category.ParentId == categoryId.Value);
        }

        query = query.OrderByDescending(p => p.CreatedAt);

        var pagedEntities = await PagedResult<Product>.CreateAsync(query, currentPage, pageSize);
        return Ok(MapToPagedProductList(pagedEntities));
    }

    // 2. LẤY DANH SÁCH SẢN PHẨM: LỌC DANH MỤC, TÌM KIẾM, PHÂN TRANG
    // Hỗ trợ query params: ?categoryId=...&search=...&page=... (và pageIndex, pageSize, brandId, minPrice, maxPrice, sortBy)
    [HttpGet]
    public async Task<IActionResult> GetPaged(
        [FromQuery] int? page = null,
        [FromQuery] int pageIndex = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] string? search = null,
        [FromQuery] long? categoryId = null,
        [FromQuery] long? brandId = null,
        [FromQuery] decimal? minPrice = null,
        [FromQuery] decimal? maxPrice = null,
        [FromQuery] bool? isActive = null,
        [FromQuery] string? sortBy = "newest")
    {
        int currentPage = page ?? pageIndex;

        var query = _context.Products
            .AsNoTracking()
            .Include(p => p.Category)
            .Include(p => p.Brand)
            .Include(p => p.Variants)
            .Include(p => p.Images)
            .Where(p => !p.IsDeleted)
            .AsQueryable();

        if (isActive.HasValue)
        {
            query = query.Where(p => p.IsActive == isActive.Value);
        }

        // Lọc theo danh mục (bao gồm cả danh mục con nếu chọn danh mục cha)
        if (categoryId.HasValue)
        {
            query = query.Where(p =>
                p.CategoryId == categoryId.Value ||
                p.Category.ParentId == categoryId.Value);
        }

        if (brandId.HasValue)
        {
            query = query.Where(p => p.BrandId == brandId.Value);
        }

        // Tìm kiếm theo Tên sản phẩm, Mô tả, Thương hiệu, Danh mục hoặc Mã SKU
        if (!string.IsNullOrWhiteSpace(search))
        {
            var pattern = $"%{search.Trim()}%";
            query = query.Where(p =>
                EF.Functions.Like(p.Name, pattern) ||
                (p.Description != null && EF.Functions.Like(p.Description, pattern)) ||
                EF.Functions.Like(p.Brand.Name, pattern) ||
                EF.Functions.Like(p.Category.Name, pattern) ||
                p.Variants.Any(v => EF.Functions.Like(v.SKU, pattern))
            );
        }

        // Lọc theo khoảng giá (ép double để tương thích cả SQL Server và SQLite)
        if (minPrice.HasValue)
        {
            var min = (double)minPrice.Value;
            query = query.Where(p => p.Variants.Any(v => v.IsActive && (double)v.Price >= min));
        }

        if (maxPrice.HasValue)
        {
            var max = (double)maxPrice.Value;
            query = query.Where(p => p.Variants.Any(v => v.IsActive && (double)v.Price <= max));
        }

        // Sắp xếp
        query = sortBy switch
        {
            "price_asc" => query.OrderBy(p => p.Variants.Where(v => v.IsActive).Min(v => (double?)v.Price) ?? 0),
            "price_desc" => query.OrderByDescending(p => p.Variants.Where(v => v.IsActive).Min(v => (double?)v.Price) ?? 0),
            "name_asc" => query.OrderBy(p => p.Name),
            _ => query.OrderByDescending(p => p.CreatedAt)
        };

        var pagedEntities = await PagedResult<Product>.CreateAsync(query, currentPage, pageSize);
        return Ok(MapToPagedProductList(pagedEntities));
    }

    // 3. CHI TIẾT SẢN PHẨM (Kèm bộ ảnh, biến thể, thông số kỹ thuật & sản phẩm liên quan)
    [HttpGet("{id:long}")]
    public async Task<IActionResult> GetById(long id)
    {
        var product = await _context.Products
            .AsNoTracking()
            .Include(p => p.Category)
            .Include(p => p.Brand)
            .Include(p => p.Images)
            .Include(p => p.Variants)
            .Include(p => p.Specifications)
            .FirstOrDefaultAsync(p => p.Id == id && !p.IsDeleted);

        if (product == null)
            return NotFound(new { message = "Không tìm thấy sản phẩm." });

        // Lấy tối đa 4 sản phẩm liên quan cùng danh mục
        var relatedEntities = await _context.Products
            .AsNoTracking()
            .Include(p => p.Category)
            .Include(p => p.Brand)
            .Include(p => p.Variants)
            .Include(p => p.Images)
            .Where(p => !p.IsDeleted && p.IsActive && p.CategoryId == product.CategoryId && p.Id != product.Id)
            .OrderByDescending(p => p.CreatedAt)
            .Take(4)
            .ToListAsync();

        var activeVariants = product.Variants.Where(v => v.IsActive).ToList();
        var priceSource = activeVariants.Count > 0 ? activeVariants : product.Variants.ToList();

        var dto = new ProductDetailDto
        {
            Id = product.Id,
            Name = product.Name,
            Description = product.Description,
            CategoryId = product.CategoryId,
            CategoryName = product.Category.Name,
            BrandId = product.BrandId,
            BrandName = product.Brand.Name,
            MinPrice = priceSource.Count > 0 ? priceSource.Min(v => v.Price) : 0,
            MaxPrice = priceSource.Count > 0 ? priceSource.Max(v => v.Price) : 0,
            IsActive = product.IsActive,
            CreatedAt = product.CreatedAt,
            UpdatedAt = product.UpdatedAt,
            Images = product.Images
                .OrderByDescending(i => i.IsPrimary)
                .ThenBy(i => i.SortOrder)
                .Select(i => new ProductImageDto
                {
                    Id = i.Id,
                    ImageUrl = i.ImageUrl,
                    IsPrimary = i.IsPrimary,
                    SortOrder = i.SortOrder
                }).ToList(),
            Variants = product.Variants
                .OrderByDescending(v => v.IsActive)
                .ThenBy(v => v.Price)
                .Select(v => new ProductVariantDto
                {
                    Id = v.Id,
                    SKU = v.SKU,
                    Color = v.Color,
                    Storage = v.Storage,
                    Price = v.Price,
                    CompareAtPrice = v.CompareAtPrice,
                    IsActive = v.IsActive
                }).ToList(),
            Specifications = product.Specifications
                .OrderBy(s => s.Id)
                .Select(s => new ProductSpecificationDto
                {
                    Id = s.Id,
                    SpecificationName = s.SpecificationName,
                    SpecificationValue = s.SpecificationValue
                }).ToList(),
            RelatedProducts = relatedEntities.Select(MapToProductListItem).ToList()
        };

        return Ok(dto);
    }

    // --- HÀM MAP DỮ LIỆU DANH SÁCH SẢN PHẨM DÙNG CHUNG ---
    private static PagedResult<ProductListItemDto> MapToPagedProductList(PagedResult<Product> pagedEntities)
    {
        return new PagedResult<ProductListItemDto>
        {
            TotalCount = pagedEntities.TotalCount,
            PageIndex = pagedEntities.PageIndex,
            PageSize = pagedEntities.PageSize,
            Items = pagedEntities.Items.Select(MapToProductListItem).ToList()
        };
    }

    private static ProductListItemDto MapToProductListItem(Product p)
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

        // Sản phẩm đã nằm trong đơn hàng (hoặc giỏ hàng) thì không được xóa cứng:
        // xóa mềm để giữ nguyên lịch sử đơn, giữ ảnh để đơn cũ vẫn hiển thị đúng.
        var variantIds = await _context.ProductVariants
            .Where(v => v.ProductId == id)
            .Select(v => v.Id)
            .ToListAsync();

        bool inOrders = await _context.OrderItems.AnyAsync(oi => variantIds.Contains(oi.VariantId));
        bool inCarts = await _context.CartItems.AnyAsync(ci => variantIds.Contains(ci.VariantId));

        if (inOrders || inCarts)
        {
            product.IsDeleted = true;
            product.IsActive = false;

            if (inCarts)
            {
                // Gỡ khỏi giỏ hàng của mọi người dùng
                var cartItems = await _context.CartItems
                    .Where(ci => variantIds.Contains(ci.VariantId))
                    .ToListAsync();
                _context.CartItems.RemoveRange(cartItems);
            }

            await _context.SaveChangesAsync();
            return Ok(new
            {
                message = inOrders
                    ? "Sản phẩm đã có trong đơn hàng nên được ẩn (xóa mềm) để giữ lịch sử đơn hàng."
                    : "Đã xóa sản phẩm và gỡ khỏi giỏ hàng của người dùng.",
                softDeleted = true
            });
        }

        // Chưa phát sinh đơn: xóa cứng và xóa toàn bộ file ảnh vật lý trong wwwroot
        var imageUrls = product.Images.Select(i => i.ImageUrl).ToList();

        _context.ProductImages.RemoveRange(product.Images);
        _context.Products.Remove(product);
        await _context.SaveChangesAsync();

        // Chỉ xóa file sau khi DB đã xóa thành công
        _fileStorage.DeletePhysicalFiles(imageUrls);

        return Ok(new { message = "Xóa sản phẩm và toàn bộ ảnh đính kèm thành công.", softDeleted = false });
    }
}