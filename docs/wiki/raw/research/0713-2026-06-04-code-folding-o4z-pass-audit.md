---
kind: research
status: working
last_reviewed: 2026-06-05
sources:
  - ../../binaryen/passes/code-folding/index.md
  - ../../binaryen/passes/code-folding/binaryen-strategy.md
  - ../../binaryen/passes/code-folding/implementation-structure-and-tests.md
  - ../../binaryen/passes/code-folding/starshine-strategy.md
  - ../../binaryen/passes/code-folding/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/code-folding/terminating-tails.md
  - ../../binaryen/passes/code-folding/wat-shapes.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../../../src/passes/code_folding.mbt
  - ../../../../src/passes/code_folding_test.mbt
  - ../../../../src/ir/hot_lift.mbt
  - ../../../../src/ir/hot_lower.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/cli/cli_test.mbt
  - ../../../../agent-todo.md
---

# Code-Folding O4z Pass Audit

## Scope

Started the active v0.1.0 slice `[O4Z-AUDIT-CF]` for `code-folding`, the next O4z per-pass audit after the completed `[O4Z-AUDIT-LCSE]` entry in `agent-todo.md`. This pass sits in the late no-DWARF cleanup neighborhood immediately before `merge-blocks`, `remove-unused-brs`, `remove-unused-names`, the second `merge-blocks`, late peepholes, `heap-store-optimization`, `rse`, and final `vacuum`.

The audit checked owner/source wiring, focused coverage against the source-backed Binaryen shape catalog, and remaining work needed before this slice can be closed.

## Current implementation map

- `src/passes/code_folding.mbt` owns the active HOT descriptor and narrowed transform, now including the June typed block-exit payload-sharing slices through the first source-backed multi-value branch-plus-fallthrough case.
- `src/passes/code_folding_test.mbt` owns focused public-pipeline WAT coverage for current positives and safety bailouts.
- `src/passes/optimize.mbt` registers `code-folding` as an active hot pass.
- `src/passes/pass_manager.mbt` includes `code-folding` in the default function pipeline and dispatches requests to `code_folding_run(ctx, func)`.
- `src/cli/cli_test.mbt` preserves `--code-folding` pass-token parsing and explicit pass ordering.

## Source-backed shape checklist

Binaryen's documented `code-folding` contract still has two distinct families:

1. expression-exit folding for named block exits and foldable `if` arms;
2. function-ending terminating-tail folding for `return`, `return_call*`, and `unreachable` paths through helper-label sharing.

Starshine currently implements a deliberately narrower expression-exit and cleanup subset. The current source/test review found these in-tree covered families:

- void and value `if` arm suffix hoisting;
- worthwhile full-arm `if` collapse;
- unprofitable tiny full-void `if` bailout;
- structured suffix hoisting through unused labels;
- outer-branch full-tail hoisting;
- block-exit tail sharing with fallthrough;
- nested branch-payload helper-wrapper sharing;
- conservative full-`if` terminal suffix sharing for empty-payload `return` endings;
- exiting dead-value block flattening;
- trailing unreachable cleanup when the result context does not still require bottom.

This audit started the missing-shape coverage by adding focused tests for:

- full `if` arms ending in `unreachable`, ensuring terminal suffix sharing is not return-only;
- unsupported `br_on_null` label poisoning for block-exit folding;
- live-label structured `if` suffixes, ensuring branch-target-bearing wrappers are not hoisted out from under their labels.

The continuation pass then widened the implementation and tests for a source-backed branch-value expression-exit slice:

- typed named-block exits with one carried branch payload can now share that payload with a matching fallthrough value;
- typed named-block exits with two or more matching carried branch payloads can share one value even when the block has no normal fallthrough;
- the rewrite demotes the target block's result to void, strips the selected plain-`br` payloads, and inserts one shared payload immediately after the block;
- the slice remains deliberately single-result, plain-`br` only, and reuses the existing suffix equality, unsupported-branch poisoning, and branch-target survival checks.

The follow-up `[O4Z-AUDIT-CF-B]` / `[O4Z-AUDIT-CF-C]` / `[O4Z-AUDIT-CF-D]` work then made the named-block candidate model explicit and widened that same typed named-block family from a single payload root to a single-result multi-root suffix:

- `CodeFoldingValueExitTail` now records owning region provenance, tail end/root pointer, target label, branch payload root list, result arity, movement-proof state, selected suffix length, and profitability score before rewriting;
- branch-backed and fallthrough tails are compared backward over a logical tail where a plain-`br` payload is the final value root and preceding region roots can be shared when they are void, equal, hoistable, and fallthrough-preserving;
- the rewrite now strips the matching region roots before each selected branch, strips each branch payload, removes matching fallthrough roots, demotes the target block to void, and inserts the shared suffix after the block;
- focused tests cover both branch-plus-fallthrough and duplicate branch-only multi-root single-result suffixes using a shared effectful `call $sink` root before the final `i32.const` result; the next source-backed increment covers a branch-plus-fallthrough multi-value payload suffix with shared `call $sink`, `i32.const`, and `f32.const` roots.

## Source-backed Binaryen shape matrix

This table is backed by Binaryen `version_129` `src/passes/CodeFolding.cpp` and `test/lit/passes/code-folding.wast` plus the current Starshine owner/tests. It maps upstream behavior families to local coverage, gaps, and the next slice that should own any remaining work.

