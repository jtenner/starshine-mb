# Heap Store Optimization Descriptor Global/Call Movement

Date: 2026-06-20

## Question

Does Binaryen `version_130` allow a `struct.set` value containing a call to move before a descriptor operand that is an immutable `global.get`, and does it still block the same movement when the descriptor global is mutable?

This distinguishes the release-oracle `orderedBefore(...)` descriptor operand check from Starshine's older broad effect-mask approximation, which treated any call as ordered with any global read.

## Binaryen probes

Local oracle: `wasm-opt version 130 (version_130)`.

### Immutable descriptor global

Probe shape:

```wat
(module
  (rec
    (type $pair (descriptor $descT) (struct (field (mut i32)) (field (mut i32))))
    (type $descT (describes $pair) (struct)))
  (type $helper (func (param i32) (result i32)))
  (import "env" "desc" (global $desc (ref (exact $descT))))
  (import "env" "helper" (func $helper (type $helper)))
  (func $f
    (local $x (ref null $pair))
    (local.set $x
      (struct.new_desc $pair
        (i32.const 0)
        (i32.const 10)
        (global.get $desc)))
    (struct.set $pair 0
      (local.get $x)
      (call $helper (i32.const 1)))))
```

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-probe-desc-moved-call.wat \
  -o .tmp/hso-probe-desc-moved-call.opt.wat
```

Observed result: Binaryen folds the store. The optimized constructor contains the `call $helper` as field `0`, the immutable descriptor `global.get $desc` remains as the descriptor operand, and no `struct.set` remains.

### Mutable descriptor global

Probe shape differs only in the descriptor global import:

```wat
(import "env" "desc" (global $desc (mut (ref (exact $descT)))))
```

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-probe-desc-mutable-global-call.wat \
  -o .tmp/hso-probe-desc-mutable-global-call.opt.wat
```

Observed result: Binaryen keeps the `struct.set`. The descriptor `global.get` remains before `struct.new_desc`, and the moved `call $helper` remains in the later store value.

## Starshine change

Added focused tests in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization moves call value before immutable descriptor global`
- `heap-store-optimization keeps struct.set before mutable descriptor global and moved call`

The positive immutable-global test failed before implementation because Starshine's descriptor operand barrier treated `global.get` and `call` as ordered solely from broad effect masks.

Implementation:

- `hso_desc_operand_effects_for_node(...)` now treats descriptor `global.get` as pure only when `HotModuleContext` proves the global type is immutable.
- Mutable descriptor globals retain the ordinary global-state effect and continue to block call movement.
- `hso_struct_new_shallow_effects(...)` now models `struct.new_desc` / `struct.new_default_desc` wrapper effects as empty for this HSO movement check. Descriptor operand effects remain checked separately, matching the Binaryen probes above.

## Validation

Focused red/green loop:

- Before implementation: `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` failed exactly `heap-store-optimization moves call value before immutable descriptor global`; Starshine kept `struct.set`.
- After implementation: same focused command passed `52/52`.

Full slice validation:

- `moon test src/passes` passed `2890/2890`.
- `moon fmt && moon build --target native --release --target-dir target src/cmd` passed; the build emitted existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-descriptor-global-call-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` compared `9977/10000`, normalized `9977`, cleanup-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, and command failures `23` (`binaryen-rec-group-zero=22`, `binaryen-bad-section-size=1`). Cache counters: wasm-smith `5000/0`, Binaryen `9977/0`, Binaryen failures `23/0`.
- `moon info && moon test` passed; full `moon test` reported `6249/6249`.

## Classification

This was a concrete Binaryen behavior parity gap, not a Starshine-win output difference. Starshine overblocked a source-backed movement family that Binaryen `version_130` allows for immutable descriptor globals and rejects for mutable descriptor globals.

## Follow-ups

Descriptor wrapper and immutable-global operand direction are now covered for moved calls. Remaining HSO audit work still includes broader descriptor operand expressions, later-field barriers, swap legality, control-flow skip-local-set exactness, unreachable no-fold boundaries, O4z slot/neighborhood evidence, and final closeout lanes.
