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
fn oi_is_power_of_2_i32(x : Int) -> Bool {
  x > 0 && (x & (x - 1)) == 0
}

///|
fn oi_is_power_of_2_i64(x : Int64) -> Bool {
  x > 0L && (x & (x - 1L)) == 0L
}

///|
fn oi_log2_i32(x : Int) -> Int {
  x.ctz()
}

///|
fn oi_log2_i64(x : Int64) -> Int64 {
  x.ctz().to_int64()
}

///|
fn oi_wrap_i32(x : Int) -> Int {
  (x.reinterpret_as_uint() & 0xffffffff).reinterpret_as_int()
}

///|
fn oi_wrap_i64(x : Int64) -> Int64 {
  x.reinterpret_as_uint64().reinterpret_as_int64()
}

///|
fn oi_const_i32(instr : TInstr) -> Int? {
  match instr {
    TI32Const(I32(v)) => Some(v)
    _ => None
  }
}

///|
fn oi_is_const(instr : TInstr) -> Bool {
  match instr {
    TI32Const(_) | TI64Const(_) | TF32Const(_) | TF64Const(_) => true
    _ => false
  }
}

///|
fn oi_instr_stmt(instr : TInstr, env : Env) -> TInstr {
  match lcs_infer_tinstr_type(instr, env) {
    Some(_) => TInstr::drop(instr)
    None => instr
  }
}

///|
fn oi_seq(stmts : Array[TInstr], result : TInstr, env : Env) -> TInstr {
  if stmts.is_empty() {
    result
  } else {
    let list = stmts.copy()
    list.push(result)
    let bt = match lcs_infer_tinstr_type(result, env) {
      Some(vt) => BlockType::val_type(vt)
      None => BlockType::void_()
    }
    TInstr::block(bt, TExpr::new(list))
  }
}

///|
fn oi_can_reorder(a : TInstr, b : TInstr) -> Bool {
  let ea = lcs_collect_effects(a)
  let eb = lcs_collect_effects(b)
  !ea.invalidates(eb) && !eb.invalidates(ea)
}

///|
fn oi_has_side_effects(instr : TInstr) -> Bool {
  let e = lcs_collect_effects(instr)
  e.has_unremovable_side_effects() || e.reads_memory || e.reads_globals
}

///|
fn oi_is_symmetric(op : BinaryOp) -> Bool {
  match op {
    I32EqOp
    | I32NeOp
    | I64EqOp
    | I64NeOp
    | F32EqOp
    | F32NeOp
    | F64EqOp
    | F64NeOp
    | I32AddOp
    | I32MulOp
    | I32AndOp
    | I32OrOp
    | I32XorOp
    | I64AddOp
    | I64MulOp
    | I64AndOp
    | I64OrOp
    | I64XorOp
    | F32AddOp
    | F32MulOp
    | F64AddOp
    | F64MulOp => true
    _ => false
  }
}

///|
fn oi_is_relational(op : BinaryOp) -> Bool {
  match op {
    I32EqOp
    | I32NeOp
    | I32LtSOp
    | I32LtUOp
    | I32GtSOp
    | I32GtUOp
    | I32LeSOp
    | I32LeUOp
    | I32GeSOp
    | I32GeUOp
    | I64EqOp
    | I64NeOp
    | I64LtSOp
    | I64LtUOp
    | I64GtSOp
    | I64GtUOp
    | I64LeSOp
    | I64LeUOp
    | I64GeSOp
    | I64GeUOp
    | F32EqOp
    | F32NeOp
    | F32LtOp
    | F32GtOp
    | F32LeOp
    | F32GeOp
    | F64EqOp
    | F64NeOp
    | F64LtOp
    | F64GtOp
    | F64LeOp
    | F64GeOp => true
    _ => false
  }
}

///|
fn oi_reverse_relational(op : BinaryOp) -> BinaryOp? {
  match op {
    I32EqOp => Some(BinaryOp::i32_eq())
    I32NeOp => Some(BinaryOp::i32_ne())
    I32LtSOp => Some(BinaryOp::i32_gt_s())
    I32LtUOp => Some(BinaryOp::i32_gt_u())
    I32LeSOp => Some(BinaryOp::i32_ge_s())
    I32LeUOp => Some(BinaryOp::i32_ge_u())
    I32GtSOp => Some(BinaryOp::i32_lt_s())
    I32GtUOp => Some(BinaryOp::i32_lt_u())
    I32GeSOp => Some(BinaryOp::i32_le_s())
    I32GeUOp => Some(BinaryOp::i32_le_u())
    I64EqOp => Some(BinaryOp::i64_eq())
    I64NeOp => Some(BinaryOp::i64_ne())
    I64LtSOp => Some(BinaryOp::i64_gt_s())
    I64LtUOp => Some(BinaryOp::i64_gt_u())
    I64LeSOp => Some(BinaryOp::i64_ge_s())
    I64LeUOp => Some(BinaryOp::i64_ge_u())
    I64GtSOp => Some(BinaryOp::i64_lt_s())
    I64GtUOp => Some(BinaryOp::i64_lt_u())
    I64GeSOp => Some(BinaryOp::i64_le_s())
    I64GeUOp => Some(BinaryOp::i64_le_u())
    F32EqOp => Some(BinaryOp::f32_eq())
    F32NeOp => Some(BinaryOp::f32_ne())
    F32LtOp => Some(BinaryOp::f32_gt())
    F32LeOp => Some(BinaryOp::f32_ge())
    F32GtOp => Some(BinaryOp::f32_lt())
    F32GeOp => Some(BinaryOp::f32_le())
    F64EqOp => Some(BinaryOp::f64_eq())
    F64NeOp => Some(BinaryOp::f64_ne())
    F64LtOp => Some(BinaryOp::f64_gt())
    F64LeOp => Some(BinaryOp::f64_ge())
    F64GtOp => Some(BinaryOp::f64_lt())
    F64GeOp => Some(BinaryOp::f64_le())
    _ => None
  }
}

///|
fn oi_invert_relational(op : BinaryOp) -> BinaryOp? {
  match op {
    I32EqOp => Some(BinaryOp::i32_ne())
    I32NeOp => Some(BinaryOp::i32_eq())
    I32LtSOp => Some(BinaryOp::i32_ge_s())
    I32LtUOp => Some(BinaryOp::i32_ge_u())
    I32LeSOp => Some(BinaryOp::i32_gt_s())
    I32LeUOp => Some(BinaryOp::i32_gt_u())
    I32GtSOp => Some(BinaryOp::i32_le_s())
    I32GtUOp => Some(BinaryOp::i32_le_u())
    I32GeSOp => Some(BinaryOp::i32_lt_s())
    I32GeUOp => Some(BinaryOp::i32_lt_u())
    I64EqOp => Some(BinaryOp::i64_ne())
    I64NeOp => Some(BinaryOp::i64_eq())
    I64LtSOp => Some(BinaryOp::i64_ge_s())
    I64LtUOp => Some(BinaryOp::i64_ge_u())
    I64LeSOp => Some(BinaryOp::i64_gt_s())
    I64LeUOp => Some(BinaryOp::i64_gt_u())
    I64GtSOp => Some(BinaryOp::i64_le_s())
    I64GtUOp => Some(BinaryOp::i64_le_u())
    I64GeSOp => Some(BinaryOp::i64_lt_s())
    I64GeUOp => Some(BinaryOp::i64_lt_u())
    F32EqOp => Some(BinaryOp::f32_ne())
    F32NeOp => Some(BinaryOp::f32_eq())
    F64EqOp => Some(BinaryOp::f64_ne())
    F64NeOp => Some(BinaryOp::f64_eq())
    _ => None
  }
}

///|
fn oi_is_shift(op : BinaryOp) -> Bool {
  match op {
    I32ShlOp
    | I32ShrSOp
    | I32ShrUOp
    | I32RotlOp
    | I32RotrOp
    | I64ShlOp
    | I64ShrSOp
    | I64ShrUOp
    | I64RotlOp
    | I64RotrOp => true
    _ => false
  }
}

///|
fn oi_is_i32_shift(op : BinaryOp) -> Bool {
  match op {
    I32ShlOp | I32ShrSOp | I32ShrUOp | I32RotlOp | I32RotrOp => true
    _ => false
  }
}

///|
fn oi_is_i64_shift(op : BinaryOp) -> Bool {
  match op {
    I64ShlOp | I64ShrSOp | I64ShrUOp | I64RotlOp | I64RotrOp => true
    _ => false
  }
}

///|
fn oi_negate_const(instr : TInstr) -> TInstr? {
  match instr {
    TI32Const(I32(v)) => Some(TInstr::i32_const(I32(oi_wrap_i32(-v))))
    TI64Const(I64(v)) => Some(TInstr::i64_const(I64(oi_wrap_i64(-v))))
    TF32Const(F32(v)) => Some(TInstr::f32_const(F32(-v)))
    TF64Const(F64(v)) => Some(TInstr::f64_const(F64(-v)))
    _ => None
  }
}

