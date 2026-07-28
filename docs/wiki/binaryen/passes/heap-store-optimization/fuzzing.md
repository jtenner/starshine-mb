---
kind: workflow
status: working
last_reviewed: 2026-07-28
sources:
  - ./index.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/fuzz/main_wbtest.mbt
---

# `heap-store-optimization` Fuzzing Profile

## Binaryen v131 spot renewal

The July 28, 2026 explicit-v131 renewal used the rebuilt `_build/native/release/build/cmd/cmd.exe` and `.tmp/binaryen-version-131/bin/wasm-opt`, verified as `wasm-opt version 131 (version_131)`:

- `.tmp/pass-fuzz-hso-v131-spot-ordinary-1000`: `1000/1000` exact normalized matches, zero mismatches/failures, Binaryen cache `0/1000` hits/misses;
- `.tmp/pass-fuzz-hso-v131-spot-dedicated-100`: `100/100` cleanup-normalized matches under `local-cleanup-debris`, zero mismatches/failures, Binaryen cache `13/87` hits/misses.

The owner file is unchanged from v130. The one dedicated-lit expectation delta is bottom-valued `local.tee` to `local.set` finalization in `$unreachable`; a focused source-WAT probe confirms Binaryen's new text, while binary reparse reduces both Binaryen and Starshine to the same valid 32-byte `unreachable` function. This renews the existing closeout without opening implementation work.

Recommended ordinary GenValid smoke lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Dedicated GenValid aggregate: `heap-store-optimization` (alias: `hso`; closeout aliases: `heap-store-optimization-closeout`, `heap-store-optimization-all`, and `heap-store-optimization-all-profiles`). It deterministically samples nine leaf profiles:

- `heap-store-optimization-tee`
- `heap-store-optimization-chains`
- `heap-store-optimization-defaults`
- `heap-store-optimization-side-effects`
- `heap-store-optimization-descriptors`
- `heap-store-optimization-control-flow`
- `heap-store-optimization-swaps`
- `heap-store-optimization-shared-ordering`
- `heap-store-optimization-boundaries`

Only the shared-ordering leaf enables atomics and shared memories. The required random all-profiles closeout lane should use the composite GenValid profile `random-all-profiles` (aliases: `all-profiles`, `random-profiles`) at seed `0x5555`; do not apply the dedicated HSO `local-cleanup-debris` normalizer to that random all-profiles lane unless a mismatch is separately inspected and justified.

The dedicated HSO aggregate emits valid GC modules with deterministic HSO-owned opportunities:

- block-local `local.set(struct.new)` followed by same-local `struct.set`;
- immediate `local.tee(struct.new)` stores;
- repeated same-field stores where the final value wins;
- call-containing old-field expressions where an overwritten constructor field is produced by a value block containing a direct void call (`1046`, not a true call-result old field);
- true direct-call-result old-field expressions where an HSO-only no-param `(result i32)` helper produces the overwritten constructor field before a later same-field store (`1054`);
- true `call_indirect` result old-field expressions where the same HSO-only no-param `(result i32)` helper type produces the overwritten constructor field before a later same-field store (`1056`);
- true `call_ref` result old-field expressions where `ref.func` / `call_ref` to the same HSO-only no-param `(result i32)` helper produces the overwritten constructor field before a later same-field store (`1057`);
- `struct.new_default` materialization followed by same-local `struct.set`;
- descriptor-bearing `struct.new_default_desc` and `struct.new_desc` materialization followed by same-local `struct.set`;
- descriptor-bearing direct-call-result old-field expressions where an HSO-only no-param `(result i32)` helper produces the overwritten constructor field before a later same-field store (`1058`);
- mutable-descriptor direct-call-result old-field expressions where the helper call produces the overwritten constructor field and a mutable exact-descriptor `global.get` supplies the descriptor operand before the later same-field store (`1059`);
- descriptor-bearing `call_indirect` result old-field expressions where the helper type is reached through table slot zero before a pure descriptor operand and later same-field store (`1060`);
- descriptor-bearing `call_ref` result old-field expressions where `ref.func` / `call_ref` reaches the helper before a pure descriptor operand and later same-field store (`1061`);
- direct `return_call` result-wrapper old-field boundaries where the overwritten constructor field is a true helper-call result before a result-typed tail-call wrapper and later same-field store (`1062`);
- `return_call_indirect` result-wrapper old-field boundaries where the overwritten constructor field is a true helper-call result before an indirect tail-call wrapper through table slot zero and later same-field store (`1063`);
- `return_call_ref` result-wrapper old-field boundaries where the overwritten constructor field is a true helper-call result before a typed-function-reference tail-call wrapper and later same-field store (`1064`);
- descriptor-bearing direct `return_call` result-wrapper old-field boundaries where the overwritten constructor field is a true helper-call result, the descriptor operand is pure, and a later same-field store remains after the wrapper (`1065`);
- descriptor-bearing `return_call_indirect` result-wrapper old-field boundaries where the overwritten constructor field is a true helper-call result, the descriptor operand is pure, and the indirect tail call uses table slot zero before a later same-field store (`1066`);
- descriptor-bearing `return_call_ref` result-wrapper old-field boundaries where the overwritten constructor field is a true helper-call result, the descriptor operand is pure, and the typed-function-reference tail call uses `ref.func` before a later same-field store (`1067`);
- mutable-descriptor direct `return_call` result-wrapper old-field boundaries where the overwritten constructor field is a true helper-call result, the descriptor operand is a mutable exact-descriptor `global.get`, and a later same-field store remains after the wrapper (`1068`);
- mutable-descriptor `return_call_indirect` result-wrapper old-field boundaries where the overwritten constructor field is a true helper-call result, the descriptor operand is a mutable exact-descriptor `global.get`, and the indirect tail call uses table slot zero before a later same-field store (`1069`);
- mutable-descriptor `return_call_ref` result-wrapper old-field boundaries where the overwritten constructor field is a true helper-call result, the descriptor operand is a mutable exact-descriptor `global.get`, and the typed-function-reference tail call uses `ref.func` before a later same-field store (`1070`);
- non-throwing void `try_table` / `table.set` wrappers between a fresh `memory.size` constructor and a later same-local `struct.set`;
- same-resource non-throwing void `try_table` / `memory.fill` barriers where the later `struct.set` should remain;
- contained-control non-throwing void `try_table` / `br_if` / `table.set` wrappers where the branch stays inside the root wrapper; and
- catchable `try_table` / `throw` skip-local-set hazards where exception control can skip the fresh-constructor `local.set` before a later same-local `struct.set`; and
- descriptor-bearing catchable `try_table` / `throw` skip-local-set hazards where the skipped local assignment materializes through `struct.new_desc`; and
- descriptor-bearing branch skip-local-set hazards where a `br_if` can skip the `struct.new_desc` local assignment; and
- descriptor-bearing old-field side-effect roots where an overwritten `memory.grow` field must be preserved before a same-field store fold;
- mutable-descriptor result-wrapper old-field roots where an overwritten `memory.grow` field, mutable descriptor `global.get`, catchable direct-call wrapper, and later `struct.set` must remain ordered; and
- descriptor-bearing result-typed `try_table` set-value roots where the moved same-field store value is produced by the result wrapper; and
- descriptor-bearing later-field result-typed `try_table` roots where another constructor field comes from the result wrapper before a same-field store fold; and
- result-typed same-resource `try_table` / `memory.fill` barriers where the later `struct.set` should remain;
- result-typed cross-family `try_table` / `table.set` roots where a `memory.size` constructor can still fold across the unrelated table store;
- catchable result-typed `try_table` / `memory.fill` barriers where the wrapper can branch to a local catch and the later `struct.set` should remain;
- table-side result-typed cross-family `try_table` / `i32.store` roots where a `table.size` constructor can still fold across the unrelated memory store; and
- result-typed cross-family `try_table` growth roots where `memory.size` crosses `table.grow` and `table.size` crosses `memory.grow`; and
- table-side result-typed same-resource `try_table` / `table.fill` barriers where the later `struct.set` should remain; and
- descriptor-bearing exact `br_on_non_null` branch-result operands feeding `struct.new_desc` where the later same-field store should fold; and
- catchable result-typed `try_table` direct-call wrappers where the call remains inside the wrapper and the later `struct.set` should remain;
- catchable result-typed `try_table` `call_indirect` wrappers where the indirect call remains inside the wrapper and the later `struct.set` should remain; and
- catchable result-typed `try_table` `call_ref` wrappers where the typed-function-reference call remains inside the wrapper and the later `struct.set` should remain.

