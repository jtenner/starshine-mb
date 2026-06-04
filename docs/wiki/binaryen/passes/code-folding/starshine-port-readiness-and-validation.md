---
kind: concept
status: supported
last_reviewed: 2026-06-04
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
| Active owner | `src/passes/code_folding.mbt` | `code-folding` has a real HOT descriptor and transform for the current narrow subset, now with explicit typed named-block exit-tail provenance and single-result multi-root suffix plans. |
| Focused tests | `src/passes/code_folding_test.mbt` | current void-tail positives, typed named-block payload and multi-root suffix positives, terminal `if` subsets, and bailouts are regression-protected. |
| Registry entry | `src/passes/optimize.mbt` | `code-folding` is an active hot pass, not a removed-name placeholder. |
| Dispatcher arm | `src/passes/pass_manager.mbt` | active requests dispatch to `code_folding_run(ctx, func)`. |
| CLI spelling preservation | `src/cli/cli_test.mbt` | `--code-folding` parses and explicit pass-token order is stable. |
| Direct revalidation | `.tmp/pass-fuzz-code-folding-cf002-terminal-if`, `docs/wiki/raw/research/0522-2026-05-06-code-folding-direct-revalidation.md` | latest executed harness lane had `6759` normalized matches and `0` semantic mismatches; direct debug-artifact timing stayed inside the <=2x Binaryen floor, but this evidence predates the June typed block-exit payload widening. |
| Backlog slice | `agent-todo.md` | `[O4Z-AUDIT-CF]` tracks fresh fixture validation, direct compare, pass-local timing, and late-slot replay before the audit closes. |
| Canonical late slot | `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` | the pass belongs immediately before the late `merge-blocks` cluster in the no-DWARF function phase. |

## Remaining Starshine slice order

Further parity work should stay staged. Binaryen's source contract is broader than the already-landed narrow local patch.

### Completed slice: narrow void `if`-arm fold positives

The current owner file and tests cover a conservative subset of the expression-exit family:

- identical void `if`-arm suffix hoisting
- identical full void-arm cleanup
- value-producing `if` bailout
- full-`if` terminal suffix sharing for empty-payload `return` and `unreachable`
- void block-exit/fallthrough tail sharing
- single-result typed named-block plain-`br` payload sharing with a matching fallthrough value or other branch payloads, including a safe multi-root suffix before the final value root
- unsupported `br_on_null` label-poisoning coverage for block-exit folding
- one-block/one-non-block `if` value-suffix folding in both then-block and else-block orientations
- live-label structured `if` suffix bailout coverage
- small exiting dead-value block flattening cleanup

### Current next slice: broader `if` expression-exit positives with hard bailouts

The named-block expression-exit substrate now covers the first safe multi-root single-result branch-payload suffix shapes. Continue with the remaining broader expression-exit family from [`./binaryen-strategy.md`](./binaryen-strategy.md):

- remaining unnamed `if` arm duplicate suffix caveats beyond the covered direct suffix and one-block/one-non-block value-suffix cases
- named-arm negatives from the official lit matrix where the local HOT/name surface can distinguish them
- any further named-block broadening only when it goes beyond the covered plain-`br`, single-result, multi-root safe subset, such as multi-value payloads with HOT/lower proof

Keep these first-slice bailouts explicit:

- any unsupported branch family beyond plain `br`
- any `br_table`, `br_if`, `br_on_*`, `delegate`, `try`, `try_table`, `throw`, or `pop` shape until the movement proof is local and tested
- any candidate whose branch target is not still in scope after the proposed move
- any multi-result, multi-value-payload, or refined-reference shape whose outer type cannot be reverified immediately
- any case that needs a fresh helper label at the end of the function body

This next slice should remain narrower than Binaryen until local candidate equality, movement-safety, mutation, and tests are proven for each new branch-bearing or arm-wrapping family.

### Slice 2: source-backed negative gates

Add the official negative families before adding more positives:

- unsupported branch-form label poisoning
- outside-target branch bailout
- equal-looking but unsafe switch / table-tail cases
- unreachable-condition `if` contexts that DCE should handle instead
- refined-result / typed-block preservation checks

These are correctness tests. They should fail before implementation, not be added as telemetry after a broad rewrite.

### Slice 3: terminating-tail helper-label sharing

The first terminating-tail step is now covered for a narrow adjacent shape: a no-else `if` then-tail and the immediately following fallthrough tail can share identical empty-payload `return` or `unreachable` suffixes by wrapping the old `if` in a fresh void helper block and replacing the old then-tail with `br` to that block label. Continue with the full dedicated terminating-tail family from [`./terminating-tails.md`](./terminating-tails.md):

