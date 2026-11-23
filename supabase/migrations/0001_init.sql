-- ============================================================================
-- Dmoney Manager — Supabase sync schema (P0, v3.0.0)
-- ============================================================================
-- One mirrored table per local Drift table (14 total), plus the private
-- Storage bucket for receipt photos. Run the whole file in the Supabase
-- dashboard SQL Editor. It is safe to run twice: tables use IF NOT EXISTS,
-- policies/triggers are dropped first, the bucket insert is ON CONFLICT
-- DO NOTHING.
--
-- Design notes (see the concept doc for the full reasoning):
--  * sync_id is the cross-device identity (matches the local syncId UUID).
--    Local integer ids are NOT stored on the server at all; every foreign
--    key here references another table's sync_id (text).
--  * owner_id + Row Level Security is the security boundary. There is
--    exactly one owner (own devices only); every policy is
--    auth.uid() = owner_id. The anon key is safe to ship in the app
--    because RLS, not the key, protects the data.
--  * server_updated_at is the ordering authority for pull. It defaults to
--    now() on insert and a trigger refreshes it on every update, so the
--    server clock — never a phone clock — decides which change is newer.
--    Clients must NOT send server_updated_at.
--  * P2 upsert guidance: use a conditional upsert (only UPDATE when the
--    incoming row actually differs). An unconditional ON CONFLICT DO UPDATE
--    fires the trigger and bumps server_updated_at even when nothing
--    changed, which makes the other device re-pull identical rows.
--  * Derived columns (wallets.balance, installment_plans.paid_count,
--    goals.saved) ARE stored here for schema completeness, but the client
--    NEVER trusts them: after every pull it recomputes them from the
--    ledger (see concept §7). recurring_transactions.next_due is also
--    stored, and syncs last-write-wins (newest wins) — recomputing it
--    from generated transactions risks double-posting an occurrence.
--  * No uniqueness constraints beyond primary keys, deliberately: the
--    server must never reject a row the local database accepted (e.g. the
--    known duplicate-budget edge). The one exception is
--    category_keywords, whose local composite key is preserved.
--  * Sync never issues DELETE. Deletes are tombstones (deleted_at set);
--    rows stay on the server so a late-arriving edit can be compared
--    against the tombstone instead of resurrecting the row.
-- ============================================================================

-- --------------------------------------------------------------------------
-- Tables (creation order follows foreign-key dependencies: parents first)
-- --------------------------------------------------------------------------

-- Local: Accounts { id, name, kind, colorHex }
create table if not exists public.accounts (
  sync_id text primary key,
  owner_id uuid not null,
  server_updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  name text not null,
  kind text not null, -- personal | work | family
  color_hex text not null default '#C6FF4A'
);

-- Local: Categories { id, name, iconKey, colorHex, kind, parentId, sortOrder }
create table if not exists public.categories (
  sync_id text primary key,
  owner_id uuid not null,
  server_updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  name text not null,
  icon_key text not null default 'other',
  color_hex text not null default '#A78BFA',
  kind text not null, -- income | expense
  parent_id text references public.categories (sync_id),
  sort_order bigint not null default 0
);

-- Local: Goals { id, name, target, saved, colorHex, deadline }
create table if not exists public.goals (
  sync_id text primary key,
  owner_id uuid not null,
  server_updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  name text not null,
  target bigint not null,
  -- Derived: recomputed locally from goal_deposits after pull; the value
  -- stored here is never applied to local state.
  saved bigint not null default 0,
  color_hex text not null default '#C6FF4A',
  deadline timestamptz
);

-- Local: Wallets { id, accountId, name, kind, balance, initialAmount,
--   colorHex, logoTemplate, sortOrder, creditLimit, statementDay, dueDay,
--   interestRateMonthly, interestRateAnnual }
create table if not exists public.wallets (
  sync_id text primary key,
  owner_id uuid not null,
  server_updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  account_id text not null references public.accounts (sync_id),
  name text not null,
  kind text not null, -- cash | bank | ewallet | credit
  -- Derived: recomputed locally from initial_amount + the transaction
  -- ledger after pull; the value stored here is never applied to local
  -- state.
  balance bigint not null default 0,
  initial_amount bigint not null default 0,
  color_hex text not null default '#C6FF4A',
  logo_template text,
  sort_order bigint not null default 0,
  -- Named credit_limit, not "limit": LIMIT is a reserved word in Postgres
  -- (and in SQLite, which is why the local column is named this way too).
  credit_limit bigint,
  statement_day bigint,
  due_day bigint,
  interest_rate_monthly double precision,
  interest_rate_annual double precision
);

