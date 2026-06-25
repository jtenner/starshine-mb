///|
pub fn optimize_instructions_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("optimize-instructions", invalidates=[
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
pub fn optimize_instructions_summary() -> String {
  "Fold safe exact-instruction peepholes such as shift masks and compare-to-zero patterns."
}

///|
priv struct OptimizeInstructionsScratch {
  cross_seen_stamps : Array[Int]
  loop_input_nodes : @bitset.BitSet
  if_condition_nodes : @bitset.BitSet
  sign_ext_bits_by_node : Array[Int]
  i32_unsigned_max_by_node : Array[Int]
  i64_unsigned_max_by_node : Array[Int64]
  mut loop_input_nodes_ready : Bool
  mut if_condition_nodes_ready : Bool
  mut sign_ext_facts_ready : Bool
  mut unsigned_max_facts_ready : Bool
  mut next_cross_seen_stamp : Int
}

///|
fn OptimizeInstructionsScratch::new(
  node_count : Int,
) -> OptimizeInstructionsScratch {
  {
    cross_seen_stamps: Array::make(node_count, -1),
    loop_input_nodes: @bitset.BitSet::new(node_count),
    if_condition_nodes: @bitset.BitSet::new(node_count),
    sign_ext_bits_by_node: Array::make(node_count, 0),
    i32_unsigned_max_by_node: Array::make(node_count, -1),
    i64_unsigned_max_by_node: Array::make(node_count, -1L),
    loop_input_nodes_ready: false,
    if_condition_nodes_ready: false,
    sign_ext_facts_ready: false,
    unsigned_max_facts_ready: false,
    next_cross_seen_stamp: 0,
  }
}

///|
fn optimize_instructions_alloc_cross_seen_stamp(
  scratch : OptimizeInstructionsScratch,
) -> Int {
  let stamp = scratch.next_cross_seen_stamp
  scratch.next_cross_seen_stamp = stamp + 1
  stamp
}

///|
fn optimize_instructions_mark_loop_input_nodes(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
) -> Unit {
  if scratch.loop_input_nodes_ready {
    return
  }
  for node_id = 0; node_id < func.nodes.length(); node_id = node_id + 1 {
    if !optimize_instructions_node_is_live(func, dead, node_id) {
      continue
    }
    let node = func.nodes[node_id]
    match node.op {
      @ir.HotOp::Loop => ()
      _ => continue
    }
    let input_count = @ir.hot_label_branch_arity(
      func,
      @ir.hot_control_node_label(func, node_id),
    )
    for slot = 0; slot < input_count; slot = slot + 1 {
      let child_id = func.children[node.child_base + slot]
      if child_id >= 0 && child_id < scratch.loop_input_nodes.length() {
        scratch.loop_input_nodes[child_id] = true
      }
    }
  }
  scratch.loop_input_nodes_ready = true
}

///|
fn optimize_instructions_mark_if_condition_nodes(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
) -> Unit {
  if scratch.if_condition_nodes_ready {
    return
  }
  for node_id = 0; node_id < func.nodes.length(); node_id = node_id + 1 {
    if !optimize_instructions_node_is_live(func, dead, node_id) {
      continue
    }
    let node = func.nodes[node_id]
    match node.op {
      @ir.HotOp::If if node.child_count > 0 => {
        let cond_id = func.children[node.child_base]
        if cond_id >= 0 && cond_id < scratch.if_condition_nodes.length() {
          scratch.if_condition_nodes[cond_id] = true
        }
      }
      _ => ()
    }
  }
  scratch.if_condition_nodes_ready = true
}

///|
fn optimize_instructions_sign_ext_bits_for_exact_instr(
  instr : @lib.Instruction,
) -> Int {
  match instr {
    @lib.Instruction::I32Load8S(_) | @lib.Instruction::I64Load8S(_) => 8
    @lib.Instruction::I32Load16S(_) | @lib.Instruction::I64Load16S(_) => 16
    @lib.Instruction::I64Load32S(_) => 32
    @lib.Instruction::I32Extend8S | @lib.Instruction::I64Extend8S => 8
    @lib.Instruction::I32Extend16S | @lib.Instruction::I64Extend16S => 16
    @lib.Instruction::I64Extend32S => 32
    _ => 0
  }
}

///|
fn optimize_instructions_i32_sign_ext_bits_for_const(raw : Int) -> Int {
  if raw >= -128 && raw <= 127 {
    8
  } else if raw >= -32768 && raw <= 32767 {
    16
  } else {
    32
  }
}

///|
fn optimize_instructions_i64_sign_ext_bits_for_const(raw : Int64) -> Int {
  if raw >= -128L && raw <= 127L {
    8
  } else if raw >= -32768L && raw <= 32767L {
    16
  } else if raw >= -2147483648L && raw <= 2147483647L {
    32
  } else {
    64
  }
}

///|
fn optimize_instructions_sign_ext_bits_for_value(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> Int {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return 0
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const =>
      match @ir.hot_const_get(func, node.imm0) {
        @ir.HotConstPayload::I32Const(@lib.I32(raw)) =>
          optimize_instructions_i32_sign_ext_bits_for_const(raw)
        @ir.HotConstPayload::I64Const(@lib.I64(raw)) =>
          optimize_instructions_i64_sign_ext_bits_for_const(raw)
        _ => 0
      }
    @ir.HotOp::LocalGet =>
      if node_id >= 0 && node_id < scratch.sign_ext_bits_by_node.length() {
        scratch.sign_ext_bits_by_node[node_id]
      } else {
        0
      }
    @ir.HotOp::Load | @ir.HotOp::Unary =>
      optimize_instructions_sign_ext_bits_for_exact_instr(
        func.instr_payloads[node.imm0].instr,
      )
    _ => 0
  }
}

///|
fn optimize_instructions_mark_local_writes_unknown(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  local_bits : Array[Int],
) -> Unit {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
      if node.imm0 >= 0 && node.imm0 < local_bits.length() {
        local_bits[node.imm0] = 0
      }
    _ => ()
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    optimize_instructions_mark_local_writes_unknown(
      func,
      dead,
      func.children[node.child_base + slot],
      local_bits,
    )
  }
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop => {
      let body = @ir.hot_region_body_ref(func, node_id)
      for i = 0; i < @ir.hot_region_root_count(func, body); i = i + 1 {
        optimize_instructions_mark_local_writes_unknown(
          func,
          dead,
          @ir.hot_region_get(func, body, i),
          local_bits,
        )
      }
    }
    @ir.HotOp::If => {
      let then_region = @ir.hot_region_then_ref(func, node_id)
      for i = 0; i < @ir.hot_region_root_count(func, then_region); i = i + 1 {
        optimize_instructions_mark_local_writes_unknown(
          func,
          dead,
          @ir.hot_region_get(func, then_region, i),
          local_bits,
        )
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          for i = 0; i < @ir.hot_region_root_count(func, else_region); i = i + 1 {
            optimize_instructions_mark_local_writes_unknown(
              func,
              dead,
              @ir.hot_region_get(func, else_region, i),
              local_bits,
            )
          }
        None => ()
      }
    }
    _ => ()
  }
}

///|
fn optimize_instructions_scan_sign_ext_expr(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  local_bits : Array[Int],
) -> Unit {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      if node.imm0 >= 0 &&
        node.imm0 < local_bits.length() &&
        node_id >= 0 &&
        node_id < scratch.sign_ext_bits_by_node.length() {
        scratch.sign_ext_bits_by_node[node_id] = local_bits[node.imm0]
      }
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
      if node.imm0 >= 0 && node.imm0 < local_bits.length() {
        local_bits[node.imm0] = 0
      }
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::If => {
      optimize_instructions_mark_local_writes_unknown(
        func, dead, node_id, local_bits,
      )
      return
    }
    _ => ()
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    optimize_instructions_scan_sign_ext_expr(
      func,
      dead,
      scratch,
      func.children[node.child_base + slot],
      local_bits,
    )
  }
}

///|
fn optimize_instructions_scan_sign_ext_facts(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
) -> Unit {
  if scratch.sign_ext_facts_ready {
    return
  }
  let local_bits = Array::make(@ir.hot_local_count(func), 0)
  for local_id = @ir.hot_local_param_count(func)
      local_id < local_bits.length()
      local_id = local_id + 1 {
    match @ir.hot_local_type(func, local_id) {
      Some(val_type) if val_type == @lib.ValType::i32() =>
        local_bits[local_id] = 8
      Some(val_type) if val_type == @lib.ValType::i64() =>
        local_bits[local_id] = 8
      _ => ()
    }
  }
  for slot = 0; slot < func.roots.length(); slot = slot + 1 {
    let root = func.roots[slot]
    optimize_instructions_scan_sign_ext_expr(
      func, dead, scratch, root, local_bits,
    )
    let node = @ir.hot_node_get(func, root)
    match node.op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee if node.child_count == 1 &&
        node.imm0 >= 0 &&
        node.imm0 < local_bits.length() =>
        local_bits[node.imm0] = optimize_instructions_sign_ext_bits_for_value(
          func,
          dead,
          scratch,
          func.children[node.child_base],
        )
      _ => ()
    }
  }
  scratch.sign_ext_facts_ready = true
}

///|
fn optimize_instructions_i32_unsigned_max_fact_for_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> Int? {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::I32Load8U(_)) => return Some(255)
    Some(@lib.Instruction::I32Load16U(_)) => return Some(65535)
    _ => ()
  }
  match node.op {
    @ir.HotOp::Const =>
      match @ir.hot_const_get(func, node.imm0) {
        @ir.HotConstPayload::I32Const(@lib.I32(raw)) if raw >= 0 => Some(raw)
        _ => None
      }
    @ir.HotOp::LocalGet =>
      if node_id >= 0 && node_id < scratch.i32_unsigned_max_by_node.length() {
        let max_value = scratch.i32_unsigned_max_by_node[node_id]
        if max_value >= 0 {
          Some(max_value)
        } else {
          None
        }
      } else {
        None
      }
    @ir.HotOp::Binary => {
      let lhs_id = func.children[node.child_base]
      let rhs_id = func.children[node.child_base + 1]
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::I32And) => {
          let (mask, value_id) = match
            optimize_instructions_i32_const(func, dead, rhs_id) {
            Some(@lib.I32(raw)) => (raw, lhs_id)
            _ =>
              match optimize_instructions_i32_const(func, dead, lhs_id) {
                Some(@lib.I32(raw)) => (raw, rhs_id)
                _ => return None
              }
          }
          if mask < 0 {
            None
          } else {
            match
              optimize_instructions_i32_unsigned_max_fact_for_node(
                func, dead, scratch, value_id,
              ) {
              Some(value) if value < mask => Some(value)
              _ => Some(mask)
            }
          }
        }
        Some(@lib.Instruction::I32ShrU) =>
          match optimize_instructions_i32_const(func, dead, rhs_id) {
            Some(@lib.I32(raw)) if raw > 0 && raw < 32 =>
              match
                optimize_instructions_i32_unsigned_max_fact_for_node(
                  func, dead, scratch, lhs_id,
                ) {
                Some(value) => Some(value >> raw)
                None if raw == 1 => Some(2147483647)
                None => Some((1 << (32 - raw)) - 1)
              }
            _ => None
          }
        _ => None
      }
    }
    _ => None
  }
}

///|
fn optimize_instructions_i64_unsigned_max_fact_for_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> Int64? {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::I64Load8U(_)) => return Some(255L)
    Some(@lib.Instruction::I64Load16U(_)) => return Some(65535L)
    Some(@lib.Instruction::I64Load32U(_)) => return Some(4294967295L)
    _ => ()
  }
  match node.op {
    @ir.HotOp::Const =>
      match @ir.hot_const_get(func, node.imm0) {
        @ir.HotConstPayload::I64Const(@lib.I64(raw)) if raw >= 0L => Some(raw)
        _ => None
      }
    @ir.HotOp::LocalGet =>
      if node_id >= 0 && node_id < scratch.i64_unsigned_max_by_node.length() {
        let max_value = scratch.i64_unsigned_max_by_node[node_id]
        if max_value >= 0L {
          Some(max_value)
        } else {
          None
        }
      } else {
        None
      }
    @ir.HotOp::Binary => {
      let lhs_id = func.children[node.child_base]
      let rhs_id = func.children[node.child_base + 1]
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::I64And) => {
          let (mask, value_id) = match
            optimize_instructions_i64_const(func, dead, rhs_id) {
            Some(@lib.I64(raw)) => (raw, lhs_id)
            _ =>
              match optimize_instructions_i64_const(func, dead, lhs_id) {
                Some(@lib.I64(raw)) => (raw, rhs_id)
                _ => return None
              }
          }
          if mask < 0L {
            None
          } else {
            match
              optimize_instructions_i64_unsigned_max_fact_for_node(
                func, dead, scratch, value_id,
              ) {
              Some(value) if value < mask => Some(value)
              _ => Some(mask)
            }
          }
        }
        Some(@lib.Instruction::I64ShrU) =>
          match optimize_instructions_i64_const(func, dead, rhs_id) {
            Some(@lib.I64(raw)) if raw > 0L && raw < 64L =>
              match
                optimize_instructions_i64_unsigned_max_fact_for_node(
                  func, dead, scratch, lhs_id,
                ) {
                Some(value) => Some(value >> raw.to_int())
                None if raw == 1L => Some(9223372036854775807L)
                None => Some((1L << (64 - raw.to_int())) - 1L)
              }
            _ => None
          }
        _ => None
      }
    }
    _ => None
  }
}

///|
fn optimize_instructions_scan_unsigned_max_expr(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  i32_local_max : Array[Int],
  i64_local_max : Array[Int64],
) -> Unit {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      if node.imm0 >= 0 &&
        node.imm0 < i32_local_max.length() &&
        node_id >= 0 &&
        node_id < scratch.i32_unsigned_max_by_node.length() {
        scratch.i32_unsigned_max_by_node[node_id] = i32_local_max[node.imm0]
        scratch.i64_unsigned_max_by_node[node_id] = i64_local_max[node.imm0]
      }
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
      if node.imm0 >= 0 && node.imm0 < i32_local_max.length() {
        i32_local_max[node.imm0] = -1
        i64_local_max[node.imm0] = -1L
      }
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::If => {
      for i = 0; i < i32_local_max.length(); i = i + 1 {
        i32_local_max[i] = -1
        i64_local_max[i] = -1L
      }
      return
    }
    _ => ()
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    optimize_instructions_scan_unsigned_max_expr(
      func,
      dead,
      scratch,
      func.children[node.child_base + slot],
      i32_local_max,
      i64_local_max,
    )
  }
}

///|
fn optimize_instructions_scan_unsigned_max_facts(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
) -> Unit {
  if scratch.unsigned_max_facts_ready {
    return
  }
  let i32_local_max = Array::make(@ir.hot_local_count(func), -1)
  let i64_local_max = Array::make(@ir.hot_local_count(func), -1L)
  for local_id = @ir.hot_local_param_count(func)
      local_id < i32_local_max.length()
      local_id = local_id + 1 {
    match @ir.hot_local_type(func, local_id) {
      Some(val_type) if val_type == @lib.ValType::i32() =>
        i32_local_max[local_id] = 0
      Some(val_type) if val_type == @lib.ValType::i64() =>
        i64_local_max[local_id] = 0L
      _ => ()
    }
  }
  for slot = 0; slot < func.roots.length(); slot = slot + 1 {
    let root = func.roots[slot]
    optimize_instructions_scan_unsigned_max_expr(
      func, dead, scratch, root, i32_local_max, i64_local_max,
    )
    let node = @ir.hot_node_get(func, root)
    match node.op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee if node.child_count == 1 &&
        node.imm0 >= 0 &&
        node.imm0 < i32_local_max.length() => {
        match
          optimize_instructions_i32_unsigned_max_fact_for_node(
            func,
            dead,
            scratch,
            func.children[node.child_base],
          ) {
          Some(max_value) => i32_local_max[node.imm0] = max_value
          None => i32_local_max[node.imm0] = -1
        }
        match
          optimize_instructions_i64_unsigned_max_fact_for_node(
            func,
            dead,
            scratch,
            func.children[node.child_base],
          ) {
          Some(max_value) => i64_local_max[node.imm0] = max_value
          None => i64_local_max[node.imm0] = -1L
        }
      }
      _ => ()
    }
  }
  scratch.unsigned_max_facts_ready = true
}

///|
fn optimize_instructions_node_is_live(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if node_id < 0 {
    return false
  }
  if node_id < dead.length() {
    return !dead[node_id]
  }
  @ir.hot_node_is_live(func, node_id)
}

