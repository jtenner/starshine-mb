///|
pub enum LiteralType {
  Int
  Float
  Hexfloat
  Infinity
  Nan
} derive(Eq, Show, Debug)

///|
pub enum ErrorLevel {
  Error
} derive(Eq, Show, Debug)

// ============================================================================
// Core Structures
// ============================================================================

///|
pub struct Location {
  filename : String
  line : Int
  first_column : Int
  last_column : Int
} derive(Eq, Show, Debug)

///|
pub struct Literal {
  literal_type : LiteralType
  text : String
} derive(Eq, Show, Debug)

///|
pub struct Token {
  location : Location
  token_type : TokenType
  value : TokenValue
} derive(Eq, Show, Debug)

///|
pub struct LexerError {
  level : ErrorLevel
  location : Location
  message : String
} derive(Eq, Show, Debug)

///|
priv enum ReservedChars {
  None
  Id
  Some
}

///|
pub enum ValueType {
  I32
  I64
  F32
  F64
  V128
  FuncRef
  ExternRef
  ExnRef
} derive(Eq, Show, Debug)

// ============================================================================
// opcode.mbt - Complete Opcode Enumeration for WASM 3.0
// ============================================================================

///|
pub enum Opcode {
  // ========== Control Instructions ==========
  Unreachable
  Nop
  Br
  BrIf
  BrTable
  Return
  Call
  CallIndirect
  Throw
  ThrowRef
  TryTable

  // ========== Reference Instructions ==========
  RefNull
  RefIsNull
  RefFunc
  RefEq
  RefAsNonNull
  AnyConvertExtern
  ExternConvertAny
  RefI31
  I31GetS
  I31GetU
  RefGetDesc
  RefTestDesc
  RefTestDescNull
  RefCastDescEq
  RefCastDescEqNull
  RefExtern // For test results

  // ========== Parametric Instructions ==========
  Drop
  Select

  // ========== Variable Instructions ==========
  LocalGet
  LocalSet
  LocalTee
  GlobalGet
  GlobalSet

  // ========== Table Instructions ==========
  TableGet
  TableSet
  TableSize
  TableGrow
  TableFill
  TableCopy
  TableInit
  ElemDrop

  // ========== Memory Instructions ==========
  I32Load
  I64Load
  F32Load
  F64Load
  I32Load8S
  I32Load8U
  I32Load16S
  I32Load16U
  I64Load8S
  I64Load8U
  I64Load16S
  I64Load16U
  I64Load32S
  I64Load32U
  I32Store
  I64Store
  F32Store
  F64Store
  I32Store8
  I32Store16
  I64Store8
  I64Store16
  I64Store32
  MemorySize
  MemoryGrow
  MemoryFill
  MemoryCopy
  MemoryInit
  DataDrop

  // ========== Numeric Instructions - Constants ==========
  I32Const
  I64Const
  F32Const
  F64Const

  // ========== i32 Operations ==========
  I32Eqz
  I32Eq
  I32Ne
  I32LtS
  I32LtU
  I32GtS
  I32GtU
  I32LeS
  I32LeU
  I32GeS
  I32GeU
  I32Clz
  I32Ctz
  I32Popcnt
  I32Add
  I32Sub
  I32Mul
  I32DivS
  I32DivU
  I32RemS
  I32RemU
  I32And
  I32Or
  I32Xor
  I32Shl
  I32ShrS
  I32ShrU
  I32Rotl
  I32Rotr

  // ========== i64 Operations ==========
  I64Eqz
  I64Eq
  I64Ne
  I64LtS
  I64LtU
  I64GtS
  I64GtU
  I64LeS
  I64LeU
  I64GeS
  I64GeU
  I64Clz
  I64Ctz
  I64Popcnt
  I64Add
  I64Sub
  I64Mul
  I64DivS
  I64DivU
  I64RemS
  I64RemU
  I64And
  I64Or
  I64Xor
  I64Shl
  I64ShrS
  I64ShrU
  I64Rotl
  I64Rotr

  // ========== f32 Operations ==========
  F32Eq
  F32Ne
  F32Lt
  F32Gt
  F32Le
  F32Ge
  F32Abs
  F32Neg
  F32Ceil
  F32Floor
  F32Trunc
  F32Nearest
  F32Sqrt
  F32Add
  F32Sub
  F32Mul
  F32Div
  F32Min
  F32Max
  F32Copysign

  // ========== f64 Operations ==========
  F64Eq
  F64Ne
  F64Lt
  F64Gt
  F64Le
  F64Ge
  F64Abs
  F64Neg
  F64Ceil
  F64Floor
  F64Trunc
  F64Nearest
  F64Sqrt
  F64Add
  F64Sub
  F64Mul
  F64Div
  F64Min
  F64Max
  F64Copysign

