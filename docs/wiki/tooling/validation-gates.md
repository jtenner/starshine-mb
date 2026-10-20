---
kind: workflow
status: supported
last_reviewed: 2026-10-20
sources:
  - ../raw/tooling/2026-10-20-master-ci.json
  - ../../../ffi/src/ffi/export-schema.generated.json
  - ../../../.github/actions/setup-moonbit/action.yml
  - ../../../.github/workflows/fuzz.yml
  - ../../../ffi/src/npm/toolchain.json
  - ../../../scripts/lib/npm-licenses.mjs
  - ../../../scripts/lib/ci-optimizer-gates.test.ts
  - ../../../src/wast/scalar_nan_payload_wbtest.mbt
  - ../raw/tooling/2026-10-19-pass-review-follow-up.json
  - ../../../src/passes/review_local_control_wbtest.mbt
  - ../../../src/passes/review_vacuum_arity_wbtest.mbt
  - ../../../src/ir/hot_control_entry_preservation_wbtest.mbt
  - ../raw/tooling/2026-10-19-pass-review-corrections.json
  - ../../../src/lib/proposal_type_format_wbtest.mbt
  - ../../../src/passes/dae2_raw_local_flow_boundary_wbtest.mbt
  - ../../../src/ir/hot_lower_scope_query_wbtest.mbt
  - ../../../src/ir/hot_lower_value_stack.mbt
  - ../raw/tooling/2026-10-18-master-ci.json
  - ../../../scripts/lib/moon-test-selection.ts
  - ../../../scripts/lib/moon-test-selection.test.ts
  - ../raw/tooling/2026-10-09-output-differences-v133.json
  - ../raw/tooling/2026-10-04-starshine-v133-review.json
  - ../raw/tooling/2026-10-05-starshine-p00-checkpoint.json
  - ../../../claude_review_10_3_6.md
  - ../../../src/passes/dae2_effect_order_wbtest.mbt
  - ../../../src/passes/optimizer_correctness_regressions_test.mbt
  - ../../../src/passes/optimizer_remaining_regressions_wbtest.mbt
  - ../../../src/passes/local_subtyping_exact_wbtest.mbt
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
| `bun validate test [--target wasm-gc] [--moon path]` | Runs every default source-file test through Moon, using explicit file paths to keep its launch arguments bounded. | Defaults: target `wasm-gc`, at most 16 workers, all `.mbt` and `.mbt.md` files under `src/`; Moon retains test-kind, skip, expected-panic, and result semantics. | Complete test execution without fuzz; CI uses `--target wasm` to preserve its original backend. |
| `bun validate full [--profile ci] [--seed <seed>] [--target wasm-gc]` | Runs the repo's local CI floor: `info`, `fmt`, `check`, `test`, then all fuzz suites through [`runFuzz(...)`](../../../scripts/lib/fuzz-task.ts). | Defaults: profile `ci`, target `wasm-gc`, random/time-derived fuzz seed when omitted, `moon` from `MOON_BIN` or `moon`. | Release-like local gate, broad validation before publishing, and high-risk behavior changes; use [`release-process.md`](release-process.md) for the full version/package/release-note checklist. |
| `bun validate coverage [--top n] [--baseline path] [--update-baseline]` | Parses `moon coverage analyze`, reports uncovered-line totals, and optionally fails CI on uncovered-line regression versus a simple baseline file. | Default top count is `10`; no baseline means report-only. | Coverage reviews and CI coverage-regression checks. |
| `bun validate readme-api-sync ...` | Verifies README/API synchronization through [`scripts/lib/readme-api-sync`](../../../scripts/lib/readme-api-sync.ts). | Arguments are owned by the readme-sync parser. | Public API or README surface changes. |
| `bun validate trace-benchmark [--repeat n] [--corpus name] [--target target] [--list-corpora]` | Runs `src/validate_trace` benchmark corpora and emits trace summaries; the wiki stores durable corpus totals separately from machine wall time. | Default target `wasm-gc`; repeated `--corpus` filters and `--list-corpora` lists available corpora. | Validator trace performance work. |
| `bun validate self-opt-smoke [--wasm path] [--limit n|--file path]` | Validates an already-built self-optimized CLI artifact with `wasm-tools validate --features all`, executes the artifact under the Node-hosted WASI Preview 1 runner with `--help`, then runs a fast WAST spec workload. | Defaults to `tests/node/dist/starshine-self-optimized-wasi.wasm` and `--limit 1`; `--wasm` may point at a candidate artifact such as `.tmp/o4z-bench/starshine-o4z-candidate.wasm`. | Checking optimized-artifact safety without rebuilding the full self-opt pipeline; runner/Preview boundaries live in [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md). |
| `bun validate self-opt-full [--wasm path]` | Runs the same wasm-validity and Node-hosted WASI Preview 1 smoke checks as `self-opt-smoke`, then executes all checked-in `tests/spec/**/*.wast` files through the self-optimized CLI artifact. | Forwards to the self-opt check lane with `--full-spec`; ask before running because it is intentionally broader than the default smoke lane. | CI/full signoff that the optimized artifact remains runtime-safe and spec-workload-correct. |
| `moon prove src/validate_proof` | Required formal-proof gate for the proof helper package, separate from ordinary validation. | Requires a configured MoonBit proof toolchain and solvers; solver/config flags are host-tooling controls, not semantic repo policy. | Changes to proved helper contracts or the validator proof kernel. |

