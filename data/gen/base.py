#!/usr/bin/env python3
"""Φτιάχνει το data/small/00_base.sql: τα κοινά δεδομένα βάσης της Φάσης Β.

Τρέξιμο (από τη ρίζα του repo):  python3 data/gen/base.py
Το αποτέλεσμα είναι πάντα το ίδιο (σταθερό seed), οπότε το .sql μπορεί να ξαναφτιαχτεί.

Γιατί υπάρχει: με αυτά τα δεδομένα ο καθένας δουλεύει την περιοχή του χωρίς να περιμένει
τους άλλους (PLANO-OMADAS.md, ενότητα 2Α). Όλα τα IDs εδώ είναι στο εύρος 1-999.
"""
import json
import os
import random
from datetime import datetime, timedelta

random.seed(342)
OUT = os.path.join(os.path.dirname(__file__), '..', 'small', '00_base.sql')

# Κωδικός δοκιμής για ΟΛΟΥΣ τους χρήστες demo: Mdms2026!  (password_hash του PHP, bcrypt)
PW = '$2y$10$9.385gryv47XiLky6c9V8O8Q4hKNuLvd3U/2gssSr7furIeuVaorS'

out = []
w = out.append


def q(v):
    """Τιμή SQL: None -> NULL, αριθμοί όπως είναι, κείμενο ως N'...'."""
    if v is None:
        return 'NULL'
    if isinstance(v, bool):
        return '1' if v else '0'
    if isinstance(v, (int, float)):
        return repr(round(v, 4)) if isinstance(v, float) else str(v)
    if isinstance(v, datetime):
        return "'" + v.strftime('%Y-%m-%d %H:%M:%S') + "'"
    return "N'" + str(v).replace("'", "''") + "'"


def insert(table, cols, rows, identity=False):
    if not rows:
        return
    if identity:
        w(f'SET IDENTITY_INSERT {table} ON;')
    for i in range(0, len(rows), 500):
        chunk = rows[i:i + 500]
        w(f'INSERT {table} ({", ".join(cols)}) VALUES')
        w(',\n'.join('  (' + ', '.join(q(v) for v in r) + ')' for r in chunk) + ';')
    if identity:
        w(f'SET IDENTITY_INSERT {table} OFF;')
    w('')


w('-- MDMS-Cy, Φάση Β: ΚΟΙΝΑ ΔΕΔΟΜΕΝΑ ΒΑΣΗΣ (εργασία F2). ΜΗΝ το διορθώνετε με το χέρι:')
w('-- αλλάζει μόνο το data/gen/base.py και μετά τρέχει ξανά (python3 data/gen/base.py).')
w('-- Σειρά: drop.sql -> create.sql -> (procedures) -> ΑΥΤΟ -> data/small/10_*, 20_*, 30_*.')
w('-- Κωδικός δοκιμής για όλους τους χρήστες demo: Mdms2026!  (δεν είναι κωδικός κανενός ανθρώπου)')
w('-- Χρόνοι σε UTC. Οι μετρήσεις: 18-19/11/2026 validated, 20/11/2026 00:00-05:45 raw (Pending) για το VEE.')
w('SET NOCOUNT ON;')
w('SET XACT_ABORT ON;')
w('BEGIN TRAN;')
w('')

# ---------------- Εταιρείες ----------------
insert('SUPPLIER', ['SupplierID', 'Name'], [(1, 'Φωτεινή Ενέργεια Ltd'), (2, 'Ήλιος Power Ltd')], True)
insert('AGGREGATOR', ['AggregatorID', 'Name'], [(1, 'ΑΠΕ Συνεργασία Aggregator')], True)

# ---------------- Χρήστες: ένας (τουλάχιστον) ανά ρόλο ----------------
U = ['UserID', 'Username', 'PasswordHash', 'Role', 'Email', 'Phone', 'FirstName', 'LastName', 'AccountStatus',
     'CreatedBy', 'RawRetentionMonths', 'BirthDate', 'Photo', 'ApprovalStatus', 'ApprovalDecidedAt', 'ApprovedBy',
     'SupplierID', 'AggregatorID']
