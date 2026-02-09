# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

## Project Structure

- MoonBit packages are organized per directory, for each directory, there is a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (common, ending in `_test.mbt`) and whitebox test files
  (ending in `_wbtest.mbt`). This project in particular puts relevant tests in
  the same file where the methods are located logically.

- In the toplevel directory, this is a `moon.mod.json` file listing about the
  module and some meta information.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.
- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory, with each function marked with `#deprecated` comment.
- Prefer using constructor methods instead of open structs directly
  ```mbt
  let a = A::{x: 1, y: 2} // bad
  let a = A::new(1, 2) // good
  ``` 
- If a data structure is needed for optimization, it should be added to `IRContext` instead of being passed around as parameters, especially if it can be used for other passes.
- "Pass" parameters can be passed to the function that construct the pass, but should be immutable, and enclosed over via the `ModuleTransformer` event functions 

## Tooling

- `moon fmt` is used to format your code properly.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check the test is passed. MoonBit supports snapshot
  testing, so when your changes indeed change the behavior of the code, you
  should run `moon test --update` to update the snapshot.

- You can run `moon check` to check the code is linted correctly.

- When writing tests, you are encouraged to use `inspect` and run
  `moon test --update` to update the snapshots, only use assertions like
  `assert_eq` when you are in some loops where each snapshot may vary. You can
  use `moon coverage analyze > uncovered.log` to see which parts of your code
  are not covered by tests.

- `./agent-todo.md` has some small tasks that are easy for AI to pick up, agent is
  welcome to finish the tasks and check the box when you are done

## Project structure

- `src/lib/*.mbt` contains the core IR data structures and types, the `types.mbt`
  file contains the main definitions.
  - `src/lib/arbitrary.mbt` contains trait definitions for typical arbitrary generation of types for use with binary spec fuzzing and testing
  - `src/lib/eq.mbt` contains trait definitions for equality comparison of types
  - `src/lib/show.mbt` contains trait definitions for pretty-printing of types
  - `src/lib/texpr.mbt` contains methods for converting between the tree-based `TExpr` and linear `Expr` types
- `src/ir/*.mbt` contains IR-specific passes and utilities
  - `src/ir/types.mbt` contains the main definitions of the IR data structures and types  
  - `src/ir/gvn.mbt` contains the implementation of the Global Value Numbering (GVN) optimization pass
  - `src/ir/liveness.mbt` contains the implementation of the liveness analysis pass
  - `src/ir/ir_context.mbt` contains the state of the IR during transformation, used with `ModuleTransformer` struct to help build module pass optimizers
- `src/passes/*.mbt` contains various optimization passes implemented using `ModuleTransformer` and `IRContext`
- `src/validate/*.mbt` contains utilities for validating and typechecking modules, should follow WebAssembly 3.0 specification
- `src/wast/*.mbt` contains utilities for parsing and pretty-printing of the s-expression text format of WebAssembly
- `src/binary/*.mbt` contains utilities for encoding and decoding the binary format of WebAssembly
- `src/transformer/*.mbt` contains the `ModuleTransformer` struct and utilities for building module passes
- `src/dataflow/*.mbt` contains a fragmented implementation of a dataflow framework for building dataflow analyses and optimizations, but is not well-integrated with the rest of the IR passes and utilities. Should be deprecated and integrated into `IRContext` instead

## Pass pipeline notes (learned)

- `src/passes/optimize.mbt` is the central pass scheduler. `optimize_module` first runs `lift_to_texpr_pass()`, then executes the selected `ModulePass` variants in order.
- The preferred pass integration pattern is: each pass file exposes a small constructor that returns `ModuleTransformer[IRContext]` (or `Result[ModuleTransformer[IRContext], String]` when setup can fail), and `optimize_module` just dispatches to those constructors.
- The following adapter constructors exist in pass files for this pattern:
  - `avoid_reinterprets_pass`
  - `coalesce_locals_pass`
  - `code_folding_ir_pass`
  - `code_pushing_ir_pass`
  - `const_hoisting_ir_pass`
  - `constant_field_propagation_ir_pass`
  - `directize_ir_pass`
  - `heap2local_ir_pass`
  - `heap_store_optimization_ir_pass`
  - `optimize_casts_ir_pass`
