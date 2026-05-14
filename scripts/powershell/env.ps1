param([string]$Env = "local")
# Usage: . $SKILL\env.ps1 [local|dev|prod]

switch ($Env) {
    "local" { $env:BASE = "http://localhost:3000" }
    "dev"   { $env:BASE = "https://dev-backend.grubgenie.ai" }
    "prod"  { $env:BASE = "https://backend.grubgenie.ai" }
    default { Write-Error "Unknown environment '$Env'. Use: local | dev | prod"; exit 1 }
}

Write-Host "Environment: $Env -> $env:BASE" -ForegroundColor Green
