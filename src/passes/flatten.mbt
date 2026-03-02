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
priv struct FLBreakTempKey {
  label_uid : Int
  val_type : ValType
} derive(Eq, Hash)

///|
priv struct FLFuncState {
  mut env : Env
  locals : Array[ValType]
  break_temps : Map[FLBreakTempKey, LocalIdx]
  mut changed : Bool

  // Label identity stack: each control construct with a label gets a unique uid.
  label_uids : Array[Int]
  next_label_uid : Ref[Int]
}

///|
fn FLFuncState::new(env : Env, locals : Array[ValType]) -> FLFuncState {
  {
    env,
    locals,
    break_temps: Map::new(),
    changed: false,
    label_uids: [],
    next_label_uid: Ref::new(1),
  }
}

///|
fn fl_label_depth(label : LabelIdx) -> Int {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int()
}

///|
fn fl_bump_label(label : LabelIdx, delta : Int) -> LabelIdx {
  LabelIdx::new((fl_label_depth(label) + delta).reinterpret_as_uint())
}

///|
fn fl_push_label(state : FLFuncState) -> Int {
  let uid = state.next_label_uid.val
  state.next_label_uid.update(fn(i) { i + 1 })
  state.label_uids.push(uid)
  uid
}

///|
fn fl_pop_label(state : FLFuncState) -> Unit {
  if state.label_uids.length() > 0 {
    ignore(state.label_uids.pop())
  }
}

///|
fn fl_resolve_label_uid(state : FLFuncState, label : LabelIdx) -> Int? {
  let depth = fl_label_depth(label)
  let n = state.label_uids.length()
  // LabelIdx(0) refers to innermost enclosing label => last element.
  let idx = n - 1 - depth
  if idx < 0 || idx >= n {
    None
  } else {
    Some(state.label_uids[idx])
  }
}

///|
fn fl_add_temp_local(state : FLFuncState, ty : ValType) -> LocalIdx {
  let idx = LocalIdx::new(state.locals.length().reinterpret_as_uint())
  state.locals.push(ty)
  state.env = state.env.with_locals(state.locals)
  state.changed = true
  idx
}

///|
fn fl_get_break_temp(
  state : FLFuncState,
  label : LabelIdx,
  ty : ValType,
) -> LocalIdx {
  // IMPORTANT: resolve to stable label uid, not raw LabelIdx depth
  let uid = match fl_resolve_label_uid(state, label) {
    Some(u) => u
    None =>
      // Fallback: if something is malformed, still avoid crashing.
      // Use an impossible uid derived from depth (still better than conflating everything).
      // You may prefer to return an Err instead, but this keeps the signature.
      -1000000 - fl_label_depth(label)
  }
  let key = { label_uid: uid, val_type: ty }
  match state.break_temps.get(key) {
    Some(idx) => idx
    None => {
      let idx = fl_add_temp_local(state, ty)
      state.break_temps[key] = idx
      idx
    }
  }
}

///|
fn fl_instr_type(instr : TInstr, env : Env) -> ValType? {
  lcs_infer_tinstr_type(instr, env)
}

///|
/// Atomic leaves for flattening/idempotence.
/// These should not be wrapped into temp locals repeatedly.

///|
fn fl_is_leaf_constant_or_nop(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_)
    | TInstrKind::TLocalGet(_)
    | TInstrKind::TGlobalGet(_)
    | TInstrKind::TNop => true
    _ => false
  }
}

///|
/// Main flattening entry for expressions: unchanged signature.
fn fl_flatten_texpr(body : TExpr, state : FLFuncState) -> Result[TExpr, String] {
  let out : Array[TInstr] = []
  for instr in body.instrs {
    let (next_instr, preludes) = match fl_flatten_instr(instr, state) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    for prelude in preludes {
      out.push(prelude)
      state.changed = true
    }
    out.push(next_instr)
  }
  Ok(TExpr::new(out))
}

