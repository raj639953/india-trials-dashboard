$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$NodeCandidates = @(
    "C:\Users\raj63\AppData\Local\OpenAI\Codex\bin\node.exe",
    "node.exe"
)

$node = $null
foreach ($candidate in $NodeCandidates) {
    try {
        $command = Get-Command $candidate -ErrorAction Stop
        $node = $command.Source
        break
    } catch {}
}

if (-not $node) {
    throw "Node.js runtime was not found."
}

$envFile = Join-Path $ProjectDir ".env"
$port = 4321
if (Test-Path -LiteralPath $envFile) {
    foreach ($line in Get-Content -LiteralPath $envFile) {
        if ($line -match "^\s*PORT\s*=\s*(\d+)\s*$") {
            $port = [int]$Matches[1]
        }
    }
}

try {
    $health = Invoke-RestMethod -Uri "http://localhost:$port/api/health" -TimeoutSec 2
    if ($health.ok) {
        Write-Host "Nightmare Clinical Analytics is already running at http://localhost:$port"
        exit 0
    }
} catch {}

$server = Join-Path $ProjectDir "server.js"
$process = Start-Process -FilePath $node -ArgumentList "`"$server`"" -WorkingDirectory $ProjectDir -WindowStyle Hidden -PassThru
$process.Id | Set-Content -LiteralPath (Join-Path $ProjectDir "server.pid")
Start-Sleep -Seconds 2

try {
    $health = Invoke-RestMethod -Uri "http://localhost:$port/api/health" -TimeoutSec 5
    if ($health.ok) {
        Write-Host "Nightmare Clinical Analytics started at http://localhost:$port"
        exit 0
    }
} catch {
    throw "Server process started but health check failed."
}
