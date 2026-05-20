---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
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
The public boundary is the explicit [`node/package.json`](../../../node/package.json) `exports` map: Node resolves only the listed package subpaths, and TypeScript must resolve matching declaration files through the same listed surface. The 2026-05-20 source bridge in [`../raw/node/2026-05-20-node-package-export-boundary.md`](../raw/node/2026-05-20-node-package-export-boundary.md) records the current Node and TypeScript package-resolution rules checked for that claim.

The current flow has two important artifacts:

1. [`scripts/lib/generate-node-package.mjs`](../../../scripts/lib/generate-node-package.mjs) intentionally throws because the old generator depended on the legacy `src/node_api` adapter and removed pass ports.
2. [`scripts/lib/build-node-package.mjs`](../../../scripts/lib/build-node-package.mjs) rebuilds the optimized WASI CLI artifact from `src/cmd`, copies it to `node/internal/starshine.wasm-wasi.wasm`, and keeps the checked-in `node/internal/starshine.wasm-gc.wasm` boundary artifact.

That split is the main invariant for maintainers: **do not assume `npm run build` refreshes all JS/TS wrappers from the current MoonBit signatures.** The package README now states the same boundary: build refreshes the WASI CLI artifact only, while wrapper generation remains disabled until the Node adapter story is redesigned.

## Current Export Shape

[`node/package.json`](../../../node/package.json) currently exports these public subpaths. Each listed subpath has both a `types` target and an `import` target, so the package contract is two-sided: consumers need the declaration shape and the runtime export shape to agree.

| Subpath | Purpose | Current status |
| --- | --- | --- |
| `.` | Barrel re-export surface | Public convenience layer. |
| `./binary` | Decode / encode binary wasm | Full top-level wrapper surface in the original audit. |
| `./cli` | Parse CLI flags and config-shaped inputs | Useful, but still behind the full MoonBit closed-world parser state. |
| `./cmd` | Packaged command pipeline, cmd fuzz harness, differential hooks | Highest-priority April drift is now repaired by parity tests. |
| `./lib` | Public module constructors and value wrappers | Broad constructor surface; examples exercise module-from-scratch paths. |
| `./validate` | Module validation and selected validator helpers | Intentionally partial; still the largest missing high-value surface. |
| `./wast` / `./wat` | Text parsing, printing, and spec helpers | Mostly covered; `wast.evaluate_wast_static_assertion(...)` remains absent from Node. |

The MoonBit workspace/package topology is cataloged in [`moonbit-workspace-package-map.md`](moonbit-workspace-package-map.md). Active MoonBit package surfaces under [`src/`](../../../src/) include `binary`, `bitset`, `cli`, `cli-benchmarks`, `cmd`, `diff`, `fs`, `fuzz`, `ir`, `lib`, `passes`, `passes_perf_long`, `spec_runner`, `validate`, `validate_proof`, `validate_trace`, `wast`, and `wat`.
Node deliberately omits several of those (`bitset`, `cli-benchmarks`, `diff`, `fs`, `fuzz`, `ir`, `passes`, `passes_perf_long`, `spec_runner`, `validate_proof`, and `validate_trace`), and the package map owns the `moon.pkg` / `is-main` / generated-interface distinction behind that statement.
That omission is acceptable only while the README and tests keep the package framed as a partial host boundary, not as the whole Starshine implementation surface.

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

### `validate`: high-value public helpers remain absent

[`src/validate/pkg.generated.mbti`](../../../src/validate/pkg.generated.mbti) now exposes many validation, configured-generation, invalid-AST, diagnostic, and feature-ledger helpers.
[`node/validate.d.ts`](../../../node/validate.d.ts) remains intentionally smaller.
The highest-value missing Node additions are still:

1. `validation_issue_family(...)` / `validationIssueFamily(...)`
2. `validate_defined_func_against_module(...)` / `validateDefinedFuncAgainstModule(...)`
3. `default_gen_valid_config(...)` / `defaultGenValidConfig(...)`
4. `gen_valid_module_with_config(...)` / `genValidModuleWithConfig(...)`
5. `validate_invalid_ast_registry(...)` / `validateInvalidAstRegistry(...)`
6. `validate_invalid_ast_strategy_by_stable_id(...)` / `validateInvalidAstStrategyByStableId(...)`
7. `build_validate_invalid_ast_minimal_repro_by_stable_id(...)` / `buildValidateInvalidAstMinimalReproByStableId(...)`

The focused diagnostics/repro contract in [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md) explains why the first, fifth, sixth, and seventh items are a coherent JS-facing slice: consumers need the family mapper, stable-id registry lookup, and minimal repro generation together to build reliable invalid-case reports instead of parsing human-readable validator messages.

`validate_module_with_trace(...)` is also valuable conceptually, but [`node/validate.js`](../../../node/validate.js) currently exposes `validateModuleWithTrace` as an unsupported higher-order export because the wasm-gc adapter cannot pass callback parameters through that path.
Do not document it as ready for JS consumers until the adapter story changes.

