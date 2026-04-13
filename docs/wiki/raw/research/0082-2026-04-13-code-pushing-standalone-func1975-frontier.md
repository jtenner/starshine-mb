# 0082 — Code-pushing standalone `Func 1975` frontier

- Date: 2026-04-13
- Area: `code-pushing`
- Status: open frontier note

## Goal

- Recover a sharper current-tree parity frontier after the `Func 1977` explicit-
  exit-fed alias-tail fix.
- Avoid relying only on stale full-artifact WAT snapshots or long traced replay
  runs that still time out on the full debug artifact.
- Determine whether any of the older Binaryen-only changed functions from the
  saved artifact slices are still real on the current tree.

## Method

1. Reuse the saved per-function slices already extracted from the debug artifact:
   - `.tmp/codex-tmp/extract-20260413/star_no-func1975.wat`
   - `.tmp/codex-tmp/extract-20260413/star_no-func509.wat`
   - related `bin_no` / `bin_yes` slices
2. Rebuild standalone probe modules from the current Starshine no-pass slices by:
   - copying the full type section from `.tmp/no-code-pushing-current.wat`
   - stubbing each directly called callee as an import with the same visible
     signature line
   - adding a plain `memory 1`
   - embedding the sliced function body as the only defined function
3. Run current-source Starshine on those standalone modules with:
   - `moon run src/cmd --target native -- --code-pushing --out ... <probe>.wat`
4. Normalize the Starshine output with `wasm-opt -S` and compare it against
   Binaryen's standalone `wasm-opt --code-pushing -S` output.

## Key Findings

### 1. Standalone `Func 509` is no longer the next current-tree blocker

- Standalone recreation of the saved `Func 509` slice now matches the expected
  Binaryen move on the current source.
- In particular, the alias `local.set $9 (local.get $56)` does move after the
  second decref-style `if` in the recreated standalone module.
- That means the old saved full-artifact Starshine `no`/`yes` WAT pair for that
  function is stale as a current-tree oracle.

### 2. Standalone `Func 1975` still differs on the current source

- The recreated standalone `Func 1975` module still shows a current Starshine /
  Binaryen mismatch.
- Binaryen moves the alias set
  `local.set $11 (local.get $17)`
  from before the nested result-producing `if` into that `then` arm.
- Current Starshine leaves that alias set before the result-producing `if`.
- This is the first sharp current-source standalone mismatch recovered from the
  saved artifact family after the `Func 1977` fix.

## Exact Current Standalone Difference

On the recreated standalone `Func 1975` module:

Binaryen normalized output contains the equivalent of:

- `nop`
- nested result-producing `if`
- inside the `then` arm:
  - `local.set $11 (local.get $17)`
  - then the later block/result materialization that uses that local

Current Starshine normalized output instead keeps:

- `call $moonbit.decref (local.get $9)`
- `local.set $11 (local.get $17)`
- then the nested result-producing `if`

So this is still a result-`if` sink family, but not the already-closed simple
reduced case.

## Important Negative Result

- Two smaller hand-written reductions did **not** reproduce the mismatch:
  1. a call-prefixed nested result-`if` sink where the local is only dropped in
     the `then` arm
  2. a call-prefixed nested result-`if` sink where the `then` arm wraps the read
     in a small `block (result i64)` and branches outward afterward
- Both of those smaller probes kept the alias set before the result-producing
  `if` on both sides.
- So the open `Func 1975` frontier appears to require richer surrounding
  control-flow than the already-landed simple result-`if` sink regression.

## Practical Conclusion

- The next reduced parity target is no longer best described as the old saved
  whole-artifact `Func 509` family.
- A sharper current-tree target is now the recreated standalone `Func 1975`
  result-`if` sink frontier.
- The remaining work is to reduce that standalone mismatch into a smaller
  in-repo regression, then narrow the specific sink blocker without reopening
  the already-kept non-void / owner-sensitive fences.

## Commands Used

- `moon run src/cmd --target native -- --code-pushing --out .tmp/codex-tmp/standalone2/func509-star.wasm .tmp/codex-tmp/standalone2/func509.wat`
- `moon run src/cmd --target native -- --code-pushing --out .tmp/codex-tmp/standalone2/func1975-star.wasm .tmp/codex-tmp/standalone2/func1975.wat`
- `wasm-opt .tmp/codex-tmp/standalone2/func509.wat --code-pushing -S -o .tmp/codex-tmp/standalone2/func509-bin.wat`
- `wasm-opt .tmp/codex-tmp/standalone2/func1975.wat --code-pushing -S -o .tmp/codex-tmp/standalone2/func1975-bin.wat`
- `wasm-opt .tmp/codex-tmp/standalone2/func509-star.wasm -S -o .tmp/codex-tmp/standalone2/func509-star.wat`
- `wasm-opt .tmp/codex-tmp/standalone2/func1975-star.wasm -S -o .tmp/codex-tmp/standalone2/func1975-star.wat`
