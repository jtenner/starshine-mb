///|
priv struct DeNaNState {
  in_func : Bool
  need_f32 : Bool
  need_f64 : Bool
  deNan32 : FuncIdx?
  deNan64 : FuncIdx?
}

///|
fn is_f32_nan(f : F32) -> Bool {
  let x = f.0
  x != x
}

///|
fn is_f64_nan(f : F64) -> Bool {
  let x = f.0
  x != x
}

///|
fn produces_f32(i : TInstr) -> Bool {
  match i {
    TF32Const(_) => true
    TUnary(op, _) =>
      match op {
        F32AbsOp
        | F32NegOp
        | F32CeilOp
        | F32FloorOp
        | F32TruncOp
        | F32NearestOp
        | F32SqrtOp
        | F32ConvertI32SOp
        | F32ConvertI32UOp
        | F32ConvertI64SOp
        | F32ConvertI64UOp
        | F32DemoteF64Op => true
        _ => false
      }
    TBinary(op, _, _) =>
      match op {
        F32AddOp
        | F32SubOp
        | F32MulOp
        | F32DivOp
        | F32MinOp
        | F32MaxOp
        | F32CopysignOp => true
        _ => false
      }
    _ => false
  }
}

///|
fn produces_f64(i : TInstr) -> Bool {
  match i {
    TF64Const(_) => true
    TUnary(op, _) =>
      match op {
        F64AbsOp
        | F64NegOp
        | F64CeilOp
        | F64FloorOp
        | F64TruncOp
        | F64NearestOp
        | F64SqrtOp
        | F64ConvertI32SOp
        | F64ConvertI32UOp
        | F64ConvertI64SOp
        | F64ConvertI64UOp
        | F64PromoteF32Op => true
        _ => false
      }
    TBinary(op, _, _) =>
      match op {
        F64AddOp
        | F64SubOp
        | F64MulOp
        | F64DivOp
        | F64MinOp
        | F64MaxOp
        | F64CopysignOp => true
        _ => false
      }
    _ => false
  }
}

///|
fn make_denam_transformer() -> ModuleTransformer[DeNaNState] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_func: Some(fn(self, st, func) {
      match func {
        TFunc(params, _) => {
          // FIX: Check parameters to determine if helpers are needed for sanitization
          let mut st = st
          for param in params {
            match param {
              NumTypeValType(F32NumType) => st = { ..st, need_f32: true }
              NumTypeValType(F64NumType) => st = { ..st, need_f64: true }
              _ => ()
            }
          }
          let st = DeNaNState::{ ..st, in_func: true }
          let (st, func) = match self.walk_func_default(st, func) {
            Ok(Some(t)) => t
            Ok(None) => (st, func)
            Err(t) => return Err(t)
          }
          change(DeNaNState::{ ..st, in_func: false }, func)
        }
        _ => Ok(None)
      }
    }),
    on_tinstruction: Some(fn(self, st, instr) {
      match instr {
        // f32 NaN constant → 0
        TF32Const(f) =>
          if is_f32_nan(f) {
            Ok(Some((st, TInstr::f32_const(F32(0.0)))))
          } else {
            Ok(None)
          }

        // f64 NaN constant → 0
        TF64Const(f) =>
          if is_f64_nan(f) {
            Ok(Some((st, TInstr::f64_const(F64(0.0)))))
          } else {
            Ok(None)
          }

        // wrap f32 producers
        _ if st.in_func && produces_f32(instr) => {
          let st = DeNaNState::{ ..st, need_f32: true }
          match st.deNan32 {
            Some(idx) => {
              let (st, processed_instr) = match
                self.walk_tinstruction_default(st, instr) {
                Ok(Some(pair)) => pair
                Ok(None) => (st, instr)
                Err(e) => return Err(e)
              }
              Ok(Some((st, TInstr::call(idx, [processed_instr]))))
            }
            None => self.walk_tinstruction_default(st, instr)
          }
        }

        // wrap f64 producers
        _ if st.in_func && produces_f64(instr) => {
          let st = DeNaNState::{ ..st, need_f64: true }
          match st.deNan64 {
            Some(idx) => {
              let (st, processed_instr) = match
                self.walk_tinstruction_default(st, instr) {
                Ok(Some(pair)) => pair
                Ok(None) => (st, instr)
                Err(e) => return Err(e)
              }
              Ok(Some((st, TInstr::call(idx, [processed_instr]))))
            }
            None => self.walk_tinstruction_default(st, instr)
          }
        }
        _ => self.walk_tinstruction_default(st, instr)
      }
    }),
  }
}

