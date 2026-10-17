---
kind: comparison
status: supported
last_reviewed: 2026-10-10
sources:
  - ./index.md
  - ./fuzzing.md
  - ./multivalue-call-scope.md
  - index.md
  - ../tracker.md
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/reorder_locals_test.mbt
  - ../../../../../src/passes/reorder_locals_grouping_wbtest.mbt
  - ../../../../../src/passes/reorder_locals_grouping_controls_wbtest.mbt
  - ../../../../../src/passes/reorder_locals_primitive_key_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ./starshine-hot-ir-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ./multivalue-call-scope.md
---

# `reorder-locals` Binaryen Parity

> **Comparison baseline — October 10, 2026:** new comparisons use [Binaryen 133](../../release-horizon-and-oracles.md). Recorded v131/v132 sources, commands, artifacts and results retain their historical versions and do not establish v133 signoff. The new declaration-compression section explicitly supersedes the historical unconditional first-use tie rule.

## Equal-frequency declaration compression

The October 10 investigation uses verified Binaryen **133**. It supersedes the
unconditional first-use tie rule below for Starshine's direct module owner:
descending access frequency remains primary, but equal-frequency body locals
may be grouped by their existing value type when their encoded declarations
become strictly smaller. Equal or larger candidates retain first-use ordering.
The nested type-stable owner and preset composition are unchanged.

For a frequency class with access count `c`, permuting its local indices keeps
`c * sum(ULEB-width(index))` unchanged, including parameter offsets and width
boundaries. The implementation measures both complete `Locals` encodings, so
run-vector, run-count and reference-type widths participate in selection.
Parameters stay fixed; declarations and all recursive get/set/tee users use
the same final permutation, and existing name repair remains responsible for
local metadata. Source instruction arrays retain copy-on-write ownership.

Type ranks use disjoint primitive `UInt64` keys, normalizing only equivalent
nullable inexact unshared abstract reference sugar. Reference flags, all 17
abstract heap types, shared/absolute/recursive heap categories and full-width
`UInt32` indices remain distinct. Actual declarations retain their types and
proposal support. Inline `DefType` graphs and bottom types retain baseline
ordering; no derived graph hash/equality specialization is needed. Primitive
key lookups and integer ranks keep sort comparisons constant-cost. Per-function extra scratch is
linear in body-local count; sorting is `O(L log L)`. Mixed-type functions that
previously returned early can now pay this work, so artifact resource costs
must be measured independently of the size proof.

The reduced six-local numeric fixture changes from **89 to 81 bytes** through
grouping alone. Binaryen emits 73 bytes: its additional eight-byte reduction
removes four temporary local set/get instructions during expression writeback.
Those writer changes are a separate remaining cause, not this transform's
claimed benefit. Tests cover source ownership, local-index and declaration
ULEB boundaries, frequency-class separation, genuinely changed equal/larger
candidate rejection, abstract sugar, exact/nullable reference fields and
name repair with imported-function offsets. Exact-reference field tests are
direct-IR evidence, not a Node proposal-runtime signoff.

The regression-first checkpoint ran six tests with five intended failures and
one fallback pass; the implementation and three added controls pass. Primitive-key contracts add three further tests. The first
full default suite had one superseded first-use expectation; its update proves
a two-byte declaration win and exact remapped indices. All 13 existing tests
then pass, and the final explicit WasmGC suite passes **14,067/14,067**. Native
compilation, API-info generation and formatting pass with no public type drift.
Independent source and focused runtime review found no blocker.

The verified Binaryen 133 dedicated `reorder-locals-all` lane compares **10,000**
modules with prebuilt native tools and independent wasm-tools validation:
**7,996** canonical matches and **2,004** agent-classified canonical size wins.
The residuals are 1,019 one-byte `nop` removals and 985 three-byte branchless
void-loop removals. All 20 retained diffs were independently inspected; the
1,984 suppressed diffs are classified using those representatives, generator
contracts, profile counts and exact 3,974-byte accounting. Every retained
Starshine raw output is byte-identical to the fresh integrated baseline, so
these families predate this grouping change. Raw aggregate bytes remain larger
than Binaryen (871,096 versus 788,165); the win claim is canonical. Validation,
generator and command failures are zero. The harness's exit 1 for structural
mismatches is retained; agent classification does not rewrite its result.

A permitted Node 26 rerun checks all 256 generated inputs, but those profiles
lack callable exports or start functions: its 256 all-equal outcomes establish
compilation and instantiation only. Two separate exported numeric/nullable-GC
fixtures execute position-sensitive results, explicit and null-reference traps,
mutable global state across calls and distinct public `f`/`g` function objects.
Their original, direct-pass and O4s variants match for 16 returned values and
four traps per variant. Exact-reference flags remain direct-IR coverage only.

