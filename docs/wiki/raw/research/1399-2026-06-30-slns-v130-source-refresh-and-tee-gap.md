# SLNS `version_130` source refresh and existing-tee gap

## Question

Refresh the `simplify-locals-nostructure` source/test inventory against the current local Binaryen oracle (`wasm-opt version 130 (version_130)`) and start the transform-family audit from the highest-risk Starshine gap: existing `local.tee` caused the direct SLNS runner to bail out of the whole function.

## Source inventory

Local source snapshots were downloaded into `.tmp/slns-v130-source/` from official Binaryen `version_130` raw URLs:

- `src/passes/SimplifyLocals.cpp`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/SimplifyLocals.cpp>
- `src/passes/pass.cpp`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/pass.cpp>
- `src/passes/passes.h`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/passes.h>
- `src/pass.h`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/pass.h>
- `src/passes/opt-utils.h`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/opt-utils.h>
- `src/ir/local-utils.h`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/ir/local-utils.h>
- `src/ir/effects.h`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/ir/effects.h>
- `src/ir/equivalent_sets.h`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/ir/equivalent_sets.h>
- `src/ir/linear-execution.h`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/ir/linear-execution.h>
- `src/ir/properties.h`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/ir/properties.h>
- `src/ir/branch-utils.h`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/ir/branch-utils.h>
- `test/passes/simplify-locals-nostructure.wast`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/passes/simplify-locals-nostructure.wast>
- `test/passes/simplify-locals-nostructure.txt`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/passes/simplify-locals-nostructure.txt>
- `test/passes/simplify-locals-notee-nostructure.wast`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/passes/simplify-locals-notee-nostructure.wast>
- `test/passes/simplify-locals-notee-nostructure.txt`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/passes/simplify-locals-notee-nostructure.txt>
- `test/passes/simplify-locals.wast`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/passes/simplify-locals.wast>
- `test/passes/simplify-locals.txt`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/passes/simplify-locals.txt>

`version_129` copies of the same files were also downloaded into `.tmp/slns-v129-source/` for a focused drift check. The dedicated no-structure and nearby-variant test files are byte-identical between `version_129` and `version_130`. `SimplifyLocals.cpp` only changes the block-break and unoptimizable-block containers from ordered to unordered containers; that is performance/implementation detail, not a new transform family. The reviewed helper diffs are broader (`EffectAnalyzer`, `LinearExecutionWalker`, `Properties`, pass registration, `WorldMode`), but they do not change the public SLNS template identity or dedicated no-structure proof files. The helper changes are still relevant to the audit: call/throw precision and null-trap effect modeling should be rechecked in the effect/order invalidation family.

## Current Binaryen `version_130` contract checklist

| Family | Binaryen `version_130` source/test fact | Starshine status after this slice | Next audit action |
| --- | --- | --- | --- |
| Template identity | `createSimplifyLocalsNoStructurePass()` returns `SimplifyLocals<true, false>` i.e. teeing and nesting enabled, structure disabled. | Partially covered. Direct runner calls `simplify_locals_run_with_options(ctx, func, false, true)`. | Keep as checklist anchor. |
| Get counting | `LocalGetCounter` runs before main cycles and again before late optimizations. | Covered by existing sink/copy/dead tests, but no dedicated count stress profile yet. | Add pass-specific GenValid profile. |
| First-cycle single-use sinks | `firstCycle = true`; first cycle refuses multi-use tee creation and Binaryen schedules another cycle. | Existing straight-line single-use test covers basic shape. Later performance work adds an output-preserving Starshine-only fast path that skips the second main/dead-cleanup scan when the first no-change cycle has no deferred multi-use local.set work. | Keep first-cycle-vs-later-cycle fixtures covered by tee creation and keep the no-deferred fast-path perf invariant green. |
| Later-cycle teeing | `allowTee = true`; later cycles can sink multi-use locals by converting the original set into `local.tee`. Dedicated no-structure fixture demonstrates this. | Gap narrowed: straight-line/no-control functions no longer bail out merely because a pre-existing tee exists; structured-control plus tee still has `control-local-tee-hazard-noop`. Existing tests cover creating tees and preserving dependent-load tees. | Continue tee-family audit with multi-use first-read sinks, structured-control tee safety, and dropped-first-use cleanup. |
| `drop(local.tee)` cleanup | `visitDrop` converts dropped tee to `local.set`; final cleanup can then remove dead sets. Dedicated fixture `no-unreachable` reaches `unreachable`; this slice's probe reaches two `nop`s plus `i32.const 7`. | New focused test covers a root, single-use, unrelated existing dropped tee plus a sinkable local. | Add direct dropped-tee-only, nested dropped-tee, and unreachable/refinalization edge tests. |
| Overwritten pending set cleanup | A later pending set to the same local converts the previous set into `drop(oldValue)`. | Existing docs claim coverage, but not refreshed in this slice. | Focused Binaryen-vs-Starshine probe. |
| Effect/order invalidation | `checkInvalidations` uses `effects.orderedAfter(info.effects)`. `version_130` helper diffs refine effects for calls, null traps, and known nonthrowing call flow. | Partially covered by dependent loads, condition tee, and historical effect tests. | Re-audit calls, globals, memory/table, shared memory, traps, and helper diff impact. |
| `try` / `try_table` throwing barriers | `visitPre` drops sinkables whose values may throw before entering `try` / `try_table`. | Not refreshed in this slice. | Add/verify focused EH probes. |
| Unreachable/refinalization/nondefaultable fixups | Single-use replacement can set `refinalize`; late equivalent get can refinalize; Binaryen pass runner fixups remain in `pass.h`. | Existing no-unreachable and broad validation evidence are historical. | Recheck with GC/nondefaultable locals under v130. |
| Late equivalent-get cleanup | `EquivalentOptimizer` still runs for no-structure; `removeEquivalentSets = allowStructure`, so no-structure canonicalizes gets but does not remove equivalent sets in that phase. | Existing exact-slot set-copy tests cover some effects. | Add/refine focused tests for canonicalizing gets without structure deletion. |
| Final dead-set cleanup | `UnneededSetRemover` runs after late equivalent cleanup. | Covered by straight-line and new existing-tee test. | Include in dedicated profile. |
| Disabled structure synthesis | `allowStructure` gates block, `if`, and loop return-building helpers. Dedicated no-structure expected output keeps branch-created carriers. | Existing no-structure if-result negative covers this broadly. | Re-audit block/if/loop variants and document non-goal boundaries. |

## Existing-tee gap and fix

Before this slice, `src/passes/simplify_locals.mbt` made `simplify_locals_nostructure_run(...)` return unchanged for any function containing a live `LocalTee`. That was broader than Binaryen's contract: `simplify-locals-nostructure` is tee-enabled and must still optimize unrelated locals in a function containing existing tees. This slice narrows that over-broad bailout: straight-line/no-control existing-tee functions run, while structured-control plus existing tee still returns unchanged with trace reason `control-local-tee-hazard-noop` until the HOT safety issue is fixed precisely.

Binaryen probe:

```wat
(module
  (func (result i32) (local i32 i32)
    i32.const 1
    local.tee 0
    drop
    i32.const 7
    local.set 1
    local.get 1))
```

Command:

```sh
wasm-opt --all-features .tmp/slns-existing-tee.wat --simplify-locals-nostructure -S -o .tmp/slns-existing-tee.opt.wat
```

Observed Binaryen `version_130` output keeps only two `nop`s and `i32.const 7`; the existing dropped tee does not block the unrelated local sink.

Red-first Starshine test added:

- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure optimizes unrelated locals when an existing tee is present`

Failure before implementation: the whole function was unchanged and still contained `local.tee`, `local.set (Local 1)`, and `local.get (Local 1)`. Implementation removed the broad existing-tee bailout from `simplify_locals_nostructure_run(...)` only, added a root/single-use guard around dropped-tee cleanup, and retained a narrower `control-local-tee-hazard-noop` guard after direct HOT tuple-neighbor tests exposed invalid child references when structured control and existing tees mix. The no-tee sibling still has its existing tee bailout and remains an explicit follow-up.

## Commands and results

- `wasm-opt --version` — kickoff established `wasm-opt version 130 (version_130)`.
- `python3` source fetch into `.tmp/slns-v130-source/` — succeeded for all listed primary files.
- `diff -q` between `.tmp/slns-v129-source/` and `.tmp/slns-v130-source/` — dedicated SLNS/no-tee/full test files unchanged; `SimplifyLocals.cpp` only unordered container drift; helper changes noted above.
- `wasm-opt --all-features .tmp/slns-existing-tee.wat --simplify-locals-nostructure -S -o .tmp/slns-existing-tee.opt.wat` — Binaryen optimized through the existing dropped tee to `nop`, `nop`, `i32.const 7`.
- Red-first `moon test src/passes --filter "simplify-locals-nostructure optimizes unrelated locals when an existing tee is present"` — failed before implementation with unchanged local traffic.
- Same focused test after implementation — passed.
- `moon test src/passes/simplify_locals_nostructure_test.mbt` — `15/15` passed.
- `moon test src/passes` — `3664/3664` passed after preserving the narrower structured-control-plus-tee guard.
- `moon build --target native --release src/cmd` — passed with pre-existing warnings; actual binary path in this workspace is `_build/native/release/build/cmd/cmd.exe`, not `target/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 1000 ... --starshine-bin target/native/release/build/cmd/cmd.exe` — all 1000 cases failed as `starshine-command-failed` due stale binary path ENOENT; do not count as semantic evidence.
- `bun scripts/pass-fuzz-compare.ts --count 200 --seed 0x5eed --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-slice-genvalid-200 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` — `200/200` compared, `200` normalized matches, zero mismatches, validation failures, generator failures, property failures, or command failures; final rerun Binaryen cache hits/misses `200/0`.

## Remaining risks / reopening criteria

- The initial slice did not prove the full tee family. It only narrowed the over-broad pre-existing tee bailout for canonical SLNS and covered one Binaryen-positive straight-line/no-control existing-tee shape. The follow-up below further narrows root dropped-tee plus later-control and no-tee straight-line shapes, but embedded-control tees remain open.
- The initial no-tee/no-structure sibling existing-tee bailout was superseded by the follow-up below for the straight-line dropped-tee/unrelated-local shape. Reopen remaining no-tee work for multi-use, embedded-control, or artifact-sized hazards rather than the already-fixed broad straight-line bailout.
- `version_130` helper drift in `EffectAnalyzer` and `LinearExecutionWalker` may affect call/throw/null-trap invalidation surfaces. Reopen with focused tests around known nonthrowing calls, call_ref/call_indirect effects, EH, and null-ref traps.
- Dedicated pass-specific GenValid profile for SLNS is still missing.
- Pass-local performance has not been measured in this slice beyond the green bounded compare lane; final audit still must collect SLNS/Binaryen pass timings and pursue `starshine_time <= binaryen_time` where safe.

## Follow-up: structured root tee and no-tee sibling narrowing

A later 2026-06-30 slice continued the tee-family audit without changing the upstream `version_130` source inventory. Two more Binaryen-positive probes were checked:

```wat
(module
  (func (param i32) (result i32) (local i32 i32)
    i32.const 1
    local.tee 1
    drop
    local.get 0
    if
      nop
    end
    i32.const 7
    local.set 2
    local.get 2))
```

`wasm-opt --all-features .tmp/slns-structured-existing-tee.wat --simplify-locals-nostructure -S -o .tmp/slns-structured-existing-tee.opt.wat` produced a module that preserves the `if` boundary but removes the dropped root tee and sinks the unrelated local to `i32.const 7`. This proved the first narrowed Starshine guard was still too broad: structured control in the same function is not enough to block Binaryen's unrelated root dropped-tee cleanup.

`wasm-opt --all-features .tmp/slns-existing-tee.wat --simplify-locals-notee-nostructure -S -o .tmp/slns-existing-tee-notee.opt.wat` also removed the existing dropped tee and sunk the unrelated local. This proves `notee` disables creating new tees; it does not mean an already-present tee should block unrelated no-tee cleanup.

Red-first Starshine tests added:

- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure optimizes root existing tee with later control`
- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-notee-nostructure optimizes unrelated locals when an existing tee is present`

Both failed before implementation because the current Starshine runners returned the function unchanged. The implementation now scans once from the root region and only keeps `control-local-tee-hazard-noop` when a `local.tee` is embedded under a structured-control subtree, including control children and body/catch regions. Root dropped tees outside the control subtree no longer block canonical SLNS or the no-tee sibling. The no-tee sibling still runs with tee creation disabled.

The embedded-control guard remains an explicit HOT safety blocker, not a Binaryen parity claim. It is retained because the direct HOT tuple-neighbor fixtures still prove that a block containing `drop(local.tee(...))` can trigger invalid child refs without the guard. Reopen this boundary when HOT child ownership/deletion for nested dropped tees is repaired.

Additional validation from this follow-up:

- `moon test src/passes --filter "simplify-locals-nostructure optimizes root existing tee with later control"` — failed before implementation, passed after.
- `moon test src/passes --filter "simplify-locals-notee-nostructure optimizes unrelated locals when an existing tee is present"` — failed before implementation, passed after.
- `moon fmt` — passed/no work after final code changes.
- `moon test src/passes/simplify_locals_nostructure_test.mbt` — `17/17` passed.
- `moon test src/passes --filter "optimize-instructions tuple.extract localization survives simplify-locals-nostructure neighbor"` — passed.
- `moon test src/passes --filter "optimize-instructions earlier and later tuple.extract localization survives simplify-locals-nostructure neighbor"` — passed.
- `moon test src/passes` — `3666/3666` passed.
- `moon build --target native --release src/cmd` — passed with pre-existing unused-function warnings; native binary path remains `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 500 --seed 0x5eed --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-tee-guard2-genvalid-500 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` — `500/500` compared, `500` normalized matches, zero mismatches, validation failures, generator failures, property failures, or command failures; Binaryen cache hits/misses `500/0` on the final rerun.
- `bun scripts/self-optimize-compare.ts .tmp/slns-structured-existing-tee.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/slns-tee-guard2-timing-structured --timing-only --simplify-locals-nostructure` — canonical wasm equal; Starshine whole-command `1.588ms` vs Binaryen `2.553ms`; pass-local Starshine `0.078ms` vs Binaryen `0.053ms`. This tiny fixture misses the user-requested `starshine_time <= binaryen_time` pass-local target and must not be treated as final performance acceptance.

Remaining tee-family risks after the follow-up:

- `local.tee` embedded under `block`, `loop`, `if`, `try`, or `try_table` remains guarded by `control-local-tee-hazard-noop` until the HOT nested dropped-tee child-ownership problem is fixed.
- No-tee multi-use and structured-control cases still need separate probes; this slice only proved straight-line existing dropped-tee cleanup plus unrelated single-use sinking.
- The broader effect/order invalidation, EH barrier, refinalization, late equivalent-get cleanup, final dead-set cleanup, dedicated GenValid profile, and full performance target remain open.

## Follow-up: overwritten pending-set cleanup refresh

A later 2026-06-30 slice refreshed the overwritten pending-set cleanup family against the same Binaryen `version_130` oracle. The focused probe avoids Starshine's still-open root call/stack-effect hazard surface by using potentially trapping memory loads as the overwritten and overwriting values:

```wat
(module
  (memory 1)
  (func (result i32) (local i32)
    i32.const 0
    i32.load
    local.set 0
    i32.const 4
    i32.load
    local.set 0
    local.get 0))
```

Commands:

```sh
wasm-opt --all-features .tmp/slns-overwrite-load-load.wat --simplify-locals-nostructure -S -o .tmp/slns-overwrite-load-load.opt.wat
wasm-opt --all-features .tmp/slns-overwrite-load-load.wat --simplify-locals-notee-nostructure -S -o .tmp/slns-overwrite-load-load-notee.opt.wat
```

Both Binaryen variants produce the same behavior shape: the first overwritten pending set becomes `drop(i32.load (i32.const 0))`, preserving possible trap timing, the overwritten set itself is removed, and the later `i32.load (i32.const 4)` feeds the function result without a surviving `local.set` / `local.get` carrier.

Starshine already matched this straight-line load/trap-shaped family, so this slice added regression coverage rather than a code change:

- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure drops overwritten pending load set`
- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-notee-nostructure drops overwritten pending load set`

Focused validation after adding the tests:

- `moon test src/passes --filter "simplify-locals-nostructure drops overwritten pending load set"` — passed before implementation because the audited family was already implemented; retained as a coverage refresh, not a red-first gap fix.
- `moon test src/passes --filter "simplify-locals-notee-nostructure drops overwritten pending load set"` — passed.
- `moon fmt` — passed.
- `moon test src/passes/simplify_locals_nostructure_test.mbt` — `19/19` passed.
- `moon test src/passes` — `3668/3668` passed.
- `git diff --check` — passed.

Remaining boundary superseded in part by the follow-up below: Binaryen also converts the adjacent call-valued overwrite/final-use shape to `drop(call ...)` plus the final call result. Starshine now covers that narrow shape, but the broader root stack/local-set call hazard remains guarded when a stack-effecting later root reads the call-valued local before the next write.

## Follow-up: call-valued overwritten-set cleanup and root stack-effect guard reduction

A later 2026-06-30 slice moved from the load/trap-shaped overwritten-set refresh to the call-valued surface. Binaryen `version_130` probe:

```wat
(module
  (func $a (result i32) (i32.const 1))
  (func $b (result i32) (i32.const 2))
  (func (result i32) (local i32)
    (call $a)
    (local.set 0)
    (call $b)
    (local.set 0)
    (local.get 0)))
```

Commands:

```sh
wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-call-overwrite-audit/overwrite-call-call.wat -S -o .tmp/slns-call-overwrite-audit/overwrite-call-call.opt.wat
wasm-opt --all-features --simplify-locals-notee-nostructure .tmp/slns-call-overwrite-audit/overwrite-call-call.wat -S -o .tmp/slns-call-overwrite-audit/overwrite-call-call-notee.opt.wat
```

Both Binaryen variants emit `drop(call $a)`, `nop`, and `call $b`: the first call's side effect is preserved at the original position, the overwritten local write is erased, and the final call result feeds the function result without a surviving `local.set` / `local.get` carrier.

Red-first Starshine tests added:

- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure drops overwritten pending call set`
- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-notee-nostructure drops overwritten pending call set`

Both failed before implementation: the optimized function remained unchanged with both `local.set (Local 0)` and `local.get (Local 0)` carriers. The implementation makes two narrow changes. First, the root stack/local-set call hazard now detects the historical unsafe shape more precisely: a stack-effect-valued root local write is guarded when a later stack-effecting root reads that local before the next write, instead of skipping every function that merely has a call-valued local write. Second, immediate following root `local.get` consumers may be replaced by a non-inline-safe single-result value such as `call $b` when no live root exists between the set and the get. The existing hazard tests still pass, so the artifact guard remains for stack-effecting later reads.

Validation after implementation:

- Red-first focused call-overwrite tests failed before implementation and passed after.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*overwritten pending call set*'` — `2/2` passed.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*root stack/local-set call hazards*'` — `2/2` passed, preserving the historical guard where a later stack-effecting call reads the local.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — `31/31` passed.
- `moon fmt` — passed.
- `moon test src/passes` — `3680/3680` passed after fixing a temporary full-`simplify-locals` const-overwrite regression by keeping exact following-root replacement limited to non-inline-safe values.
- `moon info` — passed with pre-existing warnings.
- `moon test` — `7065/7065` passed.
- `moon build --target native --release src/cmd` — passed with pre-existing warnings; native binary path remains `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 30 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-effect-order --out-dir .tmp/pass-fuzz-slns-effect-order-smoke-30-after-call-overwrite --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures` — compared `30/30`, normalized `20`, mismatches `10`, zero validation/generator/property/command failures, Binaryen cache `30/0`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-smoke-100-after-call-overwrite --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures` — compared `100/100`, normalized `91`, mismatches `9`, zero validation/generator/property/command failures, selected-profile counts straight-line `49`, tee-control `22`, effect-order `29`, Binaryen cache `100/0`.

The dedicated-profile smoke counts did not change because the current residuals are the already-classified structured-control result-annotation-only family, not this adjacent call-overwrite shape. This slice closes only the adjacent call-valued overwritten-set/final-use family for canonical and no-tee SLNS. Reopen broader call hazards for `call_ref` / `call_indirect`, non-adjacent call-valued carriers with intervening effects, stack-effecting later reads that still trigger the guard, and artifact-sized root stack/local-set lowering hazards.

## Follow-up: try_table EH throwing-barrier refresh

A later 2026-06-30 slice refreshed the EH throwing-barrier family for `try_table` bodies against the same Binaryen `version_130` oracle. `SimplifyLocals.cpp::visitPre` invalidates pending sinkables whose values may throw before entering `try` / `try_table`, because moving such a value inside the EH body could make the handler catch an exception that was previously outside the handler. Nonthrowing values are not invalidated by that pre-visit rule.

Binaryen nonthrowing probe:

```wat
(module
  (tag $e (param i32))
  (func (result i32) (local i32)
    i32.const 7
    local.set 0
    (block $h (result i32)
      (try_table (result i32) (catch $e $h)
        local.get 0))))
```

Command:

```sh
wasm-opt --all-features .tmp/slns-try-table-nonthrowing-sink.wat --simplify-locals-nostructure -S -o .tmp/slns-try-table-nonthrowing-sink.opt.wat
```

Observed Binaryen output replaces the body `local.get 0` with `i32.const 7` and nops the preceding set.

Binaryen throwing probe:

```wat
(module
  (import "env" "maybe" (func $maybe (result i32)))
  (tag $e (param i32))
  (func (result i32) (local i32)
    call $maybe
    local.set 0
    (block $h (result i32)
      (try_table (result i32) (catch $e $h)
        local.get 0))))
```

Command:

```sh
wasm-opt --all-features .tmp/slns-try-table-throwing-barrier.wat --simplify-locals-nostructure -S -o .tmp/slns-try-table-throwing-barrier.opt.wat
```

Observed Binaryen output keeps `local.set 0 (call $maybe)` before the `try_table` and keeps the body `local.get 0`.

Starshine previously scanned `try_table` bodies with a fresh sinkable set, which was safe but missed the Binaryen-positive nonthrowing sink. The implementation now clears only pending sinkables with `EFFECT_MASK_THROW`, scans the `try_table` body with the surviving parent sinkables, clears them after the body, and still scans catch-list roots with a fresh sinkable set. Focused tests added:

- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure sinks nonthrowing set into try_table body`
- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure keeps throwing set before try_table body`

A legacy `try` WAT probe was attempted first and failed before implementation, but the focused test path currently lowers that legacy `try` syntax into block/loop shape before HOT `Try` coverage, so this slice does not claim plain `try` closure. Reopen plain `try` when a HOT-preserving fixture or binary fixture path is available.

Validation after the implementation:

- `wasm-opt --all-features .tmp/slns-try-table-nonthrowing-sink.wat --simplify-locals-nostructure -S -o .tmp/slns-try-table-nonthrowing-sink.opt.wat` — Binaryen sinks the pure const into the `try_table` body.
- `wasm-opt --all-features .tmp/slns-try-table-throwing-barrier.wat --simplify-locals-nostructure -S -o .tmp/slns-try-table-throwing-barrier.opt.wat` — Binaryen keeps the call-valued set before `try_table`.
- `moon test src/passes --filter "simplify-locals-nostructure sinks nonthrowing set into try body"` — failed before implementation, but this was the legacy-`try` lowering probe and is not retained as final coverage.
- `moon test src/passes --filter "simplify-locals-nostructure sinks nonthrowing set into try_table body"` — passed after implementation.
- `moon test src/passes --filter "simplify-locals-nostructure keeps throwing set before try_table body"` — passed.
- `moon fmt` — passed.
- `moon test src/passes/simplify_locals_nostructure_test.mbt` — `21/21` passed.
- `moon test src/passes` — `3670/3670` passed.
- `moon build --target native --release src/cmd` — passed with pre-existing warnings.
- `bun scripts/pass-fuzz-compare.ts --count 500 --seed 0x5eed --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-trytable-barrier-genvalid-500 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` — `500/500` compared, `500` normalized matches, zero mismatches, validation failures, generator failures, property failures, or command failures; Binaryen cache hits/misses `500/0`.

Remaining EH boundaries: plain `try` still needs a direct HOT-preserving focused fixture; catch-region/catch-list sinking remains intentionally fresh until separately audited; broader effect/order invalidation for calls, memory/table/global, shared memory, and null traps remains open.
## Follow-up: distinct-global effect/order invalidation refresh

A later 2026-06-30 slice refreshed part of the effect/order invalidation family against Binaryen `version_130`, focusing on global state exactness plus memory/table write barriers. Binaryen's `effects.orderedAfter(info.effects)` is precise enough to let a pending read of one global sink across a write to another global, while preserving same-global read-before-write order.

Binaryen probes were written under `.tmp/slns-effect-audit/` and optimized with `wasm-opt --all-features <input>.wat --simplify-locals-nostructure -S -o <input>.opt.wat`:

- `global-get-set.wat`: `global.get $g; local.set 0; global.set $h; local.get 0` optimizes to `nop; global.set $h; global.get $g`.
- `global-get-set-same.wat`: `global.get $g; local.set 0; global.set $g; local.get 0` keeps the `local.set` / `local.get` carrier.
- `load-load.wat`: dynamic read-only loads can commute; Binaryen drops the second load first and sinks the first load to the result.
- `load-store.wat` and `store-value-load.wat`: memory writes remain barriers for pending memory reads/writes.
- `table-get-set.wat`: a table write remains a barrier for a pending same-table `table.get`.

Starshine previously treated any global-state instruction as conflicting with any pending global-state value and therefore missed the distinct-global positive. Red-first focused test `simplify-locals-nostructure sinks global.get across unrelated global.set` failed before implementation because the local carrier remained. The same-global negative test was added alongside it and remained green after the fix. The implementation now records exact global reads/writes for pending local-set values and uses those facts in directional invalidation: a same-global read/write or write/read/write conflict still clears the sinkable, but unrelated global writes no longer clear a pending value that only reads a different global.

Focused coverage added:

- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure sinks global.get across unrelated global.set`
- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure keeps global.get before same-global set`

Validation after the implementation:

- `moon test src/passes/simplify_locals_nostructure_test.mbt --filter "simplify-locals-nostructure sinks global.get across unrelated global.set"` — failed before implementation, passed after.
- `moon test src/passes/simplify_locals_nostructure_test.mbt --filter "simplify-locals-nostructure keeps global.get before same-global set"` — passed.
- `moon test src/passes/simplify_locals_nostructure_test.mbt` — `23/23` passed.
- `moon test src/passes/simplify_locals_wbtest.mbt` — `4/4` passed after updating the white-box effect fixture for the new exact-global fields.
- `moon fmt` — passed.
- `moon test src/passes` — `3672/3672` passed.
- `moon info` — passed with pre-existing warnings.
- `moon build --target native --release src/cmd` — passed with pre-existing unused-function warnings.
- `bun scripts/pass-fuzz-compare.ts --count 500 --seed 0x5eed --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-global-effects-genvalid-500 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` — `500/500` compared, `500` normalized matches, zero mismatches, validation failures, generator failures, property failures, or command failures; Binaryen cache hits/misses `500/0`.

Remaining boundaries for this family after the distinct-global slice were table exactness beyond the same-table barrier probe, shared memories/atomics, calls/nonthrowing-call precision, null-trap ordering, and EH/catch-region effects. The later dynamic-load/table-barrier follow-up below supersedes the earlier note that dynamic read-only load commutation was not yet promoted into Starshine regression coverage.

## Follow-up: dynamic read-only loads and table-write barrier refresh

A later 2026-06-30 slice continued the effect/order invalidation audit against the same Binaryen `version_130` oracle. It promoted the earlier dynamic read-only-load observation into Starshine behavior coverage and checked whether table exactness has a distinct-table positive analogous to the distinct-global case.

Binaryen probes under `.tmp/slns-effect-audit/`:

- `load-load.wat`: `local.get 0; i32.load; local.set 2; local.get 1; i32.load; drop; local.get 2` optimizes to `nop; drop(i32.load (local.get 1)); i32.load (local.get 0)`. This confirms that Binaryen lets two dynamic read-only trapping loads commute for SLNS.
- `table-get-set-same.wat`: a pending `table.get $t0` remains local-carried across `table.set $t0`.
- `table-get-set-distinct.wat`: a pending `table.get $t0` also remains local-carried across `table.set $t1`. This means the current `version_130` behavior does **not** provide a different-table positive to implement; table writes remain a broad barrier for this family.

Starshine previously kept the read-only-load local carrier because `simplify_locals_value_can_move_one_use` refused to move `Load` values even after effect invalidation had proven no ordering conflict. Red-first focused test `simplify-locals-nostructure sinks dynamic read-only loads` failed with the original `local.set (Local 2)` / `local.get (Local 2)` carrier still present. The implementation now allows one-use `Load` values to move when the load has a single result and its address subtree reads only function parameters. This intentionally narrow guard covers the Binaryen-positive dynamic read-only-load probe without reopening the dependent-load tee hazard where load addresses read a body local written by an earlier `local.tee`.

During `moon test src/passes`, existing atomic coverage caught an over-broad first attempt: treating ordinary read-only loads as commutable must not let loads sink across `struct.atomic.get`. Starshine now models atomic read operations as memory read/write barriers for SLNS effect ordering, keeping the existing `simplify-locals does not sink loads across struct atomic gets` regression green. This is a conservative barrier, not a claim that the shared-memory/atomic Binaryen audit row is closed.

Focused coverage added:

- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure sinks dynamic read-only loads`
- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure keeps table.get before same table.set`
- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure keeps table.get before distinct table.set`

Validation after the implementation:

- `wasm-opt --all-features .tmp/slns-effect-audit/load-load.wat --simplify-locals-nostructure -S -o .tmp/slns-effect-audit/load-load.opt.wat` — Binaryen commutes the two dynamic read-only loads.
- `wasm-opt --all-features .tmp/slns-effect-audit/table-get-set-distinct.wat --simplify-locals-nostructure -S -o .tmp/slns-effect-audit/table-get-set-distinct.opt.wat` — Binaryen keeps the carrier across a distinct-table write.
- `wasm-opt --all-features .tmp/slns-effect-audit/table-get-set-same.wat --simplify-locals-nostructure -S -o .tmp/slns-effect-audit/table-get-set-same.opt.wat` — Binaryen keeps the carrier across a same-table write.
- `moon test src/passes/simplify_locals_nostructure_test.mbt --filter "simplify-locals-nostructure sinks dynamic read-only loads"` — failed before implementation, passed after.
- `moon test src/passes/simplify_locals_nostructure_test.mbt --filter "simplify-locals-nostructure keeps tee before dependent loads"` — passed after narrowing load movement to parameter-address loads.
- `moon test src/passes/atomic_pass_support_test.mbt --filter "simplify-locals does not sink loads across struct atomic gets"` — failed during the first implementation attempt, passed after atomic reads were restored as barriers.
- `moon test src/passes/simplify_locals_nostructure_test.mbt` — `26/26` passed.
- `moon test src/passes/simplify_locals_wbtest.mbt` — `4/4` passed.
- `moon test src/passes` — `3675/3675` passed.
- `moon build --target native --release src/cmd` — passed with pre-existing unused-function warnings.
- `bun scripts/pass-fuzz-compare.ts --count 500 --seed 0x5eed --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-load-table-effects-genvalid-500 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` — `500/500` compared, `500` normalized matches, zero mismatches, validation failures, generator failures, property failures, or command failures; Binaryen cache hits/misses `500/0`.

