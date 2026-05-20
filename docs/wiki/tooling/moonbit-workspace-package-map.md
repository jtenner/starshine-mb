---
kind: workflow
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/moonbit/2026-05-20-workspace-package-surface.md
  - ../raw/moonbit/2026-05-20-moon-cli-command-manual-refresh.md
  - ../raw/moonbit/2026-05-20-formal-verification-command-and-trust-refresh.md
  - ../../../moon.mod.json
  - ../../../src/*/moon.pkg
  - ../../../src/*/pkg.generated.mbti
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

Starshine is a MoonBit module named `jtenner/starshine`. The repo-wide module metadata lives in [`moon.mod.json`](../../../moon.mod.json), and package-local build metadata lives under `src/<package>/moon.pkg`.

The beginner model is:

```text
moon.mod.json
  -> source = "src"
  -> src/<package>/moon.pkg declares imports and package options
  -> *.mbt files implement package code and tests beside it
  -> moon info refreshes pkg.generated.mbti public interfaces
  -> bun/moon validation gates check package, API, proof, and runtime entrypoints
```

The official MoonBit package documentation distinguishes the module file from package files: module config describes the whole module, while package config owns `import { ... }`, aliases such as `@lib`, and `options(...)` such as `"is-main"` or `"proof-enabled"`. The current source capture is [`../raw/moonbit/2026-05-20-workspace-package-surface.md`](../raw/moonbit/2026-05-20-workspace-package-surface.md).

## Module-Level Contract

[`moon.mod.json`](../../../moon.mod.json) currently says:

| Field | Current Starshine value | Maintenance meaning |
| --- | --- | --- |
| `name` | `jtenner/starshine` | Prefix used by intra-repo imports such as `jtenner/starshine/lib`. |
| `source` | `src` | Packages are discovered under `src/`; do not add production packages outside that tree without a module-schema update. |
| `deps` | `moonbitlang/x` `0.4.40` | External module dependency metadata. Core packages such as `moonbitlang/core/debug` still appear in package imports where needed. |
| `readme` | `README.mbt.md` | Public package readme metadata; keep API-sync docs pointed at this root. |
| `license` | `Apache-2.0` | Module metadata, not per-package behavior. |

Starshine does not currently set module-level `preferred-target` or `supported-targets`. Target-specific validation policy instead lives in [`validation-gates.md`](validation-gates.md), where the local full gate uses `bun validate full --profile ci --target wasm-gc`. Release-prep version synchronization between this module metadata and the Node package metadata lives in [`release-process.md`](release-process.md).

## Package-Level Contract

Each `src/<package>/moon.pkg` answers three questions:

1. **What does this package import?** Example: [`src/passes/moon.pkg`](../../../src/passes/moon.pkg) imports `binary`, `bitset`, `fs`, `ir`, `lib`, `validate`, and `wast` so pass code can use those APIs.
2. **Which aliases are available?** Example: [`src/binary/moon.pkg`](../../../src/binary/moon.pkg) imports `jtenner/starshine/lib` as `@lib`, and source files must use that alias consistently.
3. **Is there package-local behavior?** `options("is-main": true)` marks executable entrypoints; `options("proof-enabled": true)` opts a package into MoonBit proof support; link options configure wasm-level details for entrypoints.

Package imports are not optional documentation. If a source file starts using a new package alias, the owning `moon.pkg` must declare it. Conversely, removing an import should be paired with compile/test evidence, because stale or missing imports can break package-level builds independently of any wiki page.

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
| [`src/cmd`](../../../src/cmd/) | Main `starshine` command dispatcher. | `options("is-main": true)` plus wasm memory-export link metadata; command behavior is documented in [`cli-command-and-dispatcher.md`](cli-command-and-dispatcher.md). |
| [`src/fuzz`](../../../src/fuzz/) | Main fuzzing runner and invalid-repro helpers. | `options("is-main": true)`; imports binary, passes, fs, validate, WAST, and WAT surfaces. |
| [`src/validate`](../../../src/validate/) | Module validation, typechecking, valid/invalid generators, diagnostics. | `options("proof-enabled": true)` and imports `validate_proof`; direct validator proving is policy-sensitive. |
| [`src/validate_proof`](../../../src/validate_proof/) | Small proof helper package. | `options("proof-enabled": true)`; required proof lane is documented in [`../validation/moonbit-prove-strategy.md`](../validation/moonbit-prove-strategy.md). |
| [`src/validate_trace`](../../../src/validate_trace/) | Main validation-trace benchmark runner. | `options("is-main": true)`; trace benchmark behavior lives in [`../validate/trace-benchmark-baseline.md`](../validate/trace-benchmark-baseline.md). |
| [`src/cli-benchmarks`](../../../src/cli-benchmarks/) | Main CLI startup/runtime benchmark package. | `options("is-main": true)`; use [`cli-startup-path.md`](cli-startup-path.md) for startup-cost follow-up. |
| [`src/fs`](../../../src/fs/), [`src/diff`](../../../src/diff/), [`src/bitset`](../../../src/bitset/) | Support packages. | Keep support-package public interfaces small and reviewed through `.mbti` diffs when they become shared APIs. |

