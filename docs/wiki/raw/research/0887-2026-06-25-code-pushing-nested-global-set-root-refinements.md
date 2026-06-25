# 0887 - code-pushing nested global-set root refinements

Date: 2026-06-25

## Question

After `0884` admitted only direct disjoint global writes plus trivial `nop` / dead `drop(const)` roots inside one crossed nested block, refine the source-backed boundary around additional nested roots: multiple direct disjoint writes, a live `drop(local.get)` separator, and a disjoint write hidden inside a sub-block.

## Probes

Probe files:

- `.tmp/cp-probes/global-get-across-nested-two-other-global-sets-before-brif-void.wat`
- `.tmp/cp-probes/global-get-across-nested-other-global-set-with-drop-local-before-brif.wat`
- `.tmp/cp-probes/global-get-across-nested-subblock-other-global-set-before-brif.wat`

Commands:

```sh
wasm-tools parse .tmp/cp-probes/global-get-across-nested-two-other-global-sets-before-brif-void.wat -o .tmp/cp-probes/global-get-across-nested-two-other-global-sets-before-brif-void.wasm
wasm-tools validate --features all .tmp/cp-probes/global-get-across-nested-two-other-global-sets-before-brif-void.wasm
wasm-opt --all-features --code-pushing -S .tmp/cp-probes/global-get-across-nested-two-other-global-sets-before-brif-void.wasm -o -

wasm-tools parse .tmp/cp-probes/global-get-across-nested-other-global-set-with-drop-local-before-brif.wat -o .tmp/cp-probes/global-get-across-nested-other-global-set-with-drop-local-before-brif.wasm
wasm-tools validate --features all .tmp/cp-probes/global-get-across-nested-other-global-set-with-drop-local-before-brif.wasm
wasm-opt --all-features --code-pushing -S .tmp/cp-probes/global-get-across-nested-other-global-set-with-drop-local-before-brif.wasm -o -

wasm-tools parse .tmp/cp-probes/global-get-across-nested-subblock-other-global-set-before-brif.wat -o .tmp/cp-probes/global-get-across-nested-subblock-other-global-set-before-brif.wasm
wasm-tools validate --features all .tmp/cp-probes/global-get-across-nested-subblock-other-global-set-before-brif.wasm
wasm-opt --all-features --code-pushing -S .tmp/cp-probes/global-get-across-nested-subblock-other-global-set-before-brif.wasm -o -
```

## Findings

Local `wasm-opt version 130 (version_130)` validates all three probes.

- Binaryen moves `global.get $g0; local.set` after a nested block containing two direct disjoint writes, `global.set $g1` and `global.set $g2`, and after the later `br_if`.
- Binaryen keeps the candidate before a nested disjoint-write block that also contains a live `drop (local.get $q)` separator.
- Binaryen keeps the candidate before a nested block whose only disjoint write is inside a sub-block instead of as a direct root of the crossed block.

## Starshine coverage

Focused tests added:

- `code-pushing moves global.get value past nested multiple other global.set roots`
- `code-pushing boundary keeps global.get before nested disjoint global.set with drop local separator`
- `code-pushing boundary keeps global.get before nested sub-block disjoint global.set`

All three pass with the current narrowed nested disjoint-global gate. No pass implementation or GenValid profile changed. The two boundary tests are explicitly intentionally unsupported/Binaryen-stationary: the accepted crossing window still requires direct disjoint writes and only trivial `nop` / dead `drop(const)` extra roots in the crossed nested block.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*multiple other global.set roots*'` passed `1/1`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*drop local separator*'` passed `1/1`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*nested sub-block disjoint global.set*'` passed `1/1`.

## Follow-up

This coverage does not change behavior and does not refresh the post-`0884` final matrix requirement. Final `[O4Z-AUDIT-CP]` closeout still needs post-`0884` regular 100000, explicit wasm-smith 10000, dedicated `code-pushing-all` 10000, and broad named `pass-fuzz-stress` 10000 lanes. Broader nested-block contents, nested sub-block recursion, and nontrivial separator roots remain boundaries unless future source probes prove movement.
