---
kind: concept
status: supported
last_reviewed: 2026-07-16
sources:
  - ../../../raw/binaryen/2026-07-15-flatten-version-130-internal-output-recursive-ownership-impact.md
  - ../../../raw/binaryen/2026-07-15-flatten-version-130-nested-call-argument-impact.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-conditional-branch-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-loop-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-loop-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unreachable-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-add-unreachable-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unreachable-add-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-pure-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-pure-binary-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-add-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-add-two-multiplies-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-sub-two-multiplies-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-subtract-const-multiply-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-subtract-multiply-const-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-two-multiply-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-multiply-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-add-multiply-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-direct-nontrapping-binary-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-direct-nontrapping-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-direct-root-sequence-with-trap-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-direct-root-sequence-with-unreachable-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-direct-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-binary-call-argument-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unary-conversion-call-argument-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-two-constant-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-binary-plus-constant-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unary-conversion-plus-constant-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-constant-argument-vector-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-one-rich-argument-vector-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-binary-unary-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-binary-conversion-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-two-binary-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unary-conversion-pair-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-two-rich-argument-vector-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-one-multiply-child-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-two-multiply-children-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-deeper-two-multiply-children-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-direct-drop-const-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-add-multiply-roots-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-multiply-add-roots-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unary-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-trapping-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-loop-table-call-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-call-argument-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-legacy-eh-repair-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-unreachable-return-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-terminal-throw-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-conditional-consumer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-terminal-tail-call-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-block-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-if-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-branch-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-entry-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-table-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-conditional-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-conditional-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-result-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-try-tail-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-try-rich-tail-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-try-tail-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-try-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-try-conditional-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-reversed-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-two-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-three-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-scalar-try-two-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-two-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-two-block-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-unsupported-policy-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-conditional-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-11-flatten-current-main-and-local-status-recheck.md
  - ../../../raw/binaryen/2026-04-27-flatten-port-readiness-primary-sources.md
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

Binaryen implements `flatten` in `src/passes/Flatten.cpp` as a function-parallel Flat-IR normalizer; Starshine now has an internal active-partial `src/passes/flatten.mbt` owner with ordered scalar operand preludes, reachable/unreachable tee lowering across region roots and operand positions, branch-free scalar block/if routing, branch-free defaultable independently produced multivalue block/if, one exact exclusive tuple-made multivalue block tail, if-arm tail, plain block/if-targeting `br` payload, repeated-target `br_table` payload, or exact block/if-targeting `br_if` flow, and zero-input loop routing across payloadless backedges through exclusive consumer spans, branch-targeted independently scalar multivalue if arms with plain exits, branch-free scalar and independently produced multivalue legacy try do/catch routing behind an explicit catch-payload/exceptional-transfer prerequisite classifier, defaultable scalar branch-targeted if routing, zero-input and independently scalar or one exact tuple-made-entry inputful scalar-result loop routing with payloadless or independently scalar one- and multi-parameter `br`/`br_if` backedges, and plain scalar or independently scalar multivalue block-targeting `br`, including mixed fallthrough plus nested plain exits, scalar `br_if` routing including rich shared origins and the two-temp target/flow mismatch, same-vector multivalue block/if-targeting `br_if` routing with exact exclusive false-path spans, plus independently scalar `br_table` rich-origin and unique-target fanout for defaultable scalar block/if targets, exact repeated-label and nested multi-block multivalue targets, one- or multi-parameter loop entry channels, exact inputful multivalue loop plain branches and `br_if` channels with immediate direct-drop, same-typed binary with a simple opposite operand, one exact one-use rich right operand when the payload is left, or one exact pre-branch rich left paired with lane zero when the payload is right and the legacy-try or inputful-loop payload vector contains only individually supported rich origins, unary, or conversion false flow from independently scalar or tuple-made payloads, one exact exclusive tuple-made loop result tail, per-arm independently scalar or exact separately owned tuple-made legacy-try tails with supported scalar component origins, and exact loop-plus-enclosing-block, loop-plus-repeated-if, and loop-plus-repeated-block table channels, exact nonterminal legacy-try table representations with only direct `Unreachable` suffix roots, any positive number of exclusively owned distinct direct `drop(const)` roots, either exact two-root mixed order of direct `drop(const)` and direct `Unreachable`, either exact two-root mixed order of direct `drop(i32.add(const, const))` and direct `Unreachable`, any positive ordered sequence whose roots are independently owned direct `drop(const)`, direct `Unreachable`, or independently owned direct `drop(i32.add(const, const))`, `drop(i32.sub(const, const))`, `drop(i32.mul(const, const))`, `drop(i32.and(const, const))`, `drop(i32.clz(const))`, `drop(i64.extend_i32_s(const))`, or `drop(i32.div_s(const, const))`, or exact owned direct resultless calls with zero arguments, any positive vector of distinct scalar constants, exactly one audited binary, unary, or conversion argument plus any positive number of distinct scalar constants at arbitrary positions, or exactly two audited rich arguments from the admitted pair roster, with or without additional distinct scalar constants at arbitrary positions, or one exact scalar constant, `i32.add(const, const)`, `i32.div_s(const, const)`, `i32.clz(const)`, or `i64.extend_i32_s(const)` argument, or exact one- or two-multiply-child outer-add or outer-subtract drop trees with constant leaves, or one exact bounded outer add/subtract tree combining a matching two-multiply-child subtree and one direct constant; separately admitted single-root suffixes include exact `drop(i32.sub(const, const))`, any positive number of independently owned direct `drop(i32.mul(const, const))` roots, exact `drop(i32.and(const, const))`, exact `drop(i32.clz(const))`, exact `drop(i64.extend_i32_s(const))`, or exact `drop(i32.div_s(const, const))` root, plus exact owned direct resultless call suffixes with zero arguments, any positive vector of distinct exclusively owned scalar constants, exactly one audited binary, unary, or conversion argument plus any positive number of distinct exclusively owned scalar constants at arbitrary positions, or exactly two audited rich arguments from the admitted pair roster, with or without additional distinct scalar constants at arbitrary positions, or one exclusively owned scalar constant, exact `i32.add(const, const)`, exact `i32.div_s(const, const)`, exact `i64.extend_i32_s(const)`, or exact `i32.clz(const)` argument through admitted try-table ancestries, and owner-local terminal placeholders for nested `br`/`br_table`/`return`/`return_call`/`return_call_indirect`/`return_call_ref`/`throw`/`throw_ref`, while admitting exact untargeted void block, constant-condition complete-arm void if, and zero-input/no-backedge void loop drop-constant roots individually or in vectors mixed with exactly recognized ordinary roots through atomic descendant-plus-owned-label deletion and keeping richer, shared, targeted, or unsupported structured roots fail-closed, and keeping `flatten` publicly removed until broader control, payload, EH, and signoff work is complete.

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

