# DAE006 Func509 final-cleanup input reduction

Date: 2026-05-26

## Scope

Follow-up to `0588-2026-05-26-dae-func509-outer-block-reduction.md` for the live both-canonical `dae-optimizing` frontier at `defined=509 abs=526`.

The immediate recovery task was to reduce the exact instruction-list family suggested by `.tmp/dae-print-func526.err` and determine whether `dae_strip_root_return_suffix_instrs` can already strip the printed Func509 wrapper suffix.

## New regression

Added a focused white-box regression in `src/passes/dead_argument_elimination_wbtest.mbt`:

- `dae final return suffix cleanup strips func509 printed outer block shape`

The fixture preserves the important printed shape:

- outer `block I64`,
- leading inner `block (Void)` with `br Label 1` / `unreachable` control exits,
- the fallthrough result-object allocation and `local.get $20; return`,
- post-return `local.set $2`, wrapper allocation, `i64.store`, and wrapper `local.get` suffix.

## Result

The focused test passes with the existing helper. This is intentionally a reduction/proof test rather than a behavior change: the current recursive `dae_strip_root_return_suffix_instrs` already truncates the post-`return` suffix in the printed shape.

Validation command:

```sh
moon test src/passes -f 'dae final return suffix cleanup strips func509 printed outer block shape'
```

Result: `1` test passed. The run reported only the existing DAE/pass-manager unused-helper warnings.

## Classification

`[DAE]006` remains open. The printed `--print-func 526` text is no longer enough to explain the missed artifact cleanup, because the reduced printed shape is already covered by the final cleanup helper.

Agent classification remains: semantic-safe, size-losing dead-return/wrapper cleanup gap. The new evidence narrows the unresolved boundary to one of these possibilities:

1. the final DAE cleanup input differs from the printed post-pass text in a still-unreduced way;
2. the wrapper suffix is introduced or reintroduced after `dae_strip_module_root_return_suffix_once` runs;
3. the diagnostic print path shows a lowered/encoded form that is not the form available at the final DAE hook.

## Next step

Instrument the final cleanup hook itself, or add a diagnostic-only dump immediately before `dae_strip_module_root_return_suffix_once` inspects `defined=509`, then reduce that exact in-memory instruction sequence. Do not claim Func509 closure until a both-canonical replay moves beyond `defined=509 abs=526` or the later-boundary reintroduction is documented with direct evidence.