| Binaryen shape family | Binaryen behavior | Current Starshine status | Local tests / evidence | Gap | Next slice |
| --- | --- | --- | --- | --- | --- |
| Named-block void exit tails | Collects unconditional end-of-block `br $label` tails and possible fallthrough for a named block; moves an equal void suffix after the block when safe. | Covered for conservative void suffixes and fallthrough sharing. | `code-folding hoists block-exit tail shared with fallthrough`; `code-folding hoists block-exit tail before outer branch fallthrough`. | Helper-block profitability and broader nested cases remain narrower than Binaryen. | `[O4Z-AUDIT-CF-J]` for fixpoint/helper cleanup if needed. |
| Named-block typed branch payload tails | Treats plain-`br` payloads as mergeable tail items while preserving the branch shell; can share deeper suffix roots before the payload. | Covered for single-result plain-`br` payload roots, single-result multi-root suffixes, one source-backed branch-plus-fallthrough multi-value payload suffix, and one branch-only multi-value payload suffix with an unreachable fallback. | `code-folding hoists typed block-exit branch payload shared with fallthrough`; `... branch payloads without fallthrough`; multi-root fallthrough and branch-only tests; `code-folding hoists multi-value block-exit payload suffix with fallthrough`. | Non-plain branch participation, broader multi-value variants with live terminal fallbacks, and helper/profitability search remain unimplemented. | `[O4Z-AUDIT-CF-K]` for 10000-case closeout; future multi-value breadth only with HOT/lower proof. |
| Branch-plus-fallthrough tails | Adds the block's normal fallthrough as a tail when the end is reachable, so explicit exits and fallthrough can share a suffix. | Covered for void suffixes, single payload roots, single-result multi-root payload suffixes, and one multi-value payload suffix. | Void fallthrough test plus typed fallthrough, multi-root fallthrough, and multi-value fallthrough tests. | More complex helper/profitability shapes stay narrower. | `[O4Z-AUDIT-CF-J]` / `[O4Z-AUDIT-CF-K]`. |
| `if` unnamed block / unnamed block suffixes | Folds identical suffixes from unnamed `if` arms, including full-arm collapse to `drop(condition)` when profitable. | Covered for current void and value block suffix cases, including the exact partial non-block value-arm lit/doc shape where only the `f32.const 0` suffix is shared and source-backed two-unnamed-block value-arm shapes with unique prefixes sharing the final value suffix, now including a multi-root `call $sink` / `f32.const` suffix. Simple full-value non-block arms now remain a no-op for this pass. | `code-folding hoists identical if-arm suffixes`; `... full value if arms`; `code-folding keeps simple full value if arms for optimize-instructions`; `... partial value if suffixes`; `code-folding hoists exact partial non-block value if suffix`; `code-folding hoists two-block value if suffixes`; `code-folding hoists two-block multi-root value if suffixes`; `... structured suffixes`; profitability negative. | Does not yet model every Binaryen unnamed-block arm wrapper shape; local HOT/lower elides `nop`, so the exact partial non-block fixture asserts suffix sharing rather than final `nop` text, and broader named/unreachable-condition caveats remain open. | `[O4Z-AUDIT-CF-E]`. |
| One-block / one-non-block `if` wrapping | Binaryen can wrap one non-block arm in a synthetic unnamed block when it exactly matches the block arm's suffix. | Covered for the safe value-result shape in both then-block and else-block orientations, plus source-backed then-block and else-block multi-root `call $sink` / `f32.const` value suffixes. | `code-folding hoists one-block then-arm value suffix`; `code-folding hoists one-block else-arm value suffix`; `code-folding hoists one-block multi-root value suffix`; `code-folding hoists one-block else-arm multi-root value suffix`. | Exact named-unused arm and unreachable-condition local fixture coverage remain caveated by HOT/name and local WAT validation surfaces; both multi-root orientations are now source-backed locally. | `[O4Z-AUDIT-CF-E]` follow-up only for those caveats. |
| Named-arm negatives | Named `if` arm blocks are not folded because their labels may be branch targets. | Covered for live-label structured suffix bailout, including a crossed inner-vs-outer branch target guard. | `code-folding keeps live-label structured if suffixes`; `code-folding keeps crossed live-label structured if suffixes`. | Exact named-unused arm text parity remains caveated by local name preservation; keep live branch-target guards green. | `[O4Z-AUDIT-CF-E]` / `[O4Z-AUDIT-CF-H]`. |
| Full-arm terminal `return` / `unreachable` subset | Binaryen's terminating-tail family handles general function endings; local expression-exit subset can safely share full `if` arms ending in empty-payload terminal roots. | Covered for conservative full-`if` terminal `return`/`unreachable` arms, the first helper-label-like no-else `if`/fallthrough terminal-tail shape, and a root-anchored function-ending helper-label subset. | `code-folding shares full if arms ending in return`; `... ending in unreachable`; `... shares if-then and fallthrough return tails`; `... unreachable tails`; `... non-adjacent return tails`; `... block-backed unreachable tails`. | Arbitrary non-root subsets and branch/control-bearing moved suffixes remain absent. | `[O4Z-AUDIT-CF-F]` and `[O4Z-AUDIT-CF-H/J]`. |
| General terminating `return` tails | Searches subsets of function-ending `return` tails, prefers deeper suffixes, rewrites old tails to a fresh helper label, and appends one shared suffix at function end. | Partially covered for adjacent no-else `if`/fallthrough tails, root-anchored non-adjacent `return` suffixes, and non-root `return` subsets; when the original root body can fall through, Starshine now wraps it with a skip label so ordinary fallthrough does not execute the shared terminal suffix, and it can exclude a different root `return` from the selected subset. The terminating-tail mover now accepts label-unused structured block/if/loop suffix roots through the same hoistability check used by expression-exit folding, plus narrow alpha-equivalent self-branching block cases whose internal branch targets remain inside the moved suffix; the equality helper now carries a multi-label alpha map for the nested internal-label subset, guarded by a crossed nested-label return negative that keeps inner-vs-outer branch targets distinct. | `code-folding shares if-then and fallthrough return tails`; `code-folding shares non-adjacent return tails`; `code-folding shares non-root return tail subsets`; `code-folding shares non-root return subsets excluding a different root return`; `code-folding folds deeper non-root return subset then shallow fixpoint`; `code-folding shares non-root structured block return suffixes`; `code-folding shares non-root structured if return suffixes`; `code-folding shares non-root structured loop return suffixes`; `code-folding shares non-root self-branch block return suffixes`; `code-folding shares non-root nested self-branch block return suffixes`; `code-folding shares non-root return tail subsets with root fallthrough`. | Needs broader movement safety, exact helper-block cost modeling, and additional arbitrary-subset/tail-call/unreachable coverage. | `[O4Z-AUDIT-CF-F]` / `[O4Z-AUDIT-CF-J]`. |
| Terminating `return_call`, `return_call_indirect`, `return_call_ref` | Records tail-call terminators through the same terminating-tail helper path. | Partially covered for root-anchored direct, indirect, and ref tail-call suffixes, including typed-result direct `return_call`, logical call-signature comparison for indirect/ref nodes, non-root direct/indirect/ref tail-call subsets with root fallthrough, direct `return_call` coverage for the narrow and nested self-branching block suffix cases plus a crossed nested-label negative, `return_call_indirect` and non-null `return_call_ref` coverage for the nested internal-label self-branching suffix case, and a crossed nested-label `return_call_indirect` negative. Tail-call-only operand suffixes are now treated as Binaryen-unprofitable instead of being shared alone. | `code-folding shares direct return-call tails with typed results`; `code-folding shares non-root direct return-call tail subsets with root fallthrough`; `code-folding shares non-root self-branch block return-call suffixes`; `code-folding shares non-root nested self-branch return-call suffixes`; `code-folding keeps crossed nested self-branch return-call suffixes`; `code-folding shares return-call-indirect tails`; `code-folding shares non-root return-call-indirect tail subsets with root fallthrough`; `code-folding shares non-root nested self-branch return-call-indirect suffixes`; `code-folding keeps crossed nested self-branch return-call-indirect suffixes`; `code-folding shares return-call-ref tails`; `code-folding shares non-root return-call-ref tail subsets with root fallthrough`; `code-folding shares non-root nested self-branch return-call-ref suffixes`. | Needs broader arbitrary-subset coverage, broader movement-safety negatives, and more natural non-null `return_call_ref` fixtures once local syntax/HOT support is cleaner. | `[O4Z-AUDIT-CF-G]` / `[O4Z-AUDIT-CF-H/J]`. |
| Terminating `unreachable` tails | Runs terminating-tail folding for `unreachable` groups before return groups. | Partially covered for adjacent no-else `if`/fallthrough tails, root-anchored block-backed `unreachable` suffixes, a non-root `unreachable` subset with root fallthrough, and the same narrow self-branching plus nested internal-label self-branching block suffix cases as return tails, with a crossed nested-label negative for the `unreachable` family. | `code-folding shares full if arms ending in unreachable`; `code-folding shares if-then and fallthrough unreachable tails`; `code-folding shares block-backed unreachable tails`; `code-folding shares non-root unreachable tail subsets with root fallthrough`; `code-folding shares non-root self-branch block unreachable suffixes`; `code-folding shares non-root nested self-branch block unreachable suffixes`; `code-folding keeps crossed nested self-branch unreachable suffixes`; unreachable cleanup tests. | Needs broader arbitrary-subset/deeper-suffix coverage and branch/control-bearing movement proof. | `[O4Z-AUDIT-CF-F]` / `[O4Z-AUDIT-CF-H/J]`. |
| Unsupported branch poisoning (`br_on_*`, `br_if`, `br_table`, `delegate`) | Unsupported branch forms targeting a label mark that label unoptimizable for label folding; `br_table` / switch targets are treated conservatively. | Poison behavior preserved for local named-block folds, including focused `br_if` and `br_table` negatives. | Core-built `code-folding keeps br-on-null-poisoned block-exit suffixes`; `code-folding keeps br-if-poisoned block-exit payload suffixes`; `code-folding keeps br-table-poisoned block-exit suffixes`; collector rejects `br_if`, `br_on_*`, `br_table`, and `delegate` target traffic. | More official poison fixtures could be added for each unsupported family. | `[O4Z-AUDIT-CF-H]`. |
| Outside-target movement bailout | `canMove` rejects equal-looking suffixes if moving them would strand a branch target whose owner is inside the moved-out region. | Covered in simplified form through label-use and target-survival checks, with a reduced outside-target switch-like return-tail negative, narrow `return`, `unreachable`, `return_call`, `return_call_indirect`, and `return_call_ref` positives where nested branch targets remain inside the moved suffix, and crossed nested-label negatives through direct and indirect tail calls where an inner-label branch must not alpha-match an outer-label branch. | `code-folding keeps live-label structured if suffixes`; `code-folding keeps outside-target switch-like return tails`; `code-folding shares non-root nested self-branch block return suffixes`; `code-folding shares non-root nested self-branch block unreachable suffixes`; `code-folding shares non-root nested self-branch return-call-indirect suffixes`; `code-folding shares non-root nested self-branch return-call-ref suffixes`; `code-folding keeps crossed nested self-branch return suffixes`; `code-folding keeps crossed nested self-branch return-call suffixes`; `code-folding keeps crossed nested self-branch unreachable suffixes`; `code-folding keeps crossed nested self-branch return-call-indirect suffixes`; branch-target survival helper and label-map equality in `code_folding.mbt`. | Full branch/control-bearing terminating-tail movement is still rejected instead of repaired/moved. | `[O4Z-AUDIT-CF-H]`. |
| Equal-looking unsafe switch / `br_table` cases | Binaryen rejects switch/table cases where equality is insufficient because branch targets would not remain valid. | Conservative local collector poisons `br_table` target traffic; no positive switch folding. | `code-folding keeps careful switch target scopes`. | Positive switch folding remains out of scope; keep this negative before any broadening. | `[O4Z-AUDIT-CF-H]`. |
| EH-sensitive movement / bailout / repair | `canMove` rejects dangling `pop` and throwing-through-`try` hazards; block-adding rewrites can run EH nested-pop repair. | Local code now descends into `try` / `try_table` bodies only for non-terminal `if` arm suffix folding, while still treating EH controls as hard boundaries for block-exit and terminating-tail movement and keeping no repair path. A 2026-06-04 `wasm-opt version_129 --enable-exception-handling --code-folding -S` check showed an explicit outer-`catch_all` `try_table` terminal-tail shape stays unfolded in Binaryen, matching the local bailout; 2026-06-05 `catch_ref` / `catch_all_ref` terminal-tail probes also stay unfolded. Separate checked `catch_all`, explicit `catch $e`, nested `try_table`, and now dropped outer `catch_ref` / `catch_all_ref` throwing-body shapes fold duplicate non-terminal `if` arm suffixes in both Binaryen and Starshine; exact text-level plain `try` coverage remains blocked because local WAT lowering erases that surface before final pretty output. | Collector returns false on `Try` / `TryTable` for block-exit and terminating-tail families; `code-folding folds non-terminal try-table if-arm body suffixes`; `code-folding folds catch try-table if-arm body suffixes`; `code-folding folds catch-ref try-table throwing-body if-arm suffixes`; `code-folding folds catch-all-ref try-table throwing-body if-arm suffixes`; `code-folding folds nested try-table if-arm body suffixes`; `code-folding keeps outer-catch try-table terminal tails as EH bailout`; `code-folding keeps catch-ref try-table terminal tails as EH bailout`; `code-folding keeps catch-all-ref try-table terminal tails as EH bailout`; `code-folding keeps try-table terminal tails as EH bailout`; `code-folding keeps try-table block-exit suffixes as EH bailout`. | EH movement/repair, throwing-through-try hazards, nested-pop repair, exact plain-`try` text-surface coverage, and broader EH shapes remain unimplemented or unclassified. | `[O4Z-AUDIT-CF-I]`. |
| Helper block / profitability / fixpoint | Uses a measured profitability heuristic, can add helper blocks, and repeats until no new fold is exposed. | Local expression-exit folds use a simplified suffix measure and direct after-block insertion; function-ending helper labels now use a node-count profitability threshold and the pass reruns its local visit/terminating-tail sequence to fixpoint. | Current tests cover unprofitable tiny full-void `if` bailout; named-block and terminating-tail plans carry suffix length and profitability score; `code-folding reaches a root-anchored terminating-tail fixpoint`; `code-folding folds deeper non-root return subset then shallow fixpoint`; `code-folding late branch-cleanup neighborhood keeps shared return tail valid`; `code-folding late branch-cleanup neighborhood keeps non-root return subset valid`. | Needs exact Binaryen helper cost modeling and generated late-slot proof. | `[O4Z-AUDIT-CF-J]` plus `[O4Z-AUDIT-CF-F/G]`. |

## Remaining direct completeness gaps

These are not new regressions; they are the known difference between Starshine's accepted narrow direct pass and Binaryen's broader `CodeFolding.cpp` surface.

- Function-ending helper-label sharing now covers a root-anchored subset for `return`, `return_call`, `return_call_indirect`, `return_call_ref`, and `unreachable`, and the local pass now reruns that root-anchored subset to fixpoint. It is still narrower than Binaryen's general algorithm: arbitrary non-root subsets, branch/control-bearing moved suffixes, exact helper cost modeling, and EH repair remain unimplemented.
- Branch-value folding for typed named-block exits now covers plain-`br` payload sharing with matching fallthrough or multiple branch payloads, including safe single-result multi-root suffixes and one source-backed multi-value branch-plus-fallthrough suffix. It remains narrower than Binaryen's full branch-payload suffix model: broader multi-value payload variants, `br_if` / `br_table` / `br_on_*` participation, full helper-block profitability/subset search, and broad EH-aware movement remain open.
- EH-sensitive movement remains mostly a hard bailout: the pass now descends into `try` / `try_table` bodies only to run ordinary non-terminal `if` arm suffix folding, including the dropped outer `catch_ref` / `catch_all_ref` throwing-body shapes where the try-table is embedded as the value of a `drop`. It still does not collect block exits or terminating tails across EH boundaries and has no local nested-pop repair equivalent. The 2026-06-04 outer-`catch_all` and 2026-06-05 `catch_ref` / `catch_all_ref` `try_table` terminal-tail checks match Binaryen's bailouts, and the separate non-terminal `catch_all`, explicit-`catch`, `catch_ref`, and `catch_all_ref` `try_table` if-arm probes now have matching local coverage.
- Broader helper-block creation and profitability modeling remain conditional future work rather than a v0.1.0 direct blocker unless a semantic, validity, or proven downstream code-size issue appears.
- The exact late O4z slot/neighborhood still needs refreshed generated evidence before the audit slice can close.

