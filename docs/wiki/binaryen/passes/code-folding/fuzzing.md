---
kind: workflow
status: maintained
last_reviewed: 2026-07-19
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_code_folding_tests.mbt
---

# `code-folding` Fuzzing Profile

## Stable aggregate

Use `code-folding-all` for dedicated closeout:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 --seed 0x5eed \
  --pass code-folding \
  --gen-valid-profile code-folding-all \
  --out-dir .tmp/pass-fuzz-code-folding-dedicated \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Aliases: `code-folding`, `code-folding-all`, and `pass-code-folding-all`.

The aggregate selects six leaf profiles:

| Profile | Intended family |
| --- | --- |
| `code-folding-if-arms` | identical full/partial `if` arm tails |
| `code-folding-block-exits` | named-block branch and fallthrough exits |
| `code-folding-returns` | duplicated `return` / terminating suffixes |
| `code-folding-tail-calls` | duplicated `return_call` suffixes |
| `code-folding-movement` | structured suffixes with internal branch targets |
| `code-folding-eh` | non-throwing tails inside `try_table` bodies |

The fixtures use mutable-global writes rather than removable `nop` or dropped-constant padding, so the pass-owned opportunity survives the preceding `vacuum` slot during neighborhood replay.

Manifest triage fields:

- `genValidSelectedProfile`
- `genValidProfileCaseLabel`
- `inputEffectTrapFacts`

## 2026-07-18 closeout

The required direct four-lane matrix used a current prebuilt native release binary:

| Lane | Result |
| --- | --- |
| regular GenValid, seed `0x5eed` | `.tmp/pass-fuzz-code-folding-closeout-regular-100000`: `100000/100000` normalized matches, zero mismatches or failures |
| explicit wasm-smith, seed `0x5eed` | `.tmp/pass-fuzz-code-folding-closeout-wasm-smith-10000`: `9956/10000` normalized matches, zero mismatches; 44 Binaryen/tool command failures (`39` empty rec-group, `1` invalid tag index, `1` table index, `3` bad section size) |
| `code-folding-all`, seed `0x5eed` | `.tmp/pass-fuzz-code-folding-closeout-dedicated-effectful-10000`: `10000/10000` normalized matches, zero mismatches or failures |
| random all-profiles, seed `0x5555` | `.tmp/pass-fuzz-code-folding-closeout-random-all-10000`: `10000/10000` normalized matches, zero mismatches or failures |

Dedicated distribution: returns `1727`, block exits `1679`, EH `1674`, movement `1649`, tail calls `1647`, and if arms `1624`.

## 2026-07-19 external-validity refresh

After an externally detected typed-tail-region invalid output was fixed, the complete matrix was rerun with Binaryen v131 and `--external-validator wasm-tools`:

| Lane | Result |
| --- | --- |
| regular GenValid | `.tmp/pass-fuzz-code-folding-post-validity-regular-v131-100000`: `100000/100000` normalized matches; zero mismatches, validation failures, generator failures, or command failures |
| explicit wasm-smith | `.tmp/pass-fuzz-code-folding-post-validity-wasm-smith-v131-10000`: `9956/10000` compared and normalized; zero mismatches or validation failures; the same 44 Binaryen/tool command failures |
| `code-folding-all` | `.tmp/pass-fuzz-code-folding-post-validity-dedicated-v131-10000`: `10000/10000` normalized matches; zero mismatches or failures |
| random all-profiles | `.tmp/pass-fuzz-code-folding-post-validity-random-all-v131-10000`: `10000/10000` normalized matches; zero mismatches or failures |

A rebuilt-current-binary dedicated replay after rebasing onto local `main` at `.tmp/pass-fuzz-code-folding-post-rebase-current-10000` also completed `10000/10000` with zero mismatches, validation failures, property failures, generator failures, or command failures. The first interrupted rerun later resolved TinyGo's Binaryen v116 and stopped after 33 comparisons; it is tool-version drift, not parity evidence. The v131-prefixed directories above and the post-rebase replay supersede it. Detailed validity and performance conclusions are retained in [`./index.md`](./index.md), [`./starshine-strategy.md`](./starshine-strategy.md), and [`../../../log.md`](../../../log.md).

## Ordered neighborhood

The scheduled sequence is:

```text
vacuum -> code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks
```

The effectful 1000-case replay at `.tmp/pass-fuzz-code-folding-effectful-neighborhood-1000` validates all outputs but records downstream shape differences: the `if`-arm family is raw green; return/tail-call and movement cases are smaller Starshine `br_if` forms; block-exit and EH cases expose size-losing cleanup gaps in neighboring `merge-blocks` / branch cleanup. These are not direct `code-folding` mismatches because the direct aggregate is raw green, but they remain preset-neighborhood reopening evidence and must not be reported as full cleanup-cluster shape parity.

## Dewdrop runtime renewal with a real Node process

The September renewal uses frozen native revision `009ad983b`, explicit
Binaryen 131, seed `0x5eed`, eight workers, wasm-tools validation, determinism,
codec roundtrips, and the strict v2 Node process oracle. Earlier Bun-worker
observations are not Node evidence.

| Lane | Canonical output | Runtime | Canonical bytes, Starshine / Binaryen | Wall time |
| --- | --- | --- | --- | --- |
| Regular GenValid, 10,000 | 10,000 matches | 5,019 matches; 4,981 blocked original executions; zero mismatches | 42,157,334 / 42,157,334 | 2,191.280 s |
| `code-folding-all`, 10,000 | 6,624 matches; 3,376 shape differences | 10,000 matches; zero blocked or mismatched | 668,374 / 671,750 | 622.840 s |

Both lanes have zero generator, validation, command, determinism, or codec
failures. All 20 retained aggregate diffs remove exactly one final bare return
and retain earlier nested returns. Every differing output saves one canonical
byte; none is larger. The agent classification is a size-winning final-return
cleanup, supported by the inspected transform and completed runtime comparisons.
This does not establish a runtime speed benefit or sign off later shared-IR
changes. The blocked regular originals are not counted as runtime passes.

Evidence in Dewdrop's `.tmp/starshine-pass-repairs/`:
`genvalid-wave14-code-folding-{regular,aggregate}/result.json`,
`generated-signoff-wave14-commands.json`, and
`code-folding-aggregate-return-diff-review.json`.
