using backend.Data;
using backend.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

[ApiController]
[Route("api/admin/stats")]
[Authorize(Roles = "Admin")]
public class AdminStatsController : ControllerBase
{
    private static readonly string[] InProgressStatuses = { "Pending", "Confirmed", "Processing", "Shipped" };

    private readonly ElectronicsStoreContext _context;

    public AdminStatsController(ElectronicsStoreContext context)
    {
        _context = context;
    }

    // THỐNG KÊ DOANH THU: tổng, hôm nay, tháng này, dự kiến và doanh thu từng ngày gần đây.
    // Doanh thu chỉ tính đơn đã giao (Delivered), theo ngày giao. Giờ trong DB là UTC nên
    // client truyền tzOffsetMinutes (ví dụ 420 cho UTC+7) để chia ngày đúng múi giờ của người dùng.
    [HttpGet("revenue")]
    public async Task<IActionResult> GetRevenue(
        [FromQuery] int days = 7,
        [FromQuery] int tzOffsetMinutes = 0)
    {
        if (days < 1 || days > 90)
            return BadRequest(new { message = "days phải từ 1 đến 90." });
        if (tzOffsetMinutes < -840 || tzOffsetMinutes > 840)
            return BadRequest(new { message = "tzOffsetMinutes không hợp lệ." });

        var offset = TimeSpan.FromMinutes(tzOffsetMinutes);
        var today = (DateTime.UtcNow + offset).Date;

        var delivered = await _context.Orders
            .AsNoTracking()
            .Where(o => o.Status == "Delivered")
            .Select(o => new
            {
                o.TotalAmount,
                o.CreatedAt,
                o.UpdatedAt,
                DeliveredAt = o.StatusHistories
                    .Where(h => h.NewStatus == "Delivered")
                    .OrderByDescending(h => h.CreatedAt)
                    .Select(h => (DateTime?)h.CreatedAt)
                    .FirstOrDefault()
            })
            .ToListAsync();

        // Ngày giao (theo múi giờ client): ưu tiên thời điểm chuyển sang Delivered trong lịch sử
        var rows = delivered
            .Select(o => new
            {
                o.TotalAmount,
                Day = ((o.DeliveredAt ?? o.UpdatedAt ?? o.CreatedAt) + offset).Date
            })
            .ToList();

        var statusCounts = await _context.Orders
            .AsNoTracking()
            .GroupBy(o => o.Status)
            .Select(g => new { Status = g.Key, Count = g.Count() })
            .ToListAsync();

        var inProgress = await _context.Orders
            .AsNoTracking()
            .Where(o => InProgressStatuses.Contains(o.Status))
            .Select(o => o.TotalAmount)
            .ToListAsync();

        var monthStart = new DateTime(today.Year, today.Month, 1);

        var daily = Enumerable.Range(0, days)
            .Select(i => today.AddDays(-(days - 1 - i)))
            .Select(d => new DailyRevenueDto
            {
                Date = d.ToString("yyyy-MM-dd"),
                Revenue = rows.Where(r => r.Day == d).Sum(r => r.TotalAmount),
                Orders = rows.Count(r => r.Day == d)
            })
            .ToList();

        return Ok(new RevenueStatsDto
        {
            TotalRevenue = rows.Sum(r => r.TotalAmount),
            DeliveredOrders = rows.Count,
            TodayRevenue = rows.Where(r => r.Day == today).Sum(r => r.TotalAmount),
            TodayOrders = rows.Count(r => r.Day == today),
            MonthRevenue = rows.Where(r => r.Day >= monthStart).Sum(r => r.TotalAmount),
            MonthOrders = rows.Count(r => r.Day >= monthStart),
            InProgressRevenue = inProgress.Sum(),
            InProgressOrders = inProgress.Count,
            CancelledOrders = statusCounts.FirstOrDefault(s => s.Status == "Cancelled")?.Count ?? 0,
            OrdersByStatus = statusCounts.ToDictionary(s => s.Status, s => s.Count),
            DailyRevenue = daily
        });
    }
}
