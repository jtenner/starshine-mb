---
kind: comparison
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../../../agent-todo.md
  - ../../../../../CHANGELOG.md
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/passes/perf_test.mbt
related:
  - ./index.md
  - ./wat-shapes.md
  - ./raw-lane-and-writeback.md
  - ./validation-and-signoff.md
  - ./performance-and-artifact-frontiers.md
---

# `simplify-locals` Parity Status

## Scope

- This page is the living comparison note for Starshine versus Binaryen on `simplify-locals`.
- It keeps durable status and frontier information.
- It is not the place for every temporary trace or reducer transcript.

## What Is Green Today

- The pass has broad reduced coverage in [`src/passes/simplify_locals_test.mbt`](../../../../../src/passes/simplify_locals_test.mbt).
- The raw lane and skip reasons are guarded in:
  - [`src/passes/pass_manager_wbtest.mbt`](../../../../../src/passes/pass_manager_wbtest.mbt)
  - [`src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt)
- Multiple 10k `gen-valid` pass-fuzz lanes are green for the kept exact-writeback and raw-skip cleanups.

## Retired Artifact Families

### `Func 216` Single-Use `if (result i32)` Call-Argument Sink

- Retired.
- The pass now sinks a single-use self-contained `if (result i32)` into a later call argument when the leading-evaluation-path rule permits it.

### `StringView.make_init_no_rc` Loop-Carried Initializer

- Retired as a wrong-code bug.
- The pass no longer lets outer pending values flow into loop headers.

### One-Armed `if` Then-Arm `nop` And Live Prefix Roots

- Retired.
- The pass now preserves Binaryen's then-arm `nop` sentinel and live prefix roots when lifting one-armed `if` writes.

### `moonbit.malloc` Sibling-Argument Reordering

- Retired as a wrong-code bug.
- Pending local read/write effects are now collected through `if` / `try` / `try_table` region bodies, and effectful replacements only inline on the leading evaluation path.

### `Func 41` Tee-Backed Alias Drift

- Retired in two steps:
  - preserve tee-backed copied locals for later direct call or branch uses
  - narrow that protection so same-arm non-call aliases still collapse back to the source local

### Old `Func 50` Validator-Skip Loop Temp Drift

- Retired.
- The validator raw-skip path now sinks single-use effectful temps across disjoint pure local-copy barriers.

## Durable Negative Findings

### Broad Lowered-`nop` Stripping

- Rejected.
- The pass-fuzz lane diverged immediately enough that this is now a documented anti-pattern, not just an abandoned experiment.

### Broad `if (result) -> select` Cleanup

- Rejected.
- Reduced Binaryen probes showed Binaryen does not perform the simple selectification families the repo could trivially emit.

## Current Frontier

- The old validator raw-skip local-copy frontier is no longer the meaningful first mismatch.
- The artifact notes now indicate two durable open buckets:
  - non-adjacent nested exact-expression cleanup around the old `Func 71` family
  - unchanged exact-path no-op parity where Starshine reports `changed=false` but Binaryen still prints a tighter control/value form, as seen in later functions such as `Func 386` and `Func 399`

## Why The Frontier Matters

- The current status means the next work is not "add more raw validator cleanup blindly."
- The repo already learned that:
  - several validator-heavy temp families are retired
  - broad lowered cleanup is unsafe
  - some remaining gaps are in unchanged exact-path output, not in obvious sink failures
- So the next parity work has to distinguish:
  - true missed transform
  - exact-path pretty-print or canonicalization drift
  - performance-only hotspot family

## Performance Status

- The raw-skip heuristics removed several artifact-scale no-op families from the hotspot list.
- Important retired performance families include:
  - huge straight-line tee-heavy builders
  - dense structured call-heavy helpers
  - several validator and decode-shaped no-op walkers
- The remaining hotspot cluster is now smaller and more internal, with examples such as `Func 473`, `308`, and `1488` recorded in the backlog.

## Current Project Rule

- Treat Binaryen-equal no-op families as performance work, not semantic wins.
- Treat a parity difference as a bug only when:
  - the family is reduced or traced to a stable shape
  - the difference is not merely explained by a documented raw stable-boundary rule
  - the fix stays green on the pass-fuzz lane

## Maintenance Rule

- Update this page when one of these changes:
  - a named artifact family is retired
  - a previously-accepted cleanup is rejected
  - the current frontier moves to a different category
  - a performance-only hotspot family is removed from the active list
