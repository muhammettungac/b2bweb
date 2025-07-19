CREATE TABLE Brands (
    BrandID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    BrandName NVARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE Suppliers (
    SupplierID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    SupplierName NVARCHAR(100) NOT NULL
);

CREATE TABLE Parts (
    PartID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    PartNumber NVARCHAR(100) UNIQUE NOT NULL,
    PartName NVARCHAR(255) NOT NULL,  -- Yeni PartName s�tunu eklendi
    BrandID INT NOT NULL,
    INDEX IX_Parts_Brand NONCLUSTERED (BrandID),
    FOREIGN KEY (BrandID) REFERENCES Brands(BrandID)
);

CREATE TABLE PartHistory (
    HistoryID BIGINT IDENTITY(1,1) PRIMARY KEY, -- Her bir tarih kayd�n� benzersiz k�lacak ID
    PartID INT NOT NULL, -- Par�an�n ID'si
    PartNumber NVARCHAR(100) NOT NULL, -- Par�an�n eski numaras�
    ValidFrom DATETIME NOT NULL DEFAULT GETDATE(), -- Kayd�n ge�erli oldu�u tarih
    ValidTo DATETIME NULL, -- Eski numaran�n ge�erli oldu�u biti� tarihi
    FOREIGN KEY (PartID) REFERENCES Parts(PartID) -- Sadece PartID'yi tutuyoruz
);

CREATE TABLE Currencies (
    CurrencyID INT IDENTITY(1,1) PRIMARY KEY, -- Her para birimi i�in bir ID
    CurrencyCode NVARCHAR(10) NOT NULL, -- Para birimi kodu (USD, EUR, vb.)
    CurrencyName NVARCHAR(50) NOT NULL, -- Para birimi ad� (Dolar, Euro, vb.)
    ExchangeRate DECIMAL(18,4) NOT NULL DEFAULT 1 -- �stenirse d�viz kuru da eklenebilir
);

CREATE PARTITION FUNCTION PriceDatePartitionFunction (DATETIME)
AS RANGE LEFT FOR VALUES ('2025-01-01', '2024-01-01', '2023-01-01', '2022-01-01');

ALTER DATABASE mct ADD FILEGROUP ARCHIVE;
ALTER DATABASE mct ADD FILEGROUP HISTORICAL;
ALTER DATABASE mct ADD FILEGROUP OLD;
ALTER DATABASE mct ADD FILEGROUP VERY_OLD;  -- Fazladan filegroup eklendi

CREATE PARTITION SCHEME PricePartitionScheme 
AS PARTITION PriceDatePartitionFunction 
TO ([PRIMARY], [ARCHIVE], [HISTORICAL], [OLD], [VERY_OLD]);  -- Fazladan filegroup eklendi

ALTER TABLE Prices DROP CONSTRAINT PK__Prices__6DB0E0F5;

ALTER TABLE Prices ADD CONSTRAINT PK_Prices PRIMARY KEY NONCLUSTERED (PartID, SupplierID, ValidFrom);

CREATE TABLE Prices (
    PriceID BIGINT IDENTITY(1,1), -- PriceID, UNIQUE olarak kal�yor
    PartID INT NOT NULL,
    SupplierID INT NOT NULL,
    Price DECIMAL(18,2) NOT NULL,
    CurrencyID INT NOT NULL, -- Para birimi referans�
    ValidFrom DATETIME NOT NULL DEFAULT GETDATE(),
    Description NVARCHAR(255),
    
    -- Burada ValidFrom da PRIMARY KEY i�inde yer alacak.
    PRIMARY KEY CLUSTERED (PriceID, ValidFrom), -- ValidFrom da burada dahil edildi.

    INDEX IX_Prices_PartSupplier NONCLUSTERED (PartID, SupplierID) INCLUDE (Price, ValidFrom),
    
    -- Di�er Foreign Key'ler
    FOREIGN KEY (PartID) REFERENCES Parts(PartID),
    FOREIGN KEY (SupplierID) REFERENCES Suppliers(SupplierID),
    FOREIGN KEY (CurrencyID) REFERENCES Currencies(CurrencyID) -- Para birimi referans�
)
ON PricePartitionScheme (ValidFrom); -- Partitioning i�lemi

ALTER INDEX ALL ON Prices REBUILD WITH (DATA_COMPRESSION = PAGE);
