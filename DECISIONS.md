# MDMS-Cy: decisions, conflicts, assumptions and rules

Generated from er-model/model.js and er-model/schema.js (the source of truth); do not edit by hand. S = spec citation (er-model/sources.js, pages of project.pdf), L = course lecture/assignment citation, D = our design decision, C = conflict/question for the lab, T = schema convention.

## Design decisions D1-D32 (ER model)

**D1. Roles are entities, not rows of a ROLE table.** The spec names seven roles: ΔΣ, ΛΣ, ΚΧ, ΤΠ, DSO, TSO and market users. Each has its own attributes or its own relationships, so each is its own entity (D2). A ROLE table as well would store the same membership twice and need a rule to keep the two in step. The spec's examples of future extension are meter types, telemetry protocols, prosumer classes and VEE methods, not roles, and a new role later would be a new entity and a new table, which extends the schema without changing it. If the lab says the ΛΣ is the DSO (C5), SYSTEM_OPERATOR and DSO_OPERATOR become one entity. _(S3, S11, S60, C5)_

**D2. Each role is a weak entity of USER_ACCOUNT.** A role becomes its own entity when it has its own attributes or its own relationships: CONSUMER, FIELD_TECHNICIAN, MARKET_USER, SYSTEM_ADMIN (creates ΛΣ, may give the final GDPR approval), SYSTEM_OPERATOR (approvals), TSO_OPERATOR (load-shed orders) and DSO_OPERATOR (manual estimates and edits in VEE). Without EER (D32), each is a weak entity owned by USER_ACCOUNT through a 1:1 identifying relationship (IS_CONSUMER to IS_DSO) with no partial key, so its key is the UserID of the account; lecture 5 allows an identifying relationship to be 1:1. A role row exists only while the account holds that role, and one account can have several role rows, because one person can hold several roles. Every other relationship points to the role entity, so only a ΛΣ can approve (a ΔΣ may also give the final GDPR decision, D17), only a TSO can order shedding and only DSO staff can change readings by hand. That every account has at least one role cannot be drawn without EER; Phase B creates each account together with its first role in one procedure, and a trigger refuses to remove the last role of an account. _(S11, S14, S31, S73, L2, D32)_

**D3. MARKET_USER for supplier and aggregator staff.** The spec requires authenticated, permission-checked calls for suppliers and aggregators, so their staff need accounts tied to their company. _(S57)_

**D4. Administrative areas as three entities.** Parish belongs to municipality and municipality to district. Storing all three on PREMISE would create a transitive dependency, so they become a chain of N:1 relationships. Postal code stays an attribute because postal areas do not nest inside parishes. _(S16)_

**D5. HOLDING records each holding period.** The spec only demands that one consumer can have many premises. Each period in which a consumer holds a premise is its own HOLDING row, a weak entity owned by CONSUMER and PREMISE with key (UserID, PremiseID, StartDate). A premise can change hands, and a consumer who leaves and later returns gets a new row, so no period covers another holder's readings. The app limits each consumer to readings inside their own periods. _(S15, L2)_

**D6. Thresholds are per premise.** A consumer with two premises will want different limits, so each threshold points to one premise. _(S20)_

**D7. Availability area is a municipality.** The spec asks for daily time and geographic availability but does not fix the unit. Municipality is used; a geofence would also work. Each availability row is one date and time slot, and it can cover several municipalities. _(S31)_

**D8. Documents have exactly one owner.** DOCUMENT belongs either to a technician or to a meter. Phase B enforces this with a CHECK that exactly one of its two foreign keys is set. Attachments always belong to a task (EVIDENCE), including installation photos. _(S32, S37, D26)_

**D9. A task names a premise, a meter, or both.** The spec says premise and/or meter, so both links are optional and a CHECK requires at least one. An installation task starts before the meter is linked. _(S34)_

**D10. METER_INSTALLATION keeps the history.** Each installation has InstalledAt and RemovedAt. A replacement closes one row and opens another, so the premise history is the union of its installations, and readings stay with the meter that produced them. _(S39)_

**D11. LOAD_SHED_ORDER groups the commands.** One TSO shedding order for a transformer creates one Load shed command per Active meter SERVED_BY that transformer, each with its own attempts and ACK. A Retired meter keeps its last transformer but gets no command, since it could never send an ACK. _(S6, S40)_

**D12. READING keeps the received value and the value in use.** 1.8.0 is a cumulative counter, but the VEE examples reason in kWh per 15 minutes. ReceivedValue keeps what the meter sent and never changes. UsedValue is what spikes, gaps, aggregates and reports use: the slot's energy (the difference from the previous slot) for a Cumulative register, the measured value for an Instantaneous code. Estimation and editing change only UsedValue, and READING_EDIT records each change. _(S63, S47, S48)_

