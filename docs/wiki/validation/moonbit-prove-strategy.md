---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/moonbit/2026-06-04-formal-verification-v093-refresh.md
  - ../raw/moonbit/2026-05-20-formal-verification-command-and-trust-refresh.md
  - ../raw/moonbit/2026-05-20-workspace-package-surface.md
  - ../raw/moonbit/2026-05-13-formal-verification-docs.md
  - ../raw/research/0077-2026-04-10-moonbit-prove-strategy.md
  - ../raw/research/0515-2026-05-06-validate-proof-boundary-audit.md
  - ../../../src/validate/moon.pkg
  - ../../../src/validate_proof/moon.pkg
  - ../../../src/validate_proof/pkg.generated.mbti
  - ../../../src/validate/imports.mbt
  - ../../../src/validate/env.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate_proof/bounds_index.mbt
  - ../../../src/validate_proof/func_index.mbt
  - ../../../src/validate_proof/group_index.mbt
  - ../../../src/validate_proof/label_index.mbt
  - ../../../src/validate_proof/rectype_index.mbt
  - ../../../src/validate_proof/stack_discipline.mbt
  - ../../../src/validate_proof/stack_index.mbt
  - ../../../src/validate_proof/suffix_index.mbt
related:
  - ../tooling/validation-gates.md
  - ../tooling/moonbit-workspace-package-map.md
  - ../validate/fuzz-hardening.md
  - ../../../src/validate/env_tests.mbt
  - ../../../src/validate/typecheck_negative_tests.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/bitset/bitset.mbt
---

# MoonBit Formal Proof Strategy

## Overview

MoonBit verification is useful in Starshine when a small executable helper has a crisp arithmetic, bounds, or stack-shape postcondition that can be expressed in `.mbtp` predicates. It is **not** a replacement for validator tests, fuzzing, binary roundtrip tests, or pass parity checks. The current project boundary is deliberately narrow: keep the required proof gate in the low-dependency `src/validate_proof` package, then import only stable helpers into `src/validate` after executable tests already describe the behavior.

Official MoonBit docs frame verification as a Why3-backed workflow driven by `moon prove`, with package opt-in through `proof-enabled`, solver setup around Why3 plus solvers such as Z3, CVC5, or Alt-Ergo, executable `where` contracts, and proof-only companion material such as `.mbtp` predicates. The broader package-topology map in [`../tooling/moonbit-workspace-package-map.md`](../tooling/moonbit-workspace-package-map.md) owns the general `moon.pkg` / `is-main` / generated-interface rules; this page owns only proof policy and trust boundaries. The 2026-06-04 v0.9.3 refresh confirms the upstream shape is still compatible with Starshine's small helper-package strategy and adds one practical source-current nuance: official file-targeted proving assumes dependencies, so direct `src/validate/*.mbt` proof runs are useful local investigations but do not automatically graduate into the required gate. MoonBit also exposes richer proof-only and trusted/axiomatized surfaces that Starshine does **not** use in committed `src/` code today, so adopting those constructs would widen the trust boundary and must be documented deliberately. Starshine's local policy follows the upstream package model but keeps the broad validator package optional because the PRV006 audit showed direct `src/validate` file targets are not isolated enough for the required gate in this workspace. See the current v0.9.3 source bridge in [`../raw/moonbit/2026-06-04-formal-verification-v093-refresh.md`](../raw/moonbit/2026-06-04-formal-verification-v093-refresh.md), the 2026-05-20 command/trust refresh in [`../raw/moonbit/2026-05-20-formal-verification-command-and-trust-refresh.md`](../raw/moonbit/2026-05-20-formal-verification-command-and-trust-refresh.md), the earlier official-doc manifest in [`../raw/moonbit/2026-05-13-formal-verification-docs.md`](../raw/moonbit/2026-05-13-formal-verification-docs.md), the local PRV006 audit in [`../raw/research/0515-2026-05-06-validate-proof-boundary-audit.md`](../raw/research/0515-2026-05-06-validate-proof-boundary-audit.md), and the shared validation-gate map in [`../tooling/validation-gates.md`](../tooling/validation-gates.md).

