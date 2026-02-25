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
fn tu_mod_has_multivalue(mod : Module) -> Bool {
  match mod.type_sec {
    Some(TypeSec(recs)) => {
      for rec in recs {
        match rec {
          SingleRecType(st) =>
            match st.get_comptype() {
              FuncCompType(_, results) if results.length() > 1 => return true
              _ => ()
            }
          GroupRecType(sts) =>
            for st in sts {
              match st.get_comptype() {
                FuncCompType(_, results) if results.length() > 1 => return true
                _ => ()
              }
            }
        }
      }
      false
    }
    None => false
  }
}

///|
fn tuple_optimization_ir_pass(mod : Module) -> ModuleTransformer[IRContext] {
  if !tu_mod_has_multivalue(mod) {
    return ModuleTransformer::new()
  }
  // This IR does not model explicit tuple locals (`tuple.make` / `tuple.extract`),
  // so retain the proven multivalue fallback behavior for now.
  dataflow_optimization_pass(mod)
}

///|
fn tu_apply_ir_pass(
  mod : Module,
  pass : ModuleTransformer[IRContext],
) -> Result[Module, String] {
  let ctx = IRContext::new()
  match pass.walk_module(ctx, mod) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(mod)
    Err(e) => Err(e)
  }
}

///|
test "tuple optimization skips non-multivalue modules" {
  let body = TExpr::new([
    TInstr::local_set(
      LocalIdx::new(0),
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::i32_const(I32(40)),
        TInstr::i32_const(I32(2)),
      ),
    ),
    TInstr::return_([TInstr::local_get(LocalIdx::new(0))]),
  ])
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([ValType::i32()], body)]),
  )
  let out = match tu_apply_ir_pass(mod, tuple_optimization_ir_pass(mod)) {
    Ok(out) => out
    Err(e) => fail("tuple_optimization_ir_pass should not fail: \{e}")
  }
  assert_eq(out, mod)
}

///|
test "tuple optimization matches dataflow fallback when multivalue signatures exist" {
  let body = TExpr::new([
    TInstr::local_set(
      LocalIdx::new(0),
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::i32_const(I32(1)),
        TInstr::i32_const(I32(2)),
      ),
    ),
    TInstr::return_([TInstr::local_get(LocalIdx::new(0))]),
  ])
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        single_rec_type(
          comp_type_sub_type(func_comp_type([], [ValType::i32()])),
        ),
        single_rec_type(
          comp_type_sub_type(
            func_comp_type([], [ValType::i32(), ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new([Func::t_func([ValType::i32()], body)]))
  let tuple_out = match tu_apply_ir_pass(mod, tuple_optimization_ir_pass(mod)) {
    Ok(out) => out
    Err(e) => fail("tuple_optimization_ir_pass should not fail: \{e}")
  }
  let dataflow_out = match
    tu_apply_ir_pass(mod, dataflow_optimization_pass(mod)) {
    Ok(out) => out
    Err(e) => fail("dataflow_optimization_pass should not fail: \{e}")
  }
  assert_eq(tuple_out, dataflow_out)
}

///|
test "tuple optimization propagates dataflow non-texpr error for multivalue modules" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        single_rec_type(
          comp_type_sub_type(
            func_comp_type([], [ValType::i32(), ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([Func::new([], Expr::new([Instruction::nop()]))]),
    )
  match tu_apply_ir_pass(mod, tuple_optimization_ir_pass(mod)) {
    Err(e) => assert_eq(e, "Expected TFunc")
    _ => fail("expected multivalue tuple optimization to run dataflow and fail")
  }
}
