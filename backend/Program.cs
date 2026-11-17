using System.Security.Claims;
using System.Text;
using backend.Data;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// 1. Chọn SQLite hoặc SQL Server dựa theo cấu hình UseSqlite
bool useSqlite = builder.Configuration.GetValue<bool>("UseSqlite");

if (useSqlite)
{
    string? sqliteConn = builder.Configuration.GetConnectionString("SqliteConnection");
    builder.Services.AddDbContext<ElectronicsStoreContext>(p => p.UseSqlite(sqliteConn));
}
else
{
    string? sqlServerConn = builder.Configuration.GetConnectionString("ElectronicsStore");
    builder.Services.AddDbContext<ElectronicsStoreContext>(p => p.UseSqlServer(sqlServerConn));
}

builder.Services.AddHttpContextAccessor();
builder.Services.AddControllers();

builder.Services.AddAuthentication(p =>
{
    p.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    p.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddCookie()
.AddJwtBearer(p =>
{
    p.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidIssuer = builder.Configuration["Jwt:Issuer"],
        ValidAudience = builder.Configuration["Jwt:Audience"],
        ValidateLifetime = true,
        IssuerSigningKey = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"] ?? throw new KeyNotFoundException("Jwt:Key"))
        ),
        RoleClaimType = ClaimTypes.Role,
        NameClaimType = ClaimTypes.NameIdentifier
    };
});

builder.Services.AddAuthorization();

builder.Services.AddCors(options =>
{
    options.AddPolicy("FlutterPolicy", policy =>
    {
        policy.WithOrigins("http://localhost:5259")
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

var app = builder.Build();

// Khởi tạo bảng (nếu dùng SQLite) và seed dữ liệu mẫu
await DbSeeder.SeedAsync(app.Services, useSqlite);

app.UseStaticFiles();
app.UseCors("FlutterPolicy");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();