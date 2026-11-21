#!/usr/bin/env python3
"""Builds the LARGE synthetic data set (DAT-1..4): data/large/<NN>_<TABLE>.dat + sql/import.sql.

Run from the repo root:  python data/gen/large.py        (fixed seed: output is always identical)

Loads AFTER data/small/00_base.sql. Every IDENTITY table uses IDs from 100000 upward, usernames start with
'lc_' (consumers) / 'lt_' (technicians), serials 'LSN-', NetworkIDs 'LEAC-', IBANs 'CY99...', so nothing
collides with the base data or the test_* data. Empty field in a .dat = NULL. Times are UTC.
"""
import csv
import json
import os
import random
import re
from datetime import datetime, timedelta, date

R = random.Random(342100)
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUTDIR = os.path.join(ROOT, 'data', 'large')
IMPORT = os.path.join(ROOT, 'sql', 'import.sql')
BASE = 100000
PW = '$2y$10$9.385gryv47XiLky6c9V8O8Q4hKNuLvd3U/2gssSr7furIeuVaorS'   # same demo hash as base.py (Mdms2026!)

N_CONSUMERS = 2000
N_EXTRA_PREMISES = 200
N_TECH = 30
N_CONTRACTS = 1500
N_READING_METERS = 200        # 5 per leaf
READ_START = datetime(2026, 11, 1)
READ_DAYS = 10
SLOTS = 96


class Num(str):
    """A number already formatted as text (exact decimals, no float drift)."""


def num3(milli):
    return Num(f'{milli // 1000}.{milli % 1000:03d}')


def sqlq(v):
    if v is None:
        return 'NULL'
    if isinstance(v, Num):
        return str(v)
    if isinstance(v, bool):
        return '1' if v else '0'
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return repr(round(v, 4))
    if isinstance(v, datetime):
        return "'" + v.strftime('%Y-%m-%d %H:%M:%S') + "'"
    if isinstance(v, date):
        return "'" + v.isoformat() + "'"
    s = str(v).replace("'", "''")
    return ("'" + s + "'") if s.isascii() else ("N'" + s + "'")


def datv(v):
    if v is None:
        return ''
    if isinstance(v, datetime):
        return v.strftime('%Y-%m-%d %H:%M:%S')
    if isinstance(v, date):
        return v.isoformat()
    if isinstance(v, float):
        return repr(round(v, 4))
    return str(v)


os.makedirs(OUTDIR, exist_ok=True)
for f in os.listdir(OUTDIR):
    if f.endswith('.dat'):
        os.remove(os.path.join(OUTDIR, f))
os.makedirs(os.path.dirname(IMPORT), exist_ok=True)
imp = open(IMPORT, 'w', encoding='utf-8', newline='\n')
TABLES = {}          # table -> (cols, rows) kept for self-checks
COUNTS = []
_since_go = [0]
_fileno = [0]


def go():
    imp.write('GO\n')
    _since_go[0] = 0


def emit(table, cols, rows, identity=False):
    _fileno[0] += 1
    TABLES[table] = (cols, rows)
    COUNTS.append((table, len(rows)))
    with open(os.path.join(OUTDIR, f'{_fileno[0]:02d}_{table}.dat'), 'w', encoding='utf-8', newline='') as f:
        wr = csv.writer(f, lineterminator='\n')
        wr.writerow(cols)
        for r in rows:
            wr.writerow([datv(v) for v in r])
    imp.write(f'-- {table}: {len(rows)} rows\n')
    if identity:
        imp.write(f'SET IDENTITY_INSERT {table} ON;\n')
    for i in range(0, len(rows), 1000):
        chunk = rows[i:i + 1000]
        imp.write(f'INSERT {table} ({", ".join(cols)}) VALUES\n')
        imp.write(',\n'.join('(' + ','.join(sqlq(v) for v in r) + ')' for r in chunk) + ';\n')
        _since_go[0] += len(chunk)
        if _since_go[0] >= 4000:
            go()
    if identity:
        imp.write(f'SET IDENTITY_INSERT {table} OFF;\n')
    go()


