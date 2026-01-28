// ============================================================================
// dataflow/types.mbt - Core type definitions
// ============================================================================

///|
/// Wasm value types
pub enum WasmType {
  I32
  I64
  F32
  F64
  V128
  FuncRef
  ExternRef
  Unreachable
  None
} derive(Eq, Hash, Show)

///|
pub fn WasmType::i32() -> WasmType {
  I32
}

///|
pub fn WasmType::i64() -> WasmType {
  I64
}

///|
pub fn WasmType::f32() -> WasmType {
  F32
}

///|
pub fn WasmType::f64() -> WasmType {
  F64
}

///|
pub fn WasmType::v128() -> WasmType {
  V128
}

///|
pub fn WasmType::func_ref() -> WasmType {
  FuncRef
}

///|
pub fn WasmType::extern_ref() -> WasmType {
  ExternRef
}

///|
pub fn WasmType::unreachable_() -> WasmType {
  Unreachable
}

///|
pub fn WasmType::none() -> WasmType {
  None
}

///|
pub fn WasmType::is_integer(self : WasmType) -> Bool {
  match self {
    I32 | I64 => true
    _ => false
  }
}

///|
pub fn WasmType::is_concrete(self : WasmType) -> Bool {
  match self {
    Unreachable | None => false
    _ => true
  }
}

///|
pub fn WasmType::bit_size(self : WasmType) -> Int {
  match self {
    I32 | F32 => 32
    I64 | F64 => 64
    V128 => 128
    _ => 0
  }
}

///|
/// Binary operations
pub enum BinaryOp {
  AddInt32
  AddInt64
  SubInt32
  SubInt64
  MulInt32
  MulInt64
  DivSInt32
  DivSInt64
  DivUInt32
  DivUInt64
  RemSInt32
  RemSInt64
  RemUInt32
  RemUInt64
  AndInt32
  AndInt64
  OrInt32
  OrInt64
  XorInt32
  XorInt64
  ShlInt32
  ShlInt64
  ShrUInt32
  ShrUInt64
  ShrSInt32
  ShrSInt64
  RotLInt32
  RotLInt64
  RotRInt32
  RotRInt64
  EqInt32
  EqInt64
  NeInt32
  NeInt64
  LtSInt32
  LtSInt64
  LtUInt32
  LtUInt64
  LeSInt32
  LeSInt64
  LeUInt32
  LeUInt64
  GtSInt32
  GtSInt64
  GtUInt32
  GtUInt64
  GeSInt32
  GeSInt64
  GeUInt32
  GeUInt64
  AddFloat32
  AddFloat64
  SubFloat32
  SubFloat64
  MulFloat32
  MulFloat64
  DivFloat32
  DivFloat64
  MinFloat32
  MaxFloat32
  CopysignFloat32
  EqFloat32
  NeFloat32
  LtFloat32
  LeFloat32
  GtFloat32
  GeFloat32
  MinFloat64
  MaxFloat64
  CopysignFloat64
  EqFloat64
  NeFloat64
  LtFloat64
  LeFloat64
  GtFloat64
  GeFloat64
} derive(Eq, Show)

///|
pub fn BinaryOp::is_associative(self : BinaryOp) -> Bool {
  match self {
    // Integer arithmetic
    AddInt32
    | AddInt64
    | MulInt32
    | MulInt64

    // Integer bitwise
    | AndInt32
    | AndInt64
    | OrInt32
    | OrInt64
    | XorInt32
    | XorInt64 => true
    _ => false
  }
}

///|
pub fn BinaryOp::add_int32() -> BinaryOp {
  AddInt32
}

///|
pub fn BinaryOp::add_int64() -> BinaryOp {
  AddInt64
}

///|
pub fn BinaryOp::sub_int32() -> BinaryOp {
  SubInt32
}

///|
pub fn BinaryOp::sub_int64() -> BinaryOp {
  SubInt64
}

///|
pub fn BinaryOp::mul_int32() -> BinaryOp {
  MulInt32
}

///|
pub fn BinaryOp::mul_int64() -> BinaryOp {
  MulInt64
}

///|
pub fn BinaryOp::div_s_int32() -> BinaryOp {
  DivSInt32
}

