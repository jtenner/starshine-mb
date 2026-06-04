---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/node/2026-06-04-node-package-export-and-wrapper-drift-recheck.md
  - ../raw/node/2026-05-20-node-package-export-boundary.md
  - ../raw/moonbit/2026-05-20-workspace-package-surface.md
  - ../raw/wasm/2026-05-19-wast-static-assertion-sources.md
  - ../raw/research/0110-2026-04-18-node-package-api-audit.md
  - ../../../node/package.json
  - ../../../node/README.md
  - ../../../node/test/api-parity.test.mjs
  - ../../../node/test/smoke.test.mjs
  - ../../../node/test/examples.test.mjs
  - ../../../scripts/lib/generate-node-package.mjs
  - ../../../scripts/lib/build-node-package.mjs
  - ../../../src/cli/pkg.generated.mbti
  - ../../../src/cmd/pkg.generated.mbti
  - ../../../src/validate/pkg.generated.mbti
  - ../../../src/wast/pkg.generated.mbti
related:
  - ./fuzz-runner.md
  - ./cli-command-and-dispatcher.md
  - ./release-process.md
  - ./moonbit-workspace-package-map.md
  - ./cli-startup-path.md
  - ../validate/fuzz-hardening.md
  - ../validate/diagnostics-and-invalid-repro.md
  - ../wast/static-assertion-harness.md
  - ../../README.md
---

# Node Package Surface

## Overview

The checked-in `node/` package is a hand-maintained, ESM-first boundary package for `@jtenner/starshine`, not a live mirror of every active MoonBit package.
It exports a small JavaScript-facing toolkit for binary/text roundtrips, command execution, validation, and examples, while deeper compiler internals remain repo-local.
Treat the Node package as a public API layer whose correctness depends on explicit wrapper tests and packaging checks rather than on automatic regeneration from `src/*`.
The public boundary is the explicit [`node/package.json`](../../../node/package.json) `exports` map: Node resolves only the listed package subpaths, and TypeScript must resolve matching declaration files through the same listed surface. The 2026-06-04 recheck in [`../raw/node/2026-06-04-node-package-export-and-wrapper-drift-recheck.md`](../raw/node/2026-06-04-node-package-export-and-wrapper-drift-recheck.md) refreshed the current Node and TypeScript package-resolution rules behind that claim: unlisted subpaths stay private, export targets must be package-relative `./...` paths, TypeScript follows `exports` in Node-aware modes, and each public subpath needs declaration/runtime parity.

The current flow has two important artifacts:

1. [`scripts/lib/generate-node-package.mjs`](../../../scripts/lib/generate-node-package.mjs) intentionally throws because the old generator depended on the legacy `src/node_api` adapter and removed pass ports.
2. [`scripts/lib/build-node-package.mjs`](../../../scripts/lib/build-node-package.mjs) rebuilds the optimized WASI CLI artifact from `src/cmd`, copies it to `node/internal/starshine.wasm-wasi.wasm`, and keeps the checked-in `node/internal/starshine.wasm-gc.wasm` boundary artifact.

That split is the main invariant for maintainers: **do not assume `npm run build` refreshes all JS/TS wrappers from the current MoonBit signatures.** The package README now states the same boundary: build refreshes the WASI CLI artifact only, while wrapper generation remains disabled until the Node adapter story is redesigned.

## Current Export Shape

[`node/package.json`](../../../node/package.json) currently exports these public subpaths. Each listed subpath has both a `types` target and an `import` target, so the package contract is two-sided: consumers need the declaration shape and the runtime export shape to agree.

The package currently uses one extensionless public specifier style (`@jtenner/starshine/validate`, not a second `@jtenner/starshine/validate.js` alias), has no wildcard export patterns, and has no `require` condition because the package is ESM-first. Adding a new public helper normally belongs inside one of the existing subpaths; adding a new subpath or an extensioned alias broadens the package API and should be reviewed like a semver-relevant public surface.

