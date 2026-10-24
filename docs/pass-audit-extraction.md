# Pass audit extraction

Source: `origin/codex/pass-audit-red-green-fixes` at `6636026d0`; baseline: `6d020542e`. Each row is reviewed against current master; no whole-branch merge.

| Source | Decision | Evidence |
| --- | --- | --- |
| `7e66ffe75` | Review pending | docs: track October pass audit repairs |
| `19b8053fb` | EXTRACT | RED native regression returned the unchanged module (missing inserted imports); GREEN focused shared-parity file: 27/27 passed; source: fix: remap shared-object function names after import insertion |
| `102dc8349` | Review pending | fix: remap shared-object type and field names on type swap |
| `c9415221e` | Review pending | fix: retain local names for unchanged coalescing functions |
| `222c0fd2f` | Review pending | fix: retain gathered raw names when global indices stay fixed |
| `af91ec935` | Review pending | fix: separate saturating i64 conversion lowering from ABI pass |
| `df4b96762` | Review pending | fix: skip discarded O4z preset work for caught try tables |
| `33b60af13` | Review pending | perf: bound nested GTO constructor operand work |
| `e4a220e83` | Review pending | perf: skip inlining dead-suffix queries without targets |
| `e123aa521` | Review pending | perf: reuse merge-blocks effect masks across prefixes |
| `9dce22234` | Review pending | perf: check expected remove-unused-brs root index first |
| `794519800` | Review pending | perf: batch DCE detached reference scans |
| `d265b2a43` | Review pending | perf: skip merge-locals graph work without influenced reads |
| `300c6d1f6` | Review pending | perf: rewrite only candidate module-pass functions |
| `6589329c3` | Review pending | fix: add only used i64 saturation temporary locals |
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
