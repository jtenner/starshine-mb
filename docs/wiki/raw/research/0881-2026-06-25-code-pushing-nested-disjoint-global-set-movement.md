# 0881 - code-pushing nested disjoint global-set movement

Date: 2026-06-25

## Question

After `0879` admitted the direct `global.get G0` / `global.set G1` (`G0 != G1`) movement case, check whether Binaryen v130 also moves a global-reading SFA candidate across a nested block containing only a disjoint global write, and whether the disjoint exception must still stop when the disjoint write's value contains an ordered call.

## Probes

Probe files:

- `.tmp/cp-probes/global-get-across-nested-other-global-set-before-brif.wat`
- `.tmp/cp-probes/global-get-across-global-set-value-reads-same-global-before-brif.wat`
- `.tmp/cp-probes/global-get-across-other-global-set-call-value-before-brif.wat`

Commands:

```sh
wasm-tools parse .tmp/cp-probes/global-get-across-nested-other-global-set-before-brif.wat -o .tmp/cp-probes/global-get-across-nested-other-global-set-before-brif.wasm
wasm-tools validate --features all .tmp/cp-probes/global-get-across-nested-other-global-set-before-brif.wasm
wasm-opt --all-features .tmp/cp-probes/global-get-across-nested-other-global-set-before-brif.wat --code-pushing -S -o -

wasm-tools parse .tmp/cp-probes/global-get-across-global-set-value-reads-same-global-before-brif.wat -o .tmp/cp-probes/global-get-across-global-set-value-reads-same-global-before-brif.wasm
wasm-tools validate --features all .tmp/cp-probes/global-get-across-global-set-value-reads-same-global-before-brif.wasm
wasm-opt --all-features .tmp/cp-probes/global-get-across-global-set-value-reads-same-global-before-brif.wat --code-pushing -S -o -

wasm-tools parse .tmp/cp-probes/global-get-across-other-global-set-call-value-before-brif.wat -o .tmp/cp-probes/global-get-across-other-global-set-call-value-before-brif.wasm
wasm-tools validate --features all .tmp/cp-probes/global-get-across-other-global-set-call-value-before-brif.wasm
wasm-opt --all-features .tmp/cp-probes/global-get-across-other-global-set-call-value-before-brif.wat --code-pushing -S -o -
```

## Findings

Local `wasm-opt version 130 (version_130)` validates all three probes.

- Binaryen moves `global.get $g0; local.set` after a nested `(block (global.set $g1 ...))` and the later `br_if` when the nested block contains only the disjoint global write.
- Binaryen also moves across a direct disjoint `global.set $g1` whose value is a `global.get $g0`; reading the same global as part of the disjoint write's value is not itself a movement barrier in this reduced shape.
- Binaryen keeps the candidate before a direct disjoint `global.set $g1` whose value is `call $callee`; the call remains an ordered-before barrier even though the written global differs from the candidate's read global.

## Starshine change

Focused tests added:

- `code-pushing moves global.get value past nested other global.set before br_if push point`
- `code-pushing boundary keeps global.get value before disjoint global.set call value`

Both tests failed before implementation: the positive nested-block case stayed before the nested block, and the call-valued disjoint global-set boundary incorrectly moved after the call/global.set.

`src/passes/code_pushing.mbt` now keeps the disjoint global exception narrow:

- direct disjoint `GlobalSet` remains crossable only when its value subtree has no call, throw, memory-write, or table-write effects;
- a single nested `Block` root is crossable only when all body roots are direct disjoint `GlobalSet` roots with the same no-call/non-global-write value restriction;
- matching global writes, calls, EH barriers, memory writes, and table writes remain barriers.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*nested other global.set*'` passed `1/1` after failing before implementation.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*disjoint global.set call value*'` passed `1/1` after failing before implementation.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*other global.set*'` passed `2/2`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*global.get value before global.set*'` passed `1/1`.

## Follow-up

This is a behavior change after `0879`, so final `[O4Z-AUDIT-CP]` closeout still needs fresh post-`0881` regular 100000, explicit wasm-smith 10000, dedicated `code-pushing-all` 10000, and broad named `pass-fuzz-stress` 10000 lanes. Broader nested control, multi-root, and non-global state-read/write alias refinements remain open unless source-backed by future probes.
