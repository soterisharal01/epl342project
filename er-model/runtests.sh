#!/bin/bash
# Runs the schema on SQL Server and records the results the schema page shows.
# Needs a SQL Server 2025 container named mssql, for example:
#   docker run -d --name mssql -e ACCEPT_EULA=Y -e 'MSSQL_SA_PASSWORD=<password>' -p 1433:1433 mcr.microsoft.com/mssql/server:2025-latest
#   MSSQL_SA_PASSWORD=<password> ./runtests.sh
# Steps: fresh database epl342test, create.sql, object counts, test.sql, drop.sql, create.sql again.
# Writes test-results.json and test-env.json, which build-schema.js reads (it refuses to build if a test failed).
cd "$(dirname "$0")"
PW=${MSSQL_SA_PASSWORD:?set MSSQL_SA_PASSWORD}
S="docker exec mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $PW -C -b"
run() { docker cp "$1" mssql:/tmp/run.sql >/dev/null && $S -d epl342test -i /tmp/run.sql; }
OUT=$(mktemp)
$S -Q "IF DB_ID('epl342test') IS NOT NULL BEGIN ALTER DATABASE epl342test SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE epl342test; END; CREATE DATABASE epl342test;" || exit 1
run create.sql || { echo CREATE FAILED; exit 1; }
counts=$(run counts.sql | awk 'NR>2 && NF {n=$NF; $NF=""; sub(/ +$/,""); printf "%s\"%s\":%s", (c++?",":""), $0, n}')
docker cp test.sql mssql:/tmp/test.sql >/dev/null
$S -d epl342test -y 0 -i /tmp/test.sql > "$OUT" 2>&1 || { echo TEST SCRIPT FAILED; cat "$OUT"; exit 1; }
tr -d '\n\r' < "$OUT" > test-results.json
run drop.sql || { echo DROP FAILED; exit 1; }
left=$($S -d epl342test -h -1 -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.tables" | tr -d ' \r\n')
run create.sql || { echo RECREATE FAILED; exit 1; }
again=$($S -d epl342test -h -1 -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.tables" | tr -d ' \r\n')
ver=$($S -h -1 -Q "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar(20)) + '|' + CAST(SERVERPROPERTY('ProductUpdateLevel') AS varchar(20)) + '|' + CAST(SERVERPROPERTY('Edition') AS varchar(60))" | tr -d '\r\n' | sed 's/ *$//')
echo "{\"version\":\"$ver\",\"counts\":{$counts},\"afterDrop\":$left,\"afterRecreate\":$again,\"date\":\"$(date -u +%Y-%m-%d)\"}" > test-env.json
cat test-env.json; echo
node -e "
const r=JSON.parse(require('fs').readFileSync('test-results.json','utf8'));
let bad=0; for(const x of r){const pass = x.expected==='OK' ? x.got==='OK' : x.got.includes(x.expected); if(!pass){bad++; console.log('FAIL', x.n, 'expected', x.expected, 'got', x.got.slice(0,250));}}
console.log('results', r.length, 'failed', bad);"
