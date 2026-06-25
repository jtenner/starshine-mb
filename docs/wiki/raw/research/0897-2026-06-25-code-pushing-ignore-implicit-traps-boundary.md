# 0897 - code-pushing ignore-implicit-traps boundary

Date: 2026-06-25

Superseded for implementation status by [`0902-2026-06-25-code-pushing-ignore-implicit-traps-implementation.md`](0902-2026-06-25-code-pushing-ignore-implicit-traps-implementation.md). This note remains historical evidence for the prior accepted boundary and its reopening criteria.

## Question

Can Starshine close `[CP-BINREP-003]` by matching or explicitly resolving the Binaryen v130 `code-pushing_ignore-implicit-traps.wast` surface without silently conflating it with `--traps-never-happen`?

## Answer

Yes, as a narrow accepted boundary for the current Starshine public surface. Binaryen v130 exposes a distinct `--ignore-implicit-traps` / `-iit` option, and the official lit file `test/lit/passes/code-pushing_ignore-implicit-traps.wast` runs `wasm-opt --code-pushing --ignore-implicit-traps`. Starshine currently exposes only `--trap-mode <allow|never>`, `--traps-never-happen`, and `--traps-may-happen`; repo grep found no `ignore_implicit_traps` / `--ignore-implicit-traps` plumbing in CLI, pass options, `HotPassContext`, or `code-pushing`.

This slice therefore resolves `[CP-BINREP-003]` as **not implemented / not a current Starshine flag mapping**, not as behavior parity. The important unresolved Binaryen-positive family is the lit `value-might-interfere` memory-load movement: under `--ignore-implicit-traps`, Binaryen can move an `i32.load`-backed local set past a `br_if` when there is no intervening memory write, while keeping `value-interferes` and accumulation variants stationary when a store intervenes. Starshine's current `code-pushing` movable-value gate does not admit ordinary memory loads, and its existing `traps_never_happen` relaxation is intentionally limited to exact integer div/rem nodes from `[CP-BINREP-002]`.

Do not treat `--traps-never-happen` as a semantic replacement for `--ignore-implicit-traps`: TNH is already wired and stronger/different in Starshine's current model, while Binaryen keeps a separate option surface. Reopen this boundary if Starshine adds a distinct implicit-trap policy, maps Binaryen `-iit` for replacement compatibility, or a generated/direct compare lane starts using `--ignore-implicit-traps` as part of the oracle contract.

## Source-backed lit surface

Local source file: `.tmp/binaryen-lit/code-pushing_ignore-implicit-traps.wast`, fetched from Binaryen `version_130`.

The named shapes split into three groups:

1. Already-covered ordinary code-pushing movement shapes, such as `push-if`, `push-dropped`, and several pure-set `br_if` push cases. These are not evidence that Starshine implements `--ignore-implicit-traps`; they overlap with existing default code-pushing families.
2. The option-specific load shape:
   - `value-might-interfere ;; but doesn't`: Binaryen moves `local.set $x (i32.load (i32.const 0))` after a `br_if` when no memory write intervenes.
   - `value-interferes` and `value-interferes-accumulation`: Binaryen keeps the load before an intervening `i32.store` and later `br_if`.
   - `value-interferes-in-pushpoint`: Binaryen keeps the load before an `if` push point whose body calls an effectful function.
3. Side-effect / unpushed-local boundaries:
   - `values-might-interfere`, `unpushed-interferes`, `unpushed-side-effect-into-drop`, and `unpushed-side-effect-into-if` keep call-valued local sets stationary.
   - `unpushed-ignorable` and `unpushed-ignorable-side-effect` show that an unpushed earlier local need not block a later independent pure local when order/effects allow it.

## Starshine status

Current Starshine plumbing:

- CLI/config: `src/cli/cli.mbt` and `src/cmd/cmd.mbt` support `--trap-mode <allow|never>`, `--traps-never-happen`, and `--traps-may-happen` only.
- Hot pass context: `src/passes/pass_manager.mbt` exposes `HotPassContext.traps_never_happen` only.
- Code-pushing trap relaxation: `src/passes/code_pushing.mbt` uses `ctx.traps_never_happen` to admit exact integer div/rem nodes; it does not admit ordinary `i32.load` as a movable value under a separate implicit-trap policy.
- Command probe: `_build/native/release/build/cmd/cmd.exe --ignore-implicit-traps --code-pushing --format wat .tmp/binaryen-lit/code-pushing_ignore-implicit-traps.wast` exits with `error: unknown pass flag: ignore-implicit-traps` in this checkout. The same probe also reports local `wat2wasm` absence before the pass error, so it is command-surface evidence only, not a WAT execution lane.

## Decision

Mark `[CP-BINREP-003]` complete as an explicitly documented accepted boundary/non-goal for the current replacement follow-up. No behavior change landed in this slice, so no red/green TDD test was added. The boundary is narrow:

- Starshine does not currently expose or emulate Binaryen `--ignore-implicit-traps`.
- Starshine does not claim the `value-might-interfere` memory-load movement.
- Existing TNH support from `0895` must not be cited as closing the Binaryen `-iit` surface.

Reopening criteria:

- add a distinct `ignore_implicit_traps` option to CLI/config/hot-pass context;
- accept Binaryen CLI replacement compatibility for `--ignore-implicit-traps` / `-iit`;
- implement memory-load movement under an explicit implicit-trap policy with focused red-first tests for `value-might-interfere`, `value-interferes`, `value-interferes-accumulation`, and `value-interferes-in-pushpoint`;
- discover a generated mismatch where the agreed direct-pass oracle includes implicit-trap relaxation.

## Validation

Docs/status slice only. Evidence commands:

```sh
wasm-opt --version
wasm-opt --help | grep -n "implicit\|trap" | head -20
grep -R "ignore_implicit\|ignore-implicit" src
_build/native/release/build/cmd/cmd.exe --ignore-implicit-traps --code-pushing --format wat .tmp/binaryen-lit/code-pushing_ignore-implicit-traps.wast
```

Results:

- local Binaryen oracle is `wasm-opt version 130 (version_130)`;
- Binaryen help lists `--ignore-implicit-traps,-iit` separately from `--traps-never-happen,-tnh`;
- Starshine source grep found no `ignore_implicit` / `--ignore-implicit-traps` plumbing;
- Starshine command probe reports `error: unknown pass flag: ignore-implicit-traps`.
