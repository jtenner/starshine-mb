# Starshine Docs And Wasm Knowledge Base

This file is the canonical schema for documentation and wiki maintenance in this repo. It consolidates the current repo rules from `AGENTS.md` and the wiki-maintenance rules adapted from Andrej Karpathy's `LLM Wiki` pattern plus Rohit Gupta's `LLM Wiki v2` extension.

If `AGENTS.md` and this file ever diverge, update both in the same change. Keep repo-wide operational constraints in `AGENTS.md`; keep the longer wiki schema here.

## High-Signal Repo Rules

This section mirrors `AGENTS.md` and is intentionally compact enough to reuse in agent runtime context when needed. Keep repo-wide operational constraints here and in `AGENTS.md`; keep the longer wiki schema below.

### Repo Essentials

- MoonBit workspace with directory-scoped packages via `moon.pkg` under `moon.mod.json`.
- Tests live beside implementation as `*_test.mbt` or `*_wbtest.mbt`; package imports live in `package*/imports.mbt`.
- Review `.mbti` diffs for public API changes.
- `docs/README.md` is the canonical docs and wiki schema; keep it in sync with `AGENTS.md`.
- Keep normative docs in `docs/`, living knowledge in `docs/wiki/`, immutable committed sources in `docs/wiki/raw/` except for redaction or format normalization, and one-off investigations in `docs/wiki/raw/research/[serial]-[YYYY-MM-DD]-[kebab-title].md`.
- Keep `docs/wiki/index.md` and `docs/wiki/log.md` current when wiki schema, ingest, query-fileback, or lint behavior changes.
- `src/node_api/`, `src/optimization/`, and `src/transformer/` are inactive compatibility or staging dirs unless rebuilt.
- `agent-todo.md` is active unreleased backlog only. `agent-lost-and-found.md` is local-only and must never be committed.

### Always-Follow Workflow Rules

- Use TDD: write or update tests first, confirm failure, then implement.
- Start from `docs/` for major architecture, ABI, release, planning, or wiki-schema work. Read `docs/README.md` first for knowledge-base ingest, query, lint, or schema work.
- Update relevant docs for behavior or API changes; keep docs concise.
- Update pass tests in the implementing file and active dispatcher. Today that is usually `src/cmd/cmd.mbt`; later also `src/passes/optimize.mbt`.
- Do not remove features, disable passing tests, add telemetry-only tests, or add shell scripts under `scripts/`.
- Gitignore new non-repo build or cache dirs when needed.
- Do not use destructive git commands unless explicitly requested.
- Serialize `moon` commands because they contend on `_build/.moon-lock`.

### Task-Specific Rules

#### Docs And Wiki

- Prefer updating an existing wiki page over creating a near-duplicate page.
- Cite supporting numbered docs, raw sources, tests, or source files.
- Record uncertainty, contradictions, and supersession explicitly; do not silently overwrite stale claims.
- Treat completed debugging, research, and design threads as sources; file durable conclusions back into the wiki.
- Once a research note in `docs/` has been fully absorbed and is no longer the active normative contract, move it to `docs/wiki/raw/research/` and repoint live references.
- Never commit secrets, credentials, tokens, or other private material into `docs/wiki/` or `docs/wiki/raw/`.

#### Working On Passes

- Correctness first.
- Match oracle Binaryen semantics at minimum; byte-for-byte wasm, raw canonical wasm/text, or transform-for-transform parity is not required when normalized/canonical semantic evidence proves equivalence.
- Every transform must be safe and produce a valid wasm module.
- Target `< 1s` or `>= 50%` of Binaryen pass-local wall time where possible.
- Verify parity with `bun fuzz compare-pass ...` (the project wrapper); `bun scripts/pass-fuzz-compare.ts` remains the same underlying implementation when invoked directly, at `10000` comparisons.
- For DAE / `dae-optimizing` mixed-generator compare-pass lanes, include `--normalize drop-consts --normalize unreachable-control-debris` so known generated dropped-constant and unreachable/control debris counts as `cleanupNormalizedMatchCount` instead of blocking the run as raw mismatches; still classify any remaining mismatches normally.
- When reporting compare-pass mismatches, classify them as an agent judgment, not as a harness-provided fact: semantic-safe/size-winning, representation-only, size-losing, unknown/risky, validation failure, tool/Binaryen failure, or true semantic mismatch. Do not call a mismatch semantically safe just because both outputs validate or Starshine is smaller; cite the transform contract, inspected diff family, replay evidence, or other semantic reason.
- Prefer `--pass <name>` with canonical pass names and treat the harness as pass-targeted before expanding to combined-pass runs.
- Use `.pi/skills/starshine-pass-implementation/SKILL.md` as the detailed pass creation, porting, parity-fix, registry-wiring, and signoff workflow.