///|
fn fl_flatten_non_control_children(
  instr : TInstr,
  state : FLFuncState,
) -> Result[(TInstr, Array[TInstr]), String] {
  let children = eval_children(instr)
  if children.is_empty() {
    return Ok((instr, []))
  }
  let rebuilt_children : Array[TInstr] = []
  let preludes : Array[TInstr] = []
  let mut any_child_change = false
  for child in children {
    let (next_child, child_preludes) = match fl_flatten_instr(child, state) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    for p in child_preludes {
      preludes.push(p)
    }
    if next_child != child {
      any_child_change = true
    }
    rebuilt_children.push(next_child)
  }
  if any_child_change {
    state.changed = true
    Ok((mb_rebuild_non_control(instr, rebuilt_children), preludes))
  } else {
    Ok((instr, preludes))
  }
}

///|
fn fl_flatten_instr(
  instr : TInstr,
  state : FLFuncState,
) -> Result[(TInstr, Array[TInstr]), String] {
  if fl_is_leaf_constant_or_nop(instr) {
    return Ok((instr, []))
  }

  let mut curr = instr
  let preludes : Array[TInstr] = []

  match curr.kind {
    TInstrKind::TBlock(bt, body) => {
      // Enter label scope
      let my_uid = fl_push_label(state)

      let next_body = match fl_flatten_texpr(body, state) {
        Ok(v) => v
        Err(e) => {
          fl_pop_label(state)
          return Err(e)
        }
      }

      // If this block produces a value, lower it correctly:
      // - allocate temp
      // - rewrite all branches targeting this block (by uid) to store + branch with no values
      // - rewrite fallthrough value to store
      // - emit void block as a prelude, return local.get(temp)
      match bt {
        VoidBlockType => curr = TInstr::block(bt, next_body)
        _ =>
          // block has a result type (possibly val_type or type index); we only support single ValType here
          match fl_instr_type(TInstr::block(bt, next_body), state.env) {
            Some(vt) => {
              let temp = fl_add_temp_local(state, vt)

              // IMPORTANT: rewrite branch value flow targeting this block
              let rewritten1 = fl_rewrite_label_value_flow_in_texpr(
                next_body, state, my_uid, temp,
              )

              // Handle fallthrough result
              let rewritten2 = fl_rewrite_fallthrough_value_to_set(
                rewritten1,
                temp,
                state.env,
              )

              preludes.push(TInstr::block(BlockType::void_(), rewritten2))
              curr = TInstr::local_get(temp)
              state.changed = true
            }
            None =>
              // unexpected, but keep structure
              curr = TInstr::block(bt, next_body)
          }
      }

      // Leave label scope
      fl_pop_label(state)
    }
    TInstrKind::TLoop(bt, body) => {
      let my_uid = fl_push_label(state)

      let next_body = match fl_flatten_texpr(body, state) {
        Ok(v) => v
        Err(e) => {
          fl_pop_label(state)
          return Err(e)
        }
      }

      match bt {
        VoidBlockType => curr = TInstr::loop_(bt, next_body)
        _ =>
          match fl_instr_type(TInstr::loop_(bt, next_body), state.env) {
            Some(vt) => {
              let temp = fl_add_temp_local(state, vt)
              let rewritten1 = fl_rewrite_label_value_flow_in_texpr(
                next_body, state, my_uid, temp,
              )
              let rewritten2 = fl_rewrite_fallthrough_value_to_set(
                rewritten1,
                temp,
                state.env,
              )

              preludes.push(TInstr::loop_(BlockType::void_(), rewritten2))
              curr = TInstr::local_get(temp)
              state.changed = true
            }
            None => curr = TInstr::loop_(bt, next_body)
          }
      }

      fl_pop_label(state)
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let my_uid = fl_push_label(state)

      let next_body = match fl_flatten_texpr(body, state) {
        Ok(v) => v
        Err(e) => {
          fl_pop_label(state)
          return Err(e)
        }
      }

      match bt {
        VoidBlockType => curr = TInstr::try_table(bt, catches, next_body)
        _ =>
          match
            fl_instr_type(TInstr::try_table(bt, catches, next_body), state.env) {
            Some(vt) => {
              let temp = fl_add_temp_local(state, vt)
              let rewritten1 = fl_rewrite_label_value_flow_in_texpr(
                next_body, state, my_uid, temp,
              )
              let rewritten2 = fl_rewrite_fallthrough_value_to_set(
                rewritten1,
                temp,
                state.env,
              )

              preludes.push(
                TInstr::try_table(BlockType::void_(), catches, rewritten2),
              )
              curr = TInstr::local_get(temp)
              state.changed = true
            }
            None => curr = TInstr::try_table(bt, catches, next_body)
          }
      }

      fl_pop_label(state)
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      // Flatten condition first
      let (next_cond, cond_preludes) = match fl_flatten_instr(cond, state) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      for p in cond_preludes {
        preludes.push(p)
      }

      // Enter the if label scope for then/else bodies (br 0 targets end of if)
      let my_uid = fl_push_label(state)

      let next_then = match fl_flatten_texpr(then_body, state) {
        Ok(v) => v
        Err(e) => {
          fl_pop_label(state)
          return Err(e)
        }
      }
      let next_else = match else_body {
        Some(b) =>
          match fl_flatten_texpr(b, state) {
            Ok(v) => Some(v)
            Err(e) => {
              fl_pop_label(state)
              return Err(e)
            }
          }
        None => None
      }

      let mut rewritten_if = TInstr::if_(bt, next_cond, next_then, next_else)

      // Lower if result properly if it has a value:
      match fl_instr_type(rewritten_if, state.env) {
        Some(vt) => {
          let temp = fl_add_temp_local(state, vt)
          let then1 = fl_rewrite_label_value_flow_in_texpr(
            next_then, state, my_uid, temp,
          )
          let then2 = fl_rewrite_fallthrough_value_to_set(
            then1,
            temp,
            state.env,
          )

          let else2 = match next_else {
            Some(b) => {
              let else1 = fl_rewrite_label_value_flow_in_texpr(
                b, state, my_uid, temp,
              )
              fl_rewrite_fallthrough_value_to_set(else1, temp, state.env)
            }
            None =>
              return Err(
                "flatten: if with concrete result requires an else branch",
              )
          }

          rewritten_if = TInstr::if_(
            BlockType::void_(),
            next_cond,
            then2,
            Some(else2),
          )
          preludes.push(rewritten_if)
          curr = TInstr::local_get(temp)
          state.changed = true
        }
        None => curr = rewritten_if
      }

      fl_pop_label(state)
    }
    _ => {
      // Non-control: flatten children
      let (rebuilt, child_preludes) = match
        fl_flatten_non_control_children(curr, state) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      curr = rebuilt
      for p in child_preludes {
        preludes.push(p)
      }

      // Local tee lowering
      match curr.kind {
        TInstrKind::TLocalTee(idx, value) =>
          if is_unreachable_instr(value) {
            curr = value
            state.changed = true
          } else {
            preludes.push(TInstr::local_set(idx, value))
            curr = TInstr::local_get(idx)
            state.changed = true
          }
        _ => ()
      }

      // Branch value localization (stable label identity now)
      match curr.kind {
        TInstrKind::TBr(label, values) =>
          if values.length() == 1 {
            match fl_instr_type(values[0], state.env) {
              Some(vt) => {
                let temp = fl_get_break_temp(state, label, vt)
                preludes.push(TInstr::local_set(temp, values[0]))
                curr = TInstr::br(label, [TInstr::local_get(temp)])
                state.changed = true
              }
              None => ()
            }
          }
        TInstrKind::TBrIf(label, cond, values) =>
          if values.length() == 1 {
            match fl_instr_type(values[0], state.env) {
              Some(vt) => {
                let temp = fl_get_break_temp(state, label, vt)
                preludes.push(TInstr::local_set(temp, values[0]))
                curr = TInstr::br_if(label, cond, [TInstr::local_get(temp)])
                state.changed = true
              }
              None => ()
            }
          }
        TInstrKind::TBrOnNull(label, ref_, values) =>
          if values.length() == 1 {
            match fl_instr_type(values[0], state.env) {
              Some(vt) => {
                let temp = fl_get_break_temp(state, label, vt)
                preludes.push(TInstr::local_set(temp, values[0]))
                curr = TInstr::br_on_null(label, ref_, [TInstr::local_get(temp)])
                state.changed = true
              }
              None => ()
            }
          }
        TInstrKind::TBrOnNonNull(label, ref_, values) =>
          if values.length() == 1 {
            match fl_instr_type(values[0], state.env) {
              Some(vt) => {
                let temp = fl_get_break_temp(state, label, vt)
                preludes.push(TInstr::local_set(temp, values[0]))
                curr = TInstr::br_on_non_null(label, ref_, [
                  TInstr::local_get(temp),
                ])
                state.changed = true
              }
              None => ()
            }
          }
        TInstrKind::TBrOnCast(label, castop, ht1, ht2, ref_, values) =>
          if values.length() == 1 {
            match fl_instr_type(values[0], state.env) {
              Some(vt) => {
                let temp = fl_get_break_temp(state, label, vt)
                preludes.push(TInstr::local_set(temp, values[0]))
                curr = TInstr::br_on_cast(
                  label,
                  castop.0,
                  ht1,
                  castop.1,
                  ht2,
                  ref_,
                  [TInstr::local_get(temp)],
                )
                state.changed = true
              }
              None => ()
            }
          }
        TInstrKind::TBrOnCastFail(label, castop, ht1, ht2, ref_, values) =>
          if values.length() == 1 {
            match fl_instr_type(values[0], state.env) {
              Some(vt) => {
                let temp = fl_get_break_temp(state, label, vt)
                preludes.push(TInstr::local_set(temp, values[0]))
                curr = TInstr::br_on_cast_fail(
                  label,
                  castop.0,
                  ht1,
                  castop.1,
                  ht2,
                  ref_,
                  [TInstr::local_get(temp)],
                )
                state.changed = true
              }
              None => ()
            }
          }
        _ => ()
      }
    }
  }

  // Preserve unreachable handling
  if is_unreachable_instr(curr) {
    preludes.push(curr)
    state.changed = true
    return Ok((TInstr::unreachable_(), preludes))
  }

  // Final "wrap typed expr into temp" rule — but now idempotent via leaf predicate
  match fl_instr_type(curr, state.env) {
    Some(vt) =>
      if !fl_is_leaf_constant_or_nop(curr) {
        let temp = fl_add_temp_local(state, vt)
        preludes.push(TInstr::local_set(temp, curr))
        state.changed = true
        Ok((TInstr::local_get(temp), preludes))
      } else {
        Ok((curr, preludes))
      }
    None => Ok((curr, preludes))
  }
}

