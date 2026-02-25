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
fn ut_localidx_to_int(idx : LocalIdx) -> Int {
  let LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn ut_collect_param_types(mod : Module) -> Array[Array[ValType]] {
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
fn ut_rewrite_texpr(
  expr : TExpr,
  local_types : Array[ValType],
) -> (TExpr, Bool) {
  let out : Array[TInstr] = []
  let mut changed = false
  for instr in expr.0 {
    let (next_instr, instr_changed) = ut_rewrite_tinstr(instr, local_types)
    out.push(next_instr)
    if instr_changed {
      changed = true
    }
  }
  if changed {
    (TExpr::new(out), true)
  } else {
    (expr, false)
  }
}

///|
fn ut_rewrite_tinstr(
  instr : TInstr,
  local_types : Array[ValType],
) -> (TInstr, Bool) {
  match instr {
    TLocalTee(idx, value) => {
      let (next_value, value_changed) = ut_rewrite_tinstr(value, local_types)
      if is_unreachable_instr(next_value) {
        (next_value, true)
      } else {
        let local_i = ut_localidx_to_int(idx)
        match local_types.get(local_i) {
          Some(local_type) => {
            let lowered = TInstr::block(
              BlockType::val_type(local_type),
              TExpr::new([
                TInstr::local_set(idx, next_value),
                TInstr::local_get(idx),
              ]),
            )
            (lowered, true)
          }
          None => {
            let rebuilt = TInstr::local_tee(idx, next_value)
            if value_changed {
              (rebuilt, true)
            } else {
              (instr, false)
            }
          }
        }
      }
    }
    TBlock(bt, body) => {
      let (next_body, changed) = ut_rewrite_texpr(body, local_types)
      if changed {
        (TInstr::block(bt, next_body), true)
      } else {
        (instr, false)
      }
    }
    TLoop(bt, body) => {
      let (next_body, changed) = ut_rewrite_texpr(body, local_types)
      if changed {
        (TInstr::loop_(bt, next_body), true)
      } else {
        (instr, false)
      }
    }
    TIf(bt, cond, then_body, else_body) => {
      let (next_cond, cond_changed) = ut_rewrite_tinstr(cond, local_types)
      let (next_then, then_changed) = ut_rewrite_texpr(then_body, local_types)
      let (next_else, else_changed) = match else_body {
        Some(other) => {
          let (rewritten, changed) = ut_rewrite_texpr(other, local_types)
          (Some(rewritten), changed)
        }
        None => (None, false)
      }
      if cond_changed || then_changed || else_changed {
        (TInstr::if_(bt, next_cond, next_then, next_else), true)
      } else {
        (instr, false)
      }
    }
    TTryTable(bt, catches, body) => {
      let (next_body, changed) = ut_rewrite_texpr(body, local_types)
      if changed {
        (TInstr::try_table(bt, catches, next_body), true)
      } else {
        (instr, false)
      }
    }
    _ => {
      let children = eval_children(instr)
      if children.is_empty() {
        return (instr, false)
      }
      let rewritten : Array[TInstr] = []
      let mut changed = false
      for child in children {
        let (next_child, child_changed) = ut_rewrite_tinstr(child, local_types)
        rewritten.push(next_child)
        if child_changed {
          changed = true
        }
      }
      if changed {
        (mb_rebuild_non_control(instr, rewritten), true)
      } else {
        (instr, false)
      }
    }
  }
}

///|
fn untee_pass(func : Func, params : Array[ValType]) -> (Func, Bool) {
  match func {
    TFunc(locals, body) => {
      let local_types = params.copy()
      for local_ in locals {
        local_types.push(local_)
      }
      let (next_body, changed) = ut_rewrite_texpr(body, local_types)
      if changed {
        (Func::t_func(locals, next_body), true)
      } else {
        (func, false)
      }
    }
    _ => (func, false)
  }
}

///|
fn untee_ir_pass(mod : Module) -> ModuleTransformer[IRContext] {
  let param_types = ut_collect_param_types(mod)
  let next_def_idx = Ref::new(0)
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    let def_idx = next_def_idx.val
    next_def_idx.update(fn(i) { i + 1 })
    let params = param_types.get(def_idx).unwrap_or([])
    let (next_func, changed) = untee_pass(func, params)
    if changed {
      change(ctx, next_func)
    } else {
      unchanged()
    }
  })
}

///|
fn run_untee(mod : Module) -> Module {
  let pass = untee_ir_pass(mod)
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => out
    Ok(None) => mod
    Err(e) => abort("untee pass failed: \{e}")
  }
}

///|
test "untee rewrites local.tee into result-typed block with set/get" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32()],
        TExpr::new([
          TInstr::drop(
            TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(7))),
          ),
        ]),
      ),
    ]),
  )
  let out = run_untee(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TBlock(block_type, TExpr(instrs)))]))])) => {
      match block_type {
        ValTypeBlockType(vt) => assert_eq(vt, ValType::i32())
        _ => fail("expected result-typed block")
      }
      match instrs {
        [
          TLocalSet(LocalIdx(set_i), TI32Const(I32(v))),
          TLocalGet(LocalIdx(get_i)),
        ] => {
          assert_eq(set_i, 0U)
          assert_eq(get_i, 0U)
          assert_eq(v, 7)
        }
        _ => fail("expected local.set/local.get block body")
      }
    }
    _ => fail("expected local.tee to be lowered into block(set,get)")
  }
}

///|
test "untee drops unreachable local.tee to unreachable value" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32()],
        TExpr::new([
          TInstr::drop(
            TInstr::local_tee(LocalIdx::new(0), TInstr::unreachable_()),
          ),
        ]),
      ),
    ]),
  )
  let out = run_untee(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TUnreachable)]))])) => ()
    _ => fail("expected unreachable local.tee to become unreachable child")
  }
}

///|
test "untee uses parameter local type for block result" {
  let func_type = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([func_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(11))),
            ),
          ]),
        ),
      ]),
    )
  let out = run_untee(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TBlock(block_type, _))]))])) =>
      match block_type {
        ValTypeBlockType(vt) => assert_eq(vt, ValType::i32())
        _ => fail("expected i32 block type for param local.tee")
      }
    _ => fail("expected lowered local.tee")
  }
}
