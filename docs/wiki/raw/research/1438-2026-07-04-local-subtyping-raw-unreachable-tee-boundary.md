# Local-subtyping raw-unreachable tee/get boundary refresh

Date: 2026-07-04

## Question

Can Starshine safely match Binaryen's non-null narrowing for the `local-subtyping` lit-style raw `unreachable` before a `local.tee`, followed by a later `local.get` of the same local?

## Reduced shape

The refreshed WAT probe uses an exact function-typed nullable body local, a raw `unreachable`, a `block` result produced by `local.tee`, and a later `local.get`:

```wat
(module
  (type $base (sub (struct)))
  (type $child (sub $base (struct)))
  (type $main_t (func (param (ref $child))))
  (type $callee_t (func))
  (elem declare func $callee)
  (func $main (type $main_t) (param $p (ref $child))
    (local $temp (ref null $callee_t))
    unreachable
    (drop
      (block (result (ref null $callee_t))
        (local.tee $temp
          (ref.func $callee))))
    (drop (local.get $temp)))
  (func $callee (type $callee_t)))
```

Probe path: `.tmp/ls-raw-unreachable-tee-20260704/unreachable-before-write-tee-get-helper-shape-declare.wat`.

## Findings

- `wasm-tools validate --features all` accepts the source probe.
- Binaryen v130 still narrows `$temp` to a non-null exact callee type under `--local-subtyping`.
- `wasm-tools validate --features all` rejects the Binaryen v130 output with `uninitialized local: 1` at the later `local.get`.
- After rebuilding `_build/native/release/build/cmd/cmd.exe` from the current Starshine source, `STARSHINE_PASSES=local-subtyping` keeps `$temp` nullable exact, exits 0, and the emitted wasm validates with `wasm-tools`.
- The CLI still prints the pre-existing `sh: 1: wat2wasm: not found` line while succeeding; that line is unrelated to the LS classification.
- A new focused WAT-parsed test, `local-subtyping keeps WAT exact nullable for raw unreachable tee boundary`, locks this exact surface in `src/passes/local_subtyping_test.mbt`.

## Commands and results

```sh
wasm-tools validate --features all \
  .tmp/ls-raw-unreachable-tee-20260704/unreachable-before-write-tee-get-helper-shape-declare.wat
```

Result: passed.

```sh
wasm-opt --all-features --local-subtyping \
  .tmp/ls-raw-unreachable-tee-20260704/unreachable-before-write-tee-get-helper-shape-declare.wat \
  -S \
  -o .tmp/ls-raw-unreachable-tee-20260704/unreachable-before-write-tee-get-helper-shape-declare.binaryen.v130.wat

wasm-tools validate --features all \
  .tmp/ls-raw-unreachable-tee-20260704/unreachable-before-write-tee-get-helper-shape-declare.binaryen.v130.wat
```

Result: Binaryen emitted a non-null exact local; `wasm-tools` rejected it with `uninitialized local: 1`.

```sh
moon build --target native --release src/cmd

STARSHINE_PASSES=local-subtyping \
  _build/native/release/build/cmd/cmd.exe \
  .tmp/ls-raw-unreachable-tee-20260704/unreachable-before-write-tee-get-helper-shape-declare.wat \
  --out .tmp/ls-raw-unreachable-tee-20260704/unreachable-before-write-tee-get-helper-shape-declare.starshine.current.wasm

wasm-tools validate --features all \
  .tmp/ls-raw-unreachable-tee-20260704/unreachable-before-write-tee-get-helper-shape-declare.starshine.current.wasm
```

Result: Starshine exited 0 and the emitted wasm validated. The printed output shows the body local as `(ref null (exact $callee_t))`.

```sh
moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt
```

Result after adding the focused WAT-parsed guard: passed `73/73`.

## Classification

This is a precise validator/tooling boundary, not a Starshine win. Binaryen v130 exposes a non-null narrowing for this shape, but the reduced Binaryen output is currently rejected by `wasm-tools` as a nondefaultable local use after raw unreachable flow. Starshine keeps the local nullable exact and emits validating wasm.

This refresh narrows the residual from a broad `raw-unreachable-before-write` concern to this exact tee/get nondefaultable-local proof boundary. It should remain open as an LS residual until Starshine can intentionally prove or repair the non-null shape, or until Binaryen/tooling behavior changes.

## Reopening criteria

Reopen for implementation when any of the following becomes true:

- the reduced Binaryen non-null output validates under the current validator/toolchain;
- Starshine validation gains a spec-backed proof that the raw-unreachable tee write safely initializes the nondefaultable local for the later get;
- LS can rewrite or repair the unreachable-tail use so that Binaryen's non-null narrowing can be represented while still emitting wasm accepted by `wasm-tools` and Starshine validation;
- a separate reduced case in this family validates today and shows a Binaryen-observable narrowing that Starshine misses.

Until then, do not classify the nullable Starshine output as a measured Starshine win; it is a validation-preserving boundary fallback.
