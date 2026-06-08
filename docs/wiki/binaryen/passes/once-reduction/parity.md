---
kind: comparison
status: signed-off
last_reviewed: 2026-06-08
sources:
  - ../../../raw/binaryen/2026-04-22-once-reduction-primary-sources.md
  - ../../../raw/research/0717-2026-06-08-once-reduction-behavior-gap-inventory.md
  - ../../../raw/research/0138-2026-04-20-once-reduction-binaryen-research.md
  - ../../../raw/research/0238-2026-04-21-once-reduction-starshine-strategy-followup.md
  - ../../../raw/research/0256-2026-04-22-once-reduction-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0536-2026-05-06-once-reduction-direct-revalidation.md
  - ../../../raw/research/0701-2026-06-03-once-reduction-o4z-audit.md
  - ../../../../../src/passes/once_reduction.mbt
  - ../../../../../src/passes/once_reduction_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast_tests.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./dominance-propagation-and-cycle-safety.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
---

# `once-reduction` Binaryen parity

## Durable conclusions

- Binaryen `version_130` `once-reduction` is a module-level once-bit plus direct-call optimization pass, not a generic repeated-call eliminator.
- Starshine now matches the saved generated-artifact `-O4z` slot `4` on exact wasm and normalized WAT.
- `[O4Z-AUDIT-OR]` is signed off for v0.1.0 behavior parity and removed from `agent-todo.md` after the 2026-06-08 source/lit behavior checklist, focused test expansion, and final 100000-case direct compare.
- The previously documented broad gaps are now covered by focused tests: imported idempotent roots, idempotent-adjacent wrapper cleanup, positive/negative write selection, merge conservatism, branch/loop/EH precision, dangerous cycles, `return_call` divergence, direct call-chain summaries, and lit-surface negative body shapes.

## Current in-tree status

- The explicit implementation lives in [`../../../../../src/passes/once_reduction.mbt`](../../../../../src/passes/once_reduction.mbt).
- Focused coverage lives in [`../../../../../src/passes/once_reduction_test.mbt`](../../../../../src/passes/once_reduction_test.mbt).
- Preset scheduling coverage lives in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) and [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt).

The current Starshine subset clearly covers:

- explicit integer once-global discovery
- no-param/no-result once-function recognition in flat and single-top-level-block forms
- read and write disqualification for once-globals
- defined no-param/no-result `@binaryen.idempotent` functions as fake once roots
- fixed-point propagation of definitely-set once-bits across direct-call summaries
- redundant direct-call and redundant `global.set` elimination
- trivial once-body cleanup for empty bodies and single-call wrappers, including the single-top-level-block form

## 2026-06-08 behavior-gap inventory

The latest source audit is [`../../../raw/research/0717-2026-06-08-once-reduction-behavior-gap-inventory.md`](../../../raw/research/0717-2026-06-08-once-reduction-behavior-gap-inventory.md). It checked local Binaryen `wasm-opt version 130 (version_130)` and found that `version_130` `OnceReduction.cpp` plus the dedicated lit file are unchanged from the `version_129` sources this dossier already used.

The audit originally kept `[O4Z-AUDIT-OR]` open with nine concrete red-test families: imported idempotent roots, idempotent-adjacent wrapper cleanup, negative once writes, CFG/dominator merge drift, branch exits, loop propagation, EH/`try_table`, dangerous recursive cycles, and `return_call` divergence. The same 2026-06-08 follow-up implemented those covered families, then a later test expansion added 12 more source/lit-surface fixtures.

Current closeout evidence:

- `moon test --package jtenner/starshine/passes --file once_reduction_test.mbt`: `37` / `37` passed
- `moon test src/passes`: `2015` / `2015` passed
- final direct compare `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass once-reduction --out-dir .tmp/pass-fuzz-once-reduction-current-100000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`: `99751` compared, `99751` normalized matches, `0` mismatches, `0` validation/property/generator failures, and `249` Binaryen/tool command failures.

Agent classification: the final compare lane has zero Starshine-vs-Binaryen behavior mismatches for compared cases. The remaining command failures are Binaryen/tool failures, not Starshine semantic differences. No broad unapproved once-reduction behavior gap remains active.

## Covered source-visible strategy surface

Upstream uses nested scanner/optimizer passes, CFG construction, and `DomTree` immediate-dominator reasoning. Starshine uses recursive instruction-array scanning and rewriting, but the behavior inventory now maps the official `version_130` source/lit families to focused tests rather than treating the architectural difference as an open broad gap.

Covered families include:

- explicit integer once-global discovery, including positive non-`1` writes and nonzero initial globals
- no-param/no-result once-function recognition in flat and single-top-level-block forms
- negative body recognition for leading/middle debris, `if else`, mismatched globals, loop-root bodies, too-short bodies, params/results, non-integer globals, zero writes, nonconstant writes, imported/exported globals, and extra reads
- imported and defined no-param/no-result `@binaryen.idempotent` fake roots, plus typed/unannotated negatives
- fixed-point direct-call summaries, including long call chains and the Binaryen directionality for non-once callees
- redundant direct-call and redundant positive `global.set` elimination
- after-merge conservatism, branch/return/unreachable cutoffs, loop-local dominance, and `try_table` traversal
- self-recursive once-call cleanup plus dangerous mutually recursive cycle preservation
- direct-call versus `return_call` behavior selection
- unreachable/dead-trap debris cleanup needed for final normalized direct-compare parity

## Refreshed direct-pass signoff

On 2026-06-03, the O4z audit lane ran:

- `moon test src/passes`
- `moon build --target native --release src/cmd`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass once-reduction --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-once-reduction-audit-current-10000-keepgoing`

The compare run reported `9975` compared cases, `9975` normalized matches, `0` semantic mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures. Failure classes were `22` zero-sized recursion group parser/canonicalization failures, `1` bad-section-size command failure, `1` table-index-out-of-range command failure, and `1` invalid-tag-index command failure. These are tracked separately from semantic output mismatches.

`moon info` still crashed in the local Moon tool with the known index-out-of-bounds panic, and `moon fmt --check` still reported unrelated repo-wide migration/format drift.

## Current evidence

The dossier now has an immutable raw provenance capture at:

- [`../../../raw/binaryen/2026-04-22-once-reduction-primary-sources.md`](../../../raw/binaryen/2026-04-22-once-reduction-primary-sources.md)

That 2026-04-22 capture records that the reviewed official Binaryen GitHub release page for `version_129` showed publish date **2026-04-01**, and that a narrow current-`main` spot check did not surface a new teaching-relevant drift in the upstream source/test surfaces this parity note depends on.

## Saved generated-artifact audit

The saved `-O4z` audit reports slot `4` (`once-reduction`) as:

- exact wasm equal: `yes`
- normalized WAT equal: `yes`
- Starshine runtime: `421.087 ms`
- Binaryen runtime: `206.659 ms`
- Starshine pass time: `12.455 ms`
- Binaryen pass time: `13.674 ms`

That is encouraging in two ways:

- the current local implementation already matches the artifact's exercised semantics exactly
- the pass itself is not a major local runtime outlier on that artifact

## Saved Binaryen debug log

The saved Binaryen debug log shows one top-level `running pass: once-reduction` line.
It also shows `running nested passes`, which matches the documented implementation shape:

- top-level module pass
- internal nested helper passes for scanning and optimization

## In-tree focused tests

The current local test file covers the core and source/lit parity families listed in the behavior-gap inventory, including repeated direct calls, explicit once-global body recognition, idempotent fake roots, boundary globals, direct-call summaries, control-flow conservatism, cycle safety, and Binaryen-negative guard shapes. The focused suite is now the executable behavior checklist for this pass.

## Practical signoff rule

Treat `once-reduction` as signed off for v0.1.0 behavior parity:

- green on the saved generated artifact
- covered by focused source/lit behavior tests
- zero-mismatch on the current final 100000-case direct compare lane
- remaining final-run command failures classified separately as Binaryen/tool failures

## Sources

- [`../../../raw/research/0138-2026-04-20-once-reduction-binaryen-research.md`](../../../raw/research/0138-2026-04-20-once-reduction-binaryen-research.md)
- [`../../../raw/research/0536-2026-05-06-once-reduction-direct-revalidation.md`](../../../raw/research/0536-2026-05-06-once-reduction-direct-revalidation.md)
- [`../../../raw/research/0701-2026-06-03-once-reduction-o4z-audit.md`](../../../raw/research/0701-2026-06-03-once-reduction-o4z-audit.md)
- Saved generated-artifact slot and Binaryen debug-log facts are copied into that committed O4z audit note; any older `.artifacts` path is a local replay identifier, not a durable source link.
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OnceReduction.cpp>
- Binaryen `version_129` annotation helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
- Binaryen `version_129` dedicated lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/once-reduction.wast>
- Implementation: [`../../../../../src/passes/once_reduction.mbt`](../../../../../src/passes/once_reduction.mbt)
- Focused tests: [`../../../../../src/passes/once_reduction_test.mbt`](../../../../../src/passes/once_reduction_test.mbt)