| Subpath | Purpose | Current status |
| --- | --- | --- |
| `.` | Barrel re-export surface | Public convenience layer with root `types` / `main` metadata plus explicit export-map entry. |
| `./binary` | Decode / encode binary wasm | Full top-level wrapper surface in the original audit. |
| `./cli` | Parse CLI flags and config-shaped inputs | Useful, but still behind the full MoonBit closed-world parser state. |
| `./cmd` | Packaged command pipeline, cmd fuzz harness, differential hooks | Highest-priority April drift is now repaired by parity tests. |
| `./lib` | Public module constructors and value wrappers | Broad constructor surface; examples exercise module-from-scratch paths. |
| `./validate` | Module validation and selected validator helpers | Intentionally partial; now the largest grouped wrapper-drift surface. |
| `./wast` / `./wat` | Text parsing, printing, and spec helpers | File/suite spec helpers exist, but command-level static assertions and arbitrary-feature stats still lag MoonBit. |

The MoonBit workspace/package topology is cataloged in [`moonbit-workspace-package-map.md`](moonbit-workspace-package-map.md). Active MoonBit package surfaces under [`src/`](../../../src/) include `binary`, `bitset`, `cli`, `cli-benchmarks`, `cmd`, `diff`, `fs`, `fuzz`, `ir`, `lib`, `passes`, `passes_perf_long`, `spec_runner`, `validate`, `validate_proof`, `validate_trace`, `wast`, and `wat`.
Node deliberately omits several of those (`bitset`, `cli-benchmarks`, `diff`, `fs`, `fuzz`, `ir`, `passes`, `passes_perf_long`, `spec_runner`, `validate_proof`, and `validate_trace`), and the package map owns the normal `moon.pkg` / `is-main` / generated-interface distinction plus the current `spec_runner` `imports.mbt` topology exception behind that statement.
That omission is acceptable only while the README and tests keep the package framed as a partial host boundary, not as the whole Starshine implementation surface.

## Export-Map Health Contract

Start every Node package audit from [`node/package.json#exports`](../../../node/package.json), not from the full `node/` directory and not from every generated MoonBit interface. The current official Node package docs and TypeScript module-resolution docs, captured in [`../raw/node/2026-06-04-node-package-export-and-wrapper-drift-recheck.md`](../raw/node/2026-06-04-node-package-export-and-wrapper-drift-recheck.md), make the export map the consumer-facing boundary: unlisted package subpaths are private to package resolution, and TypeScript resolves declaration targets through Node-aware `exports` conditions.

Use this audit shape:

| Step | Question | Starshine rule |
| --- | --- | --- |
| 1. Public subpaths | Which subpaths are listed under `exports`? | Only `.`, `./binary`, `./cli`, `./cmd`, `./lib`, `./validate`, `./wast`, and `./wat` are public today. Do not file `src/ir`, `src/passes`, `src/spec_runner`, or `node/internal/*` omissions as Node API drift unless a design decision adds a public subpath. |
| 2. Runtime/declaration parity | Does each public subpath have both `import` and `types` targets, and do those files agree? | Every current export has both targets. Wrapper work must update `.js`, `.d.ts`, README, and tests together; a declaration-only helper or runtime-only helper is an API bug. |
| 3. Specifier style | Is there exactly one public spelling for each subpath? | Keep the current extensionless style. Adding `./validate.js` next to `./validate` broadens the public API and should be treated as a semver-relevant decision, not a convenience alias. |
| 4. MoonBit parity classification | If a generated MoonBit symbol is missing from Node, why? | Classify it as `public-required-now`, `adapter-unsupported`, `intentionally-omitted`, or `compat-alias`. The `cmd` parity repair is the model; `validateModuleWithTrace(...args: never[])` is an adapter-unsupported placeholder, not a ready public callback API. |
| 5. Test ownership | Which test proves the public boundary? | Extend [`node/test/api-parity.test.mjs`](../../../node/test/api-parity.test.mjs) for export/declaration/runtime shape. Use [`node/test/smoke.test.mjs`](../../../node/test/smoke.test.mjs) and [`node/test/examples.test.mjs`](../../../node/test/examples.test.mjs) for behavior and example coverage. |

This keeps package health checks small and reviewable. A broad “mirror all `pkg.generated.mbti` symbols” test would be noisy and wrong because the package is intentionally partial. A useful stronger test is export-map-driven: enumerate public subpaths, read their `types` and `import` files, and then assert only the symbols that this page classifies as required for that subpath.

## Current Gap-To-Action Ledger

