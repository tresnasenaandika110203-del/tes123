# FinkaCare — Perbaikan integrasi Supabase

Paket ini berisi pembaruan untuk `app.js` dan `index.html` agar cocok dengan skema database Apotek Finka yang menggunakan `stok_tersedia`, `satuan_dasar`, `batch_id`, `kontak`, dan `created_at`.

## Cara memasang
1. Unduh ZIP ini dan ekstrak.
2. Ganti `app.js` dan `index.html` di repository GitHub dengan file dari paket ini.
3. **Jangan mengganti `config.js`** jika file tersebut sudah berisi Project URL dan Publishable Key milik proyek Supabase kamu.
4. Commit dan push ke GitHub; tunggu Vercel selesai deploy.
5. Buka website, login, uji memuat dashboard, lalu tekan Logout.
6. Refresh halaman: aplikasi seharusnya kembali ke halaman login.

## Perubahan
- Riwayat mutasi membaca `created_at`, bukan kolom yang tidak ada `tanggal_mutasi`.
- Tabel detail penerimaan tidak diurutkan berdasarkan `created_at`, karena kolom itu tidak ada di tabel tersebut.
- Nama kolom stok, satuan, relasi batch, dan kontak supplier diselaraskan dengan skema yang diberikan.
- RPC stok keluar memakai parameter `p_batch_id`, `p_jumlah`, `p_referensi`, dan `p_catatan`.
- Sesi autentikasi hanya disimpan selama halaman masih terbuka (`persistSession: false`), sehingga refresh meminta login lagi.
- Tombol Logout menangani hasil/error dan mengakhiri sesi lokal.

Catatan: perubahan ini belum diuji langsung ke proyek Supabase kamu. Setelah deploy, uji login, tambah data obat, tambah supplier, stok masuk, stok keluar, dan logout sebelum digunakan untuk pencatatan apotek sebenarnya.
