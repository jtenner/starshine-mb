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
priv enum PCLiteral {
  PCI32(Int)
  PCI64(Int64)
  PCF32(Float)
  PCF64(Double)
  PCRefNull(HeapType)
  PCRefFunc(FuncIdx)
} derive(Eq)

///|
priv struct PCSetKey {
  local_idx : LocalIdx
  root : TInstr
} derive(Eq, Hash)

///|
priv struct PCSetSite {
  key : PCSetKey
  value : TInstr
  start_get_id : Int
}

///|
fn pc_wrap_i32(x : Int) -> Int {
  (x.reinterpret_as_uint() & 0xffffffffU).reinterpret_as_int()
}

///|
fn pc_wrap_i64(x : Int64) -> Int64 {
  x.reinterpret_as_uint64().reinterpret_as_int64()
}

///|
fn pc_round_half_to_even_f32(x : Float) -> Float {
  let d = x.to_double()
  let r = pc_round_half_to_even_f64(d)
  Float::from_double(r)
}

///|
fn pc_round_half_to_even_f64(x : Double) -> Double {
  if compat_is_f64_non_finite(x) {
    return x
  }
  let t = x.trunc()
  let frac = (x - t).abs()
  if frac < 0.5 {
    t
  } else if frac > 0.5 {
    t + (if x >= 0.0 { 1.0 } else { -1.0 })
  } else {
    let ti = t.to_int64()
    if (ti & 1L) == 0L {
      t
    } else {
      t + (if x >= 0.0 { 1.0 } else { -1.0 })
    }
  }
}

///|
fn pc_trunc_f64_to_i64_s(x : Double) -> Int64? {
  compat_trunc_f64_to_i64_s(x)
}

///|
fn pc_trunc_f64_to_i64_u(x : Double) -> Int64? {
  compat_trunc_f64_to_i64_u(x)
}

///|
fn pc_literal_from_instr(instr : TInstr) -> PCLiteral? {
  match instr {
    TI32Const(I32(v)) => Some(PCI32(v))
    TI64Const(I64(v)) => Some(PCI64(v))
    TF32Const(F32(v)) => Some(PCF32(v))
    TF64Const(F64(v)) => Some(PCF64(v))
    TRefNull(ht) => Some(PCRefNull(ht))
    TRefFunc(fi) => Some(PCRefFunc(fi))
    _ => None
  }
}

///|
fn pc_instr_from_literal(value : PCLiteral) -> TInstr {
  match value {
    PCI32(v) => TInstr::i32_const(I32(v))
    PCI64(v) => TInstr::i64_const(I64(v))
    PCF32(v) => TInstr::f32_const(F32(v))
    PCF64(v) => TInstr::f64_const(F64(v))
    PCRefNull(ht) => TInstr::ref_null(ht)
    PCRefFunc(fi) => TInstr::ref_func(fi)
  }
}

///|
fn pc_imported_global_count(mod : Module) -> UInt {
  let mut count : UInt = 0U
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(_)) => count += 1U
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn pc_collect_immutable_globals(mod : Module) -> Map[GlobalIdx, PCLiteral] {
  let out : Map[GlobalIdx, PCLiteral] = Map::new()
  let imported = pc_imported_global_count(mod)
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for i = 0; i < globals.length(); i = i + 1 {
        match globals[i] {
          Global(GlobalType(_, is_mut), Expr(init_instrs)) =>
            if !is_mut {
              match init_instrs {
                [I32Const(I32(v))] =>
                  out[GlobalIdx::new(imported + i.reinterpret_as_uint())] = PCI32(
                    v,
                  )
                [I64Const(I64(v))] =>
                  out[GlobalIdx::new(imported + i.reinterpret_as_uint())] = PCI64(
                    v,
                  )
                [F32Const(F32(v))] =>
                  out[GlobalIdx::new(imported + i.reinterpret_as_uint())] = PCF32(
                    v,
                  )
                [F64Const(F64(v))] =>
                  out[GlobalIdx::new(imported + i.reinterpret_as_uint())] = PCF64(
                    v,
                  )
                [RefNull(ht)] =>
                  out[GlobalIdx::new(imported + i.reinterpret_as_uint())] = PCRefNull(
                    ht,
                  )
                [RefFunc(fi)] =>
                  out[GlobalIdx::new(imported + i.reinterpret_as_uint())] = PCRefFunc(
                    fi,
                  )
                _ => ()
              }
            }
        }
      }
    None => ()
  }
  out
}

///|
fn pc_eval_unary(op : UnaryOp, value : PCLiteral) -> PCLiteral? {
  match (op, value) {
    (I32EqzOp, PCI32(x)) => Some(PCI32(if x == 0 { 1 } else { 0 }))
    (I32ClzOp, PCI32(x)) => Some(PCI32(x.clz()))
    (I32CtzOp, PCI32(x)) => Some(PCI32(x.ctz()))
    (I32PopcntOp, PCI32(x)) => Some(PCI32(x.popcnt()))
    (I32WrapI64Op, PCI64(x)) => Some(PCI32(x.to_int()))
    (I32Extend8SOp, PCI32(x)) => Some(PCI32(x << 24 >> 24))
    (I32Extend16SOp, PCI32(x)) => Some(PCI32(x << 16 >> 16))
    (I64EqzOp, PCI64(x)) => Some(PCI32(if x == 0L { 1 } else { 0 }))
    (I64ClzOp, PCI64(x)) => Some(PCI64(x.clz().to_int64()))
    (I64CtzOp, PCI64(x)) => Some(PCI64(x.ctz().to_int64()))
    (I64PopcntOp, PCI64(x)) => Some(PCI64(x.popcnt().to_int64()))
    (I64ExtendI32SOp, PCI32(x)) => Some(PCI64(x.to_int64()))
    (I64ExtendI32UOp, PCI32(x)) =>
      Some(PCI64(x.reinterpret_as_uint().to_uint64().reinterpret_as_int64()))
    (I64TruncF32SOp, PCF32(x)) =>
      match pc_trunc_f64_to_i64_s(x.to_double()) {
        Some(v) => Some(PCI64(v))
        None => None
      }
    (I64TruncF32UOp, PCF32(x)) =>
      match pc_trunc_f64_to_i64_u(x.to_double()) {
        Some(v) => Some(PCI64(v))
        None => None
      }
    (I64TruncF64SOp, PCF64(x)) =>
      match pc_trunc_f64_to_i64_s(x) {
        Some(v) => Some(PCI64(v))
        None => None
      }
    (I64TruncF64UOp, PCF64(x)) =>
      match pc_trunc_f64_to_i64_u(x) {
        Some(v) => Some(PCI64(v))
        None => None
      }
    (I64Extend8SOp, PCI64(x)) => Some(PCI64(x << 56 >> 56))
    (I64Extend16SOp, PCI64(x)) => Some(PCI64(x << 48 >> 48))
    (I64Extend32SOp, PCI64(x)) => Some(PCI64(x << 32 >> 32))
    (F32AbsOp, PCF32(x)) => Some(PCF32(x.abs()))
    (F32NegOp, PCF32(x)) => Some(PCF32(-x))
    (F32CeilOp, PCF32(x)) =>
      Some(PCF32(Float::from_double(x.to_double().ceil())))
    (F32FloorOp, PCF32(x)) =>
      Some(PCF32(Float::from_double(x.to_double().floor())))
    (F32TruncOp, PCF32(x)) =>
      Some(PCF32(Float::from_double(x.to_double().trunc())))
    (F32NearestOp, PCF32(x)) => Some(PCF32(pc_round_half_to_even_f32(x)))
    (F32SqrtOp, PCF32(x)) => Some(PCF32(x.sqrt()))
    (F64AbsOp, PCF64(x)) => Some(PCF64(x.abs()))
    (F64NegOp, PCF64(x)) => Some(PCF64(-x))
    (F64CeilOp, PCF64(x)) => Some(PCF64(x.ceil()))
    (F64FloorOp, PCF64(x)) => Some(PCF64(x.floor()))
    (F64TruncOp, PCF64(x)) => Some(PCF64(x.trunc()))
    (F64NearestOp, PCF64(x)) => Some(PCF64(pc_round_half_to_even_f64(x)))
    (F64SqrtOp, PCF64(x)) => Some(PCF64(x.sqrt()))
    (F32ReinterpretI32Op, PCI32(x)) =>
      Some(PCF32(Float::reinterpret_from_int(x)))
    (I32ReinterpretF32Op, PCF32(x)) => Some(PCI32(x.reinterpret_as_int()))
    (F64ReinterpretI64Op, PCI64(x)) => Some(PCF64(x.reinterpret_as_double()))
    (I64ReinterpretF64Op, PCF64(x)) => Some(PCI64(x.reinterpret_as_int64()))
    (F32ConvertI32SOp, PCI32(x)) =>
      Some(PCF32(Float::from_double(x.to_double())))
    (F32ConvertI32UOp, PCI32(x)) =>
      Some(PCF32(Float::from_double(x.reinterpret_as_uint().to_double())))
    (F32ConvertI64SOp, PCI64(x)) =>
      Some(PCF32(Float::from_double(x.to_double())))
    (F32ConvertI64UOp, PCI64(x)) =>
      Some(PCF32(Float::from_double(x.reinterpret_as_uint64().to_double())))
    (F32DemoteF64Op, PCF64(x)) => Some(PCF32(Float::from_double(x)))
    (F64ConvertI32SOp, PCI32(x)) => Some(PCF64(x.to_double()))
    (F64ConvertI32UOp, PCI32(x)) =>
      Some(PCF64(x.reinterpret_as_uint().to_double()))
    (F64ConvertI64SOp, PCI64(x)) => Some(PCF64(x.to_double()))
    (F64ConvertI64UOp, PCI64(x)) =>
      Some(PCF64(x.reinterpret_as_uint64().to_double()))
    (F64PromoteF32Op, PCF32(x)) => Some(PCF64(x.to_double()))
    _ => None
  }
}

