namespace backend.Models;

public class Payment
{
    public long Id { get; set; }
    public long OrderId { get; set; }
    public string PaymentMethod { get; set; } = "COD";
    public decimal Amount { get; set; }
    public string Status { get; set; } = "Pending";
    public string? TransactionCode { get; set; }
    public string? GatewayResponse { get; set; }
    public DateTime? PaidAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public Order Order { get; set; } = null!;
}