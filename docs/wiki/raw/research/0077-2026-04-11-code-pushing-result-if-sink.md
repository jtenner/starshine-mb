# 0077 - Code-Pushing Result-`if` Arm Sink

## Scope

- Recheck whether Binaryen `code-pushing` really forbids sinking a `local.set`
  into a result-producing `if` arm.
- Compare that question against the current Starshine fence in
  `cp_try_sink_into_if`.
- Use a reduced Binaryen probe plus current debug-artifact slices to decide
  whether the fence is a true parity boundary or just an over-conservative
  Starshine bailout.

## Primary Sources

- Existing project study:
  [`docs/0073-2026-04-02-code-pushing-binaryen-plan.md`](../../../0073-2026-04-02-code-pushing-binaryen-plan.md)
- Existing `func $127` artifact reread:
  [`0076-2026-04-11-code-pushing-func-127-binaryen-noop.md`](./0076-2026-04-11-code-pushing-func-127-binaryen-noop.md)
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
  (func (param i32 i64) (result i64)
    (local i64)
    (local.get 1)
    (local.set 2)
    (if (result i64)
      (local.get 0)
      (then
        (local.get 2))
      (else
        (i64.const 0)))))
```

Binaryen `wasm-opt --code-pushing -S` output:

```wat
(module
 (type $0 (func (param i32 i64) (result i64)))
 (func $0 (type $0) (param $0 i32) (param $1 i64) (result i64)
  (local $2 i64)
  (nop)
  (if (result i64)
   (local.get $0)
   (then
    (local.set $2
     (local.get $1)
    )
    (local.get $2)
   )
   (else
    (i64.const 0)
   )
  )
 )
)
```

## Artifact Corroboration

- A fresh Binaryen no-pass vs `--code-pushing` diff on the current debug artifact
  shows value-producing one-arm sinks too.
- The clearest reduced body slice came from body index `1954`
  (absolute function index `1975` once the `21` imported funcs are counted).
- In that function Binaryen rewrites:
  - `local.set $11 (local.get $17)` before a result-producing `if`
- into:
  - `nop` in the old slot
  - the same `local.set` prepended to the taken arm of that result-producing
    `if`
- That shape matches the reduced probe above and contradicts Starshine's old
  blanket `cp_node_has_nonvoid_result(func, if_id) => return false` fence.

## Conclusion

- Binaryen does allow one-arm `if` sinks when the `if` itself produces a value.
- The relevant restriction is not "the `if` must be void".
- The real upstream restriction remains the one already noted in `0073`:
  Binaryen avoids sinking `unreachable`-typed sets because that would change
  surrounding reachability and require refinalization.
- Starshine's old result-`if` fence in `cp_try_sink_into_if` was therefore an
  over-conservative parity bug, not a deliberate Binaryen match.

## Kept Repository Change

- `src/passes/code_pushing.mbt` now lets `cp_try_sink_into_if` consider
  result-producing `if` roots too.
- `src/passes/code_pushing_test.mbt` now pins the reduced result-`if` arm sink
  directly and also keeps native debug-artifact lowering probes for current
  Binaryen-matched changed functions.

## Validation

- `moon test src/passes/code_pushing_test.mbt`
- `moon test src/cmd/cmd_test.mbt`
- `bun scripts/pass-fuzz-compare.ts --pass code-pushing --generator gen-valid --count 10000 --max-failures 5 --out-dir .tmp/pass-fuzz-code-pushing-20260411e`
- `bun scripts/pass-fuzz-compare.ts --pass code-pushing --generator wasm-smith --count 1000 --max-failures 5 --out-dir .tmp/pass-fuzz-code-pushing-20260411f`

## Practical Decision

- Treat result-producing `if` arm sinks as part of the intended Binaryen surface.
- Keep the broader non-void carrier and explicit-exit fences in place, but do not
  use a blanket result-`if` ban as a proxy for those harder lowering risks.
