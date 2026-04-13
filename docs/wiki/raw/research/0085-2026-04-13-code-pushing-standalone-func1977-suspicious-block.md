# 0085 — Code-pushing standalone `Func 1977` suspicious lowered block localization

- Date: 2026-04-13
- Area: `code-pushing`, `hot_lower`
- Status: open frontier note

## Goal

- Continue reducing the standalone `Func 1977` lower/writeback frontier from
  [`0084`](./0084-2026-04-13-code-pushing-standalone-func1977-writeback-frontier.md).
- Move from the coarse fact
  - "standalone `Func 1977` hot pass rewrites, but writeback still fails"
  to the sharper fact
  - "which exact lowered sub-instruction first trips the suspicious escape-
    carrier heuristic and writeback validation?"

## Method

1. Reused the standalone reconstruction from:
   - `.tmp/codex-tmp/standalone-scan-20260413d/func1977.wat`
2. Replayed `code-pushing` in whitebox mode:
   - lift the standalone function
   - run `hot_pass_run(...)`
   - lower with `@ir.hot_lower_func(...)`
3. Walked the lowered top-level body recursively with
   `run_hot_pipeline_has_invalid_hard_exit_escape_carrier_block(...)` until the
   first nested instruction that still matched the suspicious-carrier heuristic.
4. Rechecked writeback validation with
   `run_hot_pipeline_precompute_writeback_validation_error(...)`.

## Key Finding

The first offending lowered sub-instruction is no longer "somewhere inside the
whole lowered function". It is a much sharper nested block at path:

- `34/0/0/0/11/else/5/then/2/0/0`

That offending instruction has the essential shape:

- `block (result i32)`
- body:
  - `block (void)` containing a long prefix with hard exits
  - trailing `local.get` payload

More concretely, it is a split payload wrapper of the form:

- `block I32`
  - `block Void`
    - prefix work
    - nested result-carrying / refcount ladder
    - one arm stores the carried value into a local and branches
    - the other arm takes a deeper parent-exit branch
    - `unreachable`
  - `local.get <carried-local>`

Writeback validation on the lowered rewritten function still reports:

- `stack underflow`

## What This Rules Out

- The remaining standalone `Func 1977` blocker is still **not** another
  `code-pushing` root-motion admission problem.
- It is also not fixed by the naive `hot_lower` probe of broadening
  `hot_lower_impl_try_fix_split_payload_wrapper_with_tail(...)` from only branch
  depth pairs `(1, 2)` / `(2, 1)` to any differing positive depths.
- That broad probe did **not** remove the standalone `skip-invalid-lower`
  result on `func1977.wat`, so the remaining issue is narrower than just
  "branch depths differ by more than one".

## Current Mechanism Hypothesis

The sharper frontier now looks like a missing `hot_lower` repair for a split
parent-exit payload wrapper where:

- the payload is forwarded via a later `local.get <carried-local>`
- the producing arm stores into that carried local before branching
- a sibling arm exits at a deeper parent label
- the existing split-payload helpers do not fully repack or retarget that mixed
  carry-set / deeper-parent-exit combination

The most likely implementation surfaces to inspect next are:

- `hot_lower_impl_try_pack_split_if_payload_forwarder(...)`
- `hot_lower_impl_try_fix_split_payload_wrapper_with_tail(...)`
- nearby parent-exit payload peeling / repacking helpers in `src/ir/hot_lower.mbt`

## Practical Conclusion

- The next reduction target is now the localized split payload wrapper above,
  not the full standalone `Func 1977` function body.
- The likely next useful in-repo regression is a `hot_lower` live repro or
  whitebox test for a result block whose payload is carried by a later
  `local.get`, while one arm stores that carried value and another arm exits to
  a deeper parent label.
