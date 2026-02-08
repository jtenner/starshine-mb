// ============================================================================
// AST Types
// ============================================================================

///|
pub enum Index {
  Num(UInt)
  Id(String)
}

///|
pub struct Limits {
  min : UInt
  max : UInt?
}

///|
pub struct FuncType {
  params : Array[ValueType]
  results : Array[ValueType]
}

///|
pub struct TypeUse {
  type_index : Index?
  func_type : FuncType
}

///|
pub enum InlineExport {
  Export(String)
}

///|
pub enum ImportDesc {
  Func(TypeUse)
  Table(TableType)
  Memory(MemoryType)
  Global(GlobalType)
}

///|
pub struct Import {
  module_name : String
  field_name : String
  desc : ImportDesc
  id : String?
}

///|
pub enum ExportDesc {
  Func(Index)
  Table(Index)
  Memory(Index)
  Global(Index)
}

///|
pub struct Export {
  name : String
  desc : ExportDesc
}

///|
pub struct TableType {
  limits : Limits
  elem_type : ValueType
}

///|
pub struct MemoryType(Limits)

///|
pub struct GlobalType {
  val_type : ValueType
  mutable_ : Bool
}

///|
pub struct Local {
  id : String?
  val_type : ValueType
}

///|
pub struct Func {
  id : String?
  exports : Array[InlineExport]
  type_use : TypeUse
  locals : Array[Local]
  body : Array[Instruction]
}

///|
pub struct Global {
  id : String?
  exports : Array[InlineExport]
  global_type : GlobalType
  init : Array[Instruction]
}

///|
pub struct Table {
  id : String?
  exports : Array[InlineExport]
  table_type : TableType
}

///|
pub struct Memory {
  id : String?
  exports : Array[InlineExport]
  memory_type : MemoryType
}

///|
pub struct TypeDef {
  id : String?
  func_type : FuncType
}

///|
pub struct DataSegment {
  id : String?
  memory_index : Index
  offset : Array[Instruction]
  data : Bytes
}

///|
pub struct ElemSegment {
  id : String?
  table_index : Index
  offset : Array[Instruction]
  func_indices : Array[Index]
}

///|
pub struct Start {
  func_index : Index
}

///|
pub enum ModuleField {
  TypeField(TypeDef)
  FuncField(Func)
  TableField(Table)
  MemoryField(Memory)
  GlobalField(Global)
  ImportField(Import)
  ExportField(Export)
  StartField(Start)
  ElemField(ElemSegment)
  DataField(DataSegment)
}

///|
pub struct Module {
  id : String?
  fields : Array[ModuleField]
}

// ============================================================================
// Instruction AST
// ============================================================================

///|
pub struct MemArg {
  align : UInt
  offset : UInt
}

///|
pub struct BlockType {
  label : String?
  type_use : TypeUse?
}

// ============================================================================
// instruction.mbt - Extended Instruction AST for SIMD
// ============================================================================

///|
pub struct V128Const {
  shape : SimdShape
  values : Array[String]
}

///|
pub enum SimdShape {
  I8x16
  I16x8
  I32x4
  I64x2
  F32x4
  F64x2
} derive(Show, Eq)

///|
pub struct ShuffleLanes {
  lanes : FixedArray[UInt] // 16 lane indices
}

///|
pub enum Instruction {
  // Control
  Unreachable
  Nop
  Block(BlockType, Array[Instruction])
  Loop(BlockType, Array[Instruction])
  If(BlockType, Array[Instruction], Array[Instruction])
  Br(Index)
  BrIf(Index)
  BrTable(Array[Index], Index)
  Return
  Call(Index)
  CallIndirect(Index, TypeUse)

  // Parametric
  Drop
  Select(Array[ValueType]?)

  // Variable
  LocalGet(Index)
  LocalSet(Index)
  LocalTee(Index)
  GlobalGet(Index)
  GlobalSet(Index)

  // Table
  TableGet(Index)
  TableSet(Index)
  TableSize(Index)
  TableGrow(Index)
  TableFill(Index)
  TableCopy(Index, Index)
  TableInit(Index, Index)
  ElemDrop(Index)

  // Memory
  Load(Opcode, MemArg)
  Store(Opcode, MemArg)
  MemorySize
  MemoryGrow
  MemoryFill
  MemoryCopy
  MemoryInit(Index)
  DataDrop(Index)

  // Numeric
  Const(Opcode, String)
  Unary(Opcode)
  Binary(Opcode)
  Test(Opcode)
  Compare(Opcode)
  Convert(Opcode)

  // Reference
  RefNull(ValueType)
  RefIsNull
  RefFunc(Index)

  // ========== SIMD Instructions ==========

  // V128 Const
  V128Const(V128Const)

  // V128 Memory
  V128Load(MemArg)
  V128Load8x8S(MemArg)
  V128Load8x8U(MemArg)
  V128Load16x4S(MemArg)
  V128Load16x4U(MemArg)
  V128Load32x2S(MemArg)
  V128Load32x2U(MemArg)
  V128Load8Splat(MemArg)
  V128Load16Splat(MemArg)
  V128Load32Splat(MemArg)
  V128Load64Splat(MemArg)
  V128Load32Zero(MemArg)
  V128Load64Zero(MemArg)
  V128Store(MemArg)
  V128Load8Lane(MemArg, UInt) // memarg, lane
  V128Load16Lane(MemArg, UInt)
  V128Load32Lane(MemArg, UInt)
  V128Load64Lane(MemArg, UInt)
  V128Store8Lane(MemArg, UInt)
  V128Store16Lane(MemArg, UInt)
  V128Store32Lane(MemArg, UInt)
  V128Store64Lane(MemArg, UInt)

  // V128 Shuffle/Swizzle
  I8x16Shuffle(ShuffleLanes)
  I8x16Swizzle

  // V128 Splat
  I8x16Splat
  I16x8Splat
  I32x4Splat
  I64x2Splat
  F32x4Splat
  F64x2Splat

  // V128 Extract/Replace Lane
  I8x16ExtractLaneS(UInt)
  I8x16ExtractLaneU(UInt)
  I8x16ReplaceLane(UInt)
  I16x8ExtractLaneS(UInt)
  I16x8ExtractLaneU(UInt)
  I16x8ReplaceLane(UInt)
  I32x4ExtractLane(UInt)
  I32x4ReplaceLane(UInt)
  I64x2ExtractLane(UInt)
  I64x2ReplaceLane(UInt)
  F32x4ExtractLane(UInt)
  F32x4ReplaceLane(UInt)
  F64x2ExtractLane(UInt)
  F64x2ReplaceLane(UInt)

  // V128 Unary operations (no operands beyond the v128)
  SimdUnary(Opcode)

  // V128 Binary operations
  SimdBinary(Opcode)

  // V128 Ternary operations (bitselect, relaxed laneselect, fma)
  SimdTernary(Opcode)

  // V128 Shift operations (take i32 shift amount)
  SimdShift(Opcode)

  // V128 Test operations (return i32)
  SimdTest(Opcode)

  // V128 Comparison operations (return v128 mask)
  SimdCompare(Opcode)

  // V128 Conversion operations
  SimdConvert(Opcode)

  // Relaxed SIMD
  SimdRelaxed(Opcode)
}

///|
pub enum WastValue {
  I32(String)
  I64(String)
  F32(String)
  F64(String)
  RefNull(ValueType)
  RefFunc
}

///|
pub enum WastResult {
  Value(WastValue)
  F32NanCanonical
  F32NanArithmetic
  F64NanCanonical
  F64NanArithmetic
  RefNull(ValueType?)
  RefFunc
}

///|
pub struct WastAction {
  module_name : String?
  name : String
  args : Array[WastValue]
}

///|
pub enum WastActionType {
  Invoke(WastAction)
  Get(String?, String) // module_name?, global_name
}

///|
pub enum WastCommand {
  Module(Module)
  ModuleBinary(String?, Bytes)
  ModuleQuote(String?, Array[String])
  Register(String, String?) // name, module_id
  Action(WastActionType)
  AssertReturn(WastActionType, Array[WastResult])
  AssertTrap(WastActionType, String)
  AssertExhaustion(WastActionType, String)
  AssertMalformed(WastModuleDef, String)
  AssertInvalid(WastModuleDef, String)
  AssertUnlinkable(WastModuleDef, String)
}

///|
pub enum WastModuleDef {
  Inline(Module)
  Binary(Bytes)
  Quote(Array[String])
}

///|
pub struct WastScript {
  commands : Array[WastCommand]
}

// ============================================================================
// Parser Error Types
// ============================================================================

///|
pub struct ParseError {
  location : Location
  message : String
}

///|
pub suberror ParserError {
  UnexpectedToken(Token, String)
  InvalidInstruction(String)
  Custom(String)
} derive(Show)

// ============================================================================
// Lexer State for Rollback
// ============================================================================

///|
pub struct LexerState {
  cursor : Int
  line : Int
  line_start : Int
}

// ============================================================================
// Parser Structure
// ============================================================================

///|
pub struct WastParser {
  lexer : WastLexer
  mut current : Token
  errors : Array[ParseError]
}

///|
pub fn WastParser::new(lexer : WastLexer) -> WastParser {
  let parser = {
    lexer,
    current: {
      location: { filename: "", line: 0, first_column: 0, last_column: 0 },
      token_type: Eof,
      value: None,
    },
    errors: [],
  }
  ignore(parser.advance())
  parser
}

// ============================================================================
// Parser Utilities
// ============================================================================

///|
fn WastParser::advance(self : WastParser) -> Token {
  let prev = self.current
  self.current = self.lexer.get_token()
  prev
}

///|
fn WastParser::check(self : WastParser, token_type : TokenType) -> Bool {
  match (self.current.token_type, token_type) {
    (Eof, Eof) => true
    (Lpar, Lpar) => true
    (Rpar, Rpar) => true
    (Nat, Nat) => true
    (Int, Int) => true
    (Float, Float) => true
    (Text, Text) => true
    (Var, Var) => true
    (Module, Module) => true
    (Func, Func) => true
    (Param, Param) => true
    (Result, Result) => true
    (Local, Local) => true
    (Global, Global) => true
    (Type, Type) => true
    (Table, Table) => true
    (Memory, Memory) => true
    (Import, Import) => true
    (Export, Export) => true
    (Block, Block) => true
    (Loop, Loop) => true
    (If, If) => true
    (Else, Else) => true
    (End, End) => true
    (Then, Then) => true
    (Start, Start) => true
    (Data, Data) => true
    (Elem, Elem) => true
    (Mut, Mut) => true
    (Offset, Offset) => true
    (Item, Item) => true
    (ValueType(_), ValueType(_)) => true
    (Opcode(_), Opcode(_)) => true
    _ => false
  }
}

///|
fn WastParser::match_token(self : WastParser, token_type : TokenType) -> Bool {
  if self.check(token_type) {
    let _ = self.advance()
    true
  } else {
    false
  }
}

///|
fn WastParser::expect(
  self : WastParser,
  token_type : TokenType,
  msg : String,
) -> Token raise ParserError {
  if self.check(token_type) {
    self.advance()
  } else {
    raise UnexpectedToken(self.current, msg)
  }
}

///|
fn WastParser::expect_lpar(self : WastParser) -> Unit raise ParserError {
  let _ = self.expect(Lpar, "expected '('")

}

///|
fn WastParser::expect_rpar(self : WastParser) -> Unit raise ParserError {
  let _ = self.expect(Rpar, "expected ')'")

}

///|
fn WastParser::get_text(_ : WastParser, token : Token) -> String {
  match token.value {
    Text(s) => s
    _ => ""
  }
}

///|
fn WastParser::get_literal_text(_ : WastParser, token : Token) -> String {
  match token.value {
    Literal(lit) => lit.text
    _ => ""
  }
}

// ============================================================================
// Lexer State Management
// ============================================================================

///|
fn WastParser::save_lexer_state(self : WastParser) -> LexerState {
  {
    cursor: self.lexer.cursor,
    line: self.lexer.line,
    line_start: self.lexer.line_start,
  }
}

///|
fn WastParser::restore_lexer_state(
  self : WastParser,
  state : LexerState,
) -> Unit {
  self.lexer.cursor = state.cursor
  self.lexer.line = state.line
  self.lexer.line_start = state.line_start
}

// ============================================================================
// Index Parsing
// ============================================================================

