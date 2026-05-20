---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-05-20
sources:
  - https://docs.npmjs.com/cli/v11/configuring-npm/package-json
  - https://docs.npmjs.com/cli/v11/commands/npm-publish
  - https://docs.npmjs.com/cli/v11/commands/npm-pack
  - https://docs.npmjs.com/cli/v11/using-npm/scripts#life-cycle-scripts
  - ../../../../AGENTS.md
  - ../../../README.md
  - ../../../../moon.mod.json
  - ../../../../package.json
  - ../../../../node/package.json
  - ../../../../node/README.md
  - ../../../../scripts/lib/validate-task.ts
  - ../../../../scripts/lib/build-node-package.mjs
  - ../../../../scripts/lib/generate-node-package.mjs
  - ../moonbit/2026-05-20-workspace-package-surface.md
  - ../moonbit/2026-05-20-moon-cli-command-manual-refresh.md
  - ../node/2026-05-20-node-package-export-boundary.md
related:
  - ../../tooling/release-process.md
  - ../../tooling/validation-gates.md
  - ../../tooling/node-package-surface.md
  - ../../tooling/moonbit-workspace-package-map.md
---

# Starshine Release Process Source Snapshot - 2026-05-20

This manifest supports the living release-process guide. It captures the current source boundary for Starshine releases: local repo policy owns the release gate, while npm and MoonBit docs explain the package metadata and packaging mechanics that the local policy relies on.

## External primary sources checked

1. npm CLI v11 package-json docs: <https://docs.npmjs.com/cli/v11/configuring-npm/package-json>
   - Used for the durable meaning of `version`, `exports`, `files`, `bin`, `engines`, and package metadata fields that appear in [`node/package.json`](../../../../node/package.json).
2. npm CLI v11 `npm publish` docs: <https://docs.npmjs.com/cli/v11/commands/npm-publish>
   - Used for the package-publish boundary: publishing sends a package to the configured registry and has a `--dry-run` mode. Starshine docs should still treat actual publish as an explicit human action, not an agent default.
3. npm CLI v11 `npm pack` docs: <https://docs.npmjs.com/cli/v11/commands/npm-pack>
   - Used for the local package-inspection recommendation: `npm pack --dry-run` can show the package tarball contents before publishing.
4. npm CLI v11 scripts lifecycle docs: <https://docs.npmjs.com/cli/v11/using-npm/scripts#life-cycle-scripts>
   - Used for the lifecycle-script boundary: npm has pack/publish lifecycle hooks, and Starshine's [`node/package.json`](../../../../node/package.json) sets `prepack` to `npm run build`.
5. Existing MoonBit source manifests:
   - [`../moonbit/2026-05-20-workspace-package-surface.md`](../moonbit/2026-05-20-workspace-package-surface.md) for `moon.mod.json`, package config, and generated-interface review.
   - [`../moonbit/2026-05-20-moon-cli-command-manual-refresh.md`](../moonbit/2026-05-20-moon-cli-command-manual-refresh.md) for current `moon` command provenance.

## Starshine local sources checked

- [`AGENTS.md`](../../../../AGENTS.md) and [`docs/README.md`](../../../README.md) define the release policy: semver bump, successful validation, consistent package version bumps, release notes drafted from wiki pages / log / git history, and no per-commit changelog requirement.
- [`moon.mod.json`](../../../../moon.mod.json) currently declares MoonBit module name `jtenner/starshine` and version `0.1.0`.
- [`node/package.json`](../../../../node/package.json) currently declares npm package name `@jtenner/starshine`, version `0.1.0`, explicit `exports`, `files`, `bin`, `engines`, `scripts`, and `prepack`.
- Root [`package.json`](../../../../package.json) is private script orchestration, not a published package.
- [`node/README.md`](../../../../node/README.md), [`scripts/lib/build-node-package.mjs`](../../../../scripts/lib/build-node-package.mjs), and [`scripts/lib/generate-node-package.mjs`](../../../../scripts/lib/generate-node-package.mjs) record the current Node build boundary: build refreshes the optimized WASI CLI artifact, while wrapper generation remains disabled.
- [`scripts/lib/validate-task.ts`](../../../../scripts/lib/validate-task.ts) owns the `bun validate full`, `coverage`, `readme-api-sync`, and `trace-benchmark` command shapes summarized by the validation-gate page.

## Durable conclusions

1. A Starshine release currently has at least two versioned package surfaces: MoonBit module metadata in `moon.mod.json` and npm package metadata in `node/package.json`. They must be bumped together when publishing the same Starshine release.
2. The root `package.json` is intentionally `private` and names the script workspace (`starshine-scripts`); it is not a third published artifact.
3. npm package publication is governed by `node/package.json#exports`, `files`, `bin`, lifecycle scripts, and the package tarball contents. The release guide should require local package inspection before publish rather than relying on assumed file inclusion.
4. Starshine's current Node build does not regenerate JS/TS wrappers. Release signoff must therefore include the Node package surface and parity tests when wrapper declarations or runtime exports change.
5. Release notes should be drafted from living wiki pages, `docs/wiki/log.md`, raw/research notes, and git history. The retired committed changelog workflow should not be revived without updating `AGENTS.md`, `docs/README.md`, and this guide together.
6. Actual registry publication, npm token use, git tags, and remote pushes are human-controlled release operations. An agent can prepare docs and commits, but should not publish or push without an explicit request and credentials-safe procedure.
