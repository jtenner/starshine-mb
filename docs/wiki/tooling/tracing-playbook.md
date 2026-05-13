---
kind: concept
status: supported
last_reviewed: 2026-05-13
sources:
  - ../raw/research/0001-2026-03-10-tracing.md
related:
  - ./validation-gates.md
  - ../validate/module-validation-phases.md
  - ../../../src/lib/util.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/passes/trace_golden_test.mbt
  - ../../../src/passes/optimize.mbt
---

# Tracing Playbook

## Durable Conclusions

- Traced entrypoints take an optional `trace?` callback and a `trace_all_funcs?` gate.
- Tracing must stay cheap when disabled; timing work and per-function setup are guarded locally.
- Logs use compact `key=value` tokens with stable pass, function, and phase markers.
- Shared timing helpers live in [`../../../src/lib/util.mbt`](../../../src/lib/util.mbt).
- Passes and validator entrypoints should emit per-function deltas, run totals, and a final hotspot summary; benchmark entrypoints are routed through the shared [`validation-gates.md`](./validation-gates.md) command map, and validator phase names are cataloged in [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md).
- Repeated failures should be suppressed after a bounded prefix instead of flooding output.
- Do not add trace-only tests; trace behavior is validated through existing functional or contract coverage.

## Log Contract

- `pass[...]`: `start`, `done`, `error`
- `func[...]` lifecycle lines
- `phase=...`
- `changed=true|false`
- elapsed timing plus one or two size counters

## Practical Rule

- Reuse the shared trace shape across validator and pass entrypoints instead of inventing pass-local log formats.
- Emit one compact final summary line per run and keep detailed timing and hotspot work behind the trace gate.
- If trace shape changes, update the existing passing contract or golden coverage instead of adding a trace-only lane.

## Sources

- Archived research doc: [`../raw/research/0001-2026-03-10-tracing.md`](../raw/research/0001-2026-03-10-tracing.md)
- Shared validation-gate map: [`./validation-gates.md`](./validation-gates.md)
- Timing helpers: [`../../../src/lib/util.mbt`](../../../src/lib/util.mbt)
