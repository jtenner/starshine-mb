# SGO loop-prefix closeout

## Question

Should `[SGO]003C5` remain an active implementation queue after the narrow direct-loop prefix series through segment drops?

## Decision

Close `[SGO]003C5` as accepted for the currently evidenced direct-loop prefix surface. The implemented queue now covers the source/probe-backed non-branching value-loop forms where an independent prefix effect precedes the yielded candidate `global.get`, and the adjacent consumer is one of the already-supported direct, `i32.eqz`, compare-const, reverse-compare, or simple pure condition guards.

This is not a claim of full Binaryen loop `FlowScanner` parity. It is a stop point: future loop broadening needs a fresh exact Binaryen-positive fixture, a paired guardrail negative, focused tests, and direct SGO fuzz.

## Covered loop-prefix evidence

The current accepted `[SGO]003C5` queue is backed by these landed slices:

- [`0677`](./0677-2026-05-25-sgo-loop-independent-global-set-prefix.md): independent `const; global.set <other>; global.get <candidate>`.
- [`0678`](./0678-2026-05-25-sgo-loop-independent-local-set-prefix.md): independent `const; local.set; global.get <candidate>`.
- [`0679`](./0679-2026-05-25-sgo-loop-independent-store-prefix.md): constant-operand `i32.store`.
- [`0680`](./0680-2026-05-25-sgo-loop-independent-i64-store-prefix.md): constant-operand `i64.store`.
- [`0681`](./0681-2026-05-25-sgo-loop-independent-subword-store-prefix.md): integer subword stores.
- [`0682`](./0682-2026-05-25-sgo-loop-independent-float-store-prefix.md): `f32.store` and `f64.store`.
- [`0683`](./0683-2026-05-25-sgo-loop-independent-table-set-prefix.md): clean `table.set`.
- [`0684`](./0684-2026-05-25-sgo-loop-independent-memory-fill-prefix.md): three-constant `memory.fill`.
- [`0685`](./0685-2026-05-25-sgo-loop-independent-memory-copy-prefix.md): three-constant `memory.copy`.
- [`0686`](./0686-2026-05-25-sgo-loop-independent-memory-init-prefix.md): three-constant `memory.init`.
- [`0687`](./0687-2026-05-25-sgo-loop-independent-table-fill-prefix.md): clean `table.fill`.
- [`0688`](./0688-2026-05-25-sgo-loop-independent-table-init-copy-prefix.md): three-constant `table.init` and `table.copy`.
- [`0689`](./0689-2026-05-25-sgo-loop-independent-grow-prefix.md): independent `memory.grow` and `table.grow` when their results are immediately dropped.
- [`0690`](./0690-2026-05-25-sgo-loop-independent-segment-drop-prefix.md): operandless `elem.drop` and `data.drop`.

Each behavior-bearing slice added focused positive coverage and paired candidate-derived or broader-shape guardrails where the instruction family had operands that could depend on the candidate global. Each slice's direct SGO fuzz reported zero Starshine validation failures and zero semantic mismatches; the repeated command failures were classified as established Binaryen/tool failures, not Starshine optimizer mismatches.

## Remaining loop boundaries

Keep these out of scope until new evidence justifies a dedicated child slice:

- branch/control loop bodies, `br_if`, `br`, `return`, `throw`, caught exception control, and loop-carried facts;
- candidate-derived memory/table/grow/store operands;
- trapping candidate consumers, including global-derived loads/table accesses;
- atomics, SIMD memory operations, relaxed SIMD, and parser-unsupported SIMD/control surfaces;
- calls whose operands consume the candidate value or whose effect/read summaries are not proven safe for the candidate global;
- broad reuse of the full block/nested-if FlowScanner inside loops.

## Backlog update rationale

`[SGO]003C5` should no longer be the active recurring-cron target. The parent `[SGO]003C` FlowScanner parity slice remains active for other source-backed families such as broader condition/control inventory, pure/nontrapping operator closure, nested-if and arm-flow completion, `try_table`/exception wrappers, and branch/control guardrails. Later loop work should be opened as a new exact child with Binaryen-positive evidence instead of continuing the completed prefix micro-series implicitly.

## Validation

No optimizer behavior changed in this closeout note. Latest behavior-bearing validation remains the 0690 segment-drop slice:

- `moon test src/passes`: `1641/1641` passed.
- `moon fmt`: passed.
- `moon info`: passed with existing DAE unused-value warnings.
- full `moon test`: `3717/3717` passed.
- direct SGO fuzz at `.tmp/pass-fuzz-sgo-loop-segment-drop-0690-10000`: `6759/10000` compared before the configured `20` Binaryen/tool command-failure stop, `0` mismatches, `0` Starshine validation failures; agent classification was tool/Binaryen failures only (`17` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, `1` `binaryen-invalid-tag-index`).
