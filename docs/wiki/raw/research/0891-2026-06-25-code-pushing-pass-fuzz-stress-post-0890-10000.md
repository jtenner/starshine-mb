# 0891 - code-pushing pass-fuzz-stress post-0890 10000 refresh

Date: 2026-06-25

## Question

Refresh the required broad named GenValid `pass-fuzz-stress` 10000 lane after the current post-`0884` behavior and post-`0888`/`0889`/`0890` final-lane evidence, using the current native Starshine binary.

## Command

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5555 \
  --pass code-pushing \
  --gen-valid-profile pass-fuzz-stress \
  --out-dir .tmp/pass-fuzz-code-pushing-pass-fuzz-stress-10000-20260625-post-0890 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

## Result

`.tmp/pass-fuzz-code-pushing-pass-fuzz-stress-10000-20260625-post-0890`:

- requested/compared: `10000/10000`
- normalized matches: `10000`
- cleanup-normalized matches: `0`
- raw mismatches: `0`
- validation failures: `0`
- generator failures: `0`
- property failures: `0`
- command failures: `0`
- jobs: `16` (`--jobs auto`)
- cache: wasm-smith `0 hits/0 misses`; Binaryen `10000 hits/0 misses`; Binaryen failures `0 hits/0 misses`
- selected profile: `pass-fuzz-stress: 10000`

## Classification

This is green post-`0890` broad named GenValid evidence: all `10000` compared `pass-fuzz-stress` cases normalized, and there were no raw mismatches, validation failures, generator failures, property failures, or command failures. No cleanup-normalized classification was needed for this lane.

## Follow-up

This satisfies the current broad named `pass-fuzz-stress` 10000 final-closeout lane for post-`0884`/post-`0887` evidence. The four current final-lane direct-compare artifacts are now `0888` dedicated `code-pushing-all`, `0889` explicit wasm-smith, `0890` regular GenValid, and this `0891` broad named lane. Final `[O4Z-AUDIT-CP]` closeout still needs an explicit source-backed stop condition and must not overclaim broad unimplemented families as closed unless the closeout documents narrow acceptance/reopen criteria.
