---
kind: concept
status: supported
last_reviewed: 2026-07-01
sources:
  - ../../../raw/research/1399-2026-06-30-slns-v130-source-refresh-and-tee-gap.md
  - ../../../raw/research/0552-2026-05-08-simplify-locals-nostructure-ordered-slot-replay.md
  - ../../../raw/research/0543-2026-05-06-slns-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md
  - ../../../raw/research/0433-2026-05-04-simplify-locals-nostructure-current-main-recheck.md
  - ../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md
  - ../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tuple-optimization/index.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nonesting/index.md
  - ../reorder-locals/index.md
  - ../coalesce-locals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./parity.md
  - ./variant-surface.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../tuple-optimization/index.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nonesting/index.md
  - ../reorder-locals/index.md
  - ../coalesce-locals/index.md
---

# Starshine `simplify-locals-nostructure` port readiness and validation

## Why this page exists

The landing, strategy, variant, and WAT-shape pages explain what Binaryen does.
This page answers the follow-along question:

- what is the smallest honest local slice?
- what must stay disabled so the sibling does not become full `simplify-locals`?
- what tests and oracle lanes prove the no-structure contract?

## Current hold point

The direct pass is landed and active. The `version_130` audit is closed with current four-lane fuzz evidence after the latest SLNS code change and an explicitly accepted pass-local performance caveat. Starshine treats `simplify-locals-nostructure` as an active hot pass, and also accepts the local compatibility spelling `simplify-locals-no-structure`.

Current state:

- upstream Binaryen spelling: `simplify-locals-nostructure`
- local alias: `simplify-locals-no-structure`
- local category: active hot pass
- CLI / pipeline behavior: runnable direct pass plus exact-slot ordered replay helper
- owner: `src/passes/simplify_locals.mbt`
- preset role: public `optimize` / `shrink` still stay unchanged; historical exact-slot replay is useful, and direct SLNS `version_130` closure is recorded in [`./parity.md`](./parity.md)

## Exact local code map today

- `src/passes/optimize.mbt`
  - active hot entries for `simplify-locals-nostructure` and `simplify-locals-no-structure`
  - `tuple_optimization_exact_slot_prereqs_ready()` now sees the no-structure neighbor as active
  - `simplify_locals_nostructure_exact_slot_passes()` exposes the proven `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals` replay lane
  - public presets remain conservative because neighboring preset work is still owned elsewhere
- `src/passes/simplify_locals.mbt`
  - owns the no-structure descriptors and alias descriptor
  - runs the shared local-sink/dead-cleanup cycles with structure-result rewrites disabled
  - canonical SLNS no longer has a whole-function pre-existing `local.tee` bailout for straight-line/no-control functions or the root dropped-tee plus later-control shape; protected-root/protected-child cleanup fixed the bounded generated embedded-control tee residual family, and the current random all-profiles required lane is normalized-green. Treat new embedded-control tee drift as a fresh regression rather than the old `control-local-tee-hazard-noop` blocker.
- `src/passes/pass_manager.mbt`
  - dispatches both spellings to `simplify_locals_nostructure_run(...)`
  - shares the raw simplify-locals artifact skip/rewrite gates and writeback validation guards
- `src/passes/simplify_locals_nostructure_test.mbt`
  - covers straight-line sinking, the negative guarantee that the pass does not synthesize `if` result structures, the exact ordered `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals` replay, and current active-audit slices for tee, overwrite, try_table, global, load, and table-barrier behavior
- `scripts/lib/pass-fuzz-compare-task.ts` and `scripts/lib/self-optimize-compare-task.ts`
  - accept the canonical flag and compatibility alias, mapping the alias to Binaryen's canonical `--simplify-locals-nostructure` spelling

## Validation evidence

Current active-audit evidence:

1. 2026-06-30 existing-tee slices:
   - Red-first `moon test src/passes --filter "simplify-locals-nostructure optimizes unrelated locals when an existing tee is present"` failed while the function stayed unchanged due the broad existing-tee bailout.
   - Red-first `moon test src/passes --filter "simplify-locals-nostructure optimizes root existing tee with later control"` failed while the function stayed unchanged under the first coarse structured-control tee guard; Binaryen `version_130` probe `.tmp/slns-structured-existing-tee.opt.wat` removes the root dropped tee and sinks the unrelated local while preserving the `if` boundary.
   - Red-first `moon test src/passes --filter "simplify-locals-notee-nostructure optimizes unrelated locals when an existing tee is present"` failed while the no-tee sibling bailed on any existing tee; Binaryen `version_130` probe `.tmp/slns-existing-tee-notee.opt.wat` proves no-tee still cleans existing dropped tees and single-use unrelated locals.
   - After implementation, all three focused tests passed; the kept guard is explicit trace reason `control-local-tee-hazard-noop` and is now limited to tees embedded under structured control.
   - `moon fmt` — passed/no work after final code changes.
   - `moon test src/passes/simplify_locals_nostructure_test.mbt` — `17/17` passed.
   - Tuple-neighbor guard checks — focused `optimize-instructions tuple.extract localization survives simplify-locals-nostructure neighbor` and `optimize-instructions earlier and later tuple.extract localization survives simplify-locals-nostructure neighbor` both passed.
   - `moon test src/passes` — `3666/3666` passed.
   - `moon build --target native --release src/cmd` — passed with pre-existing warnings; actual native binary path is `_build/native/release/build/cmd/cmd.exe`.
   - `.tmp/pass-fuzz-slns-slice-genvalid-200` — `200/200` compared, `200` normalized matches, zero mismatches/failures/command failures.
   - `.tmp/pass-fuzz-slns-tee-guard2-genvalid-500` — `500/500` compared, `500` normalized matches, zero mismatches/failures/command failures; Binaryen cache `500/0` on the final rerun.
   - `.tmp/slns-tee-guard2-timing-structured` — canonical wasm equal on the structured root-tee probe; Starshine whole command `1.588ms` vs Binaryen `2.553ms`, but pass-local Starshine `0.078ms` vs Binaryen `0.053ms`, so the user-requested pass-local speed target is not yet met.
   - A stale-path compare using `target/native/release/build/cmd/cmd.exe` produced only `starshine-command-failed` ENOENT failures and is not semantic evidence.