///|
fn WastParser::parse_index(self : WastParser) -> Index raise ParserError {
  match self.current.token_type {
    Nat => {
      let token = self.advance()
      let text = self.get_literal_text(token)
      Index::Num(parse_uint(text))
    }
    Var => {
      let token = self.advance()
      let text = self.get_text(token)
      Index::Id(text)
    }
    _ => raise UnexpectedToken(self.current, "expected index")
  }
}

///|
fn WastParser::try_parse_index(self : WastParser) -> Index? {
  match self.current.token_type {
    Nat | Var => Some(self.parse_index()) catch { _ => None }
    _ => None
  }
}

///|
fn parse_uint(s : String) -> UInt {
  let mut result : UInt = 0
  let mut i = 0
  // Handle hex prefix
  if s.length() > 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X') {
    i = 2
    while i < s.length() {
      let c = s[i]
      if c == '_' {
        i += 1
        continue
      }
      let digit = if c >= '0' && c <= '9' {
        c.to_int() - 0x30
      } else if c >= 'a' && c <= 'f' {
        c.to_int() - 0x61 + 10
      } else if c >= 'A' && c <= 'F' {
        c.to_int() - 0x41 + 10
      } else {
        0
      }
      result = (result << 4) | digit.reinterpret_as_uint()
      i += 1
    }
  } else {
    while i < s.length() {
      let c = s[i]
      if c == '_' {
        i += 1
        continue
      }
      if c >= '0' && c <= '9' {
        result = result * 10 + (c.to_int() - 0x30).reinterpret_as_uint()
      }
      i += 1
    }
  }
  result
}

// ============================================================================
// Value Type Parsing
// ============================================================================

///|
fn WastParser::parse_value_type(
  self : WastParser,
) -> ValueType raise ParserError {
  match self.current.token_type {
    ValueType(vt) => {
      let _ = self.advance()
      vt
    }
    // 'func' is an abbreviation for funcref in heap type contexts (e.g., ref.null func)
    Func => {
      let _ = self.advance()
      FuncRef
    }
    _ => raise UnexpectedToken(self.current, "expected value type")
  }
}

// ============================================================================
// Limits Parsing
// ============================================================================

///|
fn WastParser::parse_limits(self : WastParser) -> Limits raise ParserError {
  let min_token = self.expect(Nat, "expected minimum limit")
  let min = parse_uint(self.get_literal_text(min_token))
  let max : UInt? = if self.check(Nat) {
    let max_token = self.advance()
    Some(parse_uint(self.get_literal_text(max_token)))
  } else {
    None
  }
  { min, max }
}

// ============================================================================
// Type Use Parsing
// ============================================================================

///|
fn WastParser::parse_type_use(self : WastParser) -> TypeUse raise ParserError {
  let mut type_index : Index? = None
  let params : Array[ValueType] = []
  let results : Array[ValueType] = []

  // Check for (type $id) or (type 0)
  if self.check(Lpar) {
    let saved_state = self.save_lexer_state()
    let saved_token = self.current
    self.expect_lpar()
    if self.check(Type) {
      let _ = self.advance() // consume 'type'
      type_index = Some(self.parse_index())
      self.expect_rpar()
      // After consuming type reference, return early
      return { type_index, func_type: { params, results } }
    } else {
      // Not a type reference, rollback
      self.restore_lexer_state(saved_state)
      self.current = saved_token
    }
  }

  // Parse inline params (only if we didn't find a type reference)
  while self.check(Lpar) {
    let saved_state = self.save_lexer_state()
    let saved_token = self.current
    self.expect_lpar()
    if self.check(Param) {
      let _ = self.advance() // consume 'param'
      // Check for named param: (param $name type)
      if self.current.token_type is Var {
        let _ = self.advance() // skip the id
        params.push(self.parse_value_type())
      } else {
        // Abbreviated: (param type*)
        while self.current.token_type is ValueType(_) {
          params.push(self.parse_value_type())
        }
      }
      self.expect_rpar()
    } else {
      // Not a param, rollback and continue
      self.restore_lexer_state(saved_state)
      self.current = saved_token
      break
    }
  }

  // Parse inline results
  while self.check(Lpar) {
    let saved_state = self.save_lexer_state()
    let saved_token = self.current
    self.expect_lpar()
    if self.check(Result) {
      let _ = self.advance() // consume 'result'
      while self.current.token_type is ValueType(_) {
        results.push(self.parse_value_type())
      }
      self.expect_rpar()
    } else {
      // Not a result, rollback and stop
      self.restore_lexer_state(saved_state)
      self.current = saved_token
      break
    }
  }
  { type_index, func_type: { params, results } }
}

// ============================================================================
// Instruction Parsing
// ============================================================================

///|
fn WastParser::parse_mem_arg(self : WastParser, default_align : UInt) -> MemArg {
  let mut offset : UInt = 0
  let mut align = default_align

  // Parse offset=N and align=N in any order
  while true {
    match self.current.token_type {
      OffsetEqNat => {
        let token = self.advance()
        offset = parse_uint(self.get_text(token))
      }
      AlignEqNat => {
        let token = self.advance()
        align = parse_uint(self.get_text(token))
      }
      _ => break
    }
  }
  { align, offset }
}

///|
fn WastParser::parse_block_type(
  self : WastParser,
) -> BlockType raise ParserError {
  let label : String? = if self.current.token_type is Var {
    let token = self.advance()
    Some(self.get_text(token))
  } else {
    None
  }

  // Try to parse type use for block
  let type_use : TypeUse? = if self.check(Lpar) {
    let saved_state = self.save_lexer_state()
    let saved_token = self.current
    self.expect_lpar()
    if self.check(Type) || self.check(Param) || self.check(Result) {
      // It's a type use, parse it
      self.restore_lexer_state(saved_state)
      self.current = saved_token
      Some(self.parse_type_use())
    } else {
      // Not a type use, restore
      self.restore_lexer_state(saved_state)
      self.current = saved_token
      None
    }
  } else if self.current.token_type is ValueType(_) {
    // Shorthand: just a result type (no parens)
    let vt = self.parse_value_type()
    Some({ type_index: None, func_type: { params: [], results: [vt] } })
  } else {
    None
  }
  { label, type_use }
}

///|
fn WastParser::parse_instructions(
  self : WastParser,
) -> Array[Instruction] raise ParserError {
  let instrs : Array[Instruction] = []
  while true {
    match self.current.token_type {
      Rpar | Else | End | Eof => break
      Lpar => {
        self.expect_lpar()
        let folded = self.parse_folded_instruction()
        for instr in folded {
          instrs.push(instr)
        }
        self.expect_rpar()
      }
      _ =>
        match self.try_parse_plain_instruction() {
          Some(instr) => instrs.push(instr)
          None => break
        }
    }
  }
  instrs
}

///|
fn WastParser::parse_folded_instruction(
  self : WastParser,
) -> Array[Instruction] raise ParserError {
  match self.current.token_type {
    Block => {
      let _ = self.advance()
      let block_type = self.parse_block_type()
      let body = self.parse_instructions()
      [Block(block_type, body)]
    }
    Loop => {
      let _ = self.advance()
      let block_type = self.parse_block_type()
      let body = self.parse_instructions()
      [Loop(block_type, body)]
    }
    If => {
      let _ = self.advance()
      let block_type = self.parse_block_type()

      // Collect condition operands first
      let result : Array[Instruction] = []

      // Parse condition operands (folded instructions before then/else)
      while self.check(Lpar) {
        let saved = self.save_lexer_state()
        let saved_token = self.current
        self.expect_lpar()
        if self.check(Then) || self.check(Else) {
          self.restore_lexer_state(saved)
          self.current = saved_token
          break
        }
        self.restore_lexer_state(saved)
        self.current = saved_token

        // Parse the operand
        self.expect_lpar()
        let nested = self.parse_folded_instruction()
        for i in nested {
          result.push(i)
        }
        self.expect_rpar()
      }
      let has_folded_then = self.check(Lpar) &&
        {
          let saved = self.save_lexer_state()
          let saved_token = self.current
          self.expect_lpar()
          let is_then = self.check(Then)
          self.restore_lexer_state(saved)
          self.current = saved_token
          is_then
        }
      let mut then_body : Array[Instruction] = []
      let mut else_body : Array[Instruction] = []
      if has_folded_then {
        // Hybrid syntax
        self.expect_lpar()
        let _ = self.expect(Then, "expected 'then'")
        then_body = self.parse_instructions()
        self.expect_rpar()
        if self.check(Lpar) {
          let saved = self.save_lexer_state()
          let saved_token = self.current
          self.expect_lpar()
          if self.check(Else) {
            let _ = self.advance()
            else_body = self.parse_instructions()
            self.expect_rpar()
          } else {
            self.restore_lexer_state(saved)
            self.current = saved_token
          }
        }
      } else {
        // Flat syntax
        then_body = self.parse_block_body()
        else_body = if self.match_token(Else) {
          self.parse_block_body()
        } else {
          []
        }
        let _ = self.expect(End, "expected 'end'")

      }
      result.push(If(block_type, then_body, else_body))
      result
    }
    Opcode(op) => {
      let _ = self.advance()
      let instr = self.parse_opcode_instruction(op)
      // Parse nested operand instructions
      let result : Array[Instruction] = []
      while self.check(Lpar) {
        self.expect_lpar()
        let nested = self.parse_folded_instruction()
        for i in nested {
          result.push(i)
        }
        self.expect_rpar()
      }
      result.push(instr)
      result
    }
    _ => raise UnexpectedToken(self.current, "expected instruction")
  }
}

///|
fn WastParser::try_parse_plain_instruction(
  self : WastParser,
) -> Instruction? raise ParserError {
  match self.current.token_type {
    Block => {
      let _ = self.advance()
      let block_type = self.parse_block_type()
      let body = self.parse_block_body()
      let _ = self.expect(End, "expected 'end'")
      Some(Block(block_type, body))
    }
    Loop => {
      let _ = self.advance()
      let block_type = self.parse_block_type()
      let body = self.parse_block_body()
      let _ = self.expect(End, "expected 'end'")
      Some(Loop(block_type, body))
    }
    If => {
      let _ = self.advance()
      let block_type = self.parse_block_type()
      let mut used_explicit_syntax = false

      // Check if we're using explicit (then ...) syntax
      let then_body : Array[Instruction] = if self.check(Lpar) {
        let saved_state = self.save_lexer_state()
        let saved_token = self.current
        self.expect_lpar()
        if self.check(Then) {
          // Explicit (then ...) form
          used_explicit_syntax = true
          let _ = self.advance()
          let instrs = self.parse_instructions()
          self.expect_rpar()
          instrs
        } else {
          // Not a then block, rollback and parse as regular instructions
          self.restore_lexer_state(saved_state)
          self.current = saved_token
          self.parse_block_body()
        }
      } else {
        // Flat form without explicit then
        self.parse_block_body()
      }

      // Parse else block
      let else_body : Array[Instruction] = if self.check(Lpar) {
        let saved_state = self.save_lexer_state()
        let saved_token = self.current
        self.expect_lpar()
        if self.check(Else) {
          // Explicit (else ...) form
          used_explicit_syntax = true
          let _ = self.advance()
          let instrs = self.parse_instructions()
          self.expect_rpar()
          instrs
        } else {
          // Not an else block, rollback
          self.restore_lexer_state(saved_state)
          self.current = saved_token
          if self.match_token(Else) {
            self.parse_block_body()
          } else {
            []
          }
        }
      } else if self.match_token(Else) {
        // Bare else keyword in flat form
        self.parse_block_body()
      } else {
        []
      }

      // Only expect 'end' for flat form (no explicit then/else blocks)
      if not(used_explicit_syntax) {
        let _ = self.expect(End, "expected 'end'")

      }
      Some(If(block_type, then_body, else_body))
    }
    Opcode(op) => {
      let _ = self.advance()
      Some(self.parse_opcode_instruction(op))
    }
    _ => None
  }
}

///|
fn WastParser::parse_block_body(
  self : WastParser,
) -> Array[Instruction] raise ParserError {
  let instrs : Array[Instruction] = []
  while true {
    match self.current.token_type {
      End | Else | Then | Eof => break
      Lpar => {
        let saved_state = self.save_lexer_state()
        let saved_token = self.current
        self.expect_lpar()

        // Check for (then or (else which shouldn't be parsed as instructions
        if self.check(Then) || self.check(Else) {
          self.restore_lexer_state(saved_state)
          self.current = saved_token
          break
        }
        let folded = self.parse_folded_instruction()
        for instr in folded {
          instrs.push(instr)
        }
        self.expect_rpar()
      }
      _ =>
        match self.try_parse_plain_instruction() {
          Some(instr) => instrs.push(instr)
          None => break
        }
    }
  }
  instrs
}