///|
fn sanitize_params(
  params : Array[ValType],
  body : TExpr,
  st : DeNaNState,
) -> TExpr {
  let prefix : Array[TInstr] = []
  for i, vt in params {
    match vt {
      NumTypeValType(F32NumType) =>
        match st.deNan32 {
          Some(idx) =>
            prefix.push(
              TInstr::local_set(
                LocalIdx::new(i.reinterpret_as_uint()),
                TInstr::call(idx, [
                  TInstr::local_get(LocalIdx::new(i.reinterpret_as_uint())),
                ]),
              ),
            )
          None => ()
        }
      NumTypeValType(F64NumType) =>
        match st.deNan64 {
          Some(idx) =>
            prefix.push(
              TInstr::local_set(
                LocalIdx::new(i.reinterpret_as_uint()),
                TInstr::call(idx, [
                  TInstr::local_get(LocalIdx::new(i.reinterpret_as_uint())),
                ]),
              ),
            )
          None => ()
        }
      _ => ()
    }
  }
  if prefix.is_empty() {
    body
  } else {
    prefix.append(body.0)
    TExpr::new(prefix)
  }
}

///|
fn make_denam32_func() -> Func {
  let cond = TInstr::binary(
    BinaryOp::f32_eq(),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let body = TInstr::if_(
    ValTypeBlockType(ValType::f32()),
    cond,
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
    Some(TExpr::new([TInstr::f32_const(F32(0.0))])),
  )
  Func::t_func([ValType::f32()], TExpr::new([body]))
}

///|
fn make_denam64_func() -> Func {
  let cond = TInstr::binary(
    BinaryOp::f64_eq(),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let body = TInstr::if_(
    ValTypeBlockType(ValType::f64()),
    cond,
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
    Some(TExpr::new([TInstr::f64_const(F64(0.0))])),
  )
  Func::t_func([ValType::f64()], TExpr::new([body]))
}

///|
pub fn run_denam(m : @lib.Module) -> Result[@lib.Module, String] {
  let tr = make_denam_transformer()
  let init_state = DeNaNState::{
    in_func: false,
    need_f32: false,
    need_f64: false,
    deNan32: None,
    deNan64: None,
  }

  // Pass 1: Identify needs and replace NaN constants
  let (st1, mod1) = match tr.walk_module(init_state, m) {
    Ok(Some(pair)) => pair
    Ok(None) => return Ok(m)
    Err(e) => return Err(e)
  }

  // Calculate helper indices based on Pass 1 needs
  let base_count = match mod1.code_sec {
    Some(cs) => cs.0.length()
    None => 0
  }
  let mut idx32 : FuncIdx? = None
  let mut idx64 : FuncIdx? = None
  let mut offset = 0U
  let base_count = base_count.reinterpret_as_uint()
  if st1.need_f32 {
    idx32 = Some(FuncIdx::new(base_count + offset))
    offset = offset + 1
  }
  if st1.need_f64 {
    idx64 = Some(FuncIdx::new(base_count + offset))
    offset = offset + 1
  }

  // Early exit if no helpers needed
  if idx32 is None && idx64 is None {
    return Ok(mod1)
  }

  // Pass 2: Apply wrappers now that indices are known
  let st2 = DeNaNState::{ ..st1, deNan32: idx32, deNan64: idx64 }
  let (st2, mod2) = match tr.walk_module(st2, mod1) {
    Ok(Some(pair)) => pair
    Ok(None) => (st2, mod1) // Should ideally not happen if mod1 had content, but safe fallback
    Err(e) => return Err(e)
  }

  // Post-process: Sanitize function parameters
  let current_funcs = match mod2.code_sec {
    Some(cs) => cs.0
    None => []
  }
  let updated_funcs = current_funcs.map(fn(f) {
    match f {
      TFunc(params, body) => {
        let new_body = sanitize_params(params, body, st2)
        Func::t_func(params, new_body)
      }
      _ => f
    }
  })

  // Append helper functions
  let final_funcs = updated_funcs
  if st2.need_f32 {
    final_funcs.push(make_denam32_func())
  }
  if st2.need_f64 {
    final_funcs.push(make_denam64_func())
  }
  Ok(mod2.with_code_sec(CodeSec::new(final_funcs)))
}
// test_denan.mbt

// ============================================
// Test Helpers
// ============================================

///|
fn make_empty_module() -> @lib.Module {
  @lib.Module::new()
}

///|
fn make_module_with_code(funcs : Array[Func]) -> @lib.Module {
  Module::new().with_code_sec(CodeSec::new(funcs))
}

// ============================================
// Test: NaN Constant Replacement
// ============================================

///|
test "f32 NaN constant is replaced with 0.0" {
  // Create a module with a function containing f32 NaN constant
  let nan_bits : UInt = 0x7FC00000 // Quiet NaN
  let nan_f32 = @lib.F32(Float::reinterpret_from_uint(nan_bits))
  let func = Func::t_func([], TExpr::new([TInstr::f32_const(nan_f32)]))
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      match funcs[0] {
        TFunc(_, TExpr(instrs)) =>
          match instrs[0] {
            TF32Const(F32(v)) =>
              assert_eq(v, 0.0, msg="NaN should be replaced with 0.0")
            _ => fail("Expected TF32Const")
          }
        _ => fail("Expected TFunc")
      }
    _ => fail("Expected code section")
  }
}

///|
test "f64 NaN constant is replaced with 0.0" {
  let nan_bits : UInt64 = 0x7FF8000000000000 // Quiet NaN
  let nan_f64 = @lib.F64(nan_bits.reinterpret_as_double())
  let func = Func::t_func([], TExpr::new([TInstr::f64_const(nan_f64)]))
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      match funcs[0] {
        TFunc(_, TExpr(instrs)) =>
          match instrs[0] {
            TF64Const(F64(v)) =>
              assert_eq(v, 0.0, msg="NaN should be replaced with 0.0")
            _ => fail("Expected TF64Const")
          }
        _ => fail("Expected TFunc")
      }
    _ => fail("Expected code section")
  }
}

