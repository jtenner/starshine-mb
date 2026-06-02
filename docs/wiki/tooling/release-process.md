---
kind: workflow
status: supported
last_reviewed: 2026-06-02
sources:
  - ../raw/release/2026-05-20-starshine-release-process-sources.md
  - ../../../AGENTS.md
  - ../../README.md
  - ../../../moon.mod.json
  - ../../../node/package.json
  - ../../../node/README.md
  - ../../../package.json
  - ../../../scripts/lib/validate-task.ts
  - ../../../scripts/lib/build-node-package.mjs
  - ../../../scripts/lib/generate-node-package.mjs
  - ../raw/validation/2026-06-02-wasm-tools-validation-feature-defaults.md
related:
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

1. **MoonBit module metadata** in [`moon.mod.json`](../../../moon.mod.json), currently `jtenner/starshine` at version `0.1.0`.
2. **Node/npm package metadata** in [`node/package.json`](../../../node/package.json), currently `@jtenner/starshine` at version `0.1.0`.
3. **Checked-in public API snapshots** through `src/*/pkg.generated.mbti`, especially for packages exposed through the Node boundary.
4. **The runnable CLI and Node package artifacts**, including `node/internal/starshine.wasm-wasi.wasm`, the checked-in wasm-gc adapter artifact, JS/TS wrappers, and `node/package.json#exports`.
5. **Durable release evidence** in wiki pages, [`docs/wiki/log.md`](../log.md), raw/research notes, release notes, validation artifacts, and git history.

The primary-source snapshot for this page is [`../raw/release/2026-05-20-starshine-release-process-sources.md`](../raw/release/2026-05-20-starshine-release-process-sources.md). It checks current npm CLI docs for package metadata, pack/publish, and lifecycle hooks; local MoonBit package metadata; Node package build boundaries; and the repo's own release policy.

For releases that include an already-built self-optimized CLI artifact, treat that artifact as a separate release surface. Use the dedicated `bun validate self-opt-smoke` / `bun validate self-opt-full` gate from [`validation-gates.md`](validation-gates.md) so artifact safety stays explicit instead of being inferred from the ordinary repo validation ladder.

## Release Invariants

- **Explicit version bump required.** Publishing requires an intentional semver bump. Today that means synchronizing at least [`moon.mod.json`](../../../moon.mod.json) and [`node/package.json`](../../../node/package.json). The root [`package.json`](../../../package.json) is `private` script orchestration and is not a published package version surface.
- **Validation before publication.** At minimum, use the quick repo signoff (`moon info`, `moon fmt`, `moon test`) for normal changes and prefer [`bun validate full --profile ci --target wasm-gc`](validation-gates.md) before publishing.
- **Generated-interface review is part of API review.** `moon info` can update `pkg.generated.mbti`; review those diffs before release, especially for packages routed through [`node-package-surface.md`](node-package-surface.md).
- **Node package contents are explicit.** npm publication is bounded by [`node/package.json`](../../../node/package.json): `exports`, `files`, `bin`, `engines`, and lifecycle scripts. Do not infer public package contents from every file under `node/` or every package under `src/`.
- **Node build does not regenerate wrappers.** [`node/package.json`](../../../node/package.json) has `prepack: npm run build`, and [`scripts/lib/build-node-package.mjs`](../../../scripts/lib/build-node-package.mjs) rebuilds the optimized WASI CLI artifact. [`scripts/lib/generate-node-package.mjs`](../../../scripts/lib/generate-node-package.mjs) intentionally throws, so JS/TS wrapper changes remain hand-maintained until the adapter story changes.
- **Release notes replace per-commit changelog edits.** The current policy says durable change records live in wiki pages, [`docs/wiki/log.md`](../log.md), release notes, and git history. Do not revive a committed `CHANGELOG.md` workflow without updating [`AGENTS.md`](../../../AGENTS.md), [`docs/README.md`](../../README.md), and this page together.
- **Publishing is human-controlled.** npm tokens, package-registry writes, remote pushes, and public tags are credentials-sensitive operations. Agents may prepare and commit release documentation, but actual publish/push/tag actions need explicit human instruction.

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

