---
kind: entity
status: supported
last_reviewed: 2026-08-12
sources:
  - ../../release-horizon-and-oracles.md
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/SimplifyLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/pass.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/linear-execution.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/equivalent_sets.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/local-utils.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./transform-family-inventory.md
  - ./variant-matrix-and-scheduler.md
  - ./wat-shapes.md
  - ./structure-result-lifting-and-carrier-cleanup.md
  - ./starshine-hot-ir-strategy.md
  - ./implementation-map.md
  - ./effect-ordering-and-barriers.md
  - ./raw-lane-and-writeback.md
  - ./validation-and-signoff.md
  - ./performance-and-artifact-frontiers.md
  - ./parity.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../simplify-locals-nostructure/index.md
  - ../simplify-locals-notee-nostructure/index.md
---

# `simplify-locals`

## Binaryen v131 renewal status

The five-variant Binaryen-v131 renewal is closed. `SimplifyLocals.cpp` and the reviewed locals helpers are unchanged from v130; the relevant released drift is confined to shared pass/global-effect behavior and expected outputs. The audit nevertheless found and repaired four Starshine cleanup gaps: discarded `struct.new_default`, pure dropped local reads, return-local carriers separated by inert code and unreachable suffixes, and branch-result block carriers. Native SHA-256 `5935985cb02530a77aba751dd88f0103a3eadc6ada8e4a0c0b040c878ba4e5bf` was compared with official `wasm-opt version 131 (version_131)`, SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`.

The July 27 five-variant `10000`-case aggregate profiles had zero validation, property, generator, or command failures and no output larger than Binaryen. Exact/more-compact counts were: full `7298/2702`, no-tee `2766/7234`, no-structure `7115/2885`, no-tee/no-structure `2766/7234`, and nonesting `7684/2316`. Five independent `1000`-case idempotence lanes were `1000/1000`, and replaying all `2433` former full random-all mismatches left no larger output or failure.

The August 12 live-out refresh uses the expanded `simplify-locals-all` aggregate, which now includes deterministic `simplify-locals-family-coverage`. It compares `10000/10000` with `5000` normalized matches and zero failures. The `3125` family-coverage residuals remain fourteen canonical bytes smaller, but `1875` generated `structure-result` residuals are `2..4` bytes larger because Starshine retains `nop` debris. That size-losing output-shape family is open parity debt rather than an approved divergence; net canonical residual delta is still `-38,135`.

The July 28 follow-up adds deterministic `SL-01`–`SL-35` interaction coverage and repairs postorder structure formation, unique control/value ownership, payload-bearing `br_if` lowering, aggregate first-cycle deferral, explicit no-tee/no-structure policy, transparent copy chains, and nonesting refined fallthrough equivalence. The integrated pass retains the already measured smaller pure-drop/dead-local cleanup behavior from the larger v131 renewal. `[V131-SPOT]001` is closed for this family.

## 2026-08-12 repaired SGO final-suffix placement

The initial profitability-guarded experiment inserted full `simplify-locals` between SGO's final `merge-blocks` and `remove-unused-brs` stages. It validated and shrank the corpus but failed exact no-cache WIPC with allocator/TLSF aborts, so that implementation was correctly rejected.

The runtime failure is now reduced and repaired. Hybrid function isolation on `bool.spec.wasm` found defined function 43 / absolute function 47. Inside an `if`, the old recursive adjacent-pair cleanup rewrote `call 44; local.set 1; local.get 1; i32.eqz` to `call 44; nop; i32.eqz`, even though a later parent-level `local.get 1` still observed the value. The cleanup considered only reads later inside the child and therefore left the stale pre-`if` pointer live.

`run_hot_pipeline_simplify_locals_lowered_collect_local_reads(...)`, `run_hot_pipeline_simplify_locals_lowered_reads_after(...)`, and `run_hot_pipeline_simplify_locals_lowered_drop_dead_adjacent_local_set_get_pairs_with_liveout(...)` now propagate inherited and later-sibling reads into blocks, both `if` arms, loops, and `try_table`; loop bodies additionally contribute their own reads because another iteration can observe them. The focused regression `simplify-locals preserves a conditional call result reloaded from a parameter` owns the reduced failure, and the SGO regression `simplify-globals-optimizing simplifies locals in the final cleanup suffix` proves the production transaction commits.

The retained owner-scoped sequence is `precompute-propagate -> merge-blocks -> simplify-locals -> remove-unused-brs -> bounded coalesce-locals -> sgo_apply_final_cleanup`. It runs only after SGO changes the module, skips modules with at least 1,000 defined functions, validates and encodes the candidate, and commits only a strictly smaller result. Native SHA-256 `443fa73acbe3789b0e1b330fdf28652fe5f567c4e6df53470e46217b65b92d47` produces `20,252,110` aggregate `json-as` bytes—naive `6,601,920`, SIMD `6,841,190`, SWAR `6,809,000`—and passes optimize/external validation plus exact no-cache WIPC `105/105`. Full Moon is `10,369/10,369`; native/self-optimized artifact optimization is byte-identical, recursive spec is `284/64/220/0`, and full wasm-gc validation includes `86,820` green binary roundtrips.

## Role

- `simplify-locals` is an active implemented **hot pass** in Starshine.
- Its 2026-06-04 O4z audit closeout is green: the direct keep-going `10000`-request lane `.tmp/pass-fuzz-simplify-locals-audit-10000-keepgoing` reached `9975/10000` compared cases with `9975` normalized matches, `0` cleanup-normalized matches, `0` mismatches, and `25` Binaryen/tool command failures; the generated late-neighborhood lane `.tmp/pass-fuzz-sl-late-neighborhood-audit-10000-keepgoing` for `local-cse -> simplify-locals -> merge-blocks` reached the same counts. Both lanes used `--jobs auto` and `_build/native/release/build/cmd/cmd.exe` because this workspace did not produce `target/native/release/build/cmd/cmd.exe`.
- In upstream Binaryen `version_131`, `simplify-locals` is not one pass name with one behavior.
  It is a **family** of five public passes built from one templated implementation in `SimplifyLocals.cpp`.
- The public `pass.cpp` summary is short:
  - `miscellaneous locals-related optimizations`

That summary is true, but much too small.

A better beginner summary is:

- Binaryen counts local uses,
- sinks `local.set` values toward later `local.get`s when effect ordering still allows it,
- optionally creates `local.tee` when later uses still need the local,
- optionally rewrites blocks / `if`s / loops to return values directly,
- then runs a separate equivalent-copy cleanup and final dead-set cleanup.

So this pass is **not** just dead-local removal and **not** just adjacent set/get peepholes.

## Why this pass matters

- `simplify-locals` still sits in one of the most scheduler-relevant parts of the Binaryen pipeline:
  - an early no-structure variant runs before the main local-cleanup cluster
  - the full structured pass runs later after `coalesce-locals` and optional `local-cse`
- The active `SL` backlog slice in `agent-todo.md` still depends on understanding that late slot and its surrounding cleanup neighborhood correctly.
- This thread picked `simplify-locals` as an explicitly justified major-gap fallback after the tracker showed that:
  - the `none` queue was already clear
  - the implemented-landing queue was already clear
  - the older tuple / RUME / RUB / DFE fallback gaps were already closed
- The old folder was already deep, but it was still missing two newer-style pieces that make the dossier easier to use in practice:
  - an immutable primary-source manifest for the exact official release/source/test surfaces reviewed
  - one compact bridge page for block/if/loop result lifting, one-armed `if` defaultability, and the local wrapper-forwarder carrier cleanup family

## Most important durable takeaways

- Binaryen `simplify-locals` is **not** generic CFG-based local dataflow.
- Binaryen `simplify-locals` is **not** just dead-set cleanup.
- The real `version_131` contract is a staged family built from:
  1. `LocalGetCounter` use counting
  2. a first cycle biased toward single-use sinks
  3. later tee-aware linear-trace sinking cycles
  4. optional block / `if` / loop result synthesis
  5. a separate late equivalent-copy optimizer
  6. `UnneededSetRemover` final dead-set cleanup
  7. in-pass `ReFinalize` plus pass-runner nondefaultable-local fixups
- The three semantic axes are real and user-visible:
  - tee creation
  - structure creation
  - whether new nesting is allowed at all
- The 2026-06-04 O4z audit added focused `try_table` EH boundary tests for nonthrowing value sinking and may-throw producer preservation in `src/passes/simplify_locals_test.mbt`, refreshed the direct and late-neighborhood generated parity lanes, and closed `[O4Z-AUDIT-SL]`; no implementation change was needed.
- Current `main` shows only a tiny checked drift beyond `version_131` here:
  - `std::map` / `std::set` -> `std::unordered_map` / `std::unordered_set` bookkeeping cleanup in `SimplifyLocals.cpp`
  - the major dedicated lit files checked for this dossier are unchanged

## Biggest beginner correction

The easy wrong mental model is:

- `simplify-locals` just removes obvious `local.set` / `local.get` pairs

The safer mental model is:

- Binaryen uses a cheap linear-execution model to move pending local writes through later code,
- effect ordering decides when that move is still legal,
- structure synthesis is a separate optional layer,
- and equivalent-copy cleanup plus dead-set cleanup happen later as distinct phases.

That difference explains why:

- the first cycle is intentionally stricter than later cycles
- `simplify-locals-nostructure` and full `simplify-locals` are not interchangeable
- one-armed `if` rewrites are guarded so hard
- equal-local canonicalization can switch a `local.get` to a more refined representative late in the pass

## Page map

### Upstream Binaryen contract

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_131` implementation, algorithm phases, helper dependencies, and why the pass family is more structured than the public name suggests.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Exact upstream file map plus the official lit roster: what `SimplifyLocals.cpp`, `linear-execution.h`, `equivalent_sets.h`, `local-utils.h`, `pass.cpp`, `opt-utils.h`, and the simplify-locals lit files each prove.
- [`./transform-family-inventory.md`](./transform-family-inventory.md)
  - Current `version_131` source-owned transform inventory for all five variants, including the no-tee structure-created-tee distinction, the nonesting parent-position rule, late equivalent-set policy, effect domains, and Starshine gap map.
