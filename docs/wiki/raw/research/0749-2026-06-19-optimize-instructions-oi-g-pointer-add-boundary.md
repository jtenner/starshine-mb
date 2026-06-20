# Optimize-instructions OI-G pointer-add offset boundary slice

## Question

Should `[O4Z-AUDIT-OI-G]` claim or implement nonconstant pointer-add memory offset canonicalization, such as rewriting `(i32.load offset=8 (i32.add (local.get $p) (i32.const 4)))` into a different load/store offset spelling, as part of the `optimize-instructions` pass?

## Classification

This is the eighteenth `[O4Z-AUDIT-OI-G]` sub-slice. It is a source-backed boundary slice, not an implementation slice.

Binaryen `version_130` `optimize-instructions` owns the already-covered constant-address static-offset fold: constant pointer child plus nonzero static memarg offset can be folded into the constant address when the memory32 or memory64 address guard passes. A local oracle probe found that `wasm-opt --optimize-instructions` does **not** fold nonconstant pointer-add address forms for the tested scalar load/store shapes. Starshine therefore keeps those forms unchanged in the local OI pass and does not claim them as OI-owned load/store canonicalization.

This closes the specific OI-G question of whether `(local.get + const)` pointer-add forms have a direct `optimize-instructions` ownership proof today. It does not prevent a future `optimize-added-constants` or another source-backed pass from owning that rewrite, and it does not close broader OI-G stored-value, trap-mode, or raw-gate work.

Source anchors:

- Binaryen `version_130` source-refresh matrix records `optimizeMemoryAccess(...)` / load-store cleanup as `[O4Z-AUDIT-OI-G]` work, with prior OI-G slices implementing the source-backed constant-address static-offset subset.
- Prior constant-offset slices [`0743-2026-06-19-optimize-instructions-oi-g-const-memory-offset.md`](0743-2026-06-19-optimize-instructions-oi-g-const-memory-offset.md) and [`0744-2026-06-19-optimize-instructions-oi-g-memory64-const-offset.md`](0744-2026-06-19-optimize-instructions-oi-g-memory64-const-offset.md) explicitly left general pointer-add canonicalization open.
- Local Binaryen oracle probe `.tmp/oi-g-add-offset.wat` with `wasm-opt --optimize-instructions -S --print` kept `i32.add` plus `offset=8` for load/store pointer-add fixtures, including the commuted input after canonicalizing the add operands.

## Test and implementation changes

Changed `src/passes/optimize_instructions_test.mbt`:

- Added `optimize-instructions intentionally keeps nonconstant pointer-add memory offsets outside OI ownership`.
- The fixture runs the public `optimize-instructions` pipeline on memory32 scalar load/store functions whose addresses are `local.get $p; i32.const 4; i32.add` and whose memarg offsets are `8`.
- The assertions require the `i32.add` and `offset=U64(8)` to remain and require `offset=U64(12)` not to appear.

No implementation code changed. The existing `optimize_instructions_try_fold_const_memory_access_offset(...)` remains deliberately limited to constant address children plus static offsets.

## Evidence

Local Binaryen oracle probe before adding the Starshine boundary test:

```sh
cat > .tmp/oi-g-add-offset.wat <<'WAT'
(module
  (memory 1)
  (func $load (param $p i32) (result i32)
    local.get $p
    i32.const 4
    i32.add
    i32.load offset=8)
  (func $load_commute (param $p i32) (result i32)
    i32.const 4
    local.get $p
    i32.add
    i32.load offset=8)
  (func $store (param $p i32) (param $v i32)
    local.get $p
    i32.const 4
    i32.add
    local.get $v
    i32.store offset=8)
  (func $neg (param $p i32) (result i32)
    local.get $p
    i32.const -4
    i32.add
    i32.load offset=8))
WAT
wasm-opt .tmp/oi-g-add-offset.wat --optimize-instructions -S --print | grep -E 'func|local.get|i32.const|i32.add|i32.load|i32.store'
```

Observed result: the load/store pointer-add fixtures still printed `i32.add` under `i32.load offset=8` / `i32.store offset=8`; the commuted input was merely normalized to put `local.get` before the constant. The negative-constant form remained arithmetic as well. This is a **Binaryen no-change boundary**, not a Starshine divergence.

Focused Starshine boundary test:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nonconstant pointer-add memory offsets*'
```

Result: passed, `Total tests: 1, passed: 1, failed: 0.` This is a fail-closed boundary test, so there is no red-first behavior gap.

Focused memory coverage:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'
```

Result: passed, `Total tests: 23, passed: 23, failed: 0.`

Focused optimize-instructions coverage:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
```

Result: passed, `Total tests: 130, passed: 130, failed: 0.`

Broader Moon signoff:

```sh
moon fmt
moon test src/passes
moon build --target native --release src/cmd
moon info
```

Results:

- `moon fmt` passed.
- `moon test src/passes` passed, `Total tests: 2642, passed: 2642, failed: 0.`
- Native `src/cmd` release build passed with no work to do.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.

Direct compare lane:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-g-pointer-add-boundary-10000
bun scripts/pass-fuzz-compare.ts \
  --pass optimize-instructions \
  --count 10000 \
  --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-pointer-add-boundary-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result: completed to the default failure ceiling, requested `10000`, compared `54/10000`, normalized matches `27`, cleanup-normalized matches `0`, compare-normalized matches `0`, raw mismatches `27`, validation failures `0`, property failures `0`, generator failures `0`, command failures `1`, jobs `16`.

Cache: wasm-smith `28` hits / `0` misses; Binaryen `54` hits / `0` misses; Binaryen failures `1` hit / `0` misses.

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`).

Agent mismatch classification: the `27` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new pointer-add, memory-fill, memory-copy, or memory-offset semantic failures. Grepping final Binaryen/Starshine failure WATs found no `i32.load offset`, `i32.store offset`, `i64.load offset`, `i64.store offset`, `memory.fill`, or `memory.copy` occurrences.

## Remaining OI-G work

`[O4Z-AUDIT-OI-G]` remains active for:

- any other source-backed `optimizeStoredValue` shapes with clear local proof;
- further useful effect/trap negatives around memory lowering;
- any broader source-backed decision on whether a class of shapes should escape `load-call-optimize-instructions-noop`;
- zero-size bulk-memory cleanup only if local ignore-traps/TNH/IIT-equivalent support is added.

Nonconstant pointer-add offset folding should not be counted as an open `optimize-instructions` parity gap unless a future Binaryen source/oracle refresh shows OI ownership for that class.
