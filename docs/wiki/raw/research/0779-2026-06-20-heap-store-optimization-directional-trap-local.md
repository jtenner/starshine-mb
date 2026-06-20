---
kind: research
status: supported
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ../../binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0778-2026-06-20-heap-store-optimization-shallow-effects-fold.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` directional trap/local movement fix

Question: does Starshine match Binaryen `version_130` when a moved `struct.set` value has only local side effects and the later constructor field may trap?

## Answer

Not before this slice. Binaryen `version_130` uses directional `EffectAnalyzer::orderedBefore(...)` for later constructor operands before moving the stored value earlier. A focused oracle probe showed Binaryen folds this shape:

- constructor field `1`: `i32.load`, which can read memory and trap;
- later `struct.set` value for field `0`: a block that performs `local.set $tmp` and returns an `i32`;
- folding moves the local-only side effect before the trapping load.

Binaryen allows this because local state is not externally observable after a trap. Starshine's prior `hso_mask_invalidates(...)` approximation treated any trapping later operand as an unconditional symmetric barrier, so it kept the `struct.set`.

The fix adds a directional HOT effect predicate for HSO movement barriers. In particular, a barrier trap no longer blocks moving a value that only mutates local state, while traps still block movement across non-local writes. The later-field, descriptor-operand, and shallow-constructor movement checks now use this directional predicate instead of the old symmetric approximation.

This is a Binaryen behavior-parity fix, not an output-parity exception.

## Test added

`src/passes/heap_store_optimization_test.mbt` now includes `heap-store-optimization moves local-only set value before later trapping load`.

The test failed before the implementation because the optimized function still contained `struct.set`. It passes after the directional effect-order change and the folded output keeps the `i32.load` and moved local-only value inside `struct.new`.

## Validation

Commands run in this slice:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon test src/passes
moon fmt
moon build --target native --release --target-dir target src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-directional-trap-local-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures
moon info
moon test
```

Results after the fix:

- focused HSO tests: `50/50` passed;
- `moon test src/passes`: `2888/2888` passed;
- `moon fmt`: passed;
- native `src/cmd` build into `target/`: passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`;
- direct 10000-case compare: requested `10000`, compared `9977`, normalized `9977`, cleanup-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `23`;
- `moon info`: passed with existing generator warnings;
- full `moon test`: `6247/6247` passed.

Command-failure classes from `result.json`:

- `binaryen-rec-group-zero=22`
- `binaryen-bad-section-size=1`

Agent classification: the direct lane found no HSO behavior mismatch or output drift requiring classification. The command failures are Binaryen/oracle boundaries, not Starshine semantic failures.

## Remaining HSO audit work

This closes one source-backed directional later-field operand subfamily: trapping later field before moved local-only side effects.

Still open:

- descriptor wrapper and descriptor operand directional barriers;
- `trySwap(...)` directionality;
- exact control-flow skip-local-set parity;
- default/descriptor old-field combinations;
- saved early/late O4z slot or neighborhood evidence for `[O4Z-AUDIT-HSO-B]`;
- final 100000-case closeout and backlog cleanup.