///|
fn fl_collect_param_types(mod : Module) -> Array[Array[ValType]] {
  let out : Array[Array[ValType]] = []
  let env = Env::new().with_module(mod)
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for tidx in type_idxs {
        match env.resolve_functype(tidx) {
          Some(FuncType(params, _)) => out.push(params)
          None => out.push([])
        }
      }
    None => ()
  }
  out
}

///|
fn flatten_ir_pass(mod : Module) -> ModuleTransformer[IRContext] {
  let param_types = fl_collect_param_types(mod)
  let next_def_idx = Ref::new(0)
  let base_env = Env::new().with_module(mod)
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    let def_idx = next_def_idx.val
    next_def_idx.update(fn(i) { i + 1 })
    match func {
      TFunc(locals, body) => {
        let params = param_types.get(def_idx).unwrap_or([])
        let all_locals = params.copy()
        for local_ in locals {
          all_locals.push(local_)
        }
        let state = FLFuncState::new(
          base_env.with_locals(all_locals),
          all_locals,
        )
        let next_body = match fl_flatten_texpr(body, state) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let next_non_param_locals : Array[ValType] = []
        for i in params.length()..<state.locals.length() {
          next_non_param_locals.push(state.locals[i])
        }
        if state.changed || next_non_param_locals.length() != locals.length() {
          change(ctx, Func::t_func(next_non_param_locals, next_body))
        } else {
          unchanged()
        }
      }
      _ => unchanged()
    }
  })
}

