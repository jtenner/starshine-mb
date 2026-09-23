# Agent Tasks

## v0.1.1 — September 22 optimizer correctness spree [IR2-CORRECTNESS-20260922]

- **Goal / why:** close the eight-agent pass audit at `006c24f9` without silently
  treating valid output, small output, or harness normalization as semantic
  proof. The audit found reproduced wrong results, invalid intermediate modules,
  a valid-input crash family, source-level hazards, and signoff blind spots.
- **Deliverables / tasks:** work through the numbered checklist below with one
  independently reviewable fix per atomic commit. For each behavior gap, add an
  adjacent red regression and an active-dispatcher regression, observe failure,
  implement the smallest sound correction, observe green, update relevant docs,
  and record the commit here. For hypotheses, first construct a valid executable
  reproducer or establish a source/spec proof; fix confirmed defects and record
  the evidence when the hypothesis is disproved. No fuzz runs in this spree.
- **Required APIs / invariants:** every supported transform preserves Wasm
  results, traps, effects, imports/exports, proposal-specific control targets,
  and valid encoding. Input modules stay immutable through rollback. Compiler
  facts and name maps remain coherent. Binaryen 132 is the comparison target;
  use the verified v132 oracle only for bounded reproductions.
- **Dependencies / exit:** serialize Moon commands; use `moon info`, `moon fmt`,
  and `moon test` for behavior changes. The user's no-fuzz instruction replaces
  the skill's randomized signoff matrix for this spree, so do not claim final
  fuzz/parity signoff. Close each item with its regression, source review,
  validation result, and atomic commit hash; leave any unresolved item visible.
- **Suggested tests:** reduced WAT/Core-AST fixtures, direct IR/byte assertions,
  bounded runtime result/trap checks, host import/identity checks, validator
  checks, and harness unit tests. Saved repros are under `.tmp/current-audit-*`.

### Reproduced defects and urgent safety gaps

1. [x] OI → DCE multi-value loop returns `unreachable` instead of `[0, 2.5]`
   (`acb68f4a2`); source-ordered value roots survive DCE, with adjacent and
   active OI→DCE dispatcher regressions red then green.
2. [x] Global Struct Inference substitutes an internal object for an imported
   GC reference (`936d7f4d3`, `cb1f2ea08`); imported origins and exported
   function parameters now poison compatible singleton facts, with direct
   and command-dispatch regressions.
3. [x] RUME leaves a stale type-name index after type compaction
   (`0ecbc09e1`); direct and dispatcher metadata regressions are green.
4. [x] RUME leaves stale label names after function-body nullification
   (`fd44305d5`); direct and dispatcher validation regressions are green.
5. [x] OptimizeInstructions crashes on valid legacy-EH `delegate` inputs
   (`e32869055`). The HOT verifier checks exception-transfer arity independently of the
   target try's ordinary result arity; focused IR and dispatcher tests were
   red before the fix and green afterward.
6. [x] Compare-pass exits zero despite configured correctness failures
   (`2bb42a77c`); explicit `--report-only` retains diagnostic collection.
7. [x] DCE label-use index omits `try_table` catch destinations
   (`fdfae1e2e`); all catch-arm labels now enter the incoming-label bitset.
   Direct and dispatcher fixtures failed before the fix and passed after.
8. [x] DCE label-use index omits continuation handler destinations
   (`647323046`); all represented continuation targets now enter the same
   bitset. Direct and dispatcher fixtures failed before the fix and passed
   after. Combined label tests passed 2/2 adjacent and 2/2 dispatcher;
   `moon fmt` and `moon info` passed. No fuzzing was run.
9. [x] Shared unreachable cleanup can rebind continuation handlers
   (`b6a775e51`); the helper and once-reduction dispatcher regressions are green.
10. [x] Vacuum block flattening omits continuation-label rebasing
    (`20f58fa2b`); raw owner scans and outer-label rebasing now cover all
    three resume forms. Direct and public dispatcher tests failed before the
    fix and passed afterward (4/4 and 140/140); `moon fmt` and `moon info`
    passed. No fuzzing was run.
11. [x] Flatten now indexes continuation handler label targets and rejects
    unsupported implicit-payload routing (`ebb3618e9`). Valid adjacent and
    dispatcher fixtures failed before the fix with a resume label-arity
    validation error and passed afterward; the full adjacent file passed
    294/294, and `moon fmt` passed.
12. [x] CodePushing structured-region local-effect concern was disproved
    (`5ffb679d2`). Recursive whole-function and suffix counts reject intervening
    structured reads and writes before movement. Valid direct and dispatcher
    fixtures passed before any production change; no behavior fix was warranted.
13. [x] CodePushing nested-branch concern was disproved (`bc2419f9b`).
    The HOT child graph already reaches nested region roots. Direct ownership
    and dispatcher encode/decode fixtures stayed green; mutation of the recursive
    guard made both fixtures fail. No behavior change or fuzzing was needed.
14. [x] RemoveUnusedBrs now counts continuation handler labels and preserves
    their result type during block refinalization (`6216b1a7d`). Valid direct
    and dispatcher fixtures failed before the fix; both passed afterward,
    with `moon fmt` and `moon info` green. No fuzzing was run.
15. [x] MergeBlocks `try`/`try_table` carried-local scan concern was
    disproved: both collectors recurse through generic HOT children in
    `src/passes/merge_blocks.mbt`, and the HOT builders give each EH node two
    region-holder children. Valid legacy `Try` catch and catchless `TryTable`
    carried-local fixtures now pass directly and through the active dispatcher
    (`39291ee50`). Exact scanner-omission mutations failed both tests;
    restored production passed. This proves conservative scan ownership and
    shape preservation, not a standalone runtime corruption reproduction.
16. [x] SimplifyLocals now treats continuation handler labels as exits before
    sinking local writes (`cab7b8aa3`). Valid direct and dispatcher fixtures
    failed before the fix and passed afterward; `moon fmt` and `moon info`
    passed. Valid `ResumeThrow` and `ResumeThrowRef` direct and dispatcher
    fixtures now cover the same pre-operation exit path (`b1cf20d89`).
17. [x] SimplifyLocals now clears block fallthrough facts when a continuation
    has an on-label exit (`100c7e537`). A later `local.set 9` does not dominate
    the handler path that still observes `1`; before the fix the final get was
    incorrectly replaced with `i32.const 9`. Valid direct and dispatcher tests
    were red then green; `moon fmt` and `moon info` passed without fuzzing.
    Both throwing resume forms now have valid direct and dispatcher
    post-operation fallthrough regressions (`b1cf20d89`).
18. [x] CoalesceLocals liveness omits resume-handler successors
    (`323893154`); `ResumeOnLabel` targets now contribute to backward
    liveness for all three resume forms. Valid direct and dispatcher fixtures
    failed before the fix and passed afterward; `moon fmt` and `moon info`
    passed. Valid direct and dispatcher fixtures now cover `ResumeThrow` and
    `ResumeThrowRef` on-label successors (`b1cf20d89`).
19. [x] Pattern-B partial inlining misses branch/catch/continuation escapes
    (`980043a5d`); the escape scanner covers all represented branch, catch,
    and resume-handler targets, with invalid-helper repros red then green.
20. [x] DAE2 changes signatures reachable through exported abstract `funcref`
    tables (`04a3c15ae`); host-visible table references and indirect-call
    types retain their signatures. Direct and dispatcher fixtures were red
    before the fix and green afterward; neighboring private-table pruning and
    `moon fmt` passed. No broad suite or fuzzing was run.
21. [x] Shared identity atomic RMW loses its release write (`b12664835`);
    focused pass and command regressions are green.
22. [x] Same-value shared `cmpxchg` loses its conditional release write
    (`b41f7d36a`); focused pass and command regressions are green.
23. [x] Nested Local CSE misses atomic struct/array mutation barriers
    (`4cfbbeb99`); direct and command regressions are green.
24. [x] Nested Local CSE misses ordinary `ArrayStore` barriers
    (`4cfbbeb99`); direct and command regressions are green.
25. [x] Local CSE treats suspend/resume/stack-switch execution as transparent
    (`d7219b783`); nested-window scans now stop at switching operations,
    with valid direct and command-dispatch regressions red then green.
26. [x] Caught-`try_table` safety scans omit legacy `Try` descendants
    (`3c74e420d`); pass-manager, remove-unused-brs, and CLI scanners now
    recurse through protected and catch regions, with focused O4z and CLI
    regressions red then green.
27. [x] Once Reduction mutates nested arrays owned by its input module
    (`d9d8e0b9a`); direct input-byte and O4z rollback regressions failed before
    deep copying and passed afterward (45/45 adjacent, 140/140 dispatcher).

### Host behavior, metadata, and registry contracts

28. [x] RUME removes imports whose host resolution is observable
    (`432e01596`); public variants retain all source-order imports after
    semantic reachability, with direct and dispatcher host-roster regressions
    red then green (59/59 adjacent, 4/4 whitebox).
29. [x] ReorderGlobals changes observable imported-global getter order
    (`e73420e80`); the import section keeps source order while defined globals
    still reorder and remap, with focused dispatcher and whitebox regressions.
30. [x] Directize synthesizes labels without remapping label-name metadata;
    synthetic `if` insertions now shift later function-wide label-name indices.
    Direct and dispatcher regressions failed before the fix and passed after;
    both Directize test files, `moon fmt`, and `moon info` passed.
31. [x] `no-inline*` annotation rebuild drops structured compiler facts.
    Both policy dispatch and clone annotation copying now preserve the
    compiler-fact custom section; adjacent focused tests were red then green
    (`3ffc943ca`).
32. [x] MergeSimilarFunctions introduces tail calls despite conflicting
    target-feature metadata (`3db11a408`); canonical `-tail-call` metadata
    selects ordinary calls, with adjacent and dispatcher regressions red then
    green (15/15 adjacent, 1/1 dispatcher).
33. [x] Direct DFE now preserves every exported function address, including
    equal-body exports; the JavaScript API caches function objects by address.
    Direct and dispatcher tests failed before the guard and passed afterward;
    the full adjacent DFE file passed 31/31. Item 71 tracks remaining
    address-taken internal identity risk.
34. [x] Direct DIE now preserves independently resolved repeated imports
    (`d53b6f1d1`), and an explicit `duplicate-import-elimination-assume-stable-bindings`
    variant retains merging only under a caller guarantee of side-effect-free
    repeated lookup and identical converted Wasm function identity
    (`26ef7d52e`). Default direct and preset modes keep host getter effects;
    Red/Green direct, dispatcher, and Node host identity tests passed.
    `moon info` records the intentional public `.mbti` entrypoint. No fuzzing ran.
35. [x] DIE preserves annotations on a removed import alias (`5ec8e0ac4`).
    The trusted stable-binding variant unions annotations by final function
    index in source order, deduplicates identical name/argument pairs, and
    retains annotations on shifted defined functions. Direct and dispatcher
    regressions were red 0/2 then green 2/2; adjacent DIE tests passed 15/15.
36. [x] MemoryPacking rebuilds unchanged modules after a reverted segment
    rewrite (`7876e64af`). The post-cap change check returns the input module;
    a dedicated skipped 100,000-segment regression was red then green and
    verifies raw name bytes survive direct and dispatcher execution.
37. [x] MemoryPacking models `RefTestDesc` with the wrong operand count
    (`4dc7ebcad`).
    The scanner now consumes one reference; its whitebox assertion and a
    validated active dispatcher fixture failed before the fix and pass after.
38. [x] Bare `no-inline*` registry entries advertise unsupported exact pass
    names. Library expansion now requires `=PATTERN`, and CLI parsing rejects
    each bare base before dispatch; registry and CLI tests were red then green.

### Harness correctness and coverage

39. [x] `drop-consts` normalization erases trapping unsigned conversions
    (`761806225`).
40. [x] `unreachable-control-debris` normalization fails to root the start
    function (`05a1bac63`).
41. [x] Canonicalization strips semantically important named type uses
    (`d54717072`); previously hidden type-shape mismatches may reopen.
42. [x] Runtime-v2 discards definite observations when another surface is
    blocked (`1fdabfd0f`); focused runtime harness regressions are green.
43. [x] Runtime-v1 skips parameterized/missing exports and can count empty
    matrices (`e87f95d36`); required exports, typed parameters, blocked rows,
    and empty-matrix accounting have focused harness regressions.
44. [x] Resume fingerprints omit source and configuration identity
    (`c1b713091`); versioned SHA-256 records bind resume journals to tool,
    source, and normalized run settings, with count-zero red/green harness tests.
45. [x] Binaryen command failure can still increment `comparedCount` as a
    match (`115b20297`); fresh and resumed failure records stay out of
    comparison counts, with synthetic red/green oracle-command coverage.
46. [x] Name/debug pass comparisons are erased by unconditional debug stripping
    (`68d82071a`); `strip-debug` lanes now preserve printable names through
    canonicalization, reduction, and diagnostics, with isolated cache entries.
    Synthetic red/green harness tests passed 77/77; arbitrary custom sections
    and nonprinted DWARF remain outside this specific comparison projection.
47. [x] Add executable proposal observations for currently blocked families.
    Non-null `i31ref` function arguments/results and imported-function events
    are now observed with bounded signed 31-bit vectors (`8d485d476`); focused
    runtime tests passed 41/41 after integration. Exact-type retained exports
    now supply executable non-null struct and array references; `exnref` and
    abstract/nullable/nominal `contref` crossings return explicit JavaScript
    unsupported reasons, and relaxed-SIMD diagnostics carry a machine-readable
    general allowed-outcome boundary (`389865173`). Imported memory64 uses a
    BigInt-limit Node adapter and a full in-cap snapshot; a corrupt
    `memory.size` is detected (`ab1ef3225`). Focused Bun and Moon suites passed.
    Arbitrary relaxed-SIMD outcome contracts and GC arguments without an exact
    producer remain explicit unsupported boundaries. No fuzz campaign ran.
48. [x] Add bounded multi-thread allowed-outcome checks for atomic transforms.
    A bounded two-worker Node litmus now checks declared allowed outcomes for
    sequentially consistent `i32.atomic.rmw.add` over shared memory
    (`75fec2f14`); synthetic increment-by-two corruption is rejected, and
    focused runtime suites passed 60/60. A second bounded `wait32`/`notify`
    fixture observes completed calls and rejects an incorrect atomic store;
    a third fixture checks `i32.atomic.rmw.cmpxchg` winner identity and rejects
    a wrong replacement value; focused Bun tests passed 5/5. A bounded
    nonzero-memory `i32.atomic.rmw.add` fixture now catches an optimizer that
    redirects memory 1 to memory 0 (`6c862b7f3`); focused Red/Green tests
    passed 6/6. A required-wake fixture now blocks acceptance when a bounded
    notify run produces no actual wake witness (`8579496ae`); absence is not
    mislabeled a semantic mismatch. A two-worker shared-memory64 RMW at
    address zero rejects add-by-two corruption (`9b734a133`). A second
    nonzero-memory `cmpxchg` fixture observes both memories and rejects a
    redirected target (`239f2ec58`). Exact AcqRel and Relaxed store/fence
    binaries are `blocked` by Node v26 before execution (`7ec41eb9c`), so
    they supply an explicit unsupported boundary, not outcome evidence.
    A mixed memory32/memory64 two-worker fixture rejects redirection from
    memory64 to memory32 (`501cf2281`). Memory64 last-word/first-out-of-bounds
    RMW fixtures now observe normalized per-thread bounds traps and reject a
    corrupt address while unrelated worker traps remain blocked (`ede701b63`).
    The original shared-function shared-GC probe remains a tested Node v26
    unsupported boundary (`82cb893b3`). An instance-per-worker topology now
    transfers one shared struct reference, observes allowed
    `struct.atomic.rmw.add seq_cst` old values `(0, 1)` / `(1, 0)` and final old
    value `2`, and rejects an add-by-two candidate. This is an opt-in replay
    primitive; general node-v2 still runs single-threaded. The bounded harness
    goal is met; unsupported orders, broader shared-GC families, general
    wait/notify liveness, addresses above 4 GiB, wider opcode coverage, and
    arbitrary schedules remain tracked below. No fuzz campaign ran.
49. [x] Runtime-v2 now adds two bounded finite scalar vectors derived from the
    recorded seed for each callable export; the invocation hash and semantic
    cache revision reflect the new observations. A focused test failed before
    the change and passed afterward; runtime/cache unit files passed 16/16.
50. [x] Binaryen success-cache hits now verify SHA-256 hashes of raw Wasm,
    canonical Wasm, and WAT artifacts; missing, legacy, or corrupt entries
    regenerate. A synthetic tamper regression failed before the fix and passed
    after; nearby harness tests passed 77/77. No fuzzing was run.
51. [x] Binaryen/canonicalization command failures are no longer cached as
    stable oracle results; old `failure.json` entries are ignored and a later
    lane retries the command. A fail-then-recover synthetic regression failed
    before the fix and passed afterward; nearby harness tests passed 77/77.
52. [x] Optimizer, validator, generator, and auxiliary subprocesses have hard
    deadlines. The configurable timeout now reaches wasm-smith, GenValid, and
    the Binaryen version probe (`7e127706a`); the latter retains a 5-second
    maximum. Synthetic hangs for Starshine, an external validator, both
    generators, and the version probe exposed the missing deadlines before the
    fix and passed afterward (compare-pass tests 86/86). Auxiliary probes keep
    documented fixed deadlines. No fuzz campaign ran.