## Validation status

The continuation completed baseline slice `[O4Z-AUDIT-CF-A]` for the current widened implementation.

Commands and results:

```sh
moon info
# Finished. moon: ran 6 tasks, now up to date

moon fmt
# Finished. moon: ran 2 tasks, now up to date

moon test src/passes
# Total tests: 1590, passed: 1590, failed: 0

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in pass_manager.mbt and 0 errors
# Native binary path in this workspace: _build/native/release/build/cmd/cmd.exe

bun scripts/pass-fuzz-compare.ts \
  --pass code-folding \
  --count 1000 \
  --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-code-folding-audit-1000 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
# Compared cases: 998/1000
# Normalized matches: 998
# Compare-normalized matches: 0
# Validation failures: 0
# Property failures: 0
# Generator failures: 0
# Command failures: 2 (command-class.binaryen-rec-group-zero)
# Mismatches: 0

bun scripts/self-optimize-compare.ts \
  tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/code-folding-audit-self-compare \
  --timing-only \
  --code-folding
# Starshine runtime (ms): 1184.332
# Binaryen runtime (ms): 586.258
# Starshine pass runtime (ms): 172.276
# Starshine pass skipped raw: no
# Binaryen pass runtime (ms): 169.576
```

The pass-local timing is within the repo floor (`172.276ms <= 2 * 169.576ms`). The compare smoke had zero mismatches; the two command failures are `command-class.binaryen-rec-group-zero`, classified as tool/Binaryen command failures rather than Starshine semantic mismatches.

Additional commit-ready validation for `[O4Z-AUDIT-CF-A]`:

```sh
moon test
# Total tests: 4775, passed: 4775, failed: 0
```

Follow-up `[O4Z-AUDIT-CF-B]` / `[O4Z-AUDIT-CF-C]` / `[O4Z-AUDIT-CF-D]` validation after the source matrix, explicit named-block candidate model, and single-result multi-root named-block suffix widening:

```sh
moon test src/passes
# First test-first run failed the two new multi-root named-block tests.
# After implementation: Total tests: 1592, passed: 1592, failed: 0

moon fmt
# Finished. moon: ran 2 tasks, now up to date

moon test
# Total tests: 4777, passed: 4777, failed: 0

moon info
# Finished. moon: ran 6 tasks, now up to date

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in pass_manager.mbt and 0 errors
# Native binary path in this workspace: _build/native/release/build/cmd/cmd.exe

bun scripts/pass-fuzz-compare.ts \
  --pass code-folding \
  --count 1000 \
  --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-code-folding-bd-1000 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
# Compared cases: 998/1000
# Normalized matches: 998
# Compare-normalized matches: 0
# Validation failures: 0
# Property failures: 0
# Generator failures: 0
# Command failures: 2 (command-class.binaryen-rec-group-zero)
# Mismatches: 0

bun scripts/self-optimize-compare.ts \
  tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/code-folding-bd-self-compare \
  --timing-only \
  --code-folding
# Starshine runtime (ms): 1260.633
# Binaryen runtime (ms): 630.984
# Starshine pass runtime (ms): 196.213
# Starshine pass skipped raw: no
# Binaryen pass runtime (ms): 187.281
```

The follow-up pass-local timing remains inside the repo floor (`196.213ms <= 2 * 187.281ms`). The direct compare smoke had zero mismatches; the two command failures are again `command-class.binaryen-rec-group-zero`, classified as tool/Binaryen command failures rather than Starshine semantic mismatches.

Follow-up `[O4Z-AUDIT-CF-E]` progress after the one-block/one-non-block `if` arm widening:

```sh
moon test src/passes
# First test-first run failed the two new one-block/one-non-block tests.
# After implementation: Total tests: 1594, passed: 1594, failed: 0

moon fmt
# Finished. moon: no work to do after docs refresh

moon test
# Total tests: 4779, passed: 4779, failed: 0

moon info
# Finished. moon: ran 6 tasks, now up to date

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in pass_manager.mbt and 0 errors
# Native binary path in this workspace: _build/native/release/build/cmd/cmd.exe

bun scripts/pass-fuzz-compare.ts \
  --pass code-folding \
  --count 1000 \
  --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-code-folding-e-1000 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
# Compared cases: 998/1000
# Normalized matches: 998
# Compare-normalized matches: 0
# Validation failures: 0
# Property failures: 0
# Generator failures: 0
# Command failures: 2 (command-class.binaryen-rec-group-zero)
# Mismatches: 0

bun scripts/self-optimize-compare.ts \
  tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/code-folding-e-self-compare \
  --timing-only \
  --code-folding
# Starshine runtime (ms): 1283.800
# Binaryen runtime (ms): 644.081
# Starshine pass runtime (ms): 208.362
# Starshine pass skipped raw: no
# Binaryen pass runtime (ms): 185.945
```

The `[O4Z-AUDIT-CF-E]` pass-local timing remains inside the repo floor (`208.362ms <= 2 * 185.945ms`). The direct compare smoke had zero mismatches; the two command failures are again `command-class.binaryen-rec-group-zero`, classified as tool/Binaryen command failures rather than Starshine semantic mismatches.

Follow-up `[O4Z-AUDIT-CF-F]` progress after the first no-else `if` then-tail plus fallthrough terminal-tail helper-label-like widening:

```sh
moon test src/passes
# First test-first run failed the two new return/unreachable then-tail plus fallthrough tests.
# After implementation: Total tests: 1596, passed: 1596, failed: 0

moon fmt
# Finished. moon: ran 1 task, now up to date after docs refresh

moon test
# Total tests: 4781, passed: 4781, failed: 0

moon info
# Finished. moon: ran 6 tasks, now up to date

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in pass_manager.mbt and 0 errors
# Native binary path in this workspace: _build/native/release/build/cmd/cmd.exe

bun scripts/pass-fuzz-compare.ts \
  --pass code-folding \
  --count 1000 \
  --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-code-folding-f-1000 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
# Compared cases: 998/1000
# Normalized matches: 998
# Compare-normalized matches: 0
# Validation failures: 0
# Property failures: 0
# Generator failures: 0
# Command failures: 2 (command-class.binaryen-rec-group-zero)
# Mismatches: 0

bun scripts/self-optimize-compare.ts \
  tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/code-folding-f-self-compare \
  --timing-only \
  --code-folding
# Starshine runtime (ms): 1263.602
# Binaryen runtime (ms): 684.836
# Starshine pass runtime (ms): 187.189
# Starshine pass skipped raw: no
# Binaryen pass runtime (ms): 198.305
```

The `[O4Z-AUDIT-CF-F]` pass-local timing is faster than Binaryen on this artifact lane (`187.189ms <= 198.305ms`). The direct compare smoke had zero mismatches; the two command failures are again `command-class.binaryen-rec-group-zero`, classified as tool/Binaryen command failures rather than Starshine semantic mismatches.

Follow-up `[O4Z-AUDIT-CF-F]` / `[O4Z-AUDIT-CF-G]` progress after the root-anchored terminating-tail helper-label widening:

```sh
moon test src/passes
# Failing-first/implementation-loop runs exposed the new non-adjacent return, block-backed unreachable, direct return_call, return_call_indirect, and return_call_ref positives before the final implementation was complete.
# The attempted unreachable-condition `if` fixture still failed in the local HOT/lower pipeline and was removed as a documented fixture blocker.
# After implementation: Total tests: 1601, passed: 1601, failed: 0

moon fmt
# Finished. moon: ran 2 tasks, now up to date

moon info
# Finished. moon: ran 6 tasks, now up to date

moon test
# Total tests: 4786, passed: 4786, failed: 0

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in pass_manager.mbt and 0 errors
# Native binary path in this workspace: _build/native/release/build/cmd/cmd.exe

bun scripts/pass-fuzz-compare.ts \
  --pass code-folding \
  --count 1000 \
  --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-code-folding-fg-1000 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
# Compared cases: 998/1000
# Normalized matches: 998
# Compare-normalized matches: 0
# Validation failures: 0
# Property failures: 0
# Generator failures: 0
# Command failures: 2 (command-class.binaryen-rec-group-zero)
# Mismatches: 0

bun scripts/self-optimize-compare.ts \
  tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/code-folding-fg-self-compare \
  --timing-only \
  --code-folding
# Starshine runtime (ms): 1292.746
# Binaryen runtime (ms): 693.685
# Starshine pass runtime (ms): 210.383
# Starshine pass skipped raw: no
# Binaryen pass runtime (ms): 187.861
```

The new root-anchored terminating-tail helper-label slice remains inside the repo pass-local floor (`210.383ms <= 2 * 187.861ms`). The direct compare smoke had zero mismatches; the two command failures are again `command-class.binaryen-rec-group-zero`, classified as tool/Binaryen command failures rather than Starshine semantic mismatches. The new rewrite is deliberately narrower than Binaryen's full function-ending algorithm: it requires the selected group to include the root function-ending tail so normal fallthrough into the shared suffix remains semantically justified, rejects EH and branch/control-bearing moved suffix items, and still leaves arbitrary non-root subsets and broader movement-safety cases to `[O4Z-AUDIT-CF-H]` / `[O4Z-AUDIT-CF-I]` / `[O4Z-AUDIT-CF-J]`.

Follow-up `[O4Z-AUDIT-CF-H]` / `[O4Z-AUDIT-CF-I]` / `[O4Z-AUDIT-CF-J]` progress after the movement-safety, EH-bailout, and local fixpoint batch:

```sh
moon test src/passes
# First test-first run failed the new root-anchored terminating-tail fixpoint test and the new try_table terminal-tail EH bailout test.
# After implementation: Total tests: 1608, passed: 1608, failed: 0

moon fmt
# Finished. moon: ran 2 tasks, now up to date

moon info
# Finished. moon: ran 6 tasks, now up to date

moon test
# Total tests: 4793, passed: 4793, failed: 0

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in pass_manager.mbt and 0 errors
# Native binary path in this workspace: _build/native/release/build/cmd/cmd.exe

bun scripts/pass-fuzz-compare.ts \
  --pass code-folding \
  --count 1000 \
  --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-code-folding-hij-1000 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
# Compared cases: 998/1000
# Normalized matches: 998
# Compare-normalized matches: 0
# Validation failures: 0
# Property failures: 0
# Generator failures: 0
# Command failures: 2 (command-class.binaryen-rec-group-zero)
# Mismatches: 0

bun scripts/self-optimize-compare.ts \
  tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/code-folding-hij-self-compare \
  --timing-only \
  --code-folding
# Starshine runtime (ms): 1373.596
# Binaryen runtime (ms): 696.997
# Starshine pass runtime (ms): 231.629
# Starshine pass skipped raw: no
# Binaryen pass runtime (ms): 195.691
```

