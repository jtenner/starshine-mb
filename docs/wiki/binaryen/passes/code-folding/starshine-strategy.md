---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - ../../../raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md
  - ../../../raw/research/0522-2026-05-06-code-folding-direct-revalidation.md
  - ../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md
  - ../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md
  - ../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md
  - ../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md
  - ../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../merge-blocks/index.md
  - ../remove-unused-brs/index.md
  - ../remove-unused-names/index.md
  - ../rse/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./terminating-tails.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../merge-blocks/index.md
  - ../remove-unused-brs/index.md
  - ../remove-unused-names/index.md
  - ../rse/index.md
---

# Starshine Strategy For `code-folding`

Use this page together with the tagged raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md), the 2026-05-05 current-main bridge in [`../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md), the focused port-readiness source manifest in [`../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md), the owner/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), and the implementation-readiness ladder in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`code-folding` is now an active Starshine HOT pass with owner file `src/passes/code_folding.mbt`, focused tests in `src/passes/code_folding_test.mbt`, registry coverage, and a dispatcher arm.

The active implementation is still a narrowed direct-pass subset, not the full Binaryen tail-sharing surface. It now covers void and typed/value `if`-arm suffix hoisting, one-block/one-non-block `if` value-suffix hoisting including both multi-root orientations, and two-unnamed-block `if` value-suffix hoisting, the simple full-value non-block `if` no-op boundary, adjacent no-else `if` plus fallthrough empty-payload `return`/`unreachable` terminal-tail sharing, a root-anchored helper-label terminating-tail subset for non-adjacent `return`, block-backed `unreachable`, typed-result direct `return_call`, `return_call_indirect`, and core-built `return_call_ref` tails, a local fixpoint loop over that current root-anchored model, branch-free structured suffix hoisting, branch-to-outer-label full-tail hoisting, narrow nested internal-label self-branching suffix sharing for `return`, `unreachable`, `return_call`, `return_call_indirect`, and `return_call_ref`, unprofitable full-void `if` skips, conservative full-`if` terminal suffix sharing for empty-payload `return` / `unreachable` endings, conservative void block-exit/fallthrough tail hoisting, single-result typed block-exit plain-`br` payload sharing with matching fallthrough or other branch payloads, single-result multi-root named-block suffix sharing before the final branch/fallthrough value root, first multi-value branch-plus-fallthrough and branch-only/unreachable-fallback payload suffixes, branch-payload embedded block-exit hoisting, a HOT-level `if` unreachable-condition bailout, tested `br_table` / outside-target / careful-switch negatives, narrow non-terminal `if` suffix folding inside `try` / `try_table` bodies with simple and nested `try_table` text coverage, conservative EH boundary bailouts including outer-`catch_all` and `catch_all_ref` terminal-tail bailouts matched to Binaryen, and a small exiting dead-value block cleanup family. It also guards against moving live-label blocks or deleting trailing `unreachable` sentinels that typed result regions still need. Broader Binaryen helper-block shaping, broader multi-value branch-payload suffix splitting, remaining exact `if` caveats, arbitrary non-root function-ending helper-label subsets, broad branch/control-bearing suffix movement, exact helper cost/fixpoint parity, and EH repair remain future work only when a new semantic, validity, or proven downstream code-size blocker justifies them.