///|
fn pc_eval_binary(
  op : BinaryOp,
  left : PCLiteral,
  right : PCLiteral,
) -> PCLiteral? {
  match (op, left, right) {
    (I32AddOp, PCI32(x), PCI32(y)) => Some(PCI32(pc_wrap_i32(x + y)))
    (I32SubOp, PCI32(x), PCI32(y)) => Some(PCI32(pc_wrap_i32(x - y)))
    (I32MulOp, PCI32(x), PCI32(y)) => Some(PCI32(pc_wrap_i32(x * y)))
    (I32DivSOp, PCI32(x), PCI32(y)) =>
      if y == 0 || (x == -2147483648 && y == -1) {
        None
      } else {
        Some(PCI32(pc_wrap_i32(x / y)))
      }
    (I32DivUOp, PCI32(x), PCI32(y)) =>
      if y == 0 {
        None
      } else {
        let xu = x.reinterpret_as_uint()
        let yu = y.reinterpret_as_uint()
        Some(PCI32((xu / yu).reinterpret_as_int()))
      }
    (I32RemSOp, PCI32(x), PCI32(y)) =>
      if y == 0 {
        None
      } else {
        Some(PCI32(pc_wrap_i32(x % y)))
      }
    (I32RemUOp, PCI32(x), PCI32(y)) =>
      if y == 0 {
        None
      } else {
        let xu = x.reinterpret_as_uint()
        let yu = y.reinterpret_as_uint()
        Some(PCI32((xu % yu).reinterpret_as_int()))
      }
    (I32AndOp, PCI32(x), PCI32(y)) => Some(PCI32(pc_wrap_i32(x & y)))
    (I32OrOp, PCI32(x), PCI32(y)) => Some(PCI32(pc_wrap_i32(x | y)))
    (I32XorOp, PCI32(x), PCI32(y)) => Some(PCI32(pc_wrap_i32(x ^ y)))
    (I32ShlOp, PCI32(x), PCI32(y)) => Some(PCI32(pc_wrap_i32(x << (y & 31))))
    (I32ShrSOp, PCI32(x), PCI32(y)) => Some(PCI32(pc_wrap_i32(x >> (y & 31))))
    (I32ShrUOp, PCI32(x), PCI32(y)) =>
      Some(PCI32((x.reinterpret_as_uint() >> (y & 31)).reinterpret_as_int()))
    (I32RotlOp, PCI32(x), PCI32(y)) => {
      let k = y & 31
      if k == 0 {
        Some(PCI32(x))
      } else {
        let xu = x.reinterpret_as_uint()
        Some(PCI32(((xu << k) | (xu >> (32 - k))).reinterpret_as_int()))
      }
    }
    (I32RotrOp, PCI32(x), PCI32(y)) => {
      let k = y & 31
      if k == 0 {
        Some(PCI32(x))
      } else {
        let xu = x.reinterpret_as_uint()
        Some(PCI32(((xu >> k) | (xu << (32 - k))).reinterpret_as_int()))
      }
    }
    (I32EqOp, PCI32(x), PCI32(y)) => Some(PCI32(if x == y { 1 } else { 0 }))
    (I32NeOp, PCI32(x), PCI32(y)) => Some(PCI32(if x != y { 1 } else { 0 }))
    (I32LtSOp, PCI32(x), PCI32(y)) => Some(PCI32(if x < y { 1 } else { 0 }))
    (I32LtUOp, PCI32(x), PCI32(y)) =>
      Some(
        PCI32(
          if x.reinterpret_as_uint() < y.reinterpret_as_uint() {
            1
          } else {
            0
          },
        ),
      )
    (I32GtSOp, PCI32(x), PCI32(y)) => Some(PCI32(if x > y { 1 } else { 0 }))
    (I32GtUOp, PCI32(x), PCI32(y)) =>
      Some(
        PCI32(
          if x.reinterpret_as_uint() > y.reinterpret_as_uint() {
            1
          } else {
            0
          },
        ),
      )
    (I32LeSOp, PCI32(x), PCI32(y)) => Some(PCI32(if x <= y { 1 } else { 0 }))
    (I32LeUOp, PCI32(x), PCI32(y)) =>
      Some(
        PCI32(
          if x.reinterpret_as_uint() <= y.reinterpret_as_uint() {
            1
          } else {
            0
          },
        ),
      )
    (I32GeSOp, PCI32(x), PCI32(y)) => Some(PCI32(if x >= y { 1 } else { 0 }))
    (I32GeUOp, PCI32(x), PCI32(y)) =>
      Some(
        PCI32(
          if x.reinterpret_as_uint() >= y.reinterpret_as_uint() {
            1
          } else {
            0
          },
        ),
      )
    (I64AddOp, PCI64(x), PCI64(y)) => Some(PCI64(pc_wrap_i64(x + y)))
    (I64SubOp, PCI64(x), PCI64(y)) => Some(PCI64(pc_wrap_i64(x - y)))
    (I64MulOp, PCI64(x), PCI64(y)) => Some(PCI64(pc_wrap_i64(x * y)))
    (I64DivSOp, PCI64(x), PCI64(y)) =>
      if y == 0L || (x == -9223372036854775808L && y == -1L) {
        None
      } else {
        Some(PCI64(pc_wrap_i64(x / y)))
      }
    (I64DivUOp, PCI64(x), PCI64(y)) =>
      if y == 0L {
        None
      } else {
        let xu = x.reinterpret_as_uint64()
        let yu = y.reinterpret_as_uint64()
        Some(PCI64((xu / yu).reinterpret_as_int64()))
      }
    (I64RemSOp, PCI64(x), PCI64(y)) =>
      if y == 0L {
        None
      } else {
        Some(PCI64(pc_wrap_i64(x % y)))
      }
    (I64RemUOp, PCI64(x), PCI64(y)) =>
      if y == 0L {
        None
      } else {
        let xu = x.reinterpret_as_uint64()
        let yu = y.reinterpret_as_uint64()
        Some(PCI64((xu % yu).reinterpret_as_int64()))
      }
    (I64AndOp, PCI64(x), PCI64(y)) => Some(PCI64(pc_wrap_i64(x & y)))
    (I64OrOp, PCI64(x), PCI64(y)) => Some(PCI64(pc_wrap_i64(x | y)))
    (I64XorOp, PCI64(x), PCI64(y)) => Some(PCI64(pc_wrap_i64(x ^ y)))
    (I64ShlOp, PCI64(x), PCI64(y)) =>
      Some(PCI64(pc_wrap_i64(x << (y & 63L).to_int())))
    (I64ShrSOp, PCI64(x), PCI64(y)) =>
      Some(PCI64(pc_wrap_i64(x >> (y & 63L).to_int())))
    (I64ShrUOp, PCI64(x), PCI64(y)) =>
      Some(
        PCI64(
          (x.reinterpret_as_uint64() >> (y & 63L).to_int()).reinterpret_as_int64(),
        ),
      )
    (I64RotlOp, PCI64(x), PCI64(y)) => {
      let k = (y & 63L).to_int()
      if k == 0 {
        Some(PCI64(x))
      } else {
        let xu = x.reinterpret_as_uint64()
        Some(PCI64(((xu << k) | (xu >> (64 - k))).reinterpret_as_int64()))
      }
    }
    (I64RotrOp, PCI64(x), PCI64(y)) => {
      let k = (y & 63L).to_int()
      if k == 0 {
        Some(PCI64(x))
      } else {
        let xu = x.reinterpret_as_uint64()
        Some(PCI64(((xu >> k) | (xu << (64 - k))).reinterpret_as_int64()))
      }
    }
    (I64EqOp, PCI64(x), PCI64(y)) => Some(PCI32(if x == y { 1 } else { 0 }))
    (I64NeOp, PCI64(x), PCI64(y)) => Some(PCI32(if x != y { 1 } else { 0 }))
    (I64LtSOp, PCI64(x), PCI64(y)) => Some(PCI32(if x < y { 1 } else { 0 }))
    (I64LtUOp, PCI64(x), PCI64(y)) =>
      Some(
        PCI32(
          if x.reinterpret_as_uint64() < y.reinterpret_as_uint64() {
            1
          } else {
            0
          },
        ),
      )
    (I64GtSOp, PCI64(x), PCI64(y)) => Some(PCI32(if x > y { 1 } else { 0 }))
    (I64GtUOp, PCI64(x), PCI64(y)) =>
      Some(
        PCI32(
          if x.reinterpret_as_uint64() > y.reinterpret_as_uint64() {
            1
          } else {
            0
          },
        ),
      )
    (I64LeSOp, PCI64(x), PCI64(y)) => Some(PCI32(if x <= y { 1 } else { 0 }))
    (I64LeUOp, PCI64(x), PCI64(y)) =>
      Some(
        PCI32(
          if x.reinterpret_as_uint64() <= y.reinterpret_as_uint64() {
            1
          } else {
            0
          },
        ),
      )
    (I64GeSOp, PCI64(x), PCI64(y)) => Some(PCI32(if x >= y { 1 } else { 0 }))
    (I64GeUOp, PCI64(x), PCI64(y)) =>
      Some(
        PCI32(
          if x.reinterpret_as_uint64() >= y.reinterpret_as_uint64() {
            1
          } else {
            0
          },
        ),
      )
    (F32AddOp, PCF32(x), PCF32(y)) => Some(PCF32(x + y))
    (F32SubOp, PCF32(x), PCF32(y)) => Some(PCF32(x - y))
    (F32MulOp, PCF32(x), PCF32(y)) => Some(PCF32(x * y))
    (F32DivOp, PCF32(x), PCF32(y)) => Some(PCF32(x / y))
    (F32MinOp, PCF32(x), PCF32(y)) =>
      Some(
        PCF32(
          if compat_is_f32_nan(x) || compat_is_f32_nan(y) {
            @float.not_a_number
          } else if x < y {
            x
          } else {
            y
          },
        ),
      )
    (F32MaxOp, PCF32(x), PCF32(y)) =>
      Some(
        PCF32(
          if compat_is_f32_nan(x) || compat_is_f32_nan(y) {
            @float.not_a_number
          } else if x > y {
            x
          } else {
            y
          },
        ),
      )
    (F32CopysignOp, PCF32(x), PCF32(y)) => {
      let x_abs = x.abs()
      Some(PCF32(if y.reinterpret_as_int() < 0 { -x_abs } else { x_abs }))
    }
    (F32EqOp, PCF32(x), PCF32(y)) => Some(PCI32(if x == y { 1 } else { 0 }))
    (F32NeOp, PCF32(x), PCF32(y)) => Some(PCI32(if x != y { 1 } else { 0 }))
    (F32LtOp, PCF32(x), PCF32(y)) => Some(PCI32(if x < y { 1 } else { 0 }))
    (F32GtOp, PCF32(x), PCF32(y)) => Some(PCI32(if x > y { 1 } else { 0 }))
    (F32LeOp, PCF32(x), PCF32(y)) => Some(PCI32(if x <= y { 1 } else { 0 }))
    (F32GeOp, PCF32(x), PCF32(y)) => Some(PCI32(if x >= y { 1 } else { 0 }))
    (F64AddOp, PCF64(x), PCF64(y)) => Some(PCF64(x + y))
    (F64SubOp, PCF64(x), PCF64(y)) => Some(PCF64(x - y))
    (F64MulOp, PCF64(x), PCF64(y)) => Some(PCF64(x * y))
    (F64DivOp, PCF64(x), PCF64(y)) => Some(PCF64(x / y))
    (F64MinOp, PCF64(x), PCF64(y)) =>
      Some(
        PCF64(
          if compat_is_f64_nan(x) || compat_is_f64_nan(y) {
            @double.not_a_number
          } else if x < y {
            x
          } else {
            y
          },
        ),
      )
    (F64MaxOp, PCF64(x), PCF64(y)) =>
      Some(
        PCF64(
          if compat_is_f64_nan(x) || compat_is_f64_nan(y) {
            @double.not_a_number
          } else if x > y {
            x
          } else {
            y
          },
        ),
      )
    (F64CopysignOp, PCF64(x), PCF64(y)) => {
      let x_abs = x.abs()
      Some(PCF64(if y.reinterpret_as_int64() < 0L { -x_abs } else { x_abs }))
    }
    (F64EqOp, PCF64(x), PCF64(y)) => Some(PCI32(if x == y { 1 } else { 0 }))
    (F64NeOp, PCF64(x), PCF64(y)) => Some(PCI32(if x != y { 1 } else { 0 }))
    (F64LtOp, PCF64(x), PCF64(y)) => Some(PCI32(if x < y { 1 } else { 0 }))
    (F64GtOp, PCF64(x), PCF64(y)) => Some(PCI32(if x > y { 1 } else { 0 }))
    (F64LeOp, PCF64(x), PCF64(y)) => Some(PCI32(if x <= y { 1 } else { 0 }))
    (F64GeOp, PCF64(x), PCF64(y)) => Some(PCI32(if x >= y { 1 } else { 0 }))
    _ => None
  }
}

