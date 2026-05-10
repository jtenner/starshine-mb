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
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./terminating-tails.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/ir/hot_builders.mbt
  - ../../../../../src/ir/hot_region_edit.mbt
  - ../../../../../src/ir/hot_query.mbt
  - ../../../../../src/ir/hot_side_tables.mbt
  - ../../../../../src/ir/hot_labels.mbt
  - ../../../../../src/ir/hot_verify.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./terminating-tails.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../merge-blocks/index.md
  - ../remove-unused-brs/index.md
  - ../remove-unused-names/index.md
  - ../rse/index.md
---

# Starshine `code-folding` port readiness and validation

This page is the practical bridge from the source-backed Binaryen dossier to a future Starshine implementation.
Read it after:

- [`./binaryen-strategy.md`](./binaryen-strategy.md) for the upstream algorithm
- [`./wat-shapes.md`](./wat-shapes.md) for before/after examples
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for upstream owner/test surfaces and current local status
- [`./starshine-strategy.md`](./starshine-strategy.md) for the high-level Starshine status map

## Current local starting point

`code-folding` is active in Starshine as a narrowed HOT direct pass. It has an owner file, focused tests, registry entry, and `pass_manager` dispatcher arm. Its v0.1.0 direct-pass signoff is accepted under the repo criteria; it does **not** yet have full Binaryen coverage or public preset-slot proof.

The local surfaces that already exist are active implementation and planning surfaces:

| Surface | Location | What it proves |
| --- | --- | --- |
| Active owner | `src/passes/code_folding.mbt` | `code-folding` has a real HOT descriptor and transform for the current narrow subset. |
| Focused tests | `src/passes/code_folding_test.mbt` | current void-tail positives and bailouts are regression-protected. |
| Registry entry | `src/passes/optimize.mbt` | `code-folding` is an active hot pass, not a removed-name placeholder. |
| Dispatcher arm | `src/passes/pass_manager.mbt` | active requests dispatch to `code_folding_run(ctx, func)`. |
| CLI spelling preservation | `src/cli/cli_test.mbt` | `--code-folding` parses and explicit pass-token order is stable. |
| Direct revalidation | `.tmp/pass-fuzz-code-folding-cf002-terminal-if`, `docs/wiki/raw/research/0522-2026-05-06-code-folding-direct-revalidation.md` | refreshed harness lane had `6759` normalized matches and `0` semantic mismatches; direct debug-artifact timing stayed inside the <=2x Binaryen floor. |
| Backlog slice | `agent-todo.md` | direct `[CF]002` is accepted; future work is limited to new semantic/validity blockers, proven downstream code-size blockers, or preset-scheduling evidence. |
| Canonical late slot | `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` | the pass belongs immediately before the late `merge-blocks` cluster in the no-DWARF function phase. |

## Remaining Starshine slice order

Further parity work should stay staged. Binaryen's source contract is broader than the already-landed narrow local patch.

### Completed slice: narrow void `if`-arm fold positives

The current owner file and tests cover a conservative subset of the expression-exit family:

- identical void `if`-arm suffix hoisting
- identical full void-arm cleanup
- value-producing `if` bailout
- small exiting dead-value block flattening cleanup

### Next slice: broader expression-exit fold positives with hard bailouts

Continue with the broader expression-exit family from [`./binaryen-strategy.md`](./binaryen-strategy.md):

- unnamed `if` arm duplicate suffixes
- named-block plain-`br` tails to the same exit
- branch-payload plus fallthrough suffixes where target scope is obviously preserved

Keep these first-slice bailouts explicit:

- any unsupported branch family beyond plain `br`
- any `br_table`, `br_if`, `br_on_*`, `delegate`, `try`, `try_table`, `throw`, or `pop` shape until the movement proof is local and tested
- any candidate whose branch target is not still in scope after the proposed move
- any multi-result or refined-reference shape whose outer type cannot be reverified immediately
- any case that needs a fresh helper label at the end of the function body

This next slice should remain narrower than Binaryen until the local candidate, equality, movement-safety, mutation, and tests are proven for branch-bearing tails.

### Slice 2: source-backed negative gates

Add the official negative families before adding more positives:

- unsupported branch-form label poisoning
- outside-target branch bailout
- equal-looking but unsafe switch / table-tail cases
- unreachable-condition `if` contexts that DCE should handle instead
- refined-result / typed-block preservation checks

