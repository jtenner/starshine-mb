# Binaryen No-DWARF Default Optimize Path

## Scope

- Record the canonical `wasm-opt version 125` default `-O` / `-Os` optimization path when DWARF preservation is not active.
- Anchor the result to the real MoonBit debug artifact at `tests/node/dist/starshine-debug-wasi.wasm`.
- Capture both the top-level ordered pass list and the nested re-optimization subpipelines entered by later optimizing passes.
- Provide a single document that `agent-todo.md` can target with pass-specific line anchors until dedicated per-pass docs are spun out.

## Current Behavior

- Binaryen's default optimizer is `PassRunner::addDefaultOptimizationPasses()`, which always expands to:
  `addDefaultGlobalOptimizationPrePasses() -> addDefaultFunctionOptimizationPasses() -> addDefaultGlobalOptimizationPostPasses()`.
- `-O` is equivalent to `-Os`, which means `optimizeLevel=2` and `shrinkLevel=1`.
- Every pass in the default path is added through `addIfNoDWARFIssues(...)`.
- `addIfNoDWARFIssues(...)` only skips a pass when that pass invalidates DWARF and `shouldPreserveDWARF()` returns `true`.
- `shouldPreserveDWARF()` only returns `true` when both `options.debugInfo` is enabled and the module contains `.debug_*` custom sections.
- The MoonBit debug artifact used here has a `name` custom section but no `.debug_*` custom sections, so it runs the unrestricted no-DWARF path.
- `wasm-opt --all-features --print-features tests/node/dist/starshine-debug-wasi.wasm` reports the artifact enables:
  `threads`, `mutable-globals`, `nontrapping-float-to-int`, `simd`, `bulk-memory`, `sign-ext`, `exception-handling`, `tail-call`, `reference-types`, `multivalue`, `gc`, `memory64`, `relaxed-simd`, `extended-const`, `strings`, `multimemory`, `stack-switching`, `shared-everything`, `fp16`, `bulk-memory-opt`, `call-indirect-overlong`, and `custom-descriptors`.
- Those feature flags matter because the default path conditionally adds `heap-store-optimization`, `tuple-optimization`, `heap2local`, `optimize-casts`, `local-subtyping`, `gsi`, and `string-gathering`.

## Source Anchors

- Binaryen preset expansion:
  `version_125/src/passes/pass.cpp:619-827`.
- No-DWARF gating:
  `version_125/src/passes/pass.cpp:610-617` and `version_125/src/passes/pass.cpp:1089-1100`.
- DWARF preservation predicate:
  `version_125/src/wasm/wasm-debug.cpp:106-108`.
- Post-inlining nested rerun helper:
  `version_125/src/passes/opt-utils.h:34-58`.
- `inlining-optimizing` nested rerun entry:
  `version_125/src/passes/Inlining.cpp:1434-1441`.
- `dae-optimizing` nested rerun entry:
  `version_125/src/passes/DeadArgumentElimination.cpp:466-468`.
- `simplify-globals-optimizing` nested rerun entries:
  `version_125/src/passes/SimplifyGlobals.cpp:415-423` and `version_125/src/passes/SimplifyGlobals.cpp:454-458`.

## Top-Level Ordered Path

For `wasm-opt tests/node/dist/starshine-debug-wasi.wasm -O --all-features`, the no-DWARF top-level path is:

1. `duplicate-function-elimination`
2. `remove-unused-module-elements`
3. `memory-packing`
4. `once-reduction`
5. `global-refining`
6. `remove-unused-module-elements`
7. `gsi`
8. `ssa-nomerge`
9. `dce`
10. `remove-unused-names`
11. `remove-unused-brs`
12. `remove-unused-names`
13. `optimize-instructions`
14. `heap-store-optimization`
15. `pick-load-signs`
16. `precompute`
17. `code-pushing`
18. `tuple-optimization`
19. `simplify-locals-nostructure`
20. `vacuum`
21. `reorder-locals`
22. `remove-unused-brs`
23. `heap2local`
24. `optimize-casts`
25. `local-subtyping`
26. `coalesce-locals`
27. `local-cse`
28. `simplify-locals`
29. `vacuum`
30. `reorder-locals`
31. `coalesce-locals`
32. `reorder-locals`
33. `vacuum`
34. `code-folding`
35. `merge-blocks`
36. `remove-unused-brs`
37. `remove-unused-names`
38. `merge-blocks`
39. `precompute`
40. `optimize-instructions`
41. `heap-store-optimization`
42. `rse`
43. `vacuum`
44. `dae-optimizing`
45. `inlining-optimizing`
46. `duplicate-function-elimination`
47. `duplicate-import-elimination`
48. `simplify-globals-optimizing`
49. `remove-unused-module-elements`
50. `string-gathering`
51. `reorder-globals`
52. `directize`

## Nested Rerun Shape

