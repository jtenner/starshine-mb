---
kind: research
status: supported
date: 2026-06-25
sources:
  - ../../binaryen/passes/code-pushing/fuzzing.md
  - ../../binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
---

# Code-pushing current 10000-case aggregate profile refresh

## Slice

`[O4Z-AUDIT-CP-QQ]` reran the then-current dedicated `code-pushing-all` GenValid profile after the prefix-payload `br_on_non_null` and value-`br_if` leaves joined the aggregate. This is closeout-progress evidence only, not final `[O4Z-AUDIT-CP]` closeout.

## Command

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-all-10000-20260625-current --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

## Result

- Compared: `10000/10000`
- Normalized matches: `4769`
- Cleanup-normalized matches: `5231`
- Raw mismatches: `0`
- Validation failures: `0`
- Generator failures: `0`
- Property failures: `0`
- Command failures: `0`
- Jobs: `16`
- Cache: wasm-smith `0` hits / `0` misses; Binaryen `10000` hits / `0` misses; Binaryen failures `0` hits / `0` misses

Selected profile counts:

| Selected profile | Count |
| --- | ---: |
| `code-pushing-multi-set-dropped-if` | 530 |
| `code-pushing-after-if` | 558 |
| `code-pushing-multi-set-local-copy` | 520 |
| `code-pushing-br-on-null` | 524 |
| `code-pushing-multi-set-nop-window` | 540 |
| `code-pushing-br-on-cast` | 565 |
| `code-pushing-br-on-non-null` | 555 |
| `code-pushing-multi-set` | 507 |
| `code-pushing-multi-set-local-get-window` | 515 |
| `code-pushing-br-if` | 537 |
| `code-pushing-loop-br-if` | 511 |
| `code-pushing-br-on-cast-fail` | 526 |
| `code-pushing-dropped-if` | 510 |
| `code-pushing-multi-set-br-if` | 511 |
| `code-pushing-multi-set-global-get-window` | 554 |
| `code-pushing-br-on-non-null-prefix` | 513 |
| `code-pushing-multi-set-drop-window` | 504 |
| `code-pushing-br-if-value` | 516 |
| `code-pushing-if-arm` | 504 |

## Classification

The lane is green under the documented `local-cleanup-debris` normalizer. The `5231` cleanup-normalized cases are agent-classified as local cleanup/lowering debris already narrowed in the prefix and value-`br_if` normalizer slices; the harness count alone is not a semantic proof. There were no raw mismatches after normalization and no Starshine validation/generator/property/command failures.

## Remaining closeout work

Final closeout remains open. This lane replaces the older 17-leaf 10000-case aggregate evidence and the 19-leaf 1000-case smokes, but it does not replace:

- a then-current `100000` regular GenValid lane;
- a fresh explicit wasm-smith lane if final source-gap resolution changes behavior after the earlier closeout-progress lane;
- a fresh broad named lane if final source-gap resolution changes behavior after the earlier `pass-fuzz-stress` lane;
- source-backed resolution or narrow accepted boundaries for remaining switch/`br_table`, broader `br_on_*`, ordered-window, local-copy dependency, and precise `orderedBefore` / atomics / GC / EH / trap surfaces.
