---
kind: research
status: current
last_reviewed: 2026-06-08
sources:
  - ../../../../src/passes/once_reduction.mbt
  - ../../../../src/passes/once_reduction_test.mbt
  - ../../../../agent-todo.md
  - ../../../binaryen/passes/once-reduction/parity.md
  - ../../../binaryen/passes/once-reduction/starshine-hot-ir-strategy.md
  - ../../../binaryen/passes/once-reduction/binaryen-strategy.md
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/OnceReduction.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/once-reduction.wast
related:
  - ../../../binaryen/passes/once-reduction/index.md
  - ../../../binaryen/passes/once-reduction/parity.md
  - ../../../binaryen/passes/once-reduction/starshine-hot-ir-strategy.md
  - ./0701-2026-06-03-once-reduction-o4z-audit.md
  - ./0714-2026-06-07-o4z-behavior-parity-inventory.md
---

# `once-reduction` behavior-gap inventory

## Scope

I picked the reopened `[O4Z-AUDIT-OR]` `once-reduction` pass and inventoried behavior parity gaps between current Starshine and local Binaryen `wasm-opt version 130 (version_130)`.

This is a source/fixture audit, not an implementation slice. I did not run a fresh compare lane or add tests in this inventory.

## Commands and source checks

- `wasm-opt --version`
  - reports `wasm-opt version 130 (version_130)`.
- Downloaded official Binaryen sources for `version_130`:
  - `src/passes/OnceReduction.cpp`
  - `test/lit/passes/once-reduction.wast`
- Downloaded the same files for `version_129` and diffed them against `version_130`.
  - Both diffs were empty, so the existing `version_129` dossier remains source-current for this pass under local `version_130`.
- `bun scripts/pass-fuzz-compare.ts --list-passes | grep once-reduction`
  - confirms `once-reduction` is still a direct compare pass name.

## Current Starshine baseline

Starshine currently implements a real active module pass:

- candidate global discovery for non-imported, non-exported integer globals
- exact flat or one-top-level-block once-wrapper recognition
- defined no-param/no-result `@binaryen.idempotent` fake roots
- fixed-point function-summary propagation over recursive instruction arrays
- redundant direct-call and redundant constant `global.set` nopping
- tiny empty-body / single-call-wrapper cleanup for explicit once functions

The 2026-06-03 direct lane remains useful evidence: `9975/10000` compared, `9975` normalized matches, `0` semantic mismatches, and `25` Binaryen/tool command failures. It does **not** close the source-surface gaps below.

## Gap inventory

