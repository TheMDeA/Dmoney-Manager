-- ============================================================================
-- 0003_prefs.sql — synced preferences (P5, §7)
-- Run after 0002_devices.sql (0001 first, then 0002, then 0003).
-- Idempotent (safe to run twice).
--
-- ONE row per owner: currency + language only — the allowlist. Every
-- other preference (theme, lock, notification toggles, account
-- scope, …) is device-local by design and never leaves the device.
--
-- Ordering: `server_updated_at` is the only authority. The client
-- keeps the stamp it last saw (AppPrefs.syncPrefsUpdatedAt): a
-- server row newer than the stamp wins over local values, otherwise
-- local values push. The trigger below stamps every UPDATE with
-- the server clock, exactly like the 14 data tables in 0001 (the
-- function is re-declared here so this file also works standalone).
-- ============================================================================

create table if not exists public.sync_prefs (
  -- The Supabase Auth user id — one row per owner, so it is the key.
  owner_id uuid primary key,
  currency_code text not null default 'IDR',
  -- Null means "follow the device language" (the app default).
  language_code text,
  server_updated_at timestamptz not null default now()
);

alter table public.sync_prefs enable row level security;

drop policy if exists sync_prefs_owner_all on public.sync_prefs;
create policy sync_prefs_owner_all on public.sync_prefs for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- Same trigger as 0001 (re-declared so this file works standalone).
create or replace function public.set_server_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.server_updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_sync_prefs_server_updated_at on public.sync_prefs;
create trigger trg_sync_prefs_server_updated_at
  before update on public.sync_prefs
  for each row execute function public.set_server_updated_at();
