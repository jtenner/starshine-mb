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
| Active owner | `src/passes/code_folding.mbt` | `code-folding` has a real HOT descriptor and transform for the current narrow subset, now with explicit typed named-block exit-tail provenance, single-result multi-root suffix plans, and the first source-backed multi-value branch-plus-fallthrough payload suffix. |
| Focused tests | `src/passes/code_folding_test.mbt` | current void-tail positives, typed named-block payload, multi-root, and first multi-value suffix positives, terminal `if` subsets, and bailouts are regression-protected. |
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
- typed named-block plain-`br` payload sharing with a matching fallthrough value or other branch payloads, including safe single-result multi-root suffixes and one source-backed multi-value branch-plus-fallthrough suffix
- unsupported `br_on_null` label-poisoning coverage for block-exit folding
- exact partial non-block value-arm `if` suffix sharing, one-block/one-non-block `if` value-suffix folding in both then-block and else-block orientations plus both-arm-prefix, full one-block value-arm, full one-block void-arm, full multi-root non-block value-arm, embedded `select`, `drop`, `call`, `unary`, `binary`, `compare`, `convert`, `load`, `local.set`, `local.tee`, `global.set`, `store`, `br` payload, `return`, `ref.is_null`, `table.get`, `table.set` index, `call_indirect`, `memory.grow`, `table.grow`, `table.fill`, `memory.fill`, `memory.copy`, and `memory.init` value-child typed-wrapper shapes, and a source-backed two-unnamed-block value-arm suffix fold with unique prefixes plus a two-unnamed-block void-arm suffix fold
- live-label structured `if` suffix bailout coverage
- small exiting dead-value block flattening cleanup

### Current next slice: broader `if` expression-exit positives with hard bailouts

The named-block expression-exit substrate now covers the first safe multi-root single-result branch-payload suffix shapes and one source-backed multi-value branch-plus-fallthrough shape. Continue with the remaining broader expression-exit family from [`./binaryen-strategy.md`](./binaryen-strategy.md):

- remaining unnamed `if` arm duplicate suffix caveats beyond the covered direct suffix, exact partial non-block value suffix, widened one-block/one-non-block value-suffix cases, and the new two-unnamed-block value-suffix case
- named-arm negatives from the official lit matrix where the local HOT/name surface can distinguish them
- any further named-block broadening only when it goes beyond the covered plain-`br`, single-result multi-root safe subset and first multi-value branch-plus-fallthrough payload suffix, with HOT/lower proof for each new shape

Keep these first-slice bailouts explicit:

- any unsupported branch family beyond plain `br`
- any `br_table`, `br_if`, `br_on_*`, `delegate`, `try`, `try_table`, `throw`, or `pop` shape until the movement proof is local and tested; focused H/I coverage now protects `br_table`, outside-target/switch-scope negatives, simple/nested/dropped-value non-terminal `try_table` body positives, and tested `try_table` bailout shapes including `catch_ref` terminal tails
- any candidate whose branch target is not still in scope after the proposed move
- any additional multi-result, multi-value-payload, or refined-reference shape whose outer type cannot be reverified immediately
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

The first terminating-tail step covered a narrow adjacent shape: a no-else `if` then-tail and the immediately following fallthrough tail can share identical empty-payload `return` or `unreachable` suffixes by wrapping the old `if` in a fresh void helper block and replacing the old then-tail with `br` to that block label. The next slice now covers a conservative root-anchored helper-label subset of the dedicated terminating-tail family from [`./terminating-tails.md`](./terminating-tails.md):

- non-adjacent `return` suffixes where the selected group includes the root function-ending tail
- block-backed `unreachable` suffixes with the same root-tail anchor
- typed-result direct `return_call`
- `return_call_indirect`
- core-built `return_call_ref` using a typed nullable reference fixture

This remains a separate implementation slice because the full Binaryen algorithm still needs:

- arbitrary subset grouping instead of requiring the root-end tail anchor
- deeper common-suffix search across non-root groups, not just root-anchored groups
- fresh helper-label creation for arbitrary selected tails
- old-body fallthrough prevention for groups that cannot rely on the original root-ending suffix
- broader movement safety for branch/control-bearing moved items
- direct root replacement for root-level terminators in groups that do not include the final body suffix

The current local root-anchored model now reruns to a fixpoint, but that is not the same as Binaryen's arbitrary non-root subset search or exact helper-cost behavior.

