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
public class OrdersController : ControllerBase
{
    private readonly ElectronicsStoreContext _context;

    private static readonly HashSet<string> AllowedPaymentMethods = new(StringComparer.OrdinalIgnoreCase)
    {
        "COD", "BankTransfer", "VNPay", "VietQR", "MoMo", "ZaloPay"
    };

    public OrdersController(ElectronicsStoreContext context)
    {
        _context = context;
    }
    
    // 1. CHECKOUT: TẠO ĐƠN HÀNG TỪ GIỎ HÀNG BẰNG TRANSACTION
    [HttpPost("checkout")]
    public async Task<IActionResult> Checkout([FromBody] CheckoutRequest request)
    {
        // Nhiều người cùng đặt có thể gây deadlock hiếm gặp (SQL Server chọn 1 giao dịch làm nạn nhân,
        // đã tự rollback) -> thử lại tối đa 3 lần với giỏ hàng/tồn kho đọc lại từ đầu.
        for (var attempt = 1; attempt <= 3; attempt++)
        {
            try
            {
                return await CheckoutCoreAsync(request);
            }
            catch (Microsoft.Data.SqlClient.SqlException ex) when (ex.Number == 1205)
            {
                _context.ChangeTracker.Clear();
                await Task.Delay(50 * attempt);
            }
        }

        return StatusCode(409, new { message = "Hệ thống đang bận xử lý đơn khác. Vui lòng thử đặt hàng lại." });
    }

