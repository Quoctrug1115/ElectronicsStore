namespace backend.Models;

public class ProductSpecification
{
    public long Id { get; set; }
    public long ProductId { get; set; }
    public string SpecificationName { get; set; } = string.Empty;
    public string SpecificationValue { get; set; } = string.Empty;

    public Product Product { get; set; } = null!;
}