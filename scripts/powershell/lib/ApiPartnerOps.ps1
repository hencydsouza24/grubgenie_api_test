# Partner Ops domain verbs — PowerShell twin of ../../lib/api_partner_ops.sh. Bundles three
# read-heavy admin groups plus the four new Table chair actions that don't yet have a home in
# Api.ps1's existing Get-GgTables/Set-GgTableStatus:
#   - AllOutlets  (/v1/partner/all-outlets)  — cross-branch rollup reads + one write (mark-read)
#   - Queue       (/v1/partner/queue)        — walk-in queue CRUD + 5 state-transition actions
#   - Role        (/v1/partner/roles)        — custom partner roles. NOTE: the route is mounted
#     at `/v1/partner/roles` (plural) in src/routes/v1/partner/index.ts, NOT `/v1/partner/role`.
#   - Table       (/v1/partner/table)        — split / merge / borrow-chair / return-chair, on
#     top of the table.route.ts base that Get-GgTables/Set-GgTableStatus already use.
#
# Expressed over Http.ps1 + Json.ps1, exactly like Api.ps1. Not yet dot-sourced by Bootstrap.ps1
# (wired centrally later to avoid collisions with sibling lib files being added in parallel) —
# scripts that need these functions dot-source this file directly, after Bootstrap.ps1.
#
# Bash -> PowerShell name mapping (mirrors Api.ps1's own header convention):
#   gg_all_outlets_list               -> Get-GgAllOutlets
#   gg_all_outlets_inquiries          -> Get-GgAllOutletsInquiries
#   gg_all_outlets_reservations       -> Get-GgAllOutletsReservations
#   gg_all_outlets_queue              -> Get-GgAllOutletsQueue
#   gg_all_outlets_notifications      -> Get-GgAllOutletsNotifications
#   gg_all_outlets_notifications_read -> Set-GgAllOutletsNotificationsRead
#   gg_queue_create                   -> New-GgQueueEntry
#   gg_queue_list                     -> Get-GgQueueEntries
#   gg_queue_get                      -> Get-GgQueueEntry
#   gg_queue_update                   -> Set-GgQueueEntry
#   gg_queue_delete                   -> Remove-GgQueueEntry
#   gg_queue_notify                   -> Invoke-GgQueueNotify
#   gg_queue_table_ready              -> Invoke-GgQueueTableReady
#   gg_queue_seat                     -> Invoke-GgQueueSeat
#   gg_queue_abandon                  -> Invoke-GgQueueAbandon
#   gg_queue_reopen                   -> Invoke-GgQueueReopen
#   gg_role_permission_catalog        -> Get-GgRolePermissionCatalog
#   gg_role_list                      -> Get-GgRoles
#   gg_role_create                    -> New-GgRole
#   gg_role_update                    -> Set-GgRole
#   gg_role_delete                    -> Remove-GgRole
#   gg_table_split                    -> Split-GgTable
#   gg_table_merge                    -> Merge-GgTable
#   gg_table_borrow_chair             -> Invoke-GgBorrowChair
#   gg_table_return_chair             -> Remove-GgBorrowedChair

if (Get-Variable -Name _GgApiPartnerOpsLoaded -Scope Script -ErrorAction SilentlyContinue) { return }
$Script:_GgApiPartnerOpsLoaded = $true

# ============================= AllOutlets =============================

function Get-GgAllOutlets {
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'all-outlets list' -Method GET -Path "$base/v1/partner/all-outlets/outlets" -Token $partnerToken
}

# Get-GgAllOutletsInquiries [-Query @{...}] — optional: branchId, page, limit, status, inquiryType, q.
function Get-GgAllOutletsInquiries {
    param([hashtable]$Query)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'all-outlets inquiries' -Method GET -Path "$base/v1/partner/all-outlets/inquiries" -Token $partnerToken -Query $Query
}

