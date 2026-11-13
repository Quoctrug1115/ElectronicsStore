using Microsoft.EntityFrameworkCore;

namespace backend.Data;

public class ElectronicsStoreContext : DbContext
{
    public ElectronicsStoreContext (DbContextOptions options) : base(options) { }

}