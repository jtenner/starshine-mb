///|
// Frozen8fb4ebd30 pure suffix flat worker, including unchanged storage reuse.
fn sl_pure_middle_reference_flat(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Int) {
  let rewritten : Array[@lib.Instruction] = []
  let mut cursor = 0
  let mut scan_idx = 0
  let mut rewrite_count = 0
  let mut typed_seed : SlStatementTypeSeed? = None
  let wide_environment = env.locals.length() >= 128
  let mut checked_compound_suffix = false
  while scan_idx < instrs.length() {
    let mut rewritten_here = false
    match instrs[scan_idx] {
      @lib.LocalSet(@lib.LocalIdx(target_raw)) => {
        let compound_suffix = wide_environment &&
          scan_idx > 0 &&
          !run_hot_pipeline_raw_simplify_locals_instr_is_pure_movable_value(
            instrs[scan_idx - 1],
          )
        if compound_suffix &&
          checked_compound_suffix &&
          typed_seed is None &&
          wide_environment {
          typed_seed = Some(SlStatementTypeSeed::new(env))
        }
        let producer_suffix = sl_value_suffix_at_with_seed(
          instrs,
          scan_idx,
          1,
          env,
          typed_seed,
          None,
          None,
        )
        checked_compound_suffix = checked_compound_suffix || compound_suffix
        let producer_start = scan_idx - producer_suffix.length()
        if producer_suffix.length() > 0 &&
          producer_start >= cursor &&
          run_hot_pipeline_raw_simplify_locals_instrs_all_pure_movable_values(
            producer_suffix,
          ) {
          let target_local = target_raw.reinterpret_as_int()
          let source_locals = run_hot_pipeline_raw_simplify_locals_instr_source_locals(
            producer_suffix,
          )
          let producer_is_dupable_copy = producer_suffix.length() == 1 &&
            run_hot_pipeline_raw_simplify_locals_instr_is_dupable_copy_value(
              producer_suffix[0],
            )
          let movable_middle : Array[@lib.Instruction] = []
          let mut sink_idx = scan_idx + 1
          while sink_idx < instrs.length() {
            let statement = sl_statement_at(instrs, sink_idx, env)
            if statement.length() == 0 ||
              statement.any(fn(instr) {
                run_hot_pipeline_raw_simplify_locals_instr_is_structured(instr) ||
                run_hot_pipeline_raw_simplify_locals_instr_is_early_terminator(
                  instr,
                )
              }) ||
              run_hot_pipeline_raw_instrs_have_later_local_read(
                statement, 0, target_local,
              ) ||
              run_hot_pipeline_raw_instrs_have_later_local_write(
                statement, 0, target_local,
              ) ||
              source_locals.any(fn(local_id) {
                run_hot_pipeline_raw_instrs_have_later_local_write(
                  statement, 0, local_id,
                )
              }) {
              break
            }
            let statement_len = statement.length()
            for instr in statement {
              movable_middle.push(instr)
            }
            sink_idx = sink_idx + statement_len
          }
          if movable_middle.length() > 0 && !producer_is_dupable_copy {
            for idx = cursor; idx < producer_start; idx = idx + 1 {
              rewritten.push(instrs[idx])
            }
            for instr in movable_middle {
              rewritten.push(instr)
            }
            for instr in producer_suffix {
              rewritten.push(instr)
            }
            rewritten.push(instrs[scan_idx])
            cursor = sink_idx
            scan_idx = sink_idx
            rewrite_count = rewrite_count + 1
            rewritten_here = true
          }
          if !rewritten_here &&
            movable_middle.length() == 0 &&
            producer_suffix.length() == 1 {
            match
              run_hot_pipeline_raw_simplify_locals_instr_source_local(
                producer_suffix[0],
              ) {
              Some(source_local) => {
                let statement = sl_statement_at(instrs, scan_idx + 1, env)
                if run_hot_pipeline_raw_simplify_locals_statement_is_safe_copy_if_barrier(
                    statement, target_local, source_local,
                  ) {
                  for idx = cursor; idx < producer_start; idx = idx + 1 {
                    rewritten.push(instrs[idx])
                  }
                  for instr in statement {
                    rewritten.push(instr)
                  }
                  for instr in producer_suffix {
                    rewritten.push(instr)
                  }
                  rewritten.push(instrs[scan_idx])
                  cursor = scan_idx + 1 + statement.length()
                  scan_idx = cursor
                  rewrite_count = rewrite_count + 1
                  rewritten_here = true
                }
              }
              None => ()
            }
          }
          if !rewritten_here && producer_is_dupable_copy {
            match
              run_hot_pipeline_raw_simplify_locals_try_rewrite_dupable_copy_terminal_value_suffix(
                instrs,
                target_local,
                producer_suffix[0],
                source_locals,
                env,
                start=scan_idx + 1,
              ) {
              Some((rewritten_terminal, consumed_len)) => {
                for idx = cursor; idx < producer_start; idx = idx + 1 {
                  rewritten.push(instrs[idx])
                }
                for instr in rewritten_terminal {
                  rewritten.push(instr)
                }
                cursor = scan_idx + 1 + consumed_len
                scan_idx = cursor
                rewrite_count = rewrite_count + 1
                rewritten_here = true
              }
              None => ()
            }
          }
          if !rewritten_here && producer_is_dupable_copy {
            match
              run_hot_pipeline_raw_simplify_locals_try_rewrite_dupable_copy_into_next_if_condition(
                instrs,
                target_local,
                producer_suffix[0],
                source_locals,
                start=scan_idx + 1,
              ) {
              Some((rewritten_condition, consumed_len)) => {
                for idx = cursor; idx < producer_start; idx = idx + 1 {
                  rewritten.push(instrs[idx])
                }
                rewritten.push(@lib.Instruction::nop())
                for instr in rewritten_condition {
                  rewritten.push(instr)
                }
                cursor = scan_idx + 1 + consumed_len
                scan_idx = cursor
                rewrite_count = rewrite_count + 1
                rewritten_here = true
              }
              None => ()
            }
          }
          if !rewritten_here && producer_is_dupable_copy {
            let skipped_middle_statements : Array[Array[@lib.Instruction]] = []
            let mut sink_idx = scan_idx + 1
            while sink_idx < instrs.length() && !rewritten_here {
              let statement0 = sl_statement_at(instrs, sink_idx, env)
              let statement = if statement0.length() > 0 {
                statement0
              } else {
                sl_statement_at(instrs, sink_idx, env, allow_escape=true)
              }
              if statement.length() == 0 {
                break
              }
              let statement_end = sink_idx + statement.length()
              let statement_escapes = statement.length() > 0 &&
                run_hot_pipeline_raw_simplify_locals_instr_is_unconditional_terminator(
                  statement[statement.length() - 1],
                )
              if run_hot_pipeline_raw_instrs_have_later_local_write(
                  statement, 0, target_local,
                ) ||
                source_locals.any(fn(local_id) {
                  run_hot_pipeline_raw_instrs_have_later_local_write(
                    statement, 0, local_id,
                  )
                }) {
                break
              }
              let reads_target = run_hot_pipeline_raw_instrs_have_later_local_read(
                statement, 0, target_local,
              )
              if reads_target {
                if statement_escapes ||
                  !run_hot_pipeline_raw_instrs_have_later_local_read_before_next_local_write(
                    instrs, statement_end, target_local,
                  ) {
                  for idx = cursor; idx < producer_start; idx = idx + 1 {
                    rewritten.push(instrs[idx])
                  }
                  rewritten.push(@lib.Instruction::nop())
                  let rewritten_statement = run_hot_pipeline_raw_simplify_locals_rewrite_local_reads_in_body(
                    statement,
                    target_local,
                    producer_suffix[0],
                  )
                  let (rewritten_middle, rewritten_statement, middle_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_dupable_copy_middle_statements_into_statement(
                    skipped_middle_statements, rewritten_statement, instrs, statement_end,
                  )
                  for instr in rewritten_middle {
                    rewritten.push(instr)
                  }
                  for instr in rewritten_statement {
                    rewritten.push(instr)
                  }
                  cursor = statement_end
                  scan_idx = statement_end
                  rewrite_count = rewrite_count + 1 + middle_rewrites
                  rewritten_here = true
                }
                break
              }
              if statement.any(fn(instr) {
                  run_hot_pipeline_raw_simplify_locals_instr_is_structured(
                    instr,
                  ) ||
                  run_hot_pipeline_raw_simplify_locals_instr_is_early_terminator(
                    instr,
                  )
                }) {
                break
              }
              skipped_middle_statements.push(statement)
              sink_idx = statement_end
            }
          }
        }
      }
      _ => ()
    }
    if !rewritten_here {
      scan_idx = scan_idx + 1
    }
  }
  // Unchanged input remains borrowed; no tail copy is needed.
  if rewrite_count == 0 {
    return (instrs, 0)
  }
  for idx = cursor; idx < instrs.length(); idx = idx + 1 {
    rewritten.push(instrs[idx])
  }
  (rewritten, rewrite_count)
}
