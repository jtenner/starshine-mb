---
kind: specification
status: supported
last_reviewed: 2026-08-31
sources:
  - ../../../src/representation/compiler_facts.mbt
  - ../../../src/binary/compiler_facts_encode.mbt
  - ../../../src/binary/compiler_facts_decode.mbt
  - ../../../src/binary/compiler_fact_sites.mbt
  - ../../../src/validate/compiler_facts.mbt
  - ../../../src/passes/apply_compiler_facts.mbt
  - ../../../src/passes/directize.mbt
  - ../../../src/passes/optimize.mbt
  - ../../../src/passes/pass_manager.mbt
  - ../../../src/cmd/cmd.mbt
related:
  - custom-and-name-sections.md
  - instruction-and-expression-encoding.md
  - function-import-export-and-code-sections.md
  - type-table-memory-global-tag-sections.md
  - ../wasm-compilation-hints-boundary.md
---

# `compiler.facts` Version 1

## Status

**Version 1 is frozen by the 2026-08-31 schema-completion change.** The earlier implementation was pre-freeze and had no external producer commitment. The completed schema therefore expands version 1 in place rather than introducing version 2. Any future incompatible wire change requires a new version.

`compiler.facts` is a Starshine-specific advisory custom section. A normal WebAssembly engine can ignore it. Its presence, absence, truth, or falsity never changes ordinary WebAssembly validation or execution semantics. The section describes frontend knowledge; it does not request transformations.

## Trust And Security

Structural validation and factual truth are separate:

- structural validation checks indices, canonical sets, masks, ranges, instruction sites, result arity, opcode attachment, and type compatibility;
- structural validation does **not** prove non-nullness, exact targets, ranges, no-escape claims, effects, populations, or aliases true;
- producer metadata and the optional fingerprint are diagnostics/integrity metadata, not authenticity or trust mechanisms.

A malicious module can forge `producer = "dewdrop"` and every semantic assertion. Starshine therefore uses a nonserialized invocation policy:

| Policy | Meaning |
| --- | --- |
| `IgnoreFacts` | No hint or assertion affects optimization. Default for arbitrary input. |
| `HintsOnly` | Profitability hints may be used; semantic assertions may not change transformations. |
| `TrustAssertions` | Structurally valid assertions may be used as optimizer axioms in a controlled frontend pipeline. |

CLI spelling is `--compiler-facts=ignore`, `--compiler-facts=hints`, or `--compiler-facts=trust`. Optimization level and trust are independent. Producer name, section presence, filename, and `-O4`/`-O4z` never imply trust.

## Primitive Wire Rules

The custom section is:

```text
section id = 0
name = "compiler.facts"
payload = version:u32 + module_fingerprint:option<bytes> + OptimizationFactsSec
```

Version 1 uses only:

| Shape | Encoding |
| --- | --- |
| `Bool` | one byte `00` or `01` |
| enum | one explicit one-byte discriminator followed by its payload |
| `UInt` | existing unsigned u32 LEB |
| `UInt64` | existing unsigned u64 LEB |
| `Int64` | existing signed i64 LEB |
| array | u32 length followed by elements |
| option | `00`, or `01` followed by the value |
| bytes | u32 length followed by bytes |
| string | existing UTF-8 name/string length and bytes |

Unknown enum tags, invalid option tags, invalid booleans/masks, truncation, unsupported versions, duplicate reserved sections, and trailing payload bytes are rejected. There is no TLV layer, reflection, schema compiler, compression, interning, JSON, CBOR, or protobuf.

## Top-Level Order

`OptimizationFactsSec` is encoded in this exact order:

```text
producer: option<ProducerInfo>
world: option<WorldFacts>
functions: array<FunctionFacts>
signatures: array<SignatureFacts>
types: array<TypeFacts>
globals: array<GlobalFacts>
tables: array<TableFacts>
bodies: array<FunctionBodyFacts>
hints: array<OptimizationHint>
```

All arrays default to empty. Missing producer and world records are valid. Missing world facts mean open/unknown, never closed.

## Sites And Index Meaning

`CodeSite(function, offset)` uses an absolute WebAssembly function index and a canonical opcode byte offset. `ValueSite(site, result)` adds the produced-result ordinal. Result `0` is used for ordinary single-result instructions.

