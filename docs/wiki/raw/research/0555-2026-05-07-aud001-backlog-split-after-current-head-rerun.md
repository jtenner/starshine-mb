---
kind: research
status: current
last_reviewed: 2026-05-07
sources:
  - ../../../../agent-todo.md
  - ./0513-2026-05-06-starshine-pass-audit.md
  - ./0548-2026-05-07-remove-unused-brs-mixed-rerun-and-local-normalization-classification.md
  - ../../../../src/passes/memory_packing.mbt
  - ../../../../src/passes/precompute.mbt
  - ../../../../src/passes/remove_unused_brs.mbt
  - ../../../../src/passes/ssa_nomerge.mbt
related:
  - ./0513-2026-05-06-starshine-pass-audit.md
  - ./0548-2026-05-07-remove-unused-brs-mixed-rerun-and-local-normalization-classification.md
  - ../../binaryen/passes/memory-packing/parity.md
  - ../../binaryen/passes/remove-unused-brs/parity.md
  - ../../binaryen/passes/precompute/index.md
---

# Close `[AUD]001` by splitting focused current-head follow-up tasks

## Question

Can the umbrella `[AUD]001 - Fresh Direct-Pass Mismatch Triage` backlog item be closed now that the current-head mismatch families have been rerun and classified more precisely than the original 2026-05-06 smoke audit?

## Method

Reran the four still-red direct pass lanes from the 2026-05-06 audit with the same smoke seed and fresh out dirs:

- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0xA11D --max-failures 5 --pass memory-packing --out-dir .tmp/recheck-memory-packing`
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0xA11D --max-failures 5 --pass precompute --out-dir .tmp/recheck-precompute`
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0xA11D --max-failures 5 --pass remove-unused-brs --out-dir .tmp/recheck-remove-unused-brs`
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0xA11D --max-failures 5 --pass ssa-nomerge --out-dir .tmp/recheck-ssa-nomerge`

Then diffed the saved `binaryen.wat` vs `starshine.wat` files in each failure dir to check whether the active mismatch family was still what the original audit said.

## Results

### `memory-packing`

Smoke rerun:

- compared cases: `100 / 100`
- normalized matches: `96`
- mismatches: `4`
- command failures: `0`

Current-head family is narrower than the original one-line audit summary suggested:

- the mismatches are all **empty-segment / dead-passive-segment normalization drift**
- Binaryen emits only the kept active payload segments and may retain an empty active segment at the canonical offset
- Starshine currently preserves extra empty segments and preserved passive data segments that Binaryen drops in these cases

Representative saved dirs:

- `case-000025-wasm-smith`: Binaryen drops the passive `"\0b"` segment and keeps only the empty active segment at offset `0`; Starshine keeps both
- `case-000069-wasm-smith`, `case-000093-wasm-smith`, `case-000095-wasm-smith`: Starshine emits extra empty segments alongside the rewritten active payloads

### `precompute`

Smoke rerun:

- compared cases: `10 / 100`
- normalized matches: `5`
- mismatches: `5`
- command failures: `0`

The active family is more precise than the original `dead block / br_table cleanup drift` wording:

- the current failures are **dead-root nop-normalization drift before trailing `unreachable`**
- Binaryen keeps long root-level `nop` padding after folding away dead exact roots
- Starshine trims that root residue more aggressively and collapses the same dead prefix to a self-targeting `block` / `br_table` shell before the final `unreachable`

This means the current direct mismatch is not “precompute missed a semantic cleanup” so much as “precompute currently over-normalizes the dead root compared with Binaryen.”

### `remove-unused-brs`

Smoke rerun:

- compared cases: `24 / 100`
- normalized matches: `19`
- mismatches: `5`
- command failures: `0`

The current-head family is **not** the original 2026-05-06 `br_table` wrapper-cleanup drift anymore.
Instead, the fresh saved dirs now match the classification already recorded in `0548-2026-05-07-remove-unused-brs-mixed-rerun-and-local-normalization-classification.md`:

- the remaining diffs are local-declaration count/type/order drift only
- the inspected current-head failure hunks do not show instruction-body mismatches
- this family now overlaps strongly with the remaining `ssa-nomerge` normalization work rather than with the older `br_table` cleanup slice

Representative saved dirs:

- `case-000004-gen-valid`
- `case-000006-gen-valid`
- `case-000010-gen-valid`
- `case-000022-gen-valid`
- `case-000024-gen-valid`

### `ssa-nomerge`

Smoke rerun:

- compared cases: `10 / 100`
- normalized matches: `5`
- mismatches: `5`
- command failures: `0`

The family remains what the original audit called out, but the rerun makes the boundary sharper:

- the current failures are **temp-local declaration shaping drift only**
- the inspected hunks change local declaration count/type/order without changing the instruction bodies in the same saved functions
- this is the same broad normalization surface that now appears in current-head `remove-unused-brs` reruns

## Conclusion

Yes. `[AUD]001` can be closed **as a triage umbrella**.

What it was meant to do is now complete:

- the red direct-pass lanes were rerun on current head
- the saved failure families were reclassified from concrete current artifacts
- stale wording from the original audit can now be corrected
- the remaining work is pass-specific implementation work, not one more round of shared triage

The right follow-up is to replace the umbrella item with focused backlog slices:

- a dedicated `memory-packing` empty-segment / dead-passive normalization task
- an updated `precompute` task that explicitly names the dead-root nop-normalization family before the broader runtime / representation work
- a dedicated `remove-unused-brs` local-declaration normalization task
- a dedicated `ssa-nomerge` temp-local declaration normalization task

## Why this closes triage but not the bugs

No new focused tests landed in this change because the current remaining failures are representation-only normalization families whose fix strategy is still a live design choice per pass:

- preserve Starshine's current normalization and document an approved divergence, or
- match Binaryen's declaration / empty-segment / nop-padding shapes directly

That decision belongs in the focused implementation slices, not in the umbrella triage item.

So the durable output of this work is **backlog decomposition plus corrected classification**, not a pretend green status.
