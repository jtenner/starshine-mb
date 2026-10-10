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
  and generator, verified Binaryen133, seed `0x5eed`, at most eight subprocesses
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