-- Local: InstallmentPlans { id, walletId, name, totalAmount,
--   installmentAmount, totalCount, paidCount, createdAt }
create table if not exists public.installment_plans (
  sync_id text primary key,
  owner_id uuid not null,
  server_updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  wallet_id text not null references public.wallets (sync_id),
  name text not null,
  total_amount bigint not null,
  installment_amount bigint not null,
  total_count bigint not null,
  -- Derived: re-derived locally from recorded installment-payment
  -- transfers after pull; the value stored here is never applied.
  paid_count bigint not null default 0,
  created_at timestamptz not null default now()
);

-- Local: Debts { id, person, note, amount, direction, isPaid, dueDate,
--   colorHex, walletId, createdAt, recordAsTransaction }
create table if not exists public.debts (
  sync_id text primary key,
  owner_id uuid not null,
  server_updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  person text not null,
  note text not null default '',
  amount bigint not null,
  direction text not null, -- payable | receivable
  is_paid boolean not null default false,
  due_date timestamptz,
  color_hex text not null default '#A78BFA',
  wallet_id text references public.wallets (sync_id),
  created_at timestamptz not null default now(),
  record_as_transaction boolean not null default true
);

-- Local: DebtPayments { id, debtId, amount, date, note, walletId }
create table if not exists public.debt_payments (
  sync_id text primary key,
  owner_id uuid not null,
  server_updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  debt_id text not null references public.debts (sync_id),
  amount bigint not null,
  date timestamptz not null,
  note text not null default '',
  wallet_id text references public.wallets (sync_id)
);

-- Local: GoalDeposits { id, goalId, amount, date, note }
create table if not exists public.goal_deposits (
  sync_id text primary key,
  owner_id uuid not null,
  server_updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  goal_id text not null references public.goals (sync_id),
  amount bigint not null, -- positive = deposit, negative = withdrawal
  date timestamptz not null,
  note text not null default ''
);

-- Local: RecurringTransactions { id, walletId, categoryId, kind, amount,
--   note, frequency, nextDue, endDate, active }
create table if not exists public.recurring_transactions (
  sync_id text primary key,
  owner_id uuid not null,
  server_updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  wallet_id text not null references public.wallets (sync_id),
  category_id text not null references public.categories (sync_id),
  kind text not null, -- income | expense
  amount bigint not null,
  note text not null default '',
  frequency text not null, -- daily | weekly | monthly | yearly
  -- Synced as a value, newest wins. Pull MUST run before recurring
  -- generation on launch, or a device with a stale next_due will
  -- materialise an occurrence the other device already posted.
  next_due timestamptz not null,
  end_date timestamptz,
  active boolean not null default true
);

-- Local: Transactions { id, walletId, categoryId, kind, amount, note, memo,
--   date, createdAt, toWalletId, debtId, debtPaymentId, recurringId,
--   transferId, planId }
create table if not exists public.transactions (
  sync_id text primary key,
  owner_id uuid not null,
  server_updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  wallet_id text not null references public.wallets (sync_id),
  category_id text not null references public.categories (sync_id),
  kind text not null, -- income | expense | transfer
  amount bigint not null, -- whole IDR, always positive
  note text not null default '',
  memo text not null default '',
  date timestamptz not null,
  created_at timestamptz not null default now(),
  to_wallet_id text references public.wallets (sync_id),
  debt_id text references public.debts (sync_id),
  debt_payment_id text references public.debt_payments (sync_id),
  recurring_id text references public.recurring_transactions (sync_id),
  -- Self-reference: a transfer-fee expense row points at its transfer.
  transfer_id text references public.transactions (sync_id),
  plan_id text references public.installment_plans (sync_id)
);

-- Local: TransactionPhotos { id, transactionId, path }
create table if not exists public.transaction_photos (
  sync_id text primary key,
  owner_id uuid not null,
  server_updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  transaction_id text not null references public.transactions (sync_id),
  -- Storage object key, NOT a local filesystem path:
  -- receipts/<owner-uid>/<transaction-sync-id>/<photo-sync-id>.jpg
  -- The client derives it from the key layout; it never uploads a
  -- device-local path.
  path text not null
);

-- Local: Budgets { id, categoryId, month, limit }
create table if not exists public.budgets (
  sync_id text primary key,
  owner_id uuid not null,
  server_updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  category_id text not null references public.categories (sync_id),
  month text not null, -- yyyy-MM
  -- Quoted: LIMIT is a reserved word in Postgres.
  "limit" bigint not null
);

