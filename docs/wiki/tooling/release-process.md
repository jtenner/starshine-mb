---
kind: workflow
status: supported
last_reviewed: 2026-10-10
sources:
  - https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
  - https://docs.npmjs.com/cli/v11/configuring-npm/package-json
  - https://docs.npmjs.com/cli/v11/commands/npm-pack
  - https://docs.npmjs.com/cli/v11/commands/npm-publish
  - https://docs.npmjs.com/cli/v11/using-npm/scripts#life-cycle-scripts
  - https://docs.npmjs.com/trusted-publishers
  - https://docs.npmjs.com/generating-provenance-statements
  - https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
  - ../../../AGENTS.md
  - ../../README.md
  - ../../../moon.mod
  - ../../../node/package.json
  - ../../../node/README.md
  - ../../../node/internal/.gitignore
  - ../../../node/internal/.npmignore
  - ../../../package.json
  - ../../../scripts/lib/validate-task.ts
  - ../../../scripts/lib/build-node-package.mjs
  - ../../../scripts/lib/generate-node-package.mjs
  - ../../../.github/workflows/node-wasm-tests.yml
  - ../../../.github/workflows/fuzz.yml
  - ../../../.github/workflows/readme-api-sync.yml
related:
  - ./wasi-runner-and-preview-boundary.md
  - ./validation-gates.md
  - ./moonbit-workspace-package-map.md
  - ./node-package-surface.md
  - ./cli-command-and-dispatcher.md
  - ./pass-fuzz-compare.md
  - ../validate/trace-benchmark-baseline.md
  - ../validation/moonbit-prove-strategy.md
---

# Release Process

## Overview

Use this page when preparing a Starshine release, reviewing a release-prep branch, or deciding whether a change is release-blocking. It turns the compact repo policy in [`AGENTS.md`](../../../AGENTS.md) and [`docs/README.md`](../../README.md) into a concrete checklist with package-surface, validation, release-notes, and publication boundaries.

A Starshine release is not just “run tests and publish npm.” The current repo has several distinct surfaces:

1. **MoonBit module metadata** in [`moon.mod`](../../../moon.mod), currently `jtenner/starshine` at candidate version `0.1.2-beta.0`.
2. **Node/npm package metadata** in [`node/package.json`](../../../node/package.json), currently `@jtenner/starshine` at candidate version `0.1.2-beta.0`.
3. **Checked-in public API snapshots** through `src/*/pkg.generated.mbti`, especially for packages exposed through the Node boundary.
4. **The runnable CLI and Node package artifacts**, including `node/internal/starshine.wasm-wasi.wasm`, the required wasm-gc adapter package artifact, JS/TS wrappers, and `node/package.json#exports`.
5. **Durable release evidence** in wiki pages, [`docs/wiki/log.md`](../log.md), raw/research notes, release notes, validation artifacts, and git history.

The release package surface is grounded directly in the live [`moon.mod`](../../../moon.mod), [`node/package.json`](../../../node/package.json), root [`package.json`](../../../package.json), Node build scripts, and current package/test workflows, alongside the official npm and MoonBit documentation listed below. [`moon.mod`](../../../moon.mod) and official [MoonBit module configuration](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html) establish the current module-file format.

Starshine now has repository metadata, an explicit beta dist-tag and a tested source-to-tarball build. It has no checked-in publication workflow or `id-token: write` publication job. Registry-side trusted-publisher configuration remains unverified and requires a release decision. The checked-in package, fuzz and README workflows validate source with `contents: read` permissions and perform no publication. The root MIT / MoonBit Apache-2.0 license conflict must also be reconciled before registry publication; the npm candidate has no silently selected license.

For releases that include an already-built self-optimized CLI artifact, treat that artifact as a separate release surface. Use the dedicated `bun validate self-opt-smoke` / `bun validate self-opt-full` gate from [`validation-gates.md`](validation-gates.md) so artifact safety stays explicit instead of being inferred from the ordinary repo validation ladder.

