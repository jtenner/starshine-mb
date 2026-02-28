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
fn ml_run_merge_locals(mod : Module) -> Module {
  optimize_module(mod, [ModulePass::MergeLocals]).unwrap()
}

///|
fn ml_single_func_body(mod : Module) -> TExpr {
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      if funcs.length() == 1 {
        match funcs[0] {
          TFunc(_, body) => body
          _ => TExpr::new([])
        }
      } else {
        TExpr::new([])
      }
    None => TExpr::new([])
  }
}

///|
fn ml_trivial_tee_count(body : TExpr) -> Int {
  let mut count = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr.kind {
      TInstrKind::TLocalTee(idx, { kind: TInstrKind::TLocalGet(src), .. }) if idx ==
        src => count += 1
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  count
}

///|
fn ml_drop_get_indices(body : TExpr) -> Array[Int] {
  let out = Array::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr.kind {
      TInstrKind::TDrop({ kind: TInstrKind::TLocalGet(idx), .. }) => {
        let LocalIdx(raw) = idx
        out.push(raw.reinterpret_as_int())
      }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  out
}

///|
fn ml_many_copy_func(pair_count : Int) -> Func {
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let instrs = Array::new()
  for i in 0..<pair_count {
    instrs.push(TInstr::local_set(y, TInstr::i32_const(I32(i))))
    instrs.push(TInstr::local_set(x, TInstr::local_get(y)))
    instrs.push(TInstr::drop(TInstr::local_get(y)))
  }
  Func::t_func([ValType::i32(), ValType::i32()], TExpr::new(instrs))
}

///|
fn ml_simple_copy_func() -> Func {
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  Func::t_func(
    [ValType::i32(), ValType::i32()],
    TExpr::new([
      TInstr::local_set(y, TInstr::i32_const(I32(1))),
      TInstr::local_set(x, TInstr::local_get(y)),
      TInstr::drop(TInstr::local_get(y)),
    ]),
  )
}

///|
test "merge locals instrumentation is cleaned up" {
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let func = Func::t_func(
    [ValType::i32(), ValType::i32()],
    TExpr::new([
      TInstr::local_set(y, TInstr::i32_const(I32(1))),
      TInstr::local_set(x, TInstr::local_get(y)),
      TInstr::drop(TInstr::local_get(x)),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = ml_run_merge_locals(mod)
  let body = ml_single_func_body(out)
  assert_eq(ml_trivial_tee_count(body), 0)
  assert_eq(ml_drop_get_indices(body), [1])
}

///|
test "merge locals only instruments exact local.get copies with distinct indices" {
  let a = LocalIdx::new(0)
  let b = LocalIdx::new(1)
  let input_body = TExpr::new([
    TInstr::local_set(a, TInstr::i32_const(I32(9))),
    TInstr::local_set(
      b,
      TInstr::unary(UnaryOp::i32_eqz(), TInstr::local_get(a)),
    ),
    TInstr::local_set(a, TInstr::local_get(a)),
    TInstr::drop(TInstr::local_get(b)),
  ])
  let func = Func::t_func([ValType::i32(), ValType::i32()], input_body)
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = ml_run_merge_locals(mod)
  let body = ml_single_func_body(out)
  assert_eq(ml_trivial_tee_count(body), 0)
  assert_eq(body, input_body)
}

///|
test "merge locals optimize-to-copy rewrites y gets to x" {
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let func = Func::t_func(
    [ValType::i32(), ValType::i32()],
    TExpr::new([
      TInstr::local_set(y, TInstr::i32_const(I32(5))),
      TInstr::local_set(x, TInstr::local_get(y)),
      TInstr::drop(TInstr::local_get(y)),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = ml_run_merge_locals(mod)
  let body = ml_single_func_body(out)
  assert_eq(ml_trivial_tee_count(body), 0)
  assert_eq(ml_drop_get_indices(body), [1])
}

///|
test "merge locals optimize-to-copy rejects phi like reaches" {
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let func = Func::t_func(
    [ValType::i32(), ValType::i32()],
    TExpr::new([
      TInstr::local_set(y, TInstr::i32_const(I32(1))),
      TInstr::local_set(x, TInstr::local_get(y)),
      TInstr::if_(
        BlockType::void_(),
        TInstr::i32_const(I32(1)),
        TExpr::new([TInstr::local_set(y, TInstr::i32_const(I32(2)))]),
        Some(TExpr::new([TInstr::local_set(y, TInstr::i32_const(I32(3)))])),
      ),
      TInstr::drop(TInstr::local_get(y)),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = ml_run_merge_locals(mod)
  let body = ml_single_func_body(out)
  assert_eq(ml_drop_get_indices(body), [0])
}

///|
test "merge locals optimize-to-copy requires exact type equality" {
  let funcref_nullable = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let func = Func::t_func(
    [funcref_nullable, ValType::anyref()],
    TExpr::new([
      TInstr::local_set(y, TInstr::ref_null(HeapType::abs(AbsHeapType::func()))),
      TInstr::local_set(x, TInstr::local_get(y)),
      TInstr::drop(TInstr::local_get(y)),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = ml_run_merge_locals(mod)
  let body = ml_single_func_body(out)
  assert_eq(ml_drop_get_indices(body), [0])
}

///|
test "merge locals optimize-to-trivial rewrites x gets to y" {
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let func = Func::t_func(
    [ValType::i32(), ValType::i32()],
    TExpr::new([
      TInstr::local_set(y, TInstr::i32_const(I32(7))),
      TInstr::local_set(x, TInstr::local_get(y)),
      TInstr::drop(TInstr::local_get(y)),
      TInstr::drop(TInstr::local_get(x)),
      TInstr::if_(
        BlockType::void_(),
        TInstr::i32_const(I32(1)),
        TExpr::new([TInstr::local_set(y, TInstr::i32_const(I32(8)))]),
        None,
      ),
      TInstr::drop(TInstr::local_get(y)),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = ml_run_merge_locals(mod)
  let body = ml_single_func_body(out)
  let drops = ml_drop_get_indices(body)
  assert_eq(drops[1], 0)
}

///|
test "merge locals optimize-to-trivial rejects phi like reaches" {
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let func = Func::t_func(
    [ValType::i32(), ValType::i32()],
    TExpr::new([
      TInstr::local_set(y, TInstr::i32_const(I32(7))),
      TInstr::local_set(x, TInstr::local_get(y)),
      TInstr::drop(TInstr::local_get(y)),
      TInstr::if_(
        BlockType::void_(),
        TInstr::i32_const(I32(1)),
        TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(8)))]),
        Some(TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(9)))])),
      ),
      TInstr::drop(TInstr::local_get(x)),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = ml_run_merge_locals(mod)
  let body = ml_single_func_body(out)
  let drops = ml_drop_get_indices(body)
  assert_eq(drops[drops.length() - 1], 1)
}

///|
test "merge locals optimize-to-trivial requires exact type equality" {
  let funcref_nullable = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let func = Func::t_func(
    [funcref_nullable, ValType::anyref()],
    TExpr::new([
      TInstr::local_set(y, TInstr::ref_null(HeapType::abs(AbsHeapType::func()))),
      TInstr::local_set(x, TInstr::local_get(y)),
      TInstr::drop(TInstr::local_get(y)),
      TInstr::drop(TInstr::local_get(x)),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = ml_run_merge_locals(mod)
  let body = ml_single_func_body(out)
  assert_eq(ml_drop_get_indices(body), [0, 1])
}

///|
test "merge locals post verification undoes optimize-to-copy on conflict" {
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let func = Func::t_func(
    [ValType::i32(), ValType::i32()],
    TExpr::new([
      TInstr::local_set(y, TInstr::i32_const(I32(1))),
      TInstr::local_set(x, TInstr::local_get(y)),
      TInstr::local_set(x, TInstr::i32_const(I32(2))),
      TInstr::drop(TInstr::local_get(y)),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = ml_run_merge_locals(mod)
  let body = ml_single_func_body(out)
  assert_eq(ml_drop_get_indices(body), [0])
}

///|
test "merge locals post verification undoes optimize-to-trivial on conflict" {
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let func = Func::t_func(
    [ValType::i32(), ValType::i32()],
    TExpr::new([
      TInstr::local_set(y, TInstr::i32_const(I32(1))),
      TInstr::local_set(x, TInstr::local_get(y)),
      TInstr::drop(TInstr::local_get(y)),
      TInstr::local_set(y, TInstr::i32_const(I32(2))),
      TInstr::drop(TInstr::local_get(x)),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = ml_run_merge_locals(mod)
  let body = ml_single_func_body(out)
  let drops = ml_drop_get_indices(body)
  assert_eq(drops[drops.length() - 1], 1)
}

///|
test "merge locals applies rewrites all or nothing per copy" {
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let func = Func::t_func(
    [ValType::i32(), ValType::i32()],
    TExpr::new([
      TInstr::local_set(y, TInstr::i32_const(I32(1))),
      TInstr::local_set(x, TInstr::local_get(y)),
      TInstr::drop(TInstr::local_get(y)),
      TInstr::if_(
        BlockType::void_(),
        TInstr::i32_const(I32(1)),
        TExpr::new([TInstr::local_set(y, TInstr::i32_const(I32(3)))]),
        None,
      ),
      TInstr::drop(TInstr::local_get(y)),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = ml_run_merge_locals(mod)
  let body = ml_single_func_body(out)
  assert_eq(ml_drop_get_indices(body), [0, 0])
}

///|
test "merge locals handles multiple copy sites independently" {
  let a = LocalIdx::new(0)
  let b = LocalIdx::new(1)
  let c = LocalIdx::new(2)
  let d = LocalIdx::new(3)
  let func = Func::t_func(
    [ValType::i32(), ValType::i32(), ValType::i32(), ValType::i32()],
    TExpr::new([
      TInstr::local_set(a, TInstr::i32_const(I32(1))),
      TInstr::local_set(b, TInstr::local_get(a)),
      TInstr::drop(TInstr::local_get(a)),
      TInstr::local_set(c, TInstr::i32_const(I32(2))),
      TInstr::local_set(d, TInstr::local_get(c)),
      TInstr::drop(TInstr::local_get(c)),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = ml_run_merge_locals(mod)
  let body = ml_single_func_body(out)
  assert_eq(ml_drop_get_indices(body), [1, 3])
}

///|
test "merge locals is idempotent" {
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let func = Func::t_func(
    [ValType::i32(), ValType::i32()],
    TExpr::new([
      TInstr::local_set(y, TInstr::i32_const(I32(9))),
      TInstr::local_set(x, TInstr::local_get(y)),
      TInstr::drop(TInstr::local_get(y)),
      TInstr::drop(TInstr::local_get(x)),
    ]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let once = ml_run_merge_locals(mod)
  let twice = ml_run_merge_locals(once)
  assert_eq(twice, once)
}

///|
test "merge locals skips oversized copy-heavy function" {
  let func = ml_many_copy_func(5000)
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let out = ml_run_merge_locals(mod)
  assert_eq(out, mod)
}

///|
test "merge locals skips oversized module before per-function analysis" {
  let funcs = Array::new()
  for _ in 0..<401 {
    funcs.push(ml_simple_copy_func())
  }
  let mod = Module::new().with_code_sec(CodeSec::new(funcs))
  let out = ml_run_merge_locals(mod)
  assert_eq(out, mod)
}
