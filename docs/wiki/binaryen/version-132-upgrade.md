---
kind: decision
status: working
last_reviewed: 2026-09-16
sources:
  - ../raw/binaryen/2026-09-10-v131-v132-release-inventory.json
  - https://github.com/WebAssembly/binaryen/compare/version_131...version_132
  - https://github.com/WebAssembly/binaryen/releases/tag/version_132
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/passes/ConstraintAnalysis.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/passes/DeadArgumentElimination2.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/passes/MakeSharedObjects.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/wasm/wasm-binary.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/constraint-analysis.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/constraint-analysis-loops.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-control-flow.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/basic/compact-imports.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/basic/relaxed-atomics.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/waitqueue.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/array-multibyte.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/make-shared-objects.wast
related:
  - release-horizon-and-oracles.md
  - passes/tracker.md
  - ../../../agent-todo.md
---

# Binaryen 132 Upgrade

Remote integration on September 11 advances local master by 51 commits from
`a1d2f889528ee0d17724e91bea92e133d8dd14b1` to
`5f74d54b1ecae465308f985d515f0bf9647d7610`. The uncommitted upgrade is restored
above that baseline, retaining incoming local-lifetime, access-ordinal,
exact-reference, Precompute and definite-initialization fixes.

The final source passes **11,228** default wasm-gc tests. Renew25 passes the full CI fuzz gate
(including **86,820** binary roundtrips), component checks, and **256** Bun library
tests. Native `766c3e35…` passes **52** explicit Node lifetime comparisons and all
**304** selected upstream module/world structural checks. Across renew21–25,
**32** dedicated 10,000-case campaigns complete without validation, generator,
command or property failures. Three ordinary shared-pass renewals are structural
checks; their runtime coverage is separate. Proposal runtime exclusions and
unresolved size differences remain explicit.

The renew23 optimizing compiler exposes a new startup failure even though its
output validates. Body bisection isolates SimplifyLocals and two reduced cases:
a later parameter tee moves before an earlier conditional call, and a conditional
call moves past an exported-global write. Red-first regressions cover lowering,
the public pass pipeline, command dispatch and the effects prefilter. The local
repairs distinguish child access order from newly allocated wrapper IDs and keep
pending calls/control/traps visible to the exact effect check. GenValid's
`dae2-locals` leaf now includes both observable shapes and is also selected by
`simplify-locals-all`. Renew24 passes 47 independent small execution checks but compiler startup then
fails at absolute function 34. Its reduced allocation/header fixture returns `8`
instead of `272`: a second SimplifyLocals cycle sinks the definition across an
older read carried in a later root. Renew25 indexes source reads per main cycle
and retains that definition. It also bounds inferred lowering dependencies by
their existing consumer, preserving newly inserted writes and calls. All 113
lowering and 361 SimplifyLocals tests pass. Native `766c3e35…` then passes startup
for DAE2, DAE2-optimizing and constraint-optimized compilers, with **20/20**
functional invocations producing the same validated output per fixture. It also
passes **52** independent Node cases and **304** upstream structural checks.
The full CI gate passes **11,222/11,222** tests and **86,820** binary roundtrips.
Three new 10,000-case local-lifetime campaigns (DAE2, DAE2-optimizing and
SimplifyLocals) each pass all execution, validation, determinism and codec checks.
These generated execution checks use Bun/JSC; the 52-case lane explicitly uses
Node. Output-shape review found an unused SimplifyLocals lowering scratch local;
a new regression reproduces three declarations where the source and Binaryen
have two. Removing unused generated declarations preserves source locals and
instruction evaluation. DAE2 also reuses an existing identical function type
after private parameter pruning, and full SimplifyLocals folds a lowered
`local.set`/`nop*`/`local.get` capture to `local.tee` without moving its producer.
The final focused DAE2, SimplifyLocals and command suites pass 41, 363 and 14
tests respectively; the full default wasm-gc suite passes 11,228/11,228. A final
native rebuild, renewed 10,000-case comparisons and isolated performance remain pending;
earlier failing artifacts remain recorded as failures.

The combined-source regressions cover pending throwing calls and older local
reads, tuple producers evaluated once, default-local initialization and
unshared atomic RMW construction order. The aggregate selector now varies body
shapes independently of profile selection. New cases cover typed declarative
function elements and nested descriptor targets with observable writes.
Descriptor refinement removes dead explicit values after terminators before
validating a non-null bottom block result. Balanced stack captures are compacted
without moving evaluations, including after DAE2's optimizing cleanup.
The continuation cleanup removes non-null unused allocations while retaining
operand effects, nullable traps and consuming binds. Its 10,000-case continuation
Vacuum lane canonically matches Binaryen throughout; runtime is unsupported.
Tuple forwarding cleanup removes local-only wrappers and now clears stale label
names only from changed functions. Both named overlap variants enter GenValid.
Instruction optimization also folds a zero comparison through a constant `i64`
tee while preserving the write and operand effects. These are compatibility
repairs to existing behavior; v132's upstream OptimizeInstructions.cpp still
adds only comments. Continuation core/binary/HOT support does not imply the older WAST
continuation text grammar is implemented.

The [validation ledger](../raw/binaryen/2026-09-10-v132-validation.json) retains
exact hashes, commands, failures, runtime-host corrections and compiler resource
probes. Earlier checkpoint counts remain historical evidence, and concurrent
resource probes do not establish isolated speed signoff.

Binaryen **132** is the comparison target from September 10, 2026. The official
release was published August 12 at `79dfe6b412a3c22bfdb190ed6a4d79adf734db5d`;
the previous baseline is v131 at `1f903c14babf829745b421b92ff0f286e93e4209`.
The [captured inventory](../raw/binaryen/2026-09-10-v131-v132-release-inventory.json)
was reproduced from those exact tags: **59 commits, 220 changed files, 25 pass
files, and 83 changed test paths**. `main` is not the release oracle.

The user-supplied September 10 source review inspected Starshine
`7a58886305102c0575949cefc790a3678c0be292`. Implementation started at
`a1d2f8895` after three subsequent commits. Historical parity and timing results
remain evidence for their recorded versions; the baseline change does not turn
v131 signoff into v132 signoff. Named missing passes remain missing until a real
implementation and dispatcher coverage land.

