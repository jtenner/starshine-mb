// ssa_optimize.mbt

// ============================================================
// Utility helpers
// ============================================================

///|
fn is_power_of_2_i32(x : Int) -> Bool {
  x > 0 && (x & (x - 1)) == 0
}

///|
fn log2_i32(x : Int) -> Int {
  x.ctz()
}

///|
fn is_power_of_2_i64(x : Int64) -> Bool {
  x > 0L && (x & (x - 1L)) == 0L
}

///|
fn log2_i64(x : Int64) -> Int64 {
  x.ctz().to_int64()
}

///|
fn round_half_to_even_f32(x : Float) -> Float {
  let d = x.to_double()
  let r = round_half_to_even_f64(d)
  Float::from_double(r)
}

///|
fn round_half_to_even_f64(x : Double) -> Double {
  if x.is_nan() || x.is_inf() {
    return x
  }
  let t = x.trunc()
  let frac = (x - t).abs()
  if frac < 0.5 {
    t
  } else if frac > 0.5 {
    t + (if x >= 0.0 { 1.0 } else { -1.0 })
  } else {
    // Exactly 0.5 — round to even
    let ti = t.to_int64()
    if (ti & 1L) == 0L {
      t
    } else {
      t + (if x >= 0.0 { 1.0 } else { -1.0 })
    }
  }
}

///|
/// Constant literal extracted from SSA ops
enum SSALiteral {
  LitI32(Int)
  LitI64(Int64)
  LitF32(Float)
  LitF64(Double)
} derive(Eq, Show)

///|
fn literal_to_op(lit : SSALiteral) -> SSAOp {
  match lit {
    LitI32(x) => SSAOp::I32Const(x)
    LitI64(x) => SSAOp::I64Const(x)
    LitF32(x) => SSAOp::F32Const(x)
    LitF64(x) => SSAOp::F64Const(x)
  }
}

///|
fn op_to_literal(op : SSAOp) -> SSALiteral? {
  match op {
    I32Const(I32(x)) => Some(LitI32(x))
    I64Const(I64(x)) => Some(LitI64(x))
    F32Const(F32(x)) => Some(LitF32(x))
    F64Const(F64(x)) => Some(LitF64(x))
    _ => None
  }
}

///|
fn is_const_op(op : SSAOp) -> Bool {
  op_to_literal(op) is Some(_)
}

///|
/// Mutable optimization context for a single pass over SSACFG
priv struct SSAOptCtx {
  /// SSAValue -> defining SSAOp
  def_map : Map[SSAValue, SSAOp]
  /// Replacement map: uses of key should be replaced by value
  replacements : Map[SSAValue, SSAValue]
  /// Track which values are used (for DCE)
  used : @set.Set[SSAValue]
  /// Fresh value counter
  mut next_value : Int
  /// Whether anything changed this pass
  mut changed : Bool
}

///|
fn SSAOptCtx::new(ssa : SSACFG) -> SSAOptCtx {
  let def_map : Map[SSAValue, SSAOp] = {}
  for _, block in ssa.blocks {
    for instr in block.instrs {
      match instr {
        Assign(v, op) => def_map[v] = op
        Effect(_) => ()
      }
    }
  }
  {
    def_map,
    replacements: {},
    used: @set.Set::new(),
    next_value: ssa.next_value,
    changed: false,
  }
}

///|
/// Resolve a value through the replacement chain
fn SSAOptCtx::resolve(self : SSAOptCtx, v : SSAValue) -> SSAValue {
  let mut current = v
  for i = 0; i < 100; i = i + 1 {
    match self.replacements.get(current) {
      Some(next) if next != current => current = next
      _ => break
    }
  }
  current
}

///|
/// Get the defining op for a value, following replacements
fn SSAOptCtx::get_op(self : SSAOptCtx, v : SSAValue) -> SSAOp? {
  self.def_map.get(self.resolve(v))
}

///|
/// Get constant literal for a value
fn SSAOptCtx::get_const(self : SSAOptCtx, v : SSAValue) -> SSALiteral? {
  match self.get_op(v) {
    Some(op) => op_to_literal(op)
    None => None
  }
}

///|
/// Record that `from` should be replaced by `to`
fn SSAOptCtx::replace(self : SSAOptCtx, from : SSAValue, to : SSAValue) -> Unit {
  self.replacements[from] = to
  self.changed = true
}

///|
/// Allocate a fresh SSAValue
fn SSAOptCtx::fresh_value(self : SSAOptCtx) -> SSAValue {
  let v = SSAValue(self.next_value)
  self.next_value = self.next_value + 1
  v
}

///|
/// Create a constant instruction and register it
fn SSAOptCtx::make_const(self : SSAOptCtx, lit : SSALiteral) -> SSAValue {
  let v = self.fresh_value()
  let op = literal_to_op(lit)
  self.def_map[v] = op
  v
}

// ============================================================
// Constant folding for unary operations
// ============================================================

///|
fn eval_ssa_unary(op : UnaryOp, lit : SSALiteral) -> SSALiteral? {
  match (op, lit) {
    // i32 operations
    (I32EqzOp, LitI32(x)) => Some(LitI32(if x == 0 { 1 } else { 0 }))
    (I32ClzOp, LitI32(x)) => Some(LitI32(x.clz()))
    (I32CtzOp, LitI32(x)) => Some(LitI32(x.ctz()))
    (I32PopcntOp, LitI32(x)) => Some(LitI32(x.popcnt()))
    // i64 operations
    (I64EqzOp, LitI64(x)) => Some(LitI32(if x == 0L { 1 } else { 0 }))
    (I64ClzOp, LitI64(x)) => Some(LitI64(x.clz().to_int64()))
    (I64CtzOp, LitI64(x)) => Some(LitI64(x.ctz().to_int64()))
    (I64PopcntOp, LitI64(x)) => Some(LitI64(x.popcnt().to_int64()))
    // Conversions
    (I32Extend8SOp, LitI32(x)) => Some(LitI64(x.to_int64()))
    (I32Extend16SOp, LitI32(x)) =>
      Some(LitI64(x.reinterpret_as_uint().to_uint64().reinterpret_as_int64()))
    (I32WrapI64Op, LitI64(x)) => Some(LitI32(x.to_int()))
    // f32 operations
    (F32NegOp, LitF32(x)) => Some(LitF32(-x))
    (F32AbsOp, LitF32(x)) => Some(LitF32(x.abs()))
    (F32SqrtOp, LitF32(x)) => Some(LitF32(x.sqrt()))
    (F32CeilOp, LitF32(x)) =>
      Some(LitF32(Float::from_double(x.to_double().ceil())))
    (F32FloorOp, LitF32(x)) =>
      Some(LitF32(Float::from_double(x.to_double().floor())))
    (F32TruncOp, LitF32(x)) =>
      Some(LitF32(Float::from_double(x.to_double().trunc())))
    (F32NearestOp, LitF32(x)) => Some(LitF32(round_half_to_even_f32(x)))
    // f64 operations
    (F64NegOp, LitF64(x)) => Some(LitF64(-x))
    (F64AbsOp, LitF64(x)) => Some(LitF64(x.abs()))
    (F64SqrtOp, LitF64(x)) => Some(LitF64(x.sqrt()))
    (F64CeilOp, LitF64(x)) => Some(LitF64(x.ceil()))
    (F64FloorOp, LitF64(x)) => Some(LitF64(x.floor()))
    (F64TruncOp, LitF64(x)) => Some(LitF64(x.trunc()))
    (F64NearestOp, LitF64(x)) => Some(LitF64(round_half_to_even_f64(x)))
    // Float to int conversions
    (I32TruncF32SOp, LitF32(x)) => Some(LitI32(x.to_double().trunc().to_int()))
    (I32TruncF32UOp, LitF32(x)) =>
      Some(LitI32(x.to_double().trunc().to_uint().reinterpret_as_int()))
    (I32TruncF64SOp, LitF64(x)) => Some(LitI32(x.trunc().to_int()))
    (I32TruncF64UOp, LitF64(x)) =>
      Some(LitI32(x.trunc().to_uint().reinterpret_as_int()))
    (I64ExtendI32SOp, LitF32(x)) =>
      Some(LitI64(x.to_double().trunc().to_int64()))
    (I64ExtendI32UOp, LitF32(x)) =>
      Some(LitI64(x.to_double().trunc().to_uint64().reinterpret_as_int64()))
    // TODO: Check these truncation operations
    (I64TruncF32SOp, LitF32(x)) => Some(LitI64(x.trunc().to_int().to_int64()))
    (I64TruncF32UOp, LitF32(x)) => Some(LitI64(x.trunc().to_int().to_int64()))
    // Int to float conversions
    (F32ConvertI32SOp, LitI32(x)) =>
      Some(LitF32(Float::from_double(x.to_double())))
    (F32ConvertI32UOp, LitI32(x)) =>
      Some(LitF32(Float::from_double(x.reinterpret_as_uint().to_double())))
    (F32ConvertI64SOp, LitI64(x)) =>
      Some(LitF32(Float::from_double(x.to_double())))
    (F32ConvertI64UOp, LitI64(x)) =>
      Some(LitF32(Float::from_double(x.reinterpret_as_uint64().to_double())))
    (F64ConvertI32SOp, LitI32(x)) => Some(LitF64(x.to_double()))
    (F64ConvertI32UOp, LitI32(x)) =>
      Some(LitF64(x.reinterpret_as_uint().to_double()))
    (F64ConvertI64SOp, LitI64(x)) => Some(LitF64(x.to_double()))
    (F64ConvertI64UOp, LitI64(x)) =>
      Some(LitF64(x.reinterpret_as_uint64().to_double()))
    // Float promotions/demotions
    (F64PromoteF32Op, LitF32(x)) => Some(LitF64(x.to_double()))
    (F32DemoteF64Op, LitF64(x)) => Some(LitF32(Float::from_double(x)))
    // Reinterpret
    (F32ReinterpretI32Op, LitF32(x)) => Some(LitI32(x.reinterpret_as_int()))
    (F64ReinterpretI64Op, LitF64(x)) => Some(LitI64(x.reinterpret_as_int64()))
    (I32ReinterpretF32Op, LitI32(x)) =>
      Some(LitF32(Float::reinterpret_from_int(x)))
    (I64ReinterpretF64Op, LitI64(x)) => Some(LitF64(x.reinterpret_as_double()))
    _ => None
  }
}

