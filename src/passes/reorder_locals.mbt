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
fn rl_localidx_to_int(idx : LocalIdx) -> Int {
  let LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn rl_localidx_from_int(idx : Int) -> LocalIdx {
  LocalIdx::new(idx.reinterpret_as_uint())
}

///|
fn rl_collect_param_counts(mod : Module) -> Array[Int] {
  let out : Array[Int] = []
  let env = Env::new().with_module(mod)
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for tidx in type_idxs {
        match env.resolve_functype(tidx) {
          Some(FuncType(params, _)) => out.push(params.length())
          None => out.push(0)
        }
      }
    None => ()
  }
  out
}

///|
fn rl_scan_local_uses(
  body : TExpr,
  counts : Array[Int],
  first_uses : Array[Int],
) -> Result[Unit, String] {
  let first_use_index = Ref::new(1)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let bump = fn(idx : LocalIdx) {
      let raw = rl_localidx_to_int(idx)
      if raw >= 0 && raw < counts.length() {
        counts[raw] = counts[raw] + 1
        if first_uses[raw] == 0 {
          first_uses[raw] = first_use_index.val
          first_use_index.update(fn(i) { i + 1 })
        }
      }
    }
    match instr.kind {
      TInstrKind::TLocalGet(idx) => bump(idx)
      TInstrKind::TLocalSet(idx, _) => bump(idx)
      TInstrKind::TLocalTee(idx, _) => bump(idx)
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  match walker.walk_texpr((), body) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
fn rl_remap_local_indices(
  body : TExpr,
  old_to_new : Array[Int],
) -> Result[TExpr, String] {
  let rewriter = ModuleTransformer::new().on_localidx_evt(fn(_, _, idx) {
    let raw = rl_localidx_to_int(idx)
    if raw < 0 || raw >= old_to_new.length() {
      return unchanged()
    }
    let mapped = old_to_new[raw]
    if mapped == raw || mapped < 0 {
      unchanged()
    } else {
      change((), rl_localidx_from_int(mapped))
    }
  })
  match rewriter.walk_texpr((), body) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(body)
    Err(e) => Err(e)
  }
}

///|
fn rl_reorder_function(func : Func, param_count : Int) -> (Func, Bool) {
  match func {
    TFunc(locals, body) => {
      if locals.is_empty() {
        return (func, false)
      }
      let num = param_count + locals.length()
      let counts = Array::make(num, 0)
      let first_uses = Array::make(num, 0)
      match rl_scan_local_uses(body, counts, first_uses) {
        Ok(_) => ()
        Err(_) => return (func, false)
      }
      let new_to_old : Array[Int] = []
      for i = 0; i < num; i = i + 1 {
        new_to_old.push(i)
      }
      new_to_old.sort_by(fn(a, b) {
        let a_is_param = a < param_count
        let b_is_param = b < param_count
        if a_is_param && !b_is_param {
          -1
        } else if b_is_param && !a_is_param {
          1
        } else if a_is_param && b_is_param {
          a - b
        } else {
          let ca = counts[a]
          let cb = counts[b]
          if ca == cb {
            if ca == 0 {
              a - b
            } else {
              first_uses[a] - first_uses[b]
            }
          } else {
            cb - ca
          }
        }
      })
      for i = 0; i < param_count && i < new_to_old.length(); i = i + 1 {
        new_to_old[i] = i
      }
      let kept_new_to_old : Array[Int] = []
      for i = 0; i < param_count; i = i + 1 {
        kept_new_to_old.push(i)
      }
      let reordered_locals : Array[ValType] = []
      let mut i = param_count
      while i < new_to_old.length() {
        let old_idx = new_to_old[i]
        if counts[old_idx] > 0 {
          kept_new_to_old.push(old_idx)
          reordered_locals.push(locals[old_idx - param_count])
        } else {
          break
        }
        i = i + 1
      }
      let old_to_new = Array::make(num, -1)
      for i = 0; i < kept_new_to_old.length(); i = i + 1 {
        if i < param_count {
          old_to_new[i] = i
        } else {
          old_to_new[kept_new_to_old[i]] = i
        }
      }
      let next_body = match rl_remap_local_indices(body, old_to_new) {
        Ok(out) => out
        Err(_) => body
      }
      let next_func = Func::t_func(reordered_locals, next_body)
      if next_func == func {
        (func, false)
      } else {
        (next_func, true)
      }
    }
    _ => (func, false)
  }
}

///|
fn reorder_locals_ir_pass(mod : Module) -> ModuleTransformer[IRContext] {
  let param_counts = rl_collect_param_counts(mod)
  let next_def_idx = Ref::new(0)
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    let def_idx = next_def_idx.val
    next_def_idx.update(fn(i) { i + 1 })
    let param_count = param_counts.get(def_idx).unwrap_or(0)
    let (next_func, changed) = rl_reorder_function(func, param_count)
    if changed {
      change(ctx, next_func)
    } else {
      unchanged()
    }
  })
}