t0 = datetime(2026, 11, 1, 8, 0, 0)
users = [
    (1, 'admin', PW, 'Admin', 'admin@mdms.cy', None, 'Άννα', 'Διαχειρίστρια', 'Active', None, None, None, None, None, None, None, None, None),
    (2, 'operator', PW, 'Operator', 'operator@mdms.cy', None, 'Πέτρος', 'Λειτουργός', 'Active', 1, None, None, None, None, None, None, None, None),
    (3, 'consumer1', PW, 'Consumer', 'maria@example.cy', '99000001', 'Μαρία', 'Γεωργίου', 'Active', None, 36, None, None, None, None, None, None, None),
    (4, 'consumer2', PW, 'Consumer', 'nikos@example.cy', '99000002', 'Νίκος', 'Ιωάννου', 'Active', None, 36, None, None, None, None, None, None, None),
    (5, 'tech1', PW, 'Technician', 'tech1@example.cy', '99000005', 'Κώστας', 'Τεχνικός', 'Active', None, None, '1990-05-10', 'photos/tech1.jpg', 'Approved', t0, 2, None, None),
    (6, 'tech2', PW, 'Technician', 'tech2@example.cy', '99000006', 'Ελένη', 'Νέα', 'Active', None, None, '1995-03-22', 'photos/tech2.jpg', 'Pending', None, None, None, None),
    (7, 'dso1', PW, 'DSO', 'dso@mdms.cy', None, 'Γιώργος', 'Διανομέας', 'Active', None, None, None, None, None, None, None, None, None),
    (8, 'tso1', PW, 'TSO', 'tso@mdms.cy', None, 'Σοφία', 'Δίκτυο', 'Active', None, None, None, None, None, None, None, None, None),
    (9, 'supplier1', PW, 'Supplier', 'sales@fotini.cy', None, 'Χάρης', 'Προμηθευτής', 'Active', None, None, None, None, None, None, None, 1, None),
    (10, 'aggregator1', PW, 'Aggregator', 'ops@ape.cy', None, 'Λένα', 'Aggregator', 'Active', None, None, None, None, None, None, None, None, 1),
]
insert('USER_ACCOUNT', U, users, True)
insert('CONSUMER_NOTIFICATION_CHANNEL', ['UserID', 'NotificationChannel'], [(3, 'Email'), (4, 'Email'), (4, 'SMS')])

# ---------------- Γεωγραφία, κατάλογοι ----------------
insert('DISTRICT', ['DistrictID', 'Name'], [(1, 'Λευκωσία'), (2, 'Λεμεσός')], True)
insert('MUNICIPALITY', ['MunicipalityID', 'Name', 'DistrictID'], [(1, 'Λευκωσία', 1), (2, 'Αγλαντζιά', 1), (3, 'Λεμεσός', 2)], True)
insert('PARISH', ['ParishID', 'Name', 'MunicipalityID'], [(1, 'Άγιος Αντώνιος', 1), (2, 'Αγλαντζιά', 2), (3, 'Άγιος Νικόλαος', 3)], True)
insert('SUPPLY_SCHEME', ['SchemeID', 'Name'], [(1, 'Standard'), (2, 'Net Metering'), (3, 'Net Billing')], True)
insert('TARIFF_TYPE', ['TariffTypeID', 'Name'], [(1, 'Οικιακό 08'), (2, 'Εμπορικό 20')], True)
insert('SERVICE_TYPE', ['ServiceTypeID', 'Name', 'Fee'], [(1, 'Πρόσβαση σε ιστορικά δεδομένα (ανά μήνα)', 2.00), (2, 'Τέλος υπηρεσίας MDMS-Cy', 1.00)], True)
insert('METER_MODEL', ['ModelID', 'Manufacturer', 'ModelName', 'MeterType', 'PhaseCount'],
       [(1, 'MeterCo', 'SP-100', 'Single-Phase', 1), (2, 'MeterCo', 'TP-300', 'Three-Phase', 3)], True)
insert('COMM_TYPE', ['CommTypeID', 'Name'], [(1, 'NB-IoT'), (2, 'PLC'), (3, 'Cellular')], True)
insert('TECHNICIAN_CATEGORY', ['CategoryID', 'Name'], [(1, 'Εγκατάσταση μετρητών'), (2, 'Έλεγχοι anti-tamper')], True)
insert('IN_CATEGORY', ['UserID', 'CategoryID'], [(5, 1), (5, 2), (6, 1)])

