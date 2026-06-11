///|
pub struct GenValidSsaFuncFacts {
  has_ssa_straight_line_local_chain : Bool
  has_ssa_multi_def_same_local : Bool
  has_ssa_local_tee_def_use : Bool
  has_ssa_param_write : Bool
  has_ssa_dead_local_set : Bool
  has_ssa_dead_local_tee : Bool
  has_ssa_if_join_phi_candidate : Bool
  has_ssa_loop_backedge_phi_candidate : Bool
  has_ssa_br_table_phi_candidate : Bool
  has_ssa_parallel_copy_candidate : Bool
  has_ssa_parallel_copy_cycle_candidate : Bool
  has_ssa_default_local_merge : Bool
  has_ssa_unreachable_local_carrier : Bool
  has_ssa_dropped_increment_guard_shape : Bool
  has_ssa_dropped_increment_reversed_boundary : Bool
  has_ssa_exceptional_fail_closed_shape : Bool
  has_ssa_typed_loop_param_fail_closed_shape : Bool
  has_ssa_nested_cfg_fail_closed_shape : Bool
  has_ssa_nested_result_if_supported_shape : Bool
  has_ssa_nested_result_if_condition_write : Bool
  has_ssa_nested_result_if_condition_value_block : Bool
  has_ssa_nested_result_if_arm_value_block : Bool
  has_ssa_nested_result_if_mixed_arm_value_block : Bool
  has_ssa_nested_result_if_scalar_result : Bool
  has_ssa_structured_early_return_local : Bool
  has_ssa_block_branch_merge_copy : Bool
  has_ssa_block_br_if_merge_copy : Bool
  has_ssa_structured_param_merge : Bool
  has_ssa_branch_local_not_read_later : Bool
} derive(Eq, Debug)

///|
pub fn GenValidSsaFuncFacts::empty() -> GenValidSsaFuncFacts {
  {
    has_ssa_straight_line_local_chain: false,
    has_ssa_multi_def_same_local: false,
    has_ssa_local_tee_def_use: false,
    has_ssa_param_write: false,
    has_ssa_dead_local_set: false,
    has_ssa_dead_local_tee: false,
    has_ssa_if_join_phi_candidate: false,
    has_ssa_loop_backedge_phi_candidate: false,
    has_ssa_br_table_phi_candidate: false,
    has_ssa_parallel_copy_candidate: false,
    has_ssa_parallel_copy_cycle_candidate: false,
    has_ssa_default_local_merge: false,
    has_ssa_unreachable_local_carrier: false,
    has_ssa_dropped_increment_guard_shape: false,
    has_ssa_dropped_increment_reversed_boundary: false,
    has_ssa_exceptional_fail_closed_shape: false,
    has_ssa_typed_loop_param_fail_closed_shape: false,
    has_ssa_nested_cfg_fail_closed_shape: false,
    has_ssa_nested_result_if_supported_shape: false,
    has_ssa_nested_result_if_condition_write: false,
    has_ssa_nested_result_if_condition_value_block: false,
    has_ssa_nested_result_if_arm_value_block: false,
    has_ssa_nested_result_if_mixed_arm_value_block: false,
    has_ssa_nested_result_if_scalar_result: false,
    has_ssa_structured_early_return_local: false,
    has_ssa_block_branch_merge_copy: false,
    has_ssa_block_br_if_merge_copy: false,
    has_ssa_structured_param_merge: false,
    has_ssa_branch_local_not_read_later: false,
  }
}

///|
pub fn gen_valid_merge_ssa_func_facts(
  left : GenValidSsaFuncFacts,
  right : GenValidSsaFuncFacts,
) -> GenValidSsaFuncFacts {
  {
    has_ssa_straight_line_local_chain: left.has_ssa_straight_line_local_chain ||
    right.has_ssa_straight_line_local_chain,
    has_ssa_multi_def_same_local: left.has_ssa_multi_def_same_local ||
    right.has_ssa_multi_def_same_local,
    has_ssa_local_tee_def_use: left.has_ssa_local_tee_def_use ||
    right.has_ssa_local_tee_def_use,
    has_ssa_param_write: left.has_ssa_param_write || right.has_ssa_param_write,
    has_ssa_dead_local_set: left.has_ssa_dead_local_set ||
    right.has_ssa_dead_local_set,
    has_ssa_dead_local_tee: left.has_ssa_dead_local_tee ||
    right.has_ssa_dead_local_tee,
    has_ssa_if_join_phi_candidate: left.has_ssa_if_join_phi_candidate ||
    right.has_ssa_if_join_phi_candidate,
    has_ssa_loop_backedge_phi_candidate: left.has_ssa_loop_backedge_phi_candidate ||
    right.has_ssa_loop_backedge_phi_candidate,
    has_ssa_br_table_phi_candidate: left.has_ssa_br_table_phi_candidate ||
    right.has_ssa_br_table_phi_candidate,
    has_ssa_parallel_copy_candidate: left.has_ssa_parallel_copy_candidate ||
    right.has_ssa_parallel_copy_candidate,
    has_ssa_parallel_copy_cycle_candidate: left.has_ssa_parallel_copy_cycle_candidate ||
    right.has_ssa_parallel_copy_cycle_candidate,
    has_ssa_default_local_merge: left.has_ssa_default_local_merge ||
    right.has_ssa_default_local_merge,
    has_ssa_unreachable_local_carrier: left.has_ssa_unreachable_local_carrier ||
    right.has_ssa_unreachable_local_carrier,
    has_ssa_dropped_increment_guard_shape: left.has_ssa_dropped_increment_guard_shape ||
    right.has_ssa_dropped_increment_guard_shape,
    has_ssa_dropped_increment_reversed_boundary: left.has_ssa_dropped_increment_reversed_boundary ||
    right.has_ssa_dropped_increment_reversed_boundary,
    has_ssa_exceptional_fail_closed_shape: left.has_ssa_exceptional_fail_closed_shape ||
    right.has_ssa_exceptional_fail_closed_shape,
    has_ssa_typed_loop_param_fail_closed_shape: left.has_ssa_typed_loop_param_fail_closed_shape ||
    right.has_ssa_typed_loop_param_fail_closed_shape,
    has_ssa_nested_cfg_fail_closed_shape: left.has_ssa_nested_cfg_fail_closed_shape ||
    right.has_ssa_nested_cfg_fail_closed_shape,
    has_ssa_nested_result_if_supported_shape: left.has_ssa_nested_result_if_supported_shape ||
    right.has_ssa_nested_result_if_supported_shape,
    has_ssa_nested_result_if_condition_write: left.has_ssa_nested_result_if_condition_write ||
    right.has_ssa_nested_result_if_condition_write,
    has_ssa_nested_result_if_condition_value_block: left.has_ssa_nested_result_if_condition_value_block ||
    right.has_ssa_nested_result_if_condition_value_block,
    has_ssa_nested_result_if_arm_value_block: left.has_ssa_nested_result_if_arm_value_block ||
    right.has_ssa_nested_result_if_arm_value_block,
    has_ssa_nested_result_if_mixed_arm_value_block: left.has_ssa_nested_result_if_mixed_arm_value_block ||
    right.has_ssa_nested_result_if_mixed_arm_value_block,
    has_ssa_nested_result_if_scalar_result: left.has_ssa_nested_result_if_scalar_result ||
    right.has_ssa_nested_result_if_scalar_result,
    has_ssa_structured_early_return_local: left.has_ssa_structured_early_return_local ||
    right.has_ssa_structured_early_return_local,
    has_ssa_block_branch_merge_copy: left.has_ssa_block_branch_merge_copy ||
    right.has_ssa_block_branch_merge_copy,
    has_ssa_block_br_if_merge_copy: left.has_ssa_block_br_if_merge_copy ||
    right.has_ssa_block_br_if_merge_copy,
    has_ssa_structured_param_merge: left.has_ssa_structured_param_merge ||
    right.has_ssa_structured_param_merge,
    has_ssa_branch_local_not_read_later: left.has_ssa_branch_local_not_read_later ||
    right.has_ssa_branch_local_not_read_later,
  }
}

