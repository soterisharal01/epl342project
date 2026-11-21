#!/usr/bin/env python3
"""perf_10000.py : PRF-4. 10,000 OLTP requests against the database; shows that 95% finish under 2 seconds.

Each request is one stored-procedure call, the same call a PHP page makes (call_proc), with a user picked at random
from the loaded data. The mix follows what the roles do most: consumers open readings, invoices and premises,
users log in, technicians list tasks, suppliers read Day-Ahead totals, DSO lists packets.

    pip install pymssql
    set the connection in environment variables (the password is never printed or stored):
      MDMS_SERVER   e.g. localhost  or  mssql.cs.ucy.ac.cy\\SQL2025
      MDMS_DB       database name
      MDMS_USER     SQL login
      MDMS_PASSWORD SQL password (typed by the member, e.g.  read -s MDMS_PASSWORD; export MDMS_PASSWORD)
    python sql/perf/perf_10000.py [requests=10000] [workers=4]

Read-only: it calls only procedures that read, so the data do not change. Prints a table per procedure
(count, mean, p50, p95, p99, max in ms) and the overall share of requests under 2 s.
"""
import os, random, statistics, sys, threading, time
from datetime import timedelta
import pymssql

N = int(sys.argv[1]) if len(sys.argv) > 1 else 10000
WORKERS = int(sys.argv[2]) if len(sys.argv) > 2 else 4
LIMIT_MS = 2000.0


def connect():
    return pymssql.connect(server=os.environ['MDMS_SERVER'], user=os.environ['MDMS_USER'],
                           password=os.environ['MDMS_PASSWORD'], database=os.environ['MDMS_DB'], autocommit=True)


def ids(cur, sql):
    cur.execute(sql)
    return [r for r in cur.fetchall()]


# ---- parameters from the data ----
c = connect(); cur = c.cursor()
consumers = ids(cur, """SELECT DISTINCT h.UserID, mi.MeterID FROM HOLDING h JOIN METER_INSTALLATION mi ON mi.PremiseID = h.PremiseID
                        AND mi.RemovedAt IS NULL JOIN USER_ACCOUNT u ON u.UserID = h.UserID
                        WHERE h.EndDate IS NULL AND u.AccountStatus = 'Active'""")
usernames = [r[0] for r in ids(cur, "SELECT Username FROM USER_ACCOUNT WHERE AccountStatus = 'Active'")]
techs = [r[0] for r in ids(cur, "SELECT UserID FROM USER_ACCOUNT WHERE Role = 'Technician' AND ApprovalStatus = 'Approved' AND AccountStatus = 'Active'")]
suppliers = [r[0] for r in ids(cur, "SELECT UserID FROM USER_ACCOUNT WHERE Role = 'Supplier' AND AccountStatus = 'Active'")]
dso = ids(cur, "SELECT MIN(UserID) FROM USER_ACCOUNT WHERE Role = 'DSO' AND AccountStatus = 'Active'")[0][0]
cur.execute("SELECT CAST(MAX(IntervalStart) AS DATE) FROM VALIDATED_READING"); last_day = cur.fetchone()[0]
c.close()
day_from = last_day.isoformat() + ' 00:00:00'
day_to = (last_day + timedelta(days=1)).isoformat() + ' 00:00:00'
week_from = (last_day - timedelta(days=6)).isoformat()

# (weight, name, function that returns the parameter tuple)
MIX = [
    (25, 'sp_consumer_readings',      lambda: (*random.choice(consumers), day_from, day_to)),
    (15, 'sp_consumer_list_invoices', lambda: (random.choice(consumers)[0], None)),
    (15, 'sp_consumer_list_premises', lambda: (random.choice(consumers)[0],)),
    (15, 'sp_auth_get_login',         lambda: (random.choice(usernames),)),
    (10, 'sp_tech_list_tasks',        lambda: (random.choice(techs), None)),
    (10, 'sp_supplier_totals',        lambda: (random.choice(suppliers), 'Day', week_from, last_day.isoformat())),
    (10, 'sp_dso_list_packets',       lambda: (dso, 50, None)),
]
plan = random.Random(342).choices([m for m in MIX], weights=[m[0] for m in MIX], k=N)
results = []          # (name, ms, ok)
lock = threading.Lock()


def worker(part):
    conn = connect(); cu = conn.cursor()
    local = []
    for _, name, args in part:
        params = args()
        t0 = time.perf_counter()
        ok = True
        try:
            cu.callproc(name, params)
            while True:                       # read every result set, as the page does
                cu.fetchall()
                if not cu.nextset():
                    break
        except pymssql.Error:
            ok = False
        local.append((name, (time.perf_counter() - t0) * 1000.0, ok))
    conn.close()
    with lock:
        results.extend(local)


t_start = time.perf_counter()
threads = [threading.Thread(target=worker, args=(plan[i::WORKERS],)) for i in range(WORKERS)]
for t in threads: t.start()
for t in threads: t.join()
wall = time.perf_counter() - t_start


def pct(v, p):
    v = sorted(v); k = max(0, min(len(v) - 1, int(round(p / 100.0 * len(v) + 0.5)) - 1))
    return v[k]


print(f'{len(results)} requests, {WORKERS} parallel connections, {wall:.1f} s wall time, {len(results) / wall:.0f} requests/s')
print(f'{"procedure":28} {"count":>6} {"errors":>6} {"mean":>7} {"p50":>7} {"p95":>7} {"p99":>7} {"max":>8}  (ms)')
for name in [m[1] for m in MIX] + ['ALL']:
    rows = [r for r in results if name == 'ALL' or r[0] == name]
    ms = [r[1] for r in rows]
    print(f'{name:28} {len(rows):6d} {sum(not r[2] for r in rows):6d} {statistics.mean(ms):7.1f} {pct(ms, 50):7.1f} '
          f'{pct(ms, 95):7.1f} {pct(ms, 99):7.1f} {max(ms):8.1f}')
under = sum(1 for r in results if r[1] < LIMIT_MS) / len(results) * 100
print(f'under 2 s: {under:.2f}% of requests (target: at least 95%) -> {"PASS" if under >= 95 else "FAIL"}')