# ---------------- OBIS + κανόνες VEE ----------------
obis = [
    ('1.8.0', 'Συνολική εισαγόμενη ενεργός ενέργεια', 'kWh', 'Cumulative register', None, 0, 50),
    ('1.8.1', 'Εισαγόμενη ενέργεια ζώνης αιχμής', 'kWh', 'Cumulative register', None, 0, 50),
    ('1.8.2', 'Εισαγόμενη ενέργεια ζώνης μη-αιχμής', 'kWh', 'Cumulative register', None, 0, 50),
    ('2.8.0', 'Συνολική εξαγόμενη ενεργός ενέργεια (PV)', 'kWh', 'Cumulative register', None, 0, 50),
    ('3.8.0', 'Συνολική εισαγόμενη άεργος ενέργεια', 'kvarh', 'Cumulative register', None, 0, 50),
    ('4.8.0', 'Συνολική εξαγόμενη άεργος ενέργεια', 'kvarh', 'Cumulative register', None, 0, 50),
    ('32.7.0', 'Στιγμιαία τάση φάσης L1', 'V', 'Instantaneous', 'L1', 0, 400),
    ('52.7.0', 'Στιγμιαία τάση φάσης L2', 'V', 'Instantaneous', 'L2', 0, 400),
    ('72.7.0', 'Στιγμιαία τάση φάσης L3', 'V', 'Instantaneous', 'L3', 0, 400),
    ('31.7.0', 'Ένταση ρεύματος φάσης L1', 'A', 'Instantaneous', 'L1', 0, 200),
    ('51.7.0', 'Ένταση ρεύματος φάσης L2', 'A', 'Instantaneous', 'L2', 0, 200),
    ('71.7.0', 'Ένταση ρεύματος φάσης L3', 'A', 'Instantaneous', 'L3', 0, 200),
]
w('-- OBIS: MinValid/MaxValid = αποδεκτά όρια της τιμής που ελέγχει το VEE (για σωρευτικούς: ενέργεια 15λεπτου).')
insert('OBIS_CODE', ['ObisCode', 'Description', 'Unit', 'Kind', 'Phase', 'MinValid', 'MaxValid'], obis)
rules = [
    (1, 'Range', json.dumps({'note': 'τιμή μέσα στο MinValid-MaxValid του OBIS_CODE'}), 1),
    (2, 'Spike', json.dumps({'factor': 5, 'window': 3, 'note': 'ύποπτη αν > factor x μέσος όρος των προηγούμενων window'}), 1),
    (3, 'Gap', json.dumps({'note': 'λείπει 15λεπτο ανάμεσα σε δύο υπαρκτά'}), 1),
    (4, 'LinearEstimate', json.dumps({'note': 'εκτίμηση κενού = μέσος όρος προηγούμενου και επόμενου'}), 1),
    (5, 'VoltageBand', json.dumps({'min': 207, 'max': 253, 'note': '230 V +/- 10%: εκτός = συμβάν ποιότητας'}), 1),
]
insert('VEE_RULE', ['RuleID', 'RuleType', 'Parameters', 'IsActive'], rules, True)
rule_for = [(1, c[0]) for c in obis] + [(2, '1.8.0'), (2, '2.8.0'), (3, '1.8.0'), (3, '2.8.0'), (4, '1.8.0'), (4, '2.8.0'),
                                         (5, '32.7.0'), (5, '52.7.0'), (5, '72.7.0')]
insert('RULE_FOR', ['RuleID', 'ObisCode'], rule_for)