FIRST = ['Μαρία', 'Γιώργος', 'Ελένη', 'Νίκος', 'Άννα', 'Κώστας', 'Σοφία', 'Δημήτρης', 'Ανδρέας', 'Χριστίνα', 'Πέτρος',
         'Ιωάννα', 'Μιχάλης', 'Στέλλα', 'Αντρέας', 'Δέσποινα', 'Παναγιώτης', 'Κατερίνα', 'Σάββας', 'Μαριλένα']
LAST = ['Γεωργίου', 'Ιωάννου', 'Παπαδόπουλος', 'Χαραλάμπους', 'Δημητρίου', 'Νικολάου', 'Κωνσταντίνου', 'Αντωνίου',
        'Χριστοδούλου', 'Σάββα', 'Ανδρέου', 'Παύλου', 'Μιχαήλ', 'Κυριάκου', 'Θεοδώρου', 'Λοΐζου']
STREETS = ['Λεωφ. Μακαρίου', 'Οδός Ερμού', 'Οδός Αρχιεπισκόπου', 'Οδός Ηρώων', 'Λεωφ. Στροβόλου', 'Οδός Κύκνων',
           'Οδός Ελευθερίας', 'Οδός Ομήρου', 'Οδός Ιπποκράτους', 'Οδός Αθηνών', 'Οδός Ρήγα Φεραίου', 'Οδός Σταδίου']

# ---------------------------------------------------------------- grid: new subtrees under base 2 and 3
# base: geofence 2 = (35.05,33.20)-(35.25,33.50), 3 = (34.62,32.95)-(34.76,33.15); base leaves 4,5 / 6 stay untouched.
GEO, TRF, LEAVES = [], [], []     # LEAVES: (transformer id, bbox)
mids = [  # name, parent, bbox, rows, cols
    ('A', 2, (35.06, 33.22, 35.12, 33.48), 2, 5, 'NIC'),
    ('B', 2, (35.19, 33.22, 35.24, 33.48), 2, 5, 'NIC'),
    ('C', 3, (34.63, 32.96, 34.66, 33.14), 2, 5, 'LIM'),
    ('D', 3, (34.71, 32.96, 34.75, 33.14), 2, 5, 'LIM'),
]
gid = BASE
mid_ids = {}
for name, parent, bb, nr, nc, city in mids:
    mid_ids[name] = gid
    GEO.append((gid, f'Υποσταθμός {city}-{name} MV', *bb))
    TRF.append((gid, f'T-{city}-{name}', round((bb[0] + bb[2]) / 2, 6), round((bb[1] + bb[3]) / 2, 6), gid, parent))
    gid += 1
for name, parent, bb, nr, nc, city in mids:
    h = (bb[2] - bb[0]) / nr
    wd = (bb[3] - bb[1]) / nc
    for r in range(nr):
        for c in range(nc):
            b = (round(bb[0] + h * r + h * 0.1, 6), round(bb[1] + wd * c + wd * 0.1, 6),
                 round(bb[0] + h * (r + 1) - h * 0.1, 6), round(bb[1] + wd * (c + 1) - wd * 0.1, 6))
            GEO.append((gid, f'{city}-{name}{r * nc + c + 1:02d} LV', *b))
            TRF.append((gid, f'T-{city}-{name}{r * nc + c + 1:02d}', round((b[0] + b[2]) / 2, 6), round((b[1] + b[3]) / 2, 6), gid, mid_ids[name]))
            LEAVES.append((gid, b, 1 if city == 'NIC' else 3))
            gid += 1
NL = len(LEAVES)

# ---------------------------------------------------------------- users
users = []
UC = ['UserID', 'Username', 'PasswordHash', 'Role', 'Email', 'Phone', 'FirstName', 'LastName', 'AccountStatus',
      'CreatedBy', 'RawRetentionMonths', 'BirthDate', 'Photo', 'ApprovalStatus', 'ApprovalDecidedAt', 'ApprovedBy',
      'SupplierID', 'AggregatorID']
for i in range(N_CONSUMERS):
    users.append((BASE + i, f'lc_{i + 1:05d}', PW, 'Consumer', f'lc{i + 1:05d}@example.cy', f'99{R.randint(100000, 999999)}',
                  R.choice(FIRST), R.choice(LAST), 'Active', None, 36, None, None, None, None, None, None, None))