///|
test "non-NaN f32 constant is unchanged" {
  let func = Func::t_func([], TExpr::new([TInstr::f32_const(F32(3.14))]))
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      match funcs[0] {
        TFunc(_, TExpr(instrs)) =>
          match instrs[0] {
            TF32Const(F32(v)) =>
              assert_eq(v, 3.14, msg="Non-NaN should be unchanged")
            _ => fail("Expected TF32Const")
          }
        _ => fail("Expected TFunc")
      }
    _ => fail("Expected code section")
  }
}

///|
test "negative zero is not replaced" {
  let neg_zero_bits : UInt = 0x80000000
  let neg_zero = @lib.F32(Float::reinterpret_from_uint(neg_zero_bits))
  let func = Func::t_func([], TExpr::new([TInstr::f32_const(neg_zero)]))
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      match funcs[0] {
        TFunc(_, TExpr(instrs)) =>
          match instrs[0] {
            TF32Const(F32(v)) => {
              // Check it's still negative zero (bit pattern preserved)
              let bits = v.reinterpret_as_uint()
              assert_eq(
                bits,
                0x80000000U,
                msg="Negative zero should be unchanged",
              )
            }
            _ => fail("Expected TF32Const")
          }
        _ => fail("Expected TFunc")
      }
    _ => fail("Expected code section")
  }
}

