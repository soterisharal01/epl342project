#!/usr/bin/env bash
# =====================================================================
# test_local.sh : για το Claude (ή όποιον έχει Docker). Στήνει από το μηδέν
# μια τοπική βάση σε SQL Server 2025 και τρέχει ΟΛΑ με τη σειρά Α9 + τα tests.
# ΔΕΝ αγγίζει τη βάση του Τμήματος.
#
#   bash sql/tools/test_local.sh
#
# Πρώτη φορά στήνει container "mssql" (image mcr.microsoft.com/mssql/server:2025-latest).
# Ο κωδικός sa είναι τοπικός, τυχαίος, και γράφεται στο ~/.mdms_sa (όχι στο repo).
# Αποτέλεσμα: "ALL OK" ή το πρώτο λάθος.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."
SUDO=""; [ "$(id -u)" != 0 ] && command -v sudo >/dev/null && SUDO=sudo
PWFILE="$HOME/.mdms_sa"
[ -f "$PWFILE" ] || echo "Mdms$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')!" > "$PWFILE"
PW=$(cat "$PWFILE")

if ! $SUDO docker info >/dev/null 2>&1; then
  ($SUDO dockerd > /tmp/dockerd.log 2>&1 &) ; sleep 6
fi
if ! $SUDO docker ps -a --format '{{.Names}}' | grep -qx mssql; then
  $SUDO docker run -d --name mssql -e ACCEPT_EULA=Y -e "MSSQL_SA_PASSWORD=$PW" -p 1433:1433 \
    mcr.microsoft.com/mssql/server:2025-latest >/dev/null
  sleep 25
fi
$SUDO docker start mssql >/dev/null
SQL() { $SUDO docker exec mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$PW" -C -I -f 65001 -b "$@"; }
for i in $(seq 1 30); do SQL -Q "SELECT 1" >/dev/null 2>&1 && break; sleep 2; done

SQL -Q "IF DB_ID('mdms_test') IS NOT NULL BEGIN ALTER DATABASE mdms_test SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE mdms_test; END; CREATE DATABASE mdms_test;" >/dev/null

python3 sql/tools/build_all.py --tests >/dev/null
$SUDO docker cp sql/build/ALL.sql mssql:/tmp/ALL.sql
if SQL -d mdms_test -i /tmp/ALL.sql > /tmp/mdms_test.log 2>&1; then
  grep -E "FAIL|OK" /tmp/mdms_test.log | tail -40 || true
  if grep -q "FAIL" /tmp/mdms_test.log; then echo "ΥΠΑΡΧΟΥΝ FAIL (δες /tmp/mdms_test.log)"; exit 1; fi
  echo "ALL OK"
else
  tail -20 /tmp/mdms_test.log
  echo "ΛΑΘΟΣ (όλο το log: /tmp/mdms_test.log)"; exit 1
fi