///|
fn optimize_instructions_replace_with_const_i32(
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
fn optimize_instructions_replace_with_const_i64(
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
fn optimize_instructions_replace_with_unreachable(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Unit {
  let temp = @ir.hot_build_unreachable(func)
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_replace_with_existing_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Unit {
  let replacement_id = @ir.hot_child_get(func, node_id, 0)
  @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, replacement_id))
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_replace_with_node_id(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  replacement_id : Int,
) -> Unit {
  @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, replacement_id))
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_replace_with_exact_unary(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  instr : @lib.Instruction,
  operand_id : Int,
) -> Unit {
  let result_ty = match instr {
    @lib.Instruction::I64Eqz => @lib.ValType::i32()
    @lib.Instruction::I64Extend8S
    | @lib.Instruction::I64Extend16S
    | @lib.Instruction::I64Extend32S => @lib.ValType::i64()
    _ => @lib.ValType::i32()
  }
  let temp = @ir.hot_build_unary(func, result_ty, operand_id)
  @ir.hot_node_exact_instr_set(func, temp, instr)
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_replace_with_exact_compare(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Unit {
  let temp = @ir.hot_build_compare(func, lhs_id, rhs_id)
  @ir.hot_node_exact_instr_set(func, temp, instr)
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_node_is_i32_value(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_type_get(func, @ir.hot_node_get(func, node_id).ty) {
    @ir.HotTypeInfo::Value(val_type) => val_type == @lib.ValType::i32()
    _ => false
  }
}

///|
fn optimize_instructions_rewrite_exact_with_children(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  instr : @lib.Instruction,
  new_children : Array[Int],
) -> Unit {
  ignore(@ir.hot_replace_child_span(func, node_id, new_children))
  @ir.hot_node_exact_instr_set(func, node_id, instr)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_call_ref_result_block_type(
  func : @ir.HotFunc,
  node : @ir.HotNode,
) -> @lib.BlockType? {
  let results = @ir.hot_type_results(func, node.ty)
  match results.length() {
    0 => Some(@lib.BlockType::void_())
    1 => Some(@lib.BlockType::val_type(results[0]))
    _ => None
  }
}

///|
fn optimize_instructions_try_directize_fallthrough_ref_func_call_ref(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node : @ir.HotNode,
  callee_ref_id : Int,
  args : Array[Int],
) -> Int? {
  let (prefix, local_ids) = match
    optimize_instructions_call_ref_localize_args(func, args) {
    Some(localized) => localized
    None => return None
  }
  let callee_ref = @ir.hot_node_get(func, callee_ref_id)
  match callee_ref.op {
    @ir.HotOp::Block => ()
    _ => return None
  }
  let body_ref = @ir.hot_region_body_ref(func, callee_ref_id)
  let root_count = @ir.hot_region_root_count(func, body_ref)
  if root_count < 1 {
    return None
  }
  let target_id = @ir.hot_region_get(func, body_ref, root_count - 1)
  if !optimize_instructions_node_is_live(func, dead, target_id) {
    return None
  }
  let target = @ir.hot_node_get(func, target_id)
  match target.op {
    @ir.HotOp::RefFunc => ()
    _ => return None
  }
  let replacement_body = prefix.copy()
  replacement_body.push(@ir.hot_build_drop(func, callee_ref_id))
  match node.op {
    @ir.HotOp::CallRef => {
      let block_type = match
        optimize_instructions_call_ref_result_block_type(func, node) {
        Some(block_type) => block_type
        None => return None
      }
      replacement_body.push(
        @ir.hot_build_call(
          func,
          target.imm0,
          @ir.hot_type_results(func, node.ty),
          optimize_instructions_call_ref_local_gets(func, local_ids),
        ),
      )
      Some(@ir.hot_build_block(func, block_type, replacement_body))
    }
    @ir.HotOp::ReturnCallRef => {
      replacement_body.push(
        @ir.hot_build_return_call(
          func,
          target.imm0,
          optimize_instructions_call_ref_local_gets(func, local_ids),
        ),
      )
      Some(@ir.hot_build_block(func, @lib.BlockType::void_(), replacement_body))
    }
    _ => None
  }
}

///|
fn optimize_instructions_call_ref_localize_args(
  func : @ir.HotFunc,
  args : Array[Int],
) -> (Array[Int], Array[Int])? {
  let arg_types : Array[@lib.ValType] = []
  for arg in args {
    let arg_node = @ir.hot_node_get(func, arg)
    let arg_results = @ir.hot_type_results(func, arg_node.ty)
    if arg_results.length() != 1 {
      return None
    }
    arg_types.push(arg_results[0])
  }
  let prefix : Array[Int] = []
  let local_ids : Array[Int] = []
  for i = 0; i < args.length(); i = i + 1 {
    let local_id = @ir.hot_append_body_local(func, arg_types[i])
    prefix.push(@ir.hot_build_local_set(func, local_id, args[i]))
    local_ids.push(local_id)
  }
  Some((prefix, local_ids))
}

///|
fn optimize_instructions_call_ref_local_gets(
  func : @ir.HotFunc,
  local_ids : Array[Int],
) -> Array[Int] {
  let gets : Array[Int] = []
  for local_id in local_ids {
    gets.push(@ir.hot_build_local_get(func, local_id))
  }
  gets
}

///|
fn optimize_instructions_try_directize_ref_func_call_ref(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::CallRef | @ir.HotOp::ReturnCallRef => ()
    _ => return false
  }
  if node.child_count < 1 {
    return false
  }
  let callee_ref_id = @ir.hot_child_get(func, node_id, node.child_count - 1)
  if !optimize_instructions_node_is_live(func, dead, callee_ref_id) {
    return false
  }
  let callee_ref = @ir.hot_node_get(func, callee_ref_id)
  let args : Array[Int] = []
  for slot = 0; slot < node.child_count - 1; slot = slot + 1 {
    args.push(@ir.hot_child_get(func, node_id, slot))
  }
  let temp = match callee_ref.op {
    @ir.HotOp::RefFunc =>
      match node.op {
        @ir.HotOp::CallRef =>
          @ir.hot_build_call(
            func,
            callee_ref.imm0,
            @ir.hot_type_results(func, node.ty),
            args,
          )
        @ir.HotOp::ReturnCallRef =>
          @ir.hot_build_return_call(func, callee_ref.imm0, args)
        _ => abort("unreachable call_ref directization op")
      }
    @ir.HotOp::Block =>
      match
        optimize_instructions_try_directize_fallthrough_ref_func_call_ref(
          func, dead, node, callee_ref_id, args,
        ) {
        Some(replacement) => replacement
        None => return false
      }
    @ir.HotOp::TableGet if callee_ref.child_count == 1 => {
      let table_index_id = @ir.hot_child_get(func, callee_ref_id, 0)
      if !optimize_instructions_node_is_live(func, dead, table_index_id) {
        return false
      }
      let sig = @ir.hot_call_sig_get(func, node.imm0)
      match node.op {
        @ir.HotOp::CallRef =>
          @ir.hot_build_call_indirect(
            func,
            sig.type_idx,
            @lib.TableIdx::new(callee_ref.imm0.reinterpret_as_uint()),
            @ir.hot_type_results(func, node.ty),
            args,
            table_index_id,
          )
        @ir.HotOp::ReturnCallRef =>
          @ir.hot_build_return_call_indirect(
            func,
            sig.type_idx,
            @lib.TableIdx::new(callee_ref.imm0.reinterpret_as_uint()),
            args,
            table_index_id,
          )
        _ => abort("unreachable call_ref directization op")
      }
    }
    @ir.HotOp::Select if callee_ref.child_count == 3 => {
      let true_ref_id = @ir.hot_child_get(func, callee_ref_id, 0)
      let false_ref_id = @ir.hot_child_get(func, callee_ref_id, 1)
      let condition_id = @ir.hot_child_get(func, callee_ref_id, 2)
      if !optimize_instructions_node_is_live(func, dead, true_ref_id) ||
        !optimize_instructions_node_is_live(func, dead, false_ref_id) ||
        !optimize_instructions_node_is_live(func, dead, condition_id) {
        return false
      }
      let true_ref = @ir.hot_node_get(func, true_ref_id)
      let false_ref = @ir.hot_node_get(func, false_ref_id)
      match (true_ref.op, false_ref.op) {
        (@ir.HotOp::RefFunc, @ir.HotOp::RefFunc) => ()
        _ => return false
      }
      let block_type = match node.op {
        @ir.HotOp::CallRef =>
          match optimize_instructions_call_ref_result_block_type(func, node) {
            Some(block_type) => block_type
            None => return false
          }
        @ir.HotOp::ReturnCallRef => @lib.BlockType::void_()
        _ => abort("unreachable call_ref directization op")
      }
      let (prefix, local_ids) = match
        optimize_instructions_call_ref_localize_args(func, args) {
        Some(localized) => localized
        None => return false
      }
      let replacement_if = match node.op {
        @ir.HotOp::CallRef =>
          @ir.hot_build_if(
            func,
            block_type,
            condition_id,
            [
              @ir.hot_build_call(
                func,
                true_ref.imm0,
                @ir.hot_type_results(func, node.ty),
                optimize_instructions_call_ref_local_gets(func, local_ids),
              ),
            ],
            else_body=Some([
              @ir.hot_build_call(
                func,
                false_ref.imm0,
                @ir.hot_type_results(func, node.ty),
                optimize_instructions_call_ref_local_gets(func, local_ids),
              ),
            ]),
          )
        @ir.HotOp::ReturnCallRef =>
          @ir.hot_build_if(
            func,
            @lib.BlockType::void_(),
            condition_id,
            [
              @ir.hot_build_return_call(
                func,
                true_ref.imm0,
                optimize_instructions_call_ref_local_gets(func, local_ids),
              ),
            ],
            else_body=Some([
              @ir.hot_build_return_call(
                func,
                false_ref.imm0,
                optimize_instructions_call_ref_local_gets(func, local_ids),
              ),
            ]),
          )
        _ => abort("unreachable call_ref directization op")
      }
      if prefix.length() == 0 {
        replacement_if
      } else {
        let body = prefix.copy()
        body.push(replacement_if)
        @ir.hot_build_block(func, block_type, body)
      }
    }
    _ => return false
  }
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  match replacement.op {
    @ir.HotOp::If
    | @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable =>
      @ir.hot_label_owner_set(
        func,
        @ir.hot_control_node_label(func, node_id),
        node_id,
      )
    _ => ()
  }
  @ir.hot_delete_node(func, temp)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_try_fold_constant_if_condition(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If => ()
    _ => return false
  }
  let cond_id = @ir.hot_child_get(func, node_id, 0)
  let take_then = match optimize_instructions_i32_const(func, dead, cond_id) {
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
  if !precompute_constant_if_chosen_region_can_inline(func, chosen_region) {
    return false
  }
  let root_count = @ir.hot_region_root_count(func, chosen_region)
  let body : Array[Int] = []
  for i = 0; i < root_count; i = i + 1 {
    body.push(@ir.hot_region_get(func, chosen_region, i))
  }
  @ir.hot_control_demote_if_to_block(func, node_id, body)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_i32_const(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> @lib.I32? {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return None
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::Const => ()
    _ => return None
  }
  match func.consts[node.imm0] {
    @ir.HotConstPayload::I32Const(v) => Some(v)
    _ => None
  }
}

///|
fn optimize_instructions_i64_const(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> @lib.I64? {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return None
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::Const => ()
    _ => return None
  }
  match func.consts[node.imm0] {
    @ir.HotConstPayload::I64Const(v) => Some(v)
    _ => None
  }
}

///|
fn optimize_instructions_f32_const(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> @lib.F32? {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return None
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::Const => ()
    _ => return None
  }
  match func.consts[node.imm0] {
    @ir.HotConstPayload::F32Const(v) => Some(v)
    _ => None
  }
}

///|
fn optimize_instructions_f64_const(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> @lib.F64? {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return None
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::Const => ()
    _ => return None
  }
  match func.consts[node.imm0] {
    @ir.HotConstPayload::F64Const(v) => Some(v)
    _ => None
  }
}

///|
fn optimize_instructions_shift_mask_bits(instr : @lib.Instruction) -> Int? {
  match instr {
    @lib.Instruction::I32Shl
    | @lib.Instruction::I32ShrS
    | @lib.Instruction::I32ShrU
    | @lib.Instruction::I32Rotl
    | @lib.Instruction::I32Rotr => Some(31)
    @lib.Instruction::I64Shl
    | @lib.Instruction::I64ShrS
    | @lib.Instruction::I64ShrU
    | @lib.Instruction::I64Rotl
    | @lib.Instruction::I64Rotr => Some(63)
    _ => None
  }
}

///|
fn optimize_instructions_shift_rhs_i32_amount(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  rhs_id : Int,
  mask_bits : Int,
) -> Int? {
  match optimize_instructions_i32_const(func, dead, rhs_id) {
    Some(@lib.I32(raw)) => return Some(raw & mask_bits)
    None => ()
  }
  if !optimize_instructions_node_is_live(func, dead, rhs_id) {
    return None
  }
  let rhs = @ir.hot_node_get(func, rhs_id)
  match rhs.op {
    @ir.HotOp::Binary =>
      match @ir.hot_node_exact_instr(func, rhs_id) {
        Some(@lib.Instruction::I32And) =>
          match
            optimize_instructions_i32_const(
              func,
              dead,
              func.children[rhs.child_base + 1],
            ) {
            Some(@lib.I32(raw)) if (raw & mask_bits) == mask_bits =>
              match
                optimize_instructions_i32_const(
                  func,
                  dead,
                  func.children[rhs.child_base],
                ) {
                Some(@lib.I32(amount)) => Some(amount & mask_bits)
                _ => None
              }
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn optimize_instructions_shift_rhs_i64_amount(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  rhs_id : Int,
  mask_bits : Int,
) -> Int? {
  match optimize_instructions_i64_const(func, dead, rhs_id) {
    Some(@lib.I64(raw)) => return Some((raw & mask_bits.to_int64()).to_int())
    None => ()
  }
  if !optimize_instructions_node_is_live(func, dead, rhs_id) {
    return None
  }
  let rhs = @ir.hot_node_get(func, rhs_id)
  match rhs.op {
    @ir.HotOp::Binary =>
      match @ir.hot_node_exact_instr(func, rhs_id) {
        Some(@lib.Instruction::I64And) =>
          match
            optimize_instructions_i64_const(
              func,
              dead,
              func.children[rhs.child_base + 1],
            ) {
            Some(@lib.I64(raw)) if (raw & mask_bits.to_int64()) ==
              mask_bits.to_int64() =>
              match
                optimize_instructions_i64_const(
                  func,
                  dead,
                  func.children[rhs.child_base],
                ) {
                Some(@lib.I64(amount)) =>
                  Some((amount & mask_bits.to_int64()).to_int())
                _ => None
              }
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn optimize_instructions_i32_non_negative_const(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match optimize_instructions_i32_const(func, dead, node_id) {
    Some(@lib.I32(raw)) => raw >= 0
    None => false
  }
}

///|
fn optimize_instructions_i64_non_negative_const(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match optimize_instructions_i64_const(func, dead, node_id) {
    Some(@lib.I64(raw)) => raw >= 0L
    None => false
  }
}

///|
fn optimize_instructions_signed_const_unsigned_variant(
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  match instr {
    @lib.Instruction::I32LtS => Some(@lib.Instruction::i32_lt_u())
    @lib.Instruction::I32GtS => Some(@lib.Instruction::i32_gt_u())
    @lib.Instruction::I32LeS => Some(@lib.Instruction::i32_le_u())
    @lib.Instruction::I32GeS => Some(@lib.Instruction::i32_ge_u())
    @lib.Instruction::I32DivS => Some(@lib.Instruction::i32_div_u())
    @lib.Instruction::I32RemS => Some(@lib.Instruction::i32_rem_u())
    @lib.Instruction::I32ShrS => Some(@lib.Instruction::i32_shr_u())
    @lib.Instruction::I64LtS => Some(@lib.Instruction::i64_lt_u())
    @lib.Instruction::I64GtS => Some(@lib.Instruction::i64_gt_u())
    @lib.Instruction::I64LeS => Some(@lib.Instruction::i64_le_u())
    @lib.Instruction::I64GeS => Some(@lib.Instruction::i64_ge_u())
    @lib.Instruction::I64DivS => Some(@lib.Instruction::i64_div_u())
    @lib.Instruction::I64RemS => Some(@lib.Instruction::i64_rem_u())
    @lib.Instruction::I64ShrS => Some(@lib.Instruction::i64_shr_u())
    _ => None
  }
}

///|
fn optimize_instructions_try_canonicalize_signed_const_unsigned(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let unsigned_instr = match
    optimize_instructions_signed_const_unsigned_variant(instr) {
    Some(unsigned_instr) => unsigned_instr
    None => return false
  }
  let operands_are_non_negative = match instr {
    @lib.Instruction::I32LtS
    | @lib.Instruction::I32GtS
    | @lib.Instruction::I32LeS
    | @lib.Instruction::I32GeS
    | @lib.Instruction::I32DivS
    | @lib.Instruction::I32RemS =>
      optimize_instructions_i32_non_negative_const(func, dead, lhs_id) &&
      optimize_instructions_i32_non_negative_const(func, dead, rhs_id)
    @lib.Instruction::I32ShrS =>
      optimize_instructions_i32_non_negative_const(func, dead, lhs_id) &&
      optimize_instructions_i32_non_negative_const(func, dead, rhs_id)
    @lib.Instruction::I64LtS
    | @lib.Instruction::I64GtS
    | @lib.Instruction::I64LeS
    | @lib.Instruction::I64GeS
    | @lib.Instruction::I64DivS
    | @lib.Instruction::I64RemS =>
      optimize_instructions_i64_non_negative_const(func, dead, lhs_id) &&
      optimize_instructions_i64_non_negative_const(func, dead, rhs_id)
    @lib.Instruction::I64ShrS =>
      optimize_instructions_i64_non_negative_const(func, dead, lhs_id) &&
      optimize_instructions_i64_non_negative_const(func, dead, rhs_id)
    _ => false
  }
  if !operands_are_non_negative {
    return false
  }
  @ir.hot_node_exact_instr_set(func, node_id, unsigned_instr)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_prefer_negative_leb_i32(raw : Int) -> Bool {
  match raw {
    0x40 | 0x2000 | 0x100000 | 0x8000000 => true
    _ => false
  }
}

///|
fn optimize_instructions_prefer_negative_leb_i64(raw : Int64) -> Bool {
  match raw {
    0x40L
    | 0x2000L
    | 0x100000L
    | 0x8000000L
    | 0x400000000L
    | 0x20000000000L
    | 0x1000000000000L
    | 0x80000000000000L
    | 0x4000000000000000L => true
    _ => false
  }
}

///|
fn optimize_instructions_i32_power_of_two_shift(raw : Int) -> Int? {
  if raw <= 0 || (raw & (raw - 1)) != 0 {
    return None
  }
  let mut shift = 0
  let mut value = raw
  while value > 1 {
    value = value >> 1
    shift = shift + 1
  }
  Some(shift)
}

///|
fn optimize_instructions_i64_power_of_two_shift(raw : Int64) -> Int64? {
  if raw <= 0L || (raw & (raw - 1L)) != 0L {
    return None
  }
  let mut shift = 0L
  let mut value = raw
  while value > 1L {
    value = value >> 1
    shift = shift + 1L
  }
  Some(shift)
}

///|
fn optimize_instructions_is_commutative_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Instruction::I32Add
    | @lib.Instruction::I64Add
    | @lib.Instruction::I32Mul
    | @lib.Instruction::I64Mul
    | @lib.Instruction::I32And
    | @lib.Instruction::I64And
    | @lib.Instruction::I32Or
    | @lib.Instruction::I64Or
    | @lib.Instruction::I32Xor
    | @lib.Instruction::I64Xor
    | @lib.Instruction::I32Eq
    | @lib.Instruction::I64Eq
    | @lib.Instruction::I32Ne
    | @lib.Instruction::I64Ne => true
    _ => false
  }
}

///|
fn optimize_instructions_local_get_id(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Int? {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return None
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::LocalGet => Some(node.imm0)
    _ => None
  }
}

///|
fn optimize_instructions_is_constlike(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::Const | @ir.HotOp::RefNull | @ir.HotOp::RefFunc => true
    _ => false
  }
}

///|
fn optimize_instructions_is_shared_cross_safe_leaf(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::Const
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc => true
    _ => false
  }
}

///|
fn optimize_instructions_can_cross_local_get(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  use_def : @ir.HotUseDef,
  node_id : Int,
  local_id : Int,
  under_local_tee_payload : Bool,
  loop_input_nodes : @bitset.BitSet,
  seen_stamps : Array[Int],
  seen_stamp : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return true
  }
  if node_id < seen_stamps.length() && seen_stamps[node_id] == seen_stamp {
    return true
  }
  if node_id < seen_stamps.length() {
    seen_stamps[node_id] = seen_stamp
  }
  if node_id < loop_input_nodes.length() && loop_input_nodes[node_id] {
    return false
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::If => ()
    @ir.HotOp::Block => {
      let label_id = @ir.hot_control_node_label(func, node_id)
      match @ir.hot_label_kind(func, label_id) {
        @ir.HotLabelKind::RegionLabel => ()
        _ => return false
      }
    }
    @ir.HotOp::Loop
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable
    | @ir.HotOp::Br
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::Return
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate
    | @ir.HotOp::Catch
    | @ir.HotOp::CatchAll => return false
    _ => ()
  }
  if @ir.node_use_count(use_def, node_id) > 1 {
    if !optimize_instructions_is_shared_cross_safe_leaf(func, dead, node_id) ||
      under_local_tee_payload {
      return false
    }
  }
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee if node.imm0 == local_id =>
      return false
    _ => ()
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    let child_is_local_tee_payload = match node.op {
      @ir.HotOp::LocalTee => slot == 0
      _ => false
    }
    if !optimize_instructions_can_cross_local_get(
        func,
        dead,
        use_def,
        func.children[node.child_base + slot],
        local_id,
        child_is_local_tee_payload,
        loop_input_nodes,
        seen_stamps,
        seen_stamp,
      ) {
      return false
    }
  }
  true
}

///|
fn optimize_instructions_commutative_node_kind_rank(op : @ir.HotOp) -> Int? {
  match op {
    @ir.HotOp::Call | @ir.HotOp::CallIndirect | @ir.HotOp::CallRef => Some(-1)
    @ir.HotOp::LocalGet => Some(0)
    @ir.HotOp::LocalTee => Some(1)
    @ir.HotOp::GlobalGet => Some(2)
    @ir.HotOp::Load => Some(3)
    @ir.HotOp::Const | @ir.HotOp::RefNull | @ir.HotOp::RefFunc => Some(4)
    @ir.HotOp::Unary => Some(5)
    @ir.HotOp::Binary => Some(6)
    @ir.HotOp::Compare => Some(7)
    @ir.HotOp::Convert => Some(8)
    _ => None
  }
}

///|
fn optimize_instructions_should_swap_commutative_node_kinds(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, lhs_id) ||
    !optimize_instructions_node_is_live(func, dead, rhs_id) {
    return false
  }
  let lhs = if lhs_id < func.nodes.length() {
    func.nodes[lhs_id]
  } else {
    @ir.hot_node_get(func, lhs_id)
  }
  let rhs = if rhs_id < func.nodes.length() {
    func.nodes[rhs_id]
  } else {
    @ir.hot_node_get(func, rhs_id)
  }
  match
    (
      optimize_instructions_commutative_node_kind_rank(lhs.op),
      optimize_instructions_commutative_node_kind_rank(rhs.op),
    ) {
    (Some(lhs_rank), Some(rhs_rank)) => {
      let local_get_tie_break = match (lhs.op, rhs.op) {
        (@ir.HotOp::LocalGet, @ir.HotOp::LocalGet) => lhs.imm0 > rhs.imm0
        _ => false
      }
      lhs_rank > rhs_rank || (lhs_rank == rhs_rank && local_get_tie_break)
    }
    _ => false
  }
}

///|
fn optimize_instructions_try_canonicalize_commutative(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
  scratch : OptimizeInstructionsScratch,
) -> Bool {
  // The old O4z guard disabled this after address-like operand reordering bugs.
  // Re-enable only when both the local kind-rank order wants a swap and the
  // shared Binaryen-style effect/use-def proof says the operand subtrees can
  // exchange positions without changing observable behavior.
  ignore(scratch)
  if !optimize_instructions_should_swap_commutative_node_kinds(
      func, dead, lhs_id, rhs_id,
    ) {
    return false
  }
  if !optimize_instructions_can_swap_leading_operands(ctx, func, lhs_id, rhs_id) {
    return false
  }
  optimize_instructions_rewrite_exact_with_children(ctx, func, node_id, instr, [
    rhs_id, lhs_id,
  ])
  true
}

///|
fn optimize_instructions_is_trivially_pure_value(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::Const
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc => true
    _ => false
  }
}

///|
fn optimize_instructions_is_side_effect_free_expr(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::Const
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc => true
    @ir.HotOp::Unary
    | @ir.HotOp::Binary
    | @ir.HotOp::Compare
    | @ir.HotOp::Convert
    | @ir.HotOp::Select => {
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        if !optimize_instructions_is_side_effect_free_expr(
            func,
            dead,
            func.children[node.child_base + slot],
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
fn optimize_instructions_negate_boolean_expr(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Int? {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return None
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::I32Eqz) if @ir.hot_child_count(func, node_id) == 1 =>
      Some(@ir.hot_child_get(func, node_id, 0))
    _ =>
      match optimize_instructions_i32_const(func, dead, node_id) {
        Some(@lib.I32(raw)) if raw == 0 =>
          Some(@ir.hot_build_const_i32(func, @lib.I32(1)))
        Some(@lib.I32(raw)) if raw == 1 =>
          Some(@ir.hot_build_const_i32(func, @lib.I32(0)))
        _ => None
      }
  }
}

///|
fn optimize_instructions_negate_boolean_expr_recursive(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Int? {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If => {
      let then_region = @ir.hot_region_then_ref(func, node_id)
      let else_region = match @ir.hot_region_else_ref(func, node_id) {
        Some(region) => region
        None => return None
      }
      if @ir.hot_region_root_count(func, then_region) != 1 ||
        @ir.hot_region_root_count(func, else_region) != 1 {
        return None
      }
      let neg_then = match
        optimize_instructions_negate_boolean_expr_recursive(
          func,
          dead,
          @ir.hot_region_get(func, then_region, 0),
        ) {
        Some(node) => node
        None => return None
      }
      let neg_else = match
        optimize_instructions_negate_boolean_expr_recursive(
          func,
          dead,
          @ir.hot_region_get(func, else_region, 0),
        ) {
        Some(node) => node
        None => return None
      }
      @ir.hot_region_replace_body(func, then_region, [neg_then])
      @ir.hot_region_replace_body(func, else_region, [neg_else])
      return Some(node_id)
    }
    _ => ()
  }
  optimize_instructions_negate_boolean_expr(func, dead, node_id)
}

///|
fn optimize_instructions_is_boolean_constant_tree(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match optimize_instructions_i32_const(func, dead, node_id) {
    Some(@lib.I32(0)) | Some(@lib.I32(1)) => return true
    _ => ()
  }
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::If => ()
    _ => return false
  }
  let then_region = @ir.hot_region_then_ref(func, node_id)
  let else_region = match @ir.hot_region_else_ref(func, node_id) {
    Some(region) => region
    None => return false
  }
  if @ir.hot_region_root_count(func, then_region) != 1 ||
    @ir.hot_region_root_count(func, else_region) != 1 {
    return false
  }
  optimize_instructions_is_boolean_constant_tree(
    func,
    dead,
    @ir.hot_region_get(func, then_region, 0),
  ) &&
  optimize_instructions_is_boolean_constant_tree(
    func,
    dead,
    @ir.hot_region_get(func, else_region, 0),
  )
}

///|
fn optimize_instructions_boolean_tree_if_nodes_are_unshared(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  use_def : @ir.HotUseDef,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::I32Eqz) if @ir.hot_child_count(func, node_id) == 1 =>
      return true
    _ => ()
  }
  match optimize_instructions_i32_const(func, dead, node_id) {
    Some(@lib.I32(0)) | Some(@lib.I32(1)) => return true
    _ => ()
  }
  if @ir.node_use_count(use_def, node_id) > 1 {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::If => ()
    _ => return false
  }
  let then_region = @ir.hot_region_then_ref(func, node_id)
  let else_region = match @ir.hot_region_else_ref(func, node_id) {
    Some(region) => region
    None => return false
  }
  if @ir.hot_region_root_count(func, then_region) != 1 ||
    @ir.hot_region_root_count(func, else_region) != 1 {
    return false
  }
  optimize_instructions_boolean_tree_if_nodes_are_unshared(
    func,
    dead,
    use_def,
    @ir.hot_region_get(func, then_region, 0),
  ) &&
  optimize_instructions_boolean_tree_if_nodes_are_unshared(
    func,
    dead,
    use_def,
    @ir.hot_region_get(func, else_region, 0),
  )
}

///|
fn optimize_instructions_same_branch_shape(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, lhs_id) ||
    !optimize_instructions_node_is_live(func, dead, rhs_id) {
    return false
  }
  let lhs = @ir.hot_node_get(func, lhs_id)
  let rhs = @ir.hot_node_get(func, rhs_id)
  match (lhs.op, rhs.op) {
    (@ir.HotOp::Br, @ir.HotOp::Br) if lhs.imm0 == rhs.imm0 &&
      lhs.child_count == rhs.child_count => {
      for slot = 0; slot < lhs.child_count; slot = slot + 1 {
        if @ir.hot_child_get(func, lhs_id, slot) !=
          @ir.hot_child_get(func, rhs_id, slot) {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_try_collapse_duplicate_then_branch(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let then_region = @ir.hot_region_then_ref(func, node_id)
  let then_root_count = @ir.hot_region_root_count(func, then_region)
  if then_root_count != 1 && then_root_count != 2 {
    return false
  }
  let inner_if_id = @ir.hot_region_get(func, then_region, 0)
  if then_root_count == 2 {
    let tail_id = @ir.hot_region_get(func, then_region, 1)
    match @ir.hot_node_get(func, tail_id).op {
      @ir.HotOp::Unreachable => ()
      _ => return false
    }
  }
  match @ir.hot_node_get(func, inner_if_id).op {
    @ir.HotOp::If => ()
    _ => return false
  }
  let inner_else = match @ir.hot_region_else_ref(func, inner_if_id) {
    Some(region) => region
    None => return false
  }
  let inner_then = @ir.hot_region_then_ref(func, inner_if_id)
  if @ir.hot_region_root_count(func, inner_then) != 1 ||
    @ir.hot_region_root_count(func, inner_else) != 1 {
    return false
  }
  let inner_cond_id = @ir.hot_child_get(func, inner_if_id, 0)
  if !optimize_instructions_is_side_effect_free_expr(func, dead, inner_cond_id) {
    return false
  }
  let then_root = @ir.hot_region_get(func, inner_then, 0)
  let else_root = @ir.hot_region_get(func, inner_else, 0)
  if !optimize_instructions_same_branch_shape(func, dead, then_root, else_root) {
    return false
  }
  let branch = @ir.hot_node_get(func, then_root)
  let replacement = @ir.hot_build_br(
    func,
    branch.imm0,
    values=@ir.hot_child_span(func, then_root),
  )
  @ir.hot_region_replace_body(func, then_region, [replacement])
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_node_is_zero_sentinel(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const =>
      @ir.hot_const_get(func, node.imm0) ==
      @ir.HotConstPayload::i32_const(@lib.I32(0))
    @ir.HotOp::Drop =>
      if @ir.hot_child_count(func, node_id) != 1 {
        false
      } else {
        optimize_instructions_node_is_zero_sentinel(
          func,
          @ir.hot_child_get(func, node_id, 0),
        )
      }
    _ => false
  }
}

///|
fn optimize_instructions_node_is_drop_zero_sentinel(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Drop =>
      @ir.hot_child_count(func, node_id) == 1 &&
      optimize_instructions_node_is_zero_sentinel(
        func,
        @ir.hot_child_get(func, node_id, 0),
      )
    _ => false
  }
}

///|
fn optimize_instructions_holder_flows_to_drop(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  if region_ref == @ir.HotRegionRef::root() {
    return false
  }
  let use_def = pass_require_use_def(ctx, func)
  let mut current = region_ref.holder
  for hops = 0; hops < 64; hops = hops + 1 {
    if @ir.node_use_count(use_def, current) != 1 {
      return false
    }
    let sites = @ir.node_use_sites_borrowed(use_def, current)
    let site = sites[0]
    if site.user == -1 {
      return false
    }
    let user = @ir.hot_node_get(func, site.user)
    match site.kind {
      @ir.HotUseSlotKind::ChildUseSlot =>
        match user.op {
          @ir.HotOp::Drop => return true
          _ => return false
        }
      @ir.HotUseSlotKind::RootUseSlot => current = site.user
    }
  }
  false
}

///|
fn optimize_instructions_region_exits_to_label(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  region_ref : @ir.HotRegionRef,
  label_id : Int,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return false
  }
  optimize_instructions_node_exits_to_label(
    func,
    dead,
    @ir.hot_region_get(func, region_ref, root_count - 1),
    label_id,
  )
}

///|
fn optimize_instructions_region_never_falls_through(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return false
  }
  optimize_instructions_node_never_falls_through(
    func,
    dead,
    @ir.hot_region_get(func, region_ref, root_count - 1),
  )
}

///|
fn optimize_instructions_node_never_falls_through(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Unreachable
    | @ir.HotOp::Return
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate
    | @ir.HotOp::Br => true
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_region_never_falls_through(
            func,
            dead,
            @ir.hot_region_then_ref(func, node_id),
          ) &&
          optimize_instructions_region_never_falls_through(
            func, dead, else_region,
          )
        None => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_region_never_falls_through_to_label(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  region_ref : @ir.HotRegionRef,
  label_id : Int,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return false
  }
  optimize_instructions_node_never_falls_through_to_label(
    func,
    dead,
    @ir.hot_region_get(func, region_ref, root_count - 1),
    label_id,
  )
}

///|
fn optimize_instructions_node_never_falls_through_to_label(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  label_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Unreachable
    | @ir.HotOp::Return
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate => true
    @ir.HotOp::Br => node.imm0 == label_id
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_region_never_falls_through_to_label(
            func,
            dead,
            @ir.hot_region_then_ref(func, node_id),
            label_id,
          ) &&
          optimize_instructions_region_never_falls_through_to_label(
            func, dead, else_region, label_id,
          )
        None => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_node_exits_to_label(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  label_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Unreachable
    | @ir.HotOp::Return
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate => true
    @ir.HotOp::Br => node.imm0 == label_id
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_region_exits_to_label(
            func,
            dead,
            @ir.hot_region_then_ref(func, node_id),
            label_id,
          ) &&
          optimize_instructions_region_exits_to_label(
            func, dead, else_region, label_id,
          )
        None => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_region_exits_only_via_branches(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return false
  }
  optimize_instructions_node_exits_only_via_branches(
    func,
    dead,
    @ir.hot_region_get(func, region_ref, root_count - 1),
  )
}

///|
fn optimize_instructions_node_exits_only_via_branches(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br => true
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_region_exits_only_via_branches(
            func,
            dead,
            @ir.hot_region_then_ref(func, node_id),
          ) &&
          optimize_instructions_region_exits_only_via_branches(
            func, dead, else_region,
          )
        None => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_node_branches_to_label(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  label_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br => node.imm0 == label_id
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_region_branches_to_label(
            func,
            dead,
            @ir.hot_region_then_ref(func, node_id),
            label_id,
          ) &&
          optimize_instructions_region_branches_to_label(
            func, dead, else_region, label_id,
          )
        None => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_region_branches_to_label(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  region_ref : @ir.HotRegionRef,
  label_id : Int,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return false
  }
  optimize_instructions_node_branches_to_label(
    func,
    dead,
    @ir.hot_region_get(func, region_ref, root_count - 1),
    label_id,
  )
}

///|
fn optimize_instructions_node_exits_via_nonbranch_terminal(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Unreachable
    | @ir.HotOp::Return
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate => true
    @ir.HotOp::Block =>
      optimize_instructions_region_exits_via_nonbranch_terminal(
        func,
        dead,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_region_exits_via_nonbranch_terminal(
            func,
            dead,
            @ir.hot_region_then_ref(func, node_id),
          ) &&
          optimize_instructions_region_exits_via_nonbranch_terminal(
            func, dead, else_region,
          )
        None => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_region_exits_via_nonbranch_terminal(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return false
  }
  for idx = 0; idx < root_count; idx = idx + 1 {
    let root = @ir.hot_region_get(func, region_ref, idx)
    if !optimize_instructions_node_is_live(func, dead, root) {
      continue
    }
    if optimize_instructions_node_exits_via_nonbranch_terminal(func, dead, root) {
      return true
    }
    if optimize_instructions_node_never_falls_through(func, dead, root) {
      return false
    }
  }
  false
}

///|
fn optimize_instructions_try_collapse_dead_region_suffix(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  region_ref : @ir.HotRegionRef,
  label_id : Int,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count < 2 {
    return false
  }
  for idx = 0; idx < root_count - 1; idx = idx + 1 {
    let root = @ir.hot_region_get(func, region_ref, idx)
    let root_op = @ir.hot_node_get(func, root).op
    let branch_only_if_escape = match root_op {
      @ir.HotOp::If =>
        optimize_instructions_node_exits_only_via_branches(func, dead, root)
      _ => false
    }
    let direct_terminal = match root_op {
      @ir.HotOp::Br
      | @ir.HotOp::Unreachable
      | @ir.HotOp::Return
      | @ir.HotOp::Throw
      | @ir.HotOp::Rethrow
      | @ir.HotOp::ThrowRef
      | @ir.HotOp::Delegate => true
      _ => false
    }
    let tail_is_value_branch_to_label = if idx + 2 == root_count {
      let tail_id = @ir.hot_region_get(func, region_ref, idx + 1)
      let tail = @ir.hot_node_get(func, tail_id)
      match tail.op {
        @ir.HotOp::Br =>
          tail.imm0 == label_id && @ir.hot_child_count(func, tail_id) > 0
        _ => false
      }
    } else {
      false
    }
    let never_falls_through = if tail_is_value_branch_to_label {
      optimize_instructions_node_never_falls_through_to_label(
        func, dead, root, label_id,
      )
    } else {
      optimize_instructions_node_never_falls_through(func, dead, root)
    }
    let escapes = if branch_only_if_escape {
      false
    } else {
      match root_op {
        @ir.HotOp::Br
        | @ir.HotOp::Unreachable
        | @ir.HotOp::Return
        | @ir.HotOp::Throw
        | @ir.HotOp::Rethrow
        | @ir.HotOp::ThrowRef
        | @ir.HotOp::Delegate => true
        _ =>
          optimize_instructions_node_exits_to_label(func, dead, root, label_id) ||
          never_falls_through
      }
    }
    if !escapes {
      continue
    }
    if idx + 2 == root_count {
      let tail_id = @ir.hot_region_get(func, region_ref, idx + 1)
      let root_is_if = match root_op {
        @ir.HotOp::If => true
        _ => false
      }
      if root_is_if &&
        optimize_instructions_node_is_drop_zero_sentinel(func, tail_id) {
        return false
      }
      let root_is_result_carrier = match root_op {
        @ir.HotOp::If | @ir.HotOp::Block => true
        _ => false
      }
      let keep_result_zero_sentinel = root_is_result_carrier &&
        optimize_instructions_node_exits_via_nonbranch_terminal(
          func, dead, root,
        )
      if optimize_instructions_node_is_zero_sentinel(func, tail_id) &&
        (
          optimize_instructions_holder_flows_to_drop(ctx, func, region_ref) ||
          keep_result_zero_sentinel
        ) {
        return false
      }
    }
    if idx + 2 == root_count {
      let tail_id = @ir.hot_region_get(func, region_ref, idx + 1)
      let tail = @ir.hot_node_get(func, tail_id)
      match tail.op {
        @ir.HotOp::Unreachable => return false
        @ir.HotOp::Br =>
          if @ir.hot_child_count(func, tail_id) > 0 {
            let root_is_if = match root_op {
              @ir.HotOp::If => true
              _ => false
            }
            if root_is_if &&
              !optimize_instructions_node_exits_to_label(
                func,
                dead,
                root,
                tail.imm0,
              ) {
              return false
            }
          }
        _ => ()
      }
    }
    let next : Array[Int] = []
    for keep = 0; keep <= idx; keep = keep + 1 {
      next.push(@ir.hot_region_get(func, region_ref, keep))
    }
    let root_is_if = match root_op {
      @ir.HotOp::If => true
      _ => false
    }
    let needs_unreachable = if direct_terminal {
      false
    } else if root_is_if && branch_only_if_escape {
      false
    } else if region_ref == @ir.HotRegionRef::root() {
      true
    } else {
      let holder = region_ref.holder
      let holder_label = @ir.hot_control_node_label(func, holder)
      match @ir.hot_label_kind(func, holder_label) {
        @ir.HotLabelKind::RegionLabel => false
        _ => true
      }
    }
    if needs_unreachable {
      next.push(@ir.hot_build_unreachable(func))
    }
    @ir.hot_region_replace_body(func, region_ref, next)
    pass_mark_mutated(ctx, func)
    return true
  }
  false
}

///|
fn optimize_instructions_reverse_relational_instr(
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  match instr {
    @lib.Instruction::I32LtS => Some(@lib.Instruction::i32_gt_s())
    @lib.Instruction::I32LtU => Some(@lib.Instruction::i32_gt_u())
    @lib.Instruction::I32LeS => Some(@lib.Instruction::i32_ge_s())
    @lib.Instruction::I32LeU => Some(@lib.Instruction::i32_ge_u())
    @lib.Instruction::I32GtS => Some(@lib.Instruction::i32_lt_s())
    @lib.Instruction::I32GtU => Some(@lib.Instruction::i32_lt_u())
    @lib.Instruction::I32GeS => Some(@lib.Instruction::i32_le_s())
    @lib.Instruction::I32GeU => Some(@lib.Instruction::i32_le_u())
    @lib.Instruction::I64LtS => Some(@lib.Instruction::i64_gt_s())
    @lib.Instruction::I64LtU => Some(@lib.Instruction::i64_gt_u())
    @lib.Instruction::I64LeS => Some(@lib.Instruction::i64_ge_s())
    @lib.Instruction::I64LeU => Some(@lib.Instruction::i64_ge_u())
    @lib.Instruction::I64GtS => Some(@lib.Instruction::i64_lt_s())
    @lib.Instruction::I64GtU => Some(@lib.Instruction::i64_lt_u())
    @lib.Instruction::I64GeS => Some(@lib.Instruction::i64_le_s())
    @lib.Instruction::I64GeU => Some(@lib.Instruction::i64_le_u())
    _ => None
  }
}

///|
fn optimize_instructions_try_canonicalize_relational_const(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  if !optimize_instructions_is_constlike(func, dead, lhs_id) ||
    optimize_instructions_is_constlike(func, dead, rhs_id) {
    return false
  }
  match optimize_instructions_reverse_relational_instr(instr) {
    Some(reversed) => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        reversed,
        [rhs_id, lhs_id],
      )
      true
    }
    None => false
  }
}

///|
fn optimize_instructions_try_canonicalize_relational_operands(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
  scratch : OptimizeInstructionsScratch,
) -> Bool {
  let reversed = match optimize_instructions_reverse_relational_instr(instr) {
    Some(reversed) => reversed
    None => return false
  }
  let lhs_canonicalized = match
    optimize_instructions_local_get_id(func, dead, lhs_id) {
    Some(local_id) => {
      if optimize_instructions_is_constlike(func, dead, rhs_id) {
        return false
      }
      let should_swap = match
        optimize_instructions_local_get_id(func, dead, rhs_id) {
        Some(rhs_local_id) => local_id > rhs_local_id
        None => true
      }
      if !should_swap {
        return false
      }
      let use_def = pass_require_use_def(ctx, func)
      if @ir.node_use_count(use_def, rhs_id) > 1 {
        return false
      }
      optimize_instructions_mark_loop_input_nodes(func, dead, scratch)
      let seen_stamp = optimize_instructions_alloc_cross_seen_stamp(scratch)
      let can_cross = optimize_instructions_can_cross_local_get(
        func,
        dead,
        use_def,
        rhs_id,
        local_id,
        false,
        scratch.loop_input_nodes,
        scratch.cross_seen_stamps,
        seen_stamp,
      )
      if !can_cross {
        return false
      }
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        reversed,
        [rhs_id, lhs_id],
      )
      true
    }
    None => false
  }
  if lhs_canonicalized {
    return true
  }
  match optimize_instructions_local_get_id(func, dead, rhs_id) {
    Some(local_id) => {
      if optimize_instructions_is_constlike(func, dead, lhs_id) ||
        !optimize_instructions_should_swap_commutative_node_kinds(
          func, dead, lhs_id, rhs_id,
        ) {
        return false
      }
      let use_def = pass_require_use_def(ctx, func)
      if @ir.node_use_count(use_def, lhs_id) > 1 {
        return false
      }
      optimize_instructions_mark_loop_input_nodes(func, dead, scratch)
      let seen_stamp = optimize_instructions_alloc_cross_seen_stamp(scratch)
      let can_cross = optimize_instructions_can_cross_local_get(
        func,
        dead,
        use_def,
        lhs_id,
        local_id,
        false,
        scratch.loop_input_nodes,
        scratch.cross_seen_stamps,
        seen_stamp,
      )
      if !can_cross {
        return false
      }
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        reversed,
        [rhs_id, lhs_id],
      )
      true
    }
    None => false
  }
}

///|
fn optimize_instructions_try_canonicalize_compare_const(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match (instr, optimize_instructions_i32_const(func, dead, rhs_id)) {
    (@lib.Instruction::I32GtS, Some(@lib.I32(raw))) if raw == -1 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_ge_s(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(0))],
      )
      true
    }
    (@lib.Instruction::I32LeS, Some(@lib.I32(raw))) if raw == -1 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_lt_s(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(0))],
      )
      true
    }
    (@lib.Instruction::I32LtS, Some(@lib.I32(raw))) if raw == 1 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_le_s(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(0))],
      )
      true
    }
    (@lib.Instruction::I32GeS, Some(@lib.I32(raw))) if raw == 1 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_gt_s(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(0))],
      )
      true
    }
    (@lib.Instruction::I32LtU, Some(@lib.I32(raw))) if raw == 1 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_eq(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(0))],
      )
      true
    }
    (@lib.Instruction::I32GeU, Some(@lib.I32(raw))) if raw == 1 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_ne(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(0))],
      )
      true
    }
    (@lib.Instruction::I32LtS, Some(@lib.I32(raw))) if raw == -2147483647 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_eq(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(-2147483648))],
      )
      true
    }
    (@lib.Instruction::I32GeS, Some(@lib.I32(raw))) if raw == -2147483647 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_ne(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(-2147483648))],
      )
      true
    }
    (@lib.Instruction::I32GtS, Some(@lib.I32(raw))) if raw == 2147483646 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_eq(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(2147483647))],
      )
      true
    }
    (@lib.Instruction::I32LeS, Some(@lib.I32(raw))) if raw == 2147483646 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_ne(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(2147483647))],
      )
      true
    }
    _ =>
      match (instr, optimize_instructions_i64_const(func, dead, rhs_id)) {
        (@lib.Instruction::I64GtS, Some(@lib.I64(raw))) if raw == -1L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_ge_s(),
            [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(0L))],
          )
          true
        }
        (@lib.Instruction::I64LeS, Some(@lib.I64(raw))) if raw == -1L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_lt_s(),
            [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(0L))],
          )
          true
        }
        (@lib.Instruction::I64LtS, Some(@lib.I64(raw))) if raw == 1L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_le_s(),
            [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(0L))],
          )
          true
        }
        (@lib.Instruction::I64GeS, Some(@lib.I64(raw))) if raw == 1L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_gt_s(),
            [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(0L))],
          )
          true
        }
        (@lib.Instruction::I64LtU, Some(@lib.I64(raw))) if raw == 1L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_eq(),
            [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(0L))],
          )
          true
        }
        (@lib.Instruction::I64GeU, Some(@lib.I64(raw))) if raw == 1L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_ne(),
            [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(0L))],
          )
          true
        }
        (@lib.Instruction::I64LtS, Some(@lib.I64(raw))) if raw ==
          -9223372036854775807L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_eq(),
            [
              lhs_id,
              @ir.hot_build_const_i64(func, @lib.I64(-9223372036854775808L)),
            ],
          )
          true
        }
        (@lib.Instruction::I64GeS, Some(@lib.I64(raw))) if raw ==
          -9223372036854775807L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_ne(),
            [
              lhs_id,
              @ir.hot_build_const_i64(func, @lib.I64(-9223372036854775808L)),
            ],
          )
          true
        }
        (@lib.Instruction::I64GtS, Some(@lib.I64(raw))) if raw ==
          9223372036854775806L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_eq(),
            [
              lhs_id,
              @ir.hot_build_const_i64(func, @lib.I64(9223372036854775807L)),
            ],
          )
          true
        }
        (@lib.Instruction::I64LeS, Some(@lib.I64(raw))) if raw ==
          9223372036854775806L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_ne(),
            [
              lhs_id,
              @ir.hot_build_const_i64(func, @lib.I64(9223372036854775807L)),
            ],
          )
          true
        }
        _ => false
      }
  }
}