///|
fn pc_eval_texpr_const(
  expr : TExpr,
  imm_globals : Map[GlobalIdx, PCLiteral],
) -> PCLiteral? {
  let TExpr(instrs) = expr
  if instrs.is_empty() {
    return None
  }
  let mut last : PCLiteral? = None
  for instr in instrs {
    match pc_eval_const_expr(instr, imm_globals) {
      Some(v) => last = Some(v)
      None => return None
    }
  }
  last
}

///|
fn pc_eval_const_expr(
  instr : TInstr,
  imm_globals : Map[GlobalIdx, PCLiteral],
) -> PCLiteral? {
  match pc_literal_from_instr(instr) {
    Some(lit) => return Some(lit)
    None => ()
  }
  match instr {
    TGlobalGet(idx) => imm_globals.get(idx)
    TUnary(op, child) =>
      match pc_eval_const_expr(child, imm_globals) {
        Some(v) => pc_eval_unary(op, v)
        None => None
      }
    TBinary(op, left, right) =>
      match
        (
          pc_eval_const_expr(left, imm_globals),
          pc_eval_const_expr(right, imm_globals),
        ) {
        (Some(a), Some(b)) => pc_eval_binary(op, a, b)
        _ => None
      }
    TRefEq(left, right) =>
      match
        (
          pc_eval_const_expr(left, imm_globals),
          pc_eval_const_expr(right, imm_globals),
        ) {
        (Some(PCRefNull(_)), Some(PCRefNull(_))) => Some(PCI32(1))
        (Some(PCRefFunc(a)), Some(PCRefFunc(b))) =>
          Some(PCI32(if a == b { 1 } else { 0 }))
        (Some(PCRefNull(_)), Some(PCRefFunc(_)))
        | (Some(PCRefFunc(_)), Some(PCRefNull(_))) => Some(PCI32(0))
        _ => None
      }
    TRefIsNull(value) =>
      match pc_eval_const_expr(value, imm_globals) {
        Some(PCRefNull(_)) => Some(PCI32(1))
        Some(PCRefFunc(_)) => Some(PCI32(0))
        _ => None
      }
    TSelect(_, cond, if_true, if_false) =>
      match
        (
          pc_eval_const_expr(cond, imm_globals),
          pc_eval_const_expr(if_true, imm_globals),
          pc_eval_const_expr(if_false, imm_globals),
        ) {
        (Some(PCI32(c)), Some(t), Some(f)) =>
          if c == 0 {
            Some(f)
          } else {
            Some(t)
          }
        _ => None
      }
    TBlock(_, body) => pc_eval_texpr_const(body, imm_globals)
    TIf(_, cond, then_body, else_body) =>
      match pc_eval_const_expr(cond, imm_globals) {
        Some(PCI32(v)) =>
          if v == 0 {
            match else_body {
              Some(body) => pc_eval_texpr_const(body, imm_globals)
              None => None
            }
          } else {
            pc_eval_texpr_const(then_body, imm_globals)
          }
        _ => None
      }
    _ => None
  }
}

