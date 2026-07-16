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

# DAEO forwarded-cycle priority recovery

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

## Artifact result

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Output: `.tmp/daeo-cycle-priority-20260716/out.wasm`.

- validates with `wasm-tools --features all`;
- raw size: `3210126` bytes, `2480` bytes smaller than checkpoint `1629`;
- Binaryen-v130 canonical size: `3272468` bytes, `2590` bytes smaller than checkpoint `1629`;
- Binaryen-v130 canonical reference: `3262456` bytes;
- remaining canonical gap: `+10012` bytes, down from `+12602`;
- traced DAEO time: `34029047us`.

The size regression is mostly recovered, but the pass remains twelve bytes beyond the literal 10KB boundary and far from behavior-parity closeout. The remaining leading positive body owners are Func `8429 +1299`, Func `9347 +1258`, Func `8187 +1241`, Func `41 +1219`, and Func `7556 +1126`. The next slices should continue source-backed optimizing-after-inlining behavior rather than resume artifact-local carrier micro-matching.

## Validation

- red first: `dead_argument_elimination_wbtest.mbt` failed because the cycle collector had no `preferred_defs` contract;
- focused white-box: `208/208` passed;
- focused DAEO: `331/331` passed;
- `moon info`: passed with pre-existing warnings;
- `moon fmt`: passed; `moon.mod` was restored to the repository spelling;
- full Moon: `8876/8876` passed;
- native release build passed;
- dedicated DAEO GenValid smoke: `1000/1000` normalized, zero failures;
- regular GenValid smoke: `1000/1000` normalized, zero failures.
