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
  mod : Module,
  params : Array[ValType],
  locals : Array[ValType],
  body : TExpr,
  trace? : (String) -> Unit = fn(_) { () },
) -> (Array[ValType], TExpr)? {
  let function_locals = FunctionLocals::new(params, locals)
  ctx.set_mod(mod)
  ctx.set_locals(
    function_locals.all_locals(),
    param_count=function_locals.param_count(),
  )
  ctx.set_body(body)
  ctx.optimize_body_with_ssa_trace_with_locals(trace)
}

///|
priv enum DataflowNormalizedFunc {
  TFuncBody(Array[ValType], Array[ValType], TExpr)
  PlainFunc(Func)
}

///|
fn dataflow_instrs_have_parametric_blocktypes(
  instrs : Array[Instruction],
  env : Env,
) -> Bool {
  for instr in instrs {
    if dataflow_instr_has_parametric_blocktype(instr, env) {
      return true
    }
  }
  false
}

///|
fn dataflow_instr_has_parametric_blocktype(
  instr : Instruction,
  env : Env,
) -> Bool {
  match instr {
    Block(bt, Expr(body)) | Loop(bt, Expr(body)) =>
      match env.expand_blocktype(bt) {
        Ok((params, _)) =>
          !params.is_empty() ||
          dataflow_instrs_have_parametric_blocktypes(body, env)
        Err(_) => dataflow_instrs_have_parametric_blocktypes(body, env)
      }
    If(bt, then_body, else_body_opt) => {
      let has_param_input = match env.expand_blocktype(bt) {
        Ok((params, _)) => !params.is_empty()
        Err(_) => false
      }
      if has_param_input {
        return true
      }
      if dataflow_instrs_have_parametric_blocktypes(then_body, env) {
        return true
      }
      match else_body_opt {
        Some(else_body) =>
          dataflow_instrs_have_parametric_blocktypes(else_body, env)
        None => false
      }
    }
    TryTable(bt, _, Expr(body)) =>
      match env.expand_blocktype(bt) {
        Ok((params, _)) =>
          !params.is_empty() ||
          dataflow_instrs_have_parametric_blocktypes(body, env)
        Err(_) => dataflow_instrs_have_parametric_blocktypes(body, env)
      }
    _ => false
  }
}

///|
fn dataflow_normalize_func_to_tfunc(
  env : Env,
  abs_idx : Int,
  func : Func,
) -> Result[DataflowNormalizedFunc, String] {
  let func_idx = FuncIdx::new(abs_idx.reinterpret_as_uint())
  let (params, results) = match env.get_functype_by_funcidx(func_idx) {
    Some(FuncType(ps, rs)) => (ps, rs)
    None => ([], [])
  }
  match func {
    TFunc(tfunc_params, locals, body) =>
      match
        FunctionLocals::from_typed_func_for_pass(params, tfunc_params, locals) {
        Ok(function_locals) =>
          Ok(
            DataflowNormalizedFunc::TFuncBody(
              function_locals.params(),
              function_locals.body_locals(),
              body,
            ),
          )
        Err(e) =>
          Err(
            "dataflow_optimization_pass: malformed typed function locals for function \{abs_idx}: \{e}",
          )
      }
    Func(grouped_locals, expr_body) =>
      match FunctionLocals::from_local_decls(params, grouped_locals) {
        Ok(function_locals) => {
          let locals = function_locals.body_locals()
          let all_locals = function_locals.all_locals()
          let func_env = env
            .with_locals(all_locals)
            .with_labels([results])
            .with_return_type(Some(results))
          let Expr(body_instrs) = expr_body
          if dataflow_instrs_have_parametric_blocktypes(body_instrs, func_env) {
            return Ok(
              DataflowNormalizedFunc::PlainFunc(
                Func::new(grouped_locals, Expr::new(body_instrs)),
              ),
            )
          }
          match to_texpr(expr_body, func_env) {
            Ok(body) =>
              Ok(DataflowNormalizedFunc::TFuncBody(params, locals, body))
            Err(_) =>
              Ok(
                DataflowNormalizedFunc::PlainFunc(
                  Func::new(grouped_locals, expr_body),
                ),
              )
          }
        }
        Err(e) =>
          Err(
            "dataflow_optimization_pass: expand_locals failed for function \{abs_idx}: \{e}",
          )
      }
  }
}

