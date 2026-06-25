---
kind: workflow
status: working
last_reviewed: 2026-06-24
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
- `struct.new_default` materialization followed by same-local `struct.set`;
- descriptor-bearing `struct.new_default_desc` and `struct.new_desc` materialization followed by same-local `struct.set`;
- non-throwing void `try_table` / `table.set` wrappers between a fresh `memory.size` constructor and a later same-local `struct.set`;
- same-resource non-throwing void `try_table` / `memory.fill` barriers where the later `struct.set` should remain;
- contained-control non-throwing void `try_table` / `br_if` / `table.set` wrappers where the branch stays inside the root wrapper; and
- catchable `try_table` / `throw` skip-local-set hazards where exception control can skip the fresh-constructor `local.set` before a later same-local `struct.set`; and
- descriptor-bearing catchable `try_table` / `throw` skip-local-set hazards where the skipped local assignment materializes through `struct.new_desc`; and
- descriptor-bearing branch skip-local-set hazards where a `br_if` can skip the `struct.new_desc` local assignment; and
- descriptor-bearing old-field side-effect roots where an overwritten `memory.grow` field must be preserved before a same-field store fold; and
- descriptor-bearing result-typed `try_table` set-value roots where the moved same-field store value is produced by the result wrapper; and
- descriptor-bearing later-field result-typed `try_table` roots where another constructor field comes from the result wrapper before a same-field store fold; and
- result-typed same-resource `try_table` / `memory.fill` barriers where the later `struct.set` should remain;
- result-typed cross-family `try_table` / `table.set` roots where a `memory.size` constructor can still fold across the unrelated table store;
- catchable result-typed `try_table` / `memory.fill` barriers where the wrapper can branch to a local catch and the later `struct.set` should remain; and
- table-side result-typed cross-family `try_table` / `i32.store` roots where a `table.size` constructor can still fold across the unrelated memory store.

Recommended dedicated-profile smoke lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-genvalid-profile-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Use `--normalize local-cleanup-debris` for this profile while Starshine removes folded-store `nop` roots that Binaryen retains. Research note `1023` classified the initial 20-case raw mismatch family as a Starshine-win cleanup drift: Binaryen output kept `(nop)` placeholders after HSO folds, while Starshine emitted smaller validated output without those dead roots.

Manifest triage fields:

- `config_label`: `heap-store-optimization` for direct requests;
- `selected_profile`: `heap-store-optimization` because this is currently a leaf profile;
- `facts.has_gc_constructors` and `facts.has_gc_accessors`: expected true for emitted profile cases.

Broader generated descriptor barriers and broader control-flow/store-barrier generators beyond the current non-throwing void `try_table` / `table.set`, same-resource void/result `memory.fill`, catchable result `memory.fill`, result-typed cross-family `table.set` and `i32.store`, contained-control `br_if`, ordinary and descriptor catchable `throw`, descriptor branch skip-local-set, descriptor old-field `memory.grow`, descriptor result-typed set-value, and descriptor later-field result-wrapper roots remain future work. Research note `1025` re-enabled the `1024` generated try-table family after focused mixed-field tests and a rebuilt 20-case dedicated-profile smoke lane were compare-normalized green. Research note `1026` added the `memory.fill` no-fold barrier and contained-branch table-store profile roots with a rebuilt 20-case dedicated-profile smoke and a 1000-case direct smoke, both green. Research note `1027` added descriptor `struct.new_default_desc` and `struct.new_desc` fold opportunities with a rebuilt 20-case dedicated-profile smoke and a 1000-case direct smoke, both green. Research note `1028` added an ordinary catchable `try_table` / `throw` skip-local-set hazard with a rebuilt 20-case dedicated-profile smoke and a 1000-case direct smoke, both green. Research note `1029` added the descriptor `struct.new_desc` catch/throw skip-local-set counterpart with the same smoke shape, both green. Research note `1030` added the descriptor `struct.new_desc` branch skip-local-set counterpart with the same smoke shape, both green. Research note `1031` added a descriptor `struct.new_desc` old-field `memory.grow` side-effect root with the same smoke shape, both green. Research note `1032` added a descriptor `struct.new_desc` result-typed `try_table` set-value root with the same smoke shape, both green. Research note `1033` added a descriptor `struct.new_desc` later-field result-typed `try_table` root with the same smoke shape, both green. Research note `1034` added a result-typed same-resource `try_table` / `memory.fill` barrier root with the same smoke shape, both green. Research note `1035` added a result-typed cross-family `try_table` / `table.set` fold-positive root with the same smoke shape, both green. Research note `1036` added a catchable result-typed `try_table` / `memory.fill` barrier root with the same smoke shape, both green. Research note `1037` added a table-side result-typed `try_table` / `i32.store` fold-positive root with the same smoke shape, both green.
