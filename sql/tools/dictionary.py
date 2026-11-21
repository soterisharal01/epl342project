#!/usr/bin/env python3
"""Generate docs/20-data-dictionary.md from sql/create.sql (task DOC-3).

Run from the repo root:  python sql/tools/dictionary.py
The structure (columns, types, keys, checks, triggers) is parsed from create.sql.
Purposes and the meaning of non-obvious columns are written by hand in the dicts below.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "sql" / "create.sql"
OUT = ROOT / "docs" / "20-data-dictionary.md"

AREAS = {
    "Users and companies": ["USER_ACCOUNT", "SUPPLIER", "AGGREGATOR", "CONSUMER_NOTIFICATION_CHANNEL"],
    "Geography": ["DISTRICT", "MUNICIPALITY", "PARISH"],
    "Premises and money": ["PREMISE", "SUPPLY_SCHEME", "HOLDING", "BANK_ACCOUNT", "ACCOUNT_FOR", "CONSUMPTION_THRESHOLD",
                           "TARIFF_TYPE", "SUPPLY_CONTRACT", "INVOICE", "PAYMENT", "SERVICE_TYPE", "SERVICE_PURCHASE",
                           "SERVICE_REQUEST"],
    "Technicians and field work": ["TECHNICIAN_CATEGORY", "IN_CATEGORY", "DOCUMENT", "AVAILABILITY", "AVAILABLE_IN",
                                   "FIELD_TASK", "TASK_NOTE", "ATTACHMENT", "NOTIFIES"],
    "Meters and commands": ["METER_MODEL", "COMM_TYPE", "METER", "METER_INSTALLATION", "METER_CONNECTED_PHASE",
                            "REMOTE_COMMAND", "COMMAND_ATTEMPT"],
    "Telemetry and VEE": ["TELEMETRY_PACKET", "OBIS_CODE", "RAW_READING", "VEE_RULE", "RULE_FOR", "VEE_RUN",
                          "VALIDATED_READING", "READING_EDIT"],
    "Aggregates and grid": ["METER_AGGREGATE", "GEOFENCE", "TRANSFORMER", "TRANSFORMER_AGGREGATE",
                            "TRANSFORMER_CURRENT_STATE", "LOAD_SHED_ORDER"],
    "Events": ["EVENT", "LEADS_TO"],
    "Market": ["PORTFOLIO", "INCLUDES"],
    "Compliance": ["GDPR_REQUEST", "AUDIT_LOG"],
}

PURPOSE = {
    "USER_ACCOUNT": "Every person who logs in; one username has exactly one Role, and the role-specific columns are NULL unless that role needs them.",
    "SUPPLIER": "An electricity supplier company (a company, not a role); its staff are USER_ACCOUNT rows with Role Supplier.",
    "AGGREGATOR": "A market aggregator company that manages portfolios of premises; its staff have Role Aggregator.",
    "CONSUMER_NOTIFICATION_CHANNEL": "The channels (Email, SMS) through which a consumer wants to be informed.",
    "DISTRICT": "Top level of the administrative geography (Cyprus districts).",
    "MUNICIPALITY": "Second level of the geography; belongs to one district.",
    "PARISH": "Third level of the geography; belongs to one municipality and is where a premise is located.",
    "PREMISE": "A supplied property (house, shop, factory, field) with address, coordinates, usage type and supply scheme.",
    "SUPPLY_SCHEME": "Lookup of supply schemes a premise can be under.",
    "HOLDING": "One period in which a consumer holds a premise; at most one open (EndDate NULL) row per consumer and premise.",
    "BANK_ACCOUNT": "A bank account (IBAN) of a consumer, used to pay invoices.",
    "ACCOUNT_FOR": "Many-to-many link saying which premises a bank account pays for.",
    "CONSUMPTION_THRESHOLD": "A consumer's daily or monthly consumption limit for one premise; crossing it triggers a notification.",
    "TARIFF_TYPE": "Lookup of tariff types a supply contract can be on.",
    "SUPPLY_CONTRACT": "A dated contract between a consumer, a premise and a supplier; decides which supplier may see which customer.",
    "INVOICE": "A bill issued to a consumer for a period, optionally under a supply contract.",
    "PAYMENT": "One payment against an invoice, possibly from a stored bank account.",
    "SERVICE_TYPE": "Catalogue of paid additional services with their fee.",
    "SERVICE_PURCHASE": "A consumer's purchase of an additional service for a premise, charged on an invoice.",
    "SERVICE_REQUEST": "A consumer's request for a meter check or a fault report on a premise or meter.",
    "TECHNICIAN_CATEGORY": "Lookup of technician specialities (categories).",
    "IN_CATEGORY": "Many-to-many link between technicians and their categories.",
    "DOCUMENT": "A certificate or ID file owned either by a technician or by a meter, reviewed by an operator.",
    "AVAILABILITY": "One daily time slot a technician declares as available.",
    "AVAILABLE_IN": "The municipalities that one availability slot covers.",
    "FIELD_TASK": "A job for a technician (installation, replacement, technical or anti-tamper check) at a premise and/or meter.",
    "TASK_NOTE": "Numbered observations and findings a technician writes while doing a task.",
    "ATTACHMENT": "A file (photo, evidence) uploaded for a field task.",
    "NOTIFIES": "Many-to-many link recording which users are notified about a task.",
    "METER_MODEL": "Manufacturer and model of meters, with the number of phases.",
    "COMM_TYPE": "Lookup of the communication technology a meter uses.",
    "METER": "A smart meter device with identifiers, firmware, status and the leaf transformer that serves it.",
    "METER_INSTALLATION": "History of one meter installed at one premise; a replacement closes one row and opens another.",
    "METER_CONNECTED_PHASE": "The phases (L1, L2, L3) a meter is connected to.",
    "REMOTE_COMMAND": "A command sent to a meter (for example load shed or disconnect), with approval and status.",
    "COMMAND_ATTEMPT": "Each numbered try to deliver a remote command and what came back (Timeout, NAK, ACK).",
    "TELEMETRY_PACKET": "Every telemetry packet that reached the DSO endpoint, kept with its ingest result even if it was rejected.",
    "OBIS_CODE": "Catalogue of measurement types (OBIS codes) with unit, kind and the range VEE accepts.",
    "RAW_READING": "A 15-minute value exactly as the meter sent it, waiting for or marked by VEE.",
    "VEE_RULE": "A configurable validation, estimation or editing rule with JSON parameters.",
    "RULE_FOR": "Many-to-many link saying which OBIS codes a VEE rule applies to.",
    "VEE_RUN": "One execution of the VEE process over a period.",
    "VALIDATED_READING": "The final 15-minute value produced by VEE; immutable, and the only source of aggregates.",
    "READING_EDIT": "Audit trail of each VEE estimate and manual correction of a 15-minute value.",
    "METER_AGGREGATE": "Stored daily, monthly or yearly sum of validated readings per meter and OBIS code.",
    "GEOFENCE": "A rectangular map area, one per transformer; the hierarchy comes from the transformer tree.",
    "TRANSFORMER": "A transformer in a strict tree (root has no parent); meters are attached only to leaves.",
    "TRANSFORMER_AGGREGATE": "Stored Day, Month or Year totals for leaf transformers; upper levels are computed with a recursive query.",
    "TRANSFORMER_CURRENT_STATE": "Latest 15-minute import (1.8.0) and export (2.8.0) total per leaf transformer.",
    "LOAD_SHED_ORDER": "A TSO order to reduce load on a transformer; it groups one command per active meter.",
    "EVENT": "A network or meter event (alarm, unmatched packet) with severity and handling status.",
    "LEADS_TO": "Many-to-many link between events and the field tasks they cause.",
    "PORTFOLIO": "A named group of premises managed by an aggregator.",
    "INCLUDES": "Membership of a premise in a portfolio, with its dates.",
    "GDPR_REQUEST": "A consumer's erasure request moving through the stages Submitted, Under review, Pre-approved, Approved or Rejected, Applied.",
    "AUDIT_LOG": "Generic dated record of every state change: object type and id, action, actor, old and new state.",
}

# Meanings written by hand: (TABLE, COLUMN) first, then COLUMN only (any table).
MEANING_T = {
    ("USER_ACCOUNT", "Role"): "The one role of this username: Admin, Operator, Consumer, Technician, DSO, TSO, Supplier or Aggregator.",
    ("USER_ACCOUNT", "PasswordHash"): "Hash from PHP password_hash(); the password itself is never stored.",
    ("USER_ACCOUNT", "AccountStatus"): "Active or Suspended; a suspended account cannot log in.",
    ("USER_ACCOUNT", "CreatedBy"): "Admin who created the account (set only when Role is Operator).",
    ("USER_ACCOUNT", "RawRetentionMonths"): "How many months raw readings of this consumer are kept (1 to 36); set for Consumer only.",
    ("USER_ACCOUNT", "BirthDate"): "Technician only.",
    ("USER_ACCOUNT", "Photo"): "Path of the technician's photo; Technician only.",
    ("USER_ACCOUNT", "ApprovalStatus"): "Technician registration state: Pending, Approved, Rejected or Suspended; NULL for other roles.",
    ("USER_ACCOUNT", "ApprovalDecidedAt"): "When an operator decided the technician's registration.",
    ("USER_ACCOUNT", "ApprovedBy"): "Operator who decided the technician's registration.",
    ("USER_ACCOUNT", "SupplierID"): "Company of a Supplier user; NULL for every other role.",
    ("USER_ACCOUNT", "AggregatorID"): "Company of an Aggregator user; NULL for every other role.",
    ("HOLDING", "EndDate"): "NULL while the consumer still holds the premise (open period).",
    ("PREMISE", "UsageType"): "Residential, Commercial, Industrial or Agricultural.",
    ("CONSUMPTION_THRESHOLD", "LimitKWh"): "The limit in kWh for the PeriodType.",
    ("CONSUMPTION_THRESHOLD", "UserID"): "Consumer who set the threshold.",
    ("SUPPLY_CONTRACT", "EndDate"): "NULL while the contract is active; one open contract per premise.",
    ("SUPPLY_CONTRACT", "UserID"): "The consumer who signed the contract.",
    ("INVOICE", "Status"): "Issued, Partially paid, Paid or Cancelled.",
    ("INVOICE", "Amount"): "Total to pay in euro.",
    ("INVOICE", "UserID"): "Consumer the invoice is issued to.",
    ("SERVICE_PURCHASE", "MonthFrom"): "First month of the service (first day of the month); NULL for one-off services.",
    ("SERVICE_PURCHASE", "MonthTo"): "Last month of the service (first day of the month).",
    ("SERVICE_REQUEST", "UserID"): "Consumer who submitted the request.",
    ("SERVICE_REQUEST", "Status"): "Submitted, Assigned, Resolved or Cancelled.",
    ("DOCUMENT", "TechnicianID"): "Owner when the document belongs to a technician (ID card, licence, training); exactly one of TechnicianID and MeterID is set.",
    ("DOCUMENT", "MeterID"): "Owner when the document belongs to a meter (calibration, CE, encryption certificate).",
    ("DOCUMENT", "ReviewStatus"): "Pending, Accepted or Rejected.",
    ("DOCUMENT", "ReviewedBy"): "Operator who reviewed the document.",
    ("DOCUMENT", "FilePath"): "Where the uploaded file is stored.",
    ("FIELD_TASK", "Status"): "Assigned, Accepted, Done or Cancelled.",
    ("FIELD_TASK", "TechnicianID"): "The technician (USER_ACCOUNT with Role Technician) the task is assigned to.",
    ("FIELD_TASK", "Result"): "Outcome written by the technician; required when Status is Done.",
    ("FIELD_TASK", "RequestID"): "Service request this task resolves, if any.",
    ("TASK_NOTE", "NoteKind"): "Observation or Finding.",
    ("TASK_NOTE", "NoteNo"): "Number of the note within its task (1, 2, 3...).",
    ("AVAILABILITY", "UserID"): "The technician who declared the slot.",
    ("METER", "NetworkID"): "Identifier the meter puts in its telemetry packets; used to match a packet to the meter.",
    ("METER", "Status"): "Pending confirmation, Active or Retired; only Active meters accept telemetry and commands.",
    ("METER", "MaxLoadAmps"): "Maximum load the meter supports, in amperes.",
    ("METER", "TransformerID"): "Leaf transformer that serves this meter.",
    ("METER_INSTALLATION", "ConfirmationStatus"): "Pending, Confirmed or Rejected; an operator confirms the technician's installation.",
    ("METER_INSTALLATION", "RemovedAt"): "NULL while the meter is still installed (open row); one open installation per meter.",
    ("METER_INSTALLATION", "TaskID"): "The installation or replacement task that created this row.",
    ("METER_INSTALLATION", "ConfirmedBy"): "Operator who confirmed or rejected.",
    ("REMOTE_COMMAND", "CommandType"): "Kind of command; 'Load shed' exactly when ShedOrderID is set.",
    ("REMOTE_COMMAND", "Parameters"): "JSON with the command's parameters.",
    ("REMOTE_COMMAND", "Status"): "Awaiting approval, Sent, Acknowledged, Failed or Cancelled.",
    ("REMOTE_COMMAND", "RequestedBy"): "User who asked for the command.",
    ("REMOTE_COMMAND", "ApprovedBy"): "User who approved it; must be NULL while Status is Awaiting approval.",
    ("REMOTE_COMMAND", "ShedOrderID"): "Load-shed order this command belongs to; NULL for ordinary commands.",
    ("COMMAND_ATTEMPT", "AttemptNo"): "Number of the try within the command (1, 2, 3...).",
    ("COMMAND_ATTEMPT", "Outcome"): "Timeout, NAK or ACK; NULL while waiting.",
    ("COMMAND_ATTEMPT", "RespondedAt"): "When the meter answered; set only for NAK and ACK.",
    ("TELEMETRY_PACKET", "ReceivedNetworkID"): "Network id as written in the packet, before matching to a meter.",
    ("TELEMETRY_PACKET", "TransmissionTimestamp"): "Time the meter says it sent the packet.",
    ("TELEMETRY_PACKET", "ReceivedAt"): "Time the server received it.",
    ("TELEMETRY_PACKET", "NetworkType"): "Network the packet came over, as reported by the meter.",
    ("TELEMETRY_PACKET", "SignalDbm"): "Signal strength in dBm (-150 to 0).",
    ("TELEMETRY_PACKET", "RawPayload"): "The packet exactly as received (JSON text).",
    ("TELEMETRY_PACKET", "IngestStatus"): "Accepted, Partially accepted, Unknown meter, Meter not active or Malformed.",
    ("TELEMETRY_PACKET", "ErrorMessage"): "Why the packet was (partly) rejected; required for Partially accepted and Malformed.",
    ("TELEMETRY_PACKET", "MeterID"): "Meter the packet was matched to; NULL for Unknown meter or Malformed.",
    ("OBIS_CODE", "ObisCode"): "The code itself, for example 1.8.0 (import energy) or 2.8.0 (export energy).",
    ("OBIS_CODE", "Kind"): "Cumulative register (counter that only grows) or Instantaneous (voltage, current).",
    ("OBIS_CODE", "Phase"): "L1, L2 or L3 for per-phase codes; NULL otherwise.",
    ("OBIS_CODE", "MinValid"): "Lowest value VEE accepts for this code (NULL = no limit).",
    ("OBIS_CODE", "MaxValid"): "Highest value VEE accepts for this code (NULL = no limit).",
    ("RAW_READING", "IntervalStart"): "Start of the 15-minute interval (minute 0, 15, 30 or 45, seconds 0).",
    ("RAW_READING", "ReceivedValue"): "What the meter sent (decision B2); for 1.8.0 this is the counter since installation, not the 15-minute energy.",
    ("RAW_READING", "VeeStatus"): "Pending (not yet checked), Validated or Suspect (failed a VEE rule).",
    ("RAW_READING", "PacketID"): "Packet that carried this value.",
    ("VEE_RULE", "RuleType"): "Kind of rule (for example range, spike, gap, estimation method).",
    ("VEE_RULE", "Parameters"): "JSON with the rule's thresholds; changing it changes VEE behaviour with no code change.",
    ("VEE_RULE", "IsActive"): "Inactive rules are skipped by VEE.",
    ("VEE_RUN", "PeriodFrom"): "Start of the period the run processed.",
    ("VEE_RUN", "PeriodTo"): "End of the period the run processed.",
    ("VEE_RUN", "FinishedAt"): "NULL while the run is still going.",
    ("VALIDATED_READING", "Value"): "Energy in that 15 minutes for cumulative codes (difference from the previous interval), or the measured value for instantaneous codes (decision B2).",
    ("VALIDATED_READING", "Quality"): "Validated (passed all rules), Estimated (VEE filled it) or Edited (changed by hand).",
    ("VALIDATED_READING", "RunID"): "VEE run that made this reading final.",
    ("VALIDATED_READING", "ValidatedAt"): "When the row was written; the row never changes afterwards (trigger).",
    ("READING_EDIT", "EditNo"): "Number of the edit for this meter, code and interval (1, 2, ...).",
    ("READING_EDIT", "OldValue"): "Value before the edit; NULL when the slot had no value (a gap).",
    ("READING_EDIT", "NewValue"): "Value after the edit.",
    ("READING_EDIT", "Origin"): "Automatic estimate (VEE rule), Manual estimate or Manual edit (DSO staff).",
    ("READING_EDIT", "EditedBy"): "DSO user for manual origins; NULL for automatic estimates.",
    ("READING_EDIT", "RuleID"): "VEE rule that produced an automatic estimate.",
    ("METER_AGGREGATE", "PeriodType"): "Day, Month or Year.",
    ("METER_AGGREGATE", "PeriodStart"): "First day of the period (first of the month for Month, 1 January for Year).",
    ("METER_AGGREGATE", "SumValue"): "Sum of the validated 15-minute Values of the period.",
    ("METER_AGGREGATE", "ReadingCount"): "How many validated readings were summed.",
    ("METER_AGGREGATE", "EstimatedCount"): "How many of those were Estimated or Edited rather than measured.",
    ("GEOFENCE", "MinLat"): "South edge of the rectangle.",
    ("GEOFENCE", "MinLon"): "West edge of the rectangle.",
    ("GEOFENCE", "MaxLat"): "North edge of the rectangle.",
    ("GEOFENCE", "MaxLon"): "East edge of the rectangle.",
    ("TRANSFORMER", "ParentTransformerID"): "Parent in the tree; NULL for the root.",
    ("TRANSFORMER", "GeofenceID"): "The map area this transformer serves (one-to-one).",
    ("TRANSFORMER_AGGREGATE", "PeriodType"): "Day, Month or Year.",
    ("TRANSFORMER_AGGREGATE", "PeriodStart"): "First day of the period.",
    ("TRANSFORMER_AGGREGATE", "SumValue"): "Sum of the meters' validated Values under this leaf transformer for the period.",
    ("TRANSFORMER_AGGREGATE", "MeterCount"): "Number of meters included.",
    ("TRANSFORMER_AGGREGATE", "ComputedAt"): "When the row was computed.",
    ("TRANSFORMER_CURRENT_STATE", "ObisCode"): "Only 1.8.0 (import) or 2.8.0 (export).",
    ("TRANSFORMER_CURRENT_STATE", "RefInterval"): "The 15-minute interval the state refers to.",
    ("TRANSFORMER_CURRENT_STATE", "SumValue"): "Sum of the meters' Values in that interval.",
    ("TRANSFORMER_CURRENT_STATE", "MeterCount"): "Number of meters included.",
    ("LOAD_SHED_ORDER", "Status"): "Issued, Completed or Partially failed (some command did not get an ACK).",
    ("LOAD_SHED_ORDER", "OrderedBy"): "TSO user who issued the order.",
    ("EVENT", "EventType"): "Kind of event (for example 'Unmatched packet'); an Unmatched packet event needs PacketID.",
    ("EVENT", "Severity"): "Info, Warning or Critical.",
    ("EVENT", "Status"): "Open, In progress or Closed.",
    ("EVENT", "TaskID"): "Field task during which the event was found, if any.",
    ("INCLUDES", "StartDate"): "Date the premise joined the portfolio.",
    ("INCLUDES", "EndDate"): "NULL while the premise is still in the portfolio.",
    ("GDPR_REQUEST", "Status"): "Stage: Submitted, Under review, Pre-approved, Approved, Rejected or Applied; a CHECK ties each stage to the timestamps that must be set.",
    ("GDPR_REQUEST", "ConsumerID"): "Consumer who asks for erasure.",
    ("GDPR_REQUEST", "PreApprovedBy"): "Operator who pre-approved.",
    ("GDPR_REQUEST", "DecidedBy"): "Operator who gave the final decision (at most one of DecidedBy and DecidedByAdmin).",
    ("GDPR_REQUEST", "DecidedByAdmin"): "Admin who gave the final decision instead of an operator.",
    ("GDPR_REQUEST", "AppliedAt"): "When the erasure was carried out.",
    ("AUDIT_LOG", "ObjectType"): "Kind of object changed (table or concept name); not a foreign key, so any object can be logged.",
    ("AUDIT_LOG", "ObjectID"): "Id of the changed object, as text.",
    ("AUDIT_LOG", "Action"): "What happened (for example create, approve, reject).",
    ("AUDIT_LOG", "ActorMechanism"): "For automatic actions: the job or procedure that acted (set when PerformedBy is NULL).",
    ("AUDIT_LOG", "OldState"): "State before the change.",
    ("AUDIT_LOG", "NewState"): "State after the change.",
    ("AUDIT_LOG", "ResultComment"): "Free-text outcome or reason.",
    ("AUDIT_LOG", "PerformedBy"): "User who acted; NULL for automatic actions.",
}
MEANING_C = {
    "Latitude": "Latitude in degrees (-90 to 90).",
    "Longitude": "Longitude in degrees (-180 to 180).",
    "IsActive": "1 = in use, 0 = switched off.",
    "CreatedAt": "When the row was created (UTC).",
    "Email": "E-mail address.",
    "Phone": "Phone number (digits, + and spaces).",
    "IBAN": "International bank account number.",
    "HolderName": "Name of the account holder.",
    "PeriodType": "Period the row covers.",
    "Fee": "Price of the service in euro.",
    "ObisCode": "OBIS code of the measurement (foreign key to OBIS_CODE).",
    "IntervalStart": "Start of the 15-minute interval.",
}

TRIGGER_TEXT = {
    "TR_TRANSFORMER_Tree": "Error 50001: a parent transformer may not have meters. Error 50002: no cycles in the tree.",
    "TR_METER_LeafTransformer": "Error 50003: a meter may be attached only to a transformer that has no children.",
    "TR_TRANSFORMER_AGGREGATE_Leaf": "Error 50004: aggregates are stored only for leaf transformers.",
    "TR_VALIDATED_READING_Immutable": "Error 50005: UPDATE is always rejected. Error 50006: DELETE is rejected unless the retention procedure set session context mdms_purge = 1.",
}

# ---------------------------------------------------------------- parsing


def split_top(body):
    items, depth, cur, inq = [], 0, [], False
    for ch in body:
        if ch == "'":
            inq = not inq
        if not inq:
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            elif ch == "," and depth == 0:
                items.append("".join(cur).strip())
                cur = []
                continue
        cur.append(ch)
    if "".join(cur).strip():
        items.append("".join(cur).strip())
    return items


def squash(s):
    return re.sub(r"\s+", " ", s).strip()


def check_text(expr):
    """Text inside the first CHECK ( ... ) of expr."""
    i = expr.index("CHECK") + 5
    j = expr.index("(", i)
    depth, k, inq = 0, j, False
    while k < len(expr):
        c = expr[k]
        if c == "'":
            inq = not inq
        if not inq:
            if c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
                if depth == 0:
                    return squash(expr[j + 1:k])
        k += 1
    return squash(expr[j + 1:])


def readable(expr):
    e = squash(expr)
    m = re.fullmatch(r"(\w+) IN \((.*)\)", e)
    if m:
        return f"{m.group(1)} is one of {m.group(2)}"
    m = re.fullmatch(r"(\w+) BETWEEN (\S+) AND (\S+)", e)
    if m:
        return f"{m.group(1)} between {m.group(2)} and {m.group(3)}"
    m = re.fullmatch(r"(\w+) (>=|>|<=|<) (\S+)", e)
    if m:
        return f"{m.group(1)} {m.group(2)} {m.group(3)}"
    return e


def parse_tables(sql):
    tables, order = {}, []
    for m in re.finditer(r"CREATE TABLE (\w+) \(\n(.*?)\n\);", sql, re.S):
        name, body = m.group(1), m.group(2)
        t = {"cols": [], "pk": [], "fks": [], "uniques": [], "checks": []}
        for item in split_top(body):
            if item.startswith("CONSTRAINT"):
                cm = re.match(r"CONSTRAINT (\w+) (PRIMARY KEY|FOREIGN KEY|UNIQUE|CHECK)", item)
                cname, kind = cm.group(1), cm.group(2)
                if kind == "PRIMARY KEY":
                    t["pk"] = [c.strip() for c in re.search(r"\(([^)]*)\)", item).group(1).split(",")]
                elif kind == "UNIQUE":
                    t["uniques"].append((cname, [c.strip() for c in re.search(r"\(([^)]*)\)", item).group(1).split(",")]))
                elif kind == "FOREIGN KEY":
                    fm = re.search(r"FOREIGN KEY \(([^)]*)\) REFERENCES (\w+) \(([^)]*)\)(.*)", item, re.S)
                    t["fks"].append((cname, [c.strip() for c in fm.group(1).split(",")], fm.group(2),
                                     [c.strip() for c in fm.group(3).split(",")], "ON DELETE CASCADE" in fm.group(4)))
                else:
                    t["checks"].append((cname, readable(check_text(item))))
            else:
                cm = re.match(r"(\w+)\s+(\w+(?:\([^)]*\))?)\s*(.*)", item, re.S)
                cname, ctype, rest = cm.groups()
                rest = squash(rest)
                head = rest.split("CONSTRAINT")[0]
                identity = "IDENTITY" in head
                nullable = "NOT NULL" not in head
                default = None
                dm = re.search(r"DEFAULT (.*?)(?= CONSTRAINT|$)", rest)
                if dm:
                    default = dm.group(1).strip()
                for part in re.finditer(r"CONSTRAINT (\w+) CHECK", rest):
                    t["checks"].append((part.group(1), readable(check_text(rest[part.start():]))))
                t["cols"].append({"name": cname, "type": ctype.upper(), "null": nullable,
                                  "default": default, "identity": identity})
        tables[name] = t
        order.append(name)
    return tables, order


def parse_triggers(sql):
    return re.findall(r"CREATE TRIGGER (\w+) ON (\w+) AFTER ([A-Z, ]+?) AS", sql)


def parse_indexes(sql):
    return re.findall(r"CREATE UNIQUE INDEX (\w+) ON (\w+) \(([^)]*)\) WHERE ([^;]+);", sql)

# ---------------------------------------------------------------- rendering


def words(name):
    s = re.sub(r"(?<=[a-z])(?=[A-Z])", " ", name)
    s = re.sub(r"(?<=[A-Z])(?=[A-Z][a-z])", " ", s)
    return s.lower()


def esc(s):
    return s.replace("|", "\\|")


def meaning(table, col, t):
    if (table, col) in MEANING_T:
        return MEANING_T[(table, col)]
    if col in MEANING_C:
        return MEANING_C[col]
    for _, cols, tgt, _tc, _c in t["fks"]:
        if cols == [col]:
            return f"Foreign key to {tgt}" + (" (same table)." if tgt == table else ".")
    for _, cols, tgt, _tc, _c in t["fks"]:
        if col in cols:
            return f"Part of the foreign key to {tgt}."
    if col in t["pk"] and len(t["pk"]) == 1:
        return "Primary key."
    w = words(col)
    return w[0].upper() + w[1:] + "."


def key_text(col, t):
    k = []
    if col in t["pk"]:
        k.append("PK")
    for _, cols, tgt, _tc, _c in t["fks"]:
        if col in cols:
            k.append(f"FK {tgt}")
    for _cn, cols in t["uniques"]:
        if col in cols:
            k.append("UQ" if len(cols) == 1 else "UQ(" + ",".join(cols) + ")")
    return ", ".join(dict.fromkeys(k))


def render(tables, order, triggers, indexes):
    known = {n for a in AREAS.values() for n in a}
    if set(order) != known or set(order) != set(PURPOSE):
        sys.exit(f"table lists out of date: not listed={set(order) - known} unknown={known - set(order)} "
                 f"no purpose={set(order) - set(PURPOSE)}")
    area_of = {n: a for a, ns in AREAS.items() for n in ns}
    out = []
    w = out.append
    w("# 20. Data dictionary\n")
    w("[← Back to the menu](../README.md)\n")
    w("> **Status: written. Generated.** This page is produced from [sql/create.sql](../sql/create.sql) by "
      "`python sql/tools/dictionary.py`. Do not edit it by hand: change the script (purposes and column meanings are "
      "dicts at its top) or `create.sql`, then run the script again.\n")
    w(f"The database has **{len(order)} tables**. Reading values (decision B2 in [19-conventions.md](19-conventions.md)): "
      "`RAW_READING.ReceivedValue` is what the meter sent, and for the cumulative code `1.8.0` it is the counter since "
      "installation. `VALIDATED_READING.Value` is the energy in that 15 minutes for cumulative codes and the measured value "
      "for instantaneous codes. Aggregates sum `Value`.\n")
    w("Column table legend: **Null** says whether the column may be empty. **Key** shows PK, FK and UQ (unique). "
      "Defaults, composite keys and checks are listed under each table. Run order and the schema-change process are in "
      "[04-database-schema.md](04-database-schema.md).\n")
    w("## Overview\n")
    w("| Table | Area | Purpose | Rows in base data |")
    w("|---|---|---|---|")
    for n in order:
        w(f"| [`{n}`](#{n.lower()}) | {area_of[n]} | {esc(PURPOSE[n])} | — |")
    w("")
    trg = {}
    for name, tbl, ev in triggers:
        trg.setdefault(tbl, []).append((name, ev))
    idx = {}
    for name, tbl, cols, where in indexes:
        idx.setdefault(tbl, []).append((name, cols, where))
    for area, names in AREAS.items():
        w(f"## Area: {area}\n")
        for n in names:
            t = tables[n]
            w(f"### {n}\n")
            w(PURPOSE[n] + "\n")
            w("| Column | Type | Null | Key | Meaning |")
            w("|---|---|---|---|---|")
            for c in t["cols"]:
                typ = c["type"] + (" IDENTITY" if c["identity"] else "")
                w(f"| `{c['name']}` | {typ} | {'yes' if c['null'] else 'no'} | {key_text(c['name'], t)} | "
                  f"{esc(meaning(n, c['name'], t))} |")
            w("")
            defaults = [(c["name"], c["default"]) for c in t["cols"] if c["default"]]
            if defaults:
                w("- **Defaults:** " + "; ".join(f"`{a}` = `{esc(b)}`" for a, b in defaults))
            if len(t["pk"]) > 1:
                w("- **Primary key:** (" + ", ".join(t["pk"]) + ")")
            for _, cols, tgt, tcols, casc in t["fks"]:
                if len(cols) > 1:
                    w(f"- **Foreign key:** ({', '.join(cols)}) → {tgt} ({', '.join(tcols)})" + (", delete cascades" if casc else ""))
            cc = [", ".join(cols) + f" → {tgt}" for _, cols, tgt, _tc, casc in t["fks"] if casc and len(cols) == 1]
            if cc:
                w("- **Delete cascades:** " + "; ".join(cc))
            for _cn, cols in t["uniques"]:
                if len(cols) > 1:
                    w(f"- **Unique:** ({', '.join(cols)})")
            for cname, cols, where in idx.get(n, []):
                w(f"- **Unique index** `{cname}` on ({cols}) where {where.strip()}: at most one open row.")
            for cname, text in t["checks"]:
                w(f"- **Check** `{cname}`: {esc(text)}")
            for tn, ev in trg.get(n, []):
                w(f"- **Trigger** `{tn}` (after {ev.strip().lower()}): {TRIGGER_TEXT.get(tn, '')}")
            w("")
    return "\n".join(out)


def main():
    sql = SRC.read_text(encoding="utf-8")
    tables, order = parse_tables(sql)
    text = render(tables, order, parse_triggers(sql), parse_indexes(sql))
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {OUT} ({len(order)} tables)")


if __name__ == "__main__":
    main()
