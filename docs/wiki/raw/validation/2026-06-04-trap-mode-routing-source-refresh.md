---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-06-04
sources:
  - https://webassembly.github.io/spec/core/exec/runtime.html#syntax-trap
  - https://webassembly.github.io/spec/core/exec/instructions.html
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizationOptions.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/pass.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h
  - ../../../../src/cli/cli.mbt
  - ../../../../src/cli/cli_test.mbt
  - ../../../../src/cmd/cmd.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/ir/hot_flags.mbt
  - ../../../../src/ir/effects.mbt
related:
  - ../../validate/runtime-trap-semantics.md
  - ../../tooling/cli-command-and-dispatcher.md
  - ../../binaryen/passes/vacuum/effect-pruning-and-traps-never-happen.md
  - ../../binaryen/passes/optimize-instructions/gc-casts-call_ref-and-trap-sensitive-rewrites.md
---

# Trap Mode Routing Source Refresh

- Capture date: 2026-06-04
- Source family: WebAssembly trap semantics, Binaryen trap-assumption option plumbing, and current Starshine CLI/config/optimizer routing for `--trap-mode` / `--traps-never-happen`.
- Extends: [`2026-06-04-runtime-trap-current-refresh.md`](../wasm/2026-06-04-runtime-trap-current-refresh.md) with the narrower command-routing and Binaryen-oracle distinction. The runtime-trap refresh remains the source for Core execution, JavaScript `RuntimeError`, and static WAST harness boundaries.

## Primary sources checked

- WebAssembly Core Specification, `Execution / Runtime Structure` — trap is a runtime result distinct from static validation failure: <https://webassembly.github.io/spec/core/exec/runtime.html#syntax-trap>
- WebAssembly Core Specification, `Execution / Instructions` — `unreachable` executes to `trap`: <https://webassembly.github.io/spec/core/exec/instructions.html>
- Binaryen `OptimizationOptions.h` — the upstream optimizer option set carries a `trapsNeverHappen` boolean for passes that deliberately assume trap paths do not occur: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizationOptions.h>
- Binaryen `pass.h` / `ir/effects.h` — upstream pass options and effect analysis distinguish trap-sensitive movement/removal from ordinary validation; some Binaryen passes consult `trapsNeverHappen` or adjacent implicit-trap options when proving rewrites: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>, <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>

## Repository evidence checked

- [`../../../../src/cli/cli.mbt`](../../../../src/cli/cli.mbt) defines `TrapMode::allow()` / `TrapMode::never()`, parses `--trap-mode <allow|never>`, accepts the longer values `traps-may-happen` / `traps-never-happen`, and treats `--traps-never-happen` / `--traps-may-happen` as aliases. These flags are not appended to `pass_flags`.
- [`../../../../src/cli/cli_test.mbt`](../../../../src/cli/cli_test.mbt) locks mixed-case trap-mode values, rejects missing/invalid trap-mode values, proves trap-mode toggles are omitted from the scheduled pass list, and confirms the last trap-mode flag wins.
- [`../../../../src/cmd/cmd.mbt`](../../../../src/cmd/cmd.mbt) merges trap mode with CLI > environment > config precedence, stores `traps_never_happen` in `OptimizeOptions`, records it in `CmdRunSummary`, includes it in trace option lines, and adds `--traps-never-happen` to post-encode repro hints when set.
- [`../../../../src/cmd/cmd_wbtest.mbt`](../../../../src/cmd/cmd_wbtest.mbt) covers config/env/CLI trap-mode precedence and JSON config spellings such as `options.trapsNeverHappen`.
- [`../../../../src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt) owns pass registry and preset expansion, but this source check found no current pass-registry or pass-implementation consumption of `OptimizeOptions.traps_never_happen` beyond command-level routing. Current hot passes still rely on conservative `HOT_FLAG_MAY_TRAP` / `EFFECT_MASK_TRAP` evidence unless their own dossier documents a narrower exception.
- [`../../../../src/ir/hot_flags.mbt`](../../../../src/ir/hot_flags.mbt) and [`../../../../src/ir/effects.mbt`](../../../../src/ir/effects.mbt) remain the local trap-sensitivity facts passes use today.

## Durable takeaways

- In Binaryen, `traps-never-happen` is a real optimization assumption that selected passes can use to relax trap-preservation constraints. A Binaryen-oracle mismatch involving TNH must be classified under the pass-specific Binaryen contract, not as ordinary Core validation behavior.
- In current Starshine, `--trap-mode never`, `--traps-never-happen`, config `trapMode: "never"`, and config `trapsNeverHappen: true` are accepted command/config vocabulary and are preserved in summaries/repro hints, but they are not a scheduled pass and do not currently activate pass-local TNH rewrites by themselves.
- The default local semantic assumption remains traps-may-happen / trap-preserving unless a specific pass page proves otherwise. Do not cite the mere presence of `OptimizeOptions.traps_never_happen` as evidence that a Starshine pass implements Binaryen TNH behavior.
- If a future Starshine pass starts consuming `traps_never_happen`, update the pass dossier, `validate/runtime-trap-semantics.md`, `tooling/cli-command-and-dispatcher.md`, compare-pass classification guidance, command tests, and this source bridge together.

## Open cautions

- This was a source/wiki alignment pass, not a new oracle or runtime validation run.
- The source check was repository-wide but docs should still cite exact owner files rather than relying on a transient grep result.
- Some Binaryen pass dossiers already teach upstream TNH behavior for that pass. Those pages remain valid as Binaryen strategy references; they should not be read as local Starshine parity claims unless their Starshine strategy page says the option is implemented locally.
