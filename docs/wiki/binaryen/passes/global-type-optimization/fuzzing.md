---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `global-type-optimization` Fuzzing Status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` lane for `global-type-optimization` today.

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) classifies the local full-name spelling as boundary-only, so Starshine intentionally rejects it rather than running a pass.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not admit `--global-type-optimization` in `SUPPORTED_PASS_FLAGS`. It also does not establish the upstream `gto` alias as a local executable spelling.
- Therefore, a rejected command or zero useful comparisons is a **status check**, not Binaryen-parity evidence. Follow the four admission gates in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless discovery command only to inspect the admitted harness roster:

```text
bun fuzz compare-pass --list-passes
```

## Why ordinary GenValid is insufficient by itself

Upstream GTO is a closed-world, GC-only private-struct transform. Meaningful tests need field traffic, subtype layouts, and output behavior that preserve effects and traps while fields become immutable or disappear. A random module with GC enabled is not enough evidence that those preconditions occurred.

Before a runnable lane exists, focused fixtures must cover at least:

- non-GC or open-world policy, public and imported types, non-private parents, and non-struct boundaries;
- private-field mutability tightening versus unread-field removal, including `struct.new` traffic that does not by itself retain a field;
- subtype-layout reorder legality and JS descriptor/prototype-field keepalive behavior;
- removed `struct.set` values whose side effects and null traps must remain observable; and
- module-initializer rewrite cases, field-name/type remapping, binary round trips, and validator checks after the type graph changes.

See [`./wat-shapes.md`](./wat-shapes.md) and [`./field-removal-subtyping-js-interop-and-traps.md`](./field-removal-subtyping-js-interop-and-traps.md) for the concrete shape families.

## Future runnable template

Enable a comparison lane only after all of these are true:

1. an active Starshine closed-world module pass implements its documented private-struct rewrite scope;
2. the registry exposes one canonical local spelling and documents how it maps to Binaryen `--gto`;
3. `SUPPORTED_PASS_FLAGS` admits that spelling and `bun fuzz compare-pass --list-passes` reports it; and
4. a fixture corpus or GC/type-aware generator profile yields meaningful compared cases with an explicit `--min-compared` threshold.

Candidate command shape once those gates are satisfied:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass global-type-optimization --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-global-type-optimization --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

This is a **future template**, not current signoff guidance. Record the closed-world configuration, feature/profile mix, normalizers, and replay-artifact contract before treating a lane as parity evidence.
