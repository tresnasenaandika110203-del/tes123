-- FinkaCare - setup keamanan dan transaksi stok
-- Disesuaikan dengan skema tabel yang dikirim pengguna.
-- Jalankan di Supabase SQL Editor sebagai project owner.
-- PENTING: isi dua UUID admin pada bagian INSERT ADMIN sebelum menjalankan.

-- 1) Daftar allowlist admin. Hanya project owner yang mengelola daftar ini via SQL Editor.
create table if not exists public.admin_users (
    user_id uuid primary key references auth.users(id) on delete cascade,
    created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;

drop policy if exists "admin_users_select_self" on public.admin_users;
create policy "admin_users_select_self"
    on public.admin_users for select to authenticated
    using (user_id = auth.uid());

insert into public.admin_users (user_id)
values
    ('fed02d5a-af99-4220-84ef-465779df8970'),
    ('17f20846-0512-47cc-8798-405d21814df8')
on conflict (user_id) do nothing;

-- 2) Pastikan RLS aktif pada tabel inventaris.
alter table public.obat enable row level security;
alter table public.batch_obat enable row level security;
alter table public.supplier enable row level security;
alter table public.penerimaan enable row level security;
alter table public.detail_penerimaan enable row level security;
alter table public.mutasi_stok enable row level security;

-- 3) Hapus kebijakan FinkaCare lama jika pernah dibuat, lalu izinkan admin saja.
drop policy if exists "finkacare_admin_all_obat" on public.obat;
create policy "finkacare_admin_all_obat" on public.obat
for all to authenticated
using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()))
with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));

drop policy if exists "finkacare_admin_all_batch_obat" on public.batch_obat;
create policy "finkacare_admin_all_batch_obat" on public.batch_obat
for all to authenticated
using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()))
with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));

drop policy if exists "finkacare_admin_all_supplier" on public.supplier;
create policy "finkacare_admin_all_supplier" on public.supplier
for all to authenticated
using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()))
with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));

drop policy if exists "finkacare_admin_all_penerimaan" on public.penerimaan;
create policy "finkacare_admin_all_penerimaan" on public.penerimaan
for all to authenticated
using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()))
with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));

drop policy if exists "finkacare_admin_all_detail_penerimaan" on public.detail_penerimaan;
create policy "finkacare_admin_all_detail_penerimaan" on public.detail_penerimaan
for all to authenticated
using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()))
with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));

drop policy if exists "finkacare_admin_all_mutasi_stok" on public.mutasi_stok;
create policy "finkacare_admin_all_mutasi_stok" on public.mutasi_stok
for all to authenticated
using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()))
with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));

-- 4) Fungsi transaksi stok masuk. Mengikuti bigint dan nama kolom skema pengguna.
create or replace function public.catat_stok_masuk(
    p_supplier_id bigint,
    p_nomor_faktur text,
    p_tanggal_penerimaan date,
    p_catatan text,
    p_obat_id bigint,
    p_nomor_batch text,
    p_tanggal_kedaluwarsa date,
    p_jumlah numeric,
    p_harga_beli numeric
) returns bigint
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_penerimaan_id bigint;
    v_batch_id bigint;
    v_stok_sekarang numeric;
begin
    if auth.uid() is null then raise exception 'Login diperlukan.'; end if;
    if not exists (select 1 from public.admin_users a where a.user_id = auth.uid()) then
        raise exception 'Akun ini tidak memiliki akses admin.';
    end if;
    if p_jumlah is null or p_jumlah <= 0 then raise exception 'Jumlah masuk harus lebih besar dari nol.'; end if;
    if p_obat_id is null then raise exception 'Obat wajib dipilih.'; end if;
    if coalesce(trim(p_nomor_batch), '') = '' then raise exception 'Nomor batch wajib diisi.'; end if;
    if coalesce(trim(p_nomor_faktur), '') = '' then raise exception 'Nomor faktur wajib diisi.'; end if;

    insert into public.penerimaan (supplier_id, nomor_faktur, tanggal_penerimaan, catatan)
    values (p_supplier_id, p_nomor_faktur, coalesce(p_tanggal_penerimaan, current_date), p_catatan)
    returning id into v_penerimaan_id;

    select id, coalesce(stok_tersedia, 0)
      into v_batch_id, v_stok_sekarang
      from public.batch_obat
     where obat_id = p_obat_id
       and lower(nomor_batch) = lower(p_nomor_batch)
     limit 1
     for update;

    if v_batch_id is null then
        insert into public.batch_obat
            (obat_id, nomor_batch, tanggal_kedaluwarsa, stok_tersedia, harga_beli)
        values
            (p_obat_id, p_nomor_batch, p_tanggal_kedaluwarsa, p_jumlah, p_harga_beli)
        returning id into v_batch_id;
    else
        update public.batch_obat
           set stok_tersedia = coalesce(v_stok_sekarang, 0) + p_jumlah,
               tanggal_kedaluwarsa = coalesce(p_tanggal_kedaluwarsa, tanggal_kedaluwarsa),
               harga_beli = coalesce(p_harga_beli, harga_beli)
         where id = v_batch_id;
    end if;

    insert into public.detail_penerimaan (penerimaan_id, batch_id, jumlah, harga_beli)
    values (v_penerimaan_id, v_batch_id, p_jumlah, p_harga_beli);

    insert into public.mutasi_stok (batch_id, jenis_mutasi, jumlah, referensi, catatan)
    values (v_batch_id, 'masuk', p_jumlah, p_nomor_faktur, p_catatan);

    return v_penerimaan_id;
