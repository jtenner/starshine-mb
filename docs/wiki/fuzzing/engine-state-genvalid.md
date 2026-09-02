---
kind: workflow
status: working
last_reviewed: 2026-09-02
sources:
  - ../../../ffi/README.md
  - ../../../src/ffi_bridge/ffi_bridge.mbt
  - ../../../src/ffi_bridge/ffi_bridge_test.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/validate/gen_valid_engine_state.mbt
  - ../../../src/validate/gen_valid_engine_state_wbtest.mbt
  - ../../../src/fuzz/main.mbt
  - ../../../src/fuzz/engine_state_manifest_wbtest.mbt
  - ../../../scripts/lib/optimizer-runtime.ts
  - ../../../scripts/lib/optimizer-runtime-executor.ts
  - ../../../scripts/lib/optimizer-runtime-executor.test.ts
related:
  - ./generator-coverage-ledger.md
  - ./semantic-optimizer-campaigns.md
  - ../tooling/fuzz-runner.md
---

# Engine-State GenValid Profiles

## Purpose

The `engine-state-*` family generates compact deterministic Wasm test programs from the start driver outward. A case is credited only for behavior that the start driver reaches and executes and that becomes observable through the fixed host transcript or exported resource state. Static opcode presence remains available through ordinary `GenValidFeatureFacts`, but does not satisfy the engine-state execution facts in the nested manifest.

The intended cross-engine contract is:

> Given the same Wasm bytes, case seed, and fixed `__fuzz` ABI, an executor compiles and instantiates the module within a strict budget, records the ordered start transcript, and serializes all observable post-start state canonically.

## Profile family

`engine-state-all` is a seed-rotated exact 40-case weighted cycle. Every contiguous 40 selected cases realizes the declared weights exactly, so every singleton leaf is present without probabilistic retry. The mix reserves 40% for the original execution leaves, 45% for forced semantic scenarios, and 15% for self-checking equivalent families:

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

Aliases `engine-state` and `engine-state-all-profiles` resolve to the aggregate.

## Scenario diversity

The six scenario leaves select a forced semantic motif before they derive constants. Seed bits then rotate structural alternatives inside that motif: join operators and table targets for topology, operand order and branch effects for effects, copy order and block/if wrappers for resources, integer and float edge operations for boundaries, four cleanup/constant-control shapes for optimizer code, and four equivalent arithmetic/control spellings for equivalence checks. Dedicated tests run the forced seed slots without generator retry, which prevents invalid variants from silently biasing the output back toward one accepted shape.

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
- only active data and element segments;
- no recursion, shared memory, atomics, wait/notify, GC objects, continuations, relaxed SIMD, memory64, or hidden mutable resources;
- bounded loops and explicit small resource maxima;
- deterministic bytes for a profile/seed pair.

Generic GenValid metamorphic transforms are rejected for engine-state profiles. This prevents an unrelated transform from adding passive segments, hidden resources, or driver-irrelevant code while leaving the profile label unchanged.

## Success and trap separation

All leaves except `engine-state-trap` complete normally and emit the completion marker. An accidental trap is a generator/profile failure.

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

Engine-state records use `starshine.gen-valid.engine-state.v2` and include:

- profile version and generator build identity;
- selected singleton leaf and intended `complete` or `trap` outcome;
- completion/pre-trap markers and intended trap family;
- the exact fixed ABI and seed/channel derivation policy;
- resource and synthetic-export maps, including aliases and imported-versus-defined origin;
- observation IDs with function index, result index, Wasm type, and encoding;
- per-feature four-stage facts: `present_in_module`, `reachable_from_start`, `executed_by_driver`, and `observable_after_execution`;
- enabled/disabled proposal policy;
- actual static instruction count and hard budgets;
- hidden-state restrictions;
- strict-bit NaN policy and disabled relaxed-operation policy.

The top-level `acceptance_contract` records the required runtime floor keys. The generator self-checks deterministic leaf scheduling, singleton presence for aggregate batches of at least 20 cases, transform absence, and the 512-instruction hard limit before returning or writing a profile selection. Runtime executors remain responsible for floors that require execution evidence, including distinct state hashes, complete observations, and trap-family outcomes.

## Budgets

The current identity uses:

- 4–12 defined functions and at most 12 types;
- at most 4 parameters, 3 results, and 12 locals per function;
- body depth at most 5;
- 512 static instructions and a declared 5,000 dynamic-instruction ceiling;
- typical encoded size below 16 KiB and hard size at 64 KiB;
- at most one memory in current singleton builders, with at most two initial pages;
- at most two tables and a declared 32-entry observation cap;
- at most 12 globals;
- at most four active data and four active element segments;
- total segment payload below 4 KiB;
- loop trip counts 1–8 in the current loop leaf, with a hard declared maximum of 16.

## Runtime observation

`starshine.optimizer-runtime-observation.v2` now serializes explicit `compilation` and `instantiation` outcomes in addition to start/export steps, ordered import events, globals, full-memory hashes and chunk hashes, table relations, aliases, and completeness diagnostics. Compilation can be succeeded/failed/unknown; instantiation can be succeeded, trapped, failed, timed out, unknown, or not attempted.

Node is the implemented executor in this repository. Railshot and Dragline are not present here; they should consume the same batch/engine-state schemas and emit the same runtime-observation value/resource vocabulary rather than introducing engine-specific object or pointer identities.

## Commands

The WasmGC foreign library provides a host-safe, one-case generation API:

```text
ffi_bridge::generate_engine_state_case(root_seed: i64, case_index: i32)
  -> EncodedEngineStateCase
```

The case index is one-based. The returned object exposes module bytes, the exact derived case seed, selected singleton profile, generator attempts, static instruction count, intended-trap metadata, and diagnostic bytes through scalar accessors. This avoids passing MoonBit `String`, `Result`, `GenValidConfig`, or `Module` representations across the JavaScript boundary. Run `bun ffi build` before use; consumers load `dist/ffi/starshine-ffi.wasm` and pass the root seed as a JavaScript `BigInt`.

Emit one exact aggregate cycle:

```text
bun fuzz run --emit-gen-valid-batch \
  --count 40 \
  --seed 150937214 \
  --out-dir .tmp/engine-state \
  --manifest .tmp/engine-state/manifest.json \
  --gen-valid-profile engine-state-all \
  --max-attempts 20
```

Validate emitted modules independently:

```text
for file in .tmp/engine-state/*.wasm; do
  wasm-tools validate --features all "$file"
done
```

For semantic optimizer execution, use Node observation v2 and pass the manifest record's `case_seed` into the runtime executor so `input_i32` and `input_i64` replay exactly.
