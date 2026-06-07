# Handoff: json-as full-suite validation and optimizer follow-up

Date: 2026-06-06
Workspace: `/home/jtenner/Projects/starshine-mb`
Current HEAD: `67bb6ef8d Guard large json-as cleanup shapes`

## Task

Continue Starshine optimizer correctness and size/parity work around the `json-as` suite and artifacts.

The immediate user goal was to run the full `json-as` test suite against generated/optimized artifacts first, then directly compare Binaryen and Starshine performance/size. This has now been done locally with a Node WASI `as-test` runner. The next agent should preserve the evidence, avoid overstating it, and continue with either durable replay tooling, preset-widening work, or broader O4/O4z parity work.

## User intent and success criteria

- Correctness first.
- Do not claim Starshine is safe for arbitrary Wasm based only on these artifacts.
- Distinguish:
  - validation,
  - Node benchmark `start` smoke,
  - full `json-as` `as-test` suite execution,
  - real benchmark harness performance.
- Preserve the untracked wasm files under `examples/modules/`; do not delete or overwrite them.
- If changing behavior, use TDD: write/update tests first, confirm failure, then implement.
- Prefer exact, artifact-backed claims with command paths and logs.

## Current status

### Git status

Tracked tree is clean after commit `67bb6ef8d`. Known untracked artifacts remain under `examples/modules/`:

```text
examples/modules/large.lazy.bench.incremental.swar.starshine.optimized.wasm
examples/modules/large.lazy.bench.incremental.swar.wasm
examples/modules/medium.bench.incremental.naive.starshine.optimized.wasm
examples/modules/medium.bench.incremental.naive.wasm
examples/modules/medium.bench.incremental.simd.starshine.optimized.wasm
examples/modules/medium.bench.incremental.simd.wasm
examples/modules/medium.lazyauto.bench.incremental.simd.starshine.optimized.wasm
examples/modules/medium.lazyauto.bench.incremental.simd.wasm
```

### Recent commits

```text
67bb6ef8d Guard large json-as cleanup shapes
ae8fb7020 Document json-as DFE CF RSE preset analysis
56ecdfd2e Record DFE CF RSE restored-artifact smoke
5ab3b53ae Preserve RSE loop-entry default resets
cd566ae6c Record duplicate-function-elimination compare signoff
4bd541de0 Record redundant-set-elimination compare signoff
ce9496b0d Record code-folding direct compare signoff
bb5a5ede3 Drop false self-branch loops in precompute
```

## Work completed in this slice

### Full json-as suite setup

The `json-as` checkout used is:

```text
.tmp/json-as-f707d68
```

Inspected config:

- `.tmp/json-as-f707d68/package.json`
- `.tmp/json-as-f707d68/as-test.config.json`

Important facts:

- Suite command is `ast test --parallel --enable try-as`.
- Config covers `35` spec files under `assembly/__tests__/*.spec.ts`.
- Modes: `naive`, `swar`, `simd`.
- Build artifacts: `.as-test/build/<mode>/*.spec.wasm`.
- Runtime default expected `wasmtime`, but `wasmtime` was not installed locally.

Created temporary Node WASI runner/config in the clone:

- `.tmp/json-as-f707d68/.tmp-run-wasi.mjs`
- `.tmp/json-as-f707d68/as-test.node.config.json`

The runner instantiates WASI modules under Node and invokes `_start` with `returnOnExit: true`.

Built full baseline suite:

```sh
cd .tmp/json-as-f707d68
./node_modules/.bin/ast build \
  --config as-test.node.config.json \
  --mode naive,swar,simd \
  --parallel --enable try-as --no-cache --clean
```

Copied baseline artifacts to:

```text
.tmp/jsonas-suite-test/baseline-build
```

Baseline Node WASI suite passed. Log:

```text
.tmp/jsonas-suite-baseline-node.log
```

### Initial failures discovered and fixed/guarded

Starshine `--optimize -O4` initially failed on:

```text
.tmp/jsonas-suite-test/baseline-build/naive/json-runtime.spec.wasm
```

Initial failure:

```text
error: final module validate: type mismatch
Offending function idx=(Func 844)
```

Bisection showed:

- `--reorder-locals` alone was not responsible.
- Prefix through `precompute` could pass Starshine internal validation, but external `wasm-tools validate` exposed issues earlier in the suite path.
- `code-pushing`, `merge-blocks`, and `remove-unused-brs` needed conservative large-shape guards for `json-as`-shaped functions.

Commit `67bb6ef8d Guard large json-as cleanup shapes` added:

- `src/passes/code_pushing_test.mbt`
  - large local-heavy `json-as`-shaped skip regression
- `src/passes/merge_blocks_test.mbt`
  - large local-heavy `json-as`-shaped skip regression
- `src/passes/remove_unused_brs_test.mbt`
  - deep dispatch / large-local `json-as`-shaped skip regression
- `src/passes/pass_manager.mbt`
  - conservative skip guards for the above shapes
- `src/passes/remove_unused_brs.mbt`
  - small related adjustment from the committed fix
- `agent-todo.md`
  - recorded full-suite replay evidence and follow-up status

Focused/full pass tests after the commit:

```sh
moon fmt
moon test src/passes/code_pushing_test.mbt
moon test src/passes/merge_blocks_test.mbt
moon test src/passes/remove_unused_brs_test.mbt
moon test src/passes
moon build --target native --release src/cmd
```

Key final test result:

```text
Total tests: 1735, passed: 1735, failed: 0.
```

## Full json-as Starshine suite evidence

Generated all 105 Starshine O4 suite artifacts from baseline build artifacts:

```sh
target/native/release/build/cmd/cmd.exe \
  --traps-never-happen --closed-world --optimize -O4 \
  -o <dst> <src>
```

Output tree:

```text
.tmp/jsonas-suite-test/starshine-o4
```

Final per-artifact optimization logs:

```text
.tmp/jsonas-suite-test/starshine-o4-logs-final
```

Validation:

```sh
wasm-tools validate --features all .tmp/jsonas-suite-test/starshine-o4/*/*.wasm
```

Result:

```text
105/105 valid
```

Full `json-as` suite run under Node WASI:

```sh
cd .tmp/json-as-f707d68
cp -a ../../.tmp/jsonas-suite-test/starshine-o4/. .as-test/build/
./node_modules/.bin/ast run \
  --config as-test.node.config.json \
  --mode naive,swar,simd \
  --parallel --enable try-as --clean \
  > ../../.tmp/jsonas-suite-starshine-o4-node-final.log 2>&1
```

Final Starshine result:

```text
Files:   0 failed, 0 skipped,    35 total
Suites:  0 failed, 3 skipped,  1284 total
Tests:   0 failed, 0 skipped, 10656 total
Modes:   0 failed, 0 skipped,     3 total
Time:    5.156s (36.507s build)
```

Log:

```text
.tmp/jsonas-suite-starshine-o4-node-final.log
```

## Binaryen comparison evidence

Generated Binaryen O4 outputs for all 105 baseline artifacts:

```sh
.tmp/json-as-f707d68/node_modules/.bin/wasm-opt \
  -O4 --all-features \
  <src> -o <dst>
```

Output tree:

```text
.tmp/jsonas-suite-test/binaryen-o4
```

Binaryen validation:

```text
105/105 valid
```

Binaryen suite run:

```sh
cd .tmp/json-as-f707d68
cp -a ../../.tmp/jsonas-suite-test/binaryen-o4/. .as-test/build/
./node_modules/.bin/ast run \
  --config as-test.node.config.json \
  --mode naive,swar,simd \
  --parallel --enable try-as --clean \
  > ../../.tmp/jsonas-suite-binaryen-o4-node-final.log 2>&1
```

Final Binaryen result:

```text
Files:   0 failed, 0 skipped,    35 total
Suites:  0 failed, 3 skipped,  1284 total
Tests:   0 failed, 0 skipped, 10656 total
Modes:   0 failed, 0 skipped,     3 total
Time:    5.5s (36.004s build)
```

Log:

```text
.tmp/jsonas-suite-binaryen-o4-node-final.log
```

## Size comparison across 105 suite artifacts

Computed by summing `*.wasm` file sizes under each tree:

| Set | Total bytes |
| --- | ---: |
| Baseline build | `68,279,901` |
| Starshine O4 | `57,167,519` |
| Binaryen O4 | `44,696,598` |

Deltas:

- Starshine vs baseline: `-11,112,382` bytes (`83.73%` of baseline)
- Binaryen vs baseline: `-23,583,303` bytes (`65.46%` of baseline)
- Starshine vs Binaryen: `+12,470,921` bytes (`1.279x`, about `+27.9%` larger)

By mode:

| Mode | Baseline | Starshine | Binaryen | Starshine/Binaryen |
| --- | ---: | ---: | ---: | ---: |
| naive | `20,649,811` | `18,107,704` | `14,663,071` | `1.235x` |
| swar | `21,225,942` | `18,742,006` | `14,951,703` | `1.254x` |
| simd | `26,404,148` | `20,317,809` | `15,081,824` | `1.347x` |

Interpretation:

- Starshine O4 is correct on this full suite under the Node WASI runner.
- Starshine still has a large size gap versus Binaryen O4, especially in SIMD.
- This is full-suite correctness evidence for the pinned `json-as` clone/config, not universal Wasm correctness.

## Runtime / performance comparison caveats

The direct runtime comparison used the Node WASI `as-test` runner, not the official `json-as` benchmark harness or a stable `d8`/V8 benchmark environment.

Earlier 3-trial Node WASI suite timings:

- Starshine O4: `[6.399s, 6.083s, 7.540s]`, mean `6.674s`, median `6.399s`
- Binaryen O4: `[5.876s, 5.760s, 5.752s]`, mean `5.796s`, median `5.760s`

Ratios:

- Mean: Starshine `1.151x` Binaryen
- Median: Starshine `1.111x` Binaryen

Final single run after refined guards:

- Starshine: `5.156s`
- Binaryen: `5.5s`

Because the runner is noisy and includes process/test harness overhead, treat these as local proxy evidence only. Do not make a stable benchmark claim until the real benchmark harness/runtime is available.

Additional local perf summary path mentioned in `agent-todo.md`:

```text
.tmp/jsonas-suite-test/wasi-artifact-perf-summary.json
```

## Important durable docs / backlog

Durable research note from earlier analysis:

```text
docs/wiki/raw/research/0713-2026-06-06-jsonas-dfe-cf-rse-preset-analysis.md
```

This note covers the `DFE + RUME + CF + RSE + RUME` suffix candidate on debug benchmark artifacts, including section-size evidence and direct-pass compare evidence.

`agent-todo.md` was updated in commit `67bb6ef8d`, especially `[JSON-AS]004`, to record that:

- full `as-test` suite replay is Starshine-green for the pinned clone,
- it is not yet scripted as a durable repo task,
- correctness is ahead of size parity,
- Node WASI timing is proxy evidence only.

## Relevant temporary paths

- `json-as` clone:
  - `.tmp/json-as-f707d68`
- Node WASI runner/config:
  - `.tmp/json-as-f707d68/.tmp-run-wasi.mjs`
  - `.tmp/json-as-f707d68/as-test.node.config.json`
- Baseline artifacts:
  - `.tmp/jsonas-suite-test/baseline-build`
- Starshine O4 artifacts:
  - `.tmp/jsonas-suite-test/starshine-o4`
- Starshine final optimization logs:
  - `.tmp/jsonas-suite-test/starshine-o4-logs-final`
- Binaryen O4 artifacts:
  - `.tmp/jsonas-suite-test/binaryen-o4`
