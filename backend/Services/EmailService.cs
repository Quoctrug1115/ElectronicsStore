using MailKit;
using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace backend.Services;

public class EmailService
{
    private readonly IConfiguration _configuration;

    public EmailService(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public async Task SendOtpEmailAsync(string toEmail, string fullName, string otpCode, string purpose)
    {
        var senderName = _configuration["EmailSettings:SenderName"] ?? "Electronics Store";
        var senderEmail = _configuration["EmailSettings:SenderEmail"];
        var appPassword = _configuration["EmailSettings:AppPassword"];
        var smtpHost = _configuration["EmailSettings:SmtpHost"] ?? "smtp.gmail.com";
        var smtpPort = int.TryParse(_configuration["EmailSettings:SmtpPort"], out var port) ? port : 587;

        if (string.IsNullOrWhiteSpace(senderEmail) || string.IsNullOrWhiteSpace(appPassword))
            throw new InvalidOperationException("Chưa cấu hình EmailSettings:SenderEmail hoặc AppPassword.");

        bool isEmailConfirm = purpose == "EmailConfirm";
        var subject = isEmailConfirm
            ? "[Electronics Store] Mã OTP xác thực tài khoản"
            : "[Electronics Store] Mã OTP đặt lại mật khẩu";

        var title = isEmailConfirm ? "Xác thực địa chỉ Email" : "Đặt lại mật khẩu";
        var description = isEmailConfirm
            ? "Cảm ơn bạn đã đăng ký tài khoản tại Electronics Store. Vui lòng nhập mã OTP bên dưới để kích hoạt tài khoản:"
            : "Chúng tôi nhận được yêu cầu đặt lại mật khẩu cho tài khoản của bạn. Vui lòng nhập mã OTP bên dưới để tiếp tục:";

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(senderName, senderEmail.Trim()));
        message.To.Add(new MailboxAddress(fullName, toEmail.Trim()));
        message.Subject = subject;

        message.Body = new TextPart("html")
        {
            Text = $@"
                <div style='font-family: Arial, sans-serif; max-width: 520px; margin: 0 auto; padding: 24px; border: 1px solid #e5e7eb; border-radius: 12px;'>
                    <h2 style='color: #111827; margin-top: 0;'>{title}</h2>
                    <p style='color: #374151;'>Xin chào <strong>{System.Net.WebUtility.HtmlEncode(fullName)}</strong>,</p>
                    <p style='color: #374151;'>{description}</p>
                    <div style='margin: 24px 0; text-align: center;'>
                        <span style='display: inline-block; font-size: 32px; font-weight: bold; letter-spacing: 8px; padding: 14px 28px; background-color: #f3f4f6; color: #1d4ed8; border-radius: 8px;'>
                            {otpCode}
                        </span>
                    </div>
                    <p style='color: #6b7280; font-size: 13px;'>Mã OTP có hiệu lực trong <strong>10 phút</strong>. Tuyệt đối không chia sẻ mã này cho bất kỳ ai.</p>
                </div>"
        };

        var cleanPassword = appPassword.Replace(" ", "").Trim();
        var secureOption = smtpPort == 465
            ? SecureSocketOptions.SslOnConnect
            : SecureSocketOptions.StartTls;

        using var client = new SmtpClient(new ProtocolLogger(Console.OpenStandardOutput()));
        await client.ConnectAsync(smtpHost, smtpPort, secureOption);
        await client.AuthenticateAsync(senderEmail.Trim(), cleanPassword);
        await client.SendAsync(message);
        await client.DisconnectAsync(true);
    }
}