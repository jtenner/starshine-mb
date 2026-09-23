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

**Repository comparison policy remains v132.** The v133 oracle supplied the
new input shapes, while the repository's ordinary compare-pass baseline remains
v132. The initial red-first corpus reached 61 green focused tests and
12,334/12,334 default wasm-gc tests in `00ba1836a`. Four fuzz follow-up tests
bring the focused corpus to 65 cases; the refreshed default suite passes
12,338/12,338. These checks establish the listed behavior, not broad pass
parity; dedicated pass results are below.

## Released optimizer opportunities

The rows below are semantic input families. A family groups equivalent WAT
spellings and local numbering; the linked owner and released lit file provide
the finer variants. `Green` points to a focused Starshine test that failed before implementation and now passes. `Covered`
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
| Integer span endpoint, such as `x <u y` followed by `x != UINT_MAX` | Use the span implied by the first predicate to fold the second. | Green: [constraints corpus](../../../src/passes/binaryen133_constraints_red_wbtest.mbt). |
| `local.tee` inside a comparison, with a later predicate on the tee target | Parse the tee in execution order, transfer its value, and prove the later predicate. | Green: constraints corpus. |
| Constant or copied local value behind a block/select/tee fallthrough | Follow a safe fallthrough producer when building local facts; invalidate it after a later write. | Green: changed local behind a block fallthrough in constraints corpus; select/tee variants remain a targeted extension of the same producer walk. |
| Loop index starts at a constant and compares against a **local** upper bound | Widen the induction range, prove the index remains nonnegative, and terminate the analysis. Signed and unsigned loop forms are released. | Green: signed variable-bound loop in constraints corpus; covered: unsigned exit predicate in [existing coverage](../../../src/passes/binaryen133_existing_coverage_wbtest.mbt). |
| Contradiction, modular overflow, and unreachable continuation of the solver | Stop facts after unreachable control; do not infer a false proof from mixed signedness, overflow, or a short-circuited condition. | Safety boundary; existing constraint tests cover several, exact v133 edge cases open. |
| Floating-point comparisons with and without `--fast-math` | Without fast-math, retain NaN and signed-zero uncertainty; under fast-math, permit the released equality proofs. | Green: [command-level fast-math fixture](../../../src/cmd/binaryen133_fast_math_red_wbtest.mbt) for a known local f64 equality; the CLI now forwards this option. |
| `-O3` and `-Os` preset slots | Schedule `constraint-analysis` at optimize level at least 3 or shrink level at least 1. | Green: O3 and Os scheduler assertions in constraints corpus. |

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
expanding that guard corpus. Starshine now registers `tail-call` and converts
the focused function-exit shapes with whole-module validation rollback.

### `optimize-instructions`: publish and resume

Sources: [owner](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/OptimizeInstructions.cpp),
[publish tests](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/optimize-instructions-publish.wast),
and [resume tests](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/optimize-instructions-resume.wast).

| Shape | v133 rewrite | Local corpus |
| --- | --- | --- |
| `publish(struct.new)` or `publish(struct.new_default)` for a fresh shared struct | Remove `publish`; keep allocation and operand order. | Green: [publish corpus](../../../src/passes/binaryen133_publish_red_wbtest.mbt). |
| `publish(array.new)`, `array.new_default`, `array.new_fixed`, `array.new_data`, or `array.new_elem` | Remove `publish` for each fresh shared allocation opcode. | Green: one oracle-checked test for each opcode in publish corpus. |
| `publish(publish(x))` | Remove only the outer publish. | Green: publish corpus. |
| A publish value reached through a transparent block or non-null cast; a value whose heap type cannot be a shared struct/array | Remove the redundant publish without moving effects or traps. | Green: block, `ref.as_non_null`, unshared struct, and nested publish through block in publish corpus. |
| A fresh `cont.new(ref.func $known)` whose exact local callee cannot suspend, immediately resumed | Replace allocation and resume with direct `call`, preserving operands, traps, and handler effects. | Green: [binary resume fixture](../../../src/passes/binaryen133_resume_red_wbtest.mbt) through the active `global-effects` pass. |
| Resume through a transparent block/cast and TNH-permitted tee/branch | Same direct-call rewrite only when single-shot use and trap policy allow it. | Green: transparent block in resume corpus; cast and TNH variants remain eligibility extensions. |

Starshine now represents `publish` in text, binary, IR, and validation. The
optimizer removes only the focused provably redundant forms. The resume test
still embeds the 54-byte v133 input module because the local stack-switching
text grammar is missing; `global-effects` now folds the fresh, non-suspending
target before subsequent cleanup.

