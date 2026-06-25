# 0886 - code-pushing-all post-0884 smoke

Date: 2026-06-25

## Question

After the `0884` nested disjoint-global pure-root behavior change and the `0885` nested call-valued boundary coverage, run a bounded dedicated aggregate smoke to catch immediate regressions before handing off. This is not final closeout evidence.

## Commands

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --out-dir .tmp/pass-fuzz-code-pushing-all-post-0884-smoke-1000-local-cleanup --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --normalize local-cleanup-debris
```

## Results

`moon build --target native --release src/cmd` passed and produced `_build/native/release/build/cmd/cmd.exe`; the build printed the same pre-existing pass-manager unused-function warnings observed in earlier slices.

The bounded dedicated smoke wrote artifacts to `.tmp/pass-fuzz-code-pushing-all-post-0884-smoke-1000-local-cleanup` and reported:

- jobs: `16`
- compared cases: `1000/1000`
- normalized matches: `466`
- compare-normalized matches: `534` under `--normalize local-cleanup-debris`
- raw mismatches: `0`
- validation failures: `0`
- generator failures: `0`
- property failures: `0`
- command failures: `0`
- Binaryen cache: `1000 hits/0 misses`
- Binaryen failure cache: `0 hits/0 misses`
- wasm-smith cache: `0 hits/0 misses`

## Classification

This is bounded regression smoke evidence only. The `534` compare-normalized cases are agent-classified as the already documented local-cleanup/lowering debris family covered by `local-cleanup-debris`; they are not raw semantic mismatches and are not harness proof of broad semantic equivalence.

## Follow-up

Final `[O4Z-AUDIT-CP]` closeout remains blocked. Because `0884` changed behavior, closeout still needs post-`0884` regular GenValid `100000`, explicit wasm-smith `10000`, dedicated `code-pushing-all` `10000`, and broad named `pass-fuzz-stress` `10000` lanes plus a source-backed stop condition.
