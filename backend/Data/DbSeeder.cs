using backend.Models;
using Microsoft.EntityFrameworkCore;

namespace backend.Data;

public static class DbSeeder
{
    public static async Task SeedAsync(IServiceProvider serviceProvider, bool isSqlite)
    {
        using var scope = serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ElectronicsStoreContext>();

        if (isSqlite)
        {
            await context.Database.EnsureCreatedAsync();
        }

        // 1. Seed Roles
        if (!await context.Roles.AnyAsync())
        {
            context.Roles.AddRange(
                new Role { Name = "Admin", Description = "Quản trị viên hệ thống" },
                new Role { Name = "Member", Description = "Thành viên / khách hàng" }
            );
            await context.SaveChangesAsync();
        }

        // 2. Seed tài khoản Admin
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

        // 3. Seed Categories & 1 Product mẫu để test ràng buộc xóa
        if (!await context.Categories.AnyAsync())
        {
            var phoneCategory = new Category
            {
                Name = "Điện thoại",
                Description = "Các dòng điện thoại thông minh"
            };

            context.Categories.AddRange(
                phoneCategory,
                new Category { Name = "Laptop", Description = "Máy tính xách tay" },
                new Category { Name = "Tablet", Description = "Máy tính bảng" },
                new Category { Name = "Phụ kiện", Description = "Phụ kiện điện tử" },
                new Category { Name = "Màn hình", Description = "Màn hình máy tính" }
            );
            await context.SaveChangesAsync();

            // Tạo sẵn 1 sản phẩm thuộc danh mục "Điện thoại" để test AnyAsync chặn xóa
            if (!await context.Products.AnyAsync())
            {
                context.Products.Add(new Product
                {
                    CategoryId = phoneCategory.Id,
                    BrandId = 1,
                    Name = "iPhone 16 Pro Max",
                    Description = "Sản phẩm mẫu kiểm tra ràng buộc danh mục"
                });
                await context.SaveChangesAsync();
            }
        }
    }
}