- [`./variant-matrix-and-scheduler.md`](./variant-matrix-and-scheduler.md)
  - Explicit public variant matrix for `simplify-locals`, `-notee`, `-nostructure`, `-notee-nostructure`, and `-nonesting`, plus the exact top-level and nested scheduler placements that give each variant its job.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly upstream WAT-shape catalog covering positive sink / tee / structure families, important bailout families, and nearby-pass interaction shapes.
- [`./structure-result-lifting-and-carrier-cleanup.md`](./structure-result-lifting-and-carrier-cleanup.md)
  - Compact bridge page for block / if / loop result lifting, one-armed `if` defaultability, and the way those upstream shape families map onto current Starshine helpers and tests.

### Starshine-local port and maintenance surface

- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current in-tree HOT-IR and raw-lane port strategy.
- [`./implementation-map.md`](./implementation-map.md)
  - Concrete map from the dossier to the actual MoonBit helper clusters and tests in tree.
- [`./effect-ordering-and-barriers.md`](./effect-ordering-and-barriers.md)
  - Current in-tree barrier model for local motion.
- [`./raw-lane-and-writeback.md`](./raw-lane-and-writeback.md)
  - Exact-instruction fallback lane and lowered cleanup policy.
- [`./validation-and-signoff.md`](./validation-and-signoff.md)
  - What each local test lane and compare lane proves.