# ---------------- Δέντρο μετασχηματιστών (geofence 1:1) ----------------
# 1 Κύπρος (ρίζα) -> 2 Λευκωσία, 3 Λεμεσός -> φύλλα 4, 5 (κάτω από 2) και 6 (κάτω από 3)
geo = [
    (1, 'Κύπρος', 34.50, 32.20, 35.75, 34.60),
    (2, 'Επαρχία Λευκωσίας', 35.05, 33.20, 35.25, 33.50),
    (3, 'Επαρχία Λεμεσού', 34.62, 32.95, 34.76, 33.15),
    (4, 'Αγλαντζιά LV', 35.13, 33.37, 35.16, 33.41),
    (5, 'Άγιος Αντώνιος LV', 35.16, 33.36, 35.18, 33.38),
    (6, 'Λεμεσός Κέντρο LV', 34.67, 33.03, 34.69, 33.06),
]
insert('GEOFENCE', ['GeofenceID', 'Name', 'MinLat', 'MinLon', 'MaxLat', 'MaxLon'], geo, True)
trans = [
    (1, 'T-ROOT Κύπρος', 35.10, 33.30, 1, None),
    (2, 'T-NIC Λευκωσία', 35.17, 33.36, 2, 1),
    (3, 'T-LIM Λεμεσός', 34.68, 33.04, 3, 1),
    (4, 'T-NIC-AGL', 35.145, 33.39, 4, 2),
    (5, 'T-NIC-AGA', 35.17, 33.37, 5, 2),
    (6, 'T-LIM-CEN', 34.68, 33.045, 6, 3),
]
insert('TRANSFORMER', ['TransformerID', 'Name', 'Latitude', 'Longitude', 'GeofenceID', 'ParentTransformerID'], trans, True)

# ---------------- Υποστατικά, κάτοχοι, συμβόλαια, τιμολόγια ----------------
prem = [
    (1, 'Λεωφ. Αγλαντζιάς 10', '2108', 35.1450, 33.3900, 'Residential', 2, 1),
    (2, 'Οδός Αγίου Αντωνίου 5', '1070', 35.1700, 33.3700, 'Residential', 1, 1),
    (3, 'Οδός Ανεξαρτησίας 20', '3036', 34.6800, 33.0450, 'Residential', 3, 2),   # prosumer, Net Metering
    (4, 'Λεωφ. Αγλαντζιάς 44', '2108', 35.1420, 33.3950, 'Commercial', 2, 1),
    (5, 'Οδός Γλάδστωνος 7', '3040', 34.6820, 33.0400, 'Residential', 3, 1),    # χωρίς κάτοχο ακόμα
]
insert('PREMISE', ['PremiseID', 'Address', 'PostalCode', 'Latitude', 'Longitude', 'UsageType', 'ParishID', 'SchemeID'], prem, True)
insert('HOLDING', ['UserID', 'PremiseID', 'StartDate', 'EndDate'],
       [(3, 1, '2026-01-01', None), (3, 2, '2026-03-01', None), (4, 3, '2026-01-01', None), (4, 4, '2026-02-01', None)])
insert('BANK_ACCOUNT', ['BankAccountID', 'IBAN', 'HolderName', 'UserID'],
       [(1, 'CY17002001280000001200527600', 'Μαρία Γεωργίου', 3), (2, 'CY21002001950000357001234567', 'Νίκος Ιωάννου', 4)], True)
insert('ACCOUNT_FOR', ['BankAccountID', 'PremiseID'], [(1, 1), (1, 2), (2, 3), (2, 4)])
insert('SUPPLY_CONTRACT', ['ContractID', 'StartDate', 'EndDate', 'UserID', 'PremiseID', 'SupplierID', 'TariffTypeID'],
       [(1, '2026-01-01', None, 3, 1, 1, 1), (2, '2026-03-01', None, 3, 2, 1, 1),
        (3, '2026-01-01', None, 4, 3, 2, 1), (4, '2026-02-01', None, 4, 4, 1, 2)], True)
insert('INVOICE', ['InvoiceID', 'IssueDate', 'PeriodFrom', 'PeriodTo', 'Amount', 'Status', 'UserID', 'ContractID'],
       [(1, '2026-10-05', '2026-09-01', '2026-09-30', 52.40, 'Paid', 3, 1),
        (2, '2026-11-05', '2026-10-01', '2026-10-31', 47.90, 'Issued', 3, 1),
        (3, '2026-11-05', '2026-10-01', '2026-10-31', 18.30, 'Issued', 4, 3)], True)
insert('PAYMENT', ['PaymentID', 'Amount', 'PaidAt', 'Reference', 'InvoiceID', 'BankAccountID'],
       [(1, 52.40, datetime(2026, 10, 12, 9, 30), 'PAY-2026-0001', 1, 1)], True)
