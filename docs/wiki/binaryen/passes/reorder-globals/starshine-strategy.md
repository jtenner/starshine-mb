---
kind: concept
status: supported
last_reviewed: 2026-07-29
sources:
  - ./index.md
  - ../../../raw/wasm/2026-06-04-leb128-current-refresh.md
  - ../../../../../src/passes/reorder_globals.mbt
  - ../../../../../src/passes/reorder_globals_test.mbt
  - ../../../../../src/passes/reorder_globals_wbtest.mbt
  - ../../../../../src/validate/gen_valid_reorder_globals.mbt
  - ../../../../../src/passes_perf_long/reorder_globals_perf_test.mbt
  - ./fuzzing.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../../../../src/ir/hot.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
  - ../string-gathering/index.md
  - ../reorder-globals-always/index.md
  - ../directize/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./size-model-and-dependency-order.md
  - ./wat-shapes.md
  - ./fuzzing.md
  - ../../../binary/leb128-and-integer-encoding.md
  - ../string-gathering/index.md
  - ../reorder-globals-always/index.md
  - ../directize/index.md
---

# Starshine Strategy For `reorder-globals`

Use this page together with the retained current-main freshness research recheck in [research note 0689](./index.md) and the owner/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that now own the direct pass, and the concrete neighboring implementation areas around the accepted public late-tail suffix and any broader widening beyond it.

## The honest current status

`reorder-globals` now has an active direct Starshine module-pass port in `src/passes/reorder_globals.mbt`.

The current local strategy is direct public-pass support plus explicit late-tail deferral:

- keep the public pass spelling active as a module pass
- keep `reorder-globals-always` boundary-only so the sibling policy is not collapsed into the production pass
- preserve Binaryen's public `<128` total-global no-op
- count whole-module global traffic and initializer dependencies over the complete imported-plus-defined index space
- reorder imported globals within the fixed import prefix as well as defined globals, preserve non-global import positions, and apply Starshine-specific numeric `GlobalIdx` remapping
- keep the accepted public late-tail suffix documented alongside the no-DWARF order, with any broader widening beyond it still gated on fresh evidence
- keep the final explicit-v131 regular `100000`, dedicated `10000`, random-all `10000`, and wasm-smith `10000` evidence recorded, alongside the inner `string-gathering -> reorder-globals -> directize` replay

So this page is now an **implementation status and late-tail follow-up** page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- active module-pass owner
  - [`src/passes/reorder_globals.mbt`](../../../../../src/passes/reorder_globals.mbt)
    - implements public cutoff, traffic counting, dependency sorting, candidate scoring, declaration reorder, and numeric index remapping
- focused direct-pass tests
  - [`src/passes/reorder_globals_test.mbt`](../../../../../src/passes/reorder_globals_test.mbt)
    - covers registry status, public cutoff, imported-only and mixed-import movement, non-global import-position preservation, hot 129th-defined-global movement, dependency preservation, export/global-name remapping, and stale raw-name clearing
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
  - [`agent-todo.md`](../../../../../agent-todo.md)
    - the dedicated `RG` replay blocker is closed; remaining broader-widening gating now lives under shared late-tail scheduling work