## Implemented compatibility changes

The comparison harness, CI and performance sweeps target the exact v132 oracle.
An explicit version override remains available for historical replay. DAE2 and
constraint analysis are real registered implementations; ordinary DAE remains
separate. Presets have not changed.

| Area | Implemented behavior | Current limits |
| --- | --- | --- |
| Atomic representation | Distinct acquire-release/relaxed features; three orders throughout core, WAST, binary, HOT and generated component APIs; all 66 linear atomics, GC reads/stores/RMWs, matched order pairs and fences. | Independent engines do not execute all released draft forms. |
| Atomic optimization | Directional load-before-store rule across heap classes; shared/SeqCst Precompute guards; fresh-allocation store folding; unshared AcqRel struct-store relaxation; shared RMW and identity-order guards. | Atomic OI renewal has 10,000 canonical matches; proposal runtime exclusions remain explicit. |
| Compact imports | Both binary and grouped text forms expand into ordered logical imports; opt-in `encode_module(..., compact_imports=true)` groups compatible consecutive runs. | Existing import AST lacks source spans and original grouping metadata. |
| Descriptors | Both branch polarities, exact annotations, bottom-result and local refinement; borrowed multivalue payloads retain single evaluation. | Nine expanded descriptor lanes pass 10,000 structural checks each; output-size gaps and unavailable independent runtime remain explicit. |
| DAE2 | One parameter/result usage graph, whole result tuples, cycles, referenced type families, open-world restrictions and post-tag #8994. | The 730 generated legacy multi-handler cases remain larger; continuation and tuple cleanup losses are repaired. |
| Constraints | Integer/reference facts, width-correct bit-pattern ranges, copy relations, joins, increments, loop arguments, widening, bounded work and converged rewrites. | Floating-point proofs remain disabled; corpus performance and residual opportunities require signoff. |
| Proposal model | Waitqueue references/new/notify/explicit waits; multibyte array offsets/alignment through parsing, validation, HOT and encoding; continuation-associated signatures and control. | Runtime exclusions remain explicit. Optional tool passes are separate. |
| Feature policy | Core and CLI controls for acquire-release atomics, relaxed atomics, shared-everything, multibyte and relaxed SIMD; inference includes declarations, initializers and handlers. | This does not claim complete support for every older proposal. |

## Released transform and shape catalog

This is the shape-level view of the v131-to-v132 delta. It groups the released
source and test changes by the input pattern they recognize or represent. The
examples describe semantic forms; Binaryen may use different temporary locals,
type names or canonical text after rewriting. Post-tag fixes are called out
where they change the safety boundary, but are not presented as v132 release
behavior.

### Constraint analysis: facts that collapse predicates

`constraint-analysis` walks the function CFG, records local writes and branch
conditions, joins facts at reachable merges, and rewrites a predicate only when
the converged facts prove its result. The v132 additions cover these shapes:

| Input shape | Fact or rewrite | Required boundary |
| --- | --- | --- |
| `x = C; eq(x, C)` or `ne(x, D)` in the same block | Replace the Boolean result with `1` or `0`, while retaining the predicate operands and their effects. | Only predicate-relevant locals are tracked; an unknown local remains unknown. |
| `x = y` followed by a predicate on `x` | Follow the copy back to `y` and track both locals. | A later write invalidates facts that depended on the old value. |
| A predicate in an `if`, conditional `br`, or null/non-null `br_on` arm | Send the condition or its negation to the selected successor, then use it inside that block. | The released pass handles two-way CFG edges and `br_on_null` / `br_on_non_null`; switch and cast branches remain outside this solver slice. |
| Two paths assign the same constant before a merge | Join the equal facts and fold the post-merge predicate. | Different path values produce a range or unknown fact rather than a false equality proof; unreachable predecessors contribute nothing. |
| `x == C || x > C` and `x <= C && x < C` | Fuse redundant relational alternatives into a stronger normalized bound, then use it in later predicates. | Signedness, operand width and comparison negation are preserved independently. |
| Signed or unsigned inequality against a constant | Add the corresponding lower/upper bound, including the v132 missing unsigned cases. | Bit-pattern ranges are width-correct; i32 and i64 constants do not share a domain. |
| `x = y + K` on a loop backedge followed by a bound check | Transfer the increment and widen the loop-carried range so bounded loops converge without enumerating iterations. | Modular overflow is preserved; unbounded or almost-infinite loops must terminate analysis without inventing a proof. |
| An unreachable block after a proved contradiction | Drop its remaining children and replace the region with `unreachable`, then refinalize. | Effects and traps in reachable operands stay in evaluation order; unfinished analysis cannot certify a rewrite. |

The solver also sorts and removes redundant constraints internally, limits
repeated increment work, and avoids copying state when an edge has no useful
branch condition. Those changes improve convergence and memory cost; they are
not additional IR rewrite families. Floating-point predicates remain disabled
because NaNs and signed zero make the integer-style logical rules unsound.
The [constraint shape page](passes/constraint-analysis/wat-shapes.md) contains
small WAT examples and the local test map.

### DAE2: unused values, result tuples, and dependency graphs

The v132 DAE2 result extension treats a function's result tuple as one liveness
unit and solves it together with parameters, direct calls, indirect function
type families and forwarding cycles:

| Input shape | Released result | Required boundary |
| --- | --- | --- |
| Private `(result i32)` whose callers drop the call | Remove the result from the function and call type; turn the producer expression into a dropped value when it has effects. | A trapping or effectful producer is retained in its original position. |
| Private `(result i32 i64)` whose whole tuple is unused | Remove the whole tuple and retain its evaluation through `tuple.drop` or equivalent dropped children. | A tuple with any observed component stays intact; per-slot result pruning is not a v132 feature. |
| A result used only as an argument to an unused parameter | Forward “used” backward through the graph; if no observable consumer reaches it, remove both value edges. | Calls, nontermination, traps and argument evaluation remain observable. |
| Forwarding functions in a cycle | Keep the cycle's value locations unused unless an observable consumer reaches the cycle. | The solver must converge without assuming recursion is dead. |
| Result-producing `if`, block, loop, return or tail-call | Remove the value wrapper while preserving conditional calls, writes, traps and control flow. | The control structure cannot be flattened merely because its result is dropped. |
| Direct and indirect calls, referenced functions, imports/exports and intrinsics | Rewrite only the eligible signatures and all affected call/return sites. | Open-world references and effect-free-call intrinsics pin signatures; stack-switching continuation types are collected and protected. |