On 2026-05-10, direct `code-folding` was accepted for v0.1.0 under the repo pass criteria. The refreshed direct lane for `--pass code-folding` at `.tmp/pass-fuzz-code-folding-cf002-terminal-if` reported `6759/10000` compared cases, `6759` normalized matches, `0` semantic mismatches, and `20` Binaryen empty-recursion-group command failures after adding conservative full-`if` terminal suffix sharing. The debug artifact `--code-folding` command still differs first at `defined=220 abs=237`, but Starshine now shares the repeated `call $28(local.get $6)` branch-exit tails inside the value-carrying branch payload. A reduced helper-wrapper fixture added in `src/passes/code_folding_test.mbt` shows Binaryen and Starshine both reduce six duplicated `$sink` calls to four calls while keeping different wrapper placement; in the artifact function both outputs have three `call $28(local.get $6)` sites and sixteen total `call $28` sites, and Starshine's focused WAT is smaller (`21687` bytes vs Binaryen's `22085`). The remaining inspected `defined=220 abs=237` diff is therefore classified as representation/helper-wrapper drift, not a current code-quality blocker. The latest direct replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1680352` reports `334.711ms` Starshine pass-local time vs `176.295ms` Binaryen, still inside the repo speed floor (`starshine_time <= 2 * binaryen_time`). The focused late cleanup replay `code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names` at `.tmp/cf002-late-cleanup-artifact` remains red at `defined=29 abs=46`, but the no-CF cleanup baseline at `.tmp/cf002-late-cleanup-without-cf-artifact` has the same first diff and byte-identical focused diff files, so that replay did not expose a code-folding-specific downstream blocker.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- active pass owner
  - `src/passes/code_folding.mbt`
    - descriptor, summary, structural equality including logical call-signature comparison, suffix movement guards, typed/value `if` suffix logic, one-block/one-non-block and two-unnamed-block `if` suffix logic, adjacent no-else `if`/fallthrough terminal-tail helper block logic, root-anchored terminating-tail helper-label candidate selection/rewrite logic with local fixpoint reruns, narrow EH-body `if` suffix folding, simple and nested `try_table` text coverage, conservative EH boundary bailouts including checked `catch_all_ref` terminal tails, conservative block-exit/fallthrough suffix logic, explicit named-block value-exit candidate provenance, typed block-exit payload, multi-root suffix, and first multi-value payload suffix sharing, mutation helpers, and run function for the current narrowed HOT subset
- focused direct tests
  - `src/passes/code_folding_test.mbt`
    - identical void and typed/value if-arm suffix hoists, one-block/one-non-block `if` value-suffix hoists including both multi-root orientations, and two-unnamed-block `if` value-suffix hoists, the simple full-value non-block `if` no-op, adjacent no-else `if` plus fallthrough `return`/`unreachable` terminal-tail positives, root-anchored non-adjacent `return`, block-backed `unreachable`, typed-result direct `return_call`, `return_call_indirect`, and core-built `return_call_ref` positives, root-anchored terminating-tail fixpoint coverage, late-neighborhood helper-label coverage, structured suffix hoists, outer-branch full-tail hoists, nested internal-label self-branching suffix sharing for `return`, `unreachable`, `return_call`, `return_call_indirect`, and `return_call_ref`, crossed nested-label direct/indirect tail-call guards, unprofitable full-void if skips, block-exit/fallthrough and branch-payload suffix hoists, typed block-exit branch-payload positives with and without fallthrough, typed block-exit multi-root suffix positives with and without fallthrough, the first multi-value branch-plus-fallthrough and branch-only/unreachable-fallback payload suffix positives, full-`if` terminal suffix sharing for `return` and `unreachable`, unsupported `br_on_null`, `br_if`, and `br_table` poison negatives, outside-target/switch-scope movement negatives, simple and nested non-terminal `try_table` body `if` suffix positives, conservative `try_table` EH bailout negatives including the outer-`catch_all` and `catch_all_ref` terminal-tail shapes, live-label block and `if`-suffix safety, result-region `unreachable` safety, and exiting dead-value block flattening coverage
- active registry and dispatcher status
  - `src/passes/optimize.mbt`
    - `code-folding` is a hot-pass registry entry, not a removed-name placeholder
  - `src/passes/pass_manager.mbt`
    - dispatches `"code-folding"` through `code_folding_run(ctx, func)`
- preset caution
  - `src/passes/optimize.mbt`
    - public `optimize` / `shrink` preset expansion still needs exact late-slot proof before broader claims
- CLI spelling and pass-flag preservation proof
  - `src/cli/cli_test.mbt`
    - long-form kebab-case pass flags and explicit pass-token order stay stable
- backlog and delivery plan
  - `agent-todo.md`
    - direct `code-folding` / `[CF]002` is accepted; future work is limited to new semantic/validity blockers, proven downstream code-size blockers, or preset-scheduling evidence
- canonical scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - the late-cluster slot where `code-folding` belongs before `merge-blocks`
- surrounding implemented Starshine cleanup consumers
  - `docs/wiki/binaryen/passes/merge-blocks/index.md`
  - `docs/wiki/binaryen/passes/remove-unused-brs/index.md`
  - `docs/wiki/binaryen/passes/remove-unused-names/index.md`
  - `docs/wiki/binaryen/passes/rse/index.md`

That code-and-doc map, plus [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), lets readers jump directly from the upstream algorithm to exact local status, official test families, and the future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `code-folding` is deliberately active but narrow.

### 1. The pass has a real owner and dispatch path

`src/passes/code_folding.mbt` owns the HOT descriptor and transform. `src/passes/optimize.mbt` registers `code-folding` as a hot pass, and `src/passes/pass_manager.mbt` dispatches active requests through `code_folding_run(ctx, func)`.

### 2. The reduced behavior is protected by focused tests

`src/passes/code_folding_test.mbt` covers the current reduced surface:

- identical void `if`-arm suffixes are hoisted once
- profitable identical full void arms collapse to condition evaluation plus one shared suffix, while tiny unprofitable full-void arms stay in place like Binaryen
- typed/value `if` suffixes can be hoisted when the moved suffix provides the original result, including the exact partial non-block value-arm lit/doc shape, a safe one-block/one-non-block arm shape in either orientation, and a source-backed two-unnamed-block value-arm shape with unique prefixes sharing the final value root; simple full-value non-block arms remain a no-op for this pass and are left to `optimize-instructions`
- branch-free structured suffixes can be hoisted through alpha-equivalent unused labels
- full tails ending in a branch to an outer live label can be hoisted safely
- full `if` arms ending in empty-payload `return` or `unreachable` share one terminal suffix
- adjacent no-else `if` then-tails and immediate fallthrough tails ending in empty-payload `return` or `unreachable` can share one terminal suffix through a fresh void wrapper block label
- root-anchored non-adjacent `return`, block-backed `unreachable`, typed-result direct `return_call`, `return_call_indirect`, and core-built `return_call_ref` tails can share a deepest profitable suffix through a fresh wrapper label when the selected group includes the original function-ending tail, including narrow nested internal-label self-branching suffix cases for `return`, `unreachable`, `return_call`, `return_call_indirect`, and `return_call_ref` plus crossed-label negatives through direct and indirect tail calls that keep inner-target and outer-target branches distinct and a tail-call operand-only profitability guard, and the current local root-anchored model reruns to fixpoint
- a conservative named block-exit tail shared by branch exits and fallthrough can be hoisted after the block
- typed named-block exits can share a matching plain-`br` payload with the fallthrough value or with other matching branch payloads, can share matching void/effectful roots immediately before the final value root, and now cover one multi-value branch-plus-fallthrough payload suffix plus a branch-only/unreachable-fallback variant
- unsupported `br_on_null`, `br_if`, and `br_table` traffic to the same label poisons block-exit folding instead of being silently merged with plain `br` tails
- live-label exiting blocks, outside-target switch-like tails, crossed nested-label branches, careful switch scopes, and structured `if` suffixes are not flattened or hoisted out from under their branch targets
- `try` / `try_table` bodies are only visited for ordinary non-terminal `if` suffix folding; simple and nested `try_table` body-local positives are covered for the current catch kinds, exact text-level plain `try` coverage is blocked by local WAT lowering, EH block-exit, terminal-tail, movement, and repair shapes remain conservative bailouts, the explicit outer-`catch_all` and `catch_all_ref` `try_table` terminal-tail bailouts were checked against Binaryen version 129 (`version_129`), and a throwing-body `catch_all_ref` body-local positive remains open because Binaryen folds it but Starshine does not yet
- result-region trailing `unreachable` sentinels are preserved when they still provide the required bottom-typed result
- an exiting dead-value block shape is flattened without duplicating unreachable residue

### 3. Direct oracle and timing evidence

The 2026-05-10 revalidation lane ran `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass code-folding --max-failures 20 --out-dir .tmp/pass-fuzz-code-folding-cf002-terminal-if` after the standard Moon signoff from the implementation thread.
It produced zero semantic mismatches across all compared cases and kept direct debug-artifact pass-local timing inside the <=2x Binaryen floor. The June 4 typed block-exit payload widening has a baseline smoke at `.tmp/pass-fuzz-code-folding-audit-1000`: `998/1000` compared cases, `998` normalized matches, `0` mismatches, and `2` command failures, plus debug-WASI pass-local timing at `.tmp/code-folding-audit-self-compare` (`172.276ms` Starshine vs `169.576ms` Binaryen, within the <=2x floor). The follow-up multi-root named-block widening smoke at `.tmp/pass-fuzz-code-folding-bd-1000` is also green (`998/1000` compared, `998` normalized matches, `0` mismatches, `2` `binaryen-rec-group-zero` command failures), with debug-WASI pass-local timing at `.tmp/code-folding-bd-self-compare` (`196.213ms` Starshine vs `187.281ms` Binaryen, within the <=2x floor). The one-block/one-non-block `if` widening smoke at `.tmp/pass-fuzz-code-folding-e-1000` is green (`998/1000` compared, `998` normalized matches, `0` mismatches, `2` `binaryen-rec-group-zero` command failures), with debug-WASI pass-local timing at `.tmp/code-folding-e-self-compare` (`208.362ms` Starshine vs `185.945ms` Binaryen, within the <=2x floor). The adjacent `return`/`unreachable` terminal-tail smoke at `.tmp/pass-fuzz-code-folding-f-1000` is green (`998/1000` compared, `998` normalized matches, `0` mismatches, `2` `binaryen-rec-group-zero` command failures), with debug-WASI pass-local timing at `.tmp/code-folding-f-self-compare` (`187.189ms` Starshine vs `198.305ms` Binaryen). The root-anchored `return` / `unreachable` / `return_call*` terminal-tail smoke at `.tmp/pass-fuzz-code-folding-fg-1000` is green (`998/1000` compared, `998` normalized matches, `0` mismatches, `2` `binaryen-rec-group-zero` command failures), with debug-WASI pass-local timing at `.tmp/code-folding-fg-self-compare` (`210.383ms` Starshine vs `187.861ms` Binaryen, within the <=2x floor). The H/I/J movement-safety, EH-bailout, and local-fixpoint smoke at `.tmp/pass-fuzz-code-folding-hij-1000` is green (`998/1000` compared, `998` normalized matches, `0` mismatches, `2` `binaryen-rec-group-zero` command failures), with debug-WASI pass-local timing at `.tmp/code-folding-hij-self-compare` (`231.629ms` Starshine vs `195.691ms` Binaryen, within the <=2x floor). Full 10000-case compare and generated late-slot evidence remain open before audit closeout.

### 4. Direct signoff is accepted; broader parity is conditional future work

`agent-todo.md` no longer keeps a v0.1.0 direct `code-folding` blocker open. The remaining known direct artifact diff is classified representation drift, and the focused late cleanup replay did not move the first diff when `code-folding` was added to the cleanup baseline.

Future broadening should be demand-driven:

- broader expression-exit helper-block sharing or additional multi-value branch-payload suffix splitting only when it proves a real shrink/correctness gap beyond the currently classified `defined=220 abs=237` helper-wrapper representation drift and the June typed-payload / multi-root / first multi-value suffix widening
- broader function-ending tail coverage beyond the covered root-anchored subset only when a semantic, validity, or artifact-size blocker requires it
- late-pipeline / preset scheduling only after the surrounding cleanup path is representable and oracle-proven

## The right next Starshine implementation shape

The current implementation and neighboring passes still suggest that expanded `code-folding` work should remain a **late-cluster HOT rewrite family**, not become an isolated generic optimizer.

Why:

- Binaryen runs it late
- the pass can add helper structure
- later cleanup passes are expected to simplify that helper structure again
- Starshine already has active late-cluster cleanup passes in exactly that neighborhood

So the local strategy should be thought of as:

1. identify a HOT-level representation of the two upstream families
   - expression-exit tail sharing
   - function-terminating tail sharing
2. prove the same movement-safety boundaries locally
   - branch-target scope
   - EH-sensitive movement
   - no silent broadening to unsupported branch forms
3. rely on existing late-cluster Starshine neighbors to consume the helper structure
   - `merge-blocks`
   - `remove-unused-brs`
   - `remove-unused-names`
   - later `rse`

In other words, future expansion should stay slotted into the local cleanup ecosystem that already exists.

## The most important local dependency map

### Upstream `code-folding` output would feed directly into local `merge-blocks`

See [`../merge-blocks/index.md`](../merge-blocks/index.md).

Why it matters locally:

- Binaryen `code-folding` may add helper blocks
- Starshine already has an active late `merge-blocks` pass that exists to flatten branch-free wrappers and expose simpler shapes downstream

So future Starshine `code-folding` expansion should preserve that cleanup handoff instead of trying to do every structural simplification itself.

### It would also create work for local `remove-unused-brs`

See [`../remove-unused-brs/index.md`](../remove-unused-brs/index.md).

Why:

- upstream `code-folding` often rewrites duplicate tails into branch traffic toward a shared suffix
- late branch cleanup is therefore part of the intended payoff, not an accidental afterthought

Future local expansion should keep that relationship explicit.

### It also interacts with local `remove-unused-names`

See [`../remove-unused-names/index.md`](../remove-unused-names/index.md).

Why:

- helper labels and old labels can become redundant after tail sharing
- Binaryen already relies on late name cleanup in the same neighborhood
- Starshine's implemented local label-cleanup pass is therefore part of the practical port boundary

### Late `rse` is part of the payoff story too

See [`../rse/index.md`](../rse/index.md).

Why:

- once a single shared tail exists, later local redundancy cleanup has a clearer single-copy shape to analyze
- that makes `code-folding` more than a standalone size transform in the scheduler story

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine still does **not** have:

- full branch-tail candidate collection for duplicate block-exit traffic beyond the covered void tails and single-result plain-`br` payload roots
- local branch-scope movement analysis broad enough for Binaryen's full expression-exit family
- the full Binaryen function-ending helper-label tail-sharing rewriter for arbitrary non-root subsets, branch/control-bearing suffixes, and exact helper cost/fixpoint parity beyond the covered root-anchored subset
- EH movement / nested-pop repair support for this pass; EH bodies are only partially visited for non-terminal `if` suffix folding
- generated artifact proof for the exact late no-DWARF `code-folding` slot

So the current repo status is best summarized as:

- active narrow HOT transform
- focused tests and dispatcher wiring
- prior 10000-case direct fuzz parity evidence plus June 1000-case smokes after the typed-payload, `if`, adjacent terminal-tail, root-anchored terminal-tail, and H/I/J movement-safety/EH/fixpoint batches
- scheduler slot documented
- neighboring consumers implemented
- broader late-slot and artifact proof still open

## Validation plan for future expansion

The dedicated port-readiness page owns the detailed test-first ladder: [`./starshine-port-readiness-and-validation.md#validation-ladder`](./starshine-port-readiness-and-validation.md#validation-ladder).
The short version is still:

The existing backlog plus neighboring pass docs imply the right validation ladder.
Future expansion should validate in this order:

1. reduced shape tests for the two upstream families
   - named block-exit tails
   - unnamed foldable `if`-arm tails
   - terminating `return` / `return_call*` / `unreachable` tails
2. negative movement-safety tests
   - outer break-target scope hazards
   - unsupported branch-form poison cases
   - EH-sensitive movement barriers
3. late-cluster interaction tests
   - `code-folding -> merge-blocks`
   - `code-folding -> remove-unused-brs`
   - `code-folding -> remove-unused-names`
4. artifact and oracle comparison
   - the `CF` slice in `agent-todo.md`
   - the canonical no-DWARF debug-artifact replay path

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow.

## Bottom line

Current Starshine `code-folding` strategy is an accepted direct HOT pass plus conditional future broadening:

- the pass has `src/passes/code_folding.mbt` ownership, registry wiring, dispatcher routing, and focused tests
- the 2026-05-10 direct compare lane is green with zero semantic mismatches and pass-local timing inside the <=2x Binaryen floor; the June typed block-exit, `if`, adjacent terminal-tail, root-anchored terminal-tail, and H/I/J movement-safety/EH/fixpoint batches have green 1000-case smoke/timing lanes but still need 10000-case closeout before final parity claims
- the direct artifact `defined=220 abs=237` helper-wrapper diff is accepted representation drift
- the focused cleanup replay did not expose a `code-folding`-specific downstream blocker because the same `defined=29 abs=46` diff appears without `code-folding`
- the canonical slot is documented in the no-DWARF optimizer notes, but public preset scheduling still needs separate ordered-path proof

So the right mental model today is:

- **accepted direct transform**
- **accepted prior direct parity and timing evidence, plus green June smoke/timing for the widened slice**
- **clear slot in the pipeline**
- **broader expression-exit / function-ending work only if future evidence needs it**

## Sources

- [`../../../raw/research/0522-2026-05-06-code-folding-direct-revalidation.md`](../../../raw/research/0522-2026-05-06-code-folding-direct-revalidation.md)
- [`../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md)
- [`../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md`](../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md)
- [`../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md)
- [`../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md`](../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md)
- [`../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md`](../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md)
- [`../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md`](../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/code_folding.mbt`](../../../../../src/passes/code_folding.mbt)
- [`../../../../../src/passes/code_folding_test.mbt`](../../../../../src/passes/code_folding_test.mbt)
- [`../../../../../src/cli/cli_test.mbt`](../../../../../src/cli/cli_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
