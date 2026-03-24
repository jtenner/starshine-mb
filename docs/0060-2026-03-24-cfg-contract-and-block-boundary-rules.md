# CFG Contract And Block Boundary Rules

## Scope

- Define the normative CFG contract for `HotFunc` before CFG construction lands.
- Cover block boundaries, structured-control successor policy, terminator edge kinds, and exceptional-edge policy.
- Leave actual block-array/edge-array construction to the later CFG build slice.

## Current Behavior

- `HotFunc` already has stable control labels, control-region slot metadata, structural queries, and verification.
- There is no canonical CFG contract yet, so later agents would otherwise have to guess where blocks start and stop.

## Contract

- `BlockId` is an analysis-layer id keyed to one built CFG overlay, not a body-owned identifier.
- Every top-level root starts a block boundary at function entry.
- Structured control nodes `Block`, `Loop`, `If`, `Try`, and `TryTable` are block headers and also terminate the incoming block.
- `Loop` adds an explicit loop-header boundary in addition to the ordinary control-header boundary.
- Control-region slots are explicit block-entry boundaries:
  - `Block` / `Loop`: body region.
  - `If`: then region and optional else region.
  - `Try`: body region and optional catch region.
  - `TryTable`: body region and catch-list region.
- Value-only nodes stay in the current block unless they are themselves a structured control header.
- Terminators are:
  - Structured control headers.
  - `Br`, `BrIf`, `BrTable`, `BrOnNull`, `BrOnNonNull`, `BrOnCast`, `BrOnCastFail`.
  - `Return`.
  - `Throw`, `ThrowRef`, `Rethrow`, `Delegate`.
  - `Unreachable`.
- Terminator edge kinds:
  - Conditional branch families produce explicit branch and fallthrough edges.
  - `Return` produces a return edge to the synthetic function exit.
  - Exceptional terminators produce explicit exceptional edges.
  - `Unreachable` produces an explicit unreachable-exit edge, not an implicit missing successor.
- Exceptional-edge policy:
  - `Try` routes exceptional flow to its catch region.
  - `TryTable` routes exceptional flow to its catch-list region.
  - `Throw`, `ThrowRef`, and `Rethrow` propagate to the caller-visible exceptional exit when no enclosing handler intercepts them.
  - `Delegate` is explicit exceptional control transfer to its delegated target, not a hidden side fact.

## Correctness Constraints

- Every live region root belongs to exactly one CFG block when CFG construction lands.
- Successor policy must come from control-slot metadata, not child-slot guessing.
- Exceptional control flow must be materialized as explicit CFG edges.
- CFG construction may add synthetic entry/exit blocks, but it must keep their policy separate from owned body nodes.

## Validation Plan

- Unit tests lock structured-control successor policies.
- Unit tests lock block-boundary classification for roots, loops, structured branches, and ordinary terminators.
- Unit tests lock explicit branch/fallthrough/exceptional edge-kind policy.

## Performance Impact

- This slice is metadata-only. Runtime cost is negligible and limited to small policy-table lookups.

## Open Questions

- Whether future CFG construction should split a dedicated continuation block after every structured control header or only when a real fallthrough successor exists.
- Whether `Delegate` should eventually use a dedicated edge kind distinct from ordinary exceptional edges once CFG build records concrete delegated targets.
