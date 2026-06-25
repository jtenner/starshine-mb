# 0899 - code-pushing intrinsic no-effects boundary

Date: 2026-06-25

## Question

Can Starshine close `[CP-BINREP-004]` by implementing or explicitly resolving Binaryen's `binaryen-intrinsics/call.without.effects` code-pushing surface?

## Answer

Yes, as a narrow accepted implementation boundary. Binaryen v130 `code-pushing_into_if.wast` proves that calls to the imported intrinsic `binaryen-intrinsics/call.without.effects` may be treated as no-effect call values when their arguments are safe, allowing the local set to sink into the consuming `if` arm. Starshine currently has no reliable hot-pass way to identify that import by module/name: `HotModuleContext` records function types but not import module/name metadata, and `HotOp::Call` nodes carry only the function index in `imm0` plus ordinary call side-effect flags.

Therefore `[CP-BINREP-004]` is resolved as **not implemented / blocked by missing intrinsic identity metadata**, not as behavior parity. Ordinary calls remain barriers, and that conservative behavior is still correct for all non-intrinsic calls.

## Source-backed lit shapes

Local source file: `.tmp/binaryen-lit/code-pushing_into_if.wast`, fetched from Binaryen `version_130`.

Relevant lit family:

- `sink-call`: Binaryen sinks a `local.set $temp (call $call.without.effects (i32.const 1234) (ref.func $sink-call))` into the only `if` arm that returns `$temp`.
- `no-sink-call`, `no-sink-call-2`, and `no-sink-call-3`: Binaryen keeps the set stationary when the local is read after the `if`, including through intervening `nop` / dropped-use shapes.
- `sink-call-3`: Binaryen still sinks when the post-`if` roots do not read the moved local.
- `no-sink-call-sub`: Binaryen keeps the set stationary when an intrinsic argument has an effect (`local.tee $other`), even though the call target itself is the no-effects intrinsic.

These fixtures should be reused if/when Starshine implements the family; ad hoc intrinsic WAT is easy to make invalid or semantically different.

## Starshine blocker

Current local implementation facts:

- `HotOp::Call`, `CallIndirect`, and `CallRef` default to call / side-effect / may-trap flags in `src/ir/hot_flags.mbt`.
- `code-pushing` treats calls as hard segment-order barriers and does not include `HotOp::Call` in `code_pushing_node_is_movable_value(...)`.
- `HotModuleContext` currently stores function type indexes and resolved function types, but not import module/name strings. It cannot answer whether a function index names `binaryen-intrinsics` / `call.without.effects`.
- A heuristic based only on function type or arity would be unsafe: any ordinary imported or defined function with the same signature could have side effects, trap, or observe state.

## Decision

Mark `[CP-BINREP-004]` complete as an explicit accepted boundary for the current replacement follow-up. No behavior change landed and no TDD test was added in this slice because the correct implementation requires a prerequisite representation/API change rather than a narrow local code-pushing edit.

Reopening criteria:

- extend `HotModuleContext` or another pass-visible module metadata path with function import module/name identity;
- add an intrinsic predicate that specifically recognizes `binaryen-intrinsics/call.without.effects` by function index;
- add red-first focused tests from the exact lit-derived shapes above, including `sink-call`, `sink-call-3`, post-if-use negatives, and `local.tee` argument negative;
- prove ordinary calls remain barriers and no function-type-only heuristic admits side-effectful calls.

## Validation

Docs/status slice only. Evidence commands:

```sh
grep -n "call.without.effects\|intrinsic\|without" .tmp/binaryen-lit/code-pushing_into_if.wast
```

Manual source review checked `src/ir/hot_flags.mbt`, `src/ir/hot_module_context.mbt`, `src/ir/hot_lift.mbt`, and `src/passes/code_pushing.mbt` for call flags, function-index payloads, missing import-name metadata, and call barrier behavior.
