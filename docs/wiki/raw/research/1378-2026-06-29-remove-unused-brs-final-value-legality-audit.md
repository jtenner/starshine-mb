# Remove-unused-brs final value legality audit

Date: 2026-06-29

## Scope

This note audits the remaining Binaryen `RemoveUnusedBrs.cpp::FinalOptimizer` value-legality surfaces that were still easy to overgeneralize after note `1377`:

1. `selectify(...)` value-`if` to `select` guards.
2. `restructureIf(...)` dropped self-target `br_if` value guards.
3. `optimizeSetIf(...)` local.set/local.tee `if` arm extraction guards.

The slice did not add a new transform. It tightened focused boundary coverage and records the source-backed reopening criteria.

## Source evidence

Local oracle: `.tmp/binaryen-v130/RemoveUnusedBrs.cpp` (`wasm-opt version_130`).

### `selectify(...)`

Binaryen's `selectify(...)` only rewrites two-arm `if`s when:

- both arms can be emitted as `select` arms,
- the condition is not `Type::unreachable`,
- unconditional arm execution passes the shrink/cost model,
- both arms have no side effects, and
- the condition does not invalidate either arm's analysis.

The important Starshine boundary in this slice is the invalidation rule: if the condition writes a local that a selected arm reads, rewriting to `select` would run the arm before the condition and read the old local value. Starshine already preserved that shape; the new test locks it.

A valid polymorphic unreachable-condition source probe currently fails during HOT lift before RUB can preserve the shape:

```sh
moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt
```

with a temporary test for `(if (result i32) (unreachable) ...)` reported:

```text
lift: InvalidBodyState(hot lift stack underflow in if condition ... need 1, have 0)
```

That failure is classified here as a command/tooling boundary, not a RUB transform implementation. Reopen RUB-specific unreachable-condition selectify coverage after HOT lift supports unreachable-typed conditions without stack underflow.

### `restructureIf(...)`

Binaryen's dropped-value self-target prefix rewrite has two paths:

- side-effect-free branch values can become a result `if` only when the branch value can reorder with the condition;
- side-effectful branch values can become `select` only when the remaining block can reorder with the condition, has no side effects, and is select-compatible.

The source also has a TODO for handling additional target references through a larger refactor. Starshine's existing `block has another target use` boundary remains correct because upstream does not implement that broader refactoring in `version_130` either.

This slice adds a narrower invalidation boundary: a side-effectful branch value plus a `local.tee` condition that writes the local read by the fallthrough block must not become a `select`.

### `optimizeSetIf(...)`

Binaryen's `optimizeSetIfWithBrArm(...)` only extracts a branch arm when the arm is a simple branch. The source has a TODO for conditional branches because condition side effects require additional proof. Starshine's local-set branch-arm extraction is therefore correct to keep conditional `br_if` arms conservative.

This slice adds a boundary fixture where one `local.set (if ...)` arm is a value-carrying conditional `br_if` to an outer result block. The pass must preserve the conditional branch shape instead of extracting it as if it were a simple unconditional `br`.

## Tests added

`src/passes/remove_unused_brs_test.mbt`:

- `remove-unused-brs boundary keeps condition-invalidated value if out of selectify`
- `remove-unused-brs boundary keeps dropped value br_if prefix when condition invalidates rest`
- `remove-unused-brs boundary keeps conditional br_if set-if arms conservative`

These are intentional boundary/fail-closed tests. They are not green no-op tests for a required implementation gap; they lock source-backed legality checks where Binaryen either also guards the rewrite or leaves a TODO.

## Commands

- Temporary unreachable-condition public WAT boundary probe: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` failed before RUB with HOT lift `InvalidBodyState(hot lift stack underflow in if condition ... need 1, have 0)`. The temporary test was removed and the blocker is documented here instead.
- Focused after the three boundary tests: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `208/208`.
- Slice validation: `moon fmt && moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt && moon test src/passes` passed; focused RUB tests `208/208`, `moon test src/passes` `3614/3614`.
- `moon info` passed with 6 pre-existing warnings.
- `moon build --target native --release src/cmd` passed / no work to do.
- `git diff --check` passed with no output.
- Direct normalized freshness probe: `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass remove-unused-brs --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-final-value-legality-100-normalized --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `100/100`: `13` normalized matches, `87` compare-normalized matches, `0` mismatches, `0` validation/generator/property/command failures. Cache: Binaryen `100` hits / `0` misses; wasm-smith `0` hits / `0` misses. Command-failure classes: `{}`. Pass-local timing was not available from this lane.

## Classification and reopening criteria

- `selectify(...)` invalidation: implemented/protected by local reorder safety. Reopen only if Starshine broadens selectification to a new expression-equality/effect model.
- `selectify(...)` unreachable condition: command/tooling boundary in HOT lift, not implemented here. Reopen when polymorphic unreachable conditions can be lifted and RUB can prove preservation with a public-pipeline test.
- `restructureIf(...)` invalidating condition vs rest: protected boundary. Reopen with a Binaryen-equivalent `EffectAnalyzer::canReorder` proof if HOT grows more precise effect tracking.
- `restructureIf(...)` other target references: upstream `version_130` TODO/non-goal; reopen if upstream implements the larger refactor or Starshine intentionally chooses a source-backed stronger transform.
- `optimizeSetIf(...)` conditional `br_if` arm extraction: upstream `version_130` TODO/non-goal; reopen only with side-effect/order proof for the conditional branch condition and target payload.
