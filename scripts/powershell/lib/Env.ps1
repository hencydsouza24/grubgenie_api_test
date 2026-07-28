# Environment name -> BASE URL resolution. Dot-sourced by Bootstrap.ps1. Mirrors scripts/lib/env.sh.

if (Get-Variable -Name _GgEnvLoaded -Scope Script -ErrorAction SilentlyContinue) { return }
$Script:_GgEnvLoaded = $true

# Get-GgEnvName → the environment name in effect ($env:GG_ENV, default "local").
function Get-GgEnvName {
    if ($env:GG_ENV) { return $env:GG_ENV }
    return 'local'
}

# Resolve-GgBase [-Name env_name] → BASE url.
# Precedence: explicit $env:BASE (when no -Name given) > mapped default.
function Resolve-GgBase {
    param([string]$Name)

    if (-not $Name) {
        if ($env:BASE) { return $env:BASE }
        $Name = Get-GgEnvName
    }

    switch ($Name) {
        'local' { return $Script:GgEnvLocal }
        'dev'   { return $Script:GgEnvDev }
        'prod'  { return $Script:GgEnvProd }
        default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown environment: $Name (expected local|dev|prod)" }
    }
}

# Get-GgTempDir → honors $env:TMPDIR first (as bash does) so the session file that Auth.ps1
# writes lands at the SAME path a bash script on the same machine would use — this is what
# makes the session file work as a genuine cross-language handoff, not just a bash convenience.
function Get-GgTempDir {
    if ($env:TMPDIR) { return $env:TMPDIR.TrimEnd('/', '\') }
    return ([System.IO.Path]::GetTempPath()).TrimEnd('/', '\')
}
