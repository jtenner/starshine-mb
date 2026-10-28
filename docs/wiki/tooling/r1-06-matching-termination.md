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