The owner also tightens two safety rules: an inner descriptor cast cannot be
removed across an effectful outer descriptor operand, and
`optimize-instructions-never-fold-or-reorder` cannot move a non-null trap across
branch-hint metadata. Descriptor operand fallthrough now records the
descriptor's effects. These are parity and ordering guards; a valid but
different-looking output is not acceptance evidence.

### Whole-module, lowering, and other pass changes

| Shape | v133 behavior | Local corpus |
| --- | --- | --- |
| Export of a defined `nop` function, including aliases; export of a defined empty-block function | New `remove-empty-function-exports` removes only the export and leaves the function for later cleanup. Imported and nonempty bodies stay exported. [Owner](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/RemoveEmptyFunctionExports.cpp). | Green: two cases in new-pass corpus. |
| Nullable and non-null `externref` across exported/imported functions; explicit `extern.convert_any` / `any.convert_extern` | `make-shared-objects` represents external references with dynamically grown table indices encoded as shared i31 references, adds boundary wrappers, and preserves null/non-null conversion. [Owner](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/MakeSharedObjects.cpp); [tests](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/make-shared-objects.wast). | Green: five export/import/conversion cases in new-pass corpus. |
| Ordinary struct and array definitions, their uses, and reference fields | `make-shared-objects` changes the definitions to shared types and remaps references; function definitions remain unshared. | Green: direct type-metadata assertions for struct, array, a recursive function signature, and a function-reference struct field in new-pass corpus. |
| `funcref` and ordinary `anyref` in function signatures | Lower a function reference to a shared i31 index and an any reference to a shared any reference. | Green: direct signature-type assertions in new-pass corpus. |
| Descriptor field that would become a JS prototype after an earlier field is removed or made immutable | GTO inserts an immutable i8 placeholder, retains externally visible prototype semantics, and updates struct indices after operand localization. This also applies through inherited descriptor fields and `struct.wait`. [Owner](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/GlobalTypeOptimization.cpp); [tests](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/gto-jsinterop.wast). | Green: [direct and inherited GTO placeholder cases](../../../src/passes/binaryen133_gto_red_wbtest.mbt), including a subtype field-index remap; `struct.wait` remains a proposal boundary. |
| Saturating `f32`/`f64` to signed/unsigned `i64` conversions, after flattening | `i64-to-i32-lowering` now lowers all four opcodes into i32 halves. Its documented float conversion arithmetic is wasm2js-oriented and does not preserve ordinary Wasm trap semantics in all cases. [Owner](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/I64ToI32Lowering.cpp); [tests](https://github.com/WebAssembly/binaryen/blob/version_133/test/lit/passes/flatten_i64-to-i32-lowering.wast). | Green: [four lowering cases](../../../src/passes/binaryen133_i64_lowering_red_wbtest.mbt). |
| Tail `call.without.effects` intrinsic with static `ref.func` or a dynamic function reference | `intrinsic-lowering` keeps tail position as `return_call` or `return_call_ref`. [Owner](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/Intrinsics.cpp). | Green: [two intrinsic cases](../../../src/passes/binaryen133_intrinsic_tail_red_wbtest.mbt). |
| Atomic load/store sent to `dealign` | Keep required natural alignment; ordinary non-atomic access may still be de-aligned. [Owner](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeAlign.cpp). | Green: [load and store cases](../../../src/passes/binaryen133_dealign_red_wbtest.mbt). |
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

The initial green phase adds `ref.i31_shared`, shared-object boundary wrappers,
type remapping, four saturating i64 conversions, and the registered pass
implementations described above. It was committed as `00ba1836a` **before**
the fuzz phase. The i64 implementation covers the four new conversions, not
the complete wasm2js i64 pass. GTO and shared-object lowering retain validation
rollback where current representation does not prove a safe rewrite.

## Post-commit fuzz investigation

All rows below used the official v133 `wasm-opt` SHA-256
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`,
the explicit native release Starshine executable, eight subprocesses, and
deterministic GenValid seed `0x5eed`. The separate CA v132 row used the
checksum-verified official v132 binary SHA-256
`1014958e6f20d412f1542320b43970214b0fb1ed780595e8f7c0d8761ed53725`.
The ordinary comparison target remains v132. The table describes the first
post-commit run; a mismatch is an **open parity difference** until semantic and
size evidence supports a more specific judgment.

| Pass and generator profile | Compared / normalized match | Mismatch | Validation / oracle command failure | Finding |
| --- | ---: | ---: | ---: | --- |
| CA, `constraint-analysis`, v132 | 10,000 / 4,254 | 5,746 | 0 / 0 | Every differing Starshine canonical module was smaller. |
| CA, `constraint-analysis`, v133 | 10,000 / 7,368 | 2,632 | 0 / 0 | v133 matches more closely than v132; remaining differences need semantic classification. |
| OI, `pass-oi-all` | 10,000 / 8,920 | 1,080 | 0 / 0 | All differences had smaller Starshine canonical modules; sample includes shorter local-copy chains. |
| `tail-call`, random-all-profiles | 10,000 / 9,614 | 386 | 0 / 0 | 11 cases were one byte larger; the others were equal or smaller. |
| `remove-empty-function-exports`, random-all-profiles | 10,000 / 9,906 | 94 | 0 / 0 | 11 cases were one byte larger, including preexisting block-flattening drift in unchanged function bodies. |
| `intrinsic-lowering`, random-all-profiles | 10,000 / 9,851 | 149 | 0 / 0 | A 55-case `dae2-intrinsics` family exposed missing non-tail directization; red regression and fix followed. |
| `global-effects`, random-all-profiles | 10,000 / 9,906 | 94 | 0 / 0 | Differences matched generic representation families; no generated fresh-resume case failed validation. |
| `global-type-optimization --closed-world`, random-all-profiles | 10,000 / 8,747 | 1,253 | 0 / 0 | 935 cases were larger. The focused v133 descriptor placeholder is green, but full older GTO field/type pruning remains a substantial parity gap. |
| `dealign`, random-all-profiles | 10,000 / 9,824 | 176 | 0 / 0 | No invalid output; 11 larger generic control cases remain open. |
| `make-shared-objects`, random-all-profiles | 9,834 / 7,683 | 2,151 | 55 / 111 | Binaryen primary validation was required because wasm-tools does not yet decode `ref.i31_shared`. All 55 Starshine validation failures were the `call.without.effects` intrinsic signature; Binaryen v133 also emitted invalid output for a replay of that family. All 111 oracle command failures were `try_table` catch sent-type errors from Binaryen. A red-first intrinsic boundary guard and a red-first table/element remap fix followed. |

After the non-tail intrinsic fix, a fresh 10,000-case `intrinsic-lowering`
run had **9,906 normalized matches, 94 mismatches, and no validation or
command failures**. Its 55 `dae2-intrinsics` mismatches disappeared; the
remaining 94 were the same generic control/representation profiles seen by
passes that do no rewrite on those inputs. A 256-case three-way Node replay
checked CA on all 256 modules with 256 equal outcomes and no blocked or
different results. OI checked 231 of 256 with 231 equal outcomes; 25 cases
were blocked by the runtime adapter's unsupported proposal shapes. This
samples semantics but does not prove every output-shape difference safe.

After the intrinsic boundary and table/element fixes, a fresh
`make-shared-objects` run requested 10,300 generated cases to obtain **10,133
completed comparisons**: 7,917 normalized matches, 2,216 mismatches, **zero
Starshine validation failures**, and 167 Binaryen command failures. The
oracle failures were 112 `try_table` sent-type cases and 55
`call.without.effects` intrinsic cases; a saved intrinsic case also fails when
run directly through the official v133 binary. The remaining mismatches include
86 Starshine canonical size losses. Every one of those 86 came from a
`remove-unused-brs-*` GenValid profile; a saved example differs in a
preexisting block/local representation with no shared-object rewrite. The
shared-object-specific output differences still require semantic and size
analysis.

Three more 256-case Node-v2 replays checked tail-call, closed-world GTO, and
intrinsic lowering. Each had 246 equal three-way outcomes, 10 runtime-blocked
cases, and zero observed semantic mismatches. The same 10 unsupported cases
arose from the shared random-all-profiles generator mix. These samples do not
settle GTO's broad field/type-pruning parity gap or the shared-object
representation differences.

The `i64-to-i32-lowering` compare-pass lane cannot provide ordinary parity
evidence with random GenValid modules: the released Binaryen pass expects
flattened input and lowers all i64 values, while this intake only implements
the four new saturating conversions. A deterministic runtime probe compiled
one module exporting those four operations, then compared the original and
Starshine-lowered exports on 10,000 randomized and boundary bit patterns per
operation (40,000 calls total): zero result or trap differences. This is
focused conversion evidence, not full-pass parity.

The shared-object failure prompted an intentionally unsupported boundary:
Starshine now leaves a module with `binaryen-intrinsics` / `call.without.effects`
unchanged rather than change its required funcref parameter into shared i31.
The original module remains valid. Binaryen v133's own transformed output for
the same saved case fails its validator. The shared-object table and passive
element regression now keeps function indices consistent with the rewritten
shared i31 references. Broader differences in function-index numbering,
boundary wrappers, and older GTO pruning remain open pending direct semantic
and size analysis; validation alone is not acceptance evidence.