## Durable Conclusions

- `moon prove` is a package-oriented, Why3-backed workflow. A package must opt in through `moon.pkg` / `moon.pkg.json` with `proof-enabled` before the verifier will prove it.
- Proofs should live beside small executable helpers: `.mbt` files keep the implementation and `where` contracts, while `.mbtp` files keep reusable predicates and lemmas.
- The official docs describe package/file-targeted proving with dependencies assumed. Locally, this reinforces the current design: prove `src/validate_proof` directly, then let `src/validate` consume the verified helper functions instead of making broad dependency proof output part of the default release gate.
- The current proof model reasons over mathematical integers, so proofs do not replace runtime tests for overflow-sensitive, byte-precise, bit-precise, or wasm-encoding behavior.
- Starshine should keep first-wave proof work in validator-adjacent helper packages, not in `src/binary`, `src/bitset`, pass implementations, or fuzz entrypoints.
- `proof_axiomatized` and similar proof-control/trust annotations should not become permanent escape hatches in validator-critical code. Every trusted assumption expands the proof boundary and must stay temporary, explicit, and listed in the trust-surface ledger.
- Solver knobs such as a custom Why3 config and proof parallelism are host/tooling settings. Record them when they affect a run, but do not treat them as semantic evidence about Starshine's validator.
- As of 2026-06-04, repository search found no committed source under `src/` using `proof_axiomatized`, `#proof_pure`, `proof_decrease`, `proof_reasoning`, `proof_assert`, `proof_invariant`, or `proof_yield`; mentions remain policy/history only in docs and backlog material.

## Current Starshine Boundary

### Required proof gate

- Required proof target on a configured prover host: `moon prove src/validate_proof`.
- The current Moon command manual/source is the command-shape authority for `moon prove`, including solver/configuration controls; Starshine's repo policy still owns *when* to run it and intentionally keeps it out of `bun validate full`.
- `src/validate_proof/moon.pkg` is proof-enabled and imports only `moonbitlang/core/debug` for tests.
- `src/validate/moon.pkg` is also proof-enabled, but direct-validator proving remains optional because the PRV006 audit observed that file-targeted `moon prove src/validate/...` dry-runs emit broad package plus dependency proof artifacts.
- If no configured prover is available, record the host/tooling limitation exactly. Do not treat a missing Why3/solver setup as semantic evidence against the proof kernel.

### Machine-checked helper kernel

`src/validate_proof` currently exports fifteen executable helpers with proof postconditions:

| Helper | Purpose | Live validator consumption |
| --- | --- | --- |
| `bounded_index` | Generic `0 <= idx < len` bounds proof. | Imported by `src/validate/imports.mbt`; used heavily for name-section and declared-function index checks in `src/validate/validate.mbt`. |
| `defined_func_body_index` | Map absolute function indices to defined-code-body indices after imported-function prefix removal. | Imported and used by `src/validate/validate.mbt`. |
| `defined_func_absolute_index` | Map a defined body ordinal back to an absolute function index. | Imported and used while validating code bodies in `src/validate/validate.mbt`. |
| `defined_body_func_index` | Bounds-check a code body ordinal and return the corresponding absolute function index. | Imported and used by `src/validate/validate.mbt`. |
| `group_relative_absolute_index` | Map a rec-group relative member to its absolute type index. | Imported and used by descriptor metadata validation and subtype resolution in `src/validate/validate.mbt`. |
| `group_member_relative_index` | Recover a relative member index from an absolute type index inside a group. | Imported and used by `src/validate/validate.mbt`. |
| `label_stack_storage_index` | Convert branch-depth style label lookup to reverse storage indexing. | Imported and used by `LabelStack::get` and label resolution in `src/validate/env.mbt`. |
| `latest_stack_index` | Recover the top element index of a nonempty stack. | Imported and used by rec-stack lookups in `src/validate/env.mbt` and label-tail checks in `src/validate/typecheck.mbt`. |
| `suffix_start_index` | Recover the start index of a suffix inside a longer list. | Imported and used for current rec-group and imported-function-prefix recovery in `src/validate/validate.mbt`. |
| `rectype_suffix_member_index` | Compose suffix recovery with group-relative type indexing. | Proved and exported, but not imported into `src/validate` as of the 2026-06-04 import-map recheck. Keep as sidecar evidence until a call site needs the combined helper. |
| `stack_len_after_push1` | Prove one-value stack push length. | Proved and exported, currently sidecar-only. |
| `stack_len_after_push_types` | Prove multi-value stack push length. | Proved and exported, currently sidecar-only. |
| `stack_len_after_pop1` | Prove one-value pop length and underflow behavior. | Proved and exported, currently sidecar-only. |
| `stack_len_after_pop_types` | Prove multi-value pop length and underflow behavior. | Proved and exported, currently sidecar-only. |
| `stack_suffix_start_after_end_check` | Prove result-suffix recovery after end-stack checking. | Proved and exported, currently sidecar-only. |

