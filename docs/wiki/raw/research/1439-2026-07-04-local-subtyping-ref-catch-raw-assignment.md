# Local-subtyping ref-catch raw-assignment parity slice

Date: 2026-07-04

## Question

Can Starshine close the `catch_ref` / `catch_all_ref` skipped-write residual without waiting for full HOT lifting of ref-catch result-flow modules?

## Sources and probes

- Prior classification: [`1436-2026-07-04-local-subtyping-ref-catch-handler-flow.md`](1436-2026-07-04-local-subtyping-ref-catch-handler-flow.md).
- Implementation and focused coverage: `src/passes/local_subtyping.mbt` and `src/passes/local_subtyping_test.mbt`.
- Local reduced probes under `.tmp/ls-ref-catch-impl-20260704/`:
  - `catch-ref-skipped-struct-write.wat`
  - `catch-all-ref-skipped-struct-write.wat`

## Findings

The prior blocker was narrower than full handler-flow modeling. Starshine did not need to HOT-lift the ref-catch result-flow shape in order to collect enough assignment evidence for the probed skipped-write family. A conservative raw assignment collector can walk the lib instruction body, record writes to reference body locals, and infer only local producer types it can prove directly from raw instructions such as `ref.null`, `struct.new_default`, `array.new_default`, `local.get`, `ref.as_non_null`, simple blocks, and typed `select`.

Unknown producers are deliberately fail-closed by recording the declared local type for that assignment. That prevents the raw path from narrowing through incomplete stack typing. The ref-catch path also disables non-null dominance facts entirely, so skipped handler paths can only produce nullable local rewrites.

For the reduced `catch_ref` and `catch_all_ref` skipped-write probes, local Binaryen v130 narrows `$x` from `(ref null $base)` to `(ref null (exact $child))`. The new Starshine raw-assignment path does the same while preserving validating output.

## Commands and results

- `wasm-tools validate --features all .tmp/ls-ref-catch-impl-20260704/catch-ref-skipped-struct-write.wat` — passed.
- `wasm-opt --all-features --local-subtyping .tmp/ls-ref-catch-impl-20260704/catch-ref-skipped-struct-write.wat -S -o .tmp/ls-ref-catch-impl-20260704/catch-ref-skipped-struct-write.binaryen.v130.wat` — passed; Binaryen output declares `$x` as `(ref null (exact $child))`.
- `wasm-tools validate --features all .tmp/ls-ref-catch-impl-20260704/catch-ref-skipped-struct-write.binaryen.v130.wat` — passed.
- `wasm-tools validate --features all .tmp/ls-ref-catch-impl-20260704/catch-all-ref-skipped-struct-write.wat` — passed.
- `wasm-opt --all-features --local-subtyping .tmp/ls-ref-catch-impl-20260704/catch-all-ref-skipped-struct-write.wat -S -o .tmp/ls-ref-catch-impl-20260704/catch-all-ref-skipped-struct-write.binaryen.v130.wat` — passed; Binaryen output declares `$x` as `(ref null (exact $child))`.
- `wasm-tools validate --features all .tmp/ls-ref-catch-impl-20260704/catch-all-ref-skipped-struct-write.binaryen.v130.wat` — passed.
- Red-first `moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt` after changing the ref-catch boundary tests — failed `71/73`; both new tests still saw the original nullable parent local.
- After implementation: `moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt` — passed `73/73`.
- `moon build --target native --release src/cmd` — passed with pre-existing warnings.
- `STARSHINE_PASSES=local-subtyping _build/native/release/build/cmd/cmd.exe .tmp/ls-ref-catch-impl-20260704/catch-ref-skipped-struct-write.wat --out .tmp/ls-ref-catch-impl-20260704/catch-ref-skipped-struct-write.starshine.current.wasm` — exited 0; printed the pre-existing `sh: 1: wat2wasm: not found` line; emitted wasm.
- `wasm-tools validate --features all .tmp/ls-ref-catch-impl-20260704/catch-ref-skipped-struct-write.starshine.current.wasm` — passed; printed output declares `$x` as `(ref null (exact $child))`.
- `STARSHINE_PASSES=local-subtyping _build/native/release/build/cmd/cmd.exe .tmp/ls-ref-catch-impl-20260704/catch-all-ref-skipped-struct-write.wat --out .tmp/ls-ref-catch-impl-20260704/catch-all-ref-skipped-struct-write.starshine.current.wasm` — exited 0; printed the pre-existing `sh: 1: wat2wasm: not found` line; emitted wasm.
- `wasm-tools validate --features all .tmp/ls-ref-catch-impl-20260704/catch-all-ref-skipped-struct-write.starshine.current.wasm` — passed; printed output declares `$x` as `(ref null (exact $child))`.
- `moon fmt` — passed.
- `moon info` — passed with pre-existing warnings.
- `moon test` — passed `7390/7390`.

## Classification

This slice fixes the concrete ref-catch skipped-write parity residual described in note `1436`. It is not a Starshine win and no residual in this family is intentionally diverging.

The implemented raw path is deliberately narrow: it exists to collect assignment types for functions containing `catch_ref` or `catch_all_ref` without HOT lifting those functions. It does not attempt full EH handler-flow or catch-payload result joins. Broad catch-payload joins stay broad because unknown assignments and unknown producers fall back to the declared local type, and ref-catch functions do not receive non-null dominance permission.

## Remaining LS residuals after this slice

- Direct block-return nondefaultable-local unreachable-tail validator/tooling boundary: still open under the reopening criteria from note `1437`.
- Raw-unreachable-before-write nondefaultable-local tee/get validator/tooling boundary: still open under the reopening criteria from note `1438`.

Final LS closeout still requires refreshed direct-pass evidence, including focused tests, `moon info`, `moon fmt`, `moon test`, native `src/cmd` build, regular GenValid, wasm-smith, LS-specific GenValid profile, and random all-profiles.
