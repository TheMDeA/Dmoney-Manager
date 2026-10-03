#!/usr/bin/env python3
"""Generate a sample Dmoney Manager backup zip for testing backup/restore
(and every other feature: stats, search, budgets, goals, debts, photos).

Output: ~/workspace/your_files/dmoney-sample-backup.zip
Restore it in the app via Settings > Backup & restore > Restore from file,
or on the onboarding screen.

Schema notes (must match drift):
- DateTime columns are INTEGER unix-epoch seconds.
- Bool columns are INTEGER 0/1.
- Table/column names are drift's snake_case defaults; schema v7.
"""
import json
import os
import sqlite3
import zipfile
from datetime import datetime, timedelta, timezone

WITA = timezone(timedelta(hours=8))
HOME = os.path.expanduser("~")
OUT_ZIP = os.path.join(HOME, "workspace/your_files/dmoney-sample-backup.zip")
WORK = "/tmp/dmoney_sample"
DB_PATH = os.path.join(WORK, "database.sqlite")

# Fake on-device path; the app's restore rewrites photo paths to the
# real documents dir, so this value only needs the right filename.
FAKE_DOCS = "/data/user/0/com.dmda.dmoneymanager/app_flutter"


def ts(y, m, d, hh=12, mm=0):
    return int(datetime(y, m, d, hh, mm, tzinfo=WITA).timestamp())


SCHEMA = """
CREATE TABLE accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  kind TEXT NOT NULL);
CREATE TABLE wallets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL REFERENCES accounts(id),
  name TEXT NOT NULL,
  kind TEXT NOT NULL,
  balance INTEGER NOT NULL DEFAULT 0,
  initial_amount INTEGER NOT NULL DEFAULT 0,
  color_hex TEXT NOT NULL DEFAULT '#C6FF4A');
CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  icon_key TEXT NOT NULL DEFAULT 'other',
  color_hex TEXT NOT NULL DEFAULT '#A78BFA',
  kind TEXT NOT NULL,
  parent_id INTEGER REFERENCES categories(id),
  sort_order INTEGER NOT NULL DEFAULT 0);
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  wallet_id INTEGER NOT NULL REFERENCES wallets(id),
  category_id INTEGER NOT NULL REFERENCES categories(id),
  kind TEXT NOT NULL,
  amount INTEGER NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  date INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  to_wallet_id INTEGER REFERENCES wallets(id),
  debt_id INTEGER REFERENCES debts(id),
  debt_payment_id INTEGER REFERENCES debt_payments(id));
CREATE TABLE transaction_photos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_id INTEGER NOT NULL REFERENCES transactions(id),
  path TEXT NOT NULL);
CREATE TABLE budgets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id INTEGER NOT NULL REFERENCES categories(id),
  month TEXT NOT NULL,
  "limit" INTEGER NOT NULL);
CREATE TABLE goals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  target INTEGER NOT NULL,
  saved INTEGER NOT NULL DEFAULT 0,
  color_hex TEXT NOT NULL DEFAULT '#C6FF4A',
  deadline INTEGER);
CREATE TABLE debts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  person TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  amount INTEGER NOT NULL,
  direction TEXT NOT NULL,
  is_paid INTEGER NOT NULL DEFAULT 0,
  due_date INTEGER,
  color_hex TEXT NOT NULL DEFAULT '#A78BFA',
  wallet_id INTEGER REFERENCES wallets(id),
  created_at INTEGER NOT NULL,
  record_as_transaction INTEGER NOT NULL DEFAULT 1);
CREATE TABLE debt_payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  debt_id INTEGER NOT NULL REFERENCES debts(id),
  amount INTEGER NOT NULL,
  date INTEGER NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  wallet_id INTEGER REFERENCES wallets(id));
CREATE TABLE goal_deposits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  goal_id INTEGER NOT NULL REFERENCES goals(id),
  amount INTEGER NOT NULL,
  date INTEGER NOT NULL,
  note TEXT NOT NULL DEFAULT '');
"""


