---
kind: research
status: current
last_reviewed: 2026-05-07
sources:
  - ../../binaryen/passes/remove-unused-brs/parity.md
  - ../../../../tests/node/dist/starshine-debug-wasi.wasm
  - ../../../../scripts/pass-fuzz-compare.ts
  - ../../../../scripts/self-optimize-compare.ts
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/remove-unused-brs/index.md
  - ../../binaryen/passes/remove-unused-brs/parity.md
  - ./0505-2026-05-06-remove-unused-brs-current-main-recheck.md
---

# `remove-unused-brs` mixed rerun and local-normalization classification

## Question

Can the dedicated `[RUB]002` follow-up leave `agent-todo.md` after a fresh current-head direct artifact replay and a larger mixed-generator direct-pass rerun, and if not, what direct mismatch family actually remains?

## Evidence

Commands run on 2026-05-07:

- `moon info`
- `moon test src/passes`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --remove-unused-brs`
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --count 10000 --seed 0x5eed --max-failures 20 --out-dir .tmp/pass-fuzz-remove-unused-brs-20260507 --keep-going-after-command-failures`

Results from the debug-artifact replay:

- `Canonical wasm equal: no`
- `Normalized WAT equal: yes`
- `Canonical function compare equal: yes`
- `Starshine runtime (ms): 2481.977`
- `Binaryen runtime (ms): 711.557`
- `Starshine pass runtime (ms): 233.201`
- `Binaryen pass runtime (ms): 265.666`
- `Starshine pass skipped raw: yes`

So the direct artifact lane remains representation-stable and canonically green on the function-comparison surfaces already used elsewhere in the RUB dossier, even though raw emitted wasm still differs.

Results from the mixed-generator direct-pass rerun in `.tmp/pass-fuzz-remove-unused-brs-20260507`:

- compared cases: `163 / 10000`
- normalized matches: `143`
- mismatches: `20`
- validation failures: `0`
- generator failures: `0`
- command failures: `1`
- command-failure class: `binaryen-rec-group-zero`
- compared generator split: `82` `gen-valid`, `81` `wasm-smith`

The rerun hit `maxFailuresHit: true`, but every saved semantic mismatch in this run was a `gen-valid` case labeled only as `normalized outputs differed`.

Manual diff inspection of representative failures (`case-000006-gen-valid`, `case-000018-gen-valid`, `case-000022-gen-valid`, `case-000024-gen-valid`, `case-000026-gen-valid`, `case-000052-gen-valid`) showed the same pattern each time:

- no instruction-body diff
- only local declaration count/type/order drift between Starshine and Binaryen normalized WAT
- representative examples include extra or reordered locals such as `f64` / `f32` / `i64` declarations appearing in Starshine where Binaryen prints fewer or differently ordered locals

A quick whole-failure diff scan over the saved `gen-valid` mismatch set found no non-local-line diff hunks in the first twenty saved semantic failures.

## Conclusion

The dedicated `[RUB]002` task is complete:

- the direct debug-artifact lane was rerun on current head and is still green on normalized WAT and canonical function comparison,
- the larger mixed-generator direct-pass rerun was completed,
- and the fresh direct mismatch family is no longer evidence of a mutation-backed branch rewrite bug.

The remaining direct-pass RUB work should stay under shared `[AUD]001` as **local-normalization shaping drift**, not as a separate `remove-unused-brs` ordered-neighborhood/runtime slice. Ordered-neighborhood proof and end-to-end runtime work still exist, but they now belong to the broader optimize-path queue rather than a standalone `[RUB]002` tracker entry.
