# 0073 - Reorder Locals Binaryen Comparison

## Scope

- Research the exact `reorder-locals` behavior used by the local Binaryen oracle for this worktree.
- Map that behavior onto Starshine's current boundary module form and hot IR ownership rules.
- Define a concrete implementation plan for the first Starshine port.

## Oracle Version

- Local toolchain check:
  `wasm-opt --version` reports `wasm-opt version 125 (version_125)`.
- This doc therefore treats Binaryen `version_125` as the canonical source.

## Primary Sources

- Binaryen source:
  - `version_125/src/passes/ReorderLocals.cpp:17-165`
  - `version_125/src/passes/pass.cpp:675-709`
  - `version_125/src/passes/CoalesceLocals.cpp:18-26`
  - `version_125/src/passes/LocalSubtyping.cpp:17-185`
- Starshine source relevant to the port:
  - `src/lib/types.mbt`
  - `src/lib/util.mbt`
  - `src/lib/module.mbt`
  - `src/validate/validate.mbt`
  - `src/ir/README.md`
  - `src/ir/hot_core.mbt`
  - `src/ir/hot_types.mbt`
  - `src/passes/optimize.mbt`
  - `src/passes/pass_manager.mbt`

## Project Structure Relevant To This Pass

- Starshine currently has two important function-body forms:
  - boundary `@lib.Func`, stored in `Module.code_sec`
  - hot `@ir.HotFunc`, the only optimizer-owned body IR
- Boundary functions separate params from body locals:
  - params come from the declared function type
  - body locals live in `@lib.Func(@lib.Locals, @lib.Expr)`
- `@lib.FunctionLocals::from_local_decls(...)` combines those two views into one total local table when needed.
- Boundary instructions carry local indices only on:
  - `LocalGet(LocalIdx)`
  - `LocalSet(LocalIdx)`
  - `LocalTee(LocalIdx)`
- Hot IR also separates params from body locals:
  - `HotLocals.params`
  - `HotLocals.locals`
- Hot local indices are plain integers stored in `node.imm0` on `HotOp::LocalGet`, `HotOp::LocalSet`, and `HotOp::LocalTee`.
- Name-section local metadata is boundary-owned, not hot-owned:
  - `NameSec.local_names : IndirectNameMap?`
  - validation checks those indices against `params + body locals`
- At research start, the pass registry classified `reorder-locals` as `BoundaryOnly`, but the pipeline already supported true module passes interleaved with hot passes.

## Exact Binaryen Behavior

Binaryen's implementation is small and specific. It is not a liveness pass and it is not a local-minimization pass in the `coalesce-locals` sense.

- The pass is function-parallel.
- It returns early when a function has no body vars.
  Parameters alone mean no work.
- It allocates two arrays over all local indices, including params:
  - `counts[local]`
  - `firstUses[local]`
- It walks the function body and increments `counts` on every:
  - `LocalGet`
  - `LocalSet`
- In Binaryen IR, `local.tee` is represented by `LocalSet` with tee state, so tees are counted through the `LocalSet` visitor.
- The first time a local is seen, it records an increasing `firstUses` rank.

That yields the real ordering rule:

- params stay before body vars
- params keep their original order
- body vars sort by descending access count
- ties among body vars with nonzero count break by first observed access
- ties among body vars with zero count break by original index

Two details matter for parity:

- Binaryen counts writes as accesses.
  A local with only `local.set` or only `local.tee` traffic is not dropped by this pass.
- The pass drops only body vars whose final access count is exactly zero.
  It does not try to prove a write is dead; that is earlier-pass work.

After sorting, Binaryen rebuilds the body-var list:

- params remain fixed
- body vars are appended in sorted order
- rebuilding stops at the first zero-count body var
- because the array is already sorted by count, that removes every unused body var

It then constructs the inverse remap and applies it to:

- every `LocalGet`
- every `LocalSet`
- the function's local-name maps

Names for dropped body vars disappear. Parameter names stay in place because parameters stay in place.

Binaryen also marks the pass as not needing non-nullable-local fixups. That matches the algorithm: it only renumbers and drops completely unaccessed body locals, and it never changes local types.

## Scheduler Placement In Binaryen

In the default no-DWARF function pipeline for `version_125`, `reorder-locals` runs three times:

1. after `simplify-locals-nostructure` and `vacuum`
2. after `simplify-locals` and `vacuum`
3. after the second `coalesce-locals`

The surrounding source comments explain why:

- the early slot removes trivially unused locals before heavier local work
- `local-subtyping` runs before `coalesce-locals`, because coalescing can force a wider supertype
- `coalesce-locals` is intended to run after `simplify-locals` and `reorder-locals`, because that reduces the local set it has to color

So `reorder-locals` is both:

- a small code-size pass on its own
- a cleanup/canonicalization pass that prepares later local passes

## Implications For Starshine

The cleanest first Starshine port is a module pass, not a hot pass.

Reasons:

- Binaryen's pass is fundamentally about boundary-local numbering and local-name metadata.
- Starshine hot IR does not own `NameSec.local_names`, so a hot-only implementation would still need boundary-side repair work.
- The current algorithm needs no CFG, liveness, dominance, SSA, or hot-region surgery.
- The current pipeline can already run module passes anywhere in the requested order.