The batch remains inside the repo pass-local floor (`231.629ms <= 2 * 195.691ms`). The direct compare smoke had zero mismatches; the two command failures are again `command-class.binaryen-rec-group-zero`, classified as tool/Binaryen command failures rather than Starshine semantic mismatches. Focused tests now cover `br_table` poisoning, outside-target/switch-scope movement negatives, tested `try_table` terminal-tail and block-exit bailouts, a local root-anchored terminating-tail fixpoint, and a small `code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks` helper-label neighborhood. A larger debug-WASI timing-only replay of the full late-neighborhood flag sequence was attempted separately and failed during Starshine command validation, so it is not counted as generated late-slot evidence for closing `[O4Z-AUDIT-CF-J]`.

Additional EH classification on 2026-06-04 used `wasm-opt version_129 --enable-exception-handling --code-folding -S` on `.tmp/code-folding-try-table-outer-catch-terminal.wat`. Binaryen preserved the explicit outer-`catch_all` `try_table`, two `call $sink` roots, and two `return` roots, so the agent classification is a source-backed bailout match rather than an implementation gap for that exact terminal-tail shape. A separate probe on `.tmp/code-folding-try-table-if-arms.wat` showed Binaryen can fold a non-terminal duplicate `if` arm suffix inside a `try_table` body; Starshine now has a matching focused test and a narrow EH-body visitor for that non-terminal `if` family. This does not implement EH movement/repair or terminating-tail collection across EH boundaries.

Follow-up `[O4Z-AUDIT-CF-E]` two-unnamed-block value-arm increment on 2026-06-05 first checked `wasm-opt version_129 --all-features --code-folding -S` on `.tmp/cf-block-block.wat`; Binaryen preserved the `if`, folded the unique block prefixes to void arms, and emitted one shared `f32.const 0` after the `if`. The local test-first run failed `code-folding hoists two-block value if suffixes` before implementation (`1629/1630` passed); after the narrow unused-label block/block implementation, `moon fmt` completed and `moon test src/passes` passed `1630/1630`.

Follow-up `[O4Z-AUDIT-CF-E]` two-unnamed-block multi-root value-suffix coverage on 2026-06-05 checked `wasm-opt version_129 --all-features --code-folding -S` on `.tmp/code-folding-5-slices/slice1-two-block-multi-root.wat`; Binaryen keeps the `if` for distinct prefixes and emits one shared `call $sink` / `f32.const 0` suffix after it. The existing unused-label block/block implementation already matched this source-backed shape, so the local slice is coverage rather than new behavior; `moon fmt` completed and `moon test src/passes` passed `1633/1633`.

Follow-up `[O4Z-AUDIT-CF-E/H]` crossed live-label if-arm negative on 2026-06-05 checked `wasm-opt version_129 --all-features --code-folding -S` on `.tmp/code-folding-5-slices/slice2-crossed-if-label-negative.wat`; Binaryen preserves both structured arm suffixes because one branch targets an inner label while the other targets the outer label. The matching local test is guard coverage for label-scope movement safety, not a broad named-arm parity claim; `moon fmt` completed and `moon test src/passes` passed `1634/1634`.

Follow-up `[O4Z-AUDIT-CF-I]` explicit-`catch` `try_table` body classification on 2026-06-05 checked `wasm-opt version_129 --enable-exception-handling --code-folding -S` on `.tmp/code-folding-5-slices/slice3-try-table-catch-if.wat`; Binaryen folds the body-local duplicate `if` arms under `(catch $e 0)`, leaving one shared `call $sink` / `i32.const 7` suffix. The existing EH-body visitor is catch-kind agnostic for this non-terminal `if` family; this slice does not implement EH movement, terminating tails across EH, or nested-pop repair; `moon fmt` completed and `moon test src/passes` passed `1635/1635`.

Follow-up `[O4Z-AUDIT-CF-H/F]` crossed nested-label `unreachable` negative on 2026-06-05 checked `wasm-opt version_129 --all-features --code-folding -S` on `.tmp/code-folding-5-slices/slice4-crossed-unreachable-negative.wat`; Binaryen preserves both `unreachable` tails when one suffix branch targets the inner block and the other targets the outer block. The matching local guard extends the existing crossed-label `return` negative to the `unreachable` terminal family; `moon fmt` completed and `moon test src/passes` passed `1636/1636`.

Follow-up `[O4Z-AUDIT-CF-G/H]` nested self-branching `return_call_indirect` coverage on 2026-06-05 checked `wasm-opt version_129 --all-features --code-folding -S` on `.tmp/code-folding-5-slices/slice5-nested-return-call-indirect.wat`; Binaryen shares the nested internal-label block suffix and leaves one `return_call_indirect`. The matching local coverage extends the narrow alpha-map movement-positive family from direct `return_call` to indirect tail calls without changing the broader `br_table`, outside-target, live-label, or EH bailouts; `moon fmt` completed and `moon test src/passes` passed `1637/1637`.

Five-slice validation on 2026-06-05 stayed green after the coverage batch:

```sh
moon info
# Finished. moon: no work to do

moon test
# Total tests: 4822, passed: 4822, failed: 0.

moon build --target native --release src/cmd
# Finished. moon: no work to do

bun scripts/pass-fuzz-compare.ts --pass code-folding --count 1000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-code-folding-five-slices-2026-06-05-1000 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
# Compared cases: 998/1000
# Normalized matches: 998
# Mismatches: 0
# Command failures: 2
```

The two command failures are again `command-class.binaryen-rec-group-zero` in `summary.json`, classified as tool/Binaryen command failures rather than Starshine semantic mismatches. This is a 1000-case smoke, not the 10000-case parity closeout.

Follow-up `[O4Z-AUDIT-CF-I]` nested EH-body classification on 2026-06-05 first probed plain `try` with `wasm-opt version_129 --enable-exception-handling --code-folding -S`, where Binaryen folds the duplicate body-local `if` suffix, but the local text fixture does not preserve `try` after WAT lowering. The committed source-backed fallback uses `.tmp/cf-nested-try-table-if-arms.wat`; Binaryen keeps both `try_table` controls and emits one shared `call $sink` / `i32.const 7` suffix. The matching local coverage was already handled by the narrow EH-body visitor, so this is a classification/coverage slice rather than a new EH movement implementation; `moon test src/passes` passed `1631/1631`.

Follow-up `[O4Z-AUDIT-CF-H/F]` nested self-branching `unreachable` coverage on 2026-06-05 checked `.tmp/cf-nested-self-branch-unreachable.wat` with `wasm-opt version_129 --all-features --code-folding -S`; Binaryen shares the nested internal-label block suffix and leaves one terminal `unreachable`. The matching local test was already green under the existing multi-label alpha-map movement proof, so this is coverage for the `unreachable` terminal family rather than a broader branch/control-bearing movement implementation; `moon test src/passes` passed `1632/1632`.

Follow-up `[O4Z-AUDIT-CF-E]` one-block/one-non-block multi-root value-suffix coverage on 2026-06-05 checked `wasm-opt` version 129 (`version_129`) with `--all-features --code-folding -S` on `.tmp/code-folding-next5/slice1-one-block-nonblock-multiroot.wat`; Binaryen preserves the `if` with the unique block prefix and emits one shared `call $sink` / `f32.const 0` suffix after it. The existing one-block matcher already matched this source-backed shape, so the slice is coverage/classification rather than new implementation; `moon test src/passes` passed `1638/1638`.

Follow-up `[O4Z-AUDIT-CF-D/E]` multi-value named-block payload coverage on 2026-06-05 checked `wasm-opt` version 129 (`version_129`) with `--all-features --code-folding -S` on `.tmp/code-folding-next5/slice2-multivalue-block-payload.wat`; Binaryen demotes the `(result i32 f32)` block, preserves the branch shell, and emits one shared `call $sink` plus two-value payload suffix after the block. The local test failed first (`1638/1639` passed) while the value-exit path was single-result-only, then the implementation was widened to require the whole value tuple before demoting the block; `moon test src/passes` passed `1639/1639` after the fix.

Follow-up `[O4Z-AUDIT-CF-I]` `catch_all_ref` EH bailout coverage on 2026-06-05 checked `wasm-opt` version 129 (`version_129`) with `--all-features --enable-exception-handling --code-folding -S` on `.tmp/code-folding-next5/slice3-try-table-catch-all-ref-terminal.wat`; Binaryen preserves both terminal `return` tails under the `catch_all_ref` `try_table`. The matching local test keeps that bailout green (`moon test src/passes` passed `1640/1640`). A separate probe on `.tmp/code-folding-next5/slice3-try-table-catch-all-ref-if.wat` showed Binaryen folds a throwing-body `catch_all_ref` non-terminal `if` suffix; the local fixture did not fold, so that remains an explicit EH-body parity gap rather than a claimed catch-ref breadth match.

Follow-up `[O4Z-AUDIT-CF-G/H]` crossed nested-label `return_call_indirect` negative on 2026-06-05 checked `wasm-opt` version 129 (`version_129`) with `--all-features --code-folding -S` on `.tmp/code-folding-next5/slice4-crossed-return-call-indirect-negative.wat`; Binaryen preserves both crossed nested-label tail-call suffixes and both `return_call_indirect` roots. The local test failed first by sharing only the operand/`return_call_indirect` suffix despite the crossed blocks; the fix keeps tail-call operand-only suffixes unshared under the simplified helper-cost model while preserving nested internal-label positives. After the fix, `moon test src/passes` passed `1641/1641`.

Follow-up `[O4Z-AUDIT-CF-G/H]` nested self-branching `return_call_ref` coverage on 2026-06-05 checked `wasm-opt` version 129 (`version_129`) with `--all-features --code-folding -S` on `.tmp/code-folding-next5/slice5-nested-return-call-ref.wat`; Binaryen shares the nested internal-label block suffix and leaves one non-null `ref.func` / `return_call_ref` tail. The local text path currently rejects that fixture surface, so the matching local coverage is core-built with a declarative `ref.func`; it was already accepted by the existing alpha-map movement proof, and `moon test src/passes` passed `1642/1642`.