- canonical scheduler context
  - [`../../no-dwarf-default-optimize-path.md#L35`](../../no-dwarf-default-optimize-path.md#L35)
    - the canonical late-tail slot `string-gathering -> reorder-globals -> directize`
- neighboring living dossiers the accepted public late-tail suffix still must line up with
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
- scores candidates using true observed counts and estimated ULEB global-index byte widths; the shared binary byte-layer caveat is [`../../../binary/leb128-and-integer-encoding.md`](../../../binary/leb128-and-integer-encoding.md), while this pass uses encoder-size thresholds for profitability
- keeps imported globals before defined globals while sorting the imported-global subsequence by the same candidate policy
- rewrites global imports without moving non-global imports, reorders defined `global_sec` entries, and remaps numeric global references across module/code/name surfaces

### 2. The `always` sibling still rejects honestly

`reorder-globals-always` remains boundary-only. That keeps explicit requests for the small-module/internal-helper variant honest until the repo chooses to port that separate policy.

### 3. The remaining work is planned as a real parity slice, not an orphan idea

The old dedicated `RG` replay blocker is closed, and the post-legacy-EH v131 renewal is complete.
The 2026-07-29 audit also repaired the previously missing imported-global family. The delivered work covers:

- Binaryen-shaped reordering criteria
- safe remap after string gathering and other late global cleanup
- externally visible boundary and section invariants
- regressions for reordered globals with string users, exports, and directized tail interaction
- exact pass-owned comparison for every dedicated family, plus the proven inner late-tail replay
- bounded performance proof after replacing quadratic ready scans: `0.742 ms` Starshine versus `1.68593 ms` Binaryen on 2,000 imports, and `0.762 ms` versus `1.49234 ms` on a 2,000-global dependency chain; both outputs are byte-identical

That framing matches the upstream dossier better than a vague “sort globals by use count” summary would.

## The right Starshine implementation shape

The current docs, neighboring passes, and landed direct port teach `reorder-globals` as a **late module pass**, not as an isolated HOT peephole and not as a side effect of `string-gathering`.

Why:

- Binaryen runs it after `string-gathering`
- it is the second-to-last top-level pass in the canonical no-DWARF tail
- its correctness depends on whole-module declaration order, import-prefix preservation, initializer dependencies, and final global-index layout
- the completed v131 audit treats safe remapping as a first-class invariant with focused and generated coverage

So the local strategy should be thought of as:

1. keep the direct module pass focused on whole-module global traffic and initializer dependencies
2. choose a dependency-safe final declaration order with the reviewed Binaryen candidate families
3. apply imported-global and defined-global declaration reorders plus Starshine-specific numeric remapping
4. keep reduced export/name/dependency coverage green
5. validate string users, startup/global-initializer correctness, and final artifact parity in the real late-tail neighborhood once surrounding passes exist

In other words, the direct port has landed, while any broader widening beyond the accepted public suffix still belongs to the documented late optimization ecosystem.

## The most important local dependency map

### `reorder-globals` is downstream of `string-gathering`

See:

- [`../string-gathering/index.md`](../string-gathering/index.md)

Why it matters locally:

- the no-DWARF scheduler docs already place `reorder-globals` immediately after `string-gathering`
- the `string-gathering` dossier already teaches that its own internal reorder is only a validity repair for defining globals
- Starshine should keep the same division of labor explicit when any broader widening beyond the accepted public suffix lands: string gathering first for validity/canonicalization, final global layout second for size and declaration order

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
- public optimize/shrink scheduling is already landed for the accepted late-tail suffix; any broader widening that still starts earlier at `simplify-globals-optimizing -> remove-unused-module-elements` remains future work
- a replay of that broader scheduled late tail once the remaining earlier neighbors exist locally

So the current repo status is best summarized as:

- direct public transform landed
- `always` sibling still boundary-only
- broader late-tail widening deferred behind missing earlier neighbors
- reduced tests and explicit triple-neighborhood replay landed
- refreshed direct oracle proof recorded; remaining proof debt is now the broader scheduled late tail, not the inner triple

## Validation ladder for future changes

The completed audit plus the upstream dossier establish this validation order for future changes:

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
   - current direct evidence is recorded in [`./fuzzing.md`](./fuzzing.md): regular `100000/100000`, dedicated `10000/10000`, random-all classified, and all 9956 comparable wasm-smith cases green after one established cleanup normalization
   - the final native artifact and explicit official v131 oracle hashes are recorded there for replay

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow and the exact neighboring passes that should feed the port.

## Bottom line

Current Starshine `reorder-globals` strategy is direct public-pass support plus late-tail landing-zone planning:

- the pass implementation lives in [`src/passes/reorder_globals.mbt`](../../../../../src/passes/reorder_globals.mbt)
- focused coverage lives in [`src/passes/reorder_globals_test.mbt`](../../../../../src/passes/reorder_globals_test.mbt)
- `reorder-globals` is registered as an active module pass while `reorder-globals-always` remains boundary-only
- [`agent-todo.md`](../../../../../agent-todo.md) records the remaining broader-widening follow-up under shared scheduling work rather than a dedicated `RG` replay item
- the canonical slot is already documented in [`../../no-dwarf-default-optimize-path.md#L35`](../../no-dwarf-default-optimize-path.md#L35)
- the surrounding [`string-gathering`](../string-gathering/index.md), [`reorder-globals-always`](../reorder-globals-always/index.md), and [`directize`](../directize/index.md) dossiers define the remaining landing zone

So the right mental model today is:

- **public transform landed**
- **`always` sibling deferred**
- **broader late-tail widening deferred**
- **reduced reindexing tests landed**
- **full explicit-v131 four-lane direct matrix recorded; inner late-tail triple replay proven**
