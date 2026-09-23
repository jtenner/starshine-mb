---
kind: workflow
status: working
last_reviewed: 2026-09-23
sources:
  - ../../../scripts/lib/optimizer-runtime.ts
  - ../../../scripts/lib/optimizer-runtime-executor.ts
  - ../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../scripts/lib/optimizer-replay.ts
  - ../../../scripts/lib/optimizer-corpus.ts
  - ../../../scripts/lib/optimizer-seeds.ts
  - ../../../scripts/lib/fuzz-task.ts
  - ../../../scripts/lib/optimizer-properties.ts
  - ../../../scripts/lib/optimizer-failure-fingerprint.ts
  - ../../../scripts/lib/optimizer-localization.ts
  - ../../../scripts/lib/optimizer-metamorphic.ts
  - ../../../scripts/lib/optimizer-thresholds.ts
  - ../../../scripts/lib/optimizer-neighborhood.ts
  - ../../../scripts/lib/optimizer-translation-validation.ts
  - ../../../scripts/lib/optimizer-correctness.ts
  - ../../../scripts/lib/optimizer-atomic-runtime.ts
  - ../../../scripts/lib/optimizer-atomic-runtime.test.ts
related:
  - ../tooling/pass-fuzz-compare.md
  - ./reduction-backends.md
  - ./generator-coverage-ledger.md
---

# Semantic Optimizer Campaign Components

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../binaryen/release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

## Oracle policy

The original module is the primary semantic oracle. A Starshine output is correct only when it preserves the original module's observable behavior under the selected invocation plan and semantic policy. Binaryen remains an independent optimizer and diagnostic oracle; agreement between Starshine and Binaryen cannot excuse disagreement with the original.

Structural comparison is separate. Canonical structural drift can identify parity, size, or convergence issues, but structural inequality alone is not a semantic failure.

## Versioned component schemas

The reusable TypeScript component layer defines:

- `starshine.optimizer-runtime-interface.v1`
- `starshine.optimizer-invocation-plan.v2`
- `starshine.optimizer-runtime-observation.v2`
- `starshine.optimizer-semantic-comparison.v2`
- `starshine.optimizer-three-way-semantic.v1`
- `starshine.optimizer-three-way-runtime-report.v1`
- `starshine.optimizer-atomic-litmus.v1`
- `starshine.optimizer-atomic-litmus-execution.v1`
- `starshine.optimizer-atomic-litmus-comparison.v1`
- `starshine.optimizer-property-result.v1`
- `starshine.optimizer-semantic-fingerprint.v1`
- `starshine.optimizer-fingerprint-reduction.v1`
- `starshine.optimizer-pass-localization.v1`
- `starshine.optimizer-metamorphic-relation.v1`
- `starshine.optimizer-metamorphic-pair.v1`
- `starshine.optimizer-threshold.v1`
- `starshine.optimizer-threshold-cliff-group.v1`
- `starshine.optimizer-neighborhood-family.v1`
- `starshine.optimizer-rewrite-proof.v1`
- `starshine.optimizer-rewrite-validation.v1`
- `starshine.optimizer-rewrite-validation-batch.v1`
- `starshine.optimizer-threshold-registry.v1`
- `starshine.optimizer-case.v2`

Existing version 1 invocation-plan, observation, self-semantic, corpus, replay, and compare-pass readers remain unchanged. `optimizer-correctness.ts` re-exports the new runtime and property primitives while preserving its prior exports.

## Observation version 2

Typed values retain integer signed values and bit patterns, floating-point bit patterns and classes, signed zero, NaN quiet/payload facts, and reference relation tokens. Runtime observation v2 also records explicit compilation and instantiation outcomes; trapping starts distinguish the normalized trap from ordinary instantiation failure and retain snapshots of host-owned imported globals, memories, and tables even though Node cannot return the failed local instance. `strict` compares exact observable bits; `canonical-nan` ignores only same-width NaN payload differences; `trap-aware` still requires the exact committed event/state prefix and normalized trap class.

