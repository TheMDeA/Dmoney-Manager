-- ============================================================================
-- 0002_devices.sql — device registry for the sync device list (idea #2)
-- Run after 0001_init.sql. Idempotent (safe to run twice).
--
-- One row per device that has ever synced. Heartbeat only — no data flows
-- through it. Each sync upserts the device's row (label + last_seen_at +
-- app_version). The app reads this table to show "which of my devices are
-- in sync, and when each last synced" in Settings.
-- ============================================================================

create table if not exists public.devices (
  -- UUID generated on the device at first sync (its stable sync identity).
  device_id text primary key,
  owner_id uuid not null,
  -- User-editable; defaults to a device model string on first sync.
  label text not null,
  last_seen_at timestamptz not null default now(),
  app_version text
);

alter table public.devices enable row level security;

drop policy if exists devices_owner_all on public.devices;
create policy devices_owner_all on public.devices for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create index if not exists idx_devices_owner_seen
  on public.devices (owner_id, last_seen_at desc);
