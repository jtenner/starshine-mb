---
kind: entity
status: strong
starshine_status: active
last_reviewed: 2026-07-26
sources:
  - ../../../../../src/passes/local_subtyping.mbt
  - ../../../../../src/passes/local_subtyping_test.mbt
  - ../../../../../src/passes/local_subtyping_wbtest.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./lubs-and-dominance.md
  - ./fuzzing.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `local-subtyping`

## Status

`local-subtyping` is an active Starshine module pass and is behavior-closed for the represented Binaryen v131 surface as of July 26, 2026.

The renewed audit found and repaired behavior that the earlier v130 closeout profiles did not exercise:

- concrete common-parent LUBs for sibling writes;
- abstract LUBs such as i31 plus struct becoming non-null `eqref`;
- distinct concrete function writes becoming non-null `funcref`;
- exact typed-function LUBs with `nofunc` bottom values, including unreachable assignments;
- nullable-aware pairwise LUB computation;
- abstract typed-null normalization to the appropriate bottom heap type;
- raw assignment fallback before HOT lifting when every relevant write is understood, avoiding unsupported unreachable-shape lift failures;
- Binaryen's official i31-valued if and direct-branch block result refinalization;
- conservative preservation of `catch_ref` / `catch_all_ref` block result types.

## Contract

The pass:

1. scans reference-typed locals and preserves parameter declarations;
2. records `local.set` and `local.tee` assignments, including relevant unreachable writes;
3. computes the least upper bound of all assigned reference values through concrete supertype chains and the abstract heap hierarchy;
4. allows non-null declarations only when structural dominance proves all gets safe;
5. rewrites body-local declarations and iterates until dependent local, select, and call-ref types stabilize;
6. refinalizes the represented official control-result shapes and normalizes typed nulls;
7. fails closed on decoded legacy `try` before mutation and remains conservative around ref-catch result flow.

## Source and test map

- Owner: `src/passes/local_subtyping.mbt`.
- Direct behavior: `src/passes/local_subtyping_test.mbt` (`77` focused tests).
- Internal subtype/raw/refinalization contracts: `src/passes/local_subtyping_wbtest.mbt` (`4` focused white-box tests).
- Generator families: `src/validate/gen_valid.mbt` and `src/validate/gen_valid_tests.mbt`.
- Registry/preset/dispatch: `src/passes/optimize.mbt`, `src/passes/pass_manager.mbt`, registry tests, optimize tests, and CLI tests.

## v131 evidence

The official source refresh used Binaryen `version_131`:

- `LocalSubtyping.cpp` SHA-256 `f5cdc0792d0499bdcb8a93c3fc6490e21d4c1753663f7be24e945a9d85965c2e`;
- `local-subtyping.wast` SHA-256 `01efe49996a15075cdc4188cd079ee24deaf76508ca6886d5af894286b93afc5`;
- `local-structural-dominance.h` SHA-256 `5dbc4529376148136d3ba39b3f7c1bea1ff505be57f4997a1f1c1e30a63c920c`.

The final direct matrix is documented in [`fuzzing.md`](./fuzzing.md): regular `100000/100000`, dedicated `10000/10000`, random-all `10000/10000`, and wasm-smith exact for `9955` of `9956` comparable cases plus one cleanup-normalized, pass-independent unreachable-debris case. There are zero true semantic, Starshine validation, generator, or property failures.

## Remaining boundaries

- Decoded legacy `try` remains a deliberate pre-mutation fail-closed boundary because the raw algorithm models `try_table`, not legacy handler flow.
- The two historical Binaryen nondefaultable-local outputs rejected by `wasm-tools` remain validator/tooling boundaries rather than emitted Starshine behavior: direct block-return unreachable-tail and raw-unreachable-before-write tee/get. Starshine keeps validating nullable declarations there.
- The wasm-smith case `009332` belongs to shared unreachable cleanup, not local-subtyping; `--normalize unreachable-control-debris` proves convergence.

Reopen the pass only for a reduced represented-surface mismatch, a v132+ source change, a validator change that makes a historical boundary valid, or a new local-subtyping family missing from the aggregate profile.
