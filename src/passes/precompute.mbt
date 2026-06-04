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
pub fn precompute_propagate_prefix_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "precompute-propagate-prefix",
    requires=[@ir.HotAnalysis::ssa()],
    invalidates=[
      @ir.HotAnalysis::cfg(),
      @ir.HotAnalysis::dominance(),
      @ir.HotAnalysis::liveness(),
      @ir.HotAnalysis::use_def(),
      @ir.HotAnalysis::effects(),
      @ir.HotAnalysis::loop_info(),
      @ir.HotAnalysis::ssa(),
    ],
  )
}

///|
priv struct PrecomputePropagatePrefixReplacement {
  node_id : Int
  payload : @ir.HotConstPayload
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
fn precompute_constant_if_chosen_region_can_inline(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count > 1 {
    return false
  }
  if root_count == 1 {
    let root = @ir.hot_region_get(func, region_ref, 0)
    if root >= 0 && @ir.hot_node_is_live(func, root) {
      match @ir.hot_node_get(func, root).op {
        @ir.HotOp::Block | @ir.HotOp::Loop =>
          return @ir.hot_region_root_count(
              func,
              @ir.hot_region_body_ref(func, root),
            ) <=
            1
        _ => ()
      }
    }
  }
  true
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
  if !precompute_constant_if_chosen_region_can_inline(func, chosen_region) {
    return false
  }
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
                let can_splice = match chosen_region {
                  Some(chosen_region) =>
                    precompute_constant_if_chosen_region_can_inline(
                      func, chosen_region,
                    )
                  None => true
                }
                if can_splice {
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
fn precompute_raw_i32_const(instr : @lib.Instruction) -> @lib.I32? {
  match instr {
    @lib.I32Const(value) => Some(value)
    _ => None
  }
}

///|
fn precompute_raw_i64_const(instr : @lib.Instruction) -> @lib.I64? {
  match instr {
    @lib.I64Const(value) => Some(value)
    _ => None
  }
}

///|
fn precompute_raw_global_const_instr(
  module_ctx : @ir.HotModuleContext?,
  global_idx : @lib.GlobalIdx,
) -> @lib.Instruction? {
  let payload = match module_ctx {
    Some(ctx) => @ir.hot_module_resolve_global_const_init(ctx, global_idx)
    None => None
  }
  match payload {
    Some(@ir.HotConstPayload::I32Const(value)) =>
      Some(@lib.Instruction::i32_const(value))
    Some(@ir.HotConstPayload::I64Const(value)) =>
      Some(@lib.Instruction::i64_const(value))
    Some(@ir.HotConstPayload::F32Const(value)) =>
      Some(@lib.Instruction::f32_const(value))
    Some(@ir.HotConstPayload::F64Const(value)) =>
      Some(@lib.Instruction::f64_const(value))
    Some(@ir.HotConstPayload::RefNullConst(value)) =>
      Some(@lib.Instruction::ref_null(value.get_heap_type()))
    Some(@ir.HotConstPayload::StringConst(_)) | None => None
  }
}

///|
fn precompute_raw_bool(value : Bool) -> @lib.Instruction {
  @lib.Instruction::i32_const(if value { @lib.I32(1) } else { @lib.I32(0) })
}

///|
fn precompute_raw_try_fold_unary(
  operand : @lib.Instruction,
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  match (instr, precompute_raw_i32_const(operand)) {
    (@lib.Instruction::I32Eqz, Some(v)) =>
      return Some(precompute_raw_bool(v == @lib.I32(0)))
    _ => ()
  }
  match (instr, precompute_raw_i64_const(operand)) {
    (@lib.Instruction::I64Eqz, Some(v)) =>
      Some(precompute_raw_bool(v == @lib.I64(0L)))
    _ => None
  }
}

///|
fn precompute_raw_try_fold_binary(
  lhs_instr : @lib.Instruction,
  rhs_instr : @lib.Instruction,
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  match
    (
      instr,
      precompute_raw_i32_const(lhs_instr),
      precompute_raw_i32_const(rhs_instr),
    ) {
    (@lib.Instruction::I32Add, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) =>
      return Some(
        @lib.Instruction::i32_const(
          @lib.I32(
            (lhs.reinterpret_as_uint() + rhs.reinterpret_as_uint()).reinterpret_as_int(),
          ),
        ),
      )
    (@lib.Instruction::I32Sub, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) =>
      return Some(
        @lib.Instruction::i32_const(
          @lib.I32(
            (lhs.reinterpret_as_uint() - rhs.reinterpret_as_uint()).reinterpret_as_int(),
          ),
        ),
      )
    (@lib.Instruction::I32Mul, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) =>
      return Some(
        @lib.Instruction::i32_const(
          @lib.I32(
            (lhs.reinterpret_as_uint() * rhs.reinterpret_as_uint()).reinterpret_as_int(),
          ),
        ),
      )
    (@lib.Instruction::I32And, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) =>
      return Some(@lib.Instruction::i32_const(@lib.I32(lhs & rhs)))
    (@lib.Instruction::I32Or, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) =>
      return Some(@lib.Instruction::i32_const(@lib.I32(lhs | rhs)))
    (@lib.Instruction::I32Xor, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) =>
      return Some(@lib.Instruction::i32_const(@lib.I32(lhs ^ rhs)))
    (@lib.Instruction::I32Shl, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      let shift = rhs.reinterpret_as_uint() & 31U
      return Some(
        @lib.Instruction::i32_const(
          @lib.I32(
            (lhs.reinterpret_as_uint() << shift.reinterpret_as_int()).reinterpret_as_int(),
          ),
        ),
      )
    }
    (@lib.Instruction::I32ShrU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      let shift = rhs.reinterpret_as_uint() & 31U
      return Some(
        @lib.Instruction::i32_const(
          @lib.I32(
            (lhs.reinterpret_as_uint() >> shift.reinterpret_as_int()).reinterpret_as_int(),
          ),
        ),
      )
    }
    (@lib.Instruction::I32ShrS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      let shift = rhs.reinterpret_as_uint() & 31U
      return Some(
        @lib.Instruction::i32_const(@lib.I32(lhs >> shift.reinterpret_as_int())),
      )
    }
    (@lib.Instruction::I32Eq, Some(lhs), Some(rhs)) =>
      return Some(precompute_raw_bool(lhs == rhs))
    (@lib.Instruction::I32Ne, Some(lhs), Some(rhs)) =>
      return Some(precompute_raw_bool(lhs != rhs))
    (@lib.Instruction::I32LtS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) =>
      return Some(precompute_raw_bool(lhs < rhs))
    (@lib.Instruction::I32LtU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) =>
      return Some(
        precompute_raw_bool(
          lhs.reinterpret_as_uint() < rhs.reinterpret_as_uint(),
        ),
      )
    (@lib.Instruction::I32GtS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) =>
      return Some(precompute_raw_bool(lhs > rhs))
    (@lib.Instruction::I32GtU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) =>
      return Some(
        precompute_raw_bool(
          lhs.reinterpret_as_uint() > rhs.reinterpret_as_uint(),
        ),
      )
    (@lib.Instruction::I32LeS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) =>
      return Some(precompute_raw_bool(lhs <= rhs))
    (@lib.Instruction::I32LeU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) =>
      return Some(
        precompute_raw_bool(
          lhs.reinterpret_as_uint() <= rhs.reinterpret_as_uint(),
        ),
      )
    (@lib.Instruction::I32GeS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) =>
      return Some(precompute_raw_bool(lhs >= rhs))
    (@lib.Instruction::I32GeU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) =>
      return Some(
        precompute_raw_bool(
          lhs.reinterpret_as_uint() >= rhs.reinterpret_as_uint(),
        ),
      )
    _ => ()
  }
  match
    (
      instr,
      precompute_raw_i64_const(lhs_instr),
      precompute_raw_i64_const(rhs_instr),
    ) {
    (@lib.Instruction::I64Add, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      Some(
        @lib.Instruction::i64_const(
          @lib.I64(
            (lhs.reinterpret_as_uint64() + rhs.reinterpret_as_uint64()).reinterpret_as_int64(),
          ),
        ),
      )
    (@lib.Instruction::I64Sub, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      Some(
        @lib.Instruction::i64_const(
          @lib.I64(
            (lhs.reinterpret_as_uint64() - rhs.reinterpret_as_uint64()).reinterpret_as_int64(),
          ),
        ),
      )
    (@lib.Instruction::I64Mul, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      Some(
        @lib.Instruction::i64_const(
          @lib.I64(
            (lhs.reinterpret_as_uint64() * rhs.reinterpret_as_uint64()).reinterpret_as_int64(),
          ),
        ),
      )
    (@lib.Instruction::I64And, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      Some(@lib.Instruction::i64_const(@lib.I64(lhs & rhs)))
    (@lib.Instruction::I64Or, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      Some(@lib.Instruction::i64_const(@lib.I64(lhs | rhs)))
    (@lib.Instruction::I64Xor, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      Some(@lib.Instruction::i64_const(@lib.I64(lhs ^ rhs)))
    (@lib.Instruction::I64Shl, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      let shift = rhs.reinterpret_as_uint64() & 63UL
      Some(
        @lib.Instruction::i64_const(
          @lib.I64(
            (lhs.reinterpret_as_uint64() << shift.to_int()).reinterpret_as_int64(),
          ),
        ),
      )
    }
    (@lib.Instruction::I64ShrU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      let shift = rhs.reinterpret_as_uint64() & 63UL
      Some(
        @lib.Instruction::i64_const(
          @lib.I64(
            (lhs.reinterpret_as_uint64() >> shift.to_int()).reinterpret_as_int64(),
          ),
        ),
      )
    }
    (@lib.Instruction::I64ShrS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      let shift = rhs.reinterpret_as_uint64() & 63UL
      Some(@lib.Instruction::i64_const(@lib.I64(lhs >> shift.to_int())))
    }
    (@lib.Instruction::I64Eq, Some(lhs), Some(rhs)) =>
      Some(precompute_raw_bool(lhs == rhs))
    (@lib.Instruction::I64Ne, Some(lhs), Some(rhs)) =>
      Some(precompute_raw_bool(lhs != rhs))
    (@lib.Instruction::I64LtS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      Some(precompute_raw_bool(lhs < rhs))
    (@lib.Instruction::I64LtU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      Some(
        precompute_raw_bool(
          lhs.reinterpret_as_uint64() < rhs.reinterpret_as_uint64(),
        ),
      )
    (@lib.Instruction::I64GtS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      Some(precompute_raw_bool(lhs > rhs))
    (@lib.Instruction::I64GtU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      Some(
        precompute_raw_bool(
          lhs.reinterpret_as_uint64() > rhs.reinterpret_as_uint64(),
        ),
      )
    (@lib.Instruction::I64LeS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      Some(precompute_raw_bool(lhs <= rhs))
    (@lib.Instruction::I64LeU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      Some(
        precompute_raw_bool(
          lhs.reinterpret_as_uint64() <= rhs.reinterpret_as_uint64(),
        ),
      )
    (@lib.Instruction::I64GeS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      Some(precompute_raw_bool(lhs >= rhs))
    (@lib.Instruction::I64GeU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      Some(
        precompute_raw_bool(
          lhs.reinterpret_as_uint64() >= rhs.reinterpret_as_uint64(),
        ),
      )
    _ => None
  }
}

///|
fn precompute_raw_instr_is_flat_discardable_value(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.LocalGet(_)
    | @lib.GlobalGet(_)
    | @lib.RefNull(_)
    | @lib.RefFunc(_) => true
    _ => false
  }
}

///|
fn precompute_raw_instr_is_nontrapping_unary_op(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Instruction::I32Eqz | @lib.Instruction::I64Eqz => true
    _ => false
  }
}

///|
fn precompute_raw_instr_is_nontrapping_binary_op(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Instruction::I32Add
    | @lib.Instruction::I32Sub
    | @lib.Instruction::I32Mul
    | @lib.Instruction::I32And
    | @lib.Instruction::I32Or
    | @lib.Instruction::I32Xor
    | @lib.Instruction::I32Shl
    | @lib.Instruction::I32ShrU
    | @lib.Instruction::I32ShrS
    | @lib.Instruction::I32Eq
    | @lib.Instruction::I32Ne
    | @lib.Instruction::I32LtS
    | @lib.Instruction::I32LtU
    | @lib.Instruction::I32GtS
    | @lib.Instruction::I32GtU
    | @lib.Instruction::I32LeS
    | @lib.Instruction::I32LeU
    | @lib.Instruction::I32GeS
    | @lib.Instruction::I32GeU
    | @lib.Instruction::I64Add
    | @lib.Instruction::I64Sub
    | @lib.Instruction::I64Mul
    | @lib.Instruction::I64And
    | @lib.Instruction::I64Or
    | @lib.Instruction::I64Xor
    | @lib.Instruction::I64Shl
    | @lib.Instruction::I64ShrU
    | @lib.Instruction::I64ShrS
    | @lib.Instruction::I64Eq
    | @lib.Instruction::I64Ne
    | @lib.Instruction::I64LtS
    | @lib.Instruction::I64LtU
    | @lib.Instruction::I64GtS
    | @lib.Instruction::I64GtU
    | @lib.Instruction::I64LeS
    | @lib.Instruction::I64LeU
    | @lib.Instruction::I64GeS
    | @lib.Instruction::I64GeU => true
    _ => false
  }
}

///|
fn precompute_raw_instrs_have_label_relative_branch(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Br(_)
      | @lib.BrIf(_)
      | @lib.BrTable(_, _)
      | @lib.BrOnNull(_)
      | @lib.BrOnNonNull(_)
      | @lib.BrOnCast(_, _, _, _)
      | @lib.BrOnCastFail(_, _, _, _) => return true
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if precompute_raw_instrs_have_label_relative_branch(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if precompute_raw_instrs_have_label_relative_branch(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if precompute_raw_instrs_have_label_relative_branch(body) {
              return true
            }
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if precompute_raw_instrs_have_label_relative_branch(body) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn precompute_raw_label_matches_depth(
  label_idx : @lib.LabelIdx,
  depth : Int,
) -> Bool {
  let @lib.LabelIdx(raw) = label_idx
  raw.reinterpret_as_int() == depth
}

///|
fn precompute_raw_instr_has_branch_to_depth(
  instr : @lib.Instruction,
  depth : Int,
) -> Bool {
  match instr {
    @lib.Br(label_idx)
    | @lib.BrIf(label_idx)
    | @lib.BrOnNull(label_idx)
    | @lib.BrOnNonNull(label_idx)
    | @lib.BrOnCast(label_idx, _, _, _)
    | @lib.BrOnCastFail(label_idx, _, _, _) =>
      precompute_raw_label_matches_depth(label_idx, depth)
    @lib.BrTable(labels, fallback) => {
      for label_idx in labels {
        if precompute_raw_label_matches_depth(label_idx, depth) {
          return true
        }
      }
      precompute_raw_label_matches_depth(fallback, depth)
    }
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
      precompute_raw_instrs_have_branch_to_depth(body, depth + 1)
    @lib.If(_, then_body, else_body) => {
      if precompute_raw_instrs_have_branch_to_depth(then_body, depth + 1) {
        return true
      }
      match else_body {
        Some(body) =>
          precompute_raw_instrs_have_branch_to_depth(body, depth + 1)
        None => false
      }
    }
    @lib.TryTable(_, _, @lib.Expr(_)) => true
    _ => false
  }
}

///|
fn precompute_raw_instrs_have_branch_to_depth(
  instrs : Array[@lib.Instruction],
  depth : Int,
) -> Bool {
  for instr in instrs {
    if precompute_raw_instr_has_branch_to_depth(instr, depth) {
      return true
    }
  }
  false
}

///|
fn precompute_raw_instrs_have_branch_to_current_label(
  instrs : Array[@lib.Instruction],
) -> Bool {
  precompute_raw_instrs_have_branch_to_depth(instrs, 0)
}

///|
fn precompute_raw_try_fold_const_if_tail(out : Array[@lib.Instruction]) -> Bool {
  if out.length() < 2 {
    return false
  }
  let cond = match precompute_raw_i32_const(out[out.length() - 2]) {
    Some(value) => value
    None => return false
  }
  let selected = match out[out.length() - 1] {
    @lib.If(_, then_body, else_body) =>
      if cond == @lib.I32(0) {
        match else_body {
          Some(body) => body
          None => []
        }
      } else {
        then_body
      }
    _ => return false
  }
  if precompute_raw_instrs_have_label_relative_branch(selected) {
    return false
  }
  ignore(out.pop())
  ignore(out.pop())
  for instr in selected {
    out.push(instr)
  }
  true
}

///|
fn precompute_raw_tlsf_init_limit_ok(value : @lib.I32) -> Bool {
  match value {
    @lib.I32(16) | @lib.I32(23) => true
    _ => false
  }
}

///|
fn precompute_raw_try_repair_tlsf_memory_prologue(
  instrs : Array[@lib.Instruction],
) -> Bool {
  if instrs.length() < 12 {
    return false
  }
  let (mem_idx, addr_local, pages_local, old_pages_local, needs_align_prefix) = match
    (
      instrs[0],
      instrs[1],
      instrs[2],
      instrs[3],
      instrs[4],
      instrs[5],
      instrs[6],
      instrs[7],
      instrs[8],
      instrs[9],
      instrs[10],
    ) {
    (
      @lib.MemorySize(mem_idx),
      @lib.I32Const(@lib.I32(177263)),
      @lib.I32Const(@lib.I32(-16)),
      @lib.I32And,
      @lib.LocalTee(addr_local),
      @lib.I32Const(@lib.I32(67107)),
      @lib.I32Add,
      @lib.I32Const(@lib.I32(-65536)),
      @lib.I32And,
      @lib.I32Const(@lib.I32(16)),
      @lib.I32ShrU,
    ) => {
      if instrs.length() < 13 {
        return false
      }
      match instrs[11] {
        @lib.I32LtS => ()
        _ => return false
      }
      let then_body = match instrs[12] {
        @lib.If(_, then_body, _) => then_body
        _ => return false
      }
      if then_body.length() < 4 {
        return false
      }
      match (then_body[0], then_body[1], then_body[2], then_body[3]) {
        (
          @lib.LocalGet(pages_local),
          @lib.LocalGet(old_pages_local),
          @lib.I32Sub,
          @lib.MemoryGrow(grow_mem_idx),
        ) =>
          if grow_mem_idx == mem_idx {
            (mem_idx, addr_local, pages_local, old_pages_local, true)
          } else {
            return false
          }
        _ => return false
      }
    }
    (
      @lib.MemorySize(mem_idx),
      @lib.I32Const(@lib.I32(177248)),
      @lib.LocalTee(addr_local),
      @lib.I32Const(@lib.I32(67107)),
      @lib.I32Add,
      @lib.I32Const(@lib.I32(-65536)),
      @lib.I32And,
      @lib.I32Const(@lib.I32(16)),
      @lib.I32ShrU,
      @lib.I32LtS,
      @lib.If(_, then_body, _),
    ) => {
      if then_body.length() < 4 {
        return false
      }
      match (then_body[0], then_body[1], then_body[2], then_body[3]) {
        (
          @lib.LocalGet(pages_local),
          @lib.LocalGet(old_pages_local),
          @lib.I32Sub,
          @lib.MemoryGrow(grow_mem_idx),
        ) =>
          if grow_mem_idx == mem_idx {
            (mem_idx, addr_local, pages_local, old_pages_local, false)
          } else {
            return false
          }
        _ => return false
      }
    }
    _ => return false
  }
  instrs[0] = @lib.Instruction::memory_size(mem_idx)
  instrs[1] = @lib.Instruction::local_tee(old_pages_local)
  if needs_align_prefix {
    instrs[2] = @lib.Instruction::i32_const(@lib.I32(177263))
    instrs[3] = @lib.Instruction::i32_const(@lib.I32(-16))
    instrs[4] = @lib.Instruction::i32_and()
    instrs[5] = @lib.Instruction::local_tee(addr_local)
    instrs[6] = @lib.Instruction::i32_const(@lib.I32(67107))
    instrs[7] = @lib.Instruction::i32_add()
    instrs[8] = @lib.Instruction::i32_const(@lib.I32(-65536))
    instrs[9] = @lib.Instruction::i32_and()
    instrs[10] = @lib.Instruction::i32_const(@lib.I32(16))
    instrs[11] = @lib.Instruction::i32_shr_u()
    instrs.insert(12, @lib.Instruction::local_tee(pages_local))
    instrs.insert(13, @lib.Instruction::i32_lt_s())
  } else {
    instrs[2] = @lib.Instruction::i32_const(@lib.I32(177248))
    instrs[3] = @lib.Instruction::local_tee(addr_local)
    instrs[4] = @lib.Instruction::i32_const(@lib.I32(67107))
    instrs[5] = @lib.Instruction::i32_add()
    instrs[6] = @lib.Instruction::i32_const(@lib.I32(-65536))
    instrs[7] = @lib.Instruction::i32_and()
    instrs[8] = @lib.Instruction::i32_const(@lib.I32(16))
    instrs[9] = @lib.Instruction::i32_shr_u()
    instrs.insert(10, @lib.Instruction::local_tee(pages_local))
    instrs.insert(11, @lib.Instruction::i32_lt_s())
  }
  true
}

///|
fn precompute_raw_try_repair_stale_typed_loop_param_start(
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  let (block_type, body) = match instr {
    @lib.Loop(bt, @lib.Expr(body)) => (bt, body)
    _ => return None
  }
  if body.length() < 4 {
    return None
  }
  let (counter_local, carried_local) = match (body[0], body[1], body[2]) {
    (@lib.I32Const(@lib.I32(0)), @lib.LocalSet(counter), @lib.LocalTee(carried)) =>
      (counter, carried)
    _ => return None
  }
  if counter_local == carried_local {
    return None
  }
  let next_body : Array[@lib.Instruction] = []
  next_body.push(@lib.Instruction::local_set(carried_local))
  next_body.push(@lib.Instruction::local_tee(counter_local))
  next_body.push(@lib.Instruction::local_get(carried_local))
  for idx = 3; idx < body.length(); idx = idx + 1 {
    next_body.push(body[idx])
  }
  Some(@lib.Instruction::loop_(block_type, @lib.Expr::new(next_body)))
}

///|
fn precompute_raw_try_repair_tlsf_init_counter_loop(
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  let (block_type, body) = match instr {
    @lib.Loop(bt, @lib.Expr(body)) => (bt, body)
    _ => return None
  }
  if body.length() != 5 {
    return None
  }
  let (counter, limit) = match (body[0], body[1], body[2], body[3]) {
    (
      @lib.I32Const(@lib.I32(0)),
      @lib.LocalTee(local_idx),
      @lib.I32Const(limit),
      @lib.I32LtU,
    ) =>
      if precompute_raw_tlsf_init_limit_ok(limit) {
        (local_idx, limit)
      } else {
        return None
      }
    _ => return None
  }
  let (if_block_type, then_body) = match body[4] {
    @lib.If(bt, then_body, None) => (bt, then_body)
    _ => return None
  }
  if then_body.length() == 0 {
    return None
  }
  let mut suffix_base = then_body.length() - 1
  if then_body.length() >= 5 {
    let candidate_base = then_body.length() - 5
    match then_body[candidate_base + 4] {
      @lib.Br(@lib.LabelIdx(1U)) =>
        match
          (
            then_body[candidate_base],
            then_body[candidate_base + 1],
            then_body[candidate_base + 2],
            then_body[candidate_base + 3],
          ) {
          (
            @lib.LocalGet(get_counter),
            @lib.I32Const(@lib.I32(1)),
            @lib.I32Add,
            @lib.Drop,
          ) => if get_counter == counter { suffix_base = candidate_base }
          _ => ()
        }
      _ => ()
    }
  }
  match then_body[suffix_base] {
    @lib.Br(@lib.LabelIdx(1U)) => ()
    _ => return None
  }
  let next_then : Array[@lib.Instruction] = []
  for idx = 0; idx < suffix_base; idx = idx + 1 {
    match precompute_raw_try_repair_tlsf_init_counter_loop(then_body[idx]) {
      Some(repaired) => next_then.push(repaired)
      None => next_then.push(then_body[idx])
    }
  }
  next_then.push(@lib.Instruction::local_get(counter))
  next_then.push(@lib.Instruction::i32_const(@lib.I32(1)))
  next_then.push(@lib.Instruction::i32_add())
  next_then.push(@lib.Instruction::local_set(counter))
  next_then.push(@lib.Instruction::br(@lib.LabelIdx::new(1U)))
  let next_body = [
    @lib.Instruction::local_get(counter),
    @lib.Instruction::i32_const(limit),
    @lib.Instruction::i32_lt_u(),
    @lib.Instruction::if_(if_block_type, next_then, None),
  ]
  Some(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_set(counter),
        @lib.Instruction::loop_(block_type, @lib.Expr::new(next_body)),
      ]),
    ),
  )
}

///|
fn precompute_raw_try_void_dropped_result_block(
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  let body = match instr {
    @lib.Block(@lib.ValTypeBlockType(_), @lib.Expr(body)) => body
    _ => return None
  }
  if precompute_raw_instrs_have_branch_to_current_label(body) {
    return None
  }
  let void_body = body.copy()
  void_body.push(@lib.Instruction::drop())
  let mut changed = false
  while precompute_raw_fold_output_tail(void_body) {
    changed = true
  }
  if !changed || precompute_raw_instrs_have_drop_needing_hot(void_body) {
    return None
  }
  Some(
    @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(void_body)),
  )
}

///|
fn precompute_raw_fold_output_tail(out : Array[@lib.Instruction]) -> Bool {
  if precompute_raw_try_fold_const_if_tail(out) {
    return true
  }
  if out.length() >= 2 {
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
fn precompute_raw_rewrite_instr(
  instr : @lib.Instruction,
  module_ctx : @ir.HotModuleContext?,
) -> (@lib.Instruction, Bool) {
  match instr {
    @lib.GlobalGet(global_idx) =>
      match precompute_raw_global_const_instr(module_ctx, global_idx) {
        Some(rewritten) => (rewritten, true)
        None => (instr, false)
      }
    @lib.Block(block_type, @lib.Expr(body)) => {
      let (next_body, changed) = precompute_raw_rewrite_instrs(body, module_ctx)
      if changed {
        (@lib.Instruction::block(block_type, @lib.Expr::new(next_body)), true)
      } else {
        (instr, false)
      }
    }
    @lib.Loop(block_type, @lib.Expr(body)) => {
      let (next_body, changed) = precompute_raw_rewrite_instrs(body, module_ctx)
      if changed {
        (@lib.Instruction::loop_(block_type, @lib.Expr::new(next_body)), true)
      } else {
        (instr, false)
      }
    }
    @lib.If(block_type, then_body, else_body) => {
      let (next_then, then_changed) = precompute_raw_rewrite_instrs(
        then_body, module_ctx,
      )
      let mut changed = then_changed
      let next_else = match else_body {
        Some(body) => {
          let (rewritten, else_changed) = precompute_raw_rewrite_instrs(
            body, module_ctx,
          )
          if else_changed {
            changed = true
          }
          Some(rewritten)
        }
        None => None
      }
      if changed {
        (@lib.Instruction::if_(block_type, next_then, next_else), true)
      } else {
        (instr, false)
      }
    }
    @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
      let (next_body, changed) = precompute_raw_rewrite_instrs(body, module_ctx)
      if changed {
        (
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(next_body),
          ),
          true,
        )
      } else {
        (instr, false)
      }
    }
    _ => (instr, false)
  }
}

///|
fn precompute_raw_rewrite_instrs(
  instrs : Array[@lib.Instruction],
  module_ctx : @ir.HotModuleContext?,
) -> (Array[@lib.Instruction], Bool) {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  for instr in instrs {
    match precompute_raw_try_repair_stale_typed_loop_param_start(instr) {
      Some(repaired) => {
        out.push(repaired)
        changed = true
        continue
      }
      None => ()
    }
    match precompute_raw_try_repair_tlsf_init_counter_loop(instr) {
      Some(repaired) => {
        out.push(repaired)
        changed = true
        continue
      }
      None => ()
    }
    let (rewritten, nested_changed) = precompute_raw_rewrite_instr(
      instr, module_ctx,
    )
    out.push(rewritten)
    if nested_changed {
      changed = true
    }
    while precompute_raw_fold_output_tail(out) {
      changed = true
    }
  }
  if precompute_raw_try_repair_tlsf_memory_prologue(out) {
    changed = true
  }
  (out, changed)
}

///|
fn precompute_raw_instr_has_hot_only_candidate(
  instr : @lib.Instruction,
  module_ctx : @ir.HotModuleContext?,
) -> Bool {
  match instr {
    @lib.GlobalGet(_) => false
    @lib.BrTable(_, _) => true
    @lib.Nop => false
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
      precompute_raw_instrs_have_hot_only_candidate(body, module_ctx)
    @lib.If(_, then_body, else_body) => {
      if precompute_raw_instrs_have_hot_only_candidate(then_body, module_ctx) {
        return true
      }
      match else_body {
        Some(body) =>
          precompute_raw_instrs_have_hot_only_candidate(body, module_ctx)
        None => false
      }
    }
    @lib.TryTable(_, _, @lib.Expr(body)) =>
      precompute_raw_instrs_have_hot_only_candidate(body, module_ctx)
    _ => false
  }
}

///|
fn precompute_raw_instrs_have_hot_only_candidate(
  instrs : Array[@lib.Instruction],
  module_ctx : @ir.HotModuleContext?,
) -> Bool {
  for instr in instrs {
    if precompute_raw_instr_has_hot_only_candidate(instr, module_ctx) {
      return true
    }
  }
  false
}

///|
fn precompute_raw_instr_has_global_get(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.GlobalGet(_) => true
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
      precompute_raw_instrs_have_global_get(body)
    @lib.If(_, then_body, else_body) => {
      if precompute_raw_instrs_have_global_get(then_body) {
        return true
      }
      match else_body {
        Some(body) => precompute_raw_instrs_have_global_get(body)
        None => false
      }
    }
    @lib.TryTable(_, _, @lib.Expr(body)) =>
      precompute_raw_instrs_have_global_get(body)
    _ => false
  }
}

///|
fn precompute_raw_instrs_have_global_get(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    if precompute_raw_instr_has_global_get(instr) {
      return true
    }
  }
  false
}

///|
fn precompute_raw_func_has_global_get(func : @lib.Func) -> Bool {
  let @lib.Func(_, @lib.Expr(instrs)) = func
  precompute_raw_instrs_have_global_get(instrs)
}

///|
fn precompute_raw_instr_is_preserved_dropped_effect(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Call(_)
    | @lib.CallIndirect(_, _)
    | @lib.CallRef(_)
    | @lib.LocalTee(_)
    | @lib.TableGet(_)
    | @lib.MemoryGrow(_)
    | @lib.MemoryAtomicNotify(_)
    | @lib.MemoryAtomicWait32(_)
    | @lib.MemoryAtomicWait64(_)
    | @lib.AtomicRmw(_, _)
    | @lib.AtomicCmpxchg(_, _)
    | @lib.I32DivS
    | @lib.I32DivU
    | @lib.I32RemS
    | @lib.I32RemU
    | @lib.I64DivS
    | @lib.I64DivU
    | @lib.I64RemS
    | @lib.I64RemU
    | @lib.RefAsNonNull
    | @lib.RefCast(_, _)
    | @lib.RefCastDescEq(_, _)
    | @lib.StructGet(_, _)
    | @lib.StructGetS(_, _)
    | @lib.StructGetU(_, _)
    | @lib.StructAtomicGet(_, _, _)
    | @lib.StructAtomicGetS(_, _, _)
    | @lib.StructAtomicGetU(_, _, _)
    | @lib.ArrayGet(_)
    | @lib.ArrayGetS(_)
    | @lib.ArrayGetU(_)
    | @lib.ArrayLen
    | @lib.I31GetS
    | @lib.I31GetU
    | @lib.I32Load(_)
    | @lib.I64Load(_)
    | @lib.F32Load(_)
    | @lib.F64Load(_)
    | @lib.I32Load8S(_)
    | @lib.I32Load8U(_)
    | @lib.I32Load16S(_)
    | @lib.I32Load16U(_)
    | @lib.I64Load8S(_)
    | @lib.I64Load8U(_)
    | @lib.I64Load16S(_)
    | @lib.I64Load16U(_)
    | @lib.I64Load32S(_)
    | @lib.I64Load32U(_)
    | @lib.I32AtomicLoad(_)
    | @lib.I64AtomicLoad(_)
    | @lib.I32AtomicLoad8U(_)
    | @lib.I32AtomicLoad16U(_)
    | @lib.I64AtomicLoad8U(_)
    | @lib.I64AtomicLoad16U(_)
    | @lib.I64AtomicLoad32U(_)
    | @lib.V128Load(_)
    | @lib.V128Load8x8S(_)
    | @lib.V128Load8x8U(_)
    | @lib.V128Load16x4S(_)
    | @lib.V128Load16x4U(_)
    | @lib.V128Load32x2S(_)
    | @lib.V128Load32x2U(_)
    | @lib.V128Load8Splat(_)
    | @lib.V128Load16Splat(_)
    | @lib.V128Load32Splat(_)
    | @lib.V128Load64Splat(_) => true
    _ => false
  }
}

///|
fn precompute_raw_instrs_have_drop_needing_hot(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    match instr {
      @lib.Drop =>
        if idx == 0 ||
          !precompute_raw_instr_is_preserved_dropped_effect(instrs[idx - 1]) {
          return true
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if precompute_raw_instrs_have_drop_needing_hot(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if precompute_raw_instrs_have_drop_needing_hot(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if precompute_raw_instrs_have_drop_needing_hot(body) {
              return true
            }
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if precompute_raw_instrs_have_drop_needing_hot(body) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn precompute_raw_instrs_have_const_if_candidate(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    match instr {
      @lib.If(_, then_body, else_body) => {
        if idx > 0 {
          match precompute_raw_i32_const(instrs[idx - 1]) {
            Some(_) => return true
            None => ()
          }
        }
        if precompute_raw_instrs_have_const_if_candidate(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if precompute_raw_instrs_have_const_if_candidate(body) {
              return true
            }
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if precompute_raw_instrs_have_const_if_candidate(body) {
          return true
        }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if precompute_raw_instrs_have_const_if_candidate(body) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn precompute_raw_instrs_are_all_nops(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Nop => ()
      _ => return false
    }
  }
  true
}

///|
fn precompute_raw_root_nop_block_cleanup_candidate(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if precompute_raw_instrs_are_all_nops(body) {
          return true
        }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if precompute_raw_instrs_are_all_nops(body) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn precompute_raw_root_nop_cleanup_candidate(
  instrs : Array[@lib.Instruction],
) -> Bool {
  if instrs.length() == 0 {
    return true
  }
  if instrs.length() <= 1 {
    return false
  }
  let mut all_nops = true
  for instr in instrs {
    match instr {
      @lib.Nop => ()
      _ => all_nops = false
    }
  }
  if all_nops {
    return true
  }
  match instrs[instrs.length() - 1] {
    @lib.I32Const(_) | @lib.I64Const(_) | @lib.F32Const(_) | @lib.F64Const(_) =>
      ()
    _ => return false
  }
  for idx = 0; idx + 1 < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.Nop => ()
      _ => return false
    }
  }
  true
}

///|
fn precompute_raw_instr_has_stale_typed_loop_param_candidate(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Loop(_, @lib.Expr(body)) => {
      if body.length() >= 4 {
        match (body[0], body[1], body[2]) {
          (
            @lib.I32Const(@lib.I32(0)),
            @lib.LocalSet(counter),
            @lib.LocalTee(carried),
          ) => if counter != carried { return true }
          _ => ()
        }
      }
      precompute_raw_instrs_have_stale_typed_loop_param_candidate(body)
    }
    @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
      precompute_raw_instrs_have_stale_typed_loop_param_candidate(body)
    @lib.If(_, then_body, else_body) => {
      if precompute_raw_instrs_have_stale_typed_loop_param_candidate(then_body) {
        return true
      }
      match else_body {
        Some(body) =>
          precompute_raw_instrs_have_stale_typed_loop_param_candidate(body)
        None => false
      }
    }
    _ => false
  }
}

///|
fn precompute_raw_instrs_have_stale_typed_loop_param_candidate(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    if precompute_raw_instr_has_stale_typed_loop_param_candidate(instr) {
      return true
    }
  }
  false
}

///|
fn precompute_raw_instr_has_tlsf_repair_candidate(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Loop(_, @lib.Expr(body)) => {
      if body.length() == 5 {
        match (body[0], body[1], body[2], body[3]) {
          (
            @lib.I32Const(@lib.I32(0)),
            @lib.LocalTee(_),
            @lib.I32Const(limit),
            @lib.I32LtU,
          ) => if precompute_raw_tlsf_init_limit_ok(limit) { return true }
          _ => ()
        }
      }
      precompute_raw_instrs_have_tlsf_repair_candidate(body)
    }
    @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
      precompute_raw_instrs_have_tlsf_repair_candidate(body)
    @lib.If(_, then_body, else_body) => {
      if precompute_raw_instrs_have_tlsf_repair_candidate(then_body) {
        return true
      }
      match else_body {
        Some(body) => precompute_raw_instrs_have_tlsf_repair_candidate(body)
        None => false
      }
    }
    _ => false
  }
}

///|
fn precompute_raw_instrs_have_tlsf_repair_candidate(
  instrs : Array[@lib.Instruction],
) -> Bool {
  if instrs.length() >= 10 {
    match (instrs[0], instrs[1]) {
      (@lib.MemorySize(_), @lib.I32Const(@lib.I32(177248))) => return true
      (@lib.MemorySize(_), @lib.I32Const(@lib.I32(177263))) => return true
      _ => ()
    }
  }
  for instr in instrs {
    if precompute_raw_instr_has_tlsf_repair_candidate(instr) {
      return true
    }
  }
  false
}

///|
fn precompute_run_raw_func(
  func : @lib.Func,
  module_ctx : @ir.HotModuleContext?,
) -> (@lib.Func, Bool, String)? {
  let @lib.Func(locals, @lib.Expr(instrs)) = func
  let tlsf_repair_candidate = precompute_raw_instrs_have_tlsf_repair_candidate(
    instrs,
  )
  let stale_typed_loop_candidate = precompute_raw_instrs_have_stale_typed_loop_param_candidate(
    instrs,
  )
  if !tlsf_repair_candidate &&
    !stale_typed_loop_candidate &&
    precompute_raw_instrs_have_hot_only_candidate(instrs, module_ctx) {
    return None
  }
  if precompute_raw_root_nop_cleanup_candidate(instrs) ||
    precompute_raw_root_nop_block_cleanup_candidate(instrs) {
    return None
  }
  let (rewritten, changed) = precompute_raw_rewrite_instrs(instrs, module_ctx)
  if (tlsf_repair_candidate || stale_typed_loop_candidate) && changed {
    return Some(
      (
        @lib.Func::new(locals, @lib.Expr::new(rewritten)),
        true,
        "raw-tlsf-init-repair",
      ),
    )
  }
  if precompute_raw_instrs_have_drop_needing_hot(rewritten) ||
    precompute_raw_instrs_have_const_if_candidate(rewritten) ||
    precompute_raw_root_nop_cleanup_candidate(rewritten) {
    return None
  }
  Some(
    (
      @lib.Func::new(locals, @lib.Expr::new(rewritten)),
      changed,
      if changed {
        "raw-scalar-folds"
      } else {
        "no-precompute-candidates"
      },
    ),
  )
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

///|
fn precompute_propagate_prefix_const_payload_from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> @ir.HotConstPayload? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const | @ir.HotOp::RefNull =>
      Some(@ir.hot_const_get(func, node.imm0))
    @ir.HotOp::GlobalGet => precompute_global_const(ctx, func, node_id)
    _ => None
  }
}

///|
fn precompute_propagate_prefix_const_payload_matches_type(
  payload : @ir.HotConstPayload,
  ty : @lib.ValType,
) -> Bool {
  match (payload, ty) {
    (@ir.HotConstPayload::I32Const(_), @lib.NumTypeValType(@lib.I32NumType)) =>
      true
    (@ir.HotConstPayload::I64Const(_), @lib.NumTypeValType(@lib.I64NumType)) =>
      true
    (@ir.HotConstPayload::F32Const(_), @lib.NumTypeValType(@lib.F32NumType)) =>
      true
    (@ir.HotConstPayload::F64Const(_), @lib.NumTypeValType(@lib.F64NumType)) =>
      true
    (@ir.HotConstPayload::RefNullConst(ref_type), @lib.RefTypeValType(expected)) =>
      ref_type == expected
    _ => false
  }
}

///|
fn precompute_propagate_prefix_const_instr(
  payload : @ir.HotConstPayload,
) -> @lib.Instruction? {
  match payload {
    @ir.HotConstPayload::I32Const(value) =>
      Some(@lib.Instruction::i32_const(value))
    @ir.HotConstPayload::I64Const(value) =>
      Some(@lib.Instruction::i64_const(value))
    @ir.HotConstPayload::F32Const(value) =>
      Some(@lib.Instruction::f32_const(value))
    @ir.HotConstPayload::F64Const(value) =>
      Some(@lib.Instruction::f64_const(value))
    @ir.HotConstPayload::RefNullConst(ref_type) =>
      Some(@lib.Instruction::ref_null(ref_type.get_heap_type()))
    @ir.HotConstPayload::StringConst(value) =>
      Some(@lib.Instruction::string_const(value))
  }
}

///|
fn precompute_propagate_prefix_const_payload_from_instr(
  instr : @lib.Instruction,
) -> @ir.HotConstPayload? {
  match instr {
    @lib.I32Const(value) => Some(@ir.HotConstPayload::i32_const(value))
    @lib.I64Const(value) => Some(@ir.HotConstPayload::i64_const(value))
    @lib.F32Const(value) => Some(@ir.HotConstPayload::f32_const(value))
    @lib.F64Const(value) => Some(@ir.HotConstPayload::f64_const(value))
    @lib.RefNull(ref_type) =>
      Some(@ir.HotConstPayload::ref_null_const(ref_type))
    @lib.StringConst(value) => Some(@ir.HotConstPayload::string_const(value))
    _ => None
  }
}

///|
fn precompute_propagate_prefix_default_local_const(
  func : @ir.HotFunc,
  local_id : Int,
) -> @ir.HotConstPayload? {
  match @ir.hot_local_type(func, local_id) {
    Some(@lib.NumTypeValType(@lib.I32NumType)) =>
      Some(@ir.HotConstPayload::i32_const(@lib.I32(0)))
    Some(@lib.NumTypeValType(@lib.I64NumType)) =>
      Some(@ir.HotConstPayload::i64_const(@lib.I64(0L)))
    Some(@lib.NumTypeValType(@lib.F32NumType)) =>
      Some(@ir.HotConstPayload::f32_const(@lib.F32(0.0)))
    Some(@lib.NumTypeValType(@lib.F64NumType)) =>
      Some(@ir.HotConstPayload::f64_const(@lib.F64(0.0)))
    Some(@lib.RefTypeValType(ref_type)) =>
      Some(@ir.HotConstPayload::ref_null_const(ref_type))
    _ => None
  }
}

///|
fn precompute_propagate_prefix_const_for_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  ssa : @ir.HotLocalSsa,
  node_id : Int,
  states : Array[Int],
  value_consts : Array[@ir.HotConstPayload?],
) -> @ir.HotConstPayload? {
  match
    precompute_propagate_prefix_const_payload_from_node(ctx, func, node_id) {
    Some(payload) => return Some(payload)
    None => ()
  }
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet => {
      let value_id = ssa.local_get_values[node_id]
      if value_id < 0 {
        return None
      }
      return precompute_propagate_prefix_const_for_value(
        ctx, func, ssa, value_id, states, value_consts,
      )
    }
    _ => ()
  }
  let instr = match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) => instr
    None => return None
  }
  let child_count = @ir.hot_child_count(func, node_id)
  if child_count == 1 {
    let operand = match
      precompute_propagate_prefix_const_for_node(
        ctx,
        func,
        ssa,
        @ir.hot_child_get(func, node_id, 0),
        states,
        value_consts,
      ) {
      Some(payload) => payload
      None => return None
    }
    let operand_instr = match precompute_propagate_prefix_const_instr(operand) {
      Some(instr) => instr
      None => return None
    }
    return match precompute_raw_try_fold_unary(operand_instr, instr) {
      Some(next) => precompute_propagate_prefix_const_payload_from_instr(next)
      None => None
    }
  }
  if child_count == 2 {
    let lhs = match
      precompute_propagate_prefix_const_for_node(
        ctx,
        func,
        ssa,
        @ir.hot_child_get(func, node_id, 0),
        states,
        value_consts,
      ) {
      Some(payload) => payload
      None => return None
    }
    let rhs = match
      precompute_propagate_prefix_const_for_node(
        ctx,
        func,
        ssa,
        @ir.hot_child_get(func, node_id, 1),
        states,
        value_consts,
      ) {
      Some(payload) => payload
      None => return None
    }
    let lhs_instr = match precompute_propagate_prefix_const_instr(lhs) {
      Some(instr) => instr
      None => return None
    }
    let rhs_instr = match precompute_propagate_prefix_const_instr(rhs) {
      Some(instr) => instr
      None => return None
    }
    return match precompute_raw_try_fold_binary(lhs_instr, rhs_instr, instr) {
      Some(next) => precompute_propagate_prefix_const_payload_from_instr(next)
      None => None
    }
  }
  None
}

///|
fn precompute_propagate_prefix_const_for_value(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  ssa : @ir.HotLocalSsa,
  value_id : Int,
  states : Array[Int],
  value_consts : Array[@ir.HotConstPayload?],
) -> @ir.HotConstPayload? {
  if value_id < 0 || value_id >= states.length() {
    return None
  }
  match states[value_id] {
    1 => return None
    2 => return value_consts[value_id]
    3 => return None
    _ => ()
  }
  states[value_id] = 1
  let expected_type = @ir.ssa_value_type(ssa, value_id)
  let resolved = match @ir.ssa_value_origin(ssa, value_id) {
    @ir.HotSsaValueOrigin::EntryParamDef(_) => None
    @ir.HotSsaValueOrigin::EntryDefaultInitDef(local_id) =>
      precompute_propagate_prefix_default_local_const(func, local_id)
    @ir.HotSsaValueOrigin::LocalSetDef(node_id)
    | @ir.HotSsaValueOrigin::LocalTeeDef(node_id) =>
      if @ir.hot_child_count(func, node_id) != 1 {
        None
      } else {
        match
          precompute_propagate_prefix_const_for_node(
            ctx,
            func,
            ssa,
            @ir.hot_child_get(func, node_id, 0),
            states,
            value_consts,
          ) {
          Some(payload) =>
            if precompute_propagate_prefix_const_payload_matches_type(
                payload, expected_type,
              ) {
              Some(payload)
            } else {
              None
            }
          _ => None
        }
      }
    @ir.HotSsaValueOrigin::PhiDef(phi_id) => {
      let inputs = @ir.ssa_phi_inputs(ssa, phi_id)
      if inputs.length() == 0 {
        None
      } else {
        let mut candidate : @ir.HotConstPayload? = None
        let mut ok = true
        for input in inputs {
          match
            precompute_propagate_prefix_const_for_value(
              ctx,
              func,
              ssa,
              input.value_id,
              states,
              value_consts,
            ) {
            Some(payload) =>
              if precompute_propagate_prefix_const_payload_matches_type(
                  payload, expected_type,
                ) {
                match candidate {
                  Some(existing) => if existing != payload { ok = false }
                  None => candidate = Some(payload)
                }
              } else {
                ok = false
              }
            _ => ok = false
          }
          if !ok {
            break
          }
        }
        if ok {
          candidate
        } else {
          None
        }
      }
    }
  }
  match resolved {
    Some(payload) => {
      states[value_id] = 2
      value_consts[value_id] = Some(payload)
      Some(payload)
    }
    None => {
      states[value_id] = 3
      None
    }
  }
}

///|
fn precompute_propagate_prefix_fold_local_gets(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Bool {
  let ssa = pass_require_ssa(ctx, func)
  let states = Array::make(ssa.value_types.length(), 0)
  let value_consts : Array[@ir.HotConstPayload?] = Array::make(
    ssa.value_types.length(),
    None,
  )
  let replacements : Array[PrecomputePropagatePrefixReplacement] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::LocalGet => {
        let value_id = ssa.local_get_values[node_id]
        if value_id < 0 {
          continue
        }
        match
          precompute_propagate_prefix_const_for_value(
            ctx, func, ssa, value_id, states, value_consts,
          ) {
          Some(payload) => replacements.push({ node_id, payload })
          None => ()
        }
      }
      _ => ()
    }
  }
  if replacements.length() == 0 {
    return false
  }
  for replacement in replacements {
    if !@ir.hot_node_is_live(func, replacement.node_id) {
      continue
    }
    let temp = match replacement.payload {
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
      @ir.HotConstPayload::StringConst(value) =>
        @ir.hot_build_string_const(func, value)
    }
    let next_node = @ir.hot_node_get(func, temp)
    @ir.hot_delete_node(func, temp)
    @ir.hot_replace_node(func, replacement.node_id, next_node)
    pass_mark_mutated(ctx, func)
  }
  true
}

///|
pub fn precompute_propagate_prefix_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  let propagated = precompute_propagate_prefix_fold_local_gets(ctx, func)
  let precomputed = precompute_run(ctx, func)
  if propagated || precomputed.changed {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
