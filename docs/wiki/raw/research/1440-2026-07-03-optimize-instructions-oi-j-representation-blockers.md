# Optimize-instructions OI-J representation blockers: descriptor-cast validation and exact ref.test binary support

Date: 2026-07-03

## Scope

This note follows `1439-2026-07-03-optimize-instructions-oi-j-roadmap.md` and intentionally lifts only the finite representation/tooling blockers needed by two roadmap probes:

- Probe 01: `.tmp/oi-j-roadmap-probes-20260703/inputs/01-direct-desc-cast-simplifies.wat`
  - Shape: descriptor-bearing recursive `$a` / `$d` pair, `(ref (exact $a))` value operand, `(ref $d)` descriptor operand, and `ref.cast_desc_eq (ref null $a)`.
  - Prior Starshine status in `.tmp/oi-j-roadmap-probes-20260703/probe-results.*`: validation failure.
- Probe 10: `.tmp/oi-j-roadmap-probes-20260703/inputs/10-exact-success-test-cast.wat`
  - Shape: exact `ref.test (ref (exact $a))` plus exact `ref.cast (ref (exact $a))`.
  - Prior Starshine status in `.tmp/oi-j-roadmap-probes-20260703/probe-results.*`: decode failure.

This is not a TNH/IIT implementation slice and does not broaden the existing `ref.get_desc(ref.as_non_null(local.get nullable))` optimizer rule beyond the direct-local default-mode case selected by the roadmap note.

## Representation changes

- `Instruction::RefTest` now carries target exactness as `RefTest(nullable, exact, heap_type)`, matching the already exact-aware `RefCast` representation.
- Constructors now distinguish inexact and exact tests:
  - `Instruction::ref_test(nullable, ht)` remains the inexact compatibility constructor.
  - `Instruction::ref_test_type(rt)` preserves `RefType` exactness.
  - `Instruction::ref_test_exact(nullable, ht)` constructs exact tests directly.
- Binary decode/encode for `ref.test` / `ref.test_null` now uses the same exact-aware heap immediate path as `ref.cast`, so `0x62 <s33>` exact concrete heap immediates are consumed and preserved.
- Show/arbitrary/generated interface and pass pattern matches were widened to the new `RefTest` arity. Existing optimizer facts that should not infer exact behavior remain guarded to inexact `RefTest(_, false, ...)` where appropriate.

## Validator changes

- `ref.test` now validates exact targets by constructing `RefType::new(nullable, heap_type, exact~)` and applying the existing reference test/cast compatibility check.
- `ref.cast_desc_eq` validation now accepts the probe-01 shape where an exact target result is paired with an inexact non-null descriptor operand describing the same concrete type.
- Descriptor-cast validation is also tighter in nearby invalid cases:
  - nullable descriptor operands are rejected as descriptor operands;
  - descriptor-cast targets must be concrete type-index heap types;
  - descriptor-cast targets must have descriptor metadata.

## Tests added or updated

Red-first intended coverage was added in binary and validation surfaces:

- Binary exact `ref.test` encode/decode bytes `fb 14 62 00` and roundtrip bytes `fb 14 62 01`.
- Truncated exact `ref.test` and exact marker before abstract heap immediate rejection tests.
- Module roundtrip preserving exact `ref.test` and exact `ref.cast` immediates.
- Typechecker exact `RefTest` acceptance for exact concrete sources and rejection for exact abstract targets.
- Descriptor-cast tests covering:
  - non-null descriptor operand stack effect;
  - exact descriptor-cast target accepted with inexact non-null descriptor operand for probe 01;
  - mismatched descriptor target rejection;
  - nullable descriptor operand rejection;
  - descriptorless concrete target rejection.

## Boundaries retained

- The default-mode direct-local standalone `ref.get_desc(ref.as_non_null(local.get nullable))` cleanup from note `1439` remained the only optimizer behavior selected from the roadmap pack in this representation slice. The later note `1441` separately widens the standalone helper only to branch-free block children with ordered zero-result effect/trap roots and a final nullable `local.get`.
- This representation/tooling slice did not widen the optimizer rule to non-local, effectful, trapping, control-produced, TNH, or IIT children; the later `1441` behavior slice covers only its finite default-mode branch-free block subset and keeps control/TNH/IIT fail-closed.
- TNH/IIT descriptor-cast skip behavior remains a future OI-J slice.
- `ref.test_desc` remains a separate text/binary tooling blocker from earlier OI-J descriptor-profile evidence.
- Broader exactness reasoning beyond preserving and validating exact `ref.test`/`ref.cast` immediates remains open.

## Validation status

Signoff run in this thread:

- `moon fmt` passed.
- `moon test --package jtenner/starshine/binary --file tests.mbt` passed `102/102`.
- `moon test --package jtenner/starshine/validate --file typecheck.mbt` passed `550/550`.
- `moon test src/validate` passed `1667/1667`.
- `moon test src/wast` passed `382/382` with pre-existing unused helper warnings.
- Focused descriptor optimizer regression checks passed after keeping inexact descriptor-cast immediates when the descriptor operand is not proven exact.
- Full `moon test` passed `7344/7344`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- `git diff --check` passed.
- Probe replay under `.tmp/oi-j-probe-replay-20260703` parsed both probe WAT files, validated both inputs with `wasm-tools validate --features all`, ran `target/native/release/build/cmd/cmd.exe --optimize-instructions`, and validated both Starshine outputs with `wasm-tools validate --features all`.

Probe replay observations:

- Probe 01 now decodes, optimizes, and emits a validating module. Default-mode Starshine preserves `ref.cast_desc_eq`, narrowing only the nullable result to a non-null inexact cast spelling `ref.cast_desc_eq (ref $a)`; it deliberately does not perform the broader TNH/O4z descriptor-cast removal from the roadmap.
- Probe 10 now decodes, optimizes, and emits a validating module. Exact `ref.test (ref (exact $a))` is preserved, and exact `ref.cast (ref (exact $a))` over an exact local is simplified to the local value.

This note reduces the two named representation blockers only. OI-J remains open for TNH/IIT, ref.test_desc tooling, broad descriptor optimizer behavior, and broader exactness reasoning.
