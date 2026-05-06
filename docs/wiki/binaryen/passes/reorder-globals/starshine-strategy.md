---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0525-2026-05-06-reorder-globals-direct-revalidation.md
  - ../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-23-reorder-globals-primary-sources.md
  - ../../../raw/research/0367-2026-04-25-reorder-globals-current-main-and-test-map.md
  - ../../../raw/research/0270-2026-04-23-reorder-globals-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../../../../src/ir/hot.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../string-gathering/index.md
  - ../reorder-globals-always/index.md
  - ../directize/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./size-model-and-dependency-order.md
  - ./wat-shapes.md
  - ../string-gathering/index.md
  - ../reorder-globals-always/index.md
  - ../directize/index.md
---

# Starshine Strategy For `reorder-globals`

Use this page together with the current-main source bridge in [`../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md) and the owner/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that now own the direct pass, and the concrete neighboring implementation areas the late-tail preset still has to hook into.

## The honest current status

`reorder-globals` now has an active direct Starshine module-pass port in `src/passes/reorder_globals.mbt`.

The current local strategy is direct public-pass support plus explicit late-tail deferral:

- keep the public pass spelling active as a module pass
- keep `reorder-globals-always` boundary-only so the sibling policy is not collapsed into the production pass
- preserve Binaryen's public `<128` total-global no-op
- count whole-module global traffic and initializer dependencies
- apply a declaration reorder plus Starshine-specific numeric `GlobalIdx` remapping
- keep the canonical no-DWARF late-tail slot documented but out of presets until `string-gathering` and `directize` exist locally
- keep refreshed direct 10000-case oracle proof recorded while reserving ordered late-tail proof for the full late-tail neighborhood

So this page is now an **implementation status and late-tail follow-up** page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- active module-pass owner
  - [`src/passes/reorder_globals.mbt`](../../../../../src/passes/reorder_globals.mbt)
    - implements public cutoff, traffic counting, dependency sorting, candidate scoring, declaration reorder, and numeric index remapping
- focused direct-pass tests
  - [`src/passes/reorder_globals_test.mbt`](../../../../../src/passes/reorder_globals_test.mbt)
    - covers registry status, public cutoff, hot 129th-global movement, dependency preservation, export remapping, and global-name remapping
- registry status
  - [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
    - `reorder-globals` is registered as a module pass; `reorder-globals-always` remains boundary-only
- active dispatch and CLI surfaces
  - [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - [`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
  - [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
- numeric global-index and module-section surfaces the active port remaps
  - [`src/lib/types.mbt#L91`](../../../../../src/lib/types.mbt#L91)
    - `GlobalIdx` is a numeric index type, unlike Binaryen's name-keyed global references
  - [`src/lib/types.mbt#L351-L368`](../../../../../src/lib/types.mbt#L351-L368)
    - `Module` owns `import_sec`, `global_sec`, `export_sec`, `elem_sec`, `code_sec`, and `data_sec`
  - [`src/lib/types.mbt#L442`](../../../../../src/lib/types.mbt#L442)
    - `GlobalSec(Array[Global])` is the declaration vector a local module pass would reorder
  - [`src/binary/encode.mbt#L633-L636`](../../../../../src/binary/encode.mbt#L633-L636) and [`src/binary/decode.mbt#L731-L735`](../../../../../src/binary/decode.mbt#L731-L735)
    - binary roundtrip encodes/decodes numeric `GlobalIdx` values
  - [`src/validate/validate.mbt#L949-L965`](../../../../../src/validate/validate.mbt#L949-L965)
    - const-expression `global.get` validation depends on imported or previously defined immutable globals
  - [`src/ir/hot.mbt#L206-L218`](../../../../../src/ir/hot.mbt#L206-L218) and [`src/ir/hot.mbt#L285-L297`](../../../../../src/ir/hot.mbt#L285-L297)
    - HOT lift stores `GlobalGet` / `GlobalSet` operands as numeric global indices, confirming this is not a HOT-only peephole
- backlog and delivery plan
  - [`agent-todo.md#L672-L687`](../../../../../agent-todo.md#L672-L687)
    - `RG - Reorder Globals`
    - `[RG]001 - Global Cost Model and Reindexing`
    - `[RG]002 - Late-Postpass Validation and Artifact Compare`
- canonical scheduler context
  - [`../../no-dwarf-default-optimize-path.md#L35`](../../no-dwarf-default-optimize-path.md#L35)
    - the canonical late-tail slot `string-gathering -> reorder-globals -> directize`
- neighboring living dossiers the late-tail preset still must line up with
  - [`../string-gathering/index.md`](../string-gathering/index.md)
  - [`../reorder-globals-always/index.md`](../reorder-globals-always/index.md)
  - [`../directize/index.md`](../directize/index.md)

That code-and-doc map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and future landing zone.

## What Starshine currently does for this pass name

Today Starshine accepts `--reorder-globals` as a real module pass.

### 1. The public production pass is active

The implementation:

- returns unchanged below `128` total globals, matching the public Binaryen cutoff
- counts `global.get` and `global.set` uses in functions and module-level expression code
- builds initializer dependency edges from defined-global initializer `global.get`s
- tries the zero/raw/summed-dependent/exponential-dependent candidate families
- scores candidates using true observed counts and estimated ULEB global-index byte widths
- keeps imported globals before defined globals
- reorders the defined `global_sec` entries and remaps numeric global references across module/code/name surfaces

### 2. The `always` sibling still rejects honestly

`reorder-globals-always` remains boundary-only. That keeps explicit requests for the small-module/internal-helper variant honest until the repo chooses to port that separate policy.

### 3. The remaining work is planned as a real parity slice, not an orphan idea

`agent-todo.md` already gives `reorder-globals` a real backlog slice under `RG`.
The current deliverables are framed around the right local concerns:

- port Binaryen's reordering criteria
- compute a safe remap after late global cleanup and string gathering
- preserve externally visible boundaries and section invariants
- add regressions for reordered globals with string users and exports
- compare local output against Binaryen on the debug artifact

That backlog framing already matches the upstream dossier better than a vague “sort globals by use count” summary would.

## The right Starshine implementation shape

The current docs, neighboring passes, and landed direct port teach `reorder-globals` as a **late module pass**, not as an isolated HOT peephole and not as a side effect of `string-gathering`.

Why:

- Binaryen runs it after `string-gathering`
- it is the second-to-last top-level pass in the canonical no-DWARF tail
- its correctness depends on whole-module declaration order, import-prefix preservation, initializer dependencies, and final global-index layout
- the local backlog already makes safe remapping a first-class deliverable

So the local strategy should be thought of as:

1. keep the direct module pass focused on whole-module global traffic and initializer dependencies
2. choose a dependency-safe final declaration order with the reviewed Binaryen candidate families
3. apply a declaration reorder and Starshine-specific numeric remapping
4. keep reduced export/name/dependency coverage green
5. validate string users, startup/global-initializer correctness, and final artifact parity in the real late-tail neighborhood once surrounding passes exist

In other words, the direct port has landed, while its preset slot still belongs to the documented late optimization ecosystem.

## The most important local dependency map

### `reorder-globals` is downstream of `string-gathering`

See:

- [`../string-gathering/index.md`](../string-gathering/index.md)

Why it matters locally:

- the no-DWARF scheduler docs already place `reorder-globals` immediately after `string-gathering`
- the `string-gathering` dossier already teaches that its own internal reorder is only a validity repair for defining globals
- Starshine should keep the same division of labor explicit when the late-tail preset lands: string gathering first for validity/canonicalization, final global layout second for size and declaration order

That boundary is easy to blur if readers only remember that both passes can move globals.

### `reorder-globals-always` is a real sibling, not just an implementation footnote

See:

- [`../reorder-globals-always/index.md`](../reorder-globals-always/index.md)

Why it matters locally:

- `src/passes/optimize.mbt` preserves both spellings but now classifies only `reorder-globals-always` as boundary-only
- the upstream dossier keeps the `< 128` public no-op rule and the smooth-scoring sibling distinct
- a future sibling port may need to decide whether exact parity also requires a separate internal/test-facing helper story, or whether the repo should keep only the production public policy

The current local strategy page therefore keeps the sibling boundary explicit instead of teaching `reorder-globals` as if it were the entire family.

### `reorder-globals` feeds the final `directize` tail slot

See:

- [`../directize/index.md`](../directize/index.md)

Why it matters locally:

- the canonical no-DWARF scheduler places `reorder-globals` immediately before `directize`
- even though the passes operate on different surfaces, the local late-tail contract is clearer if `reorder-globals` is validated in the real neighborhood rather than as an isolated declaration-order tweak
- the remaining Starshine late-tail work should therefore include scheduler-neighborhood proof, not only standalone reorder tests

### `reorder-globals` is boundary/module work, not a neighbor of the current HOT peephole cluster

This is one of the most important local teaching points.
The current active Starshine HOT cluster covers passes like:

- `dead-code-elimination`
- `remove-unused-names`
- `remove-unused-brs`
- `optimize-instructions`
- `precompute`
- `merge-blocks`

Those are valuable neighboring dossiers for style and validation habits, but `reorder-globals` does not naturally belong in that cluster.
Its module-pass classification is not arbitrary bookkeeping.
It reflects the same architectural fact the Binaryen dossier teaches: global declaration layout and representation-correct remapping come first.

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a `reorder-globals-always` implementation
- public optimize/shrink preset scheduling for the late `string-gathering -> reorder-globals -> directize` tail
- ordered late-tail artifact replay coverage through `string-gathering -> reorder-globals -> directize`

So the current repo status is best summarized as:

- direct public transform landed
- `always` sibling still boundary-only
- late-tail preset integration deferred behind missing neighbors
- reduced tests landed
- refreshed direct oracle proof recorded; ordered late-tail proof still blocked on the full late-tail neighborhood

## Validation plan for the eventual port

The existing backlog plus the upstream dossier imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced shape tests for the main upstream families
   - hotter independent globals
   - dependency-preserving chains
   - `global.set` heat
   - import-first ordering
   - string-user cases that must remain valid after the final reorder
2. policy-boundary tests
   - exact public `< 128` no-op behavior if parity is the target
   - explicit separate handling, deferral, or absence of `reorder-globals-always`
3. remap and section-boundary tests
   - exported globals
   - initializer/global-order validity
   - any local index-bearing surfaces that need remapping in Starshine's representation or emit path
4. scheduler-neighborhood interaction tests
   - the full late-tail `string-gathering -> reorder-globals -> directize`
5. artifact and oracle comparison
   - direct pass evidence is `.tmp/pass-fuzz-reorder-globals-10000-post-raw-name-clear` and `.tmp/self-opt-reorder-globals-20260426-post-raw-name-clear`
   - the remaining future evidence is ordered late-tail replay once neighboring passes exist

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow and the exact neighboring passes that should feed the port.

## Bottom line

Current Starshine `reorder-globals` strategy is direct public-pass support plus late-tail landing-zone planning:

- the pass implementation lives in [`src/passes/reorder_globals.mbt`](../../../../../src/passes/reorder_globals.mbt)
- focused coverage lives in [`src/passes/reorder_globals_test.mbt`](../../../../../src/passes/reorder_globals_test.mbt)
- `reorder-globals` is registered as an active module pass while `reorder-globals-always` remains boundary-only
- [`agent-todo.md`](../../../../../agent-todo.md) records refreshed direct oracle evidence and treats late-tail proof as the remaining `RG` work
- the canonical slot is already documented in [`../../no-dwarf-default-optimize-path.md#L35`](../../no-dwarf-default-optimize-path.md#L35)
- the surrounding [`string-gathering`](../string-gathering/index.md), [`reorder-globals-always`](../reorder-globals-always/index.md), and [`directize`](../directize/index.md) dossiers define the remaining landing zone

So the right mental model today is:

- **public transform landed**
- **`always` sibling deferred**
- **late-tail preset scheduling deferred**
- **reduced reindexing tests landed**
- **refreshed direct 10000-case compare evidence recorded; ordered late-tail proof pending**