## Release Surface Matrix

| Surface | Current owner | Release decision |
| --- | --- | --- |
| MoonBit product metadata | [`moon.mod`](../../../moon.mod) | Bump `version` for a Starshine release; this is the current module-file format, not `moon.mod.json`. |
| npm product metadata and public entry points | [`node/package.json`](../../../node/package.json) | Bump `version` with `moon.mod`; review `exports`, `files`, `bin`, `engines`, and `prepack` as the publication boundary. |
| Root script workspace | [`package.json`](../../../package.json) | Keep out of product version synchronization because it is `private` script orchestration. |
| Node JS/TS wrappers | `node/*.js`, `node/*.d.ts`, `node/bin/`, `node/examples/` | Most namespace wrappers and declarations are generated from the qualified FFI export schema, with reviewed constructor compatibility projections. The `cmd.js` callback facade, root entry point, bin and examples remain maintained source. `npm run build` regenerates the derived files. Use [`node-package-surface.md`](node-package-surface.md) for export-map parity. |
| WASI CLI package artifact | `node/internal/starshine.wasm-wasi.wasm` | Rebuilt by `npm run build` / `prepack` from `moon build --target wasm --release src/cmd`; ignored by Git but intentionally publishable through `node/internal/.npmignore`; executed by the Node-hosted WASI Preview 1 runner documented in [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md); validate released candidates with the self-opt artifact gates when optimized artifacts are in scope. |
| wasm-gc adapter artifact | `node/internal/starshine.wasm-gc.wasm` | Compiled from the generated `ffi/src/npm` adapter on every build, self-optimized with the fresh native bootstrap, independently validated and compared with the preserved raw artifact before promotion. No prebuilt package artifact is needed. |
| Release evidence | Wiki pages, [`../log.md`](../log.md), raw/research notes, git commits, release notes | Use as the source of release notes and known-caveat summaries. Do not reconstruct release history from memory. |

For beginners: npm publication does not upload the whole repository. It uploads the package assembled from `node/package.json` metadata and package files, after lifecycle scripts such as `prepack` have run. That is why release review must inspect both version metadata and the actual tarball contents.

## Release Invariants

- **Explicit version bump required.** Publishing requires an intentional semver bump. Today that means synchronizing at least [`moon.mod`](../../../moon.mod) and [`node/package.json`](../../../node/package.json). The root [`package.json`](../../../package.json) is `private` script orchestration and is not a published package version surface.
- **Validation before publication.** At minimum, use the quick repo signoff (`moon info`, `moon fmt`, `moon test`) for normal changes and prefer [`bun validate full --profile ci --target wasm-gc`](validation-gates.md) before publishing.
- **Generated-interface review is part of API review.** `moon info` can update `pkg.generated.mbti`; review those diffs before release, especially for packages routed through [`node-package-surface.md`](node-package-surface.md).
- **Node package contents are explicit.** npm publication is bounded by [`node/package.json`](../../../node/package.json): `exports`, `files`, `bin`, `engines`, and lifecycle scripts. Do not infer public package contents from every file under `node/` or every package under `src/`.
- **Build and generation fail on drift.** `prepack` rebuilds both Wasm artifacts and deterministic JS/TS bindings. FFI signatures remain authoritative; reviewed unsupported ABI exceptions are explicit and any new or changed exception fails generation. [`generate-product-version.mjs`](../../../scripts/lib/generate-product-version.mjs) rejects inconsistent MoonBit/npm metadata and derives the CLI version. `check-generated` compares generated FFI/npm/version source without rewriting it; its `moon info` step can refresh `.mbti` interfaces.
- **Release notes replace per-commit changelog edits.** The current policy says durable change records live in wiki pages, [`docs/wiki/log.md`](../log.md), release notes, and git history. Do not revive a committed `CHANGELOG.md` workflow without updating [`AGENTS.md`](../../../AGENTS.md), [`docs/README.md`](../../README.md), and this page together.
- **Publishing is human-controlled.** npm tokens, package-registry writes, remote pushes, and public tags are credentials-sensitive operations. Agents may prepare and commit release documentation, but actual publish/push/tag actions need explicit human instruction.
- **Publishing and licensing remain release decisions.** Package repository metadata is present; registry credentials, trusted-publisher configuration and provenance must be reviewed before publication. This preparation does not configure accounts or publish. Resolve the MIT / Apache-2.0 conflict before choosing npm license metadata.

