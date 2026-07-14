# DAEO broad removed-param local compaction

Date: 2026-07-13

## Scope

This bounded slice starts from the remaining direct Func `41` parity gap recorded in note `1593`. It does not accept the residual as representation drift. The source-backed owner is Binaryen DAEO's optimizing-only nested cleanup after parameter removal: Starshine removed Func `41`'s third parameter but skipped the ordinary nested cleanup because the artifact touched `38` functions, leaving many now-unreferenced locals in the changed function.

## Red-first regression

`src/passes/dae_optimizing_test.mbt` now builds a broad `4097`-definition module with:

- more than eight DAE-touched functions, forcing the existing broad nested-cleanup guard;
- one `128`-local function whose unused parameter is removed;
- root local traffic that remains behaviorally live; and
- `96` declarations that become syntactically unreferenced.

The test failed first because both plain DAE and DAEO retained all `128` locals. It now proves that:

- plain `dead-argument-elimination` remains at `128` locals;
- optimizing DAEO retains the `32` referenced locals and removes only the `96` unreferenced locals;
- the selected output validates; and
- the optimizing-only trace identifies the ranked selected definition and measured removed-local count.

## Generic bounded selector

`src/passes/pass_manager.mbt` now checks only already-touched definitions when a module has more than `4096` defined functions. A candidate must:

1. have at least `128` declared locals;
2. have fewer parameters after DAEO than in the original module;
3. retain at least `16` removable unreferenced locals after the existing exact lowered cleanup; and
4. win the deterministic rank by removed-local count, then lower definition index.

Only the best candidate is rewritten. The implementation uses the existing recursive local-reference collector and bijective local remapper, so every retained local keeps its original type and every local reference is updated. No artifact function index is encoded in the selector.

## First fresh artifact measurement

Fresh native binary:

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 e7887d79de84dfe843d05edecb065d39f3955c44a68043feabddd1a804a13532
```

Direct output:

```text
.tmp/daeo-f41-local-compact-20260713/starshine-direct.wasm
```

The output validates with `wasm-tools validate --features all`. The selector reports:

```text
pass[dae-optimizing]:broad-removed-param-local-cleanup def=41 removed_locals=168
```

| dimension | note 1593 | this slice | delta |
|---|---:|---:|---:|
| raw wasm | `3198310` | `3197559` | `-751` |
| canonical wasm | `3275701` | `3275027` | `-674` |
| Func `41` canonical body | `7377` | `6703` | `-674` |
| Func `41` delta vs Binaryen | `+1960` | `+1286` | `-674` |
| DAEO pass-local | `11088.465ms` | `13662.779ms` | `+2574.314ms` |

Binaryen remains `8083.49ms`, so this first retained implementation is `1.69x` Binaryen and remains inside the required `<=2x` pass-local bound. The entire canonical improvement belongs to Func `41`; the `[7007,7008]`, `8429`, and `9347` bodies are byte-unchanged.

## Judgment and continuation

This is a measured direct Starshine size win relative to note `1593`, not direct parity and not a claim that the remaining Func `41 +1286` bytes are acceptable. The overall canonical artifact gap is now `+12571` (`3275027 - 3262456`).

The next slice should reduce selector overhead without changing output, then remeasure the `[7007,7008]` family or another leading direct owner. Final signoff still requires the fresh four-lane matrix, exact-once public scheduling replay, full tests/validation, docs/backlog updates, and explicit classification of every retained direct difference.
