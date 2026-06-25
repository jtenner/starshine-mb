# 0806-2026-06-20-code-pushing-unreachable-arm-post-use

## Question

Can Starshine widen `code-pushing` to match Binaryen's `optimizeIntoIf` nuance where a local set may sink into the only consuming `if` arm even when the local is read after the `if`, provided the opposite arm cannot fall through?

## Sources and local context

- Active backlog slice: `[O4Z-AUDIT-CP]` in `agent-todo.md`.
- Living pass docs: `docs/wiki/binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md` and `segment-selection-and-barriers.md`.
- Implementation: `src/passes/code_pushing.mbt`.
- Tests: `src/passes/code_pushing_test.mbt`.

## Binaryen oracle probe

A local probe with `wasm-opt --all-features --code-pushing -S` on this shape:

```wat
(module
  (func (param i32) (result i32) (local i32)
    i32.const 7
    local.set 1
    local.get 0
    if
      local.get 1
      drop
    else
      unreachable
    end
    local.get 1))
```

showed Binaryen replacing the original root `local.set` with `nop` and inserting `local.set 1 (i32.const 7)` at the start of the consuming `then` arm. The later `local.get 1` remains after the `if`; this is safe because the non-consuming `else` arm is `unreachable` and cannot reach that later read.

## Change

Added a narrow Starshine slice for this exact safety proof:

- `code_pushing_count_local_gets_writes_in_region_suffix_bounded(...)` counts same-region uses after the destination `if`.
- `code_pushing_region_cannot_fall_through_simple(...)` recognizes a conservative non-fallthrough arm ending in `unreachable`, `return`, or tail-return roots.
- `code_pushing_try_sink_set_into_if_then(...)` now accepts extra same-region suffix reads only when:
  - there is still exactly one write to the local;
  - all arm reads are in exactly one `if` arm;
  - all additional reads are after the destination `if` in the same region;
  - there are no same-region prefix reads before the set;
  - there are no suffix writes; and
  - the non-consuming arm is present and cannot fall through under the conservative helper.

The existing fallthrough-post-use negative remains unchanged for the no-`else` case, where the non-consuming path can still reach the later read.

## Evidence

- Red-first focused test: `moon test --target native src/passes/code_pushing_test.mbt --filter '*opposite arm cannot fall through*'` failed before implementation with `expected nop`.
- After implementation, the same focused test passed `1/1`.
- Focused pass tests passed: `moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'` passed `19/19`.

## Remaining work

This does not close `[O4Z-AUDIT-CP]`. Open code-pushing audit work remains:

- source-refresh / behavior matrix against current local Binaryen version;
- analyzer and segment-window parity beyond the current narrow HOT implementation;
- switch / conditional-branch / dropped-wrapper push points;
- multi-set order preservation;
- GC, EH, trap-option, and broader effect-invalidation surfaces;
- modern direct compare and any dedicated GenValid profile/four-lane closeout required by the current pass-audit standard.
