// Frozen pre-range cleanup implementation for native controls.

///|
fn sl_balanced_range_reference(
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
    let producer_prefix : Array[@lib.Instruction] = []
    for idx = 0; idx < scan_idx; idx = idx + 1 {
      producer_prefix.push(instrs[idx])
    }
    let (producer_head, producer_suffix) = sl_balanced_range_reference_suffix(
      producer_prefix, 1, env,
    )
    if producer_suffix.length() == 0 || producer_head.length() < cursor {
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
      let remaining : Array[@lib.Instruction] = []
      for idx = statement_start; idx < instrs.length(); idx = idx + 1 {
        remaining.push(instrs[idx])
      }
      let (statement, _) = sl_balanced_range_reference_prefix(remaining, env)
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
        let statement_end = statement_start + statement.length()
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
      statement_start = statement_start + statement.length()
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
fn sl_balanced_range_reference_suffix(
  instrs : Array[@lib.Instruction],
  count : Int,
  env : @validate.Env,
  typed_instructions? : Array[Int]? = None,
) -> (Array[@lib.Instruction], Array[@lib.Instruction]) {
  if count <= 0 {
    return (instrs.copy(), [])
  }
  let mut required = 0
  let mut net = 0
  let mut known = true
  let mut start = instrs.length() - 1
  while start >= 0 {
    if known {
      match sl_value_suffix_stack_effect(instrs[start], env) {
        Some((inputs, outputs)) => {
          required = Int::max(inputs, required + inputs - outputs)
          net += outputs - inputs
        }
        None => known = false
      }
      if known && (required != 0 || net != count) {
        start -= 1
        continue
      }
    }
    let suffix : Array[@lib.Instruction] = []
    for idx = start; idx < instrs.length(); idx = idx + 1 {
      suffix.push(instrs[idx])
    }
    match typed_instructions {
      Some(visits) => visits[0] += suffix.length()
      None => ()
    }
    let init_state = @validate.make_state(env, [])
    match @validate.Typecheck::typecheck(@lib.Expr::new(suffix), init_state) {
      Ok(state) =>
        if state.reachable &&
          state.escape == @validate.tc_escape_none() &&
          state.stack.length() == count {
          let head : Array[@lib.Instruction] = []
          for idx = 0; idx < start; idx = idx + 1 {
            head.push(instrs[idx])
          }
          return (head, suffix)
        }
      Err(_) => ()
    }
    start = start - 1
  }
  (instrs.copy(), [])
}

///|
fn sl_balanced_range_reference_prefix(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Array[@lib.Instruction]) {
  let end = sl_balanced_range_reference_prefix_end(instrs, env, false)
  if end == 0 {
    return ([], instrs.copy())
  }
  let prefix = Array::makei(end, fn(index) { instrs[index] })
  let tail = Array::makei(instrs.length() - end, fn(index) {
    instrs[end + index]
  })
  (prefix, tail)
}

///|
// Expr typechecking is a left-to-right fold over Instruction. Once a prefix
// fails, extending it cannot repair that earlier error. Keep the state only
// within this scan; no cached result survives an instruction or environment edit.
fn sl_balanced_range_reference_prefix_end(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
  allow_escape : Bool,
  typed_instructions? : Array[Int]? = None,
) -> Int {
  let mut state = @validate.make_state(env, [])
  for index = 0; index < instrs.length(); index = index + 1 {
    match typed_instructions {
      Some(count) => count[0] += 1
      None => ()
    }
    state = match @validate.Typecheck::typecheck(instrs[index], state) {
      Ok(next) => next
      Err(_) => return 0
    }
    let end = index + 1
    let reaches = state.reachable && state.escape == @validate.tc_escape_none()
    let boundary = if allow_escape {
      state.stack.length() == 0 ||
      (end == instrs.length() && reaches && state.stack.length() > 0)
    } else {
      reaches && state.stack.length() == 0
    }
    if boundary {
      return end
    }
  }
  0
}
