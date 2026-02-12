///|
priv enum FloatKind {
  Float32
  Float64
}

///|
priv struct DeNaNState {
  env : Env
  in_func : Bool
  wrap_enabled : Bool
  next_func_abs : UInt
  current_param_types : Array[ValType]
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
fn is_f32_valtype(vt : ValType) -> Bool {
  match vt {
    NumTypeValType(F32NumType) => true
    _ => false
  }
}

///|
fn is_f64_valtype(vt : ValType) -> Bool {
  match vt {
    NumTypeValType(F64NumType) => true
    _ => false
  }
}

///|
fn imported_func_count(mod : Module) -> UInt {
  let mut n = 0U
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, ex) = import_
        match ex {
          FuncExternType(_) => n = n + 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn unary_result_type(op : UnaryOp) -> ValType? {
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
    | F32DemoteF64Op
    | F32ReinterpretI32Op => Some(ValType::f32())
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
    | F64PromoteF32Op
    | F64ReinterpretI64Op => Some(ValType::f64())
    _ => None
  }
}

///|
fn binary_result_type(op : BinaryOp) -> ValType? {
  match op {
    F32AddOp
    | F32SubOp
    | F32MulOp
    | F32DivOp
    | F32MinOp
    | F32MaxOp
    | F32CopysignOp => Some(ValType::f32())
    F64AddOp
    | F64SubOp
    | F64MulOp
    | F64DivOp
    | F64MinOp
    | F64MaxOp
    | F64CopysignOp => Some(ValType::f64())
    _ => None
  }
}

///|
fn load_result_type(op : LoadOp) -> ValType? {
  match op {
    F32LoadOp => Some(ValType::f32())
    F64LoadOp => Some(ValType::f64())
    _ => None
  }
}

///|
fn infer_tinstr_type(instr : TInstr, st : DeNaNState) -> ValType? {
  match instr {
    TI32Const(_) => Some(ValType::i32())
    TI64Const(_) => Some(ValType::i64())
    TF32Const(_) => Some(ValType::f32())
    TF64Const(_) => Some(ValType::f64())
    TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      Some(ValType::v128())
    TUnary(op, _) => unary_result_type(op)
    TBinary(op, _, _) => binary_result_type(op)
    TLoad(op, _, _) => load_result_type(op)
    TLocalGet(idx) => st.env.get_local_type(idx)
    TGlobalGet(idx) =>
      match st.env.get_global_type(idx) {
        Some(GlobalType(vt, _)) => Some(vt)
        None => None
      }
    TLocalTee(_, value) => infer_tinstr_type(value, st)
    TSelect(Some(types), _, _, _) if types.length() == 1 => Some(types[0])
    TCall(target, _) =>
      match st.env.get_functype_by_funcidx(target) {
        Some(FuncType(_, [r])) => Some(r)
        _ => None
      }
    TCallIndirect(type_idx, _, _, _) | TCallRef(type_idx, _, _) =>
      match st.env.resolve_functype(type_idx) {
        Some(FuncType(_, [r])) => Some(r)
        _ => None
      }
    TBlock(bt, _) | TLoop(bt, _) | TIf(bt, _, _, _) | TTryTable(bt, _, _) =>
      match st.env.expand_blocktype(bt) {
        Ok((_, [vt])) => Some(vt)
        _ => None
      }
    TStructGet(type_idx, field_idx, _)
    | TStructGetS(type_idx, field_idx, _)
    | TStructGetU(type_idx, field_idx, _) =>
      match st.env.resolve_struct_fields(type_idx) {
        Ok(fields) => {
          let U32(raw_idx) = field_idx
          match fields.get(raw_idx.reinterpret_as_int()) {
            Some(ft) => Some(ft.unpack())
            None => None
          }
        }
        Err(_) => None
      }
    TArrayGet(type_idx, _, _)
    | TArrayGetS(type_idx, _, _)
    | TArrayGetU(type_idx, _, _) =>
      match st.env.resolve_array_field(type_idx) {
        Ok(field) => Some(field.unpack())
        Err(_) => None
      }
    _ => None
  }
}

///|
fn infer_float_kind(instr : TInstr, st : DeNaNState) -> FloatKind? {
  match infer_tinstr_type(instr, st) {
    Some(vt) =>
      if is_f32_valtype(vt) {
        Some(Float32)
      } else if is_f64_valtype(vt) {
        Some(Float64)
      } else {
        None
      }
    None => None
  }
}

///|
fn is_denam32_func(f : Func) -> Bool {
  match f {
    TFunc(
      [NumTypeValType(F32NumType)],
      TExpr(
        [
          TIf(
            ValTypeBlockType(NumTypeValType(F32NumType)),
            TBinary(F32EqOp, TLocalGet(LocalIdx(0)), TLocalGet(LocalIdx(0))),
            TExpr([TLocalGet(LocalIdx(0))]),
            Some(TExpr([TF32Const(F32(v))]))
          ),
        ]
      )
    ) => v == 0.0
    _ => false
  }
}

///|
fn is_denam64_func(f : Func) -> Bool {
  match f {
    TFunc(
      [NumTypeValType(F64NumType)],
      TExpr(
        [
          TIf(
            ValTypeBlockType(NumTypeValType(F64NumType)),
            TBinary(F64EqOp, TLocalGet(LocalIdx(0)), TLocalGet(LocalIdx(0))),
            TExpr([TLocalGet(LocalIdx(0))]),
            Some(TExpr([TF64Const(F64(v))]))
          ),
        ]
      )
    ) => v == 0.0
    _ => false
  }
}

///|
fn find_existing_denan_helpers(mod : Module) -> (FuncIdx?, FuncIdx?) {
  let imported = imported_func_count(mod)
  let mut idx32 : FuncIdx? = None
  let mut idx64 : FuncIdx? = None
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for i, f in funcs {
        let abs_idx = FuncIdx::new(imported + i.reinterpret_as_uint())
        if idx32 is None && is_denam32_func(f) {
          idx32 = Some(abs_idx)
        }
        if idx64 is None && is_denam64_func(f) {
          idx64 = Some(abs_idx)
        }
      }
    None => ()
  }
  (idx32, idx64)
}

