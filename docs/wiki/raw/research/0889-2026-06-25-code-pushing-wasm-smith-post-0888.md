# 0889 - code-pushing wasm-smith post-0888 refresh

Date: 2026-06-25

## Question

Refresh the required explicit `wasm-smith` lane after the current post-`0884` behavior and post-`0887`/`0888` evidence, using the current native Starshine binary.

## Command

```sh
bun scripts/pass-fuzz-compare.ts \
  --wasm-smith \
  --count 10000 \
  --seed 0x5eed \
  --pass code-pushing \
  --out-dir .tmp/pass-fuzz-code-pushing-wasm-smith-10000-20260625-post-0888 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

## Result

`.tmp/pass-fuzz-code-pushing-wasm-smith-10000-20260625-post-0888`:

- requested: `10000`
- compared: `9956`
- normalized matches: `9956`
- cleanup-normalized matches: `0`
- raw mismatches: `0`
- validation failures: `0`
- generator failures: `0`
- property failures: `0`
- command failures: `44`
- jobs: `16` (`--jobs auto`)
- cache: wasm-smith `10000 hits/0 misses`; Binaryen `9956 hits/0 misses`; Binaryen failures `44 hits/0 misses`

Command-failure classes from `summary.json`:

- `binaryen-rec-group-zero`: `39`
- `binaryen-bad-section-size`: `3`
- `binaryen-invalid-tag-index`: `1`
- `binaryen-table-index-out-of-range`: `1`

Feature counts from `summary.json` included `optional_input_has_exception: 7039`, `optional_input_has_call: 2837`, `optional_input_mutates_memory: 1728`, `optional_input_mutates_global: 250`, `optional_input_mutates_table: 227`, and `optional_input_has_atomics: 170`.

## Classification

The compared wasm-smith cases are green post-`0888` evidence: `9956` normalized matches, no raw mismatches, no validation failures, no generator failures, and no property failures. The `44` command failures are classified separately as cached Binaryen/tool failure classes, not Starshine semantic mismatches.

## Follow-up

This satisfies the current explicit wasm-smith 10000 final-closeout lane for post-`0884`/post-`0887` evidence. Final `[O4Z-AUDIT-CP]` closeout is still blocked by the post-`0884`/post-`0887` regular GenValid 100000, broad named `pass-fuzz-stress` 10000, and explicit source-backed stop condition.