### Slice 4: EH and broad movement safety

Do not mix EH movement into the first green port.
Binaryen's source has conservative `pop` / throwing-through-`try` barriers plus nested-pop repair after block-adding rewrites.
The current local decision is mostly bailout: `code-folding` now descends into `try` / `try_table` bodies only for ordinary non-terminal `if` suffix folding, does not treat EH controls as normal exiting/fallthrough-preventing cleanup nodes, and keeps focused `try_table` terminal/block-exit tests. The 2026-06-04 outer-`catch_all` and 2026-06-05 `catch_ref` / `catch_all_ref` `try_table` terminal-tail probes matched Binaryen's bailouts under `wasm-opt` version 129 (`version_129`), while simple, nested, and dropped outer `catch_ref` / `catch_all_ref` throwing-body duplicate `if` arms inside `try_table` bodies now have matching local coverage. Exact text-level plain `try` coverage remains blocked because local WAT lowering does not preserve that EH surface in the final HOT/pretty output. A later local port should only move EH-sensitive shapes if it also proves:

- HOT lift exposes enough catch / `try_table` ownership to detect the same hazards
- HOT lower/writeback preserves the repaired shape
- focused EH tests cover both accepted and rejected movement beyond the current non-terminal `if` body fold

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

Keep that shape for future broadening. Terminating-tail candidates now have the first explicit root-anchored model in `src/passes/code_folding.mbt`: owning region, region end index, terminator family, selected suffix length, profitability, and a rewrite path that requires one selected tail to be the root function-ending suffix. The pass now recomputes label use and repeats the local visit/terminating-tail sequence until no local change remains. Future broadening should add the missing Binaryen fields deliberately, especially arbitrary replacement-site provenance, movement-safety proof for branch/control-bearing suffixes, and exact helper-cost/fixpoint state. This avoids the common over-broad implementation mistake: comparing two root arrays, finding them equal, and moving them without knowing why the move is legal.

## Validation ladder

Use a strict test-first ladder.

### Reduced tests first

Seed a future `src/passes/code_folding_test.mbt` from Binaryen's dedicated `code-folding.wast` proof families:

1. identical unnamed `if` arm blocks fold to a shared suffix
2. partially shared `if` arm suffixes fold while preserving the unique prefix
3. named arm blocks stay untouched
4. plain branch-value tails to one named exit share the payload suffix while preserving the branch shell (single-result payload-root and multi-root pre-payload suffix cases now have June 4 coverage; a first multi-value branch-plus-fallthrough suffix has June 5 coverage)
5. branch-plus-fallthrough tails share the suffix (void tails, single-result payload-root plus multi-root payload-suffix cases, and one multi-value payload suffix now have coverage; broader helper/profitability cases remain future)
6. `br_on_*` / unsupported branch forms poison label folding
7. outside-target branches block movement
8. refined-result and typed-block contexts still validate

### Then add terminating-tail tests

After slice 1 is green, keep adding:

1. duplicate `return` suffixes produce one shared function-ending suffix (root-anchored non-adjacent coverage now exists)
2. duplicate `unreachable` suffixes share safely (root-anchored block-backed coverage now exists)
3. `return_call*` belongs to the same family (root-anchored direct/indirect/ref coverage now exists, and simple result direct/indirect sibling-tail bailout boundaries are covered)
4. a second local root-anchored fold exposed by the first is reached in the same pass invocation
5. old-body fallthrough cannot accidentally execute the shared suffix (covered for groups anchored on the original root ending; arbitrary non-root groups remain future)
6. root-level terminators are rewritten correctly, not only block-backed ones (root-ending anchor coverage exists; direct pointer-style non-root replacement remains future)

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

The root-anchored `[O4Z-AUDIT-CF-F]` / `[O4Z-AUDIT-CF-G]` terminating-tail lane is also green:

