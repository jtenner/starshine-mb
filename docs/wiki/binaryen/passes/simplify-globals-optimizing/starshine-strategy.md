---
kind: concept
status: supported
last_reviewed: 2026-07-07
sources:
  - ../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md
  - ../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md
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

Use this page with the retained 2026-04-24 research inventory, direct tagged source URLs, and [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md).
The purpose here is to map the reviewed Binaryen contract to the exact current Starshine status and the concrete local surfaces a future port should start from. The implementation-readiness and validation ladder now live in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Honest current status

`simplify-globals-optimizing` is **implemented and audit-complete for the current Binaryen `version_130` / Starshine v0.1.0 scope**.
The implementation lives in [`src/passes/simplify_globals_optimizing.mbt`](../../../../../src/passes/simplify_globals_optimizing.mbt) and is wired as an active module pass through [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) and [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt).
The 2026-07-06 through 2026-07-07 recursive audit in [`../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md`](../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md) classified the Binaryen v130 source/lit families, implemented the remaining supported families test-first, recorded source-backed negatives, met the strict 1x timing target, and completed the fresh four-lane direct matrix.

The current local strategy is therefore a maintained supported-contract map:

- keep the public pass spelling active and requestable,
- treat it as a module/global pass rather than a HOT-local peephole,
- preserve the canonical late-post-pass slot in the public `optimize` / `shrink` presets,
- reopen only for a new semantic mismatch, validation failure, measured size/performance regression, or upstream contract drift,
- keep the sibling relation to plain boundary-only `simplify-globals` and `propagate-globals-globally` explicit,
- preserve source-backed exclusions instead of widening generic structured/effect flow without proof.

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
    - tests cover active registration, private mutable constant promotion, touched-only cleanup, startup data-offset propagation, dead-set rewrite, side-effect preservation through dropped set operands, funcref/externref alias same-init guardrails, read-only-to-write self-guards including `i32.eqz`, bidirectional compare-const, nested block-condition, block-wrapped and block-yielded condition reads including `i32.eqz`, block-yielded operators after pure block condition bodies, block-yielded external pure-condition chains, block-yielded short external pure operators, block-yielded reverse external pure operators, the source-backed result-`if` side-effect arm including pure arm-local value flow, pure post-result value flow, the function-level if-return/set variant, and a nested result-if-arm value-flow subset, side-effecting `select` value-flow including the official `select`-through-`i32.eqz` shape and the source-backed independent-call operand shapes, guardrail negatives for unsupported external block-yielded wrong-target, non-constant-write, `else`, trapping-op, trailing-code, and wrong-stack-depth shapes, adjacent/nested plain-block runtime propagation with call and early-exit barriers plus imported/exported and reference-typed runtime fact guardrails, including deeper reference and externref-null call/loop/branch/`try_table`/post-if boundaries plus mixed scalar/reference independent-write preservation, typed `ref.null`, typed externref-null direct/alias/block-result, and direct/alias/block-result `ref.func` function-body replacement, typed element item-expression/ref.func alias preservation for refinalization safety, no-op const/drop prefixes before block-wrapped condition reads, `nop` / void-`block` transparent bodies, no-op const/drop prefixes before the write, plus exact/eqz/bidirectional compare/block-wrapped-condition/nested-block-wrapped-condition/block-yielded-condition/block-yielded-condition+set/block-yielded operators after pure block condition bodies/block-yielded external pure-condition chains/block-yielded short external pure operators/block-yielded reverse external pure operators/block-wrapped-set/block-wrapped-condition+set `if return; set`, and exported mutable-global bailout.
