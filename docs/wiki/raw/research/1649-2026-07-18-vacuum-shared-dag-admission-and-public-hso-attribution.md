---
kind: research
status: current
last_reviewed: 2026-07-18
sources:
  - ../../binaryen/passes/vacuum/index.md
  - ../../binaryen/passes/vacuum/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/dae-optimizing/index.md
  - ./1648-2026-07-17-dce-batch-writeback-and-shrink-vacuum-attribution.md
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/vacuum/index.md
  - ../../binaryen/passes/vacuum/fuzzing.md
  - ../../binaryen/passes/vacuum/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/dae-optimizing/index.md
  - ./1645-2026-07-17-daeo-final-direct-closeout-matrix.md
  - ./1648-2026-07-17-dce-batch-writeback-and-shrink-vacuum-attribution.md
---

# Vacuum Shared-DAG Admission And Public HSO Attribution

## Question

After note `1648` advanced public shrink through DCE and remove-unused-brs, can the shared optimize/shrink vacuum blocker be accelerated without weakening vacuum's existing effect, trap, branch, structured-write, or writeback guards, and where do the public modes stop next?

## Scope and preserved contracts

This slice does not change vacuum's accepted transforms, public schedule order, DAEO behavior, plain-DAE behavior, or the locked DAEO slot.

The preserved safety contract is:

- calls, memory/table mutation, trapping conversions, and explicit control remain subject to the existing vacuum guards;
- root local-set/stack-effect and branchy structured-write safeguards remain unchanged;
- the raw precleaner and writeback validation remain unchanged;
- the direct DAEO closeout in note `1645` remains authoritative at raw `3203060`, canonical `3263950`, and accepted `+1494`, with both DAE normalizers;
- public optimize, shrink, and O4z must still reach exactly one DAEO execution after late HSO and immediately before `inlining-optimizing` before the release audit can close.

## Source attribution

The old timeout was initially visible after repeated `raw-vacuum-guarded-hazard` traces, but per-function tracing showed that those were only the last completed classifications before the real cliff.

Temporary attribution hooks identified absolute Func `151` as the first noncompleting HOT vacuum function. A focused extraction had:

- input size `76535` bytes;
- `179` HOT nodes and `5` root nodes;
- a pre-fix direct vacuum wall time of `38.845s`;
- `pass:vacuum` time of `38.142453s` in that replay;
- valid output of `76499` bytes, SHA-256 `571472796b3e3e4986ff9767ae52e668ae8137b0efa4f62820a7d51bf259d706`.

Stage timers then localized the pass-local cliff:

- root local-set/stack-effect guard: microseconds;
- branchy structured-write guard: microseconds;
- region cleanup: microseconds;
- `hot_pass_vacuum_remove_local_only_void_body(...)`: tens of seconds;
- specifically, `hot_pass_vacuum_region_contains_local_tee(...)`: `33649680us` in the final pre-fix stage trace.

The source bug was an unbounded recursive existence query over a HOT expression DAG. `hot_pass_vacuum_node_contains_local_tee(...)` revisited shared child nodes through every incoming path. Func `151` contains a small node set but enough shared structure before the first reachable `local.tee` to make the nominal admission scan exponential in path count.

This was not a raw-preclean transform cost, module validation cost, lift/lower cost, or vacuum writeback-validation cost.

## Red-first test

`src/passes/pass_manager_wbtest.mbt` now constructs a depth-24 shared binary-expression DAG as the first root and a later `local.tee` root.

The test first failed to compile because `hot_pass_vacuum_region_contains_local_tee_with_visit_count(...)` did not exist. The retained assertion requires:

- the query to find the later `local.tee`;
- only `26` unique nodes to be visited.

This locks the intended graph complexity rather than relying on a generous wall-clock threshold.

## Implementation

The local-tee admission query now allocates one `seen` bitmap sized to `hot_node_count(func)` and threads it through node and region recursion.

The memoized traversal:

- rejects invalid, deleted, out-of-range, or already visited nodes;
- marks each live node before descending;
- preserves the existing control-region recursion for blocks, loops, try/try_table bodies, and both if arms;
- preserves the existing ordinary-child traversal;
- still returns immediately when any `HotOp::LocalTee` is found.

For a shared DAG, revisiting a node that was already explored without finding a tee cannot produce new evidence. HOT expression graphs are required to be acyclic; treating an unexpected revisit as no new evidence is also fail-closed for this admission query.

No transform matcher, effect/trap rule, branch label rule, or writeback path changed.

## Final native artifact and direct evidence

After removing temporary attribution hooks and an unneeded exploratory dropped-expression memoization, the explicit final native binary is:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `9ec46fa0dc46b209478d71e2357ffeddbee180b05b1dcc8d92d2572a5f42c8c6`.

