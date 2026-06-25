---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1072-2026-06-25-heap-store-optimization-allocation-heavy-performance-refresh.md
  - ./1084-2026-06-25-heap-store-optimization-allocation-heavy-scaling.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO straight-line region-scan skip

## Question

Can the allocation-heavy HSO slowdown be reduced without weakening movement-safety predicates or changing Binaryen behavior?

## Change

`hso_process_node_regions(...)` now returns immediately for straight-line subtrees whose effect mask does not contain `EFFECT_MASK_CONTROL`.

This only short-circuits the pre-rewrite recursive descent that looks for nested HOT regions. The current-region root-chain scan still visits `local.set(struct.new*)`, tee-wrapped `struct.set`, and later `struct.set(local.get)` candidates exactly as before. A nested `block`, `loop`, `if`, `try`, or `try_table` carries HOT control flags into the subtree effect mask, so control-containing value roots still receive the old recursive region processing.

## Validation

Commands run after the code change:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon fmt
moon build --target-dir target --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-hso-control-skip-20260625-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Results:

- Focused HSO tests: `416/416` passed.
- `moon fmt`: passed.
- Native `src/cmd` build: passed with the pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct compare smoke: `1000/1000` compared, `1000` normalized matches, `0` mismatches, `0` validation/property/generator/command failures. Cache counters: wasm-smith `0/0`, Binaryen `1000` hits / `0` misses, Binaryen failures `0/0`.

## Allocation-heavy timing after the change

Reused the `1084` fixtures and reran three Starshine traced HSO passes for the 1000-function and 2000-function cases. Every emitted wasm validated with `wasm-tools validate --features all`.

| Fixture | Before Starshine HSO median | After Starshine HSO samples | After median | Prior Binaryen median | After ratio |
|---:|---:|---:|---:|---:|---:|
| 1000 functions | `5.904ms` | `5.600ms`, `5.612ms`, `5.783ms` | `5.612ms` | `0.791ms` | `7.1x` |
| 2000 functions | `11.988ms` | `11.542ms`, `11.199ms`, `11.145ms` | `11.199ms` | `2.110ms` | `5.3x` |

## Interpretation

This is a correctness-preserving micro-optimization and a small HSO-I improvement, not a performance closeout. The allocation-heavy fixture still misses the pass-local target (`starshine_time <= 2 * binaryen_time`). The improvement is roughly `5%` on the 1000-function fixture and `7%` on the 2000-function fixture, confirming that straight-line pre-scan overhead was part of the HSO-owned linear cost but not the dominant remaining cost.

HSO-I stays open. Next likely HSO-owned targets are repeated simple-shape safety predicate calls in `hso_process_local_set_chain(...)` / `hso_try_fold_into_struct_new(...)` and per-function cache allocation or initialization overhead on thousands of tiny functions. Do not weaken ordering or skip-local-set guards to chase this target.