///|
fn find_func_type_idx(
  type_sec : TypeSec,
  params : Array[ValType],
  results : Array[ValType],
) -> TypeIdx? {
  let TypeSec(rec_types) = type_sec
  let mut idx = 0U
  for rec in rec_types {
    match rec {
      SingleRecType(st) =>
        match st.get_comptype() {
          FuncCompType(ps, rs) if ps == params && rs == results =>
            return Some(TypeIdx::new(idx))
          _ => ()
        }
      GroupRecType(sts) =>
        for st in sts {
          match st.get_comptype() {
            FuncCompType(ps, rs) if ps == params && rs == results =>
              return Some(TypeIdx::new(idx))
            _ => ()
          }
          idx = idx + 1
        }
    }
    if rec is SingleRecType(_) {
      idx = idx + 1
    }
  }
  None
}

///|
fn ensure_func_type(
  type_sec : TypeSec,
  params : Array[ValType],
  results : Array[ValType],
) -> (TypeSec, TypeIdx) {
  match find_func_type_idx(type_sec, params, results) {
    Some(idx) => (type_sec, idx)
    None => {
      let TypeSec(rec_types) = type_sec
      let idx = rec_types.length().reinterpret_as_uint()
      rec_types.push(
        single_rec_type(comp_type_sub_type(func_comp_type(params, results))),
      )
      (TypeSec::new(rec_types), TypeIdx::new(idx))
    }
  }
}