Every artifact run starts from the preserved ORIGINAL, with numeric optimization
and shrink levels **4/1**. Production GC output is **6,774,210 bytes**, a
**186,626-byte** reduction from the integrated GC checkpoint; WASI output is
**6,229,197 bytes**, **11,308 bytes** smaller. Every non-code section payload
matches that checkpoint, preserving its public exports and proposal metadata;
all outputs independently validate. Bounded API/CLI parity against ORIGINAL
and clean packed JS/strict TypeScript 5.8.3 consumers pass using the preserved
qualified npm archive with these new Wasm files. The separate fresh-source
package qualification below also passes. The prep owner retains publication
and release-workflow ownership.

The initial generic-`ValType`-map implementation was measured with three
alternating-order serial whole-command pairs per artifact against fresh
integrated control, each invocation reading ORIGINAL. These measurements
precede the final primitive-key implementation.
GC median time is **8.694 -> 8.637 seconds**; median peak RSS is
**304,852 -> 299,864 KiB**. WASI is **9.635 -> 9.934 seconds** (**+3.1%**),
with **278,844 -> 278,788 KiB**. GC time ranges are 8.232–15.652 versus
8.631–13.695 seconds; WASI 9.586–9.889 versus 9.334–12.362. All twelve
output hashes match. The fresh Python supervisor measures monotonic elapsed
and Linux child peak RSS before validation; GNU time was unavailable. These
small local samples retain slower/outlier runs and desktop variability; they
do not establish universal throughput or memory improvements. No median RSS
increase is observed, and the separate GC memory **P1** remains open.

A serial one-sample refresh of each qualified Binaryen 133 O4s/Oz preset
reproduces all four historical output hashes from ORIGINAL with eight workers
and the saved runtime-compatible feature flags. The remaining O4s size gap is
**1,229,101 GC bytes** and **80,664 WASI bytes**; WASI Oz is **1,371,562 bytes**
smaller than Starshine O4s. These are artifact samples, not universal quality
claims. The same five explicit stages and broader writer/preset effects remain
separate; copying broader public function aliasing is not an acceptable shortcut
when distinct exported function-object identity is observable.

## Primitive keys and fresh-source npm qualification

The initial generic type-map source patch is `5783fcaa37971a5a48f38eb37e55f6e665f6ea37`.
The primitive-key regression commit is `df53a872fc2d21f3aeb0cb9eb1d39cf16470743f`
(two intended RED failures); the final source fix is
`062f9c6c3` (three focused GREEN tests, including unsupported graph/bottom control).
Final WasmGC full tests pass 14,067/14,067. The final native tool repeats all
10,000 generated comparisons: the same 7,996 matches and 2,004 classified
canonical size wins, no validator/generator/command failures. All 100 retained
input/output files across 20 cases are byte-identical to the independently
reviewed first grouping lane. The structural mismatch exit 1 and scope of the
1,984 suppressed classifications remain explicit.

A final primitive-key serial pair per ORIGINAL artifact reproduces both prior
output hashes. GC control/candidate is **8.483/9.886 seconds** and
**304,404/307,324 KiB** peak RSS; WASI is **9.886/9.735 seconds** and
**278,836/278,380 KiB**. This one-pair local sample shows a GC time and memory
cost, not statistical signoff. Keep it separate from the earlier three-pair
map cohort; the existing GC memory P1 remains open.

The final native tool SHA-256 is
`67e8f3b70857e2de75149f41e6b9c2c763244205bf8d07815526e47de5ea0c74`.
GC output SHA-256 is
`ee68ed73ca28487439f2c3b249286035850b934429a6e84bfaa949b9f7d5bea2`;
WASI is
`8d814b12fa44c21027af8e304f0792923022cd8078be812189ba0728a56784e2`.

A fresh npm build generates **4,370 concrete FFI exports** and **29 documented
explicit concrete wrappers**, with no tracked declaration drift. It self-optimizes
using Starshine's native bootstrap and actual numeric **4/1**; Binaryen is not
in the build. Raw/optimized API and CLI parity pass. The 47-file packed archive
SHA-256 is
`0bf6b61dbe432fbb50365d0f673594f18c651c0ebd4cccd52a1e58bc20cf46a8`.
Clean JavaScript and strict TypeScript 5.8.3 consumers pass on Node 25.8.1 and
26.11.1, with checkout/MoonBit access denied. The actual WasmGC npm API changes
the reduced fixture 89 -> 81 bytes and preserves its returned value 231.
Position-sensitive native numeric/nullable-GC fixtures also renew values,
traps, mutable state and distinct exported function identity against ORIGINAL.

