# 0884 - code-pushing nested disjoint global-set pure-root window

Date: 2026-06-25

## Question

After `0881` admitted one nested block containing only disjoint global writes, check whether Binaryen v130 also crosses a nested block that contains trivial pure roots next to the disjoint write, and keep the matching-global boundary explicit for mixed nested blocks.

## Probes

Probe files:

- `.tmp/cp-probes/global-get-across-nested-other-global-set-with-nop-before-brif.wat`
- `.tmp/cp-probes/global-get-across-nested-other-global-set-with-drop-const-before-brif.wat`
- `.tmp/cp-probes/global-get-across-nested-matching-and-other-global-set-before-brif.wat`

Commands:

```sh
wasm-tools parse .tmp/cp-probes/global-get-across-nested-other-global-set-with-nop-before-brif.wat -o /tmp/cp-nop.wasm
wasm-tools validate --features all /tmp/cp-nop.wasm
wasm-opt --all-features --code-pushing -S .tmp/cp-probes/global-get-across-nested-other-global-set-with-nop-before-brif.wat -o -

wasm-tools parse .tmp/cp-probes/global-get-across-nested-other-global-set-with-drop-const-before-brif.wat -o /tmp/cp-drop.wasm
wasm-tools validate --features all /tmp/cp-drop.wasm
wasm-opt --all-features --code-pushing -S .tmp/cp-probes/global-get-across-nested-other-global-set-with-drop-const-before-brif.wat -o -

wasm-tools parse .tmp/cp-probes/global-get-across-nested-matching-and-other-global-set-before-brif.wat -o /tmp/cp-match.wasm
wasm-tools validate --features all /tmp/cp-match.wasm
wasm-opt --all-features --code-pushing -S .tmp/cp-probes/global-get-across-nested-matching-and-other-global-set-before-brif.wat -o -
```

## Findings

Local `wasm-opt version 130 (version_130)` validates all three probes.

- Binaryen moves `global.get $g0; local.set` after a nested block containing a trivial `nop` and disjoint `global.set $g1`, and after the later `br_if`.
- Binaryen also moves across the nested disjoint write when the block contains a dead `drop (i32.const 9)` root before the disjoint write.
- Binaryen keeps the candidate before a nested block that writes both disjoint `g1` and matching `g0` globals.

## Starshine change

Focused tests added:

- `code-pushing moves global.get value past nested other global.set with pure roots before br_if push point`
- `code-pushing boundary keeps global.get before nested block with matching global.set`

The positive pure-root test failed before implementation with Starshine leaving `global.get G0; local.set` before the nested block. The matching-global boundary already stayed stationary.

`src/passes/code_pushing.mbt` now keeps the nested disjoint-global exception narrow but allows `nop` and dead `drop(const)` roots inside the crossed block alongside direct disjoint global writes. Direct matching global writes, call-valued writes, EH, memory writes, and table writes remain barriers.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*pure roots*'` failed before implementation, then passed `1/1`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*matching global.set*'` passed `1/1`.

## Follow-up

This is another behavior change after `0881`, so final `[O4Z-AUDIT-CP]` closeout needs post-`0884` regular 100000, explicit wasm-smith 10000, dedicated `code-pushing-all` 10000, and broad named `pass-fuzz-stress` 10000 lanes. Broader nested-block contents remain open unless source-backed by future probes.