///|
fn oi_make_binary(op : BinaryOp, left : TInstr, right : TInstr) -> TInstr {
  TInstr::binary(op, left, right)
}

///|
fn oi_optimize_boolean(
  cond : TInstr,
  _env : Env,
  _options : OptimizeOptions,
) -> TInstr {
  match cond {
    TUnary(I32EqzOp, TUnary(I32EqzOp, value)) => value
    TUnary(I32EqzOp, TBinary(op, left, right)) =>
      match oi_invert_relational(op) {
        Some(inv) => TInstr::binary(inv, left, right)
        None => cond
      }
    TUnary(I32EqzOp, value) =>
      match value {
        TI32Const(I32(v)) => TInstr::i32_const(I32(if v == 0 { 1 } else { 0 }))
        _ => cond
      }
    TBinary(I32NeOp, value, TI32Const(I32(0))) => value
    TBinary(I32SubOp, TI32Const(I32(0)), value) => value
    _ => cond
  }
}

///|
fn oi_optimize_with_const_right(
  op : BinaryOp,
  left : TInstr,
  right : TInstr,
  env : Env,
  options : OptimizeOptions,
) -> TInstr? {
  match (op, right) {
    (I32ShlOp, TI32Const(I32(0)))
    | (I32ShrSOp, TI32Const(I32(0)))
    | (I32ShrUOp, TI32Const(I32(0)))
    | (I32RotlOp, TI32Const(I32(0)))
    | (I32RotrOp, TI32Const(I32(0)))
    | (I64ShlOp, TI64Const(I64(0L)))
    | (I64ShrSOp, TI64Const(I64(0L)))
    | (I64ShrUOp, TI64Const(I64(0L)))
    | (I64RotlOp, TI64Const(I64(0L)))
    | (I64RotrOp, TI64Const(I64(0L)))
    | (I32OrOp, TI32Const(I32(0)))
    | (I32XorOp, TI32Const(I32(0)))
    | (I64OrOp, TI64Const(I64(0L)))
    | (I64XorOp, TI64Const(I64(0L)))
    | (I32AddOp, TI32Const(I32(0)))
    | (I64AddOp, TI64Const(I64(0L)))
    | (I32SubOp, TI32Const(I32(0)))
    | (I64SubOp, TI64Const(I64(0L))) => Some(left)
    (I32AndOp, TI32Const(I32(-1))) | (I64AndOp, TI64Const(I64(-1L))) =>
      Some(left)
    (I32AndOp, TI32Const(I32(0))) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I64AndOp, TI64Const(I64(0L))) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i64_const(I64(0L)), env))
    (I32OrOp, TI32Const(I32(-1))) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(-1)), env))
    (I64OrOp, TI64Const(I64(-1L))) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i64_const(I64(-1L)), env))
    (I32EqOp, TI32Const(I32(0))) =>
      Some(TInstr::unary(UnaryOp::i32_eqz(), left))
    (I64EqOp, TI64Const(I64(0L))) =>
      Some(TInstr::unary(UnaryOp::i64_eqz(), left))
    (I32MulOp, TI32Const(I32(1)))
    | (I64MulOp, TI64Const(I64(1L)))
    | (I32DivSOp, TI32Const(I32(1)))
    | (I32DivUOp, TI32Const(I32(1)))
    | (I64DivSOp, TI64Const(I64(1L)))
    | (I64DivUOp, TI64Const(I64(1L))) => Some(left)
    (I32MulOp, TI32Const(I32(0))) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I64MulOp, TI64Const(I64(0L))) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i64_const(I64(0L)), env))
    (I32RemSOp, TI32Const(I32(1)))
    | (I32RemUOp, TI32Const(I32(1)))
    | (I32RemSOp, TI32Const(I32(-1))) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I64RemSOp, TI64Const(I64(1L)))
    | (I64RemUOp, TI64Const(I64(1L)))
    | (I64RemSOp, TI64Const(I64(-1L))) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i64_const(I64(0L)), env))
    (I32GeUOp, TI32Const(I32(0))) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(1)), env))
    (I64GeUOp, TI64Const(I64(0L))) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(1)), env))
    (I32LtUOp, TI32Const(I32(0))) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I64LtUOp, TI64Const(I64(0L))) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I32LeUOp, TI32Const(I32(-1))) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(1)), env))
    (I64LeUOp, TI64Const(I64(-1L))) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(1)), env))
    (I32GtUOp, TI32Const(I32(-1))) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I64GtUOp, TI64Const(I64(-1L))) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I32LtUOp, TI32Const(I32(-1))) =>
      Some(TInstr::binary(BinaryOp::i32_ne(), left, TInstr::i32_const(I32(-1))))
    (I64LtUOp, TI64Const(I64(-1L))) =>
      Some(
        TInstr::binary(BinaryOp::i64_ne(), left, TInstr::i64_const(I64(-1L))),
      )
    (I32LeUOp, TI32Const(I32(0))) =>
      Some(TInstr::binary(BinaryOp::i32_eq(), left, TInstr::i32_const(I32(0))))
    (I64LeUOp, TI64Const(I64(0L))) =>
      Some(TInstr::binary(BinaryOp::i64_eq(), left, TInstr::i64_const(I64(0L))))
    (I32GtUOp, TI32Const(I32(0))) =>
      Some(TInstr::binary(BinaryOp::i32_ne(), left, TInstr::i32_const(I32(0))))
    (I64GtUOp, TI64Const(I64(0L))) =>
      Some(TInstr::binary(BinaryOp::i64_ne(), left, TInstr::i64_const(I64(0L))))
    (I32GeUOp, TI32Const(I32(-1))) =>
      Some(TInstr::binary(BinaryOp::i32_eq(), left, TInstr::i32_const(I32(-1))))
    (I64GeUOp, TI64Const(I64(-1L))) =>
      Some(
        TInstr::binary(BinaryOp::i64_eq(), left, TInstr::i64_const(I64(-1L))),
      )
    (I32MulOp, TI32Const(I32(-1))) =>
      Some(TInstr::binary(BinaryOp::i32_sub(), TInstr::i32_const(I32(0)), left))
    (I64MulOp, TI64Const(I64(-1L))) =>
      Some(
        TInstr::binary(BinaryOp::i64_sub(), TInstr::i64_const(I64(0L)), left),
      )
    (I32DivUOp, TI32Const(I32(c))) =>
      if oi_is_power_of_2_i32(c) {
        Some(
          TInstr::binary(
            BinaryOp::i32_shr_u(),
            left,
            TInstr::i32_const(I32(oi_log2_i32(c))),
          ),
        )
      } else {
        None
      }
    (I64DivUOp, TI64Const(I64(c))) =>
      if oi_is_power_of_2_i64(c) {
        Some(
          TInstr::binary(
            BinaryOp::i64_shr_u(),
            left,
            TInstr::i64_const(I64(oi_log2_i64(c))),
          ),
        )
      } else {
        None
      }
    (I32RemUOp, TI32Const(I32(c))) =>
      if oi_is_power_of_2_i32(c) {
        Some(
          TInstr::binary(
            BinaryOp::i32_and(),
            left,
            TInstr::i32_const(I32(oi_wrap_i32(c - 1))),
          ),
        )
      } else {
        None
      }
    (I64RemUOp, TI64Const(I64(c))) =>
      if oi_is_power_of_2_i64(c) {
        Some(
          TInstr::binary(
            BinaryOp::i64_and(),
            left,
            TInstr::i64_const(I64(oi_wrap_i64(c - 1L))),
          ),
        )
      } else {
        None
      }
    (I32MulOp, TI32Const(I32(c))) =>
      if oi_is_power_of_2_i32(c) {
        Some(
          TInstr::binary(
            BinaryOp::i32_shl(),
            left,
            TInstr::i32_const(I32(oi_log2_i32(c))),
          ),
        )
      } else {
        None
      }
    (I64MulOp, TI64Const(I64(c))) =>
      if oi_is_power_of_2_i64(c) {
        Some(
          TInstr::binary(
            BinaryOp::i64_shl(),
            left,
            TInstr::i64_const(I64(oi_log2_i64(c))),
          ),
        )
      } else {
        None
      }
    (F32MulOp, TF32Const(F32(-1.0))) =>
      Some(TInstr::unary(UnaryOp::f32_neg(), left))
    (F64MulOp, TF64Const(F64(-1.0))) =>
      Some(TInstr::unary(UnaryOp::f64_neg(), left))
    (F32AddOp, TF32Const(F32(v))) =>
      if options.optimize_level > 0 && v == 0.0 {
        Some(left)
      } else {
        None
      }
    (F64AddOp, TF64Const(F64(v))) =>
      if options.optimize_level > 0 && v == 0.0 {
        Some(left)
      } else {
        None
      }
    _ => None
  }
}

