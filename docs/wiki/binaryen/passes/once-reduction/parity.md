---
kind: comparison
status: working
last_reviewed: 2026-06-03
sources:
  - ../../../raw/binaryen/2026-04-22-once-reduction-primary-sources.md
  - ../../../raw/research/0138-2026-04-20-once-reduction-binaryen-research.md
  - ../../../raw/research/0238-2026-04-21-once-reduction-starshine-strategy-followup.md
  - ../../../raw/research/0256-2026-04-22-once-reduction-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0536-2026-05-06-once-reduction-direct-revalidation.md
  - ../../../raw/research/0701-2026-06-03-once-reduction-o4z-audit.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
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

- Binaryen `version_129` `once-reduction` is a module-level once-bit plus direct-call optimization pass, not a generic repeated-call eliminator.
- Current Starshine already matches the saved generated-artifact `-O4z` slot `4` on exact wasm and normalized WAT.
- That green slot is **not** proof that Starshine already covers the full official `OnceReduction.cpp` surface.
- The 2026-06-03 audit added the source-visible defined-function `@binaryen.idempotent` fake-root path and the main top-level-block once-wrapper shape; imported idempotent calls and Binaryen's broader CFG/dominator precision remain outside the local subset.

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

## Remaining gap

The former largest documented gap, the official idempotent-annotation path, is now partially closed for defined no-param/no-result functions.

Upstream `OnceReduction.cpp` explicitly does this:

- read `Intrinsics::getAnnotations(func.get()).idempotent`
- give the function a fake once-global name with `Names::getValidGlobalName(...)`
- run the ordinary once-call elimination machinery on that fake-global identity

Current Starshine now models that fake-root behavior for defined no-param/no-result functions. It still deliberately keeps imported idempotent calls as a boundary until the exact upstream import semantics are source-confirmed and accepted locally.

Repo-local source evidence:

- `src/passes/once_reduction.mbt` contains idempotent-annotation handling through the function annotation section
- the focused tests cover defined idempotent positives, typed idempotent negatives, and imported idempotent boundary behavior
- the repo parser and lowering layers support function annotations, including `@binaryen.idempotent`, as shown by `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, and `src/wast/module_wast_tests.mbt`

## Other source-visible strategy differences

The local pass is also architecturally narrower than upstream in how it reasons about control flow.

### Upstream

- nested `Scanner` and `Optimizer` passes
- CFG construction
- `DomTree` immediate-dominator reasoning
- shipped lit coverage for after-merge conservatism, try/catch stability, long control-flow chains, and dangerous multi-node cycles

### Local

- recursive instruction-array scanning and rewriting
- explicit `if`-intersection logic and conservative loop / try-table handling in local code
- focused coverage for block-root wrappers, idempotent fake roots, imported/global boundary cases, extra reads, and table / `ref.func` escapes
- still a much smaller control-flow test surface than the full upstream lit file

That does not automatically mean the local pass is wrong.
It does mean the saved green artifact slot should be read as:

- “good on the exercised artifact slice”

not as:

- “fully source-parity-complete with official `OnceReduction.cpp`”

## Lateral divergence to keep explicit

Local code also has one interesting sideways divergence:

- `src/passes/once_reduction.mbt` explicitly mentions `ReturnCall`
- upstream `OnceReduction.cpp` only visits direct `Call`

I did **not** prove in this thread whether that is:

- a harmless local extension
- dead code for current artifacts
- or a parity hazard

So treat it as an explicit open follow-up question, not a silent assumption.

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

The current local test file covers these core families:

- repeated once calls becoming `nop`
- exported-global, imported-global, imported-function, and imported-idempotent boundary conservatism
- flat and single-top-level-block trivial once-body collapse
- multiple independent once-globals
- defined no-param/no-result idempotent fake roots and typed idempotent negatives
- extra once-global read invalidation
- table element plus `ref.func` escape preservation while still removing redundant direct calls

Those tests are real, but they are still much smaller than the full upstream lit control-flow surface.

## Practical signoff rule

For now, treat `once-reduction` as:

- **green on the saved generated artifact**
- **substantially implemented locally for explicit once-global shapes plus defined idempotent fake roots**
- **not yet a full source-surface parity port of Binaryen `OnceReduction.cpp`**

That is the honest status this dossier should preserve.

## Sources

- [`../../../raw/research/0138-2026-04-20-once-reduction-binaryen-research.md`](../../../raw/research/0138-2026-04-20-once-reduction-binaryen-research.md)
- [`../../../raw/research/0536-2026-05-06-once-reduction-direct-revalidation.md`](../../../raw/research/0536-2026-05-06-once-reduction-direct-revalidation.md)
- [`../../../raw/research/0701-2026-06-03-once-reduction-o4z-audit.md`](../../../raw/research/0701-2026-06-03-once-reduction-o4z-audit.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OnceReduction.cpp>
- Binaryen `version_129` annotation helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
- Binaryen `version_129` dedicated lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/once-reduction.wast>
- Implementation: [`../../../../../src/passes/once_reduction.mbt`](../../../../../src/passes/once_reduction.mbt)
- Focused tests: [`../../../../../src/passes/once_reduction_test.mbt`](../../../../../src/passes/once_reduction_test.mbt)
