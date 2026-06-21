---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0864-2026-06-20-heap-store-optimization-descriptor-select.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` descriptor `ref.as_non_null` trap boundary

Question: does Binaryen `version_130` fold a later call-valued `struct.set` into `struct.new_desc` when the descriptor operand is `ref.as_non_null(global.get nullable-desc)`?

## Answer

No. Binaryen preserves the later `struct.set`. The descriptor operand can trap before the original later store value is evaluated; moving the call-valued replacement field into `struct.new_desc` would evaluate the call before that possible descriptor trap.

This is a source-backed HSO-D boundary, not a Starshine non-goal. Starshine already matched Binaryen, so this slice adds focused negative coverage and documents the behavior without changing implementation.

## Binaryen `version_130` probe

Probe fixture: `.tmp/hso-probe-desc-as-non-null-call.wat`.

```sh
wasm-opt --all-features \
  .tmp/hso-probe-desc-as-non-null-call.wat \
  --heap-store-optimization \
  -S \
  -o .tmp/hso-probe-desc-as-non-null-call.opt.wat

grep -n "struct.set\|struct.new_desc\|ref.as_non_null\|call\|global.get" \
  .tmp/hso-probe-desc-as-non-null-call.opt.wat
```

Observed grep:

```text
13:   (struct.new_desc $pair
16:    (ref.as_non_null
17:     (global.get $descg)
21:  (struct.set $pair 0
23:   (call $helper
```

Agent classification: Binaryen behavior boundary. The retained `struct.set` preserves trap ordering for the nullable descriptor operand.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps descriptor store when descriptor ref.as_non_null may trap`.

The test uses a nullable exact descriptor global, wraps it with `ref.as_non_null`, and asserts that the optimized function still contains `struct.set`.

Because this is a negative boundary that Starshine already matched, there was no required red-first implementation failure and no code change.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: focused HSO tests passed `224/224`.

No native rebuild or direct 10000-case compare was needed because this was coverage-only and made no behavior or implementation change.

## Remaining work

This narrows HSO-D descriptor-expression coverage by locking one trap-sensitive descriptor operand boundary. HSO-D/E/F/G/H/I/J remain open for broader arbitrary descriptor expressions, descriptor/later-field hazard combinations, broader in-function branch/catch negatives, remaining swap/wrapper variants, explicit non-goal wording, allocation-heavy performance evidence, final O4z slot/neighborhood replay, and final 100000-case closeout.
