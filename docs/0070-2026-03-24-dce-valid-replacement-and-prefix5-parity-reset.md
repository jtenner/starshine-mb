# DCE valid replacement and five-pass parity reset

## Scope

- Restore a validating Starshine `--dead-code-elimination` on `tests/node/dist/starshine-debug-wasi.wasm`.
- Re-run the shared five-pass compare against Binaryen on the debug artifact.
- Separate correctness blockers from real parity blockers.

## Current behavior

- Direct Starshine `--dead-code-elimination` on `tests/node/dist/starshine-debug-wasi.wasm` now produces a wasm module that validates with `wasm-tools validate`.
- The reduced repro `/tmp/starshine-debug-dce-repro.wasm` also validates after direct Starshine DCE.
- The compare harness itself needed two fixes before parity data was usable:
  - raise `spawnSync` buffer capacity in `scripts/lib/task-runtime.ts`
  - stop normalizing WAT through stdout capture and instead write `wasm-opt -S` output to a temp file in `scripts/lib/self-optimize-compare-task.ts`

## Replacement status

- The previous recursive dead-result cleanup and structured unreachable barrier rewriting were the source of the invalid encodings.
- The current replacement is intentionally narrower:
  - keep generic unreachable-child rewrites for non-structured instructions
  - keep direct `drop(strict-terminal)` collapse
  - stop truncating typed expression lists after the first inferred structured terminator
  - stop collapsing `drop(if/block/try_table/loop ...)` based on broad structured-unreachable inference
- This replacement is functionally correct on the current debug artifact, but much less aggressive than Binaryen.

## Five-pass comparison results

Shared prefix:

1. `--duplicate-function-elimination`
2. `--remove-unused-module-elements`
3. `--memory-packing`
4. `--once-reduction`
5. `--dead-code-elimination`

Comparison artifact:

- input: `tests/node/dist/starshine-debug-wasi.wasm`
- out dir: `/tmp/starshine-parity-prefixes-20260324/debug-prefix5`

Observed result:

- Starshine output validates
- Binaryen output validates
- normalized WAT still differs
- Starshine size: `19,540,620`
- Binaryen size: `7,861,593`

## What that size gap means

- The large debug-artifact size gap is not caused by Starshine DCE alone.
- The shared-prefix pass-4 and pass-5 Starshine outputs are byte-identical:
  - `/tmp/starshine-parity-prefixes-20260324/debug-prefix4/starshine.wasm`
  - `/tmp/starshine-parity-prefixes-20260324/debug-prefix5/starshine.wasm`
- Binaryen still changes the module between pass 4 and pass 5:
  - `/tmp/starshine-parity-prefixes-20260324/debug-prefix4/binaryen.wasm`
  - `/tmp/starshine-parity-prefixes-20260324/debug-prefix5/binaryen.wasm`
- Therefore the current Starshine DCE is now valid but effectively a no-op on this shared five-pass prefix.

## Binaryen-only DCE shape

- The first Binaryen-only DCE diff on the shared prefix shows structured-result cleanup patterns like:
  - `if (result i32)` -> `if` plus explicit trailing `unreachable`
  - `loop (result i32)` -> `loop` plus explicit trailing `unreachable`
  - nested `block (result i32)` chains where Binaryen rewrites the structured result type away once the continuation is provably non-fallthrough
- This is the same family that originally caused invalid Starshine encodings when implemented without enough context.

## Correctness constraints

- Any renewed structured DCE rewrite must distinguish:
  - branch payload position
  - dead drop context
  - enclosing block result requirements
  - whether an inner `br` targets the current structure or escapes beyond it
- The current `module rewrite engine` callback shape still does not supply parent/operand-role context directly, so a parity-grade structured DCE likely needs a dedicated context-carrying recursive walker.

## Validation plan

- Keep direct validation on:
  - `tests/node/dist/starshine-debug-wasi.wasm`
  - reduced repros from `wasm-tools shrink`
- Re-run both shared-prefix compares:
  - prefix 4
  - prefix 5
- Use `cmp` on Starshine prefix 4 vs prefix 5 to confirm that DCE is actually firing again before treating any size change as a parity result.

## Performance impact

- The replacement restores correctness but currently leaves Binaryen’s pass-5 wins on the table.
- On the shared debug-prefix target, Starshine DCE currently contributes `0` bytes of reduction while Binaryen DCE still reduces the prefix-4 output.

## Open questions

- Is the debug artifact still the right parity target, or should the shared-prefix comparison strip debug/name sections first to isolate optimizer behavior?
- Which minimal structured rewrite slice can be reintroduced safely with explicit operand-role context?
- Should the compare harness normalize names and section-order noise before using normalized WAT equality as a parity gate?