///|
fn oi_optimize_with_const_left(
  op : BinaryOp,
  left : TInstr,
  right : TInstr,
  _env : Env,
) -> TInstr? {
  match (op, left) {
    (I32ShlOp, TI32Const(I32(0)))
    | (I32ShrSOp, TI32Const(I32(0)))
    | (I32ShrUOp, TI32Const(I32(0)))
    | (I64ShlOp, TI64Const(I64(0L)))
    | (I64ShrSOp, TI64Const(I64(0L)))
    | (I64ShrUOp, TI64Const(I64(0L))) =>
      if !oi_has_side_effects(right) {
        Some(left)
      } else {
        None
      }
    (I32ShrSOp, TI32Const(I32(-1)))
    | (I32RotlOp, TI32Const(I32(-1)))
    | (I32RotrOp, TI32Const(I32(-1)))
    | (I64ShrSOp, TI64Const(I64(-1L)))
    | (I64RotlOp, TI64Const(I64(-1L)))
    | (I64RotrOp, TI64Const(I64(-1L))) =>
      if !oi_has_side_effects(right) {
        Some(left)
      } else {
        None
      }
    (I32SubOp, TI32Const(I32(c1))) =>
      match right {
        TBinary(I32AddOp, x, TI32Const(I32(c2))) =>
          Some(
            TInstr::binary(
              BinaryOp::i32_sub(),
              TInstr::i32_const(I32(oi_wrap_i32(c1 - c2))),
              x,
            ),
          )
        TBinary(I32SubOp, TI32Const(I32(c2)), x) =>
          Some(
            TInstr::binary(
              BinaryOp::i32_add(),
              x,
              TInstr::i32_const(I32(oi_wrap_i32(c1 - c2))),
            ),
          )
        _ => None
      }
    (I64SubOp, TI64Const(I64(c1))) =>
      match right {
        TBinary(I64AddOp, x, TI64Const(I64(c2))) =>
          Some(
            TInstr::binary(
              BinaryOp::i64_sub(),
              TInstr::i64_const(I64(oi_wrap_i64(c1 - c2))),
              x,
            ),
          )
        TBinary(I64SubOp, TI64Const(I64(c2)), x) =>
          Some(
            TInstr::binary(
              BinaryOp::i64_add(),
              x,
              TInstr::i64_const(I64(oi_wrap_i64(c1 - c2))),
            ),
          )
        _ => None
      }
    _ => None
  }
}

///|
fn oi_optimize_binary(
  op0 : BinaryOp,
  left0 : TInstr,
  right0 : TInstr,
  env : Env,
  options : OptimizeOptions,
) -> TInstr? {
  let mut op = op0
  let mut left = left0
  let mut right = right0
  let mut changed = false
  if oi_is_symmetric(op) &&
    oi_is_const(left) &&
    !oi_is_const(right) &&
    oi_can_reorder(left, right) {
    let tmp = left
    left = right
    right = tmp
    changed = true
  }
  if oi_is_relational(op) &&
    oi_is_const(left) &&
    !oi_is_const(right) &&
    oi_can_reorder(left, right) {
    match oi_reverse_relational(op) {
      Some(next) => {
        op = next
        let tmp = left
        left = right
        right = tmp
        changed = true
      }
      None => ()
    }
  }
  if (
      op == BinaryOp::i32_sub() ||
      op == BinaryOp::i64_sub() ||
      op == BinaryOp::f32_sub() ||
      op == BinaryOp::f64_sub()
    ) &&
    oi_is_const(right) {
    match oi_negate_const(right) {
      Some(neg_right) => {
        right = neg_right
        op = match op {
          I32SubOp => BinaryOp::i32_add()
          I64SubOp => BinaryOp::i64_add()
          F32SubOp => BinaryOp::f32_add()
          F64SubOp => BinaryOp::f64_add()
          _ => op
        }
        changed = true
      }
      None => ()
    }
  }
  if oi_is_shift(op) {
    match (op, right) {
      (op, TI32Const(I32(v))) if oi_is_i32_shift(op) => {
        let eff = v & 31
        if eff != v {
          right = TInstr::i32_const(I32(eff))
          changed = true
        }
        if eff == 0 {
          return Some(left)
        }
      }
      (op, TI64Const(I64(v))) if oi_is_i64_shift(op) => {
        let eff = v & 63L
        if eff != v {
          right = TInstr::i64_const(I64(eff))
          changed = true
        }
        if eff == 0L {
          return Some(left)
        }
      }
      (_, TBinary(I32AndOp, y, TI32Const(I32(mask)))) if oi_is_i32_shift(op) =>
        if (mask & 31) == 31 {
          right = y
          changed = true
        }
      (_, TBinary(I64AndOp, y, TI64Const(I64(mask)))) if oi_is_i64_shift(op) =>
        if (mask & 63L) == 63L {
          right = y
          changed = true
        }
      _ => ()
    }
  }
  if op == BinaryOp::i32_and() {
    match (left, right) {
      (TUnary(I32EqzOp, x), TUnary(I32EqzOp, y)) =>
        return Some(
          TInstr::unary(
            UnaryOp::i32_eqz(),
            TInstr::binary(BinaryOp::i32_or(), x, y),
          ),
        )
      _ => ()
    }
  }
  match (op, left, right) {
    (F32AddOp, TUnary(F32NegOp, x), y) =>
      if oi_can_reorder(x, y) {
        return Some(TInstr::binary(BinaryOp::f32_sub(), y, x))
      }
    (F64AddOp, TUnary(F64NegOp, x), y) =>
      if oi_can_reorder(x, y) {
        return Some(TInstr::binary(BinaryOp::f64_sub(), y, x))
      }
    (F32AddOp, x, TUnary(F32NegOp, y)) =>
      return Some(TInstr::binary(BinaryOp::f32_sub(), x, y))
    (F64AddOp, x, TUnary(F64NegOp, y)) =>
      return Some(TInstr::binary(BinaryOp::f64_sub(), x, y))
    (F32SubOp, x, TUnary(F32NegOp, y)) =>
      return Some(TInstr::binary(BinaryOp::f32_add(), x, y))
    (F64SubOp, x, TUnary(F64NegOp, y)) =>
      return Some(TInstr::binary(BinaryOp::f64_add(), x, y))
    (
      I32MulOp,
      TBinary(I32SubOp, TI32Const(I32(0)), x),
      TBinary(I32SubOp, TI32Const(I32(0)), y),
    ) => return Some(TInstr::binary(BinaryOp::i32_mul(), x, y))
    (
      I64MulOp,
      TBinary(I64SubOp, TI64Const(I64(0L)), x),
      TBinary(I64SubOp, TI64Const(I64(0L)), y),
    ) => return Some(TInstr::binary(BinaryOp::i64_mul(), x, y))
    (I32MulOp, TBinary(I32SubOp, TI32Const(I32(0)), x), y) =>
      if !oi_is_const(x) && !oi_is_const(y) {
        return Some(
          TInstr::binary(
            BinaryOp::i32_sub(),
            TInstr::i32_const(I32(0)),
            TInstr::binary(BinaryOp::i32_mul(), x, y),
          ),
        )
      }
    (I32MulOp, x, TBinary(I32SubOp, TI32Const(I32(0)), y)) =>
      if !oi_is_const(x) && !oi_is_const(y) {
        return Some(
          TInstr::binary(
            BinaryOp::i32_sub(),
            TInstr::i32_const(I32(0)),
            TInstr::binary(BinaryOp::i32_mul(), x, y),
          ),
        )
      }
    (I64MulOp, TBinary(I64SubOp, TI64Const(I64(0L)), x), y) =>
      if !oi_is_const(x) && !oi_is_const(y) {
        return Some(
          TInstr::binary(
            BinaryOp::i64_sub(),
            TInstr::i64_const(I64(0L)),
            TInstr::binary(BinaryOp::i64_mul(), x, y),
          ),
        )
      }
    (I64MulOp, x, TBinary(I64SubOp, TI64Const(I64(0L)), y)) =>
      if !oi_is_const(x) && !oi_is_const(y) {
        return Some(
          TInstr::binary(
            BinaryOp::i64_sub(),
            TInstr::i64_const(I64(0L)),
            TInstr::binary(BinaryOp::i64_mul(), x, y),
          ),
        )
      }
    (F32MulOp, TUnary(F32AbsOp, x), TUnary(F32AbsOp, y)) =>
      return Some(
        TInstr::unary(
          UnaryOp::f32_abs(),
          TInstr::binary(BinaryOp::f32_mul(), x, y),
        ),
      )
    (F64MulOp, TUnary(F64AbsOp, x), TUnary(F64AbsOp, y)) =>
      return Some(
        TInstr::unary(
          UnaryOp::f64_abs(),
          TInstr::binary(BinaryOp::f64_mul(), x, y),
        ),
      )
    (F32DivOp, TUnary(F32AbsOp, x), TUnary(F32AbsOp, y)) =>
      return Some(
        TInstr::unary(
          UnaryOp::f32_abs(),
          TInstr::binary(BinaryOp::f32_div(), x, y),
        ),
      )
    (F64DivOp, TUnary(F64AbsOp, x), TUnary(F64AbsOp, y)) =>
      return Some(
        TInstr::unary(
          UnaryOp::f64_abs(),
          TInstr::binary(BinaryOp::f64_div(), x, y),
        ),
      )
    _ => ()
  }
  if oi_is_const(right) {
    match oi_optimize_with_const_right(op, left, right, env, options) {
      Some(rep) => return Some(rep)
      None => ()
    }
  }
  if oi_is_const(left) {
    match oi_optimize_with_const_left(op, left, right, env) {
      Some(rep) => return Some(rep)
      None => ()
    }
  }
  match (op, left, right) {
    (I32EqOp, TBinary(I32SubOp, x, y), TI32Const(I32(0)))
    | (I32NeOp, TBinary(I32SubOp, x, y), TI32Const(I32(0)))
    | (I32GtUOp, TBinary(I32SubOp, x, y), TI32Const(I32(0)))
    | (I32LeUOp, TBinary(I32SubOp, x, y), TI32Const(I32(0))) => {
      let new_op = match op {
        I32GtUOp => BinaryOp::i32_ne()
        I32LeUOp => BinaryOp::i32_eq()
        _ => op
      }
      return Some(TInstr::binary(new_op, x, y))
    }
    (I64EqOp, TBinary(I64SubOp, x, y), TI64Const(I64(0L)))
    | (I64NeOp, TBinary(I64SubOp, x, y), TI64Const(I64(0L)))
    | (I64GtUOp, TBinary(I64SubOp, x, y), TI64Const(I64(0L)))
    | (I64LeUOp, TBinary(I64SubOp, x, y), TI64Const(I64(0L))) => {
      let new_op = match op {
        I64GtUOp => BinaryOp::i64_ne()
        I64LeUOp => BinaryOp::i64_eq()
        _ => op
      }
      return Some(TInstr::binary(new_op, x, y))
    }
    _ => ()
  }
  if left == right && !oi_has_side_effects(left) {
    match op {
      I32SubOp | I32XorOp => return Some(TInstr::i32_const(I32(0)))
      I64SubOp | I64XorOp => return Some(TInstr::i64_const(I64(0L)))
      I32AndOp | I32OrOp | I64AndOp | I64OrOp => return Some(left)
      I32EqOp
      | I32LeSOp
      | I32LeUOp
      | I32GeSOp
      | I32GeUOp
      | I64EqOp
      | I64LeSOp
      | I64LeUOp
      | I64GeSOp
      | I64GeUOp => return Some(TInstr::i32_const(I32(1)))
      I32NeOp
      | I32LtSOp
      | I32LtUOp
      | I32GtSOp
      | I32GtUOp
      | I64NeOp
      | I64LtSOp
      | I64LtUOp
      | I64GtSOp
      | I64GtUOp => return Some(TInstr::i32_const(I32(0)))
      _ => ()
    }
  }
  if changed {
    Some(oi_make_binary(op, left, right))
  } else {
    None
  }
}