| Subpath | Current high-value gap | First useful slice | Required evidence before docs call it ready |
| --- | --- | --- | --- |
| `./cli` | The MoonBit parser surface has `resolve_closed_world(...)`, `CliParseError::invalid_dump_path(...)`, `CliParseError::invalid_function_index_list(...)`, and `CliParseResult.closed_world`, while `node/cli.*` still omits them. | Add `resolveClosedWorld(...)`, the two parse-error constructors, and the `closedWorld` constructor/result slot, or document a permanent split where only `cmd` exposes resolved closed-world state. | Runtime export, `.d.ts` declaration, `api-parity.test.mjs` assertion against [`src/cli/pkg.generated.mbti`](../../../src/cli/pkg.generated.mbti), and README note if the split remains intentional. |
| `./wast` | File/suite spec helpers exist, but command-level static assertion classification does not. | Add `evaluateWastStaticAssertion(...)` plus result/stage/kind types only if the wasm-gc adapter can expose the shape ergonomically. | Wrapper tests for `assert_malformed`, `assert_invalid`, and `assert_unlinkable`; cross-link to [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md) because that page owns stage semantics. |
| `./wast` | `wast_arbitrary_feature_stats(...)` is MoonBit-only. | Treat this as fuzz/reporting API, not as part of the static assertion slice. | Runtime/declaration parity plus a small fixture proving the returned feature facts match WAST arbitrary docs before advertising it to JS consumers. |
| `./validate` | Diagnostics / invalid-AST repro helpers are MoonBit-only. | Expose `validationIssueFamily(...)`, the invalid-AST registry/lookup helpers, and stable-id minimal-repro builders before broad GenValid parity. | API parity tests plus examples or smoke coverage that avoid parsing human validation messages; link to [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md). |
| `./validate` | Current invalid-fuzz naming differs (`runValidateInvalidFuzz` versus MoonBit `run_validate_invalid_ast_fuzz(...)`). | Add compatibility aliases or write a semver plan before removing the old name. | Parity tests must show which name is canonical and which aliases remain supported. |
| `./validate` | Configured `gen_valid` profiles and feature-ledger helpers are absent. | Land after diagnostics/repro, because generator parity has a larger type surface. | Wrapper tests tied to [`src/validate/pkg.generated.mbti`](../../../src/validate/pkg.generated.mbti) plus docs that distinguish generator profiles from fuzz suite profiles. |

## What Changed Since The 2026-04-18 Audit

The archived audit at [`../raw/research/0110-2026-04-18-node-package-api-audit.md`](../raw/research/0110-2026-04-18-node-package-api-audit.md) correctly identified `cmd` as the most urgent drift point at that time.
That specific status is now stale:

- [`node/cmd.d.ts`](../../../node/cmd.d.ts) declares `CmdFuzzStats`, `runCmdFuzzHarness(...)`, and `runCmdFuzzHarnessProfile(...)`.
- [`node/cmd.js`](../../../node/cmd.js) now exports the same parity names and keeps `WasmSmithFuzzStats`, `runWasmSmithFuzzHarness(...)`, and `runWasmSmithFuzzHarnessProfile(...)` as compatibility aliases.
- [`node/cmd.d.ts`](../../../node/cmd.d.ts) and [`node/cmd.js`](../../../node/cmd.js) both carry `CmdIO.printTextModule` and `CmdRunSummary.closedWorld`.
- [`node/test/api-parity.test.mjs`](../../../node/test/api-parity.test.mjs) now asserts the renamed fuzz symbols, compatibility aliases, `CmdIO.printTextModule`, and `CmdRunSummary.closedWorld` in both runtime and declaration surfaces.
- [`node/README.md`](../../../node/README.md) documents the parity names, legacy aliases, and the caveat that `printTextModule` is present for API parity but is not yet routed through the checked-in JS command bridge.

The new teaching rule is therefore: **`cmd` is no longer the top correctness cleanup; it is the model for the kind of explicit parity coverage other Node subpaths still need.**

## Still-Open Drift And Why It Matters

### `cli`: closed-world state is only partially exposed

[`src/cli/pkg.generated.mbti`](../../../src/cli/pkg.generated.mbti) exposes `resolve_closed_world(...)`, two additional parse-error constructors (`invalid_dump_path(...)` and `invalid_function_index_list(...)`), and a `CliParseResult::new(...)` shape with `closed_world?` before `tracing?`.
[`node/cli.d.ts`](../../../node/cli.d.ts) still lacks `resolveClosedWorld(...)`, those two parse-error constructors, and the `closedWorld` constructor slot.

