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
  label_depth : Int
  val_type : ValType
} derive(Eq, Hash)

///|
priv struct FLFuncState {
  mut env : Env
  locals : Array[ValType]
  break_temps : Map[FLBreakTempKey, LocalIdx]
  mut changed : Bool
}

///|
fn FLFuncState::new(env : Env, locals : Array[ValType]) -> FLFuncState {
  { env, locals, break_temps: Map::new(), changed: false }
}

///|
fn fl_label_depth(label : LabelIdx) -> Int {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int()
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
  let key = { label_depth: fl_label_depth(label), val_type: ty }
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
fn fl_is_leaf_constant_or_nop(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_)
    | TInstrKind::TNop => true
    _ => false
  }
}

///|
fn fl_rewrite_last_value_to_set(
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
      let next_body = match fl_flatten_texpr(body, state) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      curr = TInstr::block(bt, next_body)
      match fl_instr_type(curr, state.env) {
        Some(vt) => {
          let temp = fl_add_temp_local(state, vt)
          let lowered = fl_rewrite_last_value_to_set(next_body, temp, state.env)
          preludes.push(TInstr::block(BlockType::void_(), lowered))
          curr = TInstr::local_get(temp)
          state.changed = true
        }
        None => ()
      }
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let (next_cond, cond_preludes) = match fl_flatten_instr(cond, state) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let next_then = match fl_flatten_texpr(then_body, state) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let next_else = match else_body {
        Some(other) =>
          match fl_flatten_texpr(other, state) {
            Ok(v) => Some(v)
            Err(e) => return Err(e)
          }
        None => None
      }
      let mut rewritten_if = TInstr::if_(bt, next_cond, next_then, next_else)
      for p in cond_preludes {
        preludes.push(p)
      }
      match fl_instr_type(rewritten_if, state.env) {
        Some(vt) => {
          let temp = fl_add_temp_local(state, vt)
          let lowered_then = fl_rewrite_last_value_to_set(
            next_then,
            temp,
            state.env,
          )
          let lowered_else = match next_else {
            Some(other) =>
              Some(fl_rewrite_last_value_to_set(other, temp, state.env))
            None =>
              return Err(
                "flatten: if with concrete result requires an else branch",
              )
          }
          rewritten_if = TInstr::if_(
            BlockType::void_(),
            next_cond,
            lowered_then,
            lowered_else,
          )
          preludes.push(rewritten_if)
          curr = TInstr::local_get(temp)
          state.changed = true
        }
        None => curr = rewritten_if
      }
    }
    TInstrKind::TLoop(bt, body) => {
      let next_body = match fl_flatten_texpr(body, state) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      curr = TInstr::loop_(bt, next_body)
      match fl_instr_type(curr, state.env) {
        Some(vt) => {
          let temp = fl_add_temp_local(state, vt)
          let lowered = fl_rewrite_last_value_to_set(next_body, temp, state.env)
          preludes.push(TInstr::loop_(BlockType::void_(), lowered))
          curr = TInstr::local_get(temp)
          state.changed = true
        }
        None => ()
      }
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let next_body = match fl_flatten_texpr(body, state) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      curr = TInstr::try_table(bt, catches, next_body)
      match fl_instr_type(curr, state.env) {
        Some(vt) => {
          let temp = fl_add_temp_local(state, vt)
          let lowered = fl_rewrite_last_value_to_set(next_body, temp, state.env)
          preludes.push(TInstr::try_table(BlockType::void_(), catches, lowered))
          curr = TInstr::local_get(temp)
          state.changed = true
        }
        None => ()
      }
    }
    _ => {
      let (rebuilt, child_preludes) = match
        fl_flatten_non_control_children(curr, state) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      curr = rebuilt
      for p in child_preludes {
        preludes.push(p)
      }

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

  if is_unreachable_instr(curr) {
    preludes.push(curr)
    state.changed = true
    return Ok((TInstr::unreachable_(), preludes))
  }

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
