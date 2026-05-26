---
kind: research
status: complete
date: 2026-05-25
sources:
  - ../../binaryen/passes/dae-optimizing/starshine-strategy.md
  - ../../../../agent-todo.md
  - ./0581-2026-05-25-dae-func505-bool-carrier-cleanup.md
  - ../../../../.tmp/dae-func505-bool-carrier-artifact/result.json
  - ../../../../.tmp/dae-func505-bool-carrier-artifact/func-defined505-abs522.starshine.pretty.txt
  - ../../../../.tmp/dae-func505-bool-carrier-artifact/func-defined505-abs522.binaryen.pretty.txt
---

# DAE Func505 underscore guard reduction

## Question

After the selected-Func505 bool-carrier cleanup, is the remaining underscore guard polarity around `Func4495` a real DAE semantics risk, a pass-side cleanup target, or compare-layer representation drift?

## Result

The underscore guard subshape is a **representation-only control-polarity difference** in the saved `.tmp/dae-func505-bool-carrier-artifact` first-diff function. No pass behavior or compare tooling changed in this slice.

The inspected Starshine shape is:

```wat
local.get $char
i32.const 95
call $Func4495
if
  br $after-digit-parse
else
  ;; digit/error/overflow parse body
end
```

The inspected Binaryen shape is:

```wat
local.get $char
i32.const 95
call $Func4495
i32.eqz
if
  ;; digit/error/overflow parse body
end
```

Those forms run the same `Func4495` predicate once with the same operands and preserve the same parse body effects. If `Func4495` returns nonzero, Starshine enters the `then` arm and branches to the same continuation that Binaryen reaches by skipping the `eqz`-guarded `if`. If `Func4495` returns zero, Starshine enters the `else` parse body and Binaryen enters the `eqz`-guarded parse body. The polarity difference does not duplicate, delete, or reorder the predicate call or parse body.

## Evidence

Saved artifact:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --dae-optimizing \
  --canonicalize-binaryen-output \
  --out-dir .tmp/dae-func505-bool-carrier-artifact
```

`result.json` reports the same first differing function as before this reduction:

- first differing function: `defined=505 abs=522`;
- Starshine pass runtime: `2721.553ms`;
- Binaryen pass runtime: `873.679ms`;
- both-canonical outputs were already validated in the prior 0581 slice.

The inspected pretty dumps show the predicate call and parse body remain in the same relative order. The remaining first-diff regions also include loop induction/exit-carrier structure, overflow/error-return construction, and temporary local reuse, so this reduction alone is not enough to classify the whole Func505 frontier as representation-only.

## Classification

Agent classification for the underscore guard polarity subshape: **representation-only**.

Rationale: the branch is an ordinary boolean control inversion around a single predicate call and a shared continuation. WebAssembly `if` treats nonzero `i32` as true, so `if (p) br K else BODY` is equivalent to `if (eqz p) BODY` when the `then` branch has no effects before the branch and both paths join at `K`. That matches the inspected pretty dumps for this subshape.

Agent classification for the overall Func505 frontier: **still unknown/risky current DAE output-shape drift**.

Rationale: the underscore guard polarity is now reduced, but the first diff still contains live loop, allocation, call, store, and return structure outside this local polarity change. Those remaining regions are not safe diagnostic-normalizer targets until separately reduced.

## Next action

Keep `[DAE]006` open. The next productive reduction should target one of the remaining live Func505 regions before adding pass logic or a diagnostic-only normalizer:

1. loop induction and exit carrier;
2. overflow/error-return construction and temp-local reuse.

If a later compare-tool slice chooses to normalize this underscore polarity, it should use a narrow fixture that proves the `if (p) br K else BODY` to `if (eqz p) BODY` shape without broadening raw wasm comparison.