- current preset placement
  - [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
    - local `optimize` / `shrink` presets include the late suffix `duplicate-import-elimination -> simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize -> strip-debug`.
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
The direct pass is inserted into the public `optimize` / `shrink` late-tail presets after direct source, test, compare, and timing proof.

### 3. The landed subset covers both SGO backlog halves narrowly

The current implementation includes:

- a module-owned global fact table over imports, exports, table initializers, global initializers, element item expressions, data offsets, and function bodies,
- practical immutability promotion for private never-written globals,
- single-use global-initializer folding into later global initializers,
- exact-type immutable global-copy-chain canonicalization to the earliest compatible ancestor in global initializers and function bodies,
- never-read, direct literal/ref-null/ref.func same-as-init with guardrails for expression and result-block non-matches plus defined `global.get`/alias-init one-pass/two-pass and imported/exported-boundary behavior, including funcref and externref alias chains, adjacent/eqz/bidirectional compare-const/simple-pure-condition (including source-backed i32 unary/bitwise/shift-rotate ops, i64 equality/compare and non-trapping value ops, f32/f64 compares, non-trapping f32/f64 value operators, and non-trapping numeric conversion/reinterpret/sign-extension/trunc_sat operators, non-trapping `ref.is_null` / `ref.eq` predicates, and `local.get` pure operands), transparent, nested, block-wrapped-condition, block-yielded-condition, block-yielded operators after pure block condition bodies, block-yielded external pure-condition chains, block-yielded short external pure operators, block-yielded reverse external pure operators, no-op-condition-prefix, const-drop-body, source-backed result-`if` side-effect arm including pure arm-local value flow, pure post-result value flow, the function-level if-return/set variant, nested result-if-arm value flow, and nested result-if-arm pure-suffix value flow, and side-effecting `select` value-flow including `select` through `i32.eqz` for both guarded-write and if-return/set tails, independent-call first/second-operand read-only-to-write self-guards, independent-call and independent memory-op compare operand guarded-write and if-return self-guards, independent memory-op, independent table-op, and independent constant-local-tee first/second-operand select self-guards, and the block-prefix independent-call, independent memory-op, independent table-op (table.size/table.grow/table.set/table.fill/table.copy/table.init/elem.drop), independent local-write, and independent global-write condition subsets and if-return variants, and exact/eqz/bidirectional compare/block-wrapped-condition/nested-block-wrapped-condition/block-yielded-condition/block-yielded-condition+set/block-yielded operators after pure block condition bodies/block-yielded external pure-condition chains/block-yielded short external pure operators/block-yielded reverse external pure operators/block-wrapped-set/block-wrapped-condition+set `if return; set` read-only-to-write `global.set` rewriting to `drop(value)` with the writer marked as touched,
- supported single-instruction constant `global.get` replacement in function bodies, including typed `ref.null`, typed externref-null direct/alias/block-result, and direct, alias, and block-result `ref.func` cases that the pipeline validates after replacement,
- startup constant propagation into table initializers, global initializers, element offsets, and data offsets,
- single-const global write propagation, including imported/exported globals and reference-typed `ref.func` / `ref.null` facts, along straight-line, top-level-noise, adjacent/nested plain-block, and if-then-body runtime traces with call/control/early-exit barriers plus guardrail coverage for independent writes including mixed scalar/reference writes, latest-write wins, reference, externref-null, and scalar loops, `try_table` barriers, post-if non-joins, and else-arm conservatism,
- reference-typed element item expression preservation, including `ref.func` globals and aliases, until exact type/refinalization breadth lands,
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
- broader same-as-init expression matching beyond the landed direct literal/ref-null/ref.func write shape and the probed defined-`global.get`/alias-init repeated-run boundary,
- broader `read-only-to-write` structural matching and its whole-pass iteration beyond the landed adjacent/eqz/bidirectional compare-const/simple-pure-condition (now including i32 unary/bitwise/shift-rotate ops, i64 equality/compare and non-trapping value ops, f32/f64 compares, non-trapping f32/f64 value operators, and non-trapping numeric conversion/reinterpret/sign-extension/trunc_sat operators, non-trapping `ref.is_null` / `ref.eq` predicates, and `local.get` pure operands), transparent, nested, block-wrapped-condition, block-yielded-condition, block-yielded operators after pure block condition bodies, block-yielded external pure-condition chains, block-yielded short external pure operators, block-yielded reverse external pure operators, no-op-condition-prefix, const-drop-body, the 2026-07-06 source-backed safe-side-effect result-`if` arm subset where one arm is the global read and the other arm may have independent effects, including pure operators inside the selected arm, pure post-result operators before the final guarded-write condition, and the function-level if-return/set variant, the first official `select` value-flow subset where independent load/local.tee operand effects stay before the global-derived select condition, the official `select` through `i32.eqz` subset, the source-backed independent-call and independent memory-op first/second-operand `select` subsets including their if-return variants, the official nested-thrice subset where a nested same-global guard prefix yields the final same-global read to the next guarded write, and the official multi-global nested-body subset where nested different-global guards are allowed around the guarded constant write, plus exact/eqz/bidirectional compare/block-wrapped-condition/nested-block-wrapped-condition/block-yielded-condition/block-yielded-condition+set/block-yielded operators after pure block condition bodies/block-yielded external pure-condition chains/block-yielded short external pure operators/block-yielded reverse external pure operators/block-wrapped-set/block-wrapped-condition+set `if return; set` shapes; the main next source-backed gap remains the rest of Binaryen's side-effecting-but-safe condition value-flow matching and full `FlowScanner` equivalence, not more isolated pure syntactic variants,
- broader copy-chain/type-refinalization cases beyond the landed exact-type immutable ancestor rewrite and probed typed element item-expression conservatism,
- broader runtime linear-trace propagation beyond the landed straight-line/top-level-noise, plain-block, if-then-body, and imported/exported same-trace single-const write facts, including the probed `ref.func` / `ref.null` reference fact guardrails,
- type/refinalization breadth for replacements that change reference precision,
- debug-artifact Binaryen parity evidence for the isolated pass and late-tail neighborhood,
- freshness-reviewed full-matrix evidence after the green dedicated-profile `10000`, regular GenValid `100000`, random-all `10000`, explicit wasm-smith mismatch-free `9956/10000` compared lane (with 44 Binaryen/tool failures classified separately), and representative pass-local 1x timing lanes,
- direct Binaryen oracle replay after each newly-added global rewrite family; latest pure if-arm, post-result-if-arm, if-arm if-return, nested-if-arm pure-suffix, and multi-global nested smokes are green but not a full closeout-lane freshness replacement.

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

The first active-partial slice has direct generated-module oracle evidence. The 2026-07-06 recursive audit added the dedicated `simplify-globals-optimizing-all` GenValid aggregate with six leaves: initializer folding, same-init/dead-set, read-only-to-write, startup propagation, runtime propagation, and nested cleanup payoff. Focused generator tests passed, a 200-case profile smoke at `.tmp/pass-fuzz-sgo-genvalid-all-smoke-200` compared `200/200` with all six leaves sampled, and the closeout-scale dedicated lane `.tmp/pass-fuzz-sgo-genvalid-simplify-globals-optimizing-all-10000` compared `10000/10000` with `10000` normalized matches, `0` mismatches, `0` validation/generator/property/command failures, and all six leaves sampled.

- `moon test` passes for the focused registry, rewrite, touched-cleanup, dedicated-profile generator tests, and the select/value-flow read-only-to-write fixtures.
- A post-select regular GenValid smoke at `.tmp/pass-fuzz-sgo-select-flow-genvalid-1000` compared `1000/1000`, with `1000` normalized matches and `0` mismatches/failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-typed-externref-body-10k` compared `9975/10000` mixed-generator cases after the typed externref function-body guardrail slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-typed-ref-func-body-10k` compared `9975/10000` mixed-generator cases after the typed ref-func function-body guardrail slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-mixed-independent-runtime-10k` compared `9975/10000` mixed-generator cases after the mixed scalar/reference independent runtime guardrail slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-externref-deep-control-10k` compared `9975/10000` mixed-generator cases after the externref deep-control runtime guardrail slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-externref-alias-guardrails-10k` compared `9975/10000` mixed-generator cases after the externref-alias same-init guardrail slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-reference-alias-guardrails-10k` compared `9975/10000` mixed-generator cases after the reference-alias same-init guardrail slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-reference-runtime-guardrails-10k` compared `9975/10000` mixed-generator cases after the reference-runtime guardrail slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
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
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-float-value-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures` and dedicated profile `.tmp/pass-fuzz-sgo-float-value-dedicated-1000` both compared `1000/1000`, normalized `1000`, and had zero mismatches or failures after the f32/f64 non-trapping value-operator pure-condition slice. The later ref-predicate slice likewise passed regular `.tmp/pass-fuzz-sgo-ref-pure-genvalid-1000` and dedicated `.tmp/pass-fuzz-sgo-ref-pure-dedicated-1000` smokes with `1000/1000` normalized and zero failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-blockyield-pure-ops-10k` compared `9975/10000` mixed-generator cases after the block-yielded external-operator after pure block condition self-guard and `if return; set` slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-blockyield-external-pure-10k` compared `9975/10000` mixed-generator cases after the block-yielded external pure-condition self-guard and `if return; set` slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-blockyield-short-external-pure-10k` compared `9975/10000` mixed-generator cases after the block-yielded short external pure-operator self-guard and `if return; set` slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-blockyield-reverse-external-pure-10k` compared `9975/10000` mixed-generator cases after the block-yielded reverse external pure-operator self-guard and `if return; set` slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-external-guardrails-10k` compared `9975/10000` mixed-generator cases after the external block-yielded guardrail-negative slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-runtime-blocks-10k` compared `9975/10000` mixed-generator cases after the adjacent runtime block propagation slice, matched all `9975`, found `0` normalized mismatches, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --generator gen-valid --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-rotw-gen-valid-10k` matched Binaryen on `10000/10000` normalized cases with `0` validation failures and `0` mismatches.

The earlier `.tmp/pass-fuzz-sgo-10k` mixed run found seven mismatches from missing multi-instruction global-initializer folding and over-eager reference-constant replacement in element item expressions; focused regressions now cover those families.

This evidence validates the current generated-input subset and gives SGO a pass-specific profile for the modern closeout matrix, but it does not close the remaining Binaryen rewrite families or saved debug-artifact parity. The follow-up 2026-07-06 cheap-cleanup slice brought all representative direct timing fixtures under the user-requested 1x Binaryen median bar, and the later unreachable-debris slice preserved that bar: `const-read-1000f` `0.31x`, runtime propagation `0.17x`, read-only-select `0.45x`, initializer folding `0.45x`, and startup offsets `0.62x`. That slice reran focused pass tests, `moon fmt`, `moon test src/passes`, the native `src/cmd` build, a regular GenValid smoke at `.tmp/pass-fuzz-sgo-unreachable-block-cleanup-genvalid-1000` (`1000/1000` normalized), the dedicated profile at `.tmp/pass-fuzz-sgo-genvalid-simplify-globals-optimizing-all-unreachable-block-cleanup-10000` (`10000/10000` normalized), and explicit wasm-smith at `.tmp/pass-fuzz-sgo-wasm-smith-10000-unreachable-block-cleanup` (`9956/10000` compared, `9956` normalized, `0` mismatches, `44` Binaryen/tool command failures).

Random-all is now green after two SGO-only large-function cleanup follow-ups. The first escape hatch removed the dead tail after leading unreachable control in large touched functions but left `65` `coverage-forced-portable` mismatches from remaining const-trunc/pure-prefix debris. The second safe trunc-prefix slice recognizes only the generated in-range constant `12` float-to-int trunc/drop batch before a void block that exits to a guaranteed `unreachable`, preserves potentially trapping NaN/out-of-range prefixes, drops now-unused locals, and reduces `.tmp/pass-fuzz-sgo-genvalid-random-all-profiles-10000-safe-trunc-prefix-locals` to `10000/10000` normalized with zero mismatches/failures. Representative timing after that slice still meets 1x: `const-read` `0.285x`, runtime propagation `0.164x`, read-only-select `0.422x`, initializer folding `0.348x`, and startup offsets `0.637x`.

## Focused next slices after the 2026-05-18 research refresh

Prefer these local slices before more broadening:

1. Add more negative guard tests around the recent helper complexity: wrong set global, non-constant set operand, `if` with `else`, and trailing code after the exact whole-function `if return; set` body.
2. Add further simple pure-condition operators only when they are non-trapping, source/probe-backed, and covered by focused tests; the 2026-05-18 unary, bitwise, shift/rotate, i64-compare, i64-value, float-compare, and float-value slices added `i32.clz` / `i32.ctz` / `i32.popcnt`, `i32.and` / `i32.or` / `i32.xor`, `i32.shl` / `i32.shr_s` / `i32.shr_u` / `i32.rotl` / `i32.rotr`, `i64.eqz` and `i64` equality/relational compares, non-trapping i64 unary/arithmetic/bitwise/shift-rotate operators feeding those conditions, plus f32/f64 equality/relational compares and non-trapping f32/f64 value operators feeding those compares.
3. Keep remaining official safe-side-effect condition positives separate because they need Binaryen-style upward value-flow reasoning, not just a pure-expression whitelist; the landed result-`if` / pure-arm / if-return / nested-if-arm and `select` / select-if-return / independent select-operand / independent compare-operand subsets should stay narrow, and the flow-into-`local.tee` / extra-read-after-select / trapping-load-address / call-parameter / `memory.grow`-delta / `table.grow`-delta negatives should stay as guardrails.
4. Leave broader same-as-init constant-expression equivalence, fixed-point widening beyond the observed defined-`global.get`/alias-init repeated-run boundary, and GC/refinalization-sensitive replacements as separate design slices.
5. Keep the 1x direct timing frontier guarded: SGO-owned cheap cleanup now handles const/drop, simple i32 const folds, side-effecting select/empty-if cleanup including independent load/call/memory-op/table-op/local-tee operands, select independent-call/memory-op/table-op/local-tee if-return shells, independent-call, independent memory-op, and independent table-op compare/empty-if and compare/if-return shells, plus block-prefix independent-call (zero-parameter/result and zero-parameter/void), memory-op, and table-op (table.size/table.grow/table.set/table.fill/table.copy/table.init/elem.drop) guarded-write and if-return shells, no-global unreachable result-block/drop debris, large-batch final-shape pruning for const-read/runtime-propagation/read-only-select surfaces, and the narrow generated safe-trunc prefix before guaranteed unreachable tails in large touched functions. Reopen this item if a new representative SGO fixture exceeds Binaryen median time or if broader `FlowScanner` work creates touched-function nested cleanup pressure again.

## Bottom line

Current Starshine `simplify-globals-optimizing` strategy is an active but partial module-pass implementation.
It covers the first constant-global / single-use-init / exact-type copy-chain / dead-set / same-init / adjacent-eqz-bidirectional-compare-simple-pure-condition-with-i32-unary-bitwise-shift-rotate-i64-compare-value-float-compare-and-float-value plus transparent/nested/block-wrapped/block-yielded/block-yielded-after-pure-block/block-yielded-external-pure/block-yielded-short-external-pure/block-yielded-reverse-external-pure/no-op-prefix/const-drop-body/result-if-arm/pure-arm/if-return/select-value-flow/select-eqz-if-return/select-operand read-only-to-write / exact-eqz-compare-blockcond-nestedblockcond-blockyield-blockyieldset-blockyield-after-pure-block-blockyield-external-pure-blockyield-short-external-pure-blockyield-reverse-external-pure-blockset-combined-if-return-set / straight-line runtime-propagation / touched-cleanup slice and proves the optimizing wrapper shape without the `precompute-propagate` prefix, but it must remain documented as incomplete until the remaining Binaryen global rewrite families, debug-artifact parity, and public preset scheduling land.

## Sources

- [`../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md`](../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md)
- [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md)
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

## 2026-07-06 local-set compare FlowScanner addendum

Starshine now covers the source-backed independent constant `local.set` compare-operand subset: a block condition may write a constant local, compare `global.get $g` with `local.get $tmp` in either operand order, and flow only to the same-global guarded write or function-level `if return; set` tail. The value-flow guardrail remains strict: if `global.get $g` feeds the `local.set` value, the read is not counted as safe. Focused tests and 1000-case regular/dedicated smokes are recorded in [`fuzzing.md`](./fuzzing.md) and the kickoff research note.

## 2026-07-06 global-set compare FlowScanner update

Starshine now covers the source-backed independent `global.set` compare-operand subset: `global.get $guard` compared with a result block that performs `const; global.set $other; const`, in either operand order and in the function-level `if return; set` matcher. The implementation preserves the independent `$other` write while removing the fake `$guard` guard shell, and it continues to reject guarded values flowing into `global.set $other`. This is another narrow bridge toward Binaryen `FlowScanner`, not a claim of generic parent/child equivalence.

## 2026-07-06 memory-store compare FlowScanner update

Starshine now covers the source-backed independent memory-store compare-operand subset for constant and local-fed store operands: `global.get $guard` compared with a result block that performs `const/local.get address; const/local.get value; i32.store; const`, in either operand order and in the function-level `if return; set` matcher. The implementation preserves the independent store while removing the fake `$guard` guard shell, and it continues to reject guarded values flowing into the store address or value. This is still a narrow bridge toward Binaryen `FlowScanner` behavior, not generic parent/child equivalence; additional non-constant side-effect operands beyond `local.get` remain unclaimed.

## 2026-07-06 local-fed global-set compare FlowScanner update

Starshine now widens the source-backed independent `global.set` compare-operand subset from constant-only stored values to constant-or-`local.get` values: `global.get $guard` may be compared with a result block that performs `const/local.get; global.set $other; const`, in either operand order and in the function-level `if return; set` matcher. The implementation preserves the independent `$other` write while removing the fake `$guard` guard shell, and it continues to reject guarded values flowing into `global.set $other`. This is still a narrow, source-probed subset and not generic Binaryen `FlowScanner` parent/child equivalence.

## 2026-07-06 local-fed local-write compare FlowScanner update

Starshine now widens the source-backed independent local-write compare subsets from constant-only values to constant-or-`local.get` values. Covered shapes are direct `local.tee` compare operands and block-condition `local.set` / `local.get` compare operands, in both compare operand orders and in the function-level `if return; set` matcher. Guarded-value-to-local-write flow remains excluded. Focused tests plus regular and dedicated 1000-case smokes are recorded in [`fuzzing.md`](./fuzzing.md); broad generic Binaryen `FlowScanner` parent/child equivalence remains open.

## 2026-07-06 local-fed table-grow compare FlowScanner update

Starshine now widens the source-backed independent `table.grow` compare subset from constant-only ref/delta operands to constant-or-`local.get` operands. Covered shapes compare `global.get $guard` with `table.grow 0 (local.get $r) (local.get $n)` in both operand orders and in the function-level `if return; set` matcher. The implementation preserves the independent table growth as `table.grow; drop` after removing the fake `$guard` guard shell, and it continues to reject guarded values flowing into the `table.grow` delta. Focused tests plus regular and dedicated 1000-case smokes are recorded in [`fuzzing.md`](./fuzzing.md); broad generic Binaryen `FlowScanner` parent/child equivalence remains open.

## 2026-07-06 local-fed memory-grow compare/select FlowScanner update

Starshine now widens the source-backed independent `memory.grow` compare and select subsets from constant-only deltas to constant-or-`local.get` deltas. Covered shapes compare `global.get $guard` with `memory.grow (local.get $n)` in both compare operand orders, use `memory.grow (local.get $n)` as either select value operand while the guarded global controls the select, and include the function-level `if return; set` matcher for both families. The implementation preserves the independent memory growth as `memory.grow; drop` after removing the fake `$guard` guard shell, and it continues to reject guarded values flowing into the `memory.grow` delta. Focused tests plus regular and dedicated 1000-case smokes are recorded in [`fuzzing.md`](./fuzzing.md); broad generic Binaryen `FlowScanner` parent/child equivalence remains open.


## 2026-07-06 local-fed table-grow select FlowScanner update

Starshine now widens the source-backed independent `table.grow` select subset from constant-only ref/delta operands to constant-or-`local.get` operands. Covered shapes use `table.grow 0 (local.get $r) (local.get $n)` as either select value operand while the guarded global supplies the other select value/condition, including the function-level `if return; set` matcher. The implementation preserves the independent table growth as `table.grow; drop` after removing the fake `$guard` guard shell, and it continues to reject guarded values flowing into the `table.grow` delta. Focused tests plus regular and dedicated 1000-case smokes are recorded in [`fuzzing.md`](./fuzzing.md); broad generic Binaryen `FlowScanner` parent/child equivalence remains open.

## 2026-07-06 / 2026-07-07 pure-add grow select/compare status

The current Starshine `FlowScanner` model remains intentionally narrow, but the next Binaryen `version_130` pure-add grow positives are implemented: independent `memory.grow` / `table.grow` select and compare operands may use a nontrapping `i32.add` delta over constants or `local.get`s when the guarded global only supplies the other select/compare value for the same-global write or function-level `if return; set` tail. The select subset now covers the probed reverse/second-operand order too, where the pure-add grow is evaluated before `global.get $guard` and then preserved as `grow; drop` after guard-shell removal.

Evidence lives in [`../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md`](../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md) and [`./fuzzing.md`](./fuzzing.md): focused red-first coverage passed after implementation, full SGO file now passes `280/280`, `moon test src/passes` passes `4429/4429`, full `moon test` passes `7868/7868`, and regular/dedicated 1000-case compare smokes for forward select, reverse select, and compare pure-add grow slices are normalized-green. This remains a narrow source-backed subset; do not treat it as generic FlowScanner equivalence.

## 2026-07-07 independent call `i32.add` FlowScanner update

Starshine now covers a source-backed parent/child FlowScanner subset beyond the previous grow-specific follow-ups: an independent zero-parameter/result call may be the sibling operand of `global.get $guard` under a pure `i32.add`, in either operand order and in both direct guarded-write and function-level `if return; set` forms. The implementation preserves the call as `call; drop` after removing the fake guard shell and keeps guarded-value-to-call-argument flow excluded.

Evidence lives in [`../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md`](../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md) and [`./fuzzing.md`](./fuzzing.md): local Binaryen `version_130` probes for all four operand/tail variants reduced `$guard` to immutable, red-first focused coverage failed before implementation and passed after, full SGO file now passes `282/282`, `moon test src/passes` passes `4431/4431`, full `moon test` passes `7870/7870`, and regular/dedicated 1000-case compare smokes are normalized-green. This still does not claim arbitrary side-effect parents, non-`i32.add` effectful sibling parents, extra guarded reads, or generic Binaryen `FlowScanner` equivalence.


## 2026-07-07 independent call nontrapping `i32` binary FlowScanner update

Starshine now widens the previous independent-call-through-`i32.add` subset to source-backed nontrapping pure `i32` binary parents: `i32.add`, `i32.sub`, `i32.mul`, `i32.and`, `i32.or`, `i32.xor`, `i32.shl`, `i32.shr_s`, `i32.shr_u`, `i32.rotl`, and `i32.rotr`. Local Binaryen `version_130` probes reduced all direct/reverse operand forms in this family to immutable `$guard`, while `i32.div_s` / `i32.rem_u` probes kept `$guard` mutable. The implementation remains deliberately narrow: independent zero-parameter/one-result calls are preserved as `call; drop`; call-argument flow and arbitrary side-effect parents stay rejected.

Evidence lives in [`../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md`](../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md) and [`./fuzzing.md`](./fuzzing.md): red-first focused coverage failed before implementation and passed after, full SGO file now passes `283/283`, `moon test src/passes` passes `4432/4432`, regular and dedicated `1000/1000` smokes are normalized-green, and direct timing remains under `1x` Binaryen median on every representative fixture.

## 2026-07-07 independent call binary `i32.eqz` suffix FlowScanner update

Starshine now covers one deeper pure-parent step after the nontrapping `i32` binary independent-call sibling subset: the binary result may flow through `i32.eqz` before the final same-global guarded write or function-level `if return; set` tail. The implementation stays intentionally narrow and source-backed: calls must be zero-parameter/one-result and independent, the parent binary must be one of the nontrapping `i32` operators already accepted by local Binaryen, and only the `i32.eqz` suffix is admitted. Trapping `i32.div_s; i32.eqz`, guarded-value-to-call-argument flow, arbitrary pure suffix chains, extra guarded reads, and generic `FlowScanner` equivalence remain open. Evidence lives in [`../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md`](../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md) and [`./fuzzing.md`](./fuzzing.md); focused tests, full SGO tests, `moon test src/passes`, native build, regular/dedicated 1000-case smokes, and 1x timing are green for this slice.

## 2026-07-07 independent call binary unary-suffix FlowScanner update

Starshine now covers one more source-backed parent-chain step after the nontrapping `i32` binary independent-call sibling subset: the binary result may flow through exactly one nontrapping integer-unary suffix (`i32.clz`, `i32.ctz`, or `i32.popcnt`) before the final same-global guarded write or function-level `if return; set` tail. The implementation remains intentionally narrow: calls must be zero-parameter/one-result and independent, the parent binary must be one of the already accepted nontrapping `i32` operators, and trapping div/rem parents remain excluded even when followed by a unary suffix.

Evidence lives in [`../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md`](../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md) and [`./fuzzing.md`](./fuzzing.md): local Binaryen `version_130` probes accepted direct `i32.mul; i32.clz`, reverse `i32.mul; i32.ctz`, and if-return `i32.xor; i32.popcnt`, while `i32.div_s; i32.clz` kept `$guard` mutable. Red-first focused coverage failed before implementation and passed after; full SGO file remains green at `284/284`, `moon test src/passes` passed `4433/4433`, regular and dedicated 1000-case smokes normalized `1000/1000`, and representative timing stayed under 1x Binaryen median (`read-only-select` worst observed `0.845x`).

## 2026-07-07 independent call binary constant-fed comparison FlowScanner update

Starshine now covers one constant-fed equality parent above the nontrapping `i32` binary independent-call sibling family: one `i32.const` may feed `i32.eq` / `i32.ne` with the binary result in either operand order before the guarded-write or function-level if-return tail. The call remains zero-parameter/one-result and independent, and cleanup preserves it as `call; drop`. Trapping binary parents, relational comparisons, multiple suffixes, guarded-value-to-call-argument flow, arbitrary side-effect parents, extra guarded reads, and generic FlowScanner equivalence remain excluded. Focused TDD, full SGO and pass-package tests, native build, regular/dedicated 1000-case smokes, and 1x timing are green; see [`./fuzzing.md`](./fuzzing.md).

## 2026-07-07 independent `i64` call binary suffix FlowScanner update

Starshine now applies the same narrow strategy to `i64`: enumerate only nontrapping integer binary parents, require an independent zero-parameter/one-result call, and require exactly one boolean-producing `i64.eqz` or constant-fed `i64.eq` / `i64.ne` suffix before the same-global guard tail. SGO-created shells collapse to `call; drop`; trapping div/rem parents remain untouched. This is not a generic typed parent-stack implementation. Relational integer comparisons, deeper pure chains, arbitrary calls/effects, call-argument flow, and extra guarded reads remain open.

## 2026-07-07 independent float call binary-comparison FlowScanner update

Starshine now covers the Binaryen-positive `f32` / `f64` sibling-call chain with an exact typed matcher: an independent zero-parameter/one-result call and guarded same-typed float global feed one of `add`, `sub`, `mul`, `div`, `min`, `max`, or `copysign`, then exactly one same-typed constant-fed `eq`, `ne`, `lt`, `gt`, `le`, or `ge` comparison reaches the same-global guarded-write or function-level if-return tail. Both binary operand orders and both comparison constant orders are accepted. IEEE divide and NaN-sensitive operations are admitted because the probed parent operations are nontrapping; cleanup preserves the independent call as `call; drop`.

The matcher remains intentionally narrower than Binaryen's generic `FlowScanner`: guarded-value-to-call-argument flow, extra guarded reads, multiple/deeper pure suffixes, arbitrary effectful siblings or side-effect parents, and unprobed typed parent chains remain open. Focused/full Moon tests, regular and dedicated `1000/1000` compares, native build, and representative `<=1x` timing are green; the final full four-lane matrix still needs freshness after the latest narrow changes.

## 2026-07-07 generic scalar straight-line FlowScanner update

The strategy now consolidates the independent-call typed matchers behind a scalar provenance parser. The parser tracks the dependent result kind across nontrapping `i32` / `i64` / `f32` / `f64` unary operations, nontrapping conversions and reinterprets, saturating float-to-int conversions, and result-first constant-fed binary/comparison parents. It admits arbitrary parent depth until the value becomes the final `i32` guard. The cleanup side uses the same grammar, so removing the guard preserves the independent call exactly as `call; drop`.

This is the preferred direction over continuing one matcher per opcode chain, but it is not yet the complete generic architecture. The next implementation should generalize the abstract stack from one call-plus-global scalar expression to arbitrary straight-line sibling producers, then preserve each independent unremovable effect while rejecting any effect whose operands depend on the guarded read. Structured result expressions and nested safe-pattern stops must remain handled separately until the flat instruction representation has an equivalent parent/child proof.

## 2026-07-07 constant-first parent-depth update

The scalar parser now models constant-first parents at arbitrary supported depth when their operands form a contiguous typed prefix below the guarded expression. It consumes those constants in LIFO stack order, supports both first call/global operand orders, and gives the same prefix bounds to cleanup so the resulting shell becomes `call; drop`. This closes the probed two-level `i32.mul` then `i32.lt_s` family without broadening to non-constant independent producers. Full tests, two `1000/1000` compare smokes, and representative `0.925x` worst timing are green; generic effect reconstruction, structured parents, and final full-matrix freshness remain open.

## 2026-07-07 reverse pre-parent independent fragment strategy

Cleanup now treats the independent call result before the first call/global parent as a bounded instruction fragment rather than assuming every instruction is removable. The parser tracks scalar result kind across nontrapping unary/conversion instructions, records trapping float-to-int truncations for ordered replay, then verifies the replaced global constant and nontrapping first parent against the existing scalar suffix grammar. Emission preserves `call`, replays only the recorded trap-capable conversions, and drops the final independent result. The dependent guarded-value grammar is unchanged and still rejects trapping parents. The next architecture step remains a general provenance/effect stack for independent calls, loads, grows, and writes rather than more isolated cleanup tuples.

## 2026-07-07 generic independent scalar producer strategy

`SgoScalarIndependentFragment` is now the shared bounded provenance/effect record for the flat scalar family. It records result kind, source bounds, and whether the producer itself must replay. Detection and cleanup use the same producer grammar: zero-parameter scalar calls replay, `memory.size` is removable, and constant-address scalar loads replay their address/load instructions because the load may trap. Producer-local nontrapping unary/conversion instructions are removable; trapping float-to-int conversions are rediscovered for ordered replay only after the whole guard shell matches, avoiding allocation on rejected hot paths.

This is a deliberate intermediate architecture, not a general abstract stack. It excludes local-address/memory64 loads, grows, stores, writes, and arbitrary calls until each class has direct Binaryen probes and effect/provenance tests. A guarded value used as a load address remains a negative. The implementation also keeps cheap candidate gates so the representative read-only-select batch stays within the strict 1x target after local-main rebase.

## 2026-07-07 bounded structured scalar producer strategy

The shared fragment record now admits two source-probed structured producer envelopes without scanning arbitrary control. A single-result numeric `block` may contain either a pure constant/unary result or one already-supported independent scalar fragment whose required trap/effect replay can be reconstructed from the block body. A single-result numeric `if` may be fed by a removable `local.get`/constant condition or a zero-parameter i32 call; both arms must be pure constant/unary scalar expressions of the declared result type. Cleanup discards the pure envelope, preserves a block-contained load as `address; load; drop`, and preserves a call-fed `if` condition as `call; drop`.

The paired negative remains essential: when the guarded global itself supplies the result-`if` condition that selects an observable call arm, the global stays mutable. Type-index/multivalue blocks, branches, loops, effectful arms, and arbitrary structured nesting remain outside this bounded grammar. The next slice should classify broader independent grows/writes and the remaining source/lit inventory rather than generalizing this record into an unchecked control stack.

## 2026-07-07 structured memory-grow producer strategy

The bounded result-block grammar now admits one effectful prefix family: an independent `memory.grow` over a constant or `local.get` delta, or the already-probed nontrapping `i32.add` of those operands, followed by `drop` and a scalar constant result. Detection and cleanup share the same exact prefix proof. Cleanup replays the delta and `memory.grow`; the existing scalar-fragment cleanup supplies the final drop, matching Binaryen's effect order and output shape.

This is not permission to treat arbitrary result-block effects as independent. A guarded global used as the grow delta remains negative; exact later slices classify and cover the additional source-probed write/store/control families while true multivalue and guarded-value-to-effect flow remain negative. The implementation stays allocation-light on rejected paths; representative timing remains under the strict 1x Binaryen median target.

## 2026-07-07 structured local-write and table-grow producer strategy

The bounded effect-prefix classifier now also admits exact independent local-write and table-grow records. A local prefix is `constant-or-local.get; local.set; result-const` or `constant-or-local.get; local.tee; drop; result-const`; replay uses `local.tee` so the shared fragment cleanup can discard the block result without stack underflow, then a narrow one-use cleanup replaces `value; local.tee; drop; local.get` with `value` only when the target local has no other references. A table prefix is `independent-ref; independent-delta; table.grow; drop; result-const`, with both operands restricted to constants or `local.get`s.

Guarded values may not feed the local write or table-grow delta. The final metadata-aware touched `reorder-locals` slice removes the now-unused one-use declaration and remaps local-name metadata, matching Binaryen's `44`-byte stripped fixture. The strategy remains exact-pattern and source-probed rather than an unchecked general local dataflow or structured effect stack.

## 2026-07-07 repeated-local and structured-control strategy

The exact constant local-write cleanup now also recognizes the observed two-read tail `i32.const; local.tee; drop; local.get; local.get; i32.add`. It replaces the reads with the folded constant and lets dead-local-write cleanup remove the assignment. This is an intentional measured Starshine win over Binaryen v130's retained `local.set`: stripped pass-local output is `47` bytes versus Binaryen's `51`, and both converge to the identical `37`-byte `wasm-opt -Oz --strip-debug` output. Parameter-fed two-read cases already lower to repeated parameter reads in both tools; reassignment remains outside this narrow rule.

The structured producer classifier now admits scalar `loop` producers and otherwise-unclassified scalar result blocks only when their bodies contain no global references. The original structured instruction is replayed and dropped, preserving branches, traps, and effects while removing the unrelated global guard. Direct v130 probes confirm that single-result type-index blocks, independent scalar loops, independent branchful scalar blocks, and result `if`s with an effectful independent arm are positive; true multivalue blocks are negative in Binaryen and remain excluded.

## 2026-07-07 guarded structured value-flow strategy

The read-only-to-write counter now recognizes two bounded cases where the guarded value itself originates inside structured control: an exact scalar result loop containing only the guarded `global.get`, and the probed branchful result block where that value is carried to `br_if`'s target or replaced by a scalar constant on fallthrough. The result then uses the existing typed pure-suffix and guarded-write/if-return matcher. This is intentionally not a blanket structured replay rule: nested side-effecting conditions, arbitrary branch stacks, multiple guarded reads, type-index generalization, and multivalue remain outside the matcher.

The remaining cleanup drift is measured as parity work, not accepted representation drift. One-use local declarations cost Starshine two stripped bytes (`46` versus `44`), and effectful result-if residual cleanup costs two (`65` versus `63`); both converge under shared downstream `-Oz`. A trial declaration deletion was reverted after it left local-name metadata out of range, so declaration cleanup must be metadata-aware. The 51-repeat timing decision remains `<=1x`, worst `0.977x` on read-only-select.
