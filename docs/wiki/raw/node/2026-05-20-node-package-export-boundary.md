# Node Package Export Boundary Sources

Capture date: 2026-05-20

## External primary/high-quality sources

- Node.js v26.1.0 documentation, "Modules: Packages": <https://nodejs.org/api/packages.html>
  - Checked the `package.json` `type`, `main`, and `exports` rules for ESM package entry points.
  - Durable takeaway: a package `exports` map is the authoritative public subpath boundary for Node resolution; unlisted subpaths are intentionally not part of the package contract. Extensionless subpaths are valid, but a package should keep a single stable specifier style per public subpath.
  - Starshine relevance: `node/package.json` deliberately lists the public `@jtenner/starshine` subpaths (`.`, `./binary`, `./cli`, `./cmd`, `./lib`, `./validate`, `./wast`, and `./wat`), so wiki/API docs should not imply private files or omitted MoonBit packages are importable Node API.

- TypeScript Handbook, "Modules - Reference": <https://www.typescriptlang.org/docs/handbook/modules/reference>
  - Checked the current TypeScript resolver discussion for `package.json` `exports`, `types` conditions, and package-relative fallback behavior.
  - Durable takeaway: in Node-aware resolution modes, TypeScript follows Node's package `exports` contract for bare package lookups, then applies TypeScript-specific declaration resolution. The presence of `exports` blocks undeclared subpaths from resolving through package-relative fallback.
  - Starshine relevance: each exported `node/package.json` subpath carries a `types` target plus an `import` target, so wrapper parity must cover both the runtime `.js` file and the matching `.d.ts` declaration file.

## Repository evidence checked

- `node/package.json`: ESM package, explicit `exports` map, `engines.node >=25`, `npm run build`, `npm run generate`, and `prepack` command wiring.
- `node/README.md`: public package summary and build-note wording.
- `scripts/lib/build-node-package.mjs`: builds `src/cmd` for the WASI CLI artifact, keeps the checked-in `node/internal/starshine.wasm-gc.wasm`, and copies only the WASI artifact into `node/internal/starshine.wasm-wasi.wasm`.
- `scripts/lib/generate-node-package.mjs`: generation is intentionally disabled while the old `src/node_api` adapter path is not active.
- `scripts/lib/make-task.ts`: `bun make node-package` dispatches to `buildNodePackage(...)`; `bun make generate-node-package` dispatches to the disabled generator.
- `src/cli/pkg.generated.mbti`, `node/cli.d.ts`, and `node/cli.js`: MoonBit `cli` still has closed-world fields/helpers that the Node `cli` wrapper does not expose.
- `src/wast/pkg.generated.mbti`, `node/wast.d.ts`, and `node/wast.js`: MoonBit `wast` exports `evaluate_wast_static_assertion(...)`, while Node `wast` still lacks an `evaluateWastStaticAssertion(...)` wrapper.
- `node/test/api-parity.test.mjs`: current parity coverage is focused on the repaired `cmd` subpath, not a full MoonBit-to-Node package parity audit.

## Reconciliations and caveats

- The wiki's prior build-boundary claim was correct: `npm run build` does **not** regenerate every checked-in JS/TS wrapper from MoonBit signatures. The checked-in Node README still said the package surface was regenerated, so the README needed a wording fix.
- `node/package.json#exports` is a public API allowlist, not an implementation-directory mirror. Omitted active MoonBit packages such as `cli-benchmarks`, `fuzz`, `ir`, `passes`, `spec_runner`, `validate_proof`, and `validate_trace` remain intentionally private to the repo until a separate API-design decision exposes them.
- The current `types` + `import` export entries make declaration/runtime parity a package invariant for the listed subpaths only. The stronger future test should classify missing symbols as public-now, intentionally unsupported by the wasm-gc adapter, or intentionally omitted from the partial Node package instead of requiring blanket parity.
