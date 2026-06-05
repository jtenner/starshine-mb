---
kind: research
status: working
last_reviewed: 2026-06-04
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

- `src/passes/code_folding.mbt` owns the active HOT descriptor and narrowed transform, now including the June single-result typed block-exit payload-sharing slice.
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
- focused tests cover both branch-plus-fallthrough and duplicate branch-only multi-root single-result suffixes using a shared effectful `call $sink` root before the final `i32.const` result.

## Source-backed Binaryen shape matrix

This table is backed by Binaryen `version_129` `src/passes/CodeFolding.cpp` and `test/lit/passes/code-folding.wast` plus the current Starshine owner/tests. It maps upstream behavior families to local coverage, gaps, and the next slice that should own any remaining work.

| Binaryen shape family | Binaryen behavior | Current Starshine status | Local tests / evidence | Gap | Next slice |
| --- | --- | --- | --- | --- | --- |
| Named-block void exit tails | Collects unconditional end-of-block `br $label` tails and possible fallthrough for a named block; moves an equal void suffix after the block when safe. | Covered for conservative void suffixes and fallthrough sharing. | `code-folding hoists block-exit tail shared with fallthrough`; `code-folding hoists block-exit tail before outer branch fallthrough`. | Helper-block profitability and broader nested cases remain narrower than Binaryen. | `[O4Z-AUDIT-CF-J]` for fixpoint/helper cleanup if needed. |
| Named-block typed branch payload tails | Treats plain-`br` payloads as mergeable tail items while preserving the branch shell; can share deeper suffix roots before the payload. | Covered for single-result plain-`br` payload roots and now single-result multi-root suffixes. | `code-folding hoists typed block-exit branch payload shared with fallthrough`; `... branch payloads without fallthrough`; new multi-root fallthrough and branch-only tests. | Multi-value payloads and non-plain branch participation remain unimplemented. | `[O4Z-AUDIT-CF-K]` for 10000-case closeout; future multi-value work only with HOT/lower proof. |
| Branch-plus-fallthrough tails | Adds the block's normal fallthrough as a tail when the end is reachable, so explicit exits and fallthrough can share a suffix. | Covered for void suffixes, single payload roots, and single-result multi-root payload suffixes. | Void fallthrough test plus typed fallthrough and multi-root fallthrough tests. | More complex helper/profitability shapes stay narrower. | `[O4Z-AUDIT-CF-J]` / `[O4Z-AUDIT-CF-K]`. |
| `if` unnamed block / unnamed block suffixes | Folds identical suffixes from unnamed `if` arms, including full-arm collapse to `drop(condition)` when profitable. | Covered for current void and value block suffix cases, including the exact partial non-block value-arm lit/doc shape where only the `f32.const 0` suffix is shared and source-backed two-unnamed-block value-arm shapes with unique prefixes sharing the final value suffix, now including a multi-root `call $sink` / `f32.const` suffix. Simple full-value non-block arms now remain a no-op for this pass. | `code-folding hoists identical if-arm suffixes`; `... full value if arms`; `code-folding keeps simple full value if arms for optimize-instructions`; `... partial value if suffixes`; `code-folding hoists exact partial non-block value if suffix`; `code-folding hoists two-block value if suffixes`; `code-folding hoists two-block multi-root value if suffixes`; `... structured suffixes`; profitability negative. | Does not yet model every Binaryen unnamed-block arm wrapper shape; local HOT/lower elides `nop`, so the exact partial non-block fixture asserts suffix sharing rather than final `nop` text, and broader named/unreachable-condition caveats remain open. | `[O4Z-AUDIT-CF-E]`. |
| One-block / one-non-block `if` wrapping | Binaryen can wrap one non-block arm in a synthetic unnamed block when it exactly matches the block arm's suffix. | Covered for the safe value-result shape in both then-block and else-block orientations, plus a source-backed then-block multi-root `call $sink` / `f32.const` value suffix. | `code-folding hoists one-block then-arm value suffix`; `code-folding hoists one-block else-arm value suffix`; `code-folding hoists one-block multi-root value suffix`. | Exact named-unused arm and unreachable-condition local fixture coverage remain caveated by HOT/name and local WAT validation surfaces; the opposite multi-root orientation can be added if Binaryen/source evidence demands it. | `[O4Z-AUDIT-CF-E]` follow-up only for those caveats. |
| Named-arm negatives | Named `if` arm blocks are not folded because their labels may be branch targets. | Covered for live-label structured suffix bailout, including a crossed inner-vs-outer branch target guard. | `code-folding keeps live-label structured if suffixes`; `code-folding keeps crossed live-label structured if suffixes`. | Exact named-unused arm text parity remains caveated by local name preservation; keep live branch-target guards green. | `[O4Z-AUDIT-CF-E]` / `[O4Z-AUDIT-CF-H]`. |
| Full-arm terminal `return` / `unreachable` subset | Binaryen's terminating-tail family handles general function endings; local expression-exit subset can safely share full `if` arms ending in empty-payload terminal roots. | Covered for conservative full-`if` terminal `return`/`unreachable` arms, the first helper-label-like no-else `if`/fallthrough terminal-tail shape, and a root-anchored function-ending helper-label subset. | `code-folding shares full if arms ending in return`; `... ending in unreachable`; `... shares if-then and fallthrough return tails`; `... unreachable tails`; `... non-adjacent return tails`; `... block-backed unreachable tails`. | Arbitrary non-root subsets and branch/control-bearing moved suffixes remain absent. | `[O4Z-AUDIT-CF-F]` and `[O4Z-AUDIT-CF-H/J]`. |
| General terminating `return` tails | Searches subsets of function-ending `return` tails, prefers deeper suffixes, rewrites old tails to a fresh helper label, and appends one shared suffix at function end. | Partially covered for adjacent no-else `if`/fallthrough tails, root-anchored non-adjacent `return` suffixes, and non-root `return` subsets; when the original root body can fall through, Starshine now wraps it with a skip label so ordinary fallthrough does not execute the shared terminal suffix, and it can exclude a different root `return` from the selected subset. The terminating-tail mover now accepts label-unused structured block/if/loop suffix roots through the same hoistability check used by expression-exit folding, plus narrow alpha-equivalent self-branching block cases whose internal branch targets remain inside the moved suffix; the equality helper now carries a multi-label alpha map for the nested internal-label subset, guarded by a crossed nested-label return negative that keeps inner-vs-outer branch targets distinct. | `code-folding shares if-then and fallthrough return tails`; `code-folding shares non-adjacent return tails`; `code-folding shares non-root return tail subsets`; `code-folding shares non-root return subsets excluding a different root return`; `code-folding folds deeper non-root return subset then shallow fixpoint`; `code-folding shares non-root structured block return suffixes`; `code-folding shares non-root structured if return suffixes`; `code-folding shares non-root structured loop return suffixes`; `code-folding shares non-root self-branch block return suffixes`; `code-folding shares non-root nested self-branch block return suffixes`; `code-folding shares non-root return tail subsets with root fallthrough`. | Needs broader movement safety, exact helper-block cost modeling, and additional arbitrary-subset/tail-call/unreachable coverage. | `[O4Z-AUDIT-CF-F]` / `[O4Z-AUDIT-CF-J]`. |
| Terminating `return_call`, `return_call_indirect`, `return_call_ref` | Records tail-call terminators through the same terminating-tail helper path. | Partially covered for root-anchored direct, indirect, and ref tail-call suffixes, including typed-result direct `return_call`, logical call-signature comparison for indirect/ref nodes, non-root direct/indirect/ref tail-call subsets with root fallthrough, direct `return_call` coverage for the narrow self-branching block suffix case, and `return_call_indirect` coverage for the nested internal-label self-branching suffix case. | `code-folding shares direct return-call tails with typed results`; `code-folding shares non-root direct return-call tail subsets with root fallthrough`; `code-folding shares non-root self-branch block return-call suffixes`; `code-folding shares return-call-indirect tails`; `code-folding shares non-root return-call-indirect tail subsets with root fallthrough`; `code-folding shares non-root nested self-branch return-call-indirect suffixes`; `code-folding shares return-call-ref tails`; `code-folding shares non-root return-call-ref tail subsets with root fallthrough`. | Needs broader arbitrary-subset coverage, broader movement-safety negatives, and more natural non-null `return_call_ref` fixtures once local syntax/HOT support is cleaner. | `[O4Z-AUDIT-CF-G]` / `[O4Z-AUDIT-CF-H/J]`. |
| Terminating `unreachable` tails | Runs terminating-tail folding for `unreachable` groups before return groups. | Partially covered for adjacent no-else `if`/fallthrough tails, root-anchored block-backed `unreachable` suffixes, a non-root `unreachable` subset with root fallthrough, and the same narrow self-branching plus nested internal-label self-branching block suffix cases as return tails, with a crossed nested-label negative for the `unreachable` family. | `code-folding shares full if arms ending in unreachable`; `code-folding shares if-then and fallthrough unreachable tails`; `code-folding shares block-backed unreachable tails`; `code-folding shares non-root unreachable tail subsets with root fallthrough`; `code-folding shares non-root self-branch block unreachable suffixes`; `code-folding shares non-root nested self-branch block unreachable suffixes`; `code-folding keeps crossed nested self-branch unreachable suffixes`; unreachable cleanup tests. | Needs broader arbitrary-subset/deeper-suffix coverage and branch/control-bearing movement proof. | `[O4Z-AUDIT-CF-F]` / `[O4Z-AUDIT-CF-H/J]`. |
| Unsupported branch poisoning (`br_on_*`, `br_if`, `br_table`, `delegate`) | Unsupported branch forms targeting a label mark that label unoptimizable for label folding; `br_table` / switch targets are treated conservatively. | Poison behavior preserved for local named-block folds, including a focused `br_table` negative. | Core-built `code-folding keeps br-on-null-poisoned block-exit suffixes`; `code-folding keeps br-table-poisoned block-exit suffixes`; collector rejects `br_if`, `br_on_*`, `br_table`, and `delegate` target traffic. | More official poison fixtures could be added for each unsupported family. | `[O4Z-AUDIT-CF-H]`. |
| Outside-target movement bailout | `canMove` rejects equal-looking suffixes if moving them would strand a branch target whose owner is inside the moved-out region. | Covered in simplified form through label-use and target-survival checks, with a reduced outside-target switch-like return-tail negative, narrow `return`, `unreachable`, and `return_call_indirect` positives where nested branch targets remain inside the moved suffix, and crossed nested-label negatives where an inner-label branch must not alpha-match an outer-label branch. | `code-folding keeps live-label structured if suffixes`; `code-folding keeps outside-target switch-like return tails`; `code-folding shares non-root nested self-branch block return suffixes`; `code-folding shares non-root nested self-branch block unreachable suffixes`; `code-folding shares non-root nested self-branch return-call-indirect suffixes`; `code-folding keeps crossed nested self-branch return suffixes`; `code-folding keeps crossed nested self-branch unreachable suffixes`; branch-target survival helper and label-map equality in `code_folding.mbt`. | Full branch/control-bearing terminating-tail movement is still rejected instead of repaired/moved. | `[O4Z-AUDIT-CF-H]`. |
| Equal-looking unsafe switch / `br_table` cases | Binaryen rejects switch/table cases where equality is insufficient because branch targets would not remain valid. | Conservative local collector poisons `br_table` target traffic; no positive switch folding. | `code-folding keeps careful switch target scopes`. | Positive switch folding remains out of scope; keep this negative before any broadening. | `[O4Z-AUDIT-CF-H]`. |
| EH-sensitive movement / bailout / repair | `canMove` rejects dangling `pop` and throwing-through-`try` hazards; block-adding rewrites can run EH nested-pop repair. | Local code now descends into `try` / `try_table` bodies only for non-terminal `if` arm suffix folding, while still treating EH controls as hard boundaries for block-exit and terminating-tail movement and keeping no repair path. A 2026-06-04 `wasm-opt version_129 --enable-exception-handling --code-folding -S` check showed an explicit outer-`catch_all` `try_table` terminal-tail shape stays unfolded in Binaryen, matching the local bailout. Separate checked `catch_all`, explicit `catch $e`, and nested `try_table` body shapes fold duplicate non-terminal `if` arm suffixes in both Binaryen and Starshine; exact text-level plain `try` coverage remains blocked because local WAT lowering erases that surface before final pretty output. | Collector returns false on `Try` / `TryTable` for block-exit and terminating-tail families; `code-folding folds non-terminal try-table if-arm body suffixes`; `code-folding folds catch try-table if-arm body suffixes`; `code-folding folds nested try-table if-arm body suffixes`; `code-folding keeps outer-catch try-table terminal tails as EH bailout`; `code-folding keeps try-table terminal tails as EH bailout`; `code-folding keeps try-table block-exit suffixes as EH bailout`. | EH movement/repair, throwing-through-try hazards, nested-pop repair, exact plain-`try` text-surface coverage, and broader EH shapes remain unimplemented or unclassified. | `[O4Z-AUDIT-CF-I]`. |
| Helper block / profitability / fixpoint | Uses a measured profitability heuristic, can add helper blocks, and repeats until no new fold is exposed. | Local expression-exit folds use a simplified suffix measure and direct after-block insertion; function-ending helper labels now use a node-count profitability threshold and the pass reruns its local visit/terminating-tail sequence to fixpoint. | Current tests cover unprofitable tiny full-void `if` bailout; named-block and terminating-tail plans carry suffix length and profitability score; `code-folding reaches a root-anchored terminating-tail fixpoint`; `code-folding folds deeper non-root return subset then shallow fixpoint`; `code-folding late branch-cleanup neighborhood keeps shared return tail valid`; `code-folding late branch-cleanup neighborhood keeps non-root return subset valid`. | Needs exact Binaryen helper cost modeling and generated late-slot proof. | `[O4Z-AUDIT-CF-J]` plus `[O4Z-AUDIT-CF-F/G]`. |