-- Local: TransactionTemplates { id, name, walletId, categoryId, kind,
--   amount, note, useCount }
create table if not exists public.transaction_templates (
  sync_id text primary key,
  owner_id uuid not null,
  server_updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  name text not null,
  wallet_id text not null references public.wallets (sync_id),
  category_id text not null references public.categories (sync_id),
  kind text not null, -- income | expense
  amount bigint not null,
  note text not null default '',
  -- Usage counter. Syncs last-write-wins and may undercount slightly
  -- when two devices use the same template between syncs. Cosmetic only.
  use_count bigint not null default 0
);

-- Local: CategoryKeywords { keyword, categoryId, hits } — composite PK,
-- no integer id. The server keeps the same logical key.
create table if not exists public.category_keywords (
  -- Deterministic, NOT a random UUID: 'kw:' || keyword || ':' ||
  -- category sync_id. Two devices learning the same keyword produce the
  -- same sync_id, so the upsert merges instead of colliding on the unique
  -- key below. P1 must generate syncIds for this table this way.
  sync_id text primary key,
  owner_id uuid not null,
  server_updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  keyword text not null,
  category_id text not null references public.categories (sync_id),
  -- Learned counter. Last-write-wins, may undercount. Cosmetic only.
  hits bigint not null default 0,
  unique (owner_id, keyword, category_id)
);

-- --------------------------------------------------------------------------
-- server_updated_at maintenance: stamp every update with the server clock
-- --------------------------------------------------------------------------

create or replace function public.set_server_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.server_updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_accounts_server_updated_at on public.accounts;
create trigger trg_accounts_server_updated_at
  before update on public.accounts
  for each row execute function public.set_server_updated_at();

drop trigger if exists trg_categories_server_updated_at on public.categories;
create trigger trg_categories_server_updated_at
  before update on public.categories
  for each row execute function public.set_server_updated_at();

drop trigger if exists trg_goals_server_updated_at on public.goals;
create trigger trg_goals_server_updated_at
  before update on public.goals
  for each row execute function public.set_server_updated_at();

drop trigger if exists trg_wallets_server_updated_at on public.wallets;
create trigger trg_wallets_server_updated_at
  before update on public.wallets
  for each row execute function public.set_server_updated_at();

drop trigger if exists trg_installment_plans_server_updated_at on public.installment_plans;
create trigger trg_installment_plans_server_updated_at
  before update on public.installment_plans
  for each row execute function public.set_server_updated_at();

drop trigger if exists trg_debts_server_updated_at on public.debts;
create trigger trg_debts_server_updated_at
  before update on public.debts
  for each row execute function public.set_server_updated_at();

drop trigger if exists trg_debt_payments_server_updated_at on public.debt_payments;
create trigger trg_debt_payments_server_updated_at
  before update on public.debt_payments
  for each row execute function public.set_server_updated_at();

drop trigger if exists trg_goal_deposits_server_updated_at on public.goal_deposits;
create trigger trg_goal_deposits_server_updated_at
  before update on public.goal_deposits
  for each row execute function public.set_server_updated_at();

drop trigger if exists trg_recurring_transactions_server_updated_at on public.recurring_transactions;
create trigger trg_recurring_transactions_server_updated_at
  before update on public.recurring_transactions
  for each row execute function public.set_server_updated_at();

drop trigger if exists trg_transactions_server_updated_at on public.transactions;
create trigger trg_transactions_server_updated_at
  before update on public.transactions
  for each row execute function public.set_server_updated_at();

drop trigger if exists trg_transaction_photos_server_updated_at on public.transaction_photos;
create trigger trg_transaction_photos_server_updated_at
  before update on public.transaction_photos
  for each row execute function public.set_server_updated_at();

drop trigger if exists trg_budgets_server_updated_at on public.budgets;
create trigger trg_budgets_server_updated_at
  before update on public.budgets
  for each row execute function public.set_server_updated_at();

drop trigger if exists trg_transaction_templates_server_updated_at on public.transaction_templates;
create trigger trg_transaction_templates_server_updated_at
  before update on public.transaction_templates
  for each row execute function public.set_server_updated_at();

drop trigger if exists trg_category_keywords_server_updated_at on public.category_keywords;
create trigger trg_category_keywords_server_updated_at
  before update on public.category_keywords
  for each row execute function public.set_server_updated_at();

