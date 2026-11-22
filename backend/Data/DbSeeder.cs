using backend.Models;
using Microsoft.EntityFrameworkCore;

namespace backend.Data;

public static class DbSeeder
{
    public static async Task SeedAsync(IServiceProvider serviceProvider)
    {
        using var scope = serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ElectronicsStoreContext>();

        if (!await context.Roles.AnyAsync())
        {
            context.Roles.AddRange(
                new Role { Name = "Admin", Description = "Quản trị viên hệ thống" },
                new Role { Name = "Member", Description = "Thành viên / khách hàng" }
            );
            await context.SaveChangesAsync();
        }

        const string adminEmail = "admin@electronics.com";
        if (!await context.Users.AnyAsync(u => u.Email == adminEmail && !u.IsDeleted))
        {
            var adminRole = await context.Roles.FirstAsync(r => r.Name == "Admin");

            var adminUser = new User
            {
                FullName = "System Administrator",
                Email = adminEmail,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Admin@123"),
                PhoneNumber = "0900000000",
                EmailConfirmed = true,
                IsActive = true,
                IsDeleted = false,
                CreatedAt = DateTime.UtcNow
            };

            context.Users.Add(adminUser);
            await context.SaveChangesAsync();

            context.UserRoles.Add(new UserRole
            {
                UserId = adminUser.Id,
                RoleId = adminRole.Id
            });
            await context.SaveChangesAsync();
        }

        if (!await context.Brands.AnyAsync())
        {
            context.Brands.AddRange(
                new Brand { Name = "Apple", Description = "Thương hiệu Apple" },
                new Brand { Name = "Samsung", Description = "Thương hiệu Samsung" },
                new Brand { Name = "Dell", Description = "Thương hiệu Dell" },
                new Brand { Name = "ASUS", Description = "Thương hiệu ASUS" },
                new Brand { Name = "Lenovo", Description = "Thương hiệu Lenovo" }
            );
            await context.SaveChangesAsync();
        }

        if (!await context.Categories.AnyAsync())
        {
            var phoneCategory = new Category { Name = "Điện thoại", Description = "Các dòng điện thoại thông minh" };
            context.Categories.AddRange(
                phoneCategory,
                new Category { Name = "Laptop", Description = "Máy tính xách tay" },
                new Category { Name = "Tablet", Description = "Máy tính bảng" },
                new Category { Name = "Phụ kiện", Description = "Phụ kiện điện tử" },
                new Category { Name = "Màn hình", Description = "Màn hình máy tính" }
            );
            await context.SaveChangesAsync();

            var appleBrand = await context.Brands.FirstAsync(b => b.Name == "Apple");
            var sampleProduct = new Product
            {
                CategoryId = phoneCategory.Id,
                BrandId = appleBrand.Id,
                Name = "iPhone 16 Pro Max",
                Description = "Chip A18 Pro, màn hình Super Retina XDR 6.9 inch",
                Variants = new List<ProductVariant>
                {
                    new()
                    {
                        SKU = "IP16PM-256-TI",
                        Color = "Titan Tự Nhiên",
                        Storage = "256GB",
                        Price = 34990000,
                        CompareAtPrice = 36990000,
                        StockQuantity = 50
                    }
                }
            };
            context.Products.Add(sampleProduct);
            await context.SaveChangesAsync();
        }
    }
}