Remaining effect/order boundaries after this slice: table writes are now documented as broad Binaryen barriers rather than an exact-table positive; shared memory/atomics still need a source/probe audit beyond the preserved Starshine barrier; calls/nonthrowing-call precision, null-trap ordering, catch-region/catch-list effects, and other helper-diff surfaces remain open.

## Follow-up: direct-call barrier and null-trap ordering refresh

A later 2026-06-30 slice continued the effect/order invalidation audit against the same Binaryen `version_130` oracle, focusing on two helper-diff surfaces left open by the source refresh: calls/nonthrowing-call precision and null-trap ordering.

Binaryen probes under `.tmp/slns-call-audit/`:

- `call-pure-const.wat`: even a pending `i32.const 7` carrier remains before a direct call to a locally-defined no-arg/no-side-effect callee. Binaryen keeps `local.set` / `local.get` around the call rather than treating the local direct call as a nonthrowing transparent window for SLNS.
- `call-import-const.wat`: an imported call is likewise a barrier for the const carrier.
- `call-pure-load.wat`: a pending dynamic read-only load remains before the direct call. This is consistent with calls remaining barriers even after the prior read-only-load/read-only-load commutation slice.

Binaryen probe under `.tmp/slns-null-audit/`:

- `ref-as-non-null-load-nullable-local.wat`: a pending `ref.as_non_null(local.get 0)` stored in a defaultable `externref` local can sink across a dropped dynamic read-only load and then feed the final result. The optimized shape is `nop; drop(i32.load(local.get 1)); ref.as_non_null(ref.as_non_null(local.get 0))` with no surviving carrier local.

Starshine already matched both refreshed behaviors, so this slice added focused coverage rather than a code change:

- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure keeps local before direct call barrier`
- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure sinks ref.as_non_null across read-only load`

Validation for this slice:

- `wasm-opt --all-features .tmp/slns-call-audit/call-pure-const.wat --simplify-locals-nostructure -S -o .tmp/slns-call-audit/call-pure-const.opt.wat` — Binaryen keeps the const carrier across the direct call.
- `wasm-opt --all-features .tmp/slns-call-audit/call-import-const.wat --simplify-locals-nostructure -S -o .tmp/slns-call-audit/call-import-const.opt.wat` — Binaryen keeps the const carrier across the imported call.
- `wasm-opt --all-features .tmp/slns-call-audit/call-pure-load.wat --simplify-locals-nostructure -S -o .tmp/slns-call-audit/call-pure-load.opt.wat` — Binaryen keeps the load carrier across the direct call.
- `wasm-opt --all-features .tmp/slns-null-audit/ref-as-non-null-load-nullable-local.wat --simplify-locals-nostructure -S -o .tmp/slns-null-audit/ref-as-non-null-load-nullable-local.opt.wat` — Binaryen sinks the `ref.as_non_null` carrier across the dropped read-only load.
- `moon test src/passes/simplify_locals_nostructure_test.mbt --filter "simplify-locals-nostructure keeps local before direct call barrier"` — passed; this was a green coverage refresh, not a red-first gap fix.
- `moon test src/passes/simplify_locals_nostructure_test.mbt --filter "simplify-locals-nostructure sinks ref.as_non_null across read-only load"` — passed; this was a green coverage refresh, not a red-first gap fix.
- `moon fmt` — passed.
- `moon test src/passes/simplify_locals_nostructure_test.mbt` — `28/28` passed.
- `moon test src/passes` — `3677/3677` passed.

Remaining boundaries after this slice: call-valued overwritten-set cleanup remains blocked by the broader root stack/local-set call hazard; calls still need broader `call_ref` / `call_indirect` / tail-call / side-effect classification if a future Binaryen-positive window is found; nondefaultable local/refinalization fixups remain open because a direct nondefaultable-local `ref.as_non_null` probe exposes Starshine validation/tooling limitations rather than a safe SLNS behavior claim; shared-memory/atomic source audit, plain `try`, catch-region effects, embedded-control tee safety, dedicated GenValid profile, full closeout lanes, and strict pass-local performance remain open.

## Follow-up: dedicated GenValid aggregate profile

A later 2026-06-30 slice added the pass-owned GenValid aggregate profile required for SLNS closeout:

- `simplify-locals-nostructure-straight-line`: straight-line single-use local sinking and root dropped-tee cleanup without effectful barriers.
- `simplify-locals-nostructure-tee-control`: root dropped tee plus unrelated structured control, and a no-structure barrier shape that should not synthesize result-producing control.
- `simplify-locals-nostructure-effect-order`: read-only load movement and overwritten-load local traffic under an effect-capable module envelope with globals, tables, memory, calls, call_ref/call_indirect, and EH-capable context.
- `simplify-locals-nostructure-all`: deterministic weighted aggregate; aliases `simplify-locals-nostructure`, `simplify-locals-nostructure-closeout`, `simplify-locals-nostructure-all-profiles`, `slns`, and `slns-closeout` resolve to it.

Implementation and tests:

- `src/validate/gen_valid.mbt` wires the profile constructors, names, aliases, aggregate weights, and configs.
- `src/validate/gen_valid_ssa.mbt` adds SLNS-specific local-traffic body slices. These reuse the existing local-traffic generator gate and `has_ssa_*` feature facts as generator plumbing; they are not a semantic claim that SLNS is the SSA no-merge pass.
- `src/validate/gen_valid_tests.mbt` proves profile resolution, aggregate membership, feature toggles, and emitted local-traffic opportunities.
- `src/fuzz/main_wbtest.mbt` proves aggregate manifests retain `config_label: "simplify-locals-nostructure-all"` and deterministic `selected_profile` metadata.
- `docs/wiki/binaryen/passes/simplify-locals-nostructure/fuzzing.md` documents the aggregate, leaves, closeout command, smoke result, exclusions, and reopening criteria.

Red-first result: the focused validate test initially failed to compile because the `SimplifyLocalsNostructure*Profile` constructors did not exist. After implementation, the focused validate and fuzz manifest tests passed.

Smoke compare command:

```sh
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-smoke-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Smoke result: compared `100/100`, normalized `71`, mismatches `29`, validation failures `0`, generator failures `0`, command failures `0`; selected profile counts were straight-line `49`, tee-control `22`, effect-order `29`.

Classification: this profile addition is not a parity closure. The 29 residuals are active audit inputs concentrated in the effect-order leaf. Representative `case-000004` shows Binaryen sinking/removing local carriers around read-only loads before global/table/call barriers while Starshine preserves the carriers. Treat these as effect/order precision follow-ups rather than accepted drift. The straight-line leaf intentionally avoids pure overwritten/dead const-set debris because Binaryen preserves those carriers as dropped constants while Starshine may erase the pure carrier outright; keep that family in focused tests until it has explicit classification or normalization.

## Follow-up: dedicated-profile residual classification

A later 2026-06-30 slice triaged the first residuals from the new `simplify-locals-nostructure-all` GenValid aggregate instead of accepting them as broad effect/order drift. The initial smoke remains:

```sh
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-smoke-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `100/100`, normalized `71`, mismatches `29`, validation/generator/command failures `0`; selected profiles were straight-line `49`, tee-control `22`, effect-order `29`.

This slice replayed all 29 residual inputs through Starshine with `--tracing pass` and classified every mismatch as the same raw/lowered guard family:

```sh
_build/native/release/build/cmd/cmd.exe <failure>/input.wasm --simplify-locals-nostructure -o .tmp/trace.tmp.wasm --tracing pass
```

All 29 cases selected `simplify-locals-nostructure-effect-order` and every affected function emitted `pass[simplify-locals-nostructure]:skip-raw reason=root-local-set-stack-hazard-noop`. The stored classifier output is `.tmp/slns-smoke-100-failure-trace-classification.txt`.

Additional leaf smokes narrowed the profile health:

```sh
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-straight-line --out-dir .tmp/pass-fuzz-slns-straight-line-smoke-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-tee-control --out-dir .tmp/pass-fuzz-slns-tee-control-smoke-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 30 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-effect-order --out-dir .tmp/pass-fuzz-slns-effect-order-smoke-30 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 30 --keep-going-after-command-failures
```

Results:

- `.tmp/pass-fuzz-slns-straight-line-smoke-100`: compared `100/100`, normalized `100`, mismatches/failures `0`, Binaryen cache `51/49` hits/misses.
- `.tmp/pass-fuzz-slns-tee-control-smoke-100`: compared `100/100`, normalized `100`, mismatches/failures `0`, Binaryen cache `25/75` hits/misses.
- `.tmp/pass-fuzz-slns-effect-order-smoke-30`: compared `30/30`, normalized `0`, mismatches `30`, validation/generator/command failures `0`, Binaryen cache `5/25` hits/misses; a trace replay classified all 30 as `skip-raw reason=root-local-set-stack-hazard-noop`.

Agent classification: this is a Starshine parity gap / safety blocker, not an accepted representation drift. Binaryen optimizes local carriers in these generated call/table/effect envelopes; Starshine's raw/lowered path returns the original function before HOT because the functions combine root local writes with stack-effecting calls/call_ref/call_indirect and enough structured/instruction shape to trigger the artifact-safety guard. The next implementation target is to reduce the raw/lowered `root-local-set-stack-hazard-noop` guard precisely enough to run safe prefix/local cleanup around call barriers, or to split the dedicated profile into a call-free signoff leaf plus an explicit call-guard audit leaf. Do not hide the call/call_ref/call_indirect surface: it remains open until Binaryen-positive generated and focused cases can run without the broad raw skip or are narrowed into an evidence-backed boundary with reopening criteria.

## Follow-up: root stack/local-set guard reduction for pure pre-call traffic

A later 2026-06-30 slice reduced the generated effect-order profile blocker without removing the historical json-as safety guard wholesale. The old initial raw/HOT boundary skipped any no-structure function that had both a root local write and a root stack-effecting call/call_ref/call_indirect/memory-copy/fill. That was too broad for Binaryen `version_130`: Binaryen still removes or sinks pure local carriers before later root calls when the local write itself is not call-valued.

Red-first Starshine coverage added:

- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure optimizes pure local traffic before root calls`

The test failed before implementation because the function stayed unchanged and retained `local.set (Local 1)` / `local.get (Local 1)` under `root-local-set-stack-hazard-noop`. The fix narrows the initial raw and HOT no-structure skip to stack-effect-valued local writes: raw detection now looks for a stack-effecting instruction whose value is immediately written to a local, and HOT detection now requires a root `LocalSet` / `LocalTee` subtree containing a stack-effecting operation. The broader lowered-cleanup guard in `pass_manager.mbt` intentionally remains unchanged so `pass_manager_wbtest.mbt::simplify-locals-nostructure lowered cleanup skips stack-root call hazards` continues to protect the historical json-as stack-root `local.tee` / call artifact.

Validation and profile evidence after the fix:

- Red-first focused test before implementation — failed with unchanged local traffic.
- `moon fmt` — passed.
- `moon test src/passes/simplify_locals_nostructure_test.mbt` — `29/29` passed.
- `moon test src/passes` — `3678/3678` passed.
- `moon build --target native --release src/cmd` — passed with pre-existing unused-function warnings; native binary path remains `_build/native/release/build/cmd/cmd.exe`.
- `moon test` — `7063/7063` passed with pre-existing warnings.
- `moon info` — passed with pre-existing warnings.
- `bun scripts/pass-fuzz-compare.ts --count 30 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-effect-order --out-dir .tmp/pass-fuzz-slns-effect-order-smoke-30-after-narrow-stack-guard --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 30 --keep-going-after-command-failures` — compared `30/30`, normalized `20`, mismatches `10`, validation/generator/command failures `0`, Binaryen cache hits/misses `30/0`.
- Trace classifier over those 10 residuals wrote `.tmp/slns-effect-order-smoke-30-after-narrow-stack-guard-classification.txt`; none reported `skip-raw` or `skip-hot` reasons.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-smoke-100-after-narrow-stack-guard --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures` — compared `100/100`, normalized `91`, mismatches `9`, validation/generator/command failures `0`, selected profiles straight-line `49`, tee-control `22`, effect-order `29`, Binaryen cache hits/misses `100/0`.

Agent classification after this guard-reduction slice: the root-local-set stack-effect blocker is reduced, not closed. The old profile residual family no longer hides the whole effect-order leaf behind the skip guard. The next follow-up below classifies the current smoke residuals as result-type/refinalization output drift rather than effect-order scheduling mismatches; continue with embedded-control tee safety, call-valued overwritten cleanup, plain `try`, broader EH/catch effects, nondefaultable/refinalization beyond annotation-only drift, and call_ref/call_indirect precision before final closeout.

## Follow-up: effect-order residual result-type classification

A follow-up 2026-06-30 slice classified the 10 residuals from `.tmp/pass-fuzz-slns-effect-order-smoke-30-after-narrow-stack-guard/failures/*` and the 9 residuals from `.tmp/pass-fuzz-slns-genvalid-all-smoke-100-after-narrow-stack-guard/failures/*`.

Method:

- Replayed the existing residual artifacts rather than generating new inputs.
- Compared `binaryen.wat` and `starshine.wat` after erasing only structured-control `(result ...)` annotations.
- Validated every `binaryen.wasm` and `starshine.wasm` residual artifact with `wasm-tools validate --features all`.
- Wrote `.tmp/slns-effect-order-smoke-30-after-narrow-stack-guard-result-type-classification.txt` and `.tmp/slns-genvalid-all-smoke-100-after-narrow-stack-guard-result-type-classification.txt`.

Result: all 10 effect-order leaf residuals and all 9 aggregate residuals report `same_after_erasing_result_annotations=True`; the aggregate residuals all selected `simplify-locals-nostructure-effect-order`. The separate validation loop accepted both tools' optimized wasm outputs for every residual.

Agent classification: these current smoke residuals are behavior-parity matches despite output/refinalization drift. The observed differences are only control result type spellings such as Binaryen using `nullref` / exact function references where Starshine uses `i31ref`, `anyref`, `structref`, or `funcref`; after removing those annotations, instruction order and local traffic are identical. This does not close the broad nondefaultable/refinalization family: reopen if a residual has instruction-order or local-traffic drift after erasing result annotations, either output fails validation, runtime replay disagrees, a nondefaultable-local case hits the known Starshine tooling limitation, or larger dedicated lanes produce a different residual family.

## Follow-up: direct-HOT legacy `try` throwing-barrier coverage

A later 2026-06-30 slice closed the plain legacy-`try` fixture blocker enough to cover Starshine's `HotOp::Try` implementation directly. The public WAT path still desugars legacy `try` before HOT, so this is direct-HOT white-box coverage rather than public-pipeline coverage.

Binaryen nonthrowing legacy-`try` probe:

```wat
(module
  (tag $e)
  (func (result i32) (local i32)
    i32.const 7
    local.set 0
    (try (result i32)
      (do
        local.get 0)
      (catch $e
        i32.const 9))))
```

Command:

```sh
wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-legacy-try-audit/nonthrowing.wat -S -o .tmp/slns-legacy-try-audit/nonthrowing.opt.wat
```

Binaryen `version_130` emits `nop` before the `try` and places `i32.const 7` in the `do` body, matching the source contract that nonthrowing pending values may sink into EH bodies.

Binaryen throwing legacy-`try` probe:

```wat
(module
  (import "env" "maybe" (func $maybe (result i32)))
  (tag $e)
  (func (result i32) (local i32)
    call $maybe
    local.set 0
    (try (result i32)
      (do
        local.get 0)
      (catch $e
        i32.const 9))))
```

Command:

```sh
wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-legacy-try-audit/throwing.wat -S -o .tmp/slns-legacy-try-audit/throwing.opt.wat
```

Binaryen keeps `local.set(call $maybe)` before the `try` and leaves the body `local.get`, because moving the call into the protected body could make the catch handle an exception that was outside the handler before the pass.

Starshine coverage added:

- `src/passes/simplify_locals_wbtest.mbt::simplify-locals-nostructure sinks nonthrowing set into legacy try body`
- `src/passes/simplify_locals_wbtest.mbt::simplify-locals-nostructure keeps throwing set before legacy try body`

Both tests construct `HotOp::Try` directly, run `simplify-locals-nostructure` through `hot_pass_run`, and inspect HOT output before lowering. The nonthrowing case verifies the root `local.set` becomes `nop` and the `try` body `local.get` becomes a `Const`. The throwing case verifies the root `LocalSet` and body `LocalGet` remain. This was a green coverage refresh of an already-implemented `HotOp::Try` path, not a red-first behavior fix.

Validation for this slice:

- `wasm-opt --version` — `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-legacy-try-audit/nonthrowing.wat -S -o .tmp/slns-legacy-try-audit/nonthrowing.opt.wat` — Binaryen sinks the pure value into the legacy `try` body.
- `wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-legacy-try-audit/throwing.wat -S -o .tmp/slns-legacy-try-audit/throwing.opt.wat` — Binaryen keeps the throwing call-valued set before the legacy `try` body.
- `moon test --target native src/passes/simplify_locals_wbtest.mbt --filter '*legacy try*'` — `2/2` passed with pre-existing warnings.
- `moon test --target native src/passes/simplify_locals_wbtest.mbt` — `6/6` passed.

Remaining EH boundaries after this slice: the public WAT path still cannot demonstrate legacy `try` directly because it desugars before HOT; catch-region and catch-list sinking/invalidation remain unaudited; `try_table` and direct-HOT legacy `try` body barriers are covered only for the focused pure-const and call-valued shapes above.

## Follow-up: late equivalent gets and no-structure block/loop/if breadth

A later 2026-06-30 slice audited two lower-risk checklist rows: late equivalent-get cleanup and disabled structure synthesis. It found one concrete Binaryen-positive gap in Starshine's root sinkable propagation across plain fallthrough blocks, and refreshed direct tests for equivalent-get cleanup plus loop/if/branch-created non-synthesis boundaries.

Late equivalent-get Binaryen probe:

```wat
(module
  (memory 1)
  (func (param i32) (result f32) (local i32)
    local.get 0
    local.set 1
    local.get 1
    i32.const 1
    i32.store
    local.get 1
    f32.load))
```

Command:

```sh
wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-equivalent-audit/equiv-store-load.wat -S -o .tmp/slns-equivalent-audit/equiv-store-load.opt.wat
```

Binaryen `version_130` emits a `nop`, changes both `local.get 1` uses to `local.get 0`, and leaves no `local.set 1` / `local.get 1` carrier. Starshine already matched this shape; `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure canonicalizes late equivalent gets` is a green coverage refresh, not a red-first gap fix.

Disabled-structure Binaryen probes under `.tmp/slns-structure-audit/` established four focused boundaries:

- `block-tail-set.wat`: a plain void fallthrough `block` with no branches is not a structure-synthesis case. Binaryen sinks the local after the block, leaves the block void, and returns `i32.const 7`.
- `loop-tail-set.wat`: Binaryen keeps the `local.set` inside the loop and the later `local.get`; it does not synthesize a loop result.
- `one-armed-if-tail-set.wat`: Binaryen keeps the one-armed `if` void with `local.set` in the arm and a later `local.get`; it does not synthesize an if result or invent a default carrier.
- `block-br-tail-set.wat`: Binaryen keeps the branch-created carrier inside a void block with `br $b` and the later `local.get`; it does not synthesize a block result across the branch.

Red-first Starshine coverage:

- `simplify-locals-nostructure sinks across fallthrough block without block result` initially failed: Starshine left `(block (Void) (i32.const 7) (local.set 0)) (local.get 0)` unchanged, while Binaryen sinks the value through the branch-free block boundary.
- The implementation now lets sinkable local traffic produced inside void branch-free blocks remain pending after the block. It still clears sinkables for loops, ifs, EH regions, typed blocks, or any block body containing a branch, so the branch-created and result-synthesis boundaries remain protected.

Additional Starshine coverage added:

- `simplify-locals-nostructure does not synthesize loop results`
- `simplify-locals-nostructure does not synthesize one-armed if results`
- `simplify-locals-nostructure does not synthesize branch-created block results`

Those tests were green against the existing implementation and lock the refreshed Binaryen-stationary boundaries.

Validation for this slice:

- `wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-equivalent-audit/equiv-store-load.wat -S -o .tmp/slns-equivalent-audit/equiv-store-load.opt.wat` — Binaryen rewrites copied-local uses to the original local and removes the copy set.
- `wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-structure-audit/{block-tail-set,loop-tail-set,one-armed-if-tail-set,block-br-tail-set}.wat -S -o ...` — Binaryen sinks only the branch-free fallthrough block carrier and leaves loop, one-armed-if, and branch-created block carriers as void control plus local traffic.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*fallthrough*'` — failed before implementation, passed after.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*equivalent*'` — passed `1/1`.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*synthesize*'` — passed `4/4`.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — passed `36/36`.
- `moon fmt` — passed.
- `moon test src/passes` — passed `3687/3687`.
- `moon build --target native --release src/cmd` — passed with pre-existing warnings; native binary path remains `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-smoke-100-after-block-fallthrough --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` — compared `100/100`, normalized `91`, mismatches `9`, validation/generator/property/command failures `0`, Binaryen cache `100/0`, selected profiles straight-line `49`, tee-control `22`, effect-order `29`. The residual failure IDs are the same already-classified annotation-only set (`case-000041`, `000043`, `000060`, `000069`, `000070`, `000082`, `000084`, `000092`, `000094`); do not treat this rerun as a new broad refinalization closure.

Remaining boundaries after this slice: branch-bearing block sink precision remains intentionally conservative; loops, one-armed ifs, branch-created carriers, and structured result synthesis stay open for broader scaled fuzzing even though the focused Binaryen probes now have coverage. Late equivalent cleanup is covered for the direct copy/store/load shape but still needs GC/nondefaultable/refinalization breadth and scaled profile signoff.

## Follow-up: first-cycle vs later-cycle teeing refresh

A later 2026-06-30 slice refreshed the first-cycle/later-cycle teeing checklist rows against the same Binaryen `version_130` oracle. The goal was to prove the canonical no-structure pass still follows Binaryen's two-cycle contract: the first cycle refuses multi-use tee creation, then the forced later cycle may sink the multi-use carrier through a fresh `local.tee`. This was a coverage refresh; Starshine already matched the focused shapes.

Binaryen canonical multi-use probe:

```wat
(module
  (func (result i32) (local i32)
    i32.const 7
    local.set 0
    local.get 0
    local.get 0
    i32.add))
```

Commands:

```sh
wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-tee-cycle-audit/multi-use-tee.wat -S -o .tmp/slns-tee-cycle-audit/multi-use-tee.opt.wat
wasm-opt --all-features --simplify-locals-notee-nostructure .tmp/slns-tee-cycle-audit/multi-use-tee.wat -S -o .tmp/slns-tee-cycle-audit/multi-use-tee-notee.opt.wat
```

Observed Binaryen output for canonical SLNS nops the original set and rewrites the first add operand to `local.tee $0 (i32.const 7)`, with the second operand as `local.get $0`. The no-tee sibling keeps `local.set $0 (i32.const 7)` plus two `local.get $0` operands, proving that `notee` disables fresh tee creation while the canonical pass remains tee-enabled.

A second focused probe checked the dropped-first-use case:

```wat
(module
  (func (result i32) (local i32)
    i32.const 7
    local.set 0
    local.get 0
    drop
    local.get 0))
```

Command:

```sh
wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-tee-cycle-audit/first-use-drop-second-use.wat -S -o .tmp/slns-tee-cycle-audit/first-use-drop-second-use.opt.wat
```

Binaryen emits only nops plus the final `i32.const 7` carrier, with no `local.tee`. This covers the first-cycle/dropped-use cleanup boundary separately from the multi-use tee positive.

Starshine focused coverage added:

- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure creates tees for later-cycle multi-use locals`
- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure avoids tees when the first use is dropped`

The existing `simplify-locals-notee-nostructure does not create tees for multi-use locals` test now has a refreshed Binaryen oracle probe. These tests passed on the current implementation, so this slice is green coverage refresh rather than a red-first behavior fix.

Validation for this slice:

- `wasm-opt --version` — `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-tee-cycle-audit/multi-use-tee.wat -S -o .tmp/slns-tee-cycle-audit/multi-use-tee.opt.wat` — Binaryen creates a fresh tee for canonical SLNS.
- `wasm-opt --all-features --simplify-locals-notee-nostructure .tmp/slns-tee-cycle-audit/multi-use-tee.wat -S -o .tmp/slns-tee-cycle-audit/multi-use-tee-notee.opt.wat` — Binaryen no-tee keeps the local carrier and creates no tee.
- `wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-tee-cycle-audit/first-use-drop-second-use.wat -S -o .tmp/slns-tee-cycle-audit/first-use-drop-second-use.opt.wat` — Binaryen avoids tee creation and leaves only the final constant carrier.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*tee*'` — passed `14/14`.
- `moon fmt` — passed.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — passed `38/38`.
- `moon test src/passes` — passed `3689/3689`.

Remaining tee-family boundaries after this slice: embedded-control `local.tee` remains guarded by `control-local-tee-hazard-noop` until the HOT child-ownership / invalid-child-ref blocker is reduced; structured-control no-tee sibling boundaries and large-module artifact hazards remain open; scaled dedicated lanes still need to prove the straight-line tee profile beyond focused fixtures.

## Follow-up: final dead-set cleanup breadth

A later 2026-06-30 slice refreshed the final dead-set cleanup family against the same Binaryen `version_130` oracle. Focused probes under `.tmp/slns-dead-set-audit/` covered zero-read pure sets, trapping load-valued sets, call-valued sets, and copy chains where late equivalent-get cleanup can make a set dead.

Binaryen observations:

- `pure-dead-set.wat`: both `--simplify-locals-nostructure` and `--simplify-locals-notee-nostructure` erase the zero-read `local.set` and leave only inert `nop` debris.
- `load-dead-set.wat`: both variants remove the dead local carrier but preserve the possible trap as `drop(i32.load (i32.const 0))`.
- `call-dead-set.wat`: both variants remove the dead local carrier but preserve the call side effect as `drop(call $side)`.
- `copy-dead-after-use.wat`: canonical SLNS rewrites the surviving copied-local use back to the source param and final dead-set cleanup removes both copy carriers. Binaryen no-tee removes the zero-read copy to the second local but leaves the first pure copy carrier; Starshine currently does the stronger no-tee cleanup by canonicalizing the effect-free copy chain back to the source param without creating a tee or synthesizing structure. This is recorded as a narrow Starshine win for the no-tee sibling, with reopening criteria if a future case involves effects, traps, nondefaultable/refined refs, or any tee/structure synthesis.

Focused Starshine coverage added in `src/passes/simplify_locals_nostructure_test.mbt`:

- `simplify-locals-nostructure removes pure zero-read sets`
- `simplify-locals-notee-nostructure removes pure zero-read sets`
- `simplify-locals-nostructure drops trapping zero-read sets`
- `simplify-locals-notee-nostructure drops trapping zero-read sets`
- `simplify-locals-nostructure drops call-valued zero-read sets`
- `simplify-locals-notee-nostructure drops call-valued zero-read sets`
- `simplify-locals-nostructure removes dead copy after equivalent-get cleanup`
- `simplify-locals-notee-nostructure removes dead copy without creating tees`

These were coverage-refresh tests rather than red-first implementation fixes. The no-tee copy-chain test intentionally locks the Starshine-win shape instead of Binaryen's local-carrier spelling: the fixture demonstrates fewer local operations while preserving the same pure param value and still asserting no `local.tee` is introduced.

Validation after adding the tests:

- `wasm-opt --version` — `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-dead-set-audit/{pure-dead-set,load-dead-set,call-dead-set,copy-dead-after-use}.wat -S ...` — produced the canonical outputs summarized above.
- `wasm-opt --all-features --simplify-locals-notee-nostructure .tmp/slns-dead-set-audit/{pure-dead-set,load-dead-set,call-dead-set,copy-dead-after-use}.wat -S ...` — produced the no-tee outputs summarized above.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*zero-read*'` — passed `6/6`.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*dead copy*'` — initially exposed the no-tee Starshine-vs-Binaryen output-shape difference, then passed `2/2` after the test documented and asserted the narrower Starshine-win cleanup.
- `moon fmt` — passed.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — passed `46/46`.
- `moon test src/passes` — passed `3697/3697`.
- `git diff --check` — passed.

Remaining final-dead-set work: scaled dedicated-profile lanes still need to prove the focused family beyond these probes; GC/nondefaultable/refinalization interactions remain open; no-tee equivalent-copy cleanup should be reopened if the stronger Starshine cleanup touches effectful/trapping operands, nondefaultable locals, refined refs, embedded control, or tee/structure synthesis.

## Follow-up: EH catch-region and catch-list boundaries

A later 2026-06-30 slice audited the remaining EH catch-region/catch-list surface. Binaryen `version_130` legacy-`try` probes under `.tmp/slns-eh-catch-audit/` show catch bodies are scanned as fresh local-sinking regions rather than inheriting pre-`try` pending sinkables.

Binaryen catch-parent boundary probe:

```wat
(module
  (tag $e)
  (func (result i32) (local i32)
    i32.const 7
    local.set 0
    (try (result i32)
      (do
        throw $e
        i32.const 0)
      (catch $e
        local.get 0))))
```

Command:

```sh
wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-eh-catch-audit/legacy-catch-nonthrowing.wat -S -o .tmp/slns-eh-catch-audit/legacy-catch-nonthrowing.opt.wat
```

Binaryen keeps `local.set $0 (i32.const 7)` before the `try` and keeps the catch `local.get $0`. It does not sink the pre-`try` const into the catch body.

Binaryen throwing-parent boundary probe:

```wat
(module
  (import "env" "maybe" (func $maybe (result i32)))
  (tag $e)
  (func (result i32) (local i32)
    call $maybe
    local.set 0
    (try (result i32)
      (do
        throw $e
        i32.const 0)
      (catch $e
        local.get 0))))
```

Command:

```sh
wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-eh-catch-audit/legacy-catch-throwing.wat -S -o .tmp/slns-eh-catch-audit/legacy-catch-throwing.opt.wat
```

Binaryen likewise keeps the call-valued parent carrier before the `try` and leaves the catch `local.get`.

Binaryen catch-inner positive probe:

```wat
(module
  (tag $e)
  (func (result i32) (local i32)
    (try (result i32)
      (do
        throw $e
        i32.const 0)
      (catch $e
        i32.const 7
        local.set 0
        local.get 0))))
