# npm WasmGC beta preparation handoff

This prepares `@jtenner/starshine@0.1.2-beta.0`. Source publication to
`origin/master` was explicitly authorized on October 10 after local qualification.
No npm package was published, no tag/release created, and no account credentials
were changed. Licensing remains undecided and blocks an npm release.

## Checkout and authority

- Branch: `codex/npm-wasmgc-beta`.
- Isolated checkout: `/home/jtenner/Documents/Codex/2026-10-09/task-9/starshine-mb`.
- Baseline: verified local and remote `master`,
  `f91f5ec300ec72027342a5942b4a86c96bd53c5e`, rather than stale `main`.
- Other worktrees and active tasks were inspected and preserved. Unrelated
  DAE2/O work was not resumed. Preparation commits are listed by
  `git log f91f5ec300ec72027342a5942b4a86c96bd53c5e..HEAD`.
- Before the authorized source push, a fresh fetch still found `origin/master`
  at that baseline; no newer source or integration conflict was present.

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
The fresh bootstrap applies the requested **O4s** preset using
`--optimize --optimize-level 4 --shrink-level 1` to both artifacts. Literal
`-O4s` is rejected by the current CLI parser; the existing ambient-stack return
regression names numeric levels 4/1 O4s. The build queries the fresh bootstrap
and requires those levels and the expanded queue: duplicate-function elimination,
constraint analysis, vacuum, reorder locals and strip debug. This is the current
fast preset; the full O4z scheduler requires levels 4/4.
A duplicate-function fixture must transform and preserve execution result 84
before/after; its measured size changes from 70 to 54 bytes. Both actual package
artifacts shrink in this qualification. Size or runtime gains are not promised.
Each optimizer command has a default 180-second budget; packed harness commands
have a 240-second budget. A timeout fails the build.

Input/output bytes pass independent wasm-tools validation. Required exports must
survive. Separate standalone package copies compare semantic executions, errors,
roundtrips, O4s-optimized bytes and executed values, export names, a one-case fuzz result and CLI help before optimized
bytes are promoted. A failure stops packaging without an unoptimized fallback.
Stale promoted artifacts are removed at the beginning of every build.

## Local evidence

Final O4s tarball: `dist/npm/jtenner-starshine-0.1.2-beta.0.tgz`, 4,821,600 bytes, 47 files.
SHA-256: `0d4cc321fef5554fce32cf95ee30a1d7be30a84380df048e75f07302775d9ab2`.
The reproducible commands and toolchain are in [the package README](../node/README.md)
and `ffi/src/npm/toolchain.json`. Exact local reports and tarballs live in ignored
`dist/npm/`; they are handoff evidence, not repository source or package contents.

- FFI/schema generator tests: 10 passed, 44 assertions.
- Static package contract: passed.
- Documented dependency setup: `moon update` passed after allowing registry-cache writes; initial sandboxed registry update was read-only and cached dependencies were used for the first build.
- README/API synchronization: passed.
- Prior package implementation at `279aaf642`: MoonBit bounded WasmGC suite 14,001 passed, zero failed; full repository gate including all 14 CI-profile fuzz suites passed with seed `0x1a1241680765d7f`. This preset-only revision changes no MoonBit implementation; those historical gates are retained rather than claimed as fresh O4s runs. No passing test was disabled.
- Final exact packed JS/TS consumers: passed on Node 25.8.1 and 26.11.1, TypeScript 5.8.3, all nine public export entries. Both runtime reports identify the same tarball hash.
- O4s qualification: the packed gate first rejected the preserved O1 report, then passed with levels 4/1 and the exact queue. Three API fixtures preserve results 42 / 7 / 9; the packed CLI also executes the ambient-stack return regression with O4s and result 42.
- Focused existing MoonBit O4s ambient-stack return regression: one passed on WasmGC.
- Node suite: 44 passed, zero failed or skipped.
- Generated FFI/npm drift: passed. CI workflow passes actionlint; remote CI was
  unrun at the initial local qualification checkpoint.
- Coverage: `bun validate coverage --top 5 --baseline .github/coverage-baseline.txt` exceeded a ten-minute execution budget. After stopping its instrumented Wasm test and parent Moon process, it emitted a partial report: 59,436 uncovered lines / 243 files versus the unchanged baseline 28,138 / 196 (delta +31,298 / +47). The report command exited zero, but the collection was interrupted; no completed coverage or regression pass is claimed. These partial counts do not attribute a regression to this package change or repair previously reported coverage failures.

O4s build measurement: 29,637 ms locally, including bootstrap, generation,
validation and parity. The complete build/pack/Node 26 consumer run took 34,276 ms,
with 926,512 KiB peak RSS across reaped descendants (not an additive concurrent
process total). `o4s-build-measurement.json` records this scope.

