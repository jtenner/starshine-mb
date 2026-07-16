---
kind: research
status: active
created: 2026-07-16
updated: 2026-07-16
sources:
  - ../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../src/passes/dead_argument_elimination_wbtest.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ./1629-2026-07-16-daeo-direct-gc-batch-performance.md
  - ./1627-2026-07-16-daeo-consumed-call-argument-slot-checkpoint.md
---

# DAEO forwarded-cycle priority and multi-cycle recovery

## Behavior discrepancy

Checkpoint `1629` made large-module direct-GC collection substantially faster, but the earlier large-module convergence batches expanded the touched-definition set from the narrow checkpoint-`1627` neighborhood to thousands of definitions. `dae_collect_forwarded_param_cycle_defs` returned the first touched cycle in definition order. That made an unrelated cycle around definitions `5167`/`5168` win before the broad adjacent candidate already selected at definitions `7007`/`7008`.

The resulting behavior regression was visible in the self-host artifact: Starshine retained an extra `i32` parameter on Funcs `7007` and `7008`, skipped the previously proven forwarding-component transaction, and increased those canonical function bodies by `1522` and `992` bytes relative to checkpoint `1627`. Binaryen v130 removes that parameter from both functions.

## Retained fix

- `dae_collect_forwarded_param_cycle_defs` accepts an ordered preferred-definition list, deduplicates it, and scans those touched definitions before the remaining touched set.
- The DAEO scheduler supplies the two definitions from the already selected broad adjacent candidate as preferred cycle seeds.
- All existing cycle/component safety checks remain authoritative; preference changes only which independently eligible touched cycle is processed first.
- A white-box regression constructs two touched forwarding cycles and proves that the explicitly selected later cycle wins over the earlier unrelated cycle.

The artifact trace again reports:

```text
pass[dae-optimizing]:forwarded-param-cycle-precompute defs=[7007, 7008, 7010]
pass[dae-optimizing]:forwarded-param-component-transaction defs=[7008, 7007, 7010] params=3
```

## Multi-cycle convergence follow-up

Priority restores the selected component, but Binaryen does not stop after one forwarding cycle. Starshine's collector still returned only one cycle, so other touched cycles never received the optimizing-only precompute replay. The follow-up:

- lets cycle discovery exclude already processed component definitions;
- collects all currently visible distinct cycles from one call-boundary/type snapshot instead of rebuilding whole-module facts once per cycle;
- runs one `precompute-propagate-prefix` batch over the union of each discovery round;
- repeats batch rounds until no new nonoverlapping cycle remains, removing the arbitrary eight-cycle stop;
- preserves the existing dead-callee and forwarding-component transactions where their complete safety proofs succeed;
- unions changed component definitions for the existing bounded post-component cleanup.

A strengthened white-box test proves preferred ordering plus independent-cycle continuation. A red-first public regression constructs nine touched forwarding-only cycles; the old eight-cycle stop left the ninth pair parameterized, while the retained implementation removes all eighteen parameters. On the self-host artifact the selected `7007`/`7008`/`7010` component is processed first, followed by eleven distinct cycle neighborhoods. The final batched-round output is byte-identical to the slower per-cycle unbounded probe, proving that batching changes scheduling cost rather than retained behavior.

## Artifact result

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Current output: `.tmp/daeo-final-behavior-20260716/out.wasm`.

- validates with `wasm-tools --features all`;
- raw size: `3207779` bytes, `4827` bytes smaller than checkpoint `1629` and `359` smaller than the eight-cycle slice;
- Binaryen-v130 canonical size: `3269948` bytes, `5110` bytes smaller than checkpoint `1629` and `361` smaller than the eight-cycle slice;
- raw SHA-256: `19b3afee6ff45a7c6b03003c6e7f556306467ce8a8623ab7aaffaf8d8aa5ed53`;
- canonical SHA-256: `127d3872bce6750b94788295ca7d1fd2c0866c11320e85c7414a6d8df10341a2`;
- Binaryen-v130 canonical reference: `3262456` bytes;
- remaining canonical gap: `+7492` bytes, down from `+12602`;
- code-section gap: `+8621` bytes, partly offset by a `-1136` type-section delta;
- traced DAEO time: `51903360us`.

This clears the user's 10KB size boundary with source-backed convergence behavior rather than an artifact-local shape rule. It is not parity or performance closeout. The leading positive body owners remain Func `8429 +1299`, Func `9347 +1258`, Func `8187 +1241`, Func `41 +1219`, and Func `7556 +1126`. The all-cycle behavior is now complete for the current snapshot, but runtime remains severely over target; further work should retain this output while replacing repeated large-module setup and transaction scans.

## Validation

- red first, priority: `dead_argument_elimination_wbtest.mbt` failed because the cycle collector had no `preferred_defs` contract;
- red first, convergence: the strengthened white-box test returned the excluded selected cycle instead of the next independent cycle;
- red first, cap removal: the nine-cycle public fixture left the ninth pair parameterized after eight component transactions;
- focused white-box: `208/208` passed;
- focused DAEO: `332/332` passed;
- `moon info`: passed with pre-existing warnings;
- `moon fmt`: passed; `moon.mod` was restored to the repository spelling;
- full Moon: `8877/8877` passed;
- native release build passed; final binary SHA-256 `7aeb0295c535c0eecef1c588ea665973c752e2c4e06b76733cea4ebe67dcc880`;
- dedicated DAEO GenValid smoke: `1000/1000` normalized, zero failures;
- regular GenValid smoke: `1000/1000` normalized, zero failures.

Both `1000`-case smokes were rerun after the final batched-round convergence follow-up and remained fully normalized with zero failures.
