---
title: Environments & BASE URL
description: How the skill selects local/dev/prod, and the local-port drift risk.
type: concept
tags:
  - wiki
  - concept
---
## Definition

Every script reads a `BASE` environment variable for the API root. `env.sh`/`env.ps1` set it from a 3-way selector:

| Env | URL |
|---|---|
| `local` | `http://localhost:3000` |
| `dev` | `https://dev-backend.grubgenie.ai` |
| `prod` | `https://backend.grubgenie.ai` |

## Why it matters

Getting `BASE` wrong silently breaks every downstream script with connection errors or 404s, and it's the very first thing any session does (`eval "$(bash $SKILL/env.sh local)"`). **The `local` value is suspect**: the backend's `src/config/config.ts` defaults `PORT=3002`, not `3000`. If local dev actually runs on `3002`, `env.sh local` is wrong for every session until fixed — verify against the backend's actual `.env` before trusting it. See [API Reference & Drift](../modules/api-reference.md).

## Where it lives

- [scripts/env.sh](../../../scripts/env.sh) / `scripts/powershell/env.ps1`
- Every other script defaults `BASE=${BASE:-http://localhost:3000}` as a fallback if `env.sh` wasn't sourced

## Related

- [Backend API Architecture](../architecture/backend-api-architecture.md)
- [API Reference & Drift](../modules/api-reference.md)