///|
fn run_flatten(mod : Module) -> Result[Module, String] {
  let pass = flatten_ir_pass(mod)
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(mod)
    Err(e) => Err(e)
  }
}

///|
fn fl_count_local_tees(body : TExpr) -> Int {
  let count = Ref::new(0)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr.kind {
      TInstrKind::TLocalTee(_, _) => count.update(fn(v) { v + 1 })
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  count.val
}

///|
test "flatten rewrites local.tee into set/get flat form" {
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
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(fl_count_local_tees(body), 0)
    _ => fail("expected flattened typed function")
  }
}

///|
test "flatten hoists if condition preludes and removes if value" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32(), ValType::i32()],
        TExpr::new([
          TInstr::drop(
            TInstr::if_(
              BlockType::val_type(ValType::i32()),
              TInstr::binary(
                BinaryOp::i32_eq(),
                TInstr::local_get(LocalIdx::new(0)),
                TInstr::i32_const(I32(1)),
              ),
              TExpr::new([TInstr::i32_const(I32(7))]),
              Some(TExpr::new([TInstr::i32_const(I32(8))])),
            ),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(locals, { instrs, .. })])) => {
      assert_true(locals.length() >= 2)
      let mut saw_if_void = false
      for instr in instrs {
        match instr.kind {
          TInstrKind::TIf(VoidBlockType, _, _, _) => saw_if_void = true
          _ => ()
        }
      }
      assert_true(saw_if_void)
    }
    _ => fail("expected flattened function output")
  }
}

