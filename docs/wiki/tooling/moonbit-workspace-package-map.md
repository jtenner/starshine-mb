---
kind: workflow
status: supported
last_reviewed: 2026-10-28
sources:
  - https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
  - https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html
  - https://docs.moonbitlang.com/en/latest/language/verification.html
  - https://moonbitlang.github.io/moon/commands.html
  - ../../../moon.mod
  - ../../../src/*/moon.pkg
  - ../../../src/spec_runner/imports.mbt
  - ../../../src/spec_runner/spec_runner.mbt
  - ../../../src/*/pkg.generated.mbti
  - ../raw/tooling/2026-10-27-moonbit-core-compatibility.json
related:
  - ./validation-gates.md
  - ./release-process.md
  - ./node-package-surface.md
  - ../validation/moonbit-prove-strategy.md
  - ../ir2/architecture-rules.md
  - ../../README.md
---

# MoonBit Workspace And Package Map

## Overview

Starshine is a MoonBit module named `jtenner/starshine`. The repo-wide module metadata lives in [`moon.mod`](../../../moon.mod), and package-local build metadata normally lives under `src/<package>/moon.pkg`. [`src/spec_runner`](../../../src/spec_runner/) contains legacy native spec-suite wrapper source and has no `moon.pkg`; it is not an active buildable package. The legacy `moon.mod.json` filename remains upstream/historical context, but it is not the live Starshine module file.

The beginner model is:

```text
moon.mod
  -> source = "src"
  -> most src/<package>/moon.pkg files declare imports and package options
  -> *.mbt files implement package code and tests beside it
  -> moon info refreshes pkg.generated.mbti public interfaces
  -> bun/moon validation gates check package, API, proof, and runtime entrypoints
```

The official MoonBit [module](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html) and [package](https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html) documentation distinguishes whole-module configuration from package configuration: module config describes the module, while package config owns `import { ... }`, aliases such as `@lib`, and `pkgtype(kind: "executable")` and `proof_enabled = true`. The live [`moon.mod`](../../../moon.mod), package files are the repository evidence for the current filename and package configuration.

## Module-Level Contract

[`moon.mod`](../../../moon.mod) currently says:

| Field | Current Starshine value | Maintenance meaning |
| --- | --- | --- |
| `name` | `jtenner/starshine` | Prefix used by intra-repo imports such as `jtenner/starshine/lib`. |
| `source` | `src` | Packages are discovered under `src/`; do not add production packages outside that tree without a module-schema update. |
| `import` | `moonbitlang/x` `0.5.1` | External module dependency metadata. Core packages such as `moonbitlang/core/debug` still appear in package imports where needed. |
| `readme` | `README.md` | Public package readme metadata; keep API-sync docs pointed at this root. |
| `repository` | `https://github.com/jtenner/starshine-mb` | Repository metadata. |
| `license` | `Apache-2.0` | Module metadata, not per-package behavior. |
| `keywords` / `description` | WebAssembly-related keywords and toolkit description | Package-discovery metadata, not a substitute for the checked-in README or wiki release notes. |

The shared filesystem uses a local copy of `moonbitlang/x@0.5.1/fs` in
[`src/internal/xfs`](../../../src/internal/xfs/README.md), with six native
stream-cleanup fixes. The registry dependency still supplies Unicode conversion.
See [module input resource lifetime](module-input-resource-lifetime.md) for
ownership, regression proof and the measurement handoff.

Starshine does not currently set module-level `preferred-target` or `supported-targets`. Target-specific validation policy instead lives in [`validation-gates.md`](validation-gates.md), where the local full gate uses `bun validate full --profile ci --target wasm-gc`. Release-prep version synchronization between this module metadata and the Node package metadata lives in [`release-process.md`](release-process.md).

### MoonBit core compatibility

The 20261023 core removes integer-side `reinterpret_as_float` and the
deprecated `Result::is_ok` / `Result::is_err` methods. Use
`Float::reinterpret_from_uint(bits)` for unsigned f32 bit patterns,
`Float::reinterpret_from_int(bits)` for signed bit patterns, and
`result is Ok(_)` / `result is Err(_)` for result checks. The 20261012
core also supports these forms. The result patterns are the exact bodies
of the old deprecated methods; the float constructors use the same
`%i32.to_f32_reinterpret` intrinsic. These spelling changes add no
allocation, loop, or data copy, including in pass validation fallbacks
and `precompute_u64_to_f32`.