These are correctness tests. They should fail before implementation, not be added as telemetry after a broad rewrite.

### Slice 3: terminating-tail helper-label sharing

Only after the expression-exit substrate is green, add the dedicated terminating-tail family from [`./terminating-tails.md`](./terminating-tails.md):

- `return`
- `return_call`
- `return_call_indirect`
- `return_call_ref`
- `unreachable`

This is a separate implementation slice because it needs:

- subset grouping instead of all-tails-or-nothing matching
- deeper common-suffix search before shallower search
- fresh helper-label creation
- old-body fallthrough prevention
- direct root replacement for root-level terminators, not just block-backed tail edits

### Slice 4: EH and broad movement safety

Do not mix EH movement into the first green port.
Binaryen's source has conservative `pop` / throwing-through-`try` barriers plus nested-pop repair after block-adding rewrites.
A local port should initially bail out on EH-sensitive shapes unless it also proves:

- HOT lift exposes enough catch / `try_table` ownership to detect the same hazards
- HOT lower/writeback preserves the repaired shape
- focused EH tests cover both accepted and rejected movement

## Local implementation substrate

The nearest reusable Starshine APIs today are these.

| Need | Current local files | Notes |
| --- | --- | --- |
| Build helper blocks, `if`s, branches, returns, and unreachable markers | `src/ir/hot_builders.mbt:171-182`, `src/ir/hot_builders.mbt:366-397`, `src/ir/hot_builders.mbt:476-514`, `src/ir/hot_builders.mbt:718-766` | Enough to construct the first expression-exit and later terminating-tail output shapes. |
| Identify and mutate regions | `src/ir/hot_region_edit.mbt:119-312` | Region refs, root reads, inserts, removes, splices, and body replacement are the likely mutation substrate. |
| Recognize simple block / `if` roots and split branch tails | `src/ir/hot_query.mbt:181-303` | Existing helpers already expose simple live-root and trailing plain-branch forms used by neighboring cleanup passes. |
| Query branch targets and branch tables | `src/ir/hot_query.mbt:501-523`, `src/ir/hot_side_tables.mbt:123-145` | First slice should use plain branch targets and treat branch tables as poisoning / bailout shapes. |
| Track labels and branch arity | `src/ir/hot_labels.mbt:19-59` | A faithful port must preserve label owners, result types, and branch payload arity. |
| Verify branch target validity | `src/ir/hot_verify.mbt:113-145`, `src/ir/hot_verify.mbt:408-468` | Use this as a post-rewrite guard; do not rely on shape intuition alone. |
| Extend active pass | `src/passes/code_folding.mbt`, `src/passes/optimize.mbt`, `src/passes/pass_manager.mbt` | The owner, registry entry, and dispatcher already exist; future work should extend the active pass with tests first. |

## Candidate model to keep concrete

Before writing broad equality code, model a candidate tail as data with explicit provenance:

- owning region or root pointer
- tail root sequence
- whether the tail ends in branch, fallthrough, or terminator
- target label, if any
- branch payload roots, if any
- type / arity expectation at the shared exit
- movement-safety proof state
- profitability score

This avoids the common over-broad implementation mistake: comparing two root arrays, finding them equal, and moving them without knowing why the move is legal.

## Validation ladder

Use a strict test-first ladder.

### Reduced tests first

Seed a future `src/passes/code_folding_test.mbt` from Binaryen's dedicated `code-folding.wast` proof families:

1. identical unnamed `if` arm blocks fold to a shared suffix
2. partially shared `if` arm suffixes fold while preserving the unique prefix
3. named arm blocks stay untouched
4. plain branch-value tails to one named exit share only the payload suffix
5. branch-plus-fallthrough tails share the suffix
6. `br_on_*` / unsupported branch forms poison label folding
7. outside-target branches block movement
8. refined-result and typed-block contexts still validate

### Then add terminating-tail tests

After slice 1 is green, add:

1. duplicate `return` suffixes produce one shared function-ending suffix
2. duplicate `unreachable` suffixes share safely
3. `return_call*` belongs to the same family
4. old-body fallthrough cannot accidentally execute the shared suffix
5. root-level terminators are rewritten correctly, not only block-backed ones

### Then add neighborhood tests

Because Binaryen intentionally schedules `code-folding` before late cleanup, validate the local handoff:

- `code-folding -> merge-blocks`
- `code-folding -> remove-unused-brs`
- `code-folding -> remove-unused-names`
- `code-folding -> rse`

