# DAE003-C local-carrier closeout

## Scope

Close `[DAE003-C]` for the current conservative non-adjacent local-carrier surface. This is a validation/classification slice, not a behavior-changing optimizer change.

## Evidence

The implemented and documented local-carrier subset now covers:

- positive straight-line carrier: `i32.const 77; local.set 0; local.get 0; call $target` (`0639`),
- negative local-tee and multiple-write guards (`0640`),
- negative earlier same-local read / multiple-get guard (`0641`),
- negative trapping and effectful producers (`0642`),
- conservative self-recursive and `ref.func` escaped-callee policy (`0643`).

Structured carriers are explicitly separate under `[DAE003-F]`; typed single-instruction `block` support is recorded in `0644`, while loops, branchy/multi-instruction blocks, if, try, and try_table carriers remain open there.

## Validation

- `moon test src/passes` passed: 1402 tests.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae003c-closure-20260526` wrote artifacts and stopped at the current known failure threshold after `45/10000` compared cases, with `26` normalized matches, `19` normalized mismatches, `0` validation failures, `0` generator failures, and `1` Binaryen/tool command failure.

## Agent classification

The lone command failure is the known Binaryen/tool `binaryen-rec-group-zero` parse failure from `case-000029-wasm-smith`.

The `19` normalized mismatches are kept in the accepted DAE010/DAE011 `gen-valid` raw-cleanup / size-winning semantic-safe family for this closeout slice: no validation failures were observed, the mismatch family is the same early stopped direct-DAE gen-valid family already documented for recent DAE003/DAE010 refreshes, and this run made no behavior changes beyond the already-tested local-carrier subset. This classification is an agent judgment, not a harness-provided proof.

## Conclusion

`[DAE003-C]` is closed for the current conservative local-carrier subset. Reopen it only for a new concrete non-structured local-carrier semantic mismatch, validation failure, escape/self-cycle unsoundness, or evidence that a currently guarded straight-line local carrier can be accepted safely. Continue structured-carrier work under `[DAE003-F]` and artifact/signoff breadth under `[DAE003-I]`.
