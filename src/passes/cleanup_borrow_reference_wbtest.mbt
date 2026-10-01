///|
// Frozen V74 continuation cleanup, including complete legacy read facts.
fn sl_cleanup_borrow_reference(
  instrs : Array[@lib.Instruction],
  live_after : SlCleanupReadSet,
  child_liveout_contexts? : Array[Int]? = None,
  suffix_root_visits? : Array[Int]? = None,
) -> Array[@lib.Instruction] {
  let has_children = instrs.any(fn(instr) {
    match instr {
      @lib.Block(_, _)
      | @lib.Loop(_, _)
      | @lib.TryTable(_, _, _)
      | @lib.If(_, _, _) => true
      _ => false
    }
  })
  let normalized = Array::make(instrs.length(), @lib.Instruction::nop())
  let suffix_reads = if has_children { live_after.copy() } else { live_after }
  // Children use the original continuation's reads. Accumulate those reads
  // once in reverse order, preserving the original instruction order in the
  // output. Flat bodies never need a child continuation set.
  for idx = instrs.length() - 1; idx >= 0; idx = idx - 1 {
    let instr = instrs[idx]
    let child_live_after = match instr {
      @lib.Block(_, _)
      | @lib.Loop(_, _)
      | @lib.TryTable(_, _, _)
      | @lib.If(_, _, _) => {
        match child_liveout_contexts {
          Some(contexts) => contexts[0] += 1
          None => ()
        }
        // A loop also observes reads from its own next iteration. Keep those
        // separate from the continuation inherited by its siblings.
        if instr is @lib.Loop(_, _) {
          suffix_reads.copy()
        } else {
          suffix_reads
        }
      }
      _ => live_after
    }
    normalized[idx] = match instr {
      @lib.Block(bt, @lib.Expr(body)) =>
        @lib.Instruction::block(
          bt,
          @lib.Expr::new(sl_cleanup_borrow_reference(body, child_live_after)),
        )
      @lib.Loop(bt, @lib.Expr(body)) => {
        child_live_after.collect(body)
        @lib.Instruction::loop_(
          bt,
          @lib.Expr::new(sl_cleanup_borrow_reference(body, child_live_after)),
        )
      }
      @lib.TryTable(bt, catches, @lib.Expr(body)) =>
        @lib.Instruction::try_table(
          bt,
          catches,
          @lib.Expr::new(sl_cleanup_borrow_reference(body, child_live_after)),
        )
      @lib.If(bt, then_body, else_body) =>
        @lib.Instruction::if_(
          bt,
          sl_cleanup_borrow_reference(then_body, child_live_after),
          match else_body {
            Some(else_body) =>
              Some(sl_cleanup_borrow_reference(else_body, child_live_after))
            None => None
          },
        )
      _ => instr
    }
    if has_children {
      match suffix_root_visits {
        Some(visits) => visits[0] += 1
        None => ()
      }
      // Use the original subtree even when child cleanup removed a read.
      // The old suffix analysis saw that original read as well.
      suffix_reads.collect_instr(instr)
    }
  }
  let rewritten : Array[@lib.Instruction] = []
  let mut idx = 0
  while idx < normalized.length() {
    match normalized[idx] {
      @lib.LocalTee(@lib.LocalIdx(raw)) =>
        if idx + 1 < normalized.length() &&
          normalized[idx + 1] == @lib.Instruction::drop() &&
          !live_after.contains(raw.reinterpret_as_int()) &&
          !run_hot_pipeline_raw_instrs_have_later_local_read(
            normalized,
            idx + 2,
            raw.reinterpret_as_int(),
          ) {
          rewritten.push(@lib.Instruction::local_set(@lib.LocalIdx::new(raw)))
          idx = idx + 2
        } else {
          rewritten.push(normalized[idx])
          idx = idx + 1
        }
      @lib.LocalSet(@lib.LocalIdx(raw)) => {
        let mut get_idx = idx + 1
        while get_idx < normalized.length() &&
              simplify_locals_cleanup_is_inert_separator(normalized[get_idx]) {
          get_idx = get_idx + 1
        }
        let removable = if get_idx < normalized.length() {
          match normalized[get_idx] {
            @lib.LocalGet(@lib.LocalIdx(next_raw)) =>
              raw == next_raw &&
              !live_after.contains(raw.reinterpret_as_int()) &&
              !run_hot_pipeline_raw_instrs_have_later_local_read(
                normalized,
                get_idx + 1,
                raw.reinterpret_as_int(),
              )
            _ => false
          }
        } else {
          false
        }
        if removable {
          if get_idx + 1 >= normalized.length() ||
            normalized[get_idx + 1] != @lib.Instruction::drop() {
            rewritten.push(@lib.Instruction::nop())
          }
          for nop_idx = idx + 1; nop_idx < get_idx; nop_idx = nop_idx + 1 {
            rewritten.push(normalized[nop_idx])
          }
          idx = get_idx + 1
        } else {
          rewritten.push(normalized[idx])
          idx = idx + 1
        }
      }
      _ => {
        rewritten.push(normalized[idx])
        idx = idx + 1
      }
    }
  }
  rewritten
}
