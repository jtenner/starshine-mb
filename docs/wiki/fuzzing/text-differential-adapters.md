---
kind: workflow
status: supported
last_reviewed: 2026-06-05
sources:
  - ../raw/fuzzing/2026-06-05-text-differential-adapter-source-refresh.md
  - ../../../scripts/lib/fuzz-text-adapters.ts
  - ../../../scripts/lib/fuzz-text-adapters.test.ts
  - ../../../src/cmd/fuzz_harness.mbt
  - ../../../src/cmd/fuzz_harness_wbtest.mbt
  - ../../../src/fuzz/main.mbt
  - ../../../src/fuzz/main_wbtest.mbt
related:
  - ../tooling/fuzz-runner.md
  - recipe-schema.md
  - wast-arbitrary-parity-plan.md
  - reduction-backends.md
  - ../tooling/external-validator-adapters.md
  - ../wast/text-surface-gap-ledger.md
  - ../wasm-feature-status-and-proposal-boundaries.md
---

# Text Differential Adapters

## Overview

Use this page when a text-fuzzing result, WAST parser/printer bug, external text-parser disagreement, or `text-differential-smoke` recipe needs interpretation.

Starshine has two related text-differential layers:

1. **MoonBit local matrix and opt-in fuzz suite.** [`run_text_differential_fuzz(...)`](../../../src/fuzz/main.mbt) generates a tiny deterministic WAT module, parses it with Starshine, lowers and encodes it, prints it back to WAST, reparses and relowers the printed text, and checks that the two encoded modules match. This is what `moon run src/fuzz -- text-differential smoke --seed 0x1045a7` and the [`text-differential-smoke`](recipe-schema.md) recipe run today.
2. **TypeScript optional external adapter scaffold.** [`scripts/lib/fuzz-text-adapters.ts`](../../../scripts/lib/fuzz-text-adapters.ts) can run WABT `wat2wasm` or `wasm-tools parse` over a text case and classify the result into the `starshine.fuzz.text-adapters.v1` schema. This scaffold is tested, but the current MoonBit fuzz suite does not invoke it; the suite reports `wabt-unavailable` and `wasm-tools-unavailable` placeholders instead.

Keep those layers separate. A green `text-differential` smoke run proves Starshine's current local parse/print/reparse/lower path is stable for the generated cases. It does **not** prove WABT, `wasm-tools`, Binaryen, or every WAST proposal syntax agrees with Starshine.

The current source bridge is [`../raw/fuzzing/2026-06-05-text-differential-adapter-source-refresh.md`](../raw/fuzzing/2026-06-05-text-differential-adapter-source-refresh.md). It rechecked the official `wasm-tools parse` and WABT `wat2wasm` command roles plus the local MoonBit and TypeScript implementation evidence.

## Beginner Model

WebAssembly has both a binary format (`.wasm`) and text formats (`.wat` / `.wast`). A text differential test asks questions like:

- Can Starshine parse this text?
- Can Starshine lower the parsed AST to its core module model?
- Can Starshine print the AST back to text?
- Can Starshine parse and lower its own printed text?
- Do the original-lowered bytes and reprinted/reparsed-lowered bytes match?
- If an external text tool is available, does it accept or reject the same source text?

That is different from binary validation. `wasm-tools parse` and WABT `wat2wasm` translate text to binary; [`external-validator-adapters.md`](../tooling/external-validator-adapters.md) covers `wasm-tools validate`, WABT `wasm-validate`, and Binaryen `wasm-opt --validate` for binary modules.

## Current MoonBit Suite Flow

The runnable suite in [`src/fuzz/main.mbt`](../../../src/fuzz/main.mbt) is intentionally small and opt-in:

```text
text_differential_case(seed, attempt)
  -> "(module (func (export \"answer\") (result i32) i32.const <n>))"
  -> wast_to_module(...)
  -> wast_ast_to_binary_module(...)
  -> encode_module(...)
  -> module_to_wast(...)
  -> wast_to_module(printed, ...)
  -> wast_ast_to_binary_module(reparsed)
  -> encode_module(relowered)
  -> compare original-lowered bytes with reparsed-lowered bytes
```

