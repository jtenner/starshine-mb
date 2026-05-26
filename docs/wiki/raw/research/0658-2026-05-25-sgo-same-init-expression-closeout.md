# SGO same-init expression equivalence closeout

## Scope

Research/bookkeeping-only `[SGO]003J` closeout for same-as-init expression-equivalence broadening in `simplify-globals-optimizing`.

This slice decides whether the current backlog should keep an open item for broadening removable same-init writes beyond the already-supported direct literal / `ref.null` / `ref.func` and source-backed guardrail shapes.

## Sources checked

- `docs/wiki/raw/research/0574-2026-05-23-sgo-next-breadth-probe-inventory.md`
- `docs/wiki/raw/research/0576-2026-05-23-sgo-same-init-runtime-guardrails.md`
- `docs/wiki/raw/research/0577-2026-05-23-sgo-official-lit-breadth-inventory.md`
- `docs/wiki/raw/research/0594-2026-05-23-sgo-non-init-same-init-lit-regression.md`
- `docs/wiki/raw/research/0595-2026-05-23-sgo-non-init-changed-write-negative-lit.md`
- `docs/wiki/raw/research/0596-2026-05-23-sgo-non-init-imported-initializer-lit.md`
- `docs/wiki/raw/research/0633-2026-05-25-sgo-next-slice-probe-inventory-refresh.md`
- Active backlog entry in `agent-todo.md`.

## Audit

The existing evidence is conservative rather than implementation-positive:

- 0574 found that a block-wrapped same-init value with a real later read was a Binaryen negative, even when the value looked constant after other simplification.
- 0574 also found that alias-initializer plus direct literal same-init write behavior is one-run/repeated-run sensitive and should not be treated as a generic removable same-init expression.
- 0576 pinned those expression-looking negatives locally so future broadening does not accidentally erase them.
- 0577 concluded that the official non-init lit coverage supports provenance caution rather than broad expression equivalence.
- 0594 pinned the parser-supported direct scalar same-init positive from the official non-init lit file.
- 0595 pinned changed literal / unknown value writes as negatives.
- 0596 pinned imported-initializer provenance as a negative.
- 0633 explicitly ranked `[SGO]003J` as a poor next implementation slice because prior probes found block-wrapped/read-present and imported-provenance negatives, requiring a fresh source-backed positive before coding.

Together, these notes cover the useful direct-literal positive and the key negatives that would make broad expression equivalence risky.

## Decision

Close `[SGO]003J` as conservative/research-only.

Do not broaden same-init removable-write matching inside `[SGO]003` without a new explicit Binaryen-positive expression grammar.

The current allowed surface remains the already-landed direct literal / `ref.null` / `ref.func` and source-backed guardrail shapes. The following remain out of scope:

- generic expression equivalence;
- block-wrapped same-init values with real reads;
- alias-init one-shot removal without exact repeated-run evidence;
- imported-provenance initializers;
- object-identity-sensitive GC expressions;
- trapping or effectful expressions.

A future slice may reopen this area only if it starts from an exact Binaryen-positive fixture, separates one-run from repeated-run behavior, adds paired provenance/effect/trapping/object-identity negatives, and runs direct SGO fuzz for any behavior change.

## Validation

- `git diff --check` — passed.

No Moon tests or direct SGO fuzz were required for this closeout because no code, matcher logic, parser behavior, registry, preset, or normative pass docs changed.

## Status

`[SGO]003J` is complete as a conservative/research-only closeout. `[SGO]003` remains active/partial; this is not a full Binaryen `SimplifyGlobals.cpp` parity claim.
