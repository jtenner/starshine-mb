# npm WasmGC beta preparation handoff

This is local preparation for `@jtenner/starshine@0.1.2-beta.0`. No package was
published, no tag/release created, and no branch pushed or merged. No account
credentials were changed.

## Checkout and authority

- Branch: `codex/npm-wasmgc-beta`.
- Isolated checkout: `/home/jtenner/Documents/Codex/2026-10-09/task-9/starshine-mb`.
- Baseline: verified local and remote `master`,
  `f91f5ec300ec72027342a5942b4a86c96bd53c5e`, rather than stale `main`.
- Other worktrees and active tasks were inspected and preserved. Unrelated
  DAE2/O work was not resumed. Local commits are listed by `git log master..HEAD`.

## Generated API

The FFI generator writes a schema from the same parsed and qualified signatures
that generate its actual exports. Current schema: 4,370 concrete signatures.
The npm generator uses it for parameters, returns, effects, optional arguments
and concrete forwarding calls. `.mbti` metadata supplies named types, constants
and traits. There is no separate hand-maintained function signature list.

`ffi/src/npm/generated.mbt` is the actual compiled WasmGC adapter. The required
ABI manifest currently has 2,848 names. The direct ABI unsupported manifest has
23 callback/raising/generic entries; selected command callbacks are implemented
by the retained JavaScript facade. Unknown or ambiguous supported
mappings stop generation. Public JS and TypeScript files are deterministic;
`npm run check-generated --prefix node` checks FFI/npm outputs, and CI also checks
tracked diffs. `moon info` can refresh source interfaces while checking.

Compatibility metadata preserves existing `Module.new` and `CliParseResult.new`
argument positions, appending new optional fields. Callback facade declarations
are generated with explicit FFI parameter projections and JavaScript record
representations. Aliases remain. Independent omitted optional arguments, unsigned
integer returns, primitive GC enum values and instance-owned opaque handles are
covered. Handles are GC-managed without explicit disposal. The README documents
async ESM initialization, mapping/errors and the retained callback facade limits.

## Bootstrap and self-optimization

The build regenerates FFI/bindings, compiles the WasmGC adapter, compiles a fresh
native release CLI directly from source, and compiles the WASI release CLI. The
native binary does not depend on the final npm package. Compiler debug name
sections are removed because their subsection ordering is noncanonical.

The name-stripped unoptimized artifacts are preserved under ignored `dist/npm/`.
The fresh bootstrap applies `--optimize --optimize-level 1` to both artifacts.
This bounded active preset runs duplicate-function elimination and debug stripping.
A duplicate-function fixture must transform and preserve execution result 84
before/after; its measured size changes from 70 to 54 bytes. The actual package artifacts currently have equal before/after hashes
and zero size gain. No claim of size or runtime improvement is made.

Input/output bytes pass independent wasm-tools validation. Required exports must
survive. Separate standalone package copies compare semantic executions, errors,
roundtrips, export names, a one-case fuzz result and CLI help before optimized
bytes are promoted. A failure stops packaging without an unoptimized fallback.
Stale promoted artifacts are removed at the beginning of every build.

## Local evidence

Final tarball: `dist/npm/jtenner-starshine-0.1.2-beta.0.tgz`, 4,898,006 bytes, 47 files.
SHA-256: `2105e691b479f7ae081deb4bb094f969815617a9d46764c122eac186345b25ad`.
The reproducible commands and toolchain are in [the package README](../node/README.md)
and `ffi/src/npm/toolchain.json`. Exact local reports and tarballs live in ignored
`dist/npm/`; they are handoff evidence, not repository source or package contents.