```

Command:

```sh
wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-eh-catch-audit/legacy-catch-inner-local.wat -S -o .tmp/slns-eh-catch-audit/legacy-catch-inner-local.opt.wat
```

Binaryen nops the catch-local set and replaces the catch `local.get` with `i32.const 7`, proving catch bodies are fresh but still optimized.

Red-first Starshine direct-HOT tests exposed a related implementation gap in the immediate following-root local-get inliner: it could look through a following `HotOp::Try` / `HotOp::TryTable` and replace the first `local.get` found in the catch/catch-list child, then remove the parent local.set. That does not match Binaryen's catch boundary and is risky for exceptional-control semantics. The fix makes both following-root child inliners skip child slot `1` for `Try` and `TryTable` nodes, preserving body behavior while keeping catch/catch-list regions fresh.

Starshine coverage added in `src/passes/simplify_locals_wbtest.mbt`:

- `simplify-locals-nostructure keeps parent set out of legacy try catch`
- `simplify-locals-nostructure optimizes local traffic inside legacy try catch`
- `simplify-locals-nostructure keeps parent set out of try_table catch list`
- `simplify-locals-nostructure optimizes local traffic inside try_table catch list`

The `try_table` catch-list tests are direct-HOT representation coverage: public Wasm `try_table` catch clauses are immediates targeting labels, not inline user catch bodies. Starshine still has a HOT catch-list region for exceptional CFG handling, so the slice locks the same fresh-region invariant there.

Validation after implementation:

- `wasm-opt --version` — `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-eh-catch-audit/{legacy-catch-nonthrowing,legacy-catch-throwing,legacy-catch-inner-local}.wat -S ...` — Binaryen behavior summarized above.
- `moon test --target native src/passes/simplify_locals_wbtest.mbt --filter '*catch*'` — failed before implementation for the two parent-boundary tests, then passed `4/4` after skipping EH catch/catch-list child slots in the inliners.
- `moon fmt` — passed.
- `moon test --target native src/passes/simplify_locals_wbtest.mbt` — passed `10/10`.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — passed `46/46`.
- `moon test src/passes` — passed `3701/3701`.
- `moon build --target native --release src/cmd` — passed with pre-existing warnings; native binary path remains `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-smoke-100-after-eh-catch --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` — compared `100/100`, normalized `91`, mismatches `9`, validation/generator/property/command failures `0`, selected profiles straight-line `49`, tee-control `22`, effect-order `29`, Binaryen cache `100/0`; residual IDs are the same already-classified annotation-only aggregate set (`case-000041`, `000043`, `000060`, `000069`, `000070`, `000082`, `000084`, `000092`, `000094`).

Remaining EH work after this slice: catch bodies/catch-lists now have focused fresh-region coverage, but EH result carriers, typed catch payloads, `catch_ref` / `catch_all_ref`, branch-bearing catch regions, and scaled EH-heavy fuzzing remain open. The public WAT path still cannot demonstrate legacy `try` directly because it desugars before HOT; direct-HOT coverage is the current guard for `HotOp::Try`.

## Follow-up: unreachable bottom dead-set cleanup and nondefaultable tooling boundary

A later 2026-06-30 slice targeted the open unreachable/refinalization/nondefaultable row. Binaryen `version_130` was probed under `.tmp/slns-nondefaultable-audit/`.

Bottom-valued zero-read stack set probe:

```wat
(module
  (func (result i32) (local i32)
    unreachable
    local.set 0
    i32.const 1))
```

Command:

```sh
wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-nondefaultable-audit/bottom-dead-set.wat -S -o .tmp/slns-nondefaultable-audit/bottom-dead-set.opt.wat
wasm-opt --all-features --simplify-locals-notee-nostructure .tmp/slns-nondefaultable-audit/bottom-dead-set.wat -S -o .tmp/slns-nondefaultable-audit/bottom-dead-set-notee.opt.wat
```

Both Binaryen variants remove the stack-style `local.set` after `unreachable`, leaving the trap and the trailing `i32.const 1`. This is a narrow bottom/unreachable final-dead-set cleanup: the local has zero reads, the stack producer is unreachable-polymorphic, and removing the stack consumer preserves validation and behavior.

Red-first Starshine coverage added in `src/passes/simplify_locals_nostructure_test.mbt`:

- `simplify-locals-nostructure removes zero-read stack set after unreachable`
- `simplify-locals-notee-nostructure removes zero-read stack set after unreachable`

The canonical test failed before implementation because Starshine kept `unreachable; local.set 0; i32.const 1`. The fix adds a raw no-structure cleanup in `src/passes/pass_manager.mbt`: for direct no-structure variants only, a `local.set` after an unconditional terminator is replaced with `nop` when the target local has no later read. The early raw cleanup is intentionally limited to no-structure descriptors so it does not bypass existing full `simplify-locals` structure cleanup such as `simplify-locals removes unreachable dead local defs outside the ssa overlay`.

Nondefaultable local probe:

```wat
(module
  (type $s (struct))
  (func (result (ref $s)) (local (ref $s))
    struct.new_default $s
    local.set 0
    local.get 0))
```

Binaryen command:

```sh
wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-nondefaultable-audit/nonnullable-struct-local.wat -S -o .tmp/slns-nondefaultable-audit/nonnullable-struct-local.opt.wat
```

Binaryen sinks the `struct.new_default $s` to the result and leaves the now-unused nondefaultable local declaration. The optimized output validates with `wasm-tools validate --features all`.

Starshine command:

```sh
wasm-tools parse .tmp/slns-nondefaultable-audit/nonnullable-struct-local.wat -o .tmp/slns-nondefaultable-audit/nonnullable-struct-local.wasm
_build/native/release/build/cmd/cmd.exe --simplify-locals-nostructure .tmp/slns-nondefaultable-audit/nonnullable-struct-local.wasm -o .tmp/slns-nondefaultable-audit/nonnullable-struct-local.star.wasm
```

Starshine still fails before a safe SLNS behavior claim with `final module validate: locals: type has no default value` / `locals_error: local type has no default value`. Treat direct nondefaultable locals as a Starshine validation/tooling boundary for this audit, not a classified SLNS behavior match. Reopen when decode/validation/lowering can preserve and validate initialized nondefaultable locals well enough to run SLNS and compare optimized output.

A bottom-valued set/get probe:

```wat
(module
  (func (result i32) (local i32)
    unreachable
    local.set 0
    local.get 0))
```

Binaryen canonical SLNS rewrites this as `local.tee $0 (unreachable); local.get $0`; Starshine currently keeps the stack-style set/get spelling. This is semantic-equivalent unreachable-code output drift, not closed as a transform-family match. Reopen for a focused implementation if larger lanes show this family outside unreachable-polymorphic code, if output drift blocks normalization, or if pass-local size/performance evidence favors matching Binaryen's tee form.

Validation after implementation:

- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*unreachable*'` — failed before implementation for the canonical test, then passed after the no-structure raw cleanup.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*zero-read*'` — passed `8/8`.
- `moon test --target native src/passes/simplify_locals_test.mbt --filter '*unreachable dead local defs*'` — passed, proving the no-structure raw cleanup does not steal the full `simplify-locals` existing unreachable cleanup path.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — passed `48/48`.
- `moon fmt` — passed.
- `moon test src/passes` — passed `3703/3703` after restricting the early raw cleanup to no-structure descriptors.
- `moon build --target native --release src/cmd` — passed with pre-existing warnings; native binary path remains `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-smoke-100-after-unreachable-dead-set --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` — compared `100/100`, normalized `91`, mismatches `9`, validation/generator/property/command failures `0`, selected profiles straight-line `49`, tee-control `22`, effect-order `29`, Binaryen cache `100/0`; residual IDs are the same already-classified annotation-only aggregate set (`case-000041`, `000043`, `000060`, `000069`, `000070`, `000082`, `000084`, `000092`, `000094`).

Remaining refinalization/nondefaultable work: direct nondefaultable locals are tooling-blocked as above; the bottom set/get tee-form drift is still open; GC/refined refs, nondefaultable params, bottom values under structured/EH result carriers, and larger generated refinalization lanes remain unaudited.

## Follow-up: dedicated aggregate 1000 lane and attempted 10000 scale-up

A later 2026-06-30 slice advanced the dedicated GenValid signoff evidence without changing Starshine code. The native binary was checked first:

- `moon build --target native --release src/cmd` — `Finished. moon: no work to do`; current binary remains `_build/native/release/build/cmd/cmd.exe`.

The required dedicated aggregate lane was attempted at `10000` cases:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-10000-after-unreachable-dead-set --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

It timed out after `1800s` before `result.json` was written. Partial artifacts are still useful but not a completed lane: `.tmp/pass-fuzz-slns-genvalid-all-10000-after-unreachable-dead-set/cases.jsonl` had `6026` case records and `failures/` had `701` mismatch directories when the command was killed. A quick local classifier over those partial failure dirs found all mismatches selected `simplify-locals-nostructure-effect-order`; `676/701` were still identical after erasing structured-control result annotations, while `25/701` had additional output-shape drift. Because the lane has no `result.json`, treat this only as timeout/throughput and residual-shape evidence, not as signoff.

A completed bounded aggregate lane used the same seed/profile/binary:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-1000-after-unreachable-dead-set --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 500 --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized `874`, cleanup-normalized `0`, mismatches `126`, validation failures `0`, generator failures `0`, property failures `0`, command failures `0`, selected profiles straight-line `423`, tee-control `276`, effect-order `301`, Binaryen cache `1000/0`.

Local classifier artifact: `.tmp/slns-genvalid-all-1000-after-unreachable-dead-set-result-type-classification.txt`.

Classifier summary:

- All `126` mismatches selected the effect-order leaf.
- `wasm-tools validate --features all` accepted all `252` Binaryen and Starshine optimized wasm artifacts from the 126 mismatch dirs.
- `120/126` residuals become text-identical after erasing only structured-control result annotations, matching the earlier 30-case and 100-case bounded residual family.
- `6/126` residuals do **not** become identical after erasing result annotations:
  - `case-000194`, `case-000251`, `case-000692`, `case-000770`, and `case-000997` differ by Binaryen-emitted `unreachable` debris after throwing `try_table` arms. This looks related to unreachable-control debris / EH result canonicalization, but it is not classified as semantic-safe until reduced or normalized with explicit evidence.
  - `case-000606` differs by a Binaryen tee-form rewrite of a pure `i32.const 50` local into an imported-call argument (`local.tee $0 (i32.const 50)`) while Starshine keeps the earlier `local.set $0` and later `local.get $0`. This is an open effect-order / later-cycle tee-form parity gap unless a later slice proves it is an intentional Starshine win.

This slice therefore improves the dedicated-profile evidence from 100-case smoke to a completed 1000-case lane, but it also reopens the residual classification beyond the previous annotation-only smoke set. The 10000 dedicated aggregate lane, the full four-lane pass signoff matrix, and pass-local performance target remain open.

## Follow-up: value-block call-argument tee-form residual

A later 2026-06-30 slice reduced and fixed the non-annotation `case-000606` residual from `.tmp/pass-fuzz-slns-genvalid-all-1000-after-unreachable-dead-set`. The generated case was not fundamentally a `call_ref` issue: the minimal reproducer is a pure multi-use `i32.const 50` local whose first surviving use is a later imported-call argument, but an earlier sibling call argument is a branch-free value-producing `block`.

Reduced probe:

```wat
(module
  (import "env" "f" (func $f (param i31ref i32)))
  (func (local i32)
    i32.const 50
    local.set 0
    block (result i31ref)
      ref.null i31
    end
    local.get 0
    call $f
    local.get 0
    drop))
```

Binaryen `version_130` keeps the branch-free value block as a call argument and rewrites the later multi-use pure local carrier to `local.tee $0 (i32.const 50)`. Starshine previously cleared pending sinkables after every value-producing block, so the pure local set remained before the call and both later uses stayed as `local.get 0`. The red-first regression `simplify-locals-nostructure carries pure tee candidate across value block call argument` failed with the old `local.set` / `local.get` carrier, then passed after branch-free blocks stopped clearing sinkables solely because they produce a result. Branch-bearing blocks still clear the pending set, so this is a narrow no-structure linear-boundary fix rather than structure synthesis.

Validation and profile evidence after the fix:

- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*value block call argument*'` — failed before implementation, passed after.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — `49/49` passed.
- `moon fmt` — passed.
- `moon test src/passes` — `3704/3704` passed.
- `moon build --target native --release src/cmd` — passed with pre-existing warnings; native binary path remains `_build/native/release/build/cmd/cmd.exe`.
- `moon info` — passed with pre-existing warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-1000-after-value-block --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 500 --keep-going-after-command-failures` — compared `1000/1000`, normalized `875`, cleanup-normalized `0`, mismatches `125`, validation/generator/property/command failures `0`, selected profiles straight-line `423`, tee-control `276`, effect-order `301`, Binaryen cache `1000/0`.
- Classifier `.tmp/slns-genvalid-all-1000-after-value-block-result-type-classification.txt` — all `125` mismatches selected the effect-order leaf; `120/125` become identical after erasing structured-control result annotations; all `250` Binaryen/Starshine optimized wasm artifacts validate; the only non-annotation residuals are the same five EH/unreachable-debris cases (`case-000194`, `000251`, `000692`, `000770`, `000997`).

Remaining work after this slice: the required 10000 dedicated aggregate lane still has not completed; the five EH/unreachable-debris residuals need reduction/classification; direct nondefaultable locals remain validation/tooling-blocked; bottom set/get tee-form unreachable-code drift remains open; embedded structured-control `local.tee`, broader `call_ref` / `call_indirect` / tail-call surfaces, EH typed payload/result carriers, shared-memory/atomic precision, branch-bearing block precision, and pass-local performance remain open.

## Follow-up: EH `try_table` result/unreachable-debris residual classification

A later 2026-06-30 slice reduced and classified the five remaining non-annotation residuals from `.tmp/pass-fuzz-slns-genvalid-all-1000-after-value-block`: `case-000194`, `case-000251`, `case-000692`, `case-000770`, and `case-000997`. All five selected `simplify-locals-nostructure-effect-order`; the earlier classifier already validated all corresponding Binaryen and Starshine optimized wasm artifacts.

The residual family is narrower than a general EH/catch semantic mismatch. Binaryen `version_130` canonicalizes `try_table` bodies that cannot produce a normal value (`throw` or `unreachable`, with `catch_ref` / `catch_all_ref` exiting to an enclosing exnref result) by removing the `try_table` result annotation, refining the surrounding exnref result spelling, and in some `if`-arm shapes leaving explicit `unreachable` debris. Starshine preserves the result-typed `try_table` form. The reduced outputs validate on both sides and appear behavior-equivalent for the inspected shapes, but Binaryen's form is smaller, so this is not accepted as a Starshine win.

The first reduction used `wasm-reduce` against `case-000194` with an interestingness script that required Binaryen to emit no-result EH plus `unreachable`/EH debris while Starshine retained a result-typed `try_table`:

```sh
wasm-reduce \
  .tmp/pass-fuzz-slns-genvalid-all-1000-after-value-block/failures/case-000194-gen-valid/input.wasm \
  --all-features \
  --force \
  --timeout=5 \
  --command='.tmp/slns-eh-debris-interesting.sh .tmp/slns-eh-debris-test.wasm' \
  --test=.tmp/slns-eh-debris-test.wasm \
  --working=.tmp/slns-eh-debris-reduced.wasm
```

The reduced input `.tmp/slns-eh-debris-reduced.wasm` still contains unrelated `ref.func` local traffic followed by a dropped exnref block whose `try_table (result exnref)` body is `unreachable`. Binaryen removes the `try_table` result and refines the surrounding block result; Starshine preserves the result-typed `try_table`.

A smaller manual probe that keeps the same trigger shape is:

```wat
(module
  (tag $e)
  (elem declare func $dummy)
  (func $dummy)
  (func (local funcref)
    ref.func $dummy
    local.set 0
    local.get 0
    drop
    (drop
      (block $h (result exnref)
        (try_table (result exnref) (catch_ref $e $h)
          unreachable)))))
```

Commands:

```sh
wasm-tools parse .tmp/slns-eh-debris-manual3.wat -o .tmp/slns-eh-debris-manual3.wasm
wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-eh-debris-manual3.wasm -o .tmp/slns-eh-debris-manual3.binaryen.wasm
_build/native/release/build/cmd/cmd.exe --simplify-locals-nostructure .tmp/slns-eh-debris-manual3.wasm -o .tmp/slns-eh-debris-manual3.starshine.wasm
wasm-tools validate --features all .tmp/slns-eh-debris-manual3.binaryen.wasm
wasm-tools validate --features all .tmp/slns-eh-debris-manual3.starshine.wasm
```

Both optimized wasm outputs validate. The Binaryen output is `60` bytes and the Starshine output is `81` bytes. Two sibling probes behave the same way:

- `.tmp/slns-eh-debris-manual4.wat` changes the body to `throw $e`; Binaryen validates at `61` bytes and Starshine validates at `82` bytes.
- `.tmp/slns-eh-debris-manual5.wat` places the throwing `try_table` in an `if` arm feeding an exnref call; Binaryen validates at `85` bytes and Starshine validates at `118` bytes.

Agent classification: this residual family is not currently evidence for a true semantic mismatch, because both outputs validate and the reduced shapes differ only in EH result/canonical-unreachable spelling for bodies with no normal value. It is also not an accepted representation boundary, because the Starshine spelling is size-losing in the reduced probes. Keep it open as an EH result/refinalization parity and performance gap. Reopen or fix when working on EH typed result carriers, `try_table` result refinalization, output normalizers, or pass-local size/performance.

## Follow-up: narrow dropped-block EH no-normal result rewrite

A later 2026-06-30 slice added red-first coverage for the smallest dropped-block subcase from the EH result/refinalization family. The focused test `simplify-locals-nostructure canonicalizes no-normal try_table result` uses the manual3 shape: a dropped `block (result exnref)` whose only body root is `try_table (result exnref)` with an `unreachable` body and `catch_ref` to the block label. Before implementation, Starshine preserved the result-typed `try_table`; the test failed with a live nonvoid no-normal `try_table` in the optimized function. The fix runs a narrow lowered no-structure canonicalization after local cleanup, even when the lowered stack-hazard guard skips broader cleanup: only a result-typed block that is immediately dropped, whose body is exactly a ref-payload `catch_ref` / `catch_all_ref` `try_table` ending in `unreachable` / `throw`, rewrites the `try_table` to void and inserts an explicit `unreachable` in the block body. A deliberately broader trial that rewrote all no-normal result-typed `try_table` nodes also touched generated call-argument / `if`-arm contexts where Binaryen keeps the result annotation; the 1000-case aggregate worsened to `873/1000` normalized with `127` mismatches, including new `case-000305`, so the final implementation is intentionally limited to dropped blocks.

Validation and evidence:

- Red-first focused test failed before implementation, then `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*no-normal try_table*'` passed.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` passed `50/50`.
- `moon fmt` passed.
- `moon test src/passes` passed `3705/3705`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings; native binary path remains `_build/native/release/build/cmd/cmd.exe`.
- `moon info` passed with pre-existing warnings.
- Manual dropped-block probes after the fix:
  - `.tmp/slns-eh-debris-manual3.starshine.after-dropped-block.wasm` validates and prints as no-result `try_table` plus explicit `unreachable`; raw size is `82` bytes because Starshine preserves names, but `wasm-opt --strip-debug` gives Starshine `59` bytes vs Binaryen `60` bytes.
  - `.tmp/slns-eh-debris-manual4.starshine.after-dropped-block.wasm` validates and similarly strips to Starshine `60` bytes vs Binaryen `61` bytes.
  - `.tmp/slns-eh-debris-manual5.starshine.after-dropped-block.wasm` validates but remains a broader if-arm/call-argument result context; it strips to Starshine `84` bytes vs Binaryen `85` bytes but is not used to claim generated-lane closure.
- Dedicated aggregate smoke after the narrow fix:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-1000-after-dropped-block-eh-only --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 500 --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized `875`, mismatches `125`, cleanup-normalized `0`, validation/generator/property/command failures `0`, selected profiles straight-line `423`, tee-control `276`, effect-order `301`, Binaryen cache `1000/0`. This matches the post-value-block aggregate count, so the slice fixes a focused dropped-block subcase but does not reduce the generated residual set. Keep the five EH generated residual IDs open until the broader call-argument / `if`-arm result contexts are implemented safely or precisely classified with source-backed reopening criteria.

## Follow-up: constant-dead if-arm `try_table` result canonicalization

A later 2026-06-30 slice narrowed the open EH result/refinalization residuals further without changing the `version_130` source baseline. Manual probe `.tmp/slns-eh-debris-manual5.wat` places a no-normal `try_table (result exnref)` in the `then` arm of an `if (result exnref)` whose condition is the constant `0`, so that arm is stack-polymorphic/dead while the `else` arm supplies the value. Binaryen removes the `try_table` result annotation and leaves explicit `unreachable` debris in that arm.

Red-first Starshine test added:

- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure canonicalizes no-normal if-arm try_table result`

The test failed before implementation because Starshine preserved the result-typed `catch_ref` `try_table`. The kept implementation rewrites only `if` arms proved dead by a preceding root `i32.const` condition and only when the arm body is exactly a tag-specific `catch_ref` no-normal `try_table`; it emits a void `try_table` plus explicit `unreachable`. This is intentionally narrower than the dropped-block helper, because aggregate replay showed broader arm rewriting was unsafe as a Binaryen-shape approximation: `.tmp/pass-fuzz-slns-genvalid-all-1000-after-if-arm-eh` compared `1000/1000` but regressed to `874` normalized matches, `126` mismatches, and added `case-000488`, where Binaryen kept a live `catch_all_ref` arm result-typed.

Validation after narrowing:

- `moon fmt` — passed.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*if-arm try_table*'` — failed before implementation, then passed.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — `51/51` passed.
- `moon test src/passes` — `3706/3706` passed.
- `moon info` — passed with pre-existing warnings.
- `moon build --target native --release src/cmd` — passed with pre-existing warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-1000-after-dead-if-arm-catch-ref-eh --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 500 --keep-going-after-command-failures` — compared `1000/1000`, normalized `875`, mismatches `125`, cleanup-normalized `0`, validation/generator/property/command failures `0`, selected profiles straight-line `423`, tee-control `276`, effect-order `301`, Binaryen cache `1000/0`.

This slice is not closure evidence. It proves one dead-arm `catch_ref` subcase and no aggregate regression, but the aggregate residual count is unchanged. Live arms, `catch_all_ref`, nested block/call-argument contexts, and surrounding result/refinalization cleanup remain open, and the dedicated `10000` lane plus final four-lane signoff still have not completed.

## Follow-up: post-dead-if EH residual classification and rejected live-block trial

A later 2026-06-30 slice classified the post-dead-if-arm aggregate without keeping a behavior change. The kept lane was:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-1000-after-dead-if-arm-catch-ref-eh --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 500 --keep-going-after-command-failures
```

It compared `1000/1000`, normalized `875`, left `125` mismatches, and had zero validation/generator/property/command failures. The new classifier artifact `.tmp/slns-genvalid-all-1000-after-dead-if-arm-catch-ref-eh-result-type-classification.txt` inspected those `125` failure dirs: `122/125` become identical after erasing only structured-control result annotations, and all Binaryen/Starshine optimized wasm outputs validate. `case-000194` and `case-000997`, previously part of the five EH/unreachable-debris residuals, are now annotation-only after the dropped-block and constant-dead if-arm fixes.

The remaining non-annotation residuals are:

- `case-000251`: both `if` arms contain no-normal `catch_all_ref` `try_table` bodies. Binaryen removes both `try_table` result annotations and emits explicit `unreachable` debris; Starshine preserves result-typed `try_table`s.
- `case-000692`: a live call-argument block contains a no-normal `catch_all_ref` `try_table`. Binaryen removes the `try_table` result and emits explicit `unreachable`; Starshine preserves the result-typed `try_table`.
- `case-000770`: a live `else` block contains a no-normal `catch_ref` `try_table`. Binaryen removes the `try_table` result and emits explicit `unreachable`; Starshine preserves the result-typed `try_table`.

A focused live-block `catch_all_ref` probe was tried red-first and failed as expected, but the implementation trial was rejected. The trial broadened the existing block-body canonicalizer from dropped-value blocks to every block whose body is exactly a no-normal ref-payload `try_table`. The focused probe then passed, and focused SLNS plus `moon test src/passes` and a native `src/cmd` build passed, but the aggregate replay regressed:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-1000-after-live-block-eh --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 500 --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized `874`, mismatches `126`, zero failures, Binaryen cache `1000/0`. The only added residual was `case-000305`, where Binaryen keeps a live `catch_all_ref` block result-typed but the trial rewrote it to a void `try_table` plus `unreachable`. The broad live-block rewrite was therefore reverted. Agent classification: the remaining three non-annotation EH cases are open parity/performance gaps, not accepted drift, and live block/arm EH result canonicalization needs a stricter Binaryen-backed discriminator before another behavior change.

Validation kept after reverting the trial: `moon fmt` passed and focused `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*try_table*'` passed `4/4`. Full `moon test`, the required dedicated `10000` aggregate, final four-lane signoff, and pass-local performance target remain open.

## Follow-up: live EH result canonicalization appears refinalization-triggered

A later 2026-06-30 classification-only slice built Binaryen oracle probes to separate the remaining live `catch_all_ref` call-argument residual (`case-000692`) from the rejected broad live-block rewrite residual (`case-000305`). No Starshine behavior was changed.

The key reduced oracle artifact is `.tmp/slns-eh-probes/case692-live-callarg-reduced.wasm` with text at `.tmp/slns-eh-probes/case692-live-callarg-reduced.wat`. It keeps a live imported-call argument block containing a no-normal `catch_all_ref` `try_table`, plus an unrelated `ref.func` local set/get pair in the same function:

```wat
(local.set $12 (ref.func $0))
(drop (local.get $12))
(call $fimport$0
  (block $block (result exnref)
    (try_table (result exnref) (catch_all_ref $block)
      (unreachable)))
  (i64.const 0))
```

Running Binaryen `version_130` with `--simplify-locals-nostructure`, then reprinting the produced wasm, gives `.tmp/slns-eh-probes/case692-live-callarg-reduced.opt.wat`: the local pair becomes `drop(ref.func $0)`, and the live call-argument block is refinalized to `(result (ref exn))` with a void `try_table` plus explicit `unreachable`:

```wat
(drop (ref.func $0))
(call $fimport$0
  (block $block (result (ref exn))
    (try_table (catch_all_ref $block)
      (unreachable))
    (unreachable))
  (i64.const 0))
```

Manual counter-probes show this is not a simple live-block shape rule:

- `.tmp/slns-eh-probes/callarg-import-first-with-later-load.wat`, `.tmp/slns-eh-probes/callarg-local-first-with-later-load.wat`, `.tmp/slns-eh-probes/callarg-import-second-last.wat`, and `.tmp/slns-eh-probes/callarg-local-second-last.wat` keep their live `catch_all_ref` `try_table` result annotations when no local simplification in the same function triggers Binaryen's `ReFinalize` path.
- `.tmp/slns-eh-probes/callarg-local-second-last-refinalize-trigger.wat` adds only a `ref.func` local set/get simplification to an otherwise stationary second-call-argument shape, and Binaryen then voids the no-normal live `catch_all_ref` `try_table` and inserts explicit `unreachable`.
- A reduction attempt for `case-000305` that only required “keeps result typed” collapsed to a dropped-block/no-refinalize shape (`.tmp/slns-eh-probes/case305-live-keep-result-reduced.wasm`), which is useful mainly as a warning: broad live-block rewriting does not model Binaryen's conditional refinalization behavior.

Inference: the remaining live `case-000692`-style residual is likely caused by Binaryen's function-level refinalization after a type-changing local-get replacement (for example replacing a nullable `funcref`/typed local get with a more refined `ref.func` expression), not by `SimplifyLocals` deliberately canonicalizing every no-normal live EH block. The rejected Starshine trial rewrote live blocks without such a refinalization discriminator, which explains why it fixed one focused probe but added `case-000305`.

Agent classification: this slice narrows the open fix direction but does not close the residual. A future safe Starshine fix should first expose or reconstruct a pass-local “Binaryen would refinalize this function” signal, then add red-first coverage for both sides: a refinalization-triggered live `catch_all_ref` call-argument block should void the `try_table`, while the no-refinalization live `catch_all_ref` block should remain result-typed. Do not revive broad live-block rewriting without this or an equally strong Binaryen-backed discriminator.

Commands used in this slice:

```sh
wasm-reduce .tmp/pass-fuzz-slns-genvalid-all-1000-after-dead-if-arm-catch-ref-eh/failures/case-000692-gen-valid/input.wasm --all-features -f --command=.tmp/slns-eh-probes/interesting-case692-live-callarg.sh --test=.tmp/slns-eh-probes/case692-live-callarg-test.wasm --working=.tmp/slns-eh-probes/case692-live-callarg-reduced.wasm
wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-eh-probes/case692-live-callarg-reduced.wasm -o .tmp/slns-eh-probes/case692-live-callarg-reduced.opt.wasm
wasm-opt --all-features -S .tmp/slns-eh-probes/case692-live-callarg-reduced.opt.wasm -o .tmp/slns-eh-probes/case692-live-callarg-reduced.opt.wat
wasm-opt --all-features --simplify-locals-nostructure .tmp/slns-eh-probes/callarg-local-second-last-refinalize-trigger.wat -o .tmp/slns-eh-probes/callarg-local-second-last-refinalize-trigger.opt.wasm
```

No Moon tests, native rebuild, dedicated `10000` lane, final four-lane signoff, or performance run were executed in this classification-only slice.

## Follow-up: refinalization-triggered live `catch_all_ref` block fix

A later 2026-06-30 slice turned the prior refinalization-discriminator evidence into a narrow red/green behavior change. Two focused tests were added:

- `simplify-locals-nostructure keeps live no-normal catch_all_ref block without refinalization trigger` locks the rejected broad-live-block boundary (`case-000305`-style): without a same-function local simplification that would make Binaryen run `ReFinalize`, the live call-argument block keeps its result-typed `catch_all_ref` `try_table`.
- `simplify-locals-nostructure canonicalizes live no-normal catch_all_ref block after refinalization trigger` covers the `case-000692` direction: adding a same-function `ref.func; local.set N; local.get N` simplification lets the live no-normal block canonicalize to a void `try_table` plus explicit `unreachable`.

The positive test failed red-first while Starshine preserved the result-typed live block. The kept implementation does not revive the broad live-block rewrite. Instead, lowered SLNS canonicalization receives the original lowered function and computes a narrow proxy for Binaryen's refinalization path: a `ref.func` local-set immediately followed by a `local.get` of the same local. Only in that proxy context does the existing no-normal block-body canonicalizer apply to live blocks; no-refinalization live blocks remain result-typed.

Validation and evidence:

- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*live no-normal catch_all_ref*'` — failed `1/2` before implementation, then passed `2/2` after the discriminator fix.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — `53/53` passed.
- `moon fmt` — passed.
- `moon test src/passes` — `3708/3708` passed.
- `moon info` — passed with pre-existing warnings.
- `moon build --target native --release src/cmd` — passed with pre-existing unused-function warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-1000-after-refinalized-live-catchall2 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 500 --keep-going-after-command-failures` — compared `1000/1000`, normalized `875`, cleanup-normalized `0`, mismatches `125`, validation/generator/property/command failures `0`, selected profiles straight-line `423`, tee-control `276`, effect-order `301`, Binaryen cache `1000/0`.
- Local classifier `.tmp/slns-genvalid-all-1000-after-refinalized-live-catchall2-result-type-classification.txt` — `124/125` residuals become identical after erasing structured-control result annotations and all optimized wasm outputs validate. `case-000692` and `case-000770` moved into the annotation-only class; only `case-000251` remains non-annotation.

Remaining work: `case-000251` (both arms contain no-normal `catch_all_ref` bodies) still needs focused oracle probing before any implementation. The aggregate mismatch count is unchanged, the required `10000` dedicated aggregate remains incomplete, full `moon test` has not been rerun in this slice, the final four-lane pass signoff is still open, and the pass-local performance target remains open.

## Follow-up: both-arm `catch_all_ref` case-000251 probe

A later 2026-06-30 slice probed the last non-annotation residual from `.tmp/pass-fuzz-slns-genvalid-all-1000-after-refinalized-live-catchall2`: `case-000251`, where both arms of a result-typed `if` contain no-normal `catch_all_ref` `try_table` bodies.

Binaryen probes under `.tmp/slns-eh-probes/` established a narrow discriminator:

- `.tmp/slns-eh-probes/case251-both-arms-no-refinalization.wat` — Binaryen `version_130` keeps both `catch_all_ref` arms result-typed when the function has no local simplification that appears to trigger `ReFinalize`.
- `.tmp/slns-eh-probes/case251-both-arms-refinalization.wat` — adding a same-function `ref.func; local.set; local.get; drop` simplification makes Binaryen void the both-arm `catch_all_ref` `try_table` bodies and wrap the result context in a block.

Red-first coverage was added for this paired discriminator:

- `simplify-locals-nostructure keeps both-arm catch_all_ref if without refinalization trigger`
- `simplify-locals-nostructure canonicalizes both-arm catch_all_ref if after refinalization trigger`

The positive test failed before implementation while the explicit-block probe retained result-typed `try_table`s, then passed after adding a lowered canonicalizer path for refinalization-context blocks whose body ends in a constant-conditioned, both-arm no-normal `catch_all_ref` `if`. The boundary test keeps the no-refinalization form result-typed.

However, the generated `case-000251` residual is **not closed**. The completed replay after this change stayed at the same aggregate counts:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-1000-after-case251-both-arm3 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 500 --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized `875`, cleanup-normalized `0`, mismatches `125`, validation/generator/property/command failures `0`, selected profiles all residuals in `simplify-locals-nostructure-effect-order`, Binaryen cache `1000/0`. Classifier `.tmp/slns-genvalid-all-1000-after-case251-both-arm3-result-type-classification.txt` still reports `124/125` annotation-only residuals, zero wasm validation failures, and `case-000251` as the only non-annotation residual. The generated case still preserves a result-typed `catch_all_ref` block and also differs in surrounding ref.func/local/call_ref simplification, so the remaining gap is broader than the explicit-block subcase.

Validation from this slice:

- Red-first focused filter `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*catch_all_ref*'` initially failed on the new positive and then passed `4/4`.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — `55/55` passed.
- `moon fmt` — passed.
- `moon test src/passes` — `3710/3710` passed.
- `moon build --target native --release src/cmd` — passed with pre-existing unused-function warnings.
- `moon info` — passed with pre-existing warnings.
- `git diff --check` — passed.

