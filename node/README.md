# Starshine Node Package

`@jtenner/starshine` is an ESM package with a real WasmGC API and a bundled WASI CLI. This checkout prepares `0.1.2-beta.0`; publication and the final version remain release decisions.

## Runtime and API

Node.js 25+ must support WebAssembly GC and JS string builtins. Tested with Node 25.8.1 and 26.11.1. ESM imports await shared Wasm initialization; exported operations are synchronous after import. Initialization rejects if the artifact or required host features are unavailable. CommonJS and browser hosting are not promised.

The root exports `binary`, `cli`, `cmd`, `lib`, `passes`, `validate`, `wast` and `wat`. Each also has an extensionless subpath, for example `@jtenner/starshine/passes`. `passes.optimizeModule` runs the active hot pipeline; it does not expose every compiler pass implementation. The `starshine` executable runs the bundled WASI Preview 1 CLI.

```js
import { binary, passes, validate, wast } from '@jtenner/starshine';

const parsed = wast.wastToBinaryModule(
  '(module (func (export "answer") (result i32) i32.const 40 i32.const 2 i32.add))'
);
if (!parsed.ok) throw new Error(parsed.display ?? 'parse failed');
const optimized = passes.optimizeModule(parsed.value, ['precompute', 'vacuum']);
if (!optimized.ok) throw new Error(optimized.error);
if (!validate.validateModule(optimized.value).ok) throw new Error('invalid module');
const encoded = binary.encodeModule(optimized.value);
if (!encoded.ok) throw new Error(encoded.display ?? 'encode failed');
const { instance } = await WebAssembly.instantiate(encoded.value);
console.log(instance.exports.answer()); // 42
```

## Values, errors and compatibility

MoonBit opaque values are nominal handles owned by their Wasm instance. Keep handles obtained from this package; plain objects and handles of another type or instance are rejected. JavaScript and Wasm GC manage their lifetime; there is no explicit `dispose` operation. Dropping references permits collection. Arrays, bytes, options, tuples and results are converted to JavaScript values; bytes use `Uint8Array`, options use `null`, tuples use arrays, and results use `{ ok: true, value }` or `{ ok: false, error, display? }`.

64-bit integers use `bigint`; runtime conversion also accepts safe integer numbers, while declarations require `bigint`. Smaller integer widths are range checked. `Char` accepts a scalar code point or a one-scalar string. Independently omitted optional arguments use `undefined`; explicit `null` represents a nullable value. Required mapping errors throw `TypeError`; ordinary parse/validate/optimize errors return results. Wasm traps can throw.

The validator keeps ordinary diagnostics unchanged. Control diagnostic subtrees exceeding 32 levels or 256 instructions use an explicit `<bounded control diagnostic>` marker, retaining the instruction location, block type, underlying reason and operand stack. This bounds recursive diagnostic rendering; it does not promise arbitrary-depth exception-control validation.

Unsupported callback, raising or generic signatures remain explicit throwing placeholders with `never[]` declarations and reasons recorded in the source manifest. Generation fails on unknown or ambiguous supported mappings. There are no invented overloads. Concrete function signatures and factory declarations are generated from the FFI schema. Reviewed compatibility metadata preserves old constructor argument positions and explicitly projects the retained command facade. `WasmSmithFuzzStats` and the `runWasmSmithFuzzHarness*` names remain aliases. `CmdIO` is a JavaScript callback model; `printTextModule` is carried but the callback command bridge does not currently invoke it. Use the bundled CLI for the complete live command interface.

## Tested build, pack and install

Build tools: Moon `0.1.20260920 (914d7da 2026-09-20)`, compiler `v0.10.14+7d59c7ec9`, Bun 1.4.2, Node 25+, a native C toolchain, wasm-tools 1.251.0, and TypeScript 5.8.3 for consumer checks. Exact tested versions are recorded in `ffi/src/npm/toolchain.json`. The MoonBit installer currently serves `latest`; the tested snapshot's archive URL returned HTTP 403 during preparation. Preserve or provision the tested snapshot, or qualify a newer compiler using the drift and consumer gates. CI installs the available compiler and requires deterministic generated-file and packed-consumer checks.

From the repository root with those tools installed:

```sh
moon update
# Native C compilation can spill large assembly files; use disk-backed scratch.
mkdir -p .tmp/npm-build
export TMPDIR="$PWD/.tmp/npm-build"
npm run build --prefix node
npm run check-generated --prefix node
bun test ./scripts/lib/ffi-generation.test.ts ./scripts/lib/node-generation.test.ts ./scripts/lib/npm-process.test.ts ./scripts/lib/npm-preset.test.ts ./scripts/lib/npm-consumer-scratch.test.ts
node --test node/test/*.test.mjs
# TSC_BIN can be an absolute path if tsc is not available on PATH.
NPM_CONSUMER_TMPDIR=/tmp bun scripts/test/npm-packed-consumers.mjs
```

On the tested Linux host, one build exhausted the shared 32 GiB `/tmp` tmpfs while the native compiler wrote assembly; retrying with disk-backed `TMPDIR` avoids that capacity limit. This is a build-host requirement and adds no consumer dependency.

The last command executes the real `npm pack` prepack build, inspects the tarball and installs it into empty JS and strict NodeNext TypeScript projects outside the checkout. It exercises every export, runtime initialization, roundtrips, optimization, errors, a short fuzz case and the CLI with MoonBit absent from runtime PATH. Reports and tarballs are in ignored `dist/npm/`.