That means the first port should operate directly on `@lib.Module`:

- iterate defined functions in `code_sec`
- resolve each function's param types from the module signature
- flatten body locals into a linear body-local type array
- count accesses and first-use ranks over the nested `Expr`
- compute the Binaryen-style remap
- rewrite the function body local indices
- rebuild the function's body locals with `Locals::from_types(...)`
- rewrite that function's `NameSec.local_names` entry if present

One more boundary detail matters here:

- `Module.raw_name_sec_payload` must not survive a changed local layout
- the binary encoder prefers `raw_name_sec_payload` over structured `name_sec`
- so a changed pass result must clear the raw payload cache

The safest pattern is:

- return the original module unchanged on a no-op
- construct a fresh module with updated `code_sec` and updated `name_sec` when anything changed
- omit `raw_name_sec_payload` in that changed result

## Proposed Implementation Plan

### RL001 - Exact Reindexing Pass

- Add `src/passes/reorder_locals.mbt`.
- Expose `reorder_locals_run_module_pass(mod_ : @lib.Module) -> @lib.Module`.
- Reclassify `reorder-locals` from `BoundaryOnly` to `ModulePass` in `src/passes/optimize.mbt`.
- Wire it through `run_hot_pipeline_apply_module_pass(...)`.

Implementation shape:

- Build `Env::new().with_module(mod_)` once to resolve params by absolute `FuncIdx`.
- For each defined function:
  - compute `param_count`
  - flatten body locals to `Array[ValType]`
  - compute total-local `counts` and `first_uses`
  - count `LocalGet`, `LocalSet`, and `LocalTee`
  - sort `new_to_old` using Binaryen's exact comparator
  - force the parameter prefix back to identity order
  - rebuild body locals from the sorted live suffix, stopping at first zero-count body local
  - build `old_to_new`
  - rewrite the function body recursively
- If a function's reordered body-local list and rewritten body are identical to the input, keep the original function object.

### RL002 - Metadata And Slot Integration

- Rewrite `NameSec.local_names` only for defined functions that changed.
- Preserve imported-function local-name entries untouched.
- Drop names for removed body locals.
- Once the standalone pass is correct, add the intended slot coverage where the surrounding pass availability makes that honest.

For this worktree, I do not need to force the full triple-slot preset wiring first.
The exact pass behavior should land before we claim Binaryen scheduler parity around the missing `simplify-locals-nostructure`, `local-subtyping`, and `coalesce-locals` neighbors.
That policy is now explicit in the tree: `reorder-locals` remains available as an explicit module pass, and preset coverage intentionally stays absent until those neighboring local passes land.

## Test Plan

Add focused coverage beside the implementing file and registry tests around it.

- function with params only: no-op
- unused body locals: dropped
- dead-write-only body local: retained
- `local.tee`-only body local: retained
- higher access count sorts earlier
- equal nonzero access counts sort by first access order
- zero-count locals preserve original order before being dropped
- nested `block` / `if` / `loop` / `try_table` local indices rewrite correctly
- `NameSec.local_names` rewrites for changed defined functions
- imported-function local names remain untouched
- changed pass result clears stale raw name payload
- pipeline accepts `--reorder-locals` as a real module pass

Validation while implementing:

- `moon info`
- `moon fmt`
- focused `moon test` runs for the new pass and registry/CLI surfaces
- `moon test`

## Open Questions

- The raw sorter itself is no longer the suspected gap. I checked Binaryen's actual pass source at
  `version_125/src/passes/ReorderLocals.cpp`, and the implementation matches Starshine's current raw algorithm:
  count `LocalGet` and `LocalSet` accesses, use first-seen rank as the nonzero-count tiebreak, keep params fixed, and drop only zero-count body locals.
- The remaining mismatch sits outside that sort. A tiny hand-written multivalue carrier repro still compares red, but `wasm-opt` with no passes already rewrites that input from `14` body locals to `19` before `reorder-locals` even runs:
  `wasm-opt /tmp/rl-min-triple-carrier.wasm --all-features -o /tmp/rl-min-triple-carrier-nop.raw.wasm`.
- Running `--reorder-locals` on that Binaryen-loaded `19`-local fixture is still not raw-output stable across engines:
  - Starshine keeps the `19`-local shape and reorders it.
  - Binaryen emits a `24`-local shape from the same input, introducing another carrier layer on writeback.
- `bun scripts/self-optimize-compare.ts` now has explicit Binaryen-boundary controls for this investigation:
  - `--binaryen-nop-roundtrips <n>` replays a fixed number of Binaryen no-pass writebacks before the actual compare.
  - `--binaryen-nop-until-stable <max>` keeps replaying no-pass writebacks until the bytes stop changing or the max is hit, and records both the effective input path and whether the boundary converged.