**D13. VEE_RUN records each VEE execution.** The end of a run is the moment readings become final and aggregation starts, so each final reading points to the run that finalized it. Readings that fail a run go back for correction and become final in a later run (Figure 3). So an aggregate row for a period is written once, after the run in which the last reading of that period becomes final: every slot of the period, within each meter's installation dates, has a final reading, received or estimated, for each meter that reports that code. Until then the period has no row, so an aggregate never needs recomputing and a Month always equals the sum of its Days. _(S49, S50, S75, S44)_

**D14. The geofence hierarchy is a tree.** The text allows arbitrary depth; Figure 4 shows each geofence under exactly one parent, so PARENT_OF is 1:N. Level must follow the tree: a child is one level below its parent, upper geofences have at least one child, and only level-1 geofences have a transformer. _(S53, S54)_

**D15. Intraday sums are not stored.** The spec asks that intraday data be computable straight from the latest readings, so it is a query over non-final READING rows, not an entity. _(S59)_

**D16. SUPPLY_CONTRACT decides supplier access.** The spec says consumers choose a supplier and suppliers see only their own customers. A dated contract between consumer, premise and SUPPLIER records exactly that. _(S7, S57, D30)_

**D17. GDPR stages: who on the request, history in AUDIT_LOG.** The ΛΣ who pre-approved and the ΛΣ or ΔΣ who gave the final decision are relationships (PRE_APPROVES, and FINAL_APPROVES or FINAL_APPROVES_ADMIN, since Figure 2 lets either role decide), like the other approvals in the model, and their times are attributes of GDPR_REQUEST. At most one final approver is set. AUDIT_LOG keeps the dated record of every stage with its user, so no separate step entity is needed. _(S25, S13, S11)_

**D18. One generic AUDIT_LOG.** ObjectType + ObjectID cannot be a foreign key. The gain is that any new object type can be logged without a new table. The alternative is one log table per area. _(S13, S60)_

**D19. Retention follows the holder at the time of the reading.** RawRetentionMonths (36 or 1) sits on CONSUMER. A raw READING of meter m at time t belongs to the consumers whose HOLDING covers t at the premise where m was installed at t (METER_INSTALLATION). It is purged after the shortest RawRetentionMonths among them, or after 36 months if the premise had no holder. The TELEMETRY_PACKET rows of that meter for the same window are purged too, and packets with no meter after 36 months. Aggregates are never purged. The spec's wording "the meter of the consumer" would also allow a per-meter setting (C4). _(S27, S28, S66, S70)_

**D20. Notifications are not an entity.** The spec says the system may inform consumers. For network events, EVENT_ON gives the meter, which leads to the premise and its holders. For thresholds, SETS and THRESHOLD_FOR give the consumer and the premise, which are compared with readings or aggregates as they are built. NotificationChannel says how. Alerts are sent, not stored. _(S19, S20)_

**D21. Transformer measurements are geofence aggregates.** The spec never gives transformers their own meters. Figure 2 shows transformer data as per-geofence 15-minute aggregates kept permanently, which GEOFENCE_AGGREGATE stores. Technical losses therefore cannot be computed (C7). _(S29, S30, C7)_

**D22. Bank accounts follow "consumer and/or premise".** An account can belong to a consumer, be tied to premises, or both, so both links are optional. At least one must exist; Phase B enforces this in the insert procedure and with a trigger, because a CHECK cannot read the ACCOUNT_FOR table. ACCOUNT_FOR is M:N because one account often pays for several premises. _(S17)_

**D23. An invoice points to a contract or to purchases.** A supplier invoice belongs to a SUPPLY_CONTRACT, which already gives the supplier and the premise. An MDMS-Cy fee invoice charges SERVICE_PURCHASE rows (CHARGED_IN), whose service type gives the fee. At least one of the two must exist; Phase B enforces this in the insert procedure and with a trigger, because CHARGED_IN is a foreign key in SERVICE_PURCHASE, which a CHECK on INVOICE cannot read. There is no separate fee link that could disagree. _(S24, S21, D16)_

