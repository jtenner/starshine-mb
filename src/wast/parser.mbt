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
  UnexpectedEof
  InvalidInstruction(String)
  InvalidType(String)
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
fn WastParser::error(self : WastParser, message : String) -> Unit {
  self.errors.push({ location: self.current.location, message })
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
      [Instruction::Block(block_type, body)]
    }
    Loop => {
      let _ = self.advance()
      let block_type = self.parse_block_type()
      let body = self.parse_instructions()
      [Instruction::Loop(block_type, body)]
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
      Some(Instruction::Block(block_type, body))
    }
    Loop => {
      let _ = self.advance()
      let block_type = self.parse_block_type()
      let body = self.parse_block_body()
      let _ = self.expect(End, "expected 'end'")
      Some(Instruction::Loop(block_type, body))
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
      Some(Instruction::If(block_type, then_body, else_body))
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
    Opcode::Unreachable => Instruction::Unreachable
    Opcode::Nop => Instruction::Nop
    Opcode::Br => Instruction::Br(self.parse_index())
    Opcode::BrIf => Instruction::BrIf(self.parse_index())
    Opcode::BrTable => {
      let indices : Array[Index] = []
      while self.current.token_type is (Nat | Var) {
        indices.push(self.parse_index())
      }
      if indices.length() == 0 {
        raise Custom("br_table requires at least one index")
      }
      let default = indices.pop().unwrap()
      Instruction::BrTable(indices, default)
    }
    Opcode::Return => Instruction::Return
    Opcode::Call => Instruction::Call(self.parse_index())
    Opcode::CallIndirect => {
      let table_index = self.try_parse_index().unwrap_or(Index::Num(0))
      let type_use = self.parse_type_use()
      Instruction::CallIndirect(table_index, type_use)
    }

    // Parametric
    Opcode::Drop => Instruction::Drop
    Opcode::Select => {
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
      Instruction::Select(types)
    }

    // Variable
    Opcode::LocalGet => Instruction::LocalGet(self.parse_index())
    Opcode::LocalSet => Instruction::LocalSet(self.parse_index())
    Opcode::LocalTee => Instruction::LocalTee(self.parse_index())
    Opcode::GlobalGet => Instruction::GlobalGet(self.parse_index())
    Opcode::GlobalSet => Instruction::GlobalSet(self.parse_index())

    // Table
    Opcode::TableGet =>
      Instruction::TableGet(self.try_parse_index().unwrap_or(Index::Num(0)))
    Opcode::TableSet =>
      Instruction::TableSet(self.try_parse_index().unwrap_or(Index::Num(0)))
    Opcode::TableSize =>
      Instruction::TableSize(self.try_parse_index().unwrap_or(Index::Num(0)))
    Opcode::TableGrow =>
      Instruction::TableGrow(self.try_parse_index().unwrap_or(Index::Num(0)))
    Opcode::TableFill =>
      Instruction::TableFill(self.try_parse_index().unwrap_or(Index::Num(0)))
    Opcode::TableCopy => {
      let dst = self.try_parse_index().unwrap_or(Index::Num(0))
      let src = self.try_parse_index().unwrap_or(Index::Num(0))
      Instruction::TableCopy(dst, src)
    }
    Opcode::TableInit => {
      // table.init can have either:
      //   table.init elemidx           -> table defaults to 0
      //   table.init tableidx elemidx  -> explicit table index
      let first = self.try_parse_index()
      match first {
        Some(idx1) => {
          let second = self.try_parse_index()
          match second {
            Some(idx2) => Instruction::TableInit(idx1, idx2) // tableidx, elemidx
            None => Instruction::TableInit(Index::Num(0), idx1) // default table 0, elemidx
          }
        }
        None => raise Custom("table.init requires at least one index")
      }
    }
    Opcode::ElemDrop => Instruction::ElemDrop(self.parse_index())

    // Memory
    Opcode::I32Load => Instruction::Load(op, self.parse_mem_arg(4))
    Opcode::I64Load => Instruction::Load(op, self.parse_mem_arg(8))
    Opcode::F32Load => Instruction::Load(op, self.parse_mem_arg(4))
    Opcode::F64Load => Instruction::Load(op, self.parse_mem_arg(8))
    Opcode::I32Load8S | Opcode::I32Load8U =>
      Instruction::Load(op, self.parse_mem_arg(1))
    Opcode::I32Load16S | Opcode::I32Load16U =>
      Instruction::Load(op, self.parse_mem_arg(2))
    Opcode::I64Load8S | Opcode::I64Load8U =>
      Instruction::Load(op, self.parse_mem_arg(1))
    Opcode::I64Load16S | Opcode::I64Load16U =>
      Instruction::Load(op, self.parse_mem_arg(2))
    Opcode::I64Load32S | Opcode::I64Load32U =>
      Instruction::Load(op, self.parse_mem_arg(4))
    Opcode::I32Store => Instruction::Store(op, self.parse_mem_arg(4))
    Opcode::I64Store => Instruction::Store(op, self.parse_mem_arg(8))
    Opcode::F32Store => Instruction::Store(op, self.parse_mem_arg(4))
    Opcode::F64Store => Instruction::Store(op, self.parse_mem_arg(8))
    Opcode::I32Store8 | Opcode::I64Store8 =>
      Instruction::Store(op, self.parse_mem_arg(1))
    Opcode::I32Store16 | Opcode::I64Store16 =>
      Instruction::Store(op, self.parse_mem_arg(2))
    Opcode::I64Store32 => Instruction::Store(op, self.parse_mem_arg(4))
    Opcode::MemorySize => Instruction::MemorySize
    Opcode::MemoryGrow => Instruction::MemoryGrow
    Opcode::MemoryFill => Instruction::MemoryFill
    Opcode::MemoryCopy => Instruction::MemoryCopy
    Opcode::MemoryInit => Instruction::MemoryInit(self.parse_index())
    Opcode::DataDrop => Instruction::DataDrop(self.parse_index())

    // Const
    Opcode::I32Const | Opcode::I64Const => {
      let token = self.advance()
      let text = match token.token_type {
        Nat | Int => self.get_literal_text(token)
        _ => "0"
      }
      Instruction::Const(op, text)
    }
    Opcode::F32Const | Opcode::F64Const => {
      let token = self.advance()
      let text = match token.token_type {
        Nat | Int | Float => self.get_literal_text(token)
        _ => "0"
      }
      Instruction::Const(op, text)
    }

    // Unary
    Opcode::I32Clz
    | Opcode::I32Ctz
    | Opcode::I32Popcnt
    | Opcode::I64Clz
    | Opcode::I64Ctz
    | Opcode::I64Popcnt
    | Opcode::F32Abs
    | Opcode::F32Neg
    | Opcode::F32Ceil
    | Opcode::F32Floor
    | Opcode::F32Trunc
    | Opcode::F32Nearest
    | Opcode::F32Sqrt
    | Opcode::F64Abs
    | Opcode::F64Neg
    | Opcode::F64Ceil
    | Opcode::F64Floor
    | Opcode::F64Trunc
    | Opcode::F64Nearest
    | Opcode::F64Sqrt
    | Opcode::I32Extend8S
    | Opcode::I32Extend16S
    | Opcode::I64Extend8S
    | Opcode::I64Extend16S
    | Opcode::I64Extend32S => Instruction::Unary(op)

    // Binary
    Opcode::I32Add
    | Opcode::I32Sub
    | Opcode::I32Mul
    | Opcode::I32DivS
    | Opcode::I32DivU
    | Opcode::I32RemS
    | Opcode::I32RemU
    | Opcode::I32And
    | Opcode::I32Or
    | Opcode::I32Xor
    | Opcode::I32Shl
    | Opcode::I32ShrS
    | Opcode::I32ShrU
    | Opcode::I32Rotl
    | Opcode::I32Rotr
    | Opcode::I64Add
    | Opcode::I64Sub
    | Opcode::I64Mul
    | Opcode::I64DivS
    | Opcode::I64DivU
    | Opcode::I64RemS
    | Opcode::I64RemU
    | Opcode::I64And
    | Opcode::I64Or
    | Opcode::I64Xor
    | Opcode::I64Shl
    | Opcode::I64ShrS
    | Opcode::I64ShrU
    | Opcode::I64Rotl
    | Opcode::I64Rotr
    | Opcode::F32Add
    | Opcode::F32Sub
    | Opcode::F32Mul
    | Opcode::F32Div
    | Opcode::F32Min
    | Opcode::F32Max
    | Opcode::F32Copysign
    | Opcode::F64Add
    | Opcode::F64Sub
    | Opcode::F64Mul
    | Opcode::F64Div
    | Opcode::F64Min
    | Opcode::F64Max
    | Opcode::F64Copysign => Instruction::Binary(op)

    // Test
    Opcode::I32Eqz | Opcode::I64Eqz => Instruction::Test(op)

    // Compare
    Opcode::I32Eq
    | Opcode::I32Ne
    | Opcode::I32LtS
    | Opcode::I32LtU
    | Opcode::I32GtS
    | Opcode::I32GtU
    | Opcode::I32LeS
    | Opcode::I32LeU
    | Opcode::I32GeS
    | Opcode::I32GeU
    | Opcode::I64Eq
    | Opcode::I64Ne
    | Opcode::I64LtS
    | Opcode::I64LtU
    | Opcode::I64GtS
    | Opcode::I64GtU
    | Opcode::I64LeS
    | Opcode::I64LeU
    | Opcode::I64GeS
    | Opcode::I64GeU
    | Opcode::F32Eq
    | Opcode::F32Ne
    | Opcode::F32Lt
    | Opcode::F32Gt
    | Opcode::F32Le
    | Opcode::F32Ge
    | Opcode::F64Eq
    | Opcode::F64Ne
    | Opcode::F64Lt
    | Opcode::F64Gt
    | Opcode::F64Le
    | Opcode::F64Ge => Instruction::Compare(op)

    // Conversion
    Opcode::I32WrapI64
    | Opcode::I32TruncF32S
    | Opcode::I32TruncF32U
    | Opcode::I32TruncF64S
    | Opcode::I32TruncF64U
    | Opcode::I64ExtendI32S
    | Opcode::I64ExtendI32U
    | Opcode::I64TruncF32S
    | Opcode::I64TruncF32U
    | Opcode::I64TruncF64S
    | Opcode::I64TruncF64U
    | Opcode::F32ConvertI32S
    | Opcode::F32ConvertI32U
    | Opcode::F32ConvertI64S
    | Opcode::F32ConvertI64U
    | Opcode::F32DemoteF64
    | Opcode::F64ConvertI32S
    | Opcode::F64ConvertI32U
    | Opcode::F64ConvertI64S
    | Opcode::F64ConvertI64U
    | Opcode::F64PromoteF32
    | Opcode::I32ReinterpretF32
    | Opcode::I64ReinterpretF64
    | Opcode::F32ReinterpretI32
    | Opcode::F64ReinterpretI64
    | Opcode::I32TruncSatF32S
    | Opcode::I32TruncSatF32U
    | Opcode::I32TruncSatF64S
    | Opcode::I32TruncSatF64U
    | Opcode::I64TruncSatF32S
    | Opcode::I64TruncSatF32U
    | Opcode::I64TruncSatF64S
    | Opcode::I64TruncSatF64U => Instruction::Convert(op)

    // Reference
    Opcode::RefNull => {
      let vt = self.parse_value_type()
      Instruction::RefNull(vt)
    }
    Opcode::RefIsNull => Instruction::RefIsNull
    Opcode::RefFunc => Instruction::RefFunc(self.parse_index())
    _ => raise InvalidInstruction("unknown opcode")
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
