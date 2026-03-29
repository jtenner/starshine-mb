///|
pub fn precompute_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("precompute", invalidates=[
    @ir.HotAnalysis::cfg(),
    @ir.HotAnalysis::dominance(),
    @ir.HotAnalysis::liveness(),
    @ir.HotAnalysis::use_def(),
    @ir.HotAnalysis::effects(),
    @ir.HotAnalysis::loop_info(),
    @ir.HotAnalysis::ssa(),
  ])
}

///|
pub fn precompute_summary() -> String {
  "Fold exact constant integer expressions that are trap-free and stable across the top-level precompute slots."
}

///|
fn precompute_i32_const(func : @ir.HotFunc, node_id : Int) -> @lib.I32? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const =>
      match @ir.hot_const_get(func, node.imm0) {
        @ir.HotConstPayload::I32Const(value) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
fn precompute_i64_const(func : @ir.HotFunc, node_id : Int) -> @lib.I64? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const =>
      match @ir.hot_const_get(func, node.imm0) {
        @ir.HotConstPayload::I64Const(value) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
fn precompute_replace_with_const_i32(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  value : @lib.I32,
) -> Unit {
  let temp = @ir.hot_build_const_i32(func, value)
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
}

///|
fn precompute_replace_with_const_i64(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  value : @lib.I64,
) -> Unit {
  let temp = @ir.hot_build_const_i64(func, value)
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
}

///|
fn precompute_try_fold_unary(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  instr : @lib.Instruction,
  operand_id : Int,
) -> Bool {
  match (instr, precompute_i32_const(func, operand_id)) {
    (@lib.Instruction::I32Eqz, Some(v)) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if v == @lib.I32(0) { @lib.I32(1) } else { @lib.I32(0) },
      )
      return true
    }
    _ => ()
  }
  match (instr, precompute_i64_const(func, operand_id)) {
    (@lib.Instruction::I64Eqz, Some(v)) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if v == @lib.I64(0L) { @lib.I32(1) } else { @lib.I32(0) },
      )
      true
    }
    _ => false
  }
}

