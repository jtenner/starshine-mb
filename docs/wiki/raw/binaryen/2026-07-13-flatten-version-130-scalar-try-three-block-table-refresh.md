---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-scalar-try-two-block-table-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` scalar legacy-try plus three-block table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's scalar `Switch` owner stages one concrete payload before selector work and iterates every unique target returned by `BranchUtils::getUniqueTargets(...)`. It has no semantic target-count cap. Each target gets a distinct break temp, and postorder handling erases every value-carrying control in the enclosing chain independently.

## Direct v130 probe

The ignored `.tmp/flatten-probes/scalar-try-three-block-table-targets.wat` probe places a scalar legacy try inside three nested matching scalar blocks. Its terminal table targets the try and all three blocks, with the try repeated as default. The `.out.wat` output from the explicit Binaryen v130 `wasm-opt --all-features --flatten -S` binary confirms payload-before-selector order, one staged payload, four distinct target assignments, a payload-free table, catch-to-try routing, and three outward fallthrough copies.

## Local admission

Starshine removed the arbitrary three-unique-target cap from the scalar helper. Admission remains ancestry-driven: after identifying exactly one legacy-try label, every other unique target must be a matching defaultable block that directly encloses the previously proven owner. The preflight must consume the complete non-try target roster, and the table must still be terminal in the try body or catch. Payload type/origin, label-use, EH-prerequisite, and no-partial-mutation gates remain unchanged.

The payload stages once before selector work and copies into a distinct local for the try and every directly enclosing block. Catch writes the try channel, each fallthrough copies only to the next outward channel, and table/control arity is erased without a hardcoded chain length.

This does not admit skipped or non-direct ancestry, non-block secondary targets, multiple try labels, nonterminal tables, nondefaultable results, typed catch payloads, or exceptional-transfer repair. Multivalue routes retain their separate target-count and ownership policies.