## Generated Interfaces And Public API Drift

Checked-in `pkg.generated.mbti` files are the public interface snapshots reviewers should inspect after `moon info`. They are especially important when changing:

- Node-facing package APIs (`cli`, `cmd`, `validate`, `wast`) documented in [`node-package-surface.md`](node-package-surface.md);
- shared optimizer APIs in `ir` or `passes`;
- proof helpers exported by `validate_proof` and imported by `validate`;
- fuzz/validation helper constructors used across package boundaries.

Do not infer API stability from an implementation file alone. The normal quick-gate order remains `moon info`, `moon fmt`, then `moon test`, with broader `bun validate` lanes chosen by change kind.

## Main Packages Versus Library Packages

`options("is-main": true)` marks an executable entrypoint, not a claim that the package is a stable library API. In the current tree:

- [`src/cmd/moon.pkg`](../../../src/cmd/moon.pkg) owns the `starshine` command path.
- [`src/fuzz/moon.pkg`](../../../src/fuzz/moon.pkg) owns the fuzz runner.
- [`src/validate_trace/moon.pkg`](../../../src/validate_trace/moon.pkg) owns validation trace benchmarks.
- [`src/cli-benchmarks/moon.pkg`](../../../src/cli-benchmarks/moon.pkg) owns CLI benchmark execution.

When docs discuss how users run something, link to the main package and its command wrapper. When docs discuss what other packages can import, cite `pkg.generated.mbti` and tests that consume the API.

## Proof-Enabled Packages

Proof support is package-local. Starshine currently has two proof-enabled packages:

- [`src/validate_proof/moon.pkg`](../../../src/validate_proof/moon.pkg), the small helper package used by the required `moon prove src/validate_proof` lane;
- [`src/validate/moon.pkg`](../../../src/validate/moon.pkg), the broader validator package, where direct proving remains optional/policy-sensitive.

Use [`../validation/moonbit-prove-strategy.md`](../validation/moonbit-prove-strategy.md) for the trust model: exported proof helpers, live imports into the validator, and proof-command availability are separate facts.

## Maintenance Checklist

When adding or reshaping a package:

1. Add or update `src/<package>/moon.pkg` first: imports, aliases, `is-main`, proof, and link options belong there.
2. Add implementation and package-local tests beside the code.
3. Run `moon info` so `pkg.generated.mbti` drift is visible, then review the `.mbti` diff for public API changes. If the change is release-prep work, also verify the version and package-surface checklist in [`release-process.md`](release-process.md).
4. Run `moon fmt`; expect `moon.pkg` formatting to be normalized.
5. Run focused `moon test src/<package>` plus the normal wiki/validation gate for the change kind.
6. Update this page, [`validation-gates.md`](validation-gates.md), Node/package docs, proof docs, or IR2/pass docs when package topology affects how developers build, import, run, or validate the repo.

## Common Mistakes

- **Mistaking `imports.mbt` for dependency configuration.** It can collect implementation imports, but `moon.pkg` is still the package dependency and alias source.
- **Forgetting `.mbti` review.** A behavior-only change can still alter a public constructor, enum, helper, or generated interface.
- **Treating main packages as stable libraries.** Entrypoints can be runnable without being Node-exposed or suitable for downstream import.
- **Assuming proof enablement is global.** It is package-local and should be cited per package.
- **Adding pass or CLI behavior without updating package-level docs.** New dependencies, public APIs, or entrypoint behavior should refresh package map, command docs, and validation-gate docs together.

## Sources

- Source manifest: [`../raw/moonbit/2026-05-20-workspace-package-surface.md`](../raw/moonbit/2026-05-20-workspace-package-surface.md)
- Moon CLI command-source refresh: [`../raw/moonbit/2026-05-20-moon-cli-command-manual-refresh.md`](../raw/moonbit/2026-05-20-moon-cli-command-manual-refresh.md)
- Proof command/trust refresh: [`../raw/moonbit/2026-05-20-formal-verification-command-and-trust-refresh.md`](../raw/moonbit/2026-05-20-formal-verification-command-and-trust-refresh.md)
- Module config: [`../../../moon.mod.json`](../../../moon.mod.json)
- Package configs: [`../../../src/binary/moon.pkg`](../../../src/binary/moon.pkg), [`../../../src/cli/moon.pkg`](../../../src/cli/moon.pkg), [`../../../src/cmd/moon.pkg`](../../../src/cmd/moon.pkg), [`../../../src/fuzz/moon.pkg`](../../../src/fuzz/moon.pkg), [`../../../src/ir/moon.pkg`](../../../src/ir/moon.pkg), [`../../../src/lib/moon.pkg`](../../../src/lib/moon.pkg), [`../../../src/passes/moon.pkg`](../../../src/passes/moon.pkg), [`../../../src/validate/moon.pkg`](../../../src/validate/moon.pkg), [`../../../src/validate_proof/moon.pkg`](../../../src/validate_proof/moon.pkg), [`../../../src/validate_trace/moon.pkg`](../../../src/validate_trace/moon.pkg), [`../../../src/wast/moon.pkg`](../../../src/wast/moon.pkg)
