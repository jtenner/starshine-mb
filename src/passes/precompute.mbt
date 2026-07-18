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
  "Evaluate exact scalar expressions, selected control and GC values, and safe dropped computations."
}

///|
pub fn precompute_propagate_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "precompute-propagate",
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
pub fn precompute_propagate_summary() -> String {
  "Precompute constants, propagate agreeing local values through SSA, then rerun precompute once."
}

///|
fn precompute_replace_node_rehoming_control_label(
  func : @ir.HotFunc,
  node_id : @ir.NodeId,
  replacement : @ir.HotNode,
) -> Unit {
  @ir.hot_replace_node(func, node_id, replacement)
  let label_id = @ir.hot_control_node_label(func, node_id)
  if label_id >= 0 {
    @ir.hot_label_owner_set(func, label_id, node_id)
  }
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
fn precompute_exact_const_instr(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> @lib.Instruction? {
  let payload = if node_id >= 0 && @ir.hot_node_is_live(func, node_id) {
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Const | @ir.HotOp::RefNull =>
        Some(@ir.hot_const_get(func, node.imm0))
      @ir.HotOp::GlobalGet => precompute_global_const(ctx, func, node_id)
      _ => None
    }
  } else {
    None
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
      Some(@lib.Instruction::ref_null_type(value))
    Some(@ir.HotConstPayload::StringConst(value)) =>
      Some(@lib.Instruction::string_const(value))
    None => None
  }
}

///|
fn precompute_build_const_instr(
  func : @ir.HotFunc,
  instr : @lib.Instruction,
) -> Int? {
  match instr {
    @lib.I32Const(value) => Some(@ir.hot_build_const_i32(func, value))
    @lib.I64Const(value) => Some(@ir.hot_build_const_i64(func, value))
    @lib.F32Const(value) => Some(@ir.hot_build_const_f32(func, value))
    @lib.F64Const(value) => Some(@ir.hot_build_const_f64(func, value))
    @lib.RefNull(ref_type) => Some(@ir.hot_build_ref_null(func, ref_type))
    @lib.StringConst(value) => Some(@ir.hot_build_string_const(func, value))
    _ => None
  }
}

///|
fn precompute_replace_with_const_instr(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  instr : @lib.Instruction,
) -> Bool {
  let temp = match precompute_build_const_instr(func, instr) {
    Some(node_id) => node_id
    None => return false
  }
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  precompute_replace_node_rehoming_control_label(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
  true
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
  precompute_replace_node_rehoming_control_label(func, node_id, replacement)
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
  precompute_replace_node_rehoming_control_label(func, node_id, replacement)
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
      precompute_replace_node_rehoming_control_label(func, node_id, replacement)
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
  match precompute_exact_const_instr(ctx, func, operand_id) {
    Some(operand) =>
      match precompute_raw_try_fold_unary(operand, instr) {
        Some(folded) =>
          if precompute_replace_with_const_instr(ctx, func, node_id, folded) {
            return true
          }
        None => ()
      }
    None => ()
  }
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
      precompute_exact_const_instr(ctx, func, lhs_id),
      precompute_exact_const_instr(ctx, func, rhs_id),
    ) {
    (Some(lhs), Some(rhs)) =>
      match precompute_raw_try_fold_binary(lhs, rhs, instr) {
        Some(folded) =>
          if precompute_replace_with_const_instr(ctx, func, node_id, folded) {
            return true
          }
        None => ()
      }
    _ => ()
  }
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
fn precompute_try_partial_select_unary_parent(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  instr : @lib.Instruction,
) -> Bool {
  if @ir.hot_child_count(func, node_id) != 1 ||
    @ir.hot_node_result_arity(func, node_id) != 1 {
    return false
  }
  let select_id = @ir.hot_child_get(func, node_id, 0)
  if select_id < 0 ||
    !@ir.hot_node_is_live(func, select_id) ||
    @ir.hot_child_count(func, select_id) != 3 {
    return false
  }
  match @ir.hot_node_get(func, select_id).op {
    @ir.HotOp::Select => ()
    _ => return false
  }
  let true_value = match
    precompute_exact_const_instr(
      ctx,
      func,
      @ir.hot_child_get(func, select_id, 0),
    ) {
    Some(value) => value
    None => return false
  }
  let false_value = match
    precompute_exact_const_instr(
      ctx,
      func,
      @ir.hot_child_get(func, select_id, 1),
    ) {
    Some(value) => value
    None => return false
  }
  let folded_true = match precompute_raw_try_fold_unary(true_value, instr) {
    Some(value) => value
    None => return false
  }
  let folded_false = match precompute_raw_try_fold_unary(false_value, instr) {
    Some(value) => value
    None => return false
  }
  let next_true = match precompute_build_const_instr(func, folded_true) {
    Some(value) => value
    None => return false
  }
  let next_false = match precompute_build_const_instr(func, folded_false) {
    Some(value) => value
    None => return false
  }
  let results = @ir.hot_type_results(func, @ir.hot_node_get(func, node_id).ty)
  if results.length() != 1 {
    return false
  }
  let temp = @ir.hot_build_select(
    func,
    results[0],
    next_true,
    next_false,
    @ir.hot_child_get(func, select_id, 2),
  )
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  precompute_replace_node_rehoming_control_label(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn precompute_try_partial_select_parent(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  instr : @lib.Instruction,
) -> Bool {
  if @ir.hot_child_count(func, node_id) == 1 {
    return precompute_try_partial_select_unary_parent(ctx, func, node_id, instr)
  }
  if @ir.hot_child_count(func, node_id) != 2 ||
    @ir.hot_node_result_arity(func, node_id) != 1 {
    return false
  }
  let lhs_id = @ir.hot_child_get(func, node_id, 0)
  let rhs_id = @ir.hot_child_get(func, node_id, 1)
  let lhs_is_select = if lhs_id >= 0 && @ir.hot_node_is_live(func, lhs_id) {
    match @ir.hot_node_get(func, lhs_id).op {
      @ir.HotOp::Select => true
      _ => false
    }
  } else {
    false
  }
  let rhs_is_select = if rhs_id >= 0 && @ir.hot_node_is_live(func, rhs_id) {
    match @ir.hot_node_get(func, rhs_id).op {
      @ir.HotOp::Select => true
      _ => false
    }
  } else {
    false
  }
  let (select_id, other_id, select_is_lhs) = if lhs_is_select {
    (lhs_id, rhs_id, true)
  } else if rhs_is_select {
    (rhs_id, lhs_id, false)
  } else {
    return false
  }
  if @ir.hot_child_count(func, select_id) != 3 {
    return false
  }
  let other = match precompute_exact_const_instr(ctx, func, other_id) {
    Some(value) => value
    None => return false
  }
  let true_id = @ir.hot_child_get(func, select_id, 0)
  let false_id = @ir.hot_child_get(func, select_id, 1)
  let condition_id = @ir.hot_child_get(func, select_id, 2)
  let true_value = match precompute_exact_const_instr(ctx, func, true_id) {
    Some(value) => value
    None => return false
  }
  let false_value = match precompute_exact_const_instr(ctx, func, false_id) {
    Some(value) => value
    None => return false
  }
  let folded_true = match
    (if select_is_lhs {
      precompute_raw_try_fold_binary(true_value, other, instr)
    } else {
      precompute_raw_try_fold_binary(other, true_value, instr)
    }) {
    Some(value) => value
    None => return false
  }
  let folded_false = match
    (if select_is_lhs {
      precompute_raw_try_fold_binary(false_value, other, instr)
    } else {
      precompute_raw_try_fold_binary(other, false_value, instr)
    }) {
    Some(value) => value
    None => return false
  }
  let next_true = match precompute_build_const_instr(func, folded_true) {
    Some(value) => value
    None => return false
  }
  let next_false = match precompute_build_const_instr(func, folded_false) {
    Some(value) => value
    None => return false
  }
  let results = @ir.hot_type_results(func, @ir.hot_node_get(func, node_id).ty)
  if results.length() != 1 {
    return false
  }
  let temp = @ir.hot_build_select(
    func,
    results[0],
    next_true,
    next_false,
    condition_id,
  )
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  precompute_replace_node_rehoming_control_label(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
  true
}

///|
priv enum PrecomputeEffectfulChildKeep {
  PrecomputeNoEffectKeep
  PrecomputeKeepLocalSet(Int, Int)
  PrecomputeKeepDrop(Int)
}

///|
fn precompute_effectful_child_plan(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  child_id : Int,
) -> (@lib.Instruction, PrecomputeEffectfulChildKeep)? {
  match precompute_exact_const_instr(ctx, func, child_id) {
    Some(value) => return Some((value, PrecomputeNoEffectKeep))
    None => ()
  }
  if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
    return None
  }
  let child = @ir.hot_node_get(func, child_id)
  match child.op {
    @ir.HotOp::LocalTee => {
      if @ir.hot_child_count(func, child_id) != 1 {
        return None
      }
      let value_id = @ir.hot_child_get(func, child_id, 0)
      match precompute_exact_const_instr(ctx, func, value_id) {
        Some(value) =>
          Some((value, PrecomputeKeepLocalSet(child.imm0, value_id)))
        None => None
      }
    }
    @ir.HotOp::Block => {
      if @ir.hot_node_result_arity(func, child_id) != 1 {
        return None
      }
      let body_ref = @ir.hot_region_body_ref(func, child_id)
      let root_count = @ir.hot_region_root_count(func, body_ref)
      if root_count < 2 {
        return None
      }
      let tail_id = @ir.hot_region_get(func, body_ref, root_count - 1)
      let value = match precompute_exact_const_instr(ctx, func, tail_id) {
        Some(value) => value
        None => return None
      }
      for slot = 0; slot + 1 < root_count; slot = slot + 1 {
        let root_id = @ir.hot_region_get(func, body_ref, slot)
        if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
          return None
        }
        match @ir.hot_node_get(func, root_id).op {
          @ir.HotOp::Nop => ()
          @ir.HotOp::LocalSet | @ir.HotOp::GlobalSet =>
            if @ir.hot_child_count(func, root_id) != 1 ||
              precompute_exact_const_instr(
                ctx,
                func,
                @ir.hot_child_get(func, root_id, 0),
              )
              is None {
              return None
            }
          _ => return None
        }
      }
      Some((value, PrecomputeKeepDrop(child_id)))
    }
    _ => None
  }
}

///|
fn precompute_try_fold_effectful_parent(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  instr : @lib.Instruction,
) -> Bool {
  let child_count = @ir.hot_child_count(func, node_id)
  if (child_count != 1 && child_count != 2) ||
    @ir.hot_node_result_arity(func, node_id) != 1 {
    return false
  }
  let plans : Array[(@lib.Instruction, PrecomputeEffectfulChildKeep)] = []
  let mut has_effect = false
  for slot = 0; slot < child_count; slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    let plan = match precompute_effectful_child_plan(ctx, func, child_id) {
      Some(plan) => plan
      None => {
        let child = if child_id >= 0 && @ir.hot_node_is_live(func, child_id) {
          @ir.hot_node_get(func, child_id)
        } else {
          return false
        }
        match child.op {
          @ir.HotOp::LocalGet => {
            let mut prior_value : @lib.Instruction? = None
            for prior_slot = 0; prior_slot < slot; prior_slot = prior_slot + 1 {
              let prior_id = @ir.hot_child_get(func, node_id, prior_slot)
              if prior_id >= 0 && @ir.hot_node_is_live(func, prior_id) {
                let prior = @ir.hot_node_get(func, prior_id)
                match prior.op {
                  @ir.HotOp::LocalTee if prior.imm0 == child.imm0 =>
                    prior_value = Some(plans[prior_slot].0)
                  _ => ()
                }
              }
            }
            match prior_value {
              Some(value) => (value, PrecomputeNoEffectKeep)
              None => return false
            }
          }
          _ => return false
        }
      }
    }
    match plan.1 {
      PrecomputeNoEffectKeep => ()
      _ => has_effect = true
    }
    plans.push(plan)
  }
  if !has_effect {
    return false
  }
  let folded = if child_count == 1 {
    match precompute_raw_try_fold_unary(plans[0].0, instr) {
      Some(value) => value
      None => return false
    }
  } else {
    match precompute_raw_try_fold_binary(plans[0].0, plans[1].0, instr) {
      Some(value) => value
      None => return false
    }
  }
  let folded_id = match precompute_build_const_instr(func, folded) {
    Some(value) => value
    None => return false
  }
  let kept : Array[Int] = []
  for plan in plans {
    match plan.1 {
      PrecomputeNoEffectKeep => ()
      PrecomputeKeepLocalSet(local_id, value_id) =>
        kept.push(@ir.hot_build_local_set(func, local_id, value_id))
      PrecomputeKeepDrop(child_id) =>
        kept.push(@ir.hot_build_drop(func, child_id))
    }
  }
  kept.push(folded_id)
  let results = @ir.hot_type_results(func, @ir.hot_node_get(func, node_id).ty)
  if results.length() != 1 {
    return false
  }
  let temp = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(results[0]),
    kept,
  )
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  precompute_replace_node_rehoming_control_label(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn precompute_fresh_struct_allocation_is_discardable(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.StructNew(_)) | Some(@lib.StructNewDefault(_)) => ()
    _ => return false
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if !precompute_is_discardable_value(
        func,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return false
    }
  }
  true
}

///|
fn precompute_try_fold_gc_identity(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.RefEq) => ()
    _ => return false
  }
  if @ir.hot_child_count(func, node_id) != 2 {
    return false
  }
  let lhs = @ir.hot_child_get(func, node_id, 0)
  let rhs = @ir.hot_child_get(func, node_id, 1)
  let lhs_null = lhs >= 0 &&
    @ir.hot_node_is_live(func, lhs) &&
    (match @ir.hot_node_get(func, lhs).op {
      @ir.HotOp::RefNull => true
      _ => false
    })
  let rhs_null = rhs >= 0 &&
    @ir.hot_node_is_live(func, rhs) &&
    (match @ir.hot_node_get(func, rhs).op {
      @ir.HotOp::RefNull => true
      _ => false
    })
  if (lhs_null && precompute_fresh_struct_allocation_is_discardable(func, rhs)) ||
    (rhs_null && precompute_fresh_struct_allocation_is_discardable(func, lhs)) {
    precompute_replace_with_const_i32(ctx, func, node_id, @lib.I32(0))
    return true
  }
  false
}

