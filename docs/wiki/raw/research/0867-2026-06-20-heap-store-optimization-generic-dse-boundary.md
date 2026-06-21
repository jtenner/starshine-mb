---
kind: research
status: supported
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` generic DSE / load-forwarding boundary

Question: should the active HSO audit treat generic struct dead-store elimination or generic struct load forwarding as pass-owned behavior gaps?

## Answer

No. Binaryen `version_130` still preserves these generic heap-store patterns under `--heap-store-optimization`:

- repeated `struct.set` writes through a non-fresh reference are not dead-store-eliminated;
- `struct.get` after a `struct.set` through the same non-fresh reference is not load-forwarded.

This is a source-backed narrow non-goal, not a broad excuse to skip constructor/store folding. The upstream owner file still centers on `struct.set` folding into nearby fresh `struct.new*` constructors, and the TODO for broader dead-store elimination / load forwarding remains outside the implemented pass behavior.

## Binaryen `version_130` probe

Probe fixture:

```wat
(module
  (type $s (struct (field (mut i32))))
  (global $g (mut (ref null $s)) (ref.null $s))
  (func $dead_stores
    (global.get $g)
    (i32.const 1)
    (struct.set $s 0)
    (global.get $g)
    (i32.const 2)
    (struct.set $s 0))
  (func $load_forwarding (result i32)
    (global.get $g)
    (i32.const 7)
    (struct.set $s 0)
    (global.get $g)
    (struct.get $s 0))
)
```

Command:

```sh
wasm-opt --all-features .tmp/hso-probe-generic-dse-load-forwarding.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-generic-dse-load-forwarding.opt.wat

grep -n "func \\$\|struct.set\|struct.get\|i32.const" \
  .tmp/hso-probe-generic-dse-load-forwarding.opt.wat
```

Observed grep output:

```text
7:  (struct.set $s 0
9:   (i32.const 1)
11:  (struct.set $s 0
13:   (i32.const 2)
17:  (struct.set $s 0
19:   (i32.const 7)
21:  (struct.get $s 0
```

## Starshine coverage

Added focused boundary tests in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization does not do generic struct dead-store elimination`
- `heap-store-optimization does not do generic struct load forwarding`

Both use non-fresh nullable local references so the pass cannot justify the rewrite as fresh-constructor folding. The focused HSO test file passed `226/226` after adding the tests.

## Reopening criteria

Reopen this boundary if a future Binaryen release implements generic heap dead-store elimination or load forwarding inside `heap-store-optimization`, or if Starshine adds a separate explicitly scheduled pass for those transforms. This boundary does not permit skipping any source-backed `struct.set` into fresh `struct.new*` folding family.
