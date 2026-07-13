# DAEO bounded structured-copy cleanup

Date: 2026-07-13

## Scope

This slice replaces the giant structured-function `simplify-locals` shortcut's recursively repeated general rewrite with a bounded staged cleanup for the `structured-pure-copy-call-tail` family attributed in note `1583`. It does not activate the broad DAEO dropped-result chain yet.

## Red-first fixture

The existing structured copy/call-tail performance fixture was reduced from `96` to `64` nested arms so it remains above the raw-path thresholds (`128` locals) without overflowing the wasm-gc test runtime stack. The expectation was changed first to require the new bounded raw path; the focused test failed because the old trace reason was still emitted.

The bounded path runs each required family at most through its existing small fixed-point cap:

1. unreachable dead local-set cleanup;
2. nested pure copy/call-tail sinking;
3. pure suffix local-set cleanup;
4. control-carrier local-get cleanup;
5. effectful suffix local-get cleanup.

Unlike the previous general recursive helper, it does not recursively re-run the whole stage bundle at every structured node.

## Focused evidence

- `moon test --package jtenner/starshine/passes --file perf_test.mbt --filter '*bounded cleanup*'` — `1/1` passed after implementation.
- The same cached focused command completed in `0.154s` shell elapsed time.
- `moon test --package jtenner/starshine/passes --file simplify_locals_test.mbt --filter '*structured pure-tail shortcut*'` — `1/1` passed.
- The fixture still removes all targeted `local.set` copies, preserves calls, emits `structured-pure-copy-call-tail-bounded`, and does not enter HOT lift/pass timers.

## Classification and next step

This is a performance-path implementation, not yet a DAEO artifact endpoint. The next slice must activate a generic payoff-ranked dropped-result wrapper/callee chain transaction, run this bounded cleanup only on the selected functions, and retain it only if the fresh artifact is valid, non-losing in raw/canonical/WAT size, and within `2x` Binaryen pass-local time. Plain DAE remains unchanged.
