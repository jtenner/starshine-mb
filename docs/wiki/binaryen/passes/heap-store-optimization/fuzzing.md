---
kind: workflow
status: working
last_reviewed: 2026-06-25
sources:
  - ../../../raw/research/1023-2026-06-24-heap-store-optimization-genvalid-profile.md
  - ../../../raw/research/1024-2026-06-24-heap-store-optimization-default-profile-and-void-try-table.md
  - ../../../raw/research/1025-2026-06-24-heap-store-optimization-try-table-profile-coverage.md
  - ../../../raw/research/1026-2026-06-24-heap-store-optimization-profile-control-store-barriers.md
  - ../../../raw/research/1027-2026-06-24-heap-store-optimization-profile-descriptor-constructors.md
  - ../../../raw/research/1028-2026-06-24-heap-store-optimization-profile-catch-throw-skip-local-set.md
  - ../../../raw/research/1029-2026-06-24-heap-store-optimization-profile-descriptor-catch-throw.md
  - ../../../raw/research/1030-2026-06-24-heap-store-optimization-profile-descriptor-branch-skip.md
  - ../../../raw/research/1031-2026-06-24-heap-store-optimization-profile-descriptor-oldfield-memory-grow.md
  - ../../../raw/research/1032-2026-06-24-heap-store-optimization-profile-descriptor-result-try-value.md
  - ../../../raw/research/1033-2026-06-24-heap-store-optimization-profile-descriptor-later-result-field.md
  - ../../../raw/research/1034-2026-06-24-heap-store-optimization-profile-result-memory-fill.md
  - ../../../raw/research/1035-2026-06-25-heap-store-optimization-profile-result-table-set.md
  - ../../../raw/research/1036-2026-06-25-heap-store-optimization-profile-catchable-result-memory-fill.md
  - ../../../raw/research/1037-2026-06-25-heap-store-optimization-profile-result-i32-store.md
  - ../../../raw/research/1038-2026-06-25-heap-store-optimization-profile-result-growth.md
  - ../../../raw/research/1039-2026-06-25-heap-store-optimization-profile-result-table-fill.md
  - ../../../raw/research/1040-2026-06-25-heap-store-optimization-profile-descriptor-br-on-non-null-blocker.md
  - ../../../raw/research/1041-2026-06-25-heap-store-optimization-profile-descriptor-br-on-non-null.md
  - ../../../raw/research/1042-2026-06-25-heap-store-optimization-profile-catchable-call.md
  - ../../../raw/research/1043-2026-06-25-heap-store-optimization-profile-catchable-call-ref.md
  - ../../../raw/research/1044-2026-06-25-heap-store-optimization-profile-catchable-call-indirect.md
  - ../../../raw/research/1045-2026-06-25-heap-store-optimization-profile-mutable-descriptor-old-field.md
  - ../../../raw/research/1046-2026-06-25-heap-store-optimization-profile-call-old-field.md
  - ../../../raw/research/1047-2026-06-25-heap-store-optimization-profile-call-result-old-field-blocker.md
  - ../../../raw/research/1054-2026-06-25-heap-store-optimization-profile-direct-call-result-oldfield.md
  - ../../../raw/research/1056-2026-06-25-heap-store-optimization-profile-call-indirect-result-oldfield.md
  - ../../../raw/research/1057-2026-06-25-heap-store-optimization-profile-call-ref-result-oldfield.md
  - ../../../raw/research/1058-2026-06-25-heap-store-optimization-profile-descriptor-call-result-oldfield.md
  - ../../../raw/research/1059-2026-06-25-heap-store-optimization-profile-mutable-descriptor-call-result-oldfield.md
  - ../../../raw/research/1060-2026-06-25-heap-store-optimization-profile-descriptor-call-indirect-result-oldfield.md
  - ../../../raw/research/1061-2026-06-25-heap-store-optimization-profile-descriptor-call-ref-result-oldfield.md
  - ../../../raw/research/1062-2026-06-25-heap-store-optimization-profile-return-call-oldfield.md
  - ../../../raw/research/1063-2026-06-25-heap-store-optimization-profile-return-call-indirect-oldfield.md
  - ../../../raw/research/1064-2026-06-25-heap-store-optimization-profile-return-call-ref-oldfield.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/fuzz/main_wbtest.mbt
---

# `heap-store-optimization` Fuzzing Profile

Recommended ordinary mixed-generator smoke lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Dedicated GenValid profile: `heap-store-optimization` (alias: `hso`). It emits valid GC modules with deterministic HSO-owned opportunities:

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
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-genvalid-profile-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Use `--normalize local-cleanup-debris` for this profile while Starshine removes folded-store `nop` roots that Binaryen retains. Research note `1023` classified the initial 20-case raw mismatch family as a Starshine-win cleanup drift: Binaryen output kept `(nop)` placeholders after HSO folds, while Starshine emitted smaller validated output without those dead roots.

Manifest triage fields:

