# Hướng dẫn chạy project sau khi clone

Hệ thống gồm 3 phần: **SQL Server** → **Backend .NET** (`localhost:5202`) → **App Flutter**.

## 1. Cần cài sẵn

- SQL Server (cổng `1433`) và công cụ `sqlcmd`
- .NET SDK **10**
- Flutter **3.47+** (Dart ≥ 3.13.5)
- Android Studio / Android SDK nếu chạy trên Android

## 2. Tạo database (chỉ làm 1 lần)

```bash
sqlcmd -S 127.0.0.1,1433 -U sa -P '<mật khẩu sa của bạn>' -C -i ElectronicsStore.sql
```

Script tạo database `ElectronicsStore` cùng toàn bộ bảng và dữ liệu mẫu (role Admin/Member, danh mục, thương hiệu).
Script **không chạy lại được**. Muốn tạo lại thì chạy `DROP DATABASE ElectronicsStore` trước.

## 3. Chạy backend

`backend/appsettings.json` đang chứa mật khẩu `sa` của người tạo repo. **Đừng sửa file này.** Mỗi người truyền connection string của máy mình qua biến môi trường:

```bash
cd backend
export ConnectionStrings__ElectronicsStore='Server=127.0.0.1,1433;Database=ElectronicsStore;User Id=sa;Password=<mật khẩu sa của bạn>;TrustServerCertificate=True;'
dotnet run --launch-profile http
```

Khi thấy dòng `Now listening on: http://localhost:5202` là backend đã chạy.
Lần chạy đầu, backend tự tạo tài khoản admin: **`admin@electronics.com` / `Admin@123`**.

## 4. Chạy app Flutter

```bash
cd frontend
flutter pub get
```

Địa chỉ API mặc định là `http://localhost:5202` (khai báo trong `lib/core/api_config.dart`). Tùy thiết bị:

| Chạy trên                    | Lệnh                                                                                                                                                                         | Trạng thái                        |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| Linux desktop                | `flutter run -d linux`                                                                                                                                                       | ✅ Đã test                        |
| Chrome (Web)                 | `flutter run -d chrome` (tự chạy ở cổng **5259**, xem lưu ý bên dưới)                                                                                                        | ✅ Đã test                        |
| Android Emulator             | `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:5202`                                                                                               | ⚠️ Đã cấu hình, **chưa chạy thử** |
| Điện thoại Android cắm USB   | `adb reverse tcp:5202 tcp:5202` rồi `flutter run -d <id>`                                                                                                                    | ⚠️ Đã cấu hình, **chưa chạy thử** |
| Điện thoại Android qua Wi-Fi | Chạy backend với `ASPNETCORE_URLS=http://0.0.0.0:5202 dotnet run`, mở firewall cổng 5202, rồi `flutter run -d <id> --dart-define=API_BASE_URL=http://<IP-LAN-máy-tính>:5202` | ⚠️ Đã cấu hình, **chưa chạy thử** |

Ai chạy thử thành công trên Android thì cập nhật lại cột **Trạng thái** giúp tao.

Xem id thiết bị bằng `flutter devices`.
