# 0893 - code-pushing dependency-chain into-if sinking

Date: 2026-06-25

## Question

Can Starshine close `[CP-BINREP-001]` by matching the Binaryen v130 behavior that sinks a local-copy dependency chain into the sole consuming `if` arm while preserving source order?

## Answer

Yes. Starshine now handles the reduced Binaryen-positive family where consecutive SFA `local.set` roots form a dependency chain before a void `if`, and only one reachable arm consumes the moved locals. The new implementation inserts cloned sets at the beginning of the consuming arm in original order, replaces the original roots with `nop`, and refuses the movement when the `if` arm rewrites a source or moved local.

This is a narrow `optimizeIntoIf` widening, not a blanket arbitrary CFG-sinking implementation. It currently admits consecutive local-set chains only; broader non-adjacent dependency windows, two-arm consumption, and source-local rewrites remain boundaries until separately proven and tested.

## Source-backed shape

The replacement follow-up item came from a local Binaryen v130 probe under `.tmp/cp-gap-research/copy-chain-into-if.wat`: Binaryen moves

```wat
(local.set $x (local.get $p))
(local.set $y (local.get $x))
(if (local.get $cond)
  (then
    (drop (local.get $y))))
```

into the only using arm as `$x` before `$y`. Before this slice, Starshine left both sets before the `if`.

## Implementation

Changed `src/passes/code_pushing.mbt`:

- added `code_pushing_try_sink_dependency_chain_into_if_arm(...)` before the existing single-set into-if sinker;
- collects consecutive void `local.set` roots immediately before a void `if`;
- allows a direct `local.get` value to read an earlier moved local, preserving source order;
- requires SFA writes, no prefix/suffix uses outside the chain plus consuming arm, one consuming arm, no two-arm consumption, and no arm writes to the moved/source locals;
- inserts the cloned set chain at the start of the consuming arm and nops the originals.

Added focused tests in `src/passes/code_pushing_test.mbt`:

- positive: `code-pushing sinks local-copy dependency chain into the only using if arm`;
- negative/source-write boundary: `code-pushing keeps local-copy chain before if when the source local is rewritten in the arm`.

The positive test failed before implementation with `expected nop`, because the original sets remained at the root level.

## Validation

- Red test confirmation: `moon test --target native src/passes/code_pushing_test.mbt` failed before implementation in the new positive test (`expected nop`).
- Focused after implementation: `moon test --target native src/passes/code_pushing_test.mbt` passed `123/123` with pre-existing warnings.
- Package: `moon fmt && moon test src/passes && moon build --target native --release src/cmd` passed; `src/passes` passed `2832/2832`, native build completed with pre-existing warnings.
- `moon info` passed with pre-existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- Bounded dedicated compare smoke with the required code-pushing normalizer:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass code-pushing \
  --gen-valid-profile code-pushing-all \
  --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-code-pushing-all-1000-20260625-binrep001-local-cleanup-rerun2 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 200 \
  --keep-going-after-command-failures
```

Result: `1000/1000` compared, `466` normalized, `534` cleanup-normalized, raw mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache `1000 hits/0 misses`.

A first smoke accidentally used the absent `target/native/release/build/cmd/cmd.exe` path and produced `1000` Starshine command failures (`ENOENT`); it is tool-path noise only and is superseded by the rerun above with `_build/native/release/build/cmd/cmd.exe`.

## Remaining follow-up

`[CP-BINREP-001]` is implemented for the reduced Binaryen-positive dependency-chain into-if shape. `[O4Z-AUDIT-CP-BINREP]` remains active for trap-relaxed movement (`[CP-BINREP-002]`), `ignore-implicit-traps` lit coverage, intrinsic no-effects calls, GC/ref surfaces, broader ordering refinements, and low-priority multi-value branch/switch probes.
