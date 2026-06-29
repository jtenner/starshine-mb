# RemoveUnusedBrs raw-size regression triage: v128 same-target br_table

Date: 2026-06-29

## Scope

Initial `[O4Z-AUDIT-RUB-S]` triage after RUB-R. The goal was to sort accepted dead-shell dedicated-profile failures by raw Starshine-minus-Binaryen size and reduce the largest raw regression enough to identify the owner.

## Sorted failure summary

Command used:

```sh
python3 - <<'PY'
from pathlib import Path
for base in [Path('.tmp/pass-fuzz-remove-unused-brs-rub-loop-current-1000-max100/failures'), Path('.tmp/pass-fuzz-remove-unused-brs-rub-loop-current-1000-runtime-max20/failures')]:
    rows=[]
    for d in base.iterdir():
        if d.is_dir():
            rows.append(((d/'starshine.raw.wasm').stat().st_size-(d/'binaryen.raw.wasm').stat().st_size, (d/'starshine.raw.wasm').stat().st_size, (d/'binaryen.raw.wasm').stat().st_size, d.name))
    rows.sort(reverse=True)
    print(base, rows[:15], 'count', len(rows), 'total', sum(r[0] for r in rows))
PY
```

Largest raw regressions in `.tmp/pass-fuzz-remove-unused-brs-rub-loop-current-1000-max100/failures`:

| case | Starshine raw | Binaryen raw | delta |
| --- | ---: | ---: | ---: |
| `case-000073-gen-valid` | 1118 | 1045 | +73 |
| `case-000029-gen-valid` | 1107 | 1036 | +71 |
| `case-000032-gen-valid` | 1117 | 1056 | +61 |
| `case-000019-gen-valid` | 1093 | 1035 | +58 |
| `case-000020-gen-valid` | 1108 | 1056 | +52 |

Aggregate: `115` failures, total raw delta `+951`, `71` positive cases and `42` negative cases.

Runtime-checked lane `.tmp/pass-fuzz-remove-unused-brs-rub-loop-current-1000-runtime-max20/failures` has the same leading family: `case-000029` `+71`, `case-000032` `+61`, `case-000019` `+58`, `case-000020` `+52`, `case-000028` `+51`; aggregate `35` failures, total raw delta `+428`, `22` positive and `12` negative.

A mechanical check over the `1000-max100` positive raw regressions showed every positive case has more `br_table` occurrences in Starshine's normalized WAT than Binaryen's:

```text
positive count 71
brtable residual 71
brtable residual delta sum +1428
other positive cases 0
```

The negative cases more than partially offset this, explaining why the accepted family is normalized/canonical-size winning but raw-size mixed.

## Reduced owner

The largest case (`case-000073-gen-valid`, `selected_profile: remove-unused-brs-switch`) contains residual Starshine `br_table` shapes whose payload is `v128`. Binaryen lowers these same-target tables to `drop(selector); br payload` shells, while Starshine leaves the `br_table` and a dead suffix payload in raw output.

Reduced repro written locally at `.tmp/rub-s-v128-brtable.wat`:

```wat
(module
  (func (export "main") (result v128)
    (block (result v128)
      (v128.const i32x4 0 0 0 0)
      (i32.const 2)
      (br_table 0 0)
      (unreachable))))
```

Replay:

```sh
wasm-tools parse .tmp/rub-s-v128-brtable.wat -o .tmp/rub-s-reduce/input.wasm
wasm-opt --all-features --remove-unused-brs .tmp/rub-s-reduce/input.wasm -o .tmp/rub-s-reduce/binaryen.raw.wasm
_build/native/release/build/cmd/cmd.exe --remove-unused-brs --out .tmp/rub-s-reduce/starshine.raw.wasm .tmp/rub-s-reduce/input.wasm
wasm-tools validate --features all .tmp/rub-s-reduce/{binaryen.raw.wasm,starshine.raw.wasm}
```

Raw sizes:

- input: `63` bytes
- Binaryen: `65` bytes
- Starshine: `80` bytes
- Starshine-minus-Binaryen: `+15` bytes

Binaryen raw shape:

```wat
block (result v128)
  block
    i32.const 2
    drop
    v128.const i32x4 0 0 0 0
    br 1
  end
  unreachable
end
```

Starshine raw shape:

```wat
block (result v128)
  v128.const i32x4 0 0 0 0
  i32.const 2
  br_table 0
  unreachable
  v128.const i32x4 0 0 0 0
end
```

