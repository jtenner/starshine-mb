# 0808-2026-06-20 code-pushing segment inventory

## Question

Can Starshine add a non-mutating `code-pushing` analyzer/segment-window inventory slice that mirrors Binaryen `version_130` concepts before broadening movement?

This is a bounded `[O4Z-AUDIT-CP]` slice. It does **not** claim final pass closeout or new mutating Binaryen parity.

## Source basis

The immediately preceding `version_130` refresh found that official Binaryen `CodePushing.cpp` still centers on:

- `LocalAnalyzer` SFA classification,
- `Pusher` block-root segment scanning,
- `isPushable(...)`,
- `isPushPoint(...)`,
- `optimizeSegment(...)`, and
- `optimizeIntoIf(...)`.

It also found that `version_130` movement checks use `effects.orderedBefore(cumulativeEffects)` and that `code-pushing-atomics.wast` proves GC reads can move across shared atomic loads but not shared atomic stores.

## Change

Added non-mutating whitebox inventory helpers in `src/passes/code_pushing.mbt`:

- `code_pushing_push_point_kind(...)`
  - recognizes `if`, `br_table`/switch, conditional branch forms (`br_if`, `br_on_*`), and `drop` wrappers around those push points;
- `code_pushing_segment_window_diagnostic(...)`
  - classifies a candidate `local.set` root as a block-local segment-window candidate or an explicit rejection reason.

The diagnostic is intentionally conservative and returns strings for test-facing inventory only. It does not rewrite modules.

Implemented reasons / candidates:

- `candidate:if`
- `candidate:dropped-if`
- `candidate:conditional-branch`
- `reject:prefix-local-read`
- `reject:multiple-local-writes`
- `reject:ordered-before-barrier`
- plus support reasons for invalid/no-use/no-push-point/not-pushable/use-before-push-point cases.

## Tests

Added `src/passes/code_pushing_wbtest.mbt` to keep this as a whitebox inventory surface rather than a public API.

Focused tests cover:

1. ordinary `if` push-point discovery;
2. dropped value-`if` push-point discovery;
3. locally representable conditional-branch push-point discovery inside a block;
4. SFA rejection reasons for read-before-set and multiple-write cases;
5. a coarse ordered-before barrier when a `global.get` value would cross an intervening memory store before the push point.

## Red-first note

The tests were first added to `src/passes/code_pushing_test.mbt` and failed because `code_pushing_segment_window_diagnostic(...)` was unbound. They were then moved to `code_pushing_wbtest.mbt` so the helper can remain private to the package while the whitebox tests exercise it.

## Validation

Focused whitebox command:

```sh
moon test --target native src/passes/code_pushing_wbtest.mbt --filter '*segment inventory*'
```

Result: `5/5` passed, with pre-existing unused-function warnings in unrelated pass-manager whitebox surfaces.

## Boundaries

- This slice does not implement `optimizeSegment(...)` movement.
- It does not preserve ordered multi-set movement yet.
- It does not model Binaryen's full `EffectAnalyzer::orderedBefore(...)` semantics.
- It does not add atomics/GC/EH/trap-option mutation support.
- It does not schedule `code-pushing` in public presets.
- It is not final `[O4Z-AUDIT-CP]` closeout; the full repo-required pass signoff matrix was not run.

## Reopening / next evidence

Reopen this inventory if later movement slices find that the candidate labels or rejection order hide an unsafe family. The next useful slice is to consume this discovery layer in one smallest safe segment-movement family, preserving source-backed barriers and adding negative tests before mutation.