The packaged [`node/cmd.js`](../../../node/cmd.js) bridge compensates inside the command wrapper by parsing config/env/CLI closed-world state itself and returning a truthful `CmdRunSummary.closedWorld`; the local runtime command precedence is summarized in [`cli-command-and-dispatcher.md`](./cli-command-and-dispatcher.md).
That is useful for `cmd`, but it does not make `node/cli` a full parser-parity surface.

### `validate`: grouped wrapper-drift slices remain absent

[`src/validate/pkg.generated.mbti`](../../../src/validate/pkg.generated.mbti) now exposes many validation, configured-generation, invalid-AST, diagnostic, feature-ledger, and typechecker helpers.
[`node/validate.d.ts`](../../../node/validate.d.ts) remains intentionally smaller.
The open drift is better treated as grouped JS-facing slices than as one giant parity task:

1. **Diagnostics and invalid-repro slice:** `validation_issue_family(...)` / `validationIssueFamily(...)`, `validate_invalid_ast_registry(...)`, `validate_invalid_ast_strategy_by_stable_id(...)`, `build_validate_invalid_ast_minimal_repro_by_stable_id(...)`, and their supporting strategy-spec/result types.
2. **Renamed invalid-AST fuzz slice:** current MoonBit exposes `run_validate_invalid_ast_fuzz(...)` and `ValidateInvalidAstFuzzStats`; Node still exposes older `runValidateInvalidFuzz(...)` / `ValidateInvalidFuzzStats` names.
3. **Configured GenValid slice:** `default_gen_valid_config(...)`, `gen_valid_module_with_config(...)`, `gen_valid_module_result(...)`, `gen_valid_module_result_from_seed(...)`, profile lookup/name helpers, random-stream labels, and feature-toggle / feature-ledger helpers.
4. **Focused validator-entry slice:** `validate_defined_func_against_module(...)` plus any small helper types needed by JS-side reduced-function repros.
5. **Internal typechecker/proof-adjacent helpers:** `tc_state_*`, owned-stack helpers, and low-level `Env` additions are not the first Node priority unless a public debugging workflow needs them.

The focused diagnostics/repro contract in [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md) explains why the first slice should land before broad generator parity: consumers need the family mapper, stable-id registry lookup, and minimal repro generation together to build reliable invalid-case reports instead of parsing human-readable validator messages.

`validate_module_with_trace(...)` is also valuable conceptually, but [`node/validate.js`](../../../node/validate.js) currently exposes `validateModuleWithTrace` as an unsupported higher-order export because the wasm-gc adapter cannot pass callback parameters through that path.
Do not document it as ready for JS consumers until the adapter story changes.

### `wast`: file/suite spec helpers exist, but command-level static assertions are missing

[`src/wast/pkg.generated.mbti`](../../../src/wast/pkg.generated.mbti) exposes `evaluate_wast_static_assertion(...)`, whose stage model is documented in [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md).
[`node/wast.d.ts`](../../../node/wast.d.ts) already exposes `runWastSpecFile(...)` and `runWastSpecSuite(...)`, but it does not currently expose an `evaluateWastStaticAssertion(...)` wrapper or the result/stage/kind types that would make command-level assertion classification ergonomic.
That is a small but useful gap for JS-side spec-harness tooling because it would let Node consumers reuse Starshine's static-assertion semantics for `assert_malformed`, `assert_invalid`, and `assert_unlinkable` instead of reimplementing or shelling out.

The current MoonBit `wast` package also exposes `wast_arbitrary_feature_stats(...)`, but Node does not expose `wastArbitraryFeatureStats(...)` or `WastArbitraryFeatureStats`. Treat that as a fuzz/reporting wrapper gap, not as part of the static-assertion API slice.

## Maintenance And Validation Guidance

Use these checks when touching the Node package or documenting its surface:

1. **Wrapper parity:** run or update [`node/test/api-parity.test.mjs`](../../../node/test/api-parity.test.mjs) for any intentional `.d.ts` / runtime export shape change.
2. **Smoke behavior:** keep [`node/test/smoke.test.mjs`](../../../node/test/smoke.test.mjs) green for binary/text validation, `cmd` adapter hooks, differential validation, fuzz-report persistence, closed-world summary precedence, and WASI startup.
3. **Examples:** keep [`node/test/examples.test.mjs`](../../../node/test/examples.test.mjs) green so the checked-in published examples still exercise the public API.
4. **Build boundary:** remember that [`npm run build`](../../../node/package.json) rebuilds the WASI CLI artifact through [`scripts/lib/build-node-package.mjs`](../../../scripts/lib/build-node-package.mjs), but does not regenerate every JS/TS wrapper from MoonBit.
5. **Docs truthfulness:** when adding a wrapper, update [`node/README.md`](../../../node/README.md), this page, the release checklist in [`release-process.md`](release-process.md) if package contents or versioning change, and any relevant top-level API docs together.