The neighboring living dossiers are:

- [`../merge-blocks/index.md`](../merge-blocks/index.md)
- [`../remove-unused-brs/index.md`](../remove-unused-brs/index.md)
- [`../remove-unused-names/index.md`](../remove-unused-names/index.md)
- [`../rse/index.md`](../rse/index.md)

### Final parity signoff

The refreshed direct lane is current as of 2026-05-10:

- implementation-thread signoff: `moon info`, `moon fmt`, `moon test`
- latest direct fuzz: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass code-folding --max-failures 20 --out-dir .tmp/pass-fuzz-code-folding-cf002-terminal-if`
- result: `6759/10000` compared cases, `6759` normalized matches, `0` semantic mismatches, `20` Binaryen empty-recursion-group command failures
- direct artifact replay: `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1680352`, first diff `defined=220 abs=237`, classified representation drift, `334.711ms` Starshine pass time vs `176.295ms` Binaryen
- late cleanup replay: `.tmp/cf002-late-cleanup-artifact`, first diff `defined=29 abs=46`, same focused diff files as the no-CF baseline `.tmp/cf002-late-cleanup-without-cf-artifact`

Direct `[CF]002` signoff is accepted as of 2026-05-10. The remaining direct debug-artifact diff is classified representation drift, and the focused `code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names` cleanup replay produced the same first diff as the no-CF cleanup baseline.

Future parity work should only proceed when one of these is true:

1. a new semantic or validity mismatch appears
2. a proven downstream code-size blocker requires broader helper-label sharing
3. preset scheduling is being advanced with separate ordered-path proof
4. the pass-targeted comparison harness regresses after a future broadening change

Follow the repo-level pass signoff rule from [`../../../../../AGENTS.md`](../../../../../AGENTS.md): compare against Binaryen at meaningful counts before calling parity done.

## Current open design questions

- Should the first implementation live as a pure HOT pass, or should some equality/profitability work be easier over lowered lib instruction arrays?
- Should suffix equality begin with exact HOT-node structural equality, or reuse a normalized lowered-instruction comparison for the first slice?
- How should Starshine represent Binaryen's `unoptimizables` label set when a label has both plain-`br` tails and unsupported branch-form users?
- Which local size model should stand in for Binaryen's expression `Measurer` before Starshine has byte-level profitability for this pass?
- Is it better to add EH support after function-ending tails, or should EH-sensitive shapes stay permanent bailouts until more local EH rewrite infrastructure exists?

Record the answer to each question here when implementation begins.

## Bottom line

The source-backed implementation path is:

1. keep `code-folding` active but narrow until tests drive each broader family
2. extend expression-exit positives and source-backed negative gates before branchy movement
3. add terminating-tail helper-label sharing as a separate slice
4. treat EH movement as advanced follow-up, not first-slice scope
5. keep direct compare-pass green before broad artifact replay

That keeps Starshine aligned with Binaryen's actual `code-folding` contract instead of drifting into a generic duplicate-region optimizer.

## Sources

- [`../../../raw/research/0522-2026-05-06-code-folding-direct-revalidation.md`](../../../raw/research/0522-2026-05-06-code-folding-direct-revalidation.md)
- [`../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md)
- [`../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md`](../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md)
- [`../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md)
- [`../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md`](../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./terminating-tails.md`](./terminating-tails.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- Binaryen current `main` pass source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodeFolding.cpp>
- Binaryen current `main` lit tests: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-folding.wast>
- [`../../../../../src/passes/code_folding.mbt`](../../../../../src/passes/code_folding.mbt)
- [`../../../../../src/passes/code_folding_test.mbt`](../../../../../src/passes/code_folding_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/ir/hot_builders.mbt`](../../../../../src/ir/hot_builders.mbt)
- [`../../../../../src/ir/hot_region_edit.mbt`](../../../../../src/ir/hot_region_edit.mbt)
- [`../../../../../src/ir/hot_query.mbt`](../../../../../src/ir/hot_query.mbt)
- [`../../../../../src/ir/hot_side_tables.mbt`](../../../../../src/ir/hot_side_tables.mbt)
- [`../../../../../src/ir/hot_labels.mbt`](../../../../../src/ir/hot_labels.mbt)
- [`../../../../../src/ir/hot_verify.mbt`](../../../../../src/ir/hot_verify.mbt)
- [`../../../../../src/cli/cli_test.mbt`](../../../../../src/cli/cli_test.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
