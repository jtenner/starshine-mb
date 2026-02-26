///| 
/// Copyright 2023 WebAssembly Community Group participants
/// 
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
/// 
///     http://www.apache.org/licenses/LICENSE-2.0
/// 
/// Unless required by applicable law or agreed to in writing, software
/// distributed under the License is distributed on an "AS IS" BASIS,
/// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/// See the License for the specific language governing permissions and
/// limitations under the License.
///

///|
priv struct VQFuncSig {
  params : Array[ValType]
  results : Array[ValType]
}

///|
fn VQFuncSig::new(
  params : Array[ValType],
  results : Array[ValType],
) -> VQFuncSig {
  { params, results }
}

///|
fn vq_collect_func_sigs(mod : Module) -> Array[VQFuncSig] {
  let out : Array[VQFuncSig] = []
  let env = Env::new().with_module(mod)
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for tidx in type_idxs {
        match env.resolve_functype(tidx) {
          Some(FuncType(params, results)) =>
            out.push(VQFuncSig::new(params, results))
          None => out.push(VQFuncSig::new([], []))
        }
      }
    None => ()
  }
  out
}

///|
fn vq_type_of(instr : TInstr, env : Env) -> ValType? {
  lcs_infer_tinstr_type(instr, env)
}

///|
fn vq_same_type(a : ValType?, b : ValType?) -> Bool {
  match (a, b) {
    (Some(x), Some(y)) => x == y
    (None, None) => true
    _ => false
  }
}

///|
fn vq_block_result_type(bt : BlockType, env : Env) -> ValType? {
  match env.expand_blocktype(bt) {
    Ok((_, [vt])) => Some(vt)
    _ => None
  }
}

///|
fn vq_texpr_result_type(expr : TExpr, env : Env) -> ValType? {
  let TExpr(items) = expr
  if items.is_empty() {
    None
  } else {
    vq_type_of(items[items.length() - 1], env)
  }
}

///|
fn vq_is_nop_texpr(expr : TExpr) -> Bool {
  let TExpr(items) = expr
  if items.is_empty() {
    return true
  }
  for item in items {
    match item {
      TNop => ()
      _ => return false
    }
  }
  true
}

///|
fn vq_texpr_is_unreachable(expr : TExpr) -> Bool {
  let TExpr(items) = expr
  for item in items {
    if is_unreachable_instr(item) {
      return true
    }
  }
  false
}

///|
fn vq_wrap_texpr(expr : TExpr, env : Env) -> TInstr {
  let TExpr(items) = expr
  if items.length() == 0 {
    return TInstr::nop()
  }
  if items.length() == 1 {
    return items[0]
  }
  match vq_texpr_result_type(expr, env) {
    Some(vt) => TInstr::block(BlockType::val_type(vt), expr)
    None => TInstr::block(BlockType::void_(), expr)
  }
}

///|
fn vq_drop_texpr_value(expr : TExpr, env : Env) -> TExpr {
  let wrapped = vq_wrap_texpr(expr, env)
  match vq_type_of(wrapped, env) {
    Some(_) => TExpr::new([TInstr::drop(wrapped)])
    None => TExpr::new([wrapped])
  }
}

///|
fn vq_must_keep_unused_parent(curr : TInstr) -> Bool {
  lcs_collect_shallow_effects(curr).has_unremovable_side_effects()
}

///|
fn vq_children_with_effects(curr : TInstr) -> Array[TInstr] {
  let out : Array[TInstr] = []
  for child in eval_children(curr) {
    if lcs_collect_effects(child).has_unremovable_side_effects() {
      out.push(child)
    }
  }
  out
}

///|
fn vq_get_dropped_children_and_append(
  curr : TInstr,
  env : Env,
  dummy : TInstr,
) -> TInstr {
  let items : Array[TInstr] = []
  for child in vq_children_with_effects(curr) {
    match vq_type_of(child, env) {
      Some(_) => items.push(TInstr::drop(child))
      None => items.push(child)
    }
  }
  items.push(dummy)
  match vq_type_of(dummy, env) {
    Some(vt) => TInstr::block(BlockType::val_type(vt), TExpr::new(items))
    None => TInstr::block(BlockType::void_(), TExpr::new(items))
  }
}