## Remaining direct completeness gaps

These are not new regressions; they are the known difference between Starshine's accepted narrow direct pass and Binaryen's broader `CodeFolding.cpp` surface.

- Function-ending helper-label sharing now covers a root-anchored subset for `return`, `return_call`, `return_call_indirect`, `return_call_ref`, and `unreachable`, and the local pass now reruns that root-anchored subset to fixpoint. It is still narrower than Binaryen's general algorithm: arbitrary non-root subsets, branch/control-bearing moved suffixes, exact helper cost modeling, and EH repair remain unimplemented.
- Branch-value folding for typed named-block exits now covers single-result plain-`br` payload sharing with matching fallthrough or multiple branch payloads, including a safe multi-root suffix before the final value root. It remains narrower than Binaryen's full branch-payload suffix model: no multi-value payloads, no `br_if` / `br_table` / `br_on_*` participation, no full helper-block profitability/subset search, and no broad EH-aware movement.
- EH-sensitive movement remains mostly a hard bailout: the pass now descends into `try` / `try_table` bodies only to run ordinary non-terminal `if` arm suffix folding, but it still does not collect block exits or terminating tails across EH boundaries and has no local nested-pop repair equivalent. The 2026-06-04 outer-`catch_all` `try_table` terminal-tail check matches Binaryen's bailout, and the separate non-terminal `catch_all` / explicit-`catch` `try_table` if-arm probes now have matching local coverage.
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

