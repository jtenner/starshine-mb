---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ./0775-2026-06-20-heap-store-optimization-recursive-handoff-plan.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../../agent-todo.md
---

# `heap-store-optimization` HSO-B direct baseline

Question: what does a fresh direct `heap-store-optimization` compare against the local Binaryen `version_130` oracle show before behavior-changing HSO implementation work resumes?

## Answer

The direct baseline is normalized-green for the 1000-case smoke lane:

- requested: `1000`
- compared: `998`
- normalized matches: `998`
- cleanup-normalized matches: `0`
- mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `2`
- command-failure class: `binaryen-rec-group-zero=2`
- cache: wasm-smith `500` hits / `0` misses; Binaryen `1` hit / `997` misses; Binaryen failures `0` hits / `2` misses
- generator mix: wasm-smith `498`, GenValid `500` with selected profile `binaryen-oracle-portable=500`

Agent classification: the 1000-case direct smoke found no behavior mismatch and no output drift requiring classification. The two command failures are Binaryen/oracle boundaries (`binaryen-rec-group-zero`), not Starshine failures. This is baseline evidence only; it does **not** close the HSO audit because the `version_130` source refresh still lists source-backed behavior families that require focused tests and/or implementation, especially directional `orderedBefore(...)` movement legality.

## Commands and artifacts

Build command used first:

```sh
moon build --target native --release src/cmd
```

Result: passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.

The first compare attempt used the documented target path before a local `target/` build existed:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-hso-b-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures
```

Result: `0/1000` compared, `1000` `starshine-command-failed` entries, all with `ENOENT` for `target/native/release/build/cmd/cmd.exe`. This is a local artifact-path setup issue, not HSO behavior evidence.

A native target build was then materialized under `target/`:

```sh
moon build --target native --release --target-dir target src/cmd
ls -l target/native/release/build/cmd/cmd.exe
```

Result: build passed with the same existing unused-function warnings; `target/native/release/build/cmd/cmd.exe` existed and was executable.

Successful direct baseline:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-hso-b-1000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures
```

Result artifact: `.tmp/pass-fuzz-heap-store-optimization-hso-b-1000-rerun/result.json`.

## Follow-up

Continue HSO-B/HSO-D with focused source-backed tests that distinguish Binaryen `version_130` directional movement checks from Starshine's current broad `hso_mask_invalidates(...)`-style predicates:

1. Descriptor operand barrier: `descEffects.orderedBefore(setValueEffects)`.
2. Later constructor operand barrier: `operandEffects.orderedBefore(setValueEffects)`.
3. Shallow constructor/allocation barrier: `structNewEffects.orderedBefore(setValueEffects)`.
4. Swap barrier: `firstEffects.orderedBefore(secondEffects)`.

If focused tests reveal Starshine overblocking, implement the directional behavior test-first. If they reveal underblocking or semantic risk, preserve safety and document the narrower Binaryen difference until the exact HOT effect API can match `orderedBefore(...)`.

Final closeout still needs the wider standard/final compare lanes and early/late O4z slot or neighborhood evidence from the recursive-handoff completion criteria.