///|
fn vq_take_budget(budget : Ref[Int]) -> Bool {
  let remaining = budget.val
  if remaining <= 0 {
    false
  } else {
    budget.update(fn(i) { i - 1 })
    true
  }
}

///|
fn vq_optimize(
  instr : TInstr,
  result_used : Bool,
  type_matters : Bool,
  env : Env,
  budget : Ref[Int],
) -> TInstr? {
  if !vq_take_budget(budget) {
    return Some(instr)
  }
  let initial_type = vq_type_of(instr, env)
  let mut type_matters = type_matters
  if initial_type is None {
    type_matters = true
  }
  if is_unreachable_instr(instr) {
    return Some(instr)
  }
  if result_used {
    return Some(instr)
  }

  let mut prev = instr
  let mut curr = instr
  for _ in 0..<64 {
    let curr_type = vq_type_of(curr, env)
    if type_matters && !vq_same_type(curr_type, initial_type) {
      return Some(prev)
    }
    prev = curr
    match curr {
      TDrop(_)
      | TBlock(_, _)
      | TIf(_, _, _, _)
      | TLoop(_, _)
      | TTryTable(_, _, _) => return Some(curr)
      _ => ()
    }
    if vq_must_keep_unused_parent(curr) {
      return Some(curr)
    }
    let children = vq_children_with_effects(curr)
    if children.is_empty() {
      return None
    }
    if children.length() == 1 {
      curr = children[0]
      if is_unreachable_instr(curr) {
        return Some(curr)
      }
      continue
    }
    match curr_type {
      Some(vt) =>
        match af_make_zero(vt) {
          Some(dummy) =>
            return Some(vq_get_dropped_children_and_append(curr, env, dummy))
          None => return Some(curr)
        }
      None => return Some(curr)
    }
  }
  Some(curr)
}

///|
priv struct VQSequenceResult {
  items : Array[TInstr]
  changed : Bool
}

///|
fn VQSequenceResult::new(
  items : Array[TInstr],
  changed : Bool,
) -> VQSequenceResult {
  { items, changed }
}

///|
fn vq_optimize_sequence(
  items : Array[TInstr],
  env : Env,
  result_type : ValType?,
  result_used : Bool,
  budget : Ref[Int],
) -> VQSequenceResult {
  let out : Array[TInstr] = []
  let mut changed = false
  let size = items.length()
  for i = 0; i < size; i = i + 1 {
    let child = items[i]
    let used = i == size - 1 && result_type is Some(_) && result_used
    let mut optimized = vq_process_instr(child, env, used, true, budget)
    if optimized is None {
      match vq_type_of(child, env) {
        Some(vt) =>
          match af_make_zero(vt) {
            Some(zero) => optimized = Some(zero)
            None => optimized = Some(child)
          }
        None => if is_unreachable_instr(child) { optimized = Some(child) }
      }
    }
    match optimized {
      None => changed = true
      Some(next) => {
        if next != child {
          changed = true
        }
        out.push(next)
        if is_unreachable_instr(next) {
          if i + 1 < size {
            changed = true
          }
          break
        }
      }
    }
  }
  VQSequenceResult::new(out, changed)
}

///|
fn vq_optimize_texpr(
  expr : TExpr,
  env : Env,
  result_type : ValType?,
  result_used : Bool,
  budget : Ref[Int],
) -> TExpr {
  let TExpr(items) = expr
  let sequence = vq_optimize_sequence(
    items, env, result_type, result_used, budget,
  )
  TExpr::new(sequence.items)
}

///|
fn vq_simplify_block_to_contents(
  bt : BlockType,
  body : TExpr,
  env : Env,
) -> TInstr {
  if has_break_to_depth_in_texpr(body, 0) {
    return TInstr::block(bt, body)
  }
  let TExpr(items) = body
  if items.length() == 0 {
    if vq_block_result_type(bt, env) is Some(_) {
      return TInstr::block(bt, body)
    }
    return TInstr::nop()
  }
  if items.length() == 1 {
    let only = items[0]
    match vq_block_result_type(bt, env) {
      Some(vt) =>
        match vq_type_of(only, env) {
          Some(t) if t == vt => return only
          _ => ()
        }
      None =>
        if vq_type_of(only, env) is None || is_unreachable_instr(only) {
          return only
        }
    }
  }
  TInstr::block(bt, body)
}

