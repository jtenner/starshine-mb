---
kind: workflow
status: working
last_reviewed: 2026-09-23
sources:
  - ../../../ffi/README.md
  - ../../../src/ffi_bridge/ffi_bridge.mbt
  - ../../../src/ffi_bridge/ffi_bridge_test.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/validate/gen_valid_engine_state.mbt
  - ../../../src/validate/gen_valid_engine_tiering.mbt
  - ../../../src/validate/gen_valid_engine_profiles_wbtest.mbt
  - ../../../src/validate/gen_valid_engine_state_wbtest.mbt
  - ../../../src/fuzz/main.mbt
  - ../../../src/fuzz/engine_state_manifest_wbtest.mbt
  - ../../../scripts/lib/optimizer-runtime.ts
  - ../../../scripts/lib/optimizer-runtime-executor.ts
  - ../../../scripts/lib/optimizer-runtime-executor.test.ts
related:
  - ./engine-profile-deep-dive.md
  - ./generator-coverage-ledger.md
  - ./semantic-optimizer-campaigns.md
  - ../tooling/fuzz-runner.md
---

# Engine-State GenValid Profiles

## Purpose

The `engine-state-*` family generates compact deterministic Wasm test programs from the start driver outward. The invalid-module leaf starts from a valid AST and applies one controlled binary mutation after encoding. A case is credited only for behavior that the start driver reaches and executes and that becomes observable through the fixed host transcript or exported resource state. Static opcode presence remains available through ordinary `GenValidFeatureFacts`, but does not satisfy the engine-state execution facts in the nested manifest.

The intended cross-engine contract is:

> Given the same Wasm bytes, case seed, and fixed `__fuzz` ABI, an executor compiles and instantiates the module within a strict budget, records the ordered start transcript, and serializes all observable post-start state canonically.

## Profile family

`engine-state-all` is a seed-rotated exact 136-case weighted cycle. Every contiguous 136 selected cases realizes the declared weights exactly, so every singleton leaf is present without probabilistic retry. Its 45 leaves force module shapes that ordinary instruction sampling rarely reaches:

| Leaf | Weight | Executed focus |
|---|---:|---|
| `engine-state-scalar-control` | 3 | Scalar arithmetic, structured branches, a 1–8-trip bounded loop, global mutation, integer/float exact-bit observations, and multi-value results. |
| `engine-state-calls` | 2 | Direct calls, a call chain, bounded indirect calls through an initialized table, and a multi-value float call. |
| `engine-state-memory` | 2 | In-bounds loads/stores, `memory.fill`, one guaranteed `memory.grow`, and active data initialization. |
| `engine-state-table` | 1 | Table mutation, one bounded `table.grow`, active elements, exported function identities, and a valid indirect call. |
| `engine-state-simd` | 1 | Deterministic SIMD computation with `v128` results stored into exported observation-memory slots. |
| `engine-state-imports` | 2 | Fixed deterministic function imports plus imported mutable global, memory, and table state. |
| `engine-state-initialization` | 1 | Active data/elements, start-order reads, mutable global initialization, and multiple export aliases for the same resources. |
| `engine-state-trap` | 2 | An observable committed prefix followed by one intended deterministic trap frontier. |
| `engine-state-mixed` | 2 | A bounded scalar/call/memory/table/SIMD combination driven and observed by start. |
| `engine-state-topology` | 4 | Deep direct chains, call diamonds, seed-selected join operations, and table dispatch. |
| `engine-state-effects` | 4 | Seed-selected operand order, nested call effects, branch effects, host marks, and exported global/memory mutations. |
| `engine-state-resources` | 4 | Overlapping active segments, memory/table copies, growth, mutation, and the full exported state lifecycle. |
| `engine-state-boundaries` | 3 | Integer edge classes, strict float bit classes, unaligned stores, and an exact-end memory access. |
| `engine-state-optimizer-shapes` | 3 | Wrappers, redundant locals, dropped constants, result blocks, constant control, and exported final state. |
| `engine-state-equivalent-families` | 6 | Four equivalent arithmetic/control forms plus a wrapper, with in-module comparisons that trap on disagreement. |
| `engine-state-passive-segments` | 4 | `memory.init`, `data.drop`, `table.init`, and `elem.drop`, with copied resource state observed after both segments are dropped. |
| `engine-state-instantiation-boundaries` | 3 | Active-data bounds failure, memory import-limit mismatch, and table import-limit mismatch before start. |
| `engine-state-multi-resource` | 4 | Two memories and two tables, cross-memory copy, cross-table copy, and independent growth. |
| `engine-state-stack-pressure` | 4 | A 16-parameter/eight-result call, result reduction, and a 64-value operand stack. |
| `engine-state-memory-aliasing` | 4 | Both overlapping-copy directions, unaligned access, mixed widths, and signed loads. |
| `engine-state-indirect-traps` | 3 | Null entries, wrong signatures, out-of-range indices, and table mutation before dispatch. |
| `engine-state-trap-placement` | 3 | A selected trap in a callee, block, loop, or taken branch after committed imported-resource effects. |
| `engine-state-cross-instance` | 3 | A provider exports memory, table, and mutable global; a consumer imports and mutates the same resources during start. |
| `engine-state-resource-exhaustion` | 3 | Deterministic failed `memory.grow` and `table.grow` at declared maxima. |
| `engine-state-decoder-topology` | 4 | Eleven small functions and custom payloads at 127/128/255-byte section-size boundaries. |
| `engine-state-tail-calls` | 1 | An observed `return_call` result. |
| `engine-state-typed-function-references` | 1 | An observed `ref.func` plus `call_ref` result. |
| `engine-state-memory64` | 1 | An i64-addressed memory64 load/store and `memory.size` result. |
| `engine-state-exceptions` | 1 | `try_table`, `throw`, and an observed caught i32 payload. |
| `engine-state-gc` | 1 | `struct.new` and `struct.get`, reduced to an observed i32 so no GC reference crosses the host boundary. |
| `engine-state-link-graph` | 3 | A provider, zero to two re-export relays, and a consumer share one memory, table, and global identity. |
| `engine-state-gc-graph` | 4 | A self-cycle, mutable array, i31 value, and dynamic `ref.test`, reduced to one scalar digest. |
| `engine-state-initialization-graph` | 4 | Imported immutable globals, extended constant expressions, active segments, and consumed passive segments. |
| `engine-state-exception-unwind` | 4 | State mutation before a caught throw routed through direct, indirect, `call_ref`, or tail calls. |
| `engine-state-type-call-matrix` | 4 | Direct, indirect, `call_ref`, and tail calls with integer, float, SIMD, reference, and multi-value results. |
| `engine-state-leb-index-boundaries` | 2 | Function index 128 and custom payload sizes 127, 128, 16,383, and 16,384. |
| `engine-state-table-reference-matrix` | 4 | Seed-rotated funcref, externref, typed funcref, and table64 cases with bulk and growth operations. |
| `engine-state-memory64-multi-memory` | 3 | One memory32 and one memory64 with independent address and result widths. |
| `engine-state-trap-commit-matrix` | 4 | Imported state commits before division, memory, null-call, or unreachable traps. |
| `engine-state-metamorphic-twins` | 4 | Two distinct module encodings compute and report the same seed-derived result. |
| `engine-state-compiler-boundaries` | 4 | Seed-rotated function counts, local counts, and 16-deep structured control. |
| `engine-state-nan` | 4 | NaN-producing arithmetic is reduced to stable classification, with exact signed-zero bits observed separately. |
| `engine-state-invalid-module` | 4 | Valid AST generation followed by one strict invalid magic, version, truncation, or section-length byte mutation. |

Aliases `engine-state` and `engine-state-all-profiles` resolve to the aggregate.

## Engine-oriented aggregate profiles

Four aggregate profiles provide smaller, purpose-built alternatives to undirected module sampling. Each uses a seed-rotated exact weighted cycle: after one complete cycle every declared leaf has appeared exactly at its configured weight. Batch manifests record the selected singleton profile, and tiering leaves additionally record their scale or dispatch mode in `profile_case_label`.

