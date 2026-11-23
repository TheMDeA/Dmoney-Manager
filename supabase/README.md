# Dmoney Manager sync — Supabase setup (P0, v3.0.0)

Do these once, in order. Nothing here touches the app — the app is wired
up in a later step, after you send back the two values from step 5.

## 1. Create the project

1. Go to [supabase.com](https://supabase.com) and sign in (or create an
   account).
2. **New project**. Name it `dmoney-sync`, pick the **Free** plan, and
   choose the region closest to you — **Singapore** is the nearest to
   Makassar. Set a database password and save it somewhere safe (it is
   only for direct database access; the app never needs it).
3. Wait for the project to finish provisioning (about a minute).

No credit card is needed for the free tier.

## 2. Create the tables

1. In the project dashboard, open the **SQL Editor** (left sidebar).
2. Open **New query**, paste the entire contents of
   `supabase/migrations/0001_init.sql` from this repo, and press **Run**.
   Then do the same for `supabase/migrations/0002_devices.sql` and
   `supabase/migrations/0003_prefs.sql` (in order — 0001 first, 0002
   second, 0003 third).
3. It should finish with no errors. All three scripts are safe to run
   twice if anything looks off — just run them again.
4. Quick check: open the **Table Editor** — you should see all 14 tables
   (`accounts`, `wallets`, `categories`, `transactions`,
   `transaction_photos`, `budgets`, `goals`, `debts`, `debt_payments`,
   `goal_deposits`, `recurring_transactions`, `transaction_templates`,
   `category_keywords`, `installment_plans`), each with Row Level
   Security enabled, plus a `devices` table and a `sync_prefs` table
   (currency + language only — the rest of the settings stay on each
   device).

## 3. Confirm the Storage bucket

1. Open **Storage** (left sidebar). You should see a private bucket
   named `receipts`.
2. If it is missing (the SQL insert can fail on some projects), create it
   there: **New bucket** → name `receipts` → **Private** → Create.

## 4. Enable Google sign-in

1. Open **Authentication → Providers**, find **Google**, and enable it.
2. **Client ID** — paste this (it is a public identifier, not a secret):
   `762584749177-fcu62fjiqs36e9adqht5e4q0jkop16p1.apps.googleusercontent.com`
   This is the same Web OAuth client already used for the Drive backup.
3. **Client Secret** — in [Google Cloud Console](https://console.cloud.google.com),
   go to **APIs & Services → Credentials**, open that same Web OAuth
   client, and copy the **Client secret** into Supabase.
4. Still in Google Cloud Console, on that same OAuth client, add this
   URL to **Authorized redirect URIs** (it is the Supabase callback for
   your project — replace `<project-ref>` with your project's ref, which
   is the subdomain in the Project URL from step 5):
   `https://<project-ref>.supabase.co/auth/v1/callback`
5. Back in Supabase, **Save** the Google provider.

## 5. Send the app credentials to the assistant

1. Open **Project Settings → API**.
2. Copy the **Project URL** and the **anon `public` key** and send them
   both to the assistant (paste them in chat).
3. The anon key is designed to ship inside client apps — pasting it in
   chat is fine. What protects your data is Row Level Security on every
   table, not the key.
4. **Never** share the `service_role` (secret) key. The app never needs
   it, and the assistant will never ask for it.

## What happens next

Once the assistant has the Project URL and anon key, it wires the app
(P1: local schema, P2: push) to this project. Until then, the app keeps
working exactly as it does today — nothing is synced yet.