    private async Task<IActionResult> CheckoutCoreAsync(CheckoutRequest request)
    {
        if (!TryGetCurrentUserId(out var userId))
            return Unauthorized();

        if (!AllowedPaymentMethods.Contains(request.PaymentMethod))
        {
            return BadRequest(new
            {
                message = "Phương thức thanh toán không hợp lệ. Chỉ hỗ trợ: COD, BankTransfer, VNPay, VietQR, MoMo, ZaloPay."
            });
        }

        // Lấy giỏ hàng hiện tại của user
        var cart = await _context.Carts
            .Include(c => c.Items)
                .ThenInclude(i => i.Variant)
                    .ThenInclude(v => v.Product)
            .FirstOrDefaultAsync(c => c.UserId == userId);

        if (cart == null || cart.Items.Count == 0)
            return BadRequest(new { message = "Giỏ hàng đang trống, không thể đặt hàng." });

        // Kiểm tra tất cả sản phẩm trong giỏ còn đang kinh doanh
        foreach (var item in cart.Items)
        {
            if (item.Variant.Product.IsDeleted || !item.Variant.Product.IsActive || !item.Variant.IsActive)
            {
                return BadRequest(new
                {
                    message = $"Sản phẩm '{item.Variant.Product.Name}' ({item.Variant.SKU}) đã ngừng kinh doanh. Vui lòng xóa khỏi giỏ trước khi đặt hàng."
                });
            }
        }

        // Chuẩn hóa tên phương thức thanh toán đúng chữ hoa/thường theo CHECK constraint DB
        var normalizedPaymentMethod = AllowedPaymentMethods.First(m =>
            m.Equals(request.PaymentMethod, StringComparison.OrdinalIgnoreCase));

        await using var transaction = await _context.Database.BeginTransactionAsync();
        try
        {
            var now = DateTime.UtcNow;
            var subtotal = cart.Items.Sum(i => i.Variant.Price * i.Quantity);
            var discountAmount = 0m;
            var shippingFee = request.ShippingFee;
            var totalAmount = subtotal - discountAmount + shippingFee;

            // Trừ tồn kho nguyên tử: chỉ trừ khi còn đủ hàng (WHERE StockQuantity >= qty).
            // Hai người mua cùng lúc không thể làm tồn kho âm; thiếu hàng thì rollback toàn bộ đơn.
            // Luôn trừ theo thứ tự VariantId tăng dần để các giao dịch khóa dòng cùng thứ tự (tránh deadlock).
            foreach (var item in cart.Items.GroupBy(i => i.VariantId).Select(g => new { VariantId = g.Key, Qty = g.Sum(x => x.Quantity) }).OrderBy(x => x.VariantId))
            {
                var affected = await _context.Database.ExecuteSqlInterpolatedAsync(
                    $"UPDATE ProductVariants SET StockQuantity = StockQuantity - {item.Qty} WHERE Id = {item.VariantId} AND StockQuantity >= {item.Qty}");

                if (affected == 0)
                {
                    await transaction.RollbackAsync();
                    var v = cart.Items.First(i => i.VariantId == item.VariantId).Variant;
                    var left = await _context.ProductVariants.AsNoTracking()
                        .Where(x => x.Id == item.VariantId).Select(x => x.StockQuantity).FirstOrDefaultAsync();
                    return BadRequest(new
                    {
                        message = left <= 0
                            ? $"Sản phẩm '{v.Product.Name}' đã hết hàng. Vui lòng xóa khỏi giỏ trước khi đặt hàng."
                            : $"Sản phẩm '{v.Product.Name}' chỉ còn {left} trong kho, bạn đang đặt {item.Qty}. Vui lòng giảm số lượng."
                    });
                }
            }

            var orderCode = $"ORD-{now:yyyyMMddHHmmss}-{Random.Shared.Next(1000, 9999)}";

            // Bước A: Tạo Order
            var order = new Order
            {
                OrderCode = orderCode,
                UserId = userId,
                AddressId = request.AddressId,
                RecipientName = request.RecipientName.Trim(),
                PhoneNumber = request.PhoneNumber.Trim(),
                ShippingAddress = request.ShippingAddress.Trim(),
                Subtotal = subtotal,
                DiscountAmount = discountAmount,
                ShippingFee = shippingFee,
                TotalAmount = totalAmount,
                Status = "Pending",
                Note = request.Note?.Trim(),
                CreatedAt = now
            };

            _context.Orders.Add(order);
            await _context.SaveChangesAsync();

            // Bước B: Copy các sản phẩm từ CartItems sang OrderItems (OrderDetails)
            var orderItems = cart.Items.Select(ci => new OrderItem
            {
                OrderId = order.Id,
                VariantId = ci.VariantId,
                ProductName = ci.Variant.Product.Name,
                SKU = ci.Variant.SKU,
                UnitPrice = ci.Variant.Price,
                Quantity = ci.Quantity,
                TotalPrice = ci.Variant.Price * ci.Quantity
            }).ToList();

            _context.OrderItems.AddRange(orderItems);

            // Bước C: Ghi nhận thông tin thanh toán & lịch sử trạng thái khởi tạo
            _context.Payments.Add(new Payment
            {
                OrderId = order.Id,
                PaymentMethod = normalizedPaymentMethod,
                Amount = totalAmount,
                Status = "Pending",
                CreatedAt = now
            });

            _context.OrderStatusHistories.Add(new OrderStatusHistory
            {
                OrderId = order.Id,
                OldStatus = null,
                NewStatus = "Pending",
                ChangedBy = userId,
                Note = "Khách hàng đặt đơn hàng mới",
                CreatedAt = now
            });

            // Bước D: Xóa toàn bộ CartItems sau khi đã chuyển sang đơn hàng
            _context.CartItems.RemoveRange(cart.Items);
            cart.UpdatedAt = now;

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            var detailDto = await BuildOrderDetailDtoAsync(order.Id);
            return CreatedAtAction(nameof(GetOrderById), new { id = order.Id }, new
            {
                message = "Đặt hàng thành công.",
                data = detailDto
            });
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    // 2. XEM DANH SÁCH ĐƠN HÀNG CỦA USER (CÓ PHÂN TRANG & LỌC TRẠNG THÁI)
    [HttpGet]
    public async Task<IActionResult> GetMyOrders(
        [FromQuery] int? page = null,
        [FromQuery] int pageIndex = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] string? status = null)
    {
        if (!TryGetCurrentUserId(out var userId))
            return Unauthorized();

        int currentPage = page ?? pageIndex;

        var query = _context.Orders
            .AsNoTracking()
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.Variant)
                    .ThenInclude(v => v.Product)
                        .ThenInclude(p => p.Images)
            .Include(o => o.Payments)
            .Where(o => o.UserId == userId)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(status))
        {
            var normalizedStatus = status.Trim();
            query = query.Where(o => o.Status == normalizedStatus);
        }

        query = query.OrderByDescending(o => o.CreatedAt);

        var pagedOrders = await PagedResult<Order>.CreateAsync(query, currentPage, pageSize);

