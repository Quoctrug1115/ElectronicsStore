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
    private readonly IConfiguration _configuration;

    private static readonly HashSet<string> AllowedPaymentMethods = new(StringComparer.OrdinalIgnoreCase)
    {
        "COD", "BankTransfer", "VNPay", "VietQR", "MoMo", "ZaloPay"
    };

    public OrdersController(ElectronicsStoreContext context, IConfiguration configuration)
    {
        _context = context;
        _configuration = configuration;
    }

    // 1. CHECKOUT: TẠO ĐƠN HÀNG TỪ GIỎ HÀNG BẰNG TRANSACTION
    [HttpPost("checkout")]
    public async Task<IActionResult> Checkout([FromBody] CheckoutRequest request)
    {
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

        var cart = await _context.Carts
            .Include(c => c.Items)
                .ThenInclude(i => i.Variant)
                    .ThenInclude(v => v.Product)
            .FirstOrDefaultAsync(c => c.UserId == userId);

        if (cart == null || cart.Items.Count == 0)
            return BadRequest(new { message = "Giỏ hàng đang trống, không thể đặt hàng." });

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

            // Trừ tồn kho nguyên tử theo thứ tự VariantId tăng dần
            foreach (var item in cart.Items
                .GroupBy(i => i.VariantId)
                .Select(g => new { VariantId = g.Key, Qty = g.Sum(x => x.Quantity) })
                .OrderBy(x => x.VariantId))
            {
                var affected = await _context.Database.ExecuteSqlInterpolatedAsync(
                    $"UPDATE ProductVariants SET StockQuantity = StockQuantity - {item.Qty} WHERE Id = {item.VariantId} AND StockQuantity >= {item.Qty}");

                if (affected == 0)
                {
                    await transaction.RollbackAsync();
                    var v = cart.Items.First(i => i.VariantId == item.VariantId).Variant;
                    var left = await _context.ProductVariants.AsNoTracking()
                        .Where(x => x.Id == item.VariantId)
                        .Select(x => x.StockQuantity)
                        .FirstOrDefaultAsync();

                    return BadRequest(new
                    {
                        message = left <= 0
                            ? $"Sản phẩm '{v.Product.Name}' đã hết hàng. Vui lòng xóa khỏi giỏ trước khi đặt hàng."
                            : $"Sản phẩm '{v.Product.Name}' chỉ còn {left} trong kho, bạn đang đặt {item.Qty}. Vui lòng giảm số lượng."
                    });
                }
            }

            var orderCode = $"ORD-{now:yyyyMMddHHmmss}-{Random.Shared.Next(1000, 9999)}";

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
                Note = $"Khách hàng đặt đơn hàng mới ({normalizedPaymentMethod})",
                CreatedAt = now
            });

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

    // 2. XEM DANH SÁCH ĐƠN HÀNG CỦA USER (PHÂN TRANG, TÌM KIẾM & LỌC NGÀY/TRẠNG THÁI)
    [HttpGet]
    public async Task<IActionResult> GetMyOrders(
        [FromQuery] int? page = null,
        [FromQuery] int pageIndex = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] string? status = null,
        [FromQuery] string? keyword = null,
        [FromQuery] DateTime? fromDate = null,
        [FromQuery] DateTime? toDate = null)
    {
        if (!TryGetCurrentUserId(out var userId))
            return Unauthorized();

        if (fromDate.HasValue && toDate.HasValue && fromDate.Value.Date > toDate.Value.Date)
            return BadRequest(new { message = "Ngày bắt đầu (fromDate) không được lớn hơn ngày kết thúc (toDate)." });

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
            var normalizedStatus = status.Trim().ToLowerInvariant() switch
            {
                "pending" or "chờ xác nhận" => "Pending",
                "confirmed" or "đã xác nhận" => "Confirmed",
                "processing" or "đang xử lý" => "Processing",
                "shipping" or "shipped" or "đang giao" => "Shipped",
                "delivered" or "đã giao" or "hoàn thành" => "Delivered",
                "cancelled" or "đã hủy" or "hủy" => "Cancelled",
                "returned" or "đã trả hàng" => "Returned",
                _ => status.Trim()
            };
            query = query.Where(o => o.Status == normalizedStatus);
        }

        if (!string.IsNullOrWhiteSpace(keyword))
        {
            var pattern = $"%{keyword.Trim()}%";
            query = query.Where(o =>
                EF.Functions.Like(o.OrderCode, pattern) ||
                EF.Functions.Like(o.RecipientName, pattern) ||
                EF.Functions.Like(o.PhoneNumber, pattern) ||
                o.OrderItems.Any(oi =>
                    EF.Functions.Like(oi.ProductName, pattern) ||
                    EF.Functions.Like(oi.SKU, pattern)));
        }

        if (fromDate.HasValue)
        {
            var fromUtc = fromDate.Value.Date;
            query = query.Where(o => o.CreatedAt >= fromUtc);
        }

        if (toDate.HasValue)
        {
            var toExclusive = toDate.Value.Date.AddDays(1);
            query = query.Where(o => o.CreatedAt < toExclusive);
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

    // 3. XEM CHI TIẾT ĐƠN HÀNG CỦA USER THEO ID (KÈM MÃ VIETQR NẾU THANH TOÁN VIETQR)
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

    // 4. KHÁCH HÀNG HỦY ĐƠN HÀNG (KHI ĐƠN Ở TRẠNG THÁI PENDING / CONFIRMED)
    [HttpPost("{id:long}/cancel")]
    public async Task<IActionResult> CancelOrder(long id)
    {
        if (!TryGetCurrentUserId(out var userId))
            return Unauthorized();

        var order = await _context.Orders
            .Include(o => o.OrderItems)
            .Include(o => o.Payments)
            .FirstOrDefaultAsync(o => o.Id == id);

        if (order == null)
            return NotFound(new { message = "Không tìm thấy đơn hàng." });

        if (order.UserId != userId && !User.IsInRole("Admin"))
            return Forbid();

        if (order.Status != "Pending" && order.Status != "Confirmed")
            return BadRequest(new { message = "Chỉ có thể hủy đơn hàng đang ở trạng thái Chờ xác nhận hoặc Đã xác nhận." });

        await using var transaction = await _context.Database.BeginTransactionAsync();
        try
        {
            var now = DateTime.UtcNow;
            var oldStatus = order.Status;

            // Hoàn lại tồn kho
            foreach (var item in order.OrderItems.OrderBy(i => i.VariantId))
            {
                await _context.Database.ExecuteSqlInterpolatedAsync(
                    $"UPDATE ProductVariants SET StockQuantity = StockQuantity + {item.Quantity} WHERE Id = {item.VariantId}");
            }

            order.Status = "Cancelled";
            order.UpdatedAt = now;

            var latestPayment = order.Payments.OrderByDescending(p => p.CreatedAt).FirstOrDefault();
            if (latestPayment != null && latestPayment.Status == "Pending")
            {
                latestPayment.Status = "Failed";
            }

            _context.OrderStatusHistories.Add(new OrderStatusHistory
            {
                OrderId = order.Id,
                OldStatus = oldStatus,
                NewStatus = "Cancelled",
                ChangedBy = userId,
                Note = "Khách hàng hủy đơn hàng",
                CreatedAt = now
            });

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            return Ok(new { message = "Đã hủy đơn hàng thành công." });
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    // 5. KHÁCH HÀNG XÁC NHẬN ĐÃ CHUYỂN KHOẢN VIETQR
    [HttpPost("{id:long}/confirm-payment")]
    public async Task<IActionResult> ConfirmVietQrPayment(long id)
    {
        if (!TryGetCurrentUserId(out var userId))
            return Unauthorized();

        var order = await _context.Orders
            .Include(o => o.Payments)
            .FirstOrDefaultAsync(o => o.Id == id);

        if (order == null)
            return NotFound(new { message = "Không tìm thấy đơn hàng." });

        if (order.UserId != userId)
            return Forbid();

        if (order.Status == "Cancelled" || order.Status == "Returned")
            return BadRequest(new { message = "Đơn hàng đã hủy, không thể xác nhận thanh toán." });

        var payment = order.Payments.OrderByDescending(p => p.CreatedAt).FirstOrDefault();
        if (payment == null || !payment.PaymentMethod.Equals("VietQR", StringComparison.OrdinalIgnoreCase))
            return BadRequest(new { message = "Đơn hàng này không sử dụng phương thức thanh toán VietQR." });

        if (payment.Status == "Completed")
            return Ok(new { message = "Thanh toán đã được xác nhận trước đó." });

        var now = DateTime.UtcNow;
        payment.TransactionCode = $"VQR-{order.OrderCode}";
        payment.GatewayResponse = "Khách hàng xác nhận đã chuyển khoản qua VietQR";
        order.UpdatedAt = now;

        _context.OrderStatusHistories.Add(new OrderStatusHistory
        {
            OrderId = order.Id,
            OldStatus = order.Status,
            NewStatus = order.Status,
            ChangedBy = userId,
            Note = $"Khách hàng báo đã chuyển khoản VietQR (Nội dung: {order.OrderCode})",
            CreatedAt = now
        });

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Đã ghi nhận thông tin chuyển khoản. Cửa hàng sẽ xác nhận đơn hàng của bạn trong giây lát."
        });
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
        var paymentMethod = latestPayment?.PaymentMethod ?? "COD";

        VietQrInfoDto? vietQr = null;
        if (paymentMethod.Equals("VietQR", StringComparison.OrdinalIgnoreCase))
        {
            var bankId = _configuration["VietQR:BankId"] ?? "MB";
            var accountNo = _configuration["VietQR:AccountNo"] ?? "0909123456";
            var accountName = _configuration["VietQR:AccountName"] ?? "ELECTRONICS STORE";
            var template = _configuration["VietQR:Template"] ?? "compact2";
            var amount = (long)Math.Round(order.TotalAmount, MidpointRounding.AwayFromZero);
            var addInfo = order.OrderCode;

            var qrUrl = $"https://img.vietqr.io/image/{Uri.EscapeDataString(bankId)}-{Uri.EscapeDataString(accountNo)}-{Uri.EscapeDataString(template)}.png"
                      + $"?amount={amount}&addInfo={Uri.EscapeDataString(addInfo)}&accountName={Uri.EscapeDataString(accountName)}";

            vietQr = new VietQrInfoDto
            {
                BankId = bankId,
                AccountNo = accountNo,
                AccountName = accountName,
                Amount = amount,
                AddInfo = addInfo,
                QrImageUrl = qrUrl
            };
        }

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
            PaymentMethod = paymentMethod,
            PaymentStatus = latestPayment?.Status ?? "Pending",
            VietQrUrl = vietQr?.QrImageUrl,
            VietQr = vietQr,
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