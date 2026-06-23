# 0837 - optimize-instructions OI-G widen stores of i32.wrap_i64

## Scope

Continue `[O4Z-AUDIT-OI-G]` with one narrow store-value sub-slice: widen an i32-typed store whose direct one-use value child is `i32.wrap_i64` to the matching i64 store, dropping the wrap.

This slice covers only:

- `i32.store8(addr, i32.wrap_i64(v))` -> `i64.store8(addr, v)`;
- `i32.store16(addr, i32.wrap_i64(v))` -> `i64.store16(addr, v)`;
- `i32.store(addr, i32.wrap_i64(v))` -> `i64.store32(addr, v)`;

when the `i32.wrap_i64` is the direct value operand of the store and has exactly one use. Storing the low N bits of `(i32.wrap_i64 v)` is equivalent to storing the low N bits of `v` directly via the matching i64 narrow store, so the wrap becomes dead and the store widens to avoid the redundant wrap.

The reverse direction (`i64.store8` / `i64.store16` of `i64.extend_i32_u` / `i64.extend_i32_s`) is **not** folded by Binaryen and is locked as a parity boundary. Multi-use wraps (for example a wrap spilled to a local and read back) are not a direct value child, so they are naturally left unchanged.

## Binaryen oracle

Probe files: `.tmp/oi-g-store-value-probe.wat` and `.tmp/oi-g-wrap-store-probe.wat`.

Commands:

```sh
wasm-opt .tmp/oi-g-wrap-store-probe.wat -S --optimize-instructions -o -
wasm-opt .tmp/oi-g-wrap-store-probe.wat -S -O --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior:

- `i32.store8(0, i32.wrap_i64(x))` -> `i64.store8(0, x)` under both the direct `--optimize-instructions` lane and the O4z-style `-O` lane.
- `i32.store16(0, i32.wrap_i64(x))` -> `i64.store16(0, x)`.
- `i32.store(0, i32.wrap_i64(x))` -> `i64.store32(0, x)`.
- `i64.store8(0, i64.extend_i32_u(x))` and `i64.extend_i32_s(x)` kept verbatim (reverse direction not folded).
- A multi-use wrap spilled to a local kept the `i32.store8(local.get $w)` form.

This is OI-owned: the direct `--optimize-instructions` lane performs the widening.

## Starshine change

`src/passes/optimize_instructions.mbt` adds `optimize_instructions_try_widen_store_of_wrap_i64` and wires it into the `Store` visitor arm after the existing constant-offset, constant-truncation, and mask-drop helpers. The helper proves:

- the store has exactly two operands;
- the store is `i32.store8` / `i32.store16` / `i32.store` (mapping to `i64.store8` / `i64.store16` / `i64.store32` with the same `MemArg`);
- the value child is a live direct `i32.wrap_i64` with exactly one child;
- the wrap has exactly one use (this store), so it becomes dead after the rewrite.

It then rewrites the store node in place to the matching i64 store with children `[addr, wrap_operand]`.

## Tests and validation

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*widens narrow stores of i32.wrap_i64*'
```

Before implementation this failed because the optimized function still printed `i32.wrap_i64` followed by `i32.store8` / `i32.store16` / `i32.store`. After implementation the focused filter passed `1/1`, and the reverse-direction boundary filter also passed `1/1`.

A `MoonBit` note for future slices: the pretty-printer spells the convert opcodes `i64.extend_i32u` / `i64.extend_i32s` (no underscore before the final width letter), and `I32WrapI64` is a read-only enum variant that can only be matched as a pattern, not constructed as a value.

Final validation for this slice:

- Binaryen O4z-style and direct oracle commands above widened all three i32 store shapes, kept the reverse extend direction, and kept the multi-use wrap.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*widens narrow stores*'` failed before implementation and passed `1/1` after.
- `*extend_i32 before i64*' passed `1/1` (reverse-direction parity boundary).
- `*optimize-instructions*' passed `223/223`.
- `moon fmt` passed.
- `moon test src/passes` passed `2753/2753`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `git diff --check && git diff --cached --check` passed.
- Direct compare smoke `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-wrap-store-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `1/1`, with normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`, cache counters wasm-smith `0` hits / `0` misses, Binaryen `1` hit / `0` misses, Binaryen failures `0` hits / `0` misses. Agent classification: the single raw mismatch was the known scalar output-shape family and was unrelated to this slice; grepping Starshine and Binaryen output artifacts found no `wrap_i64`, `i32.store`, `i64.store`, `store8`, `store16`, or `store32` occurrences in either output.

## Boundaries

- This is not general store-width rewriting. It requires an i32 store, a direct one-use `i32.wrap_i64` value child, and a matching widening target.
- The reverse direction (`i64.store8` / `i64.store16` of `i64.extend_i32_*`) is intentionally not folded, matching Binaryen.
- Multi-use wraps (spilled to a local) are not a direct value child and are left unchanged.
- `f32`/`f64` stores, atomic stores, and broader `optimizeStoredValue` / `maxBits` recursive analysis remain open `[O4Z-AUDIT-OI-G]` work.
