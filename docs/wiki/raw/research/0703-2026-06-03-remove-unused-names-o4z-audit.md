---
kind: research
status: current
last_reviewed: 2026-06-03
sources:
  - ../../binaryen/passes/remove-unused-names/index.md
  - ../../binaryen/passes/remove-unused-names/starshine-hot-ir-strategy.md
  - ../../../../src/passes/remove_unused_names.mbt
  - ../../../../src/passes/remove_unused_names_test.mbt
  - ../../../../src/passes/pass_common.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/remove-unused-names/index.md
  - ../../binaryen/passes/remove-unused-names/starshine-hot-ir-strategy.md
  - ./0517-2026-05-06-remove-unused-names-direct-revalidation.md
---

# `remove-unused-names` O4z audit

## Question

Can the active `[O4Z-AUDIT-RUN]` slice be closed or narrowed with current evidence for label-use tracking, delegate / try behavior, repeated RUN slots, name-section expectations, direct oracle parity, and O4z slot behavior?

## Summary

The direct HOT pass remains semantically clean under the refreshed direct compare lane, and the local tests now cover two audit gaps:

- `Delegate` targets are included in the shared label-use helper used by `remove-unused-names`.
- wasm name-section expectations are explicit: non-label metadata survives, while label-name maps can be dropped after structural control rewrites because those maps can become stale when block wrappers are peeled.

The important O4z finding is that current O4z execution still does **not** run the structural rewrite: `src/passes/pass_manager.mbt` returns the original function for every `remove-unused-names` function pass when `optimize_level >= 4 && shrink_level >= 1` with trace reason `o4z-remove-unused-names-noop`. That makes the current O4z RUN slots correctness-safe but precision-limited: all same-type wrapper collapses and loop demotions are missed in actual O4z mode until that guard is intentionally removed or narrowed.

## Commands and results

Environment note: `.tmp/` had been cleaned before this audit, so the local MoonBit toolchain was restored under `.tmp/moonbit` before running Moon and harness commands.

### Direct compare smoke

```sh
export PATH="$PWD/.tmp/moonbit/bin:$PATH"
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass remove-unused-names \
  --keep-going-after-command-failures \
  --out-dir .tmp/pass-fuzz-remove-unused-names-audit-1000
```

Result:

- compared: 998 / 1000
- normalized matches: 998
- compare-normalized matches: 0
- validation failures: 0
- generator failures: 0
- command failures: 2
- mismatches: 0
- command-failure class: `binaryen-rec-group-zero` x2

### Direct compare closeout lane

```sh
export PATH="$PWD/.tmp/moonbit/bin:$PATH"
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass remove-unused-names \
  --keep-going-after-command-failures \
  --out-dir .tmp/pass-fuzz-remove-unused-names-audit-10000
```

Result:

- compared: 9975 / 10000
- normalized matches: 9975
- compare-normalized matches: 0
- validation failures: 0
- property failures: 0
- generator failures: 0
- command failures: 25
- mismatches: 0

Command-failure breakdown from `summary.json`:

- `binaryen-rec-group-zero`: 22
- `binaryen-bad-section-size`: 1
- `binaryen-table-index-out-of-range`: 1
- `binaryen-invalid-tag-index`: 1

Agent classification: these are Binaryen/canonicalization parser failures, not Starshine semantic mismatches. The saved failure examples all fail before Binaryen can produce the oracle output for comparison.

### Focused tests

```sh
export PATH="$PWD/.tmp/moonbit/bin:$PATH"
moon test src/passes
```

Result:

- total tests: 1486
- passed: 1486
- failed: 0

## Coverage inspected

Existing coverage already present before this audit:

- same-typed nested block peel
- type-index wrapper preservation
- branch rebasing through peeled blocks
- nested-control bailout when an inner branch targets a peeled scope
- `try_table` catch-target bailout
- loop demotion when no continue target survives
- loop bailout when a continue target survives
- optimize preset repeated RUN slots: `src/passes/optimize_test.mbt` checks three `remove-unused-names` starts in the optimize preset, and `src/passes/registry_test.mbt` locks the three RUN slots in optimize/shrink ordering
- repeated explicit pass scheduling trace: `src/passes/trace_golden_test.mbt` covers `remove-unused-names` repeated in a stacked pass sequence

New focused coverage added in this audit:

- `remove-unused-names label-use helper marks delegate targets`
  - Builds a HOT function with an inner block label targeted by `HotOp::Delegate` and asserts `pass_compute_label_used` marks that label.
  - This is helper-level coverage because the current public `@lib.Instruction` model has `TryTable` but not the legacy `try ... delegate` instruction surface.
- `remove-unused-names preserves non-label name-section metadata`
  - Proves function and local names survive a structural `remove-unused-names` rewrite.