///|
fn pc_literal_maps_equal(
  a : Map[Int, PCLiteral],
  b : Map[Int, PCLiteral],
) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for k, v in a {
    match b.get(k) {
      Some(other) if other == v => ()
      _ => return false
    }
  }
  true
}

///|
fn pc_set_literal_maps_equal(
  a : Map[PCSetKey, PCLiteral],
  b : Map[PCSetKey, PCLiteral],
) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for k, v in a {
    match b.get(k) {
      Some(other) if other == v => ()
      _ => return false
    }
  }
  true
}

///|
fn pc_advance_get_ids(instr : TInstr, get_id : Ref[Int]) -> Unit {
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalGet(_) => get_id.update(fn(n) { n + 1 })
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_tinstruction((), instr))
}

///|
fn pc_get_constant_for_get_id(
  graph : LocalGraph,
  get_id : Int,
  set_values : Map[PCSetKey, PCLiteral],
  branchy_locals : Set[LocalIdx],
) -> PCLiteral? {
  let sets = graph.get_sets(get_id)
  if sets.is_empty() {
    return None
  }
  let mut value : PCLiteral? = None
  for set_ in sets {
    let current = match set_ {
      LocalSet::InitValue => return None
      LocalSet::Set(local_idx, root) =>
        if branchy_locals.contains(local_idx) {
          return None
        } else {
          match set_values.get({ local_idx, root }) {
            Some(v) => v
            None => return None
          }
        }
    }
    match value {
      Some(existing) if existing != current => return None
      None => value = Some(current)
      _ => ()
    }
  }
  value
}

///|
fn pc_mark_branchy_locals_instr(
  instr : TInstr,
  in_if : Bool,
  branchy_locals : Set[LocalIdx],
) -> Unit {
  match instr {
    TIf(_, cond, then_body, else_body) => {
      pc_mark_branchy_locals_instr(cond, in_if, branchy_locals)
      for item in then_body.0 {
        pc_mark_branchy_locals_instr(item, true, branchy_locals)
      }
      match else_body {
        Some(other) =>
          for item in other.0 {
            pc_mark_branchy_locals_instr(item, true, branchy_locals)
          }
        None => ()
      }
    }
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      for item in body.0 {
        pc_mark_branchy_locals_instr(item, in_if, branchy_locals)
      }
    TLocalSet(local_idx, value) => {
      if in_if {
        branchy_locals.add(local_idx)
      }
      pc_mark_branchy_locals_instr(value, in_if, branchy_locals)
    }
    _ =>
      for child in eval_children(instr) {
        pc_mark_branchy_locals_instr(child, in_if, branchy_locals)
      }
  }
}

///|
fn pc_collect_branchy_locals(body : TExpr) -> Set[LocalIdx] {
  let out : Set[LocalIdx] = Set::new()
  for instr in body.0 {
    pc_mark_branchy_locals_instr(instr, false, out)
  }
  out
}