The comparison report stops at the first deterministic difference and records its category/path, expected and actual structured values, import-event common prefix, resource kind/index, outcome kinds, and trap classes. Incomplete memory, table, cross-table identity, or unsupported-export observation is `blocked`, not a match, when the aligned executed outcomes agree. A definite scalar result, return-versus-trap, or normalized trap-class disagreement in an aligned executed step remains a semantic mismatch even when one of those unrelated observation surfaces is incomplete. Reference-valued results outside the executable `i31ref` and retained aggregate-factory surfaces, relaxed-SIMD values without an allowed-result oracle, timeouts, unsupported outcomes, and unknown blockers remain blocked.

Invocation plans are deterministic, hashed, and bounded. They include a default vector, one-parameter boundary vectors, bounded pairwise vectors, and optional targeted vectors without constructing a Cartesian product. `v128` arguments/results use generated Wasm-side two-`i64` scalar adapters so SIMD values never cross JavaScript. Imported v128 functions use the inverse adapter and retain exact import-event arguments/results. The configured Node engine exposes `i31ref` function parameters and results as signed JavaScript integers, so the planner exercises null plus `0`, `1`, `-1`, `-2^30`, and `2^30 - 1`; observations retain both the signed value and exact 31-bit pattern, including imported-function events. Nullable `anyref`, `eqref`, `structref`, and `arrayref` retain null fixtures. A non-null nominal struct or array parameter can reuse the opaque result of a zero-parameter exported producer with the exact same Wasm type; no JavaScript object substitution is involved, and modules without a matching producer remain blocked. Both fallback text extraction and the native report distinguish indexed continuation types from aggregate types.

Node can compile the bounded `exnref` and WasmFX `contref` fixtures, but its JavaScript boundary rejects values of those types. Their parameter or result crossings are therefore reported as `unsupported JavaScript reference crossing: exnref` or `contref`, including normalized nullable and nominal continuation forms. Relaxed-SIMD modules still execute for diagnostic observations, then block semantic signoff with `unsupported-relaxed-simd-general-allowed-outcome-oracle:instruction-and-state-contract-required`; arbitrary relaxed instructions need instruction- and state-specific allowed-result contracts. Imported memory64 resources remain blocked pending their separate resource adapter.

The executor constructs typed deterministic imports, including `WebAssembly.Tag`, isolates execution in a killable worker, distinguishes independent and stateful invocation modes, records start/import events, snapshots imported and exported globals/memories/tables, hashes every observed memory byte, and blocks over-cap resources instead of sampling them as equivalent. Immutable active element segments provide exact `funcidx:<n>` identity across tables; modules with runtime table mutation still block cross-table identity. Every three-way report records runtime-interface, invocation-plan, original observation, Starshine observation, Binaryen observation, comparison, and total milliseconds; the semantic cache runtime identity is versioned so older untimed reports cannot be reused as timed evidence. Focused tests cover wrong scalar results, scalar and trap mismatches beside unrelated blocked resources, signed zero, strict versus canonical NaN, exact event prefixes at traps, full-memory changes beyond 64 KiB, over-cap blocking, static cross-table aliases, imported exceptions, v128 imports/exports, non-null exported and imported-function `i31ref` observations, nullable references, retained non-null struct and array crossings, explicit exception and continuation boundaries, trap normalization, deterministic plans, stage timings, and three-way classifications.

## Bounded atomic litmus observations

[`optimizer-atomic-runtime.ts`](../../../scripts/lib/optimizer-atomic-runtime.ts) provides an opt-in two-worker Node lane for reviewed atomic transformation fixtures. Version 1 accepts one primary plus up to three additional imported shared memories, each memory32 by default or explicitly memory64 and capped at sixteen pages, one exported function with bounded `i32` arguments and one `i32` result, one to eight fresh-memory trials, and one to sixteen aligned `i32` observations. Outcome memory values list the required primary-memory offsets first and optional explicitly selected additional-memory locations afterward. Both workers instantiate the same module with the same shared memory objects, wait at a host barrier, and invoke the export concurrently. The worker constructs memory64 imports with `address: "i64"` and BigInt page limits. The subprocess timeout is capped at sixty seconds and remains fail-closed.

