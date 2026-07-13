---
kind: concept
status: supported
last_reviewed: 2026-07-13
sources:
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Flatten.cpp
  - ../../../raw/research/0422-2026-04-27-flatten-port-readiness.md
  - ../../../raw/research/0360-2026-04-25-flatten-current-main-and-test-map.md
  - ../../../raw/research/0267-2026-04-23-flatten-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../raw/research/0065-2026-03-24-ir2-execution-plan.md
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./flat-ir-contract-and-preludes.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../local-cse/index.md
  - ../rereloop/index.md
  - ../i64-to-i32-lowering/index.md
---

# `flatten` implementation structure and tests

This page maps the upstream Binaryen owner files, helper surfaces, official tests, scheduler placement, and current Starshine code/status surfaces for `flatten`.
Read it when you want to move from the conceptual pages to exact files.

## Status in one sentence

Binaryen implements `flatten` in `src/passes/Flatten.cpp` as a function-parallel Flat-IR normalizer; Starshine now has an internal active-partial `src/passes/flatten.mbt` owner with ordered scalar operand preludes, reachable/unreachable tee lowering across region roots and operand positions, branch-free scalar block/if routing, zero-input/no-backedge scalar loop routing, and plain `br`, scalar `br_if` routing including rich shared origins and the two-temp target/flow mismatch, plus scalar `br_table` rich-origin and unique-target fanout for defaultable scalar block targets and owner-local terminal placeholders for nested `br`/`br_table`, while keeping `flatten` publicly removed until broader control, payload, EH, and signoff work is complete.

## Upstream owner map

| Surface | Role | Why it matters |
| --- | --- | --- |
| Binaryen `src/passes/Flatten.cpp` | Main implementation | Owns the `preludes` map, branch-target `breakTemps`, value-carrying control rewrites, `local.tee` removal, branch-payload routing, unsupported-instruction fatal boundaries, final body prelude attachment, and EH nested-pop repair. |
| Binaryen `src/ir/flat.h` | Formal target invariant | Defines what Flat IR means: simple ordinary operands, no value-carrying control flow, no reachable tees, no control-flow values directly under `local.set`, and no concrete function-body flow. |
| Binaryen `src/passes/pass.cpp` | Pass registration and scheduler placement | Exposes the public `flatten` pass and places it in the `optimizeLevel >= 4` aggressive cluster before `simplify-locals-notee-nostructure` and `local-cse`. |
| Binaryen `src/passes/passes.h` | Pass-constructor declaration | Keeps `createFlattenPass()` as a public pass constructor rather than a private helper. |
| Binaryen `src/ir/branch-utils.h` | Branch-target helper surface | Supplies unique-target enumeration for `switch` / `br_table` payload fanout. |
| Binaryen `src/ir/eh-utils.h` | EH repair helper surface | Supplies `handleBlockNestedPops(...)`, which is part of flatten's real correctness story after blocks are inserted under legacy `catch` bodies. |
| Binaryen `src/ir/properties.h` | Already-flat and control-flow tests | Supplies the constant-expression and control-flow-structure decisions that shape prelude migration. |
| Binaryen `src/ir/manipulation.h` | Expression copy helper surface | Supplies expression copying used by tricky `br_if` flowing-out versus branch-target temp cases. |

Primary current-main URLs are Binaryen [`Flatten.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Flatten.cpp), [`flat.h`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/flat.h), and [`pass.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp). Direct tagged `version_129` URLs remain listed in [`./binaryen-strategy.md`](./binaryen-strategy.md).

## Binaryen implementation structure

### 1. Function-parallel pass wrapper

`Flatten.cpp` defines a function-parallel pass and reports that it invalidates DWARF.
That matters because all temp locals, prelude queues, branch-target temp slots, and EH repairs are scoped to one function, while debug info cannot currently survive the local-splitting rewrite faithfully.

Beginner takeaway: this is not a whole-module analysis pass. It is a per-function structural rewrite that can create many locals.

### 2. Formal target check lives outside the pass file

The cleanest source for “what does flatten try to make true?” is `flat.h`, not the pass-name summary in `pass.cpp`.
The verifier contract is the important invariant:

- ordinary operands are simple (`local.get`, constants, `unreachable`, or `ref.as_non_null`);
- `block`, `loop`, `if`, and `try` do not flow concrete values;
- reachable `local.tee` is not Flat IR;
- `local.set` cannot take a control-flow expression as its value;
- a function body cannot itself flow a concrete value.

A faithful Starshine port should write tests against this invariant before adding broad optimizer-comparison tests.

### 3. `preludes` carry work to earlier statement positions

The central implementation map is `preludes`: expressions that must execute immediately before another expression.
The postorder walker lets each child flatten itself first, then lets the parent decide whether those preludes can migrate upward or must be placed inside a control-flow region.

This is the main source-backed reason the pass preserves side-effect order while changing expression shape.

### 4. `breakTemps` make branch payload channels explicit

The second central implementation map is `breakTemps`: a temp local per branch target name.
When a branch carries a value, Binaryen stores that value into the target temp and clears the branch payload.

The subtle cases are:

- `br_if`, where the taken-branch target type and the not-taken flowing-out type can differ and may need two temps;
- `switch` / `br_table`, where the value is first stored once, then copied to every unique target temp.

Those are correctness tests for a future port, not merely shape-quality details.

### 5. Control nodes get custom value-erasure rewrites

`Block`, `If`, `Loop`, and legacy `Try` each place child preludes differently.
They also erase value-carrying control flow by storing the old result into a temp and leaving a `local.get` for the outer consumer.

The `If` case is particularly important for reference-typed code because the temp type can be the least upper bound of the arm types.

### 6. Generic spill and unreachable-placeholder handling finish the job

After special handling, any remaining concrete typed expression can be moved into a temp-local prelude and replaced with `local.get`.
If the expression is unreachable, Binaryen keeps the real expression in the prelude and leaves a placeholder `unreachable` at the original position.

That placeholder rule is why `flatten` is safer to describe as “statement-sequencing plus valid placeholder repair” than as “just introduce locals.”

### 7. Unsupported families are fatal in Binaryen

The reviewed `version_129` and current-main sources still hard-fail on `BrOn*` and `TryTable` with `Unsupported instruction for Flatten`.
A future Starshine implementation must choose an explicit policy here:

- match Binaryen and reject/fail those shapes for the pass, or
- intentionally diverge and document why a safe local no-op/skip policy is preferable.

It should not silently claim full Binaryen parity while accepting unsupported families differently.

### 8. EH nested-pop repair is part of correctness

At function exit, Binaryen attaches remaining preludes and then calls `EHUtils::handleBlockNestedPops(...)`.
This is not optional cleanup: flatten can insert blocks inside `catch`, and legacy EH pop placement must be repaired after that structural change.

## Official test surface

| Test file | What it proves | Local port implication |
| --- | --- | --- |
| `test/lit/passes/flatten.wast` | Tiny smoke coverage, including a nonnullable-param case. | Do not over-cite this as the full pass proof. Use it as a smoke fixture. |
| `test/lit/passes/flatten_all-features.wast` | Broad direct behavior coverage for value-carrying control, `local.tee`, branch payloads, reference cases, and unsupported families. | This should seed the main reduced Starshine shape suite. |
| `test/lit/passes/flatten-eh-legacy.wast` | Legacy EH/catch behavior and nested-pop repair. | Add EH-specific tests before claiming parity, or explicitly gate EH unsupported locally. |
| `test/lit/passes/opt_flatten.wast` | Aggressive optimizer composition around flatten. | Use after direct pass tests to check scheduler-neighbor behavior. |
| `test/lit/passes/flatten_rereloop.wast` | `rereloop` consumes already-flattened input. | Preserve the “flatten first, then rebuild structure” relationship. |
| `test/lit/passes/flatten_i64-to-i32-lowering.wast` | Lowering can depend on flattened input. | Treat flatten as a structural prerequisite for some downstream lowering tests. |

## Current Starshine code map

Starshine implements only the first internal transform slices today; the public removed status and remaining gaps are represented in code and docs.