The upstream result fixtures are split across [`dae2-results.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results.wast), [`dae2-results-control-flow.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-control-flow.wast), [`dae2-results-cycles.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-cycles.wast), [`dae2-results-indirect.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-indirect.wast), [`dae2-results-open-world.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-open-world.wast), [`dae2-results-intrinsics.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-intrinsics.wast), [`dae2-results-returns.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-returns.wast), and [`dae2-results-cont.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-cont.wast). The post-tag #8994 correction additionally preserves caller results for an unchangeable open-world indirect tail callee.

### Atomic orders: ordering-sensitive eligibility

v132 introduces a distinct `relaxed-atomics` feature and a `Relaxed` order
alongside `SeqCst` and `AcqRel`. The represented shapes include ordered linear
loads, stores, RMWs, cmpxchg operations and fences, plus order-bearing shared
GC reads/stores and matching RMW pairs. Text roundtrips preserve forms such as:

```wat
(atomic.fence relaxed)
(i32.atomic.store relaxed (i32.const 1) (i32.const 1))
(drop (i32.atomic.load relaxed (i32.const 1)))
```

The v132 effect rule is directional: an earlier Relaxed-or-stronger atomic load
cannot be moved past a later Relaxed-or-stronger atomic store, even when their
heap classes are disjoint. `SeqCst` and shared reads remain barriers for
Precompute. Eligible immutable, unshared Relaxed/AcqRel GC reads may fold; the
fold does not apply to mutable fields, shared objects or SeqCst reads. An
atomic fence is an ordering barrier with no stack result, never removable
incidental code. These rules describe optimization eligibility, not a claim of
concurrent runtime signoff.

### Descriptors: branch polarity, nullability, and borrowed payloads

The descriptor family uses both `br_on_cast_desc_eq` and
`br_on_cast_desc_eq_fail` forms:

```wat
(br_on_cast_desc_eq $done (ref null $source) (ref $target)
  (local.get $value) (local.get $descriptor))
```

