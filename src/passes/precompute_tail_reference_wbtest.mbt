///|
fn precompute_raw_fold_output_tail_reference(
  out : Array[@lib.Instruction],
  module_ctx? : @ir.HotModuleContext? = None,
  label_arities? : Array[Int?] = [],
) -> Bool {
  if precompute_raw_fold_same_target_br_table_tail(out, label_arities) {
    return true
  }
  if out.length() >= 4 {
    let base = out.length() - 4
    match (out[base], out[base + 1], out[base + 2], out[base + 3]) {
      (
        @lib.I32Const(@lib.I32(0))
        | @lib.I64Const(@lib.I64(0L)),
        @lib.I32Const(@lib.I32(0)),
        @lib.I32Const(@lib.I32(0)),
        @lib.MemoryInit(_, _),
      ) => {
        for _ in 0..<4 {
          ignore(out.pop())
        }
        return true
      }
      _ => ()
    }
  }
  if out.length() >= 12 {
    let base = out.length() - 12
    match
      (
        out[base],
        out[base + 1],
        out[base + 2],
        out[base + 3],
        out[base + 4],
        out[base + 5],
        out[base + 6],
        out[base + 7],
        out[base + 8],
        out[base + 9],
        out[base + 10],
        out[base + 11],
      ) {
      (
        first_value,
        @lib.LocalSet(first_local),
        second_value,
        @lib.LocalSet(second_local),
        @lib.LocalGet(first_compare_get),
        @lib.LocalGet(second_compare_get),
        compare_op,
        @lib.LocalSet(mask_local),
        @lib.LocalGet(first_select_get),
        @lib.LocalGet(second_select_get),
        @lib.LocalGet(mask_get),
        @lib.V128Bitselect,
      ) if first_local == first_compare_get &&
        first_compare_get == second_compare_get &&
        first_local == first_select_get &&
        second_local == second_select_get &&
        mask_local == mask_get &&
        first_local != second_local &&
        first_local != mask_local &&
        second_local != mask_local =>
        match
          precompute_raw_try_fold_binary(first_value, first_value, compare_op) {
          Some(mask) =>
            match
              precompute_raw_try_fold_ternary(
                first_value,
                second_value,
                mask,
                @lib.Instruction::v128_bitselect(),
              ) {
              Some(folded) => {
                for pop_idx = 0; pop_idx < 12; pop_idx = pop_idx + 1 {
                  ignore(pop_idx)
                  ignore(out.pop())
                }
                out.push(first_value)
                out.push(@lib.Instruction::local_set(first_local))
                out.push(second_value)
                out.push(@lib.Instruction::local_set(second_local))
                out.push(mask)
                out.push(@lib.Instruction::local_set(mask_local))
                out.push(folded)
                return true
              }
              None => ()
            }
          None => ()
        }
      _ => ()
    }
  }
  if out.length() >= 7 {
    let base = out.length() - 7
    match
      (
        out[base],
        out[base + 1],
        out[base + 2],
        out[base + 3],
        out[base + 4],
        out[base + 5],
        out[base + 6],
      ) {
      (
        first_value,
        @lib.LocalTee(tee_local),
        second_value,
        @lib.LocalGet(first_get),
        @lib.LocalGet(second_get),
        compare_op,
        @lib.V128Bitselect,
      ) if tee_local == first_get && first_get == second_get =>
        match
          precompute_raw_try_fold_binary(first_value, first_value, compare_op) {
          Some(mask) =>
            match
              precompute_raw_try_fold_ternary(
                first_value,
                second_value,
                mask,
                @lib.Instruction::v128_bitselect(),
              ) {
              Some(folded) => {
                for pop_idx = 0; pop_idx < 7; pop_idx = pop_idx + 1 {
                  ignore(pop_idx)
                  ignore(out.pop())
                }
                out.push(first_value)
                out.push(@lib.Instruction::local_set(tee_local))
                out.push(folded)
                return true
              }
              None => ()
            }
          None => ()
        }
      _ => ()
    }
  }
  if precompute_raw_try_fold_string_slice_tail(out) {
    return true
  }
  if precompute_raw_try_fold_string_new_wtf16_tail(out) {
    return true
  }
  if precompute_raw_try_fold_const_if_tail(out, module_ctx, label_arities) {
    return true
  }
  if precompute_raw_try_partial_select_condition_tail(out) ||
    precompute_raw_try_partial_select_unary_tail(out) ||
    precompute_raw_try_partial_select_tail(out) {
    return true
  }
  if precompute_raw_try_mark_value_tail_after_infinite_loop(out) {
    return true
  }
  if out.length() >= 6 {
    let base = out.length() - 6
    match
      (
        out[base],
        out[base + 1],
        out[base + 2],
        out[base + 3],
        out[base + 4],
        out[base + 5],
      ) {
      (
        @lib.I32Const(_) as scratch_const,
        @lib.LocalSet(scratch_local),
        @lib.LocalGet(accumulator_local),
        @lib.LocalGet(read_scratch),
        @lib.I32Add,
        @lib.LocalTee(final_local) as final_write,
      )
      | (
        @lib.I32Const(_) as scratch_const,
        @lib.LocalSet(scratch_local),
        @lib.LocalGet(accumulator_local),
        @lib.LocalGet(read_scratch),
        @lib.I32Add,
        @lib.LocalSet(final_local) as final_write,
      ) if scratch_local == read_scratch &&
        accumulator_local == final_local &&
        scratch_local != accumulator_local => {
        for _ in 0..<6 {
          ignore(out.pop())
        }
        out.push(@lib.Instruction::local_get(accumulator_local))
        out.push(scratch_const)
        out.push(@lib.Instruction::i32_add())
        out.push(final_write)
        return true
      }
      _ => ()
    }
  }
  if out.length() >= 7 {
    let base = out.length() - 7
    match
      (
        out[base],
        out[base + 1],
        out[base + 2],
        out[base + 3],
        out[base + 4],
        out[base + 5],
        out[base + 6],
      ) {
      (
        @lib.LocalGet(first_get),
        @lib.I32Const(_) as first_const,
        @lib.I32Add,
        @lib.LocalTee(first_tee),
        @lib.I32Const(_) as second_const,
        @lib.I32Add,
        @lib.LocalTee(final_local) as final_write,
      )
      | (
        @lib.LocalGet(first_get),
        @lib.I32Const(_) as first_const,
        @lib.I32Add,
        @lib.LocalTee(first_tee),
        @lib.I32Const(_) as second_const,
        @lib.I32Add,
        @lib.LocalSet(final_local) as final_write,
      ) if first_get == first_tee && first_tee == final_local =>
        match
          precompute_raw_try_fold_binary(
            first_const,
            second_const,
            @lib.Instruction::i32_add(),
          ) {
          Some(folded_const) => {
            for _ in 0..<7 {
              ignore(out.pop())
            }
            out.push(@lib.Instruction::local_get(first_get))
            out.push(folded_const)
            out.push(@lib.Instruction::i32_add())
            out.push(final_write)
            return true
          }
          None => ()
        }
      _ => ()
    }
  }
  if out.length() >= 8 {
    let base = out.length() - 8
    match
      (
        out[base],
        out[base + 1],
        out[base + 2],
        out[base + 3],
        out[base + 4],
        out[base + 5],
        out[base + 6],
        out[base + 7],
      ) {
      (
        @lib.LocalGet(first_get),
        @lib.I32Const(_) as first_const,
        @lib.I32Add,
        @lib.LocalSet(first_set),
        @lib.LocalGet(second_get),
        @lib.I32Const(_) as second_const,
        @lib.I32Add,
        @lib.LocalSet(second_set),
      ) if first_get == first_set &&
        first_set == second_get &&
        second_get == second_set =>
        match
          precompute_raw_try_fold_binary(
            first_const,
            second_const,
            @lib.Instruction::i32_add(),
          ) {
          Some(folded_const) => {
            for _ in 0..<8 {
              ignore(out.pop())
            }
            out.push(@lib.Instruction::local_get(first_get))
            out.push(folded_const)
            out.push(@lib.Instruction::i32_add())
            out.push(@lib.Instruction::local_set(first_set))
            return true
          }
          None => ()
        }
      _ => ()
    }
  }
  if out.length() >= 5 {
    match out[out.length() - 4] {
      @lib.LocalTee(local_idx) =>
        match
          precompute_raw_try_fold_ternary(
            out[out.length() - 5],
            out[out.length() - 3],
            out[out.length() - 2],
            out[out.length() - 1],
          ) {
          Some(folded) => {
            let value = out[out.length() - 5]
            for pop_idx = 0; pop_idx < 5; pop_idx = pop_idx + 1 {
              ignore(pop_idx)
              ignore(out.pop())
            }
            out.push(value)
            out.push(@lib.Instruction::local_set(local_idx))
            out.push(folded)
            return true
          }
          None => ()
        }
      _ => ()
    }
  }
  if out.length() >= 4 {
    match
      precompute_raw_try_fold_ternary(
        out[out.length() - 4],
        out[out.length() - 3],
        out[out.length() - 2],
        out[out.length() - 1],
      ) {
      Some(folded) => {
        for pop_idx = 0; pop_idx < 4; pop_idx = pop_idx + 1 {
          ignore(pop_idx)
          ignore(out.pop())
        }
        out.push(folded)
        return true
      }
      None => ()
    }
  }
  if out.length() >= 2 {
    match (out[out.length() - 2], out[out.length() - 1]) {
      (@lib.I32Const(@lib.I32(value)), @lib.BrIf(label_idx)) => {
        ignore(out.pop())
        ignore(out.pop())
        if value != 0 {
          out.push(@lib.Instruction::br(label_idx))
        }
        return true
      }
      _ => ()
    }
    match out[out.length() - 1] {
      @lib.Drop => {
        match
          precompute_raw_try_void_dropped_result_block(out[out.length() - 2]) {
          Some(rewritten) => {
            ignore(out.pop())
            ignore(out.pop())
            out.push(rewritten)
            return true
          }
          None => ()
        }
        if precompute_raw_instr_is_flat_discardable_value(out[out.length() - 2]) {
          ignore(out.pop())
          ignore(out.pop())
          out.push(@lib.Instruction::nop())
          return true
        }
        if out.length() >= 3 &&
          dae_instr_is_const_safe_float_to_int_unary(
            out[out.length() - 3],
            out[out.length() - 2],
          ) {
          ignore(out.pop())
          ignore(out.pop())
          ignore(out.pop())
          out.push(@lib.Instruction::nop())
          return true
        }
        if out.length() >= 3 &&
          precompute_raw_instr_is_nontrapping_unary_op(out[out.length() - 2]) &&
          precompute_raw_instr_is_flat_discardable_value(out[out.length() - 3]) {
          ignore(out.pop())
          ignore(out.pop())
          ignore(out.pop())
          out.push(@lib.Instruction::nop())
          return true
        }
        if out.length() >= 4 &&
          precompute_raw_instr_is_nontrapping_binary_op(out[out.length() - 2]) &&
          precompute_raw_instr_is_flat_discardable_value(out[out.length() - 3]) &&
          precompute_raw_instr_is_flat_discardable_value(out[out.length() - 4]) {
          ignore(out.pop())
          ignore(out.pop())
          ignore(out.pop())
          ignore(out.pop())
          out.push(@lib.Instruction::nop())
          return true
        }
        if out.length() >= 5 &&
          precompute_raw_instr_is_flat_discardable_value(out[out.length() - 3]) &&
          precompute_raw_instr_is_flat_discardable_value(out[out.length() - 4]) &&
          precompute_raw_instr_is_flat_discardable_value(out[out.length() - 5]) {
          match out[out.length() - 2] {
            @lib.Select(_) => {
              ignore(out.pop())
              ignore(out.pop())
              ignore(out.pop())
              ignore(out.pop())
              ignore(out.pop())
              out.push(@lib.Instruction::nop())
              return true
            }
            _ => ()
          }
        }
      }
      _ => ()
    }
    match
      precompute_raw_try_fold_unary(
        out[out.length() - 2],
        out[out.length() - 1],
      ) {
      Some(folded) => {
        ignore(out.pop())
        ignore(out.pop())
        out.push(folded)
        return true
      }
      None => ()
    }
  }
  if out.length() >= 4 {
    match (out[out.length() - 3], out[out.length() - 2]) {
      (@lib.LocalTee(tee_local), @lib.LocalGet(get_local)) if tee_local ==
        get_local =>
        match
          precompute_raw_try_fold_binary(
            out[out.length() - 4],
            out[out.length() - 4],
            out[out.length() - 1],
          ) {
          Some(folded) => {
            let value = out[out.length() - 4]
            ignore(out.pop())
            ignore(out.pop())
            ignore(out.pop())
            ignore(out.pop())
            out.push(value)
            out.push(@lib.Instruction::local_set(tee_local))
            out.push(folded)
            return true
          }
          None => ()
        }
      _ => ()
    }
  }
  if out.length() >= 5 {
    match (out[out.length() - 4], out[out.length() - 2]) {
      (@lib.LocalTee(first_local), @lib.LocalTee(second_local)) =>
        match
          precompute_raw_try_fold_binary(
            out[out.length() - 5],
            out[out.length() - 3],
            out[out.length() - 1],
          ) {
          Some(folded) => {
            let first_value = out[out.length() - 5]
            let second_value = out[out.length() - 3]
            for i = 0; i < 5; i = i + 1 {
              ignore(i)
              ignore(out.pop())
            }
            out.push(first_value)
            out.push(@lib.Instruction::local_set(first_local))
            out.push(second_value)
            out.push(@lib.Instruction::local_set(second_local))
            out.push(folded)
            return true
          }
          None => ()
        }
      _ => ()
    }
  }
  if out.length() >= 3 {
    match
      (
        precompute_raw_effectful_block_const(out[out.length() - 3]),
        precompute_raw_effectful_block_const(out[out.length() - 2]),
      ) {
      (Some(lhs), Some(rhs)) =>
        match precompute_raw_try_fold_binary(lhs, rhs, out[out.length() - 1]) {
          Some(folded) => {
            let lhs_block = out[out.length() - 3]
            let rhs_block = out[out.length() - 2]
            ignore(out.pop())
            ignore(out.pop())
            ignore(out.pop())
            out.push(lhs_block)
            out.push(@lib.Instruction::drop())
            out.push(rhs_block)
            out.push(@lib.Instruction::drop())
            out.push(folded)
            return true
          }
          None => ()
        }
      _ => ()
    }
  }
  if out.length() >= 3 {
    match out[out.length() - 2] {
      @lib.LocalTee(local_idx) =>
        match
          precompute_raw_try_fold_unary(
            out[out.length() - 3],
            out[out.length() - 1],
          ) {
          Some(folded) => {
            let value = out[out.length() - 3]
            ignore(out.pop())
            ignore(out.pop())
            ignore(out.pop())
            out.push(value)
            out.push(@lib.Instruction::local_set(local_idx))
            out.push(folded)
            return true
          }
          None => ()
        }
      _ => ()
    }
  }
  if out.length() >= 4 {
    match out[out.length() - 3] {
      @lib.LocalTee(local_idx) =>
        match
          precompute_raw_try_fold_binary(
            out[out.length() - 4],
            out[out.length() - 2],
            out[out.length() - 1],
          ) {
          Some(folded) => {
            let value = out[out.length() - 4]
            ignore(out.pop())
            ignore(out.pop())
            ignore(out.pop())
            ignore(out.pop())
            out.push(value)
            out.push(@lib.Instruction::local_set(local_idx))
            out.push(folded)
            return true
          }
          None => ()
        }
      _ => ()
    }
    match out[out.length() - 2] {
      @lib.LocalTee(local_idx) =>
        match
          precompute_raw_try_fold_binary(
            out[out.length() - 4],
            out[out.length() - 3],
            out[out.length() - 1],
          ) {
          Some(folded) => {
            let value = out[out.length() - 3]
            ignore(out.pop())
            ignore(out.pop())
            ignore(out.pop())
            ignore(out.pop())
            out.push(value)
            out.push(@lib.Instruction::local_set(local_idx))
            out.push(folded)
            return true
          }
          None => ()
        }
      _ => ()
    }
  }
  if out.length() >= 3 {
    match
      precompute_raw_try_fold_binary(
        out[out.length() - 3],
        out[out.length() - 2],
        out[out.length() - 1],
      ) {
      Some(folded) => {
        ignore(out.pop())
        ignore(out.pop())
        ignore(out.pop())
        out.push(folded)
        return true
      }
      None => ()
    }
  }
  false
}

///|
fn precompute_root_snapshot_prefix_reference(
  instrs : Array[@lib.Instruction],
) -> Bool {
  let live : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.Nop => ()
      _ => live.push(instr)
    }
  }
  let target = match live {
    [@lib.GlobalGet(target), @lib.LocalTee(_), @lib.GlobalGet(second_read), ..] if second_read ==
      target => target
    _ => return false
  }
  let limit = if live.length() < 16 { live.length() } else { 16 }
  for idx = 3; idx < limit; idx = idx + 1 {
    match live[idx] {
      @lib.GlobalSet(written) if written == target => return true
      _ => ()
    }
  }
  false
}
