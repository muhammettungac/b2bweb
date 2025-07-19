import pyodbc
import pandas as pd

# Veritabanı bağlantısı
conn = pyodbc.connect('DRIVER={SQL Server};SERVER=DESKTOP-RF7RE73;DATABASE=mct;UID=mctAdmin;PWD=mctAdmin')
cursor = conn.cursor()

# Excel dosyasını yükle
excel_file = 'insertFile.xlsx'
df = pd.read_excel(excel_file, sheet_name=None)  # Sheet'leri okuyarak bir sözlük oluştur

def get_or_insert_brand(brand_name):
    # Markayı veritabanında ara
    cursor.execute("SELECT BrandID FROM Brands WHERE BrandName = ?", (brand_name,))
    result = cursor.fetchone()

    if result:
        return result[0]
    else:
        # Marka yoksa, ekle ve ID'yi al
        cursor.execute("INSERT INTO Brands (BrandName) OUTPUT INSERTED.BrandID VALUES (?)", (brand_name,))
        return cursor.fetchone()[0]

def get_or_insert_supplier(supplier_name):
    # Tedarikçiyi veritabanında ara
    cursor.execute("SELECT SupplierID FROM Suppliers WHERE SupplierName = ?", (supplier_name,))
    result = cursor.fetchone()

    if result:
        return result[0]
    else:
        # Tedarikçi yoksa, ekle ve ID'yi al
        cursor.execute("INSERT INTO Suppliers (SupplierName) OUTPUT INSERTED.SupplierID VALUES (?)", (supplier_name,))
        return cursor.fetchone()[0]

def get_or_insert_part(part_number, part_name, brand_id):
    # Parçayı veritabanında ara
    cursor.execute("SELECT PartID FROM Parts WHERE PartNumber = ?", (part_number,))
    result = cursor.fetchone()

    if result:
        part_id = result[0]
        # REF-2 varsa, PartHistory'yi ekle (eski numara kaydını)
        if 'REF-2' in row and pd.notna(row['REF-2']):
            cursor.execute("INSERT INTO PartHistory (PartID, PartNumber, ValidFrom) VALUES (?, ?, GETDATE())",
                           (part_id, row['REF-2']))
        return part_id
    else:
        # Parça yoksa, ekle ve ID'yi al
        cursor.execute("INSERT INTO Parts (PartNumber, PartName, BrandID) OUTPUT INSERTED.PartID VALUES (?, ?, ?)",
                       (part_number, part_name, brand_id))
        return cursor.fetchone()[0]

# Excel sheet'lerinde işlem yap
for sheet_name, data in df.items():
    for index, row in data.iterrows():
        brand_name = row['BRAND']
        part_number = row['REF']  # REF-2 yoksa, REF kullanılıyor
        part_name = row['DESCRIPTION']
        supplier_name = sheet_name  # Sheet ismi tedarikçi adı olarak alınıyor
        price = row['PRICE']
        
        # Markayı ekle veya al
        brand_id = get_or_insert_brand(brand_name)
        
        # Tedarikçiyi ekle veya al
        supplier_id = get_or_insert_supplier(supplier_name)
        
        # Parçayı ekle veya al ve PartHistory'yi kaydet
        part_id = get_or_insert_part(part_number, part_name, brand_id)
        
        # Fiyatı Prices tablosuna ekle
        cursor.execute("""
            INSERT INTO Prices (PartID, SupplierID, Price, CurrencyID, ValidFrom)
            VALUES (?, ?, ?, 1, GETDATE())""", 
                       (part_id, supplier_id, price))  # Para birimi 1 olarak varsayalım
        
    conn.commit()  # Veritabanı değişikliklerini kaydet

# Bağlantıyı kapat
cursor.close()
conn.close()