**D24. Paths that must agree.** Some facts can be reached two ways and Phase B must keep them consistent. A consumer may only set thresholds, file requests, buy services, link accounts or sign contracts for premises they hold (HOLDING) in that period. An invoice's consumer equals its contract's consumer and the buyer of its purchases, and a PAID_FROM account belongs to that consumer or pays for that premise. A READING from a packet has that packet's SENT_BY meter as its MEASURED meter, and an EVENT with EVENT_FROM has that meter as EVENT_ON. When a task or request names both a premise and a meter, the meter is installed there at that date (except the task's own new installation), and an installation is INSTALLED_AT the TASK_AT premise of its DONE_IN task. A task RESOLVED_BY a request is at that request's premise. Every SHED_COMMAND command is a Load shed that TARGETS a meter that was Active and SERVED_BY the order's transformer when the order was created. METER.Status agrees with the open installation, and REMOTE_COMMAND.Status with its attempts. _(S15, S24, S42, S6)_

**D25. SERVED_BY is stored, not computed.** The spec finds a meter's transformer from its coordinates and the geofence that contains them. The result is stored in SERVED_BY so that load shedding and aggregation do not repeat the lookup; it must match the transformer of the level-1 geofence that contains the meter. Level-1 rectangles do not overlap and every meter lies inside exactly one, so the lookup gives one transformer. _(S51, S52)_

**D26. Installations are field tasks.** Installation and replacement are field tasks, and the meter's data is entered at installation. So every meter has an installation, every installation is done in exactly one task (DONE_IN, 1:1), and the installer is the task's technician. For these tasks the new meter comes from DONE_IN and TASK_AT is required; TASK_ON names only a meter that is checked or removed (empty for an Installation, the old meter for a Replacement). In a Replacement the old installation's RemovedAt, the new InstalledAt and the task's CompletedAt are the same. _(S34, S36, S39)_

**D27. Tariff types attach to supply contracts.** "τύπους υπηρεσιών και τιμολογίων" is read as service types and tariff types, since invoices are records rather than types. The tariff is chosen per supply contract. _(S12, D16)_

**D28. Portfolios hold premises.** Aggregates are computed from meters, which are installed at premises, so a portfolio lists premises with dates. INCLUDES keeps one row per portfolio and premise: a premise that leaves and later re-joins gets new dates, and only its latest membership is kept. If the lab wants the full membership history, INCLUDES can become a weak entity like HOLDING (D5). _(S8, S57, D5)_

**D29. What applying a GDPR request does.** It sets CONSUMER.RawRetentionMonths to 1, and the purge of D19 then deletes the raw readings older than one month (with their READING_EDIT rows) and the matching packets for the consumer's holding periods. It keeps the account and its login (the consumer is still a user), invoices, payments and the bank accounts they use, contracts, service purchases, aggregates and AUDIT_LOG, because these are needed for accounting or legal reasons. Whether the name and contact details of a consumer who has left should also be anonymized is asked in C6. _(S25, S26, S28, S66)_

**D30. Suppliers and aggregators are two entities.** Suppliers have customers through contracts and aggregators have portfolios ("τους πελάτες ή τα χαρτοφυλάκια που εκπροσωπούν"), so each gets its own relationship, by the same rule as D2. Without EER (D32) they are two separate entities, the way lecture 6 writes subclasses in plain ER (slide 6-39), instead of subclasses of one participant entity. A company that acts as both is registered once in each. A market user works for exactly one of them (WORKS_FOR_SUPPLIER or WORKS_FOR_AGGREGATOR); both foreign keys sit in MARKET_USER, so a row CHECK enforces it, as in D8. _(S57, D2, D32, L15)_

**D31. Only M:N relationships carry attributes.** On a 1:N relationship an attribute moves to the N side (lecture 5, slide 5-16), so the decision times are ApprovalDecidedAt on FIELD_TECHNICIAN, ReviewedAt on DOCUMENT, and PreApprovedAt and DecidedAt on GDPR_REQUEST. Only the M:N INCLUDES keeps attributes. ERD+ also copies relationship attributes into tables only for M:N relationships. _(L12)_

**D32. Plain Chen ER, without EER.** Phase A asks for "Εννοιολογική Σχεδίαση με Χρήση του Διαγράμματος Chen ER" and a "Διάγραμμα Οντοτήτων Συσχετίσεων (ER)", and never mentions EER. Assignment 1 asked explicitly for "ER – όχι EER", and lecture 6 teaches EER as an extension of ER. So the model uses only plain ER shapes. Lecture 6 (slide 6-39) says any EER can be written in ER with some loss of meaning, which the database program must then handle. Here the roles become weak entities of USER_ACCOUNT (D2) and SUPPLIER and AGGREGATOR become two entities (D30). For the roles, the tables are exactly those of the textbook mapping of a specialization: one table per role, keyed by UserID. For suppliers and aggregators they are the mapping that keeps only the subclass tables, which the textbook allows for a disjoint, total specialization. The one rule that no longer shows in the diagram, at least one role per account, is enforced in Phase B (D2). _(S76, S61, L14, L3, L9, L15, L16)_

