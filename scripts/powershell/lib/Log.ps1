# Structured narration — host/error stream only, never the success (pipeline) stream.
# Dot-sourced by Bootstrap.ps1. Mirrors scripts/lib/log.sh.

if (Get-Variable -Name _GgLogLoaded -Scope Script -ErrorAction SilentlyContinue) { return }
$Script:_GgLogLoaded = $true

# All narration goes through [Console]::Error, NOT Write-Host. Write-Host writes to the host's
# console stream, which — when a caller captures output via `$x = pwsh -Command "..."` (exactly
# how bash callers do `body=$(gg_get ...)`) — still lands on the process's real stdout and
# corrupts the "stdout carries exactly one value" contract this whole library exists to enforce.
# [Console]::Error.WriteLine is unambiguous: real OS stderr (fd 2), matching bash's `>&2`.
function Write-GgInfo  { param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Message) [Console]::Error.WriteLine("[info] $($Message -join ' ')") }
function Write-GgWarn  { param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Message) [Console]::Error.WriteLine("[warn] $($Message -join ' ')") }
function Write-GgError { param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Message) [Console]::Error.WriteLine("[error] $($Message -join ' ')") }

function Write-GgStep {
    param([Parameter(Mandatory)][string]$Number, [Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Title)
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("=== Step ${Number}: $($Title -join ' ') ===")
}

function Write-GgKv {
    param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Value)
    # The extra parens around the `-f` expression are load-bearing: inside a method call's
    # argument list, a bare comma is parsed as the METHOD's own argument separator, not as part
    # of `-f`'s array — without them, $Value silently becomes WriteLine's second argument
    # instead of `-f`'s, and "{1}" in the format string has nothing left to bind to.
    [Console]::Error.WriteLine(("  {0,-14} {1}" -f "${Key}:", $Value))
}

# Exit-GgDie <exit_code> <message...> — always terminates the current process. Each script here
# runs as its own `pwsh script.ps1` process, so this mirrors bash's `exit` inside gg_die exactly.
function Exit-GgDie {
    param([Parameter(Mandatory)][int]$ExitCode, [Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Message)
    Write-GgError ($Message -join ' ')
    exit $ExitCode
}
