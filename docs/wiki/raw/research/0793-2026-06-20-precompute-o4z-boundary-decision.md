# Precompute O4z boundary decision

## Question

Decide and document the remaining O4z no-op boundary for canonical pass `precompute` after the regular GenValid mismatch family was reduced/classified by [`0792`](0792-2026-06-20-precompute-loop-nop-closeout-normalizer.md). Determine whether another small safe O4z recovery slice is obvious now, or whether the remaining `o4z-precompute-noop` surface should stay as an explicit v0.1.0 release boundary with reopening criteria and honest slot-evidence notes.

## Files reviewed

- `docs/README.md` — repo docs/wiki, pass-audit, validation, and commit policy.
- `.pi/skills/recursive-handoff/SKILL.md` — bounded recursive continuation rules.
- `.pi/skills/starshine-pass-implementation/SKILL.md` — pass final closeout, mismatch classification, and pass-specific profile requirements.
- `.pi/skills/commit/SKILL.md` — commit policy.
- `agent-todo.md` — active `[O4Z-AUDIT-PC]` state.
- `docs/wiki/binaryen/passes/precompute/` — current precompute dossier.
- `docs/wiki/raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md` through `0792-2026-06-20-precompute-loop-nop-closeout-normalizer.md` — current recursive-chain evidence.
- `src/passes/pass_manager.mbt` — O4z `precompute` raw gate, hazard/no-op reasons, and accepted `raw-scalar-folds` path.
- `src/passes/precompute.mbt` — raw precompute return reasons and HOT-only fallback decisions.
- `src/passes/precompute_test.mbt` — focused O4z scalar recovery and O4z HOT-only no-op coverage.
- `src/passes/perf_test.mbt` — raw shortcut coverage and no-HOT-lift trace expectations for direct `precompute` raw reasons.
- `src/cmd/cmd_wbtest.mbt` — historical generated O4z slot19/slot43 replay tests and their `.artifacts` dependency.

## Source findings

`run_hot_pipeline_raw_precompute(...)` now has exactly one accepted O4z mutation class: when `optimize_level >= 4 && shrink_level >= 1`, Starshine runs a changed raw result only if `precompute_run_raw_func(...)` reports `reason == "raw-scalar-folds"`. That is the narrow recovery implemented in [`0788`](0788-2026-06-20-precompute-o4z-raw-scalar-recovery.md) and protected by `precompute runs narrow raw scalar folds under O4z gate`.

Every other path deliberately maps to `o4z-precompute-noop` under the O4z gate:

1. **Load/call/local-set ownership hazard**: `run_hot_pipeline_dce_raw_has_load_call_set_hazard(...)` recursively detects same-base `local.get; load; local.get; call; local.set` sequences. Direct non-O4z coverage (`precompute skips load-call-set ownership hazards`) proves this hazard remains guarded.
2. **Large lowered functions**: functions with more than `64` locals and more than `500` lowered instructions return the no-op reason. This is a coarse artifact-size/ownership boundary rather than a semantic proof that no fold is possible.
3. **SIMD parser / `br_table` stack hazard**: `run_hot_pipeline_raw_can_skip_simd_parser_br_table_stack_hazard(...)` recognizes a high-control, high-branch, `br_table`-bearing generated-parser shape. The focused O4z no-op test intentionally uses `br_table` cleanup and expects `o4z-precompute-noop`.
4. **HOT-only candidates**: when `precompute_run_raw_func(...)` returns `None`, O4z keeps the original function. This includes root-`nop` cleanup, raw-drop cases needing HOT ownership, constant-`if` candidates that still need HOT after raw rewriting, and other structural cleanup paths that are not proven safe to run in the historical self-opt O4z ownership context.
5. **Raw no-candidate / unchanged results**: unchanged raw scans (`no-precompute-candidates`) remain no-op under O4z; this is intentional because there is no pass-owned mutation to recover.
6. **Changed non-scalar repair reasons**: artifact repair paths such as `raw-tlsf-init-repair` remain outside the accepted O4z mutation class. They are valuable direct-pass repairs, but they are not yet proven as safe O4z slot behavior for the release gate.

## Decision

Accept the remaining O4z `precompute` no-op surface as a **v0.1.0 release boundary**, not as proof of full O4z `precompute` parity. The release-gating contract is now explicit:

- O4z `precompute` may run changed `raw-scalar-folds` only.
- HOT-only cleanup, load/call ownership hazards, large lowered functions, `br_table`/parser stack hazards, unchanged raw no-candidate cases, and changed non-scalar raw repair reasons stay fail-closed as `o4z-precompute-noop`.
- This boundary is acceptable only because the direct pass remains the behavior-parity target for final closeout, the previous O4z hard failures were retired by writeback/HOT-lower guard work, and the final report must continue to state that broader O4z PC slot optimization is intentionally deferred.

No new small safe implementation slice was obvious from this review. Recovering more O4z work would require a focused reduced artifact or fixture that proves the candidate shape does not reintroduce the self-opt ownership hazards that caused the original no-op gate.

## Historical slot evidence status

The old generated O4z slot tests in `src/cmd/cmd_wbtest.mbt` still document the intended replay surfaces:

- slot19 predecessor: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/15-slot18-pick-load-signs/binaryen.wasm`;
- slot43 predecessor / slot44 neighbor: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/29-slot43-precompute/binaryen.wasm`.

Those paths are not replayable in this checkout because `.artifacts` is absent. The native-only tests read those files directly and fail-closed if the fixtures are missing, so they are not a current runnable signoff lane here. The durable historical conclusions remain the earlier notes: slot19 was retired by precompute writeback validation and HOT/writeback guards, and the later slot43 continuation was retired by HOT-lower carried-prefix label guarding rather than by enabling broad O4z precompute.

For the current release-gating chain, the slot evidence decision is therefore: do not block the boundary decision on missing local `.artifacts`, but do not claim refreshed slot replay. If the artifacts return, or if a new generated fixture replaces them, rerun the slot/neighborhood tests before removing the O4z boundary.

## Reopening criteria

Reopen this O4z boundary if any of the following occurs:

- a current O4z or self-opt artifact shows that an `o4z-precompute-noop` reason leaves a material size/performance regression that can be reduced to a safe shape;
- a focused fixture proves a HOT-only cleanup, br_table/control cleanup, large-function subset, load/call/local-set subset, or non-scalar repair can run under O4z without invalid lowering, ownership corruption, or semantic drift;
- refreshed slot19/slot43 artifacts become available and show current behavior differs from the documented historical retirement story;
- the final direct closeout matrix finds a semantic mismatch, Starshine validation failure, Starshine-specific command failure, or unclassified output-shape family attributable to the O4z gate or raw precompute shortcut;
- the project deliberately chooses to chase broader O4z optimization parity before v0.1.0 rather than accepting the fail-closed boundary.

## Commands and results

- `git status --short --branch`
  - Initial result: clean worktree at `## starshine-gsi` before this docs slice.
- `find .artifacts -maxdepth 2 -name '*precompute*' 2>/dev/null | head -20; test -d .artifacts && echo artifacts-present || echo artifacts-missing`
  - Result: `artifacts-missing`; no local generated O4z slot replay fixture is available in this checkout.
- `moon test --package jtenner/starshine/passes --file precompute_test.mbt`
  - Result: focused precompute tests passed `36/36`, including the current O4z scalar recovery and O4z HOT-only no-op fixtures.

## Classification

- O4z boundary: explicit and accepted for v0.1.0, with reopening criteria above.
- New behavior gap: none reduced in this slice.
- Code changes: none; this is a docs/backlog decision slice.
- `[O4Z-AUDIT-PC]`: remains open. The final closeout matrix has still not run, and any final report must state the accepted O4z no-op boundary separately from direct `--pass precompute` behavior parity.

## Commands not run

- No final compare-pass closeout lanes were run. The next closeout still needs regular GenValid `100000`, explicit wasm-smith `10000`, dedicated `precompute-all` `10000` with PC normalizers, and broad `pass-fuzz-stress` `10000` with `_build/native/release/build/cmd/cmd.exe` in this checkout.
- No slot19/slot43 replay was run because `.artifacts` is absent.
- No `moon fmt` or full `moon test` was run before filing this note because no MoonBit source changed.

## Next work

Run the refreshed direct/final evidence now that the regular GenValid mismatch family and O4z boundary are explicit. Start with a bounded current direct lane if desired, then proceed to the required four-lane closeout matrix with `_build/native/release/build/cmd/cmd.exe` after `moon build --target native --release src/cmd`.