2. 2026-06-30 try_table EH barrier slice:
   - Binaryen `version_130` probe `.tmp/slns-try-table-nonthrowing-sink.opt.wat` sinks a pure pending `i32.const 7` into a `try_table` body and nops the original set.
   - Binaryen `version_130` probe `.tmp/slns-try-table-throwing-barrier.opt.wat` keeps `local.set 0 (call $maybe)` before `try_table` because the call may throw into a handler if moved.
   - Starshine now clears only throwing pending sinkables before scanning a `try_table` body with surviving parent sinkables, clears after the body, and scans catch-list roots with a fresh sinkable set.
   - Focused tests `simplify-locals-nostructure sinks nonthrowing set into try_table body` and `simplify-locals-nostructure keeps throwing set before try_table body` pass; focused file `21/21`, `moon test src/passes` `3670/3670`, and `.tmp/pass-fuzz-slns-trytable-barrier-genvalid-500` `500/500` normalized with zero failures.
   - Plain legacy `try` is not claimed closed because the focused WAT path currently desugars that syntax before HOT `Try` coverage.
3. 2026-06-30 distinct-global effect/order slice:
   - Binaryen `version_130` probe `.tmp/slns-effect-audit/global-get-set.opt.wat` sinks a pending `global.get $g` across `global.set $h`.
   - Binaryen `version_130` probe `.tmp/slns-effect-audit/global-get-set-same.opt.wat` keeps the local carrier across `global.set $g`.
   - Memory/table probes in the same directory keep carriers across writes; dynamic read-only loads commute in Binaryen.
   - Starshine now records exact global reads/writes for pending local-set values and uses them in directional invalidation.
   - Red-first focused `simplify-locals-nostructure sinks global.get across unrelated global.set` failed before implementation and passed after; `simplify-locals-nostructure keeps global.get before same-global set` passes.
   - Focused SLNS file `23/23`, simplify-locals white-box `4/4`, `moon fmt`, `moon test src/passes` `3672/3672`, native `src/cmd` build, and `.tmp/pass-fuzz-slns-global-effects-genvalid-500` `500/500` normalized with zero failures all passed.
4. 2026-06-30 dynamic read-only-load/table-barrier effect slice:
   - Binaryen `version_130` probe `.tmp/slns-effect-audit/load-load.opt.wat` sinks the first dynamic read-only load to the final use after dropping the second load.
   - Binaryen `version_130` probes `.tmp/slns-effect-audit/table-get-set-same.opt.wat` and `.tmp/slns-effect-audit/table-get-set-distinct.opt.wat` both keep the `table.get` local carrier before `table.set`, so there is no current different-table positive to implement.
   - Red-first focused `simplify-locals-nostructure sinks dynamic read-only loads` failed before implementation and passed after. Starshine now allows one-use `Load` movement only for parameter-reading address subtrees; focused dependent-load tee coverage and atomic-read barrier coverage both passed after the guard was narrowed.
   - Focused table same/distinct tests document Binaryen-stationary barriers and passed as green coverage refreshes.
   - Focused SLNS file `26/26`, simplify-locals white-box `4/4`, `moon test src/passes` `3675/3675`, native `src/cmd` build, and `.tmp/pass-fuzz-slns-load-table-effects-genvalid-500` `500/500` normalized with zero failures all passed.
5. 2026-06-30 direct-call/null-trap effect coverage slice:
   - Binaryen `version_130` probes `.tmp/slns-call-audit/call-pure-const.opt.wat`, `.tmp/slns-call-audit/call-import-const.opt.wat`, and `.tmp/slns-call-audit/call-pure-load.opt.wat` keep carriers before direct/imported calls, including a locally-defined pure-looking direct callee.
   - Binaryen `version_130` probe `.tmp/slns-null-audit/ref-as-non-null-load-nullable-local.opt.wat` sinks a nullable-local `ref.as_non_null` carrier across a dropped dynamic read-only load.
   - Starshine already matched these two refreshed boundaries, so focused tests `simplify-locals-nostructure keeps local before direct call barrier` and `simplify-locals-nostructure sinks ref.as_non_null across read-only load` were added as green coverage refreshes, not red-first gap fixes.
   - Nondefaultable-local/refinalization fixups remain open; a direct nondefaultable-local `ref.as_non_null` probe currently exposes Starshine validation/tooling limitations rather than a safe SLNS closure claim.