///|
fn WastParser::parse_opcode_instruction(
  self : WastParser,
  op : Opcode,
) -> Instruction raise ParserError {
  match op {
    // Control
    Unreachable => Unreachable
    Nop => Nop
    Br => Br(self.parse_index())
    BrIf => BrIf(self.parse_index())
    BrTable => {
      let indices : Array[Index] = []
      while self.current.token_type is (Nat | Var) {
        indices.push(self.parse_index())
      }
      if indices.length() == 0 {
        raise Custom("br_table requires at least one index")
      }
      let default = indices.pop().unwrap()
      BrTable(indices, default)
    }
    Return => Return
    Call => Call(self.parse_index())
    CallIndirect => {
      let table_index = self.try_parse_index().unwrap_or(Index::Num(0))
      let type_use = self.parse_type_use()
      CallIndirect(table_index, type_use)
    }

    // Parametric
    Drop => Drop
    Select => {
      // Check for typed select
      let types : Array[ValueType]? = if self.check(Lpar) {
        let saved_state = self.save_lexer_state()
        let saved_token = self.current
        self.expect_lpar()
        if self.check(Result) {
          let _ = self.advance()
          let ts : Array[ValueType] = []
          while self.current.token_type is ValueType(_) {
            ts.push(self.parse_value_type())
          }
          self.expect_rpar()
          Some(ts)
        } else {
          self.restore_lexer_state(saved_state)
          self.current = saved_token
          None
        }
      } else {
        None
      }
      Select(types)
    }

    // Variable
    LocalGet => LocalGet(self.parse_index())
    LocalSet => LocalSet(self.parse_index())
    LocalTee => LocalTee(self.parse_index())
    GlobalGet => GlobalGet(self.parse_index())
    GlobalSet => GlobalSet(self.parse_index())

    // Table
    TableGet => TableGet(self.try_parse_index().unwrap_or(Index::Num(0)))
    TableSet => TableSet(self.try_parse_index().unwrap_or(Index::Num(0)))
    TableSize => TableSize(self.try_parse_index().unwrap_or(Index::Num(0)))
    TableGrow => TableGrow(self.try_parse_index().unwrap_or(Index::Num(0)))
    TableFill => TableFill(self.try_parse_index().unwrap_or(Index::Num(0)))
    TableCopy => {
      let dst = self.try_parse_index().unwrap_or(Index::Num(0))
      let src = self.try_parse_index().unwrap_or(Index::Num(0))
      TableCopy(dst, src)
    }
    TableInit => {
      // table.init can have either:
      //   table.init elemidx           -> table defaults to 0
      //   table.init tableidx elemidx  -> explicit table index
      let first = self.try_parse_index()
      match first {
        Some(idx1) => {
          let second = self.try_parse_index()
          match second {
            Some(idx2) => TableInit(idx1, idx2) // tableidx, elemidx
            None => TableInit(Index::Num(0), idx1) // default table 0, elemidx
          }
        }
        None => raise Custom("table.init requires at least one index")
      }
    }
    ElemDrop => ElemDrop(self.parse_index())

    // Memory
    I32Load => Load(op, self.parse_mem_arg(4))
    I64Load => Load(op, self.parse_mem_arg(8))
    F32Load => Load(op, self.parse_mem_arg(4))
    F64Load => Load(op, self.parse_mem_arg(8))
    I32Load8S | I32Load8U => Load(op, self.parse_mem_arg(1))
    I32Load16S | I32Load16U => Load(op, self.parse_mem_arg(2))
    I64Load8S | I64Load8U => Load(op, self.parse_mem_arg(1))
    I64Load16S | I64Load16U => Load(op, self.parse_mem_arg(2))
    I64Load32S | I64Load32U => Load(op, self.parse_mem_arg(4))
    I32Store => Store(op, self.parse_mem_arg(4))
    I64Store => Store(op, self.parse_mem_arg(8))
    F32Store => Store(op, self.parse_mem_arg(4))
    F64Store => Store(op, self.parse_mem_arg(8))
    I32Store8 | I64Store8 => Store(op, self.parse_mem_arg(1))
    I32Store16 | I64Store16 => Store(op, self.parse_mem_arg(2))
    I64Store32 => Store(op, self.parse_mem_arg(4))
    MemorySize => MemorySize
    MemoryGrow => MemoryGrow
    MemoryFill => MemoryFill
    MemoryCopy => MemoryCopy
    MemoryInit => MemoryInit(self.parse_index())
    DataDrop => DataDrop(self.parse_index())

    // Const
    I32Const | I64Const => {
      let token = self.advance()
      let text = match token.token_type {
        Nat | Int => self.get_literal_text(token)
        _ => "0"
      }
      Const(op, text)
    }
    F32Const | F64Const => {
      let token = self.advance()
      let text = match token.token_type {
        Nat | Int | Float => self.get_literal_text(token)
        _ => "0"
      }
      Const(op, text)
    }

    // Unary
    I32Clz
    | I32Ctz
    | I32Popcnt
    | I64Clz
    | I64Ctz
    | I64Popcnt
    | F32Abs
    | F32Neg
    | F32Ceil
    | F32Floor
    | F32Trunc
    | F32Nearest
    | F32Sqrt
    | F64Abs
    | F64Neg
    | F64Ceil
    | F64Floor
    | F64Trunc
    | F64Nearest
    | F64Sqrt
    | I32Extend8S
    | I32Extend16S
    | I64Extend8S
    | I64Extend16S
    | I64Extend32S => Unary(op)

    // Binary
    I32Add
    | I32Sub
    | I32Mul
    | I32DivS
    | I32DivU
    | I32RemS
    | I32RemU
    | I32And
    | I32Or
    | I32Xor
    | I32Shl
    | I32ShrS
    | I32ShrU
    | I32Rotl
    | I32Rotr
    | I64Add
    | I64Sub
    | I64Mul
    | I64DivS
    | I64DivU
    | I64RemS
    | I64RemU
    | I64And
    | I64Or
    | I64Xor
    | I64Shl
    | I64ShrS
    | I64ShrU
    | I64Rotl
    | I64Rotr
    | F32Add
    | F32Sub
    | F32Mul
    | F32Div
    | F32Min
    | F32Max
    | F32Copysign
    | F64Add
    | F64Sub
    | F64Mul
    | F64Div
    | F64Min
    | F64Max
    | F64Copysign => Binary(op)

    // Test
    I32Eqz | I64Eqz => Test(op)

    // Compare
    I32Eq
    | I32Ne
    | I32LtS
    | I32LtU
    | I32GtS
    | I32GtU
    | I32LeS
    | I32LeU
    | I32GeS
    | I32GeU
    | I64Eq
    | I64Ne
    | I64LtS
    | I64LtU
    | I64GtS
    | I64GtU
    | I64LeS
    | I64LeU
    | I64GeS
    | I64GeU
    | F32Eq
    | F32Ne
    | F32Lt
    | F32Gt
    | F32Le
    | F32Ge
    | F64Eq
    | F64Ne
    | F64Lt
    | F64Gt
    | F64Le
    | F64Ge => Compare(op)

    // Conversion
    I32WrapI64
    | I32TruncF32S
    | I32TruncF32U
    | I32TruncF64S
    | I32TruncF64U
    | I64ExtendI32S
    | I64ExtendI32U
    | I64TruncF32S
    | I64TruncF32U
    | I64TruncF64S
    | I64TruncF64U
    | F32ConvertI32S
    | F32ConvertI32U
    | F32ConvertI64S
    | F32ConvertI64U
    | F32DemoteF64
    | F64ConvertI32S
    | F64ConvertI32U
    | F64ConvertI64S
    | F64ConvertI64U
    | F64PromoteF32
    | I32ReinterpretF32
    | I64ReinterpretF64
    | F32ReinterpretI32
    | F64ReinterpretI64
    | I32TruncSatF32S
    | I32TruncSatF32U
    | I32TruncSatF64S
    | I32TruncSatF64U
    | I64TruncSatF32S
    | I64TruncSatF32U
    | I64TruncSatF64S
    | I64TruncSatF64U => Convert(op)

    // Reference
    RefNull => {
      let vt = self.parse_value_type()
      RefNull(vt)
    }
    RefIsNull => RefIsNull
    RefFunc => RefFunc(self.parse_index())

    // SIMD - delegate to SIMD parser
    _ => self.parse_simd_instruction(op)
  }
}

// ============================================================================
// Module Field Parsing
// ============================================================================

///|
fn WastParser::parse_type_def(self : WastParser) -> TypeDef raise ParserError {
  let _ = self.expect(Type, "expected 'type'")
  let id : String? = if self.current.token_type is Var {
    let token = self.advance()
    Some(self.get_text(token))
  } else {
    None
  }

  // (func ...)
  self.expect_lpar()
  let _ = self.expect(Func, "expected 'func'")
  let params : Array[ValueType] = []
  let results : Array[ValueType] = []

  // Parse params
  while self.check(Lpar) {
    let saved_state = self.save_lexer_state()
    let saved_token = self.current
    self.expect_lpar()
    if self.check(Param) {
      let _ = self.advance()
      if self.current.token_type is Var {
        let _ = self.advance()
        params.push(self.parse_value_type())
      } else {
        while self.current.token_type is ValueType(_) {
          params.push(self.parse_value_type())
        }
      }
      self.expect_rpar()
    } else {
      self.restore_lexer_state(saved_state)
      self.current = saved_token
      break
    }
  }

  // Parse results
  while self.check(Lpar) {
    let saved_state = self.save_lexer_state()
    let saved_token = self.current
    self.expect_lpar()
    if self.check(Result) {
      let _ = self.advance()
      while self.current.token_type is ValueType(_) {
        results.push(self.parse_value_type())
      }
      self.expect_rpar()
    } else {
      self.restore_lexer_state(saved_state)
      self.current = saved_token
      break
    }
  }
  self.expect_rpar() // close func
  { id, func_type: { params, results } }
}

///|
fn WastParser::parse_inline_exports(
  self : WastParser,
) -> Array[InlineExport] raise ParserError {
  let exports : Array[InlineExport] = []
  while self.check(Lpar) {
    let saved_state = self.save_lexer_state()
    let saved_token = self.current
    self.expect_lpar()
    if self.check(Export) {
      let _ = self.advance()
      let name_token = self.expect(Text, "expected export name")
      let name = self.get_text(name_token)
      // Remove quotes from string
      let cleaned = if name.length() >= 2 {
        name.sub(start=1, end=name.length() - 1).to_string() catch {
          _ => name
        }
      } else {
        name
      }
      exports.push(InlineExport::Export(cleaned))
      self.expect_rpar()
    } else {
      self.restore_lexer_state(saved_state)
      self.current = saved_token
      break
    }
  }
  exports
}

///|
fn WastParser::parse_func(self : WastParser) -> Func raise ParserError {
  let _ = self.expect(Func, "expected 'func'")
  let id : String? = if self.current.token_type is Var {
    let token = self.advance()
    Some(self.get_text(token))
  } else {
    None
  }
  let exports = self.parse_inline_exports()
  let type_use = self.parse_type_use()

  // Parse locals
  let locals : Array[Local] = []
  while self.check(Lpar) {
    let saved_state = self.save_lexer_state()
    let saved_token = self.current
    self.expect_lpar()
    if self.check(Local) {
      let _ = self.advance()
      if self.current.token_type is Var {
        let id_token = self.advance()
        let local_id : String? = Some(self.get_text(id_token))
        let vt = self.parse_value_type()
        locals.push({ id: local_id, val_type: vt })
      } else {
        while self.current.token_type is ValueType(_) {
          let vt = self.parse_value_type()
          locals.push({ id: None, val_type: vt })
        }
      }
      self.expect_rpar()
    } else {
      self.restore_lexer_state(saved_state)
      self.current = saved_token
      break
    }
  }
  let body = self.parse_instructions()
  { id, exports, type_use, locals, body }
}