TECH0 = BASE + N_CONSUMERS
for i in range(N_TECH):
    d = datetime(2026, 10, 1 + i % 20, 10, 0, 0)
    users.append((TECH0 + i, f'lt_{i + 1:03d}', PW, 'Technician', f'lt{i + 1:03d}@example.cy', f'96{R.randint(100000, 999999)}',
                  R.choice(FIRST), R.choice(LAST), 'Active', None, None,
                  date(R.randint(1975, 2000), R.randint(1, 12), R.randint(1, 28)), f'photos/lt_{i + 1:03d}.jpg',
                  'Approved', d, 2, None, None))
emit('USER_ACCOUNT', UC, users, True)
emit('CONSUMER_NOTIFICATION_CHANNEL', ['UserID', 'NotificationChannel'],
     [(BASE + i, 'Email') for i in range(N_CONSUMERS)] + [(BASE + i, 'SMS') for i in range(N_CONSUMERS) if i % 10 < 3])
emit('IN_CATEGORY', ['UserID', 'CategoryID'],
     [(TECH0 + i, 1) for i in range(N_TECH)] + [(TECH0 + i, 2) for i in range(N_TECH) if i % 2 == 0])

emit('GEOFENCE', ['GeofenceID', 'Name', 'MinLat', 'MinLon', 'MaxLat', 'MaxLon'], GEO, True)
emit('TRANSFORMER', ['TransformerID', 'Name', 'Latitude', 'Longitude', 'GeofenceID', 'ParentTransformerID'], TRF, True)

# ---------------------------------------------------------------- premises (leaf of premise i = i % NL)
NP = N_CONSUMERS + N_EXTRA_PREMISES
prem, pleaf = [], []
reading_idx = [i for i in range(N_READING_METERS)]          # meters 0..199 (5 per leaf) get readings
prosumer = {i for i in reading_idx if i % 5 == 0}           # 40 prosumers (20%)
for i in range(NP):
    leaf = LEAVES[i % NL]
    b = leaf[1]
    lat = round(R.uniform(b[0] + 0.0005, b[2] - 0.0005), 6)
    lon = round(R.uniform(b[1] + 0.0005, b[3] - 0.0005), 6)
    if i in prosumer:
        scheme = 2 if i % 10 == 0 else 3
    else:
        scheme = 2 if R.random() < 0.04 else 1
    usage = R.choices(['Residential', 'Commercial', 'Industrial', 'Agricultural'], [80, 14, 3, 3])[0]
    prem.append((BASE + i, f'{R.choice(STREETS)} {R.randint(1, 200)}', f'{R.randint(1000, 3999):04d}',
                 lat, lon, usage, leaf[2], scheme))
    pleaf.append(leaf)
# parish: NIC leaves -> parish 1 or 2, LIM -> parish 3
prem = [p[:6] + ((R.choice([1, 2]) if p[6] == 1 else 3), p[7]) for p in prem]
emit('PREMISE', ['PremiseID', 'Address', 'PostalCode', 'Latitude', 'Longitude', 'UsageType', 'ParishID', 'SchemeID'], prem, True)

holder = {}                                   # premise index -> consumer index
hold = []
for i in range(N_CONSUMERS):
    holder[i] = i
for j in range(N_EXTRA_PREMISES):
    holder[N_CONSUMERS + j] = (j * 7 + 3) % N_CONSUMERS
hstart = {}
for i in range(NP):
    hstart[i] = date(2026, 1, 1) + timedelta(days=R.randint(0, 120))
    hold.append((BASE + holder[i], BASE + i, hstart[i], None))
emit('HOLDING', ['UserID', 'PremiseID', 'StartDate', 'EndDate'], hold)

banks = []
for i in range(N_CONTRACTS):
    u = users[i]
    banks.append((BASE + i, f'CY99{900000000000000000 + i:024d}', f'{u[6]} {u[7]}', BASE + i))
emit('BANK_ACCOUNT', ['BankAccountID', 'IBAN', 'HolderName', 'UserID'], banks, True)
emit('ACCOUNT_FOR', ['BankAccountID', 'PremiseID'], [(BASE + i, BASE + i) for i in range(N_CONTRACTS)])
contracts = [(BASE + i, hstart[i], None, BASE + i, BASE + i, 1 if i % 3 else 2, 2 if prem[i][5] != 'Residential' else 1)
             for i in range(N_CONTRACTS)]
emit('SUPPLY_CONTRACT', ['ContractID', 'StartDate', 'EndDate', 'UserID', 'PremiseID', 'SupplierID', 'TariffTypeID'], contracts, True)