The original WAST error stops dependency compilation before the compiler
can check `passes` and `cmd`. A clean WAST package alone therefore does
not prove a clean workspace. Keep release builds for `wasm`, `wasm-gc`,
and `native`, plus tests for each changed package, in the compatibility
check. See [scalar payload construction](../wast/numeric-instruction-authoring.md)
and the implementations in [`precompute.mbt`](../../../src/passes/precompute.mbt),
[`global_effects.mbt`](../../../src/passes/global_effects.mbt), and
[`cmd.mbt`](../../../src/cmd/cmd.mbt).

On Linux, the 20261023 `moon test` launcher can exceed the argument-size
limit when it lists the large `passes` test package. Compile with
`--build-only`, then run the generated test drivers with small file/index
batches from their `__*_test_info.json` files. Preserve `#skip` exclusions,
exclude `with_bench_args_tests` from timing-free checks, and require a
completion record for every selected test. A launcher `Argument list too
long` error alone is not a failed project assertion.

The [2026-10-27 compatibility evidence](../raw/tooling/2026-10-27-moonbit-core-compatibility.json)
records successful 20261023 release builds for all three targets and 2,929
focused tests: 438 WAST, 2,304 pass, and 187 command tests on wasm-gc.
Benchmark entries and explicit skip attributes remain excluded. The shared
fleet installation now has the same compiler executable hashes as the tested
scratch installation. Old-toolchain builds were cancelled after that gate
was waived; dual compatibility is not a measured claim.

## Package-Level Contract

Each ordinary `src/<package>/moon.pkg` answers three questions:

1. **What does this package import?** Example: [`src/passes/moon.pkg`](../../../src/passes/moon.pkg) imports `binary`, `bitset`, `fs`, `ir`, `lib`, `validate`, and `wast` so pass code can use those APIs.
2. **Which aliases are available?** Example: [`src/binary/moon.pkg`](../../../src/binary/moon.pkg) imports `jtenner/starshine/lib` as `@lib`, and source files must use that alias consistently.
3. **Is there package-local behavior?** `pkgtype(kind: "executable")` marks executable entrypoints; `proof_enabled = true` opts a package into MoonBit proof support; link options configure wasm-level details for entrypoints.

Package imports are not optional documentation. If a source file starts using a new package alias, the owning `moon.pkg` must declare it. Conversely, removing an import should be paired with compile/test evidence, because stale or missing imports can break package-level builds independently of any wiki page. The legacy `src/spec_runner` source has an `imports.mbt` and a generated interface, but no `moon.pkg`. These files do not establish an active package.

## Current Package Families

### Core library and binary/text layers

| Package | Role | Important package facts |
| --- | --- | --- |
| [`src/lib`](../../../src/lib/) | Core Wasm module, type, instruction, and metadata model. | Minimal core dependencies; most other packages depend on it. |
| [`src/binary`](../../../src/binary/) | Wasm binary decode/encode and byte-level tests. | Imports `lib` as `@lib` and `validate` as `@validate`; binary well-formedness and validation remain separate concepts. |
| [`src/wast`](../../../src/wast/) | WAST parser/lowerer/printer/static harness surface. | Imports `binary`, `lib`, and `validate`; WAST authoring pages cite this package for text support. |
| [`src/wat`](../../../src/wat/) | Lower-level WAT support. | Used by fuzzing and text tooling where the high-level WAST package is not the whole story. |

### Optimizer and IR2 layers

| Package | Role | Important package facts |
| --- | --- | --- |
| [`src/ir`](../../../src/ir/) | Owned HOT function IR plus CFG, dominance, liveness, effects, loop info, use-def, and SSA overlays. | Imports `bitset`, `lib`, `validate`, and `wast`; architecture rules live in [`../ir2/architecture-rules.md`](../ir2/architecture-rules.md). |
| [`src/passes`](../../../src/passes/) | Pass registry, pass manager, shared pass helpers, hot/module passes, and preset expansion. | Imports `ir`, `binary`, `validate`, `wast`, and helper packages; CLI-visible pass truth comes from the live registry and tests. |
| [`src/passes_perf_long`](../../../src/passes_perf_long/) | Long pass-performance tests. | Keep heavy randomized or long perf checks out of ordinary `moon test` unless the package/test policy says otherwise. |

### Command, tooling, fuzzing, and validation layers