## Conflicts in the spec / questions for the lab C1-C7

**C1. Phase A deadline.** The cover says "Friday 19/10/26", but 19 October 2026 is a Monday. Check the date on Moodle. _(S1)_

**C2. Can final readings be deleted?.** Figure 3 says readings are neither modified nor deleted after VEE, and III.4.2 says final readings and historical aggregates are kept permanently as immutable data. Yet III.1.4 deletes raw readings after 3 years, or 1 month after an approved request. Our reading: immutable means value and status never change; the retention purge is the only delete allowed, and it also removes the matching packets (D19). _(S49, S50, S68, S27, S28, D19)_

**C3. Summing cumulative registers.** III.4.2 sums 1.8.0 and 2.8.0, which are counters since installation. A sum of counters is a valid "total so far", but per-slot energy needs differences. READING keeps both the received counter and the per-slot UsedValue (D12); ask the lab which one they expect. _(S55, S63, D12)_

**C4. Retention per consumer or per meter.** The spec says "the meter of the consumer", but also that the period follows the preferences the user has set. We keep one setting per consumer and apply it by holding period (D19). Switching to a per-meter attribute is a small change if the lab prefers it. If a premise had several holders at the same time, the shorter period wins. _(S28, S70, D19)_

**C5. Who is the Λειτουργός Συστήματος?.** Figure 1 labels the DSO actor "Λειτουργός Συστήματος (DSO)", but section III makes the ΛΣ a separate approval role created by a ΔΣ. We keep SYSTEM_OPERATOR and DSO_OPERATOR as separate role entities. One account can hold both roles, so DSO staff can also be ΛΣ, and either answer fits; if the lab says they are one role, the two entities merge. _(S71, S11, D1, D2)_

**C6. What does the right to be forgotten erase?.** The spec erases "the personal data that may be deleted" but keeps what accounting needs, and it also says the request cuts raw retention to 1 month, which implies the consumer stays a user. We keep the account and its contact details (D29). Ask whether the name and contact details of a consumer who has left should also be anonymized. _(S26, S28, D29)_

**C7. Transformer measurements and technical losses.** The DSO must compute technical losses, but the spec never gives transformers their own meters, so we store transformer data as geofence aggregates (D21). Losses (energy fed in minus energy metered) then cannot be computed. Ask whether transformers or grid equipment send their own measurements. If they do, a weak TRANSFORMER_READING owned by TRANSFORMER and OBIS_CODE can be added without changing the existing structure. _(S5, S29, S60, D21)_

## Assumptions (basis for the Phase A "παραδοχές", max 1/2 page)

- One person has one account and may hold several roles; every account has at least one. _(S9, D1, D2)_
- A premise can change consumers over time; each holding period is its own row with start and end dates. _(S15, D5)_
- Readings belong to the meter. A premise's history is the union of the meters installed there. _(S39, D10)_
- Every meter is served by exactly one LV transformer, and each level-1 geofence covers exactly one transformer. Geofences are rectangles that form a tree, and level-1 rectangles do not overlap. _(S51, S52, S54, D14, D25)_
- Packet timestamps are placed in their 15-minute slot. A reading keeps the value received and the per-slot value that later functions use. _(S42, D12)_
- After VEE, a reading's value and status never change. The only deletion allowed is the retention purge of consumer readings and their packets (36 months, or 1 month after an approved GDPR request). Transformer data, i.e. geofence aggregates, is never deleted. _(S49, S68, S27, S28, S29, C2, D19)_
- An approved GDPR request cuts raw retention to 1 month; the account, invoices, payments and aggregates are kept. _(S26, D29)_
- Suppliers see only premises with a supply contract, aggregators only premises in their portfolios, and both only as aggregates. _(S57, D16)_
- Dynamic pricing, forecasting, technical losses and real email or SMS delivery are outside the database scope. _(S24, S69, D20, C7)_
- In the ERD+ drawing every underlined attribute other than the entity's ID is an alternative key, because ERD+ has no overline. _(L4, L8)_

## Schema conventions T1-T10 (step 3)