///|
test "infinity is not replaced" {
  let inf_bits : UInt = 0x7F800000 // Positive infinity
  let inf_f32 = @lib.F32(Float::reinterpret_from_uint(inf_bits))
  let func = Func::t_func([], TExpr::new([TInstr::f32_const(inf_f32)]))
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      match funcs[0] {
        TFunc(_, TExpr(instrs)) =>
          match instrs[0] {
            TF32Const(F32(v)) => {
              let bits = v.reinterpret_as_uint()
              assert_eq(bits, 0x7F800000U, msg="Infinity should be unchanged")
            }
            _ => fail("Expected TF32Const")
          }
        _ => fail("Expected TFunc")
      }
    _ => fail("Expected code section")
  }
}

// ============================================
// Test: Helper Function Generation
// ============================================

///|
test "helper functions are added when f32 operations exist" {
  // f32.add produces f32, should trigger helper generation
  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::binary(
        BinaryOp::f32_add(),
        TInstr::f32_const(F32(1.0)),
        TInstr::f32_const(F32(2.0)),
      ),
    ]),
  )
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      // Should have original func + deNan32 helper
      assert_eq(
        funcs.length(),
        2,
        msg="Should have 2 functions (original + deNan32)",
      )
    _ => fail("Expected code section")
  }
}

///|
test "helper functions are added when f64 operations exist" {
  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::binary(
        BinaryOp::f64_add(),
        TInstr::f64_const(F64(1.0)),
        TInstr::f64_const(F64(2.0)),
      ),
    ]),
  )
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      // Should have original func + deNan64 helper
      assert_eq(
        funcs.length(),
        2,
        msg="Should have 2 functions (original + deNan64)",
      )
    _ => fail("Expected code section")
  }
}

///|
test "both helpers added when both f32 and f64 operations exist" {
  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::binary(
        BinaryOp::f32_add(),
        TInstr::f32_const(F32(1.0)),
        TInstr::f32_const(F32(2.0)),
      ),
      TInstr::binary(
        BinaryOp::f64_add(),
        TInstr::f64_const(F64(1.0)),
        TInstr::f64_const(F64(2.0)),
      ),
    ]),
  )
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      // Should have original func + deNan32 + deNan64
      assert_eq(
        funcs.length(),
        3,
        msg="Should have 3 functions (original + both helpers)",
      )
    _ => fail("Expected code section")
  }
}

///|
test "no helpers added when only NaN constants exist" {
  let nan_bits : UInt = 0x7FC00000
  let nan_f32 = @lib.F32(Float::reinterpret_from_uint(nan_bits))
  let func = Func::t_func(
    [],
    TExpr::new([TInstr::f32_const(nan_f32)]), // Just a constant, no operations
  )
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      // Should only have original func (constant was replaced inline)
      assert_eq(
        funcs.length(),
        1,
        msg="Should have 1 function (no helpers needed)",
      )
    _ => fail("Expected code section")
  }
}

// ============================================
// Test: Operation Wrapping
// ============================================

///|
test "f32.add is wrapped with deNan call" {
  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::binary(
        BinaryOp::f32_add(),
        TInstr::f32_const(F32(1.0)),
        TInstr::f32_const(F32(2.0)),
      ),
    ]),
  )
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      match funcs[0] {
        TFunc(_, TExpr(instrs)) =>
          match instrs[0] {
            TCall(FuncIdx(idx), args) => {
              // Should be calling the helper function (index 1)
              assert_eq(idx, 1U, msg="Should call deNan32 helper at index 1")
              assert_eq(args.length(), 1, msg="Call should have 1 argument")
              match args[0] {
                TBinary(F32AddOp, _, _) => () // Good, the add is the argument
                _ => fail("Expected f32.add as argument to deNan call")
              }
            }
            _ => fail("Expected TCall wrapping the f32.add")
          }
        _ => fail("Expected TFunc")
      }
    _ => fail("Expected code section")
  }
}