///|
fn fl_count_br_on_family(body : TExpr) -> Int {
  let count = Ref::new(0)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr.kind {
      TInstrKind::TBrOnNull(_, _, _)
      | TInstrKind::TBrOnNonNull(_, _, _)
      | TInstrKind::TBrOnCast(_, _, _, _, _, _)
      | TInstrKind::TBrOnCastFail(_, _, _, _, _, _) =>
        count.update(fn(v) { v + 1 })
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  count.val
}

///|
fn fl_find_try_table_result_blocktype(body : TExpr) -> BlockType? {
  let found = Ref::new(None)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr.kind {
      TInstrKind::TTryTable(bt, _, _) =>
        match found.val {
          None => found.update(fn(_) { Some(bt) })
          Some(_) => ()
        }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  found.val
}

///|
/// Helper: rewrite fallthrough value (if the last instr produces a value) into
/// `local.set(temp, last)` so the surrounding construct can become void.
/// This is *necessary but not sufficient* for correctness; branch rewrites handle the rest.

///|
fn fl_rewrite_fallthrough_value_to_set(
  body : TExpr,
  temp : LocalIdx,
  env : Env,
) -> TExpr {
  let { instrs: items, .. } = body
  if items.length() == 0 {
    return body
  }
  let out = items.copy()
  let last_i = out.length() - 1
  let last = out[last_i]
  match fl_instr_type(last, env) {
    Some(_) => out[last_i] = TInstr::local_set(temp, last)
    None => ()
  }
  TExpr::new(out)
}

///|
/// Rewrite any branch-like instruction that targets `target_uid` and carries exactly
/// one value so that it stores into `temp` and branches with no values.
/// This removes value flow through label parameters after we lower the label to void.
///
/// NOTE: This rewrite is structural and uses the *current* label stack to resolve LabelIdx.
/// That’s why it’s a separate walk that pushes/pops label uids as it descends.

///|
fn fl_rewrite_label_value_flow_in_instr(
  instr : TInstr,
  state : FLFuncState,
  target_uid : Int,
  temp : LocalIdx,
) -> TInstr {
  // Push labels for control constructs before walking into their bodies, so
  // LabelIdx resolution is correct inside.
  match instr.kind {
    TInstrKind::TBlock(bt, body) => {
      let _uid = fl_push_label(state)
      let next_body = fl_rewrite_label_value_flow_in_texpr(
        body, state, target_uid, temp,
      )
      fl_pop_label(state)
      TInstr::block(bt, next_body)
    }
    TInstrKind::TLoop(bt, body) => {
      let _uid = fl_push_label(state)
      let next_body = fl_rewrite_label_value_flow_in_texpr(
        body, state, target_uid, temp,
      )
      fl_pop_label(state)
      TInstr::loop_(bt, next_body)
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let _uid = fl_push_label(state)
      let next_body = fl_rewrite_label_value_flow_in_texpr(
        body, state, target_uid, temp,
      )
      fl_pop_label(state)
      TInstr::try_table(bt, catches, next_body)
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let next_cond = fl_rewrite_label_value_flow_in_instr(
        cond, state, target_uid, temp,
      )
      let _uid = fl_push_label(state)
      let next_then = fl_rewrite_label_value_flow_in_texpr(
        then_body, state, target_uid, temp,
      )
      let next_else = match else_body {
        Some(b) =>
          Some(fl_rewrite_label_value_flow_in_texpr(b, state, target_uid, temp))
        None => None
      }
      fl_pop_label(state)
      TInstr::if_(bt, next_cond, next_then, next_else)
    }
    _ => {
      // First, recursively rewrite children in non-control instructions.
      // (Control instructions are handled above.)
      let children = eval_children(instr)
      if !children.is_empty() {
        let rebuilt : Array[TInstr] = []
        for child in children {
          rebuilt.push(
            fl_rewrite_label_value_flow_in_instr(child, state, target_uid, temp),
          )
        }
        let instr2 = mb_rebuild_non_control(instr, rebuilt)

        // Now rewrite branch-like forms at this node.
        fl_rewrite_branch_node(instr2, state, target_uid, temp)
      } else {
        fl_rewrite_branch_node(instr, state, target_uid, temp)
      }
    }
  }
}

///|
fn fl_rewrite_label_value_flow_in_texpr(
  body : TExpr,
  state : FLFuncState,
  target_uid : Int,
  temp : LocalIdx,
) -> TExpr {
  let out : Array[TInstr] = []
  for instr in body.instrs {
    out.push(
      fl_rewrite_label_value_flow_in_instr(instr, state, target_uid, temp),
    )
  }
  TExpr::new(out)
}

///|
/// Rewrite a single branch-like node if it targets `target_uid` and has exactly one value.
///
/// IMPORTANT: the sequencing wrapper introduces a new innermost label, so rewritten
/// branches must target `label + 1` to preserve the original control destination.

///|
fn fl_rewrite_branch_node(
  instr : TInstr,
  state : FLFuncState,
  target_uid : Int,
  temp : LocalIdx,
) -> TInstr {
  match instr.kind {
    TInstrKind::TBr(label, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::local_set(temp, values[0]),
                TInstr::br(bumped, []),
              ]),
            )
          }
          _ => instr
        }
      } else {
        instr
      }
    TInstrKind::TBrIf(label, cond, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::local_set(temp, values[0]),
                TInstr::br_if(bumped, cond, []),
              ]),
            )
          }
          _ => instr
        }
      } else {
        instr
      }
    TInstrKind::TBrOnNull(label, ref_, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::local_set(temp, values[0]),
                TInstr::br_on_null(bumped, ref_, []),
              ]),
            )
          }
          _ => instr
        }
      } else {
        instr
      }
    TInstrKind::TBrOnNonNull(label, ref_, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::local_set(temp, values[0]),
                TInstr::br_on_non_null(bumped, ref_, []),
              ]),
            )
          }
          _ => instr
        }
      } else {
        instr
      }
    TInstrKind::TBrOnCast(label, castop, ht1, ht2, ref_, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::local_set(temp, values[0]),
                TInstr::br_on_cast(bumped, castop.0, ht1, castop.1, ht2, ref_, []),
              ]),
            )
          }
          _ => instr
        }
      } else {
        instr
      }
    TInstrKind::TBrOnCastFail(label, castop, ht1, ht2, ref_, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::local_set(temp, values[0]),
                TInstr::br_on_cast_fail(
                  bumped,
                  castop.0,
                  ht1,
                  castop.1,
                  ht2,
                  ref_,
                  [],
                ),
              ]),
            )
          }
          _ => instr
        }
      } else {
        instr
      }
    _ => instr
  }
}

