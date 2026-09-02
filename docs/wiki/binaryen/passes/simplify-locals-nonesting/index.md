---
kind: entity
status: supported
starshine_status: active
last_reviewed: 2026-09-02
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
  - ../simplify-locals/index.md
  - ../../../../../agent-todo.md
  - ../simplify-locals/variant-matrix-and-scheduler.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/SimplifyLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/passes/simplify-locals-nonesting.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/passes/simplify-locals-nonesting.txt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flatness-variant-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ./fuzzing.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nostructure/index.md
  - ../flatten/index.md
  - ../dataflow-optimization/index.md
  - ../tracker.md
---

# `simplify-locals-nonesting`

## Binaryen-v131 renewal

Closed on 2026-07-27. The refreshed aggregate completed `10000/10000`: `7684` exact matches and `2316` strictly smaller Starshine outputs (`-6..-2` bytes), with zero validation, property, generator, or command failures. Idempotence is `1000/1000`.

## Role

- `simplify-locals-nonesting` is a real public Binaryen pass and now an **active Starshine hot pass**.
- The canonical spelling and compatibility alias `simplify-locals-no-nesting` share `SimplifyLocalsPolicy(false, false, false)` in [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt).
- Focused red-first tests prove flat copy retargeting, computed-value movement only into another `local.set`, preservation under `drop` and calls, no `if`-result synthesis, and alias behavior.
- Starshine's HOT inline helpers now carry an explicit parent-position fact so non-copy expressions move only when the immediate consumer is a `local.set`; copy values remain eligible everywhere. This is the Binaryen-specific nonesting exception, not a broad skip gate.
- The current dedicated aggregate compares `10000/10000` with `7684` exact and `2316` strictly smaller Starshine outputs; the separate idempotence lane is `1000/1000`.
- It is not part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.

## 2026-08-27 P0 performance repair

The canonical 4,977,401-byte production artifact exposed a quadratic preflight in `simplify_locals_should_skip_root_local_set_stack_hazard(...)`: every effectful root local write rescanned all later roots and recursively searched each effectful subtree for the same local. Direct `simplify-locals-nonesting` therefore exceeded 900 seconds while Binaryen's pass took about 0.773 seconds.

The repaired preflight performs one forward scan with a pending-effectful-writer bit per local and stamped per-root node visitation. It preserves the established read-before-overwrite rule, including an effectful read/write root satisfying the older writer before replacing it, while a pure overwrite clears the pending writer. White-box tests lock both semantic cases and bound a dense 128-writer/128-effect-root fixture to at most 512 visited read-scan nodes.

Final formatted native SHA-256 `360389c2467e43535b06842d027f4582bba659b5a352a2180e66f5701bc2dc97` measures Starshine pass-local median `551.868ms` versus Binaryen `763.111ms` (`0.72x`) over one warmup plus three serial paired samples, down from the prior `>900s` failure. The pre-repair full command did not complete and therefore produced no comparable full output; every final traced/no-trace pair is byte-identical, the output is stable across the final formatting rebuild, and regular GenValid is `10000/10000` normalized against Binaryen. The absolute no-trace command remains `3.659s` versus Binaryen `1.261s` because HOT lift still owns `1.618s`; `[P0-WALL-SLNONESTING]` therefore remains open until the complete direct command is `<=2x` Binaryen without size or parity loss.

Fresh regular GenValid is `10000/10000` normalized with zero failures. The dedicated aggregate compares all 7,235 Binaryen-parseable cases as `5,026` normalized plus `2,209` strictly smaller canonical Starshine outputs, with zero canonical size losses and zero Starshine validation/property/generator failures; the remaining 2,765 `simplify-locals-family-coverage` inputs are classified Binaryen-v131 parser/tool failures (`bad node code 31`), not optimizer failures.

## 2026-09-02 wall-time closeout

No new nonesting transform is needed for the production gate. The accepted August output is unchanged, while the intervening shared HOT-lift and function-envelope work reduces the complete direct command. One warmup plus three serial pairs on the canonical 4,977,401-byte artifact measure:

- no-trace command: `3,659.315ms -> 2,467.228ms` (`1.483x`, `-32.577%`)
- pass-local: `551.868ms -> 459.349ms` (`1.201x`, `-16.765%`)
- HOT lift: `1,617.657ms -> 819.908ms` (`1.973x`, `-49.315%`)
- HOT lower: `276.629ms`
- aggregate function overhead: `306.842ms`
- batch writeback: `51.910ms`
- main pipeline: `1,938.813ms`

Paired Binaryen-v131 medians are `1,254.875ms` command and `754.346ms` pass-local. Starshine is therefore `1.966x` command / `0.609x` pass and clears the fixed `<=2.550s` command target by `82.772ms`. All three measured Starshine outputs equal the prior accepted result byte-for-byte: 4,961,908 bytes, SHA-256 `b5dc28fea9588a3bc219f181b83a6a644e1fba807159f472e9042f9ef7c8ee0d`. The final native binary SHA-256 is `925e2f72645efcfe48887635888b1b170d21f213ecc568283b4b106fb3436d7f`, and each representative output passes `wasm-tools validate --features all`.

The trace still shows a broad unchanged envelope rather than a hidden raw bypass: all 11,999 functions enter HOT, 1,179 report `changed=true`, and 10,820 report `changed=false`. The existing fail-closed guards account for 5,839 control-local-tee protections, 2,767 root-local-set stack-hazard no-ops, and 80 suspicious-escape writeback rollbacks.