Agent classification: actionable RUB/local-representation gap, not an encoder-only blocker. The raw bloat is owned by same-target value `br_table` cleanup not firing for public stack-form `v128` payloads. Scalar `i32` and multivalue scalar payload representatives are now covered by RUB-R; this v128 lane shows a missing value-type/stack-form arm of the same selector-drop/payload-forwarding family.

## 2026-06-29 follow-up: v128 table owner fixed

A follow-up slice added the red-first focused test `remove-unused-brs forwards same-target br_table v128 payload through dead shell`. It failed with the original Starshine output still containing `br_table`, `unreachable`, and a duplicated dead `v128.const` suffix. The implementation then widened the local switch-collapse proof narrowly: `remove_unused_brs_node_is_reorder_safe(...)` now treats exact `v128.const` SIMD payloads as reorder-safe, so `remove_unused_brs_try_optimize_switch(...)` can use the existing one-target value-switch selector-drop / branch-payload-forwarding path for public `v128` payload switches.

Targeted replay of `.tmp/rub-s-v128-brtable.wat` with current `_build/native/release/build/cmd/cmd.exe` now validates and is a raw win:

- Binaryen raw: `65` bytes
- Starshine raw: `61` bytes
- Starshine-minus-Binaryen: `-4` bytes

Current Starshine raw shape:

```wat
block (result v128)
  i32.const 2
  drop
  v128.const i32x4 0 0 0 0
  br 0
end
```

Rerunning Starshine over the saved failure directories while reusing their Binaryen raw outputs shows that the `br_table` residue class disappeared:

| saved lane | old total delta | old positive / negative / zero | new total delta | new positive / negative / zero | residual Starshine `br_table` |
| --- | ---: | ---: | ---: | ---: | ---: |
| `.tmp/pass-fuzz-remove-unused-brs-rub-loop-current-1000-max100/failures` | `+951` | `71 / 42 / 2` | `-3353` | `11 / 103 / 1` | `0` |
| `.tmp/pass-fuzz-remove-unused-brs-rub-loop-current-1000-runtime-max20/failures` | `+428` | `22 / 12 / 1` | `-880` | `7 / 28 / 0` | `0` |

The remaining positive raw cases are no longer `br_table`-residue cases. The largest saved case, `case-000073-gen-valid`, improved from `+73` to `+38` but still contains residual structured `block` / `unreachable` shell bloat relative to Binaryen. RUB-S therefore stays open, narrowed to the no-`br_table` positive raw-size family.

Focused validation:

```sh
moon fmt
moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt
moon build --target native --release src/cmd
wasm-tools validate --features all .tmp/rub-s-reduce-after/{binaryen.raw.wasm,starshine.raw.wasm}
```

`moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `218/218`; native build passed with pre-existing pass-manager unused-function warnings.

## 2026-06-29 follow-up: residual no-`br_table` positives are result-suffix guarded

The residual positive raw cases are no longer the original `br_table` owner. Re-encoding the current Starshine outputs with local Binaryen showed the remaining positives are not a straightforward Starshine raw-wasm lower bound: the `1000-max100` positive cases have current raw deltas totaling `+181`, but their Binaryen-reencoded Starshine outputs are collectively `-1584` bytes versus Binaryen's original `remove-unused-brs` outputs; the runtime-checked positive cases similarly go from `+122` current raw bytes to `-1027` when reencoded. This was used only as triage evidence because Binaryen's reader/writer changes structured form, not as a Starshine semantic proof.

The leading residual `case-000073-gen-valid` (`+38`) reduces to a void structured block whose body returns in a result-typed function, followed by a dead result suffix. Starshine keeps the suffix by design through `remove_unused_brs_root_suffix_required_after_void_structured_terminal(...)`. That guard is source-backed by the stale dedicated-profile validation reduction in note `1388` and the current regression tests that preserve result suffixes after void structured nonfallthrough roots. This slice added the focused boundary test `remove-unused-brs boundary keeps result suffix after void return block` so the residual RUB-S owner is explicit rather than hidden inside the saved fuzz case.

RUB-S is therefore closed with a split outcome: the safe pass-local raw-size cleanup was implemented for the `v128` same-target table owner, while the residual no-table positives are blocked by the result-suffix preservation contract. Do not prune these suffixes merely for raw bytes unless a later proof shows HOT lowering can preserve validity and function results without the suffix.

## Reopening / next criteria

The original `v128` same-target `br_table` owner is fixed. Reopen RUB-S only if a new current-binary residual positive raw-size class is outside the fixed v128 same-target table owner and the guarded void-structured-return/result-suffix family, or if a later implementation provides a validation-preserving proof that void structured nonfallthrough roots in result-typed functions can drop their dead suffix without recreating the note-`1388` failure mode.
