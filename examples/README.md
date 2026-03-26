# Starshine Examples

Examples are small, runnable CLI inputs for common workflows.

## Layout
- `modules/simple.wat`: tiny smoke-test module.
- `modules/feature_mix.wat`: multi-feature module for CLI and IR2 optimizer pipeline exercises.
- `modules/table_dispatch.wat`: table + `call_indirect` flow.
- `modules/simd_lane_mix.wat`: SIMD lane expressions.
- `modules/memory64_data.wat`: memory64 + data offset cases.
- `config/optimize-release.json`: preset pipeline config.
- `env/starshine.env`: example `STARSHINE_*` overrides.

## Pick an Entry
- Minimal smoke: `modules/simple.wat`
- Config run: `config/optimize-release.json`
- Env-driven run: `env/starshine.env`
- Realistic optimization target: `modules/feature_mix.wat`

## Quick Commands

```bash
starshine --out-dir out examples/modules/simple.wat
starshine --vacuum --out-dir out examples/modules/simple.wat
starshine --config examples/config/optimize-release.json
source examples/env/starshine.env && starshine examples/modules/feature_mix.wat
starshine --optimize --out-dir out examples/modules/feature_mix.wat
starshine --shrink --out-dir out examples/modules/table_dispatch.wat
```

## Notes
- Build/install CLI first if `starshine` is not found.
- Config/env/CLI precedence is `config -> env -> cli`; in practice, CLI overrides all, env overrides config, and config provides defaults.
- `--optimize` and `--shrink` run through the active hot preset pipeline.
- Legacy pass names are still surfaced in registry diagnostics, but only active hot/module/preset names are accepted for actual execution.
- Prefer small-module checks before running long command sequences on large inputs.
