namespace backend.Models;

public class OrderStatusHistory
{
    public long Id { get; set; }
    public long OrderId { get; set; }
    public string? OldStatus { get; set; }
    public string NewStatus { get; set; } = string.Empty;
    public long? ChangedBy { get; set; }
    public string? Note { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public Order Order { get; set; } = null!;
    public User? ChangedByUser { get; set; }
}