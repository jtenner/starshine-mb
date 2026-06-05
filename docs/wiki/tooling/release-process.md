---
kind: workflow
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/node/2026-06-05-wasi-runner-preview-boundary-refresh.md
  - ../raw/release/2026-06-05-npm-trusted-publishing-provenance-refresh.md
  - ../raw/release/2026-06-04-release-package-surface-refresh.md
  - ../raw/moonbit/2026-06-04-moon-mod-file-current-refresh.md
  - ../raw/release/2026-05-20-starshine-release-process-sources.md
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
  - ../raw/validation/2026-06-02-wasm-tools-validation-feature-defaults.md
related:
  - ./wasi-runner-and-preview-boundary.md
  - ./validation-gates.md
  - ./moonbit-workspace-package-map.md
  - ./node-package-surface.md
  - ./cli-command-and-dispatcher.md
  - ./pass-fuzz-compare.md
  - ../validate/trace-benchmark-baseline.md
  - ../validation/moonbit-prove-strategy.md
  - ../raw/release/2026-05-20-starshine-release-process-sources.md
---

# Release Process

## Overview

Use this page when preparing a Starshine release, reviewing a release-prep branch, or deciding whether a change is release-blocking. It turns the compact repo policy in [`AGENTS.md`](../../../AGENTS.md) and [`docs/README.md`](../../README.md) into a concrete checklist with package-surface, validation, release-notes, and publication boundaries.

A Starshine release is not just “run tests and publish npm.” The current repo has several distinct surfaces:

1. **MoonBit module metadata** in [`moon.mod`](../../../moon.mod), currently `jtenner/starshine` at version `0.1.0`.
2. **Node/npm package metadata** in [`node/package.json`](../../../node/package.json), currently `@jtenner/starshine` at version `0.1.0`.
3. **Checked-in public API snapshots** through `src/*/pkg.generated.mbti`, especially for packages exposed through the Node boundary.
4. **The runnable CLI and Node package artifacts**, including `node/internal/starshine.wasm-wasi.wasm`, the required wasm-gc adapter package artifact, JS/TS wrappers, and `node/package.json#exports`.
5. **Durable release evidence** in wiki pages, [`docs/wiki/log.md`](../log.md), raw/research notes, release notes, validation artifacts, and git history.

The current release package-surface refresh is [`../raw/release/2026-06-04-release-package-surface-refresh.md`](../raw/release/2026-06-04-release-package-surface-refresh.md). It supersedes the stale local-path claims in the older [`../raw/release/2026-05-20-starshine-release-process-sources.md`](../raw/release/2026-05-20-starshine-release-process-sources.md) manifest after rechecking current npm CLI v11 packaging docs, current MoonBit `moon.mod` docs, and the live Starshine package files. The MoonBit-specific module-file correction is also tracked in [`../raw/moonbit/2026-06-04-moon-mod-file-current-refresh.md`](../raw/moonbit/2026-06-04-moon-mod-file-current-refresh.md).

The current publication-trust refresh is [`../raw/release/2026-06-05-npm-trusted-publishing-provenance-refresh.md`](../raw/release/2026-06-05-npm-trusted-publishing-provenance-refresh.md). It checked current npm trusted-publishing / provenance docs and GitHub Actions OIDC docs against the live Starshine package and workflows. The durable result is a boundary, not a new release path: Starshine has release-prep guidance, package tests, and tarball-inspection guidance, but no configured npm trusted publisher, no publish workflow, no `id-token: write` publication job, and no `node/package.json` `repository` field yet.

For releases that include an already-built self-optimized CLI artifact, treat that artifact as a separate release surface. Use the dedicated `bun validate self-opt-smoke` / `bun validate self-opt-full` gate from [`validation-gates.md`](validation-gates.md) so artifact safety stays explicit instead of being inferred from the ordinary repo validation ladder.

## Release Surface Matrix

| Surface | Current owner | Release decision |
| --- | --- | --- |
| MoonBit product metadata | [`moon.mod`](../../../moon.mod) | Bump `version` for a Starshine release; this is the current module-file format, not `moon.mod.json`. |
| npm product metadata and public entry points | [`node/package.json`](../../../node/package.json) | Bump `version` with `moon.mod`; review `exports`, `files`, `bin`, `engines`, and `prepack` as the publication boundary. |
| Root script workspace | [`package.json`](../../../package.json) | Keep out of product version synchronization because it is `private` script orchestration. |
| Node JS/TS wrappers | `node/*.js`, `node/*.d.ts`, `node/bin/`, `node/examples/` | Treat as checked-in public source; `npm run build` does not regenerate wrappers. Use [`node-package-surface.md`](node-package-surface.md) for export-map parity. |
| WASI CLI package artifact | `node/internal/starshine.wasm-wasi.wasm` | Rebuilt by `npm run build` / `prepack` from `moon build --target wasm --release src/cmd`; ignored by Git but intentionally publishable through `node/internal/.npmignore`; executed by the Node-hosted WASI Preview 1 runner documented in [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md); validate released candidates with the self-opt artifact gates when optimized artifacts are in scope. |
| wasm-gc adapter artifact | `node/internal/starshine.wasm-gc.wasm` | Required local/package boundary artifact today; ignored by Git, kept publishable by `node/internal/.npmignore`, and not regenerated by `npm run build`. Any change, absence, or rebuild-path restoration needs a fresh source refresh and tarball inspection. |
| Release evidence | Wiki pages, [`../log.md`](../log.md), raw/research notes, git commits, release notes | Use as the source of release notes and known-caveat summaries. Do not reconstruct release history from memory. |

