---
kind: concept
status: supported
last_reviewed: 2026-05-19
sources:
  - ../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md
  - ../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md
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

This page answers the practical porting question: now that Starshine has a first partial module-pass slice, what remains and how should each next slice be validated?

## Current port-readiness summary

`simplify-globals-optimizing` is **partially implemented** in Starshine today.
The useful local status is:

| Surface | Current state | Code / doc anchor |
| --- | --- | --- |
| Public pass name | active module pass; plain `simplify-globals` remains boundary-only | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) |
| Active request behavior | direct requests run the partial SGO core plus touched nested cleanup | [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) |
| Implementation owner | first constant/dead-set/same-init/read-only-to-write/startup/single-use-init/exact-copy-chain/plain-block/if-then-runtime subset | [`src/passes/simplify_globals_optimizing.mbt`](../../../../../src/passes/simplify_globals_optimizing.mbt) |
| Focused tests | registry, constants, single-use init folding, exact-type immutable copy chains, dead sets, single-const/ref-null same-init writes plus expression/result-block and funcref/externref alias guardrails, narrow read-only-to-write self guards including `i32.eqz`, bidirectional compare-const, simple pure-condition positives with i32 unary/bitwise/shift-rotate ops, i64 equality/compare and non-trapping value ops, plus f32/f64 compares, nested block-condition, block-wrapped pure-condition and block-yielded condition reads including `i32.eqz`, no-op const/drop prefixes before block-wrapped condition reads, `nop` / void-`block` transparent bodies, no-op const/drop prefixes before the write, exact/eqz/bidirectional compare/pure-condition/block-wrapped-condition/block-wrapped-pure-condition/nested-block-wrapped-condition/block-yielded-condition/block-yielded-condition+set/block-wrapped-set/block-wrapped-condition+set `if return; set` positives and trailing-code negatives, flow-into-`local.tee`, wrong-target, non-constant set operand, `else`, `select`, and trapping-load negatives, straight-line/top-level-noise/adjacent/nested plain-block and if-then-body runtime propagation, imported/exported and reference-typed runtime fact guardrails including deeper reference and externref-null call/loop/branch/`try_table`/post-if boundaries plus mixed scalar/reference independent-write preservation, harmless block-body drop/pure-noise positives, call/control/non-constant/exported/imported/loop/try_table/post-if-join/else-arm guardrails, startup offsets, touched-only nested cleanup, typed `ref.null`, typed externref-null direct/alias/block-result, and direct/alias/block-result `ref.func` function-body replacement, typed element item/ref.func alias bailouts, exported bailout | [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../../src/passes/simplify_globals_optimizing_test.mbt) |
| Direct fuzz evidence | 10000/10000 gen-valid normalized matches; 9975/10000 mixed-generator compared matches with only Binaryen/tool command failures | [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) |
| Active presets | local `optimize` / `shrink` still stop before the late Binaryen post-pass tail | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) |
| Backlog | still split into broader global rewrite parity plus nested/artifact parity | [`agent-todo.md`](../../../../../agent-todo.md) |
| Canonical placement | after `duplicate-import-elimination`, before `remove-unused-module-elements` | [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md) |

That means the wiki should now teach the pass as an active but incomplete module/global port, not as a HOT peephole and not as full Binaryen parity. The 2026-05-18 current-main refresh found no semantic drift from Binaryen `version_129` at observed `main` commit `d3029d2b975488acdf9253eb2994a3fc55bd3549`, so the remaining port map remains current.

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
   - extend the landed simple pure-condition bridge only with focused source-backed non-trapping operators; the current unary, bitwise, shift/rotate, i64-compare, i64-value, and float-compare bridge covers `i32.clz` / `i32.ctz` / `i32.popcnt`, `i32.and` / `i32.or` / `i32.xor`, `i32.shl` / `i32.shr_s` / `i32.shr_u` / `i32.rotl` / `i32.rotr`, `i64.eqz` and `i64` equality/relational compares, non-trapping i64 unary/arithmetic/bitwise/shift-rotate operators feeding those conditions, plus f32/f64 equality/relational compares;
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
   - remove or justify the current large-module / large-touched-set guard with artifact evidence.

Every partial implementation should name the subset it supports until the fact collection, rewrite, nested-rerun, direct oracle, and artifact evidence all exist.

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
| Optimizing wrapper | touched functions receive ordinary cleanup; untouched functions do not |

The shape tests should stay readable enough for beginners, then add advanced stress cases for GC refs, segment offsets, side effects inside conditions, and nested self-guards.

## Validation ladder

Use this validation order for follow-up implementation.

### 1. Registry and request behavior

The current public-surface baseline is:

- `simplify-globals-optimizing` is an active module pass;
- direct active requests run the partial implementation;
- plain `simplify-globals` remains boundary-only;
- presets do not silently include the late-tail pass.

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
- validation/writeback after type-changing replacements.

This is the main behavior that distinguishes `simplify-globals-optimizing` from plain [`../simplify-globals/index.md`](../simplify-globals/index.md).

### 4. Binaryen oracle comparison

Run isolated oracle comparison before late-tail replay:

- `bun scripts/pass-fuzz-compare.ts --pass simplify-globals-optimizing ...`
- reduced fixtures from Binaryen's `simplify-globals-*` lit family;
- targeted debug-artifact runs once the module-boundary harness accepts the pass.

Current active-partial evidence:

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

If a future port implements only startup propagation or only dead-write cleanup, keep `simplify-globals-optimizing` marked as partial until the nested rerun contract exists too.

## Open design questions

- How much of Binaryen's `FlowScanner` should Starshine model before accepting side-effecting-but-safe condition positives? Starshine now has pure-condition positives plus focused negatives for values flowing into `local.tee`, `select`, wrong-target writes, non-constant set operands, `else` arms, and trapping loads; the remaining recommendation is to keep the official safe-side-effect positive as its own value-flow slice.
- Should Starshine land a shared `simplify-globals` / `simplify-globals-optimizing` owner first, or a narrower startup-only `propagate-globals-globally` substrate first?
- Should touched-function cleanup reuse the existing active preset list exactly, or define a smaller Binaryen-equivalent default-function subset for nested runs?
- How should local type repair represent Binaryen's `ReFinalize()` obligations for reference-typed replacements?
- Should global fact collection reuse broader module-analysis caches or stay pass-local until another global-family pass needs it?

Record the answer in this page and [`./starshine-strategy.md`](./starshine-strategy.md) when implementation work decides any of these.

## Sources

- [`../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md`](../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md)
- [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md)
- [`../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md`](../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md)
- [`../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
