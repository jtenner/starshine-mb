---
kind: concept
status: supported
last_reviewed: 2026-10-10
sources:
  - https://webassembly.github.io/esm-integration/js-api/index.html
  - https://nodejs.org/api/wasi.html
  - ../wasm-jspi-host-async-boundary.md
  - ../wasm-js-string-builtins-boundary.md
  - https://docs.npmjs.com/trusted-publishers
  - https://docs.npmjs.com/generating-provenance-statements
  - https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
  - ../../../.github/workflows/node-wasm-tests.yml
  - ../../../.github/workflows/fuzz.yml
  - ../../../.github/workflows/readme-api-sync.yml
  - https://nodejs.org/api/packages.html
  - https://www.typescriptlang.org/docs/handbook/modules/reference.html
  - https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html
  - ../../../node/package.json
  - ../../../node/README.md
  - ../../../node/internal/.gitignore
  - ../../../node/internal/.npmignore
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
  - ./wasi-runner-and-preview-boundary.md
  - ../wasm-jspi-host-async-boundary.md
  - ../wasm-esm-integration-boundary.md
  - ../wasm-js-string-builtins-boundary.md
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

The `node/` package is an ESM boundary for `@jtenner/starshine`, with generated
WasmGC bindings and declarations plus a retained JavaScript callback command
facade. The October 10 beta build replaces the former frozen-artifact route.
Function signatures come from the generated FFI export schema; unsupported
callbacks/raising/generics remain explicit placeholders. Deeper compiler
internals remain outside the package export map.
The public boundary is the explicit [`node/package.json`](../../../node/package.json) `exports` map: Node resolves only the listed package subpaths, and TypeScript must resolve matching declaration files through the same listed surface. The official [Node package documentation](https://nodejs.org/api/packages.html) and [TypeScript module-resolution reference](https://www.typescriptlang.org/docs/handbook/modules/reference.html) support the package-resolution rules behind that claim: unlisted subpaths stay private, export targets must be package-relative `./...` paths, TypeScript follows `exports` in Node-aware modes, and each public subpath needs declaration/runtime parity.

[`scripts/lib/generate-node-package.mjs`](../../../scripts/lib/generate-node-package.mjs)
selects authoritative signatures from
[`ffi/src/ffi/export-schema.generated.json`](../../../ffi/src/ffi/export-schema.generated.json)
and generates the concrete `ffi/src/npm` adapter and JS/TS files. Reviewed
constructor-order and callback-facade projections preserve intentional compatibility.
[`scripts/lib/build-node-package.mjs`](../../../scripts/lib/build-node-package.mjs)
compiles that adapter, a fresh native bootstrap and the WASI CLI. It preserves
raw baselines, applies Starshine O4s (`--optimize --optimize-level 4 --shrink-level 1`), validates input/output
with wasm-tools and compares copied-package API and CLI behavior before promotion.
Failure prevents packing. The build verifies the effective levels and exact five-pass
queue; literal `-O4s` is unsupported and levels 4/1 use the current fast preset,
not the full O4z scheduler at 4/4. Current O4s qualification reduces WasmGC by
164,569 bytes and WASI by 400,880 bytes, with before/after API and CLI parity.
This supersedes O1's zero-size-change qualification at `279aaf642`; its tarball,
artifacts and reports remain in `dist/npm/qualified-o1-279aaf642/`.
The [handoff](../../npm-beta-handoff.md) records exact hashes and the higher local
optimization time. No size or runtime improvement is promised for future builds.
The separate bootstrap fixture transforms 70 to 54 bytes with identical result 84.

The adapter requires Node 25+ with WasmGC and JS string builtins. All ESM imports
await shared initialization. Named values are instance-owned GC handles with no
explicit disposal. See [the package README](../../../node/README.md) for mappings,
errors, the complete tested build/install workflow and release decisions. The JS builtins versus `stringref` / `StringRefsSec` split is documented in [`../wasm-js-string-builtins-boundary.md`](../wasm-js-string-builtins-boundary.md); current Node runtime code does not pass `importedStringConstants`. The adjacent active JS Primitive Builtins and JS Text Encoding Builtins proposals are not enabled or modeled by the current wrapper; route any future `wasm:js-number`, `wasm:js-bigint`, or `wasm:text-encoding` runtime work through [`../wasm-js-primitive-and-text-encoding-builtins-boundary.md`](../wasm-js-primitive-and-text-encoding-builtins-boundary.md).

The package's async loading is also **not JSPI support**. [`node/internal/runtime.js`](../../../node/internal/runtime.js) and [`node/internal/wasi-runner.js`](../../../node/internal/wasi-runner.js) use ordinary JavaScript `async` / `await` around file I/O, compile/instantiate, and WASI execution, but current code does not construct `WebAssembly.Suspending` wrappers, call `WebAssembly.promising(...)`, or advertise Promise-suspending imports/exports. Route future JavaScript Promise Integration work through [`../wasm-jspi-host-async-boundary.md`](../wasm-jspi-host-async-boundary.md) so it stays separate from JS String Builtins, Component Model / WASI, WAST/binary/validator support, and optimizer pass evidence.

The ESM-first package format is also **not WebAssembly ESM Integration support**. Current [`node/package.json`](../../../node/package.json) exposes JavaScript wrapper subpaths, while [`node/internal/runtime.js`](../../../node/internal/runtime.js) and [`node/internal/wasi-runner.js`](../../../node/internal/wasi-runner.js) load wasm artifacts by reading bytes and calling the JavaScript `WebAssembly.compile(...)` / `instantiate(...)` APIs directly. They do not use source-phase `import source`, dynamic `import.source(...)`, instance-phase `.wasm` namespace imports, or package `.wasm` export targets. Node v26.4.0 documents source and instance imports as distinct loader surfaces. In its instance-import path, `wasm-js:` is reserved in module import names, module names, and export names, while `wasm:` remains allowed as an imported module name but is reserved in module/export names. Starshine has no package policy or test for those host-loader rules, and they are not Core validation rules. Route future Wasm ESM import work through [`../wasm-esm-integration-boundary.md`](../wasm-esm-integration-boundary.md) so it stays separate from ordinary package metadata, JS String Builtins, JSPI, Component Model / WASI, and Core-module validation.

The package's `starshine.wasm-wasi.wasm` runner path is **WASI Preview 1 Core-module execution**, not WASI Preview 2 / WASI 0.2, WASI Preview 3 / WASI 0.3, or Component Model support. [`node/internal/wasi-runner.js`](../../../node/internal/wasi-runner.js) constructs Node's experimental `WASI` object with `version: "preview1"`, manually merges `wasi_snapshot_preview1: wasi.wasiImport` with Starshine/MoonBit-specific host shims, and runs `_start` or initializes a reactor. Node now also documents `getImportObject()` and `finalizeBindings(...)`; current Starshine runners deliberately do not use the former or directly invoke the latter, while their normal `start` / `initialize` paths finalize ordinary bindings internally. Package smoke still is not WASI-thread evidence because there is no child-thread binding or worker policy. Route runtime, import-module, sandboxing, and `*-wasi.wasm` artifact claims through [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md) so they stay separate from package export-map parity, JSPI, Wasm ESM Integration, and Component Model claims.

There is one packaging caveat: the wasm artifacts are Git-ignored by [`node/internal/.gitignore`](../../../node/internal/.gitignore) but deliberately kept publishable by [`node/internal/.npmignore`](../../../node/internal/.npmignore). The build regenerates both artifacts from live source; `npm pack` runs it through
`prepack`. The allowlist excludes source, schema, tests, raw baselines and reports.
[`scripts/test/npm-packed-consumers.mjs`](../../../scripts/test/npm-packed-consumers.mjs)
installs the exact tarball into empty JavaScript and strict TypeScript consumers
outside the source tree and exercises every public export and the CLI.


## October 10, 2026 — Cold npm bootstrap deadline

The first published npm prep head `9057a5d8` failed its
[packed-package CI job](https://github.com/jtenner/starshine-mb/actions/runs/38028151417/job/114143304259)
while compiling the fresh native release bootstrap: `spawnSync moon ETIMEDOUT`
at 180 seconds. The successful baseline
[release job](https://github.com/jtenner/starshine-mb/actions/runs/38014936990/job/114103005410)
took 328,583 ms for native compilation, so the old compiler budget was below
an observed successful cold build. No npm tarball was produced by the failed job.

[`npm-process.mjs`](../../../scripts/lib/npm-process.mjs) gives compiler commands
15 minutes and the packed-consumer harness's whole pack/prepack command 30
minutes. Optimizer commands retain three minutes; consumer commands retain four.
CI is bounded to 45 minutes. Overrides reject unbounded/invalid values. Full
compiler/pack logs and early bootstrap error reports survive failed builds.
On the tested Linux host, timeout cleanup freezes the command's root group,
inventories descendants with `ps`, and kills nested groups as well. A red-first
[regression](../../../scripts/lib/npm-process.test.ts) reproduced the old orphan
and now protects completion, independent optimizer limits and process cleanup.

The exact follow-up head `564c11e` passed the
[cold package CI run](https://github.com/jtenner/starshine-mb/actions/runs/38029914397)
in 360,624 ms of build time. The Node 25.9.0 / TypeScript 5.8.3 consumers checked
all nine exports; the resulting archive is byte-identical to the local package
(4,822,175 bytes, SHA-256 `2c20fd47b4fd4b9bbe0ab179329bbbb0b3aa919f630d411cb2522e47ec64deb0`).
`latest` supplied the documented Moon 0.1.20260920 / moonc 0.10.14 snapshot.
This closes the package compilation timeout on that head, while native-debug
issue #1322 and the retained coverage gate remain separate open work. The three
required checks and Fuzz Suites passed on this exact head.

The source-owned [`unsupported ABI policy`](../../../ffi/src/npm/unsupported-abi-policy.json)
records the 23 existing compatibility exceptions without duplicating signatures.
Generation rejects new unsupported mappings, changed reasons and stale policy
entries before formatting or writing generated artifacts. Pure tests and real
generator fault injection verify rejection and unchanged output hashes.

The [handoff](../../npm-beta-handoff.md#published-head-ci-and-cold-build-follow-up)
preserves exact CI links, raw artifacts and the initial push's unexpected
implicit protection bypass. Follow-up source publication must first satisfy the
required checks without altering protections. Matching native-debug examples
failures and coverage evidence remain separate; this fix does not clear issue
#1322 or release licensing. Fresh exact-head CI is required for qualification.

## October 10, 2026 — Same-input Binaryen comparison

This frozen checkpoint qualifies source head
`754562d4f5e822d5f1ae630be79cbb19c6e669bd`. The selected npm build uses
**neither Binaryen transformation nor Binaryen validation**: native Starshine
transforms and wasm-tools validates. Source publication was subsequently
authorized; npm publication and licensing remain release decisions. The user
requested a separate Sol 6.1 High task to fix the observed discrepancy.

Both optimizers read copies of the identical original name-stripped compiler
artifacts. No chained optimization or idempotence comparison was performed.
Matching optimization/shrink knobs do not imply matching pass queues: current
Starshine O4s levels 4/1 select its five-pass fast queue, while Binaryen's supported
`-O4 -s 1` selects its own default pipeline. Binaryen `-Oz` is a separate size preset.

| Artifact | Original bytes | Optimizer | Output bytes | Seconds | Peak RSS MiB | Controls |
| --- | ---: | --- | ---: | ---: | ---: | --- |
| WasmGC | 7,452,107 | Starshine O4s | 7,287,538 | 8.239 | 255.6 | pass |
| WasmGC | 7,452,107 | Binaryen `-O4 -s 1` | 5,545,109 | 25.986 | 1,003.1 | pass |
| WasmGC | 7,452,107 | Binaryen `-Oz` | 5,551,472 | 14.909 | 471.4 | pass |
| WASI | 6,748,730 | Starshine O4s | 6,347,850 | 8.469 | 234.9 | pass |
| WASI | 6,748,730 | Binaryen `-O4 -s 1` | 6,148,533 | 28.034 | 1,223.6 | pass |
| WASI | 6,748,730 | Binaryen `-Oz` | 4,857,635 | 10.351 | 489.3 | pass |

Each reported row passes independent validation, preservation of every original
export name (2,849 GC / 2 WASI), unchanged absent `target_features` metadata,
raw-baseline API/CLI-help observations, and isolated exact-candidate packed JS and
strict TypeScript consumers on Node 26.11.1 / TypeScript 5.8.3 across all nine
public entries. The fixtures cover parse/validate/optimize/encode, arithmetic,
locals, GC, errors, bounded fuzz and CLI ambient-stack returns. These bounded
controls do not prove universal semantic equivalence. No performance or size
improvement is promised for other inputs.

The native bootstrap hash is
`26eb438928292397fce2d79700444521a7c881b6ed81b39bf55cc28513d904ed`.
Installed oracle: `wasm-opt version 133 (version_133-60-g93d6e9de7)` from the
local emsdk 6.0.12 installation. Binaryen runs use `BINARYEN_CORES=8`; all
measurements are single serial samples with 60-second transform budgets.
Times exclude validation/consumer tests, and RSS covers optimizer processes.
They are not matched-worker or universal speed comparisons.

Original input SHA-256 (preserved locally in `dist/npm/*.unoptimized` and
`dist/npm/binaryen-comparison/*.unoptimized`):

- WasmGC: `059555428f569dcd57275757be8453a4f4881eb80592f9f80e402b4987072de3`.
- WASI: `b7dd0896d7b41989e1aa29bd297d3fd63097b7e3b7f76883e9897f25010add52`.

Output SHA-256:

- GC / Starshine: `6ace60a63b33dda84c15067ca2ab60b702a6e74e3edb7bfca7d158761984bbea`.
- GC / Binaryen O4s: `7dfda2ce7376008cf6467d11cc360a95ae47115cc843ca6dca2d286858db9099`.
- GC / Binaryen Oz: `bd038e0f18f81737c4c25ab645f643675ea9be7cba22a109519fe574fc320bf7`.
- WASI / Starshine: `40e8be933bb3105aa74a1d54f9f4f350e4695d74ac64a9eceff05aa15bd52570`.
- WASI / Binaryen O4s: `5ea825c5cff80c377410d5ce90fc61588a69fb4ec4586f975485ad9d235e158c`.
- WASI / Binaryen Oz: `afcc27ae7a69fd6a344898395e08e461312f2f475f45e641e1de08cdfb939f02`.

Reproduce from the checkout with the toolchains documented in
[`node/README.md`](../../../node/README.md). Preserve the original input hashes
above before rebuilding: if compiler outputs differ, that is a new comparison.
Apply each command to the same original input, writing separate output paths:

```sh
# Starshine: freshly compiled native bootstrap, independent of npm package.
_build/native/release/build/cmd/cmd.exe --optimize --optimize-level 4 \
  --shrink-level 1 INPUT.wasm --out STARSHINE.wasm

# Binaryen: qualify installed version 133 first. This flag set accepts GC input.
BINARYEN_CORES=8 wasm-opt --mvp-features --enable-mutable-globals \
  --enable-sign-ext --enable-nontrapping-float-to-int --enable-bulk-memory \
  --enable-reference-types --enable-multivalue --enable-gc --enable-tail-call \
  --enable-extended-const -O4 -s 1 INPUT.wasm -o BINARYEN-O4S.wasm
# For WASI, additionally pass --enable-simd: the original input already uses it.
# For Oz, replace only -O4 -s 1 with -Oz; retain the same input/features.
wasm-tools validate --features=wasm2,gc,function-references,tail-call,extended-const OUTPUT.wasm
```

The local reproduction helpers and full commands/logs/hashes reside under ignored
`dist/npm/binaryen-comparison/`. `report.json` holds all samples, including
unqualified diagnostics; `comparison.md` summarizes qualified rows. The helpers
`measure-single-worker.py`, `measure-eight-workers.py`,
`measure-runtime-features.py`, `measure-runtime-features-wasi-simd.py`,
`check-exports-features.mjs` and `consumer-controls.py` retain time/RSS and control
procedures. For consumer qualification, the controls clone the selected tarball,
substitute only comparison Wasm files, pack with `--ignore-scripts` to avoid a
rebuild, and run a copied
[`npm-packed-consumers.mjs`](../../../scripts/test/npm-packed-consumers.mjs)
with an explicit candidate archive path in an isolated harness. Do not replace
the selected package or reports with candidate artifacts.

The selected tarball remains 4,821,600 bytes, SHA-256
`0d4cc321fef5554fce32cf95ee30a1d7be30a84380df048e75f07302775d9ab2`.
Separate 47-file comparison tarballs are 2,999,850 bytes (O4s,
`82e675f10c830f4a1c32219af6bf3ace7128517dbb9fc21c4c5cdf88785153fe`)
and 2,891,722 bytes (Oz,
`4ad4d227815963565433b25fa9d6ea845392f645390210973547b0854c199260`).
They are evidence only and are not the selected npm package.

Initial Binaryen `--all-features` outputs introduced custom-descriptor exact
references and compact imports rejected by stock Node, despite passing all-feature
wasm-tools validation; those outputs are unqualified. Single-worker O4s on both
inputs and GC Oz exceeded 60 seconds. Initial restricted WASI probes omitted its
existing SIMD and failed input validation before optimization. Qualified runs use
the explicit feature set above (plus SIMD for WASI), with no unsafe assumptions,
feature lowering or experimental Node custom-descriptor flag.

## Current Export Shape

[`node/package.json`](../../../node/package.json) currently exports these public subpaths. Each listed subpath has both a `types` target and an `import` target, so the package contract is two-sided: consumers need the declaration shape and the runtime export shape to agree.

The package currently uses one extensionless public specifier style (`@jtenner/starshine/validate`, not a second `@jtenner/starshine/validate.js` alias), has no wildcard export patterns, and has no `require` condition because the package is ESM-first. Adding a new public helper normally belongs inside one of the existing subpaths; adding a new subpath or an extensioned alias broadens the package API and should be reviewed like a semver-relevant public surface.

| Subpath | Purpose | Current status |
| --- | --- | --- |
| `.` | Barrel re-export surface | Public convenience layer with root `types` / `main` metadata plus explicit export-map entry. |
| `./binary` | Decode / encode binary wasm | Full top-level wrapper surface in the original audit. |
| `./cli` | Parse CLI flags and config-shaped inputs | Concrete signatures generated from current FFI; callback gaps stay explicit. |
| `./cmd` | Packaged command pipeline, cmd fuzz harness, differential hooks | Highest-priority April drift is now repaired by parity tests. |
| `./lib` | Public module constructors and value wrappers | Broad constructor surface; examples exercise module-from-scratch paths. |
| `./validate` | Module validation and selected validator helpers | Current concrete FFI signatures; unsupported callbacks are placeholders. |
| `./wast` / `./wat` | Text parsing, printing, and spec helpers | Current concrete FFI signatures and typed unsupported boundaries. |
| `./passes` | `optimizeModule` | Bounded active hot-pipeline facade; full pass internals stay private. |

The MoonBit workspace/package topology is cataloged in [`moonbit-workspace-package-map.md`](moonbit-workspace-package-map.md). Active MoonBit package surfaces under [`src/`](../../../src/) include `binary`, `bitset`, `cli`, `cli-benchmarks`, `cmd`, `diff`, `fs`, `fuzz`, `ir`, `lib`, `passes`, `passes_perf_long`, `spec_runner`, `validate`, `validate_proof`, `validate_trace`, `wast`, and `wat`.
Node deliberately omits several of those (`bitset`, `cli-benchmarks`, `diff`, `fs`, `fuzz`, `ir`, `passes_perf_long`, `spec_runner`, `validate_proof`, and `validate_trace`), and the package map owns the normal `moon.pkg` / `is-main` / generated-interface distinction plus the current `spec_runner` `imports.mbt` topology exception behind that statement.
That omission is acceptable only while the README and tests keep the package framed as a partial host boundary, not as the whole Starshine implementation surface.

## Export-Map Health Contract

Start every Node package audit from [`node/package.json#exports`](../../../node/package.json), not from the full `node/` directory and not from every generated MoonBit interface. The official [Node package documentation](https://nodejs.org/api/packages.html) and [TypeScript module-resolution reference](https://www.typescriptlang.org/docs/handbook/modules/reference.html) make the export map the consumer-facing boundary: unlisted package subpaths are private to package resolution, and TypeScript resolves declaration targets through Node-aware `exports` conditions.

Use this audit shape:

| Step | Question | Starshine rule |
| --- | --- | --- |
| 1. Public subpaths | Which subpaths are listed under `exports`? | Only `.`, `./binary`, `./cli`, `./cmd`, `./lib`, `./validate`, `./wast`, `./wat`, and the bounded `./passes` facade are public today. Do not file `src/ir`, `src/passes`, `src/spec_runner`, or `node/internal/*` omissions as Node API drift unless a design decision adds a public subpath. |
| 2. Runtime/declaration parity | Does each public subpath have both `import` and `types` targets, and do those files agree? | Every current export has both targets. Wrapper work must update `.js`, `.d.ts`, README, and tests together; a declaration-only helper or runtime-only helper is an API bug. |
| 3. Specifier style | Is there exactly one public spelling for each subpath? | Keep the current extensionless style. Adding `./validate.js` next to `./validate` broadens the public API and should be treated as a semver-relevant decision, not a convenience alias. |
| 4. MoonBit parity classification | If a generated MoonBit symbol is missing from Node, why? | Classify it as `public-required-now`, `adapter-unsupported`, `intentionally-omitted`, or `compat-alias`. The `cmd` parity repair is the model; `validateModuleWithTrace(...args: never[])` is an adapter-unsupported placeholder, not a ready public callback API. |
| 5. Test ownership | Which test proves the public boundary? | Extend [`node/test/api-parity.test.mjs`](../../../node/test/api-parity.test.mjs) for export/declaration/runtime shape. Use [`node/test/smoke.test.mjs`](../../../node/test/smoke.test.mjs) and [`node/test/examples.test.mjs`](../../../node/test/examples.test.mjs) for behavior and example coverage. |

This keeps package health checks small and reviewable. A broad “mirror all `pkg.generated.mbti` symbols” test would be noisy and wrong because the package is intentionally partial. A useful stronger test is export-map-driven: enumerate public subpaths, read their `types` and `import` files, and then assert only the symbols that this page classifies as required for that subpath.

## Historical July Gap-To-Action Ledger

The following July audit is retained as history. The October 10 generator supersedes
its disabled-generation and concrete-wrapper omissions. Callback/raising/generic
boundaries still require explicit adapters. Use the generated unsupported manifest
and exact packed consumer gate for current claims.


| Subpath | Current high-value gap | First useful slice | Required evidence before docs call it ready |
| --- | --- | --- | --- |
| `./cli` | The MoonBit parser surface has `resolve_closed_world(...)`, `CliParseError::invalid_dump_path(...)`, `CliParseError::invalid_function_index_list(...)`, and `CliParseResult.closed_world`, while `node/cli.*` still omits them. | Add `resolveClosedWorld(...)`, the two parse-error constructors, and the `closedWorld` constructor/result slot, or document a permanent split where only `cmd` exposes resolved closed-world state. | Runtime export, `.d.ts` declaration, `api-parity.test.mjs` assertion against [`src/cli/pkg.generated.mbti`](../../../src/cli/pkg.generated.mbti), and README note if the split remains intentional. |
| `./wast` | File/suite spec helpers exist, but command-level static assertion classification does not. | Add `evaluateWastStaticAssertion(...)` plus result/stage/kind types only if the wasm-gc adapter can expose the shape ergonomically. | Wrapper tests for `assert_malformed`, `assert_invalid`, and `assert_unlinkable`; cross-link to [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md) because that page owns stage semantics. |
| `./wast` | `wast_arbitrary_feature_stats(...)` is MoonBit-only. | Treat this as fuzz/reporting API, not as part of the static assertion slice. | Runtime/declaration parity plus a small fixture proving the returned feature facts match WAST arbitrary docs before advertising it to JS consumers. |
| `./validate` | Diagnostics / invalid-AST repro helpers are MoonBit-only. | Expose `validationIssueFamily(...)`, the invalid-AST registry/lookup helpers, and stable-id minimal-repro builders before broad GenValid parity. | API parity tests plus examples or smoke coverage that avoid parsing human validation messages; link to [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md). |
| `./validate` | Current invalid-fuzz naming differs (`runValidateInvalidFuzz` versus MoonBit `run_validate_invalid_ast_fuzz(...)`). | Add compatibility aliases or write a semver plan before removing the old name. | Parity tests must show which name is canonical and which aliases remain supported. |
| `./validate` | Configured `gen_valid` profiles and feature-ledger helpers are absent. | Land after diagnostics/repro, because generator parity has a larger type surface. | Wrapper tests tied to [`src/validate/pkg.generated.mbti`](../../../src/validate/pkg.generated.mbti) plus docs that distinguish generator profiles from fuzz suite profiles. |

## What Changed Since The 2026-04-18 Audit

The archived audit at research note 0110 correctly identified `cmd` as the most urgent drift point at that time.
That specific status is now stale:

- [`node/cmd.d.ts`](../../../node/cmd.d.ts) declares `CmdFuzzStats`, `runCmdFuzzHarness(...)`, and `runCmdFuzzHarnessProfile(...)`.
- [`node/cmd.js`](../../../node/cmd.js) now exports the same parity names and keeps `WasmSmithFuzzStats`, `runWasmSmithFuzzHarness(...)`, and `runWasmSmithFuzzHarnessProfile(...)` as compatibility aliases.
- [`node/cmd.d.ts`](../../../node/cmd.d.ts) and [`node/cmd.js`](../../../node/cmd.js) both carry `CmdIO.printTextModule` and `CmdRunSummary.closedWorld`.
- [`node/test/api-parity.test.mjs`](../../../node/test/api-parity.test.mjs) now asserts the renamed fuzz symbols, compatibility aliases, `CmdIO.printTextModule`, and `CmdRunSummary.closedWorld` in both runtime and declaration surfaces.
- [`node/README.md`](../../../node/README.md) documents the parity names, legacy aliases, and the caveat that `printTextModule` is present for API parity but is not yet routed through the checked-in JS command bridge.

The new teaching rule is therefore: **`cmd` is no longer the top correctness cleanup; it is the model for the kind of explicit parity coverage other Node subpaths still need.**

## Historical Drift And Why It Mattered

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

## Publication Metadata And Provenance Boundary

The Node package is also the npm publication boundary. Current package metadata and workflows, read with npm's [trusted-publisher](https://docs.npmjs.com/trusted-publishers) / [provenance](https://docs.npmjs.com/generating-provenance-statements) documentation and GitHub Actions [OIDC guidance](https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect), show that Starshine is **not** configured for npm trusted publishing yet:

- [`node/package.json`](../../../node/package.json) records the GitHub repository and local beta publication defaults (`access: public`, `tag: beta`); these do not configure an npm trusted publisher.
- Existing GitHub workflows are validation/test workflows with read-only contents permissions; no workflow grants `id-token: write` for an npm OIDC publish.
- No checked-in workflow runs a package publish step from the `node/` package directory.

That means publication remains a release-process concern rather than a Node API-health fact. Future work that adds trusted publishing should update package metadata, the dedicated release workflow, npm package trusted-publisher settings, [`release-process.md`](release-process.md), and this page together. Provenance does not replace wrapper parity, package tests, ignored-but-publishable wasm artifact checks, or `npm pack --dry-run` tarball inspection.

## Maintenance And Validation Guidance

Use these checks when touching the Node package or documenting its surface:

1. **Wrapper parity:** run or update [`node/test/api-parity.test.mjs`](../../../node/test/api-parity.test.mjs) for any intentional `.d.ts` / runtime export shape change.
2. **Smoke behavior:** keep [`node/test/smoke.test.mjs`](../../../node/test/smoke.test.mjs) green for binary/text validation, `cmd` adapter hooks, differential validation, fuzz-report persistence, closed-world summary precedence, and WASI startup.
3. **Examples:** keep [`node/test/examples.test.mjs`](../../../node/test/examples.test.mjs) green so the checked-in published examples still exercise the public API.
4. **Build boundary:** run the real pack/consumer gate, the Node suite and `npm run check-generated --prefix node`. Both Wasm artifacts and bindings are rebuilt; compare the reports and inspect the exact tarball. The [CI workflow](../../../.github/workflows/node-wasm-tests.yml) runs these checks with read-only permissions.
5. **Publication metadata:** if trusted publishing or package provenance is introduced, add the package-level `repository` metadata and release workflow evidence before calling the package trusted-publishing-ready.
6. **JS string builtins runtime:** if the wasm-gc adapter changes `builtins: ["js-string"]`, adds `importedStringConstants`, or stops requiring JS string builtins, update [`../wasm-js-string-builtins-boundary.md`](../wasm-js-string-builtins-boundary.md), README runtime requirements, and package smoke tests together.
7. **JS primitive/text-encoding builtins runtime:** if the adapter adds JS Primitive Builtins or JS Text Encoding Builtins compile-option/import-object behavior, update [`../wasm-js-primitive-and-text-encoding-builtins-boundary.md`](../wasm-js-primitive-and-text-encoding-builtins-boundary.md), [`../wasm-feature-status-and-proposal-boundaries.md`](../wasm-feature-status-and-proposal-boundaries.md), README runtime requirements, API docs, package smoke tests, and release-gate expectations together. Do not describe `string.encode_utf8_array` or generic `externref` support as proof of those host proposals.
8. **JSPI / host async:** if the package starts wrapping imports with `WebAssembly.Suspending`, adapting exports with `WebAssembly.promising(...)`, or advertising Promise-suspending host calls, update [`../wasm-jspi-host-async-boundary.md`](../wasm-jspi-host-async-boundary.md), README runtime requirements, API docs, runtime feature-detection tests, and release-gate expectations together.
9. **Wasm ESM Integration:** if the package starts exposing `.wasm` resources through source-phase `import source`, dynamic `import.source(...)`, instance-phase `.wasm` imports, or package wasm export targets, update [`../wasm-esm-integration-boundary.md`](../wasm-esm-integration-boundary.md), README/API docs, Node smoke/examples tests, runtime-support notes, and release packaging checks together.
10. **Docs truthfulness:** when adding a wrapper, update [`node/README.md`](../../../node/README.md), this page, the release checklist in [`release-process.md`](release-process.md) if package contents or versioning change, and any relevant top-level API docs together.

The generated drift and packed consumer checks compare:

- [`src/*/pkg.generated.mbti`](../../../src/)
- [`node/*.d.ts`](../../../node/)
- [`node/*.js`](../../../node/)
- [`node/package.json#exports`](../../../node/package.json)

The comparison must start from the `exports` allowlist, not from every file in `node/` or every package under `src/`: unlisted subpaths are intentionally private for package consumers. That test should distinguish four cases instead of requiring blanket parity:

1. public and required now,
2. intentionally unsupported through the wasm-gc adapter,
3. intentionally omitted from the partial Node package,
4. renamed compatibility aliases that must remain documented and tested until a semver decision removes them.

## Historical Recommended Widening Order

This ordering predates the FFI-driven October beta. The limited `passes` facade
is now exported; wider internals still require a separate API decision.


1. Keep `cmd` parity tests as the template and extend similar declaration/runtime checks to `cli`, `validate`, and `wast`, driven from `node/package.json#exports`.
2. Add `cli` closed-world parity (`resolveClosedWorld`, parse-error constructors, and `CliParseResult.closedWorld`) or document a permanent split if `cmd` remains the only closed-world consumer.
3. Add the small `wast.evaluateWastStaticAssertion(...)` wrapper, with result/stage/kind types or a deliberately JS-friendly object result.
4. Add the high-value `validate` diagnostics / invalid-AST repro slice before the broader GenValid and feature-ledger slice.
5. Reconcile the older `runValidateInvalidFuzz` naming with the current MoonBit `run_validate_invalid_ast_fuzz(...)` surface through either a compatibility alias or a documented semver plan.
6. Only then decide whether to add new package subpaths such as `diff`, `validate_trace`, or `fuzz`; exposing `ir` and `passes` should be treated as a larger API-design decision, not a parity cleanup.

## October 10, 2026 — candidate metadata and bridge coverage

The candidate metadata prepares `0.1.2-beta.0` in root `moon.mod` and npm.
[`generate-product-version.mjs`](../../../scripts/lib/generate-product-version.mjs)
derives `src/cmd/version.generated.mbt` and the FFI root dependency; it rejects missing or multiple version
assignments, noncanonical/malformed npm semver and npm/MoonBit disagreement.
Required CI and FFI drift checks compare the generated source. Packed API
observations and the installed CLI require `v0.1.2-beta.0`, replacing the stale
`v0.1.0` CLI value. The stable portable WIT/metadata interface remains `0.1.1`,
with its root dependency generated from product metadata; changing the npm
candidate does not rename component exports. The final npm version is a release
decision.

Six tests in [`npm_test.mbt`](../../../src/ffi_bridge/npm_test.mbt) exercise
explicit precompute/vacuum transformations, independent optional optimization
levels, intentionally invalid pass/validation/encoding errors, recovery and
GC/import/memory constructor roundtrips. Direct IR and byte assertions cover
real bridge behavior. All fourteen bridge tests pass on WasmGC. Complete local
coverage improves to 28,251 uncovered lines in 226 files against the retained
28,138 / 196 baseline. The remaining +113 / +30 is an open gate; local analysis
completion is not a passing baseline check or exact-head CI result.

Current-format `moon.mod` and nested `moon.pkg` changes now trigger package,
fuzz, coverage and native-example workflows. The workflow contract fails if
either push or pull-request filters omit them; legacy JSON triggers remain.
These triggers preserve the separate native-debug and coverage failures.

The reviewed optimizer checkpoint through `62ba4012f` is integrated at
`d0fbed55a` on the package branch. Fresh combined source produces a 47-file,
4,801,791-byte archive, SHA-256
`c59a32ef17ee6538a1c9c6e4c5515b9b0b4763bae16d5067e99d2e78ebf2d411`.
GC/WASI sizes are 7,452,238 -> 7,232,670 and 6,748,815 -> 6,240,581 bytes.
All 14,019 default tests, 44 Node cases, 45 optimizer host controls and isolated
Node25/26 JS/strict TS consumers pass. The [handoff](../../npm-beta-handoff.md#combined-optimizer-checkpoint)
separates fresh build evidence from the owner's same-original comparisons and
records the exact-head CI publication precondition. The separate GC follow-up,
licensing, coverage and native-debug failures remain open.

Exact `c9fc25cd2` package CI reproduces these bytes and full tests/release/fuzz
checks pass. Its final required semantic comparison hit the 30-minute overall
DAE job deadline after successful native builds and a 10,000-case deterministic
comparison. The job budget is now bounded at 45 minutes with comparison reports
and retained failures uploaded on success/failure; counts and failure policy are
unchanged. Red-first workflow contracts and actionlint verify the provisioning
repair. Exact-head protected checks still precede source publication. Coverage
remains failed at 28,244 / 226 (+106 / +30), without resetting the baseline.

## Sources

- WASI runner / Preview boundary: [Node `node:wasi` documentation](https://nodejs.org/api/wasi.html), [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md), [`../../../node/internal/wasi-runner.js`](../../../node/internal/wasi-runner.js), [`../../../scripts/lib/moonbit-wasi-runner.mjs`](../../../scripts/lib/moonbit-wasi-runner.mjs)
- JSPI host-async boundary: [`../wasm-jspi-host-async-boundary.md`](../wasm-jspi-host-async-boundary.md), [`../../../node/internal/runtime.js`](../../../node/internal/runtime.js), [`../../../node/internal/wasi-runner.js`](../../../node/internal/wasi-runner.js)
- ESM Integration boundary: [ESM Integration draft](https://webassembly.github.io/esm-integration/js-api/index.html), [Node Wasm-module ESM documentation](https://nodejs.org/docs/latest/api/esm.html), [`../wasm-esm-integration-boundary.md`](../wasm-esm-integration-boundary.md), [`../../../node/package.json`](../../../node/package.json), [`../../../node/internal/runtime.js`](../../../node/internal/runtime.js), [`../../../node/internal/wasi-runner.js`](../../../node/internal/wasi-runner.js)
- JS String Builtins runtime boundary: [`../wasm-js-string-builtins-boundary.md`](../wasm-js-string-builtins-boundary.md), [`../../../node/internal/runtime.js`](../../../node/internal/runtime.js)
- npm trusted-publishing, provenance, and OIDC evidence: [npm trusted publishers](https://docs.npmjs.com/trusted-publishers), [npm provenance](https://docs.npmjs.com/generating-provenance-statements), [GitHub Actions OIDC guidance](https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect), [`../../../.github/workflows/node-wasm-tests.yml`](../../../.github/workflows/node-wasm-tests.yml), [`../../../.github/workflows/fuzz.yml`](../../../.github/workflows/fuzz.yml), [`../../../.github/workflows/readme-api-sync.yml`](../../../.github/workflows/readme-api-sync.yml)
- Node/TypeScript package-resolution evidence: official [Node package documentation](https://nodejs.org/api/packages.html), official [TypeScript module-resolution reference](https://www.typescriptlang.org/docs/handbook/modules/reference.html), and the local package metadata/wrapper/test sources listed below
- Archived baseline audit: research note 0110
- Package metadata and README: [`../../../node/package.json`](../../../node/package.json), [`../../../node/README.md`](../../../node/README.md)
- Current Node parity and smoke tests: [`../../../node/test/api-parity.test.mjs`](../../../node/test/api-parity.test.mjs), [`../../../node/test/smoke.test.mjs`](../../../node/test/smoke.test.mjs), [`../../../node/test/examples.test.mjs`](../../../node/test/examples.test.mjs)
- Build/generation boundary: [`../../../scripts/lib/generate-node-package.mjs`](../../../scripts/lib/generate-node-package.mjs), [`../../../scripts/lib/build-node-package.mjs`](../../../scripts/lib/build-node-package.mjs)
- Runtime command contract: [`./cli-command-and-dispatcher.md`](./cli-command-and-dispatcher.md)
- Release/package publication checklist: [`./release-process.md`](release-process.md)
- Validator diagnostics/repro contract: [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md)
- WAST static assertion stage model: [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md)
- MoonBit workspace/package map: [`./moonbit-workspace-package-map.md`](moonbit-workspace-package-map.md), [`../../../moon.mod`](../../../moon.mod), and the official [MoonBit package configuration](https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html)
- MoonBit source signatures: [`../../../src/cli/pkg.generated.mbti`](../../../src/cli/pkg.generated.mbti), [`../../../src/cmd/pkg.generated.mbti`](../../../src/cmd/pkg.generated.mbti), [`../../../src/validate/pkg.generated.mbti`](../../../src/validate/pkg.generated.mbti), [`../../../src/wast/pkg.generated.mbti`](../../../src/wast/pkg.generated.mbti)