        var result = new PagedResult<OrderListItemDto>
        {
            TotalCount = pagedOrders.TotalCount,
            PageIndex = pagedOrders.PageIndex,
            PageSize = pagedOrders.PageSize,
            Items = pagedOrders.Items.Select(o =>
            {
                var firstItem = o.OrderItems.OrderBy(i => i.Id).FirstOrDefault();
                var firstProductImages = firstItem?.Variant?.Product?.Images;
                var firstImage = firstProductImages?.FirstOrDefault(img => img.IsPrimary)
                                 ?? firstProductImages?.OrderBy(img => img.SortOrder).FirstOrDefault();
                var latestPayment = o.Payments.OrderByDescending(p => p.CreatedAt).FirstOrDefault();

                return new OrderListItemDto
                {
                    Id = o.Id,
                    OrderCode = o.OrderCode,
                    Status = o.Status,
                    PaymentMethod = latestPayment?.PaymentMethod ?? "COD",
                    PaymentStatus = latestPayment?.Status ?? "Pending",
                    TotalQuantity = o.OrderItems.Sum(i => i.Quantity),
                    TotalAmount = o.TotalAmount,
                    FirstProductName = firstItem?.ProductName,
                    FirstProductImageUrl = firstImage?.ImageUrl,
                    CreatedAt = o.CreatedAt
                };
            }).ToList()
        };

        return Ok(result);
    }

    // 3. XEM CHI TIẾT ĐƠN HÀNG CỦA USER THEO ID
    [HttpGet("{id:long}")]
    public async Task<IActionResult> GetOrderById(long id)
    {
        if (!TryGetCurrentUserId(out var userId))
            return Unauthorized();

        var orderOwnerId = await _context.Orders
            .AsNoTracking()
            .Where(o => o.Id == id)
            .Select(o => (long?)o.UserId)
            .FirstOrDefaultAsync();

        if (orderOwnerId == null)
            return NotFound(new { message = "Không tìm thấy đơn hàng." });

        if (orderOwnerId.Value != userId && !User.IsInRole("Admin"))
            return Forbid();

        var detailDto = await BuildOrderDetailDtoAsync(id);
        return Ok(detailDto);
    }

    // --- HÀM HỖ TRỢ ---
    private bool TryGetCurrentUserId(out long userId)
    {
        var claimValue = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return long.TryParse(claimValue, out userId);
    }

    private async Task<OrderDetailDto?> BuildOrderDetailDtoAsync(long orderId)
    {
        var order = await _context.Orders
            .AsNoTracking()
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.Variant)
                    .ThenInclude(v => v.Product)
                        .ThenInclude(p => p.Images)
            .Include(o => o.Payments)
            .Include(o => o.StatusHistories)
            .FirstOrDefaultAsync(o => o.Id == orderId);

        if (order == null) return null;

        var latestPayment = order.Payments.OrderByDescending(p => p.CreatedAt).FirstOrDefault();

        return new OrderDetailDto
        {
            Id = order.Id,
            OrderCode = order.OrderCode,
            UserId = order.UserId,
            RecipientName = order.RecipientName,
            PhoneNumber = order.PhoneNumber,
            ShippingAddress = order.ShippingAddress,
            Subtotal = order.Subtotal,
            DiscountAmount = order.DiscountAmount,
            ShippingFee = order.ShippingFee,
            TotalAmount = order.TotalAmount,
            Status = order.Status,
            Note = order.Note,
            PaymentMethod = latestPayment?.PaymentMethod ?? "COD",
            PaymentStatus = latestPayment?.Status ?? "Pending",
            CreatedAt = order.CreatedAt,
            UpdatedAt = order.UpdatedAt,
            Items = order.OrderItems
                .OrderBy(i => i.Id)
                .Select(i =>
                {
                    var images = i.Variant?.Product?.Images;
                    var primaryImage = images?.FirstOrDefault(img => img.IsPrimary)
                                       ?? images?.OrderBy(img => img.SortOrder).FirstOrDefault();

                    return new OrderItemDetailDto
                    {
                        Id = i.Id,
                        ProductId = i.Variant?.ProductId ?? 0,
                        VariantId = i.VariantId,
                        ProductName = i.ProductName,
                        SKU = i.SKU,
                        Color = i.Variant?.Color,
                        Storage = i.Variant?.Storage,
                        PrimaryImageUrl = primaryImage?.ImageUrl,
                        UnitPrice = i.UnitPrice,
                        Quantity = i.Quantity,
                        TotalPrice = i.TotalPrice
                    };
                }).ToList(),
            StatusHistory = order.StatusHistories
                .OrderByDescending(h => h.CreatedAt)
                .Select(h => new OrderStatusHistoryDto
                {
                    Id = h.Id,
                    OldStatus = h.OldStatus,
                    NewStatus = h.NewStatus,
                    Note = h.Note,
                    CreatedAt = h.CreatedAt
                }).ToList()
        };
    }
}