**T1. Tables follow the textbook mapping.** Every regular entity becomes a table with its key. A weak entity becomes a table whose key is its owner's key plus its partial key. A 1:N relationship becomes a foreign key on the N side, NOT NULL when that side takes part totally. A 1:1 relationship becomes a UNIQUE foreign key on the side that takes part totally. An M:N relationship and a multivalued attribute become tables of their own, and a composite attribute becomes its parts. Only the M:N INCLUDES carries attributes (D31). _(L16, L2, D31)_

**T2. Names follow ERD+.** A foreign key takes the name of the key it points to, as the ERD+ conversion does. It is renamed where two would clash or where the role would not be clear (the rename table on the ER page). Constraint names say what they guard: PK_TABLE, FK_TABLE_RELATIONSHIP, UQ_, CK_ and DF_, so an error message names the rule that was broken. _(L9)_

**T3. Keys.** Surrogate keys are INT IDENTITY(1,1). The three tables that grow fastest, TELEMETRY_PACKET, AUDIT_LOG and EVENT, use BIGINT. OBIS_CODE keeps its natural key, the code itself, which the packets carry. The role tables take UserID from USER_ACCOUNT, so a role is a row, not a new number. _(S42, S64, D2)_

**T4. Text, files and passwords.** NVARCHAR holds text that people type and that may be in Greek (names, addresses, comments). VARCHAR holds codes, e-mail, IBAN and the fixed English status values. Photos, documents and attachments are files outside the database, which keeps their path. PasswordHash is VARCHAR(255) for the output of PHP password_hash(), which salts and hashes, so no one can read a password from the table. _(S10, S78)_

**T5. Times and dates.** All times are DATETIME2 in UTC, as the packets carry UTC times (for example "2026-10-30T12:00:00Z"). DATETIME2(0) keeps seconds; reception, command attempts and the audit log keep milliseconds, where order within a second matters. Reading slots and current-state slots start at :00, :15, :30 or :45 (CHECK). Date ranges (holdings, contracts, portfolio membership, invoices) include both ends, and EndDate is empty while the period is open. _(S42, S64)_

**T6. Numbers.** Energy, voltage and current are DECIMAL(15,4), since the sample packet has four decimals; sums are DECIMAL(18,4). Money is DECIMAL(12,2), fees DECIMAL(10,2). Coordinates are DECIMAL(9,6) (about 0.1 m), with range CHECKs. _(S64, S16)_

**T7. Fixed lists are CHECKs, open lists are tables.** A status or type whose values the spec fixes has a CHECK ... IN (...) list. Where the spec wants new values without a change of structure (meter models, communication types, supply schemes, OBIS codes, VEE methods), the values are rows of a table. Types the spec gives only as examples or wants extensible have no fixed list: METER_MODEL.MeterType (with PhaseCount 1-3 for the phase rule), REMOTE_COMMAND.CommandType, EVENT.EventType and VEE_RULE.RuleType. The CHECKs that compare one of their values (Load shed, Unmatched packet) still work. _(S60, S44, S36, S19)_

**T8. ON DELETE.** CASCADE only from an owner to rows that are part of it: multivalued attributes, M:N rows, AVAILABILITY, TASK_NOTE, COMMAND_ATTEMPT and READING_EDIT (the retention purge deletes the edits with their reading). Every other foreign key is NO ACTION, so deleting an account, meter or premise that has history fails instead of erasing that history. _(S39, S49, D19, D29)_

**T9. One row: CHECK. More rows: Phase B.** A CHECK in SQL Server sees only its own row. So the rules inside one row are CHECKs: exactly one of two foreign keys, a status that matches its times, the Origin rule. Filtered UNIQUE indexes allow at most one open holding per consumer and premise, one open installation per meter and one open contract per premise. These indexes need SET QUOTED_IDENTIFIER ON in every connection that writes to those tables: SSMS and the PHP drivers for SQL Server turn it on, and sqlcmd needs the -I option. Rules that read other rows or tables are listed below; in Phase B they become triggers or stored procedures, which the spec wants inside the database anyway. _(S78, D24)_

**T10. Indexes come in step 6.** Primary keys and UNIQUE constraints already create indexes. The performance indexes, of which the spec asks for the three most important with an explanation, belong to step 6, when there is enough synthetic data to measure them. _(S79)_

## Phase B rules that a CHECK cannot express (21; triggers / stored procedures, step 5)