- [`moon.mod.json`](../../../moon.mod.json) `version`;
- [`node/package.json`](../../../node/package.json) `version`.

Then run `moon info` so generated interfaces are current. Review any `src/*/pkg.generated.mbti` diffs as public API evidence, not formatting noise. Use [`moonbit-workspace-package-map.md`](moonbit-workspace-package-map.md) for the package topology and `.mbti` review rules.

If the release includes a prebuilt self-optimized CLI artifact, add `bun validate self-opt-smoke [--wasm <artifact>]` before the rest of the release signoff and require `bun validate self-opt-full [--wasm <artifact>]` before publication. Those gates validate an already-built artifact; they are intentionally separate from the ordinary repo validation ladder.

### 3. Verify Node package boundary if npm publication is in scope

From the `node/` package perspective, validate four things:

1. **Exports:** `node/package.json#exports` lists every public subpath and pairs runtime `import` files with declaration `types` files.
2. **Files:** `node/package.json#files` includes intended JS, `.d.ts`, `bin`, `examples`, `internal`, README, and package metadata.
3. **Build boundary:** `npm run build` refreshes the WASI CLI artifact but does not regenerate wrappers; wrapper changes require explicit JS/TS diffs and tests.
4. **Tarball contents:** use npm's package inspection path, e.g. `npm pack --dry-run` from `node/`, before a real publish. Treat dry-run output as packaging evidence, not as a replacement for tests.

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
6. Use human-controlled credentials and explicit commands for `npm publish`, git tags, and remote pushes.

Do not let an automated wiki or code-maintenance run publish by accident. Preparing a release branch or commit is different from writing to registries.

## Common Failure Modes

- **Bumping only one version.** `moon.mod.json` and `node/package.json` currently describe the same product release and should not drift silently.
- **Assuming root `package.json` is published.** It is private script orchestration; npm package publication is under `node/`.
- **Trusting `npm run build` to refresh wrappers.** It refreshes the WASI CLI artifact. JS/TS wrappers and declarations are checked in and require explicit edits/tests.
- **Skipping `.mbti` review.** A source change can become a public API change even when tests pass.
- **Conflating `bun validate full` with pass parity.** Full validation runs ordinary fuzz suites, not every Binaryen compare-pass lane.
- **Publishing without tarball inspection.** `exports` and `files` define a smaller public surface than the repo tree; inspect package contents before publish.
- **Writing release notes from memory.** Use wiki pages, raw/research notes, log entries, and git history so stale or superseded claims remain visible.

## Sources

- Release source snapshot: [`../raw/release/2026-05-20-starshine-release-process-sources.md`](../raw/release/2026-05-20-starshine-release-process-sources.md)
- Repo policy: [`../../../AGENTS.md`](../../../AGENTS.md), [`../../README.md`](../../README.md)
- Package metadata: [`../../../moon.mod.json`](../../../moon.mod.json), [`../../../node/package.json`](../../../node/package.json), [`../../../package.json`](../../../package.json)
- Node package boundary: [`./node-package-surface.md`](node-package-surface.md), [`../../../node/README.md`](../../../node/README.md), [`../../../scripts/lib/build-node-package.mjs`](../../../scripts/lib/build-node-package.mjs), [`../../../scripts/lib/generate-node-package.mjs`](../../../scripts/lib/generate-node-package.mjs)
- Validation gates: [`./validation-gates.md`](validation-gates.md), [`../../../scripts/lib/validate-task.ts`](../../../scripts/lib/validate-task.ts), [`./pass-fuzz-compare.md`](pass-fuzz-compare.md), [`../validation/moonbit-prove-strategy.md`](../validation/moonbit-prove-strategy.md)
- npm docs checked by the source snapshot: <https://docs.npmjs.com/cli/v11/configuring-npm/package-json>, <https://docs.npmjs.com/cli/v11/commands/npm-publish>, <https://docs.npmjs.com/cli/v11/commands/npm-pack>, <https://docs.npmjs.com/cli/v11/using-npm/scripts#life-cycle-scripts>
