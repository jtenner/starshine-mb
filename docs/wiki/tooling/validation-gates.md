---
kind: workflow
status: supported
last_reviewed: 2026-10-09
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
  - ../../../src/ir/hot_prefix_results_wbtest.mbt
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

The pass-comparison harness has its own contract: freshly generated inputs and Binaryen oracle outputs without persistent fuzz caching, `wasm-tools validate`, Starshine output validation, Binaryen/canonicalization comparison, normalized WAT matching, command-failure classification, optional replay by failure class/case, and parallel lanes requiring a prebuilt `--starshine-bin` next to `--jobs auto`. Its `mismatch`/failure statuses are measurements, not acceptance verdicts: keep pass evidence in the affected dossier and apply the explicit agent taxonomy in [`pass-fuzz-compare.md`](pass-fuzz-compare.md), where an unproven drift remains a parity gap rather than “safe” by validation alone. Optional command-harness binary differential validators (`wasm-tools`, WABT, Binaryen) are a separate opt-in evidence surface; use [`external-validator-adapters.md`](external-validator-adapters.md) for their stage classification, command lines, and skipped-tool semantics. For DAE / generator-debris lanes, use the explicit `--normalize drop-consts --normalize unreachable-control-debris` pair so cleanup-normalized matches stay separate from exact normalized matches.

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

## October 7, 2026 — P00 control, exception and ownership repairs

This checkpoint supersedes the October 4–5 pending notes only for the cases
listed here. The original audit remains unchanged in
[`claude_review_10_3_6.md`](../../../claude_review_10_3_6.md). Whole-pass parity,
large output-quality gaps and the four 1× performance targets remain open.

- Virtual stack inputs now cover Block, Loop, If, Try and TryTable after
  unreachable code. Lift checks the original body, records nested local-access
  placeholders and emits no fabricated producers. Both DAE2 modes have
  [dispatcher tests](../../../src/cmd/p00_dae2_polymorphic_wbtest.mbt) and
  [source-map tests](../../../src/ir/hot_virtual_entry_access_wbtest.mbt).
- [CodeFolding](../../../src/passes/code_folding_test.mbt) retains a typed
  holder's final unreachable marker after a void control. OI's boolean proof
  rejects targeted control exits, using one lazy label inventory rather than
  repeating a whole-function scan for each proof.
- MergeLocals and full SSA use operand-expanded, full-flow reaching sources.
  Caught Call, CallIndirect and CallRef arguments precede the exceptional edge;
  their result consumers follow the normal edge. CoalesceLocals includes
  exceptional liveness. [CFG tests](../../../src/ir/cfg_caught_calls_wbtest.mbt),
  [pass tests](../../../src/passes/p00_exception_flow_wbtest.mbt) and
  [command tests](../../../src/cmd/p00_exception_flow_wbtest.mbt) cover the
  pre-entry write, protected-body write and catch continuation.
- Local SSA visits expanded nodes once. SSA-nomerge builds all of its overlays
  from one pass-local expanded CFG and leaves the revision-only shared cache
  unchanged. Exception, typed-loop and unsupported copy-insertion boundaries
  remain. [Ownership tests](../../../src/ir/ssa_local_test.mbt) check exact
  definitions and uses. The raw scratch repair keeps escaping nested body-local
  and parameter writes canonical. Root overwrites kill pending escapes;
  If arms share a boundary. Separate instruction flags retain incoming
  parameter freshening and earlier writes with a dominating canonical overwrite.
  Calls and control exits split that proof. Two region walks and primitive
  pending-candidate chains use linear work and O(locals + regions + instructions)
  scratch, without per-write objects or a local-by-region matrix. Scan scratch
  is released before rewriting. Legacy-touched locals remain canonical, and
  protected/catch bodies enter the loop read/write scans. The fixed input-local
  limit includes scratch locals added by preceding stages. Rewriting does not
  expand that limit. Seen-write rows retain the original declaration limit;
  aliases grow only when needed, so unused extra lanes do not enlarge each arm
  copy. Loop reads update one first-access row directly, without
  a per-instruction bitset or full-local scan; each loop scan is O(subtree +
  input locals). Branch write masks are collected once per arm. The whole
  legacy freshener still has nested-scan and later-read costs.
  [Raw tests](../../../src/passes/p00_scratch_escapes_wbtest.mbt) cover both write
  forms, declared and appended locals, parameters, If continuations and exits,
  legacy catches, loop carriers and independent freshening.
  A single operand inventory also retains phi sources written inside a
  predecessor's branch operand. Those writes run after predecessor copies;
  independent writes still receive fresh locals. The
  [direct fixture](../../../src/passes/p00_ssa_branch_operand_wbtest.mbt)
  checks the local fields and supplies native before/after runtime bytes.
- A carried local tee before an escaping operand stays before that operand.
  [Source-order tests](../../../src/ir/hot_source_order_escape_wbtest.mbt) and
  [Flatten tests](../../../src/passes/flatten_test.mbt) check the capture order.
  Precompute delays transparent-block inlining to a phase with one lazy use
  snapshot, so a shared value holder is not cleared from another user.
  Detached holders are checked and deleted once at the end of that phase.
  All transparent children of one parent are handled in the same visit.
  Scalar identity prefixes retain their producer once; other explicit prefixes
  require an effect-retention proof. The raw route removes empty typed scalar
  identity blocks without HOT lift or a new nop. Direct
  [cleanup tests](../../../src/passes/p00_precompute_cleanup_wbtest.mbt) and
  [dispatcher tests](../../../src/cmd/p00_precompute_cleanup_wbtest.mbt)
  cover input retention and effect order.
  Root identity cleanup is enabled for Precompute only; other users of the
  shared cleanup retain their established parameter-block policy.