// ============================================================
// Constant folding for binary operations
// ============================================================

///|
fn eval_ssa_binary(
  op : @lib.BinaryOp,
  a : SSALiteral,
  b : SSALiteral,
) -> SSALiteral? {
  match (op, a, b) {
    // i32 arithmetic
    (I32AddOp, LitI32(x), LitI32(y)) => Some(LitI32(x + y))
    (I32SubOp, LitI32(x), LitI32(y)) => Some(LitI32(x - y))
    (I32MulOp, LitI32(x), LitI32(y)) => Some(LitI32(x * y))
    (I32DivSOp, LitI32(x), LitI32(y)) if y != 0 => Some(LitI32(x / y))
    (I32DivUOp, LitI32(x), LitI32(y)) if y != 0 => {
      let xu = x.reinterpret_as_uint()
      let yu = y.reinterpret_as_uint()
      Some(LitI32((xu / yu).reinterpret_as_int()))
    }
    (I32RemSOp, LitI32(x), LitI32(y)) if y != 0 => Some(LitI32(x % y))
    (I32RemUOp, LitI32(x), LitI32(y)) if y != 0 => {
      let xu = x.reinterpret_as_uint()
      let yu = y.reinterpret_as_uint()
      Some(LitI32((xu % yu).reinterpret_as_int()))
    }
    // i32 bitwise
    (I32AndOp, LitI32(x), LitI32(y)) => Some(LitI32(x & y))
    (I32OrOp, LitI32(x), LitI32(y)) => Some(LitI32(x | y))
    (I32XorOp, LitI32(x), LitI32(y)) => Some(LitI32(x ^ y))
    (I32ShlOp, LitI32(x), LitI32(y)) => Some(LitI32(x << (y & 31)))
    (I32ShrSOp, LitI32(x), LitI32(y)) => Some(LitI32(x >> (y & 31)))
    (I32ShrUOp, LitI32(x), LitI32(y)) =>
      Some(LitI32((x.reinterpret_as_uint() >> (y & 31)).reinterpret_as_int()))
    (I32RotlOp, LitI32(x), LitI32(y)) => {
      let k = y & 31
      if k == 0 {
        return Some(LitI32(x))
      }
      let xu = x.reinterpret_as_uint()
      Some(LitI32(((xu << k) | (xu >> (32 - k))).reinterpret_as_int()))
    }
    (I32RotrOp, LitI32(x), LitI32(y)) => {
      let k = y & 31
      if k == 0 {
        return Some(LitI32(x))
      }
      let xu = x.reinterpret_as_uint()
      Some(LitI32(((xu >> k) | (xu << (32 - k))).reinterpret_as_int()))
    }
    // i32 comparisons
    (I32EqOp, LitI32(x), LitI32(y)) => Some(LitI32(if x == y { 1 } else { 0 }))
    (I32NeOp, LitI32(x), LitI32(y)) => Some(LitI32(if x != y { 1 } else { 0 }))
    (I32LtSOp, LitI32(x), LitI32(y)) => Some(LitI32(if x < y { 1 } else { 0 }))
    (I32LtUOp, LitI32(x), LitI32(y)) =>
      Some(
        LitI32(
          if x.reinterpret_as_uint() < y.reinterpret_as_uint() {
            1
          } else {
            0
          },
        ),
      )
    (I32LeSOp, LitI32(x), LitI32(y)) => Some(LitI32(if x <= y { 1 } else { 0 }))
    (I32LeUOp, LitI32(x), LitI32(y)) =>
      Some(
        LitI32(
          if x.reinterpret_as_uint() <= y.reinterpret_as_uint() {
            1
          } else {
            0
          },
        ),
      )
    (I32GtSOp, LitI32(x), LitI32(y)) => Some(LitI32(if x > y { 1 } else { 0 }))
    (I32GtUOp, LitI32(x), LitI32(y)) =>
      Some(
        LitI32(
          if x.reinterpret_as_uint() > y.reinterpret_as_uint() {
            1
          } else {
            0
          },
        ),
      )
    (I32GeSOp, LitI32(x), LitI32(y)) => Some(LitI32(if x >= y { 1 } else { 0 }))
    (I32GeUOp, LitI32(x), LitI32(y)) =>
      Some(
        LitI32(
          if x.reinterpret_as_uint() >= y.reinterpret_as_uint() {
            1
          } else {
            0
          },
        ),
      )
    // i64 arithmetic
    (I64AddOp, LitI64(x), LitI64(y)) => Some(LitI64(x + y))
    (I64SubOp, LitI64(x), LitI64(y)) => Some(LitI64(x - y))
    (I64MulOp, LitI64(x), LitI64(y)) => Some(LitI64(x * y))
    (I64DivSOp, LitI64(x), LitI64(y)) if y != 0L => Some(LitI64(x / y))
    (I64DivUOp, LitI64(x), LitI64(y)) if y != 0L => {
      let xu = x.reinterpret_as_uint64()
      let yu = y.reinterpret_as_uint64()
      Some(LitI64((xu / yu).reinterpret_as_int64()))
    }
    (I64RemSOp, LitI64(x), LitI64(y)) if y != 0L => Some(LitI64(x % y))
    (I64RemUOp, LitI64(x), LitI64(y)) if y != 0L => {
      let xu = x.reinterpret_as_uint64()
      let yu = y.reinterpret_as_uint64()
      Some(LitI64((xu % yu).reinterpret_as_int64()))
    }
    // i64 bitwise
    (I64AndOp, LitI64(x), LitI64(y)) => Some(LitI64(x & y))
    (I64OrOp, LitI64(x), LitI64(y)) => Some(LitI64(x | y))
    (I64XorOp, LitI64(x), LitI64(y)) => Some(LitI64(x ^ y))
    (I64ShlOp, LitI64(x), LitI64(y)) => Some(LitI64(x << y.land(63L).to_int()))
    (I64ShrSOp, LitI64(x), LitI64(y)) => Some(LitI64(x >> y.land(63L).to_int()))
    (I64ShrUOp, LitI64(x), LitI64(y)) =>
      Some(
        LitI64(
          (x.reinterpret_as_uint64() >> y.land(63L).to_int()).reinterpret_as_int64(),
        ),
      )
    (I64RotlOp, LitI64(x), LitI64(y)) => {
      let k = y.land(63L).to_int()
      if k == 0 {
        return Some(LitI64(x))
      }
      let xu = x.reinterpret_as_uint64()
      Some(LitI64(((xu << k) | (xu >> (64 - k))).reinterpret_as_int64()))
    }
    (I64RotrOp, LitI64(x), LitI64(y)) => {
      let k = y.land(63L).to_int()
      if k == 0 {
        return Some(LitI64(x))
      }
      let xu = x.reinterpret_as_uint64()
      Some(LitI64(((xu >> k) | (xu << (64 - k))).reinterpret_as_int64()))
    }
    // i64 comparisons
    (I64EqOp, LitI64(x), LitI64(y)) => Some(LitI32(if x == y { 1 } else { 0 }))
    (I64NeOp, LitI64(x), LitI64(y)) => Some(LitI32(if x != y { 1 } else { 0 }))
    (I64LtSOp, LitI64(x), LitI64(y)) => Some(LitI32(if x < y { 1 } else { 0 }))
    (I64LtUOp, LitI64(x), LitI64(y)) =>
      Some(
        LitI32(
          if x.reinterpret_as_uint64() < y.reinterpret_as_uint64() {
            1
          } else {
            0
          },
        ),
      )
    (I64LeSOp, LitI64(x), LitI64(y)) => Some(LitI32(if x <= y { 1 } else { 0 }))
    (I64LeUOp, LitI64(x), LitI64(y)) =>
      Some(
        LitI32(
          if x.reinterpret_as_uint64() <= y.reinterpret_as_uint64() {
            1
          } else {
            0
          },
        ),
      )
    (I64GtSOp, LitI64(x), LitI64(y)) => Some(LitI32(if x > y { 1 } else { 0 }))
    (I64GtUOp, LitI64(x), LitI64(y)) =>
      Some(
        LitI32(
          if x.reinterpret_as_uint64() > y.reinterpret_as_uint64() {
            1
          } else {
            0
          },
        ),
      )
    (I64GeSOp, LitI64(x), LitI64(y)) => Some(LitI32(if x >= y { 1 } else { 0 }))
    (I64GeUOp, LitI64(x), LitI64(y)) =>
      Some(
        LitI32(
          if x.reinterpret_as_uint64() >= y.reinterpret_as_uint64() {
            1
          } else {
            0
          },
        ),
      )
    // f32 arithmetic
    (F32AddOp, LitF32(x), LitF32(y)) => Some(LitF32(x + y))
    (F32SubOp, LitF32(x), LitF32(y)) => Some(LitF32(x - y))
    (F32MulOp, LitF32(x), LitF32(y)) => Some(LitF32(x * y))
    (F32DivOp, LitF32(x), LitF32(y)) => Some(LitF32(x / y))
    (F32MinOp, LitF32(x), LitF32(y)) =>
      Some(
        LitF32(
          if x.is_nan() || y.is_nan() {
            @float.not_a_number
          } else if x < y {
            x
          } else {
            y
          },
        ),
      )
    (F32MaxOp, LitF32(x), LitF32(y)) =>
      Some(
        LitF32(
          if x.is_nan() || y.is_nan() {
            @float.not_a_number
          } else if x > y {
            x
          } else {
            y
          },
        ),
      )
    (F32CopysignOp, LitF32(x), LitF32(y)) => {
      let x_abs = x.abs()
      let result = if y.reinterpret_as_int() < 0 { -x_abs } else { x_abs }
      Some(LitF32(result))
    }
    // f32 comparisons
    (F32EqOp, LitF32(x), LitF32(y)) => Some(LitI32(if x == y { 1 } else { 0 }))
    (F32NeOp, LitF32(x), LitF32(y)) => Some(LitI32(if x != y { 1 } else { 0 }))
    (F32LtOp, LitF32(x), LitF32(y)) => Some(LitI32(if x < y { 1 } else { 0 }))
    (F32LeOp, LitF32(x), LitF32(y)) => Some(LitI32(if x <= y { 1 } else { 0 }))
    (F32GtOp, LitF32(x), LitF32(y)) => Some(LitI32(if x > y { 1 } else { 0 }))
    (F32GeOp, LitF32(x), LitF32(y)) => Some(LitI32(if x >= y { 1 } else { 0 }))
    // f64 arithmetic
    (F64AddOp, LitF64(x), LitF64(y)) => Some(LitF64(x + y))
    (F64SubOp, LitF64(x), LitF64(y)) => Some(LitF64(x - y))
    (F64MulOp, LitF64(x), LitF64(y)) => Some(LitF64(x * y))
    (F64DivOp, LitF64(x), LitF64(y)) => Some(LitF64(x / y))
    (F64MinOp, LitF64(x), LitF64(y)) =>
      Some(
        LitF64(
          if x.is_nan() || y.is_nan() {
            @double.not_a_number
          } else if x < y {
            x
          } else {
            y
          },
        ),
      )
    (F64MaxOp, LitF64(x), LitF64(y)) =>
      Some(
        LitF64(
          if x.is_nan() || y.is_nan() {
            @double.not_a_number
          } else if x > y {
            x
          } else {
            y
          },
        ),
      )
    (F64CopysignOp, LitF64(x), LitF64(y)) => {
      let x_abs = x.abs()
      let result = if y.reinterpret_as_int64() < 0L { -x_abs } else { x_abs }
      Some(LitF64(result))
    }
    // f64 comparisons
    (F64EqOp, LitF64(x), LitF64(y)) => Some(LitI32(if x == y { 1 } else { 0 }))
    (F64NeOp, LitF64(x), LitF64(y)) => Some(LitI32(if x != y { 1 } else { 0 }))
    (F64LtOp, LitF64(x), LitF64(y)) => Some(LitI32(if x < y { 1 } else { 0 }))
    (F64LeOp, LitF64(x), LitF64(y)) => Some(LitI32(if x <= y { 1 } else { 0 }))
    (F64GtOp, LitF64(x), LitF64(y)) => Some(LitI32(if x > y { 1 } else { 0 }))
    (F64GeOp, LitF64(x), LitF64(y)) => Some(LitI32(if x >= y { 1 } else { 0 }))
    _ => None
  }
}

