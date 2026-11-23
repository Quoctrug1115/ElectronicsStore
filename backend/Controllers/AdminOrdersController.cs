using System.Security.Claims;
using backend.Data;
using backend.DTOs;
using backend.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

[ApiController]
[Route("api/admin/orders")]
[Authorize(Roles = "Admin")]
public class AdminOrdersController : ControllerBase
{
    private readonly ElectronicsStoreContext _context;

    // Map chuẩn hóa cả tên tiếng Anh (DB constraint) lẫn nhãn tiếng Việt (lịch trình / UI)
    private static readonly Dictionary<string, string> StatusNormalizer = new(StringComparer.OrdinalIgnoreCase)
    {
        ["Pending"] = "Pending",
        ["Chờ xác nhận"] = "Pending",

        ["Confirmed"] = "Confirmed",
        ["Đã xác nhận"] = "Confirmed",

        ["Processing"] = "Processing",
        ["Đang xử lý"] = "Processing",

        ["Shipped"] = "Shipped",
        ["Shipping"] = "Shipped",
        ["Đang giao"] = "Shipped",

        ["Delivered"] = "Delivered",
        ["Hoàn thành"] = "Delivered",
        ["Đã giao"] = "Delivered",

        ["Cancelled"] = "Cancelled",
        ["Hủy"] = "Cancelled",
        ["Đã hủy"] = "Cancelled",

        ["Returned"] = "Returned",
        ["Đã trả hàng"] = "Returned"
    };

    private static readonly HashSet<string> TerminalStatuses = new(StringComparer.OrdinalIgnoreCase)
    {
        "Delivered", "Cancelled", "Returned"
    };

    public AdminOrdersController(ElectronicsStoreContext context)
    {
        _context = context;
    }

