# 0902 - code-pushing ignore-implicit-traps implementation

Date: 2026-06-25

## Question

Can Starshine implement Binaryen v130 `--ignore-implicit-traps` / `-iit` for `code-pushing` as a distinct option, without conflating it with `--traps-never-happen`?

## Answer

Yes. Starshine now exposes a separate `ignore_implicit_traps` option through CLI parsing, config/env merge, command optimize options, hot pipeline options, and `HotPassContext`. This is distinct from `traps_never_happen`: TNH still gates exact integer div/rem trap relaxation, while `ignore_implicit_traps` only admits ordinary memory loads for the source-backed `code-pushing_ignore-implicit-traps.wast` load movement family.

The previous boundary note [`0897`](0897-2026-06-25-code-pushing-ignore-implicit-traps-boundary.md) remains valid historical evidence for the old missing surface but is superseded for implementation status by this note. The replacement-follow-up closeout [`0901`](0901-2026-06-25-code-pushing-binrep-followup-closeout.md) remains valid for the old `[O4Z-AUDIT-CP-BINREP]` stop condition; this slice is a new widening after that closeout, not a silent rewrite of it.

## Behavior implemented

Public option surface:

- `--ignore-implicit-traps` and Binaryen-compatible `-iit` parse as optimization options, not pass names.
- `CliParseResult.ignore_implicit_traps`, `resolve_ignore_implicit_traps(...)`, `OptimizeOptions.ignore_implicit_traps`, `HotPipelineOptions.ignore_implicit_traps`, and `HotPassContext.ignore_implicit_traps` carry the policy to hot passes.
- Config accepts `options.ignoreImplicitTraps` / `options.ignore-implicit-traps`; environment overlay accepts `STARSHINE_IGNORE_IMPLICIT_TRAPS`.
- Help text lists `--ignore-implicit-traps, -iit` separately from `--traps-never-happen`.

`code-pushing` behavior:

- Default trap semantics keep `local.set $x (i32.load ...)` before a later `br_if` push point.
- With `ignore_implicit_traps=true`, `code-pushing` may move a memory-load-backed SFA `local.set` after a later eligible `br_if` when all local reads are suffix reads and intervening effects are safe.
- Intervening memory writes remain barriers, including `nop` accumulation before a store.
- An effectful `if` push point with a call in the arm remains stationary.
- TNH and `ignore_implicit_traps` remain separate: the new flag does not enable TNH exact div/rem behavior, and TNH does not stand in as the Binaryen `-iit` surface.

## Tests and validation

Red-first failures before implementation:

```sh
moon test --target native src/cli src/passes/code_pushing_test.mbt --filter '*ignore-implicit-traps*|*implicit traps*|*memory load*'
```

failed because `CliParseResult` lacked `ignore_implicit_traps` and `HotPassContext::new` lacked an `ignore_implicit_traps` parameter.

Final focused validation:

```sh
moon fmt
moon info
moon test --target native src/cli
moon test --target native src/passes/code_pushing_test.mbt
moon test --target native src/cmd --filter '*ignore*'
moon build --target native --release src/cmd
_build/native/release/build/cmd/cmd.exe --help | grep -n "ignore-implicit-traps"
bun scripts/pass-fuzz-compare.ts --count 200 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-iit-smoke-200 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Results:

- `moon fmt` passed.
- `moon info` passed with pre-existing warnings in `src/validate`.
- `src/cli` passed `63/63`.
- focused `code_pushing_test.mbt` passed `131/131`.
- focused `src/cmd --filter '*ignore*'` passed `2/2`.
- native release `src/cmd` build passed with pre-existing warnings.
- help output included `--ignore-implicit-traps, -iit`.
- bounded dedicated compare smoke `.tmp/pass-fuzz-code-pushing-iit-smoke-200` compared `200/200`: `101` normalized, `99` compare-normalized via `local-cleanup-debris`, `0` mismatches, `0` validation/property/generator/command failures.

A full four-lane direct-pass matrix was not rerun because this is a narrow option/behavior widening with focused lit-derived coverage plus bounded `code-pushing-all` smoke. Reopen for a broader lane if future `-iit` work admits more effect families, generated mismatches appear, or preset scheduling starts using `ignore_implicit_traps` in public optimize paths.