#### Validation And Signoff

- Preferred quick signoff: `moon info`, `moon fmt`, then `moon test`.
- Prefer `bun validate` before committing.
- Local full gate: `bun validate full --profile ci --target wasm-gc`.
- Coverage: `bun validate coverage`.
- README sync: `bun validate readme-api-sync`.

#### Commit And Publish

- Update relevant docs before commit; do not add per-commit changelog entries.
- Use docs/wiki pages, `docs/wiki/log.md`, release notes, and git history for durable change records.
- Review the staged diff.
- Commit with `git commit -F <temp-file>` and include changed files plus reasons in the commit text.
- Prune stale `agent-todo.md` items and add new blockers or risks.
- Publishing requires an explicit semver bump, successful validation, consistent package version bumps, and release notes drafted from the relevant docs/wiki pages and git history.

#### Research, Backlog, And MoonBit Style

- Research docs use the next zero-padded serial with commit date and short kebab title after scanning `docs/`, `docs/wiki/`, and `docs/wiki/raw/research/` for overlaps.
- Substantial investigations belong in `docs/wiki/raw/research/`; keep durable conclusions live in `docs/wiki/` when they should remain reusable.
- Keep `agent-todo.md` grouped by release target and IR2 slice id, with only active unreleased work plus goal, why, deliverables, tasks, required APIs, invariants, dependencies, exit criteria, and suggested tests.
- Keep release blockers and known test failures visible until resolved.
- MoonBit style: use block-structured `///|`, prefer constructor methods over open-struct literals, and keep deprecated behavior in `deprecated.mbt` with `#deprecated`.

## Reference Details

Use this section for lower-frequency details that help humans and agents orient in the repo but do not need top billing in `AGENTS.md`.

### Layout Details

- Active packages live under `src/`; the current active package set is `binary`, `bitset`, `cli`, `cli-benchmarks`, `cmd`, `diff`, `fs`, `fuzz`, `ir`, `lib`, `passes`, `passes_perf_long`, `spec_runner`, `validate`, `validate_proof`, `validate_trace`, `wast`, and `wat`.
- `examples/` contains runnable examples.
- `tests/spec/` and `tests/node/` hold external and integration coverage.
- `scripts/` contains Bun entrypoints only: `validate.ts`, `fuzz.ts`, `self-opt.ts`, `make.ts`, `examples.ts`, and `pass-fuzz-compare.ts`.
- `scripts/lib/*` contains shared script code.
- `scripts/test/*` contains script tests.

### Workflow Details

- Common MoonBit commands: `moon info`, `moon fmt`, `moon check`, `moon test`, and `moon test --update`.
- Common Bun workflows: `bun validate ...`, `bun fuzz ...`, `bun self-opt ...`, `bun make ...`, and `bun examples ...`.
- Run one CLI startup microbenchmark via `moon run src/cli-benchmarks -- [--iterations <n>] [--warmup <n>] [-- <starshine-cli-args...>]`; everything after the second `--` is benchmarked as Starshine CLI input. Run broad benchmark sweeps via `bun run cli-benchmarks -- [--suite smoke|standard|full] [--iterations <n>] [--warmup <n>]`.
- Run fuzzing via `moon run src/fuzz ...` or `bun fuzz run ...`; do not put heavy randomized loops inside `moon test`.
- Use `bun fuzz compare-pass --list-passes` to discover supported canonical pass names (equivalently, `bun scripts/pass-fuzz-compare.ts --list-passes`).
- The pass-comparison harness alternates `wasm-tools smith` and in-repo `gen_valid`, validates with `wasm-tools validate`, and compares normalized `wasm-opt -S --strip-debug` output; use `--jobs auto` or `--jobs <n>` with `--starshine-bin` on long lanes to run independent cases concurrently without parallel `moon` lock contention. Use explicit compare normalizers only when documented for the pass, e.g. DAE's `--normalize drop-consts --normalize unreachable-control-debris`, and report `cleanupNormalizedMatchCount` separately from exact `normalizedMatchCount`.
- Ask before running the full self-optimize pipeline.
- Ask before running `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --optimize`.
- Parity signoff requires Binaryen semantic parity, valid wasm output, and Starshine pass-local wall time `>= 50%` of Binaryen where possible; raw wasm/text drift is acceptable when canonical semantic comparison is green.

