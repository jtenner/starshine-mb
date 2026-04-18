# 0108 - Generated `-O4z` slot 40 `remove-unused-brs` retired by tail value-if rewrite guard

## Status

- Date: 2026-04-18
- Type: One-off repair note
- Retires: [O4Z]006 in `agent-todo.md`
- Prior capture: [0099 - generated `-O4z` slot 40 later `remove-unused-brs` invalid block stack state](./0099-2026-04-18-generated-o4z-rub-slot40-block-stack-leak.md)

## Scope

- Binaryen slot: `40`
- Observed Binaryen pass: `remove-unused-brs`
- Starshine pass: `--remove-unused-brs`
- Saved predecessor input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/26-slot37-vacuum/binaryen.wasm`
- In-tree fix surface:
  - `src/passes/remove_unused_brs.mbt`
  - `src/cmd/cmd_wbtest.mbt`
  - `src/passes/remove_unused_brs_test.mbt`

## Failure recap

The saved slot-40 predecessor stayed valid, but Starshine's later `remove-unused-brs` replay emitted invalid raw wasm. `wasm-tools validate` reported `values remaining on stack at end of block`, while Binaryen's validator reported an `if-else` arm type mismatch during canonicalization.

The current tree also reproduced the corruption on an extracted single-function replay:

- `_build/native/release/build/cmd/cmd.exe --extract-functions=3863 --remove-unused-brs --out ... 26-slot37-vacuum/binaryen.wasm`
- `wasm-tools validate ...`

That extracted replay isolated the same family to one function while keeping the invalid stack leak.

## Findings

### 1. The failing family was tied to Starshine's `rewrite-tail-value-if-simple-payload-arm`

Temporary local tracing showed the invalid extracted function repeatedly taking Starshine's `rewrite-tail-value-if-simple-payload-arm` path before later lowering produced the bad typed-block / `if` stack state.

Disabling just that rewrite locally made both of these replays valid again:

- extracted `Func 3863`
- full slot-40 predecessor replay on `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/26-slot37-vacuum/binaryen.wasm`

This is a direct observation from the saved predecessor and current in-tree replay, not an inference.

### 2. The corruption is a composition bug, not proof that every Binaryen-style tail payload rewrite is wrong

Binaryen's `RemoveUnusedBrs` implementation has a `restructureIf` path in `src/passes/RemoveUnusedBrs.cpp` that rewrites certain value-`if` payload shapes into a surrounding result block plus guarded branch pattern. That upstream intent explains why Starshine had an analogous rewrite at all.

Source:
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedBrs.cpp>

Inference from the upstream source plus the slot-40 replay:
- the local Starshine rewrite shape is not inherently illegitimate
- but Starshine's current rewrite contract is still too weak when later lowering / restructuring composes with these carried-value tails inside the generated-artifact slot-40 family

### 3. The conservative safe fix is to retire the rewrite until a narrower valid-context contract exists

The landed tree now keeps `remove_unused_brs_try_rewrite_tail_value_if_simple_payload_arm` disabled with an in-file note that the slot-40 family still corrupts stack state after later composition.

That guard is intentionally conservative:
- it fixes the hard corruption on the real generated-artifact predecessor
- it keeps the slot-40 compare canonically equal after normalization
- it records that the rewrite should be re-landed only after a smaller valid-context slice is reduced and covered with oracle-backed tests

## Validation

Focused validation run for the landed tree:

1. `moon test --target native --package jtenner/starshine/cmd --file cmd_wbtest.mbt --filter 'run_cmd_with_adapter keeps extracted generated O4z slot40 remove-unused-brs output wasm-tools-valid'`
2. `moon test --target native --package jtenner/starshine/passes --file remove_unused_brs_test.mbt --filter 'remove-unused-brs keeps nested returned ladder branch exits stable under returned value-if ladders'`
3. `moon build --target native --release --package jtenner/starshine/cmd`
4. `_build/native/release/build/cmd/cmd.exe --remove-unused-brs --out .artifacts/tmp-direct-rub-slot40-fixed.raw.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/26-slot37-vacuum/binaryen.wasm`
5. `wasm-tools validate .artifacts/tmp-direct-rub-slot40-fixed.raw.wasm`
6. `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/26-slot37-vacuum/binaryen.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .artifacts/tmp-self-opt-rub-slot40-fixed --remove-unused-brs`

Result summary:

- direct full replay: valid raw wasm
- extracted replay: valid raw wasm
- compare harness: `normalizedWatEqual=true` and `canonicalFuncPrettyEqual=true`

## Durable conclusion

`[O4Z]006` is retired by a conservative Starshine-side guard: the repo now prefers a no-op over the still-unsafe `rewrite-tail-value-if-simple-payload-arm` transformation on the slot-40 family. The remaining follow-up is not this corruption anymore; it is future, narrower re-enablement work with explicit oracle-backed context rules.
