---
title: Script-First Methodology
description: "SKILL.md's Core Rule 1: use a pre-built script for every standard operation, never hand-write curl."
type: concept
tags:
  - wiki
  - concept
---
## Definition

The skill's foundational rule: for any standard API operation, use the matching pre-built script (`auth.sh`, `create_cart.sh`, `order_item.sh`, etc.) rather than writing curl by hand. For operations with no matching script, route through the context-mode sandbox instead of hand-written curl — see [Debugging & Context-Mode Patterns](../modules/debugging-context-mode.md).

## Why it matters

Hand-written curl loses three things the scripts guarantee: correct token extraction (the right `jq` path for each response shape), consistent request formatting (query vs body params, the right content-type), and testability (a script that works today keeps working, hand-typed curl has to be re-derived every session). This is `SKILL.md`'s **Core Rule 1**, stated as a MUST.

## Where it lives

- `SKILL.md` — "Core Rules (MUST Follow)" section, Rule 1 and Rule 2
- Enforced by convention, not tooling — there's no lint/check that blocks manual curl, it's a behavioral instruction to the agent reading `SKILL.md`

## Related

- [Bash Scripts](../modules/scripts-bash.md) — the 14-script surface this rule points at
- [Skill Architecture](../architecture/skill-architecture.md)