- `src/passes/util.mbt` contains `wrap_unit_func_pass` for adapting `ModuleTransformer[Unit]` function-level passes into `ModuleTransformer[IRContext]`.
- `src/passes/dataflow_opt.mbt` is SSA-backed: it uses `IRContext.optimize_body_with_ssa()` and is the intended replacement path over the deprecated `src/dataflow/*` package.
- `src/passes/dead_argument_elim.mbt` is integrated into `ModulePass::DeadArgumentElimination` and follows the same transformer-constructor pattern.
- Dead argument elimination handles "unseen" call edges (exports/start/table/ref.func) by keeping original signatures stable and creating internal optimized clones plus adapter thunks, then remapping direct calls to the cloned targets.
- `src/passes/optimize.mbt` now includes these additional `ModulePass` variants and dispatch paths:
  - `DuplicateImportElimination`
  - `GlobalTypeOptimization`
  - `GUFA`
  - `GUFAOptimizing`
  - `GUFACastAll`
  - `LocalCSE`
  - `LocalSubtyping`
- `GUFAOptimizing` currently runs GUFA and then follows up with:
  - `dead_code_elimination_ir_pass`
  - `code_folding_ir_pass`

## Global Type Optimization notes (learned)

- `src/passes/global_type_optimization.mbt` implements a Binaryen-style whole-module struct field optimizer and is wired into `ModulePass::GlobalTypeOptimization`.
- Analysis currently tracks field reads/writes from `struct.get*` / `struct.set` and propagates that data across supertypes/subtypes before deciding immutability/removals.
- The pass skips public-facing heap types (derived from imports/exports signatures and exported externs) to avoid changing external type contracts.
- Field removals update both type definitions and instruction uses:
  - `struct.new` operands are removed/reordered
  - `struct.get*` / `struct.set` field indices are remapped
  - removed `struct.set` operations are replaced with side-effect-preserving drops and null-trap preservation
- Module-level `Expr` initializers are rewritten by converting through `to_texpr` / `TExpr::to_expr`; removed potentially-trapping initializer operands are preserved by synthesizing extra immutable globals.

## Heap2Local notes (learned)

- `src/passes/heap2local.mbt` is integrated as `ModulePass::Heap2Local` in `src/passes/optimize.mbt`.
- The pass is conservative and local-based:
  - candidate allocations are tracked from `local.set` of `struct.new` / `struct.new_default` and fixed-size `array.new*` forms
  - locals are optimized only when all `local.get` uses are exclusive/safe (`struct.get/set`, fixed-index `array.get/set`, `array.len`, dropped gets)
  - any escaping or mixed local usage (calls, non-constant array indexes, non-allocation writes, tees) blocks optimization for that local
- Rewriting lowers heap fields/elements to dedicated locals:
  - allocation sites become field/element local initialization blocks
  - `struct.get/set` and fixed-index `array.get/set` become `local.get/set`
  - `array.len` becomes a constant
  - dropped allocation references become `nop`
- Packed storage is now supported in local form:
  - `struct.get_s/u` / `array.get_s/u` are preserved via explicit sign/zero-extension on local reads
  - packed writes are masked on local stores so slot values match wasm packed field semantics.
- `Heap2Local` now rewrites additional non-escaping ref uses:
  - `ref.is_null` on optimized allocations to `i32.const 0`
  - `ref.eq` on optimized allocations to constant outcomes with side-effect preservation for non-local operands.
- Candidate acceptance now includes a `LocalGraph` influence check:
  - each `local.get` for a candidate local must trace only to matching allocation-producing sets
  - candidate locals are rejected if a get can see `InitValue` or non-matching sets.
- Additional safety filter rejects candidates with non-uniform conditional sets:
  - if a candidate local is assigned in only one arm of an `if`, it is not optimized.
- Fixed-size array OOB constant-index accesses are now lowered with trap-preserving rewrites:
  - `array.get*` OOB becomes `unreachable`
  - `array.set` OOB becomes `block(drop(value), unreachable)` so value side effects are preserved.
