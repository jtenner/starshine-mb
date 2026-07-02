---
kind: research
status: current
last_reviewed: 2026-07-02
sources:
  - ../binaryen/2026-07-02-reorder-locals-version-130-source-refresh.md
  - ../../binaryen/passes/reorder-locals/index.md
  - ../../binaryen/passes/reorder-locals/binaryen-strategy.md
  - ../../binaryen/passes/reorder-locals/parity.md
  - ../../binaryen/passes/reorder-locals/fuzzing.md
  - ../../binaryen/passes/reorder-locals/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/reorder_locals.mbt
  - ../../../../src/passes/reorder_locals_test.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/release-horizon-and-oracles.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
---

# `reorder-locals` `version_130` source inventory

## Question

For `[O4Z-AUDIT-RL]`, does the current local Binaryen oracle (`wasm-opt version 130 (version_130)`) change the `reorder-locals` transform-family inventory or Starshine gap map?

## Method

- Confirmed local oracle with `wasm-opt --version`.
- Downloaded official `version_130` primary sources into `.tmp/rl-v130/` for review:
  - `src/passes/ReorderLocals.cpp`
  - `src/passes/pass.cpp`
  - `test/passes/reorder-locals.wast`
  - `test/passes/reorder-locals.txt`
  - `test/passes/reorder-locals_print_roundtrip.wast`
  - `test/passes/reorder-locals_print_roundtrip.txt`
- Downloaded the same `version_129` owner/lit files into `.tmp/rl-v129/` and diffed them against `version_130`.
- Re-read the Starshine implementation, test, dispatcher, preset, CLI, backlog, and living dossier surfaces relevant to the pass.

## Findings

### No owner/lit drift from `version_129` to `version_130`

The official `version_130` pass owner and dedicated lit surfaces are byte-identical to the previously reviewed `version_129` copies:

- `ReorderLocals.cpp`
- `reorder-locals.wast`
- `reorder-locals.txt`
- `reorder-locals_print_roundtrip.wast`
- `reorder-locals_print_roundtrip.txt`

The old dossier's algorithm prose remains semantically accurate, but new O4Z audit claims should cite the `version_130` refresh rather than relying only on the older `version_129` freshness note.

### Transform families to keep audited

The complete direct-pass family list for current audit purposes is:

1. params-only no-op / parameter stability;
2. access counting for `local.get`, `local.set`, and Binaryen tee-as-`LocalSet` traffic;
3. body-local sorting by descending count;
4. nonzero count tie-break by first observed use;
5. zero-count tie old-index order plus suffix truncation;
6. body-local declaration rebuild without changing local types;
7. local-user reindexing throughout nested bodies;
8. local-name map repair and declaration-order roundtrip visibility;
9. no non-nullable-local fixups and no CFG/dataflow/liveness dependencies;
10. scheduler repetition in three no-DWARF local-cleanup slots;
11. multivalue scratch/local writer drift as an out-of-scope writer-boundary family unless fresh evidence ties it to `ReorderLocals.cpp`.

### Starshine current state

- `src/passes/reorder_locals.mbt` implements the direct algorithm as a module pass, including grouped local-run rebuild, explicit `LocalTee` handling, name-section repair, and raw name payload invalidation.
- `src/passes/reorder_locals_test.mbt` has focused coverage for parameter stability, access count + first use, write-only survival, zero-access drops, tee counting, nested rewrite, name-section repair, and a Binaryen-materialized carrier fixture.
- `src/cmd/cmd_wbtest.mbt` has explicit CLI/binary output coverage for `--reorder-locals`.
- `src/passes/optimize.mbt` and `src/passes/optimize_test.mbt` currently schedule exactly one public preset slot in the tuple/no-structure cleanup lane; the second and third Binaryen-style slots remain scheduler/audit work.
- `docs/wiki/binaryen/passes/reorder-locals/fuzzing.md` still lacks a dedicated GenValid profile. That is now the highest-leverage next implementation slice because the direct algorithm inventory itself did not drift.

## Current gap classification

| Area | Classification | Rationale |
| --- | --- | --- |
| Direct algorithm families | no new `version_130` gap found | Owner/lit files match `version_129`; local focused tests map to every direct owner-family. |
| Dedicated GenValid coverage | active gap | No `reorder-locals` profile exists yet; ordinary GenValid evidence does not prove pass-owned trigger density. |
| Current full signoff | active gap | Existing 2026-05-06 compare was 10k regular GenValid only; final O4Z closeout needs the repo-standard four-lane matrix with native Starshine binary. |
| Extra scheduler slots | active gap / scheduler work | Binaryen has three no-DWARF slots; Starshine currently claims one public slot with tests. Extra slots need ordered-neighborhood evidence, not just direct-pass confidence. |
| Multivalue scratch-local drift | standing boundary decision | Still sourced to Binaryen writer/IR-builder behavior, not `ReorderLocals.cpp`; do not reopen without fresh direct evidence. |
| TypeIdx/RecIdx invariant comment | active documentation/code hygiene gap | `[AUDIT006-E]` still asks for an inline comment near the `reorder-locals` `RecIdx` abort. |

## Next recommended slices

1. Add a dedicated `reorder-locals` GenValid aggregate profile with singleton leaves for hot-count/first-use sorting, zero-count truncation, and name/local-declaration stress where practical; prove profile resolution and manifest selected-profile metadata red-first.
2. Add the `[AUDIT006-E]` inline invariant comment near `src/passes/reorder_locals.mbt`'s `RecIdx` abort and update the relevant invariant docs/backlog.
3. Build the native CLI and run short profile-backed compare smoke before expanding to the final four-lane signoff matrix.
