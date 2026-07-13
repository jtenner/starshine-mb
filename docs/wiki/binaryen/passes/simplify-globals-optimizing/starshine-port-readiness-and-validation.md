---
kind: concept
status: supported
last_reviewed: 2026-07-07
sources:
  - ../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md
  - ../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md
  - ../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./linear-traces-read-only-to-write-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-globals/index.md
  - ../propagate-globals-globally/index.md
  - ../duplicate-import-elimination/index.md
  - ../remove-unused-module-elements/index.md
  - ../string-gathering/index.md
  - ../reorder-globals/index.md
  - ../directize/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine port readiness and validation for `simplify-globals-optimizing`

Use this page after the source contract pages:

- [`./binaryen-strategy.md`](./binaryen-strategy.md) explains what Binaryen does.
- [`./wat-shapes.md`](./wat-shapes.md) shows the important transformed shapes.
- [`./starshine-strategy.md`](./starshine-strategy.md) records current local status.

This page answers the practical porting question: now that Starshine has a signed-off v0.1.0 supported surface, what optional Binaryen-breadth work remains and how should any future slice be validated?

## Current port-readiness summary

`simplify-globals-optimizing` is signed off for the current Starshine v0.1.0 direct-pass, nested-runtime, transformation-family, and late-tail scheduling surface against Binaryen `version_130`. The recursive closeout reviewed every top-level `SimplifyGlobals.cpp` family and the broad `FlowScanner` contract, implemented supported gaps test-first, documented source-backed negatives, met strict `<=1x` pass-local timing, and completed the fresh four-lane matrix. Reopen only for new evidence of a semantic mismatch, wasm validation failure, upstream behavior drift, targeted artifact/code-size need, or measured SGO-specific wall-time regression. The current closeout record is [`../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md`](../../../raw/research/1555-2026-07-06-sgo-audit-kickoff-safe-effect-read.md).

The useful local status is:

| Surface | Current state | Code / doc anchor |
| --- | --- | --- |
| Public pass name | active module pass; plain `simplify-globals` remains boundary-only | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) |
| Active request behavior | direct requests run the audited SGO core plus touched nested cleanup | [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) |
| Implementation owner | first constant/dead-set/same-init/read-only-to-write/startup/single-use-init/exact-copy-chain/plain-block/if-then-runtime subset | [`src/passes/simplify_globals_optimizing.mbt`](../../../../../src/passes/simplify_globals_optimizing.mbt) |
| Focused tests | registry, constants, single-use init folding, exact-type immutable copy chains, dead sets, single-const/ref-null same-init writes plus expression/result-block and funcref/externref alias guardrails, narrow read-only-to-write self guards including `i32.eqz`, bidirectional compare-const, simple pure-condition positives with i32 unary/bitwise/shift-rotate ops, i64 equality/compare and non-trapping value ops, plus f32/f64 compares, nested block-condition, block-wrapped pure-condition and block-yielded condition reads including `i32.eqz`, no-op const/drop prefixes before block-wrapped condition reads, `nop` / void-`block` transparent bodies, no-op const/drop prefixes before the write, exact/eqz/bidirectional compare/pure-condition/block-wrapped-condition/block-wrapped-pure-condition/nested-block-wrapped-condition/block-yielded-condition/block-yielded-condition+set/block-wrapped-set/block-wrapped-condition+set `if return; set` positives and trailing-code negatives, source-backed result-`if` arm including pure arm-local value flow, pure post-result flow, the if-return variant, nested result-if-arm flow, and nested result-if-arm pure-suffix flow, `select` value-flow, `select` through `i32.eqz`, `select; i32.eqz` through the if-return matcher, source-backed independent-call, independent memory-op, independent table-op, and independent constant-local-tee first/second-operand `select` flow including their if-return variants, independent-call, independent memory-op, independent table-op, and independent constant-local-tee compare operand guarded-write and if-return flow, block-prefix independent-call (zero-parameter/result and zero-parameter/void), independent memory-op, independent local-write, independent global-write, and independent table-op condition flow including the if-return variants, official nested-thrice same-pattern, and official multi-global nested-body safe-side-effect positives, plus flow-into-`local.tee`, call-parameter, wrong-target, non-constant set operand, `else`, and trapping-load-address negatives, straight-line/top-level-noise/adjacent/nested plain-block and if-then-body runtime propagation, imported/exported and reference-typed runtime fact guardrails including deeper reference and externref-null call/loop/branch/`try_table`/post-if boundaries plus pre-block nested call/branch barriers and mixed scalar/reference and same-global non-constant independent-write preservation, harmless block-body drop/pure-noise positives, call/control/non-constant/exported/imported/loop/try_table/post-if-join/else-arm guardrails, startup offsets, touched-only nested cleanup, current nested cleanup pass-order and guard characterization (default cleanup sequence from `dead-code-elimination` through `redundant-set-elimination` and `vacuum` with no `precompute-propagate`, function-body rewrites trigger cleanup but startup-only data-offset and global-initializer rewrites do not, touched-function-count and module-function-count no longer skip cleanup, and individually large touched functions with `> 192` locals or `> 1000` instructions are filtered out of the nested cleanup set), typed `ref.null`, typed externref-null direct/alias/block-result, and direct/alias/block-result `ref.func` function-body replacement, typed element item/ref.func alias bailouts, exported bailout | [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../../src/passes/simplify_globals_optimizing_test.mbt) |
| Direct fuzz evidence | 10000/10000 gen-valid normalized matches; 9975/10000 mixed-generator compared matches with only Binaryen/tool command failures; post-select 1000/1000 regular GenValid smoke; post-select-eqz and post-select-eqz-if-return regular and dedicated 1000/1000 smokes; post-nested-thrice regular and dedicated 1000/1000 smokes; post-multi-global-nested regular and dedicated 1000/1000 smokes; post-pure-if-arm regular and dedicated 1000/1000 smokes; post-select-call, post-independent-call-compare, post-independent-memory-compare, post-independent-table-compare, post-independent-table-select, post-independent-local-tee-select, post-select-memory, post-select-second-call, post-select-second-memory, post-select-call-if-return, post-select-memory-if-return, post-block-prefix-call, post-if-return-block-prefix-call, post-block-prefix-void-call, post-block-prefix-memory, post-block-prefix-local, post-if-arm-if-return, post-nested-if-arm, and post-nested-if-arm-pure-suffix regular and dedicated 1000/1000 smokes; dedicated `simplify-globals-optimizing-all` 10000/10000 profile lane; regular GenValid 100000/100000; wasm-smith 9956/10000 compared with zero mismatches plus 44 Binaryen/tool failures; random-all 10000/10000 normalized plus post-independent-call-compare, post-independent-memory-compare, post-independent-table-compare, post-independent-table-select, and post-independent-local-tee-select random-all 1000/1000 smokes | [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) |
| Active presets | public `optimize` / `shrink` append the accepted late-tail suffix after direct ordered-neighborhood proof | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) |
| Backlog | `[O4Z-AUDIT-SGO]` is complete for v0.1.0; optional follow-ups remain deferred and reopen only on concrete new evidence | [`agent-todo.md`](../../../../../agent-todo.md) |
| Canonical placement | after `duplicate-import-elimination`, before `remove-unused-module-elements` | [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md) |