Remaining work: `case-000251` remains an open parity/performance gap, not accepted drift. The next slice should reduce why the generated case's `ref.func; local.set; local.get; call_ref` neighborhood is not matching Binaryen's local simplification/refinalization path, and avoid broadening live `catch_all_ref` rewrites because `case-000305` remains a proven no-refinalization boundary. The required `10000` dedicated aggregate, full `moon test`, final four-lane pass signoff, and pass-local performance target remain open.


## Follow-up: generated case-000251 catch target retargeting

A later 2026-06-30 slice attacked the remaining generated `case-000251` residual from `.tmp/pass-fuzz-slns-genvalid-all-1000-after-case251-both-arm3`. Binaryen probe `.tmp/slns-eh-probes/case251-callref-refinalization-min.wat` showed that `ref.func; local.set; local.get; call_ref` is also enough to trigger Binaryen `version_130` refinalization: Binaryen rewrites the `call_ref` operand to `ref.func`, voids both no-normal `catch_all_ref` `try_table` arms, retargets their catches to the enclosing block, and refines that block to `(result (ref exn))`.

The generated case exposed a label-depth detail missing from the explicit `$h` block tests. In generated WAT the catches were `catch_all_ref 0` targeting the result-typed `if` label. Once Starshine voided the `if`, reusing label depth `0` made the lowered function fail writeback validation with `catch_all_ref label must expect exnref`; the pass therefore skipped the generated function and preserved the mismatch. The kept fix adds a narrow original-function refinalization proxy for `ref.func; local.set; local.get; call_ref` / `return_call_ref`, retargets only zero-depth `catch_all_ref` labels in the both-arm voided-if helper to depth `1`, and emits the wrapper block as non-null `(ref exn)`. The no-refinalization boundary remains protected by the existing `case-000305`/both-arm tests; this does not revive broad live-block rewriting.

A public red-first WAT test for the exact `call_ref` shape was attempted but the current Starshine WAT test parser rejected the needed `call_ref` syntax, so the red/green evidence for this sub-slice is the generated replay plus Binaryen probe rather than a committed focused parser fixture. Direct generated `case-000251` replay after the fix no longer emits `skip-invalid-lower`, and the Starshine output validates. However, the aggregate is still not improved: `.tmp/pass-fuzz-slns-genvalid-all-1000-after-case251-label-retarget2` compared `1000/1000`, normalized `875`, left `125` mismatches, and had zero validation/generator/property/command failures with Binaryen cache `1000/0`. The remaining generated gap includes surrounding `call_ref` operand/type/local spelling (for example Starshine still prints block-wrapped `ref.func` operands in places where Binaryen prints direct `ref.func`), so `case-000251` remains an open parity gap rather than accepted drift.

Validation for this sub-slice: `moon fmt` passed; focused `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*catch_all_ref*'` passed `4/4`; focused SLNS passed `55/55`; `moon test src/passes` passed `3710/3710`; `moon build --target native --release src/cmd` passed with pre-existing warnings; `moon info` passed with pre-existing warnings; `git diff --check` passed. Full `moon test`, the required `10000` dedicated aggregate, final four-lane signoff, and pass-local performance target remain open.

## 2026-06-30 follow-up: `case-000251` exact-if probe remains insufficient

After the label-retarget slice, I inspected the latest generated residual in `.tmp/pass-fuzz-slns-genvalid-all-1000-after-case251-label-retarget2/failures/case-000251-gen-valid/`. The direct Binaryen-vs-Starshine diff at that point included an `if` result spelling difference: Binaryen printed `(ref null (exact $1))` for a `ref.func` / `ref.null func` table-set value, while Starshine printed `funcref`.

A minimal Binaryen probe `.tmp/slns-eh-probes/case251-if-ref-func-result-min.wat` confirms this is a `version_130` `ReFinalize` sub-shape: a same-function `ref.func; local.set; local.get` trigger makes Binaryen narrow the `if (result funcref)` arm type to `(ref null (exact $ft))`. Starshine now has a white-box lowered-cleanup regression in `src/passes/pass_manager_wbtest.mbt` for that exact-if subcase because the public WAT test path is still blocked for the generated `call_ref` spelling.

This subcase did **not** close the generated residual. A first attempted 1000 aggregate, `.tmp/pass-fuzz-slns-genvalid-all-1000-after-case251-exact-if`, used the non-existent `target/native/release/build/cmd/cmd.exe` path and produced `1000` Starshine command failures, so it is not parity evidence. Valid rebuilt lanes using `_build/native/release/build/cmd/cmd.exe` all stayed unchanged: `.tmp/pass-fuzz-slns-genvalid-all-1000-after-case251-exact-if2`, `.tmp/pass-fuzz-slns-genvalid-all-1000-after-case251-exact-if3`, and `.tmp/pass-fuzz-slns-genvalid-all-1000-after-case251-callref-context` each compared `1000/1000`, normalized `875`, left `125` mismatches, and had zero validation/generator/property/command failures with Binaryen cache `1000/0`.

The latest rebuilt `case-000251` diff still includes broader local cleanup/directization drift, the exact-if result spelling, and no-normal `catch_all_ref` EH result-voiding differences. Keep `case-000251` open as a parity gap; do not classify it as safe annotation-only drift, and do not count the failed `target/native/...` run as evidence.

## 2026-06-30 follow-up: local `call_ref` directization subcase is not the generated path

After the exact-if slice, I added a red-first white-box lowered-cleanup regression for a direct `ref.func; local.set; local.get; call_ref` target wrapper. This fixture was built directly in `src/passes/pass_manager_wbtest.mbt` because the public WAT test path remains blocked for the exact generated `call_ref` spelling. The test failed before implementation while the lowered cleanup preserved the local wrapper, then passed after adding a narrow no-later-read directizer for adjacent `ref.func` local wrappers and treating that rewrite as a refinalization trigger.

Validation and evidence from this sub-slice:

- `moon test --target native src/passes/pass_manager_wbtest.mbt --filter '*directizes ref.func local call_ref target*'` — failed before implementation, then passed after the lowered directizer.
- `moon test --target native src/passes/pass_manager_wbtest.mbt --filter '*simplify-locals-nostructure lowered cleanup*'` — `3/3` passed.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — `55/55` passed.
- `moon fmt` — passed.
- `moon build --target native --release src/cmd` — passed with pre-existing warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-1000-after-case251-local-callref-directize3 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 500 --keep-going-after-command-failures` — compared `1000/1000`, normalized `875`, cleanup-normalized `0`, mismatches `125`, validation/generator/property/command failures `0`, selected profiles straight-line `423`, tee-control `276`, effect-order `301`, Binaryen cache `1000/0`.

This did **not** close generated `case-000251`. In `.tmp/pass-fuzz-slns-genvalid-all-1000-after-case251-local-callref-directize3/failures/case-000251-gen-valid/starshine.wat`, Starshine still prints the generated `local.set $9 (ref.func $0)` / `call_ref $1 (local.get $9)` wrapper, the `funcref` if result, and the result-typed `catch_all_ref` arms. The new lowered helper is therefore useful coverage for a safe subcase, but the generated residual is likely flowing through a raw/HOT path or a different canonicalization entry point. Keep `case-000251` open as a parity gap, not annotation-only drift or an accepted representation difference.

Open signoff remains unchanged: full `moon test`, the required dedicated `10000` aggregate, final four-lane pass signoff, and pass-local performance target have not been run in this sub-slice.

## 2026-06-30 case-000251 table-set exact-if writeback gate

Follow-up generated-case inspection showed the previous lowered local-call-ref directizer did not reach the aggregate residual because the generated function was rolling back at writeback: exact-if refinalization narrowed a `funcref` `if` feeding `table.set` to `(ref null (exact $ft))`, then Starshine's writeback validation returned `type mismatch` and skipped the lowered result. Added red-first direct-lib pipeline coverage `simplify-locals-nostructure keeps table-set funcref if validating while directizing later call_ref local`; it failed on `skip-invalid-lower` before implementation. The kept fix suppresses exact-if refinalization only for values immediately consumed by `table.set`, which allows writeback validation to succeed and lets the existing local-call-ref directization plus no-normal `catch_all_ref` retargeting apply. Focused validation: red/green focused test passed after implementation; full focused SLNS `56/56`; lowered-cleanup white-box `3/3`; `moon fmt`; native `src/cmd` build with pre-existing warnings. Rebuilt aggregate `.tmp/pass-fuzz-slns-genvalid-all-1000-after-case251-table-set-exact-suppress` compared `1000/1000`, normalized `875`, left `125` mismatches, and had zero validation/generator/property/command failures with selected profiles `423/276/301` and Binaryen cache `1000/0`. Generated `case-000251` remains open, now reduced to Binaryen's exact table-set if result annotation vs Starshine's validating `funcref` spelling; this is exact-if/writeback-validation parity drift, not accepted closure.

## 2026-06-30 case-000251 exact null arm writeback fix

The table-set suppression slice left `case-000251` as an exact-if/writeback-validation parity gap: Binaryen printed `(ref null (exact $ft))` for the table-set value `if`, while Starshine kept the validating `funcref` spelling to avoid rolling back the lowered cleanup. A follow-up red-first white-box check showed the more precise validation failure: Starshine narrowed the if block type but left the `ref.null func` arm unchanged, so validating the optimized module failed with a branch result type mismatch.

The kept fix rewrites the null arm to `ref.null (ref null exact $ft)` whenever the lowered SLNS refinalizer narrows a `ref.func` / `ref.null func` if result to the exact nullable function type. After that, the temporary immediate-`table.set` exact-if suppression was removed. The direct-lib pipeline regression in `src/passes/simplify_locals_nostructure_test.mbt` now expects the exact table-set if, validates the optimized module, and still proves the later `ref.func; local.set; local.get; call_ref` wrapper is directized. Public WAT coverage remains blocked for the generated `call_ref` spelling, so this remains a direct-lib/white-box fixture pair.

Validation and evidence from this slice:

- `moon test --target native src/passes/pass_manager_wbtest.mbt --filter '*refinalizes ref.func null if result*'` — failed before implementation because the optimized module did not validate; passed after the exact-null-arm rewrite.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*exact table-set if validating*'` — passed after updating the direct-lib pipeline regression to require exact table-set spelling and module validation.
- `moon test --target native src/passes/pass_manager_wbtest.mbt --filter '*simplify-locals-nostructure lowered cleanup*'` — `3/3` passed.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — `56/56` passed. This command was accidentally launched concurrently with the previous Moon test and waited on `_build/.moon-lock`; future slices should keep Moon commands serialized.
- `moon fmt` — passed.
- `moon build --target native --release src/cmd` — passed with pre-existing unused-function warnings; native binary path remains `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-1000-after-exact-ref-null-arm --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 500 --keep-going-after-command-failures` — compared `1000/1000`, normalized `893`, cleanup-normalized `0`, mismatches `107`, validation/generator/property/command failures `0`, selected profiles straight-line `423`, tee-control `276`, effect-order `301`, Binaryen cache `1000/0`.
- `git diff --check` — passed.

Generated `case-000251` is no longer present in the latest failure set, and the aggregate residual count drops from `125` to `107`. This is meaningful progress but not closeout: the remaining `107` residuals have not been reclassified under the new output shape, full `moon test` has not been rerun, the required dedicated `10000` aggregate remains incomplete, final four-lane signoff is open, and pass-local performance evidence remains open.

## 2026-06-30 latest 1000-lane residual classification after exact-null-arm fix

After the exact-null-arm writeback fix, I reclassified the latest rebuilt dedicated aggregate `.tmp/pass-fuzz-slns-genvalid-all-1000-after-exact-ref-null-arm` instead of carrying forward the stale `124/125` plus `case-000251` classification. The classifier output is stored at `.tmp/slns-genvalid-all-1000-after-exact-ref-null-arm-result-type-classification.txt`.

Classifier result:

- Failure dirs inspected: `107`.
- Selected profile for all residuals: `simplify-locals-nostructure-effect-order`.
- `107/107` residuals become identical after erasing only structured-control result annotations from Binaryen and Starshine WAT.
- Non-annotation residuals: `0`.
- `wasm-tools validate --features all` accepted all `428` residual wasm artifacts (`binaryen.wasm`, `starshine.wasm`, `binaryen.raw.wasm`, and `starshine.raw.wasm` for each failure dir).
- Compared to `.tmp/pass-fuzz-slns-genvalid-all-1000-after-case251-table-set-exact-suppress`, the latest lane removes `18` failure IDs and adds none. Removed IDs: `case-000157`, `case-000201`, `case-000239`, `case-000251`, `case-000278`, `case-000380`, `case-000393`, `case-000509`, `case-000549`, `case-000572`, `case-000601`, `case-000620`, `case-000696`, `case-000711`, `case-000747`, `case-000890`, `case-000912`, and `case-000983`.

Agent classification: the latest 1000-case residual set is narrow annotation-only/refinalization output drift with validating outputs, and generated `case-000251` is no longer the active residual in this lane. This is not final signoff or broad refinalization/nondefaultable closure: the required dedicated `10000` aggregate has not been rerun successfully after the latest fixes, the final four-lane pass signoff is open, full `moon test` has not been rerun in this latest classification-only slice, and pass-local performance evidence remains open.

## 2026-06-30 fresh partial 10000 aggregate after exact-null-arm fix

A follow-up freshness slice reran local validation before trying to scale the dedicated profile again:

- `moon test src/passes` — `3713/3713` passed.
- `moon test` — `7098/7098` passed.
- `moon build --target native --release src/cmd` — finished with no work; actual binary path remains `_build/native/release/build/cmd/cmd.exe`.

The required dedicated aggregate was then attempted with the post-exact-null-arm binary:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

The command timed out after `2400s` before writing `result.json`, so it is not signoff. Partial evidence from `cases.jsonl`:

- Completed case records: `9707` (`caseIndex` `1..9707`; the tail `293` cases did not complete before timeout).
- Status counts: `8748` `match`, `959` `mismatch`.
- Selected profiles: straight-line `4152`, tee-control `2826`, effect-order `2729`.
- All `959` failure directories were selected from `simplify-locals-nostructure-effect-order`.

Classifier output is stored at `.tmp/slns-genvalid-all-10000-after-exact-ref-null-arm-fresh-partial-result-type-classification.txt`:

- `934/959` partial residuals become identical after erasing only structured-control result annotations.
- `25` residuals remain non-annotation: `24` show EH `try_table` result/unreachable-debris/refinalization spelling drift, and `case-008144-gen-valid` shows function type-index/call_ref type reference spelling plus exact-if drift.
- `wasm-tools validate --features all` accepted all `3836` residual artifacts (`binaryen.wasm`, `starshine.wasm`, `binaryen.raw.wasm`, and `starshine.raw.wasm` for each failure dir).
- There were no missing WAT cases in the classifier input.

Agent classification: this partial lane confirms the first 1000 cases are not enough to close the scaled residual set. The `107/107` 1000-lane annotation-only classification remains true for that lane, but the longer partial 10000 run exposes additional validating non-annotation EH/refinalization and type-index/call_ref output drift. Treat these as open parity gaps pending reduction or stronger semantic classification, not as accepted safe drift. The incomplete `10000` lane also keeps the throughput/performance blocker open; final four-lane signoff and pass-local performance evidence remain open.

## 2026-06-30 live const-then `catch_all_ref` single-arm fix

The fresh partial 10000 classifier exposed `case-001740-gen-valid` as one of the scaled non-annotation EH residuals. Reducing that case showed a shape not covered by the earlier dropped-block, dead-if-arm, live-block, or both-arm `catch_all_ref` fixes: a live result-typed `if` has a constant `then` arm containing a no-normal `catch_all_ref` `try_table`, while the opposite arm provides `ref.null exn`. A same-function `ref.func; local.set; local.get; drop` simplification trigger makes Binaryen `version_130` run the same refinalization-style cleanup and void only the no-normal live `then` arm.

Binaryen probe: `.tmp/slns-eh-probes/case1740-live-then-refinalization.wat`.

```sh
wasm-opt --all-features --simplify-locals-nostructure -S .tmp/slns-eh-probes/case1740-live-then-refinalization.wat -o .tmp/slns-eh-probes/case1740-live-then-refinalization.opt.wat
```

Binaryen output keeps the surrounding value block/if, removes the `try_table` result from the no-normal `then` arm, and does not rewrite the shape without the refinalization trigger. The red-first Starshine test `simplify-locals-nostructure canonicalizes live const-then catch_all_ref if after refinalization trigger` initially failed with a result-typed no-normal `try_table`; after the fix it passes. The implementation deliberately stays inside the same narrow lowered no-structure refinalization cleanup family: it canonicalizes the single live arm only when the opposite arm is not another no-normal `catch_all_ref` arm, and it wraps top-level tails around the rewritten `if` locally so the catch target does not force a whole-function result block. This preserves the existing no-refinalization and broad-live-block boundaries.

Validation and evidence:

- Focused red/green filter `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*live const-then catch_all_ref*'` failed before implementation and passed after.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*catch_all_ref*'` — `5/5` passed.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — `57/57` passed.
- `moon fmt` — passed.
- `moon test src/passes` — `3714/3714` passed.
- `moon test` — `7099/7099` passed.
- `moon build --target native --release src/cmd` — passed with pre-existing unused-function warnings; native binary path remains `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-1000-after-single-arm-catchall --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` — compared `1000/1000`, normalized `893`, cleanup-normalized `0`, mismatches `107`, validation/generator/property/command failures `0`, selected profiles straight-line `423`, tee-control `276`, effect-order `301`, Binaryen cache `1000/0`.
- `bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-partial10000-after-single-arm-catchall --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` — replayed `959/959` stale partial-10000 mismatch inputs; normalized compare still reports `959` raw mismatches because the harness does not erase structured-control result annotations.
- Classifier `.tmp/slns-replay-partial10000-after-single-arm-catchall-result-type-classification.txt` — `936/959` replay residuals become identical after erasing structured-control result annotations, `23` remain non-annotation, and all `3836` replay residual wasm artifacts validate with `wasm-tools validate --features all`. Compared to the prior partial classifier, `case-001740-gen-valid` and `case-008369-gen-valid` move into the annotation-only class; `case-008144-gen-valid` plus `22` EH/refinalization residuals remain non-annotation.

This is meaningful scaled-residual reduction, but it is not signoff. The replay uses inputs from a timed-out partial lane with no `result.json`, the completed 1000 aggregate is unchanged at `107` annotation-only mismatches, and `23` partial-10000 non-annotation residuals plus throughput/performance remain open. The next slices should reduce another representative non-annotation residual, with `case-001895-gen-valid` / `case-001994-gen-valid` for EH drift or `case-008144-gen-valid` for type-index/call_ref spelling as the best starting points.

## 2026-07-01 partial-10000 `catch_ref` dead-else representative classification

This slice inspected representative stale partial-10000 replay residuals `case-001895-gen-valid` and `case-001994-gen-valid` from `.tmp/pass-fuzz-slns-replay-partial10000-after-single-arm-catchall`. They remain non-annotation after erasing structured-control result annotations because Binaryen keeps a generated-context dead-`else` `catch_ref` no-normal `try_table` result-typed, while Starshine emits a void `try_table` followed by explicit `unreachable`.

Evidence:

- `case-001895`: `.tmp/pass-fuzz-slns-replay-partial10000-after-single-arm-catchall/failures/case-001895-gen-valid/` shows Binaryen preserving `(try_table (result exnref) (catch_ref ...))` inside the dead `else`, while Starshine prints `(try_table (catch_ref ...))` plus `unreachable`. Re-running local Binaryen `wasm-opt version 130 (version_130)` over the saved `input.wasm` reproduces Binaryen's result-typed generated output.
- `case-001994`: same family, but the block is a `call_ref` operand; Binaryen preserves the result-typed `catch_ref` try_table and Starshine prints void-plus-unreachable.
- Smaller probes under `.tmp/slns-eh-probes/` clarify but do not close the discriminator: `case1895-dead-arm-asymmetry.wat` shows no-refinalization dead-arm shapes stay result-typed; `case1895-dead-arm-asymmetry-reftrigger.wat` and `case1895-exactish-catchref.wat` show a same-function local refinalization trigger may make Binaryen void the try_table, but without Starshine's explicit unreachable debris.
- Added focused boundary coverage in `src/passes/simplify_locals_nostructure_test.mbt`: `simplify-locals-nostructure keeps dead else catch_ref if without local refinalization trigger` and `simplify-locals-nostructure keeps dead else catch_ref if only later direct call_ref is refinalized`. These are green boundary tests, not red-first fixes; the direct-lib reduced form did not reproduce the full generated call/call_ref operand mismatch.

Validation for this classification slice:

- `wasm-opt --all-features --simplify-locals-nostructure -S .tmp/slns-eh-probes/case1895-const-else-catchref.wat -o .tmp/slns-eh-probes/case1895-const-else-catchref.opt.wat` — Binaryen voided the smaller refinalized probe without explicit unreachable.
- `wasm-opt --all-features --simplify-locals-nostructure -S .tmp/pass-fuzz-slns-replay-partial10000-after-single-arm-catchall/failures/case-001895-gen-valid/input.wasm -o .tmp/slns-eh-probes/case001895-rerun.opt.wat` — reproduced the generated result-typed Binaryen shape.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*dead else catch_ref*'` — `2/2` passed.
- `moon fmt` — passed.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — `59/59` passed.

No code fix, aggregate rerun, replay rerun, completed `10000` lane, final four-lane signoff, or performance measurement landed in this slice. Agent classification: `case-001895` / `case-001994` remain open parity gaps in the EH/refinalization bucket, not accepted drift and not validation-only safe. The stale replay remains `936/959` annotation-only with `23` non-annotation residuals.

## 2026-07-01 partial-10000 `case-008144` type-index / exact-if classification

This slice inspected the distinct non-EH stale partial-10000 replay residual `case-008144-gen-valid` from `.tmp/pass-fuzz-slns-replay-partial10000-after-single-arm-catchall`. A fresh one-case replay with the current native binary kept it non-annotation:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 8144 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case008144-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`.

Observed residual:

- Binaryen `version_130` output preserves source-order surviving function types (`$0` = void func, `$1` = imported eqref func), so `call_ref $0` names the void callee type and `ref.cast (ref $1)` names the eqref-returning imported function type.
- Starshine emits an equivalent reordered surviving type section (`$0` = eqref func, `$1` = void func), so the corresponding `call_ref` / `ref.cast` references are swapped. This part is type-index spelling/output-shape drift, not an instruction-order change.
- Binaryen narrows the earlier `if` feeding imported `table.set` from `(result funcref)` to `(result (ref null (exact $0)))`; Starshine leaves it as `(result funcref)`. The arms still produce `ref.func $0` or `ref.null nofunc`, both outputs validate, and the table accepts `funcref`, but this is still a Binaryen refinalization parity gap rather than a Starshine win.

Binaryen probes under `.tmp/slns-type-probes/` clarify the trigger:

- `case008144-no-trigger-if.wat` stays `(result funcref)`.
- `case008144-direct-callref-no-local-trigger.wat` also stays `(result funcref)`, so an already-direct `ref.func; call_ref` is not enough.
- `case008144-import-func-exact-if.wat` narrows to `(ref null (exact $ft))` when the same function contains a `ref.func; local.set; local.get; call_ref` simplification trigger, even with an imported function before the defined callee.

Added focused direct-lib boundary coverage in `src/passes/simplify_locals_nostructure_test.mbt`: `simplify-locals-nostructure refinalizes table-set if after direct call_ref local`. It includes an imported function before the defined callee and asserts the exact nullable function type plus rewritten exact `ref.null` arm. This test passed immediately, so it is boundary coverage/classification evidence, not a red-first implementation fix, and it does not reproduce the full generated `case-008144` residual.

Validation for this slice:

- `moon build --target native --release src/cmd` — no work.
- One-case replay above — still `1/1` mismatch, zero failures.
- `wasm-opt --all-features --simplify-locals-nostructure -S .tmp/slns-type-probes/case008144-no-trigger-if.wat -o .tmp/slns-type-probes/case008144-no-trigger-if.opt.wat` — no exact narrowing.
- `wasm-opt --all-features --simplify-locals-nostructure -S .tmp/slns-type-probes/case008144-direct-callref-no-local-trigger.wat -o .tmp/slns-type-probes/case008144-direct-callref-no-local-trigger.opt.wat` — no exact narrowing.
- `wasm-opt --all-features --simplify-locals-nostructure -S .tmp/slns-type-probes/case008144-import-func-exact-if.wat -o .tmp/slns-type-probes/case008144-import-func-exact-if.opt.wat` — exact narrowing reproduced in the smaller trigger probe.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*direct call_ref local*'` — `1/1` passed after fixing fixture construction.
- `moon fmt` — passed.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — `60/60` passed.

Agent classification: `case-008144` is a narrow type-index/type-refinement output-shape parity gap. It is not a true semantic mismatch based on the inspected Wasm values/types, but it is also not closed as accepted drift or a Starshine win because Starshine has no measured benefit and still misses Binaryen's exact-refinalization spelling in the generated context. The stale partial replay remains `936/959` annotation-only with `23` non-annotation residuals.

## 2026-07-01 partial-10000 `case-002342` call_ref / catch_all_ref block-placement classification

This slice inspected another stale partial-10000 replay residual, `case-002342-gen-valid`, from `.tmp/pass-fuzz-slns-replay-partial10000-after-single-arm-catchall`. A fresh one-case replay with the current native binary shows the residual is still open:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 2342 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case002342-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. `wasm-tools validate --features all` accepted the fresh `binaryen.wasm`, `starshine.wasm`, `binaryen.raw.wasm`, and `starshine.raw.wasm` artifacts.

Observed residual:

- The case is in the EH/refinalization bucket, not the `case-008144` type-index bucket.
- Binaryen keeps the no-normal `catch_all_ref` cleanup local to the `call_ref` operand by wrapping the operand in `(block $block (result exnref) ...)`, retargeting the `catch_all_ref` to that block, and voiding the `try_table` with explicit `unreachable` after the throw.
- Starshine wraps the whole function body in a result `exnref` block and lets the `call_ref` operand use the surrounding function wrapper label. That validates, but it is broader output-shape drift and not a measured Starshine win.
- Binaryen also narrows nearby `funcref` table-set `if` annotations to `nullfuncref`; Starshine leaves them as `funcref` in this generated context.
- Fresh artifact sizes are equal after normalized emission (`binaryen.wasm` `643B`, `starshine.wasm` `643B`) but Starshine raw output is larger (`starshine.raw.wasm` `677B` vs Binaryen raw `643B`), so this slice does not justify accepting the drift as a size/performance win.

Binaryen probes added under `.tmp/slns-eh-probes/`:

- `case2342-callref-catchall-callarg-min.wat` / `.opt.wat`: without a local-call_ref simplification trigger, Binaryen keeps the call_ref operand block but preserves the result-typed `try_table`.
- `case2342-callref-catchall-callarg-refinalize-trigger.wat` / `.opt.wat`: adding a same-function `ref.func; local.set; local.get; call_ref` trigger makes Binaryen narrow the surrounding `if` and void the operand `try_table` inside the local block.
- A Starshine CLI probe on the triggered binary still does not match Binaryen's local operand block/refinalization spelling; it printed a validating shape that keeps the result-typed try_table in a wrapper block.

No red-first Starshine behavior test or code fix landed in this slice. The public WAT fixture path remains awkward for generated `call_ref` neighborhoods, and a focused direct-lib/generated-context reduction is still needed before changing behavior. Agent classification: `case-002342` is a narrow EH block-placement/refinalization output-shape parity gap. It is not a true semantic mismatch based on validated Wasm artifacts, but it is also not accepted drift or a Starshine win because there is no measured benefit and Starshine's raw output is larger. The stale partial replay remains `936/959` annotation-only with `23` non-annotation residuals; required completed `10000`, final four-lane signoff, and pass-local performance remain open.

## 2026-07-01 partial-10000 `case-003158` call_ref / catch_all_ref else-arm classification

This slice inspected another stale partial-10000 replay residual, `case-003158-gen-valid`, from `.tmp/pass-fuzz-slns-replay-partial10000-after-single-arm-catchall`. A fresh one-case replay with the current native binary shows the residual is still open:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 3158 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case003158-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. `wasm-tools validate --features all` accepted the fresh `binaryen.wasm`, `starshine.wasm`, `binaryen.raw.wasm`, and `starshine.raw.wasm` artifacts.

Observed residual:

- The case is in the EH/refinalization bucket, not the `case-008144` type-index bucket.
- Binaryen narrows surrounding `externref` / `anyref` / `exnref` annotations to nullable bottom forms where the arms only produce null.
- In the `call_ref` operand, Binaryen wraps the argument in a local `(block $block (result exnref) ...)`, voids the no-normal `catch_all_ref` `try_table`, retargets the catch to the block, and leaves explicit `unreachable` after the throw.
- Starshine keeps broader annotations and preserves a result-typed `try_table` in a wrapper block, so the output is not annotation-only.
- Fresh artifact sizes do not establish a Starshine win: normalized Binaryen is `727B`, normalized Starshine is `726B`, but raw Starshine is larger (`766B` vs Binaryen `727B`).

Binaryen probes added under `.tmp/slns-eh-probes/`:

- `case3158-callref-catchall-else-no-trigger.wat` / `.opt.wat`: without a local-call_ref simplification trigger, Binaryen keeps the call_ref operand block and preserves the result-typed `try_table`.
- `case3158-callref-catchall-else-refinalize-trigger.wat` / `.opt.wat`: adding a same-function `ref.func; local.set; local.get; call_ref` trigger makes Binaryen narrow the surrounding exnref annotations and void the operand `try_table` inside the local block.
- A Starshine CLI probe on the triggered binary validates but still keeps a result-typed `try_table` in a wrapper block, so it does not match Binaryen's localized operand-block/refinalization spelling.

No red-first Starshine behavior test or code fix landed in this slice. The generated context still needs a focused direct-lib reduction or a deliberate evidence-backed policy before changing behavior. Agent classification: `case-003158` is a narrow EH block-placement/refinalization output-shape parity gap in the same broad bucket as `case-002342`, but with an else-arm `catch_all_ref` call_ref operand shape plus annotation drift. It is not a true semantic mismatch based on validated Wasm artifacts, but it is also not accepted drift or a Starshine win because there is no measured benefit and Starshine's raw output is larger. The stale partial replay remains `936/959` annotation-only with `23` non-annotation residuals; required completed `10000`, final four-lane signoff, and pass-local performance remain open.