///|
fn optimize_instructions_try_optimize_if_condition(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If if node.child_count == 3 => ()
    _ => return false
  }
  if optimize_instructions_try_collapse_duplicate_then_branch(
      ctx, func, dead, node_id,
    ) {
    return true
  }
  let cond_id = func.children[node.child_base]
  let then_region = func.children[node.child_base + 1]
  let else_region = func.children[node.child_base + 2]
  let flip_if = fn(next_cond : Int) -> Bool {
    match optimize_instructions_i32_const(func, dead, next_cond) {
      Some(@lib.I32(raw)) if raw == 0 => return false
      _ => ()
    }
    match optimize_instructions_i64_const(func, dead, next_cond) {
      Some(@lib.I64(raw)) if raw == 0L => return false
      _ => ()
    }
    ignore(
      @ir.hot_replace_child_span(func, node_id, [
        next_cond, else_region, then_region,
      ]),
    )
    pass_mark_mutated(ctx, func)
    true
  }
  let cond_instr = match @ir.hot_node_exact_instr(func, cond_id) {
    Some(instr) => instr
    None => {
      if optimize_instructions_try_invert_nested_if_condition(
          ctx, func, dead, node_id, cond_id, then_region, else_region,
        ) {
        return true
      }
      return optimize_instructions_try_negate_nested_if_condition_to_eqz(
        ctx, func, dead, node_id, cond_id, else_region,
      )
    }
  }
  let direct_rewrite = match cond_instr {
    @lib.Instruction::I32Ne => {
      if @ir.hot_child_count(func, cond_id) != 2 {
        return false
      }
      let lhs_id = @ir.hot_child_get(func, cond_id, 0)
      let rhs_id = @ir.hot_child_get(func, cond_id, 1)
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(raw)) if raw == 0 &&
          optimize_instructions_node_is_i32_value(func, lhs_id) => {
          @ir.hot_child_set(func, node_id, 0, lhs_id)
          pass_mark_mutated(ctx, func)
          true
        }
        _ => false
      }
    }
    @lib.Instruction::I32Eq => {
      if @ir.hot_child_count(func, cond_id) != 2 {
        return false
      }
      let lhs_id = @ir.hot_child_get(func, cond_id, 0)
      let rhs_id = @ir.hot_child_get(func, cond_id, 1)
      let operand_id = match
        (
          optimize_instructions_i32_const(func, dead, lhs_id),
          optimize_instructions_i32_const(func, dead, rhs_id),
        ) {
        (Some(@lib.I32(0)), _) => Some(rhs_id)
        (_, Some(@lib.I32(0))) => Some(lhs_id)
        _ => None
      }
      match operand_id {
        Some(operand_id) if optimize_instructions_node_is_i32_value(
            func, operand_id,
          ) =>
          if @ir.hot_node_is_live(func, else_region) {
            flip_if(operand_id)
          } else {
            optimize_instructions_replace_with_exact_unary(
              ctx,
              func,
              cond_id,
              @lib.Instruction::i32_eqz(),
              operand_id,
            )
            true
          }
        Some(_) => false
        None => false
      }
    }
    @lib.Instruction::I32Eqz => {
      if !@ir.hot_node_is_live(func, else_region) ||
        @ir.hot_child_count(func, cond_id) != 1 {
        return false
      }
      let operand_id = @ir.hot_child_get(func, cond_id, 0)
      if !optimize_instructions_node_is_i32_value(func, operand_id) {
        return false
      }
      flip_if(operand_id)
    }
    _ => false
  }
  if direct_rewrite {
    return true
  }
  if optimize_instructions_try_invert_nested_if_condition(
      ctx, func, dead, node_id, cond_id, then_region, else_region,
    ) {
    return true
  }
  optimize_instructions_try_negate_nested_if_condition_to_eqz(
    ctx, func, dead, node_id, cond_id, else_region,
  )
}