A reusable native-release benchmark in `src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt` builds 2,048 functions outside `it.bench(...)`, requires 2,048 nonesting admissions and zero pass mutations, locks the unchanged final local carrier, and measures registry dispatch with only final-module validation disabled. It reports `10.80ms +/- 113.06us` on x86_64 AMD Ryzen 7 8845HS with MoonBit `0.1.20260713`.

Final explicit-v131 renewal is `10000/10000` normalized in the regular lane. The dedicated aggregate is `5,026` normalized plus `4,974` canonically smaller Starshine outputs, with zero canonical size losses or validation, property, generator, or command failures. The mismatch set is exact by selected profile: all 2,209 flat-parent cases remove only Binaryen-retained `nop`s; all 2,765 family-coverage cases remove `nop` debris and flatten an untargeted void loop around the same ordered `local.set`. Those are source-backed, measured Starshine cleanup wins rather than a broad normalizer. `[P0-WALL-SLNONESTING]` is closed. The 283,042-byte canonical size gap remains separate under `[SIZE]001`.

## Why this pass matters

The main no-DWARF queue, the saved `-O4z` queue, and the first widened upstream-only wave are already dossier-covered.
So this folder is a deliberate second-wave expansion for a real local registry pass that still lacked a canonical landing page.

This pass is worth teaching because it is easy to mis-handle in three different ways:

- silently collapse it into `simplify-locals-notee-nostructure`
- silently collapse it into `flatten`
- dismiss it as an implementation flag instead of a real public pass

The source-backed correction is:

- this is a public `SimplifyLocals` family variant with exact identity `SimplifyLocals<false, false, false>`
- it still performs real locals cleanup
- but it preserves flatness by refusing any sink that would create new nesting

## Main beginner correction

The easy wrong summary is:

- "`simplify-locals-nonesting` just means no tee and no structure."

The source-backed summary is:

- Binaryen builds this pass from the same shared locals engine as the rest of the family
- its exact identity is `SimplifyLocals<false, false, false>`
- so it forbids:
  - new tees
  - new structure
  - new nesting
- but it still allows:
  - flat copy-chain cleanup
  - equivalent-local canonicalization
  - dead-set cleanup
  - limited flat sinking that stays in set-value positions

So `-nonesting` is **not**:

- just `-notee-nostructure` with different wording
- just `flatten`
- a no-op cleanup pass

## Why the dedicated folder was needed

The existing `simplify-locals` family docs already mentioned the nonesting variant.
That was not enough.
A dedicated folder was still justified because:

- the local registry tracks it as its own pass name
- upstream Binaryen registers it as its own public pass name
- it has its own dedicated pass test pair
- multiple neighboring dossiers (`flatten`, `dfo`, `simplify-locals-notee-nostructure`) depend on understanding its exact flatness contract

## Most important durable takeaways

- `simplify-locals-nonesting` is a **real public Binaryen pass**, not a hidden test mode.
- Its exact implementation identity is:
  - `allowTee = false`
  - `allowStructure = false`
  - `allowNesting = false`
- It still shares the same multi-cycle `SimplifyLocals` engine, the late `EquivalentOptimizer`, and the final `UnneededSetRemover` cleanup.
- Its defining promise is stricter than the other reduced variants:
  - it preserves flatness by rejecting sinks that would create new expression nesting.
- It is an important aggressive-pipeline neighbor:
  - official combo tests use `flatten -> simplify-locals-nonesting -> dfo`
  - and similar pre-analysis pipelines before `souperify`
- The local Starshine alias `simplify-locals-no-nesting` should stay explicit instead of being silently treated as the upstream name.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Main implementation walkthrough: the shared `SimplifyLocals` engine, the nonesting gate in `optimizeLocalGet(...)`, the remaining late cleanup phases, and the real pass interactions.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./flatness-variant-boundaries.md`](./flatness-variant-boundaries.md)
  Focused guide to the hardest part to misread: what “preserves flatness” really means, how this differs from `-notee-nostructure`, and why it is not the same thing as `flatten`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing the main positive, preserved, and bailout families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Active Starshine implementation map: spelling policy, shared policy engine, parent-position legality fact, tests, and v131 closeout.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation-readiness bridge: spelling-policy first step, no-rewrite skeleton, flat-copy first slice, disabled tee/structure/nesting negatives, late-cleanup follow-up, and Binaryen `--simplify-locals-nonesting` oracle ladder.
- [`./fuzzing.md`](./fuzzing.md)
  Current compare-pass status, flatness-aware aggregate profile, refreshed v131 counts, and idempotence evidence.

## Current maintenance rule

- Treat this folder as the canonical home for future `simplify-locals-nonesting` maintenance and parity renewal.
- Keep the canonical/alias split explicit:
  - canonical upstream and Starshine name: `simplify-locals-nonesting`
  - tested Starshine compatibility alias: `simplify-locals-no-nesting`
- Reopen [`fuzzing.md`](fuzzing.md) for a new validation/property failure, semantic mismatch, unknown/risky family, or size-losing residual.
- Keep the biggest correction explicit:
  - this variant is stricter than `simplify-locals-notee-nostructure` because it also forbids new nesting.

## Sources

- Binaryen current-main owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>
- research note 0407
- research note 0331
- research note 0186
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../simplify-locals/index.md`](../simplify-locals/index.md)
- [`../simplify-locals/variant-matrix-and-scheduler.md`](../simplify-locals/variant-matrix-and-scheduler.md)
- [`../tracker.md`](../tracker.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- Binaryen `version_131` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/SimplifyLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/test/passes/simplify-locals-nonesting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/test/passes/simplify-locals-nonesting.txt>
