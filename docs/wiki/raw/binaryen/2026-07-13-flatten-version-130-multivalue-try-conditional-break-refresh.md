---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-try-conditional-break-refresh.md
  - ./2026-07-13-flatten-version-130-multivalue-try-break-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` multivalue legacy-try conditional-break refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen treats a concrete multivalue payload as one `Type` in its `Break` path. The payload is evaluated before the condition, stored through the named-target break temp, removed from `br_if`, and read again on the not-taken path. Legacy `Try` routing independently writes concrete do/catch fallthrough values and makes the try void. The observable contract is ordered one-time payload evaluation, condition-after-payload order, preserved false-path values, and one final result selected by either the branch or a reachable fallthrough arm.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-conditional-target.wat` probe carries `(i32, i64)` through `br_if` to a legacy-try label, consumes the not-taken vector with reversed stack-order drops, then produces an independent do fallthrough vector; the catch produces another vector. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms tuple construction before condition work, payload removal, preserved false flow, payload-free `br_if`, void try output, and a shared final result channel.

## Local interpretation

HOT repeats one tuple-valued node id across scalar payload and false-flow slots, while locals remain scalar. Starshine admits an exact defaultable multivalue try-label `br_if` only when the try has one exclusive outer result span and every conditional payload is either an independently scalar exact vector or one exact `TupleMake` repeated across all payload slots. Each scalar payload must have exactly the branch use plus one immediate reversed direct-drop consumer; a repeated tuple must be used only by all branch slots and those immediate reversed drops. Tuple components require supported scalar origins and exact lane types. Components spill once in source order, the shared try-result vector is written before condition work, false-path drops read that vector in reverse stack order, the tuple shell is deleted, and independent do/catch fallthroughs write the same vector.

This does not admit non-drop, non-immediate, nested, shared, mismatched, or nondefaultable false flow; table exits; arbitrary whole-tuple producers; represented typed catch payloads; or exceptional transfer repair.
