# DAE006 Func509 in-memory block suffix boundary

Date: 2026-05-26

## Scope

Follow-up to `0589-2026-05-26-dae-func509-final-cleanup-input-reduction.md` for the live both-canonical `dae-optimizing` frontier at `defined=509 abs=526`.

This recovery run tested the exact in-memory shape implied by `.tmp/dae-print-func526.err`: a value-producing outer `block I64` whose body ends in `local.get $20; return`, followed at the function-body level by `local.set $2` and the 8-byte wrapper allocation/store/result suffix.

## New safety regression

Added a focused white-box regression in `src/passes/dead_argument_elimination_wbtest.mbt`:

- `dae final return suffix cleanup preserves func509 in-memory block suffix`

The fixture differs from the previous printed-shape reduction by placing the wrapper suffix *after* the value block, matching the raw `body_raw` nesting from the print probe rather than placing it inside the block body.

## Failed cleanup probe

A broadening probe changed `dae_try_strip_outer_block_no_fallthrough_wrapper_suffix` to accept any first `block` whose body ended without fallthrough, rather than only a first `block (Void)`. The focused test then passed, but the debug artifact became invalid on canonicalization:

```sh
rm -rf .tmp/dae006-inmemory-suffix-20260526 && \
  bun scripts/self-optimize-compare.ts \
    tests/node/dist/starshine-debug-wasi.wasm \
    --starshine-bin target/native/release/build/cmd/cmd.exe \
    --dae-optimizing \
    --canonicalize-binaryen-output \
    --out-dir .tmp/dae006-inmemory-suffix-20260526
```

Result: `wasm-opt --all-features --strip-debug` rejected the Starshine output. The validator reported function-body type mismatches in functions `509` and `514`; the broad strip left a value-producing `block (result i64)` in statement position after removing the suffix that consumed its result.

The broadening was reverted. The new regression now asserts the in-memory block-level suffix is preserved by the DAE final cleanup helper.

## Classification

`[DAE]006` remains open. This run rules out a simple DAE-side deletion of the function-level suffix after a value block: deleting it before lowering/encoding is not validation-safe for the observed in-memory form.

Agent classification remains: the post-encode Func509 compare difference is semantic-safe, size-losing dead-return/wrapper cleanup debris, but the safe cleanup point is not the pre-encode DAE final hook for this value-block suffix shape. The remaining boundary is now sharper:

1. the final DAE hook can safely strip suffixes inside terminal return regions and `block (Void)` wrapper families already covered by the helper;
2. the `block I64` function-level suffix is needed to consume the block result in the pre-encode IR and cannot be removed there without further restructuring;
3. the visible canonical dead suffix appears after later lowering/encoding turns the value-block result flow into `return` plus unreachable wrapper debris.

## Next step

Do not broaden `dae_try_strip_outer_block_no_fallthrough_wrapper_suffix` to non-void first blocks. To close Func509, either add a later cleanup hook after lowering/encoding where the suffix is truly post-return, or document the both-canonical Func509 frontier as a lowerer/diagnostic boundary rather than a DAE final-hook matcher miss.

Validation in this run:

- Failing/unsafe probe: broad first-block matcher made the artifact invalid in `.tmp/dae006-inmemory-suffix-20260526`.
- Passing safety regression: `moon test src/passes -f 'dae final return suffix cleanup preserves func509 in-memory block suffix'`.
