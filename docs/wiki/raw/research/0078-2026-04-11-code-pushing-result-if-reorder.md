# 0078 - Code-Pushing Reorder Past Result-`if`

## Scope

- Recheck whether Binaryen `code-pushing` can move a `local.set` past a
  result-producing `if` without sinking into one arm.
- Compare that question against the current Starshine guard in
  `cp_try_push_to_pushpoint`.
- Use a reduced Binaryen probe plus current debug-artifact slices to decide
  whether the result-`if` pushpoint fence is a true parity boundary or an
  over-conservative Starshine bailout.

## Primary Sources

- Existing project study:
  [`docs/0073-2026-04-02-code-pushing-binaryen-plan.md`](../../../0073-2026-04-02-code-pushing-binaryen-plan.md)
- Existing result-`if` sink note:
  [`0077-2026-04-11-code-pushing-result-if-sink.md`](./0077-2026-04-11-code-pushing-result-if-sink.md)
- Upstream Binaryen source reread:
  <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/CodePushing.cpp>
- In-tree implementation and tests:
  - [`src/passes/code_pushing.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/passes/code_pushing.mbt)
  - [`src/passes/code_pushing_test.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/passes/code_pushing_test.mbt)
  - [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb-code-pushing/src/cmd/cmd_test.mbt)

## Reduced Binaryen Probe

Input:

```wat
(module
  (func (param i32) (local i32)
    i32.const 7
    local.set 1
    local.get 0
    if (result i32)
      i32.const 1
    else
      i32.const 0
    end
    drop
    local.get 1
    drop))
```

Binaryen `wasm-opt --code-pushing -S` output:

```wat
(module
 (type $0 (func (param i32)))
 (func $0 (type $0) (param $0 i32)
  (local $1 i32)
  (drop
   (if (result i32)
    (local.get $0)
    (then
     (i32.const 1))
    (else
     (i32.const 0))))
  (local.set $1
   (i32.const 7))
  (drop
   (local.get $1))
 ))
```

## Artifact Corroboration

- A fresh Binaryen no-pass vs `--code-pushing` diff on the current debug artifact
  shows the same family repeatedly.
- The cleanest visible examples are body indices:
  - `393` (absolute function index `414` with `21` imported funcs)
  - `412` (absolute function index `433`)
  - `488` (absolute function index `509`)
  - `633` (absolute function index `654`)
- In those functions Binaryen moves an alias `local.set` from before a
  result-producing `if` to immediately after the `if` when the `if` itself does
  not read or overwrite that local.

## Conclusion

- Binaryen does allow same-region reordering past a result-producing `if`.
- The relevant restriction is not "the pushpoint `if` must be void".
- The real condition is still the ordinary `code-pushing` one:
  - the pushed `local.set` must stay independent from the pushpoint's effects
  - later reads still have to justify moving the set after the pushpoint
- Starshine's old top-level result-`if` pushpoint bailout in
  `cp_try_push_to_pushpoint` was therefore an over-conservative parity bug.

## Kept Repository Change

- `src/passes/code_pushing.mbt` no longer rejects result-producing `if`
  pushpoints in `cp_try_push_to_pushpoint`.
- The same helper now also allows the normal "move after the pushpoint" decision
  when the result-producing `if` does not read or write the candidate local.
- `src/passes/code_pushing_test.mbt` now pins the reduced positive result-`if`
  reorder directly and validates the lowered output through `pass_test_run_pipeline`.

## Validation

- `moon test src/passes/code_pushing_test.mbt`
- `moon test src/cmd/cmd_test.mbt`
- `bun scripts/pass-fuzz-compare.ts --pass code-pushing --generator gen-valid --count 10000 --max-failures 5 --out-dir .tmp/pass-fuzz-code-pushing-20260411h`
- `bun scripts/pass-fuzz-compare.ts --pass code-pushing --generator wasm-smith --count 1000 --max-failures 5 --out-dir .tmp/pass-fuzz-code-pushing-20260411i`

## Practical Decision

- Treat reordering past a result-producing `if` as part of Binaryen's intended
  `code-pushing` surface.
- Keep the broader owner-sensitive non-void carrier fences, but do not use a
  blanket result-`if` pushpoint ban as a proxy for those harder cases.