## 2026-07-01 partial-10000 `case-002945` dead-then `catch_ref` call-argument classification

This slice inspected another stale partial-10000 replay residual, `case-002945-gen-valid`, from `.tmp/pass-fuzz-slns-replay-partial10000-after-single-arm-catchall`. A fresh one-case replay with the current native binary shows the residual is still open:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 2945 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case002945-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. `wasm-tools validate --features all` accepted the fresh `binaryen.wasm`, `starshine.wasm`, `binaryen.raw.wasm`, and `starshine.raw.wasm` artifacts.

Observed residual:

- The case is in the EH/refinalization bucket, not the `case-008144` type-index bucket and not the `case-002342` / `case-003158` `catch_all_ref` call_ref operand-localization subfamily.
- The mismatch occurs in a `call` argument where an `i32.const 0` dead `then` arm contains a no-normal `catch_ref` `try_table`; the opposite arm produces an `exnref` value.
- Binaryen keeps the dead-arm `try_table` result-typed in the generated call-argument context. Starshine emits a void `try_table` followed by explicit `unreachable`, so the output is not annotation-only.
- Fresh artifact sizes do not establish a Starshine win: normalized Binaryen is `573B`, normalized Starshine is `574B`, and raw Starshine is larger (`608B` vs Binaryen `573B`).

Binaryen probes added under `.tmp/slns-eh-probes/`:

- `case2945-callarg-dead-then-catchref-no-trigger.wat` / `.opt.wat`: without a local-call_ref simplification trigger, Binaryen keeps the call-argument dead-arm `catch_ref` `try_table` result-typed.
- `case2945-callarg-dead-then-catchref-direct-callref-after.wat` / `.opt.wat`: an already-direct later `call_ref` through a `ref.func` block still keeps the result-typed dead-arm `try_table`; a Starshine CLI probe on this reduced form also keeps the result-typed spelling, so the reduced form does not reproduce the full generated mismatch.
- `case2945-callarg-dead-then-catchref-refinalize-trigger.wat` / `.opt.wat`: adding a same-function `ref.func; local.set; local.get; call_ref` trigger makes Binaryen narrow the surrounding `if` to `nullexnref` and void the dead-arm `try_table` without Starshine's generated-context extra debris.

No red-first Starshine behavior test or code fix landed in this slice. The reduced no-trigger/direct-call_ref probes pass the current Starshine boundary, so a generated-context or direct-lib reduction is still needed before changing behavior safely. Agent classification: `case-002945` is an open generated call-argument EH result/refinalization parity gap in the same broad `catch_ref` dead-arm bucket as `case-001895` / `case-001994`, but with a dead `then` arm and fresh size evidence against accepting Starshine's spelling as a win. It is not a true semantic mismatch based on validated Wasm artifacts, but it is also not accepted drift or validation-only safe. The stale partial replay remains `936/959` annotation-only with `23` non-annotation residuals; required completed `10000`, final four-lane signoff, and pass-local performance remain open.

## 2026-07-01 partial-10000 `case-004065` both-arm `catch_all_ref` call_ref operand classification

This slice inspected another stale partial-10000 replay residual, `case-004065-gen-valid`, from `.tmp/pass-fuzz-slns-replay-partial10000-after-single-arm-catchall`. A fresh one-case replay with the current native binary shows the residual is still open:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 4065 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case004065-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. Fresh validation accepted `binaryen.wasm`, `starshine.wasm`, `binaryen.raw.wasm`, and `starshine.raw.wasm` with `wasm-tools validate --features all`.

The fresh residual is another generated EH/refinalization output-shape gap. In the main generated function, Binaryen localizes a both-arm no-normal `catch_all_ref` cleanup inside the generated `call_ref` operand block and voids both `try_table`s under the same-function `ref.func; local.set; local.get; call_ref` refinalization trigger. Starshine keeps/result-prints a broader result-typed operand spelling in the full generated case. A secondary function also shows nearby `catch_ref` narrowing/refinalization annotation drift, but the both-arm `catch_all_ref` call_ref operand is the clearest non-annotation difference.

Fresh size evidence does not justify accepting the drift as a Starshine win:

- normalized Binaryen `624B`, normalized Starshine `618B`;
- raw Binaryen `624B`, raw Starshine `633B`.

Reduced probes added under `.tmp/slns-eh-probes/`:

- `case4065-callarg-botharms-catchall-no-trigger.wat` / `.opt.wat`: without a local-call_ref refinalization trigger, Binaryen keeps the generated call_ref operand `catch_all_ref` try_tables result-typed.
- `case4065-callarg-botharms-catchall-direct-callref-before.wat` / `.opt.wat`: an already-direct preceding `call_ref` through `ref.func` also keeps the operand try_tables result-typed.
- `case4065-callarg-botharms-catchall-refinalize-trigger.wat` / `.opt.wat`: adding `ref.func; local.set; local.get; call_ref` makes Binaryen void the operand try_tables and narrow the enclosing block to `(ref exn)`. A current Starshine CLI probe on the same reduced trigger form validates and also narrows the enclosing block, but it still leaves explicit `unreachable` debris and does not fully reproduce the full generated broader result-typed spelling.

No red-first Starshine behavior test or code fix landed in this slice. The public WAT fixture path remains awkward for the exact generated `call_ref` neighborhood, and the reduced probe does not fully reproduce the generated Starshine shape. Agent classification: `case-004065` is an open generated-context both-arm `catch_all_ref` EH block-placement/refinalization parity gap in the same broad `call_ref` operand bucket as `case-002342` / `case-003158`, but with both arms using `catch_all_ref` in a generated operand. It is not a true semantic mismatch based on validated Wasm artifacts, but it is not accepted drift or a Starshine win because raw Starshine output is larger and no performance/downstream benefit is measured. The stale partial replay remains `936/959` annotation-only with `23` non-annotation residuals; no required completed `10000`, final four-lane signoff, or pass-local performance run was executed.

## 2026-07-01 partial-10000 `case-004556` tail `catch_all_ref` reduced fix, generated residual still open

This slice inspected another stale partial-10000 replay residual, `case-004556-gen-valid`, from `.tmp/pass-fuzz-slns-replay-partial10000-after-single-arm-catchall`. A fresh one-case replay with the then-current native binary showed the residual was still open:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 4556 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case004556-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. Fresh validation accepted `binaryen.wasm`, `starshine.wasm`, `binaryen.raw.wasm`, and `starshine.raw.wasm` with `wasm-tools validate --features all`. Size evidence did not justify accepting Starshine drift: normalized Binaryen `501B`, normalized Starshine `499B`, raw Binaryen `501B`, raw Starshine `515B`.

The generated residual is a tail no-normal `catch_all_ref` result/refinalization gap. Binaryen narrows the enclosing block to `(ref exn)`, voids the tail `try_table`, and leaves explicit `unreachable`; Starshine originally kept a nullable `exnref` block and result-typed tail `try_table`.

Reduced probes under `.tmp/slns-eh-probes/`:

- `case4556-tail-catchall-refinalize-trigger.wat` / `.opt.wat`: with a same-function `ref.func; local.set; local.get; drop` refinalization trigger and a prefix statement before the tail no-normal `catch_all_ref` try_table, Binaryen voids the try_table and narrows the block. Current Starshine originally reproduced the reduced mismatch by keeping the result-typed try_table.
- `case4556-tail-catchall-direct-callref-trigger.wat` / `.opt.wat`: an already-direct `ref.func; call_ref` does **not** trigger Binaryen refinalization; Binaryen keeps the tail try_table result-typed. This kept the fix tied to the existing local-refinalization discriminator rather than broad already-direct call_ref spelling.

A red-first public WAT test `simplify-locals-nostructure canonicalizes refinalized tail catch_all_ref block` failed before the fix with a nonvoid no-normal try_table in the reduced tail block. The lowered SLNS no-normal try_table canonicalizer now handles prefix-plus-tail `catch_all_ref` blocks only in the refinalization context and only when the catch targets the current block label. Focused validation:

- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*tail catch_all_ref*'` — failed red before implementation, then passed `1/1` after the fix.
- `moon fmt` — passed.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*catch_all_ref*'` — passed `6/6`.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — passed `61/61`.
- `moon build --target native --release src/cmd` — passed with pre-existing unused-function warnings.
- `.tmp/pass-fuzz-slns-genvalid-all-1000-after-tail-catchall` — compared `1000/1000`, normalized `893`, mismatches `107`, cleanup-normalized `0`, validation/generator/property/command failures `0`, selected profiles straight-line `423`, tee-control `276`, effect-order `301`, Binaryen cache `1000/0`.

The reduced subcase fix did **not** close the generated residual:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 4556 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case004556-after-tail-catchall --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`. In the generated replay, Starshine still keeps nullable/result-typed spelling for the relevant tail block, so the broader generated-context refinalization signal remains missing.

A replay of all stale partial-10000 mismatches after the reduced fix also did not reduce the stale non-annotation set:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-partial10000-after-tail-catchall --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: replayed `959/959`, normalized `0`, mismatches `959`, validation/generator/property/command failures `0`, Binaryen cache `959/0`. Classifier `.tmp/slns-replay-partial10000-after-tail-catchall-result-type-classification.txt` still finds `936/959` annotation-only and the same `23` non-annotation cases as the post-single-arm replay: `case-001895`, `001994`, `002342`, `002945`, `003158`, `004065`, `004556`, `004933`, `005508`, `005558`, `005696`, `005987`, `006618`, `007144`, `007321`, `007606`, `007639`, `007797`, `007981`, `008144`, `008372`, `009315`, and `009494`. A validation loop accepted all `3836` replay residual raw/canonical Binaryen and Starshine wasm artifacts.

Agent classification: the reduced `case-004556` tail `catch_all_ref` subcase is now covered and fixed, but generated `case-004556` remains an open EH/refinalization parity gap. It is not a true semantic mismatch based on validating Wasm artifacts, but it is not accepted drift or a Starshine win because raw Starshine output is larger and the stale partial non-annotation set did not shrink. The required completed `10000`, final four-lane signoff, and pass-local performance target remain open.


## 2026-07-01 partial-10000 `case-004933` function-tail `catch_all_ref` classification

This slice inspected another stale partial-10000 replay residual, `case-004933-gen-valid`, from `.tmp/pass-fuzz-slns-replay-partial10000-after-tail-catchall`. A fresh one-case replay with the current native binary shows the residual is still open:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 4933 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case004933-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. Fresh validation accepted `binaryen.wasm`, `starshine.wasm`, `binaryen.raw.wasm`, and `starshine.raw.wasm` with `wasm-tools validate --features all`.

The residual is a generated function-tail `catch_all_ref` result/refinalization gap related to, but not identical with, the `case-004556` tail block bucket:

- The relevant generated function ends in a no-normal `catch_all_ref` `try_table` after local traffic and a same-function `ref.func; local.set; local.get; call_ref` refinalization trigger.
- Binaryen wraps the function result in a non-null `(ref exn)` block, voids the tail `try_table`, retargets the catch to the block, and leaves explicit `unreachable`.
- Starshine keeps a nullable `exnref` wrapper and result-typed tail `try_table` in the generated case, so the mismatch is not annotation-only.
- Fresh size evidence does not justify accepting Starshine drift as a win: normalized Binaryen `683B`, normalized Starshine `681B`; raw Binaryen `683B`, raw Starshine `699B`.

Reduced probes added under `.tmp/slns-eh-probes/`:

- `case4933-function-tail-catchall-no-trigger.wat` / `.binaryen.wat` / `.starshine.wat`: without a local-refinalization trigger, both Binaryen and Starshine keep the function-tail try_table result-typed.
- `case4933-function-tail-catchall-already-direct-callref.wat` and `case4933-function-tail-catchall-already-direct-with-nop.wat`: an already-direct `ref.func; call_ref` shape still keeps the result-typed tail try_table, preserving the discriminator.
- `case4933-function-tail-catchall-refinalize-trigger.wat` and `case4933-function-tail-catchall-exact-callref-trigger.wat`: local-refinalization trigger shapes already make current Starshine and Binaryen agree on the reduced function-tail voiding, including an exact-local `call_ref` trigger.
- `case4933-function-tail-fullprefix.wat`: a larger hand-reduced prefix with recursive call/drop, direct `call_ref`, and a tail `catch_all_ref` also matches between current Starshine and Binaryen.

No red-first behavior test or code fix landed because the reduced function-tail trigger forms already pass; they do not reproduce the full generated mismatch. The likely remaining blocker is generated-context refinalization signal/placement rather than the simple function-tail rule itself. Agent classification: `case-004933` is an open generated-context function-tail `catch_all_ref` EH/refinalization parity gap, not a true semantic mismatch based on validated Wasm artifacts, but also not accepted drift or a Starshine win because raw Starshine output is larger and no performance/downstream benefit is measured. The stale partial replay remains `936/959` annotation-only with `23` non-annotation residuals; no required completed `10000`, final four-lane signoff, or pass-local performance run was executed.

## 2026-07-01 partial-10000 `case-005508` function-tail `catch_ref` reduced fix

This slice inspected stale partial-10000 replay residual `case-005508-gen-valid`, the `catch_ref` sibling of the generated function-tail EH/refinalization bucket.

Fresh pre-fix one-case replay:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 5508 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case005508-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. `wasm-tools validate --features all` accepted `binaryen.wasm`, `starshine.wasm`, `binaryen.raw.wasm`, and `starshine.raw.wasm`. Fresh sizes did not justify accepting Starshine drift as a win: normalized Binaryen `519B`, normalized Starshine `515B`, raw Binaryen `519B`, raw Starshine `536B`.

The generated pre-fix residual: Binaryen wraps the function result in a non-null `(ref exn)` block, voids the no-normal tail `catch_ref` `try_table`, and leaves explicit `unreachable`; Starshine kept a nullable `exnref` result and result-typed tail `try_table`. Reduced probes under `.tmp/slns-eh-probes/case5508-function-tail-catchref-*` show the same refinalization discriminator as the catch_all tail buckets: no-trigger forms keep the result-typed tail try_table, while adding a same-function `ref.func; local.set; local.get; drop` trigger makes Binaryen choose the voided function-tail form.

Red-first coverage:

- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure canonicalizes refinalized function-tail catch_ref`

The focused test failed before implementation with a nonvoid no-normal `try_table`. The lowered SLNS no-normal try_table canonicalizer now wraps function-tail current-label `catch_ref` try_tables in a non-null exn block, voids the try_table, and appends explicit `unreachable`, but only under the existing refinalization discriminator.

Focused validation:

- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*function-tail catch_ref*'` — failed red before implementation, then passed `1/1` after the fix.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*catch_all_ref*'` — passed `6/6`, preserving the existing catch_all boundaries.
- `moon fmt` — passed.
- `moon build --target native --release src/cmd` — passed with pre-existing unused-function warnings.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — passed `62/62`.
- `moon info` — passed with pre-existing warnings.
- `moon test src/passes` — passed `3719/3719`.

Fresh generated replay after the fix:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 5508 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case005508-after-catchref-tail --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`. The remaining diff in `case-005508` is now annotation-only (`funcref` vs exact if result); the function-tail `catch_ref` EH shape matches.

Replay of all stale partial-10000 mismatch inputs after the fix:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-partial10000-after-catchref-tail --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: replayed `959/959`, normalized `0`, mismatches `959`, validation/generator/property/command failures `0`, Binaryen cache `959/0`. Classifier `.tmp/slns-replay-partial10000-after-catchref-tail-result-type-classification.txt` finds `939/959` annotation-only residuals and `20` non-annotation cases: `case-001895`, `001994`, `002342`, `002945`, `003158`, `004065`, `004556`, `004933`, `005696`, `005987`, `006618`, `007144`, `007321`, `007606`, `007639`, `007797`, `007981`, `008144`, `009315`, and `009494`. `case-005508`, `case-005558`, and `case-008372` moved into the annotation-only class. A validation loop accepted all `3836` replay residual raw/canonical Binaryen and Starshine wasm artifacts.

Agent classification: the reduced and generated `case-005508` function-tail `catch_ref` EH subcase is fixed to annotation-only drift, and the same code also moves two related stale partial residuals (`case-005558`, `case-008372`) into annotation-only. The replay is still not signoff because it reuses a stale timed-out partial lane with no `result.json`; the completed required `10000` aggregate, final four-lane signoff, and pass-local performance target remain open.

## 2026-07-01 Live `catch_ref` single-arm follow-up (`case-005696` classification, `case-005987` fix)

Fresh `case-005696` replay with the current native binary:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 5696 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case005696-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. All four residual artifacts (`binaryen.wasm`, `starshine.wasm`, `binaryen.raw.wasm`, `starshine.raw.wasm`) validate with `wasm-tools validate --features all`. Fresh sizes are normalized Binaryen/Starshine `658B`/`659B`, raw Binaryen/Starshine `658B`/`696B`, so this is not a Starshine win. Agent classification: `case-005696` is an open no-refinalization generated-context dead-else `catch_ref` gap where Binaryen keeps the no-normal `try_table` result-typed and Starshine emits a void `try_table` plus explicit `unreachable`.

Fresh `case-005987` replay before the fix:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 5987 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case005987-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. All four residual artifacts validated. Fresh sizes were normalized Binaryen/Starshine `637B`/`636B`, raw Binaryen/Starshine `637B`/`666B`; raw Starshine was larger, so the pre-fix drift was not a Starshine win. The residual is the live const-then `catch_ref` sibling of the earlier live single-arm `catch_all_ref` bucket: Binaryen voids the live no-normal `catch_ref` arm and leaves explicit `unreachable` when the same function has a `ref.func; local.set; local.get; call_ref` refinalization trigger, while Starshine kept the arm result-typed.

Red-first coverage:

```sh
moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*live const-then catch_ref*'
```

The test `simplify-locals-nostructure canonicalizes live const-then catch_ref if after refinalization trigger` failed before implementation because the optimized function still contained a nonvoid no-normal `try_table`. The lowered SLNS no-normal try_table canonicalizer now lets the refinalization-gated live-arm cleanup use tag-payload `catch_ref` as well as `catch_all_ref`, while still checking the opposite constant-dead arm and the existing refinalization discriminator.

Focused validation after the fix:

- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*live const-then catch_ref*'` — passed `1/1` after the fix.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*catch_ref*'` — passed `4/4`.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*catch_all_ref*'` — passed `6/6`.
- `moon fmt` — passed.
- `moon build --target native --release src/cmd` — passed with pre-existing warnings.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` — passed `63/63`.
- `moon info` — passed with pre-existing warnings.
- `moon test src/passes` — passed `3720/3720`.

Fresh `case-005987` generated replay after the fix:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 5987 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case005987-after-live-catchref --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. All four post-fix artifacts validated. Post-fix sizes are normalized Binaryen/Starshine `637B`/`637B`, raw Binaryen/Starshine `637B`/`667B`. The remaining `case-005987` diff is annotation-only after erasing structured-control result annotations.

Replay of all stale partial-10000 mismatch inputs after the fix:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-partial10000-after-live-catchref --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: replayed `959/959`, normalized `0`, mismatches `959`, validation/generator/property/command failures `0`, Binaryen cache `959/0`. Classifier `.tmp/slns-replay-partial10000-after-live-catchref-result-type-classification.txt` finds `942/959` annotation-only residuals and `17` non-annotation cases: `case-001895`, `001994`, `002342`, `002945`, `003158`, `004065`, `004556`, `004933`, `005696`, `007321`, `007606`, `007639`, `007797`, `007981`, `008144`, `009315`, and `009494`. `case-005987`, `case-006618`, and `case-007144` moved into the annotation-only class. A validation loop accepted all `3836` replay residual raw/canonical Binaryen and Starshine wasm artifacts.

Agent classification: the reduced and generated `case-005987` live single-arm `catch_ref` EH subcase is fixed to annotation-only drift, and the same code also moves two related stale partial residuals (`case-006618`, `case-007144`) into annotation-only. `case-005696` remains an open generated-context no-refinalization `catch_ref` parity gap. The replay is still not signoff because it reuses a stale timed-out partial lane with no `result.json`; the completed required `10000` aggregate, final four-lane signoff, and pass-local performance target remain open.

## 2026-07-01 partial-10000 `case-007321` and `case-007606` classification

This slice inspected two more stale partial-10000 non-annotation residuals with the current native binary.

Fresh `case-007321` replay:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 7321 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case007321-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. All four residual artifacts validate with `wasm-tools validate --features all`. Fresh sizes are normalized Binaryen/Starshine `531B`/`530B`, raw Binaryen/Starshine `531B`/`545B`, so this is not a Starshine raw-size win. Agent classification: `case-007321` is an open generated nested call-operand EH/refinalization gap. It combines annotation-only ref spellings with a non-annotation `catch_all_ref` dead-arm/no-normal `try_table` shape: Binaryen voids the dead inner `catch_all_ref` arm and leaves explicit `unreachable`, while Starshine keeps the dead arm result-typed inside a broader wrapper. This is related to the generated `catch_all_ref` operand/block-placement bucket, not an accepted validation-only drift.

Fresh `case-007606` replay:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 7606 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case007606-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. All four residual artifacts validate with `wasm-tools validate --features all`. Fresh sizes are normalized Binaryen/Starshine `597B`/`595B`, raw Binaryen/Starshine `597B`/`622B`, so this is not a Starshine raw-size win. Agent classification: `case-007606` joins the open generated function-tail `catch_all_ref` EH/refinalization bucket already represented by `case-004933`: Binaryen wraps the function result in a non-null `(ref exn)` block, voids the tail no-normal `catch_all_ref` try_table, and appends explicit `unreachable`, while Starshine keeps a nullable/result-typed tail spelling in the generated case. The current reduced function-tail local-refinalization probes already match, so no new red-first implementable fixture or code fix landed in this slice.

No aggregate replay, completed `10000`, final four-lane signoff, or performance lane was run. The stale partial replay remains `.tmp/pass-fuzz-slns-replay-partial10000-after-live-catchref` with `942/959` annotation-only and `17` non-annotation residuals; this slice classified two of those residuals but did not reduce the count.

## 2026-07-01 partial-10000 `case-007639` and `case-007797` classification

This slice inspected two more stale partial-10000 non-annotation residuals with the current native binary. It did not change code.

Fresh `case-007639` replay:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 7639 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case007639-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. All four residual artifacts validate with `wasm-tools validate --features all`. Fresh sizes are normalized Binaryen/Starshine `528B`/`534B`, raw Binaryen/Starshine `528B`/`568B`, so this is not a Starshine raw-size win.

Agent classification: `case-007639` is an open generated imported-call operand/local-directization EH gap. Binaryen voids a mixed `catch_all_ref` / `catch_ref` no-normal `if` inside an imported-call operand and directizes nearby `ref.func` / `call_ref` local traffic, while Starshine keeps broader local traffic and result-typed EH spelling. A reduced public WAT probe for just the mixed-arm EH shape was already green in this workspace, so no red-first implementable fixture or code fix landed; the remaining generated context includes broader local cleanup/directization/block-placement behavior and remains open.

Fresh `case-007797` replay:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 7797 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case007797-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. All four residual artifacts validate with `wasm-tools validate --features all`. Fresh sizes are normalized Binaryen/Starshine `504B`/`500B`, raw Binaryen/Starshine `504B`/`518B`, so this is not a Starshine raw-size win.

Agent classification: `case-007797` joins the open generated function-tail `catch_all_ref` EH/refinalization bucket already represented by `case-004933` and `case-007606`: Binaryen wraps the function result in a non-null `(ref exn)` block, voids the tail no-normal `catch_all_ref` `try_table`, and appends explicit `unreachable`, while Starshine keeps nullable/result-typed tail spelling plus table-set if annotation drift. Current reduced function-tail local-refinalization probes already match, so no new implementable reduced fixture appeared in this slice.

A temporary reduced public WAT test for the mixed-arm `case-007639` EH shape was tried and passed immediately (`moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*mixed catch_all_ref catch_ref*'` reported `1/1`); it was removed rather than kept as a green-only no-op behavior test. No aggregate replay, stale partial replay rerun, completed `10000`, final four-lane signoff, or performance lane was run. The stale partial replay remains `.tmp/pass-fuzz-slns-replay-partial10000-after-live-catchref` with `942/959` annotation-only and `17` non-annotation residuals; this slice classified two more of those residuals but did not reduce the count.


## 2026-07-01 partial-10000 `case-007981`, `case-009315`, and `case-009494` classification

This slice inspected the remaining previously unclassified stale partial-10000 non-annotation residuals with the current native binary. It did not change code.

Fresh `case-007981` replay:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 7981 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case007981-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. All four residual artifacts validate with `wasm-tools validate --features all`. Fresh sizes are normalized Binaryen/Starshine `712B`/`708B`, raw Binaryen/Starshine `712B`/`737B`, so this is not a Starshine raw-size win. Agent classification: `case-007981` joins the generated mixed `catch_all_ref` / `catch_ref` call_ref-operand EH/refinalization bucket. Binaryen voids both no-normal arms inside a non-null `(ref exn)` block and appends unreachable debris, while Starshine keeps the call_ref operand block/result EH as nullable `exnref`. A temporary public WAT reduction using `call_ref` syntax was parser-blocked (`expected ')'`) and removed rather than kept.

Fresh `case-009315` replay:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 9315 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case009315-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. All four residual artifacts validate with `wasm-tools validate --features all`. Fresh sizes are normalized Binaryen/Starshine `579B`/`585B`, raw Binaryen/Starshine `579B`/`592B`, so this is not a Starshine size win. Agent classification: `case-009315` broadens the same mixed `catch_ref` / `catch_all_ref` call-operand bucket with surrounding local cleanup/directization and `nullref`/`anyref` annotation drift. Binaryen voids the mixed no-normal EH arms in the call operand and directizes nearby `ref.func` call_ref traffic, while Starshine keeps broader local traffic and result-typed EH spelling.

Fresh `case-009494` replay:

```sh
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 9494 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case009494-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. All four residual artifacts validate with `wasm-tools validate --features all`. Fresh sizes are normalized Binaryen/Starshine `626B`/`625B`, raw Binaryen/Starshine `626B`/`657B`, so this is not a Starshine raw-size win. Agent classification: `case-009494` combines annotation drift with a generated imported-call single-arm `catch_all_ref` block. Binaryen uses `nullexnref`, voids the no-normal `catch_all_ref` arm, and leaves the opposite `ref.null noexn` arm; Starshine keeps the `if`/`try_table` result-typed as broader `exnref`.

No aggregate replay, stale partial replay rerun, completed `10000`, final four-lane signoff, or performance lane was run. The stale partial replay remains `.tmp/pass-fuzz-slns-replay-partial10000-after-live-catchref` with `942/959` annotation-only and `17` non-annotation residuals; this slice classified three more residuals but did not reduce the count.

## 2026-07-01 `case-009494` dead-then `catch_all_ref` reduced fix

This slice converted one subcase of the previously classified `case-009494-gen-valid` imported-call operand residual into red-first coverage and a narrow fix. It does not complete the scaled audit or signoff.

The new public WAT regression is `simplify-locals-nostructure canonicalizes dead then catch_all_ref if after refinalization trigger` in `src/passes/simplify_locals_nostructure_test.mbt`. It models a same-function `ref.func; local.set; local.get; drop` refinalization trigger followed by an imported call whose `exnref` operand is a block containing a constant-false `if`; the dead `then` arm is a no-normal `catch_all_ref` `try_table`, and the live `else` arm is `ref.null exn`. The test failed before implementation because Starshine only handled the live-then/opposite-dead single-arm `catch_all_ref` direction.

The fix in `src/passes/pass_manager.mbt` keeps the refinalization discriminator but canonicalizes whichever single `if` arm can be voided when the opposite arm cannot, rather than only the prior live-then shape. It also separates single-arm `catch_all_ref` label preservation from the existing both-arm outer-label retargeting: applying the both-arm retarget to generated `case-009494` caused `skip-invalid-lower reason=writeback-validate:catch_all_ref label must expect exnref`, so the single-arm helper now preserves the catch target while the both-arm helper still retargets as before.

Validation and replay evidence:

```sh
moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*dead then catch_all_ref*'
moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*catch_all_ref*'
moon test --target native src/passes/simplify_locals_nostructure_test.mbt
moon test --target native src/passes/pass_manager_wbtest.mbt --filter '*simplify-locals-nostructure lowered cleanup*'
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 9494 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case009494-after-dead-then-label-fix --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-1000-after-dead-then-catchall --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 500 --keep-going-after-command-failures
```

Results: the red-first focused test passes; focused `*catch_all_ref*` passes `7/7`; focused SLNS passes `64/64`; focused lowered-cleanup white-box passes `3/3`; `moon fmt` and the native `src/cmd` rebuild pass with pre-existing warnings. Fresh generated `case-009494` replay still reports `1/1` raw mismatch with zero validation/generator/property/command failures, but the EH instruction drift is reduced to structured-control result annotation (`exnref` vs Binaryen `nullexnref`). All four fresh generated residual artifacts validate with `wasm-tools validate --features all`. Fresh sizes for that replay are canonical Binaryen/Starshine `626B`/`626B` and raw Binaryen/Starshine `626B`/`658B`, so this is not a raw Starshine win. The completed 1000-case aggregate remains unchanged at `1000/1000` compared, `893` normalized, `107` mismatches, zero validation/generator/property/command failures, selected profiles straight-line `423`, tee-control `276`, effect-order `301`, Binaryen cache `1000/0`.

No stale 959-case replay/classifier was rerun, no completed `10000` dedicated aggregate result was produced, no final four-lane signoff was run, and no performance lane was run. Therefore the official stale partial count remains `942/959` annotation-only and `17` non-annotation residuals until a fresh replay/classifier proves that `case-009494` (and any duplicates) moved into the annotation-only class.

## 2026-07-01 stale partial replay refresh after dead-then `catch_all_ref`

This slice reran the stale partial-10000 mismatch replay/classifier after the `case-009494` dead-then `catch_all_ref` reduced fix. This remains stale partial evidence because the source lane `.tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh` timed out before writing `result.json`; it is not the required completed `10000` dedicated aggregate and not final signoff.

Commands:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-partial10000-after-dead-then-catchall --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Results:

- `moon build --target native --release src/cmd` — passed with no work.
- `.tmp/pass-fuzz-slns-replay-partial10000-after-dead-then-catchall` — replayed `959/959` stale timed-out partial mismatch inputs, normalized `0`, mismatches `959`, validation/generator/property/command failures `0`, Binaryen cache `959/0`.
- Classifier `.tmp/slns-replay-partial10000-after-dead-then-catchall-result-type-classification.txt` — `946/959` residuals become identical after erasing structured-control result annotations; `13` remain non-annotation; all `3836` replay residual wasm artifacts validate with `wasm-tools validate --features all`.

Compared with the previous stale classifier `.tmp/slns-replay-partial10000-after-live-catchref-result-type-classification.txt` (`942/959` annotation-only, `17` non-annotation), `case-002342-gen-valid`, `case-003158-gen-valid`, `case-007321-gen-valid`, and `case-009494-gen-valid` moved into the annotation-only class. The remaining stale non-annotation residuals are `case-001895-gen-valid`, `case-001994-gen-valid`, `case-002945-gen-valid`, `case-004065-gen-valid`, `case-004556-gen-valid`, `case-004933-gen-valid`, `case-005696-gen-valid`, `case-007606-gen-valid`, `case-007639-gen-valid`, `case-007797-gen-valid`, `case-007981-gen-valid`, `case-008144-gen-valid`, and `case-009315-gen-valid`.

Agent classification: this is meaningful scaled residual reduction on stale partial evidence. It does not close the audit because the required completed dedicated `10000` aggregate still has no `result.json`, final four-lane signoff and performance remain open, and the remaining `13` stale non-annotation residuals need reduction, source-backed classification, or accepted narrow deferral.

## 2026-07-01 current recheck of three remaining stale residuals

This slice reran three current one-case replays from the remaining stale non-annotation set after the dead-then `catch_all_ref` replay refresh. It did not change Starshine code and does not reduce the `13` stale non-annotation residual count.

Commands:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 2945 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case002945-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 4065 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case004065-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 4556 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case004556-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Results:

- `moon build --target native --release src/cmd` — passed with no work.
- `case-002945-gen-valid` — compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. All four raw/canonical artifacts validate. Sizes: normalized Binaryen/Starshine `573B`/`574B`, raw Binaryen/Starshine `573B`/`608B`.
- `case-004065-gen-valid` — compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. All four raw/canonical artifacts validate. Sizes: normalized Binaryen/Starshine `624B`/`618B`, raw Binaryen/Starshine `624B`/`633B`.
- `case-004556-gen-valid` — compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. All four raw/canonical artifacts validate. Sizes: normalized Binaryen/Starshine `501B`/`499B`, raw Binaryen/Starshine `501B`/`515B`.

Scratch summary: `.tmp/slns-recheck-cases-002945-004065-004556-current.txt`.

Agent classification: `case-002945` remains a generated dead-then `catch_ref` call-argument over-voiding gap where Binaryen keeps the no-normal `try_table` result-typed and Starshine emits void `try_table` plus explicit `unreachable`. `case-004065` remains a generated both-arm `catch_all_ref` call_ref-operand block-placement/refinalization gap. `case-004556` remains a generated tail `catch_all_ref` block gap despite the reduced tail subcase fix. All three have raw size against Starshine, so none should be accepted as a Starshine win. A quick public-WAT dead-then `catch_ref` no-refinalization boundary passed immediately and was removed rather than kept as a green no-op test because it did not reproduce the generated `case-002945` context.

No focused Moon test beyond that removed green probe, aggregate replay, completed `10000`, final four-lane signoff, or performance lane was run.

## 2026-07-01 current recheck of `case-001895` and `case-001994`

This slice reran two representative dead-else `catch_ref` residuals from the remaining stale non-annotation set against the current native binary. It did not change Starshine code and does not reduce the stale `13` non-annotation residual count.

Commands:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 1895 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case001895-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 1994 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case001994-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Results:

- `moon build --target native --release src/cmd` — passed with no work.
- `case-001895-gen-valid` — compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. All four raw/canonical artifacts validate. Sizes: normalized Binaryen/Starshine `512B`/`513B`, raw Binaryen/Starshine `512B`/`530B`.
- `case-001994-gen-valid` — compared `1/1`, normalized `0`, mismatches `1`, validation/generator/property/command failures `0`, Binaryen cache `1/0`. All four raw/canonical artifacts validate. Sizes: normalized Binaryen/Starshine `674B`/`673B`, raw Binaryen/Starshine `674B`/`704B`.

Scratch summary: `.tmp/slns-recheck-cases-001895-001994-current.txt`.

Agent classification: `case-001895` remains a generated imported-call argument dead-else `catch_ref` no-normal `try_table` gap where Binaryen keeps the result-typed try_table, while Starshine emits a void try_table plus explicit `unreachable`. `case-001994` remains the related generated `call_ref` operand context with nearby exact-if/call_ref annotation drift plus the same void-plus-`unreachable` over-canonicalization. Both are open parity gaps rather than accepted drift: all artifacts validate, but validation alone is not semantic proof, and raw size is against Starshine for both.

No focused test, code fix, aggregate replay, completed `10000`, final four-lane signoff, or performance lane was run.

## 2026-07-01 mixed catch_ref/catch_all_ref operand fix for case-007981

This slice targeted the stale partial-10000 non-annotation residual `case-007981-gen-valid`, a generated call_ref operand where Binaryen voids both no-normal EH arms inside a localized non-null `(ref exn)` block and Starshine previously kept result-typed nullable `exnref` spelling.

Red-first coverage:

```sh
moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*mixed catch_all_ref catch_ref*'
```

The public WAT fixture `simplify-locals-nostructure canonicalizes mixed catch_all_ref catch_ref if after refinalization trigger` first failed on the explicit-block mixed-arm shape, then passed after implementation. A temporary closer public fixture using flat `call_ref` syntax was parser-blocked (`expected ')'`), so the kept fixture avoids that parser-blocked generated spelling while preserving the mixed ref-payload EH behavior.

Implementation notes: lowered SLNS now canonicalizes both-arm no-normal ref-payload `try_table` arms uniformly for `catch_all_ref` and `catch_ref`, retargets zero-depth ref-payload catches to the enclosing non-null exn wrapper, and post-processes refinalization-context stack operands of the form `i32.const; if` into the same localized Binaryen-style wrapper so generated call operands can validate without consuming a condition across a block boundary.

Validation and replay:

```sh
moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*mixed catch_all_ref catch_ref*'
moon test --target native src/passes/simplify_locals_nostructure_test.mbt
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 7981 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case007981-after-mixed-ref-operands --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index 9315 --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-case009315-after-mixed-ref-operands --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Results: focused red/green passed; focused SLNS file passed `65/65`; native `src/cmd` built with pre-existing warnings. Fresh `case-007981` replay now compares `1/1` with `1` normalized match, zero mismatches, zero validation/generator/property/command failures, and Binaryen cache `1/0`. Fresh sibling `case-009315` replay still compares `1/1` with `1` mismatch and zero failures; all four raw/canonical residual artifacts validate, and the remaining diff includes mixed EH block/refinalization drift plus `nullref`/`anyref` annotation drift.