// ============================================================
// Classify binary ops for algebraic simplifications
// ============================================================

///|
fn is_associative_binop(op : @lib.BinaryOp) -> Bool {
  match op {
    I32AddOp
    | I32MulOp
    | I64AddOp
    | I64MulOp
    | I32AndOp
    | I32OrOp
    | I32XorOp
    | I64AndOp
    | I64OrOp
    | I64XorOp => true
    _ => false
  }
}
// ============================================================
// Strength reduction: mul/div/rem by power of 2
// ============================================================

///|
fn try_strength_reduce_ssa(
  ctx : SSAOptCtx,
  result : SSAValue,
  op : BinaryOp,
  left : SSAValue,
  right : SSAValue,
) -> Bool {
  match op {
    I32MulOp => {
      // x * (2^k) → x << k
      match ctx.get_const(right) {
        Some(LitI32(c)) if is_power_of_2_i32(c) => {
          let shift = log2_i32(c)
          let shift_v = ctx.make_const(LitI32(shift))
          ctx.def_map[result] = SSAOp::Binary(
            BinaryOp::i32_shl(),
            left, // ✅ use the non-const operand
            shift_v,
          )
          ctx.changed = true
          return true
        }
        _ => ()
      }

      // (2^k) * x → x << k
      match ctx.get_const(left) {
        Some(LitI32(c)) if is_power_of_2_i32(c) => {
          let shift = log2_i32(c)
          let shift_v = ctx.make_const(LitI32(shift))
          ctx.def_map[result] = SSAOp::Binary(
            BinaryOp::i32_shl(),
            right, // ✅ use the non-const operand
            shift_v,
          )
          ctx.changed = true
          return true
        }
        _ => ()
      }
      false
    }
    I64MulOp => {
      // x * (2^k) → x << k
      match ctx.get_const(right) {
        Some(LitI64(c)) if is_power_of_2_i64(c) => {
          let shift = log2_i64(c)
          let shift_v = ctx.make_const(LitI64(shift))
          ctx.def_map[result] = SSAOp::Binary(
            BinaryOp::i64_shl(),
            left, // ✅ shift the non-const operand
            shift_v,
          )
          ctx.changed = true
          return true
        }
        _ => ()
      }

      // (2^k) * x → x << k
      match ctx.get_const(left) {
        Some(LitI64(c)) if is_power_of_2_i64(c) => {
          let shift = log2_i64(c)
          let shift_v = ctx.make_const(LitI64(shift))
          ctx.def_map[result] = SSAOp::Binary(
            BinaryOp::i64_shl(),
            right, // ✅ shift the non-const operand
            shift_v,
          )
          ctx.changed = true
          return true
        }
        _ => ()
      }
      false
    }
    I32DivUOp =>
      match ctx.get_const(right) {
        Some(LitI32(c)) if is_power_of_2_i32(c) => {
          if c == 1 {
            ctx.replace(result, left)
            ctx.changed = true
            return true
          }
          let shift = log2_i32(c)
          let shift_v = ctx.make_const(LitI32(shift))
          ctx.def_map[result] = SSAOp::Binary(
            BinaryOp::i32_shr_u(),
            left,
            shift_v,
          )
          ctx.changed = true
          true
        }
        _ => false
      }
    I64DivUOp =>
      match ctx.get_const(right) {
        Some(LitI64(c)) if is_power_of_2_i64(c) => {
          if c == 1L {
            ctx.replace(result, left)
            ctx.changed = true
            return true
          }
          let shift = log2_i64(c)
          let shift_v = ctx.make_const(LitI64(shift))
          ctx.def_map[result] = SSAOp::Binary(
            BinaryOp::i64_shr_u(),
            left,
            shift_v,
          )
          ctx.changed = true
          true
        }
        _ => false
      }
    I32RemUOp =>
      match ctx.get_const(right) {
        Some(LitI32(c)) if is_power_of_2_i32(c) => {
          let mask_v = ctx.make_const(LitI32(c - 1))
          ctx.def_map[result] = SSAOp::Binary(BinaryOp::i32_and(), left, mask_v)
          ctx.changed = true
          true
        }
        _ => false
      }
    I64RemUOp =>
      match ctx.get_const(right) {
        Some(LitI64(c)) if is_power_of_2_i64(c) => {
          let mask_v = ctx.make_const(LitI64(c - 1L))
          ctx.def_map[result] = SSAOp::Binary(BinaryOp::i64_and(), left, mask_v)
          ctx.changed = true
          true
        }
        _ => false
      }
    _ => false
  }
}