The important maintenance rule is to distinguish **proved/exported** from **wired into the live validator**. The April/May audits remain valuable, but the current code map still shows only nine of the fifteen helpers imported by `src/validate/imports.mbt`; the rectype-composition helper and stack-discipline helpers are reusable sidecar proofs until a future typechecker slice adopts them. `src/validate_proof/pkg.generated.mbti` is the quick roster for exported helper count, while `src/validate/imports.mbt` is the quick roster for live validator consumption.

## Staged Rollout

1. **Keep the prover toolchain setup explicit.** Install Why3 and at least one supported solver, then verify that `moon prove src/validate_proof` sees the configured prover. The official docs mention Z3, CVC5, and Alt-Ergo; Starshine's older raw notes used Why3 `1.7.2` plus Z3.
2. **Maintain `src/validate_proof` as the stable required gate.** Add new helpers only when they are small, dependency-light, executable in MoonBit, and useful to the validator.
3. **Import helpers into `src/validate` only after the executable behavior is covered.** Current consumers include `env.mbt`, `validate.mbt`, and `typecheck.mbt`; keep `imports.mbt` as the quick truth source for what is live.
4. **Extend `src/validate/match.mbt` only through designed proof slices.** The Boolean `descriptor_compatible` symmetry pilot and equal/unequal executable regressions are useful, but recursive subtype/exactness facts remain deferred.
5. **Move broader typechecker proofs after the matching kernel.** The stack-length helpers exist, but value-type compatibility and branch-exit normalization depend on validator matching semantics.
6. **Keep the rest of the assurance stack in place.** Formal proofs complement the ordinary gates described in [`../tooling/validation-gates.md`](../tooling/validation-gates.md): `moon test`, `bun validate`, validator fuzzing, binary roundtrip coverage, spec tests, and Binaryen oracle lanes.

## Practical Rules

- Prefer pure arithmetic/index helpers with named postcondition predicates such as `*_post` in `.mbtp` files.
- Keep proof-enabled packages small. If a direct proof target pulls in broad dependency proof output, treat it as investigative until a fresh audit says otherwise.
- Use targeted local proving during development:
  - required/current: `moon prove src/validate_proof`
  - optional/investigative: `moon prove src/validate/env.mbt`, `moon prove src/validate/match.mbt`, or `moon prove src/validate` (official file-target mode assumes dependencies, so record that assurance boundary)
  - future-only: root-level `moon prove`
- When Why3 output is opaque, debug with compiler-level emission, explicit WhyML/report output paths, or a documented local Why3 configuration instead of widening the required gate.
- Keep `moon` commands serialized in normal developer workflows because this repo already treats `_build/.moon-lock` contention as real.
- Do not add `proof_axiomatized`, trusted proof declarations, or other proof-control annotations without updating this page, the trust-surface ledger below, the relevant backlog item, and tests that keep the trusted assumption narrow.

## Current CI / Local Gate Policy

