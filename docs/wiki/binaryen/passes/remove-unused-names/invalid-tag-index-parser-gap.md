---
kind: comparison
status: working
last_reviewed: 2026-04-09
sources:
  - ../../../../0072-2026-03-28-run-invalid-tag-index-binaryen-parser-gap.md
related:
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../scripts/test/pass-fuzz-compare-command.ts
---

# Binaryen `invalid tag index` Parser Gap

## Durable Conclusions

- For `remove-unused-names` compare runs, the `parse exception: invalid tag index` family is an oracle parser failure, not a Starshine semantic mismatch.
- Do not count this family as a pass mismatch unless Binaryen can parse the saved case and a normalized output difference still remains.
- The compare harness should keep this family visible as its own command-failure class instead of collapsing it into generic command noise.

## Current In-Tree Status

- The harness classification lives in [`../../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) as `binaryen-invalid-tag-index`.
- Regression coverage for the classification and replay behavior lives in [`../../../../../scripts/test/pass-fuzz-compare-command.ts`](../../../../../scripts/test/pass-fuzz-compare-command.ts).
- Command-failure artifacts now persist printed WAT beside the saved wasm so the reduced case can be inspected without rerunning `wasm-tools print`.

## Practical Rule

- When this family appears, keep it in the Binaryen parser-gap bucket.
- Use failure-class replay to inspect the family again instead of treating it as proof of Starshine pass divergence.
- Re-check newer Binaryen builds before promoting any saved case into a semantic parity blocker or upstream reduction effort.

## Sources

- Numbered research doc: [`../../../../0072-2026-03-28-run-invalid-tag-index-binaryen-parser-gap.md`](../../../../0072-2026-03-28-run-invalid-tag-index-binaryen-parser-gap.md)
- Harness classification: [`../../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
- Harness tests: [`../../../../../scripts/test/pass-fuzz-compare-command.ts`](../../../../../scripts/test/pass-fuzz-compare-command.ts)