53. [x] Correctness signoff lanes now require independent `wasm-tools`
    validation through `--require-independent-validator`; Binaryen-only
    primary validation is rejected before running, while diagnostic lanes
    remain available. Both CI compare-pass commands carry the flag; parser
    and workflow-contract tests failed before the fix and passed afterward.
54. [x] A missing configured external validator now fails the case instead of
    silently passing; the skipped-tool counter remains diagnostic. A synthetic
    red/green missing-WABT regression and nearby harness tests passed 77/77.
55. [x] Both CI compare-pass correctness lanes now require `--determinism`
    and `--codec-idempotence`; a workflow-contract test failed before the flags
    were added and passed afterward. No CI fuzz campaign was run locally.
56. [x] A separate `workflow_dispatch` job now runs a bounded explicit
    `--wasm-smith` lane with pinned Binaryen 132, independent validation,
    determinism, codec stability, and strict failure exit. Its workflow
    contract test failed before the job and passed afterward. The lane was
    not executed during this no-fuzz repair spree.
57. [x] The branch-required `dae-differential` status now contains both the
    10,000-case DAE lane and a bounded semantic GenValid lane, each with strict
    failure exits and independent validation. The required workflow self-check
    enforces both commands; GitHub master protection listed `dae-differential`
    among required statuses on 2026-09-22. The semantic lane was not run during
    this no-fuzz repair spree, so its green CI result remains to be observed.
58. [x] GenValid now has deterministic trigger profiles for `local-cse`
    repeated arithmetic trees and DFE exact duplicate/fixed-point callers
    (`a2ef38904`). Both join random-all and batch manifest labeling. Missing
    constructors made the new tests red; focused validate, manifest, owner,
    and dispatcher tests passed after implementation. No fuzz campaign ran.
59. [x] GenValid now has exact whole-module feature floors for descriptors,
    continuations, waitqueues, atomics, and array memory (`ba6781d95`).
    Aggregate struct/array atomics count toward atomics while the shared
    linear-memory floor remains specific to linear atomic instructions.
    Manifest facts and counters expose the new families; required-feature
    JSON retains its legacy key and adds a lowercase label. Three red
    regressions preceded the fix; bounded validate/fuzz suites passed 2507/2507.
    No fuzz campaign ran. The public `.mbti` gained additive facts and keys.
60. [x] Compare-pass now journals exact raw `compiler.facts` section presence,
    count, encoded length, SHA-256, scan status, and effective trust policy
    (`30ffd4ad1`). Explicit policy is Starshine-only and resume-bound; legacy
    rows remain resumable. Red/Green focused Bun tests passed without fuzzing.

### Hypotheses to prove or reject before changing behavior

61. [x] SSA-no-merge now rejects continuation flow before raw LocalGraph and
    legacy alias rewriting, and guards the lifted normal-flow-only SSA path
    (`06de60fca`). A valid handler-bearing `resume` fixture made direct and
    dispatcher tests fail before the fix; both passed after. `moon fmt` and
    `moon info` passed with no API change or fuzzing.
62. [x] Direct public HOT Local CSE shared-load hypothesis was not reproduced.
    A valid lifted shared-memory function retains two matching loads without
    module context; the test checks both HOT load nodes and their result/effect
    metadata, then counts both emitted loads. It passed before any behavior
    change. The regression guards future HOT key changes; no fuzzing was run.
63. [x] Local CSE's nested raw scanner now treats `waitqueue.new` as an
    allocation barrier and `waitqueue.notify`/`struct.wait` as atomic barriers
    (`561250f47`). Valid direct and dispatcher fixtures changed incorrectly
    from three pairs of shared-struct reads to three single reads before the
    fix; both now retain `[2,2,2]`. `moon fmt` and `moon info` passed; no fuzzing.
64. [x] Shared-memory passive-split concern was not reproduced (`7072ec82d`).
    The threads execution rules reduce `memory.init` and `memory.fill` to
    increasing-address byte stores, and the pass preflights complete bounds
    and segment lifetime before writes. Valid direct and active-dispatcher
    fixtures kept ordered copy/fill/copy output and validation; both were green
    before any behavior change. No concurrent fuzzing or litmus sweep ran.
65. [x] Heap Store Optimization now folds only `Relaxed` stores into fresh
    shared-object constructors and retains `AcqRel`/`SeqCst` atomic stores
    (`702852330`). Their release/SC event may synchronize after publication;
    constructor data preserves the value but not that event. Valid direct and
    dispatcher fixtures were red then green; Relaxed still folds. Verified
    Binaryen v132 deletes the ordered store, so this is a documented Starshine
    correctness win. `moon fmt` and `moon info` passed; no fuzzing ran.
66. [x] Precompute allocation resource boundary is documented and guarded
    (`113dd13f1`). Verified Binaryen v132 erases a finite fresh allocation
    whose ordinary result is known, while retaining an enormous unsigned
    `2^32-1` allocation in its bounded evaluator. Host OOM is outside Wasm
    observable semantics; defined traps and effects remain required. Valid
    direct and dispatcher fixtures for both Precompute variants passed before
    any behavior change, as did `moon info` and `moon fmt`. No fuzzing ran.
67. [x] Canonical two-operand `RefCastDescEq` nullable-null folding preserves
    source/descriptor evaluation, nullable-descriptor traps, and typed results
    (`6a0b692b4`); adjacent and dispatcher tests failed before the fix and
    passed after, with `moon fmt` and `moon info` green. Non-null canonical
    descriptor casts remain intact pending value-identity proof.
68. [x] OptimizeCasts abstract-heap matcher now follows validator-approved
    bottom edges and rejects unrelated `func`/`extern -> any` shortcuts
    (`d4cafc8ba`). Adjacent four-edge and active-dispatch fixtures failed
    before the fix and passed afterward; `moon fmt` and `moon info` passed.
69. [x] Heap2Local's missing subtype suffix-field branch is intentional
    (`91a8bfe0f`). A valid dynamic base/subtype selection retains two
    allocations, the cast, and the field read because a base path must trap;
    the later nontrapping proof rejects scalarization. The constant subtype
    selection still scalarizes. Direct and dispatcher boundary fixtures passed
    before any behavior change, as did `moon fmt` and `moon info`; no fuzzing.

### Defects discovered during this repair spree

70. [x] MemoryPacking drops structured compiler facts whenever it rebuilds a
    module after a successful data-segment rewrite (`4381795de`). Direct and
    dispatcher zero-range fixtures were red before the metadata carry and
    green after.
71. [x] DFE now preserves internal function identities materialized by
    `ref.func`, global/table initializers, and active/passive elements
    (`4afe11d59`). Direct and dispatcher regressions were red before and green
    after; Node host identity checks distinguish table/global function values.
    Direct `ref.eq` on function refs is invalid Wasm, so the host API supplies
    the behavioral proof. Focused tests, native build, `moon info` and `moon fmt`
    passed; no fuzzing ran.
72. [x] GSI now treats functions callable through exported or imported tables
    as external parameter sources (`7db63d412`). Validator nominal subtyping
    determines compatible function types. Valid direct and dispatcher cases
    failed before the fix and passed afterward; focused tests, `moon info`,
    and `moon fmt` passed without fuzzing.
73. [x] DCE now preserves source order when a lifted terminator is stored before
    live result or control roots that execute earlier (`df10bc0b8`). A clean
    typed-loop direct regression and the full seven-pass dispatcher regression
    were red before the fix and green after; the adjacent DCE file passed
    68/68. Exact saved cases 259 and 367 now validate and return `[0, 2.5]`
    for `run(0)`, matching their original modules instead of trapping. Prior
    typed-control voidification tests remain green. No fuzz campaign ran.
74. [x] The effect/trap scanner now skips valid modules without code, decodes
    typed-reference locals and reference calls, and consumes SIMD immediates
    before classifying executable opcodes (`b483df078`). Valid-byte tests
    failed first for saved SIMD, data-only, typed-local, and call-ref shapes,
    then passed. Saved case 16 now has empty facts; all 38 data-only overlap
    inputs have empty facts; all 28 call-topology inputs report calls without
    false unreachable facts. Focused compare-task tests passed 78/78. The
    scanner remains a bounded triage decoder, not a full Wasm validator; no
    fuzz campaign ran.
75. [x] Random-all profile selection now avalanches its leaf selector before
    scheduling, breaking the low-bit correlation with case seeds (`ae91f7b87`).
    The old saved campaign selected only odd GC/call routes, even segment
    routes, and three-memory memory64 cases. A bounded 128-case test failed
    before the fix, then covered both memory counts, all eight GC variants,
    both call-route parities, and all four segment rotations. Case seed goldens
    and singleton generation remain unchanged; grouped random-all tests passed
    3/3, `moon fmt` and `moon info` passed. No fuzz campaign ran.
76. [x] Convergence now requires identical consecutive raw module hashes for
    fixed points and repeated exact raw hashes for cycles (`ec0dcf9c4`);
    canonical hashes remain diagnostics. Nine saved EH cases exposed the old
    projection-alias false fixed point. A red three-alias chain later changed
    canonical shape, then passed after the fix; unknown raw identity stays
    bounded nonconvergence. Focused property tests passed 14/14 and adjacent
    compare-task tests passed 92/92. No fuzz campaign ran.
77. [x] A phase-unknown worker deadline now reports
    `blocked-starshine-runtime` with its timeout diagnostic, rather than a
    proven Starshine correctness failure (`e8402cb13`). Saved GC case 1's
    identical raw output compiles and returns `12045` in bounded replay; the
    historical 2-second failure was a worker wall-clock timeout under parallel
    load. Red runtime and resumed-counter tests became green; adjacent focused
    suites passed 24/24, 27/27, and 78/78. Known candidate failures retain
    correctness-failure status, and cache identity advanced to v10. No fuzz
    campaign ran.
78. [x] Saved seven-pass case 907 needs repeated OptimizeInstructions and
    Precompute passes before a pure local/conditional expression reaches
    `i32.const 1`; verified Binaryen 132 rewrites it sooner. The first OI pass
    sinks local sets but does not revisit the exposed `if`; current output
    changes across four generations despite complete 10-call semantic equality.
    Add red direct and dispatcher convergence tests, fix bounded revisit
    scheduling, and replay the exact saved input without a fuzz campaign.
    Fixed in `781602ab3` with a one-node condition revisit after the
    same-local sink and a bounded raw bridge. Red direct and dispatcher tests
    required one-run OI convergence; green OI1/OI2 are byte-identical at 55
    bytes. The exact saved ten-call plan returns `1` for original, Starshine,
    and verified v132; seven-pass outputs reach a validated 40-byte fixed
    point. No fuzz campaign ran.
79. [x] The bounded effect/trap scanner still misreads signed result blocktype
    `0x7f` as an executable arithmetic hazard and stops long signed LEB
    immediates after 35 bits, then misreads their trailing bytes as opcodes.
    Saved pure cases 447, 673, and 767 therefore have false trap/unreachable
    facts despite item 74's other scanner repairs. Add valid-byte red tests,
    correct these operand boundaries, and replay their facts without fuzzing.
    Fixed in `ddfea4f36` and `ef3b71e79`: focused valid-byte tests cover
    structured result blocktypes, full-width signed constants, and multi-byte
    legacy `try` type indices while retaining true unreachable, division, and
    exception hazards. Exact saved-byte cases 447, 673, and 767 now have no
    false trap or hazard facts. The separate `try_table` catch-vector boundary
    is closed under item 80.
80. [x] The effect/trap scanner walked valid `try_table` blocktype and catch
    vector bytes as executable opcodes, adding false `unreachable` hazards and
    missing the exception region. Red valid-byte coverage and a real
    post-region `unreachable` control precede the narrow decoder in
    `c9a39aa48`. Saved EH cases 1, 40, and 256 now retain real exception and
    throw facts while losing false catch-immediate hazards; no fuzz ran.
81. [x] Verified v132 rewrites signed `x < MAX` and `x > MIN` to inequality
    against the same endpoint for i32 and i64; Starshine kept the relational
    spelling in saved cases 447 and 673 with no measured size win. Direct tests
    failed first on both endpoint families, and the public command test failed
    on i32 MAX. The guarded rewrite in `4db5b41a3` retains the original lhs,
    including calls and traps. Focused direct plus command tests are green;
    `3d0a2e9d7` covers all four command variants. Verified v132 SHA-256 is
    `500201b4d13ccc3a61fa5254073e75a138bc57be198bd6c18c5a9562c081ad18`.
82. [x] Saved seven-pass case 31 exposed a raw-size Vacuum parity gap:
    after removing the now-dead body, Starshine retained an unused struct type
    and emitted 50 bytes while verified v132 pruned the type and emitted 45.
    External canonicalization later hid the gap (44 vs 45), so the raw
    `+5` regression had to stay visible. Fixed in `59d4d55e9`: Red adjacent
    and dispatcher tests retained the dead type, and a metadata-boundary test
    exposed unsafe pruning. Vacuum now reuses validated simple-type cleanup
    after changed code and repaired writeback; the shared helper refuses opaque
    custom sections. Green adjacent, dispatcher, Vacuum metadata, Precompute
    metadata, and existing positive Precompute tests pass. Exact saved replay
    validates at 44 raw / 44 canonical bytes versus verified v132's 45 / 45;
    Starshine omits Binaryen's trailing `nop`. No fuzz campaign ran.
83. [x] Saved retained cases 15 and 28 had an OptimizeInstructions
    local-declaration grouping gap: Starshine preserved split equal-type
    groups where verified v132 packed them with a matching local-index remap.
    Their original final canonical outputs were each one byte smaller, but
    emitted raw modules were 1 and 5 bytes larger. Fixed in `f8ff746af`:
    red direct tests exposed the run count, and the guarded post-lowering
    regrouping remaps local operands and decoded names. It fails closed for
    legacy `try`, opaque names, and code-offset metadata, uses a fair
    compiler-facts size baseline, and requires a smaller validated encoding.
    Green direct, active dispatcher, and shared DFE tests pass 9/9, 2/2, and
    2/2. Exact public CLI seven-pass replay is 42/42 bytes for case 15 versus
    v132's 43/43, and 43/43 for case 28 versus v132's 44/44; all six Node
    vectors agree. No fuzz campaign ran.
84. [x] Saved seven-pass case 767 had equal-size but unordered pure `i32.or`
    comparison children. Verified v132 orders same-class scalar compares by
    its opcode rank; Starshine had no equal-class tie-break and no measured
    benefit from its output shape. Direct and dispatcher tests failed first.
    `4306ae2eb` adds the tie-break behind existing effect/use-def guards;
    both focused tests pass. Exact saved OI outputs now match v132 byte for
    byte at 63 bytes, and seven-pass outputs at 60 bytes. All outputs validate
    and the saved ten-call plan agrees; no fuzz ran.
85. [x] Saved retained case 29 first diverges at `local-cse`: prefixes through
    `vacuum` are 93 bytes in both tools, then Starshine/v132 become 98/95.
    Direct and active-dispatch tests failed first because Starshine cached the
    nullable base operand and repeated both ordinary casts. Outer-function
    Local CSE now materializes the first non-null cast result with its full
    nominal/exact result type; source writes remain barriers, the cast stays
    before the tee, and nested control plus descriptor/ref-as/i31 families keep
    operand replay. The focused pass suite passes 207/207. Exact seven-pass
    replay validates and returns `22289`; Starshine is now 91 raw and 92
    canonical bytes versus v132's 93/93, with Binaryen's leading `nop`
    accounting for the residual win. A null-cast runtime probe still traps.
    No fuzz ran.

### Open parity evidence from this audit

- [ ] Extend atomic conformance beyond the bounded two-worker litmus: find an
  independent runtime accepting the verified v132 Relaxed encoding; cover
  concurrent AcqRel behavior, general wait/notify liveness, memory64 addresses
  above 4 GiB, broader atomic opcodes, shared-GC families, mixed-memory layouts,
  and schedule families.
  Opt-in Chromium now executes the exact AcqRel store and fence once and
  observes the store write; this is capability evidence without a concurrent
  schedule claim. Node still rejects both weaker orders, and Relaxed order 2
  remains unsupported by every tested runtime. Node now executes one bounded
  shared-GC struct RMW topology with transferred shared references, while
  shared-function types remain a separate explicit boundary rather than a
  match.