A future stronger parity test should compare:

- [`src/*/pkg.generated.mbti`](../../../src/)
- [`node/*.d.ts`](../../../node/)
- [`node/*.js`](../../../node/)
- [`node/package.json#exports`](../../../node/package.json)

The comparison must start from the `exports` allowlist, not from every file in `node/` or every package under `src/`: unlisted subpaths are intentionally private for package consumers. That test should distinguish four cases instead of requiring blanket parity:

1. public and required now,
2. intentionally unsupported through the wasm-gc adapter,
3. intentionally omitted from the partial Node package,
4. renamed compatibility aliases that must remain documented and tested until a semver decision removes them.

## Recommended Widening Order

1. Keep `cmd` parity tests as the template and extend similar declaration/runtime checks to `cli`, `validate`, and `wast`, driven from `node/package.json#exports`.
2. Add `cli` closed-world parity (`resolveClosedWorld`, parse-error constructors, and `CliParseResult.closedWorld`) or document a permanent split if `cmd` remains the only closed-world consumer.
3. Add the small `wast.evaluateWastStaticAssertion(...)` wrapper, with result/stage/kind types or a deliberately JS-friendly object result.
4. Add the high-value `validate` diagnostics / invalid-AST repro slice before the broader GenValid and feature-ledger slice.
5. Reconcile the older `runValidateInvalidFuzz` naming with the current MoonBit `run_validate_invalid_ast_fuzz(...)` surface through either a compatibility alias or a documented semver plan.
6. Only then decide whether to add new package subpaths such as `diff`, `validate_trace`, or `fuzz`; exposing `ir` and `passes` should be treated as a larger API-design decision, not a parity cleanup.

## Sources

- Node/TypeScript package export bridge and drift refresh: [`../raw/node/2026-06-04-node-package-export-and-wrapper-drift-recheck.md`](../raw/node/2026-06-04-node-package-export-and-wrapper-drift-recheck.md), [`../raw/node/2026-05-20-node-package-export-boundary.md`](../raw/node/2026-05-20-node-package-export-boundary.md)
- Archived baseline audit: [`../raw/research/0110-2026-04-18-node-package-api-audit.md`](../raw/research/0110-2026-04-18-node-package-api-audit.md)
- Package metadata and README: [`../../../node/package.json`](../../../node/package.json), [`../../../node/README.md`](../../../node/README.md)
- Current Node parity and smoke tests: [`../../../node/test/api-parity.test.mjs`](../../../node/test/api-parity.test.mjs), [`../../../node/test/smoke.test.mjs`](../../../node/test/smoke.test.mjs), [`../../../node/test/examples.test.mjs`](../../../node/test/examples.test.mjs)
- Build/generation boundary: [`../../../scripts/lib/generate-node-package.mjs`](../../../scripts/lib/generate-node-package.mjs), [`../../../scripts/lib/build-node-package.mjs`](../../../scripts/lib/build-node-package.mjs)
- Runtime command contract: [`./cli-command-and-dispatcher.md`](./cli-command-and-dispatcher.md)
- Release/package publication checklist: [`./release-process.md`](release-process.md)
- Validator diagnostics/repro contract: [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md)
- WAST static assertion stage model: [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md)
- MoonBit workspace/package map: [`./moonbit-workspace-package-map.md`](moonbit-workspace-package-map.md), [`../raw/moonbit/2026-05-20-workspace-package-surface.md`](../raw/moonbit/2026-05-20-workspace-package-surface.md)
- MoonBit source signatures: [`../../../src/cli/pkg.generated.mbti`](../../../src/cli/pkg.generated.mbti), [`../../../src/cmd/pkg.generated.mbti`](../../../src/cmd/pkg.generated.mbti), [`../../../src/validate/pkg.generated.mbti`](../../../src/validate/pkg.generated.mbti), [`../../../src/wast/pkg.generated.mbti`](../../../src/wast/pkg.generated.mbti)
