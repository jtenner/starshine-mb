---
kind: research
status: supported
created: 2026-06-04
sources:
  - ../../../../agent-todo.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/global_struct_inference.mbt
  - ../../../../src/passes/global_struct_inference_test.mbt
  - ../../../../src/passes/atomic_pass_support_test.mbt
  - ../../../../src/ir/effects.mbt
  - ../../../../src/ir/hot_lift.mbt
  - ../../../../src/ir/hot_verify.mbt
  - ../../../../src/passes/local_cse.mbt
  - ../../../../src/passes/precompute.mbt
  - ../../../../src/passes/optimize_instructions.mbt
  - ../../../../src/passes/simplify_locals.mbt
  - ../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../src/passes/dead_argument_elimination.mbt
related:
  - ../../binaryen/passes/global-struct-inference/parity.md
  - ../../binaryen/passes/global-struct-inference/starshine-strategy.md
  - ../../wast/gc-aggregate-instruction-authoring.md
---

# Struct atomic get pass opportunity audit

## Question

After adding `StructAtomicGet`, `StructAtomicGetS`, and `StructAtomicGetU`, check every active Starshine optimizer pass for either a safe optimization opportunity or explicit conservative/no-op coverage. Keep aggregate atomic set/RMW/cmpxchg and array atomic forms out of scope.

The active pass set below is the current `src/passes/optimize.mbt` registry `HotPass` and `ModulePass` entries plus the `optimize` / `shrink` presets. Boundary-only and removed registry entries are not active optimizer passes for this audit.

## Durable conclusion

Only `global-struct-inference` has a currently proved struct-atomic-get optimization opportunity. Its proof is field immutability plus validation-safe replacement typing: when all possible immutable global instances expose a fixed field value, the atomic read has no write to synchronize with for that field, so GSI may preserve the original null trap and replace the read with the fixed value/origin/select.

Generic function/HOT passes must remain conservative. A `struct.atomic.get*` can trap on null, carries shared-GC atomic read semantics, and is not a linear-memory `MemArg` instruction. Do not classify it as pure or reusable just because its result type is ordinary scalar/reference. The existing guard surface models exact struct atomic gets as `HotOp::Atomic`, gives them memory-read plus trap effects, excludes them from local-CSE reuse, keeps precompute from deleting dropped reads, keeps optimize-instructions behind load-call barriers, and keeps simplify-locals from sinking loads across them.

## Implemented opportunities and guard coverage

- Implemented in GSI:
  - direct immutable-global `struct.atomic.get*` folds
  - closed-world local/param one-value and two-value singleton-select folds
  - direct immutable-global subtype reads where the global is declared at a parent/supertype but initialized with a subtype constructor
- Implemented generic guard coverage:
  - `src/ir/hot_lift.mbt` lifts struct atomic gets as exact `HotOp::Atomic` nodes without requiring `MemArg`
  - `src/ir/hot_verify.mbt` skips `MemArg` side-table verification only for exact struct atomic get nodes
  - `src/ir/effects.mbt` models struct atomic gets as memory-read plus trap
  - `src/passes/local_cse.mbt` rejects `HotOp::Atomic` CSE candidates
  - `src/passes/precompute.mbt`, `src/passes/optimize_instructions.mbt`, and `src/passes/simplify_locals.mbt` have regression coverage in `src/passes/atomic_pass_support_test.mbt`
  - `src/passes/duplicate_function_elimination.mbt`, `src/passes/remove_unused_module_elements.mbt`, and `src/passes/dead_argument_elimination.mbt` include `StructAtomicGet*` in type-index/use remapping or type-liveness walks

## Pass-by-pass classification

