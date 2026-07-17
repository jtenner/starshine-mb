# SimplifyLocals family transform inventory

## Scope

This is the source-first inventory for implementing and signing off every Binaryen `version_130` public `SimplifyLocals` variant in Starshine:

- `simplify-locals` = `<allowTee=true, allowStructure=true, allowNesting=true>`
- `simplify-locals-notee` = `<false, true, true>`
- `simplify-locals-nostructure` = `<true, false, true>`
- `simplify-locals-notee-nostructure` = `<false, false, true>`
- `simplify-locals-nonesting` = `<false, false, false>`

The primary implementation source is Binaryen `version_130` `src/passes/SimplifyLocals.cpp`. A fresh copy was downloaded on 2026-07-17 and is byte-identical to current upstream `main` at the time of this audit. Both files have SHA-256:

```text
33d45c1162a363151718f1e5d2de08234aa464590c0006699b71031ea6af2920
```

The dedicated `version_130` pass fixtures and the broader lit roster were also downloaded under `.tmp/binaryen-v130/simplify-locals/tests/` for this audit.

## Public variant truth table

| Variant | Tee creation | Structure synthesis | New ordinary nesting | Late equivalent-set removal policy |
| --- | --- | --- | --- | --- |
| `simplify-locals` | yes after the first cycle | yes | yes | remove equivalent sets and canonicalize gets |
| `simplify-locals-notee` | no | yes | yes | remove equivalent sets and canonicalize gets |
| `simplify-locals-nostructure` | yes after the first cycle | no | yes | canonicalize gets; do not directly remove equivalent sets in `EquivalentOptimizer` |
| `simplify-locals-notee-nostructure` | no | no | yes | canonicalize gets; do not directly remove equivalent sets in `EquivalentOptimizer` |
| `simplify-locals-nonesting` | no | no | no | canonicalize gets; do not directly remove equivalent sets in `EquivalentOptimizer` |

`nonesting` is not an alias for no-tee/no-structure. It has an additional parent-position check and only permits a non-copy sink when the consumer parent is another `local.set`.

## Complete source-owned rewrite-family inventory

The rows below are transform families, not merely opcode examples. Effect domains and bailout domains are listed separately afterward.

