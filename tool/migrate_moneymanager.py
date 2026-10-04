#!/usr/bin/env python3
"""Migrate a Money Manager (RealByte, Room) database into a Dmoney Manager
backup ZIP that can be restored via Settings > Backup & restore.

Source quirks handled:
- amounts are stored in cents (x100) -> whole IDR
- trans.type: 0=income, 1=expense, 2=transfer
- category.type: 1=income, 2=expense; empty names on built-in categories are
  inferred from transaction notes; MM's hidden debt categories (16/29) and
  transfer pseudo-category (0) map to Dmoney's hidden Debt/Transfer categories
- debt.type: 1=receivable (lent), 0=payable (borrowed); debtTrans rows become
  debt_payments; trans rows linked via debt_id/debt_trans_id keep their links
- original IDs are preserved so foreign keys stay intact; sqlite_sequence is
  synced so future inserts continue after the max id
"""
import json
import shutil
import sqlite3
import zipfile
from datetime import datetime, timezone

SRC = '/home/hatch/workspace/user/files/backup_20261003_073207.db'
EMPTY = '/tmp/dmoney_empty.sqlite'  # created by drift (schema v8)
WORK = '/tmp/dmoney_migrated.sqlite'
OUT = ('/home/hatch/workspace/your_files/'
       'dmoney-backup-from-moneymanager-20261003.zip')

DEBT_CAT_ID = 1000
TRANSFER_CAT_ID = 1001

# mm category id -> (dmoney name, kind, iconKey)
CATEGORY_MAP = {
    1: ('Bills', 'expense', 'bills'),
    2: ('Clothing', 'expense', 'shopping'),
    4: ('Entertainment', 'expense', 'entertainment'),
    6: ('Food', 'expense', 'food'),
    7: ('Family', 'expense', 'home'),
    8: ('Personal Care', 'expense', 'spa'),
    10: ('Pets', 'expense', 'pets'),
    11: ('Groceries', 'expense', 'cart'),
    12: ('Transport', 'expense', 'transport'),
    13: ('Travel', 'expense', 'travel'),
    14: ('Fees', 'expense', 'receipt'),
    15: ('Adjustments', 'expense', 'other'),
    21: ('Extra Income', 'income', 'payments'),
    24: ('Salary', 'income', 'salary'),
    26: ('Other Income', 'income', 'paid'),
    27: ('Adjustments', 'income', 'other'),
    30: ('Invest', 'expense', 'trending_up'),
    31: ('Pods', 'expense', 'store'),
    32: ('Koppa Mart', 'expense', 'store'),
    33: ('Work', 'expense', 'salary'),
    34: ('Interest', 'income', 'savings'),
    35: ('Tarik Tunai', 'expense', 'cash'),
    36: ('Crypto', 'expense', 'currency'),
    37: ('Ayang', 'expense', 'gift'),
    38: ('Paylater', 'expense', 'credit_card'),
    39: ('Titipan', 'expense', 'payments'),
    40: ('Online Shopping', 'expense', 'shopping'),
    41: ('Titipan', 'income', 'payments'),
}
HIDDEN_DEBT_CATS = {16, 29}  # MM's internal debt categories
def us(ms):
    """MM millis -> drift DateTime storage (unix seconds)."""
    return None if ms is None else ms // 1000


BANK_KEYWORDS = ('livin', 'mandiri', 'jago', 'bca', 'bri', 'bni', 'bank',
                 'jenius', 'seabank', 'blu')


def wallet_kind(name):
    n = (name or '').lower()
    if any(k in n for k in BANK_KEYWORDS):
        return 'bank'
    if any(k in n for k in ('gopay', 'ovo', 'dana', 'shopeepay', 'linkaja')):
        return 'ewallet'
    return 'cash'


