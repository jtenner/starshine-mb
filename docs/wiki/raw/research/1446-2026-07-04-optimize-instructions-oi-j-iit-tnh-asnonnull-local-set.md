# OI-J IIT/TNH `ref.as_non_null` local-write slice

Date: 2026-07-04

## Scope

This slice covers one finite OI-J trap-mode gap from roadmap probe 13: removing an implicit null check from a local write when trap-ignoring modes make the check unnecessary and the target local already accepts the original nullable value.

Implemented shape:

```wat
(func (param $x anyref)
  (local.set $x (ref.as_non_null (local.get $x))))
```

Binaryen `version_130` behavior:

- default `--optimize-instructions`: preserves `ref.as_non_null`;
- `--ignore-implicit-traps --optimize-instructions`: rewrites to `local.set $x (local.get $x)`;
- `--traps-never-happen --optimize-instructions`: rewrites to `local.set $x (local.get $x)`.

This does not claim broad `ref.as_non_null` erasure, descriptor-cast behavior, `ref.test_desc`, useful-type-info breadth, or effect/control localization.

## Probe evidence

Probe directory: `.tmp/oi-j-iit-asnonnull-20260704/`.

Commands used:

- `wasm-opt --all-features --optimize-instructions -S .tmp/oi-j-roadmap-probes-20260703/inputs/13-iit-only-as-non-null-set.wat`
- `wasm-opt --all-features --ignore-implicit-traps --optimize-instructions -S ...`
- `wasm-opt --all-features --traps-never-happen --optimize-instructions -S ...`
- `target/native/release/build/cmd/cmd.exe --optimize-instructions ...`
- `target/native/release/build/cmd/cmd.exe --ignore-implicit-traps --optimize-instructions ...`
- `target/native/release/build/cmd/cmd.exe --traps-never-happen --optimize-instructions ...`
- `wasm-tools validate --features all` on Starshine outputs.

Before implementation, Starshine preserved `ref.as_non_null` in all three modes. The focused test failed red-first in the IIT case with residual `ref.as_non_null`.

## Implementation

`src/passes/optimize_instructions.mbt` now runs a narrow local-write helper for `LocalSet` / `LocalTee` roots. The helper:

- requires `ctx.ignore_implicit_traps` or `ctx.traps_never_happen`;
- requires exactly one child and that child to be `RefAsNonNull`;
- requires the nullable operand's result type to equal the written local type, so removing the null check cannot change the local write type;
- rewires the local write to the nullable operand and marks the pass mutated.

Default mode remains unchanged.

## Tests and validation

Added red-first test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions removes local ref.as_non_null sets under trap-ignoring modes`

Red result before implementation:

```text
moon test src/passes/optimize_instructions_test.mbt --target native --filter 'optimize-instructions removes local ref.as_non_null sets under trap-ignoring modes'
... failed with residual ref.as_non_null in the IIT output
```

Green result after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions removes local ref.as_non_null sets under trap-ignoring modes'
Total tests: 1, passed: 1, failed: 0.
```

## Remaining OI-J work

OI-J remains `blocked-surface`. Remaining active work includes:

- `ref.test_desc` text/binary/tooling representation;
- broader descriptor-cast and descriptor-test behavior;
- useful-type-info and exactness breadth beyond exact operands, strict-subtype operands, exact-subtype exact-target misses, and exact descriptor operands;
- TNH/IIT cases beyond this local-write shape and the existing descriptor-profile lanes;
- generalized descriptor effect/control localization and escaping-label localizers.