| Active pass | Classification | Struct-atomic-get decision |
| --- | --- | --- |
| `ssa-nomerge` | Deliberately conservative | SSA/local rewriting works through HOT effects and use-def. `StructAtomicGet*` is `HotOp::Atomic`, so no purity or motion opportunity is currently safe. |
| `vacuum` | Deliberately conservative | Cleanup may remove no-ops/debris but must not remove the exact atomic read; effect modeling keeps dropped atomic reads observable to DCE-like logic. |
| `dead-code-elimination` | Blocked by semantics | Atomic reads are effectful/trapping (`HotOp::Atomic`), so deleting a dropped `struct.atomic.get*` would be unsound. |
| `remove-unused-names` | Deliberately conservative no-op | Metadata/name cleanup has no instruction rewrite surface. |
| `remove-unused-brs` | Deliberately conservative no-op | Branch cleanup does not inspect field-read values; atomic reads remain ordinary effectful nodes when encountered. |
| `optimize-instructions` | Deliberately conservative with guard coverage | Existing regression proves struct atomic gets stay load-call barriers. Treating them as side-effect-free would be unsound. |
| `heap-store-optimization` | Blocked by semantics | HSO reasons about heap stores/allocations. Atomic reads require synchronization/trap preservation; immutable-field folding belongs to GSI's closed-world proof, not generic HSO. |
| `heap2local` | Blocked by semantics | Scalarizing a heap field read into a local would erase shared atomic read semantics unless non-escape/non-share proof is added; no such proof exists. |
| `optimize-casts` | Deliberately conservative no-op | Cast/test cleanup has no direct field-read optimization. Descriptor-cast interactions remain a separate GSI-desc-cast/refinalization question. |
| `pick-load-signs` | Out of scope / no-op | This pass rewrites linear-memory load signedness. `StructAtomicGetS/U` signedness is packed-field aggregate semantics, not a `MemArg` load. |
| `precompute` | Deliberately conservative with guard coverage | Existing regression proves dropped struct atomic gets are preserved. Precomputing them as constants would erase trap/synchronization semantics. |
| `code-pushing` | Blocked by semantics | Pushing computations across an atomic read needs ordering proof. Current effect barriers are the safe behavior. |
| `code-folding` | Deliberately conservative | Tail/code sharing must not duplicate, delete, or reorder effectful atomic reads; no get-specific fold is known. |
| `tuple-optimization` | Deliberately conservative | Tuple/local carrier cleanup is guarded around effect hazards; no field-read value proof exists here. |
| `simplify-locals` | Deliberately conservative with guard coverage | Existing regression proves loads are not sunk across struct atomic gets. |
| `simplify-locals-nostructure` | Deliberately conservative | Shares simplify-locals family hazards; no atomic-get-specific fold is safe without GSI-style immutability facts. |
| `simplify-locals-no-structure` | Deliberately conservative alias | Alias of the no-structure simplify-locals path; inherits the same decision. |
| `simplify-locals-notee-nostructure` | Deliberately conservative | No-tee/no-structure local cleanup should not treat `StructAtomicGet*` as pure. |
| `local-cse` | Deliberately conservative with guard coverage | Existing regression proves repeated struct atomic gets are not CSE-merged. |
| `merge-locals` | Deliberately conservative no-op | Local-index/type remapping has no field-read value optimization. |
| `merge-blocks` | Deliberately conservative no-op | Structural block flattening has no get-specific optimization and must preserve instruction order. |
| `redundant-set-elimination` | Deliberately conservative | RSE raw handling treats struct atomic get results as fresh values, not reusable facts; no safe value equality proof. |
| `avoid-reinterprets` | Deliberately conservative no-op | Reinterpret cleanup is unrelated to aggregate atomic reads. |
| `untee` | Deliberately conservative no-op | Local tee cleanup has no field-read value optimization and must preserve effect order. |
| `duplicate-function-elimination` | Implemented guard coverage | Function/type dedup remapping includes `StructAtomicGet*` type indices, preserving exact instructions while remapping types. |
| `remove-unused-module-elements` | Implemented guard coverage | Type/resource liveness and remapping include `StructAtomicGet*` type indices. No value optimization is attempted. |
| `remove-unused-nonfunction-module-elements` | Implemented guard coverage alias | Nonfunction RUME family inherits the same type-index/remap treatment. |
| `memory-packing` | Out of scope / no-op | Linear-memory/data packing does not optimize shared-GC aggregate reads. |
| `once-reduction` | Deliberately conservative no-op | Function/table once-use analysis has no aggregate field-read surface. |
| `global-refining` | Deliberately conservative no-op | Refines global types/initializers but does not fold field reads. Any created precision is consumed by GSI rather than generic atomic optimization. |
| `global-struct-inference` | Implemented | The only proved optimization owner: immutable-field direct-global, closed-world local/param, and direct-subtype struct atomic get folds. |
| `reorder-locals` | Deliberately conservative no-op | Local declaration/order cleanup does not change instruction semantics. |
| `local-subtyping` | Deliberately conservative | Local type refinement may improve validation precision but does not fold or move atomic reads. Future GSI interactions would need separate fixtures. |
| `coalesce-locals` | Deliberately conservative no-op | Local coalescing/remapping has no field-read value optimization and must preserve effect order. |
| `duplicate-import-elimination` | Deliberately conservative no-op | Import dedup/remapping does not touch aggregate field-read semantics. |
| `simplify-globals-optimizing` | Deliberately conservative | Global propagation can create simpler operands, but it has no safe proof for replacing `StructAtomicGet*`; GSI owns immutable-field folds. |
| `dae-optimizing` | Implemented guard coverage | DAE type-liveness walks include `StructAtomicGet*` type indices; argument/result rewrites must preserve effectful atomic reads. |
| `dead-argument-elimination-optimizing` | Implemented guard coverage alias | Alias of `dae-optimizing`; inherits the same decision. |
| `inlining` | Deliberately conservative | Inliner copies/preserves exact instructions; no atomic-get-specific fold. |
| `inlining-optimizing` | Deliberately conservative | Optimizing inliner inherits normal inlining preservation plus cleanup passes that remain conservative. |
| `no-inline` | Deliberately conservative no-op | Annotation-only pass. |
| `no-full-inline` | Deliberately conservative no-op | Annotation-only pass. |
| `no-partial-inline` | Deliberately conservative no-op | Annotation-only pass. |
| `string-gathering` | Deliberately conservative no-op | String-global gathering is unrelated to aggregate atomic reads. |
| `reorder-globals` | Deliberately conservative no-op | Reorders globals while preserving dependencies; no function-body atomic optimization. |
| `directize` | Deliberately conservative no-op | Table/call directization is unrelated to aggregate atomic reads. |
| `optimize` preset | Aggregate classification | Inherits the per-pass decisions above; do not add preset-specific atomic behavior. |
| `shrink` preset | Aggregate classification | Inherits the per-pass decisions above; do not add preset-specific atomic behavior. |

