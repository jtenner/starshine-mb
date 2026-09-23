---
kind: research
status: working
last_reviewed: 2026-09-23
sources:
  - ../raw/binaryen/2026-09-23-v132-v133-release-inventory.json
  - https://github.com/WebAssembly/binaryen/releases/tag/version_133
  - https://github.com/WebAssembly/binaryen/compare/version_132...version_133
  - https://github.com/WebAssembly/binaryen/blob/version_133/CHANGELOG.md
  - https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/ConstraintAnalysis.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/TailCall.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/OptimizeInstructions.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/MakeSharedObjects.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/GlobalTypeOptimization.cpp
related:
  - version-132-upgrade.md
  - release-horizon-and-oracles.md
  - passes/tracker.md
  - ../../../agent-todo.md
---

# Binaryen 133 optimizer-shape intake

Binaryen `version_133` was published on 2026-09-21 at
`fba5005a132d85d578be5bd010e0487ed8e2ce3e`; `version_132` is
`79dfe6b412a3c22bfdb190ed6a4d79adf734db5d`. The exact tag range has
**107 commits and 292 changed paths**: 28 `src/passes/` paths, 22 `src/ir/`
paths, and 58 `test/lit/passes/` paths. The [raw inventory](../raw/binaryen/2026-09-23-v132-v133-release-inventory.json)
lists every commit subject and changed path, including API, parser, validator,
interpreter, wasm2js, fuzzing, CI, tooling, test, and NFC work that does not add
an optimizer rewrite. The short upstream changelog is not a complete pass-delta
inventory. The official Linux `wasm-opt` archive passed its published SHA-256
check; its binary reports `wasm-opt version 133 (version_133)` and hashes to
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.

**Repository comparison policy remains v132.** This page records v133 source
and oracle evidence for future implementation; it does not relabel v132 signoff
or turn the v133 binary into the ordinary compare-pass oracle. A focused red
test means the v133 result was checked and the current Starshine behavior is
missing. The red corpus is deliberately failing until the named pass, opcode,
or transform is implemented. `moon test` is therefore expected to fail on the
new files; see the exact files below.

## Released optimizer opportunities

The rows below are semantic input families. A family groups equivalent WAT
spellings and local numbering; the linked owner and released lit file provide
the finer variants. `Red` points to a focused failing Starshine test. `Covered`
means a focused Starshine check was already green. `Open` names a source-backed
variant for which this intake has not yet reduced a standalone red fixture.

### Constraint analysis and preset scheduling

