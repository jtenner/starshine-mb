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
fn precompute_global_const(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> @ir.HotConstPayload? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::GlobalGet => ()
    _ => return None
  }
  match ctx.module_ctx {
    Some(module_ctx) =>
      @ir.hot_module_resolve_global_const_init(
        module_ctx,
        @lib.GlobalIdx::new(node.imm0.reinterpret_as_uint()),
      )
    None => None
  }
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
    @ir.HotOp::GlobalGet => None
    _ => None
  }
}

///|
fn precompute_i32_exact_const(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> @lib.I32? {
  match precompute_i32_const(func, node_id) {
    Some(value) => Some(value)
    None =>
      match precompute_global_const(ctx, func, node_id) {
        Some(@ir.HotConstPayload::I32Const(value)) => Some(value)
        _ => None
      }
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
    @ir.HotOp::GlobalGet => None
    _ => None
  }
}

///|
fn precompute_i64_exact_const(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> @lib.I64? {
  match precompute_i64_const(func, node_id) {
    Some(value) => Some(value)
    None =>
      match precompute_global_const(ctx, func, node_id) {
        Some(@ir.HotConstPayload::I64Const(value)) => Some(value)
        _ => None
      }
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
fn precompute_try_fold_global_get(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match precompute_global_const(ctx, func, node_id) {
    Some(payload) => {
      let temp = match payload {
        @ir.HotConstPayload::I32Const(value) =>
          @ir.hot_build_const_i32(func, value)
        @ir.HotConstPayload::I64Const(value) =>
          @ir.hot_build_const_i64(func, value)
        @ir.HotConstPayload::F32Const(value) =>
          @ir.hot_build_const_f32(func, value)
        @ir.HotConstPayload::F64Const(value) =>
          @ir.hot_build_const_f64(func, value)
        @ir.HotConstPayload::RefNullConst(value) =>
          @ir.hot_build_ref_null(func, value)
        @ir.HotConstPayload::StringConst(_) => return false
      }
      let replacement = @ir.hot_node_get(func, temp)
      @ir.hot_delete_node(func, temp)
      @ir.hot_replace_node(func, node_id, replacement)
      pass_mark_mutated(ctx, func)
      true
    }
    None => false
  }
}

///|
fn precompute_try_fold_unary(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  instr : @lib.Instruction,
  operand_id : Int,
) -> Bool {
  match (instr, precompute_i32_exact_const(ctx, func, operand_id)) {
    (@lib.Instruction::I32Eqz, Some(v)) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if v == @lib.I32(0) {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      return true
    }
    _ => ()
  }
  match (instr, precompute_i64_exact_const(ctx, func, operand_id)) {
    (@lib.Instruction::I64Eqz, Some(v)) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if v == @lib.I64(0L) {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
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
  match
    (
      instr,
      precompute_i32_exact_const(ctx, func, lhs_id),
      precompute_i32_exact_const(ctx, func, rhs_id),
    ) {
    (@lib.Instruction::I32Add, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        @lib.I32(
          (lhs.reinterpret_as_uint() + rhs.reinterpret_as_uint()).reinterpret_as_int(),
        ),
      )
      return true
    }
    (@lib.Instruction::I32Sub, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        @lib.I32(
          (lhs.reinterpret_as_uint() - rhs.reinterpret_as_uint()).reinterpret_as_int(),
        ),
      )
      return true
    }
    (@lib.Instruction::I32Mul, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        @lib.I32(
          (lhs.reinterpret_as_uint() * rhs.reinterpret_as_uint()).reinterpret_as_int(),
        ),
      )
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
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        @lib.I32(
          (lhs.reinterpret_as_uint() << shift.reinterpret_as_int()).reinterpret_as_int(),
        ),
      )
      return true
    }
    (@lib.Instruction::I32ShrU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      let shift = rhs.reinterpret_as_uint() & 31U
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        @lib.I32(
          (lhs.reinterpret_as_uint() >> shift.reinterpret_as_int()).reinterpret_as_int(),
        ),
      )
      return true
    }
    (@lib.Instruction::I32ShrS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      let shift = rhs.reinterpret_as_uint() & 31U
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        @lib.I32(lhs >> shift.reinterpret_as_int()),
      )
      return true
    }
    (@lib.Instruction::I32Eq, Some(lhs), Some(rhs)) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs == rhs {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      return true
    }
    (@lib.Instruction::I32Ne, Some(lhs), Some(rhs)) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs != rhs {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      return true
    }
    (@lib.Instruction::I32LtS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs < rhs {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      return true
    }
    (@lib.Instruction::I32LtU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs.reinterpret_as_uint() < rhs.reinterpret_as_uint() {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      return true
    }
    (@lib.Instruction::I32GtS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs > rhs {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      return true
    }
    (@lib.Instruction::I32GtU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs.reinterpret_as_uint() > rhs.reinterpret_as_uint() {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      return true
    }
    (@lib.Instruction::I32LeS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs <= rhs {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      return true
    }
    (@lib.Instruction::I32LeU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs.reinterpret_as_uint() <= rhs.reinterpret_as_uint() {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      return true
    }
    (@lib.Instruction::I32GeS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs >= rhs {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      return true
    }
    (@lib.Instruction::I32GeU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs.reinterpret_as_uint() >= rhs.reinterpret_as_uint() {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      return true
    }
    _ => ()
  }
  match
    (
      instr,
      precompute_i64_exact_const(ctx, func, lhs_id),
      precompute_i64_exact_const(ctx, func, rhs_id),
    ) {
    (@lib.Instruction::I64Add, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i64(
        ctx,
        func,
        node_id,
        @lib.I64(
          (lhs.reinterpret_as_uint64() + rhs.reinterpret_as_uint64()).reinterpret_as_int64(),
        ),
      )
      true
    }
    (@lib.Instruction::I64Sub, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i64(
        ctx,
        func,
        node_id,
        @lib.I64(
          (lhs.reinterpret_as_uint64() - rhs.reinterpret_as_uint64()).reinterpret_as_int64(),
        ),
      )
      true
    }
    (@lib.Instruction::I64Mul, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i64(
        ctx,
        func,
        node_id,
        @lib.I64(
          (lhs.reinterpret_as_uint64() * rhs.reinterpret_as_uint64()).reinterpret_as_int64(),
        ),
      )
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
      precompute_replace_with_const_i64(
        ctx,
        func,
        node_id,
        @lib.I64(
          (lhs.reinterpret_as_uint64() << shift.to_int()).reinterpret_as_int64(),
        ),
      )
      true
    }
    (@lib.Instruction::I64ShrU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      let shift = rhs.reinterpret_as_uint64() & 63UL
      precompute_replace_with_const_i64(
        ctx,
        func,
        node_id,
        @lib.I64(
          (lhs.reinterpret_as_uint64() >> shift.to_int()).reinterpret_as_int64(),
        ),
      )
      true
    }
    (@lib.Instruction::I64ShrS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      let shift = rhs.reinterpret_as_uint64() & 63UL
      precompute_replace_with_const_i64(
        ctx,
        func,
        node_id,
        @lib.I64(lhs >> shift.to_int()),
      )
      true
    }
    (@lib.Instruction::I64Eq, Some(lhs), Some(rhs)) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs == rhs {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      true
    }
    (@lib.Instruction::I64Ne, Some(lhs), Some(rhs)) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs != rhs {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      true
    }
    (@lib.Instruction::I64LtS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs < rhs {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      true
    }
    (@lib.Instruction::I64LtU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs.reinterpret_as_uint64() < rhs.reinterpret_as_uint64() {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      true
    }
    (@lib.Instruction::I64GtS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs > rhs {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      true
    }
    (@lib.Instruction::I64GtU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs.reinterpret_as_uint64() > rhs.reinterpret_as_uint64() {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      true
    }
    (@lib.Instruction::I64LeS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs <= rhs {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      true
    }
    (@lib.Instruction::I64LeU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs.reinterpret_as_uint64() <= rhs.reinterpret_as_uint64() {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      true
    }
    (@lib.Instruction::I64GeS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs >= rhs {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      true
    }
    (@lib.Instruction::I64GeU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      precompute_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs.reinterpret_as_uint64() >= rhs.reinterpret_as_uint64() {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      true
    }
    _ => false
  }
}

///|
fn precompute_try_fold_constant_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If => ()
    _ => return false
  }
  let cond_id = @ir.hot_child_get(func, node_id, 0)
  let take_then = match precompute_i32_exact_const(ctx, func, cond_id) {
    Some(@lib.I32(0)) => false
    Some(@lib.I32(_)) => true
    None => return false
  }
  let chosen_region = if take_then {
    @ir.hot_region_then_ref(func, node_id)
  } else {
    match @ir.hot_region_else_ref(func, node_id) {
      Some(region) => region
      None => {
        let nop = @ir.hot_build_nop(func)
        @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, nop))
        pass_mark_mutated(ctx, func)
        return true
      }
    }
  }
  let root_count = @ir.hot_region_root_count(func, chosen_region)
  if root_count == 0 {
    let nop = @ir.hot_build_nop(func)
    @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, nop))
    pass_mark_mutated(ctx, func)
    return true
  }
  if root_count == 1 {
    @ir.hot_replace_node(
      func,
      node_id,
      @ir.hot_node_get(func, @ir.hot_region_get(func, chosen_region, 0)),
    )
    pass_mark_mutated(ctx, func)
    return true
  }
  let block_type = match
    @ir.hot_type_get(func, @ir.hot_node_type(func, node_id)) {
    @ir.HotTypeInfo::BlockResult(block_type)
    | @ir.HotTypeInfo::BlockResultResolved(block_type, _, _) => Some(block_type)
    _ => None
  }
  let block_type = match block_type {
    Some(block_type) => block_type
    None => return false
  }
  let body : Array[Int] = []
  for i = 0; i < root_count; i = i + 1 {
    body.push(@ir.hot_region_get(func, chosen_region, i))
  }
  let block_id = @ir.hot_build_block(func, block_type, body)
  @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, block_id))
  pass_mark_mutated(ctx, func)
  true
}

///|
fn precompute_is_discardable_value(func : @ir.HotFunc, node_id : Int) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if @ir.hot_has_side_effect(func, node_id) ||
    @ir.hot_may_trap(func, node_id) ||
    @ir.hot_is_control_node(func, node_id) ||
    @ir.hot_is_terminator_node(func, node_id) {
    return false
  }
  if @ir.hot_node_result_arity(func, node_id) == 0 {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const
    | @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc => true
    @ir.HotOp::Unary
    | @ir.HotOp::Binary
    | @ir.HotOp::Compare
    | @ir.HotOp::Convert
    | @ir.HotOp::Select => {
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        if !precompute_is_discardable_value(
            func,
            @ir.hot_child_get(func, node_id, slot),
          ) {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn precompute_try_eliminate_dead_drop(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Drop => ()
    _ => return false
  }
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let value_id = @ir.hot_child_get(func, node_id, 0)
  if !precompute_is_discardable_value(func, value_id) {
    return false
  }
  let nop = @ir.hot_build_nop(func)
  @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, nop))
  pass_mark_mutated(ctx, func)
  true
}

///|
fn precompute_simplify_region_roots(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        changed = precompute_simplify_region_roots(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) ||
          changed
      @ir.HotOp::If => {
        changed = precompute_simplify_region_roots(
            ctx,
            func,
            @ir.hot_region_then_ref(func, node_id),
          ) ||
          changed
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_region) =>
            changed = precompute_simplify_region_roots(ctx, func, else_region) ||
              changed
          None => ()
        }
      }
      @ir.HotOp::Try => {
        changed = precompute_simplify_region_roots(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) ||
          changed
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_region) =>
            changed = precompute_simplify_region_roots(ctx, func, catch_region) ||
              changed
          None => ()
        }
      }
      @ir.HotOp::TryTable => {
        changed = precompute_simplify_region_roots(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) ||
          changed
        changed = precompute_simplify_region_roots(
            ctx,
            func,
            @ir.hot_region_catch_list_ref(func, node_id),
          ) ||
          changed
      }
      _ => ()
    }
    if node_id >= 0 && @ir.hot_node_is_live(func, node_id) {
      match @ir.hot_node_get(func, node_id).op {
        @ir.HotOp::Block | @ir.HotOp::Loop =>
          if region_ref == @ir.HotRegionRef::root() &&
            @ir.hot_node_result_arity(func, node_id) == 0 &&
            precompute_region_is_all_nops(
              func,
              @ir.hot_region_body_ref(func, node_id),
            ) {
            let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [
              @ir.hot_build_nop(func),
            ])
            pass_delete_detached_nodes(ctx, func, removed)
            changed = true
            continue
          } else if region_ref == @ir.HotRegionRef::root() {
            match @ir.hot_node_get(func, node_id).op {
              @ir.HotOp::Block =>
                if precompute_block_is_selector_only_self_targeting_br_table(
                    func, node_id,
                  ) {
                  let removed = pass_splice_region(
                    ctx,
                    func,
                    region_ref,
                    idx,
                    1,
                    [@ir.hot_build_nop(func)],
                  )
                  pass_delete_detached_nodes(ctx, func, removed)
                  changed = true
                  continue
                }
              _ => ()
            }
          }
        @ir.HotOp::Drop =>
          if @ir.hot_child_count(func, node_id) == 1 &&
            precompute_is_discardable_value(
              func,
              @ir.hot_child_get(func, node_id, 0),
            ) {
            let replacement = if region_ref == @ir.HotRegionRef::root() ||
              @ir.hot_region_root_count(func, region_ref) == 1 {
              [@ir.hot_build_nop(func)]
            } else {
              []
            }
            let removed = pass_splice_region(
              ctx, func, region_ref, idx, 1, replacement,
            )
            pass_delete_detached_nodes(ctx, func, removed)
            changed = true
            continue
          }
        @ir.HotOp::If =>
          if @ir.hot_node_result_arity(func, node_id) == 0 {
            let cond_id = @ir.hot_child_get(func, node_id, 0)
            let take_then = match
              precompute_i32_exact_const(ctx, func, cond_id) {
              Some(@lib.I32(0)) => Some(false)
              Some(@lib.I32(_)) => Some(true)
              None => None
            }
            match take_then {
              Some(use_then) => {
                let replacement : Array[Int] = []
                let chosen_region : @ir.HotRegionRef? = if use_then {
                  Some(@ir.hot_region_then_ref(func, node_id))
                } else {
                  @ir.hot_region_else_ref(func, node_id)
                }
                match chosen_region {
                  Some(chosen_region) =>
                    for root_idx = 0
                        root_idx <
                       @ir.hot_region_root_count(func, chosen_region)
                        root_idx = root_idx + 1 {
                      replacement.push(
                        @ir.hot_region_get(func, chosen_region, root_idx),
                      )
                    }
                  None => ()
                }
                if replacement.length() == 0 &&
                  @ir.hot_region_root_count(func, region_ref) == 1 {
                  replacement.push(@ir.hot_build_nop(func))
                }
                let removed = pass_splice_region(
                  ctx, func, region_ref, idx, 1, replacement,
                )
                pass_delete_detached_nodes(ctx, func, removed)
                changed = true
                continue
              }
              None => ()
            }
          }
        _ => ()
      }
    }
    idx += 1
  }
  if changed {
    pass_mark_mutated(ctx, func)
  }
  changed
}

///|
fn precompute_block_is_selector_only_self_targeting_br_table(
  func : @ir.HotFunc,
  block_id : Int,
) -> Bool {
  if @ir.hot_node_result_arity(func, block_id) != 0 {
    return false
  }
  let block_label = @ir.hot_control_node_label(func, block_id)
  if block_label < 0 || @ir.hot_label_branch_arity(func, block_label) != 0 {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  if @ir.hot_region_root_count(func, body_ref) != 1 {
    return false
  }
  let br_table_id = @ir.hot_region_get(func, body_ref, 0)
  match @ir.hot_node_get(func, br_table_id).op {
    @ir.HotOp::BrTable => ()
    _ => return false
  }
  if @ir.hot_child_count(func, br_table_id) != 1 ||
    !precompute_is_discardable_value(
      func,
      @ir.hot_child_get(func, br_table_id, 0),
    ) {
    return false
  }
  if @ir.hot_branch_target(func, br_table_id) != Some(block_label) {
    return false
  }
  for target in @ir.hot_branch_table_targets_for_node(func, br_table_id) {
    if target != block_label {
      return false
    }
  }
  true
}

///|
fn precompute_region_is_all_nops(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Nop => ()
      _ => return false
    }
  }
  true
}