- Heap2Local now supports additional non-escaping fixed-size array initializers:
  - `array.new_data` with constant offset/len is lowered into local slot initialization by decoding passive data segment bytes for supported storage types (`i8/i16` packed, `i32/i64/f32/f64`)
  - `array.new_elem` with constant offset/len is lowered into local slot initialization for function/constant ref element entries
  - constant out-of-bounds `array.new_data`/`array.new_elem` initializers are folded to `unreachable` (trap parity).
- Additional ref-use parity in current IR scope:
  - wrapped references via `ref.as_non_null(local.get ...)` are now handled for struct/array get/set/len and drop/is-null patterns
  - `ref.test` on optimized allocations is folded to `i32.const 0/1` via heap-type compatibility checks.
- Candidate safety is stricter for control flow:
  - locals are rejected when allocation-producing `local.set` values can transfer control flow and the local may be read later.
- Heap2Local now runs iteratively (bounded rounds) per function, re-running analysis/rewrite to pick up opportunities created by prior rewrites.
- Descriptor-specific Binaryen behavior (`ref.cast_desc_eq`, `ref.get_desc`, descriptor-bearing `struct.new`) is currently out of scope because those ops are not present in this project’s wasm3.0 IR surface.

## Heap Store Optimization notes (learned)

- `src/passes/heap_store_optimization.mbt` is integrated as `ModulePass::HeapStoreOptimization` in `src/passes/optimize.mbt`.
- The pass currently implements Binaryen-style folding of `struct.set` into an immediately-related `struct.new`:
  - nested tee pattern: `struct.set(..., local.tee $x (struct.new ...), value)`
  - list pattern: `local.set $x (struct.new ...)` followed by one or more `struct.set (local.get $x) ...`
- The pass performs conservative effect checks before reordering/folding:
  - local read/write conflicts on the reference local
  - conflicts with later `struct.new` operands crossed by moved values
  - fallback preservation of replaced operand side effects via `drop(old), new` sequences
- `struct.new_default` is materialized to explicit defaults when folding.
- Branchy-value local-set skipping now uses a `LocalGraph`-based `canSkipLocalSet` check:
  - candidate folds are allowed when later `local.get`s cannot read the would-be-skipped `local.set`
  - this replaces the previous purely linear “any later local.get blocks branchy folds” guard.
- Added explicit `struct.new` shallow invalidation checks against folded `set_value` effects (Binaryen-style `ShallowEffectAnalyzer(new_).invalidates(setValueEffects)` parity intent):
  - rejects reordering when `set_value` has memory/global/call/trap-relevant effects that cannot move safely ahead of allocation/trap points.
- Inline parity tests now cover:
  - legal branchy skip cases that were previously rejected due linear local.get scanning
  - required rejection cases when later reads can still observe the skipped local-set value
  - mixed-effect reorder hazards (call/global side effects) that must block folding.

## GUFA notes (learned)

- `src/passes/gufa.mbt` now uses a local `ContentOracle` + `PossibleContents` domain to infer:
  - unreachable values
  - scalar constants (currently `i32`, `i64`, `f32`, `f64`)
  - reference singleton values (`ref.null`, `ref.func`)
  - refined reference types (`PCRefType`)
- The oracle is intentionally local/flow-sensitive in function traversal:
  - local contents are tracked across `local.set` / `local.tee`
  - local contents are merged across `if` boundaries by intersecting per-branch known bindings (and for no-`else`, intersecting `then` with pre-branch state)
  - local contents are still cleared at `block` / `loop` / `try_table` boundaries to avoid unsound merges
- Immutable globals with constant initializers now contribute known oracle contents for:
  - `i32.const`, `i64.const`, `f32.const`, `f64.const`
  - `ref.null`, `ref.func`
- GUFA optimizations now use oracle queries where applicable:
  - `ref.eq`, `ref.test`, `ref.cast`, `ref.as_non_null`
  - `ref.is_null`
  - `i32.eqz`, `i64.eqz`
  - leaf replacement for `local.get` / `global.get` when content is known and type-compatible
- `GUFACastAll` adds casts when inferred ref type is a strict subtype of declared ref type.

