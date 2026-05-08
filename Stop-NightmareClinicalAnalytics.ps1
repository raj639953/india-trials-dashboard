$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pidFile = Join-Path $ProjectDir "server.pid"

if (-not (Test-Path -LiteralPath $pidFile)) {
    Write-Host "No server.pid file found."
    exit 0
}

$serverPid = [int](Get-Content -LiteralPath $pidFile -Raw)
$process = Get-Process -Id $serverPid -ErrorAction SilentlyContinue
if ($process) {
    Stop-Process -Id $serverPid -Force
    Write-Host "Stopped Nightmare Clinical Analytics server."
} else {
    Write-Host "Server process was not running."
}
Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