| # | Area | Rule | How | Source |
|---|---|---|---|---|
| R1 | users | Every account has at least one role row. The registration procedures create the account and its first role in one transaction, and a trigger refuses to delete the last role of an account. | procedure + trigger | D2 |
| R2 | users | A technician belongs to at least one category and has the three required documents, each Accepted, before APPROVES may set Approved. Tasks are assigned only to Approved technicians. | procedure | S31, S32 |
| R3 | premises | Holding periods of the same consumer and premise do not overlap. | trigger | D5 |
| R4 | premises | A consumer sets thresholds, files requests, buys services, links bank accounts and signs contracts only for premises they hold at that time. | procedure | D24 |
| R5 | billing | A bank account has an owner (OWNS_ACCOUNT) or at least one ACCOUNT_FOR row. The insert procedure adds the account and its ACCOUNT_FOR rows and checks this at its end, because an AFTER INSERT trigger runs before those rows exist; a trigger refuses to remove the last ACCOUNT_FOR row of an account without an owner. | procedure + trigger | D22 |
| R6 | billing | An invoice has a contract or at least one SERVICE_PURCHASE. Its consumer equals the contract's consumer and the buyer of its purchases, and a PAID_FROM account belongs to that consumer or pays for that premise. The insert procedure adds the invoice and its SERVICE_PURCHASE rows and checks this at its end, because an AFTER INSERT trigger runs before those rows exist; a trigger refuses to remove the last purchase of an invoice without a contract. | procedure + trigger | D23, D24 |
| R7 | billing | A Historical data access purchase gives MonthFrom and MonthTo, inside the consumer's retention period; other service types leave them empty. | procedure | S21, S66 |
| R8 | field | The availability slots of a technician do not overlap, and each slot covers at least one municipality. | trigger | S31, D7 |
| R9 | field | An installation is done in an Installation or Replacement task whose premise is the installation's premise. When a task or request names a premise and a meter, the meter is installed there at that date. | trigger | D24, D26 |
| R10 | meters | The installations of a meter do not overlap, and METER.Status follows its open installation (Active only while it is Confirmed). | trigger | D10, S38 |
| R11 | meters | A meter has at least one document, and one of each equipment type, Accepted, before CONFIRMS may set Confirmed. | procedure | S37, S38 |
| R12 | meters | A meter has as many connected phases (METER_CONNECTED_PHASE rows) as the PhaseCount of its model, for example one for Single-Phase and three for Three-Phase. | trigger | S36 |
| R13 | meters | A shedding order creates one Load shed command for every Active meter SERVED_BY its transformer, so it has at least one. Order status follows its commands, and command status follows its attempts. | procedure | D11, D24 |
| R14 | telemetry | A finalized reading (RunID set) is immutable: its value and status never change, and it gets no more edits. | trigger | S49, S50 |
| R15 | telemetry | A reading from a packet has the packet's meter, and an event from a packet has the packet's meter as EVENT_ON. | trigger | D24 |
| R16 | telemetry | The retention purge deletes raw readings after the holder's RawRetentionMonths (36, or 1 after an approved GDPR request), then the packets that no reading or event still uses, and never deletes aggregates. | procedure | D19, D29 |
| R17 | grid | An aggregate row is written once, when every reading of its period is final, only for cumulative registers, and never changed. | procedure + trigger | D13 |
| R18 | grid | Geofence levels follow the tree: a child is one level below its parent, only level-1 geofences have a transformer, every higher geofence has a child, and level-1 rectangles do not overlap. | trigger | D14 |
| R19 | grid | SERVED_BY is the transformer of the level-1 geofence that contains the meter's coordinates. | procedure | D25 |
| R20 | market | The supply contracts of a premise do not overlap in time. | trigger | D16 |
| R21 | trace | Every critical state change (approvals, statuses, VEE results, GDPR stages) writes an AUDIT_LOG row with user or mechanism, time, old and new state. | procedure | S13, D18 |

## Change history of the model (reviews 1-4)

### First review

- Removed transformer meters (MeterClass, installations on transformers). The spec never says transformers have meters; their data is the per-geofence aggregate in Figure 2. _(S29, S30, D21)_
- Fixed SERVICE_AREA participation. The draft had total participation on both sides, but only level-1 geofences have a transformer. _(S51, S54)_
- Merged the two invented GDPR request types into one. The spec has one right-to-be-forgotten flow whose approval both erases personal data and cuts raw retention to 1 month. _(S25, S26, S28, S30)_
- Marked the conflict between "never deleted after VEE" (Figure 3) and the 3-year and 1-month deletion rule. The draft presented its own resolution as if the spec said it. _(S27, S50, C2)_
- FIELD_TASK now links to a premise and/or a meter, both optional. The draft made the premise mandatory. _(S34, D9)_
- READING is a weak entity identified by METER and OBIS_CODE plus the slot, matching the lecture rules for weak entities. _(L2)_
- Removed entities the spec does not need: API_CALL_LOG, NOTIFICATION, PROVISIONAL_AGGREGATE, VEE_FINDING, GDPR_REQUEST_STEP, RETENTION_POLICY, and the TASK_TYPE, COMMAND_TYPE, EVENT_TYPE and DOCUMENT_TYPE lookups. 59 entities became 48. _(D15, D17, D19, D20)_
- Kept lookup entities only where the spec requires extension without structural change (meter types, protocols, prosumer classes, OBIS codes, VEE methods) or where a System Operator defines the values. _(S2, S60, S12)_
- Removed invented attributes such as transformer capacity, correspondence address and last login time.
- Labelled every choice the spec does not make as a design decision (D), so it is clear what comes from the spec and what is ours.

