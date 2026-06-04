///|
pub fn local_cse_summary() -> String {
  "Reuse repeated local expression trees through fresh temp locals."
}

///|
pub fn local_cse_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "local-cse",
    requires=[@ir.HotAnalysis::effects()],
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
priv struct LcseRawRewrite {
  func : @lib.Func
  changed : Bool
}

///|
priv struct LcseRawExpr {
  start : Int
  end : Int
  instr : @lib.Instruction
  key : Int
  ty : @lib.ValType
  size : Int
  children : Array[Int]
  reads_locals : Array[Int]
  reads_memory : Bool
  mut repeat_of : Int
  mut local_id : Int
}

///|
priv struct LcseRawNestedRepeat {
  parent_idx : Int
  start : Int
  end : Int
  original : Int
}

///|
priv struct LcseRawCallInfo {
  params : Array[@lib.ValType]
  result : @lib.ValType?
  idempotent : Bool
}

///|
fn lcse_candidate_op_id(instr : @lib.Instruction) -> Int {
  match instr {
    @lib.Instruction::I32Add => 1
    @lib.Instruction::I32Sub => 2
    @lib.Instruction::I32Mul => 3
    @lib.Instruction::I64Add => 4
    @lib.Instruction::I64Sub => 5
    @lib.Instruction::I64Mul => 6
    @lib.Instruction::I32Eqz => 7
    @lib.Instruction::I64Eqz => 8
    @lib.Instruction::I32Eq => 9
    @lib.Instruction::I32Ne => 10
    @lib.Instruction::I64Eq => 11
    @lib.Instruction::I64Ne => 12
    @lib.Instruction::I32Load(_) => 13
    @lib.Instruction::I64Load(_) => 14
    @lib.Instruction::F32Load(_) => 15
    @lib.Instruction::F64Load(_) => 16
    @lib.Instruction::Select(_) => 17
    @lib.Instruction::Call(_) => 18
    _ => -1
  }
}

