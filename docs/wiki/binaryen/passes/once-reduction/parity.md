---
kind: comparison
status: signed-off
last_reviewed: 2026-07-21
sources:
  - ./index.md
  - ../../../../../src/passes/once_reduction.mbt
  - ../../../../../src/passes/once_reduction_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast_tests.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/OnceReduction.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./dominance-propagation-and-cycle-safety.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./fuzzing.md
---

# `once-reduction` Binaryen parity

## Durable conclusions

- Binaryen `version_130` `once-reduction` is a module-level once-bit plus direct-call optimization pass, not a generic repeated-call eliminator.
- Starshine now matches the saved generated-artifact `-O4z` slot `4` on exact wasm and normalized WAT.
- `[O4Z-AUDIT-OR]` is signed off for v0.1.0 behavior parity and removed from `agent-todo.md` after the 2026-06-08 source/lit behavior checklist, focused test expansion, and final 100000-case direct compare.
- The reviewed broad families are covered by focused tests: imported idempotent roots, idempotent-adjacent wrapper cleanup, positive/negative write selection, merge conservatism, branch/loop/EH precision, dangerous cycles, direct and tail-call summaries, tail-call wrapper cleanup, terminal-tail debris handling, direct call-chain summaries, and lit-surface negative body shapes.

## Current in-tree status

- The explicit implementation lives in [`../../../../../src/passes/once_reduction.mbt`](../../../../../src/passes/once_reduction.mbt).
- Focused coverage lives in [`../../../../../src/passes/once_reduction_test.mbt`](../../../../../src/passes/once_reduction_test.mbt).
- Preset scheduling coverage lives in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) and [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt).

The current Starshine subset clearly covers:

- explicit integer once-global discovery
- no-param/no-result once-function recognition in flat and single-top-level-block forms
- read and write disqualification for once-globals
- defined no-param/no-result `@binaryen.idempotent` functions as fake once roots
- fixed-point propagation of definitely-set once-bits across direct `call` and direct `return_call` summaries
- redundant direct-call/direct-tail and redundant `global.set` elimination
- trivial once-body cleanup for empty bodies and single-call/single-tail-call wrappers, including the single-top-level-block form
- terminal handling for indirect/reference tail calls without target inference, including recursive dead-tail cleanup

## 2026-07-21 direct-tail correction

The v131 source review found that the old local test/documentation treated direct `return_call` as intentionally outside Binaryen's call semantics. That was incorrect: Binaryen represents ordinary and tail direct calls with the same `Call` node and its `OnceReduction::Optimizer::visitCall(...)` sees both. Starshine's split raw opcodes therefore created two direct-tail parity gaps plus one raw terminal-control correctness gap for indirect/reference tails.

Red-first public tests now prove:

- a function ending in direct `return_call` contributes its target's guaranteed once facts to callers;
- flat and block-wrapped once bodies strip their redundant guard/set prefix when the sole payload is direct `return_call`, under the existing cycle guard; and
- direct, indirect, and reference tail calls terminate cleanup regions, while indirect/reference tails do not infer any target, so unreachable trailing global accesses cannot poison candidate discovery.

The implementation is in `src/passes/once_reduction.mbt`; focused behavior is in `src/passes/once_reduction_test.mbt`.

Final deterministic validation passed `moon info`, `moon fmt`, focused once-reduction `44/44`, pass-package `6300/6300`, and full Moon `9786/9786`. The three source repros produced exact normalized v131 WAT after the issue-2 nop-shape correction: direct-tail summary propagation (`65 -> 55` bytes), trivial direct-tail body cleanup (`72 -> 55`), and indirect terminal-tail cleanup (`83 -> 73`).

The four-lane native matrix used SHA-256 `176fa6aea033ab955838a5c6263201c545332ab73ee2e01f481355dbc9d67938`: regular GenValid and random-all were exact at `100000/100000` and `10000/10000`; wasm-smith had `9956/9956` exact comparable cases plus 44 Binaryen/tool failures; and the dedicated raw-byte profile produced `10000/10000` instances of one inspected terminal-tail Starshine win. In that family, Binaryen v131 allows unreachable post-tail global traffic to poison once discovery, while Starshine removes the terminal debris and the resulting redundant once logic; representative canonical size is `125` versus `144` bytes. There are zero Starshine validation, generation, property, command, size-losing, unknown/risky, or true-semantic failures. See [`./fuzzing.md`](./fuzzing.md) for cache counters and the raw-input explanation.

## 2026-06-08 behavior-gap inventory

The latest source audit is [research note 0717](./index.md). It checked local Binaryen `wasm-opt version 130 (version_130)` and found that `version_130` `OnceReduction.cpp` plus the dedicated lit file are unchanged from the `version_129` sources this dossier already used.

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
- direct `call` and direct `return_call` summary/rewrite parity, with terminal indirect/reference tails kept conservative
- unreachable/dead-trap and post-tail debris cleanup needed for final normalized direct-compare parity

## Refreshed direct-pass signoff

On 2026-06-03, the O4z audit lane ran:

- `moon test src/passes`
- `moon build --target native --release src/cmd`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass once-reduction --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-once-reduction-audit-current-10000-keepgoing`

The compare run reported `9975` compared cases, `9975` normalized matches, `0` semantic mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures. Failure classes were `22` zero-sized recursion group parser/canonicalization failures, `1` bad-section-size command failure, `1` table-index-out-of-range command failure, and `1` invalid-tag-index command failure. These are tracked separately from semantic output mismatches.

`moon info` still crashed in the local Moon tool with the known index-out-of-bounds panic, and `moon fmt --check` still reported unrelated repo-wide migration/format drift.

## Current evidence

The 2026-04-22 source review recorded that the official Binaryen `version_129` release page showed publish date **2026-04-01** and found no teaching-relevant drift in the reviewed current-`main` source/test surfaces at that time. The retained 2026-06-08 behavior inventory later confirmed that local Binaryen `version_130` kept the same `OnceReduction.cpp` and dedicated lit source for this pass.

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

- [research note 0138](./index.md)
- [research note 0536](./index.md)
- [research note 0701](./index.md)
- Saved generated-artifact slot and Binaryen debug-log facts are copied into that committed O4z audit note; any older `.artifacts` path is a local replay identifier, not a durable source link.
- Binaryen `version_131` pass source: <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/OnceReduction.cpp>
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OnceReduction.cpp>
- Binaryen `version_129` annotation helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
- Binaryen `version_129` dedicated lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/once-reduction.wast>
- Implementation: [`../../../../../src/passes/once_reduction.mbt`](../../../../../src/passes/once_reduction.mbt)
- Focused tests: [`../../../../../src/passes/once_reduction_test.mbt`](../../../../../src/passes/once_reduction_test.mbt)
