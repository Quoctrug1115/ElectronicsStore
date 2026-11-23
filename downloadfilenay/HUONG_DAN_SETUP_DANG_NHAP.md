# Hướng dẫn setup đăng nhập Google / Zalo / Facebook

> Thư mục này chứa `debug.keystore` và khóa bí mật Facebook. **Repo phải luôn để PRIVATE.** Không chia sẻ ra ngoài nhóm.

Làm đúng thứ tự, mỗi người làm **một lần**. Đăng nhập mạng xã hội chỉ chạy trên **Android** (máy thật qua USB hoặc emulator có Google Play), không chạy trên Chrome hay Linux desktop.

---

## Bước 0. Lấy code mới

```bash
git pull
cd frontend
flutter pub get
```

---

## Bước 1. Ghi đè debug keystore

Google, Zalo, Facebook đã cấu hình theo chứng chỉ debug trong file `downloadfilenay/debug.keystore`. Máy bạn phải dùng **đúng file này**.

1. Tắt Android Studio / VS Code đang chạy `flutter run`.
2. Chép đè file vào thư mục `.android` (thư mục ẩn, chưa có thì tạo):
   - Linux/macOS: `cp downloadfilenay/debug.keystore ~/.android/debug.keystore`
   - Windows: chép `downloadfilenay\debug.keystore` vào `C:\Users\<tên bạn>\.android\debug.keystore`
3. Xóa cache build:
   ```bash
   cd frontend
   flutter clean
   flutter pub get
   ```
4. Kiểm tra. SHA-1 phải đúng là `68:CF:EC:6A:82:CD:F6:C0:68:49:1F:39:8A:29:BD:9E:04:E2:A9:C3`:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
   ```

---

## Bước 2. Đặt khóa bí mật Facebook cho backend

Chỉ cần trên máy **chạy backend**. Chạy trong thư mục `backend/`:

```bash
cd backend
dotnet user-secrets set "Facebook:AppSecret" "4198312ce6b216e16f310d2ed3604774"
```

Kiểm tra (chỉ hiện tên khóa):

```bash
dotnet user-secrets list | sed -E 's/=.*/= ***/'
```

Phải thấy `Facebook:AppSecret = ***`. Thiếu thì backend trả 500 "Chưa cấu hình Facebook:AppSecret" khi đăng nhập Facebook.

Connection string SQL Server của bạn vẫn đặt riêng:

```bash
dotnet user-secrets set "ConnectionStrings:ElectronicsStore" "Server=127.0.0.1,1433;Database=ElectronicsStore;User Id=sa;Password=<mật khẩu sa>;TrustServerCertificate=True;"
```

---

## Bước 3. Chạy backend và app

**Terminal 1, backend** (cần SQL Server chạy: `sudo systemctl start mssql-server`):

```bash
cd backend
dotnet run --launch-profile http
```

Khởi động lại backend sau khi đặt secret.

**Terminal 2, app Android qua USB:**

```bash
adb devices                          # phải thấy máy ở trạng thái "device"
adb reverse tcp:5202 tcp:5202        # mất khi rút USB, chạy lại nếu app báo "Connection refused"
cd frontend
flutter run -d <id máy>
```

Emulator (không dùng USB):

```bash
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:5202
```

Emulator phải dùng image có **Google Play** và đã đăng nhập tài khoản Google.

---

## Bước 4. Thêm tài khoản của bạn vào danh sách thử nghiệm

Cả ba app đang ở chế độ phát triển, chỉ tài khoản được thêm mới đăng nhập được. Nhờ chủ repo (qtrung) thêm bạn vào:

- **Google:** Cloud Console, Audience, Test users (cần Gmail của bạn).
- **Zalo:** Zalo Developers, Vai trò (cần tài khoản Zalo).
- **Facebook:** Vai trò trong ứng dụng, Developer hoặc Tester. Vào Facebook bấm chấp nhận lời mời.

---

## Gặp lỗi?

| Lỗi | Nguyên nhân thường gặp |
|---|---|
| `Connection refused` trên điện thoại | Chưa `adb reverse tcp:5202 tcp:5202`, hoặc backend/SQL Server chưa chạy |
| Google `DEVELOPER_ERROR` / không có tài khoản | Chưa ghi đè `debug.keystore`, hoặc chưa được thêm vào Test users |
| Zalo / Facebook báo lỗi hash key | Chưa ghi đè `debug.keystore`, hoặc chưa được thêm vào Vai trò |
| Facebook 500 "Chưa cấu hình Facebook:AppSecret" | Chưa chạy lệnh Bước 2, hoặc chưa khởi động lại backend |
| Build Android lỗi sau khi pull | `flutter clean && flutter pub get`, kiểm tra đã có thư mục `frontend/packages/` |
