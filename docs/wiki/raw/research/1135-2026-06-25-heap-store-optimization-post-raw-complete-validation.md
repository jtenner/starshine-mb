---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1134-2026-06-25-heap-store-optimization-raw-complete-default-chain.md
  - ./1133-2026-06-25-heap-store-optimization-speed-parity-target.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# HSO post-raw-complete validation and timing closeout

## Question

After the raw complete-default-chain path in `1134`, is the allocation-heavy speed-parity target met under both traced pass-local accounting and a whole-command sanity check, and does the direct HSO compare lane remain green?

## Answer

Yes for the current synthetic allocation-heavy fixture and ordinary direct GenValid lane. The 2000-function fixture now raw-skips every function before HOT execution, so no `pass:heap-store-optimization` timer is emitted. Under the existing pass-local timing convention this is `0ms` traced HSO time, below the `1133` `<=1.357ms` target.

A separate no-tracing whole-command sanity check shows that the raw rewrite does not merely hide a slower path outside the pass timer on this fixture: local Starshine command median was `28.271ms`, while local Binaryen `wasm-opt --heap-store-optimization` command median was `30.112ms` on the same input. These are local wall-clock sanity numbers, not a portable benchmark threshold.

## Evidence

Pass package validation:

```sh
moon test src/passes
```

Result: `3045/3045` passed.

No-tracing whole-command timing sanity check, with output validation after each run:

```sh
target/native/release/build/cmd/cmd.exe   --heap-store-optimization   .tmp/hso-allocation-heavy-candidates-2000-20260625.wat   -o .tmp/hso-raw-complete-default-wall-star.<n>.wasm
wasm-tools validate --features all .tmp/hso-raw-complete-default-wall-star.<n>.wasm

wasm-opt --all-features   .tmp/hso-allocation-heavy-candidates-2000-20260625.wat   --heap-store-optimization   -o .tmp/hso-raw-complete-default-wall-bin.<n>.wasm
wasm-tools validate --features all .tmp/hso-raw-complete-default-wall-bin.<n>.wasm
```

Samples:

- Starshine: `29.137ms`, `27.562ms`, `28.271ms`, `27.079ms`, `38.715ms`; median `28.271ms`.
- Binaryen: `35.214ms`, `30.112ms`, `29.925ms`, `29.864ms`, `31.693ms`; median `30.112ms`.

Direct GenValid compare:

```sh
bun scripts/pass-fuzz-compare.ts   --count 10000   --seed 0x5eed   --pass heap-store-optimization   --out-dir .tmp/pass-fuzz-heap-store-optimization-raw-complete-default-10000   --jobs auto   --starshine-bin target/native/release/build/cmd/cmd.exe   --max-failures 2000   --keep-going-after-command-failures
```

Result:

- requested/compared: `10000/10000`
- normalized matches: `10000`
- compare-normalized matches: `0`
- mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `0`
- cache: wasm-smith `0` hits / `0` misses; Binaryen `10000` hits / `0` misses; Binaryen failures `0` hits / `0` misses

## Interpretation

HSO-I can be treated as resolved for the current allocation-heavy fixture and speed-parity target: traced pass-local time is below target, and local whole-command timing is not slower than Binaryen on the same fixture. Reopen HSO-I if a broader artifact/neighborhood replay shows HSO-owned slowdown, if the raw path regresses direct compare or validation, if the user requires raw rewrite work to be included in pass-local timing instead of whole-command sanity accounting, or if a new allocation-heavy source family bypasses the raw complete-chain shape and misses the `0.95x` Binaryen-speed target.

HSO-J remains open. Final closeout still needs the full final validation/compare matrix, refreshed O4z slot/neighborhood evidence where required, docs/wiki/log updates, and backlog cleanup.
