# Precompute O4z raw scalar recovery

## Question

Decide the next bounded `[O4Z-AUDIT-PC]` O4z gate slice for canonical pass `precompute`: can Starshine safely recover a narrow amount of O4z work under the existing `optimize_level >= 4 && shrink_level >= 1` no-op gate, while leaving broader HOT/cleanup ownership hazards fail-closed?

## Files reviewed

- `docs/README.md` — repo pass, validation, docs/wiki, and commit policy.
- `.pi/skills/recursive-handoff/SKILL.md` — bounded recursive continuation rules.
- `.pi/skills/starshine-pass-implementation/SKILL.md` — pass implementation/signoff rules and compare-lane requirements.
- `.pi/skills/commit/SKILL.md` — commit message and validation policy.
- `agent-todo.md` — active `[O4Z-AUDIT-PC]` blockers.
- `docs/wiki/binaryen/passes/precompute/` — current precompute dossier and O4z no-op status.
- `docs/wiki/raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md` — modern status refresh.
- `docs/wiki/raw/research/0786-2026-06-20-precompute-descriptor-split-audit.md` — descriptor split audit.
- `docs/wiki/raw/research/0787-2026-06-20-precompute-dedicated-genvalid-profile.md` — dedicated profile slice.
- `docs/wiki/ir2/pass-porting-checklist.md` — pass-author metadata and helper rules.
- `src/passes/precompute.mbt` — raw precompute subset and HOT fallback boundaries.
- `src/passes/precompute_test.mbt` — focused O4z/raw skip and direct behavior tests.
- `src/passes/perf_test.mbt` — pass/perf helper context.
- `src/passes/pass_manager.mbt` — O4z raw no-op gate, hazard checks, and pass dispatch.

## TDD notes

Added a focused public-pipeline test first:

- `precompute runs narrow raw scalar folds under O4z gate`

The red run failed because current O4z `precompute` always returned `o4z-precompute-noop`, leaving `i32.const 1; i32.const 2; i32.add` unchanged.

The existing O4z skip coverage was narrowed and renamed to:

- `precompute keeps O4z hot-only cleanup no-op until ownership hazards are safe`

That test uses a `br_table` cleanup shape that `precompute_run_raw_func(...)` deliberately reports as HOT-only, proving this slice does not re-enable the broader O4z HOT path.

## Implementation

`src/passes/pass_manager.mbt` now evaluates the existing raw precompute subset before applying the O4z no-op boundary. Under `optimize_level >= 4 && shrink_level >= 1`, it accepts only changed raw results whose reason is exactly `raw-scalar-folds`.

All other O4z cases still fail closed as `o4z-precompute-noop`, including:

- load/call/local-set ownership hazards;
- large lowered functions;
- SIMD parser / br_table stack hazards;
- raw no-candidate or unchanged results;
- raw TLSF/stale-loop repair reasons;
- any shape that `precompute_run_raw_func(...)` sends to HOT by returning `None`.

This is intentionally a narrow recovery, not a full O4z slot closeout. It reuses the previously documented raw scalar subset while keeping broader HOT cleanup and artifact ownership hazards outside the O4z gate.

## Native artifact path finding

`moon build --target native --release src/cmd` completed, but this checkout still has no `target/native/release/build/cmd/cmd.exe` path. The native release binary actually exists at:

```text
_build/native/release/build/cmd/cmd.exe
```

Using that explicit native path with `--jobs auto` works for compare-pass smoke lanes in this checkout. Final closeout still needs a repo-policy decision: either restore/create the documented `target/native/...` location or explicitly use the observed `_build/native/...` path in the closeout report.

## Commands and results

- `moon test --package jtenner/starshine/passes --file precompute_test.mbt`
  - Red-first result after adding the O4z scalar recovery test: failed `precompute runs narrow raw scalar folds under O4z gate` because `i32.add` remained unchanged.
- `moon test --package jtenner/starshine/passes --file precompute_test.mbt`
  - After implementation and narrowing the skip fixture: passed `33/33`.
- `moon build --target native --release src/cmd && find ...`
  - Native build completed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`; `target/` did not exist, but `_build/native/release/build/cmd/cmd.exe` was present.
- `moon fmt && moon test --package jtenner/starshine/passes --file precompute_test.mbt && moon test src/passes && git diff --check`
  - Passed; focused precompute tests `33/33`, pass package tests `2690/2690`, diff check clean.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass precompute --gen-valid-profile precompute-all --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-genvalid-precompute-all-o4z-slice-smoke-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Compared `100/100`; normalized `53`; cleanup-normalized `47`; mismatches `0`; validation/generator/property/command failures `0`; jobs `16`; cache Binaryen `100` hits / `0` misses. Selected profiles: `precompute-drop-cleanup=17`, `precompute-control=18`, `precompute-gc-atomic-boundary=8`, `precompute-direct-prefix-watch=8`, `precompute-global=20`, `precompute-scalar=17`, `precompute-effect-boundary=12`.
- `moon info && moon test && moon build --target native --release src/cmd && git diff --check`
  - Passed. `moon info` reported three pre-existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`; full tests passed `6012/6012`; native build had no work to do; diff check passed.

## Classification

- O4z gate: partially recovered. Narrow raw scalar folds now run under O4z; broader O4z `precompute` remains fail-closed as `o4z-precompute-noop`.
- New behavior gap: none found in this slice.
- Direct pass behavior: unchanged for ordinary non-O4z direct `--pass precompute`; the compare smoke confirms the explicit `_build` native binary works and keeps the dedicated profile smoke normalized-green with documented PC normalizers.
- `[O4Z-AUDIT-PC]`: remains open. The modern final closeout matrix, slot/neighborhood evidence, and the explicit `target` vs `_build` native path policy still need resolution.

## Commands not run

- No full final closeout lane was run. The `100`-case dedicated-profile smoke is only infrastructure/regression evidence and does not replace the required `10000` dedicated lane or the other final lanes.
- No O4z slot19/slot43 artifact replay was run; the historical `.artifacts` paths are not present in this checkout.

## Next work

1. Decide whether to document `_build/native/release/build/cmd/cmd.exe` as the accepted explicit native compare path for this checkout or restore the documented `target/native/release/build/cmd/cmd.exe` path.
2. Refresh direct/O4z evidence at larger counts only after the native path decision is explicit.
3. Keep `[O4Z-AUDIT-PC]` open until the four-lane matrix and remaining O4z slot/neighborhood evidence are complete.
