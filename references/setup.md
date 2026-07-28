# Onboarding (First-Time Setup)

## macOS / Linux

**Step 1 — install dependencies:**

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install -y jq curl
```

**Step 2 — set your skill path:**

```bash
export SKILL=~/.claude/skills/grubgenie-api-test/scripts
```

**Step 3 — pick environment, authenticate, test:**

```bash
eval "$(bash $SKILL/env.sh local)"   # http://localhost:3000
eval "$(bash $SKILL/env.sh dev)"     # https://dev-backend.grubgenie.ai
eval "$(bash $SKILL/env.sh prod)"    # https://backend.grubgenie.ai

eval "$(bash $SKILL/auth.sh)"
bash $SKILL/fetch_menu.sh restaurant-info
```

---

## Windows — Option A: PowerShell (recommended)

No extra dependencies — PowerShell 7+ ships with everything needed. PowerShell 5.1 also works
(the lib auto-detects and adjusts TLS negotiation).

**Step 1 — set your skill path:**

```powershell
$SKILL = "$HOME\.claude\skills\grubgenie-api-test\scripts\powershell"
```

**Step 2 — pick environment, authenticate, test:**

```powershell
. $SKILL\env.ps1 -Env local    # http://localhost:3000
. $SKILL\env.ps1 -Env dev      # https://dev-backend.grubgenie.ai
. $SKILL\env.ps1 -Env prod     # https://backend.grubgenie.ai

. $SKILL\auth.ps1
```

**Full E2E dine-in flow:**

```powershell
pwsh -File $SKILL\flow_dine_in_pay.ps1 -ItemId 691bf10018f1d3c34db1db00 -Qty 2
```

**Step by step:**

```powershell
. $SKILL\auth.ps1
$env:CART_ID = & "$SKILL\create_cart.ps1"
& "$SKILL\order_item.ps1" 691bf10018f1d3c34db1db00 -Qty 2
```

Note: `env.ps1` and `auth.ps1` are meant to be **dot-sourced** (`. script.ps1`) so their exported
`$env:` variables persist in your session — a dot-sourced script's `exit` only stops that
script's own execution, it does not (and should not) terminate your shell. Everything else
(`create_cart.ps1`, `order.ps1`, `pos.ps1`, ...) is a normal script invocation — use `&` or just
call it directly, and its exit code reflects success/failure normally.

---

## Windows — Option B: Git Bash

Requires bash + curl + jq.

1. Install **Git for Windows**: https://git-scm.com/download/win
2. Install **jq**:
   - Download `jq-windows-amd64.exe` from https://github.com/jqlang/jq/releases
   - Rename to `jq.exe`, place in `C:\Program Files\Git\usr\bin\`
3. Open **Git Bash**
4. Run scripts exactly like macOS/Linux:

```bash
export SKILL="$HOME/.claude/skills/grubgenie-api-test/scripts"
eval "$(bash $SKILL/env.sh dev)"
eval "$(bash $SKILL/auth.sh)"
bash $SKILL/fetch_menu.sh restaurant-info
```

---

## Verifying your setup

Run the offline eval suite — it needs no live API and confirms scripts are syntactically valid,
follow house conventions, and (if `pwsh` is installed) that bash and PowerShell agree on exit
codes for identical inputs:

```bash
bash $SKILL/../evals/run_evals.sh --offline
```

A clean install should show `PASS` on syntax/conventions/contract-mock and `SKIP` only for
optional linters (`shellcheck`, `PSScriptAnalyzer`) you haven't installed.
