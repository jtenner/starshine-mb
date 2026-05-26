# SGO startup and single-use initializer closeout

## Scope

Research/bookkeeping-only `[SGO]003K` closeout for startup/global-initializer single-use and copy-chain follow-ups in `simplify-globals-optimizing`.

This slice decides whether `[SGO]003K` still needs an open behavior item after the official `simplify-globals-single_use.wast` source-alignment guardrails landed.

## Sources checked

- Inventory/ranking note: `docs/wiki/raw/research/0579-2026-05-23-sgo-remaining-lit-inventory.md`.
- Positive startup/global-initializer guardrail notes:
  - `docs/wiki/raw/research/0584-2026-05-23-sgo-single-use-gc-lit-regression.md`
  - `docs/wiki/raw/research/0585-2026-05-23-sgo-nested-single-use-gc-lit-regression.md`
  - `docs/wiki/raw/research/0586-2026-05-23-sgo-multiple-single-use-gc-lit-regression.md`
  - `docs/wiki/raw/research/0587-2026-05-23-sgo-multi-input-single-use-gc-lit-regression.md`
  - `docs/wiki/raw/research/0588-2026-05-23-sgo-single-use-chain-lit-regression.md`
- Negative guardrail note: `docs/wiki/raw/research/0589-2026-05-23-sgo-single-use-negative-lit-guardrails.md`.
- Active backlog entry in `agent-todo.md`.

## Audit

The parser-supported positive startup/global-initializer shapes from the official single-use lit family have already been pinned locally:

- one source global folded into a later initializer;
- nested single-use initializer chains;
- multiple independent single-use folds in one module;
- multiple inputs into one initializer where all sources are proven local and single-use;
- copy-chain startup/global-initializer folding.

The compact official negatives have also been pinned:

- second global use preserves the source `global.get`;
- function-code second use preserves the startup initializer and function read;
- imported source preserves the later initializer `global.get`;
- function-code-only use remains out of startup-only folding.

The landed guardrails also preserved the important scheduling boundary: startup-only initializer rewrites do not mark functions for nested cleanup.

## Decision

Close `[SGO]003K` now.

Rationale:

- the known parser-supported official single-use/startup initializer positives are already covered by 0584 through 0588;
- the paired official compact negatives are covered by 0589;
- keeping `[SGO]003K` open would turn it into a vague startup bucket rather than a concrete source-backed slice;
- remaining GC/refinalization-sensitive work belongs to the `[SGO]003L` prerequisite path, not this startup-only item;
- runtime/code-body propagation belongs to the runtime/dataflow slices, not startup initializer follow-ups.

Future startup/global-initializer discoveries should be filed as new explicit child slices with a source fixture, paired negatives, and direct SGO validation if behavior changes.

## Validation

- `git diff --check` — passed.

No Moon tests or direct SGO fuzz were required for this closeout because no code, matcher logic, parser behavior, registry, preset, or normative pass docs changed.

## Status

`[SGO]003K` is complete. `[SGO]003` remains active/partial; this is not a full Binaryen `SimplifyGlobals.cpp` parity claim.
