---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ./1631-2026-07-17-daeo-func8429-payoff-convergence.md
---

# DAEO Func 8187 normalized-literal chain

## Goal

Close the defined Func `8187` / absolute Func `8208` artifact gap against Binaryen v130 while preserving plain-DAE separation, valid wasm, one-invocation convergence, the established `< +10000` canonical-module boundary, and explicit performance accounting.

The pre-slice canonical body was `2202` bytes versus Binaryen's `961`, a `+1241` parity gap. The accepted pre-slice traced DAEO reference was `71492436us`.

## Attribution

The first source-backed owner was a high-definition direct-call chain. A small normalized/default literal root became constant only after DAE materialization and touched cleanup, then exposed the same exact value through two private direct callees. The existing exact-literal transaction already owned the safety proof: current direct callers, escape state, call multiplicity, call operands, read-only parameters, signature rewrite, callsite rewrite, validation, and rollback. The missing behavior was bounded high-module scheduling and same-invocation cleanup.

After parameter removal, Func `8187` still retained Binaryen cleanup families around selected local/control carriers: constant `if` conditions, dead tee/set traffic, local declarations, dropped result blocks, terminal self-branch wrappers, `i32.const 0; i32.eq`, one-use spills, loop iteration aliases, and paired nullable field guards. These are optimizing-after-inlining cleanup gaps, not plain DAE behavior.

## Retained implementation

- Large-module discovery scans only defined functions at or above `4096` whose bounded recursive instruction count is at most `64`.
- Candidate callees must also be high definitions with at most `64` instructions. A depth-two direct-callee payoff ranks the chain, and the expensive lane requires payoff at least `2048`.
- The seed and every downstream rewrite use `dae_try_rewrite_exact_literal_def_with_facts_once(...)`; the scheduler does not add a second signature-rewrite proof.
- One current call-fact snapshot is reused because selected parameter removal and local cleanup do not change direct caller identity, escape state, or call multiplicity. Downstream candidates remain bounded to the seed's nearby definition neighborhood.
- Each frontier receives `precompute-propagate-prefix` and `optimize-instructions`; `vacuum` runs only after an exact-literal rewrite exposes a downstream frontier, not for the initial seed or unread-only frontier.
- The final productive definition alone receives coalescing, dead-write cleanup, structural cleanup, one required cleanup round, local reordering, selected-function validation, and strict encoded-size profitability. The whole final cleanup transaction rolls back unless the selected function is valid and smaller.
- The structural cleanup includes paired nullable-guard flattening, `i32.const 0; i32.eq -> i32.eqz`, dropped `i32` result-block voiding, terminal self-branch flattening, loop-iteration alias coalescing, one-use spill sinking, dead tee/set removal, and local compaction.
- Constant-`if` folding removes a selected label only when the retained arm has no label-sensitive branch. A local constant is accepted only from an immediately preceding `i32.const; local.set` with no intervening reference to that local.
- When the broad high chain changes the module, simple type pruning remains bypassed because remapping the grouped fresh signature neighborhood is not yet proved safe.
- Plain `dead-argument-elimination` does not schedule the broad high chain or its selected structural cleanup.

A high-module regression uses `8192` dummy definitions and `768` guarded leaf calls. It proves plain DAE keeps the three parameters, DAEO removes all three in one invocation, the leaf's guarded effects disappear only after the condition is proved false, the output validates, and the trace reports the selected chain. A white-box guard separately locks the zero-equality, dropped-result-block, and terminal-self-branch structural primitives.

Code review found no newly added unreachable helper: every broad-high helper has a production caller, and `moon info` reports only pre-existing warnings. The final cleanup loop was reduced from two rounds to one after the one-round artifact was byte-identical to the accepted endpoint. A zero-round probe is not acceptable: it improves runtime under contention but leaves Func `8187` at `1028`, above Binaryen's `961`.

## Artifact result

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Accepted current artifacts: `.tmp/daeo-func8187-final-bench-20260717/`.

