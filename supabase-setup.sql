-- =====================================================================
--  CONFIGURACIÓN DEL PANEL DE FOTOS (Supabase)
--
--  ANTES DE EJECUTAR:
--    Cambia TU_CORREO@ejemplo.com (en la línea marcada con <<<) por el correo
--    con el que vas a entrar al panel. Solo esa cuenta podrá subir,
--    editar y borrar fotos. Todo el mundo podrá VER las fotos publicadas.
--
--  CÓMO EJECUTAR:
--    Supabase > SQL Editor > New query > pega TODO este archivo > Run.
--    Se puede ejecutar más de una vez sin problema.
-- =====================================================================

-- 1) Quién es el administrador
create or replace function public.es_admin()
returns boolean
language sql
stable
as $$
  select coalesce(lower(auth.jwt() ->> 'email') = lower('abrillopezandresfelipe76@gmail.com'), false);  -- <<< CAMBIA ESTE CORREO
$$;

-- 2) Tabla de trabajos
create table if not exists public.trabajos (
  id           uuid primary key default gen_random_uuid(),
  titulo       text not null,
  categoria    text not null default 'Sofás',
  descripcion  text not null default '',
  fecha        text not null default to_char(now(), 'YYYY-MM'),
  antes_url    text,
  despues_url  text not null,
  antes_path   text,
  despues_path text,
  ancho        integer not null default 1600,
  alto         integer not null default 1200,
  orden        bigint not null default (-(extract(epoch from now()) * 1000))::bigint,
  visible      boolean not null default true,
  creado       timestamptz not null default now()
);

-- 3) Permisos de la tabla
alter table public.trabajos enable row level security;

grant select on public.trabajos to anon, authenticated;
grant insert, update, delete on public.trabajos to authenticated;

drop policy if exists "ver trabajos" on public.trabajos;
create policy "ver trabajos" on public.trabajos
  for select using (visible = true or public.es_admin());

drop policy if exists "admin agrega" on public.trabajos;
create policy "admin agrega" on public.trabajos
  for insert to authenticated with check (public.es_admin());

drop policy if exists "admin edita" on public.trabajos;
create policy "admin edita" on public.trabajos
  for update to authenticated using (public.es_admin()) with check (public.es_admin());

drop policy if exists "admin borra" on public.trabajos;
create policy "admin borra" on public.trabajos
  for delete to authenticated using (public.es_admin());

-- 4) Carpeta de fotos (pública para verlas, solo el admin puede subir)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('trabajos', 'trabajos', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = true,
      file_size_limit = 5242880,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists "fotos publicas" on storage.objects;
create policy "fotos publicas" on storage.objects
  for select using (bucket_id = 'trabajos');

drop policy if exists "admin sube fotos" on storage.objects;
create policy "admin sube fotos" on storage.objects
  for insert to authenticated with check (bucket_id = 'trabajos' and public.es_admin());

drop policy if exists "admin cambia fotos" on storage.objects;
create policy "admin cambia fotos" on storage.objects
  for update to authenticated using (bucket_id = 'trabajos' and public.es_admin());

drop policy if exists "admin borra fotos" on storage.objects;
create policy "admin borra fotos" on storage.objects
  for delete to authenticated using (bucket_id = 'trabajos' and public.es_admin());
