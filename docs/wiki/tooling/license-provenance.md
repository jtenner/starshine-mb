---
kind: investigation
status: working
last_reviewed: 2026-10-10
sources:
  - ../../../LICENSE
  - ../../../NOTICE
  - ../../../licenses/Apache-2.0.txt
  - ../../../licenses/Binaryen-LICENSE.txt
  - ../../../src/passes/LICENSE
  - ../../../src/passes/NOTICE
  - ../../../licenses/moonbit-core-NOTICE.txt
  - ../../../moon.mod
  - ../../../node/package.json
  - ../../../src/passes/pick_load_signs.mbt
  - ../../../src/passes/binaryen132_descriptor_test.mbt
  - ../../../src/passes/dead_argument_elimination2_intake_wbtest.mbt
related:
  - ./node-package-surface.md
  - ../../npm-beta-handoff.md
---

# Starshine license provenance

The user prefers MIT for original code he owns. [LICENSE](../../../LICENSE)
now scopes that grant to Joshua Tenner's rights and preserves incorporated
third-party rights. Package metadata is `SEE LICENSE IN LICENSE`, with full
[NOTICE](../../../NOTICE), Apache-2.0 text and the unabridged MoonBit Core
NOTICE explicitly packed. This is not an MIT-only bundle or a dual-license
choice for the whole bundle. The source module's existing `Apache-2.0`
declaration is retained. On October 10 the owner authorized conservative
Binaryen license and notice inclusion: “Let's be safe and assume we need to
provide binaryen's license anyway.” This settles the distribution treatment
without settling unknown factual provenance. No MIT-only pass claim follows.
This choice does not authorize npm publication, a release/tag or credential
changes. Normal source publication was separately authorized.

## Author account and conservative choice

The author reports that all algorithms and goals were rewritten to accommodate
Starshine node IDs and its IR, and prefers retaining Binaryen terms to be safe.
This is an account of substantial rewriting, not an admission that every pass
is a direct copy or proof that every current file is independently authored.
In a follow-up answer, the author confirmed: “Source was used; retain upstream
terms.” This establishes source use in the rebuilding workflow, without naming
the exact originating revision or copied/adapted portions in every current
file. The concrete PickLoadSigns/fixture evidence remains identified separately;
file-specific origin and expression scope remain unconfirmed elsewhere. The chosen conservative distribution
treatment does not require asking the same broad provenance question again.

## Pass/category matrix