///|
fn lcse_instrs_may_have_repeated_candidate_with_seen(
  instrs : Array[@lib.Instruction],
  seen : @bitset.BitSet,
) -> Bool {
  for instr in instrs {
    let id = lcse_candidate_op_id(instr)
    if id >= 0 {
      if seen[id] {
        return true
      }
      seen[id] = true
    }
    match instr {
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        if lcse_instrs_may_have_repeated_candidate_with_seen(body, seen) {
          return true
        }
      @lib.Instruction::If(_, then_body, Some(else_body)) =>
        if lcse_instrs_may_have_repeated_candidate_with_seen(then_body, seen) ||
          lcse_instrs_may_have_repeated_candidate_with_seen(else_body, seen) {
          return true
        }
      @lib.Instruction::If(_, then_body, None) =>
        if lcse_instrs_may_have_repeated_candidate_with_seen(then_body, seen) {
          return true
        }
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        if lcse_instrs_may_have_repeated_candidate_with_seen(body, seen) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn lcse_instrs_may_have_repeated_candidate(
  instrs : Array[@lib.Instruction],
) -> Bool {
  lcse_instrs_may_have_repeated_candidate_with_seen(
    instrs,
    @bitset.BitSet::new(64),
  )
}

///|
fn lcse_instr_is_load(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Instruction::I32Load(_)
    | @lib.Instruction::I32Load8S(_)
    | @lib.Instruction::I32Load8U(_)
    | @lib.Instruction::I32Load16S(_)
    | @lib.Instruction::I32Load16U(_)
    | @lib.Instruction::I64Load(_)
    | @lib.Instruction::I64Load8S(_)
    | @lib.Instruction::I64Load8U(_)
    | @lib.Instruction::I64Load16S(_)
    | @lib.Instruction::I64Load16U(_)
    | @lib.Instruction::I64Load32S(_)
    | @lib.Instruction::I64Load32U(_)
    | @lib.Instruction::F32Load(_)
    | @lib.Instruction::F64Load(_) => true
    _ => false
  }
}

///|
fn lcse_instr_is_store(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Instruction::I32Store(_)
    | @lib.Instruction::I32Store8(_)
    | @lib.Instruction::I32Store16(_)
    | @lib.Instruction::I64Store(_)
    | @lib.Instruction::I64Store8(_)
    | @lib.Instruction::I64Store16(_)
    | @lib.Instruction::I64Store32(_)
    | @lib.Instruction::F32Store(_)
    | @lib.Instruction::F64Store(_) => true
    _ => false
  }
}

///|
fn lcse_raw_func_idx_raw(idx : @lib.FuncIdx) -> Int {
  let @lib.FuncIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn lcse_raw_call_info(
  call_infos : Array[LcseRawCallInfo],
  idx : @lib.FuncIdx,
) -> LcseRawCallInfo? {
  call_infos.get(lcse_raw_func_idx_raw(idx))
}

///|
fn lcse_raw_call_is_idempotent(
  call_infos : Array[LcseRawCallInfo],
  idx : @lib.FuncIdx,
) -> Bool {
  match lcse_raw_call_info(call_infos, idx) {
    Some(info) => info.idempotent
    None => false
  }
}

///|
fn lcse_raw_instr_operand_count(
  instr : @lib.Instruction,
  call_infos : Array[LcseRawCallInfo],
  subtypes : Array[@lib.SubType],
) -> Int? {
  match instr {
    @lib.Instruction::LocalGet(_)
    | @lib.Instruction::GlobalGet(_)
    | @lib.Instruction::I32Const(_)
    | @lib.Instruction::I64Const(_)
    | @lib.Instruction::F32Const(_)
    | @lib.Instruction::F64Const(_)
    | @lib.Instruction::MemorySize(_)
    | @lib.Instruction::RefNull(_)
    | @lib.Instruction::RefFunc(_)
    | @lib.Instruction::StringConst(_) => Some(0)
    @lib.Instruction::Drop
    | @lib.Instruction::ThrowRef
    | @lib.Instruction::BrOnNull(_)
    | @lib.Instruction::BrOnNonNull(_)
    | @lib.Instruction::BrOnCast(_, _, _, _)
    | @lib.Instruction::BrOnCastFail(_, _, _, _)
    | @lib.Instruction::LocalSet(_)
    | @lib.Instruction::LocalTee(_)
    | @lib.Instruction::GlobalSet(_)
    | @lib.Instruction::If(_, _, _)
    | @lib.Instruction::BrIf(_) => Some(1)
    @lib.Instruction::Select(_) => Some(3)
    @lib.Instruction::Call(idx) =>
      match lcse_raw_call_info(call_infos, idx) {
        Some(info) => Some(info.params.length())
        None => None
      }
    @lib.Instruction::ReturnCall(idx) =>
      match lcse_raw_call_info(call_infos, idx) {
        Some(info) => Some(info.params.length())
        None => None
      }
    @lib.Instruction::ReturnCallIndirect(type_idx, _) =>
      match lcse_raw_func_type_for_idx(subtypes, type_idx) {
        Some(@lib.FuncType(params, _)) => Some(params.length() + 1)
        None => None
      }
    @lib.Instruction::ReturnCallRef(type_idx) =>
      match lcse_raw_func_type_for_idx(subtypes, type_idx) {
        Some(@lib.FuncType(params, _)) => Some(params.length() + 1)
        None => None
      }
    @lib.Instruction::I32Add
    | @lib.Instruction::I32Sub
    | @lib.Instruction::I32Mul
    | @lib.Instruction::I64Add
    | @lib.Instruction::I64Sub
    | @lib.Instruction::I64Mul
    | @lib.Instruction::I32Eq
    | @lib.Instruction::I32Ne
    | @lib.Instruction::I64Eq
    | @lib.Instruction::I64Ne => Some(2)
    @lib.Instruction::I32Eqz | @lib.Instruction::I64Eqz => Some(1)
    @lib.Instruction::StructSet(_, _) => Some(2)
    @lib.Instruction::ArraySet(_) => Some(3)
    @lib.Instruction::ArrayFill(_) => Some(4)
    @lib.Instruction::ArrayCopy(_, _) => Some(5)
    @lib.Instruction::ArrayInitData(_, _) => Some(4)
    _ =>
      if lcse_instr_is_store(instr) {
        Some(2)
      } else if lcse_instr_is_load(instr) {
        Some(1)
      } else {
        None
      }
  }
}

///|
fn lcse_raw_result_type(
  instr : @lib.Instruction,
  all_locals : Array[@lib.ValType],
  child_exprs : Array[LcseRawExpr],
  call_infos : Array[LcseRawCallInfo],
) -> @lib.ValType? {
  match instr {
    @lib.Instruction::LocalGet(idx) | @lib.Instruction::LocalTee(idx) =>
      match all_locals.get(cl_local_idx_raw(idx)) {
        Some(ty) => Some(ty)
        None => None
      }
    @lib.Instruction::I32Const(_)
    | @lib.Instruction::I32Load(_)
    | @lib.Instruction::I32Load8S(_)
    | @lib.Instruction::I32Load8U(_)
    | @lib.Instruction::I32Load16S(_)
    | @lib.Instruction::I32Load16U(_)
    | @lib.Instruction::MemorySize(_) => Some(@lib.ValType::i32())
    @lib.Instruction::I64Const(_)
    | @lib.Instruction::I64Load(_)
    | @lib.Instruction::I64Load8S(_)
    | @lib.Instruction::I64Load8U(_)
    | @lib.Instruction::I64Load16S(_)
    | @lib.Instruction::I64Load16U(_)
    | @lib.Instruction::I64Load32S(_)
    | @lib.Instruction::I64Load32U(_) => Some(@lib.ValType::i64())
    @lib.Instruction::F32Const(_) | @lib.Instruction::F32Load(_) =>
      Some(@lib.ValType::f32())
    @lib.Instruction::F64Const(_) | @lib.Instruction::F64Load(_) =>
      Some(@lib.ValType::f64())
    @lib.Instruction::RefNull(ty) => Some(@lib.ValType::ref_type(ty))
    @lib.Instruction::RefFunc(_) => Some(@lib.ValType::funcref())
    @lib.Instruction::Select(_) =>
      match child_exprs.get(0) {
        Some(expr) => Some(expr.ty)
        None => None
      }
    @lib.Instruction::Call(idx) =>
      match lcse_raw_call_info(call_infos, idx) {
        Some({ result: Some(ty), idempotent: true, .. }) => Some(ty)
        _ => None
      }
    @lib.Instruction::I32Add
    | @lib.Instruction::I32Sub
    | @lib.Instruction::I32Mul => Some(@lib.ValType::i32())
    @lib.Instruction::I64Add
    | @lib.Instruction::I64Sub
    | @lib.Instruction::I64Mul => Some(@lib.ValType::i64())
    @lib.Instruction::I32Eq
    | @lib.Instruction::I32Ne
    | @lib.Instruction::I32Eqz
    | @lib.Instruction::I64Eq
    | @lib.Instruction::I64Ne
    | @lib.Instruction::I64Eqz => Some(@lib.ValType::i32())
    _ => None
  }
}

///|
fn lcse_cancel_request_tree(exprs : Array[LcseRawExpr], expr_id : Int) -> Unit {
  if expr_id < 0 || expr_id >= exprs.length() {
    return
  }
  exprs[expr_id].repeat_of = -1
  for child in exprs[expr_id].children {
    lcse_cancel_request_tree(exprs, child)
  }
}

///|
fn lcse_raw_expr_profitable(expr : LcseRawExpr) -> Bool {
  expr.size >= 2
}

///|
fn lcse_raw_exprs_match(
  exprs : Array[LcseRawExpr],
  lhs_id : Int,
  instr : @lib.Instruction,
  children : Array[Int],
) -> Bool {
  if lhs_id < 0 || lhs_id >= exprs.length() {
    return false
  }
  let lhs = exprs[lhs_id]
  if lhs.instr != instr || lhs.children.length() != children.length() {
    return false
  }
  for idx = 0; idx < children.length(); idx = idx + 1 {
    let rhs_child = children[idx]
    let lhs_child = lhs.children[idx]
    if rhs_child < 0 ||
      rhs_child >= exprs.length() ||
      lhs_child < 0 ||
      lhs_child >= exprs.length() {
      return false
    }
    if exprs[rhs_child].key != exprs[lhs_child].key {
      return false
    }
  }
  true
}

///|
fn lcse_raw_find_active_match(
  exprs : Array[LcseRawExpr],
  active : Array[Int],
  instr : @lib.Instruction,
  children : Array[Int],
) -> Int {
  for active_id in active {
    if lcse_raw_exprs_match(exprs, active_id, instr, children) {
      return active_id
    }
  }
  -1
}

///|
fn lcse_raw_instr_slice_matches(
  instrs : Array[@lib.Instruction],
  start : Int,
  end : Int,
  body : Array[@lib.Instruction],
  body_start : Int,
) -> Bool {
  let len = end - start + 1
  if len <= 0 || body_start + len > body.length() {
    return false
  }
  for offset = 0; offset < len; offset = offset + 1 {
    if instrs[start + offset] != body[body_start + offset] {
      return false
    }
  }
  true
}

///|
fn lcse_raw_instr_clears_nested_window(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Instruction::LocalSet(_) | @lib.Instruction::LocalTee(_) => true
    @lib.Instruction::Call(_) => false
    @lib.Instruction::CallIndirect(_, _) | @lib.Instruction::CallRef(_) => true
    @lib.Instruction::Br(_)
    | @lib.Instruction::BrTable(_, _)
    | @lib.Instruction::Return
    | @lib.Instruction::ReturnCall(_)
    | @lib.Instruction::ReturnCallIndirect(_, _)
    | @lib.Instruction::ReturnCallRef(_)
    | @lib.Instruction::Throw(_)
    | @lib.Instruction::ThrowRef
    | @lib.Instruction::Unreachable => true
    _ => lcse_instr_is_store(instr)
  }
}

///|
fn lcse_raw_scan_nested_repeats(
  parent_idx : Int,
  outer_instrs : Array[@lib.Instruction],
  body : Array[@lib.Instruction],
  exprs : Array[LcseRawExpr],
  outer_active : Array[Int],
  repeats : Array[LcseRawNestedRepeat],
  call_infos : Array[LcseRawCallInfo],
) -> Unit {
  if body.length() > 16 || outer_active.length() == 0 {
    return
  }
  let active = outer_active.copy()
  let mut idx = 0
  while idx < body.length() {
    let mut best_original = -1
    let mut best_end = -1
    let mut best_size = -1
    for original_id in active {
      let original = exprs[original_id]
      if lcse_raw_expr_profitable(original) &&
        original.size > best_size &&
        lcse_raw_instr_slice_matches(
          outer_instrs,
          original.start,
          original.end,
          body,
          idx,
        ) {
        best_original = original_id
        best_end = idx + original.end - original.start
        best_size = original.size
      }
    }
    if best_original >= 0 {
      repeats.push({
        parent_idx,
        start: idx,
        end: best_end,
        original: best_original,
      })
      idx = best_end + 1
      continue
    }
    match body[idx] {
      @lib.Instruction::Call(call_idx) =>
        if !lcse_raw_call_is_idempotent(call_infos, call_idx) {
          active.clear()
        }
      other => if lcse_raw_instr_clears_nested_window(other) { active.clear() }
    }
    idx += 1
  }
}

///|
fn lcse_raw_nested_repeat_for_parent(
  repeats : Array[LcseRawNestedRepeat],
  parent_idx : Int,
  start : Int,
) -> LcseRawNestedRepeat? {
  for repeat in repeats {
    if repeat.parent_idx == parent_idx && repeat.start == start {
      return Some(repeat)
    }
  }
  None
}

///|
fn lcse_raw_rewrite_nested_with_outer_repeats(
  body : Array[@lib.Instruction],
  parent_idx : Int,
  repeats : Array[LcseRawNestedRepeat],
  exprs : Array[LcseRawExpr],
) -> (Array[@lib.Instruction], Bool) {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  let mut i = 0
  while i < body.length() {
    match lcse_raw_nested_repeat_for_parent(repeats, parent_idx, i) {
      Some(repeat) => {
        let local_id = exprs[repeat.original].local_id
        if local_id >= 0 {
          out.push(
            @lib.Instruction::local_get(
              @lib.LocalIdx::new(local_id.reinterpret_as_uint()),
            ),
          )
          changed = true
          i = repeat.end + 1
          continue
        }
      }
      None => ()
    }
    out.push(body[i])
    i += 1
  }
  (out, changed)
}

///|
fn lcse_raw_rewrite_instrs(
  instrs : Array[@lib.Instruction],
  params : Array[@lib.ValType],
  local_types : Array[@lib.ValType],
  call_infos : Array[LcseRawCallInfo],
  subtypes : Array[@lib.SubType],
) -> (Array[@lib.Instruction], Bool) {
  if instrs.length() > 16 {
    return (instrs, false)
  }
  let all_locals = params.copy()
  for ty in local_types {
    all_locals.push(ty)
  }
  let exprs : Array[LcseRawExpr] = []
  let stack : Array[Int] = []
  let active : Array[Int] = []
  let nested_repeats : Array[LcseRawNestedRepeat] = []
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    let operand_count = match
      lcse_raw_instr_operand_count(instr, call_infos, subtypes) {
      Some(count) => count
      None => {
        match instr {
          @lib.Instruction::Block(_, @lib.Expr(body))
          | @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
            lcse_raw_scan_nested_repeats(
              idx, instrs, body, exprs, active, nested_repeats, call_infos,
            )
          _ => ()
        }
        stack.clear()
        active.clear()
        continue
      }
    }
    let children : Array[Int] = []
    if stack.length() < operand_count {
      stack.clear()
      active.clear()
      continue
    }
    let first_child_stack = stack.length() - operand_count
    for child_idx = first_child_stack
        child_idx < stack.length()
        child_idx = child_idx + 1 {
      children.push(stack[child_idx])
    }
    for _ in 0..<operand_count {
      ignore(stack.pop())
    }
    match instr {
      @lib.Instruction::LocalSet(_) | @lib.Instruction::LocalTee(_) =>
        active.clear()
      @lib.Instruction::Call(call_idx) =>
        if !lcse_raw_call_is_idempotent(call_infos, call_idx) {
          active.clear()
        }
      @lib.Instruction::CallIndirect(_, _) | @lib.Instruction::CallRef(_) =>
        active.clear()
      _ => if lcse_instr_is_store(instr) { active.clear() }
    }
    match instr {
      @lib.Instruction::BrOnNull(_)
      | @lib.Instruction::BrOnCast(_, _, _, _)
      | @lib.Instruction::BrOnCastFail(_, _, _, _) => {
        if children.length() == 1 {
          stack.push(children[0])
        }
        continue
      }
      _ => ()
    }
    match
      lcse_raw_result_type(
        instr,
        all_locals,
        children.map(fn(id) { exprs[id] }),
        call_infos,
      ) {
      Some(ty) => {
        let mut start = idx
        let mut size = 1
        let reads_locals : Array[Int] = []
        let mut reads_memory = lcse_instr_is_load(instr)
        for child in children {
          let child_expr = exprs[child]
          if child_expr.start < start {
            start = child_expr.start
          }
          size += child_expr.size
          for local_id in child_expr.reads_locals {
            if !reads_locals.contains(local_id) {
              reads_locals.push(local_id)
            }
          }
          if child_expr.reads_memory {
            reads_memory = true
          }
        }
        match instr {
          @lib.Instruction::LocalGet(local_idx) => {
            let local_id = cl_local_idx_raw(local_idx)
            if !reads_locals.contains(local_id) {
              reads_locals.push(local_id)
            }
          }
          _ => ()
        }
        let expr_id = exprs.length()
        let original_id = if size <= 32 {
          lcse_raw_find_active_match(exprs, active, instr, children)
        } else {
          -1
        }
        let canonical_key = if original_id >= 0 {
          exprs[original_id].key
        } else {
          expr_id
        }
        let expr = {
          start,
          end: idx,
          instr,
          key: canonical_key,
          ty,
          size,
          children,
          reads_locals,
          reads_memory,
          repeat_of: -1,
          local_id: -1,
        }
        exprs.push(expr)
        if original_id >= 0 {
          if lcse_raw_expr_profitable(expr) {
            exprs[expr_id].repeat_of = original_id
            for child in children {
              lcse_cancel_request_tree(exprs, child)
            }
          }
        } else {
          active.push(expr_id)
        }
        stack.push(expr_id)
      }
      None => ()
    }
    match instr {
      @lib.Instruction::If(_, then_body, _) => {
        lcse_raw_scan_nested_repeats(
          idx, instrs, then_body, exprs, active, nested_repeats, call_infos,
        )
        active.clear()
      }
      _ => ()
    }
  }
  let repeat_start = Array::make(instrs.length(), -1)
  let original_end = Array::make(instrs.length(), -1)
  for expr_id = 0; expr_id < exprs.length(); expr_id = expr_id + 1 {
    let expr = exprs[expr_id]
    if expr.repeat_of >= 0 {
      repeat_start[expr.start] = expr_id
      let original = exprs[expr.repeat_of]
      original_end[original.end] = expr.repeat_of
    }
  }
  for repeat in nested_repeats {
    let original = exprs[repeat.original]
    if original.end >= 0 && original.end < original_end.length() {
      original_end[original.end] = repeat.original
    }
  }
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  let mut i = 0
  while i < instrs.length() {
    let repeat_id = repeat_start[i]
    if repeat_id >= 0 {
      let original_id = exprs[repeat_id].repeat_of
      let local_id = exprs[original_id].local_id
      if local_id >= 0 {
        out.push(
          @lib.Instruction::local_get(
            @lib.LocalIdx::new(local_id.reinterpret_as_uint()),
          ),
        )
        changed = true
        i = exprs[repeat_id].end + 1
        continue
      }
    }
    let rewritten_instr = match instrs[i] {
      @lib.Instruction::Block(block_type, @lib.Expr(body)) => {
        let (outer_body, outer_body_changed) = lcse_raw_rewrite_nested_with_outer_repeats(
          body, i, nested_repeats, exprs,
        )
        let (next_body, body_changed) = lcse_raw_rewrite_instrs(
          outer_body, params, local_types, call_infos, subtypes,
        )
        if outer_body_changed || body_changed {
          changed = true
        }
        @lib.Instruction::block(block_type, @lib.Expr::new(next_body))
      }
      @lib.Instruction::Loop(block_type, @lib.Expr(body)) => {
        let (next_body, body_changed) = lcse_raw_rewrite_instrs(
          body, params, local_types, call_infos, subtypes,
        )
        if body_changed {
          changed = true
        }
        @lib.Instruction::loop_(block_type, @lib.Expr::new(next_body))
      }
      @lib.Instruction::If(block_type, then_body, else_body) => {
        let (outer_then, outer_then_changed) = lcse_raw_rewrite_nested_with_outer_repeats(
          then_body, i, nested_repeats, exprs,
        )
        let (next_then, then_changed) = lcse_raw_rewrite_instrs(
          outer_then, params, local_types, call_infos, subtypes,
        )
        let (next_else, else_changed) = match else_body {
          Some(body) => {
            let (body2, changed2) = lcse_raw_rewrite_instrs(
              body, params, local_types, call_infos, subtypes,
            )
            (Some(body2), changed2)
          }
          None => (None, false)
        }
        if outer_then_changed || then_changed || else_changed {
          changed = true
        }
        @lib.Instruction::if_(block_type, next_then, next_else)
      }
      @lib.Instruction::TryTable(block_type, catches, @lib.Expr(body)) => {
        let (outer_body, outer_body_changed) = lcse_raw_rewrite_nested_with_outer_repeats(
          body, i, nested_repeats, exprs,
        )
        let (next_body, body_changed) = lcse_raw_rewrite_instrs(
          outer_body, params, local_types, call_infos, subtypes,
        )
        if outer_body_changed || body_changed {
          changed = true
        }
        @lib.Instruction::try_table(
          block_type,
          catches,
          @lib.Expr::new(next_body),
        )
      }
      other => other
    }
    out.push(rewritten_instr)
    let original_id = original_end[i]
    if original_id >= 0 {
      let local_id = params.length() + local_types.length()
      local_types.push(exprs[original_id].ty)
      exprs[original_id].local_id = local_id
      out.push(
        @lib.Instruction::local_tee(
          @lib.LocalIdx::new(local_id.reinterpret_as_uint()),
        ),
      )
      changed = true
    }
    i += 1
  }
  (out, changed)
}

