# 0092 - CLI startup performance audit (src/cli startup path)

## Status

- Date: 2026-04-16
- Type: One-off raw investigation
- Scope: Startup behavior for CLI argument/config parsing and option-dispatch logic in `src/cli/*` and `src/cmd/cmd.mbt`.
- Source input: follow-up review based on the startup-path issues already observed in the CLI implementation.

## Summary

The CLI startup path contains several avoidable costs that impact latency for small invocations:

- Registry lookup and pass resolution are doing redundant O(n) allocations/scan work per lookup.
- Help/version/usage paths still parse config files.
- Several parser helpers allocate short-lived temporary strings repeatedly.
- Globbing performs full pairwise candidate matching and repeated normalization.

These are likely to show up in startup profile slices because they happen before module I/O/optimization.

## High-confidence findings

### 1) `pass_registry_lookup` rebuilds pass registry each call (critical)

**Location(s):**

- `src/passes/optimize.mbt:264-267` (`pass_registry_lookup`)

**Why it is a startup issue:**

`pass_registry_lookup` calls `pass_registry_entries()` inside the lookup loop. That constructor returns a newly-built array of all entries for each invocation, so lookup is repeatedly reallocating and scanning registry contents. This is repeatedly exercised when parsing pass flags and when resolving help text.

**Impact:**

- Extra allocations per lookup (registry rebuild)
- O(registry_size) scan per lookup
- Quadratic behavior with many pass flags due to repeated scan/rebuild in looped lookups.

### 2) `--help` and `--version` still load/config-parse before exit (critical)

**Location(s):**

- `src/cmd/cmd.mbt:2999-3008` early return checks for help/version
- `src/cmd/cmd.mbt:3016-3023` config-resolution/parsing starts immediately after those checks

**Why it is a startup issue:**

Even when only needing help/version, the code proceeds to resolve config path and parse config text/JSON, including file existence checks and full parse work, before returning.

**Impact:**

- Unnecessary disk I/O and JSON parsing for trivial commands.
- Prevents true constant-time help/version responses.

### 3) `parse_olevel_text` recursively invokes the full CLI parser (high)

**Location(s):**

- `src/cmd/cmd.mbt:496-516`

**Why it is a startup issue:**

`parse_olevel_text` creates a synthetic flag string then calls `parse_cli_args([flag])`. That path reparses a one-element arg-array through the full parser logic.

**Impact:**

- Allocations for temporary arrays/strings beyond required complexity.
- Extra branch-heavy parse work called from both config and env parsing paths.

### 4) Repeated temp string allocations in parsing helpers (high)

**Location(s):**

- `src/cli/cli.mbt:388-394` `append_input_glob`
- `src/cli/cli.mbt:418-427` `parse_dump_pass_value`
- `src/cli/cli.mbt:431-440` `parse_print_pass_value`
- `src/cli/cli.mbt:443-447` `parse_extract_functions_value`
- `src/cmd/cmd.mbt:274-279` `parse_bool_string`
- `src/cmd/cmd.mbt:283-288`, `src/cmd/cmd.mbt:291-296`, `src/cmd/cmd.mbt:299-303` (format/trap/tracing parsers)

**Why it is a startup issue:**

These functions allocate fresh strings for normalization (`trim().to_string`) and/or lowercasing, then parse; many are executed in command/env parsing before processing input modules.

**Impact:**

- Higher GC churn from short-lived allocation volume.
- Extra CPU in startup-only fast paths (small command invocations).

### 5) Glob expansion is O(P×C) with repeated matching work (high)

**Location(s):**

- `src/cli/glob.mbt:186-213` (`expand_globs`)
- `src/cli/glob.mbt:167-183` (`glob_match`)
- `src/cmd/cmd.mbt:1068-1090` `resolve_input_files_with_glob` (invocation path)

**Why it is a startup issue:**

- All candidates are normalized and de-duplicated once.
- For each pattern, every normalized candidate is scanned again.
- `glob_match` then normalizes/re-splits and performs segment recursion each time.