///|
fn precompute_trim_region_nops(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        changed = precompute_trim_region_nops(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) ||
          changed
      @ir.HotOp::If => {
        changed = precompute_trim_region_nops(
            ctx,
            func,
            @ir.hot_region_then_ref(func, node_id),
          ) ||
          changed
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_region) =>
            changed = precompute_trim_region_nops(ctx, func, else_region) ||
              changed
          None => ()
        }
      }
      @ir.HotOp::Try => {
        changed = precompute_trim_region_nops(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) ||
          changed
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_region) =>
            changed = precompute_trim_region_nops(ctx, func, catch_region) ||
              changed
          None => ()
        }
      }
      @ir.HotOp::TryTable => {
        changed = precompute_trim_region_nops(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) ||
          changed
        changed = precompute_trim_region_nops(
            ctx,
            func,
            @ir.hot_region_catch_list_ref(func, node_id),
          ) ||
          changed
      }
      _ => ()
    }
    if idx >= @ir.hot_region_root_count(func, region_ref) {
      break
    }
    if region_ref == @ir.HotRegionRef::root() {
      idx += 1
      continue
    }
    let current_id = @ir.hot_region_get(func, region_ref, idx)
    match @ir.hot_node_get(func, current_id).op {
      @ir.HotOp::Nop => {
        ignore(pass_splice_region(ctx, func, region_ref, idx, 1, []))
        changed = true
        continue
      }
      _ => ()
    }
    idx += 1
  }
  changed
}