The offset is measured from the first instruction opcode after the function local-declaration vector. Starshine computes offsets with the production instruction encoder, including canonical LEB sizes and synthesized string-reference indices. `else`, `catch`, `delegate`, and `end` delimiters are not sites. `compiler_fact_opcode_sites` and `compiler_fact_module_opcode_sites` pair the canonical offsets with exact source instructions in one scan.

Validation requires:

- the function exists and has a defined body for body/site facts;
- the offset names an actual opcode start;
- `ValueSite.result` is below that instruction's result arity, not merely below the containing function result count;
- call, allocation, access, numeric, and loop facts attach to compatible opcodes.

All raw function, type, global, memory, and table fields use absolute WebAssembly index spaces. Function indices include imported functions.

## Closed Sets And Upper Bounds

Closed sets always use this meaning:

```text
None                 = unknown
Some(closed {})      = impossible / no members
Some(closed {X})     = exactly X
Some(closed {X, Y})  = X and Y are every possible member
```

Constructors normalize deterministically. Closed values, heap types, aliases, and integer-index sets are sorted and duplicate-free. Table entries are sorted by slot and duplicate slots are rejected. Missing closed sets are never interpreted as empty.

`EffectFacts.may` and parameter-use/escape masks are positive upper bounds. A broad effect bit with no matching resource set means the resource set is unknown. A present set is complete.

## Value Domain

`ValueFacts` contains optional, reusable domains:

```text
possible_values: ClosedValueSet?
integer: IntegerFacts?
float_: FloatFacts?
vector: VectorFacts?
reference: ReferenceFacts?
```

`FactValue` stores raw exact values without host floating-point canonicalization:

- integer width plus raw bits;
- f32 and f64 IEEE bit patterns;
- low/high v128 bits;
- typed reference null;
- absolute `ref.func` target;
- immutable-global identity.

Integer widths are `Int8`, `Int16`, `Int32`, and `Int64`. `Int8`/`Int16` support packed WasmGC storage facts. `KnownBits` requires disjoint known-zero/known-one masks inside the owning width. Integer ranges must be ordered and fit the width. Straightforward contradictions such as exact zero plus `nonzero=true` are rejected.

Float facts use `Float32`/`Float64` and a class mask for positive/negative zero, positive/negative normal, positive/negative subnormal, positive/negative infinity, and NaN. Exact constants remain bit patterns in `ClosedValueSet`; there is no `fast_math` boolean.

Reference facts keep nullability separate from heap and function-target domains. A nonempty function target set does not itself imply non-null. Heap facts support exact runtime type, subtype upper bound, and a closed runtime-type set over nominal and supported abstract heap types.

Vector version 1 contains known v128 bits, optional scalar splat, and optional lane shape. It intentionally has no symbolic per-lane range system.

## Stable Value And Alias References

`ValueRef` can name:

- an instruction result (`ValueSite`);
- a function parameter;
- a function result;
- a global.

`ResultIdentityFacts` is either a fresh reference or a complete closed alias set. Alias sources can name parameters, globals, or instruction results. Every referenced index and result ordinal is structurally validated.

## Function, Signature, Type, Global, Table, And Allocation Facts

Function facts retain effect summaries, per-parameter value/use/escape facts, per-result value/identity facts, boundary facts, profile hints, and inline policy.

Signature facts reference a function type index and provide indexed parameter/result value domains plus `call_sites_complete`. Type facts provide optional population facts, struct field facts, and array element facts. Field/array stored domains are checked against storage representation. Write facts distinguish no writes, initialization-only writes, and complete write-site sets.

Global facts separate initial and steady-state values from mutation phase/sites. Table facts carry mutation, growth, default value, sorted slot values, and a `contents_complete` bit. `contents_complete=false` leaves unlisted slots unknown.

Allocation facts distinguish struct, array, closure, box, and other GC allocations. They carry escape sinks, identity observation, thread confinement, optional array length, and field records. Allocation site opcodes and type shapes must agree structurally.

Access facts carry `in_bounds` and optional log2 alignment. Numeric-operation facts carry signed/unsigned no-wrap and exact-division assertions. These assertion families are serialized and validated but are not consumed in version 1's first optimizer integration.

