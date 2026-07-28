---
kind: workflow
status: supported
last_reviewed: 2026-07-27
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
related:
  - ./index.md
  - ../simplify-locals/fuzzing.md
---

# `simplify-locals-notee-nostructure` fuzzing

## Binaryen-v131 closeout

The dedicated aggregate profile is `simplify-locals-notee-nostructure`. The refreshed closeout command used seed `0x5eed`, official Binaryen v131, and the explicit native Starshine release binary:

```text
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass simplify-locals-notee-nostructure \
  --gen-valid-profile simplify-locals-notee-nostructure \
  --out-dir .tmp/pass-fuzz-simplify-locals-notee-nostructure-v131-refresh-20260727-10000 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt
```

Result:

- compared: `10000/10000`;
- exact normalized matches: `2766`;
- structural differences: `7234`, every one strictly smaller for Starshine by `10–54` canonical wasm bytes;
- validation, property, generator, and command failures: `0`;
- profile leaf coverage: local traffic `3530`, structure result `3557`, effect order `1455`, stress `1458`.

The separate `1000`-case seed-`0x1d3a` idempotence lane is `1000/1000` with zero property failures. No parity gap, unknown/risky family, validation failure, or size-losing result remains.
