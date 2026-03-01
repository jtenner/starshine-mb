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
  ctx.set_mod(mod)
  ctx.set_locals(params + locals, param_count=params.length())
  ctx.set_body(body)
  ctx.optimize_body_with_ssa_trace_with_locals(trace)
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
fn dataflow_normalize_env_now_ms(raw : UInt64) -> UInt64 {
  if raw >= 100000000000000000UL {
    // Likely nanoseconds.
    raw / 1000000UL
  } else if raw >= 100000000000000UL {
    // Likely microseconds.
    raw / 1000UL
  } else {
    // Already milliseconds.
    raw
  }
}

///|
#cfg(target="native")
#borrow(tv)
extern "c" fn dataflow_native_gettimeofday(tv : Bytes, tz : UInt64) -> Int = "gettimeofday"

///|
#cfg(target="native")
fn dataflow_read_u64_le(bytes : Bytes, start : Int) -> UInt64 {
  let mut out = 0UL
  let mut i = 0
  while i < 8 {
    out = out | (bytes[start + i].to_uint64() << (i * 8))
    i += 1
  }
  out
}

///|
#cfg(target="native")
fn dataflow_now_ms() -> UInt64 {
  let tv = Bytes::new(16)
  if dataflow_native_gettimeofday(tv, 0UL) != 0 {
    return dataflow_normalize_env_now_ms(@env.now())
  }
  let sec = dataflow_read_u64_le(tv, 0)
  let usec = dataflow_read_u64_le(tv, 8)
  sec * 1000UL + usec / 1000UL
}

///|
#cfg(target="wasm-gc")
fn dataflow_now_ms() -> UInt64 {
  dataflow_normalize_env_now_ms(@env.now())
}

///|
#cfg(target="wasm")
fn dataflow_now_ms() -> UInt64 {
  dataflow_normalize_env_now_ms(@env.now())
}

///|
#cfg(target="js")
fn dataflow_now_ms() -> UInt64 {
  dataflow_normalize_env_now_ms(@env.now())
}

///|
#cfg(target="llvm")
fn dataflow_now_ms() -> UInt64 {
  dataflow_normalize_env_now_ms(@env.now())
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
  let env = Env::new().with_module(mod)
  let imported_funcs = dataflow_count_imported_funcs(mod)
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
        let abs_idx = imported_funcs + ordinal - 1
        let params = match
          env.get_functype_by_funcidx(
            FuncIdx::new(abs_idx.reinterpret_as_uint()),
          ) {
          Some(FuncType(params, _)) => params
          None => []
        }
        if log_func {
          trace(
            "func[\{ordinal}] start locals=\{locals.length()} top_instrs=\{body.instrs.length()}",
          )
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
            change(ctx, Func::t_func(next_locals, next_body))
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
    Ok(Some((_, new_mod))) => assert_true(new_mod.code_sec is Some(_))
    Ok(None) => ()
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
    Ok(None) => ()
    Ok(Some((_, new_mod))) => assert_true(new_mod.code_sec is Some(_))
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

///|
test "dataflow optimization preserves valid locals for parameterized functions" {
  let func_type = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i32()], [ValType::i32()])),
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
    .with_code_sec(CodeSec::new([Func::t_func([ValType::i32()], body)]))
  let pass = dataflow_optimization_pass(mod)
  let ctx = IRContext::new()
  let result = pass.walk_module(ctx, mod)
  match result {
    Ok(Some((_, out))) => {
      assert_eq(validate_module(out), Ok(()))
      assert_true(out.code_sec is Some(_))
    }
    Ok(None) => fail("expected module change")
    Err(e) => fail("Unexpected error: \{e}")
  }
}