///|
fn precompute_try_fold_fresh_ref_test(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let target = match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.RefTest(_, _, target)) => target
    _ => return false
  }
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let ref_id = @ir.hot_child_get(func, node_id, 0)
  if !precompute_fresh_struct_allocation_is_discardable(func, ref_id) {
    return false
  }
  let type_idx = match @ir.hot_node_exact_instr(func, ref_id) {
    Some(@lib.StructNew(type_idx)) | Some(@lib.StructNewDefault(type_idx)) =>
      type_idx
    _ => return false
  }
  if target != @lib.HeapType::new(type_idx) {
    return false
  }
  precompute_replace_with_const_i32(ctx, func, node_id, @lib.I32(1))
  true
}

///|
fn precompute_try_fold_fresh_struct_get(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let (type_idx, raw_field, signed, unsigned) = match
    @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.StructGet(type_idx, @lib.U32(raw_field))) =>
      (type_idx, raw_field, false, false)
    Some(@lib.StructGetS(type_idx, @lib.U32(raw_field))) =>
      (type_idx, raw_field, true, false)
    Some(@lib.StructGetU(type_idx, @lib.U32(raw_field))) =>
      (type_idx, raw_field, false, true)
    _ => return false
  }
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let ref_id = @ir.hot_child_get(func, node_id, 0)
  let defaulted = match @ir.hot_node_exact_instr(func, ref_id) {
    Some(@lib.StructNew(new_type_idx)) if new_type_idx == type_idx => false
    Some(@lib.StructNewDefault(new_type_idx)) if new_type_idx == type_idx =>
      true
    _ => return false
  }
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return false
  }
  let fields = match
    @ir.hot_module_resolve_struct_fields(module_ctx, type_idx) {
    Some(fields) => fields
    None => return false
  }
  let field_idx = raw_field.reinterpret_as_int()
  let field = match fields.get(field_idx) {
    Some(field) => field
    None => return false
  }
  if field.is_mutable() {
    return false
  }
  let storage = field.get_storage_type()
  let value = if defaulted {
    if @ir.hot_child_count(func, ref_id) != 0 {
      return false
    }
    match precompute_default_const_for_storage(storage) {
      Some(value) => value
      None => return false
    }
  } else {
    if @ir.hot_child_count(func, ref_id) != fields.length() {
      return false
    }
    for slot = 0; slot < @ir.hot_child_count(func, ref_id); slot = slot + 1 {
      let child_id = @ir.hot_child_get(func, ref_id, slot)
      if slot != field_idx && !precompute_is_discardable_value(func, child_id) {
        return false
      }
    }
    match
      precompute_exact_const_instr(
        ctx,
        func,
        @ir.hot_child_get(func, ref_id, field_idx),
      ) {
      Some(value) => value
      None => return false
    }
  }
  let unpacked = match
    precompute_unpack_array_value(value, storage, signed, unsigned) {
    Some(value) => value
    None => return false
  }
  precompute_replace_with_const_instr(ctx, func, node_id, unpacked)
}

///|
fn precompute_fresh_array_allocation_is_discardable(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.ArrayNew(_))
    | Some(@lib.ArrayNewDefault(_))
    | Some(@lib.ArrayNewFixed(_, _)) => ()
    _ => return false
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if !precompute_is_discardable_value(
        func,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return false
    }
  }
  true
}

///| Binaryen v130's interpreter rejects GC arrays whose literal count reaches

///| its 1 GiB `DataLimit`. The v130 64-bit oracle uses 24-byte `Literal`s, so

///|
/// 44,739,242 is the first rejected length.
fn precompute_fresh_array_length_is_interpretable(length : UInt) -> Bool {
  length < 44739242U
}

///|
fn precompute_fresh_array_length(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> @lib.I32? {
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.ArrayNewFixed(_, @lib.U32(length))) if precompute_fresh_array_length_is_interpretable(
        length,
      ) => Some(@lib.I32(length.reinterpret_as_int()))
    Some(@lib.ArrayNew(_)) if @ir.hot_child_count(func, node_id) == 2 =>
      match
        precompute_i32_exact_const(
          ctx,
          func,
          @ir.hot_child_get(func, node_id, 1),
        ) {
        Some(@lib.I32(length)) if length >= 0 &&
          precompute_fresh_array_length_is_interpretable(
            length.reinterpret_as_uint(),
          ) => Some(@lib.I32(length))
        _ => None
      }
    Some(@lib.ArrayNewDefault(_)) if @ir.hot_child_count(func, node_id) == 1 =>
      match
        precompute_i32_exact_const(
          ctx,
          func,
          @ir.hot_child_get(func, node_id, 0),
        ) {
        Some(@lib.I32(length)) if length >= 0 &&
          precompute_fresh_array_length_is_interpretable(
            length.reinterpret_as_uint(),
          ) => Some(@lib.I32(length))
        _ => None
      }
    _ => None
  }
}

///|
fn precompute_default_const_for_storage(
  storage : @lib.StorageType,
) -> @lib.Instruction? {
  match storage {
    @lib.PackTypeStorageType(_)
    | @lib.ValTypeStorageType(@lib.NumTypeValType(@lib.I32NumType)) =>
      Some(@lib.Instruction::i32_const(@lib.I32(0)))
    @lib.ValTypeStorageType(@lib.NumTypeValType(@lib.I64NumType)) =>
      Some(@lib.Instruction::i64_const(@lib.I64(0L)))
    @lib.ValTypeStorageType(@lib.NumTypeValType(@lib.F32NumType)) =>
      Some(
        @lib.Instruction::f32_const(@lib.F32(Float::reinterpret_from_uint(0U))),
      )
    @lib.ValTypeStorageType(@lib.NumTypeValType(@lib.F64NumType)) =>
      Some(@lib.Instruction::f64_const(@lib.F64(0.0)))
    @lib.ValTypeStorageType(@lib.RefTypeValType(ref_type)) if ref_type.is_nullable() =>
      Some(@lib.Instruction::ref_null_type(ref_type))
    _ => None
  }
}

///|
fn precompute_fresh_array_get_value(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  allocation_id : Int,
  type_idx : @lib.TypeIdx,
  index : UInt,
  storage : @lib.StorageType,
) -> @lib.Instruction? {
  match @ir.hot_node_exact_instr(func, allocation_id) {
    Some(@lib.ArrayNewFixed(new_type_idx, @lib.U32(length))) if new_type_idx ==
      type_idx &&
      precompute_fresh_array_length_is_interpretable(length) &&
      index < length => {
      let slot = index.reinterpret_as_int()
      if @ir.hot_child_count(func, allocation_id) != length.reinterpret_as_int() {
        return None
      }
      precompute_exact_const_instr(
        ctx,
        func,
        @ir.hot_child_get(func, allocation_id, slot),
      )
    }
    Some(@lib.ArrayNew(new_type_idx)) if new_type_idx == type_idx &&
      @ir.hot_child_count(func, allocation_id) == 2 => {
      let length = match
        precompute_i32_exact_const(
          ctx,
          func,
          @ir.hot_child_get(func, allocation_id, 1),
        ) {
        Some(@lib.I32(length)) if length >= 0 &&
          precompute_fresh_array_length_is_interpretable(
            length.reinterpret_as_uint(),
          ) => length.reinterpret_as_uint()
        _ => return None
      }
      if index >= length {
        return None
      }
      precompute_exact_const_instr(
        ctx,
        func,
        @ir.hot_child_get(func, allocation_id, 0),
      )
    }
    Some(@lib.ArrayNewDefault(new_type_idx)) if new_type_idx == type_idx &&
      @ir.hot_child_count(func, allocation_id) == 1 => {
      let length = match
        precompute_i32_exact_const(
          ctx,
          func,
          @ir.hot_child_get(func, allocation_id, 0),
        ) {
        Some(@lib.I32(length)) if length >= 0 &&
          precompute_fresh_array_length_is_interpretable(
            length.reinterpret_as_uint(),
          ) => length.reinterpret_as_uint()
        _ => return None
      }
      if index >= length {
        return None
      }
      precompute_default_const_for_storage(storage)
    }
    _ => None
  }
}

///|
fn precompute_unpack_array_value(
  value : @lib.Instruction,
  storage : @lib.StorageType,
  signed : Bool,
  unsigned : Bool,
) -> @lib.Instruction? {
  match storage {
    @lib.ValTypeStorageType(_) => Some(value)
    @lib.PackTypeStorageType(pack_type) => {
      let raw = match value {
        @lib.I32Const(@lib.I32(raw)) => raw
        _ => return None
      }
      match (pack_type, signed, unsigned) {
        (@lib.I8PackType, true, false) =>
          Some(@lib.Instruction::i32_const(@lib.I32(raw << 24 >> 24)))
        (@lib.I8PackType, false, true) =>
          Some(@lib.Instruction::i32_const(@lib.I32(raw & 0xff)))
        (@lib.I16PackType, true, false) =>
          Some(@lib.Instruction::i32_const(@lib.I32(raw << 16 >> 16)))
        (@lib.I16PackType, false, true) =>
          Some(@lib.Instruction::i32_const(@lib.I32(raw & 0xffff)))
        _ => None
      }
    }
  }
}

///|
fn precompute_try_fold_fresh_array_len(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.ArrayLen) => ()
    _ => return false
  }
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let allocation_id = @ir.hot_child_get(func, node_id, 0)
  if !precompute_fresh_array_allocation_is_discardable(func, allocation_id) {
    return false
  }
  let length = match precompute_fresh_array_length(ctx, func, allocation_id) {
    Some(length) => length
    None => return false
  }
  precompute_replace_with_const_i32(ctx, func, node_id, length)
  true
}

