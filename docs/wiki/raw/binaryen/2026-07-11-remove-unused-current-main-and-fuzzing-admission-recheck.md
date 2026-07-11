# Binaryen `remove-unused` current-main and fuzzing-admission recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source and local-admission freshness manifest for `docs/wiki/binaryen/passes/remove-unused/`

## Scope

This recheck answers two narrow maintenance questions about Starshine's boundary-only `remove-unused` name:

1. Does Binaryen current `main` expose either `remove-unused` or the historical `remove-unused-functions` spelling?
2. Is `remove-unused` currently an executable Starshine `compare-pass` lane?

It does **not** reopen the historical algorithm or claim that the local short name is a proven intentional alias. The older 2026-06-02 release-horizon capture remains the `version_130` baseline; this document is a current-main and local-admission refresh.

## Primary and repository sources reread

### Upstream Binaryen `main`

- Public pass registration and default scheduling: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Public CLI help expectation: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/help/wasm-opt.test>
- Current successor owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedModuleElements.cpp>

### Current Starshine evidence

- Boundary-only registry name and active successor entries: `src/passes/optimize.mbt`
- Module-pass dispatcher: `src/passes/pass_manager.mbt`
- Compare-pass admission list and rejection path: `scripts/lib/pass-fuzz-compare-task.ts`
- Existing alias dossier: `docs/wiki/binaryen/passes/remove-unused/`

## Findings

### Current upstream spelling

The reviewed Binaryen `main` registration and help surfaces continue to expose the modern module-element family, including `remove-unused-module-elements` and `remove-unused-nonfunction-module-elements`. They do **not** expose a public `remove-unused` or `remove-unused-functions` pass spelling on the reviewed surfaces.

That confirms, but does not broaden, the existing historical-lineage conclusion: local `remove-unused` remains a Starshine registry-alias question rather than a current upstream pass-port target.

### Current local admission

Starshine's `pass_registry_boundary_only_names()` still contains `remove-unused`. Active registry entries and the module dispatcher instead use `remove-unused-module-elements` and `remove-unused-nonfunction-module-elements`.

The pass-fuzz harness likewise does **not** include `--remove-unused` in `SUPPORTED_PASS_FLAGS`; its pass-name normalization rejects unsupported flags before generation or either optimizer runs. Therefore:

- `bun fuzz compare-pass --pass remove-unused ...` is **not** a runnable parity lane;
- a rejection, a build with zero comparisons, or a requested count of 10,000 is only admission-status evidence;
- it is not Binaryen transform, validation, performance, or semantic-parity evidence.

## Documentation consequence

The old `remove-unused/fuzzing.md` command was stale because it advertised an executable 10,000-case lane for a boundary-only alias absent from the harness allowlist. The corrected page must mark fuzzing **planned-only**, distinguish safe roster inspection from a compare run, and require explicit implementation, harness mapping, historical-or-alias oracle choice, fixtures, and a meaningful comparison threshold before publishing a runnable command.

## Caveats

- This is an absence claim limited to the reviewed current-main registration/help surfaces; it is not a complete search of every historical Binaryen branch.
- Current Binaryen `remove-unused-module-elements` is a broader successor, not automatic proof that a local `remove-unused` alias should dispatch to it.
- The registry-alias relationship remains an inference documented in the living dossier, not a source-proven local rename decision.
