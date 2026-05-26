# DAE003 closeout evidence

Date: 2026-05-26

## Scope

Close `[DAE003-I]`: decide whether any current known artifact or fuzz frontier is attributable to missed safe constant-actual or unread-parameter materialization after the DAE003 carrier, wrapper-chain, immutable-global, and starvation slices through research note `0660`.

This is a classification/evidence slice. It does not change optimizer behavior.

## Sources reviewed

- `agent-todo.md` DAE checkpoints and `[DAE]003` / `[DAE]004` active subtasks.
- `docs/wiki/binaryen/passes/dae-optimizing/starshine-strategy.md` current DAE implementation and frontier status.
- DAE003 research notes `0627`, `0636`, `0638` through `0660`.
- DAE004 research notes `0628` through `0637` for the still-open dropped-result scheduler/fallback frontier.

## Evidence

### Direct fuzz refresh

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae003i-closeout-20260526
```

Result:

- Compared cases: `45/10000`
- Normalized matches: `26`
- Mismatches: `19`
- Validation failures: `0`
- Generator failures: `0`
- Command failures: `1`

Agent classification: the 19 mismatches remain in the already accepted DAE010/DAE011 `gen-valid` raw-cleanup family, not a constant/unread materialization frontier. The classification is based on the existing inspected DAE010 transform contract and follow-up DAE003 notes: Starshine strips audited pure/nontrapping dropped debris that Binaryen preserves on generator-valid cases, while validation remains green and wasm-smith accepted cases have matched in the full accepted lanes. The single command failure is a Binaryen/tool failure, not a Starshine validation failure.

### Debug artifact timing/validation replay

Command:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --canonicalize-binaryen-output --dae-optimizing --timing-only --out-dir .tmp/dae003i-artifact-timing-20260526
```

Result:

- Canonical wasm equal: `no`
- Starshine runtime: `2096.913ms`
- Binaryen runtime: `1200.894ms`
- Starshine pass runtime: `1721.182ms`
- Binaryen pass runtime: `902.489ms`

The pass-local ratio remains within the project target (`1721.182ms <= 2 * 902.489ms`). The output validates:

```sh
wasm-opt --all-features .tmp/dae003i-artifact-timing-20260526/starshine.wasm -o /tmp/dae003i-validated.wasm
```

This emitted only the existing large-local-count VM warning.

## Frontier classification

No current known frontier is attributed to missed safe constant/unread materialization:

- Raw/default debug-artifact first diffs remain documented type-section/type-index diagnostic drift under `[DAE]005`.
- Both-canonical Func509 remains the closed lowerer/diagnostic boundary under `[DAE]006`, not a DAE final-hook or constant/unread materialization miss.
- DAE003 constant/unread breadth now has current v0.1.0 coverage and closure notes for inventory, current-frontier classification, non-adjacent local carriers, wrapper chains, conservative recursive/self/escaped policy, structured carriers, immutable globals, and starvation/iteration-budget evidence.
- Remaining active DAE work is `[DAE]004`: selected dropped-result scheduling/fallback removal and its final artifact/fuzz closeout. Research notes `0628` and `0629` classify the still-productive selected fallback entries as blocked first by large-module ordering plus the eight-productive-attempt cap, not by stale constant/unread facts.

## Decision

Close `[DAE003-I]` and therefore close `[DAE]003` for the current v0.1.0 surface.

Deferred future behavior-widening areas from DAE003-F, such as branchy/computed multi-instruction carriers or broader control-sensitive try/if/loop positives, are not active v0.1.0 blockers unless a new artifact/fuzz frontier or semantic/validation repro attributes a miss to those families.

DAE remains incomplete because `[DAE]004` is still open.