## Version And Package Surface Checklist

### 1. Decide the semver bump

Use normal semantic-versioning judgment:

| Change kind | Typical bump pressure | Starshine examples |
| --- | --- | --- |
| Patch | Bug fix, doc correction, validation hardening with no public API break | validator diagnostic fix, pass safety guard, docs/source refresh |
| Minor | New backwards-compatible public feature | new CLI flag, new exported Node helper, new implemented optimizer pass surface |
| Major | Breaking public API or behavior | removed package export, incompatible CLI/config behavior, renamed public constructor |

Record the reasoning in the release-prep commit or release notes. If in doubt, treat Node exports, CLI flags/config, `.mbti` public interfaces, and binary/text compatibility as public surfaces.

### 2. Bump versioned metadata together

Update:

- [`moon.mod`](../../../moon.mod) `version`;
- [`node/package.json`](../../../node/package.json) `version`.

Then run `bun scripts/lib/generate-product-version.mjs` to derive `src/cmd/version.generated.mbt` from the synchronized metadata. `bun scripts/lib/generate-product-version.mjs --check`, `bun ffi check` and required CI fail on mismatch or generated version drift. The candidate CLI/API must report `v0.1.2-beta.0`, matching the packed npm version. FFI generation synchronizes its root dependency while preserving the private adapter module's own version. The stable portable component interface remains `0.1.1`: its WIT and metadata API versions agree independently of npm product metadata, and component generation derives the root dependency version. An npm version bump alone must not rename WIT exports. Run `moon info` so generated interfaces are current. Review any `src/*/pkg.generated.mbti` diffs as public API evidence, not formatting noise. Use [`moonbit-workspace-package-map.md`](moonbit-workspace-package-map.md) for the package topology and `.mbti` review rules.

If the release includes a prebuilt self-optimized CLI artifact, add `bun validate self-opt-smoke [--wasm <artifact>]` before the rest of the release signoff and require `bun validate self-opt-full [--wasm <artifact>]` before publication. Those gates validate an already-built artifact; they are intentionally separate from the ordinary repo validation ladder.

### 3. Verify Node package boundary if npm publication is in scope

From the `node/` package perspective, validate these boundaries:

1. **Exports:** `node/package.json#exports` lists every public subpath, keeps one deliberate public specifier style per subpath, and pairs runtime `import` files with declaration `types` files.
2. **Files:** `node/package.json#files` includes intended JS, `.d.ts`, `bin`, `examples`, `internal`, README, and package metadata. Do not assume unlisted repo files appear in the tarball.
3. **Build boundary:** `npm run build` generates bindings and compiles the actual WasmGC adapter, native release bootstrap and WASI CLI. It applies the documented O4s numeric preset 4/1 with no silent fallback, independently validates both raw and optimized artifacts, checks the ABI and compares copied-package API/CLI observations before promotion.
4. **Ignored-but-publishable artifact boundary:** both Wasm artifacts are ignored by Git and rebuilt from source. The tarball contains optimized bytes and declarations; raw bytes, schema/policy files, source, private/debug files and build reports remain outside it. Keep the preserved raw artifacts and measured hashes as comparison evidence.
5. **Tarball contents and consumers:** run `bun scripts/test/npm-packed-consumers.mjs` to build the exact tarball, inspect all files and install it into empty JavaScript/strict NodeNext TypeScript projects outside the checkout. Every promised export, initialization, parse/validate/optimize/encode behavior, errors and CLI version must pass without MoonBit or source-tree access at runtime.
6. **Publish trust metadata:** if the release uses npm trusted publishing or provenance, verify `node/package.json` has repository metadata matching the publishing repository, the npm package has a trusted publisher configured when using OIDC, and the GitHub Actions publishing job has `id-token: write` plus an exact publish command from the `node/` package boundary. Use trusted-publishing provenance when available; use the explicit npm provenance option only for an intentionally manual-token provenance path.

