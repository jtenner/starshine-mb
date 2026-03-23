# DCE void-block self-break fix

## Scope
- Diagnose the next direct `DeadCodeElimination` post-encode validation blocker after the `Func 313` / `Func 315` validator fixes.
- Reduce it to a small standalone shape that does not depend on the full release artifact.
- Fix the DCE rule without widening the pass beyond Binaryen-style local safety.

## Current behavior
- The minimized raw-valid shape is:

```wat
(block (result i32)
  (block
    (if
      (i32.const 1)
      (then br 1)
      (else br 1)))
  (i32.const 7))
```

- Before this slice, Starshine DCE treated the inner `block (void)` as escaping its parent expression, so enclosing expression truncation dropped the trailing `i32.const 7`.
- The remaining typed result block still kept result type `i32`, so typed-to-raw encode produced an invalid block with no fallthrough value.

## Root cause
- `optimization_dead_code_elimination_block_escapes_parent` used:

```text
if tail_does_not_escape_current_expr:
  false
else if block_type_is_void:
  true
else:
  no_live_break_to_label_0(body)
```

- That `void => true` branch was too aggressive.
- A tail `if` whose branches only `br 1` from inside the `if` exits the current `void` block, but it does not escape the parent expression when that break targets the block itself.
- Expression truncation then removed later siblings that were still needed to produce the enclosing concrete block result.

## Fixed behavior
- The escape test now always requires `no_live_break_to_label_0(body)`, regardless of block result type.
- Pseudocode:

```text
block_escapes_parent(body):
  if body is empty:
    return false
  if tail does not escape the current expr:
    return false
  return not has_live_break_to_label(body, 0)
```

- This keeps DCE local and linear in the existing analysis surface.
- It does not add broader cleanup or new speculative rewrites.

## Correctness constraints
- `br 0` or any nested branch that resolves to label `0` of the current block means the block can still complete locally.
- In that case, siblings after the block remain reachable to the parent expression and must not be truncated.
- Concrete result blocks must retain either:
  - a live incoming break carrying the block result, or
  - a fallthrough producer that remains in the body.

## Validation plan
- Whitebox regression in `src/optimization/dead_code_elimination_wbtest.mbt` asserts DCE keeps the trailing `i32.const 7` in the reduced typed fixture.
- External minimized repro before the fix:

```bash
wasm-tools parse /tmp/dce-block-tail.wat -o /tmp/dce-block-tail.wasm
_build/native/release/build/cmd/cmd.exe \
  --dead-code-elimination \
  --out /tmp/dce-block-tail-out.wasm \
  /tmp/dce-block-tail.wasm
```

- Before the fix, that failed post-encode validation with `stack underflow` and printed a `block I32` with no remaining fallthrough value.
- Full workspace `moon info`, `moon fmt`, and `moon test` are still blocked by unrelated compile errors in `src/fs/fs.mbt` and `src/validate/invalid_fuzzer.mbt`, so this slice used direct package compilation with `moonc build-package` against cached dependency artifacts.

## Performance impact
- None intended beyond removing a false-positive truncation.
- The fix only tightens an existing predicate and reuses the current live-break scan.

## Open questions
- Rebuild `src/cmd` once the unrelated workspace compile blockers are cleared and rerun:
  - direct `--dead-code-elimination` on `_build/wasm/release/build/cmd/cmd.wasm`
  - the shared five-pass prefix ending in DCE
- If `Func 531` / `Func 527` still fail after that rerun, reduce the next remaining post-encode shape separately instead of widening this rule again.
