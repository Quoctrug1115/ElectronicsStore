using Microsoft.AspNetCore.Http;

namespace backend.Services;

public class FileStorageService
{
    private readonly IWebHostEnvironment _env;
    private static readonly string[] AllowedExtensions = { ".jpg", ".jpeg", ".png", ".webp" };
    private const long MaxFileSize = 5 * 1024 * 1024; // 5MB

    public FileStorageService(IWebHostEnvironment env)
    {
        _env = env;
    }

    public async Task<(bool Success, string? RelativePath, string? ErrorMessage)> SaveImageAsync(IFormFile file, string subFolder)
    {
        if (file == null || file.Length == 0)
            return (false, null, "File ảnh không hợp lệ.");

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedExtensions.Contains(ext))
            return (false, null, "Chỉ chấp nhận file ảnh (.jpg, .jpeg, .png, .webp).");

        if (file.Length > MaxFileSize)
            return (false, null, "Kích thước mỗi ảnh tối đa 5MB.");

        var webRoot = _env.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
        var uploadFolder = Path.Combine(webRoot, "images", subFolder);
        Directory.CreateDirectory(uploadFolder);

        var fileName = $"{Guid.NewGuid()}{ext}";
        var fullPath = Path.Combine(uploadFolder, fileName);

        await using var stream = new FileStream(fullPath, FileMode.Create);
        await file.CopyToAsync(stream);

        return (true, $"/images/{subFolder}/{fileName}", null);
    }

    // Xóa 1 file vật lý trong wwwroot dựa theo đường dẫn tương đối (vd: /images/products/abc.jpg)
    public void DeletePhysicalFile(string? relativeUrl)
    {
        if (string.IsNullOrWhiteSpace(relativeUrl))
            return;

        var webRoot = _env.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
        var relativePath = relativeUrl.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
        var fullPath = Path.Combine(webRoot, relativePath);

        if (File.Exists(fullPath))
        {
            File.Delete(fullPath);
        }
    }

    // Xóa danh sách nhiều file vật lý cùng lúc
    public void DeletePhysicalFiles(IEnumerable<string?> relativeUrls)
    {
        foreach (var url in relativeUrls)
        {
            DeletePhysicalFile(url);
        }
    }
}