///|
fn WastParser::parse_table(self : WastParser) -> Table raise ParserError {
  let _ = self.expect(Table, "expected 'table'")
  let id : String? = if self.current.token_type is Var {
    let token = self.advance()
    Some(self.get_text(token))
  } else {
    None
  }
  let exports = self.parse_inline_exports()
  let limits = self.parse_limits()
  let elem_type = self.parse_value_type()
  { id, exports, table_type: { limits, elem_type } }
}

///|
fn WastParser::parse_memory(self : WastParser) -> Memory raise ParserError {
  let _ = self.expect(Memory, "expected 'memory'")
  let id : String? = if self.current.token_type is Var {
    let token = self.advance()
    Some(self.get_text(token))
  } else {
    None
  }
  let exports = self.parse_inline_exports()
  let limits = self.parse_limits()
  { id, exports, memory_type: limits }
}

///|
fn WastParser::parse_global(self : WastParser) -> Global raise ParserError {
  let _ = self.expect(Global, "expected 'global'")
  let id : String? = if self.current.token_type is Var {
    let token = self.advance()
    Some(self.get_text(token))
  } else {
    None
  }
  let exports = self.parse_inline_exports()

  // Parse global type
  let (val_type, mutable_) = if self.check(Lpar) {
    let saved_state = self.save_lexer_state()
    let saved_token = self.current
    self.expect_lpar()
    if self.check(Mut) {
      let _ = self.advance()
      let vt = self.parse_value_type()
      self.expect_rpar()
      (vt, true)
    } else {
      self.restore_lexer_state(saved_state)
      self.current = saved_token
      (self.parse_value_type(), false)
    }
  } else {
    (self.parse_value_type(), false)
  }
  let init = self.parse_instructions()
  { id, exports, global_type: { val_type, mutable_ }, init }
}

///|
fn WastParser::parse_import(self : WastParser) -> Import raise ParserError {
  let _ = self.expect(Import, "expected 'import'")
  let module_token = self.expect(Text, "expected module name")
  let module_name = self.strip_quotes(self.get_text(module_token))
  let field_token = self.expect(Text, "expected field name")
  let field_name = self.strip_quotes(self.get_text(field_token))
  self.expect_lpar()
  let (desc, id) = match self.current.token_type {
    Func => {
      let _ = self.advance()
      let func_id : String? = if self.current.token_type is Var {
        let token = self.advance()
        Some(self.get_text(token))
      } else {
        None
      }
      let type_use = self.parse_type_use()
      (ImportDesc::Func(type_use), func_id)
    }
    Table => {
      let _ = self.advance()
      let table_id : String? = if self.current.token_type is Var {
        let token = self.advance()
        Some(self.get_text(token))
      } else {
        None
      }
      let limits = self.parse_limits()
      let elem_type = self.parse_value_type()
      (ImportDesc::Table({ limits, elem_type }), table_id)
    }
    Memory => {
      let _ = self.advance()
      let mem_id : String? = if self.current.token_type is Var {
        let token = self.advance()
        Some(self.get_text(token))
      } else {
        None
      }
      let limits = self.parse_limits()
      (ImportDesc::Memory(limits), mem_id)
    }
    Global => {
      let _ = self.advance()
      let global_id : String? = if self.current.token_type is Var {
        let token = self.advance()
        Some(self.get_text(token))
      } else {
        None
      }
      let (val_type, mutable_) = if self.check(Lpar) {
        self.expect_lpar()
        let _ = self.expect(Mut, "expected 'mut'")
        let vt = self.parse_value_type()
        self.expect_rpar()
        (vt, true)
      } else {
        (self.parse_value_type(), false)
      }
      (ImportDesc::Global({ val_type, mutable_ }), global_id)
    }
    _ => raise UnexpectedToken(self.current, "expected import descriptor")
  }
  self.expect_rpar()
  { module_name, field_name, desc, id }
}

///|
fn WastParser::parse_export(self : WastParser) -> Export raise ParserError {
  let _ = self.expect(Export, "expected 'export'")
  let name_token = self.expect(Text, "expected export name")
  let name = self.strip_quotes(self.get_text(name_token))
  self.expect_lpar()
  let desc = match self.current.token_type {
    Func => {
      let _ = self.advance()
      ExportDesc::Func(self.parse_index())
    }
    Table => {
      let _ = self.advance()
      ExportDesc::Table(self.parse_index())
    }
    Memory => {
      let _ = self.advance()
      ExportDesc::Memory(self.parse_index())
    }
    Global => {
      let _ = self.advance()
      ExportDesc::Global(self.parse_index())
    }
    _ => raise UnexpectedToken(self.current, "expected export descriptor")
  }
  self.expect_rpar()
  { name, desc }
}

///|
pub fn WastParser::parse_script(
  self : WastParser,
) -> WastScript raise ParserError {
  let commands : Array[WastCommand] = []
  while not(self.check(Eof)) {
    self.expect_lpar()
    let cmd = self.parse_command()
    commands.push(cmd)
    self.expect_rpar()
  }
  { commands, }
}

///|
fn WastParser::parse_command(
  self : WastParser,
) -> WastCommand raise ParserError {
  match self.current.token_type {
    Module => self.parse_module_command()
    Register => self.parse_register_command()
    Invoke => WastCommand::Action(self.parse_action())
    Get => WastCommand::Action(self.parse_action())
    AssertReturn => self.parse_assert_return()
    AssertTrap => self.parse_assert_trap()
    AssertExhaustion => self.parse_assert_exhaustion()
    AssertMalformed => self.parse_assert_malformed()
    AssertInvalid => self.parse_assert_invalid()
    AssertUnlinkable => self.parse_assert_unlinkable()
    _ => raise UnexpectedToken(self.current, "expected WAST command")
  }
}

///|
fn WastParser::parse_module_command(
  self : WastParser,
) -> WastCommand raise ParserError {
  let _ = self.expect(Module, "expected 'module'")

  // Check for optional module id
  let id : String? = if self.current.token_type is Var {
    let token = self.advance()
    Some(self.get_text(token))
  } else {
    None
  }

  // Check for binary or quote form
  match self.current.token_type {
    Binary => {
      let _ = self.advance()
      let data = self.parse_data_strings()
      WastCommand::ModuleBinary(id, data)
    }
    Quote => {
      let _ = self.advance()
      let strings = self.parse_quote_strings()
      WastCommand::ModuleQuote(id, strings)
    }
    _ => {
      // Regular module - parse fields
      let fields : Array[ModuleField] = []
      while self.check(Lpar) {
        self.expect_lpar()
        fields.push(self.parse_module_field())
        self.expect_rpar()
      }
      WastCommand::Module({ id, fields })
    }
  }
}

///|
fn WastParser::parse_data_strings(self : WastParser) -> Bytes {
  let buf = @buffer.new()
  while self.check(Text) {
    let token = self.advance()
    let text = self.get_text(token)
    let decoded = self.decode_string(text)
    buf.write_bytes(decoded)
  }
  buf.to_bytes()
}

///|
fn WastParser::parse_quote_strings(self : WastParser) -> Array[String] {
  let strings : Array[String] = []
  while self.check(Text) {
    let token = self.advance()
    strings.push(self.strip_quotes(self.get_text(token)))
  }
  strings
}

///|
fn WastParser::parse_register_command(
  self : WastParser,
) -> WastCommand raise ParserError {
  let _ = self.expect(Register, "expected 'register'")
  let name_token = self.expect(Text, "expected register name")
  let name = self.strip_quotes(self.get_text(name_token))
  let module_id : String? = if self.current.token_type is Var {
    let token = self.advance()
    Some(self.get_text(token))
  } else {
    None
  }
  WastCommand::Register(name, module_id)
}

///|
fn WastParser::parse_action(
  self : WastParser,
) -> WastActionType raise ParserError {
  match self.current.token_type {
    Invoke => {
      let _ = self.advance()
      let module_name : String? = if self.current.token_type is Var {
        let token = self.advance()
        Some(self.get_text(token))
      } else {
        None
      }
      let name_token = self.expect(Text, "expected function name")
      let name = self.strip_quotes(self.get_text(name_token))
      let args = self.parse_wast_values()
      WastActionType::Invoke({ module_name, name, args })
    }
    Get => {
      let _ = self.advance()
      let module_name : String? = if self.current.token_type is Var {
        let token = self.advance()
        Some(self.get_text(token))
      } else {
        None
      }
      let name_token = self.expect(Text, "expected global name")
      let name = self.strip_quotes(self.get_text(name_token))
      WastActionType::Get(module_name, name)
    }
    _ => raise UnexpectedToken(self.current, "expected 'invoke' or 'get'")
  }
}

///|
fn WastParser::parse_wast_values(
  self : WastParser,
) -> Array[WastValue] raise ParserError {
  let values : Array[WastValue] = []
  while self.check(Lpar) {
    self.expect_lpar()
    let value = self.parse_wast_value()
    values.push(value)
    self.expect_rpar()
  }
  values
}

///|
fn WastParser::parse_wast_value(
  self : WastParser,
) -> WastValue raise ParserError {
  match self.current.token_type {
    Opcode(I32Const) => {
      let _ = self.advance()
      let token = self.advance()
      WastValue::I32(self.get_literal_text(token))
    }
    Opcode(I64Const) => {
      let _ = self.advance()
      let token = self.advance()
      WastValue::I64(self.get_literal_text(token))
    }
    Opcode(F32Const) => {
      let _ = self.advance()
      let token = self.advance()
      WastValue::F32(self.get_literal_text(token))
    }
    Opcode(F64Const) => {
      let _ = self.advance()
      let token = self.advance()
      WastValue::F64(self.get_literal_text(token))
    }
    Opcode(RefNull) => {
      let _ = self.advance()
      let vt = self.parse_value_type()
      WastValue::RefNull(vt)
    }
    Opcode(RefFunc) => {
      let _ = self.advance()
      WastValue::RefFunc
    }
    _ => raise UnexpectedToken(self.current, "expected const instruction")
  }
}

///|
fn WastParser::parse_wast_results(
  self : WastParser,
) -> Array[WastResult] raise ParserError {
  let results : Array[WastResult] = []
  while self.check(Lpar) {
    self.expect_lpar()
    let result = self.parse_wast_result()
    results.push(result)
    self.expect_rpar()
  }
  results
}

///|
fn WastParser::parse_wast_result(
  self : WastParser,
) -> WastResult raise ParserError {
  match self.current.token_type {
    Opcode(I32Const) => {
      let _ = self.advance()
      let token = self.advance()
      WastResult::Value(WastValue::I32(self.get_literal_text(token)))
    }
    Opcode(I64Const) => {
      let _ = self.advance()
      let token = self.advance()
      WastResult::Value(WastValue::I64(self.get_literal_text(token)))
    }
    Opcode(F32Const) => {
      let _ = self.advance()
      let token = self.advance()
      let text = self.get_literal_text(token)
      if text == "nan:canonical" {
        WastResult::F32NanCanonical
      } else if text == "nan:arithmetic" {
        WastResult::F32NanArithmetic
      } else {
        WastResult::Value(WastValue::F32(text))
      }
    }
    Opcode(F64Const) => {
      let _ = self.advance()
      let token = self.advance()
      let text = self.get_literal_text(token)
      if text == "nan:canonical" {
        WastResult::F64NanCanonical
      } else if text == "nan:arithmetic" {
        WastResult::F64NanArithmetic
      } else {
        WastResult::Value(WastValue::F64(text))
      }
    }
    Opcode(RefNull) => {
      let _ = self.advance()
      let vt : ValueType? = if self.current.token_type is ValueType(_) {
        Some(self.parse_value_type())
      } else {
        None
      }
      WastResult::RefNull(vt)
    }
    Opcode(RefFunc) => {
      let _ = self.advance()
      WastResult::RefFunc
    }
    // ref.extern result
    _ => raise UnexpectedToken(self.current, "expected result value")
  }
}

///|
fn WastParser::parse_assert_return(
  self : WastParser,
) -> WastCommand raise ParserError {
  let _ = self.expect(AssertReturn, "expected 'assert_return'")
  self.expect_lpar()
  let action = self.parse_action()
  self.expect_rpar()
  let results = self.parse_wast_results()
  WastCommand::AssertReturn(action, results)
}