///|
const GEN_VALID_SSA_LOCAL_CAP : Int = 32

///|
fn gen_valid_ssa_local_slot(idx : LocalIdx) -> Int? {
  let LocalIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  if slot < 0 || slot >= GEN_VALID_SSA_LOCAL_CAP {
    None
  } else {
    Some(slot)
  }
}

///|
fn gen_valid_ssa_func_has_local_write(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      LocalSet(_) | LocalTee(_) => return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if gen_valid_ssa_func_has_local_write(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_ssa_func_has_local_write(Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_ssa_func_has_local_write(Expr::new(body)) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_ssa_func_has_exceptional(instr : Instruction) -> Bool {
  match instr {
    TryTable(_, _, _) | Throw(_) | ThrowRef => true
    _ => false
  }
}

///|
fn gen_valid_ssa_expr_has_exceptional(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    if gen_valid_ssa_func_has_exceptional(instr) {
      return true
    }
    match instr {
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if gen_valid_ssa_expr_has_exceptional(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_ssa_expr_has_exceptional(Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_ssa_expr_has_exceptional(Expr::new(body)) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_ssa_blocktype_is_typed_loop(bt : BlockType) -> Bool {
  match bt {
    TypeIdxBlockType(_) => true
    _ => false
  }
}

///|
fn gen_valid_ssa_is_scalar_numeric_result(vt : ValType) -> Bool {
  vt == ValType::i32() ||
  vt == ValType::i64() ||
  vt == ValType::f32() ||
  vt == ValType::f64()
}

///|
fn gen_valid_ssa_blocktype_scalar_result(bt : BlockType) -> ValType? {
  match bt {
    ValTypeBlockType(vt) if gen_valid_ssa_is_scalar_numeric_result(vt) =>
      Some(vt)
    _ => None
  }
}

///|
fn gen_valid_ssa_instr_is_forbidden_control(instr : Instruction) -> Bool {
  match instr {
    Block(_, _)
    | Loop(_, _)
    | If(_, _, _)
    | Br(_)
    | BrIf(_)
    | BrTable(_, _)
    | Return
    | Unreachable
    | TryTable(_, _, _)
    | Throw(_)
    | ThrowRef => true
    _ => false
  }
}

///|
fn gen_valid_ssa_blocktype_has_stack_result(bt : BlockType) -> Bool {
  match bt {
    ValTypeBlockType(_) | TypeIdxBlockType(_) => true
    _ => false
  }
}

///|
fn gen_valid_ssa_instr_subtree_is_straight_line_no_nested_control(
  instr : Instruction,
  allow_block_root : Bool,
) -> Bool {
  match instr {
    Block(_, body) if allow_block_root =>
      gen_valid_ssa_expr_is_straight_line_no_nested_control(body)
    Block(_, _)
    | Loop(_, _)
    | If(_, _, _)
    | Br(_)
    | BrIf(_)
    | BrTable(_, _)
    | Return
    | Unreachable
    | TryTable(_, _, _)
    | Throw(_)
    | ThrowRef => false
    _ => true
  }
}

///|
fn gen_valid_ssa_expr_is_straight_line_no_nested_control(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    if !gen_valid_ssa_instr_subtree_is_straight_line_no_nested_control(
        instr, false,
      ) {
      return false
    }
  }
  true
}

///|
fn gen_valid_ssa_subtree_is_straight_line_no_nested_control(
  expr : Expr,
  allow_block_root : Bool,
) -> Bool {
  let Expr(instrs) = expr
  let mut allow_root = allow_block_root
  for instr in instrs {
    if !gen_valid_ssa_instr_subtree_is_straight_line_no_nested_control(
        instr, allow_root,
      ) {
      return false
    }
    allow_root = false
  }
  true
}

///|
fn gen_valid_ssa_instr_i32_stack_delta(instr : Instruction) -> Int? {
  match instr {
    I32Const(_) | LocalGet(_) => Some(1)
    LocalTee(_) => Some(0)
    Block(ValTypeBlockType(vt), _) if vt == ValType::i32() => Some(1)
    Block(TypeIdxBlockType(_), _) => Some(1)
    LocalSet(_)
    | Drop
    | Br(_)
    | BrIf(_)
    | BrTable(_, _)
    | Return
    | Unreachable => Some(-1)
    I32Add
    | I32Sub
    | I32Mul
    | I32DivS
    | I32DivU
    | I32RemS
    | I32RemU
    | I32And
    | I32Or
    | I32Xor => Some(-1)
    Block(bt, _) | Loop(bt, _) if !gen_valid_ssa_blocktype_has_stack_result(bt) =>
      Some(0)
    _ => None
  }
}

///|
fn gen_valid_ssa_prefix_leaves_single_i32(
  instrs : Array[Instruction],
  start : Int,
  end : Int,
) -> Bool {
  let mut stack = 0
  let mut i = start
  while i < end {
    match gen_valid_ssa_instr_i32_stack_delta(instrs[i]) {
      None => return false
      Some(delta) => {
        stack = stack + delta
        if stack < 0 {
          return false
        }
      }
    }
    i += 1
  }
  stack == 1
}

///|
fn gen_valid_ssa_instr_scalar_stack_delta(
  instr : Instruction,
  result_vt : ValType,
) -> Int? {
  match instr {
    I32Const(_) if result_vt == ValType::i32() => Some(1)
    I64Const(_) if result_vt == ValType::i64() => Some(1)
    F32Const(_) if result_vt == ValType::f32() => Some(1)
    F64Const(_) if result_vt == ValType::f64() => Some(1)
    LocalGet(_) => Some(1)
    LocalTee(_) => Some(0)
    LocalSet(_) | Drop => Some(-1)
    Block(ValTypeBlockType(vt), _) if vt == result_vt => Some(1)
    Block(bt, _) | Loop(bt, _) if !gen_valid_ssa_blocktype_has_stack_result(bt) =>
      Some(0)
    I32Add
    | I32Sub
    | I32Mul
    | I32DivS
    | I32DivU
    | I32RemS
    | I32RemU
    | I32And
    | I32Or
    | I32Xor if result_vt == ValType::i32() => Some(-1)
    I64Add
    | I64Sub
    | I64Mul
    | I64DivS
    | I64DivU
    | I64RemS
    | I64RemU
    | I64And
    | I64Or
    | I64Xor if result_vt == ValType::i64() => Some(-1)
    F32Add | F32Sub | F32Mul | F32Div | F32Min | F32Max if result_vt ==
      ValType::f32() => Some(-1)
    F64Add | F64Sub | F64Mul | F64Div | F64Min | F64Max if result_vt ==
      ValType::f64() => Some(-1)
    Br(_)
    | BrIf(_)
    | BrTable(_, _)
    | Return
    | Unreachable
    | If(_, _, _)
    | Loop(_, _)
    | TryTable(_, _, _) => None
    _ => None
  }
}

///|
fn gen_valid_ssa_arm_value_block_is_supported(
  instr : Instruction,
  result_vt : ValType,
) -> Bool {
  match instr {
    Block(ValTypeBlockType(vt), body) if vt == result_vt =>
      gen_valid_ssa_expr_is_straight_line_no_nested_control(body)
    _ => false
  }
}

///|
fn gen_valid_ssa_prefix_stack_depth(
  instrs : Array[Instruction],
  start : Int,
  end : Int,
  result_vt? : ValType = ValType::i32(),
) -> Int? {
  let mut stack = 0
  let mut i = start
  while i < end {
    let delta = if result_vt == ValType::i32() {
      gen_valid_ssa_instr_i32_stack_delta(instrs[i])
    } else {
      gen_valid_ssa_instr_scalar_stack_delta(instrs[i], result_vt)
    }
    match delta {
      None => return None
      Some(delta) => {
        stack = stack + delta
        if stack < 0 {
          return None
        }
      }
    }
    i += 1
  }
  Some(stack)
}

///|
fn gen_valid_ssa_arm_region_is_supported(
  body : Array[Instruction],
  result_vt : ValType,
) -> Bool {
  let mut last_live_idx = -1
  let mut value_block_idx = -1
  let mut i = 0

  while i < body.length() {
    last_live_idx = i
    if gen_valid_ssa_arm_value_block_is_supported(body[i], result_vt) {
      if value_block_idx >= 0 {
        return false
      }
      value_block_idx = i
    }
    i += 1
  }

  if value_block_idx >= 0 {
    // Mixed or single value-block arm:
    //   [straight-line stack-neutral prefix instructions]*
    //   final block(result t)
    //
    // In the GenValid AST, a HOT "void root" such as local.set appears as
    // multiple stack instructions (`const`, `local.set`). Therefore this scanner
    // must validate the prefix as a stack-neutral straight-line sequence, not as
    // individually void-producing roots.
    if value_block_idx != last_live_idx {
      return false
    }

    let prefix_expr = Expr::new(
      gen_valid_ssa_slice_instrs(body, 0, value_block_idx),
    )
    if !gen_valid_ssa_expr_is_straight_line_no_nested_control(prefix_expr) {
      return false
    }

    match
      gen_valid_ssa_prefix_stack_depth(body, 0, value_block_idx, result_vt~) {
      Some(0) => true
      _ => false
    }
  } else {
    // Plain straight-line arm with no explicit arm value-block. The whole arm
    // must be straight-line and leave exactly one value of the parent result type.
    let whole_expr = Expr::new(
      gen_valid_ssa_slice_instrs(body, 0, body.length()),
    )
    if !gen_valid_ssa_expr_is_straight_line_no_nested_control(whole_expr) {
      return false
    }

    match gen_valid_ssa_prefix_stack_depth(body, 0, body.length(), result_vt~) {
      Some(1) => true
      _ => false
    }
  }
}

///|
fn gen_valid_ssa_condition_value_block_is_supported(
  instr : Instruction,
) -> Bool {
  gen_valid_ssa_arm_value_block_is_supported(instr, ValType::i32())
}

///|
priv struct GenValidSsaConditionFacts {
  has_condition_write : Bool
  has_condition_value_block : Bool
}

///|
fn gen_valid_ssa_condition_window_bounds(
  instrs : Array[Instruction],
  if_idx : Int,
) -> (Int, Int)? {
  if if_idx <= 0 {
    return None
  }
  let mut need = 1
  let mut i = if_idx - 1
  while i >= 0 {
    match gen_valid_ssa_instr_i32_stack_delta(instrs[i]) {
      None => return None
      Some(delta) => {
        need = need - delta
        if need <= 0 {
          match gen_valid_ssa_prefix_stack_depth(instrs, i, if_idx) {
            Some(1) => return Some((i, if_idx))
            _ => return None
          }
        }
      }
    }
    i -= 1
  }
  None
}

///|
fn gen_valid_ssa_condition_window_is_supported(
  instrs : Array[Instruction],
  start : Int,
  end : Int,
) -> Bool {
  if start < 0 || end <= start || end > instrs.length() {
    return false
  }
  let len = end - start
  if len == 1 {
    match instrs[start] {
      instr if gen_valid_ssa_condition_value_block_is_supported(instr) => true
      instr =>
        gen_valid_ssa_instr_subtree_is_straight_line_no_nested_control(
          instr, false,
        ) &&
        gen_valid_ssa_prefix_leaves_single_i32(instrs, start, end)
    }
  } else {
    gen_valid_ssa_subtree_is_straight_line_no_nested_control(
      Expr::new(gen_valid_ssa_slice_instrs(instrs, start, end)),
      false,
    ) &&
    gen_valid_ssa_prefix_leaves_single_i32(instrs, start, end)
  }
}

///|
fn gen_valid_ssa_condition_facts_from_window(
  instrs : Array[Instruction],
  start : Int,
  end : Int,
) -> GenValidSsaConditionFacts {
  let mut has_write = false
  let mut has_value_block = false

  if end - start == 1 &&
    gen_valid_ssa_condition_value_block_is_supported(instrs[start]) {
    has_value_block = true
  } else {
    let mut i = start
    while i < end {
      match instrs[i] {
        LocalSet(_) | LocalTee(_) => has_write = true
        _ => ()
      }
      i += 1
    }
  }

  { has_condition_write: has_write, has_condition_value_block: has_value_block }
}

///|
fn gen_valid_ssa_find_supported_result_if_condition(
  instrs : Array[Instruction],
  if_idx : Int,
) -> (Int, Int, GenValidSsaConditionFacts)? {
  match gen_valid_ssa_condition_window_bounds(instrs, if_idx) {
    None => None
    Some((start, end)) =>
      if gen_valid_ssa_condition_window_is_supported(instrs, start, end) {
        Some(
          (
            start,
            end,
            gen_valid_ssa_condition_facts_from_window(instrs, start, end),
          ),
        )
      } else {
        None
      }
  }
}

///|
fn gen_valid_ssa_condition_is_supported(
  instrs : Array[Instruction],
  if_idx : Int,
) -> Bool {
  gen_valid_ssa_find_supported_result_if_condition(instrs, if_idx) is Some(_)
}

///|
fn gen_valid_ssa_slice_instrs(
  instrs : Array[Instruction],
  start : Int,
  end : Int,
) -> Array[Instruction] {
  let out : Array[Instruction] = []
  let mut i = start
  while i < end {
    out.push(instrs[i])
    i += 1
  }
  out
}

///|
fn gen_valid_ssa_arm_is_single_value_block_supported(
  body : Array[Instruction],
  result_vt : ValType,
) -> Bool {
  body.length() == 1 &&
  gen_valid_ssa_arm_value_block_is_supported(body[0], result_vt)
}

///|
fn gen_valid_ssa_arm_is_mixed_value_block_supported(
  body : Array[Instruction],
  result_vt : ValType,
) -> Bool {
  body.length() >= 2 &&
  gen_valid_ssa_arm_value_block_is_supported(body[body.length() - 1], result_vt) &&
  gen_valid_ssa_arm_region_is_supported(body, result_vt) &&
  !gen_valid_ssa_arm_is_single_value_block_supported(body, result_vt)
}

///|
fn gen_valid_ssa_dropped_result_if_is_supported(
  instrs : Array[Instruction],
  if_idx : Int,
  bt : BlockType,
  then_body : Array[Instruction],
  else_body : Array[Instruction],
) -> Bool {
  match gen_valid_ssa_blocktype_scalar_result(bt) {
    None => false
    Some(result_vt) =>
      gen_valid_ssa_condition_is_supported(instrs, if_idx) &&
      gen_valid_ssa_arm_region_is_supported(then_body, result_vt) &&
      gen_valid_ssa_arm_region_is_supported(else_body, result_vt)
  }
}

///|
fn gen_valid_ssa_scan_dropped_result_if(
  instrs : Array[Instruction],
  if_idx : Int,
  bt : BlockType,
  then_body : Array[Instruction],
  else_body : Array[Instruction],
  facts : GenValidSsaFuncFacts,
) -> GenValidSsaFuncFacts {
  if !gen_valid_ssa_dropped_result_if_is_supported(
      instrs, if_idx, bt, then_body, else_body,
    ) {
    return facts
  }
  match gen_valid_ssa_blocktype_scalar_result(bt) {
    None => facts
    Some(result_vt) => {
      let mut out = { ..facts, has_ssa_nested_result_if_supported_shape: true }
      if result_vt != ValType::i32() {
        out = { ..out, has_ssa_nested_result_if_scalar_result: true }
      }
      match gen_valid_ssa_find_supported_result_if_condition(instrs, if_idx) {
        Some((_, _, condition_facts)) => {
          if condition_facts.has_condition_write {
            out = { ..out, has_ssa_nested_result_if_condition_write: true }
          }
          if condition_facts.has_condition_value_block {
            out = {
              ..out,
              has_ssa_nested_result_if_condition_value_block: true,
            }
          }
        }
        None => ()
      }
      if gen_valid_ssa_arm_is_single_value_block_supported(then_body, result_vt) ||
        gen_valid_ssa_arm_is_single_value_block_supported(else_body, result_vt) {
        out = { ..out, has_ssa_nested_result_if_arm_value_block: true }
      }
      if gen_valid_ssa_arm_is_mixed_value_block_supported(then_body, result_vt) ||
        gen_valid_ssa_arm_is_mixed_value_block_supported(else_body, result_vt) {
        out = { ..out, has_ssa_nested_result_if_mixed_arm_value_block: true }
      }
      out
    }
  }
}

///|
fn gen_valid_ssa_tail_expr(instrs : Array[Instruction], start : Int) -> Expr {
  let tail_instrs : Array[Instruction] = []
  let mut j = start
  while j < instrs.length() {
    tail_instrs.push(instrs[j])
    j += 1
  }
  Expr::new(tail_instrs)
}

///|
fn gen_valid_ssa_scan_linear(
  param_count : Int,
  instrs : Array[Instruction],
  facts : GenValidSsaFuncFacts,
  def_counts : Array[Int],
  has_local_write_in : Bool,
  has_exceptional_in : Bool,
) -> GenValidSsaFuncFacts {
  let mut out = facts
  let mut has_local_write = has_local_write_in
  let mut has_exceptional = has_exceptional_in
  let last_tee : Array[Bool] = []
  let last_def : Array[Bool] = []
  for _ in 0..<GEN_VALID_SSA_LOCAL_CAP {
    last_tee.push(false)
    last_def.push(false)
  }
  let mut saw_unreachable_prefix = false
  let mut i = 0
  while i < instrs.length() {
    let instr = instrs[i]
    if gen_valid_ssa_func_has_exceptional(instr) {
      has_exceptional = true
    }
    match instr {
      Unreachable => saw_unreachable_prefix = true
      LocalSet(idx) | LocalTee(idx) => {
        has_local_write = true
        match gen_valid_ssa_local_slot(idx) {
          Some(slot) => {
            def_counts[slot] = def_counts[slot] + 1
            if def_counts[slot] >= 2 {
              out = { ..out, has_ssa_multi_def_same_local: true }
            }
            if slot < param_count {
              out = { ..out, has_ssa_param_write: true }
            }
            last_def[slot] = true
            if instr is LocalTee(_) {
              last_tee[slot] = true
            }
            if saw_unreachable_prefix {
              out = { ..out, has_ssa_unreachable_local_carrier: true }
            }
            if instr is LocalSet(_) {
              let tail = gen_valid_ssa_tail_expr(instrs, i + 1)
              if !gen_valid_expr_local_has_read(tail, idx) {
                out = { ..out, has_ssa_dead_local_set: true }
              }
            }
            if instr is LocalTee(_) {
              match instrs.get(i + 1) {
                Some(Drop) => {
                  let tail = gen_valid_ssa_tail_expr(instrs, i + 2)
                  if !gen_valid_expr_local_has_read(tail, idx) {
                    out = { ..out, has_ssa_dead_local_tee: true }
                  }
                }
                _ => ()
              }
            }
          }
          None => ()
        }
      }
      LocalGet(idx) =>
        match gen_valid_ssa_local_slot(idx) {
          Some(slot) => {
            if last_def[slot] {
              out = { ..out, has_ssa_straight_line_local_chain: true }
            }
            if last_tee[slot] {
              out = { ..out, has_ssa_local_tee_def_use: true }
            }
            if saw_unreachable_prefix {
              out = { ..out, has_ssa_unreachable_local_carrier: true }
            }
          }
          None => ()
        }
      Drop =>
        if i > 0 {
          match instrs[i - 1] {
            If(bt, then_body, Some(else_body)) =>
              out = gen_valid_ssa_scan_dropped_result_if(
                instrs,
                i - 1,
                bt,
                then_body,
                else_body,
                out,
              )
            Block(ValTypeBlockType(_), body)
            | Block(TypeIdxBlockType(_), body) =>
              if gen_valid_ssa_func_has_local_write(body) {
                out = { ..out, has_ssa_nested_cfg_fail_closed_shape: true }
              }
            _ => ()
          }
        }
      Block(_, body) => {
        let tail = gen_valid_ssa_tail_expr(instrs, i + 1)
        let body_has_write = gen_valid_ssa_func_has_local_write(body)
        let tail_has_read = gen_valid_ssa_expr_has_local_read(tail)
        if body_has_write && tail_has_read && gen_valid_ssa_expr_has_br(body) {
          out = { ..out, has_ssa_block_branch_merge_copy: true }
        }
        if body_has_write && tail_has_read && gen_valid_ssa_expr_has_br_if(body) {
          out = { ..out, has_ssa_block_br_if_merge_copy: true }
        }
        let (body_facts, body_writes, body_exceptional) = gen_valid_ssa_scan_expr(
          param_count, body, out, def_counts, has_local_write, has_exceptional,
        )
        out = body_facts
        has_local_write = has_local_write || body_writes
        has_exceptional = has_exceptional || body_exceptional
        if gen_valid_ssa_expr_has_unreachable(body) {
          saw_unreachable_prefix = true
        }
      }
      TryTable(_, _, body) => {
        let (body_facts, body_writes, _) = gen_valid_ssa_scan_expr(
          param_count, body, out, def_counts, has_local_write, true,
        )
        out = body_facts
        has_local_write = has_local_write || body_writes
        has_exceptional = true
        if gen_valid_ssa_expr_has_unreachable(body) {
          saw_unreachable_prefix = true
        }
      }
      Loop(bt, body) => {
        let loop_facts = gen_valid_ssa_scan_loop(
          param_count, bt, body, def_counts, has_local_write, has_exceptional,
        )
        out = gen_valid_merge_ssa_func_facts(out, loop_facts)
      }
      If(_, then_body, else_body) => {
        let (then_facts, then_writes, then_exceptional) = gen_valid_ssa_scan_if_arm(
          param_count, then_body, def_counts, has_local_write, has_exceptional,
        )
        let (else_facts, else_writes, else_exceptional) = match else_body {
          Some(body) =>
            gen_valid_ssa_scan_if_arm(
              param_count, body, def_counts, has_local_write, has_exceptional,
            )
          None => (GenValidSsaFuncFacts::empty(), false, false)
        }
        out = gen_valid_merge_ssa_func_facts(out, then_facts)
        out = gen_valid_merge_ssa_func_facts(out, else_facts)
        let tail = gen_valid_ssa_tail_expr(instrs, i + 1)
        let else_has_return = match else_body {
          Some(body) => gen_valid_ssa_expr_has_return(Expr::new(body))
          None => false
        }
        let has_arm_return = gen_valid_ssa_expr_has_return(Expr::new(then_body)) ||
          else_has_return
        if (then_writes || else_writes) &&
          has_arm_return &&
          gen_valid_ssa_expr_has_local_read(tail) {
          out = { ..out, has_ssa_structured_early_return_local: true }
        }
        if then_writes || else_writes || then_exceptional || else_exceptional {
          has_local_write = has_local_write || then_writes || else_writes
          has_exceptional = has_exceptional ||
            then_exceptional ||
            else_exceptional
        }
        out = gen_valid_ssa_scan_if_join(
          param_count, then_body, else_body, tail, out,
        )
      }
      BrTable(_, _) => {
        let tail = gen_valid_ssa_tail_expr(instrs, i + 1)
        if has_local_write && gen_valid_ssa_expr_has_local_read(tail) {
          out = { ..out, has_ssa_br_table_phi_candidate: true }
        }
      }
      _ => ()
    }
    if has_local_write && i + 3 < instrs.length() {
      match (instrs[i], instrs[i + 1], instrs[i + 2], instrs[i + 3]) {
        (LocalGet(_), I32Const(_), I32Add, Drop) =>
          out = { ..out, has_ssa_dropped_increment_guard_shape: true }
        (I32Const(_), LocalGet(_), I32Add, Drop) =>
          out = { ..out, has_ssa_dropped_increment_reversed_boundary: true }
        _ => ()
      }
    }
    i += 1
  }
  if has_exceptional && has_local_write {
    out = { ..out, has_ssa_exceptional_fail_closed_shape: true }
  }
  out
}

///|
fn gen_valid_ssa_expr_has_local_read(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      LocalGet(_) | LocalTee(_) => return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if gen_valid_ssa_expr_has_local_read(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_ssa_expr_has_local_read(Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_ssa_expr_has_local_read(Expr::new(body)) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_ssa_scan_if_arm(
  param_count : Int,
  body : Array[Instruction],
  def_counts : Array[Int],
  has_local_write : Bool,
  has_exceptional : Bool,
) -> (GenValidSsaFuncFacts, Bool, Bool) {
  let facts = gen_valid_ssa_scan_linear(
    param_count,
    body,
    GenValidSsaFuncFacts::empty(),
    def_counts,
    has_local_write,
    has_exceptional,
  )
  (
    facts,
    gen_valid_ssa_func_has_local_write(Expr::new(body)),
    gen_valid_ssa_expr_has_exceptional(Expr::new(body)),
  )
}

///|
fn gen_valid_ssa_if_arm_writes_local(body : Array[Instruction]) -> Array[Int] {
  let written : Array[Int] = []
  let Expr(instrs) = Expr::new(body)
  for instr in instrs {
    match instr {
      LocalSet(idx) | LocalTee(idx) =>
        match gen_valid_ssa_local_slot(idx) {
          Some(slot) => {
            let mut seen = false
            for existing in written {
              if existing == slot {
                seen = true
              }
            }
            if !seen {
              written.push(slot)
            }
          }
          None => ()
        }
      _ => ()
    }
  }
  written
}

///|
fn gen_valid_ssa_scan_if_join(
  param_count : Int,
  then_body : Array[Instruction],
  else_body : Array[Instruction]?,
  tail : Expr,
  facts : GenValidSsaFuncFacts,
) -> GenValidSsaFuncFacts {
  let then_writes = gen_valid_ssa_if_arm_writes_local(then_body)
  let else_writes = match else_body {
    Some(body) => gen_valid_ssa_if_arm_writes_local(body)
    None => []
  }
  let mut out = facts
  let mut any_write = false
  let mut both_arms_write = false
  for slot in then_writes {
    any_write = true
    let idx = LocalIdx::new(slot.reinterpret_as_uint())
    if gen_valid_expr_local_has_read(tail, idx) {
      out = { ..out, has_ssa_if_join_phi_candidate: true }
      if slot < param_count {
        out = { ..out, has_ssa_structured_param_merge: true }
      }
    } else {
      out = { ..out, has_ssa_branch_local_not_read_later: true }
    }
    for other in else_writes {
      if other == slot {
        both_arms_write = true
      }
    }
  }
  for slot in else_writes {
    any_write = true
    let idx = LocalIdx::new(slot.reinterpret_as_uint())
    if gen_valid_expr_local_has_read(tail, idx) {
      out = { ..out, has_ssa_if_join_phi_candidate: true }
      if slot < param_count {
        out = { ..out, has_ssa_structured_param_merge: true }
      }
    } else {
      out = { ..out, has_ssa_branch_local_not_read_later: true }
    }
  }
  if any_write {
    for slot in then_writes {
      let idx = LocalIdx::new(slot.reinterpret_as_uint())
      let in_else = else_writes.any(fn(other) { other == slot })
      if !in_else && gen_valid_expr_local_has_read(tail, idx) {
        out = { ..out, has_ssa_default_local_merge: true }
      }
    }
    for slot in else_writes {
      let idx = LocalIdx::new(slot.reinterpret_as_uint())
      let in_then = then_writes.any(fn(other) { other == slot })
      if !in_then && gen_valid_expr_local_has_read(tail, idx) {
        out = { ..out, has_ssa_default_local_merge: true }
      }
    }
    if then_writes.length() >= 2 && else_writes.length() >= 2 {
      let mut read0 = false
      let mut read1 = false
      for slot in [then_writes[0], else_writes[0]] {
        let idx = LocalIdx::new(slot.reinterpret_as_uint())
        if gen_valid_expr_local_has_read(tail, idx) {
          read0 = true
        }
      }
      if then_writes.length() > 1 && else_writes.length() > 1 {
        for slot in [then_writes[1], else_writes[1]] {
          let idx = LocalIdx::new(slot.reinterpret_as_uint())
          if gen_valid_expr_local_has_read(tail, idx) {
            read1 = true
          }
        }
      }
      if read0 && read1 {
        out = { ..out, has_ssa_parallel_copy_candidate: true }
      }
    }
    if both_arms_write && then_writes.length() >= 2 && else_writes.length() >= 2 {
      out = { ..out, has_ssa_parallel_copy_cycle_candidate: true }
    }
  }
  out
}

///|
fn gen_valid_ssa_scan_loop(
  param_count : Int,
  bt : BlockType,
  body : Expr,
  def_counts : Array[Int],
  has_local_write : Bool,
  has_exceptional : Bool,
) -> GenValidSsaFuncFacts {
  let Expr(instrs) = body
  let mut out = gen_valid_ssa_scan_linear(
    param_count,
    instrs,
    GenValidSsaFuncFacts::empty(),
    def_counts,
    has_local_write,
    has_exceptional,
  )
  let has_backedge = gen_valid_ssa_loop_has_backedge(body)
  let has_local_traffic = gen_valid_ssa_func_has_local_write(body) ||
    gen_valid_ssa_expr_has_local_read(body)
  if has_backedge && has_local_traffic {
    out = { ..out, has_ssa_loop_backedge_phi_candidate: true }
  }
  if gen_valid_ssa_blocktype_is_typed_loop(bt) && has_local_traffic {
    out = { ..out, has_ssa_typed_loop_param_fail_closed_shape: true }
  }
  out
}

///|
fn gen_valid_ssa_loop_has_backedge(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      Br(LabelIdx(idx)) | BrIf(LabelIdx(idx)) if idx == 0U => return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if gen_valid_ssa_loop_has_backedge(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_ssa_loop_has_backedge(Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_ssa_loop_has_backedge(Expr::new(body)) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_ssa_scan_expr(
  param_count : Int,
  expr : Expr,
  facts : GenValidSsaFuncFacts,
  def_counts : Array[Int],
  has_local_write : Bool,
  has_exceptional : Bool,
) -> (GenValidSsaFuncFacts, Bool, Bool) {
  let Expr(instrs) = expr
  let scanned = gen_valid_ssa_scan_linear(
    param_count, instrs, facts, def_counts, has_local_write, has_exceptional,
  )
  (
    scanned,
    has_local_write || gen_valid_ssa_func_has_local_write(expr),
    has_exceptional || gen_valid_ssa_expr_has_exceptional(expr),
  )
}

///|
fn gen_valid_ssa_expr_has_unreachable(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      Unreachable => return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if gen_valid_ssa_expr_has_unreachable(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_ssa_expr_has_unreachable(Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_ssa_expr_has_unreachable(Expr::new(body)) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_ssa_expr_has_br_table(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      BrTable(_, _) => return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if gen_valid_ssa_expr_has_br_table(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_ssa_expr_has_br_table(Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_ssa_expr_has_br_table(Expr::new(body)) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_ssa_expr_has_br(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      Br(_) => return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if gen_valid_ssa_expr_has_br(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_ssa_expr_has_br(Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_ssa_expr_has_br(Expr::new(body)) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_ssa_expr_has_br_if(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      BrIf(_) => return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if gen_valid_ssa_expr_has_br_if(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_ssa_expr_has_br_if(Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_ssa_expr_has_br_if(Expr::new(body)) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_ssa_expr_has_return(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      Return | ReturnCall(_) | ReturnCallIndirect(_, _) | ReturnCallRef(_) =>
        return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if gen_valid_ssa_expr_has_return(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_ssa_expr_has_return(Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_ssa_expr_has_return(Expr::new(body)) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
pub fn gen_valid_scan_func_ssa_facts(
  param_count : Int,
  _locals : Locals,
  expr : Expr,
) -> GenValidSsaFuncFacts {
  let def_counts : Array[Int] = []
  for _ in 0..<GEN_VALID_SSA_LOCAL_CAP {
    def_counts.push(0)
  }
  let mut out = gen_valid_ssa_scan_linear(
    param_count,
    match expr {
      Expr(instrs) => instrs
    },
    GenValidSsaFuncFacts::empty(),
    def_counts,
    false,
    false,
  )
  if gen_valid_ssa_expr_has_br_table(expr) &&
    gen_valid_ssa_func_has_local_write(expr) &&
    gen_valid_ssa_expr_has_local_read(expr) {
    out = { ..out, has_ssa_br_table_phi_candidate: true }
  }
  if gen_valid_ssa_expr_has_unreachable(expr) &&
    gen_valid_ssa_func_has_local_write(expr) &&
    gen_valid_ssa_expr_has_local_read(expr) {
    out = { ..out, has_ssa_unreachable_local_carrier: true }
  }
  out
}

///|
fn gen_valid_ssa_body_local(param_count : Int, body_idx : Int) -> LocalIdx {
  LocalIdx::new((param_count + body_idx).reinterpret_as_uint())
}

///|
fn gen_valid_append_ssa_nomerge_body_slice(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  accepts : Array[ValType],
) -> Unit {
  if !ctx.config.features.allow_ssa_nomerge_body_generator {
    return
  }
  if gen_valid_is_ssa_nomerge_smoke_config(ctx.config) {
    gen_valid_append_ssa_nomerge_smoke_body_slice(out, ctx, env, accepts)
  } else if gen_valid_is_ssa_nomerge_parity_config(ctx.config) {
    gen_valid_append_ssa_nomerge_parity_body_slice(out, ctx, env, accepts)
  } else {
    gen_valid_append_ssa_nomerge_coverage_body_slice(out, ctx, env, accepts)
  }
}

///|
fn gen_valid_append_ssa_nomerge_parity_body_slice(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  accepts : Array[ValType],
) -> Unit {
  let param_count = accepts.length()
  let l0 = gen_valid_ssa_body_local(param_count, 0)
  let p0 = LocalIdx::new(0U)
  // A. straight-line multi-def same local
  out.push(Instruction::i32_const(I32(1)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  out.push(Instruction::i32_const(I32(2)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // B. local.tee def-use chain
  out.push(Instruction::i32_const(I32(7)))
  out.push(Instruction::local_tee(l0))
  out.push(Instruction::drop())
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // C. parameter write when available
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::i32_const(I32(9)))
    out.push(Instruction::local_set(p0))
    out.push(Instruction::local_get(p0))
    out.push(Instruction::drop())
  }
  // D. if-join phi candidate
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [Instruction::i32_const(I32(1)), Instruction::local_set(l0)],
      Some([Instruction::i32_const(I32(2)), Instruction::local_set(l0)]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // E. one-arm default merge
  out.push(Instruction::local_get(l0))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [Instruction::i32_const(I32(7)), Instruction::local_set(l0)],
      None,
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  ignore(ctx)
  ignore(env)
}

///|
fn gen_valid_append_ssa_nomerge_smoke_body_slice(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  accepts : Array[ValType],
) -> Unit {
  let param_count = accepts.length()
  let l0 = gen_valid_ssa_body_local(param_count, 0)
  let l1 = gen_valid_ssa_body_local(param_count, 1)
  let l2 = gen_valid_ssa_body_local(param_count, 2)
  let p0 = LocalIdx::new(0U)
  // A. straight-line multi-def same local
  out.push(Instruction::i32_const(I32(1)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  out.push(Instruction::i32_const(I32(2)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // B. local.tee def-use chain
  out.push(Instruction::i32_const(I32(7)))
  out.push(Instruction::local_tee(l0))
  out.push(Instruction::drop())
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // C. parameter write when available
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::i32_const(I32(9)))
    out.push(Instruction::local_set(p0))
    out.push(Instruction::local_get(p0))
    out.push(Instruction::drop())
  }
  // D. if-join phi candidate
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [Instruction::i32_const(I32(1)), Instruction::local_set(l0)],
      Some([Instruction::i32_const(I32(2)), Instruction::local_set(l0)]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // E. one-arm default merge
  out.push(Instruction::local_get(l0))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [Instruction::i32_const(I32(7)), Instruction::local_set(l0)],
      None,
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // F. structured early-return local traffic with a fallthrough read.
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::local_get(p0))
    out.push(
      Instruction::if_(
        BlockType::void_(),
        [
          Instruction::i32_const(I32(7)),
          Instruction::local_set(l0),
          Instruction::return_(),
        ],
        Some([Instruction::i32_const(I32(9)), Instruction::local_set(l0)]),
      ),
    )
    out.push(Instruction::local_get(l0))
    out.push(Instruction::drop())
  }
  // G. block-target branch copy candidate.
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::local_set(l0))
    out.push(
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::local_get(p0),
          Instruction::if_(
            BlockType::void_(),
            [
              Instruction::i32_const(I32(7)),
              Instruction::local_set(l0),
              Instruction::br(LabelIdx::new(1U)),
            ],
            None,
          ),
          Instruction::i32_const(I32(9)),
          Instruction::local_set(l0),
        ]),
      ),
    )
    out.push(Instruction::local_get(l0))
    out.push(Instruction::drop())
  }
  // H. block-target br_if merge candidate.
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::i32_const(I32(7)))
    out.push(Instruction::local_set(l0))
    out.push(
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::local_get(p0),
          Instruction::br_if(LabelIdx::new(0U)),
          Instruction::i32_const(I32(9)),
          Instruction::local_set(l0),
        ]),
      ),
    )
    out.push(Instruction::local_get(l0))
    out.push(Instruction::drop())
  }
  // I. typed result-if writing a param and reading it after the merge.
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::local_get(p0))
    out.push(
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::i32_const(I32(7)),
          Instruction::local_set(p0),
          Instruction::i32_const(I32(1)),
        ],
        Some([
          Instruction::i32_const(I32(9)),
          Instruction::local_set(p0),
          Instruction::i32_const(I32(2)),
        ]),
      ),
    )
    out.push(Instruction::drop())
    out.push(Instruction::local_get(p0))
    out.push(Instruction::drop())
  }
  // J. branch-local writes that are intentionally not read later.
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::local_get(p0))
    out.push(
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::i32_const(I32(20)),
          Instruction::local_set(l1),
          Instruction::i32_const(I32(2)),
        ],
        Some([
          Instruction::i32_const(I32(30)),
          Instruction::local_set(l2),
          Instruction::i32_const(I32(3)),
        ]),
      ),
    )
    out.push(Instruction::drop())
  }
  ignore(ctx)
  ignore(env)
}

///|
fn gen_valid_append_ssa_nomerge_coverage_body_slice(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  accepts : Array[ValType],
) -> Unit {
  let param_count = accepts.length()
  let l0 = gen_valid_ssa_body_local(param_count, 0)
  let l1 = gen_valid_ssa_body_local(param_count, 1)
  let p0 = LocalIdx::new(0U)
  // A. straight-line multi-def same local
  out.push(Instruction::i32_const(I32(1)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  out.push(Instruction::i32_const(I32(2)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // B. local.tee def-use chain
  out.push(Instruction::i32_const(I32(7)))
  out.push(Instruction::local_tee(l0))
  out.push(Instruction::drop())
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // C. parameter write when available
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::i32_const(I32(9)))
    out.push(Instruction::local_set(p0))
    out.push(Instruction::local_get(p0))
    out.push(Instruction::drop())
  }
  // D. if-join phi candidate
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [Instruction::i32_const(I32(1)), Instruction::local_set(l0)],
      Some([Instruction::i32_const(I32(2)), Instruction::local_set(l0)]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // E. one-arm default merge
  out.push(Instruction::local_get(l0))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [Instruction::i32_const(I32(7)), Instruction::local_set(l0)],
      None,
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // F. loop backedge phi candidate
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::local_set(l0))
  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::loop_(
          BlockType::void_(),
          Expr::new([
            Instruction::local_get(l0),
            Instruction::drop(),
            Instruction::i32_const(I32(1)),
            Instruction::local_set(l0),
            Instruction::local_get(l0),
            Instruction::br_if(LabelIdx::new(0U)),
          ]),
        ),
      ]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // G. typed loop-param/backedge fail-closed candidate.
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::local_set(l0))
    out.push(Instruction::local_get(p0))
    out.push(
      Instruction::loop_(
        BlockType::type_idx(TypeIdx::new(0U)),
        Expr::new([
          Instruction::drop(),
          Instruction::i32_const(I32(1)),
          Instruction::local_set(l0),
          Instruction::local_get(l0),
          Instruction::br(LabelIdx::new(0U)),
        ]),
      ),
    )
    out.push(Instruction::local_get(l0))
    out.push(Instruction::drop())
  }
  // H. exceptional-flow fail-closed candidate.
  out.push(
    Instruction::try_table(
      BlockType::void_(),
      [Catch::all(LabelIdx::new(0U))],
      Expr::new([
        Instruction::i32_const(I32(42)),
        Instruction::local_set(l0),
        Instruction::ref_null(HeapType::abs(AbsHeapType::exn())),
        Instruction::throw_ref(),
      ]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // I. br-to-outer-block copy candidate
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::local_set(l0))
  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::i32_const(I32(7)),
        Instruction::local_set(l0),
        Instruction::br(LabelIdx::new(0U)),
      ]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // H. br_table multi-predecessor candidate
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::local_set(l0))
  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::i32_const(I32(1)),
        Instruction::local_set(l0),
        Instruction::i32_const(I32(0)),
        Instruction::br_table([LabelIdx::new(0U)], LabelIdx::new(0U)),
      ]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // I. parallel-copy candidate
  out.push(Instruction::i32_const(I32(1)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::i32_const(I32(2)))
  out.push(Instruction::local_set(l1))
  out.push(Instruction::local_get(l0))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [
        Instruction::local_get(l1),
        Instruction::local_set(l0),
        Instruction::local_get(l0),
        Instruction::local_set(l1),
      ],
      Some([
        Instruction::local_get(l0),
        Instruction::local_set(l1),
        Instruction::local_get(l1),
        Instruction::local_set(l0),
      ]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  out.push(Instruction::local_get(l1))
  out.push(Instruction::drop())
  // J. parallel-copy cycle candidate (stricter swap)
  out.push(Instruction::i32_const(I32(3)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::i32_const(I32(4)))
  out.push(Instruction::local_set(l1))
  out.push(Instruction::local_get(l0))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [
        Instruction::local_get(l1),
        Instruction::local_set(l0),
        Instruction::local_get(l0),
        Instruction::local_set(l1),
      ],
      Some([
        Instruction::local_get(l1),
        Instruction::local_set(l0),
        Instruction::local_get(l0),
        Instruction::local_set(l1),
      ]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  out.push(Instruction::local_get(l1))
  out.push(Instruction::drop())
  // K. unreachable local carrier
  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([Instruction::unreachable_()]),
    ),
  )
  out.push(Instruction::i32_const(I32(7)))
  out.push(Instruction::local_tee(l0))
  out.push(Instruction::drop())
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // L. dropped increment guarded shape
  out.push(Instruction::i32_const(I32(10)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(Instruction::i32_const(I32(1)))
  out.push(Instruction::i32_add())
  out.push(Instruction::drop())
  // M. dropped increment reversed boundary
  out.push(Instruction::i32_const(I32(10)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::i32_const(I32(1)))
  out.push(Instruction::local_get(l0))
  out.push(Instruction::i32_add())
  out.push(Instruction::drop())
  // N. nested CFG fail-closed shape
  out.push(
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new([
        Instruction::i32_const(I32(7)),
        Instruction::local_set(l0),
        Instruction::local_get(l0),
      ]),
    ),
  )
  out.push(Instruction::drop())
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // O. nested result-if straight-line arms (i32)
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::local_get(p0))
    out.push(
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::i32_const(I32(7)),
          Instruction::local_set(l0),
          Instruction::local_get(l0),
        ],
        Some([
          Instruction::i32_const(I32(9)),
          Instruction::local_set(l0),
          Instruction::local_get(l0),
        ]),
      ),
    )
    out.push(Instruction::drop())
    out.push(Instruction::local_get(l0))
    out.push(Instruction::drop())
  }
  // P–R. nested result-if scalar variants (i64/f32/f64)
  gen_valid_append_ssa_nested_result_if_scalar_variants(out, param_count, env)
  // S. nested result-if condition local write
  out.push(Instruction::i32_const(I32(1)))
  out.push(Instruction::local_tee(l0))
  out.push(
    Instruction::if_(
      BlockType::val_type(ValType::i32()),
      [
        Instruction::i32_const(I32(7)),
        Instruction::local_set(l0),
        Instruction::local_get(l0),
      ],
      Some([
        Instruction::i32_const(I32(9)),
        Instruction::local_set(l0),
        Instruction::local_get(l0),
      ]),
    ),
  )
  out.push(Instruction::drop())
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // T. nested result-if condition value-block
  out.push(
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new([
        Instruction::i32_const(I32(1)),
        Instruction::local_set(l0),
        Instruction::local_get(l0),
      ]),
    ),
  )
  out.push(
    Instruction::if_(
      BlockType::val_type(ValType::i32()),
      [
        Instruction::i32_const(I32(7)),
        Instruction::local_set(l0),
        Instruction::local_get(l0),
      ],
      Some([
        Instruction::i32_const(I32(9)),
        Instruction::local_set(l0),
        Instruction::local_get(l0),
      ]),
    ),
  )
  out.push(Instruction::drop())
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // U. nested result-if arm value-blocks
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::local_get(p0))
    out.push(
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::block(
            BlockType::val_type(ValType::i32()),
            Expr::new([
              Instruction::i32_const(I32(7)),
              Instruction::local_set(l0),
              Instruction::local_get(l0),
            ]),
          ),
        ],
        Some([
          Instruction::block(
            BlockType::val_type(ValType::i32()),
            Expr::new([
              Instruction::i32_const(I32(9)),
              Instruction::local_set(l0),
              Instruction::local_get(l0),
            ]),
          ),
        ]),
      ),
    )
    out.push(Instruction::drop())
    out.push(Instruction::local_get(l0))
    out.push(Instruction::drop())
  }
  // V. nested result-if mixed arm roots
  let l2 = gen_valid_ssa_body_local(param_count, 2)
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::local_get(p0))
    out.push(
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::i32_const(I32(1)),
          Instruction::local_set(l0),
          Instruction::block(
            BlockType::val_type(ValType::i32()),
            Expr::new([
              Instruction::i32_const(I32(7)),
              Instruction::local_set(l1),
              Instruction::local_get(l1),
            ]),
          ),
        ],
        Some([
          Instruction::i32_const(I32(2)),
          Instruction::local_set(l0),
          Instruction::block(
            BlockType::val_type(ValType::i32()),
            Expr::new([
              Instruction::i32_const(I32(9)),
              Instruction::local_set(l1),
              Instruction::local_get(l1),
            ]),
          ),
        ]),
      ),
    )
    out.push(Instruction::drop())
    out.push(Instruction::local_get(l0))
    out.push(Instruction::drop())
    out.push(Instruction::local_get(l1))
    out.push(Instruction::drop())
  }
  // W. nested result-if combined condition value-block + mixed arm roots
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(
      Instruction::block(
        BlockType::val_type(ValType::i32()),
        Expr::new([
          Instruction::i32_const(I32(1)),
          Instruction::local_set(l0),
          Instruction::local_get(l0),
        ]),
      ),
    )
    out.push(
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::i32_const(I32(4)),
          Instruction::local_set(l1),
          Instruction::block(
            BlockType::val_type(ValType::i32()),
            Expr::new([
              Instruction::i32_const(I32(7)),
              Instruction::local_set(l2),
              Instruction::local_get(l2),
            ]),
          ),
        ],
        Some([
          Instruction::i32_const(I32(5)),
          Instruction::local_set(l1),
          Instruction::block(
            BlockType::val_type(ValType::i32()),
            Expr::new([
              Instruction::i32_const(I32(9)),
              Instruction::local_set(l2),
              Instruction::local_get(l2),
            ]),
          ),
        ]),
      ),
    )
    out.push(Instruction::drop())
    out.push(Instruction::local_get(l0))
    out.push(Instruction::drop())
    out.push(Instruction::local_get(l1))
    out.push(Instruction::drop())
    out.push(Instruction::local_get(l2))
    out.push(Instruction::drop())
  }
  // X. structured early-return local traffic with a fallthrough read.
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::local_get(p0))
    out.push(
      Instruction::if_(
        BlockType::void_(),
        [
          Instruction::i32_const(I32(7)),
          Instruction::local_set(l0),
          Instruction::return_(),
        ],
        Some([Instruction::i32_const(I32(9)), Instruction::local_set(l0)]),
      ),
    )
    out.push(Instruction::local_get(l0))
    out.push(Instruction::drop())
  }
  // Y. block-target branch copy candidate.
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::local_set(l0))
    out.push(
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::local_get(p0),
          Instruction::if_(
            BlockType::void_(),
            [
              Instruction::i32_const(I32(7)),
              Instruction::local_set(l0),
              Instruction::br(LabelIdx::new(1U)),
            ],
            None,
          ),
          Instruction::i32_const(I32(9)),
          Instruction::local_set(l0),
        ]),
      ),
    )
    out.push(Instruction::local_get(l0))
    out.push(Instruction::drop())
  }
  // Z. block-target br_if merge candidate.
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::i32_const(I32(7)))
    out.push(Instruction::local_set(l0))
    out.push(
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::local_get(p0),
          Instruction::br_if(LabelIdx::new(0U)),
          Instruction::i32_const(I32(9)),
          Instruction::local_set(l0),
        ]),
      ),
    )
    out.push(Instruction::local_get(l0))
    out.push(Instruction::drop())
  }
  // AA. typed result-if writing a param and reading it after the merge.
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::local_get(p0))
    out.push(
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::i32_const(I32(7)),
          Instruction::local_set(p0),
          Instruction::i32_const(I32(1)),
        ],
        Some([
          Instruction::i32_const(I32(9)),
          Instruction::local_set(p0),
          Instruction::i32_const(I32(2)),
        ]),
      ),
    )
    out.push(Instruction::drop())
    out.push(Instruction::local_get(p0))
    out.push(Instruction::drop())
  }
  // AB. branch-local writes that are intentionally not read later.
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::local_get(p0))
    out.push(
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::i32_const(I32(20)),
          Instruction::local_set(l1),
          Instruction::i32_const(I32(2)),
        ],
        Some([
          Instruction::i32_const(I32(30)),
          Instruction::local_set(l2),
          Instruction::i32_const(I32(3)),
        ]),
      ),
    )
    out.push(Instruction::drop())
  }
  ignore(ctx)
  ignore(env)
}