### Second review

- INSTALLED is now total on METER. The model said "a meter in stock has no installation" while SERVED_BY and METER_DOC required every meter to be in the network; the spec enters a meter at its installation. _(S36, S51, D26)_
- Dropped INSTALLED_BY and made DONE_IN total: every installation is a field task, so the installer is the task's technician. _(S34, D26)_
- ASSIGNED_TO is total on FIELD_TASK, because every task is linked to the technician who takes it on. FIELD_TASK gained CompletedAt, the actual date of the check. _(S34, S41)_
- Dropped FEE_FOR and replaced ISSUED_BY with BILLED_UNDER (invoice to supply contract). The fee was reachable two ways, and an invoice could point at an aggregator. _(S24, D23)_
- ACCOUNT_FOR is M:N and OWNS_ACCOUNT is optional on the account side, matching "consumer and/or premise". _(S17, D22)_
- DATA_ACCESS_PURCHASE keeps the Amount paid. _(S66)_
- AVAILABLE_IN, LEADS_TO and RULE_FOR are now M:N. _(S31, S41, S45)_
- New APPLIED_RULE: an automatic correction records which VEE rule made it, so every change has an origin. _(S48, S13)_
- Removed IsFinal and FinalizedAt from READING (derived from FINALIZED_IN). Packets can be "Partially accepted" so rejected OBIS pairs are not lost silently. _(S45, D13)_
- New decisions D22 to D28 cover choices that were implicit, and four citations now point at better quotes.

### Third review

- The roles with their own relationships are now subclasses: SYSTEM_ADMIN creates SYSTEM_OPERATOR (CREATES is no longer recursive), every approval points to SYSTEM_OPERATOR, and ORDERED_BY points to TSO_OPERATOR. D2 stated this rule but did not follow it. _(S11, D2)_
- SUPPLIER and AGGREGATOR are subclasses of MARKET_PARTICIPANT, defined by ParticipantType, so only a supplier can have contracts and only an aggregator portfolios. _(S57, D30)_
- HOLDS became the weak entity HOLDING, so each holding period is its own row and a returning consumer cannot see another holder's readings. _(S15, D5)_
- Two-part partial keys are now one composite attribute: Slot (AvailDate, FromTime) and Period (PeriodType, PeriodStart). Two separate dashed underlines would mean two separate keys. _(L11)_
- READING has ReceivedValue and UsedValue instead of Value and IntervalValue, so it is clear which value edits change and which value later functions use. _(S47, D12)_
- METER.Status lost Disconnected: a cut supply does not stop ingestion, and the supply state comes from the acknowledged commands. REMOTE_COMMAND.AckAt was dropped because the attempts already record the ACK. _(S38, S40)_
- DONE_IN is 1:1 and INSTALL_PHOTO was dropped: installation photos are the evidence of the installation task. TASK_ON is defined for installations and replacements (D26). _(S37, D26)_
- Approval times moved from 1:N relationships to the N side, the ΛΣ of each GDPR stage is now a relationship, and ConnectedPhase is multivalued. _(L12, D17, D31)_
- DATA_ACCESS_PURCHASE became SERVICE_PURCHASE, so any service type can be charged. The meter aggregates now cover all six energy registers. _(S2, S62)_
- Retention now follows the holder at the time of each reading and also purges the packets. New decisions D29 to D31, new conflicts C5 to C7, and CHECK rules that would need another table are now trigger rules. _(D19, D29, C5)_
- DSO staff are a subclass, DSO_OPERATOR, and EDITED_BY points to it, because VEE is a DSO function. ROLE and HAS_ROLE were dropped: every role is already a subclass, so the table stored each role twice. The specialization of USER_ACCOUNT is now total. _(S73, S74, D1, D2)_
- A ΔΣ can give the final approval of a GDPR request (FINAL_APPROVES_ADMIN), since Figure 2 names "ΛΣ/ΔΣ" for that stage. _(S30, D17)_
- An aggregate row is written once, when every reading of its period is final, so a reading that becomes final in a later VEE run is not left out. The current-state table is computed from the latest final readings, ignoring missing ones, instead of copying a 15-minute aggregate. _(S49, S72, S75, D13)_
- Manual estimate is a third Origin of READING_EDIT, as Figure 3 names manual estimation. A received value that is estimated keeps its ReceivedValue. Load shedding targets only Active meters, since a Retired meter could never send an ACK. _(S75, S6, D11)_
- The ERD+ guide lists the foreign-key columns to rename after the conversion, so that no table ends up with two UserID columns. _(L9)_