The latest 2026-07-06 / 2026-07-07 FlowScanner slices also cover local-fed `memory.grow` compare/select operands, local-fed `table.grow` select operands, pure-add grow select/compare operands, and independent zero-parameter/result call sibling operands under pure `i32.add`. `memory.grow` deltas may be constants or `local.get`s in guarded-write and function-level `if return; set` compare/select matchers; pure-add grow deltas may be nontrapping `i32.add` over constants or `local.get`s for the probed grow families; and independent calls may be preserved as `call; drop` when the guarded global only supplies the other `i32.add` operand. Latest call-add smokes live at `.tmp/pass-fuzz-sgo-call-add-genvalid-1000` and `.tmp/pass-fuzz-sgo-call-add-dedicated-1000`; earlier grow smokes are recorded in `fuzzing.md`. Guarded-value-to-`memory.grow` / `table.grow` / call-argument flow remains excluded.

That means the wiki should teach the pass as an audit-complete v0.1.0 module/global port against the reviewed Binaryen v130 behavior families, not as a HOT peephole and not as permission to widen beyond the documented source-backed contract. The 2026-05-18 current-main refresh found no semantic drift from Binaryen `version_129` at observed `main` commit `d3029d2b975488acdf9253eb2994a3fc55bd3549`, so the remaining optional breadth map remains current.

## Minimum viable Starshine slice

A source-faithful complete port must preserve Binaryen's two identities:

1. shared global-simplification algorithm, and
2. optimizing wrapper that reruns ordinary function cleanup on exactly the changed functions.

The current first slice covers fact collection, single-use initializer folding into later globals, exact-type immutable copy-chain canonicalization, a small constant/dead-set/same-init/read-only-to-write subset with direct literal/ref-null/ref.func same-init guardrails, including funcref/externref alias-chain one-run/two-run and import/export boundaries, plus `i32.eqz`, bidirectional compare-const, a simple pure-condition family with source-backed i32 unary/bitwise/shift-rotate ops, i64 equality/compare and non-trapping value ops, plus f32/f64 compares, nested block-condition, block-wrapped pure-condition and block-yielded condition reads including `i32.eqz`, no-op const/drop prefixes before block-wrapped condition reads, `nop` / void-`block` transparent self-guard bodies, no-op const/drop prefixes before the write, and the exact/eqz/bidirectional compare/pure-condition/block-wrapped-condition/block-wrapped-pure-condition/nested-block-wrapped-condition/block-yielded-condition/block-yielded-condition+set/block-wrapped-set/block-wrapped-condition+set `if return; set` family, startup propagation for supported constants, straight-line/top-level-noise, plain-block, and if-then-body runtime propagation for single-const private/imported/exported global writes, reference-typed `ref.func` / `ref.null` runtime fact guardrails including deeper control barriers, externref-null analogs, and mixed scalar/reference independent-write preservation, typed `ref.null` / typed externref-null direct-alias-block-result / direct, alias, and block-result `ref.func` function-body replacement guardrails, reference-typed element item bailouts including `ref.func` aliases, and the no-`precompute-propagate` touched cleanup wrapper. The remaining practical landing order is:

1. **Broaden the fact table**
   - add Binaryen's `nonInitWritten` and `readOnlyToWrite` facts to the landed imported/exported/read/written table;
   - keep scanning function bodies and module-level initializer / segment-offset expressions through the module-owned path.
2. **Complete startup-only propagation**
   - keep the landed supported-constant propagation into table initializers, global initializers, element offsets, and data offsets;
   - keep the landed single-use global-initializer folding into later globals;
   - add any remaining Binaryen startup families without reintroducing unsafe reference-typed element item replacement.
3. **Complete dead or redundant write repair**
   - keep rewriting removable `global.set $g value` as `drop(value)`;
   - keep the landed single-const same-as-init write detection, including defined `global.get`-init one-pass/two-pass and imported-boundary guardrails, narrow read-only-to-write self-guard detection, and exact/eqz/bidirectional compare/pure-condition/block-wrapped-condition/block-wrapped-pure-condition/nested-block-wrapped-condition/block-yielded-condition/block-yielded-condition+set/block-wrapped-set/block-wrapped-condition+set `if return; set` family, including the current `i32.eqz`, bidirectional compare-const, nested block-condition, block-wrapped pure-condition and block-yielded condition reads including `i32.eqz`, no-op const/drop prefixes before block-wrapped condition reads, transparent `nop` / void-`block` body support, and no-op const/drop prefixes before the write;
   - add broader same-as-init expression matching only with one-pass/repeated-run oracle evidence, and add broader `read-only-to-write` shapes so the pass can remove more fake state without violating ordering;
   - extend the landed simple pure-condition bridge only with focused source-backed non-trapping operators; the current unary, bitwise, shift/rotate, i64-compare, i64-value, float-compare, float-value, numeric-conversion, ref-predicate, and local-get bridge covers `i32.clz` / `i32.ctz` / `i32.popcnt`, `i32.and` / `i32.or` / `i32.xor`, `i32.shl` / `i32.shr_s` / `i32.shr_u` / `i32.rotl` / `i32.rotr`, `i64.eqz` and `i64` equality/relational compares, non-trapping i64 unary/arithmetic/bitwise/shift-rotate operators feeding those conditions, f32/f64 equality/relational compares, non-trapping f32/f64 value operators feeding those compares, source-backed non-trapping numeric conversions / reinterprets / sign-extension / `trunc_sat`, and non-trapping `ref.is_null` / `ref.eq` predicates while keeping trapping float-to-int `trunc` out of the whitelist;
   - keep side-effecting-but-safe condition positives as a later value-flow slice because Binaryen's actual matcher is effect/value-flow based rather than a list of adjacent syntax forms.
4. **Broaden immutable-copy canonicalization only with type proof**
   - keep the landed exact-type immutable ancestor rewrite;
   - leave subtype/refinalization extensions for later unless deliberately documented.
