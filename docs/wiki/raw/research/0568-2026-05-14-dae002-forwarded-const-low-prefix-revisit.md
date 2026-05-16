# DAE002 forwarded-const low-prefix revisit moves the core frontier but not the artifact diff

Date: 2026-05-14

## Question

Can a narrow forwarded-const analysis plus a low-index exact-literal revisit move the live DAE002 artifact frontier beyond Func 42 on `tests/node/dist/starshine-debug-wasi.wasm`?

## Result

Partially.

The new slice does two things safely:

1. exact-literal analysis can now see through wrapper-local `local.get` forwarding chains on private direct-call families; and
2. after the existing reverse exact-literal lane, DAE now runs a **low-prefix forward exact-literal revisit** over the first `64` defined functions.

That combination changes the DAE core frontier on the original artifact from:

- `11, 227, 233, 236, ...`

to:

- `11, 25, 227, 233, ...`

So Func 42 is now reached as the **second productive core rewrite** on the original artifact.

However, the full `--dae-optimizing` artifact compare still differs first at:

- `defined=25 abs=42`

So this slice improves candidate reach, but it does **not** complete Func 42 parity by itself.

## What changed

### Forwarded-const analysis

The exact-literal collector now resolves a narrow extra family:

- a call actual that is a `local.get` of a read-only callee parameter in a private direct caller,
- when that caller itself has a uniform exact-literal actual for the same parameter.

This is recursive and bounded by a visited set, so tiny forwarding chains can be seen directly without waiting for every wrapper to rewrite first.

### Low-prefix revisit

After the existing reverse exact-literal lane, DAE now runs a forward exact-literal-only revisit over the first `64` defined functions.

This is intentionally narrower than rerunning the full core:

- it reuses the exact-literal-only safety lane,
- it does **not** run the broader dead-suffix/result-removal logic again,
- and it was added specifically to avoid the earlier self-call / escaped-result regressions that broad extra sweeps reintroduced.

## Evidence

### Reduced repros

Focused regressions now show:

- forwarded-const analysis can recover a reverse-starved wrapper-chain callee once it falls inside the low-prefix revisit window;
- the earlier reduced starvation repro still works;
- the escaped self-call operand preservation regression (`case 000690`) still passes after narrowing the revisit to exact-literal-only work.

### Whitebox artifact characterization

`src/passes/pass_manager_wbtest.mbt` now shows:

- first `12` productive core rewrites start with `11, 25, 227, 233, 236, 237, 246, 256, 267, 268, 287, 288`;
- the first two productive core rewrites are now `11, 25`;
- Func 42 exact-literal facts are visible on the original artifact;
- the bounded reverse frontier changed, but the real artifact compare still reports the first differing function at Func 42.

### End-to-end artifact compare

The focused compare remains red:

- out dir: `.tmp/dae002-forwarded-const-low-revisit-artifact`
- first diff: `defined=25 abs=42`
- Starshine pass runtime: `108970.725ms`
- Binaryen pass runtime: `934.554ms`

## Interpretation

This narrows the open problem:

- the remaining Func 42 gap is **no longer just candidate reach starvation in the core**, because the core now reaches Func 42 immediately after Func 28;
- but it is **also not full artifact parity yet**, because the final compare still differs first at Func 42.

So the next blocker is now the **post-rewrite Func 42 family shape itself**: likely wrapper/caller cleanup or a neighboring forwarded-call family that still diverges after DAE reaches the callee.

## Validation used

- `moon fmt`
- `moon test src/fs/fs_test.mbt`
- `moon test src/passes`
- `moon build src/cmd --release`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/dae002-forwarded-const-low-revisit-artifact --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing`
