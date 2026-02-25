# Starshine Examples

This directory contains runnable, minimal examples for common CLI workflows.

## Layout

- `modules/simple.wat`: tiny arithmetic module for basic CLI smoke checks.
- `modules/feature_mix.wat`: multi-function module with globals/table/data for pass-pipeline demos.
- `config/optimize-release.json`: config-driven optimization pipeline with output settings.
- `env/starshine.env`: environment overlay template matching `STARSHINE_*` variables.

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