5. **Broaden runtime trace propagation**
   - keep the landed straight-line single-const write/read propagation;
   - expand only while the current linear execution story is still simple;
   - clear current facts around calls, nonlinear control, and writes to tracked globals.
6. **Optimizing wrapper hardening**
   - keep the landed exact touched-function set from replacement/removal phases;
   - continue rerunning Starshine's default function cleanup on those functions only;
   - do **not** prepend `precompute-propagate`, unlike the nearby DAE/inlining optimizing siblings;
   - the current guard is now artifact-informed: nested cleanup runs above the earlier `8` touched-function and `100` defined-function limits; individually large touched functions (`> 192` locals or `> 1000` instructions) are filtered out, and cleanup skips with `reason=large-touched-function` only when every touched function is filtered; startup-only data-offset and global-initializer rewrites leave the touched-function set empty and do not trigger nested cleanup. The direct debug-artifact compare now runs cleanup on the artifact's local-heavy touched functions, makes Starshine smaller than Binaryen, and is accepted for v0.1.0 with the remaining first diff classified as representation-only default-local initialization drift.

Any future breadth implementation should name the newly supported subset and rerun focused oracle evidence instead of reopening the accepted v0.1.0 supported surface by default.

## Transformed-shape coverage to preserve

The first tests should be organized around the shape catalog in [`./wat-shapes.md`](./wat-shapes.md):

| Shape family | First Starshine proof |
| --- | --- |
| Single-use global initializer folding | one global initializer copied into a later initializer; function-use and multi-use negatives remain unchanged |
| Startup propagation | later global / data / elem offsets see earlier constants; imported/exported boundaries remain conservative |
| Dead writes | never-read or same-as-init writes become `drop(value)` rather than disappearing |
| `read-only-to-write` | exact self-guard positives, nested positives, and actual-node / effect / value-flow negatives |
| Immutable-copy chain | compatible ancestor rewrites, exact-type mismatch negatives |
| Runtime propagation | same-linear-trace positives, call and nonlinear-control barriers |
| Type-changing replacements | function-body replacements that the pipeline validates stay covered; typed element item-expression rewrites remain explicit non-goals until Starshine has an exact type/refinalization plan |
| Optimizing wrapper | touched functions receive ordinary cleanup; untouched functions do not; touched-function-count and module-function-count cleanup skips are removed; individually large touched functions (`> 192` locals or `> 1000` instructions) are filtered out, and an all-large touched set still skips with `reason=large-touched-function` |

The shape tests should stay readable enough for beginners, then add advanced stress cases for GC refs, segment offsets, side effects inside conditions, and nested self-guards.

## Validation ladder

Use this validation order for follow-up implementation.

### 1. Registry and request behavior

The current public-surface baseline is:

- `simplify-globals-optimizing` is an active module pass;
- direct active requests run the partial implementation;
- plain `simplify-globals` remains boundary-only;
- public presets explicitly include the accepted late-tail suffix and keep that order under tests.

Any future classification or preset change should update registry/preset tests in the same commit.

### 2. Shared-engine shape tests

Add source-shaped tests beside the implementing module for:

- global fact collection,
- startup propagation,
- write-to-drop repair,
- copy-chain canonicalization,
- runtime trace propagation,
- bailout preservation.

These tests prove the shared global algorithm. They do not prove the optimizing wrapper by themselves.

### 3. Optimizing-wrapper scheduler tests

Add separate tests for:

- exact touched-function set construction,
- nested default-function cleanup on changed functions,
- no nested rerun on unchanged functions,
- no extra `precompute-propagate` prefix,
- validation/writeback after type-changing replacements,
- current scheduler order and guards: the current default cleanup pass list is exact, no `precompute-propagate` prefix appears, `redundant-set-elimination` runs before the final `vacuum`, function-body rewrites trigger cleanup while startup-only data-offset and global-initializer rewrites do not, large touched sets and large modules still run touched cleanup, and individually large touched functions are filtered out.

This is the main behavior that distinguishes `simplify-globals-optimizing` from plain [`../simplify-globals/index.md`](../simplify-globals/index.md).

### 4. Binaryen oracle comparison

Run isolated oracle comparison before late-tail replay:

- `moon build --target native --release src/cmd`
- `bun scripts/pass-fuzz-compare.ts --pass simplify-globals-optimizing ... --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe`
- reduced fixtures from Binaryen's `simplify-globals-*` lit family;
- targeted debug-artifact runs once the module-boundary harness accepts the pass.

