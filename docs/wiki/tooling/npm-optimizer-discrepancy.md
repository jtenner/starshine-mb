---
kind: investigation
status: working
last_reviewed: 2026-10-10
sources:
  - ../../npm-beta-handoff.md
  - ./node-package-surface.md
  - ../../../src/passes/optimize.mbt
  - ../../../src/passes/duplicate_function_elimination.mbt
  - ../../../src/passes/o4s_private_duplicates_test.mbt
  - ../../../src/passes/dfe_gc_retention_wbtest.mbt
  - ../../../src/passes/dfe_gc_index_sharing_wbtest.mbt
  - ../../../src/passes/oi_optional_control_wbtest.mbt
  - ../../../src/passes/pass_manager.mbt
  - ../../../src/passes/coalesce_artifact_tiny_perf_wbtest.mbt
  - ../../../src/passes/coalesce_tiny_budget_wbtest.mbt
  - ../../../tests/optimizer/regressions/oi-grow-select.test.ts
related:
  - ../binaryen/passes/duplicate-function-elimination/starshine-strategy.md
  - ../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../binaryen/passes/coalesce-locals/starshine-strategy.md
  - ../ir2/registry-map.md
---

# npm O4s optimizer discrepancy

## Inputs and scope

Fresh fetch verified `origin/master` at
`9057a5d8a5a5b85859c702c76d0cbe3e9f18ab55`. Optimizer work is isolated on
`codex/optimizer-disparity`; packaging/CI/release workflow retains its existing
owner. No npm publication, tag, release or master push belongs to this task.
Licensing remains undecided.

Both optimizers must read the same original name-stripped artifact, never the
other optimizer's output. Original WasmGC: 7,452,107 bytes,
`059555428f569dcd57275757be8453a4f4881eb80592f9f80e402b4987072de3`.
Original WASI: 6,748,730 bytes,
`b7dd0896d7b41989e1aa29bd297d3fd63097b7e3b7f76883e9897f25010add52`.
The source report, comparison, handoff and both originals are immutable;
local evidence copies have a SHA-256 manifest outside the worktree.

A fresh native release build of the verified baseline reproduces the selected
WasmGC O4s output, 7,287,538 bytes,
`6ace60a63b33dda84c15067ca2ab60b702a6e74e3edb7bfca7d158761984bbea`.
Its pass trace confirms preset DFE is skipped for host-visible identity.
O4s numeric levels 4/1 select only DFE, constraint analysis, vacuum, reorder
locals and strip debug. These are different queues from Binaryen's O4/s1.

## Private duplicate admission regression

The broad preset DFE guard suppresses all duplicate merging on modules with
imports/exports. The actual pass already marks each exported and runtime
address-materialized function and refuses to merge either protected endpoint.
This includes active/passive elements, globals/tables and `ref.func` through
structured/EH bodies. Direct calls and start invoke functions without exposing
an address; declarative element payloads only satisfy validation declarations.

Focused regressions require O4s to merge private duplicate helpers while
preserving import slots, exported and table/global function identities, direct
call remapping, validation and input ownership. Candidate admission must also
exclude protected functions before duplicate normalization/pair enumeration,
so broad preset admission does not expose quadratic protected-only buckets.

Independent read-only source review supports the narrower admission and
identified that bucket-cost issue plus the separate CLI O4z portfolio filter.
This is preliminary review, not runtime or final release signoff.

## First bounded implementation checkpoint

The preset now runs identity-protecting DFE rather than skipping the complete
module. Protected functions still contribute rewrite/cleanup facts but never
enter normalization or duplicate pair enumeration. The CLI automatic O4z
candidate filter retains DFE and keeps its separate DIE restriction.

Fresh native binary SHA-256:
`ea899c2d07a03af4c634e8634d886dbf0bfe92524be9820b4ac01d7159844a8e`.
The following single serial samples start from the identical original inputs;
wall/RSS exclude independent validation and consumer tests, and are local samples.

| Artifact | Previous O4s bytes | DFE-fixed O4s bytes | Further reduction | Time (s) | Peak RSS (KiB) |
| --- | ---: | ---: | ---: | ---: | ---: |
| WasmGC | 7,287,538 | 7,232,524 | 55,014 | 8.260 | 267,636 |
| WASI | 6,347,850 | 6,240,505 | 107,345 | 9.058 | 278,852 |

Both outputs independently validate under
`wasm2,gc,function-references,tail-call,extended-const`.
GC output SHA-256:
`cda21fda5f83717853d719433996cb215a41aa3529e41515e557d66ab80608cb`.
WASI output SHA-256:
`53987fb549842534484f05fc995d52cd7cc1d9d37ae9b53b6947a3accc484df8`.
The reduced Node fixture preserves results 84, repeated state increments,
state 91 before an unreachable trap, export names, distinct exported/table/global
identities and their callback aliases. These bounded controls do not establish
universal equivalence.

## Correctness and bounded cleanup fixes

