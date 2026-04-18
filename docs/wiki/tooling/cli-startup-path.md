---
kind: concept
status: supported
last_reviewed: 2026-04-18
sources:
  - ../raw/research/0092-2026-04-16-cli-startup-performance-issues.md
  - ../../../src/cli/cli.mbt
  - ../../../src/cli/glob.mbt
  - ../../../src/cmd/cmd.mbt
  - ../../../src/passes/optimize.mbt
related:
  - ./fuzz-runner.md
  - ../README.md
---

# CLI Startup Path

## Durable Conclusions

- The 2026-04-16 audit is now mostly historical: `pass_registry_lookup` is cached, help text is prebuilt, `parse_olevel_text` parses raw `O` forms directly, and `parse_env_overlay` only probes mode-relevant variables.
- The live startup cost center is path handling. `normalize_cli_path` is shared by CLI inputs and globbing, and `expand_globs` still normalizes candidates eagerly before bucketed pattern matching.
- Keep the fast-path split sharp: help and version should stay early returns, and startup tuning should prefer path normalization and candidate-bucket work over parser refactors.

## Current Follow-up Surface

- Use the raw audit note for the older line-by-line hotspot list; this page only keeps the compact current summary.
- If startup traces regress, check `normalize_cli_path` and the candidate bucket selection in `src/cli/glob.mbt` before widening the search.

## Sources

- Archived audit: [`../raw/research/0092-2026-04-16-cli-startup-performance-issues.md`](../raw/research/0092-2026-04-16-cli-startup-performance-issues.md)
- [`../../../src/cli/cli.mbt`](../../../src/cli/cli.mbt)
- [`../../../src/cli/glob.mbt`](../../../src/cli/glob.mbt)
- [`../../../src/cmd/cmd.mbt`](../../../src/cmd/cmd.mbt)
- [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt)
