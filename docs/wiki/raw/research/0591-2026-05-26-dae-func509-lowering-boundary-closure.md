# DAE006 Func509 lowering-boundary closure

Date: 2026-05-26

## Scope

This closes the current `[DAE]006` both-canonical frontier-advancement slice for the live `dae-optimizing` diagnostic frontier at `defined=509 abs=526`.

The decision follows the evidence chain from notes `0586` through `0590`: the visible canonical diff is semantic-safe dead-return/wrapper debris after the returned object, but the exact pre-encode DAE IR shape is a value-producing `block I64` whose result is consumed by the suffix. Removing that suffix in the DAE final hook made the debug artifact invalid.

## Decision

Treat the current Func509 first diff as a documented lowerer/diagnostic boundary for DAE, not as an active DAE final-hook matcher miss.

Do not broaden `dae_try_strip_outer_block_no_fallthrough_wrapper_suffix` to non-void first blocks. The focused safety regression from `0590` preserves this: the in-memory value-block suffix must remain until a later lowering/encoding stage has converted the value flow into truly post-return debris.

## Classification

Agent classification for the Func509 diff remains semantic-safe and size-losing:

- Starshine and Binaryen return the same object before the suffix region.
- The leftover Starshine canonical text is unreachable wrapper allocation/store/value debris after a return in the lowered representation.
- The pre-encode Starshine IR still needs the suffix to consume the value-block result; stripping it there invalidates functions `509` and `514`.

This is therefore not a DAE correctness blocker and not a safe DAE final-hook cleanup. Future cleanup, if desired, belongs to a later post-lowering or writer-side dead-code cleanup investigation, with its own validation target.

## Backlog effect

`[DAE]006` is closed by the documented non-normalizable pre-encode/lowered-shape boundary allowed by its exit criteria. The broader `dae-optimizing` pass remains partial: active work continues in `[DAE]002`, `[DAE]003`, `[DAE]004`, `[DAE]005`, `[DAE]009`, `[DAE]011`, `[DAE]012`, `[DAE]013`, and `[DAE]014`.

## Validation

This is a docs/backlog closure slice. It relies on the already-landed focused regressions and artifact evidence from `0587` through `0590`, especially:

- `moon test src/passes -f 'dae final return suffix cleanup preserves func509 in-memory block suffix'`
- the reverted unsafe probe where `.tmp/dae006-inmemory-suffix-20260526` failed validation after the broad first-block strip
- the latest successful replay `.tmp/dae006-outer-block-suffix2-20260526`, which still first-diffed at `defined=509 abs=526` with valid canonical outputs

No pass behavior changed in this closure slice. Closure validation in this run: `git diff --check`, `moon info` (existing unused DAE helper warnings only), `moon fmt`, and `moon test` passed.