Follow-up `[O4Z-AUDIT-CF-D]` branch-only multi-value named-block payload coverage on 2026-06-05 checked `wasm-opt` version 129 (`version_129`) with `--all-features --code-folding -S` on `.tmp/code-folding-next5/slice6-multivalue-block-payload-branch-only.wat`; Binaryen demotes the `(result i32 f32)` block with only plain `br` payload exits plus an unreachable fallback, preserving the branch shells and emitting one shared `call $sink` plus two-value payload suffix after the block. The local implementation already matched this unreachable-fallback source-backed shape, and `moon test src/passes` passed `1643/1643`.

Follow-up `[O4Z-AUDIT-CF-E]` one-block/one-non-block else-arm multi-root value-suffix coverage on 2026-06-05 checked `wasm-opt` version 129 (`version_129`) with `--all-features --code-folding -S` on `.tmp/code-folding-next5/slice7-one-block-else-multiroot.wat`; Binaryen preserves the `if`, leaves the else-only `i32.const 2` / `drop` prefix in the block arm, and shares one `call $sink` / `f32.const 0` suffix after the `if`. The existing local one-block matcher already handled this opposite multi-root orientation, and `moon test src/passes` passed `1644/1644`.

Follow-up `[O4Z-AUDIT-CF-H]` `br_if` block-exit payload poison coverage on 2026-06-05 checked `wasm-opt` version 129 (`version_129`) with `--all-features --code-folding -S` on `.tmp/code-folding-next5/slice8-br-if-block-payload-negative.wat`; Binaryen preserves both `call $sink` / `i32.const 7` payload/fallthrough copies when a value-carrying `br_if` targets the block. The existing local collector already poisoned the label for `br_if` target traffic, and `moon test src/passes` passed `1645/1645`.

Follow-up `[O4Z-AUDIT-CF-G/H]` crossed nested-label direct `return_call` negative on 2026-06-05 checked `wasm-opt` version 129 (`version_129`) with `--all-features --code-folding -S` on `.tmp/code-folding-next5/slice9-crossed-return-call-negative.wat`; Binaryen preserves both crossed nested-label suffixes and both direct tail calls. The local crossed-label and tail-call operand-only guards already matched this direct tail-call sibling of the earlier indirect negative, and `moon test src/passes` passed `1646/1646`.

Follow-up `[O4Z-AUDIT-CF-G/H]` nested self-branching direct `return_call` coverage on 2026-06-05 checked `wasm-opt` version 129 (`version_129`) with `--all-features --code-folding -S` on `.tmp/code-folding-next5/slice10-nested-return-call.wat`; Binaryen shares the nested internal-label block suffix and leaves one direct tail call. The existing local alpha-map movement proof already handled this direct tail-call sibling of the indirect/ref positives, and `moon test src/passes` passed `1647/1647`.

Requested 10000-case compare smoke on 2026-06-05:

```sh
moon build --target native --release src/cmd
# Finished with existing unused-function warnings in pass_manager.mbt and 0 errors.
# The requested target/native/release/build/cmd/cmd.exe path did not exist in this workspace.

bun scripts/pass-fuzz-compare.ts --pass code-folding --count 10000 --seed 0x5eed \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/pass-fuzz-code-folding-after-10-more-slices-10000
# Compared cases: 0/10000
# Normalized matches: 0
# Mismatches: 0
# Command failures: 35 command-class.starshine-command-failed
# First failure: ENOENT for target/native/release/build/cmd/cmd.exe

bun scripts/pass-fuzz-compare.ts --pass code-folding --count 10000 --seed 0x5eed \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/pass-fuzz-code-folding-after-10-more-slices-10000-nativebin
# Compared cases: 6768/10000
# Normalized matches: 6768
# Compare-normalized matches: 0
# Cleanup-normalized matches: 0
# Validation failures: 0
# Property failures: 0
# Generator failures: 0
# Command failures: 20
# Mismatches: 0
```

The actual native binary path for this workspace is `_build/native/release/build/cmd/cmd.exe`. The 20 rerun command failures are classified as tool/Binaryen command failures, not Starshine semantic mismatches: `binaryen-rec-group-zero` (17), `binaryen-bad-section-size` (1), `binaryen-table-index-out-of-range` (1), and `binaryen-invalid-tag-index` (1). This requested smoke is evidence before the next five slices, not a final parity closeout for any later state.

Follow-up `[O4Z-AUDIT-CF-F]` simple return-operand profitability coverage on 2026-06-05 checked `wasm-opt` version 129 (`version_129`) with `--all-features --code-folding -S` on `.tmp/code-folding-next5b/slice1-return-operand-only-negative.wat`; Binaryen preserves both sibling `(local.get 1) / return` tails and the `i32.const 99` fallback rather than building a helper for an operand-only return suffix. The matching local slice is coverage for the existing simplified profitability boundary rather than a behavior change.

Follow-up `[O4Z-AUDIT-CF-I]` `catch_ref` terminal-tail EH bailout coverage on 2026-06-05 checked `wasm-opt` version 129 (`version_129`) with `--all-features --enable-exception-handling --code-folding -S` on `.tmp/code-folding-next5b/slice2-catch-ref-terminal-bailout.wat`; Binaryen preserves both terminal `call $sink` / `return` tails under the `catch_ref` `try_table`. The matching local slice extends the existing EH-terminal bailout coverage from `catch_all`/`catch_all_ref` to explicit `catch_ref` without implementing EH movement or nested-pop repair.

Follow-up `[O4Z-AUDIT-CF-G]` simple result `return_call` sibling-tail profitability coverage on 2026-06-05 checked `wasm-opt` version 129 (`version_129`) with `--all-features --code-folding -S` on `.tmp/code-folding-next5b/slice3-simple-result-return-call-negative.wat`; Binaryen preserves both direct `return_call` tails when the selected non-root group has no root-ending tail and only simple local/constant operands around the terminal. The matching local slice is coverage for the existing tail-call profitability/root-fallthrough boundary rather than a behavior change.

Follow-up `[O4Z-AUDIT-CF-G]` simple result `return_call_indirect` sibling-tail profitability coverage on 2026-06-05 checked `wasm-opt` version 129 (`version_129`) with `--all-features --code-folding -S` on `.tmp/code-folding-next5b/slice4-simple-result-return-call-indirect-negative.wat`; Binaryen preserves both indirect tail-call roots under the same no-root-tail/simple-operand boundary. The matching local slice extends the direct tail-call negative to the indirect-signature comparison path without changing the broader nested internal-label positives.

Follow-up `[O4Z-AUDIT-CF-J/G]` late-neighborhood simple direct tail-call bailout coverage on 2026-06-05 checked `wasm-opt` version 129 (`version_129`) with `--all-features --code-folding --merge-blocks --remove-unused-brs --remove-unused-names --merge-blocks -S` on `.tmp/code-folding-next5b/slice5-simple-result-return-call-late-neighborhood.wat`; Binaryen's late cleanup neighborhood still preserves the two simple result `return_call` tails and the fallback value. The local pipeline now has the same small deterministic neighborhood guard for this negative tail-call boundary.

Continuation `[O4Z-AUDIT-CF-K]` invalid-output fix and 100000-case smoke on 2026-06-05:

- Latest 100000-case artifact root: `.tmp/pass-fuzz-code-folding-100000-after-td-fixes`.
- Focused failing-first regressions now cover multi-result exiting-block wrappers before bottom tails, typed loop bottom tails before enclosing unreachable, root branches after typed dead operands, typed `try_table` bottom before a root unreachable, root bottom sentinels before trailing typed debris, and duplicate bottom tails in typed dead blocks.
- Implementation fixes: `code_folding_try_flatten_exiting_block_at_region` no longer flattens multi-result exiting blocks; `code_folding_visit_region` threads a bottom-tail preservation flag through root/resultful loop/resultful `if` bodies; duplicate trailing bottom sentinels are still removed when a result context no longer needs them; HOT lift now computes branch payload arity for the implicit function label from the function return type for `br`, `br_if`, `br_table`, `br_on_null`, and `br_on_non_null`; the validator typechecker now clears the operand stack when an already-unreachable state receives another unreachable/branch escape.
- Validation before the large smoke: `moon fmt`; `moon test src/passes` passed `1658/1658`; `moon test src/validate` passed `1552/1552`; `moon build --target native --release src/cmd` completed and produced `_build/native/release/build/cmd/cmd.exe`. Final docs/code signoff after refreshing the local Moon registry cache with `moon update`: `moon info`, `moon fmt`, and full `moon test` passed `4843/4843`.
- Replay of the original Starshine command-failure artifacts compared `5/5` cases with `5` normalized matches and no command or validation failures. Replay of original validation failures compared `2/2` cases with `0` validation/command failures and left one valid mismatch (`case-046375`). Replay of the original mismatch set compared `5/5` cases; `case-021671` now normalized, and `012741`, `023083`, `043481`, and `082547` remained mismatches.
- Full direct smoke:

```sh
bun scripts/pass-fuzz-compare.ts --pass code-folding --count 100000 --seed 0x5eed \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/pass-fuzz-code-folding-100000-after-td-fixes
# Compared cases: 99747/100000
# Normalized matches: 99742
# Cleanup-normalized matches: 0
# Mismatches: 5
# Validation failures: 0
# Property failures: 0
# Generator failures: 0
# Command failures: 253
```

The 253 command failures are agent-classified as tool/Binaryen command failures: `binaryen-rec-group-zero` (221), `binaryen-bad-section-size` (8), `binaryen-table-index-out-of-range` (10), `binaryen-invalid-tag-index` (2), `binaryen-command-failed` (10), and `binaryen-invalid-type-index` (2). There are no remaining Starshine command-failure, validation-failure, or property-failure buckets in this 100000-case lane.

Remaining mismatch families in `.tmp/pass-fuzz-code-folding-100000-after-td-fixes/failures` are agent-classified as follows:

| Case(s) | Starshine/Binaryen difference | Agent classification | Rationale / follow-up |
| --- | --- | --- | --- |
| `012741`, `043481` | Binaryen keeps `drop(local.get v128)` or `drop(v128.const ...)` before `unreachable`; Starshine removes the pure dead value root and leaves only `unreachable`. | semantic-safe, size-winning cleanup drift | Dropping a local get or constant has no side effects and cannot trap; both outputs validate and immediately trap at the remaining `unreachable`. Keep as documented representation/code-size drift unless a stricter text-parity lane is required. |
| `023083` | Binaryen keeps `drop(i32x4.trunc_sat_f64x2_s_zero(v128.const ...))` before `unreachable`; Starshine removes the pure SIMD typed-dead root. | semantic-safe, size-winning cleanup drift | The saturated SIMD conversion of a constant is nontrapping and side-effect-free; the path remains unreachable. Keep documented rather than reintroducing dead debris. |
| `082547` | Binaryen keeps a `drop(f32.ceil(f32.const ...))` before an inner loop `unreachable`; Starshine removes that pure nontrapping debris and keeps the loop/root bottom sentinels. | semantic-safe, size-winning cleanup drift | Constant `f32.ceil` is nontrapping and side-effect-free; the loop body still reaches `unreachable`, and the enclosing result function retains the required bottom. |
| `046375` | Binaryen reduces a typed-dead wrapper to `nop; unreachable`; Starshine now removes the dead wrapper and emits just `unreachable`. | semantic-safe, size-winning representation drift | This was the formerly invalid-output and then size-losing family. The follow-up cleanup only removes a multi-result dead block when it is adjacent to an unreachable and its pre-unreachable body prefix is no-op-only, preserving the broader bottom-tail guards. Starshine is now `73B` vs Binaryen `74B` for this case because local lowering elides Binaryen's `nop`. |