///|
fn run_reorder_locals(mod : Module) -> Module {
  let pass = reorder_locals_ir_pass(mod)
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => out
    Ok(None) => mod
    Err(e) => abort("reorder_locals_ir_pass failed: \{e}")
  }
}

///|
test "reorder_locals reorders vars by use count then first use and drops unused vars" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32(), ValType::i64(), ValType::f32(), ValType::f64()],
        TExpr::new([
          TInstr::local_set(LocalIdx::new(2), TInstr::i32_const(I32(0))),
          TInstr::drop(TInstr::local_get(LocalIdx::new(1))),
          TInstr::drop(TInstr::local_get(LocalIdx::new(2))),
          TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
        ]),
      ),
    ]),
  )
  let out = run_reorder_locals(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(locals, { instrs, .. })])) => {
      assert_eq(locals.length(), 3)
      assert_eq(locals[0], ValType::f32())
      assert_eq(locals[1], ValType::i32())
      assert_eq(locals[2], ValType::i64())
      match instrs {
        [
          {
            kind: TInstrKind::TLocalSet(
              LocalIdx(s0),
              { kind: TInstrKind::TI32Const(I32(0)), .. }
            ),
            ..,
          },
          {
            kind: TInstrKind::TDrop(
              { kind: TInstrKind::TLocalGet(LocalIdx(g0)), .. }
            ),
            ..,
          },
          {
            kind: TInstrKind::TDrop(
              { kind: TInstrKind::TLocalGet(LocalIdx(g1)), .. }
            ),
            ..,
          },
          {
            kind: TInstrKind::TDrop(
              { kind: TInstrKind::TLocalGet(LocalIdx(g2)), .. }
            ),
            ..,
          },
          {
            kind: TInstrKind::TLocalSet(
              LocalIdx(s1),
              { kind: TInstrKind::TI32Const(I32(1)), .. }
            ),
            ..,
          },
        ] => {
          assert_eq(s0, 0U)
          assert_eq(g0, 2U)
          assert_eq(g1, 0U)
          assert_eq(g2, 1U)
          assert_eq(s1, 1U)
        }
        _ => fail("unexpected reordered local index pattern")
      }
    }
    _ => fail("expected single typed function")
  }
}

///|
test "reorder_locals keeps params fixed and only reorders declared locals" {
  let sig = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i32(), ValType::i64()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::f32(), ValType::f64()],
          TExpr::new([
            TInstr::drop(TInstr::local_get(LocalIdx::new(3))),
            TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
          ]),
        ),
      ]),
    )
  let out = run_reorder_locals(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(locals, { instrs, .. })])) => {
      assert_eq(locals, [ValType::f64()])
      match instrs {
        [
          {
            kind: TInstrKind::TDrop(
              { kind: TInstrKind::TLocalGet(LocalIdx(i0)), .. }
            ),
            ..,
          },
          {
            kind: TInstrKind::TDrop(
              { kind: TInstrKind::TLocalGet(LocalIdx(i1)), .. }
            ),
            ..,
          },
        ] => {
          assert_eq(i0, 2U)
          assert_eq(i1, 0U)
        }
        _ => fail("expected local index rewrites with params preserved")
      }
    }
    _ => fail("expected single typed function")
  }
}