- failing-first/implementation-loop `moon test src/passes` runs exposed the new non-adjacent return, block-backed unreachable, direct `return_call`, `return_call_indirect`, and `return_call_ref` positives before the final implementation was complete; the attempted unreachable-condition `if` fixture still failed in the local HOT/lower pipeline and remains documented as a fixture blocker;
- after implementation `moon test src/passes` passed `1601/1601`;
- `moon fmt` completed;
- `moon info` completed with 6 tasks up to date;
- full `moon test` passed `4786/4786`;
- `moon build --target native --release src/cmd` produced `_build/native/release/build/cmd/cmd.exe` with only the existing `pass_manager.mbt` unused-function warnings;
- direct 1000-case smoke at `.tmp/pass-fuzz-code-folding-fg-1000`: `998/1000` compared cases, `998` normalized matches, `0` mismatches, `2` `binaryen-rec-group-zero` command failures;
- timing-only debug-WASI replay at `.tmp/code-folding-fg-self-compare`: `210.383ms` Starshine pass time vs `187.861ms` Binaryen, within the <=2x floor.

The `[O4Z-AUDIT-CF-H]` / `[O4Z-AUDIT-CF-I]` / `[O4Z-AUDIT-CF-J]` movement-safety, EH-bailout, and local-fixpoint lane is green:

- first test-first `moon test src/passes` failed the new root-anchored terminating-tail fixpoint test and the new `try_table` terminal-tail bailout test before implementation;
- after implementation `moon test src/passes` passed `1608/1608`;
- `moon fmt` completed;
- `moon info` completed with 6 tasks up to date;
- full `moon test` passed `4793/4793`;
- `moon build --target native --release src/cmd` produced `_build/native/release/build/cmd/cmd.exe` with only the existing `pass_manager.mbt` unused-function warnings;
- direct 1000-case smoke at `.tmp/pass-fuzz-code-folding-hij-1000`: `998/1000` compared cases, `998` normalized matches, `0` mismatches, `2` `binaryen-rec-group-zero` command failures;
- timing-only debug-WASI replay at `.tmp/code-folding-hij-self-compare`: `231.629ms` Starshine pass time vs `195.691ms` Binaryen, within the <=2x floor.

A later `[O4Z-AUDIT-CF-H]` guard added `code-folding keeps crossed nested self-branch return suffixes`, which was already green locally and protects the multi-label alpha map from equating an inner-target branch with an outer-target branch. The same alpha-map proof is now covered for nested self-branching `unreachable` suffixes. These are focused guard/coverage slices, not a broader movement-safety implementation. The same continuation added `[O4Z-AUDIT-CF-I]` coverage and a narrow implementation for `code-folding folds non-terminal try-table if-arm body suffixes`, matching the checked Binaryen body-local fold while leaving EH movement/repair and terminal-tail collection across EH boundaries open. Later nested `try_table` and dropped outer `catch_ref` / `catch_all_ref` throwing-body fixtures cover the same safe visitor through nested or embedded EH controls; exact plain `try` text coverage remains blocked by local WAT lowering.

The 2026-06-05 five-slice continuation is green:

- source-backed coverage now includes one-block/one-non-block multi-root `if` value suffixes in both orientations, two-unnamed-block multi-root `if` value suffixes, crossed live-label `if` suffix bailout, `br_if` block-exit payload poisoning, explicit-`catch` `try_table` body-local folding, `catch_all_ref` `try_table` terminal-tail bailout classification, crossed nested-label `unreachable`, `return_call`, and `return_call_indirect` bailouts, nested self-branching `return_call` and `return_call_indirect` suffix sharing, non-null `ref.func` / `return_call_ref` nested self-branching suffix coverage, and a branch-only multi-value named-block payload suffix with an unreachable fallback;
- per-slice `moon fmt` and `moon test src/passes` passed through `1647/1647` for the latest focused tail-call movement coverage slice;
- `moon info` completed with no work to do;
- full `moon test` passed `4822/4822`;
- `moon build --target native --release src/cmd` completed with no work to do and reused `_build/native/release/build/cmd/cmd.exe`;
- direct 1000-case smoke at `.tmp/pass-fuzz-code-folding-five-slices-2026-06-05-1000`: `998/1000` compared cases, `998` normalized matches, `0` mismatches, `2` `binaryen-rec-group-zero` command failures, agent-classified as tool/Binaryen command failures.

The `[O4Z-AUDIT-CF-K]` invalid-output fix and large-smoke continuation is green on validity/Starshine command stability and leaves only documented semantic-safe drift:

- failing-first regressions covered multi-result exiting-block wrappers before bottom tails, typed loop and `try_table` bottom tails before enclosing unreachable, root branches after typed dead operands, root bottom sentinels before trailing typed debris, and duplicate bottom tails in typed dead blocks;
- implementation now preserves bottom sentinels in result-producing root/loop/`if` regions when they are still needed, avoids flattening multi-result exiting blocks, computes HOT lift branch arity for branches to the implicit function label from the function return type, and clears the validator operand stack on repeated unreachable/branch escapes;
- `moon fmt` completed; `moon test src/passes` passed `1658/1658`; `moon test src/validate` passed `1552/1552`; `moon build --target native --release src/cmd` completed with `_build/native/release/build/cmd/cmd.exe`; final docs/code signoff after `moon update` ran `moon info`, `moon fmt`, and full `moon test` (`4843/4843`);
- direct 100000-case smoke at `.tmp/pass-fuzz-code-folding-100000-after-td-fixes`: `99747/100000` compared cases, `99742` normalized matches, `0` Starshine command failures, `0` validation failures, `0` property failures, `253` tool/Binaryen command failures, and `5` mismatches;
- agent-classified mismatch families: `012741`/`043481`, `023083`, and `082547` are semantic-safe size-winning cleanup drift where Starshine removes pure nontrapping value debris before `unreachable`; `046375` was later narrowed from size-losing to size-winning representation drift: Starshine now removes the dead wrapper and emits only `unreachable` (`73B` vs Binaryen `74B`, which keeps `nop; unreachable`).

The `case-046375` size cleanup continuation is also green on correctness but exposes a pass-local timing blocker:

- focused replay at `.tmp/pass-fuzz-code-folding-replay-5-after-046375-size-win`: `5/5` compared, `0` validation/command failures, five remaining semantic-safe mismatches; all five are now size-winning for Starshine;
- direct 1000-case smoke at `.tmp/pass-fuzz-code-folding-046375-fix-1000`: `998` normalized matches, `0` mismatches, `2` tool/Binaryen command failures;
- validation: `moon test src/passes` `1659/1659`, `moon test src/ir` `245/245`, full `moon test` `4844/4844`;
- requested performance check at `.tmp/code-folding-046375-self-compare-after-large-gate`: Starshine pass `5051.616ms` vs Binaryen `185.490ms`, outside the <=2x floor and now tracked under `[O4Z-AUDIT-CF-L]`.

The EH-body `catch_ref` / `catch_all_ref` breadth continuation is green:

- failing-first tests covered Binaryen's throwing-body non-terminal `if` suffix fold for `catch_ref` and `catch_all_ref` try-tables embedded in a dropped resultful outer block;
- implementation added a narrow dropped-value EH-body traversal that only runs the existing non-terminal `if` suffix folder inside embedded `try` / `try_table` bodies;
- validation: `moon test src/passes` `1661/1661`, `moon info`, `moon fmt`, full `moon test` `4846/4846`, native build at `_build/native/release/build/cmd/cmd.exe`, and direct 1000-case compare at `.tmp/pass-fuzz-code-folding-eh-catch-ref-body-1000` (`998` normalized matches, `0` mismatches, `2` tool/Binaryen command failures).

The one-block, full multi-root, embedded-select, and embedded value-parent `if` breadth continuations are green:

- failing-first tests covered Binaryen's one-block/non-block partial value-suffix fold where both arms have distinct prefixes, the full one-block/non-block value-arm fold to `drop(condition)` plus one shared suffix, the full tiny/larger one-block/non-block void-arm fold to `drop(condition)` plus the shared void suffix, the full multi-root non-block value-arm fold, the narrow embedded-`select` full-arm typed-wrapper variant, the embedded-`select` partial value-if suffix typed-wrapper variant, and source-backed embedded value-parent wrappers: partial suffixes under `drop`, `call`, `unary`, `binary`, `compare`, `convert`, `load`, `local.set`, `local.tee`, `global.set`, `store`, `br` payload, `return`, `ref.is_null`, `table.get`, `table.set` index, `call_indirect`, `memory.grow`, `table.grow`, `table.fill`, `memory.fill`, `memory.copy`, and `memory.init`, plus full multi-root suffixes under `call` and `binary`;
- implementation now computes the actual common suffix between the unused block body and non-block arm instead of requiring the whole non-block arm to be the suffix, no longer bails out before the existing full-arm replacement path for result-void one-block/non-block arms, permits full non-block value folds only when the shared suffix has multiple roots, and wraps full multi-root or partial value `if` children in typed blocks for the source-backed `select`, `drop`, `call`, `unary`, `binary`, `compare`, `convert`, `load`, `local.set`, `local.tee`, `global.set`, `store`, `br` payload, `return`, `ref.is_null`, `table.get`, `table.set` index, `call_indirect`, `memory.grow`, `table.grow`, `table.fill`, `memory.fill`, `memory.copy`, and `memory.init` parent subset;
- latest validation: initial `moon test src/passes` for the table/bulk-memory value-parent batch failed exactly the five new tests (`1689/1694`); after implementation `moon test src/passes` passed `1694/1694`; `moon fmt`, `moon info`, and full `moon test` passed `4879/4879`; native build produced `_build/native/release/build/cmd/cmd.exe`; direct 1000-case compare at `.tmp/pass-fuzz-code-folding-table-memory-bulk-1000` had `998` normalized matches, `0` mismatches, and `2` tool/Binaryen command failures (`command-class.binaryen-rec-group-zero`).