- Required proof gate today: `moon prove src/validate_proof`, but only on machines where MoonBit's Why3 harness recognizes a configured solver.
- Not required today: root-level `moon prove`, broad `moon prove src/validate`, or targeted direct-validator proving such as `moon prove src/validate/match.mbt`.
- Graduation rule: before widening required gates, land the target as a small proof-enabled package/file, document any new trusted assumptions, keep executable tests/fuzz/roundtrip gates unchanged, and refresh the wiki/log with the new proof boundary.

## Trust-Surface Ledger

| Surface | Status | Required follow-up |
| --- | --- | --- |
| Committed trusted proof-control usage | none found under `src/` on 2026-06-04 for `proof_axiomatized`, `#proof_pure`, `proof_decrease`, `proof_reasoning`, `proof_assert`, `proof_invariant`, or `proof_yield` | Keep this row current whenever an axiom, trusted declaration, or proof-control annotation is introduced or removed. |
| Direct `src/validate` proving | deferred after PRV006 audit | Current targeted dry-runs emit the whole validate package plus dependency proof artifacts; recheck only when this surface is intended for a required gate. |
| Recursive `match.mbt` subtype/exactness facts | deferred design debt | Keep the Boolean pilot and executable regressions; do not replace recursive proof obligations with permanent axioms. |
| `LabelStack` structural invariant | deferred second-wave data-structure proof | Arithmetic lookup helpers are proved and live; parent-chain/head/len invariants require a richer mutable-structure model and remain covered by `env_tests.mbt`. |
| Typechecker stack-discipline facts | sidecar helper slice landed | `src/validate_proof/stack_discipline.mbt` proves length facts, but these helpers are not imported into `src/validate` yet; adopt them only with a focused typechecker proof/design slice. |

## Sources

- Official MoonBit verification docs: <https://docs.moonbitlang.com/en/latest/language/verification.html>
- Official Moon command manual: <https://moonbitlang.github.io/moon/commands.html>
- Official Moon command-manual source: <https://github.com/moonbitlang/moon/blob/main/docs/manual/src/commands.md>
- Official MoonBit 0.9 formal-verification blog post: <https://www.moonbitlang.com/blog/moonbit-0-9-release>
- 2026-06-04 v0.9.3 source bridge: [`../raw/moonbit/2026-06-04-formal-verification-v093-refresh.md`](../raw/moonbit/2026-06-04-formal-verification-v093-refresh.md)
- 2026-05-20 command/trust manifest: [`../raw/moonbit/2026-05-20-formal-verification-command-and-trust-refresh.md`](../raw/moonbit/2026-05-20-formal-verification-command-and-trust-refresh.md)
- Workspace/package map: [`../tooling/moonbit-workspace-package-map.md`](../tooling/moonbit-workspace-package-map.md), [`../raw/moonbit/2026-05-20-workspace-package-surface.md`](../raw/moonbit/2026-05-20-workspace-package-surface.md)
- 2026-05-13 official-source manifest: [`../raw/moonbit/2026-05-13-formal-verification-docs.md`](../raw/moonbit/2026-05-13-formal-verification-docs.md)
- Original investigation: [`../raw/research/0077-2026-04-10-moonbit-prove-strategy.md`](../raw/research/0077-2026-04-10-moonbit-prove-strategy.md)
- PRV006 boundary audit: [`../raw/research/0515-2026-05-06-validate-proof-boundary-audit.md`](../raw/research/0515-2026-05-06-validate-proof-boundary-audit.md)
- Current proof package and consumers:
  - [`../../../src/validate_proof/moon.pkg`](../../../src/validate_proof/moon.pkg)
  - [`../../../src/validate_proof/pkg.generated.mbti`](../../../src/validate_proof/pkg.generated.mbti)
  - [`../../../src/validate/moon.pkg`](../../../src/validate/moon.pkg)
  - [`../../../src/validate/imports.mbt`](../../../src/validate/imports.mbt)
  - [`../../../src/validate/env.mbt`](../../../src/validate/env.mbt)
  - [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt)
  - [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt)
- Existing validator executable oracles:
  - [`../../../src/validate/env_tests.mbt`](../../../src/validate/env_tests.mbt)
  - [`../../../src/validate/typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt)