///|
fn optimize_instructions_try_wrap_boolean_if_value_in_eqz(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if @ir.hot_node_result_arity(func, node_id) != 1 {
    return false
  }
  let else_region = match @ir.hot_region_else_ref(func, node_id) {
    Some(region) => region
    None => return false
  }
  let then_region = @ir.hot_region_then_ref(func, node_id)
  if @ir.hot_region_root_count(func, then_region) != 1 ||
    @ir.hot_region_root_count(func, else_region) != 1 {
    return false
  }
  let then_root = @ir.hot_region_get(func, then_region, 0)
  let else_root = @ir.hot_region_get(func, else_region, 0)
  let plain_boolean_const_arms = match
    (
      optimize_instructions_i32_const(func, dead, then_root),
      optimize_instructions_i32_const(func, dead, else_root),
    ) {
    (Some(@lib.I32(0)), Some(@lib.I32(1)))
    | (Some(@lib.I32(1)), Some(@lib.I32(0))) => true
    _ => false
  }
  if plain_boolean_const_arms {
    return false
  }
  if optimize_instructions_is_boolean_constant_tree(func, dead, then_root) &&
    optimize_instructions_is_boolean_constant_tree(func, dead, else_root) {
    return false
  }
  let use_def = pass_require_use_def(ctx, func)
  if @ir.node_use_count(use_def, node_id) != 1 {
    return false
  }
  let use_sites = @ir.node_use_sites_borrowed(use_def, node_id)
  if use_sites.length() != 1 {
    return false
  }
  let use_site = use_sites[0]
  if use_site.user == -1 {
    return false
  }
  match use_site.kind {
    @ir.HotUseSlotKind::ChildUseSlot => ()
    @ir.HotUseSlotKind::RootUseSlot => return false
  }
  let use_user = @ir.hot_node_get(func, use_site.user)
  match use_user.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => ()
    _ => return false
  }
  let neg_then = match
    optimize_instructions_negate_boolean_expr_recursive(func, dead, then_root) {
    Some(node) => node
    None => return false
  }
  let neg_else = match
    optimize_instructions_negate_boolean_expr_recursive(func, dead, else_root) {
    Some(node) => node
    None => return false
  }
  @ir.hot_region_replace_body(func, then_region, [neg_then])
  @ir.hot_region_replace_body(func, else_region, [neg_else])
  let wrapped = @ir.hot_build_unary(func, @lib.ValType::i32(), node_id)
  @ir.hot_node_exact_instr_set(func, wrapped, @lib.Instruction::i32_eqz())
  @ir.hot_child_set(func, use_site.user, use_site.slot, wrapped)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_try_invert_nested_if_condition(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  cond_id : Int,
  then_region : Int,
  else_region : Int,
) -> Bool {
  if !@ir.hot_node_is_live(func, else_region) {
    return false
  }
  let use_def = pass_require_use_def(ctx, func)
  if @ir.node_use_count(use_def, cond_id) != 1 {
    return false
  }
  match @ir.hot_node_get(func, cond_id).op {
    @ir.HotOp::If => ()
    _ => return false
  }
  let cond_then = @ir.hot_region_then_ref(func, cond_id)
  let cond_else = match @ir.hot_region_else_ref(func, cond_id) {
    Some(region) => region
    None => return false
  }
  if @ir.hot_region_root_count(func, cond_then) != 1 ||
    @ir.hot_region_root_count(func, cond_else) != 1 {
    return false
  }
  let neg_then = match
    optimize_instructions_negate_boolean_expr(
      func,
      dead,
      @ir.hot_region_get(func, cond_then, 0),
    ) {
    Some(node) => node
    None => return false
  }
  let neg_else = match
    optimize_instructions_negate_boolean_expr(
      func,
      dead,
      @ir.hot_region_get(func, cond_else, 0),
    ) {
    Some(node) => node
    None => return false
  }
  @ir.hot_region_replace_body(func, cond_then, [neg_then])
  @ir.hot_region_replace_body(func, cond_else, [neg_else])
  ignore(
    @ir.hot_replace_child_span(func, node_id, [
      cond_id, else_region, then_region,
    ]),
  )
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_try_negate_nested_if_condition_to_eqz(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  cond_id : Int,
  else_region : Int,
) -> Bool {
  if @ir.hot_node_is_live(func, else_region) {
    return false
  }
  let use_def = pass_require_use_def(ctx, func)
  if !optimize_instructions_boolean_tree_if_nodes_are_unshared(
      func, dead, use_def, cond_id,
    ) {
    return false
  }
  match @ir.hot_node_get(func, cond_id).op {
    @ir.HotOp::If => ()
    _ => return false
  }
  let cond_then = @ir.hot_region_then_ref(func, cond_id)
  let cond_else = match @ir.hot_region_else_ref(func, cond_id) {
    Some(region) => region
    None => return false
  }
  if @ir.hot_region_root_count(func, cond_then) != 1 ||
    @ir.hot_region_root_count(func, cond_else) != 1 {
    return false
  }
  let neg_then = match
    optimize_instructions_negate_boolean_expr_recursive(
      func,
      dead,
      @ir.hot_region_get(func, cond_then, 0),
    ) {
    Some(node) => node
    None => return false
  }
  let neg_else = match
    optimize_instructions_negate_boolean_expr_recursive(
      func,
      dead,
      @ir.hot_region_get(func, cond_else, 0),
    ) {
    Some(node) => node
    None => return false
  }
  @ir.hot_region_replace_body(func, cond_then, [neg_then])
  @ir.hot_region_replace_body(func, cond_else, [neg_else])
  let wrapped = @ir.hot_build_unary(func, @lib.ValType::i32(), cond_id)
  @ir.hot_node_exact_instr_set(func, wrapped, @lib.Instruction::i32_eqz())
  @ir.hot_child_set(func, node_id, 0, wrapped)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_const_memory_size(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Int? {
  match optimize_instructions_i32_const(func, dead, node_id) {
    Some(@lib.I32(raw)) if raw >= 0 => Some(raw)
    _ =>
      match optimize_instructions_i64_const(func, dead, node_id) {
        Some(@lib.I64(raw)) if raw >= 0L && raw <= 2147483647L =>
          Some(raw.to_int())
        _ => None
      }
  }
}

///|
fn optimize_instructions_memarg_for_mem_idx(mem_idx : Int) -> @lib.MemArg {
  @lib.MemArg::new(
    @lib.U32(0),
    Some(@lib.MemIdx::new(mem_idx.reinterpret_as_uint())),
    @lib.U64(0),
  )
}

///|
fn optimize_instructions_replace_with_store_exact(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  mem_idx : Int,
  address_id : Int,
  value_id : Int,
  instr_for_memarg : (@lib.MemArg) -> @lib.Instruction,
) -> Unit {
  let memarg = optimize_instructions_memarg_for_mem_idx(mem_idx)
  let temp = @ir.hot_build_store(func, memarg, address_id, value_id)
  @ir.hot_node_exact_instr_set(func, temp, instr_for_memarg(memarg))
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_replace_with_store8(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  mem_idx : Int,
  address_id : Int,
  value_id : Int,
) -> Unit {
  optimize_instructions_replace_with_store_exact(
    ctx,
    func,
    node_id,
    mem_idx,
    address_id,
    value_id,
    @lib.Instruction::i32_store8,
  )
}

///|
fn optimize_instructions_repeated_fill_i32(raw : Int, size : Int) -> @lib.I32? {
  let byte = raw.reinterpret_as_uint() & 0xff
  match size {
    1 => Some(@lib.I32(byte.reinterpret_as_int()))
    2 => Some(@lib.I32((byte | (byte << 8)).reinterpret_as_int()))
    4 =>
      Some(
        @lib.I32(
          (byte | (byte << 8) | (byte << 16) | (byte << 24)).reinterpret_as_int(),
        ),
      )
    _ => None
  }
}

///|
fn optimize_instructions_repeated_fill_i64(raw : Int) -> @lib.I64 {
  let byte = (raw.reinterpret_as_uint() & 0xff).to_uint64()
  @lib.I64(
    (byte |
    (byte << 8) |
    (byte << 16) |
    (byte << 24) |
    (byte << 32) |
    (byte << 40) |
    (byte << 48) |
    (byte << 56)).reinterpret_as_int64(),
  )
}

///|
fn optimize_instructions_build_repeated_fill_v128_const(
  func : @ir.HotFunc,
  raw : Int,
) -> Int {
  let byte = (raw.reinterpret_as_uint() & 0xff).to_byte()
  @ir.hot_build_const_v128_splat(func, byte)
}

///|
fn optimize_instructions_build_i32_binary(
  func : @ir.HotFunc,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Int {
  let node_id = @ir.hot_build_binary(func, @lib.ValType::i32(), lhs_id, rhs_id)
  @ir.hot_node_exact_instr_set(func, node_id, instr)
  node_id
}

///|
fn optimize_instructions_build_i64_binary(
  func : @ir.HotFunc,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Int {
  let node_id = @ir.hot_build_binary(func, @lib.ValType::i64(), lhs_id, rhs_id)
  @ir.hot_node_exact_instr_set(func, node_id, instr)
  node_id
}

///|
fn optimize_instructions_build_exact_unary(
  func : @ir.HotFunc,
  result_ty : @lib.ValType,
  instr : @lib.Instruction,
  operand_id : Int,
) -> Int {
  let node_id = @ir.hot_build_unary(func, result_ty, operand_id)
  @ir.hot_node_exact_instr_set(func, node_id, instr)
  node_id
}

///|
fn optimize_instructions_repeated_fill_i32_for_local_get(
  func : @ir.HotFunc,
  local_id : Int,
  size : Int,
) -> Int? {
  let multiplier = match size {
    2 => @lib.I32(257)
    4 => @lib.I32(16843009)
    _ => return None
  }
  let value = @ir.hot_build_local_get(func, local_id)
  let masked = optimize_instructions_build_i32_binary(
    func,
    @lib.Instruction::i32_and(),
    value,
    @ir.hot_build_const_i32(func, @lib.I32(255)),
  )
  Some(
    optimize_instructions_build_i32_binary(
      func,
      @lib.Instruction::i32_mul(),
      masked,
      @ir.hot_build_const_i32(func, multiplier),
    ),
  )
}

///|
fn optimize_instructions_repeated_fill_i64_for_local_get(
  func : @ir.HotFunc,
  local_id : Int,
) -> Int {
  let value = @ir.hot_build_local_get(func, local_id)
  let masked = optimize_instructions_build_i32_binary(
    func,
    @lib.Instruction::i32_and(),
    value,
    @ir.hot_build_const_i32(func, @lib.I32(255)),
  )
  let extended = optimize_instructions_build_exact_unary(
    func,
    @lib.ValType::i64(),
    @lib.Instruction::i64_extend_i32u(),
    masked,
  )
  optimize_instructions_build_i64_binary(
    func,
    @lib.Instruction::i64_mul(),
    extended,
    @ir.hot_build_const_i64(func, @lib.I64(72340172838076673L)),
  )
}

///|
fn optimize_instructions_memory_access_with_memarg(
  instr : @lib.Instruction,
  memarg : @lib.MemArg,
) -> @lib.Instruction? {
  match instr {
    @lib.Instruction::I32Load(_) => Some(@lib.Instruction::i32_load(memarg))
    @lib.Instruction::I64Load(_) => Some(@lib.Instruction::i64_load(memarg))
    @lib.Instruction::F32Load(_) => Some(@lib.Instruction::f32_load(memarg))
    @lib.Instruction::F64Load(_) => Some(@lib.Instruction::f64_load(memarg))
    @lib.Instruction::I32Load8S(_) => Some(@lib.Instruction::i32_load8s(memarg))
    @lib.Instruction::I32Load8U(_) => Some(@lib.Instruction::i32_load8u(memarg))
    @lib.Instruction::I32Load16S(_) =>
      Some(@lib.Instruction::i32_load16s(memarg))
    @lib.Instruction::I32Load16U(_) =>
      Some(@lib.Instruction::i32_load16u(memarg))
    @lib.Instruction::I64Load8S(_) => Some(@lib.Instruction::i64_load8s(memarg))
    @lib.Instruction::I64Load8U(_) => Some(@lib.Instruction::i64_load8u(memarg))
    @lib.Instruction::I64Load16S(_) =>
      Some(@lib.Instruction::i64_load16s(memarg))
    @lib.Instruction::I64Load16U(_) =>
      Some(@lib.Instruction::i64_load16u(memarg))
    @lib.Instruction::I64Load32S(_) =>
      Some(@lib.Instruction::i64_load32s(memarg))
    @lib.Instruction::I64Load32U(_) =>
      Some(@lib.Instruction::i64_load32u(memarg))
    @lib.Instruction::I32Store(_) => Some(@lib.Instruction::i32_store(memarg))
    @lib.Instruction::I64Store(_) => Some(@lib.Instruction::i64_store(memarg))
    @lib.Instruction::F32Store(_) => Some(@lib.Instruction::f32_store(memarg))
    @lib.Instruction::F64Store(_) => Some(@lib.Instruction::f64_store(memarg))
    @lib.Instruction::I32Store8(_) => Some(@lib.Instruction::i32_store8(memarg))
    @lib.Instruction::I32Store16(_) =>
      Some(@lib.Instruction::i32_store16(memarg))
    @lib.Instruction::I64Store8(_) => Some(@lib.Instruction::i64_store8(memarg))
    @lib.Instruction::I64Store16(_) =>
      Some(@lib.Instruction::i64_store16(memarg))
    @lib.Instruction::I64Store32(_) =>
      Some(@lib.Instruction::i64_store32(memarg))
    _ => None
  }
}

///|
fn optimize_instructions_load_result_type(
  instr : @lib.Instruction,
) -> @lib.ValType? {
  match instr {
    @lib.Instruction::I32Load(_)
    | @lib.Instruction::I32Load8S(_)
    | @lib.Instruction::I32Load8U(_)
    | @lib.Instruction::I32Load16S(_)
    | @lib.Instruction::I32Load16U(_) => Some(@lib.ValType::i32())
    @lib.Instruction::I64Load(_)
    | @lib.Instruction::I64Load8S(_)
    | @lib.Instruction::I64Load8U(_)
    | @lib.Instruction::I64Load16S(_)
    | @lib.Instruction::I64Load16U(_)
    | @lib.Instruction::I64Load32S(_)
    | @lib.Instruction::I64Load32U(_) => Some(@lib.ValType::i64())
    @lib.Instruction::F32Load(_) => Some(@lib.ValType::f32())
    @lib.Instruction::F64Load(_) => Some(@lib.ValType::f64())
    _ => None
  }
}

///|
fn optimize_instructions_try_fold_const_memory_access_offset(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  ignore(dead)
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count == 0 {
    return false
  }
  match node.op {
    @ir.HotOp::Load | @ir.HotOp::Store => ()
    _ => return false
  }
  let instr = match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) => instr
    None => return false
  }
  let @lib.MemArg(align, mem, @lib.U64(offset)) = @ir.hot_memarg_get(
      func,
      node.imm0,
    ).memarg
  if offset == 0UL {
    return false
  }
  let address_id = @ir.hot_child_get(func, node_id, 0)
  let address = @ir.hot_node_get(func, address_id)
  match address.op {
    @ir.HotOp::Const => ()
    _ => return false
  }
  let new_address_id = match @ir.hot_const_get(func, address.imm0) {
    @ir.HotConstPayload::I32Const(@lib.I32(raw)) => {
      if raw < 0 {
        return false
      }
      let raw_u = raw.reinterpret_as_uint()
      if raw_u > 2147483647U {
        return false
      }
      let sum = raw_u.to_uint64() + offset
      if sum > 2147483647UL {
        return false
      }
      @ir.hot_build_const_i32(
        func,
        @lib.I32(sum.to_uint().reinterpret_as_int()),
      )
    }
    @ir.HotConstPayload::I64Const(@lib.I64(raw)) => {
      let raw_u = raw.reinterpret_as_uint64()
      if raw_u > 18446744073709551615UL - offset {
        return false
      }
      let sum = raw_u + offset
      @ir.hot_build_const_i64(func, @lib.I64(sum.reinterpret_as_int64()))
    }
    _ => return false
  }
  let new_memarg = @lib.MemArg::new(align, mem, @lib.U64(0UL))
  let new_instr = match
    optimize_instructions_memory_access_with_memarg(instr, new_memarg) {
    Some(instr) => instr
    None => return false
  }
  let temp = match node.op {
    @ir.HotOp::Load => {
      let result_type = match optimize_instructions_load_result_type(instr) {
        Some(result_type) => result_type
        None => return false
      }
      @ir.hot_build_load(func, result_type, new_memarg, new_address_id)
    }
    @ir.HotOp::Store =>
      @ir.hot_build_store(
        func,
        new_memarg,
        new_address_id,
        @ir.hot_child_get(func, node_id, 1),
      )
    _ => return false
  }
  @ir.hot_node_exact_instr_set(func, temp, new_instr)
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_store_value_bits(instr : @lib.Instruction) -> Int? {
  match instr {
    @lib.Instruction::I32Store8(_) | @lib.Instruction::I64Store8(_) => Some(8)
    @lib.Instruction::I32Store16(_) | @lib.Instruction::I64Store16(_) =>
      Some(16)
    @lib.Instruction::I64Store32(_) => Some(32)
    _ => None
  }
}

///|
fn optimize_instructions_store_value_is_i64(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Instruction::I64Store8(_)
    | @lib.Instruction::I64Store16(_)
    | @lib.Instruction::I64Store32(_) => true
    _ => false
  }
}

///|
fn optimize_instructions_packed_i32_const(
  raw : Int,
  bits : Int,
  signed : Bool,
) -> @lib.I32 {
  let mask = (1 << bits) - 1
  let truncated = raw & mask
  if signed {
    let sign = 1 << (bits - 1)
    if (truncated & sign) != 0 {
      @lib.I32(truncated - (1 << bits))
    } else {
      @lib.I32(truncated)
    }
  } else {
    @lib.I32(truncated)
  }
}

///|
fn optimize_instructions_packed_storage_bits(
  storage_type : @lib.StorageType,
) -> Int? {
  match storage_type {
    @lib.PackTypeStorageType(@lib.I8PackType) => Some(8)
    @lib.PackTypeStorageType(@lib.I16PackType) => Some(16)
    _ => None
  }
}

///|
fn optimize_instructions_struct_field_pack_bits(
  ctx : HotPassContext,
  type_idx : @lib.TypeIdx,
  field_idx : Int,
) -> Int? {
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return None
  }
  let fields = match
    @ir.hot_module_resolve_struct_fields(module_ctx, type_idx) {
    Some(fields) => fields
    None => return None
  }
  if field_idx < 0 || field_idx >= fields.length() {
    return None
  }
  optimize_instructions_packed_storage_bits(
    fields[field_idx].get_storage_type(),
  )
}

///|
fn optimize_instructions_array_field_pack_bits(
  ctx : HotPassContext,
  type_idx : @lib.TypeIdx,
) -> Int? {
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return None
  }
  let field = match @ir.hot_module_resolve_array_field(module_ctx, type_idx) {
    Some(field) => field
    None => return None
  }
  optimize_instructions_packed_storage_bits(field.get_storage_type())
}

///|
fn optimize_instructions_default_value_for_storage(
  func : @ir.HotFunc,
  storage : @lib.StorageType,
) -> Int? {
  match storage.unpack() {
    @lib.ValType::NumTypeValType(@lib.NumType::I32NumType) =>
      Some(@ir.hot_build_const_i32(func, @lib.I32(0)))
    @lib.ValType::NumTypeValType(@lib.NumType::I64NumType) =>
      Some(@ir.hot_build_const_i64(func, @lib.I64(0L)))
    @lib.ValType::NumTypeValType(@lib.NumType::F32NumType) =>
      Some(@ir.hot_build_const_f32(func, @lib.F32(0.0)))
    @lib.ValType::NumTypeValType(@lib.NumType::F64NumType) =>
      Some(@ir.hot_build_const_f64(func, @lib.F64(0.0)))
    @lib.ValType::VecTypeValType => Some(@ir.hot_build_const_v128_zero(func))
    @lib.ValType::RefTypeValType(ref_type) =>
      if ref_type.is_nullable() {
        Some(@ir.hot_build_ref_null(func, ref_type))
      } else {
        None
      }
    @lib.ValType::BotValType => None
  }
}

///|
fn optimize_instructions_struct_default_field_value(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  type_idx : @lib.TypeIdx,
  field_idx : Int,
) -> Int? {
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return None
  }
  let fields = match
    @ir.hot_module_resolve_struct_fields(module_ctx, type_idx) {
    Some(fields) => fields
    None => return None
  }
  if field_idx < 0 || field_idx >= fields.length() {
    return None
  }
  optimize_instructions_default_value_for_storage(
    func,
    fields[field_idx].get_storage_type(),
  )
}

///|
fn optimize_instructions_array_default_element_value(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  type_idx : @lib.TypeIdx,
) -> Int? {
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return None
  }
  let field = match @ir.hot_module_resolve_array_field(module_ctx, type_idx) {
    Some(field) => field
    None => return None
  }
  optimize_instructions_default_value_for_storage(
    func,
    field.get_storage_type(),
  )
}

///|
fn optimize_instructions_replace_with_packed_i32_value(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  value_id : Int,
  bits : Int,
  signed : Bool,
) -> Unit {
  match optimize_instructions_i32_const(func, dead, value_id) {
    Some(@lib.I32(raw)) =>
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        optimize_instructions_packed_i32_const(raw, bits, signed),
      )
    None =>
      if signed {
        let instr = if bits == 8 {
          @lib.Instruction::i32_extend8s()
        } else {
          @lib.Instruction::i32_extend16s()
        }
        optimize_instructions_replace_with_exact_unary(
          ctx, func, node_id, instr, value_id,
        )
      } else {
        let mask = if bits == 8 { 255 } else { 65535 }
        let replacement = optimize_instructions_build_i32_binary(
          func,
          @lib.Instruction::i32_and(),
          value_id,
          @ir.hot_build_const_i32(func, @lib.I32(mask)),
        )
        optimize_instructions_replace_with_node_id(
          ctx, func, node_id, replacement,
        )
      }
  }
}

///|
fn optimize_instructions_try_fold_tuple_extract_tuple_make(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::TupleExtract if node.child_count == 1 => ()
    _ => return false
  }
  let tuple_id = @ir.hot_child_get(func, node_id, 0)
  if !optimize_instructions_node_is_live(func, dead, tuple_id) ||
    pass_node_use_count(ctx, func, tuple_id) != 1 {
    return false
  }
  let tuple = @ir.hot_node_get(func, tuple_id)
  match tuple.op {
    @ir.HotOp::TupleMake => ()
    _ => return false
  }
  let index = node.imm0
  if index < 0 || index >= tuple.child_count {
    return false
  }
  let selected_id = @ir.hot_child_get(func, tuple_id, index)
  let selected_results = @ir.hot_type_results(
    func,
    @ir.hot_node_get(func, selected_id).ty,
  )
  if selected_results.length() != 1 {
    return false
  }
  let mut has_effectful_sibling = false
  let mut has_later_effectful_sibling = false
  for slot = 0; slot < tuple.child_count; slot = slot + 1 {
    if slot == index {
      continue
    }
    let sibling_id = @ir.hot_child_get(func, tuple_id, slot)
    if !optimize_instructions_node_effects_are_pure(ctx, func, sibling_id) {
      has_effectful_sibling = true
      if slot > index {
        has_later_effectful_sibling = true
      }
      let sibling_results = @ir.hot_type_results(
        func,
        @ir.hot_node_get(func, sibling_id).ty,
      )
      if sibling_results.length() > 1 {
        return false
      }
    }
  }
  if !has_effectful_sibling {
    optimize_instructions_replace_with_node_id(ctx, func, node_id, selected_id)
    return true
  }
  let body : Array[Int] = []
  let mut selected_local : Int = -1
  if has_later_effectful_sibling {
    selected_local = @ir.hot_append_body_local(func, selected_results[0])
  }
  for slot = 0; slot < tuple.child_count; slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, tuple_id, slot)
    if slot == index {
      if has_later_effectful_sibling {
        body.push(@ir.hot_build_local_set(func, selected_local, selected_id))
      }
      continue
    }
    if optimize_instructions_node_effects_are_pure(ctx, func, child_id) {
      continue
    }
    let child_results = @ir.hot_type_results(
      func,
      @ir.hot_node_get(func, child_id).ty,
    )
    match child_results.length() {
      0 => body.push(child_id)
      1 => body.push(@ir.hot_build_drop(func, child_id))
      _ => return false
    }
  }
  if has_later_effectful_sibling {
    body.push(@ir.hot_build_local_get(func, selected_local))
  } else {
    body.push(selected_id)
  }
  let replacement = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(selected_results[0]),
    body,
  )
  optimize_instructions_replace_with_node_id(ctx, func, node_id, replacement)
  true
}

///|
/// Binaryen version_130 keeps fresh array lengths above this O4z-observed
/// limit to preserve allocation trap behavior.
fn optimize_instructions_array_new_len_is_known_non_trapping(len : Int) -> Bool {
  len >= 0 && len <= 44739241
}

///|
fn optimize_instructions_try_fold_array_len_new_fixed(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 1 {
    return false
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::ArrayLen) => ()
    _ => return false
  }
  let array_id = @ir.hot_child_get(func, node_id, 0)
  if !optimize_instructions_node_is_live(func, dead, array_id) ||
    pass_node_use_count(ctx, func, array_id) != 1 {
    return false
  }
  let array_node = @ir.hot_node_get(func, array_id)
  let len = match @ir.hot_node_exact_instr(func, array_id) {
    Some(@lib.Instruction::ArrayNewFixed(_, @lib.U32(len))) => {
      let len = len.reinterpret_as_int()
      if len != array_node.child_count {
        return false
      }
      for i = 0; i < array_node.child_count; i = i + 1 {
        if !optimize_instructions_node_effects_are_pure(
            ctx,
            func,
            @ir.hot_child_get(func, array_id, i),
          ) {
          return false
        }
      }
      len
    }
    Some(@lib.Instruction::ArrayNewDefault(_)) => {
      if array_node.child_count != 1 {
        return false
      }
      let len = match
        optimize_instructions_i32_const(
          func,
          dead,
          @ir.hot_child_get(func, array_id, 0),
        ) {
        Some(@lib.I32(len)) if optimize_instructions_array_new_len_is_known_non_trapping(
            len,
          ) => len
        _ => return false
      }
      len
    }
    Some(@lib.Instruction::ArrayNew(_)) => {
      if array_node.child_count != 2 {
        return false
      }
      match
        optimize_instructions_i32_const(
          func,
          dead,
          @ir.hot_child_get(func, array_id, 0),
        ) {
        Some(_) => ()
        None => return false
      }
      let len = match
        optimize_instructions_i32_const(
          func,
          dead,
          @ir.hot_child_get(func, array_id, 1),
        ) {
        Some(@lib.I32(len)) if optimize_instructions_array_new_len_is_known_non_trapping(
            len,
          ) => len
        _ => return false
      }
      len
    }
    _ => return false
  }
  optimize_instructions_replace_with_const_i32(
    ctx,
    func,
    node_id,
    @lib.I32(len),
  )
  true
}

///|
fn optimize_instructions_try_fold_array_get_new_fixed(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 2 {
    return false
  }
  let (type_idx, packed_signed) = match
    @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::ArrayGet(type_idx)) => (type_idx, None)
    Some(@lib.Instruction::ArrayGetS(type_idx)) => (type_idx, Some(true))
    Some(@lib.Instruction::ArrayGetU(type_idx)) => (type_idx, Some(false))
    _ => return false
  }
  let array_id = @ir.hot_child_get(func, node_id, 0)
  let index_id = @ir.hot_child_get(func, node_id, 1)
  if !optimize_instructions_node_is_live(func, dead, array_id) ||
    pass_node_use_count(ctx, func, array_id) != 1 {
    return false
  }
  let index = match optimize_instructions_i32_const(func, dead, index_id) {
    Some(@lib.I32(index)) => index
    _ => return false
  }
  let array_node = @ir.hot_node_get(func, array_id)
  // 0 = array.new_fixed, 1 = array.new_default, 2 = array.new repeated value.
  let (array_kind, len) = match @ir.hot_node_exact_instr(func, array_id) {
    Some(@lib.Instruction::ArrayNewFixed(new_type_idx, @lib.U32(len))) if new_type_idx ==
      type_idx => {
      let len = len.reinterpret_as_int()
      if len != array_node.child_count {
        return false
      }
      (0, len)
    }
    Some(@lib.Instruction::ArrayNewDefault(new_type_idx)) if new_type_idx ==
      type_idx => {
      if array_node.child_count != 1 {
        return false
      }
      let len = match
        optimize_instructions_i32_const(
          func,
          dead,
          @ir.hot_child_get(func, array_id, 0),
        ) {
        Some(@lib.I32(len)) => len
        _ => return false
      }
      (1, len)
    }
    Some(@lib.Instruction::ArrayNew(new_type_idx)) if new_type_idx == type_idx => {
      if array_node.child_count != 2 {
        return false
      }
      let len = match
        optimize_instructions_i32_const(
          func,
          dead,
          @ir.hot_child_get(func, array_id, 1),
        ) {
        Some(@lib.I32(len)) if optimize_instructions_array_new_len_is_known_non_trapping(
            len,
          ) => len
        _ => return false
      }
      (2, len)
    }
    _ => return false
  }
  if array_kind == 0 {
    for i = 0; i < array_node.child_count; i = i + 1 {
      if (index < 0 || index >= len || i != index) &&
        !optimize_instructions_node_effects_are_pure(
          ctx,
          func,
          @ir.hot_child_get(func, array_id, i),
        ) {
        return false
      }
    }
  } else if array_kind == 2 &&
    (index < 0 || index >= len) &&
    !optimize_instructions_node_effects_are_pure(
      ctx,
      func,
      @ir.hot_child_get(func, array_id, 0),
    ) {
    return false
  }
  if index < 0 || index >= len {
    if !optimize_instructions_node_effects_are_pure(ctx, func, index_id) {
      return false
    }
    optimize_instructions_replace_with_unreachable(ctx, func, node_id)
  } else {
    let value_id = if array_kind == 0 {
      @ir.hot_child_get(func, array_id, index)
    } else if array_kind == 1 {
      match
        optimize_instructions_array_default_element_value(ctx, func, type_idx) {
        Some(value_id) => value_id
        None => return false
      }
    } else {
      @ir.hot_child_get(func, array_id, 0)
    }
    match packed_signed {
      Some(signed) => {
        let bits = match
          optimize_instructions_array_field_pack_bits(ctx, type_idx) {
          Some(bits) => bits
          None => return false
        }
        optimize_instructions_replace_with_packed_i32_value(
          ctx, func, dead, node_id, value_id, bits, signed,
        )
      }
      None =>
        optimize_instructions_replace_with_node_id(ctx, func, node_id, value_id)
    }
  }
  true
}

///|
fn optimize_instructions_replace_with_nop(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Unit {
  let temp = @ir.hot_build_nop(func)
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_try_remove_array_set_fresh_array(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 3 {
    return false
  }
  let type_idx = match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::ArraySet(type_idx)) => type_idx
    _ => return false
  }
  let array_id = @ir.hot_child_get(func, node_id, 0)
  let index_id = @ir.hot_child_get(func, node_id, 1)
  let value_id = @ir.hot_child_get(func, node_id, 2)
  if !optimize_instructions_node_is_live(func, dead, array_id) ||
    pass_node_use_count(ctx, func, array_id) != 1 {
    return false
  }
  let index = match optimize_instructions_i32_const(func, dead, index_id) {
    Some(@lib.I32(index)) => index
    _ => return false
  }
  if !optimize_instructions_node_effects_are_pure(ctx, func, value_id) {
    return false
  }
  let array_node = @ir.hot_node_get(func, array_id)
  let len = match @ir.hot_node_exact_instr(func, array_id) {
    Some(@lib.Instruction::ArrayNewFixed(new_type_idx, @lib.U32(len))) if new_type_idx ==
      type_idx => {
      let len = len.reinterpret_as_int()
      if len != array_node.child_count {
        return false
      }
      for i = 0; i < array_node.child_count; i = i + 1 {
        if !optimize_instructions_node_effects_are_pure(
            ctx,
            func,
            @ir.hot_child_get(func, array_id, i),
          ) {
          return false
        }
      }
      len
    }
    Some(@lib.Instruction::ArrayNewDefault(new_type_idx)) if new_type_idx ==
      type_idx => {
      if array_node.child_count != 1 {
        return false
      }
      match
        optimize_instructions_i32_const(
          func,
          dead,
          @ir.hot_child_get(func, array_id, 0),
        ) {
        Some(@lib.I32(len)) if optimize_instructions_array_new_len_is_known_non_trapping(
            len,
          ) => len
        _ => return false
      }
    }
    Some(@lib.Instruction::ArrayNew(new_type_idx)) if new_type_idx == type_idx => {
      if array_node.child_count != 2 {
        return false
      }
      if !optimize_instructions_node_effects_are_pure(
          ctx,
          func,
          @ir.hot_child_get(func, array_id, 0),
        ) {
        return false
      }
      match
        optimize_instructions_i32_const(
          func,
          dead,
          @ir.hot_child_get(func, array_id, 1),
        ) {
        Some(@lib.I32(len)) if optimize_instructions_array_new_len_is_known_non_trapping(
            len,
          ) => len
        _ => return false
      }
    }
    _ => return false
  }
  if index < 0 || index >= len {
    optimize_instructions_replace_with_unreachable(ctx, func, node_id)
  } else {
    optimize_instructions_replace_with_nop(ctx, func, node_id)
  }
  true
}

///|
fn optimize_instructions_try_fold_struct_get_struct_new(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 1 {
    return false
  }
  let (type_idx, field_idx, packed_signed) = match
    @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::StructGet(type_idx, @lib.U32(field_idx))) =>
      (type_idx, field_idx.reinterpret_as_int(), None)
    Some(@lib.Instruction::StructGetS(type_idx, @lib.U32(field_idx))) =>
      (type_idx, field_idx.reinterpret_as_int(), Some(true))
    Some(@lib.Instruction::StructGetU(type_idx, @lib.U32(field_idx))) =>
      (type_idx, field_idx.reinterpret_as_int(), Some(false))
    _ => return false
  }
  let struct_id = @ir.hot_child_get(func, node_id, 0)
  if !optimize_instructions_node_is_live(func, dead, struct_id) ||
    pass_node_use_count(ctx, func, struct_id) != 1 {
    return false
  }
  let struct_node = @ir.hot_node_get(func, struct_id)
  let value_id = match @ir.hot_node_exact_instr(func, struct_id) {
    Some(@lib.Instruction::StructNew(new_type_idx)) if new_type_idx == type_idx => {
      if field_idx < 0 || field_idx >= struct_node.child_count {
        return false
      }
      for i = 0; i < struct_node.child_count; i = i + 1 {
        if i != field_idx &&
          !optimize_instructions_node_effects_are_pure(
            ctx,
            func,
            @ir.hot_child_get(func, struct_id, i),
          ) {
          return false
        }
      }
      @ir.hot_child_get(func, struct_id, field_idx)
    }
    Some(@lib.Instruction::StructNewDefault(new_type_idx)) if new_type_idx ==
      type_idx =>
      match
        optimize_instructions_struct_default_field_value(
          ctx, func, type_idx, field_idx,
        ) {
        Some(value_id) => value_id
        None => return false
      }
    _ => return false
  }
  match packed_signed {
    Some(signed) => {
      let bits = match
        optimize_instructions_struct_field_pack_bits(ctx, type_idx, field_idx) {
        Some(bits) => bits
        None => return false
      }
      optimize_instructions_replace_with_packed_i32_value(
        ctx, func, dead, node_id, value_id, bits, signed,
      )
    }
    None =>
      optimize_instructions_replace_with_node_id(ctx, func, node_id, value_id)
  }
  true
}

///|
fn optimize_instructions_try_truncate_narrow_store_const_value(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 2 {
    return false
  }
  let instr = match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) => instr
    None => return false
  }
  let bits = match optimize_instructions_store_value_bits(instr) {
    Some(bits) => bits
    None => return false
  }
  let value_id = @ir.hot_child_get(func, node_id, 1)
  let new_value_id = if optimize_instructions_store_value_is_i64(instr) {
    let raw = match optimize_instructions_i64_const(func, dead, value_id) {
      Some(@lib.I64(raw)) => raw
      _ => return false
    }
    let mask = (1L << bits) - 1L
    let truncated = raw & mask
    if truncated == raw {
      return false
    }
    @ir.hot_build_const_i64(func, @lib.I64(truncated))
  } else {
    let raw = match optimize_instructions_i32_const(func, dead, value_id) {
      Some(@lib.I32(raw)) => raw
      _ => return false
    }
    let mask = (1 << bits) - 1
    let truncated = raw & mask
    if truncated == raw {
      return false
    }
    @ir.hot_build_const_i32(func, @lib.I32(truncated))
  }
  optimize_instructions_rewrite_exact_with_children(ctx, func, node_id, instr, [
    @ir.hot_child_get(func, node_id, 0),
    new_value_id,
  ])
  true
}

