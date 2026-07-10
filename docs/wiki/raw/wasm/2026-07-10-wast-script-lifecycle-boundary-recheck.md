# WAST Script Lifecycle Boundary Recheck

- Capture date: 2026-07-10
- Source family: official WebAssembly/spec reference-interpreter script model and current upstream core test corpus, reconciled with Starshine's WAST parser and static harness
- Status: immutable primary-source bridge. This supplements the 2026-05-19, 2026-05-20, and 2026-06-04 static-harness captures by recording a concrete script-grammar boundary that materially affects spec-runner skip counts.

## Primary sources checked

1. WebAssembly/spec reference interpreter, current `main`, checked 2026-07-10: <https://github.com/WebAssembly/spec/tree/main/interpreter>
2. WebAssembly/spec current core `instance.wast`, checked 2026-07-10: <https://github.com/WebAssembly/spec/blob/main/test/core/instance.wast>
3. WebAssembly/spec current core `memory.wast` and `table.wast`, checked 2026-07-10: <https://github.com/WebAssembly/spec/tree/main/test/core>
4. Current vendored upstream mirror: [`../../../../tests/spec/instance.wast`](../../../../tests/spec/instance.wast), [`../../../../tests/spec/memory.wast`](../../../../tests/spec/memory.wast), and [`../../../../tests/spec/table.wast`](../../../../tests/spec/table.wast)
5. Current Starshine parser/harness evidence: [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt), [`../../../../src/wast/spec_harness.mbt`](../../../../src/wast/spec_harness.mbt), and [`../../../../src/spec_runner/spec_runner.mbt`](../../../../src/spec_runner/spec_runner.mbt)

## Durable takeaways

- Official WAST test scripts are broader than a stream of ordinary `(module ...)` commands. The upstream corpus uses **module definitions** such as `(module definition $M ...)` and **module instances** such as `(module instance $I $M)` to express generative instantiation and reusable module definitions. The current upstream `instance.wast` is a concrete example; `memory.wast` and `table.wast` also use `(module definition ...)` for boundary-size module declarations.
- Starshine's `WastCommand` surface is intentionally smaller today: `src/wast/parser.mbt` dispatches only ordinary `module` forms, `register`, `invoke`/`get`, and the listed assertion commands. `parse_module_command(...)` accepts an optional `$id`, then `binary`, `quote`, or ordinary parenthesized module fields. It has no `definition`/`instance` command variants or parser branches.
- Consequently, an official script containing `module definition` or `module instance` fails before command-level static evaluation. `run_wast_spec_file(...)` classifies that outer script-parse failure as `Skipped(...)` through `spec_is_known_unsupported_error(...)`; it is not a passed module-validation result, a successful instantiation, or evidence that the script's later assertions ran.
- This boundary is different from the existing runtime-only-command policy. `register`, `invoke`, and runtime assertions are parsed and skipped **per command**, so a mixed script can still check later static assertions. Unsupported lifecycle grammar prevents construction of the script AST itself and therefore yields a whole-file skip.
- A future lifecycle implementation requires more than parser keywords: it needs a separate representation for definitions and instances, a definition environment, instantiation semantics, import matching, registration state, and an execution/linking policy. It should not be described as a small extension to `ValidBeforeLink`.

## Starshine interpretation rules

1. Treat `Passed` from the current static harness as evidence only for the commands that reached `spec_check_command(...)`; retain `checked_commands` and `skipped_commands` when reporting a file.
2. Treat `Skipped(...)` caused by `module definition` or `module instance` as a WAST script-lifecycle grammar/support gap. Do not collapse it into a runtime-only skip or into Core module validation failure.
3. Use ordinary extracted `(module ...)` fixtures for current parser/lowerer/validator coverage when that is the actual target. Do not claim that extraction provides evidence for the upstream definition/instance lifecycle.
4. Before implementing lifecycle forms, design the linker/instantiator together with the existing `assert_unlinkable` boundary and [`../../validate/import-export-and-external-type-matching.md`](../../validate/import-export-and-external-type-matching.md). The local static `ValidBeforeLink` result remains useful for validator fuzzing but does not establish instance creation.

## Supersession and uncertainty

- This note does not change the existing static assertion stage contract or the deliberate broad local `assert_malformed` policy.
- The vendored corpus is treated as a local mirror and replay source; the official `WebAssembly/spec` URLs remain the upstream authority. If a mirror update changes the observed lifecycle forms, recheck the upstream file before revising this boundary.
- The precise parser diagnostic text is intentionally not a durable contract. The durable fact is structural: no `WastCommand` representation or parser branch accepts `module definition` / `module instance` today.
