# GrubGenie skill eval harness (PowerShell launcher). Usage: run_evals.ps1 [-Mode offline|live|all]
# Thin wrapper: the checks themselves are bash scripts (portable via Git Bash on Windows too),
# so this just resolves a bash and delegates, keeping exactly one implementation of the runner.
param(
    [ValidateSet('offline', 'live', 'all')]
    [string]$Mode = 'offline'
)

$SkillDir = Split-Path $PSScriptRoot -Parent
$bash = Get-Command bash -ErrorAction SilentlyContinue
if (-not $bash) {
    Write-Error "bash not found on PATH — install Git for Windows (provides Git Bash) or WSL to run evals."
    exit 2
}

& $bash.Source "$PSScriptRoot/run_evals.sh" "--$Mode"
exit $LASTEXITCODE