Current signed-off supported-surface evidence (with direct artifact drift accepted as representation-only):

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --simplify-globals-optimizing --out-dir .tmp/sgo-direct-debug-artifact-nested-pruned --starshine-bin _build/native/release/build/cmd/cmd.exe` completed direct debug-artifact replay after pruning expensive SGO nested cleanup slots. It stayed valid; canonical wasm/WAT/function compare were unequal and the first difference remained `defined=48 abs=69`, now accepted by user decision as local/default-init representation drift. Starshine stayed smaller than Binaryen (`2,860,269` bytes versus `2,861,435`) and pass-local runtime moved inside the 2x Binaryen floor (`153.143ms` versus Binaryen `107.210ms`). The paired trace `.tmp/sgo-nested-pruned-trace.txt` reported total SGO pass time `139.507ms` and `detail:sgo:nested-total=86.104ms`; the remaining largest nested wrapper slot is `vacuum=45.538ms`. Previous attribution in `.tmp/sgo-nested-timers-trace.txt` showed the unpruned nested lane at `detail:sgo:nested-total=213.664ms`, led by `simplify-locals=60.031ms`, `vacuum=47.410ms`, and `remove-unused-brs=20.042ms`; this motivated the artifact-tuned nested-list pruning.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-local-threshold-192-10k` compared `9975/10000` mixed-generator modules after the SGO local-heavy nested cleanup threshold slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-nested-pruned-10k` compared `9975/10000` mixed-generator modules after pruning the SGO nested cleanup list, matched all `9975`, found `0` mismatches, `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-nested-cleanup-artifact-guard-relax-10k` compared `9975/10000` mixed-generator modules after the artifact-informed nested cleanup guard relaxation, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-size-skip-precedence-10k` compared `9975/10000` mixed-generator modules after the size-skip precedence guardrail slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-cleanup-skip-precedence-10k` compared `9975/10000` mixed-generator modules after the cleanup skip precedence guardrail slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-global-init-cleanup-guardrail-10k` compared `9975/10000` mixed-generator modules after the global-initializer cleanup guardrail slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-module-boundary-cleanup-10k` compared `9975/10000` mixed-generator modules after the module-boundary nested cleanup guardrail slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-nested-cleanup-order-10k` compared `9975/10000` mixed-generator modules after the nested cleanup order characterization slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-large-touched-function-guard-10k` compared `9975/10000` mixed-generator modules after the large touched-function guard characterization slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-runtime-barrier-characterization-10k` compared `9975/10000` mixed-generator modules after the same-trace runtime barrier characterization slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-nested-cleanup-guard-10k` compared `9975/10000` mixed-generator modules after the nested cleanup guard characterization slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-eqz-constdrop-10k` compared `9975/10000` mixed-generator modules after the block-wrapped `eqz` condition and const-drop body self-guard slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-condprefix-10k` compared `9975/10000` mixed-generator modules after the no-op condition-prefix self-guard slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-blockcond-10k` compared `9975/10000` mixed-generator modules after the block-wrapped condition-read self-guard slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-nested-10k` compared `9975/10000` mixed-generator modules after the nested self-guard slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-revcompare-10k` compared `9975/10000` mixed-generator modules after the bidirectional compare-const self-guard slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-eqz-10k` compared `9975/10000` mixed-generator modules after the `i32.eqz` self-guard slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-if-return-10k` compared `9975/10000` mixed-generator modules after the exact `if return; set` slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-ifreturn-cond-10k` compared `9975/10000` mixed-generator modules after the eqz and bidirectional compare `if return; set` slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-block-ifreturn-10k` compared `9975/10000` mixed-generator modules after the block-wrapped-condition `if return; set` slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-ifreturn-setblock-10k` compared `9975/10000` mixed-generator modules after the block-wrapped-set `if return; set` slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-ifreturn-blockcond-setblock-10k` compared `9975/10000` mixed-generator modules after the block-wrapped-condition+set `if return; set` slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-nested-blockcond-ifreturn-10k` compared `9975/10000` mixed-generator modules after the nested block-wrapped condition `if return; set` slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-blockyield-ifreturn-10k` compared `9975/10000` mixed-generator modules after the block-yielded external condition-operator `if return; set` slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-blockyield-blockset-ifreturn-10k` compared `9975/10000` mixed-generator modules after the block-yielded condition plus block-wrapped set `if return; set` slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-transparent-10k-final` compared `9975/10000` mixed-generator modules after the transparent self-guard slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-blockyield-selfguard-10k` compared `9975/10000` mixed-generator modules after the block-yielded external condition-operator self-guard slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-pure-condition-10k` compared `9975/10000` mixed-generator modules after the simple pure-condition self-guard slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-typed-externref-body-10k` compared `9975/10000` mixed-generator modules after the typed externref function-body guardrail slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-typed-ref-func-body-10k` compared `9975/10000` mixed-generator modules after the typed ref-func function-body guardrail slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-mixed-independent-runtime-10k` compared `9975/10000` mixed-generator modules after the mixed scalar/reference independent runtime guardrail slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-externref-deep-control-10k` compared `9975/10000` mixed-generator modules after the externref deep-control runtime guardrail slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-externref-alias-guardrails-10k` compared `9975/10000` mixed-generator modules after the externref-alias same-init guardrail slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-reference-alias-guardrails-10k` compared `9975/10000` mixed-generator modules after the reference-alias same-init guardrail slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-reference-runtime-guardrails-10k` compared `9975/10000` mixed-generator modules after the reference-runtime guardrail slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-bitwise-condition-10k` compared `9975/10000` mixed-generator modules after the bitwise pure-condition self-guard slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-shift-rotate-condition-10k` compared `9975/10000` mixed-generator modules after the shift/rotate pure-condition self-guard slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-unary-condition-10k` compared `9975/10000` mixed-generator modules after the unary pure-condition self-guard slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-i64-compare-condition-10k` compared `9975/10000` mixed-generator modules after the i64 equality/compare pure-condition self-guard slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-i64-value-condition-10k` compared `9975/10000` mixed-generator modules after the non-trapping i64 value pure-condition self-guard slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-float-compare-condition-10k` compared `9975/10000` mixed-generator modules after the f32/f64 compare pure-condition self-guard slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-float-value-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures` and the corresponding dedicated-profile lane `.tmp/pass-fuzz-sgo-float-value-dedicated-1000` both compared `1000/1000`, normalized `1000`, and had zero mismatches or failures after the f32/f64 non-trapping value-operator pure-condition slice.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-guard-negatives-10k` compared `9975/10000` mixed-generator modules after adding guardrail negatives for wrong-target writes, non-constant set operands, `else` arms, `select` value-flow, and trapping loads, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-pure-ifreturn-10k` compared `9975/10000` mixed-generator modules after the pure-condition `if return; set` slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-block-pure-selfguard-10k` compared `9975/10000` mixed-generator modules after the block-wrapped pure-condition self-guard slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-block-pure-ifreturn-10k` compared `9975/10000` mixed-generator modules after the block-wrapped pure-condition `if return; set` slice, matched all `9975`, found `0` validation failures, and hit `25` Binaryen/tool command failures.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --generator gen-valid --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-rotw-gen-valid-10k` matched Binaryen on `10000/10000` normalized generated modules with no mismatches or validation failures.

The earlier `.tmp/pass-fuzz-sgo-10k` baseline found seven mismatches from missing multi-instruction global-initializer folding and over-eager reference-constant replacement in element item expressions; those two families are now covered by focused regressions, and the same-init guardrails, exact-copy-chain, adjacent/eqz/bidirectional compare-const/transparent/nested/block-wrapped-condition/block-yielded-condition/no-op-condition-prefix/const-drop-body read-only-to-write, exact/eqz/bidirectional compare/pure-condition/block-wrapped-condition/block-wrapped-pure-condition/nested-block-wrapped-condition/block-yielded-condition/block-yielded-condition+set/block-wrapped-set/block-wrapped-condition+set `if return; set`, and straight-line/top-level-noise/plain-block/if-then runtime propagation plus imported/exported, reference-runtime, externref deep-control, mixed independent runtime, and typed ref-func and typed externref function-body guardrail slices preserved the green mixed-generator lane.

If future mismatches are caused by a known subset, record that subset explicitly on the Starshine strategy page.

### 5. Late-tail neighborhood replay

Only after neighboring skipped passes stop masking the output, replay the late cluster:

1. `duplicate-import-elimination`
2. `simplify-globals-optimizing`
3. `remove-unused-module-elements`
4. `string-gathering`
5. `reorder-globals`
6. `directize`

That order matters because `SGO` can expose dead globals for RUME and can alter the global/module surface seen by the later string and layout passes.

## Code surfaces a future implementation will probably need

The exact owner file is still undecided, but a faithful port needs these categories rather than only HOT helpers:

| Need | Why |
| --- | --- |
| Module-level global table | The pass reasons about imported/exported/read/written globals across the whole module. |
| Module-code walker | Global initializers and segment offsets are part of the pass contract. |
| Function-body mutation tracker | The optimizing wrapper must know exactly which functions changed. |
| Effect / side-effect classifier | `read-only-to-write` and runtime propagation both depend on conservative barriers. |
| Expression copier / replacement helper | Single-use init folding and constant propagation copy expressions into new sites. |
| Type repair / validation path | GC and `ref.func` replacements can refine expression types. |
| Nested function-pass scheduler | The optimizing sibling requires per-changed-function default cleanup without the DAE/inlining prefix. |

The current v0.1.0 surface includes the optimizing nested-rerun contract. Future startup, dead-write, value-flow, or GC/refinalization breadth should be treated as incremental follow-up work with its own focused evidence.

## Open design questions

- How much of Binaryen's `FlowScanner` should Starshine model before accepting side-effecting-but-safe condition positives? Starshine now has pure-condition positives, the result-`if` arm safe-side-effect subset including pure arm-local value flow, pure post-result operators, the function-level if-return/set variant, and nested result-if-arm flow, the first official `select` value-flow subset, the official `select` through `i32.eqz` subset including the function-level if-return variant, the source-backed independent-call, independent memory-op, independent table-op, and independent constant-local-tee first/second-operand `select` subsets including their if-return variants plus the block-prefix independent-call, independent memory-op, independent table-op (table.size/table.grow/table.set/table.fill/table.copy/table.init/elem.drop), independent local-write, and independent global-write condition subsets and if-return variants, the official nested-thrice same-pattern subset, the official multi-global nested-body subset, and focused negatives for values flowing into `local.tee`, extra guarded reads after local-tee select shells, local writes, call parameters, wrong-target writes, non-constant set operands, `else` arms, `memory.grow` deltas, guarded-global-derived table.set/table.fill/table.init operands, and trapping load addresses; the remaining recommendation is to keep shrinking the rest of the official value-flow matrix test-first.
- Should Starshine land a shared `simplify-globals` / `simplify-globals-optimizing` owner first, or a narrower startup-only `propagate-globals-globally` substrate first?
- Should a future exact-parity experiment restore more of Binaryen's nested default-function scheduler despite the measured runtime cost, or keep the accepted artifact-tuned subset?
- How should local type repair represent Binaryen's `ReFinalize()` obligations for reference-typed replacements?
- Should global fact collection reuse broader module-analysis caches or stay pass-local until another global-family pass needs it?

Record the answer in this page and [`./starshine-strategy.md`](./starshine-strategy.md) when implementation work decides any of these.

## Sources

- [`../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md`](../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md)
- [`../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md`](../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md)
- [`../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)

