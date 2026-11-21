# 17. Extensibility

[← Back to the menu](../README.md) · Task: EXT-1 in [tasks.md](tasks.md) · Part of docx (b)

> **Status: plan only.**

## Requirement

Show how the system grows without changing its structure: new meter types, protocols, prosumer classes, VEE rules.

## Planned content

| New thing | How it is added |
|---|---|
| Meter type | A row in `METER_MODEL` (`MeterType` is an open list) |
| Communication protocol | A row in `COMM_TYPE` |
| OBIS code | A row in `OBIS_CODE` with its limits, and `RULE_FOR` rows |
| VEE rule | A row in `VEE_RULE` with JSON `Parameters`, plus `RULE_FOR` |
| Prosumer class | A row in `SUPPLY_SCHEME` |
| Event or command type | Open text columns `EVENT.EventType`, `REMOTE_COMMAND.CommandType` |
| Future work | Geofences drawn freely on a map (polygons), as the professor said |
