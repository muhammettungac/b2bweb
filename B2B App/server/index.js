const express = require('express');
const sql = require('mssql');
const cors = require('cors');

const app = express();
const port = 3000;

app.use(cors()); // CORS İzinleri

const config = {
  user: 'mctAdmin',
  password: 'mctAdmin',
  server: 'localhost',
  database: 'mct',
  options: {
    trustedConnection: true,
    trustServerCertificate: true,
  }
};

// Veritabanı bağlantısı
async function getDbConnection() {
  try {
    const pool = await sql.connect(config);
    console.log('Veritabanına başarıyla bağlanıldı');
    return pool;
  } catch (err) {
    console.error('Veritabanı bağlantısı hatası:', err);
    throw err;
  }
}

// Fiyat sorgulama API'si
app.get('/get-price', async (req, res) => {
  const { partNumber, brand } = req.query;

  if (!partNumber || !brand) {
    return res.status(400).json({ message: 'PartNumber ve Brand gerekli' });
  }

  try {
    const pool = await getDbConnection();

    const query = `
      SELECT p.Price 
      FROM dbo.Prices p
      INNER JOIN dbo.Parts pa ON p.PartID = pa.PartID
      INNER JOIN dbo.Suppliers s ON p.SupplierID = s.SupplierID
      WHERE pa.PartNumber = @partNumber AND s.SupplierName = @brand
    `;

    const result = await pool.request()
      .input('partNumber', sql.NVarChar, partNumber)
      .input('brand', sql.NVarChar, brand)
      .query(query);

    if (result.recordset.length === 0) {
      return res.status(404).json({ message: 'Verilen parça ve marka için fiyat bulunamadı' });
    }

    res.json(result.recordset);
  } catch (err) {
    console.error('Hata:', err);
    res.status(500).json({ message: 'Veri çekme hatası' });
  }
});

// Sunucu başlat
app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
