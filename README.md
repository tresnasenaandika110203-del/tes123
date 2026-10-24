# FinkaCare — pembaruan form obat dan opsi dropdown

## Isi paket
- `index.html`, `app.js`, `styles.css`: aplikasi dengan pembaruan form obat.
- `config.js`: konfigurasi Supabase yang sebelumnya diunggah, dipertahankan agar aplikasi tetap terhubung.
- `finkacare_supabase_setup.sql`: setup keamanan + migrasi kolom dan opsi dropdown database.

## Cara memasang
1. Cadangkan repository dan database terlebih dahulu.
2. Buka Supabase SQL Editor. Periksa bahwa dua UUID pada bagian allowlist admin memang merupakan ID pengguna admin yang benar di Authentication → Users. Sesuaikan jika perlu.
3. Jalankan `finkacare_supabase_setup.sql` pada project yang skemanya memakai ID `bigint`, `batch_obat.stok_tersedia`, serta nama kolom/RPC yang digunakan aplikasi ini. Jangan jalankan jika skema aktual berbeda; cocokkan dahulu.
4. Ganti `index.html`, `app.js`, `styles.css`, dan `README.md` pada repository. Pertahankan `config.js` aktif milik project.
5. Commit/push ke GitHub lalu tunggu deployment Vercel selesai.

## Perilaku form
- Urutan form: kode obat, nama obat, bentuk sediaan, jenis obat, kategori obat, satuan stok, batas minimum, harga jual, nomor batch, tanggal kedaluwarsa.
- Kode/nama obat dan nomor batch menampilkan saran dari data database, tetapi tetap dapat diketik sebagai data baru.
- Menyimpan obat baru membuat master obat dan batch dengan stok 0. Jumlah stok tetap dicatat lewat menu Stok Masuk, tidak dibuatkan transaksi fiktif.
- Supplier dan tanggal penerimaan tetap dikelola melalui form Stok Masuk.
- Opsi kategori, bentuk sediaan, dan satuan disimpan pada tabel `pengaturan_opsi` agar tersedia lintas perangkat. Penghapusan meminta konfirmasi “Yakin mau dihapus?”.
- `jenis_obat` ditambahkan sebagai kolom teks opsional.

## Penting
`supabase_setup.sql` lama yang diunggah memiliki kebijakan `using (true)` untuk semua pengguna authenticated dan signature UUID yang berbeda. Jangan jalankan bersama setup aman di atas tanpa audit skema; keduanya tidak kompatibel dan kebijakan lama lebih longgar.
