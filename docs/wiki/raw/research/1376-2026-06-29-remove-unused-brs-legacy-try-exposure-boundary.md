# 1376 - remove-unused-brs legacy try exposure boundary

Date: 2026-06-29

## Question

Continue `[O4Z-AUDIT-RUB-Q]` by auditing the remaining old-`try` / HOT catch-region body gap for `RemoveUnusedBrs.cpp::visitThrow(...)`. The dossier listed legacy old-`try` bodies as representation-blocked unless a local path exposes HOT `Try` nodes with catch regions.

## Source evidence

Local Binaryen oracle source is `.tmp/binaryen-v130/RemoveUnusedBrs.cpp` (`version_130`). The pass maintains a stack of catching expressions that may be either `Try` or `TryTable`:

- `scan(...)` pushes `TryTable` and legacy `Try` expressions onto `catchers` before scanning their children and pops them after child traversal.
- `visitThrow(...)` walks the catcher stack from inner to outer.
- For each catcher it first requires `dynCast<TryTable>()`; if the catcher is a legacy `Try`, Binaryen returns immediately with the comment that it does not handle mixtures of `Try` and `TryTable`.
- If the nearest relevant catcher is a `TryTable`, Binaryen rewrites exact `catch` throws to payload-carrying `br`, rewrites non-ref `catch_all` throws to dropped operands plus `br`, and returns unchanged for `catch_ref` / `catch_all_ref`.

So Binaryen's current source is not a broad old-EH optimizer. Its old-`try` behavior is limited to catcher-stack awareness and a mixed-control bailout.

## Local representation audit

Local Starshine has a `HotOp::Try` shape in `src/ir`, but the checked public WAT/lowered `Instruction` path does not carry legacy `try` as a lib instruction:

- `src/wast/parser.mbt` parses legacy text as `TryLegacy(...)`.
- `src/wast/lower_to_lib.mbt` lowers `TryLegacy(...)` to synthetic checks in a `block` followed by `unreachable`; `Rethrow(...)` in legacy context is similarly lowered to `unreachable` after validation.
- `src/lib/types.mbt` has `TryTable(...)`, `Throw`, and `ThrowRef`, but no legacy `Try` instruction variant.
- `src/ir/hot_lift.mbt` lifts `Instruction::TryTable(...)` to `HotOp::TryTable`; there is no corresponding public lib legacy `Try` instruction to lift to `HotOp::Try` from WAT.

Added explicit boundary coverage in `src/passes/remove_unused_brs_test.mbt`:

- `remove-unused-brs boundary: legacy try is lowered before caught-throw cleanup`

The test parses a legacy `try (do (throw $e)) (catch $e)` fixture through the public lift path and asserts that no live `HotOp::Try` or `HotOp::TryTable` survives, while a synthetic `Unreachable` does. This locks the current blocker as representation/candidate exposure, not hidden RUB behavior.

## Implementation decision

No RUB transform was implemented in this slice. The source and local representation together make the actionable boundary narrow:

- public legacy `try` is lowered away before `remove-unused-brs` can see it;
- Binaryen `version_130` itself returns on mixed legacy `Try` / `TryTable` catcher stacks;
- the already-implemented Starshine `try_table` caught-throw subset remains the local representable surface.

Reopen only if a binary decoder, lib instruction, or HOT builder path can produce a live `HotOp::Try` with catch-region bodies from real input. At that point add red-first tests for the exact exposed shape and decide whether RUB should preserve Binaryen's mixed-control bailout or implement a safe old-EH subset.

## Validation

Completed during the implementation loop:

- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` — passed `203/203` after adding the boundary test.

Combined thread validation after the medium-table and legacy-try slices:

- `moon fmt && moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt && moon test src/passes` — passed; focused RUB tests `203/203`, `moon test src/passes` `3609/3609`.
- `moon info` — passed with 6 pre-existing warnings.
- `moon build --target native --release src/cmd` — passed with 27 pre-existing pass-manager unused-function warnings.
- `git diff --check` — passed with no output.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass remove-unused-brs --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-medium-brtable-legacy-100-normalized --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` — compared `100/100`: `13` normalized, `87` cleanup-normalized, `0` mismatches, `0` validation/generator/property/command failures. Cache: Binaryen `100` hits / `0` misses; selected profile `binaryen-oracle-portable=100`.

Pass-local timing was not available from this compare lane.

## Status update

Documented boundary:

- old-`try` caught-throw cleanup remains a local representation/candidate-exposure blocker. The public pipeline lowers legacy `try` away before RUB, and Binaryen `version_130` bails out on mixed legacy `Try` / `TryTable` catcher stacks.

Still open / reopening criteria:

- Reopen if local `Instruction` / binary / WAT / HOT lift paths expose a live `HotOp::Try` from actual input, or if Binaryen changes `visitThrow(...)` to optimize legacy `Try` catch bodies directly instead of using the current mixed-control bailout.