///|
fn precompute_try_fold_binary(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match (instr, precompute_i32_const(func, lhs_id), precompute_i32_const(func, rhs_id)) {
    (@lib.Instruction::I32Add, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, @lib.I32((lhs.reinterpret_as_uint() + rhs.reinterpret_as_uint()).reinterpret_as_int()))
      return true
    }
    (@lib.Instruction::I32Sub, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, @lib.I32((lhs.reinterpret_as_uint() - rhs.reinterpret_as_uint()).reinterpret_as_int()))
      return true
    }
    (@lib.Instruction::I32Mul, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, @lib.I32((lhs.reinterpret_as_uint() * rhs.reinterpret_as_uint()).reinterpret_as_int()))
      return true
    }
    (@lib.Instruction::I32And, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, @lib.I32(lhs & rhs))
      return true
    }
    (@lib.Instruction::I32Or, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, @lib.I32(lhs | rhs))
      return true
    }
    (@lib.Instruction::I32Xor, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, @lib.I32(lhs ^ rhs))
      return true
    }
    (@lib.Instruction::I32Shl, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      let shift = rhs.reinterpret_as_uint() & 31U
      precompute_replace_with_const_i32(ctx, func, node_id, @lib.I32((lhs.reinterpret_as_uint() << shift.reinterpret_as_int()).reinterpret_as_int()))
      return true
    }
    (@lib.Instruction::I32ShrU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      let shift = rhs.reinterpret_as_uint() & 31U
      precompute_replace_with_const_i32(ctx, func, node_id, @lib.I32((lhs.reinterpret_as_uint() >> shift.reinterpret_as_int()).reinterpret_as_int()))
      return true
    }
    (@lib.Instruction::I32ShrS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      let shift = rhs.reinterpret_as_uint() & 31U
      precompute_replace_with_const_i32(ctx, func, node_id, @lib.I32(lhs >> shift.reinterpret_as_int()))
      return true
    }
    (@lib.Instruction::I32Eq, Some(lhs), Some(rhs)) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs == rhs { @lib.I32(1) } else { @lib.I32(0) })
      return true
    }
    (@lib.Instruction::I32Ne, Some(lhs), Some(rhs)) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs != rhs { @lib.I32(1) } else { @lib.I32(0) })
      return true
    }
    (@lib.Instruction::I32LtS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs < rhs { @lib.I32(1) } else { @lib.I32(0) })
      return true
    }
    (@lib.Instruction::I32LtU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs.reinterpret_as_uint() < rhs.reinterpret_as_uint() { @lib.I32(1) } else { @lib.I32(0) })
      return true
    }
    (@lib.Instruction::I32GtS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs > rhs { @lib.I32(1) } else { @lib.I32(0) })
      return true
    }
    (@lib.Instruction::I32GtU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs.reinterpret_as_uint() > rhs.reinterpret_as_uint() { @lib.I32(1) } else { @lib.I32(0) })
      return true
    }
    (@lib.Instruction::I32LeS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs <= rhs { @lib.I32(1) } else { @lib.I32(0) })
      return true
    }
    (@lib.Instruction::I32LeU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs.reinterpret_as_uint() <= rhs.reinterpret_as_uint() { @lib.I32(1) } else { @lib.I32(0) })
      return true
    }
    (@lib.Instruction::I32GeS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs >= rhs { @lib.I32(1) } else { @lib.I32(0) })
      return true
    }
    (@lib.Instruction::I32GeU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs.reinterpret_as_uint() >= rhs.reinterpret_as_uint() { @lib.I32(1) } else { @lib.I32(0) })
      return true
    }
    _ => ()
  }
  match (instr, precompute_i64_const(func, lhs_id), precompute_i64_const(func, rhs_id)) {
    (@lib.Instruction::I64Add, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i64(ctx, func, node_id, @lib.I64((lhs.reinterpret_as_uint64() + rhs.reinterpret_as_uint64()).reinterpret_as_int64()))
      true
    }
    (@lib.Instruction::I64Sub, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i64(ctx, func, node_id, @lib.I64((lhs.reinterpret_as_uint64() - rhs.reinterpret_as_uint64()).reinterpret_as_int64()))
      true
    }
    (@lib.Instruction::I64Mul, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i64(ctx, func, node_id, @lib.I64((lhs.reinterpret_as_uint64() * rhs.reinterpret_as_uint64()).reinterpret_as_int64()))
      true
    }
    (@lib.Instruction::I64And, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i64(ctx, func, node_id, @lib.I64(lhs & rhs))
      true
    }
    (@lib.Instruction::I64Or, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i64(ctx, func, node_id, @lib.I64(lhs | rhs))
      true
    }
    (@lib.Instruction::I64Xor, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i64(ctx, func, node_id, @lib.I64(lhs ^ rhs))
      true
    }
    (@lib.Instruction::I64Shl, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      let shift = rhs.reinterpret_as_uint64() & 63UL
      precompute_replace_with_const_i64(ctx, func, node_id, @lib.I64((lhs.reinterpret_as_uint64() << shift.to_int()).reinterpret_as_int64()))
      true
    }
    (@lib.Instruction::I64ShrU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      let shift = rhs.reinterpret_as_uint64() & 63UL
      precompute_replace_with_const_i64(ctx, func, node_id, @lib.I64((lhs.reinterpret_as_uint64() >> shift.to_int()).reinterpret_as_int64()))
      true
    }
    (@lib.Instruction::I64ShrS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      let shift = rhs.reinterpret_as_uint64() & 63UL
      precompute_replace_with_const_i64(ctx, func, node_id, @lib.I64(lhs >> shift.to_int()))
      true
    }
    (@lib.Instruction::I64Eq, Some(lhs), Some(rhs)) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs == rhs { @lib.I32(1) } else { @lib.I32(0) })
      true
    }
    (@lib.Instruction::I64Ne, Some(lhs), Some(rhs)) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs != rhs { @lib.I32(1) } else { @lib.I32(0) })
      true
    }
    (@lib.Instruction::I64LtS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs < rhs { @lib.I32(1) } else { @lib.I32(0) })
      true
    }
    (@lib.Instruction::I64LtU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs.reinterpret_as_uint64() < rhs.reinterpret_as_uint64() { @lib.I32(1) } else { @lib.I32(0) })
      true
    }
    (@lib.Instruction::I64GtS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs > rhs { @lib.I32(1) } else { @lib.I32(0) })
      true
    }
    (@lib.Instruction::I64GtU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs.reinterpret_as_uint64() > rhs.reinterpret_as_uint64() { @lib.I32(1) } else { @lib.I32(0) })
      true
    }
    (@lib.Instruction::I64LeS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs <= rhs { @lib.I32(1) } else { @lib.I32(0) })
      true
    }
    (@lib.Instruction::I64LeU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs.reinterpret_as_uint64() <= rhs.reinterpret_as_uint64() { @lib.I32(1) } else { @lib.I32(0) })
      true
    }
    (@lib.Instruction::I64GeS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs >= rhs { @lib.I32(1) } else { @lib.I32(0) })
      true
    }
    (@lib.Instruction::I64GeU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i32(ctx, func, node_id, if lhs.reinterpret_as_uint64() >= rhs.reinterpret_as_uint64() { @lib.I32(1) } else { @lib.I32(0) })
      true
    }
    _ => false
  }
}

///|
fn precompute_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  let mut changed_any = false
  let mut changed_round = true
  while changed_round {
    changed_round = false
    for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
      if !@ir.hot_node_is_live(func, node_id) {
        continue
      }
      let instr = match @ir.hot_node_exact_instr(func, node_id) {
        Some(instr) => instr
        None => continue
      }
      let child_count = @ir.hot_child_count(func, node_id)
      let changed = if child_count == 1 {
        precompute_try_fold_unary(
          ctx,
          func,
          node_id,
          instr,
          @ir.hot_child_get(func, node_id, 0),
        )
      } else if child_count == 2 {
        precompute_try_fold_binary(
          ctx,
          func,
          node_id,
          instr,
          @ir.hot_child_get(func, node_id, 0),
          @ir.hot_child_get(func, node_id, 1),
        )
      } else {
        false
      }
      if changed {
        changed_round = true
        changed_any = true
      }
    }
  }
  if changed_any {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
