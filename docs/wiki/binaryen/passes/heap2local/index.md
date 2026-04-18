---
kind: entity
status: supported
last_reviewed: 2026-04-18
sources:
  - ../../../../../src/passes/heap2local.mbt
  - ../../../../../src/passes/heap2local_test.mbt
  - ../../../raw/research/0075-2026-04-03-heap2local-binaryen-comparison.md
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - ../late-pipeline-dispatch.md
related:
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
---

# `heap2local`

- Active hot pass in the Starshine registry.
- Current summary: replace non-escaping struct locals with scalar field locals and fold direct fresh-struct null comparisons.
- Current durable page: [`./parity.md`](./parity.md).
- Current Binaryen terminology check: upstream-facing surfaces still expose `--heap2local` / `Heap2Local`; this run found no rename or deprecation signal in the reachable non-GitHub sources.
- Current 2026-04-18 ordered generated-artifact audit: `heap2local` stayed in the expensive-but-successful cluster rather than the hard-corruption cluster, so the durable follow-up here is performance and audit visibility, not a newly observed wrong-code blocker.
- Expand this folder with dedicated strategy and shape pages as broader H2L research continues.

## Sources

- [`./parity.md`](./parity.md)
- [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md)
- Debian experimental manpage for `wasm-opt` `122`: <https://manpages.debian.org/experimental/binaryen/wasm-opt.1.en.html>
- Rust `wasm_opt::Pass` docs: <https://docs.rs/wasm-opt/latest/wasm_opt/enum.Pass.html>
