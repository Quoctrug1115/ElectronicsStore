-- Active: 1795358436970@@127.0.0.1@1433@ElectronicsStore

USE master;
GO

-- Xóa database cũ nếu tồn tại để làm sạch toàn bộ dữ liệu lỗi font trước đó
IF DB_ID('ElectronicsStore') IS NOT NULL
BEGIN
    ALTER DATABASE ElectronicsStore SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE ElectronicsStore;
END
GO

CREATE DATABASE ElectronicsStore;
GO

USE ElectronicsStore;
GO

-- =============================================
-- 1. USERS AND AUTHENTICATION
-- =============================================

CREATE TABLE Users (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    FullName NVARCHAR(150) NOT NULL,
    Email VARCHAR(255) NOT NULL,
    PasswordHash VARCHAR(500) NULL,              -- NULL cho tài khoản đăng nhập Google/Facebook/Zalo
    PhoneNumber VARCHAR(20),
    EmailConfirmed BIT NOT NULL DEFAULT 0,       -- xác thực email
    LockoutEnd DATETIME2 NULL,                   -- khóa tài khoản tạm thời
    IsActive BIT NOT NULL DEFAULT 1,
    IsDeleted BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2
);
GO



-- Email unique chỉ với user chưa bị xóa mềm (cho phép đăng ký lại)
CREATE UNIQUE INDEX UX_Users_Email
ON Users(Email)
WHERE IsDeleted = 0;
GO

CREATE TABLE Roles (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    Name VARCHAR(50) NOT NULL UNIQUE,
    Description NVARCHAR(255)
);
GO

CREATE TABLE UserRoles (
    UserId BIGINT NOT NULL,
    RoleId BIGINT NOT NULL,

    PRIMARY KEY (UserId, RoleId),

    FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE,
    FOREIGN KEY (RoleId) REFERENCES Roles(Id)
);
GO

-- Refresh token: dùng cho logout (thu hồi token)
CREATE TABLE RefreshTokens (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId BIGINT NOT NULL,
    Token VARCHAR(500) NOT NULL UNIQUE,
    ExpiresAt DATETIME2 NOT NULL,
    RevokedAt DATETIME2 NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE
);
GO

-- Token xác thực email / quên mật khẩu (lưu hash của token)
CREATE TABLE UserTokens (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId BIGINT NOT NULL,
    TokenHash VARCHAR(500) NOT NULL,
    Type VARCHAR(30) NOT NULL,
    ExpiresAt DATETIME2 NOT NULL,
    UsedAt DATETIME2 NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT CK_UserTokens_Type CHECK (Type IN ('EmailConfirm', 'ResetPassword')),

    FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE
);
GO

-- Đăng nhập bằng Google / Facebook / Zalo
CREATE TABLE ExternalLogins (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId BIGINT NOT NULL,
    Provider VARCHAR(30) NOT NULL,
    ProviderUserId VARCHAR(255) NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT CK_ExternalLogins_Provider CHECK (Provider IN ('Google', 'Facebook', 'Zalo')),
    CONSTRAINT UQ_ExternalLogins UNIQUE (Provider, ProviderUserId),

    FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE
);
GO

CREATE TABLE Addresses (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId BIGINT NOT NULL,
    RecipientName NVARCHAR(150) NOT NULL,
    PhoneNumber VARCHAR(20) NOT NULL,
    Province NVARCHAR(100) NOT NULL,
    District NVARCHAR(100) NOT NULL,
    Ward NVARCHAR(100) NOT NULL,
    DetailAddress NVARCHAR(255) NOT NULL,
    IsDefault BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    FOREIGN KEY (UserId) REFERENCES Users(Id)
);
GO

-- =============================================
-- 2. PRODUCTS AND CATEGORIES
-- =============================================

CREATE TABLE Categories (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(150) NOT NULL,
    ParentId BIGINT NULL,
    Description NVARCHAR(500),
    ImageUrl VARCHAR(500) NULL,                  -- ảnh danh mục (upload thêm/sửa/xóa)
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    FOREIGN KEY (ParentId) REFERENCES Categories(Id)
);
GO

