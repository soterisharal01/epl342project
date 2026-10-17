# Ασθενείς οντότητες: έλεγχος του κανόνα (1,1)

Κανόνας: η συμμετοχή της ασθενούς οντότητας στις προσδιορίζουσες συσχετίσεις είναι πάντα (1,1).

Αποτέλεσμα: ισχύει και στις 21 γραμμές (21 identifying relationships, 16 weak entities, καθεμία προσδιορίζεται από τουλάχιστον μία). Ελέγχθηκε στο model.js και στο mdms-er.erdplus. Ο έλεγχος είναι πλέον μέρος του `node erdplus-check.js`.

Το ERD+ γράφει το (min,max) μιας οντότητας στην **απέναντι** άκρη της γραμμής. Γι' αυτό το (1,1) της ασθενούς φαίνεται δίπλα στον ιδιοκτήτη (owner), και δίπλα στην ασθενή φαίνεται η συμμετοχή του ιδιοκτήτη.

| Relationship | Weak entity | Owner | (min,max) της weak | ERD+ το γράφει δίπλα στο | Δίπλα στη weak φαίνεται |
|---|---|---|---|---|---|
| IS_CONSUMER | CONSUMER | USER_ACCOUNT | (1,1) | USER_ACCOUNT | (0,1) |
| IS_TECHNICIAN | FIELD_TECHNICIAN | USER_ACCOUNT | (1,1) | USER_ACCOUNT | (0,1) |
| IS_MARKET_USER | MARKET_USER | USER_ACCOUNT | (1,1) | USER_ACCOUNT | (0,1) |
| IS_ADMIN | SYSTEM_ADMIN | USER_ACCOUNT | (1,1) | USER_ACCOUNT | (0,1) |
| IS_OPERATOR | SYSTEM_OPERATOR | USER_ACCOUNT | (1,1) | USER_ACCOUNT | (0,1) |
| IS_TSO | TSO_OPERATOR | USER_ACCOUNT | (1,1) | USER_ACCOUNT | (0,1) |
| IS_DSO | DSO_OPERATOR | USER_ACCOUNT | (1,1) | USER_ACCOUNT | (0,1) |
| HOLDS | HOLDING | CONSUMER | (1,1) | CONSUMER | (0,M) |
| HOLDING_OF | HOLDING | PREMISE | (1,1) | PREMISE | (0,M) |
| DECLARES | AVAILABILITY | FIELD_TECHNICIAN | (1,1) | FIELD_TECHNICIAN | (1,M) |
| HAS_NOTE | TASK_NOTE | FIELD_TASK | (1,1) | FIELD_TASK | (0,M) |
| TRIES | COMMAND_ATTEMPT | REMOTE_COMMAND | (1,1) | REMOTE_COMMAND | (0,M) |
| MEASURED | READING | METER | (1,1) | METER | (0,M) |
| READ_CODE | READING | OBIS_CODE | (1,1) | OBIS_CODE | (0,M) |
| HAS_EDIT | READING_EDIT | READING | (1,1) | READING | (0,M) |
| METER_AGG | METER_AGGREGATE | METER | (1,1) | METER | (0,M) |
| METER_AGG_CODE | METER_AGGREGATE | OBIS_CODE | (1,1) | OBIS_CODE | (0,M) |
| GEO_AGG | GEOFENCE_AGGREGATE | GEOFENCE | (1,1) | GEOFENCE | (0,M) |
| GEO_AGG_CODE | GEOFENCE_AGGREGATE | OBIS_CODE | (1,1) | OBIS_CODE | (0,M) |
| GEO_STATE | GEOFENCE_CURRENT_STATE | GEOFENCE | (1,1) | GEOFENCE | (0,M) |
| STATE_CODE | GEOFENCE_CURRENT_STATE | OBIS_CODE | (1,1) | OBIS_CODE | (0,M) |

Τα CONSUMER, FIELD_TECHNICIAN και READING είναι ασθενείς, αλλά στα HOLDS, DECLARES και HAS_EDIT είναι ο ιδιοκτήτης, όχι η οντότητα που προσδιορίζεται. Εκεί το (0,M) ή (1,M) είναι σωστό, γιατί ο κανόνας αφορά την οντότητα που προσδιορίζεται.