6. Final closeout fuzz matrix after explicit performance-caveat acceptance:
   - Regular GenValid `.tmp/pass-fuzz-slns-genvalid-100000-closeout-accepted-perf`: compared and normalized `100000/100000`, zero failures.
   - Explicit wasm-smith `.tmp/pass-fuzz-slns-wasm-smith-10000-closeout-accepted-perf`: compared/normalized `9956/10000`, zero mismatches, `44` Binaryen/oracle command failures.
   - Dedicated aggregate `.tmp/pass-fuzz-slns-genvalid-all-10000-closeout-accepted-perf`: compared `10000/10000`, normalized `9069`, with `931/931` residuals classified annotation-only and all residual artifacts validating.
   - Random all-profiles `.tmp/pass-fuzz-slns-genvalid-random-all-profiles-10000-closeout-accepted-perf`: compared and normalized `10000/10000`, zero failures.
7. Historical 2026-05-06 refreshed standard signoff:
   - `moon info`
   - `moon fmt`
   - `moon test`
   - `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-simplify-locals-nostructure`
     - `6759/10000` comparable mixed-generator cases
     - `6759` normalized matches
     - `0` mismatches, validation failures, or generator failures
     - `20` Binaryen empty-recursion-group parser/canonicalization command failures
   - `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals-no-structure --out-dir .tmp/pass-fuzz-simplify-locals-no-structure`
     - `6759/10000` comparable mixed-generator cases
     - `6759` normalized matches
     - `0` mismatches, validation failures, or generator failures
     - `20` Binaryen empty-recursion-group parser/canonicalization command failures
8. Earlier landed-slice focused evidence:
   - `moon test src/passes`
   - `moon test src/cmd`
   - `bun scripts/pass-fuzz-compare.ts --starshine-bin _build/native/release/build/cmd/cmd.exe --pass simplify-locals-nostructure --generator gen-valid --count 10000 --seed 0x5eed --min-compared 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-slns-genvalid-10000-after-raw`
     - `10000/10000` compared
     - `10000` normalized matches
     - `0` mismatches, validation failures, generator failures, or command failures
   - `bun scripts/pass-fuzz-compare.ts --starshine-bin _build/native/release/build/cmd/cmd.exe --pass simplify-locals-nostructure --count 10000 --seed 0x5eed --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-slns-10000-keepgoing-after-raw`
     - `9975/10000` comparable mixed-generator cases
     - `9975` normalized matches
     - `0` mismatches
     - `25` Binaryen-side command failures (`binaryen-rec-group-zero`, `binaryen-bad-section-size`, `binaryen-table-index-out-of-range`, `binaryen-invalid-tag-index`)
9. Earlier artifact evidence:
   - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/self-opt-slns-direct-rerun --simplify-locals-nostructure`
     - normalized WAT equal through fallback
     - canonical function compare equal
     - Starshine pass time `325.166ms`; Binaryen pass time `509466.000ms` in this run

## Remaining validation before preset placement

The direct pass and its exact early local slot are now implemented and oracle-checked. Public preset placement still stays conservative, but the remaining caution is no longer this pass's standalone ordered-slot proof.

What remains belongs to neighboring slices instead:

- `tuple-optimization` exact-slot and feature-off preset proof
- the earlier `code-pushing -> tuple-optimization` side of the neighborhood
- broader local-cluster scheduling work around later `coalesce-locals` / `local-cse` consumers

Keep those preset claims separate from direct-pass and exact-slot signoff so the tracker can say “implemented” without overstating full no-DWARF / saved-`-O4z` preset parity.

## Sources

- [`../../../raw/research/0543-2026-05-06-slns-direct-revalidation.md`](../../../raw/research/0543-2026-05-06-slns-direct-revalidation.md)
- [`../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md)
- [`../../../raw/research/0433-2026-05-04-simplify-locals-nostructure-current-main-recheck.md`](../../../raw/research/0433-2026-05-04-simplify-locals-nostructure-current-main-recheck.md)
- [`../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md)
- [`../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md`](../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md`](../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md)
- Binaryen `version_130` pass source: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/SimplifyLocals.cpp>
- Binaryen `version_130` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
- Binaryen `version_130` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/opt-utils.h>
- Binaryen `version_130` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/local-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/equivalent_sets.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/branch-utils.h>
- Binaryen `version_130` dedicated tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/simplify-locals-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/simplify-locals-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/simplify-locals-notee-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/simplify-locals-notee-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/simplify-locals-nonesting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/simplify-locals-nonesting.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/simplify-locals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/simplify-locals.txt>