## Relations And Provenance

Point-scoped relations compare a `ValueRef` or exact `FactValue` with equality, inequality, signed/unsigned order, same-reference, or distinct-reference predicates. Arbitrary symbolic expressions are intentionally absent.

`SourceProvenance` contains optional module, declaration, body, expression, source-offset, and specialization ids. Starshine treats these as opaque diagnostics metadata. Provenance can enrich validation diagnostics but never affects legality.

## Hints Versus Assertions

Hints are distinct variants and cannot justify correctness-sensitive rewrites:

- temperature/hotness;
- inline policy;
- speed/balanced/size goal;
- branch probability;
- estimated loop trips;
- likely call target;
- likely heap type.

Probability/confidence values use the inclusive integer domain `0..65535`. `AlwaysInline` remains a strong profitability hint and cannot bypass validation, recursion safety, unsupported shapes, or hard compiler resource limits.

Assertions include exact call target, non-null, exact/closed heap domain, closed values, ranges, known bits, effects, escape/identity, type populations, accesses, no-wrap, and relations. Assertions influence transformations only under `TrustAssertions`.

## Enum Discriminators

| Type | Tags |
| --- | --- |
| `WorldMode` | `00 OpenWorld`, `01 ClosedModule`, `02 ClosedProgram` |
| `IntWidth` | `00 Int8`, `01 Int16`, `02 Int32`, `03 Int64` |
| `FactHeapType` | `00 TypeIndex`, `01 Any`, `02 Eq`, `03 Struct`, `04 Array`, `05 I31`, `06 Func`, `07 Extern`, `08 Exn`, `09 Cont`, `0A String`, `0B None`, `0C NoFunc`, `0D NoExtern`, `0E NoExn`, `0F NoCont` |
| `FactValue` | `00 Integer`, `01 F32Bits`, `02 F64Bits`, `03 V128`, `04 RefNull`, `05 RefFunc`, `06 ImmutableGlobal` |
| `FloatWidth` | `00 Float32`, `01 Float64` |
| `NullabilityFacts` | `00 NullOnly`, `01 NonNull` |
| `HeapDomain` | `00 ExactRuntimeType`, `01 SubtypesOf`, `02 ClosedRuntimeTypes` |
| `VectorLaneShape` | `00 I8x16`, `01 I16x8`, `02 I32x4`, `03 I64x2`, `04 F32x4`, `05 F64x2` |
| `ValueRef` | `00 Site`, `01 Parameter`, `02 FunctionResult`, `03 Global` |
| `AliasSource` | `00 Parameter`, `01 Global`, `02 Site` |
| `ResultIdentityFacts` | `00 FreshReference`, `01 ClosedAliases` |
| `TemperatureHint` | `00 Cold`, `01 Normal`, `02 Hot` |
| `InlinePolicy` | `00 Default`, `01 Never`, `02 Prefer`, `03 Always` |
| `TypeView` | `00 Exact`, `01 SubtypeClosure` |
| `TypePopulation` | `00 Empty`, `01 Closed` |
| `WriteFacts` | `00 NoWrites`, `01 InitializationOnly`, `02 ClosedWrites` |
| `MutationPhase` | `00 Never`, `01 InitializationOnly`, `02 Runtime` |
| `AllocationKind` | `00 Struct`, `01 Array`, `02 Closure`, `03 Box`, `04 OtherGc` |
| `FactOperand` | `00 Value`, `01 Constant` |
| `RelationKind` | `00 Equal`, `01 NotEqual`, `02 SignedLessThan`, `03 SignedLessOrEqual`, `04 UnsignedLessThan`, `05 UnsignedLessOrEqual`, `06 SameReference`, `07 DistinctReferences` |
| `OptimizationGoal` | `00 PreferSpeed`, `01 Balanced`, `02 PreferSize` |
| `HintTarget` | `00 Function`, `01 Site` |
| `OptimizationHint` | `00 Hotness`, `01 Inline`, `02 Goal`, `03 BranchProbability`, `04 EstimatedLoopTrips`, `05 LikelyCallTarget`, `06 LikelyHeapType` |

## Mask Bits

### `FloatClassMask`

