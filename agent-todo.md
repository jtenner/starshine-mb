# Agent Tasks

## Blockers
- None currently.

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
- [x] Extend `wast -> lib` lowering for advanced exception forms (`throw`, `throw_ref`, `try_table`, catch forms), including parser/model plumbing.
- [x] Add parser/lexer regression tests for newly wired advanced reference op keywords and opcode classification paths.
- [x] Add negative literal tests for malformed NaN payloads and unsigned `i64x2` overflow boundaries in `v128.const` lowering.
- [x] Validate native text pipeline on `.wat`/`.wast` flows without external tool dependency and close regressions.
- [x] Add parser/lowering support for legacy exception text forms (`try`/`do`/`catch`/`delegate`/`rethrow`) used in `tests/spec/legacy/*.wast`.
- [x] Lower inline `tag` exports (for example `(tag (export "e0"))`) into `export_sec` instead of dropping them.
- [x] Add validator-backed regression coverage for `catch_ref`/`catch_all_ref` (`exnref` label typing) and imported-tag wiring edge cases.

### Spec harness/validator parity
- [x] Keep spec harness scoped to static checks only (no VM/runtime execution); runtime directives remain command-level skips.
- [x] Stop whole-file skipping for `assert_exception`; skip only `assert_exception` commands so validator directives in the same file still run.
- [x] Add directive-coverage tests that explicitly exercise validator paths for `module`, `module binary`, `module quote`, `assert_invalid`, and `assert_unlinkable` (pre-link validation check).
- [x] Add regressions for mixed-runtime files (for example `throw*.wast` / `try_table.wast`) to ensure validator directives still execute when runtime-only commands are present.
- [x] Remove temporary spec-harness skip classifications that currently hide validator coverage:
  - [x] Parser support for table element-segment abbreviation forms (for example `(table funcref (elem $f))`).
  - [x] Lowering support for named parameter/local references that currently fail with `unknown local id` in numeric/float fixtures.
  - [x] Decoder/validator parity for skipped malformed/binary fixtures (`binary-leb128`, descriptor binary fixtures, UTF-8 malformed cases).
  - [x] Validator parity for skipped alignment/init-expression diagnostics in `align`/`memory_copy`/`memory_redundancy`/`memory_init` fixtures.

### Optimizer/decoder correctness hardening
- [ ] ReReloop: add temp-local single-eval lowering path for non-dup-safe `br_table` indices when targets are not directly label-resolvable.
- [x] Replace heuristic `decode_module` span attribution with decoder-native section offsets.
- [ ] Add targeted tests for section-span reporting on section-order/duplicate-section `InvalidModule` cases (to keep `TrailingBytes` diagnostics stable under decoder refactors).

### Follow-up tasks from latest implementation
- [ ] Add CI coverage for native target `cmd/fuzz_harness_test.mbt` so real `wasm-tools`/Binaryen differential checks run in automation (not only wasm-gc tests).
- [ ] Add a lightweight corpus/minimizer flow for fuzz-harness failures (persist failing wasm + seed + pass set for deterministic repro).
- [ ] Tune/replace `gen_valid_module` candidate generation for harness throughput so fewer candidates are discarded before the 100k valid target.
- [ ] Implement full typed-heap value-type modeling in `wast` AST/lowering (`(ref $t)`/`(ref null $t)` to concrete `TypeIdx` refs), replacing current abstract-funcref approximation.
- [ ] Add focused tests for `try_table` catch label-depth semantics covering numeric and named labels across nested blocks plus implicit function-return label resolution.
- [ ] Audit downstream optimizer/type-refinement assumptions after `ref.func` now typechecks as non-null `(ref func)` and update notes/tests accordingly.
- [ ] Extend table abbreviation support to additional text forms used in spec files (`(elem func ...)`, typed ref element expressions, and non-zero active offsets where applicable).
- [ ] Add lowering + validation regression tests for table abbreviation semantics (implicit active elem segment index ordering with explicit `(elem ...)` segments).
- [ ] Add explicit regression tests for inline exports across `func`/`table`/`memory`/`global` fields to lock in the shared inline-export lowering path.
- [ ] Replace conservative legacy-exception lowering with semantic-preserving lowering to `try_table`/`throw_ref` (current path is static-validation oriented).
- [ ] Add direct parser/lowering regression tests for legacy invalid-label diagnostics (`delegate` depth/name targets and `rethrow` catch-depth checks), independent of spec-harness fixtures.

### Release quality gates
- [x] Add differential testing vs `wasm-tools` / Binaryen.
- [x] Add wasm-smith fuzz harness (`decode -> validate -> optimize -> encode -> roundtrip`).
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