///|
fn precompute_coalesce_all_root_nops(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Bool {
  let region_ref = @ir.HotRegionRef::root()
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count <= 1 {
    return false
  }
  for idx = 0; idx < root_count; idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Nop => ()
      _ => return false
    }
  }
  let mut changed = false
  while @ir.hot_region_root_count(func, region_ref) > 1 {
    ignore(pass_splice_region(ctx, func, region_ref, 1, 1, []))
    changed = true
  }
  changed
}

///|
fn precompute_trim_root_nops_before_trailing_const(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Bool {
  let region_ref = @ir.HotRegionRef::root()
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count <= 1 {
    return false
  }
  let tail_id = @ir.hot_region_get(func, region_ref, root_count - 1)
  if tail_id < 0 || !@ir.hot_node_is_live(func, tail_id) {
    return false
  }
  match @ir.hot_node_get(func, tail_id).op {
    @ir.HotOp::Const => ()
    _ => return false
  }
  for idx = 0; idx + 1 < root_count; idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Nop => ()
      _ => return false
    }
  }
  let mut changed = false
  while @ir.hot_region_root_count(func, region_ref) > 1 {
    ignore(pass_splice_region(ctx, func, region_ref, 0, 1, []))
    changed = true
  }
  changed
}

///|
fn precompute_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  let mut changed_any = false
  let mut changed_round = true
  while changed_round {
    changed_round = false
    if precompute_simplify_region_roots(ctx, func, @ir.HotRegionRef::root()) {
      changed_round = true
      changed_any = true
    }
    for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
      if !@ir.hot_node_is_live(func, node_id) {
        continue
      }
      if precompute_try_fold_global_get(ctx, func, node_id) {
        changed_round = true
        changed_any = true
        continue
      }
      if precompute_try_eliminate_dead_drop(ctx, func, node_id) {
        changed_round = true
        changed_any = true
        continue
      }
      if precompute_try_fold_constant_if(ctx, func, node_id) {
        changed_round = true
        changed_any = true
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
    if changed_round &&
      precompute_trim_region_nops(ctx, func, @ir.HotRegionRef::root()) {
      changed_round = true
      changed_any = true
    }
    if precompute_coalesce_all_root_nops(ctx, func) {
      changed_round = true
      changed_any = true
    }
    if precompute_trim_root_nops_before_trailing_const(ctx, func) {
      changed_round = true
      changed_any = true
    }
  }
  if changed_any {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
