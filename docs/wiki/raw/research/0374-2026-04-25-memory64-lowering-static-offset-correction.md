# `memory64-lowering` static-offset correction and Starshine follow-up

_Date:_ 2026-04-25  
_Status:_ filed back into living wiki pages  
_Sources:_ `docs/wiki/raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md`, `docs/wiki/raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md`, `docs/wiki/raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md`, `docs/wiki/binaryen/passes/memory64-lowering/`, `src/lib/types.mbt`, `src/validate/typecheck.mbt`, `src/validate/validate.mbt`, `src/binary/encode.mbt`

## Question

The 2026-04-25 `memory64-lowering` refresh made the dossier much more useful, but a health pass found one over-broad phrase repeated through the folder: it said high “constant address operands,” high active offsets, and high grow deltas become `unreachable` / immediate failure-sentinel shapes.

That phrasing collapsed three different Binaryen surfaces:

1. the stack operand expression;
2. the static `MemArg.offset` immediate;
3. active segment offset expressions and grow deltas.

A future Starshine port would get the lowering wrong if it treated all of those as the same kind of constant.

## Source-backed correction

The focused primary-source correction found:

- Dynamic address/index/count operands lower with `i32.wrap_i64(...)`; an operand expression being `i64.const` does not by itself make it a special trap case.
- Static memory access `offset=` immediates at or above `2^32` are the clear high-offset-to-`unreachable` family, including scalar, SIMD, atomic, and child-effect-preserving cases in the official memory lit file.
- Active data/element offsets are lowered through the expression-width repair path. I did not find source or lit evidence that high active offset expressions are special-cased to `unreachable` in current `Memory64Lowering.cpp`.
- `memory.grow` / `table.grow` remain failure-sentinel-aware, but the source-backed rule is result repair after running the lowered grow. I did not find evidence that high constant grow deltas are preclassified to the 64-bit failure sentinel before calling the lowered grow.
- Max-limit clamping and impossible-minimum uncertainty remain as previously recorded.

## Starshine local follow-up

The correction maps cleanly to existing local surfaces:

- `src/lib/types.mbt:162-164` defines `Limits::I32Limits` / `Limits::I64Limits`.
- `src/lib/types.mbt:1263-1267` maps limits to address value types.
- `src/lib/types.mbt:1366-1369` defines the mixed-width `min_addr_valtype(...)` helper used by copy rules.
- `src/validate/typecheck.mbt:1538-1577` already distinguishes static `MemArg.offset` validation from the dynamic address operand type.
- `src/validate/typecheck.mbt:2408-2426` derives `memory.size` and `memory.grow` operand/result types from the memory limits.
- `src/validate/typecheck.mbt:2468-2488` already models per-position `memory.copy` address widths.
- `src/validate/typecheck.mbt:587-635` still hard-codes table get/set/size/grow to `i32`, so `table64-lowering` still needs validation cleanup before implementation.
- `src/binary/encode.mbt:1208-1284` already encodes 32-bit and 64-bit memory/table limits, so a lowering pass must rewrite IR declarations before encoding rather than rely on the encoder to reinterpret them.

## Filed-back pages

- `docs/wiki/binaryen/passes/memory64-lowering/index.md`
- `docs/wiki/binaryen/passes/memory64-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/memory64-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/memory64-lowering/static-offsets-dynamic-operands-and-grow-repair.md`
- `docs/wiki/binaryen/passes/memory64-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/memory64-lowering/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Supersession

This note partially supersedes `docs/wiki/raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md` for the over-broad high-constant wording.
It preserves the earlier note's valid findings about declaration lowering, size result repair, grow failure-sentinel repair, max-limit clamping, mixed copy widths, local registry absence, and table64 validation prerequisites.

## Follow-ups

- If Starshine implements `memory64-lowering`, add separate reduced tests for dynamic `i64.const` address wrapping versus static high `offset=` replacement.
- Keep active data/element offset tests separate from memarg-offset tests; do not infer high-offset traps for active segments until a source or oracle run proves that behavior.
- Keep grow-delta tests focused on failure-sentinel result repair instead of a nonexistent constant-delta preclassification step.
