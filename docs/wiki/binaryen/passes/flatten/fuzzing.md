---
kind: workflow
status: planned
last_reviewed: 2026-07-16
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

The immutable-index/reusable-scratch follow-up is internal as well. It adds no generator, allowlist, descriptor, dispatcher, CLI execution, or compare surface. Private flatten is `182/182`, focused flatten `245/245`, passes `5,757/5,757`, and the full suite `9,218/9,218`. Targeted native-release measurements improve cached ancestry, table-target, type-result, target-local, and prelude-heavy owners, and the reconstructed representative is nonregressing, but none of this creates a public parity lane or requalifies the durable `3.65x` Binaryen checkpoint.

The sequenced-root/multivalue-payload lookup follow-up remains internal too. Commits `4a03de7f3` and `aa295d38b` sort exact shared-root holder/node pairs for binary membership and mark exact multivalue `br_if` payload ids for duplicate/root checks. Private flatten is `184/184`, focused flatten `245/245`, passes `5,759/5,759`, and the full suite `9,220/9,220`; no generator, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added. The 512-candidate lookup reductions (`91.56%` and `95.73%`) are owner-specific and do not authorize a public compare lane or replace the durable `970.5 us` / `3.65x` gate.

The multivalue flow-index follow-up remains internal as well. Commits `f1dc57565` and `24b909b2d` replace the remaining nested distinct-payload edge scan and tuple flow-slot duplicate scan with exact query-local indexes. Private flatten is `186/186`, focused flatten `245/245`, passes `5,761/5,761`, and the full suite `9,222/9,222`; no generator, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added. The 512-candidate owner reductions (`1,878 -> 39 us` and `59,644 -> 1,368 us`) do not authorize a public compare lane or replace the durable `970.5 us` / `3.65x` gate.

The reversed multivalue binary-flow iteration remains internal too. Commits `2ae0a6adb` and `d64535310` add independently scalar and exclusively tuple-made simple-left/payload-right false-path consumers. Focused flatten is `247/247`, private flatten `186/186`, passes `5,763/5,763`, and the full suite `9,224/9,224`. Fresh pinned-v130 source/probe evidence preserves payload-before-condition order and binary execution only after a not-taken branch. No profile, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added. This is behavior-breadth progress, not public fuzz signoff.

The rich-right binary-flow iteration remains internal as well. Commits `5c4a664dd` and `a4055b7a9` admit exact one-use rich right operands for payload-left independently scalar and exclusively tuple-made lanes; the shared consumer proof also applies to exact inputful-loop flow. Pinned-v130 legacy-try and loop probes place each rich call after payload-free `br_if` and before the binary. Focused flatten is `249/249`, private flatten `186/186`, passes `5,765/5,765`, and full suite `9,226/9,226`. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added, so no public compare lane is authorized.

The rich-left binary-flow iteration remains internal too. Commits `e5c2a91ea` and `d0a53acf9` admit one exact one-use pre-branch rich left for independently scalar and exclusively tuple-made legacy-try lanes when the complete payload vector is simple and the binary consumes lane zero after higher lanes. Pinned-v130 probes place the rich left call before payload calls and `br_if`, with the binary remaining after the not-taken branch. Focused flatten is `251/251`, private flatten `186/186`, passes `5,767/5,767`, and full suite `9,228/9,228`. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added, so no public compare lane is authorized.

The inputful-loop rich-left iteration remains internal too. Commits `843614438` and `35ac3740a` admit the exact independently scalar and exclusively tuple-made loop counterparts when one rich left precedes a complete simple payload vector and feeds lane zero's immediate false-path binary. Focused flatten is `253/253`, private flatten `186/186`, passes `5,769/5,769`, and full suite `9,230/9,230`. The pinned-v130 loop probe confirms pre-branch left placement and post-branch binary execution. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added.

The inputful-loop rich-payload iteration remains internal too. Commits `3cb5577ad` and `c5a0a738a` admit at most one supported rich payload origin alongside the existing pre-branch rich left, first for independently scalar lanes and then for one exclusively owned repeated `TupleMake`. The tuple route corrects prelude order so left work precedes child-generated payload work. Focused flatten is `255/255`, private flatten `186/186`, passes `5,771/5,771`, and full suite `9,232/9,232`. The pinned-v130 probe confirms left, rich payload, remaining payload, condition, branch, and false-path binary order. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added.

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
