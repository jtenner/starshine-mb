# DAEO null/default body cleanup and exact `struct.new` results

Date: 2026-07-13

## Scope

This slice completes the attributed defined Func `164` / absolute Func `185` body transformation after note `1577`: refine the terminal callee's `struct.new` result, fold the ten materialized null-test default branches, remove the transient local stores/reloads, and retain only the effectful default producers plus the final direct call.

## Red-first coverage

The `4097`-definition public regression now models the artifact shape directly:

- ten nullable-reference parameters;
- ten `ref.is_null` / result-typed `if` default paths;
- paired non-null and nullable transient locals;
- ten local reloads feeding a terminal direct call;
- a broad-result sink ending in `struct.new`.

Before implementation, result propagation stopped at the broad sink and the target retained `20` body locals. The focused test observed both failures red-first. A reduced white-box test also locks repeated `ref.null; ref.is_null; if` folding to the selected then/default producers.

## Implementation and safety

`dae_direct_gc_result_candidate_instr(...)` now treats `struct.new` like `struct.new_default`: both produce an exact non-null reference to their declared struct type. This lets the terminal-result dependency postorder refine defined Func `175` / absolute Func `196` before Func `164`.

`dae_fold_ref_null_is_null_if_instrs(...)` recognizes only the exact straight-line sequence:

```text
ref.null
ref.is_null
if (single value result) ... else ...
```

Because `ref.null` is pure and always null, `ref.is_null` is always true; the rewrite replaces the three instructions with the then body. It intentionally rejects type-index block signatures and does not inspect or rewrite arbitrary nested control.

The broad low-candidate schedule applies this fold only to definitions productively changed by the existing first-4096, minimum-eight-param, all-nullable-reference exact/default worklist. It then reuses `dae_try_inline_selected_terminal_call_local_sets_once(...)`, whose existing proof requires unique terminal argument locals, ordered producer segments, no interdependent temp references, and one terminal direct call. Plain `dead-argument-elimination` / `dae` does not invoke either optimizing-only schedule step.

## Fresh current-artifact replay

Fresh native binary:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `ac7673e41a94c0e31cf0a957cfb8471d801f3210c90f6861324ef5dc319f7841`.

Retained valid output:

- `.tmp/daeo-scheduled-current-artifact-20260713/starshine-direct-null-if-cleanup.wasm`;
- SHA-256 `21f933bc2f10891e9f40d70e5109adc6856b7d52377d9bdae397135f00fe7788`;
- raw `3201361`, `-199` versus note `1576`'s `3201560`, and `+23940` versus Binaryen `3177421`;
- canonical wasm `3278511`, `-240` versus regenerated prior Starshine `3278751`, and `+16055` versus Binaryen `3262456`;
- current-tool canonical WAT `179305591`, `-2832` versus regenerated prior Starshine `179308423`, and `+330308` versus Binaryen `178975283`;
- pass-local `3980.121ms` versus Binaryen `8083.49ms`, about `0.49x`;
- whole command `4698ms` by shell millisecond timing;
- valid under `wasm-tools validate --features all`.

The intermediate exact-`struct.new` result change without body cleanup emitted `3201603` raw bytes, `+43` versus the prior Starshine artifact. It was not independently signable. The retained combined behavior is smaller in raw, canonical, and canonical-WAT dimensions and remains within the pass-local target.

## Exact body and remaining chain

The current Func `185` body is now the same semantic shape as Binaryen's retained body:

```text
ref.func 186; struct.new 375
...
ref.func 195; struct.new 730
call 196
```

It has zero params, zero locals, and exact result `(ref exact $731)`. Func `196` also has exact `$731`; defined Func `39` / absolute Func `60` propagates the exact result. Trace order is:

```text
low-exact-result-worklist: 175 -> 164 -> 39
```

The next attributed gap is no longer Func `164`. Defined Funcs `37`, `38`, and `41` still retain a removable third parameter and a broad second `(ref $731)` parameter where Binaryen keeps two params and uses exact `$731`. Func `41` remains above the broad cleanup guard, so the follow-up must use current call facts for narrow parameter refinement/unread removal rather than blanket nested cleanup.

## Validation and status

- red high-definition local-count assertion: `20 != 0` before cleanup;
- reduced null-test/default producer white-box: green;
- DAE white-box tests: `207/207`;
- public DAEO tests: `310/310`;
- `moon test src/passes`: `5347/5347`;
- `moon fmt`: green;
- native release build: green with existing warnings;
- artifact validates;
- no intentional public API change.

DAEO remains active. The full four-lane matrix is stale after this behavior change and should not be rerun until the `37` / `38` / `41` parameter chain is closed or attributed.