| Profile | Cycle | Use |
|---|---:|---|
| `engine-compile-shapes` | 48 | Compilation and optimizer-front-end diversity without depending on random section shape. It selects leaf profiles from flattening, block merging, DAE2, inlining, SSA, local coalescing/merging, memory packing, global reordering, segment state, and decoder/compiler boundaries. |
| `engine-proposal-matrix` | 24 | Proposal acceptance and interaction coverage. Ten single-proposal slots cover SIMD, GC/reference subtyping, EH, memory64/multi-memory, call topology, tail calls, typed function references, memory64, exceptions, and GC. Seven pairwise or higher-order interaction leaves receive weight two: type/call, exception unwind, GC graph, table/reference, memory64/multi-memory, recursive multivalue, and subtype/cast graphs. |
| `engine-state-core` | 64 | Successful, single-module, broadly supported runtime-state cases. It keeps scalar control, calls, memory/table/import state, initialization, topology/effects/resources, boundaries, optimizer/equivalence shapes, passive segments, stack/alias pressure, exhaustion results, decoder/LEB/compiler boundaries, and NaN classification. It intentionally excludes intended traps, invalid binaries, instantiation failures, proposal-only leaves, support-module graphs, and metamorphic twins. |
| `engine-tiering-stress` | 19 | Runtime tiering and hot-path shapes across eight leaves: scaled hot loops, large functions, deep call chains, wide fanout, mono/poly indirect dispatch, locals versus operand-stack pressure, memory growth plus repeated bounds checks, and repeatable GC allocation graphs. |

The tiering loop, indirect-call, and memory leaves rotate trip counts `256`, `1024`, `4096`, and `16384`. Call-chain and fanout leaves rotate widths `8`, `16`, `32`, and `64`; the large-function leaf rotates 32–128 locals and functions. Every workload is exported through the engine-state synthetic function-export convention as well as invoked by start. A runtime harness can therefore instantiate once and repeatedly invoke the focused export to cross its own tier-up thresholds. The GC leaf allocates a struct/array graph on each exported invocation.

Use `engine-compile-shapes` for broad compiler-shape input, then add `engine-proposal-matrix` as a separate capability lane rather than conflating a proposal rejection with a core compiler failure. Use `engine-state-core` for cross-engine execution where expected failures and support graphs are unwanted. Use `engine-tiering-stress` when the harness will repeatedly call exports and collect tier-specific behavior or performance evidence.

## Scenario diversity

The scenario leaves select a forced semantic motif before they derive constants. Seed bits then rotate structural alternatives inside that motif: join operators and table targets for topology, operand order and branch effects for effects, copy order and block/if wrappers for resources, integer and float edge operations for boundaries, both overlap directions for memory aliasing, three indirect failures, four trap placements, three instantiation failures, four equivalent arithmetic/control spellings, one to three support modules, four exception routes, four table kinds, four trap-commit classes, compiler thresholds, NaN operations, and four invalid binary mutations. Dedicated tests run forced seed slots without generator retry, which prevents invalid variants from silently biasing output back toward one accepted shape.

The equivalent-family leaf compares canonical, alternate, and wrapper results inside the generated module. A disagreement reaches `unreachable`; a successful start therefore supplies an independent in-module relation in addition to the Node-versus-Railshot observation comparison.

## Fixed fuzz ABI

Every engine-state module imports these functions from module `__fuzz`, in this function-index order:

```text
0 input_i32(channel: i32) -> i32
1 input_i64(channel: i32) -> i64
2 mark(event_id: i32)
3 observe_i32(value_id: i32, bits: i32)
4 observe_i64(value_id: i32, bits: i64)
```

The Node runtime derives input bits with a fixed SplitMix-style 64-bit mixer over only the case seed, channel, and width-specific salt. Replaying the same case seed and channel therefore returns identical bits; changing either changes the input stream without clocks, ambient randomness, or external state. `mark` and `observe_*` calls are retained in order in the import transcript.

Float results cross the ABI only after `i32.reinterpret_f32` or `i64.reinterpret_f64`. SIMD values never cross JavaScript: the start driver stores them in fixed slots in exported memory. Table references are represented relationally; potentially stored defined functions receive synthetic `__fuzz_func_N` exports.

The import-focused and trap leaves additionally use fixed resource imports:

```text
__fuzz.state_global_i32 : mutable i32 global
__fuzz.state_memory     : memory 1 2
__fuzz.state_table      : funcref table 4 8
```

## Structural and execution invariants

The dedicated builders enforce:

- one defined `[] -> []` start function;
- at least three generated workload functions, all invoked directly or through a deterministic reachable call path;
- a marker before each selected workload operation;
- exact recording or observable consumption of every returned value;
- a final marker `0x7fffffff` on successful leaves;
- synthetic exports for every generated or imported memory, table, and global;
- synthetic exports for potentially stored functions;
- passive segments only in the passive-lifecycle and initialization-graph leaves, with all dropped before final observation;
- no recursion, shared memory, atomics, wait/notify, continuations, relaxed SIMD, or hidden surviving mutable resources;
- GC objects stay internal and do not survive start; proposal operations occur only in leaves that name or combine those capabilities;
- bounded loops and explicit small resource maxima;
- deterministic bytes for a profile/seed pair.

The type/call and exception-unwind leaves intentionally combine proposal
features. The aggregate still excludes shared memory, atomics, wait/notify,
continuations, and relaxed SIMD.

Generic GenValid metamorphic transforms are rejected for engine-state profiles. This prevents an unrelated transform from adding passive segments, hidden resources, or driver-irrelevant code while leaving the profile label unchanged.

## Success and trap separation

The `engine-state-trap`, `engine-state-indirect-traps`, `engine-state-trap-placement`, and `engine-state-trap-commit-matrix` leaves end in an intended runtime trap. `engine-state-instantiation-boundaries` ends before start with an intended instantiation failure. `engine-state-invalid-module` fails during compilation. All other leaves complete normally and emit the completion marker. Any other outcome is a generator/profile failure.

`engine-state-trap` performs and observes three successful workload operations against host-owned imported state, emits pre-trap marker `0x70000000`, and then reaches exactly one frontier selected deterministically from the case seed:

- explicit `unreachable`;
- integer division by zero;
- signed division overflow;
- invalid float-to-integer conversion;
- out-of-bounds memory access;
- out-of-bounds table access.

No completion marker follows. The manifest describes this as `complete-externally-committed-prefix`, not as a complete failed-instance snapshot. The Node executor retains and snapshots the host-owned imported global, memory, and table objects even when start traps, while correctly reporting the overall observation as incomplete because no successful instance was returned.

## Manifest contracts

Batch manifests now use top-level schema `starshine.gen-valid.batch.v2`. Every record includes:

- root `seed`, derived `case_seed`, case `index`, selected profile, and generator attempts;
- final encoded `wasm_hash` using the repository's `fnv1a64-*` artifact identity;
- actual static instruction count;
- ordinary static `feature_facts`;
- optional nested `engine_state` metadata.

Engine-state records use compatible schema `starshine.gen-valid.engine-state.v3`
with profile version and generator build identity 4. They include:

- profile version and generator build identity;
- selected singleton leaf and intended `complete`, `runtime-trap`, `instantiation-failure`, or `compile-failure` outcome;
- completion/pre-trap markers and intended trap family;
- the exact fixed ABI and seed/channel derivation policy;
- resource and synthetic-export maps, including aliases and imported-versus-defined origin;
- observation IDs with function index, result index, Wasm type, and encoding;
- per-feature four-stage facts: `present_in_module`, `reachable_from_start`, `executed_by_driver`, and `observable_after_execution`;
- enabled/disabled proposal policy;
- actual static instruction count and hard budgets;
- hidden-state restrictions;
- strict-bit NaN policy, or classification-plus-signed-zero policy for the NaN leaf, and disabled relaxed-operation policy.

The top-level `acceptance_contract` records the required runtime floor keys. The generator self-checks deterministic leaf scheduling, singleton presence after one complete aggregate weighted cycle, transform absence, and the 4,096-instruction family hard limit before returning or writing a profile selection. The completeness threshold and manifest `weighted_cycle_cases` value are computed from the selected profile's current positive member weights—136 cases across 45 leaves for `engine-state-all`, and 64 cases across 20 leaves for `engine-state-core`. Shorter partial batches are accepted without a false missing-leaf error. Runtime executors remain responsible for floors that require execution evidence, including distinct state hashes, complete observations, failure-family outcomes, support-graph identity, and twin equivalence.

## Budgets

The current identity uses:

- 1–140 defined functions and at most 20 types;
- at most 16 parameters, 8 results, and 128 locals per function;
- body depth at most 16;
- 4,096 static instructions and a declared 5,000 dynamic-instruction ceiling;
- typical encoded size below 16 KiB and hard size at 256 KiB;
- at most two memories, with at most two initial pages;
- at most two tables and a declared 32-entry observation cap;
- at most 12 globals;
- at most four active data and four active element segments;
- total segment payload below 4 KiB;
- loop trip counts 1–8 in the current loop leaf, with a hard declared maximum of 16.