- [ ] Classify the 557 structural mismatches in the saved seven-pass 1,000-case
  campaign; the two confirmed DCE wrong-code cases are fixed under item 73,
  while the GC runtime timeout remains separate under item 77. The historical
  size split is 503 canonically smaller, four equal, and 50 larger; only 20
  output pairs were retained. The larger families are 27 EH-control, 13
  legacy-EH local cleanup, six SIMD shape-10, two RemoveUnusedBrs switch,
  one RemoveUnusedBrs multi-function, and one constraint-loop case. Targeted
  bounded replays are active for the size-losing families. Do not infer
  semantic safety from size, validation, or instantiation-only observations.
  The six historical SIMD shape-10 rows are now closed by bounded exact-input
  replays after the OptimizeInstructions result-if repair: case 50 and siblings
  258, 410, 634, 682, and 826 are each 103 Starshine versus 112 Binaryen bytes
  in raw and canonical form. All outputs validate, and input/Starshine/Binaryen
  Node results agree for `[0, 1, -1, 42]`; the per-case vectors are recorded in
  the [OptimizeInstructions dossier](docs/wiki/binaryen/passes/optimize-instructions/fuzzing.md#2026-09-23-saved-simd-result-if-parity).
  This exact replay did not run a fuzz or aggregate campaign, so the historical
  557-case and 503/four/50 size split above remains unchanged.
  Retained legacy-EH cases 17 and 21 are byte-identical inputs (SHA-256
  `a39f36092c69354642168a59f50b8dbea6d716e4f349465c4cc84534263ac88e`),
  not two distinct residual families. Exact replay after the SimplifyLocals
  legacy-catch routing repair produces 55 raw and 55 canonical bytes for both
  Starshine and verified Binaryen 132. The raw outputs differ only in function
  type order; the canonical outputs are byte-identical with SHA-256
  `97e045e447bb651e96b3e90cce3642420e615b00d2aff68d68fa770e8b308390`.
  All raw and canonical files validate, and original/Starshine/Binaryen each
  return `[0, 1, -1, -2147483648, 2147483647]` from `run(i32) -> i32` for that
  same argument vector. This bounded two-file replay ran no aggregate or fuzz
  campaign and leaves the historical 557-case and 503/four/50 split unchanged.
  Retained case 29 is now closed under item 85. Every exact artifact returns
  i32 `22289`, with no state. Starshine's repaired Local CSE output is 91 raw
  and 92 canonical bytes versus verified v132's 93/93; both use one exact cast
  result local, while Binaryen retains a leading `nop`.
- [ ] Reduce the 128 EH/Vacuum structural differences in the existing 256-case
  campaign, alongside the dedicated Vacuum backlog slice below. Layouts `1`
  and `7` account for 64 historical rows and are source-backed canonical
  projection wins, while Binaryen remains smaller in raw bytes. Ten retained
  exact modules (50 input/output variants) validate and execute identically
  under Node and Wasmtime; the other 54 have only saved size/status rows.
  Layouts `3` and `6` account for the other 64 rows; the two retained
  representatives now match verified v132 canonical bytes after
  null-`throw_ref` wrapper cleanup. Keep the aggregate open because no new
  256-case comparison was run under the no-fuzz constraint. See the
  [Vacuum dossier](docs/wiki/binaryen/passes/vacuum/fuzzing.md#september-23-binaryen-132-eh-structural-campaign).

## v0.1.1 — EH Vacuum parity on new GenValid control shapes [IR2-PARITY]

- **Goal / why:** the September 22 `campaign-eh-control` / `vacuum` comparison
  against verified Binaryen 132 compared 256 valid modules but found 128 raw
  mismatches across four of eight layouts. Sixty-four cases are canonically
  larger in Starshine, sixty-four are smaller, and 128 are equal. Independent
  output validation and the existing cleanup normalizers do not classify the
  differences as a Starshine win.
- **Deliverables / tasks:** reduce one case from each mismatch layout (seed
  indices modulo eight: 1, 3, 6, 7), add red-first Vacuum behavior/IR tests,
  prove EH trap and catch semantics, then align the size-losing shapes to the
  Binaryen output or document a measured Starshine benefit without an important
  regression. Keep the new profile in `random-all-profiles` so the gap remains
  exercised.
- **Required APIs / invariants:** every transform produces valid wasm and
  preserves `try_table`, `catch_ref`, and `throw_ref` behavior; validation alone
  does not establish semantic parity or justify a size loss.
- **Dependencies / exit:** artifacts under
  `.tmp/pass-fuzz-campaign-eh-control-vacuum-256/`; finish with a fresh
  verified-v132 10,000-case dedicated comparison and no unclassified residuals.
- **Suggested tests:** exact EH body instructions for representative cases 1,
  3, 6, and 7, plus runtime replay for catch and trap behavior where callable.

## v0.1.1 — narrow the host-visible function identity guard [IR2-SAFETY]

- **Goal / why:** the September 22 [eight-agent audit](docs/wiki/ir2/architecture-rules.md#september-22-eight-agent-pass-safety-audit)
  showed that direct duplicate-import and duplicate-function elimination alter
  JS-visible import lookup count and exported function identity. Presets now
  conservatively skip DFE on modules with imports or exports and skip DIE on
  modules with function imports. Direct DFE now protects exported functions;
  address-taken internal identities remain under investigation in item 71.
  This broad gate can forgo useful internal-function merges.
- **Deliverables / tasks:** measure the preset size/performance cost and design
  protected-function escape analysis so presets can merge internal functions
  while preserving identities that reach exports, tables, globals, imported
  callbacks, or other host-visible surfaces. Keep getter and exported-identity
  runtime regressions in `tests/optimizer/regressions/host-identity.test.ts`.
- **Required APIs / invariants:** no implicit preset may collapse distinct
  host-observable function references or same-name imported function lookups;
  direct DFE/DIE must preserve host semantics even where Binaryen 132 merges
  observable identities; record any remaining output-shape parity gaps.
- **Dependencies / exit:** focused runtime and Moon tests, explicit v132
  comparison of changed preset output, measured size/performance deltas, and a
  sound exposure proof for any narrowed guard.

## v0.1.1 — audit verification follow-ups [IR2-PARITY]

### Resume checkpoint — September 15, user-requested usage pause

**Updated September 16:** the pause was resumed, the three saved red cases and
four subsequent ordinary OI families and two further size families are fixed;
the user-authorized fuzz renewal is complete. Do not restart the audit. Durable repair history and the
full current evidence live in the [size follow-up report](docs/wiki/ir2/architecture-rules.md#september-16-further-oi-size-reductions).

- **Workflow:** original five agents report only; root alone writes tests,
  edits, runs compilers/runtimes and commits. Serialize Moon commands. The user
  waived the commit skill and requested individual fix commits.
- **Current source:** `48a37ed54` admits index-free `i32.add` to bounded type
  cleanup; `8e6ad179a` drops declaration-only elements after the last `ref.func`
  use disappears. All six new regressions were red first; all **12,036 default
  tests pass**, plus info/fmt with no API changes. Prior fixes and test history
  remain in the [durable report](docs/wiki/ir2/architecture-rules.md#september-16-further-oi-size-reductions).
- **Fresh verification:** rebuilt command/generator binaries complete nine lanes,
  **91,020 / 92,000** comparisons, zero output-validation/command failures and
  zero canonical size losses. All 980 exclusions retain the atomic-ordering-2
  independent-validator limit. Runtime properties were off. Eight non-OI lanes
  have unchanged result counts and size totals from the prior renewal.
- **Size closures:** OI GC-aggregate losses **1,138 → 0** and call-reference
  losses **516 → 0**, saving **9,939 raw bytes** across the same 10,000 inputs.
  Every OI canonical size is unchanged and no raw size increases. Saved cases
  3 and 6 now match v132 at 91 and 53 bytes. No prior expectations were changed.
- **Remaining raw-size counts:** OI descriptors **1,090**, DAE2 continuations
  **567**, optimizing DAE2 continuations **624**, local-subtyping control
  refinalization **765**. These **3,046 observations in seven families remain
  parity gaps**. Heap2local, both global-refining and both precompute lanes have
  no raw losses in this renewal. Closures apply to the measured cohort; broader
  proposal, downstream, and runtime work remains open.
- **Latest evidence:** `.tmp/size-followup-20260916/` contains final test/build
  logs, `size-followup-fuzz/`, `size-followup-summary.json`, paired input/size
  comparisons, source/binary hashes, and `verification-audit.json` with per-lane
  cache and selected-profile counts. Preserve the earlier evidence below.

#### Next cases, one fix and commit at a time

1. **OI descriptor encoding:** inspect descriptor37 type residue, descriptor27
   producer/result structure, and descriptor52/74 exact-null encoding. Use fresh outputs before extending
   cleanup. A complete type-reference remapper is required for proposal graphs;
   do not widen simple-type guards blindly. Saved fixture repairs are complete.
2. **Continuation encoding:** DAE2 case15 and related continuation graphs still
   retain raw overhead. Complete continuation reference traversal/remapping
   before pruning or interning these types. Expression-form declarative element
   compaction is a separate possible step. Preserve existing handler semantics.
3. **Local-subtyping control refinalization:** cases23/35/36 represent the
   remaining 765 outputs, each +3 raw bytes and −1 canonical byte. Inspect the
   representation and prove a net benefit or remove the raw overhead.
4. **Broader existing parity work:** code-pushing's 513 `br-if-value` cases
   (+2,052 canonical bytes), simplify-locals-nostructure's 1,662 tee-control cases
   (+16,636), and 30 trap-relaxed OI `direct-tiny-bulk` cases (+300) were outside
   this renewal. Preserve unsampled tuple/downstream work; saved OI tuple196
   already has a separate 70/70-byte common-Oz proof. The current run does not
   establish universal downstream or runtime equivalence.
5. **Runtime/validator limits:** twelve original-and-output SSA nontermination
   fixtures remain outside runtime signoff. Never execute the known Node
   resume-throw crash fixture or use these SSA fixtures as runtime probes.
   Separate terminating fixtures are required. Preserve raw compact-import
   policy, name-metadata size gaps and atomic independent-validator limits.
   Eleven reorder blockers already have matching portable-encoding initialization
   observations; four top-level suspend cases and the continuation interpreter
   check have their recorded engine-specific evidence. Do not relabel the
   historical raw engine failures.

#### Evidence and resume requirements

- **Goal / why:** close remaining raw/canonical size gaps and unsupported
  validation/runtime boundaries without weakening completed correctness fixes.
- **Deliverables / APIs:** bounded red-first pass and dispatcher regressions;
  complete reference/index and name remappers for any newly admitted proposal
  surface; individual fixes; fresh affected-pass comparison and explicit
  agent classifications of residual families.
- **Invariants:** valid Wasm; preserved traps, producer order, local/global
  effects, lexical labels, touched-function scope, imported-tag alias priority,
  names and recursive type identity. Size or validation alone does not prove
  semantic equivalence. Keep original source/tool-version evidence intact.
- **Dependencies / exit:** compatible independent validation and bounded runtime
  adapters; passing default tests/API review; ≥10,000 comparisons per affected
  aggregate after later code changes; no unproven size losses in the scoped
  family. Rebuild native binaries after any further compiler edit.
- **Suggested tests:** the saved source fixtures and label-name/import controls;
  terminating control-refinalization probes; complete continuation/index-use
  coverage; prior audit tee-control and `br-if-value` fixtures.

All local paths below are under `.tmp/pass-audit-20260915/` unless absolute.

- `oi-residual-final-test.log`, `oi-residual-final-info.log`, and
  `oi-residual-final-fmt.log`: final default checks. `oi-residual-*-green.log`
  and `oi-residual-all-oi-tests.log`: focused evidence. The initial failing full
  run remains `oi-residual-full-test.log`.
- `parity-renewal-2-fuzz/`: nine completed lanes with commands, toolchains, cases,
  retained diffs and results. `parity-renewal-2-summary.json`: all 98 residual/
  status groups. `oi-residual-saved-case-renewal.json`: five unchanged input
  hashes and before/after sizes. `parity-renewal-2-input-exclusions.json`: the
  identical 70-byte excluded input and validator error in both precompute lanes.
- `parity-renewal-2-binaries.json` and `parity-renewal-2-source.json`: fresh native
  hashes, paths, timestamps and source identity. `run-parity-renewal-2.py` has
  **completed**; preserve its output root and use a new root for later runs.
  Verified v132 oracle remains `.tmp/binaryen-version_132/bin/wasm-opt`, SHA-256
  `1014958e6f20d412f1542320b43970214b0fb1ed780595e8f7c0d8761ed53725`.
- Historical `final-fuzz/` (151,020 comparisons), `parity-final-fuzz/` (80,000),
  `parity-directed-size/`, `parity-raw-residual-review/`, static-review JSON,
  `difference-report/`, and runtime renewal roots remain unchanged. Their
  binaries are historical, and their counts must not be relabeled as current.
- Earlier audit contracts and unresolved families remain in the
  [difference inventory](docs/wiki/ir2/architecture-rules.md#september-15-complete-difference-inventory-and-regression-handoff),
  [fourth audit](docs/wiki/ir2/architecture-rules.md#september-14-fourth-correctness-audit),
  [runtime review](docs/wiki/ir2/architecture-rules.md#runtime-review-and-remaining-parity-work),
  and [SSA static proof](docs/wiki/ir2/architecture-rules.md#ssa-timeout-and-local-declaration-difference-review).

## v0.1.1 — catch labels, fact operands, function exits [IR2-CORRECTNESS]

- **Goal / why:** retain regression guards for catch destinations, actual stack operand identities, and implicit function-label result liveness. Starting master: `e53ec910e5ccc9d8f43342c2b598d29ff30d81ba`.
- **Delivered:** `3967d7585` preserves all try_table catch targets; `3fd6df3df` tracks compiler-fact producers by stack/result lane; `3f3ecdc69` observes DAE2 function exits. All 92 execution checks pass after failing-first regressions (24 catch failures, 15 fact wrong results, 14 DAE2 aborts). `84d2ab3bf` adds adjacent-constant neighbors.
- **Final source verification:** 2,253 focused, 11,300 full wasm-gc, 11,303 full default, 65 harness, 175 execution/performance tests, 3,773 smoke attempts, and 1,000/1,000 Dewdrop replay pass. Info/fmt/check/API-sync pass; no public API change. All 800 saved and 30,000 dedicated generated outputs validate, with unchanged baseline comparison classifications.
- **Bounded semantic verification:** all 300 sampled cases now have execution evidence: 299 under the recorded Node settings and closed DAE2 case 15 under verified Binaryen 132 `wasm-shell`. The unchanged original, Starshine and Binaryen binaries on both revisions all raise the expected uncaught Wasm exception. The Node engine failure remains recorded separately; no Node report is reclassified as passing. See the durable verification for the explicit alternate-engine regression and limits.
- **Separate follow-up:** numeric implicit function-label references are rejected by the WAT reader; the name-section decoder reads into a following custom section. These frontend defects remain outside the three optimizer repairs. Existing DAE2 output-shape gaps (6,454 open / 9,900 closed) and 644 saved-lane differences remain parity work, not confirmed semantic defects.
- **Invariants / exit:** trusted facts attach only to actual result lanes; function exits observe result locations; all assertions remain enabled. The continuation check uses the unchanged binary fixture and distinguishes uncaught exceptions from traps and normal returns.
- **Evidence / tests:** [durable verification](docs/wiki/ir2/architecture-rules.md#september-12-stack-operands-and-label-destinations); exact commands, hashes and logs under `.tmp/three-correctness-20260912/`.

## v0.1.1 — Dewdrop correctness regression guards [IR2-CORRECTNESS]

- **Goal / why:** retain the reduced transformation, metadata, analysis and
  termination regression guards for the verified Dewdrop pipeline.
- **Checkpoint:** starting master `93f11e3b7` reproduced 38/1,000 replay failures
  and 56 full-suite failures. All confirmed implementation causes have reduced
  regressions. The final enclosing-exit SSA repair is `fbd1936d8`: focused
  IR/direct-pass 2,170/2,170, harness 65/65, full wasm-gc 11,295/11,295,
  and plain default-backend tests 11,298/11,298 pass on this source.
  Shared default-backend opcode-counter resource growth is repaired. Durable
  causes and regressions are in [correctness follow-up](docs/wiki/ir2/architecture-rules.md#september-12-correctness-follow-up).
- **Final verification:** fresh release execution/performance 83 tests / 171
  probes, smoke 3,773 attempts, and all 800 generated outputs validate.
  The historical strict-message replay is 997/1,000 with no new failures.
  Its three comparison failures are superseded by the corrected expectation
  contract below; the original reports remain in
  `.tmp/correctness-repair-20260911/verified-*`.
- **Trap expectation correction:** the user selected Binaryen behavior.
  Dewdrop commit `5eccd72f` adds two explicit optimized-output expectations for
  the three formerly failing comparisons. Baseline checks stay exact; changed
  effects, other traps, unrelated fixtures and engine failures still fail.
  All 10 harness tests pass after failing-first regressions, and the normal
  runner passes both fixtures under O4z and optimizing inlining in Node/Wago.
- **Corrected final verification:** all 1,000 current cases pass against the
  same policy that leaves 35 implementation failures on the starting baseline
  (965/1,000). All optimized binaries match the prior strict-message replay;
  six observations use the two explicit expectations. Fresh focused tests,
  both harness suites, both full suites, execution/performance, smoke and the
  eight saved generated lanes pass their applicable checks. No correctness
  failure or blocked check remains in the reproduced corpus. Exact evidence:
  `.tmp/trap-diagnostics-20260912/` and [verification](docs/wiki/ir2/architecture-rules.md#binaryen-trap-expectation-correction).
- **Separate parity follow-up:** ten SSA fixture size differences remain open
  (typed loop proxies, reference/cast lowering, branch-table cleanup). They are
  not confirmed execution defects. See [SSA evidence](docs/wiki/binaryen/passes/ssa-nomerge/merge-shapes-and-canonical-slots.md#september-12-baseline-expectation-resolution).
- **APIs / dependencies / invariants:** LocalGraph and CFG preserve repeated
  edges, canonical merge slots and source evaluation order; loop inputs retain
  branch arity; reference types retain canonical recursive-group identity.
  Keep all assertions and external validation enabled.
- **Exit / suggested tests:** no unexplained original/optimized behavior
  difference; bounded optimization on saved abort/timeout shapes; final focused,
  harness, smoke, full-suite and replay evidence on the final code revision.
  Exact commands and artifacts are in `.tmp/correctness-repair-20260911/`.

## Scope And Rules

- Keep only active unreleased work, standing regression guards, or explicitly deferred future work. Durable closeout evidence belongs in pass dossiers and `docs/wiki/log.md`, not here.
- Preserve Binaryen v131's locked 56-slot O4z order plus Starshine-only `strip-debug` at slot 57.
- New comparisons use `.tmp/binaryen-version_132/bin/wasm-opt`, reporting version 132 with SHA-256 `1014958e6f20d412f1542320b43970214b0fb1ed780595e8f7c0d8761ed53725`. Explicit v131 binaries are only for historical replay.
- Build the native CLI before artifact lanes and use `_build/native/release/build/cmd/cmd.exe`; treat `target/native/...` as stale unless explicitly proven fresh.
- Validation and runtime execution are separate gates. A validating artifact is not signed off until its runtime smoke is green.
- Direct pass behavior comes before scheduler integration; artifact/runtime signoff comes last.
- Moon commands must run serially.

All new comparisons and acceptance reruns in this backlog target verified Binaryen 132. Older version labels attached to recorded measurements, artifacts and source ledgers remain historical evidence.

## Current Pipeline Facts

- Dewdrop correctness status is tracked in [IR2-CORRECTNESS] above. Earlier
  wave-13 through wave-25 failure counts are historical evidence in the wiki;
  they do not describe the repaired current source.

- Dewdrop pipeline screen (2026-09-10): the aliased-counter SLNS hang, four
  additional SLNS local-lifetime/branch-join faults, and the fixed-array
  CodeFolding failure are repaired with executable regressions. All 410 source
  runtime fixtures pass under six candidate schedules in Node and Wago.
  Wago-only follow-up: `remove-unused-brs` introduces typed `select` on
  `modules/imported-generic-callback-adapter-runtime`. A reduced module that
  selects the same struct reference for both arms, then checks `ref.eq`, fails
  in Wago and passes in Node with no optimizer involved. This is a runtime
  defect, not evidence of an incorrect RemoveUnusedBrs transform. Dewdrop
  retains `tools/starshine-experiments/testdata/wago-typed-select.wat`; exclude
  this schedule from its cross-engine speed profile until the runtime repair
  in https://github.com/wago-org/wago/pull/600 is available in its Wago checkout.
  The SLNS dedicated comparison still has older output/parity gaps; keep its
  broader audit open and do not treat validation or fewer bytes as runtime proof.

- Public non-O4z presets are intentionally wall-time-first. O1/O2 run `duplicate-function-elimination -> strip-debug`; O3/O4/Os/Oz add only `vacuum -> reorder-locals` between those slots. The CLI accepts literal Binaryen-style `-Os` as `(optimize=2, shrink=1)` and `-Oz` as `(2,2)`.
- O4z remains the full compatibility lane: Binaryen v131's exact 56 top-level slots plus Starshine-only `strip-debug` at slot 57. The following 18-pass Starshine local-convergence suffix remains available below 2,000 defined functions, but is skipped as one unit at artifact scale after an August 22 production A/B showed it was both 60.285 seconds slower and 25,152 bytes larger.
- Direct passes remain available, and DAE, optimizing inlining, and SGO retain the full level/feature-aware nested function scheduler. DAE prepends `precompute-propagate`; SGO's touched-function nested roster does not. Separately, SGO owns a bounded transactional final suffix that starts with `precompute-propagate`.
- Nested cleanup remains touched-function-scoped. SGO's former 192-local / 1,000-instruction broad filter is removed. After SGO changes a module, the `<1000`-definition final transaction runs propagation, safe block merging, live-out-aware SimplifyLocals, branch cleanup, bounded coalescing, and final linear cleanup, then commits only a valid strictly smaller encoding.
- Large typed-loop modules currently use focused fail-closed owner fallbacks where production smoke exposed path-sensitive gaps: DAE optimizing now uses the same bounded safe batch at every optimization level, admitting unread and uniform-literal parameters only when the callee and every direct caller are parameterized-loop-disjoint, then converging dropped results atomically and applying optimizing-only graph-indexed exact `i32.const; drop` and `local.set/get -> local.tee` cleanup, 384-local SimplifyLocals, 32-512-local coalescing, and 128-local reorder cleanup; guarded call/bulk-memory optimizing inlining runs plain shrinking-trivial admission plus the default two-instruction always-inline ceiling and a four-instruction one-caller ceiling, while the flexible threshold stays zero; SGO no-ops; and flatten/merge-locals no-op in the affected large-module neighborhood. SimplifyLocals, TupleOptimization, DCE, Precompute, CodePushing, CoalesceLocals, CodeFolding, SSA, and OptimizeInstructions retain focused shape or guarded-writeback boundaries for reduced validation and runtime families.
- Optimizer registry/tracker/execution/release-horizon documentation has been reconciled with the live scheduler and registry.
- Current production O4z correctness evidence is green on native SHA-256 `d7921ee49c6781c10f3388e7f594dd67445587d767ef4db3d37107045e93886b`: all `105/105` `json-as` outputs optimize and externally validate, exact four-worker runtime passes `105/105`, and aggregate output remains `26,228,860` bytes from `29,604,717` input bytes. The final pass-local safety renewal compares 10,000 regular GenValid cases each for RemoveUnusedBrs, OptimizeInstructions, PrecomputePropagate, and CoalesceLocals with their reviewed cleanup normalizers; all four have zero residual mismatches/failures and zero canonical size losses. PrecomputePropagate now removes exact redundant void `(block (br 0))` shells after real propagation instead of retaining 1,025 size-losing cases.
- Current-source self-optimized CLI evidence is green on native SHA-256 `d7921ee49c6781c10f3388e7f594dd67445587d767ef4db3d37107045e93886b`; the rebuilt self artifact is `4,912,326` bytes with SHA-256 `93163197f0caa2fe90154f684f306fd8d1c76bdb8d3dfb8ca499bd4c6b11f84c`. `self-opt-smoke` passes, full self-optimized spec is `284` total / `87` passed / `197` known skips / `0` failed, native/self optimizer output is byte-identical on the default fixture, json-as is `105/105` optimization/validation/runtime, and the exact WAGO manifest is 48/48 native/self optimization and validation, 323/323 calls per variant, and 48/48 output identity. The recursive-group implicit type and command-10 canonical-equivalence gaps in `type-rec.wast` are repaired rather than newly allowlisted.
- Current-source self-optimized CLI evidence is green after the August 25 OptimizeInstructions repair. Native self-optimization prefix 35 remained optimizer-capable, prefix 36 `optimize-instructions` trapped while optimizing pinned `naive/bool`, and hybridization across 464 changed bodies isolated absolute function 6695. Its original body carried several memory loads across same-base release calls; the indexed effect fact missed the flat relation, so a benign OI mutation forced HOT lowering that moved those loads after effectful calls and moved five releases before the call that still consumed their values. The original-body `run_hot_pipeline_raw_has_load_before_same_local_call` proof now short-circuits OI before descriptor bridges or HOT lift. Rebuilt debug/release/self-optimized artifacts are `14,544,998` / `5,362,893` / `4,854,334` bytes; self SHA-256 is `26888dccfced3f805f2067e0f261ffa7672bf4f187e159b17fc122ecf7c6ea38`. The self artifact validates, exits zero for `--help`, `--version`, and `spec tests/spec/address.wast`, optimizes pinned `naive/bool` successfully, emits bytes identical to native O4z, and that output passes exact WASI startup.
- Historical self-opt artifact-comparison evidence is green on the retained August 12 source checkpoint: debug artifact `13,770,560` bytes, release artifact `5,068,591` bytes, and self-optimized CLI `5,014,671` bytes. Native and rebuilt self-optimized-Wasm optimizers emit byte-identical output SHA-256 `4e17218bcb9bf42ac8f813333dd1dff395597363d39b3190bd8c7d0c9cc4bf00`; Node/WASI smoke passes, self-opt task tests are `16/16`, recursive full spec is `284` total / `64` passed / `220` intentionally skipped / `0` failed, and `bun validate full --profile ci --target wasm-gc` passes including `86,820` binary roundtrips. The August 14 review refresh is **not** green: native SHA-256 `165611733d7536f4b853c2642414e6ce213e0c0a39d164aed11326d910ebd78d` optimizes and externally validates `105/105` O4z corpus modules (`20,182,554` bytes), but exact WIPC reports `0` pass / `102` fail / `3` timeout. All corpus inputs have fewer than 2,000 defined functions (maximum `1,551`), and final native SHA-256 `da005c82e948716b16ec7ff90d07db41d2737ae56240ed85a88867858f6b5dc0` reproduces the retained naive `bool` output byte-for-byte at SHA-256 `0a927586f0f6c5936b0236b0b88c6e8c4632dceb240d915225daeebdb930efee`; the artifact-scale CFG performance guard therefore does not alter the corpus result. An isolated clean-HEAD build produces those same failing `bool` bytes, so the runtime blocker predates the three original August 14 review fixes. The self-opt build is now bounded and completes in `330` seconds end to end instead of running for hours: debug/release/self-optimized artifacts are `13,841,184` / `5,095,702` / `4,672,918` bytes, and self-optimized SHA-256 `fa002f6f3720d4622a6866ef27849e6e90237928fa790c2b33e9a5d9b3113dae` is produced from the release artifact through compact phase tracing. It still traps with an out-of-bounds memory access on `--help`, now through Wasm functions `28`, `32`, `34`, `56`, `617`, `597`, `596`, and `9788`; full spec and optimizer-capability execution remain blocked. Full Moon is `10,412/10,412`, and the final wasm-gc CI profile remains green. Dedicated direct SimplifyLocals evidence is `10000/10000` with `5000` normalized matches and `5000` inspected deterministic residuals: `3125` fourteen-byte canonical Starshine wins from `simplify-locals-family-coverage`, plus `1875` existing structure-result output-shape gaps where Starshine is `2..4` bytes larger because it retains one `nop` per generated function; aggregate canonical delta remains `-38,135`, with zero failures. The refreshed SGO aggregate is `5055` normalized plus `4945` inspected smaller-output residuals (`1427` nested-cleanup and `2127` read-only-to-write one-byte wins plus `1391` three-byte retained initializer aliases, `-7727` aggregate), with zero validation/property/generator/command failures.
- The remaining 303 corpus `call; drop` pairs are classified and no longer an unscoped DAE target: 105 call imported result functions, while 198 target 159 private defined callees that all have mixed direct observers. There are no private all-direct-dropped, exported, or `ref.func`-escaped residual callees. Further recovery must specialize dropped callsites or inline without changing the shared callee boundary. The refreshed dedicated DAEO lane is `10000/10000`, with `6954` normalized matches, `3046` inspected source-backed smaller-output residuals (`-37,910` raw/canonical aggregate), and zero validation/generator/property/command failures.

- The broad WAGO semantic audit remains closed for confirmed Starshine-specific wrong code on final native SHA-256 `d7921ee49c6781c10f3388e7f594dd67445587d767ef4db3d37107045e93886b`: 842/842 inputs validate, 813 outputs optimize and independently validate, 2,406 probes include 2,144 completed and 206 unsupported signatures, baseline timeouts are 13, candidate/combined timeouts and probe errors are zero, and 10,721/10,935 vectors match exactly. The same 43 previously classified raw probes remain, with no additions. Typed-reference observation, trap-detail/import-inventory, runtime-feature, and Binaryen/NaN-payload classifications remain unchanged; no confirmed core wrong-code probe remains.

## v0.2.0 Binaryen 132 Upgrade

### [IR2-V132] U01–U09 — Released comparison and compatibility upgrade

- **Goal / why:** compare against Binaryen 132 and implement its applicable shared correctness, format and optimizer changes without rewriting historical v131 evidence.
- **Deliverables / tasks:** [U01–U10 contracts and exact ledger](docs/wiki/binaryen/version-132-upgrade.md); verified v132 CI/performance/fuzz oracle; compact imports; relaxed atomic order/effects/Precompute; descriptor/effect lifecycle audit; real DAE2 and opt-in constraint analysis; gated proposal intake and measured integration.
- **Required APIs / invariants:** ordered logical imports, distinct atomic capabilities, shared directional effects, revision-owned analysis, deterministic module signature remapping, HOT verification and valid lowering. Unknown effects or unfinished proofs never become permission to optimize.
- **Dependencies:** U01 → U02/U03 → U04 → U06 → U07 → U09; U05/U08 gate their feature tracks. Optional U10 does not block core work.
- **Exit criteria / suggested tests:** exact byte/text roundtrips, descriptor/bottom/unreachable fixtures, effect-motion matrix, parameter/result cycles and open-world tail calls, constraint joins/wraparound/tees/convergence, 10,000-case GenValid direct lanes with verified v132, independent runtime and fixed-corpus quality evidence.
- **Implemented:** v132 oracle defaults and CI/performance pins; exact 59-commit/220-file inventory and 83-path test intake; both compact import forms and opt-in writer; Relaxed core/codec/struct-WAST/HOT support; directional HSO effects; precompute guards and descriptor regression intake; generated component constructor.
- **Completed evidence:** 11,127 default wasm-gc tests pass at the renew10 source checkpoint. Ten renewed 10,000-case aggregates and 304 upstream world/module structural cases have zero validation/generator/command/property/observed-semantic failures at the `renew5` checkpoint. The `0fc56270…` optimized compilers pass both validators, startup and five functional probes. These supersede the earlier tuple/loop execution blockers; exact versions and counters remain in the [upgrade evidence](docs/wiki/binaryen/version-132-upgrade.md).
- **U03 descriptors:** exact source/target validation and both descriptor branch text polarities are implemented. Precise bottom-result/local refinement now passes focused tests, including a borrowed-payload double-evaluation regression. Renew the expanded descriptor profile and cross-pass validity/opportunity checks.
- **U05 atomic orders:** all three orders have complete linear/GC store carriers, feature gates and generated component APIs. New HOT fence support repairs the 37/192 DAE2 command-failure family; HSO fresh atomic stores and OI shared RMW/order guards have red-to-green tests. Rebuild and run the expanded `binaryen132-atomic-orders` profile at 10,000 cases; classify residual fence/atomic output differences and preserve directional motion tests.
- **U06 DAE2:** real 14-family aggregate, fixed-point solver and post-tag #8994 are implemented. Reduce the legacy exception size loss and optimizing cleanup gaps, then renew open/closed/optimizing comparisons and fixed-corpus cost. Preserve result/parameter cycles, effects, tuple lane materialization and continuation restrictions.
- **Native renewal:** master includes 51 remote commits through `5f74d54b1`. The final source passes **11,228/11,228** default wasm-gc tests; renew25 passes full CI fuzz (86,820 binary roundtrips), component and README checks. Native `766c3e35…` / GenValid `51e052ad…` complete three 10,000-case local-lifetime lanes with zero runtime/validation/property failures, bringing renew21–25 to 32 completed dedicated lanes. Latest compiler outputs pass startup and 20 functional invocations; 52 explicit Node and 304 upstream structural cases pass. Scratch-local compaction, adjacent capture folding and DAE2 signature reuse pass focused source tests but need a fresh native build. Keep earlier failures and source hashes in the validation ledger.
- **U07 constraints:** real 12-family aggregate and integer/reference solver are implemented. Compact predicate-relevant local state, sparse evaluation cache and lowering cleanup pass focused regressions. Renew native functional probes, 10,000-case comparison and performance after these changes; keep nested-handler CFG precision visible as an opportunity gap.
- **U04/U08 boundaries:** compact item names and forward type references pass the new mapping regression; Binaryen’s per-item parser-position table has no direct equivalent in Starshine’s expanded AST. Public source spans remain an older tooling gap. Compact, waitqueue and multibyte profiles each have 10,000 structural matches but explicit runtime exclusions. Finish broader descriptor/module-remap cases and U09 quality/cost integration. Do not claim independent execution for unavailable proposal runtimes.
- **Measured risk:** exploratory compiler CA improved from roughly 71 to 11 seconds after relevant-local compaction; DAE2 now takes 7.53 seconds and 441 MiB; Binaryen takes 0.51 seconds / 270 MiB on the same input, with different output size. These were non-isolated diagnostic runs. The earlier 1,000-read Precompute/Propagation probe is subsecond but approximately 10.6×/11.4× upstream pass time. U09 requires isolated measurements and classified gaps.
- **Latest source renewal:** all 11,210 default wasm-gc tests, the full CI fuzz gate (86,820 binary roundtrips), component bindings/artifact checks and 256 Bun library tests pass. Native `91301a24…` passes 37 actual Node lifetime comparisons and 304 selected upstream structural checks. Renew21/22 complete 24 separate 10,000-case campaigns without validation/generator/command/property failures; three ordinary shared-pass lanes are structural checks, with runtime evidence separate. The 262-case SSA runtime partial has 241 matches and 21 whole-worker timeouts; a generated loop assigns 1 before every backedge, so no termination or runtime parity is inferred. The timeout envelope does not identify the execution phase. Runtime cache/resume distinguishes Bun/JavaScriptCore from actual Node.
- **Current cleanup renewal:** continuation Vacuum has 10,000 canonical matches, and DAE2 optimizing closes all 199 continuation/tuple cleanup size losses. The 730 legacy handler cases remain a concrete HOT representation gap. Tuple and CA capture losses are repaired; descriptor size differences remain open. The constant-tee OI regression and named-tuple label repair pass focused/default/full gates; fresh native compiler and GenValid builds and their dedicated renewals are running. WAST continuation text grammar remains an older explicit boundary.
- **Compiler lifetime renewal:** renew25 preserves definitions across older carried reads and bounds inferred lowering dependencies by their consumer. Native `766c3e35…` closes startup, passes all 20 compiler-functional invocations, 52 Node lifetime checks and 304 upstream structural cases. Renew25 full gate and three 10,000-case `dae2-locals` lanes pass; renew26 adds a 10,000-case `simplify-locals-all` structural lane with zero validation/property failures. The final source passes 41 DAE2, 363 SimplifyLocals, 14 command and 11,228 full default tests. Remaining work: build a fresh native CLI; rerun DAE2 open/closed/optimizing, constraint-analysis, atomic, descriptor, tuple/OI and SimplifyLocals aggregates at 10,000 cases; classify every residual; rerun 58 explicit Node lifetime checks and optimized-compiler startup/function probes; run the full CI/component/README gate; and collect isolated paired DAE2/constraint/DAE2-optimizing performance. Preserve the 730 legacy multi-handler DAE2 representation gap and descriptor size gaps as open until implemented or measured as wins. Artifacts: `.tmp/binaryen132-renew23-self/functional.json`, `sl-bisect.json`, and `cleanup-stages.json`.
- **Validation contract:** serialize Moon commands; the default linear-wasm target exceeds V8's per-function local limit in the existing generated validator, so use the repository wasm-gc lane. Proposal campaigns explicitly select Binaryen primary validation where wasm-tools rejects the released draft; this is not independent proposal validation. Existing release/runtime blockers below remain active.

## v0.1.1 Execution Order

1. Use the completed `[WALL]001` attribution and bracketed sweep runner so every slow-pass item separates pass-local work from command-envelope cost.
2. Execute `[SIZE]001` together with the overlapping performance items: CoalesceLocals correctness first; SimplifyLocals with `[PERF-SLNS]001`; optimizing inlining with `[PERF-INL-OPT]001`; then DAE with `[PERF-DAE]001` and `[PERF-DAEO]001`.
3. Continue plain inlining's narrowly open pass-local gate, then revisit only performance items whose current bracketed evidence exceeds its declared threshold; CodeFolding, RemoveUnusedBrs, Precompute, and PrecomputePropagation are closed.
4. Run `[JSON-AS]001`, `[TOOL]001`, and `[STRIP-DEBUG]001` final release evidence.
5. Revisit focused startup fallbacks only with smaller regressions and runtime proof.

## v0.1.1 Pipeline Supporting Work

### [SEMANTIC-OPT]001 - Complete semantic optimizer campaign integration

- **Goal:** make original-primary observation-v2 evidence a routine optimizer signoff lane rather than only a bounded compare-pass option.
- **Implemented:** Node worker execution, MoonBit-decoded runtime-interface reporting, module-aware expanded pass-queue reporting and all-prefix localization, Moon-owned resolved threshold reporting, production native-interface consumption, typed imports/values, full in-cap memory and table/global state, three-way diagnostics, semantic idempotence, convergence, production pass commutators, emitted deterministic GenValid base/twin records, production metamorphic equivalence, exact fingerprints with expanded repeated pass sequences, exact deterministic semantic byte reduction, exact replay/`wasm-reduce` predicates, v2 replay/corpus promotion, curated semantic seeds, threshold listing, live integer proofs, focused tests, and bounded component CI.
- **Completed August 29, 2026:** dedicated semantic effects/import-event/trap/resource profiles and floors; exact-first explicit family relaxation; whole-Wasm `explore-optimizer-repro`; bounded semantic journals and full semantic/property/cache resume; v128 import/export adapters, imported tags, nullable GC references, and immutable cross-table identity; pinned wasm-tools/Binaryen/Z3 CI; fail-closed `--require-binaryen-version 131` admission with executable hashing and resume identity checks; observation-v2 stage timings; prebuilt `--gen-valid-bin` campaign startup; artifact-budgeted structural reduction and reduction-free broad semantic CI; Vacuum level-zero, `memory.size`, pure result-`if`, and self-branch dropped-value cleanup; live Z3/threshold evidence; 10,000 original-primary semantic/idempotence/convergence/commutator/metamorphic comparisons; regular GenValid, wasm-smith, vacuum-owned, and random-all pass campaigns.
- **Remaining acceptance blockers:** rerun the full semantic campaign with explicit Binaryen v132 rather than the accidental PATH v116 diagnostic used by the 10,000-case aggregate, and rerun the historical 10,000-case random-all Vacuum lane after the accumulated fixes rather than carrying forward its 1,239 stale gaps. The fresh locked-v131 semantic/property/commutator/metamorphic matrix is `16/16` throughout. The current explicit-v131 samples have zero canonically larger cases: `42/58/0` smaller/equal/larger at 100 cases and `395/605/0` at 1,000 cases, totaling `136,075` Starshine bytes versus Binaryen's `137,630`. The final no-throw `try_table` family is closed through an owner-block-only proof while implicit-function-label catches remain preserved. Dynamically mutated cross-table identity and non-null `exnref`/`contref` stay intentionally blocked host boundaries.
- **Invariants:** the original is primary; Binaryen agreement never excuses Starshine; incomplete observation is blocked; structural idempotence/composition and v1 readers keep their meanings; preset order stays unchanged and new evidence requires Binaryen 132; long randomized lanes remain outside default `moon test`.
- **Exit criteria:** all machine-readable reports have one MoonBit source of truth where applicable, generated semantic profiles meet their feature floors, replay/reduction preserves fingerprints, CI smoke/profile lanes are green, and required deterministic campaigns report zero true semantic mismatches with explicit blocked/tool counts.

### [REVIEW-20260822]001 - Refresh final22 after correctness and compile-time repairs

- **Implemented:** the ifs streaming XOR fold now requires the complete `i32.const 1; i32.and; i32.const 1; i32.xor` suffix, with masks `2`, `3`, `-1`, dynamic-RHS, and evaluated-result regressions. Constant-expression validation now uses one WebAssembly-3.0-derived default-deny allowlist in globals, optional table initializers, active data/element offsets, and element payloads. O4z finish reuse consumes an explicit byte-stable canonicalizer changed bit instead of NaN-sensitive structural equality; f32/f64 NaN payload tests count zero duplicate finish invocations.
- **Current bounded evidence:** full Moon passes `10,613/10,613` after converting legacy pass fixtures to spec-valid `add`/`sub`/`mul` or literal constant expressions; `moon build --target native --release src/cmd` succeeds.
- **Remaining work:** rerun the fresh 1,330-file final22 WAGO lane and exact ifs state oracle; confirm the stable cohort size; measure the changed-bit encoding cost against the eliminated finish roster; then replace historical final22 hashes/counts only if the new artifacts differ.
- **Exit criteria:** current-source final22 replay has no wrong-code or externally invalid successes, exact stateful runtime remains equal, the stable aggregate is reported from the repaired binary, and the finish-reuse path has measured nonregressing wall time on NaN-bearing and ordinary candidates.

### [REVIEW-ARTIFACT]001 - Recover the August 14 O4z runtime gate and large-input self-hosting

- **Evidence:** native SHA-256 `165611733d7536f4b853c2642414e6ce213e0c0a39d164aed11326d910ebd78d` optimized and externally validated all `105/105` retained `json-as` modules at `20,182,554` bytes, but exact four-worker no-cache WIPC is `0/105` with `102` exit-1 failures and `3` timeouts. All 105 inputs remain below the artifact-scale boundaries (maximum `1,551` defined functions), and native SHA-256 `da005c82e948716b16ec7ff90d07db41d2737ae56240ed85a88867858f6b5dc0` reproduced the retained naive `bool` artifact byte-for-byte at SHA-256 `0a927586f0f6c5936b0236b0b88c6e8c4632dceb240d915225daeebdb930efee`. The same bytes and failure reproduce from an isolated clean `HEAD` build, proving the WIPC issue predates the August 14 CFG, metadata, WAST harness, and timeout/performance fixes.
- **Recovered self-opt evidence:** the August 23 bisection first repaired raw SimplifyLocals function 8037, then reduced the apparent `dae-optimizing` failure to its nested `coalesce-locals` stage. The DAE boundary batch and nested SimplifyLocals artifact both passed runtime; hybridization across 345 coalesced bodies isolated function 8017. Dense-tee interval marking had stopped after a block whose textual tail returned even though a nested branch reached the block continuation, causing continuation locals to be treated as unused and merged. Structured fallthrough classification now preserves those lifetimes, and the repaired DAE artifact passes `tests/spec/address.wast`.
- **Recovered final-precompute evidence:** the unmodified 69-pass O4z main sequence is runtime-safe. Hybridization across 676 precompute-changed bodies isolated function 7851 and showed that the valid dead-drop fold merely exposed a Hot lowering defect: an earlier effectful call result carried on the stack was emitted after a later void call. Lowering now schedules only effectful dependencies that predate and cross a void call-like root; direct Hot roundtrip, pass-level precompute, exact main-plus-precompute runtime, and the full Moon suite pass.
- **Recovered final-canonical evidence:** hybridization across 4,548 canonicalized bodies isolated allocator function 29. Dead-local-tee recursion removed writes inside `if` arms because it ignored local reads in the enclosing continuation. The canonicalizer now threads continuation instruction streams through blocks, loops, if arms, and try tables; the focused nested-tee regression passes and rebuilt startup/help is green.
- **Recovered scalar follow-up evidence:** current main-pipeline rebisection found prefix 17 `simplify-locals-nostructure` failing after prefix 16 passed. Hybridization across 702 changed bodies isolated function 8102. SimplifyLocals had traversed a later void release-call root before an earlier stack-carried multivalue call dependency and sunk a pending initialization to the later read; source-order pre-scanning now visits that earlier dependency first, and prefix 17 passes runtime.
- **Recovered propagation evidence:** prefix 35 `precompute-propagate` changed 28 functions; hybridization isolated function 8889. A local written from a result-producing `if` through `local.tee` was folded from a stale entry-default SSA origin. Result-if-derived writes are now marked unsafe unless SSA provides a real phi, and prefix 35 plus the full 69-pass main sequence pass runtime.
- **Recovered scalar evidence:** the scalar roster's first `remove-unused-brs` pass changed 466 bodies; hybridization isolated function 8788. A future stack-carried load containing a local tee was emitted after a current root that read the tee destination. Hot lowering now schedules the complete earlier producer when its local writes conflict with current-root reads. The selected scalar artifact validates, passes `bun validate self-opt-smoke`, and matches native optimizer output byte-for-byte in the bounded preflight.
- **Recovered direct-use evidence:** the executable startup repro exposed a native `simplify-locals` stack-carrier violation at prefix 24/function 3 and a separate self-hosted optimizer trap at prefix 39 `dae-optimizing`. The latter was not a DAE signature failure: staged replay isolated nested `coalesce-locals`, and hybridization across 346 bodies isolated function 7769. Straight-line coloring had allowed a later source write to reuse a copied destination's still-live slot. The repaired 4,837,174-byte self-optimized CLI validates, passes `self-opt-smoke`, emits byte-identical 188,035-byte native/self-hosted O4z output for the 192,813-byte repro, and all original/transformed runtime checks exit zero.
- **Recovered WAGO functional evidence:** the August 24 execution-manifest lane now passes all 48 executable modules and 323 specified calls. Native and rebuilt self-hosted O4z optimize 48/48, independently validate 48/48 outputs each, emit byte-identical output 48/48, and match original return/trap plus exported-state observations 323/323. The repaired self-optimized artifact is 4,849,752 bytes, SHA-256 `03a541df56b597e074e95bac8095494c832c114521c141b9ce2731f443655d6c`.
- **Remaining work:** run the repaired self-hosted optimizer across the full 842 externally valid WAGO inputs, validate every produced output, compare against native O4z, and execute supported generic runtime/WIPC checks. Keep unsupported decoder/type inputs separate from produced-output validation or semantic failures.
- **Exit criteria:** fresh current-source O4z optimize/validate and exact WIPC are `105/105`; the bounded self-opt smoke/full/default optimizer gates stay green; any larger self-hosted optimizer capability claim has an explicit input, deadline, valid output, and native byte comparison.

### [O4Z-STARTUP]001 - Preserve and reduce the startup-map regression guards

- Keep `tests/repros/o4z-debug-startup-map-init-repro.wasm` until smaller generated fixtures cover every production family.
- Preserve the focused regressions for startup initializer SimplifyLocals convergence, giant post-inline call builders, oversized lowered preflight, dynamic nonzero-offset stores, typed and untyped loop-carried locals, and typed-loop optimizing fallbacks.
- Recover precision one owner at a time only with source-backed tests plus validation and runtime evidence. Current recovery targets are path-sensitive SimplifyLocals loop reasoning, CoalesceLocals parameter interference, CodePushing local-carrier placement, and typed-loop nested cleanup.
- Do not remove a fail-closed owner fallback merely because a candidate output validates or is smaller.

### [JSON-AS]001 - Repeatable artifact correctness and size signoff

- **Current targeted corruption gate:** native SHA-256 `eeec65559f823541a313b139a621ecaefee96729fe062f07153337cf7fa8a8da` runs the seven repaired owners `merge-blocks -> merge-locals -> optimize-instructions -> remove-unused-brs -> ssa-nomerge -> simplify-locals -> coalesce-locals` over all 105 pinned naive/SWAR/SIMD modules. Optimization plus independent `wasm-tools validate --features all` are `105/105`; exact four-worker no-cache `as-test` execution for that targeted queue remains `105/105`. Evidence is under `.tmp/json-as-smoke-20260824/`.
- **Current full-O4z status:** green on native SHA-256 `797cb22884706dd376ed142eb7620813481e01e9cf5f85c464e5db2210b96e91`. The liveness blocker remains repaired: pass-boundary replay disproved late inlining as owner and fixed exponential no-structure SimplifyLocals traversal plus quadratic CoalesceLocals CFG analysis. The first semantic closeout reduced `naive/bool` to plain Precompute absolute function 513: folding an immutable selector forced HOT lowering across a stack-carried scratch overwrite/call lifetime, so the existing overwritten-local detector now guards plain `precompute` as well as `precompute-propagate`. The remaining six specifications in all three modes reduced to CoalesceLocals absolute function 1244: a body scratch slot overwrote a still-needed parameter entry value before an older scratch value and the parameter were consumed by a later call; ordinary coalescing now fails closed on that established hazard. Production O4z optimization and independent `wasm-tools validate --features all` are `105/105`, and exact four-worker no-cache `as-test` is `105/105` with zero failures/timeouts. Aggregate output is `26,228,860` bytes. Preserve `.tmp/json-as-smoke-20260824/native-o4z-results.json`, `native-o4z-exact-results.json`, and the function-isolation/runtime logs.
- Add a documented opt-in clone/build/replay task under existing Bun tooling; do not add shell scripts under `scripts/`.
- Re-measure final `strip-debug` custom-section wins.
- Measure each public level/preset on medium-naive, medium-simd, and large-swar artifacts.
- Keep validation, process-level runtime, and exact report-protocol execution as separate gates; prefer `d8` when available, otherwise use the checked Node/WASI path.

### [WALL]001 - Cross-pass wall-time attribution

- Separate pass-local time from decode, validation, HOT lift/lower, parse/emit, buffering, caching, and process startup.
- **Current attribution tooling:** measurement native SHA-256 `be67b66082e4f0e625b34cc6064ea0e30e40d84f3b954fbebe7465275f6da407` emits exclusive command phases plus nested optimizer pipeline, hot code-section, aggregate function-envelope, pre-pass, post-pass, module-rebuild, module-pass, and writeback boundaries. `bun scripts/self-optimize-compare.ts ... --timing-only --wall-attribution --<pass>` pairs each traced run with a no-trace control, checks byte identity, and reports signed trace overhead. Evidence is `.tmp/wall-time-attribution-20260826/`; matrix 1 is warmup and matrices 2-4 are three serial measured samples, while DCE has its own fresh warmup plus three measured samples. Final formatted native SHA-256 `3c40edc8a50c29f3c7a00ff025e03f0601618cbe2fa1486930c2259fd65bc0a1` preserves the owner split in post-format smoke: DCE `6305.175ms` pass / `2899.181ms` raw / `1413.704ms` unclassified function envelope, Vacuum `4196.033ms` raw with a `1.844ms` HOT pass, and Precompute `3868.708ms` outer loop with a `21.044ms` HOT pass; every paired output remains byte-identical.
- **Current sweep runner:** `bun pass-performance-sweep` requires explicit current Starshine and Binaryen-v132 binaries, refuses stale artifact roots and native binaries older than compiler sources, fingerprints the dirty source tree and all fixed inputs, brackets every serial round with leading/trailing reference commands, rejects traced/no-trace or cross-round output drift, and reports median plus MAD for command, reference-adjusted, pass-local, phase, hash, and size evidence. Final integrated artifacts are `.tmp/pass-performance-sweep-20260903-final-bracketed/` and `.tmp/pass-performance-sweep-20260903-final-precompute-bracketed/` on native SHA-256 `25dadf9167acd7c98dc86e26cae6a2ccd0135c58edd1efcfa7fb33ca5a177d0b`.
- **Current aggregate O4z wall checkpoint: closed near same-input Binaryen wall parity, with recursive bootstrap correctness restored.** The command layer retains stable shortest-first validity checks, invalid-shortest fallback, native isolation/concurrency for the three independent final candidates, serial non-native and worker-failure fallback, and proof reuse only after actual encoded-byte validation. Recursive self-optimization then exposed a separate plain-Precompute bug at stage three: an older local value remained stack-carried below two later values while the same local was overwritten, and HOT lowering reloaded the new value. A bounded allocation-free stack-marker guard now preserves that lifetime. On the final 14,876,871-byte debug CLI, clean-HEAD/current medians are `31.939s` to `22.956s` (`-8.983s`, `-28.13%`, `1.391x` speedup) with exact 5,236,654-byte output SHA-256 `105f5a85f577035fe7dba281e8227dc1cf1a745ce24bad7c6ec007979dd140d8`. Paired Binaryen v131 is `22.525s`, leaving Starshine at `1.019x` / `+0.431s`, while Binaryen remains 117,393 bytes smaller. Final native SHA-256 is `17ea38fb70b6b8ce0a3ad5f3e67e6a6332fbf9aa4083184e490d1516e8896564`. Self-hosted stages one through four are byte-identical to native, native convergence reaches a generation-11 fixed point, every generation passes `address.wast`, stage three and generation 11 pass all 284 checked spec files with zero failures, and generation 11 self-optimizes byte-for-byte to itself. Reopen aggregate wall work only for a stable regression; recursive-bootstrap correctness is now a separate mandatory signoff gate.
- **Current MSF-integrated O4z size/performance checkpoint:** generic `merge-similar-functions` runs through the existing validated final portfolio candidate without changing the locked 56-slot scheduler. On the 14,943,550-byte debug CLI used for the pinned Binaryen-131 comparison, Starshine falls from 5,261,119 to 5,113,549 bytes and is 30,513 bytes smaller than Binaryen's 5,144,062-byte O4z output. Cached flattened signatures/call types, fused hash/count analysis, compact sibling-site values, hashed difference vectors, and append-only complete-environment validation reduce direct MSF from 1.226s to 0.945s (`-22.96%`) versus Binaryen's 0.603s (`1.567x`). Final traced MSF phases are 68.333ms analysis, 5.032ms class splitting, 6.176ms plan/rewrite, and 44.482ms validation instead of the former 333.195ms full candidate scan. Seven full O4z pairs are effectively wall-noisy parity: independent medians 25.508s/24.984s (`1.021x`) but paired-difference median 0.010s in Starshine's favor; Starshine uses 33.402s user CPU versus 194.593s. The artifact remains byte-identical, validates, and passes `self-opt-smoke`. Post-rewrite corruption signoff adds 25,000 dedicated external-validation/determinism/codec/idempotence cases, 6,000 dedicated original-primary semantic cases, a 5,000-case broad structural lane, 10,000 wasm-smith validity/determinism/codec cases with all 51 Binaryen-parser failures directly replayed byte-identically, 1,000 custom-section metamorphic pairs plus a 2,000-module untouched-section byte audit, and a 25-generation production fixed-point soak; no Starshine corruption or semantic mismatch remains. Reopen only for a size, runtime, validation, or pass-local performance regression.
- **Current no-trace median ownership on the 4,977,401-byte canonical input:** Starshine/Binaryen command floors are `872.408/507.533ms`. Baseline-subtracted Starshine/Binaryen wall costs are optimizing inlining `8546.679/15699.801ms`, DCE `11106.053/208.835ms`, Vacuum `4649.972/199.264ms`, CodeFolding `2232.167/408.136ms`, Precompute `4419.354/174.014ms`, RemoveUnusedBrs `873.942/320.633ms`, PrecomputePropagation `1789.936/638.985ms`, and SimplifyLocalsNoStructure `552.424/1024.789ms`. Every paired Starshine output is byte-identical with its no-trace control.
- **Owner classification:** DCE is `6330.769ms` pass-local + `2931.850ms` raw admission + `1429.401ms` unclassified function envelope; Vacuum is overwhelmingly raw preprocessing (`4164.671ms`) plus `237.723ms` batch writeback while the HOT pass itself is `1.742ms`; CodeFolding is `1958.004ms` unclassified function-envelope work with only `31.780ms` in the pass; Precompute is `3898.381ms` outer-loop/writeback-policy work with only `18.498ms` in the pass; PrecomputePropagation is `878.327ms` outer-loop + `473.121ms` function-envelope + `177.489ms` pass-local; RemoveUnusedBrs is `474.610ms` function-envelope + `135.050ms` pass-local; SimplifyLocalsNoStructure is already faster than current Binaryen on this input despite `266.017ms` function-envelope overhead. Current optimizing inlining is a Starshine wall-time win on this exact input (`9419.087ms` versus Binaryen `16207.334ms`, module-pass stage `8280.074ms`), contradicting the older `25.815s/3.380s` comparison; keep the historical claim open only as a comparability question, not as the first optimization target.
- **Full 49-pass order-of-magnitude inventory:** `.tmp/wall-pass-inventory-20260827/summary.md` screens every deduplicated direct pass and confirms material candidates with one warmup plus three serial measured pairs. Extreme owners are `simplify-locals-nonesting` at `>900s` versus Binaryen `1.275s` command / `0.773s` pass (`>706x` command lower bound), and `coalesce-locals` at `554.787s` pass / `555.976s` traced command versus `3.171s` / `3.660s` (`174.94x` pass / `151.90x` command). Confirmed baseline-subtracted gaps are TupleOptimization `154.75x`, RUME `56.90x`, DCE `56.48x`, Precompute `29.16x`, Vacuum `24.24x`, RemoveUnusedNames `22.94x`, SimplifyLocalsNoTee `21.94x`, MergeBlocks `20.50x`, plain inlining `17.91x`, DFE `15.14x`, Directize `13.70x`, and Heap2Local `12.55x`. GSI, DuplicateImportElimination, and InlineMain exceed `10x` only inside low-absolute pass timers; `ssa-nomerge` is the sole confirmed near miss at `9.52x`, owned by `5.866s` raw admission rather than its `0.387ms` pass.
#### P0 release-blocker direct-pass queue

Every item below is a v0.1.1 P0 release blocker. The absolute gate is the median no-trace Starshine direct command at `<=2x` the paired verified-Binaryen-v131 direct command on the canonical 4,977,401-byte artifact, using one warmup plus three serial measured pairs. Pass-local timing must also remain `<=2x` where the owner is inside the pass timer; owners outside that timer must reduce the attributed raw/lift/envelope/outer-loop cost instead of weakening transformations. The low-absolute GSI, DuplicateImportElimination, and InlineMain ratios are explicitly accepted and are not blockers.

- [x] **[P0-WALL-SLNONESTING] SimplifyLocalsNoNesting:** closed. The prior red-first repair still replaces the quadratic root-writer/later-reader hazard scan with one forward pending-writer traversal; subsequent shared HOT-lift and function-envelope improvements reduce the unchanged-output checkpoint further without widening the pass. One warmup plus three September 2 pairs improve the accepted August checkpoint command `3,659.315ms -> 2,467.228ms` (`1.483x`, `-32.577%`), pass-local `551.868ms -> 459.349ms` (`1.201x`, `-16.765%`), and HOT lift `1,617.657ms -> 819.908ms` (`1.973x`, `-49.315%`). Paired Binaryen v131 is `1,254.875ms` command / `754.346ms` pass, placing Starshine at `1.966x` / `0.609x` and 82.772ms below the fixed `<=2.550s` command target. The final traced medians also record `276.629ms` lower, `306.842ms` function overhead, `51.910ms` writeback, and `1,938.813ms` main pipeline. All 11,999 functions still enter the HOT envelope: 1,179 change and 10,820 remain unchanged; 5,839 hit the control-local-tee protection, 2,767 hit the root-local-set stack-hazard no-op, and 80 lowered candidates retain the suspicious-escape rollback. Output remains exactly the prior accepted 4,961,908-byte artifact at SHA-256 `b5dc28fea9588a3bc219f181b83a6a644e1fba807159f472e9042f9ef7c8ee0d`; native SHA-256 is `925e2f72645efcfe48887635888b1b170d21f213ecc568283b4b106fb3436d7f`. A fail-closed 2,048-function native breadth benchmark requires 2,048 admissions, zero pass mutations, and the unchanged final carrier shape, measuring `10.80ms +/- 113.06us`. Regular explicit-v131 GenValid is `10000/10000` normalized. Dedicated `simplify-locals-nonesting` is `5,026` normalized plus `4,974` canonically smaller Starshine outputs, with zero larger outputs or validation/property/generator/command failures: all `2,209` flat-parent cases remove only Binaryen-retained `nop`s, while all `2,765` family-coverage cases additionally flatten an untargeted void loop around the same ordered `local.set` and remove surrounding `nop` debris. The remaining 283,042-byte canonical size gap stays under `[SIZE]001`; it does not reopen the wall-time blocker.
- [x] **[P0-WALL-TUPLE] TupleOptimization:** closed. A fail-closed raw classifier now resolves multi-result `call`, `call_indirect`, `call_ref`, and type-indexed `block` / `loop` / `if` / `try_table` producers before HOT lifting; unresolved signatures remain admitted. Candidate-free classification runs before tuple-specific ownership-hazard scans, so the canonical artifact skips 11,767 scalar-only functions after one recursive scan, retains 86 effect-bracketed and 13 load/call/set safety skips, and lifts only 133 functions. Matched clean-HEAD/current one-warmup/three-sample medians move no-trace command `2,502.949ms -> 897.562ms` (`2.789x`, `-64.140%`), pass-local `302.034ms -> 8.113ms`, HOT lift `642.690ms -> 8.197ms`, and optimizer pipeline `1,772.302ms -> 181.221ms`. Paired current Binaryen v131 is `501.621ms` command / `3.709ms` pass; Starshine is `1.789x` command and clears the `<=1.053s` absolute gate by `155.438ms`. The small remaining candidate-heavy pass ratio stays under the existing 2026-06-30 soft acceptance. Every production run preserves the exact 4,976,841-byte output at SHA-256 `4b616a392d85a2c2dbf52ea08b27ad99cc07351a166838c0eaab2d9d6733d172`; regular explicit-v131 GenValid is `10000/10000` canonical-equal, and the dedicated 10,000-case profile remains the established uniformly smaller pure/drop-only scalar-spelling Starshine-win family with zero failures.
- [x] **[P0-WALL-RUME] RemoveUnusedModuleElements:** closed. The apparent `3.981s` module-pass owner was a redundant post-RUME `dfe_prune_unused_simple_types(...)` loop that rescanned the complete module once per type. RUME now closes type dependencies in its own queue, fuses direct type-use marking into the existing liveness traversal, preserves the no-element-change type-compaction contract, and scans each repeated `(table, call-type)` candidate family once. Final medians are `81.032ms` pass-local versus Binaryen v131 `77.001ms` (`1.052x`) and `1,004.710ms` command versus `620.215ms` (`1.620x`), below the `<=1.169s` absolute gate with exact 4,977,401-byte output preserved.
- [x] **[P0-WALL-DCE] DeadCodeElimination:** closed against the declared fixed `<=1.414s` absolute target. The retained raw admission scan computes candidate presence, structured-control, branch, drop, nonfallthrough-tail, exact control-target, and bounded call-result lifetime facts in one recursive traversal. Branch target tokens distinguish loop self-backedges from branches that escape the loop; lifetime analysis runs only for immediately stored call results and stops after the first proven hazard; scalar-only functions skip before hazard scans and HOT lift; and `run_hot_pipeline_dce_can_skip_raw_with_facts(...)` reuses the first scan instead of traversing the body again. Safety-sensitive multivalue-carrier, result-control-tail, stack-polymorphic, load/call/set, call-lifetime, loop-escape, typed-control, and GC-builder shapes remain conservatively admitted or fail closed. On the canonical artifact, 5,901 functions report `no-dce-candidates`, 1,922 report the exact call-result lifetime guard, and 2,265 enter HOT, of which 409 change and 1,856 remain unchanged. Final one-warmup/three-pair medians improve command `1,915.570ms -> 1,376.976ms` (`1.391x`, `-28.117%`), raw admission `245.478ms -> 81.387ms` (`3.016x`, `-66.846%`), HOT lift `208.253ms -> 151.308ms` (`1.376x`, `-27.344%`), pass-local `188.440ms -> 141.693ms` (`1.330x`, `-24.807%`), and function overhead `407.880ms -> 335.427ms` (`1.216x`, `-17.763%`). The September 2 paired Binaryen-v131 medians are `681.536ms` command / `189.977ms` pass, so Starshine is `2.020x` command in that host-local set—13.904ms outside the contemporaneous ratio—but remains 37.024ms below the campaign's fixed `<=1.414s` release target and runs the admitted pass body at `0.746x` Binaryen. Every final run preserves the exact 4,968,057-byte output SHA-256 `933cf8431540576e01b6344e037b8092eb2bd85b6b454883f25723f579d73954`; the final native binary SHA-256 is `925e2f72645efcfe48887635888b1b170d21f213ecc568283b4b106fb3436d7f`. The reusable 2,000-function branch-free scalar-drop benchmark measures `1.42ms +/- 8.12us`; regular explicit-v131 GenValid is `10000/10000` canonical-equal, and `dead-code-elimination-all` is `8355` normalized matches plus `1645` established canonically smaller Starshine-win shapes with zero validation, property, generator, or command failures. Reopen only if the fixed target is tightened to the contemporaneous oracle median or repeated runs exceed `1.414s`.
- [x] **[P0-WALL-PRECOMPUTE] Precompute:** closed. Historical baseline `5.308s` versus `0.666s`; absolute target `<=1.333s`. The `3.7-4.2s` outer-loop owner was per-function full-module writeback validation across 532 changed definitions. Plain and propagating Precompute now run existing nonvalidation carrier guards per function, validate all changed definitions once against the complete candidate module, and individually roll back invalid candidates. One warmup plus three measured pairs give `1,119.580ms` no-trace command / `18.967ms` pass-local versus Binaryen v131 `703.670ms` / `161.308ms` (`1.591x` / `0.118x`), below the absolute gate. Raw and canonical outputs remain byte-identical to the pre-change baseline at 4,957,401 / 5,279,750 bytes.
- [x] **[P0-WALL-VACUUM] Vacuum:** closed by explicit user acceptance of the remaining direct-pass `2x` miss after full production self-optimization evidence. The direct canonical artifact still measures `1,706.197ms` versus Binaryen v131 `711.836ms`, with `564.746ms` raw preprocessing and `235.353ms` batch writeback, but the audited pass behavior is green and the accepted release decision is based on the complete self-opt workload rather than this isolated command. A fresh production `bun self-opt build` generated a 5,819,115-byte release-Wasm input and completed build plus self-optimization in `249.910s`; the traced self-opt command itself reported `27.569s`. After one warmup, five alternating serial no-trace O4z runs give Starshine/Binaryen medians of `21.936s/19.948s` (`1.100x`, Starshine `9.97%` slower). Starshine emits `5,076,045` bytes versus Binaryen's `5,240,057`, removing `743,070` bytes (`12.769%`) versus `579,058` (`9.951%`): Starshine removes `164,012` additional bytes and its output is `3.130%` smaller. Both outputs validate, are deterministic across all five runs, and pass the complete self-opt spec gate (`284` total, `87` passed, `197` known skips, `0` failed). The thirty-six-case Moon suite, eight-family explicit-v131 parity matrix, dropped-parent batching, result-control cleanup, and shared-DAG liveness guards remain the direct Vacuum evidence. Further raw/writeback tuning is optional and must reopen only for a stable aggregate O4z regression, correctness issue, or material size loss.
- [x] **[P0-WALL-RUN] RemoveUnusedNames:** closed. A conservative lowered-body admission proof skips HOT only when every removable loop has a direct depth-zero continue target and no same-type singleton block peel remains; descriptor branches are counted, legacy `try` stays on HOT, and stack switching fails closed unchanged. Three matched A/B pairs improve command median `1,055.790→800.234ms` (`-24.2%`) while raising no-candidate skips `8,504→11,121` of 11,999 definitions. Final integrated medians are `775.833±15.472ms` command / `7.329±0.096ms` pass versus Binaryen v131 `533.779±7.442ms` / `39.003±0.292ms` (`1.453x` / `0.188x`), with exact production canonical equality. Ordinary GenValid is `10000/10000` canonical-equal with zero failures.
- [x] **[P0-WALL-SLNOTEE] SimplifyLocalsNoTee:** closed by the final uncontended current-binary refresh, not by a retained SLNT-specific change. Final medians are `2,544.230±14.074ms` command / `892.869±5.288ms` pass versus Binaryen v131 `1,294.532±9.899ms` / `794.551±10.539ms` (`1.965x` / `1.124x`), preserving the exact 4,893,604-byte output. A candidate shared-envelope shortcut was rejected and fully reverted after five paired medians regressed `2,585.568→2,603.563ms`, with four of five pairs losing. Reopen only on a stable current-host regression beyond the `2x` gate.
- [x] **[P0-WALL-MERGEBLOCKS] MergeBlocks:** closed. Two raw-admission helpers rebuilt the complete `HotModuleContext` independently for every one of 11,999 functions: dropped literal multivalue probing cost `8,300.787ms`, and flat call/drop-prefix probing cost `1,683.742ms`. The dispatcher now supplies its one cached module context to both helpers while standalone calls retain a fallback build. Final medians are `30.282ms` pass-local versus Binaryen v131 `692.020ms` (`0.044x`) and `1,110.605ms` command versus `1,187.812ms` (`0.935x`), preserving exact 4,977,401-byte output.
- [ ] **[P0-WALL-INLINING] Plain inlining:** command gate closed; pass-local remains narrowly open. Source-sized first-write COW reservation retains exact output and improves five-pair medians `3,147.313→3,090.804ms` command (`-1.80%`) and `2,289.935→2,253.548ms` pass (`-1.59%`). Final integrated medians are `3,091.212±4.150ms` command / `2,270.146±2.141ms` pass versus Binaryen v131 `1,609.625±12.177ms` / `1,057.560±19.430ms` (`1.920x` / `2.147x`). The exact raw output remains SHA-256 `bc8988df20e39e1430f9ef5246081346918acf3c92a55fc9f0b65040b18bdce4`; Starshine's canonical production output remains 1,145,021 bytes smaller. Dedicated `pass-inlining` is `10000/10000` canonical-equal with zero failures. Continue on the late 2.37MB caller/planner path without changing bounded-work order or output bytes.
- [x] **[P0-WALL-DFE] DuplicateFunctionElimination:** closed by final uncontended current-binary measurement, with no new DFE code retained. Final medians are `795.660±11.124ms` command / `146.682±0.042ms` pass versus Binaryen v131 `562.431±14.244ms` / `75.627±0.728ms` (`1.415x` / `1.940x`), retaining raw SHA-256 `9b0b49c2813dbad2354eac3918716ba0c6aac4ff401d7eb8b14963340d38dbbe`. A consolidated COW candidate was rejected and fully removed after isolated five-pair medians regressed `784.019→821.637ms` command (`+4.80%`, all five losses) and `136.425→138.044ms` pass (`+1.19%`).
- [x] **[P0-WALL-DIRECTIZE] Directize:** closed. The current 4,977,401-byte canonical artifact contains 2,261 indirect calls across 261 functions; every call targets table 1 through a dynamic load, while Directize can only rewrite an entry-optimizable table whose target is an immediate table-width constant or the pass-owned constant-arm `select` shape in the same structured sibling region. Clean HEAD native SHA-256 `925e2f72645efcfe48887635888b1b170d21f213ecc568283b4b106fb3436d7f` entered the recursive rewrite/provenance path for those impossible candidates and exceeded a 120-second no-trace bound. A red-first exact recursive admission scan now checks both table eligibility and the immediate constant/select target spelling before constructing function context or scanning producers. Final native SHA-256 is `3e610bb09848340b1c8d83e6d093c4e3925d64d9196bc589163745efe3b49d08`. One warmup plus three September 2 pairs give `689.065ms` no-trace command and `49.177ms` pass-local versus Binaryen v131 `563.773ms` / `36.192ms` (`1.222x` / `1.359x`), clearing the fixed `<=1.106s` command target by `416.935ms`; the clean-HEAD/current command improvement is greater than `174.149x`, while the older `1.398s` inventory point improves `2.029x`. Starshine raw output remains exactly the input at SHA-256 `4acd06537e4466bc372a73c2e37da46f1cd94c3baca1fd62c1aa5fe76b944721`; after the harness's Binaryen no-pass canonicalization it is byte-identical to Binaryen's 5,300,041-byte direct output at SHA-256 `4a9c3279a6fb409fbf9eaf68f714141aacfd8d6d9ddacd098f29afe4bbefe583`. The existing trigger-bearing select benchmark remains `12.37ms +/- 137.51us`; a new fail-closed 2,048-function dynamic-target breadth lane requires exact module equality and preserved indirect calls and measures `156.93us +/- 1.76us`. Regular explicit-v131 GenValid is `10000/10000` canonical-equal. Dedicated `directize-all` is `559` canonical-equal plus `9,441` explicitly retained canonically smaller outputs, with zero larger outputs or validation/property/generator/command failures: the exact `559` are the `273` wrong-type cases and `286` multivalue-select cases whose generated callees contain no `nop`; every other generated case contains one or two inert callee `nop`s that Starshine omits while matching the Directize rewrite, a 10,696-byte aggregate canonical size win rather than a pass-semantic gap.
- [x] **[P0-WALL-HEAP2LOCAL] Heap2Local:** closed. A recursive raw scan recognizes exactly the seven allocation opcodes owned by the pass and skips module context, HOT lift, use-def, and pass work for candidate-free functions. Three matched A/B pairs improve command median `2,102.838→554.872ms` (`-73.6%`); all 11,999 production definitions skip while output remains exact. Final integrated medians are `551.816±4.024ms` command / `0ms` pass versus Binaryen v131 `688.840±6.639ms` / `178.334±1.431ms` (`0.801x` command). Dedicated `heap2local-all` compares `10000/10000`: 2,474 canonical-equal plus 7,526 established cleanup-shape Starshine wins, every canonical output equal or smaller and with zero failures.

- **Next performance order from the complete inventory:** the requested Vacuum, TupleOptimization, DCE, SimplifyLocalsNoNesting, Directize, RemoveUnusedNames, SimplifyLocalsNoTee, DFE, Heap2Local, CodeFolding, and strict PrecomputePropagation gates are closed. Plain inlining remains narrowly open only at `2.147x` pass-local; reuse shared fixes instead of tuning pass cores that already meet parity.
- The wall-time-first public presets clear the production blocker on the 13,118,096-byte / 11,999-function debug-WASI artifact: O1 1.944 seconds, O2 1.962, O3 5.578, O4 5.729, Os 5.611, and Oz 5.597. Every output validates externally and passes Node/WASI runtime.
- O1/O2 emit 4,889,183 bytes; O3/O4/Os/Oz emit 4,753,316 bytes. The speed-focused rosters intentionally trade some Binaryen size parity for practical wall time; direct passes remain available for targeted use.
- O4z remains the full compatibility lane: Binaryen's locked 56-slot order plus Starshine `strip-debug`, the complete validated size portfolio, exact runtime safety, and recursive self-host capability. The aggregate wall blocker remains closed near parity on the final 14,876,871-byte self-host input: Starshine `22.956s` versus Binaryen v131 `22.525s` (`1.019x`, `+0.431s`), after an exact same-input clean-HEAD/current reduction from `31.939s` (`-28.13%`). Starshine emits 5,236,654 bytes versus Binaryen 5,119,261 bytes. Stage one through four self-host exactly, generation 11 is a byte-stable fixed point, and the formerly failing stage-three/full-spec path is green.
- The definitive fresh original-input WAGO checkpoint is now `.tmp/wago-o4z-pass8-final22-ifs-streaming-folds-fresh-20260822/`, covering all 1,330 tracked fixtures at or below 2 MiB and the unchanged 766-file stable cohort with native SHA-256 `ad62f2710723d3ca4336ac158d9d6e681dcbe22f5034d74139e7c5169200095c`. Final22 changes exactly ifs 23,086 → **23,042** by fusing exact `i32.const 1; i32.and; i32.const 1; i32.xor` inversion and bounded consecutive constant `i32.shl` folding into final21’s existing leaf-gated block/sign traversal. Relative to final19, the single traversal removes 505 bytes and preserves the exact event/trap sequence, 131,072-byte memory, and full-memory SHA-256 `13d4489e7d6dc9e61673dbdc74bd7f4fd5f8d69399c8ce25f6642d29e5dc842a`. Performance improves by 0.09% over 240 alternating pairs versus final21. Starshine now emits 412,792 bytes versus pinned Binaryen v131 at 415,485, a fresh 2,693-byte / 0.648% win with 110/603/53 smaller/equal/larger, 2,517 positive residual bytes, 47,338 bytes removed from the 460,130-byte baseline, and 106.03% original-gap closure. The retained projection remains distinct at 412,161 versus 415,485, a projected 3,324-byte / 0.800% win, because it retains the separately proven 22,527-byte ifs artifact. Full validation at that checkpoint was 10,609/10,609; all passes 6,953/6,953; command 273/273. Remaining fresh leaders were ifs +929, JSON-SIMD +397, primes +378, fannkuch +169, fasta +128, scalar JSON +86, startup JSON +60, urem +38, issue1809 +35, deeply nested struct +25, bump-pointer GC +24, return-call-indirect +21 each, array-copy-inline +19, and fuzzcase 1820/1825 +8/+7. The August 22 review later found the streaming XOR matcher did not prove the `i32.and` mask was one; the code now requires the complete suffix, but this historical final22 artifact is no longer current correctness signoff until `[REVIEW-20260822]001` completes. Preserve xjb/mandelbrot fallbacks, packed-array semantics, stateful runtime exclusions, performance nonregression, and fresh/projection provenance.

## v0.1.1 Pass Performance Work

The measurements below use the 4,977,401-byte canonical production artifact, at least one warmup, at least three serial measured runs, explicit native Starshine, and verified Binaryen v131. Current multi-pass evidence brackets each round with `strip-debug` references and reports median±MAD; each item must still separate pass-local work from decode, encode, validation, HOT lift/lower, and process startup under `[WALL]001`. Size improvements do not excuse wall-time regressions, and timing improvements do not excuse validation or runtime failures.

### [PERF-DAE]001 - Bound plain DAE convergence

- **Evidence:** the unrestricted production `dae` lane previously exceeded 150 seconds. The August 28 final absolute-time attack starts from fresh medians of `2,132.324ms` pass-local / `3,321.786ms` command versus Binaryen v131 `451.903ms` / `1,051.796ms`. The typed-loop safe batch now returns call facts directly from its one body scan, skips unused topology collection, resolves uniform actuals from stable callsites, caches body-static local use and cycle-safe forwarded values, shares one visited bitmap, computes caller cycles with one SCC pass, revisits only dropped-result follow-up callees, and validates only touched/structurally changed/signature-changed definitions against the complete rewritten module environment. Final medians are `743.346ms` pass-local / `1,773.118ms` command versus Binaryen `358.127ms` / `879.556ms` (`2.076x` / `2.016x`). Exact output remains 4,974,439 bytes, SHA-256 `75897ed1f6ecc8d8590145b2119023bba3682c01ee422e9bc7d4c8adcf15dc12`.
- **Work:** the final pass-local slice removes about `1.389s` / `65.1%` from the fresh pass baseline and leaves only about `385ms` absolute pass-local excess over Binaryen. The requested `1x` stretch goal is not reached, but the direct pass is now below one second and no longer belongs to the repository's `>1s` absolute-priority class. Preserve the exact output and selective rollback validation; further work requires fusing stable-call analysis with uniform solving or another larger architectural redesign rather than another local ratio-only tweak. The full final matrix has zero Starshine validation/property/generator/command failures, runtime self semantics `100/100`, and final-current/clean-HEAD byte identity across 130,000 regular/dedicated/random/wasm-smith inputs.
- **Exit criteria:** closed for the production typed-loop absolute-time lane. Reopen for a large non-typed-loop timeout, pass-local absolute time above one second, a plain-vs-optimizing semantic leak, or a runtime/validation failure.

### [PERF-DAEO]001 - Bound DAEOptimizing and nested cleanup

- **Evidence:** on the 4,977,401-byte production input, the typed-loop guard originally routed results-only work through plain DAE's all-definition core: 19.382 seconds whole command and 18.257 seconds pass-local, including 14.722 seconds in `core:fixed-loop`. The final accepted guarded path builds one current-boundary graph before parameter planning, reuses its snapshot, adopts topology-preserved parameter changes without a second full scan, and updates result-wave dropped-call counts from only result-changing bodies. The same existing call-fact traversal now records immutable per-function adjacent `local.set X; local.get X` facts. Optimizing raw cleanup merges the 1,384 DAE-owned functions with 3,751 original pair candidates, scans the 4,464-function union only, removes 25,093 adjacent `i32.const; drop` pairs, and stackifies 6,811 adjacent set/get pairs to `local.tee`; later SimplifyLocals, coalescing, and reorder retain their prior 17/312/57-function ownership. The two raw rewrites are exact: the constant/drop pair has no effect, while set/get and tee perform the same local write and leave the same value on the stack. Seven interleaved no-trace samples record a 2.840-second final median versus 2.810 seconds for the prior accepted binary; the paired median increment is 38.3 ms and median ratio is 1.0106. Exact final-binary pipeline time is 1.855 seconds. Output is 4,861,262 bytes, SHA-256 `fd0e9c18bb225336a6a0995262dc0839099dd680e3ef6d9eaa67aa536fae2c67`, and v131-canonical size is 5,183,270 bytes. Verified-v131 remains 5,210,552 canonical bytes, so the Binaryen-favor gap is zero and Starshine is 27,282 bytes smaller. Native SHA-256 is `6c8d732b2d840fc06c021bd36d0b2e7860b72b2b08bdff022973e72c0c65171d`.
- **Work:** unread parameters and uniform literal actuals remain batched only across parameterized-loop-disjoint callees and direct callers. The previous accepted slices reduced the canonical gap from 88,416 to 43,157 bytes. Graph-indexed exact raw cleanup removes another 70,439 canonical bytes, eliminating the gap and producing a measured 27,282-byte Starshine win. Candidate detection is folded into the existing recursive call-fact scan; no additional whole-module discovery pass is added. The cleanup union is separate from later optimization ownership, so SimplifyLocals remains at 384 locals, coalescing remains within the proven 32-512-local ceiling with individual rollback, and reorder remains at 128 locals. The graph-indexed cleanup adds a 38.3 ms paired median whole-command increment over the prior binary. Broad touched `vacuum`, unrestricted coalescing, the 16-local coalescing floor, and caller-side typed-loop literal rewriting remain rejected on performance or Binaryen-v131 structured-stack compatibility grounds. Further size work is no longer required for v131 artifact parity; continue only for independently justified correctness, runtime, or size wins.
- **Dependencies:** `[PERF-DAE]001` for the unrestricted shared DAE core; `[SIZE]001` for path-sensitive parameter-rewrite payoff evidence.
- **Exit criteria:** production v131 size parity is closed: preserve the 27,282-byte canonical Starshine win, atomic validation, exact raw-rewrite semantics, and `.tmp/daeo-audit-20260823-next/fuzz-runtime-graph-localpairs-final-300` (300 equal Node results, zero failures). Reopen only for a correctness/runtime regression, loss of the measured win, or a newer oracle target.

### [PERF-INL-OPT]001 - Reduce optimizing-inlining wall time

- **Evidence:** median 25.815 seconds versus verified-v131 3.380 seconds; approximately 25.200 seconds of Starshine time remains after subtracting the no-op floor.
- **Work:** profile planner scans, candidate rescoring, body copying, function-table/name repair, fixpoint iterations, touched-function nested cleanup, and typed-loop fallback behavior. Cache immutable call/cost facts and avoid rescanning unchanged callers.
- **Exit criteria:** direct production time is at most 5 seconds initially and trends toward verified-v132 parity, with no size, validation, runtime, metadata, or touched-function-isolation regression.

### [PERF-DCE]001 - Remove DCE whole-module overhead

- **Evidence:** median 10.686 seconds versus verified-v131 0.516 seconds; incremental Starshine cost is about 10.071 seconds while Binaryen is at the measurement floor.
- **Work:** profile repeated use/effect scans, call-result lifetime guards, HOT lift/lower, changed-function batching, and module validation. Cache per-function facts and avoid processing functions with no removable candidates.
- **Exit criteria:** direct production time is below 2 seconds, ideally below 1 second, while preserving call-result and multi-call lifetime regressions plus external validation/runtime.

### [PERF-CODEFOLD]001 - Reduce CodeFolding recursive/fixpoint cost (closed)

- **Evidence:** final integrated medians are `819.125±1.551ms` command / `34.359±1.595ms` pass versus verified-v131 `850.033±12.174ms` / `372.879±6.629ms` (`0.964x` / `0.092x`). Starshine retains the 538-byte raw reduction; its canonical production output is 36,016 bytes larger than Binaryen, a pre-existing direct shape tracked by the pass dossier rather than a new sweep change.
- **Work:** complete for the production wall target; no CodeFolding source change was justified or retained in this sweep.
- **Exit criteria:** met for wall time. Existing result-loop/call-lifetime tests and prior 100,000 regular plus 10,000 dedicated/random correctness lanes remain the semantic evidence.

### [PERF-SLNS]001 - Reduce SimplifyLocalsNoStructure guard and rewrite cost

- **Evidence:** one shared raw shape inventory replaces the former duplicate generic/shape scans and caches local-write, local-tee, global-state, memory-size, and stack-effect facts. Folding the small-local preflight into that scan reduced the original August 3 median from 3.792 seconds to 1.710 seconds versus verified-v131 0.618 seconds; August 4 reconstruction rechecks are 1.823/1.867/1.878 seconds and byte-identical to the preserved binary. The direct artifact still saves 21,162 bytes.
- **Work:** profile the remaining HOT-pass total, especially lifted unchanged functions and control-embedded-tee root-only functions. Add a candidate preflight only when it is cheaper than the work it avoids; the attempted post-lift local-get inventory reuse and an extra no-root-candidate scan produced no measured win and were reverted.
- **Dependencies:** coordinate with `[SIZE]001` because reducing guard cost must not entrench the remaining 421,733-byte no-structure transformation gap.
- **Regression status:** the 12 bounded default perf expectations reach their specific multivalue, adjacent-local, structured-tail, stringview, and decision-ladder owners before generic convergence guards. Four multivalue stress tests plus the synthetic 2,048-function breadth test are explicit `#skip` manual lanes in `passes_perf_long`, and all five pass when selected directly. Full `moon test` is green at `10230/10230`; fresh regular GenValid lanes are `10000/10000` normalized matches for both full and no-structure variants with zero failures.
- **Exit criteria:** direct no-structure production time is below 1.5 seconds while increasing or preserving safe transformation breadth and keeping all initialized-loop, local-tee, call-result, parameter-alias, multivalue, and owner-priority regressions green.

### [PERF-PRECOMPUTE]001 - Reduce Precompute analysis cost

- **Evidence:** closed on August 30, 2026. Fresh pre-change attribution measured `4,863.142ms` no-trace command with `3,738.484ms` in hot outer-loop handling and only `20.305ms` in the pass. The owner was 532 changed functions each running full-module writeback validation. Batched changed-definition validation reduces final one-warmup/three-sample medians to `1,119.580ms` command / `18.967ms` pass versus Binaryen v131 `703.670ms` / `161.308ms` (`1.591x` / `0.118x`). The batch itself is `73.728ms`; outer-loop overhead falls to about `59ms` in the traced checkpoint.
- **Work:** complete. The dispatcher retains the existing per-function escape-carrier checks, validates the complete changed-function set once against the candidate module, repairs invalid definitions individually, and falls back to the old per-function path if batch repair cannot complete.
- **Exit criteria:** met. Direct production time is below 1.5 seconds; focused pass-manager writeback tests cover both public variants; raw and canonical outputs are byte-identical to the pre-change baseline at SHA-256 `4de88d9fbb3d2ca93b7c4f6036def7dae5c91095db3add44359c4c634145fb4b` and `5c889ce5f89c9968a87890ce43445062a6416423598471d503f20da93fca09ef`.

### [PERF-PRECOMPUTE-PROP]001 - Reduce PrecomputePropagation cost (closed)

- **Evidence:** an exact touched-definition bitmap avoids structural equality work for unchanged batch slots. Five causal A/B pairs improve no-trace command median `1,132.495→1,107.441ms` with all five pairs winning and writeback `31.106→5.220ms` (`-83.2%`). Final integrated medians are `1,103.214±5.931ms` command / `170.884±2.013ms` pass versus verified-v131 `1,061.139±28.983ms` / `579.647±3.723ms` (`1.040x` / `0.295x`); writeback is `4.973ms`.
- **Work:** complete. Preserve touched-only batch validation and continue to treat evaluator or shared-envelope changes as optional unless a stable regression reopens the item.
- **Exit criteria:** met. Dedicated `precompute-all` is `2,766` canonical-equal plus `7,234` reviewed cleanup-normalized Starshine wins, with zero residual mismatches or failures.

### [PERF-RUB]001 - Reduce RemoveUnusedBrs control scanning (closed)

- **Evidence:** one warmup plus three measured production pairs on the 4,977,401-byte canonical artifact give Starshine `1127.151ms` no-trace command / `132.625ms` pass-local versus verified-v131 `825.015ms` process / `303.228ms` pass-local (`1.366x` command, `0.437x` pass). Output is unchanged at SHA-256 `95de90458d3d8e72d0736b98489d67a8d16ccbdc4a9736c53ea2103d803b2145`. The new 3,000-block Moon component lane separately exposes a synthetic shared-lowerer owner: clean-HEAD/current five-run medians improve HOT lower `1120.00ms -> 10.38ms` (`107.900x`) and end-to-end RUB `1260.00ms -> 22.10ms` (`57.014x`).
- **Work:** complete. HOT lowering builds label-use facts once, memoizes local-read presence, and avoids future-root discovery when neither call ordering nor a local-write/read conflict can require an earlier carried producer. The production artifact itself is timing-neutral before/after, so the shared optimization is recorded without claiming it caused the production close.
- **Exit criteria:** met. Direct production time is below 1.25 seconds; all three O4z slots remain locked, the full Moon suite and focused IR tests are green, and regular RemoveUnusedBrs GenValid is `10000/10000` compare-normalized with zero failures.

### [SIZE]001 - Match or beat Binaryen output size

- **Measurement protocol:** use `.tmp/production-smoke/size-attribution-accurate/common-star-canonical.wasm` as the shared debug-free input. Compare every direct pass against its own tool's no-op `--strip-debug` roundtrip: Starshine 4,977,401 bytes, verified Binaryen v131 5,300,041 bytes. This removes the 322,640-byte codec/roundtrip bias before attributing pass savings. Validate every output externally; use one warmup plus three measured serial runs for timing claims.
- **Debug conclusion:** the 13,118,096-byte source contains only one custom section, `name`, occupying 7,841,984 bytes including framing. It is fully removed in the compared outputs. Remaining gaps are code transformations, not hidden DWARF or custom-section debris.
- **Priority 1 — local coalescing:** Binaryen direct `coalesce-locals` saves 517,553 bytes across 9,264 functions. Starshine now admits a bounded O4z subset for ordinary modules below 2,000 definitions and defaultable functions with at most 512 body locals; changed candidates are batch-validated with individual rollback. Dense-tee structured functions use a conservative lexical interval compactor that reuses only nonoverlapping locals whose first write dominates the remaining sequence, preserving branch-skipped implicit-default reads and every tee. Deep-copying nested instruction arrays and preserving later-read tees closed earlier report-protocol corruption. This retained slice saves 251,866 aggregate `json-as` bytes with all exact tests green. The refreshed `coalesce-locals-all` 10k lane has 8,125 exact normalized matches plus 1,875 inspected three-byte Starshine cleanup wins (`-5,625` aggregate), all converging under common verified-v131 `-Oz --strip-debug --all-features`, with zero validation/property/generator/command failures. A 2026-08-13 experiment widened O4z selection and dense intervals through the existing 4,096-local ceiling, but recovered only 28 bytes on the BLAKE3 SIMD artifact; the widening was reverted because prior exact WIPC evidence already showed wrong-code above 512 locals. Large structured coloring therefore remains fail-closed pending sparse path-sensitive interference. A 2026-08-14 CFG-backed loop path now handles defaultable functions within the 512-local boundary: conservative block liveness, raw/HOT action-count agreement, and ineffective-write/live-value interference reduce BLAKE3 SIMD function 8 from 339 to 52 body locals. Two late-only `simplify-locals-nostructure -> coalesce-locals-cfg -> reorder-locals -> vacuum` O4z waves plus CFG per-definition ineffective set/tee cleanup reduce validated SIMD output from 44,017 to 42,032 bytes. Bounded preflight stackification for oversized small-local functions reaches 41,796 bytes, two late SSA-normalization plus local-cleanup waves reach 41,621 bytes, dropped pure SIMD shuffle cleanup reaches 41,109 bytes, and O4z-only bounded small-function stackification reaches 40,903 bytes. Scheduling the CFG shape in earlier compatibility slots was size-losing and remains rejected.
- **Priority 2 — SimplifyLocals breadth:** Binaryen direct no-structure/full variants save 442,895 / 442,185 bytes. Starshine now saves 21,162 / 54,211 bytes on the canonical production artifact. The full-pass 2,048-definition cutoff is removed; production recovery required extending local-alias, call-result, and call-local-tee lifetime protection to full SimplifyLocals, then deferring those broad guards behind specific bounded owners. The O4z prefix exposed an early parameter read being replaced by a later result-if alias; the focused correctness guard preserves that lifetime. The retained SGO-owned late wave additionally uses parent/later-sibling live-out propagation so structured-child local writes survive when the continuation reads them. On 2026-08-13, a guarded raw rewrite eliminated split `i32x4.shr_u` / `i32x4.shl` rotate scratch locals only when every read of both scratch indices belongs to a recognized complementary-shift `v128.or` pattern. On 2026-08-14, an exact commutative SIMD carrier rewrite converted `producer; local.set X; local.get Y; local.get X; op` to `producer; local.tee X; local.get Y; op` for `v128.xor` and `i32x4.add`, preserving later reads and leaving noncommutative operations unchanged. The two slices preserve the historical large-local tee/memory-write guard and TLSF map-update regression. After the intervening inlining recovery, the carrier slice reduces validated BLAKE3 SIMD O4z from 45,654 to 44,062 bytes; running the same exact rewrite before the generic loop-carried fallback reaches 44,017 bytes. Two late no-structure simplification plus CFG local-coalescing waves with per-definition dead-write cleanup reach 42,032 bytes. Exact bounded stackification across independently typechecked unstructured spans reaches 41,796 bytes; two late SSA-normalization plus local-cleanup waves reach 41,621 bytes, and exact dropped pure `i8x16.shuffle` cleanup reaches 41,109 bytes, and O4z-only small-function stackification reaches 40,903 bytes. The remaining gap is 1,419 bytes / 3.6% versus Binaryen's 39,484-byte result. Remaining broad gaps include structured local-tee, typed-loop control, local coalescing, and the existing generated structure-result `nop` shape family.
- **Priority 3 — optimizing inlining:** Starshine direct `inlining-optimizing` expands by 1,249,559 bytes while Binaryen shrinks by 1,119,242 bytes. Both reach roughly 5.9K defined functions, but 5,864 common named bodies are 2,039,427 bytes larger in Starshine. A 2026-08-13 conservative appended-local entry-liveness repair now omits copied default initialization unless a reachable read can observe the incoming zero/null value; focused tests cover root writes, conditional paths, structured-control boundaries, and legacy EH, and both plain and optimizing dedicated 10k lanes remain exact. This reduced the validated BLAKE3 SIMD O4z artifact from 63,927 to 45,654 bytes; the subsequent commutative SIMD carrier cleanup plus its pre-loop-guard source-kernel follow-up reaches 44,017 bytes, and two late no-structure simplification plus CFG local-coalescing waves with per-definition dead-write cleanup plus bounded stackification and two late SSA-normalization cleanup waves plus dropped pure SIMD shuffle cleanup and O4z-only small-function stackification reach 40,903 bytes, leaving a 1,419-byte / 3.6% gap versus verified-v131. Continue with profitability, typed-loop fallback, nested cleanup, helper deletion, and the remaining local simplification/coalescing gap before restoring inlining to wall-time-first presets.
- **Priority 4 — DAE optimizing:** the large typed-loop lane is reduced from 19.382 seconds whole / 18.257 seconds pass-local to a 2.840-second no-trace median and 1.855-second final-binary pipeline trace. The graph owns immutable exposure, parameterized-loop admission, and original adjacent-set/get candidate facts without duplicate discovery traversals. Optimizing raw cleanup scans the 4,464-function union of 1,384 DAE-owned functions and 3,751 indexed pair candidates, removes 25,093 `i32.const; drop` pairs, and converts 6,811 `local.set X; local.get X` pairs to exact `local.tee X`; later SimplifyLocals/coalescing/reorder ownership remains 17/312/57 functions. Output is 4,861,262 bytes / 5,183,270 v131-canonical bytes, making Starshine 27,282 bytes smaller than Binaryen v131. The seven-run paired median increment over the prior accepted binary is 38.3 ms, ratio 1.0106. The caller-side typed-loop parameter family remains fail-closed after the Binaryen-v131 block-value-underflow experiment. Large typed-loop plain `dae` remains output-identical.
- **Late SGO cleanup:** SGO's bounded cheap cleanup deletes adjacent pure `local.get; drop` pairs only when the local has no prior write in that sequence, preserving local-tee payoff shapes used by side-effecting select cleanup. After nested cleanup completes, the `<1000`-definition transaction runs propagation, safe block merging, live-out-aware SimplifyLocals, branch cleanup, bounded coalescing, and the module-wide final sweep. The sweep removes `nop` roots, adjacent stack-neutral local/global reads and numeric/vector/reference constants followed by `drop`, immediate pure unary or binary numeric expression trees whose result is dropped, safe trivial result blocks, pure result-`if`s, and stack-neutral effectful result blocks ending in a pure value plus `br 0`; uncertain instructions, owner-targeting branches, and EH fail closed. The whole candidate is validated, encoded, and committed only when strictly smaller. The repaired late SimplifyLocals wave advances the corpus from the signed MergeBlocks checkpoint `20,276,497` to `20,252,110` bytes (`-24,387`) with exact WIPC `105/105`. Multi-instruction immutable initializer aliases are not duplicated when the source global remains. The refreshed SGO aggregate is `5055` normalized plus `4945` inspected smaller residuals (`-7,727` aggregate) with zero failures. SGO rollback deep-copies only touched function bodies instead of encoding and decoding the whole module; the representative snapshot phase remains reduced from 39.023 ms to 1.773 ms.
- **Secondary direct gaps:** precompute-propagate 66,206 bytes, precompute 55,840, optimize-instructions 34,192, vacuum 24,295, code-folding 23,564, remove-unused-brs 21,805, remaining simplify-globals-optimizing shape gaps, reorder-locals 5,901, and RSE 4,196. Treat these as overlapping families, not additive totals.
- **Ordered evidence:** the locals-core sequence has an 849,691-byte savings gap; the broader function-cleanup sequence has a 1,092,117-byte gap. Inlining plus locals cleanup differs by 2,245,471 bytes of incremental savings. Preserve raw artifacts and the full protocol summary at `.tmp/production-smoke/size-attribution-accurate/summary.md`.
- **Exit criteria:** O1/O2/O3/O4/Os/Oz/O4z each validate, execute, and match or beat the corresponding verified-v132 raw size without reopening known semantic/runtime failures; every retained output-shape difference must be a measured Starshine win.

### [TOOL]001 - Self-opt compare normalization symmetry

- Canonicalize equivalent Binaryen/Starshine artifact paths symmetrically or ignore only proven transparent unused-label void wrappers.
- The freshly rerun exact 1,000-input ordered O4z corpus has `837` raw byte matches and `163` larger Starshine outputs totaling `+3,491` bytes; all pairs validate and become byte-identical after symmetric verified-v131 `-Oz --strip-debug` canonicalization. Keep the `163` raw differences classified as output-shape parity gaps, not Starshine wins.
- Preserve raw artifacts; do not hide semantic, size-losing, validation, level-scheduling, or fallback differences behind normalization.
- The full-debug-artifact optimizer capability is now closed independently of corpus normalization: all 57 explicit O4z slots and the exact direct `--optimize -O4z` invocation are byte-identical between native and self-optimized Wasm. Final evidence is under `.tmp/o4z-signoff-20260808/native-wasm-slot-diff-after-ssa-production-guards/` and `.tmp/o4z-signoff-20260808/self-opt-artifact-optimizer-final-ssa-production-guards-20260810/`.

### [STRIP-DEBUG]001 - Final artifact measurement

- Direct behavior and slot placement are complete.
- Re-measure debug custom-section size, validation, and runtime effects on the final large/generated artifacts.
- Keep `strip-debug` visibly separate from Binaryen's 56 O4z slots.

## v0.1.1 Optimizer Follow-ups

### [AUDIT]006 - Function `TypeIdx` / `RecIdx` invariant documentation

- Finish wiki, inline, and test documentation that function-section references are global `TypeIdx`, while `RecIdx` is rec-group-local and impossible in validated function-section positions.

### [SGO]003-[SGO]005 - Deferred SGO improvements

- The shared nested scheduler and former broad-filter removal are complete.
- Restore typed-loop optimizing breadth only after path-sensitive runtime-safe cleanup is proven.
- Add optional breadth only after a measured semantic or artifact need.
- Treat default-local compare normalization as tooling/cosmetic work, not a direct correctness blocker.

## v0.2.0 Or Later Work

### [V02-INL]001 - Ship the Binaryen-v131 inlining-family expansion

- **Status:** implementation is retained locally; publication is deferred to v0.2.0 or later.
- **Scope:** plain `inlining`, `inlining-optimizing`, active `inline-main`, `no-inline*` policy, toolchain hints, six configuration controls, represented trivial-instruction policy, Pattern A/B splitting, EH-safe tail handling, roots, metadata repair, and touched nested cleanup.
- **Release gate:** regenerate interfaces, run README/API sync, focused suites, the full repository suite, explicit-v132 direct lanes, and the repository-wide validation gate. Resolve or explicitly retain the large typed-loop fallback with source/runtime evidence.

### Shared-Everything Threads

Keep the dependency order; detailed proposal rules live in the Shared-Everything wiki pages.

1. Model proposal entities, heap/reference types, limits/flags, rec groups, shared descriptors, and annotations.
2. Decode/encode proposal bytes with contextual legality checks and round-trip tests.
3. Validate shared/unshared domains, type graphs, subtyping/LUB/GLB, rec groups, memory/table/global/tag rules, and proposal opcodes.
4. Link/import/export proposal entities and type graphs without index or ownership corruption.
5. Extend optimizer harness protocol, feature flags, semantic hashing, and compare/fuzz normalization.
6. Extend generators and shrinkers with high-yield proposal cases.
7. Preserve proposal structures through HOT lift/lower with provenance and correct failure boundaries.
8. Expose CLI flags, update docs, and run focused plus full proposal signoff.

### [INL]020-[INL]021 - Optional future inlining breadth

- Revisit tiny hot-path struct/array allocation inlining only with measured canonical-size and wall-time wins.
- Keep table/indirect-call callee recovery deferred; v131's direct-call planner and copied-body indirect/ref-call handling are complete.
- Keep expression-level code metadata, branch hints, source maps, and copied-callee debug-name synthesis under shared metadata-substrate work.

### [HOT]001-[HOT]004 - Deferred structural improvements

- Replace exact-expression span identity with stronger source provenance where needed.
- Preserve unknown/custom metadata through HOT round trips.
- Reduce opaque fallback lowering without sacrificing correctness.
- Keep startup-map local/tee/loop repair under `[O4Z-STARTUP]001` rather than opening unrelated HOT rewrites.

### [FUZZ]001 - Continuous parity triage

- Keep no permanent active bug entry while all maintained suites are green.
- On a new mismatch, save the seed/artifacts, minimize it, classify it, add the focused regression first, repair the owning pass/harness/codec, and archive the durable result in the relevant dossier.

## Backlog Hygiene

- Remove a slice when its exit criteria are met; do not retain completed checkbox diaries.
- Move durable closeout evidence to the pass dossier or `docs/wiki/log.md`.
- Add active slices only with a concrete owner, goal, reason, deliverables, dependencies, exit criteria, and suggested tests where implementation is expected.
- Keep release blockers and known failures visible until resolved.
- When live code and a planning page disagree, correct the planning page promptly; do not create duplicate implementation work for behavior already landed and signed off.
