---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ./1640-2026-07-17-daeo-func8186-final-return.md
---

# DAEO Func 8184 null guard and call argument

## Goal and source attribution

Close the remaining `+16` canonical body gap in defined Func `8184` / absolute Func `8205`. The accepted note-`1640` body was:

```wat
ref.null none
ref.is_null
if (result (ref 37))
  global.get 154
  ref.as_non_null
else
  unreachable
end
local.set 1
local.get 0
local.get 1
call 8206
```

Binaryen v130's final DAEO body is:

```wat
local.get 0
global.get 154
ref.as_non_null
call 8206
```

The first owner is exact constant control: `ref.null` is always null, so adjacent `ref.is_null` is true and only the typed then arm can execute. The second owner is an exact one-set/one-get body-local call argument. Moving `global.get; ref.as_non_null` after the other argument's `local.get` crosses only a pure, nontrapping local read. The possibly trapping `ref.as_non_null` remains before the call and crosses no effectful or trapping instruction.

## Red-first coverage

The null-guard white-box test first referenced `run_hot_pipeline_dae_fold_ref_null_is_null_if_instrs` and failed to compile because the helper did not exist. It now proves the exact adjacent true-arm fold and rejects a separated condition.

The call-argument white-box test then first referenced `run_hot_pipeline_dae_sink_global_nonnull_call_args_instrs` and failed to compile because that helper did not exist. It now proves the exact six-instruction rewrite and rejects a temp with an extra read.

The public broad-high fixture includes a nullable global argument stored once, read once, and passed after an existing scalar argument to an effectful imported call. Optimizing DAEO removes the scratch local, preserves the imported call, and keeps the carrier's plain-DAE/optimizing separation.

## Retained implementation and safety

The optimizing-only broad-high selected structural cleanup:

1. replaces only adjacent `ref.null; ref.is_null; if-with-else` with the original typed then arm;
2. during its bounded sinking loop, recognizes only `global.get; ref.as_non_null; local.set temp; local.get arg; local.get temp; call` where `temp` is a body local with exactly one set, one get, and zero tees;
3. rewrites that sequence to `local.get arg; global.get; ref.as_non_null; call`;
4. reruns existing selected cleanup and compaction.

The rewrite changes no global read relative to a global write, because it crosses only one `local.get`. It changes no trap relative to any effect or other trap. Call operand order and values remain exact. Typed branch result, function signature, branch depth, catches, selected validation, encoded-size profitability, rollback, and plain DAE remain authoritative.

## Artifact result

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Accepted artifacts: `.tmp/daeo-func8184-final-20260717/`.

- raw size: `3203066`, `-16` versus note `1640`;
- canonical size: `3263956`, `-16` versus note `1640`;
- Binaryen-v130 canonical module: `3262456`;
- canonical module gap: `+1500`;
- raw SHA-256: `75b120fd34e14af6b95d6d46a579426141774071b104155d26f10081acb10c89`;
- canonical SHA-256: `165d538e827abd5d29d09bd57a9766abd7656cf7e3d0b2dff1ec6cf047b80618`;
- native SHA-256: `73f86497e49a958d15e7c1d2824086688c43742e1cc67a3b05dcc2b51596679a`.

Canonical body matrix:

| defined Func | note `1640` | retained | Binaryen v130 | retained delta |
|---:|---:|---:|---:|---:|
| `8184` | `27` | `11` | `11` | `0` |
| `8185` | `2464` | `2464` | `2429` | `+35` |
| `8186` | `10` | `10` | `10` | `0` |
| `8187` | `768` | `768` | `961` | `-193` |
| `8429` | `25694` | `25694` | `25742` | `-48` |
| `9347` | `14706` | `14706` | `15405` | `-699` |

The first and second raw outputs are byte-identical; their Binaryen-v130 canonical forms are byte-identical. All four validate with all features.

## Runtime and validation

- first invocation: `75830002us` pass-local / `77.600s` wall;
- converged second invocation: `5044120us` pass-local / `6.663s` wall;
- `moon info` and `moon fmt`: passed with pre-existing warnings;
- `pass_manager_wbtest.mbt`: `281/281`;
- `dae_optimizing_test.mbt`: `336/336`;
- full `moon test`: `8897/8897`;
- native release build: passed with pre-existing warnings;
- dedicated `.tmp/pass-fuzz-dae-optimizing-func8184-profile-1000`: `1000/1000` normalized, zero compare-normalized matches, mismatches, validation/generator/property/command failures, Binaryen cache `1000/0`;
- regular `.tmp/pass-fuzz-dae-optimizing-func8184-regular-1000`: same result.

Both generated lanes use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE cleanup normalizers. They are focused smokes, not replacements for the required four-lane closeout matrix. No public API changed; `.mbti` review found no relevant diff.

## Remaining work

Funcs `8184` and `8186` are closed at exact body-size parity. Func `8185 +35` is the only remaining positive body in the focused matrix and needs fresh source-backed downstream attribution; its movement-sensitive direct-simplify residual remains blocked. The full four-lane DAEO closeout matrix and pre-slot public optimize/shrink/O4z blockers remain active.
