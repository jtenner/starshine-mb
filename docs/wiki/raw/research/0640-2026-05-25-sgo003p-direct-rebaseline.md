---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../agent-todo.md
  - ../../binaryen/passes/simplify-globals-optimizing/parity-matrix.md
  - ../../binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md
  - ../../../../.tmp/pass-fuzz-sgo003p-rebaseline-10k/result.json
---

# SGO direct-pass rebaseline (`[SGO]003P`)

## Scope

This slice refreshes direct `simplify-globals-optimizing` evidence after the recent `[SGO]003` guardrail, research, and source-alignment slices. It does not claim full Binaryen `SimplifyGlobals.cpp` parity and does not change optimizer behavior.

## Commands

```sh
moon info
moon fmt
moon test
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo003p-rebaseline-10k
```

## Results

- `moon info`: completed; existing DAE unused warnings only.
- `moon fmt`: completed.
- `moon test`: `3672/3672` passed.
- Direct SGO fuzz: `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.
- Command-failure classes: `22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`.

## Interpretation

The current direct pass remains semantically aligned on the compared corpus for the supported surface: no normalized mismatches and no Starshine validation failures were observed. The unmatched cases are the established Binaryen/tool failure classes from wasm-smith inputs, not SGO semantic mismatches.

This rebaseline supports continuing `[SGO]003` breadth work from focused, source-backed slices. It does not retire the parent `[SGO]003` coordination item, and it does not broaden calls, same-init expression equivalence, GC refinalization, runtime joins, nested cleanup scheduler behavior, or unprobed effectful/trapping surfaces.

## Remaining risks

- Full Binaryen `SimplifyGlobals.cpp` breadth remains incomplete.
- Direct-call read/write summaries, runtime trace broadening, same-init expression equivalence, startup/GC follow-ups, and plain-pass exposure remain separate backlog slices.
- Future behavior-bearing SGO changes should run another direct-pass compare rather than relying on this rebaseline alone.
