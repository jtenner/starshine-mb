---
kind: research
status: supported
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ../../binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0777-2026-06-20-heap-store-optimization-hso-b-direct-baseline.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` shallow constructor effect parity fix

Question: does Starshine match Binaryen `version_130` for the lit/source family where a plain `struct.new` field with old call effects is overwritten by a later call-valued `struct.set`?

## Answer

No, not before this slice. A focused TDD fixture based on Binaryen's dedicated lit family failed first:

- old field expression: `(call $helper (i32.const 0))`
- later moved store value: `(call $helper (i32.const 1))`
- constructor form: plain `struct.new`, no descriptor
- expected Binaryen behavior: fold the store into the constructor, preserve the old field call under a dropped sequence/block, and remove `struct.set`

Starshine kept `struct.set` because `hso_struct_new_shallow_effects(...)` treated every `struct.new*` wrapper as memory read/write/trap. That made the plain constructor wrapper look ordered before a side-effecting moved value even when Binaryen's `ShallowEffectAnalyzer` does not block the non-descriptor lit case.

The fix narrows Starshine's shallow wrapper effects:

- `struct.new` and `struct.new_default` now have no extra shallow wrapper effects beyond their already-checked children.
- `struct.new_desc` and `struct.new_default_desc` keep the conservative descriptor wrapper effect barrier until descriptor-specific directional tests classify it.

This is a Binaryen behavior-parity fix, not an output-parity exception.

## Tests added

`src/passes/heap_store_optimization_test.mbt` now covers three source-backed call-effect shapes:

1. preserve an old field call when folding a tee store to a plain constructor;
2. keep `struct.set` when a later constructor field call must remain ordered before a moved call;
3. fold a moved call when the only call effect being crossed is the old replaced field, preserving that old field effect.

The third test failed before the implementation change and passed after the shallow-effect narrowing.

## Validation

Commands run in this slice:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon test src/passes
moon fmt
moon build --target native --release --target-dir target src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-shallow-effects-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures
moon info
moon test
```

Results:

- focused HSO tests: `49/49` passed after the fix;
- `moon test src/passes`: `2887/2887` passed;
- `moon fmt`: passed;
- native `src/cmd` build into `target/`: passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`;
- direct 10000-case compare: requested `10000`, compared `9977`, normalized `9977`, cleanup-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `23`.
- `moon info`: passed with existing warnings in generator code.
- full `moon test`: `6246/6246` passed.

Command-failure classes from `result.json`:

- `binaryen-rec-group-zero=22`
- `binaryen-bad-section-size=1`

Agent classification: the direct lane found no HSO behavior mismatch or output drift requiring classification. The command failures are Binaryen/oracle boundaries, not Starshine semantic failures.

## Remaining HSO audit work

This slice only closes the plain-constructor shallow-effect overblocking family and adds adjacent old-field/later-field call-effect coverage. It does not close the full directional `orderedBefore(...)` audit:

- descriptor shallow wrapper effects still need focused positive/negative tests;
- later field and descriptor operand directional barriers still need more narrow probes;
- `trySwap(...)` directional legality remains open;
- saved early/late O4z slot or neighborhood evidence is still pending for `[O4Z-AUDIT-HSO-B]`.