///|
fn WastParser::parse_assert_trap(
  self : WastParser,
) -> WastCommand raise ParserError {
  let _ = self.expect(AssertTrap, "expected 'assert_trap'")
  self.expect_lpar()

  // Can be either an action or a module
  if self.check(Invoke) || self.check(Get) {
    let action = self.parse_action()
    self.expect_rpar()
    let msg_token = self.expect(Text, "expected trap message")
    let msg = self.strip_quotes(self.get_text(msg_token))
    WastCommand::AssertTrap(action, msg)
  } else {
    // Module trap - treat as module definition that traps on instantiation
    let module_def = self.parse_module_def()
    self.expect_rpar()
    let msg_token = self.expect(Text, "expected trap message")
    let msg = self.strip_quotes(self.get_text(msg_token))
    // For module traps, we use AssertTrap with a dummy action
    // This could be refined with a separate AST variant
    WastCommand::AssertUnlinkable(module_def, msg)
  }
}

///|
fn WastParser::parse_assert_exhaustion(
  self : WastParser,
) -> WastCommand raise ParserError {
  let _ = self.expect(AssertExhaustion, "expected 'assert_exhaustion'")
  self.expect_lpar()
  let action = self.parse_action()
  self.expect_rpar()
  let msg_token = self.expect(Text, "expected exhaustion message")
  let msg = self.strip_quotes(self.get_text(msg_token))
  WastCommand::AssertExhaustion(action, msg)
}

///|
fn WastParser::parse_module_def(
  self : WastParser,
) -> WastModuleDef raise ParserError {
  let _ = self.expect(Module, "expected 'module'")

  // Skip optional id
  if self.current.token_type is Var {
    let _ = self.advance()

  }
  match self.current.token_type {
    Binary => {
      let _ = self.advance()
      let data = self.parse_data_strings()
      WastModuleDef::Binary(data)
    }
    Quote => {
      let _ = self.advance()
      let strings = self.parse_quote_strings()
      WastModuleDef::Quote(strings)
    }
    _ => {
      let fields : Array[ModuleField] = []
      while self.check(Lpar) {
        self.expect_lpar()
        fields.push(self.parse_module_field())
        self.expect_rpar()
      }
      WastModuleDef::Inline({ id: None, fields })
    }
  }
}

///|
fn WastParser::parse_assert_malformed(
  self : WastParser,
) -> WastCommand raise ParserError {
  let _ = self.expect(AssertMalformed, "expected 'assert_malformed'")
  self.expect_lpar()
  let module_def = self.parse_module_def()
  self.expect_rpar()
  let msg_token = self.expect(Text, "expected error message")
  let msg = self.strip_quotes(self.get_text(msg_token))
  WastCommand::AssertMalformed(module_def, msg)
}

///|
fn WastParser::parse_assert_invalid(
  self : WastParser,
) -> WastCommand raise ParserError {
  let _ = self.expect(AssertInvalid, "expected 'assert_invalid'")
  self.expect_lpar()
  let module_def = self.parse_module_def()
  self.expect_rpar()
  let msg_token = self.expect(Text, "expected error message")
  let msg = self.strip_quotes(self.get_text(msg_token))
  WastCommand::AssertInvalid(module_def, msg)
}

///|
fn WastParser::parse_assert_unlinkable(
  self : WastParser,
) -> WastCommand raise ParserError {
  let _ = self.expect(AssertUnlinkable, "expected 'assert_unlinkable'")
  self.expect_lpar()
  let module_def = self.parse_module_def()
  self.expect_rpar()
  let msg_token = self.expect(Text, "expected error message")
  let msg = self.strip_quotes(self.get_text(msg_token))
  WastCommand::AssertUnlinkable(module_def, msg)
}

///|
fn WastParser::parse_start(self : WastParser) -> Start raise ParserError {
  let _ = self.expect(Start, "expected 'start'")
  let func_index = self.parse_index()
  Start::{ func_index, }
}

///|
fn WastParser::parse_data(self : WastParser) -> DataSegment raise ParserError {
  let _ = self.expect(Data, "expected 'data'")
  let id : String? = if self.current.token_type is Var {
    let token = self.advance()
    Some(self.get_text(token))
  } else {
    None
  }

  // Memory index (optional, defaults to 0)
  let memory_index = self.try_parse_index().unwrap_or(Index::Num(0))

  // Offset expression
  let offset = if self.check(Lpar) {
    self.expect_lpar()
    if self.check(Offset) {
      let _ = self.advance()

    }
    let instrs = self.parse_instructions()
    self.expect_rpar()
    instrs
  } else {
    []
  }

  // Data string(s)
  let data_bytes = @buffer.new()
  while self.check(Text) {
    let token = self.advance()
    let text = self.get_text(token)
    let decoded = self.decode_string(text)
    data_bytes.write_bytes(decoded)
  }
  { id, memory_index, offset, data: data_bytes.to_bytes() }
}

///|
fn WastParser::parse_elem(self : WastParser) -> ElemSegment raise ParserError {
  let _ = self.expect(Elem, "expected 'elem'")
  let id : String? = if self.current.token_type is Var {
    let token = self.advance()
    Some(self.get_text(token))
  } else {
    None
  }
  let table_index = self.try_parse_index().unwrap_or(Index::Num(0))

  // Offset expression
  let offset = if self.check(Lpar) {
    self.expect_lpar()
    if self.check(Offset) {
      let _ = self.advance()

    }
    let instrs = self.parse_instructions()
    self.expect_rpar()
    instrs
  } else {
    []
  }

  // Function indices
  let func_indices : Array[Index] = []
  while self.current.token_type is (Nat | Var) {
    func_indices.push(self.parse_index())
  }
  { id, table_index, offset, func_indices }
}

// ============================================================================
// Module Parsing
// ============================================================================

///|
fn WastParser::parse_module_field(
  self : WastParser,
) -> ModuleField raise ParserError {
  match self.current.token_type {
    Type => ModuleField::TypeField(self.parse_type_def())
    Func => ModuleField::FuncField(self.parse_func())
    Table => ModuleField::TableField(self.parse_table())
    Memory => ModuleField::MemoryField(self.parse_memory())
    Global => ModuleField::GlobalField(self.parse_global())
    Import => ModuleField::ImportField(self.parse_import())
    Export => ModuleField::ExportField(self.parse_export())
    Start => ModuleField::StartField(self.parse_start())
    Elem => ModuleField::ElemField(self.parse_elem())
    Data => ModuleField::DataField(self.parse_data())
    _ => raise UnexpectedToken(self.current, "expected module field")
  }
}

///|
fn WastParser::parse_v128_const(
  self : WastParser,
) -> V128Const raise ParserError {
  // v128.const can have multiple forms:
  // v128.const i8x16 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15
  // v128.const i16x8 0 1 2 3 4 5 6 7
  // v128.const i32x4 0 1 2 3
  // v128.const i64x2 0 1
  // v128.const f32x4 0.0 1.0 2.0 3.0
  // v128.const f64x2 0.0 1.0

  let shape = self.parse_simd_shape()
  let count = match shape {
    I8x16 => 16
    I16x8 => 8
    I32x4 => 4
    I64x2 => 2
    F32x4 => 4
    F64x2 => 2
  }
  let values : Array[String] = []
  for i = 0; i < count; i = i + 1 {
    let token = self.advance()
    let text = match token.token_type {
      Nat | Int | Float => self.get_literal_text(token)
      _ => raise UnexpectedToken(token, "expected numeric literal")
    }
    values.push(text)
  }
  { shape, values }
}

///|
fn WastParser::parse_simd_shape(
  self : WastParser,
) -> SimdShape raise ParserError {
  match self.current.token_type {
    SimdShapeToken(shape) => {
      let _ = self.advance()
      shape
    }
    _ =>
      raise UnexpectedToken(
        self.current,
        "expected SIMD shape (i8x16, i16x8, etc.)",
      )
  }
}

///|
fn WastParser::parse_lane_index(self : WastParser) -> UInt raise ParserError {
  let token = self.expect(Nat, "expected lane index")
  parse_uint(self.get_literal_text(token))
}

///|
fn WastParser::parse_shuffle_lanes(
  self : WastParser,
) -> ShuffleLanes raise ParserError {
  let lanes : FixedArray[UInt] = FixedArray::make(16, 0U)
  for i = 0; i < 16; i = i + 1 {
    let token = self.expect(Nat, "expected shuffle lane index")
    lanes[i] = parse_uint(self.get_literal_text(token))
  }
  { lanes, }
}

///|
fn WastParser::parse_simd_mem_arg(
  self : WastParser,
  default_align : UInt,
) -> MemArg {
  self.parse_mem_arg(default_align)
}