///|
fn lcse_raw_rewrite_func(
  func : @lib.Func,
  params : Array[@lib.ValType],
  call_infos : Array[LcseRawCallInfo],
  subtypes : Array[@lib.SubType],
) -> LcseRawRewrite {
  let @lib.Func(locals, @lib.Expr(instrs)) = func
  if !lcse_instrs_may_have_repeated_candidate(instrs) {
    return { func, changed: false }
  }
  let local_types = cl_flatten_locals(locals, locals.length())
  let (rewritten, changed) = lcse_raw_rewrite_instrs(
    instrs, params, local_types, call_infos, subtypes,
  )
  if changed {
    {
      func: @lib.Func::new(
        @lib.Locals::from_types(local_types),
        @lib.Expr::new(rewritten),
      ),
      changed: true,
    }
  } else {
    { func, changed: false }
  }
}

///|
fn local_cse_run_raw_func_with_params(
  func : @lib.Func,
  params : Array[@lib.ValType],
) -> (@lib.Func, Bool) {
  let rewrite = lcse_raw_rewrite_func(func, params, [], [])
  (rewrite.func, rewrite.changed)
}

///|
fn lcse_raw_func_type_for_idx(
  subtypes : Array[@lib.SubType],
  type_idx : @lib.TypeIdx,
) -> @lib.FuncType? {
  let subtype = match type_idx {
    @lib.TypeIdx(type_pos) =>
      match subtypes.get(type_pos.reinterpret_as_int()) {
        Some(subtype) => subtype
        None => return None
      }
    @lib.RecIdx(_) => return None
  }
  match subtype.get_comptype() {
    @lib.FuncCompType(params, results) =>
      Some(@lib.FuncType::new(params, results))
    _ => None
  }
}