| ID | Binaryen transform family | Source owner | Variant gate | Current Starshine status at inventory start |
| --- | --- | --- | --- | --- |
| SL-01 | Count local reads before main cycles and again before late cleanup. | `LocalGetCounter`, `doWalkFunction`, `runLateOptimizations` | all | Implemented, but repeated whole-function counting remains a performance review point. |
| SL-02 | First-cycle single-use sinking: replace the first eligible `local.get` with the pending set value and nop the origin. | `optimizeLocalGet`, `canSink` | all; nonesting parent restriction applies | Implemented for active variants. |
| SL-03 | Later-cycle multi-use sinking through a newly created `local.tee`. | `optimizeLocalGet` | `allowTee` | Implemented for full and no-structure; must remain disabled for no-tee siblings. |
| SL-04 | Nonesting multi-use copy retarget: rewrite a get of the copied local to the source local without teeing or deleting the origin immediately. | `optimizeLocalGet` | `!allowNesting`, copy value, multi-use | Missing as a public policy mode. |
| SL-05 | Nonesting parent-position gate: permit real-value sinking only into another `local.set`; permit `local.get` copy sinking anywhere. | `optimizeLocalGet`, `expressionStack` | `!allowNesting` | Missing. Current policy engine has no `allow_nesting` axis. |
| SL-06 | Type-changing single-use replacement and later refinalization. | `optimizeLocalGet`, `refinalize`, `ReFinalize` | all | Substantial support exists; dedicated cross-variant proof still required. |
| SL-07 | Collapse `drop(local.tee ...)` to `local.set`. | `visitDrop` | all input variants | Implemented, including protected embedded-control handling. |
| SL-08 | Overwritten pending set: convert the earlier dead write to `drop(oldValue)` and retain effects/traps. | `visitPost` | all | Implemented for active variants. |
| SL-09 | Record a sinkable `local.set` only when it is non-tee, has no dangling EH pop, and obeys first-cycle/no-tee use-count policy. | `canSink`, `visitPost` | all | Implemented in active policy engine; dangling-pop coverage must be refreshed. |
| SL-10 | Directional invalidation of pending values by intervening expression effects. | `visitPre`, `visitPost`, `checkInvalidations` | all | Implemented with sparse exact local/global facts and effect counters. |
| SL-11 | At `try`/`try_table` entry, invalidate pending values that may throw so motion cannot change catch ownership. | `visitPre` | all | Implemented for active variants, including legacy/catch-region tests. |
| SL-12 | Preserve compatible pending values through ordinary linear execution and clear all pending facts on unsupported nonlinear control. | `LinearExecutionWalker`, `doNoteNonLinear`, if hooks | all | Implemented approximately in HOT region scans; active tests cover major boundaries. |
| SL-13 | Collect named-block break traces with per-exit sinkable snapshots. | `doNoteNonLinear`, `blockBreaks` | structure variants consume them | Starshine has its own branch-exit candidate machinery. |
| SL-14 | Poison block-result synthesis for value-carrying branches and unsupported target users (`switch`, `br_on_*`, etc.). | `doNoteNonLinear`, `unoptimizableBlocks` | structure variants | Broad negative coverage exists; needs explicit family matrix review. |
| SL-15 | Block-result synthesis when fallthrough and every eligible break set the same local. | `optimizeBlockReturn` | `allowStructure` | Implemented in full; must be enabled in no-tee and disabled in no-structure/nonesting. |
| SL-16 | Conditional-branch condition-order guard before moving a set into a `br_if` payload. | `optimizeBlockReturn` | structure variants | Covered by local source-backed helpers; dedicated no-tee contrast required. |
| SL-17 | Conditional break payload formation: make the branch-local set a tee, attach it as the branch value, finalize, and drop the now-value branch. | `optimizeBlockReturn` | structure variants, even `notee` | Critical semantic distinction: `allowTee=false` disables sink-created tees, but structure synthesis may still create this required branch tee. Starshine policy/tests must prove this. |
| SL-18 | If/else shared-local result synthesis. | `optimizeIfElseReturn` | `allowStructure` | Implemented in full; no-tee public mode missing. |
| SL-19 | If/else one-reachable-arm result synthesis when the opposite arm is unreachable. | `optimizeIfElseReturn` | `allowStructure` | Implemented in full. |
| SL-20 | One-armed-if speculative result synthesis with a synthesized else-side `local.get`. | `optimizeIfReturn` | `allowStructure` | Implemented in full. |
| SL-21 | Refuse one-armed-if synthesis for nondefaultable locals because fixups could add a trapping get. | `optimizeIfReturn` | structure variants | Implemented in full; no-tee proof required. |
| SL-22 | Narrow loop-result synthesis by moving one pending set value to a trailing result slot and wrapping the loop in the set. | `optimizeLoopReturn` | `allowStructure` | Implemented in full. |
| SL-23 | Enlargement/retry protocol for block, if-arm, and loop bodies that lack a trailing `nop` result slot. | `blocksToEnlarge`, `ifsToEnlarge`, `loopsToEnlarge`, `runMainOptimizations` | structure variants | Starshine uses direct region surgery rather than pointer-stability retries; semantic shapes exist. |
| SL-24 | Clear sinkables after rewrites or nonlinear joins and schedule another main cycle. | `anotherCycle`, structure helpers | all | Implemented with optimized deferred-cycle facts. |
| SL-25 | Track local equivalence classes from copy sets, resetting the destination class on writes. | `EquivalentOptimizer::visitLocalSet`, `EquivalentSets` | all | Implemented with explicit representative/member arrays. |
| SL-26 | Recognize fallthrough copy values through transparent wrappers. | `Properties::getFallthrough` | all | Starshine currently recognizes direct local-get values plus selected exact cleanup paths; broad wrapper parity needs fuzz pressure. |
| SL-27 | Remove an already-equivalent tee by replacing it with its value, refinalizing if the type changes. | `EquivalentOptimizer::visitLocalSet` | `allowStructure` via `removeEquivalentSets` | Needs explicit active/full and future no-tee family tests. |
| SL-28 | Remove an already-equivalent plain set by replacing it with `drop(value)`. | `EquivalentOptimizer::visitLocalSet` | `allowStructure` via `removeEquivalentSets` | Needs explicit active/full and future no-tee family tests. |
| SL-29 | Preserve equivalent sets in no-structure/nonesting modes while still using them to form equivalence classes. | `removeEquivalentSets = allowStructure` | no-structure/nonesting | Must be encoded explicitly in the policy object; current Starshine cleanup reaches similar shapes through later dead cleanup but does not model this axis directly. |
| SL-30 | Canonicalize equivalent gets to a more refined local type first, otherwise to the representative with more remaining uses. | `EquivalentOptimizer::visitLocalGet` | all | Implemented with subtype and get-count facts. |
| SL-31 | Connect adjacent dominated block fragments during late equivalent cleanup. | `connectAdjacentBlocks = true` | all | Starshine has adjacent-block coverage but uses HOT region semantics; needs cross-variant proof. |
| SL-32 | Run final dead-set cleanup after equivalent cleanup: dead tee -> value, dead effectful set -> drop, dead pure set -> nop. | `UnneededSetRemover` | all | Implemented with HOT and exact-writeback cleanup. |
| SL-33 | If late cleanup changed the function, run one main pass and continue only if main work was enabled; do not loop late canonicalization alone because it may not converge. | `doWalkFunction` late-cycle rule | all | Current Starshine fixpoint differs and uses candidate thresholds. This is an explicit parity/performance audit item. |
| SL-34 | Run `ReFinalize` when local replacement or equivalent-get refinement changes types. | `refinalize`, nested `EquivalentOptimizer::refinalize` | all | Implemented partly in HOT/lowered repair paths; fuzz profiles must stress it. |
| SL-35 | Pass-runner nondefaultable-local fixups after the pass. | `PassRunner::handleAfterEffects`, `TypeUpdating::handleNonDefaultableLocals` | all | Starshine has its own validation/writeback repairs; cross-variant nondefaultable signoff required. |

