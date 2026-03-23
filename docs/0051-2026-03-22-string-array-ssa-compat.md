# String Array SSA Compatibility

## Scope

Make the already-landed array-backed string instructions survive the local SSA
pipeline instead of aborting during IR conversion.

This slice covers the existing eight string array ops:

- `string.new_utf8_array`
- `string.new_wtf16_array`
- `string.new_lossy_utf8_array`
- `string.new_wtf8_array`
- `string.encode_utf8_array`
- `string.encode_wtf16_array`
- `string.encode_lossy_utf8_array`
- `string.encode_wtf8_array`

## Why This Slice

`docs/0050-2026-03-22-string-array-surface-for-dce.md` landed the minimal lib,
validator, binary, and text surface needed for DCE parity, but the current IR
stack still had a hard stop in `src/ir/ssa.mbt` for these typed instructions.

That meant modules using the new string surface could validate and optimize in
typed-expression passes while still failing in SSA-based compatibility paths.

## Current Behavior

The SSA layer now models the existing string array ops as first-class `SSAOp`
nodes and preserves them through:

- local collection and local-definition scanning in `src/ir/ssa.mbt`
- typed-to-SSA lowering in `src/ir/ssa.mbt`
- SSA-to-typed destruction in `src/ir/ssa_destruction.mbt`
- SSA type inference in `src/ir/type_tracking.mbt`
- use-def and liveness analysis in `src/ir/usedef.mbt` and
  `src/ir/liveness.mbt`
- SSA rewrite plumbing in `src/ir/ssa_optimize.mbt`
- GVN operand rewriting and conservative side-effect invalidation in
  `src/ir/gvn.mbt`

Behavioral policy:

- `string.new_*_array` is treated like the existing GC allocation ops:
  value-producing and effectful for SSA/GVN purposes.
- `string.encode_*_array` is treated as value-producing and side-effecting,
  and conservatively invalidates cached array reads because it writes through
  the passed GC array reference without a type immediate.

## Validation Plan

Focused IR coverage now includes:

- `collect_instr_locals` coverage for string array ops
- SSA phi-threading coverage through `string.new_wtf16_array` and
  `string.encode_utf8_array`
- SSA type inference coverage for `stringref`-producing and `i32`-producing
  string ops
- SSA destruction coverage back to typed instructions

## Open Questions

- This slice does not add new string instructions beyond the array-backed set
  from `0050`.
- The next broader string compatibility gap remains `string.const` and the
  eventual `StringGathering` pass work that depends on it.