The failure form reverses the branch condition. Local-subtyping and cleanup
must refine the value on the selected edge, retain a non-null result when the
destination is non-null, and preserve the descriptor operand's single
evaluation when it is borrowed from a multivalue stack. A reachable descriptor
branch remains a branch even when the surrounding block result is bottom;
explicit values after a terminator can be removed only after reachability is
known. Null descriptor inputs and unreachable branch operands retain their
traps. The relevant released fixtures are
[`local-subtyping-desc.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/local-subtyping-desc.wast),
[`unreachable-br-on-cast-desc.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/basic/unreachable-br-on-cast-desc.wast),
[`vacuum-desc.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/vacuum-desc.wast),
[`monomorphize-desc.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/monomorphize-desc.wast), and
[`ref-cast-desc.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/ref-cast-desc.wast).

### Compact imports: grouped syntax expands to ordinary imports

The two released compact forms are serialization shapes rather than optimizer
rewrites. The text form can group mixed per-item descriptions:

```wat
(import "env"
  (item $f "f" (func (param i32)))
  (item $g "g" (global i32)))
```

It can also share one function or global description across several names:

```wat
(import "math"
  (item $sin "sin") (item $cos "cos")
  (func (param f64) (result f64)))
```

The reader expands either group into ordered logical imports, preserving names,
kind, exact-function annotations and index spaces. The opt-in writer groups
only consecutive compatible runs; a module-name, kind or type boundary ends a
run, and ordinary encoding remains the default. The AST does not preserve the
original group spelling or per-item source spans.

### Waitqueues and multibyte array memory arguments

The v132 proposal intake adds represented shapes that every layer must carry
without changing their effects:

```wat
(waitqueue.new)
(waitqueue.notify (global.get $wq) (i32.const 1))
(struct.wait $t 0 (global.get $object) (global.get $wq)
  (i32.const 0) (i64.const 0))

(i32.store (type $bytes) offset=12 align=2
  (local.get $array) (i32.const 0) (i32.const 1337))
(drop (i32.load8_u (type $bytes) offset=4
  (local.get $array) (i32.const 0)))
```

Waitqueue references distinguish shared `waitqueue` and `nowaitqueue`, preserve
nullable null values, and keep object/index/timeout evaluation order. A null or
unreachable wait operand still produces the specified trap or unreachable
shape. Multibyte array loads and stores carry an array type, element index,
byte offset, alignment, load signedness/width or store width, and value where
applicable. Validation rejects bad memory indices and inconsistent alignment;
binary and text roundtrips retain the memarg. These are represented proposal
forms, not new optimizer rewrites, and their runtime/concurrency support remains
separate from structural validation.

### MakeSharedObjects: unshared references become shared handles

`make-shared-objects` is a new explicit upstream pass. It rewrites reference
types to shared forms, maps `ref.func` values to stable shared `i31` handles,
synthesizes a function table and element segment, and lowers `call_ref` to a
table lookup plus `call_indirect`. Nullable casts/tests use a scratch local so
the reference is evaluated once; non-null casts retain their trap behavior.
Function signatures remain unshared while object and reference containers are
made shared, and recursive type groups are rewritten together. This pass is
still upstream-only in Starshine; its catalog entry is included to keep the
released v132 shape inventory complete.

### Changes that guard or expose shapes without adding a rewrite

Several v132 commits change acceptance, metadata or tools rather than adding a
new transform pattern:

- `wasm-ctor-eval` refuses to flatten data segments with huge memory64 offsets,
  preserving the instantiation/trap boundary instead of allocating an
  impractical constant buffer.
- The indirect-call effect type-update fix and deterministic type-name mapping
  repair analysis and metadata; they do not introduce a new user-visible
  peephole.
- Relaxed SIMD changes validation and fuzzer handling. It is separate from
  relaxed atomics and does not add a new OptimizeInstructions rule.
- JS API changes expose `BinaryenStringConst` and merge the feature-taking
  binary reader entry point. Ordinary DAE changes statistics only.
- The released `OptimizeInstructions.cpp` diff contains comments only, so no
  v132 OI peephole should be attributed to this upgrade.

The complete commit-to-file mapping remains in the [exact release ledger](#exact-release-commit-ledger), while the [83-path intake manifest](../raw/binaryen/2026-09-10-v132-regression-intake.json) records which upstream fixtures were adapted, structurally checked, or intentionally left outside execution.

Shared HOT corrections preserve evaluation of pending calls, old local reads,
multivalue producers and nested conditional assignments. CFG backedges enter loop
bodies without reevaluating initial arguments; constraint facts distinguish nested
carried-parameter scopes. Reduced compiler-derived regressions live in the
[DAE2 tests](../../../src/passes/dead_argument_elimination2_wbtest.mbt) and
[constraint tests](../../../src/passes/constraint_analysis_wbtest.mbt). Earlier
validating-but-misbehaving compiler artifacts are superseded by the functional
renewals below, not retained as successful execution evidence.

Constraint block evaluation reuses a sparse expression cache and stores only
predicate-relevant locals, including transitive copy sources. Adjacent single-use
scratch captures are removed without moving evaluations. Nonreturning control
results are recomputed before lowering. Descriptor refinement preserves source and
descriptor operand order, retains reachable descriptor branches, and never
reevaluates the label payload borrowed from the surrounding stack. DAE2 avoids exception-reference locals
when no legacy rethrow needs exception identity; nested rethrows retain captures.

Compact text imports preserve per-item names, logical indices and forward type
references in [`binaryen132_imports_test.mbt`](../../../src/wast/binaryen132_imports_test.mbt).
Upstream #8925 needs a per-item parser-position table because it reparses expanded
import descriptions. Starshine's [`parse_imports`](../../../src/wast/parser.mbt)
creates individual AST entries and [`lower_to_lib`](../../../src/wast/lower_to_lib.mbt)
resolves them after collecting types; it does not reparse declaration locations.
The AST's lack of public source spans is an older tooling boundary, separate from
this release's item/name/index mapping behavior.

### Shared analysis audit

Starshine does not keep Binaryen's indirect-signature effect-summary map.
[`HotAnalysisCache`](../../../src/ir/analysis_cache.mbt) stores function-owned
masks, [`effects.mbt`](../../../src/ir/effects.mbt) classifies calls conservatively,
and the dispatcher rebuilds `HotModuleContext` from the current module. No stale
many-to-one summary merge was reproduced. A future `global-effects` implementation
still requires U02's module invalidation, conservative unknown merges and retained
unchanged entries; function revisions alone are insufficient.

DAE2 remaps retained local/type/field names and discards stale label metadata after
control rewrites. RUME and duplicate-function elimination now remap every aggregate
atomic type annotation. Broader type merging remains an older boundary.
`pass_compute_label_used` records cast branches even when they are untaken.

**Registry correction:** released Binaryen 132 registers `dae2`, not
`dae2-optimizing`. Starshine's explicit optimizing variant runs DAE2 followed by
`simplify-locals` and `vacuum`; the oracle adapter runs the same sequence.

The `node-v2` option names the observation adapter. When invoked through Bun,
its `node:worker_threads` calls execute Wasm in **[Bun/JavaScriptCore](https://bun.com/docs/runtime)**, not a
separate Node process. Earlier reports used Bun's compatibility `process.version`
and incorrectly labeled that host `node:v26.3.0`; those observations establish
Bun results only. New reports, semantic cache keys and resume manifests record
the actual host. The independent lifetime script explicitly spawns Node v26.8.1
and separately passes 35 comparisons. See the [runtime host correction](../raw/binaryen/2026-09-10-v132-validation.json).

## Scope and execution contracts

| Slice | Work and dependencies | Exit evidence |
| --- | --- | --- |
| U01 | Pin tags and executable; capture changed tests and current registry/feature availability. | Every selected fixture records pass, explicitly unsupported, or failure; no silent skips. |
| U02 | Shared indirect effects and deterministic type metadata remapping (#8874/#8956). | Unknown remains unknown, many-to-one summaries merge conservatively, unchanged entries survive, module mutations invalidate summaries; chains/cycles/insertion order are deterministic. |
| U03 | Descriptor input/result/branch typing and recomputation (#8935/#8948/#8970/#8975). | Local-subtyping, vacuum, optimize-casts and cleanup preserve validity for unreachable/null/bottom descriptors and untaken branches. |
| U04 | Decode compact import groups into ordered logical imports; opt-in consecutive-run writing. | Both group forms, all import kinds, empty field names, mixed runs, original index order, bounded malformed-input handling and source mapping. |
| U05 | Distinct acquire-release/relaxed feature names; Relaxed order across model, binary/text, validation, HOT, directional effects and Precompute. | Exact order bytes 0/1/2 and RMW pairs 0x00/0x11/0x22; both movement directions; traps/fences/alias classes; shared and SeqCst reads retain required effects. |
| U06 | New DAE2 parameter/result dependency fixed point, then signature/call/return mutation; depends on shared correctness. | Whole result tuples, dependency cycles, tail calls, open world, referenced signatures, intrinsics and continuations; include post-tag #8994. Never alias ordinary DAE. |
| U07 | Opt-in constraint analysis over derived HOT CFG/local/SSA facts. | Typed integer/reference reasoning, signed/unsigned bit patterns, bounded joins/widening, overflow, tees and convergence; no floating-point proofs initially. |
| U08 | Waitqueue references/operations and multibyte array memory arguments. | Parse/validate/lift/verify/pass/verify/lower/validate/encode agree; allocation identity, null traps, synchronization and blocking remain observable. |
| U09 | Benchmark new passes and measured cleanup sequences; update presets only with evidence. | Fixed-corpus optimized size, pass/command time, allocations/peak memory and runtime; classify every regression. |
| U10 | Optional MakeSharedObjects, SafeHeap and DeAlign tools. | Separate feature-scoped signoff. No wasm2c optimizer requirement. |

Ordinary compiler-generated inputs follow U01 → U02/U03 → U04 → U06 → U07 → U09.
U05/U08 are required before claiming their proposal slices, and their outstanding
work prevents a claim of complete v132 feature parity. Existing older boundaries
remain separate debt. The active execution state lives in [agent-todo.md](../../../agent-todo.md).

Only two TODO comments changed `OptimizeInstructions.cpp`; it gains no v132
peephole rule. Normal DAE changed statistics, while DAE2 adds the new result
solver. Do not reopen every unchanged pass algorithm. Shared-effect and type
regressions still apply to consumers whose upstream filenames did not change.

An earlier relaxed-or-stronger atomic load cannot move after a later
relaxed-or-stronger atomic store, including disjoint heap classes. This is
Binaryen's proposal semantics, not C++ relaxed ordering. Reverse motion, aliases,
traps, fences and acquire/release/SeqCst restrictions need independent checks.
Precompute may evaluate eligible unshared Relaxed/AcqRel GC reads; released
SeqCst and shared reads remain nonconstant.

DAE2 treats a multiple-result tuple as one usage unit at this target. Solve usage
before mutation, preserve argument/result side effects and traps, repair every
affected type/call/return, then rebuild analyses. Constraint analysis must never
use an unfinished analysis as proof. Swapping comparison operands differs from
negating a comparison; increments use the operand width and fixed-width wrap
semantics. Keep floating-point constraint rewriting disabled initially.

### API review

The generated interface diff was reviewed after `moon info`: optional compact
encoding and validation feature controls preserve existing call sites; new enum
variants cover the released orders/proposals. Direct pattern matches on
`ArrayLoad`/`ArrayStore` now include `MemArg`; WAST atomic forms carry explicit
orders, `MemoryType` carries shared/memory64 limits, and `ElemSegment` records
declarative mode. These AST changes require downstream source updates.
Generated component bindings expose 860 constructors, including the eight new
waitqueue/order/store constructors. Component `array-load`/`array-store` calls
now supply a memory argument; core MoonBit constructor calls retain defaults.

## Required post-tag correctness intake

These changes are **outside v132**, even when required for a sound new port:

- DAE2 #8994: preserve caller results for unchangeable open-world indirect tail calls.
- Constraints #8998/#9003/#9029/#9037/#9041/#9045/#9049/#9058/#9065/#9075: tees,
  unreachable states, operand width, overflow, signed/unsigned ranges, floating
  zero/NaNs, convergence limits and AND/double-eqz handling.
- Descriptor branch sent types #9009 and atomic natural-alignment/DeAlign #8966
  are separate follow-up checks, not released v132 fixes.
- #9010 adds default constraint scheduling after the tag. Do not copy that preset
  change without Starshine measurements. Optional #9031 expands MakeSharedObjects;
  #9033 reverts wasm2c.

## Regression and signoff

The [regression intake manifest](../raw/binaryen/2026-09-10-v132-regression-intake.json)
tracks all 83 changed upstream test paths and the exact selected semantic
adaptations. An adapted subset passing does not mark the entire upstream file
executed; nonselected paths and runtime-unverified cases remain explicit.

Start with DAE2 result/control-flow/cycle/indirect/open-world/intrinsic/continuation/
return fixtures, constraint and abstract-domain units/loop fixtures, descriptor
local-subtyping/vacuum/monomorphize cases, type-updating effects, atomic alignment
and order fixtures, compact import parser/encoder cases, waitqueue/multibyte
validation, and `ctor-eval/memory64-massive.wast`.

Check validity, execution behavior and optimization quality separately. HOT
verification and lowered binary validation are required; execution observes
values, memory/globals/tables, imported-call order and traps. Unsupported runtime
features are structurally checked but runtime-unverified. Atomic motion needs
structural order assertions; relaxed SIMD and NaNs need allowed-result-aware
oracles. Checked data-segment offset/length arithmetic and bounded allocation
matter; Binaryen's 4 GiB flattening limit is an implementation resource policy.

New comparisons require the verified v132 executable, an explicit fresh native
Starshine executable, and `--require-binaryen-version 132`. Use repository GenValid
profiles and the 10,000-case parallel lane from [the docs schema](../../README.md);
external wasm-smith runs require an explicit request. DAE cleanup comparisons use
`--normalize drop-consts --normalize unreachable-control-debris`. Keep old artifact
paths and hashes attached to their original measurements.

The installed wasm-tools 1.251 rejects the new order byte 2. The inspected
[wasm-tools 1.258 decoder](https://github.com/bytecodealliance/wasm-tools/blob/v1.258.0/crates/wasmparser/src/binary_reader.rs)
still recognizes only SeqCst and AcqRel. Proposal campaigns therefore explicitly
use `--primary-validator binaryen`; their saved toolchain/result records identify
that choice. Starshine validates its own output and Binaryen validates both
sides, but this is **not independent validation or execution evidence**. Ordinary
campaigns retain wasm-tools by default. Never relabel an unsupported external
validator as a successful independent check.

The Linux x86_64 official archive SHA-256 is
`195ddc94f9bc89f45abdabb0b9eea86023d727ba90eac8b35b80f2544fc30572`.
The local installed oracle is `.tmp/binaryen-version_132/bin/wasm-opt`.

## Current renewal on September 11

The rebuilt `c447149a…` CLI and `9cd6bbe2…` generator use the verified v132
oracle. Constraint analysis completes 10,000 cases with 10,000 runtime matches
and no validation/generator/command/property failures. Open- and closed-world
DAE2 each complete 10,000 cases, with 9,312 runtime matches and 688 explicitly
unsupported executions, and zero failures. The corrected generator exercises
variant combinations missed by the earlier correlated aggregate selector.
Determinism and codec idempotence pass throughout. Output/size differences remain
separately classified; these execution results do not assert output parity.
The renew18 full repository and component gates pass. The remaining dedicated
lanes are running; subsequent repairs need a fresh full gate. Exact
counters are in the [validation ledger](../raw/binaryen/2026-09-10-v132-validation.json).

## Validation on September 10

[Machine-readable evidence](../raw/binaryen/2026-09-10-v132-validation.json)
retains exact commands, tool identities, counters and historical checkpoints.
The earlier renew10 source checkpoint passed **11,127** default wasm-gc tests after
`moon info` and `moon fmt`. It covers shared-RMW guards, conditional cmpxchg
lowering, compact constraint state, intrinsic argument preservation and element
declaration mode. The OI sweep now also advertises v132; its nine Bun tests pass,
and all 27 runtime-executor tests pass.

Native `5cb9a4d0…` resolves the `c126759f…` negative absent-else traversal
abort. The reduced input and full compiler now validate and execute. The updated
runtime adapter has a new cache execution contract, preventing old intrinsic-stub
reports from being reused. Declaration printing and precise descriptor-local
assertions were added after the full checkpoint and await focused execution.
Source tests do not count as external comparisons.

### Historical renewed constraint aggregate

Native `5cb9a4d0…` and generator `14050af8…` complete **10,000/10,000**
constraint comparisons with zero validation/generator/command/property/observed
semantic failures. There are 4,545 canonical equals and 5,455 smaller canonical
outputs, with no canonical size losses. All 10,000 observation-v2 comparisons
match; determinism and codec checks pass. Artifacts:
`.tmp/binaryen132-renew10-campaigns/constraint-analysis`.

The current twenty 192-case pilots also have zero failure counters. Optimizing
DAE2's larger-output cases fall from 63 to 20 after intrinsic and control cleanup:
eight exception, six local and six tuple cases remain. Atomic OI falls from
thirteen larger cases to four identity-RMW read-relaxation cases, now addressed
by a focused source fix. Common atomic summaries now retain order bits across
linear and GC operations; this follow-up requires another native renewal.

### Historical completed 10,000-case aggregates

These ten lanes used native `80a2c7ed…`, generator `8ac43e66…`, seed `0x5eed`,
eight workers, determinism and codec checks. Every lane has zero validation,
generator, command, property and observed runtime mismatches. These results predate
the latest atomic-store/fence, descriptor and cost follow-ups.

| Lane | Compared | Canonical matches | Cleanup matches | Residual differences | Larger canonical outputs | Runtime equal / blocked |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| constraint-analysis | 10,000 | 3,575 | 0 | 6,425 | 1,260 | 10,000 / 0 |
| dae2, open world | 10,000 | 4,276 | 998 | 4,726 | 721 | 9,269 / 731 |
| dae2, closed world | 10,000 | 0 | 267 | 9,733 | 721 | 9,269 / 731 |
| dae2-optimizing | 10,000 | 2,820 | 0 | 7,180 | 3,304 | 9,269 / 731 |
| waitqueue / precompute | 10,000 | 10,000 | 0 | 0 | 0 | 0 / 10,000 |
| compact imports / precompute | 10,000 | 10,000 | 0 | 0 | 0 | 0 / 10,000 |
| multibyte arrays / precompute | 10,000 | 10,000 | 0 | 0 | 0 | 0 / 10,000 |
| precompute / precompute-all | 10,000 | 3,238 | 6,762 | 0 | 0 | 9,551 / 449 |
| precompute-propagate / precompute-all | 10,000 | 2,766 | 7,234 | 0 | 0 | 9,551 / 449 |
| heap-store-optimization | 10,000 | 2,155 | 7,845 | 0 | 0 | 0 / 10,000 |

Artifacts: `.tmp/binaryen132-renew5-campaigns`. Remaining output differences are
agent-reviewed parity/size gaps until a measured Starshine benefit is established.
DAE2 larger cases are legacy exceptions; optimizing DAE2 also exposes control,
intrinsic, tuple, cycle and local cleanup gaps. Constraint larger cases were
846 tuple-loop and 414 tee cases. A later 192-case quality probe on `0fc56270…`
has zero canonically larger constraint outputs, but does not replace 10,000-case
renewal. Plain DAE2 still has eight larger exception cases in that probe.

The atomic profile pilot on `0fc56270…` found **37 DAE2 command failures** at
`atomic.fence` in 192 requested cases. HOT fence support and a positive signature
removal test now address that failure. HSO fresh atomic-store and OI unshared
AcqRel-store gaps also have red-to-green regressions. Review additionally exposed
an older OI shared-RMW safety gap; shared changing/SeqCst RMWs now retain their
atomic operation and identity reductions preserve the original order. The next 192-case atomic DAE2 pilot has all 192 canonical matches and no
command failures. HSO no longer has larger cases: its 63 differences omit one
upstream-retained `nop` each, preserving the same allocation values and access
order. Thirteen OI size gaps prompted AcqRel read relaxation and conditional
cmpxchg lowering; those source regressions now pass. Five descriptor pass pilots
each have 192 normalized matches and no failures, with runtime explicitly
blocked. Descriptor encoded-size differences remain open despite normalized
matching. Full 10,000-case renewal remains required.

### Upstream and compiler intake

The renewed release intake structurally validates 296 DAE2 world/module cases
and eight constraint cases using Starshine, Binaryen 132 and wasm-tools. Evidence:
`starshine-renew5.json` under `.tmp/binaryen132-dae2-intake` and
`.tmp/binaryen132-constraint-intake`. No RUN-line/text-output parity is inferred.
The memory64 massive empty-segment fixture retains its offset and instantiation
trap after memory-packing without a huge allocation.

The fixed compiler input is SHA-256 `2d535ab9…`. Both new-pass outputs validate,
start, and match the original compiler on five functional probes covering local
conditions, captures, pending calls, exceptions and nested loop parameters.
`.tmp/binaryen132-quality-benchmark/functional.json` records all fifteen successful
original/optimized compiler invocations. This covers the `0fc56270…` checkpoint;
new analysis changes require renewal.

Exploratory constraint measurements show user CPU `105.35 → 70.83 → 11.31`
seconds. Relevant-local compaction preserves the 5,540,604-byte output at
`a21f55d1…` and reduces peak RSS to 204,912 KiB. DAE2 still takes 69.75 CPU seconds
and 3,436,076 KiB, producing the same 5,537,556-byte output. Generator compilation
ran concurrently, so these remain resource probes, not isolated cost signoff.
The `renew10-self/functional.json` renewal records all fifteen successful compiler
invocations. No preset change is justified by these measurements alone.

Earlier 1,000-function fresh-read benchmarks produce identical canonical output
but expose Precompute/Propagation pass-local cost of approximately 10.6×/11.4×
Binaryen, despite both remaining below one second. The raw validation record keeps
those measurements; U09 still requires broader cost and allocation signoff.

## Exact release commit ledger

Commit subjects below are upstream inventory metadata. The slice column assigns
implementation intake; maintenance/API/test-only items do not imply pass ports.

| PR | Commit | Upstream change | Intake |
| --- | --- | --- | --- |
| [#8900](https://github.com/WebAssembly/binaryen/pull/8900) | `74c39b9b` | ConstraintAnalysis: Sort constraints internally | U07 |
| [#8912](https://github.com/WebAssembly/binaryen/pull/8912) | `1377e422` | ConstraintAnalysis: Remove older redundant constraints | U07 |
| [#8903](https://github.com/WebAssembly/binaryen/pull/8903) | `64e066e9` | Remove unused results in DAE2 | U06 |
| [#8915](https://github.com/WebAssembly/binaryen/pull/8915) | `ebd74547` | [cmake] Simplify C++ standard enforcement using target_compile_features | Maintenance / adapter only |
| [#8918](https://github.com/WebAssembly/binaryen/pull/8918) | `17ed400b` | [test] Improve run_example_tests. NFC | Maintenance / adapter only |
| [#8916](https://github.com/WebAssembly/binaryen/pull/8916) | `acfdce94` | [support] ParentIndexIterator: Add subscript and friend plus operators | Maintenance / adapter only |
| [#8914](https://github.com/WebAssembly/binaryen/pull/8914) | `9563498d` | Update DAE_STATS to handle results | U06 |
| [#8913](https://github.com/WebAssembly/binaryen/pull/8913) | `04bed6a0` | ConstraintAnalysis: Return a bool from approximateOr | U07 |
| [#8919](https://github.com/WebAssembly/binaryen/pull/8919) | `e273451a` | [NFC] ConstraintAnalysis: Avoid a copy when there are no interesting branch constraints | U07 |
| [#8922](https://github.com/WebAssembly/binaryen/pull/8922) | `74ff1eb9` | Cleanup shared constants. NFC | Maintenance / adapter only |
| [#8920](https://github.com/WebAssembly/binaryen/pull/8920) | `c7ae8fbd` | wasm-ctor-eval: Do not try to flatten segments with huge offsets | U01/U09 |
| [#8921](https://github.com/WebAssembly/binaryen/pull/8921) | `108e796b` | ConstraintAnalysis: Track relevant locals | U07 |
| [#8923](https://github.com/WebAssembly/binaryen/pull/8923) | `acf302c4` | [multibyte] Support offset and align for array load and store | U08 |
| [#8874](https://github.com/WebAssembly/binaryen/pull/8874) | `cdf3bfc5` | Fix type updating for indirect call effects | U02 |
| [#8930](https://github.com/WebAssembly/binaryen/pull/8930) | `355863c2` | Re-enable fuzzing for relaxed atomics | U05 |
| [#8924](https://github.com/WebAssembly/binaryen/pull/8924) | `a54b20b5` | ConstraintAnalysis: Add inequality comparisons to constants | U07 |
| [#8929](https://github.com/WebAssembly/binaryen/pull/8929) | `e88a1b54` | [multibyte] Expand array load and store validation | U08 |
| [#8931](https://github.com/WebAssembly/binaryen/pull/8931) | `bbeae83f` | [NFC] Track grammar of definitions in parser | U04 |
| [#8672](https://github.com/WebAssembly/binaryen/pull/8672) | `0a7b1713` | Updated waitqueue support | U08 |
| [#8936](https://github.com/WebAssembly/binaryen/pull/8936) | `87da91d0` | ConstraintAnalysis: Add OR fusing of { x == C \|\| x > C } => x >= C | U07 |
| [#8925](https://github.com/WebAssembly/binaryen/pull/8925) | `2e035664` | Parse text format for compact import sections | U04 |
| [#8937](https://github.com/WebAssembly/binaryen/pull/8937) | `ad130598` | ConstraintAnalysis: Add AND fusing of { x <= C && x < C } => x < C | U07 |
| [#8926](https://github.com/WebAssembly/binaryen/pull/8926) | `51db2233` | Opportunisticly emit compact imports | U04 |
| [#8935](https://github.com/WebAssembly/binaryen/pull/8935) | `84529ec8` | Fuzzer support for br_on_cast_desc_eq | U03 |
| [#8941](https://github.com/WebAssembly/binaryen/pull/8941) | `0c633e76` | Remove deprecated instruction mneumonics | U01/U09 |
| [#8942](https://github.com/WebAssembly/binaryen/pull/8942) | `55dff6b2` | Remove use of std::aligned_storage. NFC | Maintenance / adapter only |
| [#8938](https://github.com/WebAssembly/binaryen/pull/8938) | `a5702361` | [multibyte] Disable multibyte load/store until interpreter is ready. | U08 |
| [#8948](https://github.com/WebAssembly/binaryen/pull/8948) | `bbfbb253` | Fix unreachable br_on_cast parse bug | U03 |
| [#8951](https://github.com/WebAssembly/binaryen/pull/8951) | `15bd4f06` | [JS API] Expose BinaryenStringConst | Maintenance / adapter only |
| [#8952](https://github.com/WebAssembly/binaryen/pull/8952) | `e336c23b` | Update ruff to v0.16.0 | Maintenance / adapter only |
| [#8944](https://github.com/WebAssembly/binaryen/pull/8944) | `0430c35a` | Fix binary spans on wrapper blocks in IRBuilder | U01/U09 |
| [#8946](https://github.com/WebAssembly/binaryen/pull/8946) | `ecb3d997` | [NFC] Add file-level comments to IRBuilder | Maintenance / adapter only |
| [#8763](https://github.com/WebAssembly/binaryen/pull/8763) | `a9791003` | [wasm2c] Add the very beginning of a wasm2c implementation and test harness | Optional tool; no optimizer port |
| [#8956](https://github.com/WebAssembly/binaryen/pull/8956) | `16272bac` | Fix determinism bug when mapping type names | U02 |
| [#8953](https://github.com/WebAssembly/binaryen/pull/8953) | `26d46edc` | Add a MakeSharedObjects pass | U10 |
| [#8959](https://github.com/WebAssembly/binaryen/pull/8959) | `d78c2455` | [wasm2c] Only run clang-tidy-diff on files that are compiled | Maintenance / adapter only |
| [#8955](https://github.com/WebAssembly/binaryen/pull/8955) | `9c108679` | ConstraintAnalysis: Add more simple inequalities | U07 |
| [#8954](https://github.com/WebAssembly/binaryen/pull/8954) | `b8f91600` | [JS API] Merge `Module['readBinaryWithFeatures']` into `Module['readBinary']` | Maintenance / adapter only |
| [#8961](https://github.com/WebAssembly/binaryen/pull/8961) | `33abc59a` | Fix alignment in relaxed atomics spec test | U05 |
| [#8963](https://github.com/WebAssembly/binaryen/pull/8963) | `8e444fc6` | ConstraintAnalysis: Add missing unsigned cases | U07 |
| [#8967](https://github.com/WebAssembly/binaryen/pull/8967) | `fc8f31cf` | [Relaxed SIMD] Fix validation and fuzzer handling | U01/U09 |
| [#8972](https://github.com/WebAssembly/binaryen/pull/8972) | `e821d175` | Remove unused variables. NFC | Maintenance / adapter only |
| [#8973](https://github.com/WebAssembly/binaryen/pull/8973) | `b97310a2` | Add BYN_WARN_UNUSED macro and apply to Name and IString | Maintenance / adapter only |
| [#8974](https://github.com/WebAssembly/binaryen/pull/8974) | `a0463cbe` | Fix ReFinalize in MakeSharedObjects | U10 |
| [#8977](https://github.com/WebAssembly/binaryen/pull/8977) | `042f47fd` | Consistent header guards. NFC | Maintenance / adapter only |
| [#8969](https://github.com/WebAssembly/binaryen/pull/8969) | `e27398d8` | ConstraintAnalysis: Increment constants | U07 |
| [#8970](https://github.com/WebAssembly/binaryen/pull/8970) | `f1b0e46c` | Fix untaken BrOn branch analysis | U03 |
| [#8982](https://github.com/WebAssembly/binaryen/pull/8982) | `ab7d0f59` | Rename relaxed-atomics to acquire-release-atomics | U05 |
| [#8975](https://github.com/WebAssembly/binaryen/pull/8975) | `efe5df17` | [CustomDescriptors] Ensure a non-nullable type for br_on_cast_desc_eq on null | U03 |
| [#8980](https://github.com/WebAssembly/binaryen/pull/8980) | `6906bf01` | ConstraintAnalysis: Optimize loops | U07 |
| [#8971](https://github.com/WebAssembly/binaryen/pull/8971) | `b3e9b4fb` | Fix inplace_vector test on 32-bit | Maintenance / adapter only |
| [#8987](https://github.com/WebAssembly/binaryen/pull/8987) | `302396a6` | Fuzzing: Prioritize RefCast | U01/U09 |
| [#8983](https://github.com/WebAssembly/binaryen/pull/8983) | `86a7c4c7` | Add relaxed-atomics feature flag | U05 |
| [#8984](https://github.com/WebAssembly/binaryen/pull/8984) | `d8c6b2ab` | Add a "relaxed" memory order | U05 |
| [#8989](https://github.com/WebAssembly/binaryen/pull/8989) | `2a03c015` | Generate more descriptor types in the fuzzer | U01/U09 |
| [#8993](https://github.com/WebAssembly/binaryen/pull/8993) | `23b17a19` | Add Abstract::flipRelational | U07 |
| [#8988](https://github.com/WebAssembly/binaryen/pull/8988) | `37f9eb33` | ConstraintAnalysis: Handle cases with extra constraints | U07 |
| [#8995](https://github.com/WebAssembly/binaryen/pull/8995) | `7c4c1602` | Do not fuzz relaxed-atomics on V8 yet | U05 |
| [#8997](https://github.com/WebAssembly/binaryen/pull/8997) | `79dfe6b4` | Version 132 | U01 release pin |

## All changed pass files

| File | Added / removed lines |
| --- | --- |
| `src/passes/Asyncify.cpp` | +15 / -15 |
| `src/passes/CMakeLists.txt` | +1 / -0 |
| `src/passes/ConstraintAnalysis.cpp` | +313 / -27 |
| `src/passes/DeAlign.cpp` | +4 / -0 |
| `src/passes/DeadArgumentElimination.cpp` | +5 / -2 |
| `src/passes/DeadArgumentElimination2.cpp` | +555 / -268 |
| `src/passes/GenerateDynCalls.cpp` | +0 / -1 |
| `src/passes/GlobalEffects.cpp` | +8 / -6 |
| `src/passes/InstrumentBranchHints.cpp` | +2 / -2 |
| `src/passes/InstrumentLocals.cpp` | +15 / -15 |
| `src/passes/InstrumentMemory.cpp` | +30 / -30 |
| `src/passes/LegalizeJSInterface.cpp` | +4 / -4 |
| `src/passes/LogExecution.cpp` | +1 / -1 |
| `src/passes/MakeSharedObjects.cpp` | +401 / -0 |
| `src/passes/OptimizeInstructions.cpp` | +2 / -0 |
| `src/passes/Precompute.cpp` | +4 / -0 |
| `src/passes/Print.cpp` | +26 / -8 |
| `src/passes/RemoveNonJSOps.cpp` | +16 / -0 |
| `src/passes/ReorderLocals.cpp` | +0 / -1 |
| `src/passes/SafeHeap.cpp` | +21 / -11 |
| `src/passes/TrapMode.cpp` | +8 / -4 |
| `src/passes/TypeGeneralizing.cpp` | +3 / -1 |
| `src/passes/call-utils.h` | +3 / -3 |
| `src/passes/pass.cpp` | +8 / -0 |
| `src/passes/passes.h` | +1 / -0 |

All changed paths and hashes are retained in the linked machine-readable inventory.