///|
fn oi_optimize_unary(
  op : UnaryOp,
  value : TInstr,
  _env : Env,
  options : OptimizeOptions,
) -> TInstr? {
  match (op, value) {
    (I32EqzOp, TBinary(I32SubOp, x, y)) =>
      Some(TInstr::binary(BinaryOp::i32_eq(), x, y))
    (I64EqzOp, TBinary(I64SubOp, x, y)) =>
      Some(TInstr::binary(BinaryOp::i64_eq(), x, y))
    (I32EqzOp, TBinary(I32AddOp, x, TI32Const(I32(c)))) =>
      Some(
        TInstr::binary(
          BinaryOp::i32_eq(),
          x,
          TInstr::i32_const(I32(oi_wrap_i32(-c))),
        ),
      )
    (I64EqzOp, TBinary(I64AddOp, x, TI64Const(I64(c)))) =>
      Some(
        TInstr::binary(
          BinaryOp::i64_eq(),
          x,
          TInstr::i64_const(I64(oi_wrap_i64(-c))),
        ),
      )
    (I32EqzOp, TUnary(I32EqzOp, x)) =>
      if options.shrink_level == 0 {
        Some(TInstr::binary(BinaryOp::i32_ne(), x, TInstr::i32_const(I32(0))))
      } else {
        None
      }
    (I32WrapI64Op, TUnary(I64ExtendI32SOp, x))
    | (I32WrapI64Op, TUnary(I64ExtendI32UOp, x)) => Some(x)
    (I64ExtendI32SOp, TUnary(I32WrapI64Op, x)) =>
      Some(TInstr::unary(UnaryOp::i64_extend32s(), x))
    (I32ReinterpretF32Op, TUnary(F32ReinterpretI32Op, x))
    | (I64ReinterpretF64Op, TUnary(F64ReinterpretI64Op, x))
    | (F32ReinterpretI32Op, TUnary(I32ReinterpretF32Op, x))
    | (F64ReinterpretI64Op, TUnary(I64ReinterpretF64Op, x)) => Some(x)
    (I32ReinterpretF32Op, TLoad(F32LoadOp, memarg, ptr)) =>
      Some(TInstr::load(LoadOp::i32_load(), memarg, ptr))
    (F32ReinterpretI32Op, TLoad(I32LoadOp, memarg, ptr)) =>
      Some(TInstr::load(LoadOp::f32_load(), memarg, ptr))
    (I64ReinterpretF64Op, TLoad(F64LoadOp, memarg, ptr)) =>
      Some(TInstr::load(LoadOp::i64_load(), memarg, ptr))
    (F64ReinterpretI64Op, TLoad(I64LoadOp, memarg, ptr)) =>
      Some(TInstr::load(LoadOp::f64_load(), memarg, ptr))
    (F32AbsOp, TUnary(F32NegOp, x)) =>
      Some(TInstr::unary(UnaryOp::f32_abs(), x))
    (F64AbsOp, TUnary(F64NegOp, x)) =>
      Some(TInstr::unary(UnaryOp::f64_abs(), x))
    (F32AbsOp, TBinary(F32MulOp, x, y)) if x == y =>
      Some(TInstr::binary(BinaryOp::f32_mul(), x, y))
    (F64AbsOp, TBinary(F64MulOp, x, y)) if x == y =>
      Some(TInstr::binary(BinaryOp::f64_mul(), x, y))
    (F32AbsOp, TBinary(F32DivOp, x, y)) if x == y =>
      Some(TInstr::binary(BinaryOp::f32_div(), x, y))
    (F64AbsOp, TBinary(F64DivOp, x, y)) if x == y =>
      Some(TInstr::binary(BinaryOp::f64_div(), x, y))
    (_, TUnary(inner_op, x)) =>
      if inner_op == op {
        match op {
          F32AbsOp
          | F32CeilOp
          | F32FloorOp
          | F32TruncOp
          | F32NearestOp
          | F64AbsOp
          | F64CeilOp
          | F64FloorOp
          | F64TruncOp
          | F64NearestOp
          | I32Extend8SOp
          | I32Extend16SOp
          | I64Extend8SOp
          | I64Extend16SOp
          | I64Extend32SOp => Some(TInstr::unary(op, x))
          F32NegOp | F64NegOp => Some(x)
          _ => None
        }
      } else {
        None
      }
    (I32EqzOp, TBinary(bin_op, x, y)) =>
      match oi_invert_relational(bin_op) {
        Some(inv) => Some(TInstr::binary(inv, x, y))
        None => None
      }
    _ => None
  }
}

///|
fn oi_memory_is_64(mod : Module, memarg : MemArg) -> Bool {
  let MemArg(_, mem_idx, _) = memarg
  match mem_idx {
    Some(MemIdx(raw)) =>
      match mod.mem_sec {
        Some(MemSec(memories)) =>
          match memories.get(raw.reinterpret_as_int()) {
            Some(MemType(I64Limits(_, _))) => true
            _ => false
          }
        None => false
      }
    None =>
      match mod.mem_sec {
        Some(MemSec(memories)) =>
          match memories.get(0) {
            Some(MemType(I64Limits(_, _))) => true
            _ => false
          }
        None => false
      }
  }
}

