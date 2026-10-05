---
kind: workflow
status: supported
last_reviewed: 2026-10-05
sources:
  - ../raw/tooling/2026-10-04-starshine-v133-review.json
  - ../raw/tooling/2026-10-05-starshine-p00-checkpoint.json
  - ../../../claude_review_10_3_6.md
  - ../../../src/passes/dae2_effect_order_wbtest.mbt
  - ../../../src/ir/hot_mutate.mbt
  - ../../../src/validate/frame_polymorphism_wbtest.mbt
  - ../../../src/cmd/p00_validator_wbtest.mbt
  - ../../../src/cmd/p00_oi_order_wbtest.mbt
  - ../../../src/cmd/p00_dae2_polymorphic_wbtest.mbt
  - ../../../src/ir/hot_nested_dead_drop_wbtest.mbt
  - ../../../src/ir/hot_typed_prefix_verify_wbtest.mbt
  - ../../../src/ir/hot_virtual_entry_access_wbtest.mbt
  - ../../../scripts/test/p00-correctness-runtime.ts
  - https://nodejs.org/api/wasi.html
  - https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
  - https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html
  - https://docs.moonbitlang.com/en/latest/language/verification.html
  - https://moonbitlang.github.io/moon/commands.html
  - ../../README.md
  - ../../../AGENTS.md
  - ../../../package.json
  - ../../../moon.mod
  - ../../../scripts/validate.ts
  - ../../../scripts/lib/validate-task.ts
  - ../../../scripts/lib/task-runtime.ts
  - ../../../scripts/lib/fuzz-task.ts
  - ../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../scripts/lib/self-opt-task.ts
  - ../../../scripts/lib/self-optimized-artifacts.mjs
  - ../../../scripts/lib/run-self-optimized-spec-suite.mjs
  - ../../../scripts/lib/moonbit-wasi-runner.mjs
  - ../binaryen/passes/dae-optimizing/index.md
  - ../../../scripts/test/task-family-commands.ts
  - ../../../scripts/test/ci-workflow-contract.ts
  - ../../../.github/workflows/ci.yml
related:
  - ./wasi-runner-and-preview-boundary.md
  - ./cli-command-and-dispatcher.md
  - ./release-process.md
  - ./moonbit-workspace-package-map.md
  - ./fuzz-runner.md
  - ./pass-fuzz-compare.md
  - ./external-validator-adapters.md
  - ./tracing-playbook.md
  - ../validation/moonbit-prove-strategy.md
  - ../validate/module-validation-phases.md
  - ../validate/diagnostics-and-invalid-repro.md
  - ../validate/trace-benchmark-baseline.md
  - ../validate/fuzz-hardening.md
  - ../fuzzing/generator-coverage-ledger.md
---

# Validation Gates