///|
fn optimize_instructions_try_drop_narrow_store_value_mask(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 2 {
    return false
  }
  let instr = match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) => instr
    None => return false
  }
  let bits = match optimize_instructions_store_value_bits(instr) {
    Some(bits) => bits
    None => return false
  }
  let value_id = @ir.hot_child_get(func, node_id, 1)
  if !optimize_instructions_node_is_live(func, dead, value_id) {
    return false
  }
  let value = @ir.hot_node_get(func, value_id)
  match value.op {
    @ir.HotOp::Binary => ()
    _ => return false
  }
  if value.child_count != 2 {
    return false
  }
  let expected_and = if optimize_instructions_store_value_is_i64(instr) {
    @lib.Instruction::i64_and()
  } else {
    @lib.Instruction::i32_and()
  }
  if @ir.hot_node_exact_instr(func, value_id) != Some(expected_and) {
    return false
  }
  let lhs_id = @ir.hot_child_get(func, value_id, 0)
  let rhs_id = @ir.hot_child_get(func, value_id, 1)
  let unmasked_id = if optimize_instructions_store_value_is_i64(instr) {
    let (mask, unmasked_id) = match
      optimize_instructions_i64_const(func, dead, rhs_id) {
      Some(@lib.I64(raw)) => (raw, lhs_id)
      _ =>
        match optimize_instructions_i64_const(func, dead, lhs_id) {
          Some(@lib.I64(raw)) => (raw, rhs_id)
          _ => return false
        }
    }
    let required_mask = (1L << bits) - 1L
    if (mask & required_mask) != required_mask {
      return false
    }
    unmasked_id
  } else {
    let (mask, unmasked_id) = match
      optimize_instructions_i32_const(func, dead, rhs_id) {
      Some(@lib.I32(raw)) => (raw, lhs_id)
      _ =>
        match optimize_instructions_i32_const(func, dead, lhs_id) {
          Some(@lib.I32(raw)) => (raw, rhs_id)
          _ => return false
        }
    }
    let required_mask = (1 << bits) - 1
    if (mask & required_mask) != required_mask {
      return false
    }
    unmasked_id
  }
  optimize_instructions_rewrite_exact_with_children(ctx, func, node_id, instr, [
    @ir.hot_child_get(func, node_id, 0),
    unmasked_id,
  ])
  true
}

///|
fn optimize_instructions_try_rewrite_reinterpret_store_value(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 2 {
    return false
  }
  let instr = match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) => instr
    None => return false
  }
  let value_id = @ir.hot_child_get(func, node_id, 1)
  if !optimize_instructions_node_is_live(func, dead, value_id) {
    return false
  }
  let value = @ir.hot_node_get(func, value_id)
  if value.child_count != 1 {
    return false
  }
  let new_instr = match (instr, @ir.hot_node_exact_instr(func, value_id)) {
    (
      @lib.Instruction::F32Store(memarg),
      Some(@lib.Instruction::F32ReinterpretI32),
    ) => @lib.Instruction::i32_store(memarg)
    (
      @lib.Instruction::F64Store(memarg),
      Some(@lib.Instruction::F64ReinterpretI64),
    ) => @lib.Instruction::i64_store(memarg)
    (
      @lib.Instruction::I32Store(memarg),
      Some(@lib.Instruction::I32ReinterpretF32),
    ) => @lib.Instruction::f32_store(memarg)
    (
      @lib.Instruction::I64Store(memarg),
      Some(@lib.Instruction::I64ReinterpretF64),
    ) => @lib.Instruction::f64_store(memarg)
    _ => return false
  }
  optimize_instructions_rewrite_exact_with_children(
    ctx,
    func,
    node_id,
    new_instr,
    [@ir.hot_child_get(func, node_id, 0), @ir.hot_child_get(func, value_id, 0)],
  )
  true
}

///|
fn optimize_instructions_try_rewrite_reinterpret_load_result(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 1 {
    return false
  }
  let load_id = @ir.hot_child_get(func, node_id, 0)
  if !optimize_instructions_node_is_live(func, dead, load_id) ||
    pass_node_use_count(ctx, func, load_id) != 1 {
    return false
  }
  let load = @ir.hot_node_get(func, load_id)
  if load.child_count != 1 {
    return false
  }
  let new_instr = match
    (
      @ir.hot_node_exact_instr(func, load_id),
      @ir.hot_node_exact_instr(func, node_id),
    ) {
    (
      Some(@lib.Instruction::I32Load(memarg)),
      Some(@lib.Instruction::F32ReinterpretI32),
    ) => @lib.Instruction::f32_load(memarg)
    (
      Some(@lib.Instruction::I64Load(memarg)),
      Some(@lib.Instruction::F64ReinterpretI64),
    ) => @lib.Instruction::f64_load(memarg)
    (
      Some(@lib.Instruction::F32Load(memarg)),
      Some(@lib.Instruction::I32ReinterpretF32),
    ) => @lib.Instruction::i32_load(memarg)
    (
      Some(@lib.Instruction::F64Load(memarg)),
      Some(@lib.Instruction::I64ReinterpretF64),
    ) => @lib.Instruction::i64_load(memarg)
    _ => return false
  }
  optimize_instructions_rewrite_exact_with_children(
    ctx,
    func,
    node_id,
    new_instr,
    [@ir.hot_child_get(func, load_id, 0)],
  )
  true
}

///|
fn optimize_instructions_try_rewrite_i64_extend_i32_load_result(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 1 {
    return false
  }
  let load_id = @ir.hot_child_get(func, node_id, 0)
  if !optimize_instructions_node_is_live(func, dead, load_id) ||
    pass_node_use_count(ctx, func, load_id) != 1 {
    return false
  }
  let load = @ir.hot_node_get(func, load_id)
  if load.child_count != 1 {
    return false
  }
  let new_instr = match
    (
      @ir.hot_node_exact_instr(func, load_id),
      @ir.hot_node_exact_instr(func, node_id),
    ) {
    (
      Some(@lib.Instruction::I32Load(memarg)),
      Some(@lib.Instruction::I64ExtendI32U),
    ) => @lib.Instruction::i64_load32u(memarg)
    (
      Some(@lib.Instruction::I32Load(memarg)),
      Some(@lib.Instruction::I64ExtendI32S),
    ) => @lib.Instruction::i64_load32s(memarg)
    (
      Some(@lib.Instruction::I32Load8U(memarg)),
      Some(@lib.Instruction::I64ExtendI32U | @lib.Instruction::I64ExtendI32S),
    ) => @lib.Instruction::i64_load8u(memarg)
    (
      Some(@lib.Instruction::I32Load16U(memarg)),
      Some(@lib.Instruction::I64ExtendI32U | @lib.Instruction::I64ExtendI32S),
    ) => @lib.Instruction::i64_load16u(memarg)
    (
      Some(@lib.Instruction::I32Load8S(memarg)),
      Some(@lib.Instruction::I64ExtendI32S),
    ) => @lib.Instruction::i64_load8s(memarg)
    (
      Some(@lib.Instruction::I32Load16S(memarg)),
      Some(@lib.Instruction::I64ExtendI32S),
    ) => @lib.Instruction::i64_load16s(memarg)
    _ => return false
  }
  optimize_instructions_rewrite_exact_with_children(
    ctx,
    func,
    node_id,
    new_instr,
    [@ir.hot_child_get(func, load_id, 0)],
  )
  true
}

///|
fn optimize_instructions_try_widen_store_of_wrap_i64(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 2 {
    return false
  }
  // Storing the low N bits of (i32.wrap_i64 x) is equivalent to storing the low
  // N bits of x directly via the matching i64 narrow store, so a direct one-use
  // wrap value child can be dropped by widening the store.
  let new_instr = match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::I32Store8(ma)) => @lib.Instruction::i64_store8(ma)
    Some(@lib.Instruction::I32Store16(ma)) => @lib.Instruction::i64_store16(ma)
    Some(@lib.Instruction::I32Store(ma)) => @lib.Instruction::i64_store32(ma)
    _ => return false
  }
  let value_id = @ir.hot_child_get(func, node_id, 1)
  if !optimize_instructions_node_is_live(func, dead, value_id) {
    return false
  }
  match @ir.hot_node_exact_instr(func, value_id) {
    Some(@lib.Instruction::I32WrapI64) => ()
    _ => return false
  }
  let value = @ir.hot_node_get(func, value_id)
  if value.child_count != 1 {
    return false
  }
  // Only drop the wrap when this store is its sole use, so the wrap node can be
  // cleaned up instead of leaving a dangling i32 producer.
  if pass_node_use_count(ctx, func, value_id) != 1 {
    return false
  }
  let wide_value_id = @ir.hot_child_get(func, value_id, 0)
  optimize_instructions_rewrite_exact_with_children(
    ctx,
    func,
    node_id,
    new_instr,
    [@ir.hot_child_get(func, node_id, 0), wide_value_id],
  )
  true
}

///|
fn optimize_instructions_try_expand_tiny_memory_copy(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 3 {
    return false
  }
  let size_id = @ir.hot_child_get(func, node_id, 2)
  let size = match
    optimize_instructions_const_memory_size(func, dead, size_id) {
    Some(size) => size
    _ => return false
  }
  let dst_id = @ir.hot_child_get(func, node_id, 0)
  let src_id = @ir.hot_child_get(func, node_id, 1)
  let src_memarg = optimize_instructions_memarg_for_mem_idx(node.imm1)
  let (load_ty, load_instr, store_instr) = match size {
    1 =>
      (
        @lib.ValType::i32(),
        @lib.Instruction::i32_load8u,
        @lib.Instruction::i32_store8,
      )
    2 =>
      (
        @lib.ValType::i32(),
        @lib.Instruction::i32_load16u,
        @lib.Instruction::i32_store16,
      )
    4 =>
      (
        @lib.ValType::i32(),
        @lib.Instruction::i32_load,
        @lib.Instruction::i32_store,
      )
    8 =>
      (
        @lib.ValType::i64(),
        @lib.Instruction::i64_load,
        @lib.Instruction::i64_store,
      )
    16 =>
      (
        @lib.ValType::v128(),
        @lib.Instruction::v128_load,
        @lib.Instruction::v128_store,
      )
    _ => return false
  }
  let load = @ir.hot_build_load(func, load_ty, src_memarg, src_id)
  @ir.hot_node_exact_instr_set(func, load, load_instr(src_memarg))
  optimize_instructions_replace_with_store_exact(
    ctx,
    func,
    node_id,
    node.imm0,
    dst_id,
    load,
    store_instr,
  )
  true
}

///|
fn optimize_instructions_try_expand_tiny_memory_fill(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 3 {
    return false
  }
  let size_id = @ir.hot_child_get(func, node_id, 2)
  let size = match
    optimize_instructions_const_memory_size(func, dead, size_id) {
    Some(size) => size
    _ => return false
  }
  let dst_id = @ir.hot_child_get(func, node_id, 0)
  let value_id = @ir.hot_child_get(func, node_id, 1)
  match size {
    1 => {
      let stored_id = match
        optimize_instructions_i32_const(func, dead, value_id) {
        Some(@lib.I32(raw)) =>
          match optimize_instructions_repeated_fill_i32(raw, 1) {
            Some(value) => @ir.hot_build_const_i32(func, value)
            None => return false
          }
        _ => value_id
      }
      optimize_instructions_replace_with_store8(
        ctx,
        func,
        node_id,
        node.imm0,
        dst_id,
        stored_id,
      )
    }
    2 | 4 => {
      let repeated_id = match
        optimize_instructions_i32_const(func, dead, value_id) {
        Some(@lib.I32(raw)) =>
          match optimize_instructions_repeated_fill_i32(raw, size) {
            Some(value) => @ir.hot_build_const_i32(func, value)
            None => return false
          }
        _ => {
          let value = @ir.hot_node_get(func, value_id)
          match value.op {
            @ir.HotOp::LocalGet =>
              match
                optimize_instructions_repeated_fill_i32_for_local_get(
                  func,
                  value.imm0,
                  size,
                ) {
                Some(repeated_id) => repeated_id
                None => return false
              }
            _ => return false
          }
        }
      }
      let instr_for_memarg = match size {
        2 => @lib.Instruction::i32_store16
        4 => @lib.Instruction::i32_store
        _ => return false
      }
      optimize_instructions_replace_with_store_exact(
        ctx,
        func,
        node_id,
        node.imm0,
        dst_id,
        repeated_id,
        instr_for_memarg,
      )
    }
    8 => {
      let repeated_id = match
        optimize_instructions_i32_const(func, dead, value_id) {
        Some(@lib.I32(raw)) =>
          @ir.hot_build_const_i64(
            func,
            optimize_instructions_repeated_fill_i64(raw),
          )
        _ => {
          let value = @ir.hot_node_get(func, value_id)
          match value.op {
            @ir.HotOp::LocalGet =>
              optimize_instructions_repeated_fill_i64_for_local_get(
                func,
                value.imm0,
              )
            _ => return false
          }
        }
      }
      optimize_instructions_replace_with_store_exact(
        ctx,
        func,
        node_id,
        node.imm0,
        dst_id,
        repeated_id,
        @lib.Instruction::i64_store,
      )
    }
    16 => {
      let repeated_id = match
        optimize_instructions_i32_const(func, dead, value_id) {
        Some(@lib.I32(raw)) =>
          optimize_instructions_build_repeated_fill_v128_const(func, raw)
        _ => return false
      }
      optimize_instructions_replace_with_store_exact(
        ctx,
        func,
        node_id,
        node.imm0,
        dst_id,
        repeated_id,
        @lib.Instruction::v128_store,
      )
    }
    _ => return false
  }
  true
}

///|
fn optimize_instructions_try_fold_const_select(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Select if node.child_count == 3 => ()
    _ => return false
  }
  let if_true = @ir.hot_child_get(func, node_id, 0)
  let if_false = @ir.hot_child_get(func, node_id, 1)
  let condition = @ir.hot_child_get(func, node_id, 2)
  let (chosen, dead_arm) = match
    optimize_instructions_i32_const(func, dead, condition) {
    Some(@lib.I32(raw)) if raw == 0 => (if_false, if_true)
    Some(@lib.I32(_)) => (if_true, if_false)
    _ => return false
  }
  if !optimize_instructions_is_side_effect_free_expr(func, dead, dead_arm) {
    return false
  }
  if !optimize_instructions_is_side_effect_free_expr(func, dead, chosen) {
    let use_def = pass_require_use_def(ctx, func)
    if @ir.node_use_count(use_def, chosen) != 1 {
      return false
    }
  }
  optimize_instructions_replace_with_node_id(ctx, func, node_id, chosen)
  true
}

///|
fn optimize_instructions_try_fold_eqz(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  operand_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, operand_id) {
    return false
  }
  let operand = func.nodes[operand_id]
  match (instr, operand.op, @ir.hot_node_exact_instr(func, operand_id)) {
    (@lib.Instruction::I32Eqz, @ir.HotOp::Binary, Some(@lib.Instruction::I32Sub)
    )
    | (
      @lib.Instruction::I64Eqz,
      @ir.HotOp::Binary,
      Some(@lib.Instruction::I64Sub),
    ) => {
      let lhs_id = @ir.hot_child_get(func, operand_id, 0)
      let rhs_id = @ir.hot_child_get(func, operand_id, 1)
      optimize_instructions_replace_with_exact_compare(
        ctx,
        func,
        node_id,
        match instr {
          @lib.Instruction::I32Eqz => @lib.Instruction::i32_eq()
          _ => @lib.Instruction::i64_eq()
        },
        lhs_id,
        rhs_id,
      )
      return true
    }
    (@lib.Instruction::I32Eqz, @ir.HotOp::Binary, Some(@lib.Instruction::I32Add)
    ) => {
      let lhs_id = @ir.hot_child_get(func, operand_id, 0)
      let rhs_id = @ir.hot_child_get(func, operand_id, 1)
      match
        (
          optimize_instructions_i32_const(func, dead, lhs_id),
          optimize_instructions_i32_const(func, dead, rhs_id),
        ) {
        (Some(@lib.I32(raw)), _) => {
          optimize_instructions_replace_with_exact_compare(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_eq(),
            rhs_id,
            @ir.hot_build_const_i32(func, @lib.I32(-raw)),
          )
          return true
        }
        (_, Some(@lib.I32(raw))) => {
          optimize_instructions_replace_with_exact_compare(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_eq(),
            lhs_id,
            @ir.hot_build_const_i32(func, @lib.I32(-raw)),
          )
          return true
        }
        _ => ()
      }
    }
    (@lib.Instruction::I64Eqz, @ir.HotOp::Binary, Some(@lib.Instruction::I64Add)
    ) => {
      let lhs_id = @ir.hot_child_get(func, operand_id, 0)
      let rhs_id = @ir.hot_child_get(func, operand_id, 1)
      match
        (
          optimize_instructions_i64_const(func, dead, lhs_id),
          optimize_instructions_i64_const(func, dead, rhs_id),
        ) {
        (Some(@lib.I64(raw)), _) => {
          optimize_instructions_replace_with_exact_compare(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_eq(),
            rhs_id,
            @ir.hot_build_const_i64(func, @lib.I64(-raw)),
          )
          return true
        }
        (_, Some(@lib.I64(raw))) => {
          optimize_instructions_replace_with_exact_compare(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_eq(),
            lhs_id,
            @ir.hot_build_const_i64(func, @lib.I64(-raw)),
          )
          return true
        }
        _ => ()
      }
    }
    _ => ()
  }
  false
}

///|
fn optimize_instructions_try_fold_exact_const_binary(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match
    (
      instr,
      optimize_instructions_i32_const(func, dead, lhs_id),
      optimize_instructions_i32_const(func, dead, rhs_id),
    ) {
    (@lib.Instruction::I32Add, Some(@lib.I32(lhs_raw)), Some(@lib.I32(rhs_raw))) => {
      let folded = @lib.I32(
        (lhs_raw.reinterpret_as_uint() + rhs_raw.reinterpret_as_uint()).reinterpret_as_int(),
      )
      optimize_instructions_replace_with_const_i32(ctx, func, node_id, folded)
      true
    }
    (@lib.Instruction::I32Sub, Some(@lib.I32(lhs_raw)), Some(@lib.I32(rhs_raw))) => {
      let folded = @lib.I32(
        (lhs_raw.reinterpret_as_uint() - rhs_raw.reinterpret_as_uint()).reinterpret_as_int(),
      )
      optimize_instructions_replace_with_const_i32(ctx, func, node_id, folded)
      true
    }
    _ =>
      match
        (
          instr,
          optimize_instructions_i64_const(func, dead, lhs_id),
          optimize_instructions_i64_const(func, dead, rhs_id),
        ) {
        (
          @lib.Instruction::I64Add,
          Some(@lib.I64(lhs_raw)),
          Some(@lib.I64(rhs_raw)),
        ) => {
          let folded = @lib.I64(
            (lhs_raw.reinterpret_as_uint64() + rhs_raw.reinterpret_as_uint64()).reinterpret_as_int64(),
          )
          optimize_instructions_replace_with_const_i64(
            ctx, func, node_id, folded,
          )
          true
        }
        (
          @lib.Instruction::I64Sub,
          Some(@lib.I64(lhs_raw)),
          Some(@lib.I64(rhs_raw)),
        ) => {
          let folded = @lib.I64(
            (lhs_raw.reinterpret_as_uint64() - rhs_raw.reinterpret_as_uint64()).reinterpret_as_int64(),
          )
          optimize_instructions_replace_with_const_i64(
            ctx, func, node_id, folded,
          )
          true
        }
        _ => false
      }
  }
}

///|
fn optimize_instructions_i32_identity_operand(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs_id : Int,
  rhs_id : Int,
  identity : Int,
) -> Int? {
  match
    (
      optimize_instructions_i32_const(func, dead, lhs_id),
      optimize_instructions_i32_const(func, dead, rhs_id),
    ) {
    (Some(@lib.I32(raw)), _) if raw == identity => Some(rhs_id)
    (_, Some(@lib.I32(raw))) if raw == identity => Some(lhs_id)
    _ => None
  }
}

///|
fn optimize_instructions_i64_identity_operand(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs_id : Int,
  rhs_id : Int,
  identity : Int64,
) -> Int? {
  match
    (
      optimize_instructions_i64_const(func, dead, lhs_id),
      optimize_instructions_i64_const(func, dead, rhs_id),
    ) {
    (Some(@lib.I64(raw)), _) if raw == identity => Some(rhs_id)
    (_, Some(@lib.I64(raw))) if raw == identity => Some(lhs_id)
    _ => None
  }
}

///|
fn optimize_instructions_try_fold_identity_binary(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  // A constant identity operand makes these binary ops a no-op. The symmetric
  // cases allow the constant on either side; `sub` is asymmetric because
  // `sub(0, x)` is `-x`, not `x`. `rem(_, 1) -> 0` is asymmetric and requires a
  // pure lhs operand, because folding to the constant would otherwise drop the
  // lhs effect (Binaryen keeps `rem(effect, 1)`).
  match instr {
    @lib.Instruction::I32RemS | @lib.Instruction::I32RemU => {
      let rhs_is_one = match
        optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(raw)) => raw == 1
        _ => false
      }
      if rhs_is_one &&
        optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) {
        optimize_instructions_replace_with_const_i32(
          ctx,
          func,
          node_id,
          @lib.I32(0),
        )
        return true
      }
    }
    @lib.Instruction::I64RemS | @lib.Instruction::I64RemU => {
      let rhs_is_one = match
        optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(raw)) => raw == 1L
        _ => false
      }
      if rhs_is_one &&
        optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) {
        optimize_instructions_replace_with_const_i64(
          ctx,
          func,
          node_id,
          @lib.I64(0L),
        )
        return true
      }
    }
    _ => ()
  }
  let keep_id = match instr {
    @lib.Instruction::I32Or
    | @lib.Instruction::I32Xor
    | @lib.Instruction::I32Add
    | @lib.Instruction::I32Shl
    | @lib.Instruction::I32ShrU
    | @lib.Instruction::I32ShrS =>
      optimize_instructions_i32_identity_operand(func, dead, lhs_id, rhs_id, 0)
    @lib.Instruction::I32And =>
      optimize_instructions_i32_identity_operand(func, dead, lhs_id, rhs_id, -1)
    @lib.Instruction::I32Mul =>
      optimize_instructions_i32_identity_operand(func, dead, lhs_id, rhs_id, 1)
    @lib.Instruction::I32Sub =>
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(0)) => Some(lhs_id)
        _ => None
      }
    @lib.Instruction::I32DivS | @lib.Instruction::I32DivU =>
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(1)) => Some(lhs_id)
        _ => None
      }
    @lib.Instruction::I32Rotl | @lib.Instruction::I32Rotr =>
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(0)) => Some(lhs_id)
        _ => None
      }
    @lib.Instruction::I64Or
    | @lib.Instruction::I64Xor
    | @lib.Instruction::I64Add
    | @lib.Instruction::I64Shl
    | @lib.Instruction::I64ShrU
    | @lib.Instruction::I64ShrS =>
      optimize_instructions_i64_identity_operand(func, dead, lhs_id, rhs_id, 0L)
    @lib.Instruction::I64And =>
      optimize_instructions_i64_identity_operand(
        func, dead, lhs_id, rhs_id, -1L,
      )
    @lib.Instruction::I64Mul =>
      optimize_instructions_i64_identity_operand(func, dead, lhs_id, rhs_id, 1L)
    @lib.Instruction::I64Sub =>
      match optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(0L)) => Some(lhs_id)
        _ => None
      }
    @lib.Instruction::I64DivS | @lib.Instruction::I64DivU =>
      match optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(1L)) => Some(lhs_id)
        _ => None
      }
    @lib.Instruction::I64Rotl | @lib.Instruction::I64Rotr =>
      match optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(0L)) => Some(lhs_id)
        _ => None
      }
    _ => None
  }
  match keep_id {
    Some(id) => {
      optimize_instructions_replace_with_node_id(ctx, func, node_id, id)
      true
    }
    None => false
  }
}

///|
fn optimize_instructions_try_fold_absorbing_zero_i32(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let zero_on_lhs = match optimize_instructions_i32_const(func, dead, lhs_id) {
    Some(@lib.I32(0)) => true
    _ => false
  }
  let zero_on_rhs = match optimize_instructions_i32_const(func, dead, rhs_id) {
    Some(@lib.I32(0)) => true
    _ => false
  }
  let pure_other = if zero_on_lhs && !zero_on_rhs {
    optimize_instructions_is_side_effect_free_expr(func, dead, rhs_id)
  } else if zero_on_rhs && !zero_on_lhs {
    optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id)
  } else if zero_on_lhs && zero_on_rhs {
    true
  } else {
    false
  }
  if pure_other {
    optimize_instructions_replace_with_const_i32(
      ctx,
      func,
      node_id,
      @lib.I32(0),
    )
    true
  } else {
    false
  }
}

///|
fn optimize_instructions_try_fold_absorbing_zero_i64(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let zero_on_lhs = match optimize_instructions_i64_const(func, dead, lhs_id) {
    Some(@lib.I64(0L)) => true
    _ => false
  }
  let zero_on_rhs = match optimize_instructions_i64_const(func, dead, rhs_id) {
    Some(@lib.I64(0L)) => true
    _ => false
  }
  let pure_other = if zero_on_lhs && !zero_on_rhs {
    optimize_instructions_is_side_effect_free_expr(func, dead, rhs_id)
  } else if zero_on_rhs && !zero_on_lhs {
    optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id)
  } else if zero_on_lhs && zero_on_rhs {
    true
  } else {
    false
  }
  if pure_other {
    optimize_instructions_replace_with_const_i64(
      ctx,
      func,
      node_id,
      @lib.I64(0L),
    )
    true
  } else {
    false
  }
}

///|
fn optimize_instructions_try_fold_absorbing_neg_one_or_i32(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let neg_one_on_lhs = match
    optimize_instructions_i32_const(func, dead, lhs_id) {
    Some(@lib.I32(-1)) => true
    _ => false
  }
  let neg_one_on_rhs = match
    optimize_instructions_i32_const(func, dead, rhs_id) {
    Some(@lib.I32(-1)) => true
    _ => false
  }
  if !neg_one_on_lhs && !neg_one_on_rhs {
    return false
  }
  let effectful_id = if neg_one_on_lhs && !neg_one_on_rhs {
    if optimize_instructions_is_side_effect_free_expr(func, dead, rhs_id) {
      None
    } else {
      Some(rhs_id)
    }
  } else if neg_one_on_rhs && !neg_one_on_lhs {
    if optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) {
      None
    } else {
      Some(lhs_id)
    }
  } else {
    None
  }
  match effectful_id {
    Some(drop_id) =>
      optimize_instructions_replace_with_drop_then_const_i32(
        ctx,
        func,
        node_id,
        drop_id,
        @lib.I32(-1),
      )
    None =>
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        @lib.I32(-1),
      )
  }
  true
}

