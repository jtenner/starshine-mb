# Starshine Examples

This directory contains runnable, minimal examples for common CLI workflows.

Use it as a small cookbook:

- Start with `modules/simple.wat` if you only want a tiny smoke-test input.
- Start with `config/optimize-release.json` if you want a config-driven pipeline.
- Start with `env/starshine.env` if you want environment-variable overlays.
- Start with `modules/feature_mix.wat` if you want a more realistic multi-feature module for pass experiments.

## Layout

- `modules/simple.wat`: tiny arithmetic module for basic CLI smoke checks.
- `modules/feature_mix.wat`: multi-function module with globals/table/data for pass-pipeline demos.
- `modules/table_dispatch.wat`: indirect-call dispatch through a function table (`call_indirect`).
- `modules/simd_lane_mix.wat`: SIMD lane operations (`i8x16.splat`, `i8x16.add`, lane extract).
- `modules/memory64_data.wat`: memory64 + `i64` data offsets with load/size operations.
- `config/optimize-release.json`: config-driven optimization pipeline with output settings.
- `env/starshine.env`: environment overlay template matching `STARSHINE_*` variables.

## Choose An Input

| If you want to try... | Start here | Why |
| --- | --- | --- |
| The smallest possible CLI roundtrip | `modules/simple.wat` | Minimal arithmetic module with almost no noise. |
| A more realistic optimization target | `modules/feature_mix.wat` | Multiple functions plus globals, tables, and data. |
| Table and indirect call behavior | `modules/table_dispatch.wat` | Focused `call_indirect` dispatch example. |
| SIMD-related passes and printing | `modules/simd_lane_mix.wat` | SIMD lane ops in a compact module. |
| Memory64 and data offsets | `modules/memory64_data.wat` | Good input for memory/data-related validation and encoding. |
| Config-driven CLI execution | `config/optimize-release.json` | Shows how to declare inputs, outputs, and passes in JSON. |
| Environment overlays | `env/starshine.env` | Mirrors the `STARSHINE_*` variables the CLI reads. |

## Quick Start

```bash
starshine --vacuum --code-folding --out-dir out examples/modules/simple.wat
```

```bash
starshine --config examples/config/optimize-release.json
```

```bash
set -a
source examples/env/starshine.env
set +a
starshine examples/modules/feature_mix.wat
```

```bash
starshine --global-effects --flatten --vacuum --out-dir out examples/modules/table_dispatch.wat examples/modules/simd_lane_mix.wat
```

## Common Tasks

### Run the smallest possible optimization

```bash
starshine --vacuum --out-dir out examples/modules/simple.wat
```

### Compare a few passes on a richer module

```bash
starshine --global-effects --flatten --vacuum --out-dir out examples/modules/feature_mix.wat
```

### Use a saved config file

```bash
starshine --config examples/config/optimize-release.json
```

### Use environment variable overlays

```bash
set -a
source examples/env/starshine.env
set +a
starshine examples/modules/feature_mix.wat
```

## Troubleshooting

- `starshine` is not found:
  build or install the CLI first, then re-run the example commands from the repository root.
- Input format errors on stdin:
  when reading from stdin, pass an explicit format flag so the CLI does not need to infer one from a filename.
- Config, env, and CLI values conflict:
  inputs merge as `config -> env -> cli`, while output targets and optimization settings are overridden by the most specific source.
- You want a fast smoke test before running a large pass set:
  start with `modules/simple.wat` and a short pass list such as `--vacuum --code-folding`.
