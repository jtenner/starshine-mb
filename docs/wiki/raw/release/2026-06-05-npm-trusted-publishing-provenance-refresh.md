---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-06-05
sources:
  - https://docs.npmjs.com/trusted-publishers
  - https://docs.npmjs.com/generating-provenance-statements
  - https://docs.npmjs.com/cli/v11/commands/npm-publish
  - https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
  - ../../../../node/package.json
  - ../../../../package.json
  - ../../../../.github/workflows/node-wasm-tests.yml
  - ../../../../.github/workflows/fuzz.yml
  - ../../../../.github/workflows/readme-api-sync.yml
related:
  - ../../tooling/release-process.md
  - ../../tooling/node-package-surface.md
  - ../../tooling/validation-gates.md
---

# npm Trusted Publishing And Provenance Refresh - 2026-06-05

Purpose: add the current npm package-publication trust boundary to the Starshine release wiki without changing release code or workflows. This note focuses on package provenance, OIDC trusted publishing, and why the current repo state should still be treated as manually published until a deliberate release workflow exists.

## External primary sources checked

1. npm trusted publishers documentation: <https://docs.npmjs.com/trusted-publishers>
   - Rechecked that npm supports trusted publishing through an OpenID Connect exchange so packages can be published from supported CI/CD providers without long-lived npm tokens.
   - Rechecked the npm-side setup requirement that a package has a configured trusted publisher entry matching the CI provider and repository/workflow environment.
   - Rechecked the package metadata caveat: GitHub trusted publishing expects the package's `repository` field to match the GitHub repository that publishes it.
2. npm provenance documentation: <https://docs.npmjs.com/generating-provenance-statements>
   - Rechecked that npm can publish provenance statements when `npm publish` is run with the provenance option or matching npm config.
   - Rechecked that provenance is strongest when paired with a supported cloud CI/CD provider and can be verified from the npm package page or package metadata tooling.
3. npm CLI v11 publish documentation: <https://docs.npmjs.com/cli/v11/commands/npm-publish>
   - Rechecked that `npm publish` writes a package to the configured registry, that `--provenance` is a publish option, and that publication is still an irreversible name/version registry operation.
4. GitHub Actions OIDC hardening documentation: <https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect>
   - Rechecked that GitHub Actions workflows need `id-token: write` permission to request an OIDC token from GitHub's provider.

## Starshine local sources checked

- [`node/package.json`](../../../../node/package.json) declares the product npm package `@jtenner/starshine`, but it currently has no `repository` field, no `publishConfig`, and no package-script publish command.
- Root [`package.json`](../../../../package.json) is still a private script-orchestration package and is not the npm product package.
- Existing GitHub workflows checked here are test/validation workflows, not publication workflows:
  - [`node-wasm-tests.yml`](../../../../.github/workflows/node-wasm-tests.yml) has `permissions.contents: read`, runs Node/package tests, and does not publish.
  - [`fuzz.yml`](../../../../.github/workflows/fuzz.yml) has read-only contents permissions for fuzz gates and does not publish.
  - [`readme-api-sync.yml`](../../../../.github/workflows/readme-api-sync.yml) has read-only contents permissions and does not publish.
- A repo search for `npm publish`, `NPM_TOKEN`, `trusted publishing`, `id-token`, and `provenance` found no current release-publication workflow. Existing references are documentation/provenance wording, not publish automation.

## Durable conclusions

1. Starshine currently has a documented **release-prep** process, not a configured npm trusted-publishing process. Treat real package publication as human-controlled until a dedicated release workflow, npm trusted-publisher configuration, and package metadata update land together.
2. The current Node package is not yet trusted-publishing-ready because `node/package.json` lacks the `repository` metadata npm expects for GitHub trusted publishing, and no workflow grants `id-token: write` or runs a package publish step from the `node/` package boundary.
3. A future trusted-publishing slice should be explicit and reviewable: add package repository metadata, define a narrow release workflow with OIDC `id-token: write`, run validation and tarball inspection before publishing, publish from `node/` with trusted-publishing provenance, and update release docs/logs in the same change.
4. Trusted publishing and provenance improve the credential and supply-chain evidence surface, but they do not replace semver decisions, validation gates, Node wrapper/API parity, wasm artifact checks, or `npm pack --dry-run` tarball inspection.

## Follow-up checklist for a future release-hardening change

- Add a package-level `repository` field to [`node/package.json`](../../../../node/package.json) that matches the canonical GitHub repository used for npm trusted publishing.
- Configure the npm package's trusted publisher entry for the chosen GitHub Actions workflow/environment.
- Add a release workflow with least-privilege permissions: read-only repository contents plus `id-token: write` only on the publishing job.
- Run release validation, Node package tests, artifact checks, and `npm pack --dry-run` before the publish step.
- Run the publish step from the `node/` package directory, not from the root private script package; use trusted-publishing provenance when the npm trusted publisher is configured, or the explicit npm provenance option when a manual-token provenance path is intentionally chosen.
- Keep tags, remote pushes, registry writes, and version bumps under explicit human release approval.
