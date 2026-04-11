---
kind: concept
status: working
last_reviewed: 2026-04-10
sources:
  - ../raw/research/0077-2026-04-10-moonbit-prove-strategy.md
  - ../../../src/validate/env.mbt
  - ../../../src/validate/match.mbt
  - ../../../src/validate/typecheck.mbt
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
- `proof_axiomatized` should not become a permanent escape hatch in validator-critical code. Every such assumption expands the trusted surface and must stay temporary and explicit.

## Staged Rollout

1. Bootstrap the prover toolchain.
   Install Why3 `1.7.2` plus `z3` first. Keep local setup on the generated default Why3 config; use `moon prove --why3-config` only when CI or a hermetic repro actually needs it.
2. Pilot in [`../../../src/validate/env.mbt`](../../../src/validate/env.mbt).
   Enable proofs in `src/validate/moon.pkg`, add a small logic file such as `env_proof.mbtp`, and prove the existing environment and label-stack invariants that are already pinned by [`../../../src/validate/env_tests.mbt`](../../../src/validate/env_tests.mbt).
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
  - `moon prove src/validate/env.mbt`
  - `moon prove src/validate/match.mbt`
  - only later `moon prove src/validate`
- When the Why3 output is opaque, debug with compiler-level emission through `moonc prove -emit-only` and explicit WhyML/report output paths instead of turning the whole workflow inside out.
- Keep `moon` commands serialized in normal developer workflows because this repo already treats `_build/.moon-lock` contention as real.
- Defer first-wave proofs for:
  - [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt)
  - [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt)
  - [`../../../src/bitset/bitset.mbt`](../../../src/bitset/bitset.mbt)
  - pass and fuzz entrypoints

## Sources

- Archived investigation: [`../raw/research/0077-2026-04-10-moonbit-prove-strategy.md`](../raw/research/0077-2026-04-10-moonbit-prove-strategy.md)
- Official MoonBit verification docs: <https://docs.moonbitlang.com/en/latest/language/verification.html>
- Existing validator executable oracle:
  - [`../../../src/validate/env_tests.mbt`](../../../src/validate/env_tests.mbt)
  - [`../../../src/validate/typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt)
