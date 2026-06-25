---
kind: research
status: supported
last_reviewed: 2026-06-25
sources:
  - ../../binaryen/passes/code-pushing/fuzzing.md
  - ../../binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_test.mbt
  - ../../../../src/validate/gen_valid.mbt
---

# Code-pushing value-`br_if` lowering blocker refresh

## Question

Can the targeted `code-pushing-br-if-value` GenValid leaf be added to the aggregate `code-pushing-all` profile during `[O4Z-AUDIT-CP]`?

## Short answer

No. A current targeted compare still exposes a consistent value-`br_if` lowering representation and size gap, not a missing `code-pushing` movement proof. Starshine and Binaryen both sink the pure local sets after the branch-value `br_if`, but Starshine lowers the fallthrough value through a temporary local and then drops that temporary. Binaryen emits a direct `drop (br_if ...)` shape. Until this lowering gap is fixed or explicitly normalized, `code-pushing-br-if-value` should remain targeted-only and excluded from `code-pushing-all`.

## Evidence

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-br-if-value --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-br-if-value-refresh-100-20260625 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result:

- requested `100`, compared `35`, max-failures hit;
- normalized matches `0`;
- cleanup-normalized matches `0`;
- raw mismatches `35`;
- validation failures `0`;
- generator failures `0`;
- property failures `0`;
- command failures `0`;
- cache: `wasm-smith 0 hits/0 misses`, Binaryen `35 hits/0 misses`, Binaryen failures `0 hits/0 misses`;
- selected profile counts: `code-pushing-br-if-value: 35`.

Representative mismatch: `.tmp/pass-fuzz-code-pushing-br-if-value-refresh-100-20260625/failures/case-000001-gen-valid`.

Input:

```wat
(module
  (type (;0;) (func (param i32) (result i32)))
  (func (;0;) (type 0) (param i32) (result i32)
    (local i32 i32)
    block (result i32)
      i32.const 7
      local.set 1
      i32.const 9
      local.set 2
      i32.const 42
      local.get 0
      br_if 0
      drop
      local.get 1
      drop
      local.get 2
    end))
```

Binaryen normalized shape:

```wat
(block $block (result i32)
  (drop
    (br_if $block
      (i32.const 42)
      (local.get $0)))
  (local.set $1 (i32.const 7))
  (local.set $2 (i32.const 9))
  (drop (local.get $1))
  (local.get $2))
```

Starshine normalized shape:

```wat
(block $block (result i32)
  (local.set $3
    (br_if $block
      (i32.const 42)
      (local.get $0)))
  (local.set $1 (i32.const 7))
  (local.set $2 (i32.const 9))
  (drop (local.get $3))
  (drop (local.get $1))
  (local.get $2))
```

## Classification

Agent classification: size-losing lowering/normalization blocker. The pass movement itself matches the source-backed branch-value `br_if` contract: the pure SFA sets move after the branch and preserve order. The remaining mismatch is the extra Starshine temporary local used to represent the fallthrough value of a value-`br_if` before a later `drop`.

This remains a blocker for aggregating `code-pushing-br-if-value` into `code-pushing-all` because the direct compare lane produces raw mismatches on every inspected targeted case even with `--normalize local-cleanup-debris`.

## Follow-up

- Preferred fix: teach HOT lowering or a canonical cleanup to emit or normalize `drop (br_if ...)` when a value `br_if` fallthrough result is immediately dropped and no later use observes the temporary.
- Alternative: add a compare normalizer only if it is narrow enough to prove the temporary-local pattern is unobservable and not size-regressing for the pass closeout contract.
- Do not include `code-pushing-br-if-value` in `code-pushing-all` until the targeted lane stops producing this mismatch family or the family is explicitly accepted with size/semantic evidence.