///|
fn oi_fold_const_ptr_offset(
  ptr : TInstr,
  memarg : MemArg,
  mod : Module,
) -> (TInstr, MemArg) {
  let MemArg(align, mem, U64(offset)) = memarg
  if offset == 0UL {
    return (ptr, memarg)
  }
  match ptr {
    TI32Const(I32(v)) if !oi_memory_is_64(mod, memarg) => {
      let value64 = v.reinterpret_as_uint().to_uint64()
      let max32 = 0x7fffffffUL
      if value64 <= max32 && offset <= max32 && value64 + offset <= max32 {
        let total = value64 + offset
        let out = total.to_uint().reinterpret_as_int()
        (TInstr::i32_const(I32(out)), MemArg::new(align, mem, U64(0UL)))
      } else {
        (ptr, memarg)
      }
    }
    TI64Const(I64(v)) if oi_memory_is_64(mod, memarg) => {
      let value64 = v.reinterpret_as_uint64()
      let total = value64 + offset
      if total >= value64 {
        (
          TInstr::i64_const(I64(total.reinterpret_as_int64())),
          MemArg::new(align, mem, U64(0UL)),
        )
      } else {
        (ptr, memarg)
      }
    }
    _ => (ptr, memarg)
  }
}

///|
fn oi_store_bytes(op : StoreOp) -> Int {
  match op {
    I32Store8Op | I64Store8Op | I32AtomicStore8Op | I64AtomicStore8Op => 1
    I32Store16Op | I64Store16Op | I32AtomicStore16Op | I64AtomicStore16Op => 2
    I32StoreOp
    | F32StoreOp
    | I64Store32Op
    | I32AtomicStoreOp
    | I64AtomicStore32Op => 4
    I64StoreOp | F64StoreOp | I64AtomicStoreOp => 8
    V128StoreOp => 16
  }
}

///|
fn oi_store_wrap_upgrade(op : StoreOp) -> StoreOp? {
  match op {
    I32StoreOp => Some(StoreOp::i64_store32())
    I32Store16Op => Some(StoreOp::i64_store16())
    I32Store8Op => Some(StoreOp::i64_store8())
    _ => None
  }
}

///|
fn oi_reinterpret_store(op : StoreOp, value : TInstr) -> (StoreOp, TInstr)? {
  match (op, value) {
    (F32StoreOp, TUnary(F32ReinterpretI32Op, x)) =>
      Some((StoreOp::i32_store(), x))
    (I32StoreOp, TUnary(I32ReinterpretF32Op, x)) =>
      Some((StoreOp::f32_store(), x))
    (F64StoreOp, TUnary(F64ReinterpretI64Op, x)) =>
      Some((StoreOp::i64_store(), x))
    (I64StoreOp, TUnary(I64ReinterpretF64Op, x)) =>
      Some((StoreOp::f64_store(), x))
    _ => None
  }
}

///|
fn oi_optimize_store_value(op : StoreOp, value : TInstr) -> TInstr {
  let bytes = oi_store_bytes(op)
  let value = match value {
    TI32Const(I32(v)) if bytes < 4 => {
      let mask = match bytes {
        1 => 0xff
        2 => 0xffff
        _ => 0xffffffff
      }
      TInstr::i32_const(I32(oi_wrap_i32(v & mask)))
    }
    TI64Const(I64(v)) if bytes < 8 => {
      let mask = match bytes {
        1 => 0xffL
        2 => 0xffffL
        4 => 0xffffffffL
        _ => -1L
      }
      TInstr::i64_const(I64(oi_wrap_i64(v & mask)))
    }
    other => other
  }
  match value {
    TBinary(I32AndOp, x, TI32Const(I32(mask))) =>
      if (bytes == 1 && mask == 0xff) || (bytes == 2 && mask == 0xffff) {
        x
      } else {
        value
      }
    TBinary(I64AndOp, x, TI64Const(I64(mask))) =>
      if (bytes == 1 && mask == 0xffL) ||
        (bytes == 2 && mask == 0xffffL) ||
        (bytes == 4 && mask == 0xffffffffL) {
        x
      } else {
        value
      }
    _ => value
  }
}

///|
fn oi_optimize_memory_copy(
  dst_mem : MemIdx,
  src_mem : MemIdx,
  dest : TInstr,
  source : TInstr,
  size : TInstr,
  env : Env,
) -> TInstr? {
  match size {
    TI32Const(I32(0)) =>
      Some(
        TInstr::block(
          BlockType::void_(),
          TExpr::new([oi_instr_stmt(dest, env), oi_instr_stmt(source, env)]),
        ),
      )
    TI32Const(I32(bytes)) =>
      match bytes {
        1 => {
          let load_memarg = MemArg::new(U32(1), Some(src_mem), U64(0UL))
          let store_memarg = MemArg::new(U32(1), Some(dst_mem), U64(0UL))
          Some(
            TInstr::store(
              StoreOp::i32_store8(),
              store_memarg,
              dest,
              TInstr::load(LoadOp::i32_load8u(), load_memarg, source),
            ),
          )
        }
        2 => {
          let load_memarg = MemArg::new(U32(2), Some(src_mem), U64(0UL))
          let store_memarg = MemArg::new(U32(2), Some(dst_mem), U64(0UL))
          Some(
            TInstr::store(
              StoreOp::i32_store16(),
              store_memarg,
              dest,
              TInstr::load(LoadOp::i32_load16u(), load_memarg, source),
            ),
          )
        }
        4 => {
          let load_memarg = MemArg::new(U32(4), Some(src_mem), U64(0UL))
          let store_memarg = MemArg::new(U32(4), Some(dst_mem), U64(0UL))
          Some(
            TInstr::store(
              StoreOp::i32_store(),
              store_memarg,
              dest,
              TInstr::load(LoadOp::i32_load(), load_memarg, source),
            ),
          )
        }
        8 => {
          let load_memarg = MemArg::new(U32(8), Some(src_mem), U64(0UL))
          let store_memarg = MemArg::new(U32(8), Some(dst_mem), U64(0UL))
          Some(
            TInstr::store(
              StoreOp::i64_store(),
              store_memarg,
              dest,
              TInstr::load(LoadOp::i64_load(), load_memarg, source),
            ),
          )
        }
        _ => None
      }
    _ => None
  }
}

///|
fn oi_optimize_memory_fill(
  mem_idx : MemIdx,
  dest : TInstr,
  value : TInstr,
  size : TInstr,
  env : Env,
) -> TInstr? {
  match size {
    TI32Const(I32(0)) =>
      Some(
        TInstr::block(
          BlockType::void_(),
          TExpr::new([oi_instr_stmt(dest, env), oi_instr_stmt(value, env)]),
        ),
      )
    TI32Const(I32(1)) =>
      Some(
        TInstr::store(
          StoreOp::i32_store8(),
          MemArg::new(U32(1), Some(mem_idx), U64(0UL)),
          dest,
          value,
        ),
      )
    TI32Const(I32(bytes)) =>
      match (bytes, value) {
        (1, TI32Const(I32(v))) =>
          Some(
            TInstr::store(
              StoreOp::i32_store8(),
              MemArg::new(U32(1), Some(mem_idx), U64(0UL)),
              dest,
              TInstr::i32_const(I32(v & 0xff)),
            ),
          )
        (2, TI32Const(I32(v))) => {
          let x = v & 0xff
          Some(
            TInstr::store(
              StoreOp::i32_store16(),
              MemArg::new(U32(2), Some(mem_idx), U64(0UL)),
              dest,
              TInstr::i32_const(I32(oi_wrap_i32(x * 0x0101))),
            ),
          )
        }
        (4, TI32Const(I32(v))) => {
          let x = v & 0xff
          Some(
            TInstr::store(
              StoreOp::i32_store(),
              MemArg::new(U32(4), Some(mem_idx), U64(0UL)),
              dest,
              TInstr::i32_const(I32(oi_wrap_i32(x * 0x01010101))),
            ),
          )
        }
        (8, TI32Const(I32(v))) => {
          let x = (v & 0xff).to_int64()
          Some(
            TInstr::store(
              StoreOp::i64_store(),
              MemArg::new(U32(8), Some(mem_idx), U64(0UL)),
              dest,
              TInstr::i64_const(I64(oi_wrap_i64(x * 0x0101010101010101L))),
            ),
          )
        }
        _ => None
      }
    _ => None
  }
}

///|
fn oi_optimize_select(
  _types : Array[ValType]?,
  cond : TInstr,
  if_true : TInstr,
  if_false : TInstr,
  env : Env,
  options : OptimizeOptions,
) -> TInstr? {
  let cond = oi_optimize_boolean(cond, env, options)
  match cond {
    TI32Const(I32(v)) =>
      if v == 0 {
        Some(oi_seq([oi_instr_stmt(if_true, env)], if_false, env))
      } else {
        Some(oi_seq([oi_instr_stmt(if_false, env)], if_true, env))
      }
    _ =>
      if if_true == if_false {
        if oi_has_side_effects(cond) {
          Some(oi_seq([oi_instr_stmt(cond, env)], if_true, env))
        } else {
          Some(if_true)
        }
      } else {
        let max_bits = match (oi_const_i32(if_true), oi_const_i32(if_false)) {
          (Some(1), Some(0)) => true
          _ => false
        }
        if max_bits {
          Some(cond)
        } else {
          None
        }
      }
  }
}