## Global Struct Inference notes (learned)

- `src/passes/global_struct_inference.mbt` is integrated in `src/passes/optimize.mbt` as:
  - `ModulePass::GlobalStructInference`
  - `ModulePass::GlobalStructInferenceDescCast`
- Analysis is closed-world style in current pipeline behavior:
  - tracks struct types created in function bodies and marks them unoptimizable
  - tracks immutable-global root `struct.new` / `struct.new_default` initializers as candidates
  - rejects candidate roots when global declared type is not `eqref`-compatible or when the global is mutable
  - propagates both candidate globals and unoptimizable status through the subtype/supertype graph.
- Rewriting currently targets `struct.get`, `struct.get_s`, `struct.get_u` on immutable fields and supports:
  - singleton/global-known replacement with null-trap preservation (`ref.as_non_null` + `drop`)
  - two-value `select` + `ref.eq` rewrites with constant-value grouping
  - non-constant field-value handling by materializing reads from known immutable globals (`struct.get* (global.get ...)`) instead of adding new globals.
- Descriptor-cast mode flag is intentionally wired for parity but is currently a no-op in this IR surface (no descriptor instructions exposed yet); explicit regression tests now document that behavior.

## I64 To I32 Lowering notes (learned)

- `src/passes/i64_to_i32_lowering.mbt` is integrated in `src/passes/optimize.mbt` as `ModulePass::I64ToI32Lowering`.
- The pass lowers i64 ABI/storage to i32 pairs in current IR by:
  - rewriting function signatures (`i64` params -> two `i32`s, single `i64` return -> `i32`)
  - splitting defined i64 globals into low/high i32 globals, plus appending a mutable return-high global
  - rewriting function bodies with a per-function i32 stash local for high bits, and extra temp locals as needed for evaluation order.
- Implemented instruction-level lowering includes:
  - `local.get/set/tee`, `global.get/set`, direct/indirect/ref calls (including i64 arg expansion and i64 return stashing)
  - i64-result `return_call` / `return_call_indirect` / `return_call_ref` are lowered to non-tail call+return forms
  - i64 const, load/store, `select` (typed + untyped numeric i64), `return`
  - i64 unary/binary lowering now includes `ctz`, `popcnt`, `mul`, `div_{s,u}`, `rem_{s,u}`, `rotl`, `rotr` in addition to arithmetic/bitwise/shift/compare families
  - float/int cross-lowering parity for i64 conversion families:
    - `i64.trunc_f32/f64_{s,u}` lowered via split high/low arithmetic
    - `i64.trunc_sat_f32/f64_{s,u}` lowered via non-trapping split high/low arithmetic
    - `f32/f64.convert_i64_{s,u}` lowered via `f64` recomposition then optional demotion
    - `i64.reinterpret_f64` / `f64.reinterpret_i64` lowered through scratch memory at address 0.
- Additional behavior constraints learned:
  - untyped numeric `select` must be lowered for i64 and preserve Wasm operand evaluation order (`if_true`, `if_false`, then `condition`)
  - typed i64 control-flow results (`block` / `loop` / `if` / `try_table`) are rewritten to i32 result types while preserving high bits in the stash
  - implicit i64 tail-return detection must consider `TypeIdx` block types using pre-lowering type signatures; relying only on `ValTypeBlockType` misses real i64-return paths
  - explicit `return`-terminated i64 functions must not receive an extra implicit tail wrapper.
- Current explicit limitations (return `Err(...)`):
  - imported i64 globals
  - multi-value i64 function results (only the single-result i64 ABI form is lowered)
  - i64 global initializers are only supported for top-level `i64.const` and `global.get` forms.

## Inlining notes (learned)

- `src/passes/inlining.mbt` now provides:
  - `inlining(mod, options, optimizing)` for full inlining
  - `inline_main(mod, options)` for the `main` / `__original_main` special-case flow
- `src/passes/optimize.mbt` integration:
  - `ModulePass::Inlining`
  - `ModulePass::InliningOptimizing`
  - `ModulePass::InlineMain`
