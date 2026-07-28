# GrubGenie API test skill — shared library bootstrap (PowerShell twin of ../../lib/bootstrap.sh).
# Every script dot-sources ONLY this file:
#   . "$PSScriptRoot/lib/Bootstrap.ps1"
#
# Dot-sourced (not a module): dot-sourcing merges these functions into the CALLER's scope, which
# is exactly what bash `source` does. A .psm1 module would add an export surface, a module cache
# that can serve stale definitions mid-development, and a scope boundary forcing $script:/$global:
# gymnastics — three things that would make the two languages diverge structurally for nothing.

if (Get-Variable -Name _GgLoaded -Scope Script -ErrorAction SilentlyContinue) { return }
$Script:_GgLoaded = $true

$ErrorActionPreference = 'Stop'

$Script:GgLibDir = $PSScriptRoot
$Script:GgSkillDir = Split-Path $PSScriptRoot -Parent

# PowerShell 5.1 doesn't negotiate TLS 1.2 by default on some Windows configurations, which
# breaks HTTPS to dev/prod out of the box.
if ($PSVersionTable.PSVersion.Major -lt 6) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch {
        # Best-effort; if this fails, HTTPS calls will surface their own connection error.
    }
}

. "$Script:GgLibDir/Constants.ps1"
. "$Script:GgLibDir/Log.ps1"
. "$Script:GgLibDir/Env.ps1"
. "$Script:GgLibDir/Json.ps1"
. "$Script:GgLibDir/Http.ps1"
. "$Script:GgLibDir/Auth.ps1"
. "$Script:GgLibDir/Api.ps1"
