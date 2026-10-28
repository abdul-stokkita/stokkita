-- STOKKITA ONLINE: jalankan seluruh skrip ini di Supabase SQL Editor.
-- Skema memiliki RLS. Jangan pernah menaruh service_role key di HTML/browser.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null default 'pimpinan' check (role in ('admin','petugas','pimpinan')),
  created_at timestamptz not null default now()
);

create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  code text not null unique default ('BRG-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
  name text not null,
  category text not null default 'Lainnya',
  unit text not null default 'pcs',
  stock numeric(14,3) not null default 0 check (stock >= 0),
  min_stock numeric(14,3) not null default 0 check (min_stock >= 0),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.stock_movements (
  id bigint generated always as identity primary key,
  item_id uuid references public.items(id) on delete set null,
  item_code_snapshot text,
  item_name_snapshot text not null,
  type text not null check (type in ('Masuk','Keluar')),
  quantity numeric(14,3) not null check (quantity > 0),
  movement_date date not null default current_date,
  note text not null default '',
  created_by uuid not null references auth.users(id),
  created_by_email text,
  created_at timestamptz not null default now()
);

create index if not exists items_name_idx on public.items(name);
create index if not exists stock_movements_date_idx on public.stock_movements(movement_date desc);
create index if not exists stock_movements_item_idx on public.stock_movements(item_id);

-- Profil otomatis dibuat untuk setiap akun baru. Default role adalah pimpinan (read-only);
-- admin harus menetapkan role petugas/admin secara eksplisit dari SQL Editor.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles(id, display_name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email,'@',1)), 'pimpinan')
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.current_app_role()
returns text language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid() $$;

alter table public.profiles enable row level security;
alter table public.items enable row level security;
alter table public.stock_movements enable row level security;

drop policy if exists "profiles read own or admin" on public.profiles;
create policy "profiles read own or admin" on public.profiles for select to authenticated
using (id = auth.uid() or public.current_app_role() = 'admin');
drop policy if exists "admin manage profiles" on public.profiles;
create policy "admin manage profiles" on public.profiles for update to authenticated
using (public.current_app_role() = 'admin') with check (public.current_app_role() = 'admin');

drop policy if exists "signed in read items" on public.items;
create policy "signed in read items" on public.items for select to authenticated using (true);
drop policy if exists "admin insert items" on public.items;
create policy "admin insert items" on public.items for insert to authenticated
with check (public.current_app_role() = 'admin' and (created_by is null or created_by = auth.uid()));
drop policy if exists "admin update items" on public.items;
create policy "admin update items" on public.items for update to authenticated
using (public.current_app_role() = 'admin') with check (public.current_app_role() = 'admin');
drop policy if exists "admin delete items" on public.items;
create policy "admin delete items" on public.items for delete to authenticated
using (public.current_app_role() = 'admin');

drop policy if exists "signed in read movements" on public.stock_movements;
create policy "signed in read movements" on public.stock_movements for select to authenticated using (true);
-- Penulisan pergerakan stok hanya melalui RPC agar stok dan riwayat berubah dalam satu transaksi.
drop policy if exists "no direct movement inserts" on public.stock_movements;
create policy "no direct movement inserts" on public.stock_movements for insert to authenticated with check (false);
drop policy if exists "no direct movement updates" on public.stock_movements;
create policy "no direct movement updates" on public.stock_movements for update to authenticated using (false);
drop policy if exists "no direct movement deletes" on public.stock_movements;
create policy "no direct movement deletes" on public.stock_movements for delete to authenticated using (false);

create or replace function public.record_stock_movement(
  p_item_id uuid, p_type text, p_quantity numeric,
  p_movement_date date default current_date, p_note text default ''
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.items%rowtype;
  v_id bigint;
begin
  if auth.uid() is null then raise exception 'Anda harus login.'; end if;
  if public.current_app_role() not in ('admin','petugas') then
    raise exception 'Akun Anda hanya memiliki akses baca.';
  end if;
  if p_type not in ('Masuk','Keluar') then raise exception 'Jenis transaksi tidak valid.'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Jumlah harus lebih dari nol.'; end if;

  select * into v_item from public.items where id = p_item_id for update;
  if not found then raise exception 'Barang tidak ditemukan.'; end if;
  if p_type = 'Keluar' and v_item.stock < p_quantity then
    raise exception 'Stok tidak mencukupi. Stok tersedia: % %', v_item.stock, v_item.unit;
  end if;

  update public.items
  set stock = case when p_type = 'Masuk' then stock + p_quantity else stock - p_quantity end
  where id = p_item_id;

  insert into public.stock_movements
    (item_id,item_code_snapshot,item_name_snapshot,type,quantity,movement_date,note,created_by,created_by_email)
  values
    (v_item.id,v_item.code,v_item.name,p_type,p_quantity,coalesce(p_movement_date,current_date),
     coalesce(p_note,''),auth.uid(),(select email from auth.users where id=auth.uid()))
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.record_stock_movement(uuid,text,numeric,date,text) from public;
grant execute on function public.record_stock_movement(uuid,text,numeric,date,text) to authenticated;

grant usage on schema public to authenticated;
grant select on public.profiles, public.items, public.stock_movements to authenticated;
grant insert, update, delete on public.items to authenticated;
grant update on public.profiles to authenticated;
grant usage, select on sequence public.stock_movements_id_seq to authenticated;

-- SETUP AKUN ADMIN (jalankan setelah user membuat akun lewat Supabase Auth):
-- 1. Buka Authentication > Users, salin UUID akun Anda.
-- 2. Jalankan query berikut dengan mengganti UUID:
-- update public.profiles set role = 'admin', display_name = 'Administrator'
-- where id = 'GANTI-DENGAN-UUID-AKUN';
-- Untuk staf gudang:
-- update public.profiles set role = 'petugas' where id = 'UUID-AKUN-PETUGAS';
-- Akun baru secara default menjadi 'pimpinan' (hanya baca).