## 2026-07-06 local-set compare readiness note

The latest FlowScanner slice adds independent constant `local.set` compare operands for both guarded-write and function-level if-return tails, with a guarded-value-to-local-write negative. Validation evidence: focused local-set tests `3/3`, full SGO tests `255/255`, `moon test src/passes` `4404/4404`, native `src/cmd` build, regular `.tmp/pass-fuzz-sgo-localset-compare-genvalid-1000` `1000/1000` normalized, dedicated `.tmp/pass-fuzz-sgo-localset-compare-dedicated-1000` `1000/1000` normalized, and direct timing still within the required 1x Binaryen bar.

## 2026-07-06 global-set compare readiness note

The latest FlowScanner slice adds independent constant `global.set` compare operands where a result block writes a different global and yields a constant while the guarded global supplies the other `i32.eq` / `i32.ne` operand. It covers both guarded-write and function-level if-return tails, and keeps the guarded-value-to-`global.set` negative mutable. Validation evidence: focused global-set compare positives `2/2`, guardrail `1/1`, focused `*global*` SGO tests `258/258`, full SGO tests `258/258`, `moon test src/passes` `4407/4407`, native `src/cmd` build, regular `.tmp/pass-fuzz-sgo-globalset-compare-genvalid-1000` `1000/1000` normalized, dedicated `.tmp/pass-fuzz-sgo-globalset-compare-dedicated-1000` `1000/1000` normalized, and representative timing still under the 1x Binaryen bar (`0.339x`, `0.212x`, `0.583x`, `0.444x`, `0.698x`). Broad generic `FlowScanner` equivalence remains open until every remaining parent/child value-flow family is implemented or source-backed as excluded.

## 2026-07-06 memory-store compare readiness note

The latest FlowScanner slices add independent `i32.store` compare operands where a result block stores to constant or `local.get` memory address/value operands and yields a constant while the guarded global supplies the other `i32.eq` / `i32.ne` operand. They cover both guarded-write and function-level if-return tails, and keep guarded-value-to-memory-store negatives mutable. Validation evidence for the constant slice: focused memory-store positives `2/2`, guardrail `1/1`, full SGO tests `261/261`, `moon test src/passes` `4410/4410`, native `src/cmd` build, regular `.tmp/pass-fuzz-sgo-memstore-compare-genvalid-1000` `1000/1000` normalized, dedicated `.tmp/pass-fuzz-sgo-memstore-compare-dedicated-1000` `1000/1000` normalized, `moon info`, `git diff --check`, full `moon test` `7849/7849`, and representative timing under the 1x Binaryen median bar. Validation evidence for the local-fed widening: red-first focused positives failed `0/2` before implementation; after implementation focused local-fed memory-store positives passed `2/2`, focused `*memory store*` tests `5/5`, full SGO tests `263/263`, `moon test src/passes` `4412/4412`, native `src/cmd` build, regular `.tmp/pass-fuzz-sgo-local-memstore-genvalid-1000` `1000/1000` normalized, dedicated `.tmp/pass-fuzz-sgo-local-memstore-dedicated-1000` `1000/1000` normalized, and representative timing stayed under 1x (`0.343x`, `0.232x`, `0.577x`, `0.435x`, `0.665x`).

## 2026-07-06 local-fed global-set compare readiness note

