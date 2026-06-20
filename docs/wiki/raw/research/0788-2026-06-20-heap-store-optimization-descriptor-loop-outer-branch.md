---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0787-2026-06-20-heap-store-optimization-descriptor-loop.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO descriptor loop outer-branch parity

Question: after the branchless descriptor-loop fix, does Binaryen also fold through a descriptor loop when a branch inside the loop targets an outer descriptor block rather than the loop itself?

## Binaryen probe

Fixture: `.tmp/hso-probe-desc-loop-outer-branch-call.wat`.

Shape:

- `struct.new_desc $pair` uses a descriptor operand that is a result `block` around a `loop`.
- The loop body evaluates `(global.get $descg)` and branches to the outer descriptor block.
- The later `struct.set` writes field `0` with `(call $helper (i32.const 1))`.

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-probe-desc-loop-outer-branch-call.wat \
  -o .tmp/hso-probe-desc-loop-outer-branch-call.opt.wat

grep -n "struct.set\|struct.new_desc\|call\|loop\|br\|global.get" \
  .tmp/hso-probe-desc-loop-outer-branch-call.opt.wat
```

Observed behavior:

- Binaryen folded the moved helper call into `struct.new_desc`.
- Binaryen removed the later `struct.set`.
- The descriptor expression still contains the loop, the branch to the outer block, and the descriptor `global.get`.

This narrows the descriptor-loop barrier rule: a branch under a descriptor loop is not automatically a loop-control barrier. A branch to the active loop label is a barrier, while a branch to an enclosing result block can still be safe for this HSO movement family.

## Starshine gap and fix

Before this slice, Starshine's descriptor-loop control-barrier predicate treated any branch under a loop as a barrier. That matched the self-branching loop negative from `0787`, but overblocked Binaryen's outer-branch positive.

Added red-first focused test:

- `heap-store-optimization moves call before descriptor loop branch to outer block`

Initial focused run after adding the test failed: HSO tests passed `64/65`; the new case retained `struct.set`.

Implementation change:

- `hso_desc_region_has_loop_control_barrier(...)` and `hso_desc_node_has_loop_control_barrier(...)` now carry an `active_loop_id` label id from the active `Loop` node.
- Branch-like HOT nodes (`Br`, `BrIf`, `BrOnNull`, `BrOnNonNull`, `BrOnCast`, `BrOnCastFail`) are descriptor loop-control barriers only when their target label equals the active loop label.
- `BrTable` stays conservative while inside any active loop.
- Terminators remain barriers.
- Nested loops install their own active loop label; blocks, ifs, try, and try-table regions recurse with the current active loop label.

The existing self-branching descriptor-loop negative still protects the Binaryen behavior from `0787`.

## Validation

Commands/results before commit:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon fmt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Results:

- Red-first focused run after adding only the new test: `64/65` passed; the new case failed because Starshine retained `struct.set`.
- Final focused HSO tests: `65/65` passed.
- `moon fmt`: passed.

Post-handoff follow-up signoff:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-loop-outer-branch-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Results:

- Native `src/cmd` build: passed.
- Direct compare: compared `10000/10000`, normalized matches `10000`, compare-normalized matches `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`.
- Cache counters: wasm-smith `0` hits / `0` misses; Binaryen `5002` hits / `4998` misses; Binaryen failures `0` hits / `0` misses.

## Remaining risk

This slice closes only the descriptor-loop outer-branch behavior where the branch target is an enclosing descriptor block. Broader arbitrary descriptor expressions remain open, including descriptor `ref.cast` / `ref.cast_desc_eq`, `br_on_cast` / `br_on_cast_fail`, trapping descriptor-producing expressions, table/final-element swap combinations, remaining later-field directional barriers, target/control hazards, and O4z slot/neighborhood evidence.

Recommended follow-up: build native `src/cmd` and run a 10000-case direct `heap-store-optimization` compare for this latest behavior-changing slice unless explicitly skipped again.
