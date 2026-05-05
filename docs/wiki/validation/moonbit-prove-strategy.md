---
kind: concept
status: working
last_reviewed: 2026-05-05
sources:
  - ../raw/research/0077-2026-04-10-moonbit-prove-strategy.md
  - ../../../src/validate/moon.pkg
  - ../../../src/validate_proof/moon.pkg
  - ../../../src/validate/env.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/match.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate_proof/suffix_index.mbt
related:
  - ../validate/fuzz-hardening.md
  - ../../../src/validate/env_tests.mbt
  - ../../../src/validate/typecheck_negative_tests.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/bitset/bitset.mbt
---

# MoonBit Formal Proof Strategy

## Durable Conclusions

- `moon prove` is a package-local, Why3-backed workflow. A package must opt in through `moon.pkg` with `"proof-enabled": true` before the verifier will touch it.
- The current official proof model is strongest on small, model-based invariants over executable MoonBit code plus `.mbtp` predicates and lemmas.
- The current proof model reasons over mathematical integers, so proofs do not replace runtime tests for overflow-sensitive, byte-precise, or bit-precise behavior.
- Starshine should start in `src/validate`, not in `src/binary`, `src/bitset`, `src/diff`, or the pass pipeline.
- The validator proof rollout should stay incremental: prove one file or helper slice first, then widen only after the slice is stable.
- The current in-tree bootstrap landed first in `src/validate_proof`, not directly in `src/validate`, because `src/validate` is not proof-enabled today (`proof-enabled` is absent from `src/validate/moon.pkg`) and historical prove-attempt output still records a `jtenner/starshine/lib` lowering failure: `unbound type symbol 'name'`.
- The active proof kernel currently proves `10` helper goals in `src/validate_proof` and already covers label-stack lookup, current-frame/group index arithmetic, defined-function body/index translation, declared-function bounds checks, suffix-base recovery used by validator diagnostics, and rectype-suffix member-to-absolute index recovery.
- `LabelStack` is a persistent branchable stack: `LabelStack::copy` shares backing storage, so proved reverse-index arithmetic can be reused in `LabelStack::get`, but logical lookup still has to walk `head` / `parents` instead of indexing `values` directly.
- `proof_axiomatized` should not become a permanent escape hatch in validator-critical code. Every such assumption expands the trusted surface and must stay temporary and explicit.
- As of 2026-05-05, the committed proof gate is `moon prove src/validate_proof` only. It is safe to require in local/CI proof jobs once Why3/Z3 are installed, but broad root-level or direct `src/validate` proof gates remain deferred.
- As of 2026-05-05, no committed source uses `proof_axiomatized`; deferred recursive-match facts are tracked below as design debt, not trusted assumptions.

## Staged Rollout

1. Bootstrap the prover toolchain.
   Install Why3 `1.7.2` plus `z3` first. Keep local setup on the generated default Why3 config; use `moon prove --why3-config` only when CI or a hermetic repro actually needs it.
2. Pilot in the validator helper boundary first.
   Keep the first machine-checked slices in [`../../../src/validate_proof/label_index.mbt`](../../../src/validate_proof/label_index.mbt), [`../../../src/validate_proof/stack_index.mbt`](../../../src/validate_proof/stack_index.mbt), [`../../../src/validate_proof/group_index.mbt`](../../../src/validate_proof/group_index.mbt), [`../../../src/validate_proof/func_index.mbt`](../../../src/validate_proof/func_index.mbt), [`../../../src/validate_proof/bounds_index.mbt`](../../../src/validate_proof/bounds_index.mbt), and [`../../../src/validate_proof/suffix_index.mbt`](../../../src/validate_proof/suffix_index.mbt), then wire those helpers back into [`../../../src/validate/env.mbt`](../../../src/validate/env.mbt) and [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt).

   Keep `src/validate` proof progression off by default until the package is explicitly proof-enabled and the Why3 `lib` lowering blocker is cleared.
3. Extend to [`../../../src/validate/match.mbt`](../../../src/validate/match.mbt).
   Focus first on small algebraic lemmas like `descriptor_compatible` symmetry and obvious equal-shape match properties before taking on deeper exact-recursion proofs.
4. Move into the typechecker helper layer, not the whole instruction surface.
   Target stack-shape helpers in [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) first. If whole-file proving gets noisy, extract the proof-friendly helpers into a smaller sibling file or package before widening the proof boundary.
5. Keep the rest of the assurance stack in place.
   Formal proofs should complement, not replace, `moon test`, `bun validate`, validator fuzzing, binary roundtrip coverage, and spec-based tests.

## Practical Rules

