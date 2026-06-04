---
kind: research
status: working
last_reviewed: 2026-06-04
sources:
  - ../../binaryen/passes/code-folding/index.md
  - ../../binaryen/passes/code-folding/binaryen-strategy.md
  - ../../binaryen/passes/code-folding/implementation-structure-and-tests.md
  - ../../binaryen/passes/code-folding/starshine-strategy.md
  - ../../binaryen/passes/code-folding/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/code-folding/terminating-tails.md
  - ../../binaryen/passes/code-folding/wat-shapes.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../../../src/passes/code_folding.mbt
  - ../../../../src/passes/code_folding_test.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/cli/cli_test.mbt
  - ../../../../agent-todo.md
---

# Code-Folding O4z Pass Audit

## Scope

Started the active v0.1.0 slice `[O4Z-AUDIT-CF]` for `code-folding`, the next O4z per-pass audit after the completed `[O4Z-AUDIT-LCSE]` entry in `agent-todo.md`. This pass sits in the late no-DWARF cleanup neighborhood immediately before `merge-blocks`, `remove-unused-brs`, `remove-unused-names`, the second `merge-blocks`, late peepholes, `heap-store-optimization`, `rse`, and final `vacuum`.

The audit checked owner/source wiring, focused coverage against the source-backed Binaryen shape catalog, and remaining work needed before this slice can be closed.

## Current implementation map

- `src/passes/code_folding.mbt` owns the active HOT descriptor and narrowed transform, now including the June single-result typed block-exit payload-sharing slice.
- `src/passes/code_folding_test.mbt` owns focused public-pipeline WAT coverage for current positives and safety bailouts.
- `src/passes/optimize.mbt` registers `code-folding` as an active hot pass.
- `src/passes/pass_manager.mbt` includes `code-folding` in the default function pipeline and dispatches requests to `code_folding_run(ctx, func)`.
- `src/cli/cli_test.mbt` preserves `--code-folding` pass-token parsing and explicit pass ordering.

## Source-backed shape checklist

Binaryen's documented `code-folding` contract still has two distinct families:

1. expression-exit folding for named block exits and foldable `if` arms;
2. function-ending terminating-tail folding for `return`, `return_call*`, and `unreachable` paths through helper-label sharing.

Starshine currently implements a deliberately narrower expression-exit and cleanup subset. The current source/test review found these in-tree covered families:

- void and value `if` arm suffix hoisting;
- worthwhile full-arm `if` collapse;
- unprofitable tiny full-void `if` bailout;
- structured suffix hoisting through unused labels;
- outer-branch full-tail hoisting;
- block-exit tail sharing with fallthrough;
- nested branch-payload helper-wrapper sharing;
- conservative full-`if` terminal suffix sharing for empty-payload `return` endings;
- exiting dead-value block flattening;
- trailing unreachable cleanup when the result context does not still require bottom.

This audit started the missing-shape coverage by adding focused tests for:

- full `if` arms ending in `unreachable`, ensuring terminal suffix sharing is not return-only;
- unsupported `br_on_null` label poisoning for block-exit folding;
- live-label structured `if` suffixes, ensuring branch-target-bearing wrappers are not hoisted out from under their labels.

The continuation pass then widened the implementation and tests for a source-backed branch-value expression-exit slice:

- typed named-block exits with one carried branch payload can now share that payload with a matching fallthrough value;
- typed named-block exits with two or more matching carried branch payloads can share one value even when the block has no normal fallthrough;
- the rewrite demotes the target block's result to void, strips the selected plain-`br` payloads, and inserts one shared payload immediately after the block;
- the slice remains deliberately single-result, plain-`br` only, and reuses the existing suffix equality, unsupported-branch poisoning, and branch-target survival checks.

## Remaining direct completeness gaps

These are not new regressions; they are the known difference between Starshine's accepted narrow direct pass and Binaryen's broader `CodeFolding.cpp` surface.

- Function-ending helper-label sharing is still not implemented for general `return`, `return_call`, `return_call_indirect`, `return_call_ref`, or `unreachable` tail groups outside the conservative full-`if` terminal case.
- Branch-value folding for typed named-block exits now covers single-result plain-`br` payload sharing with matching fallthrough or multiple branch payloads, but remains narrower than Binaryen's full branch-payload suffix model: no multi-value payloads, no `br_if` / `br_table` / `br_on_*` participation, no helper-block profitability search, and no broader nested suffix splitting beyond the carried payload root.
- EH-sensitive movement remains a hard bailout; there is no local nested-pop repair equivalent for this pass.
- Broader helper-block creation and profitability modeling remain conditional future work rather than a v0.1.0 direct blocker unless a semantic, validity, or proven downstream code-size issue appears.
- The exact late O4z slot/neighborhood still needs refreshed generated evidence before the audit slice can close.

## Validation status

The continuation completed baseline slice `[O4Z-AUDIT-CF-A]` for the current widened implementation.

Commands and results:

```sh
moon info
# Finished. moon: ran 6 tasks, now up to date

moon fmt
# Finished. moon: ran 2 tasks, now up to date

moon test src/passes
# Total tests: 1590, passed: 1590, failed: 0

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in pass_manager.mbt and 0 errors
# Native binary path in this workspace: _build/native/release/build/cmd/cmd.exe

bun scripts/pass-fuzz-compare.ts \
  --pass code-folding \
  --count 1000 \
  --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-code-folding-audit-1000 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
# Compared cases: 998/1000
# Normalized matches: 998
# Compare-normalized matches: 0
# Validation failures: 0
# Property failures: 0
# Generator failures: 0
# Command failures: 2 (command-class.binaryen-rec-group-zero)
# Mismatches: 0

bun scripts/self-optimize-compare.ts \
  tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/code-folding-audit-self-compare \
  --timing-only \
  --code-folding
# Starshine runtime (ms): 1184.332
# Binaryen runtime (ms): 586.258
# Starshine pass runtime (ms): 172.276
# Starshine pass skipped raw: no
# Binaryen pass runtime (ms): 169.576
```

The pass-local timing is within the repo floor (`172.276ms <= 2 * 169.576ms`). The compare smoke had zero mismatches; the two command failures are `command-class.binaryen-rec-group-zero`, classified as tool/Binaryen command failures rather than Starshine semantic mismatches.

Additional commit-ready validation:

```sh
moon test
# Total tests: 4775, passed: 4775, failed: 0
```

Still required before closing the overall `[O4Z-AUDIT-CF]` parity track:

- scale direct compare to `10000` after the next behavior-widening batch or before closeout;
- run the late `code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks` neighborhood replay;
- implement or explicitly classify the remaining Binaryen behavior-parity gaps sliced in `agent-todo.md`.

## Audit classification

Current agent classification: `code-folding` is wired and semantically accepted as a narrow direct pass based on prior May evidence, and the June audit has now widened one source-backed expression-exit gap for single-result typed block-exit branch payload sharing. Baseline June validation is green at `moon test src/passes`, full `moon test`, a 1000-case direct compare smoke, and a pass-local timing lane within the <=2x floor. `[O4Z-AUDIT-CF]` is still not complete because Binaryen behavior parity requires the remaining expression-exit, terminating-tail, movement-safety, EH, fixpoint, and late-neighborhood slices now tracked in `agent-todo.md`.
