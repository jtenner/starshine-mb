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
fn lcse_raw_instr_key3(
  a : @lib.Instruction,
  b : @lib.Instruction,
  c : @lib.Instruction,
) -> String? {
  match (a, b, c) {
    (
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::I32Add,
    )
    | (
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::I32Sub,
    )
    | (
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::I32Mul,
    )
    | (
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::I64Add,
    )
    | (
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::I64Sub,
    )
    | (
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::I64Mul,
    ) =>
      Some(
        "\{@debug.to_string(a)};\{@debug.to_string(b)};\{@debug.to_string(c)}",
      )
    _ => None
  }
}

///|
fn lcse_raw_rewrite_func(
  func : @lib.Func,
  params : Array[@lib.ValType],
) -> LcseRawRewrite {
  let @lib.Func(locals, @lib.Expr(instrs)) = func
  let local_types = cl_flatten_locals(locals, locals.length())
  let first_for_key : @hashmap.HashMap[String, Int] = @hashmap.new(capacity=16)
  let temp_for_key : @hashmap.HashMap[String, Int] = @hashmap.new(capacity=16)
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  let mut next_body_local = local_types.length()
  let mut i = 0
  while i < instrs.length() {
    if i + 3 < instrs.length() && instrs[i + 3] == @lib.Instruction::drop() {
      match lcse_raw_instr_key3(instrs[i], instrs[i + 1], instrs[i + 2]) {
        Some(key) =>
          match first_for_key.get(key) {
            Some(first_out_idx) => {
              let local_id = match temp_for_key.get(key) {
                Some(existing) => existing
                None => {
                  let ty = match instrs[i + 2] {
                    @lib.Instruction::I64Add
                    | @lib.Instruction::I64Sub
                    | @lib.Instruction::I64Mul => @lib.ValType::i64()
                    _ => @lib.ValType::i32()
                  }
                  local_types.push(ty)
                  let id = params.length() + next_body_local
                  next_body_local += 1
                  temp_for_key.set(key, id)
                  out.insert(
                    first_out_idx + 3,
                    @lib.Instruction::local_tee(
                      @lib.LocalIdx::new(id.reinterpret_as_uint()),
                    ),
                  )
                  id
                }
              }
              out.push(
                @lib.Instruction::local_get(
                  @lib.LocalIdx::new(local_id.reinterpret_as_uint()),
                ),
              )
              out.push(@lib.Instruction::drop())
              changed = true
              i += 4
              continue
            }
            None => first_for_key.set(key, out.length())
          }
        None => ()
      }
    }
    match instrs[i] {
      @lib.Instruction::LocalSet(_)
      | @lib.Instruction::LocalTee(_)
      | @lib.Instruction::Call(_)
      | @lib.Instruction::CallIndirect(_, _)
      | @lib.Instruction::CallRef(_) => {
        first_for_key.clear()
        temp_for_key.clear()
      }
      _ => ()
    }
    out.push(instrs[i])
    i += 1
  }
  if changed {
    {
      func: @lib.Func::new(
        @lib.Locals::from_types(local_types),
        @lib.Expr::new(out),
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