The latest FlowScanner slice adds independent `global.set` compare operands where a result block writes a constant or `local.get` value to a different global and yields a constant while the guarded global supplies the other `i32.eq` / `i32.ne` operand. It covers both guarded-write and function-level if-return tails, and keeps the guarded-value-to-`global.set` negative mutable. Validation evidence: focused local-fed global-set positives `2/2`, focused `*global set*` tests `5/5`, full SGO tests `265/265`, `moon test src/passes` `4414/4414`, native `src/cmd` build, regular `.tmp/pass-fuzz-sgo-local-globalset-genvalid-1000` `1000/1000` normalized, dedicated `.tmp/pass-fuzz-sgo-local-globalset-dedicated-1000` `1000/1000` normalized with all six aggregate leaves sampled, and representative timing remains `<=1x` Binaryen on all harness fixtures.

## 2026-07-06 local-fed local-write compare readiness note

The latest FlowScanner slice adds independent local-write compare operands where the local write stores a constant or `local.get` value independent of the guarded global. It covers direct `local.tee` compare shells and block-condition `local.set` / `local.get` compare shells for guarded-write and function-level if-return tails, and keeps guarded-value-to-local-write negatives mutable. Validation evidence: focused local-fed local-write positives `4/4`, focused `*local*` SGO tests `26/26`, full SGO tests `269/269`, `moon test src/passes` `4418/4418`, native `src/cmd` build, regular `.tmp/pass-fuzz-sgo-local-localwrite-genvalid-1000` `1000/1000` normalized, dedicated `.tmp/pass-fuzz-sgo-local-localwrite-dedicated-1000` `1000/1000` normalized, and representative timing still under `1x` Binaryen median on all fixtures.

## 2026-07-06 local-fed memory-grow compare/select readiness note

The latest FlowScanner slice widens independent `memory.grow` compare and select operands from constant-only deltas to constants or `local.get`s independent of the guarded global. It covers direct/reverse compare order, direct/second select operand forms, and both function-level `if return; set` tails, while keeping guarded-value-to-`memory.grow` delta negatives mutable. Validation evidence: red-first focused compare and select positives each failed `0/2` before implementation; after implementation focused local-fed memory-grow compare `2/2`, focused local-fed memory-grow select `2/2`, focused `*memory*` SGO tests `20/20`, full SGO tests `275/275`, `moon test src/passes` `4424/4424`, native `src/cmd` build, regular `.tmp/pass-fuzz-sgo-local-memgrow-genvalid-1000` `1000/1000` normalized, dedicated `.tmp/pass-fuzz-sgo-local-memgrow-dedicated-1000` `1000/1000` normalized, and representative timing still under `1x` Binaryen median on all fixtures.


## 2026-07-06 local-fed table-grow select readiness note

The latest FlowScanner slice widens independent `table.grow` select operands from constant-only ref/delta operands to constants or `local.get`s independent of the guarded global. It covers direct/second select operand forms and the function-level `if return; set` tail, while keeping guarded-value-to-`table.grow` delta negatives mutable. Validation evidence: red-first focused positives failed `0/2` before implementation; after implementation focused local-fed table-grow select `2/2`, focused `*table grow*` SGO tests `6/6`, focused `*table*` tests `27/27`, full SGO tests `277/277`, `moon test src/passes` `4426/4426`, native `src/cmd` build, regular `.tmp/pass-fuzz-sgo-local-tablegrow-select-genvalid-1000` `1000/1000` normalized, dedicated `.tmp/pass-fuzz-sgo-local-tablegrow-select-dedicated-1000` `1000/1000` normalized, and representative timing still under `1x` Binaryen median on all fixtures.


## 2026-07-07 independent call nontrapping `i32` binary readiness note

The latest FlowScanner slice widens the independent call sibling subset from pure `i32.add` to local Binaryen `version_130`'s accepted nontrapping pure `i32` binary parents: add/sub/mul, bitwise ops, shifts, and rotates. It covers direct/reverse operand orders and guarded-write / function-level `if return; set` tails, preserves the independent zero-parameter/one-result call as `call; drop`, and keeps trapping div/rem plus guarded-value-to-call-argument shapes mutable. Validation evidence: red-first focused coverage failed before implementation; after implementation focused nontrapping binary `1/1`, focused call-guard tests `9/9`, full SGO `283/283`, `moon test src/passes` `4432/4432`, native `src/cmd` build, regular `.tmp/pass-fuzz-sgo-call-binary-genvalid-1000` and dedicated `.tmp/pass-fuzz-sgo-call-binary-dedicated-1000` smokes both `1000/1000` normalized, and representative direct timing remains below `1x` Binaryen on every fixture.

## 2026-07-07 independent call binary `i32.eqz` suffix readiness note

The latest FlowScanner slice adds a narrow pure-parent suffix above independent call sibling operands: after the guarded global and independent zero-parameter/one-result call feed a nontrapping pure `i32` binary operator, the result may flow through `i32.eqz` before the same-global guarded write or function-level `if return; set` tail. Local Binaryen `version_130` accepts the direct/reverse and if-return probes, while `i32.div_s; i32.eqz` keeps `$guard` mutable. Validation evidence: red-first focused coverage failed before implementation; after implementation focused suffix coverage `1/1`, focused call-guard tests `10/10`, full SGO `284/284`, `moon test src/passes` `4433/4433`, native `src/cmd` build, regular `.tmp/pass-fuzz-sgo-call-binary-eqz-genvalid-1000` and dedicated `.tmp/pass-fuzz-sgo-call-binary-eqz-dedicated-1000` smokes both `1000/1000` normalized, and representative direct timing remains below `1x` Binaryen on every fixture.

The latest FlowScanner slice widens the independent-call/nontrapping-`i32` binary parent-chain subset through one extra nontrapping integer-unary suffix: `i32.clz`, `i32.ctz`, or `i32.popcnt` may consume the binary result before a same-global guarded write or function-level `if return; set` tail. Local Binaryen `version_130` accepted direct `i32.mul; i32.clz`, reverse `i32.mul; i32.ctz`, and if-return `i32.xor; i32.popcnt`; a trapping `i32.div_s; i32.clz` negative stayed mutable. Validation evidence: red-first focused `*binary pure suffix guards*` failed before implementation, then passed `1/1`; focused `*call*guards*` passed `10/10`; full SGO tests passed `284/284`; `moon fmt`; `moon test src/passes` passed `4433/4433`; native build passed with pre-existing warnings; regular `.tmp/pass-fuzz-sgo-call-binary-unary-suffix-genvalid-1000` and dedicated `.tmp/pass-fuzz-sgo-call-binary-unary-suffix-dedicated-1000` both normalized `1000/1000` with zero failures; timing stayed under 1x (`0.428x`, `0.273x`, `0.845x`, `0.439x`, `0.593x` across the representative fixtures). Broad generic `FlowScanner` parity remains open.

