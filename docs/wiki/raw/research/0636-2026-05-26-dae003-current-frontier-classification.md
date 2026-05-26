# DAE003 current frontier classification

Date: 2026-05-26

## Question

Close `[DAE003-B]`: reproduce or classify whether the current `dae-optimizing` debug-artifact/frontier misses are still attributable to constant-actual or unread-parameter materialization.

## Evidence checked

- Backlog checkpoints in `agent-todo.md` after notes `0606`, `0627`, and `0635`.
- Current Starshine strategy page `docs/wiki/binaryen/passes/dae-optimizing/starshine-strategy.md`.
- Existing current-frontier notes:
  - `0586` through `0591`: both-canonical Func509 frontier, closed as a lowerer/diagnostic boundary.
  - `0628` and `0629`: selected dropped-result fallback inventory and gap classification.
  - `0631` and `0632`: large-module result-removal worklist design and rejected broad active switch.
  - `0633` through `0635`: mixed-call and dead-suffix dropped-result policy/repair coverage.
- Recovery replay attempt:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --canonicalize-binaryen-output --dae-optimizing --out-dir .tmp/dae003b-current-frontier-20260526`
  - The full normalized compare timed out at 120s while writing outputs. The produced Starshine wasm validated with `wasm-opt --all-features .tmp/dae003b-current-frontier-20260526/starshine.wasm -o /tmp/dae003b.valid.wasm`, with only the known large-local-count VM warning.
  - A raw printed-WAT line diff on those partial outputs still starts in type-section/type-index representation (`type $1` result arity drift), matching the already documented raw diagnostic boundary rather than a body-level constant/unread-parameter miss.

## Classification

No current leading artifact/frontier miss is attributed to missed safe constant-actual or unread-parameter materialization.

Current known DAE frontiers classify elsewhere:

1. Raw/default artifact first diff: type-section/type-index representation drift from `[DAE]005`, not DAE003 body materialization.
2. Both-canonical body frontier: Func509 lowerer/diagnostic dead-return-suffix boundary from `[DAE]006`, not an exact-literal or unread-param candidate.
3. Large debug-artifact selected dropped-result changes: `[DAE]004` scheduling/fallback gaps, first blocked by ordering plus productive-attempt cap per `0629`, not stale constant/unread facts.
4. Direct fuzz raw-cleanup mismatch set: accepted size-winning semantic-safe cleanup drift from `[DAE]010`/`[DAE]011`, not constant/unread materialization.

## Result

`[DAE003-B]` is closed as a classification slice. Remaining `[DAE]003` implementation work should target new focused generalization surfaces (`[DAE003-C]` through `[DAE003-H]`) or a new artifact/fuzz repro specifically attributed to missed constant/unread materialization. Do not broaden constant/unread behavior just to chase the current raw type-index boundary, Func509 lowerer boundary, or `[DAE]004` dropped-result fallback gaps.