| Local surface | Exact location | Meaning |
| --- | --- | --- |
| Removed-name registry | `src/passes/optimize.mbt:144-151` | `flatten` is a known removed pass name, not an unknown typo. |
| CLI trap-mode filtering test | `src/cli/cli_test.mbt:305-309` | Explicit `--flatten` survives trap-mode flag filtering in pass-token resolution. |
| CLI `-O` flag interaction test | `src/cli/cli_test.mbt:340-342` | Explicit `--flatten` survives alongside an optimization-level flag in pass-token resolution. |
| Internal owner | `src/passes/flatten.mbt` and `src/passes/flatten_test.mbt` | The first slices classify Flat IR violations, materialize scalar function results, lower reachable/unreachable tees at function roots, structured-region roots, and ordinary operand positions, sequence ordered scalar ordinary-operand preludes, route branch-free defaultable scalar block/if and zero-input/no-backedge loop results, and redirect plain carried scalar `br` plus scalar `br_if` payloads through named target temps for defaultable scalar block targets. Same-type `br_if` preserves its false-path flow through a shared `local.get`; rich ordinary payloads retain one producer, run before the condition, and feed chained conditionals through locals; the target/flow-type mismatch uses a second correctly typed flow temp and one target copy. Scalar `br_table` retains one rich ordinary producer, stores it before selector preludes, copies to every unique target temp, clears its payload, and removes the dead terminal producer root. Nested terminal `br`/`br_table` operands leave an `unreachable` placeholder while owner-region tracking preserves exactly one real effect, and scalar body-result materialization refuses unsupported root controls. Multivalue conditional and table payloads remain open behind the whole-function gate. |
| Old IR2 batch intent | `../../../raw/research/0065-2026-03-24-ir2-execution-plan.md:69-70` | `flatten` still leads the old preferred Batch 2 implementation order. |
| Old registry-map batch status | `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md:107-108` | `flatten` remains documented as removed until implementation lands. |
| Active backlog | `agent-todo.md` `[O4Z-FLAT]001` | Tracks the remaining source refresh, control/EH implementation, public wiring, profile, closeout, and aggressive-neighborhood proof. |

## What a faithful Starshine test ladder should start with

A future implementation should start with reduced shape tests before broad artifact replay:

1. simple nested expression spill and simple-child preservation;
2. value-carrying `block`, `if`, `loop`, and legacy `try` rewrites;
3. reachable `local.tee` set/get lowering and unreachable-tee shell deletion;
4. carried `br`, `br_if`, and `br_table` payload routing, including the two-temp `br_if` type mismatch family;
5. placeholder `unreachable` preservation;
6. selective `ref.as_non_null` behavior and non-nullability TODO boundaries;
7. hard unsupported `BrOn*` and `TryTable` policy;
8. EH nested-pop repair;
9. downstream cluster tests with `simplify-locals-notee-nostructure`, `local-cse`, `rereloop`, and `i64-to-i32-lowering`.

After those are green, use the pass workflow from `AGENTS.md`: compare direct `--pass flatten` behavior against Binaryen where supported, then replay the saved `-O4z` slot and nested aggressive reruns. The more detailed first-slice plan and removal-from-registry gates are now in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Non-goals to keep explicit

Do not document or implement `flatten` as any of these:

- generic block merging;
- arbitrary code motion;
- common subexpression elimination;
- `merge-blocks` under another name;
- a local-cleanup pass like `simplify-locals`;
- a whole-module layout or reachability pass.

The source-backed contract is narrower and more structural: enforce Flat IR by sequencing nested work into preludes, routing values through locals, erasing value-carrying control flow, and repairing EH stack shape.

## Sources

- Binaryen current-main [`Flatten.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Flatten.cpp)
- [`../../../raw/research/0422-2026-04-27-flatten-port-readiness.md`](../../../raw/research/0422-2026-04-27-flatten-port-readiness.md)
- [`../../../raw/research/0360-2026-04-25-flatten-current-main-and-test-map.md`](../../../raw/research/0360-2026-04-25-flatten-current-main-and-test-map.md)
- Binaryen current `main` `Flatten.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Flatten.cpp>
- Binaryen current `main` `flat.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/flat.h>
- Binaryen current `main` `flatten_all-features.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_all-features.wast>
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cli/cli_test.mbt`](../../../../../src/cli/cli_test.mbt)
- [`../../../raw/research/0065-2026-03-24-ir2-execution-plan.md`](../../../raw/research/0065-2026-03-24-ir2-execution-plan.md)
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
