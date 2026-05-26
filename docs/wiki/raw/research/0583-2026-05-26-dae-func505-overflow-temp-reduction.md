---
kind: research
status: complete
date: 2026-05-26
sources:
  - ../../binaryen/passes/dae-optimizing/starshine-strategy.md
  - ../../../../agent-todo.md
  - ./0582-2026-05-25-dae-func505-underscore-guard-reduction.md
  - ../../../../.tmp/dae-func505-bool-carrier-artifact/result.json
  - ../../../../.tmp/dae-func505-bool-carrier-artifact/func-defined505-abs522.starshine.pretty.txt
  - ../../../../.tmp/dae-func505-bool-carrier-artifact/func-defined505-abs522.binaryen.pretty.txt
---

# DAE Func505 overflow guard and temp-local reduction

## Question

After the underscore guard polarity reduction, is the remaining Func505 overflow/error-return region a real DAE semantics risk, a pass-side cleanup target, or compare-layer representation drift?

## Result

The inspected overflow guard and error-return construction subshape is a **representation-only operand-polarity and temporary-local difference** in the saved `.tmp/dae-func505-bool-carrier-artifact` first-diff function. No pass behavior or compare tooling changed in this slice.

The inspected Starshine shape computes the overflow limit into a temporary local and tests:

```wat
(i64.const -1)
(local.get $digit)
(i32.const 48)
i32.sub
call $Func4490
local.tee $digit64
i64.sub
(i64.const 10)
i64.div_u
local.set $limit

(local.get $acc_box)
i64.load offset=8
(local.get $limit)
i64.gt_u
if
  ;; construct and return the parse error object
end
```

The inspected Binaryen shape keeps the same limit expression on the stack and tests the flipped comparison:

```wat
(i64.const -1)
(local.get $digit)
(i32.const 48)
i32.sub
call $Func4490
local.tee $digit64
i64.sub
(i64.const 10)
i64.div_u

(local.get $acc_box)
i64.load offset=8
i64.lt_u
if
  ;; construct and return the parse error object
end
```

For unsigned integers, `acc > limit` and `limit < acc` are the same predicate. The saved pretty dumps show the same digit conversion input, the same unsigned division by `10`, the same accumulator load from the boxed accumulator, and the same error-return path shape. Starshine spills the limit and uses fresh temporary locals for intermediate allocator values; Binaryen keeps more values in reused low-numbered locals. That is local numbering / stack-vs-local carrier drift, not a different overflow threshold.

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
- the artifact was already validated in the prior 0581 slice.

The inspected pretty dumps line up on these semantic anchors:

1. both allocate and initialize the accumulator and count boxes before the loop;
2. both load the current UTF-16 code unit and convert `code - 48` through `Func4490`;
3. both compute `((-1 - digit64) / 10)` as the maximum safe accumulator value before multiplying by `10` and adding `digit64`;
4. both enter the same parse-error construction path exactly when `accumulator > max_safe_accumulator`;
5. both update the accumulator box and count box on the non-error path.

The remaining first-diff region still includes the broader loop induction and exit-carrier structure, especially Starshine's explicit `0` induction/local carrier versus Binaryen's reused low local and loop `set` shape. That broader loop shape still needs a separate reduction before the whole Func505 frontier can be classified as representation-only.

## Classification

Agent classification for the overflow guard and error-return temp-local subshape: **representation-only**.

Rationale: the difference is the unsigned comparison identity `acc > limit` versus `limit < acc`, plus spilling/reusing temporary locals around the same limit expression and same error-construction calls. No loads, stores, allocator calls, predicate calls, or returns are deleted, duplicated, or reordered across the overflow branch in the inspected subshape.

Agent classification for the overall Func505 frontier: **still unknown/risky current DAE output-shape drift**.

Rationale: this reduction narrows the overflow/error-return region, but the saved first-diff function still has live loop induction and exit-carrier differences outside the reduced subshape. Those loop differences control how input characters are traversed and when the parse loop exits, so they are not safe to normalize or rewrite until separately reduced.

## Next action

Keep `[DAE]006` open. The next productive reduction should target the remaining loop induction and exit-carrier structure in Func505. If that loop shape proves equivalent, a later compare-tool slice can decide whether to add narrow diagnostic-only normalizers for the underscore polarity and overflow comparison polarity; raw wasm comparison should remain unchanged.