- general `return` subsets beyond the adjacent no-else `if` shape
- `return_call`
- `return_call_indirect`
- `return_call_ref`
- general `unreachable` subsets beyond the adjacent no-else `if` shape

This remains a separate implementation slice because the full Binaryen algorithm still needs:

- subset grouping instead of all-tails-or-nothing matching
- deeper common-suffix search before shallower search
- fresh helper-label creation for arbitrary selected tails
- old-body fallthrough prevention beyond the adjacent no-else `if` case
- direct root replacement for root-level terminators, not just block-backed or adjacent tails

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

For named-block expression exits, `src/passes/code_folding.mbt` now models branch-backed and fallthrough tails as explicit `CodeFoldingValueExitTail` data before rewriting:

- owning region and tail end/root pointer
- whether the tail is branch-backed or fallthrough
- target label
- branch payload root list
- result arity expectation at the shared exit
- movement-safety proof state
- selected suffix length
- profitability score

Keep that shape for future broadening. Terminating-tail candidates should get an equally explicit model before helper-label sharing lands: owning region or root pointer, tail root sequence, terminator kind, replacement site, movement-safety proof, suffix length, and profitability. This avoids the common over-broad implementation mistake: comparing two root arrays, finding them equal, and moving them without knowing why the move is legal.

## Validation ladder

Use a strict test-first ladder.

### Reduced tests first

Seed a future `src/passes/code_folding_test.mbt` from Binaryen's dedicated `code-folding.wast` proof families:

1. identical unnamed `if` arm blocks fold to a shared suffix
2. partially shared `if` arm suffixes fold while preserving the unique prefix
3. named arm blocks stay untouched
4. plain branch-value tails to one named exit share the payload suffix while preserving the branch shell (single-result payload-root and multi-root pre-payload suffix cases now have June 4 coverage; multi-value cases remain future)
5. branch-plus-fallthrough tails share the suffix (void tails and single-result payload-root plus multi-root payload-suffix cases now have coverage; broader helper/profitability cases remain future)
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

The latest full 10000-case direct lane is from 2026-05-10 and predates the June 4 typed-payload widening:

- implementation-thread signoff: `moon info`, `moon fmt`, `moon test`
- latest archived 10000-case direct fuzz: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass code-folding --max-failures 20 --out-dir .tmp/pass-fuzz-code-folding-cf002-terminal-if`
- result: `6759/10000` compared cases, `6759` normalized matches, `0` semantic mismatches, `20` Binaryen empty-recursion-group command failures
- direct artifact replay: `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1680352`, first diff `defined=220 abs=237`, classified representation drift, `334.711ms` Starshine pass time vs `176.295ms` Binaryen
- late cleanup replay: `.tmp/cf002-late-cleanup-artifact`, first diff `defined=29 abs=46`, same focused diff files as the no-CF baseline `.tmp/cf002-late-cleanup-without-cf-artifact`

The June 4 typed block-exit payload widening baseline is green:

- `moon test src/passes`: `1590/1590`
- `moon test`: `4775/4775`
- native binary path: `_build/native/release/build/cmd/cmd.exe`
- direct 1000-case smoke at `.tmp/pass-fuzz-code-folding-audit-1000`: `998/1000` compared cases, `998` normalized matches, `0` mismatches, `2` `binaryen-rec-group-zero` command failures
- timing-only debug-WASI replay at `.tmp/code-folding-audit-self-compare`: `172.276ms` Starshine pass time vs `169.576ms` Binaryen, within the <=2x floor

The follow-up source-matrix / candidate-model / multi-root named-block widening lane is also green:

- first test-first `moon test src/passes` failed the two new multi-root tests before implementation;
- after implementation `moon test src/passes` passed `1592/1592`;
- `moon fmt` completed;
- full `moon test` passed `4777/4777`;
- `moon info` completed with 6 tasks up to date;
- `moon build --target native --release src/cmd` produced `_build/native/release/build/cmd/cmd.exe` with only the existing `pass_manager.mbt` unused-function warnings;
- direct 1000-case smoke at `.tmp/pass-fuzz-code-folding-bd-1000`: `998/1000` compared cases, `998` normalized matches, `0` mismatches, `2` `binaryen-rec-group-zero` command failures;
- timing-only debug-WASI replay at `.tmp/code-folding-bd-self-compare`: `196.213ms` Starshine pass time vs `187.281ms` Binaryen, within the <=2x floor.

The next `[O4Z-AUDIT-CF-E]` one-block/one-non-block `if` widening lane is green:

- first test-first `moon test src/passes` failed the two new one-block/one-non-block tests before implementation;
- after implementation `moon test src/passes` passed `1594/1594`;
- `moon fmt` completed;
- full `moon test` passed `4779/4779`;
- `moon info` completed with 6 tasks up to date;
- `moon build --target native --release src/cmd` produced `_build/native/release/build/cmd/cmd.exe` with only the existing `pass_manager.mbt` unused-function warnings;
- direct 1000-case smoke at `.tmp/pass-fuzz-code-folding-e-1000`: `998/1000` compared cases, `998` normalized matches, `0` mismatches, `2` `binaryen-rec-group-zero` command failures;
- timing-only debug-WASI replay at `.tmp/code-folding-e-self-compare`: `208.362ms` Starshine pass time vs `185.945ms` Binaryen, within the <=2x floor.

The first `[O4Z-AUDIT-CF-F]` adjacent terminating-tail lane is green:

- first test-first `moon test src/passes` failed the two new no-else `if` then-tail plus fallthrough terminal tests before implementation;
- after implementation `moon test src/passes` passed `1596/1596`;
- `moon fmt` completed;
- full `moon test` passed `4781/4781`;
- `moon info` completed with 6 tasks up to date;
- `moon build --target native --release src/cmd` produced `_build/native/release/build/cmd/cmd.exe` with only the existing `pass_manager.mbt` unused-function warnings;
- direct 1000-case smoke at `.tmp/pass-fuzz-code-folding-f-1000`: `998/1000` compared cases, `998` normalized matches, `0` mismatches, `2` `binaryen-rec-group-zero` command failures;
- timing-only debug-WASI replay at `.tmp/code-folding-f-self-compare`: `187.189ms` Starshine pass time vs `198.305ms` Binaryen.

Direct `[CF]002` signoff is accepted as of 2026-05-10 for the earlier narrowed surface, `[O4Z-AUDIT-CF-A]` baselines the June widening, `[O4Z-AUDIT-CF-B]` through `[O4Z-AUDIT-CF-D]` add the source-backed matrix, explicit named-block candidate model, and first multi-root named-block expression-exit widening, `[O4Z-AUDIT-CF-E]` has concrete one-block/one-non-block progress, and `[O4Z-AUDIT-CF-F]` has a first adjacent return/unreachable terminal-tail helper shape. The remaining direct debug-artifact diff is classified representation drift, and the focused `code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names` cleanup replay produced the same first diff as the no-CF cleanup baseline. The 2026-06-04 O4z audit is tracked in [`../../../raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md`](../../../raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md); it now keeps the broader Binaryen behavior-parity slices open.

Future parity work should only proceed when one of these is true:

1. a new semantic or validity mismatch appears
2. a proven downstream code-size blocker requires broader helper-label sharing
3. preset scheduling is being advanced with separate ordered-path proof
4. the pass-targeted comparison harness regresses after a future broadening change

Follow the repo-level pass signoff rule from [`../../../../../AGENTS.md`](../../../../../AGENTS.md): compare against Binaryen at meaningful counts before calling parity done.

## Current open design questions

- Should the first implementation live as a pure HOT pass, or should some equality/profitability work be easier over lowered lib instruction arrays? Current answer for expression exits: keep it in HOT.
- Should suffix equality begin with exact HOT-node structural equality, or reuse a normalized lowered-instruction comparison for the first slice? Current answer: exact HOT-node structural equality plus label-use-aware comparison for the covered named-block slices.
- How should Starshine represent Binaryen's `unoptimizables` label set when a label has both plain-`br` tails and unsupported branch-form users? Current answer: the local collectors poison the whole target by returning false when `br_if`, `br_on_*`, `br_table`, or `delegate` traffic reaches the target label.
- Which local size model should stand in for Binaryen's expression `Measurer` before Starshine has byte-level profitability for this pass? Current answer: `code_folding_node_measure` is the provisional node-count measure; it is good enough for the tested direct after-block suffix sharing but not a full Binaryen helper-block cost model.
- Is it better to add EH support after function-ending tails, or should EH-sensitive shapes stay permanent bailouts until more local EH rewrite infrastructure exists? Still open; current code treats `try` / `try_table` as hard bailouts for this pass.

## Bottom line

The source-backed implementation path is:

1. keep `code-folding` active but narrow until tests drive each broader family
2. use the completed source-backed shape matrix to select exact Binaryen families rather than generic duplicate-region rewrites
3. keep the explicit candidate model for named-block expression exits and extend it only with focused proof
4. add broader `if` arm wrapping and source-backed negative gates before risky branchy movement
5. add terminating-tail helper-label sharing as a separate slice
6. treat EH movement as advanced follow-up, not first-slice scope
7. keep direct compare-pass green before broad artifact replay

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