- `config_label`: `heap-store-optimization` for direct requests;
- `selected_profile`: `heap-store-optimization` because this is currently a leaf profile;
- `facts.has_gc_constructors` and `facts.has_gc_accessors`: expected true for emitted profile cases.

Broader generated descriptor barriers and broader control-flow/store-barrier generators beyond the current call-containing plain old-field value block, non-throwing void `try_table` / `table.set`, same-resource void/result `memory.fill`, catchable result `memory.fill`, table-side result `table.fill`, result-typed cross-family `table.set`, `i32.store`, and growth roots, contained-control `br_if`, ordinary and descriptor catchable `throw`, descriptor branch skip-local-set, descriptor exact `br_on_non_null` branch-result operands, catchable direct-call, `call_indirect`, and `call_ref` result wrappers, descriptor old-field `memory.grow`, mutable-descriptor result-wrapper old-field `memory.grow`, descriptor result-typed set-value, and descriptor later-field result-wrapper roots remain future work. Research note `1025` re-enabled the `1024` generated try-table family after focused mixed-field tests and a rebuilt 20-case dedicated-profile smoke lane were compare-normalized green. Research note `1026` added the `memory.fill` no-fold barrier and contained-branch table-store profile roots with a rebuilt 20-case dedicated-profile smoke and a 1000-case direct smoke, both green. Research note `1027` added descriptor `struct.new_default_desc` and `struct.new_desc` fold opportunities with a rebuilt 20-case dedicated-profile smoke and a 1000-case direct smoke, both green. Research note `1028` added an ordinary catchable `try_table` / `throw` skip-local-set hazard with a rebuilt 20-case dedicated-profile smoke and a 1000-case direct smoke, both green. Research note `1029` added the descriptor `struct.new_desc` catch/throw skip-local-set counterpart with the same smoke shape, both green. Research note `1030` added the descriptor `struct.new_desc` branch skip-local-set counterpart with the same smoke shape, both green. Research note `1031` added a descriptor `struct.new_desc` old-field `memory.grow` side-effect root with the same smoke shape, both green. Research note `1032` added a descriptor `struct.new_desc` result-typed `try_table` set-value root with the same smoke shape, both green. Research note `1033` added a descriptor `struct.new_desc` later-field result-typed `try_table` root with the same smoke shape, both green. Research note `1034` added a result-typed same-resource `try_table` / `memory.fill` barrier root with the same smoke shape, both green. Research note `1035` added a result-typed cross-family `try_table` / `table.set` fold-positive root with the same smoke shape, both green. Research note `1036` added a catchable result-typed `try_table` / `memory.fill` barrier root with the same smoke shape, both green. Research note `1037` added a table-side result-typed `try_table` / `i32.store` fold-positive root with the same smoke shape, both green. Research note `1038` added result-typed cross-family growth roots for `memory.size` / `table.grow` and `table.size` / `memory.grow` with the same smoke shape, both green. Research note `1039` added a table-side result-typed same-resource `try_table` / `table.fill` barrier root with the same smoke shape, both green. Research note `1040` attempted a descriptor `br_on_non_null` branch-result profile root and exposed a Starshine command-failure blocker; research note `1041` fixed the HOT verifier/lowerer blockers, committed the exact descriptor `br_on_non_null` profile root, and reran green focused fuzz, 20-case dedicated-profile, and 1000-case direct smokes. Research note `1042` added catchable result-typed direct-call wrapper coverage with matching green focused fuzz and compare-smoke evidence; research note `1043` added the matching `call_ref` wrapper coverage with green focused fuzz and compare-smoke evidence; research note `1044` added the matching `call_indirect` wrapper coverage with green focused fuzz and compare-smoke evidence; research note `1045` added mutable-descriptor result-wrapper old-field coverage with green focused fuzz and compare-smoke evidence; research note `1046` added a call-containing old-field value-block root with green focused fuzz and compare-smoke evidence. Research note `1047` documents why the `1046` root was not a true call-result old-field generator: the dedicated profile previously fixed no-param/no-result function signatures. Research note `1054` adds the direct-call-result generated floor with an HSO-only no-param `(result i32)` helper; research note `1056` adds the matching plain `call_indirect` result old-field generated floor; research note `1057` adds the matching plain `call_ref` result old-field generated floor; research note `1058` adds the pure-descriptor direct-call-result old-field generated floor; research note `1059` adds the mutable-descriptor direct-call-result old-field generated floor; research note `1060` adds the descriptor `call_indirect` result old-field generated floor; research note `1061` adds the descriptor `call_ref` result old-field generated floor; research note `1062` adds the direct `return_call` result-wrapper old-field generated floor; research note `1063` adds the `return_call_indirect` result-wrapper old-field generated floor; research note `1064` adds the `return_call_ref` result-wrapper old-field generated floor. Plain generated tail-call result-wrapper old-field coverage now includes direct, indirect, and typed-function-reference spellings; descriptor and mutable-descriptor tail-call generated siblings remain reopening work rather than covered generated-profile families.