- DCE counts every try_table catch target in the enclosing label space. Legacy
  Try bodies and catches participate in SSA-nomerge's written-local and default
  scans. Tests use opcode and local-field assertions, plus codec validation.
- Legacy rethrow now distinguishes wasm all-label depth from HOT catch ordinal.
  A catch-only persistent scope records catch prefix lengths; ordinary labels
  share that scope. UInt bounds are checked before conversion. HOT emission
  maps a retained catch LabelId to its current depth; DAE2 borrows one inline
  catch-frame stack without copying ancestors. Raw lower remaps enter legacy
  bodies and catches. Vacuum folds a constant If to a same-type Block when its
  label must remain. [Validator](../../../src/validate/p00_rethrow_wbtest.mbt),
  [text](../../../src/wast/p00_rethrow_wbtest.mbt),
  [lower](../../../src/ir/p00_rethrow_depth_wbtest.mbt) and
  [dispatcher tests](../../../src/cmd/p00_rethrow_wbtest.mbt) are the new controls.
  Catch rethrow discovery includes ordinary operands and explicit entry
  prefixes, using primitive worklist and hash rows. It allocates no linked-set
  entry object per node. A shared node is visited once per catch depth, with
  expected linear work in the reached graph. The
  [operand tests](../../../src/ir/p00_rethrow_operand_wbtest.mbt)
  prevent a hidden rethrow from losing its exception capture.
- Invalid i32/i64/f32/f64 constants produce parse errors instead of zero. The
  CLI fallback returns exit 1 without output. Native text input tries wasm-tools
  before WABT; installed WABT 1.0.42 emits invalid typed-reference bytes in the
  retained small case. No second whole-module decode was added.
  Scalar float text preserves signed zero, infinities and signed NaN payload
  bits. The [roundtrip tests](../../../src/wat/scalar_float_roundtrip_wbtest.mbt)
  cover values which the old parser silently converted to zero.

The shared prefix emitter consumes consecutive producer runs and borrows result
rows. It no longer scans all earlier producers per input lane or copies each
shared tuple row. The dedicated 2,048-lane native control measured
591.002 ± 22.789 µs before and 36.157 ± 2.058 µs after (median ± MAD), about
16.35× faster. This is a helper result, not a whole-command gain. Wide CFG
edge-symmetry checks use primitive indexed rows with O(blocks + edges) work;
degree ≤8 keeps the existing allocation-free scan. In mixed graphs, only pairs
with more than eight source successors or destination predecessors enter the
index; other counterpart scans remain bounded by eight. Scratch storage is
8 bytes per block plus 12 bytes per indexed successor. Source masks are cleared
after all kinds at one destination have been checked. The new
[catch-hub benchmarks](../../../src/ir/cfg_catch_edges_perf_wbtest.mbt) stay
skipped in the default suite.

The final direct-lower runtime lane found a separate semantic failure: an
uncaptured tuple suffix followed by a scalar repeated its imported producer.
The original and v133 emitted event `[31]`; direct HOT emitted `[31,31]`,
although the values and validation agreed. The retained failure bundle is
`.tmp/p00-runtime-4oJy8o`. Entry forwarding now matches one root to one input
lane, including partial tuple runs. It does not add captures or scratch locals.
The [pair/triple regression](../../../src/ir/hot_prefix_results_wbtest.mbt)
failed with two calls before the change and passes with one afterward in both
capture modes. The fresh native lane also passes pair and triple values, one
import event and first-import traps in both capture modes.

A frozen native checkpoint `2d3e5e3c…` agrees with original execution and verified
Binaryen 133 in 12 bounded fixtures and 211 observations, including normal and
first-import traps. It predates the rethrow and adapter changes. Canonical size
is recorded, not inferred from raw size: full SSA's caught-call fixture remains
2 bytes larger than the oracle and is an open parity gap. The renewed default
wasm-gc gate passes 13,787/13,787 tests, including the existing 498 SSA-nomerge
checks and new repeated-write, parameter If and legacy-catch regressions.
`moon info`, `moon fmt` and README/API sync pass. The earlier partial counts
remain historical evidence.

Fresh native `f8c5b53a…` passes the bounded lanes: 24 fixtures / 476 observations
(110 diagnostic observations use the earlier binary), seven rethrow fixtures /
90 observations and 27 forced-HOT/runtime fixture names / 188 observations.
Original/current/v133 execution agrees in the compared result, import-event,
trap and exception controls. The direct SSA branch operand returns 3/1;
appended block/loop scratch fixtures return 7/8. Both forced DAE2 modes now
retain `[19,23]`, and both tuple capture modes emit one import call. Rethrow
retains the host exception object, tag and payload 77. Six native adapter/error
checks pass. Every final runtime module passes the external validator; the
direct producer also encodes, decodes and validates its output without text
repair. v133's compact-import encoding is valid but unsupported by the current
Node embedding, so legacy-EH execution uses `--disable-compact-imports` for
both oracle input and output. The initial embedding failure is retained.

Canonical output gaps remain explicit: full SSA caught-call +2 bytes, SGO
empty-then +7, four SSA-nomerge parameter-If controls +8 each and rethrow-zero
Vacuum/DAE2-O +14 each. Matching bounded execution does not close those parity
gaps. Empty typed scalar identity removal saves six canonical bytes per
fixture against v133: the identical parameter/result type and empty body prove
that this removes no value, effect or branch target. This is an intentional
cleanup win, with direct and dispatcher assertions.

