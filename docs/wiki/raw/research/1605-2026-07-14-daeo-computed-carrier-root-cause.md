# DAEO computed-carrier root cause

Date: 2026-07-14

## Scope

This note identifies the first source-backed cause of the remaining Func `7007..7010` `i32` signature gap. It supersedes the working hypothesis in notes `1603` and `1604` that an optimizing-after-inlining value proof must turn Func `7007`'s computed call-result locals into literal zero.

## Controlled Binaryen v130 probes

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

A direct **plain** Binaryen v130 DAE run already removes the target `i32` parameters:

```text
wasm-opt --all-features --dae
```

The resulting defined functions `7007`, `7008`, and `7010` have no `i32` parameter. Therefore `OptUtils::optimizeAfterInlining(...)` is not the prerequisite for this family.

A focused body comparison exposes the earlier dependency:

- absolute Func `7054` / defined Func `7033` begins as `(param (ref 158) i32 i32) (result i32)`;
- its body reads parameters `0` and `2`, but never parameter `1`;
- Func `7007` passes its cycle-carried `i32` parameter into that unread position;
- Binaryen plain DAE first removes Func `7033` parameter `1`, then ordinary repeated liveness/removal makes the corresponding Func `7007` parameter unread and propagates that deadness through Func `7008` and Func `7010`.

The computed values later passed from Func `7007` to Func `7010` do **not** need to be proven equal to zero. Once the cycle-carried parameter has no semantic use, those call operands can be removed while their independent producers remain in place.

## Primary-source contract

Binaryen v130 `DeadArgumentElimination.cpp` scans parameter liveness, removes unread parameters, marks changed functions and callers stale, and iterates to convergence. `ParamUtils::removeParameter(...)` removes a call operand only when its effects are removable; otherwise DAE localizes and retries. Constant inference remains limited to literal and immutable-global expressions by `PossibleConstantValues`, but that constant path is not the owner of this artifact family.

Sources:

- [`DeadArgumentElimination.cpp`](https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/DeadArgumentElimination.cpp), especially `DAEScanner::doWalkFunction`, the converging `iteration(...)` loop, stale-caller propagation, and unread-parameter removal;
- [`param-utils.cpp`](https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/param-utils.cpp), especially `getUsedParams(...)`, `removeParameter(...)`, and `removeParameters(...)`;
- [`possible-constant.h`](https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/possible-constant.h), retained as the boundary proving that arbitrary computed locals are not constant evidence.

## Reduced red-first fixture

A generated broad-module fixture in `src/passes/dae_optimizing_test.mbt` places eight earlier unread-parameter candidates before an adjacent high-local forwarding component. The component contains:

1. an exact forwarded parameter cycle across `$a`, `$b`, and `$c`;
2. a second parameter whose `$a` use is only an argument to unread `$helper` parameter `0`;
3. a computed local carrying `$helper`'s independent result into `$b`;
4. two external calls so Binaryen's unprofitable-single-caller cutoff does not stop the reduced chain early.

Binaryen v130 `--dae-optimizing` reduces `$helper`, `$a`, `$b`, and `$c` from two parameters to one. Current Starshine leaves all four at two parameters, so the new regression is intentionally red before implementation.

## Retained first implementation slice

The first bounded implementation follows the already selected exact forwarded-cycle neighborhood, finds outside callees receiving exact caller-parameter `local.get` operands in unread positions, and removes those sink parameters through the existing owned/private/count-checked transactional callsite/callee rewrite. Candidate facts and current call facts are refreshed in bounded rounds; the same unread rewrite is then retried on the cycle definitions.

On the reduced fixture this closes the whole helper-then-cycle family. On the current artifact it safely removes the unread middle parameters from defined Funcs `7014` and `7033`, preserves valid output, and improves the prior endpoint:

| dimension | note 1604 | dead-callee sink slice | delta |
|---|---:|---:|---:|
| raw wasm | `3197404` | `3197391` | `-13` |
| canonical wasm | `3274861` | `3274829` | `-32` |
| DAEO pass-local | `13702.810ms` | `14299.444ms` | `+596.634ms` |

Against the unchanged Binaryen v130 `8538.02ms` baseline, the retained pass-local ratio is `1.67x`, within the required `<=2x` bound. The retained output SHA-256 is `0e18885eaa3d8ca1d5f665911d76570805f772055c0996d37c9087ab812547ae`; a repeat invocation is byte-identical.

The trace is:

```text
pass[dae-optimizing]:forwarded-param-dead-callee-convergence sink_defs=[7014, 7033] cycle_defs=[]
```

The empty `cycle_defs` is significant. Defined Func `7024` still reads its `i32` parameter only to forward it into defined Func `7008`; Func `7007` forwards the corresponding parameter into Func `7024`, while the existing Func `7007` / `7008` / `7010` neighborhood contains the computed local injection. No individual remaining parameter is unread yet. The next slice therefore needs a transactional forwarding-only parameter-component proof, not another constant proof and not an assumption about the computed local value.

Do not replace computed locals with constants, assume recursive values equal an external anchor, or widen to unrelated reachable definitions.
