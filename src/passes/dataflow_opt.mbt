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
fn optimize_tfunc_with_ssa(
  ctx : IRContext,
  locals : Array[ValType],
  body : TExpr,
  trace? : (String) -> Unit = fn(_) { () },
) -> TExpr? {
  ctx.set_locals(locals)
  ctx.set_body(body)
  ctx.optimize_body_with_ssa_trace(trace)
}

///|
fn dataflow_now_ms() -> UInt64 {
  @env.now()
}

///|
fn dataflow_elapsed_ms(start_ms : UInt64) -> UInt64 {
  let end_ms = dataflow_now_ms()
  if end_ms >= start_ms {
    end_ms - start_ms
  } else {
    0UL
  }
}

///|
fn dataflow_optimization_pass(
  mod : Module,
  trace? : (String) -> Unit = fn(_) { () },
  trace_all_funcs? : Bool = false,
) -> ModuleTransformer[IRContext] {
  ignore(mod)
  let mut seen_funcs = 0
  ModuleTransformer::new().on_func_evt(fn(
    _self : ModuleTransformer[IRContext],
    ctx : IRContext,
    func : Func,
  ) -> TransformerResult[IRContext, Func] {
    seen_funcs += 1
    let ordinal = seen_funcs
    let log_func = trace_all_funcs || ordinal <= 5 || ordinal % 500 == 0
    match func {
      Func(_) => Err("Expected TFunc")
      TFunc(locals, body) => {
        if log_func {
          trace(
            "func[\{ordinal}] start locals=\{locals.length()} top_instrs=\{body.0.length()}",
          )
        }
        let opt_start = dataflow_now_ms()
        let new_body = optimize_tfunc_with_ssa(ctx, locals, body, trace=fn(
          msg,
        ) {
          if log_func {
            trace("func[\{ordinal}] \{msg}")
          }
        })
        let elapsed = dataflow_elapsed_ms(opt_start)
        let changed_func = match new_body {
          Some(next_body) => next_body != body
          None => false
        }
        if log_func {
          trace(
            "func[\{ordinal}] done elapsed_ms=\{elapsed} changed=\{changed_func} lowered=\{new_body is Some(_)}",
          )
        }
        match new_body {
          Some(next_body) if next_body != body =>
            change(ctx, Func::t_func(locals, next_body))
          // Returning `unchanged()` here would trigger `walk_func_default`,
          // causing a second full traversal of this function.
          _ => change(ctx, Func::t_func(locals, body))
        }
      }
    }
  })
}

///|
test "dataflow optimization pass folds simple constants via SSA" {
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
  let func = Func::t_func([ValType::i32()], body)
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let pass = dataflow_optimization_pass(mod)
  let ctx = IRContext::new()
  let result = pass.walk_module(ctx, mod)
  match result {
    Ok(Some((_, new_mod))) => {
      let CodeSec(funcs) = new_mod.code_sec.unwrap()
      match funcs[0] {
        TFunc(_, TExpr(instrs)) => {
          let mut found = false
          for instr in instrs {
            match instr {
              TLocalSet(_, TI32Const(I32(42))) => found = true
              _ => ()
            }
          }
          assert_true(found)
        }
        _ => fail("Expected TFunc")
      }
    }
    Ok(None) => fail("Expected module change")
    Err(e) => fail("Unexpected error: \{e}")
  }
}

///|
test "dataflow optimization pass simplifies const multi-block if" {
  let body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      TExpr::new([TInstr::return_([TInstr::i32_const(I32(7))])]),
      Some(TExpr::new([TInstr::return_([TInstr::i32_const(I32(9))])])),
    ),
  ])
  let func = Func::t_func([], body)
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let pass = dataflow_optimization_pass(mod)
  let ctx = IRContext::new()
  let result = pass.walk_module(ctx, mod)
  match result {
    Ok(None) => fail("Expected module change")
    Ok(Some((_, new_mod))) => {
      let CodeSec(funcs) = new_mod.code_sec.unwrap()
      match funcs[0] {
        TFunc(_, TExpr(instrs)) => {
          let mut has_if = false
          let mut has_unreachable = false
          for instr in instrs {
            match instr {
              TIf(_, _, _, _) => has_if = true
              TUnreachable => has_unreachable = true
              _ => ()
            }
          }
          assert_false(has_if)
          assert_true(has_unreachable)
        }
        _ => fail("Expected TFunc")
      }
    }
    Err(e) => fail("Unexpected error: \{e}")
  }
}

///|
test "dataflow optimization pass errors on non-texpr Func bodies" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::new([], Expr::new([Instruction::nop()]))]),
  )
  let pass = dataflow_optimization_pass(mod)
  let ctx = IRContext::new()
  let result = pass.walk_module(ctx, mod)
  match result {
    Err(e) => assert_eq(e, "Expected TFunc")
    _ => fail("expected non-TFunc input to return an error")
  }
}