Direct `[CF]002` signoff is accepted as of 2026-05-10 for the earlier narrowed surface, `[O4Z-AUDIT-CF-A]` baselines the June widening, `[O4Z-AUDIT-CF-B]` through `[O4Z-AUDIT-CF-D]` add the source-backed matrix, explicit named-block candidate model, and first multi-root named-block expression-exit widening, `[O4Z-AUDIT-CF-E]` has exact partial non-block, widened one-block/one-non-block, two-unnamed-block multi-root progress plus a HOT-level unreachable-condition bailout, `[O4Z-AUDIT-CF-F]` has adjacent and root-anchored return/unreachable terminal-tail helper shapes, `[O4Z-AUDIT-CF-G]` has started root-anchored and selected non-root `return_call*` sharing, `[O4Z-AUDIT-CF-H]` has movement-safety positives/negatives, `[O4Z-AUDIT-CF-I]` has tested EH body-local positives and bailouts, and `[O4Z-AUDIT-CF-J]` has local root-anchored fixpoint plus a small late-neighborhood fixture. The remaining direct debug-artifact diff is classified representation drift, and the focused `code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names` cleanup replay produced the same first diff as the no-CF cleanup baseline. The 2026-06-04 O4z audit is tracked in [`../../../raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md`](../../../raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md); it now keeps the broader Binaryen behavior-parity slices open.

Future parity work should only proceed when one of these is true:

1. a new semantic or validity mismatch appears
2. a proven downstream code-size blocker requires broader helper-label sharing
3. preset scheduling is being advanced with separate ordered-path proof
4. the pass-targeted comparison harness regresses after a future broadening change
5. the team decides the current five semantic-safe mismatch families should be normalized or eliminated for a stricter parity gate

Follow the repo-level pass signoff rule from [`../../../../../AGENTS.md`](../../../../../AGENTS.md): compare against Binaryen at meaningful counts before calling parity done.

## Current open design questions

- Should the first implementation live as a pure HOT pass, or should some equality/profitability work be easier over lowered lib instruction arrays? Current answer for expression exits: keep it in HOT.
- Should suffix equality begin with exact HOT-node structural equality, or reuse a normalized lowered-instruction comparison for the first slice? Current answer: exact HOT-node structural equality plus label-use-aware comparison for the covered named-block slices.
- How should Starshine represent Binaryen's `unoptimizables` label set when a label has both plain-`br` tails and unsupported branch-form users? Current answer: the local collectors poison the whole target by returning false when `br_if`, `br_on_*`, `br_table`, or `delegate` traffic reaches the target label.
- Which local size model should stand in for Binaryen's expression `Measurer` before Starshine has byte-level profitability for this pass? Current answer: `code_folding_node_measure` is the provisional node-count measure; it is good enough for the tested direct after-block suffix sharing but not a full Binaryen helper-block cost model.
- Is it better to add EH support after function-ending tails, or should EH-sensitive shapes stay permanent bailouts until more local EH rewrite infrastructure exists? Current batch keeps EH-sensitive movement as tested bailouts while allowing only body-local non-terminal `if` suffix folding inside `try` / `try_table`; nested `try_table` and dropped outer `catch_ref` / `catch_all_ref` throwing-body coverage is green for the currently covered catch kinds, exact plain `try` text coverage is blocked by local WAT lowering, and there is still no nested-pop repair path.

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