///|
fn vq_texpr_throws(expr : TExpr) -> Bool {
  let mut throws = false
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TThrow(_, _)
      | TThrowRef(_)
      | TCall(_, _)
      | TCallIndirect(_, _, _, _)
      | TCallRef(_, _, _)
      | TReturnCall(_, _)
      | TReturnCallIndirect(_, _, _, _)
      | TReturnCallRef(_, _, _) => throws = true
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_texpr((), expr))
  throws
}

///|
fn vq_texpr_has_unremovable_side_effects(expr : TExpr) -> Bool {
  let TExpr(items) = expr
  for item in items {
    if lcs_collect_effects(item).has_unremovable_side_effects() {
      return true
    }
  }
  false
}

///|
fn vq_process_instr(
  instr : TInstr,
  env : Env,
  result_used : Bool,
  type_matters : Bool,
  budget : Ref[Int],
) -> TInstr? {
  if !vq_take_budget(budget) {
    return Some(instr)
  }
  match instr {
    TBlock(bt, body) => {
      let result_type = vq_block_result_type(bt, env)
      let next_body = vq_optimize_texpr(
        body, env, result_type, result_used, budget,
      )
      Some(vq_simplify_block_to_contents(bt, next_body, env))
    }
    TIf(bt, condition, then_body, else_body) => {
      let next_condition = match
        vq_process_instr(condition, env, true, true, budget) {
        Some(v) => v
        None => condition
      }
      let arm_result_type = vq_block_result_type(bt, env)
      let next_then = vq_optimize_texpr(
        then_body,
        env,
        arm_result_type,
        arm_result_type is Some(_),
        budget,
      )
      let next_else = match else_body {
        Some(other) =>
          Some(
            vq_optimize_texpr(
              other,
              env,
              arm_result_type,
              arm_result_type is Some(_),
              budget,
            ),
          )
        None => None
      }

      match next_condition {
        TI32Const(I32(v)) =>
          if v != 0 {
            return Some(vq_wrap_texpr(next_then, env))
          } else {
            return Some(
              match next_else {
                Some(other) => vq_wrap_texpr(other, env)
                None => TInstr::nop()
              },
            )
          }
        TI64Const(I64(v)) =>
          if v != 0L {
            return Some(vq_wrap_texpr(next_then, env))
          } else {
            return Some(
              match next_else {
                Some(other) => vq_wrap_texpr(other, env)
                None => TInstr::nop()
              },
            )
          }
        _ => ()
      }

      if is_unreachable_instr(next_condition) {
        return Some(next_condition)
      }

      match next_else {
        Some(other) => {
          if vq_is_nop_texpr(other) {
            return Some(TInstr::if_(bt, next_condition, next_then, None))
          }
          if vq_is_nop_texpr(next_then) {
            return Some(
              TInstr::if_(
                bt,
                TInstr::unary(UnaryOp::i32_eqz(), next_condition),
                other,
                None,
              ),
            )
          }
          match (next_then.0, other.0) {
            ([TDrop(left)], [TDrop(right)]) =>
              match (vq_type_of(left, env), vq_type_of(right, env)) {
                (Some(lt), Some(rt)) if lt == rt =>
                  Some(
                    TInstr::drop(
                      TInstr::if_(
                        BlockType::val_type(lt),
                        next_condition,
                        TExpr::new([left]),
                        Some(TExpr::new([right])),
                      ),
                    ),
                  )
                _ =>
                  Some(TInstr::if_(bt, next_condition, next_then, Some(other)))
              }
            _ => Some(TInstr::if_(bt, next_condition, next_then, Some(other)))
          }
        }
        None =>
          if vq_is_nop_texpr(next_then) {
            Some(TInstr::drop(next_condition))
          } else {
            Some(TInstr::if_(bt, next_condition, next_then, None))
          }
      }
    }
    TLoop(bt, body) => {
      let result_type = vq_block_result_type(bt, env)
      let next_body = vq_optimize_texpr(
        body,
        env,
        result_type,
        result_type is Some(_),
        budget,
      )
      if vq_is_nop_texpr(next_body) {
        Some(TInstr::nop())
      } else {
        Some(TInstr::loop_(bt, next_body))
      }
    }
    TDrop(value) => {
      let next_value = match
        vq_process_instr(value, env, false, false, budget) {
        Some(v) => v
        None => return Some(TInstr::nop())
      }
      match next_value {
        TDrop(inner) => return Some(TInstr::drop(inner))
        TLocalTee(idx, inner) => return Some(TInstr::local_set(idx, inner))
        _ => ()
      }

      let dropped = TInstr::drop(next_value)
      if !lcs_collect_effects(dropped).has_unremovable_side_effects() {
        return Some(TInstr::nop())
      }

      match next_value {
        TBlock(bt, body) => {
          let TExpr(items) = body
          if items.length() > 0 {
            let last = items[items.length() - 1]
            match (vq_block_result_type(bt, env), vq_type_of(last, env)) {
              (Some(block_vt), Some(last_vt)) if block_vt == last_vt =>
                match vq_optimize(last, false, false, env, budget) {
                  None =>
                    if !has_break_to_depth_in_texpr(body, 0) {
                      let next_items = items.copy()
                      ignore(next_items.pop())
                      if next_items.length() > 1 {
                        return Some(
                          TInstr::block(
                            BlockType::void_(),
                            TExpr::new(next_items),
                          ),
                        )
                      }
                      if next_items.length() == 1 {
                        return Some(next_items[0])
                      }
                      return Some(TInstr::nop())
                    }
                  Some(_) => ()
                }
              _ => ()
            }
          }
        }
        _ => ()
      }

      match next_value {
        TIf(bt, cond, then_body, Some(other_body)) => {
          let if_type = vq_block_result_type(bt, env)
          match if_type {
            Some(_) =>
              if vq_texpr_is_unreachable(then_body) &&
                vq_texpr_result_type(other_body, env) is Some(_) {
                return Some(
                  TInstr::if_(
                    BlockType::void_(),
                    cond,
                    then_body,
                    Some(vq_drop_texpr_value(other_body, env)),
                  ),
                )
              } else if vq_texpr_is_unreachable(other_body) &&
                vq_texpr_result_type(then_body, env) is Some(_) {
                return Some(
                  TInstr::if_(
                    BlockType::void_(),
                    cond,
                    vq_drop_texpr_value(then_body, env),
                    Some(other_body),
                  ),
                )
              }
            None => ()
          }
        }
        _ => ()
      }
      Some(dropped)
    }
    TTryTable(bt, catches, body) => {
      let result_type = vq_block_result_type(bt, env)
      let next_body = vq_optimize_texpr(
        body,
        env,
        result_type,
        result_type is Some(_),
        budget,
      )
      if !vq_texpr_throws(next_body) {
        Some(vq_wrap_texpr(next_body, env))
      } else {
        Some(TInstr::try_table(bt, catches, next_body))
      }
    }
    _ => {
      let children = eval_children(instr)
      if children.is_empty() {
        return vq_optimize(instr, result_used, type_matters, env, budget)
      }
      let next_children : Array[TInstr] = []
      for child in children {
        match vq_process_instr(child, env, true, true, budget) {
          Some(next_child) => next_children.push(next_child)
          None => next_children.push(child)
        }
      }
      let rebuilt = mb_rebuild_non_control(instr, next_children)
      vq_optimize(rebuilt, result_used, type_matters, env, budget)
    }
  }
}