> **Comparison baseline — October 4, 2026:** new comparisons use [Binaryen 133](../binaryen/release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v133 signoff.

## Overview

Starshine has three layers of validation:

1. **Wasm module validation** inside [`src/validate`](../../../src/validate/), whose phase map is documented in [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md) and whose diagnostic-family / invalid-repro contract is documented in [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md).
2. **MoonBit-native checks** (`moon info`, `moon fmt`, `moon check`, `moon test`, `moon coverage analyze`, and separate `moon prove` lanes) supplied by the MoonBit toolchain.
3. **Repository orchestration** (`bun validate ...`, `bun fuzz ...`, pass comparison scripts, and self-optimize comparison scripts) that chooses the target, ordering, profiles, seeds, and artifact/report conventions for Starshine.

The important maintenance rule is: **do not blur tool capability with repo policy**. The official [Moon command manual](https://moonbitlang.github.io/moon/commands.html) establishes the upstream commands as building blocks, but Starshine's exact default target, target whitelist, fuzz profile, command order, and CI/reporting semantics live in [`scripts/lib/validate-task.ts`](../../../scripts/lib/validate-task.ts), [`scripts/lib/task-runtime.ts`](../../../scripts/lib/task-runtime.ts), and the command-shape tests in [`scripts/test/task-family-commands.ts`](../../../scripts/test/task-family-commands.ts). For the runtime `starshine` command itself, use the separate dispatcher contract in [`cli-command-and-dispatcher.md`](./cli-command-and-dispatcher.md).

## Command Matrix

| Command | What it proves locally | Inputs and defaults | Use it when |
| --- | --- | --- | --- |
| `moon info` | Package metadata and generated-interface surfaces can be refreshed. Public API changes should be visible in `.mbti` diffs. | Starshine's gate runs bare `moon info` at the workspace root from [`moon.mod`](../../../moon.mod); package topology and `moon.pkg` ownership are mapped in [`moonbit-workspace-package-map.md`](moonbit-workspace-package-map.md). Upstream `moon info --target <target>` is an inspection tool for backend-specific interfaces, not the local generated-interface default. | Any code/API change, before reviewing `.mbti` drift, and as the first step in the quick gate. |
| `moon fmt` | MoonBit source formatting is normalized. | Starshine invokes mutating `moon fmt`, not `moon fmt --check`, so the gate can rewrite files; review the post-gate diff before commit. | Every source-changing slice before commit. |
| `moon check --target <target>` | The workspace type-checks for the selected Moon target without running tests. | `bun validate full` defaults to `wasm-gc`; the local wrapper forwards only repo-whitelisted targets. Upstream path selectors and `moon check --fmt` are available for focused work but are not part of the full-gate command shape. | Full-gate pre-test typecheck and target-specific breakage triage. |
| `moon test --target <target>` | Deterministic package tests pass for the selected target. | `bun validate full` defaults to `wasm-gc`; upstream supports path/package/doc/index/update controls for focused TDD, while the local full gate intentionally runs the workspace-level target test. | Required for behavior changes; prefer focused `moon test src/<pkg>` earlier in a TDD loop. |
| `bun validate full [--profile ci] [--seed <seed>] [--target wasm-gc]` | Runs the repo's local CI floor: `info`, `fmt`, `check`, `test`, then all fuzz suites through [`runFuzz(...)`](../../../scripts/lib/fuzz-task.ts). | Defaults: profile `ci`, target `wasm-gc`, random/time-derived fuzz seed when omitted, `moon` from `MOON_BIN` or `moon`. | Release-like local gate, broad validation before publishing, and high-risk behavior changes; use [`release-process.md`](release-process.md) for the full version/package/release-note checklist. |
| `bun validate coverage [--top n] [--baseline path] [--update-baseline]` | Parses `moon coverage analyze`, reports uncovered-line totals, and optionally fails CI on uncovered-line regression versus a simple baseline file. | Default top count is `10`; no baseline means report-only. | Coverage reviews and CI coverage-regression checks. |
| `bun validate readme-api-sync ...` | Verifies README/API synchronization through [`scripts/lib/readme-api-sync`](../../../scripts/lib/readme-api-sync.ts). | Arguments are owned by the readme-sync parser. | Public API or README surface changes. |
| `bun validate trace-benchmark [--repeat n] [--corpus name] [--target target] [--list-corpora]` | Runs `src/validate_trace` benchmark corpora and emits trace summaries; the wiki stores durable corpus totals separately from machine wall time. | Default target `wasm-gc`; repeated `--corpus` filters and `--list-corpora` lists available corpora. | Validator trace performance work. |
| `bun validate self-opt-smoke [--wasm path] [--limit n|--file path]` | Validates an already-built self-optimized CLI artifact with `wasm-tools validate --features all`, executes the artifact under the Node-hosted WASI Preview 1 runner with `--help`, then runs a fast WAST spec workload. | Defaults to `tests/node/dist/starshine-self-optimized-wasi.wasm` and `--limit 1`; `--wasm` may point at a candidate artifact such as `.tmp/o4z-bench/starshine-o4z-candidate.wasm`. | Checking optimized-artifact safety without rebuilding the full self-opt pipeline; runner/Preview boundaries live in [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md). |
| `bun validate self-opt-full [--wasm path]` | Runs the same wasm-validity and Node-hosted WASI Preview 1 smoke checks as `self-opt-smoke`, then executes all checked-in `tests/spec/**/*.wast` files through the self-optimized CLI artifact. | Forwards to the self-opt check lane with `--full-spec`; ask before running because it is intentionally broader than the default smoke lane. | CI/full signoff that the optimized artifact remains runtime-safe and spec-workload-correct. |
| `moon prove src/validate_proof` | Required formal-proof gate for the proof helper package, separate from ordinary validation. | Requires a configured MoonBit proof toolchain and solvers; solver/config flags are host-tooling controls, not semantic repo policy. | Changes to proved helper contracts or the validator proof kernel. |

## `bun validate full` Flow

[`runValidateFull(...)`](../../../scripts/lib/validate-task.ts) is intentionally ordered:

```text
moon info
moon fmt
moon check --target <target>
moon test --target <target>
bun fuzz run --suite all --profile <profile> --seed <seed> --target <target>
```

Why this order matters:

- `moon info` runs before format/test so public interface drift is not missed until review time. The upstream `moon` manual now documents richer backend inspection with `--target`, but this gate deliberately uses the canonical bare `moon info` output.
- `moon fmt` is early because it is deterministic and cheap compared with full test/fuzz lanes. It is also mutating in this repo gate; if it rewrites files, inspect and commit those edits intentionally.
- `moon check` isolates target typechecking before test failures obscure compile failures.
- `moon test` stays deterministic; heavy randomized work is kept in the fuzz runner.
- Fuzz runs last because they are broader, slower, and seed/profile dependent.

The target whitelist is local to [`scripts/lib/task-runtime.ts`](../../../scripts/lib/task-runtime.ts): `native`, `wasm`, `wasm-gc`, `llvm`, and `js`. `bun validate full` rejects other target names before running Moon commands. Upstream Moon documents target `all`; Starshine does **not** currently accept `all` through `bun validate`, `bun fuzz`, or `trace-benchmark` wrappers, so widening that target is a local script/test/docs change rather than a docs-only correction.

## Required GitHub CI

[`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml) is the required, read-only-permission CI floor for every pull request, every push to `master`, and manual dispatch. It intentionally has no path filter. Concurrency cancellation keeps only the newest run for one workflow/ref pair, and every job has a 30-minute timeout. [`scripts/test/ci-workflow-contract.ts`](../../../scripts/test/ci-workflow-contract.ts) makes the job names, commands, bounds, deterministic seeds, DAE normalizers, artifact checks, and `master` branch triggers reviewable and enforceable instead of leaving them as documentation-only promises.

The three jobs and their exact local equivalents are:

1. **`format-and-tests`** refreshes interfaces, applies formatting, checks that the generated raw FFI wrappers and export-name map match those interfaces, rejects any resulting tracked diff, and runs the complete default Moon test suite:

   ```text
   moon update
   bun scripts/test/ci-workflow-contract.ts
   moon info
   moon fmt
   bun ffi check
   git diff --exit-code
   moon test
   ```

   The FFI check closes the gap between public `.mbti` changes and the checked-in
   `ffi/src/ffi` wrapper surface. A new public function must not merge with stale
   raw WasmGC exports.

2. **`release-artifacts`** builds both supported release artifacts, externally validates the wasm-gc CLI with wasm-tools `1.251.0`, requires two no-pass Starshine decode/encode cycles to converge byte-for-byte, and runs the bounded binary-roundtrip fuzz suite:

   ```text
   moon update
   moon build --target native --release src/cmd
   moon build --target wasm-gc --release src/cmd
   wasm-tools validate --features all _build/wasm-gc/release/build/cmd/cmd.wasm
   mkdir -p .tmp/ci-roundtrip
   _build/native/release/build/cmd/cmd.exe _build/wasm-gc/release/build/cmd/cmd.wasm -o .tmp/ci-roundtrip/roundtrip-1.wasm
   _build/native/release/build/cmd/cmd.exe .tmp/ci-roundtrip/roundtrip-1.wasm -o .tmp/ci-roundtrip/roundtrip-2.wasm
   wasm-tools validate --features all .tmp/ci-roundtrip/roundtrip-1.wasm
   wasm-tools validate --features all .tmp/ci-roundtrip/roundtrip-2.wasm
   cmp .tmp/ci-roundtrip/roundtrip-1.wasm .tmp/ci-roundtrip/roundtrip-2.wasm
   bun fuzz run --suite binary-roundtrip --profile smoke --seed 0x5eed --target wasm-gc
   ```

3. **`dae-differential`** runs the retained-versus-fresh callsite-path tests, the topology-changing dead-suffix guard, a fresh native release build, and a deterministic 10,000-case direct-DAE GenValid signoff against the current Binaryen `132` baseline:

   ```text
   moon update
   moon test --package jtenner/starshine/passes --file dead_argument_elimination_wbtest.mbt --filter '*retained dropped-result graph*'
   moon test --package jtenner/starshine/passes --file dead_argument_elimination_wbtest.mbt --filter '*complete dead-suffix call removal reports topology change*'
   moon build --target native --release src/cmd
   bun fuzz compare-pass --count 10000 --seed 0x5eed --pass dead-argument-elimination --normalize drop-consts --normalize unreachable-control-debris --determinism --codec-idempotence --out-dir .tmp/ci-dae-genvalid --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin "$BINARYEN_DIR/bin/wasm-opt" --require-binaryen-version 132 --max-failures 1 --no-reduce-mismatches
   ```

For the third command group, set `BINARYEN_DIR` to an extracted official `binaryen-version_132` directory. CI downloads the official x86-64 Linux release archive. The 10,000-case lane is bounded, deterministic, and matches the repository-standard ordinary pass signoff count described below. Existing specialized workflows remain supplemental; their push triggers also name the repository's actual primary branch, `master`. Every workflow that installs MoonBit runs `moon update` before invoking workspace commands, so clean GitHub-hosted checkouts resolve `moonbitlang/x`. The Node workflow checks the package's static clean-checkout export/bin contract and JavaScript syntax because the runtime adapter wasm files are intentionally local-only and ignored; artifact-backed Node runtime testing remains a release/local lane. The examples workflow uses only active pass flags and the Node-24-compatible `actions/cache@v5`.

Both CI compare-pass correctness lanes require fresh-run deterministic output and stable decode/encode bytes.

## Fuzz And Pass-Oracle Boundaries

`bun validate full` runs the ordinary `src/fuzz` suite surface (`suite=all`) through the wrapper documented in [`fuzz-runner.md`](./fuzz-runner.md). That does **not** replace pass-specific Binaryen oracle signoff.

Use pass comparison lanes when a mutating optimizer pass changes. Build the native CLI first, then include both explicit parallelism and the prebuilt binary in the copied command:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass <canonical-pass>|--<pass-flag> --count 10000 --seed 0x5eed --out-dir .tmp/<run-name> --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

For script-level compatibility, `bun scripts/pass-fuzz-compare.ts` is the same underlying implementation and still valid when invoked directly; use the same `--jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` pair there too. The path is a Starshine freshness policy rather than a generic MoonBit output guarantee: after the native build, do not substitute a pre-existing `target/native/...` binary unless its timestamp or hash proves it is the refreshed executable; see the canonical [`pass-fuzz-compare.md`](pass-fuzz-compare.md) workflow and the local policy in [`../../../AGENTS.md`](../../../AGENTS.md).

The pass-comparison harness has its own contract: generated inputs, default persistent caching for deterministic `wasm-smith` inputs and Binaryen oracle outputs/failures, `wasm-tools validate`, Starshine output validation, Binaryen/canonicalization comparison, normalized WAT matching, command-failure classification, optional replay by failure class/case, and parallel lanes requiring a prebuilt `--starshine-bin` next to `--jobs auto`. Its `mismatch`/failure statuses are measurements, not acceptance verdicts: keep pass evidence in the affected dossier and apply the explicit agent taxonomy in [`pass-fuzz-compare.md`](pass-fuzz-compare.md), where an unproven drift remains a parity gap rather than “safe” by validation alone. Optional command-harness binary differential validators (`wasm-tools`, WABT, Binaryen) are a separate opt-in evidence surface; use [`external-validator-adapters.md`](external-validator-adapters.md) for their stage classification, command lines, and skipped-tool semantics. For DAE / generator-debris lanes, use the explicit `--normalize drop-consts --normalize unreachable-control-debris` pair so cleanup-normalized matches stay separate from exact normalized matches.

## Coverage Gate Semantics

[`runValidateCoverage(...)`](../../../scripts/lib/validate-task.ts) wraps `moon coverage analyze` instead of recomputing coverage itself. It parses lines shaped like:

```text
12 uncovered line(s) in src/lib/module.mbt:
Total: 16 uncovered line(s) in 2 file(s)
```

Then it sorts the top uncovered files, prints totals, and optionally compares only the total uncovered lines/files against a simple baseline:

```text
total=10
files=1
```

In CI (`CI=true`), an increased uncovered-line count versus the baseline is fatal. Outside CI, the same command reports the delta without failing unless the underlying Moon command or parser fails.

The [compiler-facts boundary tests](../../../src/binary/compiler_facts_boundary_wbtest.mbt)
check canonical scalar/vector roundtrips and reject every strict truncation of
fixed valid payloads. These deterministic codec checks exercise malformed-input
paths without weakening the uncovered-line baseline.

## Trace Benchmark Gate

`bun validate trace-benchmark` dispatches to:

```text
moon run --target <target> src/validate_trace -- --repeat <n> --corpus <name> ...
```

Use [`validate/trace-benchmark-baseline.md`](../validate/trace-benchmark-baseline.md) for durable corpus-specific `phase_totals`, `helper_totals`, and hotspot baselines; current corpus, test, wrapper, and runtime-tracing evidence is the local source/test set listed below and in [`tracing-playbook.md`](tracing-playbook.md). Do not put raw local wall-time claims into long-lived docs unless the machine/environment and corpus are recorded.

## Self-Optimized Artifact Gate

`bun self-opt check` is the underlying artifact-safety lane. `bun validate self-opt-smoke` keeps the fast default (`--limit 1`) and `bun validate self-opt-full` adds `--full-spec` for the complete checked-in spec corpus. Both lanes operate on an already-built artifact: they do not rebuild debug/release/native targets, and they fail instead of falling back to debug wasm. The upstream [wasm-tools README](https://github.com/bytecodealliance/wasm-tools/blob/main/README.md#L269-L272) shows explicit validation feature toggles such as `--features=exception-handling` and `--features=-simd`, and its proposals section at [L347-L350](https://github.com/bytecodealliance/wasm-tools/blob/main/README.md#L347-L350) says Stage 4+ proposals are enabled by default in validation. Starshine's `--features all` choice is therefore an intentionally stricter repo-local policy rather than an upstream requirement.

The check order is deliberate:

```text
wasm-tools validate --features all <artifact>
Node-hosted WASI Preview 1 run <artifact> --help
Node-hosted WASI Preview 1 run <temporary runner copy> spec <selected tests/spec/**/*.wast>
```

Use `--wasm <path>` to test a candidate artifact outside `tests/node/dist/`; relative paths resolve from the repo root. The spec workload runs against a temporary runner copy so the checked artifact remains available for later validation or size inspection. The runtime lane is Preview 1 Core-module execution through `wasi_snapshot_preview1`; use [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md) for import-module, `_start`/reactor, security, and WASI 0.2/0.3 separation.

`bun self-opt build` rebuilds debug, release, and native targets, then self-optimizes the release Wasm artifact through the normal stacked O4z pipeline. Debug-serial execution is diagnostic opt-in via `--debug-serial-passes`; it is not the production build default. The optimizer subprocess uses compact `phase` tracing by default and is process-group bounded by a ten-minute total deadline plus a 90-second no-progress deadline. Override them with `--optimize-timeout-seconds <n>` / `--optimize-stall-timeout-seconds <n>` or `SELF_OPT_OPTIMIZE_TIMEOUT_SECONDS` / `SELF_OPT_OPTIMIZE_STALL_TIMEOUT_SECONDS`. A timeout terminates the complete process group, writes the effective deadlines and rolling final output to `tests/node/dist/optimize.error.txt`, and leaves no optimizer child running. O4z modules with at least 2,000 defined functions skip `remove-unused-brs`, `precompute-propagate`, `coalesce-locals-cfg`, and second/later `ssa-nomerge` waves; the initial SSA wave and direct named-pass invocation remain available. These are artifact-scale preset admissions, not claims that the passes are globally unsupported. Use `bun self-opt build` only when the artifact itself must be regenerated, and ask before running the full build pipeline or full-spec lane in an ordinary development thread.

`bun self-opt compare-artifact-optimizer` runs native and self-optimized Wasm CLIs through the production stacked O4z pipeline and requires byte-identical output. Its default input is the bounded checked-in `tests/repros/merge-blocks-v131-main.wasm` fixture so the lane measures self-hosted optimizer drift rather than Node's Wasm stack ceiling; override it with `--input <path>` for focused capability work. Larger-input claims need an explicit deadline and separate evidence.

## Formal Proof Is A Separate Lane

Official MoonBit docs describe `moon prove` as a proof command, and Starshine keeps that lane separate from ordinary validation. The required local proof target is [`src/validate_proof`](../../../src/validate_proof/), whose package is imported by [`src/validate`](../../../src/validate/) and governed by [`validation/moonbit-prove-strategy.md`](../validation/moonbit-prove-strategy.md). The official [MoonBit verification documentation](https://docs.moonbitlang.com/en/latest/language/verification.html), the current command manual, and the live proof package files establish the proof-command and trust-surface caveats; this gate page owns only when the repo asks developers to run the proof lane.

Practical rules:

- Run `moon prove src/validate_proof` when proved helper contracts change.
- If the host lacks Why3/solver setup, record the exact tooling limitation; do not convert missing solver infrastructure into semantic evidence.
- Treat file-targeted direct-validator proving as investigative unless a fresh audit graduates it; the current MoonBit docs say file targets assume dependencies.
- Do not silently widen `bun validate full` to include broad `moon prove` runs. Proving can generate much broader package/dependency output and needs its own audit trail.

## Choosing The Right Gate

| Change kind | Minimum useful gate | Stronger gate before commit or handoff |
| --- | --- | --- |
| Docs-only wiki update | Link/source review plus `git diff`; no Moon run required unless code snippets or generated docs changed. | Optional `bun validate readme-api-sync` if README/API references changed. |
| Forward-moving test or expectation update | Diff review and enough local inspection to confirm the expectation moves in the intended direction; no test run required unless the intent is to fix related behavior. | Focused package tests when the changed expectations are meant to prove a behavior fix. |
| Positive behavior change | Focused package tests during TDD when practical. A commit may proceed with known temporary test failures if it is clear forward progress and records the failure state. | `moon info`, `moon fmt`, `moon test`, or `bun validate full --profile ci --target wasm-gc` when repository-wide confidence is needed. |
| Public API or `.mbti` change | `moon info`, review `.mbti` diffs, focused tests when behavior changed. | `bun validate readme-api-sync` plus full gate if the API is user-visible and stable enough for broad validation. |
| Optimizer pass behavior | Focused pass tests and active dispatcher/registry tests when the intent is to fix pass behavior. | `moon info`, `moon fmt`, `moon test`, pass-fuzz compare at the repo-standard count, and artifact replay when the pass participates in presets and the slice is ready for broad signoff. |
| Self-optimized artifact safety | `bun validate self-opt-smoke [--wasm <candidate>]`. | `bun validate self-opt-full [--wasm <candidate>]` after asking, especially for O4z or preset-path changes. |
| Fuzzer generator or invalid-strategy work | Focused validate/fuzz tests and suite smoke when behavior changed. | `bun validate full` or suite-specific fuzz profiles plus updates to [`validate/fuzz-hardening.md`](../validate/fuzz-hardening.md), [`validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md), and [`fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md). |
| Validator proof helpers | Focused executable tests and `moon prove src/validate_proof` when proved contracts change. | Ordinary test/full validation as needed for call-site behavior. |
| Trace/performance work | `bun validate trace-benchmark --list-corpora` and focused corpus runs when updating measured behavior. | Update [`validate/trace-benchmark-baseline.md`](../validate/trace-benchmark-baseline.md) when the durable baseline changes. |

## Edge Cases And Invariants

- **Serialize Moon commands.** The repo rules call out `_build/.moon-lock`; do not run multiple Moon commands in parallel.
- **Use `MOON_BIN` or `--moon` for alternate toolchains.** [`resolveMoonBin()`](../../../scripts/lib/task-runtime.ts) reads `MOON_BIN`, while wrapper parsers accept explicit `--moon` in the command families that need it.
- **Keep `.tmp/` artifacts out of committed docs.** Store durable conclusions in `docs/wiki/` or numbered research notes; leave raw run directories local unless intentionally archived.
- **Separate deterministic tests from randomized exploration.** `moon test` should stay fast and reproducible; broad randomization belongs in `src/fuzz` or pass comparison tasks.
- **Do not cite external MoonBit docs for Starshine-specific defaults.** Cite the raw MoonBit command-source manifests for upstream command provenance, and cite Starshine scripts/tests for local behavior.

## Sources

- Official MoonBit [module configuration](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html), [package configuration](https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html), [formal verification](https://docs.moonbitlang.com/en/latest/language/verification.html), and [command manual](https://moonbitlang.github.io/moon/commands.html)
- Official wasm-tools README: [validation examples](https://github.com/bytecodealliance/wasm-tools/blob/main/README.md#examples) and [proposal feature defaults](https://github.com/bytecodealliance/wasm-tools/blob/main/README.md#webassembly-proposals)
- Repo validation rules: [`../../../AGENTS.md`](../../../AGENTS.md), [`../../README.md`](../../README.md)
- Local validation orchestration: [`../../../scripts/validate.ts`](../../../scripts/validate.ts), [`../../../scripts/lib/validate-task.ts`](../../../scripts/lib/validate-task.ts), [`../../../scripts/lib/task-runtime.ts`](../../../scripts/lib/task-runtime.ts)
- Self-optimized artifact lane: [`../../../scripts/self-opt.ts`](../../../scripts/self-opt.ts), [`../../../scripts/lib/self-opt-task.ts`](../../../scripts/lib/self-opt-task.ts), [`../../../scripts/lib/self-optimized-artifacts.mjs`](../../../scripts/lib/self-optimized-artifacts.mjs), [`../../../scripts/lib/run-self-optimized-spec-suite.mjs`](../../../scripts/lib/run-self-optimized-spec-suite.mjs), [`../../../scripts/lib/moonbit-wasi-runner.mjs`](../../../scripts/lib/moonbit-wasi-runner.mjs)
- Command-shape tests: [`../../../scripts/test/task-family-commands.ts`](../../../scripts/test/task-family-commands.ts)
- Package and workspace metadata: [`../../../package.json`](../../../package.json), [`../../../moon.mod`](../../../moon.mod), [`./moonbit-workspace-package-map.md`](moonbit-workspace-package-map.md)
- Related workflow pages: [`./cli-command-and-dispatcher.md`](./cli-command-and-dispatcher.md), [`./release-process.md`](release-process.md), [`./fuzz-runner.md`](./fuzz-runner.md), [`./pass-fuzz-compare.md`](./pass-fuzz-compare.md), [`./tracing-playbook.md`](./tracing-playbook.md), [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md), [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md), [`../validation/moonbit-prove-strategy.md`](../validation/moonbit-prove-strategy.md), [`../validate/trace-benchmark-baseline.md`](../validate/trace-benchmark-baseline.md)


## October 3, 2026: reproduced baseline correctness blockers

A separate local review of commit 3d46f7e52 (`claude_review_10_3_6.md`, maintained
by its author and not included here) reports 26 issues. It is not an independent
review of the in-flight performance patches. Focused replay confirms the
following on both native 43feef6e and iterator candidate 8bfe3761, with identical
before/after bytes. These are **release blockers**, despite 13,403 passing default
tests and the passing bounded performance-fixture runtime matrix.

- **Validation failure:** merge-blocks produces a module rejected by wasm-tools;
  Starshine exits 0 and its explicit `--validate` also accepts it. The original
  and Binaryen 133 output validate. The validator itself accepts all three tiny
  malformed modules below; wasm-tools and Node 26 reject all three. Binaryen 133
  rejects the latter two but repairs the first while reading/writing it, so its
  CLI acceptance alone is not a strict-input validation oracle.

```wat
(module (func (result i32) block unreachable end))
(module (func block (result i32) unreachable end))
(module (func (result f32) block (result i32) unreachable end))
```

- **True semantic mismatch, DAE:** original/Binaryen 133 return 1, both Starshine
  snapshots return 0. A branch-value parameter read is lost before a later write.

```wat
(module
 (global $g (mut i32) (i32.const 1))
 (func (export "f") (result i32) (call $callee (global.get $g)))
 (func $callee (param i32) (result i32)
  (block $C (result i32) (br $C (local.get 0)))
  (local.set 0 (i32.const 5))))
```

- **True semantic mismatch, OptimizeInstructions:** original/Binaryen 133 call
  `log` in order[1,2]; both Starshine snapshots call[2,1], although all return 5.

```wat
(module
 (import "env" "log" (func $log (param i32)))
 (func $se (param i32) (result i32) (call $log (local.get 0)) (i32.const 0))
 (func (export "f") (result i32) (local i32)
  i32.const 1 call $se i32.const 0 i32.and
  i32.const 5 i32.const 0 i32.const 2 call $se i32.const 0 select
  local.set 0 i32.add))
```

[Frame typing](../../../src/validate/typecheck.mbt),
[DAE branch-value analysis](../../../src/passes/dead_argument_elimination.mbt),
[OI rewriting](../../../src/passes/optimize_instructions.mbt) and shared lift/lower
ordering require focused red regressions and oracle-backed repairs. Do not
infer semantic safety from Starshine validation alone or reclassify these as
representation wins. Remaining reported DAE2/cleanup/exception/scanner/CLI
families require independent triage; their report is evidence to investigate,
not a claim that this session replayed all 26. Keep coverage/verification gates
unchanged. Performance work does not close these blockers.

Exact frozen commands, input/output hashes, diagnostics and Node observations:
`.tmp/large-pass-hotspots-20261001/review-reductions/result.json` and
`frame-results.json`; generator/replay is `replay-review-reductions.py`.


### DAE reduced cases repaired; other blockers remain

The [operand-control liveness repair](../binaryen/passes/dead-argument-elimination/starshine-strategy.md#october-3-2026-parameter-reads-in-control-operands)
supersedes the DAE failure status above for audit #5–6. Both were independently
reproduced, including the constant self-tee case and an additional GC payload
trap. Three focused tests fail before the fix, then all four pass; 16 reduced
DAE/O runtime rows now agree with original and verified v133 (previously 10
mismatched), with 13,419 default tests passing. Six large outputs retain their
hashes and measured DAE/O command cost is essentially unchanged.
This does not close validator, merge-blocks, OI effect ordering or other reported
families, nor substitute for deferred full validation/coverage/fuzz signoff.


## October 4, 2026: focused frame, ordering and typed-entry repairs

Review base: pushed `ce2051ba7fb3ce929d26728feeec274271c749d1`. The existing
checkout includes preserved author-owned pending changes; these repairs are
additional independent units, not evidence that the clean pushed commit passed
new tests. The audit and historical benchmark records remain intact. Local
commands, red/green logs, raw bytes and source/binary seals are retained under
`.tmp/p00-focused-20261004/`.

- **Frame validation, reproduced and repaired:** the three exact invalid modules
  above and the concrete `i32`/`i64` untyped-select mismatch were accepted by the
  frozen current binary, not merely inferred from review. `TcState.polymorphic`
  now governs virtual operands independently of execution-flow `reachable` and
  `escape`. Block, loop, if and exception frames start with concrete declared
  inputs and always check their exit stack; closing a dead child restores the
  parent's concrete prefix and declared child results. Conditional reference
  branches and select still check concrete types in polymorphic frames.
  [Validator regressions](../../../src/validate/frame_polymorphism_wbtest.mbt)
  and [command replays](../../../src/cmd/p00_validator_wbtest.mbt) cover entry,
  exit, valid controls, select and the saved invalid MergeBlocks output.
- **OI effect order, reproduced and repaired:** zero-bits facts retain effects
  through a dropped-children replacement block. The replacement's fresh order
  was 14 while the original expression's order was 3; lowering's carried-value
  query examined the block header/inputs and missed the earlier call in its body
  region. The local replacement helper copies the original order before calling
  `hot_replace_node(..., preserve_value_order=true)`. The global mutation default
  is unchanged. [Direct regression](../../../src/passes/optimize_instructions.mbt)
  and [command regression](../../../src/cmd/p00_oi_order_wbtest.mbt) retain the
  zero-result fold and original evaluation position.
- **DAE2/O virtual typed inputs, reproduced and repaired:** a polymorphic parent
  may supply zero or one concrete producer for two declared inputs. The lifter
  typechecks the complete instruction before eliding its unreachable computation;
  it neither manufactures constants nor suppresses concrete/nested-body errors.
  Elided bodies reserve source-local access slots in source order, using `-1`
  for absent HOT nodes. Both modes have [command controls](../../../src/cmd/p00_dae2_polymorphic_wbtest.mbt)
  and [source-access controls](../../../src/ir/hot_virtual_entry_access_wbtest.mbt).
- **Forced-HOT DAE2/O retained-call order, reproduced; verification pending:**
  the permanent native runtime lane found `[23,19]` instead of `[19,23]` on
  the discarded typed-block fixture. The equivalent retained-prefix wrapper
  received order 12 while the original call remained at order 3. The repair
  explicitly copies the original call position to the separate replacement
  node; it does not change global replacement defaults. Both modes have a
  [failing-before-fix regression](../../../src/passes/dae2_effect_order_wbtest.mbt).
  The carried-import/intervening-write case passed before the repair and remains
  a control. Normal-route runtime results alone did not establish HOT-fallback
  correctness; renewed raw-byte/event/trap evidence is still required.
- **Reachable typed boundaries:** replay confirmed a single-parameter live
  `br_if` entry was emitted inside its label rather than before the block. Its
  typed emitter now emits the input outside and manages the block's own label.
  A captured mixed tuple also required keeping pending outer values distinct
  from entry lanes. [Lift/lower controls](../../../src/ir/hot_lift_typed_block_entry_wbtest.mbt)
  cover both capture modes, shared mixed tuple suffixes, discarded results and
  labels. [Verifier controls](../../../src/ir/hot_typed_prefix_verify_wbtest.mbt)
  cover mixed void/value prefixes, lane arity/types and indexed subtyping, without
  removing the supported implicit single-parameter representation.
- **MergeBlocks, first invalid stage traced:** the reduced original already
  became invalid in a direct HOT lift/lower round trip, before MergeBlocks.
  Baseline raw stages were 80 B before the pass, 70 B after direct rewriting,
  and 66 B after pipeline cleanup. The lowerer incorrectly treated a closed
  nonfallthrough child as a polymorphic parent and omitted its required result
  drop. The repair accounts for closed child results; no unproved change was
  made to `merge_blocks_flatten_region_root_block`. A separate terminal-control
  proof restores outer polymorphism only when the closed control cannot exit
  normally through its own label. [Lowering controls](../../../src/ir/hot_nested_dead_drop_wbtest.mbt)
  and the direct MergeBlocks stage test require raw valid output. The old invalid
  66 B output remains an independent rejection fixture.

The permanent [native runtime lane](../../../scripts/test/p00-correctness-runtime.ts)
checks raw bytes before any normalization, direct HOT/direct pass output, forced
HOT DAE2 fallback, normal results, import order/counts and first-import traps.
Its fixture producer is an explicitly skipped native test, not part of the
bounded default suite. Native compiler/debug-tool limitations and any failing
repository tests must be reported separately from Starshine output validation.

**Signoff remains open.** These focused repairs do not close all audit families,
repository-wide CI/coverage, renewed 10,000-case aggregates, output-size gaps or
any of the four 1× goals. Traced command, complete pass/pipeline and narrow helper
measurements are separate scopes. The lowerer's existing quadratic prefix-
producer scan remains an unmeasured performance risk; command-time attribution
requires an actual scoped measurement.

## October 5, 2026: resolved default-suite baseline

The merged `master` development baseline initially ran 13,606 bounded default
tests with 30 failures. The renewed run after red-first repairs passes
**13,606/13,606** with zero failures; `moon fmt` and `moon info` pass and public
`.mbti` files are unchanged. Independent WABT checks identified eighteen
malformed WAT or hand-built fixtures; two tests had stale type/shape
expectations. The remaining ten cases needed pass repairs in SSA no-merge,
SimplifyLocalsNoStructure, and OptimizeInstructions. The focused tests assert
valid transformed modules, specific IR/operand shapes, and preservation of the
descriptor-operand null-check boundary. See the implementing files and
[campaign log](../log.md#2026-10-05--resolve-the-30-saved-default-suite-failures).

This renews the default-suite gate only. The independent P00 semantic and
validation repros, full CI/coverage, performance targets, and broader pass
parity remain open. The following checkpoint keeps its original 30-failure
result as historical evidence.

The post-repair native CLI and GenValid binaries (hashes in the
[campaign log](../log.md#2026-10-05--resolve-the-30-saved-default-suite-failures))
also completed 10,000 cases apiece for `ssa-nomerge-all`,
`simplify-locals-nostructure-all`, and `pass-oi-all` against verified Binaryen
133. Every lane has zero validation, generator, property and command failures.
SSA's 6,250 allocation/shape residuals, SLNS's 1,662 size-losing tee-control
cases, and OI's 1,377 measured smaller-output residuals retain their separate
classifications; the pass comparison does not close those parity gaps.

## October 5, 2026: saved development checkpoint

The last [full-command timing report](../raw/tooling/2026-10-04-starshine-v133-review.json)
uses a combined dirty worktree, not clean pushed `ce2051ba7`. Starting/measured
binary SHA-256: `5bf4a1f5603e0c436b5ce76012493e5fd6e712848dbce09056de1827e6f0a704`.
Verified Binaryen 133 SHA-256:
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
Input: 6,211,596 bytes, SHA-256
`98189860f95b4eb8464794eb9fab5f9fd8d16942c63a6e31ed9175e7e791cbbd`.
CPU 6, one warmup, five rounds, median ± MAD in milliseconds:

| Pass | Starshine command | Binaryen 133 command | Time ratio |
|---|---:|---:|---:|
| DAE2 | 3065.635 ± 17.308 | 1102.708 ± 5.730 | 2.780× |
| DAE2-O | 5266.677 ± 19.132 | 2275.127 ± 2.911 | 2.315× |
| CoalesceLocals | 3389.078 ± 35.738 | 1784.710 ± 21.249 | 1.899× |
| OptimizeInstructions | 1745.988 ± 6.061 | 901.906 ± 2.459 | 1.936× |

Contention was present, especially four of five CL rounds on both sides. The
roughly 2–3× command times are accepted as the current development checkpoint;
all four 1× goals remain open. They are not new timings of the correctness repairs.
A separate historical traced sample recorded command / pipeline / inner ms:
DAE2 3229.001 / 2605.888 / 2590.802; DAE2-O 5385.987 / 4640.674 / 4625.685;
CL 3338.833 / 2569.864 / 2554.882; OI 1839.924 / 1310.614 / 79.310. OI's narrow
inner timer excludes most pipeline work. Never combine these distinct samples
or use the inner timer as complete-pass parity evidence.

The [focused correctness checkpoint](../raw/tooling/2026-10-05-starshine-p00-checkpoint.json)
retains raw replay commands, binary/source fingerprints, validation statuses,
the failing forced-HOT runtime trace and the last completed affected-suite
failures. The v3 release CLI hash is
`4bcd060c535fe830248e3743cd1c5166645e3586fbf87065a6c781a94338312d`;
its production-source fingerprint is
`17ac12e6461fd34d2821c528cd9c463ebf2e8813af8cd09b823c5307d94a905a`.
It rejects the three exact invalid frame fixtures, the concrete select mismatch
and saved invalid MergeBlocks bytes (exit 1); matching wasm-tools checks also
exit 1. Valid polymorphic typed-block controls validate in both DAE2 modes.
Command OI returns 5, events `[1,2]`, one import execution each; first-import
trapping records `[1]`. Normal-route typed-boundary observations passed, while
forced-HOT DAE2 reproduced `[23,19]` instead of `[19,23]`. The retained-prefix
position repair is newer than v3 and still needs green direct tests and complete
native event/trap verification.

The last completed v3 affected suite ran 12,169 tests: 12,139 passed, 30 failed,
all in legacy pass tests. Preserve those failures as evidence; the current
source and later integrated audit fixes have not renewed the full gate. Exact
follow-up command: `moon test -p jtenner/starshine/passes --target wasm-gc --file
dae2_effect_order_wbtest.mbt -j 1`. Thermal-gated attempts used CPU 6, low priority,
20% duty and pauses above 84°C. Both initial and cached-link attempts ended at
thermal deadlines before tests ran, with controller exit `-15`, rather than a
failed test assertion. Host readings reached 100°C; no new benchmark was run.

Canonical size gaps remain DAE2-O +99,251 B, CL +78,800 B and OI +33,494 B.
Full CI, coverage, renewed aggregates, quiet-host/clean-source balanced final
comparison and complete correctness/runtime evidence remain release blockers.
This checkpoint saves forward progress without claiming campaign completion.

## October 5 2026 integrated validator renewal

The Dewdrop-integrated `master` production tree at `1d4043c20` passes the
complete bounded wasm-gc suite: **13,745/13,745**, zero failures. The native
release aggregate over `tests/spec` also passes after branch payload, bottom
reference, descriptor cast, branch-table and core tag-policy repairs. No new
fixture skips, mismatch allowances or disabled passing tests were introduced.
The 28 new validator/feature regressions, 544 affected metadata/flatten/RUME/
command tests and 79 negative typecheck/branch-table tests pass separately.

Commands and local raw logs:

- `moon test --target wasm-gc -p jtenner/starshine`:
  `.tmp/spec-repair-full-green.log`, 148.056 seconds including build/test work.
- Native release `src/wast/spec_harness.mbt`, filtered to the complete fixture
  aggregate: `.tmp/spec-repair-harness-final.log`, 49.232 seconds.
- `.tmp/spec-repair-focused-final.log`, `.tmp/spec-repair-final-affected.log`
  and `.tmp/spec-repair-negative-diagnostic.log` retain focused evidence.

These are test-gate observations, not quiet-host performance comparisons.
Both aggregate activities exceed Dewdrop's 30-second compiler activity budget;
their build/run costs remain an operational risk. The older saved failing
checkpoints remain historical evidence, not the current bounded-suite status.
This renewal does not close the independent forced-HOT runtime-order,
coverage, aggregate parity, artifact-size or release-performance blockers.

The maintained contracts are [stack typing](../validate/stack-polymorphism-and-bottom.md),
[descriptor branches](../wast/reference-instruction-authoring.md),
[tag feature policy](../wast/exception-tag-authoring.md) and
[structured versus opaque metadata](../wast/code-metadata-and-function-annotations.md).