Instruction write-set analysis previously walked HOT's `-1` absent optional
else/catch sentinel as a live node. A valid no-else HOT fixture reproduced the
abort seen in direct OI on the original GC artifact. The fix skips exactly that
sentinel while collecting every present arm's writes. The original direct OI
now completes and independently validates. OI is not added to the fast preset.

At numeric levels 4/1, bounded coalescing excluded all ordinary bodies once a
module reached 2,000 defined functions. The additional lane admits at most 64
body locals, 32 parameters and 128 flat instructions, excluding structured/EH
containers and control/continuation transfers. Existing nondefaultable, runtime,
snapshot, identity and per-body validation/rollback guards remain. The touched
path also restores the full direct pass's stack-carried overwrite guard;
validation cannot detect changed call arguments. Dense analysis is capped at
96 slots for each newly admitted body. Admission/application each build a linear
parameter cache; sparse selection can still scan unrequested tiny bodies.

Appending bounded coalescing to O4s from the same originals saves only another
2,165 GC / 5,769 WASI bytes. The clean GC sample costs 9.364 seconds versus
8.248 for the retained preset. The WASI diagnostic overlapped another probe,
so its time is excluded from performance conclusions. This payoff does not
justify expanding the wall-time-first beta queue. Both direct fixes remain
available without changing packaging's five-pass contract.

## Final same-original measurements

Fresh native bootstrap SHA-256:
`aaf2270a26e51679a6f5f15560aec75c1c41cf82b98464008d9e4fea90ce0a22`.
Verified Binaryen **133** (`version_133-60-g93d6e9de7`) SHA-256:
`646443d963e0ea180a57a6dc92a4b31ebbb0693cb85149598f8a7c5ac503bb1a`.
These are single serial samples; wall/RSS exclude independent validation.

| Original | Optimizer | Bytes | Time (s) | Peak RSS (KiB) |
| --- | --- | ---: | ---: | ---: |
| GC | Starshine 4/1 | 7,232,524 | 8.248 | 266,876 |
| GC | Binaryen O4/s1 | 5,545,109 | 23.611 | 1,074,344 |
| GC | Binaryen Oz | 5,551,472 | 14.290 | 426,352 |
| WASI | Starshine 4/1 | 6,240,505 | 9.044 | 278,536 |
| WASI | Binaryen O4/s1 | 6,148,533 | 30.061 | 1,203,900 |
| WASI | Binaryen Oz | 4,857,635 | 8.442 | 495,660 |

All outputs independently validate with
`wasm2,gc,function-references,tail-call,extended-const`, retain export names and
kinds (2,849 GC / 2 WASI), and preserve absent `target_features` metadata. All
four Binaryen hashes reproduce the original qualified report. Binaryen uses
`BINARYEN_CORES=8`, `--mvp-features`, mutable globals, sign extension,
nontrapping float-to-int, bulk memory, reference types, multivalue, GC, tail
calls and extended constants; WASI additionally enables SIMD. Optimization is
`-O4 -s 1` or `-Oz`. Every invocation reads the original input directly.
All-feature Node-incompatible encodings and chained optimization remain excluded.

The remaining O4/s1 gaps are 1,687,415 GC / 91,972 WASI bytes. GC's code section
is 6,614,667 versus Binaryen's 5,070,579 bytes; its type section remains 176,778
versus 74,881. All compared custom sections total 69 bytes. Debug metadata
therefore does not explain this gap. The fast preset omits broader inlining,
argument/type refinement and other full-queue transformations. Mixed recursive
GC type pruning requires canonical dependency/identity proof; a raw function
signature scan found only one exact duplicate, so widening simple-type cleanup
alone is not a defensible shortcut. Standalone pass totals can include CLI
canonical encoding; incremental preset samples are used for admission decisions.

Compared with the historical O4s sample, WASI peak RSS rises from about 235 to
272 MiB and time from 8.47 to 9.04 seconds for the 107,345-byte saving. GC RSS
rises from about 256 to 261 MiB with similar wall time. These local observations
record the resource tradeoff, not a universal performance claim.

## Qualification and limits

- `moon info`, `moon fmt` and all **14,010** default wasm-gc tests pass. The
  skipped 2,000-function lane passes explicitly and preserves the complete
  original encoding. An old CLI roster expectation was updated after the full
  suite exposed it; behavior remains covered by positive private-merge tests.
- The final native binary passes all **13** existing Node host-identity
  regressions. Reduced controls compare results, repeated state, memory,
  imported callback arguments, traps, and exported/table/global identities.
  The artifact-scale coalescing control retains 2,002 exports and matches
  values 12/20, callback observations, memory and state after an unreachable trap.