///|
fn WastParser::parse_simd_instruction(
  self : WastParser,
  op : Opcode,
) -> Instruction raise ParserError {
  match op {
    // V128 Const
    V128Const => {
      let v128_const = self.parse_v128_const()
      V128Const(v128_const)
    }

    // V128 Memory - Load
    V128Load => V128Load(self.parse_simd_mem_arg(16))
    V128Load8x8S => V128Load8x8S(self.parse_simd_mem_arg(8))
    V128Load8x8U => V128Load8x8U(self.parse_simd_mem_arg(8))
    V128Load16x4S => V128Load16x4S(self.parse_simd_mem_arg(8))
    V128Load16x4U => V128Load16x4U(self.parse_simd_mem_arg(8))
    V128Load32x2S => V128Load32x2S(self.parse_simd_mem_arg(8))
    V128Load32x2U => V128Load32x2U(self.parse_simd_mem_arg(8))
    V128Load8Splat => V128Load8Splat(self.parse_simd_mem_arg(1))
    V128Load16Splat => V128Load16Splat(self.parse_simd_mem_arg(2))
    V128Load32Splat => V128Load32Splat(self.parse_simd_mem_arg(4))
    V128Load64Splat => V128Load64Splat(self.parse_simd_mem_arg(8))
    V128Load32Zero => V128Load32Zero(self.parse_simd_mem_arg(4))
    V128Load64Zero => V128Load64Zero(self.parse_simd_mem_arg(8))
    V128Store => V128Store(self.parse_simd_mem_arg(16))

    // V128 Memory - Lane operations
    V128Load8Lane => {
      let memarg = self.parse_simd_mem_arg(1)
      let lane = self.parse_lane_index()
      V128Load8Lane(memarg, lane)
    }
    V128Load16Lane => {
      let memarg = self.parse_simd_mem_arg(2)
      let lane = self.parse_lane_index()
      V128Load16Lane(memarg, lane)
    }
    V128Load32Lane => {
      let memarg = self.parse_simd_mem_arg(4)
      let lane = self.parse_lane_index()
      V128Load32Lane(memarg, lane)
    }
    V128Load64Lane => {
      let memarg = self.parse_simd_mem_arg(8)
      let lane = self.parse_lane_index()
      V128Load64Lane(memarg, lane)
    }
    V128Store8Lane => {
      let memarg = self.parse_simd_mem_arg(1)
      let lane = self.parse_lane_index()
      V128Store8Lane(memarg, lane)
    }
    V128Store16Lane => {
      let memarg = self.parse_simd_mem_arg(2)
      let lane = self.parse_lane_index()
      V128Store16Lane(memarg, lane)
    }
    V128Store32Lane => {
      let memarg = self.parse_simd_mem_arg(4)
      let lane = self.parse_lane_index()
      V128Store32Lane(memarg, lane)
    }
    V128Store64Lane => {
      let memarg = self.parse_simd_mem_arg(8)
      let lane = self.parse_lane_index()
      V128Store64Lane(memarg, lane)
    }

    // Shuffle
    I8x16Shuffle => {
      let lanes = self.parse_shuffle_lanes()
      I8x16Shuffle(lanes)
    }
    I8x16Swizzle => I8x16Swizzle

    // Splat
    I8x16Splat => I8x16Splat
    I16x8Splat => I16x8Splat
    I32x4Splat => I32x4Splat
    I64x2Splat => I64x2Splat
    F32x4Splat => F32x4Splat
    F64x2Splat => F64x2Splat

    // Extract lane
    I8x16ExtractLaneS => I8x16ExtractLaneS(self.parse_lane_index())
    I8x16ExtractLaneU => I8x16ExtractLaneU(self.parse_lane_index())
    I16x8ExtractLaneS => I16x8ExtractLaneS(self.parse_lane_index())
    I16x8ExtractLaneU => I16x8ExtractLaneU(self.parse_lane_index())
    I32x4ExtractLane => I32x4ExtractLane(self.parse_lane_index())
    I64x2ExtractLane => I64x2ExtractLane(self.parse_lane_index())
    F32x4ExtractLane => F32x4ExtractLane(self.parse_lane_index())
    F64x2ExtractLane => F64x2ExtractLane(self.parse_lane_index())

    // Replace lane
    I8x16ReplaceLane => I8x16ReplaceLane(self.parse_lane_index())
    I16x8ReplaceLane => I16x8ReplaceLane(self.parse_lane_index())
    I32x4ReplaceLane => I32x4ReplaceLane(self.parse_lane_index())
    I64x2ReplaceLane => I64x2ReplaceLane(self.parse_lane_index())
    F32x4ReplaceLane => F32x4ReplaceLane(self.parse_lane_index())
    F64x2ReplaceLane => F64x2ReplaceLane(self.parse_lane_index())

    // Unary operations
    I8x16Abs
    | I8x16Neg
    | I8x16Popcnt
    | I16x8Abs
    | I16x8Neg
    | I32x4Abs
    | I32x4Neg
    | I64x2Abs
    | I64x2Neg
    | F32x4Abs
    | F32x4Neg
    | F32x4Sqrt
    | F32x4Ceil
    | F32x4Floor
    | F32x4Trunc
    | F32x4Nearest
    | F64x2Abs
    | F64x2Neg
    | F64x2Sqrt
    | F64x2Ceil
    | F64x2Floor
    | F64x2Trunc
    | F64x2Nearest
    | V128Not => SimdUnary(op)

    // Binary operations
    I8x16Add
    | I8x16AddSatS
    | I8x16AddSatU
    | I8x16Sub
    | I8x16SubSatS
    | I8x16SubSatU
    | I8x16MinS
    | I8x16MinU
    | I8x16MaxS
    | I8x16MaxU
    | I8x16AvgrU
    | I16x8Add
    | I16x8AddSatS
    | I16x8AddSatU
    | I16x8Sub
    | I16x8SubSatS
    | I16x8SubSatU
    | I16x8Mul
    | I16x8MinS
    | I16x8MinU
    | I16x8MaxS
    | I16x8MaxU
    | I16x8AvgrU
    | I16x8Q15mulrSatS
    | I32x4Add
    | I32x4Sub
    | I32x4Mul
    | I32x4MinS
    | I32x4MinU
    | I32x4MaxS
    | I32x4MaxU
    | I32x4DotI16x8S
    | I64x2Add
    | I64x2Sub
    | I64x2Mul
    | F32x4Add
    | F32x4Sub
    | F32x4Mul
    | F32x4Div
    | F32x4Min
    | F32x4Max
    | F32x4Pmin
    | F32x4Pmax
    | F64x2Add
    | F64x2Sub
    | F64x2Mul
    | F64x2Div
    | F64x2Min
    | F64x2Max
    | F64x2Pmin
    | F64x2Pmax
    | V128And
    | V128AndNot
    | V128Or
    | V128Xor
    | I8x16NarrowI16x8S
    | I8x16NarrowI16x8U
    | I16x8NarrowI32x4S
    | I16x8NarrowI32x4U
    | I16x8ExtmulLowI8x16S
    | I16x8ExtmulHighI8x16S
    | I16x8ExtmulLowI8x16U
    | I16x8ExtmulHighI8x16U
    | I32x4ExtmulLowI16x8S
    | I32x4ExtmulHighI16x8S
    | I32x4ExtmulLowI16x8U
    | I32x4ExtmulHighI16x8U
    | I64x2ExtmulLowI32x4S
    | I64x2ExtmulHighI32x4S
    | I64x2ExtmulLowI32x4U
    | I64x2ExtmulHighI32x4U => SimdBinary(op)

    // Ternary operations
    V128Bitselect
    | F32x4RelaxedMadd
    | F32x4RelaxedNmadd
    | F64x2RelaxedMadd
    | F64x2RelaxedNmadd
    | I8x16RelaxedLaneselect
    | I16x8RelaxedLaneselect
    | I32x4RelaxedLaneselect
    | I64x2RelaxedLaneselect => SimdTernary(op)

    // Shift operations
    I8x16Shl
    | I8x16ShrS
    | I8x16ShrU
    | I16x8Shl
    | I16x8ShrS
    | I16x8ShrU
    | I32x4Shl
    | I32x4ShrS
    | I32x4ShrU
    | I64x2Shl
    | I64x2ShrS
    | I64x2ShrU => SimdShift(op)

    // Test operations (return i32)
    V128AnyTrue
    | I8x16AllTrue
    | I8x16Bitmask
    | I16x8AllTrue
    | I16x8Bitmask
    | I32x4AllTrue
    | I32x4Bitmask
    | I64x2AllTrue
    | I64x2Bitmask => SimdTest(op)

    // Comparison operations
    I8x16Eq
    | I8x16Ne
    | I8x16LtS
    | I8x16LtU
    | I8x16GtS
    | I8x16GtU
    | I8x16LeS
    | I8x16LeU
    | I8x16GeS
    | I8x16GeU
    | I16x8Eq
    | I16x8Ne
    | I16x8LtS
    | I16x8LtU
    | I16x8GtS
    | I16x8GtU
    | I16x8LeS
    | I16x8LeU
    | I16x8GeS
    | I16x8GeU
    | I32x4Eq
    | I32x4Ne
    | I32x4LtS
    | I32x4LtU
    | I32x4GtS
    | I32x4GtU
    | I32x4LeS
    | I32x4LeU
    | I32x4GeS
    | I32x4GeU
    | I64x2Eq
    | I64x2Ne
    | I64x2LtS
    | I64x2GtS
    | I64x2LeS
    | I64x2GeS
    | F32x4Eq
    | F32x4Ne
    | F32x4Lt
    | F32x4Gt
    | F32x4Le
    | F32x4Ge
    | F64x2Eq
    | F64x2Ne
    | F64x2Lt
    | F64x2Gt
    | F64x2Le
    | F64x2Ge => SimdCompare(op)

    // Conversion operations
    I16x8ExtendLowI8x16S
    | I16x8ExtendHighI8x16S
    | I16x8ExtendLowI8x16U
    | I16x8ExtendHighI8x16U
    | I32x4ExtendLowI16x8S
    | I32x4ExtendHighI16x8S
    | I32x4ExtendLowI16x8U
    | I32x4ExtendHighI16x8U
    | I64x2ExtendLowI32x4S
    | I64x2ExtendHighI32x4S
    | I64x2ExtendLowI32x4U
    | I64x2ExtendHighI32x4U
    | I32x4TruncSatF32x4S
    | I32x4TruncSatF32x4U
    | I32x4TruncSatF64x2SZero
    | I32x4TruncSatF64x2UZero
    | F32x4ConvertI32x4S
    | F32x4ConvertI32x4U
    | F32x4DemoteF64x2Zero
    | F64x2ConvertLowI32x4S
    | F64x2ConvertLowI32x4U
    | F64x2PromoteLowF32x4 => SimdConvert(op)

    // Relaxed SIMD
    I8x16RelaxedSwizzle
    | I32x4RelaxedTruncF32x4S
    | I32x4RelaxedTruncF32x4U
    | I32x4RelaxedTruncF64x2SZero
    | I32x4RelaxedTruncF64x2UZero
    | F32x4RelaxedMin
    | F32x4RelaxedMax
    | F64x2RelaxedMin
    | F64x2RelaxedMax
    | I16x8RelaxedQ15mulrS
    | I16x8RelaxedDotI8x16I7x16S
    | I32x4RelaxedDotI8x16I7x16AddS => SimdRelaxed(op)
    _ => raise InvalidInstruction("unhandled SIMD opcode")
  }
}

///|
pub fn WastParser::parse_module(self : WastParser) -> Module raise ParserError {
  self.expect_lpar()
  let _ = self.expect(Module, "expected 'module'")
  let id : String? = if self.current.token_type is Var {
    let token = self.advance()
    Some(self.get_text(token))
  } else {
    None
  }
  let fields : Array[ModuleField] = []
  while self.check(Lpar) {
    self.expect_lpar()
    fields.push(self.parse_module_field())
    self.expect_rpar()
  }
  self.expect_rpar()
  { id, fields }
}

// ============================================================================
// Utility Functions
// ============================================================================

///|
fn WastParser::strip_quotes(_ : WastParser, s : String) -> String {
  if s.length() >= 2 && s[0] == '"' && s[s.length() - 1] == '"' {
    s.sub(start=1, end=s.length() - 1).to_string() catch {
      _ => s
    }
  } else {
    s
  }
}

///|
fn WastParser::decode_string(self : WastParser, s : String) -> Bytes {
  let buf = @buffer.new()
  let inner = self.strip_quotes(s)
  let mut i = 0
  while i < inner.length() {
    let c = inner[i]
    if c == '\\' && i + 1 < inner.length() {
      let next = inner[i + 1]
      match next {
        'n' => {
          buf.write_byte(b'\n')
          i += 2
        }
        't' => {
          buf.write_byte(b'\t')
          i += 2
        }
        'r' => {
          buf.write_byte(b'\r')
          i += 2
        }
        '"' => {
          buf.write_byte(b'"')
          i += 2
        }
        '\'' => {
          buf.write_byte(b'\'')
          i += 2
        }
        '\\' => {
          buf.write_byte(b'\\')
          i += 2
        }
        _ =>
          // Hex escape \XX
          if i + 2 < inner.length() {
            let h1 = hex_val(inner[i + 1].unsafe_to_char())
            let h2 = hex_val(inner[i + 2].unsafe_to_char())
            if h1 >= 0 && h2 >= 0 {
              buf.write_byte(((h1 << 4) | h2).to_byte())
              i += 3
            } else {
              buf.write_byte(c.to_int().to_byte())
              i += 1
            }
          } else {
            buf.write_byte(c.to_int().to_byte())
            i += 1
          }
      }
    } else {
      buf.write_byte(c.to_int().to_byte())
      i += 1
    }
  }
  buf.to_bytes()
}

///|
fn hex_val(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - 0x30
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 0x61 + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 0x41 + 10
  } else {
    -1
  }
}

///|
pub fn WastParser::has_errors(self : WastParser) -> Bool {
  self.errors.length() > 0 || self.lexer.has_errors()
}

///|
pub fn WastParser::get_errors(self : WastParser) -> Array[ParseError] {
  self.errors
}

// ============================================================================
// Helper for lexer - make fields accessible
// ============================================================================

// Note: You'll need to make these fields pub on WastLexer if not already:
// pub mut cursor : Int
// pub mut line : Int
// pub mut line_start : Int

// ============================================================================
// Tests
// ============================================================================

///|
test "parse simple module" {
  let source =
    #|(module
    #|  (func $add (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    i32.add))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let mod = parser.parse_module()
  assert_false(parser.has_errors())
  assert_eq(mod.fields.length(), 1)
}

///|
test "parse error struct can be constructed" {
  let err : ParseError = {
    location: { filename: "test", line: 1, first_column: 1, last_column: 1 },
    message: "example",
  }
  assert_eq(err.message, "example")
}

///|
test "parse function with locals" {
  let source =
    #|(module
    #|  (func $fib (param i32) (result i32)
    #|    (local i32 i32)
    #|    local.get 0
    #|    i32.const 2
    #|    i32.lt_s
    #|    if (result i32)
    #|      (then (local.get 0))
    #|      (else
    #|        (i32.add
    #|          (call $fib (i32.sub (local.get 0) (i32.const 1)))
    #|          (call $fib (i32.sub (local.get 0) (i32.const 2)))))))
    #|)
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse function with type reference" {
  let source =
    #|(module
    #|  (type $t0 (func (param i32) (result i32)))
    #|  (func $id (type $t0)
    #|    local.get 0))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let mod = parser.parse_module()
  assert_false(parser.has_errors())
  assert_eq(mod.fields.length(), 2)
}

///|
test "parse memory and data" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (data (i32.const 0) "hello"))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse import and export" {
  let source =
    #|(module
    #|  (import "env" "log" (func $log (param i32)))
    #|  (export "log" (func $log)))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ============================================================================
// Comprehensive Test Suite for WAST Parser
// ============================================================================

// ----------------------------------------------------------------------------
// Module Structure Tests
// ----------------------------------------------------------------------------

///|
test "parse empty module" {
  let source = "(module)"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let mod = parser.parse_module()
  assert_false(parser.has_errors())
  assert_eq(mod.id, None)
  assert_eq(mod.fields.length(), 0)
}