- `OptimizeOptions` now embeds `InliningOptions` with Binaryen-compatible defaults:
  - `always_inline_max_size = 2`
  - `one_caller_inline_max_size = -1`
  - `flexible_inline_max_size = 20`
  - `max_combined_binary_size = 400 * 1024`
  - `allow_functions_with_loops = false`
  - `partial_inlining_ifs = 0`
- Current inlining model is iterative and deterministic:
  - recomputes per-function info and callsites each iteration
  - plans callsites only in reachable code (unreachable tails are ignored for inlining decisions)
  - enforces a growth cap via estimated module size + per-inline growth
  - avoids same-iteration races by skipping actions where the caller is also selected as an inlined callee in that iteration
  - caps per-caller inlining pressure with an `inlined-into` count guard
- The transform currently assumes de-Bruijn labels and fixes nested branch depths by shifting callee labels when wrapping inlined bodies.
- Tail-call inlining behavior in try context:
  - `return_call*` wrappers inlined at callsites under `try_table` use a hoist path that localizes operands and emits a follow-up guarded tail call after the wrapped original body.
  - hoist path currently supports `return_call`, `return_call_indirect`, and `return_call_ref`.
- Partial/split inlining support is enabled behind:
  - `optimize_level >= 3`
  - `shrink_level == 0`
  - `inlining.partial_inlining_ifs > 0`
  Pattern A and Pattern B split helpers are created conservatively; Pattern B includes a local dependency rejection guard for trailing items.
- `InliningOptimizing` currently runs post-inline cleanup using:
  - `dead_code_elimination_ir_pass`
  - `code_folding_ir_pass`

## Local CSE notes (learned)

- `src/passes/local_cse.mbt` is integrated in `src/passes/optimize.mbt` as `ModulePass::LocalCSE`.
- Current implementation is a 3-phase pipeline:
  - `Scanner` records repeated whole-tree expressions and request links (`repeat -> original` plus original request counts).
  - `Checker` walks linearly again and invalidates active originals when intervening shallow effects conflict.
  - `Applier` inserts `local.tee` on originals with live requests and rewrites repeats to `local.get`.
- Candidate matching uses digest-bucketed lookup plus structural equality checks on `TInstr`.
- CSE scope is intentionally linear/basic-block-local:
  - active expression/original state is cleared at non-linear boundaries (`block`, `loop`, `if`, `try_table`, and branch-like control transfers).
- Child-request suppression is implemented for direct children of repeated parents to avoid unsafe/undesired subtree reuse interactions.
- Current pass behavior follows optimize options for relevance gating:
  - `shrink_level > 0` requires larger measured expressions before CSE.

## Local Subtyping notes (learned)

- `src/passes/local_subtyping.mbt` is integrated in `src/passes/optimize.mbt` as `ModulePass::LocalSubtyping`.
- The pass refines only function var locals declared with reference types; non-ref locals and parameters are ignored.
- Analysis tracks per-local assignments (`local.set` + `local.tee`) and uses (`local.get`) and computes assigned-value LUBs iteratively until convergence.
- Non-nullability safety uses two checks:
  - `LocalGraph` reachability (`InitValue` visibility blocks non-nullable refinement)
  - a structural dominance/definite-assignment fallback traversal for branch-sensitive cases (notably one-armed `if` flows).
- Refinement guards enforced per candidate:
  - non-`none` type
  - `new_type <: old_type`
  - defaultability unless explicit safe non-nullable case
  - unsafe non-nullable candidates are relaxed to nullable before subtype/default checks.
- In current tree IR (`TInstr`), local/get/tee node types are implicit from the function local signature, so updates are applied by rewriting local type declarations.

## MemoryPacking notes (learned)

- `src/passes/memory_packing.mbt` implements the MemoryPacking pass and keeps pass-specific tests inline in the same file.
- Registration is in `src/passes/optimize.mbt` as:
  - `ModulePass::MemoryPacking(MemoryPackingPassProps)`
  - dispatch arm calling `memory_packing(mod, props)`
- Main execution phases in `run_memory_packing_on_module` are:
  - `optimize_segment_ops`
  - `collect_segment_referrers`
  - `drop_unused_segments`
  - split/segment rebuild (`mp_build_transforms_and_segments`)
  - instruction remap/rewrite (`create_replacements` + `apply_replacements`)