Fresh-source GC raw/optimized bytes are **7,600,106 / 6,948,642**; WASI is
**6,772,519 / 6,248,040**. Against the source-matched integrated owner package,
optimized GC is **26,442 bytes smaller** and WASI **7,910 bytes smaller**.
These changing-source package results differ from the fixed-ORIGINAL gains.
The dedicated 16 KiB raw-growth target remains exceeded: raw GC grows
**133,237 bytes** from 7,466,869. Preserve this failed probe.

Function-level attribution identifies a compiler type-order effect: the same
403-field opcode-counter record moves from type index 23 to 192. A census finds six similarly growing
counter-body chunks; the largest is independently proven instruction-identical
after index normalization and grows 177,073 -> 202,929
bytes with identical normalized instructions, case tags and opcode counts.
Struct operands use unsigned LEB (128 boundary); heap references use signed
LEB (64 boundary). This is encoding growth, not proven added/inlined optimizer
logic. Earlier inlining/equality hypotheses were withdrawn; `#inline(never)`
did not change size, and a withdrawn run-key experiment selected zero tests
and is not RED evidence. A bounded dependency-preserving type-order change is
a separate remaining optimization lead, requiring full module remapping,
type/field-name repair and a strict encoded-size gate.

The 16 existing Binaryen discrepancies, classified DFE residuals and public
function-identity caveat remain open. License terms are undecided. This local
checkpoint does not publish, tag, alter branch protections or close release
workflow checks.

## Binaryen v131 Oracle Verdict

The 2026-07-28 refresh used official `wasm-opt version 131 (version_131)` and Binaryen source commit `1f903c14babf829745b421b92ff0f286e93e4209` as the oracle. The reviewed `ReorderLocals.cpp` and dedicated `reorder-locals*` lit fixtures are byte-identical between `version_130` and `version_131`, so the released owner contract did not change.

That historical v131 owner contract was:

- parameters remain fixed;
- only body locals are reordered or removed;
- `local.get`, `local.set`, and `local.tee` all count as accesses;
- live body locals sort by descending access count;
- live ties use first observed access, then original index as a stable fallback;
- the zero-access suffix is removed;
- every local user is reindexed recursively;
- local-name metadata follows the new indices and stale raw name payload is invalidated;
- the pass does not require non-nullable-local fixups.

Starshine now matches that released behavior for every pass-owned family represented by its boundary IR.

## Audit Repair

The audit found one real Starshine output bug outside the sorter itself. `rl_rewrite_expr` and nested structured rewrites mutated shared instruction arrays in place. For pure same-type permutations, local declarations remained structurally identical, so the original module and optimized module became equal after aliasing. The CLI's unchanged-wasm fast path then reused the original input bytes and lost the remapped indices.

The repair makes root and nested block/loop/if/legacy-`try`/`try_table` rewriting copy-on-write. Red-first tests now prove:

- the input module retains its original local indices;
- the optimized module contains the Binaryen ordering;
- the CLI emits different wasm bytes for a pure same-type permutation;
- nested legacy-EH bodies remain recursively remapped without mutating the source module.

A dedicated `reorder-locals-permutation-only` GenValid leaf keeps all body locals live and all declarations the same type so this output boundary cannot be masked by unused-local trimming or declaration-type changes.

## Transform-Family Inventory

| Family | Evidence | Verdict |
| --- | --- | --- |
| Parameter stability and params-only no-op | Focused pass tests and hot-sort/multi-function generation | exact |
| `local.get` / `local.set` / `local.tee` counting | Focused tests plus hot-sort and permutation-only leaves | exact |
| Descending access counts | Focused carrier fixtures and `reorder-locals-hot-sort` | exact |
| Equal nonzero counts ordered by first observed use | Focused direct regression plus `reorder-locals-first-use-ties`; singleton `1000/1000` exact | exact |
| Pure same-type permutation | Copy-on-write pass/CLI regressions and `reorder-locals-permutation-only` | repaired; exact |
| Mixed declarations and grouped local runs | `reorder-locals-mixed-types` | exact |
| Nullable/non-nullable GC references | `reorder-locals-reference-types` | exact |
| Zero-access trimming and write-only survival | `reorder-locals-unused-trim` | exact |
| Structured recursive reindexing | `reorder-locals-structured` | exact |
| Legacy `try`, typed catches, catch-all, delegates | deterministic repair tests plus `reorder-locals-legacy-eh` | exact |
| Multiple defined functions, imports, parameter arities | `reorder-locals-multi-function` | exact |
| Local-name repair and raw name invalidation | focused metadata/CLI tests and `reorder-locals-name-repair` | exact |
| Repeated public scheduler slots | early tuple/no-structure slot and late simplify/coalesce sandwich remain scheduled | closed for this pass; broader preset work belongs to neighboring owners |

