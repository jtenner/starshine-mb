---
kind: concept
status: supported
last_reviewed: 2026-10-25
sources:
  - ./index.md
  - ../../../../../src/passes/merge_similar_functions.mbt
  - ../../../../../src/passes/gc_record_copy_outlining.mbt
  - ../../../../../src/passes/gc_record_copy_outlining_wbtest.mbt
  - ../../../../../src/validate/typecheck_iterative_control.mbt
  - ../../../../../src/validate/typecheck_iterative_control_wbtest.mbt
  - ../../../../../src/passes/merge_similar_functions_test.mbt
  - ../../../../../src/passes/merge_similar_functions_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/validate/gen_valid_merge_similar_functions.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ./binaryen-strategy.md
  - ./equivalence-classes-param-derivation-and-thunk-rewrites.md
  - ./profitability-indirection-and-type-barriers.md
  - ./fuzzing.md
---

# Starshine strategy for `merge-similar-functions`

> **Historical comparison baseline — September 10, 2026:** comparisons then used [Binaryen 132](../../release-horizon-and-oracles.md). The October 10 qualification below uses verified Binaryen 133. Recorded v131/v132 sources, commands, artifacts and results retain their historical versions and do not establish v133 signoff.

## Name metadata contract

An accepted ordinary merge retains the name section. Original function
indices and names belong to the retained thunks. Thunks keep their parameter
names; the primary body's local and label names move to the appended helper,
with local indices shifted past added parameters. Non-primary body names are
removed with those bodies. Names in other subsections and for untouched
functions remain unchanged. Changed structured names replace the cached raw
payload before encoding; unchanged names retain the original raw payload.

The [name regressions](../../../../../src/passes/merge_similar_functions_names_review_test.mbt)
replace the defect-confirming expectation from `562c50d9f`. Two of three tests
failed first because accepted merges dropped the complete name section. The
corrected fixtures validate their input declarations and cover direct and
pipeline dispatch, imported and untouched functions, all supported name
subsections, local and label remapping, raw-payload reuse and refresh, encoded
roundtrips, and rejected merges. Two existing call-reference fixtures now use
larger shared bodies because their previous savings depended on deleting
function names; the encoded non-growth rule is unchanged.

The repair changes accepted-rewrite metadata handling in
[`merge_similar_functions.mbt`](../../../../../src/passes/merge_similar_functions.mbt).
A sparse function map is allocated only when local or label name subsections
exist. Mapping visits merged functions and name entries; it adds no body or
class-matching scan. The unchanged complete-module encoded-size guard includes
retained names. Full gates, fuzz and timing remain deferred at the user's
request for the shared host. Broader MSF audit and parity gaps remain open.

## October 13, 2026 encoded-size guard and positive fixtures

The October 11 final encoded-size guard remains strict: the ordinary MSF candidate must not grow the complete encoded module. The weighted instruction-count estimate only admits a candidate for construction; it does not override measured helper/type/index costs. A fourteen-`nop` pair is 61 bytes before outlining and 62 after, even in verified Binaryen 133. The [ordinary-overhead regression](../../../../../src/passes/merge_similar_functions_wbtest.mbt) now proves that estimate passes but the actual candidate is rejected. Existing function/type index-boundary rejection tests remain unchanged.

Five older positive tests used this unprofitable padding, so their expected helper was blocked by the correct guard. Their fixtures now contain four shared global updates instead of padding. Helper/thunk, nested literal, ordinary-call metadata and offset-sensitive metadata assertions remain. The main [positive test](../../../../../src/passes/merge_similar_functions_test.mbt) additionally requires smaller bytes and the exact ordered update instructions, with no `nop`. An exported execution variant shrinks 116 to 103 bytes, is byte-identical to v133, and returns 42/43/42 while the global advances 0/4/8/12. This repairs test setup; no shipping MSF behavior or profitability rule changes.

The full wasm-gc suite passes 14,149/14,149 after these fixture repairs. Interfaces, formatting and README API sync pass. [Qualification evidence](../../../raw/tooling/2026-10-13-six-failure-fixtures.json) retains the size and execution observations.

## October 10, 2026 immutable record-copy cleanup

The direct MSF owner first tries the bounded record-copy slice in
[`gc_record_copy_outlining.mbt`](../../../../../src/passes/gc_record_copy_outlining.mbt),
before the ordinary similarity matcher excludes unsupported GC bodies. It
recognizes at least eight copies of one ordinary, final, unshared immutable
record with 8–512 i32 fields. Each copy reads fields in declaration order from
one local, replaces exactly one field with an i32 literal, and constructs one
fresh record. Arbitrary replacement expressions, mutable or packed fields,
subtyping, descriptors, shared records, exact function/local references and
opaque exception regions remain outside this slice.