-- --------------------------------------------------------------------------
-- Row Level Security: one owner, everything gated on auth.uid() = owner_id
-- --------------------------------------------------------------------------

alter table public.accounts enable row level security;
drop policy if exists accounts_owner_all on public.accounts;
create policy accounts_owner_all on public.accounts for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

alter table public.categories enable row level security;
drop policy if exists categories_owner_all on public.categories;
create policy categories_owner_all on public.categories for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

alter table public.goals enable row level security;
drop policy if exists goals_owner_all on public.goals;
create policy goals_owner_all on public.goals for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

alter table public.wallets enable row level security;
drop policy if exists wallets_owner_all on public.wallets;
create policy wallets_owner_all on public.wallets for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

alter table public.installment_plans enable row level security;
drop policy if exists installment_plans_owner_all on public.installment_plans;
create policy installment_plans_owner_all on public.installment_plans for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

alter table public.debts enable row level security;
drop policy if exists debts_owner_all on public.debts;
create policy debts_owner_all on public.debts for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

alter table public.debt_payments enable row level security;
drop policy if exists debt_payments_owner_all on public.debt_payments;
create policy debt_payments_owner_all on public.debt_payments for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

alter table public.goal_deposits enable row level security;
drop policy if exists goal_deposits_owner_all on public.goal_deposits;
create policy goal_deposits_owner_all on public.goal_deposits for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

alter table public.recurring_transactions enable row level security;
drop policy if exists recurring_transactions_owner_all on public.recurring_transactions;
create policy recurring_transactions_owner_all on public.recurring_transactions for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

alter table public.transactions enable row level security;
drop policy if exists transactions_owner_all on public.transactions;
create policy transactions_owner_all on public.transactions for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

alter table public.transaction_photos enable row level security;
drop policy if exists transaction_photos_owner_all on public.transaction_photos;
create policy transaction_photos_owner_all on public.transaction_photos for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

alter table public.budgets enable row level security;
drop policy if exists budgets_owner_all on public.budgets;
create policy budgets_owner_all on public.budgets for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

alter table public.transaction_templates enable row level security;
drop policy if exists transaction_templates_owner_all on public.transaction_templates;
create policy transaction_templates_owner_all on public.transaction_templates for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

alter table public.category_keywords enable row level security;
drop policy if exists category_keywords_owner_all on public.category_keywords;
create policy category_keywords_owner_all on public.category_keywords for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- --------------------------------------------------------------------------
-- Pull indexes: every pull is
--   where owner_id = ? and server_updated_at > ? order by server_updated_at
-- --------------------------------------------------------------------------

create index if not exists idx_accounts_pull on public.accounts (owner_id, server_updated_at);
create index if not exists idx_categories_pull on public.categories (owner_id, server_updated_at);
create index if not exists idx_goals_pull on public.goals (owner_id, server_updated_at);
create index if not exists idx_wallets_pull on public.wallets (owner_id, server_updated_at);
create index if not exists idx_installment_plans_pull on public.installment_plans (owner_id, server_updated_at);
create index if not exists idx_debts_pull on public.debts (owner_id, server_updated_at);
create index if not exists idx_debt_payments_pull on public.debt_payments (owner_id, server_updated_at);
create index if not exists idx_goal_deposits_pull on public.goal_deposits (owner_id, server_updated_at);
create index if not exists idx_recurring_transactions_pull on public.recurring_transactions (owner_id, server_updated_at);
create index if not exists idx_transactions_pull on public.transactions (owner_id, server_updated_at);
create index if not exists idx_transaction_photos_pull on public.transaction_photos (owner_id, server_updated_at);
create index if not exists idx_budgets_pull on public.budgets (owner_id, server_updated_at);
create index if not exists idx_transaction_templates_pull on public.transaction_templates (owner_id, server_updated_at);
create index if not exists idx_category_keywords_pull on public.category_keywords (owner_id, server_updated_at);

-- --------------------------------------------------------------------------
-- Storage: private bucket for receipt photos
-- Object layout inside the bucket: <owner-uid>/<transaction-sync-id>/
--   <photo-sync-id>.jpg
-- The policy below only works if the FIRST folder segment is the user's
-- own uid — the client must upload with exactly that layout, or access is
-- denied by design. If this insert fails in the SQL Editor, create the
-- bucket in Dashboard -> Storage instead (name: receipts, Private).
-- --------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

drop policy if exists receipts_owner_folder on storage.objects;
create policy receipts_owner_folder on storage.objects for all
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);

-- End of 0001_init.sql