// ============================================================
// Algebraic simplification
// ============================================================

///|
fn try_algebraic_simplify(
  ctx : SSAOptCtx,
  result : SSAValue,
  op : BinaryOp,
  left : SSAValue,
  right : SSAValue,
) -> Bool {
  let left_r = ctx.resolve(left)
  let right_r = ctx.resolve(right)
  let left_c = ctx.get_const(left)
  let right_c = ctx.get_const(right)
  match op {
    // x + 0 = 0 + x = x
    I32AddOp => {
      match right_c {
        Some(LitI32(0)) => {
          ctx.replace(result, left_r)
          return true
        }
        _ => ()
      }
      match left_c {
        Some(LitI32(0)) => {
          ctx.replace(result, right_r)
          return true
        }
        _ => ()
      }
      false
    }
    I64AddOp => {
      match right_c {
        Some(LitI64(0L)) => {
          ctx.replace(result, left_r)
          return true
        }
        _ => ()
      }
      match left_c {
        Some(LitI64(0L)) => {
          ctx.replace(result, right_r)
          return true
        }
        _ => ()
      }
      false
    }
    // x - 0 = x; x - x = 0
    I32SubOp => {
      match right_c {
        Some(LitI32(0)) => {
          ctx.replace(result, left_r)
          return true
        }
        _ => ()
      }
      if left_r == right_r {
        let z = ctx.make_const(LitI32(0))
        ctx.replace(result, z)
        return true
      }
      false
    }
    I64SubOp => {
      match right_c {
        Some(LitI64(0L)) => {
          ctx.replace(result, left_r)
          return true
        }
        _ => ()
      }
      if left_r == right_r {
        let z = ctx.make_const(LitI64(0L))
        ctx.replace(result, z)
        return true
      }
      false
    }
    // x * 0 = 0; x * 1 = x
    I32MulOp => {
      match right_c {
        Some(LitI32(0)) => {
          let z = ctx.make_const(LitI32(0))
          ctx.replace(result, z)
          return true
        }
        Some(LitI32(1)) => {
          ctx.replace(result, left_r)
          return true
        }
        _ => ()
      }
      match left_c {
        Some(LitI32(0)) => {
          let z = ctx.make_const(LitI32(0))
          ctx.replace(result, z)
          return true
        }
        Some(LitI32(1)) => {
          ctx.replace(result, right_r)
          return true
        }
        _ => ()
      }
      false
    }
    I64MulOp => {
      match right_c {
        Some(LitI64(0L)) => {
          let z = ctx.make_const(LitI64(0L))
          ctx.replace(result, z)
          return true
        }
        Some(LitI64(1L)) => {
          ctx.replace(result, left_r)
          return true
        }
        _ => ()
      }
      match left_c {
        Some(LitI64(0L)) => {
          let z = ctx.make_const(LitI64(0L))
          ctx.replace(result, z)
          return true
        }
        Some(LitI64(1L)) => {
          ctx.replace(result, right_r)
          return true
        }
        _ => ()
      }
      false
    }
    // x & 0 = 0; x & -1 = x; x & x = x
    I32AndOp => {
      match right_c {
        Some(LitI32(0)) => {
          let z = ctx.make_const(LitI32(0))
          ctx.replace(result, z)
          return true
        }
        Some(LitI32(-1)) => {
          ctx.replace(result, left_r)
          return true
        }
        _ => ()
      }
      match left_c {
        Some(LitI32(0)) => {
          let z = ctx.make_const(LitI32(0))
          ctx.replace(result, z)
          return true
        }
        Some(LitI32(-1)) => {
          ctx.replace(result, right_r)
          return true
        }
        _ => ()
      }
      if left_r == right_r {
        ctx.replace(result, left_r)
        return true
      }
      false
    }
    I64AndOp => {
      match right_c {
        Some(LitI64(0L)) => {
          let z = ctx.make_const(LitI64(0L))
          ctx.replace(result, z)
          return true
        }
        Some(LitI64(-1L)) => {
          ctx.replace(result, left_r)
          return true
        }
        _ => ()
      }
      match left_c {
        Some(LitI64(0L)) => {
          let z = ctx.make_const(LitI64(0L))
          ctx.replace(result, z)
          return true
        }
        Some(LitI64(-1L)) => {
          ctx.replace(result, right_r)
          return true
        }
        _ => ()
      }
      if left_r == right_r {
        ctx.replace(result, left_r)
        return true
      }
      false
    }
    // x | 0 = x; x | -1 = -1; x | x = x
    I32OrOp => {
      match right_c {
        Some(LitI32(0)) => {
          ctx.replace(result, left_r)
          return true
        }
        Some(LitI32(-1)) => {
          let z = ctx.make_const(LitI32(-1))
          ctx.replace(result, z)
          return true
        }
        _ => ()
      }
      match left_c {
        Some(LitI32(0)) => {
          ctx.replace(result, right_r)
          return true
        }
        Some(LitI32(-1)) => {
          let z = ctx.make_const(LitI32(-1))
          ctx.replace(result, z)
          return true
        }
        _ => ()
      }
      if left_r == right_r {
        ctx.replace(result, left_r)
        return true
      }
      false
    }
    I64OrOp => {
      match right_c {
        Some(LitI64(0L)) => {
          ctx.replace(result, left_r)
          return true
        }
        Some(LitI64(-1L)) => {
          let z = ctx.make_const(LitI64(-1L))
          ctx.replace(result, z)
          return true
        }
        _ => ()
      }
      match left_c {
        Some(LitI64(0L)) => {
          ctx.replace(result, right_r)
          return true
        }
        Some(LitI64(-1L)) => {
          let z = ctx.make_const(LitI64(-1L))
          ctx.replace(result, z)
          return true
        }
        _ => ()
      }
      if left_r == right_r {
        ctx.replace(result, left_r)
        return true
      }
      false
    }
    // x ^ 0 = x; x ^ x = 0
    I32XorOp => {
      match right_c {
        Some(LitI32(0)) => {
          ctx.replace(result, left_r)
          return true
        }
        _ => ()
      }
      match left_c {
        Some(LitI32(0)) => {
          ctx.replace(result, right_r)
          return true
        }
        _ => ()
      }
      if left_r == right_r {
        let z = ctx.make_const(LitI32(0))
        ctx.replace(result, z)
        return true
      }
      false
    }
    I64XorOp => {
      match right_c {
        Some(LitI64(0L)) => {
          ctx.replace(result, left_r)
          return true
        }
        _ => ()
      }
      match left_c {
        Some(LitI64(0L)) => {
          ctx.replace(result, right_r)
          return true
        }
        _ => ()
      }
      if left_r == right_r {
        let z = ctx.make_const(LitI64(0L))
        ctx.replace(result, z)
        return true
      }
      false
    }
    // x << 0 = x; x >> 0 = x
    I32ShlOp | I32ShrSOp | I32ShrUOp | I32RotlOp | I32RotrOp =>
      match right_c {
        Some(LitI32(0)) => {
          ctx.replace(result, left_r)
          true
        }
        _ => false
      }
    I64ShlOp | I64ShrSOp | I64ShrUOp | I64RotlOp | I64RotrOp =>
      match right_c {
        Some(LitI64(0L)) => {
          ctx.replace(result, left_r)
          true
        }
        _ => false
      }
    // x /s 1 = x
    I32DivSOp =>
      match right_c {
        Some(LitI32(1)) => {
          ctx.replace(result, left_r)
          true
        }
        _ => false
      }
    I64DivSOp =>
      match right_c {
        Some(LitI64(1L)) => {
          ctx.replace(result, left_r)
          true
        }
        _ => false
      }
    I32DivUOp =>
      match right_c {
        Some(LitI32(1)) => {
          ctx.replace(result, left_r)
          true
        }
        _ => false
      }
    I64DivUOp =>
      match right_c {
        Some(LitI64(1L)) => {
          ctx.replace(result, left_r)
          true
        }
        _ => false
      }
    // Self-comparison: x == x => 1, x != x => 0,
    // x <= x => 1, x >= x => 1, x < x => 0, x > x => 0
    I32EqOp | I64EqOp if left_r == right_r => {
      let z = ctx.make_const(LitI32(1))
      ctx.replace(result, z)
      true
    }
    I32NeOp | I64NeOp if left_r == right_r => {
      let z = ctx.make_const(LitI32(0))
      ctx.replace(result, z)
      true
    }
    I32LeSOp
    | I32LeUOp
    | I32GeSOp
    | I32GeUOp
    | I64LeSOp
    | I64LeUOp
    | I64GeSOp
    | I64GeUOp if left_r == right_r => {
      let z = ctx.make_const(LitI32(1))
      ctx.replace(result, z)
      true
    }
    I32LtSOp
    | I32LtUOp
    | I32GtSOp
    | I32GtUOp
    | I64LtSOp
    | I64LtUOp
    | I64GtSOp
    | I64GtUOp if left_r == right_r => {
      let z = ctx.make_const(LitI32(0))
      ctx.replace(result, z)
      true
    }
    _ => false
  }
}

