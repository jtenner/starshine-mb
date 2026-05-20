# Moon CLI command-manual refresh

_Capture date:_ 2026-05-20  
_Status:_ immutable primary-source bridge for [`docs/wiki/tooling/validation-gates.md`](../../tooling/validation-gates.md)

## Scope

This manifest refreshes the upstream MoonBit command evidence behind Starshine's validation-gate page. It deliberately records only the command surfaces that affect local validation workflows: `moon info`, `moon fmt`, `moon check`, `moon test`, `moon run`, `moon coverage analyze`, and `moon prove`.

## Official sources consulted

- MoonBit documentation, "Command-Line Help for moon" (`latest`, v0.9.2, crawled 2026-05-20): <https://docs.moonbitlang.com/en/latest/toolchain/moon/commands.html>
- Moon manual GitHub Pages (`moonbitlang.github.io/moon`, checked 2026-05-20): <https://moonbitlang.github.io/moon/commands.html>
- Moon manual source in the official `moonbitlang/moon` repository (`main`, checked 2026-05-20): <https://github.com/moonbitlang/moon/blob/main/docs/manual/src/commands.md>
- MoonBit build-system docs (`latest`, v0.9.2, checked 2026-05-20): <https://docs.moonbitlang.com/en/latest/toolchain/moon/index.html>

## Local repository evidence consulted

- [`../../../../scripts/lib/validate-task.ts`](../../../../scripts/lib/validate-task.ts) owns `bun validate full`, `coverage`, `readme-api-sync`, and `trace-benchmark` parsing plus command order.
- [`../../../../scripts/lib/task-runtime.ts`](../../../../scripts/lib/task-runtime.ts) owns `MOON_BIN`, workspace-root discovery, and Starshine's target whitelist.
- [`../../../../scripts/lib/fuzz-task.ts`](../../../../scripts/lib/fuzz-task.ts) owns `bun fuzz run` defaults and target propagation.
- [`../../../../scripts/test/task-family-commands.ts`](../../../../scripts/test/task-family-commands.ts) records command-shape expectations with a fake `moon` binary.

## Reviewed upstream command surfaces

- `moon check` remains the typecheck-only command, accepts target selection including `all`, and the up-to-date manual now documents path selectors plus `--fmt` as a check for formatting.
- `moon test` remains the deterministic test runner, accepts target selection including `all`, and the up-to-date manual documents path selection plus package/index/doc-test controls.
- `moon fmt` remains a mutating formatter by default. Official docs expose `--check`; the up-to-date manual also documents path selectors and `--warn`.
- `moon info` remains the `.mbti` generation command. The up-to-date manual clarifies that the canonical generated interface is chosen by preferred backend falling back to `wasm-gc`; `--target` inspects backend-specific interfaces and reports differences rather than changing the canonical `pkg.generated.mbti` output.
- `moon run` remains the executable-package runner; target values include `all`, but Starshine's wrappers should not forward `all` unless the local scripts explicitly widen their whitelist and command-shape tests.
- `moon coverage analyze` remains the upstream coverage surface that runs tests with instrumentation and reports coverage; package selection is upstream-owned, while Starshine currently parses only the resulting summary lines.
- `moon prove` remains a distinct proof command and is not part of `bun validate full`.

## Durable observations for Starshine

- Starshine's default `bun validate full` sequence is local policy: bare `moon info`, bare `moon fmt`, target-specific `moon check`, target-specific `moon test`, then `bun fuzz run --suite all --profile ci` through the in-repo wrapper.
- Upstream Moon accepts target `all`, but Starshine's [`assertTarget(...)`](../../../../scripts/lib/task-runtime.ts) currently accepts only `native`, `wasm`, `wasm-gc`, `llvm`, and `js`. Treat `all` as an upstream capability, not a supported Starshine wrapper target, until the scripts and tests are deliberately widened.
- Because Starshine invokes `moon fmt` without `--check`, the full gate can rewrite source files. That is acceptable local normalization policy, but maintainers must review the post-gate diff before committing.
- The older `docs.moonbitlang.com` generated command page and the up-to-date `moon` manual differ in several details (`PATH` selectors, `moon check --fmt`, `moon fmt --warn`, richer `moon info` backend semantics). Prefer the official `moon` repository/manual when exact CLI shape matters; use docs.moonbitlang.com for stable published documentation context.
- Do not cite MoonBit docs for Starshine defaults, fuzz profile names, target whitelist, pass-oracle requirements, or artifact semantics. Those remain grounded in local scripts, tests, and wiki workflow pages.

## Consumability rule

Cite this manifest together with [`../../tooling/validation-gates.md`](../../tooling/validation-gates.md) and the local script sources. Do not treat it as a full copy of upstream command documentation.