///|
pub fn BinaryOp::div_s_int64() -> BinaryOp {
  DivSInt64
}

///|
pub fn BinaryOp::div_u_int32() -> BinaryOp {
  DivUInt32
}

///|
pub fn BinaryOp::div_u_int64() -> BinaryOp {
  DivUInt64
}

///|
pub fn BinaryOp::rem_s_int32() -> BinaryOp {
  RemSInt32
}

///|
pub fn BinaryOp::rem_s_int64() -> BinaryOp {
  RemSInt64
}

///|
pub fn BinaryOp::rem_u_int32() -> BinaryOp {
  RemUInt32
}

///|
pub fn BinaryOp::rem_u_int64() -> BinaryOp {
  RemUInt64
}

///|
pub fn BinaryOp::and_int32() -> BinaryOp {
  AndInt32
}

///|
pub fn BinaryOp::and_int64() -> BinaryOp {
  AndInt64
}

///|
pub fn BinaryOp::or_int32() -> BinaryOp {
  OrInt32
}

///|
pub fn BinaryOp::or_int64() -> BinaryOp {
  OrInt64
}

///|
pub fn BinaryOp::xor_int32() -> BinaryOp {
  XorInt32
}

///|
pub fn BinaryOp::xor_int64() -> BinaryOp {
  XorInt64
}

///|
pub fn BinaryOp::shl_int32() -> BinaryOp {
  ShlInt32
}

///|
pub fn BinaryOp::shl_int64() -> BinaryOp {
  ShlInt64
}

///|
pub fn BinaryOp::shr_u_int32() -> BinaryOp {
  ShrUInt32
}

///|
pub fn BinaryOp::shr_u_int64() -> BinaryOp {
  ShrUInt64
}

///|
pub fn BinaryOp::shr_s_int32() -> BinaryOp {
  ShrSInt32
}

///|
pub fn BinaryOp::shr_s_int64() -> BinaryOp {
  ShrSInt64
}

///|
pub fn BinaryOp::rot_l_int32() -> BinaryOp {
  RotLInt32
}

///|
pub fn BinaryOp::rot_l_int64() -> BinaryOp {
  RotLInt64
}

///|
pub fn BinaryOp::rot_r_int32() -> BinaryOp {
  RotRInt32
}

///|
pub fn BinaryOp::rot_r_int64() -> BinaryOp {
  RotRInt64
}

///|
pub fn BinaryOp::eq_int32() -> BinaryOp {
  EqInt32
}

///|
pub fn BinaryOp::eq_int64() -> BinaryOp {
  EqInt64
}

///|
pub fn BinaryOp::ne_int32() -> BinaryOp {
  NeInt32
}

///|
pub fn BinaryOp::ne_int64() -> BinaryOp {
  NeInt64
}

///|
pub fn BinaryOp::lt_s_int32() -> BinaryOp {
  LtSInt32
}

///|
pub fn BinaryOp::lt_s_int64() -> BinaryOp {
  LtSInt64
}

///|
pub fn BinaryOp::lt_u_int32() -> BinaryOp {
  LtUInt32
}

///|
pub fn BinaryOp::lt_u_int64() -> BinaryOp {
  LtUInt64
}

///|
pub fn BinaryOp::le_s_int32() -> BinaryOp {
  LeSInt32
}

///|
pub fn BinaryOp::le_s_int64() -> BinaryOp {
  LeSInt64
}

///|
pub fn BinaryOp::le_u_int32() -> BinaryOp {
  LeUInt32
}

///|
pub fn BinaryOp::le_u_int64() -> BinaryOp {
  LeUInt64
}

///|
pub fn BinaryOp::gt_s_int32() -> BinaryOp {
  GtSInt32
}

///|
pub fn BinaryOp::gt_s_int64() -> BinaryOp {
  GtSInt64
}

///|
pub fn BinaryOp::gt_u_int32() -> BinaryOp {
  GtUInt32
}

///|
pub fn BinaryOp::gt_u_int64() -> BinaryOp {
  GtUInt64
}

///|
pub fn BinaryOp::ge_s_int32() -> BinaryOp {
  GeSInt32
}

///|
pub fn BinaryOp::ge_s_int64() -> BinaryOp {
  GeSInt64
}

