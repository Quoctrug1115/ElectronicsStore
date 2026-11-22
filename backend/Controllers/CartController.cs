using System.Security.Claims;
using backend.Data;
using backend.DTOs;
using backend.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CartController : ControllerBase
{
    private readonly ElectronicsStoreContext _context;

    public CartController(ElectronicsStoreContext context)
    {
        _context = context;
    }

    // 1a. LẤY GIỎ HÀNG CỦA USER ĐANG ĐĂNG NHẬP
    [HttpGet]
    public async Task<IActionResult> GetMyCart()
    {
        if (!TryGetCurrentUserId(out var currentUserId))
            return Unauthorized();

        var cartDto = await BuildCartResponseAsync(currentUserId);
        return Ok(cartDto);
    }

    // 1b. LẤY GIỎ HÀNG THEO USER ID
    [HttpGet("{userId:long}")]
    public async Task<IActionResult> GetCartByUserId(long userId)
    {
        if (!TryGetCurrentUserId(out var currentUserId))
            return Unauthorized();

        // Chỉ cho phép chính chủ hoặc Admin truy xuất giỏ hàng theo UserId
        if (currentUserId != userId && !User.IsInRole("Admin"))
            return Forbid();

        bool userExists = await _context.Users.AnyAsync(u => u.Id == userId && !u.IsDeleted);
        if (!userExists)
            return NotFound(new { message = "Không tìm thấy người dùng." });

        var cartDto = await BuildCartResponseAsync(userId);
        return Ok(cartDto);
    }

    // 2. THÊM SẢN PHẨM VÀO GIỎ HÀNG
    [HttpPost("items")]
    public async Task<IActionResult> AddToCart([FromBody] AddToCartRequest request)
    {
        if (!TryGetCurrentUserId(out var userId))
            return Unauthorized();

        var variant = await _context.ProductVariants
            .Include(v => v.Product)
            .FirstOrDefaultAsync(v => v.Id == request.VariantId);

        if (variant == null || variant.Product.IsDeleted)
            return NotFound(new { message = "Phiên bản sản phẩm không tồn tại." });

        if (!variant.IsActive || !variant.Product.IsActive)
            return BadRequest(new { message = "Sản phẩm này hiện đã ngừng kinh doanh hoặc hết hàng." });

        // Tìm giỏ hàng của user; nếu chưa có thì khởi tạo mới
        var cart = await _context.Carts
            .Include(c => c.Items)
            .FirstOrDefaultAsync(c => c.UserId == userId);

        if (cart == null)
        {
            cart = new Cart
            {
                UserId = userId,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _context.Carts.Add(cart);
            await _context.SaveChangesAsync();
        }

        var existingItem = cart.Items.FirstOrDefault(i => i.VariantId == request.VariantId);

        // Kiểm tra tồn kho: tổng số lượng trong giỏ (cũ + mới) không được vượt quá tồn
        var desiredQuantity = (existingItem?.Quantity ?? 0) + request.Quantity;
        if (variant.StockQuantity <= 0)
            return BadRequest(new { message = $"Sản phẩm '{variant.Product.Name}' đã hết hàng." });
        if (desiredQuantity > variant.StockQuantity)
        {
            var inCart = existingItem?.Quantity ?? 0;
            return BadRequest(new
            {
                message = $"Chỉ còn {variant.StockQuantity} sản phẩm '{variant.Product.Name}' trong kho" +
                          (inCart > 0 ? $" (bạn đã có {inCart} trong giỏ)." : ".")
            });
        }

        if (existingItem != null)
        {
            existingItem.Quantity += request.Quantity;
        }
        else
        {
            _context.CartItems.Add(new CartItem
            {
                CartId = cart.Id,
                VariantId = request.VariantId,
                Quantity = request.Quantity
            });
        }

        cart.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        var updatedCart = await BuildCartResponseAsync(userId);
        return Ok(new
        {
            message = "Đã thêm sản phẩm vào giỏ hàng.",
            data = updatedCart
        });
    }

    // 3. CẬP NHẬT SỐ LƯỢNG ITEM TRONG GIỎ
    [HttpPut("items/{itemId:long}")]
    public async Task<IActionResult> UpdateItemQuantity(long itemId, [FromBody] UpdateCartItemQuantityRequest request)
    {
        if (!TryGetCurrentUserId(out var userId))
            return Unauthorized();

        var cartItem = await _context.CartItems
            .Include(ci => ci.Cart)
            .Include(ci => ci.Variant)
                .ThenInclude(v => v.Product)
            .FirstOrDefaultAsync(ci => ci.Id == itemId && ci.Cart.UserId == userId);

        if (cartItem == null)
            return NotFound(new { message = "Không tìm thấy sản phẩm trong giỏ hàng." });

        if (!cartItem.Variant.IsActive || !cartItem.Variant.Product.IsActive || cartItem.Variant.Product.IsDeleted)
            return BadRequest(new { message = "Sản phẩm này hiện không còn khả dụng." });

        if (request.Quantity > cartItem.Variant.StockQuantity)
        {
            return BadRequest(new
            {
                message = cartItem.Variant.StockQuantity <= 0
                    ? $"Sản phẩm '{cartItem.Variant.Product.Name}' đã hết hàng."
                    : $"Chỉ còn {cartItem.Variant.StockQuantity} sản phẩm '{cartItem.Variant.Product.Name}' trong kho."
            });
        }

        cartItem.Quantity = request.Quantity;
        cartItem.Cart.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        var updatedCart = await BuildCartResponseAsync(userId);
        return Ok(new
        {
            message = "Cập nhật số lượng thành công.",
            data = updatedCart
        });
    }

    // 4. XÓA 1 ITEM KHỎI GIỎ HÀNG
    [HttpDelete("items/{itemId:long}")]
    public async Task<IActionResult> RemoveItem(long itemId)
    {
        if (!TryGetCurrentUserId(out var userId))
            return Unauthorized();

        var cartItem = await _context.CartItems
            .Include(ci => ci.Cart)
            .FirstOrDefaultAsync(ci => ci.Id == itemId && ci.Cart.UserId == userId);

        if (cartItem == null)
            return NotFound(new { message = "Không tìm thấy sản phẩm trong giỏ hàng." });

        var cart = cartItem.Cart;
        _context.CartItems.Remove(cartItem);
        cart.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        var updatedCart = await BuildCartResponseAsync(userId);
        return Ok(new
        {
            message = "Đã xóa sản phẩm khỏi giỏ hàng.",
            data = updatedCart
        });
    }

    // 5. XÓA TOÀN BỘ GIỎ HÀNG (Tiện ích bổ sung)
    [HttpDelete]
    public async Task<IActionResult> ClearCart()
    {
        if (!TryGetCurrentUserId(out var userId))
            return Unauthorized();

        var cart = await _context.Carts
            .Include(c => c.Items)
            .FirstOrDefaultAsync(c => c.UserId == userId);

        if (cart != null && cart.Items.Count > 0)
        {
            _context.CartItems.RemoveRange(cart.Items);
            cart.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }

        return Ok(new
        {
            message = "Đã làm trống giỏ hàng.",
            data = new CartResponseDto { Id = cart?.Id ?? 0, UserId = userId }
        });
    }

    // --- HÀM HỖ TRỢ ---
    private bool TryGetCurrentUserId(out long userId)
    {
        var claimValue = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return long.TryParse(claimValue, out userId);
    }

    private async Task<CartResponseDto> BuildCartResponseAsync(long userId)
    {
        var cart = await _context.Carts
            .AsNoTracking()
            .Include(c => c.Items)
                .ThenInclude(i => i.Variant)
                    .ThenInclude(v => v.Product)
                        .ThenInclude(p => p.Images)
            .FirstOrDefaultAsync(c => c.UserId == userId);

        if (cart == null)
        {
            return new CartResponseDto
            {
                Id = 0,
                UserId = userId,
                TotalItems = 0,
                Subtotal = 0,
                Items = new List<CartItemDto>()
            };
        }

        var itemDtos = cart.Items
            .OrderByDescending(i => i.Id)
            .Select(i =>
            {
                var product = i.Variant.Product;
                var primaryImage = product.Images.FirstOrDefault(img => img.IsPrimary)
                                   ?? product.Images.OrderBy(img => img.SortOrder).FirstOrDefault();

                return new CartItemDto
                {
                    Id = i.Id,
                    ProductId = product.Id,
                    ProductName = product.Name,
                    VariantId = i.VariantId,
                    SKU = i.Variant.SKU,
                    Color = i.Variant.Color,
                    Storage = i.Variant.Storage,
                    UnitPrice = i.Variant.Price,
                    CompareAtPrice = i.Variant.CompareAtPrice,
                    Quantity = i.Quantity,
                    LineTotal = i.Variant.Price * i.Quantity,
                    StockQuantity = i.Variant.StockQuantity,
                    PrimaryImageUrl = primaryImage?.ImageUrl,
                    IsAvailable = i.Variant.IsActive && product.IsActive && !product.IsDeleted && i.Variant.StockQuantity >= i.Quantity
                };
            })
            .ToList();

        return new CartResponseDto
        {
            Id = cart.Id,
            UserId = cart.UserId,
            UpdatedAt = cart.UpdatedAt,
            TotalItems = itemDtos.Sum(x => x.Quantity),
            Subtotal = itemDtos.Sum(x => x.LineTotal),
            Items = itemDtos
        };
    }
}