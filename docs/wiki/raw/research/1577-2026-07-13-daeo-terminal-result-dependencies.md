# DAEO terminal result dependencies

Date: 2026-07-13

## Scope

This slice corrects the result-propagation blocker identified after note `1576`. The materialized Func `164` body already ends in a direct call, but its callee, defined Func `175` / absolute Func `196`, still declared the same broad result even though its body ends in `struct.new $731`. Cleaning Func `164` first was therefore not sufficient evidence for an exact caller result: the terminal callee signature had to refine first.

## Red-first contract

The existing `4097`-definition broad nullable-default regression now routes defined Func `164` through a new parameter-free sink whose declared result is broad and whose body returns an exact leaf allocation. Before implementation, the low exact-result closure visited Func `164` first, observed only the sink's broad call result, and left the target and wrapper chain broad. The test failed on nullable broad Type `0` versus exact non-null Type `1`.

## Implementation

`dae_append_terminal_result_dependency_postorder(...)` builds a bounded, cycle-safe postorder for each productive low exact/default seed by following only the function body's terminal direct call. The result-only closure then:

1. refines the terminal callee result;
2. revisits the seed caller against the updated callee signature;
3. continues through the existing direct-caller queue.

The dependency walk is limited to depth `16`, visits each definition once, preserves the stable direct-call facts, and does not refine parameters. It does not broaden the closure to arbitrary side calls or invoke nested cleanup.

The public trace contract proves the order:

```text
primary_def=165 -> 164 -> 39 -> 38 -> 37
```

This is the Binaryen-shaped bottom-up requirement for declared call-result typing: a caller may refine from a terminal call only after the callee's function type exposes the narrower result.

## Validation and status

- red focused public regression: failed before implementation at the target result;
- focused public regression: `1/1`;
- DAE white-box tests: `206/206`;
- public DAEO tests: `310/310`;
- `moon fmt`: green;
- no intentional public API change.

The current artifact has not yet been replayed after this behavior change. The expected next check is whether Func `196`, Func `164`, and the `39 -> 38 -> 37` caller chain now emit `low-exact-result-worklist` traces. Func `164`'s repeated null/default `if` plus transient-local debris remains a separate size/shape cleanup owner even if result typing now propagates.
