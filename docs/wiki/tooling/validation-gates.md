---
kind: workflow
status: supported
last_reviewed: 2026-07-14
sources:
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
  - ../raw/research/0673-2026-05-26-dae-control-debris-normalizer.md
  - ../../../scripts/test/task-family-commands.ts
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

Use `--wasm <path>` to test a candidate artifact outside `tests/node/dist/`; relative paths resolve from the repo root. The spec workload runs against a temporary runner copy so the checked artifact remains available for later validation or size inspection. The runtime lane is Preview 1 Core-module execution through `wasi_snapshot_preview1`; use [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md) for import-module, `_start`/reactor, security, and WASI 0.2/0.3 separation. Use `bun self-opt build` only when the artifact itself must be regenerated, and ask before running the full build pipeline or full-spec lane in an ordinary development thread.

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