- Relevant IR helpers/builders used heavily:
  - `TInstr::memory_init`, `TInstr::memory_fill`, `TInstr::data_drop`
  - `TInstr::block`, `TInstr::if_`, `TInstr::unreachable_`, `TInstr::drop`
  - `ModuleTransformer::on_tinstruction_evt(...)` for both analysis and rewriting
- Current IR constraint: data segment names are not modeled in `Data`, so `__llvm*` protection is represented as a per-segment feature flag in pass logic rather than direct `Data` metadata.
- Max split cap is controlled by `MemoryPackingPassProps.max_data_segments` (default `100000`), and segment count syncing updates `DataCntSec` when present.
- To verify pass changes locally, run:
  - `/home/jtenner/.moon/bin/moon check`
  - `/home/jtenner/.moon/bin/moon test`
  - `/home/jtenner/.moon/bin/moon info && /home/jtenner/.moon/bin/moon fmt`

## MergeBlocks notes (learned)

- `src/passes/merge_blocks.mbt` implements the MergeBlocks pass and keeps pass-focused tests inline in the same file.
- Registration is in `src/passes/optimize.mbt` as:
  - `ModulePass::MergeBlocks`
  - dispatch arm calling `merge_blocks_ir_pass(mod, options=options)` through `apply_ir_transformer_pass`.
- Function-level entrypoint is `run_on_function`; the pass runs block-list merge rounds to convergence and applies a final refinalization pass when needed.
- Important helpers used by this pass:
  - `BranchCache` + `has_branch` for reusable branch-target queries
  - `compute_effects` / `invalidates` for safe expression restructuring reordering checks
  - `problem_finder` + `break_value_dropper` for safe dropped-block break-value rewrites
- Required local validation workflow remains:
  - `/home/jtenner/.moon/bin/moon check`
  - `/home/jtenner/.moon/bin/moon test`
  - `/home/jtenner/.moon/bin/moon info && /home/jtenner/.moon/bin/moon fmt`

## MergeLocals notes (learned)

- `src/passes/merge_locals.mbt` is integrated in `src/passes/optimize.mbt` as `ModulePass::MergeLocals`.
- Existing generic LocalGraph lives in `src/ir/local_graph.mbt` and exposes `get_sets(get_id)`, but MergeLocals currently builds its own eager per-function snapshot to track both:
  - reaching sets for each `local.get`
  - reverse set influences (`set -> gets`) used for rewrite eligibility and post-verify undo.
- MergeLocals instruments copy sites as `local.set x (local.tee y (local.get y))`, runs rewrite analysis, then always removes trivial tees before returning.
- Reaching-set safety in this pass is enforced as:
  - no-phi/merge check: rewritten gets must have exactly one reaching set
  - exact type-equality check: target local type must equal the get's local type.
- Local index rewrites are done by get-id mapping (analysis snapshot + rewrite pass) rather than mutating nodes ad hoc, then validated with a fresh post-analysis snapshot; failing copy-direction rewrites are rolled back.
- Dedicated pass tests live in `src/passes/merge_locals_tests.mbt`; run with:
  - `/home/jtenner/.moon/bin/moon test`

## Pass testing notes (learned)

- Most large passes already have substantial inline tests (notably `alignment_lowering`, `directize`, `optimize_casts`, `remove_unused`).
- Sparse-pass coverage has been expanded with targeted tests in:
  - `duplicate_import_elimination.mbt`
  - `duplicate_function_elimination.mbt`
  - `dataflow_opt.mbt`
  - `util.mbt`
  - `lift_to_texpr.mbt`
  - `lower_to_expr.mbt`
  - `optimize.mbt` (dispatch/integration)
  - `gufa.mbt`
- For future work, prioritize property-style/randomized tests for structural passes where combinatorial CFG/typing interactions are large.

## Local toolchain note

- In this workspace, `moon` may not be on `PATH` in non-interactive shells. Use `/home/jtenner/.moon/bin/moon` for `moon test`, `moon info`, and `moon fmt` when needed.