def main():
    os.makedirs(WORK, exist_ok=True)
    for f in (DB_PATH,):
        if os.path.exists(f):
            os.remove(f)
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    cur.executescript(SCHEMA)

    # ---------------- accounts & wallets ----------------
    cur.execute("INSERT INTO accounts (name, kind) VALUES ('Personal','personal')")
    wallets = {  # name -> dict(id, initial, balance)
        "Cash": dict(id=1, initial=3000000, color="#C6FF4A", kind="cash"),
        "BCA": dict(id=2, initial=12000000, color="#38BDF8", kind="bank"),
        "GoPay": dict(id=3, initial=1500000, color="#A78BFA", kind="ewallet"),
    }
    for name, w in wallets.items():
        cur.execute(
            "INSERT INTO wallets (id, account_id, name, kind, balance,"
            " initial_amount, color_hex) VALUES (?,?,?,?,?,?,?)",
            (w["id"], 1, name, w["kind"], 0, w["initial"], w["color"]))
        wallets[name]["balance"] = w["initial"]

    # ---------------- categories ----------------
    cats = {}  # name -> id
    def add_cat(name, icon, color, kind, parent=None, sort=0):
        cur.execute(
            "INSERT INTO categories (name, icon_key, color_hex, kind,"
            " parent_id, sort_order) VALUES (?,?,?,?,?,?)",
            (name, icon, color, kind,
             cats[parent] if parent else None, sort))
        cats[name] = cur.lastrowid

    add_cat("Food", "food", "#FB923C", "expense", sort=1)
    add_cat("Coffee", "coffee", "#B45309", "expense", parent="Food", sort=2)
    add_cat("Transport", "transport", "#38BDF8", "expense", sort=3)
    add_cat("Shopping", "shopping", "#F472B6", "expense", sort=4)
    add_cat("Bills", "bills", "#FACC15", "expense", sort=5)
    add_cat("Health", "health", "#34D399", "expense", sort=6)
    add_cat("Entertainment", "entertainment", "#A78BFA", "expense", sort=7)
    add_cat("Other", "other", "#9CA3AF", "expense", sort=8)
    add_cat("Salary", "salary", "#22C55E", "income", sort=1)
    add_cat("Freelance", "freelance", "#22C55E", "income", sort=2)
    add_cat("Transfer", "swap_horiz", "#9CA3AF", "transfer", sort=99)
    add_cat("Debt", "handshake", "#F472B6", "debt", sort=99)

    # ---------------- transactions ----------------
    # (date, wallet, category, kind, amount, note, to_wallet, debt_id, debt_payment_id)
    txs = [
        # income
        ((2026, 8, 25, 9), "BCA", "Salary", "income", 8500000, "Gaji Agustus", None, None, None),
        ((2026, 9, 25, 9), "BCA", "Salary", "income", 8500000, "Gaji September", None, None, None),
        ((2026, 9, 10, 14), "BCA", "Freelance", "income", 1500000, "Logo design client", None, None, None),
        ((2026, 9, 28, 16), "GoPay", "Freelance", "income", 750000, "Video editing", None, None, None),
        # food & coffee
        ((2026, 8, 3, 12, 30), "Cash", "Food", "expense", 45000, "Nasi padang", None, None, None),
        ((2026, 8, 12, 19), "GoPay", "Food", "expense", 68000, "Ayam geprek", None, None, None),
        ((2026, 9, 2, 12, 15), "Cash", "Food", "expense", 52000, "Soto ayam", None, None, None),
        ((2026, 9, 3, 8, 30), "Cash", "Coffee", "expense", 25000, "Kopi kenangan", None, None, None),
        ((2026, 9, 15, 13), "BCA", "Food", "expense", 125000, "Groceries Superindo", None, None, None),
        ((2026, 9, 18, 9), "GoPay", "Coffee", "expense", 32000, "Starbucks", None, None, None),
        ((2026, 9, 22, 19, 30), "GoPay", "Food", "expense", 85000, "Sushi Go", None, None, None),
        ((2026, 10, 1, 12), "Cash", "Food", "expense", 48000, "Bakso", None, None, None),
        ((2026, 10, 2, 8, 15), "Cash", "Coffee", "expense", 22000, "Kopi tubruk", None, None, None),
        ((2026, 10, 2, 18, 45), "GoPay", "Food", "expense", 72000, "Mie gacoan", None, None, None),
        # transport
        ((2026, 8, 20, 8), "Cash", "Transport", "expense", 50000, "Bensin", None, None, None),
        ((2026, 9, 5, 17, 30), "GoPay", "Transport", "expense", 18000, "Gojek to mall", None, None, None),
        ((2026, 9, 19, 8), "Cash", "Transport", "expense", 50000, "Bensin", None, None, None),
        ((2026, 10, 1, 17), "GoPay", "Transport", "expense", 22000, "Grab to office", None, None, None),
        # shopping
        ((2026, 9, 8, 15), "BCA", "Shopping", "expense", 450000, "Uniqlo jacket", None, None, None),
        ((2026, 9, 26, 20), "BCA", "Shopping", "expense", 189000, "Tokopedia - headphones", None, None, None),
        ((2026, 10, 2, 14), "GoPay", "Shopping", "expense", 95000, "Shopee - phone case", None, None, None),
        # bills
        ((2026, 8, 28, 10), "BCA", "Bills", "expense", 350000, "Listrik Agustus", None, None, None),
        ((2026, 9, 1, 10), "BCA", "Bills", "expense", 299000, "Internet Indihome", None, None, None),
        ((2026, 9, 27, 10), "BCA", "Bills", "expense", 365000, "Listrik September", None, None, None),
        ((2026, 9, 27, 10, 5), "BCA", "Bills", "expense", 75000, "Air PDAM", None, None, None),
        # health / entertainment / other
        ((2026, 9, 14, 11), "Cash", "Health", "expense", 120000, "Apotek - vitamins", None, None, None),
        ((2026, 9, 21, 19), "GoPay", "Entertainment", "expense", 100000, "Cinema XXI", None, None, None),
        ((2026, 10, 1, 9), "BCA", "Entertainment", "expense", 55000, "Spotify premium", None, None, None),
        ((2026, 9, 11, 12), "Cash", "Other", "expense", 30000, "Parkir mall", None, None, None),
        # transfer Cash -> GoPay
        ((2026, 9, 1, 8), "Cash", "Transfer", "transfer", 500000, "Top up GoPay", "GoPay", None, None),
        # debt-linked: borrowed from Budi (payable) -> income tx
        ((2026, 9, 5, 10), "BCA", "Debt", "income", 1000000, "Borrowed from Budi", None, 1, None),
        # debt-linked: lent to Sinta (receivable) -> expense tx
        ((2026, 9, 12, 15), "Cash", "Debt", "expense", 500000, "Loan to Sinta", None, 2, None),
        # debt repayments
        ((2026, 9, 20, 19), "BCA", "Debt", "expense", 400000, "Pay Budi (1/3)", None, None, 1),
        ((2026, 9, 28, 18), "Cash", "Debt", "income", 200000, "Sinta repayment", None, None, 3),
        ((2026, 10, 1, 20), "Cash", "Debt", "expense", 300000, "Pay Budi (2/3)", None, None, 2),
    ]
    tx_ids = {}
    for i, (d, wname, cname, kind, amount, note, to_w, debt_id, dp_id) in enumerate(txs, start=1):
        t = ts(*d)
        cur.execute(
            "INSERT INTO transactions (id, wallet_id, category_id, kind, amount,"
            " note, date, created_at, to_wallet_id, debt_id, debt_payment_id)"
            " VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            (i, wallets[wname]["id"], cats[cname], kind, amount, note, t, t,
             wallets[to_w]["id"] if to_w else None, debt_id, dp_id))
        tx_ids[note] = i
        # wallet balance effect
        if kind == "income":
            wallets[wname]["balance"] += amount
        elif kind == "expense":
            wallets[wname]["balance"] -= amount
        elif kind == "transfer":
            wallets[wname]["balance"] -= amount
            wallets[to_w]["balance"] += amount

    for name, w in wallets.items():
        assert w["balance"] >= 0, f"{name} negative: {w['balance']}"
        cur.execute("UPDATE wallets SET balance = ? WHERE id = ?",
                    (w["balance"], w["id"]))

    # ---------------- debts & payments ----------------
    cur.execute(
        "INSERT INTO debts (id, person, note, amount, direction, is_paid,"
        " due_date, color_hex, wallet_id, created_at, record_as_transaction)"
        " VALUES (1,'Budi','Lunch money',1000000,'payable',0,?,"
        "'#F472B6',2,?,1)",
        (ts(2026, 10, 20), ts(2026, 9, 5, 10)))
    cur.execute(
        "INSERT INTO debts (id, person, note, amount, direction, is_paid,"
        " due_date, color_hex, wallet_id, created_at, record_as_transaction)"
        " VALUES (2,'Sinta','',500000,'receivable',0,?,"
        "'#38BDF8',1,?,1)",
        (ts(2026, 11, 12), ts(2026, 9, 12, 15)))
    for pid, debt_id, amount, d, note, wname in [
        (1, 1, 400000, (2026, 9, 20, 19), "Transfer BCA", "BCA"),
        (2, 1, 300000, (2026, 10, 1, 20), "Cash", "Cash"),
        (3, 2, 200000, (2026, 9, 28, 18), "Cash received", "Cash"),
    ]:
        t = ts(*d)
        cur.execute(
            "INSERT INTO debt_payments (id, debt_id, amount, date, note, wallet_id)"
            " VALUES (?,?,?,?,?,?)",
            (pid, debt_id, amount, t, note, wallets[wname]["id"]))

    # ---------------- budgets (Oct 2026) ----------------
    for cname, limit in [("Food", 1500000), ("Transport", 600000),
                         ("Shopping", 2000000), ("Entertainment", 400000)]:
        cur.execute(
            'INSERT INTO budgets (category_id, month, "limit") VALUES (?,?,?)',
            (cats[cname], "2026-10", limit))

    # ---------------- goals ----------------
    cur.execute(
        "INSERT INTO goals (id, name, target, saved, color_hex, deadline)"
        " VALUES (1,'Emergency Fund',15000000,4500000,'#C6FF4A',?)",
        (ts(2027, 6, 30),))
    cur.execute(
        "INSERT INTO goals (id, name, target, saved, color_hex, deadline)"
        " VALUES (2,'Japan Trip',30000000,5200000,'#38BDF8',?)",
        (ts(2027, 12, 20),))
    for gid, amount, d, note in [
        (1, 1500000, (2026, 8, 5, 10), "Setoran awal"),
        (1, 1500000, (2026, 9, 5, 10), "Monthly saving"),
        (1, 1500000, (2026, 10, 2, 10), "Monthly saving"),
        (2, 2000000, (2026, 8, 15, 10), "Flight fund"),
        (2, 2000000, (2026, 9, 15, 10), "Flight fund"),
        (2, 1200000, (2026, 9, 30, 10), "Hotel fund"),
    ]:
        cur.execute(
            "INSERT INTO goal_deposits (goal_id, amount, date, note)"
            " VALUES (?,?,?,?)", (gid, amount, ts(*d), note))

    # ---------------- receipt photos ----------------
    receipts_dir = os.path.join(WORK, "receipts")
    os.makedirs(receipts_dir, exist_ok=True)
    _make_receipt(os.path.join(receipts_dir, "receipt_shopping_1.png"),
                  "UNIQLO", [("Ultra Light Down Jacket", 450000)],
                  "08/09/2026")
    _make_receipt(os.path.join(receipts_dir, "receipt_bills_1.png"),
                  "INDIHOME", [("Internet 50 Mbps - Sep", 299000)],
                  "01/09/2026")
    for tx_note, fname in [("Uniqlo jacket", "receipt_shopping_1.png"),
                            ("Internet Indihome", "receipt_bills_1.png")]:
        cur.execute(
            "INSERT INTO transaction_photos (transaction_id, path)"
            " VALUES (?,?)",
            (tx_ids[tx_note], f"{FAKE_DOCS}/receipts/{fname}"))

    # ---------------- sqlite_sequence ----------------
    for table in ("accounts", "wallets", "categories", "transactions",
                  "transaction_photos", "budgets", "goals", "debts",
                  "debt_payments", "goal_deposits"):
        cur.execute(f"SELECT COALESCE(MAX(id),0) FROM {table}")
        cur.execute("INSERT INTO sqlite_sequence (name, seq) VALUES (?,?)",
                    (table, cur.fetchone()[0]))

    con.commit()
    con.close()

    # ---------------- manifest + prefs + zip ----------------
    manifest = {
        "app": "dmoney_manager",
        "format": 1,
        "schemaVersion": 7,
        "createdAt": datetime.now(WITA).isoformat(),
    }
    with open(os.path.join(WORK, "manifest.json"), "w") as f:
        json.dump(manifest, f)
    prefs = {
        "currencyCode": "IDR",
        "displayName": "Miko",
        "themeMode": 2,
        "lockEnabled": False,
        "notifBudgetAlerts": True,
        "notifDebtReminders": True,
    }
    with open(os.path.join(WORK, "prefs.json"), "w") as f:
        json.dump(prefs, f)

    if os.path.exists(OUT_ZIP):
        os.remove(OUT_ZIP)
    with zipfile.ZipFile(OUT_ZIP, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(DB_PATH, "database.sqlite")
        z.write(os.path.join(WORK, "manifest.json"), "manifest.json")
        z.write(os.path.join(WORK, "prefs.json"), "prefs.json")
        for root, _, files in os.walk(receipts_dir):
            for fn in files:
                full = os.path.join(root, fn)
                z.write(full, "receipts/" + fn)
    print("wrote", OUT_ZIP, os.path.getsize(OUT_ZIP), "bytes")


def _make_receipt(path, merchant, items, date_str):
    from PIL import Image, ImageDraw
    img = Image.new("RGB", (420, 560), "white")
    d = ImageDraw.Draw(img)
    y = 30
    d.text((150, y), merchant, fill="black")
    y += 40
    d.line([(20, y), (400, y)], fill="black")
    y += 15
    d.text((20, y), date_str, fill="black")
    y += 35
    total = 0
    for name, price in items:
        d.text((20, y), name[:28], fill="black")
        d.text((300, y), f"{price:,}".replace(",", "."), fill="black")
        y += 28
        total += price
    y += 10
    d.line([(20, y), (400, y)], fill="black")
    y += 15
    d.text((20, y), "TOTAL", fill="black")
    d.text((300, y), f"{total:,}".replace(",", "."), fill="black")
    y += 60
    d.text((120, y), "*** THANK YOU ***", fill="black")
    img.save(path)


if __name__ == "__main__":
    main()
