---
kind: decision
status: strong
last_reviewed: 2026-07-18
sources:
  - ../README.md
  - ./tooling/wiki-maintenance-playbook.md
  - ./raw/README.md
  - ./raw/research/README.md
related:
  - ./index.md
  - ./log.md
---

# Numbered Research Archive Closeout

## Decision

On 2026-07-18, all remaining numbered documents under `docs/wiki/raw/research/` were processed into living wiki ownership and removed. The directory keeps only its lifecycle README. Exact historical text remains recoverable from git history; current developer guidance must come from maintained wiki pages, repository source/tests, and retained primary-source captures under the other `docs/wiki/raw/` topic directories.

This was a knowledge-lifecycle cleanup, not a claim that old investigations were unimportant. Deleting the agent-only copies was allowed only after every note had a durable owner and every live reference was repointed or absorbed.

## Processing result

- Numbered notes processed: **1,757**.
- Notes already referenced by living docs, indexes, or the wiki log: **1,752**.
- Previously unreferenced notes explicitly lifted during closeout: **5**.
- Durable owner pages selected after topic-owner corrections: **140**.
- Remaining numbered files in `docs/wiki/raw/research/`: **0**.

Largest absorbed clusters:

| Durable owner | Notes |
| --- | ---: |
| `optimize-instructions` | 466 |
| `heap-store-optimization` | 374 |
| `dae-optimizing` | 138 |
| `code-pushing` | 109 |
| `remove-unused-brs` | 55 |
| `tuple-optimization` | 37 |
| late-pipeline dispatch and generated O4z audit | 25 |
| `local-subtyping` | 18 |
| `precompute` | 16 |
| `reorder-locals` | 13 |

The remaining notes were distributed across pass dossiers, validator/WAST/fuzzing pages, custom-descriptor pages, scheduler/oracle pages, and project-maintenance documentation.

## Durable ownership rule

A deleted note's current answer is the living page that cited or summarized it. During closeout:

1. raw-note source entries were removed or replaced with living owner pages and direct code/upstream evidence;
2. prose links were repointed to the durable owner while retaining the surrounding conclusion;
3. pages that would otherwise lose their only source received a direct repository source;
4. duplicate historical log rows remained readable without pointing at deleted files;
5. five uncited investigations were explicitly absorbed into `pick-load-signs`, late-pipeline dispatch, `de-nan`, OptimizeInstructions tuple localization, and shared-GC/strip-debug guidance.

The resulting wiki intentionally prefers reusable contracts over one-file-per-probe ladders. Per-arity, per-function, and repeated benchmark notes should be summarized as structural invariants, maintained matrices, or explicit reopening criteria.

## Provenance and reversibility

- Git history is the source for exact deleted note text.
- Living pages preserve current conclusions and direct source/test links.
- Retained topic captures under `docs/wiki/raw/binaryen/`, `raw/wasm/`, `raw/validation/`, and sibling directories remain immutable primary-source evidence.
- `docs/wiki/log.md` records the bulk closeout and earlier research chronology.

Do not restore deleted numbered notes merely to recover an old link. Recover the text from git when needed, verify it against current source, and update the living owner page. A genuinely new substantial investigation may still use the numbered research workflow defined by the schema, but it should be absorbed promptly once its durable conclusions stabilize.

## Validation requirements

A complete archive closeout must verify:

- no numbered research files remain;
- no deleted filename or `raw/research/<numbered-note>` link remains in the worktree;
- frontmatter remains valid and every `sources:` list is nonempty;
- all introduced relative links resolve;
- index and log routing remains discoverable;
- any non-documentation changes are limited to citation comments, machine-readable evidence paths, or documentation-contract expectations required by the removal; runtime behavior remains unchanged.
