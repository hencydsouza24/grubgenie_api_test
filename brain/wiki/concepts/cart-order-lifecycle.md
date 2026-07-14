---
title: Cart & Order Lifecycle
description: Status flows for carts and orders, and the payment-blocked-on-pending-acceptance rule.
type: concept
tags:
  - wiki
  - concept
---
## Definition

**Cart**: one per active table session. Status flow: `open` → `payment_in_progress` → `payment_done` (Stripe path), or `open` → direct `payment_done` (pay-in-person path).

**Order**: multiple orders can exist per cart. Status flow: `pending` → `placed` (after `place-order`) → `pending_acceptance` (if the branch requires manual approval and the partner hasn't responded) → `preparing` → `ready` → `completed`. Rejected orders land in `rejected`.

## Why it matters

The order MUST be placed (`PUT .../place-order/:orderId`) before payment can be initiated — skipping straight from order creation to payment fails. And **all payment routes are blocked with 400** if any order in the cart is still `pending_acceptance` — the partner must accept or reject every pending order first. This is the single most common cause of "payment won't initiate" during testing.

## Where it lives

- `references/api_reference.md` — "Key Business Rules" section documents both status flows
- [flow_dine_in_pay.sh](../../../scripts/flow_dine_in_pay.sh) — encodes the happy path through this lifecycle, including the conditional auto-accept step

## Related

- [Dine-In + Pay E2E](../flows/dine-in-pay-e2e.md)
- [Order Approval / Rejection](../flows/order-approval-rejection.md)
