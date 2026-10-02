///|
// Frozen main7b9a83c82 suffix storage workers for exact before/after controls.

///|
fn sl_suffix_storage_reference_pure_suffix_local_sets_flat(
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
  for idx = cursor; idx < instrs.length(); idx = idx + 1 {
    rewritten.push(instrs[idx])
  }
  (rewritten, rewrite_count)
}

///|
fn sl_suffix_storage_reference_pure_suffix_local_sets(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Int) {
  let normalized : Array[@lib.Instruction] = []
  let mut rewrite_count = 0
  for instr in instrs {
    match instr {
      @lib.Block(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = sl_suffix_storage_reference_pure_suffix_local_sets(
          body, env,
        )
        normalized.push(
          @lib.Instruction::block(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.Loop(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = sl_suffix_storage_reference_pure_suffix_local_sets(
          body, env,
        )
        normalized.push(
          @lib.Instruction::loop_(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.TryTable(bt, catches, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = sl_suffix_storage_reference_pure_suffix_local_sets(
          body, env,
        )
        normalized.push(
          @lib.Instruction::try_table(
            bt,
            catches,
            @lib.Expr::new(rewritten_body),
          ),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.If(bt, then_body, else_body) => {
        let (rewritten_then, then_rewrites) = sl_suffix_storage_reference_pure_suffix_local_sets(
          then_body, env,
        )
        rewrite_count = rewrite_count + then_rewrites
        let rewritten_else = match else_body {
          Some(else_body) => {
            let (rewritten_else, else_rewrites) = sl_suffix_storage_reference_pure_suffix_local_sets(
              else_body, env,
            )
            rewrite_count = rewrite_count + else_rewrites
            Some(rewritten_else)
          }
          None => None
        }
        normalized.push(
          @lib.Instruction::if_(bt, rewritten_then, rewritten_else),
        )
      }
      _ => normalized.push(instr)
    }
  }
  let (rewritten, flat_rewrites) = sl_suffix_storage_reference_pure_suffix_local_sets_flat(
    normalized, env,
  )
  (rewritten, rewrite_count + flat_rewrites)
}

///|
fn sl_suffix_storage_reference_effectful_suffix_local_gets_flat(
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
          !run_hot_pipeline_raw_simplify_locals_instrs_all_pure_movable_values(
            producer_suffix,
          ) {
          let target_local = target_raw.reinterpret_as_int()
          let source_locals = run_hot_pipeline_raw_simplify_locals_instr_source_locals(
            producer_suffix,
          )
          let written_locals = run_hot_pipeline_raw_simplify_locals_instr_written_locals(
            producer_suffix,
          )
          let pure_prefix : Array[@lib.Instruction] = []
          let mut use_idx = scan_idx + 1
          while use_idx < instrs.length() {
            match instrs[use_idx] {
              @lib.LocalGet(@lib.LocalIdx(read_raw)) =>
                if read_raw.reinterpret_as_int() == target_local {
                  let has_later_read = run_hot_pipeline_raw_instrs_have_later_local_read(
                    instrs,
                    use_idx + 1,
                    target_local,
                  )
                  for idx = cursor; idx < producer_start; idx = idx + 1 {
                    rewritten.push(instrs[idx])
                  }
                  rewritten.push(@lib.Instruction::nop())
                  for instr in pure_prefix {
                    rewritten.push(instr)
                  }
                  for instr in producer_suffix {
                    rewritten.push(instr)
                  }
                  if has_later_read {
                    rewritten.push(
                      @lib.Instruction::local_tee(
                        @lib.LocalIdx::new(target_raw),
                      ),
                    )
                  }
                  cursor = use_idx + 1
                  scan_idx = cursor
                  rewrite_count = rewrite_count + 1
                  rewritten_here = true
                  break
                } else if written_locals.any(fn(local_id) {
                    local_id == read_raw.reinterpret_as_int()
                  }) {
                  break
                } else {
                  pure_prefix.push(instrs[use_idx])
                }
              @lib.Nop => pure_prefix.push(instrs[use_idx])
              @lib.Block(_, @lib.Expr(_))
              | @lib.Loop(_, @lib.Expr(_))
              | @lib.TryTable(_, _, @lib.Expr(_)) =>
                if pure_prefix.all(fn(instr) {
                    match instr {
                      @lib.Nop => true
                      _ => false
                    }
                  }) &&
                  !run_hot_pipeline_raw_instrs_have_later_local_read(
                    instrs,
                    use_idx + 1,
                    target_local,
                  ) &&
                  !run_hot_pipeline_raw_instrs_have_later_local_write(
                    instrs,
                    use_idx + 1,
                    target_local,
                  ) {
                  match
                    run_hot_pipeline_raw_simplify_locals_rewrite_leading_local_get_in_instr(
                      instrs[use_idx],
                      target_local,
                      producer_suffix,
                    ) {
                    Some(rewritten_instr) => {
                      for idx = cursor; idx < producer_start; idx = idx + 1 {
                        rewritten.push(instrs[idx])
                      }
                      rewritten.push(@lib.Instruction::nop())
                      for instr in pure_prefix {
                        rewritten.push(instr)
                      }
                      rewritten.push(rewritten_instr)
                      cursor = use_idx + 1
                      scan_idx = cursor
                      rewrite_count = rewrite_count + 1
                      rewritten_here = true
                      break
                    }
                    None => break
                  }
                } else {
                  break
                }
              @lib.LocalSet(@lib.LocalIdx(barrier_raw)) =>
                if !written_locals.any(fn(local_id) {
                    local_id == barrier_raw.reinterpret_as_int()
                  }) &&
                  run_hot_pipeline_raw_simplify_locals_pure_prefix_can_append_local_set_barrier(
                    pure_prefix,
                    target_local,
                    source_locals,
                    barrier_raw.reinterpret_as_int(),
                    env,
                  ) {
                  pure_prefix.push(instrs[use_idx])
                } else {
                  break
                }
              instr =>
                if run_hot_pipeline_raw_simplify_locals_instr_is_pure_movable_value(
                    instr,
                  ) ||
                  sl_effectful_prefix_can_append_i64_extension(
                    pure_prefix, instr, env,
                  ) {
                  pure_prefix.push(instr)
                } else {
                  break
                }
            }
            if rewritten_here {
              break
            }
            use_idx = use_idx + 1
          }
        }
      }
      _ => ()
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
fn sl_suffix_storage_reference_effectful_suffix_local_gets(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Int) {
  let normalized : Array[@lib.Instruction] = []
  let mut rewrite_count = 0
  for instr in instrs {
    match instr {
      @lib.Block(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = sl_suffix_storage_reference_effectful_suffix_local_gets(
          body, env,
        )
        normalized.push(
          @lib.Instruction::block(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.Loop(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = sl_suffix_storage_reference_effectful_suffix_local_gets(
          body, env,
        )
        normalized.push(
          @lib.Instruction::loop_(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.TryTable(bt, catches, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = sl_suffix_storage_reference_effectful_suffix_local_gets(
          body, env,
        )
        normalized.push(
          @lib.Instruction::try_table(
            bt,
            catches,
            @lib.Expr::new(rewritten_body),
          ),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.If(bt, then_body, else_body) => {
        let (rewritten_then, then_rewrites) = sl_suffix_storage_reference_effectful_suffix_local_gets(
          then_body, env,
        )
        rewrite_count = rewrite_count + then_rewrites
        let rewritten_else = match else_body {
          Some(else_body) => {
            let (rewritten_else, else_rewrites) = sl_suffix_storage_reference_effectful_suffix_local_gets(
              else_body, env,
            )
            rewrite_count = rewrite_count + else_rewrites
            Some(rewritten_else)
          }
          None => None
        }
        normalized.push(
          @lib.Instruction::if_(bt, rewritten_then, rewritten_else),
        )
      }
      _ => normalized.push(instr)
    }
  }
  let (rewritten, flat_rewrites) = sl_suffix_storage_reference_effectful_suffix_local_gets_flat(
    normalized, env,
  )
  (rewritten, rewrite_count + flat_rewrites)
}