def main():
    src = sqlite3.connect(SRC)
    src.row_factory = sqlite3.Row
    shutil.copy(EMPTY, WORK)
    dst = sqlite3.connect(WORK)
    # Drop drift's seeded defaults so migrated IDs don't collide.
    dst.execute('DELETE FROM categories')

    # ---- accounts ------------------------------------------------------
    for r in src.execute('SELECT * FROM account'):
        dst.execute('INSERT INTO accounts (id, name, kind) VALUES (?,?,?)',
                    (r['id'], r['name'] or 'Account', 'personal'))

    # ---- wallets -------------------------------------------------------
    # NOTE: MM's stored wallet.amount is stale (doesn't match its own
    # transaction history), so balances are recomputed from the imported
    # transactions after they are inserted. initial_amount is trusted.
    for r in src.execute('SELECT * FROM wallet'):
        dst.execute(
            'INSERT INTO wallets (id, account_id, name, kind, balance,'
            ' initial_amount, color_hex) VALUES (?,?,?,?,?,?,?)',
            (r['id'], r['account_id'], r['name'],
             wallet_kind(r['name']),
             r['initial_amount'] // 100, r['initial_amount'] // 100,
             r['color'] or '#C6FF4A'))

    # ---- categories ----------------------------------------------------
    for r in src.execute('SELECT * FROM category ORDER BY id'):
        mm_id = r['id']
        if mm_id in HIDDEN_DEBT_CATS:
            continue  # mapped to the hidden Debt category below
        if mm_id not in CATEGORY_MAP:
            print(f'  SKIP unused/unknown category {mm_id}')
            continue
        name, kind, icon = CATEGORY_MAP[mm_id]
        dst.execute(
            'INSERT INTO categories (id, name, icon_key, color_hex, kind,'
            ' parent_id, sort_order) VALUES (?,?,?,?,?,NULL,?)',
            (mm_id, name, icon, r['color'] or '#A78BFA', kind,
             r['ordering'] or 0))
    dst.execute(
        "INSERT INTO categories (id, name, icon_key, color_hex, kind,"
        " parent_id, sort_order) VALUES (?,?,?,?,?,NULL,0)",
        (DEBT_CAT_ID, 'Debt', 'handshake', '#F472B6', 'debt'))
    dst.execute(
        "INSERT INTO categories (id, name, icon_key, color_hex, kind,"
        " parent_id, sort_order) VALUES (?,?,?,?,?,NULL,0)",
        (TRANSFER_CAT_ID, 'Transfer', 'swap_horiz', '#9CA3AF', 'transfer'))

    # ---- transactions --------------------------------------------------
    kind_of = {0: 'income', 1: 'expense', 2: 'transfer'}
    n_tx = 0
    for r in src.execute('SELECT * FROM trans ORDER BY id'):
        cat = r['category_id']
        if cat in HIDDEN_DEBT_CATS:
            cat = DEBT_CAT_ID
        elif cat == 0:
            cat = TRANSFER_CAT_ID
        elif cat not in CATEGORY_MAP:
            raise SystemExit(f'transaction {r["id"]} uses unmapped '
                             f'category {cat}')
        to_wallet = r['transfer_wallet_id']
        dst.execute(
            'INSERT INTO transactions (id, wallet_id, category_id, kind,'
            ' amount, note, date, created_at, to_wallet_id, debt_id,'
            ' debt_payment_id, recurring_id)'
            ' VALUES (?,?,?,?,?,?,?,?,?,?,?,NULL)',
            (r['id'], r['wallet_id'], cat, kind_of[r['type']],
             abs(r['amount']) // 100, r['note'] or '',
             us(r['date_time']), us(r['date_time']),
             to_wallet if to_wallet and to_wallet > 0 else None,
             r['debt_id'] if r['debt_id'] > 0 else None,
             r['debt_trans_id'] if r['debt_trans_id'] > 0 else None))
        n_tx += 1

    # ---- debts + debt payments -----------------------------------------
    for r in src.execute('SELECT * FROM debt ORDER BY id'):
        paid = src.execute(
            'SELECT COALESCE(SUM(amount),0) FROM debtTrans WHERE debt_id=?',
            (r['id'],)).fetchone()[0]
        person = r['lender'] or r['name'] or 'Unknown'
        dst.execute(
            'INSERT INTO debts (id, person, note, amount, direction,'
            ' is_paid, due_date, color_hex, wallet_id, created_at,'
            ' record_as_transaction)'
            ' VALUES (?,?,?,?,?,?,?,?,?,?,1)',
            (r['id'], person, r['name'] or '', r['amount'] // 100,
             'receivable' if r['type'] == 1 else 'payable',
             1 if paid >= r['amount'] else 0,
             us(r['due_date']), '#A78BFA', None, us(r['lend_date'])))
    # wallet for payments: from the linked transaction, if any
    for r in src.execute('SELECT * FROM debtTrans ORDER BY id'):
        w = src.execute(
            'SELECT wallet_id FROM trans WHERE debt_trans_id=? LIMIT 1',
            (r['id'],)).fetchone()
        dst.execute(
            'INSERT INTO debt_payments (id, debt_id, amount, date, note,'
            ' wallet_id) VALUES (?,?,?,?,?,?)',
            (r['id'], r['debt_id'], r['amount'] // 100, us(r['date_time']),
             r['note'] or '', w['wallet_id'] if w else None))

    # ---- recompute wallet balances from imported history ----------------
    # (MM's stored balances are stale; the transaction history wins)
    for wid, init in dst.execute(
            'SELECT id, initial_amount FROM wallets'):
        net = dst.execute(
            'SELECT COALESCE(SUM(CASE kind WHEN \'income\' THEN amount'
            ' WHEN \'expense\' THEN -amount ELSE 0 END),0)'
            ' FROM transactions WHERE wallet_id=?', (wid,)).fetchone()[0]
        tin = dst.execute(
            'SELECT COALESCE(SUM(amount),0) FROM transactions'
            ' WHERE kind=\'transfer\' AND to_wallet_id=?', (wid,)).fetchone()[0]
        tout = dst.execute(
            'SELECT COALESCE(SUM(amount),0) FROM transactions'
            ' WHERE kind=\'transfer\' AND wallet_id=?', (wid,)).fetchone()[0]
        dst.execute('UPDATE wallets SET balance=? WHERE id=?',
                    (init + net + tin - tout, wid))

    # ---- sqlite_sequence -------------------------------------------------
    for t in ('accounts', 'wallets', 'categories', 'transactions',
              'debts', 'debt_payments'):
        mx = dst.execute(f'SELECT MAX(id) FROM {t}').fetchone()[0] or 0
        dst.execute('UPDATE sqlite_sequence SET seq=? WHERE name=?',
                    (mx, t))
    dst.commit()

    # ---- sanity checks ---------------------------------------------------
    checks = []
    for t in ('accounts', 'wallets', 'categories', 'transactions',
              'debts', 'debt_payments'):
        c = dst.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0]
        checks.append(f'{t}={c}')
    orphans = dst.execute(
        'SELECT COUNT(*) FROM transactions t LEFT JOIN wallets w'
        ' ON w.id=t.wallet_id LEFT JOIN categories c ON c.id=t.category_id'
        ' WHERE w.id IS NULL OR c.id IS NULL').fetchone()[0]
    assert orphans == 0, 'orphan transactions!'
    # wallet balance reconciliation vs imported transactions
    for wid, name, bal, init in dst.execute(
            'SELECT id, name, balance, initial_amount FROM wallets'):
        net = dst.execute(
            'SELECT COALESCE(SUM(CASE kind WHEN \'income\' THEN amount'
            ' WHEN \'expense\' THEN -amount ELSE 0 END),0)'
            ' FROM transactions WHERE wallet_id=?', (wid,)).fetchone()[0]
        tin = dst.execute(
            'SELECT COALESCE(SUM(amount),0) FROM transactions'
            ' WHERE kind=\'transfer\' AND to_wallet_id=?', (wid,)).fetchone()[0]
        tout = dst.execute(
            'SELECT COALESCE(SUM(amount),0) FROM transactions'
            ' WHERE kind=\'transfer\' AND wallet_id=?', (wid,)).fetchone()[0]
        calc = init + net + tin - tout
        flag = '' if calc == bal else f'  <-- MISMATCH calc={calc}'
        checks.append(f'wallet {name}: stored={bal} recomputed={calc}{flag}')
    dst.close()
    src.close()
    print('migrated:', ', '.join(checks[:6]))
    for line in checks[6:]:
        print(' ', line)

    # ---- pack the backup ZIP ---------------------------------------------
    manifest = {
        'app': 'dmoney_manager',
        'format': 1,
        'schemaVersion': 8,
        'createdAt': datetime.now(timezone.utc).isoformat(),
        'migratedFrom': 'Money Manager (RealByte) backup_20261003_073207.db',
    }
    prefs = {'currencyCode': 'IDR', 'userName': 'Miko'}
    with zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED) as z:
        z.write(WORK, 'database.sqlite')
        z.writestr('manifest.json', json.dumps(manifest, indent=2))
        z.writestr('prefs.json', json.dumps(prefs, indent=2))
    print('wrote', OUT)


if __name__ == '__main__':
    main()
