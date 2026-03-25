# Duplicate Function Elimination

## Scope
- Reconstruct Binaryen v125 `duplicate-function-elimination` as an explicit Starshine pass in `src/passes`.
- Match the direct-pass semantics Binaryen uses on the no-DWARF debug artifact, not a private fixpoint.
- Record the remaining parity gap after the pass lands.

## Oracle Shape
- Binaryen DFE is module-wide. It cannot be modeled as a single lifted-function hot pass because the merge decision and all rewrites depend on whole-module function indices.
- The direct pass is single-pass. It merges duplicates visible in the current module state, rewrites references once, and stops. A second explicit run can expose additional transitive merges.
- Imports are never candidates. Defined functions are compared in local-function space and then remapped back to absolute `FuncIdx` values after compaction.

## Equality Contract
- Candidate grouping is hash-first, exact-compare-second.
- The hash key has three inputs:
  - The canonicalized function type index.
  - The normalized function body plus locals.
  - The function-annotation list.
- Exact equality uses the same three dimensions. Matching bodies are not enough; differing annotations must block merges.
- Canonicalized function types are only available for the simple duplicate-type case:
  - `type_sec` is all single-rec entries.
  - Every entry is a plain function type.
  - No rec groups, supertypes, `describes`, or `descriptor` metadata are present.

## Rewrite Contract
- After choosing canonical survivors, the pass must rewrite every affected `FuncIdx` user:
  - `call`
  - `return_call`
  - `ref.func`
  - `export_sec`
  - `start_sec`
  - `elem_sec` function lists and function-containing expressions
  - global/table/data initializer expressions that may contain function references
- Function annotation and name sections must also be rewritten:
  - keep the canonical source name/annotation entry for merged targets
  - preserve sorted index order
  - drop duplicate rewritten entries

## Type Compaction
- Binaryen-style DFE parity needs a second step after merge selection settles: compact duplicate simple function type indices.
- This is separate from the merge itself.
- The pass first canonicalizes simple duplicate type indices inside function bodies for hashing/equality, then after merging it compacts the duplicate type entries and rewrites all surviving type-index uses.
- Type-name custom metadata in `name_sec.type_names` must be remapped as part of that compaction.

## Performance Plan
- Use a hash bucket map keyed by normalized body, canonical type, and annotations so the expensive exact comparison only runs inside small candidate buckets.
- Preserve a stable “first survivor wins” rule inside each bucket so rewrites are deterministic.
- Avoid rebuilding hot IR. The pass works directly on the module AST and only rewrites sections that can carry `FuncIdx` or `TypeIdx` references.

## Validation
- Land focused pass tests for:
  - direct reference rewriting
  - single-pass semantics
  - duplicate simple type compaction
  - annotation-aware non-merges
  - name/annotation section canonicalization
- Land CLI coverage for explicit `--duplicate-function-elimination`.
- Replay the oracle compare on `tests/node/dist/starshine-debug-wasi.wasm` with:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --duplicate-function-elimination`

## Current Status
- The pass now exists in `src/passes` as a module pass with `dfe_`-prefixed helpers.
- `moon test src/passes` passes.
- `moon test src/cmd` passes.
- The raw element-section mismatch against Binaryen is closed:
  - Starshine now re-canonicalizes compactable `funcref` element expressions back to the compact function-index form.
- `scripts/self-optimize-compare.ts` now records both whole-command wall time and pass-only runtime:
  - Starshine pass timing is parsed from traced `perf:timer name=pass:...` lines.
  - Binaryen pass timing is parsed from `wasm-opt --debug` `passes took ... seconds.` output.
- Direct debug-artifact replay still is not normalized-WAT-equal to Binaryen.

## Direct Artifact Replay
- Compare command:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir /tmp/starshine-dfe-compare --duplicate-function-elimination`
- Current result:
  - Starshine wasm size: `19541668`
  - Binaryen wasm size: `7865886`
  - Starshine wall time: `7558.604 ms`
  - Binaryen wall time: `1523.612 ms`
  - Starshine DFE pass time: `882.198 ms`
  - Binaryen DFE pass time: `156.806 ms`
  - normalized WAT equal: `no`
  - section-level replay via `wasm-tools objdump`:
    - Starshine: `types=135`, `imports=19`, `functions=9111`, `elements=1617 bytes`, `code=7442469 bytes`, `custom "name"=11845400 bytes`
    - Binaryen: `types=137`, `imports=19`, `functions=9111`, `elements=1617 bytes`, `code=7612089 bytes`, no `name` section
- Inference from the replay:
  - Binaryen drops the `name` section on this direct DFE output, which explains the largest raw size gap.
  - The remaining drift is not element-shape drift anymore:
    - Starshine compacts the type section more aggressively (`135` vs `137`).
    - `code` bytes still differ after direct DFE.
  - Runtime parity is still open:
    - Starshine remains materially slower than Binaryen on the MoonBit debug artifact for both whole-command time and pass-only time.
  - The function-count parity is good, but exact direct-pass artifact parity is still unresolved.

## Open Questions
- Determine exactly which sections account for the raw size gap on the debug artifact:
  - confirmed: preserved `name` metadata
  - closed: the `elements` delta was an element-kind canonicalization gap
  - still open: the `types` and `code` deltas after direct DFE
- Determine what runtime target is realistic for Starshine DFE on the MoonBit debug artifact:
  - current pass-only replay is `882.198 ms` for Starshine vs `156.806 ms` for Binaryen
  - the remaining work is identifying whether the gap is mostly candidate-key construction, duplicate-bucket management, or some still-unnecessary module metadata path
- Decide whether direct-pass parity should target:
  - exact raw wasm parity
  - normalized semantic parity plus separately tracked metadata/serialization drift
