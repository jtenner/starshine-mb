# R1-06 — Equivalent nested type matching

Confirmed on unchanged master `3d1deec7cecf1caaf65b42799777ff52ef210245`.
The original four-struct test from review commit
`6422a44b155026bdbadfac86289c20958fdc21d3` was isolated without changing
its helpers or assertions in `src/validate/review_r1_06_wbtest.mbt`.
It fails: function body result type mismatch, expected reference 7, actual 3.
The original [fixture](../../../tests/repros/hunt-r1/equivalent-deep-structs.wat)
passes parse and validation with wasm-tools 1.262.0 (e22db44da),
`RAYON_NUM_THREADS=1`. This confirms R1-06 only, not adjacent findings.

Baseline command: `moon test src/validate/review_r1_06_wbtest.mbt --target js -j 1`.
Compilation succeeds; the wrapper cannot launch absent Node. Running the
compiled whitebox JS with Bun and the single-file/index JSON reports the
assertion failure (direct runner exit status alone is not evidence).
No full suite, fuzzing, benchmark, Binaryen comparison or performance claim.

## Repair and termination

[Exact matching](../../../src/validate/match.mbt) now uses its existing active
unordered index-pair stack without helper-depth fuel. The old bound counted
helper calls, not graph steps: a struct reference edge traverses subtype,
composite, field, storage, value, reference and heap helpers before the next
index comparison. Nine types gave only 25 fuel at heap entry.

Between index edges, descent is through finite stored shapes. An unresolved
index rejects; an active pair closes a recursive cycle. With a fixed finite
validation environment, only finitely many unordered index pairs can occur on
an active path. Push/pop remains scoped to the comparison, so a backedge cannot
skip later unequal fields. Existing shape, metadata, mutability, exactness,
nullability and recursive-group checks remain in force. Declared-supertype
search retains its independent fuel and cycle guard. R1-07's external-group
precheck is outside this repair and remains unchanged.

The original regression and bounded depths 1, 3, 4 and 8 exercise ordinary and
exact matching in both directions, including unequal leaves. Recursive controls
accept equal self cycles and reject an i32/i64 mismatch after a backedge.
Before repair, the original and boundary tests fail; the recursive control
passes. These are matching controls, not a claim of exhaustive recursive Wasm
validation or a stack-exhaustion proof for arbitrarily large inputs.

## Measurement handoff

No timing was run on the borrowed host. Measure `src/validate/match.mbt` exact
matching with the committed four-struct WAT and chain/recursive controls in
`src/validate/review_r1_06_wbtest.mbt`: shallow equal/unequal pairs, deeper equal
chains, late unequal leaves, and recursive equal/unequal backedges. Compare
against baseline `3d1deec7cecf1caaf65b42799777ff52ef210245`, recording that its
rejection of deeper valid chains does less work and is incorrect.

No new containers or shape copies are introduced. The existing pair array and
linear active-pair scans remain; deeper valid comparisons necessarily traverse
more shapes and can grow that array and the call stack beyond the old premature
cutoff. Existing recursive-group normalization copies are unchanged. Repeated
sibling pairs are recomputed rather than globally memoized. No time or memory
improvement, or performance neutrality, is claimed.

## Validation outcome

All Moon commands used `PATH=/data/home/.moon/bin:$PATH`; builds/tests used
`-j 1` and were serialized. `moon info` completed with no API diff;
`moon fmt` completed (unrelated formatter edits were removed).

- `moon test src/validate/match.mbt src/validate/match_wbtest.mbt src/validate/review_r1_06_wbtest.mbt --target js -j 1 --build-only`, followed by Bun execution of the emitted internal/whitebox runners: 51 internal and 8 whitebox tests pass, including all three R1-06 tests.
- `moon build -j 1`: full workspace default-target (wasm) build passes,
  0 errors; existing deprecation warnings remain.
- A broader package runner was stopped to keep work bounded after exposing
  the existing `validate.mbt` index 31 generator-coverage assertion at line
  8677 (`combined.descriptor_types > 0`). Rebuilding with baseline `match.mbt`
  and replaying only that test gives the identical failure. The final repair
  was restored and focused matching tests rebuilt. No full-package pass is
  claimed; the pre-existing generator-coverage failure is outside R1-06.

This supersedes the original review's open R1-06 status only. Public `.mbti`
interfaces are unchanged. Validation artifacts and temporary drivers are removed
after validation; committed fixture, tests and this record remain.