- `dae-optimizing` does not end at the top-level pass boundary.
  When it rewrites callsites or localizes arguments and `optimize=true`, it runs `OptUtils::optimizeAfterInlining(...)` on the changed functions.
- `inlining-optimizing` also does not end at the top-level pass boundary.
  After inlining, it builds a nested filtered pass runner for the touched functions and then calls `OptUtils::addUsefulPassesAfterInlining(...)`.
- `OptUtils::addUsefulPassesAfterInlining(...)` prepends `precompute-propagate` and then reruns the full default function optimization pipeline on the affected functions only.
- `simplify-globals-optimizing` has a different nested shape.
  It reruns `addDefaultFunctionOptimizationPasses()` on functions changed by constant-global replacement or removed `global.set` writes, but it does not prepend `precompute-propagate`.
- The practical consequence for Starshine parity is that top-level preset expansion is necessary but not sufficient.
  The optimizing global passes also need their nested cleanup subpipelines to land in the same order.

## Correctness Constraints

- Preserve the pre/function/post phase split, not just the flat pass inventory.
- Preserve repeated cleanup passes.
  `remove-unused-names`, `remove-unused-brs`, `vacuum`, `reorder-locals`, `coalesce-locals`, `precompute`, `optimize-instructions`, `heap-store-optimization`, `merge-blocks`, and `duplicate-function-elimination` all intentionally recur.
- Preserve feature gates.
  The MoonBit debug artifact needs the GC, multivalue, and string-gated passes to exist in the default path.
- Preserve the no-DWARF branch condition exactly.
  The unrestricted path is only valid when DWARF preservation is inactive; a future DWARF-preserving scheduler must be able to skip DWARF-invalidating passes.
- Preserve nested re-optimization behavior inside `dae-optimizing`, `inlining-optimizing`, and `simplify-globals-optimizing`.
- Keep validation and normalization parity grounded in the MoonBit debug artifact, not just toy WAT fixtures.

## Validation Plan

- Use `wasm-opt tests/node/dist/starshine-debug-wasi.wasm -O --all-features --debug` as the canonical order oracle.
- Use `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` for single-pass parity checks and ordered multi-pass replay where the current Starshine surface can express the same sequence.
- Keep unit and whitebox tests close to the implementing file for:
  pass-local rewrites, scheduler expansion, nested optimizing reruns, and artifact-level command coverage.
- When a pass changes exported or public CLI behavior, update the active dispatcher coverage in `src/cmd/cmd.mbt`.

## Performance Impact

- The heavy cost centers in the observed MoonBit artifact run are `coalesce-locals`, `optimize-casts`, `code-folding`, `merge-blocks`, and the early `ssa-nomerge` conversion.
- The repeated cleanup passes are still part of the intended Binaryen shape even when individually cheap.
- Nested reruns mean late global passes can trigger additional hot-path work that does not show up if Starshine models the preset as a single flat list only.

## Open Questions

- Whether Starshine should represent nested reruns as explicit preset subgraphs instead of burying them inside individual pass implementations.
- Whether the no-DWARF pathway should be split into dedicated per-pass docs once the first batch of ports starts landing.
- Whether the future DWARF-preserving mode should be tracked in a sibling doc or as a follow-up section here.

## Pass Reference Index

### DFE - Duplicate Function Elimination

- Appears first as the cheap pre-pass dedupe and again after inlining-driven graph changes expose more duplicates.
- Implementation must compare defined functions only, then rewrite every surviving `FuncIdx` user before compacting function/code storage.

### RUME - Remove Unused Module Elements

- Runs before heavy work, after early GC refinement, and again near the end after global simplification.
- Implementation must remove dead module-scope items without breaking imports, exports, start, elements, tables, globals, or data-count expectations.

### MP - Memory Packing

- Runs unconditionally before the main function pipeline.
- Implementation must preserve data segment semantics while shrinking or merging memory layout opportunities the same way Binaryen does.

### OR - Once Reduction

- Runs once in the pre-pass phase for `optimizeLevel >= 2`.
- Implementation must collapse `once`-style scaffolding without changing side-effect ordering or observable traps.

### GR - Global Refining

- The first GC-gated refinement pass in the default path for this artifact.
- Implementation must refine global types conservatively enough to unlock later `gsi` and cleanup passes without breaking external boundaries.

### GSI - Global Struct Inference

- Runs after global refinement and the second early module cleanup.
- Implementation must infer tighter struct facts from whole-module usage and feed later GC-sensitive rewrites.

### SSA - SSA No-Merge

- Starts the function pipeline because `-O` maps to shrink level 1.
- Implementation must untangle locals into semi-SSA form without introducing new merge copies that later cleanup must undo.

### DCE - Dead Code Elimination

- First function-local cleanup after semi-SSA conversion.
- Implementation must delete unreachable or dead-result structure while preserving trapping behavior and structured control validity.

### RUN - Remove Unused Names

- Runs three times in the top-level function path.
- Implementation must prune stale labels and names opened up by DCE, branch cleanup, and later block merges.