///|
fn vq_optimize_function(
  mod : Module,
  func : Func,
  sig : VQFuncSig,
) -> (Func, Bool) {
  match func {
    TFunc(locals, body) => {
      let all_locals = sig.params.copy()
      for local_ in locals {
        all_locals.push(local_)
      }
      let env = Env::new().with_module(mod).with_locals(all_locals)
      let result_type = match sig.results {
        [vt] => Some(vt)
        _ => None
      }
      let budget = Ref::new(250000)
      let sequence = vq_optimize_sequence(
        body.0,
        env,
        result_type,
        sig.results.length() > 0,
        budget,
      )
      let next_items = sequence.items
      if next_items.is_empty() {
        next_items.push(TInstr::nop())
      }
      let next_body = TExpr::new(next_items)
      let mut changed = sequence.changed
      if sig.results.length() == 0 &&
        !vq_texpr_has_unremovable_side_effects(next_body) {
        let nopped = Func::t_func(locals, TExpr::new([TInstr::nop()]))
        changed = TExpr::new([TInstr::nop()]) != body
        (nopped, changed)
      } else {
        let next_func = Func::t_func(locals, next_body)
        (next_func, changed)
      }
    }
    _ => (func, false)
  }
}

///|
fn vacuum_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn vacuum_ir_pass_with_trace(
  mod : Module,
  trace : (String) -> Unit,
) -> ModuleTransformer[IRContext] {
  let sigs = vq_collect_func_sigs(mod)
  let next_def_idx = Ref::new(0)
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    let def_idx = next_def_idx.val
    next_def_idx.update(fn(i) { i + 1 })
    let ordinal = def_idx + 1
    let start_instrs = match func {
      TFunc(_, body) => body.0.length()
      _ => 0
    }
    if ordinal <= 50 || ordinal % 500 == 0 {
      trace("func[\{ordinal}] start instrs=\{start_instrs}")
    }
    let sig = sigs.get(def_idx).unwrap_or(VQFuncSig::new([], []))
    let (next_func, changed) = vq_optimize_function(mod, func, sig)
    let end_instrs = match next_func {
      TFunc(_, body) => body.0.length()
      _ => 0
    }
    if ordinal <= 50 || ordinal % 500 == 0 {
      trace(
        "func[\{ordinal}] done changed=\{changed} instrs=\{start_instrs}->\{end_instrs}",
      )
    }
    if changed {
      change(ctx, next_func)
    } else {
      unchanged()
    }
  })
}

