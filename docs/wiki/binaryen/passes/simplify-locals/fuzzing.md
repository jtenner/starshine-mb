---
kind: workflow
status: working
last_reviewed: 2026-07-17
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_ssa.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - ./transform-family-inventory.md
---

# SimplifyLocals family fuzzing profiles

## Canonical aggregate profiles

Every Binaryen public variant now has a direct aggregate GenValid name:

| Pass | Aggregate profile |
| --- | --- |
| `simplify-locals` | `simplify-locals` / `simplify-locals-all` |
| `simplify-locals-notee` | `simplify-locals-notee` / `simplify-locals-notee-all` |
| `simplify-locals-nostructure` | `simplify-locals-nostructure` / `simplify-locals-nostructure-all` |
| `simplify-locals-notee-nostructure` | `simplify-locals-notee-nostructure` / `simplify-locals-notee-nostructure-all` |
| `simplify-locals-nonesting` | `simplify-locals-nonesting` / `simplify-locals-nonesting-all` |

Compatibility pass spellings resolve to their canonical aggregate where applicable.

## Shared family leaves

The four newly covered aggregates select from:

- `simplify-locals-local-traffic`;
- `simplify-locals-structure-result`;
- `simplify-locals-flat-parent`;
- `simplify-locals-effect-order`;
- `simplify-locals-stress`.

The established no-structure aggregate retains its existing straight-line, tee-control, and effect-order leaves for replay continuity.

The body generator now emits dedicated structure-result and nonesting parent-position slices instead of falling through to the broad SSA matrix. Effect/stress leaves deliberately keep memory, globals, and calls while excluding table/reference/tag shapes that the installed Binaryen oracle cannot decode reliably.

## Red-first evidence

The aggregate/profile test was added before the constructors and failed to compile for all nine new leaf/aggregate constructors. After implementation, `gen_valid_tests.mbt` passes `150/150` and proves canonical resolution, composite membership, and feature envelopes.

## Initial profile audit

The first profile-backed compare runs successfully generated valid modules and removed the earlier generic-profile validation/unsupported-heap failures. They also exposed real residual families rather than being declared green:

- structure-enabled output-shape differences around redundant arm blocks/nops;
- effect-order gaps where Binaryen moves or clones local carriers across read-only loads and later consumers;
- no-tee fresh-local spill differences on repeated-local flat-parent shapes;
- dead effectful local-write cleanup differences in nonesting;
- one no-structure canonical wrapper difference.

These are agent-classified open parity/size families until measured or repaired. The structure-arm case is currently smaller in Starshine on the inspected sample, but final Starshine-win classification still requires family-wide semantic and size evidence.

## Smoke command

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass <canonical-pass> --count 1000 --seed <seed> \
  --gen-valid-profile <canonical-pass> --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/pass-fuzz-<canonical-pass>-profile-1000
```

Do not publish a final 10,000-case signoff until every selected leaf has zero validation/property/tool failures and every mismatch is either repaired or documented as a source-backed measured Starshine win.
