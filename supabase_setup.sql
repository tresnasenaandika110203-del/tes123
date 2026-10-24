-- FinkaCare: kebijakan akses dan fungsi transaksi stok.
-- Jalankan di Supabase SQL Editor setelah memastikan nama tabel/kolom cocok.
-- Semua akun yang berhasil login akan memiliki akses admin penuh ke data inventaris.

-- RLS harus aktif. Kebijakan berikut membatasi operasi kepada role authenticated.
alter table public.obat enable row level security;
alter table public.batch_obat enable row level security;
alter table public.supplier enable row level security;
alter table public.penerimaan enable row level security;
alter table public.detail_penerimaan enable row level security;
alter table public.mutasi_stok enable row level security;

-- Drop kebijakan dengan nama yang sama agar skrip dapat dijalankan ulang.
drop policy if exists "finkacare_obat_authenticated_all" on public.obat;
create policy "finkacare_obat_authenticated_all" on public.obat for all to authenticated using (true) with check (true);
drop policy if exists "finkacare_batch_authenticated_all" on public.batch_obat;
create policy "finkacare_batch_authenticated_all" on public.batch_obat for all to authenticated using (true) with check (true);
drop policy if exists "finkacare_supplier_authenticated_all" on public.supplier;
create policy "finkacare_supplier_authenticated_all" on public.supplier for all to authenticated using (true) with check (true);
drop policy if exists "finkacare_penerimaan_authenticated_all" on public.penerimaan;
create policy "finkacare_penerimaan_authenticated_all" on public.penerimaan for all to authenticated using (true) with check (true);
drop policy if exists "finkacare_detail_penerimaan_authenticated_all" on public.detail_penerimaan;
create policy "finkacare_detail_penerimaan_authenticated_all" on public.detail_penerimaan for all to authenticated using (true) with check (true);
drop policy if exists "finkacare_mutasi_authenticated_all" on public.mutasi_stok;
create policy "finkacare_mutasi_authenticated_all" on public.mutasi_stok for all to authenticated using (true) with check (true);

-- Fungsi ini membuat penerimaan, detail, batch, dan mutasi dalam satu transaksi database.
create or replace function public.catat_stok_masuk(
  p_supplier_id uuid,
  p_nomor_faktur text,
  p_tanggal_penerimaan date,
  p_catatan text,
  p_obat_id uuid,
  p_nomor_batch text,
  p_tanggal_kedaluwarsa date,
  p_jumlah numeric,
  p_harga_beli numeric
) returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_penerimaan_id uuid;
  v_batch_id uuid;
  v_stok_sekarang numeric;
begin
  if auth.uid() is null then raise exception 'Login diperlukan.'; end if;
  if p_jumlah is null or p_jumlah <= 0 then raise exception 'Jumlah masuk harus lebih besar dari nol.'; end if;
  if p_obat_id is null then raise exception 'Obat wajib dipilih.'; end if;

  insert into public.penerimaan (supplier_id, nomor_faktur, tanggal_penerimaan, catatan, created_by)
  values (p_supplier_id, p_nomor_faktur, coalesce(p_tanggal_penerimaan, current_date), p_catatan, auth.uid())
  returning id into v_penerimaan_id;

  select id, coalesce(stok_saat_ini, 0) into v_batch_id, v_stok_sekarang
  from public.batch_obat
  where obat_id = p_obat_id
    and lower(coalesce(nomor_batch, '')) = lower(coalesce(p_nomor_batch, ''))
    and tanggal_kedaluwarsa is not distinct from p_tanggal_kedaluwarsa
  limit 1
  for update;

  if v_batch_id is null then
    insert into public.batch_obat (obat_id, nomor_batch, tanggal_kedaluwarsa, stok_awal, stok_saat_ini, harga_beli)
    values (p_obat_id, p_nomor_batch, p_tanggal_kedaluwarsa, p_jumlah, p_jumlah, p_harga_beli)
    returning id into v_batch_id;
  else
    update public.batch_obat
    set stok_saat_ini = coalesce(v_stok_sekarang, 0) + p_jumlah,
        harga_beli = coalesce(p_harga_beli, harga_beli)
    where id = v_batch_id;
  end if;

  insert into public.detail_penerimaan (penerimaan_id, batch_obat_id, jumlah, harga_beli)
  values (v_penerimaan_id, v_batch_id, p_jumlah, p_harga_beli);

  insert into public.mutasi_stok (batch_obat_id, jenis_mutasi, jumlah, tanggal_mutasi, referensi, catatan, created_by)
  values (v_batch_id, 'masuk', p_jumlah, coalesce(p_tanggal_penerimaan, current_date), p_nomor_faktur, p_catatan, auth.uid());

  return v_penerimaan_id;
end;
$$;

-- Fungsi ini mengunci baris batch saat menghitung saldo, lalu menyimpan mutasi secara atomik.
create or replace function public.catat_stok_keluar(
  p_batch_obat_id uuid,
  p_jenis_mutasi text,
  p_jumlah numeric,
  p_tanggal_mutasi date,
  p_referensi text,
  p_catatan text
) returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_stok numeric;
  v_mutasi_id uuid;
begin
  if auth.uid() is null then raise exception 'Login diperlukan.'; end if;
  if p_jumlah is null or p_jumlah <= 0 then raise exception 'Jumlah keluar harus lebih besar dari nol.'; end if;

  select coalesce(stok_saat_ini, 0) into v_stok
  from public.batch_obat where id = p_batch_obat_id for update;
  if not found then raise exception 'Batch tidak ditemukan.'; end if;
  if p_jumlah > v_stok then raise exception 'Stok batch tidak mencukupi. Saldo saat ini: %', v_stok; end if;

  update public.batch_obat set stok_saat_ini = v_stok - p_jumlah where id = p_batch_obat_id;
  insert into public.mutasi_stok (batch_obat_id, jenis_mutasi, jumlah, tanggal_mutasi, referensi, catatan, created_by)
  values (p_batch_obat_id, coalesce(nullif(p_jenis_mutasi, ''), 'keluar'), p_jumlah, coalesce(p_tanggal_mutasi, current_date), p_referensi, p_catatan, auth.uid())
  returning id into v_mutasi_id;
  return v_mutasi_id;
end;
$$;

grant execute on function public.catat_stok_masuk(uuid,text,date,text,uuid,text,date,numeric,numeric) to authenticated;
grant execute on function public.catat_stok_keluar(uuid,text,numeric,date,text,text) to authenticated;
