---
kind: research
status: supported
created: 2026-06-03
sources:
  - ../../binaryen/passes/memory-packing/index.md
  - ../../binaryen/passes/memory-packing/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/memory-packing/parity.md
  - ../../../../src/passes/memory_packing.mbt
  - ../../../../src/passes/memory_packing_test.mbt
  - ../../../../agent-todo.md
---

# Memory Packing O4z Deep Audit

## Question

Audit active v0.1.0 slice `[O4Z-AUDIT-MP]` for `memory-packing`: pass-level correctness, shape coverage, and pass-local runtime versus Binaryen.

## Implementation conclusions

This slice kept Starshine's deliberately narrow `memory-packing` semantic contract, but made the hot path more scalable:

- `mp_can_optimize(...)` no longer does pairwise active-segment overlap checks. It collects active spans and checks adjacent spans after sorting, reducing the legality gate from O(n²) to O(n log n) for many active segments.
- `memory_packing_run_module_pass(...)` now skips data-usage scanning and passive data-index remap allocation when the module has no passive data segments. Active-only modules no longer walk the entire code section just to discover that no data-index rewrite can be needed.
- `mp_active_rewrite(...)` gained a single-kept-range fast path for common active-segment shapes: leading zeroes, trailing zeroes, all-zero segments, and no internal zero run wider than the existing threshold. It preserves startup-trap behavior by emitting the top byte when required, and falls back to the original range splitter for large internal zero runs.

The upstream parity boundary is unchanged: Starshine still does not implement Binaryen's full passive segment splitting, `memory.fill` insertion, lazy drop-state globals, imported-memory `zeroFilledMemory` mode, or `MaxDataSegments` cap.

## Test coverage added

New focused coverage in `src/passes/memory_packing_test.mbt`:

- empty active segment with a trapping offset remains unchanged
- trailing startup trap after a nonzero prefix (`"A\00\00"` near memory end)
- imported-memory bailout keeps active data unchanged
- passive `array.new_data` / `array.init_data` users are remapped after active segment count changes
- constant memory64 active offsets rewrite through the i64 offset path
- many out-of-order non-overlapping active segments still optimize correctly

## Direct oracle evidence

Baseline smoke before behavior changes:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass memory-packing --out-dir .tmp/pass-fuzz-memory-packing-audit-baseline-1000
```

Result: `998 / 1000` compared, `998` normalized matches, `0` mismatches, `2` command failures. Both command failures were Binaryen zero-sized recursion-group parser/canonicalization failures.

Post-change smoke:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass memory-packing --out-dir .tmp/pass-fuzz-memory-packing-audit-current-1000
```

Result: `998 / 1000` compared, `998` normalized matches, `0` mismatches, `2` command failures.

Post-change 10000-request lane, first without and then with command-failure keep-going:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass memory-packing --out-dir .tmp/pass-fuzz-memory-packing-audit-current-10000
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass memory-packing --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-memory-packing-audit-current-10000-keepgoing
```

The non-keep-going run reached `6759 / 10000` compared, `6759` normalized matches, `0` mismatches, and `20` command failures before the harness hit its command-failure cap.

The keep-going run reached `9975 / 10000` compared, `9975` normalized matches, `0` mismatches, and `25` command failures. Failure classes were:

- `22` Binaryen zero-sized recursion group parser/canonicalization failures
- `1` Binaryen bad-section-size command failure
- `1` Binaryen table-index-out-of-range command failure
- `1` Binaryen invalid-tag-index command failure

Agent classification: these are tool/Binaryen command failures, not Starshine semantic mismatches. No semantic mismatch family was observed.

## Pass-local performance evidence

Benchmark fixtures were generated under `.tmp/mp-audit-benches/` and run with release native CLIs plus Binaryen `wasm-opt --debug`.

Commands used for Starshine samples were equivalent to:

```sh
_build/native/release/build/cmd/cmd.exe --memory-packing --tracing pass --out <out.wasm> <input.wasm>
```

Binaryen samples used:

```sh
wasm-opt <input.wasm> --memory-packing --all-features --debug -o <out.wasm>
```

Median pass-local timings over 9 samples:

| Fixture | Before Starshine median | After Starshine median | Binaryen median | Result |
| --- | ---: | ---: | ---: | --- |
| active-only-large-code | `511 us` | `12 us` | `4223.3 us` | after Starshine is ~`42.6x` faster than old Starshine and ~`351.9x` faster than Binaryen on pass-local time |
| many-active-segments | `4421 us` | `825 us` | `975.6 us` | after Starshine is ~`5.4x` faster than old Starshine and ~`1.18x` faster than Binaryen |

Artifact paths:

- Baseline/current-vs-Binaryen first run: `.tmp/mp-audit-benches/results/summary.json`
- Final fast-path Starshine rerun: `.tmp/mp-audit-benches/results-fast/summary.json`

## Moon signoff evidence

Commands run:

```sh
moon test src/passes
moon test
```

Results:

- `moon test src/passes`: `1471` tests passed, `0` failed.
- `moon test`: `4648` tests passed, `0` failed.

Caveats:

- `moon info` crashed in the local Moon tool with `index out of bounds: the len is 36 but the index is 8329485`; this is a tool crash, not a pass failure.
- `moon fmt --check src/passes/memory_packing.mbt src/passes/memory_packing_test.mbt` failed because this Moon version reports repo-wide formatting/migration drift in unrelated package files such as `src/passes/optimize.mbt`, `src/passes/moon.pkg`, and `src/passes/tuple_optimization.mbt`. The check did not identify `memory_packing.mbt` or `memory_packing_test.mbt` as the reported diffs.

## Remaining risks and deferred scope

- Full Binaryen passive-segment rewrite parity remains deferred: no local `memory.init` replacement planner, no `memory.fill`, no data-drop expansion across split passive survivors, and no lazy drop-state global.
- Imported-memory optimization remains a conservative bailout, unlike Binaryen's optional `zeroFilledMemory` mode.
- High-address memory64 and encoded-offset overflow policy remains inherited from the existing local implementation; this slice added constant memory64 coverage but did not broaden the high-bit contract.
- Whole-command wall-time attribution is still under `[WALL]001`; this slice only claims pass-local improvement.