- There is now a smaller minimal blocker than the imported-call fixture. A plain single-value tee/set chain stays stable under repeated Binaryen runs, but a tiny triple-result block repro already grows on the first writeback:
  - raw input: `6` body locals
  - after one Binaryen `--reorder-locals`: `13` body locals
  - after a second Binaryen `--reorder-locals`: `15` body locals
  Both the raw `6`-local block repro and Binaryen's own `13`-local first-writeback form still compare red through `bun scripts/self-optimize-compare.ts <fixture>.wasm --reorder-locals`.
- That block-only case does at least converge. The new explicit compare boundary confirms that
  `bun scripts/self-optimize-compare.ts /tmp/rl-grow-block3.wasm --binaryen-nop-until-stable 5 --reorder-locals`
  stabilizes after `3` no-pass writebacks (`Binaryen no-pass converged: yes`) and then compares green (`Canonical wasm equal: yes`, `Normalized WAT equal: yes`).
- Multi-result calls are the harder remaining slice. The earlier imported triple-result call repro is not special because it is imported; an internal triple-result callee shows the same behavior. Repeated Binaryen no-pass roundtrips keep growing by `+5` locals each time instead of converging:
  - imported call repro: `19 -> 24 -> 29 -> 34 -> 39`
  - internal call repro: `11 -> 16 -> 21 -> 26`
  So the smallest currently known irreducible blocker is now "multi-result call writeback," not multivalue blocks in general.
- The new explicit compare boundary confirms that the call slice still does not settle. Both
  `bun scripts/self-optimize-compare.ts /tmp/rl-grow-call3.wasm --binaryen-nop-until-stable 5 --reorder-locals`
  and
  `bun scripts/self-optimize-compare.ts /tmp/rl-grow-internal-call3.wasm --binaryen-nop-until-stable 5 --reorder-locals`
  stop at the max with `Binaryen no-pass converged: no`, and both remain red (`Canonical wasm equal: no`, `Normalized WAT equal: no`) even after starting from the fifth Binaryen no-pass writeback.
- Binaryen is also not idempotent here. Re-running
  `wasm-opt /tmp/rl-min-triple-carrier-nop-compare/binaryen.raw.wasm --all-features --reorder-locals`
  grows the same tiny repro again from `24` to `29` body locals.
- That means the current red compare is not a remaining `reorder-locals` comparator bug inside Starshine. It is a Binaryen loader/writeback representation gap around stack-carried multivalue temporaries. The pass algorithm has been matched; the emitted wasm still differs because Binaryen keeps re-materializing extra carrier locals outside the raw sort itself.
- The full-artifact replay is still useful, but its blocker should now be read differently:
  - absolute `Func 71` was the first raw full-module local-shape jump already pinned earlier
  - the canonicalized full-module replay still first drifts at defined-function ordinal `63`
  - extracted standalone replays for the pinned functions still go green because they avoid the same full-module load/writeback context
- The new stable-boundary tooling does not rescue the full artifact either. Running
  `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --binaryen-nop-until-stable 5 --reorder-locals`
  still reports `Binaryen no-pass roundtrips: 5`, `Binaryen no-pass converged: no`, `Canonical wasm equal: no`, and `Normalized WAT equal: no`. The guarded signoff form
  `--binaryen-nop-until-stable 5 --require-binaryen-nop-converged`
  therefore fails immediately on the artifact before the compare phase.
- Before chasing that boundary further, the sorter hot path was trimmed in-tree:
  defined-function params are now resolved once from raw module metadata instead of through validation lookups on every function, the pass sorts only accessed body locals, the scan records touched body locals directly instead of re-filtering every slot afterward, stable accessed-index bodies skip recursive rewrites, local-name rewrites skip their resort when the remap stays monotonic, the final body rewrite now mutates nested instruction arrays in place instead of allocating replacement arrays for every rewritten `Expr`, rebuilt locals now emit `LocalRun`s directly instead of materializing a transient reordered type array and then re-running `Locals::from_types`, and local flattening now expands `Locals` runs directly instead of routing through the iterator adapter. On the same full-artifact compare command above, the earlier `176.364 ms` Starshine pass-time sample moved down first into a `166.266-173.189 ms` band, then into a roughly `151.211-155.709 ms` band after the scan/prefix fast paths, then into a `140.078-150.027 ms` band once the rewrite stopped rebuilding nested arrays, then into a `131.081-139.564 ms` band after the direct-run locals rebuild and small array preallocation cleanup, and finally into a new roughly `121.286-133.330 ms` band after the flatten path dropped the iterator layer. That is still not enough to hit the Binaryen ratio target, but it confirms there was meaningful low-risk performance headroom inside Starshine's sorter before any Binaryen boundary work.
- The next honest follow-up is no longer "tune the sorter." It is either:
  - port the Binaryen-style stack/local materialization layer that surrounds this pass, or
  - redefine pass-level parity signoff around a representation-stable boundary instead of raw emitted wasm.
- The detailed source-level explanation for that boundary gap now lives in
  [`./0074-2026-04-02-binaryen-multivalue-call-local-disparity.md`](./0074-2026-04-02-binaryen-multivalue-call-local-disparity.md):
  the extra locals come from Binaryen's multivalue call packaging and StackIR writeback, not from `ReorderLocals.cpp`.
