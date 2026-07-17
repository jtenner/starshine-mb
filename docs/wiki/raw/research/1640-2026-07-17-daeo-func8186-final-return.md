---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ./1634-2026-07-17-daeo-func8186-stack-carried-literal-suffix.md
  - ./1639-2026-07-17-daeo-func8185-never-read-result-stores.md
---

# DAEO Func 8186 final return

## Goal and attribution

Close the final one-byte body gap in defined Func `8186` / absolute Func `8207` after the stack-carried literal/signature slice in note `1634`. Binaryen v130's final DAEO body ends directly after `struct.new`; Starshine retained an explicit top-level `return` immediately before function end. At top-level function tail, explicit return and the function body's implicit return consume the same declared results. Nested and nonfinal returns are not equivalent and remain untouched.

## Red-first coverage and retained implementation

The white-box test first referenced `run_hot_pipeline_dae_remove_final_return_instrs` and failed to compile because the helper did not exist. It now proves that only a top-level final `return` is removed; a nested final return and a nonfinal return remain exact.

The public broad-high fixture now asserts that the reduced carrier has no explicit `Return`. The optimizing-only selected structural cleanup runs this exact top-level tail step after nop cleanup and before selected local cleanup/compaction. Validation, encoded-size profitability, rollback, and plain-DAE separation remain authoritative.

No producer, stack value, call, effect, trap, block signature, branch depth, catch vector, or function signature changes. The helper removes only the redundant one-byte control opcode.

## Artifact result

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Accepted artifacts: `.tmp/daeo-func8186-final-return-final-20260717/`.

- raw size: `3203082`, `-1` versus note `1639`;
- canonical size: `3263972`, `-1` versus note `1639`;
- Binaryen-v130 canonical module: `3262456`;
- canonical module gap: `+1516`;
- raw SHA-256: `c2964eed2b225aefb411e944d21d5daf9ade754cc152a545f8b6d377d64509b9`;
- canonical SHA-256: `ebe90268ad36ce29c9e14184bbe976ccc385187a7da6a987a3ce05f660f8eb3c`;
- native SHA-256: `91310f086edec4263c6496e9599579c8cf6674186b9de939bb4fcdd0a676576c`.

Canonical body matrix:

| defined Func | note `1639` | retained | Binaryen v130 | retained delta |
|---:|---:|---:|---:|---:|
| `8184` | `27` | `27` | `11` | `+16` |
| `8185` | `2464` | `2464` | `2429` | `+35` |
| `8186` | `11` | `10` | `10` | `0` |
| `8187` | `768` | `768` | `961` | `-193` |
| `8429` | `25694` | `25694` | `25742` | `-48` |
| `9347` | `14706` | `14706` | `15405` | `-699` |

The first and second raw outputs are byte-identical; their Binaryen-v130 canonical forms are byte-identical. All four validate with all features.

## Runtime and validation

- first invocation: `76581325us` pass-local / `78.354s` wall;
- converged second invocation: `5039235us` pass-local / `6.654s` wall;
- `moon info` and `moon fmt`: passed with pre-existing warnings;
- `pass_manager_wbtest.mbt`: `279/279`;
- `dae_optimizing_test.mbt`: `336/336`;
- full `moon test`: `8895/8895`;
- native release build: passed with pre-existing warnings;
- dedicated `.tmp/pass-fuzz-dae-optimizing-final-return-profile-1000`: `1000/1000` normalized, zero compare-normalized matches, mismatches, validation/generator/property/command failures, Binaryen cache `1000/0`;
- regular `.tmp/pass-fuzz-dae-optimizing-final-return-regular-1000`: same result.

Both generated lanes use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE cleanup normalizers. They are focused smokes, not replacements for the required four-lane closeout matrix. No public API changed; `.mbti` review found no relevant diff.

## Remaining work

Func `8186` is closed at exact body-size parity. Func `8184 +16` is now the next small direct owner. Func `8185 +35`, the full four-lane DAEO closeout matrix, and the pre-slot public optimize/shrink/O4z blockers remain active.
