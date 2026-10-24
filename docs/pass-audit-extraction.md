# Pass audit extraction

Source: `origin/codex/pass-audit-red-green-fixes` at `6636026d0`; baseline: `6d020542e`. Each row is reviewed against current master; no whole-branch merge.

| Source | Decision | Evidence |
| --- | --- | --- |
| `7e66ffe75` | SUPERSEDED BY MASTER | Audit-only backlog snapshot; master agent-todo.md already includes the later optimizer rollups and current release blockers; importing the old snapshot would resurrect stale work. |
| `19b8053fb` | EXTRACT | RED native regression returned the unchanged module (missing inserted imports); GREEN focused shared-parity file: 27/27 passed; source: fix: remap shared-object function names after import insertion |
| `102dc8349` | EXTRACT | RED swapped-type assertion failed; GREEN shared-parity file: 28/28 passed; source: fix: remap shared-object type and field names on type swap |
| `c9415221e` | EXTRACT | RED unchanged function lost its local names; GREEN coalesce-locals file: 95/95 passed; source: fix: retain local names for unchanged coalescing functions |
| `222c0fd2f` | EXTRACT | RED both raw-name retention assertions failed; GREEN string-gathering file: 25/25 passed; retain master raw-only decoding when remapping; source: fix: retain gathered raw names when global indices stay fixed |
| `af91ec935` | SUPERSEDED BY MASTER | Master 6f8efd3ad independently restores the ABI boundary and exposes i64-trunc-sat-float-lowering with registry/pipeline/EH tests; retain its canonical name and wiring. |
| `df4b96762` | SUPERSEDED BY MASTER | Master optimize.mbt skip_caught_o4z_preset skips valid caught-try preset entries, flushes explicit passes in order and preserves compiler facts; f60fb9eca tests manager_review_wbtest.mbt cover the stronger contract. |
| `33b60af13` | EXTRACT | RED original constructor scan with work counter: 4160 steps exceeded linear bound; GREEN GTO file passed with direct opcode and validation assertions; source: perf: bound nested GTO constructor operand work |
| `e4a220e83` | EXTRACT | RED instrumented baseline failed the bounded work/unchanged-IR regression; GREEN focused inlining_wbtest.mbt passed; only counters/new helper signatures retained during RED, optimization disabled; source: perf: skip inlining dead-suffix queries without targets |
| `e123aa521` | REDESIGN SKIP | Effects workspace/API redesign conflicts with master f60fb9eca effects_subtree_query.mbt and revision-keyed analysis reuse; retain master MergeBlocks analysis architecture. |
| `9dce22234` | Review pending | perf: check expected remove-unused-brs root index first |
| `794519800` | Review pending | perf: batch DCE detached reference scans |
| `d265b2a43` | Review pending | perf: skip merge-locals graph work without influenced reads |
| `300c6d1f6` | REDESIGN SKIP | Split reviewed: saturation candidate filtering already exists in master 6f8efd3ad; intrinsic worker changes collide with cc9677cee declared-local typing. Leave intrinsic redesign behind. |
| `6589329c3` | ALREADY ON MASTER | Master 6f8efd3ad i64_lower_sat_expr_candidate_types and conditional temporary pushes already allocate only used f32/f64 locals, with narrow-pass tests. |
| `bcc83ebe6` | Review pending | fix: avoid reorder-locals size growth from mixed type runs |
| `eb8193144` | Review pending | fix: scope descriptor field-zero reads to related types |
| `cceefec87` | Review pending | perf: coalesce sparse straight-line locals above dense guard |
| `6733db350` | Review pending | perf: reduce DAE2 raw qualification dispatch cost |
| `36e3016e1` | Review pending | fix: preserve each final invalid-module dump |
| `643d0cba4` | Review pending | fix: keep remove-unused-brs active for trivial tail branches |
| `09feb1dd7` | Review pending | Fix DCE branch caches after detached HOT roots |
| `ed0ffb333` | Review pending | Preserve local names when local CSE appends temps |
| `b0582ddba` | Review pending | Fix DCE traversal of nested value regions |
| `737ec92ca` | Review pending | Preserve typed control entries during DCE rewrites |
| `d5d51ca8f` | Review pending | Use lightweight node counts in DCE |
| `298b07ee4` | Review pending | perf: avoid handles for adjacent shared-object conversions |
| `582decb92` | Review pending | perf: omit unused shared-object handle storage |
| `6636026d0` | Review pending | docs: correct shared-object handle lifetime contract |
