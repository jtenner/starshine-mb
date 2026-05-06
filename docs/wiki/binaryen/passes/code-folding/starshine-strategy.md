---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
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

The active implementation is still a narrow direct-pass subset, not the full Binaryen tail-sharing surface. It currently focuses on void `if`-arm suffix hoisting / identical full-arm cleanup and a small exiting dead-value block flattening family; broader branchy tails, function-ending helper-label sharing, EH movement, and exact late-slot artifact replay remain `[CF]002` follow-up work.

On 2026-05-06, the refreshed direct lane for `--pass code-folding` reported `6759/10000` compared cases, `6759` normalized matches, `0` semantic mismatches, and `20` Binaryen empty-recursion-group command failures; see [`../../../raw/research/0522-2026-05-06-code-folding-direct-revalidation.md`](../../../raw/research/0522-2026-05-06-code-folding-direct-revalidation.md).

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- active pass owner
  - `src/passes/code_folding.mbt`
    - descriptor, summary, structural equality, void-tail candidate logic, mutation helpers, and run function for the current narrow HOT subset
- focused direct tests
  - `src/passes/code_folding_test.mbt`
    - identical if-arm suffix hoist, identical full void arm cleanup, value-if bailout, and exiting dead-value block flattening coverage
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
    - `[CF]002` remains the late-slot regression and artifact-compare follow-up
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
- identical full void arms collapse to condition evaluation plus one shared suffix
- value-producing `if` arms stay unchanged
- an exiting dead-value block shape is flattened without duplicating unreachable residue

### 3. The direct oracle lane is fresh

The 2026-05-06 revalidation lane ran the standard Moon signoff plus `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass code-folding --out-dir .tmp/pass-fuzz-code-folding`.
It produced zero semantic mismatches across all compared cases.

### 4. The broader parity slice remains real work

`agent-todo.md` still keeps `[CF]002` open because direct parity evidence does not prove the exact late-slot neighborhood or artifact lane. The remaining deliverables are framed around the right upstream concerns:

- branchy and structured-control tail coverage
- typed/value `if` folding decisions
- late-pipeline slot replay around neighboring cleanup passes
- debug-artifact `--code-folding` parity evidence

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

- broad branch-tail candidate collection for duplicate block-exit traffic
- local branch-scope movement analysis broad enough for Binaryen's full expression-exit family
- a function-ending helper-label tail-sharing rewriter
- EH movement / nested-pop repair support for this pass
- artifact proof for the exact late no-DWARF `code-folding` slot

So the current repo status is best summarized as:

- active narrow HOT transform
- focused tests and dispatcher wiring
- fresh direct fuzz parity evidence
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

Current Starshine `code-folding` strategy is an active narrow HOT pass plus explicit late-slot follow-up:

- the pass has `src/passes/code_folding.mbt` ownership, registry wiring, dispatcher routing, and focused tests
- the 2026-05-06 direct compare lane is green with zero semantic mismatches
- the backlog still treats broader Binaryen coverage as a real late-parity slice under `[CF]002`
- the canonical slot is already documented in the no-DWARF optimizer notes
- the surrounding implemented cleanup passes already exist and define the practical landing zone for future expansion

So the right mental model today is:

- **active direct transform**
- **fresh direct parity evidence**
- **clear slot in the pipeline**
- **broader branchy/artifact proof still open**

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