| Package | Role | Important package facts |
| --- | --- | --- |
| [`src/cli`](../../../src/cli/) | CLI parser/config/glob logic. | Library package; command dispatch is separate. |
| [`src/cmd`](../../../src/cmd/) | Main `starshine` command dispatcher. | `pkgtype(kind: "executable")` declares an executable; command behavior is documented in [`cli-command-and-dispatcher.md`](cli-command-and-dispatcher.md). |
| [`src/cmd_gc`](../../../src/cmd_gc/) | Wasm GC command with scalar bulk host I/O. | `supported_targets = "wasm-gc"`; exports linear memory; Node/Bun/Wago runners supply the protocol. |
| [`src/fuzz`](../../../src/fuzz/) | Main fuzzing runner and invalid-repro helpers. | `pkgtype(kind: "executable")`; imports binary, passes, fs, validate, WAST, and WAT surfaces. |
| [`src/validate`](../../../src/validate/) | Module validation, typechecking, valid/invalid generators, diagnostics. | `proof_enabled = true` and imports `validate_proof`; direct validator proving is policy-sensitive. |
| [`src/validate_proof`](../../../src/validate_proof/) | Small proof helper package. | `proof_enabled = true`; required proof lane is documented in [`../validation/moonbit-prove-strategy.md`](../validation/moonbit-prove-strategy.md). |
| [`src/validate_trace`](../../../src/validate_trace/) | Main validation-trace benchmark runner. | `pkgtype(kind: "executable")`; trace benchmark behavior lives in [`../validate/trace-benchmark-baseline.md`](../validate/trace-benchmark-baseline.md). |
| [`src/spec_runner`](../../../src/spec_runner/) | Legacy native/static WAST spec-suite wrapper source. | No `moon.pkg`; not an active buildable package. Spec semantics live in [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md). |
| [`src/cli-benchmarks`](../../../src/cli-benchmarks/) | Main CLI startup/runtime benchmark package. | `pkgtype(kind: "executable")`; use [`cli-startup-path.md`](cli-startup-path.md) for startup-cost follow-up. |
| [`src/binary_fuzz`](../../../src/binary_fuzz/), [`src/representation`](../../../src/representation/), [`src/rume`](../../../src/rume/), [`src/ffi_bridge`](../../../src/ffi_bridge/) | Binary fuzzing, representation metadata, optimizer support, and FFI bridge packages. | See each package configuration and generated interface for dependencies and public APIs. |
| [`src/daybreak19_measure`](../../../src/daybreak19_measure/), [`src/hot_identity_trace`](../../../src/hot_identity_trace/) | Measurement and IR tracing packages. | `hot_identity_trace` declares an executable. |
| [`src/fs`](../../../src/fs/), [`src/diff`](../../../src/diff/), [`src/bitset`](../../../src/bitset/) | Support packages. | Keep support-package public interfaces small and reviewed through `.mbti` diffs when they become shared APIs. |

## Generated Interfaces And Public API Drift

Checked-in `pkg.generated.mbti` files are the public interface snapshots reviewers should inspect after `moon info`. They are especially important when changing:

- Node-facing package APIs (`cli`, `cmd`, `validate`, `wast`) documented in [`node-package-surface.md`](node-package-surface.md);
- shared optimizer APIs in `ir` or `passes`;
- proof helpers exported by `validate_proof` and imported by `validate`;
- fuzz/validation helper constructors used across package boundaries.

Do not infer API stability from an implementation file alone. The normal quick-gate order remains `moon info`, `moon fmt`, then `moon test`, with broader `bun validate` lanes chosen by change kind.

## Main Packages Versus Library Packages

`pkgtype(kind: "executable")` marks an executable entrypoint, not a claim that the package is a stable library API. In the current tree:

- [`src/cmd/moon.pkg`](../../../src/cmd/moon.pkg) owns the `starshine` command path.
- [`src/cmd_gc/moon.pkg`](../../../src/cmd_gc/moon.pkg) owns the Wasm GC command.
- [`src/hot_identity_trace/moon.pkg`](../../../src/hot_identity_trace/moon.pkg) owns the HOT identity trace tool.
- [`src/fuzz/moon.pkg`](../../../src/fuzz/moon.pkg) owns the fuzz runner.
- [`src/validate_trace/moon.pkg`](../../../src/validate_trace/moon.pkg) owns validation trace benchmarks.
- [`src/spec_runner`](../../../src/spec_runner/) has legacy wrapper source with a `main`, but no `moon.pkg` to declare an executable package.
- [`src/cli-benchmarks/moon.pkg`](../../../src/cli-benchmarks/moon.pkg) owns CLI benchmark execution.