insert('PORTFOLIO', ['PortfolioID', 'Name', 'AggregatorID'], [(1, 'Χαρτοφυλάκιο ΑΠΕ Λεμεσού', 1)], True)
insert('INCLUDES', ['PortfolioID', 'PremiseID', 'StartDate', 'EndDate'], [(1, 3, '2026-01-01', None), (1, 4, '2026-02-01', None)])
insert('SERVICE_REQUEST', ['RequestID', 'RequestType', 'Description', 'Status', 'SubmittedAt', 'UserID', 'PremiseID', 'MeterID'],
       [(1, 'Fault report', 'Ο μετρητής δείχνει πολύ μεγάλη κατανάλωση το βράδυ.', 'Submitted', datetime(2026, 11, 19, 18, 0), 3, 1, None)], True)

# ---------------- Μετρητές: εγκατεστημένοι από τον tech1, επιβεβαιωμένοι από τον operator ----------------
#  MeterID, Serial, NetworkID, Firmware, Amps, lat, lon, Status, Model, Comm, Transformer, Premise
meters = [
    (1, 'SN-0001', 'EAC-NIC-1001', '1.4.2', 60, 35.1450, 33.3900, 'Active', 1, 1, 4, 1),
    (2, 'SN-0002', 'EAC-NIC-1002', '1.4.2', 60, 35.1700, 33.3700, 'Active', 1, 1, 5, 2),
    (3, 'SN-0003', 'EAC-LIM-2001', '2.0.1', 80, 34.6800, 33.0450, 'Active', 2, 3, 6, 3),
    (4, 'SN-0004', 'EAC-NIC-1003', '2.0.1', 100, 35.1420, 33.3950, 'Active', 2, 2, 4, 4),
    (5, 'SN-0005', 'EAC-LIM-2002', '1.4.2', 60, 34.6820, 33.0400, 'Pending confirmation', 1, 1, 6, 5),
]
insert('METER', ['MeterID', 'SerialNumber', 'NetworkID', 'Firmware', 'MaxLoadAmps', 'Latitude', 'Longitude', 'Status', 'ModelID', 'CommTypeID', 'TransformerID'],
       [m[:11] for m in meters], True)
phases = []
for m in meters:
    phases += [(m[0], p) for p in (['L1', 'L2', 'L3'] if m[8] == 2 else ['L1'])]
insert('METER_CONNECTED_PHASE', ['MeterID', 'ConnectedPhase'], phases)
tasks, inst = [], []
for m in meters:
    mid, prem_id = m[0], m[11]
    day = datetime(2026, 10, 1 + mid, 9, 0)
    tasks.append((mid, 'Installation', day, day + timedelta(hours=2), 'Done', 'Εγκαταστάθηκε ο μετρητής ' + m[1], day - timedelta(days=2), day + timedelta(hours=1), 5, prem_id, None, None))
    confirmed = m[7] == 'Active'
    inst.append((mid, day + timedelta(hours=1), None, 'Confirmed' if confirmed else 'Pending',
                 day + timedelta(days=1) if confirmed else None, 'Έλεγχος εγγράφων OK' if confirmed else None,
                 mid, prem_id, 2 if confirmed else None, mid))
insert('FIELD_TASK', ['TaskID', 'TaskType', 'ScheduledFrom', 'ScheduledTo', 'Status', 'Result', 'CreatedAt', 'CompletedAt', 'TechnicianID', 'PremiseID', 'MeterID', 'RequestID'], tasks, True)
insert('METER_INSTALLATION', ['InstallationID', 'InstalledAt', 'RemovedAt', 'ConfirmationStatus', 'ConfirmedAt', 'ConfirmComment', 'MeterID', 'PremiseID', 'ConfirmedBy', 'TaskID'], inst, True)

docs = []
did = 1
for tech, status in ((5, 'Accepted'), (6, 'Pending')):
    for dt in ('ID card', 'Installer licence', 'Training certificate'):
        rev = status == 'Accepted'
        docs.append((did, dt, f'DOC-{tech}-{did}', '2024-01-10', '2030-01-10', f'docs/tech{tech}_{did}.pdf', status,
                     'OK' if rev else None, t0 if rev else None, tech, None, 2 if rev else None))
        did += 1
for mid in (1, 5):
    for dt in ('Calibration certificate', 'CE and protocol declaration', 'Encryption certificate'):
        rev = mid == 1
        docs.append((did, dt, f'DOC-M{mid}-{did}', '2026-09-01', '2031-09-01', f'docs/meter{mid}_{did}.pdf', 'Accepted' if rev else 'Pending',
                     'OK' if rev else None, t0 if rev else None, None, mid, 2 if rev else None))
        did += 1
