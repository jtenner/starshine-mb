# Local-subtyping call_ref refinalization

Date: 2026-07-04

## Question

Binaryen's `test/lit/passes/local-subtyping.wast` has two repeated-refinalization cases after the local-get chain and adjacent-local-get select/LUB shape:

- `multiple-iterations-refinalize-call-ref`
- `multiple-iterations-refinalize-call-ref-bottom`

The open LS question was whether Starshine can represent and validate those behaviors, or whether either remains a precise tooling boundary.

## Binaryen v130 probe

Local probe file: `.tmp/ls-call-ref-refinalization-probe.wat`.

Command:

```sh
wasm-opt --all-features --local-subtyping \
  .tmp/ls-call-ref-refinalization-probe.wat \
  -S -o .tmp/ls-call-ref-refinalization-probe.out.wat
```

Observed Binaryen v130 output:

- In `multiple-iterations-refinalize-call-ref`, `$f : (ref null $ret-any)` narrows to non-null exact `(ref $ret-i31)`, the `call_ref` immediate rewrites from `$ret-any` to `$ret-i31`, and `$x : anyref` narrows to `i31ref`.
- In `multiple-iterations-refinalize-call-ref-bottom`, `$f` narrows to `nullfuncref`, the now-unemittable bottom target call is replaced with a block that drops the target and ends in `unreachable`, and `$x : anyref` narrows to non-null `(ref none)`.

This matches the checked Binaryen lit expectations in `.tmp/ls-source-refresh-20260704/local-subtyping.wast`.

## Starshine implementation

`src/passes/local_subtyping.mbt` now extends the pre-HOT raw body refinalization repair pass beyond select/LUB annotations:

- Resolve a `call_ref`'s current type and an adjacent `local.get` target's narrowed local declaration.
- If the target local's heap type is a more specific function type, the old and new function params are identical, and the new results are subtypes of the old results, rewrite the `call_ref` type immediate to the target function type.
- If the adjacent target local has narrowed to nullable `nofunc` and the current `call_ref` has no params, replace the adjacent `local.get; call_ref` expression with a `(ref none)` result block that drops the target and ends in `unreachable`.
- Rely on the existing bounded module rewrite/re-lift loop so the first iteration narrows the function-reference local, a later iteration repairs the `call_ref`, and a final iteration narrows the dependent result local.

The bottom rewrite is intentionally narrow: it only handles zero-parameter adjacent-local-get targets. Broader parameter-preserving bottom-call rewrites would need effect/order-preserving argument consumption before being generalized.

## Tests

Added focused tests in `src/passes/local_subtyping_test.mbt`:

- `local-subtyping iterates after call_ref result refinalization`
  - Red first: `$f` narrowed but `$x` stayed broad `anyref`.
  - Green after implementation: `$f` becomes non-null exact `$ret-i31`, `call_ref` observes `$ret-i31`, and `$x` becomes `i31ref`.
- `local-subtyping replaces bottom call_ref refinalization with unreachable value`
  - Red first: `$f` narrowed to `nullfuncref` but `$x` stayed broad `anyref`.
  - Green after implementation: `$x` becomes `(ref none)`, the optimized body no longer contains `call_ref`, includes `unreachable`, and validates.

Focused validation after implementation:

```sh
moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt
```

Result: `69/69` passed.

## Residual classification

This slice removes the focused `call_ref` and bottom-call-ref repeated-refinalization probes from the LS residual list for the represented zero-param adjacent-local-get shapes.

It does **not** classify any remaining residual as a Starshine win. LS remains open for:

- EH `catch_ref` / `catch_all_ref` handler-flow and handler post-state probes/classification;
- the direct block-return nondefaultable-local validator/tooling boundary;
- the raw-unreachable-before-write nondefaultable-local validator/tooling boundary.

Reopen the `call_ref` family if a reduced Binaryen v130+ case needs non-adjacent target flow, parameterized bottom-call replacement, argument side-effect preservation, or a `call_ref` type-immediate rewrite where params are not exactly identical.
