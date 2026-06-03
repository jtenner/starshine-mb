---
kind: research
status: current
last_reviewed: 2026-06-03
sources:
  - ../../binaryen/passes/pick-load-signs/index.md
  - ../../binaryen/passes/pick-load-signs/parity.md
  - ../../binaryen/passes/pick-load-signs/starshine-strategy.md
  - ../../binaryen/passes/pick-load-signs/starshine-hot-ir-strategy.md
  - ../../../../src/passes/pick_load_signs.mbt
  - ../../../../src/passes/pick_load_signs_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/pick-load-signs/index.md
  - ../../binaryen/passes/pick-load-signs/parity.md
  - ./0532-2026-05-06-pick-load-signs-direct-revalidation.md
---

# `pick-load-signs` O4z audit

## Question

Can the active `[O4Z-AUDIT-PLS]` release-gating pass audit be closed without reopening `pick-load-signs` semantics?

Scope from `agent-todo.md` on 2026-06-03:

- signed/unsigned narrow-load opcode choice
- extension-use recognition
- `local.tee` and multi-use negatives
- imported/defined memory coverage
- idempotence
- direct pass compare evidence
- `-O4z` slot evidence and pass-local timing

## Code and test audit

Reviewed active owner surfaces:

- `src/passes/pick_load_signs.mbt`
- `src/passes/pick_load_signs_test.mbt`
- `src/passes/pass_manager.mbt`
- `docs/wiki/binaryen/passes/pick-load-signs/`

The implementation remains the same narrow HOT/use-def shape:

- candidates are exact `local.set(load ...)` writes
- `local.tee` producers remain excluded
- every `local.get` use must classify as recognized signed or unsigned extension evidence
- unknown or mixed-width evidence blocks the rewrite
- a module-level no-memory gate and a function-level raw candidate scan protect the pass from unnecessary HOT lift

No semantic bug was found in the implementation during this audit.

Focused coverage was refreshed in `src/passes/pick_load_signs_test.mbt`:

- added an i64 signed positive: `i64.load32_u` becomes `i64.load32_s` when the only use is `i64.extend32_s`
- added an i64 unsigned positive: `i64.load16_s` becomes `i64.load16_u` when the only use is a `0xffff` `i64.and` mask
- corrected the imported-memory test fixture to use an actual imported memory instead of another defined-memory module

These tests close the stale documentation caveat that the broader local i64 surface was source-confirmed but not directly isolated by focused tests.

## Direct compare evidence

Smoke command run first:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass pick-load-signs --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-pick-load-signs-audit-1000
```

Result:

- compared cases: `998 / 1000`
- normalized matches: `998`
- compare-normalized matches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `2`
- mismatches: `0`
- command-failure class: `binaryen-rec-group-zero` (`2`)

Closeout command:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass pick-load-signs --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-pick-load-signs-audit-10000
```

Result:

- compared cases: `9975 / 10000`
- normalized matches: `9975`
- compare-normalized matches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `25`
- mismatches: `0`
- command-failure classes:
  - `binaryen-rec-group-zero`: `22`
  - `binaryen-bad-section-size`: `1`
  - `binaryen-table-index-out-of-range`: `1`
  - `binaryen-invalid-tag-index`: `1`

Agent classification: no semantic mismatch family was present. The command failures are Binaryen/tool parser or canonicalization failures and are not Starshine semantic mismatches.

## O4z slot and timing evidence

The saved generated-artifact `-O4z` pass-by-pass audit remains the current ordered-slot evidence:

- artifact: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`
- audit row: `15`
- Binaryen slot: `18`
- pass: `pick-load-signs`
- exact wasm equality: yes
- meaningful equality: yes
- Starshine validity: yes
- Binaryen validity: yes
- Starshine whole-command wall time: `650.954 ms`
- Binaryen whole-command wall time: `229.302 ms`
- Starshine pass-local time: `7.492 ms`
- Binaryen pass-local time: `24.574 ms`

Pass-local timing is acceptable for this slice: Starshine is faster than Binaryen for the recorded slot. The larger whole-command wall-time gap belongs to the cross-pass `[WALL]001` bucket rather than this pass.

## Moon evidence

Focused package test after coverage additions:

```sh
moon test src/passes
```

Result: `1483` tests passed, `0` failed.

## Conclusion

`[O4Z-AUDIT-PLS]` is closed for v0.1.0.

No behavior change was required. The audit added missing coverage for the local i64 divergence and fixed the imported-memory fixture, refreshed direct compare through the standard `10000` requested count, and confirmed the saved O4z slot is exact/meaningful-equal with pass-local Starshine faster than Binaryen.

Keep the broader i64 support documented as a deliberate local surface. Reopen only if future strict-upstream parity requires removing that local breadth, or if a new semantic mismatch, validation failure, or pass-local timing regression appears.