invoices, payments = [], []
iid = pid_ = BASE
months = [(2026, m) for m in range(5, 11)]        # May..Oct 2026
for ci in range(N_CONTRACTS):
    for k, (y, m) in enumerate(months):
        pf = date(y, m, 1)
        pt = (date(y + (m == 12), m % 12 + 1, 1) - timedelta(days=1))
        issue = pt + timedelta(days=5)
        amount = round(R.uniform(25, 190) * (2.5 if prem[ci][5] != 'Residential' else 1), 2)
        if k < 4 or (k == 4 and R.random() > 0.2):
            status = 'Paid'
        elif k == 4:
            status = 'Partially paid'
        else:
            status = 'Issued'
        invoices.append((iid, issue, pf, pt, amount, status, BASE + ci, BASE + ci))
        if status in ('Paid', 'Partially paid'):
            paid = amount if status == 'Paid' else round(amount / 2, 2)
            payments.append((pid_, paid, datetime.combine(issue + timedelta(days=R.randint(1, 18)), datetime.min.time()) + timedelta(hours=R.randint(7, 20), minutes=R.randint(0, 59)),
                             f'LPAY-{pid_}', iid, BASE + ci))
            pid_ += 1
        iid += 1
emit('INVOICE', ['InvoiceID', 'IssueDate', 'PeriodFrom', 'PeriodTo', 'Amount', 'Status', 'UserID', 'ContractID'], invoices, True)
emit('PAYMENT', ['PaymentID', 'Amount', 'PaidAt', 'Reference', 'InvoiceID', 'BankAccountID'], payments, True)

emit('PORTFOLIO', ['PortfolioID', 'Name', 'AggregatorID'], [(BASE + k, f'Χαρτοφυλάκιο LRG-{k + 1}', 1) for k in range(5)], True)
inc = []
for n, i in enumerate(sorted(prosumer) + list(range(1, 2000, 7))):
    if any(x[1] == BASE + i for x in inc):
        continue
    inc.append((BASE + (n % 5), BASE + i, date(2026, 5, 1), None))
emit('INCLUDES', ['PortfolioID', 'PremiseID', 'StartDate', 'EndDate'], inc)