- [`./performance-and-artifact-frontiers.md`](./performance-and-artifact-frontiers.md)
  - Runtime and artifact-hotspot maintenance notes.
- [`../../pass-manager-threshold-guards.md`](../../pass-manager-threshold-guards.md)
  - Cross-pass threshold policy, SimplifyLocals gate classification, stable trace reasons, and focused boundary-test rules.
- [`./parity.md`](./parity.md)
  - Current local parity status.

## Freshness note

A narrow 2026-04-21 source check found no meaningful semantic drift on the checked upstream surfaces.

What I directly re-confirmed:

- `SimplifyLocals.cpp` on current `main` differs from `version_131` only by container choice cleanup
- the checked dedicated lit surfaces are unchanged:
  - `simplify-locals-gc.wast`
  - `simplify-locals-gc-nn.wast`
  - `simplify-locals-gc-validation.wast`
  - `simplify-locals-eh.wast`
  - `simplify-locals-tnh.wast`
  - `global-effects_simplify-locals.wast`

So the current durable rule is:

- treat Binaryen `version_131` as the released semantic oracle for this dossier
- use the `version_131` source links in this page's Sources section when a future thread needs the exact release/source/test provenance again
- mention current-main drift only when it is more than container cleanup

## 2026-08-25 catch-observed write boundary

Four EH-local regressions returned `1` instead of `0` after no-tee/no-structure local propagation removed `local.set 0` inside a caught `try_table`; the catch path observes that write when the following call throws. SimplifyLocals now fails closed only when a caught `try_table` body contains a local write, preserving supported sinking for values defined outside the try. `tests/repros/simplify-locals-eh-catch-observed-write.wasm` owns the direct regression. The current 10,000-case no-tee/no-structure lane matches 10,000/10,000 with zero failures.

## Current maintenance rule

- Treat this folder as the canonical home for future `simplify-locals` parity and scheduler research.
- Keep the main correction explicit:
  - Binaryen `simplify-locals` is a staged locals pass family, not one adjacent-peephole transform
- Keep the variant matrix, late equivalent-copy phase, and split validation-repair story explicit whenever future docs or code changes touch this pass.
- Keep the older Starshine-port pages, but do not let them silently replace the official Binaryen `version_131` contract on the landing page.

## 2026-08-24 AssemblyScript structured-scan repair

The current `json-as` O4z smoke found that `simplify_locals_has_control_embedded_local_tee(...)` visited structured region children twice: once through generic child slots and again through the explicit block/loop/if/try region cases. A roughly 60-level AssemblyScript dispatcher therefore expanded exponentially before the no-structure pass even entered its main cycle. Generic traversal now skips region child slots and leaves each structured body to its explicit region traversal. The focused 60-level regression passes, and direct `simplify-locals-nostructure` on retained `naive/bool.spec.wasm` falls from beyond 600 seconds to `0.114s`.

This repair is traversal-only: it changes neither tee classification nor rewrite admission. The final current-native production O4z structural matrix optimizes and independently validates all `105/105` pinned naive/SWAR/SIMD artifacts with no timeout.

## Sources

- research note 0148
- research note 0241
- research note 0076
- [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- [`../../../../../src/passes/simplify_locals_test.mbt`](../../../../../src/passes/simplify_locals_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../tracker.md`](../tracker.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- Binaryen `version_131` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/SimplifyLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/equivalent_sets.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/local-utils.h>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>
