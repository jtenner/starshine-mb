---
kind: source
status: reviewed
last_reviewed: 2026-07-14
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-14-flatten-version-130-multivalue-try-two-block-if-table-refresh.md
  - ./2026-07-14-flatten-version-130-multivalue-try-block-if-table-tuple-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made legacy-try plus two blocks plus enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's concrete tuple `Switch` route stores the payload once before selector work, copies it into every unique break-target temp, and removes the original switch value. Postorder control flattening then routes the selected legacy-try result through each directly enclosing matching block and the unique outer value if. The owner imposes no fixed block-count limit, so a repeated tuple payload does not justify a separate one-block cap once component ownership, direct ancestry, and deletion are completely preflighted.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-two-block-if-table-tuple-payload.wat` probe places an `(i32, i64)` legacy try directly inside two matching multivalue blocks in the then arm of one matching outer multivalue if. Its terminal table targets the try, both blocks, and the if, with the try repeated as default. The probe was run with the explicit `wasm-opt version 130` binary and `--all-features --flatten -S`.

The output confirms:

- first component then second component evaluation before selector evaluation;
- one tuple staging channel and distinct try, inner-block, outer-block, and if target channels;
- catch writes the try channel;
- selected fallthrough copies try to inner block, inner block to outer block, and outer block to if;
- the else arm writes the if channel independently;
- the table payload and all value-control results are removed.

## Local admission

A separate repeated-HOT-`TupleMake` `(i32, i64)` fixture failed unchanged at `112/113` behind the old tuple mixed-chain length gate. Starshine now admits one exclusively owned repeated `TupleMake` for a terminal table targeting its legacy try, any nonempty strict directly enclosing chain of matching defaultable blocks, and one unique outermost matching value if.

The fixture proves ordered component scalarization, one evaluation per component, distinct per-label vectors, catch routing, every selected outward fallthrough copy, independent else routing, selector-after-payload order, tuple-shell deletion only after full preflight, cleared table/control arity, Flat IR classification, and verifier success.

Multiple if targets, reverse if-inside-block order, loops, skipped ancestry, arbitrary whole-tuple producers, shared or mixed tuple ownership, nonterminal tables, nondefaultable lanes, typed catch payloads, and exceptional-transfer repair remain rejected.
