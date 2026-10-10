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
23 callback/raising/generic entries, explicitly reviewed in
[`unsupported-abi-policy.json`](../ffi/src/npm/unsupported-abi-policy.json).
Generation fails before writing files when a newly unsupported symbol appears,
an exception's reason changes, or a policy entry becomes stale. Unknown and
ambiguous type mappings also fail. This policy contains identities/reasons;
FFI signatures remain the sole type authority. Selected command callbacks are implemented
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
before/after; the integrated checkpoint changes it from 70 to 48 bytes
(the earlier checkpoint produced 54 bytes). Both actual package
artifacts shrink in this qualification. Size or runtime gains are not promised.
Each optimizer command has a default 180-second budget; consumer commands have
a 240-second budget. Cold compiler commands have separate 900-second deadlines,
and the packed-consumer harness gives its whole npm pack/prepack command a
1,800-second deadline. Direct builds retain per-command limits. CI has an overall
45-minute job cap. Positive bounded overrides, process-tree termination and complete diagnostic logs are
documented in the package README. A timeout fails the build.

Input/output bytes pass independent wasm-tools validation. Required exports must
survive. Separate standalone package copies compare semantic executions, errors,
roundtrips, O4s-optimized bytes and executed values, export names, a one-case fuzz result and CLI help before optimized
bytes are promoted. A failure stops packaging without an unoptimized fallback.
Stale promoted artifacts are removed at the beginning of every build.

## Local evidence

Initial O4s tarball at `9057a5d8`, now preserved under
`dist/npm/qualified-o4s-9057a5d8/`: 4,821,600 bytes, 47 files.
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
  CI installs the available Moon compiler and checks generated drift. The
  successful October 10 cold build received the same documented Moon/moonc
  snapshot through `latest`; no newer compiler was required for that result.
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
  Native-debug MoonBit issue #1322 remains open; the exact-head examples
  job exercised the reported unsupported lowering path and did not clear it.
- The JavaScript callback facade does not invoke `CmdIO.printTextModule`; the
  live bundled CLI is the complete command route. Generic/raising/callback
  unsupported placeholders remain documented API limits.

npm publication remains pending user approval. Source publication authorization
does not authorize an npm publish, tag/release, deployment or credential change.

## Published-head CI and cold-build follow-up

Source head `9057a5d8a5a5b85859c702c76d0cbe3e9f18ab55` was verified on
`origin/master`. The normal non-force push used existing account permissions;
GitHub unexpectedly reported bypassed violations for three missing required
checks. No branch protection or account setting was changed. This was a failed
protection preflight, not approval to bypass checks on subsequent updates.