///|
pub fn BinaryOp::ge_u_int32() -> BinaryOp {
  GeUInt32
}

///|
pub fn BinaryOp::ge_u_int64() -> BinaryOp {
  GeUInt64
}

///|
pub fn BinaryOp::add_float32() -> BinaryOp {
  AddFloat32
}

///|
pub fn BinaryOp::add_float64() -> BinaryOp {
  AddFloat64
}

///|
pub fn BinaryOp::sub_float32() -> BinaryOp {
  SubFloat32
}

///|
pub fn BinaryOp::sub_float64() -> BinaryOp {
  SubFloat64
}

///|
pub fn BinaryOp::mul_float32() -> BinaryOp {
  MulFloat32
}

///|
pub fn BinaryOp::mul_float64() -> BinaryOp {
  MulFloat64
}

///|
pub fn BinaryOp::div_float32() -> BinaryOp {
  DivFloat32
}

///|
pub fn BinaryOp::div_float64() -> BinaryOp {
  DivFloat64
}

///|
pub fn BinaryOp::min_float32() -> BinaryOp {
  MinFloat32
}

///|
pub fn BinaryOp::max_float32() -> BinaryOp {
  MaxFloat32
}

///|
pub fn BinaryOp::copysign_float32() -> BinaryOp {
  CopysignFloat32
}

///|
pub fn BinaryOp::eq_float32() -> BinaryOp {
  EqFloat32
}

///|
pub fn BinaryOp::ne_float32() -> BinaryOp {
  NeFloat32
}

///|
pub fn BinaryOp::lt_float32() -> BinaryOp {
  LtFloat32
}

///|
pub fn BinaryOp::le_float32() -> BinaryOp {
  LeFloat32
}

///|
pub fn BinaryOp::gt_float32() -> BinaryOp {
  GtFloat32
}

///|
pub fn BinaryOp::ge_float32() -> BinaryOp {
  GeFloat32
}

///|
pub fn BinaryOp::min_float64() -> BinaryOp {
  MinFloat64
}

///|
pub fn BinaryOp::max_float64() -> BinaryOp {
  MaxFloat64
}

///|
pub fn BinaryOp::copysign_float64() -> BinaryOp {
  CopysignFloat64
}

///|
pub fn BinaryOp::eq_float64() -> BinaryOp {
  EqFloat64
}

///|
pub fn BinaryOp::ne_float64() -> BinaryOp {
  NeFloat64
}

///|
pub fn BinaryOp::lt_float64() -> BinaryOp {
  LtFloat64
}

///|
pub fn BinaryOp::le_float64() -> BinaryOp {
  LeFloat64
}

///|
pub fn BinaryOp::gt_float64() -> BinaryOp {
  GtFloat64
}

///|
pub fn BinaryOp::ge_float64() -> BinaryOp {
  GeFloat64
}

///|
pub fn BinaryOp::is_relational(self : BinaryOp) -> Bool {
  match self {
    EqInt32
    | EqInt64
    | NeInt32
    | NeInt64
    | LtSInt32
    | LtSInt64
    | LtUInt32
    | LtUInt64
    | LeSInt32
    | LeSInt64
    | LeUInt32
    | LeUInt64
    | GtSInt32
    | GtSInt64
    | GtUInt32
    | GtUInt64
    | GeSInt32
    | GeSInt64
    | GeUInt32
    | GeUInt64 => true
    _ => false
  }
}

///|
pub fn BinaryOp::get_opposite(self : BinaryOp) -> BinaryOp? {
  match self {
    GtSInt32 => Some(LtSInt32)
    GtSInt64 => Some(LtSInt64)
    GeSInt32 => Some(LeSInt32)
    GeSInt64 => Some(LeSInt64)
    GtUInt32 => Some(LtUInt32)
    GtUInt64 => Some(LtUInt64)
    GeUInt32 => Some(LeUInt32)
    GeUInt64 => Some(LeUInt64)
    _ => None
  }
}

