---
kind: raw-source
status: current
last_reviewed: 2026-07-10
sources:
  - https://github.com/WebAssembly/proposals
  - https://webassembly.github.io/threads/core/valid/instructions.html
  - https://webassembly.github.io/threads/core/exec/instructions.html
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/validate/typecheck_negative_tests.mbt
  - ../../../../src/validate/invalid_fuzzer.mbt
  - ../../../../src/validate/gen_valid.mbt
related:
  - ../../wasm-linear-memory-threads-boundary.md
  - ../../wast/atomic-memory-instruction-authoring.md
  - ../../wasm-relaxed-atomics-boundary.md
  - ../../wasm-feature-status-and-proposal-boundaries.md
  - ../../wast/text-surface-gap-ledger.md
  - ../../fuzzing/generator-coverage-ledger.md
  - ../../validate/resource-sections-and-limits.md
  - ./2026-06-04-linear-memory-threads-shared-memory-refresh.md
  - ./2026-06-04-linear-atomics-fence-unshared-reconciliation.md
---

# Linear Atomics: Unshared-Memory Validation Reconciliation (2026-07-10)

- Capture date: 2026-07-10
- Reason for capture: reconcile a stale live-wiki rule that said every `MemArg`-based linear-memory atomic requires a shared memory during Starshine validation.
- Status: immutable primary-source and repository-evidence bridge. It supersedes the **post-implementation local-validation conclusion** of the two June atomic/shared-memory captures below; they remain historical sources for Threads routing, memory-type flags, the maximum-on-shared-memory rule, WAST gaps, and generator topology.

## Primary sources rechecked

1. WebAssembly proposals tracker, checked 2026-07-10: <https://github.com/WebAssembly/proposals>. Threads remains an active Phase-4 proposal row; that status does not itself prove a Starshine layer.
2. Threads draft validation rules, checked 2026-07-10: <https://webassembly.github.io/threads/core/valid/instructions.html>. The ordinary atomic memory instructions validate their selected memory and natural alignment; sharedness is not a validation premise for atomic load/store/RMW/cmpxchg/notify/wait forms. `atomic.fence` remains a standalone empty-stack instruction.
3. Threads draft execution rules, checked 2026-07-10: <https://webassembly.github.io/threads/core/exec/instructions.html>. Runtime behavior distinguishes shared from unshared memories; in particular, wait instructions trap on an unshared memory. Static validation and execution behavior must therefore not be collapsed into one claim.
4. Local typechecker and regression evidence, checked 2026-07-10: [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt), [`src/validate/typecheck_negative_tests.mbt`](../../../../src/validate/typecheck_negative_tests.mbt), and [`src/validate/invalid_fuzzer.mbt`](../../../../src/validate/invalid_fuzzer.mbt).

## Local source reconciliation

`memarg_check_atomic(...)` in [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) delegates to ordinary `memarg_check(...)`, which proves that the selected memory exists and that alignment and offset fit the access/address width. It then returns that memory and its limits without inspecting `MemType(..., shared)`.

The focused regression [`Typecheck atomic load accepts non-shared memory`](../../../../src/validate/typecheck_negative_tests.mbt) confirms the local contract. The retained invalid-fuzzer strategy id `invalid-function-body-atomic-load-non-shared-memory` is explicit historical naming only: its implementation now makes the case invalid with oversized alignment because the non-shared bit itself is accepted. See [`validate_invalid_ast_mutate_invalid_function_body_atomic_load_non_shared_memory(...)`](../../../../src/validate/invalid_fuzzer.mbt).

`gen_valid_atomic_shared_mem_idx(...)` in [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt) still deliberately selects a shared memory before its coverage prelude emits atomics. That is a **generator topology choice**, not a validator requirement. It keeps `[FZG]017` representative of shared-memory atomic shapes, but it does not prove that unshared atomic modules are invalid or unsupported by the Starshine typechecker.

## Durable conclusions

1. Current Starshine validation accepts `MemArg`-based linear-memory atomics against an existing **shared or unshared** selected memory, subject to normal address type, alignment, offset, index, and operand-stack rules.
2. `atomic.fence` remains distinct because it has no `MemArg`, memory lookup, or stack effect. Its distinctness is not evidence that the other atomic forms require a shared memory.
3. A shared memory still has an independent resource invariant: `MemType(..., shared=true)` requires a maximum. The `0x02` and `0x06` shared-without-max binary forms remain decode-accepted, validation-invalid specimens.
4. Proposal execution semantics still distinguish unshared and shared memory, especially for `memory.atomic.wait*`. Starshine is a validator/optimizer, not an execution engine; do not infer a local runtime result from typechecking success.
5. Existing generator profiles intentionally use shared memories for atomic emission. Future generator work may add unshared atomic coverage, but must label that as coverage expansion rather than a validator-policy change.
6. Passes must preserve atomic effects and ordering regardless of the selected memory's shared bit. Validation acceptance does not make an atomic operation pure, removable, or reorderable.

## Supersession and uncertainty

- [`2026-06-04-linear-memory-threads-shared-memory-refresh.md`](2026-06-04-linear-memory-threads-shared-memory-refresh.md) and [`2026-06-04-linear-atomics-fence-unshared-reconciliation.md`](2026-06-04-linear-atomics-fence-unshared-reconciliation.md) accurately retain their June source snapshots, but their statements that Starshine rejects unshared `MemArg` atomics no longer match current checked-in code and tests. They are preserved unchanged as historical provenance.
- This capture does not establish when the local typechecker changed or whether the earlier prose reflected an older implementation versus a reading error. Use current code/tests for the present Starshine contract.
- This capture does not claim complete Threads support, a WAST text surface, external-validator agreement, or runtime execution support.
