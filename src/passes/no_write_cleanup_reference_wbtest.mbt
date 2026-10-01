///|
// Frozen V76 helper; construction stays inside native timed work.
fn sl_cleanup_nowrite_reference(
  instrs : Array[@lib.Instruction],
  live_after : SlCleanupReadSet,
  child_liveout_contexts? : Array[Int]? = None,
  suffix_root_visits? : Array[Int]? = None,
  future_read_visits? : Array[Int]? = None,
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
  let mut normalized = instrs
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
    let next = match instr {
      @lib.Block(bt, @lib.Expr(body)) => {
        let next_body = sl_cleanup_nowrite_reference(body, child_live_after)
        if physical_equal(next_body, body) {
          instr
        } else {
          @lib.Instruction::block(bt, @lib.Expr::new(next_body))
        }
      }
      @lib.Loop(bt, @lib.Expr(body)) => {
        child_live_after.collect(body)
        let next_body = sl_cleanup_nowrite_reference(body, child_live_after)
        if physical_equal(next_body, body) {
          instr
        } else {
          @lib.Instruction::loop_(bt, @lib.Expr::new(next_body))
        }
      }
      @lib.TryTable(bt, catches, @lib.Expr(body)) => {
        let next_body = sl_cleanup_nowrite_reference(body, child_live_after)
        if physical_equal(next_body, body) {
          instr
        } else {
          @lib.Instruction::try_table(bt, catches, @lib.Expr::new(next_body))
        }
      }
      @lib.If(bt, then_body, else_body) => {
        let next_then = sl_cleanup_nowrite_reference(
          then_body, child_live_after,
        )
        let mut next_else = else_body
        if else_body is Some(body) {
          let next_body = sl_cleanup_nowrite_reference(body, child_live_after)
          if !physical_equal(next_body, body) {
            next_else = Some(next_body)
          }
        }
        if physical_equal(next_then, then_body) &&
          physical_equal(next_else, else_body) {
          instr
        } else {
          @lib.Instruction::if_(bt, next_then, next_else)
        }
      }
      _ => instr
    }
    if !physical_equal(next, instr) {
      if physical_equal(normalized, instrs) {
        normalized = instrs.copy()
      }
      normalized[idx] = next
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
  // Borrow unchanged arrays. All callers treat these results as read-only;
  // allocate an owned output only when a pair is actually changed.
  let mut rewritten : Array[@lib.Instruction]? = None
  let mut cursor = 0
  let mut idx = 0
  let mut future_queries = 0
  let mut first_future_get = -1
  let mut mixed_future_queries = false
  let mut future_read_mask : Array[Bool]? = None
  // Same-local root-get queries have disjoint search intervals: each stops at
  // the next queried get or an earlier terminator/read. Their total is linear.
  // Tees are not reads, so even same-local tee queries need the mixed path.
  while idx < normalized.length() {
    match normalized[idx] {
      @lib.LocalTee(@lib.LocalIdx(raw)) =>
        if idx + 1 < normalized.length() &&
          normalized[idx + 1] == @lib.Instruction::drop() &&
          !live_after.contains(raw.reinterpret_as_int()) &&
          ({
            mixed_future_queries = true
            if future_queries < 8 {
              future_queries += 1
            } else if future_read_mask is None && normalized.length() >= 32 {
              future_read_mask = Some(
                sl_cleanup_build_future_read_mask(
                  normalized, future_read_visits,
                ),
              )
            }
            !sl_cleanup_future_read_query(
              normalized,
              idx,
              idx + 2,
              raw.reinterpret_as_int(),
              future_read_mask,
              future_read_visits,
            )
          }) {
          let out = match rewritten {
            Some(out) => out
            None => {
              let out : Array[@lib.Instruction] = []
              rewritten = Some(out)
              out
            }
          }
          for kept = cursor; kept < idx; kept = kept + 1 {
            out.push(normalized[kept])
          }
          out.push(@lib.Instruction::local_set(@lib.LocalIdx::new(raw)))
          idx += 2
          cursor = idx
        } else {
          idx += 1
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
              ({
                let local = raw.reinterpret_as_int()
                if first_future_get < 0 {
                  first_future_get = local
                } else if first_future_get != local {
                  mixed_future_queries = true
                }
                if future_queries < 8 {
                  future_queries += 1
                } else if mixed_future_queries &&
                  future_read_mask is None &&
                  normalized.length() >= 32 {
                  future_read_mask = Some(
                    sl_cleanup_build_future_read_mask(
                      normalized, future_read_visits,
                    ),
                  )
                }
                !sl_cleanup_future_read_query(
                  normalized,
                  get_idx,
                  get_idx + 1,
                  local,
                  future_read_mask,
                  future_read_visits,
                )
              })
            _ => false
          }
        } else {
          false
        }
        if removable {
          let out = match rewritten {
            Some(out) => out
            None => {
              let out : Array[@lib.Instruction] = []
              rewritten = Some(out)
              out
            }
          }
          for kept = cursor; kept < idx; kept = kept + 1 {
            out.push(normalized[kept])
          }
          if get_idx + 1 >= normalized.length() ||
            normalized[get_idx + 1] != @lib.Instruction::drop() {
            out.push(@lib.Instruction::nop())
          }
          for nop_idx = idx + 1; nop_idx < get_idx; nop_idx = nop_idx + 1 {
            out.push(normalized[nop_idx])
          }
          idx = get_idx + 1
          cursor = idx
        } else {
          idx += 1
        }
      }
      _ => idx += 1
    }
  }
  match rewritten {
    Some(out) => {
      for kept = cursor; kept < normalized.length(); kept = kept + 1 {
        out.push(normalized[kept])
      }
      out
    }
    None => normalized
  }
}
