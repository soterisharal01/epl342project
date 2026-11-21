| Table | Chen shape | In relational | In Chen |
|---|---|---|---|
| `SUPPLIER` | entity | yes | yes |
| `AGGREGATOR` | entity | yes | yes |
| `USER_ACCOUNT` | entity | yes | yes |
| `CONSUMER_NOTIFICATION_CHANNEL` | multivalued attribute of USER_ACCOUNT | yes | yes |
| `DISTRICT` | entity | yes | yes |
| `MUNICIPALITY` | entity | yes | yes |
| `PARISH` | entity | yes | yes |
| `SUPPLY_SCHEME` | entity | yes | yes |
| `PREMISE` | entity | yes | yes |
| `CONSUMPTION_THRESHOLD` | entity | yes | yes |
| `METER_MODEL` | entity | yes | yes |
| `COMM_TYPE` | entity | yes | yes |
| `GEOFENCE` | entity | yes | yes |
| `TRANSFORMER` | entity | yes | yes |
| `METER` | entity | yes | yes |
| `SERVICE_REQUEST` | entity | yes | yes |
| `HOLDING` | M:N relationship | yes | yes |
| `BANK_ACCOUNT` | entity | yes | yes |
| `TARIFF_TYPE` | entity | yes | yes |
| `SUPPLY_CONTRACT` | entity | yes | yes |
| `INVOICE` | entity | yes | yes |
| `PAYMENT` | entity | yes | yes |
| `SERVICE_TYPE` | entity | yes | yes |
| `SERVICE_PURCHASE` | entity | yes | yes |
| `ACCOUNT_FOR` | M:N relationship | yes | yes |
| `TECHNICIAN_CATEGORY` | entity | yes | yes |
| `DOCUMENT` | entity | yes | yes |
| `FIELD_TASK` | entity | yes | yes |
| `ATTACHMENT` | entity | yes | yes |
| `AVAILABILITY` | weak entity | yes | yes |
| `TASK_NOTE` | weak entity | yes | yes |
| `IN_CATEGORY` | M:N relationship | yes | yes |
| `AVAILABLE_IN` | M:N relationship | yes | yes |
| `NOTIFIES` | M:N relationship | yes | yes |
| `TELEMETRY_PACKET` | entity | yes | yes |
| `EVENT` | entity | yes | yes |
| `LEADS_TO` | M:N relationship | yes | yes |
| `METER_INSTALLATION` | entity | yes | yes |
| `LOAD_SHED_ORDER` | entity | yes | yes |
| `REMOTE_COMMAND` | entity | yes | yes |
| `COMMAND_ATTEMPT` | weak entity | yes | yes |
| `METER_CONNECTED_PHASE` | multivalued attribute of METER | yes | yes |
| `OBIS_CODE` | entity | yes | yes |
| `VEE_RULE` | entity | yes | yes |
| `VEE_RUN` | entity | yes | yes |
| `RAW_READING` | weak entity | yes | yes |
| `VALIDATED_READING` | weak entity | yes | yes |
| `READING_EDIT` | weak entity | yes | yes |
| `RULE_FOR` | M:N relationship | yes | yes |
| `METER_AGGREGATE` | weak entity | yes | yes |
| `TRANSFORMER_AGGREGATE` | weak entity | yes | yes |
| `TRANSFORMER_CURRENT_STATE` | M:N relationship | yes | yes |
| `PORTFOLIO` | entity | yes | yes |
| `INCLUDES` | M:N relationship | yes | yes |
| `GDPR_REQUEST` | entity | yes | yes |
| `AUDIT_LOG` | entity | yes | yes |
