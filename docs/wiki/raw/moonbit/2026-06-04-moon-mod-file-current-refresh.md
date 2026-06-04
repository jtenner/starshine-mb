---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-06-04
sources:
  - https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
  - https://docs.moonbitlang.com/en/latest/language/packages.html
  - ../../../../moon.mod
  - ../../../../src/binary/moon.pkg
  - ../../../../src/cmd/moon.pkg
  - ../../../../src/validate/moon.pkg
  - ../../../../src/validate_proof/moon.pkg
  - ../../../../AGENTS.md
  - ../../../README.md
related:
  - ../../tooling/moonbit-workspace-package-map.md
  - ../../tooling/release-process.md
  - ../../tooling/validation-gates.md
---

# MoonBit Module File Current Refresh - 2026-06-04

## Why this note exists

Several living wiki pages and repo-policy snippets still routed Starshine's module metadata through `moon.mod.json`. The current repository root has `moon.mod`, not `moon.mod.json`, and the official MoonBit module-configuration page now explicitly distinguishes the legacy JSON format from the newer `moon.mod` format. This note is the source bridge for correcting Starshine-local links and release/package guidance without rewriting older raw manifests.

## Source refresh

Checked on 2026-06-04:

- The official MoonBit module-configuration page says Moon uses a module file to identify and describe a module; `moon.mod.json` is the legacy format and `moon.mod` is the new format.
- The same page gives paired examples for `moon.mod` and `moon.mod.json`, including `name`, `version`, `import { ... }`, `readme`, `license`, `supported_targets`, and `options(source: "src")`.
- The package guide still contains legacy-oriented wording that says a project has a single `moon.mod.json` configuration file, while the same section already names `moon.pkg` as the non-JSON package file with `moon.pkg.json` as legacy. Treat the module-configuration page as the more precise current source for filename policy.
- Starshine's current root module file is `moon.mod`; no `moon.mod.json` exists at the repository root in this worktree.
- Starshine's package-local metadata still lives in `src/<package>/moon.pkg` files.

## Starshine local evidence

`moon.mod` currently declares:

```text
name = "jtenner/starshine"
version = "0.1.0"
import { "moonbitlang/x@0.4.40" }
readme = "README.mbt.md"
repository = ""
license = "Apache-2.0"
keywords = [ ]
description = ""
warnings = "-deprecated"
options(source: "src")
```

Representative package files such as `src/binary/moon.pkg`, `src/cmd/moon.pkg`, `src/validate/moon.pkg`, and `src/validate_proof/moon.pkg` keep package imports/options out of the module file. That split remains the same conceptual contract the wiki already documented; only the root module filename needed correction for the current tree.

## Durable conclusions

1. Current Starshine docs should link to `moon.mod` for repo-local module metadata, release version synchronization, and validation-gate package topology.
2. `moon.mod.json` remains useful as legacy-format context in upstream MoonBit docs and historical raw-source notes, but it is not the live Starshine module file.
3. Do not rewrite older raw manifests solely to hide the stale filename. When living pages need current behavior, cite this refresh and the live `moon.mod` path.
4. If code, CI workflows, or future tooling still use `moon.mod.json` as a root sentinel or path filter, treat that as implementation/tooling debt separate from the wiki filename correction; do not cite those references as current package-schema truth.

## Links checked

- MoonBit module configuration: <https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html>
- MoonBit packages guide: <https://docs.moonbitlang.com/en/latest/language/packages.html>
- Starshine module file: [`../../../../moon.mod`](../../../../moon.mod)
- Representative package files: [`../../../../src/binary/moon.pkg`](../../../../src/binary/moon.pkg), [`../../../../src/cmd/moon.pkg`](../../../../src/cmd/moon.pkg), [`../../../../src/validate/moon.pkg`](../../../../src/validate/moon.pkg), [`../../../../src/validate_proof/moon.pkg`](../../../../src/validate_proof/moon.pkg)