// ============================================================
// Rewriting: apply replacements to all SSAValue references
// ============================================================

///|
fn SSAOptCtx::rewrite_value(self : SSAOptCtx, v : SSAValue) -> SSAValue {
  self.resolve(v)
}

///|
fn SSAOptCtx::rewrite_values(
  self : SSAOptCtx,
  vs : Array[SSAValue],
) -> Array[SSAValue] {
  vs.map(fn(v) { self.rewrite_value(v) })
}

///|
fn SSAOptCtx::rewrite_op(self : SSAOptCtx, op : SSAOp) -> SSAOp {
  match op {
    I32Const(_)
    | I64Const(_)
    | F32Const(_)
    | F64Const(_)
    | RefNull(_)
    | RefFunc(_)
    | V128Const(_)
    | MemorySize(_)
    | AtomicFence
    | DataDrop(_)
    | GlobalGet(_)
    | TableSize(_)
    | ElemDrop(_)
    | StructNewDefault(_) => op
    Copy(v) => Copy(self.rewrite_value(v))
    Binary(bop, a, b) =>
      Binary(bop, self.rewrite_value(a), self.rewrite_value(b))
    Unary(uop, a) => Unary(uop, self.rewrite_value(a))
    Load(lop, ma, a) => Load(lop, ma, self.rewrite_value(a))
    Store(sop, ma, a, b) =>
      Store(sop, ma, self.rewrite_value(a), self.rewrite_value(b))
    MemoryGrow(idx, a) => MemoryGrow(idx, self.rewrite_value(a))
    MemoryAtomicNotify(ma, addr, count) =>
      MemoryAtomicNotify(
        ma,
        self.rewrite_value(addr),
        self.rewrite_value(count),
      )
    MemoryAtomicWait32(ma, addr, expected, timeout) =>
      MemoryAtomicWait32(
        ma,
        self.rewrite_value(addr),
        self.rewrite_value(expected),
        self.rewrite_value(timeout),
      )
    MemoryAtomicWait64(ma, addr, expected, timeout) =>
      MemoryAtomicWait64(
        ma,
        self.rewrite_value(addr),
        self.rewrite_value(expected),
        self.rewrite_value(timeout),
      )
    AtomicRmw(op, ma, addr, val) =>
      AtomicRmw(op, ma, self.rewrite_value(addr), self.rewrite_value(val))
    AtomicCmpxchg(op, ma, addr, expected, replacement) =>
      AtomicCmpxchg(
        op,
        ma,
        self.rewrite_value(addr),
        self.rewrite_value(expected),
        self.rewrite_value(replacement),
      )
    MemoryFill(idx, a, b, c) =>
      MemoryFill(
        idx,
        self.rewrite_value(a),
        self.rewrite_value(b),
        self.rewrite_value(c),
      )
    MemoryCopy(i1, i2, a, b, c) =>
      MemoryCopy(
        i1,
        i2,
        self.rewrite_value(a),
        self.rewrite_value(b),
        self.rewrite_value(c),
      )
    MemoryInit(di, mi, a, b, c) =>
      MemoryInit(
        di,
        mi,
        self.rewrite_value(a),
        self.rewrite_value(b),
        self.rewrite_value(c),
      )
    GlobalSet(idx, a) => GlobalSet(idx, self.rewrite_value(a))
    TableGet(idx, a) => TableGet(idx, self.rewrite_value(a))
    TableSet(idx, a, b) =>
      TableSet(idx, self.rewrite_value(a), self.rewrite_value(b))
    TableGrow(idx, a, b) =>
      TableGrow(idx, self.rewrite_value(a), self.rewrite_value(b))
    TableFill(idx, a, b, c) =>
      TableFill(
        idx,
        self.rewrite_value(a),
        self.rewrite_value(b),
        self.rewrite_value(c),
      )
    TableCopy(i1, i2, a, b, c) =>
      TableCopy(
        i1,
        i2,
        self.rewrite_value(a),
        self.rewrite_value(b),
        self.rewrite_value(c),
      )
    TableInit(ei, ti, a, b, c) =>
      TableInit(
        ei,
        ti,
        self.rewrite_value(a),
        self.rewrite_value(b),
        self.rewrite_value(c),
      )
    Call(fi, vs) => Call(fi, self.rewrite_values(vs))
    CallIndirect(ti, tbi, vs, v) =>
      CallIndirect(ti, tbi, self.rewrite_values(vs), self.rewrite_value(v))
    CallRef(ti, vs, v) =>
      CallRef(ti, self.rewrite_values(vs), self.rewrite_value(v))
    RefIsNull(a) => RefIsNull(self.rewrite_value(a))
    RefEq(a, b) => RefEq(self.rewrite_value(a), self.rewrite_value(b))
    RefAsNonNull(a) => RefAsNonNull(self.rewrite_value(a))
    RefI31(a) => RefI31(self.rewrite_value(a))
    I31GetS(a) => I31GetS(self.rewrite_value(a))
    I31GetU(a) => I31GetU(self.rewrite_value(a))
    RefTest(b, ht, a) => RefTest(b, ht, self.rewrite_value(a))
    RefCast(b, ht, a) => RefCast(b, ht, self.rewrite_value(a))
    AnyConvertExtern(a) => AnyConvertExtern(self.rewrite_value(a))
    ExternConvertAny(a) => ExternConvertAny(self.rewrite_value(a))
    StructNew(ti, vs) => StructNew(ti, self.rewrite_values(vs))
    StructGet(ti, fi, a) => StructGet(ti, fi, self.rewrite_value(a))
    StructGetS(ti, fi, a) => StructGetS(ti, fi, self.rewrite_value(a))
    StructGetU(ti, fi, a) => StructGetU(ti, fi, self.rewrite_value(a))
    StructSet(ti, fi, a, b) =>
      StructSet(ti, fi, self.rewrite_value(a), self.rewrite_value(b))
    ArrayNew(ti, a, b) =>
      ArrayNew(ti, self.rewrite_value(a), self.rewrite_value(b))
    ArrayNewDefault(ti, a) => ArrayNewDefault(ti, self.rewrite_value(a))
    ArrayNewFixed(ti, vs) => ArrayNewFixed(ti, self.rewrite_values(vs))
    ArrayNewData(ti, di, a, b) =>
      ArrayNewData(ti, di, self.rewrite_value(a), self.rewrite_value(b))
    ArrayNewElem(ti, ei, a, b) =>
      ArrayNewElem(ti, ei, self.rewrite_value(a), self.rewrite_value(b))
    ArrayGet(ti, a, b) =>
      ArrayGet(ti, self.rewrite_value(a), self.rewrite_value(b))
    ArrayGetS(ti, a, b) =>
      ArrayGetS(ti, self.rewrite_value(a), self.rewrite_value(b))
    ArrayGetU(ti, a, b) =>
      ArrayGetU(ti, self.rewrite_value(a), self.rewrite_value(b))
    ArraySet(ti, a, b, c) =>
      ArraySet(
        ti,
        self.rewrite_value(a),
        self.rewrite_value(b),
        self.rewrite_value(c),
      )
    ArrayLen(a) => ArrayLen(self.rewrite_value(a))
    ArrayFill(ti, a, b, c, d) =>
      ArrayFill(
        ti,
        self.rewrite_value(a),
        self.rewrite_value(b),
        self.rewrite_value(c),
        self.rewrite_value(d),
      )
    ArrayCopy(t1, t2, a, b, c, d, e) =>
      ArrayCopy(
        t1,
        t2,
        self.rewrite_value(a),
        self.rewrite_value(b),
        self.rewrite_value(c),
        self.rewrite_value(d),
        self.rewrite_value(e),
      )
    ArrayInitData(ti, di, a, b, c, d) =>
      ArrayInitData(
        ti,
        di,
        self.rewrite_value(a),
        self.rewrite_value(b),
        self.rewrite_value(c),
        self.rewrite_value(d),
      )
    ArrayInitElem(ti, ei, a, b, c, d) =>
      ArrayInitElem(
        ti,
        ei,
        self.rewrite_value(a),
        self.rewrite_value(b),
        self.rewrite_value(c),
        self.rewrite_value(d),
      )
    Splat(sop, a) => Splat(sop, self.rewrite_value(a))
    ExtractLane(eop, li, a) => ExtractLane(eop, li, self.rewrite_value(a))
    ReplaceLane(rop, li, a, b) =>
      ReplaceLane(rop, li, self.rewrite_value(a), self.rewrite_value(b))
    Shuffle(lanes, a, b) =>
      Shuffle(lanes, self.rewrite_value(a), self.rewrite_value(b))
    Swizzle(a, b) => Swizzle(self.rewrite_value(a), self.rewrite_value(b))
    V128Shift(sop, a, b) =>
      V128Shift(sop, self.rewrite_value(a), self.rewrite_value(b))
    V128Ternary(top, a, b, c) =>
      V128Ternary(
        top,
        self.rewrite_value(a),
        self.rewrite_value(b),
        self.rewrite_value(c),
      )
    V128LoadLane(lop, ma, li, a, b) =>
      V128LoadLane(lop, ma, li, self.rewrite_value(a), self.rewrite_value(b))
    V128StoreLane(sop, ma, li, a, b) =>
      V128StoreLane(sop, ma, li, self.rewrite_value(a), self.rewrite_value(b))
    Select(tys, a, b, c) =>
      Select(
        tys,
        self.rewrite_value(a),
        self.rewrite_value(b),
        self.rewrite_value(c),
      )
    Throw(ti, vs) => Throw(ti, self.rewrite_values(vs))
  }
}

