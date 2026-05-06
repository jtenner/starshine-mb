---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0525-2026-05-06-reorder-globals-direct-revalidation.md
  - ../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-23-reorder-globals-primary-sources.md
  - ../../../raw/research/0367-2026-04-25-reorder-globals-current-main-and-test-map.md
  - ../../../raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md
  - ../../../raw/research/0270-2026-04-23-reorder-globals-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../../../../src/ir/hot.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./size-model-and-dependency-order.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../reorder-globals-always/implementation-structure-and-tests.md
  - ../string-gathering/implementation-structure-and-tests.md
  - ../directize/implementation-structure-and-tests.md
---

# `reorder-globals` implementation structure and tests

This page maps the source-backed implementation and proof surface for Binaryen `reorder-globals`, then maps the exact Starshine code locations a future local port would need to read first.

Use it as the quick answer to:

- “which upstream file owns this pass?”
- “which lit tests prove which behavior?”
- “why does Binaryen not need to patch every use site?”
- “why would Starshine need a numeric-index remap instead?”

## Current source anchor

- Tagged oracle: Binaryen `version_129`.
- Current-main bridge: the 2026-04-25 focused recheck in [`../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md).
- Result: no teaching-relevant drift found in the owner/helper/test surfaces reviewed for this page.

The older 2026-04-23 raw manifest remains useful for the original dossier provenance; the 2026-04-25 manifest is the source of truth for this implementation/test-map follow-up.

## Upstream owner and helper map

| Source | Role in the pass |
| --- | --- |
| `src/passes/ReorderGlobals.cpp` | Main owner file. It defines the use-count scanner, public vs `always` mode, `< 128` public cutoff, dependency graph construction, candidate ordering, true-count scoring, and final `module->globals` reorder. |
| `src/passes/pass.cpp` | Registers the public `reorder-globals` name, the `reorder-globals-always` sibling, and the late global-optimization post-pass placement after `string-gathering` and before `directize`. |
| `src/passes/passes.h` | Declares both pass constructors, keeping the public and `always` variants separate. |
| `src/pass.h` | Provides the walker `runOnModuleCode(...)` surface used after function-body counting. |
| `src/wasm-traversal.h` | Defines which module-level expression slots a module-code walk can visit, including global initializers, element/data offsets, and table initializer expressions. |
| `src/support/topological_sort.h` | Supplies the dependency-respecting minimal topological sort used by the candidate order builder. |
| `src/wasm.h` | Shows the important Binaryen representation fact: `GlobalGet` / `GlobalSet` name globals by `Name`, so the pass can reorder declarations and rebuild maps without rewriting every use operand. |
| `src/passes/GlobalStructInference.cpp` | Shows the strongest internal use of the sibling: after GSI creates helper globals, it runs `reorder-globals-always` to repair/order new global declarations even on small modules. |

## Main implementation phases

### 1. Count `global.get` and `global.set`

`ReorderGlobals.cpp` uses a tiny function-parallel walker that increments a count for each referenced global name.

Important facts:

- `global.get` and `global.set` both count as heat.
- The scan is static, not profile-driven.
- Ordinary function bodies are scanned first.
- Module-level expression code is scanned too through the module-code walk.

That last point is why this pass sees more than ordinary function traffic.

### 2. Convert name counts into original-index vectors

After scanning, Binaryen builds:

- a name-to-original-index table,
- a true-count vector indexed by original global position,
- and the dependency graph used by later candidates.

The true counts remain the final scoring objective even when a candidate order was generated with a synthetic count model.

### 3. Build initializer dependency edges

For every non-imported global initializer, Binaryen finds `global.get` uses.
If global `$b`'s initializer reads `$a`, `$a` must stay before `$b`.

This dependency scope is deliberately narrow:

- it is about declaration-order validity,
- not arbitrary function dataflow,
- not exports,
- not global names,
- and not dead-global elimination.

### 4. Try candidate orders

The pass tries four dependency-valid ranking stories:

1. all-zero counts, preserving the closest dependency-valid original order,
2. true counts, the simple hot-first greedy candidate,
3. full summed dependent counts, rewarding prerequisites that unlock hot dependents,
4. exponentially discounted dependent counts with the source-defined discount factor.

All candidates obey import-prefix order and initializer dependencies before profitability.

### 5. Score candidates with true encoded-index cost

The final cost is based on the true observed counts and the estimated byte width of each global index.

For the public pass, the important threshold is:

- fewer than `128` globals means every global index is still one-byte encoded, so the public pass returns early.

For `reorder-globals-always`, the sibling dossier covers the smooth synthetic cost model.

### 6. Apply by reordering Binaryen's global vector

Binaryen chooses the lowest-scoring candidate and reorders `module->globals`.

Because Binaryen uses global names in IR operands, this is much cheaper than it would be in a numeric-index IR:

- `global.get $g` and `global.set $g` still refer to `$g` after declaration movement.
- Binaryen only needs to refresh its internal global maps.

That is the key implementation difference a future Starshine port must not miss.

## Official test map

| Test source | What it proves most directly |
| --- | --- |
| `test/lit/passes/reorder-globals.wast` | Visible sorting behavior, mostly through `--reorder-globals-always`: hot independent globals move earlier, `global.set` contributes heat, initializer dependencies block illegal moves, import-first ordering wins over heat, original-order ties are stable, and summed-dependent ordering can beat raw greed. |
| `test/lit/passes/reorder-globals-real.wast` | Production public-pass policy: a 129-global module can reorder, a 129-global greedy-positive case is covered, and a 127-global module intentionally stays unchanged under public `reorder-globals`. |

The tests are complementary. Do not cite only `reorder-globals.wast` for the public production cutoff, and do not cite only `reorder-globals-real.wast` for every small pedagogical ordering family.

## Test-surface caveats

- The source computes an exponential dependent-count candidate, but the reviewed tests are clearest for the zero/raw/summed/public-cutoff families. Treat the exponential candidate as source-confirmed, not as a behavior isolated by one obvious lit fixture.
- `reorder-globals.wast` often uses the `always` sibling to make tiny examples visible. That is useful for teaching sort mechanics, but it is not proof that public `reorder-globals` reorders tiny modules.
- The `GlobalStructInference.cpp` internal caller belongs to the shared implementation story, but the sibling-specific behavior is maintained in [`../reorder-globals-always/implementation-structure-and-tests.md`](../reorder-globals-always/implementation-structure-and-tests.md).

## Current Starshine status map

Starshine now has a direct public-pass owner file for `reorder-globals`.

| Local source | Current role |
| --- | --- |
| `src/passes/reorder_globals.mbt` | Active module-pass implementation: public `<128` cutoff, module/code global traffic counts, initializer dependency matrix, Binaryen-shaped candidate ordering, true ULEB-size scoring, declaration reorder, and numeric `GlobalIdx` remapping. |
| `src/passes/reorder_globals_test.mbt` | Focused direct-pass coverage for registry status, public cutoff, 129-global reorder, dependency preservation, export remapping, and name-section remapping. |
| `src/passes/optimize.mbt` | Registers `reorder-globals` as a module pass while keeping `reorder-globals-always` boundary-only. |
| `src/passes/pass_manager.mbt` | Dispatches the active module pass. |
| `src/cmd/cmd_wbtest.mbt` | Covers explicit CLI acceptance for `--reorder-globals`. |
| `scripts/lib/pass-fuzz-compare-task.ts` | Lists `--reorder-globals` for direct compare harness runs. |
| `agent-todo.md` | Tracks completed direct-pass status plus late-tail scheduling follow-up. |
| `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:34-35` | Records the canonical late-tail slot: `string-gathering -> reorder-globals -> directize`. |
| `src/lib/types.mbt:91` | Defines numeric `GlobalIdx`, the core index type that a Starshine implementation must remap. |
| `src/lib/types.mbt:351-368` | Defines `Module` section storage, including `import_sec`, `global_sec`, `export_sec`, `elem_sec`, `code_sec`, and `data_sec`. |
| `src/lib/types.mbt:442` | Defines `GlobalSec(Array[Global])`, the declaration vector a local module pass would reorder. |
| `src/binary/encode.mbt:633-636` | Encodes `GlobalIdx` as an unsigned index, so final byte-size wins depend on numeric remapping. |
| `src/binary/decode.mbt:731-735` | Decodes `GlobalIdx`, confirming that binary roundtrip uses numeric global indices. |
| `src/validate/validate.mbt:949-965` | Validates const-expression `global.get` against imported or previously defined immutable globals, making declaration order a validation constraint. |
| `src/ir/hot.mbt:206-218` and `src/ir/hot.mbt:285-297` | Lifts `GlobalGet` / `GlobalSet` into HOT nodes with numeric indices, confirming that this pass is not naturally a function-local HOT peephole. |

## What the current Starshine implementation adds

The active direct Starshine port includes these pieces:

1. **Whole-module traffic counter**
   - count `global.get` and `global.set` in function bodies,
   - count module-level expression code that can contain globals,
   - keep static counts, not runtime profile assumptions.
2. **Initializer dependency graph**
   - preserve import prefix,
   - preserve `global.get` dependencies among global initializers,
   - validate against Starshine's const-expression rules.
3. **Binaryen-compatible ordering policy**
   - public `< 128` no-op,
   - `reorder-globals-always` kept separate as boundary-only,
   - zero/raw/sum/exponential candidate search.
4. **Numeric `GlobalIdx` remapper**
   - global declarations,
   - exports of globals,
   - function-body `global.get` / `global.set`,
   - module-code global references,
   - global-initializer dependencies,
   - binary encode/decode and validation-sensitive order.
5. **Late-tail scheduling proof**
   - still deferred until the full `string-gathering -> reorder-globals -> directize` neighborhood is replayed,
   - direct reduced shapes are covered now,
   - refreshed direct oracle evidence is recorded: `.tmp/pass-fuzz-reorder-globals` has `6759` comparable normalized matches with `0` mismatches and `20` known Binaryen empty-recursion-group parser/canonicalization command failures, while the older `.tmp/self-opt-reorder-globals-20260426-post-raw-name-clear` artifact lane remained canonical/normalized-WAT equal on the debug artifact.

## Non-goals

Do not treat `reorder-globals` as any of these:

- dead global elimination,
- string literal gathering,
- a local HOT rewrite,
- a generic global initializer validator,
- export-name minification,
- or a pass that always reorders small modules.

Those are neighboring concerns with their own dossiers.

## Sources

- [`../../../raw/research/0525-2026-05-06-reorder-globals-direct-revalidation.md`](../../../raw/research/0525-2026-05-06-reorder-globals-direct-revalidation.md)
- [`../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-reorder-globals-current-main-and-test-map.md)
- [`../../../raw/binaryen/2026-04-23-reorder-globals-primary-sources.md`](../../../raw/binaryen/2026-04-23-reorder-globals-primary-sources.md)
- [`../../../raw/research/0367-2026-04-25-reorder-globals-current-main-and-test-map.md`](../../../raw/research/0367-2026-04-25-reorder-globals-current-main-and-test-map.md)
- [`../../../raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md`](../../../raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md)
- [`../../../raw/research/0270-2026-04-23-reorder-globals-primary-sources-and-starshine-followup.md`](../../../raw/research/0270-2026-04-23-reorder-globals-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderGlobals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/topological_sort.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals-real.wast>
