---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1108-2026-06-25-heap-store-optimization-closeout-residual-map.md
  - ./1102-2026-06-25-heap-store-optimization-exact-ref-cast-blocker-audit.md
  - ./1048-2026-06-25-heap-store-optimization-exact-ref-cast-recheck.md
  - ./0869-2026-06-20-heap-store-optimization-exact-descriptor-cast-surface.md
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO exact descriptor `ref.cast` closure

## Question

Can the exact descriptor `ref.cast` blocker from `0869`, `1048`, and `1102` now run through Starshine HSO, and does it preserve the later call-valued `struct.set` like Binaryen `version_130`?

## Answer

Yes. Starshine now has a distinct exact `ref.cast` instruction surface, decodes and re-encodes the exact heap immediate (`0x62 <typeidx>`), lowers/lifts it through HOT as a trapping `RefCast`, validates it as an exact result type, and runs the exact Binaryen probe through `--heap-store-optimization`.

The exact probe now preserves:

- the descriptor `ref.cast (ref (exact $desc))` trap/order point;
- the `struct.new_desc $pair`; and
- the later helper-call-valued `struct.set $pair 0`.

That matches the Binaryen behavior recorded in `0869` / `1048` and closes the local-surface blocker centralised in `1102`. This is not a new HSO fold; it is a negative safety fixture proving HSO does not fold across the exact descriptor-cast trap/order point.

## Implementation

Changed executable surface:

- `src/lib/types.mbt` adds `Instruction::RefCastExact` and `Instruction::ref_cast_exact(...)`.
- `src/binary/decode.mbt` decodes `ref.cast` / `ref.cast_null` immediates with the exact heap prefix into `RefCastExact` instead of failing by treating `0x62` as a signed type index.
- `src/binary/encode.mbt` re-emits `RefCastExact` as the same `ref.cast` / `ref.cast_null` opcode plus `0x62 <typeidx>`.
- `src/lib/show.mbt`, `src/validate/typecheck.mbt`, `src/validate/validate.mbt`, `src/validate/gen_valid.mbt`, and `src/ir/hot_lift.mbt` preserve the exact form through printing, validation, feature facts, and HOT lifting.
- `src/binary/tests.mbt` adds an exact instruction roundtrip for bytes `fb 16 62 01`.
- `src/passes/heap_store_optimization_test.mbt` adds the focused HSO negative `heap-store-optimization keeps struct.set across exact descriptor ref.cast and moved call`.

## Evidence

TDD red run before the instruction surface existed:

```sh
moon test --target native src/binary/tests.mbt --filter '*exact ref.cast*'
# failed: Type @jtenner/starshine/lib.Instruction has no method ref_cast_exact
```

Focused green runs after implementation:

```sh
moon test --target native src/binary/tests.mbt --filter '*exact ref.cast*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/heap_store_optimization_test.mbt --filter '*exact descriptor ref.cast*'
# Total tests: 1, passed: 1, failed: 0.
```

Native CLI rebuild and exact probe replay:

```sh
moon build --target-dir target --target native --release src/cmd

target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  --dump .tmp/hso-probe-desc-ref-cast-call.star-current-after-refcast.wat \
  .tmp/hso-probe-desc-ref-cast-call.current.wasm \
  -o .tmp/hso-probe-desc-ref-cast-call.star-current-after-refcast.wasm
```

The dumped output contains the expected safety boundary:

```text
ref.cast (ref (exact $desc))
struct.new_desc $pair
call $helper
struct.set $pair 0
```

## Updated residual classification

Exact descriptor `ref.cast` is no longer a local decode/instruction-surface blocker for HSO-D/E/F/G/H. It is now source-backed focused negative coverage.

HSO remains incomplete for other reasons: HSO-I allocation-heavy performance still needs disposition, and HSO-J still needs the final focused/full validation, compare matrix, O4z slot/neighborhood replay, docs/wiki/log updates, and backlog cleanup. The generic residual cautions for future descriptor operators, arbitrary unlisted descriptor/control expressions, and future Binaryen swap-legality drift remain reopening criteria, not hidden approved drift.
