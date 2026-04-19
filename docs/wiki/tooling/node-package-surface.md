---
kind: concept
status: supported
last_reviewed: 2026-04-18
sources:
  - ../raw/research/0110-2026-04-18-node-package-api-audit.md
  - ../../../node/package.json
  - ../../../node/README.md
  - ../../../scripts/lib/generate-node-package.mjs
  - ../../../scripts/lib/build-node-package.mjs
  - ../../../src/validate/pkg.generated.mbti
related:
  - ./fuzz-runner.md
  - ./cli-startup-path.md
  - ../validate/fuzz-hardening.md
  - ../README.md
---

# Node Package Surface

## Durable Conclusions

- The checked-in `node/` package currently works for its smoke-tested boundary surface, but it is no longer regenerated from the active MoonBit package graph. The current flow is a checked-in wrapper layer around a frozen GC artifact plus a rebuilt WASI CLI artifact, so API drift must be caught with explicit parity tests rather than assumed away.
- The public Node surface is intentionally narrower than the active repo surface: `node/package.json` exports only `binary`, `cli`, `cmd`, `lib`, `validate`, `wast`, and `wat`, while the repo currently has additional active packages such as `diff`, `fs`, `fuzz`, `ir`, `passes`, `validate_trace`, and others.
- The largest current contract gap inside the exported surface is `validate`: the Node wrapper exposes only a minority of the live MoonBit top-level functions, and the most valuable missing pieces are diagnostics and configured-generation helpers rather than low-level validator internals.
- The highest-priority correctness cleanup across the existing Node surface is `cmd` export drift between `node/cmd.d.ts` and `node/cmd.js`; after that, the next practical additions are `cli` closed-world parity, `wast.evaluateWastStaticAssertion(...)`, and a small high-value `validate` expansion.

## Validate APIs Worth Porting Next

Port these first:

1. `validate_module_with_trace(...)`
2. `validation_issue_family(...)`
3. `validate_defined_func_against_module(...)`
4. `default_gen_valid_config(...)`
5. `gen_valid_module_with_config(...)`
6. `validate_invalid_ast_registry(...)`
7. `validate_invalid_ast_strategy_by_stable_id(...)`
8. `build_validate_invalid_ast_minimal_repro_by_stable_id(...)`

These APIs help real JS consumers with tracing, failure bucketing, targeted validation, configured valid generation, and stable invalid repro workflows.

Do not prioritize the `tc_state_*` family, raw `gen_invalid_*` plumbing, or section-by-section validators unless Node is explicitly becoming a low-level programmable validator engine.

## Recommended Maintenance Rule

Keep a repo-local parity test that compares:

- `src/*/pkg.generated.mbti`
- `node/*.d.ts`
- `node/*.js`
- `node/package.json#exports`

That test should fail on any accidental gap between the live MoonBit signatures and the checked-in Node wrapper layer.

## Sources

- Archived audit: [`../raw/research/0110-2026-04-18-node-package-api-audit.md`](../raw/research/0110-2026-04-18-node-package-api-audit.md)
- [`../../../node/package.json`](../../../node/package.json)
- [`../../../node/README.md`](../../../node/README.md)
- [`../../../scripts/lib/generate-node-package.mjs`](../../../scripts/lib/generate-node-package.mjs)
- [`../../../scripts/lib/build-node-package.mjs`](../../../scripts/lib/build-node-package.mjs)
- [`../../../src/validate/pkg.generated.mbti`](../../../src/validate/pkg.generated.mbti)