///|
fn starts_with_prefix(xs : Array[TInstr], prefix : Array[TInstr]) -> Bool {
  if prefix.length() > xs.length() {
    return false
  }
  for i = 0; i < prefix.length(); i = i + 1 {
    if xs[i] != prefix[i] {
      return false
    }
  }
  true
}

///|
fn build_param_sanitizers(
  params : Array[ValType],
  denan32 : FuncIdx?,
  denan64 : FuncIdx?,
) -> Array[TInstr] {
  let prefix : Array[TInstr] = []
  for i, vt in params {
    let local_idx = LocalIdx::new(i.reinterpret_as_uint())
    match vt {
      NumTypeValType(F32NumType) =>
        match denan32 {
          Some(idx) =>
            prefix.push(
              TInstr::local_set(
                local_idx,
                TInstr::call(idx, [TInstr::local_get(local_idx)]),
              ),
            )
          None => ()
        }
      NumTypeValType(F64NumType) =>
        match denan64 {
          Some(idx) =>
            prefix.push(
              TInstr::local_set(
                local_idx,
                TInstr::call(idx, [TInstr::local_get(local_idx)]),
              ),
            )
          None => ()
        }
      _ => ()
    }
  }
  prefix
}

///|
fn sanitize_params(
  params : Array[ValType],
  body : TExpr,
  denan32 : FuncIdx?,
  denan64 : FuncIdx?,
) -> TExpr {
  let prefix = build_param_sanitizers(params, denan32, denan64)
  if prefix.is_empty() {
    return body
  }
  if starts_with_prefix(body.0, prefix) {
    return body
  }
  let updated = prefix.copy()
  updated.append(body.0)
  TExpr::new(updated)
}

///|
fn function_param_types(
  env : Env,
  func_idx : FuncIdx,
  fallback : Array[ValType],
) -> Array[ValType] {
  match env.get_functype_by_funcidx(func_idx) {
    Some(FuncType(params, _)) => params
    None => fallback
  }
}

///|
fn function_local_types(
  env : Env,
  func_idx : FuncIdx,
  tlocals : Array[ValType],
) -> (Array[ValType], Array[ValType]) {
  match env.get_functype_by_funcidx(func_idx) {
    Some(FuncType(params, _)) => {
      let locals = params.copy()
      locals.append(tlocals)
      (params, locals)
    }
    None => (tlocals, tlocals)
  }
}