For beginners: npm publication does not upload the whole repository. It uploads the package assembled from `node/package.json` metadata and package files, after lifecycle scripts such as `prepack` have run. That is why release review must inspect both version metadata and the actual tarball contents.

## Release Invariants

- **Explicit version bump required.** Publishing requires an intentional semver bump. Today that means synchronizing at least [`moon.mod`](../../../moon.mod) and [`node/package.json`](../../../node/package.json). The root [`package.json`](../../../package.json) is `private` script orchestration and is not a published package version surface.
- **Validation before publication.** At minimum, use the quick repo signoff (`moon info`, `moon fmt`, `moon test`) for normal changes and prefer [`bun validate full --profile ci --target wasm-gc`](validation-gates.md) before publishing.
- **Generated-interface review is part of API review.** `moon info` can update `pkg.generated.mbti`; review those diffs before release, especially for packages routed through [`node-package-surface.md`](node-package-surface.md).
- **Node package contents are explicit.** npm publication is bounded by [`node/package.json`](../../../node/package.json): `exports`, `files`, `bin`, `engines`, and lifecycle scripts. Do not infer public package contents from every file under `node/` or every package under `src/`.
- **Node build does not regenerate wrappers.** [`node/package.json`](../../../node/package.json) has `prepack: npm run build`, and [`scripts/lib/build-node-package.mjs`](../../../scripts/lib/build-node-package.mjs) rebuilds the optimized WASI CLI artifact. [`scripts/lib/generate-node-package.mjs`](../../../scripts/lib/generate-node-package.mjs) intentionally throws, so JS/TS wrapper changes remain hand-maintained until the adapter story changes.
- **Release notes replace per-commit changelog edits.** The current policy says durable change records live in wiki pages, [`docs/wiki/log.md`](../log.md), release notes, and git history. Do not revive a committed `CHANGELOG.md` workflow without updating [`AGENTS.md`](../../../AGENTS.md), [`docs/README.md`](../../README.md), and this page together.
- **Publishing is human-controlled.** npm tokens, package-registry writes, remote pushes, and public tags are credentials-sensitive operations. Agents may prepare and commit release documentation, but actual publish/push/tag actions need explicit human instruction.
- **Trusted publishing is not configured yet.** npm trusted publishing and provenance would be a release-hardening improvement, but current Starshine has no npm trusted-publisher setup, no GitHub Actions publish workflow with `id-token: write`, no package publish step from `node/`, and no package-level `repository` metadata in [`node/package.json`](../../../node/package.json). Keep publication manual until those pieces land together.

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

Then run `moon info` so generated interfaces are current. Review any `src/*/pkg.generated.mbti` diffs as public API evidence, not formatting noise. Use [`moonbit-workspace-package-map.md`](moonbit-workspace-package-map.md) for the package topology and `.mbti` review rules.

If the release includes a prebuilt self-optimized CLI artifact, add `bun validate self-opt-smoke [--wasm <artifact>]` before the rest of the release signoff and require `bun validate self-opt-full [--wasm <artifact>]` before publication. Those gates validate an already-built artifact; they are intentionally separate from the ordinary repo validation ladder.

### 3. Verify Node package boundary if npm publication is in scope

From the `node/` package perspective, validate five things:

1. **Exports:** `node/package.json#exports` lists every public subpath, keeps one deliberate public specifier style per subpath, and pairs runtime `import` files with declaration `types` files.
2. **Files:** `node/package.json#files` includes intended JS, `.d.ts`, `bin`, `examples`, `internal`, README, and package metadata. Do not assume unlisted repo files appear in the tarball.
3. **Build boundary:** `npm run build` refreshes the WASI CLI artifact but does not regenerate wrappers; wrapper changes require explicit JS/TS diffs and tests.
4. **Ignored-but-publishable artifact boundary:** the current build requires `node/internal/starshine.wasm-gc.wasm` to already exist and keeps it unchanged; both wasm package artifacts are ignored by Git but intentionally not ignored by npm packaging. If the wasm-gc artifact is stale, missing, or intentionally updated, record the release evidence separately from the WASI artifact rebuild.
5. **Tarball contents:** use npm's package inspection path, e.g. `npm pack --dry-run` from `node/`, before a real publish. Treat dry-run output as packaging evidence, not as a replacement for tests.
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
   npm pack --dry-run
   ```
   `npm test` in `node/package.json` already composes build plus tests, but the explicit split makes it easier to diagnose build, wrapper, and packaging failures.
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
5. Inspect `npm pack --dry-run` output from `node/` and confirm only intended files are included.
6. If using manual publication, use human-controlled credentials and explicit commands for `npm publish`, git tags, and remote pushes.
7. If using trusted publishing, verify the npm package trusted-publisher configuration, package `repository` metadata, GitHub Actions OIDC `id-token: write` permission, and package-boundary publish command are all present and scoped to the intended release workflow.

Do not let an automated wiki or code-maintenance run publish by accident. Preparing a release branch or commit is different from writing to registries. Trusted publishing reduces long-lived-token exposure, but it still writes to the public registry and needs the same release approval, version, validation, tarball, and notes checks.

## Common Failure Modes

- **Bumping only one version.** `moon.mod` and `node/package.json` currently describe the same product release and should not drift silently.
- **Assuming root `package.json` is published.** It is private script orchestration; npm package publication is under `node/`.
- **Trusting `npm run build` to refresh wrappers.** It refreshes the WASI CLI artifact. JS/TS wrappers and declarations are checked in and require explicit edits/tests.
- **Skipping `.mbti` review.** A source change can become a public API change even when tests pass.
- **Conflating `bun validate full` with pass parity.** Full validation runs ordinary fuzz suites, not every Binaryen compare-pass lane.
- **Publishing without tarball inspection.** `exports` and `files` define a smaller public surface than the repo tree; inspect package contents before publish.
- **Accidentally broadening exported specifiers.** Adding extensioned aliases, wildcard patterns, or new subpaths under `node/package.json#exports` is an API decision, not a packaging cleanup.
- **Writing release notes from memory.** Use wiki pages, raw/research notes, log entries, and git history so stale or superseded claims remain visible.

## Sources

- npm trusted-publishing and provenance refresh: [`../raw/release/2026-06-05-npm-trusted-publishing-provenance-refresh.md`](../raw/release/2026-06-05-npm-trusted-publishing-provenance-refresh.md)
- Current release package-surface refresh: [`../raw/release/2026-06-04-release-package-surface-refresh.md`](../raw/release/2026-06-04-release-package-surface-refresh.md)
- Current MoonBit module-file refresh: [`../raw/moonbit/2026-06-04-moon-mod-file-current-refresh.md`](../raw/moonbit/2026-06-04-moon-mod-file-current-refresh.md)
- Earlier release source snapshot superseded for local `moon.mod.json` paths: [`../raw/release/2026-05-20-starshine-release-process-sources.md`](../raw/release/2026-05-20-starshine-release-process-sources.md)
- Repo policy: [`../../../AGENTS.md`](../../../AGENTS.md), [`../../README.md`](../../README.md)
- Package metadata: [`../../../moon.mod`](../../../moon.mod), [`../../../node/package.json`](../../../node/package.json), [`../../../package.json`](../../../package.json)
- Node package boundary: [`./node-package-surface.md`](node-package-surface.md), [`../raw/node/2026-06-04-node-package-export-and-wrapper-drift-recheck.md`](../raw/node/2026-06-04-node-package-export-and-wrapper-drift-recheck.md), [`../../../node/README.md`](../../../node/README.md), [`../../../node/internal/.gitignore`](../../../node/internal/.gitignore), [`../../../node/internal/.npmignore`](../../../node/internal/.npmignore), [`../../../scripts/lib/build-node-package.mjs`](../../../scripts/lib/build-node-package.mjs), [`../../../scripts/lib/generate-node-package.mjs`](../../../scripts/lib/generate-node-package.mjs)
- Validation gates: [`./validation-gates.md`](validation-gates.md), [`../../../scripts/lib/validate-task.ts`](../../../scripts/lib/validate-task.ts), [`./pass-fuzz-compare.md`](pass-fuzz-compare.md), [`../validation/moonbit-prove-strategy.md`](../validation/moonbit-prove-strategy.md)
- npm docs checked by the source snapshot: <https://docs.npmjs.com/cli/v11/configuring-npm/package-json>, <https://docs.npmjs.com/cli/v11/commands/npm-publish>, <https://docs.npmjs.com/cli/v11/commands/npm-pack>, <https://docs.npmjs.com/cli/v11/using-npm/scripts#life-cycle-scripts>