Still required before closing the overall `[O4Z-AUDIT-CF]` parity track:

- scale direct compare to `10000` after the next behavior-widening batch or before closeout;
- run the late `code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks` neighborhood replay;
- implement or explicitly classify the remaining Binaryen behavior-parity gaps sliced in `agent-todo.md`.

## Audit classification

Current agent classification: `code-folding` is wired and semantically accepted as a narrow direct pass based on prior May evidence. The June audit first widened single-result typed block-exit branch payload sharing, then completed the source-backed shape matrix and widened the named-block expression-exit candidate model to single-result multi-root suffix sharing for branch-plus-fallthrough and branch-only plain-`br` tails. The next `[O4Z-AUDIT-CF-E]` progress widened `if` expression-exit folding for the safe one-block/one-non-block value-suffix shape in both orientations, added a source-backed two-unnamed-block value-arm suffix slice, added exact partial non-block value-arm coverage for the Binaryen lit/doc shape, and added a HOT-level unreachable-condition bailout, while exact public unreachable-condition fixtures remain blocked by local HOT/lower bottom-condition handling. `[O4Z-AUDIT-CF-F]` has progressed from the simple adjacent no-else `if` then-tail plus fallthrough `return`/`unreachable` shape to a root-anchored helper-label algorithm that collects root and nested region terminators, searches the deepest profitable suffix that includes the function-end tail, rewrites old nested tails to `br` to the fresh wrapper label, and keeps one shared terminal suffix after the wrapper. `[O4Z-AUDIT-CF-G]` has started on the same model for typed-result direct `return_call`, `return_call_indirect`, and core-built `return_call_ref` tails. `[O4Z-AUDIT-CF-H]` now has focused movement-safety negatives for `br_table`, outside-target switch-like return tails, careful switch target scope, a crossed nested-label guard, and narrow nested internal-label self-branching positives for `return` and `unreachable`; `[O4Z-AUDIT-CF-I]` now descends into `try` / `try_table` bodies only for non-terminal `if` arm suffix folding, keeps simple and nested `try_table` body-local `if` suffix positives plus terminal/block-exit bailout shapes, classifies an explicit outer-`catch_all` `try_table` terminal-tail bailout as matching Binaryen, and records the local plain-`try` text-surface blocker; `[O4Z-AUDIT-CF-J]` now has a local root-anchored fixpoint loop plus a small late-neighborhood helper-label fixture. Validation is green at `moon test src/passes` (`1637/1637`), full `moon test` (`4822/4822`), and a native direct 1000-case compare (`998` normalized matches, `0` mismatches, `2` `binaryen-rec-group-zero` command failures); the prior pass-local timing lane remained within the <=2x floor but was not refreshed for this coverage batch. `[O4Z-AUDIT-CF]` is still not complete because Binaryen behavior parity requires remaining exact `if` caveats, arbitrary terminating-tail subsets beyond root-anchored groups, broader branch/control-bearing movement, EH repair or exact folded/bailout classification, exact helper cost/fixpoint parity, 10000-case compare, and generated late-neighborhood evidence now tracked in `agent-todo.md`.