///|
fn make_denam_transformer() -> ModuleTransformer[DeNaNState] {
  ModuleTransformer::new()
  .on_func_evt(fn(self, st : DeNaNState, func : Func) {
    let abs_raw = st.next_func_abs
    let abs_idx = FuncIdx::new(abs_raw)
    let st = DeNaNState::{ ..st, next_func_abs: abs_raw + 1 }
    if st.wrap_enabled &&
      (st.deNan32 == Some(abs_idx) || st.deNan64 == Some(abs_idx)) {
      return change(st, func)
    }
    match func {
      TFunc(tlocals, _) => {
        let base_env = st.env
        let (params, local_types) = function_local_types(
          base_env, abs_idx, tlocals,
        )
        let mut st = DeNaNState::{
          ..st,
          in_func: true,
          current_param_types: params,
          env: base_env.with_locals(local_types),
        }
        for param in st.current_param_types {
          match param {
            NumTypeValType(F32NumType) =>
              st = DeNaNState::{ ..st, need_f32: true }
            NumTypeValType(F64NumType) =>
              st = DeNaNState::{ ..st, need_f64: true }
            _ => ()
          }
        }
        let (st, func) = match self.walk_func_default(st, func) {
          Ok(Some(t)) => t
          Ok(None) => (st, func)
          Err(t) => return Err(t)
        }
        change(
          DeNaNState::{
            ..st,
            in_func: false,
            current_param_types: [],
            env: base_env,
          },
          func,
        )
      }
      _ => self.walk_func_default(st, func)
    }
  })
  .on_tinstruction_evt(fn(self, st, instr) {
    match instr {
      TF32Const(f) =>
        if is_f32_nan(f) {
          Ok(Some((st, TInstr::f32_const(F32(0.0)))))
        } else {
          Ok(None)
        }
      TF64Const(f) =>
        if is_f64_nan(f) {
          Ok(Some((st, TInstr::f64_const(F64(0.0)))))
        } else {
          Ok(None)
        }
      TCall(idx, _) if st.wrap_enabled &&
        (st.deNan32 == Some(idx) || st.deNan64 == Some(idx)) =>
        change(st, instr)
      _ =>
        if st.in_func {
          match infer_float_kind(instr, st) {
            Some(Float32) => {
              let st = DeNaNState::{ ..st, need_f32: true }
              if !st.wrap_enabled {
                return self.walk_tinstruction_default(st, instr)
              }
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
            Some(Float64) => {
              let st = DeNaNState::{ ..st, need_f64: true }
              if !st.wrap_enabled {
                return self.walk_tinstruction_default(st, instr)
              }
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
            None => self.walk_tinstruction_default(st, instr)
          }
        } else {
          self.walk_tinstruction_default(st, instr)
        }
    }
  })
}

///|
fn make_denam32_func() -> Func {
  let cond = TInstr::binary(
    BinaryOp::f32_eq(),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let body = TInstr::if_(
    BlockType::val_type(ValType::f32()),
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
    BlockType::val_type(ValType::f64()),
    cond,
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
    Some(TExpr::new([TInstr::f64_const(F64(0.0))])),
  )
  Func::t_func([ValType::f64()], TExpr::new([body]))
}

///|
fn run_denam(m : @lib.Module) -> Result[@lib.Module, String] {
  let env0 = Env::new().with_module(m)
  let imported = imported_func_count(m)
  let (existing_32, existing_64) = find_existing_denan_helpers(m)
  let tr = make_denam_transformer()
  let init_state = DeNaNState::{
    env: env0,
    in_func: false,
    wrap_enabled: false,
    next_func_abs: imported,
    current_param_types: [],
    need_f32: false,
    need_f64: false,
    deNan32: existing_32,
    deNan64: existing_64,
  }
  let (st1, mod1) = match tr.walk_module(init_state, m) {
    Ok(Some(pair)) => pair
    Ok(None) => return Ok(m) // unreachable for walk_module, but keeps behavior explicit
    Err(e) => return Err(e)
  }
  let defined_count = match mod1.code_sec {
    Some(cs) => cs.0.length().reinterpret_as_uint()
    None => 0
  }
  let mut idx32 : FuncIdx? = st1.deNan32
  let mut idx64 : FuncIdx? = st1.deNan64
  let mut offset = 0U
  let need_new_32 = st1.need_f32 && idx32 is None
  let need_new_64 = st1.need_f64 && idx64 is None
  if need_new_32 {
    idx32 = Some(FuncIdx::new(imported + defined_count + offset))
    offset = offset + 1
  }
  if need_new_64 {
    idx64 = Some(FuncIdx::new(imported + defined_count + offset))
    offset = offset + 1
  }
  if !st1.need_f32 && !st1.need_f64 {
    return Ok(mod1)
  }
  let st2 = DeNaNState::{
    ..st1,
    env: Env::new().with_module(mod1),
    wrap_enabled: true,
    next_func_abs: imported,
    current_param_types: [],
    deNan32: idx32,
    deNan64: idx64,
  }
  let (st2, mod2) = match tr.walk_module(st2, mod1) {
    Ok(Some(pair)) => pair
    Ok(None) => (st2, mod1)
    Err(e) => return Err(e)
  }
  let env2 = Env::new().with_module(mod2)
  let mut abs_idx = imported
  let current_funcs = match mod2.code_sec {
    Some(cs) => cs.0
    None => []
  }
  let updated_funcs = current_funcs.map(fn(f) {
    let func_idx = FuncIdx::new(abs_idx)
    abs_idx = abs_idx + 1
    if st2.deNan32 == Some(func_idx) || st2.deNan64 == Some(func_idx) {
      return f
    }
    match f {
      TFunc(tlocals, body) => {
        let params = function_param_types(env2, func_idx, tlocals)
        let new_body = sanitize_params(params, body, st2.deNan32, st2.deNan64)
        Func::t_func(tlocals, new_body)
      }
      _ => f
    }
  })
  let final_funcs = updated_funcs
  if need_new_32 {
    final_funcs.push(make_denam32_func())
  }
  if need_new_64 {
    final_funcs.push(make_denam64_func())
  }
  let mod3 = mod2.with_code_sec(CodeSec::new(final_funcs))
  let final_mod = match mod3.func_sec {
    Some(FuncSec(type_idxs)) => {
      let type_sec = match mod3.type_sec {
        Some(ts) => ts
        None => return Err("de_nan: func_sec exists but type_sec is missing")
      }
      let type_idxs = type_idxs.copy()
      let (type_sec, ty32) = ensure_func_type(type_sec, [ValType::f32()], [
        ValType::f32(),
      ])
      let (type_sec, ty64) = ensure_func_type(type_sec, [ValType::f64()], [
        ValType::f64(),
      ])
      if need_new_32 {
        type_idxs.push(ty32)
      }
      if need_new_64 {
        type_idxs.push(ty64)
      }
      mod3.with_type_sec(type_sec).with_func_sec(FuncSec::new(type_idxs))
    }
    None => mod3
  }
  Ok(final_mod)
}
// test_denan.mbt

// ============================================
// Test Helpers
// ============================================

///|
fn make_module_with_code(funcs : Array[Func]) -> @lib.Module {
  Module::new().with_code_sec(CodeSec::new(funcs))
}

///|
fn make_func_type_rec(
  params : Array[ValType],
  results : Array[ValType],
) -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type(params, results)))
}

