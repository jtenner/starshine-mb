# OI-J `ref.test_desc` and descriptor BrOn boundary refresh

Date: 2026-07-04

## Scope

This bounded slice does not implement a new optimizer fold. It rechecks two remaining OI-J surfaces that were repeatedly listed as blockers after the standalone `ref.get_desc` self-contained branch slices:

- local Starshine `ref.test_desc` text/binary/tooling; and
- Binaryen descriptor branch forms `br_on_cast_desc_eq` / `br_on_cast_desc_eq_fail`.

The goal is to separate true representation/tooling boundaries from implementable optimize-instructions behavior before selecting broader descriptor/exactness/TNH/IIT work.

## Evidence

### `ref.test_desc`

Probe input: `.tmp/oi-j-next-probes/ref-test-desc-legacy-probe.wat`.

Commands and results:

```text
wasm-opt --all-features .tmp/oi-j-next-probes/ref-test-desc-legacy-probe.wat --optimize-instructions -S -o .tmp/oi-j-next-probes/ref-test-desc-legacy.binaryen.wat
=> failed: unrecognized instruction at `ref.test_desc`

wasm-tools validate --features all .tmp/oi-j-next-probes/ref-test-desc-legacy-probe.wat
=> failed: unknown operator at `ref.test_desc`

target/native/release/build/cmd/cmd.exe --optimize-instructions --out .tmp/oi-j-next-probes/ref-test-desc-legacy.starshine.wasm .tmp/oi-j-next-probes/ref-test-desc-legacy-probe.wat
=> failed final validation; the emitted body decoded as `ref.cast_desc_eq` without a descriptor operand and had a result type mismatch
```

This confirms the earlier matrix claim: `ref.test_desc` is not a comparable Binaryen `version_130` optimize-instructions oracle surface in local text tooling, and Starshine's local legacy binary spelling is not currently a validating roundtrip path. Do not add OI-J optimizer folds for `RefTestDesc` until the representation is deliberately repaired or removed and an oracle source exists.

### Descriptor BrOn variants

Probe input: `.tmp/oi-j-next-probes/br-on-cast-desc-boundary.wat`.

Commands and results:

```text
wasm-opt --all-features .tmp/oi-j-next-probes/br-on-cast-desc-boundary.wat --optimize-instructions -S -o .tmp/oi-j-next-probes/br-on-cast-desc-boundary.binaryen.wat
=> passed; Binaryen removed the explicit `ref.as_non_null` from the descriptor operand of `br_on_cast_desc_eq`

wasm-tools validate --features all .tmp/oi-j-next-probes/br-on-cast-desc-boundary.wat
=> passed

target/native/release/build/cmd/cmd.exe --optimize-instructions --out .tmp/oi-j-next-probes/br-on-cast-desc-boundary.starshine.wasm .tmp/oi-j-next-probes/br-on-cast-desc-boundary.wat
=> failed decode with `InvalidInstruction`

grep -R "BrOnCastDesc\|br_on_cast_desc" -n src --include='*.mbt'
=> no Starshine lib/HOT/lower/validate surface found
```

Binaryen `optimize-instructions-desc.wast` includes descriptor branch-cast forms and `OptimizeInstructions.cpp::visitBrOn` optimizes descriptor operands by applying `skipNonNullCast` and `trapOnNull` when a `BrOn` has a descriptor child. Starshine currently represents only ordinary `BrOnCast` / `BrOnCastFail`, so descriptor BrOn parity is a representation boundary rather than a safe extension of the just-implemented ordinary BrOn standalone proof.

## Decision

- Keep `ref.test_desc` classified as a text/binary/tooling boundary for OI-J.
- Keep descriptor BrOn forms classified as a representation boundary: Binaryen has source/lit behavior, but Starshine lacks instruction representation and decode support.
- Do not widen ordinary `BrOnCast` / `BrOnCastFail` OI-J proofs to descriptor BrOn opcodes by analogy.
- Future work may reopen either boundary only with representation-first tests and source-backed optimizer probes.

## Validation

Docs/boundary-only validation in this slice:

```text
python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/dev/null
```

No Moon behavior tests were added because this slice intentionally implements no behavior. The executed probes above are the evidence for classifying unsupported/tooling/representation boundaries.

## Remaining OI-J work

OI-J remains `blocked-surface`. The ref.test-desc and descriptor BrOn blockers are now sharper unsupported/tooling/representation boundaries, but broader descriptor-cast behavior, useful-type-info and exactness breadth, broader TNH/IIT escaping/control descriptor surfaces, arbitrary ordinary cast targets, escaping labels, payload prefixes, effectful/control operands, EH/control descriptor surfaces, multivalue children, and generalized descriptor effect/control localization remain open.