A private appended helper receives the source, selected field and replacement.
It reads each immutable field and uses scalar `select` to produce the chosen
field value, then performs one fresh `struct.new`. Every admitted original copy
already reads at least seven source fields. The helper's additional read of the
replaced field therefore preserves nullable traps after the same preceding
host effects. It preserves old aliases, allocation count and fresh identity.
Original type and function indices, imports, exports, global/table references
and `ref.func` targets retain their original identity; only private helpers and
their signatures are appended.

Admission bounds imports, flattened types and function totals to 65,536,
helpers to 32, sites to 4,096 and recursive rewrite depth to 128. An iterative whole-module preflight permits bounded validation depth up to 1,024; deeper functions remain physically shared and are never matched or rewritten. Inputs exceeding the validation ceiling fail closed. One eight-million-unit
budget covers type groups and subtype/supertype vectors, function parameters
and results, struct/array/continuation fields, function bodies, declarations,
local initialization and initializer expressions, including functions excluded
from rewriting and active segment offsets. Raw element function-index vectors
also participate. Vector lengths are charged before traversal or cache setup.
This is a structural admission budget; custom sections and data payload bytes
retain their existing handling and are not bounded by this count.
Compressed local runs are bounded before snapshot conversion and unsigned
parameter/local totals before dense allocation. Unsupported or excessive
resources return the original module.

Both the outline transaction and its combination with ordinary MSF require a
strict reduction in complete encoded module bytes and successful full-module
validation. Failure rolls back the new transaction. This does not change the
existing ordinary MSF candidate's separate validation/profitability contract.
The fast preset adds MSF only at exact numeric
optimize level 4 and shrink level 1, after `reorder-locals` and before
`strip-debug`. Neighboring fast levels and the O4z scheduler retain their
previous queues. Direct requests and other existing MSF routes can also use
this owner; unchanged queues do not imply unchanged MSF behavior.

This is a bounded cleanup slice, not a complete GC or MSF audit. Production
qualification below is tied to actual frozen source and executables; manually
outlined projections establish the causal shape only. Wider pass audit gaps
remain open.

### Compiled same-original qualification (October 10, 2026)

The clean selective-preset source at `d5097be3e` compiled to native CLI SHA
`420c4de9177cae6b6f56f56d4518f7bfb530e2eb3f710e53a309ab834e1b462e`.
Three alternating fresh-process repetitions on each immutable original input
produced identical output hashes and passed independent wasm-tools validation:

| Input | Previous five-pass bytes | Selective six-pass bytes | Saving |
| --- | ---: | ---: | ---: |
| Original GC, 7,452,107 bytes | 6,539,241 | 5,361,362 | 1,177,879 |
| Original WASI, 6,748,730 bytes | 5,993,028 | 5,775,198 | 217,830 |

The GC output SHA is
`25731db65a7f1aefd6460c10b3e0dcbad06b3429be862e2208ea4209484d0fa5`;
WASI is `328f45208d8ce374e5904f381664b1889effb0ca5ada8474e2e8ea10cea31f59`.
The same-original Binaryen 133 O4/s1 GC result is 5,545,109 bytes, 183,747
larger. The earlier ordinary-MSF checkpoint was 6,463,197 bytes; the final
combined result saves another 1,101,835 bytes beyond that checkpoint. This
comparison does not isolate every interaction as a purely additive owner gain.
The earlier 1,073,894-byte hand-outlined projection remains causal shape evidence.
Its WAT roundtrip difference comprised 71 custom-section bytes and three bytes
from an omitted empty table; it was not entirely custom metadata.

These samples overlapped authorized package/compiler work. Rough native
medians were GC 13.131 to 11.390 seconds, 304,004 to 302,008 KiB peak RSS;
WASI 15.509 to 12.787 seconds, 278,776 to 278,600 KiB. Individual samples varied;
these are developer-process diagnostics, not universal speed or output-runtime
memory claims. Existing P1 compiler-memory tracking remains open.