### Extracted Func 151

Final direct replay:

- wall `0.674s`;
- externally valid;
- output `76499` bytes;
- SHA-256 `571472796b3e3e4986ff9767ae52e668ae8137b0efa4f62820a7d51bf259d706`;
- byte-identical to the pre-fix output.

The fix therefore changes traversal cost, not output.

### Whole current artifact

Final direct `--vacuum --tracing pass` replay:

- wall `4.092s`;
- previous direct attempts timed out after about `600s` with no output;
- externally valid output;
- output `3115899` bytes;
- SHA-256 `03733b8d50713f3ee683a56b199b3a8b118594bdc366d43ac9b4cc31675235a9`;
- raw preclean completed across the module instead of stopping before the first HOT cliff.

An immediately preceding instrumented build produced the same bytes in `4.149s`; the cleaned final build removed only attribution hooks.

## Generated compare evidence and current parity warning

The current compare harness did not reproduce the historical all-green vacuum statement under today's generator/oracle state, so this slice does not silently overwrite those older claims.

With the fresh memoized build, bounded current runs reported:

- regular GenValid: `65/10000` compared before the failure cap, `65` mismatches, zero validation/generator/property/command failures;
- dedicated `vacuum` aggregate: `386/10000` compared before the failure cap, `336` normalized and `50` mismatches, zero validation/generator/property/command failures.

Inspected regular output shows an existing parity gap where Binaryen removes dropped constant-denominator integer div/rem expressions that Starshine retains. Inspected dedicated output shows an existing call-prefix wrapper parity gap. These are not classified as safe merely because both outputs validate.

To isolate this performance change from those current parity gaps, a detached pre-change `fe4e325ff` native binary was built explicitly:

- SHA-256 `d9c762b4f1252374a561d23e978c567220f340fcb4ec92fdefc51dce3f32e9fa`.

All observed mismatch inputs were replayed through the pre-change binary, the intermediate memoized binary, and the final binary:

- regular: `65/65` old/intermediate/final Starshine raw outputs byte-identical;
- dedicated: `50/50` old/intermediate/final Starshine raw outputs byte-identical;
- no replay command failure.

Agent classification: the current generated mismatches are pre-existing vacuum parity gaps exposed by the current corpus, not regressions or new families from the shared-DAG admission fix. The historical count-100000 green evidence remains historical evidence for its recorded generator/oracle state; a future behavior slice must reconcile the current corpus before claiming a fresh full green closeout.

## Public optimize and shrink reattribution

The vacuum owner is closed for the current artifact. Both public modes now pass vacuum and enter true HSO pass-local work.

Longer `600s` traces from the memoized implementation reached HSO Func `1513` without starting DAEO:

### Shrink

- wall `600.011s` timeout;
- completed HSO timings through Func `1511`: `463874107us` cumulative;
- leading completed HSO functions:
  - Func `1004`: `173.708958s`;
  - Func `445`: `136.036986s`;
  - Func `60`: `74.944325s`;
  - Func `637`: `16.559285s`;
  - Func `1138`: `16.459242s`;
  - Func `1503`: `9.554836s`;
- stopped after starting Func `1513`;
- DAEO start count `0`.

### Optimize

- wall `600.012s` timeout;
- completed HSO timings through Func `1511`: `439173162us` cumulative;
- leading completed HSO functions:
  - Func `1004`: `147.817336s`;
  - Func `445`: `136.122218s`;
  - Func `60`: `75.581484s`;
  - Func `637`: `16.655002s`;
  - Func `1138`: `16.374887s`;
  - Func `1503`: `9.841598s`;
- stopped after starting Func `1513`;
- DAEO start count `0`.

The final cleaned binary was then rerun for `180s` in each mode. Both runs passed vacuum, entered HSO, and were still inside the earliest large HSO owner, Func `60`; DAEO start count remained `0`. This confirms the final committed code has the same next-owner attribution.

O4z was already independently source-attributed to HSO in notes `1646` and `1648`; its O4z vacuum path is an intentional no-op, so this vacuum change does not alter that mode's earlier HSO ownership.

## Decision

The optimize/shrink vacuum blocker is closed without weakening safety or changing output. Public optimize, shrink, and O4z now share one pass owner: heap-store optimization.

The DAEO release audit remains incomplete because none of the three large public modes reaches the locked DAEO slot yet. Direct DAEO evidence remains closed and authoritative under note `1645`.

The next bounded slice should be HSO-specific and should begin with red-first source/performance attribution for the repeated Func `60`, Func `445`, Func `1004`, and Func `1513` families. It must preserve HSO effect/trap/control correctness, output validity, finite convergence, and the locked one-time DAEO schedule before rerunning all three public modes.