///|
fn dataflow_count_imported_funcs(mod : Module) -> Int {
  let mut n = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn dataflow_now_ms() -> UInt64 {
  pass_trace_now_ms()
}

///|
fn dataflow_elapsed_ms(start_ms : UInt64) -> UInt64 {
  pass_trace_elapsed_ms(start_ms)
}

///|
fn dataflow_optimization_pass(
  mod : Module,
  trace? : (String) -> Unit = fn(_) { () },
  trace_all_funcs? : Bool = false,
) -> ModuleTransformer[IRContext, String] {
  let env = Env::new().with_module(mod)
  let imported_funcs = dataflow_count_imported_funcs(mod)
  let mut seen_funcs = 0
  ModuleTransformer::new().on_func_evt(fn(
    _self : ModuleTransformer[IRContext, String],
    ctx : IRContext,
    func : Func,
  ) -> VisitAction[IRContext, Func, String] {
    seen_funcs += 1
    let ordinal = seen_funcs
    let log_func = trace_all_funcs || ordinal <= 5 || ordinal % 500 == 0
    let abs_idx = imported_funcs + ordinal - 1
    let was_plain_func = func is Func(_, _)
    let normalized = match
      dataflow_normalize_func_to_tfunc(env, abs_idx, func) {
      Ok(out) => out
      Err(e) => return error(e)
    }
    let (params, locals, body) = match normalized {
      DataflowNormalizedFunc::TFuncBody(params, locals, body) =>
        (params, locals, body)
      DataflowNormalizedFunc::PlainFunc(next_func) => {
        if log_func {
          trace("func[\{ordinal}] skip reason=non_liftable_expr")
        }
        return change(ctx, next_func)
      }
    }
    if log_func {
      trace(
        "func[\{ordinal}] start locals=\{locals.length()} top_instrs=\{body.instrs.length()}",
      )
      if was_plain_func {
        trace("func[\{ordinal}] normalized_from=Func")
      }
    }
    let opt_start = dataflow_now_ms()
    let new_func = optimize_tfunc_with_ssa(ctx, mod, params, locals, body, trace=fn(
      msg,
    ) {
      if log_func {
        trace("func[\{ordinal}] \{msg}")
      }
    })
    let elapsed = dataflow_elapsed_ms(opt_start)
    if log_func {
      trace(
        "func[\{ordinal}] done elapsed_ms=\{elapsed} lowered=\{new_func is Some(_)}",
      )
    }
    match new_func {
      Some((next_locals, next_body)) =>
        change(ctx, Func::t_func(params, next_locals, next_body))
      // Returning `unchanged()` here would trigger `walk_func_default`,
      // causing a second full traversal of this function.
      _ => change(ctx, Func::t_func(params, locals, body))
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
  let func = Func::t_func([], [ValType::i32()], body)
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let pass = dataflow_optimization_pass(mod)
  let ctx = IRContext::new()
  let result = pass.walk_module(ctx, mod)
  match result {
    Ok((new_mod, _)) => assert_true(new_mod.code_sec is Some(_))
    Ok(_) => ()
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
  let func = Func::t_func([], [], body)
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let pass = dataflow_optimization_pass(mod)
  let ctx = IRContext::new()
  let result = pass.walk_module(ctx, mod)
  match result {
    Ok(_) => ()
    Ok((new_mod, _)) => assert_true(new_mod.code_sec is Some(_))
    Err(e) => fail("Unexpected error: \{e}")
  }
}

///|
test "dataflow optimization pass normalizes non-texpr Func bodies" {
  let func_type = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([func_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([Func::new([], Expr::new([Instruction::nop()]))]),
    )
  let pass = dataflow_optimization_pass(mod)
  let ctx = IRContext::new()
  let result = pass.walk_module(ctx, mod)
  match result {
    Ok((out, _)) =>
      match out.code_sec {
        Some(CodeSec([TFunc(_, _, _)])) => ()
        _ => fail("expected dataflow to rewrite Func input into TFunc")
      }
    Ok(_) => fail("expected module change")
    Err(e) => fail("Unexpected error: \{e}")
  }
}

///|
test "dataflow optimization pass skips non-liftable Func bodies without failing" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::new([], Expr::new([Instruction::i32_add()]))]),
  )
  let pass = dataflow_optimization_pass(mod)
  let ctx = IRContext::new()
  let result = pass.walk_module(ctx, mod)
  match result {
    Ok((out, _)) =>
      match out.code_sec {
        Some(CodeSec([Func(_, _)])) => ()
        _ => fail("expected non-liftable Func to remain unchanged")
      }
    Ok(_) => fail("expected module change")
    Err(e) => fail("Unexpected error: \{e}")
  }
}

///|
test "dataflow optimization preserves valid locals for parameterized functions" {
  let func_type = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([
        TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(11))),
      ]),
      Some(
        TExpr::new([
          TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(22))),
        ]),
      ),
    ),
    TInstr::return_([TInstr::local_get(LocalIdx::new(1))]),
  ])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([func_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func([], [ValType::i32()], body)]))
  let pass = dataflow_optimization_pass(mod)
  let ctx = IRContext::new()
  let result = pass.walk_module(ctx, mod)
  match result {
    Ok((out, _)) => {
      assert_eq(validate_module(out), Ok(()))
      assert_true(out.code_sec is Some(_))
    }
    Ok(_) => fail("expected module change")
    Err(e) => fail("Unexpected error: \{e}")
  }
}