///|
fn SSAOptCtx::rewrite_terminator(
  self : SSAOptCtx,
  term : SSATerminator,
) -> SSATerminator {
  match term {
    Br(_) => term
    BrIf(v, t, f) => BrIf(self.rewrite_value(v), t, f)
    BrTable(v, targets, default) =>
      BrTable(self.rewrite_value(v), targets, default)
    BrOnNull(v, t, f) => BrOnNull(self.rewrite_value(v), t, f)
    BrOnNonNull(v, t, f) => BrOnNonNull(self.rewrite_value(v), t, f)
    BrOnCast(cop, h1, h2, v, t, f) =>
      BrOnCast(cop, h1, h2, self.rewrite_value(v), t, f)
    BrOnCastFail(cop, h1, h2, v, t, f) =>
      BrOnCastFail(cop, h1, h2, self.rewrite_value(v), t, f)
    Return(vs) => Return(self.rewrite_values(vs))
    ReturnCall(fi, vs) => ReturnCall(fi, self.rewrite_values(vs))
    ReturnCallIndirect(ti, tbi, vs, v) =>
      ReturnCallIndirect(
        ti,
        tbi,
        self.rewrite_values(vs),
        self.rewrite_value(v),
      )
    ReturnCallRef(ti, vs, v) =>
      ReturnCallRef(ti, self.rewrite_values(vs), self.rewrite_value(v))
    ThrowRef(v) => ThrowRef(self.rewrite_value(v))
    Unreachable => Unreachable
  }
}