| Category / exact evidence | Provenance assessment | Required treatment / unresolved action |
| --- | --- | --- |
| Original npm facade, schema-derived JS/TS, original FFI adapter/build glue and consumer examples; root MIT grant since `fdbf4aba6` | Supported scoped original-code grant; ABI similarity alone does not prove copying. Git author labels, including `OpenAI`, do not establish copyright ownership or assignment. | MIT only for Josh-owned portions; preserve upstream rights. Generated wrappers do not change the licensing of compiled callees. |
| [PickLoadSigns](../../../src/passes/pick_load_signs.mbt): `PLSUsage`, `pls_target_signedness`; historical initial owner and re-add `116b7751` | Strong adaptation evidence: five usage fields in the same order, four signedness guards and weighted choice correspond to upstream `PickLoadSigns.cpp`; the historical owner carried an Apache/WCG notice. New HOT/use-def/caching/boundary work is distinct. | Conservatively retain Apache-2.0 for the adapted file, upstream 2017 WCG attribution and historical 2023 notice, plus a prominent changed-file notice. Original modifications do not erase upstream obligations. |
| [Descriptor regression](../../../src/passes/binaryen132_descriptor_test.mbt), [DAE2 intake](../../../src/passes/dead_argument_elimination2_intake_wbtest.mbt) | Explicit upstream fixture references: v132 `local-subtyping-desc.wast` and `dae2.wast` modules 064/071. Encoding or translating fixtures does not erase provenance. | Retained Apache attribution and adaptation notices; source tests are not included in npm. Do not treat the DAE2 implementation as derivative solely because its tests are adapted. |
| ReorderLocals (`da565f651`), OptimizeInstructions (`6bacefeb0`), Precompute (`651e253b4`), Vacuum/HOT pass manager (`8a71d8463`) | Old owners had Apache notices; the optimizer was removed wholesale in `4f15bce6b`, then reimplemented incrementally. Bounded old/current and pinned-upstream review found different HOT structures. Shared algorithms/output parity do not prove derivation; absence of literal match does not prove independent authorship. | Keep the module declaration, conditional source/change notices, exact historical attributions and full Binaryen license under the owner-authorized conservative policy. Factual derivation stays unknown; no blanket Apache-derived or clean-room claim. |
| Other pass owners/helpers at frozen `1cbf1ae55`; 114 production `.mbt` files inventoried, 36 match historical notice-bearing paths | Broad source/header/history inventory, not an exhaustive line-by-line upstream derivation judgment. Syntax-only matches and mathematical encoding constants were rejected as copying proof. | All 114 inventoried files at that checkpoint carry scoped, conditional provenance and prominent Starshine change notices; 35 unresolved historical path matches retain historical 2023 WCG attribution, plus separately identified Pick. Forty pinned v130 counterpart copyright lines are retained in source and distribution NOTICE. These are conservative attributions, not findings of factual copying. |
| `moonbitlang/core` 0.10.14+7d59c7ec9, compiled into both Wasms | Installed module declares Apache-2.0; exact LICENSE/NOTICE bytes corroborate current official upstream text. Full NOTICE includes IDEA, V8/fdlibm, Go, Arm MIT and FreeBSD terms. | Ship exact full texts, without guessing which linker-eliminated routines make notices removable. A dependency update must renew review. The version suffix was not resolved to a public Git revision (raw404/API422); matching main text does not prove revision identity. |
| `moonbitlang/x` 0.5.1, `src/fs/moon.pkg` imports x/fs; installed `fs_wasm.mbt` has IDEA/Apache header | Compiled dependency, independent of whether the separate JS host was copied. Inspected JS host uses its own numeric handle/error protocol; shared names/sentinel are ABI, not copying proof. | Ship full Apache text and IDEA attribution; upstream source headers retained. Installed x has no NOTICE. A new NOTICE or version/license change stops the build for review. |
| Compiler/native bootstrap, Bun, Node, wasm-tools, TypeScript and Binaryen oracle | Developer tools are not distributed in npm. Installed native runtime C carries Apache/IDEA headers. Compiler output license freedom does not override embedded library or adapted-source terms. | No tool binary is added to the consumer payload. Distribution NOTICE conservatively retains installed runtime support Copyright 2026 IDEA/Apache attribution without asserting the C files are linked into either Wasm. Exact compiler-provided runtime inclusion has not been exhaustively mapped. |
| Specification fixtures under `tests/spec` | Existing dedicated Apache LICENSE; test assets are excluded from npm. | Preserve source license/notices on repository redistribution. |
| Documentation, oracle logs, and any upstream excerpts | Author-written analysis/oracle behavior is not derivative code just because it discusses Binaryen. Any actual copied expression retains its upstream terms. | Retain relevant attribution for copied excerpts; do not indiscriminately relicense the whole documentation tree. |

## Historical pass paths requiring source-process evidence

Initial `fdbf4aba6280acc58e07992174729e6589c46265` contains 70 notice-bearing
legacy source files and a full `src/passes/LICENSE`. Commit `4f15bce6b` removed
the optimizer tree, not just headers. These 35 still-present paths, excluding
identified PickLoadSigns, are investigation candidates rather than confirmed
derivatives:

- `src/passes/avoid_reinterprets.mbt`, `src/passes/coalesce_locals.mbt`, `src/passes/code_folding.mbt`, `src/passes/code_pushing.mbt`, `src/passes/dead_code_elimination.mbt`.
- `src/passes/directize.mbt`, `src/passes/duplicate_function_elimination.mbt`, `src/passes/duplicate_import_elimination.mbt`, `src/passes/flatten.mbt`, `src/passes/global_effects.mbt`.
- `src/passes/global_refining.mbt`, `src/passes/global_struct_inference.mbt`, `src/passes/global_type_optimization.mbt`, `src/passes/heap2local.mbt`, `src/passes/heap_store_optimization.mbt`.
- `src/passes/i64_to_i32_lowering.mbt`, `src/passes/inlining.mbt`, `src/passes/local_cse.mbt`, `src/passes/local_subtyping.mbt`, `src/passes/memory_packing.mbt`.
- `src/passes/merge_blocks.mbt`, `src/passes/merge_locals.mbt`, `src/passes/merge_similar_functions.mbt`, `src/passes/once_reduction.mbt`, `src/passes/optimize.mbt`.
- `src/passes/optimize_casts.mbt`, `src/passes/optimize_instructions.mbt`, `src/passes/precompute.mbt`, `src/passes/remove_unused_brs.mbt`, `src/passes/remove_unused_names.mbt`.
- `src/passes/reorder_globals.mbt`, `src/passes/reorder_locals.mbt`, `src/passes/simplify_locals.mbt`, `src/passes/tuple_optimization.mbt`, `src/passes/untee.mbt`.

