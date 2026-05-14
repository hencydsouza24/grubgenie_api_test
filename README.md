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

### Bash (`scripts/`)

| Script | Purpose |
|--------|---------|
| `env.sh` | Set target environment |
| `auth.sh` | Authenticate partner + diner |
| `create_cart.sh` | Create a cart |
| `order_item.sh <itemId> [qty]` | Order a menu item |
| `order_combo.sh [comboId] [qty]` | Order a combo |
| `flow_dine_in_pay.sh [itemId] [qty]` | Full E2E flow |
| `fetch_menu.sh [items\|categories\|search\|restaurant-info]` | Browse menu |
| `agent_test.sh "<message>"` | Chat with the AI agent |
| `reset_tables.sh` | Reset all tables |
| `get_pos_menu.sh` | Fetch POS menu (Petpooja) |
| `test_pos_validation.sh` | Validate POS ID rejection |
| `branch_pos_config.sh [setup\|get\|disable]` | Manage POS config |

### PowerShell (`scripts/powershell/`)

| Script | Purpose |
|--------|---------|
| `env.ps1 [local\|dev\|prod]` | Set target environment |
| `auth.ps1` | Authenticate partner + diner |
| `create_cart.ps1` | Create a cart |
| `order_item.ps1 -ItemId <id> [-Qty 2]` | Order a menu item |
| `flow_dine_in_pay.ps1 [-ItemId <id>] [-Qty 2]` | Full E2E flow |

## Using with Claude

Once installed, just ask Claude naturally:

> "Test the dine-in flow on dev"
> "Check if order approval is working"
> "Show me the menu items"

Claude will load the skill and use the scripts automatically.
