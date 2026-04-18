---
kind: entity
status: stub
last_reviewed: 2026-04-18
sources:
  - ../../../../../src/passes/heap_store_optimization.mbt
  - ../../../../../src/passes/heap_store_optimization_test.mbt
  - ../late-pipeline-dispatch.md
  - https://manpages.debian.org/experimental/binaryen/wasm-opt.1.en.html
  - https://docs.rs/wasm-opt/latest/wasm_opt/enum.Pass.html
related:
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
---

# `heap-store-optimization`

- Active hot pass in the Starshine registry.
- Current summary: Fold exact struct.set writes into nearby struct.new allocations when local and effect ordering stays safe.
- Current Binaryen terminology check: the Debian experimental `wasm-opt` manpage for Binaryen `122` still lists `--heap-store-optimization`, so this maintenance run found no rename or deprecation signal in the available official-source and package-surface checks. The published `wasm_opt::Pass` enum page is still not a useful positive source for this pass name, because this 2026-04-18 check did not find `HeapStoreOptimization` there even though that same page explicitly says its exposed variants use the command-line pass names with Rust capitalization conventions and the Debian manpage still carries the CLI flag.
- Use [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md) for the current tail roster and the refreshed 2026-04-18 official-source terminology guidance until dedicated strategy and parity pages land.

## Sources

- [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md)
- Debian experimental `wasm-opt` manpage for Binaryen `122`: <https://manpages.debian.org/experimental/binaryen/wasm-opt.1.en.html>
- Rust `wasm_opt::Pass` docs: <https://docs.rs/wasm-opt/latest/wasm_opt/enum.Pass.html>
  - Negative evidence only for this pass during the 2026-04-18 maintenance check: the published enum page says its exposed variants mirror command-line pass names with Rust capitalization conventions, but it still did not expose `HeapStoreOptimization`, so the Debian manpage remains the stronger package-surface naming source here.
