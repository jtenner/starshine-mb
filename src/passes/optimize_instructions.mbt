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
priv struct OptimizeInstructionsScratch {
  cross_seen_stamps : Array[Int]
  mut next_cross_seen_stamp : Int
}

///|
fn OptimizeInstructionsScratch::new(
  node_count : Int,
) -> OptimizeInstructionsScratch {
  { cross_seen_stamps: Array::make(node_count, -1), next_cross_seen_stamp: 0 }
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
  dead : Array[Bool],
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
  dead : Array[Bool],
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
  scratch : OptimizeInstructionsScratch,
) -> Bool {
  if !optimize_instructions_is_commutative_instr(instr) {
    return false
  }
  if optimize_instructions_is_constlike(func, dead, lhs_id) &&
    !optimize_instructions_is_constlike(func, dead, rhs_id) {
    optimize_instructions_rewrite_exact_with_children(
      ctx,
      func,
      node_id,
      instr,
      [rhs_id, lhs_id],
    )
    return true
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
      let seen_stamp = optimize_instructions_alloc_cross_seen_stamp(scratch)
      let can_cross = optimize_instructions_can_cross_local_get(
        func,
        dead,
        rhs_id,
        local_id,
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
        instr,
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
      let seen_stamp = optimize_instructions_alloc_cross_seen_stamp(scratch)
      let can_cross = optimize_instructions_can_cross_local_get(
        func,
        dead,
        lhs_id,
        local_id,
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
  dead : Array[Bool],
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
  dead : Array[Bool],
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
      let seen_stamp = optimize_instructions_alloc_cross_seen_stamp(scratch)
      let can_cross = optimize_instructions_can_cross_local_get(
        func,
        dead,
        rhs_id,
        local_id,
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
      let seen_stamp = optimize_instructions_alloc_cross_seen_stamp(scratch)
      let can_cross = optimize_instructions_can_cross_local_get(
        func,
        dead,
        lhs_id,
        local_id,
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
  dead : Array[Bool],
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
fn optimize_instructions_try_fold_eqz(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : Array[Bool],
  node_id : Int,
  instr : @lib.Instruction,
  operand_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, operand_id) {
    return false
  }
  let operand = func.nodes[operand_id]
  match operand.op {
    @ir.HotOp::Const => ()
    _ => return false
  }

  let folded = match (instr, @ir.hot_const_get(func, operand.imm0)) {
    (@lib.Instruction::I32Eqz, @ir.HotConstPayload::I32Const(v)) =>
      Some(if v == @lib.I32(0) { @lib.I32(1) } else { @lib.I32(0) })
    (@lib.Instruction::I64Eqz, @ir.HotConstPayload::I64Const(v)) =>
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
fn optimize_instructions_try_fold_exact_const_binary(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : Array[Bool],
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
        _ => false
      }
  }
}

///|
fn optimize_instructions_try_rewrite_add_sub(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : Array[Bool],
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
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
    (@lib.Instruction::I32Add, Some(@lib.I32(raw))) if optimize_instructions_prefer_negative_leb_i32(
        raw,
      ) => {
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
    (@lib.Instruction::I32Sub, Some(@lib.I32(raw))) if optimize_instructions_prefer_negative_leb_i32(
        raw,
      ) => {
      let replacement_rhs = @ir.hot_build_const_i32(func, @lib.I32(-raw))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_add(),
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
        (@lib.Instruction::I64Add, Some(@lib.I64(raw))) if optimize_instructions_prefer_negative_leb_i64(
            raw,
          ) => {
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
        (@lib.Instruction::I64Sub, Some(@lib.I64(raw))) if optimize_instructions_prefer_negative_leb_i64(
            raw,
          ) => {
          let replacement_rhs = @ir.hot_build_const_i64(func, @lib.I64(-raw))
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_add(),
            [lhs_id, replacement_rhs],
          )
          true
        }
        _ => false
      }
  }
}

///|
fn optimize_instructions_try_rewrite_mul_shift(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : Array[Bool],
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
fn optimize_instructions_try_rewrite_shift(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : Array[Bool],
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
fn optimize_instructions_try_fold_compare_zero(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : Array[Bool],
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
fn optimize_instructions_visit_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : Array[Bool],
  node_id : Int,
  seen : Array[Bool],
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
        let instr = func.instr_payloads[node.imm0].instr
        let lhs_id = func.children[node.child_base]
        let rhs_id = func.children[node.child_base + 1]
        let changed = optimize_instructions_try_fold_exact_const_binary(
            ctx, func, dead, node_id, instr, lhs_id, rhs_id,
          ) ||
          optimize_instructions_try_rewrite_add_sub(
            ctx, func, dead, node_id, instr, lhs_id, rhs_id,
          ) ||
          optimize_instructions_try_rewrite_mul_shift(
            ctx, func, dead, node_id, instr, lhs_id, rhs_id,
          ) ||
          optimize_instructions_try_rewrite_shift(
            ctx, func, dead, node_id, instr, lhs_id, rhs_id,
          )
        let canonicalized = if optimize_instructions_is_commutative_instr(instr) {
          optimize_instructions_try_canonicalize_commutative(
            ctx, func, dead, node_id, instr, lhs_id, rhs_id, scratch,
          )
        } else {
          false
        }
        if canonicalized {
          let current = func.nodes[node_id]
          let current_lhs = func.children[current.child_base]
          let current_rhs = func.children[current.child_base + 1]
          let current_instr = func.instr_payloads[current.imm0].instr
          optimize_instructions_try_fold_exact_const_binary(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_add_sub(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_mul_shift(
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
    @ir.HotOp::Compare =>
      if node.child_count != 2 {
        false
      } else {
        let mut current_instr = func.instr_payloads[node.imm0].instr
        let mut current_lhs = func.children[node.child_base]
        let mut current_rhs = func.children[node.child_base + 1]
        let mut changed = false
        if optimize_instructions_try_canonicalize_relational_const(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) {
          changed = true
          let current = func.nodes[node_id]
          current_instr = func.instr_payloads[current.imm0].instr
          current_lhs = func.children[current.child_base]
          current_rhs = func.children[current.child_base + 1]
        }
        if optimize_instructions_try_canonicalize_relational_operands(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs, scratch,
          ) {
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
        let zero_folded = optimize_instructions_try_fold_compare_zero(
          ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
        )
        changed = zero_folded || changed
        if zero_folded {
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
            optimize_instructions_try_fold_compare_zero(
              ctx, func, dead, node_id, next_instr, next_lhs, next_rhs,
            ) ||
            true
          } else {
            changed
          }
        }
      }
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
  let scratch = OptimizeInstructionsScratch::new(node_count)
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