Follow-up `[O4Z-AUDIT-CF-K]` size-losing mismatch cleanup on 2026-06-05:

- Added failing-first coverage for the `case-046375` typed-dead wrapper family: a multi-result typed block with only a no-op prefix before its internal `unreachable`, adjacent to an enclosing/root `unreachable`, should not survive as a size-losing wrapper.
- Implementation: `code-folding` now has a narrow no-op-prefix dead-block cleanup for multi-result block labels before/after `unreachable`, gated away from large functions; `hot_lower` skips final stack repair when the lowered body already ends in nonfallthrough code and trims empty-block/drop debris after an unreachable.
- Replay of the five previous mismatch cases at `.tmp/pass-fuzz-code-folding-replay-5-after-046375-size-win` still has five semantic-safe mismatches and no command/validation failures, but `case-046375` is now size-winning (`73B` Starshine vs `74B` Binaryen) rather than size-losing. The other four mismatch families remain the same size-winning pure-debris cleanup drift.
- Direct 1000-case smoke at `.tmp/pass-fuzz-code-folding-046375-fix-1000`: `998/1000` compared, `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures.
- Focused/final validation: `moon test src/passes` passed `1659/1659`; `moon test src/ir` passed `245/245`; `moon info`, `moon fmt`, and full `moon test` passed `4844/4844`; native build completed at `_build/native/release/build/cmd/cmd.exe`.
- Requested performance check: `.tmp/code-folding-046375-self-compare-after-large-gate` reported Starshine pass time `5051.616ms` vs Binaryen `185.490ms`, outside the repo floor. Earlier reruns in `.tmp/code-folding-046375-self-compare*` were similarly around `5s`; this is now recorded under `[O4Z-AUDIT-CF-L]` as a pass-local timing blocker instead of hidden under `[WALL]001`.

Follow-up `[O4Z-AUDIT-CF-I]` EH-body `catch_ref` / `catch_all_ref` breadth on 2026-06-05:

- Source-backed probe: `wasm-opt version_129 --all-features --enable-exception-handling --code-folding -S` folds `.tmp/code-folding-next5/slice3-try-table-catch-all-ref-if.wat` by keeping the unique `i32.const 1/2` prefixes in the `if` and sharing one trailing `call $sink` / `i32.const 7` suffix before the throwing continuation.
- Added failing-first local tests for the same throwing-body shape through `catch_ref` and `catch_all_ref`; both initially preserved two `call (Func 0)` and two `i32.const I32(7)` roots because the try-table sat inside a dropped resultful outer block and the embedded-control visitor only entered dropped branch-payload controls.
- Implementation: `code_folding_visit_region` now has a narrow dropped-value EH-body traversal that looks for embedded `try` / `try_table` controls and only applies the existing non-terminal EH-body `if` suffix folder. It does not collect EH block exits or terminating tails and does not treat EH controls as normal fallthrough-preventing cleanup nodes.
- Validation/evidence: `moon test src/passes` failed first with the two new tests, then passed `1661/1661`; final `moon info`, `moon fmt`, and full `moon test` passed `4846/4846`; native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe`; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-eh-catch-ref-body-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures.

Follow-up `[O4Z-AUDIT-CF-E]` one-block/one-non-block partial/full value-arm breadth on 2026-06-05:

- Source-backed probes with `wasm-opt version_129 --all-features --code-folding -S` showed Binaryen hoists a shared one-block/non-block `f32.const 0` value suffix even when both arms have distinct void prefixes, and also folds the full one-block/non-block value-arm case to `drop(condition)` plus one shared value.
- Added failing-first local tests for both shapes. Initial `moon test src/passes` failed `code-folding hoists one-block value suffixes with both arm prefixes` and `code-folding folds full one-block value arms` (`1661/1663` passed) because the one-block matcher only handled cases where the whole non-block arm was the block body's suffix.
- Implementation: `code_folding_try_fold_one_block_if_arm` now computes the actual common suffix between the unused block body and the non-block arm, rejects exit-bearing prefixes and terminal suffixes, removes the matching suffix from both arms, demotes the block/if to void for partial folds, and uses the existing `drop(condition)` replacement for full one-block value folds.
- Validation/evidence: after the fix `moon test src/passes` passed `1663/1663`; final `moon info`, `moon fmt`, and full `moon test` passed `4848/4848`; native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe`; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-one-block-prefix-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures.

Follow-up `[O4Z-AUDIT-CF-E]` full one-block/non-block void-arm breadth on 2026-06-05:

- Source-backed probes with `wasm-opt version_129 --all-features --code-folding -S` showed Binaryen folds both tiny and larger full one-block/non-block void arms to `drop(condition)` plus the single shared void suffix.
- Added failing-first local tests `code-folding folds tiny full one-block void arms` and `code-folding folds full one-block void arms`. The pre-fix native Starshine probe preserved the `if` and both duplicate suffixes for the larger source shape while Binaryen removed the `if`.
- Implementation: `code_folding_try_fold_one_block_if_arm` now lets the existing full-arm replacement path run for result-void one-block/non-block arms instead of bailing out before the shared suffix is spliced. The ordinary non-block/non-block tiny full-void profitability negative remains covered separately.
- Validation/evidence: after the fix `moon test src/passes` passed `1665/1665`; `moon fmt`, `moon info`, and full `moon test` passed `4850/4850`; native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe` with the existing `pass_manager` unused-function warnings; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-one-block-full-void-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures.

Follow-up `[O4Z-AUDIT-CF-E]` two-block void-arm suffix breadth on 2026-06-05:

- Source-backed probe with `wasm-opt version_129 --all-features --code-folding -S` showed Binaryen hoists a shared `i32.const 9; call $sink; i32.const 7; drop` suffix out of two unused void block arms while preserving the distinct `i32.const 1/2; drop` prefixes in the `if` arms.
- Added focused local test `code-folding hoists two-block void if suffixes`. The implementation removes the previous result-void bailout in `code_folding_try_fold_two_block_if_at_region`, while only demoting block/if result types for resultful folds; already-void block arms can splice out the shared suffix without type mutation.
- Validation/evidence: `moon test src/passes` passed `1666/1666`; `moon info`, `moon fmt`, and full `moon test` passed `4851/4851`; native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe` with the existing `pass_manager` unused-function warnings; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-two-block-void-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures.

Follow-up `[O4Z-AUDIT-CF-E]` full multi-root non-block value-arm breadth on 2026-06-05:

- Source-backed probes with `wasm-opt version_129 --all-features --code-folding -S` showed Binaryen folds full multi-root non-block value arms from `if (result f32)` to `drop(condition); nop; f32.const 0`, while still preserving the simple one-root full-value non-block case for `optimize-instructions`. A second probe showed Binaryen wraps the same full multi-root fold in a typed `block (result f32)` when the `if` is a `select` value child.
- Added focused local tests `code-folding folds full multi-root non-block value arms` and `code-folding folds embedded select full multi-root value if arms`. The first failing-first `moon test src/passes` run failed the top-level test (`1666/1667` passed); after the initial top-level fix, the embedded-select test still failed until the select visitor and typed wrapper rewrite were added.
- Implementation: `code_folding_full_value_if_common_suffix_allowed` now permits full non-block value-arm folds when the shared suffix has more than one root, preserving the existing simple one-root no-op boundary. A new narrow embedded-select rewriter folds only full single-result multi-root `if` children of `select`, replacing the child with a typed block containing `drop(condition)` plus the shared suffix.
- Validation/evidence: `moon test src/passes` passed `1668/1668`; `moon info`, `moon fmt`, and full `moon test` passed `4853/4853`; native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe` with the existing `pass_manager` unused-function warnings; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-full-multiroot-value-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures.

Follow-up `[O4Z-AUDIT-CF-E]` embedded-select partial value-if suffix breadth on 2026-06-05:

- Source-backed probe with `wasm-opt version_129 --all-features --code-folding -S -o -` on `.tmp/cf-select-partial.wat` showed Binaryen wraps a `select` value child partial suffix fold in a typed `block (result f32)`, preserving the demoted void `if` with the distinct arm prefixes and moving one shared `f32.const 0` after it.
- Added failing-first local test `code-folding folds embedded select partial value if suffixes`. The initial `moon test src/passes` run failed the new test (`1668/1669` passed) because the embedded-select rewriter only handled full multi-root arms.
- Implementation: `code_folding_try_fold_embedded_select_if_child` now accepts partial single-result suffixes as well as the existing full multi-root case. Partial folds set the embedded `if` result to void and replace the `select` child with a typed block containing the demoted `if` plus the shared suffix; full simple one-root arms remain a no-op for this pass.
- Validation/evidence: after the fix `moon test src/passes` passed `1669/1669`; `moon fmt`, `moon info`, and full `moon test` passed `4854/4854`; native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe` with the existing `pass_manager` unused-function warnings; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-select-partial-value-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures (`command-class.binaryen-rec-group-zero`).

Follow-up `[O4Z-AUDIT-CF-E]` embedded value-parent suffix breadth on 2026-06-05:

- Source-backed probes with `wasm-opt version_129 --all-features --code-folding -S -o -` on `.tmp/code-folding-next-cf/embedded-{drop,call,binop}-partial.wat` showed Binaryen wraps the demoted `if` plus one shared `f32.const 0` suffix in a typed `block (result f32)` when the value child is consumed by `drop`, `call`, or `f32.add`. Matching full multi-root probes for `call` and `f32.add` showed the same typed-wrapper style with `drop(condition)` plus the shared suffix inside the wrapper.
- Added five failing-first local tests: `code-folding folds embedded drop partial value if suffixes`, `code-folding folds embedded call partial value if suffixes`, `code-folding folds embedded binary partial value if suffixes`, `code-folding folds embedded call full multi-root value if arms`, and `code-folding folds embedded binary full multi-root value if arms`. The initial `moon test src/passes` run failed exactly those tests (`1669/1674` passed).
- Implementation: the embedded child fold is now a narrow `select` / `drop` / `call` / `binary` typed-wrapper rewrite instead of a `select`-only helper; root `call` and `binary` nodes now visit direct embedded controls; and `drop` visits direct embedded control children in addition to the older embedded branch-payload shape. This deliberately does not generalize to every value parent.
- Validation/evidence: after the fix `moon test src/passes` passed `1674/1674`; `moon fmt`, `moon info`, and full `moon test` passed `4859/4859`; native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe` with the existing `pass_manager` unused-function warnings; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-embedded-value-parents-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures (`command-class.binaryen-rec-group-zero`).

