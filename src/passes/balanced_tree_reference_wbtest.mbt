// Frozen V51 balanced flat/recursive traversal for exact behavior comparisons.

///|
fn sl_balanced_tree_reference_flat(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Int) {
  let rewritten : Array[@lib.Instruction] = []
  let mut cursor = 0
  let mut scan_idx = 0
  let mut rewrite_count = 0
  while scan_idx < instrs.length() {
    let mut rewritten_here = false
    let target_local = match instrs[scan_idx] {
      @lib.LocalSet(@lib.LocalIdx(raw)) => raw.reinterpret_as_int()
      _ => {
        scan_idx += 1
        continue
      }
    }
    let producer_suffix = sl_value_suffix_at(instrs, scan_idx, 1, env)
    let producer_start = scan_idx - producer_suffix.length()
    if producer_suffix.length() == 0 || producer_start < cursor {
      scan_idx = scan_idx + 1
      continue
    }
    let middle : Array[@lib.Instruction] = []
    let mut statement_start = scan_idx + 1
    while statement_start < instrs.length() {
      let leading_target_get = match instrs[statement_start] {
        @lib.LocalGet(@lib.LocalIdx(raw)) =>
          raw.reinterpret_as_int() == target_local
        _ => false
      }
      if leading_target_get {
        if run_hot_pipeline_raw_instrs_have_later_local_read_before_next_local_write(
            instrs,
            statement_start + 1,
            target_local,
          ) {
          break
        }
        for idx = cursor; idx < scan_idx; idx = idx + 1 {
          rewritten.push(instrs[idx])
        }
        for instr in middle {
          rewritten.push(instr)
        }
        cursor = statement_start + 1
        scan_idx = cursor
        rewrite_count = rewrite_count + 1
        rewritten_here = true
        break
      }
      let statement_end = run_hot_pipeline_raw_simplify_locals_statement_prefix_end(
        instrs,
        env,
        false,
        start=statement_start,
      )
      let statement = Array::makei(statement_end - statement_start, fn(index) {
        instrs[statement_start + index]
      })
      if statement.length() == 0 ||
        statement.any(fn(instr) {
          run_hot_pipeline_raw_simplify_locals_instr_is_structured(instr) ||
          run_hot_pipeline_raw_simplify_locals_instr_is_early_terminator(instr)
        }) {
        break
      }
      let first_reads_target = match statement[0] {
        @lib.LocalGet(@lib.LocalIdx(raw)) =>
          raw.reinterpret_as_int() == target_local
        _ => false
      }
      if first_reads_target {
        let mut statement_conflict = false
        for idx = 1; idx < statement.length(); idx = idx + 1 {
          match statement[idx] {
            @lib.LocalGet(@lib.LocalIdx(raw))
            | @lib.LocalSet(@lib.LocalIdx(raw))
            | @lib.LocalTee(@lib.LocalIdx(raw)) =>
              if raw.reinterpret_as_int() == target_local {
                statement_conflict = true
                break
              }
            _ => ()
          }
        }
        if statement_conflict ||
          run_hot_pipeline_raw_instrs_have_later_local_read_before_next_local_write(
            instrs, statement_end, target_local,
          ) {
          break
        }
        for idx = cursor; idx < scan_idx; idx = idx + 1 {
          rewritten.push(instrs[idx])
        }
        for instr in middle {
          rewritten.push(instr)
        }
        for idx = 1; idx < statement.length(); idx = idx + 1 {
          rewritten.push(statement[idx])
        }
        cursor = statement_end
        scan_idx = cursor
        rewrite_count = rewrite_count + 1
        rewritten_here = true
        break
      }
      if run_hot_pipeline_raw_instrs_have_later_local_read(
          statement, 0, target_local,
        ) ||
        run_hot_pipeline_raw_instrs_have_later_local_write(
          statement, 0, target_local,
        ) {
        break
      }
      for instr in statement {
        middle.push(instr)
      }
      statement_start = statement_end
    }
    if !rewritten_here {
      scan_idx = scan_idx + 1
    }
  }
  for idx = cursor; idx < instrs.length(); idx = idx + 1 {
    rewritten.push(instrs[idx])
  }
  (rewritten, rewrite_count)
}

///|
fn sl_balanced_tree_reference(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Int) {
  let normalized : Array[@lib.Instruction] = []
  let mut rewrite_count = 0
  for instr in instrs {
    match instr {
      @lib.Block(bt, @lib.Expr(body)) => {
        let (next, count) = sl_balanced_tree_reference(body, env)
        rewrite_count += count
        normalized.push(@lib.Instruction::block(bt, @lib.Expr::new(next)))
      }
      @lib.Loop(bt, @lib.Expr(body)) => {
        let (next, count) = sl_balanced_tree_reference(body, env)
        rewrite_count += count
        normalized.push(@lib.Instruction::loop_(bt, @lib.Expr::new(next)))
      }
      @lib.TryTable(bt, catches, @lib.Expr(body)) => {
        let (next, count) = sl_balanced_tree_reference(body, env)
        rewrite_count += count
        normalized.push(
          @lib.Instruction::try_table(bt, catches, @lib.Expr::new(next)),
        )
      }
      @lib.If(bt, then_body, else_body) => {
        let (next_then, then_count) = sl_balanced_tree_reference(then_body, env)
        rewrite_count += then_count
        let next_else = match else_body {
          Some(body) => {
            let (next, count) = sl_balanced_tree_reference(body, env)
            rewrite_count += count
            Some(next)
          }
          None => None
        }
        normalized.push(@lib.Instruction::if_(bt, next_then, next_else))
      }
      _ => normalized.push(instr)
    }
  }
  let (rewritten, flat_count) = sl_balanced_tree_reference_flat(normalized, env)
  (rewritten, rewrite_count + flat_count)
}
