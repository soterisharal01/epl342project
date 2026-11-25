# 04. Database schema

[← Back to the menu](../README.md)

> **Status: partly written.** This page has the Phase B changes and the table map. A full walk-through of every table comes when we go through this component together.

The Phase B schema is [sql/create.sql](../sql/create.sql): **56 tables, 96 foreign keys, 106 CHECKs, 4 triggers,
3 filtered unique indexes**. It came from the Phase A schema (`er-model/create.sql`, left as submitted) through
`sql/tools/step0-from-phase-a.py`. Since then it is edited by hand, and only through the schema-change process
([19-conventions.md](19-conventions.md), section 6).

Run order: `drop.sql` (removes old and new MDMS tables, leaves lab tables) → `create.sql`. Check with
`sql/test-step0.sql` on an empty database: it prints 17 `OK` lines and leaves test rows behind, so run
drop + create again afterwards. Tested on SQL Server 2025 RTM-CU11.

## The professor's 4 changes (meeting of 20/11/2026)

The table count: 62 in Phase A − 7 role tables − `READING` + `RAW_READING` + `VALIDATED_READING` = 56.

### 1. Users: one username = one role

- `USER_ACCOUNT.Role`: Admin, Operator, Consumer, Technician, DSO, TSO, Supplier, Aggregator.
- Removed 7 role tables: `CONSUMER`, `SYSTEM_ADMIN`, `SYSTEM_OPERATOR`, `FIELD_TECHNICIAN`, `MARKET_USER`, `TSO_OPERATOR`, `DSO_OPERATOR`.
  Their few columns became nullable columns of `USER_ACCOUNT`: `RawRetentionMonths`, `CreatedBy`, `BirthDate`, `Photo`,
  `ApprovalStatus`, `ApprovalDecidedAt`, `ApprovedBy`, `SupplierID`, `AggregatorID`. A CHECK per role says which of these must be set and which must be NULL.
- `SUPPLIER` and `AGGREGATOR` stay: they are companies, not roles.
- Every foreign key that pointed to a role table now points to `USER_ACCOUNT(UserID)`. The stored procedure checks the role.
- `UNIQUE (Email)` was dropped, because one person may have two usernames (for example technician and consumer).

### 2. Readings: raw → VEE → validated

- `READING` split in two. `RAW_READING` keeps what arrived, with `VeeStatus` Pending, Validated or Suspect.
  `VALIDATED_READING` keeps what VEE produced, with `Quality` Validated, Estimated or Edited, and the `RunID`.
- `VALIDATED_READING` rows never change. Trigger `TR_VALIDATED_READING_Immutable` rejects every UPDATE, and every DELETE
  unless the retention procedure first ran `EXEC sp_set_session_context N'mdms_purge', 1`.
- `READING_EDIT` records VEE estimates and manual fixes. It points to `METER` and `OBIS_CODE`, because an estimate for a gap has no raw row.
- `METER_AGGREGATE` is computed only from `VALIDATED_READING`.

### 3. Transformers: a strict tree

- `TRANSFORMER.ParentTransformerID` points to the same table. The root has NULL.
- Trigger `TR_TRANSFORMER_Tree`: a parent may not have meters, and no cycles. Trigger `TR_METER_LeafTransformer`: a meter goes only on a leaf.
- `GEOFENCE` lost `ParentGeofenceID` and `Level`. It stays 1:1 with a transformer and takes its hierarchy from the transformer
  tree. This is an assumption; geofences drawn freely on a map are future work.

### 4. Aggregates on transformers

- `GEOFENCE_AGGREGATE` became `TRANSFORMER_AGGREGATE`, stored only for leaves (trigger `TR_TRANSFORMER_AGGREGATE_Leaf`),
  with `PeriodType` Day, Month or Year. The professor said to keep the smallest period we need, because a large period can be built
  from small ones and not the other way round (months give quarters). Day is needed for Day-Ahead data (III.5.2); month and year for reports.
- `GEOFENCE_CURRENT_STATE` became `TRANSFORMER_CURRENT_STATE`, with a row for every node of the tree (B16).
- Higher levels are never stored: they are computed on demand with a recursive CTE over the tree (example: `test-step0.sql`, check 4c).

## Table map by area

| Area | Tables |
|---|---|
| Users and companies | `USER_ACCOUNT`, `SUPPLIER`, `AGGREGATOR`, `CONSUMER_NOTIFICATION_CHANNEL` |
| Geography | `DISTRICT` → `MUNICIPALITY` → `PARISH` |
| Premises and money | `PREMISE`, `SUPPLY_SCHEME`, `HOLDING`, `BANK_ACCOUNT`, `ACCOUNT_FOR`, `CONSUMPTION_THRESHOLD`, `TARIFF_TYPE`, `SUPPLY_CONTRACT`, `INVOICE`, `PAYMENT`, `SERVICE_TYPE`, `SERVICE_PURCHASE`, `SERVICE_REQUEST` |
| Technicians and field work | `TECHNICIAN_CATEGORY`, `IN_CATEGORY`, `DOCUMENT`, `AVAILABILITY`, `AVAILABLE_IN`, `FIELD_TASK`, `TASK_NOTE`, `ATTACHMENT`, `NOTIFIES` |
| Meters and commands | `METER_MODEL`, `COMM_TYPE`, `METER`, `METER_INSTALLATION`, `METER_CONNECTED_PHASE`, `REMOTE_COMMAND`, `COMMAND_ATTEMPT` |
| Telemetry and VEE | `TELEMETRY_PACKET`, `OBIS_CODE`, `RAW_READING`, `VEE_RULE`, `RULE_FOR`, `VEE_RUN`, `VALIDATED_READING`, `READING_EDIT` |
| Aggregates and grid | `METER_AGGREGATE`, `GEOFENCE`, `TRANSFORMER`, `TRANSFORMER_AGGREGATE`, `TRANSFORMER_CURRENT_STATE`, `LOAD_SHED_ORDER` |
| Events | `EVENT`, `LEADS_TO` |
| Market | `PORTFOLIO`, `INCLUDES` |
| Compliance | `GDPR_REQUEST`, `AUDIT_LOG` |

## Things to know when writing procedures

- Filtered unique indexes (one open row at a time): `UX_HOLDING_Open`, `UX_METER_INSTALLATION_Open`, `UX_SUPPLY_CONTRACT_Open`.
  They need `SET QUOTED_IDENTIFIER ON` on every connection that writes (SSMS and the PHP driver set it; `sqlcmd` needs `-I`).
- Trigger error numbers 50001–50006 are used by `create.sql`.
- `TRANSFORMER_CURRENT_STATE.ObisCode` only accepts `1.8.0` and `2.8.0`.
- `REMOTE_COMMAND`: `CommandType = 'Load shed'` if and only if `ShedOrderID` is set.

Phase A history: [phase-a/design-decisions.md](phase-a/design-decisions.md) and [phase-a/README.md](phase-a/README.md).