///|
test "f32.sqrt is wrapped with deNan call" {
  let func = Func::t_func(
    [],
    TExpr::new([TInstr::unary(UnaryOp::f32_sqrt(), TInstr::f32_const(F32(4.0)))]),
  )
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      match funcs[0] {
        @lib.TFunc(_, TExpr(instrs)) =>
          match instrs[0] {
            TCall(_, args) =>
              match args[0] {
                TUnary(F32SqrtOp, _) => () // Good
                _ => fail("Expected f32.sqrt as argument to deNan call")
              }
            _ => fail("Expected TCall wrapping the f32.sqrt")
          }
        _ => fail("Expected TFunc")
      }
    _ => fail("Expected code section")
  }
}

///|
test "f64.div is wrapped with deNan call" {
  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::binary(
        BinaryOp::f64_div(),
        TInstr::f64_const(F64(1.0)),
        TInstr::f64_const(F64(0.0)), // Division by zero -> infinity, not NaN
      ),
    ]),
  )
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      match funcs[0] {
        @lib.TFunc(_, TExpr(instrs)) =>
          match instrs[0] {
            TCall(_, args) =>
              match args[0] {
                TBinary(F64DivOp, _, _) => ()
                _ => fail("Expected f64.div as argument to deNan call")
              }
            _ => fail("Expected TCall wrapping the f64.div")
          }
        _ => fail("Expected TFunc")
      }
    _ => fail("Expected code section")
  }
}

// ============================================
// Test: Parameter Sanitization
// ============================================

///|
test "f32 parameter is sanitized at function entry" {
  let func = Func::t_func(
    [ValType::f32()], // One f32 parameter
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]), // Just return the parameter
  )
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      match funcs[0] {
        TFunc(_, TExpr(instrs)) =>
          // First instruction should be local.set that sanitizes the param
          match instrs[0] {
            TLocalSet(LocalIdx(0), TCall(_, args)) =>
              match args[0] {
                TLocalGet(LocalIdx(0)) => () // Good
                _ => fail("Expected local.get(0) as argument to deNan call")
              }
            _ => fail("Expected local.set with deNan call at function entry")
          }
        _ => fail("Expected TFunc")
      }
    _ => fail("Expected code section")
  }
}

///|
test "f64 parameter is sanitized at function entry" {
  let func = Func::t_func(
    [ValType::f64()],
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
  )
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      match funcs[0] {
        TFunc(_, TExpr(instrs)) =>
          match instrs[0] {
            TLocalSet(LocalIdx(0), TCall(_, _)) => ()
            _ => fail("Expected local.set with deNan call at function entry")
          }
        _ => fail("Expected TFunc")
      }
    _ => fail("Expected code section")
  }
}

///|
test "mixed parameters - only floats sanitized" {
  let func = Func::t_func(
    [
      ValType::i32(), // param 0: i32 - not sanitized
      ValType::f32(), // param 1: f32 - sanitized
      ValType::i64(), // param 2: i64 - not sanitized
      ValType::f64(),
    ], // param 3: f64 - sanitized
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
  )
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      match funcs[0] {
        TFunc(_, TExpr(instrs)) => {
          // Should have 2 sanitization instructions (for f32 and f64 params)
          // plus the original body
          let sanitize_count = instrs
            .iter()
            .take_while(fn(i) {
              match i {
                TLocalSet(_, TCall(_, _)) => true
                _ => false
              }
            })
            .count()
          assert_eq(
            sanitize_count,
            2,
            msg="Should have 2 sanitization instructions",
          )
        }
        _ => fail("Expected TFunc")
      }
    _ => fail("Expected code section")
  }
}

