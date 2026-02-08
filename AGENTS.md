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
  - `optimize_casts_ir_pass`
- `src/passes/util.mbt` contains `wrap_unit_func_pass` for adapting `ModuleTransformer[Unit]` function-level passes into `ModuleTransformer[IRContext]`.
- `src/passes/dataflow_opt.mbt` is SSA-backed: it uses `IRContext.optimize_body_with_ssa()` and is the intended replacement path over the deprecated `src/dataflow/*` package.
- `src/passes/dead_argument_elim.mbt` is integrated into `ModulePass::DeadArgumentElimination` and follows the same transformer-constructor pattern.
- Dead argument elimination handles "unseen" call edges (exports/start/table/ref.func) by keeping original signatures stable and creating internal optimized clones plus adapter thunks, then remapping direct calls to the cloned targets.
- `src/passes/optimize.mbt` now includes these additional `ModulePass` variants and dispatch paths:
  - `DuplicateImportElimination`
  - `GUFA`
  - `GUFAOptimizing`
  - `GUFACastAll`
- `GUFAOptimizing` currently runs GUFA and then follows up with:
  - `dead_code_elimination_ir_pass`
  - `code_folding_ir_pass`

## GUFA notes (learned)

- `src/passes/gufa.mbt` now uses a local `ContentOracle` + `PossibleContents` domain to infer:
  - unreachable values
  - scalar constants (currently `i32`, `f32`, `f64`)
  - reference singleton values (`ref.null`, `ref.func`)
  - refined reference types (`PCRefType`)
- The oracle is intentionally local/flow-sensitive in function traversal:
  - local contents are tracked across `local.set` / `local.tee`
  - local contents are cleared at control-flow boundaries (`block`, `loop`, `if`, `try_table`) to avoid unsound merges
- GUFA optimizations now use oracle queries where applicable:
  - `ref.eq`, `ref.test`, `ref.cast`, `ref.as_non_null`
  - `ref.is_null`
  - `i32.eqz`
  - leaf replacement for `local.get` / `global.get` when content is known and type-compatible
- `GUFACastAll` adds casts when inferred ref type is a strict subtype of declared ref type.

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
