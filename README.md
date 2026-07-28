# GrubGenie API Test — Claude Code Skill

A [Claude Code skill](https://docs.anthropic.com/en/docs/claude-code/skills) that gives Claude ready-to-run scripts and deep knowledge of all GrubGenie API flows.

## What it does

- Authenticates as partner, diner, or admin
- Runs complete E2E flows: dine-in, pay-in-person, Stripe, order approval/rejection, combo ordering
- Covers all environments: local, dev, prod
- Works on **macOS / Linux** (bash + curl + jq) and **Windows** (PowerShell or Git Bash)

## Installation

Clone into your Claude skills directory:

```bash
git clone https://github.com/hencydsouza24/grubgenie_api_test.git \
  ~/.claude/skills/grubgenie-api-test
```

Claude Code picks it up automatically — no restart needed.

## Prerequisites

### macOS / Linux / Git Bash on Windows

- `curl` (usually pre-installed)
- `jq` — `brew install jq` / `sudo apt install jq`
- For Git Bash on Windows: download `jq.exe` from [jqlang/jq releases](https://github.com/jqlang/jq/releases), place in `C:\Program Files\Git\usr\bin\`

### Windows PowerShell

No extra dependencies — `Invoke-RestMethod` is built in.

## Quick Start

### macOS / Linux / Git Bash

```bash
SKILL=~/.claude/skills/grubgenie-api-test/scripts

eval "$(bash $SKILL/env.sh local)"   # or dev / prod
eval "$(bash $SKILL/auth.sh)"

# Full E2E dine-in + pay
bash $SKILL/flow_dine_in_pay.sh 691bf10018f1d3c34db1db00 2
```

### Windows PowerShell

```powershell
$SKILL = "$HOME\.claude\skills\grubgenie-api-test\scripts\powershell"

. $SKILL\env.ps1 local    # or dev / prod
. $SKILL\auth.ps1

# Full E2E dine-in + pay
. $SKILL\flow_dine_in_pay.ps1 -ItemId 691bf10018f1d3c34db1db00 -Qty 2
```

## Environments

| Name | URL |
|------|-----|
| `local` | `http://localhost:3000` |
| `dev` | `https://dev-backend.grubgenie.ai` |
| `prod` | `https://backend.grubgenie.ai` |

## Script Reference

Every script exists in both `scripts/*.sh` (bash) and `scripts/powershell/*.ps1` (PowerShell) —
same name, same behavior, same exit codes (`0` success, `2` usage error, `4`/`5` unexpected
HTTP status, `6` response contract violation, `7` unreachable). Both languages share an
architecture layer (`scripts/lib/` / `scripts/powershell/lib/`) — see `SKILL.md` and
`AGENTS.md` for details.

| Script | Purpose | Bash usage |
|--------|---------|-------|
| `env` | Set target environment | `eval "$(bash $SKILL/env.sh local\|dev\|prod)"` |
| `auth` | Authenticate partner + diner (idempotent) | `eval "$(bash $SKILL/auth.sh [--force])"` |
| `create_cart` | Create a cart | `export CART_ID=$(bash $SKILL/create_cart.sh)` |
| `order` | Order an item or combo, then place it | `bash $SKILL/order.sh item\|combo <id> [qty]` |
| `flow_dine_in_pay` | Full E2E: cart → order → place → approve → pay → confirm | `bash $SKILL/flow_dine_in_pay.sh [itemId] [qty]` |
| `fetch_menu` | Browse menu (17 subcommands) | `bash $SKILL/fetch_menu.sh [command] [arg]` |
| `pos` | Petpooja POS: menu, items, sync, config, validate | `bash $SKILL/pos.sh menu\|items\|sync\|config\|validate` |
| `agent_test` | Chat with the AI agent | `bash $SKILL/agent_test.sh "<message>"` |
| `reset_tables` | Reset all tables | `bash $SKILL/reset_tables.sh` |

Back-compat shims (still fully functional, delegate to `order`/`pos` above): `order_item`,
`order_combo`, `get_pos_menu`, `fetch_pos_items`, `sync_pos_menu`, `branch_pos_config`,
`test_pos_validation`.

PowerShell equivalents live at `scripts/powershell/<name>.ps1`. `env.ps1` and `auth.ps1` are
meant to be dot-sourced (`. script.ps1`); every other script is a normal invocation.

## Verifying your install

```bash
bash scripts/../evals/run_evals.sh --offline   # or: pwsh evals/run_evals.ps1 -Mode offline
```

Runs syntax/lint/convention checks and a local contract-mock suite (no live API needed) —
including a cross-language check that bash and PowerShell produce identical exit codes for
identical inputs.

## Using with Claude

Once installed, just ask Claude naturally:

> "Test the dine-in flow on dev"
> "Check if order approval is working"
> "Show me the menu items"

Claude will load the skill and use the scripts automatically.