///|
fn SSAOptCtx::rewrite_phi(self : SSAOptCtx, phi : PhiNode) -> PhiNode {
  let new_args : Map[BlockId, SSAValue] = {}
  for bid, v in phi.args {
    new_args[bid] = self.rewrite_value(v)
  }
  { local_idx: phi.local_idx, result: phi.result, args: new_args }
}

// ============================================================
// Mark uses for DCE
// ============================================================

///|
fn SSAOptCtx::mark_value_used(self : SSAOptCtx, v : SSAValue) -> Unit {
  self.used.add(self.resolve(v))
}

///|
fn SSAOptCtx::mark_op_uses(self : SSAOptCtx, op : SSAOp) -> Unit {
  match op {
    I32Const(_)
    | I64Const(_)
    | F32Const(_)
    | F64Const(_)
    | RefNull(_)
    | RefFunc(_)
    | V128Const(_)
    | MemorySize(_)
    | AtomicFence
    | DataDrop(_)
    | GlobalGet(_)
    | TableSize(_)
    | ElemDrop(_)
    | StructNewDefault(_) => ()
    Copy(v) => self.mark_value_used(v)
    Binary(_, a, b) => {
      self.mark_value_used(a)
      self.mark_value_used(b)
    }
    Unary(_, a) => self.mark_value_used(a)
    Load(_, _, a) => self.mark_value_used(a)
    Store(_, _, a, b) => {
      self.mark_value_used(a)
      self.mark_value_used(b)
    }
    MemoryGrow(_, a) => self.mark_value_used(a)
    MemoryAtomicNotify(_, addr, count) => {
      self.mark_value_used(addr)
      self.mark_value_used(count)
    }
    MemoryAtomicWait32(_, addr, expected, timeout)
    | MemoryAtomicWait64(_, addr, expected, timeout) => {
      self.mark_value_used(addr)
      self.mark_value_used(expected)
      self.mark_value_used(timeout)
    }
    AtomicRmw(_, _, addr, val) => {
      self.mark_value_used(addr)
      self.mark_value_used(val)
    }
    AtomicCmpxchg(_, _, addr, expected, replacement) => {
      self.mark_value_used(addr)
      self.mark_value_used(expected)
      self.mark_value_used(replacement)
    }
    MemoryFill(_, a, b, c)
    | MemoryCopy(_, _, a, b, c)
    | MemoryInit(_, _, a, b, c)
    | TableFill(_, a, b, c)
    | TableCopy(_, _, a, b, c)
    | TableInit(_, _, a, b, c) => {
      self.mark_value_used(a)
      self.mark_value_used(b)
      self.mark_value_used(c)
    }
    GlobalSet(_, a)
    | TableGet(_, a)
    | RefIsNull(a)
    | RefAsNonNull(a)
    | RefI31(a)
    | I31GetS(a)
    | I31GetU(a)
    | AnyConvertExtern(a)
    | ExternConvertAny(a)
    | ArrayLen(a)
    | ArrayNewDefault(_, a) => self.mark_value_used(a)
    TableSet(_, a, b)
    | TableGrow(_, a, b)
    | RefEq(a, b)
    | ArrayNew(_, a, b)
    | ArrayNewData(_, _, a, b)
    | ArrayNewElem(_, _, a, b) => {
      self.mark_value_used(a)
      self.mark_value_used(b)
    }
    RefTest(_, _, a)
    | RefCast(_, _, a)
    | StructGet(_, _, a)
    | StructGetS(_, _, a)
    | StructGetU(_, _, a)
    | Splat(_, a)
    | ExtractLane(_, _, a) => self.mark_value_used(a)
    StructSet(_, _, a, b)
    | ReplaceLane(_, _, a, b)
    | Shuffle(_, a, b)
    | Swizzle(a, b)
    | V128Shift(_, a, b) => {
      self.mark_value_used(a)
      self.mark_value_used(b)
    }
    ArrayGet(_, a, b) | ArrayGetS(_, a, b) | ArrayGetU(_, a, b) => {
      self.mark_value_used(a)
      self.mark_value_used(b)
    }
    ArraySet(_, a, b, c) | V128Ternary(_, a, b, c) | Select(_, a, b, c) => {
      self.mark_value_used(a)
      self.mark_value_used(b)
      self.mark_value_used(c)
    }
    ArrayFill(_, a, b, c, d)
    | ArrayInitData(_, _, a, b, c, d)
    | ArrayInitElem(_, _, a, b, c, d) => {
      self.mark_value_used(a)
      self.mark_value_used(b)
      self.mark_value_used(c)
      self.mark_value_used(d)
    }
    ArrayCopy(_, _, a, b, c, d, e) => {
      self.mark_value_used(a)
      self.mark_value_used(b)
      self.mark_value_used(c)
      self.mark_value_used(d)
      self.mark_value_used(e)
    }
    Call(_, vs) | StructNew(_, vs) | ArrayNewFixed(_, vs) | Throw(_, vs) =>
      for v in vs {
        self.mark_value_used(v)
      }
    CallIndirect(_, _, vs, v) | CallRef(_, vs, v) => {
      for vi in vs {
        self.mark_value_used(vi)
      }
      self.mark_value_used(v)
    }
    V128LoadLane(_, _, _, a, b) | V128StoreLane(_, _, _, a, b) => {
      self.mark_value_used(a)
      self.mark_value_used(b)
    }
  }
}

///|
fn SSAOptCtx::mark_terminator_uses(
  self : SSAOptCtx,
  term : SSATerminator,
) -> Unit {
  match term {
    Br(_) | Unreachable => ()
    BrIf(v, _, _)
    | BrTable(v, _, _)
    | BrOnNull(v, _, _)
    | BrOnNonNull(v, _, _)
    | ThrowRef(v) => self.mark_value_used(v)
    BrOnCast(_, _, _, v, _, _) | BrOnCastFail(_, _, _, v, _, _) =>
      self.mark_value_used(v)
    Return(vs) | ReturnCall(_, vs) =>
      for v in vs {
        self.mark_value_used(v)
      }
    ReturnCallIndirect(_, _, vs, v) | ReturnCallRef(_, vs, v) => {
      for vi in vs {
        self.mark_value_used(vi)
      }
      self.mark_value_used(v)
    }
  }
}

///|
fn SSAOptCtx::mark_phi_uses(self : SSAOptCtx, phi : PhiNode) -> Unit {
  for _, v in phi.args {
    self.mark_value_used(v)
  }
}

// ============================================================
// Per-instruction optimization
// ============================================================

