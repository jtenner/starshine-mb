# DAEO exact-parameter chain closure

Date: 2026-07-13

## Scope

This slice closes the exact-reference/default-argument chain attributed in note `1579`: immutable Global `501` into defined Func `37`, exact second-parameter forwarding through Funcs `37`, `38`, and `41`, and removal of their third parameters without widening the general DAEO nested-cleanup lane or cleaning oversized Func `41`.

## Red-first coverage

The existing `4097`-definition broad-module regression now includes a reduced equivalent of the artifact chain:

1. a caller passes an exact leaf allocation and an immutable struct global to Func `37`;
2. Func `37` reads the immutable struct's default `i32` field, chooses a nullable value, stores it, and forwards it to Func `38`;
3. Func `38` forwards the nullable value to Func `41`;
4. Func `41` consumes the live first two arguments while its third argument becomes removable only after the preceding replay.

Before implementation, Func `37` still had three parameters. The focused test failed `3 != 2`. A reduced pass-manager white-box fixture also protects immutable first-field folding and proves an untouched sibling function stays byte-identical.

## Implementation and safety

The retained implementation is optimizing-only:

- direct GC argument evidence now accepts a `local.get` actual only when the caller's current `FunctionLocals` proves a compatible subtype;
- after the broad productive Func-164 seed, DAEO revisits only definitions `37`, `38`, and `41` for exact GC parameter refinement and only definition `37` for immutable-global literal materialization;
- the pass manager selects only Func `37` for the `precompute-propagate-prefix` replay;
- the selected adapter folds only an immutable non-null `struct.new` global's proven literal field and the exact `i32.const; local.tee; i32.const; eq/ne; if` sequence, preserving the tee write as `local.set` before choosing the proven arm;
- fresh current call facts then remove Func `38`'s uniform nullable argument and Func `41`'s now-unread third argument;
- selected `simplify-locals` and `vacuum` cleanup runs only on Funcs `37` and `38`; Func `41` is not blanket-cleaned;
- the general `large-touched-set` guard remains active and still skips the ordinary nested lane;
- plain `dead-argument-elimination` retains all three parameters and the original conditional carrier in the same broad regression.

The reduced white-box validates after rewriting and proves the unselected function is exactly unchanged.

## Fresh artifact evidence

Fresh native binary:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `48abcd5da8b92b45423915c0cd70740ff072cd420d21ab76e55ceabb0e5e5812` for the final measured behavior before this note.

Retained valid output:

- `.tmp/daeo-scheduled-current-artifact-20260713/starshine-direct-exact-param-chain.wasm`;
- SHA-256 `8c6db64956625844b99fb09bab299c89cca9ccc41f13fd77ab28649108bf12a1`;
- raw `3201367`, `+6` versus note `1578`'s retained `3201361`, and `+23946` versus Binaryen `3177421`;
- canonical wasm `3278451`, `-60` versus note `1578`'s `3278511`, and `+15995` versus Binaryen `3262456`;
- canonical WAT `179304975`, `-616` versus note `1578`'s `179305591`, and `+329692` versus Binaryen `178975283`;
- pass-local `5645.054ms` versus Binaryen `8083.49ms`, about `0.70x`;
- whole command `6360ms` by shell millisecond timing;
- valid under `wasm-tools validate --features all`.

Agent judgment: retain. The six-byte raw increase is outweighed by source-backed Binaryen signature/body convergence and measured canonical/WAT reductions; unlike rejected probe C, the endpoint removes the third parameters through Funcs `37`, `38`, and `41`, matches Binaryen's two-parameter exact-reference boundary, removes Func `37`'s default-field branch/local debris, and removes Func `38`'s trailing dropped constants. This is a measured/source-backed canonical and semantic-shape win, not a claim that the remaining whole-artifact gap is closed.

## Exact chain result

- Func `58` / defined `37`: two params, exact second `$731`, no locals, body `local.get 0; local.get 1; call 59`.
- Func `59` / defined `38`: two params, exact second `$731`, no third nullable argument, and the Binaryen-shaped live body without the trailing dropped constants.
- Func `62` / defined `41`: two params, exact second `$731`; no broad cleanup was run on its oversized body.
- Trace order: refine `37 -> 38 -> 41`, literal `37`, filtered prefix `37`, converge `38 -> 41`, selected cleanup `37,38`.

## Validation and status

- red public broad-module test: `3 != 2` before implementation;
- reduced filtered-prefix white-box: green and validates;
- focused public broad-module test: green;
- pass-manager white-box suite: `217/217` before the final selected cleanup adjustment;
- public DAEO suite: `310/310` before the final selected cleanup adjustment;
- DAE white-box suite: `207/207`;
- `moon test src/passes`: `5348/5348` before the final selected cleanup adjustment;
- `moon fmt`: green;
- native release build: green with existing warnings;
- no intentional public API change.

DAEO remains active. The retained behavior changed, so the four direct compare lanes are stale and must be rebuilt/rerun before closeout. The remaining current-artifact canonical gap is `15995` bytes; the next slice must attribute the next source-backed owner rather than widening the general large-touched-set lane.