## Effect and legality domains that must be represented in TDD and generation

These are not separate transformations, but every transform above is conditioned by them.

| Domain | Required positive/negative surfaces |
| --- | --- |
| Local state | same-local reads/writes block motion; unrelated local traffic may commute; captured source-local writes block moving a value that reads that local. |
| Globals | immutable reads can cross calls; mutable reads cannot without effect summaries; distinct-global writes may commute where exact facts prove it. |
| Calls | direct, imported, indirect, and ref calls are barriers unless effect metadata proves otherwise; call-valued overwritten sets preserve calls as drops. |
| Memory | read/read trap commuting where allowed; writes block reads; bulk memory effects; shared-memory ordering. |
| Tables | `table.get` across inert code; table writes/init remain barriers. |
| GC heaps | mutable versus immutable field/array effects; shared versus unshared heap atomicity. |
| Strings | array-read-like construction versus array-write-like encoding effects. |
| Atomics | sharedness and acquire/release ordering; TNH does not erase synchronization semantics. |
| Traps/TNH | trapping values may commute only under exact directional rules and pass options; stores/global effects must not move before a real trap. |
| EH | may-throw values stay outside `try`/`try_table`; dangling pops never move; catch body/list facts do not leak across paths. |
| Structured branches | value branches, `br_if` evaluation order, `br_table`, `br_on_*`, rethrow/delegate, and typed payloads must preserve target/result semantics. |
| Types | subtype-refined local gets, nondefaultable locals, typed control results, tuples/multivalue, exact refs, and refinalization/writeback validation. |

## Current Starshine implementation gaps exposed by this inventory

1. **Missing active public variants:** `simplify-locals-notee` and `simplify-locals-nonesting` are not executable. Local descriptive aliases remain in the removed registry.
2. **Missing policy axis:** `simplify_locals_run_with_options` accepts `allow_structure_rewrites` and `allow_tee`, but not `allow_nesting`.
3. **Structure-created tee distinction:** no-tee mode must still permit the branch tee required by structured `br_if` result synthesis. The policy must forbid only sink-created tees.
4. **Late-equivalent policy is implicit:** Binaryen's `removeEquivalentSets = allowStructure` needs a direct Starshine option and tests, not accidental convergence through dead cleanup.
5. **Late-cycle schedule differs:** Starshine skips equivalent cleanup for large/sparse functions and uses a different fixpoint. Those are performance gates, not source-backed semantic exclusions; dedicated profiles must force candidate-rich large and sparse cases.
6. **Raw skip surface remains broad:** the many `run_hot_pipeline_raw_simplify_locals_should_skip_*` gates are not Binaryen transform-family boundaries. Modern closeout must either remove them from correctness dependence or prove each retained gate as a narrow performance-only no-op boundary.
7. **Pass-specific generation is incomplete:** only `simplify-locals-nostructure-all` exists. Full, no-tee, no-tee/no-structure, and nonesting require stable aggregate profiles with family metadata.

## Implementation order

1. Add one explicit `SimplifyLocalsPolicy` carrying `allow_tee`, `allow_structure`, and `allow_nesting`, plus the late equivalent-set-removal rule derived from `allow_structure`.
2. Activate `simplify-locals-notee` with canonical and compatibility names, preserving structure and prohibiting sink-created tees.
3. Activate `simplify-locals-nonesting` with the parent-position/copy-retarget rules and all tee/structure/nesting negatives.
4. Requalify existing full, no-structure, and no-tee/no-structure variants against this same family table.
5. Add family-targeted GenValid leaves and one aggregate per public variant, then fuzz each variant independently.
6. Fix residuals by source family, not by case id or artifact identity.
7. Run the required four-lane closeout matrix for all five canonical names, then ordered O4z neighborhood and nested-rerun proof for `simplify-locals-notee-nostructure`.

## Source URLs

- <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/SimplifyLocals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/linear-execution.h>
- <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/equivalent_sets.h>
- <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/local-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_130/src/pass.h>
- <https://github.com/WebAssembly/binaryen/tree/version_130/test/passes>
- <https://github.com/WebAssembly/binaryen/tree/version_130/test/lit/passes>