The current full-command cohort uses CPU 6, one warmup and three measured
samples per binary, with alternating order. All outputs validate externally;
all repeated outputs are deterministic. Median ± MAD milliseconds are:

| Pass | Before | Current | Verified v133 | Current time change | Peak RSS change, KiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| DAE2 | 3272.887 ± 26.291 | 3300.631 ± 8.166 | 1186.307 ± 11.899 | +0.848% | +1244 |
| DAE2-O | 5684.618 ± 88.168 | 5752.942 ± 11.106 | 2371.548 ± 8.638 | +1.202% | +260 |
| CoalesceLocals | 3555.081 ± 2.221 | 3627.545 ± 31.688 | 1890.221 ± 1.779 | +2.038% | +3872 |
| OptimizeInstructions | 1867.202 ± 11.510 | 1880.409 ± 6.051 | 941.604 ± 1.708 | +0.707% | +464 |
| Precompute-propagate | 1555.972 ± 9.046 | 1545.570 ± 5.136 | 1485.549 ± 7.246 | −0.669% | +4016 |
| SSA-nomerge | 3093.414 ± 5.494 | 3094.855 ± 35.548 | 1430.598 ± 20.794 | +0.047% | +4620 |

Background applications were active; this is not a quiet-host or general clock
win. The earlier `350a1739…` cohort has time changes from −3.465% to +0.375%;
both cohorts are retained. Every one of the four 1× goals remains open. Five
pass outputs are byte-identical to the before binary. SSA-nomerge adds nine raw
and six canonical bytes. Static inspection shows the two growing canonical
bodies, 8672 and 8791, now match v133 exactly; body 9356 also matches v133.
Body 12193 restores a loaded value to the local read at exit, where the before
binary wrote a fresh slot and read the zero default from the old slot. This is
an agent-classified parity repair, with encoded-byte and local-field evidence.
No full-function runtime or reachability replay was done on these large bodies.
Body 12193's remaining oracle shape difference stays an open parity gap.

The initial `350a1739…` n3 cohort raises Precompute-propagate peak RSS by
9,680 KiB (6.179%) with disjoint ranges and fails the chosen 5% follow-up budget.
The input has no EH controls, so caught-call splits cannot cause that rise.
The smaller CFG index removes an epoch row and excludes bounded pairs. The
fresh n3 budget passes at +4,016 KiB (2.474%), but the baseline median also rises
from 156,672 to 162,348 KiB. Current medians are nearly unchanged, 166,352 and
166,364 KiB. This does not prove a process-RSS improvement from the index.
A separate n5 repeat compares before / pre-index / current medians of
166,144 / 167,416 / 169,232 KiB, with ranges
159,460–171,152 / 165,384–172,416 / 166,280–172,372 KiB. Before/current time is
1544.637 ± 10.213 / 1522.527 ± 10.720 ms; pre-index is 1523.278 ± 5.842 ms.
All three outputs are identical and validate. The current repeat has +1.859%
median RSS versus before and +1.085% versus pre-index. Keep the earlier adverse
cohort and RSS attribution open; process RSS does not measure allocation bytes.
Native code already releases the Precompute count snapshot before forest
deletion. Smaller scratch storage is established by the algorithm, not by an
unproved peak-RSS cause.

Renewed helper controls use two alternating rounds with ten framework samples.
At width 1024, Precompute cleanup's second-round median ± MAD is
41597.950 ± 184.201 → 1255.443 ± 8.789 µs, about 33.1× faster. The first before
round is severely dispersed, 97987.039 ± 85101.404 µs, and remains in the record.
Width 128 is 824.760 → 160.486 and 827.114 → 170.326 µs. Width 1 is
5.056 → 4.982 and 5.031 → 5.445 µs; the second round is adverse by 0.414 µs.
The before helper uses the historical full driver and the current helper uses
an isolated driver, with the same release optimization flags. These small
controls do not prove an enclosing-command gain. The 1024-edge catch hub is
231.168 → 20.069 and 243.014 → 19.640 µs, about 11.5–12.4× faster. Four-edge
controls retain the allocation-free route, 0.047 → 0.054–0.055 µs. The sparse
index is slower than the earlier larger index's roughly 17.3–17.5 µs wide-hub
control; that memory/time tradeoff is explicit and remains far below the
quadratic reference.

Machine-readable evidence (local-only record)
records source and executable hashes, command rows and spreads, helper build
metadata, static SSA fragments, runtime counts, canonical size deltas and
retained failures. Unused build, download and npm caches were removed;
finalized large manifests were compressed with their hashes retained. Failure
bundles, semantic differences and pending resume inputs remain. Completed
isolated native C/core/driver intermediates were also removed; executables and
build metadata remain. The old disk-full build abort is not test evidence.
Both original effect-order and tuple-duplication failures remain as historical
evidence.
Long aggregates and broad fuzz remain deferred under the active campaign's
scheduling instruction. Missing audit #11/#26 artifacts, EH local-overlay
mutation and canonical shape gaps remain open.

## October 7, 2026 — Eight-agent speed, memory, correctness and parity audit