///|
fn make_typed_module(
  types : Array[RecType],
  func_types : Array[TypeIdx],
  funcs : Array[Func],
) -> @lib.Module {
  Module::new()
  .with_type_sec(TypeSec::new(types))
  .with_func_sec(FuncSec::new(func_types))
  .with_code_sec(CodeSec::new(funcs))
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

///|
test "f32.load is wrapped with deNan call" {
  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::load(
        LoadOp::f32_load(),
        MemArg::new(U32(4), None, U64(0)),
        TInstr::i32_const(0),
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
            TCall(_, args) =>
              match args[0] {
                TLoad(F32LoadOp, _, _) => ()
                _ => fail("Expected f32.load as argument to deNan call")
              }
            _ => fail("Expected TCall wrapping f32.load")
          }
        _ => fail("Expected TFunc")
      }
    _ => fail("Expected code section")
  }
}

///|
test "typed f32.select is wrapped with deNan call" {
  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::select(
        Some([ValType::f32()]),
        TInstr::i32_const(1),
        TInstr::f32_const(F32(10.0)),
        TInstr::f32_const(F32(20.0)),
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
            TCall(_, args) =>
              match args[0] {
                TSelect(Some([NumTypeValType(F32NumType)]), _, _, _) => ()
                _ => fail("Expected typed f32 select as deNan argument")
              }
            _ => fail("Expected TCall wrapping typed select")
          }
        _ => fail("Expected TFunc")
      }
    _ => fail("Expected code section")
  }
}