The detailed Node API drift and omitted-subpath map lives in [`node-package-surface.md`](node-package-surface.md).

## Validation Ladder

Use the strongest gate proportional to the release risk:

1. **Docs-only release-note/wiki update:** link/source review plus `git diff`; no Moon run is required unless generated docs or code snippets changed.
2. **Ordinary implementation release prep:**
   ```text
   moon info
   moon fmt
   moon test
   ```
3. **Release-like local gate:**
   ```text
   bun validate full --profile ci --target wasm-gc
   ```
4. **Public API or README/API changes:** add `bun validate readme-api-sync` when README/API synchronization is relevant.
5. **Node package publication:** run the package build and Node package tests from the package boundary:
   ```text
   npm run build
   node --test test/*.test.mjs
   bun ../scripts/test/npm-packed-consumers.mjs
   ```
   Run these commands from `node/`; supply `TSC_BIN` if TypeScript is not on PATH. `npm test` already composes build plus tests. The packed-consumer harness performs its own prepack build and records the exact archive and isolated consumer results. See the tested toolchain and complete workflow in [`node/README.md`](../../../node/README.md).
6. **Optimizer pass or preset changes:** add the affected pass's focused tests and the relevant Binaryen oracle lane. Repo-standard pass signoff uses `bun fuzz compare-pass ... --count 10000` where practical; the harness contract is in [`pass-fuzz-compare.md`](pass-fuzz-compare.md).
7. **Validator proof-helper changes:** run `moon prove src/validate_proof` when the proof helper contract changes; record solver/toolchain limits exactly as described in [`../validation/moonbit-prove-strategy.md`](../validation/moonbit-prove-strategy.md).
8. **Performance-sensitive releases:** use focused benchmarks or [`bun validate trace-benchmark`](../validate/trace-benchmark-baseline.md) only when the change affects those surfaces. Do not refresh durable baselines solely for local wall-clock noise.

## Release Notes Workflow

Release notes should be drafted from evidence that is already durable:

- living pages under [`docs/wiki/`](../index.md);
- chronological entries in [`docs/wiki/log.md`](../log.md);
- raw/research notes for substantial investigations;
- git history and commit messages;
- validation artifacts summarized in the release-prep work.

Recommended release-note shape:

```text
## <version> - <date>

### Highlights
- User-visible or developer-visible release themes.

### Added
- New CLI, Node, validation, WAST, pass, or tooling surfaces.

### Changed
- Behavior, scheduling, docs/schema, validation, or packaging changes.

### Fixed
- Correctness, parity, diagnostic, or packaging fixes.

### Validation
- Exact gates run, seeds/profiles for fuzz/pass lanes, known skips or environment limits.

### Compatibility Notes
- Breaking changes, caveats, and follow-up risks.
```

Keep release notes concise and source-backed. Link the wiki page or log entry that owns the durable explanation instead of duplicating long investigations.

## Publication Boundary

Before a real npm publish or public tag:

1. Confirm the working tree is clean except intentional release-prep changes.
2. Confirm version bumps are consistent.
3. Confirm validation gates and Node package checks are green or that any exception is explicitly documented and accepted.
4. Confirm release notes exist and cite durable wiki/log/git evidence.
5. Inspect the exact tested tarball and its consumer report; confirm only intended files are included and installed CLI/API versions match metadata.
6. If using manual publication, use human-controlled credentials and explicit commands for `npm publish`, git tags, and remote pushes.
7. If using trusted publishing, verify the npm package trusted-publisher configuration, package `repository` metadata, GitHub Actions OIDC `id-token: write` permission, and package-boundary publish command are all present and scoped to the intended release workflow.