**Impact:**

- Startup path can become expensive when globbing is enabled and candidate set is large.
- Duplicate path normalization + matcher work multiplies with pattern count.

### 6) Help text rebuilds pass registry on every `--help` path (medium)

**Location(s):**

- `src/cmd/cmd.mbt:2508-2521` (`cmd_help_text`)

**Why it is a startup issue:**

`cmd_help_text` iterates `pass_registry_all()` (which routes through pass registry construction/scan) every time help text is requested, and writes the whole message via repeated `write_char` in a loop.

**Impact:**

- Nontrivial allocation and pass-registry work on each help invocation.

### 7) `normalize_cli_path` does multiple passes without caching (medium)

**Location(s):**

- `src/cli/glob.mbt:105-143` (`normalize_cli_path`)
- Multiple call sites in glob/config/env/IO-path processing.

**Why it is a startup issue:**

Normalization is called repeatedly on overlapping path values across parsing steps and candidate matching.

**Impact:**

- Extra temporary string creation and repeated character scans before the main workload starts.

### 8) Full config parse runs even for short CLI commands (medium)

**Location(s):**

- `src/cmd/cmd.mbt:581-600` (`parse_config_json`)
- `src/cmd/cmd.mbt:3016-3029` (config load in `run_cmd_with_adapter` for normal path)

**Why it is a startup issue:**

Even when user intent may only require help/version (or simple env-based parsing), the full parser still runs if invocation continues past early return.

**Impact:**

- Avoidable full AST parse overhead in startup path.

### 9) Unconditional environment variable probing (`parse_env_overlay`) (medium)

**Location(s):**

- `src/cmd/cmd.mbt:906-1064`

**Why it is a startup issue:**

`parse_env_overlay` performs many independent `io.get_env` calls regardless of whether those variables are relevant for the current mode.

**Impact:**

- Extra callback overhead for every invocation (including hot startup paths).

### 10) Suffix checks convert chars to strings each step (low)

**Location(s):**

- `src/cmd/cmd.mbt:1448-1449` in `cmd_path_has_ascii_suffix_ignore_case`

**Why it is a startup issue:**

Character compare currently converts values to `String` per comparison for the suffix test.

**Impact:**

- Unnecessary tiny allocations in repeated path checks.

## Evidence mapping

- `src/passes/optimize.mbt:264-267` (registry lookup rebuilding behavior)
- `src/cmd/cmd.mbt:2999-3029` (help/version and config parsing control flow)
- `src/cmd/cmd.mbt:496-516`, `1014-1015`, `749-750` (olevel parsing + recursive parser reuse)
- `src/cli/cli.mbt:388-394`, `418-447` (arg parsing temp allocation points)
- `src/cli/glob.mbt:186-213`, `167-183`, `105-143` (normalization + expansion complexity)
- `src/cmd/cmd.mbt:2508-2511` (help text assembly path)
- `src/cmd/cmd.mbt:906-1064` (env overlay parsing)
- `src/cmd/cmd.mbt:1448-1449` (suffix compare allocation pattern)

## Likely startup impact estimate

The heaviest startup regressors are likely:

1) pass registry lookup construction in looped hot path,
2) avoidable config parsing for help/version,
3) O(P×C) glob expansion with repeated normalization/matching,
4) repeated small allocations in parsing helpers.

## Suggested non-code follow-up

Treat this as an audit record before tuning:

- Confirm with startup trace (or `moon test` with a minimal command benchmark) whether `--help`, `--version`, and empty input lists avoid disk and JSON work after a dedicated fix.
- Then stage micro-optimizations to argument parsing / glob expansion first, followed by registry caching / lookup indexing.

## Open question

Should this be split into two work slices:

- **Slice A (fast path):** `--help`/`--version` and config/env short-circuit.
- **Slice B (steady-state):** pass lookup/registry caching and glob normalization caching.