///|
fn lcse_raw_func_has_idempotent_annotation(
  sec : @lib.FuncAnnotationSec?,
  func_idx : UInt,
) -> Bool {
  match sec {
    Some(@lib.FuncAnnotationSec(entries)) =>
      for entry in entries {
        let @lib.FuncAnnotationAssoc(idx, annotations) = entry
        if idx == func_idx {
          for annotation in annotations {
            if annotation.name == "binaryen.idempotent" &&
              annotation.args.length() == 0 {
              return true
            }
          }
        }
      }
    None => ()
  }
  false
}

///|
fn lcse_raw_module_call_infos(mod_ : @lib.Module) -> Array[LcseRawCallInfo] {
  let subtypes = cl_module_subtypes(mod_)
  let type_idxs : Array[@lib.TypeIdx] = []
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for im in imports {
        match im {
          @lib.Import(_, _, @lib.FuncExternType(type_idx)) =>
            type_idxs.push(type_idx)
          _ => ()
        }
      }
    None => ()
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(func_type_idxs)) =>
      for type_idx in func_type_idxs {
        type_idxs.push(type_idx)
      }
    None => ()
  }
  let out : Array[LcseRawCallInfo] = []
  for idx = 0; idx < type_idxs.length(); idx = idx + 1 {
    match lcse_raw_func_type_for_idx(subtypes, type_idxs[idx]) {
      Some(@lib.FuncType(params, results)) => {
        let result = match results {
          [ty] => Some(ty)
          _ => None
        }
        out.push({
          params,
          result,
          idempotent: lcse_raw_func_has_idempotent_annotation(
            mod_.func_annotation_sec,
            idx.reinterpret_as_uint(),
          ),
        })
      }
      None => out.push({ params: [], result: None, idempotent: false })
    }
  }
  out
}

