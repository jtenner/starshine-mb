# Agent Tasks

## Scope
- Keep only active work.
- Group active work by release target.
- For each active task, keep only blockers, risks, and current implementation facts.
- Move completed work to `CHANGELOG.md`.

## v0.1.0 Active Slice
- Hot-IR optimization rebuild
  - blockers:
    - `src/cmd/cmd.mbt` still routes many legacy pass names through compatibility expansion and no-op execution shims.
    - CLI/config still expose pass names and presets that imply optimizer behavior beyond the currently rebuilt hot-IR surface.
  - risks:
    - users can believe explicit pass flags performed real optimization when the current path only preserves scheduling/tracing compatibility.
    - pass/docs/test drift will keep growing until the rebuilt pass surface is either implemented or narrowed.
  - implementation features:
    - `src/ir/hot.mbt` is the owned hot function IR.
    - boundary decode/encode/validation/debug paths are raw-module based.
    - typed-tree optimizer ownership and the old pass-research docs are gone.

- CLI and docs alignment after optimizer reset
  - blockers:
    - README and CLI help still need an explicit policy for compatibility-only pass names versus rebuilt hot-IR passes.
  - risks:
    - public behavior is easy to misread while `--optimize`, `--shrink`, and explicit pass flags still preserve legacy naming.
  - implementation features:
    - command tracing, pass scheduling, and fuzz minimization still operate on pass-name lists.
    - docs cleanup removed obsolete optimizer research; remaining user docs should stay aligned with the rebuilt surface.

- Validator fuzz hardening
  - blockers:
    - the follow-up hardening work in `docs/0058-2026-03-23-validate-fuzz-hardening-plan.md` is still not fully implemented.
  - risks:
    - invalid-fuzz coverage quality can drift without stronger per-strategy accounting, expected-diagnostic checks, and repro artifacts.
  - implementation features:
    - the core fuzz migration is complete.
    - the command harness already supports pass minimization and structured failure reporting.

## v0.2.0 Backlog
- Improve fuzz ergonomics for corpus replay, shrinking, and first-class differential workflows.
- Benchmark and simplify deep decode/validation hot paths.
- Remove compatibility shims once rebuilt hot-IR optimization passes replace them.