insert('DOCUMENT', ['DocumentID', 'DocType', 'DocNumber', 'IssueDate', 'ExpiryDate', 'FilePath', 'ReviewStatus', 'ReviewComment', 'ReviewedAt', 'TechnicianID', 'MeterID', 'ReviewedBy'], docs, True)

# ---------------- Μετρήσεις ----------------
# Σειρές: (MeterID, ObisCode). Ο μετρητής 3 είναι prosumer (έχει και 2.8.0).
series = [(1, '1.8.0'), (2, '1.8.0'), (3, '1.8.0'), (3, '2.8.0'), (4, '1.8.0')]
start_counter = {(1, '1.8.0'): 14250.0, (2, '1.8.0'): 8120.0, (3, '1.8.0'): 5310.0, (3, '2.8.0'): 3410.0, (4, '1.8.0'): 22100.0}


def slot_energy(meter, code, ts):
    h = ts.hour + ts.minute / 60
    if code == '2.8.0':           # φωτοβολταϊκά: παραγωγή μόνο τη μέρα (UTC 5-15)
        return round(max(0.0, 0.9 * (1 - abs(h - 10) / 5)) * random.uniform(0.85, 1.0), 4) if 5 <= h <= 15 else 0.0
    base = 0.6 if meter == 4 else 0.25  # ο 4 είναι εμπορικός
    peak = 1.8 if 15 <= h <= 20 else (0.6 if h < 5 else 1.0)
    return round(base * peak * random.uniform(0.8, 1.2), 4)


validated_days = [datetime(2026, 11, 18), datetime(2026, 11, 19)]
raw_day = datetime(2026, 11, 20)
packets, raw, val, mag, tag = [], [], [], {}, {}
pid = 1
counter = dict(start_counter)


def add_packet(meter_id, ts, payload):
    global pid
    net = next(m[2] for m in meters if m[0] == meter_id)
    body = json.dumps({'Meter_Network_ID': net, 'Transmission_Timestamp': ts.strftime('%Y-%m-%dT%H:%M:%SZ'),
                       'Cell_Signal_Strength_dBm': -90, 'Network_Type': 'NB-IoT', 'Telemetry_Payload': payload}, ensure_ascii=False)
    packets.append((pid, net, ts, ts + timedelta(seconds=20), 'NB-IoT', -90, body, 'Accepted', None, meter_id))
    pid += 1
    return pid - 1


for day in validated_days + [raw_day]:
    slots = 96 if day in validated_days else 24
    for meter_id in (1, 2, 3, 4):
        codes = [c for (m, c) in series if m == meter_id]
        for s in range(slots):
            ts = day + timedelta(minutes=15 * s)
            if day == raw_day and meter_id == 1 and s == 10:
                continue                                   # ΚΕΝΟ στις 02:30 του μετρητή 1 (για το Gap/Estimation)
            payload, rows = [], []
            for code in codes:
                e = slot_energy(meter_id, code, ts)
                if day == raw_day and meter_id == 1 and s == 16:
                    e = 25.4                               # SPIKE στις 04:00 του μετρητή 1 (για το Spike)
                counter[(meter_id, code)] = round(counter[(meter_id, code)] + e, 4)
                payload.append({'obis': code, 'value': counter[(meter_id, code)], 'unit': 'kWh'})
                rows.append((code, counter[(meter_id, code)], e))
            if day == raw_day and meter_id == 1:
                v = 198.5 if s == 20 else round(random.uniform(225, 235), 1)   # υπόταση στις 05:00
                payload.append({'obis': '32.7.0', 'value': v, 'unit': 'V'})
                rows.append(('32.7.0', v, v))
            p = add_packet(meter_id, ts, payload)
            for code, received, e in rows:
                if day in validated_days:
                    raw.append((meter_id, code, ts, received, 'Validated', p))
                    val.append((meter_id, code, ts, e, 'Validated', 1, datetime(2026, 11, 20, 1, 0)))
                    key = (meter_id, code, day.strftime('%Y-%m-%d'))
                    mag.setdefault(key, [0.0, 0])
                    mag[key][0] += e
                    mag[key][1] += 1
                else:
                    raw.append((meter_id, code, ts, received, 'Pending', p))

