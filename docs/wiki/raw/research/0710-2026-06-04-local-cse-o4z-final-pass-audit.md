---
kind: research
status: supported
last_reviewed: 2026-06-04
sources:
  - ../binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md
  - ../../binaryen/passes/local-cse/index.md
  - ../../binaryen/passes/local-cse/basic-block-windows-and-barriers.md
  - ../../binaryen/passes/local-cse/implementation-structure-and-tests.md
  - ../../binaryen/passes/local-cse/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/local_cse.mbt
  - ../../../../src/passes/local_cse_test.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../agent-todo.md
---

# Local-CSE O4z Final-Pass Audit

## Scope

Audited active v0.1.0 slice `[O4Z-AUDIT-LCSE]` for `local-cse` as a focused final-pass audit against Binaryen. The audit looked for direct semantic parity gaps, missed Binaryen-positive shapes, and pass-local runtime ownership.

## Why this pass was chosen

`local-cse` has a localized implementation and wiki dossier, sits in the late `-O4z` local-cleanup neighborhood, and has clear Binaryen source-backed positive and negative shapes. That made it a good fit for a focused audit without expanding to every active O4z pass.

## Direct compare evidence

Built the native CLI once:

```sh
moon build --target native --release src/cmd
```

Result: finished with no work to do.

Ran direct pass compare:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-audit-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- compared cases: `998/1000`
- normalized matches: `998`
- compare-normalized matches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `2`
- mismatches: `0`

The two command failures were agent-classified as Binaryen/tool parse failures for empty recursion groups, not Starshine semantic failures:

- `.tmp/pass-fuzz-local-cse-audit-1000/failures/case-000029-wasm-smith/`
- `.tmp/pass-fuzz-local-cse-audit-1000/failures/case-000573-wasm-smith/`

Both failure metadata entries show Binaryen `wasm-opt` rejecting `Recursion groups of size zero not supported`.

## Functional findings

### No generated semantic mismatches in the 1000-case lane

The direct generated lane did not expose semantic mismatches. Agent classification: no true semantic mismatch found in this audit lane.

### Missed Binaryen-positive shape: before-`if` into `then` reuse

The focused source/wiki review found a durable missed optimization relative to Binaryen's `LinearExecutionWalker` behavior with `connectAdjacentBlocks = true`: Binaryen can reuse a repeated expression computed before an `if` inside the `then` arm. The follow-up 2026-06-04 `version_130` / current-main source refresh at [`../binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md`](../binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md) found no teaching-relevant Binaryen drift on this source-backed window model. Current Starshine raw/module `local-cse` does not carry the outer reuse window into the `then` body, so it leaves both trees in place.

Focused repro written under `.tmp/local-cse-audit-perf/before-if-then.wat` during the audit:

```wat
(module
  (func (param i32 i32 i32)
    (drop (i32.add (local.get 0) (local.get 1)))
    (if (local.get 2)
      (then
        (drop (i32.add (local.get 0) (local.get 1)))))))
```

Commands:

```sh
wasm-tools parse .tmp/local-cse-audit-perf/before-if-then.wat \
  -o .tmp/local-cse-audit-perf/before-if-then.wasm
wasm-opt .tmp/local-cse-audit-perf/before-if-then.wasm \
  --all-features --local-cse -S \
  -o .tmp/local-cse-audit-perf/before-if-then.binaryen.wat
target/native/release/build/cmd/cmd.exe --local-cse \
  -o .tmp/local-cse-audit-perf/before-if-then.starshine.wasm \
  .tmp/local-cse-audit-perf/before-if-then.wasm
wasm-opt .tmp/local-cse-audit-perf/before-if-then.starshine.wasm \
  --all-features -S --strip-debug \
  -o .tmp/local-cse-audit-perf/before-if-then.starshine.wat
```

Observed shape:

- Binaryen inserts a fresh local, wraps the first add with `local.tee`, and uses `local.get` in the `then` arm.
- Starshine keeps both `i32.add` trees.

Agent classification: semantic-safe missed optimization / functional parity gap, not a semantic mismatch. The safe fix is nontrivial because current Starshine's raw module-pass rewrite is region-local and would need cross-region binding materialization that can wrap an outer original while replacing a nested `then` repeat.

Suggested next slice: add a failing WAT test for this exact shape, then teach `local-cse` to share eligible outer bindings with the `then` region only, without sharing into the `else` arm or after the `if`. Preserve Binaryen's negative boundaries for after-`if`, else-arm, loops, br_table/switch, returns, throws, unreachable, and try regions.

## Performance findings

The compare harness summary did not report timings for `compare-pass`, so pass-local timing was captured with Starshine tracing and Binaryen debug pass timing on the checked-in debug-WASI artifact.

Starshine command, repeated three times:

```sh
target/native/release/build/cmd/cmd.exe --local-cse --tracing pass \
  -o .tmp/local-cse-audit-perf/starshine-N.wasm \
  tests/node/dist/starshine-debug-wasi.wasm
```

Starshine `perf:timer name=pass:local-cse` results:

- `63,495 us`
- `64,668 us`
- `66,576 us`

Binaryen command, repeated three times:

```sh
wasm-opt tests/node/dist/starshine-debug-wasi.wasm \
  --all-features --local-cse --debug \
  -o .tmp/local-cse-audit-perf/binaryen-debug-N.wasm
```

Binaryen debug pass timing results:

- `0.109826 seconds`
- `0.108852 seconds`
- `0.110042 seconds`

Agent classification: Starshine direct pass-local time is acceptable on this artifact. The observed Starshine pass timer is about `63-67 ms`; Binaryen reports about `109-110 ms` for the pass. This clears the repository target `starshine_time <= 2 * binaryen_time` for this sampled artifact.

Caveat: this is artifact-level pass timing, not a full runtime study. Whole-command wall time, parse/emit, validation, and harness overhead remain `[WALL]001` territory unless future evidence shows `local-cse` itself owns a regression.

## Test and source gap review

Current adjacent tests cover repeated arithmetic roots, parent-over-child preference, load/store barriers, and local-write invalidation. The audit found the following missing source-backed shapes worth adding before closing `[O4Z-AUDIT-LCSE]`:

1. before-`if` into `then` positive (confirmed missed optimization above)
2. after-`if` negative, to prevent accidentally widening reuse past Binaryen's window
3. else-arm negative, paired with the then-arm positive
4. loop/control boundary negatives
5. explicit tiny-root no-op such as repeated `global.get`
6. GC/generative-root negatives such as `struct.new` / `array.new*` where supported by the local fixture stack
7. idempotent direct-call positive only if Starshine has enough annotation plumbing to model the Binaryen exception safely

## Recommendation

Do not mark `[O4Z-AUDIT-LCSE]` complete yet. The direct generated compare lane is green, and pass-local timing is acceptable, but the before-`if`/then-arm Binaryen-positive shape is a real missed optimization with adjacent missing tests. Treat the next implementation slice as a small LCSE window-model parity task rather than a broad rewrite.