///|
test "i32 parameter is not sanitized" {
  let func = Func::t_func(
    [ValType::i32()],
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
  )
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      match funcs[0] {
        TFunc(_, TExpr(instrs)) => {
          // Body should be unchanged (just local.get)
          assert_eq(instrs.length(), 1, msg="Body should be unchanged")
          match instrs[0] {
            TLocalGet(LocalIdx(0)) => ()
            _ => fail("Expected unchanged local.get")
          }
        }
        _ => fail("Expected TFunc")
      }
    _ => fail("Expected code section")
  }
}

// ============================================
// Test: Helper Function Correctness
// ============================================

///|
test "deNan32 helper has correct structure" {
  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::binary(
        BinaryOp::f32_add(),
        TInstr::f32_const(F32(1.0)),
        TInstr::f32_const(F32(2.0)),
      ),
    ]),
  )
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      // Helper should be at index 1
      match funcs[1] {
        TFunc(params, TExpr(body)) => {
          // Should take one f32 parameter
          assert_eq(params.length(), 1, msg="Helper should have 1 parameter")
          match params[0] {
            NumTypeValType(F32NumType) => ()
            _ => fail("Helper parameter should be f32")
          }

          // Body should be: if (local.get 0 == local.get 0) local.get 0 else 0.0
          match body[0] {
            TIf(
              ValTypeBlockType(NumTypeValType(F32NumType)),
              cond,
              then_branch,
              Some(else_branch)
            ) => {
              // Condition: f32.eq (local.get 0) (local.get 0)
              match cond {
                TBinary(F32EqOp, TLocalGet(LocalIdx(0)), TLocalGet(LocalIdx(0))) =>
                  ()
                _ =>
                  fail("Condition should be f32.eq comparing param to itself")
              }

              // Then: return parameter
              match then_branch {
                TExpr([TLocalGet(LocalIdx(0))]) => ()
                _ => fail("Then branch should return parameter")
              }

              // Else: return 0.0
              match else_branch {
                TExpr([TF32Const(F32(v))]) =>
                  assert_eq(v, 0.0, msg="Else should return 0.0")
                _ => fail("Else branch should return 0.0")
              }
            }
            _ => fail("Body should be an if expression")
          }
        }
        _ => fail("Expected TFunc for helper")
      }
    _ => fail("Expected code section")
  }
}

// ============================================
// Test: Edge Cases
// ============================================

///|
test "empty module is unchanged" {
  let mod = make_empty_module()
  let result = run_denam(mod)

  // Should return the module unchanged
  match result {
    Ok({ code_sec: None, .. }) => () // Good, still no code section
    _ => fail("Empty module should remain empty")
  }
}

///|
test "module with no float operations is unchanged" {
  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::i32_const(1),
        TInstr::i32_const(2),
      ),
    ]),
  )
  let mod = make_module_with_code([func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      assert_eq(
        funcs.length(),
        1,
        msg="Should have 1 function (no helpers added)",
      )
    _ => fail("Expected code section")
  }
}

///|
test "nested expressions are properly wrapped" {
  // f32.add(f32.mul(1.0, 2.0), f32.div(3.0, 4.0))
  // Both inner operations AND the outer add should be wrapped
  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::binary(
        BinaryOp::f32_add(),
        TInstr::binary(
          BinaryOp::f32_mul(),
          TInstr::f32_const(F32(1.0)),
          TInstr::f32_const(F32(2.0)),
        ),
        TInstr::binary(
          BinaryOp::f32_div(),
          TInstr::f32_const(F32(3.0)),
          TInstr::f32_const(F32(4.0)),
        ),
      ),
    ]),
  )
  let mod = make_module_with_code([func])
  let result = run_denam(mod)

  // Count the number of deNan calls (should be 3: mul, div, add)
  fn count_calls(i : TInstr) -> Int {
    match i {
      TCall(_, args) =>
        1 + args.iter().map(count_calls).fold(init=0, fn(a, b) { a + b })
      TBinary(_, l, r) => count_calls(l) + count_calls(r)
      TUnary(_, x) => count_calls(x)
      _ => 0
    }
  }

  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      match funcs[0] {
        @lib.TFunc(_, TExpr(instrs)) => {
          let calls = count_calls(instrs[0])
          assert_eq(
            calls,
            3,
            msg="Should have 3 deNan calls for nested f32 operations",
          )
        }
        _ => fail("Expected TFunc")
      }
    _ => fail("Expected code section")
  }
}