///|
fn gen_valid_ssa_first_body_local_of_type(
  param_count : Int,
  local_types : Array[ValType],
  vt : ValType,
) -> LocalIdx? {
  let mut i = param_count
  while i < local_types.length() {
    if local_types[i] == vt {
      return Some(LocalIdx::new(i.reinterpret_as_uint()))
    }
    i += 1
  }
  None
}

///|
fn gen_valid_append_ssa_nested_result_if_scalar_variants(
  out : Array[Instruction],
  param_count : Int,
  env : GenValidBodyEnv,
) -> Unit {
  for result_vt in [ValType::i64(), ValType::f32(), ValType::f64()] {
    match
      gen_valid_ssa_first_body_local_of_type(
        param_count,
        env.local_types,
        result_vt,
      ) {
      Some(local_idx) => {
        let (then_const, else_const) = if result_vt == ValType::i64() {
          (Instruction::i64_const(I64(7L)), Instruction::i64_const(I64(9L)))
        } else if result_vt == ValType::f32() {
          (Instruction::f32_const(F32(7.0)), Instruction::f32_const(F32(9.0)))
        } else if result_vt == ValType::f64() {
          (Instruction::f64_const(F64(7.0)), Instruction::f64_const(F64(9.0)))
        } else {
          continue
        }
        out.push(Instruction::i32_const(I32(1)))
        out.push(
          Instruction::if_(
            BlockType::val_type(result_vt),
            [
              then_const,
              Instruction::local_set(local_idx),
              Instruction::local_get(local_idx),
            ],
            Some([
              else_const,
              Instruction::local_set(local_idx),
              Instruction::local_get(local_idx),
            ]),
          ),
        )
        out.push(Instruction::drop())
        out.push(Instruction::local_get(local_idx))
        out.push(Instruction::drop())
      }
      None => ()
    }
  }
}