### Fifth review (review of the second Claude, 17/10/26)

- METER_MODEL.MeterType is an open list and the new attribute PhaseCount (1-3) carries the phase rule R12, because the spec gives the meter types only as an example and wants new meter types without a change of structure. _(S36, S60)_
- REMOTE_COMMAND.CommandType and EVENT.EventType lost their fixed lists for the same reason: the spec lists events only as examples, and new telemetry protocols bring new events and commands. The CHECKs on Load shed and Unmatched packet still hold. _(S19, S60)_
- Two new tests (a new meter type is accepted, a model with 4 phases is refused): 76/76 on SQL Server 2025.

### Fourth review (plain ER, 9/10/26)

- The model is now plain Chen ER, without EER, because the spec asks for a Chen ER diagram and Assignment 1 asked for ER, not EER. Lecture 6 shows how to write EER in plain ER. _(S76, L14, L15, D32)_
- The seven roles are weak entities of USER_ACCOUNT, each with a 1:1 identifying relationship (IS_CONSUMER, IS_TECHNICIAN, IS_MARKET_USER, IS_ADMIN, IS_OPERATOR, IS_TSO, IS_DSO). Their key is the UserID of the account, so the tables are the same as with the specialization, and every relationship still points to the role it needs. _(L2, D2)_
- MARKET_PARTICIPANT and its ParticipantType, which defined the specialization, were dropped. SUPPLIER and AGGREGATOR are two entities with their own key and a unique Name, and WORKS_FOR became WORKS_FOR_SUPPLIER and WORKS_FOR_AGGREGATOR, exactly one of which a market user has. _(S57, L13, D30)_
- The rule "every account has at least one role", which only the EER double line showed, is now a Phase B rule. _(D2, L15)_
- For the schema of step 3, the notes now list the values of SERVICE_REQUEST.Status, DOCUMENT.ReviewStatus, METER_INSTALLATION.ConfirmationStatus and EVENT.Severity and Status, and COMMAND_ATTEMPT.Outcome may be empty while an attempt waits. Six more foreign keys get readable names (ConfirmedBy, OrderedBy, EditedBy, TechnicianID, WrittenBy, PerformedBy). _(S77, L9)_

## Entities per area

- **Users and roles**: USER_ACCOUNT, CONSUMER, FIELD_TECHNICIAN, MARKET_USER, SYSTEM_ADMIN, SYSTEM_OPERATOR, TSO_OPERATOR, DSO_OPERATOR
- **Consumers and premises**: PREMISE, HOLDING, PARISH, MUNICIPALITY, DISTRICT, SUPPLY_SCHEME, CONSUMPTION_THRESHOLD, SERVICE_REQUEST
- **Billing and payments**: BANK_ACCOUNT, INVOICE, PAYMENT, SERVICE_TYPE, SERVICE_PURCHASE
- **Field technicians and tasks**: TECHNICIAN_CATEGORY, AVAILABILITY, DOCUMENT, ATTACHMENT, FIELD_TASK, TASK_NOTE
- **Meters, installations and commands**: METER_MODEL, COMM_TYPE, METER, METER_INSTALLATION, REMOTE_COMMAND, COMMAND_ATTEMPT, LOAD_SHED_ORDER
- **Telemetry and VEE**: OBIS_CODE, TELEMETRY_PACKET, READING, READING_EDIT, VEE_RULE, VEE_RUN
- **Grid topology and aggregates**: TRANSFORMER, GEOFENCE, METER_AGGREGATE, GEOFENCE_AGGREGATE, GEOFENCE_CURRENT_STATE
- **Suppliers and aggregators**: SUPPLIER, AGGREGATOR, TARIFF_TYPE, SUPPLY_CONTRACT, PORTFOLIO
- **GDPR, audit log and events**: GDPR_REQUEST, AUDIT_LOG, EVENT