## 2026-07-07 independent call binary constant-fed comparison readiness note

The latest slice admits one `i32.const` plus `i32.eq` / `i32.ne` parent above the independent-call/nontrapping-`i32` binary result, in either comparison order and for guarded-write / function-level if-return tails. Local Binaryen accepted direct, constant-first reverse, and if-return probes; trapping `i32.div_s` plus the same comparison stayed mutable. Red-first focused coverage failed `0/1`, then focused suffix and call tests passed, full SGO remained `284/284`, `moon test src/passes` remained `4433/4433`, native build passed, both `.tmp/pass-fuzz-sgo-call-binary-compare-const-{genvalid,dedicated}-1000` lanes normalized `1000/1000` with zero failures, and timing stayed under 1x with worst ratio `0.857x`. Broader generic FlowScanner parity remains open.

## 2026-07-07 independent `i64` call binary suffix readiness note

The latest slice implements the first non-`i32` independent-call parent chain: nontrapping pure `i64` binary parents followed by exactly one `i64.eqz` or constant-fed `i64.eq` / `i64.ne`, covering direct/reverse call operands, constant-first equality, and guarded-write / function-level if-return tails. Local Binaryen accepted the three positive probes and kept the trapping `i64.div_s; i64.eqz` negative mutable. Red-first focused coverage failed `0/1`, then focused passed `1/1`; call-guard tests passed `11/11`, full SGO `285/285`, `moon test src/passes` `4434/4434`, full `moon test` `7873/7873`, native build passed, and both final `.tmp/pass-fuzz-sgo-call-i64-binary-suffix-{genvalid,dedicated}-1000-final` lanes normalized `1000/1000` with zero failures. Final post-fix timing remained below 1x with worst ratio `0.839x`.

## 2026-07-07 independent float call binary-comparison readiness note

The next typed parent-chain slice now implements `f32` / `f64` independent-call siblings under one IEEE float binary parent and one same-typed constant-fed float comparison. Local Binaryen accepted direct/reverse, result-first/constant-first, guarded-write/if-return, `f32.div`, `f32.min` with NaN, and `f64.copysign` probes; call-argument flow and extra-read negatives stayed mutable. Red-first focused coverage failed `0/1`, then passed `1/1`; call-guard tests passed `12/12`, full SGO `286/286`, `moon test src/passes` `4435/4435`, full `moon test` `7874/7874`, native build passed, and regular/dedicated `.tmp/pass-fuzz-sgo-call-float-binary-compare-{genvalid,dedicated}-1000` lanes normalized `1000/1000` with zero failures. Timing stayed below 1x with worst ratio `0.766x` across the representative fixtures. Broad generic `FlowScanner` equivalence and final full-matrix freshness remain open.

## 2026-07-07 generic scalar parent-chain readiness note

The latest slice removes the artificial one-suffix limit for the independent-call scalar family. Local Binaryen probes accepted deep `i32` unary chains, `i32` relational comparison, `f32.abs`, `f64.promote_f32`, and a same-type unary operation on the call result before the first parent. Starshine now tracks scalar kind through arbitrary result-first nontrapping unary/conversion and constant-fed binary/comparison parents and uses the same parser for cleanup. A parameter-fed trapping `i32.div_s` suffix remains mutable.

Red-first focused coverage failed `0/1`, then passed `1/1`; call-guard tests passed `12/12`, full SGO `287/287`, `moon test src/passes` `4436/4436`, full `moon test` `7875/7875`, native build passed, and both `.tmp/pass-fuzz-sgo-generic-scalar-parent-chain-{genvalid,dedicated}-1000` lanes normalized `1000/1000` with zero failures. Timing remains under 1x on all representative fixtures, with read-only-select now the tightest at `0.952x`. Closeout is still blocked by the remaining generic independent-effect/structured-parent classification and stale full-matrix evidence.

## 2026-07-07 multiple constant-first parent-depth readiness note

Local Binaryen probes accepted two nested constant-first `i32` parents after the first independent-call/global parent in both first-parent operand orders. The red-first test `simplify-globals-optimizing removes multiple constant-first scalar call parents` failed `0/1` while `$guard` stayed mutable, then passed after the scalar parser learned to consume contiguous typed prefix constants in LIFO parent order and cleanup collapsed the shell to `call; drop`. Full SGO passed `288/288`, `moon test src/passes` passed `4437/4437`, full `moon test` passed `7876/7876`, `moon info`, `moon fmt`, and native build passed with pre-existing warnings. Regular and dedicated `.tmp/pass-fuzz-sgo-constant-first-parent-depth-{genvalid,dedicated}-1000` lanes normalized `1000/1000` with zero failures; dedicated selections were `132/210/129/148/154/227` across the six SGO leaves. Timing remained `<=1x`, with read-only-select the tightest at `0.925x`. Generic independent-effect and structured-parent classification plus final full-matrix freshness remain open.

## 2026-07-07 reverse pre-parent fragment readiness note

The reverse independent-call first-parent order now has effect-aware cleanup. The same-type unary focused test was already green; the nontrapping type-changing conversion and trapping float-to-int tests each failed `0/1` before implementation because pure guard debris remained. After implementation, all three focused tests pass, removable fragments become `call; drop`, and trapping truncation fragments become `call; trunc; drop`. Full SGO passes `291/291`, `moon test src/passes` `4440/4440`, full `moon test` `7879/7879`, and the native build, `moon fmt`, and `moon info` are green with pre-existing warnings. Regular and dedicated `.tmp/pass-fuzz-sgo-reverse-preparent-unary-{genvalid,dedicated}-1000` lanes normalize `1000/1000` with zero failures, and timing remains `<=1x` with read-only-select at `0.977x`. Generic independent effects, structured parents, and fresh final closeout lanes remain open.

## 2026-07-07 generic independent scalar producer readiness note

The scalar provenance record now admits three bounded producer classes shared by read detection and cleanup: zero-parameter scalar calls, removable `memory.size`, and constant-address scalar loads whose possible trap must be replayed. Binaryen/Starshine direct probes now agree for direct memory-size plus unary, reverse memory-size plus type-changing conversion, independent constant-address load preservation, and the guarded-load-address negative. The three required positives failed red before implementation and now pass; focused pre-parent tests are `6/6` and full SGO is `295/295`.