Do not let an automated wiki or code-maintenance run publish by accident. Preparing a release branch or commit is different from writing to registries. Trusted publishing reduces long-lived-token exposure, but it still writes to the public registry and needs the same release approval, version, validation, tarball, and notes checks.

## Common Failure Modes

- **Bumping only one version.** `moon.mod` and `node/package.json` currently describe the same product release and should not drift silently.
- **Assuming root `package.json` is published.** It is private script orchestration; npm package publication is under `node/`.
- **Editing generated wrappers or version text directly.** FFI signatures and synchronized product metadata own those outputs. Regenerate and review deterministic diffs; drift checks must stay enabled.
- **Skipping `.mbti` review.** A source change can become a public API change even when tests pass.
- **Conflating `bun validate full` with pass parity.** Full validation runs ordinary fuzz suites, not every Binaryen compare-pass lane.
- **Publishing without tarball inspection.** `exports` and `files` define a smaller public surface than the repo tree; inspect package contents before publish.
- **Accidentally broadening exported specifiers.** Adding extensioned aliases, wildcard patterns, or new subpaths under `node/package.json#exports` is an API decision, not a packaging cleanup.
- **Writing release notes from memory.** Use wiki pages, raw/research notes, log entries, and git history so stale or superseded claims remain visible.

## Sources

- Official npm [package metadata](https://docs.npmjs.com/cli/v11/configuring-npm/package-json), [`npm pack`](https://docs.npmjs.com/cli/v11/commands/npm-pack), [`npm publish`](https://docs.npmjs.com/cli/v11/commands/npm-publish), [lifecycle scripts](https://docs.npmjs.com/cli/v11/using-npm/scripts#life-cycle-scripts), [trusted publishers](https://docs.npmjs.com/trusted-publishers), and [provenance](https://docs.npmjs.com/generating-provenance-statements) documentation; GitHub Actions [OIDC guidance](https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- Official MoonBit [module configuration](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html) and the live [`moon.mod`](../../../moon.mod)
- Repo policy: [`../../../AGENTS.md`](../../../AGENTS.md), [`../../README.md`](../../README.md)
- Package metadata and workflow evidence: [`../../../moon.mod`](../../../moon.mod), [`../../../node/package.json`](../../../node/package.json), [`../../../package.json`](../../../package.json), [`../../../.github/workflows/node-wasm-tests.yml`](../../../.github/workflows/node-wasm-tests.yml), [`../../../.github/workflows/fuzz.yml`](../../../.github/workflows/fuzz.yml), [`../../../.github/workflows/readme-api-sync.yml`](../../../.github/workflows/readme-api-sync.yml)
- Node package boundary: [`./node-package-surface.md`](node-package-surface.md), official [Node package documentation](https://nodejs.org/api/packages.html), official [TypeScript module-resolution reference](https://www.typescriptlang.org/docs/handbook/modules/reference.html), [`../../../node/README.md`](../../../node/README.md), [`../../../node/internal/.gitignore`](../../../node/internal/.gitignore), [`../../../node/internal/.npmignore`](../../../node/internal/.npmignore), [`../../../scripts/lib/build-node-package.mjs`](../../../scripts/lib/build-node-package.mjs), [`../../../scripts/lib/generate-node-package.mjs`](../../../scripts/lib/generate-node-package.mjs)
- Validation gates: [`./validation-gates.md`](validation-gates.md), [`../../../scripts/lib/validate-task.ts`](../../../scripts/lib/validate-task.ts), [`./pass-fuzz-compare.md`](pass-fuzz-compare.md), [`../validation/moonbit-prove-strategy.md`](../validation/moonbit-prove-strategy.md)