///|
test "f32 call result is wrapped with deNan call" {
  let t0 = make_func_type_rec([], [ValType::f32()])
  let callee = Func::t_func([], TExpr::new([TInstr::f32_const(F32(1.0))]))
  let caller = Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(0), [])]))
  let mod = make_typed_module([t0], [TypeIdx::new(0), TypeIdx::new(0)], [
    callee, caller,
  ])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      match funcs[1] {
        TFunc(_, TExpr(instrs)) =>
          match instrs[0] {
            TCall(FuncIdx(helper_idx), [TCall(FuncIdx(target), [])]) => {
              assert_eq(
                helper_idx,
                2U,
                msg="helper index should include both defined funcs",
              )
              assert_eq(
                target,
                0U,
                msg="inner call target should remain original callee",
              )
            }
            _ => fail("Expected wrapped call result")
          }
        _ => fail("Expected caller TFunc")
      }
    _ => fail("Expected code section")
  }
}

///|
test "f32 local.get flow is wrapped with deNan call" {
  let t0 = make_func_type_rec([], [ValType::f32()])
  let func = Func::t_func(
    [ValType::f32()],
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
  )
  let mod = make_typed_module([t0], [TypeIdx::new(0)], [func])
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      match funcs[0] {
        TFunc(_, TExpr(instrs)) =>
          match instrs[0] {
            TCall(_, [TLocalGet(LocalIdx(0))]) => ()
            _ => fail("Expected wrapped local.get result")
          }
        _ => fail("Expected TFunc")
      }
    _ => fail("Expected code section")
  }
}

///|
test "f64 global.get flow is wrapped with deNan call" {
  let t0 = make_func_type_rec([], [ValType::f64()])
  let func = Func::t_func(
    [],
    TExpr::new([TInstr::global_get(GlobalIdx::new(0))]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::f64(), false),
          Expr::new([Instruction::f64_const(F64(1.0))]),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new([func]))
  let result = run_denam(mod)
  match result {
    Ok({ code_sec: Some(CodeSec(funcs)), .. }) =>
      match funcs[0] {
        TFunc(_, TExpr(instrs)) =>
          match instrs[0] {
            TCall(_, [TGlobalGet(GlobalIdx(0))]) => ()
            _ => fail("Expected wrapped global.get result")
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
  let mod = Module::new()
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
  let t_import = make_func_type_rec([], [ValType::f32()])
  let t_main = make_func_type_rec([ValType::f32()], [ValType::f32()])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_import, t_main]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("source"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::f32(), false),
          Expr::new([Instruction::f32_const(F32(2.0))]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::binary(
              BinaryOp::f32_add(),
              TInstr::call(FuncIdx::new(0), []),
              TInstr::select(
                Some([ValType::f32()]),
                TInstr::i32_const(1),
                TInstr::local_get(LocalIdx::new(0)),
                TInstr::global_get(GlobalIdx::new(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  let once = match run_denam(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected de_nan error on first run: \{e}")
  }
  let twice = match run_denam(once) {
    Ok(m) => m
    Err(e) => fail("unexpected de_nan error on second run: \{e}")
  }
  match once.func_sec {
    Some(FuncSec(type_idxs)) =>
      assert_eq(
        type_idxs.length(),
        2,
        msg="first run should append one helper body/type",
      )
    None => fail("expected func section after transformation")
  }
  assert_eq(once.type_sec, twice.type_sec, msg="type section should be stable")
  assert_eq(once.func_sec, twice.func_sec, msg="func section should be stable")
  match (once.code_sec, twice.code_sec) {
    (Some(CodeSec(funcs1)), Some(CodeSec(funcs2))) => {
      assert_eq(funcs1, funcs2, msg="running de_nan twice should be idempotent")
      assert_eq(funcs1.length(), 2, msg="second run should not add new helpers")
      match funcs1[0] {
        TFunc(_, TExpr(instrs)) =>
          match instrs[0] {
            TLocalSet(LocalIdx(0), TCall(FuncIdx(helper_idx), _)) =>
              assert_eq(
                helper_idx,
                2U,
                msg="helper index should remain stable (1 import + 1 defined)",
              )
            _ => fail("expected stable parameter sanitizer using deNan helper")
          }
        _ => fail("expected transformed main function")
      }
    }
    _ => fail("expected code sections after both runs")
  }
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
