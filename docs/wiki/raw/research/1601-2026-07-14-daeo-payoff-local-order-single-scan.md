# DAEO payoff local-order single-scan refinement

Date: 2026-07-14

## Scope

This output-preserving follow-up removes duplicate local-reference traversal from the shared local-order scan used by note `1600`. It also locks the exact number of payoff callees ordered by the DAEO lane. Plain DAE behavior, selected payoff chains, direct bytes, and public scheduling are unchanged.

## Bounded-work change

The type-stable local rewrite previously walked every selected function body twice before rewriting:

1. a full recursive pass checked that every local access was in range;
2. a second full recursive pass collected access counts and first-use ranks.

`RLScanState` now carries a fail-closed `valid` bit. The existing access-count traversal marks the scan invalid when it observes an out-of-range local and otherwise collects the same counts and first-use order. Both the type-stable and ordinary reorder-local paths therefore retain the invalid/stale-module guard without a separate full-tree preflight traversal.

The DAEO payoff trace now records `ordered_defs=<count>`. The focused one-chain regression requires `ordered_defs=1`; the current direct artifact reports `ordered_defs=2` for the two retained payoff callees. This prevents the lane from silently widening back to module-sized ordering.

## Red-first and focused validation

The existing behavioral payoff regression was first tightened to require `ordered_defs=1` and failed against the note-1600 trace, which ended at `local_order=type-stable`. After the bounded-work change:

- `reorder_locals_test.mbt`: `10/10`;
- focused payoff regression: green;
- output remains valid;
- all parent and child direct outputs are byte-identical at SHA-256 `612396c41a4146c0888c9c661a6ef63959889138759236e12398f9b0edcbbe30`.

## Controlled performance replay

Five alternating parent/child direct runs used the same artifact and helper tracing:

| implementation | pass-local runs (ms) | median | mean |
|---|---|---:|---:|
| note `1600` parent | `12590.121`, `12734.838`, `13044.095`, `12768.303`, `12633.006` | `12734.838` | `12754.073` |
| single-scan child | `12547.221`, `12751.231`, `12649.746`, `12802.402`, `12855.058` | `12751.231` | `12721.132` |

Whole-pass timing is statistically neutral at this scale: the child median is `+16.393ms` while the mean is `-32.941ms`. No pass-local speedup claim is made. The retained value is the source-visible removal of one complete recursive traversal per ordered function, identical output, fail-closed behavior, and exact bounded selection. The final iteration signoff must use a fresh rebuilt binary and confirm the total pass remains `<=2x` Binaryen.
