---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/test/lit/passes/flatten_all-features.wast
  - ./2026-07-13-flatten-version-130-scalar-try-block-table-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` scalar legacy-try plus enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's `Switch` handling stages a carried scalar once, assigns it to every unique target temp before selector work, and removes the table payload. Postorder `Try` handling routes do/catch results through the try temp. Postorder `If` handling routes both arms through one if-result temp, while a named branch to the if result uses that same target channel. These owner paths are target-kind generic; they do not restrict a table's non-try target to `Block`.

## Direct v130 probe

The ignored `.tmp/flatten-probes/scalar-try-if-table-targets.wat` probe places a scalar-result legacy try directly in the then arm of a matching scalar-result named if. The terminal table targets the try and the if, with the try repeated as default; the else arm has an independent scalar result. The `.out.wat` output from the explicit Binaryen v130 `wasm-opt --all-features --flatten -S` binary confirms payload-before-selector order, distinct try and if target assignments, payload removal, catch-to-try routing, then-arm try-to-if fallthrough copying, independent else-arm routing, and final if-result flow.

## Local admission

Starshine now admits exactly one new target-kind roster: a terminal scalar table whose unique targets are one legacy try and one directly enclosing matching defaultable value `if`. Direct enclosure may be through either if arm, but the target roster must contain exactly those two unique labels. The existing payload type/origin, terminal-arm, try-label use, EH prerequisite, and no-partial-mutation gates remain in force. The payload stages once, copies into distinct try and if locals before selector work, catch feeds the try channel, the selected try fallthrough feeds the containing arm's if channel, and the other arm writes the same if channel independently.

This does not admit block-plus-if chains, multiple if targets, multivalue if-target tables, tuple-made if-target payloads, unrelated or skipped ancestry, loops, multiple try labels, nonterminal tables, nondefaultable lanes, typed catch payloads, or exceptional-transfer repair.
