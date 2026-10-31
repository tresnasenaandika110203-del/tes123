-- Jalankan seluruh skrip di Supabase > SQL Editor.
-- Tidak mengubah tanggal pada data lama atau tanggal mutasi stok.
-- Fungsi aktif dibaca dari database karena definisi RPC multi-obat
-- tidak disertakan dalam repository ini. Perubahan bersifat transaksional.
begin;

alter table public.penerimaan
  alter column tanggal_penerimaan drop not null,
  alter column tanggal_penerimaan drop default;

do $migration$
declare
  fn record;
  definition text;
  original_definition text;
  statement text;
  replacement text;
  matched boolean;
  required_name text;
begin
  -- Kedua RPC ini dipanggil oleh form tambah/ubah aplikasi saat ini.
  foreach required_name in array array['catat_stok_masuk_multi', 'ubah_penerimaan_multi'] loop
    if not exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = required_name
        and 'p_tanggal_penerimaan' = any(p.proargnames)
    ) then
      raise exception 'RPC public.% tidak ditemukan. Migrasi dibatalkan; diperlukan definisi fungsi aktif dari database.', required_name;
    end if;
  end loop;

  for fn in
    select p.oid, p.oid::regprocedure as signature, l.lanname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_language l on l.oid = p.prolang
    where n.nspname = 'public' and p.prokind = 'f'
      and p.proname in ('catat_stok_masuk_multi', 'ubah_penerimaan_multi',
                       'catat_stok_masuk', 'ubah_stok_masuk')
      and 'p_tanggal_penerimaan' = any(p.proargnames)
  loop
    definition := pg_get_functiondef(fn.oid);
    original_definition := definition;
    -- Hanya SQL statis dengan parameter tanggal langsung yang didukung.
    -- Jangan menebak perubahan terhadap validasi khusus atau SQL dinamis.
    if fn.lanname not in ('plpgsql', 'sql')
       or definition ~* '\mexecute\M'
       or definition ~* '\mp_tanggal_penerimaan\M\s+is\s+(not\s+)?null'
       or definition ~* '\mcoalesce\s*\(\s*p_tanggal_penerimaan\s*,\s*[^)]*\)\s+is\s+null' then
      raise exception 'Fungsi % memerlukan pemeriksaan manual. Tidak ada perubahan disimpan. Ambil definisinya dengan pg_get_functiondef.', fn.signature;
    end if;

    matched := false;
    -- Batasi penggantian pada INSERT/UPDATE penerimaan saja.
    -- COALESCE pada mutasi_stok dan validasi lain tetap dipertahankan.
    for statement in
      select m[1] from regexp_matches(definition,
        '(\m(?:insert\s+into|update)\s+(?:public\s*\.\s*)?penerimaan\M[^;]*;)', 'gi') as m
    loop
      if statement ~* '\mtanggal_penerimaan\M'
         and statement ~* '\mp_tanggal_penerimaan\M' then
        replacement := regexp_replace(statement,
          '\mcoalesce\s*\(\s*p_tanggal_penerimaan\s*,\s*(?:current_date|now\s*\(\s*\)\s*::\s*date)\s*\)',
          'p_tanggal_penerimaan', 'gi');
        -- Selain ekspresi fallback yang dikenali, hanya penggunaan
        -- langsung parameter tanggal yang dapat diubah otomatis.
        if replacement ~* '\mcoalesce\s*\(\s*p_tanggal_penerimaan\M' then
          raise exception 'Ekspresi tanggal pada % tidak dikenali; migrasi dibatalkan.', fn.signature;
        end if;
        definition := replace(definition, statement, replacement);
        matched := true;
      end if;
    end loop;

    if not matched then
      raise exception 'Penulisan tanggal penerimaan pada % tidak dikenali. Migrasi dibatalkan; diperlukan definisi fungsi aktif.', fn.signature;
    end if;
    if definition <> original_definition then
      execute definition;
    end if;
    -- Parameter NULL tetap menjalankan fungsi, termasuk bila sebelumnya STRICT.
    execute format('alter function %s called on null input', fn.signature);
    raise notice 'Tanggal penerimaan opsional: %', fn.signature;
  end loop;
end;
$migration$;

notify pgrst, 'reload schema';
commit;

-- Verifikasi: is_nullable harus YES, column_default harus NULL.
select column_name, is_nullable, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'penerimaan'
  and column_name = 'tanggal_penerimaan';

-- Setelah berhasil: kosongkan tanggal pada Catat Penerimaan, simpan
-- dengan baris obat valid, lalu buka Detail/Ubah. Tanggal harus tetap kosong.
-- Jika migrasi dibatalkan, jalankan ROLLBACK; lalu ambil definisi RPC:
-- select p.oid::regprocedure, pg_get_functiondef(p.oid)
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
-- and p.proname in ('catat_stok_masuk_multi', 'ubah_penerimaan_multi',
--                  'catat_stok_masuk', 'ubah_stok_masuk');