w('-- Πακέτα τηλεμετρίας: ένα ανά μετρητή και 15λεπτο (RawPayload = το JSON όπως στο Παράρτημα της εκφώνησης).')
insert('TELEMETRY_PACKET', ['PacketID', 'ReceivedNetworkID', 'TransmissionTimestamp', 'ReceivedAt', 'NetworkType', 'SignalDbm', 'RawPayload', 'IngestStatus', 'ErrorMessage', 'MeterID'], packets, True)
w('-- Ένα πακέτο από άγνωστο μετρητή: δεν χάνεται, γράφεται ως αποτυχία + συμβάν (ΙΙΙ.3.1).')
insert('TELEMETRY_PACKET', ['PacketID', 'ReceivedNetworkID', 'TransmissionTimestamp', 'ReceivedAt', 'NetworkType', 'SignalDbm', 'RawPayload', 'IngestStatus', 'ErrorMessage', 'MeterID'],
       [(pid, 'EAC-XXX-9999', datetime(2026, 11, 20, 3, 0), datetime(2026, 11, 20, 3, 0, 15), 'PLC', None,
         json.dumps({'Meter_Network_ID': 'EAC-XXX-9999', 'Telemetry_Payload': [{'obis': '1.8.0', 'value': 10.0, 'unit': 'kWh'}]}),
         'Unknown meter', 'Δεν υπάρχει μετρητής με αυτό το NetworkID', None)], True)
unknown_pid = pid
w('-- Raw: ReceivedValue = ό,τι έστειλε ο μετρητής (για 1.8.0 / 2.8.0 ο σωρευτικός μετρητής).')
insert('RAW_READING', ['MeterID', 'ObisCode', 'IntervalStart', 'ReceivedValue', 'VeeStatus', 'PacketID'], raw)
insert('VEE_RUN', ['RunID', 'PeriodFrom', 'PeriodTo', 'StartedAt', 'FinishedAt'],
       [(1, datetime(2026, 11, 18), datetime(2026, 11, 20), datetime(2026, 11, 20, 1, 0), datetime(2026, 11, 20, 1, 2))], True)
w('-- Validated: Value = ενέργεια του 15λεπτου (διαφορά από το προηγούμενο) - απόφαση Α2 του πλάνου.')
insert('VALIDATED_READING', ['MeterID', 'ObisCode', 'IntervalStart', 'Value', 'Quality', 'RunID', 'ValidatedAt'], val)
insert('METER_AGGREGATE', ['MeterID', 'ObisCode', 'PeriodType', 'PeriodStart', 'SumValue', 'ReadingCount', 'EstimatedCount'],
       [(m, c, 'Day', d, round(s, 4), n, 0) for (m, c, d), (s, n) in sorted(mag.items())])
leaf_of = {m[0]: m[10] for m in meters}
tagg = {}
for (m, c, d), (s, n) in mag.items():
    k = (leaf_of[m], c, d)
    tagg.setdefault(k, [0.0, set()])
    tagg[k][0] += s
    tagg[k][1].add(m)
insert('TRANSFORMER_AGGREGATE', ['TransformerID', 'ObisCode', 'PeriodType', 'PeriodStart', 'SumValue', 'MeterCount', 'ComputedAt'],
       [(t, c, 'Day', d, round(s, 4), len(ms), datetime(2026, 11, 20, 1, 3)) for (t, c, d), (s, ms) in sorted(tagg.items())])
insert('EVENT', ['EventID', 'EventType', 'Severity', 'Description', 'OccurredAt', 'Status', 'MeterID', 'PacketID', 'TaskID'],
       [(1, 'Unmatched packet', 'Warning', 'Πακέτο από άγνωστο NetworkID EAC-XXX-9999', datetime(2026, 11, 20, 3, 0), 'Open', None, unknown_pid, None)], True)

w('COMMIT;')
w(f"PRINT N'00_base.sql: OK ({len(users)} χρήστες, {len(meters)} μετρητές, {len(raw)} raw, {len(val)} validated)';")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, 'w', encoding='utf-8') as f:
    f.write('\n'.join(out) + '\n')
print('wrote', os.path.normpath(OUT), len(raw), 'raw', len(val), 'validated', len(packets) + 1, 'packets')
