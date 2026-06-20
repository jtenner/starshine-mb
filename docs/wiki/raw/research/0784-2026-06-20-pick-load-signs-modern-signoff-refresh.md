---
kind: research
status: current
last_reviewed: 2026-06-20
sources:
  - ../../binaryen/passes/pick-load-signs/index.md
  - ../../binaryen/passes/pick-load-signs/parity.md
  - ../../binaryen/passes/pick-load-signs/fuzzing.md
  - ../../binaryen/passes/pick-load-signs/binaryen-strategy.md
  - ../../binaryen/passes/pick-load-signs/starshine-strategy.md
  - ../../binaryen/passes/pick-load-signs/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/pick-load-signs/wat-shapes.md
  - ../../binaryen/passes/pick-load-signs/implementation-structure-and-tests.md
  - ./0702-2026-06-03-pick-load-signs-o4z-audit.md
  - ../../../../src/passes/pick_load_signs.mbt
  - ../../../../src/passes/pick_load_signs_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/pick-load-signs/index.md
  - ../../binaryen/passes/pick-load-signs/parity.md
  - ../../binaryen/passes/pick-load-signs/fuzzing.md
  - ./0702-2026-06-03-pick-load-signs-o4z-audit.md
---

# `pick-load-signs` modern signoff refresh

## Question

Does `pick-load-signs` remain release-closed under the current pass-audit/signoff standard, after the 2026-06-03 audit closed `[O4Z-AUDIT-PLS]` under the older `10000`-case direct lane standard?

## Files reviewed

Required docs and skills reviewed for this slice:

- `docs/README.md`
- `.pi/skills/starshine-pass-implementation/SKILL.md`
- `.pi/skills/commit/SKILL.md`
- `agent-todo.md`
- `docs/wiki/binaryen/passes/pick-load-signs/index.md`
- `docs/wiki/binaryen/passes/pick-load-signs/parity.md`
- `docs/wiki/binaryen/passes/pick-load-signs/fuzzing.md`
- `docs/wiki/binaryen/passes/pick-load-signs/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/pick-load-signs/starshine-strategy.md`
- `docs/wiki/binaryen/passes/pick-load-signs/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/pick-load-signs/wat-shapes.md`
- `docs/wiki/binaryen/passes/pick-load-signs/implementation-structure-and-tests.md`
- `docs/wiki/raw/research/0702-2026-06-03-pick-load-signs-o4z-audit.md`

Code/test surfaces reviewed enough to verify current wiring and focused behavior ownership:

- `src/passes/pick_load_signs.mbt`
- `src/passes/pick_load_signs_test.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Findings

No new semantic behavior gap was found in the inspected `pick-load-signs` implementation or focused tests.

The standing 2026-06-03 behavior evidence is still meaningful:

- focused tests cover the narrow local producer/use contract, local i64 Starshine extension surface, no-memory skip, imported memory, idempotence, unknown-use and `local.tee` bailouts
- direct compare `.tmp/pass-fuzz-pick-load-signs-audit-10000` compared `9975 / 10000` with `0` mismatches and `25` Binaryen/tool command failures
- saved generated O4z slot evidence for Binaryen slot `18` / audit row `15` was exact/meaningful-equal and pass-local Starshine was faster than Binaryen

However, the current pass skill now defines final pass closeout with a stronger four-lane matrix:

1. regular GenValid `100000` cases at seed `0x5eed`
2. explicit `--wasm-smith` `10000` cases at seed `0x5eed`
3. a pass-specific GenValid profile `10000` cases at seed `0x5eed`
4. a random all-profiles / broad named GenValid lane `10000` cases at seed `0x5555`

The existing PLS closeout predates that standard and `docs/wiki/binaryen/passes/pick-load-signs/fuzzing.md` explicitly says that no dedicated GenValid profile is documented for this pass yet. Therefore PLS should not be represented as fully closed under the current final-closeout standard. It remains behavior-closed under the older 2026-06-03 evidence, but release-gating status is reopened for modern evidence/profile work.

## Commands and results

Discovery commands run:

```sh
git status --short
```

Result: clean before this docs/backlog update.

```sh
bun scripts/pass-fuzz-compare.ts --list-passes | grep pick-load-signs
```

Result: printed `pick-load-signs`, confirming the canonical direct pass is still supported by the compare harness.

```sh
test -x target/native/release/build/cmd/cmd.exe && echo native-bin-present || echo native-bin-missing
```

Result: `native-bin-missing`, so no current compare lane was run in this docs-only refresh slice. A future closeout must first run `moon build --target native --release src/cmd`.

No Moon tests or fuzz comparisons were run in this slice because no code or executable test behavior changed. This was a docs/backlog status refresh.

## Updated status

`[O4Z-AUDIT-PLS]` is reopened as an evidence/profile slice, not because of a known semantic bug.

Required follow-up before reclosing under the current standard:

- add a PLS-specific GenValid profile that deliberately emits candidate narrow-load/local-use shapes for the signed, unsigned, mixed/unknown-use, `local.tee`, no-memory/imported-memory, and local i64 Starshine watchpoint families
- add focused generator tests proving the profile resolves, emits validating modules, and actually exercises pass-owned opportunities/boundaries
- document the profile in `docs/wiki/binaryen/passes/pick-load-signs/fuzzing.md`
- rebuild the native CLI and run the full four-lane final closeout matrix
- report selected-profile counts and cache counters where present
- update the PLS dossier and remove or close the backlog entry only if all lanes are green or any remaining differences are narrow, classified, and explicitly accepted

## Reopening criteria after a future close

After modern closeout, reopen PLS only for a new semantic mismatch, Starshine validation failure attributable to this pass, a pass-specific GenValid profile regression, a broad unclassified output-shape family without measured/accepted Starshine benefit, a Starshine-specific command-failure class after oracle/tool failures are excluded, a pass-local timing regression below the current performance rule, or upstream Binaryen source/lit drift beyond the current narrow producer/use contract.