## Wasm Knowledge Base Rules

### Scope

- The wiki exists to accumulate durable WebAssembly knowledge for this repo: spec semantics, Binaryen parity findings, Starshine invariants, pass behavior, debugging lessons, tooling quirks, and decision history.
- Keep `docs/` for normative docs only: schema, policies, ADRs, and active handoff docs.
- Use numbered `docs/wiki/raw/research/[serial]-[YYYY-MM-DD]-[kebab-title].md` files for one-off research, plans, audits, and benchmarks.
- Use `docs/wiki/` for living pages that should be updated over time instead of replaced.

### Architecture

Keep three layers in the wiki architecture:

- Raw sources: immutable inputs captured under `docs/wiki/raw/` when they belong in the repo.
- Research archive: repo-authored numbered investigations under `docs/wiki/raw/research/`.
- Wiki pages: maintained markdown under `docs/wiki/`.
- Schema: this file, which defines layout, workflows, and quality standards.
- Treat raw sources as read-only after capture except for redaction or format normalization needed to remove sensitive data.
- Keep `docs/wiki/index.md` as the human-readable catalog of living wiki pages.
- Keep `docs/wiki/log.md` as the append-only chronological audit trail for ingests, queries filed back into the wiki, and lint passes.

### Minimal Viable Wiki Layout

- Start with `docs/wiki/raw/`, `docs/wiki/index.md`, and `docs/wiki/log.md`.
- Add topic pages directly under `docs/wiki/` until volume makes subdirectories worthwhile.
- Create subdirectories only when the page count demands them; sensible future buckets are `concepts/`, `entities/`, `decisions/`, `comparisons/`, and `sessions/`.
- Prefer standard markdown links that render on GitHub. Do not rely on Obsidian-only wikilinks as the primary link format.

### Page Rules

- One durable topic, entity, invariant, workflow, or decision per page.
- Use concise titles and stable filenames; rename only when the page meaning materially changes.
- Cite the source pages, raw sources, or numbered research docs that support the page's claims.
- Record contradictions, caveats, and uncertainty explicitly instead of smoothing them away.
- When useful, add lightweight frontmatter for `kind`, `status`, `last_reviewed`, `sources`, `related`, `supersedes`, or `superseded_by`.
- Use links to related files, passes, proposals, and research docs so the page is navigable without chat history.

### Ingest Rules

- On new source, read it, extract the durable takeaways, and decide whether it belongs as a raw source, a numbered research doc under `docs/wiki/raw/research/`, an update to existing wiki pages, or all three.
- Update the affected wiki pages instead of creating near-duplicate pages for the same concept.
- Add or refresh the relevant entry in `docs/wiki/index.md`.
- Append a dated entry to `docs/wiki/log.md`.
- If the source changes an existing belief, mark the previous claim stale or superseded instead of silently overwriting history.
- If an old numbered doc in `docs/` has become absorbed research rather than active policy or handoff material, move it into `docs/wiki/raw/research/` in the same change.

### Query Rules

- Answer questions from the wiki first, then expand to raw sources and numbered docs when needed.
- Cite the wiki pages and supporting sources used for the answer.
- If a query produces durable knowledge, file it back into the wiki as a page update or a new page in the same change.
- Prefer the output format that matches the question: markdown summary, comparison table, timeline, dependency map, or structured data export.

