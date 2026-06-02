---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-06-02
sources:
  - https://github.com/bytecodealliance/wasm-tools/blob/main/README.md#L269-L272
  - https://github.com/bytecodealliance/wasm-tools/blob/main/README.md#L347-L350
  - ../../../../scripts/lib/self-opt-task.ts
  - ../../../../scripts/lib/self-optimized-artifacts.mjs
  - ../../../../scripts/lib/validate-task.ts
related:
  - ../../tooling/validation-gates.md
---

# wasm-tools validate feature defaults and explicit feature flags

This manifest captures the upstream `wasm-tools validate` behavior that Starshine's self-optimized artifact gate now leans on.

The official README section around lines 269-272 shows explicit validation feature toggles, and its proposals section around lines 347-350 states the default-on validation policy:

- `wasm-tools validate foo.wasm --features=exception-handling` to enable an off-by-default proposal.
- `wasm-tools validate foo.wasm --features=-simd` to disable a default-enabled feature.
- The same section states that Stage 4+ proposals are enabled by default in validation.

Starshine's `bun validate self-opt-smoke` and `bun validate self-opt-full` intentionally use a stricter repo-local policy: they validate the artifact with `wasm-tools validate --features all`, then run the Node/WASI `--help` smoke and the selected spec workload.

Durable takeaway:

- upstream wasm-tools validation already treats Stage 4+ features as default-on;
- Starshine's self-opt gate asks for all features anyway so the self-optimized artifact is checked under the widest feature set currently accepted by the local wrapper;
- do not use external host docs as a substitute for the local wrapper policy.
