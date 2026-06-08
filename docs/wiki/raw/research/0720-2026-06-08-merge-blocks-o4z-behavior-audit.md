# Merge Blocks O4z Behavior Audit

_Date:_ 2026-06-08
_Status:_ completed behavior-parity audit; final direct compare is zero-mismatch with the repo's unreachable/local/drop debris normalizers, and raw unnormalized drift is classified as non-semantic debris.

## Scope

Audit Starshine `merge-blocks` against Binaryen behavior parity, not byte-for-byte output parity. The target is Binaryen's current source-backed pass surface:

- child block splicing into parent lists;
- loop-tail merging where safe;
- motion of safe block prefixes out of value contexts such as `drop(block ...)`, `if` conditions, `throw` operands, and other expression operands;
- branch/label safety and refinalization/validation after mutation.

Primary local references read during this audit:

- `docs/wiki/binaryen/passes/merge-blocks/index.md`
- `docs/wiki/binaryen/passes/merge-blocks/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/merge-blocks/wat-shapes.md`
- `docs/wiki/binaryen/passes/merge-blocks/starshine-hot-ir-strategy.md`
- `src/passes/merge_blocks.mbt`
- `src/passes/merge_blocks_test.mbt`

## Finding before this slice

Starshine already handled the active HOT region-root subset:

- flatten branch-free block roots;
- preserve live-label blocks;
- preserve typed carrier lowering stability;
- preserve loop wrapper blocks after the 2026-06-05 json-as string-serialization regression;
- repair dead values before `unreachable` suffixes.

The remaining broad Binaryen behavior gap was expression-child block motion. Binaryen does not restrict itself to region-root blocks: it also moves safe prefixes out of block-valued operands, notably `drop(block ...)`, `if` conditions, and `throw` operands. The previous Starshine implementation did not inspect or rewrite non-root child blocks, so it missed these patterns even when the block was label-dead and branch-free.

## Change made

`src/passes/merge_blocks.mbt` now adds a conservative expression-child block lifting path:

- accepts only live `Block` children;
- rejects used labels;
- rejects typed block params;
- rejects bodies containing loops, preserving the json-as loop-wrapper safety guard;
- requires at least one prefix root plus a single-result tail;
- requires the child block's single result to match the tail result family;
- moves prefix roots immediately before the parent root and replaces the child with the tail;
- uses effect masks to avoid moving an effectful prefix before an effectful earlier operand;
- applies to `drop`, `if` conditions, `throw`, and other non-control expression roots through the same conservative helper.

This intentionally targets Binaryen-observable behavior parity without requiring identical AST output.

## Focused fixtures added

`src/passes/merge_blocks_test.mbt` now covers the new Binaryen surfaces:

- `merge-blocks moves block prefixes out of if conditions like Binaryen`
- `merge-blocks moves block prefixes out of drop operands like Binaryen`
- `merge-blocks moves block prefixes out of store operands without reordering effects`
- `merge-blocks moves pure block prefixes out of throw operands like Binaryen`

These tests are intended to fail on the pre-change implementation because the block-valued operand remains nested.

## Command evidence

- `moon info` still reproduces the known Moon tool panic: `index out of bounds: the len is 36 but the index is 8329485`.
- `moon fmt` completed.
- `moon test src/passes` passed `2042/2042`.
- `moon test` passed `5234/5234`.
- `moon build --target native --release src/cmd` completed; existing pass-manager unused-function warnings remain.
- Direct 1000-case compare:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass merge-blocks --out-dir .tmp/pass-fuzz-merge-blocks-o4z-audit-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --keep-going-after-command-failures`
  - Result: `998/1000` compared, `998` normalized matches, `0` mismatches, `2` Binaryen/tool command failures.
- Final unnormalized 100000-case compare:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass merge-blocks --out-dir .tmp/pass-fuzz-merge-blocks-o4z-audit-final-100000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: `99751/100000` compared, `99748` normalized matches, `3` raw mismatches, `249` Binaryen/tool command failures.
- Final behavior-normalized 100000-case compare:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass merge-blocks --normalize unreachable-control-debris --normalize local-cleanup-debris --normalize drop-consts --out-dir .tmp/pass-fuzz-merge-blocks-o4z-audit-final-100000-norm3 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: `99751/100000` compared, `99748` normalized matches, `3` cleanup-normalized matches, `0` mismatches, `249` Binaryen/tool command failures.
  - Command-failure classes: `219` `binaryen-rec-group-zero`, `12` `binaryen-bad-section-size`, `11` `binaryen-command-failed`, `6` `binaryen-table-index-out-of-range`, `1` `binaryen-invalid-tag-index`.

## Raw mismatch classification

The three unnormalized mismatches are behavior-equivalent debris, not `merge-blocks` semantic differences:

1. `case-023083-wasm-smith`: Starshine had an extra `drop(unreachable)` before a hard `unreachable`; the `unreachable-control-debris` normalizer accounts for it.
2. `case-046375-wasm-smith`: Binaryen retained a `nop` before a hard `unreachable` where Starshine omitted it; this is `local-cleanup-debris` / no-op representation drift.
3. `case-082547-wasm-smith`: Binaryen retained a pure `drop(f32.ceil(const))` before a loop-body `unreachable` where Starshine omitted it; this is pure dropped-value debris and is covered by the `drop-consts` / local cleanup normalizers.

## Remaining audit risk

No broad Binaryen behavior family remains open for v0.1.0 after the source/lit checklist and final normalized compare. Reopen if a future no-normalizer lane shows non-debris mismatches, if Binaryen changes `MergeBlocks.cpp` beyond the closed surfaces, or if O4z slot/neighborhood replay finds a runtime or validation regression.
