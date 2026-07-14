---
kind: source
status: reviewed
last_reviewed: 2026-07-14
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-scalar-try-block-if-table-refresh.md
  - ./2026-07-13-flatten-version-130-scalar-try-three-block-table-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` scalar legacy-try plus two blocks plus enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's scalar `Switch` handling stages one concrete payload before selector work and copies it into every unique named-target break temp. Postorder value-control handling reuses those target temps while erasing the legacy try, each enclosing block, and the outer value if. The owner has no block-count limit: source order and ancestry, not a fixed roster size, determine the outward copy chain.

## Direct v130 probe

The ignored `.tmp/flatten-probes/scalar-try-two-block-if-table-targets.wat` probe places a scalar legacy try directly inside two matching value blocks in the then arm of one matching outer value if. Its terminal table targets all four labels and repeats the try as default. The `.out.wat` output from explicit Binaryen v130 `wasm-opt --all-features --flatten -S` confirms:

- payload evaluation before selector evaluation;
- one staging point and distinct try/inner-block/outer-block/if target channels;
- catch writes the try channel;
- selected fallthrough copies try to inner block, inner block to outer block, and outer block to if;
- the else arm writes the if channel independently;
- the table payload and every control result are erased.

## Local admission

A verifier-backed scalar fixture failed unchanged at `110/111` behind the previous hardcoded three-target mixed-if restriction. Starshine now admits exactly one matching outermost if after any nonempty strict direct-enclosure chain of matching blocks around the legacy try. The same ancestry walk proves every control directly encloses the prior control and requires the unique if to be the outermost selected target.

The scalar payload evaluates once into staging before selector work, then copies into distinct per-label locals. Catch and every selected outward fallthrough use the corresponding channels; the other if arm remains independent. Terminal placement, exact target/result types, defaultability, supported payload origin, unique labels, and complete label-use preflight remain required.

An explicit multivalue gate remains in place for larger mixed-if rosters so independently scalar multivalue lanes can be audited red-first separately. Repeated `TupleMake` payloads remain restricted to their separately proven exact rosters. Multiple ifs, reverse if-inside-block order, loops, skipped ancestry, unrelated labels, multiple tries, nonterminal tables, nondefaultable payloads, typed catch payloads, and exceptional-transfer repair remain rejected.
