---
kind: concept
status: supported
last_reviewed: 2026-05-18
sources:
  - ../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md
  - ../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md
  - ../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md
  - ../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/fuzz_harness_wbtest.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./linear-traces-read-only-to-write-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-globals/index.md
  - ../propagate-globals-globally/index.md
  - ../duplicate-import-elimination/index.md
  - ../remove-unused-module-elements/index.md
  - ../string-gathering/index.md
  - ../reorder-globals/index.md
  - ../directize/index.md
---

# Starshine strategy for `simplify-globals-optimizing`

Use this page with the raw primary-source manifests in [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md) and [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md).
The purpose here is to map the reviewed Binaryen contract to the exact current Starshine status and the concrete local surfaces a future port should start from. The implementation-readiness and validation ladder now live in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Honest current status

`simplify-globals-optimizing` is now **partially implemented** in Starshine.
The first local slice lives in [`src/passes/simplify_globals_optimizing.mbt`](../../../../../src/passes/simplify_globals_optimizing.mbt) and is wired as an active module pass through [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) and [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt).
It is not full Binaryen parity yet. A 2026-05-18 current-main refresh rechecked official Binaryen `main` at commit `d3029d2b975488acdf9253eb2994a3fc55bd3549` and found no SGO semantic drift from the `version_129` source contract, so the remaining gaps below should still be treated as real local gaps rather than upstream churn.

The current local strategy is therefore a partial-implementation map:

- keep the public pass spelling active and requestable,
- treat it as a module/global pass rather than a HOT-local peephole,
- preserve the canonical late-post-pass slot without widening public `optimize` / `shrink` presets yet,
- keep the `SGO` backlog split visible because the shared global engine and artifact parity remain incomplete,
- keep the sibling relation to plain `simplify-globals` and `propagate-globals-globally` explicit,
- document any active subset instead of implying the current implementation already models the full Binaryen late global pass.

## Exact local code map today

The fast read-along path is:

- active module-pass registry entry
  - [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
    - `pass_registry_entries()` includes `"simplify-globals-optimizing"` as a module pass, while plain `"simplify-globals"` remains boundary-only.
- module-pass dispatcher
  - [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
    - `run_hot_pipeline_apply_module_pass(...)` routes the pass to the SGO core and then to a touched-function nested cleanup lane.
- implementation owner
  - [`src/passes/simplify_globals_optimizing.mbt`](../../../../../src/passes/simplify_globals_optimizing.mbt)
    - the current core collects global traffic facts, promotes private never-written / dead-written globals, propagates supported constants, rewrites never-read sets to `drop`, and returns touched-function bits.
- focused regression tests
  - [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../../src/passes/simplify_globals_optimizing_test.mbt)
    - tests cover active registration, private mutable constant promotion, touched-only cleanup, startup data-offset propagation, dead-set rewrite, side-effect preservation through dropped set operands, read-only-to-write self-guards including `i32.eqz`, bidirectional compare-const, nested block-condition, block-wrapped and block-yielded condition reads including `i32.eqz`, block-yielded operators after pure block condition bodies, block-yielded external pure-condition chains, block-yielded short external pure operators, block-yielded reverse external pure operators, guardrail negatives for unsupported external block-yielded wrong-target, non-constant-write, `else`, trapping-op, trailing-code, and wrong-stack-depth shapes, adjacent plain-block runtime propagation with call and early-exit barriers, no-op const/drop prefixes before block-wrapped condition reads, `nop` / void-`block` transparent bodies, no-op const/drop prefixes before the write, plus exact/eqz/bidirectional compare/block-wrapped-condition/nested-block-wrapped-condition/block-yielded-condition/block-yielded-condition+set/block-yielded operators after pure block condition bodies/block-yielded external pure-condition chains/block-yielded short external pure operators/block-yielded reverse external pure operators/block-wrapped-set/block-wrapped-condition+set `if return; set`, and exported mutable-global bailout.
- current preset gap
  - [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
    - local `optimize` / `shrink` presets still stop before the late Binaryen post-pass tail; this pass is direct-requestable but not yet scheduled in public presets.
- canonical Binaryen placement
  - [`../../no-dwarf-default-optimize-path.md#L35-L48`](../../no-dwarf-default-optimize-path.md#L35-L48)
    - the no-DWARF late post-pass phase places `simplify-globals-optimizing` after `duplicate-import-elimination` and before `remove-unused-module-elements`; the nested rerun rule records that this sibling reruns default function passes without the `precompute-propagate` prefix
- backlog slice
  - [`../../../../../agent-todo.md#L546-L561`](../../../../../agent-todo.md#L546-L561)
    - `SGO` is split into constant-global / mutation tracking and nested default-function rerun work

## What Starshine currently does for this pass name

### 1. The name is active as a module pass

`src/passes/optimize.mbt` now keeps `simplify-globals-optimizing` in the active module-pass registry.
This is the correct shape for the first implementation slice because the pass needs module-wide global facts, startup-order rewrites, function-body substitutions, and an optimizer rerun over changed functions.
Plain `simplify-globals` remains boundary-only until the shared engine is exposed deliberately under that smaller public contract.

### 2. Explicit requests run the partial implementation

The active pipeline now accepts `--simplify-globals-optimizing` / direct pass requests and routes them through `src/passes/pass_manager.mbt`.
The direct pass is intentionally not yet inserted into the public `optimize` / `shrink` presets because the late-tail neighborhood and full Binaryen algorithm are not oracle-proven.

### 3. The landed subset covers both SGO backlog halves narrowly

The current implementation includes:

- a module-owned global fact table over imports, exports, table initializers, global initializers, element item expressions, data offsets, and function bodies,
- practical immutability promotion for private never-written globals,
- single-use global-initializer folding into later global initializers,
- exact-type immutable global-copy-chain canonicalization to the earliest compatible ancestor in global initializers and function bodies,
- never-read, single-const same-as-init, adjacent/eqz/bidirectional compare-const/simple-pure-condition (including source-backed i32 unary/bitwise/shift-rotate ops, i64 equality/compare and non-trapping value ops, plus f32/f64 compares), transparent, nested, block-wrapped-condition, block-yielded-condition, block-yielded operators after pure block condition bodies, block-yielded external pure-condition chains, block-yielded short external pure operators, block-yielded reverse external pure operators, no-op-condition-prefix, and const-drop-body read-only-to-write self-guard, and exact/eqz/bidirectional compare/block-wrapped-condition/nested-block-wrapped-condition/block-yielded-condition/block-yielded-condition+set/block-yielded operators after pure block condition bodies/block-yielded external pure-condition chains/block-yielded short external pure operators/block-yielded reverse external pure operators/block-wrapped-set/block-wrapped-condition+set `if return; set` read-only-to-write `global.set` rewriting to `drop(value)` with the writer marked as touched,
- supported single-instruction constant `global.get` replacement in function bodies,
- startup constant propagation into table initializers, global initializers, element offsets, and data offsets,
- single-const private global write propagation along straight-line, adjacent/nested plain-block, and if-then-body runtime traces with call/control/early-exit barriers plus guardrail coverage for imported globals, independent writes, latest-write wins, loops, `try_table` barriers, and else-arm conservatism,
- reference-typed element item expression preservation until exact type/refinalization breadth lands,
- an exact touched defined-function bitset for changed function bodies,
- a touched-function nested default cleanup lane that deliberately does **not** prepend `precompute-propagate`.

This is still a subset, not full `SimplifyGlobals.cpp` parity.

## Starshine implementation shape to preserve

A future local port should be planned as a boundary/module family, probably sharing machinery with plain `simplify-globals` and possibly a startup-only subset.
The minimum shape is:

1. collect module-wide global traffic facts across function bodies and module-level code,
2. fold single-use global initializers only into later global initializers,
3. preserve operand evaluation when erasing useless writes by rewriting `global.set value` to `drop(value)`,
4. implement the actual-node and effect/value-flow legality checks for `read-only-to-write`,
5. canonicalize immutable copy chains only where the use type remains legal,
6. distinguish startup propagation from runtime trace propagation,
7. record exactly which functions changed,
8. rerun the default function optimization pipeline on changed functions,
9. avoid prepending `precompute-propagate` in this nested rerun,
10. re-run validation and Binaryen comparison on both isolated pass tests and the late post-pass neighborhood.

The most likely local landing point is **not** the existing HOT pass manager alone.
The pass must eventually compose with boundary/module scheduling next to `duplicate-import-elimination`, `remove-unused-module-elements`, `string-gathering`, `reorder-globals`, and `directize`. For a concrete first-slice and validation plan, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Mapping to neighboring dossiers

| Neighbor | Relationship to `simplify-globals-optimizing` |
| --- | --- |
| [`../simplify-globals/index.md`](../simplify-globals/index.md) | Shared Binaryen engine without the optimizing nested rerun. Any local implementation should keep this public-contract split explicit. |
| [`../propagate-globals-globally/index.md`](../propagate-globals-globally/index.md) | Startup-only shared-engine subset. Useful as a staging candidate, but smaller than full `simplify-globals-optimizing`. |
| [`../dae-optimizing/index.md`](../dae-optimizing/index.md) | Another optimizing late pass, but its nested cleanup helper prepends `precompute-propagate`; do not copy that exact rerun shape for `SGO`. |
| [`../inlining-optimizing/index.md`](../inlining-optimizing/index.md) | Same warning as DAE: optimizing sibling, different nested-rerun helper story. |
| [`../duplicate-import-elimination/index.md`](../duplicate-import-elimination/index.md) | Immediate late-post-pass predecessor in the no-DWARF path. |
| [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md) | Immediate late-post-pass successor; should consume globals and elements made dead by `SGO`. |
| [`../string-gathering/index.md`](../string-gathering/index.md) | Later global/string boundary pass; depends on the late-tail ordering staying honest. |
| [`../reorder-globals/index.md`](../reorder-globals/index.md) | Later layout pass; should see the post-`SGO` global set. |
| [`../directize/index.md`](../directize/index.md) | Final late-tail indirect-call cleanup neighbor. |

## What Starshine does not have yet

Do not overread the active registry entry.
Starshine still lacks:

- a shared owner for the plain `simplify-globals` / optimizing / `propagate-globals-globally` family,
- broader same-as-init expression matching beyond the landed single-const write shape,
- broader `read-only-to-write` structural matching and its whole-pass iteration beyond the landed adjacent/eqz/bidirectional compare-const/simple-pure-condition (now including i32 unary/bitwise/shift-rotate ops, i64 equality/compare and non-trapping value ops, plus f32/f64 compares), transparent, nested, block-wrapped-condition, block-yielded-condition, block-yielded operators after pure block condition bodies, block-yielded external pure-condition chains, block-yielded short external pure operators, block-yielded reverse external pure operators, no-op-condition-prefix, and const-drop-body self-guard and exact/eqz/bidirectional compare/block-wrapped-condition/nested-block-wrapped-condition/block-yielded-condition/block-yielded-condition+set/block-yielded operators after pure block condition bodies/block-yielded external pure-condition chains/block-yielded short external pure operators/block-yielded reverse external pure operators/block-wrapped-set/block-wrapped-condition+set `if return; set` shapes; the main next source-backed gap is side-effecting-but-safe condition value-flow matching rather than more isolated syntactic variants,
- broader copy-chain/type-refinalization cases beyond the landed exact-type immutable ancestor rewrite,
- broader runtime linear-trace propagation beyond the landed straight-line, plain-block, and if-then-body single-const write facts,
- type/refinalization breadth for replacements that change reference precision,
- debug-artifact Binaryen parity evidence for the isolated pass and late-tail neighborhood,
- direct Binaryen oracle replay after each newly-added global rewrite family,
- preset scheduling in `optimize` / `shrink`.

## Validation plan for the eventual port

When implementation begins, validate in this order:

1. source-shape tests for shared global rewrites:
   - single-use global initializer folding,
   - same-as-init and dead writes becoming `drop(value)`,
   - `read-only-to-write` positives and negatives,
   - immutable-copy-chain replacement,
   - startup propagation into later globals and offsets,
   - runtime trace propagation with call/control barriers;
2. scheduler tests:
   - changed functions are tracked exactly,
   - nested default function cleanup runs only where needed,
   - no `precompute-propagate` prefix is inserted for `SGO`;
3. public-surface tests:
   - `simplify-globals-optimizing` remains an active module pass,
   - plain `simplify-globals` remains boundary-only until deliberately exposed,
   - `optimize` / `shrink` preset expansion changes only when the late-tail gap is intentionally closed;
4. oracle comparison:
   - compare `--simplify-globals-optimizing` against Binaryen on reduced fixtures,
   - keep direct generated fuzz evidence current after each new rewrite family,
   - replay the MoonBit debug artifact late-tail neighborhood once neighboring skipped passes are available.

## Current validation evidence

The first active-partial slice has direct generated-module oracle evidence:

- `moon test` passes for the focused registry, rewrite, and touched-cleanup tests.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-eqz-constdrop-10k` compared `9975/10000` mixed-generator cases after the block-wrapped `eqz` condition and const-drop body self-guard slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-condprefix-10k` compared `9975/10000` mixed-generator cases after the no-op condition-prefix self-guard slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-blockcond-10k` compared `9975/10000` mixed-generator cases after the block-wrapped condition-read self-guard slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-nested-10k` compared `9975/10000` mixed-generator cases after the nested self-guard slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-revcompare-10k` compared `9975/10000` mixed-generator cases after the bidirectional compare-const self-guard slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-eqz-10k` compared `9975/10000` mixed-generator cases after the `i32.eqz` self-guard slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-if-return-10k` compared `9975/10000` mixed-generator cases after the exact `if return; set` slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-ifreturn-cond-10k` compared `9975/10000` mixed-generator cases after the eqz and bidirectional compare `if return; set` slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-block-ifreturn-10k` compared `9975/10000` mixed-generator cases after the block-wrapped-condition `if return; set` slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-ifreturn-setblock-10k` compared `9975/10000` mixed-generator cases after the block-wrapped-set `if return; set` slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-ifreturn-blockcond-setblock-10k` compared `9975/10000` mixed-generator cases after the block-wrapped-condition+set `if return; set` slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-nested-blockcond-ifreturn-10k` compared `9975/10000` mixed-generator cases after the nested block-wrapped condition `if return; set` slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-blockyield-ifreturn-10k` compared `9975/10000` mixed-generator cases after the block-yielded external condition-operator `if return; set` slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-blockyield-blockset-ifreturn-10k` compared `9975/10000` mixed-generator cases after the block-yielded condition plus block-wrapped set `if return; set` slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-transparent-10k-final` compared `9975/10000` mixed-generator cases after the transparent self-guard slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-blockyield-selfguard-10k` compared `9975/10000` mixed-generator cases after the block-yielded external condition-operator self-guard slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-pure-condition-10k` compared `9975/10000` mixed-generator cases after the simple pure-condition self-guard slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-bitwise-condition-10k` compared `9975/10000` mixed-generator cases after the bitwise pure-condition self-guard slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-shift-rotate-condition-10k` compared `9975/10000` mixed-generator cases after the shift/rotate pure-condition self-guard slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-unary-condition-10k` compared `9975/10000` mixed-generator cases after the unary pure-condition self-guard slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-i64-compare-condition-10k` compared `9975/10000` mixed-generator cases after the i64 equality/compare pure-condition self-guard slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-i64-value-condition-10k` compared `9975/10000` mixed-generator cases after the non-trapping i64 value pure-condition self-guard slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-float-compare-condition-10k` compared `9975/10000` mixed-generator cases after the f32/f64 compare pure-condition self-guard slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-blockyield-pure-ops-10k` compared `9975/10000` mixed-generator cases after the block-yielded external-operator after pure block condition self-guard and `if return; set` slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-blockyield-external-pure-10k` compared `9975/10000` mixed-generator cases after the block-yielded external pure-condition self-guard and `if return; set` slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-blockyield-short-external-pure-10k` compared `9975/10000` mixed-generator cases after the block-yielded short external pure-operator self-guard and `if return; set` slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-blockyield-reverse-external-pure-10k` compared `9975/10000` mixed-generator cases after the block-yielded reverse external pure-operator self-guard and `if return; set` slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-external-guardrails-10k` compared `9975/10000` mixed-generator cases after the external block-yielded guardrail-negative slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-runtime-blocks-10k` compared `9975/10000` mixed-generator cases after the adjacent runtime block propagation slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --generator gen-valid --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-rotw-gen-valid-10k` matched Binaryen on `10000/10000` normalized cases with `0` validation failures and `0` mismatches.

The earlier `.tmp/pass-fuzz-sgo-10k` mixed run found seven mismatches from missing multi-instruction global-initializer folding and over-eager reference-constant replacement in element item expressions; focused regressions now cover those families.

This evidence validates the current generated-input subset, but it does not close the remaining Binaryen rewrite families, saved debug-artifact parity, or public-preset scheduling.

## Focused next slices after the 2026-05-18 research refresh

Prefer these local slices before more broadening:

1. Add more negative guard tests around the recent helper complexity: wrong set global, non-constant set operand, `if` with `else`, and trailing code after the exact whole-function `if return; set` body.
2. Add further simple pure-condition operators only when they are non-trapping, source/probe-backed, and covered by focused tests; the 2026-05-18 unary, bitwise, shift/rotate, i64-compare, i64-value, and float-compare slices added `i32.clz` / `i32.ctz` / `i32.popcnt`, `i32.and` / `i32.or` / `i32.xor`, `i32.shl` / `i32.shr_s` / `i32.shr_u` / `i32.rotl` / `i32.rotr`, `i64.eqz` and `i64` equality/relational compares, non-trapping i64 unary/arithmetic/bitwise/shift-rotate operators feeding those conditions, plus f32/f64 equality/relational compares.
3. Keep the official safe-side-effect condition positive separate because it needs Binaryen-style upward value-flow reasoning, not just a pure-expression whitelist; the landed `local.tee` negative should stay as a guardrail.
4. Leave broader same-as-init constant-expression equivalence and GC/refinalization-sensitive replacements as separate design slices.
5. Resolve or justify the current touched-count / large-module nested-cleanup guard with artifact and performance evidence before public preset scheduling.

## Bottom line

Current Starshine `simplify-globals-optimizing` strategy is an active but partial module-pass implementation.
It covers the first constant-global / single-use-init / exact-type copy-chain / dead-set / same-init / adjacent-eqz-bidirectional-compare-simple-pure-condition-with-i32-unary-bitwise-shift-rotate-i64-compare-value-and-float-compare plus transparent/nested/block-wrapped/block-yielded/block-yielded-after-pure-block/block-yielded-external-pure/block-yielded-short-external-pure/block-yielded-reverse-external-pure/no-op-prefix/const-drop-body read-only-to-write / exact-eqz-compare-blockcond-nestedblockcond-blockyield-blockyieldset-blockyield-after-pure-block-blockyield-external-pure-blockyield-short-external-pure-blockyield-reverse-external-pure-blockset-combined-if-return-set / straight-line runtime-propagation / touched-cleanup slice and proves the optimizing wrapper shape without the `precompute-propagate` prefix, but it must remain documented as incomplete until the remaining Binaryen global rewrite families, debug-artifact parity, and public preset scheduling land.

## Sources

- [`../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md`](../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md)
- [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md)
- [`../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md`](../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md)
- [`../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`](../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/cmd/fuzz_harness_wbtest.mbt`](../../../../../src/cmd/fuzz_harness_wbtest.mbt)
- [`../../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
