# Agent Tasks

## Goal
Reach v0.1.0 “production-ready for MoonBit users” by end of March 2026: full native CLI, spec-test passing validator+optimizer, clean public API, and maintainable codebase.

## Scope
- This file tracks open work prioritized for v0.1 release.
- Completed tasks are intentionally removed.

## Metadata
- Last updated: `2026-02-25`
- Last audit run: `2026-02-25`

## Priority 0 (Release blockers)

### Text pipeline parity (native in-process lowering)
- [ ] Extend `wast -> lib` lowering for advanced exception forms (`throw`, `throw_ref`, `try_table`, catch forms), including parser/model plumbing.
- [ ] Add parser/lexer regression tests for newly wired advanced reference op keywords and opcode classification paths.
- [ ] Add negative literal tests for malformed NaN payloads and unsigned `i64x2` overflow boundaries in `v128.const` lowering.
- [ ] Validate native text pipeline on `.wat`/`.wast` flows without external tool dependency and close regressions.

### Spec harness/runtime parity
- [ ] Implement runtime execution semantics for `invoke`/`get` actions and `assert_return`/`assert_trap`/`assert_exhaustion`/`assert_exception`.
- [ ] Implement module instantiation/linking semantics for full `assert_unlinkable` parity.
- [ ] Remove temporary spec-harness skip classifications by adding:
  - [ ] Parser support for table element-segment abbreviation forms (for example `(table funcref (elem $f))`).
  - [ ] Lowering support for named parameter/local references that currently fail with `unknown local id` in numeric/float fixtures.
  - [ ] Decoder/validator parity for skipped malformed/binary fixtures (`binary-leb128`, descriptor binary fixtures, UTF-8 malformed cases).
  - [ ] Validator parity for skipped alignment/init-expression diagnostics in `align`/`memory_copy`/`memory_redundancy`/`memory_init` fixtures.

### Optimizer/decoder correctness hardening
- [ ] ReReloop: add temp-local single-eval lowering path for non-dup-safe `br_table` indices when targets are not directly label-resolvable.
- [ ] Replace heuristic `decode_module` span attribution with decoder-native section offsets.

### Release quality gates
- [ ] Add differential testing vs `wasm-tools` / Binaryen.
- [ ] Add wasm-smith fuzz harness (`decode -> validate -> optimize -> encode -> roundtrip`).
- [ ] Make `module_to_wast` output reliably parser-consumable in roundtrip tests.
- [ ] Reach `>=75%` line coverage on hot paths (decoder, IR lift, top passes).

## Priority 1 (Release polish)
- [ ] Expand `README.md` with architecture diagram and benchmark table.
- [ ] Add dedicated CLI command examples (`starshine` flags + config + env overlays).
- [ ] Add generated/verified API drift check so README signatures stay in sync with `pkg.generated.mbti`.
- [ ] Add `examples/` directory with real-world snippets.
- [ ] Publish first release + MoonBit registry package (`moon publish` + GitHub Release binaries).

## Deferred After v0.1
- [ ] `Poppify`
- [ ] `Outlining` as a standalone pass (beyond current inlining partial-splitting behavior)
- [ ] Broad Binaryen pass parity backlog (medium/low priority pass list)
- [ ] Large refactors: file splits (`typecheck`/`env`/`transformer`/`optimize`/`remove_unused`/`parser`) and `decode_instruction` helper decomposition
- [ ] Long-horizon platform/features: Component Model/WIT, streaming decoder API, custom sections/source maps, plugin system
