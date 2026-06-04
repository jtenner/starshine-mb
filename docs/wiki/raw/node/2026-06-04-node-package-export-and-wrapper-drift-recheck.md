# Node Package Export And Wrapper Drift Recheck

Capture date: 2026-06-04

## External primary/high-quality sources

- Node.js v26.3.0 documentation, "Modules: Packages": <https://nodejs.org/api/packages.html>
  - Checked package `type`, `exports`, subpath exports, extension-style guidance, conditional-export history, and target path rules.
  - Durable takeaways: `"type": "module"` makes package-local `.js` files ES modules; defining `"exports"` encapsulates public package subpaths so unlisted subpaths fail package resolution; package authors should keep one stable public specifier style per subpath; export targets must be relative paths beginning with `./`.
  - Starshine relevance: `node/package.json` is intentionally ESM-first, uses extensionless exported subpaths (`.`, `./binary`, `./cli`, `./cmd`, `./lib`, `./validate`, `./wast`, and `./wat`), and does not make private files or omitted MoonBit packages public just because they exist under `node/` or `src/`.

- TypeScript Handbook, "Modules - Reference": <https://www.typescriptlang.org/docs/handbook/modules/reference>
  - Checked Node-aware package lookup, `package.json` `exports` handling, `types` / `default` conditional matching, the explicit-`types` condition example, and the `exports`-blocks-other-subpaths example.
  - Durable takeaways: in `node16`, `nodenext`, and `bundler` resolution modes, TypeScript follows Node's `exports` lookup for bare package package-directory resolution; TypeScript also matches `types` conditions when resolving declarations; the mere presence of `exports` blocks unmatched package-relative subpaths; the root `types` field remains useful package metadata even when per-subpath declarations exist.
  - Starshine relevance: each listed Starshine export needs both a runtime `import` target and a declaration `types` target, and wrapper-drift tests should start from the export allowlist instead of every checked-in file.

## Repository evidence checked

- `node/package.json`: ESM package, `main` / root `types`, explicit extensionless `exports` map with `types` plus `import` entries for every public subpath, no wildcard export patterns, no `require` conditions, `engines.node >=25`, `files`, `bin`, and build/test/prepack scripts.
- `node/README.md`: documents the partial public API, Node parity notes, disabled wrapper generation, and WASI-only build refresh.
- `scripts/lib/build-node-package.mjs`: rebuilds and copies the WASI CLI artifact while treating `node/internal/starshine.wasm-gc.wasm` as a checked-in boundary artifact.
- `scripts/lib/generate-node-package.mjs`: still intentionally throws because the old generator depended on the inactive legacy adapter path.
- `src/cli/pkg.generated.mbti`, `node/cli.d.ts`, and `node/cli.js`: MoonBit exposes `resolve_closed_world(...)`, `CliParseError::invalid_dump_path(...)`, `CliParseError::invalid_function_index_list(...)`, and `CliParseResult.closed_world`; the Node `cli` wrapper still lacks those parity members.
- `src/validate/pkg.generated.mbti`, `node/validate.d.ts`, and `node/validate.js`: MoonBit exposes a much wider current validation/generation/invalid-AST/diagnostic feature surface than Node. Important missing JS-facing groups include `validation_issue_family(...)`, `validate_defined_func_against_module(...)`, `default_gen_valid_config(...)`, `gen_valid_module_with_config(...)`, `gen_valid_module_result*`, profile/feature-ledger helpers, invalid-AST strategy registry/lookup/minimal-repro helpers, and the renamed `run_validate_invalid_ast_fuzz(...)` surface.
- `src/wast/pkg.generated.mbti`, `node/wast.d.ts`, and `node/wast.js`: MoonBit exposes `evaluate_wast_static_assertion(...)` and `wast_arbitrary_feature_stats(...)`; the Node `wast` wrapper exposes file/suite-level spec helpers but still lacks a command-level `evaluateWastStaticAssertion(...)` wrapper and arbitrary-feature stats.
- `node/test/api-parity.test.mjs`: current parity test coverage remains focused on the repaired `cmd` subpath; it is not yet a general export-map-driven parity test for `cli`, `validate`, and `wast`.

## Reconciliations and caveats

- The 2026-05-20 export-boundary conclusions still hold: `node/package.json#exports` is the public allowlist, `npm run build` does not regenerate wrappers, and the current package remains a partial host boundary.
- The new drift detail is that `validate` has expanded enough that the open Node gap should be described as grouped API slices, not only the seven May examples. The highest-value public slice is still diagnostics / invalid-AST repro tooling, because it composes with the focused validator diagnostics guide and avoids forcing JS consumers to parse human messages.
- The `wast` gap should distinguish file/suite spec helpers that already exist (`runWastSpecFile`, `runWastSpecSuite`) from the still-missing command-level static assertion evaluator.
- The export map is currently extensionless. Adding both extensionless and extensioned aliases for the same JS file would broaden the public API and contradict the single-style package-contract guidance unless treated as an intentional semver decision.
- No external source contradicted the existing wiki policy. This recheck strengthens the exact condition/export rationale and refreshes local wrapper-drift evidence through the current repository state.