///|
fn optimize_assign(ctx : SSAOptCtx, result : SSAValue, op : SSAOp) -> Unit {
  match op {
    // Copy propagation
    Copy(v) => {
      ctx.replace(result, ctx.resolve(v))
      return
    }
    // Constant folding: unary
    Unary(uop, a) =>
      match ctx.get_const(a) {
        Some(lit) =>
          match eval_ssa_unary(uop, lit) {
            Some(result_lit) => {
              let cv = ctx.make_const(result_lit)
              ctx.replace(result, cv)
              return
            }
            None => ()
          }
        None => ()
      }
    // Constant folding: binary
    Binary(bop, a, b) => {
      match (ctx.get_const(a), ctx.get_const(b)) {
        (Some(la), Some(lb)) =>
          match eval_ssa_binary(bop, la, lb) {
            Some(result_lit) => {
              let cv = ctx.make_const(result_lit)
              ctx.replace(result, cv)
              return
            }
            None => ()
          }
        _ => ()
      }
      // Strength reduction
      if try_strength_reduce_ssa(ctx, result, bop, a, b) {
        return
      }
      // Algebraic simplification
      if try_algebraic_simplify(ctx, result, bop, a, b) {
        return
      }
    }
    // Select with constant condition
    Select(_, cond, t, f) =>
      match ctx.get_const(cond) {
        Some(LitI32(0)) => {
          ctx.replace(result, ctx.resolve(f))
          return
        }
        Some(LitI32(_)) => {
          ctx.replace(result, ctx.resolve(t))
          return
        }
        _ => ()
      }
    _ => ()
  }
}

// ============================================================
// Terminator optimization
// ============================================================

///|
fn optimize_terminator(ctx : SSAOptCtx, term : SSATerminator) -> SSATerminator {
  match term {
    // BrIf with constant condition
    BrIf(v, then_blk, else_blk) =>
      match ctx.get_const(v) {
        Some(LitI32(0)) => {
          ctx.changed = true
          SSATerminator::Br(else_blk)
        }
        Some(LitI32(_)) => {
          ctx.changed = true
          SSATerminator::Br(then_blk)
        }
        _ => term
      }
    // BrOnNull with known null
    BrOnNull(v, null_blk, nonnull_blk) =>
      match ctx.get_op(v) {
        Some(RefNull(_)) => {
          ctx.changed = true
          SSATerminator::Br(null_blk)
        }
        Some(RefFunc(_)) => {
          ctx.changed = true
          SSATerminator::Br(nonnull_blk)
        }
        _ => term
      }
    BrOnNonNull(v, nonnull_blk, null_blk) =>
      match ctx.get_op(v) {
        Some(RefNull(_)) => {
          ctx.changed = true
          SSATerminator::Br(null_blk)
        }
        Some(RefFunc(_)) => {
          ctx.changed = true
          SSATerminator::Br(nonnull_blk)
        }
        _ => term
      }
    // BrTable with constant index
    BrTable(v, targets, default) =>
      match ctx.get_const(v) {
        Some(LitI32(idx)) => {
          ctx.changed = true
          if idx >= 0 && idx < targets.length() {
            SSATerminator::Br(targets[idx])
          } else {
            SSATerminator::Br(default)
          }
        }
        _ => term
      }
    _ => term
  }
}

// ============================================================
// Simplify phis: if all args resolve to the same value, replace
// ============================================================

///|
fn optimize_phi(ctx : SSAOptCtx, phi : PhiNode) -> Unit {
  let mut unique : SSAValue? = None
  let result_r = ctx.resolve(phi.result)
  for _, v in phi.args {
    let vr = ctx.resolve(v)
    if vr == result_r {
      continue // self-reference in phi, skip
    }
    match unique {
      None => unique = Some(vr)
      Some(u) =>
        if u != vr {
          return // multiple distinct values, can't simplify
        }
    }
  }
  match unique {
    Some(u) => ctx.replace(phi.result, u)
    None => () // all self-referencing, leave alone
  }
}

///|
/// Run SSA optimization passes until convergence
pub fn SSACFG::optimize(self : SSACFG) -> SSACFG {
  let mut current = self

  // Limit iterations to avoid pathological cases
  for _iter = 0; _iter < 10; _iter = _iter + 1 {
    let ctx = SSAOptCtx::new(current)

    // ----------------------------------------------------------
    // Phase 1: Local instruction-level optimization
    // ----------------------------------------------------------

    // Store optimized terminators from Phase 1
    let optimized_terminators : Map[BlockId, SSATerminator] = {}

    // ----------------------------------------------------------
    // Phase 1: Local instruction-level optimization
    // ----------------------------------------------------------
    for b in current.blocks {
      let (bid, block) = b

      // Phis and instructions...
      for phi in block.phis {
        optimize_phi(ctx, phi)
      }
      for instr in block.instrs {
        match instr {
          Assign(v, op) => optimize_assign(ctx, v, op)
          Effect(_) => ()
        }
      }

      // Terminators - store the result!
      let opt_term = optimize_terminator(ctx, block.terminator)
      let new_term = ctx.rewrite_terminator(opt_term)
      ctx.mark_terminator_uses(new_term)
      optimized_terminators[bid] = new_term
    }
    let mut iteration_changed = ctx.changed

    // ----------------------------------------------------------
    // Phase 2: Rewrite SSA using replacement map
    // ----------------------------------------------------------

    let new_blocks : Map[BlockId, SSABlock] = {}

    // First pass: rewrite + mark uses
    for b in current.blocks {
      let (bid, block) = b
      // Rewrite phis
      let new_phis : Array[PhiNode] = []
      for phi in block.phis {
        if ctx.replacements.contains(phi.result) {
          continue
        }
        let rp = ctx.rewrite_phi(phi)
        ctx.mark_phi_uses(rp)
        new_phis.push(rp)
      }

      // Rewrite terminator
      let new_term = optimized_terminators[bid]
      ctx.mark_terminator_uses(new_term)

      // Rewrite instructions (keep all for now)
      let rewritten : Array[SSAInstr] = []
      for instr in block.instrs {
        match instr {
          Assign(v, op) =>
            if ctx.replacements.contains(v) {
              () // Eliminated by replacement
            } else {
              let effective_op = match ctx.def_map.get(v) {
                Some(new_op) => new_op
                None => op
              }
              let new_op = ctx.rewrite_op(effective_op)
              rewritten.push(Assign(v, new_op))
            }
          Effect(op) => {
            let new_op = ctx.rewrite_op(op)
            ctx.mark_op_uses(new_op)
            rewritten.push(Effect(new_op))
          }
        }
      }

      // ------------------------------------------------------
      // Phase 3: Dead code elimination (pure instructions)
      // ------------------------------------------------------

      let final_instrs : Array[SSAInstr] = []
      for i = rewritten.length() - 1; i >= 0; i = i - 1 {
        match rewritten[i] {
          Assign(v, op) =>
            if has_side_effects(op) || ctx.used.contains(v) {
              ctx.mark_op_uses(op)
              final_instrs.push(rewritten[i])
            }
          Effect(op) => {
            ctx.mark_op_uses(op)
            final_instrs.push(rewritten[i])
          }
        }
      }
      if final_instrs.length() != rewritten.length() {
        iteration_changed = true
      }
      // Reverse back to original order
      final_instrs.rev_in_place()
      new_blocks[bid] = {
        id: bid,
        phis: new_phis,
        instrs: final_instrs,
        terminator: new_term,
      }
    }

    // ----------------------------------------------------------
    // Phase 4: Emit newly created constants (entry block)
    // ----------------------------------------------------------

    let entry = current.entry
    match new_blocks.get(entry) {
      Some(entry_block) => {
        let new_instrs = entry_block.instrs
        for b in ctx.def_map {
          let (v, op) = b
          let predicate = fn(i : SSAInstr) -> Bool {
            match i {
              Assign(av, _) => av == v
              _ => false
            }
          }
          if is_const_op(op) &&
            ctx.used.contains(v) &&
            not(entry_block.instrs.any(predicate)) {
            new_instrs.insert(0, Assign(v, op))
            iteration_changed = true
          }
        }
        new_blocks[entry] = {
          id: entry_block.id,
          phis: entry_block.phis,
          instrs: new_instrs,
          terminator: entry_block.terminator,
        }
      }
      None => ()
    }

    // ----------------------------------------------------------
    // Commit iteration
    // ----------------------------------------------------------

    current = { ..current, blocks: new_blocks, next_value: ctx.next_value }
    if not(iteration_changed) {
      break
    }
  }
  current
}