///|
fn pc_eval_expr_for_prop(
  instr : TInstr,
  graph : LocalGraph,
  set_values : Map[PCSetKey, PCLiteral],
  imm_globals : Map[GlobalIdx, PCLiteral],
  branchy_locals : Set[LocalIdx],
  get_id : Ref[Int],
) -> PCLiteral? {
  match pc_literal_from_instr(instr) {
    Some(v) => return Some(v)
    None => ()
  }
  match instr {
    TLocalGet(_) => {
      let id = get_id.val
      get_id.update(fn(n) { n + 1 })
      pc_get_constant_for_get_id(graph, id, set_values, branchy_locals)
    }
    TGlobalGet(idx) => imm_globals.get(idx)
    TUnary(op, child) =>
      match
        pc_eval_expr_for_prop(
          child, graph, set_values, imm_globals, branchy_locals, get_id,
        ) {
        Some(v) => pc_eval_unary(op, v)
        None => None
      }
    TBinary(op, left, right) =>
      match
        (
          pc_eval_expr_for_prop(
            left, graph, set_values, imm_globals, branchy_locals, get_id,
          ),
          pc_eval_expr_for_prop(
            right, graph, set_values, imm_globals, branchy_locals, get_id,
          ),
        ) {
        (Some(a), Some(b)) => pc_eval_binary(op, a, b)
        _ => None
      }
    TRefEq(left, right) =>
      match
        (
          pc_eval_expr_for_prop(
            left, graph, set_values, imm_globals, branchy_locals, get_id,
          ),
          pc_eval_expr_for_prop(
            right, graph, set_values, imm_globals, branchy_locals, get_id,
          ),
        ) {
        (Some(PCRefNull(_)), Some(PCRefNull(_))) => Some(PCI32(1))
        (Some(PCRefFunc(a)), Some(PCRefFunc(b))) =>
          Some(PCI32(if a == b { 1 } else { 0 }))
        (Some(PCRefNull(_)), Some(PCRefFunc(_)))
        | (Some(PCRefFunc(_)), Some(PCRefNull(_))) => Some(PCI32(0))
        _ => None
      }
    TRefIsNull(value) =>
      match
        pc_eval_expr_for_prop(
          value, graph, set_values, imm_globals, branchy_locals, get_id,
        ) {
        Some(PCRefNull(_)) => Some(PCI32(1))
        Some(PCRefFunc(_)) => Some(PCI32(0))
        _ => None
      }
    TSelect(_, cond, if_true, if_false) =>
      match
        (
          pc_eval_expr_for_prop(
            cond, graph, set_values, imm_globals, branchy_locals, get_id,
          ),
          pc_eval_expr_for_prop(
            if_true, graph, set_values, imm_globals, branchy_locals, get_id,
          ),
          pc_eval_expr_for_prop(
            if_false, graph, set_values, imm_globals, branchy_locals, get_id,
          ),
        ) {
        (Some(PCI32(c)), Some(t), Some(f)) =>
          if c == 0 {
            Some(f)
          } else {
            Some(t)
          }
        _ => None
      }
    _ => {
      pc_advance_get_ids(instr, get_id)
      None
    }
  }
}

///|
fn pc_collect_set_sites(body : TExpr) -> (Array[PCSetSite], Int) {
  let sites : Array[PCSetSite] = []
  let get_id = Ref::new(0)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalSet(local_idx, value) =>
        sites.push({
          key: { local_idx, root: curr },
          value,
          start_get_id: get_id.val,
        })
      TLocalGet(_) => get_id.update(fn(n) { n + 1 })
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_texpr((), body))
  (sites, get_id.val)
}

///|
fn pc_analyze_get_values(
  body : TExpr,
  graph : LocalGraph,
  imm_globals : Map[GlobalIdx, PCLiteral],
) -> Map[Int, PCLiteral] {
  let (sites, total_gets) = pc_collect_set_sites(body)
  let branchy_locals = pc_collect_branchy_locals(body)
  let mut prev_set_values : Map[PCSetKey, PCLiteral] = Map::new()
  let mut prev_get_values : Map[Int, PCLiteral] = Map::new()
  let mut rounds = 0
  while rounds < 12 {
    rounds += 1
    let set_values : Map[PCSetKey, PCLiteral] = Map::new()
    for site in sites {
      let get_ref = Ref::new(site.start_get_id)
      match
        pc_eval_expr_for_prop(
          site.value,
          graph,
          prev_set_values,
          imm_globals,
          branchy_locals,
          get_ref,
        ) {
        Some(v) => set_values[site.key] = v
        None => ()
      }
    }
    let get_values : Map[Int, PCLiteral] = Map::new()
    for id in 0..<total_gets {
      match pc_get_constant_for_get_id(graph, id, set_values, branchy_locals) {
        Some(v) => get_values[id] = v
        None => ()
      }
    }
    if pc_set_literal_maps_equal(prev_set_values, set_values) &&
      pc_literal_maps_equal(prev_get_values, get_values) {
      return get_values
    }
    prev_set_values = set_values
    prev_get_values = get_values
  }
  prev_get_values
}

///|
fn pc_replace_gets_with_constants(
  body : TExpr,
  get_values : Map[Int, PCLiteral],
) -> TExpr {
  if get_values.is_empty() {
    return body
  }
  let next_get_id = Ref::new(0)
  let replacer = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    _,
    curr,
  ) {
    match curr {
      TLocalGet(_) => {
        let current_id = next_get_id.val
        next_get_id.update(fn(n) { n + 1 })
        match get_values.get(current_id) {
          Some(v) => change((), pc_instr_from_literal(v))
          None => unchanged()
        }
      }
      _ => self.walk_tinstruction_default((), curr)
    }
  })
  match replacer.walk_texpr((), body) {
    Ok(Some((_, out))) => out
    _ => body
  }
}

///|
fn pc_is_effectively_pure(instr : TInstr) -> Bool {
  let effects = lcs_collect_effects(instr)
  !effects.writes_memory &&
  !effects.reads_memory &&
  !effects.writes_globals &&
  !effects.reads_globals &&
  !effects.calls &&
  !effects.branches &&
  !effects.throws &&
  !effects.traps &&
  effects.locals_written.length() == 0
}

///|
fn pc_is_constant_like(
  instr : TInstr,
  imm_globals : Map[GlobalIdx, PCLiteral],
) -> Bool {
  pc_eval_const_expr(instr, imm_globals) is Some(_)
}