  // ========== Conversion Operations ==========
  I32WrapI64
  I32TruncF32S
  I32TruncF32U
  I32TruncF64S
  I32TruncF64U
  I64ExtendI32S
  I64ExtendI32U
  I64TruncF32S
  I64TruncF32U
  I64TruncF64S
  I64TruncF64U
  F32ConvertI32S
  F32ConvertI32U
  F32ConvertI64S
  F32ConvertI64U
  F32DemoteF64
  F64ConvertI32S
  F64ConvertI32U
  F64ConvertI64S
  F64ConvertI64U
  F64PromoteF32
  I32ReinterpretF32
  I64ReinterpretF64
  F32ReinterpretI32
  F64ReinterpretI64

  // ========== Sign Extension Operations ==========
  I32Extend8S
  I32Extend16S
  I64Extend8S
  I64Extend16S
  I64Extend32S

  // ========== Saturating Truncation Operations ==========
  I32TruncSatF32S
  I32TruncSatF32U
  I32TruncSatF64S
  I32TruncSatF64U
  I64TruncSatF32S
  I64TruncSatF32U
  I64TruncSatF64S
  I64TruncSatF64U

  // ========== SIMD - V128 Const and Memory ==========
  V128Const
  V128Load
  V128Load8x8S
  V128Load8x8U
  V128Load16x4S
  V128Load16x4U
  V128Load32x2S
  V128Load32x2U
  V128Load8Splat
  V128Load16Splat
  V128Load32Splat
  V128Load64Splat
  V128Load32Zero
  V128Load64Zero
  V128Store
  V128Load8Lane
  V128Load16Lane
  V128Load32Lane
  V128Load64Lane
  V128Store8Lane
  V128Store16Lane
  V128Store32Lane
  V128Store64Lane

  // ========== SIMD - V128 Shuffle and Swizzle ==========
  I8x16Shuffle
  I8x16Swizzle

  // ========== SIMD - i8x16 Operations ==========
  I8x16Splat
  I8x16ExtractLaneS
  I8x16ExtractLaneU
  I8x16ReplaceLane
  I8x16Eq
  I8x16Ne
  I8x16LtS
  I8x16LtU
  I8x16GtS
  I8x16GtU
  I8x16LeS
  I8x16LeU
  I8x16GeS
  I8x16GeU
  I8x16Abs
  I8x16Neg
  I8x16Popcnt
  I8x16AllTrue
  I8x16Bitmask
  I8x16NarrowI16x8S
  I8x16NarrowI16x8U
  I8x16Shl
  I8x16ShrS
  I8x16ShrU
  I8x16Add
  I8x16AddSatS
  I8x16AddSatU
  I8x16Sub
  I8x16SubSatS
  I8x16SubSatU
  I8x16MinS
  I8x16MinU
  I8x16MaxS
  I8x16MaxU
  I8x16AvgrU

  // ========== SIMD - i16x8 Operations ==========
  I16x8Splat
  I16x8ExtractLaneS
  I16x8ExtractLaneU
  I16x8ReplaceLane
  I16x8Eq
  I16x8Ne
  I16x8LtS
  I16x8LtU
  I16x8GtS
  I16x8GtU
  I16x8LeS
  I16x8LeU
  I16x8GeS
  I16x8GeU
  I16x8Abs
  I16x8Neg
  I16x8Q15mulrSatS
  I16x8AllTrue
  I16x8Bitmask
  I16x8NarrowI32x4S
  I16x8NarrowI32x4U
  I16x8ExtendLowI8x16S
  I16x8ExtendHighI8x16S
  I16x8ExtendLowI8x16U
  I16x8ExtendHighI8x16U
  I16x8Shl
  I16x8ShrS
  I16x8ShrU
  I16x8Add
  I16x8AddSatS
  I16x8AddSatU
  I16x8Sub
  I16x8SubSatS
  I16x8SubSatU
  I16x8Mul
  I16x8MinS
  I16x8MinU
  I16x8MaxS
  I16x8MaxU
  I16x8AvgrU
  I16x8ExtmulLowI8x16S
  I16x8ExtmulHighI8x16S
  I16x8ExtmulLowI8x16U
  I16x8ExtmulHighI8x16U

  // ========== SIMD - i32x4 Operations ==========
  I32x4Splat
  I32x4ExtractLane
  I32x4ReplaceLane
  I32x4Eq
  I32x4Ne
  I32x4LtS
  I32x4LtU
  I32x4GtS
  I32x4GtU
  I32x4LeS
  I32x4LeU
  I32x4GeS
  I32x4GeU
  I32x4Abs
  I32x4Neg
  I32x4AllTrue
  I32x4Bitmask
  I32x4ExtendLowI16x8S
  I32x4ExtendHighI16x8S
  I32x4ExtendLowI16x8U
  I32x4ExtendHighI16x8U
  I32x4Shl
  I32x4ShrS
  I32x4ShrU
  I32x4Add
  I32x4Sub
  I32x4Mul
  I32x4MinS
  I32x4MinU
  I32x4MaxS
  I32x4MaxU
  I32x4DotI16x8S
  I32x4ExtmulLowI16x8S
  I32x4ExtmulHighI16x8S
  I32x4ExtmulLowI16x8U
  I32x4ExtmulHighI16x8U
  I32x4TruncSatF32x4S
  I32x4TruncSatF32x4U
  I32x4TruncSatF64x2SZero
  I32x4TruncSatF64x2UZero

