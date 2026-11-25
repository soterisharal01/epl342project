# 20. Data dictionary

[← Back to the menu](../README.md)

> **Status: written. Generated.** This page is produced from [sql/create.sql](../sql/create.sql) by `python sql/tools/dictionary.py`. Do not edit it by hand: change the script (purposes and column meanings are dicts at its top) or `create.sql`, then run the script again.

The database has **56 tables**. Reading values (decision B2 in [19-conventions.md](19-conventions.md)): `RAW_READING.ReceivedValue` is what the meter sent, and for the cumulative code `1.8.0` it is the counter since installation. `VALIDATED_READING.Value` is the energy in that 15 minutes for cumulative codes and the measured value for instantaneous codes. Aggregates sum `Value`.

Column table legend: **Null** says whether the column may be empty. **Key** shows PK, FK and UQ (unique). Defaults, composite keys and checks are listed under each table. Run order and the schema-change process are in [04-database-schema.md](04-database-schema.md).

## Overview

| Table | Area | Purpose | Rows in base data |
|---|---|---|---|
| [`SUPPLIER`](#supplier) | Users and companies | An electricity supplier company (a company, not a role); its staff are USER_ACCOUNT rows with Role Supplier. | — |
| [`AGGREGATOR`](#aggregator) | Users and companies | A market aggregator company that manages portfolios of premises; its staff have Role Aggregator. | — |
| [`USER_ACCOUNT`](#user_account) | Users and companies | Every person who logs in; one username has exactly one Role, and the role-specific columns are NULL unless that role needs them. | — |
| [`CONSUMER_NOTIFICATION_CHANNEL`](#consumer_notification_channel) | Users and companies | The channels (Email, SMS) through which a consumer wants to be informed. | — |
| [`DISTRICT`](#district) | Geography | Top level of the administrative geography (Cyprus districts). | — |
| [`MUNICIPALITY`](#municipality) | Geography | Second level of the geography; belongs to one district. | — |
| [`PARISH`](#parish) | Geography | Third level of the geography; belongs to one municipality and is where a premise is located. | — |
| [`SUPPLY_SCHEME`](#supply_scheme) | Premises and money | Lookup of supply schemes a premise can be under. | — |
| [`PREMISE`](#premise) | Premises and money | A supplied property (house, shop, factory, field) with address, coordinates, usage type and supply scheme. | — |
| [`CONSUMPTION_THRESHOLD`](#consumption_threshold) | Premises and money | A consumer's daily or monthly consumption limit for one premise; crossing it triggers a notification. | — |
| [`METER_MODEL`](#meter_model) | Meters and commands | Manufacturer and model of meters, with the number of phases. | — |
| [`COMM_TYPE`](#comm_type) | Meters and commands | Lookup of the communication technology a meter uses. | — |
| [`GEOFENCE`](#geofence) | Aggregates and grid | A rectangular map area, one per transformer; the hierarchy comes from the transformer tree. | — |
| [`TRANSFORMER`](#transformer) | Aggregates and grid | A transformer in a strict tree (root has no parent); meters are attached only to leaves. | — |
| [`METER`](#meter) | Meters and commands | A smart meter device with identifiers, firmware, status and the leaf transformer that serves it. | — |
| [`SERVICE_REQUEST`](#service_request) | Premises and money | A consumer's request for a meter check or a fault report on a premise or meter. | — |
| [`HOLDING`](#holding) | Premises and money | One period in which a consumer holds a premise; at most one open (EndDate NULL) row per consumer and premise. | — |
| [`BANK_ACCOUNT`](#bank_account) | Premises and money | A bank account (IBAN) of a consumer, used to pay invoices. | — |
| [`TARIFF_TYPE`](#tariff_type) | Premises and money | Lookup of tariff types a supply contract can be on. | — |
| [`SUPPLY_CONTRACT`](#supply_contract) | Premises and money | A dated contract between a consumer, a premise and a supplier; decides which supplier may see which customer. | — |
| [`INVOICE`](#invoice) | Premises and money | A bill issued to a consumer for a period, optionally under a supply contract. | — |
| [`PAYMENT`](#payment) | Premises and money | One payment against an invoice, possibly from a stored bank account. | — |
| [`SERVICE_TYPE`](#service_type) | Premises and money | Catalogue of paid additional services with their fee. | — |
| [`SERVICE_PURCHASE`](#service_purchase) | Premises and money | A consumer's purchase of an additional service for a premise, charged on an invoice. | — |
| [`ACCOUNT_FOR`](#account_for) | Premises and money | Many-to-many link saying which premises a bank account pays for. | — |
| [`TECHNICIAN_CATEGORY`](#technician_category) | Technicians and field work | Lookup of technician specialities (categories). | — |
| [`DOCUMENT`](#document) | Technicians and field work | A certificate or ID file owned either by a technician or by a meter, reviewed by an operator. | — |
| [`FIELD_TASK`](#field_task) | Technicians and field work | A job for a technician (installation, replacement, technical or anti-tamper check) at a premise and/or meter. | — |
| [`ATTACHMENT`](#attachment) | Technicians and field work | A file (photo, evidence) uploaded for a field task. | — |
| [`AVAILABILITY`](#availability) | Technicians and field work | One daily time slot a technician declares as available. | — |
| [`TASK_NOTE`](#task_note) | Technicians and field work | Numbered observations and findings a technician writes while doing a task. | — |
| [`IN_CATEGORY`](#in_category) | Technicians and field work | Many-to-many link between technicians and their categories. | — |
| [`AVAILABLE_IN`](#available_in) | Technicians and field work | The municipalities that one availability slot covers. | — |
| [`NOTIFIES`](#notifies) | Technicians and field work | Many-to-many link recording which users are notified about a task. | — |
| [`TELEMETRY_PACKET`](#telemetry_packet) | Telemetry and VEE | Every telemetry packet that reached the DSO endpoint, kept with its ingest result even if it was rejected. | — |
| [`EVENT`](#event) | Events | A network or meter event (alarm, unmatched packet) with severity and handling status. | — |
| [`LEADS_TO`](#leads_to) | Events | Many-to-many link between events and the field tasks they cause. | — |
| [`METER_INSTALLATION`](#meter_installation) | Meters and commands | History of one meter installed at one premise; a replacement closes one row and opens another. | — |
| [`LOAD_SHED_ORDER`](#load_shed_order) | Aggregates and grid | A TSO order to reduce load on a transformer; it groups one command per active meter. | — |
| [`REMOTE_COMMAND`](#remote_command) | Meters and commands | A command sent to a meter (for example load shed or disconnect), with approval and status. | — |
| [`COMMAND_ATTEMPT`](#command_attempt) | Meters and commands | Each numbered try to deliver a remote command and what came back (Timeout, NAK, ACK). | — |
| [`METER_CONNECTED_PHASE`](#meter_connected_phase) | Meters and commands | The phases (L1, L2, L3) a meter is connected to. | — |
| [`OBIS_CODE`](#obis_code) | Telemetry and VEE | Catalogue of measurement types (OBIS codes) with unit, kind and the range VEE accepts. | — |
| [`VEE_RULE`](#vee_rule) | Telemetry and VEE | A configurable validation, estimation or editing rule with JSON parameters. | — |
| [`VEE_RUN`](#vee_run) | Telemetry and VEE | One execution of the VEE process over a period. | — |
| [`RAW_READING`](#raw_reading) | Telemetry and VEE | A 15-minute value exactly as the meter sent it, waiting for or marked by VEE. | — |
| [`VALIDATED_READING`](#validated_reading) | Telemetry and VEE | The final 15-minute value produced by VEE; immutable, and the only source of aggregates. | — |
| [`READING_EDIT`](#reading_edit) | Telemetry and VEE | Audit trail of each VEE estimate and manual correction of a 15-minute value. | — |
| [`RULE_FOR`](#rule_for) | Telemetry and VEE | Many-to-many link saying which OBIS codes a VEE rule applies to. | — |
| [`METER_AGGREGATE`](#meter_aggregate) | Aggregates and grid | Stored daily, monthly or yearly sum of validated readings per meter and OBIS code. | — |
| [`TRANSFORMER_AGGREGATE`](#transformer_aggregate) | Aggregates and grid | Stored Day, Month or Year totals for leaf transformers; upper levels are computed with a recursive query. | — |
| [`TRANSFORMER_CURRENT_STATE`](#transformer_current_state) | Aggregates and grid | Latest 15-minute import (1.8.0) and export (2.8.0) total per leaf transformer. | — |
| [`PORTFOLIO`](#portfolio) | Market | A named group of premises managed by an aggregator. | — |
| [`INCLUDES`](#includes) | Market | Membership of a premise in a portfolio, with its dates. | — |
| [`GDPR_REQUEST`](#gdpr_request) | Compliance | A consumer's erasure request moving through the stages Submitted, Under review, Pre-approved, Approved or Rejected, Applied. | — |
| [`AUDIT_LOG`](#audit_log) | Compliance | Generic dated record of every state change: object type and id, action, actor, old and new state. | — |

## Area: Users and companies

### USER_ACCOUNT

Every person who logs in; one username has exactly one Role, and the role-specific columns are NULL unless that role needs them.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `UserID` | INT IDENTITY | no | PK | Primary key. |
| `Username` | NVARCHAR(50) | no | UQ | Username. |
| `PasswordHash` | VARCHAR(255) | no |  | Hash from PHP password_hash(); the password itself is never stored. |
| `Role` | VARCHAR(10) | no |  | The one role of this username: Admin, Operator, Consumer, Technician, DSO, TSO, Supplier or Aggregator. |
| `Email` | VARCHAR(254) | no |  | E-mail address. |
| `Phone` | VARCHAR(20) | yes |  | Phone number (digits, + and spaces). |
| `FirstName` | NVARCHAR(50) | no |  | First name. |
| `LastName` | NVARCHAR(50) | no |  | Last name. |
| `AccountStatus` | VARCHAR(9) | no |  | Active or Suspended; a suspended account cannot log in. |
| `CreatedAt` | DATETIME2(0) | no |  | When the row was created (UTC). |
| `CreatedBy` | INT | yes | FK USER_ACCOUNT | Admin who created the account (set only when Role is Operator). |
| `RawRetentionMonths` | TINYINT | yes |  | How many months raw readings of this consumer are kept (1 to 36); set for Consumer only. |
| `BirthDate` | DATE | yes |  | Technician only. |
| `Photo` | NVARCHAR(400) | yes |  | Path of the technician's photo; Technician only. |
| `ApprovalStatus` | VARCHAR(9) | yes |  | Technician registration state: Pending, Approved, Rejected or Suspended; NULL for other roles. |
| `ApprovalDecidedAt` | DATETIME2(0) | yes |  | When an operator decided the technician's registration. |
| `ApprovedBy` | INT | yes | FK USER_ACCOUNT | Operator who decided the technician's registration. |
| `SupplierID` | INT | yes | FK SUPPLIER | Company of a Supplier user; NULL for every other role. |
| `AggregatorID` | INT | yes | FK AGGREGATOR | Company of an Aggregator user; NULL for every other role. |

- **Defaults:** `AccountStatus` = `'Active'`; `CreatedAt` = `SYSUTCDATETIME()`
- **Check** `CK_USER_ACCOUNT_Role`: Role is one of 'Admin', 'Operator', 'Consumer', 'Technician', 'DSO', 'TSO', 'Supplier', 'Aggregator'
- **Check** `CK_USER_ACCOUNT_Email`: Email LIKE '%_@_%._%'
- **Check** `CK_USER_ACCOUNT_Phone`: Phone NOT LIKE '%[^0-9+ ]%'
- **Check** `CK_USER_ACCOUNT_AccountStatus`: AccountStatus is one of 'Active', 'Suspended'
- **Check** `CK_USER_ACCOUNT_RawRetentionMonths`: RawRetentionMonths between 1 and 36
- **Check** `CK_USER_ACCOUNT_ApprovalStatus`: ApprovalStatus is one of 'Pending', 'Approved', 'Rejected', 'Suspended'
- **Check** `CK_USER_ACCOUNT_Consumer`: (Role = 'Consumer' AND RawRetentionMonths IS NOT NULL) OR (Role <> 'Consumer' AND RawRetentionMonths IS NULL)
- **Check** `CK_USER_ACCOUNT_Operator`: Role = 'Operator' OR CreatedBy IS NULL
- **Check** `CK_USER_ACCOUNT_Technician`: (Role = 'Technician' AND BirthDate IS NOT NULL AND Photo IS NOT NULL AND ApprovalStatus IS NOT NULL AND ((ApprovalStatus = 'Pending' AND ApprovedBy IS NULL AND ApprovalDecidedAt IS NULL) OR (ApprovalStatus <> 'Pending' AND ApprovedBy IS NOT NULL AND ApprovalDecidedAt IS NOT NULL))) OR (Role <> 'Technician' AND BirthDate IS NULL AND Photo IS NULL AND ApprovalStatus IS NULL AND ApprovalDecidedAt IS NULL AND ApprovedBy IS NULL)
- **Check** `CK_USER_ACCOUNT_Company`: (Role = 'Supplier' AND SupplierID IS NOT NULL AND AggregatorID IS NULL) OR (Role = 'Aggregator' AND AggregatorID IS NOT NULL AND SupplierID IS NULL) OR (Role NOT IN ('Supplier', 'Aggregator') AND SupplierID IS NULL AND AggregatorID IS NULL)

### SUPPLIER

An electricity supplier company (a company, not a role); its staff are USER_ACCOUNT rows with Role Supplier.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `SupplierID` | INT IDENTITY | no | PK | Primary key. |
| `Name` | NVARCHAR(100) | no | UQ | Name. |


### AGGREGATOR

A market aggregator company that manages portfolios of premises; its staff have Role Aggregator.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `AggregatorID` | INT IDENTITY | no | PK | Primary key. |
| `Name` | NVARCHAR(100) | no | UQ | Name. |


### CONSUMER_NOTIFICATION_CHANNEL

The channels (Email, SMS) through which a consumer wants to be informed.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `UserID` | INT | no | PK, FK USER_ACCOUNT | Foreign key to USER_ACCOUNT. |
| `NotificationChannel` | VARCHAR(5) | no | PK | Notification channel. |

- **Primary key:** (UserID, NotificationChannel)
- **Delete cascades:** UserID → USER_ACCOUNT
- **Check** `CK_CONSUMER_NOTIFICATION_CHANNEL_NotificationChannel`: NotificationChannel is one of 'Email', 'SMS'

## Area: Geography

### DISTRICT

Top level of the administrative geography (Cyprus districts).

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `DistrictID` | INT IDENTITY | no | PK | Primary key. |
| `Name` | NVARCHAR(50) | no | UQ | Name. |


### MUNICIPALITY

Second level of the geography; belongs to one district.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `MunicipalityID` | INT IDENTITY | no | PK | Primary key. |
| `Name` | NVARCHAR(100) | no | UQ(DistrictID,Name) | Name. |
| `DistrictID` | INT | no | FK DISTRICT, UQ(DistrictID,Name) | Foreign key to DISTRICT. |

- **Unique:** (DistrictID, Name)

### PARISH

Third level of the geography; belongs to one municipality and is where a premise is located.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `ParishID` | INT IDENTITY | no | PK | Primary key. |
| `Name` | NVARCHAR(100) | no | UQ(MunicipalityID,Name) | Name. |
| `MunicipalityID` | INT | no | FK MUNICIPALITY, UQ(MunicipalityID,Name) | Foreign key to MUNICIPALITY. |

- **Unique:** (MunicipalityID, Name)

## Area: Premises and money

### PREMISE

A supplied property (house, shop, factory, field) with address, coordinates, usage type and supply scheme.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `PremiseID` | INT IDENTITY | no | PK | Primary key. |
| `Address` | NVARCHAR(200) | no |  | Address. |
| `PostalCode` | CHAR(4) | no |  | Postal code. |
| `Latitude` | DECIMAL(9,6) | no |  | Latitude in degrees (-90 to 90). |
| `Longitude` | DECIMAL(9,6) | no |  | Longitude in degrees (-180 to 180). |
| `UsageType` | VARCHAR(12) | no |  | Residential, Commercial, Industrial or Agricultural. |
| `ParishID` | INT | no | FK PARISH | Foreign key to PARISH. |
| `SchemeID` | INT | no | FK SUPPLY_SCHEME | Foreign key to SUPPLY_SCHEME. |

- **Check** `CK_PREMISE_PostalCode`: PostalCode LIKE '[0-9][0-9][0-9][0-9]'
- **Check** `CK_PREMISE_Latitude`: Latitude between -90 and 90
- **Check** `CK_PREMISE_Longitude`: Longitude between -180 and 180
- **Check** `CK_PREMISE_UsageType`: UsageType is one of 'Residential', 'Commercial', 'Industrial', 'Agricultural'

### SUPPLY_SCHEME

Lookup of supply schemes a premise can be under.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `SchemeID` | INT IDENTITY | no | PK | Primary key. |
| `Name` | NVARCHAR(50) | no | UQ | Name. |


### HOLDING

One period in which a consumer holds a premise; at most one open (EndDate NULL) row per consumer and premise.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `UserID` | INT | no | PK, FK USER_ACCOUNT | Foreign key to USER_ACCOUNT. |
| `PremiseID` | INT | no | PK, FK PREMISE | Foreign key to PREMISE. |
| `StartDate` | DATE | no | PK | Start date. |
| `EndDate` | DATE | yes |  | NULL while the consumer still holds the premise (open period). |

- **Primary key:** (UserID, PremiseID, StartDate)
- **Unique index** `UX_HOLDING_Open` on (UserID, PremiseID) where EndDate IS NULL: at most one open row.
- **Check** `CK_HOLDING_Dates`: EndDate IS NULL OR EndDate >= StartDate

### BANK_ACCOUNT

A bank account (IBAN) of a consumer, used to pay invoices.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `BankAccountID` | INT IDENTITY | no | PK | Primary key. |
| `IBAN` | VARCHAR(34) | no | UQ | International bank account number. |
| `HolderName` | NVARCHAR(100) | no |  | Name of the account holder. |
| `UserID` | INT | yes | FK USER_ACCOUNT | Foreign key to USER_ACCOUNT. |

- **Check** `CK_BANK_ACCOUNT_IBAN`: IBAN LIKE '[A-Z][A-Z][0-9][0-9]%' AND IBAN NOT LIKE '%[^A-Z0-9]%' AND LEN(IBAN) BETWEEN 15 AND 34

### ACCOUNT_FOR

Many-to-many link saying which premises a bank account pays for.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `BankAccountID` | INT | no | PK, FK BANK_ACCOUNT | Foreign key to BANK_ACCOUNT. |
| `PremiseID` | INT | no | PK, FK PREMISE | Foreign key to PREMISE. |

- **Primary key:** (BankAccountID, PremiseID)
- **Delete cascades:** BankAccountID → BANK_ACCOUNT; PremiseID → PREMISE

### CONSUMPTION_THRESHOLD

A consumer's daily or monthly consumption limit for one premise; crossing it triggers a notification.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `ThresholdID` | INT IDENTITY | no | PK | Primary key. |
| `LimitKWh` | DECIMAL(12,3) | no |  | The limit in kWh for the PeriodType. |
| `PeriodType` | VARCHAR(5) | no |  | Period the row covers. |
| `IsActive` | BIT | no |  | 1 = in use, 0 = switched off. |
| `UserID` | INT | no | FK USER_ACCOUNT | Consumer who set the threshold. |
| `PremiseID` | INT | no | FK PREMISE | Foreign key to PREMISE. |

- **Defaults:** `IsActive` = `1`
- **Check** `CK_CONSUMPTION_THRESHOLD_LimitKWh`: LimitKWh > 0
- **Check** `CK_CONSUMPTION_THRESHOLD_PeriodType`: PeriodType is one of 'Day', 'Month'

### TARIFF_TYPE

Lookup of tariff types a supply contract can be on.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `TariffTypeID` | INT IDENTITY | no | PK | Primary key. |
| `Name` | NVARCHAR(100) | no | UQ | Name. |


### SUPPLY_CONTRACT

A dated contract between a consumer, a premise and a supplier; decides which supplier may see which customer.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `ContractID` | INT IDENTITY | no | PK | Primary key. |
| `StartDate` | DATE | no |  | Start date. |
| `EndDate` | DATE | yes |  | NULL while the contract is active; one open contract per premise. |
| `UserID` | INT | no | FK USER_ACCOUNT | The consumer who signed the contract. |
| `PremiseID` | INT | no | FK PREMISE | Foreign key to PREMISE. |
| `SupplierID` | INT | no | FK SUPPLIER | Foreign key to SUPPLIER. |
| `TariffTypeID` | INT | yes | FK TARIFF_TYPE | Foreign key to TARIFF_TYPE. |

- **Unique index** `UX_SUPPLY_CONTRACT_Open` on (PremiseID) where EndDate IS NULL: at most one open row.
- **Check** `CK_SUPPLY_CONTRACT_Dates`: EndDate IS NULL OR EndDate >= StartDate

### INVOICE

A bill issued to a consumer for a period, optionally under a supply contract.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `InvoiceID` | INT IDENTITY | no | PK | Primary key. |
| `IssueDate` | DATE | no |  | Issue date. |
| `PeriodFrom` | DATE | no |  | Period from. |
| `PeriodTo` | DATE | no |  | Period to. |
| `Amount` | DECIMAL(12,2) | no |  | Total to pay in euro. |
| `Status` | VARCHAR(14) | no |  | Issued, Partially paid, Paid or Cancelled. |
| `UserID` | INT | no | FK USER_ACCOUNT | Consumer the invoice is issued to. |
| `ContractID` | INT | yes | FK SUPPLY_CONTRACT | Foreign key to SUPPLY_CONTRACT. |

- **Defaults:** `Status` = `'Issued'`
- **Check** `CK_INVOICE_Amount`: Amount >= 0
- **Check** `CK_INVOICE_Status`: Status is one of 'Issued', 'Partially paid', 'Paid', 'Cancelled'
- **Check** `CK_INVOICE_Period`: PeriodFrom <= PeriodTo

### PAYMENT

One payment against an invoice, possibly from a stored bank account.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `PaymentID` | INT IDENTITY | no | PK | Primary key. |
| `Amount` | DECIMAL(12,2) | no |  | Amount. |
| `PaidAt` | DATETIME2(0) | no |  | Paid at. |
| `Reference` | NVARCHAR(50) | yes |  | Reference. |
| `InvoiceID` | INT | no | FK INVOICE | Foreign key to INVOICE. |
| `BankAccountID` | INT | yes | FK BANK_ACCOUNT | Foreign key to BANK_ACCOUNT. |

- **Check** `CK_PAYMENT_Amount`: Amount > 0

### SERVICE_TYPE

Catalogue of paid additional services with their fee.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `ServiceTypeID` | INT IDENTITY | no | PK | Primary key. |
| `Name` | NVARCHAR(100) | no | UQ | Name. |
| `Fee` | DECIMAL(10,2) | no |  | Price of the service in euro. |

- **Check** `CK_SERVICE_TYPE_Fee`: Fee >= 0

### SERVICE_PURCHASE

A consumer's purchase of an additional service for a premise, charged on an invoice.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `PurchaseID` | INT IDENTITY | no | PK | Primary key. |
| `MonthFrom` | DATE | yes |  | First month of the service (first day of the month); NULL for one-off services. |
| `MonthTo` | DATE | yes |  | Last month of the service (first day of the month). |
| `PurchasedAt` | DATETIME2(0) | no |  | Purchased at. |
| `Amount` | DECIMAL(10,2) | no |  | Amount. |
| `ServiceTypeID` | INT | no | FK SERVICE_TYPE | Foreign key to SERVICE_TYPE. |
| `PremiseID` | INT | no | FK PREMISE | Foreign key to PREMISE. |
| `InvoiceID` | INT | no | FK INVOICE | Foreign key to INVOICE. |

- **Defaults:** `PurchasedAt` = `SYSUTCDATETIME()`
- **Check** `CK_SERVICE_PURCHASE_Amount`: Amount >= 0
- **Check** `CK_SERVICE_PURCHASE_Months`: (MonthFrom IS NULL AND MonthTo IS NULL) OR (MonthFrom IS NOT NULL AND MonthTo IS NOT NULL AND DAY(MonthFrom) = 1 AND DAY(MonthTo) = 1 AND MonthFrom <= MonthTo)

### SERVICE_REQUEST

A consumer's request for a meter check or a fault report on a premise or meter.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `RequestID` | INT IDENTITY | no | PK | Primary key. |
| `RequestType` | VARCHAR(12) | no |  | Request type. |
| `Description` | NVARCHAR(1000) | no |  | Description. |
| `Status` | VARCHAR(9) | no |  | Submitted, Assigned, Resolved or Cancelled. |
| `SubmittedAt` | DATETIME2(0) | no |  | Submitted at. |
| `UserID` | INT | no | FK USER_ACCOUNT | Consumer who submitted the request. |
| `PremiseID` | INT | no | FK PREMISE | Foreign key to PREMISE. |
| `MeterID` | INT | yes | FK METER | Foreign key to METER. |

- **Defaults:** `Status` = `'Submitted'`; `SubmittedAt` = `SYSUTCDATETIME()`
- **Check** `CK_SERVICE_REQUEST_RequestType`: RequestType is one of 'Meter check', 'Fault report'
- **Check** `CK_SERVICE_REQUEST_Status`: Status is one of 'Submitted', 'Assigned', 'Resolved', 'Cancelled'

## Area: Technicians and field work

### TECHNICIAN_CATEGORY

Lookup of technician specialities (categories).

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `CategoryID` | INT IDENTITY | no | PK | Primary key. |
| `Name` | NVARCHAR(100) | no | UQ | Name. |


### IN_CATEGORY

Many-to-many link between technicians and their categories.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `UserID` | INT | no | PK, FK USER_ACCOUNT | Foreign key to USER_ACCOUNT. |
| `CategoryID` | INT | no | PK, FK TECHNICIAN_CATEGORY | Foreign key to TECHNICIAN_CATEGORY. |

- **Primary key:** (UserID, CategoryID)
- **Delete cascades:** UserID → USER_ACCOUNT; CategoryID → TECHNICIAN_CATEGORY

### DOCUMENT

A certificate or ID file owned either by a technician or by a meter, reviewed by an operator.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `DocumentID` | INT IDENTITY | no | PK | Primary key. |
| `DocType` | VARCHAR(27) | no |  | Doc type. |
| `DocNumber` | NVARCHAR(50) | no |  | Doc number. |
| `IssueDate` | DATE | no |  | Issue date. |
| `ExpiryDate` | DATE | yes |  | Expiry date. |
| `FilePath` | NVARCHAR(400) | no |  | Where the uploaded file is stored. |
| `ReviewStatus` | VARCHAR(8) | no |  | Pending, Accepted or Rejected. |
| `ReviewComment` | NVARCHAR(500) | yes |  | Review comment. |
| `ReviewedAt` | DATETIME2(0) | yes |  | Reviewed at. |
| `TechnicianID` | INT | yes | FK USER_ACCOUNT | Owner when the document belongs to a technician (ID card, licence, training); exactly one of TechnicianID and MeterID is set. |
| `MeterID` | INT | yes | FK METER | Owner when the document belongs to a meter (calibration, CE, encryption certificate). |
| `ReviewedBy` | INT | yes | FK USER_ACCOUNT | Operator who reviewed the document. |

- **Defaults:** `ReviewStatus` = `'Pending'`
- **Check** `CK_DOCUMENT_DocType`: DocType is one of 'ID card', 'Installer licence', 'Training certificate', 'Calibration certificate', 'CE and protocol declaration', 'Encryption certificate'
- **Check** `CK_DOCUMENT_ReviewStatus`: ReviewStatus is one of 'Pending', 'Accepted', 'Rejected'
- **Check** `CK_DOCUMENT_Owner`: (TechnicianID IS NOT NULL AND MeterID IS NULL AND DocType IN ('ID card', 'Installer licence', 'Training certificate')) OR (TechnicianID IS NULL AND MeterID IS NOT NULL AND DocType IN ('Calibration certificate', 'CE and protocol declaration', 'Encryption certificate'))
- **Check** `CK_DOCUMENT_Expiry`: ExpiryDate IS NULL OR ExpiryDate > IssueDate
- **Check** `CK_DOCUMENT_Review`: (ReviewStatus = 'Pending' AND ReviewedBy IS NULL AND ReviewedAt IS NULL) OR (ReviewStatus <> 'Pending' AND ReviewedBy IS NOT NULL AND ReviewedAt IS NOT NULL)

### AVAILABILITY

One daily time slot a technician declares as available.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `UserID` | INT | no | PK, FK USER_ACCOUNT | The technician who declared the slot. |
| `AvailDate` | DATE | no | PK | Avail date. |
| `FromTime` | TIME(0) | no | PK | From time. |
| `ToTime` | TIME(0) | no |  | To time. |

- **Primary key:** (UserID, AvailDate, FromTime)
- **Delete cascades:** UserID → USER_ACCOUNT
- **Check** `CK_AVAILABILITY_Slot`: ToTime > FromTime

### AVAILABLE_IN

The municipalities that one availability slot covers.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `UserID` | INT | no | PK, FK AVAILABILITY | Part of the foreign key to AVAILABILITY. |
| `AvailDate` | DATE | no | PK, FK AVAILABILITY | Part of the foreign key to AVAILABILITY. |
| `FromTime` | TIME(0) | no | PK, FK AVAILABILITY | Part of the foreign key to AVAILABILITY. |
| `MunicipalityID` | INT | no | PK, FK MUNICIPALITY | Foreign key to MUNICIPALITY. |

- **Primary key:** (UserID, AvailDate, FromTime, MunicipalityID)
- **Foreign key:** (UserID, AvailDate, FromTime) → AVAILABILITY (UserID, AvailDate, FromTime), delete cascades
- **Delete cascades:** MunicipalityID → MUNICIPALITY

### FIELD_TASK

A job for a technician (installation, replacement, technical or anti-tamper check) at a premise and/or meter.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `TaskID` | INT IDENTITY | no | PK | Primary key. |
| `TaskType` | VARCHAR(17) | no |  | Task type. |
| `ScheduledFrom` | DATETIME2(0) | no |  | Scheduled from. |
| `ScheduledTo` | DATETIME2(0) | no |  | Scheduled to. |
| `Status` | VARCHAR(9) | no |  | Assigned, Accepted, Done or Cancelled. |
| `Result` | NVARCHAR(1000) | yes |  | Outcome written by the technician; required when Status is Done. |
| `CreatedAt` | DATETIME2(0) | no |  | When the row was created (UTC). |
| `CompletedAt` | DATETIME2(0) | yes |  | Completed at. |
| `TechnicianID` | INT | no | FK USER_ACCOUNT | The technician (USER_ACCOUNT with Role Technician) the task is assigned to. |
| `PremiseID` | INT | yes | FK PREMISE | Foreign key to PREMISE. |
| `MeterID` | INT | yes | FK METER | Foreign key to METER. |
| `RequestID` | INT | yes | FK SERVICE_REQUEST | Service request this task resolves, if any. |

- **Defaults:** `Status` = `'Assigned'`; `CreatedAt` = `SYSUTCDATETIME()`
- **Check** `CK_FIELD_TASK_TaskType`: TaskType is one of 'Installation', 'Replacement', 'Technical check', 'Anti-tamper check'
- **Check** `CK_FIELD_TASK_Status`: Status is one of 'Assigned', 'Accepted', 'Done', 'Cancelled'
- **Check** `CK_FIELD_TASK_Schedule`: ScheduledTo > ScheduledFrom
- **Check** `CK_FIELD_TASK_Done`: (Status = 'Done' AND CompletedAt IS NOT NULL AND Result IS NOT NULL) OR (Status <> 'Done' AND CompletedAt IS NULL)
- **Check** `CK_FIELD_TASK_Target`: PremiseID IS NOT NULL OR MeterID IS NOT NULL
- **Check** `CK_FIELD_TASK_Install`: (TaskType NOT IN ('Installation', 'Replacement') OR PremiseID IS NOT NULL) AND (TaskType <> 'Installation' OR MeterID IS NULL) AND (TaskType <> 'Replacement' OR MeterID IS NOT NULL)

### TASK_NOTE

Numbered observations and findings a technician writes while doing a task.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `TaskID` | INT | no | PK, FK FIELD_TASK | Foreign key to FIELD_TASK. |
| `NoteNo` | SMALLINT | no | PK | Number of the note within its task (1, 2, 3...). |
| `NoteKind` | VARCHAR(11) | no |  | Observation or Finding. |
| `Text` | NVARCHAR(2000) | no |  | Text. |
| `WrittenAt` | DATETIME2(0) | no |  | Written at. |
| `WrittenBy` | INT | no | FK USER_ACCOUNT | Foreign key to USER_ACCOUNT. |

- **Defaults:** `WrittenAt` = `SYSUTCDATETIME()`
- **Primary key:** (TaskID, NoteNo)
- **Delete cascades:** TaskID → FIELD_TASK
- **Check** `CK_TASK_NOTE_NoteNo`: NoteNo >= 1
- **Check** `CK_TASK_NOTE_NoteKind`: NoteKind is one of 'Observation', 'Finding'

### ATTACHMENT

A file (photo, evidence) uploaded for a field task.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `AttachmentID` | INT IDENTITY | no | PK | Primary key. |
| `FilePath` | NVARCHAR(400) | no |  | File path. |
| `Caption` | NVARCHAR(200) | yes |  | Caption. |
| `UploadedAt` | DATETIME2(0) | no |  | Uploaded at. |
| `TaskID` | INT | no | FK FIELD_TASK | Foreign key to FIELD_TASK. |

- **Defaults:** `UploadedAt` = `SYSUTCDATETIME()`

### NOTIFIES

Many-to-many link recording which users are notified about a task.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `TaskID` | INT | no | PK, FK FIELD_TASK | Foreign key to FIELD_TASK. |
| `UserID` | INT | no | PK, FK USER_ACCOUNT | Foreign key to USER_ACCOUNT. |

- **Primary key:** (TaskID, UserID)
- **Delete cascades:** TaskID → FIELD_TASK; UserID → USER_ACCOUNT

## Area: Meters and commands

### METER_MODEL

Manufacturer and model of meters, with the number of phases.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `ModelID` | INT IDENTITY | no | PK | Primary key. |
| `Manufacturer` | NVARCHAR(100) | no | UQ(Manufacturer,ModelName) | Manufacturer. |
| `ModelName` | NVARCHAR(100) | no | UQ(Manufacturer,ModelName) | Model name. |
| `MeterType` | VARCHAR(30) | no |  | Meter type. |
| `PhaseCount` | TINYINT | no |  | Phase count. |

- **Unique:** (Manufacturer, ModelName)
- **Check** `CK_METER_MODEL_PhaseCount`: PhaseCount between 1 and 3

### COMM_TYPE

Lookup of the communication technology a meter uses.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `CommTypeID` | INT IDENTITY | no | PK | Primary key. |
| `Name` | NVARCHAR(30) | no | UQ | Name. |


### METER

A smart meter device with identifiers, firmware, status and the leaf transformer that serves it.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `MeterID` | INT IDENTITY | no | PK | Primary key. |
| `SerialNumber` | VARCHAR(40) | no | UQ | Serial number. |
| `NetworkID` | VARCHAR(40) | no | UQ | Identifier the meter puts in its telemetry packets; used to match a packet to the meter. |
| `Firmware` | VARCHAR(30) | no |  | Firmware. |
| `MaxLoadAmps` | DECIMAL(6,1) | no |  | Maximum load the meter supports, in amperes. |
| `Latitude` | DECIMAL(9,6) | no |  | Latitude in degrees (-90 to 90). |
| `Longitude` | DECIMAL(9,6) | no |  | Longitude in degrees (-180 to 180). |
| `Status` | VARCHAR(20) | no |  | Pending confirmation, Active or Retired; only Active meters accept telemetry and commands. |
| `ModelID` | INT | no | FK METER_MODEL | Foreign key to METER_MODEL. |
| `CommTypeID` | INT | no | FK COMM_TYPE | Foreign key to COMM_TYPE. |
| `TransformerID` | INT | no | FK TRANSFORMER | Leaf transformer that serves this meter. |

- **Defaults:** `Status` = `'Pending confirmation'`
- **Check** `CK_METER_MaxLoadAmps`: MaxLoadAmps > 0
- **Check** `CK_METER_Latitude`: Latitude between -90 and 90
- **Check** `CK_METER_Longitude`: Longitude between -180 and 180
- **Check** `CK_METER_Status`: Status is one of 'Pending confirmation', 'Active', 'Retired'
- **Trigger** `TR_METER_LeafTransformer` (after insert, update): Error 50003: a meter may be attached only to a transformer that has no children.

### METER_INSTALLATION

History of one meter installed at one premise; a replacement closes one row and opens another.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `InstallationID` | INT IDENTITY | no | PK | Primary key. |
| `InstalledAt` | DATETIME2(0) | no |  | Installed at. |
| `RemovedAt` | DATETIME2(0) | yes |  | NULL while the meter is still installed (open row); one open installation per meter. |
| `ConfirmationStatus` | VARCHAR(9) | no |  | Pending, Confirmed or Rejected; an operator confirms the technician's installation. |
| `ConfirmedAt` | DATETIME2(0) | yes |  | Confirmed at. |
| `ConfirmComment` | NVARCHAR(500) | yes |  | Confirm comment. |
| `MeterID` | INT | no | FK METER | Foreign key to METER. |
| `PremiseID` | INT | no | FK PREMISE | Foreign key to PREMISE. |
| `ConfirmedBy` | INT | yes | FK USER_ACCOUNT | Operator who confirmed or rejected. |
| `TaskID` | INT | no | FK FIELD_TASK, UQ | The installation or replacement task that created this row. |

- **Defaults:** `ConfirmationStatus` = `'Pending'`
- **Unique index** `UX_METER_INSTALLATION_Open` on (MeterID) where RemovedAt IS NULL: at most one open row.
- **Check** `CK_METER_INSTALLATION_ConfirmationStatus`: ConfirmationStatus is one of 'Pending', 'Confirmed', 'Rejected'
- **Check** `CK_METER_INSTALLATION_Removed`: RemovedAt IS NULL OR RemovedAt > InstalledAt
- **Check** `CK_METER_INSTALLATION_Confirmation`: (ConfirmationStatus = 'Pending' AND ConfirmedBy IS NULL AND ConfirmedAt IS NULL) OR (ConfirmationStatus <> 'Pending' AND ConfirmedBy IS NOT NULL AND ConfirmedAt IS NOT NULL)

### METER_CONNECTED_PHASE

The phases (L1, L2, L3) a meter is connected to.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `MeterID` | INT | no | PK, FK METER | Foreign key to METER. |
| `ConnectedPhase` | CHAR(2) | no | PK | Connected phase. |

- **Primary key:** (MeterID, ConnectedPhase)
- **Delete cascades:** MeterID → METER
- **Check** `CK_METER_CONNECTED_PHASE_ConnectedPhase`: ConnectedPhase is one of 'L1', 'L2', 'L3'

### REMOTE_COMMAND

A command sent to a meter (for example load shed or disconnect), with approval and status.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `CommandID` | INT IDENTITY | no | PK | Primary key. |
| `CommandType` | VARCHAR(30) | no |  | Kind of command; 'Load shed' exactly when ShedOrderID is set. |
| `Parameters` | NVARCHAR(1000) | yes |  | JSON with the command's parameters. |
| `RequestedAt` | DATETIME2(0) | no |  | Requested at. |
| `Status` | VARCHAR(17) | no |  | Awaiting approval, Sent, Acknowledged, Failed or Cancelled. |
| `MeterID` | INT | no | FK METER | Foreign key to METER. |
| `RequestedBy` | INT | no | FK USER_ACCOUNT | User who asked for the command. |
| `ApprovedBy` | INT | yes | FK USER_ACCOUNT | User who approved it; must be NULL while Status is Awaiting approval. |
| `ShedOrderID` | INT | yes | FK LOAD_SHED_ORDER | Load-shed order this command belongs to; NULL for ordinary commands. |

- **Defaults:** `RequestedAt` = `SYSUTCDATETIME()`
- **Check** `CK_REMOTE_COMMAND_Parameters`: ISJSON(Parameters) = 1
- **Check** `CK_REMOTE_COMMAND_Status`: Status is one of 'Awaiting approval', 'Sent', 'Acknowledged', 'Failed', 'Cancelled'
- **Check** `CK_REMOTE_COMMAND_ShedOrder`: (CommandType = 'Load shed' AND ShedOrderID IS NOT NULL) OR (CommandType <> 'Load shed' AND ShedOrderID IS NULL)
- **Check** `CK_REMOTE_COMMAND_Approval`: NOT (Status = 'Awaiting approval' AND ApprovedBy IS NOT NULL)

### COMMAND_ATTEMPT

Each numbered try to deliver a remote command and what came back (Timeout, NAK, ACK).

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `CommandID` | INT | no | PK, FK REMOTE_COMMAND | Foreign key to REMOTE_COMMAND. |
| `AttemptNo` | SMALLINT | no | PK | Number of the try within the command (1, 2, 3...). |
| `AttemptAt` | DATETIME2(3) | no |  | Attempt at. |
| `RespondedAt` | DATETIME2(3) | yes |  | When the meter answered; set only for NAK and ACK. |
| `Outcome` | VARCHAR(7) | yes |  | Timeout, NAK or ACK; NULL while waiting. |

- **Primary key:** (CommandID, AttemptNo)
- **Delete cascades:** CommandID → REMOTE_COMMAND
- **Check** `CK_COMMAND_ATTEMPT_AttemptNo`: AttemptNo >= 1
- **Check** `CK_COMMAND_ATTEMPT_Outcome`: Outcome is one of 'Timeout', 'NAK', 'ACK'
- **Check** `CK_COMMAND_ATTEMPT_Response`: ((Outcome IS NULL OR Outcome = 'Timeout') AND RespondedAt IS NULL) OR (Outcome IN ('NAK', 'ACK') AND RespondedAt IS NOT NULL AND RespondedAt >= AttemptAt)

## Area: Telemetry and VEE

### TELEMETRY_PACKET

Every telemetry packet that reached the DSO endpoint, kept with its ingest result even if it was rejected.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `PacketID` | BIGINT IDENTITY | no | PK | Primary key. |
| `ReceivedNetworkID` | VARCHAR(40) | yes |  | Network id as written in the packet, before matching to a meter. |
| `TransmissionTimestamp` | DATETIME2(0) | yes |  | Time the meter says it sent the packet. |
| `ReceivedAt` | DATETIME2(3) | no |  | Time the server received it. |
| `NetworkType` | VARCHAR(20) | yes |  | Network the packet came over, as reported by the meter. |
| `SignalDbm` | SMALLINT | yes |  | Signal strength in dBm (-150 to 0). |
| `RawPayload` | NVARCHAR(MAX) | no |  | The packet exactly as received (JSON text). |
| `IngestStatus` | VARCHAR(18) | no |  | Accepted, Partially accepted, Unknown meter, Meter not active or Malformed. |
| `ErrorMessage` | NVARCHAR(1000) | yes |  | Why the packet was (partly) rejected; required for Partially accepted and Malformed. |
| `MeterID` | INT | yes | FK METER | Meter the packet was matched to; NULL for Unknown meter or Malformed. |

- **Defaults:** `ReceivedAt` = `SYSUTCDATETIME()`
- **Check** `CK_TELEMETRY_PACKET_SignalDbm`: SignalDbm between -150 and 0
- **Check** `CK_TELEMETRY_PACKET_IngestStatus`: IngestStatus is one of 'Accepted', 'Partially accepted', 'Unknown meter', 'Meter not active', 'Malformed'
- **Check** `CK_TELEMETRY_PACKET_Meter`: (IngestStatus IN ('Accepted', 'Partially accepted', 'Meter not active') AND MeterID IS NOT NULL) OR (IngestStatus = 'Unknown meter' AND MeterID IS NULL) OR IngestStatus = 'Malformed'
- **Check** `CK_TELEMETRY_PACKET_Error`: IngestStatus NOT IN ('Partially accepted', 'Malformed') OR ErrorMessage IS NOT NULL

### OBIS_CODE

Catalogue of measurement types (OBIS codes) with unit, kind and the range VEE accepts.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `ObisCode` | VARCHAR(20) | no | PK | The code itself, for example 1.8.0 (import energy) or 2.8.0 (export energy). |
| `Description` | NVARCHAR(200) | no |  | Description. |
| `Unit` | VARCHAR(10) | no |  | Unit. |
| `Kind` | VARCHAR(19) | no |  | Cumulative register (counter that only grows) or Instantaneous (voltage, current). |
| `Phase` | CHAR(2) | yes |  | L1, L2 or L3 for per-phase codes; NULL otherwise. |
| `MinValid` | DECIMAL(15,4) | yes |  | Lowest value VEE accepts for this code (NULL = no limit). |
| `MaxValid` | DECIMAL(15,4) | yes |  | Highest value VEE accepts for this code (NULL = no limit). |

- **Check** `CK_OBIS_CODE_Kind`: Kind is one of 'Cumulative register', 'Instantaneous'
- **Check** `CK_OBIS_CODE_Phase`: Phase is one of 'L1', 'L2', 'L3'
- **Check** `CK_OBIS_CODE_Range`: MinValid IS NULL OR MaxValid IS NULL OR MinValid < MaxValid

### RAW_READING

A 15-minute value exactly as the meter sent it, waiting for or marked by VEE.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `MeterID` | INT | no | PK, FK METER | Foreign key to METER. |
| `ObisCode` | VARCHAR(20) | no | PK, FK OBIS_CODE | OBIS code of the measurement (foreign key to OBIS_CODE). |
| `IntervalStart` | DATETIME2(0) | no | PK | Start of the 15-minute interval (minute 0, 15, 30 or 45, seconds 0). |
| `ReceivedValue` | DECIMAL(15,4) | no |  | What the meter sent (decision B2); for 1.8.0 this is the counter since installation, not the 15-minute energy. |
| `VeeStatus` | VARCHAR(9) | no |  | Pending (not yet checked), Validated or Suspect (failed a VEE rule). |
| `PacketID` | BIGINT | no | FK TELEMETRY_PACKET | Packet that carried this value. |

- **Defaults:** `VeeStatus` = `'Pending'`
- **Primary key:** (MeterID, ObisCode, IntervalStart)
- **Check** `CK_RAW_READING_IntervalStart`: DATEPART(MINUTE, IntervalStart) % 15 = 0 AND DATEPART(SECOND, IntervalStart) = 0
- **Check** `CK_RAW_READING_VeeStatus`: VeeStatus is one of 'Pending', 'Validated', 'Suspect'

### VEE_RULE

A configurable validation, estimation or editing rule with JSON parameters.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `RuleID` | INT IDENTITY | no | PK | Primary key. |
| `RuleType` | VARCHAR(30) | no |  | Kind of rule (for example range, spike, gap, estimation method). |
| `Parameters` | NVARCHAR(1000) | yes |  | JSON with the rule's thresholds; changing it changes VEE behaviour with no code change. |
| `IsActive` | BIT | no |  | Inactive rules are skipped by VEE. |

- **Defaults:** `IsActive` = `1`
- **Check** `CK_VEE_RULE_Parameters`: ISJSON(Parameters) = 1

### RULE_FOR

Many-to-many link saying which OBIS codes a VEE rule applies to.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `RuleID` | INT | no | PK, FK VEE_RULE | Foreign key to VEE_RULE. |
| `ObisCode` | VARCHAR(20) | no | PK, FK OBIS_CODE | OBIS code of the measurement (foreign key to OBIS_CODE). |

- **Primary key:** (RuleID, ObisCode)
- **Delete cascades:** RuleID → VEE_RULE; ObisCode → OBIS_CODE

### VEE_RUN

One execution of the VEE process over a period.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `RunID` | INT IDENTITY | no | PK | Primary key. |
| `PeriodFrom` | DATETIME2(0) | no |  | Start of the period the run processed. |
| `PeriodTo` | DATETIME2(0) | no |  | End of the period the run processed. |
| `StartedAt` | DATETIME2(0) | no |  | Started at. |
| `FinishedAt` | DATETIME2(0) | yes |  | NULL while the run is still going. |

- **Defaults:** `StartedAt` = `SYSUTCDATETIME()`
- **Check** `CK_VEE_RUN_Period`: PeriodTo > PeriodFrom AND (FinishedAt IS NULL OR FinishedAt >= StartedAt)

### VALIDATED_READING

The final 15-minute value produced by VEE; immutable, and the only source of aggregates.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `MeterID` | INT | no | PK, FK METER | Foreign key to METER. |
| `ObisCode` | VARCHAR(20) | no | PK, FK OBIS_CODE | OBIS code of the measurement (foreign key to OBIS_CODE). |
| `IntervalStart` | DATETIME2(0) | no | PK | Start of the 15-minute interval. |
| `Value` | DECIMAL(15,4) | no |  | Energy in that 15 minutes for cumulative codes (difference from the previous interval), or the measured value for instantaneous codes (decision B2). |
| `Quality` | VARCHAR(9) | no |  | Validated (passed all rules), Estimated (VEE filled it) or Edited (changed by hand). |
| `RunID` | INT | no | FK VEE_RUN | VEE run that made this reading final. |
| `ValidatedAt` | DATETIME2(0) | no |  | When the row was written; the row never changes afterwards (trigger). |

- **Defaults:** `ValidatedAt` = `SYSUTCDATETIME()`
- **Primary key:** (MeterID, ObisCode, IntervalStart)
- **Check** `CK_VALIDATED_READING_IntervalStart`: DATEPART(MINUTE, IntervalStart) % 15 = 0 AND DATEPART(SECOND, IntervalStart) = 0
- **Check** `CK_VALIDATED_READING_Quality`: Quality is one of 'Validated', 'Estimated', 'Edited'
- **Trigger** `TR_VALIDATED_READING_Immutable` (after update, delete): Error 50005: UPDATE is always rejected. Error 50006: DELETE is rejected unless the retention procedure set session context mdms_purge = 1.

### READING_EDIT

Audit trail of each VEE estimate and manual correction of a 15-minute value.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `MeterID` | INT | no | PK, FK METER | Foreign key to METER. |
| `ObisCode` | VARCHAR(20) | no | PK, FK OBIS_CODE | OBIS code of the measurement (foreign key to OBIS_CODE). |
| `IntervalStart` | DATETIME2(0) | no | PK | Start of the 15-minute interval. |
| `EditNo` | SMALLINT | no | PK | Number of the edit for this meter, code and interval (1, 2, ...). |
| `OldValue` | DECIMAL(15,4) | yes |  | Value before the edit; NULL when the slot had no value (a gap). |
| `NewValue` | DECIMAL(15,4) | no |  | Value after the edit. |
| `Origin` | VARCHAR(18) | no |  | Automatic estimate (VEE rule), Manual estimate or Manual edit (DSO staff). |
| `EditedAt` | DATETIME2(0) | no |  | Edited at. |
| `Reason` | NVARCHAR(500) | yes |  | Reason. |
| `EditedBy` | INT | yes | FK USER_ACCOUNT | DSO user for manual origins; NULL for automatic estimates. |
| `RuleID` | INT | yes | FK VEE_RULE | VEE rule that produced an automatic estimate. |

- **Defaults:** `EditedAt` = `SYSUTCDATETIME()`
- **Primary key:** (MeterID, ObisCode, IntervalStart, EditNo)
- **Check** `CK_READING_EDIT_EditNo`: EditNo >= 1
- **Check** `CK_READING_EDIT_Origin`: Origin is one of 'Automatic estimate', 'Manual estimate', 'Manual edit'
- **Check** `CK_READING_EDIT_OriginActor`: (Origin = 'Automatic estimate' AND EditedBy IS NULL AND RuleID IS NOT NULL) OR (Origin = 'Manual estimate' AND EditedBy IS NOT NULL) OR (Origin = 'Manual edit' AND EditedBy IS NOT NULL AND RuleID IS NULL)

## Area: Aggregates and grid

### METER_AGGREGATE

Stored daily, monthly or yearly sum of validated readings per meter and OBIS code.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `MeterID` | INT | no | PK, FK METER | Foreign key to METER. |
| `ObisCode` | VARCHAR(20) | no | PK, FK OBIS_CODE | OBIS code of the measurement (foreign key to OBIS_CODE). |
| `PeriodType` | VARCHAR(5) | no | PK | Day, Month or Year. |
| `PeriodStart` | DATE | no | PK | First day of the period (first of the month for Month, 1 January for Year). |
| `SumValue` | DECIMAL(18,4) | no |  | Sum of the validated 15-minute Values of the period. |
| `ReadingCount` | INT | no |  | How many validated readings were summed. |
| `EstimatedCount` | INT | no |  | How many of those were Estimated or Edited rather than measured. |

- **Primary key:** (MeterID, ObisCode, PeriodType, PeriodStart)
- **Check** `CK_METER_AGGREGATE_PeriodType`: PeriodType is one of 'Day', 'Month', 'Year'
- **Check** `CK_METER_AGGREGATE_ReadingCount`: ReadingCount >= 1
- **Check** `CK_METER_AGGREGATE_EstimatedCount`: EstimatedCount >= 0
- **Check** `CK_METER_AGGREGATE_Counts`: EstimatedCount <= ReadingCount
- **Check** `CK_METER_AGGREGATE_Period`: (PeriodType = 'Day') OR (PeriodType = 'Month' AND DAY(PeriodStart) = 1) OR (PeriodType = 'Year' AND DAY(PeriodStart) = 1 AND MONTH(PeriodStart) = 1)

### GEOFENCE

A rectangular map area, one per transformer; the hierarchy comes from the transformer tree.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `GeofenceID` | INT IDENTITY | no | PK | Primary key. |
| `Name` | NVARCHAR(100) | no |  | Name. |
| `MinLat` | DECIMAL(9,6) | no |  | South edge of the rectangle. |
| `MinLon` | DECIMAL(9,6) | no |  | West edge of the rectangle. |
| `MaxLat` | DECIMAL(9,6) | no |  | North edge of the rectangle. |
| `MaxLon` | DECIMAL(9,6) | no |  | East edge of the rectangle. |

- **Check** `CK_GEOFENCE_MinLat`: MinLat between -90 and 90
- **Check** `CK_GEOFENCE_MinLon`: MinLon between -180 and 180
- **Check** `CK_GEOFENCE_MaxLat`: MaxLat between -90 and 90
- **Check** `CK_GEOFENCE_MaxLon`: MaxLon between -180 and 180
- **Check** `CK_GEOFENCE_Rectangle`: MinLat < MaxLat AND MinLon < MaxLon

### TRANSFORMER

A transformer in a strict tree (root has no parent); meters are attached only to leaves.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `TransformerID` | INT IDENTITY | no | PK | Primary key. |
| `Name` | NVARCHAR(50) | no |  | Name. |
| `Latitude` | DECIMAL(9,6) | no |  | Latitude in degrees (-90 to 90). |
| `Longitude` | DECIMAL(9,6) | no |  | Longitude in degrees (-180 to 180). |
| `GeofenceID` | INT | no | FK GEOFENCE, UQ | The map area this transformer serves (one-to-one). |
| `ParentTransformerID` | INT | yes | FK TRANSFORMER | Parent in the tree; NULL for the root. |

- **Check** `CK_TRANSFORMER_Latitude`: Latitude between -90 and 90
- **Check** `CK_TRANSFORMER_Longitude`: Longitude between -180 and 180
- **Check** `CK_TRANSFORMER_Parent`: ParentTransformerID IS NULL OR ParentTransformerID <> TransformerID
- **Trigger** `TR_TRANSFORMER_Tree` (after insert, update): Error 50001: a parent transformer may not have meters. Error 50002: no cycles in the tree.

### TRANSFORMER_AGGREGATE

Stored Day, Month or Year totals for leaf transformers; upper levels are computed with a recursive query.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `TransformerID` | INT | no | PK, FK TRANSFORMER | Foreign key to TRANSFORMER. |
| `ObisCode` | VARCHAR(20) | no | PK, FK OBIS_CODE | OBIS code of the measurement (foreign key to OBIS_CODE). |
| `PeriodType` | VARCHAR(5) | no | PK | Day, Month or Year. |
| `PeriodStart` | DATE | no | PK | First day of the period. |
| `SumValue` | DECIMAL(18,4) | no |  | Sum of the meters' validated Values under this leaf transformer for the period. |
| `MeterCount` | INT | no |  | Number of meters included. |
| `ComputedAt` | DATETIME2(0) | no |  | When the row was computed. |

- **Defaults:** `ComputedAt` = `SYSUTCDATETIME()`
- **Primary key:** (TransformerID, ObisCode, PeriodType, PeriodStart)
- **Check** `CK_TRANSFORMER_AGGREGATE_PeriodType`: PeriodType is one of 'Day', 'Month', 'Year'
- **Check** `CK_TRANSFORMER_AGGREGATE_MeterCount`: MeterCount >= 0
- **Check** `CK_TRANSFORMER_AGGREGATE_Period`: (PeriodType = 'Day') OR (PeriodType = 'Month' AND DAY(PeriodStart) = 1) OR (PeriodType = 'Year' AND DAY(PeriodStart) = 1 AND MONTH(PeriodStart) = 1)
- **Trigger** `TR_TRANSFORMER_AGGREGATE_Leaf` (after insert, update): Error 50004: aggregates are stored only for leaf transformers.

### TRANSFORMER_CURRENT_STATE

Latest 15-minute import (1.8.0) and export (2.8.0) total per leaf transformer.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `TransformerID` | INT | no | PK, FK TRANSFORMER | Foreign key to TRANSFORMER. |
| `ObisCode` | VARCHAR(20) | no | PK, FK OBIS_CODE | Only 1.8.0 (import) or 2.8.0 (export). |
| `RefInterval` | DATETIME2(0) | no |  | The 15-minute interval the state refers to. |
| `SumValue` | DECIMAL(18,4) | no |  | Sum of the meters' Values in that interval. |
| `MeterCount` | INT | no |  | Number of meters included. |
| `ComputedAt` | DATETIME2(0) | no |  | Computed at. |

- **Defaults:** `ComputedAt` = `SYSUTCDATETIME()`
- **Primary key:** (TransformerID, ObisCode)
- **Check** `CK_TRANSFORMER_CURRENT_STATE_RefInterval`: DATEPART(MINUTE, RefInterval) % 15 = 0 AND DATEPART(SECOND, RefInterval) = 0
- **Check** `CK_TRANSFORMER_CURRENT_STATE_MeterCount`: MeterCount >= 0
- **Check** `CK_TRANSFORMER_CURRENT_STATE_Code`: ObisCode is one of '1.8.0', '2.8.0'

### LOAD_SHED_ORDER

A TSO order to reduce load on a transformer; it groups one command per active meter.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `ShedOrderID` | INT IDENTITY | no | PK | Primary key. |
| `Reason` | NVARCHAR(500) | no |  | Reason. |
| `CreatedAt` | DATETIME2(0) | no |  | When the row was created (UTC). |
| `Status` | VARCHAR(16) | no |  | Issued, Completed or Partially failed (some command did not get an ACK). |
| `TransformerID` | INT | no | FK TRANSFORMER | Foreign key to TRANSFORMER. |
| `OrderedBy` | INT | no | FK USER_ACCOUNT | TSO user who issued the order. |

- **Defaults:** `CreatedAt` = `SYSUTCDATETIME()`; `Status` = `'Issued'`
- **Check** `CK_LOAD_SHED_ORDER_Status`: Status is one of 'Issued', 'Completed', 'Partially failed'

## Area: Events

### EVENT

A network or meter event (alarm, unmatched packet) with severity and handling status.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `EventID` | BIGINT IDENTITY | no | PK | Primary key. |
| `EventType` | VARCHAR(30) | no |  | Kind of event (for example 'Unmatched packet'); an Unmatched packet event needs PacketID. |
| `Severity` | VARCHAR(8) | no |  | Info, Warning or Critical. |
| `Description` | NVARCHAR(1000) | yes |  | Description. |
| `OccurredAt` | DATETIME2(0) | no |  | Occurred at. |
| `Status` | VARCHAR(11) | no |  | Open, In progress or Closed. |
| `MeterID` | INT | yes | FK METER | Foreign key to METER. |
| `PacketID` | BIGINT | yes | FK TELEMETRY_PACKET | Foreign key to TELEMETRY_PACKET. |
| `TaskID` | INT | yes | FK FIELD_TASK | Field task during which the event was found, if any. |

- **Defaults:** `Status` = `'Open'`
- **Check** `CK_EVENT_Severity`: Severity is one of 'Info', 'Warning', 'Critical'
- **Check** `CK_EVENT_Status`: Status is one of 'Open', 'In progress', 'Closed'
- **Check** `CK_EVENT_Unmatched`: EventType <> 'Unmatched packet' OR PacketID IS NOT NULL

### LEADS_TO

Many-to-many link between events and the field tasks they cause.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `EventID` | BIGINT | no | PK, FK EVENT | Foreign key to EVENT. |
| `TaskID` | INT | no | PK, FK FIELD_TASK | Foreign key to FIELD_TASK. |

- **Primary key:** (EventID, TaskID)
- **Delete cascades:** EventID → EVENT; TaskID → FIELD_TASK

## Area: Market

### PORTFOLIO

A named group of premises managed by an aggregator.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `PortfolioID` | INT IDENTITY | no | PK | Primary key. |
| `Name` | NVARCHAR(100) | no |  | Name. |
| `AggregatorID` | INT | no | FK AGGREGATOR | Foreign key to AGGREGATOR. |


### INCLUDES

Membership of a premise in a portfolio, with its dates.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `PortfolioID` | INT | no | PK, FK PORTFOLIO | Foreign key to PORTFOLIO. |
| `PremiseID` | INT | no | PK, FK PREMISE | Foreign key to PREMISE. |
| `StartDate` | DATE | no |  | Date the premise joined the portfolio. |
| `EndDate` | DATE | yes |  | NULL while the premise is still in the portfolio. |

- **Primary key:** (PortfolioID, PremiseID)
- **Delete cascades:** PortfolioID → PORTFOLIO; PremiseID → PREMISE
- **Check** `CK_INCLUDES_Dates`: EndDate IS NULL OR EndDate >= StartDate

## Area: Compliance

### GDPR_REQUEST

A consumer's erasure request moving through the stages Submitted, Under review, Pre-approved, Approved or Rejected, Applied.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `GdprRequestID` | INT IDENTITY | no | PK | Primary key. |
| `SubmittedAt` | DATETIME2(0) | no |  | Submitted at. |
| `Status` | VARCHAR(12) | no |  | Stage: Submitted, Under review, Pre-approved, Approved, Rejected or Applied; a CHECK ties each stage to the timestamps that must be set. |
| `PreApprovedAt` | DATETIME2(0) | yes |  | Pre approved at. |
| `DecidedAt` | DATETIME2(0) | yes |  | Decided at. |
| `AppliedAt` | DATETIME2(0) | yes |  | When the erasure was carried out. |
| `RequestType` | VARCHAR(9) | no |  | Request type. |
| `ConsumerID` | INT | no | FK USER_ACCOUNT | Consumer who asks for erasure. |
| `PreApprovedBy` | INT | yes | FK USER_ACCOUNT | Operator who pre-approved. |
| `DecidedBy` | INT | yes | FK USER_ACCOUNT | Operator who gave the final decision (at most one of DecidedBy and DecidedByAdmin). |
| `DecidedByAdmin` | INT | yes | FK USER_ACCOUNT | Admin who gave the final decision instead of an operator. |

- **Defaults:** `SubmittedAt` = `SYSUTCDATETIME()`; `Status` = `'Submitted'`; `RequestType` = `'Erasure'`
- **Check** `CK_GDPR_REQUEST_Status`: Status is one of 'Submitted', 'Under review', 'Pre-approved', 'Approved', 'Rejected', 'Applied'
- **Check** `CK_GDPR_REQUEST_RequestType`: RequestType is one of 'Erasure', 'Retention'
- **Check** `CK_GDPR_REQUEST_OneFinal`: DecidedBy IS NULL OR DecidedByAdmin IS NULL
- **Check** `CK_GDPR_REQUEST_PreApproval`: (PreApprovedBy IS NULL AND PreApprovedAt IS NULL) OR (PreApprovedBy IS NOT NULL AND PreApprovedAt IS NOT NULL)
- **Check** `CK_GDPR_REQUEST_Decision`: (DecidedAt IS NULL AND DecidedBy IS NULL AND DecidedByAdmin IS NULL) OR (DecidedAt IS NOT NULL AND (DecidedBy IS NOT NULL OR DecidedByAdmin IS NOT NULL))
- **Check** `CK_GDPR_REQUEST_Stage`: (Status IN ('Submitted', 'Under review') AND PreApprovedAt IS NULL AND DecidedAt IS NULL AND AppliedAt IS NULL) OR (Status = 'Pre-approved' AND PreApprovedAt IS NOT NULL AND DecidedAt IS NULL AND AppliedAt IS NULL) OR (Status = 'Approved' AND PreApprovedAt IS NOT NULL AND DecidedAt IS NOT NULL AND AppliedAt IS NULL) OR (Status = 'Rejected' AND PreApprovedAt IS NOT NULL AND AppliedAt IS NULL) OR (Status = 'Applied' AND PreApprovedAt IS NOT NULL AND DecidedAt IS NOT NULL AND AppliedAt IS NOT NULL)
- **Check** `CK_GDPR_REQUEST_Order`: (PreApprovedAt IS NULL OR PreApprovedAt >= SubmittedAt) AND (DecidedAt IS NULL OR DecidedAt >= PreApprovedAt) AND (AppliedAt IS NULL OR AppliedAt >= DecidedAt)

### AUDIT_LOG

Generic dated record of every state change: object type and id, action, actor, old and new state.

| Column | Type | Null | Key | Meaning |
|---|---|---|---|---|
| `LogID` | BIGINT IDENTITY | no | PK | Primary key. |
| `ObjectType` | VARCHAR(30) | no |  | Kind of object changed (table or concept name); not a foreign key, so any object can be logged. |
| `ObjectID` | VARCHAR(100) | no |  | Id of the changed object, as text. |
| `Action` | VARCHAR(50) | no |  | What happened (for example create, approve, reject). |
| `ActorMechanism` | NVARCHAR(100) | yes |  | For automatic actions: the job or procedure that acted (set when PerformedBy is NULL). |
| `LoggedAt` | DATETIME2(3) | no |  | Logged at. |
| `OldState` | NVARCHAR(400) | yes |  | State before the change. |
| `NewState` | NVARCHAR(400) | yes |  | State after the change. |
| `ResultComment` | NVARCHAR(1000) | yes |  | Free-text outcome or reason. |
| `PerformedBy` | INT | yes | FK USER_ACCOUNT | User who acted; NULL for automatic actions. |

- **Defaults:** `LoggedAt` = `SYSUTCDATETIME()`
- **Check** `CK_AUDIT_LOG_Actor`: PerformedBy IS NOT NULL OR ActorMechanism IS NOT NULL
