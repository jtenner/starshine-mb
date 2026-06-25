# 0898 - code-pushing branch and switch boundary closeout

Date: 2026-06-25

## Question

Can Starshine close `[CP-BINREP-007]`, the low-priority follow-up for multi-value `br_if` and `br_table` / switch movement, without implementing new behavior?

## Answer

Yes, as a narrow evidence-backed boundary. The replacement-oriented research did not find a reduced Binaryen v130 positive switch / `br_table` movement gap that Starshine should implement now. The useful branch-value `br_if` positives discovered during the old direct-pass audit are already implemented and documented in `0824` and `0825`; the remaining switch probes are Binaryen-stationary and protected by focused boundary tests.

This closes `[CP-BINREP-007]` as **no current implementation work without a new Binaryen-positive case or generated mismatch**, not as broad proof that every future `br_if` / `br_table` surface is stationary.

## Evidence inventory

Existing source-backed notes:

- [`0824`](0824-2026-06-24-code-pushing-branch-value-br-if.md): implemented the single-set value-block-target `br_if` movement family. Binaryen moved a pure SFA set after a value-carrying `br_if` when the branch payload and condition did not read the moved local; Starshine added red-first focused positive and payload-read boundary coverage.
- [`0825`](0825-2026-06-24-code-pushing-branch-value-multiset-br-if.md): implemented the adjacent local-independent multi-set value-block-target `br_if` movement family. Binaryen moved both sets after the dropped value-carrying `br_if` and preserved source order; Starshine added red-first focused order coverage. The targeted `code-pushing-br-if-value` profile remains outside `code-pushing-all` because of a separate value-`br_if` lowering representation/size gap, not because code-pushing movement is missing.
- [`0822`](0822-2026-06-21-code-pushing-br-table-boundary.md): Binaryen kept single and adjacent multi-set no-branch-value `br_table` windows stationary. Starshine added intentionally fail-closed boundary tests for those switch push points.
- [`0843`](0843-2026-06-25-code-pushing-value-br-table-boundary.md): Binaryen kept a pure SFA set before one value-carrying result-block `br_table`. Starshine added an intentionally unsupported/Binaryen-stationary boundary test.
- [`0848`](0848-2026-06-25-code-pushing-multilabel-br-table-boundary.md): Binaryen kept a pure SFA set before a multi-target nested-block `br_table` where one target fell through to a later suffix read and another exited the enclosing block. Starshine added an intentionally unsupported/Binaryen-stationary boundary test.

Together these notes cover the known CP-BINREP-007 surface: branch-value `br_if` positives were already implemented, while the probed switch / `br_table` shapes are stationary under local `wasm-opt version 130 (version_130)`.

## Decision

Mark `[CP-BINREP-007]` complete as a boundary closeout:

- no new code-pushing behavior landed in this slice;
- no new red/green TDD test was added because this is not a newly implemented behavior family;
- existing focused tests already protect the known Binaryen-stationary switch boundaries;
- future branch/switch work requires a reduced Binaryen-positive case, direct-compare mismatch, or source/lit refresh showing behavior beyond the current evidence.

## Reopening criteria

Reopen this boundary if:

- a reduced Binaryen v130/current-main probe shows a positive `br_table` / switch movement Starshine can represent safely;
- a generated direct-compare run exposes a non-normalized mismatch attributable to missing branch/switch movement rather than known value-`br_if` lowering representation drift or local cleanup debris;
- Binaryen lit/source changes add a switch movement contract not covered by the stationary probes;
- Starshine starts moving a protected stationary `br_table` shape without a source-backed implementation and focused tests.

## Validation

Docs/status closeout only. No Moon tests were required for this slice because no behavior, generated profile, or API changed. The supporting focused test and local Binaryen probe evidence lives in `0822`, `0824`, `0825`, `0843`, and `0848`.
