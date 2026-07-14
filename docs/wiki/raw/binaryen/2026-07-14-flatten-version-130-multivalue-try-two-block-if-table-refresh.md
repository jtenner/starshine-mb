---
kind: source
status: reviewed
last_reviewed: 2026-07-14
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-14-flatten-version-130-scalar-try-two-block-if-table-refresh.md
  - ./2026-07-13-flatten-version-130-multivalue-try-block-if-table-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` multivalue legacy-try plus two blocks plus enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's concrete tuple `Switch` route stages the multivalue payload once before selector work and copies it into every unique target temp. The surrounding legacy try, each directly enclosing block, and the unique outer value if then erase their concrete results in postorder through distinct tuple channels. The owner imposes no fixed block-count limit; the exact direct ancestry chain determines the selected fallthrough copies.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-two-block-if-table-targets.wat` probe places an `(i32, i64)` legacy try directly inside two matching multivalue blocks in the then arm of one matching outer multivalue if. Its terminal table targets the try, both blocks, and the if, with the try repeated as default. Explicit Binaryen v130 output confirms:

- first lane then second lane evaluation before selector evaluation;
- one staged tuple and distinct try/inner-block/outer-block/if target channels;
- catch writes the try channel;
- selected fallthrough copies try to inner block, inner block to outer block, and outer block to if;
- the else arm writes the if channel independently;
- the table payload and all value-control results are removed.

## Local admission

A separate independently scalar `(i32, i64)` fixture failed unchanged at `111/112` behind the temporary larger-vector gate before deliberate re-admission. Starshine now admits independently scalar defaultable lanes for one legacy try, any nonempty strict direct-enclosure chain of matching blocks, and one unique outermost matching value if. Every target must appear in the exact direct ancestry roster and all label uses, result vectors, scalar origins, terminal placement, and ownership must preflight before mutation.

Each lane evaluates once in source order into staging, copies into distinct per-label vectors before selector work, and clears table/control arity. Catch writes the try vector; every selected fallthrough copies the immediately inner vector outward; the other if arm writes independently. The final repeated control-result consumers become ordered local reads, and verifier-backed Flat IR validation passes.

Repeated `TupleMake` payloads remain narrower: they admit the strict block-only chain, direct try-plus-if, and exact try-plus-one-block-plus-outer-if rosters, not larger mixed chains. Multiple ifs, reverse if-inside-block order, loops, skipped ancestry, arbitrary whole-tuple producers, shared/mixed payload ownership, nonterminal tables, nondefaultable lanes, typed catch payloads, and exceptional-transfer repair remain rejected.
