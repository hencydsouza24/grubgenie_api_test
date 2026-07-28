# grubgenie-api-test

Skill for testing the GrubGenie food-ordering API (partner/diner/admin auth, cart, orders,
payments, menu, Petpooja POS, AI agent chat) across local/dev/prod. Bash and PowerShell
implementations with full parity — see `SKILL.md` for the actual instructions and usage; this
file is a pointer, not a second copy.

## Activate on

Testing or debugging GrubGenie endpoints; verifying a new backend feature; walking through
diner/partner/admin flows; reproducing an auth/permission bug; Petpooja POS integration work.

## Read first

1. **`SKILL.md`** — full instructions: quick start, core rules, script inventory, exit-code
   contract, common workflows. Read this before writing any curl or Invoke-RestMethod by hand.
2. **`references/setup.md`** — first-time dependency setup per OS.
3. **`references/api_reference.md`** — full route map when a script doesn't cover what you need.

## Non-negotiable rules (elaborated in SKILL.md)

- Script-first: every operation has a script in `scripts/`. Use it instead of hand-rolled HTTP
  calls — the scripts encode correct token extraction, request shape, and error handling that a
  fresh curl command reliably gets wrong.
- Check exit codes. `0`/`2`/`4`/`5`/`6`/`7` mean something specific — see SKILL.md's table.
  `set -e` does not reliably propagate through a failing `${VAR:?msg}` or nested command
  substitution in bash; a one-off check needs `if cmd; then ... else ... fi`, not a bare call.
- No script for what you need → use context-mode, not raw curl (keeps output out of context).

## Not here

Detailed workflows, the full API surface, and troubleshooting guides live in `SKILL.md` and
`references/`. Do not duplicate them into this file — that duplication is exactly what made the
old `SKILL.md` grow from 296 to 670 lines before this refactor.