///|
fn precompute_try_fold_fresh_array_get(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let (type_idx, signed, unsigned) = match
    @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.ArrayGet(type_idx)) => (type_idx, false, false)
    Some(@lib.ArrayGetS(type_idx)) => (type_idx, true, false)
    Some(@lib.ArrayGetU(type_idx)) => (type_idx, false, true)
    _ => return false
  }
  if @ir.hot_child_count(func, node_id) != 2 {
    return false
  }
  let allocation_id = @ir.hot_child_get(func, node_id, 0)
  if !precompute_fresh_array_allocation_is_discardable(func, allocation_id) {
    return false
  }
  let index = match
    precompute_i32_exact_const(ctx, func, @ir.hot_child_get(func, node_id, 1)) {
    Some(@lib.I32(index)) => index.reinterpret_as_uint()
    None => return false
  }
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return false
  }
  let field = match @ir.hot_module_resolve_array_field(module_ctx, type_idx) {
    Some(field) => field
    None => return false
  }
  if field.is_mutable() {
    return false
  }
  let storage = field.get_storage_type()
  let value = match
    precompute_fresh_array_get_value(
      ctx, func, allocation_id, type_idx, index, storage,
    ) {
    Some(value) => value
    None => return false
  }
  let unpacked = match
    precompute_unpack_array_value(value, storage, signed, unsigned) {
    Some(value) => value
    None => return false
  }
  precompute_replace_with_const_instr(ctx, func, node_id, unpacked)
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
        @ir.hot_control_demote_if_to_block(func, node_id, [])
        pass_mark_mutated(ctx, func)
        return true
      }
    }
  }
  let root_count = @ir.hot_region_root_count(func, chosen_region)
  if !precompute_constant_if_chosen_region_can_inline(func, chosen_region) {
    return false
  }
  let replacement : Array[Int] = []
  for i = 0; i < root_count; i = i + 1 {
    replacement.push(@ir.hot_region_get(func, chosen_region, i))
  }
  @ir.hot_control_demote_if_to_block(func, node_id, replacement)
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
fn precompute_try_inline_transparent_value_block_child(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  if @ir.hot_is_control_node(func, node_id) {
    return false
  }
  let child_count = @ir.hot_child_count(func, node_id)
  for slot = 0; slot < child_count; slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      continue
    }
    match @ir.hot_node_get(func, child_id).op {
      @ir.HotOp::Block => ()
      _ => continue
    }
    if @ir.hot_node_result_arity(func, child_id) != 1 {
      continue
    }
    let label_id = @ir.hot_control_node_label(func, child_id)
    if pass_label_is_used(label_id, label_used) {
      continue
    }
    let body_ref = @ir.hot_region_body_ref(func, child_id)
    if @ir.hot_region_root_count(func, body_ref) != 1 {
      continue
    }
    let value_id = @ir.hot_region_get(func, body_ref, 0)
    if value_id < 0 ||
      !@ir.hot_node_is_live(func, value_id) ||
      @ir.hot_node_result_arity(func, value_id) != 1 {
      continue
    }
    @ir.hot_child_set(func, node_id, slot, value_id)
    @ir.hot_region_replace_body(func, body_ref, [])
    if !@ir.hot_delete_detached_control_forest(func, [child_id]) {
      abort("precompute failed to delete detached transparent value block")
    }
    pass_mark_mutated(ctx, func)
    return true
  }
  false
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
  precompute_replace_node_rehoming_control_label(
    func,
    node_id,
    @ir.hot_node_get(func, nop),
  )
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
        @ir.HotOp::Block | @ir.HotOp::Loop => {
          if region_ref == @ir.HotRegionRef::root() &&
            precompute_loop_is_const_true_self_br_if_with_result_tail(
              ctx, func, node_id, idx,
            ) {
            let label = @ir.hot_control_node_label(func, node_id)
            @ir.hot_region_replace_body(
              func,
              @ir.hot_region_body_ref(func, node_id),
              [@ir.hot_build_br(func, label)],
            )
            let root_count = @ir.hot_region_root_count(func, region_ref)
            let removed = pass_splice_region(
              ctx,
              func,
              region_ref,
              idx + 1,
              root_count - idx - 1,
              [@ir.hot_build_unreachable(func)],
            )
            pass_delete_detached_nodes(ctx, func, removed)
            changed = true
            continue
          }
          if region_ref == @ir.HotRegionRef::root() &&
            precompute_control_is_const_self_br_if_noop(ctx, func, node_id) {
            let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [
              @ir.hot_build_nop(func),
            ])
            pass_delete_detached_nodes(ctx, func, removed)
            changed = true
            continue
          }
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
                  // Preserve the old if label on a detached empty block before
                  // splicing the chosen arm into the parent region. Deleting the
                  // detached owner would leave the label table pointing at a dead
                  // control node.
                  @ir.hot_control_demote_if_to_block(func, node_id, [])
                  ignore(
                    pass_splice_region(
                      ctx, func, region_ref, idx, 1, replacement,
                    ),
                  )
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
fn precompute_control_is_const_self_br_if_noop(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  control_id : Int,
) -> Bool {
  if @ir.hot_node_result_arity(func, control_id) != 0 {
    return false
  }
  let op = @ir.hot_node_get(func, control_id).op
  match op {
    @ir.HotOp::Block | @ir.HotOp::Loop => ()
    _ => return false
  }
  let label = @ir.hot_control_node_label(func, control_id)
  if label < 0 || @ir.hot_label_branch_arity(func, label) != 0 {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, control_id)
  if @ir.hot_region_root_count(func, body_ref) != 1 {
    return false
  }
  let branch_id = @ir.hot_region_get(func, body_ref, 0)
  let branch_node = @ir.hot_node_get(func, branch_id)
  match branch_node.op {
    @ir.HotOp::BrIf => ()
    _ => return false
  }
  if branch_node.child_count != 1 || branch_node.imm0 != label {
    return false
  }
  let cond_id = @ir.hot_child_get(func, branch_id, 0)
  match precompute_i32_exact_const(ctx, func, cond_id) {
    Some(@lib.I32(0)) => true
    Some(@lib.I32(_)) =>
      match op {
        @ir.HotOp::Block => true
        _ => false
      }
    None => false
  }
}

///|
fn precompute_root_suffix_has_result(
  func : @ir.HotFunc,
  start_idx : Int,
) -> Bool {
  let region_ref = @ir.HotRegionRef::root()
  let root_count = @ir.hot_region_root_count(func, region_ref)
  let mut idx = start_idx
  while idx < root_count {
    let root_id = @ir.hot_region_get(func, region_ref, idx)
    if @ir.hot_node_is_live(func, root_id) &&
      @ir.hot_node_result_arity(func, root_id) > 0 {
      return true
    }
    idx = idx + 1
  }
  false
}

