# FinkaCare — Apotek Finka Inventory

Aplikasi HTML/CSS/JavaScript statis yang menggunakan Supabase Auth dan Supabase Database. Tidak memerlukan build step; cocok untuk deploy ke Vercel sebagai static site.

## 1. Konfigurasi Supabase

1. Buka `config.js`.
2. Ganti `PASTE_SUPABASE_PROJECT_URL_HERE` dengan Project URL di Supabase → Project Settings → API.
3. Ganti `PASTE_SUPABASE_PUBLISHABLE_KEY_HERE` dengan **publishable key**. Jangan pernah gunakan `service_role` atau secret key pada frontend.
4. Commit perubahan ke GitHub; Vercel akan deploy otomatis.

## 2. Akun admin

Buat kedua akun dari Supabase → Authentication → Users → Add user. Gunakan email dan password berbeda. Nonaktifkan public sign-ups bila tersedia di pengaturan Auth. Aplikasi ini tidak menyediakan pendaftaran akun publik.

## 3. Tabel yang dipakai

Aplikasi mengharapkan tabel berikut dengan kolom yang umum digunakan oleh skema awal FinkaCare:

- `obat`: `id`, `kode_obat`, `nama_obat`, `kategori`, `bentuk_sediaan`, `satuan`, `stok_minimum`, `harga_beli`, `harga_jual`, `created_at`, `updated_at`
- `batch_obat`: `id`, `obat_id`, `nomor_batch`, `tanggal_kedaluwarsa`, `stok_awal`, `stok_saat_ini`, `harga_beli`, `created_at`
- `supplier`: `id`, `nama_supplier`, `alamat`, `telepon`, `email`, `created_at`
- `penerimaan`: `id`, `supplier_id`, `nomor_faktur`, `tanggal_penerimaan`, `catatan`, `created_by`, `created_at`
- `detail_penerimaan`: `id`, `penerimaan_id`, `batch_obat_id`, `jumlah`, `harga_beli`
- `mutasi_stok`: `id`, `batch_obat_id`, `jenis_mutasi`, `jumlah`, `tanggal_mutasi`, `referensi`, `catatan`, `created_by`, `created_at`

Pastikan nama kolom di project Supabase kamu cocok dengan daftar ini. Jika berbeda, sesuaikan `app.js` atau kirimkan struktur kolom aktual untuk penyesuaian.

## 4. Kebijakan akses (RLS) dan transaksi

Buka file `supabase_setup.sql`, tinjau nama kolomnya, lalu jalankan di Supabase SQL Editor. Skrip mengaktifkan RLS dan memberi hak CRUD kepada role `authenticated` pada keenam tabel—artinya kedua akun yang dapat login sama-sama menjadi admin. Skrip juga membuat fungsi transaksi stok masuk/keluar yang memperbarui saldo dan mencatat mutasi dalam satu transaksi database. Jalankan hanya setelah memastikan nama tabel dan kolom cocok dengan database yang sudah kamu buat. Jangan mengaktifkan akses `anon` untuk data inventaris.

## 5. Deploy Vercel

Pastikan `index.html`, `styles.css`, `app.js`, dan `config.js` berada di root repository. Framework preset bisa `Other`; build command dikosongkan, output directory `.`. Setelah push, cek domain Vercel.

## Catatan integritas transaksi

Penerimaan dan pengeluaran menggunakan PostgreSQL RPC dari `supabase_setup.sql` agar perubahan saldo dan catatan mutasi dijalankan secara atomik. Tetap verifikasi nama kolom dan kebijakan RLS sebelum memakai data persediaan nyata.
