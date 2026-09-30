// Frozen V50 terminal/condition helpers for the next range experiment.

///|
fn sl_terminal_reference_terminal_value_suffix(
  remaining : Array[@lib.Instruction],
  target_local : Int,
  replacement : @lib.Instruction,
  source_locals : Array[Int],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Int)? {
  let (middle, value_suffix) = run_hot_pipeline_raw_simplify_locals_take_value_suffix(
    remaining, 1, env,
  )
  if value_suffix.length() != 1 {
    return None
  }
  match value_suffix[0] {
    @lib.LocalGet(@lib.LocalIdx(raw)) =>
      if raw.reinterpret_as_int() != target_local {
        None
      } else if middle.any(fn(instr) {
          run_hot_pipeline_raw_simplify_locals_instr_is_structured(instr) ||
          run_hot_pipeline_raw_simplify_locals_instr_is_early_terminator(instr) ||
          run_hot_pipeline_raw_simplify_locals_instr_writes_local(
            instr, target_local,
          ) ||
          source_locals.any(fn(local_id) {
            run_hot_pipeline_raw_simplify_locals_instr_writes_local(
              instr, local_id,
            )
          })
        }) {
        None
      } else {
        let rewritten : Array[@lib.Instruction] = []
        rewritten.push(@lib.Instruction::nop())
        for instr in middle {
          rewritten.push(instr)
        }
        rewritten.push(replacement)
        Some((rewritten, remaining.length()))
      }
    _ => None
  }
}

///|
fn sl_terminal_reference_into_next_if_condition(
  remaining : Array[@lib.Instruction],
  target_local : Int,
  replacement : @lib.Instruction,
  source_locals : Array[Int],
) -> (Array[@lib.Instruction], Int)? {
  let prefix : Array[@lib.Instruction] = []
  let mut idx = 0
  while idx < remaining.length() {
    let instr = remaining[idx]
    if run_hot_pipeline_raw_simplify_locals_instr_writes_local(
        instr, target_local,
      ) ||
      source_locals.any(fn(local_id) {
        run_hot_pipeline_raw_simplify_locals_instr_writes_local(instr, local_id)
      }) {
      return None
    }
    match instr {
      @lib.If(_, _, _) =>
        if run_hot_pipeline_raw_instrs_have_later_local_read(
            prefix, 0, target_local,
          ) &&
          !run_hot_pipeline_raw_instrs_have_later_local_read(
            [instr],
            0,
            target_local,
          ) &&
          !run_hot_pipeline_raw_instrs_have_later_local_write(
            [instr],
            0,
            target_local,
          ) &&
          !source_locals.any(fn(local_id) {
            run_hot_pipeline_raw_instrs_have_later_local_write(
              [instr],
              0,
              local_id,
            )
          }) &&
          !run_hot_pipeline_raw_instrs_have_later_local_read_before_next_local_write(
            remaining,
            idx + 1,
            target_local,
          ) {
          let rewritten : Array[@lib.Instruction] = []
          let rewritten_prefix = run_hot_pipeline_raw_simplify_locals_rewrite_local_reads_in_body(
            prefix, target_local, replacement,
          )
          for prefix_instr in rewritten_prefix {
            rewritten.push(prefix_instr)
          }
          let rewritten_if = run_hot_pipeline_raw_simplify_locals_rewrite_local_reads_in_body(
            [instr],
            target_local,
            replacement,
          )
          for rewritten_instr in rewritten_if {
            rewritten.push(rewritten_instr)
          }
          return Some((rewritten, idx + 1))
        } else {
          return None
        }
      structured =>
        if run_hot_pipeline_raw_simplify_locals_instr_is_structured(structured) ||
          run_hot_pipeline_raw_simplify_locals_instr_is_early_terminator(
            structured,
          ) {
          return None
        } else {
          prefix.push(instr)
          idx = idx + 1
        }
    }
  }
  None
}