- raw size: `3203546` bytes;
- canonical size: `3264761` bytes;
- Binaryen-v130 canonical module: `3262456` bytes;
- canonical module gap: `+2305`;
- raw SHA-256: `748c4d42906017f629d99125a5262af126d995629fa06c959c1806df92c4e4de`;
- canonical SHA-256: `25c2852eaaa5ebb90963a58ce58ddcab0376a9ef2e77b0729edea6ba35c41b6e`;
- native SHA-256: `970bb7456dba663dbd566bbbd789d5543d8eb1960a1fdc44662b56fb2ad030bf`.

Canonical body matrix:

| defined Func | Starshine | Binaryen v130 | delta |
|---:|---:|---:|---:|
| `8184` | `40` | `11` | `+29` |
| `8185` | `2978` | `2429` | `+549` |
| `8186` | `218` | `10` | `+208` |
| `8187` | `767` | `961` | `-194` |
| `8429` | `25694` | `25742` | `-48` |
| `9347` | `14706` | `15405` | `-699` |

Func `8187` improves by `1435` canonical body bytes from the pre-slice `2202` and beats the requested Binaryen body ceiling by `194` bytes. The first and second DAEO outputs are byte-identical in raw and Binaryen-v130 `--all-features -O0` canonical form, and both validate with `wasm-tools validate --features all`.

## Performance judgment

Performance is explicitly not presented as an uncontaminated pre-slice win.

- The best earlier stable equivalent endpoint measured `77225519us` pass-local and `79.09s` wall, about `8.0%` above the `71492436us` pre-slice trace.
- The broad-high profile attributed about `5.94s` to the new lane: roughly `0.01s` discovery, `0.14s` seed proof, `4.15s` frontier rounds, and `1.64s` final selected cleanup.
- Two fresh CPU-affinity repeats in `.tmp/daeo-func8187-final-bench-20260717/` measured `115034662us` and `113604121us`, but their start snapshots record concurrent `100000`-case `simplify-locals-nonesting` fuzzing and load averages around `11-12`; they are contamination evidence, not the accepted baseline.
- Removing the required final cleanup round produced Func `8187` body `1028`, so the remaining runtime tradeoff is concrete: at least one selected cleanup round is required to satisfy the `<=961` body target. The redundant second final round was removed because one round is byte-identical.
- The converged second invocation is much cheaper: `5488417us` pass-local / `7.22s` wall in the final artifact directory.

The slice therefore records a small stable runtime regression rather than hiding it. The accepted tradeoff buys a `1435`-byte Func `8187` reduction and keeps the canonical module only `+2305` over Binaryen. Future performance work should replace the selected frontier's repeated generic hot-pass setup with equivalent function-local cleanup; it must not drop the required round or weaken exact-literal, validation, profitability, or plain-DAE guards.

## Validation

- `moon info`: passed with pre-existing warnings;
- `moon fmt`: passed;
- `pass_manager_wbtest.mbt`: `267/267`;
- `dae_optimizing_test.mbt`: `336/336`;
- full `moon test`: `8883/8883`;
- native release build: passed;
- first/second `wasm-tools validate --features all`: passed;
- first/second raw and canonical `cmp`: byte-identical;
- dedicated profile `.tmp/pass-fuzz-dae-optimizing-func8187-final-profile-1000`: `1000/1000` normalized, zero cleanup-normalized matches, mismatches, validation/generator/property/command failures, Binaryen cache `1000/0`;
- regular GenValid `.tmp/pass-fuzz-dae-optimizing-func8187-final-regular-1000`: `1000/1000` normalized, zero cleanup-normalized matches, mismatches, validation/generator/property/command failures, Binaryen cache `1000/0`.

The full four-lane DAEO closeout matrix was not rerun for this focused body slice. The Func `8187` follow-up is closed; the wider DAEO audit remains active on Funcs `8184`, `8185`, `8186`, other body/module parity owners, full closeout refresh, and the documented pre-slot public optimize/shrink/O4z blockers.