///|
fn optimize_instructions_try_fold_absorbing_neg_one_or_i64(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let neg_one_on_lhs = match
    optimize_instructions_i64_const(func, dead, lhs_id) {
    Some(@lib.I64(-1L)) => true
    _ => false
  }
  let neg_one_on_rhs = match
    optimize_instructions_i64_const(func, dead, rhs_id) {
    Some(@lib.I64(-1L)) => true
    _ => false
  }
  if !neg_one_on_lhs && !neg_one_on_rhs {
    return false
  }
  let effectful_id = if neg_one_on_lhs && !neg_one_on_rhs {
    if optimize_instructions_is_side_effect_free_expr(func, dead, rhs_id) {
      None
    } else {
      Some(rhs_id)
    }
  } else if neg_one_on_rhs && !neg_one_on_lhs {
    if optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) {
      None
    } else {
      Some(lhs_id)
    }
  } else {
    None
  }
  match effectful_id {
    Some(drop_id) =>
      optimize_instructions_replace_with_drop_then_const_i64(
        ctx,
        func,
        node_id,
        drop_id,
        @lib.I64(-1L),
      )
    None =>
      optimize_instructions_replace_with_const_i64(
        ctx,
        func,
        node_id,
        @lib.I64(-1L),
      )
  }
  true
}

///|
fn optimize_instructions_try_fold_absorbing_binary(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  // A zero-absorbing operand reduces these binops to `0` when the other operand
  // is side-effect-free. Folding would otherwise drop a non-pure lhs/rhs effect
  // (Binaryen keeps e.g. `mul(effect, 0)` and `rem(effect, -1)`).
  match instr {
    @lib.Instruction::I32Mul | @lib.Instruction::I32And =>
      optimize_instructions_try_fold_absorbing_zero_i32(
        ctx, func, dead, node_id, lhs_id, rhs_id,
      )
    @lib.Instruction::I64Mul | @lib.Instruction::I64And =>
      optimize_instructions_try_fold_absorbing_zero_i64(
        ctx, func, dead, node_id, lhs_id, rhs_id,
      )
    @lib.Instruction::I32RemS => {
      let rhs_is_neg_one = match
        optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(-1)) => true
        _ => false
      }
      if rhs_is_neg_one &&
        optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) {
        optimize_instructions_replace_with_const_i32(
          ctx,
          func,
          node_id,
          @lib.I32(0),
        )
        true
      } else {
        false
      }
    }
    @lib.Instruction::I64RemS => {
      let rhs_is_neg_one = match
        optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(-1L)) => true
        _ => false
      }
      if rhs_is_neg_one &&
        optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) {
        optimize_instructions_replace_with_const_i64(
          ctx,
          func,
          node_id,
          @lib.I64(0L),
        )
        true
      } else {
        false
      }
    }
    @lib.Instruction::I32Or =>
      optimize_instructions_try_fold_absorbing_neg_one_or_i32(
        ctx, func, dead, node_id, lhs_id, rhs_id,
      )
    @lib.Instruction::I64Or =>
      optimize_instructions_try_fold_absorbing_neg_one_or_i64(
        ctx, func, dead, node_id, lhs_id, rhs_id,
      )
    _ => false
  }
}

///|
fn optimize_instructions_try_rewrite_float_binary(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match (instr, optimize_instructions_f32_const(func, dead, rhs_id)) {
    (@lib.Instruction::F32Sub, Some(@lib.F32(raw))) => {
      let replacement_rhs = @ir.hot_build_const_f32(func, @lib.F32(-raw))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f32_add(),
        [lhs_id, replacement_rhs],
      )
      return true
    }
    (@lib.Instruction::F32Div, Some(@lib.F32(raw))) if raw == 2.0 => {
      let replacement_rhs = @ir.hot_build_const_f32(func, @lib.F32(0.5))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f32_mul(),
        [lhs_id, replacement_rhs],
      )
      return true
    }
    (@lib.Instruction::F32Mul, Some(@lib.F32(raw))) if raw == -1.0 => {
      let replacement_lhs = @ir.hot_build_const_f32(func, @lib.F32(-0.0))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f32_sub(),
        [replacement_lhs, lhs_id],
      )
      return true
    }
    (@lib.Instruction::F32Div, Some(@lib.F32(raw))) if raw == 1.0 => {
      let replacement_rhs = @ir.hot_build_const_f32(func, @lib.F32(1.0))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f32_mul(),
        [lhs_id, replacement_rhs],
      )
      return true
    }
    (@lib.Instruction::F32Div, Some(@lib.F32(raw))) if raw == -1.0 => {
      let replacement_lhs = @ir.hot_build_const_f32(func, @lib.F32(-0.0))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f32_sub(),
        [replacement_lhs, lhs_id],
      )
      return true
    }
    _ => ()
  }
  match (instr, optimize_instructions_f64_const(func, dead, rhs_id)) {
    (@lib.Instruction::F64Sub, Some(@lib.F64(raw))) => {
      let replacement_rhs = @ir.hot_build_const_f64(func, @lib.F64(-raw))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f64_add(),
        [lhs_id, replacement_rhs],
      )
      return true
    }
    (@lib.Instruction::F64Div, Some(@lib.F64(raw))) if raw == 2.0 => {
      let replacement_rhs = @ir.hot_build_const_f64(func, @lib.F64(0.5))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f64_mul(),
        [lhs_id, replacement_rhs],
      )
      return true
    }
    (@lib.Instruction::F64Mul, Some(@lib.F64(raw))) if raw == -1.0 => {
      let replacement_lhs = @ir.hot_build_const_f64(func, @lib.F64(-0.0))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f64_sub(),
        [replacement_lhs, lhs_id],
      )
      return true
    }
    (@lib.Instruction::F64Div, Some(@lib.F64(raw))) if raw == 1.0 => {
      let replacement_rhs = @ir.hot_build_const_f64(func, @lib.F64(1.0))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f64_mul(),
        [lhs_id, replacement_rhs],
      )
      return true
    }
    (@lib.Instruction::F64Div, Some(@lib.F64(raw))) if raw == -1.0 => {
      let replacement_lhs = @ir.hot_build_const_f64(func, @lib.F64(-0.0))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f64_sub(),
        [replacement_lhs, lhs_id],
      )
      return true
    }
    _ => false
  }
}

///|
fn optimize_instructions_wrap_i64_const_to_i32(value : Int64) -> @lib.I32 {
  let lower64 = value & 4294967295L
  if lower64 >= 2147483648L {
    @lib.I32((lower64 - 4294967296L).to_int())
  } else {
    @lib.I32(lower64.to_int())
  }
}

///|
fn optimize_instructions_try_fold_convert(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  operand_id : Int,
) -> Bool {
  match (instr, optimize_instructions_i64_const(func, dead, operand_id)) {
    (@lib.Instruction::I32WrapI64, Some(@lib.I64(raw))) => {
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        optimize_instructions_wrap_i64_const_to_i32(raw),
      )
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_i32_zero_sub_negated_operand(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Int? {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 2 {
    return None
  }
  match node.op {
    @ir.HotOp::Binary if func.instr_payloads[node.imm0].instr ==
      @lib.Instruction::i32_sub() => {
      let zero_id = func.children[node.child_base]
      let negated_id = func.children[node.child_base + 1]
      if optimize_instructions_i32_const(func, dead, zero_id) ==
        Some(@lib.I32(0)) {
        Some(negated_id)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn optimize_instructions_i64_zero_sub_negated_operand(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Int? {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 2 {
    return None
  }
  match node.op {
    @ir.HotOp::Binary if func.instr_payloads[node.imm0].instr ==
      @lib.Instruction::i64_sub() => {
      let zero_id = func.children[node.child_base]
      let negated_id = func.children[node.child_base + 1]
      if optimize_instructions_i64_const(func, dead, zero_id) ==
        Some(@lib.I64(0L)) {
        Some(negated_id)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
/// Effect bits a value-expression subtree may carry and still be a candidate
/// for operand reordering: pure reads of locals, globals, memory, and tables.
/// Any write, trap, call, throw, or control-flow bit is order-sensitive.
fn optimize_instructions_reorder_read_effects() -> UInt {
  @ir.EFFECT_MASK_LOCAL_STATE |
  @ir.EFFECT_MASK_GLOBAL_STATE |
  @ir.EFFECT_MASK_MEMORY_READ |
  @ir.EFFECT_MASK_TABLE_READ
}

///|
/// `(writes_local, writes_global)` for a value-expression subtree: whether it
/// contains a `local.set`/`local.tee` or a `global.set`. The coarse
/// `EFFECT_MASK_LOCAL_STATE`/`EFFECT_MASK_GLOBAL_STATE` bits conflate reads and
/// writes, so region-conflict detection needs this precise walk. It only recurses
/// value children; callers must reject control-flow operands first (see
/// `optimize_instructions_subtrees_can_swap`), whose region bodies are not
/// reflected in the aggregated node masks.
fn optimize_instructions_subtree_state_writes(
  func : @ir.HotFunc,
  node_id : Int,
) -> (Bool, Bool) {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return (false, false)
  }
  let node = @ir.hot_node_get(func, node_id)
  let mut writes_local = false
  let mut writes_global = false
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => writes_local = true
    @ir.HotOp::GlobalSet => writes_global = true
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let (child_local, child_global) = optimize_instructions_subtree_state_writes(
      func,
      @ir.hot_child_get(func, node_id, slot),
    )
    writes_local = writes_local || child_local
    writes_global = writes_global || child_global
  }
  (writes_local, writes_global)
}

///|
/// Regions a subtree writes, expressed in the read-effect namespace so the
/// result can be intersected with another operand's read mask. Memory and table
/// writes plus opaque `call` effects are precise in the node mask; local and
/// global writes use the precise `optimize_instructions_subtree_state_writes`
/// walk. A `call` may write memory, globals, and tables but never the caller's
/// locals.
fn optimize_instructions_subtree_write_mask(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  node_id : Int,
) -> UInt {
  let mask = node_masks[node_id]
  let mut writes = 0U
  if (mask & (@ir.EFFECT_MASK_MEMORY_WRITE | @ir.EFFECT_MASK_CALL)) != 0U {
    writes = writes | @ir.EFFECT_MASK_MEMORY_READ
  }
  if (mask & (@ir.EFFECT_MASK_TABLE_WRITE | @ir.EFFECT_MASK_CALL)) != 0U {
    writes = writes | @ir.EFFECT_MASK_TABLE_READ
  }
  if (mask & @ir.EFFECT_MASK_CALL) != 0U {
    writes = writes | @ir.EFFECT_MASK_GLOBAL_STATE
  }
  let (writes_local, writes_global) = optimize_instructions_subtree_state_writes(
    func, node_id,
  )
  if writes_local {
    writes = writes | @ir.EFFECT_MASK_LOCAL_STATE
  }
  if writes_global {
    writes = writes | @ir.EFFECT_MASK_GLOBAL_STATE
  }
  writes
}

///|
/// Whether two operand subtrees may be swapped (as in the leading
/// `(0 - x) + y => y - x` rewrite, which reorders `x` and `y`) without changing
/// observable behavior. Mirrors Binaryen's `optimize-instructions` reorder rule:
///
/// - there is no read-after-write / write-after-read / write-after-write
///   conflict on locals, globals, memory, or tables (read x read is fine, which
///   is why `local.get x local.get`, `load x load`, and a `local.get` across a
///   `call` all reorder);
/// - there is no may-trap-or-throw vs side-effect hazard (reordering a trapping
///   op past a side effect would change whether the effect is observed), which
///   is why `(0 - load) + local.tee` and `(0 - memory.grow) + load` stay put;
/// - operands carrying control flow never swap, because their region bodies are
///   not reflected in the aggregated node masks.
fn optimize_instructions_subtrees_can_swap(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  a_id : Int,
  b_id : Int,
) -> Bool {
  if a_id < 0 ||
    a_id >= node_masks.length() ||
    b_id < 0 ||
    b_id >= node_masks.length() {
    return false
  }
  let a_mask = node_masks[a_id]
  let b_mask = node_masks[b_id]
  // Control-flow operands carry effects inside regions that the aggregated
  // node masks do not reflect; never reorder across them.
  if (a_mask & @ir.EFFECT_MASK_CONTROL) != 0U ||
    (b_mask & @ir.EFFECT_MASK_CONTROL) != 0U {
    return false
  }
  let read_bits = optimize_instructions_reorder_read_effects()
  let a_reads = a_mask & read_bits
  let b_reads = b_mask & read_bits
  let a_writes = optimize_instructions_subtree_write_mask(
    func, node_masks, a_id,
  )
  let b_writes = optimize_instructions_subtree_write_mask(
    func, node_masks, b_id,
  )
  // RAW / WAR / WAW on any shared region.
  let region_conflict = ((a_reads | a_writes) & b_writes) != 0U ||
    ((b_reads | b_writes) & a_writes) != 0U
  if region_conflict {
    return false
  }
  // A may-trap-or-throw operand reordered past a side effect would change
  // whether that effect is observed before the trap/throw.
  let a_disrupts = (a_mask & (@ir.EFFECT_MASK_TRAP | @ir.EFFECT_MASK_THROW)) !=
    0U
  let b_disrupts = (b_mask & (@ir.EFFECT_MASK_TRAP | @ir.EFFECT_MASK_THROW)) !=
    0U
  let a_side_effect = a_writes != 0U || (a_mask & @ir.EFFECT_MASK_THROW) != 0U
  let b_side_effect = b_writes != 0U || (b_mask & @ir.EFFECT_MASK_THROW) != 0U
  if (a_disrupts && b_side_effect) || (b_disrupts && a_side_effect) {
    return false
  }
  true
}

///|
fn optimize_instructions_can_swap_leading_operands(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  a_id : Int,
  b_id : Int,
) -> Bool {
  let effects = pass_require_effects(ctx, func)
  optimize_instructions_subtrees_can_swap(func, effects.node_masks, a_id, b_id)
}

///|
fn optimize_instructions_try_rewrite_add_sub(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match instr {
    @lib.Instruction::I32Add => {
      let rhs = @ir.hot_node_get(func, rhs_id)
      if rhs.child_count == 2 {
        match rhs.op {
          @ir.HotOp::Binary if func.instr_payloads[rhs.imm0].instr ==
            @lib.Instruction::i32_sub() => {
            let zero_id = func.children[rhs.child_base]
            let sub_rhs_id = func.children[rhs.child_base + 1]
            if optimize_instructions_i32_const(func, dead, zero_id) ==
              Some(@lib.I32(0)) {
              optimize_instructions_rewrite_exact_with_children(
                ctx,
                func,
                node_id,
                @lib.Instruction::i32_sub(),
                [lhs_id, sub_rhs_id],
              )
              return true
            }
          }
          _ => ()
        }
      }
      let lhs = @ir.hot_node_get(func, lhs_id)
      if lhs.child_count == 2 {
        match lhs.op {
          @ir.HotOp::Binary if func.instr_payloads[lhs.imm0].instr ==
            @lib.Instruction::i32_sub() => {
            let zero_id = func.children[lhs.child_base]
            let sub_rhs_id = func.children[lhs.child_base + 1]
            if optimize_instructions_i32_const(func, dead, zero_id) ==
              Some(@lib.I32(0)) &&
              optimize_instructions_can_swap_leading_operands(
                ctx, func, rhs_id, sub_rhs_id,
              ) {
              optimize_instructions_rewrite_exact_with_children(
                ctx,
                func,
                node_id,
                @lib.Instruction::i32_sub(),
                [rhs_id, sub_rhs_id],
              )
              return true
            }
          }
          _ => ()
        }
      }
    }
    @lib.Instruction::I64Add => {
      let rhs = @ir.hot_node_get(func, rhs_id)
      if rhs.child_count == 2 {
        match rhs.op {
          @ir.HotOp::Binary if func.instr_payloads[rhs.imm0].instr ==
            @lib.Instruction::i64_sub() => {
            let zero_id = func.children[rhs.child_base]
            let sub_rhs_id = func.children[rhs.child_base + 1]
            if optimize_instructions_i64_const(func, dead, zero_id) ==
              Some(@lib.I64(0L)) {
              optimize_instructions_rewrite_exact_with_children(
                ctx,
                func,
                node_id,
                @lib.Instruction::i64_sub(),
                [lhs_id, sub_rhs_id],
              )
              return true
            }
          }
          _ => ()
        }
      }
      let lhs = @ir.hot_node_get(func, lhs_id)
      if lhs.child_count == 2 {
        match lhs.op {
          @ir.HotOp::Binary if func.instr_payloads[lhs.imm0].instr ==
            @lib.Instruction::i64_sub() => {
            let zero_id = func.children[lhs.child_base]
            let sub_rhs_id = func.children[lhs.child_base + 1]
            if optimize_instructions_i64_const(func, dead, zero_id) ==
              Some(@lib.I64(0L)) &&
              optimize_instructions_can_swap_leading_operands(
                ctx, func, rhs_id, sub_rhs_id,
              ) {
              optimize_instructions_rewrite_exact_with_children(
                ctx,
                func,
                node_id,
                @lib.Instruction::i64_sub(),
                [rhs_id, sub_rhs_id],
              )
              return true
            }
          }
          _ => ()
        }
      }
    }
    _ => ()
  }
  match (instr, optimize_instructions_i32_const(func, dead, rhs_id)) {
    (@lib.Instruction::I32Add, Some(@lib.I32(0)))
    | (@lib.Instruction::I32Sub, Some(@lib.I32(0))) => {
      optimize_instructions_replace_with_existing_node(ctx, func, node_id)
      return true
    }
    (@lib.Instruction::I32Add, Some(@lib.I32(raw))) if raw < 0 &&
      !optimize_instructions_prefer_negative_leb_i32(-raw) => {
      let replacement_rhs = @ir.hot_build_const_i32(func, @lib.I32(-raw))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_sub(),
        [lhs_id, replacement_rhs],
      )
      return true
    }
    _ => ()
  }
  match (instr, optimize_instructions_i64_const(func, dead, rhs_id)) {
    (@lib.Instruction::I64Add, Some(@lib.I64(0L)))
    | (@lib.Instruction::I64Sub, Some(@lib.I64(0L))) => {
      optimize_instructions_replace_with_existing_node(ctx, func, node_id)
      true
    }
    (@lib.Instruction::I64Add, Some(@lib.I64(raw))) if raw < 0L &&
      !optimize_instructions_prefer_negative_leb_i64(-raw) => {
      let replacement_rhs = @ir.hot_build_const_i64(func, @lib.I64(-raw))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i64_sub(),
        [lhs_id, replacement_rhs],
      )
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_try_rewrite_mul_negation(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match instr {
    @lib.Instruction::I32Mul =>
      match
        (
          optimize_instructions_i32_zero_sub_negated_operand(func, dead, lhs_id),
          optimize_instructions_i32_zero_sub_negated_operand(func, dead, rhs_id),
        ) {
        (Some(lhs_negated), Some(rhs_negated)) => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_mul(),
            [lhs_negated, rhs_negated],
          )
          true
        }
        _ => false
      }
    @lib.Instruction::I64Mul =>
      match
        (
          optimize_instructions_i64_zero_sub_negated_operand(func, dead, lhs_id),
          optimize_instructions_i64_zero_sub_negated_operand(func, dead, rhs_id),
        ) {
        (Some(lhs_negated), Some(rhs_negated)) => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_mul(),
            [lhs_negated, rhs_negated],
          )
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_try_rewrite_mul_shift(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match (instr, optimize_instructions_i32_const(func, dead, rhs_id)) {
    (@lib.Instruction::I32Mul, Some(@lib.I32(raw))) =>
      match optimize_instructions_i32_power_of_two_shift(raw) {
        Some(shift) => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_shl(),
            [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(shift))],
          )
          true
        }
        None => false
      }
    _ =>
      match (instr, optimize_instructions_i64_const(func, dead, rhs_id)) {
        (@lib.Instruction::I64Mul, Some(@lib.I64(raw))) =>
          match optimize_instructions_i64_power_of_two_shift(raw) {
            Some(shift) => {
              optimize_instructions_rewrite_exact_with_children(
                ctx,
                func,
                node_id,
                @lib.Instruction::i64_shl(),
                [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(shift))],
              )
              true
            }
            None => false
          }
        _ => false
      }
  }
}

///|
fn optimize_instructions_try_rewrite_div_rem_power_of_two(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match (instr, optimize_instructions_i32_const(func, dead, rhs_id)) {
    (@lib.Instruction::I32DivU, Some(@lib.I32(raw))) =>
      match optimize_instructions_i32_power_of_two_shift(raw) {
        Some(shift) => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_shr_u(),
            [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(shift))],
          )
          true
        }
        None => false
      }
    (@lib.Instruction::I32RemU, Some(@lib.I32(raw))) =>
      match optimize_instructions_i32_power_of_two_shift(raw) {
        Some(_) => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_and(),
            [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(raw - 1))],
          )
          true
        }
        None => false
      }
    _ =>
      match (instr, optimize_instructions_i64_const(func, dead, rhs_id)) {
        (@lib.Instruction::I64DivU, Some(@lib.I64(raw))) =>
          match optimize_instructions_i64_power_of_two_shift(raw) {
            Some(shift) => {
              optimize_instructions_rewrite_exact_with_children(
                ctx,
                func,
                node_id,
                @lib.Instruction::i64_shr_u(),
                [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(shift))],
              )
              true
            }
            None => false
          }
        (@lib.Instruction::I64RemU, Some(@lib.I64(raw))) =>
          match optimize_instructions_i64_power_of_two_shift(raw) {
            Some(_) => {
              optimize_instructions_rewrite_exact_with_children(
                ctx,
                func,
                node_id,
                @lib.Instruction::i64_and(),
                [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(raw - 1L))],
              )
              true
            }
            None => false
          }
        _ => false
      }
  }
}

///|
fn optimize_instructions_required_sign_ext_bits(
  instr : @lib.Instruction,
) -> Int {
  match instr {
    @lib.Instruction::I32Extend8S | @lib.Instruction::I64Extend8S => 8
    @lib.Instruction::I32Extend16S | @lib.Instruction::I64Extend16S => 16
    @lib.Instruction::I64Extend32S => 32
    _ => 0
  }
}

///|
fn optimize_instructions_try_remove_redundant_sign_ext(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  instr : @lib.Instruction,
  operand_id : Int,
) -> Bool {
  let needed_bits = optimize_instructions_required_sign_ext_bits(instr)
  if needed_bits == 0 {
    return false
  }
  let known_bits = optimize_instructions_sign_ext_bits_for_value(
    func, dead, scratch, operand_id,
  )
  if known_bits != 0 && known_bits <= needed_bits {
    optimize_instructions_replace_with_existing_node(ctx, func, node_id)
    true
  } else {
    false
  }
}

///|
fn optimize_instructions_try_rewrite_sign_ext_idiom(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let (left_shift_instr, rewrite_instr, shift_amount) = match instr {
    @lib.Instruction::I32ShrS =>
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(24)) =>
          (@lib.Instruction::i32_shl(), @lib.Instruction::i32_extend8s(), 24)
        Some(@lib.I32(16)) =>
          (@lib.Instruction::i32_shl(), @lib.Instruction::i32_extend16s(), 16)
        _ => return false
      }
    @lib.Instruction::I64ShrS =>
      match optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(56L)) =>
          (@lib.Instruction::i64_shl(), @lib.Instruction::i64_extend8s(), 56)
        Some(@lib.I64(48L)) =>
          (@lib.Instruction::i64_shl(), @lib.Instruction::i64_extend16s(), 48)
        Some(@lib.I64(32L)) =>
          (@lib.Instruction::i64_shl(), @lib.Instruction::i64_extend32s(), 32)
        _ => return false
      }
    _ => return false
  }
  if !optimize_instructions_node_is_live(func, dead, lhs_id) {
    return false
  }
  let lhs = @ir.hot_node_get(func, lhs_id)
  match lhs.op {
    @ir.HotOp::Binary => ()
    _ => return false
  }
  if lhs.child_count != 2 {
    return false
  }
  if @ir.hot_node_exact_instr(func, lhs_id) != Some(left_shift_instr) {
    return false
  }
  let lhs_rhs = func.children[lhs.child_base + 1]
  let same_amount = match shift_amount {
    16 | 24 =>
      match optimize_instructions_i32_const(func, dead, lhs_rhs) {
        Some(@lib.I32(raw)) => raw == shift_amount
        _ => false
      }
    _ =>
      match optimize_instructions_i64_const(func, dead, lhs_rhs) {
        Some(@lib.I64(raw)) => raw == shift_amount.to_int64()
        _ => false
      }
  }
  if !same_amount {
    return false
  }
  optimize_instructions_replace_with_exact_unary(
    ctx,
    func,
    node_id,
    rewrite_instr,
    func.children[lhs.child_base],
  )
  true
}

///|
fn optimize_instructions_try_rewrite_shift(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let mask_bits = match optimize_instructions_shift_mask_bits(instr) {
    Some(bits) => bits
    None => return false
  }

  match optimize_instructions_i32_const(func, dead, rhs_id) {
    Some(@lib.I32(raw)) => {
      let masked = raw & mask_bits
      if masked == raw {
        return false
      }
      if masked == 0 {
        optimize_instructions_replace_with_existing_node(ctx, func, node_id)
        return true
      }
      let replacement_rhs = @ir.hot_build_const_i32(func, @lib.I32(masked))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        instr,
        [lhs_id, replacement_rhs],
      )
      return true
    }
    None => ()
  }

  match optimize_instructions_i64_const(func, dead, rhs_id) {
    Some(@lib.I64(raw)) => {
      let mask64 = mask_bits.to_int64()
      let masked = raw & mask64
      if masked == raw {
        return false
      }
      if masked == 0 {
        optimize_instructions_replace_with_existing_node(ctx, func, node_id)
        return true
      }
      let replacement_rhs = @ir.hot_build_const_i64(func, @lib.I64(masked))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        instr,
        [lhs_id, replacement_rhs],
      )
      return true
    }
    None => ()
  }

  if !optimize_instructions_node_is_live(func, dead, rhs_id) {
    return false
  }
  let rhs = if rhs_id < func.nodes.length() {
    func.nodes[rhs_id]
  } else {
    @ir.hot_node_get(func, rhs_id)
  }
  let mask_operand_id = match rhs.op {
    @ir.HotOp::Binary =>
      match @ir.hot_node_exact_instr(func, rhs_id) {
        Some(@lib.Instruction::I32And) =>
          match
            optimize_instructions_i32_const(
              func,
              dead,
              func.children[rhs.child_base + 1],
            ) {
            Some(@lib.I32(raw)) if (raw & mask_bits) == mask_bits =>
              Some(func.children[rhs.child_base])
            _ => None
          }
        Some(@lib.Instruction::I64And) =>
          match
            optimize_instructions_i64_const(
              func,
              dead,
              func.children[rhs.child_base + 1],
            ) {
            Some(@lib.I64(raw)) if (raw & mask_bits.to_int64()) ==
              mask_bits.to_int64() => Some(func.children[rhs.child_base])
            _ => None
          }
        _ => None
      }
    _ => None
  }
  match mask_operand_id {
    Some(masked_operand_id) => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        instr,
        [lhs_id, masked_operand_id],
      )
      true
    }
    None => false
  }
}