Cold source compilation has a 15-minute deadline per compiler command; the packed-consumer harness bounds its entire `npm pack`/prepack command to 30 minutes. Direct `npm run build` or `npm pack` uses the per-command limits without a separate aggregate deadline. Individual optimizer commands keep a three-minute deadline, and consumer commands have four minutes. Override these with `NPM_COMPILER_TIMEOUT_MS`, `NPM_PACK_TIMEOUT_MS`, `NPM_SELF_OPT_TIMEOUT_MS`, and `NPM_CONSUMER_TIMEOUT_MS`, respectively; values must be positive integers up to 2147483647. On the tested Linux build host, timeout cleanup inventories descendant process groups with `ps` and terminates them, including nested prepack/compiler groups. Failure preserves full compiler/pack logs and a build error report under `dist/npm/`, then stops packaging. CI also has an overall 45-minute job limit. These budgets accommodate cold native C compilation without claiming an optimization speed improvement.

`NPM_CONSUMER_TMPDIR` selects an existing directory outside the checkout for the empty install projects. The harness rejects checkout-local directories and symlink aliases into the checkout. This is separate from the compiler's `TMPDIR`, which may use the checkout's disk-backed build scratch.

A standalone consumer needs only Node and the tarball:

```sh
mkdir consumer && cd consumer
npm init -y
npm install /absolute/path/jtenner-starshine-0.1.2-beta.0.tgz
node --input-type=module -e 'const s = await import("@jtenner/starshine"); console.log(Object.keys(s))'
npx --no-install starshine --help
```

`npm run generate --prefix node` refreshes the FFI metadata and JS/TS bindings. The MoonBit and npm candidate versions must agree; generation derives the CLI/API version from `moon.mod` and drift checks reject stale version text. `check-generated` compares generated FFI/npm outputs without rewriting them; its `moon info` step can refresh source `.mbti` interfaces. The build compiles the actual `ffi/src/npm` adapter, a fresh native bootstrap optimizer and the WASI CLI from this checkout. No prebuilt package artifact is required. Ordinary consumers have no optimizer or MoonBit dependency.

## Self-optimization and package contents

Every build removes stale package Wasm files, strips the compiler's noncanonical debug name section and preserves that unoptimized baseline in `dist/npm/*.unoptimized`. The fresh native Starshine executable applies the repository’s O4s preset using `--optimize --optimize-level 4 --shrink-level 1` to both Wasm artifacts. The literal `-O4s` flag is unsupported. The published `1cbf1ae55` checkpoint verifies five passes: duplicate-function elimination, constraint analysis, vacuum, local reordering and debug stripping. The current build requires a sixth pass, merge-similar-functions after local reordering, with selection only at numeric levels 4/1. The validator, bounded admission and scheduler form this six-pass route; neighboring fast levels and the O4z scheduler retain their existing queues. MergeSimilarFunctions can share profitable immutable i32 record copies through a private helper that allocates a fresh record on every call; it preserves the old record, reference identity and null traps. O4s uses the current fast preset; the full O4z scheduler requires optimize/shrink levels 4/4. A separate duplicate-function fixture must transform and preserve its result; there is no silent unoptimized fallback.

The build independently validates input and output with wasm-tools, checks ABI exports, then compares API observations and CLI help in separate copied packages before promoting optimized bytes. The observation harness also exercises explicit MergeSimilarFunctions and numeric 4/1 on independent 12-field record-copy inputs, checking byte reduction, all old/new fields, fresh allocation and public function identities, null traps, fallback aliases and ordered host effects. Failures stop packaging. The previous qualified O1 artifacts and reports are preserved under `dist/npm/qualified-o1-279aaf642/` for comparison. Self-optimization does not promise a size gain. The bootstrap proof fixture must change bytes and return 84 before and after. `build-report.json` records exact hashes, timing and parity.

The tarball allowlist includes public JS/declarations, shared runtime, required generated command JS, examples, README, executable and the two optimized Wasm files. Source, tests, schema, reports, raw baselines and debug maps remain outside the package. No runtime dependencies are declared.

## Release decisions

Joshua Tenner’s original portions are offered under MIT; the compiled bundle also contains third-party material under Apache-2.0 and the terms retained in MoonBit Core’s NOTICE. Package metadata uses `SEE LICENSE IN LICENSE`, with scoped `LICENSE`, `NOTICE`, `licenses/Apache-2.0.txt`, the full `licenses/Binaryen-LICENSE.txt`, and the complete `licenses/moonbit-core-NOTICE.txt` included. Binaryen notice retention follows the owner’s conservative choice; unknown pass provenance remains unknown and the existing MoonBit module Apache-2.0 declaration remains; this is not an MIT-only bundle or a dual-license choice. See [the source provenance audit](https://github.com/jtenner/starshine-mb/blob/master/docs/wiki/tooling/license-provenance.md).

Build generation checks notice drift; the build verifies reviewed installed Core 0.10.14+7d59c7ec9 license/NOTICE bytes and x 0.5.1 metadata before compilation. A dependency upgrade requires a notice/provenance review.

Confirm the beta version and publishing/provenance configuration, and resolve or explicitly assess repository release gates. Repository native-debug builds use initialized lower-stack storage to avoid MoonBit issue #1322 without changing the WasmGC API. Large native debug test linking uses a per-process 64 MiB stack (`ulimit -s 65536`). The upstream compiler issue and complete coverage qualification remain separately tracked in the repository handoff. No npm publication, release, tag, push or merge is performed by these commands.
