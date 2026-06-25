# 0885 - code-pushing nested disjoint global-set call boundary

Date: 2026-06-25

## Question

After `0884` allowed trivial pure roots next to nested disjoint global writes, verify that the call-valued disjoint-write boundary from `0881` also holds when the disjoint write is inside a nested block.

## Probe

Probe file:

- `.tmp/cp-probes/global-get-across-nested-other-global-set-call-value-before-brif.wat`

Commands:

```sh
wasm-tools parse .tmp/cp-probes/global-get-across-nested-other-global-set-call-value-before-brif.wat -o /tmp/cp-nested-call.wasm
wasm-tools validate --features all /tmp/cp-nested-call.wasm
wasm-opt --all-features --code-pushing -S .tmp/cp-probes/global-get-across-nested-other-global-set-call-value-before-brif.wat -o -
```

## Finding

Local `wasm-opt version 130 (version_130)` validates the probe and keeps `global.get $g0; local.set` before the nested block containing `global.set $g1 (call $callee)`, even though `$g0 != $g1`. The call remains an ordered barrier inside the nested block.

## Starshine coverage

Added focused boundary coverage:

- `code-pushing boundary keeps global.get before nested disjoint global.set call value`

The test is intentionally unsupported/Binaryen-stationary and passed with the current narrowed nested disjoint-global gate. No pass implementation or GenValid profile changed.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*nested disjoint global.set call value*'` passed `1/1`.

## Follow-up

This boundary does not change behavior, but final `[O4Z-AUDIT-CP]` closeout remains blocked by the post-`0884` final matrix and remaining source-backed gap review. Broader nested-block contents and other ordered-before effects remain open unless probed and either implemented or documented as narrow boundaries.
