---
kind: comparison
status: supported
last_reviewed: 2026-07-27
sources:
  - ./index.md
  - ./fuzzing.md
  - ./multivalue-call-scope.md
  - ../../../raw/binaryen/2026-07-02-reorder-locals-version-130-source-refresh.md
  - ../tracker.md
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/reorder_locals_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ./starshine-hot-ir-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ./multivalue-call-scope.md
---

# `reorder-locals` Binaryen Parity

## Binaryen v131 Oracle Verdict

The 2026-07-27 audit used official `wasm-opt version 131 (version_131)` and Binaryen source commit `1f903c14babf829745b421b92ff0f286e93e4209` as the oracle. The reviewed `ReorderLocals.cpp` and dedicated `reorder-locals*` lit fixtures are byte-identical between `version_130` and `version_131`, so the released owner contract did not change.

The current contract is:

- parameters remain fixed;
- only body locals are reordered or removed;
- `local.get`, `local.set`, and `local.tee` all count as accesses;
- live body locals sort by descending access count;
- live ties use first observed access, then original index as a stable fallback;
- the zero-access suffix is removed;
- every local user is reindexed recursively;
- local-name metadata follows the new indices and stale raw name payload is invalidated;
- the pass does not require non-nullable-local fixups.

Starshine now matches that released behavior for every pass-owned family represented by its boundary IR.

## Audit Repair

The audit found one real Starshine output bug outside the sorter itself. `rl_rewrite_expr` and nested structured rewrites mutated shared instruction arrays in place. For pure same-type permutations, local declarations remained structurally identical, so the original module and optimized module became equal after aliasing. The CLI's unchanged-wasm fast path then reused the original input bytes and lost the remapped indices.

The repair makes root and nested block/loop/if/legacy-`try`/`try_table` rewriting copy-on-write. Red-first tests now prove:

- the input module retains its original local indices;
- the optimized module contains the Binaryen ordering;
- the CLI emits different wasm bytes for a pure same-type permutation;
- nested legacy-EH bodies remain recursively remapped without mutating the source module.

A dedicated `reorder-locals-permutation-only` GenValid leaf keeps all body locals live and all declarations the same type so this output boundary cannot be masked by unused-local trimming or declaration-type changes.

## Transform-Family Inventory

| Family | Evidence | Verdict |
| --- | --- | --- |
| Parameter stability and params-only no-op | Focused pass tests and hot-sort/multi-function generation | exact |
| `local.get` / `local.set` / `local.tee` counting | Focused tests plus hot-sort and permutation-only leaves | exact |
| Descending count and first-use ties | Focused carrier fixtures and high-index generated permutations | exact |
| Pure same-type permutation | Copy-on-write pass/CLI regressions and `reorder-locals-permutation-only` | repaired; exact |
| Mixed declarations and grouped local runs | `reorder-locals-mixed-types` | exact |
| Nullable/non-nullable GC references | `reorder-locals-reference-types` | exact |
| Zero-access trimming and write-only survival | `reorder-locals-unused-trim` | exact |
| Structured recursive reindexing | `reorder-locals-structured` | exact |
| Legacy `try`, typed catches, catch-all, delegates | deterministic repair tests plus `reorder-locals-legacy-eh` | exact |
| Multiple defined functions, imports, parameter arities | `reorder-locals-multi-function` | exact |
| Local-name repair and raw name invalidation | focused metadata/CLI tests and `reorder-locals-name-repair` | exact |
| Repeated public scheduler slots | early tuple/no-structure slot and late simplify/coalesce sandwich remain scheduled | closed for this pass; broader preset work belongs to neighboring owners |

## Final Direct Evidence

The final native Starshine binary had SHA-256 `23fc1d30ef2db126e2690e610ad44b4af8f28da435cab6ebe845b6ec058f96c1`.

- Regular GenValid: `100000/100000` normalized matches.
- Dedicated nine-leaf aggregate: `10000/10000` normalized matches; every leaf selected.
- Dedicated idempotence: `10000/10000` comparisons and idempotence checks, zero property failures.
- Random all-profiles: `9375` normalized matches plus `625` classified Starshine wins from one non-pass-owned multivalue lowering family.
- External wasm-smith: `9955` direct matches plus one `unreachable-control-debris` compare-normalized match across `9956` comparable cases; `44` Binaryen-only command failures; zero remaining mismatches.
- Validation failures, Starshine command failures, generator failures, and true semantic mismatches: zero.

### Random-all Starshine-win family

All `625` residuals were `remove-unused-brs-control` modules containing type-indexed multivalue control. Binaryen materializes a different scratch-local/control shape before its pass runs. Starshine retains the direct multivalue block shape. This is not accepted merely because both outputs validate:

- Starshine canonical wasm was exactly `8` bytes smaller in every residual (`-5000` bytes total).
- A separate `1000`-case replay externally validated both outputs and executed all cases in Node.
- Runtime outcomes were `757` equal results and `243` equal traps, with zero semantic mismatches.
- Starshine was exactly `8` canonical bytes smaller in every replay case (`-8000` total).

This family is therefore a measured Starshine size win with runtime evidence. Reopen if Starshine ceases to be no larger, runtime outcomes diverge, or the Binaryen boundary stops materializing the alternate shape.

## Artifact Quality And Performance

On `tests/node/dist/starshine-debug-wasi.wasm` with debug information preserved:

- Starshine output: `12,784,150` bytes.
- Binaryen v131 `--debuginfo` output: `13,846,853` bytes.
- After applying the same Binaryen-v131 `--strip-debug` canonicalization, Starshine was `5,262,811` bytes versus Binaryen `5,271,695`, an `8,884`-byte Starshine win.
- Twenty-run whole-command medians were `1000.677 ms` for Starshine and `926.353 ms` for Binaryen, ratio `1.080x`; both outputs externally validate.

The ratio is within the repository's `<=2x` target, while Starshine produces smaller comparable output. Process startup, decode, encode, and debug-section handling are included, so this is a whole-command artifact measurement rather than an isolated sorter timer.

## Standing Boundary Decision

The old full-artifact raw wasm non-convergence remains a Binaryen writer/IR-builder boundary, not a `ReorderLocals.cpp` semantic gap. Use normalized/canonical function evidence and the measured size/runtime criteria in [`./multivalue-call-scope.md`](./multivalue-call-scope.md); do not require byte-for-byte raw output when Binaryen materializes a larger alternate multivalue shape.

## Reopening Criteria

Reopen direct parity if any of the following occurs:

- Binaryen changes the v131 owner contract in a later release;
- an encoded pure permutation reuses unchanged input bytes;
- parameters move, an accessed local is removed, a zero-access suffix survives unexpectedly, or a local user/name map is stale;
- legacy-EH protected/catch/delegate structure is mutated incorrectly;
- any dedicated leaf produces a validation, idempotence, or unclassified parity failure;
- the random-all multivalue family loses its canonical size win or runtime equality;
- whole-command artifact performance exceeds `2x` Binaryen without an accepted compensating win.
