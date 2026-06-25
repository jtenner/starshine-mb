---
kind: research
status: strong
created: 2026-06-25
sources:
  - ../../../../src/passes/strip_debug.mbt
  - ../../../../src/passes/strip_debug_test.mbt
  - ../../../../agent-todo.md
---

# `strip-debug` custom-section preservation

## Question

`[JSON-AS]008` asked for refreshed direct `--strip-debug` evidence and for custom-section/name-section drift to be classified separately from semantic sections. The active Starshine implementation was also broader than the observed Binaryen behavior: it removed every `custom_secs` entry, not just the structured/raw name-section payload.

## Binaryen probe

A reduced binary fixture under `.tmp/strip-debug-audit/input5.wasm` contains a minimal exported empty function plus a non-name custom section `foo` with payload `bar`.

Commands:

```sh
wasm-tools validate --features all .tmp/strip-debug-audit/input5.wasm
wasm-opt .tmp/strip-debug-audit/input5.wasm --all-features --strip-debug -o .tmp/strip-debug-audit/binaryen5.wasm
_build/native/release/build/cmd/cmd.exe .tmp/strip-debug-audit/input5.wasm --strip-debug -o .tmp/strip-debug-audit/starshine5-fixed.wasm
wasm-tools objdump .tmp/strip-debug-audit/binaryen5.wasm
wasm-tools objdump .tmp/strip-debug-audit/starshine5-fixed.wasm
wasm-tools validate --features all .tmp/strip-debug-audit/starshine5-fixed.wasm
```

Result:

- Binaryen preserves the non-name custom section `foo`.
- Starshine now also preserves the non-name custom section `foo`.
- Raw bytes differ because Binaryen rewrites the custom section after the code section, while Starshine preserves the input custom-section placement before the type section. This is classified as custom-section placement drift, not a semantic-section mismatch.

The ordinary `pass-fuzz-compare` harness strips debug during canonicalization, so it cannot prove custom/name-section behavior. It remains useful as a semantic-section smoke only.

## Implementation

`strip_debug_run_module_pass` now calls `without_name_sec()` without clearing `custom_secs`. The pass summary was narrowed to the current implemented contract: remove structured/raw name-section payload and preserve other custom sections.

Focused TDD updated `src/passes/strip_debug_test.mbt`:

- red-first expectation: non-name `producers` and `profile` custom sections must survive `strip-debug`;
- post-fix expectation: `name_sec` and `raw_name_sec_payload` are removed while semantic sections and non-name custom sections remain.

## Validation

- Red-first focused test failed before implementation: optimized `custom_secs` was `[]` instead of the expected `producers` and `profile` entries.
- `moon fmt` passed.
- `moon info` passed with pre-existing `src/validate` warnings.
- `moon test --target native src/passes/strip_debug_test.mbt` passed `3/3` with pre-existing `src/passes/pass_manager*` warnings.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Manual custom-section oracle above validated Starshine output and confirmed both tools preserve `foo`.
- Semantic-section smoke: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass strip-debug --out-dir .tmp/pass-fuzz-strip-debug-preserve-custom-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures` compared `1000/1000`, normalized `1000`, cleanup-normalized `0`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache `200` hits / `800` misses.

## Remaining work

`[JSON-AS]008` still needs preset-placement and artifact-size measurement decisions. This slice only fixes and documents direct custom-section preservation and refreshed direct-pass semantic smoke evidence.