Agent classification: this is a real one-case residual fix for current `case-007981` evidence and a partial sibling classification update, not signoff. The stale partial replay/classifier has not been rerun, so the documented stale `13` non-annotation count remains unchanged until refreshed. No completed `10000` dedicated lane, final four-lane signoff, or pass-local performance lane was run.

## 2026-07-01 stale partial replay refresh after mixed-arm operand fix

This slice refreshed the stale partial-10000 replay/classifier after the mixed `catch_all_ref`/`catch_ref` operand fix that normalized current `case-007981`. The source lane remains `.tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh`, which timed out after `2400s` before `result.json`; this is therefore replay/classification evidence only, not the required completed dedicated `10000` aggregate.

Commands:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-partial10000-after-mixed-ref-operands --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Results:

- Native `src/cmd` build passed with pre-existing warnings.
- `.tmp/pass-fuzz-slns-replay-partial10000-after-mixed-ref-operands` replayed `959/959` stale timed-out partial mismatch inputs, normalized `1` (`case-007981`), left `958` raw mismatches, and had zero validation/generator/property/command failures with Binaryen cache `959/0`.
- Classifier `.tmp/slns-replay-partial10000-after-mixed-ref-operands-result-type-classification.txt` validates all `3832` remaining residual Binaryen/Starshine raw/canonical wasm artifacts and finds `947/958` residual mismatches become identical after erasing structured-control result annotations.
- Remaining non-annotation residuals: `case-001895-gen-valid`, `case-001994-gen-valid`, `case-002945-gen-valid`, `case-004556-gen-valid`, `case-004933-gen-valid`, `case-005696-gen-valid`, `case-007606-gen-valid`, `case-007639-gen-valid`, `case-007797-gen-valid`, `case-008144-gen-valid`, and `case-009315-gen-valid`.

Compared with `.tmp/slns-replay-partial10000-after-dead-then-catchall-result-type-classification.txt`, `case-007981` is no longer a residual because the normalized replay matches, and `case-004065` now classifies as annotation-only under the refreshed stale replay. This reduces the stale partial non-annotation set from `13` to `11`, but it does not close the audit: completed dedicated `10000`, regular GenValid `100000`, explicit wasm-smith `10000`, random all-profiles `10000`, and pass-local performance signoff remain open.

## Follow-up: reverse mixed `catch_ref`/`catch_all_ref` operand wrapper

A 2026-07-01 slice targeted stale partial-10000 residual `case-009315`, the reverse-arm sibling of the prior `case-007981` mixed `catch_all_ref`/`catch_ref` operand gap. A reduced public WAT probe in `src/passes/simplify_locals_nostructure_test.mbt` failed red-first: Starshine had already voided both no-normal ref-payload arms, but retained the enclosing operand as a nullable/result-typed exn block and result-typed `if`. Binaryen `version_130` instead prints a non-null `(ref exn)` operand block, void `if`, and explicit `unreachable` after the same-function `ref.func` local cleanup triggers refinalization.

Implementation in `src/passes/pass_manager.mbt` is intentionally narrow in the lowered SLNS cleanup path:

- `run_hot_pipeline_slns_lowered_canonicalize_no_normal_try_table_ref_payload_if_arm_body` now accepts already-voided ref-payload arms (`try_table` with void type plus `unreachable`) as eligible when building the Binaryen-shaped both-arm operand wrapper.
- The block-level no-normal canonicalizer now unwraps a single nested non-null exn block into the enclosing operand block, avoiding the previous nullable outer wrapper around a non-null inner block.

Validation and evidence:

- Red-first focused test: `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*reverse mixed catch_ref*'` failed before the implementation and passes after.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` passes `66/66`.
- `moon fmt` passes.
- `moon build --target native --release src/cmd` passes with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `moon test src/passes` passes `3723/3723`.
- Fresh generated replay `.tmp/pass-fuzz-slns-replay-case009315-after-reverse-mixed` still reports `1/1` raw mismatch with zero validation/generator/property/command failures, but inspection shows the mixed EH block-shape gap is gone; the remaining diff is structured result annotation drift (`nullref`/`anyref` around nearby if/br_on_cast blocks). All four residual artifacts validate.
- Refreshed stale partial replay `.tmp/pass-fuzz-slns-replay-partial10000-after-reverse-mixed` reuses the timed-out 10000 partial mismatch inputs and compares `959/959`, normalizes `1`, leaves `958` raw mismatches, and has zero validation/generator/property/command failures with Binaryen cache `959/0`.
- Classifier `.tmp/slns-replay-partial10000-after-reverse-mixed-result-type-classification.txt` validates all `3832` remaining residual raw/canonical artifacts and improves stale partial evidence to `949/958` annotation-only with `9` non-annotation residuals. `case-007639` and `case-009315` move into annotation-only compared with `.tmp/slns-replay-partial10000-after-mixed-ref-operands-result-type-classification.txt`.

This is not signoff: the replay uses stale inputs from a timed-out lane, no completed `10000` dedicated aggregate was produced, the full four-lane signoff matrix remains open, and pass-local performance remains unmeasured for this change.

## Follow-up: function-tail `catch_all_ref` wrapper

A 2026-07-01 slice targeted the generated function-tail `catch_all_ref` bucket left in the stale partial-10000 residual set: `case-004556`, `case-004933`, `case-007606`, and `case-007797`. The reduced public WAT fixture `simplify-locals-nostructure canonicalizes refinalized function-tail catch_all_ref` failed red-first because Starshine kept a result-typed no-normal current-label `catch_all_ref` `try_table` at function result position. Binaryen `version_130` wraps the function result in a non-null `(ref exn)` block, voids the tail `try_table`, and leaves explicit `unreachable` when the same-function `ref.func` local cleanup triggers refinalization.

Implementation in `src/passes/pass_manager.mbt` mirrors the existing function-tail `catch_ref` helper with a narrow `catch_all_ref` sibling: in a refinalization context, a function-tail no-normal `catch_all_ref` try_table targeting the current label is wrapped in a non-null exn block with a void `try_table` and explicit `unreachable`. The change does not broaden no-refinalization EH rewriting.

Validation and evidence:

- Red-first focused test: `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*function-tail catch_all_ref*'` failed before the implementation and passes after.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` passes `67/67`.
- `moon fmt` passes.
- `moon build --target native --release src/cmd` passes with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `moon test src/passes` passes `3724/3724`.
- Fresh one-case replays: `.tmp/pass-fuzz-slns-replay-case004556-after-function-tail-catchall` and `.tmp/pass-fuzz-slns-replay-case004933-after-function-tail-catchall` each compare `1/1` with `1` normalized match and zero failures. `.tmp/pass-fuzz-slns-replay-case007606-after-function-tail-catchall` and `.tmp/pass-fuzz-slns-replay-case007797-after-function-tail-catchall` still report raw mismatches with zero failures, but the remaining diffs are structured-control result annotation drift by inspection/classifier.
- Refreshed stale partial replay `.tmp/pass-fuzz-slns-replay-partial10000-after-function-tail-catchall` reuses the timed-out 10000 partial mismatch inputs and compares `959/959`, normalizes `3`, leaves `956` raw mismatches, and has zero validation/generator/property/command failures with Binaryen cache `959/0`.
- Classifier `.tmp/slns-replay-partial10000-after-function-tail-catchall-result-type-classification.txt` validates all `3824` remaining residual raw/canonical artifacts and improves stale partial evidence to `951/956` annotation-only with `5` non-annotation residuals. Compared with the reverse-mixed classifier, `case-004556` and `case-004933` normalize while `case-007606` and `case-007797` move into annotation-only.
- Remaining stale non-annotation residuals: `case-001895-gen-valid`, `case-001994-gen-valid`, `case-002945-gen-valid`, `case-005696-gen-valid`, and `case-008144-gen-valid`.

This is not signoff: the replay uses stale inputs from a timed-out lane, no completed `10000` dedicated aggregate was produced, the full four-lane signoff matrix remains open, and pass-local performance remains unmeasured for this change.

## Fresh five-residual replay refresh after function-tail fix

After the function-tail `catch_all_ref` fix reduced the stale partial replay to five non-annotation residual IDs, a follow-up classification-only slice rebuilt/checked the current native `src/cmd` binary and reran each remaining ID as a one-case replay:

```sh
moon build --target native --release src/cmd
for case in 1895 1994 2945 5696 8144; do
  padded=$(printf "%06d" "$case")
  bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --case-index "$case" --pass simplify-locals-nostructure --out-dir ".tmp/pass-fuzz-slns-replay-case${padded}-fresh-five-residuals" --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
 done
```

All five replays still compare `1/1` with one mismatch, zero validation/generator/property/command failures, and Binaryen cache `1/0`. Validation over `.tmp/pass-fuzz-slns-replay-case{001895,001994,002945,005696,008144}-fresh-five-residuals` accepts all twenty residual artifacts (`binaryen.wasm`, `starshine.wasm`, `binaryen.raw.wasm`, and `starshine.raw.wasm` for each case). Summary artifact `.tmp/slns-five-residuals-fresh-replay-summary.txt` records the relevant `try_table` / `call_ref` lines and sizes.

Classification remains unchanged:

- `case-001895`, `case-001994`, `case-002945`, and `case-005696` are generated `catch_ref` dead-arm/no-normal over-voiding residuals. Binaryen keeps the `catch_ref` `try_table` result-typed; Starshine emits a void `try_table` plus explicit `unreachable`.
- `case-008144` remains the distinct type-index/type-refinement/call_ref spelling residual.
- Raw size remains against Starshine for all five (`512B/530B`, `674B/704B`, `573B/608B`, `658B/696B`, and `479B/501B` raw Binaryen/Starshine bytes respectively), so none is accepted as a Starshine win.

A smaller direct-lib reduction attempt for the `case-005696` dead-else `catch_ref` call-operand shape was green and removed rather than kept as no-op coverage. This slice did not change code, did not reduce the residual count, and does not replace the timed-out `10000` lane, full four-lane signoff, or performance evidence.


## Follow-up: `case-008144` nested table-set exact-if current replay fix

A 2026-07-01 slice targeted the one non-EH residual left in the fresh five-residual replay set, `case-008144-gen-valid`. The generated shape differs from the earlier green direct-lib boundary because the `funcref` `if` feeding `table.set` wraps both arms in transparent funcref blocks (`block (result funcref) ...`) before an intervening imported call and a later same-function `ref.func; local.set; local.get; call_ref` cleanup trigger. Binaryen `version_130` refinalizes that table-set value to `(ref null (exact $ft))`; Starshine previously left it as `funcref`.

Red-first coverage and implementation:

- Added `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure refinalizes table-set if across intervening imported call` as a direct-lib fixture because public `call_ref` WAT remains awkward for generated spellings.
- The test failed before implementation with the optimized body still containing `if (RefType Null (AbsHeapType Func))` around the table-set value.
- `src/passes/pass_manager.mbt` now recognizes transparent single-root funcref `block` wrappers around `ref.func` / `ref.null func` arms while finding lowered SLNS exact-if targets, and rewrites those arms to direct `ref.func` / exact nullable `ref.null` when narrowing the if result. This keeps the existing exact-null-arm validation fix and avoids a broad refinalization rule.

Validation and evidence:

- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt --filter '*intervening imported call*'` passes `1/1` after failing red-first.
- `moon test --target native src/passes/pass_manager_wbtest.mbt --filter '*refinalizes ref.func null if result*'` passes `1/1`.
- `moon test --target native src/passes/simplify_locals_nostructure_test.mbt` passes `68/68`.
- `moon fmt` passes.
- `moon build --target native --release src/cmd` passes with pre-existing warnings.
- Fresh current replay `.tmp/pass-fuzz-slns-replay-case008144-after-nested-ref-func-if` compares `1/1`, normalized `1`, mismatches `0`, validation/generator/property/command failures `0`, and Binaryen cache `1/0`.

The stale partial replay/classifier was not rerun in that implementation slice. Therefore the last completed stale classifier at that point remained `.tmp/slns-replay-partial10000-after-function-tail-catchall-result-type-classification.txt` (`951/956` annotation-only, `5` non-annotation), but current one-case evidence removed `case-008144` from the freshly reproduced non-annotation set. The remaining current open residuals were the four generated `catch_ref` dead-arm/no-normal over-voiding cases: `case-001895`, `case-001994`, `case-002945`, and `case-005696`. This was not a completed `10000` dedicated lane, final four-lane signoff, or pass-local performance acceptance.

## Follow-up: stale partial replay refresh after `case-008144`

A later 2026-07-01 slice refreshed the stale partial replay/classifier with the current native binary after the nested table-set exact-if fix:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-genvalid-all-10000-after-exact-ref-null-arm-fresh --failure-status mismatch --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-replay-partial10000-after-nested-ref-func-if --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
python3 .tmp/slns-classify-result-annotations.py .tmp/pass-fuzz-slns-replay-partial10000-after-nested-ref-func-if .tmp/slns-replay-partial10000-after-nested-ref-func-if-result-type-classification.txt
```

Results:

- `moon build --target native --release src/cmd` reported no work.
- Replay `.tmp/pass-fuzz-slns-replay-partial10000-after-nested-ref-func-if` compared `959/959` stale timed-out partial mismatch inputs, normalized `62`, left `897` raw mismatches, and had zero validation/generator/property/command failures with Binaryen cache `959/0`.
- Classifier `.tmp/slns-replay-partial10000-after-nested-ref-func-if-result-type-classification.txt` validates all `3588` remaining residual raw/canonical artifacts and updates stale partial evidence to `893/897` annotation-only with `4` non-annotation residuals: `case-001895-gen-valid`, `case-001994-gen-valid`, `case-002945-gen-valid`, and `case-005696-gen-valid`.
- The replay normalizes more stale inputs than the prior function-tail refresh (`62` vs `3`), reflecting the current accumulated SLNS fixes on the stale input set. This is useful residual evidence only: it still reuses a timed-out partial lane that never wrote a `result.json` for the original 10000 attempt, so it is not completed dedicated `10000` signoff, final four-lane signoff, or pass-local performance acceptance.

## Follow-up: fresh four-residual `catch_ref` dead-arm classification

A subsequent 2026-07-01 classification-only slice refreshed current one-case evidence for the four non-annotation residuals left by `.tmp/slns-replay-partial10000-after-nested-ref-func-if-result-type-classification.txt`. Native `src/cmd` had no rebuild work, then each case was replayed from `.tmp/pass-fuzz-slns-replay-partial10000-after-nested-ref-func-if` with the current `_build/native/release/build/cmd/cmd.exe`:

```sh
moon build --target native --release src/cmd
for idx in 1895 1994 2945 5696; do
  padded=$(printf '%06d' "$idx")
  bun scripts/pass-fuzz-compare.ts --replay-failures-from .tmp/pass-fuzz-slns-replay-partial10000-after-nested-ref-func-if --failure-status mismatch --case-index "$idx" --pass simplify-locals-nostructure --out-dir ".tmp/pass-fuzz-slns-replay-case${padded}-fresh-dead-arm-catchref" --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 10 --keep-going-after-command-failures
 done
```

Each fresh one-case replay still compares `1/1`, normalizes `0`, reports one mismatch, and has zero validation/generator/property/command failures with Binaryen cache `1/0`. A validation loop accepted `input.wasm`, `binaryen.raw.wasm`, `binaryen.wasm`, `starshine.raw.wasm`, and `starshine.wasm` for all four cases. Local summary artifact `.tmp/slns-four-catchref-residuals-fresh-summary.md` records the side-by-side shapes and sizes.

| Case | Generated context | Binaryen `version_130` shape | Starshine shape | Raw bytes Binaryen/Starshine | Current classification |
| --- | --- | --- | --- | --- | --- |
| `case-001895-gen-valid` | imported-call argument, dead `else` arm | Keeps `try_table (result exnref) (catch_ref $tag$0 $block)`. | Emits void `try_table (catch_ref ...)` followed by `unreachable`. | `512/530` | Open generated `catch_ref` dead-arm/no-normal over-voiding parity gap. |
| `case-001994-gen-valid` | `call_ref` operand block, dead `else`, plus nearby annotation drift | Keeps `try_table (result exnref) (catch_ref $tag$0 $block)`. | Emits void `try_table (catch_ref ...)` followed by `unreachable`. | `674/704` | Open generated `catch_ref` dead-arm/no-normal over-voiding parity gap. |
| `case-002945-gen-valid` | direct call argument, dead `then` arm | Keeps `try_table (result exnref) (catch_ref $tag$0 $block)`. | Emits void `try_table (catch_ref ...)` followed by `unreachable`. | `573/608` | Open generated `catch_ref` dead-arm/no-normal over-voiding parity gap. |
| `case-005696-gen-valid` | generated call/call_ref neighborhood, dead `else` arm | Keeps `try_table (result exnref) (catch_ref $tag$0 $block)`. | Emits void `try_table (catch_ref ...)` followed by `unreachable`. | `658/696` | Open generated `catch_ref` dead-arm/no-normal over-voiding parity gap. |

The common discriminator is now sharper but still not an implementable red fixture: all four are generated-context `catch_ref` dead-arm/no-normal cases where Starshine over-voids relative to Binaryen. Smaller no-refinalization and already-direct-call_ref reductions tried so far keep the result-typed `try_table`; local-refinalization-trigger reductions can make Binaryen void a try_table but do not reproduce this exact generated over-voiding mismatch. Therefore the next fix should not broaden the existing EH canonicalizer. The blocked surface is the generated call/call_ref operand context: operand placement, refinalization proxy detection, typed catch-payload handling, or lowering entry-point selection need a faithful red fixture before code changes. The raw size evidence is against Starshine for every case, so none is accepted as a Starshine win. This slice changed no code and did not run a completed `10000` dedicated aggregate, final four-lane signoff, or pass-local performance lane.

## 2026-07-01 follow-up: dead `catch_ref` arm refinalization guard

A fresh reduction of the remaining `catch_ref` dead-arm bucket showed that the generated over-voiding was not tied to `call_ref` spelling. The minimal public WAT shape is ordinary local cleanup before a constant-dead `else` arm whose body is a no-normal `catch_ref` `try_table`: Binaryen `version_130` keeps the `try_table (result exnref)`, while Starshine had voided it and appended `unreachable` whenever the function had local cleanup. Red-first test `simplify-locals-nostructure keeps dead else catch_ref if only local cleanup happens` failed before the fix and now passes after lowered SLNS gates dead-arm `catch_ref` canonicalization on the existing refinalization discriminator.

Validation/evidence from the slice:

- Focused `*catch_ref*` passes `7/7`; focused SLNS file passes `69/69`; `moon fmt`, `moon test src/passes` (`3726/3726`), and native `src/cmd` build pass with pre-existing warnings.
- Fresh one-case replays after the fix: `case-001895` and `case-002945` normalize; `case-001994` and `case-005696` remain raw mismatches but their diffs are structured result annotation-only.
- Full stale partial replay `.tmp/pass-fuzz-slns-replay-partial10000-after-dead-catchref-refctx-guard-full959` compares `959/959`, normalizes `64`, leaves `895` raw mismatches, and has zero validation/generator/property/command failures with Binaryen cache `959/0`. Classifier `.tmp/slns-replay-partial10000-after-dead-catchref-refctx-guard-full959-result-type-classification.txt` validates all `3580` residual artifacts and reports `895/895` annotation-only with `0` non-annotation residuals.
- Completed 1000 aggregate `.tmp/pass-fuzz-slns-genvalid-all-1000-after-dead-catchref-refctx-guard` compares `1000/1000`, normalizes `897`, leaves `103` raw mismatches, has zero failures, selected profiles `423/276/301`, Binaryen cache `1000/0`, and classifier `.tmp/slns-genvalid-all-1000-after-dead-catchref-refctx-guard-result-type-classification.txt` validates all `412` residual artifacts and reports `103/103` annotation-only.

This removes the currently known non-annotation stale partial residuals. It is not completed `10000` dedicated aggregate signoff, not the final four-lane signoff matrix, and not pass-local performance acceptance.

## 2026-07-01 completed dedicated aggregate after dead `catch_ref` refinalization guard

This slice reran the dedicated `simplify-locals-nostructure-all` GenValid aggregate after the dead `catch_ref` refinalization-discriminator fix removed the known stale partial non-annotation residuals. It used the current native binary path that exists in this worktree:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-10000-after-dead-catchref-refctx-guard-fresh --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
python3 .tmp/slns-classify-result-annotations.py .tmp/pass-fuzz-slns-genvalid-all-10000-after-dead-catchref-refctx-guard-fresh .tmp/slns-genvalid-all-10000-after-dead-catchref-refctx-guard-fresh-result-type-classification.txt
```

Results:

- Native `src/cmd` build: no work to do.
- Dedicated aggregate `.tmp/pass-fuzz-slns-genvalid-all-10000-after-dead-catchref-refctx-guard-fresh`: compared `10000/10000`, normalized `9069`, cleanup-normalized `0`, mismatches `931`, validation/generator/property/command failures `0`.
- Selected profiles: straight-line `4290`, tee-control `2885`, effect-order `2825`; all `931` mismatches selected effect-order.
- Cache counters: Binaryen `9758` hits / `242` misses; wasm-smith `0/0`; Binaryen failures `0/0`.
- Classifier `.tmp/slns-genvalid-all-10000-after-dead-catchref-refctx-guard-fresh-result-type-classification.txt`: validates all `3724` residual raw/canonical Binaryen and Starshine wasm artifacts and reports `931/931` annotation-only residuals with `0` non-annotation residuals.

Agent classification: the previously timed-out pass-specific dedicated aggregate now has a completed `result.json`. The residuals are currently classified as structured-control result-annotation-only output drift with validating artifacts, not instruction-order/local-traffic drift. This is not final pass closeout: the regular `100000` GenValid lane, explicit wasm-smith `10000` lane, random all-profiles `10000` lane, and pass-local performance target remain unrun.

## 2026-07-01 bounded pass-local timing probe after completed dedicated aggregate

A follow-up performance-prep slice ran a small timing-only probe over ten existing inputs from the completed dedicated aggregate: one normalized case (`case-000001`) plus the nine historical early annotation-only residual IDs (`case-000041`, `000043`, `000060`, `000069`, `000070`, `000082`, `000084`, `000092`, `000094`). This used `scripts/self-optimize-compare.ts`, so it records Starshine traced pass-local time and Binaryen `--debug` pass time, but it is only a tiny generated-input sample and not final performance acceptance.

Command shape:

```sh
rm -rf .tmp/slns-perf-probe-dedicated-10 && mkdir -p .tmp/slns-perf-probe-dedicated-10
for n in 1 41 43 60 69 70 82 84 92 94; do
  padded=$(printf '%06d' "$n")
  bun scripts/self-optimize-compare.ts \
    ".tmp/pass-fuzz-slns-genvalid-all-10000-after-dead-catchref-refctx-guard-fresh/inputs/gen-valid/gen-valid-$padded.wasm" \
    --starshine-bin _build/native/release/build/cmd/cmd.exe \
    --out-dir ".tmp/slns-perf-probe-dedicated-10/case-$padded" \
    --timing-only \
    --simplify-locals-nostructure
 done
```

Results:

| Case | Canonical wasm equal | Starshine wall ms | Binaryen wall ms | Starshine pass ms | Binaryen pass ms | Pass ratio |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `case-000001` | yes | `2.063` | `2.906` | `0.132` | `0.068` | `1.93x` |
| `case-000041` | no | `2.586` | `3.019` | `0.368` | `0.114` | `3.22x` |
| `case-000043` | no | `2.589` | `3.069` | `0.360` | `0.110` | `3.28x` |
| `case-000060` | no | `2.628` | `2.982` | `0.417` | `0.121` | `3.44x` |
| `case-000069` | no | `2.733` | `3.102` | `0.398` | `0.131` | `3.04x` |
| `case-000070` | no | `2.757` | `3.180` | `0.357` | `0.107` | `3.32x` |
| `case-000082` | no | `2.820` | `3.490` | `0.434` | `0.121` | `3.60x` |
| `case-000084` | no | `2.801` | `3.241` | `0.485` | `0.127` | `3.82x` |
| `case-000092` | no | `2.961` | `3.343` | `0.472` | `0.123` | `3.85x` |
| `case-000094` | no | `2.285` | `2.990` | `0.256` | `0.137` | `1.87x` |

Aggregate over this 10-input probe: Starshine whole-command wall time is faster on all ten cases (median `2.680ms` vs Binaryen `3.085ms`), but pass-local Starshine misses the ordinary `<= 2x Binaryen` floor on eight of ten cases. Median pass-local time is `0.383ms` Starshine vs `0.121ms` Binaryen, with a median pass ratio of `3.30x` and mean ratio `3.14x`. Treat this as the first concrete SLNS performance blocker signal after the dedicated aggregate became annotation-only, not as a final performance lane. Larger and more representative pass-local timing evidence remains required before pass closeout.

## 2026-07-01 broader bounded timing probe over 100 dedicated inputs

A follow-up slice broadened the tiny ten-input timing probe without claiming final performance acceptance. It sampled 100 existing completed dedicated-aggregate inputs: `gen-valid-000001`, then every 100th input through `gen-valid-009901`, and wrote per-case timing artifacts under `.tmp/slns-perf-probe-dedicated-100-even`. Summary artifact: `.tmp/slns-perf-probe-dedicated-100-even-summary.md`.

Command shape:

```sh
rm -rf .tmp/slns-perf-probe-dedicated-100-even && mkdir -p .tmp/slns-perf-probe-dedicated-100-even
for n in $(seq 1 100 9901); do
  padded=$(printf '%06d' "$n")
  bun scripts/self-optimize-compare.ts \
    ".tmp/pass-fuzz-slns-genvalid-all-10000-after-dead-catchref-refctx-guard-fresh/inputs/gen-valid/gen-valid-$padded.wasm" \
    --starshine-bin _build/native/release/build/cmd/cmd.exe \
    --out-dir ".tmp/slns-perf-probe-dedicated-100-even/case-$padded" \
    --timing-only \
    --simplify-locals-nostructure
 done