## October 18: complete Moon test selection

Moon's package-wide selector repeats empty file entries across test classes.
The pass package can exceed Linux's single-argument limit before its whitebox
tests start. Required CI, full validation, and coverage share this failure.
The source selector discovers all ordinary `.mbt` and `.mbt.md` files under
`src/`, including inline tests and test helpers, and passes each path once.
Moon selects and executes the tests; no generated test metadata or driver is
rewritten, and no custom result interpreter replaces Moon.

The same selection is used by the test-only lane, the test stage of full
validation, and the single coverage analyze call. Explicit paths preserve
Moon's default handling of skipped, unnamed, panic, asynchronous, and bench
cases. A filename wildcard is not an alternative: Moon's file filter requires
exact names. Full validation still runs its complete configured fuzz profile
after successful tests. The required job retains its previous Wasm backend.

The local red case fails before the pass whitebox driver starts: its default
selection argument is 167,107 bytes, above Linux's 131,072-byte per-argument
limit, and the kernel returns `E2BIG`. Explicit file selection reduces that
argument to 50,230 bytes. Reconstructed default and explicit Wasm selections
contain the same 15,167 case IDs, exclude the same 173 skipped normal cases
and 3,439 bench cases, and have equal inventory hashes. This is selection
evidence; execution results are recorded separately in the
[CI repair record](../raw/tooling/2026-10-18-master-ci.json).

Native debug tests have a separate compiler limitation: core `Array.map` on
the mixed `HotLowerStackValue` record creates an uninitialized array which
MoonBit v0.10.15 cannot lower. The scope-query fixture now accepts an
initialized `FixedArray` and uses `hot_lower_value_stack_makei` for computed
values. The existing stack and scope assertions remain active. This extends
the initialized-storage rule already used by the native stack; it changes
neither production behavior nor public interfaces.

After the launch repair, complete local and remote tests run successfully.
Fresh coverage then reports 28,263 uncovered lines in 255 files, exceeding the
retained 28,138-line budget by 125. The budget remains unchanged. Bounded tests
now check raw DAE2 plan rejection without graph publication, frozen and cached
reaching definitions, branch payloads and indexed-loop carry. Separate public
type tests check GC and descriptor identities, exact/shared references, wide
memory/table limits, declaration order and diagnostic section formats.

All 27 focused tests pass on instrumented Wasm. Adding their traces to the
completed red run gives 28,127 uncovered lines. The earlier incremental stage
records all 54 existing production source maps and 33 original traces unchanged.
This incremental result is an estimate before the separate fresh
clean/test/report cycle and remote rerun;
[the repair record](../raw/tooling/2026-10-18-master-ci.json) keeps those scopes
separate. The fresh cycle at `80301e701` passes with 28,128 uncovered lines,
ten below budget. Its one additional uncovered point is in
`src/validate/validate.mbt:403`; the fresh total supersedes the estimate.

Independent review then identifies three weak DAE2 test controls. Corrected
cases use accepted ample-budget bodies, complete intrinsic-call operands and
separate frame/function dependencies. The label mismatch now uses in-range
labels, and a wrapper case checks both plan rejection and explicit commitment
of an accepted dependency plan. All 28 focused tests pass. The final master
rerun verifies this later test version. No optimizer implementation, public
API, skip list, fuzz count or coverage budget changes.

## `bun validate full` Flow

[`runValidateFull(...)`](../../../scripts/lib/validate-task.ts) is intentionally ordered:

```text
moon info
moon fmt
moon check --target <target>
moon test --target <target> --jobs <bounded-workers> <all-source-files>
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
   bun validate test --target wasm
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

3. **`dae-differential`** runs the retained-versus-fresh callsite-path tests, the topology-changing dead-suffix guard, a fresh native release build, and a deterministic 10,000-case direct-DAE GenValid check against its pinned legacy Binaryen `132` baseline:

   ```text
   moon update
   moon test --package jtenner/starshine/passes --file dead_argument_elimination_wbtest.mbt --filter '*retained dropped-result graph*'
   moon test --package jtenner/starshine/passes --file dead_argument_elimination_wbtest.mbt --filter '*complete dead-suffix call removal reports topology change*'
   moon build --target native --release src/cmd
   bun fuzz compare-pass --count 10000 --seed 0x5eed --pass dead-argument-elimination --normalize drop-consts --normalize unreachable-control-debris --determinism --codec-idempotence --out-dir .tmp/ci-dae-genvalid --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin "$BINARYEN_DIR/bin/wasm-opt" --require-binaryen-version 132 --max-failures 1 --no-reduce-mismatches
   ```

New dedicated pass evidence uses the verified Binaryen 133 target from `AGENTS.md`; the existing required differential job retains its explicit legacy 132 contract. For the third command group, set `BINARYEN_DIR` to an extracted official `binaryen-version_132` directory. CI downloads the official x86-64 Linux release archive. The 10,000-case lane is bounded, deterministic, and matches the repository-standard ordinary pass signoff count described below. Existing specialized workflows remain supplemental; their push triggers also name the repository's actual primary branch, `master`. Every workflow that installs MoonBit runs `moon update` before invoking workspace commands, so clean GitHub-hosted checkouts resolve `moonbitlang/x`. The Node workflow checks the package's static clean-checkout export/bin contract and JavaScript syntax because the runtime adapter wasm files are intentionally local-only and ignored; artifact-backed Node runtime testing remains a release/local lane. The examples workflow uses only active pass flags and the Node-24-compatible `actions/cache@v5`.

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

The wrapper passes the same complete source-file list through repeated
`--test-flag=<path>` arguments in one `coverage analyze` call. Moon still owns
the clean/test/report cycle; running separate analyze calls for file batches
would discard earlier coverage. No coverage baseline or failure policy changes.

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

## October 9, 2026 — Classify and repair generated output differences

This checkpoint supersedes the open output-family judgments in the earlier
October 9 repair table, for the four named generated profiles only. Classification
is an agent judgment based on the transform contract, inspected family, replay,
encoded size and common downstream cleanup. The harness does not supply a
semantic proof. Binaryen 133 remains the pinned oracle.

The table below records the final native CLI, SHA-256
`42f386573da7ccab4ae923122b17e29e9069a5686fb91921f89f439fd2de85a3`.
All four final lanes completed 10,000 cases. After the app restart, the valid
SimplifyLocals result was retained; the other three lanes were regenerated in
new `-renewed` report directories. Interrupted partial files remain separate
and are excluded from these totals. The final bounded suite passes
**14,001/14,001** tests (`moon test --target wasm-gc --no-render`).
`moon info`, `moon fmt` and the native release build pass. No public `.mbti`
change or new test skip was introduced. Earlier results and adverse timings
remain under their original executable identities in the evidence record.

| Pass | Compared | Normalized | Cleanup normalized | Residuals | Raw bytes saved | Canonical bytes saved |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| MergeBlocks | 10,000 | 7,007 | 0 | 2,993 | 5,986 | 5,986 |
| SimplifyLocals | 10,000 | 380 | 0 | 9,620 | 226,119 | 216,372 |
| CodePushing | 10,000 | 5,006 | 4,994 | 0 | 26,487 | 12,016 |
| OptimizeInstructions | 10,000 | 8,623 | 0 | 1,377 | 54,052 | 42,727 |

Each aggregate has zero raw or canonical size losses, and zero validation,
generator, property or command failures. All 40,000 inputs were regenerated
with seed `0x5eed`, eight workers, a prebuilt native CLI, the verified v133
oracle and independent `wasm-tools` validation. Runtime observation was off in
these aggregate commands; separate execution checks below provide that evidence.
The [machine-readable record](../raw/tooling/2026-10-09-output-differences-v133.json)
retains the baseline and replacement counts, executable identities and exact
scopes. The four pass dossiers retain the invocation arguments.
Historical `/tmp` paths in the dossiers and record identify provenance. Those
temporary files were lost at the app/host restart. Complete final replay data
was copied into the durable record before the restart; final aggregate results
and toolchain records are also embedded there. The fresh full-suite log and
comparison reports remain under the worktree `.tmp` directories.

- **MergeBlocks: Starshine-win, expression family.** All 2,993 residuals use
  one fixed input. Removing two effect-free `nop`s saves two bytes. A live
  exported wrapper preserves the payload and memory result; common v133 `-O`
  and `-Oz` cleanup produces identical bytes. The old effect and EH families
  had raw size losses from redundant controls and types. Their repaired output
  now matches v133 byte-for-byte. See [MergeBlocks](../binaryen/passes/merge-blocks/fuzzing.md).
- **SimplifyLocals: Starshine-win, seven finite generated families.** All
  10,000 outputs were replayed; there are 8,719 unique inputs. Common downstream
  `-O` and `-Oz` output is identical for every case. Node checks all unique
  inputs with separate original, Starshine and Binaryen instances: 235,150
  call scenarios, including 2,894 traps, agree on results and observed state.
  Five extra fixtures cover calls, ordered traps and a live exception handler.
  Source inspection covers pure debris, branchless controls, local traffic,
  and the discarded global read moved across a load with no intervening write
  or call. Raw declaration grouping closes the old raw-size losses; canonical
  savings remain. See [SimplifyLocals](../binaryen/passes/simplify-locals/fuzzing.md).
- **OptimizeInstructions: Starshine-win, tuple and boolean families.** All
  1,080 tuple rows were replayed from regenerated matching inputs; 338 inputs
  are unique. They remove 18,915 local operations, save 37,975 canonical bytes,
  and have identical common `-O`/`-Oz` output. Node results, division traps and
  globals agree. The 297 boolean rows share one input; literal condition folding
  saves 16 bytes per case with the same downstream output and execution result.
  Four descriptor inputs formerly lost raw bytes. Terminal bottom null, ordered
  terminal-trap cleanup and unused signature pruning now match v133 bytes.
  Descriptor runtime remains unavailable; this narrower result uses inspected
  source, independent validation and exact oracle output. See
  [OptimizeInstructions](../binaryen/passes/optimize-instructions/fuzzing.md).
- **CodePushing: Starshine-win, ten differing fixed families.** Each of the 20
  generated profiles has one input hash. Nine differences are effect-free
  `nop`s; the prefix family removes seven scratch locals and nested wrappers,
  saving 35 raw and six canonical bytes. Common downstream output and branch,
  trap and state observations agree. The old 513-case branch-value spill gap
  was a parity gap. Moving the fallthrough payload drop before the sunk sets
  closes it: both outputs are 51 bytes; a single-set fixture is 44 bytes.
  Wasmtime returns 9 and 42 on the two branch paths. See
  [CodePushing](../binaryen/passes/code-pushing/fuzzing.md).

Five read-only Claude Code Opus reviews ran with high effort and the authorized
safe mode. Findings were verified before edits. A late review exposed a real
correctness fault: module-wide type remapping could invalidate untouched bodies
that inlining restores later. Five new partial-selection tests failed before the
fix; the full-selection control passed. Partial selection now keeps the original
type index space. All 28 focused encoding tests pass after that repair.
The full-selection cleanup remains active.

The fourth review also found that direct OI cleanup and selected dispatch lacked
the opaque offset-metadata guard used by whole-module dispatch. Three tests
failed on changed output before the repair. The helper and both selected entry
points now preserve those intentionally unsupported metadata modules. All three
tests pass; each has a positive unguarded cleanup control. The fifth review and
a separate GPT review found no new correctness fault in the nop/control
admission gates or the shared control-transfer predicate.

A separate bounded cost regression checks type index 128 moving to zero in
both the function section and a typed block, whole-module byte reduction and
validation. Its extra full-size check failed before the change and passed after
it. For independent unshared plain signatures, interning and stable live
compaction only lower type indices. Index widths cannot grow; a strict type
section reduction therefore proves a whole-module reduction. This guarded path
sizes only the type section. The old full size and validation branch remains for encoder failure. With
valid admitted signatures, any removal strictly shrinks the section, so the
normal accepted path uses the remap proof and performs no module validation.
Independent output validation is required for signoff; optional pipeline
validation must not be described as an unconditional guard. See the
[cost regression](../../../src/passes/simple_type_cleanup_fast_path_wbtest.mbt).

Precise nop, branchless-control and local-declaration admission gates now avoid
body rewrites and legacy-EH scans when no supported candidate exists. The local
gate retains zero-run cleanup and repeated numeric-type remapping; a live
local-index and strict byte-saving control passes. The candidate-free guard
count failed before the fix. All three current grouping tests pass. A separate
GPT review found no new correctness fault. A sixth Claude attempt reached the
provider session limit; no review occurred in that attempt.

These results establish scoped semantic and size parity for the inspected
families. They do not establish engine speed, allocation savings, universal pass
parity, or a general optimizer performance win. On the separate 6 MB compiler
artifact, five quiet alternating pairs measure baseline/final pipeline medians
of 1.273972/1.439864 seconds: **165.892 ms added cost (13.0%)** for 20 bytes saved.
The earlier 702 ms and 296 ms adverse checkpoints remain under their original
binary hashes. The final declaration gate cuts the traced local-group stage
from 38.9 to 5.4 ms without changing output. The artifact output remains
**368,910 bytes larger than v133** (6,058,213 vs 5,689,303): an open size and
performance parity gap, not a Starshine-win. Native full-preset probes timed out
at 60 seconds on both baseline and the earlier checkpoint; artifact downstream
parity remains unverified. Seven paired small-input samples are in the SL
dossier; their timings do not support a general speed claim.

Independent stringref and descriptor execution, the known combined-pass
fixed-point gap, and the separate IR scaling leads remain in the
[active backlog](../../../agent-todo.md#p00b--october-9-optimizer-and-ir-follow-up-ir2-effect-correctness).

## October 17, 2026 — Optimization-pass audit red/green checkpoint

An eight-agent read-only audit covered the optimization-pass implementations,
shared walkers, dispatcher, module cleanup, and focused tests. The parent
verified all findings in source. Thirty-two focused regressions then failed on
the pre-fix code and pass after the repairs. The permanent fixtures are in the
[main regression suite](../../../src/passes/optimizer_correctness_regressions_test.mbt),
[remaining regression suite](../../../src/passes/optimizer_remaining_regressions_wbtest.mbt),
[exact local-subtyping suite](../../../src/passes/local_subtyping_exact_wbtest.mbt),
and pass-local test files.

The repaired families are:

- constant and type correctness: unsigned narrow precompute, SIMD LocalCSE
  result types, bit-exact signed-zero equality in DFE and raw OI, and exact
  reference types in LocalSubtyping;
- control flow and effects: DAE infinite loops, leading unreachable in
  CodePushing, nonlocal `br_if` in SGO, earlier exits in Vacuum, `try_table`
  fallthrough in DCE, catch-target safety in CoalesceLocals, divergent loop
  operands in HSO, `br_if` reads in SimplifyLocals, loop-carried SSA reads,
  tuple `local.tee`, and non-defaultable inline tail hoists;
- module and reference integrity: active-element slot preservation and late
  `ref.func` liveness in RUME, exported and shared abstract function references
  in DAE2, mixed function/external reference handling in MakeSharedObjects,
  nested external origins in GSI, continuation handler exactification in
  Precompute, and `ref.is_null` plus continuation-label uses in RemoveUnusedBrs;
- robustness and shared infrastructure: Unicode wildcard matching in NoInline,
  definite-write tracking in DAE artifact remapping, legacy `try` traversal in
  raw OI, legacy `try` cursors in raw SSA, Memory64 LocalCSE properties, and the
  second earlier-branch Vacuum case.

All **1,854** checked-in `src/**/*test.mbt` files pass in 38 bounded shards.
The single all-at-once `moon test` invocation exceeds this host's argument-size
limit before it can launch the pass package; this is a command-size limitation,
not a failing test. `moon fmt` and the native release builds pass. The release
CLI used for comparison has SHA-256
`e6b64ce56151b24153a35091d81099617b9c97cd673583bc5b089e6a6af73ea8`.

The v133 comparison campaign requested **250,000** current-tree GenValid cases
across 25 pass lanes and completed **248,232** comparisons. Twenty-three full
lanes used independent `wasm-tools` validation and one MakeSharedObjects lane
used Binaryen validation because current `wasm-tools` releases do not decode
the required GC opcode. Those 24 full lanes have no validation, generator,
command, property, or canonical-size regression. Five high-assurance lanes
(50,000 cases) also have no observed semantic, determinism, or codec failure.
The broad MakeSharedObjects diagnostic compared 8,232 of 10,000 cases; its
1,640 independent-validator failures and 128 Binaryen command failures replay
with identical counts and case behavior on baseline commit
`e798b3162c7889390c29d0c3228c11033e9ffcd4`. Two additional 10,000-case
baseline control lanes for GSI and MakeSharedObjects also match the current
case ledgers. Therefore the observed diagnostic failures are pre-existing tool
or oracle limits, not regressions from this repair set. They do not establish
universal semantic parity beyond the executed profiles.

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


## October 19, 2026 — Pass review corrections

The review starts at `a4237ca0336d665137622490ffe6f348f6e49176`.
The reported cases have different contracts:

| Area | Confirmed result and repair |
| --- | --- |
| DAE2 family arity | Function subtypes require equal parameter and result arities. Direct unvalidated `Module` input could still reach a bounds error. The new preflight returns an error before family graph construction and identity rewriting. |
| DAE2 indirect demand | The targeted signature split did not reproduce. Existing bidirectional family edges retain shared demand. Equal-arity contravariant and unequal-demand controls preserve compatible dispatch types. |
| String table initializers | Defined-global reads are invalid in table initializers; wasm-tools also rejects the proposed input. The raw module rebuild now remaps table `global.get` indices and preserves inline table strings. |
| MergeLocals ordering | Rebuilt IDs can differ from source positions. Both order guards and the carried-read preflight now use `HotNode.order`. Tests establish a missed hazard check and a missed optimization; no old semantic miscompile was proved. |
| HOT loop demotion | Block entry-prefix and label result arities now preserve scalar and tuple loop operands. The caller must still prove there is no continue to the old loop label. |
| DFE field names | Shifted owners are remapped, deleted owners are dropped, and merged owners keep only canonical field names. Inner field indices remain unchanged. |
| RUME reference-only bodies | Nullification is the intended verified v133 closed-world policy. Static and runtime-written indirect callees retain their executable bodies. |

Sources and bounded regressions are in the existing
[DAE2](../binaryen/passes/dae2/implementation-structure-and-tests.md#function-family-arity-and-indirect-targets),
[StringGathering](../binaryen/passes/string-gathering/starshine-port-readiness-and-validation.md),
[MergeLocals](../binaryen/passes/merge-locals/starshine-strategy.md#rebuilt-hot-nodes-retain-source-positions),
[HOT](../ir2/architecture-rules.md#loop-demotion-preserves-entry-operands),
[DFE](../binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md#field-name-ownership-during-type-compaction),
and [RUME](../binaryen/passes/remove-unused-module-elements/roots-reference-only-and-nullification.md#v133-check-of-reference-only-body-removal)
pages.

`moon info`, `moon fmt`, and `bun validate readme-api-sync` pass without public
`.mbti` changes. The repository's `bun validate test` gate passes
**15,213/15,213** tests on its default `wasm-gc` target. Plain `moon test`
first hit the OS per-argument limit while spawning the passes whitebox runner;
the existing explicit-file gate avoids the empty filename selection entries.
No tests were disabled.

Fresh native baseline/candidate and v133 runs validate 36 optimized modules,
plus six original modules. All 56 observed calls match the fixed fixture
results; each of the 12 baseline/candidate output pairs is byte-identical.
These controls cover shared and contravariant DAE2 dispatch in both DAE2
modes, and reference-only/static/runtime-written RUME targets in both worlds.
They do not establish general runtime equivalence.

An independent GPT source review found no defect in the final repairs.
Claude Code was invoked from the repository root with normal authentication
and read-only tools, but returned its session limit (exit 1) before reading
source. It supplied no review assessment.


### Scoped comparison and replay results

The [raw record](../raw/tooling/2026-10-19-pass-review-corrections.json)
contains exact executable hashes, commands, profile counts, size totals, all
retained baseline replays, native samples and reproducible benchmark recipes.
Every large lane uses seed `0x5eed`, a fresh prebuilt native command and
GenValid executable, verified Binaryen 133, `--jobs auto`, eight subprocesses,
20 mismatch bundles, and a 20,000 failure budget so residuals cannot truncate
the requested 10,000 comparisons. Automatic reduction is off; the initial
interrupted reduction run retains its bundles and pending inputs.

| Pass / profile / world | Compared | Canonical match | Cleanup match | Residual | Canonically larger |
| --- | ---: | ---: | ---: | ---: | ---: |
| StringGathering / ordinary portable / open | 10,000 | 0 | 0 | 10,000 | 0 |
| MergeLocals / `merge-locals-all` / open | 10,000 | 9,353 | 0 | 647 | 0 |
| DFE / `duplicate-function-elimination` / open | 10,000 | 5,000 | 0 | 5,000 | 0 |
| DAE2 / `dae2` / open | 10,000 | 2,879 | 667 | 6,454 | 0 |
| DAE2-optimizing / `dae2` / closed | 10,000 | 100 | 0 | 9,900 | 2,133 |

All validation, generator, property and command failure counts are zero.
Both DAE2 lanes use `drop-consts` and `unreachable-control-debris`.
**All five strict comparison commands exit 1 on structural residuals.** They
are not clean whole-pass parity signoffs. The full 100,000-case general and
10,000-case random-all-profile closeout lanes were not repeated for these
scoped repairs; an external-generator lane was not requested.

Twenty retained outputs per lane, 100 total, match the freshly built baseline
raw bytes. This proves sample provenance, not equality of every unsaved output.
The 647 MergeLocals unread-tee and 5,000 DFE fixed-point-caller residuals keep
their existing source-backed size-win classifications. The portable string
lane has no strings: all 20 inspected canonical diffs are empty-else nops,
but 3,844 cases are raw-larger and aggregate raw bytes grow 2,768 despite
29,981 canonical bytes saved. Keep those writer and unretained parity gaps
open. DAE2 residuals and the 2,133 closed optimizing canonical size losses
also remain open; baseline replay alone does not make them acceptable.
These classifications are review judgments, not harness conclusions.

Bounded Node-v2 replays attempt all 100 retained cases: 87 report all-equal
original/Starshine/v133 observations, 13 report `original-runtime-blocked`,
and none reports a semantic mismatch. Twelve blocked cases are portable
string-lane inputs and one is from closed DAE2-optimizing. They remain
unverified. The DFE profile exports no functions, so its 20 matching reports
do not demonstrate function-body execution. Runtime checks are off in the
50,000-case lanes.

### Native footprint limits

Two warmup processes and 11 measured processes per tool/input alternate tools
serially after builds and fuzzing stop, under the shared Moon and heavy-work
locks. The inputs have 10,000 dropped local reads inside a result block, which
forces the changed HOT MergeLocals path, and 2,000 final function types for
DAE2. The latter does not measure subtype-heavy artifacts. A native C `wait4`
helper excludes the Python launcher from child peak RSS. The first cohort's
Python-floor RSS values are retained but excluded from memory claims.

| Input / build | Pass median / MAD (us) | Pass range (us) | Peak RSS median / range (KiB) |
| --- | ---: | ---: | ---: |
| MergeLocals / baseline | 5,843 / 251 | 5,350–7,704 | 20,496 / 20,268–20,608 |
| MergeLocals / repaired | 5,855 / 239 | 5,374–7,155 | 20,448 / 20,248–20,696 |
| DAE2 / baseline | 927 / 20 | 860–966 | 11,556 / 11,420–11,692 |
| DAE2 / repaired | 945 / 21 | 920–1,225 | 11,512 / 11,336–11,732 |

Point medians add 0.2% and 1.9% pass time with overlapping spread and RSS
ranges. They do not prove a universal speed or memory gain. The v133 medians
are 2,098.1 and 282.25 us; these synthetic inputs do not close the existing
relative-speed goals. Native command size grows 5,280 bytes (15,571,704 to
15,576,984). Both benchmark outputs remain byte-identical to baseline, and
traced/plain output identity and stable output hashes pass. Baseline, repaired
and oracle benchmark calls return 2 and 42 as expected.

MergeLocals reuses existing source-order fields, maps and traversal. DAE2 adds
one linear type/parent read without new arrays. Table copies are lazy; DFE
canonical metadata maps are created only when field names exist. Those are
source-level allocation bounds. Whole-process RSS is not allocated-byte,
retained-heap or leak evidence. Compiler time, general artifacts, metadata
allocation volume and other architectures were not measured.


## October 19, 2026 — Pass review follow-up

This investigation starts at `b6e158590b9d02b531146fe6582d09e7a65fbc17`.
It is separate from the earlier October 19 repair record above. The
[follow-up evidence](../raw/tooling/2026-10-19-pass-review-follow-up.json)
records the reported correctness, metadata and performance leads, source
identities, bounded regressions, native measurements and review limits.
The final repository gate passes all 15,352 tests and all 14 CI fuzz suites.
Native CLI compilation and README/API synchronization also pass. Generated
comparisons and retained-case reviews are recorded separately below.

The exact baseline reproduces the DAE multi-value error: an ambient `1`, a
pair returning `5, 6`, and a constant-returning two-argument callee produce
`105` after DAE instead of `101`. Operand recovery now rejects lane overshoot
and uses one producer evaluation when it must retain selected lanes.
CodeFolding also had a reproducible effect-order error when a moved nested
exit invalidated a cached suffix. Cached tails now retain and check branch
identity. CoalesceLocals changes negative zero to positive zero on both
float widths in baseline execution; constant facts now preserve exact bits
and recognize only positive zero as a default value. These are confirmed
semantic defects, including the previously unconfirmed float concern.

Control repairs cover legacy try local indices and first-use order, typed
control entry operands, used If labels, delegate/catch/resume owner guards,
all dropped result lanes, and non-defaultable local initialization across
control frames. The shared HOT representation retains explicit scalar
entry producers and evaluates try entry operands before entering handlers.
The [architecture rule](../ir2/architecture-rules.md),
[Vacuum contract](../binaryen/passes/vacuum/starshine-hot-ir-strategy.md) and
[SSA contract](../binaryen/passes/ssa/starshine-strategy.md) describe these
invariants and their direct tests.

Metadata changes preserve field and local name ownership through index
changes and handle valid raw-only name sections. A malformed raw-only payload
does not stop the transform; changed output clears the stale cache and a no-op
retains the original. The initial guard that stopped these transforms failed
the existing StringGathering contract and was removed. Clearing compiler facts after a
transform is required by their ownership contract; preserving stale facts
is not a valid fix. Concrete function references remain in the function
type hierarchy, outside `any`.

Performance work targets shared analysis, unchanged-body checks, batched
rewrites, exact cache ownership, sparse query storage, type interning and
repeated control scans. Each family has before/after native controls, with
raw samples and build identities retained in the evidence record. A
source change alone does not establish a runtime or memory gain. Whole
process peak RSS does not establish allocation or retained heap savings.
Some reported scan counts were too broad; the final record distinguishes
measured improvements from rejected claims and unchanged required work.

The warmed instruction-query controls show one explicit tradeoff: a
1,024-deep effect query takes 22.78 to 24.11 us while requested bytes fall
from 4,312.5 to 228.5 per operation. Full-arena effect times overlap; deep
and small rethrow queries improve. This is evidence for bounded scratch
storage, not a claim that every query is faster.

Claude Code completed a limited baseline source review. Its later immutable
checkpoint review stopped at the session limit and returned no assessment.
The evidence records that incomplete scope separately from the completed
independent source checks; it does not claim a final Claude assessment.

The first local-proof index rebuilt a small instruction tree for each pair.
An equal-work allocator check exposed a 22-fold byte increase, so that
version was removed. The final index stores row starts and original
instruction offsets in two numeric arrays. It scans those rows directly.
The 512-pair path control improves 52.5-fold and adds 12,556 bytes for one
shared function index; 12,292 bytes are the two array payloads. Consume
allocation falls, and the small-local fallback keeps identical allocation.
The path control adds about 0.1 MiB peak RSS; this is not a general memory
reduction claim.

The full-pass Flatten control exposed a gap in the first helper-only
measurements: rebuilding ownership facts after each mutation still made the
512-control case slower. The final private proof keeps one ownership census
and a complete prefix bound for a restricted operand tree. Matching native
full-pass samples improve from 89,090 to 1,093 us; requested pass bytes fall
from 101,925,244 to 799,592. Doubling controls from 256 to 512 now doubles time
and requested bytes. These controls compare the prior tested native checkpoint
with the final Flatten source under the same common sources.

That change adds 24 bytes of cold state per function and 940 KiB of focused
process peak RSS. It adds no graph arrays. Generic fallback and root insertion
can still have quadratic worst cases; the result is not a universal complexity
or memory claim. The [raw record](../raw/tooling/2026-10-19-pass-review-follow-up.json)
contains 63 retained samples per side, allocator counts, all source/build
identities, exact encoded-byte checks and 36 matching runtime observations.

The final native CLI is `4aa2af1acc077a246e33f0fcecf8dbc52de16a38f1dcb2a98f77af5405e88d0a`.
Forty-eight complete-command controls use two warmups and seven alternating
samples for the original CLI, final CLI and verified Binaryen 133. Every command
and independent output validation succeeds. On the 512-control Flatten fixture,
original-to-final command time falls from 78.856 to 7.663 ms; Binaryen takes
5.848 ms. Whole-command peak RSS falls from 15,668 to 13,968 KiB on this fixture.
This does not supersede the focused pass process's 940 KiB RSS increase.

Seven critical CLI regressions match original execution. Eighty additional
Flatten observations compare original, baseline, final and Binaryen outputs,
including distinct nested entry values and import effect order. Node cannot
execute one Binaryen compact-import encoding. The runtime-only replay disables
that encoding and verifies that every non-import, non-custom section remains
byte-identical; the native timing samples retain the original oracle bytes.
These Flatten functions return zero; import arguments, call order and call
counts provide the additional runtime observations. Exact baseline/final
encoded bytes and direct IR tests supply separate value-preservation evidence.

Small controls do not all improve. CodeFolding's alternating small samples are
253 to 258 us, and its mixed samples are 279 to 259 us; the earlier grouped
27% small-case regression does not reproduce. Mixed CoalesceLocals takes 667
to 721 us. Complete SimplifyLocals controls remain near parity despite a faster
cleanup driver. The final CLI grows from 15,576,984 to 15,753,808 bytes (1.14%).
No original cold compiler-time measurement exists, so there is no compiler-time
gain claim.
Twenty of the 48 command medians are higher after the repairs; every such
before/after sample range overlaps. The evidence supports the stated pass
improvements and costs, not a uniform whole-pipeline speedup. Missing pass
timers remain unavailable measurements rather than zero-time results.

Representative native controls use matching harnesses and common sources.
These are fixture measurements, not complete-module speed guarantees:

| Path | Before → after, us | Scope |
| --- | ---: | --- |
| DAE, 256 rewritten calls | 477 → 126 | Batched callsite reconstruction |
| DAE, mutual-call analysis | 2,115 → 38.5 | Shared call-graph facts |
| Manager, tuple interning | 2,749 → 44 | Large type workspace; tiny control also measured |
| CodeFolding, 256 independent folds | 20,458 → 1,206 | Shared analysis and no full restart |
| Instruction purity queries | 346 → 12.6 | Revision-owned query memo |
| Flatten, 512 tuple controls | 89,090 → 1,093 | Full pass; restricted ownership proof |
| CoalesceLocals, 512 pair proofs | 2,041 → 38.9 | Shared numeric index; extra bytes stated above |
| GlobalStructInference, 256 distinct wrappers | 63,532 → 94.7 | Strong buckets; recursive cases retain exact fallback |
| Precompute, immutable heap reads | 201 → 5 | Cached initializer values |
| ReorderGlobals, equal-width candidates | 55.8 → 30.3 | Avoid repeated construction and byte buffers |

The raw record retains all samples, controls, allocator counts and source/build
identities, including neutral and adverse cases. Required semantic graph
rebuilds, dense interference storage and conservative control fallbacks remain;
the repairs do not remove their correctness requirements.

Final generated verification completes 250,000 comparisons in 25 lanes across
24 pass modes against verified Binaryen 133. There are 129,341 canonical
matches, 8,064 configured cleanup matches and 112,595 structural differences.
Validation, generator, property and command failures are zero. The required
`inlining-optimizing-all` aggregate matches all 10,000 cases with equal raw and
canonical sizes; its earlier general-profile run remains supplemental evidence.
These lanes have runtime checking off. They do not close complete pass parity.

All 400 retained differences reproduce byte-identical baseline outputs. Their
independent source reviews distinguish scoped wins from raw-size, canonical-size
and unverified gaps. Bounded Node-v2 replay matches original and Starshine in
351 cases: 245 have function invocation plans, recording 1,510 steps; 106 only
check compilation, instantiation and resources. Another 48 originals time out
at one second and one requires stack-switching support. Binaryen has 28 further
blocked observations from compact imports or custom descriptors. No Starshine
or Binaryen semantic mismatch is observed in these bounded replays. Every
runtime report is retained; blocked or unexecuted functions remain unverified.

Coverage limits remain explicit. The cast aggregate has a pre-existing
configuration defect: seven labels repeat the later-reuse body. Direct bounded
tests cover the repaired function-reference hierarchy. Each Precompute lane
repeats eleven fixed inputs. Ordinary GSI, GTO and StringGathering inputs contain
no GC or string targets; focused tests provide the metadata and type evidence.
Comparison counts therefore do not mean the same number of unique modules.
Known DAE localization costs, DAE2 canonical losses, mixed RUB/SSA raw-size
losses and ReorderGlobals import-order gaps remain open. General inlining also
has an open raw-byte gap despite canonical equality. The raw record owns exact
per-lane counts, family judgments, source hashes and supersession of earlier
pending replay statements.

## October 20, 2026 — Pin the qualified CI compiler

Master CI at `6d9aa96caacf4f5d9288c2a3220c1ab69418da8d` installed
Moon `0.1.20261016` and compiler/Core `0.10.16+b1a0e846e` through `latest`.
That compiler rejects the existing `Int.reinterpret_as_float` call and
`Result.is_ok`/`is_err` test calls. These compile failures block later artifact
checks. They are separate from the preceding pass review's qualified-toolchain
results.

The [shared setup action](../../../.github/actions/setup-moonbit/action.yml)
now requests the full release identifier `0.10.15+943464bfa` through the official
installer. It checks Moon `0.1.20261012 (748b63c 2026-10-12)`, compiler
`v0.10.15+943464bfa (2026-10-12)` and the matching Core version. All 11 Moon
setup steps in six workflows use this action. Both trigger filters in each of
the five filtered workflows watch action changes; Required CI has no path
filter. The [npm toolchain record](../../../ffi/src/npm/toolchain.json) and
[Core license guard](../../../scripts/lib/npm-licenses.mjs) retain their
qualified versions. A newer compiler requires separate qualification.

The full-identifier Linux x86_64 toolchain and Core archive URLs return HTTP
200. Downloaded `moon`, `moonc` and `moonrun` bytes match the qualified local
tools; all 1,200 Core archive files match. This supersedes the provisioning
limit in the [npm handoff](../../npm-beta-handoff.md#remaining-release-decisions).
Earlier HTTP 403 results remain historical evidence; date-only and short
version requests still return 403.

The [workflow contract](../../../scripts/test/ci-workflow-contract.ts) fails
before the pin and passes after it. Native-example and npm static contracts,
workflow/action YAML parsing and action shell syntax checks pass. Expanded
[float-bit parsing tests](../../../src/wast/scalar_nan_payload_wbtest.mbt)
pass all four cases on the qualified compiler. Current comparison jobs also
move from Binaryen 132 to verified 133, with separate red/green
[optimizer contract tests](../../../scripts/lib/ci-optimizer-gates.test.ts).
Counts, seeds, profiles, properties, normalizers and failure policy are
unchanged. Historical oracle results keep their recorded versions.

These local checks do not complete the repair. Fresh coverage reports 28,265
uncovered lines across 260 files, against the unchanged budget of 28,138 lines
across 196 files. The 127-line excess is an active blocker; bounded test repairs
remain in progress. Product-version, `moon info` and `moon fmt` checks pass.
The fresh `bun ffi check` exposed two missing generated IR exports,
`cache_swap_scalar_operands` and `effects_for_node_subtree`. Regeneration
updates their wrappers, names and schema; the check now passes with 4,377
exports. The npm declaration generator produces no further change. Independent
comparison confirms all 4,375 existing wrappers and schema entries are unchanged;
38 generator contract tests pass with Bun 1.4.2 and Node 25.8.1. Artifact/consumer
gates and the remote CI rerun remain pending. The [raw repair record](../raw/tooling/2026-10-20-master-ci.json)
keeps the failed runs, archive identities and red/green results.
Local evidence is retained outside production source under
`/tmp/starshine-master-ci-20261020/compiler/` and `workflows/`, including archive
identities, red/green logs and the independent workflow review.
