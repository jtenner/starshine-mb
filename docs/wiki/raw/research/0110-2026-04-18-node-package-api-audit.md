# 0110 - Node package API audit

## Status

- Date: 2026-04-18
- Type: One-off raw investigation
- Scope: Current `node/` package surface versus the active MoonBit package APIs under `src/*`, with emphasis on exposed Node coverage, source-of-truth drift, and which `validate` APIs are actually worth porting next.
- Source input: Repo-local audit of `node/*`, `scripts/lib/*node-package*.mjs`, `src/*/pkg.generated.mbti`, `README.md`, `node/README.md`, and the checked-in Node smoke/example tests.

## Commands run

- `node --version`
- `npm --version`
- `moon version`
- `git status --short`
- `cd node && node --test test/smoke.test.mjs`
- `cd node && node --test test/examples.test.mjs`
- Repo-local comparison scripts over:
  - `node/*.d.ts`
  - `node/*.js`
  - `src/*/pkg.generated.mbti`
  - `node/package.json`

## High-confidence findings

### 1) The current Node package works for its checked-in smoke/examples surface

The repo-local Node tests passed on `Node v25.9.0`:

- `node/test/smoke.test.mjs`: `13` tests passed.
- `node/test/examples.test.mjs`: `18` tests passed.

So the currently documented `binary` / `cli` / `cmd` / `lib` / `validate` / `wast` / `wat` workflows are not globally broken on the checked-in runtime path.

### 2) The Node package is not rebuilt from the active MoonBit package surface anymore

The current Node flow is explicitly frozen/manual instead of regenerated from a live adapter source:

- `scripts/lib/generate-node-package.mjs` says Node package generation is disabled during the optimization-pipeline refactor.
- `scripts/lib/build-node-package.mjs` treats `node/internal/starshine.wasm-gc.wasm` as a checked-in boundary artifact and explicitly says the old `src/node_api` rebuild path is gone.
- `node/README.md` says the `src/node_api` compatibility/staging surface is not rebuilt as part of the current Node flow.

This means API drift is now expected unless it is caught by explicit parity tests.

### 3) Package-level coverage is intentionally narrow relative to the active repo

Active MoonBit packages under `src/*/moon.pkg`:

- `binary`
- `bitset`
- `cli`
- `cmd`
- `diff`
- `fs`
- `fuzz`
- `ir`
- `lib`
- `passes`
- `passes_perf_long`
- `validate`
- `validate_proof`
- `validate_trace`
- `wast`
- `wat`

Node currently exports only:

- `binary`
- `cli`
- `cmd`
- `lib`
- `validate`
- `wast`
- `wat`

So the package-level Node surface is `7 / 16` active packages. Missing Node subpaths are:

- `bitset`
- `diff`
- `fs`
- `fuzz`
- `ir`
- `passes`
- `passes_perf_long`
- `validate_proof`
- `validate_trace`

This is not inherently wrong, but it means the Node package should be documented and tested as a deliberately partial host surface rather than as a full mirror of repo capabilities.

### 4) Top-level function parity is uneven across the exported Node modules

Comparison of `node/*.d.ts` against `src/*/pkg.generated.mbti` top-level functions:

| Module | Node-covered top-level fns | Total MoonBit top-level fns | Coverage |
| --- | ---: | ---: | ---: |
| `binary` | 6 | 6 | 100.0% |
| `cli` | 10 | 11 | 90.9% |
| `cmd` | 14 | 14 | 100.0% on paper, but see runtime/name drift below |
| `lib` | 36 | 36 | 100.0% |
| `validate` | 28 | 66 | 42.4% |
| `wast` | 13 | 14 | 92.9% |
| `wat` | 8 | 8 | 100.0% |

The largest practical gap is `validate`, which exposes less than half of the current top-level MoonBit surface.

### 5) `cli` is behind the current MoonBit parse/config surface

`src/cli/pkg.generated.mbti` exposes APIs and state that are not present in the current Node surface, notably:

- `resolve_closed_world(...)`
- `CliParseError::invalid_dump_path(...)`
- `CliParseError::invalid_function_index_list(...)`
- `CliParseResult.closed_world`
- `CliParseResult::new(..., closed_world?, tracing?)`

