///|
pub enum LiteralType {
  Int
  Float
  Hexfloat
  Infinity
  Nan
} derive(Eq, Debug)

///|
pub impl Show for LiteralType with fn output(self, logger) {
  match self {
    Int => logger.write_string("Int")
    Float => logger.write_string("Float")
    Hexfloat => logger.write_string("Hexfloat")
    Infinity => logger.write_string("Infinity")
    Nan => logger.write_string("Nan")
  }
}

///|
pub enum ErrorLevel {
  Error
} derive(Eq, Debug)

///|
pub impl Show for ErrorLevel with fn output(_self, logger) {
  logger.write_string("Error")
}

// ============================================================================
// Core Structures
// ============================================================================

///|
pub struct Location {
  filename : String
  line : Int
  first_column : Int
  last_column : Int
} derive(Eq, Debug)

///|
pub impl Show for Location with fn output(self, logger) {
  logger.write_string("Location {filename: ")
  self.filename.output(logger)
  logger.write_string(", line: ")
  self.line.output(logger)
  logger.write_string(", first_column: ")
  self.first_column.output(logger)
  logger.write_string(", last_column: ")
  self.last_column.output(logger)
  logger.write_char('}')
}

///|
pub struct Literal {
  literal_type : LiteralType
  text : String
} derive(Eq, Debug)

///|
pub impl Show for Literal with fn output(self, logger) {
  logger.write_string("Location {literal_type: ")
  self.literal_type.output(logger)
  logger.write_string(", text: ")
  self.text.output(logger)
  logger.write_char('}')
}

///|
pub struct Token {
  location : Location
  token_type : TokenType
  value : TokenValue
} derive(Eq, Debug)

///|
pub impl Show for Token with fn output(self, logger) {
  logger.write_string("Token {location: ")
  self.location.output(logger)
  logger.write_string(", token_type:")
  self.token_type.output(logger)
  logger.write_string(", value:")
  self.value.output(logger)
  logger.write_char('}')
}

///|
pub struct LexerError {
  level : ErrorLevel
  location : Location
  message : String
} derive(Eq, Debug)

///|
pub impl Show for LexerError with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
priv enum ReservedChars {
  None
  Id
  Some
}

///|
pub enum HeapTypeRef {
  TypeNum(UInt)
  TypeId(String)
  ExactTypeNum(UInt)
  ExactTypeId(String)
  Any
  String
  Eq
  I31
  Struct
  Array
  None_
  NoFunc
  NoExtern
  NoExn
} derive(Eq, Debug)

///|
pub impl Show for HeapTypeRef with fn output(self, logger) {
  match self {
    TypeNum(val) => {
      logger.write_string("TypeNum(")
      val.output(logger)
      logger.write_char(')')
    }
    TypeId(val) => {
      logger.write_string("TypeId(")
      val.output(logger)
      logger.write_char(')')
    }
    ExactTypeNum(val) => {
      logger.write_string("ExactTypeNum(")
      val.output(logger)
      logger.write_char(')')
    }
    ExactTypeId(val) => {
      logger.write_string("ExactTypeId(")
      val.output(logger)
      logger.write_char(')')
    }
    Any => logger.write_string("Any")
    String => logger.write_string("String")
    Eq => logger.write_string("Eq")
    I31 => logger.write_string("I31")
    Struct => logger.write_string("Struct")
    Array => logger.write_string("Array")
    None_ => logger.write_string("None_")
    NoFunc => logger.write_string("NoFunc")
    NoExtern => logger.write_string("NoExtern")
    NoExn => logger.write_string("NoExn")
  }
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
  NonNullFuncRef
  NonNullExternRef
  NonNullExnRef
  TypedFuncRef(HeapTypeRef)
  NonNullTypedFuncRef(HeapTypeRef)
} derive(Eq, Debug)

///|
pub impl Show for ValueType with fn output(self, logger) {
  match self {
    I32 => logger.write_string("I32")
    I64 => logger.write_string("I64")
    F32 => logger.write_string("F32")
    F64 => logger.write_string("F64")
    V128 => logger.write_string("V128")
    FuncRef => logger.write_string("FuncRef")
    ExternRef => logger.write_string("ExternRef")
    ExnRef => logger.write_string("ExnRef")
    NonNullFuncRef => logger.write_string("NonNullFuncRef")
    NonNullExternRef => logger.write_string("NonNullExternRef")
    NonNullExnRef => logger.write_string("NonNullExnRef")
    TypedFuncRef(htr) => {
      logger.write_string("TypedFuncRef(")
      htr.output(logger)
      logger.write_char(')')
    }
    NonNullTypedFuncRef(htr) => {
      logger.write_string("NonNullTypedFuncRef(")
      htr.output(logger)
      logger.write_char(')')
    }
  }
}

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
  ReturnCall
  ReturnCallIndirect
  ReturnCallRef
  Throw
  ThrowRef
  TryTable

  // ========== Reference Instructions ==========
  RefNull
  RefIsNull
  RefFunc
  RefEq
  RefAsNonNull
  StringConst
  StringNewUtf8Array
  StringNewWtf16Array
  StringEncodeUtf8Array
  StringEncodeWtf16Array
  StringNewLossyUtf8Array
  StringNewWtf8Array
  StringEncodeLossyUtf8Array
  StringEncodeWtf8Array
  AnyConvertExtern
  ExternConvertAny
  RefI31
  I31GetS
  I31GetU
  StructNew
  StructNewDefault
  StructGet
  StructGetS
  StructGetU
  StructAtomicGet
  StructAtomicGetS
  StructAtomicGetU
  StructNewDesc
  StructNewDefaultDesc
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
} derive(Eq, Debug)