### Lint Rules

- Periodically scan for contradictions, stale claims, orphan pages, missing backlinks, broken links, duplicate concepts, and data gaps worth researching.
- Auto-fix safe issues in the same pass when the correct repair is obvious.
- Flag unclear conflicts and capture the competing claims plus supporting sources.
- Keep the wiki tending toward health without waiting for a dedicated cleanup sprint.

### Lifecycle Rules

- Not all claims are equally strong; preserve how well-supported a claim is.
- Track confidence using source count, recency, and contradiction status. A simple status ladder such as `working`, `supported`, `strong`, `stale`, or `superseded` is acceptable.
- Newer, better-supported information should weaken or supersede older claims automatically.
- Do not delete useful older knowledge by default; demote or mark it stale unless it is incorrect noise or sensitive material that should not be kept.
- Architecture rules and long-lived invariants decay slowly; transient bugs and one-off observations decay quickly.

### Knowledge Graph Rules

- Go beyond flat prose where it helps: keep typed relationships explicit.
- Common entity types in this repo include proposals, instructions, passes, packages, files, tools, benchmarks, bugs, invariants, and decisions.
- Common relationship types include `uses`, `depends_on`, `contradicts`, `caused`, `fixes`, `supersedes`, `validated_by`, and `measured_by`.
- Pages are for reading; the typed links between them are for navigation, search, and impact analysis.

### Search Rules

- Use `docs/wiki/index.md` as the first catalog at small scale.
- Use repo search tools such as `rg` as the default local retrieval path once the wiki grows.
- If the wiki grows beyond what one index page can support comfortably, add stronger search rather than bloating the index indefinitely.
- Keep the index human-readable even if better search is added later.

### Automation Rules

- Favor event-driven maintenance over manual bookkeeping when tooling exists.
- On new source, update the wiki, index, and log together.
- On session end, crystallize durable findings into pages or numbered docs.
- On schedule, run lint, consolidation, and retention review.
- When adding future tooling, prioritize automation that reduces filing and cross-reference maintenance rather than replacing human curation.

### Quality And Self-Correction Rules

- Score or label content quality based on structure, evidence, consistency, and usefulness.
- Prefer self-healing maintenance: repair links, add missing cross-references, and flag stale claims proactively.
- Resolve contradictions by preferring newer, stronger, better-sourced claims, while preserving the audit trail.
- The wiki should accumulate trust over time, not just accumulate text.

### Collaboration Rules

- The committed wiki is shared project knowledge.
- Personal workflow notes belong in local-only files such as `agent-lost-and-found.md`, not in the committed wiki.
- Use `agent-todo.md` for active execution tracking; use `docs/wiki/` for durable knowledge.
- When multiple sessions touch the wiki, merge changes with timestamped log entries and explicit supersession when claims conflict.

### Privacy And Governance Rules

- Strip secrets, credentials, tokens, and other sensitive material before committing raw sources or wiki pages.
- Keep the log detailed enough to explain what changed and why.
- Make bulk cleanup or consolidation reversible in git and documented in `docs/wiki/log.md`.

### Crystallization Rules

- Completed research, debugging, or design threads are sources too.
- Distill them into durable digests that capture the question, findings, files involved, lessons learned, and follow-up questions.
- Use numbered `docs/wiki/raw/research/` docs when the output is a substantial investigation; use `docs/wiki/` when the result is a living concept or decision page.

### Wasm-Specific Priorities

- Bias toward knowledge that helps future Starshine work: validation behavior, pass contracts, IR invariants, spec edge cases, Binaryen parity findings, performance evidence, and toolchain behavior.
- Prefer pages that answer repeat questions such as "what does this proposal change," "what invariants does this pass rely on," "what breaks when this validation rule is violated," and "how does Starshine differ from Binaryen here."
- Link wiki pages back to numbered docs, tests, and relevant source files so knowledge stays grounded in the codebase.

## References

- Rohit Gupta, `LLM Wiki v2`: <https://gist.github.com/rohitg00/2067ab416f7bbe447c1977edaaa681e2>
- Andrej Karpathy, `LLM Wiki`: <https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f>