| ID | Gap | Binaryen `version_130` behavior | Starshine behavior | Classification | Suggested next test |
| --- | --- | --- | --- | --- | --- |
| OR-GAP-001 | Imported `@binaryen.idempotent` no-param/no-result functions | The idempotent loop iterates all module functions and does not filter imported functions before assigning a fake global. Repeated calls can be nopped when the annotation is present and the signature is empty. | The local fake-root loop starts at `imported_func_count`, so imported idempotent functions are an explicit conservative boundary. | Missed Binaryen-positive optimization. Needs source-confirmed local annotation/import support before enabling. | WAT with an imported annotated no-param/no-result function and two direct calls. |
| OR-GAP-002 | Wrapper cleanup when an explicit once function's sole payload calls an idempotent fake-root function | `optimizeOnceBodies` can strip the explicit once function's guard when the payload target has any `onceFuncGlobals` entry, including fake globals from idempotent annotations. | `or_optimize_once_bodies` checks `once_func_globals[target_idx] >= 0`, which excludes idempotent fake roots. | Missed Binaryen-positive cleanup; semantic-safe if the idempotent contract is accepted. | Explicit once wrapper whose only payload is a defined idempotent function. |
| OR-GAP-003 | Negative nonzero integer writes | The scanner accepts only integer constants with `getInteger() > 0`; negative i32/i64 constants are not considered valid monotonic once writes. | `or_prev_nonzero_integer_const` accepts any nonzero i32/i64 value, including negative constants. | Starshine-only extension. Likely semantic-safe under private once-global rules, but it is not Binaryen behavior parity. | Once wrapper writing `i32.const -1` / `i64.const -1`; decide whether to match Binaryen or document as accepted extension. |
| OR-GAP-004 | CFG / immediate-dominator precision | The optimizer builds a CFG and `DomTree`, then optimizes relevant calls/sets in basic blocks dominated by prior once writes. | Starshine uses recursive structural traversal with block union, if intersection, loop non-propagation, and try-table non-propagation; it has no CFG or immediate dominator tree. | Broad algorithmic behavior gap. It can be both less precise and differently precise than Binaryen. | Port representative Binaryen lit control-flow positives/negatives into focused Starshine tests before changing code. |
| OR-GAP-005 | After-merge conservatism | Binaryen's dedicated lit says a call after an `if` where both arms call the once function is **not** optimized, because the pass only uses dominance and not merge intersection. | Starshine's `if` analysis intersects branch exit facts; when both arms set the same once bit, the following direct call can become a `nop`. | Starshine-only stronger optimization. Likely semantic-safe for plain if/else, but observable as Binaryen output/behavior-selection drift. | `caller-if-2` shape from Binaryen lit: both arms call `$once`, then call `$once` after the `if`. |
| OR-GAP-006 | Loop and backedge treatment inside the local optimizer | Binaryen's CFG can optimize within loop bodies according to dominance while keeping loop/cycle caveats from the lit file. | Starshine rewrites inside loops using incoming facts but does not propagate learned loop facts outside the loop. It also does not model loop backedges as CFG predecessors. | Mixed missed optimization / possible over- or under-approximation depending on shape. | `caller-loop-1` and `caller-loop-2` lit shapes; include an explicit loop backedge and a post-loop call. |
| OR-GAP-007 | EH / try-catch CFG surface | Binaryen's lit includes a try/catch assertion-safety shape; CFG traversal emits and visits try contents without assertion failures. | Starshine scans and rewrites inside `try_table`, but analysis treats `try_table` as non-propagating and has much smaller EH coverage. | Missed precision / coverage gap; no known semantic bug yet. | Port the lit try-catch shape to current `try_table` syntax supported by Starshine. |
| OR-GAP-008 | Dangerous mutually recursive once-function summaries | Binaryen's lit keeps specific second calls in two-function and triple-loop cycles because setting a once global on entry does not prove the callee's payload has completed; removing those calls can reorder observable imports. | Starshine's fixed-point summaries union callee summaries through cycles. That can infer that mutually recursive once functions set each other's once bits and may remove later calls that Binaryen intentionally preserves. | High-priority potential true semantic mismatch; not just output drift. | Port the Binaryen dangerous triple-loop fixture and assert Starshine preserves the second cross-cycle calls. |
| OR-GAP-009 | Wrapper cycle safety breadth | Binaryen strips single-call wrapper guards with a deterministic `removedExitLogic` set and preserves at least one guard in call cycles. | Starshine has a similar bitset guard for explicit once wrappers, but not the full Binaryen name/fake-global surface and not idempotent target cleanup. | Mostly covered for explicit one-call cycles; incomplete for idempotent-adjacent wrapper cleanup. | Two-function explicit once wrapper cycle plus explicit-once-to-idempotent wrapper case. |
| OR-GAP-010 | `return_call` handling | Binaryen's optimizer records ordinary `Call` expressions; the source does not visit or optimize `ReturnCall`. | Starshine scans/analyzes `ReturnCall` as a summary-producing call and then continues with later instructions in the flat array, while rewrite never nops the `ReturnCall` itself. | Local divergence and potential reachability hazard for code after a terminal `return_call`; needs focused validation. | Function with `return_call $once` followed by another once call or set in unreachable tail. |
| OR-GAP-011 | Branch / early-exit semantics inside structural blocks | Binaryen's CFG/dominator model accounts for branches, unreachable blocks, and immediate dominators when deciding that a once bit is definitely set. | Starshine's `Block` handling unions facts from the body into the parent without explicit `br`, `return`, or `unreachable` path modeling. | Potential precision and safety gap; fuzz has not exposed a current true mismatch, but the proof is weaker than Binaryen's. | Block with a branch that skips a once write, followed by another call to the same once function. |
| OR-GAP-012 | Source-test surface parity | Binaryen's lit file has ~2K lines covering nonzero init, nonzero writes, params/results negatives, imported mutable globals, multiple once/non-once globals, call-chain propagation, try/catch, cycles, triple-loop order, self-loop, and non-once callers/callees. | Starshine tests cover core repeats, exported/imported boundaries, block-root wrappers, defined idempotent roots, extra reads, and table/ref escapes, but do not port the full lit decision tree. | Coverage gap. Not every missing lit case is a behavior bug, but the pass cannot be called source-surface complete without classifying them. | Add a `once_reduction_binaryen_lit_subset_test.mbt` or equivalent focused fixtures in priority order. |