- The subsequent [Binaryen grow/select lead](https://github.com/WebAssembly/binaryen/pull/9227)
  does not establish a local bug. Starshine already marks grows as effectful
  and requires explicit equality facts. All **32** bounded Node qualification
  cases preserve sequential old sizes, final memory/table sizes and both select
  outcomes across successful, zero, failed and partially failed growth, including
  eager operand/condition callback ordering. No implementation change is needed.
- Three **10,000**-case direct-pass aggregates use freshly built native optimizer
  and generator, verified Binaryen 133, seed `0x5eed`, at most eight subprocesses
  and independent wasm-tools validation. Normalized/residual counts are DFE
  5,000/5,000, CL 3,750/6,250 and OI 8,623/1,377. Validation, generator and command
  failure counts are zero. Runtime/property modes are off; zero counters do not
  establish checks that were not enabled. Only 20 ordinary residual bundles per
  lane are retained. Independent source review identifies scoped private-call
  and nop/wrapper size wins; broader OI tuple/effectful residuals stay open.
- Exact-original before/after package copies pass bounded API/CLI parity and
  isolated JavaScript / strict TypeScript consumers on Node26.11.1 / TS5.8.3.
- A separate fresh-source build regenerates FFI-backed JavaScript and TypeScript,
  verifies numeric levels 4/1 and the unchanged five-pass queue, self-optimizes
  without Binaryen, validates both artifacts, and passes API/CLI parity plus
  isolated packed JS/strict TS consumers. Packaging/CI implementations and
  generated tracked files remain unchanged. This fresh build is a different
  input: GC 7,452,231 -> 7,232,663; WASI 6,748,799 -> 6,240,565 bytes. It is not
  mixed into the original-input comparison.
- Fresh archive SHA-256:
  `de4459cfec0e1723b8b4a82e4fbca518ed198b272dde51dba764e2ddb6d73ff2`.
  Native tool, original/fresh input/output hashes, commands, qualified archive,
  consumer reports and full logs remain in the delegated task's local evidence
  directory. Original reports/artifacts are rechecked unchanged.

Independent review found no code blocker in the three fixes and final test
updates. This is a scoped implementation checkpoint, not closure of every pass
or universal semantic parity. Broader GC/preset opportunities and effectful OI
families stay on the backlog. `bun validate full --profile ci --target wasm-gc`,
coverage/native-example CI gates and exact integrated-head release qualification
remain with preparation owner/parent; they are not claimed here. Licensing stays
undecided. Local commits are ready for coordinated source integration; this task
performs no push, npm publication, release/tag, deployment or credential changes.


## October 10, 2026 — Native-debug compatibility and resource qualification

MoonBit 0.1.20260920 / moonc 0.10.14+7d59c7ec9 fails native-debug lowering
of uninitialized non-null reference arrays containing the mixed `#valtype`
`HotLowerStackValue` record (upstream issue #1322). The private native stack
now uses an initialized `FixedArray` and a logical count. Other targets retain
core `Array` storage. Push growth and copy initialize every slot; indexed access
checks logical bounds. Pop, clear and truncate retain slots like core Array,
keeping their constant-time cost and the observations of retained iterators.
The record remains a value type; no optimizer algorithm or public API changes.

Native regressions cross both growth boundaries with scalar and nullable
reference types, check every value/type in a copy and retained iterator, and
exercise replacement, removal and empty states. Existing lower-stack fixtures
use target-aware factories with their assertions preserved. Actual native-debug
CLI compilation, all three example groups (six independently validated outputs)
and the existing installed-validator test pass. Large debug test linking also
needs `ulimit -s 65536` with this compiler: the default 8 MiB process stack
reported a compiler stack overflow after the array issue was cleared. CI applies
this 64 MiB limit only in the relevant test processes, keeps the debug target,
and watches IR changes in both push and pull-request filters.

Three paired serial native-release O4s runs per preserved package input produce
identical output hashes and sizes before/after this compatibility change. All
12 outputs independently validate. Order alternates between baseline and
candidate. Local median wall time and peak child RSS are:

| Input | Baseline seconds | Candidate seconds | Baseline KiB | Candidate KiB |
| --- | ---: | ---: | ---: | ---: |
| WasmGC | 8.634 | 8.613 | 268,412 | 268,080 |
| WASI | 9.535 | 9.859 | 278,688 | 279,016 |

The WASI median is about 3.4% slower; ranges overlap and median RSS differences are
under 1 MiB. This short sample supports compatibility and bounded resource
cost, not a speed win. Full source/package qualification is recorded separately
in the npm handoff. The later GC canonicalization and memory-repair checkpoints
remain isolated pending the owner's memory decision; their results are not
attributed to this initialized-storage change.

## Follow-up after the reviewed checkpoint

The reviewed `62ba4012f` checkpoint is retained for the preparation owner's
coordinated integration. Follow-up starts on a separate local branch at that
commit. Original GC has 15,944 types (10,889 function / 4,651 struct / 404 array)
and 105 explicit recursive groups; checkpoint keeps all types while Binaryen
O4/s1 retains 6,757. Direct inlining and DAE execute on the original, so their
omission from the fast queue is distinct from blanket admission failure.

RUME disables all type compaction when any recursive group has more than one
member. A reduced public-pipeline regression requires whole-group removal,
last-member-only rooting and the dependency of an otherwise unrooted sibling;
it currently retains five recursive entries rather than three. The proposed
extension must retain all members/order of every live group, without splitting
or merging, and use flat type indices for roots/remapping.

Independent source review found prerequisites: the standalone RUME remapper
omits legacy exception children/catches, continuation operands and descriptor
branch casts; both shared remapper copies lose exactness flags when rebuilding
ordinary branch casts. Focused regressions reproduce these omissions. They must
be repaired before recursive-group admission. No fast preset or packaging
contract has changed in this follow-up.

The remapper prerequisites are now repaired independently of group admission:
all cast reconstruction paths preserve nullable/exact flags, continuation and
descriptor operands preserve non-type indices, and standalone legacy exception
rewriting walks body/catches with lazy changed-catch storage and unchanged
delegate depths. The shared DFE scan tracks the newly represented type operands.
Focused positive type/field assertions replace a mistaken negative assumption
about identity-map entries with an unrelated-index map; the existing optional
reference helper may reconstruct an unchanged identity-mapped reference.

Whole-group pruning now replaces the blanket multi-member-group skip. Roots
and maps use flattened type indices; one linear owner table resolves indices
to groups. Each live group retains all members in order and visits every
member's dependencies once. Type and field names use the same flat remap.
Independent review additionally found reference-only functions whose bodies
become `unreachable` but whose locals remain; a separate red regression exposed
missing local type roots, now retained before dependency closure. Focused RUME
checks pass 26/26, including sibling dependencies, last-member roots, named
members, group-local IR `RecIdx` preservation and bounded visit counts.

A diagnostic structural walk of the original skeleton estimates 4,678 duplicate
backward-referencing singleton types (2,554 struct / 139 array / 1,985 function),
while leaving explicit groups and self/forward references untouched. This is a
lead for reduced canonicalization work, not a transformation or semantic proof.

DFE's GC remapping prerequisite now also covers `struct.wait` and array memory
load/store type operands, preserving complete memory arguments. Its selective
rewrite predicate recognizes every aggregate atomic type operand. The reduced
12-form helper regression passes; independent source audit found no omitted
represented type-bearing instruction in full/optional/scan/predicate matchers.
The existing liveness-pruner guard remains restricted to independent function
types; this prerequisite alone does not admit GC canonicalization.

Bounded mixed-GC canonicalization now walks singleton types once before DFE body
hashing. It interns complete subtypes only when every explicit dependency points
strictly backward, preserving finality/supers, storage/mutability and nullable/
exact references. Equal abbreviated/expanded abstract references use one key
representation. Explicit group members never enter the singleton dictionary;
shared, descriptor, continuation, inline `DefType`, `RecIdx`, self and forward
forms remain distinct. A dense flat map rewrites every surviving definition and
operand, including protected imported/exported interfaces. Existing plain-type
interning and dead-type pruning guards remain unchanged. No new preset pass is
added: numeric 4/1 reaches this through its existing DFE slot.

Reduced public fixtures verify transitive struct->array->function aliases,
private-body merging, shifted two-member groups, GC import/global/local operands
and nonfinal-base/final-child chains. Boundary fixtures cover identity exclusions,
key equality and a no-alias canonical-byte control. Independent source review
approves this bounded lane; full tests, native artifact impact, runtimes and
consumer qualification follow separately before integration readiness.

## Qualified bounded GC follow-up

Implementation `5c16ded2e410607b23f9e25399b2ca219fb39f46` has a fresh native
SHA-256 `2364a2c553c27c949f0406d25808c32a42258547dc9484f9db8c2b796ea06c55`.
The final default wasm-gc suite passes 14,032/14,032. Independent read-only
source and evidence reviews approve the scoped checkpoint.

Every measured optimizer below starts directly from the immutable ORIGINAL
inputs above. Binaryen 133 uses eight workers and the recorded runtime-compatible
feature flags. No chained or idempotence-based artifact comparison is used.
These are single local wall/RSS samples, not universal performance claims.

| Original input | Optimizer | Bytes | Wall seconds | Peak RSS KiB |
| --- | --- | ---: | ---: | ---: |
| GC 7,452,107 | Starshine numeric 4/1 | 6,960,836 | 7.713 | 321,228 |
| GC 7,452,107 | Binaryen O4/s1 | 5,545,109 | 23.744 | 1,081,080 |
| GC 7,452,107 | Binaryen Oz | 5,551,472 | 13.739 | 468,452 |
| WASI 6,748,730 | Starshine numeric 4/1 | 6,240,505 | 8.962 | 278,720 |
| WASI 6,748,730 | Binaryen O4/s1 | 6,148,533 | 30.414 | 1,202,608 |
| WASI 6,748,730 | Binaryen Oz | 4,857,635 | 8.367 | 509,012 |

All outputs validate independently; repeated Binaryen outputs match historical
hashes. Starshine GC output SHA-256 is
`a8200e0b6c257a2778786548ab8ad6f40a8a5992a17a3a8d0795212c3e99b55c`;
WASI remains byte-identical to the previous checkpoint, SHA-256
`53987fb549842534484f05fc995d52cd7cc1d9d37ae9b53b6947a3accc484df8`.
Public export names/kinds/order remain 2,849 GC and two WASI entries.

The follow-up saves 271,688 GC bytes beyond the previous 7,232,524 checkpoint
(491,271 from original). It removes exactly 4,678 aliases: 2,554 struct, 139 array,
1,985 function; 11,266 types and 21,794 functions remain. All 105 explicit recursive
groups remain. The type section falls 176,778->129,540 bytes; code falls
6,614,667->6,393,827 relative to the previous checkpoint. Custom metadata stays
69 bytes, confirming it is not the disparity's cause. Direct original DFE is
6,977,189 bytes/1.466 seconds/277,796KiB. The single-pass prefix/dictionary lane
avoids recursive unfolding and whole-prefix comparisons. Its extra normalized
keys/remap and transformed bodies increase preset peak RSS from 266,876 to
321,228KiB in these samples despite lower wall time; retain that tradeoff.

Renewed DFE GenValid uses an explicit fresh native binary, unchanged explicit
generator SHA-256 `11f3b1920b6cf07c96f61b75c679ec710c9a57fe111a127fbb72ec18f3a6ab65`,
v133, seed 0x5eed and eight subprocesses. It completes 10,000 cases: 5,000 matches
plus 5,000 residual comparisons classified by reviewer judgment as scoped
six-byte wins. Every residual is the existing private constant/caller family;
all 20 retained outputs byte-match the previous reviewed checkpoint. There are
zero validation/generator/command failures and no larger canonical outputs.
Runtime/property modes are off; this profile does not supply GC alias coverage.

Separate bounded GC subtype runtime renewal has 256/256 normalized and primary
original/Starshine/Binaryen semantic matches, zero blocked/mismatching cases and
zero validation/generator/command failures. The initial sandboxed run's 256
runtime blocks are retained; approved subprocess access resolves them, using the
same byte-identical generator manifest. This existing profile checks GC boundary
preservation; the new aliases are exercised by reduced fixtures.

Three reduced independently validated fixtures shrink 169->86,334->267 and
174->122 bytes. Fresh Node instances preserve 48 result observations, mutated
state, six null RuntimeError classes, host call order and three public function
identity checks. Trap messages/locations and non-null typed host arguments are
outside this observation scope. Fixture/observer/tool/output hashes and exact
commands are retained alongside the observations. Original candidate API/CLI
parity and isolated packed JavaScript/strict TypeScript consumers also pass.

Remaining O4/s1 gaps are 1,415,727 GC and 91,972 WASI bytes. Recursive type
canonicalization, broader body transformations/preset composition and general
proposal runtimes remain open. No fast-queue expansion, dead-GC-type-pruner
guard widening, packaging-source edit, license choice or source publication is
part of this checkpoint. Exact integrated-head CI/release gates stay with the
preparation owner and parent.

Fresh SOURCE qualification is separate from the identical-original comparison.
Live FFI/TypeScript generation plus the unchanged five-pass numeric 4/1 build
uses the same native bootstrap hash and no Binaryen. Newly compiled GC shrinks
7,460,987->6,970,113 bytes (8.870s); WASI 6,760,437->6,250,813 (9.632s).
These fresh-source build-report intervals include optimizer invocation, output
validation, reading and export checks; they are distinct from the original-input
CLI wall samples. Local npm prepack renews this build before packing.
Before/after API and CLI observations agree. Local archive
`jtenner-starshine-0.1.2-beta.0.tgz` is 4,669,877 bytes, SHA-256
`7ef0c7da61b4b0b7ee6aa50e083443e2b79f40806f0a889aa12d70ed12ee885a`.
Clean packed JavaScript and strict TypeScript consumers pass all nine package
entrypoints and CLI with checkout/MoonBit reads denied. Generated packaging
files leave no tracked diff. Initial sandbox subprocess failures and successful
approved local reruns are retained separately; no failed run is relabeled green.

A final read-only fetch at 2026-10-10 08:30UTC still pins master to
`9057a5d8a5a5b85859c702c76d0cbe3e9f18ab55`. The preparation owner retains
integration/publication of the prior 62ba4012f checkpoint. This follow-up is a
local branch based exactly there; coordinate the integrated baseline and apply
its separate regression/fix commits through that owner, without concurrent
master pushes. Parent messaging currently returns `thread not found`; the
platform handoff and retained local progress/evidence provide the handoff path.

## Qualified GC compaction memory follow-up

The reviewed `ae6900cb0` checkpoint stays intact. Separate red
`435cb5cfa357977d5cc5713096b94ff0e60db0a2` exposes unnecessary reconstruction of
unmoved typed bodies/subtypes. Repair
`121084db47bcf56aadbad459db1d1b85b056683f` uses sparse changed operand mappings,
a separate dense name ownership map only with name metadata, and skips the
generic type-section rewrite that retained-group rebuilding immediately
discarded. Other remapper callers keep the default full rewrite. Type admission,
proposal preservation, presets and immutable input ownership are unchanged.
Focused physical-sharing/name/immutability controls at widths 1/8/32 pass; all
14,033 default tests, including shifted groups and proposal remappers, pass.
Independent authorized read-only source and resource evidence reviews approve
this scope.

Fresh native SHA-256
`df2c4d5c01d21509718c4c6b65b3659de77285b0c0d456c959c1f36c7795bb9b`
starts each measurement directly from the ORIGINAL GC/WASI hashes above. Three
alternating control/repair GC runs use isolated fresh-child measurements; no
other heavy build/benchmark runs concurrently. These short local samples do
not establish a universal time or memory bound.

| Numeric 4/1 native CLI | Peak RSS KiB samples | Median KiB | Wall seconds samples |
| --- | --- | ---: | --- |
| Previous pre-GC checkpoint | 268,636 / 265,468 / 267,604 | 267,604 | 8.478 / 9.664 / 8.314 |
| Reviewed GC checkpoint, paired controls | 321,536 / 322,052 / 321,712 | 321,712 | 8.882 / 8.685 / 8.581 |
| Storage repair | 318,612 / 318,136 / 324,420 | 318,612 | 8.900 / 8.578 / 8.705 |

The repair median is 3,100KiB lower, but its maximum is higher and ranges
overlap: no reliable upper-peak improvement follows. The remaining median
increase versus the pre-GC checkpoint is 51,008KiB (about 49.8MiB). Paired GC
wall medians 8.685/8.705s provide no meaningful speed claim. One WASI control
278,672KiB/9.020s versus repaired 278,836KiB/9.804s is retained, including its
adverse timing; one pair does not establish speed parity or a regression trend.

Local GDB snapshots visit occupied blocks in the synchronous native default
mimalloc heap. They count rounded allocated slots including headers/capacity,
not cumulative allocations, whole-process memory or phase maxima. Instrumented
RSS/time remain diagnostic and are excluded from the normal peak table. Libc
Massif does not observe this static mimalloc build.

| Phase | GC checkpoint occupied bytes | Repair occupied bytes | Removed bytes |
| --- | ---: | ---: | ---: |
| After pre-canonicalization | 225,218,288 | 221,737,808 | 3,480,480 |
| After DFE, before first constraint analysis | 234,658,576 | 231,292,816 | 3,365,760 |
| Before writing encoded output | 7,178,160 | 7,178,160 | 0 |
| Allocator process shutdown entry | 98,400 | 98,400 | 0 |

Before canonicalization both occupy 148,543,968 bytes. Most of the increase
therefore consists of live overlapping immutable input/transformed IR, not only
freed pages retained by the allocator. Its extra logical data is transient in
this CLI sample; RSS can remain high after those objects are released. This is
not a whole-process leak guarantee or repeated npm-API heap qualification.
Changed concrete indices still require new immutable trees. Scratch maps/arrays
are bounded by flat type count; unchanged regions now share storage. Existing
dictionary collision/repeated-scan behavior is unchanged. Three independently
validated, identity-protected fixtures requiring changed concrete references
at widths 128/512/2048 add 65,040/257,040/1,025,040 occupied bytes across the
pre-canonicalization boundary: `500*width + 1040` for this fixed type shape.
That demonstrates repaired-path growth in these controls, not repair savings
against the old tool or a universal graph-complexity bound.

All original outputs remain byte-identical to the reviewed GC checkpoint:
GC 6,960,836 and WASI 6,240,505 bytes with the same hashes above. Reduced alias/
shifted-group/subtype outputs also byte-match, and fresh Node observers preserve
48 results, mutated state, six RuntimeError classes, host call order and three
function identities. Trap messages/locations and non-null typed host arguments
remain outside the observation scope. Original outputs validate independently.

Strict dedicated DFE renewal uses this fresh native, verified v133, seed 0x5eed,
eight subprocesses, an explicit unchanged generator, independent validation and
15s subprocess limits. It completes all 10,000 cases: 5,000 normalized matches
and 5,000 existing private fixed-point caller residuals, with zero validation/
generator/command failures. The complete input manifest hashes exactly to the
prior run, `40549dec6f139a14ef049220951f04440d13fa407472a6fee310a90c0d248454`;
all 20 retained input/Starshine/Binaryen bundles byte-match. Existing independent
source/reviewer reasoning classifies that bounded private constant/caller family
as six-byte Starshine wins, rather than calling mismatch output safe by size
alone. Runtime/property modes are off; this aggregate does not cover GC aliases.
The initial 39-case default-stop run and a preliminary 10,000-case run with
default validator/timeout/reduction settings remain separate from this stricter
qualification. No final whole-pass audit closure is claimed.

The remaining O4/s1 gaps stay 1,415,727 GC/91,972 WASI bytes. This allocation-only
repair does not rerun Binaryen because output bytes are unchanged; the retained
verified-v133 identical-original comparison remains the target. Prior original-
package and fresh-source FFI/types/packed JS/strict-TS checks remain historical
qualification of `ae6900cb0`, not a new package build of this repair. Per parent
coordination, this follow-up performs no npm action; integrated-head package/CI
qualification stays with the preparation owner. Broader recursive-type/body/
preset work and the scoped effectful OI gap remain open.


## Qualified immutable type-wrapper sharing

Published master was fetched and verified again as
`113af38748a139a08d8c130dccdc3eee868f9516`. Its optimizer/binary/FFI source matches
first reviewed `62ba4012f`. CLI changes move its version constant into a
generated file and update help/version expectations; module version also changes. The preserved first binary is therefore
a code-equivalent optimization baseline, not a build of that published commit.
The held GC/memory checkpoints stay isolated; no memory acceptance is inferred.

Red `c5964160c` and fix `1aed6450c` share immutable rewritten `TypeIdx` values.
Separate red `a78d54874` and fix
`0d68c3f1bc745d2fd288b29e2c6d28f2387a283f` additionally share concrete `HeapType`
wrappers. One private CodeSec-remap cache owns two UInt-keyed maps. Each has at
most one entry per distinct reached final target; keys are never mapped twice.
No graph, expression array or mutable container is shared by these tables.
Default callers, legacy Try scans, recursive-group indices, abstract/shared-
abstract heaps and inline DefType graphs keep their previous paths. RefType
flags/constructor ownership remain unchanged; `ref_null_type` reconstructs its
nullable wrapper, so a RefType cache alone would not share stored RefNull values.

The [bounded regression](../../../src/passes/dfe_gc_index_sharing_wbtest.mbt)
checks nested/body/local convergence, fresh-module isolation, direct targets,
exact/nullable flags, default behavior, excluded forms, immutable inputs and
widths 1/8/32. All 14,035 default wasm-gc tests pass, then final reviewer controls
pass 2/2 with unchanged production source. Source review finds no scoped blocker.
Fresh native SHA-256 is
`3f0aaf851d9a6c1acb93e43d68a5dbd664dd91635daebb42c412182e9af0a395`.

Each short sample runs numeric 4/1 directly on the immutable ORIGINAL GC input,
in a fresh probe process. Three fixed-order serial cohorts run with no concurrent
heavy build/benchmark; they are not randomized or universal performance claims.

| Native CLI | Peak RSS KiB samples | Median KiB | Wall seconds samples | Median seconds |
| --- | --- | ---: | --- | ---: |
| Published-first equivalent | 261,400 / 265,612 / 265,952 | 265,612 | 8.716 / 8.617 / 8.766 | 8.716 |
| Memory repair control | 324,776 / 326,352 / 324,236 | 324,776 | 8.268 / 8.247 / 8.587 | 8.268 |
| Scalar index cache | 305,332 / 305,420 / 305,468 | 305,420 | 8.162 / 8.410 / 8.122 | 8.162 |
| Index plus concrete heap cache | 302,828 / 303,492 / 303,164 | 303,164 | 8.266 / 8.422 / 7.808 | 8.266 |

Final median RSS falls 21,612KiB versus the paired memory control; heap sharing
adds 2,256KiB beyond indices. The remaining increase versus first is 37,552KiB
(about 36.7MiB). This replaces the earlier roughly 50MiB estimate only for this
new local cohort, not an upper-peak guarantee. No speed improvement is established
against memory/index controls. One WASI pair is 279,392KiB/9.228s versus final
279,220KiB/9.124s; earlier adverse index-only WASI observations stay preserved.

The same local occupied-block probe records 231,292,816 / 222,991,344 /
221,249,952 bytes after DFE for repair/index/final, reducing occupied storage by
10,042,864 bytes overall. These are rounded live default-heap slots including
headers/capacity, not cumulative bytes or normal phase maxima. Extra logical
storage is released before writing (final 7,178,192 bytes) and shutdown entry
(98,400). Instrumented final after-write RSS 292,124KiB is higher than the earlier
index probe's 250,656KiB despite identical occupied slots; adverse diagnostics
are retained. No whole-process leak or repeated npm-API heap guarantee follows.

All original outputs remain byte-identical to the reviewed GC checkpoint and
validate independently: GC 6,960,836 / WASI 6,240,505 bytes. Reduced alias/shifted-
group/subtype fixtures preserve 48 values, six RuntimeError classes, three public
function identities, state and host observations. Trap messages/locations and
non-null typed host arguments remain outside scope.

Strict fresh v133/eight-worker renewal completes 10,000 independently validated
owned cases under 15s subprocess limits. Its complete manifest and all 100 Wasms
in 20 retained bundles byte-match prior qualification: 5,000 normalized matches
plus the same independently reviewed six-byte private-caller wins, zero validation/
generator/command failures. Runtime/property modes are off; that lane does not
cover GC aliases. A separate fresh 256-case `campaign-gc-ref-subtypes` Node-v2
oracle matches original/Starshine/Binaryen runtime observations in all cases,
with zero blocked/failing cases and the identical prior manifest. This remains
scoped implementation qualification, not a final whole-pass audit.

The unchanged original output bytes retain verified-v133 gaps of 1,415,727 GC /
91,972 WASI bytes; no new artifact-sized Binaryen run is needed for allocation-
only changes. Numeric 4/1 and the Starshine-only release-build contract remain.
No npm action occurred here: prior ae package/type/packed-consumer evidence is
historical, and fresh integrated-head FFI/types/self-build/packed JS/strict-TS/CI
qualification stays with the prep owner. Memory acceptance, licensing and broader
recursive GC/preset/effectful OI gaps remain open; no push or release action.


## Integration decision and P1 memory blocker

The published native/coverage repair `a2edeed5ca715fb9e67a4d02a460652dd73dfed7`
passes all six master workflows, including 14,033 default tests, actual native
examples and installed-validator checks, and 28,104 uncovered lines against the
unchanged 28,138 baseline. Its exact package CI reproduces the 47-file archive
recorded in [the handoff](../../npm-beta-handoff.md). Earlier failed checkpoints
and historical owner measurements above remain separate evidence.

The complete nineteen-commit reviewed GC chain after `62ba4012f` through
`680fd66c14899375fddc26b7a2979db2abe183d4` is now locally integrated atop a2 at
`dfee891382f9ed188129242fcde4408377d6839f`. Pass/RUME source is identical to the
reviewed owner checkpoint; native compatibility, public FFI/package contracts
and CI retain a2 source. Red-first regressions and original commit provenance
are retained. The separate no-benefit baseline allocation route is excluded.

The user's October 10 decision temporarily accepts the overhead for integration
and requires it to remain a **P1 blocker**. This supersedes the historical
acceptance-pending statements above. It does not establish a peak bound, a leak
or speed guarantee, or close [NPM-GC-MEMORY-P1](../../../agent-todo.md#p1-blocker--reduce-gc-canonicalization-and-wrapper-peak-memory-npm-gc-memory-p1).
Historical three-sample median RSS remains 37,552 KiB above the first equivalent
control despite saving 21,612 KiB against the memory-repair control. The 271,688
additional GC-byte benefit and unchanged original output hashes are preserved.
The active blocker requires controlled matched cohorts, explicit noise budget,
phase/lifetime attribution and repeated supported-Node reclamation checks;
partial reductions and temporary acceptance cannot close it.

Fresh qualification must use the combined source, newly compiled native CLI,
FFI-generated declarations, self-optimized artifacts and exact packed consumers.
Historical owner and a2 package results do not qualify that new head. The five-
pass O4s numeric 4/1 preset, bounded admission, immutable ownership and complete
recursive/public/type identities stay unchanged. All protected exact-head
checks precede normal source publication. License, candidate/provenance and npm
publication decisions remain separate; broader GC/preset and effectful OI gaps
remain open.


## Reviewed declaration grouping integration

The full reviewed GC chain is published at `0ca3cb6e` and all six master
workflows pass, including 14,058 default tests and unchanged coverage baseline
(28,022 uncovered / 225 partial versus 28,138 / 196). Its exact 47-file package
passes isolated Node25/26 JS and strict TypeScript consumers. This supersedes
combined-GC qualification-pending statements above; failed earlier checkpoints
remain recorded.

The five reviewed commits through `36cfe0be` are now locally integrated onto
0ca, retaining regression-first history. Only ReorderLocals source/tests and
[its parity evidence](../binaryen/passes/reorder-locals/parity.md) change.
Equal-frequency grouping is admitted only for a strictly smaller complete
encoded declaration vector; bounded primitive keys preserve actual type fields
and exclude inline graph keys. Public FFI, native compatibility, five-pass
numeric 4/1 preset and build/CI sources remain unchanged. Later unread-tee and
type-ordering experiments are outside this integration.

On identical ORIGINAL inputs the reviewed outputs save 186,626 GC / 11,308 WASI
bytes beyond 0ca. Fresh owner self-build inputs differ: optimized outputs improve
26,442 / 7,910 bytes, while raw GC grows 133,237 bytes and fails the 16 KiB target.
One largest counter body is independently instruction-identical after type-index
normalization; type 23 -> 192 widens immediates by 25,856 bytes. Six growing chunks
were counted, but only the largest has that normalization proof. Withdrawn
inlining/dispatcher hypotheses are not explanations. Final single-pair GC cost
is 8.483 -> 9.886 seconds / 304,404 -> 307,324 KiB; WASI is 9.886 -> 9.735 seconds /
278,836 -> 278,380 KiB. These diagnostic pairs do not close P1. Earlier grouping
cohorts overlapped local work and are not controlled performance signoff.

Owner tests pass 14,067/14,067. Dedicated verified-v133 10k retains structural
exit 1: 7,996 canonical matches and 2,004 classified size wins, with zero
validation/generator/command failures. Twenty retained representatives and
100 Wasms were reviewed/replayed; the 1,984 suppressed cases use generator
contracts/counts, not an exhaustive raw-diff audit. Meaningful exported numeric
and nullable-GC fixtures preserve values, traps, state and distinct public
function objects. Neither this evidence nor the package closes the retained
16 Binaryen discrepancies, DFE residuals or public-identity caveat.

Fresh combined-head qualification is required separately. Investigation of the
prior source-push warning found that workflow-dispatch jobs are excluded from
required-check evaluation, despite matching names/app/head, while the existing
master rule exempts admins. The user explicitly authorizes a normal non-force
fast-forward using that existing exemption for this checkpoint only, followed
by terminal exact-published-head workflows. Retain any server bypass warning;
no protection/credential change, PR, npm publication, license selection or
release action is included. This scoped exception supersedes the blanket
pre-push check sentence above only for this checkpoint.
