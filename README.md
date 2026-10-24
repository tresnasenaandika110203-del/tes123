# FinkaCare — Pembaruan Form Obat dan Legenda Kategori

## File yang diperbarui
- `index.html`
- `app.js`
- `styles.css`

## Cara memasang
1. Unduh ZIP pembaruan.
2. Ekstrak ZIP.
3. Ganti file `index.html`, `app.js`, dan `styles.css` pada repository GitHub FinkaCare dengan file dari ZIP.
4. **Jangan mengganti atau menghapus `config.js` yang sudah aktif**, karena file itu berisi konfigurasi Supabase milik aplikasi Anda.
5. Commit/push ke GitHub lalu tunggu deployment Vercel selesai.

## Perubahan
- Kategori, bentuk sediaan, dan satuan stok menjadi dropdown.
- Opsi dropdown dapat ditambah atau dihapus. Daftar opsi tersimpan di browser yang digunakan (localStorage), sehingga pengaturan opsi tidak otomatis berpindah ke browser/perangkat lain.
- Batas minimum stok menjadi opsional.
- Harga jual diformat dengan pemisah ribuan titik saat diketik, tetapi disimpan sebagai angka.
- Form obat mencakup nomor batch dan tanggal kedaluwarsa. Saat obat baru disimpan, sistem membuat batch awal dengan stok 0; stok masuk tetap dicatat lewat menu Stok Masuk.
- Kategori ditampilkan sebagai label warna dengan keterangan:
  - Merah: Obat Keras
  - Kuning: Jamu / Obat Herbal Terstandar
  - Biru (termasuk variasi warna biru): Obat Bebas Terbatas
  - Hijau dan toska pada sumber Excel: Obat Bebas (ditampilkan sebagai label hijau)
  - Ungu: Alat Kesehatan

## Catatan teknis
- Pembaruan ini memakai nama kolom Supabase yang saat ini digunakan oleh aplikasi, termasuk `batch_obat.stok_tersedia`.
- Saat mengedit obat, nomor batch dan tanggal kedaluwarsa yang ditampilkan adalah batch pertama yang ditemukan untuk obat tersebut. Batch lain dikelola melalui fitur penerimaan/stok masuk.