Each fixture declares the complete allowed outcome set from the instruction contract. Thread results are signed `i32` values or the normalized `memory-out-of-bounds` trap; other worker failures remain blocked. The comparator checks original and candidate observations for membership in that set; it never treats the bounded original sample as the oracle. Different allowed schedules may appear on the two sides. An original outcome outside the set blocks the fixture as an oracle/runtime conflict, while a candidate outcome outside the set is a semantic mismatch. A fixture may also declare a subset as `requiredObservedOutcomes` when acceptance needs a bounded witness of a particular behavior. If either side does not produce every required witness, comparison blocks and records the first missing outcome. It does not label absence under a bounded scheduler as a proven semantic mismatch. Seeing only allowed outcomes, or seeing a required witness, is bounded evidence and does not prove that every execution or allowed behavior was preserved.

The first deterministic fixture covers two sequentially consistent `i32.atomic.rmw.add` operations from zero. The only allowed observations are old values `(0, 1)` or `(1, 0)` with final memory `2`; a transformed fixture that increments by two reliably produces final memory `4` and is rejected. A second fixture checks `i32.atomic.rmw.cmpxchg` winner identity: replacement `1` or `2` wins, the losing thread returns the winner's value, and final memory identifies the winner. A candidate always replacing with `3` is rejected. A third bounded fixture covers `memory.atomic.wait32` paired with an atomic store and `memory.atomic.notify`: the waiter may return notified with notify count `1`, or observe the changed value with notify count `0`, and final memory must be `1`. A candidate writing `2` is rejected. The stronger bounded wake fixture retries notification with one-millisecond atomic-wait backoffs, allows either an actual wake or retry exhaustion, and requires at least one actual-wake witness: waiter result `0`, notifier result `1`. A candidate that notifies the backoff address produces only the allowed exhaustion outcome, so comparison blocks on the missing wake witness rather than misclassifying schedule absence as a semantic mismatch.

Version 1 also accepts up to three additional, uniquely named imported shared memories. Both workers receive the same memory objects. The first selected-memory fixture performs the RMW on imported memory `1`, while observations retain imported memory `0` as a sentinel. A candidate that redirects the RMW to memory `0` produces sentinel value `2` and leaves the declared outcome set. A distinct compare-exchange fixture observes both memories: the correct module leaves the memory `0` sentinel at zero and records winner `1` or `2` in memory `1`; a candidate redirected to memory `0` instead records the winner in the sentinel and leaves memory `1` at zero. This is focused evidence for preserving a nonzero atomic `MemArg` memory index for RMW-add and compare-exchange. It does not enumerate more than four memories, every atomic opcode, or arbitrary observation layouts.