Recommended dedicated-profile smoke lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-genvalid-profile-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Recommended random all-profiles closeout lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass heap-store-optimization --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-heap-store-optimization-genvalid-random-all-profiles-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Use `--normalize local-cleanup-debris` for the dedicated HSO aggregate while Starshine removes folded-store `nop` roots that Binaryen retains. Research note `1023` classified the initial 20-case raw mismatch family as a Starshine-win cleanup drift: Binaryen output kept `(nop)` placeholders after HSO folds, while Starshine emitted smaller validated output without those dead roots. The refreshed 2026-06-25 10000-case dedicated-profile lane in research note `1073` compared `10000/10000` cases with `0` raw mismatches/failures and `10000` cleanup-normalized matches under this normalizer; `cases.jsonl` selected `heap-store-optimization` for all `10000` cases.

Manifest triage fields:

- `config_label`: `heap-store-optimization` for direct aggregate requests;
- `selected_profile`: one of the nine leaf names above;
- `case_label`: one of `hso:tee`, `hso:chains`, `hso:defaults`, `hso:side-effects`, `hso:descriptors`, `hso:control-flow`, `hso:swaps`, `hso:shared-ordering`, or `hso:boundaries`;
- `facts.has_gc_constructors` and `facts.has_gc_accessors`: expected true for emitted profile cases.