///|
test "flatten supports br_on family instructions and keeps them present" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::funcref()],
        TExpr::new([
          TInstr::drop(
            TInstr::br_on_null(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_non_null(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast(
              LabelIdx::new(0),
              true,
              HeapType::abs(AbsHeapType::func()),
              false,
              HeapType::abs(AbsHeapType::func()),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast_fail(
              LabelIdx::new(0),
              true,
              HeapType::abs(AbsHeapType::func()),
              false,
              HeapType::abs(AbsHeapType::func()),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(fl_count_br_on_family(body), 4)
    _ => fail("expected flattened function with br_on family instructions")
  }
}

///|
test "flatten rewrites br_on value flow through local temp when needed" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::funcref()],
        TExpr::new([
          TInstr::drop(
            TInstr::br_on_null(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [TInstr::i32_const(I32(17))],
            ),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      let saw_localized_value = Ref::new(false)
      let saw_set_of_const = Ref::new(false)
      let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
        self,
        _,
        instr,
      ) {
        match instr.kind {
          TInstrKind::TBrOnNull(_, _, [{ kind: TInstrKind::TLocalGet(_), .. }]) =>
            saw_localized_value.update(fn(_) { true })
          TInstrKind::TLocalSet(_, { kind: TInstrKind::TI32Const(I32(v)), .. }) if v ==
            17 => saw_set_of_const.update(fn(_) { true })
          _ => ()
        }
        self.walk_tinstruction_default((), instr)
      })
      ignore(walker.walk_texpr((), body))
      assert_true(saw_localized_value.val)
      assert_true(saw_set_of_const.val)
    }
    _ => fail("expected flattened br_on_null output")
  }
}

///|
test "flatten rewrites br_on value flow for all br_on variants" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::funcref()],
        TExpr::new([
          TInstr::drop(
            TInstr::br_on_null(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [TInstr::i32_const(I32(1))],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_non_null(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [TInstr::i32_const(I32(2))],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast(
              LabelIdx::new(0),
              true,
              HeapType::abs(AbsHeapType::func()),
              false,
              HeapType::abs(AbsHeapType::func()),
              TInstr::local_get(LocalIdx::new(0)),
              [TInstr::i32_const(I32(3))],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast_fail(
              LabelIdx::new(0),
              true,
              HeapType::abs(AbsHeapType::func()),
              false,
              HeapType::abs(AbsHeapType::func()),
              TInstr::local_get(LocalIdx::new(0)),
              [TInstr::i32_const(I32(4))],
            ),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      let localized_count = Ref::new(0)
      let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
        self,
        _,
        instr,
      ) {
        match instr.kind {
          TInstrKind::TBrOnNull(_, _, [{ kind: TInstrKind::TLocalGet(_), .. }])
          | TInstrKind::TBrOnNonNull(
            _,
            _,
            [{ kind: TInstrKind::TLocalGet(_), .. }]
          )
          | TInstrKind::TBrOnCast(
            _,
            _,
            _,
            _,
            _,
            [{ kind: TInstrKind::TLocalGet(_), .. }]
          )
          | TInstrKind::TBrOnCastFail(
            _,
            _,
            _,
            _,
            _,
            [{ kind: TInstrKind::TLocalGet(_), .. }]
          ) => localized_count.update(fn(v) { v + 1 })
          _ => ()
        }
        self.walk_tinstruction_default((), instr)
      })
      ignore(walker.walk_texpr((), body))
      assert_eq(localized_count.val, 4)
    }
    _ => fail("expected flattened br_on family output")
  }
}

///|
test "flatten supports try_table and removes try_table value result" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::drop(
            TInstr::try_table(
              BlockType::val_type(ValType::i32()),
              [Catch::all(LabelIdx::new(0))],
              TExpr::new([TInstr::i32_const(I32(12))]),
            ),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) =>
      match fl_find_try_table_result_blocktype(body) {
        Some(VoidBlockType) => ()
        Some(_) => fail("expected flattened try_table to have void blocktype")
        None => fail("expected try_table to remain present after flatten")
      }
    _ => fail("expected flattened try_table output")
  }
}

