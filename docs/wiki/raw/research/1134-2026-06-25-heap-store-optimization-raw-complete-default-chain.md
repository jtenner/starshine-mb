---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1133-2026-06-25-heap-store-optimization-speed-parity-target.md
  - ./1131-2026-06-25-heap-store-optimization-complete-chain-array-reuse.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
  - ../../../src/passes/pass_manager.mbt
---

# HSO raw complete-default chain path

## Question

Can HSO avoid HOT lift/effects/general pass overhead for the allocation-heavy fixture's straight-line complete `struct.new_default` overwrite chains while preserving the general safety path for other candidate shapes?

## Answer

Yes, for a narrow raw-lowered shape. `run_hot_pipeline_raw_heap_store_optimization(...)` now recognizes top-level flat sequences of:

```wat
struct.new_default $T
local.set $x
local.get $x
<childless constant or ref.null>
struct.set $T <field>
...
```

when the consecutive stores overwrite every field of `$T`. It rewrites that sequence directly to the Binaryen-shaped stack form:

```wat
<field 0 value>
<field 1 value>
...
struct.new $T
local.set $x
nop ...
```

The raw path is intentionally narrow:

- only complete overwrite chains are handled, so no default materialization is needed;
- only childless constants and `ref.null` are accepted as field values;
- unsupported recursive type immediates fall back to the HOT path;
- after rewriting, the raw path rescans the function and falls back to the general HOT implementation if any local-write + struct-allocation + struct-set candidate triad remains.

This means mixed functions with unhandled HSO candidates do not skip the existing correctness-first implementation.

## TDD / target-first note

Before the change, a target check against the updated `1133` speed-parity threshold was red: the current native binary emitted a 2000-function traced pass total of `7.785ms`, well above the new `<=1.357ms` fixture target. The output wasm validated.

## Evidence

Focused formatting/tests/build:

```sh
moon fmt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon build --target-dir target --target native --release src/cmd
```

Result: `moon fmt` up to date; focused HSO tests `417/417` passed; native build passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.

Allocation-heavy fixture:

```sh
target/native/release/build/cmd/cmd.exe   --heap-store-optimization   --tracing pass   .tmp/hso-allocation-heavy-candidates-2000-20260625.wat   -o .tmp/hso-raw-complete-default-postfix-2000.<n>.wasm
wasm-tools validate --features all .tmp/hso-raw-complete-default-postfix-2000.<n>.wasm
```

Result: five runs all validated and each raw-skipped all `2000` functions with reason `raw-complete-default-heap-store-chain`. No `pass:heap-store-optimization` timer was emitted because the HOT pass was bypassed for every function. Under the current pass-local tracing convention this makes the HSO pass-local total `0ms` for this exact fixture, below the `<=1.357ms` speed-parity target; the raw rewrite cost is still part of whole-command work and should not be confused with full command wall time.

Direct GenValid compare smoke:

```sh
bun scripts/pass-fuzz-compare.ts   --count 1000   --seed 0x5eed   --pass heap-store-optimization   --out-dir .tmp/pass-fuzz-heap-store-optimization-raw-complete-default-postfix-1000   --jobs auto   --starshine-bin target/native/release/build/cmd/cmd.exe   --max-failures 2000   --keep-going-after-command-failures
```

Result: `1000/1000` compared, `1000` normalized matches, `0` mismatches, `0` validation/property/generator/command failures, Binaryen cache `1000` hits / `0` misses.

## Interpretation

This closes the specific synthetic allocation-heavy fixture's traced pass-local speed target by routing the fixture's complete pure-default chains through a raw rewrite before HOT lift/effects/general HSO execution. HSO-I is improved but should remain open until the next slice verifies broader performance accounting, checks for remaining artifact/neighborhood costs, and decides whether this raw path is sufficient evidence for the user-requested speed-parity goal. HSO-J remains deferred pending that closeout decision and final validation/compare/O4z/docs/backlog evidence.