## Final Direct Evidence

The refreshed native Starshine binary has SHA-256 `e90aad59cc6e1f43e4304906b6364c8a57b3cb25d1de915b08043dd8ac085bd4`.

- First-use-tie singleton: `1000/1000` normalized matches.
- Regular GenValid: `100000/100000` normalized matches.
- Dedicated ten-leaf aggregate: `10000/10000` normalized matches; every leaf selected, including `999` first-use-tie cases.
- Dedicated idempotence: `10000/10000` comparisons and idempotence checks, zero property failures.
- Random all-profiles: `9375` normalized matches plus `625` classified Starshine wins from one non-pass-owned multivalue lowering family.
- External wasm-smith: `9955` direct matches plus one `unreachable-control-debris` compare-normalized match across `9956` comparable cases; `44` Binaryen-only command failures; zero remaining mismatches.
- Validation failures, Starshine command failures, generator failures, and true semantic mismatches: zero.

### Random-all Starshine-win family

All `625` residuals were `remove-unused-brs-control` modules containing type-indexed multivalue control. Binaryen materializes a different scratch-local/control shape before its pass runs. Starshine retains the direct multivalue block shape. This is not accepted merely because both outputs validate:

- Starshine canonical wasm was exactly `8` bytes smaller in every residual (`-5000` bytes total).
- A separate `1000`-case replay externally validated both outputs and executed all cases in Node.
- Fresh runtime outcomes were `775` equal results and `225` equal traps, with zero semantic mismatches.
- Starshine was exactly `8` canonical bytes smaller in every replay case (`-8000` total).

This family is therefore a measured Starshine size win with runtime evidence. Reopen if Starshine ceases to be no larger, runtime outcomes diverge, or the Binaryen boundary stops materializing the alternate shape.

## Official Fixture Replay

Both official Binaryen v131 fixtures were parsed to wasm, run through Starshine and Binaryen with debug names preserved, externally validated, and normalized through the same v131 writer. `reorder-locals.wast` was byte-equal at `165` bytes for both outputs; `reorder-locals_print_roundtrip.wast` was byte-equal at `89` bytes. This directly confirms the source fixture's hotness/trimming behavior and the print-roundtrip local-name/declaration-order contract.

## Artifact Quality And Performance

On `tests/node/dist/starshine-debug-wasi.wasm` with debug information preserved:

- Starshine output: `12,784,150` bytes.
- Binaryen v131 `--debuginfo` output: `13,846,853` bytes.
- After applying the same Binaryen-v131 `--strip-debug` canonicalization, Starshine was `5,262,811` bytes versus Binaryen `5,271,695`, an `8,884`-byte Starshine win.
- Twenty-run whole-command medians were `1000.677 ms` for Starshine and `926.353 ms` for Binaryen, ratio `1.080x`; both outputs externally validate.

The ratio is within the repository's `<=2x` target, while Starshine produces smaller comparable output. Process startup, decode, encode, and debug-section handling are included, so this is a whole-command artifact measurement rather than an isolated sorter timer.

## Standing Boundary Decision

The old full-artifact raw wasm non-convergence remains a Binaryen writer/IR-builder boundary, not a `ReorderLocals.cpp` semantic gap. Use normalized/canonical function evidence and the measured size/runtime criteria in [`./multivalue-call-scope.md`](./multivalue-call-scope.md); do not require byte-for-byte raw output when Binaryen materializes a larger alternate multivalue shape.

## Reopening Criteria

Reopen direct parity if any of the following occurs:

- Binaryen changes the v131 owner contract in a later release;
- an encoded pure permutation reuses unchanged input bytes;
- parameters move, an accessed local is removed, a zero-access suffix survives unexpectedly, or a local user/name map is stale;
- legacy-EH protected/catch/delegate structure is mutated incorrectly;
- any dedicated leaf produces a validation, idempotence, or unclassified parity failure;
- the random-all multivalue family loses its canonical size win or runtime equality;
- whole-command artifact performance exceeds `2x` Binaryen without an accepted compensating win.