Follow-up `[O4Z-AUDIT-CF-E]` embedded setter/store/return value-parent suffix breadth on 2026-06-05:

- Source-backed probes with `wasm-opt version_129 --all-features --code-folding -S -o -` on `.tmp/code-folding-next-cf2/embedded-{local-set,local-tee,global-set,store,return}-partial.wat` showed Binaryen uses the same typed `block (result f32)` wrapper for partial value-child `if` suffixes consumed by `local.set`, `local.tee`, `global.set`, `f32.store`, and `return`.
- Added five failing-first local tests: `code-folding folds embedded local.set partial value if suffixes`, `code-folding folds embedded local.tee partial value if suffixes`, `code-folding folds embedded global.set partial value if suffixes`, `code-folding folds embedded store partial value if suffixes`, and `code-folding folds embedded return partial value if suffixes`. The initial `moon test src/passes` run failed exactly those tests (`1674/1679` passed).
- Implementation: `code_folding_parent_accepts_embedded_value_wrapper` now admits only those five additional source-backed parent ops, and the region visitor reaches direct embedded control children for those same roots. The rewrite remains deliberately narrow and still does not treat every value parent as safe.
- Validation/evidence: after the fix `moon test src/passes` passed `1679/1679`; `moon fmt`, `moon info`, and full `moon test` passed (`4864/4864`); native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe` with existing `pass_manager` unused-function warnings; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-embedded-value-set-return-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures (`command-class.binaryen-rec-group-zero`).


Follow-up `[O4Z-AUDIT-CF-E]` embedded core value-parent suffix breadth on 2026-06-05:

- Source-backed probes with `wasm-opt version_129 --all-features --code-folding -S -o -` on `.tmp/code-folding-next-slices/embedded-{br,unary,convert,load,compare}-partial.wat` showed Binaryen uses the same typed wrapper style for partial value-child `if` suffixes consumed by a plain `br` payload, `f32.neg` / `unary`, `f64.promote_f32` / `convert`, `i32.load`, and `i32.eq` / `compare` parents.
- Added five failing-first local tests: `code-folding folds embedded br payload partial value if suffixes`, `code-folding folds embedded unary partial value if suffixes`, `code-folding folds embedded convert partial value if suffixes`, `code-folding folds embedded load partial value if suffixes`, and `code-folding folds embedded compare partial value if suffixes`. The initial `moon test src/passes` run failed exactly those tests (`1679/1684` passed).
- Implementation: `code_folding_parent_accepts_embedded_value_wrapper` now admits only those five additional source-backed parent op families, and the region visitor reaches direct embedded controls at `unary`, `convert`, `load`, and `compare` roots while reusing the existing budgeted `br` embedded-control traversal. The rewrite remains deliberately narrow and still does not treat every value parent as safe.
- Validation/evidence: after the fix `moon test src/passes` passed `1684/1684`; `moon fmt`, `moon info`, and full `moon test` passed (`4869/4869`); native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe` with existing `pass_manager` unused-function warnings; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-embedded-value-core-ops-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures (`command-class.binaryen-rec-group-zero`).

Follow-up `[O4Z-AUDIT-CF-E]` embedded ref/table/memory value-parent suffix breadth on 2026-06-05:

- Source-backed probes with `wasm-opt version_129 --all-features --code-folding -S -o -` on `.tmp/code-folding-next5-probes/{ref-is-null,table-get,table-set-index,call-indirect,memory-grow}-partial.wat` showed Binaryen uses the same typed wrapper style for partial value-child `if` suffixes consumed by `ref.is_null`, `table.get`, `table.set` index, `call_indirect`, and `memory.grow` parents.
- Added five failing-first local tests: `code-folding folds embedded ref.is_null partial value if suffixes`, `code-folding folds embedded table.get partial value if suffixes`, `code-folding folds embedded table.set index partial value if suffixes`, `code-folding folds embedded call_indirect partial value if suffixes`, and `code-folding folds embedded memory.grow partial value if suffixes`. The initial `moon test src/passes` run failed exactly those tests (`1684/1689` passed).
- Implementation: `code_folding_parent_accepts_embedded_value_wrapper` now admits only those five additional source-backed parent op families, and the region visitor reaches direct embedded controls at those roots. The rewrite remains deliberately narrow and still does not treat every value parent as safe.
- Validation/evidence: after the fix `moon test src/passes` passed `1689/1689`; `moon fmt`, `moon info`, and full `moon test` passed (`4874/4874`); native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe` with existing `pass_manager` unused-function warnings; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-embedded-ref-table-memory-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures (`command-class.binaryen-rec-group-zero`).

Follow-up `[O4Z-AUDIT-CF-E]` embedded table/bulk-memory value-parent suffix breadth on 2026-06-05:

- Source-backed probes with `wasm-opt version_129 --all-features --code-folding -S -o -` on `.tmp/code-folding-next5-probes/{table-grow,table-fill-value,memory-fill-dest,memory-copy-dest,memory-init-dest}-partial.wat` showed Binaryen uses the same typed wrapper style for partial value-child `if` suffixes consumed by `table.grow`, `table.fill`, `memory.fill`, `memory.copy`, and `memory.init` parents.
- Added five failing-first local tests: `code-folding folds embedded table.grow partial value if suffixes`, `code-folding folds embedded table.fill value partial value if suffixes`, `code-folding folds embedded memory.fill dest partial value if suffixes`, `code-folding folds embedded memory.copy dest partial value if suffixes`, and `code-folding folds embedded memory.init dest partial value if suffixes`. The initial `moon test src/passes` run failed exactly those tests (`1689/1694` passed).
- Implementation: `code_folding_parent_accepts_embedded_value_wrapper` now admits only those five additional source-backed parent op families, and the region visitor reaches direct embedded controls at those roots. The rewrite remains deliberately narrow and still does not treat every value parent as safe.
- Validation/evidence: after the fix `moon test src/passes` passed `1694/1694`; `moon fmt`, `moon info`, and full `moon test` passed (`4879/4879`); native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe` with existing `pass_manager` unused-function warnings; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-table-memory-bulk-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures (`command-class.binaryen-rec-group-zero`).

Follow-up `[O4Z-AUDIT-CF-K]` requested 100000-case mismatch triage on 2026-06-05:

- Inspected the five requested mismatch artifacts in `.tmp/pass-fuzz-code-folding-table-memory-bulk-100000-maxfail2000/failures`: `case-012741-wasm-smith`, `case-023083-wasm-smith`, `case-043481-wasm-smith`, `case-046375-wasm-smith`, and `case-082547-wasm-smith`.
- The semantic classification remains agent-judged semantic-safe cleanup/representation drift: the removed roots are nontrapping, effect-free local/constant/unary/SIMD value debris on paths that still immediately reach `unreachable`, and `046375` is the already-documented no-op wrapper/nop-elision family. However, direct raw-size inspection found two detrimental Starshine raw outputs in the requested lane even though normalized comparison output was size-winning: `023083` was `74B` Starshine raw vs `72B` Binaryen raw, and `082547` was `70B` Starshine raw vs `68B` Binaryen raw.
- Added failing-first focused tests for those detrimental raw families: `code-folding removes pure simd debris after bottom in typed dead block` and `code-folding removes pure float debris after loop bottom`; the first test-first `moon test src/passes` failed exactly those two new tests (`1694/1696`).
- Implementation: `hot_lower` now has a narrow final-body cleanup that removes a source-backed pure nontrapping dropped unary/SIMD value expression (`f32.ceil` or `i32x4.trunc_sat_f64x2_*_zero` fed by a pure leaf) only when it sits between a leading bottom sentinel and a later `unreachable`. This keeps the existing bottom-tail preservation shape while deleting raw-size-losing dead debris.
- Validation/evidence: after the fix `moon fmt` and `moon test src/passes` passed (`1696/1696`), `moon test src/ir` passed (`245/245`), native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe`, replay of the five requested mismatches at `.tmp/pass-fuzz-code-folding-replay-5-pure-drop-cleanup` compared `5/5` cases with `0` validation/command failures and five remaining semantic-safe mismatches, and direct 1000-case compare at `.tmp/pass-fuzz-code-folding-pure-drop-cleanup-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures. Final serialized signoff then passed `moon info`, `moon fmt`, and full `moon test` (`4881/4881`). Replay sizes now show every inspected family is Starshine raw-size-winning or positive: `023083` is `51B` Starshine raw vs `72B` Binaryen raw, and `082547` is `62B` Starshine raw vs `68B` Binaryen raw.

Follow-up `[O4Z-AUDIT-CF-E]` embedded table-copy value-parent suffix breadth on 2026-06-05:

- Source-backed probe with `wasm-opt version_129 --all-features --code-folding -S -o -` on `.tmp/cf-table-copy-partial.wat` showed Binaryen uses the same typed wrapper style for a partial value-child `if` suffix consumed by the destination operand of `table.copy`.
- Added failing-first local test `code-folding folds embedded table.copy dest partial value if suffixes`. The initial `moon test src/passes` run failed that new test (`1696/1697` passed) because the embedded value-parent allowlist and direct-control visitor did not include `table.copy`.
- Implementation: `code_folding_parent_accepts_embedded_value_wrapper` now admits `HotOp::TableCopy`, and `code_folding_visit_region` visits direct embedded controls at `table.copy` roots. This is another source-backed allowlist increment, not a general heap/value-parent widening.
- Validation/evidence: after the fix `moon fmt`, `moon info`, and full `moon test` passed (`4882/4882`); native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe`; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-table-copy-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures.

2026-06-06 embedded `return_call_ref` value-parent continuation:

- Source-backed probe with `wasm-opt version_129 --all-features --code-folding -S -o -` on `.tmp/cf-return-call-ref-partial-stack.wat` showed Binaryen uses the same typed wrapper style for a partial value-child `if` suffix consumed by a `return_call_ref` callee-reference operand.
- The local text frontend rejects this WAT surface, so the focused local test is core-built with `@lib.Instruction::return_call_ref`, a declarative elem for `ref.func`, and the same logical shape as the Binaryen probe.
- Added failing-first local test `code-folding folds embedded return_call_ref partial value if suffixes`. The core-built initial `moon test src/passes` run failed that new behavior test (`1701/1702` passed) because the embedded value-parent allowlist and direct-control visitor did not include `return_call_ref`.
- Implementation: `code_folding_parent_accepts_embedded_value_wrapper` now admits `HotOp::ReturnCallRef`, and `code_folding_visit_region` visits direct embedded controls at `return_call_ref` roots. This is a source-backed terminal value-parent allowlist increment, not a general tail-call broadening.
- Validation/evidence: after the fix `moon test src/passes`, `moon fmt`, `moon info`, and full `moon test` passed (`4887/4887`); native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe`; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-return-call-ref-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures.

