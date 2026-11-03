# Reservation widget embed config (partner-side, X-Api-Key auth) + public (unauthenticated)
# reservation self-service, keyed by a signed `ref` token (NOT a plain Mongo id).
# Usage: pwsh ./reservation.ps1 embed
#        pwsh ./reservation.ps1 public review <ref>
#        pwsh ./reservation.ps1 public get <ref>
#        pwsh ./reservation.ps1 public availability <ref> <date> <partySize>
#        pwsh ./reservation.ps1 public modify <ref> [startAt] [partySize]
#        pwsh ./reservation.ps1 public cancel <ref> [reason]
param(
    [Parameter(Mandatory, Position = 0)][ValidateSet('embed', 'public')][string]$Command,
    [Parameter(Position = 1)][string]$Sub,
    [Parameter(Position = 2)][string]$Ref,
    [Parameter(Position = 3)][string]$Arg1,
    [Parameter(Position = 4)][string]$Arg2
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

switch ($Command) {
    'embed' {
        Get-GgReservationWidgetEmbed
    }
    'public' {
        if (-not $Sub) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: reservation.ps1 public review|get|availability|modify|cancel <ref> [args]' }
        if (-not $Ref) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Usage: reservation.ps1 public $Sub <ref> [args]" }
        switch ($Sub) {
            'review'       { Get-GgPublicReservationReview -Ref $Ref }
            'get'          { Get-GgPublicReservation -Ref $Ref }
            'availability' { Get-GgPublicReservationAvailability -Ref $Ref -Date $Arg1 -PartySize $Arg2 }
            'modify'       { Update-GgPublicReservation -Ref $Ref -StartAt $Arg1 -PartySize $Arg2 }
            'cancel'       { Cancel-GgPublicReservation -Ref $Ref -Reason $Arg1 }
            default        { Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown public subcommand: $Sub (expected review|get|availability|modify|cancel)" }
        }
    }
}
