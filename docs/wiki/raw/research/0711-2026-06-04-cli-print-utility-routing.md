# CLI print utility routing

- Date: 2026-06-04
- Target living page: [`docs/wiki/tooling/cli-command-and-dispatcher.md`](../../tooling/cli-command-and-dispatcher.md)
- Reason: the CLI dispatcher page had a one-row mention of `print-*` utility steps, but did not teach selector parsing, supported item kinds, name-source differences, stderr log shape, or how print checkpoints interact with pass segments.

## Sources checked

Primary / upstream orientation:

- Binaryen README on `main`: <https://github.com/WebAssembly/binaryen/blob/main/README.md>
  - Current README still frames Binaryen as a wasm-to-wasm optimizer that loads WebAssembly, optimizes it, and re-emits it. This remains only orientation for Starshine; it does not define Starshine's debug item selectors.
- Binaryen `src/tools/wasm-opt.cpp` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/tools/wasm-opt.cpp>
  - Current source still has a print-oriented path (`print` / `print-function-map`) that can write to stdout instead of ordinary output, and still treats command options and pass names as an ordered CLI surface. Starshine's `--print-{kind}` steps are more structured and stderr-oriented, so Binaryen should not be cited as exact selector semantics.

Local Starshine source:

- [`src/cli/cli.mbt`](../../../../src/cli/cli.mbt)
- [`src/cli/cli_test.mbt`](../../../../src/cli/cli_test.mbt)
- [`src/cmd/cmd.mbt`](../../../../src/cmd/cmd.mbt)
- [`src/cmd/cmd_wbtest.mbt`](../../../../src/cmd/cmd_wbtest.mbt)
- [`docs/wiki/tooling/cli-command-and-dispatcher.md`](../../tooling/cli-command-and-dispatcher.md)
- [`docs/wiki/binary/custom-and-name-sections.md`](../../binary/custom-and-name-sections.md)
- [`docs/wiki/validate/import-export-and-external-type-matching.md`](../../validate/import-export-and-external-type-matching.md)

## Findings

- `src/cli/cli.mbt` accepts any long flag whose name starts with `print-` and requires a non-empty inline or following selector. It normalizes the pass-queue entry as `print-<kind>=<selector>`. Parser coverage in `src/cli/cli_test.mbt` covers `--print-func main`, `--print-type=(0)`, and `--print-elem elist`.
- The dispatcher, not the parser, owns the supported kind allowlist. `cmd_is_supported_print_kind(...)` currently accepts exactly `type`, `func`, `import`, `table`, `memory`, `global`, `export`, `tag`, `elem`, and `data`. Unsupported `--print-foo` reaches `CmdError::unknown_pass_flag("print-foo")`.
- Selectors are parsed after queue resolution. Decimal text like `71` and parenthesized decimal text like `(71)` both resolve as an index. Anything else resolves as a name selector.
- Type/function/table/memory/global/tag/element/data name selectors come from the structured `NameSec` maps, not from source `$` identifiers unless those names survived lowering into structured metadata. Missing name maps mean index selectors still work while name selectors fail.
- Import selectors use import field names with a useful module-qualified disambiguator: `field` selects the first matching field name, while `module.field` selects an exact module/field pair. Export selectors use the public export name string. Those are real import/export payloads, not `NameSec` maps.
- Function printing counts imported functions plus locally defined functions so absolute `FuncIdx` selectors align with the validator/imported-prefix model. Imported function pretty-printing depends on `Module::pretty_print_func(...)`; the page should not overpromise full body text for imports.
- Each print step flushes pending optimizer passes before resolving the item, logs to stderr, and does not mutate the module. The first print for an input emits a `Log: <input>` header, each print increments an entry number, labels use `Kind[index name]` when a name is available, and the body is indented. `cmd_wbtest.mbt` locks ordered `Type[0]`, `Func[0]`, and `Elem[0]` entries around an intervening pass.
- Print failures are optimizer-stage failures, not parser failures, once the flag has a non-empty selector: missing item/name/index produces `OptimizeFailed("print <kind>: no item matched selector ...")`, while stderr-write failure produces `OutputWriteFailed("stderr print log ...")`.

## Follow-up

If a new printable item kind lands, update all four layers together: CLI help, `cmd_is_supported_print_kind(...)`, `cmd_resolve_pipeline_print_entry(...)`, and this dispatcher page. If selector syntax changes, update `src/cli/cli_test.mbt`, the command-level print log test, and the name-section/import-export pages that describe the source of names.
