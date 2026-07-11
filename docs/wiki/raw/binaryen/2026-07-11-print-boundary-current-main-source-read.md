# Binaryen `print-boundary` Current-Main Source Read

Capture date: 2026-07-11

Purpose: record the previously untracked public Binaryen `print-boundary` pass, its current recursive-type safety repair, and Starshine's present non-implementation. This is a source reconciliation, not a Starshine behavior change.

## Primary Sources

- current `main` owner: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/PrintBoundary.cpp>
- `version_130` owner: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/PrintBoundary.cpp>
- current `main` pass registration: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `version_130` pass registration: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/pass.cpp>
- current `main` focused fixture: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/print-boundary.wast>
- `version_130` focused fixture: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/lit/passes/print-boundary.wast>
- upstream recursive-type repair PR: <https://github.com/WebAssembly/binaryen/pull/8786>

## Findings

- `print-boundary` is a public Binaryen pass registered through `createPrintBoundaryPass()`; it is an observation/debugging pass, not an optimizer or feature lowering.
- The owner emits one JSON object with exactly two arrays: `imports` and `exports`. `imports` iterates Binaryen's importable external kinds; `exports` iterates module exports. The pass does not alter the module.
- Each import record has `module`, `base`, `kind`, and `type`; each export record has `name`, `kind`, and `type`. `kind` is one of `func`, `table`, `memory`, `global`, or `tag`. A function or tag `type` is a `{ "params": [...], "results": [...] }` object; scalar table/memory/global types are strings, and multi-value types remain arrays.
- The current focused fixture establishes that import/export protocol across function, memory, table, tag, and global boundaries. It is an output-format test, not a semantic transform fixture.
- Current `main` adds a recursion-depth guard while formatting signature reference types. PR #8786 identifies the reason: recursive type groups could otherwise recurse indefinitely. The fixture now covers a recursive function-type reference and expects the nested reference to be printed as a terminal type string. This is behavior-bearing diagnostic-safety drift from `version_130`, not a WebAssembly semantic change.
- The pass writes pretty JSON to the optional `--print-boundary=OUTFILE` target, or stdout when no target is supplied. Consumers should parse JSON rather than scrape presentation text.

## Starshine Reconciliation

Focused local searches on 2026-07-11 found no `print-boundary`, `PrintBoundary`, or `createPrintBoundaryPass` spelling under `src/`, and no `--print-boundary` admission in `scripts/lib/pass-fuzz-compare-task.ts`.

Starshine can already represent and print many of the observed module surfaces (`ImportSec`, `ExportSec`, type/table/memory/global sections, and WAT output), but this is prerequisite inspection infrastructure, not an implementation of Binaryen's JSON boundary protocol. The correct local status is **upstream-only / local-unknown**.

## Consequences

- Do not put `print-boundary` into optimization presets: it is reporting-only and produces observable stdout.
- Do not treat a normal `compare-pass` canonical-Wasm comparison as the right oracle. A future port needs JSON snapshots for import/export records, including recursive signature-reference termination, plus a no-mutation byte/validation check.
- Keep this pass distinct from `print`, `--print-full`, WAT round-tripping, or Starshine CLI inspection commands. Similar human-readable output does not prove the same machine-readable import/export protocol.