Its [packed-package job](https://github.com/jtenner/starshine-mb/actions/runs/38028151417/job/114143304259)
failed with `spawnSync moon ETIMEDOUT` during the fresh native release bootstrap
build at the old 180-second deadline. It produced no tarball. The previous
successful baseline [release job](https://github.com/jtenner/starshine-mb/actions/runs/38014936990/job/114103005410)
spent 328,583 ms on native release compilation (01:55:25.246 to 02:00:53.829 UTC).
This supports a separate bounded cold-compiler budget rather than extending the
optimizer deadline or reusing a stale bootstrap. The follow-up retains full
compiler and pack logs, writes an error report even for bootstrap failures, and
tests completion, independent optimizer timeout, diagnostics, invalid budgets
and termination of descendants that ignore SIGTERM. Internal review reproduced
an orphan with the first synchronous timeout helper; the final asynchronous
runner terminates descendant groups on timeout, including reparented inherited-output holders, and awaits a bounded termination grace before permitting a retry.
The exact follow-up head `564c11e559d6785b19406a5d976b375a485d9c72`
passed the [cold package CI run](https://github.com/jtenner/starshine-mb/actions/runs/38029914397).
Its build took 360,624 ms; GC/WASI optimization plus validation took 9,949 /
11,017 ms. Node 25.9.0 and TypeScript 5.8.3 consumers exercised all nine exports
under consumer-only filesystem permissions. The CI tarball has exactly the same
4,822,175-byte SHA-256 as the local cold-budget package below, and the raw and
optimized Wasm hashes match. Downloaded reports, compiler logs and the archive
are preserved under `dist/npm/source-publication/cold-budget-ci-evidence/`.
This qualifies the package route on that head; other required/release gates
remain separately tracked. All three protected required checks and Fuzz Suites
also passed on `564c11e`; Coverage Report failed at the unchanged 28,279 / 227
count, and Examples CLI Native retained the compiler ICE. Later local policy
and bridge-test hardening require their own checks. No source update to master
followed this result.

The [native examples job](https://github.com/jtenner/starshine-mb/actions/runs/38028151316/job/114143303815)
failed with the same `Machine_of_clam_lower.lower_array_make` unsupported
uninitialized non-null GC ref array error and memory64 example command as the
baseline job. The follow-up examples job failed identically. The upstream
[issue #1322](https://github.com/moonbitlang/moonbit-docs/issues/1322), still open
on October 10, documents the same compiler version, native-debug `#valtype`
record/enum array allocation path and lowering diagnostic. This is evidence of
the reported compiler limitation, distinct from the fixed release-bootstrap
timeout; it does not clear the native-debug gate.

The completed published-head coverage run reported 28,279 uncovered lines in
227 files against the retained 28,138 / 196 baseline. The completed pre-push
`f91f5ec3` run already reported 28,277 / 226, so npm preparation adds two
uncovered lines and one file to an existing +139-line / +30-file regression.
The old interrupted local coverage report was partial and is not substituted
for either completed result. Six new bridge behavior tests cover explicit optimization, both optional
preset levels, diagnostics reset, encoding failure recovery and GC/import/memory
constructors with direct IR/byte assertions. Fourteen bridge tests pass on
WasmGC. Complete local coverage improves to 28,251 uncovered lines in 226 files
(+113 / +30 against the retained baseline), eliminating the npm bridge
regression and covering another 26 existing lines. The baseline gate still
fails; no baseline is reset. This local result awaits exact-head CI.

The cold-build follow-up's historical local tarball is
`dist/npm/jtenner-starshine-0.1.2-beta.0.tgz`, 4,822,175 bytes, 47 files,
SHA-256 `2c20fd47b4fd4b9bbe0ab179329bbbb0b3aa919f630d411cb2522e47ec64deb0`.
Its 575-byte archive increase comes from the updated build documentation;
both raw and optimized Wasm hashes remain exactly those above. The rebuilt
package passed before/after observations and both JS/strict TypeScript consumers
on Node 25.8.1 and 26.11.1 with TypeScript 5.8.3. Build time was 26,165 ms on the
warm local checkout; this is not a cold CI or optimization speed measurement.
The 44 Node tests, generated drift, README sync and actionlint pass. Timeout
regressions include both a live-parent detached child and a departed parent
whose detached child holds the inherited output pipe. Linux cleanup recovers
those pipe holders and deadline settlement does not depend on `close`.

The selected O4s checkpoint and raw inputs are additionally preserved in
`dist/npm/qualified-o4s-9057a5d8/` with `snapshot.json` hashes. CI logs and JSON
are retained under `dist/npm/source-publication/`. No gate or coverage baseline
was disabled or reset. Licensing remains undecided.

## Discrepancy investigation handoff

The [same-input comparison](wiki/tooling/node-package-surface.md#october-10-2026--same-input-binaryen-comparison)
records the observed Starshine/Binaryen artifact size and local time/RSS gap,
exact input/output hashes, feature limits and reproduction commands. The selected
build remains Starshine O4s; comparison candidate tarballs are separate evidence.
All original unoptimized inputs and the qualified tarball remain under ignored
`dist/npm/`, including preserved O1 and Binaryen comparison reports. The user
requested a new Sol 6.1 High task to investigate the discrepancy after source
publication. Its reviewed ten-commit checkpoint through `62ba4012f` is now
integrated into this preparation branch; later GC follow-up remains isolated.

## Combined optimizer checkpoint

The ten optimizer commits were cherry-picked with original commit attribution
onto the version-consistent package branch. Combined implementation head is
`d0fbed55a8bfedc3877740b61961e1e8c8816b08`; pass sources and regressions match
the owner's reviewed `62ba4012f` checkpoint. Backlog/wiki conflicts preserve
both the package release blockers and the remaining optimizer gaps. All 14,019
default MoonBit tests pass, alongside generator/process/version/component helper
tests, the workflow contract and actionlint. An identical explicit-target test
rerun was stopped after the default WasmGC suite passed; it is not counted as
an additional passing gate.

The [scoped optimizer dossier](wiki/tooling/npm-optimizer-discrepancy.md)
records private DFE admission, absent optional-arm analysis and bounded flat
coalescing. O4s retains its five-pass queue. The three dedicated 10,000-case
GenValid comparisons have no validation/generator/command failures, but
runtime/property modes were off and structural residuals remain. This is
scoped integration evidence, not full pass closure or universal equivalence.
The owner's same-original samples save an additional 55,014 GC / 107,345 WASI
bytes; the remaining Binaryen O4/s1 gaps are 1,687,415 / 91,972 bytes. Those
frozen-input samples are distinct from this combined source's fresh artifacts.

The combined source's fresh tarball contains 47 files and 4,801,791 bytes,
SHA-256 `c59a32ef17ee6538a1c9c6e4c5515b9b0b4763bae16d5067e99d2e78ebf2d411`.
Preserved evidence is under `dist/npm/qualified-combined/`, including raw and
optimized artifacts, build report, snapshot hashes and both consumer reports.
WasmGC changes from 7,452,238 to 7,232,670 bytes; WASI from 6,748,815 to
6,240,581 bytes. Local build time is 278,892 ms, including changed native source
compilation; optimization plus independent validation takes 8,410 / 9,138 ms.
API/CLI parity takes 627 ms and retains observation hash
`49034fc667f46d450d3147c525c10c9bb54f7663c85711df7cb9a1089ec0593c`.
These are single local samples, not a runtime-performance claim.

Normal offline installation into empty JS and strict NodeNext TypeScript
projects passes on Node 25.8.1 and 26.11.1 with TypeScript 5.8.3. All nine
exports, initialization, parse/validate/optimize/encode behavior and errors,
nominal type rejection, installed CLI `v0.1.2-beta.0`, transformation and
ambient-stack fixtures pass with checkout/compiler reads denied. The archive
includes both Wasm artifacts, declared JS/types, CLI and examples, with no
source, schema, private backend declarations, tests, raw artifacts or logs.
All 44 Node cases and 45 optimizer host/grow-select cases (90 expectations),
28 helper cases (105 expectations), generated drift and README sync pass.
Independent internal review found no new concrete defect and confirmed the
integration and package contracts. Exact final committed-head CI remains the
precondition for a normal nonforce master update; baseline native-debug and
coverage failures remain separate release gates.

Exact documentation head `c9fc25cd2` reproduces the same tarball in cold package
CI: 433,519 ms, with 14,587 / 15,442 ms GC/WASI optimization plus validation.
Its full 14,019 tests, release artifacts, package and fuzz checks pass. Complete
coverage is 28,244 / 226, still +106 / +30 against the unchanged baseline;
native-debug reproduces MoonBit #1322. The final required DAE job reached its
semantic comparison after successful boundary tests, fresh native builds
(14 min 33 s) and deterministic 10,000-case comparison (10 min 50 s), then hit
the old 30-minute whole-job deadline. Cancellation is not a semantic pass or a
reported semantic failure. Its complete logs and step timestamps are retained
under `dist/npm/source-publication/`.

The required DAE job now has a bounded 45-minute overall budget, retaining its
counts, profiles, runtime/property checks, validator/oracle requirements and
failure policy. Comparison reports and retained failure bundles upload on
success or failure. Red-first workflow contracts reject the old deadline and
missing evidence retention; actionlint passes. This fixes provisioning time
without changing optimizer source or package bytes. The exact new head must
complete all three protected checks before a normal source push; no bypass,
coverage reset or native-debug gate change is permitted.

## Candidate version consistency

MoonBit product metadata and npm metadata now prepare `0.1.2-beta.0`. The CLI
previously returned `v0.1.0`; its private version constant is generated from
`moon.mod` by `scripts/lib/generate-product-version.mjs`. Generation rejects
missing, ambiguous, malformed or inconsistent metadata before FFI work.
Required CI and `bun ffi check` reject stale generated version text. API
observations and installed CLI checks require the packed metadata version.
The candidate version remains subject to release review; this does not publish
the package or create a tag.

Path-filtered package, fuzz, coverage and native-example workflows now watch
`moon.mod` and nested `moon.pkg` files as well as legacy JSON metadata. This
closes a metadata-only trigger gap; it does not clear coverage or the compiler
ICE. The workflow contract rejects missing current-format triggers.

Before optimizer integration, the version-consistent candidate packed 47 files
into 4,822,247 bytes, SHA-256
`208ee14e3057fc04c22c023ca24661db8dcdc21f1f4927163e85007142f48b8b`.
Its raw/optimized GC artifacts are 7,452,114 / 7,287,545 bytes; WASI artifacts
are 6,748,746 / 6,347,866 bytes. The local rebuild took 235,654 ms with
8,386 / 9,059 ms GC/WASI optimization plus independent validation. This
recompiled changed native CLI source and is not an optimizer speed comparison.
Normal offline install, all nine exports, API behavior and installed CLI
`v0.1.2-beta.0` pass on Node 25.8.1 and 26.11.1; strict NodeNext TypeScript
5.8.3 passes. The 44 actual Node cases and 28 Bun helper cases pass. Evidence
is preserved under `dist/npm/qualified-version-preintegration/`.

The portable component deliberately retains WIT interface and metadata API
version `0.1.1`, preserving its export qualifiers. Product/npm metadata is
independent. Component generation derives its root dependency from the product
version; FFI version generation derives the same root dependency while keeping
the private adapter module version independent. The pinned 0.60.0 wit-bindgen
release was provisioned inside ignored `.tmp/component-tools/` after checking
the official release digest. Component generation/build/independent validation
passes, with no generated signature or ABI changes. The npm commands do not
publish npm, tags or releases.