Profiles are:

| Profile | Attempts | Purpose |
| --- | ---: | --- |
| `smoke` | 1 | Cheap local parser/printer/lowerer canary. |
| `ci` | 8 | Slightly broader deterministic constants. |
| `stress` | 32 | Still tiny; useful for local development loops, not broad syntax coverage. |

The suite details JSON currently reports:

- `local_parse_ok`
- `local_print_ok`
- `local_reparse_lower_ok`
- `local_lower_mismatch`
- `adapter_unavailable`
- `adapter_unavailable_classifications`
- `accepted_classifications`
- `external_adapters`

[`src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt) locks the important policy: `text-differential-smoke` is discoverable as a standard recipe, `text-differential` is **not** part of the default active suite set, and the smoke run records two unavailable external-adapter placeholders.

## Optional External Adapter Scaffold

The TypeScript helper in [`scripts/lib/fuzz-text-adapters.ts`](../../../scripts/lib/fuzz-text-adapters.ts) uses this schema:

```text
schema: starshine.fuzz.text-adapters.v1
inputHash: sha256(sourceText)
adapters: [{ adapter, classification, diagnostic? }]
summary: counts by classification
```

Adapter classifications are:

| Classification | Meaning | Typical owner |
| --- | --- | --- |
| `accepted` | The adapter command exited successfully for the text case. | Evidence only; compare generated bytes separately before claiming semantic equivalence. |
| `parse-error` | The adapter rejected the text as ordinary syntax/parse failure. | Could be Starshine extension, external gap, malformed input, or real text bug. Inspect syntax and feature status. |
| `unsupported-syntax` | Diagnostics contain unsupported/proposal wording. | Route through [`text-surface-gap-ledger.md`](../wast/text-surface-gap-ledger.md) and [`wasm-feature-status-and-proposal-boundaries.md`](../wasm-feature-status-and-proposal-boundaries.md). |
| `adapter-unavailable` | The command was missing, usually `ENOENT`. | Skipped evidence; do not count as agreement or disagreement. |
| `adapter-error` | The command failed operationally in a way that is not a normal parse result. | Tooling failure; retry or inspect stderr/stdout. |

The tested command shapes are:

| Adapter | Command shape | Current integration status |
| --- | --- | --- |
| WABT | `wat2wasm <case.wat> -o <case.wasm>` | Implemented in TypeScript helper; not run by current MoonBit `text-differential` suite. |
| `wasm-tools` | `wasm-tools parse <case.wat> -o <case.wasm>` | Implemented in TypeScript helper; not run by current MoonBit `text-differential` suite. |
| Starshine local | in-process `wast_to_module` / lower / encode / print / reparse / relower / encode | Implemented in MoonBit helper and suite. |

[`scripts/lib/fuzz-text-adapters.test.ts`](../../../scripts/lib/fuzz-text-adapters.test.ts) uses fake commands to prove accepted, unavailable, unsupported-syntax, and fake n-way classification behavior without making real external binaries mandatory.

## Aggregate Classification In `src/cmd`

[`src/cmd/fuzz_harness.mbt`](../../../src/cmd/fuzz_harness.mbt) has a richer in-tree aggregate model for local reports plus external adapter-like results:

| Aggregate | Meaning |
| --- | --- |
| `accepted` | Available adapters agree that parse/print/lower/validation facts are acceptable. |
| `parse-disagreement` | At least one adapter failed parse while another did not, or Starshine local parse failed. |
| `print-disagreement` | Starshine-local print failed or print booleans disagree. External text-to-binary adapters usually have no print result. |
| `lower-disagreement` | Lowering or original-vs-reparsed byte equality failed/disagreed. |
| `unsupported-syntax` | Any adapter marks the text as unsupported/proposal syntax. |
| `semantic-validation-disagreement` | Optional validation booleans disagree after parse/lower. |
| `adapter-unavailable` | Any selected adapter is unavailable. This wins early so skipped evidence is explicit. |

`persist_text_differential_artifacts(...)` writes `original.wat`, optional `starshine.printed.wat`, optional original/reparsed `.wasm` files, `adapters.txt`, and `classification.txt` under a `text-repros/seed-<seed>-attempt-<attempt>-<classification>` directory. Those artifacts are triage evidence; committed durable conclusions should still be filed back into `docs/wiki/` or `docs/wiki/raw/research/` rather than citing temporary run directories.

## How To Interpret Common Outcomes

| Observation | Interpret as | Next step |
| --- | --- | --- |
| `text-differential-smoke` passes with `adapter_unavailable=2`. | Starshine local text matrix is stable; external adapters were not exercised. | No external-tool claim. Use this as a cheap parser/printer canary only. |
| Starshine parses and prints, WABT `wat2wasm` rejects. | Text parser disagreement, not automatically a Starshine bug. | Check whether the case uses Starshine-local syntax, proposal syntax, or a WAST feature external WAT tools do not support. |
| WABT and `wasm-tools parse` accept but Starshine rejects. | Likely Starshine parser/lowerer gap, but still feature-check first. | Reproduce with a minimal `.wat`, then route through the relevant WAST authoring page and gap ledger. |
| Starshine parses original text but rejects its own printed text. | Printer/reparse bug. | Preserve `original.wat` and `starshine.printed.wat`; add a focused WAST roundtrip test. |
| Original-lowered and reparsed-lowered bytes differ. | Lowering/printing roundtrip drift. | Decide whether the difference is representation-only or semantic by decoding/validating and inspecting the module shape. |
| Adapter command missing. | Skipped evidence. | Install the command, pass the helper an explicit binary path, or keep the result as `adapter-unavailable`. |

## Maintenance Guidance

When widening text differential coverage:

1. **Add focused WAST tests first.** If a new syntax family is not supported by Starshine WAST, update the focused authoring page and [`text-surface-gap-ledger.md`](../wast/text-surface-gap-ledger.md) before using it as a fuzz positive.
2. **Keep suite claims honest.** If the MoonBit runner still reports placeholder unavailable adapters, do not cite it as WABT / `wasm-tools` evidence.
3. **Keep external text and binary validators separate.** Text adapters parse/encode source text; binary adapters validate bytes.
4. **Persist enough repro context.** For disagreements, retain original text, Starshine printed text, original/reparsed bytes if present, adapter diagnostics, classification, seed, attempt, profile, and exact command line.
5. **Classify proposal gaps explicitly.** Browser support, active proposal status, and external parser acceptance are distinct facts. Use the shared feature-boundary page before assigning blame.
6. **Update the recipe and fuzz-runner docs together.** Any change to `text-differential-smoke`, profile attempt counts, details JSON, adapter names, or artifact layout should update [`recipe-schema.md`](recipe-schema.md), [`../tooling/fuzz-runner.md`](../tooling/fuzz-runner.md), this page, and [`../log.md`](../log.md).

## Source Map

- Source bridge: [`../raw/fuzzing/2026-06-05-text-differential-adapter-source-refresh.md`](../raw/fuzzing/2026-06-05-text-differential-adapter-source-refresh.md)
- TypeScript optional adapters: [`../../../scripts/lib/fuzz-text-adapters.ts`](../../../scripts/lib/fuzz-text-adapters.ts), [`../../../scripts/lib/fuzz-text-adapters.test.ts`](../../../scripts/lib/fuzz-text-adapters.test.ts)
- MoonBit local matrix and aggregate helpers: [`../../../src/cmd/fuzz_harness.mbt`](../../../src/cmd/fuzz_harness.mbt), [`../../../src/cmd/fuzz_harness_wbtest.mbt`](../../../src/cmd/fuzz_harness_wbtest.mbt)
- Runnable fuzz suite and recipe tests: [`../../../src/fuzz/main.mbt`](../../../src/fuzz/main.mbt), [`../../../src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt)
- Related docs: [`../tooling/fuzz-runner.md`](../tooling/fuzz-runner.md), [`recipe-schema.md`](recipe-schema.md), [`wast-arbitrary-parity-plan.md`](wast-arbitrary-parity-plan.md), [`../tooling/external-validator-adapters.md`](../tooling/external-validator-adapters.md), [`../wast/text-surface-gap-ledger.md`](../wast/text-surface-gap-ledger.md)