///|
pub fn local_cse_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let params = cl_defined_func_param_cache(mod_)
      let call_infos = lcse_raw_module_call_infos(mod_)
      let subtypes = cl_module_subtypes(mod_)
      let rewritten : Array[@lib.Func] = []
      let mut changed = false
      for idx = 0; idx < funcs.length(); idx = idx + 1 {
        let rewrite = lcse_raw_rewrite_func(
          funcs[idx],
          params[idx],
          call_infos,
          subtypes,
        )
        rewritten.push(rewrite.func)
        if rewrite.changed {
          changed = true
        }
      }
      if !changed {
        return mod_
      }
      cl_rebuild_module(
        mod_,
        Some(@lib.CodeSec::new(rewritten)),
        cl_name_sec_without_local_names(mod_.name_sec),
      )
    }
    None => mod_
  }
}

///|
priv enum LcsePlace {
  Region(@ir.HotRegionRef, Int)
  Child(Int, Int)
}

///|
priv struct LcseBinding {
  original : Int
  place : LcsePlace
  mut local_id : Int
  ty : @lib.ValType
}

///|
priv struct LcseState {
  mut bindings : @hashmap.HashMap[String, LcseBinding]
}

///|
fn LcseState::new() -> LcseState {
  { bindings: @hashmap.new(capacity=64) }
}

