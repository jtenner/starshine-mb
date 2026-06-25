# 0903 - code-pushing post-IIT actionability audit

Date: 2026-06-25

## Question

After implementing Starshine's distinct Binaryen-compatible `code-pushing` `--ignore-implicit-traps` / `-iit` support in [`0902`](0902-2026-06-25-code-pushing-ignore-implicit-traps-implementation.md), is any remaining source-backed or generated-mismatch-backed `code-pushing` replacement/widening work currently actionable?

## Answer

No. The recursive follow-up goal is complete for now: the only replacement-follow-up item that was superseded by implementation status after the old [`0901`](0901-2026-06-25-code-pushing-binrep-followup-closeout.md) closeout was the `--ignore-implicit-traps` / `-iit` boundary from [`0897`](0897-2026-06-25-code-pushing-ignore-implicit-traps-boundary.md), and `0902` implemented that as a new source-backed widening slice.

The remaining accepted boundaries are still not actionable without prerequisite representation/API work, a reduced Binaryen-positive probe beyond the existing evidence, or a generated mismatch:

- Branch/switch: [`0898`](0898-2026-06-25-code-pushing-branch-switch-boundary-closeout.md) remains closed. Existing branch-value `br_if` positives were already implemented, and the probed `br_table` / switch shapes remain Binaryen-stationary. Reopen only for a new Binaryen-positive switch probe, source/lit drift, or a generated mismatch attributable to missing switch movement.
- Intrinsic no-effects calls: [`0899`](0899-2026-06-25-code-pushing-intrinsic-no-effects-boundary.md) remains blocked by missing pass-visible import module/name metadata for `binaryen-intrinsics/call.without.effects`. Do not implement a type/arity heuristic.
- GC/ref: [`0900`](0900-2026-06-25-code-pushing-gc-ref-boundary.md) remains blocked by local type weakening/refinalization for `ref-into-if` and by broader official GC fixture representation. Existing `RefFunc`, `br_on_*`, and atomics/GC `struct.get` families remain covered.

No new behavior change was made in this audit. The only durable follow-up was documentation hygiene: update stale wiki wording that still described `--ignore-implicit-traps` as a current non-goal/boundary instead of a post-`0902` implemented option.

## Evidence reviewed

- Direct-pass closeout: [`0892`](0892-2026-06-25-code-pushing-final-closeout.md) remains valid for the old v0.1.0 release-gating audit.
- Replacement closeout: [`0901`](0901-2026-06-25-code-pushing-binrep-followup-closeout.md) remains valid for the old `[O4Z-AUDIT-CP-BINREP]` stop condition and explicitly points to `0902` as the later implementation slice.
- Implementation slice: [`0902`](0902-2026-06-25-code-pushing-ignore-implicit-traps-implementation.md) confirms `ignore_implicit_traps` is distinct from `traps_never_happen`, implements the lit-derived memory-load movement only under `-iit`, and preserves default/TNH/IIT separation.
- Remaining boundary notes: [`0898`](0898-2026-06-25-code-pushing-branch-switch-boundary-closeout.md), [`0899`](0899-2026-06-25-code-pushing-intrinsic-no-effects-boundary.md), and [`0900`](0900-2026-06-25-code-pushing-gc-ref-boundary.md).
- Living pages under `docs/wiki/binaryen/passes/code-pushing/` and the `[O4Z-AUDIT-CP]` / `[O4Z-AUDIT-CP-BINREP]` entries in `agent-todo.md`.

## Validation

Docs/status audit only; no behavior, generated profile, public API, or executable example changed. No Moon tests were required.

Source/link review plus repo grep found two stale living-page statements that still framed `--ignore-implicit-traps` as a current Starshine boundary/non-goal; those were corrected to point at `0902` while preserving `0897` as historical evidence.

## Reopening criteria

Start a new source-backed `code-pushing` slice only if one of the existing closeout criteria fires:

- a reduced Binaryen v130/current-main probe shows a positive movement Starshine misses;
- a protected stationary boundary starts moving upstream;
- direct compare finds an unexplained raw mismatch beyond documented `local-cleanup-debris` or Binaryen/tool failures;
- Starshine emits invalid wasm after `code-pushing`;
- pass-visible import identity, local refinalization, or broader GC/switch representation makes an accepted boundary implementable;
- public preset/neighborhood evidence requires ordered `code-pushing` work.
