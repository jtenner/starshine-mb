---
kind: workflow
status: working
last_reviewed: 2026-08-29
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
related:
  - ../tooling/pass-fuzz-compare.md
  - ./reduction-backends.md
  - ./generator-coverage-ledger.md
---

# Semantic Optimizer Campaign Components

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

Typed values retain integer signed values and bit patterns, floating-point bit patterns and classes, signed zero, NaN quiet/payload facts, and reference relation tokens. `strict` compares exact observable bits; `canonical-nan` ignores only same-width NaN payload differences; `trap-aware` still requires the exact committed event/state prefix and normalized trap class.

The comparison report stops at the first deterministic difference and records its category/path, expected and actual structured values, import-event common prefix, resource kind/index, outcome kinds, and trap classes. Incomplete memory or table observation is `blocked`, not a match. Timeouts and unsupported direct crossings are also blocked.

Invocation plans are deterministic, hashed, and bounded. They include a default vector, one-parameter boundary vectors, bounded pairwise vectors, and optional targeted vectors without constructing a Cartesian product. `v128` arguments/results use generated Wasm-side two-`i64` scalar adapters so SIMD values never cross JavaScript. Imported v128 functions use the inverse adapter and retain exact import-event arguments/results. Nullable `anyref`, `eqref`, `i31ref`, `structref`, and `arrayref` use retained null fixtures; non-null and host-unsupported `exnref`/`contref` crossings remain blocked.

The executor constructs typed deterministic imports, including `WebAssembly.Tag`, isolates execution in a killable worker, distinguishes independent and stateful invocation modes, records start/import events, snapshots imported and exported globals/memories/tables, hashes every observed memory byte, and blocks over-cap resources instead of sampling them as equivalent. Immutable active element segments provide exact `funcidx:<n>` identity across tables; modules with runtime table mutation still block cross-table identity. Every three-way report records runtime-interface, invocation-plan, original observation, Starshine observation, Binaryen observation, comparison, and total milliseconds; the semantic cache runtime identity is versioned so older untimed reports cannot be reused as timed evidence. Focused tests cover wrong scalar results, signed zero, strict versus canonical NaN, exact event prefixes at traps, full-memory changes beyond 64 KiB, over-cap blocking, static cross-table aliases, imported exceptions, v128 imports/exports, nullable references, trap normalization, deterministic plans, stage timings, and three-way classifications.

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

The dedicated `semantic-effects`, `semantic-import-events`, `semantic-trap-frontier`, and `semantic-resources` leaves form `semantic-optimizer-all`. Streaming manifests retain per-case `feature_facts`; stable floors are `semantic_effects`, `import_event_channel`, `trap_frontier`, `resource_observation`, and `poisoned_dead_code`. The profile is constrained to one imported function/table/memory/global, no start/active segments, and Bun-supported proposals so observation remains complete.

Semantic cache keys include raw original/Starshine/Binaryen bytes, seed, policy, mode, timeout, caps, runtime version, and Binaryen diagnostic state. `cases.jsonl` persists bounded semantic/property/localization/cache evidence; resume reconstructs observation-v2, semantic-idempotence, convergence, commutator, metamorphic, structural-property, localization, and cache counters. Artifact-scale hazard arrays are excluded from journals after a Bun 1.3.14 monolithic campaign reached 62.72 GB RSS and crashed at 1,856 recorded cases.

August 29, 2026 campaign evidence under `.tmp/semantic-optimizer-all-10000-20260829/aggregate.json` aggregates ten process-isolated 1,000-case shards: 10,000/10,000 original-primary semantic matches, semantic-idempotence matches, convergence fixed points, commutator matches, and metamorphic-equivalence matches; zero blocked, semantic, property, generator, validation, or mismatch outcomes. All 10,000 cases reported Binaryen diagnostic failures because that aggregate accidentally used PATH Binaryen 116 rather than the locked v131 binary; the original-primary conclusions do not depend on Binaryen, but this artifact is not locked-v131 three-way signoff. A corrected explicit-v131 preflight reached 46/100 cases before the one-hour command timeout and exposed large structural vacuum gaps, so locked-v131 10,000-case three-way signoff remains incomplete.

Broader pass evidence completed regular GenValid `10000/10000` and the vacuum-owned profile `10000/10000` (`7175` raw normalized plus `2825` local-cleanup-normalized). The wasm-smith lane compared `6719/10000`, with 3,281 Binaryen/tool failures and 14 inspected canonical-smaller Starshine cleanup shapes. The random-all-profiles lane compared `9007/10000` and retained 1,239 genuine vacuum parity gaps after all existing normalizers; it is a completed bug-finding campaign, not a green vacuum closeout.

Pinned CI now installs wasm-tools `1.251.0`, Binaryen `131`, and Z3 `4.13.3`, builds native Starshine, runs semantic components and a live integer proof, then executes a bounded semantic profile matrix. Every pinned compare lane passes `--require-binaryen-version 131`: compare-pass probes before generation, rejects wrong/malformed/unavailable tools, hashes the resolved executable into `toolchain.json`, `result.json`, and each case record, and rejects resume under a different identity. Remaining acceptance work is therefore limited to closing or explicitly accepting the locked-v131 random-all vacuum parity gaps and rerunning the full locked-v131 semantic three-way campaign; unsupported non-null `exnref`/`contref` and dynamically mutated cross-table identity remain intentionally blocked host boundaries, not matches.
