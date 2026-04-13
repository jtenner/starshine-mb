# 0086 — Code-pushing standalone `Func 1977` leaf suspicious-wrapper pairs

- Date: 2026-04-13
- Area: `code-pushing`, `hot_lower`
- Status: open frontier note

## Goal

Continue sharpening the standalone `Func 1977` lower/writeback frontier from
[`0084`](./0084-2026-04-13-code-pushing-standalone-func1977-writeback-frontier.md)
and [`0085`](./0085-2026-04-13-code-pushing-standalone-func1977-suspicious-block.md)
by answering one more structural question:

- Is the suspicious lowered shape tied directly to the final reopened
  `LocalSet(45)` / `LocalSet(50)` tail near the end of the function?
- Or does the suspicious-carrier walk actually bottom out somewhere earlier in
  the rewritten decode ladders?

## Method

1. Reused the standalone reconstruction at:
   - `.tmp/codex-tmp/standalone-scan-20260413d/func1977.wat`
2. Replayed `code-pushing` in whitebox mode and lowered the rewritten HOT
   function.
3. Walked the lowered instruction tree recursively with the same structural
   heuristic as `run_hot_pipeline_has_invalid_hard_exit_escape_carrier_block(...)`.
4. Recorded the flagged paths and summarized the subtree shapes at each path.

## Key Finding

The suspicious-carrier walk does **not** bottom out near the final reopened
`LocalSet(45)` / `LocalSet(50)` tail.

Instead, after stripping the enclosing wrapper paths, it bottoms out at two
symmetric leaf wrapper families inside the earlier loop / decode ladders:

- `34/0/0/0/11/else/5/then/2/0/0`
- `34/0/0/0/11/else/5/else/3/then/10/0/0`

These are the two leaf suspicious blocks that matter. The higher paths are just
containing wrappers around them.

## Shared Leaf Shape

Both leaf paths have the same essential lowered shape:

- `block (result i32)`
  - `block (void)` with a long prefix (`len=18` in the probe)
  - trailing carried `local.get`

Inside that `block (void)` prefix, both leaves also contain the same control
pattern:

- a large nested `if`
  - then arm length `29`
  - else arm length `22`
- then arm ends by materializing a small carried result block and storing the
  carried value into a local, then branching to the nearer parent
- else arm stores the alternate value into a different local and branches to a
  deeper parent exit

The two leaves are effectively mirrored copies for the tag-`76` and tag-`77`
decode ladders.

## Why This Matters

This sharpens the frontier again:

- the remaining standalone `Func 1977` issue is **not** centered on the final
  reopened alias-tail move near local `45`
- it is also probably not a one-off single-path anomaly
- instead, it looks like a repeated `hot_lower` wrapper family that occurs twice
  in the earlier decode ladders

That makes a reusable lowering repair more plausible than a bespoke `Func 1977`
exception.

## Practical Next Step

The best next reduction target is now one of these two mirrored leaf families,
not the final `LocalSet(45)` tail.

A good next in-repo repro would model:

- a result block with body `[ block(void prefix-with-hard-exits), local.get ]`
- a nested `if` inside the prefix whose then arm feeds the carried local and
  branches to a nearer parent
- a sibling else arm that feeds an alternate local and branches to a deeper
  parent exit
- trailing roots in the next enclosing result block that consume the carried
  local after the inner wrapper completes