- FFI/schema generator tests: 10 passed, 44 assertions.
- Static package contract: passed.
- Documented dependency setup: `moon update` passed after allowing registry-cache writes; initial sandboxed registry update was read-only and cached dependencies were used for the first build.
- README/API synchronization: passed.
- MoonBit bounded WasmGC suite: 14,001 passed, zero failed.
- Full repository gate including CI-profile fuzz: passed. All 14 suites pass with seed `0x1a1241680765d7f`; no passing test was disabled.
- Final exact packed JS/TS consumers: passed on Node 25.8.1 and 26.11.1, TypeScript 5.8.3, all nine public export entries. Both runtime reports identify the same tarball hash.
- Node suite: 44 passed, zero failed or skipped.
- Generated FFI/npm drift: passed. CI workflow passes actionlint; remote CI is unrun.
- Coverage: `bun validate coverage --top 5 --baseline .github/coverage-baseline.txt` exceeded a ten-minute execution budget. After stopping its instrumented Wasm test and parent Moon process, it emitted a partial report: 59,436 uncovered lines / 243 files versus the unchanged baseline 28,138 / 196 (delta +31,298 / +47). The report command exited zero, but the collection was interrupted; no completed coverage or regression pass is claimed. These partial counts do not attribute a regression to this package change or repair previously reported coverage failures.

Final build measurement: 11560 ms locally, including bootstrap,
generation, validation and parity. WasmGC: 7,452,107 bytes before/after,
SHA-256 `059555428f569dcd57275757be8453a4f4881eb80592f9f80e402b4987072de3`.
WASI: 6,748,730 bytes before/after,
SHA-256 `b7dd0896d7b41989e1aa29bd297d3fd63097b7e3b7f76883e9897f25010add52`.
Last build optimizer/validation times: 708 ms / 476 ms.
A separate single local sample measured native self-optimization at 636 ms and
172,840 KiB peak RSS; Node API observation at 248 ms and 168,720 KiB peak RSS.
These are short absolute samples, not comparative performance claims.

The tarball includes public JS/declarations, shared runtime/declarations, the
required private command JS, README/examples, executable and both optimized Wasm
files. Unused private backend declarations were removed with an explicit file
allowlist. No source, tests, schema, debug maps, raw baselines or reports are
packed. There are no runtime dependencies or bundled license text.

The consumer harness uses empty projects under `/tmp`, installs the exact packed
archive offline with no lifecycle scripts or runtime dependencies, and removes
MoonBit from runtime PATH. Node runtime filesystem permissions allow only the
consumer directory, with explicit denied-read checks for repository and compiler
files; the CLI preopens only the consumer directory. It imports root plus every promised subpath, checks
strict NodeNext declarations without `skipLibCheck`, and exercises arithmetic,
locals and GC struct semantics, actual precompute/vacuum optimization, errors,
optional holes, nominal handles, command callbacks, positive bounded fuzz and
CLI WAT-to-Wasm output. The packed file list is included in `consumer-report.json`.

Internal Sol 6.1 High read-only review found and verified repairs for enum
representations, handle type/instance ownership, constructor compatibility,
optional argument holes, `osize` config and the previously broken positive fuzz
entry point. No external CLI reviewer received code. Final review found no
remaining concrete package-code blocker; handoff evidence is checked separately.

## Remaining release decisions

- Root `LICENSE` declares MIT; `moon.mod` declares Apache-2.0. No npm license was
  silently chosen and no license text is bundled. Reconcile this before publishing.
- Approve candidate version `0.1.2-beta.0`, the prepared public/beta metadata defaults and a publishing/
  provenance route. Current CI only validates; it never publishes.
- Tested Moon snapshot archive requests returned HTTP 403, while `latest` is
  available. Provision the documented snapshot or qualify a newer compiler with
  drift and consumer gates. Bun, wasm-tools and TypeScript are pinned/documented;
  CI installs the available Moon compiler and checks generated drift.
- Remote CI is unrun because this branch remains local. Repository coverage and
  broader release/performance gates are independent of package consumer success.
  Native-debug MoonBit issue #1322 was not exercised or cleared by this work.
- The JavaScript callback facade does not invoke `CmdIO.printTextModule`; the
  live bundled CLI is the complete command route. Generic/raising/callback
  unsupported placeholders remain documented API limits.

npm publication remains pending user approval. Push and merge require further
instruction even after the release decisions are resolved.