///|
fn lcse_result_type(func : @ir.HotFunc, node_id : Int) -> @lib.ValType? {
  match @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [ty] => Some(ty)
    _ => None
  }
}

///|
fn lcse_node_exact_suffix(func : @ir.HotFunc, node_id : Int) -> String {
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) => ":instr=\{@debug.to_string(instr)}"
    None => ""
  }
}

///|
fn lcse_tree_key(func : @ir.HotFunc, node_id : Int) -> String? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  let mut key = "op=\{node.op};results=\{@ir.hot_type_results(func, node.ty)};imm0=\{node.imm0};imm1=\{node.imm1};flags=\{node.flags}\{lcse_node_exact_suffix(func, node_id)}("
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    match lcse_tree_key(func, @ir.hot_child_get(func, node_id, slot)) {
      Some(child_key) => key = key + child_key + ","
      None => return None
    }
  }
  Some(key + ")")
}

///|
fn lcse_tree_size(func : @ir.HotFunc, node_id : Int) -> Int {
  let mut size = 1
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    size += lcse_tree_size(func, @ir.hot_child_get(func, node_id, slot))
  }
  size
}

///|
fn lcse_effect_mask_allowed(mask : @ir.EffectMask) -> Bool {
  // Allow pure trees and repeated loads. The linear window is cleared by memory,
  // local, global, table, call, throw, and control barriers before a later use can
  // reuse stale state.
  let allowed = @ir.EFFECT_MASK_MEMORY_READ |
    @ir.EFFECT_MASK_TRAP |
    @ir.EFFECT_MASK_LOCAL_STATE
  (mask | allowed) == allowed
}