- Keep proof logic in small slice-specific `.mbtp` files such as `env_proof.mbtp` and `match_proof.mbtp`.
- Prefer named predicates like `*_wf`, `*_inv`, and `*_post` over large inline formulas.
- Use targeted local proving during development:
  - `moon prove src/validate_proof`
  - For `src/validate` slices, first enable proof by setting `"proof-enabled": true` in [`../../../src/validate/moon.pkg`](../../../src/validate/moon.pkg), then prove focused files such as:
    - `moon prove src/validate/env.mbt`
    - `moon prove src/validate/match.mbt`
  - only later `moon prove src/validate`
- Keep CI proof gating opt-in until the direct `src/validate` blocker is cleared. Required CI/local proof checks should be limited to proof-enabled packages or files that are expected to prove cleanly on the documented Why3/Z3 setup; broad root-level `moon prove` remains a future policy decision, not a current release gate.
- Treat `src/validate_proof` as the current committed proof boundary: it is intentionally proof-enabled, contains standalone arithmetic/index lemmas, and is safe to run in CI or local signoff with `moon prove src/validate_proof` when Why3/Z3 are available.
- Treat direct `src/validate` proving as experimental only: enabling proof in `src/validate/moon.pkg` is a temporary local investigation step until the historical `jtenner/starshine/lib` WhyML lowering failure is removed or documented as obsolete by a fresh successful targeted run.
- When the Why3 output is opaque, debug with compiler-level emission through `moonc prove -emit-only` and explicit WhyML/report output paths instead of turning the whole workflow inside out.
- Keep `moon` commands serialized in normal developer workflows because this repo already treats `_build/.moon-lock` contention as real.
- Defer first-wave proofs for:
  - [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt)
  - [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt)
  - [`../../../src/bitset/bitset.mbt`](../../../src/bitset/bitset.mbt)
  - pass and fuzz entrypoints

## Current CI / Local Gate Policy

- Required proof gate today: `moon prove src/validate_proof`, but only on machines with configured Why3/Z3. If no configured prover is available, record that exact environment limitation instead of treating the proof as failed semantic evidence.
- Not required today: root-level `moon prove`, `moon prove src/validate`, or targeted direct-validator proving such as `moon prove src/validate/match.mbt`.
- Graduation rule: before widening required gates, land the target as a proof-enabled package/file, document any new trusted assumptions in the ledger below, and keep `moon test` / fuzz / binary roundtrip gates unchanged.

## Trust-Surface Ledger

| Surface | Status | Required follow-up |
| --- | --- | --- |
| Committed `proof_axiomatized` usage | none found on 2026-05-05 outside docs/backlog mentions | Keep this row current whenever an axiom is introduced or removed. |
| Direct `src/validate` proving | deferred | Recheck only after the historical `jtenner/starshine/lib` WhyML lowering blocker is cleared or proven obsolete by a fresh targeted run. |
| Recursive `match.mbt` subtype/exactness facts | deferred design debt | Start with `descriptor_compatible` symmetry and equal-shape match facts; do not replace hard recursive proof obligations with permanent axioms. |
| Typechecker stack-discipline facts | deferred design debt | Extract proof-friendly helpers if whole-file proving becomes noisy; keep executable stack tests as the oracle meanwhile. |

## Current Kernel

- `src/validate_proof` currently proves:
  - `label_stack_storage_index`
  - `latest_stack_index`
  - `group_relative_absolute_index`
  - `group_member_relative_index`
  - `defined_func_body_index`
  - `defined_func_absolute_index`
  - `defined_body_func_index`
  - `bounded_index`
  - `suffix_start_index`
  - `rectype_suffix_member_index`
- Those helpers currently drive:
  - `LabelStack::get` parent-chain label lookup in `env.mbt`
  - `Env::get_label_types`
  - `Env::resolve_subtype` and `Env::resolve_typeidx_subtype`
  - `typecheck.mbt` branch-on-null / branch-on-cast label-tail index recovery
  - `typecheck.mbt` stack-top recovery in `check_pop_types_from_top` / `validate_end_stack`
  - descriptor-metadata group indexing in `validate.mbt`
  - name-section function, type, table, memory, global, elem, data, tag, local, label, and field-name bounds checks
  - code-body diagnostic function-index mapping
  - declared-function bitset bounds checks in the `ref.func` declaration pass
  - suffix-base recovery for current rectype groups and imported-function prefixes
  - suffix-local rectype member recovery for resolving relative members to absolute type indices

## Sources

- Archived investigation: [`../raw/research/0077-2026-04-10-moonbit-prove-strategy.md`](../raw/research/0077-2026-04-10-moonbit-prove-strategy.md)
- Official MoonBit verification docs: <https://docs.moonbitlang.com/en/latest/language/verification.html>
- Existing validator executable oracle:
  - [`../../../src/validate/env_tests.mbt`](../../../src/validate/env_tests.mbt)
  - [`../../../src/validate/typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt)