///|
fn oi_optimize_if(
  bt : BlockType,
  cond : TInstr,
  then_ : TExpr,
  else_ : TExpr?,
  env : Env,
  options : OptimizeOptions,
) -> TInstr? {
  let cond = oi_optimize_boolean(cond, env, options)
  match else_ {
    Some(else_expr) =>
      match cond {
        TUnary(I32EqzOp, value) =>
          Some(TInstr::if_(bt, value, else_expr, Some(then_)))
        _ =>
          if then_ == else_expr {
            if oi_has_side_effects(cond) {
              let list = [oi_instr_stmt(cond, env)]
              for instr in then_.0 {
                list.push(instr)
              }
              Some(TInstr::block(bt, TExpr::new(list)))
            } else {
              Some(TInstr::block(bt, then_))
            }
          } else {
            Some(TInstr::if_(bt, cond, then_, Some(else_expr)))
          }
      }
    None =>
      if cond == oi_optimize_boolean(cond, env, options) {
        None
      } else {
        Some(TInstr::if_(bt, cond, then_, None))
      }
  }
}

///|
fn oi_optimize_once(
  instr : TInstr,
  env : Env,
  options : OptimizeOptions,
  mod : Module,
) -> TInstr {
  match instr {
    TBinary(op, left, right) =>
      match oi_optimize_binary(op, left, right, env, options) {
        Some(rep) => rep
        None => instr
      }
    TUnary(op, value) =>
      match oi_optimize_unary(op, value, env, options) {
        Some(rep) => rep
        None => instr
      }
    TSelect(types, cond, if_true, if_false) =>
      match oi_optimize_select(types, cond, if_true, if_false, env, options) {
        Some(rep) => rep
        None => instr
      }
    TIf(bt, cond, then_, else_) =>
      match oi_optimize_if(bt, cond, then_, else_, env, options) {
        Some(rep) => rep
        None => instr
      }
    TGlobalSet(idx, TGlobalGet(get_idx)) if idx == get_idx => TInstr::nop()
    TBrIf(label, cond, values) =>
      TInstr::br_if(label, oi_optimize_boolean(cond, env, options), values)
    TLoad(op, memarg, ptr) => {
      let (next_ptr, next_memarg) = oi_fold_const_ptr_offset(ptr, memarg, mod)
      TInstr::load(op, next_memarg, next_ptr)
    }
    TStore(op, memarg, ptr, value) => {
      let (next_ptr, next_memarg) = oi_fold_const_ptr_offset(ptr, memarg, mod)
      let mut next_op = op
      let mut next_value = oi_optimize_store_value(op, value)
      match next_value {
        TUnary(I32WrapI64Op, inner) =>
          match oi_store_wrap_upgrade(next_op) {
            Some(upgraded) => {
              next_op = upgraded
              next_value = inner
            }
            None => ()
          }
        _ => ()
      }
      match oi_reinterpret_store(next_op, next_value) {
        Some((rewritten_op, rewritten_value)) => {
          next_op = rewritten_op
          next_value = rewritten_value
        }
        None => ()
      }
      TInstr::store(next_op, next_memarg, next_ptr, next_value)
    }
    TMemoryCopy(dst_mem, src_mem, dest, source, size) =>
      match oi_optimize_memory_copy(dst_mem, src_mem, dest, source, size, env) {
        Some(rep) => rep
        None => instr
      }
    TMemoryFill(mem_idx, dest, value, size) =>
      match oi_optimize_memory_fill(mem_idx, dest, value, size, env) {
        Some(rep) => rep
        None => instr
      }
    TCallRef(type_idx, args, target) =>
      match target {
        TRefFunc(func_idx) => TInstr::call(func_idx, args)
        TTableGet(table_idx, index) =>
          TInstr::call_indirect(type_idx, table_idx, args, index)
        _ => instr
      }
    _ => instr
  }
}

///|
fn oi_optimize_fixpoint(
  instr : TInstr,
  env : Env,
  options : OptimizeOptions,
  mod : Module,
) -> TInstr {
  let mut curr = instr
  let mut rounds = 0
  while rounds < 8 {
    rounds += 1
    let next = oi_optimize_once(curr, env, options, mod)
    if next == curr {
      break
    }
    curr = next
  }
  curr
}

///|
fn optimize_instructions_on_func(
  func : Func,
  mod : Module,
  options : OptimizeOptions,
) -> Func {
  match func {
    TFunc(locals, body) => {
      let env = Env::new().with_module(mod).with_locals(locals)
      let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
        self,
        _,
        curr,
      ) {
        let walked = match self.walk_tinstruction_default((), curr) {
          Ok(Some((_, updated))) => updated
          Ok(None) => curr
          Err(e) => return Err(e)
        }
        let rewritten = oi_optimize_fixpoint(walked, env, options, mod)
        if rewritten == walked {
          unchanged()
        } else {
          change((), rewritten)
        }
      })
      let new_body = match walker.walk_texpr((), body) {
        Ok(Some((_, out))) => out
        Ok(None) => body
        Err(_) => body
      }
      Func::t_func(locals, new_body)
    }
    _ => func
  }
}

///|
fn optimize_instructions_ir_pass(
  mod : Module,
  options : OptimizeOptions,
) -> ModuleTransformer[IRContext] {
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    let next = optimize_instructions_on_func(func, mod, options)
    if next == func {
      unchanged()
    } else {
      change(ctx, next)
    }
  })
}

///|
fn oi_run_func(
  body : Array[TInstr],
  locals? : Array[ValType] = [],
  options? : OptimizeOptions = OptimizeOptions::new(),
  with_memory? : Bool = false,
) -> TExpr {
  let mut mod_ = Module::new().with_code_sec(
    CodeSec::new([Func::t_func(locals, TExpr::new(body))]),
  )
  if with_memory {
    mod_ = mod_.with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, None))]))
  }
  let out = optimize_module_with_options(
    mod_,
    [ModulePass::OptimizeInstructions],
    options,
  ).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, out_body)])) => out_body
    _ => abort("expected one transformed function")
  }
}

///|
test "optimize instructions eqz(sub) to eq" {
  let body = oi_run_func(
    [
      TInstr::unary(
        UnaryOp::i32_eqz(),
        TInstr::binary(
          BinaryOp::i32_sub(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    TExpr([TBinary(I32EqOp, TLocalGet(LocalIdx(i)), TLocalGet(LocalIdx(j)))]) => {
      assert_eq(i.reinterpret_as_int(), 0)
      assert_eq(j.reinterpret_as_int(), 1)
    }
    _ => fail("expected i32.eq")
  }
}

///|
test "optimize instructions eqz(add const) to eq neg const" {
  let body = oi_run_func(
    [
      TInstr::unary(
        UnaryOp::i32_eqz(),
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(5)),
        ),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    TExpr([TBinary(I32EqOp, TLocalGet(_), TI32Const(I32(v)))]) =>
      assert_eq(v, -5)
    _ => fail("expected i32.eq with negated constant")
  }
}

///|
test "optimize instructions de-morgan eqz and" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_and(),
        TInstr::unary(UnaryOp::i32_eqz(), TInstr::local_get(LocalIdx::new(0))),
        TInstr::unary(UnaryOp::i32_eqz(), TInstr::local_get(LocalIdx::new(1))),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    TExpr([TUnary(I32EqzOp, TBinary(I32OrOp, _, _))]) => ()
    _ => fail("expected eqz(or)")
  }
}

///|
test "optimize instructions masks shift constants and removes zero shifts" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_shl(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(32)),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    TExpr([TLocalGet(LocalIdx(i))]) => assert_eq(i.reinterpret_as_int(), 0)
    _ => fail("expected shift-by-32 to collapse to lhs")
  }
}

///|
test "optimize instructions removes rhs mask in shifts" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_shl(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::binary(
          BinaryOp::i32_and(),
          TInstr::local_get(LocalIdx::new(1)),
          TInstr::i32_const(I32(31)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    TExpr([TBinary(I32ShlOp, _, TLocalGet(LocalIdx(i)))]) =>
      assert_eq(i.reinterpret_as_int(), 1)
    _ => fail("expected shift rhs to be simplified to local.get")
  }
}

///|
test "optimize instructions float add neg rhs to sub" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::f32_add(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::unary(UnaryOp::f32_neg(), TInstr::local_get(LocalIdx::new(1))),
      ),
    ],
    locals=[ValType::f32(), ValType::f32()],
  )
  match body {
    TExpr([TBinary(F32SubOp, _, TLocalGet(LocalIdx(i)))]) =>
      assert_eq(i.reinterpret_as_int(), 1)
    _ => fail("expected f32.sub")
  }
}