///|
fn vacuum_ir_pass(mod : Module) -> ModuleTransformer[IRContext] {
  vacuum_ir_pass_with_trace(mod, vacuum_trace_noop)
}

///|
fn run_vacuum(mod : Module) -> Module {
  let pass = vacuum_ir_pass(mod)
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => out
    Ok(None) => mod
    Err(e) => abort("vacuum pass failed: \{e}")
  }
}

///|
fn vq_first_func_body(mod : Module) -> TExpr {
  match mod.code_sec {
    Some(CodeSec([TFunc(_, body), ..])) => body
    _ => abort("expected first typed function body")
  }
}

///|
test "vacuum rewrites drop(local.tee(...)) to local.set(...)" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32()],
        TExpr::new([
          TInstr::drop(
            TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(9))),
          ),
        ]),
      ),
    ]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).0 {
    [TLocalSet(LocalIdx(i), TI32Const(I32(v)))] => {
      assert_eq(i, 0U)
      assert_eq(v, 9)
    }
    _ => fail("expected drop(local.tee) to rewrite to local.set")
  }
}

///|
test "vacuum removes side-effect-free dropped value" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func([], TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))])),
    ]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).0 {
    [TNop] => ()
    _ => fail("expected pure drop to be removed")
  }
}

///|
test "vacuum simplifies dropped unary wrapper around call to dropped call" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::unary(
                UnaryOp::i32_eqz(),
                TInstr::call(FuncIdx::new(1), []),
              ),
            ),
          ]),
        ),
        Func::t_func([], TExpr::new([TInstr::nop()])),
      ]),
    )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).0 {
    [TDrop(TCall(FuncIdx(i), []))] => assert_eq(i, 1U)
    _ => fail("expected drop(i32.eqz(call)) to become drop(call)")
  }
}

///|
test "vacuum replaces constant if(true) with then arm" {
  let t_i32 = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::val_type(ValType::i32()),
              TInstr::i32_const(I32(1)),
              TExpr::new([TInstr::i32_const(I32(7))]),
              Some(TExpr::new([TInstr::i32_const(I32(8))])),
            ),
          ]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).0 {
    [TI32Const(I32(v))] => assert_eq(v, 7)
    _ => fail("expected constant-true if to fold to then arm")
  }
}

