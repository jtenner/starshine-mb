---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-06-04
sources:
  - https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
  - https://docs.moonbitlang.com/en/latest/language/packages.html
  - ../../../../moon.mod
  - ../../../../src/spec_runner/imports.mbt
  - ../../../../src/spec_runner/spec_runner.mbt
  - ../../../../src/spec_runner/pkg.generated.mbti
  - ../../../../src/cmd/moon.pkg
  - ../../../../src/wast/moon.pkg
related:
  - ../../tooling/moonbit-workspace-package-map.md
  - ../../tooling/node-package-surface.md
  - ../../wast/static-assertion-harness.md
---

# Spec Runner Package Topology Recheck - 2026-06-04

## Why this note exists

The living package map described the active Starshine package set but did not give `src/spec_runner` a row. That omission was easy to miss because `spec_runner` is still an active MoonBit package with a generated interface and native `main`, while it is also the one current `src/` package that does not have a `moon.pkg` file. This note records the source evidence so package-topology docs can describe the exception without weakening the normal `moon.pkg` rule.

## Source refresh

Checked on 2026-06-04:

- The official MoonBit module-configuration page treats `moon.mod` as the current module file format and says `options(source: "src")` makes `src` the module source directory.
- The official package guide says MoonBit code is organized into packages; packages have a package configuration file in the current `moon.pkg` format or the legacy `moon.pkg.json` format, package dependencies are normally declared by the package-file `import` field, and main packages are distinguished from library packages by `main`/`is-main` behavior.
- Starshine's root [`moon.mod`](../../../../moon.mod) uses `options(source: "src")`, so `src/spec_runner` is part of the current source tree.
- `src/spec_runner` currently contains [`imports.mbt`](../../../../src/spec_runner/imports.mbt), [`spec_runner.mbt`](../../../../src/spec_runner/spec_runner.mbt), and [`pkg.generated.mbti`](../../../../src/spec_runner/pkg.generated.mbti), but no `moon.pkg` file.
- The generated interface identifies the package as `jtenner/starshine/spec_runner`; the implementation imports `@wast`, `@fs`, and `@wasi` through `imports.mbt` and defines a native CLI-style `main` that runs the WAST spec-suite harness.

## Durable conclusions

1. Treat `spec_runner` as an active Starshine package and CLI/helper surface, not as a Node-public package and not as a normal `moon.pkg`-configured package.
2. Keep the normal maintenance rule that new or reshaped packages should use `moon.pkg` for imports, aliases, options, and link settings; `spec_runner` is a documented legacy/imports-only exception until a separate conversion lands.
3. When citing spec-suite behavior, continue routing semantics through [`../../wast/static-assertion-harness.md`](../../wast/static-assertion-harness.md); the package-topology fact only explains where the native wrapper lives.
4. If `spec_runner` is converted to `moon.pkg`, update the package map, Node surface caveat, this raw manifest's supersession status, and the ordinary package-maintenance checklist together.

## Links checked

- MoonBit module configuration: <https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html>
- MoonBit package guide: <https://docs.moonbitlang.com/en/latest/language/packages.html>
- Starshine module file: [`../../../../moon.mod`](../../../../moon.mod)
- Spec runner package files: [`../../../../src/spec_runner/imports.mbt`](../../../../src/spec_runner/imports.mbt), [`../../../../src/spec_runner/spec_runner.mbt`](../../../../src/spec_runner/spec_runner.mbt), [`../../../../src/spec_runner/pkg.generated.mbti`](../../../../src/spec_runner/pkg.generated.mbti)