///|
test "optimize instructions int neg multiply patterns" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_mul(),
        TInstr::binary(
          BinaryOp::i32_sub(),
          TInstr::i32_const(I32(0)),
          TInstr::local_get(LocalIdx::new(0)),
        ),
        TInstr::binary(
          BinaryOp::i32_sub(),
          TInstr::i32_const(I32(0)),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    TExpr([TBinary(I32MulOp, TLocalGet(LocalIdx(i)), TLocalGet(LocalIdx(j)))]) => {
      assert_eq(i.reinterpret_as_int(), 0)
      assert_eq(j.reinterpret_as_int(), 1)
    }
    _ => fail("expected -x * -y => x * y")
  }
}

///|
test "optimize instructions unsigned compare constants" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_ge_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(0)),
      ),
      TInstr::binary(
        BinaryOp::i32_lt_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(0)),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    TExpr([_, _]) => ()
    _ => fail("expected two instructions")
  }
  match body {
    TExpr([first, second]) => {
      match first {
        TBlock(_, TExpr([TDrop(TLocalGet(_)), TI32Const(I32(v))])) =>
          assert_eq(v, 1)
        _ => fail("expected ge_u 0 => 1 preserving lhs")
      }
      match second {
        TBlock(_, TExpr([TDrop(TLocalGet(_)), TI32Const(I32(v))])) =>
          assert_eq(v, 0)
        _ => fail("expected lt_u 0 => 0 preserving lhs")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions power-of-two integer arithmetic" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_mul(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(8)),
      ),
      TInstr::binary(
        BinaryOp::i32_div_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(8)),
      ),
      TInstr::binary(
        BinaryOp::i32_rem_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(8)),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    TExpr([mul_i, div_i, rem_i]) => {
      match mul_i {
        TBinary(I32ShlOp, _, TI32Const(I32(v))) => assert_eq(v, 3)
        _ => fail("expected mul by 8 => shl 3")
      }
      match div_i {
        TBinary(I32ShrUOp, _, TI32Const(I32(v))) => assert_eq(v, 3)
        _ => fail("expected div_u by 8 => shr_u 3")
      }
      match rem_i {
        TBinary(I32AndOp, _, TI32Const(I32(v))) => assert_eq(v, 7)
        _ => fail("expected rem_u by 8 => and 7")
      }
    }
    _ => fail("expected three rewritten instructions")
  }
}

///|
test "optimize instructions arithmetic trivial constants" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_and(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(-1)),
      ),
      TInstr::binary(
        BinaryOp::i32_or(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(-1)),
      ),
      TInstr::binary(
        BinaryOp::i32_eq(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(0)),
      ),
      TInstr::binary(
        BinaryOp::i32_mul(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(-1)),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    TExpr([a0, a1, a2, a3]) => {
      match a0 {
        TLocalGet(_) => ()
        _ => fail("expected and -1 => x")
      }
      match a1 {
        TBlock(_, TExpr([TDrop(_), TI32Const(I32(-1))])) => ()
        _ => fail("expected or -1 => -1 with drop")
      }
      match a2 {
        TUnary(I32EqzOp, _) => ()
        _ => fail("expected eq 0 => eqz")
      }
      match a3 {
        TBinary(I32SubOp, TI32Const(I32(0)), _) => ()
        _ => fail("expected mul -1 => 0 - x")
      }
    }
    _ => fail("expected four rewritten instructions")
  }
}

///|
test "optimize instructions constant-left subtraction patterns" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_sub(),
        TInstr::i32_const(I32(10)),
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(4)),
        ),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    TExpr([TBinary(I32SubOp, TI32Const(I32(c)), TLocalGet(LocalIdx(i)))]) => {
      assert_eq(c, 6)
      assert_eq(i.reinterpret_as_int(), 0)
    }
    _ => fail("expected C1 - (x + C2) rewrite")
  }
}

///|
test "optimize instructions relational x-y compare to zero" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_eq(),
        TInstr::binary(
          BinaryOp::i32_sub(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::local_get(LocalIdx::new(1)),
        ),
        TInstr::i32_const(I32(0)),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    TExpr([TBinary(I32EqOp, TLocalGet(LocalIdx(i)), TLocalGet(LocalIdx(j)))]) => {
      assert_eq(i.reinterpret_as_int(), 0)
      assert_eq(j.reinterpret_as_int(), 1)
    }
    _ => fail("expected x-y==0 => x==y")
  }
}