| Artifact | Unoptimized bytes | O4s bytes | Delta | Optimized SHA-256 |
| --- | ---: | ---: | ---: | --- |
| WasmGC | 7,452,107 | 7,287,538 | -164,569 | `6ace60a63b33dda84c15067ca2ab60b702a6e74e3edb7bfca7d158761984bbea` |
| WASI | 6,748,730 | 6,347,850 | -400,880 | `40e8be933bb3105aa74a1d54f9f4f350e4695d74ac64a9eceff05aa15bd52570` |

Raw hashes remain `059555428f569dcd57275757be8453a4f4881eb80592f9f80e402b4987072de3`
(WasmGC) and `b7dd0896d7b41989e1aa29bd297d3fd63097b7e3b7f76883e9897f25010add52`
(WASI). Build optimizer-plus-validation times were 9,454 / 9,726 ms. A separate
single serial native optimization sample measured 9,139 ms / 262,956 KiB peak RSS
for WasmGC and 9,373 ms / 223,436 KiB for WASI, excluding independent validation.
Both samples reproduced the promoted hashes and independently validated. The
sample command/measurement helper is retained with `validation-o4s/` evidence.
These are short local samples, not throughput or runtime-performance claims.

This O4s checkpoint supersedes the O1 package qualification at `279aaf642`.
All 20 previous evidence files, raw/optimized artifacts and the 4,898,006-byte
O1 tarball are preserved in `dist/npm/qualified-o1-279aaf642/`, with a verified
`snapshot.json` checksum manifest. O1 tar SHA-256:
`2105e691b479f7ae081deb4bb094f969815617a9d46764c122eac186345b25ad`.
O1 had zero artifact size change, an 11,560 ms build and 708 / 476 ms
optimizer-plus-validation times. O4s is slower in these local build samples;
the smaller package is not presented as a speed win.

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
CLI WAT-to-Wasm output and O4s ambient-stack return semantics. The packed file
list is included in `consumer-report.json` and the Node 25 / 26 copies.

Internal Sol 6.1 High read-only review found and verified repairs for enum
representations, handle type/instance ownership, constructor compatibility,
optional argument holes, `osize` config and the previously broken positive fuzz
entry point. No external CLI reviewer received code. Final review found no
remaining concrete package-code blocker. A subsequent O4s review independently
checked preset expansion, artifact/tar hashes and direct observation results,
with no new concrete defect. Licensing remains undecided.

## Remaining release decisions

- Root `LICENSE` declares MIT; `moon.mod` declares Apache-2.0. No npm license was
  silently chosen and no license text is bundled. Reconcile this before publishing.
- Approve candidate version `0.1.2-beta.0`, the prepared public/beta metadata defaults and a publishing/
  provenance route. Current CI only validates; it never publishes.
- Tested Moon snapshot archive requests returned HTTP 403, while `latest` is
  available. Provision the documented snapshot or qualify a newer compiler with
  drift and consumer gates. Bun, wasm-tools and TypeScript are pinned/documented;
  CI installs the available Moon compiler and checks generated drift.
- Initial package qualification was local. On pre-push `origin/master` at
  `f91f5ec3`, [Required CI](https://github.com/jtenner/starshine-mb/actions/runs/38014936990),
  [Fuzz Suites](https://github.com/jtenner/starshine-mb/actions/runs/38014937050)
  and [Node API Surface Tests](https://github.com/jtenner/starshine-mb/actions/runs/38014936998)
  passed, while [Coverage Report](https://github.com/jtenner/starshine-mb/actions/runs/38014936994)
  and [Examples CLI Native](https://github.com/jtenner/starshine-mb/actions/runs/38014937021)
  failed. Exact pushed-head CI must be
  reported separately; these prior results do not sign the new source head.
  Repository coverage and broader release/performance gates are independent of
  package consumer success.
  Native-debug MoonBit issue #1322 was not exercised or cleared by this work.
- The JavaScript callback facade does not invoke `CmdIO.printTextModule`; the
  live bundled CLI is the complete command route. Generic/raising/callback
  unsupported placeholders remain documented API limits.

npm publication remains pending user approval. Source publication authorization
does not authorize an npm publish, tag/release, deployment or credential change.

## Discrepancy investigation handoff

The [same-input comparison](wiki/tooling/node-package-surface.md#october-10-2026--same-input-binaryen-comparison)
records the observed Starshine/Binaryen artifact size and local time/RSS gap,
exact input/output hashes, feature limits and reproduction commands. The selected
build remains Starshine O4s; comparison candidate tarballs are separate evidence.
All original unoptimized inputs and the qualified tarball remain under ignored
`dist/npm/`, including preserved O1 and Binaryen comparison reports. The user
requested a new Sol 6.1 High task to investigate the discrepancy after source
publication. That optimization investigation is not part of this preparation.