///|
/// Unary operations
pub enum UnaryOp {
  ClzInt32
  ClzInt64
  CtzInt32
  CtzInt64
  PopcntInt32
  PopcntInt64
  EqZInt32
  EqZInt64
  ExtendSInt32
  ExtendUInt32
  WrapInt64
  NegFloat32
  NegFloat64
  AbsFloat32
  AbsFloat64
  SqrtFloat32
  CeilFloat32
  FloorFloat32
  TruncFloat32
  NearestFloat32
  SqrtFloat64
  CeilFloat64
  FloorFloat64
  TruncFloat64
  NearestFloat64
  TruncSFloat32ToInt32
  TruncUFloat32ToInt32
  TruncSFloat64ToInt32
  TruncUFloat64ToInt32
  TruncSFloat32ToInt64
  TruncUFloat32ToInt64
  TruncSFloat64ToInt64
  TruncUFloat64ToInt64
  ConvertSInt32ToFloat32
  ConvertUInt32ToFloat32
  ConvertSInt64ToFloat32
  ConvertUInt64ToFloat32
  ConvertSInt32ToFloat64
  ConvertUInt32ToFloat64
  ConvertSInt64ToFloat64
  ConvertUInt64ToFloat64
  PromoteFloat32
  DemoteFloat64
  ReinterpretFloat32
  ReinterpretFloat64
  ReinterpretInt32
  ReinterpretInt64
} derive(Eq, Show)

///|
pub fn UnaryOp::clz_int32() -> UnaryOp {
  ClzInt32
}

///|
pub fn UnaryOp::clz_int64() -> UnaryOp {
  ClzInt64
}

///|
pub fn UnaryOp::ctz_int32() -> UnaryOp {
  CtzInt32
}

///|
pub fn UnaryOp::ctz_int64() -> UnaryOp {
  CtzInt64
}

///|
pub fn UnaryOp::popcnt_int32() -> UnaryOp {
  PopcntInt32
}

///|
pub fn UnaryOp::popcnt_int64() -> UnaryOp {
  PopcntInt64
}

///|
pub fn UnaryOp::eq_z_int32() -> UnaryOp {
  EqZInt32
}

///|
pub fn UnaryOp::eq_z_int64() -> UnaryOp {
  EqZInt64
}

///|
pub fn UnaryOp::extend_s_int32() -> UnaryOp {
  ExtendSInt32
}

///|
pub fn UnaryOp::extend_u_int32() -> UnaryOp {
  ExtendUInt32
}

///|
pub fn UnaryOp::wrap_int64() -> UnaryOp {
  WrapInt64
}

///|
pub fn UnaryOp::neg_float32() -> UnaryOp {
  NegFloat32
}

///|
pub fn UnaryOp::neg_float64() -> UnaryOp {
  NegFloat64
}

///|
pub fn UnaryOp::abs_float32() -> UnaryOp {
  AbsFloat32
}

///|
pub fn UnaryOp::abs_float64() -> UnaryOp {
  AbsFloat64
}

///|
pub fn UnaryOp::sqrt_float32() -> UnaryOp {
  SqrtFloat32
}

///|
pub fn UnaryOp::ceil_float32() -> UnaryOp {
  CeilFloat32
}

///|
pub fn UnaryOp::floor_float32() -> UnaryOp {
  FloorFloat32
}

///|
pub fn UnaryOp::trunc_float32() -> UnaryOp {
  TruncFloat32
}

///|
pub fn UnaryOp::nearest_float32() -> UnaryOp {
  NearestFloat32
}

///|
pub fn UnaryOp::sqrt_float64() -> UnaryOp {
  SqrtFloat64
}

///|
pub fn UnaryOp::ceil_float64() -> UnaryOp {
  CeilFloat64
}

///|
pub fn UnaryOp::floor_float64() -> UnaryOp {
  FloorFloat64
}

///|
pub fn UnaryOp::trunc_float64() -> UnaryOp {
  TruncFloat64
}

///|
pub fn UnaryOp::nearest_float64() -> UnaryOp {
  NearestFloat64
}

///|
pub fn UnaryOp::trunc_s_float32_to_int32() -> UnaryOp {
  TruncSFloat32ToInt32
}

///|
pub fn UnaryOp::trunc_u_float32_to_int32() -> UnaryOp {
  TruncUFloat32ToInt32
}