///|
test "vacuum replaces if with unreachable condition by the condition" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::if_(
            BlockType::void_(),
            TInstr::unreachable_(),
            TExpr::new([TInstr::nop()]),
            None,
          ),
        ]),
      ),
    ]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).0 {
    [TUnreachable] => ()
    _ => fail("expected if(unreachable) to fold to unreachable")
  }
}

///|
test "vacuum removes if without else when then arm is nop by dropping condition" {
  let t_i32 = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i32()])),
  )
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32, t_void]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("cond"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::call(FuncIdx::new(0), []),
              TExpr::new([TInstr::nop()]),
              None,
            ),
          ]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).0 {
    [TDrop(TCall(FuncIdx(i), []))] => assert_eq(i, 0U)
    _ => fail("expected empty if body to become drop(condition)")
  }
}

///|
test "vacuum removes loops with nop body" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::loop_(BlockType::void_(), TExpr::new([TInstr::nop()])),
        ]),
      ),
    ]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).0 {
    [TNop] => ()
    _ => fail("expected loop with nop body to become nop")
  }
}

///|
test "vacuum removes trailing dead code after unreachable in block body" {
  let block = TInstr::block(
    BlockType::void_(),
    TExpr::new([
      TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
      TInstr::unreachable_(),
      TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(2))),
    ]),
  )
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([ValType::i32()], TExpr::new([block]))]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).0 {
    [TBlock(_, TExpr([TLocalSet(_, TI32Const(I32(v))), TUnreachable]))] =>
      assert_eq(v, 1)
    _ => fail("expected unreachable tail in block to be removed")
  }
}

///|
test "vacuum turns drop(if drop(..) else drop(..)) into drop(if value else value)" {
  let t_i32 = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i32()])),
  )
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let dropped_if = TInstr::drop(
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([TInstr::drop(TInstr::call(FuncIdx::new(0), []))]),
      Some(TExpr::new([TInstr::drop(TInstr::call(FuncIdx::new(1), []))])),
    ),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32, t_void]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("left"),
          ExternType::func(TypeIdx::new(0)),
        ),
        Import::new(
          Name::new("env"),
          Name::new("right"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([Func::t_func([ValType::i32()], TExpr::new([dropped_if]))]),
    )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).0 {
    [
      TDrop(
        TIf(ValTypeBlockType(NumTypeValType(I32NumType)), _, then_, Some(else_))
      ),
    ] =>
      match (then_.0, else_.0) {
        ([TCall(FuncIdx(a), [])], [TCall(FuncIdx(b), [])]) => {
          assert_eq(a, 0U)
          assert_eq(b, 1U)
        }
        _ => fail("expected value arms")
      }
    _ => fail("expected dropped arms rewrite")
  }
}

///|
test "vacuum removes try_table when body cannot throw" {
  let t_i32 = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i32()])),
  )
  let instr = TInstr::try_table(
    BlockType::val_type(ValType::i32()),
    [Catch::all(LabelIdx::new(0))],
    TExpr::new([TInstr::i32_const(I32(77))]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func([], TExpr::new([instr]))]))
  let out = run_vacuum(mod)
  match vq_first_func_body(out).0 {
    [TI32Const(I32(v))] => assert_eq(v, 77)
    _ => fail("expected throw-free try_table to fold to body")
  }
}

///|
test "vacuum keeps non-removable try_table body that may throw" {
  let instr = TInstr::try_table(
    BlockType::void_(),
    [Catch::all(LabelIdx::new(0))],
    TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([single_rec_type(comp_type_sub_type(func_comp_type([], [])))]),
    )
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
    .with_code_sec(CodeSec::new([Func::t_func([], TExpr::new([instr]))]))
  let out = run_vacuum(mod)
  match vq_first_func_body(out).0 {
    [TTryTable(_, _, _)] => ()
    _ => fail("expected throwing try_table to remain")
  }
}

///|
test "vacuum nops side-effect-free none-returning function body" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], TExpr::new([TInstr::i32_const(I32(1))]))]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).0 {
    [TNop] => ()
    _ => fail("expected side-effect-free function body to become nop")
  }
}

///|
test "vacuum is stable on nop-only function body across repeated runs" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
  )
  let once = run_vacuum(mod)
  let twice = run_vacuum(once)
  assert_eq(once, twice)
}