After rebasing onto local `main` `c24acc74a`, the rebuilt native CLI produced exact probe WAT parity. Regular and dedicated `.tmp/pass-fuzz-sgo-generic-scalar-producer-post-rebase-{genvalid,dedicated}-1000` lanes normalized `1000/1000` with zero failures; the dedicated profile selected `132/210/129/148/154/227`. Representative timing remains `<=1x`, with the final run at `0.465x`, `0.314x`, `0.981x`, `0.465x`, and `0.997x` for const-read, runtime propagation, read-only-select, initializer folding, and startup offsets. The last two margins are narrow, so further generic widening must remain allocation-light and immediately timed.

## 2026-07-07 bounded structured producer readiness note

Local Binaryen v130 probes classify direct pure result-block, reverse result-block with a trapping load, pure result-`if`, call-conditioned result-`if`, and guarded-global-as-result-`if`-condition negative shapes. Three new positives failed before implementation: the direct block and call-conditioned `if` left the global mutable, while the reverse block made the global immutable but retained guard debris. The guarded-condition negative was already green. After the bounded structured grammar landed, focused result-block/result-if tests pass, full SGO passes `300/300`, and `moon test src/passes` passes `5091/5091`; native build and formatting pass with existing warnings.

Binaryen/Starshine probe diffs now differ only in generated symbol names. Regular and dedicated `.tmp/pass-fuzz-sgo-structured-producers-{genvalid,dedicated}-1000` lanes each requested/compared/normalized `1000/1000`, with zero mismatches or failures; dedicated selections remain `132/210/129/148/154/227`. Timing remains within the strict 1x requirement: `0.433x`, `0.327x`, `0.990x`, `0.438x`, and `0.930x`. Broader independent grows/writes, type-index/multivalue or branchful structured producers, complete source/lit classification, and the fresh final four-lane matrix remain open.

## 2026-07-07 structured memory-grow readiness note

The bounded structured grammar now covers direct result blocks that execute independent `memory.grow` before yielding a scalar. Accepted deltas are constants, `local.get`, or one nontrapping `i32.add` over those operands; cleanup preserves the grow as `delta; memory.grow; drop`. A guarded global used as the grow delta stays mutable. Two positives failed red before implementation and the negative remained green; focused tests now pass `3/3`, full SGO `303/303`, pass tests `5094/5094`, and full tests `8537/8537`.

Direct probe output matches Binaryen except generated names. Regular and dedicated `.tmp/pass-fuzz-sgo-structured-grow-{genvalid,dedicated}-1000` lanes normalize `1000/1000` with zero failures or mismatches; timing remains `<=1x`, with read-only-select at `0.961x`.

## 2026-07-07 structured local-write and table-grow readiness note

Local Binaryen v130 probes classify independent observable `local.set`, `local.tee`, parameter-fed local writes, and independent `table.grow` result-block prefixes as FlowScanner-safe, while guarded-global-to-local-write and guarded-global-to-table-grow-delta shapes remain negative. Three local-write positives and one table-grow positive failed red before implementation; the two negatives passed. The bounded fragment record now replays local writes through `local.tee` and folds the exact single following `local.get`; table grows replay their ref/delta/grow prefix and retain the grow result drop.

Focused local/table tests pass `4/4` and `2/2`; full SGO `309/309`, pass tests `5100/5100`, and full tests `8543/8543` pass. `moon info`, `moon fmt`, native release build, and `git diff --check` pass with pre-existing warnings. Direct probe instructions match Binaryen; Starshine retains an unused local declaration in the one-use local case. Regular and dedicated `.tmp/pass-fuzz-sgo-structured-local-table-{genvalid,dedicated}-1000` lanes each normalize `1000/1000`, with zero mismatches/failures, Binaryen cache `1000/0`, and dedicated selections `132/210/129/148/154/227`. A 31-repeat timing rerun is `0.438x`, `0.324x`, `0.993x`, `0.431x`, and `0.907x` across the representative fixtures.

## 2026-07-07 repeated-local and structured-control readiness note

Binaryen v130 probes under `.tmp/sgo-current-audit/` classify constant two-read local tails, single-result type-index blocks, independent scalar loops, independent branchful scalar blocks, and effectful-independent-arm result `if`s as positive. True multivalue blocks remain mutable in Binaryen and are a source-backed exclusion. Guarded reads flowing from inside a loop or branchful block are positive in Binaryen but remain open in Starshine.

The repeated-constant local test failed red `0/1`; independent loop and branchful-block tests failed red `0/2`. After implementation, repeated-local `1/1`, structured-control `2/2`, full SGO `312/312`, pass tests `5103/5103`, and full tests `8546/8546` pass. `moon info`, `moon fmt`, native release build, and `git diff --check` pass with existing warnings. The repeated-local output is a measured Starshine win: stripped pass-local size `47` bytes versus Binaryen `51`, with identical `37`-byte downstream `-Oz` output.

Regular and dedicated `.tmp/pass-fuzz-sgo-structured-control-{genvalid,dedicated}-1000` lanes each requested/compared/normalized `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property failures, or command failures; Binaryen cache is `1000/0`. Dedicated selections are same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`. The accepted 31-repeat timing ratios are `0.423x`, `0.298x`, `0.906x`, `0.480x`, and `0.966x`.

## 2026-07-07 guarded structured value-flow readiness note

Exact scalar guarded-result loops and the probed branchful result-block value path now count as read-only-to-write-safe through the existing pure suffix, guarded-write, and if-return tails. Direct/reverse loop and guarded-write/if-return block positives failed red `0/2`; focused positives now pass `2/2` and the dangerous nested-condition guardrail passes `1/1`. Full SGO/pass/repo tests pass `315/315`, `5106/5106`, and `8549/8549`; `moon info`, `moon fmt`, native build, and `git diff --check` pass with existing warnings.

Regular and dedicated `.tmp/pass-fuzz-sgo-guarded-structured-{genvalid,dedicated}-1000` each normalize `1000/1000` with zero failures/mismatches and Binaryen cache `1000/0`; dedicated selections remain `132/210/129/148/154/227`. The accepted 51-repeat timing ratios are `0.470x`, `0.340x`, `0.977x`, `0.450x`, and `0.932x`.

One-use unused-local declarations and effectful result-if cleanup are measured size-losing parity gaps: `46` versus `44` and `65` versus `63` stripped bytes, respectively, with downstream `-Oz` convergence. Metadata-unsafe local removal was tested and reverted after a local-name-index validation failure. Remaining blockers are complete v130 source/lit family inventory, metadata-aware local cleanup and result-if cleanup decisions, and a fresh final four-lane matrix.