Sources: [solver](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/ConstraintAnalysis.cpp),
[constraint domain](https://github.com/WebAssembly/binaryen/blob/version_133/src/ir/constraint.cpp),
[released tests](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/constraint-analysis.wast),
[loop tests](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/constraint-analysis-loops.wast),
and [float tests](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/constraint-analysis-float.wast).

| Shape | v133 observation | Local corpus |
| --- | --- | --- |
| Conjoined branch predicates, `a && b`, and their edge-specific negations | Carry both proved facts to the taken successor; short-circuit/tee writes still bound the proof. | Covered by the existing constraint suite; a new candidate also passed and was not retained as a red case. |
| Same-term local comparisons, such as `x < y` followed by `x != y` or `x <= y` | Prove related signed/unsigned predicates without requiring a constant operand. | Covered by the existing constraint suite and a green candidate. |
| Integer span endpoint, such as `x <u y` followed by `x != UINT_MAX` | Use the span implied by the first predicate to fold the second. | Red: [constraints corpus](../../../src/passes/binaryen133_constraints_red_wbtest.mbt). |
| `local.tee` inside a comparison, with a later predicate on the tee target | Parse the tee in execution order, transfer its value, and prove the later predicate. | Red: constraints corpus. |
| Constant or copied local value behind a block/select/tee fallthrough | Follow a safe fallthrough producer when building local facts; invalidate it after a later write. | Red: changed local behind a block fallthrough in constraints corpus; select/tee variants remain a targeted extension of the same producer walk. |
| Loop index starts at a constant and compares against a **local** upper bound | Widen the induction range, prove the index remains nonnegative, and terminate the analysis. Signed and unsigned loop forms are released. | Red: signed variable-bound loop in constraints corpus; covered: unsigned exit predicate in [existing coverage](../../../src/passes/binaryen133_existing_coverage_wbtest.mbt). |
| Contradiction, modular overflow, and unreachable continuation of the solver | Stop facts after unreachable control; do not infer a false proof from mixed signedness, overflow, or a short-circuited condition. | Safety boundary; existing constraint tests cover several, exact v133 edge cases open. |
| Floating-point comparisons with and without `--fast-math` | Without fast-math, retain NaN and signed-zero uncertainty; under fast-math, permit the released equality proofs. | Open: Starshine has no fast-math pass option yet. |
| `-O3` and `-Os` preset slots | Schedule `constraint-analysis` at optimize level at least 3 or shrink level at least 1. | Red: O3 and Os scheduler assertions in constraints corpus. |

### New `tail-call` pass

Sources: [owner](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/TailCall.cpp),
[core shapes](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/tail-call.wast),
[exception shapes](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/tail-call-eh.wast),
and [trap-policy shapes](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/tail-call-tnh.wast).
The [red pass corpus](../../../src/passes/binaryen133_new_passes_red_wbtest.mbt)
has one released-oracle-checked case for each of the following opportunities:

| Input shape | Required rewrite |
| --- | --- |
| Final void direct `call`; final value direct `call`; call enclosed by explicit `return`; void call immediately before `return` | `return_call`, preserving operands and the function result contract. |
| Callee result subtype of caller result; whole multivalue result | `return_call` without narrowing the caller's declared result. |
| Both arms of a tail `if`; one-arm tail `if` in a void function; tail loop fallthrough | Convert only calls on paths that exit the function. |
| Direct call used as a tail `br` value; tail `br_if` value with safe condition; `br_table` value when every target exits | Convert the value producer while preserving branch conditions and their effects. |
| Void call immediately before a branch out of the function | Convert the call in each proven exit path. |
| Final `call_indirect` and final `call_ref` | Emit `return_call_indirect` or `return_call_ref` with the same type/target evaluation. |

The owner additionally guards local exception handlers, potentially throwing
calls, unreachable operands, mismatched dead-code result types, effectful
conditional branches, non-tail switch targets, and already-tail calls. Those
are **eligibility/safety boundaries**, not additional positive rewrite
families. The released exception and TNH fixtures remain the source for
expanding that guard corpus. Starshine currently rejects the `tail-call` pass
name; all listed positive examples fail for that reason after their inputs
parse and validate.

### `optimize-instructions`: publish and resume

Sources: [owner](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/OptimizeInstructions.cpp),
[publish tests](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/optimize-instructions-publish.wast),
and [resume tests](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/optimize-instructions-resume.wast).

| Shape | v133 rewrite | Local corpus |
| --- | --- | --- |
| `publish(struct.new)` or `publish(struct.new_default)` for a fresh shared struct | Remove `publish`; keep allocation and operand order. | Red: [publish corpus](../../../src/passes/binaryen133_publish_red_wbtest.mbt). |
| `publish(array.new)`, `array.new_default`, `array.new_fixed`, `array.new_data`, or `array.new_elem` | Remove `publish` for each fresh shared allocation opcode. | Red: one oracle-checked test for each opcode in publish corpus. |
| `publish(publish(x))` | Remove only the outer publish. | Red: publish corpus. |
| A publish value reached through a transparent block or non-null cast; a value whose heap type cannot be a shared struct/array | Remove the redundant publish without moving effects or traps. | Red: block, `ref.as_non_null`, unshared struct, and nested publish through block in publish corpus. |
| A fresh `cont.new(ref.func $known)` whose exact local callee cannot suspend, immediately resumed | Replace allocation and resume with direct `call`, preserving operands, traps, and handler effects. | Red: [binary resume fixture](../../../src/passes/binaryen133_resume_red_wbtest.mbt); local `global-effects` prerequisite is boundary-only. |
| Resume through a transparent block/cast and TNH-permitted tee/branch | Same direct-call rewrite only when single-shot use and trap policy allow it. | Red: transparent block in resume corpus; cast and TNH variants remain eligibility extensions. |

The new `publish` opcode is not yet represented by Starshine's WAT/parser/IR.
The publish tests therefore fail at the exact parser floor, before the
optimizer. The resume test embeds the 54-byte v133 input module because the
local stack-switching text grammar is still missing; it decodes locally and
fails at the boundary-only `global-effects` prerequisite. The same v133 binary
with `--generate-global-effects --optimize-instructions` yields a direct call.

The owner also tightens two safety rules: an inner descriptor cast cannot be
removed across an effectful outer descriptor operand, and
`optimize-instructions-never-fold-or-reorder` cannot move a non-null trap across
branch-hint metadata. Descriptor operand fallthrough now records the
descriptor's effects. These are parity and ordering guards; a valid but
different-looking output is not acceptance evidence.

### Whole-module, lowering, and other pass changes

| Shape | v133 behavior | Local corpus |
| --- | --- | --- |
| Export of a defined `nop` function, including aliases; export of a defined empty-block function | New `remove-empty-function-exports` removes only the export and leaves the function for later cleanup. Imported and nonempty bodies stay exported. [Owner](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/RemoveEmptyFunctionExports.cpp). | Red: two cases in new-pass corpus. |
| Nullable and non-null `externref` across exported/imported functions; explicit `extern.convert_any` / `any.convert_extern` | `make-shared-objects` represents external references with dynamically grown table indices encoded as shared i31 references, adds boundary wrappers, and preserves null/non-null conversion. [Owner](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/MakeSharedObjects.cpp); [tests](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/make-shared-objects.wast). | Red: five export/import/conversion cases in new-pass corpus. |
| Ordinary struct and array definitions, their uses, and reference fields | `make-shared-objects` changes the definitions to shared types and remaps references; function definitions remain unshared. | Red: direct type-metadata assertions for struct, array, a recursive function signature, and a function-reference struct field in new-pass corpus. |
| `funcref` and ordinary `anyref` in function signatures | Lower a function reference to a shared i31 index and an any reference to a shared any reference. | Red: direct signature-type assertions in new-pass corpus. |
| Descriptor field that would become a JS prototype after an earlier field is removed or made immutable | GTO inserts an immutable i8 placeholder, retains externally visible prototype semantics, and updates struct indices after operand localization. This also applies through inherited descriptor fields and `struct.wait`. [Owner](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/GlobalTypeOptimization.cpp); [tests](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/gto-jsinterop.wast). | Red: [direct and inherited GTO placeholder cases](../../../src/passes/binaryen133_gto_red_wbtest.mbt), including a subtype field-index remap; `struct.wait` remains a proposal boundary. |
| Saturating `f32`/`f64` to signed/unsigned `i64` conversions, after flattening | `i64-to-i32-lowering` now lowers all four opcodes into i32 halves. Its documented float conversion arithmetic is wasm2js-oriented and does not preserve ordinary Wasm trap semantics in all cases. [Owner](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/I64ToI32Lowering.cpp); [tests](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/flatten_i64-to-i32-lowering.wast). | Red: [four lowering cases](../../../src/passes/binaryen133_i64_lowering_red_wbtest.mbt). |
| Tail `call.without.effects` intrinsic with static `ref.func` or a dynamic function reference | `intrinsic-lowering` keeps tail position as `return_call` or `return_call_ref`. [Owner](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/Intrinsics.cpp). | Red: [two intrinsic cases](../../../src/passes/binaryen133_intrinsic_tail_red_wbtest.mbt). |
| Atomic load/store sent to `dealign` | Keep required natural alignment; ordinary non-atomic access may still be de-aligned. [Owner](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeAlign.cpp). | Red: [load and store cases](../../../src/passes/binaryen133_dealign_red_wbtest.mbt). |
| Two identical atomic RMW results used by a `select` | Treat each read-write result as generative and retain both evaluations. The same rule now covers atomic cmpxchg, atomic wait/notify, waitqueue notify, and GC struct/array RMW/cmpxchg. [Owner](https://github.com/WebAssembly/binaryen/blob/version_133/src/ir/properties.cpp). | Covered: [atomic RMW behavior test](../../../src/passes/binaryen133_existing_coverage_wbtest.mbt) passes locally; remaining opcode variants open. |

Several released edits constrain existing passes rather than adding a new
positive rewrite: open-world `merge-similar-functions` must not promote an
invalid exact private signature to a public type;
`type-refining`/GUFA must still fix a reachable cmpxchg replacement when only
another operand is unreachable; `unsubtyping` must repair block-nested EH pops
and descriptor squares; `global-effects` must carry a separate suspension
effect; GUFA must skip switch handlers without a target; and `struct.wait`
expected/reference field types must be updated after type changes. The
[merge regression](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/dae-merge-similar-functions-exact.wast),
[type-refining regression](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/type-refining-gufa-rmw.wast),
[unsubtyping regression](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/unsubtyping-desc.wast),
and [effects tests](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/global-effects-suspends.wast)
are the primary follow-up fixtures. The v133 DAE2 indirect-return-call repair
was already incorporated into Starshine's v132 intake as the then-post-tag
`#8994` fix; it is not counted as a newly missing v133 behavior.

## Other v133 changes and boundaries

The 107-commit range also changes validation and source representation:
`publish` syntax/binary/typing, `struct.wait` on equality-comparable fields
except floats, natural-alignment rejection for atomics, remaining FP16 feature
checks, descriptor finality/subtyping, declarative-element tag indices,
`br_on_cast_desc_eq` null sent types, and primitive GC array literal storage.
There are C/JS API additions for `try_table`, `throw_ref`, waitqueue instructions,
and JS type enums; wasm2js gains direct nontrapping float-to-int translation;
wasm-split, fuzzing, parallel test execution, CI and NFC edits account for many
of the remaining paths. The [complete path/commit inventory](../raw/binaryen/2026-09-23-v132-v133-release-inventory.json)
is the source for exact classification of any omitted non-optimizer file.

No 10,000-case v133 compare-pass campaign was run: the repository's normal
comparison contract still requires a verified v132 oracle, and this change
only adds red corpus inputs. Do not treat these focused v133 oracle results as
pass signoff. The open variants above remain explicit work for the next corpus
slice, alongside implementation of the red cases.