Primary current-main URLs are captured in [`../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md`](../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md) and rechecked for port-readiness in [`../../../raw/binaryen/2026-04-27-flatten-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-flatten-port-readiness-primary-sources.md). The tagged `version_130` conditional-branch refresh is [`../../../raw/binaryen/2026-07-13-flatten-version-130-conditional-branch-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-conditional-branch-refresh.md), the matching switch/unique-target refresh is [`../../../raw/binaryen/2026-07-13-flatten-version-130-switch-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-switch-refresh.md), and the loop/table composition refresh is [`../../../raw/binaryen/2026-07-13-flatten-version-130-loop-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-loop-table-refresh.md); the earlier `version_129` provenance remains [`../../../raw/binaryen/2026-04-23-flatten-primary-sources.md`](../../../raw/binaryen/2026-04-23-flatten-primary-sources.md).

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

The refreshed `version_130` owner still treats all four `BrOn*` variants and `TryTable` as hard unsupported. Direct v130 probes show `BrOn` reports `Unsupported instruction for Flatten`, while `TryTable` reaches the earlier unhandled control-structure arm and aborts. Internal Starshine now classifies all five as `FlattenRunAdmission::UpstreamHardUnsupported` before mutation and returns unchanged only while public execution remains removed. Public admission still needs a tested Binaryen-compatible rejection path. Source: [`../../../raw/binaryen/2026-07-13-flatten-version-130-unsupported-policy-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-unsupported-policy-refresh.md).

The public policy choices remain:

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
| Internal owner | `src/passes/flatten.mbt`, `src/passes/flatten_test.mbt`, and `src/passes/flatten_wbtest.mbt` | The first slices classify Flat IR violations, materialize scalar function results, use `hot_loop_entry_values_clear(...)` to remove admitted loop input prefixes after ordered typed-local capture, lower reachable/unreachable tees at function roots, structured-region roots, and ordinary operand positions, sequence ordered scalar ordinary-operand preludes, route branch-free defaultable scalar block/if, independently produced multivalue block/if, one exact exclusive tuple-made multivalue block tail, if-arm tail, plain block/if-targeting `br` payload, repeated-target `br_table` payload, or exact block/if-targeting `br_if` flow, plus zero-input loop results across payloadless backedges, branch-targeted independently scalar multivalue if arms with plain exits, branch-free scalar legacy try do/catch results behind an EH-repair gate, branch-targeted defaultable scalar if, and zero-input or independently scalar / one exact tuple-made-entry inputful loop results across payloadless or independently scalar one- and multi-parameter `br`/`br_if` backedges, plus exact independently scalar inputful multivalue loop results for plain branch backedges, same-vector conditional backedges with one immediate reversed direct-drop, exact scalar-binary, or exact unary/conversion consumer span, and the admitted loop-plus-enclosing-block, repeated-if, and repeated-block table families, and redirect plain carried scalar `br`, independently scalar multivalue block-targeting `br`, including mixed fallthrough plus nested plain exits, plus scalar and same-vector multivalue `br_if` payloads through named target temp vectors for admitted block/if targets. The multivalue conditional route requires exact defaultable target/payload types, supported scalar origins, exactly one non-branch use per distinct payload, and one contiguous ordered false-path tail; it clears payload children while preserving the condition and lets control-result routing reuse the same reads. Same-type scalar `br_if` preserves its false-path flow through a shared `local.get`; rich ordinary payloads retain one producer, run before the condition, and feed chained conditionals through locals; the target/flow-type mismatch uses a second correctly typed flow temp and one target copy. All admitted block, if, and loop targets share one per-label typed local vector with centralized allocation and type matching. Branch-free multivalue blocks and ifs plus zero-input multivalue loops with payloadless backedges use that vector when their defaultable scalar tails map to one exclusive repeated HOT consumer span, preserving result order while erasing the control result. Independently scalar `br_table` payloads retain one producer each, store in source order before selector preludes, copy to every unique admitted block/if target temp or one- or multi-parameter loop entry-local vector, clear their payloads, and remove dead terminal producer roots. The first inputful multivalue-result loop lane permits exact loop-plus-enclosing-block fanout and routes independently scalar fallthrough tails through a separate result vector. Scalar legacy tries write exact do/catch tails into one shared typed local and become void; exact scalar try-label `br_if` additionally admits one immediate direct-drop, unary, conversion, or same-typed binary false-flow consumer with a simple opposite operand, while the exact multivalue family redirects one immediate reversed span of direct drops, independently scalar / exclusively tuple-made single-use unary/conversion or same-typed binary consumers with simple opposite operands or exact one-use rich right operands when the payload is left through the shared typed channel, and keep independent do/catch fallthrough routing; multivalue tuple payloads require exclusive repeated ownership and are scalarized once. Exact terminal scalar `br_table` families admit one repeated try target or that try plus any complete strict direct-enclosure chain of matching defaultable block/if controls in structural order without a hardcoded count cap. Exact multivalue families admit one repeated try target; independently scalar payloads may target the same arbitrary strict direct mixed order, including try-inside-if-inside-block; one exclusively owned repeated-`TupleMake` payload may target the same arbitrary strict direct block/if ancestry after separate exclusive-ownership, component, one-evaluation, and safe-deletion preflight, without a hardcoded count cap. Payload stages copy into distinct per-label typed channels before selector work, and multivalue try fallthrough uses one exclusive repeated region-tail span. Direct try-table ancestry now uses one structural child-to-parent map plus an outward chain walk, with private tests for ordered extraction, skipped block/loop ancestry rejection, direct loop extraction, non-root rejection, and reverse if-inside-block extraction; exact scalar and independently scalar tables may route into one inputful enclosing loop after loop input/backedge/result preflight, and one exclusively owned repeated-HOT-`TupleMake` payload may use the same loop route after separate exact-use, component, loop-backedge, and deletion preflight; a warm filtered run of the three-block-plus-thirty-two-if fixture completed in 0.187s. Branch-free multivalue legacy tries write per-arm exact independently scalar tails or separately owned exact tuple-made tails with supported scalar component origins into one shared typed vector when one exclusive repeated consumer or region-tail span owns the results. `flatten_eh_repair_requirement(...)` classifies missing catch-payload tracking separately from exceptional-transfer repair, and one scalar first-descendant `Catch` family through direct blocks or an `if` condition and arbitrary ordered same-tag direct-block-chain lane vectors repair through entry locals, while unsupported catch populations, partial/mixed-tag vectors, then/else paths, other non-first-descendant or repeated uses, broader lane paths, nested catches, loops/multiple execution, sharing/outside ownership, and catch-all payload extraction stay whole-function fail-closed; any positive depth-zero catch-all rethrow population through arbitrary strict direct resultless untargeted block/if ancestry and one resultless outer-target delegate whose sole catch representation is direct or a strict direct resultless single-root unused-label block chain are admitted, while broader exceptional-transfer populations stay fail-closed. Nested terminal `br`/`br_table`/`return`/`return_call`/`return_call_indirect`/`return_call_ref`/`throw`/`throw_ref` operands leave an `unreachable` placeholder while owner-region tracking preserves exactly one real effect, branch payloads, tail-call operands, and throw arguments flatten before the terminal in source order, and scalar body-result materialization refuses unsupported root controls. Mismatched or ambiguously shared multivalue conditional payloads, mixed if/loop or nonexclusive multivalue table payloads, and nested or nonexclusive conditional multivalue loop controls remain open behind the whole-function gate. |
| Old IR2 batch intent | `../../../raw/research/0065-2026-03-24-ir2-execution-plan.md:69-70` | `flatten` still leads the old preferred Batch 2 implementation order. |
| Old registry-map batch status | `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md:107-108` | `flatten` remains documented as removed until implementation lands. |
| Active backlog | `agent-todo.md` `[O4Z-FLAT]001` | Tracks the remaining source refresh, control/EH implementation, public wiring, profile, closeout, and aggressive-neighborhood proof. |

## Latest internal output, ownership, proof-cache, and batch-mutation slices

Commits `b789c2ff7`, `a2ce97352`, and `7af372b56` add one behavioral test each for resultless synthetic catch-all `Try` lowering, recursive owned call-argument trees, and direct subtraction plus ownership-result reuse. Commits `23f779aa8` and `32da5c798` add one red-first invariant/behavior test each for exact terminal-table cache completeness and direct unsigned-shift ownership, while removing duplicate generic routing after dedicated payload-bearing branch handling. Current commits `b610394b4` and `56908b781` add one red-first invariant each for lightweight reachable use-count equivalence and one-revision exact detached-set deletion. The recursive collector records all immediate arguments before descendants, preserves left-to-right traversal, has no tree-depth cap, and requires every call, argument, intermediate, and leaf to be distinct and one-use before deletion.

A detached-baseline matrix now proves actual current Starshine lowering, encoding, validation, execution, and cleanup for three synthetic catch-all probes. Nonthrowing synthetic-try elision reduces current Starshine to `212` direct and cleanup bytes, versus Binaryen's `275` direct and `236` cleanup bytes, so this narrow bridge/control/local family remains a measured 24-byte post-cleanup Starshine win. Exact terminal-table support joins run-wide suffix, EH, effective-terminal, scalar-try, and label-use caches; payload-bearing branch rewrites no longer retry generic routers; suffix ownership now uses lightweight reachable counts; and exact detached node vectors delete with one revision invalidation. The representative 120-function pass-only median is now `970.5 us`, versus `266.05 us` for Binaryen v130, so performance remains `3.65x` slower and blocks public admission. Direct `i32.shl`, `i32.shr_s`, and `i32.shr_u` resultless-call roots share the recursive complete-ownership proof; `i32.rotl` is the current private outside-roster boundary. The EH prerequisite behavior test still proves both exact deferred outcomes and no partial operand/local mutation. The new batch API does not remove owned label metadata, so structured suffix controls remain gated. See the [current impact note](../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md) and the retained [prior baseline](../../../raw/binaryen/2026-07-15-flatten-version-130-internal-output-recursive-ownership-impact.md).

The next exact two-code iteration adds commits `c6181e26d` and `0a415161f`. The first builds one label-to-branch-node index, deduplicates repeated table labels, derives `label_used` from the same scan, and removes the full-node scalar-target scan. The second adds a private exact region-root replacement helper and routes one-for-one scalar/multivalue control tails through it instead of full region splices. Their red-first invariants are `flatten label branch cache records each exact targeting node once` and `flatten replaces one region root without rebuilding its siblings`.

The next exact two-code iteration adds commits `13fe7b744` and `9acdac744`. The first adds a public HOT region-suffix truncation mutation and applies it to admitted terminal-table suffixes, replacing holder-span reconstruction with exact prefix-preserving detachment before batch tombstoning. Its red-first invariant is `body region suffix truncation preserves the existing child span`. The second makes rewrite-time scalar branch-target proof consume the pre-mutation `label_branch_nodes` snapshot for `br`, `br_if`, and `br_table`; its red-first invariant is `flatten rewrite scalar target proof uses the pre-mutation branch index`.

Validation is now focused region editing `4/4`, focused flatten `245/245`, private flatten `147/147`, passes `5,722/5,722`, and full suite `9,183/9,183`. The only `.mbti` change is `hot_region_truncate_suffix`; no public pass surface changed. The reconstructed candidate chain improved from clean HEAD `1,116.5 us` to code 1 `1,053.5 us` (`5.64%`). Code 2's samples were noisy and slower, so it is proof-boundary correctness/scan-removal rather than a measured performance win. The prior stable `970.5 us` checkpoint remains about `3.65x` Binaryen, so neither iteration is public-readiness evidence.

The next exact two-code iteration adds commits `9aa7499e9` and `710cdc910`. The first threads `FlattenRewriteState.label_branch_nodes` through multivalue target support, recursive table-target checks, deferred rich-payload admission, and rewrite-time branch routing. Its red-first invariant is `flatten rewrite multivalue target proof uses the pre-mutation branch index`; a post-snapshot malformed branch makes the uncached support check fail but cannot widen the rewrite proof. The second adds `flatten_rewrite_br_table_target_locals(...)`, which first preflights all target kinds and existing vector types without mutation, then resolves each target vector once and reuses it across all lanes. Its red-first invariant is `flatten resolves each br_table target local vector once`.

Validation is now focused flatten `245/245`, private flatten `149/149`, passes `5,724/5,724`, full suite `9,185/9,185`, and green `moon info`, targeted formatting, and diff checks. No `.mbti` or public pass surface changed. A 120-function multivalue branch fixture improved from `5,581.5 us` to `5,099 us` in one same-session order (`8.64%`); the two-target/four-lane table fixture reversed direction across run order, so the vector-resolution slice is not classified as a measured speed win. The prior stable `970.5 us` candidate checkpoint remains about `3.65x` Binaryen.

The next exact two-code iteration adds commits `e39faf79e` and `e64428dc1`. The first makes multivalue legacy-try label support consume the immutable pre-mutation branch index; its red-first invariant proves post-snapshot branches cannot widen rewrite-time try proof. The second replaces full node-use/use-def construction in multivalue legacy-try and loop conditional-flow proofs with exact lightweight reachable counts and adds an explicit rewrite-only ownership boundary.

Validation is now focused flatten `245/245`, private flatten `151/151`, passes `5,726/5,726`, full suite `9,187/9,187`, and green `moon info`, targeted formatting, and diff checks. No `.mbti` or public pass surface changed. The 120-function tuple-made legacy-try `br_if` fixture improved `16,524.5 -> 16,167 -> 6,724.5 us` (`59.31%` total). The stable representative checkpoint remains `970.5 us` (`3.65x` Binaryen), so this targeted win does not satisfy public performance readiness.

The next exact two-code iteration adds commits `3d0acb44e` and `19fa4eda8`. The first replaces two full region-tail tuple use-site builds with the immutable reachable-use counts already owned by `FlattenRewriteState`; its red-first invariant is `flatten rewrite region tail tuple proof uses pre-mutation ownership counts`. The second threads state through inputful-loop support/rewrite, replaces full live-node loop branch scans with the immutable per-label branch population, and reuses the same count snapshot for tuple conditional flow; its invariant is `flatten rewrite multivalue loop proof uses the pre-mutation branch index`.

Validation is now focused flatten `245/245`, private flatten `153/153`, passes `5,728/5,728`, full suite `9,189/9,189`, and green `moon info`, targeted formatting, and diff checks. No `.mbti` or public pass surface changed. The tuple-tail fixture improved `6,569 -> 4,144.5 us` (`36.91%`), and the loop fixture improved `8,344 -> 6,870 us` (`17.67%`). The reconstructed representative fixture remained noisy, so the stable `970.5 us` / `3.65x` checkpoint still blocks public readiness.

The next exact two-code iteration adds commits `3a88b5bd6` and `5c0235d71`. The first replaces full use-site allocation for exact tuple-made inputful-loop entries with the frozen reachable counts, requiring exactly the known entry-slot and reversed-drop uses; its invariant is `flatten rewrite tuple loop entry proof uses pre-mutation ownership counts`. The second applies the same snapshot boundary to exact scalar legacy-try `br_if` payload and rich-consumer ownership; its invariant is `flatten rewrite scalar try flow uses pre-mutation ownership counts`.

Validation is now focused flatten `245/245`, private flatten `155/155`, passes `5,730/5,730`, full suite `9,191/9,191`, and green `moon info`, targeted formatting, and diff checks. No `.mbti` or public pass surface changed. The tuple-entry fixture improved `10,895.5 -> 4,506 us` (`58.64%`), and the scalar-try fixture improved `8,867.5 -> 4,214.5 us` (`52.47%`). These targeted wins do not replace the stable representative `970.5 us` / `3.65x` public gate result.

The next exact two-code iteration adds commits `24ca31723` and `32690a37d`. The first replaces tuple-made plain branch/table payload use-site allocation with the frozen reachable count plus structurally known payload slots; its invariant is `flatten rewrite tuple branch payload proof uses pre-mutation ownership counts`. The second removes the final full node-use/use-site builder from flatten by locating generic tuple-made block/if `br_if` false-flow sites once during admission, caching the exact positive or negative result by branch id, and requiring that cache after rewriting starts; its invariant is `flatten rewrite tuple br_if flow uses pre-mutation exact site cache`.

Validation is now focused flatten `245/245`, private flatten `157/157`, passes `5,732/5,732`, full suite `9,193/9,193`, and green `moon info`, targeted formatting, owner verification, and diff checks. No `.mbti` or public pass surface changed. The tuple branch fixture improved `13,697 -> 5,238 us` (`61.76%`), and the tuple block-`br_if` fixture improved `12,764.5 -> 5,578.5 us` (`56.30%`). The stable representative remains the unrequalified `970.5 us` / `3.65x` public gate result.

The next exact two-code iteration adds commits `ae096a883` and `b87464d25`. The first caches exact positive or negative distinct non-tuple multivalue block/if `br_if` flow spans during admission and requires that cache after mutation starts. The second snapshots scalar `br_if` flow parents, re-resolves only the same parent populations after prelude-induced slot shifts, and records replacement identity so chained branches cannot authorize an unrelated post-snapshot local read. Their red-first invariants are `flatten rewrite multivalue br_if flow uses pre-mutation exact site cache` and `flatten rewrite scalar br_if flow uses pre-mutation exact site cache`.

Validation is focused flatten `245/245`, private flatten `159/159`, passes `5,734/5,734`, full suite `9,195/9,195`, and green `moon info`, targeted formatting, owner verification, and diff checks. The distinct 600-function fixture moved `30 -> 28 ms`; the scalar fixture moved `22 -> 23 ms`, so only the first is directional performance evidence and neither requalifies the durable gate. No `.mbti` or public pass surface changed.

The next exact two-code iteration adds commits `e165fde1c` and `476848f9d`. The first replaces node-sized tuple, multivalue, scalar `br_if`, and chained-flow replacement arrays with sparse exact admission entries. The second does the same for dead suffix, terminal-table, and scalar-try decisions. Their red-first invariants prove that 256 unrelated nodes allocate no proof entries and that each inspected owner adds exactly one matching entry. Existing mutation-time tests continue to prove that missing or mismatched entries cannot widen rewrite admission.

Validation is focused flatten `245/245`, private flatten `161/161`, passes `5,736/5,736`, full suite `9,197/9,197`, and green `moon info`, targeted formatting, owner verification, and diff checks. No `.mbti` or public pass surface changed. The reconstructed three-family benchmark showed only coarse directional movement for code 1 and no code-2 timing win; the durable `970.5 us` / `3.65x` checkpoint remains unrequalified.

The next exact two-code iteration adds commits `7801166ac` and `18101a947`. The first proves that only carried plain `br` nodes need the generic postorder router after recursive operand handling; payload-bearing `br_if` and `br_table` already use dedicated arms that return, while ordinary and payloadless nodes need no generic routing attempt. The second proves that sequence-root deduplication needs storage only for nodes with more than one reachable pre-mutation owner. Its frozen node limit is part of the invariant: the first implementation caused five focused failures by querying rewrite-created ids against the old count population, and the corrected helper rejects those ids before lookup.

Validation is focused flatten `245/245`, private flatten `163/163`, passes `5,738/5,738`, full suite `9,199/9,199`, and green `moon info`, targeted formatting, owner verification, and diff checks. No `.mbti` or public pass surface changed. A recovered native-release pass-only path measured the root-heavy fixture at `57,498 -> 52,402 -> 52,534.5 us` and the reconstructed representative at `1,177 -> 1,176 -> 1,171.5 us`. Code 1 is a measured targeted traversal win; code 2 is allocation-footprint/proof-boundary work with overlapping timing. The durable `970.5 us` / `3.65x` checkpoint remains unrequalified.

The next exact two-code iteration adds commits `81cfb9619` and `dda2bdfe3`. The first removes the separate staging vector only when repeated/default `br_table` labels deduplicate to one unique target; the payload writes directly to the resolved target locals before selector work, while multi-target fanout is unchanged. Its red-first invariant covers both sides of that boundary, and existing behavior tests now lock the reduced scalar, tuple, loop, legacy-try, suffix, and placeholder shapes. A focused module encodes at `47` bytes versus `51` before the change. The second caches exact inputful-loop support decisions and refuses uncached discovery after mutation starts; its invariant adds a malformed post-snapshot backedge and proves the cached result remains the admission result.

Validation is focused flatten `245/245`, private flatten `165/165`, passes `5,740/5,740`, full suite `9,201/9,201`, and green `moon info`, targeted formatting, owner verification, and diff checks. No `.mbti` or public pass surface changed. Reconstructed timing was overlapping/flat, so code 1 is classified by its measured size and operation-count win and code 2 by its proof-boundary/repeated-support removal. The durable `970.5 us` / `3.65x` performance gate remains unrequalified.

The next exact two-code iteration adds commits `6a74918d6` and `1acb9bc14`. The first replaces `branch_nodes[label].contains(node_id)` with a monotonic per-label last-recorded-node guard, preserving exact node order while deduplicating repeated/default labels from the current table or try-table node in constant time. The second extends that same immutable live-node scan to collect exact loop, legacy-try, and payload-bearing branch admission rosters; the three deferred-family checks now iterate those populations rather than rescanning every live node.

Validation is focused flatten `245/245`, private flatten `167/167`, passes `5,742/5,742`, full suite `9,203/9,203`, and green `moon info`, targeted formatting, owner verification, and diff checks. The branch-dense fixture improves `17,065 -> 14,723 us` (`13.72%`); the root-heavy fixture improves `54,596 -> 51,076.5 us` (`6.45%`) with a `49,953.5 us` rerun; the reconstructed representative moves directionally `1,111.5 -> 1,066 us`. No `.mbti`, semantic family, or public pass surface changed, and the durable `970.5 us` / `3.65x` gate remains unrequalified.

The next exact two-code iteration adds commits `7706110c1` and `2c5a54ac3`. The first extends `FlattenPreMutationNodeIndex` with the exact `FlattenEhRepairRequirement`, setting typed-catch-payload and exceptional-transfer bits during the existing live-node scan and preserving `Delegate` label indexing. Its single red-first invariant is `flatten pre-mutation node index shares EH prerequisite classification`; `FlattenRewriteState` now reuses the indexed requirement rather than calling a separate whole-node classifier.

The second factors exact per-live-node and function-tail Flat IR classification, stores the complete report in the same pre-mutation index and rewrite state, and makes `flatten_run` consume that frozen report. Its single red-first invariant is `flatten pre-mutation node index shares flatness classification`, comparing rich operands, value control, hard-unsupported control, and concrete body flow against the standalone classifier. The standalone analysis API remains behaviorally identical.

Validation is focused flatten `245/245`, private flatten `169/169`, passes `5,744/5,744`, full suite `9,205/9,205`, and green `moon info`, targeted formatting, owner verification, and diff checks. Code 1's reconstructed representative improves `1,131 -> 1,060 us` (`6.28%`); code 2 timings overlap or regress by order and are not classified as a win. No `.mbti`, semantic family, registry, dispatcher, CLI execution, compare/API, generator, or preset surface changed, and the durable `970.5 us` / `3.65x` gate remains unrequalified.

The next exact two-code iteration adds commits `c420a9950` and `9b5c4170a`. The first keeps scalar legacy-try proof entries sorted by exact pre-mutation try id, uses binary search for lookup, and inserts without node-sized storage. Its single red-first invariant is `flatten scalar try proof cache keeps sparse entries sorted`; the old append-only order failed as `[16, 4, 10]` instead of `[4, 10, 16]`.

The second applies the same sparse sorted lookup contract to dead-suffix and terminal-table entries keyed by exact table node id. Its single red-first invariant is `flatten terminal proof caches keep sparse entries sorted`; the old append-only order failed as `[33, 7, 20]` instead of `[7, 20, 33]`. Existing region, label, payload-arity, mixed-target, support, ownership-vector, and rewrite-boundary checks are unchanged, and the first proof for an owner is never widened by a later insertion.

Validation is focused flatten `245/245`, private flatten `171/171`, passes `5,746/5,746`, full suite `9,207/9,207`, and green `moon info`, targeted formatting, owner verification, and diff checks. The scalar candidate-density median improves `7,115.5 -> 6,689.5 us` at 512 candidates per function; the terminal density median improves `22,708.5 -> 9,426 us` at 256 candidates per function. The representative reconstruction overlaps by order (`1,069.5` baseline versus `1,108` then `1,063 us` current). No `.mbti`, semantic family, or public surface changed, and the durable `970.5 us` / `3.65x` gate remains unrequalified.

The next exact two-code iteration adds commits `e32819f5b` and `fc5c89bff`. The first keeps inputful-loop support entries sparse and sorted by exact pre-mutation loop id; its red-first invariant queried three supported loops out of order and failed with `[11, 1, 6]` instead of `[1, 6, 11]`. The second keeps scalar `br_if` flow sites sorted by branch id and same-state replacements sorted by original value id; its invariant failed with branch order `[17, 3, 10]` instead of `[3, 10, 17]`. Binary lookup now serves all three populations, first admission proofs remain authoritative, replacement updates remain supported, and rewrite-time absent entries still fail closed.

Validation is focused flatten `245/245`, private flatten `173/173`, passes `5,748/5,748`, full suite `9,209/9,209`, and green `moon info` with 11 existing warnings. At fixed 2,048 candidates, inputful loops improve `14,038 -> 12,694 us` (`9.57%`) and scalar flow improves `36,469 -> 35,250.5 us` (`3.34%`) at 128 candidates per function. These are targeted lookup wins; no `.mbti`, semantic family, registry, dispatcher, CLI execution, compare/API, generator, or preset surface changed, and the durable `970.5 us` / `3.65x` gate remains unrequalified.

The next exact two-code iteration adds commits `80e6a652b` and `efb8fdfa2`. The first keeps tuple-made multivalue `br_if` flow entries sorted by exact pre-mutation branch id; its single red-first invariant failed with `[17, 5, 11]` instead of `[5, 11, 17]`. The second switches the distinct non-tuple flow population to the same sorted sparse helper and removes the final linear conditional-flow cache lookup; its invariant failed with `[14, 4, 9]` instead of `[4, 9, 14]`.

Validation is focused flatten `245/245`, private flatten `175/175`, passes `5,750/5,750`, full suite `9,211/9,211`, and green `moon info` with 11 existing warnings. Exact cached-lookup medians at 512 candidates improve `304,931 -> 160,577 us` for tuple flow and `365,408.5 -> 120,985.5 us` for distinct flow. No `.mbti`, semantic family, or public surface changed, and the durable `970.5 us` / `3.65x` gate remains unrequalified.

The next exact two-code iteration adds commits `bdad9efaf` and `902848fca`. The first replaces the quadratic growing-vector target deduplication in `flatten_unique_br_table_targets(...)` with one label-sized bitset and an exact record helper. Its red-first invariant proves first explicit-target order, duplicate suppression, mark retention, invalid-label rejection, and default-target compatibility. The second keeps `FlattenRewriteState.terminal_payloads` sparse and sorted by exact node id, rejects duplicate records, and uses binary membership in scalar block tail repair plus recursive region-root removal. Its invariant queried payloads in mixed order and required exact present/absent results.

Validation is focused flatten `245/245`, private flatten `177/177`, passes `5,752/5,752`, full suite `9,213/9,213`, and green `moon info` with 11 existing warnings. The exact 512-label extraction reconstruction improves `437,000 -> 16,000 us`; the 512-root membership reconstruction improves `110,000 -> 20,000 us`. No `.mbti`, semantic family, or public surface changed, and the durable `970.5 us` / `3.65x` gate remains unrequalified.

The allocation/index follow-up adds five private invariants and no new WAT family. `FlattenPreMutationNodeIndex` now freezes unique `br_table` targets into sparse entries plus one flat pool. `FlattenRewriteState` lazily builds structural parents before mutation, reuses generation-mark and depth-indexed prelude scratch, caches type results by dense type id, and preflights target locals without materializing an outer nested array. `pass_splice_region(...)` copies ids into region storage, so clearing a reused prelude buffer after the call cannot mutate the region. Exact one-use/two-use ownership checks replace only the duplicate scans they mathematically dominate; other `contains` checks remain where use counts do not prove uniqueness.

The red-first file moves from `177/177` to `182/182`; focused flatten remains `245/245`. Targeted medians improve ancestry `76.22%`, table-target lookup `96.88%`, type-result lookup `73.33%`, target-local preflight `11.69%`, and root-heavy traversal `9.68%`. The reconstructed representative moves directionally `1,001.5 -> 989.5 us` with overlapping ranges. Passes are `5,757/5,757`, the full suite is `9,218/9,218`, `moon info` reports 11 existing warnings and no errors, the native release CLI builds, and no `.mbti` or public surface changes.

The next exact two-code iteration adds commits `4a03de7f3` and `aa295d38b` without widening behavior. The first keeps shared sequenced-root holder/node pairs sparse, sorted, and binary-searchable; its red-first invariant rejects duplicate and cross-pair matches while preserving exact mixed-order insertion. The second collects distinct multivalue `br_if` payload ids with a temporary mark set, preserves source order, rejects repeated ids, and reuses marked membership for root exclusion while leaving cached false-flow parent/slot checks unchanged.

The exact 512-candidate reconstructions improve sequenced-root lookup `31,569 -> 2,664 us` (`91.56%`) and multivalue payload distinctness `64,554 -> 2,757 us` (`95.73%`). Final validation is private flatten `184/184`, focused flatten `245/245`, passes `5,759/5,759`, full suite `9,220/9,220`, and green `moon info` with 11 existing warnings. No `.mbti`, semantic family, output shape, registry, dispatcher, CLI execution, compare/API, generator, or preset surface changed.

The next exact two-code iteration adds commits `f1dc57565` and `24b909b2d` without widening behavior. The first maps each distinct non-tuple multivalue `br_if` payload id to its exact source slot once, replacing the nested child-edge-to-every-payload scan while retaining exact counts, branch-slot exclusion, unique parent ownership, and contiguous order. The second replaces tuple false-flow slot `contains` scans with one parent-sized mark array while retaining first-position order and the final sorted contiguous-span proof. Their red-first invariants are `flatten multivalue flow payload slots preserve exact source positions` and `flatten tuple flow slot marks preserve exact first positions`.

At 512 candidates, the targeted native-release reconstructions improve non-tuple flow indexing `1,878 -> 39 us` (`97.92%`) and tuple slot distinctness `59,644 -> 1,368 us` (`97.71%`). Final validation is private flatten `186/186`, focused flatten `245/245`, passes `5,761/5,761`, full suite `9,222/9,222`, and green `moon info` with 11 existing warnings. No `.mbti`, semantic family, output shape, registry, dispatcher, CLI execution, compare/API, generator, or preset surface changed.

The next exact two-code iteration adds commits `2ae0a6adb` and `d64535310`. The first admits independently scalar multivalue `br_if` lanes as either operand of one immediate directly dropped same-typed binary when the opposite operand is Flat-IR-simple; its red-first legacy-try fixture failed unchanged at `245/246`. The second applies the same exact child-slot rule to an exclusively owned repeated `TupleMake`; its fixture failed unchanged at `246/247`. Slot-aware rewrite changes only the payload child and leaves the binary, simple sibling, opcode, and false-path placement intact.

Validation is focused flatten `247/247`, private flatten `186/186`, passes `5,763/5,763`, full suite `9,224/9,224`, and green `moon info` with 11 existing warnings. Fresh pinned-v130 multivalue-tuple/left-lane and scalar-reversed probes support the combined source rule. No `.mbti` or public surface changed. Remaining work is feature-first: typed EH/pop repair, exceptional transfer, structured control-plus-label deletion, broader mixed/shared flow, then generator/signoff/neighborhood/public admission. Millisecond-scale micro-optimization is not a priority while those families remain open.

The next exact two-code iteration adds commits `5c4a664dd` and `a4055b7a9`. The first red-first fixture admits independently scalar payload-left binaries with exact one-use rich right operands; the second applies the same rule to one exclusively owned repeated `TupleMake`. The common consumer helper is shared by exact legacy-try and inputful-loop flow. Generic postorder operand routing materializes the rich right operand after the payload-free branch and before the binary, while payload-right binaries retain the simple-left requirement.

Validation is focused flatten `249/249`, private flatten `186/186`, passes `5,765/5,765`, full suite `9,226/9,226`, and green `moon info` with 11 existing warnings. Pinned-v130 legacy-try and loop probes confirm the same after-branch call placement. No `.mbti`, public registry, dispatcher, CLI execution, compare/API, generator, or preset surface changed. Remaining work is feature-first and the durable performance gate remains unrequalified.

The next exact two-code iteration adds commits `e5c2a91ea` and `d0a53acf9`. The first admits one independently scalar rich-left/payload-right legacy-try lane; the second applies the same proof to one exclusively owned repeated `TupleMake`. Admission requires one one-use supported rich left, the complete payload vector to be simple, and the rich binary to consume lane zero as the final reversed false-flow consumer. Rewrite stages the rich left before payload locals and `br_if`, then leaves the exact binary after the branch.

The red-first focused fixtures fail unchanged at `249/250` and `250/251`, then pass at `251/251`. Private flatten remains `186/186`, passes reach `5,767/5,767`, full reaches `9,228/9,228`, and `moon info` is green with 11 existing warnings. Pinned-v130 independently scalar and tuple-oriented probes confirm pre-branch left-call placement and post-branch binary execution. No `.mbti`, public registry, dispatcher, CLI execution, compare/API, generator, preset, or performance surface changed.

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

## Latest inputful-loop rich-left behavior iteration

Commits `843614438` and `35ac3740a` add one red-first behavior test each for independently scalar and exclusively tuple-made inputful-loop flow. The scalar helper now returns exact branch-root, rich-left, and binary identities after proving every payload is simple, defaultable, type-matched, supported, and exactly branch-plus-consumer owned. The tuple helper returns the same identities alongside the tuple/root pair and additionally requires every ordered component to be simple and the tuple to own every branch and consumer slot.

Rewrite materializes the rich left before payload-local writes and `br_if`, changes only the binary's left child to a local read, and leaves the binary on the false path. The tuple shell is deleted only after every branch and consumer use is replaced. Red-first focused counts move `251/252 -> 252/252` and `252/253 -> 253/253`; private flatten remains `186/186`, passes reach `5,769/5,769`, full reaches `9,230/9,230`, and `moon info` is green. No `.mbti` or public pass surface changed.

## Latest inputful-loop rich-payload behavior iteration

Commits `3cb5577ad` and `c5a0a738a` add one red-first behavior test each for independently scalar and exclusively tuple-made inputful-loop flow with pre-branch rich-left work plus one rich payload origin. The scalar route admits at most one non-simple payload under the existing supported-origin, type, defaultability, exact branch-plus-consumer ownership, lane-zero binary, and current-structure proof. The tuple route applies the same bounded vector rule under complete repeated-`TupleMake` ownership.

The tuple slice exposed an ordering hazard after admission first succeeded: recursive component flattening had already appended the rich-payload prelude, so a normal `push` placed the rich-left store too late. The final route inserts that store at prelude index zero, matching pinned-v130 order before the payload vector, condition, and `br_if`; tuple deletion still waits for complete replacement. Red-first counts move `253/254 -> 254/254` and `254/255 -> 255/255`; private flatten remains `186/186`, passes reach `5,771/5,771`, full reaches `9,232/9,232`, and `moon info` is green. No `.mbti` or public pass surface changed.

## Latest legacy-try rich-payload behavior iteration

Commits `61055698d` and `d9aa4cd94` add one red-first behavior test each for independently scalar and exclusively tuple-made legacy-try flow with pre-branch rich-left work plus one rich payload origin. The scalar slice applies the existing at-most-one-rich-payload vector proof and inserts the left store before child-generated payload preludes. The tuple slice applies the same rule under complete repeated-`TupleMake` ownership and deletes the shell only after every branch and consumer slot is replaced.

Red-first focused counts move `255/256 -> 256/256` and `256/257 -> 257/257`; private flatten remains `186/186`, passes reach `5,773/5,773`, full reaches `9,234/9,234`, and `moon info` is green with 11 existing warnings. Fresh pinned-v130 scalar and tuple-oriented probes preserve left, payload-vector, condition, payload-free-branch, and false-path-binary order. No `.mbti` or public pass surface changed.

## Latest multiple-rich-payload behavior iteration

Commits `6e4229bae` and `f223f14d6` add one red-first behavior test each for exact legacy-try and inputful-loop flow with a pre-branch rich left and two rich payload origins. The first test covers independently scalar ownership in both controls. The second covers one exclusively owned repeated `TupleMake` in both controls and additionally proves the shell is deleted only after every branch and consumer use is replaced.

The shared vector helper now accepts all supported rich origins only when the calling family opts into the widened proof. Scalar flow requires every distinct payload to retain exactly one branch edge and one immediate false-flow consumer. Tuple flow retains complete repeated-shell branch-slot/consumer coverage, ordered supported components, defaultable types, lane-zero rich-left identity, and delayed deletion. Red-first focused counts move `257/258 -> 258/258` and `258/259 -> 259/259`; private flatten remains `186/186`, passes reach `5,775/5,775`, full reaches `9,236/9,236`, and `moon info` is green with 11 existing warnings. Four fresh pinned-v130 probes preserve left, all payload calls in vector order, condition, payload-free branch, and false-path binary order. No `.mbti` or public pass surface changed.

## Latest ordered catch-payload repair slice

Commits `43ea95972` and `49079c0dc` extend the typed `HotOp::Catch` bridge to one exact ordered two-lane family while preserving the scalar APIs. `src/ir/hot_mutate.mbt` exposes `hot_ordered_catch_payloads_repairable(...)` and `hot_repair_ordered_catch_payloads(...)`. Whole-function preflight requires two childless same-tag scalar markers, one exclusive direct block chain, and final-region roots zero and one whose unary paths end at the matching lanes with no extra use. Local ids retain `i32`/`f32` source order, entry captures run lane one then lane zero to consume the handler stack, and old positions become local reads. The partial-second-lane negative locks revision, nodes, locals, roots, region roots, and all original edges.

`src/passes/flatten.mbt` now uses the ordered planner, applies repair before ordinary flattening, and rebuilds `FlattenRewriteState`. `src/ir/hot_lower.mbt` accepts at most two same-tag lanes and resolves exactly two through an existing result-only multivalue block type. The whitebox fixture locks ordered capture/read identity, nested blocks, the enclosing branch, HOT verification, lowering, and module validation against a tag `(param i32 f32)`.

Validation is HOT mutation `16/16`, IR `326/326`, focused flatten `263/263`, whitebox flatten `188/188`, passes `5,781/5,781`, and full `9,250/9,250`. The generated IR snapshot adds only the two generic ordered repair APIs; the lowering/pass slice changes no `.mbti`. Non-first-descendant/repeated uses, broader independent lane paths, nested catches, loops/multiple execution, and catch-all payload extraction remain unsupported; no public flatten pass API or wiring exists.

## Latest ordered catch breadth slice

Commits `82c4c260c` and `95f71db1e` reuse the existing public ordered repair APIs without changing their signatures. `src/ir/hot_mutate.mbt` now builds one arbitrary-length same-tag lane plan from the leading catch markers and ordered final-region roots, while preserving complete preflight and reverse capture order. `src/ir/hot_lower.mbt` removes the temporary two-lane abort and resolves any matching result-only handler type. The scalar lane walker also follows `HotOp::If` only through child zero, matching Binaryen v130's condition-first `getFirstPop(...)` rule.

`src/passes/flatten_wbtest.mbt` adds one three-lane `i32`/`f32`/`i64` fixture and one scalar nested-if-condition fixture. Their red states were `190/191` and `191/192`; final results are whitebox `192/192`, focused flatten `263/263`, IR `326/326`, passes `5,785/5,785`, and full `9,254/9,254`. Both lower and validate. No `.mbti` or public flatten surface changed. The older exact-two-lane section is retained as chronology but its lane-count and if-control blockers are superseded here.

## Latest direct exceptional-transfer lowering slice

Commits `d76a91b3f` and `7bfb10372` add no new public API. `src/passes/flatten.mbt` now distinguishes two exact supported populations from the existing exceptional-transfer prerequisite: one depth-zero catch-all rethrow under direct block ancestry, and one resultless delegated try whose sole delegate root targets the directly enclosing outer try and whose own label has no users. Every other exceptional-transfer population retains `DeferredExceptionalTransferRepair` before mutation.

`src/ir/hot_lower.mbt` carries an active legacy-rethrow exception-local stack through lowering. The admitted rethrow handler uses `catch_all_ref`, captures the exception reference into an extra nullable `exnref` local, and emits `local.get` plus `throw_ref`. The admitted delegate verifies that its target label is active, omits only the obsolete inner legacy handler shell, and lowers the body in the outer try's active label context. `src/passes/flatten_wbtest.mbt` locks ancestry, unchanged target/depth immediates, HOT verification, modern EH output shape, and module validation.

Red-first whitebox results were `188/189` and `189/190`; final results are HOT lower `89/89`, whitebox flatten `190/190`, focused flatten `263/263`, IR `326/326`, passes `5,783/5,783`, and full `9,252/9,252`. `moon fmt` and `moon info` are green with 11 existing warnings. No `.mbti` or public flatten surface changed. Nonzero/non-direct rethrow, typed-catch rethrow composition, nested-catch ownership, non-direct/value-carrying/mixed delegate forms, used inner labels, and broader nested populations remain unsupported.

## Latest multiple and nested-if rethrow lowering slice

Commits `3c819922c` and `41533e603` add no public API. `src/ir/hot_lower.mbt` captures one exception reference whenever a catch has any positive admitted rethrow count, rather than aborting above one, and recursively discovers rethrows through direct blocks plus `if` arms. At that checkpoint, `src/passes/flatten.mbt` admitted at most one resultless, untargeted if on a depth-zero rethrow ancestry path; direct-parent construction did not classify conditions as arm ancestry, and loops or nested try/catch regions remained outside discovery.

`src/passes/flatten_wbtest.mbt` added two red-first behavior fixtures. The multiple-rethrow fixture failed during lowering at `192/193`, then proved one `catch_all_ref` and two `throw_ref` uses from one captured local. The nested-if fixture failed admission at `193/194`, then preserved the rethrow immediate, verified HOT, lowered the if arm, and validated the module. Evidence reached HOT lower `89/89`, whitebox flatten `194/194`, focused flatten `263/263`, IR `326/326`, passes `5,787/5,787`, and full `9,256/9,256`. The older direct exceptional-transfer section remains chronology; its one-rethrow and block-only boundaries are superseded here.

## Latest strict rethrow/delegate ancestry slices

Commit `9c237165d` changes only `src/passes/flatten.mbt` and `src/passes/flatten_wbtest.mbt`. Admission no longer counts nested ifs; instead every direct-parent step independently proves a resultless if with no label users or a direct block until the exact catch root is reached. The new fixture interleaves two ifs with direct blocks, failed at `194/195`, then lowered through the existing recursive arm discovery and validated at `195/195`.

Commit `88197c97e` changes `src/passes/flatten.mbt`, `src/ir/hot_lower.mbt`, and `src/passes/flatten_wbtest.mbt`. Delegate admission now walks from the delegate through a strict catch-side block chain, requiring each block to be resultless, single-rooted, and untargeted before proving the exact delegated try. Lowering performs the same structural walk before transparent propagation. The two-block catch-chain fixture failed at `195/196`, then preserved the target, verified HOT, lowered, and validated at `196/196`.

Final evidence is HOT lower `89/89`, IR `326/326`, focused flatten `263/263`, whitebox flatten `196/196`, passes `5,789/5,789`, full `9,258/9,258`, `moon fmt`, and green `moon info` with 11 existing warnings. No `.mbti` changed. Public registry, dispatcher, CLI execution, compare/API, GenValid profile, preset, scheduler, and exact-neighborhood readiness remain absent.

## Latest structured control deletion slices

`src/ir/hot_mutate.mbt` now exposes `hot_delete_detached_forest(...)` plus validating control-only wrappers `hot_delete_detached_control_forest(...)` and `hot_delete_detached_control_subtree(...)`, alongside `hot_label_is_live(...)`. Generic forest deletion collects every complete descendant tree from ordinary or control roots, rejects empty or duplicate roots, overlap, sharing/cycles, roots or child references outside the set, external branch/delegate/try-table-catch users, labels owned by non-controls, and incomplete control-label ownership, then tombstones the complete node/label union with one revision bump. `src/ir/hot_mutate_test.mbt` locks mixed drop/block/unreachable success plus rejection without partial deletion when a later control has an external label user. The public IR snapshot adds only the generic mutation API; no public `flatten` API changed.

`src/passes/flatten.mbt` uses that mutation after unconditional legacy-try `br_table`. Structured roots remain the exact void `Block`, constant-condition complete-arm void `If`, and zero-input/no-backedge void `Loop` roster. Positive vectors may now mix those controls with any ordinary root already admitted by an exact dead-suffix recognizer, but every root must be recognized from immutable facts and the vector must contain both ordinary and structured roots. One suffix truncation precedes one generic atomic forest deletion; no scalar subset is tombstoned before a later control can fail.

The generic API red-first test failed on the unbound symbol, then passes HOT mutation `13/13` and IR `321/321`. The mixed `drop(const) + block + if + loop + unreachable` fixture failed unchanged at `262/263`, then passes `263/263`; private flatten is `186/186`, passes `5,779/5,779`, full `9,243/9,243`, and `moon info` is green with 11 existing warnings. Fresh pinned Binaryen v130 retains that ordered mixed suffix under direct flatten at `76` bytes; matched `--vacuum --dce` removes it at `63` bytes. Nonconstant/effectful conditions, partial or richer arms, inputful/value loops, loop-target users/backedges, try-like roots, sharing, and external label users remain pre-mutation fail-closed.

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
