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
  "Fold safe exact-instruction peepholes such as constant eqz, shift masks, and compare-to-zero patterns."
}

///|
fn optimize_instructions_node_is_live(
  func : @ir.HotFunc,
  dead : Array[Bool],
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
fn optimize_instructions_i32_const(
  func : @ir.HotFunc,
  dead : Array[Bool],
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
  dead : Array[Bool],
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
  dead : Array[Bool],
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
  dead : Array[Bool],
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
fn optimize_instructions_can_cross_local_get(
  func : @ir.HotFunc,
  dead : Array[Bool],
  node_id : Int,
  local_id : Int,
  seen : Array[Bool],
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return true
  }
  if node_id < seen.length() && seen[node_id] {
    return true
  }
  if node_id < seen.length() {
    seen[node_id] = true
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee if node.imm0 == local_id =>
      return false
    _ => ()
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if !optimize_instructions_can_cross_local_get(
        func,
        dead,
        func.children[node.child_base + slot],
        local_id,
        seen,
      ) {
      return false
    }
  }
  true
}

///|
fn optimize_instructions_try_canonicalize_commutative(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : Array[Bool],
  node_id : Int,
) -> Bool {
  let node = func.nodes[node_id]
  if node.child_count != 2 {
    return false
  }
  let instr = match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) if optimize_instructions_is_commutative_instr(instr) => instr
    _ => return false
  }
  let lhs_id = func.children[node.child_base]
  let rhs_id = func.children[node.child_base + 1]
  match optimize_instructions_local_get_id(func, dead, lhs_id) {
    Some(local_id) => {
      if optimize_instructions_is_constlike(func, dead, rhs_id) {
        return false
      }
      let seen = Array::make(@ir.hot_node_count(func), false)
      if !optimize_instructions_can_cross_local_get(
          func, dead, rhs_id, local_id, seen,
        ) {
        return false
      }
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        instr,
        [rhs_id, lhs_id],
      )
      true
    }
    None => false
  }
}

///|
fn optimize_instructions_is_trivially_pure_value(
  func : @ir.HotFunc,
  dead : Array[Bool],
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
fn optimize_instructions_try_fold_eqz(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : Array[Bool],
  node_id : Int,
) -> Bool {
  let node = func.nodes[node_id]
  match node.op {
    @ir.HotOp::Unary => ()
    _ => return false
  }
  if node.child_count != 1 {
    return false
  }
  let operand_id = func.children[node.child_base]
  if !optimize_instructions_node_is_live(func, dead, operand_id) {
    return false
  }
  let operand = func.nodes[operand_id]
  match operand.op {
    @ir.HotOp::Const => ()
    _ => return false
  }

  let folded = match
    (
      @ir.hot_node_exact_instr(func, node_id),
      @ir.hot_const_get(func, operand.imm0),
    ) {
    (Some(@lib.Instruction::I32Eqz), @ir.HotConstPayload::I32Const(v)) =>
      Some(if v == @lib.I32(0) { @lib.I32(1) } else { @lib.I32(0) })
    (Some(@lib.Instruction::I64Eqz), @ir.HotConstPayload::I64Const(v)) =>
      Some(if v == @lib.I64(0) { @lib.I32(1) } else { @lib.I32(0) })
    _ => None
  }
  match folded {
    Some(value) => {
      optimize_instructions_replace_with_const_i32(ctx, func, node_id, value)
      true
    }
    None => false
  }
}

///|
fn optimize_instructions_try_rewrite_add_sub(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : Array[Bool],
  node_id : Int,
) -> Bool {
  let node = func.nodes[node_id]
  match node.op {
    @ir.HotOp::Binary => ()
    _ => return false
  }
  if node.child_count != 2 {
    return false
  }
  let instr = match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) => instr
    None => return false
  }
  let lhs_id = func.children[node.child_base]
  let rhs_id = func.children[node.child_base + 1]
  match (instr, optimize_instructions_i32_const(func, dead, rhs_id)) {
    (@lib.Instruction::I32Add, Some(@lib.I32(raw))) if raw < 0 => {
      let replacement_rhs = @ir.hot_build_const_i32(func, @lib.I32(-raw))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_sub(),
        [lhs_id, replacement_rhs],
      )
      true
    }
    _ =>
      match (instr, optimize_instructions_i64_const(func, dead, rhs_id)) {
        (@lib.Instruction::I64Add, Some(@lib.I64(raw))) if raw < 0L => {
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
}

///|
fn optimize_instructions_try_rewrite_shift(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : Array[Bool],
  node_id : Int,
) -> Bool {
  let node = func.nodes[node_id]
  match node.op {
    @ir.HotOp::Binary => ()
    _ => return false
  }
  if node.child_count != 2 {
    return false
  }
  let instr = match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) => instr
    None => return false
  }
  let mask_bits = match optimize_instructions_shift_mask_bits(instr) {
    Some(bits) => bits
    None => return false
  }
  let lhs_id = func.children[node.child_base]
  let rhs_id = func.children[node.child_base + 1]

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
fn optimize_instructions_try_fold_compare_zero(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : Array[Bool],
  node_id : Int,
) -> Bool {
  let node = func.nodes[node_id]
  match node.op {
    @ir.HotOp::Compare => ()
    _ => return false
  }
  if node.child_count != 2 {
    return false
  }
  let instr = match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) => instr
    None => return false
  }
  let lhs_id = func.children[node.child_base]
  let rhs_id = func.children[node.child_base + 1]
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
fn optimize_instructions_visit_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : Array[Bool],
  node_id : Int,
  seen : Array[Bool],
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
    changed = optimize_instructions_visit_node(ctx, func, dead, child_id, seen) ||
      changed
  }
  let local_changed = match node.op {
    @ir.HotOp::Unary =>
      optimize_instructions_try_fold_eqz(ctx, func, dead, node_id)
    @ir.HotOp::Binary =>
      optimize_instructions_try_rewrite_add_sub(ctx, func, dead, node_id) ||
      optimize_instructions_try_rewrite_shift(ctx, func, dead, node_id) ||
      optimize_instructions_try_canonicalize_commutative(
        ctx, func, dead, node_id,
      )
    @ir.HotOp::Compare =>
      optimize_instructions_try_fold_compare_zero(ctx, func, dead, node_id) ||
      optimize_instructions_try_canonicalize_commutative(
        ctx, func, dead, node_id,
      )
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
  let seen = Array::make(node_count, false)
  let dead = Array::make(node_count, false)
  for free_id in func.free_nodes {
    if free_id >= 0 && free_id < dead.length() {
      dead[free_id] = true
    }
  }
  for slot = 0; slot < func.roots.length(); slot = slot + 1 {
    changed = optimize_instructions_visit_node(
        ctx,
        func,
        dead,
        func.roots[slot],
        seen,
      ) ||
      changed
  }
  if changed {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