///|
fn lcse_candidate_key(func : @ir.HotFunc, node_id : Int) -> String? {
  let node = @ir.hot_node_get(func, node_id)
  if lcse_result_type(func, node_id) is None {
    return None
  }
  match node.op {
    @ir.HotOp::Const
    | @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc => return None
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee | @ir.HotOp::Drop => return None
    @ir.HotOp::Atomic => return None
    _ => ()
  }
  if lcse_tree_size(func, node_id) < 2 {
    return None
  }
  lcse_tree_key(func, node_id)
}

///|
fn lcse_barrier_clears_window(func : @ir.HotFunc, node_id : Int) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Drop => false
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => true
    @ir.HotOp::LocalGet
    | @ir.HotOp::Const
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc => false
    _ => {
      let mask = @ir.effects_for_node(func, node_id)
      !lcse_effect_mask_allowed(mask)
    }
  }
}

///|
fn lcse_wrap_original(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  binding : LcseBinding,
) -> Int {
  if binding.local_id >= 0 {
    return binding.local_id
  }
  let local_id = @ir.hot_append_body_local(func, binding.ty)
  let tee_id = @ir.hot_build_local_tee(func, local_id, binding.original)
  match binding.place {
    LcsePlace::Region(region_ref, idx) =>
      ignore(@ir.hot_region_set(func, region_ref, idx, tee_id))
    LcsePlace::Child(parent_id, slot) =>
      @ir.hot_child_set(func, parent_id, slot, tee_id)
  }
  binding.local_id = local_id
  pass_mark_mutated(ctx, func)
  local_id
}