### `wast`: the static assertion evaluator is missing

[`src/wast/pkg.generated.mbti`](../../../src/wast/pkg.generated.mbti) exposes `evaluate_wast_static_assertion(...)`, whose stage model is documented in [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md).
[`node/wast.d.ts`](../../../node/wast.d.ts) does not currently expose an `evaluateWastStaticAssertion(...)` wrapper.
That is a small but useful gap for JS-side spec-harness tooling because it would let Node consumers reuse Starshine's static-assertion semantics for `assert_malformed`, `assert_invalid`, and `assert_unlinkable` instead of reimplementing or shelling out.

## Maintenance And Validation Guidance

Use these checks when touching the Node package or documenting its surface:

1. **Wrapper parity:** run or update [`node/test/api-parity.test.mjs`](../../../node/test/api-parity.test.mjs) for any intentional `.d.ts` / runtime export shape change.
2. **Smoke behavior:** keep [`node/test/smoke.test.mjs`](../../../node/test/smoke.test.mjs) green for binary/text validation, `cmd` adapter hooks, differential validation, fuzz-report persistence, closed-world summary precedence, and WASI startup.
3. **Examples:** keep [`node/test/examples.test.mjs`](../../../node/test/examples.test.mjs) green so the checked-in published examples still exercise the public API.
4. **Build boundary:** remember that [`npm run build`](../../../node/package.json) rebuilds the WASI CLI artifact through [`scripts/lib/build-node-package.mjs`](../../../scripts/lib/build-node-package.mjs), but does not regenerate every JS/TS wrapper from MoonBit.
5. **Docs truthfulness:** when adding a wrapper, update [`node/README.md`](../../../node/README.md), this page, and any relevant top-level API docs together.

A future stronger parity test should compare:

- [`src/*/pkg.generated.mbti`](../../../src/)
- [`node/*.d.ts`](../../../node/)
- [`node/*.js`](../../../node/)
- [`node/package.json#exports`](../../../node/package.json)

The comparison must start from the `exports` allowlist, not from every file in `node/` or every package under `src/`: unlisted subpaths are intentionally private for package consumers. That test should distinguish three cases instead of requiring blanket parity:

1. public and required now,
2. intentionally unsupported through the wasm-gc adapter,
3. intentionally omitted from the partial Node package.

## Recommended Widening Order

1. Keep `cmd` parity tests as the template and extend similar declaration/runtime checks to `cli`, `validate`, and `wast`.
2. Add `cli` closed-world parity (`resolveClosedWorld`, parse-error constructors, and `CliParseResult.closedWorld`) or document a permanent split if `cmd` remains the only closed-world consumer.
3. Add the small `wast.evaluateWastStaticAssertion(...)` wrapper.
4. Add the high-value `validate` helpers listed above, preferring diagnostics, stable invalid repros, and configured valid generation over low-level `tc_state_*` internals.
5. Only then decide whether to add new package subpaths such as `diff`, `validate_trace`, or `fuzz`; exposing `ir` and `passes` should be treated as a larger API-design decision, not a parity cleanup.

## Sources

- Node/TypeScript package export bridge: [`../raw/node/2026-05-20-node-package-export-boundary.md`](../raw/node/2026-05-20-node-package-export-boundary.md)
- Archived baseline audit: [`../raw/research/0110-2026-04-18-node-package-api-audit.md`](../raw/research/0110-2026-04-18-node-package-api-audit.md)
- Package metadata and README: [`../../../node/package.json`](../../../node/package.json), [`../../../node/README.md`](../../../node/README.md)
- Current Node parity and smoke tests: [`../../../node/test/api-parity.test.mjs`](../../../node/test/api-parity.test.mjs), [`../../../node/test/smoke.test.mjs`](../../../node/test/smoke.test.mjs), [`../../../node/test/examples.test.mjs`](../../../node/test/examples.test.mjs)
- Build/generation boundary: [`../../../scripts/lib/generate-node-package.mjs`](../../../scripts/lib/generate-node-package.mjs), [`../../../scripts/lib/build-node-package.mjs`](../../../scripts/lib/build-node-package.mjs)
- Runtime command contract: [`./cli-command-and-dispatcher.md`](./cli-command-and-dispatcher.md)
- Validator diagnostics/repro contract: [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md)
- WAST static assertion stage model: [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md)
- MoonBit workspace/package map: [`./moonbit-workspace-package-map.md`](moonbit-workspace-package-map.md), [`../raw/moonbit/2026-05-20-workspace-package-surface.md`](../raw/moonbit/2026-05-20-workspace-package-surface.md)
- MoonBit source signatures: [`../../../src/cli/pkg.generated.mbti`](../../../src/cli/pkg.generated.mbti), [`../../../src/cmd/pkg.generated.mbti`](../../../src/cmd/pkg.generated.mbti), [`../../../src/validate/pkg.generated.mbti`](../../../src/validate/pkg.generated.mbti), [`../../../src/wast/pkg.generated.mbti`](../../../src/wast/pkg.generated.mbti)
