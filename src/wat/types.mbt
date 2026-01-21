pub enum LiteralType {
  Int
  Float
  Hexfloat
  Infinity
  Nan
}

pub enum ErrorLevel {
  Error
  Warning
}

// ============================================================================
// Core Structures
// ============================================================================

pub struct Location {
  filename : String
  line : Int
  first_column : Int
  last_column : Int
}

pub struct Literal {
  literal_type : LiteralType
  text : String
}

pub struct Token {
  location : Location
  token_type : TokenType
  value : TokenValue
}

pub struct LexerError {
  level : ErrorLevel
  location : Location
  message : String
}

enum ReservedChars {
  None
  Id
  Some
}


pub enum ValueType {
  I32
  I64
  F32
  F64
  V128
  FuncRef
  ExternRef
  Func
  Extern
}

pub enum Opcode {
  // Control
  Unreachable
  Nop
  Block
  Loop
  If
  Else
  End
  Br
  BrIf
  BrTable
  Return
  Call
  CallIndirect
  // Reference
  RefNull
  RefIsNull
  RefFunc
  // Parametric
  Drop
  Select
  // Variable
  LocalGet
  LocalSet
  LocalTee
  GlobalGet
  GlobalSet
  // Table
  TableGet
  TableSet
  TableSize
  TableGrow
  TableFill
  TableCopy
  TableInit
  ElemDrop
  // Memory
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
  // Numeric - Constants
  I32Const
  I64Const
  F32Const
  F64Const
  // Numeric - i32 operations
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
  // Numeric - i64 operations
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
  // Numeric - f32 operations
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
  // Numeric - f64 operations
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
  // Conversions
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
  // Sign extension
  I32Extend8S
  I32Extend16S
  I64Extend8S
  I64Extend16S
  I64Extend32S
  // Saturating truncation
  I32TruncSatF32S
  I32TruncSatF32U
  I32TruncSatF64S
  I32TruncSatF64U
  I64TruncSatF32S
  I64TruncSatF32U
  I64TruncSatF64S
  I64TruncSatF64U
}

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
  AlignEqNat
  OffsetEqNat
  Invalid
  // Module structure
  Module
  Type
  Func
  Param
  Result
  Local
  Global
  Table
  Memory
  Elem
  Data
  Start
  Import
  Export
  Mut
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
  // Other module keywords
  Offset
  Item
  Declare
  Quote
  Register
  Invoke
  Get
  AssertMalformed
  AssertInvalid
  AssertUnlinkable
  AssertReturn
  AssertTrap
  AssertExhaustion
  Input
  Output
  Binary
}

pub enum TokenValue {
  None
  Text(String)
  Literal(Literal)
  ValueType(ValueType)
  Opcode(Opcode)
}

// ============================================================================
// Keyword Entry and Hash Table
// ============================================================================

struct KeywordEntry {
  keyword : String
  token_type : TokenType
}

// ============================================================================
// WastLexer
// ============================================================================

pub struct WastLexer {
  buffer : Bytes
  filename : String
  mut line : Int
  mut cursor : Int
  mut line_start : Int
  mut token_start : Int
  errors : Array[LexerError]
}

