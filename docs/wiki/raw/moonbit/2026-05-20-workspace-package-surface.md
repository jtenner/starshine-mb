# MoonBit Workspace And Package Surface Refresh

_Status:_ immutable source manifest for [`docs/wiki/tooling/moonbit-workspace-package-map.md`](../../tooling/moonbit-workspace-package-map.md)
_Captured:_ 2026-05-20

## Why this refresh exists

Starshine already had focused MoonBit source captures for validation commands and formal proof setup, but no living page explained how the repo's MoonBit module, package directories, imports, generated interfaces, main packages, and proof-enabled packages fit together. This manifest records the current official MoonBit package/source rules plus the Starshine-local package configuration evidence so future wiki updates do not have to infer workspace behavior from `AGENTS.md`, scattered `moon.pkg` files, and validation-gate notes.

## Official MoonBit sources checked

- MoonBit module configuration, current English docs: <https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html>
  - `moon.mod.json` / `moon.mod` identifies and describes a module.
  - `source` selects the module source directory; Starshine sets it to `src`.
  - `deps` declares module dependencies; Starshine currently depends on `moonbitlang/x` `0.4.40`.
  - `preferred-target` / `supported-targets` are metadata/default-target controls; Starshine does not currently set either at module level.
- MoonBit package configuration, current English docs: <https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html>
  - `moon.pkg` is the new concise package DSL; `moon.pkg.json` remains the legacy format.
  - Ordinary dependencies belong in `import { ... }`; custom aliases use `@alias` and are then referenced as `@alias` in source.
  - Most core subpackages still need explicit imports when used through an alias such as `@json`; only the prelude is implicit.
  - `options("is-main": true)` marks an executable/linkable package.
  - Link options such as wasm export/import-memory settings belong under `options(link: ...)`.
- MoonBit formal verification docs, current English docs: <https://docs.moonbitlang.com/en/latest/language/verification.html>
  - Proof support is package-local: each package that carries proof-oriented code must enable it in `moon.pkg`.
  - Proof packages can contain ordinary `.mbt` code plus proof-oriented `.mbtp` files.

## Starshine repository evidence checked

### Module root

- [`moon.mod.json`](../../../../moon.mod.json)
  - module name: `jtenner/starshine`
  - version: `0.1.0`
  - source root: `src`
  - dependency: `moonbitlang/x` `0.4.40`
  - readme metadata: `README.mbt.md`
  - license metadata: `Apache-2.0`

### Package configuration files under `src/`

Directories with `moon.pkg` in the current tree:

- [`src/binary/moon.pkg`](../../../../src/binary/moon.pkg) imports `lib`, `validate`, buffer/UTF-8/list/quickcheck helpers.
- [`src/bitset/moon.pkg`](../../../../src/bitset/moon.pkg) is a small support package.
- [`src/cli/moon.pkg`](../../../../src/cli/moon.pkg) imports core `set`, `hashmap`, and `debug`.
- [`src/cli-benchmarks/moon.pkg`](../../../../src/cli-benchmarks/moon.pkg) is a main benchmark package.
- [`src/cmd/moon.pkg`](../../../../src/cmd/moon.pkg) is the main command package with CLI, fs, passes, binary, validation, WAST, and config/runtime imports plus wasm memory-export link metadata.
- [`src/diff/moon.pkg`](../../../../src/diff/moon.pkg) is the diff support package.
- [`src/fs/moon.pkg`](../../../../src/fs/moon.pkg) is the host filesystem abstraction package.
- [`src/fuzz/moon.pkg`](../../../../src/fuzz/moon.pkg) is a main package importing binary, passes, fs, validate, WAST, and WAT support.
- [`src/ir/moon.pkg`](../../../../src/ir/moon.pkg) imports bitset, lib, validate, WAST, and float/core helpers for HOT IR and analyses.
- [`src/lib/moon.pkg`](../../../../src/lib/moon.pkg) is the core module-model package and imports only core support packages.
- [`src/passes/moon.pkg`](../../../../src/passes/moon.pkg) imports binary, bitset, fs, IR, lib, validate, WAST, and core buffer/hashmap/debug helpers.
- [`src/passes_perf_long/moon.pkg`](../../../../src/passes_perf_long/moon.pkg) holds long-running pass performance tests.
- [`src/validate/moon.pkg`](../../../../src/validate/moon.pkg) is proof-enabled and imports bitset, lib, `validate_proof`, and quickcheck splitmix support.
- [`src/validate_proof/moon.pkg`](../../../../src/validate_proof/moon.pkg) is proof-enabled and imports core debug only.
- [`src/validate_trace/moon.pkg`](../../../../src/validate_trace/moon.pkg) is a main validation-trace runner.
- [`src/wast/moon.pkg`](../../../../src/wast/moon.pkg) imports binary, lib, validate, and parser/printer support packages.
- [`src/wat/moon.pkg`](../../../../src/wat/moon.pkg) is the lower-level WAT package.

### Generated interfaces and import sidecars

- Checked-in `pkg.generated.mbti` files exist for the active public surfaces under `src/*/pkg.generated.mbti`, including CLI, command, validation, WAST, Node-facing packages, IR, and passes. Use `moon info` before reviewing public API drift, as described in [`../../tooling/validation-gates.md`](../../tooling/validation-gates.md) and the Moon CLI source refreshes.
- Some packages also have `imports.mbt` files that re-export or alias dependencies for implementation convenience. These do not replace `moon.pkg` imports; the package config still controls build dependencies.

## Durable wiki implications

- New Starshine packages should be introduced by adding a `src/<pkg>/moon.pkg` import/options file first, then package code, tests, and generated-interface evidence.
- When a source file starts using `@alias.foo`, the owning `moon.pkg` must import the package with that alias unless the name comes from the prelude.
- Main packages are operational entrypoints (`cmd`, `fuzz`, `validate_trace`, `cli-benchmarks`), not general library APIs. User-facing Node/package API claims should cite `pkg.generated.mbti` and wrapper/export evidence, not only `is-main` status.
- Proof-enabled status is package-local. Starshine currently enables proofs in `validate` and `validate_proof`; the required proof lane remains focused on `validate_proof` unless repo policy changes.
- `moon fmt` can rewrite `moon.pkg` formatting, and `moon info` can refresh `.mbti` surfaces. Keep validation-gate docs and this workspace map in sync if command behavior or package metadata changes.

## Open questions and caveats

- This manifest does not certify every generated interface as current. It records the package/source map and points public-API validation to `moon info` / README sync gates.
- This manifest does not decide whether all historical package directories should remain active forever. It records the current tree so future additions/removals can update one living map instead of scattering package-shape claims across pass, CLI, validation, and Node pages.