The remaining current owners/helpers also need an actual author/source-process
record before an MIT-only claim. Options are: (1) keep accurate Apache treatment
for adapted expression while licensing original additions under MIT; (2) obtain
permission from every relevant upstream rightsholder for an alternative grant;
(3) independently replace the protected expression using documented requirements
and independently authored tests, then review the result. Attribution alone is
not permission to discard a license. A general author recollection must be
checked against the concrete retained-expression evidence.

## Official sources and attribution rules

[Apache-2.0 section 4](https://www.apache.org/licenses/LICENSE-2.0) requires the
license text, retained applicable source notices, changed-file notices and
applicable upstream NOTICE attribution when supplied. Different terms for own
modifications are permitted while incorporated obligations remain. The inspected
Binaryen v130 (`5d704ad5`), v132 (`79dfe6b4`) and v133 (`fba5005a`) trees contain
no NOTICE. [Binaryen's license](https://github.com/WebAssembly/binaryen/blob/version_133/LICENSE)
is Apache-2.0 with separately licensed third-party parts; no FP16 or LLVM
incorporation was found in these Starshine assets. That MIT exception does not
apply to the main pass sources.

The [MIT text](https://opensource.org/license/mit) requires retaining its
copyright and permission notice. The [Copyright Office guidance](https://www.copyright.gov/circs/circ61.pdf)
distinguishes protected program expression from algorithms and functional
aspects; this audit does not adjudicate any particular copyright threshold.
[npm metadata](https://docs.npmjs.com/cli/v11/configuring-npm/package-json/)
supports a scoped `SEE LICENSE IN filename` arrangement. `OR` would wrongly
imply an unrestricted choice for included third-party code; a simplistic `AND`
would omit additional retained third-party terms.

[MoonBit's compiler licensing statement](https://www.moonbitlang.com/blog/compiler-opensource)
permits users to choose output licenses. It does not relicense third-party
library content incorporated into that output. Core's installed LICENSE and
NOTICE are byte-identical to the captured official main texts, hashes
`86460c45017ffacb9aa9e18850fa9fdb036339dc8851125465f4a3f3442fc894` and
`047a7cd5e93c10a8a753b7f152c371ef309b523c4d9b945ec5776321e7e602fb`.

## Build and distribution controls

Canonical legal files live at the repository root and `licenses/`; generation
copies all five verbatim into `node/`. Check mode rejects missing/changed copies.
Before compilation, the build checks installed Core and both installed x module
versions/licenses, matches Core LICENSE/NOTICE to the reviewed bytes, and refuses
an unreviewed x NOTICE. It records dependency notice hashes in `build-report.json`.
This pins the reviewed text/version pair; it is not a cryptographic proof of all
upstream dependency code. A shared `/tmp` tmpfs overflow during native assembly emission was retained as
a failed attempt; the unchanged-source retry uses workspace-backed `TMPDIR`.
The npm README documents that scratch setup. A separate restricted execution
returned empty Node Wasm-observer stdout after successful compilation; ten
reproductions were empty there while ten identical host probes returned the
expected values. Its exact cause remains unproved, and the unchanged host build
retains every validation gate rather than accepting an empty observation. This capacity failure is separate
from MoonBit #1322 and from license/ownership conclusions.

Builders using an alternative Moon installation must
point `MOON_BIN`/`MOON_HOME` at that same reviewed installation.

The npm build resolves the FFI workspace with a release WasmGC build dry-run
before checking its registry input licenses. `moon update` does not materialize
this FFI dependency tree in the tested toolchain. A clean CI checkout otherwise has no
`ffi/.mooncakes/moonbitlang/x` metadata until the first FFI build. Resolution
errors and changed notices still stop the build before artifact compilation;
the dependency-resolution log is retained with build evidence. The first
published licensing-head Node package run exposed this ordering gap and is
preserved as a failed attempt, followed by the regression-tested correction.

Packed-consumer checks require all five assets in the actual tarball and verify
exact bytes after offline installation, alongside JS/API/CLI and strict TS
checks. These legal corrections are separate from published checkpoint
`b0b3cdc104b1a41cb2e249f9a696c96c5bfb0dcc`; its historical 47-file archive is
preserved, not retroactively called compliant. At the frozen licensing
checkpoint `1cbf1ae55c62ab1e96553e5fb359a9a6eda845f3`,
the source patch changes licenses, comment headers, metadata, documentation
and build checks; executable pass bodies are unchanged. Later optimizer
changes require separate artifact and consumer qualification. Rebuilt Wasm
hashes differ; bounded old/current API/CLI
observations match, without an exhaustive equivalence or layout-remap proof.

The full Binaryen license is byte-identical in the pinned v130/v132/v133
source distributions: 11,535 bytes, SHA256
`64c0d02491e16eced74826440ecd2bcf7722d37fa586faf457b2494293afbffe`.
It retains the upstream FP16 trailer; that trailer describes Binaryen, not a
finding that FP16 is distributed here. The five package assets are `LICENSE`,
`NOTICE`, `licenses/Apache-2.0.txt`, `licenses/Binaryen-LICENSE.txt`, and
`licenses/moonbit-core-NOTICE.txt`. `src/passes/LICENSE` is the same full
Binaryen bytecopy; `src/passes/NOTICE` records source scope and attributions.

Independent internal review approved the conservative source/license treatment
and exact archive after source, notice-byte, manifest and installed consumer
checks. Remaining file-specific provenance stays open for any future relabeling; this is technical compliance evidence,
not a definitive legal opinion or authorization to publish npm.

## Qualified conservative licensing package

This section records the frozen `1cbf1ae55` checkpoint and its exact archive.
It does not qualify subsequent optimizer or preset changes.

The exact 52-file archive is 4,289,718 packed / 13,457,162 unpacked bytes,
SHA256 `78d2d8c39ea9bc16a22ce37ecf4bbb5829636d9ab2d0a6d5f66f7af75580fb0c`.
It adds five canonical legal assets to the historical 47-file candidate with
no removals. README, metadata and both freshly rebuilt Wasms changed; all
other JS/declarations/examples are byte-identical. No private audit/source/debug
files entered the tarball. Both installed consumer reports name this exact hash.

| Artifact | Raw / optimized bytes | Current optimized SHA256 |
| --- | --- | --- |
| WasmGC API | 7,475,602 / 6,560,165 | `12680cce03e76800fbd3df8e95d1ae94813d4d018cde09ed3ee7021b16cb414e` |
| WASI CLI | 6,774,798 / 6,013,480 | `4cee1a9677b02321ed343d4c7b1072f1d5dbb6562a6cc98a333bfdd6c5077959` |

At this frozen checkpoint, all 114 production pass bodies match published b0
after excluding the leading notice comments. Raw and optimized sizes match that checkpoint, while hashes
and several standard section payloads differ. The exact compiler layout/change
mechanism has not been proved. Independent host Node 26 old/current observers
produce equal complete scoped API JSON (SHA256 `49034fc667f46d450d3147c525c10c9bb54f7663c85711df7cb9a1089ec0593c`)
and byte-identical CLI help; all four old/current Wasms independently validate.
This qualifies the observed scope, not every possible API behavior or a full
binary remapping proof.

Normal host prepack compiles the GC adapter, native bootstrap and WASI CLI,
then applies Starshine's numeric O4s 4/1 five-pass route. Independent validation,
required ABI checks, raw/optimized API/help parity and the 70→48-byte witness
returning 84 all pass. No unoptimized fallback was used. The single build's
GC/WASI optimization times were 8,030/9,341 ms; these are diagnostics, not a
controlled performance claim. The installed Core/x notices passed their guards.

Empty external JS and strict TypeScript 5.8.3 consumers pass on Node 25.8.1 and
26.11.1 with all nine exports, initialization, errors, roundtrips, optimization,
CLI and exact legal bytes; runtime reads of the checkout/MoonBit are denied.
Checkpoint Node API tests pass 44/44; build helpers pass 32/32 (132 assertions).
Generated/declaration/legal drift and the static package contract pass. Failed
tmpfs and restricted-observer attempts remain recorded separately; neither is
substituted for the successful host qualification.

All six master workflows pass at exact head `1cbf1ae55`, including 14,086
default and 14,083 WasmGC tests. CI packs the byte-identical archive above.
Coverage reports 28,020 uncovered lines across 225 files against the unchanged
28,138 / 196 baseline. The retained DAE CI lane uses Binaryen 132; it does not
establish Binaryen 133 signoff. The preceding licensing-head npm failure and
Required cancellation remain recorded, followed by the clean-dependency fix.
Normal master pushes reported administrative required-check bypass warnings;
no protection or credential changed. Candidate version, publishing/provenance
configuration and npm approval remain separate;
existing memory P1 and optimizer/raw-serialization gaps stay open.