///|
fn lcse_replace_repeat(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  place : LcsePlace,
  local_id : Int,
) -> Unit {
  let get_id = @ir.hot_build_local_get(func, local_id)
  match place {
    LcsePlace::Region(region_ref, idx) =>
      ignore(@ir.hot_region_set(func, region_ref, idx, get_id))
    LcsePlace::Child(parent_id, slot) =>
      @ir.hot_child_set(func, parent_id, slot, get_id)
  }
  pass_mark_mutated(ctx, func)
}

///|
fn lcse_visit_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : LcseState,
  node_id : Int,
  place : LcsePlace,
) -> Unit {
  match lcse_candidate_key(func, node_id) {
    Some(key) =>
      match state.bindings.get(key) {
        Some(binding) => {
          let local_id = lcse_wrap_original(ctx, func, binding)
          lcse_replace_repeat(ctx, func, place, local_id)
          return
        }
        None =>
          match lcse_result_type(func, node_id) {
            Some(ty) =>
              state.bindings.set(key, {
                original: node_id,
                place,
                local_id: -1,
                ty,
              })
            None => ()
          }
      }
    None => ()
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::Try | @ir.HotOp::TryTable => {
      lcse_visit_region(ctx, func, @ir.hot_region_body_ref(func, node_id))
      return
    }
    @ir.HotOp::If => {
      if @ir.hot_child_count(func, node_id) > 0 {
        let condition = @ir.hot_child_get(func, node_id, 0)
        if condition >= 0 && @ir.hot_node_is_live(func, condition) {
          lcse_visit_node(
            ctx,
            func,
            state,
            condition,
            LcsePlace::Child(node_id, 0),
          )
        }
      }
      lcse_visit_region(ctx, func, @ir.hot_region_then_ref(func, node_id))
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => lcse_visit_region(ctx, func, else_ref)
        None => ()
      }
      return
    }
    _ => ()
  }
  let count = @ir.hot_child_count(func, node_id)
  for slot = 0; slot < count; slot = slot + 1 {
    let child = @ir.hot_child_get(func, node_id, slot)
    if child >= 0 && @ir.hot_node_is_live(func, child) {
      lcse_visit_node(ctx, func, state, child, LcsePlace::Child(node_id, slot))
    }
  }
}

///|
fn lcse_visit_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Unit {
  let state = LcseState::new()
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let root = @ir.hot_region_get(func, region_ref, idx)
    if root < 0 || !@ir.hot_node_is_live(func, root) {
      continue
    }
    lcse_visit_node(ctx, func, state, root, LcsePlace::Region(region_ref, idx))
    if lcse_barrier_clears_window(func, root) {
      state.bindings = @hashmap.new(capacity=64)
    }
  }
}

///|
pub fn local_cse_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  let before_revision = @ir.hot_revision_current(func)
  lcse_visit_region(ctx, func, @ir.HotRegionRef::root())
  if @ir.hot_revision_current(func) != before_revision {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
