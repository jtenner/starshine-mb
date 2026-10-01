///|
#valtype
priv struct SlCleanupFutureReadProbe {
  outcome : Int
  visited : Int
}

///|
fn SlCleanupFutureReadProbe::new(
  outcome : Int,
  visited : Int,
) -> SlCleanupFutureReadProbe {
  { outcome, visited, }
}

///|
// 0 means no read, 1 means a read, -1 means exhausted. Primitive recursion
// credits and value results avoid a mutable heap owner on cheap repeated reads.
fn sl_cleanup_probe_future_read(
  body : Array[@lib.Instruction],
  start : Int,
  local : Int,
  limit : Int,
  visits : Array[Int]?,
) -> SlCleanupFutureReadProbe {
  let mut visited = 0
  for idx = start; idx < body.length(); idx = idx + 1 {
    if visited == limit {
      return SlCleanupFutureReadProbe::new(-1, visited)
    }
    visited += 1
    if visits is Some(visits) {
      visits[0] += 1
    }
    let instr = body[idx]
    if run_hot_pipeline_raw_simplify_locals_instr_is_unconditional_terminator(
        instr,
      ) {
      return SlCleanupFutureReadProbe::new(0, visited)
    }
    let found = match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) =>
        SlCleanupFutureReadProbe::new(
          if raw.reinterpret_as_int() == local {
            1
          } else {
            0
          },
          0,
        )
      @lib.Block(_, @lib.Expr(nested))
      | @lib.Loop(_, @lib.Expr(nested))
      | @lib.TryTable(_, _, @lib.Expr(nested)) =>
        sl_cleanup_probe_future_read(nested, 0, local, limit - visited, visits)
      @lib.If(_, yes, no) => {
        let yes = sl_cleanup_probe_future_read(
          yes,
          0,
          local,
          limit - visited,
          visits,
        )
        if yes.outcome != 0 {
          return SlCleanupFutureReadProbe::new(
            yes.outcome,
            visited + yes.visited,
          )
        }
        match no {
          Some(no) => {
            let no = sl_cleanup_probe_future_read(
              no,
              0,
              local,
              limit - visited - yes.visited,
              visits,
            )
            SlCleanupFutureReadProbe::new(no.outcome, yes.visited + no.visited)
          }
          None => yes
        }
      }
      @lib.Try(_, @lib.Expr(nested), catches, _) => {
        let body = sl_cleanup_probe_future_read(
          nested,
          0,
          local,
          limit - visited,
          visits,
        )
        visited += body.visited
        if body.outcome != 0 {
          return SlCleanupFutureReadProbe::new(body.outcome, visited)
        }
        for catch_ in catches {
          let @lib.Expr(handler) = match catch_ {
            @lib.LegacyCatch(_, expr) | @lib.LegacyCatchAll(expr) => expr
          }
          let found = sl_cleanup_probe_future_read(
            handler,
            0,
            local,
            limit - visited,
            visits,
          )
          visited += found.visited
          if found.outcome != 0 {
            return SlCleanupFutureReadProbe::new(found.outcome, visited)
          }
        }
        SlCleanupFutureReadProbe::new(0, 0)
      }
      _ => SlCleanupFutureReadProbe::new(0, 0)
    }
    visited += found.visited
    if found.outcome != 0 {
      return SlCleanupFutureReadProbe::new(found.outcome, visited)
    }
  }
  SlCleanupFutureReadProbe::new(0, visited)
}

///|
#inline
fn sl_cleanup_future_read_with_visits(
  body : Array[@lib.Instruction],
  start : Int,
  local : Int,
  visits : Array[Int]?,
) -> Bool {
  match visits {
    None =>
      run_hot_pipeline_raw_instrs_have_later_local_read(body, start, local)
    Some(_) =>
      sl_cleanup_probe_future_read(body, start, local, 2147483647, visits).outcome ==
      1
  }
}

///|
// Reachable-prefix union, matching the existing future-read query rather than
// the intentionally broader original-continuation collector. A terminator in
// one body/arm/handler does not stop its sibling or enclosing instruction list.
fn sl_cleanup_collect_reachable_read_instr(
  reads : SlCleanupReadSet,
  instr : @lib.Instruction,
  visits : Array[Int]?,
) -> Unit {
  if visits is Some(visits) {
    visits[0] += 1
  }
  match instr {
    @lib.LocalGet(@lib.LocalIdx(raw)) => reads.insert(raw.reinterpret_as_int())
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) =>
      sl_cleanup_collect_reachable_reads(reads, body, visits)
    @lib.If(_, yes, no) => {
      sl_cleanup_collect_reachable_reads(reads, yes, visits)
      if no is Some(no) {
        sl_cleanup_collect_reachable_reads(reads, no, visits)
      }
    }
    @lib.Try(_, @lib.Expr(body), catches, _) => {
      sl_cleanup_collect_reachable_reads(reads, body, visits)
      for catch_ in catches {
        let @lib.Expr(handler) = match catch_ {
          @lib.LegacyCatch(_, expr) | @lib.LegacyCatchAll(expr) => expr
        }
        sl_cleanup_collect_reachable_reads(reads, handler, visits)
      }
    }
    _ => ()
  }
}

///|
fn sl_cleanup_collect_reachable_reads(
  reads : SlCleanupReadSet,
  body : Array[@lib.Instruction],
  visits : Array[Int]?,
) -> Unit {
  for instr in body {
    if run_hot_pipeline_raw_simplify_locals_instr_is_unconditional_terminator(
        instr,
      ) {
      if visits is Some(visits) {
        visits[0] += 1
      }
      break
    }
    sl_cleanup_collect_reachable_read_instr(reads, instr, visits)
  }
}

///|
fn sl_cleanup_build_future_read_mask(
  body : Array[@lib.Instruction],
  visits : Array[Int]?,
) -> Array[Bool] {
  let mask = Array::make(body.length(), false)
  let mut reads = SlCleanupReadSet::new([])
  for idx = body.length() - 1; idx >= 0; idx = idx - 1 {
    if visits is Some(visits) {
      visits[0] += 1
    }
    let instr = body[idx]
    if run_hot_pipeline_raw_simplify_locals_instr_is_unconditional_terminator(
        instr,
      ) {
      reads = SlCleanupReadSet::new([])
      continue
    }
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) =>
        mask[idx] = reads.contains(raw.reinterpret_as_int())
      _ => ()
    }
    // Publish before inserting this read: facts describe its strict suffix.
    // A queried tee is followed by drop, which cannot add a local read.
    sl_cleanup_collect_reachable_read_instr(reads, instr, visits)
  }
  mask
}

///|
// The read is a root get or a dropped tee; its strict suffix cannot gain a
// local read from the skipped drop. Borrow published facts without a budget
// owner, value-result record or per-query recursion accounting in production.
#inline
fn sl_cleanup_future_read_query(
  body : Array[@lib.Instruction],
  read : Int,
  start : Int,
  local : Int,
  mask : Array[Bool]?,
  visits : Array[Int]?,
) -> Bool {
  match mask {
    Some(mask) => mask[read]
    None => sl_cleanup_future_read_with_visits(body, start, local, visits)
  }
}
