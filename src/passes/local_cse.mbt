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
  key : String
  ty : @lib.ValType
  size : Int
  children : Array[Int]
  reads_locals : Array[Int]
  reads_memory : Bool
  mut repeat_of : Int
  active : Bool
  mut local_id : Int
}

///|
fn lcse_instr_text(instr : @lib.Instruction) -> String {
  @debug.to_string(instr)
}

///|
fn lcse_instr_is_binary_text(text : String) -> Bool {
  text.contains("Add") ||
  text.contains("Sub") ||
  text.contains("Mul") ||
  text.contains("Div") ||
  text.contains("Rem") ||
  text.contains("And") ||
  text.contains("Or") ||
  text.contains("Xor") ||
  text.contains("Shl") ||
  text.contains("Shr") ||
  text.contains("Rot") ||
  text.contains("Min") ||
  text.contains("Max") ||
  text.contains("Copysign") ||
  (
    !text.contains("Eqz") &&
    (
      text.contains("Eq") ||
      text.contains("Ne") ||
      text.contains("Lt") ||
      text.contains("Gt") ||
      text.contains("Le") ||
      text.contains("Ge") ||
      text.contains("RefEq")
    )
  )
}

///|
fn lcse_instr_is_unary_text(text : String) -> Bool {
  text.contains("Eqz") ||
  text.contains("Clz") ||
  text.contains("Ctz") ||
  text.contains("Popcnt") ||
  text.contains("Abs") ||
  text.contains("Neg") ||
  text.contains("Ceil") ||
  text.contains("Floor") ||
  text.contains("Trunc") ||
  text.contains("Nearest") ||
  text.contains("Sqrt") ||
  text.contains("Convert") ||
  text.contains("Wrap") ||
  text.contains("Extend") ||
  text.contains("Promote") ||
  text.contains("Demote") ||
  text.contains("Reinterpret") ||
  text.contains("RefIsNull") ||
  text.contains("RefAsNonNull")
}

///|
fn lcse_raw_instr_operand_count(instr : @lib.Instruction) -> Int? {
  let text = lcse_instr_text(instr)
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
    | @lib.Instruction::LocalSet(_)
    | @lib.Instruction::LocalTee(_)
    | @lib.Instruction::GlobalSet(_)
    | @lib.Instruction::If(_, _, _)
    | @lib.Instruction::BrIf(_) => Some(1)
    @lib.Instruction::Select(_) | @lib.Instruction::MemoryFill(_) => Some(3)
    _ =>
      if text.contains("Store") ||
        text.contains("TableSet") ||
        text.contains("RefEq") ||
        lcse_instr_is_binary_text(text) {
        Some(2)
      } else if text.contains("Load") || lcse_instr_is_unary_text(text) {
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
) -> @lib.ValType? {
  let text = lcse_instr_text(instr)
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
    @lib.Instruction::Select(_) =>
      match child_exprs.get(0) {
        Some(expr) => Some(expr.ty)
        None => None
      }
    _ =>
      if text.contains("Eq") ||
        text.contains("Ne") ||
        text.contains("Lt") ||
        text.contains("Gt") ||
        text.contains("Le") ||
        text.contains("Ge") ||
        text.contains("Eqz") ||
        text.contains("RefIsNull") ||
        text.contains("RefEq") {
        Some(@lib.ValType::i32())
      } else if text.contains("I64") {
        Some(@lib.ValType::i64())
      } else if text.contains("F32") {
        Some(@lib.ValType::f32())
      } else if text.contains("F64") {
        Some(@lib.ValType::f64())
      } else if text.contains("I32") {
        Some(@lib.ValType::i32())
      } else {
        None
      }
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
fn lcse_raw_rewrite_instrs(
  instrs : Array[@lib.Instruction],
  params : Array[@lib.ValType],
  local_types : Array[@lib.ValType],
) -> (Array[@lib.Instruction], Bool) {
  if instrs.length() > 128 {
    return (instrs, false)
  }
  let all_locals = params.copy()
  for ty in local_types {
    all_locals.push(ty)
  }
  let exprs : Array[LcseRawExpr] = []
  let stack : Array[Int] = []
  let active : @hashmap.HashMap[String, Int] = @hashmap.new(capacity=64)
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    let operand_count = match lcse_raw_instr_operand_count(instr) {
      Some(count) => count
      None => {
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
      @lib.Instruction::Call(_)
      | @lib.Instruction::CallIndirect(_, _)
      | @lib.Instruction::CallRef(_) => active.clear()
      _ => if lcse_instr_text(instr).contains("Store") { active.clear() }
    }
    match
      lcse_raw_result_type(
        instr,
        all_locals,
        children.map(fn(id) { exprs[id] }),
      ) {
      Some(ty) => {
        let mut start = idx
        let mut size = 1
        let reads_locals : Array[Int] = []
        let mut reads_memory = lcse_instr_text(instr).contains("Load")
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
        let mut key = "large:\{idx}"
        if size <= 32 {
          key = lcse_instr_text(instr) + "("
          for child in children {
            key = key + exprs[child].key + ","
          }
          key = key + ")"
        }
        let expr_id = exprs.length()
        let expr = {
          start,
          end: idx,
          key,
          ty,
          size,
          children,
          reads_locals,
          reads_memory,
          repeat_of: -1,
          active: true,
          local_id: -1,
        }
        exprs.push(expr)
        if lcse_raw_expr_profitable(expr) {
          match active.get(key) {
            Some(original_id) =>
              if original_id >= 0 &&
                original_id < exprs.length() &&
                exprs[original_id].active {
                exprs[expr_id].repeat_of = original_id
                for child in children {
                  lcse_cancel_request_tree(exprs, child)
                }
              } else {
                active.set(key, expr_id)
              }
            None => active.set(key, expr_id)
          }
        }
        stack.push(expr_id)
      }
      None => ()
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
        let (next_body, body_changed) = lcse_raw_rewrite_instrs(
          body, params, local_types,
        )
        if body_changed {
          changed = true
        }
        @lib.Instruction::block(block_type, @lib.Expr::new(next_body))
      }
      @lib.Instruction::Loop(block_type, @lib.Expr(body)) => {
        let (next_body, body_changed) = lcse_raw_rewrite_instrs(
          body, params, local_types,
        )
        if body_changed {
          changed = true
        }
        @lib.Instruction::loop_(block_type, @lib.Expr::new(next_body))
      }
      @lib.Instruction::If(block_type, then_body, else_body) => {
        let (next_then, then_changed) = lcse_raw_rewrite_instrs(
          then_body, params, local_types,
        )
        let (next_else, else_changed) = match else_body {
          Some(body) => {
            let (body2, changed2) = lcse_raw_rewrite_instrs(
              body, params, local_types,
            )
            (Some(body2), changed2)
          }
          None => (None, false)
        }
        if then_changed || else_changed {
          changed = true
        }
        @lib.Instruction::if_(block_type, next_then, next_else)
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
) -> LcseRawRewrite {
  let @lib.Func(locals, @lib.Expr(instrs)) = func
  let local_types = cl_flatten_locals(locals, locals.length())
  let (rewritten, changed) = lcse_raw_rewrite_instrs(
    instrs, params, local_types,
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
pub fn local_cse_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      if funcs.length() > 1000 {
        return mod_
      }
      let params = cl_defined_func_param_cache(mod_)
      let rewritten : Array[@lib.Func] = []
      let mut changed = false
      for idx = 0; idx < funcs.length(); idx = idx + 1 {
        let rewrite = lcse_raw_rewrite_func(funcs[idx], params[idx])
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
