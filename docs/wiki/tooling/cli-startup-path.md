---
kind: concept
status: supported
last_reviewed: 2026-06-02
sources:
  - ../raw/research/0092-2026-04-16-cli-startup-performance-issues.md
  - ../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md
  - ../../../src/cli/cli.mbt
  - ../../../src/cli/glob.mbt
  - ../../../src/cli/glob_test.mbt
  - ../../../src/cmd/cmd.mbt
  - ../../../src/cmd/cmd_wbtest.mbt
  - ../../../src/passes/optimize.mbt
related:
  - ./cli-command-and-dispatcher.md
  - ./fuzz-runner.md
  - ./o4z-debug-startup-trap.md
  - ../../README.md
---

# CLI Startup Path

## Durable Conclusions

- The 2026-04-16 audit is historical now: `pass_registry_lookup` is cached, help text is prebuilt, `parse_olevel_text` parses raw `O` forms directly, and `parse_env_overlay` only probes mode-relevant variables.
- Fast-path evidence is now test-backed. `run_cmd_with_adapter` exits on parsed help before `STARSHINE_INPUT` probing, skips irrelevant env-overlay probes when the CLI already fixes startup mode, and bare `--version` still returns before env lookup.
- The live startup cost center is path handling. `normalize_cli_path` canonicalizes separators and dot segments for both CLI inputs and glob candidates, while `expand_globs` normalizes, deduplicates, sorts, and then bucket-matches candidates before emitting matches.
- Keep the fast-path split sharp: help/version should stay early returns, and startup tuning should prefer path normalization and candidate-bucket work over parser refactors.

## Current Follow-up Surface

- Use the raw audit note for the older line-by-line hotspot list; this page only keeps the compact current summary.
- Use [`cli-command-and-dispatcher.md`](./cli-command-and-dispatcher.md) for the current command/config/env/dispatcher contract; this page should stay focused on startup cost.
- The `o4z` debug-startup runtime blocker now has a dedicated living page in [`o4z-debug-startup-trap.md`](./o4z-debug-startup-trap.md); use that runtime-correctness page and the archived research note [`../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md`](../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md) for the trap owner evidence, and keep both distinct from the path-handling audit.
- If startup traces regress, check `normalize_cli_path`, `expand_globs`, and the `cmd_wbtest` fast-path coverage before widening the search.

## Sources

- Archived audit: [`../raw/research/0092-2026-04-16-cli-startup-performance-issues.md`](../raw/research/0092-2026-04-16-cli-startup-performance-issues.md)
- [`../../../src/cli/cli.mbt`](../../../src/cli/cli.mbt)
- [`../../../src/cli/glob.mbt`](../../../src/cli/glob.mbt)
- [`../../../src/cli/glob_test.mbt`](../../../src/cli/glob_test.mbt)
- [`../../../src/cmd/cmd.mbt`](../../../src/cmd/cmd.mbt)
- [`../../../src/cmd/cmd_wbtest.mbt`](../../../src/cmd/cmd_wbtest.mbt)
- [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt)
- Current command contract: [`./cli-command-and-dispatcher.md`](./cli-command-and-dispatcher.md)
