///|
// Live locals at a raw branch target. The implicit function label has no
// local live-out: return values are already on the operand stack.
fn ssa_nomerge_raw_label_live(
  labels : Array[@bitset.BitSet],
  label : @lib.LabelIdx,
  local_count : Int,
) -> @bitset.BitSet {
  let @lib.LabelIdx(raw) = label
  let index = labels.length() - 1 - raw.reinterpret_as_int()
  if index >= 0 && index < labels.length() {
    labels[index]
  } else if index == -1 {
    @bitset.BitSet::new(local_count)
  } else {
    abort("ssa-nomerge liveness: branch depth exceeds the function label")
  }
}

///|
fn ssa_nomerge_raw_loop_live(
  body : Array[@lib.Instruction],
  live_after : @bitset.BitSet,
  labels : Array[@bitset.BitSet],
) -> @bitset.BitSet {
  let mut header = @bitset.BitSet::new(live_after.length())
  let nested_labels = labels.copy()
  nested_labels.push(header)
  // The finite, monotone live-in equation includes both the backedge and
  // normal/outer exits. A later iteration can read a different local first.
  while true {
    nested_labels[nested_labels.length() - 1] = header
    let next = ssa_nomerge_raw_live_before(body, 0, live_after, nested_labels)
    if next == header {
      break
    }
    header = next
  }
  header
}

///|
fn ssa_nomerge_raw_live_before(
  instrs : Array[@lib.Instruction],
  start_idx : Int,
  live_after : @bitset.BitSet,
  labels : Array[@bitset.BitSet],
) -> @bitset.BitSet {
  let local_count = live_after.length()
  let mut live = live_after.copy()
  for index = instrs.length() - 1; index >= start_idx; index = index - 1 {
    match instrs[index] {
      @lib.LocalGet(@lib.LocalIdx(raw)) => live[raw.reinterpret_as_int()] = true
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) =>
        live[raw.reinterpret_as_int()] = false
      @lib.Br(label) =>
        live = ssa_nomerge_raw_label_live(labels, label, local_count).copy()
      @lib.BrIf(label)
      | @lib.BrOnNull(label)
      | @lib.BrOnNonNull(label)
      | @lib.BrOnCast(label, _, _, _)
      | @lib.BrOnCastFail(label, _, _, _)
      | @lib.BrOnCastDescEq(label, _, _)
      | @lib.BrOnCastDescEqFail(label, _, _) =>
        live = run_hot_pipeline_raw_bitset_union(
          live,
          ssa_nomerge_raw_label_live(labels, label, local_count),
        )
      @lib.BrTable(targets, fallback) => {
        live = ssa_nomerge_raw_label_live(labels, fallback, local_count).copy()
        for target in targets {
          live = run_hot_pipeline_raw_bitset_union(
            live,
            ssa_nomerge_raw_label_live(labels, target, local_count),
          )
        }
      }
      @lib.Block(_, @lib.Expr(body)) => {
        let nested_labels = labels.copy()
        nested_labels.push(live)
        live = ssa_nomerge_raw_live_before(body, 0, live, nested_labels)
      }
      @lib.If(_, then_body, else_body) => {
        let nested_labels = labels.copy()
        nested_labels.push(live)
        let then_live = ssa_nomerge_raw_live_before(
          then_body, 0, live, nested_labels,
        )
        let else_live = match else_body {
          Some(body) =>
            ssa_nomerge_raw_live_before(body, 0, live, nested_labels)
          None => live
        }
        live = run_hot_pipeline_raw_bitset_union(then_live, else_live)
      }
      @lib.Loop(_, @lib.Expr(body)) =>
        live = ssa_nomerge_raw_loop_live(body, live, labels)
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if run_hot_pipeline_raw_try_table_body_has_exceptional_edge(body) {
          // The raw alias rewriter declines these exception edges. Do not
          // infer dead locals while computing a containing region's inputs.
          live = @bitset.BitSet::make(local_count, true)
        } else {
          let nested_labels = labels.copy()
          nested_labels.push(live)
          live = ssa_nomerge_raw_live_before(body, 0, live, nested_labels)
        }
      @lib.Try(_, _, _, _) => live = @bitset.BitSet::make(local_count, true)
      @lib.Return
      | @lib.ReturnCall(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_)
      | @lib.Throw(_)
      | @lib.ThrowRef
      | @lib.Rethrow(_)
      | @lib.Unreachable => live = @bitset.BitSet::new(local_count)
      _ => ()
    }
  }
  live
}