///|
test "flatten output with br_on_null and try_table remains valid and idempotent" {
  let target_sig = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let nullable_target_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let main_sig = single_rec_type(
    comp_type_sub_type(func_comp_type([nullable_target_ref], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([target_sig, main_sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::drop(
                  TInstr::br_on_null(
                    LabelIdx::new(0),
                    TInstr::local_get(LocalIdx::new(0)),
                    [],
                  ),
                ),
              ]),
            ),
            TInstr::drop(
              TInstr::try_table(
                BlockType::val_type(ValType::i32()),
                [],
                TExpr::new([TInstr::i32_const(I32(12))]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let once = run_flatten(mod).unwrap()
  let twice = run_flatten(mod).unwrap()
  assert_eq(once, twice)
  match validate_module(once) {
    Ok(_) => ()
    Err(e) =>
      fail("expected flattened br_on_null + try_table module to validate: \{e}")
  }
}

///|
fn fl_mk_valid_one_func_module(
  params : Array[ValType],
  results : Array[ValType],
  locals : Array[ValType],
  body : TExpr,
) -> Module {
  // Create a single rec type containing a single func type.
  // This matches the style you already use in the last test.
  let sig = single_rec_type(comp_type_sub_type(func_comp_type(params, results)))

  Module::new()
  .with_type_sec(TypeSec::new([sig]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(CodeSec::new([Func::t_func(locals, body)]))
}

///|
test "flatten: block result produced by br value remains valid" {
  let mod = fl_mk_valid_one_func_module(
    [], // params
    [], // results
    [], // locals
    TExpr::new([
      TInstr::drop(
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(7))]),
            TInstr::i32_const(I32(0)), // unreachable
          ]),
        ),
      ),
    ]),
  )

  let out = run_flatten(mod).unwrap()
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for block result via br; got validation error: \{e}",
      )
  }
}

