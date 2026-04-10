---
kind: decision
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../0060-2026-03-24-cfg-contract-and-block-boundary-rules.md
related:
  - ./local-ssa-policy.md
  - ../../../src/ir/cfg_contract.mbt
  - ../../../src/ir/cfg_contract_test.mbt
  - ../../../src/ir/cfg.mbt
  - ../../../src/ir/cfg_test.mbt
---

# IR2 CFG Contract

## Decision

- `BlockId` is an analysis-layer id for one built CFG overlay, not an owned body id.
- Every top-level root starts a block boundary at function entry.
- Structured control nodes are block headers and also terminate the incoming block.
- `Loop` adds an explicit loop-header boundary in addition to the ordinary control-header boundary.
- Control-region slots are explicit block-entry boundaries for body, then, else, catch, and catch-list regions.
- Value-only nodes stay in the current block unless they are themselves structured control headers.

## Edge Policy

- Terminators include structured control headers, branch families, `return`, exceptional terminators, and `unreachable`.
- Conditional branch families produce explicit branch and fallthrough edges.
- `Return` produces an explicit return edge to the synthetic function exit.
- Exceptional control flow is explicit:
  - `try` routes to its catch region
  - `try_table` routes to its catch-list region
  - `throw`, `throw_ref`, and `rethrow` propagate to the caller-visible exceptional exit when no handler intercepts them
  - `delegate` is explicit exceptional transfer to its delegated target
- `Unreachable` produces an explicit unreachable-exit edge rather than an implicit missing successor.

## Current In-Tree Status

- The policy surface lives in [`../../../src/ir/cfg_contract.mbt`](../../../src/ir/cfg_contract.mbt).
- Boundary, successor, and exception-policy coverage lives in [`../../../src/ir/cfg_contract_test.mbt`](../../../src/ir/cfg_contract_test.mbt).
- Concrete CFG build coverage lives in [`../../../src/ir/cfg_test.mbt`](../../../src/ir/cfg_test.mbt).

## Practical Rule

- Derive successor structure from control-slot metadata, not child-slot guessing.
- Materialize exceptional flow as real CFG edges.
- Keep synthetic entry and exit policy separate from owned body nodes.

## Sources

- Numbered research doc: [`../../0060-2026-03-24-cfg-contract-and-block-boundary-rules.md`](../../0060-2026-03-24-cfg-contract-and-block-boundary-rules.md)
- Policy layer: [`../../../src/ir/cfg_contract.mbt`](../../../src/ir/cfg_contract.mbt)
- CFG build coverage: [`../../../src/ir/cfg_test.mbt`](../../../src/ir/cfg_test.mbt)
