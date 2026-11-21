# =====================================================================
# save_credential.ps1 : stores YOUR SQL Server login for run_sql.ps1, once per machine.
#
#   powershell -ExecutionPolicy Bypass -File sql\tools\save_credential.ps1
#
# It asks for the username and password in the terminal (the password is not shown)
# and writes %USERPROFILE%\.mdms_sql.xml, encrypted with Windows DPAPI: only your
# Windows account on this machine can read it. Nothing is written to the repo.
# =====================================================================
$user = Read-Host 'SQL Server username (your department username)'
$pass = Read-Host 'SQL Server password' -AsSecureString
$cred = New-Object System.Management.Automation.PSCredential($user, $pass)
$file = Join-Path $env:USERPROFILE '.mdms_sql.xml'
$cred | Export-Clixml -Path $file
Write-Host "Saved to $file (encrypted for your Windows account only)."