## Runtime observation

`starshine.optimizer-runtime-observation.v2` now serializes explicit `compilation` and `instantiation` outcomes in addition to start/export steps, ordered import events, globals, full-memory hashes and chunk hashes, table relations, aliases, and completeness diagnostics. Compilation can be succeeded/failed/unknown; instantiation can be succeeded, trapped, failed, timed out, unknown, or not attempted.

Node is the reference executor in this repository. Wago/Railshot consumes the
same FFI case and emits the same value and resource vocabulary without
engine-specific object or pointer identities.

## September 23 optimizer deep dive

One exact cycle of each engine-oriented aggregate was compared against every
one of the 59 direct passes exposed by the harness with verified Binaryen 132,
independent validation, determinism, codec idempotence, and a separate stateful
Node semantic lane. Across 9,145 requested cases, Starshine had zero validation,
generator, determinism, codec, or observed semantic failures. Fifty-nine
semantic checks were blocked by the intentionally nonterminating `ssa-loop`
leaf, once per pass.

The matrix is evidence that these profiles reach useful pass and tool
boundaries, not parity signoff. It found 1,984 strict structural differences
across all 236 pass/profile cells; their artifacts were suppressed in the broad
run and the families remain unclassified. It also found four Binaryen Flatten
assertions on valid exception inputs and a Node compact-import capability
boundary. A scaled OptimizeInstructions property lane exposed a separate
one-invocation fixed-point gap on `flatten-ifs`, `flatten-loops`, and
`ssa-merge-explicit`. Across 16 exact cycles per profile, the scaled lane
requested 2,480 cases and reproduced 48 structural-idempotence failures: each
of the three leaves failed once per compile-shapes cycle, while semantic
idempotence remained green and every failure converged at generation 3.

The full counts, classifications, minimal Binaryen repro, operational hazards,
local artifact map, and replay command are maintained in the
[engine-profile optimizer deep dive](engine-profile-deep-dive.md).

## Commands

The WasmGC foreign library provides a host-safe, one-case generation API:

```text
ffi_bridge::generate_engine_state_case(root_seed: i64, case_index: i32)
  -> EncodedEngineStateCase
```

The case index is one-based. The returned object exposes module bytes, zero or more ordered support-module byte arrays, an optional equivalent comparison module, the exact derived case seed, selected singleton profile, generator attempts, static instruction count, outcome kind, failure-family metadata, and diagnostic bytes through scalar accessors. Cross-instance uses one support module. Link-graph uses one to three. Metamorphic-twins supplies a comparison module. Invalid-module mutates its primary encoded bytes after the valid AST is encoded. This avoids passing MoonBit `String`, `Result`, `GenValidConfig`, or `Module` representations across the JavaScript boundary. Run `bun ffi build` before use; consumers load `dist/ffi/starshine-ffi.wasm` and pass the root seed as a JavaScript `BigInt`.

Emit one exact aggregate cycle:

```text
bun fuzz run --emit-gen-valid-batch \
  --count 136 \
  --seed 150937214 \
  --out-dir .tmp/engine-state \
  --manifest .tmp/engine-state/manifest.json \
  --gen-valid-profile engine-state-all \
  --max-attempts 136
```

The command above only generates and validates artifacts; it does not launch an engine or execute the start function.

Emit one exact cycle of any new aggregate by changing the profile and count:

```text
# compiler/optimizer structural diversity
--count 48 --gen-valid-profile engine-compile-shapes

# proposal and proposal-interaction matrix
--count 24 --gen-valid-profile engine-proposal-matrix

# successful portable engine-state cases
--count 64 --gen-valid-profile engine-state-core

# tiering shapes; execution remains a separate harness step
--count 19 --gen-valid-profile engine-tiering-stress
```

Validate emitted modules independently:

```text
for file in .tmp/engine-state/*.wasm; do
  wasm-tools validate --features all "$file"
done
```

For semantic optimizer execution, use Node observation v2 and pass the manifest record's `case_seed` into the runtime executor so `input_i32` and `input_i64` replay exactly.
