---
kind: source
status: reviewed
last_reviewed: 2026-07-14
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-14-flatten-version-130-scalar-try-two-if-table-refresh.md
  - ./2026-07-14-flatten-version-130-multivalue-try-two-block-if-table-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` multivalue legacy-try plus two enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's concrete tuple `Switch` route stages an ordered multivalue payload once before selector work and copies it into every unique target temp. Postorder value-control flattening then routes the selected tuple through each directly enclosing value if. The source has no scalar-versus-tuple target-count distinction; independently scalar Starshine lanes can therefore use the same exact blocks-before-ifs ancestry once vector ownership, types, and fallthrough consumers are completely preflighted.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-two-if-table-targets.wat` probe places an `(i32, i64)` legacy try in the then arm of one matching multivalue if, itself in the then arm of a second matching multivalue if. The terminal table targets the try and both if labels, with the try repeated as default. It was run with the explicit `wasm-opt version 130` binary and `--all-features --flatten -S`.

The output confirms:

- first lane then second lane evaluation before selector evaluation;
- one staged tuple and distinct try, inner-if, and outer-if target channels;
- catch writes the try channel;
- selected fallthrough copies try to inner if and inner if to outer if;
- each else arm writes its own if channel independently;
- the table payload and all value-control results are removed.

## Local admission

A separate independently scalar `(i32, i64)` fixture failed unchanged at `114/115` behind the temporary larger-vector gate. Removing only that gate admits independently scalar defaultable lanes for the same strict direct-enclosure roster as scalar payloads: zero or more matching blocks followed by one or more matching value ifs, with all ifs outermost and no hardcoded count cap.

The fixture proves ordered single evaluation, distinct per-label vectors, catch routing, both selected outward vector copies, independent else routing at both levels, selector-after-payload order, cleared table/control arity, Flat IR classification, and verifier success.

Repeated `TupleMake` multiple-if payloads remain separately rejected by `flatten_tuple_mixed_try_table_is_supported(...)`. Reverse if-inside-block order, loops, skipped ancestry, arbitrary whole-tuple producers, shared or mixed ownership, nonterminal tables, nondefaultable lanes, typed catch payloads, and exceptional-transfer repair also remain gated.
