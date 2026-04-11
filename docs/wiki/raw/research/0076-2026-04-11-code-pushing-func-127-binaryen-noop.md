# 0076 - Code-Pushing `func $127` Binaryen No-Op

## Scope

- Recheck the remaining `code-pushing` whole-artifact frontier from the
  Binaryen side, not just from Starshine traces.
- Determine whether Binaryen actually transforms the printed `func $127`
  frontier on `tests/node/dist/starshine-debug-wasi.wasm`.
- Use that answer to decide whether the remaining `44251` / `44254` family is a
  true Binaryen transform gap or a Starshine-only admission bug mixed with
  Binaryen writeback noise.

## Primary Sources

- Existing project pass study:
  [`docs/0073-2026-04-02-code-pushing-binaryen-plan.md`](../../../../0073-2026-04-02-code-pushing-binaryen-plan.md)
- Existing Binaryen writeback-noise note:
  [`0074-2026-04-02-binaryen-multivalue-call-local-disparity.md`](./0074-2026-04-02-binaryen-multivalue-call-local-disparity.md)
- Upstream Binaryen source reread:
  <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/CodePushing.cpp>
- Current in-tree implementation and regressions:
  - [`src/passes/code_pushing.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/passes/code_pushing.mbt)
  - [`src/passes/code_pushing_test.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/passes/code_pushing_test.mbt)
  - [`src/ir/hot_lower_live_repro_test.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/ir/hot_lower_live_repro_test.mbt)
  - [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/cmd/cmd_test.mbt)

## Binaryen Reread

- The current upstream `version_129` `CodePushing.cpp` is still deliberately
  narrow.
- Binaryen only does two kinds of motion:
  - move plain SFA `local.set` roots forward inside one flat block list
  - sink a plain SFA `local.set` into exactly one `if` arm when later reads make
    that legal
- The pass still reasons in terms of:
  - flat block-list segments
  - effect barriers
  - SFA locals
  - one-arm `if` sinks
- It does **not** contain Starshine-style logic for:
  - explicit-exit carrier summaries
  - owner-sensitive branch-payload classification
  - terminal-owner carrier whitelists
  - alias-local synthesis around carried-result blocks

## Artifact Probe

- Normalized the debug artifact with no optimization:
  - `wasm-opt tests/node/dist/starshine-debug-wasi.wasm --all-features --strip-debug -S`
- Normalized the same artifact after Binaryen `--code-pushing`:
  - `wasm-opt tests/node/dist/starshine-debug-wasi.wasm --all-features --code-pushing --strip-debug -S`
- The documented `44251` / `44254` frontier is inside printed function:
  - `$_M0FP37jtenner9starshine3cmd19parse__config__json`
- Extracting just that function from both normalized outputs and diffing the
  slices produced no changes.

## Conclusion

- Binaryen `--code-pushing` is a no-op on the current printed `func $127`
  frontier.
- That means the live `44251` / `44254` whole-artifact blocker is **not**:
  - "Binaryen transforms this function and Starshine transforms it differently"
- It is much more likely:
  - Starshine still admits a function-local rewrite that Binaryen leaves
    untouched
  - the visible local / tuple-materialization drift is downstream writeback
    fallout on top of that Starshine-only admission
- This matches the earlier project notes from `0073`:
  - the old top-of-`Func 148` dropped-carrier corruption was already gone
  - the remaining live semantic question had moved to the later
    `candidate-set -> condition-set -> later-if` terminal-owner family
  - the raw `44251` boundary was never a stable oracle by itself because
    Binaryen no-pass writeback still adds boundary noise on this artifact

## Issue Hypothesis From The Binaryen Angle

- If Binaryen leaves `parse__config__json` unchanged, then any Starshine rule
  that depends on explicit-exit carrier summaries in that function is already
  broader than the upstream pass surface.
- The safest interpretation is:
  - keep direct HOT-lowering-valid reorder proofs as evidence that a shape can
    lower
  - but do **not** admit that shape in `code-pushing` unless Binaryen also
    proves it on the real artifact
- For the current tree, that points directly at the kept fence on the
  terminal-owner family:
  - a candidate `local.set`
  - an extra kept condition-set before the later `if`
  - an earlier explicit-exit carried-result block that makes Starshine's guard
    broader than Binaryen's flat block-list algorithm

## Kept Repository Change

- The in-tree fix is now a narrower guard in
  [`src/passes/code_pushing.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/passes/code_pushing.mbt):
  `cp_push_to_pushpoint_has_condition_set_crossed_carrier_alias_guard(...)`
- The guard blocks exactly the documented family:
  - the moved root is an alias `local.set(local.get ...)`
  - the later `if` has an extra kept condition-set immediately before it
  - an earlier explicit-exit block carrier aliases the same carried local
- The HOT-only lowering proof stays in
  [`src/ir/hot_lower_live_repro_test.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/ir/hot_lower_live_repro_test.mbt),
  but the pass now keeps the documented terminal-owner crossed-condition-set
  shape fenced in
  [`src/passes/code_pushing_test.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/passes/code_pushing_test.mbt).

## Validation

- Focused pass regressions now pass for:
  - the new negative boundary on the terminal-owner crossed-condition-set shape
  - the adjacent still-valid positive owner-only direct-terminal shape
  - the adjacent still-valid loaded-condition-set shape
- A native artifact regression was added in
  [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/cmd/cmd_test.mbt)
  to assert that traced debug-artifact replay no longer marks `Func 148` as
  changed while `Func 1948` still rewrites.

## Practical Decision

- Treat the old `44251` / `44254` family as a Starshine-only correctness fence,
  not as a remaining "port more of Binaryen `code-pushing`" task.
- After this fence, the next blocker should be runtime unless a fresh artifact
  replay proves a different later semantic delta still survives.