///|
test "flatten: nested block br value remains valid" {
  let mod = fl_mk_valid_one_func_module(
    [],
    [],
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::br(LabelIdx::new(1), [TInstr::i32_const(I32(42))]),
              ]),
            ),
            TInstr::i32_const(I32(0)), // unreachable
          ]),
        ),
      ),
    ]),
  )

  let out = run_flatten(mod).unwrap()
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for nested br-to-outer-block-with-value; got: \{e}",
      )
  }
}

///|
test "flatten: idempotent on atomic local.get" {
  let mod = fl_mk_valid_one_func_module(
    [ValType::i32()], // params
    [], // results
    [], // locals
    TExpr::new([TInstr::drop(TInstr::local_get(LocalIdx::new(0)))]),
  )

  let once = run_flatten(mod).unwrap()
  let twice = run_flatten(once).unwrap()
  assert_eq(once, twice)

  match validate_module(twice) {
    Ok(_) => ()
    Err(e) => fail("expected flattened module to validate: \{e}")
  }
}

///|
test "flatten: result block with br inside if remains valid" {
  let mod = fl_mk_valid_one_func_module(
    [ValType::i32()], // params
    [],
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([
                TInstr::br(LabelIdx::new(1), [TInstr::i32_const(I32(9))]),
              ]),
              Some(TExpr::new([TInstr::nop()])),
            ),
            TInstr::i32_const(I32(0)),
          ]),
        ),
      ),
    ]),
  )

  let out = run_flatten(mod).unwrap()
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for br-with-value inside if to outer result block; got: \{e}",
      )
  }
}