| Bit | Meaning |
| ---: | --- |
| 0 | positive zero |
| 1 | negative zero |
| 2 | positive normal |
| 3 | negative normal |
| 4 | positive subnormal |
| 5 | negative subnormal |
| 6 | positive infinity |
| 7 | negative infinity |
| 8 | NaN |

### `ParameterUseMask`

| Bit | Meaning |
| ---: | --- |
| 0 | direct computation |
| 1 | control |
| 2 | address/index |
| 3 | call argument |
| 4 | stored value |
| 5 | returned |
| 6 | identity observed |

### `EscapeSinkMask`

| Bit | Meaning |
| ---: | --- |
| 0 | return |
| 1 | call |
| 2 | global |
| 3 | memory |
| 4 | table |
| 5 | GC heap |
| 6 | throw |
| 7 | host/unknown |

### `EffectMask`

| Bit | Meaning |
| ---: | --- |
| 0 | may trap |
| 1 | may throw |
| 2 | may diverge |
| 3 | may call unknown code |
| 4 | may call host code |
| 5 | may reenter |
| 6 | may suspend |
| 7 | may allocate GC |
| 8 | may observe reference identity |
| 9 | may produce nondeterministic results |
| 10 | may read global |
| 11 | may write global |
| 12 | may read memory |
| 13 | may write memory |
| 14 | may grow memory |
| 15 | may read table |
| 16 | may write table |
| 17 | may grow table |
| 18 | may read GC heap |
| 19 | may write GC heap |
| 20 | may synchronize |
| 21 | may wait or notify |
| 22 | local-state mutation (retained pre-freeze compatibility bit) |

Unknown bits are invalid.

## Materialization And Lifetime

When policy is `TrustAssertions`, Starshine runs `apply-compiler-facts` before the ordinary pass queue. This preparation stage is outside Binaryen-compatible scheduler slots, so the locked O4z roster and slot numbering remain unchanged.

The first semantic consumer is exact call target:

```text
arguments
reference-producing expression
call_ref $type
```

becomes:

```text
arguments
reference-producing expression
drop
call $exact_target
```

`return_call_ref` similarly becomes `drop; return_call`. The explicit reference producer is never silently deleted. Its calls, allocations, mutable reads, traps, exceptions, and control effects still occur in the original order. The target function may be imported or defined. The rewrite requires target existence and signature compatibility and fails closed by retaining the original reference call.

Exact targets can come from `CallSiteFacts.direct_target` or a singleton exact function-reference value fact on the call's target-producing root. Conflicts are not resolved by last-wins behavior.

After trusted body-relative facts are materialized, the compiler-facts section is cleared before ordinary rewrites can stale offsets. Other index/body-changing `Module` helpers also clear facts conservatively. There is no general fact remapping framework in version 1.

Absent-section fast path:

```text
no compiler_fact_custom_section
  -> no fact index
  -> no opcode-site map
  -> no materializer traversal
```

## Current Consumers

| Fact | Current consumer |
| --- | --- |
| Exact call target | `apply-compiler-facts`; `call_ref -> drop; call`, `return_call_ref -> drop; return_call` under `TrustAssertions` |
| Inline policy | serialized/validated hint; not yet wired to the inliner |
| Hotness/profile/goal hints | serialized/validated; not yet consumed |
| Non-null/reference heap facts | not yet consumed |
| Integer ranges/known bits/exact values | not yet consumed |
| Float classes | not yet consumed |
| Vector facts | not yet consumed |
| Effect summaries | not yet consumed |
| Parameter uses/escape | not yet consumed |
| Result aliases | not yet consumed |
| Type/field/array facts | not yet consumed |
| Global/table facts | not yet consumed |
| Allocation facts | not yet consumed |
| Access/no-wrap/relational facts | not yet consumed |
| Source provenance | diagnostics only |
| Producer/fingerprint | diagnostics/integrity metadata only; never trust |

Serialization and validation do not imply optimizer support.

## Component Model Boundary

The generated Component Model facade remains rooted at `@lib.Module`. Representation-owned fact constructors are intentionally not recursively exposed through WIT. Compiler facts enter through the native/library representation API or binary decode. Component clients may preserve or clear an existing section without constructing the full representation graph.