///|
fn optimize_instructions_try_combine_nested_const_shift(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let mask_bits = match optimize_instructions_shift_mask_bits(instr) {
    Some(bits) => bits
    None => return false
  }
  if !optimize_instructions_node_is_live(func, dead, lhs_id) {
    return false
  }
  let inner = @ir.hot_node_get(func, lhs_id)
  match inner.op {
    @ir.HotOp::Binary => ()
    _ => return false
  }
  if inner.child_count != 2 {
    return false
  }
  if @ir.hot_node_exact_instr(func, lhs_id) != Some(instr) {
    return false
  }
  let inner_lhs = func.children[inner.child_base]
  let inner_rhs = func.children[inner.child_base + 1]
  match instr {
    @lib.Instruction::I32Shl
    | @lib.Instruction::I32ShrS
    | @lib.Instruction::I32ShrU
    | @lib.Instruction::I32Rotl
    | @lib.Instruction::I32Rotr => {
      let outer_amount = match
        optimize_instructions_shift_rhs_i32_amount(
          func, dead, rhs_id, mask_bits,
        ) {
        Some(amount) => amount
        None => return false
      }
      let inner_amount = match
        optimize_instructions_shift_rhs_i32_amount(
          func, dead, inner_rhs, mask_bits,
        ) {
        Some(amount) => amount
        None => return false
      }
      let combined = (outer_amount + inner_amount) & mask_bits
      let replacement_rhs = @ir.hot_build_const_i32(func, @lib.I32(combined))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        instr,
        [inner_lhs, replacement_rhs],
      )
      true
    }
    @lib.Instruction::I64Shl
    | @lib.Instruction::I64ShrS
    | @lib.Instruction::I64ShrU
    | @lib.Instruction::I64Rotl
    | @lib.Instruction::I64Rotr => {
      let outer_amount = match
        optimize_instructions_shift_rhs_i64_amount(
          func, dead, rhs_id, mask_bits,
        ) {
        Some(amount) => amount
        None => return false
      }
      let inner_amount = match
        optimize_instructions_shift_rhs_i64_amount(
          func, dead, inner_rhs, mask_bits,
        ) {
        Some(amount) => amount
        None => return false
      }
      let combined = (outer_amount + inner_amount) & mask_bits
      let replacement_rhs = @ir.hot_build_const_i64(
        func,
        @lib.I64(combined.to_int64()),
      )
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        instr,
        [inner_lhs, replacement_rhs],
      )
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_try_fold_compare_zero(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  if !optimize_instructions_is_trivially_pure_value(func, dead, lhs_id) {
    return false
  }
  match instr {
    @lib.Instruction::I32GeU =>
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(raw)) if raw == 0 => {
          optimize_instructions_replace_with_const_i32(
            ctx,
            func,
            node_id,
            @lib.I32(1),
          )
          true
        }
        _ => false
      }
    @lib.Instruction::I32LtU =>
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(raw)) if raw == 0 => {
          optimize_instructions_replace_with_const_i32(
            ctx,
            func,
            node_id,
            @lib.I32(0),
          )
          true
        }
        _ => false
      }
    @lib.Instruction::I64GeU =>
      match optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(raw)) if raw == 0L => {
          optimize_instructions_replace_with_const_i32(
            ctx,
            func,
            node_id,
            @lib.I32(1),
          )
          true
        }
        _ => false
      }
    @lib.Instruction::I64LtU =>
      match optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(raw)) if raw == 0L => {
          optimize_instructions_replace_with_const_i32(
            ctx,
            func,
            node_id,
            @lib.I32(0),
          )
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_is_remainder_instr(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let exact_id = match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::LocalTee if @ir.hot_child_count(func, node_id) == 1 =>
      @ir.hot_child_get(func, node_id, 0)
    _ => node_id
  }
  match @ir.hot_node_exact_instr(func, exact_id) {
    Some(
      @lib.Instruction::I32RemS
      | @lib.Instruction::I32RemU
      | @lib.Instruction::I64RemS
      | @lib.Instruction::I64RemU
    ) => true
    _ => false
  }
}

///|
fn optimize_instructions_should_keep_i64_eq_zero_if_condition(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match instr {
    @lib.Instruction::I64Eq => ()
    _ => return false
  }
  optimize_instructions_mark_if_condition_nodes(func, dead, scratch)
  if node_id < 0 ||
    node_id >= scratch.if_condition_nodes.length() ||
    !scratch.if_condition_nodes[node_id] {
    return false
  }
  optimize_instructions_i64_const(func, dead, lhs_id) == Some(@lib.I64(0L)) ||
  optimize_instructions_i64_const(func, dead, rhs_id) == Some(@lib.I64(0L))
}

///|
fn optimize_instructions_replace_with_ref_is_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  operand_id : Int,
) -> Unit {
  optimize_instructions_replace_with_exact_unary(
    ctx,
    func,
    node_id,
    @lib.Instruction::ref_is_null(),
    operand_id,
  )
}

///|
fn optimize_instructions_replace_with_ref_is_non_null_test(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  operand_id : Int,
) -> Unit {
  let is_null = @ir.hot_build_unary(func, @lib.ValType::i32(), operand_id)
  @ir.hot_node_exact_instr_set(func, is_null, @lib.Instruction::ref_is_null())
  let non_null = @ir.hot_build_unary(func, @lib.ValType::i32(), is_null)
  @ir.hot_node_exact_instr_set(func, non_null, @lib.Instruction::i32_eqz())
  let replacement = @ir.hot_node_get(func, non_null)
  @ir.hot_replace_node(func, node_id, replacement)
  @ir.hot_delete_node(func, non_null)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_ref_is_known_non_null(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) =>
          ref_type.is_non_nullable()
        _ => false
      }
    @ir.HotOp::RefFunc => true
    @ir.HotOp::Heap =>
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::RefI31) => true
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_ref_is_null_operand(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::RefNull => true
    _ =>
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::RefNull(_)) => true
        _ => false
      }
  }
}

///|
fn optimize_instructions_ref_i31_matches_target(ht : @lib.HeapType) -> Bool {
  match ht {
    @lib.HeapType::AbsHeapTypeHeapType(abs) =>
      abs == @lib.AbsHeapType::i31() ||
      abs == @lib.AbsHeapType::eq() ||
      abs == @lib.AbsHeapType::any()
    _ => false
  }
}

///|
fn optimize_instructions_abs_struct_array_matches_target(
  source : @lib.HeapType,
  target : @lib.HeapType,
) -> Bool {
  match (source, target) {
    (
      @lib.HeapType::AbsHeapTypeHeapType(source_abs),
      @lib.HeapType::AbsHeapTypeHeapType(target_abs),
    ) =>
      (
        source_abs == @lib.AbsHeapType::struct_() ||
        source_abs == @lib.AbsHeapType::array()
      ) &&
      (
        target_abs == @lib.AbsHeapType::eq() ||
        target_abs == @lib.AbsHeapType::any()
      )
    _ => false
  }
}

///|
fn optimize_instructions_ref_func_matches_target(ht : @lib.HeapType) -> Bool {
  match ht {
    @lib.HeapType::AbsHeapTypeHeapType(abs) => abs == @lib.AbsHeapType::func()
    _ => false
  }
}

///|
fn optimize_instructions_ref_i31_cannot_match_target(
  ht : @lib.HeapType,
) -> Bool {
  match ht {
    @lib.HeapType::AbsHeapTypeHeapType(abs) =>
      abs == @lib.AbsHeapType::struct_() || abs == @lib.AbsHeapType::array()
    @lib.HeapType::HeapType(_) | @lib.HeapType::DefTypeHeapType(_) => true
  }
}

///|
fn optimize_instructions_ref_is_known_non_null_i31(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) =>
          ref_type.is_non_nullable() &&
          ref_type.get_heap_type() ==
          @lib.HeapType::abs(@lib.AbsHeapType::i31())
        _ => false
      }
    @ir.HotOp::Heap =>
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::RefI31) => true
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_ref_cannot_be_i31(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) =>
          optimize_instructions_ref_i31_cannot_match_target(
            ref_type.get_heap_type(),
          )
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_abs_struct_array_disjoint(
  lhs : @lib.HeapType,
  rhs : @lib.HeapType,
) -> Bool {
  match (lhs, rhs) {
    (
      @lib.HeapType::AbsHeapTypeHeapType(lhs_abs),
      @lib.HeapType::AbsHeapTypeHeapType(rhs_abs),
    ) =>
      (
        lhs_abs == @lib.AbsHeapType::struct_() &&
        rhs_abs == @lib.AbsHeapType::array()
      ) ||
      (
        lhs_abs == @lib.AbsHeapType::array() &&
        rhs_abs == @lib.AbsHeapType::struct_()
      )
    _ => false
  }
}

///|
fn optimize_instructions_ref_local_heap_type(
  func : @ir.HotFunc,
  node_id : Int,
) -> @lib.RefType? {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) => Some(ref_type)
        _ => None
      }
    _ => None
  }
}

///|
fn optimize_instructions_ref_local_heaps_are_impossible_equal(
  func : @ir.HotFunc,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match
    (
      optimize_instructions_ref_local_heap_type(func, lhs_id),
      optimize_instructions_ref_local_heap_type(func, rhs_id),
    ) {
    (Some(lhs), Some(rhs)) =>
      (lhs.is_non_nullable() || rhs.is_non_nullable()) &&
      optimize_instructions_abs_struct_array_disjoint(
        lhs.get_heap_type(),
        rhs.get_heap_type(),
      )
    _ => false
  }
}

///|
fn optimize_instructions_ref_is_null_or_known_miss_for_non_null_target(
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) =>
          (
            ref_type.get_heap_type() ==
            @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
            optimize_instructions_ref_i31_cannot_match_target(target)
          ) ||
          optimize_instructions_abs_struct_array_disjoint(
            ref_type.get_heap_type(),
            target,
          )
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_ref_is_known_miss_for_target(
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) =>
          ref_type.is_non_nullable() &&
          (
            (
              ref_type.get_heap_type() ==
              @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
              optimize_instructions_ref_i31_cannot_match_target(target)
            ) ||
            optimize_instructions_abs_struct_array_disjoint(
              ref_type.get_heap_type(),
              target,
            )
          )
        _ => false
      }
    @ir.HotOp::Heap =>
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::RefI31) =>
          optimize_instructions_ref_i31_cannot_match_target(target)
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_ref_is_known_match_for_target(
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) =>
          ref_type.is_non_nullable() &&
          (
            ref_type.get_heap_type() == target ||
            (
              ref_type.get_heap_type() ==
              @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
              optimize_instructions_ref_i31_matches_target(target)
            ) ||
            optimize_instructions_abs_struct_array_matches_target(
              ref_type.get_heap_type(),
              target,
            )
          )
        _ => false
      }
    @ir.HotOp::RefFunc => optimize_instructions_ref_func_matches_target(target)
    @ir.HotOp::Heap =>
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::RefI31) =>
          optimize_instructions_ref_i31_matches_target(target)
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_ref_is_known_match_for_nullable_target(
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) =>
          ref_type.is_nullable() &&
          (
            ref_type.get_heap_type() == target ||
            (
              ref_type.get_heap_type() ==
              @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
              optimize_instructions_ref_i31_matches_target(target)
            ) ||
            optimize_instructions_abs_struct_array_matches_target(
              ref_type.get_heap_type(),
              target,
            )
          )
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_ref_operand_is_nullable_exact_heap(
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
) -> Bool {
  match @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [@lib.ValType::RefTypeValType(ref_type)] =>
      ref_type.is_nullable() && ref_type.get_heap_type() == target
    _ => false
  }
}

///|
fn optimize_instructions_ref_operand_is_nullable_match_for_target(
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
) -> Bool {
  match @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [@lib.ValType::RefTypeValType(ref_type)] =>
      ref_type.is_nullable() &&
      (
        ref_type.get_heap_type() == target ||
        (
          ref_type.get_heap_type() ==
          @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
          optimize_instructions_ref_i31_matches_target(target)
        ) ||
        optimize_instructions_abs_struct_array_matches_target(
          ref_type.get_heap_type(),
          target,
        )
      )
    _ => false
  }
}

///|
fn optimize_instructions_ref_operand_has_exact_heap(
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
) -> Bool {
  match @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [@lib.ValType::RefTypeValType(ref_type)] =>
      ref_type.is_exact() && ref_type.get_heap_type() == target
    _ => false
  }
}

///|
fn optimize_instructions_replace_ref_cast_with_ref_as_non_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  operand_id : Int,
) -> Bool {
  let result_types = @ir.hot_type_results(
    func,
    @ir.hot_node_type(func, node_id),
  )
  let temp = @ir.hot_build_heap(
    func,
    result_types,
    @lib.Instruction::ref_as_non_null(),
    [operand_id],
  )
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  @ir.hot_delete_node(func, temp)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_try_fold_ref_is_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let operand_id = @ir.hot_child_get(func, node_id, 0)
  match @ir.hot_node_get(func, operand_id).op {
    @ir.HotOp::RefNull => {
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        @lib.I32(1),
      )
      true
    }
    _ if optimize_instructions_ref_is_known_non_null(func, operand_id) => {
      if optimize_instructions_node_effects_are_pure(ctx, func, operand_id) {
        optimize_instructions_replace_with_const_i32(
          ctx,
          func,
          node_id,
          @lib.I32(0),
        )
      } else {
        optimize_instructions_replace_with_drop_then_const_i32(
          ctx,
          func,
          node_id,
          operand_id,
          @lib.I32(0),
        )
      }
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_try_fold_ref_test_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let (nullable, target) = match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefTest(nullable, target)) => (nullable, target)
    _ => return false
  }
  let operand_id = @ir.hot_child_get(func, node_id, 0)
  match @ir.hot_node_get(func, operand_id).op {
    @ir.HotOp::RefNull => {
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if nullable {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      true
    }
    _ if not(nullable) &&
      optimize_instructions_ref_operand_is_nullable_match_for_target(
        func, operand_id, target,
      ) => {
      optimize_instructions_replace_with_ref_is_non_null_test(
        ctx, func, node_id, operand_id,
      )
      true
    }
    _ if optimize_instructions_ref_is_known_match_for_target(
        func, operand_id, target,
      ) ||
      (
        nullable &&
        optimize_instructions_ref_is_known_match_for_nullable_target(
          func, operand_id, target,
        )
      ) => {
      if optimize_instructions_node_effects_are_pure(ctx, func, operand_id) {
        optimize_instructions_replace_with_const_i32(
          ctx,
          func,
          node_id,
          @lib.I32(1),
        )
      } else {
        optimize_instructions_replace_with_drop_then_const_i32(
          ctx,
          func,
          node_id,
          operand_id,
          @lib.I32(1),
        )
      }
      true
    }
    _ if optimize_instructions_ref_is_known_miss_for_target(
        func, operand_id, target,
      ) ||
      (
        not(nullable) &&
        optimize_instructions_ref_is_null_or_known_miss_for_non_null_target(
          func, operand_id, target,
        )
      ) => {
      if optimize_instructions_node_effects_are_pure(ctx, func, operand_id) {
        optimize_instructions_replace_with_const_i32(
          ctx,
          func,
          node_id,
          @lib.I32(0),
        )
      } else {
        optimize_instructions_replace_with_drop_then_const_i32(
          ctx,
          func,
          node_id,
          operand_id,
          @lib.I32(0),
        )
      }
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_try_fold_ref_cast_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let (nullable, exact, target) = match
    @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefCast(nullable, exact, target)) =>
      (nullable, exact, target)
    _ => return false
  }
  let operand_id = @ir.hot_child_get(func, node_id, 0)
  match @ir.hot_node_get(func, operand_id).op {
    @ir.HotOp::RefNull => {
      if nullable {
        optimize_instructions_replace_with_node_id(
          ctx, func, node_id, operand_id,
        )
      } else {
        optimize_instructions_replace_with_unreachable(ctx, func, node_id)
      }
      true
    }
    _ if not(nullable) &&
      (
        not(exact) ||
        optimize_instructions_ref_operand_has_exact_heap(
          func, operand_id, target,
        )
      ) &&
      optimize_instructions_ref_operand_is_nullable_exact_heap(
        func, operand_id, target,
      ) =>
      optimize_instructions_replace_ref_cast_with_ref_as_non_null(
        ctx, func, node_id, operand_id,
      )
    _ if (
        not(exact) ||
        optimize_instructions_ref_operand_has_exact_heap(
          func, operand_id, target,
        )
      ) &&
      (
        optimize_instructions_ref_is_known_match_for_target(
          func, operand_id, target,
        ) ||
        (
          nullable &&
          optimize_instructions_ref_is_known_match_for_nullable_target(
            func, operand_id, target,
          )
        )
      ) => {
      optimize_instructions_replace_with_node_id(ctx, func, node_id, operand_id)
      true
    }
    _ if optimize_instructions_ref_is_known_miss_for_target(
        func, operand_id, target,
      ) ||
      (
        not(nullable) &&
        optimize_instructions_ref_is_null_or_known_miss_for_non_null_target(
          func, operand_id, target,
        )
      ) =>
      if optimize_instructions_node_effects_are_pure(ctx, func, operand_id) {
        optimize_instructions_replace_with_unreachable(ctx, func, node_id)
        true
      } else {
        optimize_instructions_replace_with_drop_then_unreachable(
          ctx, func, node_id, operand_id,
        )
      }
    _ => false
  }
}

///|
fn optimize_instructions_try_replace_ref_cast_unreachable_operand(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let operand_id = @ir.hot_child_get(func, node_id, 0)
  match @ir.hot_node_get(func, operand_id).op {
    @ir.HotOp::Unreachable => {
      optimize_instructions_replace_with_unreachable(ctx, func, node_id)
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_try_fold_ref_as_non_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefAsNonNull) => ()
    _ => return false
  }
  let operand_id = @ir.hot_child_get(func, node_id, 0)
  match @ir.hot_node_get(func, operand_id).op {
    @ir.HotOp::RefNull => {
      optimize_instructions_replace_with_unreachable(ctx, func, node_id)
      true
    }
    _ if optimize_instructions_ref_is_known_non_null(func, operand_id) => {
      optimize_instructions_replace_with_node_id(ctx, func, node_id, operand_id)
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_ref_eq_same_local_operand(
  func : @ir.HotFunc,
  node_id : Int,
) -> Int? {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::LocalGet => Some(@ir.hot_node_get(func, node_id).imm0)
    @ir.HotOp::RefCast => {
      if @ir.hot_child_count(func, node_id) != 1 {
        return None
      }
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::RefCast(true, _, target)) => {
          let child_id = @ir.hot_child_get(func, node_id, 0)
          match @ir.hot_node_get(func, child_id).op {
            @ir.HotOp::LocalGet => {
              let local_idx = @ir.hot_node_get(func, child_id).imm0
              match @ir.hot_local_type(func, local_idx) {
                Some(@lib.ValType::RefTypeValType(ref_type)) =>
                  if ref_type.get_heap_type() == target ||
                    (
                      ref_type.get_heap_type() ==
                      @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
                      optimize_instructions_ref_i31_matches_target(target)
                    ) ||
                    optimize_instructions_abs_struct_array_matches_target(
                      ref_type.get_heap_type(),
                      target,
                    ) {
                    Some(local_idx)
                  } else {
                    None
                  }
                _ => None
              }
            }
            _ => None
          }
        }
        _ => None
      }
    }
    _ => None
  }
}

///|
fn optimize_instructions_ref_eq_operands_are_same_local(
  func : @ir.HotFunc,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match
    (
      optimize_instructions_ref_eq_same_local_operand(func, lhs_id),
      optimize_instructions_ref_eq_same_local_operand(func, rhs_id),
    ) {
    (Some(lhs), Some(rhs)) => lhs == rhs
    _ => false
  }
}

///|
fn optimize_instructions_ref_eq_same_local_as_non_null_operand(
  func : @ir.HotFunc,
  node_id : Int,
) -> (Int, Int)? {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::LocalGet => Some((@ir.hot_node_get(func, node_id).imm0, -1))
    _ =>
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::RefAsNonNull) => {
          if @ir.hot_child_count(func, node_id) != 1 {
            return None
          }
          let child_id = @ir.hot_child_get(func, node_id, 0)
          match @ir.hot_node_get(func, child_id).op {
            @ir.HotOp::LocalGet => {
              let local_idx = @ir.hot_node_get(func, child_id).imm0
              match @ir.hot_local_type(func, local_idx) {
                Some(@lib.ValType::RefTypeValType(ref_type)) =>
                  if ref_type.is_non_nullable() {
                    Some((local_idx, -1))
                  } else {
                    Some((local_idx, node_id))
                  }
                _ => None
              }
            }
            _ => None
          }
        }
        _ => None
      }
  }
}

///|
fn optimize_instructions_ref_eq_same_local_as_non_null_trap(
  func : @ir.HotFunc,
  lhs_id : Int,
  rhs_id : Int,
) -> Int? {
  match
    (
      optimize_instructions_ref_eq_same_local_as_non_null_operand(func, lhs_id),
      optimize_instructions_ref_eq_same_local_as_non_null_operand(func, rhs_id),
    ) {
    (Some((lhs, lhs_trap)), Some((rhs, rhs_trap))) if lhs == rhs =>
      if lhs_trap >= 0 {
        Some(lhs_trap)
      } else if rhs_trap >= 0 {
        Some(rhs_trap)
      } else {
        None
      }
    _ => None
  }
}

///|
fn optimize_instructions_replace_with_drop_then_const_i32(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  drop_id : Int,
  value : @lib.I32,
) -> Unit {
  let temp = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [@ir.hot_build_drop(func, drop_id), @ir.hot_build_const_i32(func, value)],
  )
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, node_id),
    node_id,
  )
  @ir.hot_delete_node(func, temp)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_replace_with_drop_then_const_i64(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  drop_id : Int,
  value : @lib.I64,
) -> Unit {
  let temp = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i64()),
    [@ir.hot_build_drop(func, drop_id), @ir.hot_build_const_i64(func, value)],
  )
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, node_id),
    node_id,
  )
  @ir.hot_delete_node(func, temp)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_replace_with_drop_then_unreachable(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  drop_id : Int,
) -> Bool {
  let block_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [] => @lib.BlockType::void_()
    [val_type] => @lib.BlockType::val_type(val_type)
    _ => return false
  }
  let temp = @ir.hot_build_block(func, block_type, [
    @ir.hot_build_drop(func, drop_id),
    @ir.hot_build_unreachable(func),
  ])
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, node_id),
    node_id,
  )
  @ir.hot_delete_node(func, temp)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_node_effects_are_pure(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let effects = pass_require_effects(ctx, func)
  @ir.effects_is_pure(effects.node_masks[node_id])
}

///|
fn optimize_instructions_replace_ref_eq_impossible_with_const_i32(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  lhs_id : Int,
  rhs_id : Int,
) -> Unit {
  let lhs_pure = optimize_instructions_node_effects_are_pure(ctx, func, lhs_id)
  let rhs_pure = optimize_instructions_node_effects_are_pure(ctx, func, rhs_id)
  match (lhs_pure, rhs_pure) {
    (true, true) =>
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        @lib.I32(0),
      )
    (false, true) =>
      optimize_instructions_replace_with_drop_then_const_i32(
        ctx,
        func,
        node_id,
        lhs_id,
        @lib.I32(0),
      )
    (true, false) =>
      optimize_instructions_replace_with_drop_then_const_i32(
        ctx,
        func,
        node_id,
        rhs_id,
        @lib.I32(0),
      )
    (false, false) => {
      let temp = @ir.hot_build_block(
        func,
        @lib.BlockType::val_type(@lib.ValType::i32()),
        [
          @ir.hot_build_drop(func, lhs_id),
          @ir.hot_build_drop(func, rhs_id),
          @ir.hot_build_const_i32(func, @lib.I32(0)),
        ],
      )
      let replacement = @ir.hot_node_get(func, temp)
      @ir.hot_replace_node(func, node_id, replacement)
      @ir.hot_label_owner_set(
        func,
        @ir.hot_control_node_label(func, node_id),
        node_id,
      )
      @ir.hot_delete_node(func, temp)
      pass_mark_mutated(ctx, func)
    }
  }
}

///|
fn optimize_instructions_ref_i31_local_operand(
  func : @ir.HotFunc,
  node_id : Int,
) -> Int? {
  if @ir.hot_child_count(func, node_id) != 1 {
    return None
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefI31) => {
      let child_id = @ir.hot_child_get(func, node_id, 0)
      match @ir.hot_node_get(func, child_id).op {
        @ir.HotOp::LocalGet => Some(@ir.hot_node_get(func, child_id).imm0)
        _ => None
      }
    }
    _ => None
  }
}

///|
fn optimize_instructions_ref_eq_operands_are_same_i31_local(
  func : @ir.HotFunc,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match
    (
      optimize_instructions_ref_i31_local_operand(func, lhs_id),
      optimize_instructions_ref_i31_local_operand(func, rhs_id),
    ) {
    (Some(lhs), Some(rhs)) => lhs == rhs
    _ => false
  }
}

///|
fn optimize_instructions_ref_i31_const_operand(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> @lib.I32? {
  if @ir.hot_child_count(func, node_id) != 1 {
    return None
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefI31) =>
      optimize_instructions_i32_const(
        func,
        dead,
        @ir.hot_child_get(func, node_id, 0),
      )
    _ => None
  }
}