This is the pre-repair audit record. The [October 8 repair checkpoint](#october-8-2026--mass-audit-repairs-and-green-default-suites) supersedes its active gate status; its original counts, reports and oracle outcomes remain historical evidence.

The user requested eight separate audits before parent compilation. One agent
owned DAE2 and DAE2-O together. All eight agents finished before the parent ran
Moon. Agents wrote only new tests and reports. They ran no Moon commands,
benchmarks or aggregate fuzz campaigns. Direct replays used existing executables
and a verified Binaryen 133 oracle. The frozen native CLI is `f8c5b53a…`; the
oracle SHA-256 is `8f25e9fd…`. Historical earlier-binary rows retain their own
identity. All 293 production/interface hashes remain unchanged during the audit.

| Audit owner | New Moon tests | Failed | Main findings |
| --- | ---: | ---: | --- |
| DAE2 and DAE2-O | 2 | 2 | Imported callback target signatures; useful pruning with distinct runtime type identities; type-conflict cascades and sibling cleanup costs |
| Shared IR | 6 | 6 | Repeated tuple evaluation missing from CFG flow; caller-owned intern rows; cache owner identity; cycle and label-scope checks; repeated tuple captures |
| Validator and types | 20 | 20 | Explicit subtype contents, parent/finality/shared domains, limits, reference hierarchy/bottom rules and proposal conflicts |
| Local passes | 8 | 8 | Typed entry writes and captured-value order in RSE/SL/CSE; source identity collision; 17-instruction CSE coverage |
| Precompute, OI, SGO | 9 | 7 | Live scratch write removed; fractional truncation and legacy control folding gaps; unrelated legacy control blocks SGO |
| Original DAE, inlining, module remaps | 13 | 13 | Legacy parameter reads/writes; lost table-initializer type; module-wide legacy guards; inlining ceiling overflow |
| Binary codec and WAST | 14 | 14 | Unicode/name bytes, malformed spans/limits/flags/counts, unknown name subsections, trailing text and type-use checks |
| Remaining passes and pipeline | 2 | 2 | Shared allocation deletion in Heap2Local; HSO self-target wrapper rejection; further pipeline/resource leads |

The parent also saved six Bun harness regressions under
[`scripts/lib/mass-audit-regressions/`](../../../scripts/lib/mass-audit-regressions/).
All six fail: computed-divisor trap normalization, nested runtime signatures,
a missed scalar-return difference, SMT shift masking, and two legacy runtime
deadline probes. The deadline tests kill their isolated child after four seconds
and clean temporary files; no nonterminating child remains. The runtime-signature
failure applies to the fallback path without an explicit Starshine interface
report. The main node-v2 compare path with `starshineBin` avoids that parser.

The first full Moon attempt failed to compile the new tests; it is not behavior
evidence. The parent corrected four test-only API/helper issues. The next full
`moon test --target wasm-gc` compiled and completed: **13,861 tests, 13,789 pass,
72 fail**. All failures are in new audit files; all 13,787 previous tests pass.
Two legacy value fixtures initially abort before pass execution. The parent
replaced their text with validated direct IR, formatted the audit packages, and
reran all 74 new Moon tests: **two pass and 72 fail**. The corrected legacy tests
now fail at optimizer behavior assertions. All six Bun tests fail again from
their repository paths. Across both languages, 80 new tests have two passing
controls and 78 failures; overlapping tests are not independent bug counts.

The two nested-condition propagation tests pass. They do not reproduce the
value agent's V2 hypothesis. Keep them as controls; do not add an implementation
task for that witness. Agent reports remain immutable source records with their
original UNRUN labels. Parent results supersede only those labels, not the
reports' explicit evidence limits.

Repair priority is observable wrong values and invalid output, then type/byte/IR
and harness contracts, then positive coverage and measured resource work. Plain
Precompute returns 0 instead of 7 after deleting a live scratch write. Original
DAE/O returns stale/default values across legacy control and can remove a type
used by a table initializer. Typed-prefix local tests expose stale definitions;
Heap2Local aborts on the shared-allocation fixture. DAE2's ordinary imported
callback changes original behavior in the same way as v133 closed-world DAE2;
its intrinsic oracle case aborts separately. Resolve the imported-call contract
without treating an oracle error or changed original behavior as acceptance.

Validator local-initialization frame scope and aggregate atomic storage/reference
rules have specification/wasm-tools evidence that conflicts with v133. This is
different from cases rejected by both external tools. Preserve those conflicts
and settle the represented proposal contract before changing the expectations.

The clearest bounded storage result is shared tuple materialization: four pair
calls request **20 locals instead of eight**. Source review also finds repeated
type-conflict rounds, candidate-free sibling cleanup, graph queries, nested RSE
probes, caller rebuilds, interner/history lookups, deep tail comparisons, branch
and label copies, and post-lift dense storage. These are resource leads with
source bounds. They are not measured native time, allocated bytes or peak RSS.
No performance win, pass closure or new aggregate signoff follows from this
audit. All four 1× targets, canonical output gaps and final CI/coverage/aggregate
gates remain open.

The [active repair queue](../../../agent-todo.md#p00a--eight-agent-audit-repair-queue-ir2-mass-audit)
contains the implementation tasks and invariants. The
machine-readable evidence (local-only record)
contains all eight reports, source/test/artifact hashes, oracle identities,
parent commands, failure messages and passing-control status. At this audit checkpoint, production fixes were open and the default gate was
red. The October 8 checkpoint below records the subsequent implementation.


## October 8, 2026 — Mass-audit repairs and green default suites

All eight audit agents completed their reports before parent compiler commands.
The parent confirmed failing regressions, applied the source fixes and completed
focused follow-up reviews. Agents prepared patches and independent fixture
checks; they ran no Moon commands. The parent serialized compilation and tests.

The default `moon test --target wasm-gc --jobs 4` suite passes **13,890/13,890**
tests. `moon info`, `moon fmt` and README/API synchronization pass.
`bun test scripts/lib scripts/test` passes **343 tests, with zero failures**;
the existing opt-in Chromium control remains skipped. No passing test was
disabled or moved out of the default suite. Long stress/fuzz controls retain
their existing separate-lane policy.

The fixes preserve live scratch writes and typed-entry/captured values; complete
original DAE legacy parameter and caller walks; preserve table type roots and
opaque imported callback signatures; retain shared allocation owners; represent
repeated linear tuple evaluations in flow; bind analyses to function identity;
own interned rows; reject cycles and out-of-scope branches; validate subtype,
shared-domain, limit and reference contracts; and enforce byte/text bounds and
Unicode/name handling. Positive coverage adds long-region bounded LocalCSE,
legacy scalar/sibling cleanup, HSO self-target wrappers and narrow private-scalar
DAE2 signature pruning with distinct runtime identities.

The compiled first integration gate exposed 1,103 failures, chiefly because
stricter text/type/IR checks now reject old invalid fixtures. Corrections removed
978 raw comma lines, six attached comma bytes and 177 surplus module tails,
while preserving 1,142 complete module prefixes. Invalid final parents became
explicit open parents. Initialization checks now use the Core frame rule.
Detached/self-targeting branch fixtures gained actual enclosing labels; OI and
DCE fixtures now validate lowered and encoded/decoded modules. Two delegate
fixtures use direct instructions for a valid nested legacy handler, independent
of the narrower legacy authoring parser. Parser and verifier checks were kept.
The last two intermediate gates had 17 and two failures; their records remain.

OptimizeCasts uses nullable storage for inner-frame captures and restores their
non-null result type. Function-frame carriers retain their old declaration and
opcode count. The scope mark uses existing cache storage, with no new dense row
or per-use graph walk. Stable tuple captures avoid redundant capture locals and
keep effects at the original producer positions. Sparse occurrence scratch and
bounded LocalCSE candidates do not retain oversized capacity across narrow
regions.

The cache owner field and `InvalidAnalysisOwner` error are public interface
changes. The earlier legacy-catch scope field/type/helper also remain in the
validator interface. Constructor users retain their existing calls; direct
public struct literals and exhaustive error matches need review. See
[IR ownership contract](../ir2/local-ssa-policy.md) and
[validator/proposal conflicts](../validate/module-validation-phases.md#october-8-2026--audit-contract-repairs).

Sources: [active dispatcher regressions](../../../src/cmd/mass_repair_dispatch_wbtest.mbt),
[audit tests](../../../src/passes/mass_audit_module_wbtest.mbt),
[DAE2 controls](../../../src/passes/mass_repair_dae2_wbtest.mbt),
[IR capture and scope tests](../../../src/ir/mass_audit_ir_wbtest.mbt),
[cast storage test](../../../src/passes/mass_audit_ir_wbtest.mbt),
[binary bounds tests](../../../src/binary/mass_audit_codec_wbtest.mbt),
[frontend tests](../../../src/wast/mass_audit_codec_wbtest.mbt),
[harness contract](pass-fuzz-compare.md).


The first repaired native release build was `b8e8069f…`, compared with frozen pre-repair
`f8c5b53a…` and verified v133 `8f25e9fd…`. Sixty bounded fixture/pass cases
produce 60 valid current modules and 68 current observations, all equal to the
original. Across original/before/current/oracle lanes, 234 outputs validate and
266 observations are retained. Forty-eight post-optimization indirect-call
probes preserve matching success and mismatched type traps in all four lanes.
These probes test the retained type-identity invariant; they do not replace an
aggregate pass campaign.

Agent judgment classifies the ordinary imported callback's v133 result 0 versus
original/current 11 as an observable original-behavior failure at the opaque
host boundary. Four intrinsic v133 command failures are tool failures, including
two aborts; they are not accepted semantic matches. The old Starshine table-type
root failures remain historical validation/command failures. All current cases
validate and match the original; no blanket unknown-difference acceptance is used.

The private cascade is 111 canonical bytes in both current DAE2 modes, versus
127 before and v133's 157 plain / 119 optimizing bytes. Equal-pruned members
are 69 bytes, versus 73 before and 79 / 75 in v133. Singleton witness output is
63 bytes, **three bytes larger than original/before**, though smaller than
v133's 66 / 64. Retain that baseline size gap; successful execution and type
traps do not erase it. These are bounded one-round no-pass v133 strip-debug
writer sizes, with exact commands and hashes in the evidence record. Large
canonical parity and all four 1× targets remain open.


The subsequent packed-dependency build `3c348752…` passes the full 13,886-test
suite and all 64 bounded native fixture/pass cases. Its 64 outputs validate,
and 78 current observations equal their original inputs. Across all four
lanes, 250 output rows validate and 306 observations remain recorded. The
48 type-identity probes also pass. These counts extend the first repaired
build's scope with LocalCSE reuse, local-write, NaN-payload and signed-zero
controls. Earlier command/tool failures retain their original classification.

The complete-command performance phases retain all samples, outliers, binary
hashes, exact output checks and independent validation. Each phase uses CPU 6,
one warm-up and three measured samples per side with alternating order. The
large input is 6,211,596 bytes with SHA-256 `98189860…`; the oracle is verified
Binaryen 133 with SHA-256 `8f25e9fd…`. Different cohorts have different host
conditions; compare binaries within a cohort, rather than subtracting absolute
medians across phases.

| LocalCSE phase | Narrow baseline median | Expanded median | Time above narrow baseline | RSS above narrow baseline |
| --- | ---: | ---: | ---: | ---: |
| First expansion `b8e8069f…` | 697.575 ms | 1009.921 ms | 44.776% | 12.468% |
| Owned storage `96aab657…` | 819.447 ms | 1122.026 ms | 36.925% | 7.849% |
| Matcher ordering `9b9991bc…` | 787.578 ms | 1020.259 ms | 29.544% | 6.450% |
| Stable scalar leaves `6bfd8fb2…` | 839.625 ms | 990.892 ms | 18.016% | 6.490% |
| Packed dependencies `3c348752…` | 869.258 ms | 1031.633 ms | 18.680% | 7.809% |

The last cohort's packed output is byte-identical to the stable-leaf output.
It saves 617 raw / 849 canonical bytes versus the narrow baseline. Its median
time is 5.572% lower than the stable-leaf binary in the same cohort, but median
RSS is 1.633% higher. This is partial time recovery with an open memory cost,
not a general performance win. The unchanged OptimizeInstructions control is
noisy: packed median 2587.951 ms, minimum 2072.826 ms, maximum 3154.217 ms and
MAD 515.125 ms. Retain it without assigning a causal change to LocalCSE packing.
No allocation-byte profile, broad performance proof or aggregate parity signoff
is claimed. All four 1× goals and final CI/coverage/10,000-case campaigns remain
open. The repair evidence (local-only record)
retains the exact records, not just selected medians.


### Final storage and singleton checkpoint

Current native `ee57fe32…` passes 13,890 default Moon tests, all 66 bounded
native cases and the 48 matching/mismatching type-identity probes. Its 66
outputs validate, and all 86 current observations equal the original.
Across original/before/current/v133, 258 output rows validate and 338
observations remain recorded. The two new LocalCSE child-row fixtures check
four argument pairs each; parent dependency unions and tee writes retain
original values. The earlier six command/tool failures remain historical.
Bun remains 343 passed, zero failed and one existing opt-in Chromium skip;
no Bun source changed after that gate. Info, formatting and README/API sync pass.

The singleton output is now **59 canonical bytes in both DAE2 modes**, versus
original/before 60, witness intermediate 63 and v133 66 / 64. The carrier is
open and supertype-free, while all admitted source singletons are final.
After optimization, an indirect call with the target's type succeeds and
one with the caller's equal final signature traps. The multi-member group
and opaque callback controls still pass. This closes the bounded +3-byte
witness gap; general referenced/GC type families and aggregate parity stay open.

The direct nameless Moon fixture encodes 59 bytes in plain mode and 60 in
optimizing mode. Vacuum deliberately keeps one nop in an empty function.
The fixed no-pass v133 strip-debug writer normalizes that byte, producing
59 in both native canonical rows. A first strict-shrink optimizing assertion
exposed this distinction; the corrected assertion requires no encoded growth
in optimizing mode while plain mode still requires shrinkage. The old witness
fails both contracts. Existing Vacuum expectations and source behavior stay
unchanged. Both failed diagnostic runs remain in the evidence.

The final large-input cohort uses the same CPU 6, n3, alternating order and
one warm-up protocol. Every current raw/canonical output is byte-identical to
packed `3c348752…` on that input.

| Pass | Before median | Packed median | Current median | Current RSS | Current time versus before |
| --- | ---: | ---: | ---: | ---: | ---: |
| LocalCSE | 909.105 ms | 1080.924 ms | 1081.030 ms | 159,172 KiB | +18.911% |
| DAE2 | 3704.177 ms | 3807.630 ms | 3713.453 ms | 262,416 KiB | +0.250% |
| DAE2 optimizing | 6087.079 ms | 6159.204 ms | 6313.666 ms | 290,424 KiB | +3.722% |
| OptimizeInstructions | 2111.138 ms | 2141.017 ms | 2061.173 ms | 156,052 KiB | −2.367% |

Shared LocalCSE dependency rows have +0.010% median time and +0.338% median
RSS versus packed storage in this cohort; both ranges overlap. No measured
clock or peak-memory gain follows from the source allocation reduction.
The residual LocalCSE cost versus the narrow pass is +18.911% time / +8.027%
RSS for 849 fewer canonical bytes. Arena lifetime and retained-expression
cost remain open. DAE2/O and OI controls do not isolate a causal change from
this LocalCSE repair. Preserve their spreads and all earlier adverse samples.

A separate 32,717-byte scalar fixture has 4,098 functions and activates the
one-carrier closed-world path. Its original and all eight successful output
run observations agree, and each output validates. Precise n5 exit timing
uses blocking wait4 with a deadline, one warm-up and alternating sides.
The first n3 timing cohort used a 10 ms polling quantum; keep it as coarse
historical evidence, not precise signoff for these short commands. Both
Python-launched timing cohorts have a uniform RSS floor. A separate small
native launcher gives the memory measurements below; its source/binary
hashes and compile command are retained.

| Scalar fixture | Witness time | Current time | Time change | Witness RSS | Current RSS | Canonical bytes, witness → current |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| DAE2 | 21.083 ms | 19.188 ms | −8.991% | 17,808 KiB | 17,676 KiB | 16,452 → 16,448 |
| DAE2 optimizing | 43.564 ms | 40.587 ms | −6.833% | 19,856 KiB | 19,572 KiB | 16,452 → 16,448 |

This bounded scalar result reduces witness cost. It does not establish broad
clock/RSS or allocation-byte gains, and its larger v133 shape difference is
not aggregate parity signoff. All four 1× targets and deferred final CI,
coverage and 10,000-case GenValid campaigns remain open. Exact records are in
repair evidence (local-only record).

## October 9, 2026 — Optimizer and IR audit

Eight agents and an independent Claude Code review inspected `src/passes`
and `src/ir` without editing repository source. Claude's prescribed `--bare`
mode could not use the local OAuth
login; the user approved `--safe-mode` with `Read,Glob,Grep` only. Its findings
were checked against source and by separate agents. `moon test src/ir` passed
676/676 and `moon test src/passes` passed 9,173/9,173 before changes. These
suites did not detect the three executed semantic differences below or the
proposal trap deletion found by direct OptimizeInstructions.

- **Reproduced wrong behavior, SimplifyLocals:** a valid module with an unused
  local assignment from an out-of-bounds `v128.load` traps before the pass but
  returns after `--simplify-locals`. Current-source `moon run src/cmd` produced
  an empty function body; Node execution confirmed `RuntimeError` before and
  normal return after. [HOT lift](../../../src/ir/hot_lift.mbt) classifies SIMD
  memory instructions as `HotOp::Simd`, while [HOT flags](../../../src/ir/hot_flags.mbt),
  [shared effects](../../../src/ir/effects.mbt), and the private
  [SimplifyLocals effects](../../../src/passes/simplify_locals.mbt) omit their
  memory and trap effects. Minimal WAT: `(module (memory 1) (func (export
  "run") (local v128) i32.const 65536 v128.load local.set 0))`.
- **Reproduced wrong value, MergeBlocks:** a function that adds a memory-reading
  call result to a result block containing `v128.store` returns 1 before
  `--merge-blocks` and 2 after it. Current-source output validates. The same
  zero SIMD effect mask lets [MergeBlocks](../../../src/passes/merge_blocks.mbt)
  lift the store before the call through the purity test in
  [pass_common.mbt](../../../src/passes/pass_common.mbt). A reduced valid WAT
  case uses a one-page memory, a reader function with `i32.load 0`, and
  `i32.add (call $reader) (block (result i32) (v128.store 0
  (v128.const i32x4 1 2 3 4)) (i32.const 1))`.
- **Reproduced wrong value, CodePushing with `--ignore-implicit-traps`:** a
  scalar load from address zero moves past a `v128.store` to that address.
  Current-source output validates; fresh Node instances return 0 before
  `--code-pushing` and 1 afterward for both values of an intervening `if`
  condition. The trap-relaxation option permits moving the scalar load, but
  the zero SIMD effect mask incorrectly permits crossing its memory write.
  The default trap policy blocks this particular movement.
- **Validated output loses a required trap, OptimizeInstructions:** a valid
  proposal module with null references passed to `string.encode_utf8_array` and two
  nested `i32.shr_u` operations is accepted by the current CLI. Direct
  `--optimize-instructions --validate` reduces its body to `i32.const 0`,
  deleting the encoder and its null-reference trap. The
  [stringref proposal](https://github.com/WebAssembly/stringref/blob/main/proposals/stringref/Overview.md)
  requires a trap for a null `stringref`. [Shared effects](../../../src/ir/effects.mbt)
  omit the `StringOp` trap and array-write bits. Binaryen's shell and Wasmtime
  both reject this proposal opcode, so execution was not observed in an
  independent runtime; the finding rests on accepted input, exact output and
  the string instruction's trap contract.
- **Source-confirmed, behavior impact pending:** SimplifyLocals' private
  heap mask omits `ArrayLoad` and `ArrayStore`. A valid direct replay with an
  array load, intervening array store, and later local read preserved the
  original value: the rewrite kept the load before the store with a scratch
  local. The missing mask remains a contract gap, but that simple wrong-value
  claim is withdrawn. Find a distinct executable trigger before assigning
  output impact to this mask gap.
- **Confirmed IR API defects in isolated wasm-gc tests:** a caller can mutate
  the array returned by [branch-table side-table access](../../../src/ir/hot_side_tables.mbt)
  without a revision bump. HOT verification still passes, fresh CFG edges
  change, and the cached CFG remains stale. The normal pass retargeting paths
  use revision-bumping setters; no active pass misuse was found. The public
  [exact-instruction setter](../../../src/ir/hot_mutate.mbt) also accepts an
  `i64.add` payload for an `i32.add` node; HOT verification and lowering pass,
  but module validation rejects the output. Active OptimizeInstructions code
  uses this setter, with no confirmed bad instruction at a current call site.
  A valid typed loop whose body is `unreachable` leaves its entry `local.get`
  unmapped in [default SSA](../../../src/ir/ssa_local.mbt); the expanded CFG
  maps it correctly. Active SSA destruction guards typed loops. A separate
  typed loop with a body write maps correctly, so a broad claim that all typed
  loop entries are skipped is withdrawn. [Natural-loop analysis](../../../src/ir/loop_info.mbt)
  includes a dead `nop` predecessor in a loop in an isolated failing test,
  although no active pass consumes LoopInfo today. Promote these temporary
  tests into repository regressions before repair.
- **Unverified IR leads:** [batch child rewrites](../../../src/ir/hot_mutate.mbt)
  can mutate earlier spans before a later preflight failure. The carried-local
  global-minimum dependency query in [HOT lower](../../../src/ir/hot_lower.mbt)
  warrants a semantic HOT fixture and a production pass-origin witness.
- **Performance leads:** `effects_for_node` allocates a full node-count array
  and bitset per call; CodePushing repeats a full node-count allocation while
  checking rethrows; nested changed struct constructors can trigger repeated
  rewriting in GlobalTypeOptimization. Benchmark pass-local time and allocated
  bytes before claiming a measured regression. The older, source-specific
  Binaryen 133 command ratios in [the active backlog](../../../agent-todo.md)
  remain historical measurements, not a current pass-local signoff.

No source fix, regression test, broad fuzz comparison, or full validation gate
was part of this audit. A string-gathering table-global candidate was withdrawn:
the validator processes table initializers before defined globals, so its
proposed input was invalid; imported global indices stay stable.
On the reduced SIMD and string fixtures, the default `--optimize` preset
preserved the original behavior or bytes; these observations prove direct-pass
defects and do not establish a preset failure.

## October 9, 2026 — Optimizer and IR repairs

This checkpoint follows the [same-day audit](#october-9-2026--optimizer-and-ir-audit).
The audit text above keeps its original observations and pre-repair test counts.

- [Exact SIMD and string effects](../../../src/ir/effects.mbt) now classify all
  SIMD memory loads, stores and lane forms, plus string array reads, writes and
  null-reference traps. `string.eq` remains pure for nullable operands, and
  synthesized `ref.as_non_null` retains its trap flag. HOT construction and
  mutation give exact SIMD, string, and unary nodes matching flags. SIMD stores
  have no value flag, and direct node mutation refreshes exact flags;
  [SimplifyLocals](../../../src/passes/simplify_locals.mbt)
  reads those flags and classifies `ArrayLoad` and `ArrayStore` in its private
  heap mask. Focused pass tests and [command dispatch tests](../../../src/cmd/cmd.mbt)
  retain the trapping load and encoder and preserve load/call order before a
  SIMD store. The stringref trap is still source-backed rather than runtime
  executed because the available engines reject that proposal opcode.
- [Branch and catch side tables](../../../src/ir/hot_side_tables.mbt) copy
  mutable arrays on construction, allocation, and return, so retained payload
  objects and accessor results cannot silently alter CFG targets or catch arms.
  The `HotFunc` fields remain public; direct field writes still require the
  caller to manage revisions. A duplicate continuation copy was removed.
- [Exact-instruction mutation](../../../src/ir/hot_mutate.mbt) now checks
  operand and result types for concrete binary and comparison nodes before
  storing the payload. It rejects the tested `i64.add` replacement of an
  `i32.add` node. Polymorphic operands and other exact families can be
  assembled in stages by active passes and remain outside this setter guard;
  the pipeline's final module validation still checks them.
- [Compact-CFG local SSA](../../../src/ir/ssa_local.mbt) visits loop-entry
  operands before the loop body, including a typed loop with an unreachable
  body. Repeated tuple entry lanes and shared operand references record each
  static local definition once. [Natural-loop analysis](../../../src/ir/loop_info.mbt) admits only
  header-dominated predecessors, excluding the reproduced dead `nop` block.
  Batched control rewrites now validate planned region labels before writing
  child spans. [HOT lowering](../../../src/ir/hot_lower.mbt) searches for a
  later conflicting local read when the cached first read is below the query
  bound; the bounded index scans a wide reader set once for multiple writers.
  Reduced two-local correctness and 32-local work-count tests failed before
  these changes.

The focused IR suite passed 691/691 after these fixes. Direct pass and
command-dispatch regressions passed for the four affected passes; final
`moon fmt`, `moon info`, and `moon test --no-render` passed, with 13,964/13,964
tests and zero type errors. Native command SHA-256 is
`ef9d25da69bc5a1832d7c12a4f8f3f2ef33a5759fb58190f8fbd1dee55e07b30`;
the verified Binaryen 133 oracle SHA-256 is
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
The fresh native CLI and Node return the original observations after each
direct pass: the out-of-bounds SIMD load traps, MergeBlocks returns `1`, and
CodePushing with `--ignore-implicit-traps` returns `0`. All three optimized
modules pass independent `wasm-tools validate --features all`. The CLI's WAT
frontend rejects the stringref proposal syntax; the API/dispatcher regression
validates the accepted binary and retains `string.encode_utf8_array`.

Fresh seed `0x5eed` GenValid aggregate runs used the two explicit prebuilt
native binaries, eight workers, the pinned oracle, and `wasm-tools` as the
primary validator. Each requested and compared 10,000 cases with zero
validation, generator, property, or command failures:

| Pass and profile | Normalized | Cleanup normalized | Raw residuals | Judgment |
| --- | ---: | ---: | ---: | --- |
| `merge-blocks`, `merge-blocks-all` | 7,007 | 0 | 2,993 | Sampled expression cases remove two effect-free empty-arm `nop`s and save two canonical bytes. This is a measured size win for that family. |
| `simplify-locals`, `simplify-locals-all` | 380 | 0 | 9,620 | Every canonical output is smaller, but the seven selected profile families include effect reordering. Retained samples show pure debris removal and an unused global read moved across a load. Treat the remaining aggregate as open parity evidence until each family has a semantic and downstream check. |
| `code-pushing`, `code-pushing-all` | 4,493 | 5,507 | 0 | The documented `local-cleanup-debris` normalizer accounts for the output differences. No unnormalized residual remains. |
| `optimize-instructions`, `pass-oi-all` | 8,623 | 0 | 1,377 | A sampled `boolean-select` case folds constant conditions and saves 16 canonical bytes. The 1,080 tuple-profile residuals are smaller but retain the documented downstream-size risk, so they stay open parity gaps. |

The reports are under `.tmp/optimizer-ir-fix-{merge-blocks,simplify-locals,code-pushing,optimize-instructions}-v133-10000/`.
Only 20 ordinary mismatch bundles per lane were retained; every case record
remains in its report. Runtime semantic observation was off in these four
lanes. These generated profiles do not replace the direct SIMD and string
regressions, which they do not target.
The performance findings from the audit remain leads until pass-local time and
allocated bytes are measured on comparable fixtures. The [active backlog](../../../agent-todo.md#p00b--october-9-optimizer-and-ir-follow-up-ir2-effect-correctness)
tracks that evidence and the remaining aggregate comparisons.

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