Research note `1079` added the general `random-all-profiles` GenValid composite profile required by final HSO closeout; it samples the current compare-pass-stable non-composite leaf set (`coverage-forced-portable`, `binaryen-oracle-portable`, `pass-fuzz-stress`, `ssa-nomerge-smoke`, and `ssa-nomerge-parity`) and excludes composite aliases, the currently aborting `pathological-valid` profile, and the dedicated HSO profile whose raw local-cleanup output-shape drift remains scoped to the dedicated lane. Research note `1080` ran that random all-profiles lane at 10000 cases / seed `0x5555` without cleanup normalizers: `10000/10000` compared, `10000` normalized, `0` mismatches/failures, with selected leaves `pass-fuzz-stress=2062`, `coverage-forced-portable=2037`, `ssa-nomerge-smoke=1973`, `ssa-nomerge-parity=1970`, and `binaryen-oracle-portable=1958`. Research note `1082` ran the required regular GenValid lane at 100000 cases / seed `0x5eed` without cleanup normalizers: `100000/100000` compared, `100000` normalized, `0` cleanup-normalized, `0` mismatches, and `0` validation/property/generator/command failures. Final matrix refresh `1137` superseded the individual older closeout-lane evidence after the raw complete-default-chain path: regular GenValid `100000/100000` normalized; explicit wasm-smith `9956/10000` compared with `9956` normalized and `44` Binaryen/oracle command failures; dedicated HSO profile `10000/10000` cleanup-normalized under `local-cleanup-debris`; and random all-profiles `10000/10000` normalized with selected leaves `pass-fuzz-stress=2062`, `coverage-forced-portable=2037`, `ssa-nomerge-smoke=1973`, `ssa-nomerge-parity=1970`, and `binaryen-oracle-portable=1958`. All `1137` lanes had `0` mismatches, validation failures, property failures, and generator failures. Post-speed closeout `1357` reran the full matrix after the raw plain-`struct.new` fast path using `_build/native/release/build/cmd/cmd.exe`: regular GenValid `100000/100000` normalized; explicit wasm-smith `9956/10000` normalized with the same `44` Binaryen/oracle command failures; dedicated HSO profile `10000/10000` cleanup-normalized under `local-cleanup-debris`; and random all-profiles `10000/10000` normalized with the same selected leaf counts as `1137`. All `1357` lanes had `0` mismatches, validation failures, property failures, and generator failures. After the `1085` straight-line region-scan skip, research note `1087` reran a 10000-case direct GenValid smoke at the same seed with no cleanup normalizers: `10000/10000` compared, `10000` normalized, `0` mismatches, and `0` validation/property/generator/command failures. After the `1088` straight-line context setup skip, research note `1090` reran the same 10000-case direct GenValid smoke with no cleanup normalizers: `10000/10000` compared, `10000` normalized, `0` mismatches, and `0` validation/property/generator/command failures. After the `1092` simple no-control skip-local-set fast path, research note `1093` reran the same 10000-case direct GenValid smoke with no cleanup normalizers: `10000/10000` compared, `10000` normalized, `0` mismatches, and `0` validation/property/generator/command failures. Status audit `1074` narrows the old `1047` generated call-result blocker: the profile now includes true generated direct-call, `call_indirect`, `call_ref`, pure-descriptor, mutable-descriptor, and direct/indirect/typed-function-reference tail-call result-wrapper old-field floors through `1054`, `1056`-`1070`. Micro-audit `1105` source-maps the dedicated profile after the `1073` 10000-case refresh: the profile is current generated regression coverage for the listed roots, but it is not a substitute for source-family closeout, exact descriptor `ref.cast`, or performance disposition; keep `local-cleanup-debris` scoped to the dedicated HSO profile lane. The explicit wasm-smith lane in `1076` found one no-heap-store cleanup mismatch where Starshine retained `drop(unreachable)` before a hard `unreachable`; follow-up `1077` fixed the no-candidate raw fast path and replayed saved `case-009332-wasm-smith` to `1/1` normalized matches without an HSO-wide cleanup normalizer. The full 10000-case explicit wasm-smith rerun in `1078` compared `9956/10000` cases with `9956` normalized matches, `0` mismatches, and `44` Binaryen/oracle command failures, also without cleanup normalizers. Broader generated descriptor barriers and broader control-flow/store-barrier generators beyond the currently listed roots still remain future work rather than source-family closeout. Research note `1025` re-enabled the `1024` generated try-table family after focused mixed-field tests and a rebuilt 20-case dedicated-profile smoke lane were compare-normalized green. Research note `1026` added the `memory.fill` no-fold barrier and contained-branch table-store profile roots with a rebuilt 20-case dedicated-profile smoke and a 1000-case direct smoke, both green. Research note `1027` added descriptor `struct.new_default_desc` and `struct.new_desc` fold opportunities with a rebuilt 20-case dedicated-profile smoke and a 1000-case direct smoke, both green. Research note `1028` added an ordinary catchable `try_table` / `throw` skip-local-set hazard with a rebuilt 20-case dedicated-profile smoke and a 1000-case direct smoke, both green. Research note `1029` added the descriptor `struct.new_desc` catch/throw skip-local-set counterpart with the same smoke shape, both green. Research note `1030` added the descriptor `struct.new_desc` branch skip-local-set counterpart with the same smoke shape, both green. Research note `1031` added a descriptor `struct.new_desc` old-field `memory.grow` side-effect root with the same smoke shape, both green. Research note `1032` added a descriptor `struct.new_desc` result-typed `try_table` set-value root with the same smoke shape, both green. Research note `1033` added a descriptor `struct.new_desc` later-field result-typed `try_table` root with the same smoke shape, both green. Research note `1034` added a result-typed same-resource `try_table` / `memory.fill` barrier root with the same smoke shape, both green. Research note `1035` added a result-typed cross-family `try_table` / `table.set` fold-positive root with the same smoke shape, both green. Research note `1036` added a catchable result-typed `try_table` / `memory.fill` barrier root with the same smoke shape, both green. Research note `1037` added a table-side result-typed `try_table` / `i32.store` fold-positive root with the same smoke shape, both green. Research note `1038` added result-typed cross-family growth roots for `memory.size` / `table.grow` and `table.size` / `memory.grow` with the same smoke shape, both green. Research note `1039` added a table-side result-typed same-resource `try_table` / `table.fill` barrier root with the same smoke shape, both green. Research note `1040` attempted a descriptor `br_on_non_null` branch-result profile root and exposed a Starshine command-failure blocker; research note `1041` fixed the HOT verifier/lowerer blockers, committed the exact descriptor `br_on_non_null` profile root, and reran green focused fuzz, 20-case dedicated-profile, and 1000-case direct smokes. Research note `1042` added catchable result-typed direct-call wrapper coverage with matching green focused fuzz and compare-smoke evidence; research note `1043` added the matching `call_ref` wrapper coverage with green focused fuzz and compare-smoke evidence; research note `1044` added the matching `call_indirect` wrapper coverage with green focused fuzz and compare-smoke evidence; research note `1045` added mutable-descriptor result-wrapper old-field coverage with green focused fuzz and compare-smoke evidence; research note `1046` added a call-containing old-field value-block root with green focused fuzz and compare-smoke evidence. Research note `1047` documents why the `1046` root was not a true call-result old-field generator: the dedicated profile previously fixed no-param/no-result function signatures. Research note `1054` adds the direct-call-result generated floor with an HSO-only no-param `(result i32)` helper; research note `1056` adds the matching plain `call_indirect` result old-field generated floor; research note `1057` adds the matching plain `call_ref` result old-field generated floor; research note `1058` adds the pure-descriptor direct-call-result old-field generated floor; research note `1059` adds the mutable-descriptor direct-call-result old-field generated floor; research note `1060` adds the descriptor `call_indirect` result old-field generated floor; research note `1061` adds the descriptor `call_ref` result old-field generated floor; research note `1062` adds the direct `return_call` result-wrapper old-field generated floor; research note `1063` adds the `return_call_indirect` result-wrapper old-field generated floor; research note `1064` adds the `return_call_ref` result-wrapper old-field generated floor; research note `1065` adds the pure-descriptor direct `return_call` result-wrapper old-field generated floor; research note `1066` adds the pure-descriptor `return_call_indirect` result-wrapper old-field generated floor; research note `1067` adds the pure-descriptor `return_call_ref` result-wrapper old-field generated floor; research note `1068` adds the mutable-descriptor direct `return_call` result-wrapper old-field generated floor; research note `1069` adds the mutable-descriptor `return_call_indirect` result-wrapper old-field generated floor; research note `1070` adds the mutable-descriptor `return_call_ref` result-wrapper old-field generated floor. Plain, pure-descriptor, and mutable-descriptor generated tail-call result-wrapper old-field coverage now includes direct, indirect, and typed-function-reference spellings. The `1074` D/E audit keeps source-backed HSO-D/E open despite this generated coverage: exact descriptor `ref.cast` remains decode-blocked, arbitrary descriptor/later-field expression coverage is not proven exhaustive, and no broad default/descriptor/moved-value drift is approved.

## Binaryen v131 renewal evidence

The 2026-07-28 renewal used the verified `.tmp/binaryen-version-131-bin/bin/wasm-opt` (`wasm-opt version 131 (version_131)`) and a freshly rebuilt native Starshine CLI. The final aggregate lane at seed `0x5eed` compared `10000/10000` cases: `2155` normalized matches, `7845` `local-cleanup-debris` matches, and zero mismatches, validation failures, property failures, generator failures, or command failures. All nine leaves were selected, including the shared-ordering leaf. Binaryen oracle outputs were `10000/10000` cache hits on the final rerun.

Official fixture replay additionally covers the released v131 main HSO, descriptor, and ordered-atomics tests. The descriptor fixture retains null and nested-null trap boundaries and folds the nontrapping nested descriptor chain. The atomics fixture roundtrips acquire/release order and keeps the nullable-descriptor ordinary-memory-store boundary ordered. Residual text differences are classified measured Starshine wins: omitted Binaryen `nop` placeholders, safe additional fresh-store folds, and preserved no-op function bodies instead of unnecessary HOT re-lowering. Stripped official outputs are smaller for main HSO (`1153` versus `1175` bytes), descriptor (`118` versus `119`), and atomics (`300` versus `314`).
