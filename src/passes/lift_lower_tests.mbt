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
test "lower_to_expr_pass lowers TFunc locals and instructions" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32(), ValType::i32(), ValType::i64()],
        TExpr::new([
          TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(5))),
        ]),
      ),
    ]),
  )
  let lowered = run_lower_to_expr_pass(mod)
  match lowered.code_sec {
    Some(CodeSec([Func(locals, Expr(instrs))])) => {
      assert_eq(locals.length(), 2)
      let Locals(c0, t0) = locals[0]
      let Locals(c1, t1) = locals[1]
      assert_eq(c0, 2U)
      assert_eq(t0, ValType::i32())
      assert_eq(c1, 1U)
      assert_eq(t1, ValType::i64())
      assert_eq(instrs.length(), 2)
      match instrs[0] {
        I32Const(I32(v)) => assert_eq(v, 5)
        _ => fail("expected lowered value expression before local.set")
      }
      match instrs[1] {
        LocalSet(LocalIdx(i)) => assert_eq(i, 1U)
        _ => fail("expected lowered local.set instruction")
      }
    }
    _ => fail("expected lowered Func in code section")
  }
}

///|
test "lift_to_texpr_pass lifts Func body and expands locals" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::new(
        tlocals_to_locals([ValType::i32(), ValType::i32()]),
        Expr::new([
          Instruction::i32_const(I32(9)),
          Instruction::local_set(LocalIdx::new(1)),
        ]),
      ),
    ]),
  )
  let pass = lift_to_texpr_pass()
  let lifted = match pass.walk_module((), mod) {
    Ok(Some((_, m))) => m
    Ok(None) => fail("expected lifted module")
    Err(e) => fail("unexpected lift_to_texpr_pass error: \{e}")
  }
  match lifted.code_sec {
    Some(CodeSec([TFunc(locals, { instrs, .. })])) => {
      assert_eq(locals, [ValType::i32(), ValType::i32()])
      assert_eq(instrs.length(), 1)
      match instrs[0] {
        TLocalSet(LocalIdx(i), TI32Const(I32(v))) => {
          assert_eq(i, 1U)
          assert_eq(v, 9)
        }
        _ => fail("expected lifted local.set with nested const")
      }
    }
    _ => fail("expected lifted TFunc in code section")
  }
}

///|
test "lift_to_texpr_pass leaves existing TFunc unchanged" {
  let func = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let pass = lift_to_texpr_pass()
  let lifted = match pass.walk_module((), mod) {
    Ok(Some((_, m))) => m
    Ok(None) => fail("expected module result")
    Err(e) => fail("unexpected lift_to_texpr_pass error: \{e}")
  }
  match lifted.code_sec {
    Some(CodeSec([TFunc(_, { instrs: [TNop], .. })])) => ()
    _ => fail("expected existing TFunc to remain unchanged")
  }
}