- `remove-unused-names drops stale label-name metadata after control rewrites`
  - Locks the current expectation that control-label name maps may be removed after a block peel because label indices no longer map cleanly to the rewritten control structure.

## O4z slot finding

`remove-unused-names` is still scheduled three times in the optimize/shrink preset order, matching the RUN slots that previous generated-audit docs identified. However, current O4z mode does not execute the HOT rewrite for this pass. The raw adapter in `src/passes/pass_manager.mbt` returns the original function with reason `o4z-remove-unused-names-noop` whenever `optimize_level >= 4 && shrink_level >= 1`.

Existing test coverage protects that behavior:

- `src/passes/remove_unused_names_test.mbt`: `remove-unused-names skips O4z raw pass until self-opt encoder stack is safe`

Audit classification:

- correctness risk: low, because the guard is no-op and direct pass parity is clean
- code-size / precision risk: active, because actual O4z misses all same-type wrapper collapses and loop demotions from this pass
- performance risk: low in current O4z mode, because the raw guard avoids lift/writeback work for every RUN slot

## Rewrite-kernel performance follow-up

A follow-up on 2026-06-03 targeted the candidate-heavy direct rewrite fixture from `.tmp/run-kernel-speed/` rather than the O4z no-op guard. The fixture shape is 50,000 repeated functions of `(func $block_N (block (block (nop))))`; the smaller corroborating fixture has 5,000 such functions.

Implementation changes:

- `src/passes/remove_unused_names.mbt` no longer does a global candidate scan plus global `pass_compute_label_used` scan before every rewrite. The HOT fallback now checks only the candidate subtree labels it may remove, preserving the `br`, `br_if`, `br_on_*`, `delegate`, `br_table`, and `try_table` catch safety rules.
- `src/passes/pass_manager.mbt` now has a real raw lowered-instruction rewrite lane for branchless / label-use-free `remove-unused-names` functions. It performs same-type single-child block peeling, loop demotion, and harmless `nop` dropping, and falls back to the HOT path as soon as any branch-like label use or `try_table` label target is present. This is not the existing O4z no-op guard and not a no-candidate skip: it writes changed functions and reports `Starshine pass skipped raw: no` in the compare harness.

Timing evidence after the fix:

- 5k fixture:
  - command: `bun scripts/self-optimize-compare.ts .tmp/run-kernel-speed/remove-unused-names-kernel-5000.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --remove-unused-names --timing-only --out-dir .tmp/run-kernel-speed/final-exact-5000`
  - Starshine pass-local: `0.441 ms`
  - Binaryen pass-local: `0.381 ms`
  - Starshine pass skipped raw: `no`
  - whole command: Starshine `21.781 ms`, Binaryen `12.563 ms`
- 50k fixture, three final timing-only trials:
  - out dirs: `.tmp/run-kernel-speed/final-exact-50000`, `...-trial2`, `...-trial3`
  - Starshine pass-local: `4.749 ms`, `4.773 ms`, `4.510 ms` (median `4.749 ms`)
  - Binaryen pass-local: `2.493 ms`, `2.478 ms`, `2.465 ms` (median `2.478 ms`)
  - pass-local ratio: about `1.92x` slower than Binaryen, within the repo target of Starshine being at least 50% as fast
  - whole command median: Starshine `237.884 ms`, Binaryen `132.146 ms`
  - Starshine pass skipped raw: `no` in all three trials

Semantic evidence after the fix:

```sh
moon test src/passes
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass remove-unused-names \
  --keep-going-after-command-failures \
  --out-dir .tmp/pass-fuzz-remove-unused-names-perf-exact-final-10000
```

Results:

- `moon test src/passes`: 1486 / 1486 passed
- compare: 9975 / 10000 compared, 9975 normalized matches, 0 mismatches, 25 Binaryen/canonicalization command failures

This closes the direct branchless rewrite-kernel performance gap for the audited fixture family. It does **not** change the O4z `o4z-remove-unused-names-noop` guard; O4z precision recovery remains separate.

## Conclusion

Direct `remove-unused-names` remains a correct HOT structural subset with refreshed `10000`-requested oracle evidence and stronger label/name-section tests. The direct branchless rewrite-kernel fixture now runs via an actual raw rewrite lane rather than through no-op raw skipping, reducing the 50k pass-local median from about `148.047 ms` to `4.749 ms` while preserving normalized oracle parity.

Do not treat the O4z RUN slots as fully optimized yet. They are currently guarded no-ops in O4z mode. The remaining active work, if v0.1.0 wants actual O4z `remove-unused-names` cleanup rather than safe no-op scheduling, is to narrow or remove `o4z-remove-unused-names-noop` test-first and replay the self-opt / O4z artifact lane that originally motivated the guard.