  // ========== SIMD - i64x2 Operations ==========
  I64x2Splat
  I64x2ExtractLane
  I64x2ReplaceLane
  I64x2Eq
  I64x2Ne
  I64x2LtS
  I64x2GtS
  I64x2LeS
  I64x2GeS
  I64x2Abs
  I64x2Neg
  I64x2AllTrue
  I64x2Bitmask
  I64x2ExtendLowI32x4S
  I64x2ExtendHighI32x4S
  I64x2ExtendLowI32x4U
  I64x2ExtendHighI32x4U
  I64x2Shl
  I64x2ShrS
  I64x2ShrU
  I64x2Add
  I64x2Sub
  I64x2Mul
  I64x2ExtmulLowI32x4S
  I64x2ExtmulHighI32x4S
  I64x2ExtmulLowI32x4U
  I64x2ExtmulHighI32x4U

  // ========== SIMD - f32x4 Operations ==========
  F32x4Splat
  F32x4ExtractLane
  F32x4ReplaceLane
  F32x4Eq
  F32x4Ne
  F32x4Lt
  F32x4Gt
  F32x4Le
  F32x4Ge
  F32x4Abs
  F32x4Neg
  F32x4Sqrt
  F32x4Add
  F32x4Sub
  F32x4Mul
  F32x4Div
  F32x4Min
  F32x4Max
  F32x4Pmin
  F32x4Pmax
  F32x4Ceil
  F32x4Floor
  F32x4Trunc
  F32x4Nearest
  F32x4ConvertI32x4S
  F32x4ConvertI32x4U
  F32x4DemoteF64x2Zero

  // ========== SIMD - f64x2 Operations ==========
  F64x2Splat
  F64x2ExtractLane
  F64x2ReplaceLane
  F64x2Eq
  F64x2Ne
  F64x2Lt
  F64x2Gt
  F64x2Le
  F64x2Ge
  F64x2Abs
  F64x2Neg
  F64x2Sqrt
  F64x2Add
  F64x2Sub
  F64x2Mul
  F64x2Div
  F64x2Min
  F64x2Max
  F64x2Pmin
  F64x2Pmax
  F64x2Ceil
  F64x2Floor
  F64x2Trunc
  F64x2Nearest
  F64x2ConvertLowI32x4S
  F64x2ConvertLowI32x4U
  F64x2PromoteLowF32x4

  // ========== SIMD - V128 Bitwise Operations ==========
  V128Not
  V128And
  V128AndNot
  V128Or
  V128Xor
  V128Bitselect
  V128AnyTrue

  // ========== Relaxed SIMD (WASM 3.0) ==========
  I8x16RelaxedSwizzle
  I32x4RelaxedTruncF32x4S
  I32x4RelaxedTruncF32x4U
  I32x4RelaxedTruncF64x2SZero
  I32x4RelaxedTruncF64x2UZero
  F32x4RelaxedMadd
  F32x4RelaxedNmadd
  F64x2RelaxedMadd
  F64x2RelaxedNmadd
  I8x16RelaxedLaneselect
  I16x8RelaxedLaneselect
  I32x4RelaxedLaneselect
  I64x2RelaxedLaneselect
  F32x4RelaxedMin
  F32x4RelaxedMax
  F64x2RelaxedMin
  F64x2RelaxedMax
  I16x8RelaxedQ15mulrS
  I16x8RelaxedDotI8x16I7x16S
  I32x4RelaxedDotI8x16I7x16AddS
} derive(Eq, Show, Debug)

///|
pub enum TokenType {
  Eof
  Lpar
  Rpar
  LparAnn
  Nat
  Int
  Float
  Text
  Var
  Reserved
  Invalid
  // Module structure
  Module
  Type
  Func
  Param
  Result
  Local
  Global
  Tag
  Table
  Memory
  Import
  Export
  // Types
  ValueType(ValueType)
  // Instructions
  Opcode(Opcode)
  // Control keywords
  Block
  Loop
  If
  Then
  Else
  End
  Catch
  CatchRef
  CatchAll
  CatchAllRef
  // Other module keywords
  Offset
  Item
  Start
  Data
  Elem
  Mut

  // Additional script tokens
  Binary
  Quote
  Input
  Output
  Register
  Invoke
  Get
  Declare
  AssertMalformed
  AssertInvalid
  AssertUnlinkable
  AssertReturn
  AssertTrap
  AssertExhaustion
  NanCanonical
  NanArithmetic

  // Memory arg tokens
  OffsetEqNat // offset=N
  AlignEqNat // align=N
  SimdShapeToken(SimdShape)
} derive(Eq, Show, Debug)

///|
pub enum TokenValue {
  None
  Text(String)
  Literal(Literal)
  ValueType(ValueType)
  Opcode(Opcode)
} derive(Eq, Show, Debug)

// ============================================================================
// WastLexer
// ============================================================================

///|
pub struct WastLexer {
  buffer : Bytes
  filename : String
  mut line : Int
  mut cursor : Int
  mut line_start : Int
  mut token_start : Int
  errors : Array[LexerError]
}
