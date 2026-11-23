# ElectronicsStore

Từ .NET 9/10, ASP.NET Core dùng sẵn AddOpenApi() + MapOpenApi() thay cho AddSwaggerGen(), kết hợp với Scalar để có giao diện test API hiện đại và hỗ trợ sẵn Bearer Token.

# Test api trên file .http
## Test CRUD ở Backend bằng cách chạy mục 3, 7, 8, 9, 10 ở file .http
## Test Order và Cart thì chục mục 3 đăng nhập trước

Chạy theo thứ tự từ trên xuống: Các request sau dùng biến tự động từ response trước (như {{loginAdmin.response.body.accessToken}}, {{createOrder.response.body.data.id}}).

Test Ngày 11.1 (DELETE /api/products/1): Request này sẽ ẩn mềm sản phẩm ID 1 (IsDeleted = true). Nếu muốn hiện lại sản phẩm 1 sau khi test xong để tiếp tục làm Flutter, bạn chạy lệnh SQL UPDATE Products SET IsDeleted = 0, IsActive = 1 WHERE Id = 1

Test Ngày 12.4 – 12.8 (OTP Gmail): Thay biến @testEmail ở đầu file bằng địa chỉ Gmail của bạn và đảm bảo đã điền đúng SenderEmail + AppPassword (16 ký tự) trong appsettings.json, sau đó mở hộp thư lấy mã 6 số điền vào trường "otp" ở bước 12.6 và 12.8