CREATE TABLE Brands (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL UNIQUE,
    LogoUrl VARCHAR(500),
    Description NVARCHAR(500),
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE Products (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    CategoryId BIGINT NOT NULL,
    BrandId BIGINT NOT NULL,
    Name NVARCHAR(255) NOT NULL,
    Description NVARCHAR(MAX),
    IsActive BIT NOT NULL DEFAULT 1,
    IsDeleted BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2,

    FOREIGN KEY (CategoryId) REFERENCES Categories(Id),
    FOREIGN KEY (BrandId) REFERENCES Brands(Id)
);
GO

CREATE TABLE ProductVariants (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    ProductId BIGINT NOT NULL,
    SKU VARCHAR(100) NOT NULL UNIQUE,
    Color NVARCHAR(50),
    Storage NVARCHAR(50),
    Price DECIMAL(18,2) NOT NULL,
    CompareAtPrice DECIMAL(18,2),
    StockQuantity INT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT CK_ProductVariants_StockQuantity
        CHECK (StockQuantity >= 0),

    CONSTRAINT CK_ProductVariants_Price
        CHECK (Price >= 0),

    CONSTRAINT CK_ProductVariants_CompareAtPrice
        CHECK (CompareAtPrice IS NULL OR CompareAtPrice >= 0),

    FOREIGN KEY (ProductId) REFERENCES Products(Id) ON DELETE CASCADE
);
GO

CREATE TABLE ProductImages (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    ProductId BIGINT NOT NULL,
    ImageUrl VARCHAR(500) NOT NULL,              -- lưu đường dẫn tương đối để xóa file vật lý
    IsPrimary BIT NOT NULL DEFAULT 0,
    SortOrder INT NOT NULL DEFAULT 0,

    FOREIGN KEY (ProductId) REFERENCES Products(Id) ON DELETE CASCADE
);
GO

-- Mỗi sản phẩm chỉ có tối đa 1 ảnh chính
CREATE UNIQUE INDEX UX_ProductImages_Primary
ON ProductImages(ProductId)
WHERE IsPrimary = 1;
GO

CREATE TABLE ProductSpecifications (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    ProductId BIGINT NOT NULL,
    SpecificationName NVARCHAR(100) NOT NULL,
    SpecificationValue NVARCHAR(500) NOT NULL,

    FOREIGN KEY (ProductId) REFERENCES Products(Id) ON DELETE CASCADE
);
GO

-- =============================================
-- 3. CART AND ORDERS
-- =============================================

CREATE TABLE Carts (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId BIGINT NOT NULL UNIQUE,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2,

    FOREIGN KEY (UserId) REFERENCES Users(Id)
);
GO

CREATE TABLE CartItems (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    CartId BIGINT NOT NULL,
    VariantId BIGINT NOT NULL,
    Quantity INT NOT NULL,

    CONSTRAINT CK_CartItems_Quantity CHECK (Quantity > 0),

    CONSTRAINT UQ_CartItems_Cart_Variant
        UNIQUE (CartId, VariantId),

    FOREIGN KEY (CartId) REFERENCES Carts(Id) ON DELETE CASCADE,
    FOREIGN KEY (VariantId) REFERENCES ProductVariants(Id) ON DELETE CASCADE
);
GO

CREATE TABLE Orders (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    OrderCode VARCHAR(50) NOT NULL UNIQUE,
    UserId BIGINT NOT NULL,
    AddressId BIGINT NULL,
    -- Snapshot thông tin giao hàng
    RecipientName NVARCHAR(150) NOT NULL,
    PhoneNumber VARCHAR(20) NOT NULL,
    ShippingAddress NVARCHAR(500) NOT NULL,

    Subtotal DECIMAL(18,2) NOT NULL,
    DiscountAmount DECIMAL(18,2) NOT NULL DEFAULT 0,
    ShippingFee DECIMAL(18,2) NOT NULL DEFAULT 0,
    TotalAmount DECIMAL(18,2) NOT NULL,

    Status VARCHAR(30) NOT NULL DEFAULT 'Pending',
    Note NVARCHAR(500),

    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2,

    CONSTRAINT CK_Orders_Amounts CHECK (
        Subtotal >= 0
        AND DiscountAmount >= 0
        AND ShippingFee >= 0
        AND TotalAmount >= 0
    ),

    CONSTRAINT CK_Orders_Status CHECK (
        Status IN (
            'Pending',
            'Confirmed',
            'Processing',
            'Shipped',
            'Delivered',
            'Cancelled',
            'Returned'
        )
    ),

    FOREIGN KEY (UserId) REFERENCES Users(Id),
    FOREIGN KEY (AddressId) REFERENCES Addresses(Id)
);
GO

CREATE TABLE OrderItems (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    OrderId BIGINT NOT NULL,
    VariantId BIGINT NOT NULL,
    -- Snapshot sản phẩm tại thời điểm mua
    ProductName NVARCHAR(255) NOT NULL,
    SKU VARCHAR(100) NOT NULL,

    UnitPrice DECIMAL(18,2) NOT NULL,
    Quantity INT NOT NULL,
    TotalPrice DECIMAL(18,2) NOT NULL,

    CONSTRAINT CK_OrderItems_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_OrderItems_Prices CHECK (
        UnitPrice >= 0 AND TotalPrice >= 0
    ),

    FOREIGN KEY (OrderId) REFERENCES Orders(Id),
    FOREIGN KEY (VariantId) REFERENCES ProductVariants(Id)   -- không cascade: chặn xóa SP đã có trong đơn
);
GO

-- Lịch sử đổi trạng thái đơn hàng (admin cập nhật)
CREATE TABLE OrderStatusHistory (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    OrderId BIGINT NOT NULL,
    OldStatus VARCHAR(30),
    NewStatus VARCHAR(30) NOT NULL,
    ChangedBy BIGINT NULL,
    Note NVARCHAR(500),
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    FOREIGN KEY (OrderId) REFERENCES Orders(Id),
    FOREIGN KEY (ChangedBy) REFERENCES Users(Id)
);
GO

-- =============================================
-- 4. PAYMENTS AND SHIPPING
-- =============================================

CREATE TABLE Payments (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    OrderId BIGINT NOT NULL,
    PaymentMethod VARCHAR(30) NOT NULL,
    Amount DECIMAL(18,2) NOT NULL,
    Status VARCHAR(30) NOT NULL DEFAULT 'Pending',
    TransactionCode VARCHAR(150),
    GatewayResponse NVARCHAR(MAX) NULL,          -- lưu response cổng thanh toán để đối soát
    PaidAt DATETIME2,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT CK_Payments_Amount CHECK (Amount >= 0),

    CONSTRAINT CK_Payments_Method CHECK (
        PaymentMethod IN (
            'COD',
            'BankTransfer',
            'VNPay',
            'VietQR',
            'MoMo',
            'ZaloPay'
        )
    ),

    CONSTRAINT CK_Payments_Status CHECK (
        Status IN (
            'Pending',
            'Processing',
            'Completed',
            'Failed',
            'Refunded'
        )
    ),

    FOREIGN KEY (OrderId) REFERENCES Orders(Id)
);
GO

CREATE TABLE Shipments (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    OrderId BIGINT NOT NULL,
    ShippingProvider NVARCHAR(100),
    TrackingNumber VARCHAR(100),
    ShippingStatus VARCHAR(30) NOT NULL DEFAULT 'Pending',
    ShippedAt DATETIME2,
    DeliveredAt DATETIME2,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT CK_Shipments_Status CHECK (
        ShippingStatus IN (
            'Pending',
            'Preparing',
            'Shipping',
            'Delivered',
            'Failed',
            'Returned'
        )
    ),

    FOREIGN KEY (OrderId) REFERENCES Orders(Id)
);
GO

-- =============================================
-- 5. INVENTORY MANAGEMENT
-- =============================================

CREATE TABLE Warehouses (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(150) NOT NULL,
    Address NVARCHAR(500),
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE Inventory (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    WarehouseId BIGINT NOT NULL,
    VariantId BIGINT NOT NULL,
    Quantity INT NOT NULL DEFAULT 0,
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT CK_Inventory_Quantity CHECK (Quantity >= 0),

    CONSTRAINT UQ_Inventory_Warehouse_Variant
        UNIQUE (WarehouseId, VariantId),

    FOREIGN KEY (WarehouseId) REFERENCES Warehouses(Id),
    FOREIGN KEY (VariantId) REFERENCES ProductVariants(Id) ON DELETE CASCADE
);
GO

CREATE TABLE StockTransactions (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    WarehouseId BIGINT NOT NULL,
    VariantId BIGINT NOT NULL,
    TransactionType VARCHAR(30) NOT NULL,
    Quantity INT NOT NULL,
    ReferenceCode VARCHAR(100),
    Note NVARCHAR(500),
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT CK_StockTransactions_Type CHECK (
        TransactionType IN (
            'Import',
            'Export',
            'Return',
            'Adjustment'
        )
    ),

    CONSTRAINT CK_StockTransactions_Quantity CHECK (Quantity > 0),

    FOREIGN KEY (WarehouseId) REFERENCES Warehouses(Id),
    FOREIGN KEY (VariantId) REFERENCES ProductVariants(Id)
);
GO

-- =============================================
-- 6. COUPONS AND REVIEWS
-- =============================================

CREATE TABLE Coupons (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    Code VARCHAR(50) NOT NULL UNIQUE,
    Description NVARCHAR(500),
    DiscountType VARCHAR(20) NOT NULL,
    DiscountValue DECIMAL(18,2) NOT NULL,
    MinOrderAmount DECIMAL(18,2) NOT NULL DEFAULT 0,
    MaxDiscountAmount DECIMAL(18,2),
    StartDate DATETIME2 NOT NULL,
    EndDate DATETIME2 NOT NULL,
    UsageLimit INT,
    IsActive BIT NOT NULL DEFAULT 1,

    CONSTRAINT CK_Coupons_DiscountType CHECK (
        DiscountType IN ('Percentage', 'Fixed')
    ),

    CONSTRAINT CK_Coupons_DiscountValue CHECK (
        DiscountValue > 0
    ),

    CONSTRAINT CK_Coupons_Dates CHECK (
        EndDate > StartDate
    ),

    CONSTRAINT CK_Coupons_MinOrder CHECK (
        MinOrderAmount >= 0
    )
);
GO

CREATE TABLE CouponUsages (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    CouponId BIGINT NOT NULL,
    UserId BIGINT NOT NULL,
    OrderId BIGINT NOT NULL,
    UsedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    FOREIGN KEY (CouponId) REFERENCES Coupons(Id),
    FOREIGN KEY (UserId) REFERENCES Users(Id),
    FOREIGN KEY (OrderId) REFERENCES Orders(Id),

    CONSTRAINT UQ_CouponUsages_Order UNIQUE (OrderId)
);
GO

CREATE TABLE Reviews (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId BIGINT NOT NULL,
    ProductId BIGINT NOT NULL,
    OrderItemId BIGINT NOT NULL,
    Rating INT NOT NULL,
    Comment NVARCHAR(1000),
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2,

    CONSTRAINT CK_Reviews_Rating CHECK (
        Rating BETWEEN 1 AND 5
    ),

    CONSTRAINT UQ_Reviews_OrderItem UNIQUE (OrderItemId),

    FOREIGN KEY (UserId) REFERENCES Users(Id),
    FOREIGN KEY (ProductId) REFERENCES Products(Id),
    FOREIGN KEY (OrderItemId) REFERENCES OrderItems(Id)
);
GO

-- =============================================
-- 7. WISHLIST
-- =============================================

CREATE TABLE Wishlists (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId BIGINT NOT NULL UNIQUE,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    FOREIGN KEY (UserId) REFERENCES Users(Id)
);
GO

CREATE TABLE WishlistItems (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    WishlistId BIGINT NOT NULL,
    ProductId BIGINT NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT UQ_WishlistItems_Product
        UNIQUE (WishlistId, ProductId),

    FOREIGN KEY (WishlistId) REFERENCES Wishlists(Id) ON DELETE CASCADE,
    FOREIGN KEY (ProductId) REFERENCES Products(Id) ON DELETE CASCADE
);
GO

-- =============================================
-- 8. INDEXES
-- =============================================

CREATE INDEX IX_Categories_ParentId ON Categories(ParentId);

CREATE INDEX IX_Products_CategoryId ON Products(CategoryId);
CREATE INDEX IX_Products_BrandId ON Products(BrandId);
CREATE INDEX IX_Products_Name ON Products(Name);
CREATE INDEX IX_Products_CreatedAt ON Products(CreatedAt DESC);

CREATE INDEX IX_ProductVariants_ProductId ON ProductVariants(ProductId);
CREATE INDEX IX_ProductImages_ProductId ON ProductImages(ProductId);
CREATE INDEX IX_ProductSpecifications_ProductId ON ProductSpecifications(ProductId);

CREATE INDEX IX_CartItems_VariantId ON CartItems(VariantId);

CREATE INDEX IX_Orders_UserId ON Orders(UserId);
CREATE INDEX IX_Orders_Status ON Orders(Status);
CREATE INDEX IX_Orders_CreatedAt ON Orders(CreatedAt);

CREATE INDEX IX_OrderItems_OrderId ON OrderItems(OrderId);
CREATE INDEX IX_OrderItems_VariantId ON OrderItems(VariantId);
CREATE INDEX IX_OrderStatusHistory_OrderId ON OrderStatusHistory(OrderId);

CREATE INDEX IX_Payments_OrderId ON Payments(OrderId);
CREATE INDEX IX_Shipments_OrderId ON Shipments(OrderId);
CREATE INDEX IX_Addresses_UserId ON Addresses(UserId);
CREATE INDEX IX_Reviews_ProductId ON Reviews(ProductId);
CREATE INDEX IX_StockTransactions_VariantId ON StockTransactions(VariantId);
CREATE INDEX IX_CouponUsages_UserId ON CouponUsages(UserId);

CREATE INDEX IX_RefreshTokens_UserId ON RefreshTokens(UserId);
CREATE INDEX IX_UserTokens_UserId_Type ON UserTokens(UserId, Type);
CREATE INDEX IX_ExternalLogins_UserId ON ExternalLogins(UserId);
GO

-- =============================================
-- 9. INITIAL DATA
-- =============================================

INSERT INTO Roles (Name, Description)
VALUES
('Admin', N'Quản trị viên hệ thống'),
('Member', N'Thành viên / khách hàng');
GO

INSERT INTO Categories (Name, Description)
VALUES
(N'Điện thoại', N'Các dòng điện thoại thông minh'),
(N'Laptop', N'Máy tính xách tay'),
(N'Tablet', N'Máy tính bảng'),
(N'Phụ kiện', N'Phụ kiện điện tử'),
(N'Màn hình', N'Màn hình máy tính');
GO

INSERT INTO Brands (Name, Description)
VALUES
(N'Apple', N'Thương hiệu Apple'),
(N'Samsung', N'Thương hiệu Samsung'),
(N'Dell', N'Thương hiệu Dell'),
(N'ASUS', N'Thương hiệu ASUS'),
(N'Lenovo', N'Thương hiệu Lenovo');
GO

INSERT INTO Warehouses (Name, Address)
VALUES (N'Kho chính', N'TP. Hồ Chí Minh');
GO

-- Kiểm tra lại dữ liệu tiếng Việt sau khi khởi tạo
SELECT * FROM Categories;
SELECT * FROM Brands;
SELECT * FROM Roles;
GO
