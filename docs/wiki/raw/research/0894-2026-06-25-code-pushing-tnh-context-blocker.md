# 0894 - code-pushing TNH movement context blocker

Date: 2026-06-25

Superseded for implementation status by [`0895-2026-06-25-code-pushing-tnh-movement.md`](0895-2026-06-25-code-pushing-tnh-movement.md): the blocker identified here was resolved by adding `HotPassContext.traps_never_happen` and wiring it into `code-pushing`. This note remains useful as the historical blocker analysis.

## Question

Can `[CP-BINREP-002]` be implemented immediately by teaching `code-pushing` to honor `--traps-never-happen` for trapping values such as `i32.div_s` sunk into a sole consuming `if` arm?

## Answer

Not as a narrow `code-pushing`-only behavior change yet. The public pipeline has a trap-mode option, but hot function passes currently do not receive that option through `HotPassContext`, so `src/passes/code_pushing.mbt` cannot distinguish default trap semantics from `--traps-never-happen` without first changing shared pass-manager context plumbing.

This is a blocker, not a non-goal. `[CP-BINREP-002]` should remain active until a follow-up adds trap-mode plumbing to hot-pass context (with API snapshot review) or provides another pass-local mechanism that is equivalently explicit.

## Evidence

Local source inspection on 2026-06-25 found:

- `src/passes/pass_manager.mbt` `HotPipelineOptions` has `traps_never_happen : Bool` and `HotPipelineOptions::new(traps_never_happen? = false)`.
- `src/cmd/cmd.mbt` resolves CLI/config/env trap options and passes `traps_never_happen` into the hot pipeline options.
- `src/passes/pass_manager.mbt` `HotPassContext` has `closed_world`, `optimize_level`, and `shrink_level`, but no `traps_never_happen` field.
- `HotPassContext::new(...)` therefore cannot pass trap mode to `code_pushing.mbt`; the current direct helper tests also construct `HotPassContext` with no trap option.
- `src/passes/code_pushing.mbt` hard-rejects exact trapping integer div/rem opcodes through `code_pushing_exact_instr_can_trap(...)` and `code_pushing_node_is_movable_value(...)`, independent of pipeline trap mode.

## Required next implementation shape

A correct follow-up should be TDD and likely split into two small changes if it grows:

1. Add failing focused tests that distinguish default and TNH behavior for the reduced Binaryen-positive shape:
   - default `code-pushing`: keep `(local.set $x (i32.div_s ...))` before the `if`;
   - `traps_never_happen=true`: sink the same set into the sole using arm.
2. Plumb trap mode into hot-pass execution explicitly, probably by adding a `traps_never_happen` field and optional constructor parameter to `HotPassContext`, wiring `run_hot_pipeline`/hot dispatcher construction from `HotPipelineOptions`, and reviewing generated `.mbti` diffs because `HotPassContext` is public.
3. Narrowly relax `code_pushing_exact_instr_can_trap(...)` / `code_pushing_node_is_movable_value(...)` only when the pass context says traps never happen.
4. Validate focused CP tests, `moon fmt`, `moon test src/passes`, native `src/cmd` build, and a bounded `code-pushing-all` or targeted TNH compare smoke.

## Remaining status

`[CP-BINREP-002]` remains open. This note documents the current local API blocker so the next implementation does not hide trap-mode behavior behind an implicit default or a telemetry-only test.
