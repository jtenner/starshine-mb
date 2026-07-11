# Binaryen `code-folding` terminating-tail performance recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source reconciliation for `docs/wiki/binaryen/passes/code-folding/`

## Why this capture exists

The living `code-folding` pages accurately described the pass's semantic tail-sharing contract, but they compressed the terminating-tail search into a simple recursive hash-and-equality loop. That omission matters to future ports: the upstream algorithm contains explicit per-fixpoint caching and lazy whole-function analysis so recursive subset search does not repeatedly rescan the same control-flow facts.

This capture supplements, rather than edits, the 2026-04-22 tagged provenance and the 2026-05-05 current-main freshness bridge. The older bridge's conclusion that no *semantic* teaching drift was found remains compatible with this note: the newly documented facts explain the released/current implementation's performance structure, not a new transform family.

## Primary sources reread

### Upstream Binaryen

- Current `main` owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodeFolding.cpp>
- Current `main` focused fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-folding.wast>
- Current `main` registration/scheduling surface: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Released comparison owner: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/CodeFolding.cpp>
- Binaryen `version_130` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_130>

## Durable findings

### 1. The release and current owner share the reviewed structure

The reviewed `version_130` and current-main `CodeFolding.cpp` owner files have the same teaching-relevant terminating-tail machinery. This is a narrow source comparison, not a claim about every commit or every unreviewed option interaction.

The existing semantic contract remains unchanged:

- `return`, `return_call*`, and `unreachable` tails are a distinct function-ending family;
- the search explores deeper equal suffixes before accepting a shallower profitable subset;
- moved items with exiting branch targets are rejected before they become candidates;
- actual equality still uses `ExpressionAnalyzer::equal(...)` after hashing;
- profitability still includes helper-branch/block cost; and
- a successful rewrite restarts the per-function fixpoint and may require EH nested-pop repair.

### 2. Exiting-branch detection is cached per fixpoint iteration

The terminating-tail filter uses `hasExitingBranches(newItem)` before recursive subset grouping. The owner does not rerun an independent whole-subtree branch walk for every query:

1. `exitingBranchCache` stores only queried expression roots.
2. `populateExitingBranchCache(...)` walks a previously uncached root bottom-up.
3. It collects scope-name uses from children, removes names defined by the current expression, and preserves only the root's resulting set.
4. A nested root already in the cache is skipped and its cached result is merged exactly.
5. The cache is cleared after each successful/unsuccessful walk iteration, together with the candidate and modified-node state.

The cache is a search-cost optimization, **not** a legality shortcut. The semantic check still rejects a candidate if it exits a scope that will not remain valid after moving.

### 3. Whole-function branch targets are lazy and shared through recursion

`optimizeTerminatingTails(...)` accepts an optional `bodyTargets` set. It computes `BranchUtils::getBranchTargets(getFunction()->body)` only at the first recursive point that needs a profitability/movement decision, then passes the same set to deeper calls.

That matters because `canMove(items, functionBody, bodyTargets)` otherwise needs an `O(N)` branch-target scan of the function body for multiple candidate subsets. The upstream algorithm therefore separates:

- per-candidate exiting-branch filtering (cached by expression root); from
- branch targets defined anywhere in the function body (one lazy analysis per recursive terminating-tail search).

The set is scoped to one invocation chain and naturally becomes invalid after a rewrite, because the pass restarts the function walk instead of reusing it across iterations.

### 4. Deterministic subset exploration is intentional

Candidates are first bucketed by `ExpressionAnalyzer::hash(...)`, then validated with `ExpressionAnalyzer::equal(...)`. The owner does not iterate the hash map directly to choose buckets. It walks the original tail order with a `seen` set, so each digest is explored once in insertion order.

This gives stable choice order when several equal subsets are available. It does **not** make the heuristic globally optimal, and a hash never proves equality.

### 5. Porting implication: preserve the invariants before copying the caches

A future broad Starshine terminating-tail port should first prove the semantic boundaries—replacement-site provenance, exact structural equality, branch-target scope, EH movement, helper cost, and post-rewrite verification. Only after profiling identifies repeated candidate scans should it introduce a revision-scoped cache analogous to Binaryen's:

- invalidate it on every HOT mutation or whole-function rewrite;
- cache a sound summary of *exiting* targets, not merely all branch targets;
- keep exact equality and scope checks as independent proofs; and
- measure large tail-set functions before claiming a pass-local performance win.

Current Starshine's documented terminating-tail subset is root-anchored and narrower than Binaryen's arbitrary subset search, so this source structure is a future implementation map rather than evidence that the local pass already needs or has these caches.

## Sources to update

Use this capture for current/released source claims about terminating-tail search cost structure. Keep the older raw captures for original tagged provenance and the dated 2026-05-05 source review.