The current Node `cli` layer therefore lags the current CLI configuration and parser state contract.

### 6) `wast` is only missing a small but real static-assertion helper

`src/wast/pkg.generated.mbti` exposes:

- `evaluate_wast_static_assertion(...)`

That helper is not present in `node/wast.d.ts` or `node/wast.js`.

This is a narrow gap, but it is a useful one for JS-side spec-harness or fixture tooling.

### 7) `cmd` has the most obvious JS/runtime versus `.d.ts` drift

The `cmd` surface currently has a mismatch between the checked-in TypeScript declarations and the actual JS exports.

`node/cmd.d.ts` declares:

- `CmdFuzzStats`
- `runCmdFuzzHarness(...)`
- `runCmdFuzzHarnessProfile(...)`

But `node/cmd.js` actually exports:

- `WasmSmithFuzzStats`
- `runWasmSmithFuzzHarness(...)`

and does not export `runCmdFuzzHarnessProfile(...)`.

Additional structural drift exists too:

- MoonBit `CmdIO::new(...)` still includes `print_text_module`, but the Node typing surface does not.
- MoonBit `CmdRunSummary` includes `closed_world`, but the Node typing surface does not.

So `cmd` is the highest-priority export-contract cleanup even though the checked-in smoke tests happen to pass.

### 8) `validate` is the most incomplete exported Node module

The current Node `validate` surface omits several classes of useful MoonBit APIs:

- configured valid generation
- invalid-AST registry / repro helpers
- validation classification helpers
- targeted per-function validation
- tracing-capable module validation

The most notable missing top-level functions are:

- `default_gen_valid_config(...)`
- `gen_valid_module_with_config(...)`
- `validate_module_with_trace(...)`
- `validate_defined_func_against_module(...)`
- `validation_issue_family(...)`
- `validate_invalid_ast_registry(...)`
- `validate_invalid_ast_strategy_by_stable_id(...)`
- `build_validate_invalid_ast_minimal_repro(...)`
- `build_validate_invalid_ast_minimal_repro_by_stable_id(...)`
- `validate_invalid_ast_run_config(...)`
- `run_validate_invalid_ast_fuzz(...)`

By contrast, many low-level validator-internal helpers are present in MoonBit but are poor candidates for public Node priority.

### 9) The Node tests currently prove behavior, not API parity

The checked-in Node tests are valuable smoke tests, but they do not enforce source-of-truth parity.

Current Node coverage mostly proves that:

- basic roundtrip flows work,
- examples execute,
- a few JS callback shims for `cmd` behave as expected,
- the packaged WASI artifact can still start.

They do not currently fail when:

- a MoonBit API disappears from Node,
- `.d.ts` and `.js` drift apart,
- `node/package.json#exports` stops matching intended package coverage,
- constructor/field surfaces fall out of sync.

## Which `validate` APIs are actually worth porting?

### Definitely worth porting next

These have clear value for real Node consumers:

1. `validate_module_with_trace(...)`
   - Best missing practical validator API.
   - Useful for CLIs, editor integrations, triage tooling, and test harnesses.

2. `validation_issue_family(...)`
   - Pairs naturally with `validation_error_diagnostic(...)`, `validation_error_message(...)`, and `validation_error_func_idx(...)`.
   - Lets JS tools bucket failures by stable family instead of parsing error strings.

3. `validate_defined_func_against_module(...)`
   - Useful for targeted sanity checks after local JS-side module or function edits.
   - More valuable if Node later exposes more rewrite or pass tooling.

4. `default_gen_valid_config(...)`
5. `gen_valid_module_with_config(...)`
   - `gen_valid_module(...)` without config is too limited for serious JS-side fuzzing or coverage control.

6. `validate_invalid_ast_registry(...)`
7. `validate_invalid_ast_strategy_by_stable_id(...)`
8. `build_validate_invalid_ast_minimal_repro_by_stable_id(...)`
   - These are the best invalid-surface exports to add if Node is meant to support repro tooling, CI smoke checks, or stable issue attachments.

### Maybe later

Useful for dedicated fuzz/coverage tooling, but lower priority for ordinary Node consumers:

- `run_validate_invalid_ast_fuzz(...)`
- `validate_invalid_ast_run_config(...)`
- `gen_valid_feature_facts(...)`
- `validate_valid_feature_actual_count(...)`
- `check_validate_valid_feature_floors(...)`
- `validate_valid_run_config(...)`

### Not worth prioritizing right now

These are validator-internal or low-level composition helpers rather than good public Node APIs:

- the `tc_state_*` family
- `tc_escape_none(...)`
- `tc_escape_terminal(...)`
- `make_state_owned(...)`
- raw `gen_invalid_*` plumbing like `gen_invalid_ast_generate(...)`, `gen_invalid_ast_seed_module(...)`, and the config shapers
- section-by-section validators like `validate_typesec(...)`, `validate_importsec(...)`, `validate_funcsec(...)`, `validate_tablesec(...)`, and similar

Those helpers are useful inside the validator implementation, but they are not the best next public surface for Node.

## Recommended widening plan

### Phase 0 - lock parity drift down

Add explicit contract tests that compare:

- `src/*/pkg.generated.mbti`
- `node/*.d.ts`
- `node/*.js`
- `node/package.json#exports`

This should fail when:

- a MoonBit export is unintentionally missing from Node,
- a `.d.ts` export is missing at runtime,
- runtime JS exports have stale or legacy names,
- package export-map coverage drifts.

### Phase 1 - fix current correctness and UX gaps

1. Repair `cmd` naming/runtime drift:
   - align `CmdFuzzStats` / `runCmdFuzzHarness(...)` / `runCmdFuzzHarnessProfile(...)`
   - keep legacy aliases only if explicitly documented
2. Bring `cli` back in sync on `closed_world` and parser error constructors.
3. Add `wast.evaluateWastStaticAssertion(...)`.
4. Add the high-value `validate` surface listed above.

### Phase 2 - widen Node coverage deliberately

If the project wants Node to be more than a boundary/CLI wrapper, the next package candidates with the best value-to-scope ratio are:

- `diff`
- `fs`
- `validate_trace`
- `fuzz`

Only after that should the project decide whether Node is meant to expose the deeper programmable optimizer surface (`ir`, `passes`, and related packages).

## Suggested Node coverage tests

The most useful missing tests are:

1. export-shape parity tests (`.d.ts` versus `.js`)
2. source-of-truth parity tests (`pkg.generated.mbti` versus Node wrappers)
3. TypeScript consumer tests (`tsc --noEmit` over examples plus an all-imports fixture)
4. `npm pack` / temp-install smoke tests for the published artifact
5. `validate`-specific behavior tests for:
   - configured valid generation
   - validation-family classification
   - invalid minimal repro builders
   - trace output callback behavior

## Open questions

1. Should the Node package stay intentionally boundary-focused, or is it meant to become a first-class programmable compiler/debug surface?
2. If Node remains intentionally partial, should the README and package docs say so more explicitly?
3. Does the repo want a replacement generation path for Node bindings, or should the checked-in JS/TS wrappers be treated as a hand-maintained public API layer?

## Source map

- Public docs and package metadata:
  - `README.md`
  - `node/README.md`
  - `node/package.json`
- Node runtime/type surfaces:
  - `node/index.js`
  - `node/index.d.ts`
  - `node/binary.js`
  - `node/binary.d.ts`
  - `node/cli.js`
  - `node/cli.d.ts`
  - `node/cmd.js`
  - `node/cmd.d.ts`
  - `node/lib.js`
  - `node/lib.d.ts`
  - `node/validate.js`
  - `node/validate.d.ts`
  - `node/wast.js`
  - `node/wast.d.ts`
  - `node/wat.js`
  - `node/wat.d.ts`
- Build/rebuild flow:
  - `scripts/lib/generate-node-package.mjs`
  - `scripts/lib/build-node-package.mjs`
- MoonBit source-of-truth signatures:
  - `src/binary/pkg.generated.mbti`
  - `src/cli/pkg.generated.mbti`
  - `src/cmd/pkg.generated.mbti`
  - `src/lib/pkg.generated.mbti`
  - `src/validate/pkg.generated.mbti`
  - `src/wast/pkg.generated.mbti`
  - `src/wat/pkg.generated.mbti`
- Node tests exercised during this audit:
  - `node/test/smoke.test.mjs`
  - `node/test/examples.test.mjs`
