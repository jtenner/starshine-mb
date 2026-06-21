---
kind: research
status: active
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0865-2026-06-20-heap-store-optimization-descriptor-ref-as-non-null.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../src/ir/hot_verify.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp
---

# HSO descriptor `br_on_non_null` trap/escape boundary probe

Question: how does Binaryen `version_130` handle a descriptor operand that proves non-null with `br_on_non_null` and falls through to `unreachable`, before a later call-valued `struct.set` would be folded into `struct.new_desc`?

## Answer

Binaryen keeps the later `struct.set`. In the probed module, the descriptor operand is a block returning an exact descriptor reference:

- `global.get` reads a nullable exact descriptor global;
- `br_on_non_null` branches to the block result on the non-null path;
- the null fallthrough reaches `unreachable`;
- a later `struct.set` stores the result of a helper call into the fresh struct.

Folding the helper call into `struct.new_desc` would move the call before a descriptor operand path that can reach `unreachable`, so Binaryen preserves the original ordering.

This is a source-backed HSO-D/F boundary candidate: it combines descriptor operand ordering with GC branch control flow. It is not an accepted Starshine semantic non-goal.

## Probe command

```sh
wasm-opt --all-features \
  .tmp/hso-probe-desc-br-on-non-null-unreachable-call.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-desc-br-on-non-null-unreachable-call.opt.wat && \
grep -n "struct.set\|struct.new_desc\|br_on_non_null\|unreachable\|call\|global.get" \
  .tmp/hso-probe-desc-br-on-non-null-unreachable-call.opt.wat
```

Observed grep:

```text
13:   (struct.new_desc $s
16:     (br_on_non_null $b
17:      (global.get $d)
19:     (unreachable)
23:  (struct.set $s 0
25:   (call $f)
```

## Local Starshine surface status

A focused Starshine direct-AST fixture was attempted using `Instruction::br_on_non_null` inside an exact descriptor block. The module validated before the hot pass, but the hot pipeline aborted while building the CFG/effect analysis:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Observed failure for the attempted fixture:

```text
hot_verify_all_or_abort
cfg_build
cache_get_or_build_cfg
cache_get_or_build_effects
pass_require_effects
```

The attempted test was removed so the HSO suite remains green. Treat this as a local HOT CFG/verifier surface blocker for descriptor-typed `br_on_non_null` blocks, not as HSO behavior parity evidence and not as an accepted HSO non-goal. Reopen this boundary when HOT verification/CFG support for this branch-result shape is repaired or when a binary replay path can run HSO over the exact probe fixture.

## Validation

No implementation behavior changed. The slice is a Binaryen probe plus local surface classification.

The focused HSO suite should remain at the previous test count after removing the attempted unsupported fixture.

## Remaining risk

HSO-D/F remains open for descriptor-producing `br_on_*` / cast-like expressions where the local surface permits a focused pass test. This note narrows one source-backed branch descriptor family and records why it is not yet covered by Starshine's focused HSO suite.