    // 1. DANH SÁCH TẤT CẢ ĐƠN HÀNG (Hỗ trợ lọc trạng thái, tìm kiếm & ngày đặt)
    [HttpGet]
    public async Task<IActionResult> GetAllOrders(
        [FromQuery] int? page = null,
        [FromQuery] int pageIndex = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] string? status = null,
        [FromQuery] string? keyword = null,
        [FromQuery] DateTime? fromDate = null,
        [FromQuery] DateTime? toDate = null)
    {
        int currentPage = page ?? pageIndex;

        var query = _context.Orders
            .AsNoTracking()
            .Include(o => o.User)
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.Variant)
                    .ThenInclude(v => v.Product)
                        .ThenInclude(p => p.Images)
            .Include(o => o.Payments)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(status))
        {
            var trimmed = status.Trim();
            var normalized = StatusNormalizer.TryGetValue(trimmed, out var mapped) ? mapped : trimmed;
            query = query.Where(o => o.Status == normalized);
        }

        if (!string.IsNullOrWhiteSpace(keyword))
        {
            var pattern = $"%{keyword.Trim()}%";
            query = query.Where(o =>
                EF.Functions.Like(o.OrderCode, pattern) ||
                EF.Functions.Like(o.RecipientName, pattern) ||
                EF.Functions.Like(o.PhoneNumber, pattern) ||
                EF.Functions.Like(o.User.FullName, pattern) ||
                EF.Functions.Like(o.User.Email, pattern));
        }

        if (fromDate.HasValue)
        {
            var fromUtc = fromDate.Value.Date;
            query = query.Where(o => o.CreatedAt >= fromUtc);
        }

        if (toDate.HasValue)
        {
            // Lấy trọn hết ngày toDate (23:59:59.999)
            var toExclusive = toDate.Value.Date.AddDays(1);
            query = query.Where(o => o.CreatedAt < toExclusive);
        }

        query = query.OrderByDescending(o => o.CreatedAt);

        var pagedOrders = await PagedResult<Order>.CreateAsync(query, currentPage, pageSize);

        var result = new PagedResult<AdminOrderListItemDto>
        {
            TotalCount = pagedOrders.TotalCount,
            PageIndex = pagedOrders.PageIndex,
            PageSize = pagedOrders.PageSize,
            Items = pagedOrders.Items.Select(o =>
            {
                var firstItem = o.OrderItems.OrderBy(i => i.Id).FirstOrDefault();
                var images = firstItem?.Variant?.Product?.Images;
                var primaryImage = images?.FirstOrDefault(img => img.IsPrimary)
                                   ?? images?.OrderBy(img => img.SortOrder).FirstOrDefault();
                var latestPayment = o.Payments.OrderByDescending(p => p.CreatedAt).FirstOrDefault();

                return new AdminOrderListItemDto
                {
                    Id = o.Id,
                    OrderCode = o.OrderCode,
                    UserId = o.UserId,
                    CustomerName = o.User.FullName,
                    CustomerEmail = o.User.Email,
                    RecipientName = o.RecipientName,
                    PhoneNumber = o.PhoneNumber,
                    ShippingAddress = o.ShippingAddress,
                    Status = o.Status,
                    PaymentMethod = latestPayment?.PaymentMethod ?? "COD",
                    PaymentStatus = latestPayment?.Status ?? "Pending",
                    TotalQuantity = o.OrderItems.Sum(i => i.Quantity),
                    TotalAmount = o.TotalAmount,
                    FirstProductName = firstItem?.ProductName,
                    FirstProductImageUrl = primaryImage?.ImageUrl,
                    CreatedAt = o.CreatedAt,
                    UpdatedAt = o.UpdatedAt
                };
            }).ToList()
        };

        return Ok(result);
    }

    // 2. XEM CHI TIẾT ĐƠN HÀNG (ADMIN)
    [HttpGet("{id:long}")]
    public async Task<IActionResult> GetOrderDetail(long id)
    {
        var order = await _context.Orders
            .AsNoTracking()
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.Variant)
                    .ThenInclude(v => v.Product)
                        .ThenInclude(p => p.Images)
            .Include(o => o.Payments)
            .Include(o => o.StatusHistories)
            .FirstOrDefaultAsync(o => o.Id == id);

        if (order == null)
            return NotFound(new { message = "Không tìm thấy đơn hàng." });

        var latestPayment = order.Payments.OrderByDescending(p => p.CreatedAt).FirstOrDefault();

        return Ok(new OrderDetailDto
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
            Items = order.OrderItems.OrderBy(i => i.Id).Select(i =>
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
            StatusHistory = order.StatusHistories.OrderByDescending(h => h.CreatedAt).Select(h => new OrderStatusHistoryDto
            {
                Id = h.Id,
                OldStatus = h.OldStatus,
                NewStatus = h.NewStatus,
                Note = h.Note,
                CreatedAt = h.CreatedAt
            }).ToList()
        });
    }

    // 3. CẬP NHẬT TRẠNG THÁI ĐƠN HÀNG (Chờ xác nhận -> Đang giao -> Hoàn thành -> Hủy)
    [HttpPut("{id:long}/status")]
    public async Task<IActionResult> UpdateOrderStatus(long id, [FromBody] UpdateOrderStatusRequest request)
    {
        if (!StatusNormalizer.TryGetValue(request.Status.Trim(), out var newStatus))
        {
            return BadRequest(new
            {
                message = "Trạng thái không hợp lệ. Hỗ trợ: Pending (Chờ xác nhận), Confirmed (Đã xác nhận), Processing (Đang xử lý), Shipped (Đang giao), Delivered (Hoàn thành), Cancelled (Hủy)."
            });
        }

        var order = await _context.Orders
            .Include(o => o.OrderItems)
            .Include(o => o.Payments)
            .FirstOrDefaultAsync(o => o.Id == id);

        if (order == null)
            return NotFound(new { message = "Không tìm thấy đơn hàng." });

        var oldStatus = order.Status;
        if (oldStatus.Equals(newStatus, StringComparison.OrdinalIgnoreCase))
            return BadRequest(new { message = $"Đơn hàng hiện đã ở trạng thái '{newStatus}'." });

        // Chặn sửa đơn đã kết thúc (trừ trường hợp Delivered -> Returned)
        if (TerminalStatuses.Contains(oldStatus) && !(oldStatus == "Delivered" && newStatus == "Returned"))
            return BadRequest(new { message = $"Đơn hàng đã ở trạng thái '{oldStatus}', không thể cập nhật thêm." });

        // Chặn nhảy cóc trực tiếp từ Pending sang Delivered mà chưa qua Shipped
        if (oldStatus == "Pending" && newStatus == "Delivered")
            return BadRequest(new { message = "Đơn hàng cần chuyển sang 'Đang giao' (Shipped) trước khi 'Hoàn thành' (Delivered)." });

        // Chặn quay ngược trạng thái từ Shipped về Pending/Confirmed/Processing
        if (oldStatus == "Shipped" && (newStatus == "Pending" || newStatus == "Confirmed" || newStatus == "Processing"))
            return BadRequest(new { message = "Đơn hàng đang giao không thể quay lại trạng thái trước đó." });

        await using var transaction = await _context.Database.BeginTransactionAsync();
        try
        {
            var now = DateTime.UtcNow;

            // Hoàn lại tồn kho ProductVariants nếu hủy đơn hoặc trả hàng
            if ((newStatus == "Cancelled" || newStatus == "Returned") &&
                oldStatus != "Cancelled" && oldStatus != "Returned")
            {
                foreach (var item in order.OrderItems)
                {
                    await _context.Database.ExecuteSqlInterpolatedAsync(
                        $"UPDATE ProductVariants SET StockQuantity = StockQuantity + {item.Quantity} WHERE Id = {item.VariantId}");
                }
            }

            // Nếu giao thành công và thanh toán COD đang Pending -> đánh dấu Completed
            if (newStatus == "Delivered")
            {
                var codPayment = order.Payments.FirstOrDefault(p => p.PaymentMethod == "COD" && p.Status == "Pending");
                if (codPayment != null)
                {
                    codPayment.Status = "Completed";
                    codPayment.PaidAt = now;
                }
            }

            order.Status = newStatus;
            order.UpdatedAt = now;

            long? adminId = long.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var parsedId)
                ? parsedId
                : null;

            _context.OrderStatusHistories.Add(new OrderStatusHistory
            {
                OrderId = order.Id,
                OldStatus = oldStatus,
                NewStatus = newStatus,
                ChangedBy = adminId,
                Note = string.IsNullOrWhiteSpace(request.Note)
                    ? $"Admin cập nhật trạng thái từ '{oldStatus}' sang '{newStatus}'"
                    : request.Note.Trim(),
                CreatedAt = now
            });

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            return Ok(new
            {
                message = $"Đã cập nhật trạng thái đơn #{order.OrderCode} thành '{newStatus}'.",
                orderId = order.Id,
                orderCode = order.OrderCode,
                oldStatus,
                status = newStatus
            });
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }
}