```

Results over the 100 sampled timing commands:

- All `100/100` commands completed.
- Raw wasm equality: `89/100`.
- Whole-command wall time: Starshine faster on `100/100`; median Starshine `1.978ms` vs Binaryen `2.890ms`, mean Starshine `2.110ms` vs Binaryen `3.177ms`.
- Pass-local floor (`starshine_time <= 2 * binaryen_time`): only `2/100` cases within the ordinary repo floor.
- Starshine pass-local time: min `0.120ms`, p25 `0.146ms`, median `0.189ms`, p75 `0.254ms`, max `0.649ms`, mean `0.233ms`.
- Binaryen pass-local time: min `0.046ms`, p25 `0.056ms`, median `0.060ms`, p75 `0.086ms`, max `0.137ms`, mean `0.072ms`.
- Pass-local ratio: min `1.95x`, p25 `2.56x`, median `3.18x`, p75 `3.59x`, max `5.67x`, mean `3.13x`.

Starshine trace-timer aggregation points mostly at repeated main pass cycles over small functions rather than lift/lower or whole-command wall:

- Median functions timed by `pass:simplify-locals-nostructure`: `3` (min `2`, max `4`, mean `2.69`).
- Median outer pass timer: `188.5us` (mean `233.1us`, max `649us`).
- Median `detail:simplify-locals:main-cycle`: `74.5us` (mean `99.5us`, max `281us`), median count `6`.
- Median `detail:simplify-locals:scan-root-region`: `32.0us` (mean `47.1us`, max `160us`), median count `6`.
- Median `detail:simplify-locals:dead-cleanup`: `10.0us` (mean `14.9us`, max `66us`), median count `6`.

Agent classification: this strengthens the performance blocker signal from the ten-input probe. Whole-command Starshine remains faster on these tiny generated inputs, but the pass-local `<=2x` floor is consistently missed. The likely near-term owner is repeated main-cycle/root-region scan work, with a possible measurement component from detail timer emission because those timers trace while the outer pass timer is still running. This is not final performance acceptance; representative larger timing and the remaining regular GenValid `100000`, explicit wasm-smith `10000`, and random all-profiles `10000` lanes remain open.

## 2026-07-01 redundant second-main-cycle fast path and timing rerun

A follow-up performance slice targeted the repeated main-cycle/root-region scan owner identified above. The focused invariant is narrow: if the first SLNS main/dead-cleanup pass makes no change and there is no first-cycle-deferred multi-use `local.set` work, then the no-structure pass does not need to force the historical second main/dead-cleanup scan before falling through to late cleanup / exit.

Red-first test:

- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure skips redundant second main cycle without deferred writes`
- Before implementation, the focused test failed with `2 != 1` because the fixture emitted two `detail:simplify-locals:main-cycle` timer events.
- After implementation, `simplify_locals_run_main_cycle` reports whether first-cycle multi-use local sets remain deferred; `simplify_locals_run_with_options` only continues to a second main cycle when there was a main/dead-cleanup change or actual deferred work.

Validation and bounded fuzz evidence:

- Focused red/green filter passed after implementation.
- Focused SLNS file: `moon test --package jtenner/starshine/passes --file simplify_locals_nostructure_test.mbt` passed `70/70`.
- `moon fmt` passed.
- `moon test src/passes` passed `3727/3727`.
- `moon build --target native --release src/cmd` passed with pre-existing unused-function warnings; actual binary path remains `_build/native/release/build/cmd/cmd.exe`.
- Completed aggregate smoke after the code change:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-1000-after-skip-redundant-main-cycle --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
python3 .tmp/slns-classify-result-annotations.py .tmp/pass-fuzz-slns-genvalid-all-1000-after-skip-redundant-main-cycle .tmp/slns-genvalid-all-1000-after-skip-redundant-main-cycle-result-type-classification.txt
```

Result: compared `1000/1000`, normalized `897`, left `103` raw mismatches, cleanup-normalized `0`, and had zero validation/generator/property/command failures. Binaryen cache was `1000/0`; wasm-smith cache was `0/0`. The classifier validates all `412` residual raw/canonical artifacts and finds `103/103` annotation-only with `0` non-annotation residuals.

The same 100-input timing sample was rerun under `.tmp/slns-perf-probe-dedicated-100-even-after-skip-redundant-main-cycle`; summary artifact: `.tmp/slns-perf-probe-dedicated-100-even-after-skip-redundant-main-cycle-summary.md`.

Results over the rerun timing sample:

- All `100/100` timing commands completed.
- Canonical wasm equal: `89/100`.
- Whole-command Starshine faster: `99/100`.
- Pass-local floor (`starshine_time <= 2 * binaryen_time`): `0/100` cases.
- Starshine pass-local time: median `0.1965ms`, mean `0.2402ms`, p75 `0.2725ms`, max `0.6270ms`.
- Binaryen pass-local time: median `0.0601ms`, mean `0.0721ms`, p75 `0.0918ms`, max `0.1359ms`.
- Pass-local ratio: median `3.27x`, mean `3.25x`, p75 `3.56x`, max `5.46x`.
- Trace aggregation still points to repeated main-cycle/root-region work on the generated sample: median `detail:simplify-locals:main-cycle` total `80.5us`, median `scan-root-region` total `34.0us`, median event count `6` for both.

Agent classification: the fast path is a correct focused performance cleanup and is protected by a red-first perf-invariant test, but it does not close the generated-input performance blocker. The 100-input rerun is essentially unchanged/noisier relative to the previous 100-input timing probe and still misses the pass-local floor on every sampled case. Final performance acceptance remains open, as do the regular GenValid `100000`, explicit wasm-smith `10000`, and random all-profiles `10000` signoff lanes.

## 2026-07-01 changed/no-deferred first-cycle fast path and timing rerun

A follow-up performance slice tightened the previous fast path. The first attempt only skipped a forced second main/dead-cleanup scan when the first cycle made no changes and had no deferred multi-use local.set work. The 100-input timing rerun still showed a median `6` `main-cycle` / `scan-root-region` event count because common generated functions mutate during the first cycle but do not actually have deferred multi-use tee work.

New red-first test:

- `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure skips changed first-cycle follow-up without deferred writes`
- Before implementation, the focused filter failed with `2 != 1` because a straight-line single-use local sink still emitted two `detail:simplify-locals:main-cycle` timer events.
- After implementation, `simplify_locals_run_with_options` only forces the first-cycle follow-up when `simplify_locals_run_main_cycle` reports actual deferred multi-use local.set work. Mutating single-use cleanup/sinking still runs the same-cycle dead cleanup and then proceeds to structure-disabled late cleanup / exit without paying for another full root scan.

Validation and bounded fuzz evidence:

- Focused red/green filter passed after implementation.
- Focused SLNS file passed `71/71`.
- `moon fmt` passed.
- `moon test src/passes` passed `3728/3728`.
- `moon build --target native --release src/cmd` passed with pre-existing unused-function warnings; actual binary path remains `_build/native/release/build/cmd/cmd.exe`.
- Completed aggregate smoke after the code change:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-1000-after-skip-changed-no-deferred-cycle --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
python3 .tmp/slns-classify-result-annotations.py .tmp/pass-fuzz-slns-genvalid-all-1000-after-skip-changed-no-deferred-cycle .tmp/slns-genvalid-all-1000-after-skip-changed-no-deferred-cycle-result-type-classification.txt
```

Result: compared `1000/1000`, normalized `897`, left `103` raw mismatches, cleanup-normalized `0`, and had zero validation/generator/property/command failures. Binaryen cache was `1000/0`; wasm-smith cache was `0/0`. The classifier validates all `412` residual raw/canonical artifacts and finds `103/103` annotation-only with `0` non-annotation residuals.

The same 100-input timing sample was rerun under `.tmp/slns-perf-probe-dedicated-100-even-after-skip-changed-no-deferred-cycle`; summary artifact: `.tmp/slns-perf-probe-dedicated-100-even-after-skip-changed-no-deferred-cycle-summary.md`.

Results over the rerun timing sample:

- All `100/100` timing commands completed.
- Canonical wasm equal: `89/100`.
- Whole-command Starshine faster: `99/100`.
- Pass-local floor (`starshine_time <= 2 * binaryen_time`): `0/100` cases.
- Starshine pass-local time: median `0.1370ms`, mean `0.2006ms`, p75 `0.2513ms`, max `0.5260ms`.
- Binaryen pass-local time: median `0.0616ms`, mean `0.0751ms`, p75 `0.0909ms`, max `0.1699ms`.
- Pass-local ratio: median `2.22x`, mean `2.48x`, p75 `3.11x`, max `5.11x`.
- Trace aggregation now shows median `detail:simplify-locals:main-cycle` / `scan-root-region` event counts of `3`, down from the previous median `6`; median `main-cycle` total is `53.5us` and median `scan-root-region` total is `28.0us`.

Agent classification: the changed/no-deferred fast path is a real bounded performance improvement and preserves the latest 1000-case dedicated aggregate/classifier shape. It improves the sampled median pass ratio from the prior `3.27x` blocker signal to `2.22x`, but it still misses the pass-local floor on every sampled input. Final performance acceptance remains open, as do the regular GenValid `100000`, explicit wasm-smith `10000`, and random all-profiles `10000` signoff lanes.

## 2026-07-01 100-largest-input timing probe

A measurement-only follow-up checked whether the improved even-spaced timing sample was hiding worse behavior on less-tiny generated modules. It selected the 100 largest input wasm files from the completed dedicated aggregate `.tmp/pass-fuzz-slns-genvalid-all-10000-after-dead-catchref-refctx-guard-fresh/inputs/gen-valid` and reran timing-only direct SLNS comparisons with the same native binary.

Command shape:

```sh
OUT=.tmp/slns-perf-probe-dedicated-100-largest-after-skip-changed-no-deferred-cycle
python3 - <<'PY' > "$OUT/selected-inputs.txt"
from pathlib import Path
inputs=Path('.tmp/pass-fuzz-slns-genvalid-all-10000-after-dead-catchref-refctx-guard-fresh/inputs/gen-valid')
items=sorted(inputs.glob('gen-valid-*.wasm'), key=lambda p:(p.stat().st_size, p.name), reverse=True)[:100]
for p in items:
    print(p)
PY
while IFS= read -r input; do
  base=$(basename "$input" .wasm)
  bun scripts/self-optimize-compare.ts "$input" --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir "$OUT/$base" --timing-only --simplify-locals-nostructure >/dev/null || exit 1
done < "$OUT/selected-inputs.txt"
```

Summary artifact: `.tmp/slns-perf-probe-dedicated-100-largest-after-skip-changed-no-deferred-cycle-summary.md`.

Results:

- Selected input sizes: median `767B`, mean `775.34B`, min selected `746B`, max `910B`.
- Cases completed: `100/100`.
- Canonical wasm equal: `18/100`.
- Whole-command Starshine faster: `55/100`.
- Pass-local floor (`starshine_time <= 2 * binaryen_time`): `0/100` cases.
- Starshine pass-local time: median `0.5110ms`, mean `0.5288ms`, p75 `0.5480ms`, max `0.6890ms`.
- Binaryen pass-local time: median `0.1290ms`, mean `0.1355ms`, p75 `0.1381ms`, max `0.2021ms`.
- Pass-local ratio: median `3.94x`, mean `3.95x`, p75 `4.25x`, max `5.49x`.
- Trace counts: median `4` `pass:simplify-locals-nostructure` events and median `12` `detail:simplify-locals:main-cycle`, `scan-root-region`, and `dead-cleanup` events per module.

Agent classification: this is not a code fix and not performance acceptance. It strengthens the performance blocker: on the largest generated inputs from the already completed dedicated aggregate, the current fast-path binary is much farther from the pass-local floor than on the even-spaced sample (`3.94x` median vs `2.22x`). The trace counts suggest these selected modules have about three main/dead scan cycles per function. The next performance owner should measure whether a post-deferred second cycle can prove stability without a third full root/dead scan, and should separate guard/preflight scan cost outside the current detail timers from the scan-region/dead-cleanup cost inside them.

## 2026-07-01 random all-profiles broad-lane probe

A follow-up slice attempted the required random all-profiles GenValid lane for final SLNS closeout. This does not complete the lane: the required-size run timed out, and the bounded completed run exposes an open embedded-control `local.tee` parity blocker.

Commands:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass simplify-locals-nostructure --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-slns-genvalid-random-all-profiles-10000-seed5555 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5555 --pass simplify-locals-nostructure --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-slns-genvalid-random-all-profiles-1000-seed5555 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 500 --keep-going-after-command-failures
python3 .tmp/slns-classify-result-annotations.py .tmp/pass-fuzz-slns-genvalid-random-all-profiles-1000-seed5555 .tmp/slns-random-all-profiles-1000-seed5555-result-type-classification.txt
```

Results:

- Native `src/cmd` build reported no work.
- `.tmp/pass-fuzz-slns-genvalid-random-all-profiles-10000-seed5555` timed out after `2400s` before `result.json`. Partial `cases.jsonl` has `6168` records: `4897` matches and `1271` mismatches. Partial selected-profile counts are `ssa-nomerge-smoke` `1271`, `coverage-forced-portable` `1269`, `pass-fuzz-stress` `1258`, `binaryen-oracle-portable` `1191`, and `ssa-nomerge-parity` `1179`; all `1271` partial mismatches selected `ssa-nomerge-smoke`.
- `.tmp/pass-fuzz-slns-genvalid-random-all-profiles-1000-seed5555` completed: compared `1000/1000`, normalized `795`, left `205` raw mismatches, cleanup-normalized `0`, and had zero validation/generator/property/command failures. Cache counters were wasm-smith `0/0`, Binaryen `1000/0`, and Binaryen failures `0/0`.
- Completed 1000 selected-profile counts: `coverage-forced-portable` `215`, `ssa-nomerge-smoke` `205`, `pass-fuzz-stress` `205`, `ssa-nomerge-parity` `193`, and `binaryen-oracle-portable` `182`; all `205` mismatches selected `ssa-nomerge-smoke`.
- Classifier `.tmp/slns-random-all-profiles-1000-seed5555-result-type-classification.txt` validates all `820` residual raw/canonical Binaryen and Starshine wasm artifacts and reports `0/205` annotation-only, `205` non-annotation residuals.
- Size evidence is against accepting the drift as a Starshine win: Starshine raw output is larger in `205/205` residuals, with Starshine-minus-Binaryen raw delta median `47B` (mean `48.52B`, min `43B`, max `71B`); normalized Starshine output is exactly `28B` larger for all `205` residuals.
- Trace probes for representative residuals `case-000002`, `case-000003`, `case-000004`, `case-000009`, and `case-000011` all report `pass[simplify-locals-nostructure]:skip-hot reason=control-local-tee-hazard-noop`.

Agent classification: the broad random all-profiles lane is blocked by the documented embedded-control `local.tee` / HOT child-ownership guard. This is not a true semantic-mismatch claim because the residual artifacts validate and no runtime/property replay was run, but it is also not annotation-only and not an accepted Starshine win because Starshine is consistently size-larger and skips Binaryen-visible local cleanup around embedded `local.tee` shapes. The completed dedicated SLNS aggregate remains current, but final closeout still needs this random lane to complete without unclassified/non-annotation residuals, plus regular GenValid `100000`, explicit wasm-smith `10000`, and pass-local performance acceptance.

## Follow-up: random-all-profiles embedded-tee guard sweep

A later 2026-07-01 bounded classification slice expanded the random all-profiles `seed 0x5555` blocker evidence without changing code. The completed bounded random lane remains `.tmp/pass-fuzz-slns-genvalid-random-all-profiles-1000-seed5555`: `1000/1000` compared, `795` normalized, `205` raw mismatches, zero validation/generator/property/command failures, and all mismatches selected `ssa-nomerge-smoke`. Classifier `.tmp/slns-random-all-profiles-1000-seed5555-result-type-classification.txt` validates all `820` residual raw/canonical artifacts and reports `0/205` annotation-only.

The new sweep ran `_build/native/release/build/cmd/cmd.exe --tracing pass --simplify-locals-nostructure` over every failure dir from that result. Summary artifact `.tmp/slns-random-all-profiles-1000-seed5555-guard-trace-summary.md` records that all `205/205` residual cases exited successfully and hit `control-local-tee-hazard-noop`; the only other skip reason was `no-local-writes` on unaffected sibling functions (`822` occurrences). Per-case traces live under `.tmp/slns-random-all-profiles-1000-seed5555-all-guard-traces/`.

The same slice reduced a representative issue to `.tmp/slns-embedded-tee-unrelated-local.wat`:

```wat
(module
  (func (param i32) (local i32 i32)
    local.get 0
    if
      i32.const 7
      local.tee 1
      drop
    end
    i32.const 42
    local.set 2
    local.get 2
    drop))
```

Binaryen `version_130` with `--simplify-locals-nostructure` keeps the `if` boundary but removes the dropped embedded tee and unrelated local carrier, emitting `nop` plus `drop(i32.const 42)`. Starshine validates but reports `skip-hot reason=control-local-tee-hazard-noop` and leaves the function unchanged. Treat this as the current smallest documented reopening target for a future red-first fix: optimize unrelated root local traffic without deleting nested tee nodes in a way that violates HOT child ownership. No failing repo test was kept because no safe code fix landed in this slice.

This strengthens the classification of the random all-profiles blocker as an embedded-control `local.tee` / HOT child-ownership parity gap. It is not a true semantic-mismatch claim, not an accepted Starshine win, and not completed random-all-profiles `10000` signoff.

## Follow-up: embedded-tee root-only cleanup narrowing

A later 2026-07-01 implementation slice turned the minimal embedded-tee probe into red-first coverage and narrowed the whole-function skip. The new focused fixture `simplify-locals-nostructure optimizes unrelated root locals with embedded control tee` failed before implementation because Starshine left the unrelated root `local.set` / `local.get` carrier unchanged under `skip-hot reason=control-local-tee-hazard-noop`. The kept fix replaces the whole-function embedded-control tee skip in canonical SLNS and the no-tee sibling with a protected root-only main scan: structured-control regions containing embedded `local.tee` remain protected, while unrelated root-level local traffic may still be cleaned. A trace hook now reports `protect-hot reason=control-local-tee-hazard-root-only` for this narrowed path.

Validation and replay:

- Red-first focused test failed before implementation, then passed.
- Focused `*tee*` tests: `21/21` passed.
- Full focused SLNS file: `72/72` passed.
- `moon fmt` passed.
- `moon test src/passes` passed `3729/3729`.
- `moon build --target native --release src/cmd` passed with pre-existing unused-function warnings.
- `moon info` passed with pre-existing warnings; `git diff --check` passed.
- Direct replay: `_build/native/release/build/cmd/cmd.exe --tracing pass --simplify-locals-nostructure --out .tmp/slns-embedded-tee-unrelated-local.after-root-only.wasm .tmp/slns-embedded-tee-unrelated-local.wasm` reported `protect-hot reason=control-local-tee-hazard-root-only` and `done changed=true`. `wasm-tools validate --features all .tmp/slns-embedded-tee-unrelated-local.after-root-only.wasm` accepted the output. The printed `.tmp/slns-embedded-tee-unrelated-local.after-root-only.wat` keeps the `if` boundary, removes the local carrier, and emits `drop(i32.const 42)`.
- Refreshed pass-specific 1000 aggregate `.tmp/pass-fuzz-slns-genvalid-all-1000-after-embedded-tee-root-only` compared `1000/1000`, normalized `897`, left `103` raw mismatches, and had zero validation/generator/property/command failures with Binaryen cache `1000/0`. This matches the previous post-fast-path 1000 count; no classifier was rerun in this slice.
- Refreshed bounded random all-profiles lane `.tmp/pass-fuzz-slns-genvalid-random-all-profiles-1000-after-embedded-tee-root-only` compared `1000/1000`, normalized `795`, left `205` raw mismatches, and had zero validation/generator/property/command failures with Binaryen cache `1000/0`. Selected-profile counts remained `coverage-forced-portable` `215`, `ssa-nomerge-smoke` `205`, `pass-fuzz-stress` `205`, `ssa-nomerge-parity` `193`, and `binaryen-oracle-portable` `182`; all mismatches still selected `ssa-nomerge-smoke`.
- Fresh trace sweep `.tmp/slns-random-all-profiles-1000-after-embedded-tee-root-only-guard-traces/summary.json` ran the current binary over all `205` refreshed bounded random residual inputs. All commands exited `0`; all `205/205` residuals reported `protect-hot reason=control-local-tee-hazard-root-only`; all `205/205` reported `done changed=true`; no residual reported a `skip-hot` reason.

Agent classification: this slice fixes the reduced whole-function skip and proves unrelated root cleanup can run in the presence of an embedded-control dropped tee, but it does **not** close the broad random all-profiles residual family. The refreshed bounded random lane has the same `205` raw mismatches as before, all from `ssa-nomerge-smoke`, so the remaining generated diff still needs reduction/classification. Do not treat this as random all-profiles `10000` signoff, final four-lane signoff, or performance acceptance.

## Follow-up: embedded-tee protected root cycles

A later 2026-07-01 implementation slice narrowed the protected embedded-control tee path further. After the root-only scan fix, `case-000002` from the bounded random all-profiles lane still showed root-level deferred multi-use local carriers left behind because protected mode did not run Binaryen's later root cycle or dead cleanup. A new reduced probe `.tmp/slns-root-multiuse-embedded-tee.wat` captures the safe root subset: two root `local.set` / `local.get` / `drop` pairs around an embedded-control dropped `local.tee`. The red-first fixture `simplify-locals-nostructure optimizes deferred root locals with embedded control tee` failed before implementation with `local.set (Local 1)` / `local.get (Local 1)` still present.

Implementation: canonical SLNS and the no-tee sibling now run protected root main cycles plus root-only dead cleanup when an embedded-control tee is present. The structured-control child path remains protected by `protect-hot reason=control-local-tee-hazard-root-only`, while root-level deferred local cleanup can reach the same later-cycle shape as ordinary SLNS.

Validation and evidence:

- Red-first focused `*deferred root locals*` failed before implementation, then passed.
- Focused embedded-control tests: `2/2` passed.
- Focused `*tee*` tests: `22/22` passed.
- Full focused SLNS file: `73/73` passed.
- `moon fmt` passed.
- `moon test src/passes` passed `3730/3730`.
- `moon build --target native --release src/cmd` passed with pre-existing unused-function warnings.
- Direct replay: `_build/native/release/build/cmd/cmd.exe --tracing pass --simplify-locals-nostructure --out .tmp/slns-root-multiuse-embedded-tee.after-root-cycle.wasm .tmp/slns-root-multiuse-embedded-tee.wat`; `wasm-tools validate --features all` accepted the output, and printed WAT removes the root `Local 1` carriers.
- One-case replay `.tmp/pass-fuzz-slns-random-case000002-after-root-cycle` still mismatches `1/1` with zero failures, but the representative diff is narrowed to two instruction-shape gaps: Starshine keeps `local.set $2 (i32.const 20)` inside a dropped result `if` where Binaryen emits `nop`, and Starshine prints `drop(local.tee $3 (i32.const 120))` in the embedded `if` where Binaryen prints `local.set $3 (i32.const 120)`.
- Refreshed random all-profiles bounded lane `.tmp/pass-fuzz-slns-genvalid-random-all-profiles-1000-after-embedded-tee-root-cycles` compared `1000/1000`, normalized `795`, left `205` raw mismatches, and had zero validation/generator/property/command failures with Binaryen cache `1000/0`. All mismatches still selected `ssa-nomerge-smoke`.
- Fresh trace sweep `.tmp/slns-random-all-profiles-1000-after-embedded-tee-root-cycles-guard-traces/summary.json` reports `caseCount=205`, all commands exit `0`, `protectReasons.control-local-tee-hazard-root-only=205`, no skip reasons, and `changedTrue=205`.
- Validation summary `.tmp/slns-random-all-profiles-1000-after-embedded-tee-root-cycles-validation-summary.json` validates all `820` residual raw/canonical Binaryen and Starshine artifacts.
- Size evidence improved but still argues against accepting drift: Starshine raw output remains larger in `205/205` residuals; median raw delta is now `+8B` and normalized delta `+4B`, down from the pre-root-cycle `+47B` raw / `+28B` normalized deltas.
- Refreshed dedicated aggregate `.tmp/pass-fuzz-slns-genvalid-all-1000-after-embedded-tee-root-cycles` compared `1000/1000`, normalized `897`, left `103` mismatches, and had zero validation/generator/property/command failures with Binaryen cache `1000/0`.

Agent classification: protected root cycles reduce the size and shape of the random residuals but do not reduce their count. The broad `ssa-nomerge-smoke` embedded-control tee family remains an open parity gap, not a true semantic-mismatch claim, not a Starshine win, and not completed random all-profiles signoff. The next reduction should target the remaining `case-000002`-style nested `drop(local.tee)` vs `local.set` gap and the dropped-result-`if` dead local-set cleanup without weakening the existing HOT child-ownership protections.

## Follow-up: protected child cleanup closes bounded random embedded-tee residuals

A 2026-07-01 follow-up reduced the post-root-cycle random-all-profiles representative `case-000002` to two remaining instruction-shape gaps and fixed both with red-first coverage:

- `simplify-locals-nostructure removes dead result-if set with embedded tee` failed while protected mode preserved a dead pure stack-style `local.set` inside a dropped result `if`.
- `simplify-locals-nostructure lowers embedded dropped tee to set` failed while protected mode preserved `drop(local.tee)` inside a structured child instead of Binaryen's `local.set` spelling.

Starshine now lets the protected embedded-control-tee path perform those two narrow child cleanups while still avoiding the broader unsafe nested child-control deletion that originally motivated the guard. Fresh one-case replay `.tmp/pass-fuzz-slns-random-case000002-after-embedded-tee-dead-result-if` compares `1/1`, normalizes `1`, and has zero validation/generator/property/command failures.

Refreshed bounded random all-profiles evidence:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5555 --pass simplify-locals-nostructure --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-slns-genvalid-random-all-profiles-1000-after-embedded-tee-dead-result-if --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized `1000`, mismatches `0`, validation/generator/property/command failures `0`, selected profiles `coverage-forced-portable=215`, `ssa-nomerge-smoke=205`, `pass-fuzz-stress=205`, `ssa-nomerge-parity=193`, `binaryen-oracle-portable=182`, Binaryen cache `1000/0`.

Refreshed dedicated aggregate evidence:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-1000-after-embedded-tee-dead-result-if --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
python3 .tmp/slns-classify-result-annotations.py .tmp/pass-fuzz-slns-genvalid-all-1000-after-embedded-tee-dead-result-if .tmp/slns-genvalid-all-1000-after-embedded-tee-dead-result-if-result-type-classification.txt
```

Result: compared `1000/1000`, normalized `897`, mismatches `103`, validation/generator/property/command failures `0`, selected profiles `straight-line=423`, `tee-control=276`, `effect-order=301`, Binaryen cache `1000/0`. The classifier validates all `412` residual raw/canonical Binaryen and Starshine artifacts and finds `103/103` annotation-only after erasing structured-control result annotations.

Focused validation: `moon test --package jtenner/starshine/passes --file simplify_locals_nostructure_test.mbt --filter '*dead result-if*'` failed before implementation and passed after; `*embedded dropped tee*` failed before implementation and passed after; focused embedded tests pass `4/4`, focused `*tee*` pass `23/23`, focused SLNS passes `75/75`, `moon fmt` passes, `moon test src/passes` passes `3732/3732`, and native `src/cmd` builds with pre-existing warnings.

Classification: the bounded `205/1000` random all-profiles embedded-control tee residual set is fixed at 1000-case scale. This is not completed random-all-profiles `10000` signoff, final four-lane signoff, or performance acceptance; the previous required-size random lane still lacks a `result.json`, and representative pass-local performance remains a blocker.

## Follow-up: current large fuzz lanes after embedded-tee cleanup

After the protected child cleanup fixed the bounded random embedded-tee residual set, three required fuzz lanes completed with current `_build/native/release/build/cmd/cmd.exe`:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass simplify-locals-nostructure --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-slns-genvalid-random-all-profiles-10000-after-embedded-tee-dead-result-if --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-10000-after-embedded-tee-dead-result-if --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-genvalid-100000-after-embedded-tee-dead-result-if --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Results:

- Random all-profiles `10000`: compared `10000/10000`, normalized `10000`, mismatches/failures `0`; selected profiles `pass-fuzz-stress=2062`, `coverage-forced-portable=2037`, `ssa-nomerge-smoke=1973`, `ssa-nomerge-parity=1970`, `binaryen-oracle-portable=1958`; Binaryen cache `6435/3565`.
- Dedicated aggregate `10000`: compared `10000/10000`, normalized `9069`, mismatches `931`, failures `0`; selected profiles `straight-line=4290`, `tee-control=2885`, `effect-order=2825`; Binaryen cache `10000/0`. Classifier `.tmp/slns-genvalid-all-10000-after-embedded-tee-dead-result-if-result-type-classification.txt` validates all `3724` residual artifacts and finds `931/931` annotation-only with `0` non-annotation residuals.
- Regular GenValid `100000`: compared `100000/100000`, normalized `100000`, mismatches/failures `0`; Binaryen cache `839/99161`.

The explicit wasm-smith lane remains open:

```sh
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-wasm-smith-10000-after-embedded-tee-dead-result-if --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: compared `9956/10000`, normalized `9954`, mismatches `2`, validation/generator/property failures `0`, command failures `44` (`binaryen-rec-group-zero=39`, `binaryen-bad-section-size=3`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`), wasm-smith cache `10000/0`, Binaryen cache `106/9850`, Binaryen failure cache `0/44`.

Classification `.tmp/slns-wasm-smith-10000-after-embedded-tee-dead-result-if-classification.md` keeps both raw mismatches open:

- `case-003694-wasm-smith`: validating but size-losing nested result-loop local-carrier output-shape gap (`71B`/`74B` normalized Binaryen/Starshine; `71B`/`77B` raw).
- `case-009332-wasm-smith`: validating but size-losing unreachable/control-debris output-shape gap (`77B`/`79B` normalized Binaryen/Starshine; raw both `79B`).

These two residuals are not accepted as Starshine wins and keep explicit wasm-smith closeout open unless fixed or explicitly deferred. Pass-local performance also remains open.

## Follow-up: wasm-smith `case-009332` no-normal result-block fix

A 2026-07-01 follow-up targeted explicit wasm-smith residual `case-009332-wasm-smith`. The input has no local writes, so SLNS previously took the raw `no-local-writes` skip and left a result block whose body is `f64.const; unreachable` before a function-tail `unreachable`. Binaryen `version_130` emits flat dropped stack debris for that no-normal result block; after canonical strip-debug, the Binaryen artifact becomes `drop(memory.size); drop(f64.const); unreachable`, while Starshine's structured raw output canonicalized to an extra `drop(unreachable)` before the final `unreachable`.

Red-first public coverage `simplify-locals-nostructure flattens no-normal result block before tail unreachable` failed while the optimized function still printed `block I32`, then passed after `src/passes/pass_manager.mbt` learned a narrow no-local-writes raw fallback: flatten branch-free result blocks whose body cannot complete normally when the following non-`nop` statement is also an unconditional terminator. The branch-free guard keeps this from becoming a broad block/label rewrite.

Validation and replay evidence:

- Red-first focused test failed before implementation and passed after.
- `moon fmt` passed.
- `moon test src/passes/simplify_locals_nostructure_test.mbt` passed `76/76`.
- `moon test src/passes/pass_manager_wbtest.mbt` passed `54/54`.
- `moon build --target native --release src/cmd` passed with pre-existing unused-function warnings.
- Direct artifact replay of `case-009332` wrote `.tmp/slns-case-009332-replay-after-no-normal-block/starshine.raw.wasm`; after `wasm-opt --all-features --strip-debug`, the Starshine canonical wasm byte-compared equal to the cached Binaryen canonical artifact.
- Focused compare replay `.tmp/pass-fuzz-slns-wasm-smith-case-009332-after-no-normal-block` compared `1/1`, normalized `1`, and had zero validation/generator/property/command failures.
- Replay of both previous wasm-smith raw mismatches `.tmp/pass-fuzz-slns-wasm-smith-mismatch-replay-after-no-normal-block` compared `2/2`, normalized `1`, and left one mismatch: `case-003694-wasm-smith`.
- Refreshed explicit wasm-smith lane `.tmp/pass-fuzz-slns-wasm-smith-10000-after-no-normal-result-block-raw-only` compared `9956/10000`, normalized `9955`, left `1` raw mismatch, had zero validation/generator/property failures, and reported the same `44` Binaryen/oracle command failures (`binaryen-rec-group-zero=39`, `binaryen-bad-section-size=3`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`). Cache counters: wasm-smith `10000/0`, Binaryen `9956/0`, Binaryen failures `44/0`.
- Classification `.tmp/slns-wasm-smith-10000-after-no-normal-result-block-raw-only-classification.md` records `case-009332` as fixed and keeps `case-003694` open. `wasm-tools validate --features all` accepts all four raw/canonical residual artifacts for `case-003694`; sizes remain against Starshine (`71B`/`74B` normalized and `71B`/`77B` raw Binaryen/Starshine), so it is not accepted drift.

Agent classification: this slice fixes one validating but size-losing wasm-smith output-shape residual. It does not close SLNS: the remaining `case-003694` nested result-loop local-carrier residual and pass-local performance blocker remain open. The regular `100000`, dedicated `10000`, and random-all-profiles `10000` GenValid lanes were not rerun after this no-normal result-block fix, so do not present the current state as final four-lane signoff.

## Follow-up: wasm-smith `case-003694` typed result-loop const/nop fix

A later 2026-07-01 follow-up targeted the remaining explicit wasm-smith residual, `case-003694-wasm-smith`. The input has no local writes and consists of nested typed result loops whose inner body is `f64.const; nop`. Binaryen `version_130` still runs enough SLNS cleanup to move the inert `nop` debris before the constant and appends an unused scratch local; this avoids the compare harness's canonical strip-debug step synthesizing a `local.set` / `local.get` carrier. Starshine previously skipped raw processing for any typed-loop simplify-locals function before reaching the no-local-write raw fallback, so its raw output stayed input-shaped and canonicalized to the larger local-carrier form.

Red-first public coverage `simplify-locals-nostructure reorders const nop in nested result loops` first failed with trace `skip-raw reason=typed-loop-param-control` and the body still printing `(f64.const F64(1))nop`. The kept fix:

- lets simplify-locals descriptors with typed loops try the raw fallback when the function has no local writes;
- preserves the typed-loop HOT skip for functions with local writes;
- extends the existing const/nop result-loop cleanup from the no-tee sibling to canonical no-structure SLNS for no-local-write functions.

Validation and replay evidence:

- Red-first focused test failed before implementation and passed after.
- `moon fmt` passed.
- `moon test src/passes/simplify_locals_nostructure_test.mbt` passed `77/77`.
- `moon test src/passes/pass_manager_wbtest.mbt` passed `54/54`.
- `moon test src/passes` passed `3734/3734`.
- `moon build --target native --release src/cmd` passed with pre-existing unused-function warnings.
- Focused compare replay `.tmp/pass-fuzz-slns-wasm-smith-case-003694-after-const-nop-raw` compared `1/1`, normalized `1`, and had zero validation/generator/property/command failures.
- Replay of both prior wasm-smith raw mismatches `.tmp/pass-fuzz-slns-wasm-smith-mismatch-replay-after-const-nop-raw` compared `2/2`, normalized `2`, and had zero validation/generator/property/command failures.
- Refreshed explicit wasm-smith lane `.tmp/pass-fuzz-slns-wasm-smith-10000-after-const-nop-raw` compared `9956/10000`, normalized `9956`, left `0` raw mismatches, had zero validation/generator/property failures, and reported the same `44` Binaryen/oracle command failures (`binaryen-rec-group-zero=39`, `binaryen-bad-section-size=3`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`). Cache counters: wasm-smith `10000/0`, Binaryen `9956/0`, Binaryen failures `44/0`.
- Classification `.tmp/slns-wasm-smith-10000-after-const-nop-raw-classification.md` records both prior wasm-smith residuals as fixed and the explicit wasm-smith lane as normalized-green except for Binaryen/oracle command failures.

Agent classification: the prior validating but size-losing `case-003694` local-carrier output-shape residual is fixed, not deferred. This still does not close SLNS: the regular `100000`, dedicated `10000`, and random-all-profiles `10000` GenValid lanes were not rerun after this latest code change, and pass-local performance remains an explicit blocker.

### Post-`case-003694` bounded GenValid refresh and required-size timeout

After the typed result-loop const/nop fix, bounded GenValid probes were rerun with the same `_build/native/release/build/cmd/cmd.exe` binary:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-genvalid-1000-after-const-nop-raw --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5555 --pass simplify-locals-nostructure --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-slns-genvalid-random-all-profiles-1000-after-const-nop-raw --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-1000-after-const-nop-raw --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
python3 .tmp/slns-classify-result-annotations.py .tmp/pass-fuzz-slns-genvalid-all-1000-after-const-nop-raw .tmp/slns-genvalid-all-1000-after-const-nop-raw-result-type-classification.txt
```

Results:

- Regular GenValid `1000`: compared `1000/1000`, normalized `1000`, zero validation/generator/property/command failures, Binaryen cache `1000/0`.
- Random all-profiles `1000`: compared `1000/1000`, normalized `1000`, zero validation/generator/property/command failures, selected profiles `coverage-forced-portable=215`, `ssa-nomerge-smoke=205`, `pass-fuzz-stress=205`, `ssa-nomerge-parity=193`, `binaryen-oracle-portable=182`, Binaryen cache `1000/0`.
- Dedicated aggregate `1000`: compared `1000/1000`, normalized `897`, mismatches `103`, zero validation/generator/property/command failures, selected profiles `straight-line=423`, `tee-control=276`, `effect-order=301`, Binaryen cache `1000/0`. The classifier validates all `412` residual raw/canonical artifacts and finds `103/103` annotation-only with `0` non-annotation residuals.

A required-size dedicated aggregate rerun was attempted:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-10000-after-const-nop-raw --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

It timed out after `1800s` before `result.json`; partial `cases.jsonl` has `6239` records (`5650` matches, `589` mismatches). Treat this as a throughput/performance blocker signal and partial evidence only, not the required dedicated `10000` signoff lane.

Agent classification: bounded GenValid did not expose new non-annotation residuals after the wasm-smith fix, but final closeout still requires current required-size regular/dedicated/random GenValid lanes and pass-local performance resolution or explicit acceptance.

## 2026-07-01 current 100-largest timing refresh after const/nop raw fix

A measurement-only slice refreshed the 100-largest timing probe against the current native binary and the post-const/nop dedicated input corpus:

```sh
moon build --target native --release src/cmd
OUT=.tmp/slns-perf-probe-constnop-100-largest-current
INPUT_DIR=.tmp/pass-fuzz-slns-genvalid-all-10000-after-const-nop-raw/inputs/gen-valid
# select the 100 largest gen-valid inputs from INPUT_DIR, then:
bun scripts/self-optimize-compare.ts <selected input> --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir "$OUT/<case>" --timing-only --simplify-locals-nostructure
```

Results are summarized in `.tmp/slns-perf-probe-constnop-100-largest-current-summary.md`:

- `moon build --target native --release src/cmd` reported no work.
- Timing commands completed `100/100`.
- Selected input sizes: median `767B`, mean `775.34B`, min selected `746B`, max `910B`.
- Canonical wasm equal: `18/100`.
- Whole-command Starshine faster: `86/100`.
- Pass-local within the ordinary `starshine_time <= 2 * binaryen_time` floor: `0/100`.
- Starshine/Binaryen pass medians: `0.4875ms` / `0.1293ms`.
- Pass-ratio median `3.7990x`, mean `3.7908x`, p75 `3.9334x`, max `5.5935x`.
- Trace aggregation still shows median four `pass:simplify-locals-nostructure` events and twelve `main-cycle` / `scan-root-region` / `dead-cleanup` events, roughly three main/dead cycles per function.

Agent classification: this is current performance-blocker evidence, not performance acceptance and not final signoff. Whole-command timing is often favorable on these tiny generated inputs, but pass-local SLNS remains well outside the repo floor, and the repeated main/dead scan shape remains the obvious next optimization target. No behavior code changed in this measurement slice, and no required-size GenValid lane was rerun.

## Follow-up: deferred multi-use follow-up performance skip

A 2026-07-01 performance slice targeted the current 100-largest timing blocker where generated functions paid three main/dead scan cycles: first cycle, deferred multi-use follow-up, then a no-op confirmation cycle. Red-first `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure stops after deferred multi-use follow-up stabilizes` failed with `3 != 2` `detail:simplify-locals:main-cycle` timer events on a straight-line multi-use set/drop fixture. The loop now treats the first post-deferred follow-up as the required Binaryen tee/cleanup cycle and does not force a further confirmation cycle merely because that follow-up changed the function.

Validation and bounded post-change evidence:

- Focused SLNS file: `moon test --package jtenner/starshine/passes --file simplify_locals_nostructure_test.mbt` — `78/78` passed.
- `moon test src/passes` — `3735/3735` passed.
- `moon build --target native --release src/cmd` — passed after the change; the workspace binary path remains `_build/native/release/build/cmd/cmd.exe`.
- Regular GenValid bounded refresh `.tmp/pass-fuzz-slns-genvalid-1000-after-deferred-followup-skip` — compared `1000/1000`, normalized `1000`, zero mismatches/failures.
- Dedicated aggregate bounded refresh `.tmp/pass-fuzz-slns-genvalid-all-1000-after-deferred-followup-skip` — compared `1000/1000`, normalized `897`, mismatches `103`, zero validation/generator/property/command failures; classifier `.tmp/slns-genvalid-all-1000-after-deferred-followup-skip-result-type-classification.txt` validates all `412` residual artifacts and finds `103/103` annotation-only.
- Random all-profiles bounded refresh `.tmp/pass-fuzz-slns-genvalid-random-all-profiles-1000-after-deferred-followup-skip` — compared `1000/1000`, normalized `1000`, zero mismatches/failures.
- Bounded explicit wasm-smith refresh `.tmp/pass-fuzz-slns-wasm-smith-1000-after-deferred-followup-skip` — compared `997/1000`, normalized `997`, zero mismatches, zero validation/generator/property failures, and `3` Binaryen/oracle command failures (`binaryen-rec-group-zero=2`, `binaryen-invalid-tag-index=1`).

Timing probe `.tmp/slns-perf-probe-deferred-followup-skip-100-largest-current` reused the same 100 largest inputs from `.tmp/pass-fuzz-slns-genvalid-all-10000-after-const-nop-raw/inputs/gen-valid` as the prior const/nop probe. It completes `100/100`; canonical/normalized equality signal remains `18/100`; whole-command Starshine is faster on `95/100`; pass-local Starshine remains within `<=2x Binaryen` on `0/100`. The median pass ratio improves from the previous current `3.7990x` to `2.8141x`; Starshine/Binaryen pass medians are `0.3675ms` / `0.1304ms`; trace median main/dead event counts drop from `12` to `8` across the four pass invocations.

This is a real bounded performance improvement, but not performance acceptance or final signoff. Required-size regular GenValid `100000`, dedicated aggregate `10000`, random all-profiles `10000`, and explicit wasm-smith `10000` still need post-latest-change refresh, and the pass-local performance floor remains unmet on the 100-largest sample.

## Follow-up: subphase timer trace-overhead performance slice

A later 2026-07-01 performance slice found that the previous 100-largest pass-local timing still included substantial diagnostic trace overhead inside the outer `pass:simplify-locals-nostructure` timer. Existing aggregation over `.tmp/slns-perf-probe-deferred-followup-skip-100-largest-current` showed a median pass time of `367.5us`, but only `209us` median in top-level detail timers (`main-cycle`, dead cleanup, and delete timers); the median unaccounted portion was `158us`. A significant owner was per-cycle trace emission for high-frequency subphase timers.

Red-first `src/passes/simplify_locals_nostructure_test.mbt::simplify-locals-nostructure keeps high-frequency subphase timers off the trace hot path` failed while a two-cycle deferred fixture emitted per-cycle `count-local-gets`, `scan-root-region`, `delete-main-detached`, `dead-cleanup`, and `delete-dead-detached` timer lines. The implementation now uses accumulated timers for those high-frequency subphases without emitting each cycle. The transform is unchanged, and `detail:simplify-locals:main-cycle` remains emitted so the existing cycle-count performance invariants still have a stable signal.

Validation and bounded post-change evidence:

- Red-first focused test failed before implementation with the expected inner subphase timer lines in the trace.
- Focused SLNS file: `moon test --package jtenner/starshine/passes --file simplify_locals_nostructure_test.mbt` — `79/79` passed after implementation.
- `moon fmt` — passed / up to date.
- `moon test src/passes` — `3736/3736` passed.
- `moon build --target native --release src/cmd` — passed with pre-existing unused-function warnings in `pass_manager.mbt`; the workspace binary path remains `_build/native/release/build/cmd/cmd.exe`.
- Regular GenValid bounded refresh `.tmp/pass-fuzz-slns-genvalid-1000-after-subphase-timer-accumulate` — compared `1000/1000`, normalized `1000`, zero mismatches/failures.
- Dedicated aggregate bounded refresh `.tmp/pass-fuzz-slns-genvalid-all-1000-after-subphase-timer-accumulate` — compared `1000/1000`, normalized `897`, mismatches `103`, zero validation/generator/property/command failures. The failure ID set exactly matches the previous post-deferred-followup-skip 103-case annotation-only set; classifier `.tmp/slns-genvalid-all-1000-after-subphase-timer-accumulate-result-type-classification.txt` validates all `412` residual artifacts and records `103/103` annotation-only.
- Random all-profiles bounded refresh `.tmp/pass-fuzz-slns-genvalid-random-all-profiles-1000-after-subphase-timer-accumulate` — compared `1000/1000`, normalized `1000`, zero mismatches/failures.
- Bounded explicit wasm-smith refresh `.tmp/pass-fuzz-slns-wasm-smith-1000-after-subphase-timer-accumulate` — compared `997/1000`, normalized `997`, zero mismatches, zero validation/generator/property failures, and `3` Binaryen/oracle command failures (`binaryen-rec-group-zero=2`, `binaryen-invalid-tag-index=1`).

Timing probe `.tmp/slns-perf-probe-subphase-timer-accumulate-100-largest-current` reused the same 100 largest inputs from `.tmp/pass-fuzz-slns-genvalid-all-10000-after-const-nop-raw/inputs/gen-valid` as the prior const/nop and deferred-followup probes. Summary artifact `.tmp/slns-perf-probe-subphase-timer-accumulate-100-largest-current-summary.md` records:

- Timing commands completed `100/100`.
- Selected input sizes: median `767B`, mean `775.34B`, min selected `746B`, max `910B`.
- Canonical/normalized equality signal: `18/100`.
- Whole-command Starshine faster: `99/100`.
- Pass-local within the ordinary `starshine_time <= 2 * binaryen_time` floor: `90/100`.
- Starshine/Binaryen pass medians: `0.2335ms` / `0.1348ms`.
- Pass-ratio median `1.7590x`, mean `1.7402x`, p75 `1.8776x`, max `2.3921x`.
- `detail:simplify-locals:main-cycle` remains at median `8` events across the four pass invocations. The high-frequency subphase timers no longer have per-cycle trace event counts by design.

Agent classification: this is a trace-overhead performance fix, not a transform/semantic change. It is a large bounded timing improvement over the previous median ratio `2.8141x` / `0/100` within `<=2x`, but it is still not final performance acceptance: ten sampled cases remain above `2x`, and the required-size regular `100000`, dedicated aggregate `10000`, random all-profiles `10000`, and explicit wasm-smith `10000` lanes still need post-latest-code-change refresh before final closeout.

## 2026-07-01 post-subphase required fuzz refresh

After the subphase-timer trace-overhead slice, the transform was unchanged but the latest code change still made the required-size fuzz lanes stale for closeout reporting. This follow-up rebuilt no code and used the existing native binary `_build/native/release/build/cmd/cmd.exe` to refresh the full required matrix:

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-genvalid-100000-after-subphase-timer-accumulate --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-slns-wasm-smith-10000-after-subphase-timer-accumulate --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals-nostructure --gen-valid-profile simplify-locals-nostructure-all --out-dir .tmp/pass-fuzz-slns-genvalid-all-10000-after-subphase-timer-accumulate --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass simplify-locals-nostructure --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-slns-genvalid-random-all-profiles-10000-after-subphase-timer-accumulate --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
python3 .tmp/slns-classify-result-annotations.py .tmp/pass-fuzz-slns-genvalid-all-10000-after-subphase-timer-accumulate .tmp/slns-genvalid-all-10000-after-subphase-timer-accumulate-result-type-classification.txt
```

Results:

- Regular GenValid `100000`: compared `100000/100000`, normalized `100000`, mismatches/failures `0`, selected profile `binaryen-oracle-portable=100000`, Binaryen cache `100000/0`.
- Explicit wasm-smith `10000`: compared `9956/10000`, normalized `9956`, mismatches `0`, validation/generator/property failures `0`, command failures `44` classified as Binaryen/oracle tool failures (`binaryen-rec-group-zero=39`, `binaryen-bad-section-size=3`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`), cache wasm-smith `10000/0`, Binaryen `9956/0`, Binaryen failures `44/0`.
- Dedicated aggregate `10000`: compared `10000/10000`, normalized `9069`, mismatches `931`, validation/generator/property/command failures `0`, selected profiles straight-line `4290`, tee-control `2885`, effect-order `2825`, Binaryen cache `10000/0`. The classifier validates all `3724` residual artifacts and finds `931/931` annotation-only with `0` non-annotation residuals.
- Random all-profiles `10000`: compared `10000/10000`, normalized `10000`, mismatches/failures `0`, selected profiles `pass-fuzz-stress=2062`, `coverage-forced-portable=2037`, `ssa-nomerge-smoke=1973`, `ssa-nomerge-parity=1970`, `binaryen-oracle-portable=1958`, Binaryen cache `10000/0`.

Agent classification: the post-latest-code-change required fuzz matrix is current and has no Starshine validation, generator, property, command, or true semantic mismatches. The dedicated aggregate's raw residuals are the already documented structured-control result-annotation output drift with validated artifacts; the wasm-smith command failures are Binaryen/oracle tool boundaries. This does not close the audit because pass-local performance remains unresolved: the current bounded 100-largest timing probe is improved (`90/100` sampled cases within `<=2x`, median ratio `1.7590x`) but still leaves ten sampled cases outside the repo floor and no accepted performance exception.

## 2026-07-01 slow-case timing repeat probe

A follow-up measurement-only slice inspected the ten originally `>2x` cases from `.tmp/slns-perf-probe-subphase-timer-accumulate-100-largest-current`:

- `gen-valid-008369`
- `gen-valid-007144`
- `gen-valid-000761`
- `gen-valid-007364`
- `gen-valid-000475`
- `gen-valid-000151`
- `gen-valid-005836`
- `gen-valid-008728`
- `gen-valid-001688`
- `gen-valid-001444`

Each case was rerun ten times with the same timing command shape and `_build/native/release/build/cmd/cmd.exe`; artifacts and summary are in `.tmp/slns-perf-probe-subphase-timer-accumulate-slow10-repeat-current/`.

Results from `.tmp/slns-perf-probe-subphase-timer-accumulate-slow10-repeat-current/summary.md`:

- Total repeat runs: `100`; pass-local within `<=2x`: `78/100`.
- Repeated pass-ratio median/mean/p75/max: `1.8269x` / `1.8181x` / `1.9715x` / `2.6625x`.
- Every originally slow case had at least `5/10` repeat runs within the ordinary floor.
- Original single-run traces for all ten cases had four SLNS function-pass invocations and eight `detail:simplify-locals:main-cycle` events; the main-cycle timer accounted for about `40-53%` of the pass-local timer. `lift` and `lower` were measured separately and are not included in `starshinePassElapsedMs`.

Agent classification: the original `10/100` slow cases are not stable hard failures under repeat measurement, and the slow-case repeated median remains below the `<=2x` floor. However, maxima still exceed the floor and the trace shape shows real remaining main-cycle/pass overhead, so this is only bounded evidence toward a performance exception or broader timing signoff. No red-first safe fix was identified in this measurement slice, and no final performance acceptance is claimed.

## 2026-07-01 100-largest repeat3 timing probe

A follow-up measurement-only slice broadened the slow-case repeat evidence by rerunning every case from `.tmp/slns-perf-probe-subphase-timer-accumulate-100-largest-current` three times. The command shape was the same as the slow10 probe:

```sh
bun scripts/self-optimize-compare.ts .tmp/pass-fuzz-slns-genvalid-all-10000-after-const-nop-raw/inputs/gen-valid/<case>.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/slns-perf-probe-subphase-timer-accumulate-100-largest-repeat3-current/<case>/run-<n> --timing-only --simplify-locals-nostructure
```

Artifacts and the generated summary are in `.tmp/slns-perf-probe-subphase-timer-accumulate-100-largest-repeat3-current/`.

Results from `.tmp/slns-perf-probe-subphase-timer-accumulate-100-largest-repeat3-current/summary.md`:

- Total repeat runs: `300`; pass-local within `<=2x`: `242/300`.
- Repeat-run pass-ratio median/mean/p75/max: `1.7930x` / `1.7871x` / `1.9412x` / `2.7598x`.
- Per-case median ratio median/mean/p75/max: `1.8043x` / `1.7879x` / `1.8837x` / `2.3251x`.
- Cases with all three repeats within `<=2x`: `57/100`; at least two passing repeats: `86/100`; fewer than two passing repeats: `14/100`; zero passing repeats: `1/100`.
- Original one-run baseline for the same sample was `90/100` within `<=2x`, with median/mean/p75/max `1.7590x` / `1.7402x` / `1.8773x` / `2.3921x`.
- The ten originally slow cases had `26/30` repeat runs within `<=2x` and `9/10` cases with at least two passing repeats; the ninety originally within-floor cases had `216/270` passing repeat runs.

Agent classification: single-run per-case SLNS timing remains noisy at this sub-millisecond scale. The central tendency is within the ordinary floor, but tail behavior is still above-floor and the repeat max reaches `2.7598x`. This evidence strengthens the case for a bounded/noisy performance exception discussion, but it does not prove strict pass-local floor compliance for every generated input and does not identify a concrete safe performance fix. Final performance acceptance or exception remains open.

## 2026-07-01 100-largest tail timing attribution

A follow-up measurement/classification slice analyzed the existing trace artifacts from `.tmp/slns-perf-probe-subphase-timer-accumulate-100-largest-repeat3-current` without rerunning Starshine or Binaryen. The generated attribution summary is `.tmp/slns-perf-probe-subphase-timer-accumulate-tail-attribution-current/summary.md`.

Key findings:

- All `300/300` repeat traces have exactly `4` SLNS pass invocations and `8` visible `detail:simplify-locals:main-cycle` events; the current timing tail is not caused by extra main cycles in these traces.
- All 100 largest sampled cases come from the dedicated aggregate's `simplify-locals-nostructure-effect-order` selected profile leaf, so the weak-tail subset is not a separate selected-profile family.
- Slow repeat runs (`ratio > 2`, `58/300`) have median Starshine pass-local `277.0us`, Binaryen pass-local `126.9us`, main-cycle `127.5us`, non-main pass overhead `146.5us`, and main-cycle share `47.9%`.
- Passing repeat runs (`ratio <= 2`, `242/300`) have median Starshine pass-local `236.5us`, Binaryen pass-local `135.5us`, main-cycle `114.0us`, non-main pass overhead `121.0us`, and main-cycle share `48.7%`.
- The `14/100` cases with fewer than two passing repeats have median case-level Starshine/Binaryen/main/non-main times `279.5us` / `133.9us` / `126.0us` / `145.5us` and median ratio `2.0752x`; the other `86/100` cases have `237.0us` / `133.9us` / `115.0us` / `121.0us` and median ratio `1.7902x`.
- Input byte size does not distinguish the weak subset: weak median/mean/min/max bytes are `756.0` / `774.6` / `746` / `910`, while stronger cases are `767.5` / `775.5` / `746` / `906`.

Agent classification: this narrows the unresolved performance tail to fixed-shape, sub-millisecond effect-order generated inputs. Main-cycle work remains a large owner, but weak-vs-strong timing differs in both main-cycle and non-main pass overhead. Because high-frequency scan/dead-cleanup subphase timers are now accumulated without per-cycle trace emission, any concrete performance fix should first add temporary instrumentation or a new low-overhead counter to split main-cycle, setup, cleanup, and writeback costs. This is not performance acceptance and not a user-approved exception.

## 2026-07-01 100-largest structural attribution

A follow-up measurement/classification slice reused the same `.tmp/slns-perf-probe-subphase-timer-accumulate-100-largest-repeat3-current` traces plus the original input wasm files from `.tmp/pass-fuzz-slns-genvalid-all-10000-after-const-nop-raw/inputs/gen-valid`. It did not rerun Starshine or Binaryen. The analysis printed the 100 inputs with `wasm-tools print`, counted simple structural features, and wrote `.tmp/slns-perf-probe-subphase-timer-accumulate-structural-attribution-current/summary.md` plus raw metrics JSON.

Key findings:

- Analyzed `100` cases (`14` weak-tail cases with fewer than two of three repeats within `<=2x`, and `86` stronger cases) and reused all `300` repeat traces.
- No single structural counter cleanly separates weak-tail cases from stronger cases. Byte size, selected profile, function-pass invocation count, and basic WAT counters all overlap heavily.
- Largest median structural differences are small: weak vs stronger cases have WAT-line medians `267.0` vs `271.0`, `drop` medians `25.0` vs `29.0`, `local.get` medians `19.5` vs `21.0`, `if` medians `8.0` vs `7.0`, and byte medians `756.0` vs `767.5`.
- The highest descriptive rank correlation with median pass ratio is the count of `if` instructions (`rho=0.450`), followed by `const` (`0.288`) and negative correlations for `local.set` / `call_ref` (`-0.272`). These are descriptive only at `n=100` and do not justify a code change.
- Trace-derived medians show the weak subset has somewhat larger median max per-function pass time (`94.0us` vs `82.5us`) and max main-cycle time (`28.5us` vs `25.0us`), but the ranges overlap (`78-120us` vs `68-109us` for max function pass time; `22-37us` vs `19-32us` for max main-cycle time).

Agent classification: this reinforces the prior tail attribution rather than finding a new actionable input family. The weak subset remains best classified as a fixed-shape, sub-millisecond effect-order timing tail with overlapping structural/timing ranges. There is still no performance acceptance or user-approved exception. If pursuing a fix instead of an exception, the next safe step is temporary/local or low-overhead accumulated subphase counters for scan/count/delete/writeback/dead-cleanup on the weak cases, especially `gen-valid-004921`; do not keep telemetry-only tests.

## 2026-07-01 draft soft performance exception packet

A follow-up documentation-only slice turned the current timing evidence into a draft exception packet in `docs/wiki/binaryen/passes/simplify-locals-nostructure/parity.md`. No Starshine/Binaryen timing commands, Moon tests, or fuzz lanes were rerun for this slice, and no source code changed.

Evidence supporting a possible narrow exception:

- The required fuzz matrix is current after the latest code change: regular GenValid `100000/100000` normalized; explicit wasm-smith `9956/10000` normalized with only `44` Binaryen/oracle command failures; dedicated aggregate `10000/10000` compared with `931/931` residuals classified annotation-only and all residual artifacts validating; random all-profiles `10000/10000` normalized.
- The remaining blocker is pass-local timing, not whole-command wall time or correctness. The single-run 100-largest probe has whole-command Starshine faster on `99/100` cases and pass-local within `<=2x` on `90/100` cases.
- Repeat evidence shows sub-millisecond noise/tail behavior: the all-100 repeat3 probe has `242/300` repeats within `<=2x`, repeat median/mean/p75 `1.7930x` / `1.7871x` / `1.9412x`, but max `2.7598x` and per-case median max `2.3251x`.
- Tail and structural attribution find no distinct safe code-change family: all traces have four pass invocations and eight main-cycle events, all cases are effect-order generated inputs, and structural counters overlap heavily.
- Obvious performance owners already received red-first fixes in prior slices: redundant main-cycle follow-ups were skipped and high-frequency subphase timers were removed from ordinary trace output, reducing the 100-largest median ratio from `3.7990x` after the const/nop fix to `1.7590x` after subphase-timer accumulation.

Reasons the packet is not an approval:

- The ordinary pass-local floor remains `starshine_time <= 2 * binaryen_time`; measured repeat tails still exceed it.
- The evidence is a bounded 100-largest dedicated effect-order sample, not universal performance signoff.
- A real fix could still exist, but needs temporary/local or low-overhead subphase counters for scan/count/delete/writeback/dead-cleanup before changing behavior.

Proposed approval wording, if the user accepts it later: SLNS `version_130` can close with a narrow performance caveat because correctness/fuzz evidence is current and green or annotation-only, whole-command timing is favorable on the bounded sample, pass-local central tendency is within the ordinary floor, and the remaining fixed-shape sub-millisecond tail has no identified safe fix after redundant-cycle and trace-overhead optimizations. Reopening criteria: any new Starshine validation/generator/property/semantic mismatch; a repeatable pass-local regression whose central tendency exceeds `2x`; discovery of a stable structural or subphase owner that suggests a safe optimization; or explicit rejection of the exception.


## 2026-07-01 function-slot timing attribution

A follow-up measurement/classification slice parsed the existing `.tmp/slns-perf-probe-subphase-timer-accumulate-100-largest-repeat3-current` traces and `result.json` files without rerunning Starshine, Binaryen, Moon, or fuzzing. The generated summary is `.tmp/slns-perf-probe-subphase-timer-accumulate-function-slot-attribution-current/summary.md`.

Key findings:

- Analyzed all `100` cases and all `300` repeat runs from the repeat3 probe (`58` runs above `2x`, `242` within `<=2x`).
- Every parsed run still has four SLNS function-pass invocations and two visible `detail:simplify-locals:main-cycle` events per invocation, matching the prior tail attribution.
- Weak-tail cases (`14/100`, fewer than two of three repeats within `<=2x`) are slower across all four function-pass slots rather than one isolated function position. Weak-vs-strong median pass-time deltas by slot are `+10.5us`, `+14.5us`, `+1.0us`, and `+5.5us`.
- The weak-vs-strong gap is split between visible main-cycle and inferred non-main pass-local time. Slot 2 is the largest descriptive signal: weak slot-2 medians are `65.5us` pass / `29.5us` main / `34.0us` non-main, versus stronger `51.0us` / `24.0us` / `27.0us`; simple Pearson correlations with case median ratio are `0.464` for slot-2 non-main time, `0.450` for slot-2 pass time, and `0.396` for slot-2 main time.
- `gen-valid-004921`, the only `0/3` repeat-pass case, has high-but-not-unique per-slot medians (`100/52/48`, `57/25/32`, `73/30/43`, `54/22/32` pass/main/non-main us), so it remains a useful probe but not a standalone safe optimization recipe.

Agent classification: this strengthens the current performance-blocker classification but does not change closeout status. The tail is fixed-shape and distributed across visible main-cycle and invisible accumulated subphases / writeback / cleanup overhead, not a single function-position shortcut. Because current ordinary traces intentionally hide `count-local-gets`, `scan-root-region`, delete, and dead-cleanup subphase totals, a real fix still needs temporary/local or low-overhead counters before changing code. This is not performance acceptance, not a user-approved exception, and not new fuzz evidence.