///|
test "multiple functions are all processed" {
  let func1 = Func::t_func(
    [ValType::f32()],
    TExpr::new([
      TInstr::unary(UnaryOp::f32_sqrt(), TInstr::local_get(LocalIdx::new(0))),
    ]),
  )
  let func2 = Func::t_func(
    [ValType::f64()],
    TExpr::new([
      TInstr::unary(UnaryOp::f64_sqrt(), TInstr::local_get(LocalIdx::new(0))),
    ]),
  )
  let mod = make_module_with_code([func1, func2])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) => {
      // Original 2 funcs + deNan32 + deNan64
      assert_eq(funcs.length(), 4, msg="Should have 4 functions total")

      // Both original functions should have parameter sanitization
      for i in [0, 1] {
        match funcs[i] {
          @lib.TFunc(_, TExpr(instrs)) =>
            match instrs[0] {
              TLocalSet(_, TCall(_, _)) => () // Has sanitization
              _ => fail("Function \{i} should have parameter sanitization")
            }
          _ => fail("Expected TFunc")
        }
      }
    }
    _ => fail("Expected code section")
  }
}

// ============================================
// Test: Idempotency
// ============================================

///|
test "running pass twice produces same result" {
  // TODO: Implement this test
}

// ============================================
// Test: NaN Detection Logic
// ============================================

///|
test "is_f32_nan correctly identifies NaN" {
  let nan_bits : UInt = 0x7FC00000 // Quiet NaN
  let nan = @lib.F32(Float::reinterpret_from_uint(nan_bits))
  assert_eq(is_f32_nan(nan), true, msg="Should detect quiet NaN")
  let snan_bits : UInt = 0x7F800001 // Signaling NaN
  let snan = @lib.F32(Float::reinterpret_from_uint(snan_bits))
  assert_eq(is_f32_nan(snan), true, msg="Should detect signaling NaN")
  let neg_nan_bits : UInt = 0xFFC00000 // Negative NaN
  let neg_nan = @lib.F32(Float::reinterpret_from_uint(neg_nan_bits))
  assert_eq(is_f32_nan(neg_nan), true, msg="Should detect negative NaN")
}

///|
test "is_f32_nan correctly rejects non-NaN" {
  assert_eq(is_f32_nan(F32(0.0)), false, msg="0.0 is not NaN")
  assert_eq(is_f32_nan(F32(-0.0)), false, msg="-0.0 is not NaN")
  assert_eq(is_f32_nan(F32(1.0)), false, msg="1.0 is not NaN")
  assert_eq(is_f32_nan(F32(-1.0)), false, msg="-1.0 is not NaN")
  let inf_bits : UInt = 0x7F800000 // Infinity
  let inf = @lib.F32(Float::reinterpret_from_uint(inf_bits))
  assert_eq(is_f32_nan(inf), false, msg="Infinity is not NaN")
  let neg_inf_bits : UInt = 0xFF800000 // Negative infinity
  let neg_inf = @lib.F32(Float::reinterpret_from_uint(neg_inf_bits))
  assert_eq(is_f32_nan(neg_inf), false, msg="Negative infinity is not NaN")
}

///|
test "is_f64_nan correctly identifies NaN" {
  let nan_bits : UInt64 = 0x7FF8000000000000 // Quiet NaN
  let nan = @lib.F64(nan_bits.reinterpret_as_double())
  assert_eq(is_f64_nan(nan), true, msg="Should detect quiet NaN")
}

///|
test "is_f64_nan correctly rejects non-NaN" {
  assert_eq(is_f64_nan(F64(0.0)), false, msg="0.0 is not NaN")
  assert_eq(is_f64_nan(F64(1.0)), false, msg="1.0 is not NaN")
}