///|
pub fn UnaryOp::trunc_s_float64_to_int32() -> UnaryOp {
  TruncSFloat64ToInt32
}

///|
pub fn UnaryOp::trunc_u_float64_to_int32() -> UnaryOp {
  TruncUFloat64ToInt32
}

///|
pub fn UnaryOp::trunc_s_float32_to_int64() -> UnaryOp {
  TruncSFloat32ToInt64
}

///|
pub fn UnaryOp::trunc_u_float32_to_int64() -> UnaryOp {
  TruncUFloat32ToInt64
}

///|
pub fn UnaryOp::trunc_s_float64_to_int64() -> UnaryOp {
  TruncSFloat64ToInt64
}

///|
pub fn UnaryOp::trunc_u_float64_to_int64() -> UnaryOp {
  TruncUFloat64ToInt64
}

///|
pub fn UnaryOp::convert_s_int32_to_float32() -> UnaryOp {
  ConvertSInt32ToFloat32
}

///|
pub fn UnaryOp::convert_u_int32_to_float32() -> UnaryOp {
  ConvertUInt32ToFloat32
}

///|
pub fn UnaryOp::convert_s_int64_to_float32() -> UnaryOp {
  ConvertSInt64ToFloat32
}

///|
pub fn UnaryOp::convert_u_int64_to_float32() -> UnaryOp {
  ConvertUInt64ToFloat32
}

///|
pub fn UnaryOp::convert_s_int32_to_float64() -> UnaryOp {
  ConvertSInt32ToFloat64
}

///|
pub fn UnaryOp::convert_u_int32_to_float64() -> UnaryOp {
  ConvertUInt32ToFloat64
}

///|
pub fn UnaryOp::convert_s_int64_to_float64() -> UnaryOp {
  ConvertSInt64ToFloat64
}

///|
pub fn UnaryOp::convert_u_int64_to_float64() -> UnaryOp {
  ConvertUInt64ToFloat64
}

///|
pub fn UnaryOp::promote_float32() -> UnaryOp {
  PromoteFloat32
}

///|
pub fn UnaryOp::demote_float64() -> UnaryOp {
  DemoteFloat64
}

///|
pub fn UnaryOp::reinterpret_float32() -> UnaryOp {
  ReinterpretFloat32
}

///|
pub fn UnaryOp::reinterpret_float64() -> UnaryOp {
  ReinterpretFloat64
}

///|
pub fn UnaryOp::reinterpret_int32() -> UnaryOp {
  ReinterpretInt32
}

///|
pub fn UnaryOp::reinterpret_int64() -> UnaryOp {
  ReinterpretInt64
}

///|
pub fn UnaryOp::is_relational(self : UnaryOp) -> Bool {
  match self {
    EqZInt32 | EqZInt64 => true
    _ => false
  }
}

///|
/// Literal values
pub enum Literal {
  LitI32(Int)
  LitI64(Int64)
  LitF32(Float)
  LitF64(Double)
} derive(Eq, Hash, Show)

///|
pub fn Literal::i32(val : Int) -> Literal {
  LitI32(val)
}

///|
pub fn Literal::i64(val : Int64) -> Literal {
  LitI64(val)
}

///|
pub fn Literal::f32(val : Float) -> Literal {
  LitF32(val)
}

///|
pub fn Literal::f64(val : Double) -> Literal {
  LitF64(val)
}

///|
pub fn Literal::make_zero(wasm_type : WasmType) -> Literal {
  match wasm_type {
    I32 => LitI32(0)
    I64 => LitI64(0L)
    F32 => LitF32(0.0)
    F64 => LitF64(0.0)
    _ => LitI32(0) // fallback
  }
}

///|
pub fn Literal::get_type(self : Literal) -> WasmType {
  match self {
    LitI32(_) => I32
    LitI64(_) => I64
    LitF32(_) => F32
    LitF64(_) => F64
  }
}

///|
pub fn Literal::to_tinstr(self : Literal) -> @lib.TInstr {
  match self {
    LitI32(x) => @lib.TInstr::i32_const(x)
    LitI64(x) => @lib.TInstr::i64_const(x)
    LitF32(x) => @lib.TInstr::f32_const(x)
    LitF64(x) => @lib.TInstr::f64_const(x)
  }
}