# Get-GgAllOutletsReservations [-Query @{...}] — `after` and `before` (ISO dates) are REQUIRED by
# allOutlets.validation.ts; include them in -Query, e.g. -Query @{ after = '2026-01-01'; before = '2026-01-31' }
function Get-GgAllOutletsReservations {
    param([hashtable]$Query)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'all-outlets reservations' -Method GET -Path "$base/v1/partner/all-outlets/reservations" -Token $partnerToken -Query $Query
}

# Get-GgAllOutletsQueue [-Query @{...}] — optional: branchId only.
function Get-GgAllOutletsQueue {
    param([hashtable]$Query)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'all-outlets queue' -Method GET -Path "$base/v1/partner/all-outlets/queue" -Token $partnerToken -Query $Query
}

function Get-GgAllOutletsNotifications {
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'all-outlets notifications' -Method GET -Path "$base/v1/partner/all-outlets/notifications" -Token $partnerToken
}

# Set-GgAllOutletsNotificationsRead <BranchId> <NotificationId...> → marks that one branch's
# notifications read (single group in the `items` array — this skill's scripts always drive one
# branch at a time, so a multi-branch batch would be unused flexibility). Returns the message.
function Set-GgAllOutletsNotificationsRead {
    param(
        [Parameter(Mandatory)][string]$BranchId,
        [Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$NotificationIds
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $body = @{ items = @(@{ branchId = $BranchId; notificationIds = @($NotificationIds) }) } | ConvertTo-Json -Compress -Depth 5
    $resp = Invoke-GgHttpOrDie -Label 'all-outlets notifications read' -Method PUT -Path "$base/v1/partner/all-outlets/notifications/read" -Token $partnerToken -JsonBody $body
    return Get-GgJsonMessage -Json $resp
}

# ============================= Queue =============================

# New-GgQueueEntry <GuestName> <GuestPhone> <PartySize> [-QuotedWaitMin N] [-PreferenceNote S] →
# the created entry's queueId.
function New-GgQueueEntry {
    param(
        [Parameter(Mandatory)][string]$GuestName,
        [Parameter(Mandatory)][string]$GuestPhone,
        [Parameter(Mandatory)][int]$PartySize,
        [int]$QuotedWaitMin,
        [string]$PreferenceNote
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $fields = @{ guestName = $GuestName; guestPhone = $GuestPhone; partySize = $PartySize }
    if ($PSBoundParameters.ContainsKey('QuotedWaitMin')) { $fields['quotedWaitMin'] = $QuotedWaitMin }
    if ($PreferenceNote) { $fields['preferenceNote'] = $PreferenceNote }
    $body = $fields | ConvertTo-Json -Compress
    $resp = Invoke-GgHttpOrDie -Label 'queue create' -Method POST -Path "$base/v1/partner/queue" -Token $partnerToken -JsonBody $body
    return Get-GgJsonField -Json $resp -Path '.result._id' -Label 'queueId'
}

# Get-GgQueueEntries [-Query @{...}] — optional: include=all, status, joinedAfter, joinedBefore, q, limit.
function Get-GgQueueEntries {
    param([hashtable]$Query)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'queue list' -Method GET -Path "$base/v1/partner/queue" -Token $partnerToken -Query $Query
}

function Get-GgQueueEntry {
    param([Parameter(Mandatory)][string]$QueueId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'queue get' -Method GET -Path "$base/v1/partner/queue/$QueueId" -Token $partnerToken
}

# Set-GgQueueEntry <QueueId> [-GuestName S] [-GuestPhone S] [-PartySize N] [-QuotedWaitMin N]
# [-PreferenceNote S] — only the fields you pass are sent; at least one is required
# (queue.validation.ts: body.min(1)).
function Set-GgQueueEntry {
    param(
        [Parameter(Mandatory)][string]$QueueId,
        [string]$GuestName,
        [string]$GuestPhone,
        [int]$PartySize,
        [int]$QuotedWaitMin,
        [string]$PreferenceNote
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $fields = @{}
    if ($GuestName) { $fields['guestName'] = $GuestName }
    if ($GuestPhone) { $fields['guestPhone'] = $GuestPhone }
    if ($PSBoundParameters.ContainsKey('PartySize')) { $fields['partySize'] = $PartySize }
    if ($PSBoundParameters.ContainsKey('QuotedWaitMin')) { $fields['quotedWaitMin'] = $QuotedWaitMin }
    if ($PreferenceNote) { $fields['preferenceNote'] = $PreferenceNote }
    $body = $fields | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'queue update' -Method PUT -Path "$base/v1/partner/queue/$QueueId" -Token $partnerToken -JsonBody $body
}

# Remove-GgQueueEntry <QueueId> → the response message.
function Remove-GgQueueEntry {
    param([Parameter(Mandatory)][string]$QueueId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $resp = Invoke-GgHttpOrDie -Label 'queue delete' -Method DELETE -Path "$base/v1/partner/queue/$QueueId" -Token $partnerToken
    return Get-GgJsonMessage -Json $resp
}

# Invoke-GgQueueNotify <QueueId> — `notify` takes an empty body (queueValidation.transitionEmpty).
function Invoke-GgQueueNotify {
    param([Parameter(Mandatory)][string]$QueueId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $resp = Invoke-GgHttpOrDie -Label 'queue notify' -Method POST -Path "$base/v1/partner/queue/$QueueId/notify" -Token $partnerToken -JsonBody '{}'
    return Get-GgJsonMessage -Json $resp
}

# Invoke-GgQueueTableReady <QueueId> [-TableId Id] — body: {tableId?} (queueValidation.transitionSeat).
function Invoke-GgQueueTableReady {
    param([Parameter(Mandatory)][string]$QueueId, [string]$TableId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $fields = @{}
    if ($TableId) { $fields['tableId'] = $TableId }
    $body = $fields | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'queue table-ready' -Method POST -Path "$base/v1/partner/queue/$QueueId/table-ready" -Token $partnerToken -JsonBody $body
}

# Invoke-GgQueueSeat <QueueId> [-TableId Id] — same body shape as table-ready (both use transitionSeat).
function Invoke-GgQueueSeat {
    param([Parameter(Mandatory)][string]$QueueId, [string]$TableId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $fields = @{}
    if ($TableId) { $fields['tableId'] = $TableId }
    $body = $fields | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'queue seat' -Method POST -Path "$base/v1/partner/queue/$QueueId/seat" -Token $partnerToken -JsonBody $body
}

# Invoke-GgQueueAbandon <QueueId> [-Reason staff|converted] — omit to leave unset.
function Invoke-GgQueueAbandon {
    param([Parameter(Mandatory)][string]$QueueId, [ValidateSet('staff', 'converted')][string]$Reason)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $fields = @{}
    if ($Reason) { $fields['reason'] = $Reason }
    $body = $fields | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'queue abandon' -Method POST -Path "$base/v1/partner/queue/$QueueId/abandon" -Token $partnerToken -JsonBody $body
}

# Invoke-GgQueueReopen <QueueId> — empty body (queueValidation.transitionEmpty). Returns the message.
function Invoke-GgQueueReopen {
    param([Parameter(Mandatory)][string]$QueueId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $resp = Invoke-GgHttpOrDie -Label 'queue reopen' -Method POST -Path "$base/v1/partner/queue/$QueueId/reopen" -Token $partnerToken -JsonBody '{}'
    return Get-GgJsonMessage -Json $resp
}

# ============================= Role =============================
# NOTE: mounted at /v1/partner/roles (plural) — see file header.

# Get-GgRolePermissionCatalog [-RoleKey K] — RoleKey is optional.
function Get-GgRolePermissionCatalog {
    param([string]$RoleKey)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $query = if ($RoleKey) { @{ roleKey = $RoleKey } } else { $null }
    return Invoke-GgHttpOrDie -Label 'role permission catalog' -Method GET -Path "$base/v1/partner/roles/permission-catalog" -Token $partnerToken -Query $query
}

function Get-GgRoles {
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'role list' -Method GET -Path "$base/v1/partner/roles" -Token $partnerToken
}

# New-GgRole <Name> <Permission...> — permission values must be real leaves from the permission
# vocabulary (src/config/roles.ts), e.g. `readBranch`, `getQueue`, `createQueueEntry` — not
# made-up strings; the server 400s on anything outside that vocabulary.
function New-GgRole {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Permissions
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $body = @{ name = $Name; permissions = @($Permissions) } | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'role create' -Method POST -Path "$base/v1/partner/roles" -Token $partnerToken -JsonBody $body
}

# Set-GgRole <RoleId> [-Name N] [-Permissions P1,P2,...] — at least one of Name/Permissions must
# be supplied (role.validation.ts: `.or('name', 'permissions')`).
function Set-GgRole {
    param(
        [Parameter(Mandatory)][string]$RoleId,
        [string]$Name,
        [string[]]$Permissions
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $fields = @{}
    if ($Name) { $fields['name'] = $Name }
    if ($Permissions -and $Permissions.Count -gt 0) { $fields['permissions'] = @($Permissions) }
    $body = $fields | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'role update' -Method PUT -Path "$base/v1/partner/roles/$RoleId" -Token $partnerToken -JsonBody $body
}

# Remove-GgRole <RoleId> → the response message.
function Remove-GgRole {
    param([Parameter(Mandatory)][string]$RoleId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $resp = Invoke-GgHttpOrDie -Label 'role delete' -Method DELETE -Path "$base/v1/partner/roles/$RoleId" -Token $partnerToken
    return Get-GgJsonMessage -Json $resp
}

# ============================= Table actions (new) =============================
# Additional to Get-GgTables/Set-GgTableStatus already in Api.ps1. Confirmed directly against
# src/routes/v1/partner/table.route.ts + table.validation.ts + table.controller.ts — all four
# routes live under the SAME /v1/partner/table base as the existing table functions.

# Split-GgTable <TableId> <Segment...> — 2 to 4 seat-count integers that the table's current seats
# get divided into (table.validation.ts: segments min 2, max 4).
function Split-GgTable {
    param(
        [Parameter(Mandatory)][string]$TableId,
        [Parameter(Mandatory, ValueFromRemainingArguments)][int[]]$Segments
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $body = @{ segments = @($Segments) } | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'table split' -Method POST -Path "$base/v1/partner/table/$TableId/split" -Token $partnerToken -JsonBody $body
}

# Merge-GgTable <TableId> — merges this table's split segments back together. No body.
function Merge-GgTable {
    param([Parameter(Mandatory)][string]$TableId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'table merge' -Method POST -Path "$base/v1/partner/table/$TableId/merge" -Token $partnerToken -JsonBody '{}'
}

# Invoke-GgBorrowChair <TableId> <FromTableId> [-Count N] — borrows Count (default 1, per
# table.validation.ts) chairs from FromTableId onto TableId. Response is the updated table doc;
# its `borrowedChairs[]` entries each carry their own `_id`, which is the BorrowId that
# Remove-GgBorrowedChair needs — read it out of this call's output (e.g. `.result.borrowedChairs`)
# rather than this script auto-chaining, matching the skill's existing style of explicit-id args.
function Invoke-GgBorrowChair {
    param(
        [Parameter(Mandatory)][string]$TableId,
        [Parameter(Mandatory)][string]$FromTableId,
        [int]$Count
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $fields = @{ fromTableId = $FromTableId }
    if ($PSBoundParameters.ContainsKey('Count')) { $fields['count'] = $Count }
    $body = $fields | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'table borrow chair' -Method POST -Path "$base/v1/partner/table/$TableId/borrow-chair" -Token $partnerToken -JsonBody $body
}

# Remove-GgBorrowedChair <TableId> <BorrowId> — DELETE, not POST: confirmed against
# table.route.ts (`router.delete('/:tableId/borrow-chair/:borrowId', ...)`). No body; both the
# table and the specific borrow record (its `_id` from Invoke-GgBorrowChair's response) are path
# params.
function Remove-GgBorrowedChair {
    param(
        [Parameter(Mandatory)][string]$TableId,
        [Parameter(Mandatory)][string]$BorrowId
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'table return chair' -Method DELETE -Path "$base/v1/partner/table/$TableId/borrow-chair/$BorrowId" -Token $partnerToken
}
