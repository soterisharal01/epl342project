# =====================================================================
# run_sql.ps1 : runs SQL on the department server from a terminal, without SSMS or sqlcmd.
# Uses the .NET SqlClient built into Windows, and the login saved by save_credential.ps1.
# The password is never printed or passed on the command line.
#
#   powershell -ExecutionPolicy Bypass -File sql\tools\run_sql.ps1 -Query "SELECT COUNT(*) FROM sys.tables"
#   powershell -ExecutionPolicy Bypass -File sql\tools\run_sql.ps1 -File sql\build\ALL.sql
#   ... -File sql\drop.sql -AllowDestructive        (required for DROP / DELETE / TRUNCATE)
#
# Defaults: server mssql.cs.ucy.ac.cy\SQL2025, database = your username (your own database).
# Scripts are split on lines that contain only GO, like SSMS. PRINT output and result sets
# are shown. It stops at the first error (like sqlcmd -b) and exits with code 1.
# =====================================================================
param(
    [string]$Query,
    [string]$File,
    [string]$Database,
    [string]$Server = 'mssql.cs.ucy.ac.cy\SQL2025',
    [switch]$AllowDestructive,
    [int]$Timeout = 600
)
$ErrorActionPreference = 'Stop'
$credFile = Join-Path $env:USERPROFILE '.mdms_sql.xml'
if (-not (Test-Path $credFile)) { Write-Host 'No saved login. Run sql\tools\save_credential.ps1 first.'; exit 1 }
$cred = Import-Clixml $credFile
if (-not $Database) { $Database = $cred.UserName }

if ($File) { $text = [IO.File]::ReadAllText((Resolve-Path $File), [Text.Encoding]::UTF8) }
elseif ($Query) { $text = $Query }
else { Write-Host 'Give -Query "..." or -File path.sql'; exit 1 }

if (-not $AllowDestructive -and $text -match '(?im)^\s*(DROP\s+(TABLE|DATABASE)|TRUNCATE\s+TABLE|DELETE\s)') {
    Write-Host 'The SQL contains DROP / TRUNCATE / DELETE. Re-run with -AllowDestructive if that is intended.'
    exit 1
}

$b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$b['Data Source'] = $Server
$b['Initial Catalog'] = $Database
$b['User ID'] = $cred.UserName
$b['Password'] = $cred.GetNetworkCredential().Password
$b['Encrypt'] = $true
$b['TrustServerCertificate'] = $true
$b['Connect Timeout'] = 15
$b['Application Name'] = 'mdms run_sql.ps1'
$cn = New-Object System.Data.SqlClient.SqlConnection $b.ConnectionString
$b = $null
$cn.add_InfoMessage({ param($s, $e) foreach ($m in $e.Errors) { Write-Host $m.Message } })

$batches = [regex]::Split($text, '(?im)^\s*GO\s*$') | Where-Object { $_.Trim() -ne '' }
$failed = $false
try {
    $cn.Open()
    # One database, several sessions/agents: a full script run (drop + rebuild + tests) holds an exclusive
    # session lock, so runs queue up instead of wiping each other's objects halfway. Released on disconnect.
    if ($File -or $AllowDestructive) {
        $lk = $cn.CreateCommand()
        $lk.CommandTimeout = 0
        $lk.CommandText = "DECLARE @r INT; EXEC @r = sp_getapplock @Resource = N'mdms_run_sql', @LockMode = 'Exclusive', @LockOwner = 'Session', @LockTimeout = 1800000; SELECT @r;"
        Write-Host 'Waiting for the database lock (other runs finish first)...'
        $r = [int]$lk.ExecuteScalar()
        if ($r -lt 0) { Write-Host "Could not get the database lock (code $r)."; exit 1 }
        Write-Host 'Database lock acquired.'
    }
    $setup = $cn.CreateCommand()
    $setup.CommandText = 'SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;'
    [void]$setup.ExecuteNonQuery()
    $n = 0
    foreach ($batch in $batches) {
        $n++
        $cmd = $cn.CreateCommand()
        $cmd.CommandText = $batch
        $cmd.CommandTimeout = $Timeout
        try {
            $rd = $cmd.ExecuteReader()
            # DataTable.Load reads one result set and moves to the next one itself
            # (or closes the reader after the last), so only call NextResult for sets without columns.
            while (-not $rd.IsClosed) {
                if ($rd.FieldCount -gt 0) {
                    $dt = New-Object System.Data.DataTable
                    $dt.Load($rd)
                    if ($dt.Rows.Count -gt 0) { $dt | Format-Table -AutoSize | Out-String -Width 250 | Write-Host }
                    else { Write-Host '(0 rows)' }
                } elseif (-not $rd.NextResult()) {
                    $rd.Close()
                }
            }
        } catch {
            $msg = $_.Exception.InnerException; if (-not $msg) { $msg = $_.Exception }
            Write-Host "ERROR in batch $n of $($batches.Count): $($msg.Message)"
            $first = ($batch.Trim() -split "`n")[0]
            Write-Host "  batch starts with: $first"
            $failed = $true
            break
        }
    }
} catch {
    Write-Host "CONNECTION ERROR: $($_.Exception.Message)"
    $failed = $true
} finally {
    $cn.Close()
}
if ($failed) { exit 1 }
