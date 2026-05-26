---
kind: research
status: complete
date: 2026-05-26
sources:
  - ../../binaryen/passes/dae-optimizing/starshine-strategy.md
  - ../../../../agent-todo.md
  - ./0583-2026-05-26-dae-func505-overflow-temp-reduction.md
  - ../../../../.tmp/dae-func505-bool-carrier-artifact/result.json
  - ../../../../.tmp/dae-func505-bool-carrier-artifact/func-defined505-abs522.starshine.wat
  - ../../../../.tmp/dae-func505-bool-carrier-artifact/func-defined505-abs522.binaryen.wat
---

# DAE Func505 loop induction and exit-carrier reduction

## Question

After the underscore guard and overflow/error-return reductions, is the remaining Func505 loop induction and exit-carrier structure a real DAE semantics risk, a pass-side cleanup target, or compare-layer representation drift?

## Result

The inspected loop induction and exit-carrier subshape in the saved `.tmp/dae-func505-bool-carrier-artifact` first-diff function is **representation-only control and local-carrier drift**. No pass behavior or compare tooling changed in this slice.

Both sides implement the same parser loop:

1. initialize the index to `0`;
2. while the index is signed-less-than the input length, bounds-check and load the UTF-16 code unit at `input + index * 2`;
3. skip the digit/overflow/count-update body when the code unit is underscore (`95`);
4. otherwise run the digit/error/overflow path and update the accumulator and count boxes;
5. continue with `index + 1`;
6. exit the loop when `index >= length`, then branch on the parsed-count box and return either the empty-input error or the boxed accumulator.

The Starshine shape carries the index through a high-numbered temporary (`$99`, snapshot `$76`) and writes it with an outer `local.set` around a value-producing block. The Binaryen shape carries the same value in low local `$3` and uses a smaller value-producing block. Starshine prints the loop guard as `index < length`; Binaryen prints it as `length > index`. Starshine represents underscore skip as `if (is_underscore) br body_done else parse_body`; Binaryen represents the same choice as `if (eqz is_underscore) parse_body`. Both join at the same continuation that returns `index + 1` to the loop-carrier block.

The exit carrier is also equivalent. Starshine exits through an extra named block after a `drop (i32.const 0)` debris node; Binaryen exits through the immediately enclosing block. Neither side uses the induction local after the loop. Both read the parsed-count box, free it, choose the same empty-input-vs-success branch, then read/free the accumulator box and return the same boxed `i64` value on success.

## Evidence

Saved artifact:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --dae-optimizing \
  --canonicalize-binaryen-output \
  --out-dir .tmp/dae-func505-bool-carrier-artifact
```

`result.json` reports:

- first differing function: `defined=505 abs=522`;
- Starshine pass runtime: `2721.553ms`;
- Binaryen pass runtime: `873.679ms`;
- the artifact was validated in the prior 0581 slice.

Inspected anchors in `func-defined505-abs522.starshine.wat` and `func-defined505-abs522.binaryen.wat`:

- Starshine initializes `$99` to `0`; Binaryen initializes `$3` to `0`.
- Starshine guard: `i32.lt_s (local.tee $76 (local.get $99)) (call $9 (local.get $0))`.
- Binaryen guard: `i32.gt_s (call $9 (local.get $0)) (local.get $3)`.
- Starshine load index: `$76`; Binaryen load index: `$3`.
- Starshine continue value: `i32.add (local.get $76) (i32.const 1)`.
- Binaryen continue value: `i32.add (local.get $3) (i32.const 1)`.
- Starshine and Binaryen both update the same accumulator and parsed-count boxes only on the non-underscore, non-error path.
- Starshine and Binaryen both leave the loop before reading the parsed-count box when the signed guard fails.

The remaining textual mismatch is therefore a combination of extra local declarations, high-local carrier naming, block-label factoring, guard polarity, underscore-branch polarity, temporary-local spills, and dropped pure `0` debris already covered by earlier Func505 reductions.

## Classification

Agent classification for the loop induction and exit-carrier subshape: **representation-only**.

Rationale: signed `index < length` and `length > index` are the same predicate; both loops start from zero, advance by one only after the same code-unit load and body/skip decision, use the same index for the load and bounds check, and exit before post-loop parsed-count handling under the same condition. The extra Starshine block and dropped-zero debris do not alter effects or values. The induction carrier local is not read after the loop, so high-local versus low-local placement is local-numbering drift.

Agent classification for the saved Func505 first-diff body: **representation-only after inspected subshape reductions**.

Rationale: previous notes reduced the default-zero high guard, empty-input count branch, lower-bound bool carrier, underscore guard polarity, and overflow/error-return temp-local drift. This note reduces the remaining loop induction and exit carrier. The canonical compare still first-diffs at Func505 because no diagnostic normalizer or pass-shape cleanup changed in this slice, but the inspected body-level differences are now attributable to representation/control factoring rather than a known semantic DAE risk.

## Next action

Treat `[DAE]006` Func505 semantic-risk reduction as complete for the saved `.tmp/dae-func505-bool-carrier-artifact` body. The next productive implementation slice should either:

1. add narrow diagnostic-only compare normalizers for the now-classified Func505 representation families and replay the both-canonical artifact to discover the next frontier; or
2. leave Func505 as a documented representation boundary and move to another DAE backlog slice such as `[DAE]002`, `[DAE]003`, `[DAE]004`, or `[DAE]011`.

Do not change raw wasm comparison behavior for this classification-only result.