The first memory64 fixture imports a one-page shared memory64, performs two sequentially consistent `i32.atomic.rmw.add` operations at `i64.const 0`, and declares only old values `(0, 1)` or `(1, 0)` with final memory `2`. Node `v26.10.0` executes the fixture through a `WebAssembly.Memory` created with `address: "i64"`, `initial: 1n`, `maximum: 1n`, and `shared: true`. A candidate adding two produces final memory `4` and is rejected. A mixed-width target-selection fixture imports memory32 at index `0` and memory64 at index `1`, observes offset zero in both, and performs both RMWs on memory64. The [Threads execution rule](https://webassembly.github.io/threads/core/exec/instructions.html) makes each RMW an indivisible load/add/store that returns the old value, so the complete allowed set is old values `(0, 1)` or `(1, 0)`, memory32 `0`, and memory64 `2`. A valid corrupt module selects memory32 with the matching `i32` address; it produces memory32 `2` and memory64 `0` and is rejected.

The bounds fixture moves that RMW to the last valid aligned word, `i64.const 65532`, in the same one-page memory. Its complete nontrapping outcomes remain `(0, 1)` or `(1, 0)` with final word `2`. The controlled wrong candidate uses `i64.const 65536`; both workers report normalized `memory-out-of-bounds` traps and the last valid word remains zero, so the candidate leaves the allowed set as a semantic mismatch. This covers one exact memory64 upper-bound transition and host import capability. It does not cover addresses above 4 GiB, every access width or partial-overlap boundary, memory64 wait/notify, broader mixed-width programs, or every atomic opcode.

This lane is a library/replay primitive and is not inferred automatically for arbitrary GenValid modules. Its required wake is a bounded fixture acceptance witness, not a proof of general wakeup liveness or fairness. Acquire/release and relaxed orders, fences, broader memory64 schedules, shared-GC atomics, and arbitrary-program schedule exploration remain outside version 1.

Weaker-order and ordered-fence execution has a tested fail-closed boundary. The
independent `wasm-tools 1.251.0` WAT parser rejects the active-proposal
`acq_rel` and `relaxed` operand spellings. Exact valid binaries emitted by
Starshine bypass that text parser, but the configured Node runtime rejects
both weaker store encodings at compilation as invalid alignments and both
weaker fence encodings as invalid atomic operands. Focused runtime tests feed
all four exact binaries through the two-worker comparison entrypoint and
require `blocked` on the original side. Therefore the lane cannot yet provide
weaker-order or fence allowed-outcome evidence; sequentially consistent
fixtures remain executable.

## Properties

The common property-result interface records pass flags, generated artifacts, validation, semantic comparisons, structural diagnostics, first failure, replay data, and reducer data.

- **Structural idempotence** remains the existing compare-pass property: canonical structure of `P(M)` equals canonical structure of `P(P(M))`.
- **Semantic idempotence** separately requires `M`, `P(M)`, and `P(P(M))` to remain semantically equivalent. Structural drift is reported without becoming a semantic failure. Compare-pass accepts it as a repeatable `--property semantic-idempotence` mode when `--semantic-oracle node-v2` is active.
- **Composition** remains the existing combined-scheduler versus sequential-single-pass property.
- **Commutator** separately compares `P(Q(M))` and `Q(P(M))` semantically and distinguishes passes that fail alone from order-only failures.
- **Convergence** records every generation's canonical hash and encoded size, detects fixed points, full structural cycles, late validation failure, late semantic divergence, persistent growth, and bounded nonconvergence. Compare-pass accepts `--property convergence --convergence-max <n>` and persists every generated artifact and `starshine.optimizer-property-result.v1` record.
- **Metamorphic equivalence** checks the unoptimized base/twin relation before optimizer blame, then checks each optimization and the optimized relation projection.

## Metamorphic relations

`starshine.optimizer-metamorphic-relation.v1` distinguishes exact interfaces, encoding-only changes, additive unobserved interfaces, export-alias extensions, and validation-only transforms. Validation-only or otherwise unsafe transforms are excluded from semantic pairing. Relation-group IDs are deterministic from seed, profile, transform ID, and generator version. Observation projection can restrict exports to the base interface and remove explicitly promised unused imports.

## Localization and fingerprints

With `--localize-first-divergence`, compare-pass first asks native Starshine for `starshine.optimizer-expanded-pass-queue.v1`, then evaluates prefix zero and every boundary in that exact module-aware scheduler sequence. Repeated O4z slots remain repeated, and `optimize` / `shrink` are localized within their expansion rather than treated as indivisible top-level flags. The report records `passSequenceSource: "moon-expanded-queue"`, validation, semantic relation, canonical hash, byte size, first observed divergent boundary, and all later recoveries. The predecessor module is fed to the observed boundary pass alone; the report says `reproduced`, `context-dependent`, or `blocked`, never "proven guilty." Semantic fingerprints retain the same expanded repeated sequence when localization ran.

Real semantic-v2 failure bundles now include `semantic-fingerprint.json` and `semantic-fingerprint.sha256`. Exact fingerprints retain pass/boundary, difference location, exact offset, trap classes, invocation-plan hash, and first differing import event. Family fingerprints retain the property, pass family, difference/resource category, trap family, and relation/threshold family while allowing witness values or offsets to move.

Reduction starts in exact mode. Invalid candidates, nondeterministic predicates, timeout substitutions, and changed fingerprints are rejected. Family relaxation is allowed only when configured and is recorded explicitly; reports do not claim the exact witness survived after relaxation.

## Experimental campaigns

The following components are experimental bug-finding tools rather than pass correctness proofs:

- pass commutators, now available as a production compare-pass property but still diagnostic rather than proof of pass guilt;
- threshold-cliff triplets;
- reducer-guided typed neighborhood exploration;
- integer rewrite translation validation.

Threshold groups derive `N-1`, `N`, and `N+1` from a supplied descriptor value and use deterministic relation IDs. `bun fuzz explore-optimizer-repro` applies deterministic whole-module `wasm-tools mutate --preserve-semantics` mutations, externally validates every candidate, replays exact fingerprints first, then clusters explicit family-only and nonreproducing variants. The expression-level component remains as a unit-testable primitive, not the production explorer.

Integer translation validation models modular integer values separately from definedness/traps. It covers integer arithmetic, bit operations, shifts, signed/unsigned division and remainder, divide-by-zero, and signed-minimum division overflow. `bun fuzz prove-rewrites <contracts.json>` runs reduced-width exhaustive evaluation before a live Z3 query and writes one `.smt2` and one versioned JSON result per rule. Solver absence is blocked. This system proves declarative integer contracts only; it does not prove floating-point, effectful rewrites, or a whole optimizer implementation without shared declarative source.

`bun fuzz list-optimizer-thresholds` invokes native Starshine's `--emit-optimizer-thresholds-json`, converts its seven resolved Moon-owned values into campaign descriptors, and emits `starshine.optimizer-threshold-registry.v1` plus deterministic cliff groups. TypeScript no longer duplicates the inlining, monomorphization, or low-memory defaults.

## Production command forms

```text
bun fuzz compare-pass --pass <name> \
  --semantic-oracle node-v2 \
  --semantic-policy strict|canonical-nan|trap-aware \
  --observation-mode independent|stateful \
  --observation-memory-cap-bytes <n> \
  --observation-table-entry-cap <n> \
  --runtime-timeout-ms <n> \
  [--property semantic-idempotence] \
  [--property convergence --convergence-max <n>] \
  [--commutator-left <pass> --commutator-right <pass>] \
  [--gen-valid-metamorphic-transform <id> --emit-metamorphic-pairs] \
  [--localize-first-divergence] \
  [--semantic-reduction-relax-family] \
  [--resume]

bun fuzz replay-optimizer <failure-dir|manifest.json>
bun fuzz promote-optimizer <failure-dir> --corpus-root tests/optimizer/regressions
bun fuzz optimizer-seeds --semantic-oracle node-v2 --observation-mode stateful --pass <name>
bun fuzz list-optimizer-thresholds [--seed=<value>]
bun fuzz prove-rewrites <contracts.json> [--solver z3] [--out-dir <dir>]
bun fuzz explore-optimizer-repro <failure-dir|manifest.json> --out-dir <dir> [--seed <n>] [--budget <n>]

starshine --emit-runtime-interface-json <input.wasm>
starshine --emit-expanded-pass-queue-json -O4z --optimize <input.wasm>
starshine --emit-optimizer-thresholds-json [optimizer tuning flags]
```

Every semantic-v2 compare case persists `semantic-observations/case-XXXXXX.json`. Failures additionally retain the report in the copied work directory, exact fingerprint files, optional prefix-localization report/artifacts, and replay metadata. Promotion writes `starshine.optimizer-case.v2` for semantic-v2 failures while continuing to read and write version 1 cases for version 1 properties.

## Current integration boundary

As of August 29, 2026, production compare-pass includes observation-v2 execution and persistence, original-primary three-way classification, Binaryen-unavailable continuation, repeatable structural/semantic property parsing, semantic idempotence, bounded convergence, pass commutators, exact semantic fingerprints, Moon-expanded all-prefix localization, v2 replay/corpus promotion, curated semantic seed execution, threshold listing, and live integer proof commands.

MoonBit now owns `--emit-runtime-interface-json`, `--emit-expanded-pass-queue-json`, and `--emit-optimizer-thresholds-json`. Runtime-interface extraction reads decoded sections directly, reports typed imports/exports/resources/start state, and is used by production semantic compare, properties, localization comparisons, replay, and curated seeds whenever a resolved Starshine command is available. The legacy wasm-tools text extractor remains only as a compatibility path for component callers without a Starshine command.

GenValid metamorphic requests now emit each transformed case together with `gen-valid-NNNNNN-base.wasm`, `base_file_name`, and a deterministic `relation_group_id`. `--emit-metamorphic-pairs` validates the input relation before optimizer blame, optimizes both variants, and persists common property results and aggregate match/blocked/failure counters. Fresh GenValid semantic-v2 failures run deterministic validation-gated byte reduction against the exact fingerprint twice per accepted candidate. Replay requires the persisted exact fingerprint when present, so `bun fuzz reduce-optimizer` and external `wasm-reduce` inherit the same exact predicate; older artifacts without fingerprints retain explicit legacy class-only replay.

The dedicated `semantic-effects`, `semantic-import-events`, `semantic-trap-frontier`, and `semantic-resources` leaves form `semantic-optimizer-all`. The separate `engine-state-*` family is the stricter start-program lane: it uses a fixed `__fuzz` ABI, exact weighted aggregate scheduling, synthetic resource/function exports, active-only hidden-state policy, per-result observation manifests, seed/channel-derived host inputs, and distinct success/trap contracts. See [`engine-state-genvalid.md`](engine-state-genvalid.md). Streaming manifests retain per-case `feature_facts`; stable floors are `semantic_effects`, `import_event_channel`, `trap_frontier`, `resource_observation`, and `poisoned_dead_code`. The profile is constrained to one imported function/table/memory/global, no start/active segments, and Bun-supported proposals so observation remains complete.

Semantic cache keys include raw original/Starshine/Binaryen bytes, seed, policy, mode, timeout, caps, runtime version, and Binaryen diagnostic state. `cases.jsonl` persists bounded semantic/property/localization/cache evidence; resume reconstructs observation-v2, semantic-idempotence, convergence, commutator, metamorphic, structural-property, localization, and cache counters. Artifact-scale hazard arrays are excluded from journals after a Bun 1.3.14 monolithic campaign reached 62.72 GB RSS and crashed at 1,856 recorded cases.

August 29, 2026 campaign evidence under `.tmp/semantic-optimizer-all-10000-20260829/aggregate.json` aggregates ten process-isolated 1,000-case shards: 10,000/10,000 original-primary semantic matches, semantic-idempotence matches, convergence fixed points, commutator matches, and metamorphic-equivalence matches; zero blocked, semantic, property, generator, validation, or mismatch outcomes. All 10,000 cases reported Binaryen diagnostic failures because that aggregate accidentally used PATH Binaryen 116 rather than the locked v131 binary; the original-primary conclusions do not depend on Binaryen, but this artifact is not locked-v131 three-way signoff. The earlier explicit-v131 preflight timeout was dominated by cold native generator compilation and structural reduction. After `--gen-valid-bin`, reduction-free broad execution, and the level-zero Vacuum flatten/preclean fix, `.tmp/semantic-optimizer-v131-after-level-zero-local-normalized-16` completes all `16/16` cases with cleanup-normalized structural matches and zero semantic/property/validation/generator/command failures. Full locked-v131 10,000-case signoff remains incomplete.

Broader pass evidence completed regular GenValid `10000/10000` and the vacuum-owned profile `10000/10000` (`7175` raw normalized plus `2825` local-cleanup-normalized). The wasm-smith lane compared `6719/10000`, with 3,281 Binaryen/tool failures and 14 inspected canonical-smaller Starshine cleanup shapes. The random-all-profiles lane compared `9007/10000` and retained 1,239 genuine vacuum parity gaps after all existing normalizers; it is a completed bug-finding campaign, not a green vacuum closeout.

Pinned CI now installs wasm-tools `1.251.0`, Binaryen `132`, and Z3 `4.13.3`, builds native Starshine plus `_build/native/release/build/fuzz/fuzz.exe`, runs semantic components and a live integer proof, then executes a bounded semantic profile matrix through `--gen-valid-bin` so each campaign process avoids implicit native-release compilation. Every pinned compare lane passes `--require-binaryen-version 132`: compare-pass probes before generation, rejects wrong/malformed/unavailable tools, hashes the resolved executable into `toolchain.json`, `result.json`, and each case record, and rejects resume under a different identity. The earlier v131 campaign remains historical and incomplete; the current acceptance work is to renew any remaining semantic three-way evidence against v132. Unsupported non-null `exnref`/`contref` and dynamically mutated cross-table identity remain intentionally blocked host boundaries, not matches.