Actual compiled direct and selective-preset reduced fixtures passed default
Node 25 and 26 expected-value observers: all record fields, unchanged old
aliases, fresh identity, selected-null traps, fallback identity, ordered host
calls/state, throwing callbacks, callback reentry, and public function/table/
global identity. A separate unchanged 567-depth function executed alongside
the new copies. The 403-field, 64-arm callback-free batch used seven warm
20,000-iteration samples: medians were Node 25 11.806 ms original to
3.855 ms direct / 3.563 ms preset, and Node 26 13.005 to 4.048 / 3.900 ms.
The tiny 12-field batch slowed: Node 25 0.286 to 0.314 / 0.454 ms and Node 26
0.180 to 0.230 / 0.298 ms. These microbenchmarks do not establish whole-API
throughput. The separate 403-arm fixture exceeds rewrite depth 128 and stays
outside the new owner; its runtime is compatibility evidence only.

The original-input optimized WASI artifact also executed CLI help and numeric
4/1 through the repository MoonBit host adapter. Help stdout matched the
original; expected numeric values, division trap, ordered callbacks, throwing
callback and state matched under default Node 25/26. The artifact retains
its original compiled program; new-source API behavior is separately qualified
by package consumers.

Local supporting evidence is retained under task9 `gc-cleanup-evidence`:
`original-six-cohort.json`, `selective-six-source-fingerprint.json`,
`fresh-reduced-source-qualification.json`, `final-reduced-runtime-exits.json`,
the corresponding default-Node observer JSON files, and
`wasi-help-final-comparison.json` / `wasi-final-effects-node25.json` / `node26`.
Generated comparisons are recorded in [the fuzzing page](./fuzzing.md).
Source/full-package gates remain separately recorded, with original-input and
new-source artifact results kept distinct.

The shipping WasmGC release outlining controls passed 16/16, including full
candidate validation at depth 1,024, rejection at 1,025, unchanged 567-depth
body identity, invalid deep rollback, compressed-local and structural budget
boundaries. Independent native debug and release validator controls passed
11/11 each. The seed-derived custom observer executed every selected arm for
52 distinct native-generator input modules, with all original, direct MSF,
selective preset and Binaryen variants on default Node 25/26: 208 variants,
153,704 export calls, 624 traps and 140,216 field checks per runtime. A separate
linear WAT input census found exactly 531 copy sites, 8–12 in every input,
plus one make constructor per input; field-load totals matched the generator
contract. The generic runtime host is a stub, so these independent callbacks
and reentry checks supplement its recorded import trace.

## September 25, 2026 call-type shape-collision measurement

The shape hash now includes the cached target type index for direct and return calls, matching the existing equivalence rule that permits different call targets only when those type indices match. Distinct target types no longer enter one pairwise class-comparison bucket. In the [native white-box benchmark](../../../../../src/passes/merge_similar_functions_shape_collision_perf_wbtest.mbt), 128 same-shaped wrappers calling imports with distinct type IDs improved from `191.41` to `1.94 µs` (98.7×), and 256 improved from `767.40` to `3.91 µs` (196.3×). A same-type-target regression and 24 existing MergeSimilar tests pass. These are class-collection timings; full-pass impact remains unmeasured.

## Current status

Starshine now implements `merge-similar-functions` as an active whole-module pass.

