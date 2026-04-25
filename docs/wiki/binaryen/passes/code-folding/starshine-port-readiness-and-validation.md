---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md
  - ../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md
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

`code-folding` is still unimplemented in Starshine.
There is no `src/passes/code_folding.mbt` owner file, no `pass_manager` dispatcher arm, and no active preset slot.

The local surfaces that already exist are planning and compatibility surfaces:

| Surface | Location | What it proves |
| --- | --- | --- |
| Removed-name registry | `src/passes/optimize.mbt:144-151` | `code-folding` is known and intentionally rejected, not an unknown typo. |
| Removed-pass request guard | `src/passes/optimize.mbt:469-471` | active requests fail before any placeholder transform can run. |
| Preset omission | `src/passes/optimize.mbt:385-410` | public `optimize` / `shrink` presets still skip the pass. |
| CLI spelling preservation | `src/cli/cli_test.mbt:159-165`, `src/cli/cli_test.mbt:297-309` | `--code-folding` parses and explicit pass-token order is stable. |
| Dispatcher gap | `src/passes/pass_manager.mbt:8693-8705` | neighboring HOT passes dispatch there, but `code-folding` has no match arm. |
| Backlog slice | `agent-todo.md:445-460` | `CF` is the active implementation-planning slot. |
| Canonical late slot | `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:33` | the pass belongs immediately before the late `merge-blocks` cluster in the no-DWARF function phase. |

## Minimum viable Starshine slice order

A faithful port should be staged. Binaryen's source contract is broader than a safe first local patch.

### Slice 1: expression-exit fold positives with hard bailouts

Start with the expression-exit family from [`./binaryen-strategy.md`](./binaryen-strategy.md):

- unnamed `if` arm duplicate suffixes
- named-block plain-`br` tails to the same exit
- branch-payload plus fallthrough suffixes where target scope is obviously preserved

Keep these first-slice bailouts explicit:

- any unsupported branch family beyond plain `br`
- any `br_table`, `br_if`, `br_on_*`, `delegate`, `try`, `try_table`, `throw`, or `pop` shape until the movement proof is local and tested
- any candidate whose branch target is not still in scope after the proposed move
- any multi-result or refined-reference shape whose outer type cannot be reverified immediately
- any case that needs a fresh helper label at the end of the function body

This slice is intentionally narrower than Binaryen. Its goal is to establish the local candidate/equality/mutation/test substrate without pretending to implement the full pass.

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
| Wire a future pass | `src/passes/optimize.mbt:144-151`, `src/passes/pass_manager.mbt:8693-8705` | Implementation requires moving the name out of removed registry status and adding a dispatcher branch. |

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

After reduced tests and neighborhood tests pass:

1. run the pass-targeted comparison harness with canonical pass name `code-folding`
2. replay the canonical no-DWARF ordered prefix through the documented late slot
3. replay the saved generated-artifact `-O4z` skipped-slot context from the tracker
4. require post-pass validation after each HOT writeback

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

1. keep `code-folding` unimplemented until tests drive a real owner file
2. start with narrow expression-exit positives and source-backed negative gates
3. add terminating-tail helper-label sharing as a separate slice
4. treat EH movement as advanced follow-up, not first-slice scope
5. validate against the official Binaryen lit families before broad artifact replay

That keeps Starshine aligned with Binaryen's actual `code-folding` contract instead of drifting into a generic duplicate-region optimizer.

## Sources

- [`../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md)
- [`../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md`](../../../raw/research/0373-2026-04-25-code-folding-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./terminating-tails.md`](./terminating-tails.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- Binaryen current `main` pass source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodeFolding.cpp>
- Binaryen current `main` lit tests: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-folding.wast>
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