2026-06-06 embedded `call_ref` value-parent continuation:

- Source-backed probe with `wasm-opt version_129 --all-features --code-folding -S -o -` on `.tmp/cf-call-ref-partial-stack.wat` showed Binaryen uses the same typed wrapper style for a partial value-child `if` suffix consumed by a `call_ref` callee-reference operand.
- The local text frontend rejects this WAT surface, so the focused local test is core-built with `@lib.Instruction::call_ref`, a declarative elem for `ref.func`, and the same logical shape as the Binaryen probe.
- Added failing-first local test `code-folding folds embedded call_ref partial value if suffixes`. The core-built initial `moon test src/passes` run failed that new behavior test (`1700/1701` passed) because the embedded value-parent allowlist and direct-control visitor did not include `call_ref`.
- Implementation: `code_folding_parent_accepts_embedded_value_wrapper` now admits `HotOp::CallRef`, and `code_folding_visit_region` visits direct embedded controls at `call_ref` roots. This is another source-backed allowlist increment, not a general GC/value-parent broadening.
- Validation/evidence: after the fix `moon test src/passes`, `moon fmt`, `moon info`, and full `moon test` passed (`4886/4886`); native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe`; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-call-ref-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures.

2026-06-06 embedded `ref.cast` value-parent continuation:

- Source-backed probe with `wasm-opt version_129 --all-features --code-folding -S -o -` on `.tmp/cf-ref-cast-func-partial.wat` showed Binaryen uses the same typed wrapper style for a partial value-child `if` suffix consumed by a `ref.cast` operand.
- As with `ref.test`, the local text frontend does not yet provide a clean WAT surface for this shape, so the focused local test is core-built with `@lib.Instruction::ref_cast` while preserving the Binaryen WAT probe as source evidence.
- Added failing-first local test `code-folding folds embedded ref.cast partial value if suffixes`. The core-built initial `moon test src/passes` run failed that new behavior test (`1699/1700` passed) because the embedded value-parent allowlist and direct-control visitor did not include `ref.cast`.
- Implementation: `code_folding_parent_accepts_embedded_value_wrapper` now admits `HotOp::RefCast`, and `code_folding_visit_region` visits direct embedded controls at `ref.cast` roots. This is another source-backed allowlist increment, not a general GC/ref broadening.
- Validation/evidence: after the fix `moon test src/passes`, `moon fmt`, `moon info`, and full `moon test` passed (`4885/4885`); native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe`; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-ref-cast-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures.

2026-06-06 embedded `ref.test` value-parent continuation:

- Source-backed probe with `wasm-opt version_129 --all-features --code-folding -S -o -` on `.tmp/cf-ref-test-func-partial.wat` showed Binaryen uses the same typed wrapper style for a partial value-child `if` suffix consumed by a `ref.test` operand.
- The local text frontend still rejects this WAT surface, so the focused local test is core-built with `@lib.Instruction::ref_test` while preserving the Binaryen WAT probe as source evidence.
- Added failing-first local test `code-folding folds embedded ref.test partial value if suffixes`. The core-built initial `moon test src/passes` run failed that new behavior test (`1698/1699` passed) because the embedded value-parent allowlist and direct-control visitor did not include `ref.test`.
- Implementation: `code_folding_parent_accepts_embedded_value_wrapper` now admits `HotOp::RefTest`, and `code_folding_visit_region` visits direct embedded controls at `ref.test` roots. This is another source-backed allowlist increment, not a general GC/ref broadening.
- Validation/evidence: after the fix `moon test src/passes`, `moon fmt`, `moon info`, and full `moon test` passed (`4884/4884`); native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe`; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-ref-test-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures.

2026-06-06 embedded `table.init` value-parent continuation:

- Source-backed probe with `wasm-opt version_129 --all-features --code-folding -S -o -` on `.tmp/cf-table-init-partial-42.wat` showed Binaryen uses the same typed wrapper style for a partial value-child `if` suffix consumed by the destination operand of `table.init`.
- Added failing-first local test `code-folding folds embedded table.init dest partial value if suffixes`. The initial `moon test src/passes` run failed that new test (`1697/1698` passed) because the embedded value-parent allowlist and direct-control visitor did not include `table.init`.
- Implementation: `code_folding_parent_accepts_embedded_value_wrapper` now admits `HotOp::TableInit`, and `code_folding_visit_region` visits direct embedded controls at `table.init` roots. This is another source-backed allowlist increment, not a general all-value-parent widening.
- Validation/evidence: after the fix `moon test src/passes`, `moon fmt`, `moon info`, and full `moon test` passed (`4883/4883`); native `src/cmd` rebuilt at `_build/native/release/build/cmd/cmd.exe`; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-table-init-1000` compared `998/1000` cases with `998` normalized matches, `0` mismatches, `0` validation failures, and `2` tool/Binaryen command failures.

Still required before closing the overall `[O4Z-AUDIT-CF]` parity track:

- rerun direct compare at large count after the next behavior-widening batch or before closeout; the latest 100000-case lane has no Starshine validation/command failures, and the latest focused replay has five documented semantic-safe size-winning representation/cleanup mismatches;
- investigate and fix/attribute the `[O4Z-AUDIT-CF-L]` pass-local performance regression on the debug-WASI timing lane;
- run the late `code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks` neighborhood replay on generated artifacts;
- implement or explicitly classify the remaining Binaryen behavior-parity gaps sliced in `agent-todo.md`.

## Audit classification

Current agent classification: `code-folding` is wired and semantically accepted as a narrow direct pass based on prior May evidence. The June audit first widened single-result typed block-exit branch payload sharing, then completed the source-backed shape matrix and widened the named-block expression-exit candidate model to single-result multi-root suffix sharing for branch-plus-fallthrough and branch-only plain-`br` tails; the next source-backed increments add multi-value branch-plus-fallthrough and branch-only/unreachable-fallback payload suffixes. The next `[O4Z-AUDIT-CF-E]` progress widened `if` expression-exit folding for the safe one-block/one-non-block value-suffix shape in both orientations, now including cases where both arms have distinct prefixes before the shared value suffix, the full one-block/non-block value-arm fold to `drop(condition)` plus one suffix, the full one-block/non-block void-arm fold to `drop(condition)` plus the shared void suffix, the source-backed full multi-root non-block value-arm fold, the narrow embedded-select full-arm/partial typed-wrapper variants, and source-backed embedded `drop`, `call`, `call_ref`, `unary`, `binary`, `compare`, `convert`, `load`, `local.set`, `local.tee`, `global.set`, `store`, `br` payload, `return`, `return_call_ref`, `ref.is_null`, `ref.test`, `ref.cast`, `table.get`, `table.set` index, `call_indirect`, `memory.grow`, `table.grow`, `table.fill`, `memory.fill`, `memory.copy`, and `memory.init` value-parent typed-wrapper variants; it also added a source-backed two-unnamed-block value-arm suffix slice, exact partial non-block value-arm coverage for the Binaryen lit/doc shape, and a HOT-level unreachable-condition bailout, while exact public unreachable-condition fixtures remain blocked by local HOT/lower bottom-condition handling. `[O4Z-AUDIT-CF-F]` has progressed from the simple adjacent no-else `if` then-tail plus fallthrough `return`/`unreachable` shape to a root-anchored helper-label algorithm that collects root and nested region terminators, searches the deepest profitable suffix that includes the function-end tail, rewrites old nested tails to `br` to the fresh wrapper label, and keeps one shared terminal suffix after the wrapper. `[O4Z-AUDIT-CF-G]` has started on the same model for typed-result direct `return_call`, `return_call_indirect`, and core-built `return_call_ref` tails, including non-null `ref.func` nested self-branch coverage, with direct and indirect `return_call*` crossed-label negatives and tail-call operand-only profitability guard now keeping the Binaryen-preserved shape unfolded. `[O4Z-AUDIT-CF-H]` now has focused movement-safety negatives for `br_table`, outside-target switch-like return tails, careful switch target scope, a crossed nested-label guards, and narrow nested internal-label self-branching positives for `return`, `unreachable`, `return_call`, `return_call_indirect`, and `return_call_ref`; `[O4Z-AUDIT-CF-I]` now descends into `try` / `try_table` bodies only for non-terminal `if` arm suffix folding, keeps simple and nested `try_table` body-local `if` suffix positives plus terminal/block-exit bailout shapes, classifies explicit outer-`catch_all` and `catch_ref` / `catch_all_ref` `try_table` terminal-tail bailouts as matching Binaryen, covers the throwing-body `catch_ref` / `catch_all_ref` non-terminal positives through a narrow dropped-value EH-body traversal, and records the local plain-`try` text-surface blocker; `[O4Z-AUDIT-CF-J]` now has a local root-anchored fixpoint loop plus a small late-neighborhood helper-label fixture. Validation is green after the latest source-backed return_call_ref value-parent increment (`moon test src/passes`, `moon info`, `moon fmt`, full `moon test` `4887/4887`, native build at `_build/native/release/build/cmd/cmd.exe`), and direct 1000-case compare at `.tmp/pass-fuzz-code-folding-table-init-1000` had `998` normalized matches, `0` mismatches, and `2` tool/Binaryen command failures. The preceding requested five-mismatch raw-size triage replay at `.tmp/pass-fuzz-code-folding-replay-5-pure-drop-cleanup` kept five agent-classified semantic-safe mismatches with no validation/command failures while making the formerly raw-size-detrimental `023083` and `082547` families raw-size-winning. The latest 100000-case direct smoke remains `.tmp/pass-fuzz-code-folding-table-memory-bulk-100000-maxfail2000` / the earlier `.tmp/pass-fuzz-code-folding-100000-after-td-fixes` family evidence with `0` Starshine command failures, `0` validation failures, five agent-classified semantic-safe cleanup/representation mismatches, and tool/Binaryen command failures only; the requested post-046375 pass-local timing lane is currently outside the <=2x floor and tracked under `[O4Z-AUDIT-CF-L]`. `[O4Z-AUDIT-CF]` is still not complete because Binaryen behavior parity requires remaining exact `if` caveats, arbitrary terminating-tail subsets beyond root-anchored groups, broader branch/control-bearing movement, EH repair or exact folded/bailout classification, exact helper cost/fixpoint parity, generated late-neighborhood evidence, fixing the pass-local timing blocker, and accepting or eliminating the remaining documented semantic-safe representation/cleanup mismatches.