- registry category: `ModulePass`
- direct request: `--merge-similar-functions`
- owner: [`src/passes/merge_similar_functions.mbt`](../../../../../src/passes/merge_similar_functions.mbt)
- dispatcher: [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- O4z integration: the existing validated `optimized-similar-functions` portfolio candidate runs the legacy specialized outlines and then generic MSF
- locked O4z scheduler: unchanged; MSF is integrated through candidate selection rather than inserting another top-level slot

## Implemented algorithm

The local pass follows the Binaryen 131 contract:

1. hash defined functions while ignoring scalar/vector literal payloads and direct call targets
2. split hash collisions with an exact recursive structural comparison
3. require compatible resolved function signatures and local declaration layouts
4. derive literal and same-type direct-callee difference vectors in reverse DFS order
5. reuse one synthetic parameter for repeated identical vectors
6. enforce the 255-parameter limit and Binaryen's weighted profitability rule
7. append a shared helper type and function
8. shift original non-parameter local indices after synthetic parameters
9. replace originals with tail-call thunks when target metadata permits them,
   otherwise use ordinary calls
10. lower differing direct callees through `ref.func` and `call_ref` / `return_call_ref`
11. append declarative function references and validate the complete candidate transactionally

The pass also preserves Binaryen-observable details found during fuzzing:

- profitable exact duplicates are accepted by the direct pass
- canonical-equivalent simple function type indices may share a class
- local declaration types remain part of the hash prefilter
- equivalence classes are emitted in primary-function order
- function annotations make the pass fail closed rather than rewriting stale branch metadata

## Safety boundaries

- imported functions are never candidates because only code-section definitions are scanned
- differing direct callees must use the same exact function type index before function-reference parameterization
- accessed local indices must have compatible types across the class
- helper and thunk insertion preserves every original function index, export, start reference, and call target
- a canonical `target_features` entry that disallows `tail-call` keeps thunks
  on ordinary `call`; malformed named payloads also fail closed to ordinary
  calls because the pass preserves the opaque metadata unchanged
- a candidate is discarded unless an append-only proof preserves every untouched section and existing type/function/element prefix, rebuilds the complete validation environment, and validates every changed or appended function
- name metadata is stripped after a successful rewrite because helper insertion and local clearing invalidate local/debug names

## O4z artifact result

On the same 14,943,550-byte debug CLI used for the prior O4z comparison:

- previous Starshine O4z: 5,261,119 bytes
- Starshine O4z with generic MSF portfolio integration: **5,113,549 bytes**
- pinned Binaryen 131 O4z: 5,144,062 bytes
- Starshine now emits **30,513 fewer bytes** than Binaryen on this artifact
- the new Starshine artifact validates with `wasm-tools --features all` and passes `bun validate self-opt-smoke`

After the retained performance rewrite, direct command medians are 0.945 seconds for Starshine and 0.603 seconds for Binaryen 131 with `-s 2`, a 1.567x ratio. Starshine falls 0.282 seconds / 22.96% from its 1.226-second pre-rewrite baseline while preserving exact output bytes. A final trace attributes 68.333ms to fused analysis, 5.032ms to class splitting, 6.176ms to planning/rewrite, and 44.482ms to append-only candidate validation; the previous full candidate scan took 333.195ms.

A seven-pair full O4z sample is host-noisy but near wall parity: independent medians are 25.508s for Starshine and 24.984s for Binaryen (`1.021x`), while the median paired difference is 0.010s in Starshine's favor. Starshine uses 33.402s median user CPU versus Binaryen's 194.593s and keeps the 30,513-byte output advantage.

## Fuzz ownership

The dedicated aggregate is `merge-similar-functions-all`. It includes:

- literals
- repeated diff vectors
- exact duplicates
- duplicate simple type indices
- local-index shifting
- nested control
- direct call targets
- tail-call targets

See [`./fuzzing.md`](./fuzzing.md) for commands and results.

### Source qualification gates

At frozen executable source `d5097be3e`, plain `moon test` passed 14,107/14,107
and explicit WasmGC defaults passed 14,104/14,104. Shipping release outlining
controls passed 16/16, including dedicated skipped resource/depth boundaries.
The integrated owner also passed full WasmGC validation (14,104 tests and all
14 CI fuzz suites). Its executable logic matches this checkpoint; subsequent
source changes were provenance comments. Package build/consumer and compressed
archive results belong to the separately retained package evidence.

At this documentation checkpoint, `CI=true bun validate coverage --top 15
--baseline .github/coverage-baseline.txt` was still collecting instrumented
test results against the unchanged baseline of 28,138 uncovered lines in
196 files. No coverage pass or delta is inferred here; its eventual normal
exit and report are retained in `record-copy-final-coverage.log` under the
local evidence directory.

### Deep control validation dependency

The fixed GC artifact contains unrelated Block/Loop/If bodies up to 567 control
levels. Full candidate validation previously overflowed the shipping WasmGC
expression checker on an equivalent valid body; release mode reproduced this
failure. Expression validation now suspends these three control kinds in private
boxed continuation frames and invokes the existing entry and finish rules.
Exception controls retain their existing dispatch. Each expression retains its
own initialization owner, and if validation checks both instruction sequences
before either arm's end-stack normalization, preserving error precedence.

Ordinary diagnostics retain their existing text. On errors, a control subtree
exceeding 32 levels or 256 instructions uses an explicit bounded control
rendering marker while retaining the instruction index, block type, underlying
reason and stack. This avoids recursively formatting a deep invalid body. This
change validates the body fully; it only bounds diagnostic rendering.

A short ordinary validation process sample retained both improvements and
regressions. Flat 10,000-instruction fixture medians were 6.005 to 5.085 ms
with peak RSS 13,854 to 13,924 KiB; a shallow 12-arm fixture was 2.493 to
2.764 ms and 13,620 to 13,880 KiB. These include process startup, codec and
I/O, and are rough concurrent diagnostics rather than isolated frame-allocation
or universal consumer performance measurements. The continuation repair
therefore does not carry a blanket zero-overhead claim.