///|
fn pc_try_partial_precompute(
  instr : TInstr,
  imm_globals : Map[GlobalIdx, PCLiteral],
) -> TInstr? {
  match instr {
    TUnary(op, TSelect(types, cond, if_true, if_false)) =>
      if pc_is_constant_like(if_true, imm_globals) &&
        pc_is_constant_like(if_false, imm_globals) {
        let true_eval = pc_eval_const_expr(
          TInstr::unary(op, if_true),
          imm_globals,
        )
        let false_eval = pc_eval_const_expr(
          TInstr::unary(op, if_false),
          imm_globals,
        )
        match (true_eval, false_eval) {
          (Some(t), Some(f)) =>
            Some(
              TInstr::select(
                types,
                cond,
                pc_instr_from_literal(t),
                pc_instr_from_literal(f),
              ),
            )
          _ => None
        }
      } else {
        None
      }
    TBinary(op, TSelect(types, cond, if_true, if_false), right) =>
      if pc_is_constant_like(if_true, imm_globals) &&
        pc_is_constant_like(if_false, imm_globals) &&
        pc_is_constant_like(right, imm_globals) {
        let true_eval = pc_eval_const_expr(
          TInstr::binary(op, if_true, right),
          imm_globals,
        )
        let false_eval = pc_eval_const_expr(
          TInstr::binary(op, if_false, right),
          imm_globals,
        )
        match (true_eval, false_eval) {
          (Some(t), Some(f)) =>
            Some(
              TInstr::select(
                types,
                cond,
                pc_instr_from_literal(t),
                pc_instr_from_literal(f),
              ),
            )
          _ => None
        }
      } else {
        None
      }
    TBinary(op, left, TSelect(types, cond, if_true, if_false)) =>
      if pc_is_constant_like(if_true, imm_globals) &&
        pc_is_constant_like(if_false, imm_globals) &&
        pc_is_constant_like(left, imm_globals) {
        let true_eval = pc_eval_const_expr(
          TInstr::binary(op, left, if_true),
          imm_globals,
        )
        let false_eval = pc_eval_const_expr(
          TInstr::binary(op, left, if_false),
          imm_globals,
        )
        match (true_eval, false_eval) {
          (Some(t), Some(f)) =>
            Some(
              TInstr::select(
                types,
                cond,
                pc_instr_from_literal(t),
                pc_instr_from_literal(f),
              ),
            )
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn pc_fold_instr(
  instr : TInstr,
  imm_globals : Map[GlobalIdx, PCLiteral],
  options : OptimizeOptions,
) -> TInstr {
  match instr {
    TGlobalGet(idx) =>
      match imm_globals.get(idx) {
        Some(v) => return pc_instr_from_literal(v)
        None => ()
      }
    _ => ()
  }
  match instr {
    TSelect(_, cond, if_true, if_false) =>
      match pc_eval_const_expr(cond, imm_globals) {
        Some(PCI32(v)) =>
          if pc_is_effectively_pure(if_true) && pc_is_effectively_pure(if_false) {
            return if v == 0 { if_false } else { if_true }
          }
        _ => ()
      }
    _ => ()
  }
  if options.optimize_level >= 2 {
    match pc_try_partial_precompute(instr, imm_globals) {
      Some(next) => return next
      None => ()
    }
  }
  if pc_is_effectively_pure(instr) {
    match pc_eval_const_expr(instr, imm_globals) {
      Some(v) => return pc_instr_from_literal(v)
      None => ()
    }
  }
  instr
}

///|
fn pc_simplify_body(
  body : TExpr,
  imm_globals : Map[GlobalIdx, PCLiteral],
  options : OptimizeOptions,
) -> TExpr {
  let pass = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    let walked = match self.walk_tinstruction_default((), curr) {
      Ok(Some((_, out))) => out
      Ok(None) => curr
      Err(_) => curr
    }
    let next = pc_fold_instr(walked, imm_globals, options)
    if next == walked {
      unchanged()
    } else {
      change((), next)
    }
  })
  match pass.walk_texpr((), body) {
    Ok(Some((_, out))) => out
    _ => body
  }
}

///|
fn precompute_on_func(
  func : Func,
  mod : Module,
  options : OptimizeOptions,
  propagate : Bool,
) -> Result[Func, String] {
  let imm_globals = pc_collect_immutable_globals(mod)
  match func {
    Func(_) => Ok(func)
    TFunc(locals, initial_body) => {
      let mut body = initial_body
      if propagate {
        let graph = LocalGraph::new(body.0)
        let get_values = pc_analyze_get_values(body, graph, imm_globals)
        body = pc_replace_gets_with_constants(body, get_values)
      }
      let mut rounds = 0
      while rounds < 12 {
        rounds += 1
        let next = pc_simplify_body(body, imm_globals, options)
        if next == body {
          break
        }
        body = next
      }
      Ok(Func::t_func(locals, body))
    }
  }
}

///|
fn precompute_ir_pass(
  mod : Module,
  options : OptimizeOptions,
  propagate : Bool,
) -> ModuleTransformer[IRContext] {
  ModuleTransformer::new().on_func_evt(fn(_self, ctx : IRContext, func) {
    match precompute_on_func(func, mod, options, propagate) {
      Ok(next_func) =>
        match (func, next_func) {
          (TFunc(orig_locals, orig_body), TFunc(next_locals, next_body)) => {
            ctx.set_body(next_body)
            if orig_locals == next_locals && orig_body == next_body {
              unchanged()
            } else {
              change(ctx, Func::t_func(next_locals, next_body))
            }
          }
          _ => change(ctx, next_func)
        }
      Err(e) => Err(e)
    }
  })
}

///|
fn createPrecomputePass() -> ModulePass {
  ModulePass::Precompute
}

///|
fn createPrecomputePropagatePass() -> ModulePass {
  ModulePass::PrecomputePropagate
}

///|
fn pc_run_module(
  mod : Module,
  propagate? : Bool = false,
  options? : OptimizeOptions = OptimizeOptions::new(optimize_level=2),
) -> Result[Module, String] {
  let pass = if propagate {
    ModulePass::PrecomputePropagate
  } else {
    ModulePass::Precompute
  }
  optimize_module_with_options(mod, [pass], options)
}

///|
fn pc_single_func_module(
  body : Array[TInstr],
  locals? : Array[ValType] = [],
) -> Module {
  Module::new().with_code_sec(
    CodeSec::new([Func::t_func(locals, TExpr::new(body))]),
  )
}

///|
fn pc_expect_literal(actual : PCLiteral?, expected : PCLiteral) -> Unit raise {
  match actual {
    Some(v) => assert_true(v == expected)
    None => fail("expected literal result")
  }
}

///|
test "precompute constructors return expected module pass variants" {
  match createPrecomputePass() {
    ModulePass::Precompute => ()
    _ => fail("expected createPrecomputePass to return ModulePass::Precompute")
  }
  match createPrecomputePropagatePass() {
    ModulePass::PrecomputePropagate => ()
    _ =>
      fail(
        "expected createPrecomputePropagatePass to return ModulePass::PrecomputePropagate",
      )
  }
}

///|
test "precompute folds simple unary and binary constants" {
  let mod = pc_single_func_module([
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::i32_const(I32(1)),
      TInstr::i32_const(I32(2)),
    ),
    TInstr::unary(UnaryOp::i32_eqz(), TInstr::i32_const(I32(0))),
  ])
  let out = pc_run_module(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TI32Const(I32(a)), TI32Const(I32(b))]))])) => {
      assert_eq(a, 3)
      assert_eq(b, 1)
    }
    _ => fail("expected folded i32.const values")
  }
}

///|
test "precompute folds nested constant expression tree" {
  let mod = pc_single_func_module([
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::binary(
        BinaryOp::i32_mul(),
        TInstr::i32_const(I32(2)),
        TInstr::i32_const(I32(3)),
      ),
      TInstr::i32_const(I32(4)),
    ),
  ])
  let out = pc_run_module(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TI32Const(I32(v))]))])) => assert_eq(v, 10)
    _ => fail("expected nested constant expression to fold")
  }
}

///|
test "precompute does not fold trapping integer division by zero" {
  let mod = pc_single_func_module([
    TInstr::binary(
      BinaryOp::i32_div_s(),
      TInstr::i32_const(I32(10)),
      TInstr::i32_const(I32(0)),
    ),
  ])
  let out = pc_run_module(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TBinary(I32DivSOp, _, _)]))])) => ()
    _ => fail("expected i32.div_s by zero to remain")
  }
}

///|
test "precompute folds immutable global.get constants" {
  let mod = Module::new()
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), false),
          Expr::new([Instruction::i32_const(I32(7))]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([TInstr::drop(TInstr::global_get(GlobalIdx::new(0)))]),
        ),
      ]),
    )
  let out = pc_run_module(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TI32Const(I32(v)))]))])) =>
      assert_eq(v, 7)
    _ => fail("expected global.get to fold to constant")
  }
}