///|
pub impl Show for Opcode with fn output(self, logger) {
  match self {
    Unreachable => logger.write_string("Unreachable")
    Nop => logger.write_string("Nop")
    Br => logger.write_string("Br")
    BrIf => logger.write_string("BrIf")
    BrTable => logger.write_string("BrTable")
    Return => logger.write_string("Return")
    Call => logger.write_string("Call")
    CallIndirect => logger.write_string("CallIndirect")
    ReturnCall => logger.write_string("ReturnCall")
    ReturnCallIndirect => logger.write_string("ReturnCallIndirect")
    ReturnCallRef => logger.write_string("ReturnCallRef")
    Throw => logger.write_string("Throw")
    ThrowRef => logger.write_string("ThrowRef")
    TryTable => logger.write_string("TryTable")
    RefNull => logger.write_string("RefNull")
    RefIsNull => logger.write_string("RefIsNull")
    RefFunc => logger.write_string("RefFunc")
    RefEq => logger.write_string("RefEq")
    RefAsNonNull => logger.write_string("RefAsNonNull")
    StringConst => logger.write_string("StringConst")
    StringNewUtf8Array => logger.write_string("StringNewUtf8Array")
    StringNewWtf16Array => logger.write_string("StringNewWtf16Array")
    StringEncodeUtf8Array => logger.write_string("StringEncodeUtf8Array")
    StringEncodeWtf16Array => logger.write_string("StringEncodeWtf16Array")
    StringNewLossyUtf8Array => logger.write_string("StringNewLossyUtf8Array")
    StringNewWtf8Array => logger.write_string("StringNewWtf8Array")
    StringEncodeLossyUtf8Array =>
      logger.write_string("StringEncodeLossyUtf8Array")
    StringEncodeWtf8Array => logger.write_string("StringEncodeWtf8Array")
    AnyConvertExtern => logger.write_string("AnyConvertExtern")
    ExternConvertAny => logger.write_string("ExternConvertAny")
    RefI31 => logger.write_string("RefI31")
    I31GetS => logger.write_string("I31GetS")
    I31GetU => logger.write_string("I31GetU")
    StructNew => logger.write_string("StructNew")
    StructNewDefault => logger.write_string("StructNewDefault")
    StructGet => logger.write_string("StructGet")
    StructGetS => logger.write_string("StructGetS")
    StructGetU => logger.write_string("StructGetU")
    StructAtomicGet => logger.write_string("StructAtomicGet")
    StructAtomicGetS => logger.write_string("StructAtomicGetS")
    StructAtomicGetU => logger.write_string("StructAtomicGetU")
    StructNewDesc => logger.write_string("StructNewDesc")
    StructNewDefaultDesc => logger.write_string("StructNewDefaultDesc")
    RefGetDesc => logger.write_string("RefGetDesc")
    RefTestDesc => logger.write_string("RefTestDesc")
    RefTestDescNull => logger.write_string("RefTestDescNull")
    RefCastDescEq => logger.write_string("RefCastDescEq")
    RefCastDescEqNull => logger.write_string("RefCastDescEqNull")
    RefExtern => logger.write_string("RefExtern")
    Drop => logger.write_string("Drop")
    Select => logger.write_string("Select")
    LocalGet => logger.write_string("LocalGet")
    LocalSet => logger.write_string("LocalSet")
    LocalTee => logger.write_string("LocalTee")
    GlobalGet => logger.write_string("GlobalGet")
    GlobalSet => logger.write_string("GlobalSet")
    TableGet => logger.write_string("TableGet")
    TableSet => logger.write_string("TableSet")
    TableSize => logger.write_string("TableSize")
    TableGrow => logger.write_string("TableGrow")
    TableFill => logger.write_string("TableFill")
    TableCopy => logger.write_string("TableCopy")
    TableInit => logger.write_string("TableInit")
    ElemDrop => logger.write_string("ElemDrop")
    I32Load => logger.write_string("I32Load")
    I64Load => logger.write_string("I64Load")
    F32Load => logger.write_string("F32Load")
    F64Load => logger.write_string("F64Load")
    I32Load8S => logger.write_string("I32Load8S")
    I32Load8U => logger.write_string("I32Load8U")
    I32Load16S => logger.write_string("I32Load16S")
    I32Load16U => logger.write_string("I32Load16U")
    I64Load8S => logger.write_string("I64Load8S")
    I64Load8U => logger.write_string("I64Load8U")
    I64Load16S => logger.write_string("I64Load16S")
    I64Load16U => logger.write_string("I64Load16U")
    I64Load32S => logger.write_string("I64Load32S")
    I64Load32U => logger.write_string("I64Load32U")
    I32Store => logger.write_string("I32Store")
    I64Store => logger.write_string("I64Store")
    F32Store => logger.write_string("F32Store")
    F64Store => logger.write_string("F64Store")
    I32Store8 => logger.write_string("I32Store8")
    I32Store16 => logger.write_string("I32Store16")
    I64Store8 => logger.write_string("I64Store8")
    I64Store16 => logger.write_string("I64Store16")
    I64Store32 => logger.write_string("I64Store32")
    MemorySize => logger.write_string("MemorySize")
    MemoryGrow => logger.write_string("MemoryGrow")
    MemoryFill => logger.write_string("MemoryFill")
    MemoryCopy => logger.write_string("MemoryCopy")
    MemoryInit => logger.write_string("MemoryInit")
    DataDrop => logger.write_string("DataDrop")
    I32Const => logger.write_string("I32Const")
    I64Const => logger.write_string("I64Const")
    F32Const => logger.write_string("F32Const")
    F64Const => logger.write_string("F64Const")
    I32Eqz => logger.write_string("I32Eqz")
    I32Eq => logger.write_string("I32Eq")
    I32Ne => logger.write_string("I32Ne")
    I32LtS => logger.write_string("I32LtS")
    I32LtU => logger.write_string("I32LtU")
    I32GtS => logger.write_string("I32GtS")
    I32GtU => logger.write_string("I32GtU")
    I32LeS => logger.write_string("I32LeS")
    I32LeU => logger.write_string("I32LeU")
    I32GeS => logger.write_string("I32GeS")
    I32GeU => logger.write_string("I32GeU")
    I32Clz => logger.write_string("I32Clz")
    I32Ctz => logger.write_string("I32Ctz")
    I32Popcnt => logger.write_string("I32Popcnt")
    I32Add => logger.write_string("I32Add")
    I32Sub => logger.write_string("I32Sub")
    I32Mul => logger.write_string("I32Mul")
    I32DivS => logger.write_string("I32DivS")
    I32DivU => logger.write_string("I32DivU")
    I32RemS => logger.write_string("I32RemS")
    I32RemU => logger.write_string("I32RemU")
    I32And => logger.write_string("I32And")
    I32Or => logger.write_string("I32Or")
    I32Xor => logger.write_string("I32Xor")
    I32Shl => logger.write_string("I32Shl")
    I32ShrS => logger.write_string("I32ShrS")
    I32ShrU => logger.write_string("I32ShrU")
    I32Rotl => logger.write_string("I32Rotl")
    I32Rotr => logger.write_string("I32Rotr")
    I64Eqz => logger.write_string("I64Eqz")
    I64Eq => logger.write_string("I64Eq")
    I64Ne => logger.write_string("I64Ne")
    I64LtS => logger.write_string("I64LtS")
    I64LtU => logger.write_string("I64LtU")
    I64GtS => logger.write_string("I64GtS")
    I64GtU => logger.write_string("I64GtU")
    I64LeS => logger.write_string("I64LeS")
    I64LeU => logger.write_string("I64LeU")
    I64GeS => logger.write_string("I64GeS")
    I64GeU => logger.write_string("I64GeU")
    I64Clz => logger.write_string("I64Clz")
    I64Ctz => logger.write_string("I64Ctz")
    I64Popcnt => logger.write_string("I64Popcnt")
    I64Add => logger.write_string("I64Add")
    I64Sub => logger.write_string("I64Sub")
    I64Mul => logger.write_string("I64Mul")
    I64DivS => logger.write_string("I64DivS")
    I64DivU => logger.write_string("I64DivU")
    I64RemS => logger.write_string("I64RemS")
    I64RemU => logger.write_string("I64RemU")
    I64And => logger.write_string("I64And")
    I64Or => logger.write_string("I64Or")
    I64Xor => logger.write_string("I64Xor")
    I64Shl => logger.write_string("I64Shl")
    I64ShrS => logger.write_string("I64ShrS")
    I64ShrU => logger.write_string("I64ShrU")
    I64Rotl => logger.write_string("I64Rotl")
    I64Rotr => logger.write_string("I64Rotr")
    F32Eq => logger.write_string("F32Eq")
    F32Ne => logger.write_string("F32Ne")
    F32Lt => logger.write_string("F32Lt")
    F32Gt => logger.write_string("F32Gt")
    F32Le => logger.write_string("F32Le")
    F32Ge => logger.write_string("F32Ge")
    F32Abs => logger.write_string("F32Abs")
    F32Neg => logger.write_string("F32Neg")
    F32Ceil => logger.write_string("F32Ceil")
    F32Floor => logger.write_string("F32Floor")
    F32Trunc => logger.write_string("F32Trunc")
    F32Nearest => logger.write_string("F32Nearest")
    F32Sqrt => logger.write_string("F32Sqrt")
    F32Add => logger.write_string("F32Add")
    F32Sub => logger.write_string("F32Sub")
    F32Mul => logger.write_string("F32Mul")
    F32Div => logger.write_string("F32Div")
    F32Min => logger.write_string("F32Min")
    F32Max => logger.write_string("F32Max")
    F32Copysign => logger.write_string("F32Copysign")
    F64Eq => logger.write_string("F64Eq")
    F64Ne => logger.write_string("F64Ne")
    F64Lt => logger.write_string("F64Lt")
    F64Gt => logger.write_string("F64Gt")
    F64Le => logger.write_string("F64Le")
    F64Ge => logger.write_string("F64Ge")
    F64Abs => logger.write_string("F64Abs")
    F64Neg => logger.write_string("F64Neg")
    F64Ceil => logger.write_string("F64Ceil")
    F64Floor => logger.write_string("F64Floor")
    F64Trunc => logger.write_string("F64Trunc")
    F64Nearest => logger.write_string("F64Nearest")
    F64Sqrt => logger.write_string("F64Sqrt")
    F64Add => logger.write_string("F64Add")
    F64Sub => logger.write_string("F64Sub")
    F64Mul => logger.write_string("F64Mul")
    F64Div => logger.write_string("F64Div")
    F64Min => logger.write_string("F64Min")
    F64Max => logger.write_string("F64Max")
    F64Copysign => logger.write_string("F64Copysign")
    I32WrapI64 => logger.write_string("I32WrapI64")
    I32TruncF32S => logger.write_string("I32TruncF32S")
    I32TruncF32U => logger.write_string("I32TruncF32U")
    I32TruncF64S => logger.write_string("I32TruncF64S")
    I32TruncF64U => logger.write_string("I32TruncF64U")
    I64ExtendI32S => logger.write_string("I64ExtendI32S")
    I64ExtendI32U => logger.write_string("I64ExtendI32U")
    I64TruncF32S => logger.write_string("I64TruncF32S")
    I64TruncF32U => logger.write_string("I64TruncF32U")
    I64TruncF64S => logger.write_string("I64TruncF64S")
    I64TruncF64U => logger.write_string("I64TruncF64U")
    F32ConvertI32S => logger.write_string("F32ConvertI32S")
    F32ConvertI32U => logger.write_string("F32ConvertI32U")
    F32ConvertI64S => logger.write_string("F32ConvertI64S")
    F32ConvertI64U => logger.write_string("F32ConvertI64U")
    F32DemoteF64 => logger.write_string("F32DemoteF64")
    F64ConvertI32S => logger.write_string("F64ConvertI32S")
    F64ConvertI32U => logger.write_string("F64ConvertI32U")
    F64ConvertI64S => logger.write_string("F64ConvertI64S")
    F64ConvertI64U => logger.write_string("F64ConvertI64U")
    F64PromoteF32 => logger.write_string("F64PromoteF32")
    I32ReinterpretF32 => logger.write_string("I32ReinterpretF32")
    I64ReinterpretF64 => logger.write_string("I64ReinterpretF64")
    F32ReinterpretI32 => logger.write_string("F32ReinterpretI32")
    F64ReinterpretI64 => logger.write_string("F64ReinterpretI64")
    I32Extend8S => logger.write_string("I32Extend8S")
    I32Extend16S => logger.write_string("I32Extend16S")
    I64Extend8S => logger.write_string("I64Extend8S")
    I64Extend16S => logger.write_string("I64Extend16S")
    I64Extend32S => logger.write_string("I64Extend32S")
    I32TruncSatF32S => logger.write_string("I32TruncSatF32S")
    I32TruncSatF32U => logger.write_string("I32TruncSatF32U")
    I32TruncSatF64S => logger.write_string("I32TruncSatF64S")
    I32TruncSatF64U => logger.write_string("I32TruncSatF64U")
    I64TruncSatF32S => logger.write_string("I64TruncSatF32S")
    I64TruncSatF32U => logger.write_string("I64TruncSatF32U")
    I64TruncSatF64S => logger.write_string("I64TruncSatF64S")
    I64TruncSatF64U => logger.write_string("I64TruncSatF64U")
    V128Const => logger.write_string("V128Const")
    V128Load => logger.write_string("V128Load")
    V128Load8x8S => logger.write_string("V128Load8x8S")
    V128Load8x8U => logger.write_string("V128Load8x8U")
    V128Load16x4S => logger.write_string("V128Load16x4S")
    V128Load16x4U => logger.write_string("V128Load16x4U")
    V128Load32x2S => logger.write_string("V128Load32x2S")
    V128Load32x2U => logger.write_string("V128Load32x2U")
    V128Load8Splat => logger.write_string("V128Load8Splat")
    V128Load16Splat => logger.write_string("V128Load16Splat")
    V128Load32Splat => logger.write_string("V128Load32Splat")
    V128Load64Splat => logger.write_string("V128Load64Splat")
    V128Load32Zero => logger.write_string("V128Load32Zero")
    V128Load64Zero => logger.write_string("V128Load64Zero")
    V128Store => logger.write_string("V128Store")
    V128Load8Lane => logger.write_string("V128Load8Lane")
    V128Load16Lane => logger.write_string("V128Load16Lane")
    V128Load32Lane => logger.write_string("V128Load32Lane")
    V128Load64Lane => logger.write_string("V128Load64Lane")
    V128Store8Lane => logger.write_string("V128Store8Lane")
    V128Store16Lane => logger.write_string("V128Store16Lane")
    V128Store32Lane => logger.write_string("V128Store32Lane")
    V128Store64Lane => logger.write_string("V128Store64Lane")
    I8x16Shuffle => logger.write_string("I8x16Shuffle")
    I8x16Swizzle => logger.write_string("I8x16Swizzle")
    I8x16Splat => logger.write_string("I8x16Splat")
    I8x16ExtractLaneS => logger.write_string("I8x16ExtractLaneS")
    I8x16ExtractLaneU => logger.write_string("I8x16ExtractLaneU")
    I8x16ReplaceLane => logger.write_string("I8x16ReplaceLane")
    I8x16Eq => logger.write_string("I8x16Eq")
    I8x16Ne => logger.write_string("I8x16Ne")
    I8x16LtS => logger.write_string("I8x16LtS")
    I8x16LtU => logger.write_string("I8x16LtU")
    I8x16GtS => logger.write_string("I8x16GtS")
    I8x16GtU => logger.write_string("I8x16GtU")
    I8x16LeS => logger.write_string("I8x16LeS")
    I8x16LeU => logger.write_string("I8x16LeU")
    I8x16GeS => logger.write_string("I8x16GeS")
    I8x16GeU => logger.write_string("I8x16GeU")
    I8x16Abs => logger.write_string("I8x16Abs")
    I8x16Neg => logger.write_string("I8x16Neg")
    I8x16Popcnt => logger.write_string("I8x16Popcnt")
    I8x16AllTrue => logger.write_string("I8x16AllTrue")
    I8x16Bitmask => logger.write_string("I8x16Bitmask")
    I8x16NarrowI16x8S => logger.write_string("I8x16NarrowI16x8S")
    I8x16NarrowI16x8U => logger.write_string("I8x16NarrowI16x8U")
    I8x16Shl => logger.write_string("I8x16Shl")
    I8x16ShrS => logger.write_string("I8x16ShrS")
    I8x16ShrU => logger.write_string("I8x16ShrU")
    I8x16Add => logger.write_string("I8x16Add")
    I8x16AddSatS => logger.write_string("I8x16AddSatS")
    I8x16AddSatU => logger.write_string("I8x16AddSatU")
    I8x16Sub => logger.write_string("I8x16Sub")
    I8x16SubSatS => logger.write_string("I8x16SubSatS")
    I8x16SubSatU => logger.write_string("I8x16SubSatU")
    I8x16MinS => logger.write_string("I8x16MinS")
    I8x16MinU => logger.write_string("I8x16MinU")
    I8x16MaxS => logger.write_string("I8x16MaxS")
    I8x16MaxU => logger.write_string("I8x16MaxU")
    I8x16AvgrU => logger.write_string("I8x16AvgrU")
    I16x8Splat => logger.write_string("I16x8Splat")
    I16x8ExtractLaneS => logger.write_string("I16x8ExtractLaneS")
    I16x8ExtractLaneU => logger.write_string("I16x8ExtractLaneU")
    I16x8ReplaceLane => logger.write_string("I16x8ReplaceLane")
    I16x8Eq => logger.write_string("I16x8Eq")
    I16x8Ne => logger.write_string("I16x8Ne")
    I16x8LtS => logger.write_string("I16x8LtS")
    I16x8LtU => logger.write_string("I16x8LtU")
    I16x8GtS => logger.write_string("I16x8GtS")
    I16x8GtU => logger.write_string("I16x8GtU")
    I16x8LeS => logger.write_string("I16x8LeS")
    I16x8LeU => logger.write_string("I16x8LeU")
    I16x8GeS => logger.write_string("I16x8GeS")
    I16x8GeU => logger.write_string("I16x8GeU")
    I16x8Abs => logger.write_string("I16x8Abs")
    I16x8Neg => logger.write_string("I16x8Neg")
    I16x8Q15mulrSatS => logger.write_string("I16x8Q15mulrSatS")
    I16x8AllTrue => logger.write_string("I16x8AllTrue")
    I16x8Bitmask => logger.write_string("I16x8Bitmask")
    I16x8NarrowI32x4S => logger.write_string("I16x8NarrowI32x4S")
    I16x8NarrowI32x4U => logger.write_string("I16x8NarrowI32x4U")
    I16x8ExtendLowI8x16S => logger.write_string("I16x8ExtendLowI8x16S")
    I16x8ExtendHighI8x16S => logger.write_string("I16x8ExtendHighI8x16S")
    I16x8ExtendLowI8x16U => logger.write_string("I16x8ExtendLowI8x16U")
    I16x8ExtendHighI8x16U => logger.write_string("I16x8ExtendHighI8x16U")
    I16x8Shl => logger.write_string("I16x8Shl")
    I16x8ShrS => logger.write_string("I16x8ShrS")
    I16x8ShrU => logger.write_string("I16x8ShrU")
    I16x8Add => logger.write_string("I16x8Add")
    I16x8AddSatS => logger.write_string("I16x8AddSatS")
    I16x8AddSatU => logger.write_string("I16x8AddSatU")
    I16x8Sub => logger.write_string("I16x8Sub")
    I16x8SubSatS => logger.write_string("I16x8SubSatS")
    I16x8SubSatU => logger.write_string("I16x8SubSatU")
    I16x8Mul => logger.write_string("I16x8Mul")
    I16x8MinS => logger.write_string("I16x8MinS")
    I16x8MinU => logger.write_string("I16x8MinU")
    I16x8MaxS => logger.write_string("I16x8MaxS")
    I16x8MaxU => logger.write_string("I16x8MaxU")
    I16x8AvgrU => logger.write_string("I16x8AvgrU")
    I16x8ExtmulLowI8x16S => logger.write_string("I16x8ExtmulLowI8x16S")
    I16x8ExtmulHighI8x16S => logger.write_string("I16x8ExtmulHighI8x16S")
    I16x8ExtmulLowI8x16U => logger.write_string("I16x8ExtmulLowI8x16U")
    I16x8ExtmulHighI8x16U => logger.write_string("I16x8ExtmulHighI8x16U")
    I32x4Splat => logger.write_string("I32x4Splat")
    I32x4ExtractLane => logger.write_string("I32x4ExtractLane")
    I32x4ReplaceLane => logger.write_string("I32x4ReplaceLane")
    I32x4Eq => logger.write_string("I32x4Eq")
    I32x4Ne => logger.write_string("I32x4Ne")
    I32x4LtS => logger.write_string("I32x4LtS")
    I32x4LtU => logger.write_string("I32x4LtU")
    I32x4GtS => logger.write_string("I32x4GtS")
    I32x4GtU => logger.write_string("I32x4GtU")
    I32x4LeS => logger.write_string("I32x4LeS")
    I32x4LeU => logger.write_string("I32x4LeU")
    I32x4GeS => logger.write_string("I32x4GeS")
    I32x4GeU => logger.write_string("I32x4GeU")
    I32x4Abs => logger.write_string("I32x4Abs")
    I32x4Neg => logger.write_string("I32x4Neg")
    I32x4AllTrue => logger.write_string("I32x4AllTrue")
    I32x4Bitmask => logger.write_string("I32x4Bitmask")
    I32x4ExtendLowI16x8S => logger.write_string("I32x4ExtendLowI16x8S")
    I32x4ExtendHighI16x8S => logger.write_string("I32x4ExtendHighI16x8S")
    I32x4ExtendLowI16x8U => logger.write_string("I32x4ExtendLowI16x8U")
    I32x4ExtendHighI16x8U => logger.write_string("I32x4ExtendHighI16x8U")
    I32x4Shl => logger.write_string("I32x4Shl")
    I32x4ShrS => logger.write_string("I32x4ShrS")
    I32x4ShrU => logger.write_string("I32x4ShrU")
    I32x4Add => logger.write_string("I32x4Add")
    I32x4Sub => logger.write_string("I32x4Sub")
    I32x4Mul => logger.write_string("I32x4Mul")
    I32x4MinS => logger.write_string("I32x4MinS")
    I32x4MinU => logger.write_string("I32x4MinU")
    I32x4MaxS => logger.write_string("I32x4MaxS")
    I32x4MaxU => logger.write_string("I32x4MaxU")
    I32x4DotI16x8S => logger.write_string("I32x4DotI16x8S")
    I32x4ExtmulLowI16x8S => logger.write_string("I32x4ExtmulLowI16x8S")
    I32x4ExtmulHighI16x8S => logger.write_string("I32x4ExtmulHighI16x8S")
    I32x4ExtmulLowI16x8U => logger.write_string("I32x4ExtmulLowI16x8U")
    I32x4ExtmulHighI16x8U => logger.write_string("I32x4ExtmulHighI16x8U")
    I32x4TruncSatF32x4S => logger.write_string("I32x4TruncSatF32x4S")
    I32x4TruncSatF32x4U => logger.write_string("I32x4TruncSatF32x4U")
    I32x4TruncSatF64x2SZero => logger.write_string("I32x4TruncSatF64x2SZero")
    I32x4TruncSatF64x2UZero => logger.write_string("I32x4TruncSatF64x2UZero")
    I64x2Splat => logger.write_string("I64x2Splat")
    I64x2ExtractLane => logger.write_string("I64x2ExtractLane")
    I64x2ReplaceLane => logger.write_string("I64x2ReplaceLane")
    I64x2Eq => logger.write_string("I64x2Eq")
    I64x2Ne => logger.write_string("I64x2Ne")
    I64x2LtS => logger.write_string("I64x2LtS")
    I64x2GtS => logger.write_string("I64x2GtS")
    I64x2LeS => logger.write_string("I64x2LeS")
    I64x2GeS => logger.write_string("I64x2GeS")
    I64x2Abs => logger.write_string("I64x2Abs")
    I64x2Neg => logger.write_string("I64x2Neg")
    I64x2AllTrue => logger.write_string("I64x2AllTrue")
    I64x2Bitmask => logger.write_string("I64x2Bitmask")
    I64x2ExtendLowI32x4S => logger.write_string("I64x2ExtendLowI32x4S")
    I64x2ExtendHighI32x4S => logger.write_string("I64x2ExtendHighI32x4S")
    I64x2ExtendLowI32x4U => logger.write_string("I64x2ExtendLowI32x4U")
    I64x2ExtendHighI32x4U => logger.write_string("I64x2ExtendHighI32x4U")
    I64x2Shl => logger.write_string("I64x2Shl")
    I64x2ShrS => logger.write_string("I64x2ShrS")
    I64x2ShrU => logger.write_string("I64x2ShrU")
    I64x2Add => logger.write_string("I64x2Add")
    I64x2Sub => logger.write_string("I64x2Sub")
    I64x2Mul => logger.write_string("I64x2Mul")
    I64x2ExtmulLowI32x4S => logger.write_string("I64x2ExtmulLowI32x4S")
    I64x2ExtmulHighI32x4S => logger.write_string("I64x2ExtmulHighI32x4S")
    I64x2ExtmulLowI32x4U => logger.write_string("I64x2ExtmulLowI32x4U")
    I64x2ExtmulHighI32x4U => logger.write_string("I64x2ExtmulHighI32x4U")
    F32x4Splat => logger.write_string("F32x4Splat")
    F32x4ExtractLane => logger.write_string("F32x4ExtractLane")
    F32x4ReplaceLane => logger.write_string("F32x4ReplaceLane")
    F32x4Eq => logger.write_string("F32x4Eq")
    F32x4Ne => logger.write_string("F32x4Ne")
    F32x4Lt => logger.write_string("F32x4Lt")
    F32x4Gt => logger.write_string("F32x4Gt")
    F32x4Le => logger.write_string("F32x4Le")
    F32x4Ge => logger.write_string("F32x4Ge")
    F32x4Abs => logger.write_string("F32x4Abs")
    F32x4Neg => logger.write_string("F32x4Neg")
    F32x4Sqrt => logger.write_string("F32x4Sqrt")
    F32x4Add => logger.write_string("F32x4Add")
    F32x4Sub => logger.write_string("F32x4Sub")
    F32x4Mul => logger.write_string("F32x4Mul")
    F32x4Div => logger.write_string("F32x4Div")
    F32x4Min => logger.write_string("F32x4Min")
    F32x4Max => logger.write_string("F32x4Max")
    F32x4Pmin => logger.write_string("F32x4Pmin")
    F32x4Pmax => logger.write_string("F32x4Pmax")
    F32x4Ceil => logger.write_string("F32x4Ceil")
    F32x4Floor => logger.write_string("F32x4Floor")
    F32x4Trunc => logger.write_string("F32x4Trunc")
    F32x4Nearest => logger.write_string("F32x4Nearest")
    F32x4ConvertI32x4S => logger.write_string("F32x4ConvertI32x4S")
    F32x4ConvertI32x4U => logger.write_string("F32x4ConvertI32x4U")
    F32x4DemoteF64x2Zero => logger.write_string("F32x4DemoteF64x2Zero")
    F64x2Splat => logger.write_string("F64x2Splat")
    F64x2ExtractLane => logger.write_string("F64x2ExtractLane")
    F64x2ReplaceLane => logger.write_string("F64x2ReplaceLane")
    F64x2Eq => logger.write_string("F64x2Eq")
    F64x2Ne => logger.write_string("F64x2Ne")
    F64x2Lt => logger.write_string("F64x2Lt")
    F64x2Gt => logger.write_string("F64x2Gt")
    F64x2Le => logger.write_string("F64x2Le")
    F64x2Ge => logger.write_string("F64x2Ge")
    F64x2Abs => logger.write_string("F64x2Abs")
    F64x2Neg => logger.write_string("F64x2Neg")
    F64x2Sqrt => logger.write_string("F64x2Sqrt")
    F64x2Add => logger.write_string("F64x2Add")
    F64x2Sub => logger.write_string("F64x2Sub")
    F64x2Mul => logger.write_string("F64x2Mul")
    F64x2Div => logger.write_string("F64x2Div")
    F64x2Min => logger.write_string("F64x2Min")
    F64x2Max => logger.write_string("F64x2Max")
    F64x2Pmin => logger.write_string("F64x2Pmin")
    F64x2Pmax => logger.write_string("F64x2Pmax")
    F64x2Ceil => logger.write_string("F64x2Ceil")
    F64x2Floor => logger.write_string("F64x2Floor")
    F64x2Trunc => logger.write_string("F64x2Trunc")
    F64x2Nearest => logger.write_string("F64x2Nearest")
    F64x2ConvertLowI32x4S => logger.write_string("F64x2ConvertLowI32x4S")
    F64x2ConvertLowI32x4U => logger.write_string("F64x2ConvertLowI32x4U")
    F64x2PromoteLowF32x4 => logger.write_string("F64x2PromoteLowF32x4")
    V128Not => logger.write_string("V128Not")
    V128And => logger.write_string("V128And")
    V128AndNot => logger.write_string("V128AndNot")
    V128Or => logger.write_string("V128Or")
    V128Xor => logger.write_string("V128Xor")
    V128Bitselect => logger.write_string("V128Bitselect")
    V128AnyTrue => logger.write_string("V128AnyTrue")
    I8x16RelaxedSwizzle => logger.write_string("I8x16RelaxedSwizzle")
    I32x4RelaxedTruncF32x4S => logger.write_string("I32x4RelaxedTruncF32x4S")
    I32x4RelaxedTruncF32x4U => logger.write_string("I32x4RelaxedTruncF32x4U")
    I32x4RelaxedTruncF64x2SZero =>
      logger.write_string("I32x4RelaxedTruncF64x2SZero")
    I32x4RelaxedTruncF64x2UZero =>
      logger.write_string("I32x4RelaxedTruncF64x2UZero")
    F32x4RelaxedMadd => logger.write_string("F32x4RelaxedMadd")
    F32x4RelaxedNmadd => logger.write_string("F32x4RelaxedNmadd")
    F64x2RelaxedMadd => logger.write_string("F64x2RelaxedMadd")
    F64x2RelaxedNmadd => logger.write_string("F64x2RelaxedNmadd")
    I8x16RelaxedLaneselect => logger.write_string("I8x16RelaxedLaneselect")
    I16x8RelaxedLaneselect => logger.write_string("I16x8RelaxedLaneselect")
    I32x4RelaxedLaneselect => logger.write_string("I32x4RelaxedLaneselect")
    I64x2RelaxedLaneselect => logger.write_string("I64x2RelaxedLaneselect")
    F32x4RelaxedMin => logger.write_string("F32x4RelaxedMin")
    F32x4RelaxedMax => logger.write_string("F32x4RelaxedMax")
    F64x2RelaxedMin => logger.write_string("F64x2RelaxedMin")
    F64x2RelaxedMax => logger.write_string("F64x2RelaxedMax")
    I16x8RelaxedQ15mulrS => logger.write_string("I16x8RelaxedQ15mulrS")
    I16x8RelaxedDotI8x16I7x16S =>
      logger.write_string("I16x8RelaxedDotI8x16I7x16S")
    I32x4RelaxedDotI8x16I7x16AddS =>
      logger.write_string("I32x4RelaxedDotI8x16I7x16AddS")
  }
}

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
  Try
  Do
  Then
  Else
  End
  Catch
  CatchRef
  CatchAll
  CatchAllRef
  Delegate
  Rethrow
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
  AssertException
  AssertExhaustion
  NanCanonical
  NanArithmetic

  // Memory arg tokens
  OffsetEqNat // offset=N
  AlignEqNat // align=N
  SimdShapeToken(SimdShape)
} derive(Eq, Debug)

