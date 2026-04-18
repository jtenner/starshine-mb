# 0106 - Generated `-O4z` slot 23 `vacuum` replay retired after the earlier `Func 652` carrier-wrapper guard

## Status

- Date: 2026-04-18
- Type: One-off raw investigation
- Resolves: [0097 - slot 23 `vacuum` `Func 652` stack underflow](./0097-2026-04-18-generated-o4z-vacuum-slot23-func652-stack-underflow.md)
- Related earlier fix: [0103 - slot 16 `optimize-instructions` `Func 652` carrier-wrapper guard follow-up](./0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md)
- Shared audit summary: [0093 - generated ordered `-O4z` audit](./0093-2026-04-18-generated-o4z-pass-audit-summary.md)

## Scope

- Selected backlog item: `[O4Z]004`
- Replay input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/17-slot21-tuple-optimization/binaryen.wasm`
- Pass under test: `--vacuum`
- Focused regression: `src/cmd/cmd_wbtest.mbt`

## Binaryen / oracle behavior

Authoritative Binaryen intent for this pass is still simple cleanup, not structural result-carrier invention:

- Binaryen source oracle: `src/passes/Vacuum.cpp` in the upstream `version_129` tag - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Vacuum.cpp>
- Newer upstream drift note: the 2026-02-27 Chromium-mirror change stopped rewriting explicit `unreachable` to `nop`, so current trunk still treats `Vacuum` as a cleanup pass, not as a place to synthesize new typed payload carriers - <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/9ee4a25ee15ab53e796cb0b3f320cafa2622c407%5E%21/>
- Local oracle replay:
  - `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/17-slot21-tuple-optimization/binaryen.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .artifacts/o4z004-slot23-compare --vacuum`

Observed oracle result on the current tree:

- Binaryen's `vacuum` replay on the saved slot-23 predecessor is valid.
- Starshine's current replay is also valid and the compare harness reports:
  - `Normalized WAT equal: yes`
  - `Canonical function compare equal: yes`
- Canonical wasm bytes still differ, so this retirement is about fixing the corruption, not achieving byte-for-byte identity.

## Earlier failure state

[0097](./0097-2026-04-18-generated-o4z-vacuum-slot23-func652-stack-underflow.md) captured the pre-fix symptom:

- direct `--vacuum` replay exited nonzero
- final validation failed with `stack underflow`
- offending function was `(Func 652)`

At the time, that looked plausibly shared with the nearby slot-16 `optimize-instructions` failure because both crashed in the same function family.

## Current verification

### Direct replay

- `_build/native/release/build/cmd/cmd.exe --vacuum --out .artifacts/o4z004-slot23-fixed.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/17-slot21-tuple-optimization/binaryen.wasm`
- `wasm-tools validate .artifacts/o4z004-slot23-fixed.wasm`

Observed result:

- exit code `0`
- emitted wasm validates successfully

### Extracted offender replay

- `_build/native/release/build/cmd/cmd.exe --extract-functions=652 --vacuum --out .artifacts/o4z004-slot23-f652-fixed.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/17-slot21-tuple-optimization/binaryen.wasm`
- `wasm-tools validate .artifacts/o4z004-slot23-f652-fixed.wasm`

Observed result:

- the isolated `Func 652` replay now also exits `0`
- the extracted output validates successfully

### Compare harness

- `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/17-slot21-tuple-optimization/binaryen.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .artifacts/o4z004-slot23-compare --vacuum`

Observed result:

- `Normalized WAT equal: yes`
- `Canonical function compare equal: yes`

## Root-cause conclusion

Inference from the current evidence:

- `[O4Z]004` was **not** a `vacuum`-specific mutation bug.
- The slot-23 corruption retired as fallout from the earlier HOT-lower guard in [0103](./0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md), which stopped `hot_lower_impl_stackify_wrapped_struct_set_prefixes(...)` from inserting a typed `block (result i32)` when child exits still targeted the parent label.
- That inference is supported by three facts taken together:
  1. [0103](./0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md) already identified the exact `Func 652` failure family as a HOT-lower carrier-wrapper bug rather than an `optimize-instructions` peephole bug.
  2. `vacuum` itself still only removes `nop` roots and region entries in Starshine (`src/passes/pass_manager.mbt`), so it has no pass-local rewrite that would intentionally create a new typed payload carrier.
  3. The saved slot-23 `vacuum` replay is now green on the current tree without any dedicated `vacuum` algorithm change in this slice.

So the durable fix story is: slot 23 looked like a `vacuum` corruption because `vacuum` was the pass being replayed when final lowering happened, but the invalid shape was already the same HOT-lower `Func 652` carrier-wrapper family retired by [0103](./0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md).

## Durable takeaways

- When an ordered-prefix corruption disappears after a lower/writeback fix and no pass-local logic changed, treat the pass label on the failing slot as the replay boundary, not automatically as the root cause.
- Slot `23` should no longer be counted among the active `vacuum` blockers.
- The remaining ordered `vacuum` blocker is the later slot `33` `Func 1818` replay from [0098](./0098-2026-04-18-generated-o4z-vacuum-slot33-func1818-stack-underflow.md).

## Files changed in this slice

- `src/cmd/cmd_wbtest.mbt`
- `agent-todo.md`
- `CHANGELOG.md`
- `docs/wiki/binaryen/passes/vacuum/index.md`
- `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Supporting evidence

- Saved audit input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/17-slot21-tuple-optimization/binaryen.wasm`
- Saved compare output: `.artifacts/o4z004-slot23-compare/`
- Fixed full-slot output: `.artifacts/o4z004-slot23-fixed.wasm`
- Fixed extracted replay output: `.artifacts/o4z004-slot23-f652-fixed.wasm`