///|
test "precompute propagate replaces local.get with constant values" {
  let x = LocalIdx::new(0)
  let mod = pc_single_func_module(
    [
      TInstr::local_set(x, TInstr::i32_const(I32(42))),
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(x),
        TInstr::i32_const(I32(1)),
      ),
    ],
    locals=[ValType::i32()],
  )
  let out = pc_run_module(mod, propagate=true).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TLocalSet(_, _), TI32Const(I32(v))]))])) =>
      assert_eq(v, 43)
    _ => fail("expected propagated local.get to fold expression")
  }
}

///|
test "precompute propagate reaches fixpoint through chained locals" {
  let a = LocalIdx::new(0)
  let b = LocalIdx::new(1)
  let c = LocalIdx::new(2)
  let mod = pc_single_func_module(
    [
      TInstr::local_set(a, TInstr::i32_const(I32(10))),
      TInstr::local_set(
        b,
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(a),
          TInstr::i32_const(I32(5)),
        ),
      ),
      TInstr::local_set(
        c,
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(b),
          TInstr::i32_const(I32(7)),
        ),
      ),
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(c),
        TInstr::i32_const(I32(1)),
      ),
    ],
    locals=[ValType::i32(), ValType::i32(), ValType::i32()],
  )
  let out = pc_run_module(mod, propagate=true).unwrap()
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr(
              [
                TLocalSet(_, _),
                TLocalSet(_, _),
                TLocalSet(_, _),
                TI32Const(I32(v)),
              ]
            )
          ),
        ]
      )
    ) => assert_eq(v, 23)
    _ => fail("expected chained propagation to reach constant")
  }
}

///|
test "precompute propagate is conservative on conflicting if-merge sets" {
  let x = LocalIdx::new(0)
  let cond = LocalIdx::new(1)
  let mod = pc_single_func_module(
    [
      TInstr::if_(
        BlockType::void_(),
        TInstr::local_get(cond),
        TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(1)))]),
        Some(TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(2)))])),
      ),
      TInstr::local_get(x),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  let out = pc_run_module(mod, propagate=true).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TIf(_, _, _, _), TLocalGet(_)]))])) => ()
    _ => fail("expected local.get after conflicting merge to remain")
  }
}

///|
test "precompute partially precomputes unary over select arms" {
  let cond = LocalIdx::new(0)
  let mod = pc_single_func_module(
    [
      TInstr::unary(
        UnaryOp::i32_eqz(),
        TInstr::select(
          None,
          TInstr::local_get(cond),
          TInstr::i32_const(I32(10)),
          TInstr::i32_const(I32(0)),
        ),
      ),
    ],
    locals=[ValType::i32()],
  )
  let out = pc_run_module(mod).unwrap()
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr(
              [TSelect(_, TLocalGet(_), TI32Const(I32(a)), TI32Const(I32(b)))]
            )
          ),
        ]
      )
    ) => {
      assert_eq(a, 0)
      assert_eq(b, 1)
    }
    _ => fail("expected partial precompute to push unary into select arms")
  }
}

///|
test "precompute partially precomputes binary over select arms" {
  let cond = LocalIdx::new(0)
  let mod = pc_single_func_module(
    [
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::select(
          None,
          TInstr::local_get(cond),
          TInstr::i32_const(I32(2)),
          TInstr::i32_const(I32(5)),
        ),
        TInstr::i32_const(I32(8)),
      ),
    ],
    locals=[ValType::i32()],
  )
  let out = pc_run_module(mod).unwrap()
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr(
              [TSelect(_, TLocalGet(_), TI32Const(I32(a)), TI32Const(I32(b)))]
            )
          ),
        ]
      )
    ) => {
      assert_eq(a, 10)
      assert_eq(b, 13)
    }
    _ => fail("expected partial precompute to push binary into select arms")
  }
}

///|
test "precompute partial precompute keeps non-constant sibling case unchanged" {
  let cond = LocalIdx::new(0)
  let rhs = LocalIdx::new(1)
  let mod = pc_single_func_module(
    [
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::select(
          None,
          TInstr::local_get(cond),
          TInstr::i32_const(I32(2)),
          TInstr::i32_const(I32(5)),
        ),
        TInstr::local_get(rhs),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  let out = pc_run_module(mod).unwrap()
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr([TBinary(I32AddOp, TSelect(_, _, _, _), TLocalGet(_))])
          ),
        ]
      )
    ) => ()
    _ => fail("expected non-constant sibling to block partial precompute")
  }
}

///|
test "precompute pass is idempotent in propagate mode" {
  let x = LocalIdx::new(0)
  let mod = pc_single_func_module(
    [
      TInstr::local_set(x, TInstr::i32_const(I32(9))),
      TInstr::binary(
        BinaryOp::i32_mul(),
        TInstr::local_get(x),
        TInstr::i32_const(I32(2)),
      ),
    ],
    locals=[ValType::i32()],
  )
  let once = pc_run_module(mod, propagate=true).unwrap()
  let twice = pc_run_module(once, propagate=true).unwrap()
  assert_eq(once, twice)
}

///|
test "precompute helper rounding and literal conversion paths" {
  assert_eq(pc_wrap_i64(-1L), -1L)
  assert_eq(pc_round_half_to_even_f64(2.5), 2.0)
  assert_eq(pc_round_half_to_even_f64(3.5), 4.0)
  assert_eq(pc_round_half_to_even_f32(2.5), 2.0)

  pc_expect_literal(
    pc_literal_from_instr(TInstr::i64_const(I64(9L))),
    PCI64(9L),
  )
  assert_eq(pc_instr_from_literal(PCI64(9L)), TInstr::i64_const(I64(9L)))
}

///|
test "precompute immutable global collection includes all literal kinds and import offset" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("f"),
          ExternType::func(TypeIdx::new(0)),
        ),
        Import::new(
          Name::new("env"),
          Name::new("g"),
          ExternType::global(GlobalType::new(ValType::i32(), false)),
        ),
      ]),
    )
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i64(), false),
          Expr::new([Instruction::i64_const(I64(1))]),
        ),
        Global::new(
          GlobalType::new(ValType::f32(), false),
          Expr::new([Instruction::f32_const(F32(1.25))]),
        ),
        Global::new(
          GlobalType::new(ValType::f64(), false),
          Expr::new([Instruction::f64_const(F64(2.5))]),
        ),
        Global::new(
          GlobalType::new(
            ValType::ref_type(RefType::abs(AbsHeapType::func())),
            false,
          ),
          Expr::new([Instruction::ref_null(HeapType::abs(AbsHeapType::func()))]),
        ),
        Global::new(
          GlobalType::new(
            ValType::ref_type(RefType::abs(AbsHeapType::func())),
            false,
          ),
          Expr::new([Instruction::ref_func(FuncIdx::new(0))]),
        ),
        Global::new(
          GlobalType::new(ValType::i32(), true),
          Expr::new([Instruction::i32_const(I32(99))]),
        ),
      ]),
    )
  assert_eq(pc_imported_global_count(mod), 1U)
  let imm = pc_collect_immutable_globals(mod)
  assert_eq(imm.length(), 5)
  assert_true(imm.contains(GlobalIdx::new(1)))
  assert_true(imm.contains(GlobalIdx::new(2)))
  assert_true(imm.contains(GlobalIdx::new(3)))
  assert_true(imm.contains(GlobalIdx::new(4)))
  assert_true(imm.contains(GlobalIdx::new(5)))
}