end;
$$;

-- 5) Fungsi transaksi stok keluar. Hanya menerima jenis 'keluar' agar saldo konsisten.
create or replace function public.catat_stok_keluar(
    p_batch_id bigint,
    p_jumlah numeric,
    p_referensi text,
    p_catatan text
) returns bigint
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_stok numeric;
    v_mutasi_id bigint;
begin
    if auth.uid() is null then raise exception 'Login diperlukan.'; end if;
    if not exists (select 1 from public.admin_users a where a.user_id = auth.uid()) then
        raise exception 'Akun ini tidak memiliki akses admin.';
    end if;
    if p_jumlah is null or p_jumlah <= 0 then raise exception 'Jumlah keluar harus lebih besar dari nol.'; end if;

    select coalesce(stok_tersedia, 0)
      into v_stok
      from public.batch_obat
     where id = p_batch_id
     for update;
    if not found then raise exception 'Batch tidak ditemukan.'; end if;
    if p_jumlah > v_stok then
        raise exception 'Stok batch tidak mencukupi. Saldo saat ini: %', v_stok;
    end if;

    update public.batch_obat
       set stok_tersedia = v_stok - p_jumlah
     where id = p_batch_id;

    insert into public.mutasi_stok (batch_id, jenis_mutasi, jumlah, referensi, catatan)
    values (p_batch_id, 'keluar', p_jumlah, p_referensi, p_catatan)
    returning id into v_mutasi_id;

    return v_mutasi_id;
end;
$$;

grant execute on function public.catat_stok_masuk(bigint,text,date,text,bigint,text,date,numeric,numeric) to authenticated;
grant execute on function public.catat_stok_keluar(bigint,numeric,text,text) to authenticated;

-- 6) Berikan akses API kepada role authenticated untuk tabel yang digunakan aplikasi.
-- RLS di atas tetap membatasi data hanya untuk UID admin yang terdaftar.
grant select, insert, update, delete on public.obat, public.batch_obat, public.supplier,
    public.penerimaan, public.detail_penerimaan, public.mutasi_stok to authenticated;


-- 7) Kolom jenis obat sesuai workbook DATA OBAT.
alter table public.obat add column if not exists jenis_obat text;

-- 8) Opsi dropdown yang dibagikan antarperangkat dan tersimpan di database.
create table if not exists public.pengaturan_opsi (
    jenis text not null check (jenis in ('kategori','bentuk_sediaan','satuan_dasar')),
    nilai text not null,
    created_at timestamptz not null default now(),
    primary key (jenis, nilai)
);
alter table public.pengaturan_opsi enable row level security;
drop policy if exists "finkacare_admin_all_pengaturan_opsi" on public.pengaturan_opsi;
create policy "finkacare_admin_all_pengaturan_opsi" on public.pengaturan_opsi
for all to authenticated
using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()))
with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));
grant select, insert, update, delete on public.pengaturan_opsi to authenticated;

insert into public.pengaturan_opsi (jenis, nilai) values
('kategori','Obat Keras'),
('kategori','Obat Bebas Terbatas'),
('kategori','Obat Bebas'),
('kategori','Jamu / Obat Herbal Terstandar'),
('kategori','Alat Kesehatan'),
('bentuk_sediaan','Tablet'),
('bentuk_sediaan','Kaplet'),
('bentuk_sediaan','Kapsul'),
('bentuk_sediaan','Sirup'),
('bentuk_sediaan','Salep'),
('bentuk_sediaan','Krim'),
('bentuk_sediaan','Gel'),
('bentuk_sediaan','Larutan'),
('bentuk_sediaan','Serbuk'),
('bentuk_sediaan','Kasa Steril'),
('bentuk_sediaan','Plester'),
('bentuk_sediaan','Masker Medis'),
('bentuk_sediaan','Infusion Set'),
('bentuk_sediaan','Alat Kesehatan'),
('satuan_dasar','Pcs'),
('satuan_dasar','Strip'),
('satuan_dasar','Botol'),
('satuan_dasar','Dus/Box'),
('satuan_dasar','Lembar'),
('satuan_dasar','Sachet'),
('satuan_dasar','Tube'),
('satuan_dasar','Ampul'),
('satuan_dasar','Vial'),
('satuan_dasar','Pack')
on conflict (jenis, nilai) do nothing;
