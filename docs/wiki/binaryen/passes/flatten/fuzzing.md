---
kind: workflow
status: planned
last_reviewed: 2026-07-15
sources:
  - ../../../raw/binaryen/2026-07-15-flatten-version-130-internal-output-recursive-ownership-impact.md
  - ../../../raw/binaryen/2026-07-15-flatten-version-130-nested-call-argument-impact.md
  - ../../../raw/binaryen/2026-07-11-flatten-current-main-and-local-status-recheck.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `flatten` Fuzzing Status

## Current state: planned, not runnable

Do **not** treat `bun fuzz compare-pass --pass flatten ...` as a current smoke lane.

- The harness allowlist in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does **not** include `flatten`, so it rejects the command before generation or either optimizer runs.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) retains `flatten` as **Removed**, not as an active pass with a descriptor or dispatcher route. Private `pass_manager.mbt` helpers whose names contain `flatten` belong to other transforms and do not alter that admission result.
- Parser rejection, removed-pass rejection, or zero compared cases is only current-status evidence. It is not evidence about the upstream `flatten` transform or Starshine parity.

Safe inspection only:

```text
bun fuzz compare-pass --list-passes
```

## Internal impact evidence is not public fuzz signoff

The latest 2026-07-15 internal matrix adds actual Starshine lowering, encoding, validation, execution, and cleanup evidence for three synthetic resultless catch-all probes. It still does not expose `flatten`, add a GenValid profile, or run any of the four public compare lanes. Nonthrowing synthetic-try elision makes the narrow matrix a measured cleanup-size win (`212` Starshine bytes versus `236` Binaryen). Exact terminal-table caching, duplicate-router removal, lightweight reachable ownership counts, and batched detached suffix deletion leave candidate-dense pass-local time at `3.65x` Binaryen. Typed catch/pop repair and structured control-plus-label deletion remain unimplemented, although current whole-function deferred outcomes remain exact. Direct `i32.shl`, `i32.shr_s`, and `i32.shr_u` roots are focused behavior evidence, not a substitute for a pass-specific generator or public compare matrix. Performance and public signoff remain gated. See [`../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md`](../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md).

The latest branch-index, in-place-tail, suffix-truncation, scalar/multivalue/legacy-try rewrite-proof, table-target-vector, lightweight ownership, tuple-branch count, conditional-site, scalar parent-population, sparse proof-cache, postorder-dispatch, shared-root, single-target staging, inputful-loop support-cache, constant-time branch append, shared admission-roster, EH-prerequisite, flatness-classification, and sparse binary-lookup commits remain internal work only. Commits `80e6a652b` and `efb8fdfa2` complete sorted sparse binary lookup for tuple-made and distinct non-tuple multivalue `br_if` flow proofs. They preserve explicit negative admission results, first-proof authority, exact current parent/slot checks, and post-boundary missing-entry rejection. They add no GenValid profile, harness allowlist entry, public pass descriptor, dispatcher, CLI execution, or compare/API exposure. Focused flatten is `245/245`, private flatten is `175/175`, passes are `5,750/5,750`, and the full suite is `9,211/9,211`. Exact cached-lookup reconstruction improves tuple flow `47.34%` and distinct flow `66.89%` at 512 candidates, but no representative run was requalified and the original public gate harness remains unrecovered. The durable representative checkpoint therefore remains `3.65x` Binaryen. Typed EH plus structured label-owner deletion are absent, the flatten aggregate does not exist, and no public compare lane is authorized yet.

The table-target/terminal-payload iteration remains internal as well. Commits `bdad9efaf` and `902848fca` replace measured linear target deduplication and payload-root membership with exact mark-set and sorted sparse lookup. Private flatten is `177/177`, focused flatten `245/245`, passes `5,752/5,752`, and the full suite `9,213/9,213`; no generator, allowlist, descriptor, dispatcher, CLI execution, or compare surface was added. The owner-specific 512-candidate improvements (`437,000 -> 16,000 us` for target extraction and `110,000 -> 20,000 us` for payload membership) do not requalify the unrecovered representative gate.

## Future executable lane

Enable a lane only after Starshine has an active flatten implementation, the harness admits and maps the spelling to Binaryen `--flatten`, and fixtures/profile generation demonstrate Flat-IR-relevant shapes with a meaningful `--min-compared` threshold. The future corpus must separately cover evaluation order, local/tee introduction, control and exception boundaries, multivalue carriers, and output flatness; generic valid modules do not prove those properties.

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass flatten --count 10000 --seed 0x5eed \
  --gen-valid-profile <flatten-aware-profile> \
  --out-dir .tmp/pass-fuzz-flatten --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

This is a future template, not a command to run against the current removed implementation.