# ---------------------------------------------------------------- meters (one per premise 0..1999), installations
meters, phases, tasks, insts = [], [], [], []
three = lambda i: i % 4 == 3
for i in range(N_CONSUMERS):
    leaf = LEAVES[i % NL]
    model = 2 if three(i) else 1
    meters.append((BASE + i, f'LSN-{i + 1:06d}', f'LEAC-{i + 1:06d}', R.choice(['1.4.2', '2.0.1']), 80 if model == 2 else 60,
                   prem[i][3], prem[i][4], 'Active', model, R.choice([1, 2, 3]), leaf[0]))
    phases += [(BASE + i, p) for p in (['L1', 'L2', 'L3'] if model == 2 else [R.choice(['L1', 'L2', 'L3'])])]
    day = datetime(2026, 9, 1) + timedelta(days=i % 50, hours=9 + (i // 50) % 8)
    tasks.append((BASE + i, 'Installation', day, day + timedelta(hours=2), 'Done', f'Εγκαταστάθηκε ο μετρητής LSN-{i + 1:06d}',
                  day - timedelta(days=2), day + timedelta(hours=1), TECH0 + i % N_TECH, BASE + i, None, None))
    insts.append((BASE + i, day + timedelta(hours=1), None, 'Confirmed', day + timedelta(days=1), 'Έλεγχος OK',
                  BASE + i, BASE + i, 2, BASE + i))
emit('METER', ['MeterID', 'SerialNumber', 'NetworkID', 'Firmware', 'MaxLoadAmps', 'Latitude', 'Longitude', 'Status', 'ModelID', 'CommTypeID', 'TransformerID'], meters, True)
emit('METER_CONNECTED_PHASE', ['MeterID', 'ConnectedPhase'], phases)
sreq = []
for k in range(150):
    i = R.randrange(N_CONSUMERS)
    st = R.choice(['Submitted', 'Assigned', 'Resolved', 'Cancelled'])
    sreq.append((BASE + k, R.choice(['Meter check', 'Fault report']), R.choice(['Ο μετρητής δείχνει λάθος κατανάλωση.', 'Διακοπές επικοινωνίας του μετρητή.', 'Ζητώ έλεγχο του μετρητή.']),
                 st, datetime(2026, 11, 1, 6) + timedelta(minutes=R.randint(0, 20 * 24 * 60)), BASE + i, BASE + i, BASE + i if k % 2 else None))
emit('SERVICE_REQUEST', ['RequestID', 'RequestType', 'Description', 'Status', 'SubmittedAt', 'UserID', 'PremiseID', 'MeterID'], sreq, True)
emit('FIELD_TASK', ['TaskID', 'TaskType', 'ScheduledFrom', 'ScheduledTo', 'Status', 'Result', 'CreatedAt', 'CompletedAt', 'TechnicianID', 'PremiseID', 'MeterID', 'RequestID'], tasks, True)
emit('METER_INSTALLATION', ['InstallationID', 'InstalledAt', 'RemovedAt', 'ConfirmationStatus', 'ConfirmedAt', 'ConfirmComment', 'MeterID', 'PremiseID', 'ConfirmedBy', 'TaskID'], insts, True)
docs, did = [], BASE
for t in range(N_TECH):
    for dt in ('ID card', 'Installer licence', 'Training certificate'):
        docs.append((did, dt, f'LDOC-{did}', date(2024, 1, 10), date(2030, 1, 10), f'docs/lt_{t + 1:03d}_{did}.pdf', 'Accepted', 'OK',
                     datetime(2026, 10, 5, 12), TECH0 + t, None, 2))
        did += 1
emit('DOCUMENT', ['DocumentID', 'DocType', 'DocNumber', 'IssueDate', 'ExpiryDate', 'FilePath', 'ReviewStatus', 'ReviewComment', 'ReviewedAt', 'TechnicianID', 'MeterID', 'ReviewedBy'], docs, True)

# ---------------------------------------------------------------- readings
RUN = BASE
emit('VEE_RUN', ['RunID', 'PeriodFrom', 'PeriodTo', 'StartedAt', 'FinishedAt'],
     [(RUN, READ_START, READ_START + timedelta(days=READ_DAYS), datetime(2026, 11, 11, 1, 0), datetime(2026, 11, 11, 1, 30))], True)

packets, raw, val = [], [], []
magg = {}
PKT_SLOTS = 24                     # one telemetry packet = 6 hours of one meter (all its codes)
seq = BASE
VALIDATED_AT = datetime(2026, 11, 11, 1, 30)
for i in reading_idx:
    mid = BASE + i
    net = meters[i][2]
    codes = ['1.8.0'] + (['2.8.0'] if i in prosumer else [])
    counter = {'1.8.0': R.randint(2000, 20000) * 1000, '2.8.0': R.randint(500, 9000) * 1000}
    comm = 'NB-IoT'
    base_load = R.choice([150, 250, 350, 600]) if prem[i][5] == 'Residential' else R.choice([700, 1100])   # Wh per slot (x1000 below)
    for s0 in range(0, READ_DAYS * SLOTS, PKT_SLOTS):
        t_first = READ_START + timedelta(minutes=15 * s0)
        entries = {c: [] for c in codes}
        pk_rows = []
        for s in range(s0, s0 + PKT_SLOTS):
            ts = READ_START + timedelta(minutes=15 * s)
            h = ts.hour + ts.minute / 60
            for c in codes:
                if c == '1.8.0':
                    mult = 1.8 if 15 <= h < 20 else (0.6 if h < 5 else 1.0)
                    e = int(base_load * mult * R.uniform(0.8, 1.2))      # milli-kWh
                else:
                    e = int(max(0.0, 900 * (1 - abs(h - 10) / 5)) * R.uniform(0.85, 1.0)) if 5 <= h <= 15 else 0
                counter[c] += e
                entries[c].append(counter[c])
                pk_rows.append((c, ts, counter[c], e))
                k = (mid, c, ts.date())
                a = magg.setdefault(k, [0, 0])
                a[0] += e
                a[1] += 1
        t_last = READ_START + timedelta(minutes=15 * (s0 + PKT_SLOTS - 1))
        payload = json.dumps({'Meter_Network_ID': net, 'Transmission_Timestamp': (t_last + timedelta(minutes=15)).strftime('%Y-%m-%dT%H:%M:%SZ'),
                              'Network_Type': comm, 'Telemetry_Payload': [
                                  {'obis': c, 'start': t_first.strftime('%Y-%m-%dT%H:%M:%SZ'), 'interval_s': 900,
                                   'unit': 'kWh', 'values': [str(num3(v)) for v in entries[c]]} for c in codes]},
                             ensure_ascii=False, separators=(',', ':'))
        packets.append((seq, net, t_last + timedelta(minutes=15), t_last + timedelta(minutes=15, seconds=20), comm, -R.randint(70, 100),
                        payload, 'Accepted', None, mid))
        for c, ts, cv, e in pk_rows:
            raw.append((mid, c, ts, num3(cv), 'Validated', seq))
            val.append((mid, c, ts, num3(e), 'Validated', RUN))
        seq += 1
emit('TELEMETRY_PACKET', ['PacketID', 'ReceivedNetworkID', 'TransmissionTimestamp', 'ReceivedAt', 'NetworkType', 'SignalDbm', 'RawPayload', 'IngestStatus', 'ErrorMessage', 'MeterID'], packets, True)
emit('RAW_READING', ['MeterID', 'ObisCode', 'IntervalStart', 'ReceivedValue', 'VeeStatus', 'PacketID'], raw)
emit('VALIDATED_READING', ['MeterID', 'ObisCode', 'IntervalStart', 'Value', 'Quality', 'RunID'], val)   # ValidatedAt = column default (load time): saves ~10 MB
maggr = [(m, c, 'Day', d, num3(s), n, 0) for (m, c, d), (s, n) in sorted(magg.items())]
emit('METER_AGGREGATE', ['MeterID', 'ObisCode', 'PeriodType', 'PeriodStart', 'SumValue', 'ReadingCount', 'EstimatedCount'], maggr)
tagg = {}
leaf_of = {BASE + i: meters[i][10] for i in range(N_CONSUMERS)}
for (m, c, d), (s, n) in magg.items():
    a = tagg.setdefault((leaf_of[m], c, d), [0, set()])
    a[0] += s
    a[1].add(m)
emit('TRANSFORMER_AGGREGATE', ['TransformerID', 'ObisCode', 'PeriodType', 'PeriodStart', 'SumValue', 'MeterCount', 'ComputedAt'],
     [(t, c, 'Day', d, num3(s), len(ms), datetime(2026, 11, 11, 1, 35)) for (t, c, d), (s, ms) in sorted(tagg.items())], False)

# ---------------------------------------------------------------- self-checks
def pk(table, idx):
    cols, rows = TABLES[table]
    ix = [cols.index(c) for c in idx]
    keys = [tuple(r[j] for j in ix) for r in rows]
    assert len(keys) == len(set(keys)), f'duplicate key in {table} {idx}'
    return set(keys)


def col(table, c):
    cols, rows = TABLES[table]
    j = cols.index(c)
    return [r[j] for r in rows]


def fk(table, c, target, tc, nullable=False):
    ok = {k[0] for k in pk(target, [tc])} if target in TABLES else None
    assert ok is not None
    bad = [v for v in col(table, c) if v is not None and v not in ok]
    assert not bad, f'FK {table}.{c} -> {target}: {bad[:3]}'


BASE_IDS = {'USER': {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}}
for t, i in [('USER_ACCOUNT', ['UserID']), ('USER_ACCOUNT', ['Username']), ('GEOFENCE', ['GeofenceID']), ('TRANSFORMER', ['TransformerID']),
             ('TRANSFORMER', ['GeofenceID']), ('PREMISE', ['PremiseID']), ('HOLDING', ['UserID', 'PremiseID', 'StartDate']),
             ('BANK_ACCOUNT', ['IBAN']), ('SUPPLY_CONTRACT', ['ContractID']), ('INVOICE', ['InvoiceID']), ('PAYMENT', ['PaymentID']),
             ('METER', ['MeterID']), ('METER', ['SerialNumber']), ('METER', ['NetworkID']), ('FIELD_TASK', ['TaskID']),
             ('METER_INSTALLATION', ['TaskID']), ('TELEMETRY_PACKET', ['PacketID']), ('RAW_READING', ['MeterID', 'ObisCode', 'IntervalStart']),
             ('VALIDATED_READING', ['MeterID', 'ObisCode', 'IntervalStart']), ('METER_AGGREGATE', ['MeterID', 'ObisCode', 'PeriodType', 'PeriodStart']),
             ('TRANSFORMER_AGGREGATE', ['TransformerID', 'ObisCode', 'PeriodType', 'PeriodStart']), ('INCLUDES', ['PortfolioID', 'PremiseID']),
             ('SERVICE_REQUEST', ['RequestID']), ('DOCUMENT', ['DocumentID']), ('METER_CONNECTED_PHASE', ['MeterID', 'ConnectedPhase'])]:
    pk(t, i)
# one open holding per (user, premise); one open contract per premise; one open install per meter
assert len(set(col('SUPPLY_CONTRACT', 'PremiseID'))) == N_CONTRACTS
assert len(set(col('METER_INSTALLATION', 'MeterID'))) == N_CONSUMERS
# FKs inside the set
fk('HOLDING', 'UserID', 'USER_ACCOUNT', 'UserID'); fk('HOLDING', 'PremiseID', 'PREMISE', 'PremiseID')
fk('BANK_ACCOUNT', 'UserID', 'USER_ACCOUNT', 'UserID'); fk('ACCOUNT_FOR', 'BankAccountID', 'BANK_ACCOUNT', 'BankAccountID'); fk('ACCOUNT_FOR', 'PremiseID', 'PREMISE', 'PremiseID')
fk('SUPPLY_CONTRACT', 'UserID', 'USER_ACCOUNT', 'UserID'); fk('SUPPLY_CONTRACT', 'PremiseID', 'PREMISE', 'PremiseID')
fk('INVOICE', 'ContractID', 'SUPPLY_CONTRACT', 'ContractID'); fk('PAYMENT', 'InvoiceID', 'INVOICE', 'InvoiceID'); fk('PAYMENT', 'BankAccountID', 'BANK_ACCOUNT', 'BankAccountID')
fk('INCLUDES', 'PortfolioID', 'PORTFOLIO', 'PortfolioID'); fk('INCLUDES', 'PremiseID', 'PREMISE', 'PremiseID')
fk('METER', 'TransformerID', 'TRANSFORMER', 'TransformerID')
fk('METER_CONNECTED_PHASE', 'MeterID', 'METER', 'MeterID'); fk('FIELD_TASK', 'TechnicianID', 'USER_ACCOUNT', 'UserID'); fk('FIELD_TASK', 'PremiseID', 'PREMISE', 'PremiseID')
fk('METER_INSTALLATION', 'TaskID', 'FIELD_TASK', 'TaskID'); fk('METER_INSTALLATION', 'MeterID', 'METER', 'MeterID'); fk('METER_INSTALLATION', 'PremiseID', 'PREMISE', 'PremiseID')
fk('TELEMETRY_PACKET', 'MeterID', 'METER', 'MeterID'); fk('RAW_READING', 'PacketID', 'TELEMETRY_PACKET', 'PacketID'); fk('RAW_READING', 'MeterID', 'METER', 'MeterID')
fk('VALIDATED_READING', 'RunID', 'VEE_RUN', 'RunID'); fk('METER_AGGREGATE', 'MeterID', 'METER', 'MeterID')
fk('SERVICE_REQUEST', 'UserID', 'USER_ACCOUNT', 'UserID'); fk('SERVICE_REQUEST', 'PremiseID', 'PREMISE', 'PremiseID'); fk('SERVICE_REQUEST', 'MeterID', 'METER', 'MeterID')
fk('DOCUMENT', 'TechnicianID', 'USER_ACCOUNT', 'UserID'); fk('TRANSFORMER_AGGREGATE', 'TransformerID', 'TRANSFORMER', 'TransformerID')
# geography: child geofence inside parent, transformer inside own geofence, new transformers only under base 2 and 3
geo = {g[0]: g[2:] for g in GEO}
base_geo = {2: (35.05, 33.20, 35.25, 33.50), 3: (34.62, 32.95, 34.76, 33.15)}
tr = {t[0]: t for t in TRF}
for t in TRF:
    g = geo[t[4]]
    assert g[0] < g[2] and g[1] < g[3]
    assert g[0] <= t[2] <= g[2] and g[1] <= t[3] <= g[3], 'transformer point outside own geofence'
    pb = geo[tr[t[5]][4]] if t[5] in tr else base_geo[t[5]]
    assert pb[0] <= g[0] and pb[1] <= g[1] and g[2] <= pb[2] and g[3] <= pb[3], f'geofence {t[0]} not inside parent'
assert {t[5] for t in TRF} - set(tr) <= {2, 3}
parents = {t[5] for t in TRF}
leaf_ids = {l[0] for l in LEAVES}
assert not (leaf_ids & parents), 'a leaf has children'
assert all(m[10] in leaf_ids for m in meters), 'meter on non-leaf'
# leaf geofences are pairwise disjoint (and disjoint from base leaf geofences 4,5,6)
boxes = [geo[l[0]] for l in LEAVES] + [(35.13, 33.37, 35.16, 33.41), (35.16, 33.36, 35.18, 33.38), (34.67, 33.03, 34.69, 33.06)]
for a in range(len(boxes)):
    for b in range(a + 1, len(boxes)):
        A, B = boxes[a], boxes[b]
        assert A[2] <= B[0] or B[2] <= A[0] or A[3] <= B[1] or B[3] <= A[1], 'leaf geofences overlap'
for i in range(NP):
    g = geo[pleaf[i][0]]
    assert g[0] <= float(prem[i][3]) <= g[2] and g[1] <= float(prem[i][4]) <= g[3], 'premise outside leaf geofence'
for i, m in enumerate(meters):
    g = geo[m[10]]
    assert g[0] <= m[5] <= g[2] and g[1] <= m[6] <= g[3] and (m[5], m[6]) == (prem[i][3], prem[i][4])
    assert len([p for p in phases if p[0] == m[0]]) == (3 if m[8] == 2 else 1)
assert all(re.fullmatch(r'CY\d{26}', b[1]) and 15 <= len(b[1]) <= 34 for b in banks)
assert all(u[6] and u[7] for u in users)
# readings: counters non-decreasing and strictly increasing for 1.8.0; validated deltas match; 15-minute grid
last = {}
for (m, c, ts, v, st, p) in raw:
    assert ts.minute % 15 == 0 and ts.second == 0
    x = int(str(v).replace('.', ''))
    k = (m, c)
    if k in last:
        assert x > last[k] if c == '1.8.0' else x >= last[k], 'counter not increasing'
    last[k] = x
assert len(raw) == len(val)
prev = {}
for r, v in zip(raw, val):
    assert (r[0], r[1], r[2]) == (v[0], v[1], v[2])
    x = int(str(r[3]).replace('.', ''))
    if (r[0], r[1]) in prev:
        assert x - prev[(r[0], r[1])] == int(str(v[3]).replace('.', '')), 'validated != delta'
    prev[(r[0], r[1])] = x
tech_ok = [u for u in users if u[3] == 'Technician']
assert all(u[13] == 'Approved' and u[15] == 2 and u[14] and u[11] and u[12] for u in tech_ok)
assert 200000 <= len(raw) <= 400000, len(raw)
print('self-checks OK')

# ---------------------------------------------------------------- header + footer of import.sql
imp.close()
body = open(IMPORT, encoding='utf-8').read()
head = [
    '-- MDMS-Cy: LARGE synthetic data set (DAT-1..4). Generated by data/gen/large.py: DO NOT edit by hand.',
    '-- Run order: drop.sql -> create.sql -> procs_*.sql -> indexes.sql -> data/small/00_base.sql -> THIS FILE.',
    '-- Runs on a database that has only the base data. IDs of every IDENTITY table start at 100000.',
    '-- The same rows are in data/large/NN_TABLE.dat (CSV, UTF-8, header row, empty field = NULL, times UTC).',
    '-- Not wrapped in one transaction (too big): on an error, rebuild the database and run again.',
    'SET NOCOUNT ON;', 'SET XACT_ABORT ON;', 'GO', '']
foot = ['', "PRINT N'import.sql: OK';"]
foot += [f"PRINT N'  {t}: {n}';" for t, n in COUNTS]
with open(IMPORT, 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(head) + body + '\n'.join(foot) + '\n')
tot = 0
for t, n in COUNTS:
    tot += n
print(f'{"table":24s} rows')
for t, n in COUNTS:
    print(f'{t:24s} {n}')
print('total rows', tot)