## Priority order

1. **OR-GAP-008 dangerous cycles**: possible true semantic mismatch because Binaryen explicitly preserves calls to avoid import reorderings.
2. **OR-GAP-011 branch/early-exit CFG proof**: local structural union lacks Binaryen's path proof.
3. **OR-GAP-001 imported idempotent** and **OR-GAP-002 idempotent-adjacent wrapper cleanup**: direct source-visible Binaryen-positive missed behaviors.
4. **OR-GAP-005 after-merge intersection** and **OR-GAP-003 negative constants**: likely semantic-safe Starshine extensions, but must be either aligned or explicitly accepted as non-goals.
5. Remaining loop/EH/lit coverage gaps.

## Red test inventory

The 2026-06-08 red-test slice added focused failing fixtures to [`../../../../src/passes/once_reduction_test.mbt`](../../../../src/passes/once_reduction_test.mbt), each prefixed with `once-reduction ...`:

| Test | Gap(s) covered |
| --- | --- |
| `once-reduction treats imported idempotent no-arg calls as fake once roots` | OR-GAP-001 |
| `once-reduction strips explicit wrapper guard before idempotent payload` | OR-GAP-002 |
| `once-reduction rejects negative i32 once writes like Binaryen` | OR-GAP-003 |
| `once-reduction keeps first post-if call after two-arm merge` | OR-GAP-004 / OR-GAP-005 |
| `once-reduction honors unreachable branch exits before learning once facts` | OR-GAP-004 / OR-GAP-011 |
| `once-reduction applies Binaryen loop-local dominance without leaking loop facts` | OR-GAP-004 / OR-GAP-006 |
| `once-reduction optimizes repeated once calls inside try_table and after nonthrowing try` | OR-GAP-004 / OR-GAP-007 |
| `once-reduction does not treat return_call as a Binaryen once call` | OR-GAP-010 |
| `once-reduction preserves dangerous triple-cycle call order` | OR-GAP-008 / OR-GAP-009 |

Initial red verification command: `moon test --package jtenner/starshine/passes --file once_reduction_test.mbt` reported `23` total tests, `14` passed, `9` failed. All nine failures were the new red fixtures.

The follow-up green phase in the same thread implemented the covered behavior families in `src/passes/once_reduction.mbt`. Current focused verification reports `25` total tests, `25` passed, `0` failed. The standard direct compare lane `.tmp/pass-fuzz-once-reduction-green-10000` requested `10000`, compared `9977`, had `9977` normalized matches, `0` mismatches, `0` validation/property/generator failures, and `23` Binaryen/tool command failures. A later final-style 100000-case probe at `.tmp/pass-fuzz-once-reduction-final-100000-cleanup3` compared `99751`, had `99748` normalized matches, `3` raw mismatches, and `249` Binaryen/tool command failures; inspected diffs were unreachable/dead-trap debris on no-once modules, not once-call behavior differences. The shared cleanup follow-up moved the unreachable debris cleanup into `pass_raw_remove_dropped_unreachable_debris(...)` and the final rerun `.tmp/pass-fuzz-once-reduction-final-100000-shared-cleanup` compared `99751`, had `99751` normalized matches, `0` mismatches, and `249` Binaryen/tool command failures.

## What would close `[O4Z-AUDIT-OR]`

A credible final closeout still needs all of the following:

- port or explicitly classify any remaining dedicated-lit shapes not covered by the nine focused tests
- decide whether a final `100000`-case closeout is required for removing `[O4Z-AUDIT-OR]` from active backlog
- explicit user-approved non-goal notes for any remaining Starshine-only extension retained, with reopening criteria
- a final source review confirming no remaining broad `OnceReduction.cpp` behavior family is only documented as out of scope

## Sources

- Starshine implementation: [`../../../../src/passes/once_reduction.mbt`](../../../../src/passes/once_reduction.mbt)
- Starshine tests: [`../../../../src/passes/once_reduction_test.mbt`](../../../../src/passes/once_reduction_test.mbt)
- Current parity page: [`../../../binaryen/passes/once-reduction/parity.md`](../../../binaryen/passes/once-reduction/parity.md)
- Current local strategy page: [`../../../binaryen/passes/once-reduction/starshine-hot-ir-strategy.md`](../../../binaryen/passes/once-reduction/starshine-hot-ir-strategy.md)
- Binaryen `version_130` source: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/OnceReduction.cpp>
- Binaryen `version_130` lit test: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/once-reduction.wast>