///|
test "precompute unary and binary evaluators cover i64 float conversion and trap guards" {
  pc_expect_literal(pc_eval_unary(UnaryOp::i32_clz(), PCI32(1)), PCI32(31))
  pc_expect_literal(
    pc_eval_unary(UnaryOp::i64_extend_i32u(), PCI32(-1)),
    PCI64(4294967295L),
  )
  pc_expect_literal(
    pc_eval_unary(UnaryOp::f32_reinterpret_i32(), PCI32(0)),
    PCF32(Float::reinterpret_from_int(0)),
  )
  pc_expect_literal(
    pc_eval_unary(UnaryOp::f64_convert_i32u(), PCI32(-1)),
    PCF64(4294967295.0),
  )

  pc_expect_literal(
    pc_eval_binary(BinaryOp::i32_sub(), PCI32(9), PCI32(4)),
    PCI32(5),
  )
  match pc_eval_binary(BinaryOp::i32_div_s(), PCI32(9), PCI32(0)) {
    None => ()
    _ => fail("expected i32.div_s by zero to remain non-foldable")
  }
  pc_expect_literal(
    pc_eval_binary(BinaryOp::i32_div_s(), PCI32(9), PCI32(3)),
    PCI32(3),
  )
  match pc_eval_binary(BinaryOp::i32_div_u(), PCI32(9), PCI32(0)) {
    None => ()
    _ => fail("expected i32.div_u by zero to remain non-foldable")
  }
  match pc_eval_binary(BinaryOp::i32_rem_s(), PCI32(9), PCI32(0)) {
    None => ()
    _ => fail("expected i32.rem_s by zero to remain non-foldable")
  }
  match pc_eval_binary(BinaryOp::i32_rem_u(), PCI32(9), PCI32(0)) {
    None => ()
    _ => fail("expected i32.rem_u by zero to remain non-foldable")
  }
  pc_expect_literal(
    pc_eval_binary(BinaryOp::i32_and(), PCI32(6), PCI32(3)),
    PCI32(2),
  )
  pc_expect_literal(
    pc_eval_binary(BinaryOp::i32_shr_u(), PCI32(-2), PCI32(1)),
    PCI32(2147483647),
  )
  pc_expect_literal(
    pc_eval_binary(BinaryOp::i32_rotr(), PCI32(1), PCI32(0)),
    PCI32(1),
  )
  pc_expect_literal(
    pc_eval_binary(BinaryOp::i32_eq(), PCI32(7), PCI32(7)),
    PCI32(1),
  )
}

///|
test "precompute unary evaluator folds i64 trunc float conversions with trap guards" {
  pc_expect_literal(
    pc_eval_unary(
      UnaryOp::i64_trunc_f32s(),
      PCF32(Float::from_double(3000000000.0)),
    ),
    PCI64(3000000000L),
  )
  pc_expect_literal(
    pc_eval_unary(
      UnaryOp::i64_trunc_f32s(),
      PCF32(Float::from_double(-3000000000.0)),
    ),
    PCI64(-3000000000L),
  )
  pc_expect_literal(
    pc_eval_unary(UnaryOp::i64_trunc_f64s(), PCF64(-42.9)),
    PCI64(-42L),
  )
  pc_expect_literal(
    pc_eval_unary(UnaryOp::i64_trunc_f64u(), PCF64(3000000000.0)),
    PCI64(3000000000L),
  )
  match pc_eval_unary(UnaryOp::i64_trunc_f64s(), PCF64(9223372036854775808.0)) {
    None => ()
    _ =>
      fail("expected i64.trunc_f64_s out-of-range input to remain non-foldable")
  }
  match pc_eval_unary(UnaryOp::i64_trunc_f64u(), PCF64(-1.0)) {
    None => ()
    _ => fail("expected i64.trunc_f64_u negative input to remain non-foldable")
  }
  match
    pc_eval_unary(
      UnaryOp::i64_trunc_f32s(),
      PCF32(Float::from_double(@double.not_a_number)),
    ) {
    None => ()
    _ => fail("expected i64.trunc_f32_s NaN input to remain non-foldable")
  }
}

///|
test "precompute unary evaluator rejects signaling and signed NaN payloads for trunc ops" {
  let nan32_payloads : Array[Float] = [
    Float::reinterpret_from_uint(0x7F800001),
    Float::reinterpret_from_uint(0xFFC00000),
  ]
  let f32_ops : Array[UnaryOp] = [
    UnaryOp::i32_trunc_f32s(),
    UnaryOp::i32_trunc_f32u(),
    UnaryOp::i64_trunc_f32s(),
    UnaryOp::i64_trunc_f32u(),
  ]
  for payload in nan32_payloads {
    for op in f32_ops {
      match pc_eval_unary(op, PCF32(payload)) {
        None => ()
        _ => fail("expected f32 NaN payload trunc op to remain non-foldable")
      }
    }
  }

  let nan64_payloads : Array[Double] = [
    0x7FF0000000000001UL.reinterpret_as_double(),
    0xFFF8000000000000UL.reinterpret_as_double(),
  ]
  let f64_ops : Array[UnaryOp] = [
    UnaryOp::i32_trunc_f64s(),
    UnaryOp::i32_trunc_f64u(),
    UnaryOp::i64_trunc_f64s(),
    UnaryOp::i64_trunc_f64u(),
  ]
  for payload in nan64_payloads {
    for op in f64_ops {
      match pc_eval_unary(op, PCF64(payload)) {
        None => ()
        _ => fail("expected f64 NaN payload trunc op to remain non-foldable")
      }
    }
  }
}

///|
test "precompute binary min/max folds payload NaNs for f32 and f64" {
  let snan32 = Float::reinterpret_from_uint(0x7F800001)
  let neg_qnan32 = Float::reinterpret_from_uint(0xFFC00000)
  let finite32 = Float::reinterpret_from_uint(0x3F800000)
  let f32_cases : Array[(BinaryOp, Float, Float)] = [
    (BinaryOp::f32_min(), snan32, finite32),
    (BinaryOp::f32_max(), finite32, neg_qnan32),
  ]
  for case_ in f32_cases {
    let (op, lhs, rhs) = case_
    match pc_eval_binary(op, PCF32(lhs), PCF32(rhs)) {
      Some(PCF32(v)) =>
        assert_true(
          compat_is_f32_nan(v),
          msg="expected f32 min/max with payload NaN to fold to NaN",
        )
      _ => fail("expected f32 min/max to fold to f32 NaN literal")
    }
  }

  let snan64 = 0x7FF0000000000001UL.reinterpret_as_double()
  let neg_qnan64 = 0xFFF8000000000000UL.reinterpret_as_double()
  let finite64 = 1.0
  let f64_cases : Array[(BinaryOp, Double, Double)] = [
    (BinaryOp::f64_min(), snan64, finite64),
    (BinaryOp::f64_max(), finite64, neg_qnan64),
  ]
  for case_ in f64_cases {
    let (op, lhs, rhs) = case_
    match pc_eval_binary(op, PCF64(lhs), PCF64(rhs)) {
      Some(PCF64(v)) =>
        assert_true(
          compat_is_f64_nan(v),
          msg="expected f64 min/max with payload NaN to fold to NaN",
        )
      _ => fail("expected f64 min/max to fold to f64 NaN literal")
    }
  }
}
