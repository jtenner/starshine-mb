# Starshine Examples

Examples are small, runnable CLI inputs for common workflows.

## Layout
- `modules/simple.wat`: tiny smoke-test module.
- `modules/feature_mix.wat`: multi-feature module for optimizer exercises.
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
starshine --vacuum --out-dir out examples/modules/simple.wat
starshine --config examples/config/optimize-release.json
source examples/env/starshine.env && starshine examples/modules/feature_mix.wat
starshine --global-effects --flatten --vacuum --out-dir out examples/modules/table_dispatch.wat examples/modules/simd_lane_mix.wat
```

## Notes
- Build/install CLI first if `starshine` is not found.
- Use config/env in the order: `config -> env -> cli`; output/optimization flags in env/cli override config.
- Prefer small-module checks before running long command sequences on large inputs.