///|
test "optimize instructions deduplicate equal binary children" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_xor(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(0)),
      ),
      TInstr::binary(
        BinaryOp::i32_eq(),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::local_get(LocalIdx::new(1)),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    TExpr([a0, a1]) => {
      match a0 {
        TI32Const(I32(0)) => ()
        _ => fail("expected x xor x => 0")
      }
      match a1 {
        TI32Const(I32(1)) => ()
        _ => fail("expected x eq x => 1")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions reinterpret chains and load reinterpret" {
  let body = oi_run_func(
    [
      TInstr::unary(
        UnaryOp::i32_reinterpret_f32(),
        TInstr::unary(
          UnaryOp::f32_reinterpret_i32(),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
      TInstr::unary(
        UnaryOp::i32_reinterpret_f32(),
        TInstr::load(
          LoadOp::f32_load(),
          MemArg::new(U32(4), None, U64(0UL)),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
    with_memory=true,
  )
  match body {
    TExpr([a0, a1]) => {
      match a0 {
        TLocalGet(LocalIdx(i)) => assert_eq(i.reinterpret_as_int(), 0)
        _ => fail("expected reinterpret(reinterpret(x)) => x")
      }
      match a1 {
        TLoad(I32LoadOp, _, _) => ()
        _ => fail("expected reinterpret(f32.load) => i32.load")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions if eqz arm flip and fold identical arms" {
  let body = oi_run_func(
    [
      TInstr::if_(
        BlockType::void_(),
        TInstr::unary(UnaryOp::i32_eqz(), TInstr::local_get(LocalIdx::new(0))),
        TExpr::new([TInstr::i32_const(I32(1))]),
        Some(TExpr::new([TInstr::i32_const(I32(2))])),
      ),
      TInstr::if_(
        BlockType::val_type(ValType::i32()),
        TInstr::local_get(LocalIdx::new(0)),
        TExpr::new([TInstr::i32_const(I32(7))]),
        Some(TExpr::new([TInstr::i32_const(I32(7))])),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    TExpr([a0, a1]) => {
      match a0 {
        TIf(
          _,
          TLocalGet(_),
          TExpr([TI32Const(I32(2))]),
          Some(TExpr([TI32Const(I32(1))]))
        ) => ()
        _ => fail("expected if eqz flip")
      }
      match a1 {
        TBlock(_, TExpr([TI32Const(I32(7))])) => ()
        _ => fail("expected identical-arm if fold")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions global.set same global.get becomes nop" {
  let body = oi_run_func([
    TInstr::global_set(GlobalIdx::new(0), TInstr::global_get(GlobalIdx::new(0))),
  ])
  match body {
    TExpr([TNop]) => ()
    _ => fail("expected global.set g (global.get g) => nop")
  }
}

///|
test "optimize instructions memory access folds const pointer into offset" {
  let body = oi_run_func(
    [
      TInstr::load(
        LoadOp::i32_load(),
        MemArg::new(U32(4), None, U64(8UL)),
        TInstr::i32_const(I32(10)),
      ),
      TInstr::store(
        StoreOp::i32_store(),
        MemArg::new(U32(4), None, U64(6UL)),
        TInstr::i32_const(I32(4)),
        TInstr::i32_const(I32(1)),
      ),
    ],
    with_memory=true,
  )
  match body {
    TExpr([l0, s0]) => {
      match l0 {
        TLoad(_, MemArg(_, _, U64(off)), TI32Const(I32(v))) => {
          assert_eq(off, 0UL)
          assert_eq(v, 18)
        }
        _ => fail("expected folded load pointer")
      }
      match s0 {
        TStore(_, MemArg(_, _, U64(off)), TI32Const(I32(v)), _) => {
          assert_eq(off, 0UL)
          assert_eq(v, 10)
        }
        _ => fail("expected folded store pointer")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions store value truncation and wrap upgrade" {
  let body = oi_run_func(
    [
      TInstr::store(
        StoreOp::i32_store8(),
        MemArg::new(U32(1), None, U64(0UL)),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(0x1234)),
      ),
      TInstr::store(
        StoreOp::i32_store(),
        MemArg::new(U32(4), None, U64(0UL)),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::unary(
          UnaryOp::i32_wrap_i64(),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i64()],
    with_memory=true,
  )
  match body {
    TExpr([s0, s1]) => {
      match s0 {
        TStore(I32Store8Op, _, _, TI32Const(I32(v))) => assert_eq(v, 0x34)
        _ => fail("expected store8 const truncation")
      }
      match s1 {
        TStore(I64Store32Op, _, _, TLocalGet(LocalIdx(i))) =>
          assert_eq(i.reinterpret_as_int(), 1)
        _ => fail("expected wrap_i64 store upgrade to i64.store32")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions reinterpret store rewrites value type" {
  let body = oi_run_func(
    [
      TInstr::store(
        StoreOp::f32_store(),
        MemArg::new(U32(4), None, U64(0UL)),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::unary(
          UnaryOp::f32_reinterpret_i32(),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
    with_memory=true,
  )
  match body {
    TExpr([TStore(I32StoreOp, _, _, TLocalGet(LocalIdx(i)))]) =>
      assert_eq(i.reinterpret_as_int(), 1)
    _ => fail("expected f32.store(reinterpret_i32) => i32.store")
  }
}

///|
test "optimize instructions memory.copy rewrites constants" {
  let body = oi_run_func(
    [
      TInstr::memory_copy(
        MemIdx::new(0),
        MemIdx::new(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::i32_const(I32(0)),
      ),
      TInstr::memory_copy(
        MemIdx::new(0),
        MemIdx::new(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::i32_const(I32(4)),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
    with_memory=true,
  )
  match body {
    TExpr([c0, c1]) => {
      match c0 {
        TBlock(_, TExpr([TDrop(_), TDrop(_)])) => ()
        _ => fail("expected memory.copy size 0 rewrite")
      }
      match c1 {
        TStore(I32StoreOp, _, _, TLoad(I32LoadOp, _, _)) => ()
        _ => fail("expected memory.copy size 4 => store(load)")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions memory.fill rewrites constants" {
  let body = oi_run_func(
    [
      TInstr::memory_fill(
        MemIdx::new(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::i32_const(I32(0)),
      ),
      TInstr::memory_fill(
        MemIdx::new(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::i32_const(I32(1)),
      ),
      TInstr::memory_fill(
        MemIdx::new(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(0xaa)),
        TInstr::i32_const(I32(4)),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
    with_memory=true,
  )
  match body {
    TExpr([f0, f1, f2]) => {
      match f0 {
        TBlock(_, TExpr([TDrop(_), TDrop(_)])) => ()
        _ => fail("expected memory.fill size 0 rewrite")
      }
      match f1 {
        TStore(I32Store8Op, _, _, _) => ()
        _ => fail("expected memory.fill size 1 => store8")
      }
      match f2 {
        TStore(I32StoreOp, _, _, TI32Const(I32(v))) => assert_eq(v, 0xaaaaaaaa)
        _ =>
          fail("expected memory.fill const size 4 => i32.store const pattern")
      }
    }
    _ => fail("expected three rewritten instructions")
  }
}

///|
test "optimize instructions select constant condition and equal arms" {
  let body = oi_run_func(
    [
      TInstr::select(
        None,
        TInstr::i32_const(I32(0)),
        TInstr::i32_const(I32(1)),
        TInstr::local_get(LocalIdx::new(0)),
      ),
      TInstr::select(
        Some([ValType::i32()]),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(7)),
        TInstr::i32_const(I32(7)),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    TExpr([s0, s1]) => {
      match s0 {
        TBlock(_, TExpr([TDrop(TI32Const(I32(1))), TLocalGet(LocalIdx(i))])) =>
          assert_eq(i.reinterpret_as_int(), 0)
        _ => fail("expected select cond=0 rewrite")
      }
      match s1 {
        TI32Const(I32(7)) => ()
        _ => fail("expected select equal arms fold")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions call_ref direct simplifications" {
  let type_sec = TypeSec::new([
    single_rec_type(comp_type_sub_type(func_comp_type([], [ValType::i32()]))),
  ])
  let func_sec = FuncSec::new([TypeIdx::new(0)])
  let code_sec = CodeSec::new([
    Func::t_func(
      [],
      TExpr::new([
        TInstr::call_ref(TypeIdx::new(0), [], TInstr::ref_func(FuncIdx::new(0))),
      ]),
    ),
  ])
  let mod_ = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
  let out = optimize_module(mod_, [ModulePass::OptimizeInstructions]).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCall(FuncIdx(raw), _)]))])) =>
      assert_eq(raw.reinterpret_as_int(), 0)
    _ => fail("expected call_ref(ref.func) => call")
  }
}

///|
test "optimize instructions helper arithmetic and relational utilities cover i64 and negative paths" {
  assert_true(oi_is_power_of_2_i64(8L))
  assert_false(oi_is_power_of_2_i64(0L))
  assert_eq(oi_log2_i64(8L), 3L)
  assert_eq(oi_wrap_i64(-1L), -1L)

  assert_eq(oi_const_i32(TInstr::i32_const(I32(11))), Some(11))
  assert_eq(oi_const_i32(TInstr::i64_const(I64(11L))), None)

  assert_eq(
    oi_reverse_relational(BinaryOp::i32_lt_s()),
    Some(BinaryOp::i32_gt_s()),
  )
  assert_eq(oi_invert_relational(BinaryOp::i32_eq()), Some(BinaryOp::i32_ne()))
  assert_eq(oi_invert_relational(BinaryOp::i32_add()), None)

  assert_true(oi_is_i64_shift(BinaryOp::i64_shl()))
  assert_false(oi_is_i32_shift(BinaryOp::i64_shl()))
  assert_true(oi_negate_const(TInstr::i64_const(I64(5L))) is Some(_))
}

///|
test "optimize instructions helper sequencing boolean and reorder checks" {
  let env = Env::new()
  assert_eq(oi_instr_stmt(TInstr::nop(), env), TInstr::nop())
  assert_eq(oi_seq([], TInstr::nop(), env), TInstr::nop())
  match oi_seq([TInstr::i32_const(I32(1))], TInstr::nop(), env) {
    TBlock(VoidBlockType, TExpr([_, TNop])) => ()
    _ => fail("expected oi_seq to emit block for non-empty statements")
  }

  assert_true(
    oi_can_reorder(TInstr::i32_const(I32(1)), TInstr::i32_const(I32(2))),
  )
  assert_false(
    oi_can_reorder(
      TInstr::global_set(GlobalIdx::new(0), TInstr::i32_const(I32(1))),
      TInstr::global_get(GlobalIdx::new(0)),
    ),
  )

  let eqz_eqz = oi_optimize_boolean(
    TInstr::unary(
      UnaryOp::i32_eqz(),
      TInstr::unary(UnaryOp::i32_eqz(), TInstr::local_get(LocalIdx::new(0))),
    ),
    env,
    OptimizeOptions::new(),
  )
  assert_eq(eqz_eqz, TInstr::local_get(LocalIdx::new(0)))

  let eqz_const = oi_optimize_boolean(
    TInstr::unary(UnaryOp::i32_eqz(), TInstr::i32_const(I32(0))),
    env,
    OptimizeOptions::new(),
  )
  assert_eq(eqz_const, TInstr::i32_const(I32(1)))
}

///|
test "optimize instructions i64 constant-right simplifications mirror i32 coverage" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i64_div_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i64_const(I64(8L)),
      ),
      TInstr::binary(
        BinaryOp::i64_rem_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i64_const(I64(8L)),
      ),
      TInstr::binary(
        BinaryOp::i64_ge_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i64_const(I64(0L)),
      ),
      TInstr::binary(
        BinaryOp::i64_lt_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i64_const(I64(-1L)),
      ),
      TInstr::binary(
        BinaryOp::i64_mul(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i64_const(I64(-1L)),
      ),
    ],
    locals=[ValType::i64()],
  )
  match body {
    TExpr([a0, a1, a2, a3, a4]) => {
      match a0 {
        TBinary(I64ShrUOp, _, TI64Const(I64(v))) => assert_eq(v, 3L)
        _ => fail("expected i64.div_u by pow2 => shr_u")
      }
      match a1 {
        TBinary(I64AndOp, _, TI64Const(I64(v))) => assert_eq(v, 7L)
        _ => fail("expected i64.rem_u by pow2 => and")
      }
      match a2 {
        TBlock(_, TExpr([TDrop(_), TI32Const(I32(v))])) => assert_eq(v, 1)
        _ => fail("expected i64.ge_u 0 => true with dropped lhs")
      }
      match a3 {
        TBinary(I64NeOp, _, TI64Const(I64(v))) => assert_eq(v, -1L)
        _ => fail("expected i64.lt_u -1 => ne -1")
      }
      match a4 {
        TBinary(I64SubOp, TI64Const(I64(0L)), _) => ()
        _ => fail("expected i64.mul -1 => 0 - x")
      }
    }
    _ => fail("expected five rewritten i64 instructions")
  }
}