///|
fn precompute_loop_is_const_true_self_br_if_with_result_tail(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  loop_id : Int,
  root_idx : Int,
) -> Bool {
  match @ir.hot_node_get(func, loop_id).op {
    @ir.HotOp::Loop => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, loop_id) != 0 {
    return false
  }
  if !precompute_root_suffix_has_result(func, root_idx + 1) {
    return false
  }
  let label = @ir.hot_control_node_label(func, loop_id)
  if label < 0 || @ir.hot_label_branch_arity(func, label) != 0 {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  if @ir.hot_region_root_count(func, body_ref) != 1 {
    return false
  }
  let branch_id = @ir.hot_region_get(func, body_ref, 0)
  let branch_node = @ir.hot_node_get(func, branch_id)
  match branch_node.op {
    @ir.HotOp::BrIf => ()
    _ => return false
  }
  if branch_node.child_count != 1 || branch_node.imm0 != label {
    return false
  }
  let cond_id = @ir.hot_child_get(func, branch_id, 0)
  match precompute_i32_exact_const(ctx, func, cond_id) {
    Some(@lib.I32(0)) | None => false
    Some(@lib.I32(_)) => true
  }
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
fn precompute_raw_f32_const(instr : @lib.Instruction) -> @lib.F32? {
  match instr {
    @lib.F32Const(value) => Some(value)
    _ => None
  }
}

///|
fn precompute_raw_f64_const(instr : @lib.Instruction) -> @lib.F64? {
  match instr {
    @lib.F64Const(value) => Some(value)
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
fn precompute_raw_f32_nearest(value : Float) -> Float {
  if value.is_nan() ||
    value >= Float::from_double(8388608.0) ||
    value <= Float::from_double(-8388608.0) {
    return value
  }
  let lower = value.floor()
  let fraction = value - lower
  let rounded = if fraction < Float::from_double(0.5) {
    lower
  } else if fraction > Float::from_double(0.5) {
    lower + Float::from_double(1.0)
  } else if (lower.to_int() & 1) == 0 {
    lower
  } else {
    lower + Float::from_double(1.0)
  }
  if rounded == Float::from_double(0.0) &&
    (value.reinterpret_as_uint() & 0x80000000U) != 0U {
    Float::reinterpret_from_uint(0x80000000U)
  } else {
    rounded
  }
}

///|
fn precompute_raw_f64_nearest(value : Double) -> Double {
  if value.is_nan() ||
    value >= 4503599627370496.0 ||
    value <= -4503599627370496.0 {
    return value
  }
  let lower = value.floor()
  let fraction = value - lower
  let rounded = if fraction < 0.5 {
    lower
  } else if fraction > 0.5 {
    lower + 1.0
  } else if (lower.to_int64() & 1L) == 0L {
    lower
  } else {
    lower + 1.0
  }
  if rounded == 0.0 &&
    (value.reinterpret_as_uint64() & 0x8000000000000000UL) != 0UL {
    0x8000000000000000UL.reinterpret_as_double()
  } else {
    rounded
  }
}

///|
fn precompute_raw_try_fold_i32_trunc(
  value : Double,
  signed : Bool,
  saturating : Bool,
) -> @lib.Instruction? {
  if signed {
    if saturating {
      let result = if value.is_nan() {
        0
      } else if value <= -2147483648.0 {
        -2147483647 - 1
      } else if value >= 2147483648.0 {
        2147483647
      } else {
        value.to_int()
      }
      return Some(@lib.Instruction::i32_const(@lib.I32(result)))
    }
    if value.is_nan() || value < -2147483648.0 || value >= 2147483648.0 {
      return None
    }
    return Some(@lib.Instruction::i32_const(@lib.I32(value.to_int())))
  }
  if saturating {
    let result = if value.is_nan() || value <= 0.0 {
      0U
    } else if value >= 4294967296.0 {
      0xffffffffU
    } else {
      value.to_uint()
    }
    return Some(
      @lib.Instruction::i32_const(@lib.I32(result.reinterpret_as_int())),
    )
  }
  if value.is_nan() || value < 0.0 || value >= 4294967296.0 {
    return None
  }
  Some(
    @lib.Instruction::i32_const(@lib.I32(value.to_uint().reinterpret_as_int())),
  )
}

///|
fn precompute_trunc_double_to_uint64(value : Double) -> UInt64 {
  if value < 9223372036854775808.0 {
    value.to_int64().reinterpret_as_uint64()
  } else {
    (value - 9223372036854775808.0).to_int64().reinterpret_as_uint64() |
    0x8000000000000000UL
  }
}

///|
fn precompute_raw_try_fold_i64_trunc(
  value : Double,
  signed : Bool,
  saturating : Bool,
) -> @lib.Instruction? {
  if signed {
    if saturating {
      let result = if value.is_nan() {
        0L
      } else if value <= -9223372036854775808.0 {
        -9223372036854775807L - 1L
      } else if value >= 9223372036854775808.0 {
        9223372036854775807L
      } else {
        value.to_int64()
      }
      return Some(@lib.Instruction::i64_const(@lib.I64(result)))
    }
    if value.is_nan() ||
      value < -9223372036854775808.0 ||
      value >= 9223372036854775808.0 {
      return None
    }
    return Some(@lib.Instruction::i64_const(@lib.I64(value.to_int64())))
  }
  if saturating {
    let result = if value.is_nan() || value <= 0.0 {
      0UL
    } else if value >= 18446744073709551616.0 {
      0xffffffffffffffffUL
    } else {
      precompute_trunc_double_to_uint64(value)
    }
    return Some(
      @lib.Instruction::i64_const(@lib.I64(result.reinterpret_as_int64())),
    )
  }
  if value.is_nan() || value < 0.0 || value >= 18446744073709551616.0 {
    return None
  }
  Some(
    @lib.Instruction::i64_const(
      @lib.I64(precompute_trunc_double_to_uint64(value).reinterpret_as_int64()),
    ),
  )
}

///|
fn precompute_raw_try_fold_unary(
  operand : @lib.Instruction,
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  match (instr, precompute_raw_i32_const(operand)) {
    (@lib.Instruction::I32Eqz, Some(v)) =>
      return Some(precompute_raw_bool(v == @lib.I32(0)))
    (@lib.Instruction::I32Clz, Some(@lib.I32(v))) =>
      return Some(
        @lib.Instruction::i32_const(@lib.I32(v.reinterpret_as_uint().clz())),
      )
    (@lib.Instruction::I32Ctz, Some(@lib.I32(v))) =>
      return Some(
        @lib.Instruction::i32_const(@lib.I32(v.reinterpret_as_uint().ctz())),
      )
    (@lib.Instruction::I32Popcnt, Some(@lib.I32(v))) =>
      return Some(
        @lib.Instruction::i32_const(@lib.I32(v.reinterpret_as_uint().popcnt())),
      )
    (@lib.Instruction::I64ExtendI32S, Some(@lib.I32(v))) =>
      return Some(@lib.Instruction::i64_const(@lib.I64(v.to_int64())))
    (@lib.Instruction::I64ExtendI32U, Some(@lib.I32(v))) =>
      return Some(
        @lib.Instruction::i64_const(
          @lib.I64(v.reinterpret_as_uint().to_uint64().reinterpret_as_int64()),
        ),
      )
    (@lib.Instruction::F32ConvertI32S, Some(@lib.I32(v))) =>
      return Some(@lib.Instruction::f32_const(@lib.F32(Float::from_int(v))))
    (@lib.Instruction::F32ConvertI32U, Some(@lib.I32(v))) =>
      return Some(
        @lib.Instruction::f32_const(
          @lib.F32(Float::from_uint(v.reinterpret_as_uint())),
        ),
      )
    (@lib.Instruction::F64ConvertI32S, Some(@lib.I32(v))) =>
      return Some(@lib.Instruction::f64_const(@lib.F64(v.to_double())))
    (@lib.Instruction::F64ConvertI32U, Some(@lib.I32(v))) =>
      return Some(
        @lib.Instruction::f64_const(
          @lib.F64(v.reinterpret_as_uint().to_double()),
        ),
      )
    (@lib.Instruction::F32ReinterpretI32, Some(@lib.I32(v))) =>
      return Some(
        @lib.Instruction::f32_const(
          @lib.F32(Float::reinterpret_from_uint(v.reinterpret_as_uint())),
        ),
      )
    (@lib.Instruction::I32Extend8S, Some(@lib.I32(v))) =>
      return Some(@lib.Instruction::i32_const(@lib.I32(v << 24 >> 24)))
    (@lib.Instruction::I32Extend16S, Some(@lib.I32(v))) =>
      return Some(@lib.Instruction::i32_const(@lib.I32(v << 16 >> 16)))
    _ => ()
  }
  match (instr, precompute_raw_i64_const(operand)) {
    (@lib.Instruction::I64Eqz, Some(v)) =>
      return Some(precompute_raw_bool(v == @lib.I64(0L)))
    (@lib.Instruction::I64Clz, Some(@lib.I64(v))) =>
      return Some(
        @lib.Instruction::i64_const(
          @lib.I64(v.reinterpret_as_uint64().clz().to_int64()),
        ),
      )
    (@lib.Instruction::I64Ctz, Some(@lib.I64(v))) =>
      return Some(
        @lib.Instruction::i64_const(
          @lib.I64(v.reinterpret_as_uint64().ctz().to_int64()),
        ),
      )
    (@lib.Instruction::I64Popcnt, Some(@lib.I64(v))) =>
      return Some(
        @lib.Instruction::i64_const(
          @lib.I64(v.reinterpret_as_uint64().popcnt().to_int64()),
        ),
      )
    (@lib.Instruction::I32WrapI64, Some(@lib.I64(v))) =>
      return Some(
        @lib.Instruction::i32_const(
          @lib.I32(v.reinterpret_as_uint64().to_uint().reinterpret_as_int()),
        ),
      )
    (@lib.Instruction::F32ConvertI64S, Some(@lib.I64(v))) =>
      return Some(
        @lib.Instruction::f32_const(@lib.F32(Float::from_double(v.to_double()))),
      )
    (@lib.Instruction::F32ConvertI64U, Some(@lib.I64(v))) =>
      return Some(
        @lib.Instruction::f32_const(
          @lib.F32(Float::from_double(v.reinterpret_as_uint64().to_double())),
        ),
      )
    (@lib.Instruction::F64ConvertI64S, Some(@lib.I64(v))) =>
      return Some(@lib.Instruction::f64_const(@lib.F64(v.to_double())))
    (@lib.Instruction::F64ConvertI64U, Some(@lib.I64(v))) =>
      return Some(
        @lib.Instruction::f64_const(
          @lib.F64(v.reinterpret_as_uint64().to_double()),
        ),
      )
    (@lib.Instruction::F64ReinterpretI64, Some(@lib.I64(v))) =>
      return Some(
        @lib.Instruction::f64_const(
          @lib.F64(v.reinterpret_as_uint64().reinterpret_as_double()),
        ),
      )
    (@lib.Instruction::I64Extend8S, Some(@lib.I64(v))) =>
      return Some(@lib.Instruction::i64_const(@lib.I64(v << 56 >> 56)))
    (@lib.Instruction::I64Extend16S, Some(@lib.I64(v))) =>
      return Some(@lib.Instruction::i64_const(@lib.I64(v << 48 >> 48)))
    (@lib.Instruction::I64Extend32S, Some(@lib.I64(v))) =>
      return Some(@lib.Instruction::i64_const(@lib.I64(v << 32 >> 32)))
    _ => ()
  }
  match (instr, precompute_raw_f32_const(operand)) {
    (@lib.Instruction::F32Abs, Some(@lib.F32(v))) =>
      return Some(
        @lib.Instruction::f32_const(
          @lib.F32(
            Float::reinterpret_from_uint(v.reinterpret_as_uint() & 0x7fffffffU),
          ),
        ),
      )
    (@lib.Instruction::F32Neg, Some(@lib.F32(v))) =>
      return Some(
        @lib.Instruction::f32_const(
          @lib.F32(
            Float::reinterpret_from_uint(v.reinterpret_as_uint() ^ 0x80000000U),
          ),
        ),
      )
    (@lib.Instruction::F32Ceil, Some(@lib.F32(v))) =>
      return Some(
        @lib.Instruction::f32_const(
          @lib.F32(
            if v.is_nan() {
              Float::reinterpret_from_uint(0x7fc00000U)
            } else {
              v.ceil()
            },
          ),
        ),
      )
    (@lib.Instruction::F32Floor, Some(@lib.F32(v))) =>
      return Some(
        @lib.Instruction::f32_const(
          @lib.F32(
            if v.is_nan() {
              Float::reinterpret_from_uint(0x7fc00000U)
            } else {
              v.floor()
            },
          ),
        ),
      )
    (@lib.Instruction::F32Trunc, Some(@lib.F32(v))) =>
      return Some(
        @lib.Instruction::f32_const(
          @lib.F32(
            if v.is_nan() {
              Float::reinterpret_from_uint(0x7fc00000U)
            } else {
              v.trunc()
            },
          ),
        ),
      )
    (@lib.Instruction::F32Nearest, Some(@lib.F32(v))) =>
      return Some(
        @lib.Instruction::f32_const(
          @lib.F32(
            if v.is_nan() {
              Float::reinterpret_from_uint(0x7fc00000U)
            } else {
              precompute_raw_f32_nearest(v)
            },
          ),
        ),
      )
    (@lib.Instruction::F32Sqrt, Some(@lib.F32(v))) =>
      return Some(
        @lib.Instruction::f32_const(
          @lib.F32(
            if v.is_nan() || v < Float::from_double(0.0) {
              Float::reinterpret_from_uint(0x7fc00000U)
            } else {
              v.sqrt()
            },
          ),
        ),
      )
    (@lib.Instruction::F64PromoteF32, Some(@lib.F32(v))) =>
      return Some(
        @lib.Instruction::f64_const(
          @lib.F64(
            if v.is_nan() {
              0x7ff8000000000000UL.reinterpret_as_double()
            } else {
              v.to_double()
            },
          ),
        ),
      )
    (@lib.Instruction::I32ReinterpretF32, Some(@lib.F32(v))) =>
      return Some(
        @lib.Instruction::i32_const(
          @lib.I32(v.reinterpret_as_uint().reinterpret_as_int()),
        ),
      )
    (@lib.Instruction::I32TruncF32S, Some(@lib.F32(v))) =>
      return precompute_raw_try_fold_i32_trunc(v.to_double(), true, false)
    (@lib.Instruction::I32TruncF32U, Some(@lib.F32(v))) =>
      return precompute_raw_try_fold_i32_trunc(v.to_double(), false, false)
    (@lib.Instruction::I64TruncF32S, Some(@lib.F32(v))) =>
      return precompute_raw_try_fold_i64_trunc(v.to_double(), true, false)
    (@lib.Instruction::I64TruncF32U, Some(@lib.F32(v))) =>
      return precompute_raw_try_fold_i64_trunc(v.to_double(), false, false)
    (@lib.Instruction::I32TruncSatF32S, Some(@lib.F32(v))) =>
      return precompute_raw_try_fold_i32_trunc(v.to_double(), true, true)
    (@lib.Instruction::I32TruncSatF32U, Some(@lib.F32(v))) =>
      return precompute_raw_try_fold_i32_trunc(v.to_double(), false, true)
    (@lib.Instruction::I64TruncSatF32S, Some(@lib.F32(v))) =>
      return precompute_raw_try_fold_i64_trunc(v.to_double(), true, true)
    (@lib.Instruction::I64TruncSatF32U, Some(@lib.F32(v))) =>
      return precompute_raw_try_fold_i64_trunc(v.to_double(), false, true)
    _ => ()
  }
  match (instr, precompute_raw_f64_const(operand)) {
    (@lib.Instruction::F64Abs, Some(@lib.F64(v))) =>
      Some(
        @lib.Instruction::f64_const(
          @lib.F64(
            (v.reinterpret_as_uint64() & 0x7fffffffffffffffUL).reinterpret_as_double(),
          ),
        ),
      )
    (@lib.Instruction::F64Neg, Some(@lib.F64(v))) =>
      Some(
        @lib.Instruction::f64_const(
          @lib.F64(
            (v.reinterpret_as_uint64() ^ 0x8000000000000000UL).reinterpret_as_double(),
          ),
        ),
      )
    (@lib.Instruction::F64Ceil, Some(@lib.F64(v))) =>
      Some(
        @lib.Instruction::f64_const(
          @lib.F64(
            if v.is_nan() {
              0x7ff8000000000000UL.reinterpret_as_double()
            } else {
              v.ceil()
            },
          ),
        ),
      )
    (@lib.Instruction::F64Floor, Some(@lib.F64(v))) =>
      Some(
        @lib.Instruction::f64_const(
          @lib.F64(
            if v.is_nan() {
              0x7ff8000000000000UL.reinterpret_as_double()
            } else {
              v.floor()
            },
          ),
        ),
      )
    (@lib.Instruction::F64Trunc, Some(@lib.F64(v))) =>
      Some(
        @lib.Instruction::f64_const(
          @lib.F64(
            if v.is_nan() {
              0x7ff8000000000000UL.reinterpret_as_double()
            } else {
              v.trunc()
            },
          ),
        ),
      )
    (@lib.Instruction::F64Nearest, Some(@lib.F64(v))) =>
      Some(
        @lib.Instruction::f64_const(
          @lib.F64(
            if v.is_nan() {
              0x7ff8000000000000UL.reinterpret_as_double()
            } else {
              precompute_raw_f64_nearest(v)
            },
          ),
        ),
      )
    (@lib.Instruction::F64Sqrt, Some(@lib.F64(v))) =>
      Some(
        @lib.Instruction::f64_const(
          @lib.F64(
            if v.is_nan() || v < 0.0 {
              0x7ff8000000000000UL.reinterpret_as_double()
            } else {
              v.sqrt()
            },
          ),
        ),
      )
    (@lib.Instruction::F32DemoteF64, Some(@lib.F64(v))) =>
      Some(
        @lib.Instruction::f32_const(
          @lib.F32(
            if v.is_nan() {
              Float::reinterpret_from_uint(0x7fc00000U)
            } else {
              Float::from_double(v)
            },
          ),
        ),
      )
    (@lib.Instruction::I64ReinterpretF64, Some(@lib.F64(v))) =>
      Some(
        @lib.Instruction::i64_const(
          @lib.I64(v.reinterpret_as_uint64().reinterpret_as_int64()),
        ),
      )
    (@lib.Instruction::I32TruncF64S, Some(@lib.F64(v))) =>
      precompute_raw_try_fold_i32_trunc(v, true, false)
    (@lib.Instruction::I32TruncF64U, Some(@lib.F64(v))) =>
      precompute_raw_try_fold_i32_trunc(v, false, false)
    (@lib.Instruction::I64TruncF64S, Some(@lib.F64(v))) =>
      precompute_raw_try_fold_i64_trunc(v, true, false)
    (@lib.Instruction::I64TruncF64U, Some(@lib.F64(v))) =>
      precompute_raw_try_fold_i64_trunc(v, false, false)
    (@lib.Instruction::I32TruncSatF64S, Some(@lib.F64(v))) =>
      precompute_raw_try_fold_i32_trunc(v, true, true)
    (@lib.Instruction::I32TruncSatF64U, Some(@lib.F64(v))) =>
      precompute_raw_try_fold_i32_trunc(v, false, true)
    (@lib.Instruction::I64TruncSatF64S, Some(@lib.F64(v))) =>
      precompute_raw_try_fold_i64_trunc(v, true, true)
    (@lib.Instruction::I64TruncSatF64U, Some(@lib.F64(v))) =>
      precompute_raw_try_fold_i64_trunc(v, false, true)
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
    (@lib.Instruction::I32Rotl, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      let shift = rhs.reinterpret_as_uint() & 31U
      let value = lhs.reinterpret_as_uint()
      let rotated = if shift == 0U {
        value
      } else {
        (value << shift.reinterpret_as_int()) |
        (value >> (32 - shift.reinterpret_as_int()))
      }
      return Some(
        @lib.Instruction::i32_const(@lib.I32(rotated.reinterpret_as_int())),
      )
    }
    (@lib.Instruction::I32Rotr, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      let shift = rhs.reinterpret_as_uint() & 31U
      let value = lhs.reinterpret_as_uint()
      let rotated = if shift == 0U {
        value
      } else {
        (value >> shift.reinterpret_as_int()) |
        (value << (32 - shift.reinterpret_as_int()))
      }
      return Some(
        @lib.Instruction::i32_const(@lib.I32(rotated.reinterpret_as_int())),
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
    (@lib.Instruction::I32DivS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      if rhs == 0 || (lhs == -2147483648 && rhs == -1) {
        return None
      }
      return Some(@lib.Instruction::i32_const(@lib.I32(lhs / rhs)))
    }
    (@lib.Instruction::I32DivU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      let divisor = rhs.reinterpret_as_uint()
      if divisor == 0U {
        return None
      }
      return Some(
        @lib.Instruction::i32_const(
          @lib.I32((lhs.reinterpret_as_uint() / divisor).reinterpret_as_int()),
        ),
      )
    }
    (@lib.Instruction::I32RemS, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      if rhs == 0 {
        return None
      }
      let value = if lhs == -2147483648 && rhs == -1 { 0 } else { lhs % rhs }
      return Some(@lib.Instruction::i32_const(@lib.I32(value)))
    }
    (@lib.Instruction::I32RemU, Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      let divisor = rhs.reinterpret_as_uint()
      if divisor == 0U {
        return None
      }
      return Some(
        @lib.Instruction::i32_const(
          @lib.I32((lhs.reinterpret_as_uint() % divisor).reinterpret_as_int()),
        ),
      )
    }
    _ => ()
  }
  match
    (
      instr,
      precompute_raw_i64_const(lhs_instr),
      precompute_raw_i64_const(rhs_instr),
    ) {
    (@lib.Instruction::I64Add, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      return Some(
        @lib.Instruction::i64_const(
          @lib.I64(
            (lhs.reinterpret_as_uint64() + rhs.reinterpret_as_uint64()).reinterpret_as_int64(),
          ),
        ),
      )
    (@lib.Instruction::I64Sub, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      return Some(
        @lib.Instruction::i64_const(
          @lib.I64(
            (lhs.reinterpret_as_uint64() - rhs.reinterpret_as_uint64()).reinterpret_as_int64(),
          ),
        ),
      )
    (@lib.Instruction::I64Mul, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      return Some(
        @lib.Instruction::i64_const(
          @lib.I64(
            (lhs.reinterpret_as_uint64() * rhs.reinterpret_as_uint64()).reinterpret_as_int64(),
          ),
        ),
      )
    (@lib.Instruction::I64And, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      return Some(@lib.Instruction::i64_const(@lib.I64(lhs & rhs)))
    (@lib.Instruction::I64Or, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      return Some(@lib.Instruction::i64_const(@lib.I64(lhs | rhs)))
    (@lib.Instruction::I64Xor, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      return Some(@lib.Instruction::i64_const(@lib.I64(lhs ^ rhs)))
    (@lib.Instruction::I64Shl, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      let shift = rhs.reinterpret_as_uint64() & 63UL
      return Some(
        @lib.Instruction::i64_const(
          @lib.I64(
            (lhs.reinterpret_as_uint64() << shift.to_int()).reinterpret_as_int64(),
          ),
        ),
      )
    }
    (@lib.Instruction::I64ShrU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      let shift = rhs.reinterpret_as_uint64() & 63UL
      return Some(
        @lib.Instruction::i64_const(
          @lib.I64(
            (lhs.reinterpret_as_uint64() >> shift.to_int()).reinterpret_as_int64(),
          ),
        ),
      )
    }
    (@lib.Instruction::I64ShrS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      let shift = rhs.reinterpret_as_uint64() & 63UL
      return Some(@lib.Instruction::i64_const(@lib.I64(lhs >> shift.to_int())))
    }
    (@lib.Instruction::I64Rotl, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      let shift = rhs.reinterpret_as_uint64() & 63UL
      let value = lhs.reinterpret_as_uint64()
      let rotated = if shift == 0UL {
        value
      } else {
        (value << shift.to_int()) | (value >> (64 - shift.to_int()))
      }
      return Some(
        @lib.Instruction::i64_const(@lib.I64(rotated.reinterpret_as_int64())),
      )
    }
    (@lib.Instruction::I64Rotr, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      let shift = rhs.reinterpret_as_uint64() & 63UL
      let value = lhs.reinterpret_as_uint64()
      let rotated = if shift == 0UL {
        value
      } else {
        (value >> shift.to_int()) | (value << (64 - shift.to_int()))
      }
      return Some(
        @lib.Instruction::i64_const(@lib.I64(rotated.reinterpret_as_int64())),
      )
    }
    (@lib.Instruction::I64Eq, Some(lhs), Some(rhs)) =>
      return Some(precompute_raw_bool(lhs == rhs))
    (@lib.Instruction::I64Ne, Some(lhs), Some(rhs)) =>
      return Some(precompute_raw_bool(lhs != rhs))
    (@lib.Instruction::I64LtS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      return Some(precompute_raw_bool(lhs < rhs))
    (@lib.Instruction::I64LtU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      return Some(
        precompute_raw_bool(
          lhs.reinterpret_as_uint64() < rhs.reinterpret_as_uint64(),
        ),
      )
    (@lib.Instruction::I64GtS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      return Some(precompute_raw_bool(lhs > rhs))
    (@lib.Instruction::I64GtU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      return Some(
        precompute_raw_bool(
          lhs.reinterpret_as_uint64() > rhs.reinterpret_as_uint64(),
        ),
      )
    (@lib.Instruction::I64LeS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      return Some(precompute_raw_bool(lhs <= rhs))
    (@lib.Instruction::I64LeU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      return Some(
        precompute_raw_bool(
          lhs.reinterpret_as_uint64() <= rhs.reinterpret_as_uint64(),
        ),
      )
    (@lib.Instruction::I64GeS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      return Some(precompute_raw_bool(lhs >= rhs))
    (@lib.Instruction::I64GeU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) =>
      return Some(
        precompute_raw_bool(
          lhs.reinterpret_as_uint64() >= rhs.reinterpret_as_uint64(),
        ),
      )
    (@lib.Instruction::I64DivS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      if rhs == 0L || (lhs == -9223372036854775808L && rhs == -1L) {
        return None
      }
      return Some(@lib.Instruction::i64_const(@lib.I64(lhs / rhs)))
    }
    (@lib.Instruction::I64DivU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      let divisor = rhs.reinterpret_as_uint64()
      if divisor == 0UL {
        return None
      }
      return Some(
        @lib.Instruction::i64_const(
          @lib.I64(
            (lhs.reinterpret_as_uint64() / divisor).reinterpret_as_int64(),
          ),
        ),
      )
    }
    (@lib.Instruction::I64RemS, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      if rhs == 0L {
        return None
      }
      let value = if lhs == -9223372036854775808L && rhs == -1L {
        0L
      } else {
        lhs % rhs
      }
      return Some(@lib.Instruction::i64_const(@lib.I64(value)))
    }
    (@lib.Instruction::I64RemU, Some(@lib.I64(lhs)), Some(@lib.I64(rhs))) => {
      let divisor = rhs.reinterpret_as_uint64()
      if divisor == 0UL {
        return None
      }
      return Some(
        @lib.Instruction::i64_const(
          @lib.I64(
            (lhs.reinterpret_as_uint64() % divisor).reinterpret_as_int64(),
          ),
        ),
      )
    }
    _ => ()
  }
  match
    (
      instr,
      precompute_raw_f32_const(lhs_instr),
      precompute_raw_f32_const(rhs_instr),
    ) {
    (@lib.Instruction::F32Add, Some(@lib.F32(lhs)), Some(@lib.F32(rhs))) => {
      let value = lhs + rhs
      return Some(
        @lib.Instruction::f32_const(
          @lib.F32(
            if value.is_nan() {
              Float::reinterpret_from_uint(0x7fc00000U)
            } else {
              value
            },
          ),
        ),
      )
    }
    (@lib.Instruction::F32Sub, Some(@lib.F32(lhs)), Some(@lib.F32(rhs))) => {
      let value = lhs - rhs
      return Some(
        @lib.Instruction::f32_const(
          @lib.F32(
            if value.is_nan() {
              Float::reinterpret_from_uint(0x7fc00000U)
            } else {
              value
            },
          ),
        ),
      )
    }
    (@lib.Instruction::F32Mul, Some(@lib.F32(lhs)), Some(@lib.F32(rhs))) => {
      let value = lhs * rhs
      return Some(
        @lib.Instruction::f32_const(
          @lib.F32(
            if value.is_nan() {
              Float::reinterpret_from_uint(0x7fc00000U)
            } else {
              value
            },
          ),
        ),
      )
    }
    (@lib.Instruction::F32Div, Some(@lib.F32(lhs)), Some(@lib.F32(rhs))) => {
      let value = lhs / rhs
      return Some(
        @lib.Instruction::f32_const(
          @lib.F32(
            if value.is_nan() {
              Float::reinterpret_from_uint(0x7fc00000U)
            } else {
              value
            },
          ),
        ),
      )
    }
    (@lib.Instruction::F32Min, Some(@lib.F32(lhs)), Some(@lib.F32(rhs))) => {
      if lhs.is_nan() || rhs.is_nan() {
        return Some(
          @lib.Instruction::f32_const(
            @lib.F32(Float::reinterpret_from_uint(0x7fc00000U)),
          ),
        )
      }
      let value = if lhs == rhs {
        if lhs == Float::from_double(0.0) &&
          (
            (lhs.reinterpret_as_uint() | rhs.reinterpret_as_uint()) &
            0x80000000U
          ) !=
          0U {
          Float::reinterpret_from_uint(0x80000000U)
        } else {
          lhs
        }
      } else if lhs < rhs {
        lhs
      } else {
        rhs
      }
      return Some(@lib.Instruction::f32_const(@lib.F32(value)))
    }
    (@lib.Instruction::F32Max, Some(@lib.F32(lhs)), Some(@lib.F32(rhs))) => {
      if lhs.is_nan() || rhs.is_nan() {
        return Some(
          @lib.Instruction::f32_const(
            @lib.F32(Float::reinterpret_from_uint(0x7fc00000U)),
          ),
        )
      }
      let value = if lhs == rhs {
        if lhs == Float::from_double(0.0) {
          if (
              lhs.reinterpret_as_uint() &
              rhs.reinterpret_as_uint() &
              0x80000000U
            ) !=
            0U {
            Float::reinterpret_from_uint(0x80000000U)
          } else {
            Float::reinterpret_from_uint(0U)
          }
        } else {
          lhs
        }
      } else if lhs > rhs {
        lhs
      } else {
        rhs
      }
      return Some(@lib.Instruction::f32_const(@lib.F32(value)))
    }
    (@lib.Instruction::F32Copysign, Some(@lib.F32(lhs)), Some(@lib.F32(rhs))) =>
      return Some(
        @lib.Instruction::f32_const(
          @lib.F32(
            Float::reinterpret_from_uint(
              (lhs.reinterpret_as_uint() & 0x7fffffffU) |
              (rhs.reinterpret_as_uint() & 0x80000000U),
            ),
          ),
        ),
      )
    (@lib.Instruction::F32Eq, Some(@lib.F32(lhs)), Some(@lib.F32(rhs))) =>
      return Some(precompute_raw_bool(lhs == rhs))
    (@lib.Instruction::F32Ne, Some(@lib.F32(lhs)), Some(@lib.F32(rhs))) =>
      return Some(precompute_raw_bool(lhs != rhs))
    (@lib.Instruction::F32Lt, Some(@lib.F32(lhs)), Some(@lib.F32(rhs))) =>
      return Some(precompute_raw_bool(lhs < rhs))
    (@lib.Instruction::F32Gt, Some(@lib.F32(lhs)), Some(@lib.F32(rhs))) =>
      return Some(precompute_raw_bool(lhs > rhs))
    (@lib.Instruction::F32Le, Some(@lib.F32(lhs)), Some(@lib.F32(rhs))) =>
      return Some(precompute_raw_bool(lhs <= rhs))
    (@lib.Instruction::F32Ge, Some(@lib.F32(lhs)), Some(@lib.F32(rhs))) =>
      return Some(precompute_raw_bool(lhs >= rhs))
    _ => ()
  }
  match
    (
      instr,
      precompute_raw_f64_const(lhs_instr),
      precompute_raw_f64_const(rhs_instr),
    ) {
    (@lib.Instruction::F64Add, Some(@lib.F64(lhs)), Some(@lib.F64(rhs))) => {
      let value = lhs + rhs
      Some(
        @lib.Instruction::f64_const(
          @lib.F64(
            if value.is_nan() {
              0x7ff8000000000000UL.reinterpret_as_double()
            } else {
              value
            },
          ),
        ),
      )
    }
    (@lib.Instruction::F64Sub, Some(@lib.F64(lhs)), Some(@lib.F64(rhs))) => {
      let value = lhs - rhs
      Some(
        @lib.Instruction::f64_const(
          @lib.F64(
            if value.is_nan() {
              0x7ff8000000000000UL.reinterpret_as_double()
            } else {
              value
            },
          ),
        ),
      )
    }
    (@lib.Instruction::F64Mul, Some(@lib.F64(lhs)), Some(@lib.F64(rhs))) => {
      let value = lhs * rhs
      Some(
        @lib.Instruction::f64_const(
          @lib.F64(
            if value.is_nan() {
              0x7ff8000000000000UL.reinterpret_as_double()
            } else {
              value
            },
          ),
        ),
      )
    }
    (@lib.Instruction::F64Div, Some(@lib.F64(lhs)), Some(@lib.F64(rhs))) => {
      let value = lhs / rhs
      Some(
        @lib.Instruction::f64_const(
          @lib.F64(
            if value.is_nan() {
              0x7ff8000000000000UL.reinterpret_as_double()
            } else {
              value
            },
          ),
        ),
      )
    }
    (@lib.Instruction::F64Min, Some(@lib.F64(lhs)), Some(@lib.F64(rhs))) => {
      if lhs.is_nan() || rhs.is_nan() {
        return Some(
          @lib.Instruction::f64_const(
            @lib.F64(0x7ff8000000000000UL.reinterpret_as_double()),
          ),
        )
      }
      let value = if lhs == rhs {
        if lhs == 0.0 &&
          (
            (lhs.reinterpret_as_uint64() | rhs.reinterpret_as_uint64()) &
            0x8000000000000000UL
          ) !=
          0UL {
          0x8000000000000000UL.reinterpret_as_double()
        } else {
          lhs
        }
      } else if lhs < rhs {
        lhs
      } else {
        rhs
      }
      Some(@lib.Instruction::f64_const(@lib.F64(value)))
    }
    (@lib.Instruction::F64Max, Some(@lib.F64(lhs)), Some(@lib.F64(rhs))) => {
      if lhs.is_nan() || rhs.is_nan() {
        return Some(
          @lib.Instruction::f64_const(
            @lib.F64(0x7ff8000000000000UL.reinterpret_as_double()),
          ),
        )
      }
      let value = if lhs == rhs {
        if lhs == 0.0 {
          if (
              lhs.reinterpret_as_uint64() &
              rhs.reinterpret_as_uint64() &
              0x8000000000000000UL
            ) !=
            0UL {
            0x8000000000000000UL.reinterpret_as_double()
          } else {
            0.0
          }
        } else {
          lhs
        }
      } else if lhs > rhs {
        lhs
      } else {
        rhs
      }
      Some(@lib.Instruction::f64_const(@lib.F64(value)))
    }
    (@lib.Instruction::F64Copysign, Some(@lib.F64(lhs)), Some(@lib.F64(rhs))) =>
      Some(
        @lib.Instruction::f64_const(
          @lib.F64(
            ((lhs.reinterpret_as_uint64() & 0x7fffffffffffffffUL) |
            (rhs.reinterpret_as_uint64() & 0x8000000000000000UL)).reinterpret_as_double(),
          ),
        ),
      )
    (@lib.Instruction::F64Eq, Some(@lib.F64(lhs)), Some(@lib.F64(rhs))) =>
      Some(precompute_raw_bool(lhs == rhs))
    (@lib.Instruction::F64Ne, Some(@lib.F64(lhs)), Some(@lib.F64(rhs))) =>
      Some(precompute_raw_bool(lhs != rhs))
    (@lib.Instruction::F64Lt, Some(@lib.F64(lhs)), Some(@lib.F64(rhs))) =>
      Some(precompute_raw_bool(lhs < rhs))
    (@lib.Instruction::F64Gt, Some(@lib.F64(lhs)), Some(@lib.F64(rhs))) =>
      Some(precompute_raw_bool(lhs > rhs))
    (@lib.Instruction::F64Le, Some(@lib.F64(lhs)), Some(@lib.F64(rhs))) =>
      Some(precompute_raw_bool(lhs <= rhs))
    (@lib.Instruction::F64Ge, Some(@lib.F64(lhs)), Some(@lib.F64(rhs))) =>
      Some(precompute_raw_bool(lhs >= rhs))
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
    @lib.Instruction::I32Eqz
    | @lib.Instruction::I64Eqz
    | @lib.Instruction::I32Clz
    | @lib.Instruction::I32Ctz
    | @lib.Instruction::I32Popcnt
    | @lib.Instruction::I64Clz
    | @lib.Instruction::I64Ctz
    | @lib.Instruction::I64Popcnt
    | @lib.Instruction::F32Abs
    | @lib.Instruction::F32Neg
    | @lib.Instruction::F32Ceil
    | @lib.Instruction::F32Floor
    | @lib.Instruction::F32Trunc
    | @lib.Instruction::F32Nearest
    | @lib.Instruction::F32Sqrt
    | @lib.Instruction::F64Abs
    | @lib.Instruction::F64Neg
    | @lib.Instruction::F64Ceil
    | @lib.Instruction::F64Floor
    | @lib.Instruction::F64Trunc
    | @lib.Instruction::F64Nearest
    | @lib.Instruction::F64Sqrt
    | @lib.Instruction::I32WrapI64
    | @lib.Instruction::I64ExtendI32S
    | @lib.Instruction::I64ExtendI32U
    | @lib.Instruction::F32ConvertI32S
    | @lib.Instruction::F32ConvertI32U
    | @lib.Instruction::F32ConvertI64S
    | @lib.Instruction::F32ConvertI64U
    | @lib.Instruction::F64ConvertI32S
    | @lib.Instruction::F64ConvertI32U
    | @lib.Instruction::F64ConvertI64S
    | @lib.Instruction::F64ConvertI64U
    | @lib.Instruction::F32DemoteF64
    | @lib.Instruction::F64PromoteF32
    | @lib.Instruction::I32ReinterpretF32
    | @lib.Instruction::I64ReinterpretF64
    | @lib.Instruction::F32ReinterpretI32
    | @lib.Instruction::F64ReinterpretI64
    | @lib.Instruction::I32Extend8S
    | @lib.Instruction::I32Extend16S
    | @lib.Instruction::I64Extend8S
    | @lib.Instruction::I64Extend16S
    | @lib.Instruction::I64Extend32S
    | @lib.Instruction::I32TruncSatF32S
    | @lib.Instruction::I32TruncSatF32U
    | @lib.Instruction::I32TruncSatF64S
    | @lib.Instruction::I32TruncSatF64U
    | @lib.Instruction::I64TruncSatF32S
    | @lib.Instruction::I64TruncSatF32U
    | @lib.Instruction::I64TruncSatF64S
    | @lib.Instruction::I64TruncSatF64U
    | @lib.Instruction::RefIsNull => true
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
    | @lib.Instruction::I64GeU
    | @lib.Instruction::I32Rotl
    | @lib.Instruction::I32Rotr
    | @lib.Instruction::I64Rotl
    | @lib.Instruction::I64Rotr
    | @lib.Instruction::F32Add
    | @lib.Instruction::F32Sub
    | @lib.Instruction::F32Mul
    | @lib.Instruction::F32Div
    | @lib.Instruction::F32Min
    | @lib.Instruction::F32Max
    | @lib.Instruction::F32Copysign
    | @lib.Instruction::F32Eq
    | @lib.Instruction::F32Ne
    | @lib.Instruction::F32Lt
    | @lib.Instruction::F32Gt
    | @lib.Instruction::F32Le
    | @lib.Instruction::F32Ge
    | @lib.Instruction::F64Add
    | @lib.Instruction::F64Sub
    | @lib.Instruction::F64Mul
    | @lib.Instruction::F64Div
    | @lib.Instruction::F64Min
    | @lib.Instruction::F64Max
    | @lib.Instruction::F64Copysign
    | @lib.Instruction::F64Eq
    | @lib.Instruction::F64Ne
    | @lib.Instruction::F64Lt
    | @lib.Instruction::F64Gt
    | @lib.Instruction::F64Le
    | @lib.Instruction::F64Ge => true
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
fn precompute_raw_loop_is_unconditional_self_branch(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Loop(block_type, @lib.Expr([@lib.Br(@lib.LabelIdx(0U))])) =>
      block_type == @lib.BlockType::void_()
    _ => false
  }
}

///|
fn precompute_raw_try_mark_value_tail_after_infinite_loop(
  out : Array[@lib.Instruction],
) -> Bool {
  if out.length() < 2 {
    return false
  }
  let mut loop_idx = 0
  while loop_idx + 1 < out.length() {
    if precompute_raw_loop_is_unconditional_self_branch(out[loop_idx]) {
      let mut suffix_idx = loop_idx + 1
      let mut has_value_tail = false
      let mut suffix_supported = true
      while suffix_idx < out.length() {
        match out[suffix_idx] {
          @lib.Nop => ()
          instr if precompute_raw_instr_is_flat_discardable_value(instr) =>
            has_value_tail = true
          _ => suffix_supported = false
        }
        suffix_idx = suffix_idx + 1
      }
      if suffix_supported && has_value_tail {
        while out.length() > loop_idx + 1 {
          ignore(out.pop())
        }
        out.push(@lib.Instruction::unreachable_())
        return true
      }
    }
    loop_idx = loop_idx + 1
  }
  false
}

///|
fn precompute_raw_try_partial_select_unary_tail(
  out : Array[@lib.Instruction],
) -> Bool {
  if out.length() < 5 {
    return false
  }
  let base = out.length() - 5
  let select_instr = match out[base + 3] {
    @lib.Select(_) => out[base + 3]
    _ => return false
  }
  let folded_true = match
    precompute_raw_try_fold_unary(out[base], out[base + 4]) {
    Some(value) => value
    None => return false
  }
  let folded_false = match
    precompute_raw_try_fold_unary(out[base + 1], out[base + 4]) {
    Some(value) => value
    None => return false
  }
  let condition = out[base + 2]
  while out.length() > base {
    ignore(out.pop())
  }
  out.push(folded_true)
  out.push(folded_false)
  out.push(condition)
  out.push(select_instr)
  true
}

///|
fn precompute_raw_try_partial_select_tail(
  out : Array[@lib.Instruction],
) -> Bool {
  if out.length() < 6 {
    return false
  }
  let base = out.length() - 6
  let op = out[base + 5]
  let select_lhs = match out[base + 3] {
    @lib.Select(_) => true
    _ => false
  }
  let select_rhs = match out[base + 4] {
    @lib.Select(_) => true
    _ => false
  }
  let (true_value, false_value, condition, select_instr, other, select_is_lhs) = if select_lhs {
    (
      out[base],
      out[base + 1],
      out[base + 2],
      out[base + 3],
      out[base + 4],
      true,
    )
  } else if select_rhs {
    (
      out[base + 1],
      out[base + 2],
      out[base + 3],
      out[base + 4],
      out[base],
      false,
    )
  } else {
    return false
  }
  let folded_true = match
    (if select_is_lhs {
      precompute_raw_try_fold_binary(true_value, other, op)
    } else {
      precompute_raw_try_fold_binary(other, true_value, op)
    }) {
    Some(value) => value
    None => return false
  }
  let folded_false = match
    (if select_is_lhs {
      precompute_raw_try_fold_binary(false_value, other, op)
    } else {
      precompute_raw_try_fold_binary(other, false_value, op)
    }) {
    Some(value) => value
    None => return false
  }
  while out.length() > base {
    ignore(out.pop())
  }
  out.push(folded_true)
  out.push(folded_false)
  out.push(condition)
  out.push(select_instr)
  true
}

///|
fn precompute_raw_is_literal_const(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.RefNull(_)
    | @lib.StringConst(_) => true
    _ => false
  }
}

///|
fn precompute_raw_effectful_block_const(
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  let body = match instr {
    @lib.Block(_, @lib.Expr(body)) => body
    _ => return None
  }
  if body.length() < 3 ||
    !precompute_raw_is_literal_const(body[body.length() - 1]) {
    return None
  }
  let mut slot = 0
  while slot + 1 < body.length() {
    if !precompute_raw_is_literal_const(body[slot]) {
      return None
    }
    match body[slot + 1] {
      @lib.LocalSet(_) | @lib.GlobalSet(_) => ()
      _ => return None
    }
    slot = slot + 2
  }
  if slot != body.length() - 1 {
    return None
  }
  Some(body[body.length() - 1])
}

///|
fn precompute_write_utf8_scalar(buf : @buffer.Buffer, scalar : Int) -> Unit {
  if scalar <= 0x7f {
    buf.write_byte(scalar.to_byte())
  } else if scalar <= 0x7ff {
    buf.write_byte((0xc0 | (scalar >> 6)).to_byte())
    buf.write_byte((0x80 | (scalar & 0x3f)).to_byte())
  } else if scalar <= 0xffff {
    buf.write_byte((0xe0 | (scalar >> 12)).to_byte())
    buf.write_byte((0x80 | ((scalar >> 6) & 0x3f)).to_byte())
    buf.write_byte((0x80 | (scalar & 0x3f)).to_byte())
  } else {
    buf.write_byte((0xf0 | (scalar >> 18)).to_byte())
    buf.write_byte((0x80 | ((scalar >> 12) & 0x3f)).to_byte())
    buf.write_byte((0x80 | ((scalar >> 6) & 0x3f)).to_byte())
    buf.write_byte((0x80 | (scalar & 0x3f)).to_byte())
  }
}

///|
fn precompute_raw_try_fold_string_new_wtf16_tail(
  out : Array[@lib.Instruction],
) -> Bool {
  if out.length() < 4 ||
    out[out.length() - 1] != @lib.Instruction::string_new_wtf16_array() {
    return false
  }
  let (start, length) = match (out[out.length() - 3], out[out.length() - 2]) {
    (@lib.I32Const(@lib.I32(start)), @lib.I32Const(@lib.I32(length))) =>
      (start, length)
    _ => return false
  }
  if start < 0 || length < 0 {
    return false
  }
  let count = match out[out.length() - 4] {
    @lib.ArrayNewFixed(_, @lib.U32(count)) => count.reinterpret_as_int()
    _ => return false
  }
  let value_start = out.length() - 4 - count
  if value_start < 0 || start > count || length > count - start {
    return false
  }
  let units : Array[Int] = []
  for slot = 0; slot < count; slot = slot + 1 {
    match out[value_start + slot] {
      @lib.I32Const(@lib.I32(value)) => units.push(value & 0xffff)
      _ => return false
    }
  }
  let bytes = @buffer.new(size_hint=length * 3)
  let end = start + length
  let mut slot = start
  while slot < end {
    let unit = units[slot]
    if unit >= 0xd800 && unit <= 0xdbff {
      if slot + 1 >= end {
        return false
      }
      let low = units[slot + 1]
      if low < 0xdc00 || low > 0xdfff {
        return false
      }
      let scalar = 0x10000 + ((unit - 0xd800) << 10) + (low - 0xdc00)
      precompute_write_utf8_scalar(bytes, scalar)
      slot = slot + 2
    } else if unit >= 0xdc00 && unit <= 0xdfff {
      return false
    } else {
      precompute_write_utf8_scalar(bytes, unit)
      slot = slot + 1
    }
  }
  for pop_idx = 0; pop_idx < count + 4; pop_idx = pop_idx + 1 {
    ignore(pop_idx)
    ignore(out.pop())
  }
  out.push(@lib.Instruction::string_const(bytes.to_bytes()))
  true
}

///|
fn precompute_raw_fold_output_tail(out : Array[@lib.Instruction]) -> Bool {
  if precompute_raw_try_fold_string_new_wtf16_tail(out) {
    return true
  }
  if precompute_raw_try_fold_const_if_tail(out) {
    return true
  }
  if precompute_raw_try_partial_select_unary_tail(out) ||
    precompute_raw_try_partial_select_tail(out) {
    return true
  }
  if precompute_raw_try_mark_value_tail_after_infinite_loop(out) {
    return true
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
fn precompute_raw_void_block_is_selector_only_self_br_table(
  instrs : Array[@lib.Instruction],
) -> Bool {
  if instrs.length() != 2 {
    return false
  }
  match instrs[0] {
    @lib.I32Const(_) => ()
    _ => return false
  }
  let (targets, fallback) = match instrs[1] {
    @lib.BrTable(targets, fallback) => (targets, fallback)
    _ => return false
  }
  if fallback != @lib.LabelIdx::new(0U) {
    return false
  }
  for target in targets {
    if target != @lib.LabelIdx::new(0U) {
      return false
    }
  }
  true
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
      if block_type == @lib.BlockType::void_() {
        if precompute_raw_void_block_is_selector_only_self_br_table(next_body) {
          return (@lib.Instruction::nop(), true)
        }
        if next_body.length() == 1 {
          match next_body[0] {
            @lib.Br(@lib.LabelIdx(0U)) => return (@lib.Instruction::nop(), true)
            _ => ()
          }
        }
        if precompute_raw_instrs_are_all_nops(next_body) {
          return (@lib.Instruction::nop(), true)
        }
      }
      if changed {
        (@lib.Instruction::block(block_type, @lib.Expr::new(next_body)), true)
      } else {
        (instr, false)
      }
    }
    @lib.Loop(block_type, @lib.Expr(body)) => {
      let (next_body, changed) = precompute_raw_rewrite_instrs(body, module_ctx)
      if block_type == @lib.BlockType::void_() &&
        precompute_raw_instrs_are_all_nops(next_body) {
        return (@lib.Instruction::nop(), true)
      }
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
    @lib.BrTable(_, _)
    | @lib.StructGet(_, _)
    | @lib.StructGetS(_, _)
    | @lib.StructGetU(_, _)
    | @lib.ArrayGet(_)
    | @lib.ArrayGetS(_)
    | @lib.ArrayGetU(_)
    | @lib.ArrayLen
    | @lib.RefEq
    | @lib.RefTest(_, _, _) => true
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
    | @lib.RefCast(_, _, _)
    | @lib.RefCastDescEq(_, _, _)
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
  if precompute_raw_root_nop_cleanup_candidate(instrs) {
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
fn precompute_raw_instr_has_atomic_fence(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.AtomicFence => true
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) =>
      precompute_raw_instrs_have_atomic_fence(body)
    @lib.If(_, then_body, else_body) => {
      if precompute_raw_instrs_have_atomic_fence(then_body) {
        return true
      }
      match else_body {
        Some(body) => precompute_raw_instrs_have_atomic_fence(body)
        None => false
      }
    }
    _ => false
  }
}

///|
fn precompute_raw_instrs_have_atomic_fence(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    if precompute_raw_instr_has_atomic_fence(instr) {
      return true
    }
  }
  false
}

///|
fn precompute_raw_instr_has_memory_grow(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.MemoryGrow(_) => true
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
      precompute_raw_instrs_have_memory_grow(body)
    @lib.If(_, then_body, else_body) => {
      if precompute_raw_instrs_have_memory_grow(then_body) {
        return true
      }
      match else_body {
        Some(body) => precompute_raw_instrs_have_memory_grow(body)
        None => false
      }
    }
    @lib.TryTable(_, _, @lib.Expr(body)) =>
      precompute_raw_instrs_have_memory_grow(body)
    _ => false
  }
}

///|
fn precompute_raw_instrs_have_memory_grow(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    if precompute_raw_instr_has_memory_grow(instr) {
      return true
    }
  }
  false
}

///|
fn precompute_run_raw_around_atomic_fence(
  func : @lib.Func,
  module_ctx : @ir.HotModuleContext?,
) -> (@lib.Func, Bool)? {
  let @lib.Func(locals, @lib.Expr(instrs)) = func
  if !precompute_raw_instrs_have_atomic_fence(instrs) {
    return None
  }
  let (rewritten, changed) = precompute_raw_rewrite_instrs(instrs, module_ctx)
  Some((@lib.Func::new(locals, @lib.Expr::new(rewritten)), changed))
}

///|
fn precompute_raw_default_local_const(ty : @lib.ValType) -> @lib.Instruction? {
  match ty {
    @lib.NumTypeValType(@lib.I32NumType) =>
      Some(@lib.Instruction::i32_const(@lib.I32(0)))
    @lib.NumTypeValType(@lib.I64NumType) =>
      Some(@lib.Instruction::i64_const(@lib.I64(0L)))
    @lib.NumTypeValType(@lib.F32NumType) =>
      Some(@lib.Instruction::f32_const(@lib.F32(0.0)))
    @lib.NumTypeValType(@lib.F64NumType) =>
      Some(@lib.Instruction::f64_const(@lib.F64(0.0)))
    @lib.RefTypeValType(ref_type) =>
      Some(@lib.Instruction::ref_null_type(ref_type))
    _ => None
  }
}

///|
fn precompute_raw_instr_is_foldable_binary(instr : @lib.Instruction) -> Bool {
  if precompute_raw_instr_is_nontrapping_binary_op(instr) {
    return true
  }
  match instr {
    @lib.I32DivS
    | @lib.I32DivU
    | @lib.I32RemS
    | @lib.I32RemU
    | @lib.I64DivS
    | @lib.I64DivU
    | @lib.I64RemS
    | @lib.I64RemU
    | @lib.F32Add
    | @lib.F32Sub
    | @lib.F32Mul
    | @lib.F32Div
    | @lib.F32Eq
    | @lib.F32Ne
    | @lib.F32Lt
    | @lib.F32Gt
    | @lib.F32Le
    | @lib.F32Ge
    | @lib.F64Add
    | @lib.F64Sub
    | @lib.F64Mul
    | @lib.F64Div
    | @lib.F64Eq
    | @lib.F64Ne
    | @lib.F64Lt
    | @lib.F64Gt
    | @lib.F64Le
    | @lib.F64Ge => true
    _ => false
  }
}

///|
fn precompute_raw_mark_written_locals(
  instrs : Array[@lib.Instruction],
  written : Array[Bool],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(raw_local))
      | @lib.LocalTee(@lib.LocalIdx(raw_local)) => {
        let local_id = raw_local.reinterpret_as_int()
        if local_id >= 0 && local_id < written.length() {
          written[local_id] = true
        }
      }
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        precompute_raw_mark_written_locals(body, written)
      @lib.If(_, then_body, else_body) => {
        precompute_raw_mark_written_locals(then_body, written)
        match else_body {
          Some(body) => precompute_raw_mark_written_locals(body, written)
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        precompute_raw_mark_written_locals(body, written)
      _ => ()
    }
  }
}

///|
fn precompute_propagate_run_raw_instrs(
  instrs : Array[@lib.Instruction],
  local_values : Array[@lib.Instruction?],
  module_ctx : @ir.HotModuleContext?,
) -> (Array[@lib.Instruction], Array[@lib.Instruction?], Bool)? {
  let stack : Array[@lib.Instruction?] = []
  let rewritten : Array[@lib.Instruction] = []
  let mut changed = false
  for instr_idx = 0; instr_idx < instrs.length(); instr_idx = instr_idx + 1 {
    let instr = instrs[instr_idx]
    match instr {
      @lib.I32Const(_)
      | @lib.I64Const(_)
      | @lib.F32Const(_)
      | @lib.F64Const(_)
      | @lib.RefNull(_)
      | @lib.StringConst(_) => {
        rewritten.push(instr)
        stack.push(Some(instr))
      }
      @lib.LocalGet(@lib.LocalIdx(raw_local)) => {
        let local_id = raw_local.reinterpret_as_int()
        if local_id < 0 || local_id >= local_values.length() {
          return None
        }
        match local_values[local_id] {
          Some(value) => {
            rewritten.push(value)
            stack.push(Some(value))
            changed = true
          }
          None => {
            rewritten.push(instr)
            stack.push(None)
          }
        }
      }
      @lib.LocalSet(@lib.LocalIdx(raw_local)) => {
        let local_id = raw_local.reinterpret_as_int()
        if local_id < 0 ||
          local_id >= local_values.length() ||
          stack.length() == 0 {
          return None
        }
        local_values[local_id] = stack.pop().unwrap()
        rewritten.push(instr)
      }
      @lib.LocalTee(@lib.LocalIdx(raw_local)) => {
        let local_id = raw_local.reinterpret_as_int()
        if local_id < 0 ||
          local_id >= local_values.length() ||
          stack.length() == 0 {
          return None
        }
        local_values[local_id] = stack[stack.length() - 1]
        rewritten.push(instr)
      }
      @lib.Loop(@lib.VoidBlockType, @lib.Expr(body)) => {
        let before_values = local_values.copy()
        let body_values_in = local_values.copy()
        let written = Array::make(local_values.length(), false)
        precompute_raw_mark_written_locals(body, written)
        for local_id = 0
            local_id < body_values_in.length()
            local_id = local_id + 1 {
          if written[local_id] {
            body_values_in[local_id] = None
          }
        }
        let (next_body, body_values, body_changed) = match
          precompute_propagate_run_raw_instrs(body, body_values_in, module_ctx) {
          Some(result) => result
          None => return None
        }
        for local_id = 0
            local_id < local_values.length()
            local_id = local_id + 1 {
          if before_values[local_id] == body_values[local_id] {
            local_values[local_id] = before_values[local_id]
          } else {
            local_values[local_id] = None
          }
        }
        rewritten.push(
          @lib.Instruction::loop_(
            @lib.BlockType::void_(),
            @lib.Expr::new(next_body),
          ),
        )
        if body_changed {
          changed = true
        }
      }
      @lib.If(block_type, then_body, else_body) => {
        if stack.length() == 0 {
          return None
        }
        ignore(stack.pop())
        let has_result = match block_type {
          @lib.VoidBlockType => false
          @lib.ValTypeBlockType(_) => true
          @lib.TypeIdxBlockType(_) => return None
        }
        if has_result && else_body is None {
          return None
        }
        let (next_then, then_values, then_changed) = match
          precompute_propagate_run_raw_instrs(
            then_body,
            local_values.copy(),
            module_ctx,
          ) {
          Some(result) => result
          None => return None
        }
        let (next_else, else_values, else_changed) = match else_body {
          Some(body) =>
            match
              precompute_propagate_run_raw_instrs(
                body,
                local_values.copy(),
                module_ctx,
              ) {
              Some((next_body, values, body_changed)) =>
                (Some(next_body), values, body_changed)
              None => return None
            }
          None => (None, local_values.copy(), false)
        }
        for local_id = 0
            local_id < local_values.length()
            local_id = local_id + 1 {
          if then_values[local_id] == else_values[local_id] {
            local_values[local_id] = then_values[local_id]
          } else {
            local_values[local_id] = None
          }
        }
        rewritten.push(@lib.Instruction::if_(block_type, next_then, next_else))
        if has_result {
          stack.push(None)
        }
        if then_changed || else_changed {
          changed = true
        }
      }
      @lib.I32Store(_)
      | @lib.I64Store(_)
      | @lib.F32Store(_)
      | @lib.F64Store(_)
      | @lib.I32Store8(_)
      | @lib.I32Store16(_)
      | @lib.I64Store8(_)
      | @lib.I64Store16(_)
      | @lib.I64Store32(_) => {
        if stack.length() < 2 {
          return None
        }
        ignore(stack.pop())
        ignore(stack.pop())
        rewritten.push(instr)
      }
      @lib.MemorySize(_) => {
        rewritten.push(instr)
        stack.push(None)
      }
      @lib.MemoryGrow(_) => {
        if stack.length() == 0 {
          return None
        }
        ignore(stack.pop())
        rewritten.push(instr)
        stack.push(None)
      }
      @lib.Drop => {
        if stack.length() == 0 {
          return None
        }
        ignore(stack.pop())
        rewritten.push(instr)
      }
      @lib.GlobalSet(_) => {
        if stack.length() == 0 {
          return None
        }
        ignore(stack.pop())
        rewritten.push(instr)
      }
      @lib.Call(_) => {
        rewritten.push(instr)
        stack.clear()
      }
      @lib.Br(_) => {
        rewritten.push(instr)
        for rest_idx = instr_idx + 1
            rest_idx < instrs.length()
            rest_idx = rest_idx + 1 {
          rewritten.push(instrs[rest_idx])
        }
        return Some((rewritten, local_values, changed))
      }
      @lib.Nop => rewritten.push(instr)
      @lib.Unreachable => {
        rewritten.push(instr)
        stack.clear()
      }
      op if precompute_raw_instr_is_nontrapping_unary_op(op) => {
        if stack.length() == 0 {
          return None
        }
        let operand = stack.pop().unwrap()
        stack.push(
          match operand {
            Some(value) => precompute_raw_try_fold_unary(value, op)
            None => None
          },
        )
        rewritten.push(instr)
      }
      op if precompute_raw_instr_is_foldable_binary(op) => {
        if stack.length() < 2 {
          return None
        }
        let rhs = stack.pop().unwrap()
        let lhs = stack.pop().unwrap()
        stack.push(
          match (lhs, rhs) {
            (Some(lhs), Some(rhs)) =>
              precompute_raw_try_fold_binary(lhs, rhs, op)
            _ => None
          },
        )
        rewritten.push(instr)
      }
      _ => {
        if !changed {
          return None
        }
        rewritten.push(instr)
        for rest_idx = instr_idx + 1
            rest_idx < instrs.length()
            rest_idx = rest_idx + 1 {
          rewritten.push(instrs[rest_idx])
        }
        for local_id = 0
            local_id < local_values.length()
            local_id = local_id + 1 {
          local_values[local_id] = None
        }
        let (folded, folded_changed) = precompute_raw_rewrite_instrs(
          rewritten, module_ctx,
        )
        return Some((folded, local_values, changed || folded_changed))
      }
    }
  }
  let (folded, folded_changed) = precompute_raw_rewrite_instrs(
    rewritten, module_ctx,
  )
  Some((folded, local_values, changed || folded_changed))
}

///|
fn precompute_propagate_run_raw_straight_line_func(
  func : @lib.Func,
  params : Array[@lib.ValType],
  module_ctx : @ir.HotModuleContext?,
) -> (@lib.Func, Bool)? {
  let @lib.Func(locals, @lib.Expr(instrs)) = func
  let local_values : Array[@lib.Instruction?] = Array::make(
    params.length() + locals.length(),
    None,
  )
  for idx = 0; idx < locals.length(); idx = idx + 1 {
    local_values[params.length() + idx] = precompute_raw_default_local_const(
      locals.get(idx),
    )
  }
  match precompute_propagate_run_raw_instrs(instrs, local_values, module_ctx) {
    Some((rewritten, _, changed)) =>
      Some((@lib.Func::new(locals, @lib.Expr::new(rewritten)), changed))
    None => None
  }
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
    let label_used = pass_compute_label_used(func)
    for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
      if !@ir.hot_node_is_live(func, node_id) {
        continue
      }
      if precompute_try_inline_transparent_value_block_child(
          ctx, func, node_id, label_used,
        ) {
        changed_round = true
        changed_any = true
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
      if precompute_try_fold_gc_identity(ctx, func, node_id) ||
        precompute_try_fold_fresh_ref_test(ctx, func, node_id) ||
        precompute_try_fold_fresh_struct_get(ctx, func, node_id) ||
        precompute_try_fold_fresh_array_len(ctx, func, node_id) ||
        precompute_try_fold_fresh_array_get(ctx, func, node_id) {
        changed_round = true
        changed_any = true
        continue
      }
      let instr = match @ir.hot_node_exact_instr(func, node_id) {
        Some(instr) => instr
        None => continue
      }
      if precompute_try_partial_select_parent(ctx, func, node_id, instr) ||
        precompute_try_fold_effectful_parent(ctx, func, node_id, instr) {
        changed_round = true
        changed_any = true
        continue
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
  label_used : @bitset.BitSet,
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
        ctx, func, ssa, label_used, value_id, states, value_consts,
      )
    }
    // Binaryen's propagate mode reasons from a set value's fallthrough value.
    // Peel value-preserving tees and unbranched single-result blocks while
    // leaving the original wrapper and its effects in place.
    @ir.HotOp::LocalTee =>
      if @ir.hot_child_count(func, node_id) == 1 {
        return precompute_propagate_prefix_const_for_node(
          ctx,
          func,
          ssa,
          label_used,
          @ir.hot_child_get(func, node_id, 0),
          states,
          value_consts,
        )
      }
    @ir.HotOp::Block => {
      let label_id = @ir.hot_control_node_label(func, node_id)
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      let body_count = @ir.hot_region_root_count(func, body_ref)
      if @ir.hot_node_result_arity(func, node_id) == 1 &&
        !pass_label_is_used(label_id, label_used) &&
        body_count > 0 {
        return precompute_propagate_prefix_const_for_node(
          ctx,
          func,
          ssa,
          label_used,
          @ir.hot_region_get(func, body_ref, body_count - 1),
          states,
          value_consts,
        )
      }
    }
    @ir.HotOp::If => {
      let cond_id = @ir.hot_child_get(func, node_id, 0)
      let take_then = match
        precompute_propagate_prefix_const_for_node(
          ctx, func, ssa, label_used, cond_id, states, value_consts,
        ) {
        Some(@ir.HotConstPayload::I32Const(@lib.I32(0))) => false
        Some(@ir.HotConstPayload::I32Const(_)) => true
        _ => return None
      }
      let chosen = if take_then {
        Some(@ir.hot_region_then_ref(func, node_id))
      } else {
        @ir.hot_region_else_ref(func, node_id)
      }
      match chosen {
        Some(region_ref) => {
          let root_count = @ir.hot_region_root_count(func, region_ref)
          if root_count > 0 {
            return precompute_propagate_prefix_const_for_node(
              ctx,
              func,
              ssa,
              label_used,
              @ir.hot_region_get(func, region_ref, root_count - 1),
              states,
              value_consts,
            )
          }
        }
        None => ()
      }
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
        label_used,
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
        label_used,
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
        label_used,
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
  label_used : @bitset.BitSet,
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
            label_used,
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
              label_used,
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
fn precompute_propagate_mark_result_if_arm_writes(
  func : @ir.HotFunc,
  node_id : Int,
  inside_result_if_arm : Bool,
  unsafe_locals : Array[Bool],
) -> Unit {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
      if inside_result_if_arm &&
        node.imm0 >= 0 &&
        node.imm0 < unsafe_locals.length() {
        unsafe_locals[node.imm0] = true
      }
    _ => ()
  }
  match node.op {
    @ir.HotOp::If => {
      precompute_propagate_mark_result_if_arm_writes(
        func,
        @ir.hot_child_get(func, node_id, 0),
        inside_result_if_arm,
        unsafe_locals,
      )
      let arm_is_unsafe = inside_result_if_arm ||
        @ir.hot_node_result_arity(func, node_id) > 0
      let then_ref = @ir.hot_region_then_ref(func, node_id)
      for idx = 0
          idx < @ir.hot_region_root_count(func, then_ref)
          idx = idx + 1 {
        precompute_propagate_mark_result_if_arm_writes(
          func,
          @ir.hot_region_get(func, then_ref, idx),
          arm_is_unsafe,
          unsafe_locals,
        )
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) =>
          for idx = 0
              idx < @ir.hot_region_root_count(func, else_ref)
              idx = idx + 1 {
            precompute_propagate_mark_result_if_arm_writes(
              func,
              @ir.hot_region_get(func, else_ref, idx),
              arm_is_unsafe,
              unsafe_locals,
            )
          }
        None => ()
      }
    }
    _ =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        precompute_propagate_mark_result_if_arm_writes(
          func,
          @ir.hot_child_get(func, node_id, slot),
          inside_result_if_arm,
          unsafe_locals,
        )
      }
  }
}

///|
fn precompute_propagate_collect_condition_const_writes(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  local_consts : Array[@ir.HotConstPayload?],
) -> Unit {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    precompute_propagate_collect_condition_const_writes(
      ctx,
      func,
      @ir.hot_child_get(func, node_id, slot),
      local_consts,
    )
  }
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => {
      let local_id = node.imm0
      if local_id >= 0 &&
        local_id < local_consts.length() &&
        @ir.hot_child_count(func, node_id) == 1 {
        local_consts[local_id] = precompute_propagate_prefix_const_payload_from_node(
          ctx,
          func,
          @ir.hot_child_get(func, node_id, 0),
        )
      }
    }
    _ => ()
  }
}

///|
fn precompute_propagate_mark_arm_direct_const_gets(
  func : @ir.HotFunc,
  node_id : Int,
  condition_consts : Array[@ir.HotConstPayload?],
  arm_written : Array[Bool],
  get_consts : Array[@ir.HotConstPayload?],
) -> Unit {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop => {
      let body = @ir.hot_region_body_ref(func, node_id)
      for idx = 0; idx < @ir.hot_region_root_count(func, body); idx = idx + 1 {
        precompute_propagate_mark_arm_direct_const_gets(
          func,
          @ir.hot_region_get(func, body, idx),
          condition_consts,
          arm_written,
          get_consts,
        )
      }
      return
    }
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    precompute_propagate_mark_arm_direct_const_gets(
      func,
      @ir.hot_child_get(func, node_id, slot),
      condition_consts,
      arm_written,
      get_consts,
    )
  }
  match node.op {
    @ir.HotOp::LocalGet => {
      let local_id = node.imm0
      if local_id >= 0 &&
        local_id < condition_consts.length() &&
        !arm_written[local_id] {
        get_consts[node_id] = condition_consts[local_id]
      }
    }
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => {
      let local_id = node.imm0
      if local_id >= 0 && local_id < arm_written.length() {
        arm_written[local_id] = true
      }
    }
    _ => ()
  }
}

///|
fn precompute_propagate_mark_result_if_direct_const_gets(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  get_consts : Array[@ir.HotConstPayload?],
) -> Unit {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If => {
      let condition_id = @ir.hot_child_get(func, node_id, 0)
      precompute_propagate_mark_result_if_direct_const_gets(
        ctx, func, condition_id, get_consts,
      )
      let then_ref = @ir.hot_region_then_ref(func, node_id)
      let else_ref = @ir.hot_region_else_ref(func, node_id)
      if @ir.hot_node_result_arity(func, node_id) > 0 {
        let condition_consts : Array[@ir.HotConstPayload?] = Array::make(
          @ir.hot_local_count(func),
          None,
        )
        precompute_propagate_collect_condition_const_writes(
          ctx, func, condition_id, condition_consts,
        )
        let then_written = Array::make(@ir.hot_local_count(func), false)
        for idx = 0
            idx < @ir.hot_region_root_count(func, then_ref)
            idx = idx + 1 {
          precompute_propagate_mark_arm_direct_const_gets(
            func,
            @ir.hot_region_get(func, then_ref, idx),
            condition_consts,
            then_written,
            get_consts,
          )
        }
        match else_ref {
          Some(region_ref) => {
            let else_written = Array::make(@ir.hot_local_count(func), false)
            for idx = 0
                idx < @ir.hot_region_root_count(func, region_ref)
                idx = idx + 1 {
              precompute_propagate_mark_arm_direct_const_gets(
                func,
                @ir.hot_region_get(func, region_ref, idx),
                condition_consts,
                else_written,
                get_consts,
              )
            }
          }
          None => ()
        }
      }
      for idx = 0
          idx < @ir.hot_region_root_count(func, then_ref)
          idx = idx + 1 {
        precompute_propagate_mark_result_if_direct_const_gets(
          ctx,
          func,
          @ir.hot_region_get(func, then_ref, idx),
          get_consts,
        )
      }
      match else_ref {
        Some(region_ref) =>
          for idx = 0
              idx < @ir.hot_region_root_count(func, region_ref)
              idx = idx + 1 {
            precompute_propagate_mark_result_if_direct_const_gets(
              ctx,
              func,
              @ir.hot_region_get(func, region_ref, idx),
              get_consts,
            )
          }
        None => ()
      }
    }
    @ir.HotOp::Block | @ir.HotOp::Loop => {
      let body = @ir.hot_region_body_ref(func, node_id)
      for idx = 0; idx < @ir.hot_region_root_count(func, body); idx = idx + 1 {
        precompute_propagate_mark_result_if_direct_const_gets(
          ctx,
          func,
          @ir.hot_region_get(func, body, idx),
          get_consts,
        )
      }
    }
    _ =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        precompute_propagate_mark_result_if_direct_const_gets(
          ctx,
          func,
          @ir.hot_child_get(func, node_id, slot),
          get_consts,
        )
      }
  }
}

///|
fn precompute_propagate_prefix_fold_local_gets(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Bool {
  let ssa = pass_require_ssa(ctx, func)
  let label_used = pass_compute_label_used(func)
  let states = Array::make(ssa.value_types.length(), 0)
  let value_consts : Array[@ir.HotConstPayload?] = Array::make(
    ssa.value_types.length(),
    None,
  )
  let result_if_arm_written = Array::make(@ir.hot_local_count(func), false)
  let result_if_direct_get_consts : Array[@ir.HotConstPayload?] = Array::make(
    @ir.hot_node_count(func),
    None,
  )
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    precompute_propagate_mark_result_if_direct_const_gets(
      ctx,
      func,
      @ir.hot_root_get(func, root_idx),
      result_if_direct_get_consts,
    )
    precompute_propagate_mark_result_if_arm_writes(
      func,
      @ir.hot_root_get(func, root_idx),
      false,
      result_if_arm_written,
    )
  }
  let replacements : Array[PrecomputePropagatePrefixReplacement] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::LocalGet => {
        let local_id = @ir.hot_node_get(func, node_id).imm0
        match result_if_direct_get_consts[node_id] {
          Some(payload) => {
            replacements.push({ node_id, payload })
            continue
          }
          None => ()
        }
        let value_id = ssa.local_get_values[node_id]
        if value_id < 0 {
          continue
        }
        if local_id >= 0 &&
          local_id < result_if_arm_written.length() &&
          result_if_arm_written[local_id] {
          // A real phi proves CFG/SSA observed both result-if arms. If SSA
          // reports a stale entry or prior definition instead, retain the get.
          match @ir.ssa_value_origin(ssa, value_id) {
            @ir.HotSsaValueOrigin::PhiDef(_) => ()
            _ => continue
          }
        }
        // Outside result-producing if arms, trust the SSA origin directly.
        // In particular, an entry-default read before a later write is a real
        // constant, even when that local is written elsewhere in the function.
        match
          precompute_propagate_prefix_const_for_value(
            ctx, func, ssa, label_used, value_id, states, value_consts,
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
    precompute_replace_node_rehoming_control_label(
      func,
      replacement.node_id,
      next_node,
    )
    pass_mark_mutated(ctx, func)
  }
  true
}

///|
pub fn precompute_propagate_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  // Resolve the local graph before mutating control. The current plain
  // precompute cleanup can temporarily leave detached label owners until
  // lowering; requiring SSA after that mutation would verify the transient
  // state. Applying the proven local facts first still preserves Binaryen's
  // bounded contract: one local solve followed by one evaluator run.
  let propagated = precompute_propagate_prefix_fold_local_gets(ctx, func)
  let precomputed = precompute_run(ctx, func)
  if propagated || precomputed.changed {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
