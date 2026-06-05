# Binaryen BrOn Assertion Oracle Boundary

Capture date: 2026-06-05

Purpose: record the current primary-source status of Binaryen's April 2026 `IRBuilder::makeBrOn` reachable-assertion fix so Starshine wiki readers classify Binaryen parser/validator crashes correctly in external-validator and compare-pass lanes.

## Primary external sources checked

- Binaryen commit `1251efbc1ea471c1311d2726b2bbe061ff2a291c`, `Avoid assertion in BrOn parsing`: <https://github.com/WebAssembly/binaryen/commit/1251efbc1ea471c1311d2726b2bbe061ff2a291c>
  - Maintainer summary: the `ref` and descriptor operands were later used as references in `finalize()`, so non-reference operands such as `i32` could reach an assertion.
  - Patch location: `src/wasm/wasm-ir-builder.cpp`, `IRBuilder::makeBrOn(...)`.
  - Durable behavior fact: the builder now validates that the `br_on*` reference operand is a reference or unreachable, and that descriptor-branch operands are also reference or unreachable when present, before later finalization logic.
- Binaryen issue #8633, `Assertion failure isRef() in wasm::Type::getHeapType() at wasm-type.h:407 (main branch @3ef8d19)`: <https://github.com/WebAssembly/binaryen/issues/8633>
  - The issue reports a local malformed-input assertion while parsing a `br_on*`-family shape with `wasm-ctor-eval` on Binaryen `main` commit `3ef8d19` as of 2026-04-21.
- Binaryen pull request #8635, `Avoid assertion in BrOn parsing`: <https://github.com/WebAssembly/binaryen/pull/8635>
  - Merged into `WebAssembly/binaryen:main` on 2026-04-21 as commit `1251efb`, with reviewer approval and checks passing.
- NVD CVE-2026-8257: <https://nvd.nist.gov/vuln/detail/CVE-2026-8257>
  - NVD records the same patch commit and issue/PR references as `CWE-617 Reachable Assertion`.
  - NVD's CPE range currently says Binaryen versions up to and including `117`, while the official upstream issue describes a `main`-branch debug/ASan repro at commit `3ef8d19`. Treat that version range as external advisory metadata, not as a substitute for upstream release/tag ancestry checks.
- Binaryen `version_130` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_130>
  - The release was created on 2026-06-01 at tag commit `5d704ad`, after the April 21 fix landed on `main`.
- GitHub compare page `1251efb...version_130`: <https://github.com/WebAssembly/binaryen/compare/1251efbc1ea471c1311d2726b2bbe061ff2a291c...version_130>
  - GitHub reports `122` commits between the patch commit and `version_130`, which is useful corroboration that the public `version_130` baseline is after the BrOn assertion fix.

## Repository evidence checked

- `docs/wiki/binaryen/release-horizon-and-oracles.md` already treats `version_130` as the current public release baseline.
- `docs/wiki/tooling/external-validator-adapters.md` documents Binaryen adapter failures as `tool-failure`, not Starshine validity evidence.
- `docs/wiki/tooling/pass-fuzz-compare.md` documents Binaryen command failures as replayable tool/oracle failures until classified.
- `docs/wiki/wast/reference-instruction-authoring.md` and `docs/wiki/custom-descriptors/descriptor-instruction-surface.md` already route ordinary `br_on_*` and descriptor-aware reference forms through their own Starshine core/binary/validator contracts.

## Durable conclusions

1. For installed Binaryen builds older than the `1251efb` fix, a `br_on*` / descriptor-branch parser assertion is Binaryen tool/oracle failure evidence, not proof that Starshine accepted an invalid module or miscompiled a pass output.
2. The current wiki public release horizon (`version_130`) is after the fix. Keep `version_130` as the default public baseline unless a future release-horizon recheck changes it.
3. Do not use the NVD `up to 117` wording to downgrade the `version_130` baseline or to claim every later local `wasm-opt` is fixed without checking the actual installed binary. The actionable rule for Starshine workflows is: record the exact Binaryen command/build when a BrOn-family assertion appears, then classify it as `tool-failure` / Binaryen oracle failure unless replay on a fixed build proves a Starshine-specific issue.
4. Starshine reference-branch semantics remain owned by local source and tests: `BrOnNull`, `BrOnNonNull`, `BrOnCast`, and `BrOnCastFail` in `src/lib/types.mbt`, typechecking in `src/validate/typecheck.mbt`, HOT lowering in `src/ir/hot_lower.mbt`, and WAST text-surface caveats in `docs/wiki/wast/reference-instruction-authoring.md`. This upstream Binaryen fix does not add or remove Starshine WAST syntax.

## Follow-up triggers

- If a future Binaryen release supersedes `version_130`, refresh `docs/wiki/binaryen/release-horizon-and-oracles.md` and re-evaluate whether this bridge remains only historical tool-failure guidance.
- If Starshine compare-pass or binary-differential reports start seeing `br_on*` assertion failures from the installed Binaryen command, preserve the exact `wasm-opt --version` / command path and failure artifact before updating pass-specific pages.