///|
fn optimize_instructions_try_rewrite_ref_eq_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if @ir.hot_child_count(func, node_id) != 2 {
    return false
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefEq) => ()
    _ => return false
  }
  let lhs_id = @ir.hot_child_get(func, node_id, 0)
  let rhs_id = @ir.hot_child_get(func, node_id, 1)
  if optimize_instructions_ref_eq_operands_are_same_local(func, lhs_id, rhs_id) ||
    optimize_instructions_ref_eq_operands_are_same_i31_local(
      func, lhs_id, rhs_id,
    ) {
    optimize_instructions_replace_with_const_i32(
      ctx,
      func,
      node_id,
      @lib.I32(1),
    )
    return true
  }
  match
    optimize_instructions_ref_eq_same_local_as_non_null_trap(
      func, lhs_id, rhs_id,
    ) {
    Some(trap_id) => {
      optimize_instructions_replace_with_drop_then_const_i32(
        ctx,
        func,
        node_id,
        trap_id,
        @lib.I32(1),
      )
      return true
    }
    _ => ()
  }
  match
    (
      optimize_instructions_ref_i31_const_operand(func, dead, lhs_id),
      optimize_instructions_ref_i31_const_operand(func, dead, rhs_id),
    ) {
    (Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      optimize_instructions_replace_with_const_i32(
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
    _ => ()
  }
  if (
      optimize_instructions_ref_is_known_non_null_i31(func, lhs_id) &&
      optimize_instructions_ref_cannot_be_i31(func, rhs_id)
    ) ||
    (
      optimize_instructions_ref_is_known_non_null_i31(func, rhs_id) &&
      optimize_instructions_ref_cannot_be_i31(func, lhs_id)
    ) ||
    optimize_instructions_ref_local_heaps_are_impossible_equal(
      func, lhs_id, rhs_id,
    ) {
    optimize_instructions_replace_ref_eq_impossible_with_const_i32(
      ctx, func, node_id, lhs_id, rhs_id,
    )
    return true
  }
  if optimize_instructions_ref_is_null_operand(func, lhs_id) &&
    optimize_instructions_ref_is_null_operand(func, rhs_id) {
    optimize_instructions_replace_with_const_i32(
      ctx,
      func,
      node_id,
      @lib.I32(1),
    )
    return true
  }
  if optimize_instructions_ref_is_null_operand(func, lhs_id) {
    if optimize_instructions_ref_is_known_non_null(func, rhs_id) {
      if optimize_instructions_node_effects_are_pure(ctx, func, rhs_id) {
        optimize_instructions_replace_with_const_i32(
          ctx,
          func,
          node_id,
          @lib.I32(0),
        )
      } else {
        optimize_instructions_replace_with_drop_then_const_i32(
          ctx,
          func,
          node_id,
          rhs_id,
          @lib.I32(0),
        )
      }
    } else {
      optimize_instructions_replace_with_ref_is_null(ctx, func, node_id, rhs_id)
    }
    return true
  }
  if optimize_instructions_ref_is_null_operand(func, rhs_id) {
    if optimize_instructions_ref_is_known_non_null(func, lhs_id) {
      if optimize_instructions_node_effects_are_pure(ctx, func, lhs_id) {
        optimize_instructions_replace_with_const_i32(
          ctx,
          func,
          node_id,
          @lib.I32(0),
        )
      } else {
        optimize_instructions_replace_with_drop_then_const_i32(
          ctx,
          func,
          node_id,
          lhs_id,
          @lib.I32(0),
        )
      }
    } else {
      optimize_instructions_replace_with_ref_is_null(ctx, func, node_id, lhs_id)
    }
    return true
  }
  false
}

///|
fn optimize_instructions_same_local_integer_compare_result(
  instr : @lib.Instruction,
) -> @lib.I32? {
  match instr {
    @lib.Instruction::I32Eq | @lib.Instruction::I64Eq => Some(@lib.I32(1))
    @lib.Instruction::I32Ne
    | @lib.Instruction::I64Ne
    | @lib.Instruction::I32LtS
    | @lib.Instruction::I32LtU
    | @lib.Instruction::I64LtS
    | @lib.Instruction::I64LtU
    | @lib.Instruction::I32GtS
    | @lib.Instruction::I32GtU
    | @lib.Instruction::I64GtS
    | @lib.Instruction::I64GtU => Some(@lib.I32(0))
    @lib.Instruction::I32LeS
    | @lib.Instruction::I32LeU
    | @lib.Instruction::I64LeS
    | @lib.Instruction::I64LeU
    | @lib.Instruction::I32GeS
    | @lib.Instruction::I32GeU
    | @lib.Instruction::I64GeS
    | @lib.Instruction::I64GeU => Some(@lib.I32(1))
    _ => None
  }
}

///|
fn optimize_instructions_try_fold_same_local_integer_compare(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match
    (
      optimize_instructions_local_get_id(func, dead, lhs_id),
      optimize_instructions_local_get_id(func, dead, rhs_id),
      optimize_instructions_same_local_integer_compare_result(instr),
    ) {
    (Some(lhs_local), Some(rhs_local), Some(result)) if lhs_local == rhs_local => {
      optimize_instructions_replace_with_const_i32(ctx, func, node_id, result)
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_try_fold_same_local_integer_binary(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match
    (
      optimize_instructions_local_get_id(func, dead, lhs_id),
      optimize_instructions_local_get_id(func, dead, rhs_id),
    ) {
    (Some(lhs_local), Some(rhs_local)) if lhs_local == rhs_local => ()
    _ => return false
  }
  match instr {
    @lib.Instruction::I32Sub | @lib.Instruction::I32Xor => {
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        @lib.I32(0),
      )
      true
    }
    @lib.Instruction::I64Sub | @lib.Instruction::I64Xor => {
      optimize_instructions_replace_with_const_i64(
        ctx,
        func,
        node_id,
        @lib.I64(0L),
      )
      true
    }
    @lib.Instruction::I32And
    | @lib.Instruction::I32Or
    | @lib.Instruction::I64And
    | @lib.Instruction::I64Or => {
      optimize_instructions_replace_with_node_id(ctx, func, node_id, lhs_id)
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_i32_sign_extension_range(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> (Int, Int, Int)? {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Unary if node.child_count == 1 => ()
    _ => return None
  }
  let child_id = @ir.hot_child_get(func, node_id, 0)
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::I32Extend8S) => Some((-128, 127, child_id))
    Some(@lib.Instruction::I32Extend16S) => Some((-32768, 32767, child_id))
    _ => None
  }
}

///|
fn optimize_instructions_i32_sign_extension_equality_result(
  instr : @lib.Instruction,
  min_value : Int,
  max_value : Int,
  rhs : Int,
) -> @lib.I32? {
  if rhs >= min_value && rhs <= max_value {
    return None
  }
  match instr {
    @lib.Instruction::I32Eq => Some(@lib.I32(0))
    @lib.Instruction::I32Ne => Some(@lib.I32(1))
    _ => None
  }
}

///|
fn optimize_instructions_try_fold_i32_sign_extension_equality_compare(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let (min_value, max_value, drop_id) = match
    optimize_instructions_i32_sign_extension_range(func, dead, lhs_id) {
    Some(range) => range
    None => return false
  }
  let rhs = match optimize_instructions_i32_const(func, dead, rhs_id) {
    Some(@lib.I32(raw)) => raw
    _ => return false
  }
  match
    optimize_instructions_i32_sign_extension_equality_result(
      instr, min_value, max_value, rhs,
    ) {
    Some(result) => {
      if optimize_instructions_is_side_effect_free_expr(func, dead, drop_id) ||
        optimize_instructions_node_effects_are_pure(ctx, func, drop_id) {
        optimize_instructions_replace_with_const_i32(ctx, func, node_id, result)
      } else {
        optimize_instructions_replace_with_drop_then_const_i32(
          ctx, func, node_id, drop_id, result,
        )
      }
      true
    }
    None => false
  }
}

///|
fn optimize_instructions_i32_unsigned_max(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> Int? {
  optimize_instructions_i32_unsigned_max_fact_for_node(
    func, dead, scratch, node_id,
  )
}

///|
fn optimize_instructions_i32_masked_unsigned_compare_result(
  instr : @lib.Instruction,
  max_value : Int,
  rhs : Int,
) -> @lib.I32? {
  let rhs_outside = rhs < 0 || rhs > max_value
  if !rhs_outside {
    return None
  }
  match instr {
    @lib.Instruction::I32Eq
    | @lib.Instruction::I32GeU
    | @lib.Instruction::I32GtU => Some(@lib.I32(0))
    @lib.Instruction::I32Ne
    | @lib.Instruction::I32LtU
    | @lib.Instruction::I32LeU => Some(@lib.I32(1))
    @lib.Instruction::I32LtS =>
      if rhs <= 0 {
        Some(@lib.I32(0))
      } else {
        Some(@lib.I32(1))
      }
    @lib.Instruction::I32LeS =>
      if rhs < 0 {
        Some(@lib.I32(0))
      } else {
        Some(@lib.I32(1))
      }
    @lib.Instruction::I32GtS =>
      if rhs < 0 {
        Some(@lib.I32(1))
      } else {
        Some(@lib.I32(0))
      }
    @lib.Instruction::I32GeS =>
      if rhs <= 0 {
        Some(@lib.I32(1))
      } else {
        Some(@lib.I32(0))
      }
    _ => None
  }
}

///|
fn optimize_instructions_i32_signed_to_unsigned_compare_instr(
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  match instr {
    @lib.Instruction::I32LtS => Some(@lib.Instruction::i32_lt_u())
    @lib.Instruction::I32LeS => Some(@lib.Instruction::i32_le_u())
    @lib.Instruction::I32GtS => Some(@lib.Instruction::i32_gt_u())
    @lib.Instruction::I32GeS => Some(@lib.Instruction::i32_ge_u())
    _ => None
  }
}

///|
fn optimize_instructions_try_fold_i32_masked_unsigned_compare(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let max_value = match
    optimize_instructions_i32_unsigned_max(func, dead, scratch, lhs_id) {
    Some(value) => value
    None => return false
  }
  let rhs = match optimize_instructions_i32_const(func, dead, rhs_id) {
    Some(@lib.I32(raw)) => raw
    _ => return false
  }
  match
    optimize_instructions_i32_masked_unsigned_compare_result(
      instr, max_value, rhs,
    ) {
    Some(result) => {
      if optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) ||
        optimize_instructions_node_effects_are_pure(ctx, func, lhs_id) {
        optimize_instructions_replace_with_const_i32(ctx, func, node_id, result)
      } else {
        optimize_instructions_replace_with_drop_then_const_i32(
          ctx, func, node_id, lhs_id, result,
        )
      }
      true
    }
    None =>
      match optimize_instructions_i32_signed_to_unsigned_compare_instr(instr) {
        Some(replacement) if rhs >= 0 => {
          optimize_instructions_replace_with_exact_compare(
            ctx, func, node_id, replacement, lhs_id, rhs_id,
          )
          true
        }
        _ => false
      }
  }
}

///|
fn optimize_instructions_i64_unsigned_max(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> Int64? {
  optimize_instructions_i64_unsigned_max_fact_for_node(
    func, dead, scratch, node_id,
  )
}

///|
fn optimize_instructions_i64_masked_unsigned_compare_result(
  instr : @lib.Instruction,
  max_value : Int64,
  rhs : Int64,
) -> @lib.I32? {
  let rhs_outside = rhs < 0L || rhs > max_value
  if !rhs_outside {
    return None
  }
  match instr {
    @lib.Instruction::I64Eq
    | @lib.Instruction::I64GeU
    | @lib.Instruction::I64GtU => Some(@lib.I32(0))
    @lib.Instruction::I64Ne
    | @lib.Instruction::I64LtU
    | @lib.Instruction::I64LeU => Some(@lib.I32(1))
    @lib.Instruction::I64LtS =>
      if rhs <= 0L {
        Some(@lib.I32(0))
      } else {
        Some(@lib.I32(1))
      }
    @lib.Instruction::I64LeS =>
      if rhs < 0L {
        Some(@lib.I32(0))
      } else {
        Some(@lib.I32(1))
      }
    @lib.Instruction::I64GtS =>
      if rhs < 0L {
        Some(@lib.I32(1))
      } else {
        Some(@lib.I32(0))
      }
    @lib.Instruction::I64GeS =>
      if rhs <= 0L {
        Some(@lib.I32(1))
      } else {
        Some(@lib.I32(0))
      }
    _ => None
  }
}

///|
fn optimize_instructions_i64_signed_to_unsigned_compare_instr(
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  match instr {
    @lib.Instruction::I64LtS => Some(@lib.Instruction::i64_lt_u())
    @lib.Instruction::I64LeS => Some(@lib.Instruction::i64_le_u())
    @lib.Instruction::I64GtS => Some(@lib.Instruction::i64_gt_u())
    @lib.Instruction::I64GeS => Some(@lib.Instruction::i64_ge_u())
    _ => None
  }
}

///|
fn optimize_instructions_try_fold_i64_masked_unsigned_compare(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let max_value = match
    optimize_instructions_i64_unsigned_max(func, dead, scratch, lhs_id) {
    Some(value) => value
    None => return false
  }
  let rhs = match optimize_instructions_i64_const(func, dead, rhs_id) {
    Some(@lib.I64(raw)) => raw
    _ => return false
  }
  match
    optimize_instructions_i64_masked_unsigned_compare_result(
      instr, max_value, rhs,
    ) {
    Some(result) => {
      if optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) ||
        optimize_instructions_node_effects_are_pure(ctx, func, lhs_id) {
        optimize_instructions_replace_with_const_i32(ctx, func, node_id, result)
      } else {
        optimize_instructions_replace_with_drop_then_const_i32(
          ctx, func, node_id, lhs_id, result,
        )
      }
      true
    }
    None =>
      match optimize_instructions_i64_signed_to_unsigned_compare_instr(instr) {
        Some(replacement) if rhs >= 0L => {
          optimize_instructions_replace_with_exact_compare(
            ctx, func, node_id, replacement, lhs_id, rhs_id,
          )
          true
        }
        _ => false
      }
  }
}

///|
fn optimize_instructions_try_rewrite_compare_eqz(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  if optimize_instructions_should_keep_i64_eq_zero_if_condition(
      func, dead, scratch, node_id, instr, lhs_id, rhs_id,
    ) {
    return false
  }
  match
    (
      instr,
      optimize_instructions_i32_const(func, dead, lhs_id),
      optimize_instructions_i32_const(func, dead, rhs_id),
    ) {
    (@lib.Instruction::I32Eq, Some(@lib.I32(0)), _) =>
      if optimize_instructions_is_remainder_instr(func, dead, rhs_id) {
        ()
      } else {
        optimize_instructions_replace_with_exact_unary(
          ctx,
          func,
          node_id,
          @lib.Instruction::i32_eqz(),
          rhs_id,
        )
        return true
      }
    (@lib.Instruction::I32Eq, _, Some(@lib.I32(0))) =>
      if optimize_instructions_is_remainder_instr(func, dead, lhs_id) {
        ()
      } else {
        optimize_instructions_replace_with_exact_unary(
          ctx,
          func,
          node_id,
          @lib.Instruction::i32_eqz(),
          lhs_id,
        )
        return true
      }
    _ => ()
  }
  match
    (
      instr,
      optimize_instructions_i64_const(func, dead, lhs_id),
      optimize_instructions_i64_const(func, dead, rhs_id),
    ) {
    (@lib.Instruction::I64Eq, Some(@lib.I64(0L)), _) =>
      if optimize_instructions_is_remainder_instr(func, dead, rhs_id) {
        false
      } else {
        optimize_instructions_replace_with_exact_unary(
          ctx,
          func,
          node_id,
          @lib.Instruction::i64_eqz(),
          rhs_id,
        )
        true
      }
    (@lib.Instruction::I64Eq, _, Some(@lib.I64(0L))) =>
      if optimize_instructions_is_remainder_instr(func, dead, lhs_id) {
        false
      } else {
        optimize_instructions_replace_with_exact_unary(
          ctx,
          func,
          node_id,
          @lib.Instruction::i64_eqz(),
          lhs_id,
        )
        true
      }
    _ => false
  }
}

///|
fn optimize_instructions_visit_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  seen : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  if seen[node_id] {
    return false
  }
  seen[node_id] = true
  match ctx.perf {
    Some(perf) => perf_count_traversal_visit(perf)
    None => ()
  }
  let node = func.nodes[node_id]
  let mut changed = false
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    let child_id = func.children[node.child_base + slot]
    if !optimize_instructions_node_is_live(func, dead, child_id) {
      continue
    }
    changed = optimize_instructions_visit_node(
        ctx, func, dead, child_id, seen, scratch,
      ) ||
      changed
  }
  let local_changed = match node.op {
    @ir.HotOp::Unary =>
      if node.child_count != 1 {
        false
      } else {
        optimize_instructions_try_remove_redundant_sign_ext(
          ctx,
          func,
          dead,
          scratch,
          node_id,
          func.instr_payloads[node.imm0].instr,
          func.children[node.child_base],
        ) ||
        optimize_instructions_try_fold_eqz(
          ctx,
          func,
          dead,
          node_id,
          func.instr_payloads[node.imm0].instr,
          func.children[node.child_base],
        )
      }
    @ir.HotOp::Binary =>
      if node.child_count != 2 {
        false
      } else {
        let initial_instr = func.instr_payloads[node.imm0].instr
        let initial_lhs = func.children[node.child_base]
        let initial_rhs = func.children[node.child_base + 1]
        let changed = optimize_instructions_try_fold_same_local_integer_binary(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_fold_identity_binary(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_fold_absorbing_binary(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_canonicalize_signed_const_unsigned(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_fold_exact_const_binary(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_rewrite_add_sub(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_rewrite_mul_negation(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_rewrite_float_binary(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_rewrite_mul_shift(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_rewrite_div_rem_power_of_two(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_rewrite_sign_ext_idiom(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_combine_nested_const_shift(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_rewrite_shift(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          )
        let current = func.nodes[node_id]
        let canonicalized = match current.op {
          @ir.HotOp::Binary => {
            let current_instr = func.instr_payloads[current.imm0].instr
            if !optimize_instructions_is_commutative_instr(current_instr) {
              false
            } else {
              let current_lhs = func.children[current.child_base]
              let current_rhs = func.children[current.child_base + 1]
              optimize_instructions_try_canonicalize_commutative(
                ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
                scratch,
              )
            }
          }
          _ => false
        }
        if canonicalized {
          let current = func.nodes[node_id]
          let current_lhs = func.children[current.child_base]
          let current_rhs = func.children[current.child_base + 1]
          let current_instr = func.instr_payloads[current.imm0].instr
          optimize_instructions_try_fold_same_local_integer_binary(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_fold_identity_binary(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_fold_absorbing_binary(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_fold_exact_const_binary(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_add_sub(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_mul_negation(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_float_binary(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_mul_shift(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_div_rem_power_of_two(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_sign_ext_idiom(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_combine_nested_const_shift(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_shift(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          true
        } else {
          changed
        }
      }
    @ir.HotOp::Convert =>
      if node.child_count != 1 {
        false
      } else {
        optimize_instructions_try_rewrite_reinterpret_load_result(
          ctx, func, dead, node_id,
        ) ||
        optimize_instructions_try_rewrite_i64_extend_i32_load_result(
          ctx, func, dead, node_id,
        ) ||
        optimize_instructions_try_fold_convert(
          ctx,
          func,
          dead,
          node_id,
          func.instr_payloads[node.imm0].instr,
          func.children[node.child_base],
        )
      }
    @ir.HotOp::Compare =>
      if node.child_count != 2 {
        false
      } else {
        let mut current_instr = func.instr_payloads[node.imm0].instr
        let mut current_lhs = func.children[node.child_base]
        let mut current_rhs = func.children[node.child_base + 1]
        let mut changed = false
        if optimize_instructions_try_fold_same_local_integer_compare(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_compare_eqz(
            ctx, func, dead, scratch, node_id, current_instr, current_lhs, current_rhs,
          ) {
          true
        } else {
          if optimize_instructions_try_canonicalize_signed_const_unsigned(
              ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
            ) {
            changed = true
            let current = func.nodes[node_id]
            current_instr = func.instr_payloads[current.imm0].instr
            current_lhs = func.children[current.child_base]
            current_rhs = func.children[current.child_base + 1]
          }
          if optimize_instructions_try_canonicalize_relational_const(
              ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
            ) {
            changed = true
            let current = func.nodes[node_id]
            current_instr = func.instr_payloads[current.imm0].instr
            current_lhs = func.children[current.child_base]
            current_rhs = func.children[current.child_base + 1]
          }

          let relational_operands_changed = optimize_instructions_try_canonicalize_relational_operands(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs, scratch,
          )
          if relational_operands_changed {
            changed = true
            let current = func.nodes[node_id]
            current_instr = func.instr_payloads[current.imm0].instr
            current_lhs = func.children[current.child_base]
            current_rhs = func.children[current.child_base + 1]
          }
          if optimize_instructions_try_canonicalize_compare_const(
              ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
            ) {
            changed = true
            let current = func.nodes[node_id]
            current_instr = func.instr_payloads[current.imm0].instr
            current_lhs = func.children[current.child_base]
            current_rhs = func.children[current.child_base + 1]
          }
          let range_folded = optimize_instructions_try_fold_i32_sign_extension_equality_compare(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          )
          let masked_unsigned_folded = if range_folded {
            false
          } else {
            optimize_instructions_try_fold_i32_masked_unsigned_compare(
              ctx, func, dead, scratch, node_id, current_instr, current_lhs, current_rhs,
            ) ||
            optimize_instructions_try_fold_i64_masked_unsigned_compare(
              ctx, func, dead, scratch, node_id, current_instr, current_lhs, current_rhs,
            )
          }
          changed = range_folded || masked_unsigned_folded || changed
          let zero_folded = if masked_unsigned_folded || range_folded {
            false
          } else {
            optimize_instructions_try_fold_compare_zero(
              ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
            )
          }
          changed = zero_folded || changed
          if zero_folded || masked_unsigned_folded || range_folded {
            changed
          } else {
            let canonicalized = if optimize_instructions_is_commutative_instr(
                current_instr,
              ) {
              optimize_instructions_try_canonicalize_commutative(
                ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
                scratch,
              )
            } else {
              false
            }
            if canonicalized {
              let current = func.nodes[node_id]
              let next_instr = func.instr_payloads[current.imm0].instr
              let next_lhs = func.children[current.child_base]
              let next_rhs = func.children[current.child_base + 1]
              optimize_instructions_try_canonicalize_compare_const(
                ctx, func, dead, node_id, next_instr, next_lhs, next_rhs,
              ) ||
              optimize_instructions_try_fold_i32_sign_extension_equality_compare(
                ctx, func, dead, node_id, next_instr, next_lhs, next_rhs,
              ) ||
              optimize_instructions_try_fold_i32_masked_unsigned_compare(
                ctx, func, dead, scratch, node_id, next_instr, next_lhs, next_rhs,
              ) ||
              optimize_instructions_try_fold_i64_masked_unsigned_compare(
                ctx, func, dead, scratch, node_id, next_instr, next_lhs, next_rhs,
              ) ||
              optimize_instructions_try_fold_compare_zero(
                ctx, func, dead, node_id, next_instr, next_lhs, next_rhs,
              ) ||
              true
            } else {
              changed
            }
          }
        }
      }
    @ir.HotOp::Select =>
      optimize_instructions_try_fold_const_select(ctx, func, dead, node_id)
    @ir.HotOp::TupleExtract =>
      optimize_instructions_try_fold_tuple_extract_tuple_make(
        ctx, func, dead, node_id,
      )
    @ir.HotOp::RefIsNull =>
      optimize_instructions_try_fold_ref_is_null(ctx, func, node_id)
    @ir.HotOp::RefTest =>
      optimize_instructions_try_fold_ref_test_null(ctx, func, node_id)
    @ir.HotOp::RefCast =>
      optimize_instructions_try_fold_ref_cast_null(ctx, func, node_id) ||
      optimize_instructions_try_replace_ref_cast_unreachable_operand(
        ctx, func, node_id,
      )
    @ir.HotOp::Heap =>
      optimize_instructions_try_fold_ref_as_non_null(ctx, func, node_id) ||
      optimize_instructions_try_rewrite_ref_eq_null(ctx, func, dead, node_id) ||
      optimize_instructions_try_fold_array_len_new_fixed(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_fold_array_get_new_fixed(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_remove_array_set_fresh_array(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_fold_struct_get_struct_new(
        ctx, func, dead, node_id,
      )
    @ir.HotOp::CallRef | @ir.HotOp::ReturnCallRef =>
      optimize_instructions_try_directize_ref_func_call_ref(
        ctx, func, dead, node_id,
      )
    @ir.HotOp::Load =>
      optimize_instructions_try_fold_const_memory_access_offset(
        ctx, func, dead, node_id,
      )
    @ir.HotOp::Store =>
      optimize_instructions_try_fold_const_memory_access_offset(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_truncate_narrow_store_const_value(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_drop_narrow_store_value_mask(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_rewrite_reinterpret_store_value(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_widen_store_of_wrap_i64(
        ctx, func, dead, node_id,
      )
    @ir.HotOp::MemoryCopy =>
      optimize_instructions_try_expand_tiny_memory_copy(
        ctx, func, dead, node_id,
      )
    @ir.HotOp::MemoryFill =>
      optimize_instructions_try_expand_tiny_memory_fill(
        ctx, func, dead, node_id,
      )
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      optimize_instructions_try_collapse_dead_region_suffix(
        ctx,
        func,
        dead,
        @ir.hot_region_body_ref(func, node_id),
        @ir.hot_control_node_label(func, node_id),
      )
    @ir.HotOp::If =>
      optimize_instructions_try_fold_constant_if_condition(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_optimize_if_condition(ctx, func, dead, node_id) ||
      optimize_instructions_try_wrap_boolean_if_value_in_eqz(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_collapse_dead_region_suffix(
        ctx,
        func,
        dead,
        @ir.hot_region_then_ref(func, node_id),
        @ir.hot_control_node_label(func, node_id),
      ) ||
      (match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_try_collapse_dead_region_suffix(
            ctx,
            func,
            dead,
            else_region,
            @ir.hot_control_node_label(func, node_id),
          )
        None => false
      })
    _ => false
  }
  local_changed || changed
}

///|
fn optimize_instructions_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  let mut changed = false
  let node_count = @ir.hot_node_count(func)
  let seen = @bitset.BitSet::new(node_count)
  let dead = @bitset.BitSet::new(node_count)
  let scratch = OptimizeInstructionsScratch::new(node_count)
  for free_id in func.free_nodes {
    if free_id >= 0 && free_id < dead.length() {
      dead[free_id] = true
    }
  }
  optimize_instructions_scan_sign_ext_facts(func, dead, scratch)
  optimize_instructions_scan_unsigned_max_facts(func, dead, scratch)
  for slot = 0; slot < func.roots.length(); slot = slot + 1 {
    changed = optimize_instructions_visit_node(
        ctx,
        func,
        dead,
        func.roots[slot],
        seen,
        scratch,
      ) ||
      changed
  }
  if changed {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
