---
title: Sync Skill With Backend Changes
description: How to re-verify the skill's docs against the live backend and close drift.
type: guide
tags:
  - wiki
  - guide
  - how-to
---
## Goal

Keep `references/api_reference.md` (and this wiki) accurate as the backend at `~/Desktop/grubgenie_api_refactor` evolves — close the drift documented in [API Reference & Drift](../modules/api-reference.md) and catch new drift before it accumulates again.

## Steps

1. **Diff route trees, not docs.** Read `src/app.ts` and `src/routes/v1/**` directly (native `Read`/`Grep`/`Glob` — it's source code, not wiki markdown) rather than trusting `api_reference.md`'s existing tables.
2. **Check `git log` on the backend repo** for recent route additions — `git log --oneline -30` in `~/Desktop/grubgenie_api_refactor` surfaces new surfaces fast (this is how the `/v1/admin/genie/*` gap was found: three commits in the 24h before the check).
3. **Verify webhook mount order specifically.** This skill has already been caught documenting `webhooks/v1/...` when the code mounts `v1/webhooks/...` — always confirm the exact prefix order and any provider-name segments (`/pos/petpooja/...`) against `src/webhooks/v1/**`, don't assume the old doc's shape is right.
4. **Verify the local `PORT`** against the backend's actual `.env` (not just `config.ts`'s Joi default) before trusting `env.sh local`'s `localhost:3000`.
5. **Update `references/api_reference.md`** route tables for anything that changed.
6. **Update `modules/api-reference.md`** in this wiki — move confirmed-fixed items out of "Drift found", add anything newly discovered.
7. **Re-stamp this wiki's `source_commit`** (`OVERVIEW.md` frontmatter) to the backend's current `git rev-parse HEAD` if you want future refreshes to diff from this point — note this wiki's own `source_commit` tracks *this skill repo's* HEAD, not the backend's, since the backend is a separate, unlinked project.

## Relevant code

- Backend: `src/app.ts`, `src/routes/v1/**`, `src/webhooks/v1/**`, `src/config/config.ts` (outside this repo — not directly linkable)
- This skill: [references/api_reference.md](../../../references/api_reference.md), [modules/api-reference.md](../modules/api-reference.md)

## Gotchas

- The backend and this skill are **two separate git repos with no automated link** — drift is only caught by someone (or an agent) manually re-reading backend source. There's no CI check enforcing this sync.
- Don't just grep the backend for route strings that match what's already documented — that confirms existing entries but misses entirely new route groups (like `/v1/admin/genie/*` was). Read the route-mounting files (`app.ts`, each domain's `index.ts`/router file) top to bottom instead.
- Webhook and dev-only (`NODE_ENV`-gated) routes are easy to miss since they're not under the main `/v1/routes` domain folders — check `src/webhooks/v1/**` and any `NODE_ENV === 'development'` conditionals in `app.ts` explicitly.

## Related

- [API Reference & Drift](../modules/api-reference.md)
- [Backend API Architecture](../architecture/backend-api-architecture.md)