### RUB - Remove Unused Brs

- Runs early, mid, and late in the function pipeline.
- Implementation must remove dead branch edges and repair structured regions so later `merge-blocks` can compress safely.

### OI - Optimize Instructions

- Runs once early and once late.
- Implementation must perform peephole rewrites that are valid before and after broader CFG and local cleanup.

### HSO - Heap Store Optimization

- Runs in both instruction-optimization slots because the artifact has GC enabled.
- Implementation must fold or eliminate heap stores only when GC field/value semantics stay exact.

### PLS - Pick Load Signs

- Runs once in the early function phase for `optimizeLevel >= 2`.
- Implementation must choose smaller or more canonical load signedness without changing observable integer semantics.

### PC - Precompute

- Runs once early and once late for `-O` / `-Os`; the artifact does not take the `precompute-propagate` top-level branch.
- Implementation must fold constants and local evaluable fragments conservatively enough to compose with repeated late cleanup.

### CP - Code Pushing

- Runs once in the early function phase because `optimizeLevel >= 2`.
- Implementation must move computations deeper into control flow only when duplicated work and side effects remain valid.

### TO - Tuple Optimization

- Runs because the artifact enables multivalue.
- Implementation must simplify tuple construction and extraction before local cleanup without invalidating multivalue typing.

### SLNS - Simplify Locals No-Structure

- The first major local cleanup pass before `vacuum` and `reorder-locals`.
- Implementation must simplify local traffic without introducing new structured return values or reshaping blocks in ways that hurt coalescing.

### VQ - Vacuum

- Runs four times as the generic garbage collector for prior rewrites.
- Implementation must delete detached nop-like residue and empty structure without hiding bugs behind destructive cleanup.

### RL - Reorder Locals

- Runs three times to normalize local layout after simplification and coalescing.
- Implementation must preserve observable indices at external boundaries while reordering internal locals for size and later analysis quality.

### H2L - Heap2Local

- Runs once in the mid-function GC slice because `optimizeLevel > 1`.
- Implementation must replace eligible heap traffic with locals only when aliasing, escape, and lifetime constraints make the rewrite exact.

### OC - Optimize Casts

- Runs once after `heap2local`.
- Implementation must remove or tighten ref casts only when subtype and nullability facts stay exact across GC references.

### LS - Local Subtyping

- Runs once immediately after `optimize-casts`.
- Implementation must narrow local types before coalescing so later merges do not force wider supertypes than Binaryen keeps.

### CL - Coalesce Locals

- Runs twice in the function pipeline.
- Implementation must merge compatible locals without changing read-after-write behavior, tuple scratch use, or debug-artifact validity.

### LCSE - Local CSE

- Runs once in the mid-function cleanup because `shrinkLevel >= 1`.
- Implementation must reuse equivalent local computations without crossing side-effect or trap boundaries.

### SL - Simplify Locals

- Runs once after the first coalescing/CSE cluster.
- Implementation must finish the local cleanup that `simplify-locals-nostructure` intentionally left alone.

### CF - Code Folding

- Runs once in the late function pipeline because `shrinkLevel >= 1`.
- Implementation must merge duplicate code regions without disturbing labels, tuple semantics, or later branch cleanup.

### MB - Merge Blocks

- Runs twice in the late function cleanup.
- Implementation must collapse nested block structure exactly enough to expose dead branches while preserving typed block signatures.

### RSE - Redundant Set Elimination

- Runs once right before the final `vacuum`.
- Implementation must remove redundant writes after coalescing and late peepholes without losing ordering or trap behavior.

### DAE - Dead Argument Elimination Optimizing

- First late global optimizing pass.
- Implementation must remove provably dead call parameters and then rerun the nested post-inlining cleanup pipeline on touched functions.

### INL - Inlining Optimizing

- Second late global optimizing pass.
- Implementation must apply Binaryen's inlining heuristics, rewrite callsites, delete now-dead functions, and run the same nested post-inlining cleanup pipeline.

### DIE - Duplicate Import Elimination

- Runs immediately after the second duplicate-function-elimination pass.
- Implementation must merge import entries only when module/name/type identity and all external references remain exact.

### SGO - Simplify Globals Optimizing

- Runs late, before the final module cleanup.
- Implementation must replace constant-global reads and delete dead `global.set`s, then rerun the default function pipeline on each mutated function.

### SG - String Gathering

- Runs because the artifact enables strings and `optimizeLevel >= 2`.
- Implementation must gather or canonicalize string data just before `reorder-globals`.

### RG - Reorder Globals

- Runs once near the end because `shrinkLevel >= 1`.
- Implementation must reorder globals for the same cost model Binaryen uses after string gathering and global cleanup.

### DIR - Directize

- Final top-level pass in the no-DWARF default path.
- Implementation must turn eligible indirect calls into direct ones without overstepping module-boundary or table-behavior constraints.