- Final suite logs:
  - `.tmp/jsonas-suite-starshine-o4-node-final.log`
  - `.tmp/jsonas-suite-binaryen-o4-node-final.log`
- Earlier useful debug logs:
  - `.tmp/jsonas-suite-test/json-runtime-opt.log`
  - `.tmp/jsonas-suite-test/json-runtime-debug-serial.log`
  - `.tmp/jsonas-suite-test/json-runtime-o4-after-rusb-guard.log`
  - `.tmp/jsonas-suite-test/json-runtime-o4-debug-after-merge-guard.log`

## Repository rules and workflow reminders

From `AGENTS.md` / active project rules:

- MoonBit workspace under `moon.mod`.
- Tests live beside implementation as `*_test.mbt` or `*_wbtest.mbt`.
- Use TDD for behavior changes.
- Serialize `moon` commands; they contend on `_build/.moon-lock`.
- Preferred quick signoff: `moon info`, `moon fmt`, `moon test`.
- `moon info` previously crashed locally with a Moon internal panic; do not claim a clean `moon info` gate unless rerun successfully.
- Preferred broader gate before publishing: `bun validate` or `bun validate full --profile ci --target wasm-gc`.
- Do not delete or overwrite the untracked wasm files under `examples/modules/`.
- Correctness first; every transform must be safe and produce valid wasm.
- When reporting compare-pass mismatches, classify as agent judgment; validation alone does not prove semantic safety.

## Open questions / risks

1. **Durable replay tooling missing**
   - Full suite replay currently depends on temporary `.tmp/json-as-f707d68` files and ad hoc commands.
   - `[JSON-AS]004` asks for a documented opt-in replay command/task.

2. **Performance evidence is proxy-only**
   - Node WASI `as-test` timing is useful, but not an official benchmark claim.
   - Prefer real `json-as` benchmark harness / `d8` runner if available later.

3. **Size parity gap remains large**
   - Starshine full-suite outputs are ~27.9% larger than Binaryen O4.
   - Debug benchmark artifact analysis similarly showed remaining function/type/code gaps.

4. **Preset widening is not landed**
   - `DFE + RUME + CF + RSE + RUME` remains an incremental candidate, not currently scheduled in the default preset.
   - Landing it should happen in a dedicated slice with exact order tests and refreshed full-suite/artifact evidence.

5. **Conservative guards may leave optimization on the table**
   - `67bb6ef8d` uses correctness-first skips for large `json-as`-shaped cleanup hazards.
   - Future work can replace broad guards with more precise safe rewrites, but only with focused TDD + suite evidence.

## Recommended next actions

1. Decide whether the next goal is:
   - durable `json-as` replay tooling,
   - preset widening with `DFE + RUME + CF + RSE + RUME`,
   - deeper size parity work,
   - or replacing conservative large-shape guards with precise safe transforms.

2. If creating replay tooling:
   - keep it opt-in and `.tmp`-based,
   - do not touch `examples/modules/*.wasm`,
   - include build, Starshine optimize, Binaryen optimize, `wasm-tools validate`, and Node WASI suite execution.

3. If widening presets:
   - add exact order tests for:
     - `duplicate-function-elimination`
     - `remove-unused-module-elements`
     - `code-folding`
     - `redundant-set-elimination`
     - trailing `remove-unused-module-elements`
   - rerun direct pass compare evidence for newly scheduled passes if behavior changes,
   - rerun the full `json-as` suite replay.

4. If pursuing size parity:
   - start from `docs/wiki/raw/research/0713-2026-06-06-jsonas-dfe-cf-rse-preset-analysis.md`,
   - focus on function/type/code liveness and inlining-derived cleanup gaps,
   - keep inlining lanes blocked until direct compare/runtime evidence is clean.

5. If continuing cleanup guard refinement:
   - use the `json-runtime.spec.wasm` and deep-dispatch examples as integration evidence,
   - minimize to focused fixtures before changing behavior,
   - always validate with both Starshine internal validation and `wasm-tools validate --features all` because external validation caught failures that internal validation initially missed.