///|
pub impl Show for TokenType with fn output(self, logger) {
  match self {
    Eof => logger.write_string("Eof")
    Lpar => logger.write_string("Lpar")
    Rpar => logger.write_string("Rpar")
    LparAnn => logger.write_string("LparAnn")
    Nat => logger.write_string("Nat")
    Int => logger.write_string("Int")
    Float => logger.write_string("Float")
    Text => logger.write_string("Text")
    Var => logger.write_string("Var")
    Reserved => logger.write_string("Reserved")
    Invalid => logger.write_string("Invalid")
    Module => logger.write_string("Module")
    Type => logger.write_string("Type")
    Func => logger.write_string("Func")
    Param => logger.write_string("Param")
    Result => logger.write_string("Result")
    Local => logger.write_string("Local")
    Global => logger.write_string("Global")
    Tag => logger.write_string("Tag")
    Table => logger.write_string("Table")
    Memory => logger.write_string("Memory")
    Import => logger.write_string("Import")
    Export => logger.write_string("Export")
    ValueType(val) => {
      logger.write_string("ValueType(")
      val.output(logger)
      logger.write_string(")")
    }
    Opcode(val) => {
      logger.write_string("Opcode(")
      val.output(logger)
      logger.write_string(")")
    }
    Block => logger.write_string("Block")
    Loop => logger.write_string("Loop")
    If => logger.write_string("If")
    Try => logger.write_string("Try")
    Do => logger.write_string("Do")
    Then => logger.write_string("Then")
    Else => logger.write_string("Else")
    End => logger.write_string("End")
    Catch => logger.write_string("Catch")
    CatchRef => logger.write_string("CatchRef")
    CatchAll => logger.write_string("CatchAll")
    CatchAllRef => logger.write_string("CatchAllRef")
    Delegate => logger.write_string("Delegate")
    Rethrow => logger.write_string("Rethrow")
    Offset => logger.write_string("Offset")
    Item => logger.write_string("Item")
    Start => logger.write_string("Start")
    Data => logger.write_string("Data")
    Elem => logger.write_string("Elem")
    Mut => logger.write_string("Mut")
    Binary => logger.write_string("Binary")
    Quote => logger.write_string("Quote")
    Input => logger.write_string("Input")
    Output => logger.write_string("Output")
    Register => logger.write_string("Register")
    Invoke => logger.write_string("Invoke")
    Get => logger.write_string("Get")
    Declare => logger.write_string("Declare")
    AssertMalformed => logger.write_string("AssertMalformed")
    AssertInvalid => logger.write_string("AssertInvalid")
    AssertUnlinkable => logger.write_string("AssertUnlinkable")
    AssertReturn => logger.write_string("AssertReturn")
    AssertTrap => logger.write_string("AssertTrap")
    AssertException => logger.write_string("AssertException")
    AssertExhaustion => logger.write_string("AssertExhaustion")
    NanCanonical => logger.write_string("NanCanonical")
    NanArithmetic => logger.write_string("NanArithmetic")
    OffsetEqNat => logger.write_string("OffsetEqNat")
    AlignEqNat => logger.write_string("AlignEqNat")
    SimdShapeToken(val) => {
      logger.write_string("SimdShapeToken(")
      val.output(logger)
      logger.write_string(")")
    }
  }
}

///|
pub enum TokenValue {
  None
  Text(String)
  Literal(Literal)
  ValueType(ValueType)
  Opcode(Opcode)
} derive(Eq, Debug)

///|
pub impl Show for TokenValue with fn output(self, logger) {
  match self {
    None => logger.write_string("None")
    Text(text) => {
      logger.write_string("Text(")
      text.output(logger)
      logger.write_char(')')
    }
    Literal(lit) => {
      logger.write_string("Literal(")
      lit.output(logger)
      logger.write_char(')')
    }
    ValueType(val_type) => {
      logger.write_string("ValueType(")
      val_type.output(logger)
      logger.write_char(')')
    }
    Opcode(op) => {
      logger.write_string("Opcode(")
      op.output(logger)
      logger.write_char(')')
    }
  }
}

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