## Remaining risks and follow-ups

- Descriptor-cast/refinalization-shaped opportunities remain unimplemented. The current proved GSI surface is adjacent direct-global or closed-world local/param field reads.
- `StructAtomicGet*` still uses `HotOp::Atomic`, whose side-table helpers historically assumed linear-memory `MemArg` payloads. Existing exact-instruction guard coverage handles the current get surface, but future HOT-side atomic code must continue to check exact instruction shape before assuming a `MemArg`.
- Future aggregate `struct.atomic.set`, aggregate RMW/cmpxchg, and array atomic forms are out of scope. They need new opcodes, WAT/binary/validation support, effect modeling, and pass-specific proofs.

## Validation evidence

The behavior-changing GSI subtype-direct slice immediately before this audit used:

- `moon test src/passes` failed on the new subtype atomic fixture before implementation and passed after implementation (`1545/1545`).
- `moon fmt` passed.
- `moon test` passed (`4730/4730`).
- `moon build --target native --release src/cmd` passed with existing `pass_manager.mbt` unused-function warnings.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --keep-going-after-command-failures --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/pass-fuzz-global-struct-inference-atomic-subtype-direct-10000` produced 9975 / 10000 compared, 9975 normalized matches, 0 mismatches, 0 validation failures, and 25 Binaryen/tool command failures.
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --global-struct-inference --timing-only --out-dir .tmp/gsi-debug-artifact-timing-atomic-subtype-direct` was canonical-equal with Starshine/Binaryen pass-local `0.482 ms` / `3.038 ms`.

This audit itself is documentation/backlog classification work. It did not implement new non-GSI behavior.