///|
test "parse named module" {
  let source = "(module $my_module)"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let mod = parser.parse_module()
  assert_false(parser.has_errors())
  assert_eq(mod.id, Some("$my_module"))
}

// ----------------------------------------------------------------------------
// Type Definition Tests
// ----------------------------------------------------------------------------

///|
test "parse type with no params no results" {
  let source = "(module (type $t (func)))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let mod = parser.parse_module()
  assert_false(parser.has_errors())
  assert_eq(mod.fields.length(), 1)
}

///|
test "parse type with params only" {
  let source = "(module (type $t (func (param i32) (param i64))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse type with results only" {
  let source = "(module (type $t (func (result i32))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse type with multiple params abbreviated" {
  let source = "(module (type $t (func (param i32 i64 f32 f64))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse type with multiple results" {
  let source = "(module (type $t (func (result i32 i64))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse type with named params" {
  let source = "(module (type $t (func (param $a i32) (param $b i64) (result i32))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Function Tests
// ----------------------------------------------------------------------------

///|
test "parse minimal function" {
  let source = "(module (func))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse named function" {
  let source = "(module (func $foo))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse function with inline export" {
  let source =
    #|(module (func $foo (export "foo")))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse function with multiple inline exports" {
  let source =
    #|(module (func $foo (export "foo") (export "bar")))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse a function with type reference" {
  let source =
    #|(module
    #|  (type $sig (func (param i32) (result i32)))
    #|  (func $f (type $sig) local.get 0))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse function with inline signature" {
  let source = "(module (func $add (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse function with named params" {
  let source = "(module (func $add (param $a i32) (param $b i32) (result i32) local.get $a local.get $b i32.add))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse another function with locals" {
  let source = "(module (func $f (local i32) (local i64 f32)))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse function with named locals" {
  let source = "(module (func $f (local $x i32) (local $y i64)))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Control Flow Tests - Block
// ----------------------------------------------------------------------------

///|
test "parse empty block flat" {
  let source = "(module (func block end))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse empty block folded" {
  let source = "(module (func (block)))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse named block" {
  let source = "(module (func (block $label nop)))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse block with result type" {
  let source = "(module (func (result i32) (block (result i32) i32.const 42)))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse block flat with instructions" {
  let source = "(module (func block nop nop end))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse nested blocks" {
  let source = "(module (func (block (block (block nop)))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Control Flow Tests - Loop
// ----------------------------------------------------------------------------

///|
test "parse empty loop flat" {
  let source = "(module (func loop end))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse empty loop folded" {
  let source = "(module (func (loop)))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse named loop with br" {
  let source = "(module (func (loop $continue (br $continue))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Control Flow Tests - If
// ----------------------------------------------------------------------------

///|
test "parse if flat no else" {
  let source = "(module (func (param i32) local.get 0 if nop end))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse if flat with else" {
  let source = "(module (func (param i32) local.get 0 if nop else nop end))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse if folded condition only" {
  let source = "(module (func (param i32) (if (local.get 0) (then nop))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse if folded with else" {
  let source = "(module (func (param i32) (if (local.get 0) (then nop) (else nop))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse if with result type" {
  let source = "(module (func (param i32) (result i32) (if (result i32) (local.get 0) (then (i32.const 1)) (else (i32.const 0)))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse nested if" {
  let source =
    #|(module (func (param i32 i32)
    #|  (if (local.get 0)
    #|    (then
    #|      (if (local.get 1)
    #|        (then nop)
    #|        (else nop)))
    #|    (else nop))))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Control Flow Tests - Branch
// ----------------------------------------------------------------------------

///|
test "parse br" {
  let source = "(module (func (block $exit (br $exit))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse br with numeric index" {
  let source = "(module (func (block (br 0))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse br_if" {
  let source = "(module (func (param i32) (block $exit (local.get 0) (br_if $exit))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse br_table" {
  let source = "(module (func (param i32) (block $a (block $b (local.get 0) (br_table $a $b $a)))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse return" {
  let source = "(module (func return))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Call Tests
// ----------------------------------------------------------------------------

///|
test "parse call" {
  let source = "(module (func $f) (func (call $f)))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse call with numeric index" {
  let source = "(module (func) (func (call 0)))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse call_indirect" {
  let source =
    #|(module
    #|  (type $sig (func (param i32) (result i32)))
    #|  (table 1 funcref)
    #|  (func (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 0
    #|    call_indirect (type $sig)))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Numeric Instruction Tests
// ----------------------------------------------------------------------------

///|
test "parse i32 const" {
  let source = "(module (func (result i32) i32.const 42))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse i32 const negative" {
  let source = "(module (func (result i32) i32.const -42))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse i32 const hex" {
  let source = "(module (func (result i32) i32.const 0x2a))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse i64 const" {
  let source = "(module (func (result i64) i64.const 9223372036854775807))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse f32 const" {
  let source = "(module (func (result f32) f32.const 3.14))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse f64 const" {
  let source = "(module (func (result f64) f64.const 3.141592653589793))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse i32 arithmetic" {
  let source = "(module (func (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse i32 arithmetic folded" {
  let source = "(module (func (param i32 i32) (result i32) (i32.add (local.get 0) (local.get 1))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse i32 all binary ops" {
  let source =
    #|(module (func (param i32 i32) (result i32)
    #|  (i32.add (local.get 0) (local.get 1))
    #|  (i32.sub (local.get 0) (local.get 1))
    #|  (i32.mul (local.get 0) (local.get 1))
    #|  (i32.div_s (local.get 0) (local.get 1))
    #|  (i32.div_u (local.get 0) (local.get 1))
    #|  (i32.rem_s (local.get 0) (local.get 1))
    #|  (i32.rem_u (local.get 0) (local.get 1))
    #|  (i32.and (local.get 0) (local.get 1))
    #|  (i32.or (local.get 0) (local.get 1))
    #|  (i32.xor (local.get 0) (local.get 1))
    #|  (i32.shl (local.get 0) (local.get 1))
    #|  (i32.shr_s (local.get 0) (local.get 1))
    #|  (i32.shr_u (local.get 0) (local.get 1))
    #|  (i32.rotl (local.get 0) (local.get 1))
    #|  (i32.rotr (local.get 0) (local.get 1))
    #|  drop drop drop drop drop drop drop drop drop drop drop drop drop drop
    #|  i32.const 0))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse i32 unary ops" {
  let source =
    #|(module (func (param i32) (result i32)
    #|  (i32.clz (local.get 0))
    #|  (i32.ctz (local.get 0))
    #|  (i32.popcnt (local.get 0))
    #|  drop drop
    #|  i32.const 0))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse i32 comparison ops" {
  let source =
    #|(module (func (param i32 i32) (result i32)
    #|  (i32.eq (local.get 0) (local.get 1))
    #|  (i32.ne (local.get 0) (local.get 1))
    #|  (i32.lt_s (local.get 0) (local.get 1))
    #|  (i32.lt_u (local.get 0) (local.get 1))
    #|  (i32.gt_s (local.get 0) (local.get 1))
    #|  (i32.gt_u (local.get 0) (local.get 1))
    #|  (i32.le_s (local.get 0) (local.get 1))
    #|  (i32.le_u (local.get 0) (local.get 1))
    #|  (i32.ge_s (local.get 0) (local.get 1))
    #|  (i32.ge_u (local.get 0) (local.get 1))
    #|  drop drop drop drop drop drop drop drop drop
    #|  i32.const 0))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse i32 eqz" {
  let source = "(module (func (param i32) (result i32) (i32.eqz (local.get 0))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse f32 ops" {
  let source =
    #|(module (func (param f32 f32) (result f32)
    #|  (f32.add (local.get 0) (local.get 1))
    #|  (f32.sub (local.get 0) (local.get 1))
    #|  (f32.mul (local.get 0) (local.get 1))
    #|  (f32.div (local.get 0) (local.get 1))
    #|  (f32.min (local.get 0) (local.get 1))
    #|  (f32.max (local.get 0) (local.get 1))
    #|  (f32.copysign (local.get 0) (local.get 1))
    #|  drop drop drop drop drop drop
    #|  f32.const 0))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse f32 unary ops" {
  let source =
    #|(module (func (param f32) (result f32)
    #|  (f32.abs (local.get 0))
    #|  (f32.neg (local.get 0))
    #|  (f32.ceil (local.get 0))
    #|  (f32.floor (local.get 0))
    #|  (f32.trunc (local.get 0))
    #|  (f32.nearest (local.get 0))
    #|  (f32.sqrt (local.get 0))
    #|  drop drop drop drop drop drop
    #|  f32.const 0))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Conversion Instruction Tests
// ----------------------------------------------------------------------------

///|
test "parse i32 wrap i64" {
  let source = "(module (func (param i64) (result i32) (i32.wrap_i64 (local.get 0))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse i64 extend i32" {
  let source =
    #|(module (func (param i32) (result i64)
    #|  (i64.extend_i32_s (local.get 0))
    #|  (i64.extend_i32_u (local.get 0))
    #|  drop
    #|  i64.const 0))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse float conversions" {
  let source =
    #|(module
    #|  (func (param i32) (result f32) (f32.convert_i32_s (local.get 0)))
    #|  (func (param i32) (result f32) (f32.convert_i32_u (local.get 0)))
    #|  (func (param f64) (result f32) (f32.demote_f64 (local.get 0)))
    #|  (func (param f32) (result f64) (f64.promote_f32 (local.get 0))))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse reinterpret" {
  let source =
    #|(module
    #|  (func (param f32) (result i32) (i32.reinterpret_f32 (local.get 0)))
    #|  (func (param i32) (result f32) (f32.reinterpret_i32 (local.get 0)))
    #|  (func (param f64) (result i64) (i64.reinterpret_f64 (local.get 0)))
    #|  (func (param i64) (result f64) (f64.reinterpret_i64 (local.get 0))))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse trunc sat" {
  let source =
    #|(module
    #|  (func (param f32) (result i32) (i32.trunc_sat_f32_s (local.get 0)))
    #|  (func (param f32) (result i32) (i32.trunc_sat_f32_u (local.get 0)))
    #|  (func (param f64) (result i32) (i32.trunc_sat_f64_s (local.get 0)))
    #|  (func (param f64) (result i32) (i32.trunc_sat_f64_u (local.get 0))))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse sign extension" {
  let source =
    #|(module (func (param i32 i64)
    #|  (i32.extend8_s (local.get 0))
    #|  (i32.extend16_s (local.get 0))
    #|  (i64.extend8_s (local.get 1))
    #|  (i64.extend16_s (local.get 1))
    #|  (i64.extend32_s (local.get 1))
    #|  drop drop drop drop drop))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Variable Instruction Tests
// ----------------------------------------------------------------------------

///|
test "parse local get set tee" {
  let source =
    #|(module (func (param i32) (local i32)
    #|  (local.get 0)
    #|  (local.set 1)
    #|  (local.tee 1 (i32.const 42))
    #|  drop))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse global get set" {
  let source =
    #|(module
    #|  (global $g (mut i32) (i32.const 0))
    #|  (func
    #|    (global.get $g)
    #|    (global.set $g)
    #|    (global.get 0)
    #|    (global.set 0)))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Memory Instruction Tests
// ----------------------------------------------------------------------------

///|
test "parse memory load store" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param i32)
    #|    (i32.load (local.get 0))
    #|    (i32.store (local.get 0))
    #|    (i64.load (local.get 0))
    #|    (i64.store (local.get 0))
    #|    drop drop))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse memory load with offset and align" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param i32) (result i32)
    #|    (i32.load offset=4 align=4 (local.get 0))))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse memory load partial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param i32)
    #|    (i32.load8_s (local.get 0))
    #|    (i32.load8_u (local.get 0))
    #|    (i32.load16_s (local.get 0))
    #|    (i32.load16_u (local.get 0))
    #|    (i64.load8_s (local.get 0))
    #|    (i64.load8_u (local.get 0))
    #|    (i64.load16_s (local.get 0))
    #|    (i64.load16_u (local.get 0))
    #|    (i64.load32_s (local.get 0))
    #|    (i64.load32_u (local.get 0))
    #|    drop drop drop drop drop drop drop drop drop drop))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse memory store partial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param i32 i64)
    #|    (i32.store8 (local.get 0) (local.get 0))
    #|    (i32.store16 (local.get 0) (local.get 0))
    #|    (i64.store8 (local.get 0) (local.get 1))
    #|    (i64.store16 (local.get 0) (local.get 1))
    #|    (i64.store32 (local.get 0) (local.get 1))))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse memory size and grow" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (result i32)
    #|    memory.size
    #|    (memory.grow (i32.const 1))
    #|    drop))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse memory fill copy" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func
    #|    (memory.fill (i32.const 0) (i32.const 0) (i32.const 100))
    #|    (memory.copy (i32.const 0) (i32.const 100) (i32.const 50))))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse memory init and data drop" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (data $d (i32.const 0) "hello")
    #|  (func
    #|    (memory.init $d (i32.const 0) (i32.const 0) (i32.const 5))
    #|    (data.drop $d)))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Table Instruction Tests
// ----------------------------------------------------------------------------

///|
test "parse table get set" {
  let source =
    #|(module
    #|  (table 1 funcref)
    #|  (func (param i32)
    #|    (table.get (local.get 0))
    #|    (table.set (local.get 0))
    #|    drop))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse table size grow fill" {
  let source =
    #|(module
    #|  (table 1 funcref)
    #|  (func
    #|    (table.size)
    #|    (table.grow (ref.null func) (i32.const 1))
    #|    drop drop))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse table copy init" {
  let source =
    #|(module
    #|  (table $t 10 funcref)
    #|  (elem $e (i32.const 0) $f)
    #|  (func $f)
    #|  (func
    #|    (table.copy (i32.const 0) (i32.const 5) (i32.const 5))
    #|    (table.init $e (i32.const 0) (i32.const 0) (i32.const 1))
    #|    (elem.drop $e)))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Reference Instruction Tests
// ----------------------------------------------------------------------------

///|
test "parse ref null" {
  let source = "(module (func (result funcref) (ref.null func)))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse ref is null" {
  let source = "(module (func (param funcref) (result i32) (ref.is_null (local.get 0))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse ref func" {
  let source =
    #|(module
    #|  (func $f)
    #|  (func (result funcref) (ref.func $f)))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Parametric Instruction Tests
// ----------------------------------------------------------------------------

///|
test "parse drop" {
  let source = "(module (func (i32.const 42) drop))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse select" {
  let source = "(module (func (param i32) (result i32) (select (i32.const 1) (i32.const 2) (local.get 0))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse typed select" {
  let source = "(module (func (param i32) (result i32) (select (result i32) (i32.const 1) (i32.const 2) (local.get 0))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Memory Definition Tests
// ----------------------------------------------------------------------------

///|
test "parse memory min only" {
  let source = "(module (memory 1))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse memory min max" {
  let source = "(module (memory 1 10))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse named memory" {
  let source = "(module (memory $mem 1))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse memory with inline export" {
  let source =
    #|(module (memory $mem (export "memory") 1))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Table Definition Tests
// ----------------------------------------------------------------------------

///|
test "parse table min only" {
  let source = "(module (table 1 funcref))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse table min max" {
  let source = "(module (table 1 10 funcref))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse named table" {
  let source = "(module (table $tbl 1 funcref))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse table with inline export" {
  let source =
    #|(module (table $tbl (export "table") 1 funcref))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Global Definition Tests
// ----------------------------------------------------------------------------

///|
test "parse immutable global" {
  let source = "(module (global i32 (i32.const 42)))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse mutable global" {
  let source = "(module (global (mut i32) (i32.const 42)))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse named global" {
  let source = "(module (global $g (mut i32) (i32.const 0)))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse global with inline export" {
  let source =
    #|(module (global $g (export "global") (mut i32) (i32.const 0)))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse global all types" {
  let source =
    #|(module
    #|  (global i32 (i32.const 0))
    #|  (global i64 (i64.const 0))
    #|  (global f32 (f32.const 0))
    #|  (global f64 (f64.const 0)))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Import Tests
// ----------------------------------------------------------------------------

///|
test "parse import func" {
  let source =
    #|(module (import "env" "log" (func $log (param i32))))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse import func with type" {
  let source =
    #|(module
    #|  (type $sig (func (param i32)))
    #|  (import "env" "log" (func $log (type $sig))))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse import memory" {
  let source =
    #|(module (import "env" "memory" (memory 1)))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse import table" {
  let source =
    #|(module (import "env" "table" (table 1 funcref)))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse import global immutable" {
  let source =
    #|(module (import "env" "g" (global i32)))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse import global mutable" {
  let source =
    #|(module (import "env" "g" (global (mut i32))))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Export Tests
// ----------------------------------------------------------------------------

///|
test "parse export func" {
  let source =
    #|(module (func $f) (export "f" (func $f)))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse export func by index" {
  let source =
    #|(module (func) (export "f" (func 0)))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse export memory" {
  let source =
    #|(module (memory 1) (export "mem" (memory 0)))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse export table" {
  let source =
    #|(module (table 1 funcref) (export "tbl" (table 0)))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse export global" {
  let source =
    #|(module (global i32 (i32.const 0)) (export "g" (global 0)))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Start Function Tests
// ----------------------------------------------------------------------------

///|
test "parse start by name" {
  let source = "(module (func $main) (start $main))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse start by index" {
  let source = "(module (func) (start 0))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Data Segment Tests
// ----------------------------------------------------------------------------

///|
test "parse data segment" {
  let source =
    #|(module (memory 1) (data (i32.const 0) "hello"))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse data segment with offset keyword" {
  let source =
    #|(module (memory 1) (data (offset (i32.const 0)) "hello"))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse named data segment" {
  let source =
    #|(module (memory 1) (data $d (i32.const 0) "hello"))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse data segment multiple strings" {
  let source =
    #|(module (memory 1) (data (i32.const 0) "hello" " " "world"))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse data segment with escapes" {
  let source =
    #|(module (memory 1) (data (i32.const 0) "hello\nworld\00"))|
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Element Segment Tests
// ----------------------------------------------------------------------------

///|
test "parse elem segment" {
  let source = "(module (table 1 funcref) (func $f) (elem (i32.const 0) $f))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse elem segment with offset keyword" {
  let source = "(module (table 1 funcref) (func $f) (elem (offset (i32.const 0)) $f))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse named elem segment" {
  let source = "(module (table 1 funcref) (func $f) (elem $e (i32.const 0) $f))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse elem segment multiple funcs" {
  let source = "(module (table 3 funcref) (func $a) (func $b) (func $c) (elem (i32.const 0) $a $b $c))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse elem segment by index" {
  let source = "(module (table 1 funcref) (func) (elem (i32.const 0) 0))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Complex Expression Tests
// ----------------------------------------------------------------------------

///|
test "parse deeply nested folded expressions" {
  let source =
    #|(module (func (result i32)
    #|  (i32.add
    #|    (i32.mul
    #|      (i32.const 2)
    #|      (i32.const 3))
    #|    (i32.sub
    #|      (i32.const 10)
    #|      (i32.const 4)))))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse mixed flat and folded" {
  let source =
    #|(module (func (param i32) (result i32)
    #|  local.get 0
    #|  (i32.add (i32.const 1))
    #|  i32.const 2
    #|  i32.mul))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse fibonacci recursive" {
  let source =
    #|(module
    #|  (func $fib (param $n i32) (result i32)
    #|    (if (result i32) (i32.lt_s (local.get $n) (i32.const 2))
    #|      (then (local.get $n))
    #|      (else
    #|        (i32.add
    #|          (call $fib (i32.sub (local.get $n) (i32.const 1)))
    #|          (call $fib (i32.sub (local.get $n) (i32.const 2))))))))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse factorial iterative" {
  let source =
    #|(module
    #|  (func $fact (param $n i32) (result i32)
    #|    (local $result i32)
    #|    (local.set $result (i32.const 1))
    #|    (block $exit
    #|      (loop $loop
    #|        (br_if $exit (i32.le_s (local.get $n) (i32.const 1)))
    #|        (local.set $result (i32.mul (local.get $result) (local.get $n)))
    #|        (local.set $n (i32.sub (local.get $n) (i32.const 1)))
    #|        (br $loop)))
    #|    (local.get $result)))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// Complete Module Tests
// ----------------------------------------------------------------------------

///|
test "parse complete module with all sections" {
  let source =
    #|(module $complete
    #|  ;; Types
    #|  (type $unary (func (param i32) (result i32)))
    #|  (type $binary (func (param i32 i32) (result i32)))
    #|
    #|  ;; Imports
    #|  (import "env" "log" (func $log (param i32)))
    #|  (import "env" "memory" (memory $mem 1))
    #|
    #|  ;; Table
    #|  (table $tbl 2 funcref)
    #|
    #|  ;; Globals
    #|  (global $counter (mut i32) (i32.const 0))
    #|  (global $max i32 (i32.const 100))
    #|
    #|  ;; Functions
    #|  (func $inc (type $unary)
    #|    (i32.add (local.get 0) (i32.const 1)))
    #|
    #|  (func $add (type $binary)
    #|    (i32.add (local.get 0) (local.get 1)))
    #|
    #|  (func $main
    #|    (call $log (call $inc (i32.const 41))))
    #|
    #|  ;; Element segment
    #|  (elem (i32.const 0) $inc $add)
    #|
    #|  ;; Data segment
    #|  (data (i32.const 0) "Hello, World!")
    #|
    #|  ;; Exports
    #|  (export "inc" (func $inc))
    #|  (export "add" (func $add))
    #|  (export "table" (table $tbl))
    #|  (export "counter" (global $counter))
    #|
    #|  ;; Start
    #|  (start $main))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let mod = parser.parse_module()
  assert_false(parser.has_errors())
  assert_eq(mod.id, Some("$complete"))
}

// ----------------------------------------------------------------------------
// Edge Case Tests
// ----------------------------------------------------------------------------

///|
test "parse hex integers" {
  let source = "(module (func (result i32) i32.const 0xDEADBEEF))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse underscore in numbers" {
  let source = "(module (func (result i32) i32.const 1_000_000))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse empty block in if" {
  let source = "(module (func (param i32) (if (local.get 0) (then) (else))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse unreachable and nop" {
  let source = "(module (func unreachable) (func nop))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse many fields in module" {
  let source =
    #|(module
    #|  (func) (func) (func) (func) (func)
    #|  (func) (func) (func) (func) (func))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let mod = parser.parse_module()
  assert_false(parser.has_errors())
  assert_eq(mod.fields.length(), 10)
}

///|
test "parse function with many params" {
  let source = "(module (func (param i32 i32 i32 i32 i32 i32 i32 i32)))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse f32 special values" {
  let source =
    #|(module
    #|  (func (result f32) f32.const inf)
    #|  (func (result f32) f32.const -inf)
    #|  (func (result f32) f32.const nan))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse f64 special values" {
  let source =
    #|(module
    #|  (func (result f64) f64.const inf)
    #|  (func (result f64) f64.const -inf)
    #|  (func (result f64) f64.const nan))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

// ----------------------------------------------------------------------------
// If Statement Variations
// ----------------------------------------------------------------------------

///|
test "parse if flat form simple" {
  let source =
    #|(module (func (param i32)
    #|  local.get 0
    #|  if
    #|    nop
    #|  end))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse if flat form with else" {
  let source =
    #|(module (func (param i32)
    #|  local.get 0
    #|  if
    #|    nop
    #|  else
    #|    nop
    #|  end))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse if flat form with result" {
  let source =
    #|(module (func (param i32) (result i32)
    #|  local.get 0
    #|  if (result i32)
    #|    i32.const 1
    #|  else
    #|    i32.const 0
    #|  end))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse if folded with condition" {
  let source = "(module (func (param i32) (if (local.get 0) (then nop))))"
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse if folded complex condition" {
  let source =
    #|(module (func (param i32 i32)
    #|  (if (i32.and (local.get 0) (local.get 1))
    #|    (then nop)
    #|    (else nop))))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse if inside block" {
  let source =
    #|(module (func (param i32)
    #|  (block
    #|    (if (local.get 0)
    #|      (then (br 1))))))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}

///|
test "parse if inside loop" {
  let source =
    #|(module (func (param i32)
    #|  (loop $continue
    #|    (if (local.get 0)
    #|      (then (br $continue))))))
  let lexer = make_lexer(source)
  let parser = WastParser::new(lexer)
  let _ = parser.parse_module()
  assert_false(parser.has_errors())
}