When docs discuss how users run something, link to the main package and its command wrapper. When docs discuss what other packages can import, cite `pkg.generated.mbti` and tests that consume the API.

## Proof-Enabled Packages

Proof support is package-local. The 2026-06-04 formal-verification refresh confirms that current MoonBit still gates verification through `proof-enabled` package configuration, with file-targeted proving assuming dependencies rather than replacing package-boundary policy. Starshine currently has two proof-enabled packages:

- [`src/validate_proof/moon.pkg`](../../../src/validate_proof/moon.pkg), the small helper package used by the required `moon prove src/validate_proof` lane;
- [`src/validate/moon.pkg`](../../../src/validate/moon.pkg), the broader validator package, where direct proving remains optional/policy-sensitive.

Use [`../validation/moonbit-prove-strategy.md`](../validation/moonbit-prove-strategy.md) for the trust model: exported proof helpers, live imports into the validator, file-target assurance boundaries, and proof-command availability are separate facts.

## Maintenance Checklist

When adding or reshaping a package:

1. Add or update `src/<package>/moon.pkg` first: imports, aliases, executable kind, proof, and link options belong there. Do not copy the legacy `spec_runner` `imports.mbt` into new packages.
2. Add implementation and package-local tests beside the code.
3. Run `moon info` so `pkg.generated.mbti` drift is visible, then review the `.mbti` diff for public API changes. If the change is release-prep work, also verify the version and package-surface checklist in [`release-process.md`](release-process.md).
4. Run `moon fmt`; expect `moon.pkg` formatting to be normalized.
5. Run focused `moon test src/<package>` plus the normal wiki/validation gate for the change kind.
6. Update this page, [`validation-gates.md`](validation-gates.md), Node/package docs, proof docs, or IR2/pass docs when package topology affects how developers build, import, run, or validate the repo.

## Common Mistakes

- **Mistaking `imports.mbt` for dependency configuration.** It can collect implementation imports, but `moon.pkg` is still the normal package dependency and alias source. `src/spec_runner/imports.mbt` belongs to legacy source and does not define an active package.
- **Forgetting `.mbti` review.** A behavior-only change can still alter a public constructor, enum, helper, or generated interface.
- **Treating main packages as stable libraries.** Entrypoints can be runnable without being Node-exposed or suitable for downstream import.
- **Assuming proof enablement is global.** It is package-local and should be cited per package.
- **Adding pass or CLI behavior without updating package-level docs.** New dependencies, public APIs, or entrypoint behavior should refresh package map, command docs, and validation-gate docs together.

## Sources

- Official MoonBit [module configuration](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html), [package configuration](https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html), [formal verification](https://docs.moonbitlang.com/en/latest/language/verification.html), and [command manual](https://moonbitlang.github.io/moon/commands.html).
- Module config: [`../../../moon.mod`](../../../moon.mod)
- Package configs: [`../../../src/binary/moon.pkg`](../../../src/binary/moon.pkg), [`../../../src/cli/moon.pkg`](../../../src/cli/moon.pkg), [`../../../src/cmd/moon.pkg`](../../../src/cmd/moon.pkg), [`../../../src/fuzz/moon.pkg`](../../../src/fuzz/moon.pkg), [`../../../src/ir/moon.pkg`](../../../src/ir/moon.pkg), [`../../../src/lib/moon.pkg`](../../../src/lib/moon.pkg), [`../../../src/passes/moon.pkg`](../../../src/passes/moon.pkg), [`../../../src/validate/moon.pkg`](../../../src/validate/moon.pkg), [`../../../src/validate_proof/moon.pkg`](../../../src/validate_proof/moon.pkg), [`../../../src/validate_trace/moon.pkg`](../../../src/validate_trace/moon.pkg), [`../../../src/wast/moon.pkg`](../../../src/wast/moon.pkg); legacy source files: [`../../../src/spec_runner/imports.mbt`](../../../src/spec_runner/imports.mbt), [`../../../src/spec_runner/spec_runner.mbt`](../../../src/spec_runner/spec_runner.mbt), [`../../../src/spec_runner/pkg.generated.mbti`](../../../src/spec_runner/pkg.generated.mbti)
