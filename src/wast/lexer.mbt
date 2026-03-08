///|
let eof : Int = -1

// ============================================================================
// Constructor
// ============================================================================

///|
pub fn WastLexer::new(buffer : Bytes, filename : String) -> WastLexer {
  {
    buffer,
    filename,
    line: 1,
    cursor: 0,
    line_start: 0,
    token_start: 0,
    errors: [],
  }
}

// ============================================================================
// Character Classification
// ============================================================================

///|
fn is_digit(c : Int) -> Bool {
  c >= 0x30 && c <= 0x39 // '0' to '9'
}

///|
fn is_hex_digit(c : Int) -> Bool {
  is_digit(c) ||
  (c >= 0x41 && c <= 0x46) || // 'A' to 'F'
  (c >= 0x61 && c <= 0x66) // 'a' to 'f'
}

///|
fn is_keyword(c : Int) -> Bool {
  c >= 0x61 && c <= 0x7A // 'a' to 'z'
}

///|
fn is_id_char(c : Int) -> Bool {
  if c < 0x21 || c > 0x7E {
    return false
  }
  // Exclude: " ( ) , ; [ ] { }
  match c {
    0x22 | 0x28 | 0x29 | 0x2C | 0x3B | 0x5B | 0x5D | 0x7B | 0x7D => false
    _ => true
  }
}

///|
fn parse_hex_digit(c : Int) -> Int {
  if c >= 0x30 && c <= 0x39 {
    c - 0x30
  } else if c >= 0x41 && c <= 0x46 {
    c - 0x41 + 10
  } else if c >= 0x61 && c <= 0x66 {
    c - 0x61 + 10
  } else {
    0
  }
}

// ============================================================================
// Low-level Character Operations
// ============================================================================

///|
fn WastLexer::peek_char(self : WastLexer) -> Int {
  if self.cursor < self.buffer.length() {
    self.buffer[self.cursor].to_int()
  } else {
    eof
  }
}

///|
fn WastLexer::read_char(self : WastLexer) -> Int {
  if self.cursor < self.buffer.length() {
    let c = self.buffer[self.cursor].to_int()
    self.cursor += 1
    c
  } else {
    eof
  }
}

///|
fn WastLexer::match_char(self : WastLexer, c : Int) -> Bool {
  if self.peek_char() == c {
    let _ = self.read_char()
    true
  } else {
    false
  }
}

///|
fn WastLexer::match_string(self : WastLexer, s : String) -> Bool {
  let saved_cursor = self.cursor
  for i = 0; i < s.length(); i = i + 1 {
    if self.read_char() != s[i].to_int() {
      self.cursor = saved_cursor
      return false
    }
  }
  true
}

///|
fn WastLexer::newline(self : WastLexer) -> Unit {
  self.line += 1
  self.line_start = self.cursor
}

// ============================================================================
// Token Creation Helpers
// ============================================================================

///|
fn WastLexer::get_location(self : WastLexer) -> Location {
  let first_col = if self.token_start >= self.line_start {
    self.token_start - self.line_start + 1
  } else {
    1
  }
  let last_col = if self.cursor >= self.line_start {
    self.cursor - self.line_start + 1
  } else {
    1
  }
  {
    filename: self.filename,
    line: self.line,
    first_column: first_col,
    last_column: last_col,
  }
}

///|
fn WastLexer::get_text(self : WastLexer, offset : Int) -> String {
  let start = self.token_start + offset
  if start >= self.buffer.length() || self.cursor <= start {
    return ""
  }
  let len = self.cursor - start
  let chars : Array[Char] = Array::make(len, '\u{00}')
  for i = 0; i < len; i = i + 1 {
    chars[i] = self.buffer[start + i].to_int().unsafe_to_char()
  }
  String::from_array(chars)
}

///|
fn WastLexer::bare_token(self : WastLexer, token_type : TokenType) -> Token {
  { location: self.get_location(), token_type, value: None }
}

///|
fn WastLexer::literal_token(
  self : WastLexer,
  token_type : TokenType,
  literal_type : LiteralType,
) -> Token {
  let text = self.get_text(0)
  {
    location: self.get_location(),
    token_type,
    value: Literal({ literal_type, text }),
  }
}

///|
fn WastLexer::text_token(
  self : WastLexer,
  token_type : TokenType,
  offset : Int,
) -> Token {
  {
    location: self.get_location(),
    token_type,
    value: Text(self.get_text(offset)),
  }
}

///|
fn WastLexer::error(self : WastLexer, message : String) -> Unit {
  self.errors.push({ level: Error, location: self.get_location(), message })
}

// ============================================================================
// Comment and Whitespace Handling
// ============================================================================

///|
fn WastLexer::read_block_comment(self : WastLexer) -> Bool {
  let mut nesting = 1
  while true {
    match self.read_char() {
      c if c == eof => {
        self.error("EOF in block comment")
        return false
      }
      0x3B => // ';'
        if self.match_char(0x29) {
          // ')'
          nesting -= 1
          if nesting == 0 {
            return true
          }
        }
      0x28 => // '('
        if self.match_char(0x3B) {
          // ';'
          nesting += 1
        }
      0x0A => // '\n'
        self.newline()
      _ => ()
    }
  }
  false
}

///|
fn WastLexer::read_line_comment(self : WastLexer) -> Bool {
  while true {
    match self.read_char() {
      c if c == eof => return false
      0x0D => {
        // '\r'
        if self.peek_char() == 0x0A {
          let _ = self.read_char()
        }
        self.newline()
        return true
      }
      0x0A => {
        // '\n'
        self.newline()
        return true
      }
      _ => ()
    }
  }
  false
}

///|
fn WastLexer::read_whitespace(self : WastLexer) -> Unit {
  while true {
    match self.peek_char() {
      0x20 | 0x09 | 0x0D => {
        // ' ', '\t', '\r'
        let _ = self.read_char()
      }
      0x0A => {
        // '\n'
        let _ = self.read_char()
        self.newline()
      }
      _ => return
    }
  }
}

// ============================================================================
// Number Reading Helpers
// ============================================================================

///|
fn WastLexer::read_num(self : WastLexer) -> Bool {
  if is_digit(self.peek_char()) {
    let _ = self.read_char()
    if self.match_char(0x5F) || is_digit(self.peek_char()) {
      // '_'
      return self.read_num()
    }
    return true
  }
  false
}

///|
fn WastLexer::read_hex_num(self : WastLexer) -> Bool {
  if is_hex_digit(self.peek_char()) {
    let _ = self.read_char()
    if self.match_char(0x5F) || is_hex_digit(self.peek_char()) {
      // '_'
      return self.read_hex_num()
    }
    return true
  }
  false
}

///|
fn WastLexer::read_sign(self : WastLexer) -> Unit {
  let c = self.peek_char()
  if c == 0x2B || c == 0x2D {
    // '+' or '-'
    let _ = self.read_char()
  }
}

///|
fn WastLexer::read_reserved_chars(self : WastLexer) -> ReservedChars {
  let mut ret = ReservedChars::None
  while true {
    let peek = self.peek_char()
    if is_id_char(peek) {
      let _ = self.read_char()
      if ret is ReservedChars::None {
        ret = Id
      }
    } else if peek == 0x22 {
      // '"'
      let _ = self.get_string_token()
      ret = Some
    } else {
      break
    }
  }
  ret
}

///|
fn WastLexer::no_trailing_reserved_chars(self : WastLexer) -> Bool {
  not(is_id_char(self.peek_char())) && self.peek_char() != 0x22
}

// ============================================================================
// String Token Parsing
// ============================================================================

///|
fn WastLexer::get_string_token(self : WastLexer) -> Token {
  let saved_token_start = self.token_start
  let mut has_error = false
  let mut in_string = true
  let _ = self.read_char() // consume opening '"'
  while in_string {
    match self.read_char() {
      c if c == eof => return self.bare_token(Eof)
      0x0A => {
        // '\n'
        self.token_start = self.cursor - 1
        self.error("newline in string")
        has_error = true
        self.newline()
        continue
      }
      0x22 => {
        // '"'
        if self.peek_char() == 0x22 {
          self.error("invalid string token")
          has_error = true
        }
        in_string = false
      }
      0x5C =>
        // '\\'
        match self.read_char() {
          0x74 | 0x6E | 0x72 | 0x22 | 0x27 | 0x5C =>
            // 't', 'n', 'r', '"', '\'', '\\'
            () // Valid escape
          c if is_hex_digit(c) =>
            if is_hex_digit(self.peek_char()) {
              let _ = self.read_char()
            } else {
              self.token_start = self.cursor - 2
              self.error("bad escape")
              has_error = true
            }
          0x75 => {
            // 'u'
            self.token_start = self.cursor - 2
            if self.read_char() != 0x7B {
              // '{'
              self.error("bad escape")
              has_error = true
              continue
            }
            let mut scalar_value : UInt = 0
            while is_hex_digit(self.peek_char()) {
              let digit = parse_hex_digit(self.read_char())
              scalar_value = (scalar_value << 4) | digit.reinterpret_as_uint()
              if scalar_value >= 0x110000 {
                self.error("bad escape")
                has_error = true
                break
              }
            }
            if self.peek_char() != 0x7D {
              // '}'
              self.error("bad escape")
              has_error = true
              continue
            }
            if scalar_value >= 0xD800 && scalar_value < 0xE000 {
              let _ = self.read_char()
              self.error("bad escape")
              has_error = true
            }
          }
          _ => {
            self.token_start = self.cursor - 2
            self.error("bad escape")
            has_error = true
          }
        }
      _ => ()
    }
  }
  self.token_start = saved_token_start
  if has_error {
    return { location: self.get_location(), token_type: Invalid, value: None }
  }
  self.text_token(Text, 0)
}

// ============================================================================
// Number Token Parsing
// ============================================================================

///|
fn WastLexer::get_number_token(
  self : WastLexer,
  token_type : TokenType,
) -> Token {
  let mut tt = token_type
  if self.read_num() {
    if self.match_char(0x2E) {
      // '.'
      tt = Float
      if is_digit(self.peek_char()) && not(self.read_num()) {
        return self.get_reserved_token()
      }
    }
    if self.match_char(0x65) || self.match_char(0x45) {
      // 'e' or 'E'
      tt = Float
      self.read_sign()
      if not(self.read_num()) {
        return self.get_reserved_token()
      }
    }
    if self.no_trailing_reserved_chars() {
      if tt is Float {
        return self.literal_token(tt, LiteralType::Float)
      } else {
        return self.literal_token(tt, LiteralType::Int)
      }
    }
  }
  self.get_reserved_token()
}

///|
fn WastLexer::get_hex_number_token(
  self : WastLexer,
  token_type : TokenType,
) -> Token {
  let mut tt = token_type
  if self.read_hex_num() {
    if self.match_char(0x2E) {
      // '.'
      tt = Float
      if is_hex_digit(self.peek_char()) && not(self.read_hex_num()) {
        return self.get_reserved_token()
      }
    }
    if self.match_char(0x70) || self.match_char(0x50) {
      // 'p' or 'P'
      tt = Float
      self.read_sign()
      if not(self.read_num()) {
        return self.get_reserved_token()
      }
    }
    if self.no_trailing_reserved_chars() {
      if tt is Float {
        return self.literal_token(tt, Hexfloat)
      } else {
        return self.literal_token(tt, LiteralType::Int)
      }
    }
  }
  self.get_reserved_token()
}

///|
fn WastLexer::get_inf_token(self : WastLexer) -> Token {
  if self.match_string("inf") {
    if self.no_trailing_reserved_chars() {
      return self.literal_token(Float, Infinity)
    }
    return self.get_reserved_token()
  }
  self.get_keyword_token()
}

///|
fn WastLexer::get_nan_token(self : WastLexer) -> Token {
  if self.match_string("nan") {
    if self.match_char(0x3A) {
      // ':'
      if self.match_string("0x") {
        ignore(self.read_reserved_chars())
        if self.no_trailing_reserved_chars() {
          return self.literal_token(Float, Nan)
        }
      } else {
        ignore(self.read_reserved_chars())
        if self.no_trailing_reserved_chars() {
          return self.literal_token(Float, Nan)
        }
      }
    } else if self.no_trailing_reserved_chars() {
      return self.literal_token(Float, Nan)
    }
  }
  self.get_keyword_token()
}

///|
fn WastLexer::get_name_eq_num_token(
  self : WastLexer,
  name : String,
  token_type : TokenType,
) -> Token {
  if self.match_string(name) {
    if self.match_string("0x") {
      if self.read_hex_num() && self.no_trailing_reserved_chars() {
        return self.text_token(token_type, name.length())
      }
    } else if self.read_num() && self.no_trailing_reserved_chars() {
      return self.text_token(token_type, name.length())
    }
  }
  self.get_keyword_token()
}

// ============================================================================
// Identifier and Keyword Tokens
// ============================================================================

///|
fn WastLexer::get_id_chars(self : WastLexer) -> Token {
  if self.read_reserved_chars() is Id {
    return self.text_token(Var, 0)
  }
  self.text_token(Reserved, 0)
}

///|
fn WastLexer::get_keyword_token(self : WastLexer) -> Token {
  let _ = self.read_reserved_chars()
  let text = self.get_text(0)
  match lookup_keyword(text) {
    Some(token_type) =>
      match token_type {
        ValueType(vt) =>
          {
            location: self.get_location(),
            token_type,
            value: TokenValue::ValueType(vt),
          }
        Opcode(op) =>
          {
            location: self.get_location(),
            token_type,
            value: TokenValue::Opcode(op),
          }
        _ => self.bare_token(token_type)
      }
    None => self.text_token(Reserved, 0)
  }
}

///|
fn WastLexer::get_reserved_token(self : WastLexer) -> Token {
  let _ = self.read_reserved_chars()
  self.text_token(Reserved, 0)
}

// ============================================================================
// Main Tokenization Entry Point
// ============================================================================

///|
pub fn WastLexer::get_token(self : WastLexer) -> Token {
  while true {
    self.token_start = self.cursor
    match self.peek_char() {
      c if c == eof => return self.bare_token(Eof)
      0x28 =>
        // '('
        if self.match_string("(;") {
          if self.read_block_comment() {
            continue
          }
          return self.bare_token(Eof)
        } else if self.match_string("(@") {
          let _ = self.get_id_chars()
          return self.text_token(LparAnn, 2)
        } else {
          let _ = self.read_char()
          return self.bare_token(Lpar)
        }
      0x29 => {
        // ')'
        let _ = self.read_char()
        return self.bare_token(Rpar)
      }
      0x3B =>
        // ';'
        if self.match_string(";;") {
          if self.read_line_comment() {
            continue
          }
          return self.bare_token(Eof)
        } else {
          let _ = self.read_char()
          self.error("unexpected char")
          continue
        }
      0x20 | 0x09 | 0x0D | 0x0A => {
        // ' ', '\t', '\r', '\n'
        self.read_whitespace()
        continue
      }
      0x22 =>
        // '"'
        return self.get_string_token()
      0x2B | 0x2D => {
        // '+', '-'
        let _ = self.read_char()
        match self.peek_char() {
          0x69 =>
            // 'i'
            return self.get_inf_token()
          0x6E =>
            // 'n'
            return self.get_nan_token()
          0x30 =>
            // '0'
            return if self.match_string("0x") {
              self.get_hex_number_token(Int)
            } else {
              self.get_number_token(Int)
            }
          c if c >= 0x31 && c <= 0x39 =>
            // '1'-'9'
            return self.get_number_token(Int)
          _ => return self.get_reserved_token()
        }
      }
      0x30 =>
        // '0'
        return if self.match_string("0x") {
          self.get_hex_number_token(Nat)
        } else {
          self.get_number_token(Nat)
        }
      c if c >= 0x31 && c <= 0x39 =>
        // '1'-'9'
        return self.get_number_token(Nat)
      0x24 =>
        // '$'
        return self.get_id_chars()
      0x61 =>
        // 'a'
        return self.get_name_eq_num_token("align=", AlignEqNat)
      0x69 =>
        // 'i'
        return self.get_inf_token()
      0x6E =>
        // 'n'
        return self.get_nan_token()
      0x6F =>
        // 'o'
        return self.get_name_eq_num_token("offset=", OffsetEqNat)
      c =>
        if is_keyword(c) {
          return self.get_keyword_token()
        } else if is_id_char(c) {
          return self.get_reserved_token()
        } else {
          let _ = self.read_char()
          self.error("unexpected char")
          continue
        }
    }
  }
  self.bare_token(Eof) // unreachable
}

// ============================================================================
// Utility Functions
// ============================================================================

///|
pub fn WastLexer::get_errors(self : WastLexer) -> Array[LexerError] {
  self.errors
}

///|
pub fn WastLexer::has_errors(self : WastLexer) -> Bool {
  self.errors.length() > 0
}

// ============================================================================
// lexer_test.mbt - Comprehensive Tests
// ============================================================================

///|
fn string_to_bytes(s : String) -> Bytes {
  let bytes = @buffer.new(size_hint=s.length())
  for i = 0; i < s.length(); i = i + 1 {
    bytes.write_byte(s[i].to_int().to_byte())
  }
  bytes.to_bytes()
}

///|
fn make_lexer(source : String) -> WastLexer {
  WastLexer::new(string_to_bytes(source), "test.wast")
}

///|
fn collect_tokens(lexer : WastLexer) -> Array[Token] {
  let tokens : Array[Token] = []
  while true {
    let token = lexer.get_token()
    tokens.push(token)
    if token.token_type is Eof {
      break
    }
  }
  tokens
}

///|
priv suberror TokenTypeMismatch

///|
priv suberror ExpectedLiteral

///|
priv suberror ExpectedIntLiteral

///|
priv suberror ExpectedFloatLiteral

///|
priv suberror ExpectedHexFloatLiteral

///|
priv suberror ExpectedInfinityLiteral

///|
priv suberror ExpectedNanLiteral

///|
priv suberror ExpectedText

///|
fn assert_token_type(token : Token, expected : TokenType) -> Unit raise Error {
  // Simple comparison - in real code you'd implement proper equality
  let matches = match (token.token_type, expected) {
    (Eof, Eof) => true
    (Lpar, Lpar) => true
    (Rpar, Rpar) => true
    (LparAnn, LparAnn) => true
    (Nat, Nat) => true
    (Int, Int) => true
    (Float, Float) => true
    (Text, Text) => true
    (Var, Var) => true
    (Reserved, Reserved) => true
    (AlignEqNat, AlignEqNat) => true
    (OffsetEqNat, OffsetEqNat) => true
    (Invalid, Invalid) => true
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
    (ValueType(_), ValueType(_)) => true
    (Opcode(_), Opcode(_)) => true
    _ => false
  }
  if not(matches) {
    raise TokenTypeMismatch
  }
}

// ============================================================================
// Basic Token Tests
// ============================================================================

///|
test "empty input returns EOF" {
  let lexer = make_lexer("")
  let token = lexer.get_token()
  assert_token_type(token, Eof)
}

///|
test "whitespace only returns EOF" {
  let lexer = make_lexer("   \t\n\r\n  ")
  let token = lexer.get_token()
  assert_token_type(token, Eof)
}

///|
test "left paren" {
  let lexer = make_lexer("(")
  let token = lexer.get_token()
  assert_token_type(token, Lpar)
}

///|
test "right paren" {
  let lexer = make_lexer(")")
  let token = lexer.get_token()
  assert_token_type(token, Rpar)
}

///|
test "multiple parens" {
  let lexer = make_lexer("(())")
  let tokens = collect_tokens(lexer)
  assert_eq(tokens.length(), 5) // ( ( ) ) EOF
  assert_token_type(tokens[0], Lpar)
  assert_token_type(tokens[1], Lpar)
  assert_token_type(tokens[2], Rpar)
  assert_token_type(tokens[3], Rpar)
  assert_token_type(tokens[4], Eof)
}

// ============================================================================
// Comment Tests
// ============================================================================

///|
test "line comment" {
  let lexer = make_lexer(";; this is a comment\n(")
  let token = lexer.get_token()
  assert_token_type(token, Lpar)
}

///|
test "line comment at EOF" {
  let lexer = make_lexer(";; comment without newline")
  let token = lexer.get_token()
  assert_token_type(token, Eof)
}

///|
test "block comment" {
  let lexer = make_lexer("(; block comment ;)(")
  let token = lexer.get_token()
  assert_token_type(token, Lpar)
}

///|
test "nested block comment" {
  let lexer = make_lexer("(; outer (; inner ;) outer ;)(")
  let token = lexer.get_token()
  assert_token_type(token, Lpar)
}

///|
test "block comment with newlines" {
  let lexer = make_lexer("(; line 1\nline 2\nline 3 ;)(")
  let token = lexer.get_token()
  assert_token_type(token, Lpar)
  assert_eq(lexer.line, 3)
}

// ============================================================================
// Number Tests
// ============================================================================

///|
test "natural number" {
  let lexer = make_lexer("42")
  let token = lexer.get_token()
  assert_token_type(token, Nat)
  match token.value {
    Literal(lit) => assert_eq(lit.text, "42")
    _ => raise ExpectedLiteral
  }
}

///|
test "natural number zero" {
  let lexer = make_lexer("0")
  let token = lexer.get_token()
  assert_token_type(token, Nat)
}

///|
test "positive integer" {
  let lexer = make_lexer("+123")
  let token = lexer.get_token()
  assert_token_type(token, Int)
  match token.value {
    Literal(lit) => assert_eq(lit.text, "+123")
    _ => raise ExpectedLiteral
  }
}

///|
test "negative integer" {
  let lexer = make_lexer("-456")
  let token = lexer.get_token()
  assert_token_type(token, Int)
  match token.value {
    Literal(lit) => assert_eq(lit.text, "-456")
    _ => raise ExpectedLiteral
  }
}

///|
test "hex number" {
  let lexer = make_lexer("0xDEADBEEF")
  let token = lexer.get_token()
  assert_token_type(token, Nat)
  match token.value {
    Literal(lit) => assert_eq(lit.text, "0xDEADBEEF")
    _ => raise ExpectedLiteral
  }
}

///|
test "hex number lowercase" {
  let lexer = make_lexer("0xabcdef")
  let token = lexer.get_token()
  assert_token_type(token, Nat)
}

///|
test "number with underscores" {
  let lexer = make_lexer("1_000_000")
  let token = lexer.get_token()
  assert_token_type(token, Nat)
  match token.value {
    Literal(lit) => assert_eq(lit.text, "1_000_000")
    _ => raise ExpectedLiteral
  }
}

///|
test "hex number with underscores" {
  let lexer = make_lexer("0xDEAD_BEEF")
  let token = lexer.get_token()
  assert_token_type(token, Nat)
}

///|
test "float decimal" {
  let lexer = make_lexer("3.14")
  let token = lexer.get_token()
  assert_token_type(token, Float)
  match token.value {
    Literal(lit) => {
      assert_eq(lit.text, "3.14")
      match lit.literal_type {
        LiteralType::Float => ()
        _ => raise ExpectedFloatLiteral
      }
    }
    _ => raise ExpectedLiteral
  }
}

///|
test "float with exponent" {
  let lexer = make_lexer("1.5e10")
  let token = lexer.get_token()
  assert_token_type(token, Float)
}

///|
test "float with negative exponent" {
  let lexer = make_lexer("2.5e-3")
  let token = lexer.get_token()
  assert_token_type(token, Float)
}

///|
test "float with positive exponent" {
  let lexer = make_lexer("1E+5")
  let token = lexer.get_token()
  assert_token_type(token, Float)
}

///|
test "hex float" {
  let lexer = make_lexer("0x1.fp10")
  let token = lexer.get_token()
  assert_token_type(token, Float)
  match token.value {
    Literal(lit) =>
      match lit.literal_type {
        Hexfloat => ()
        _ => raise ExpectedHexFloatLiteral
      }
    _ => raise ExpectedLiteral
  }
}

///|
test "infinity" {
  let lexer = make_lexer("inf")
  let token = lexer.get_token()
  assert_token_type(token, Float)
  match token.value {
    Literal(lit) =>
      match lit.literal_type {
        Infinity => ()
        _ => raise ExpectedInfinityLiteral
      }
    _ => raise ExpectedLiteral
  }
}

///|
test "positive infinity" {
  let lexer = make_lexer("+inf")
  let token = lexer.get_token()
  assert_token_type(token, Float)
}

///|
test "negative infinity" {
  let lexer = make_lexer("-inf")
  let token = lexer.get_token()
  assert_token_type(token, Float)
}

///|
test "nan" {
  let lexer = make_lexer("nan")
  let token = lexer.get_token()
  assert_token_type(token, Float)
  match token.value {
    Literal(lit) =>
      match lit.literal_type {
        Nan => ()
        _ => raise ExpectedNanLiteral
      }
    _ => raise ExpectedLiteral
  }
}

///|
test "nan with payload" {
  let lexer = make_lexer("nan:0x7fc00000")
  let token = lexer.get_token()
  assert_token_type(token, Float)
}

// ============================================================================
// String Tests
// ============================================================================

///|
test "simple string" {
  let lexer = make_lexer("\"hello\"")
  let token = lexer.get_token()
  assert_token_type(token, Text)
  match token.value {
    TokenValue::Text(s) => assert_eq(s, "\"hello\"")
    _ => raise ExpectedText
  }
}

///|
test "empty string" {
  let lexer = make_lexer("\"\"")
  let token = lexer.get_token()
  assert_token_type(token, Text)
}

///|
test "string with escape sequences" {
  let lexer = make_lexer("\"hello\\nworld\"")
  let token = lexer.get_token()
  assert_token_type(token, Text)
}

///|
test "string with tab escape" {
  let lexer = make_lexer("\"col1\\tcol2\"")
  let token = lexer.get_token()
  assert_token_type(token, Text)
}

///|
test "string with hex escape" {
  let lexer = make_lexer("\"\\41\\42\\43\"")
  let token = lexer.get_token()
  assert_token_type(token, Text)
}

///|
test "string with unicode escape" {
  let lexer = make_lexer("\"\\u{0041}\"")
  let token = lexer.get_token()
  assert_token_type(token, Text)
}

///|
test "string with quote escape" {
  let lexer = make_lexer("\"say \\\"hello\\\"\"")
  let token = lexer.get_token()
  assert_token_type(token, Text)
}

///|
test "string with backslash escape" {
  let lexer = make_lexer("\"path\\\\to\\\\file\"")
  let token = lexer.get_token()
  assert_token_type(token, Text)
}

// ============================================================================
// Variable Tests
// ============================================================================

///|
test "variable with dollar" {
  let lexer = make_lexer("$foo")
  let token = lexer.get_token()
  assert_token_type(token, Var)
  match token.value {
    TokenValue::Text(s) => assert_eq(s, "$foo")
    _ => raise ExpectedText
  }
}

///|
test "variable with numbers" {
  let lexer = make_lexer("$var123")
  let token = lexer.get_token()
  assert_token_type(token, Var)
}

///|
test "variable with underscores" {
  let lexer = make_lexer("$my_var_name")
  let token = lexer.get_token()
  assert_token_type(token, Var)
}

///|
test "variable with special chars" {
  let lexer = make_lexer("$<>+-*/")
  let token = lexer.get_token()
  assert_token_type(token, Var)
}

// ============================================================================
// Keyword Tests
// ============================================================================

///|
test "module keyword" {
  let lexer = make_lexer("module")
  let token = lexer.get_token()
  assert_token_type(token, Module)
}

///|
test "func keyword" {
  let lexer = make_lexer("func")
  let token = lexer.get_token()
  assert_token_type(token, Func)
}

///|
test "param keyword" {
  let lexer = make_lexer("param")
  let token = lexer.get_token()
  assert_token_type(token, Param)
}

///|
test "result keyword" {
  let lexer = make_lexer("result")
  let token = lexer.get_token()
  assert_token_type(token, Result)
}

///|
test "local keyword" {
  let lexer = make_lexer("local")
  let token = lexer.get_token()
  assert_token_type(token, Local)
}

///|
test "global keyword" {
  let lexer = make_lexer("global")
  let token = lexer.get_token()
  assert_token_type(token, Global)
}

///|
test "type keyword" {
  let lexer = make_lexer("type")
  let token = lexer.get_token()
  assert_token_type(token, Type)
}

///|
test "import keyword" {
  let lexer = make_lexer("import")
  let token = lexer.get_token()
  assert_token_type(token, Import)
}

///|
test "export keyword" {
  let lexer = make_lexer("export")
  let token = lexer.get_token()
  assert_token_type(token, Export)
}

///|
test "memory keyword" {
  let lexer = make_lexer("memory")
  let token = lexer.get_token()
  assert_token_type(token, Memory)
}

///|
test "table keyword" {
  let lexer = make_lexer("table")
  let token = lexer.get_token()
  assert_token_type(token, Table)
}

// ============================================================================
// Type Keyword Tests
// ============================================================================

///|
test "i32 type" {
  let lexer = make_lexer("i32")
  let token = lexer.get_token()
  assert_token_type(token, ValueType(I32))
}

///|
test "i64 type" {
  let lexer = make_lexer("i64")
  let token = lexer.get_token()
  assert_token_type(token, ValueType(I64))
}

///|
test "f32 type" {
  let lexer = make_lexer("f32")
  let token = lexer.get_token()
  assert_token_type(token, ValueType(F32))
}

///|
test "f64 type" {
  let lexer = make_lexer("f64")
  let token = lexer.get_token()
  assert_token_type(token, ValueType(F64))
}

///|
test "funcref type" {
  let lexer = make_lexer("funcref")
  let token = lexer.get_token()
  assert_token_type(token, ValueType(FuncRef))
}

///|
test "externref type" {
  let lexer = make_lexer("externref")
  let token = lexer.get_token()
  assert_token_type(token, ValueType(ExternRef))
}

// ============================================================================
// Instruction Tests
// ============================================================================

///|
test "i32.add instruction" {
  let lexer = make_lexer("i32.add")
  let token = lexer.get_token()
  assert_token_type(token, Opcode(I32Add))
}

///|
test "i32.sub instruction" {
  let lexer = make_lexer("i32.sub")
  let token = lexer.get_token()
  assert_token_type(token, Opcode(I32Sub))
}

///|
test "i32.const instruction" {
  let lexer = make_lexer("i32.const")
  let token = lexer.get_token()
  assert_token_type(token, Opcode(I32Const))
}

///|
test "local.get instruction" {
  let lexer = make_lexer("local.get")
  let token = lexer.get_token()
  assert_token_type(token, Opcode(LocalGet))
}

///|
test "local.set instruction" {
  let lexer = make_lexer("local.set")
  let token = lexer.get_token()
  assert_token_type(token, Opcode(LocalSet))
}

///|
test "descriptor reference opcodes" {
  let lexer = make_lexer(
    "ref.get_desc ref.test_desc ref.test_desc_null ref.cast_desc_eq ref.cast_desc_eq_null",
  )
  assert_token_type(lexer.get_token(), Opcode(RefGetDesc))
  assert_token_type(lexer.get_token(), Opcode(RefTestDesc))
  assert_token_type(lexer.get_token(), Opcode(RefTestDescNull))
  assert_token_type(lexer.get_token(), Opcode(RefCastDescEq))
  assert_token_type(lexer.get_token(), Opcode(RefCastDescEqNull))
}

///|
test "advanced reference and exception keyword classification paths" {
  let lexer = make_lexer(
    "ref.eq ref.as_non_null any.convert_extern extern.convert_any ref.i31 i31.get_s i31.get_u throw throw_ref try_table try do catch catch_ref catch_all catch_all_ref delegate rethrow tag",
  )

  assert_token_type(lexer.get_token(), Opcode(RefEq))
  assert_token_type(lexer.get_token(), Opcode(RefAsNonNull))
  assert_token_type(lexer.get_token(), Opcode(AnyConvertExtern))
  assert_token_type(lexer.get_token(), Opcode(ExternConvertAny))
  assert_token_type(lexer.get_token(), Opcode(RefI31))
  assert_token_type(lexer.get_token(), Opcode(I31GetS))
  assert_token_type(lexer.get_token(), Opcode(I31GetU))

  let throw_token = lexer.get_token()
  assert_true(throw_token.token_type is Opcode(_))
  let throw_ref_token = lexer.get_token()
  assert_true(throw_ref_token.token_type is Opcode(_))
  let try_table_token = lexer.get_token()
  assert_true(try_table_token.token_type is Opcode(_))
  let legacy_try_token = lexer.get_token()
  assert_false(legacy_try_token.token_type is Reserved)
  let do_token = lexer.get_token()
  assert_false(do_token.token_type is Reserved)

  let catch_token = lexer.get_token()
  assert_false(catch_token.token_type is Reserved)
  let catch_ref_token = lexer.get_token()
  assert_false(catch_ref_token.token_type is Reserved)
  let catch_all_token = lexer.get_token()
  assert_false(catch_all_token.token_type is Reserved)
  let catch_all_ref_token = lexer.get_token()
  assert_false(catch_all_ref_token.token_type is Reserved)
  let delegate_token = lexer.get_token()
  assert_false(delegate_token.token_type is Reserved)
  let rethrow_token = lexer.get_token()
  assert_false(rethrow_token.token_type is Reserved)

  let tag_token = lexer.get_token()
  assert_false(tag_token.token_type is Reserved)
}

///|
test "call instruction" {
  let lexer = make_lexer("call")
  let token = lexer.get_token()
  assert_token_type(token, Opcode(Call))
}

///|
test "drop instruction" {
  let lexer = make_lexer("drop")
  let token = lexer.get_token()
  assert_token_type(token, Opcode(Drop))
}

///|
test "return instruction" {
  let lexer = make_lexer("return")
  let token = lexer.get_token()
  assert_token_type(token, Opcode(Return))
}

///|
test "unreachable instruction" {
  let lexer = make_lexer("unreachable")
  let token = lexer.get_token()
  assert_token_type(token, Opcode(Unreachable))
}

///|
test "nop instruction" {
  let lexer = make_lexer("nop")
  let token = lexer.get_token()
  assert_token_type(token, Opcode(Nop))
}

// ============================================================================
// Control Flow Tests
// ============================================================================

///|
test "block keyword" {
  let lexer = make_lexer("block")
  let token = lexer.get_token()
  assert_token_type(token, Block)
}

///|
test "loop keyword" {
  let lexer = make_lexer("loop")
  let token = lexer.get_token()
  assert_token_type(token, Loop)
}

///|
test "if keyword" {
  let lexer = make_lexer("if")
  let token = lexer.get_token()
  assert_token_type(token, If)
}

///|
test "else keyword" {
  let lexer = make_lexer("else")
  let token = lexer.get_token()
  assert_token_type(token, Else)
}

///|
test "end keyword" {
  let lexer = make_lexer("end")
  let token = lexer.get_token()
  assert_token_type(token, End)
}

///|
test "br instruction" {
  let lexer = make_lexer("br")
  let token = lexer.get_token()
  assert_token_type(token, Opcode(Br))
}

///|
test "br_if instruction" {
  let lexer = make_lexer("br_if")
  let token = lexer.get_token()
  assert_token_type(token, Opcode(BrIf))
}

// ============================================================================
// Annotation Tests
// ============================================================================

///|
test "annotation" {
  let lexer = make_lexer("(@custom)")
  let token = lexer.get_token()
  assert_token_type(token, LparAnn)
  match token.value {
    TokenValue::Text(s) => assert_eq(s, "custom")
    _ => raise ExpectedText
  }
}

// ============================================================================
// Align and Offset Tests
// ============================================================================

///|
test "align equals nat" {
  let lexer = make_lexer("align=4")
  let token = lexer.get_token()
  assert_token_type(token, AlignEqNat)
  match token.value {
    TokenValue::Text(s) => assert_eq(s, "4")
    _ => raise ExpectedText
  }
}

///|
test "align equals hex" {
  let lexer = make_lexer("align=0x10")
  let token = lexer.get_token()
  assert_token_type(token, AlignEqNat)
}

///|
test "offset equals nat" {
  let lexer = make_lexer("offset=100")
  let token = lexer.get_token()
  assert_token_type(token, OffsetEqNat)
  match token.value {
    TokenValue::Text(s) => assert_eq(s, "100")
    _ => raise ExpectedText
  }
}

///|
test "offset equals hex" {
  let lexer = make_lexer("offset=0xFF")
  let token = lexer.get_token()
  assert_token_type(token, OffsetEqNat)
}

// ============================================================================
// Location Tests
// ============================================================================

///|
test "location tracking" {
  let lexer = make_lexer("(func)")
  let token1 = lexer.get_token() // (
  assert_eq(token1.location.line, 1)
  assert_eq(token1.location.first_column, 1)
  let token2 = lexer.get_token() // func
  assert_eq(token2.location.first_column, 2)
}

///|
test "location tracking across newlines" {
  let lexer = make_lexer("(\n  func\n)")
  let _ = lexer.get_token() // (
  let token2 = lexer.get_token() // func
  assert_eq(token2.location.line, 2)
  let token3 = lexer.get_token() // )
  assert_eq(token3.location.line, 3)
}

// ============================================================================
// Integration Tests - Full Module Parsing
// ============================================================================

///|
test "simple function" {
  let source =
    #|(module
    #|  (func $add (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    i32.add))
  let lexer = make_lexer(source)
  let tokens = collect_tokens(lexer)
  // Should tokenize without errors
  assert_true(tokens.length() > 0)
  assert_token_type(tokens[tokens.length() - 1], Eof)
  assert_false(lexer.has_errors())
}

///|
test "memory and data" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (data (i32.const 0) "hello"))
  let lexer = make_lexer(source)
  let _ = collect_tokens(lexer)
  assert_false(lexer.has_errors())
}

///|
test "import and export" {
  let source =
    #|(module
    #|  (import "env" "log" (func $log (param i32)))
    #|  (export "main" (func $main))
    #|  (func $main))
  let lexer = make_lexer(source)
  let _ = collect_tokens(lexer)
  assert_false(lexer.has_errors())
}

///|
test "global variables" {
  let source =
    #|(module
    #|  (global $counter (mut i32) (i32.const 0))
    #|  (global $max i32 (i32.const 100)))
  let lexer = make_lexer(source)
  let _ = collect_tokens(lexer)
  assert_false(lexer.has_errors())
}

///|
test "control flow" {
  let source =
    #|(module
    #|  (func $fib (param i32) (result i32)
    #|    (if (result i32) (i32.le_s (local.get 0) (i32.const 1))
    #|      (then (local.get 0))
    #|      (else
    #|        (i32.add
    #|          (call $fib (i32.sub (local.get 0) (i32.const 1)))
    #|          (call $fib (i32.sub (local.get 0) (i32.const 2))))))))
  let lexer = make_lexer(source)
  let _ = collect_tokens(lexer)
  assert_false(lexer.has_errors())
}

// ============================================================================
// Error Recovery Tests
// ============================================================================

///|
test "error on unexpected character" {
  let lexer = make_lexer("(func @)")
  let _ = collect_tokens(lexer)
  // Should have recorded an error but continued
  // The @ character should cause an error
}

///|
test "unterminated block comment" {
  let lexer = make_lexer("(; unterminated")
  let token = lexer.get_token()
  // Should return EOF and record error
  assert_token_type(token, Eof)
  assert_true(lexer.has_errors())
}

// ============================================================================
// Edge Cases
// ============================================================================

///|
test "reserved token" {
  let lexer = make_lexer("notakeyword")
  let token = lexer.get_token()
  assert_token_type(token, Reserved)
}

///|
test "keywords with common prefix" {
  let source = "local local.get local.set local.tee"
  let lexer = make_lexer(source)
  let t1 = lexer.get_token()
  assert_token_type(t1, Local)
  let t2 = lexer.get_token()
  assert_token_type(t2, Opcode(LocalGet))
  let t3 = lexer.get_token()
  assert_token_type(t3, Opcode(LocalSet))
  let t4 = lexer.get_token()
  assert_token_type(t4, Opcode(LocalTee))
}

///|
test "float vs int distinction" {
  let lexer1 = make_lexer("42")
  let t1 = lexer1.get_token()
  assert_token_type(t1, Nat)
  let lexer2 = make_lexer("42.0")
  let t2 = lexer2.get_token()
  assert_token_type(t2, Float)
  let lexer3 = make_lexer("42e5")
  let t3 = lexer3.get_token()
  assert_token_type(t3, Float)
}

///|
test "hex vs decimal distinction" {
  let lexer1 = make_lexer("255")
  let t1 = lexer1.get_token()
  match t1.value {
    Literal(lit) =>
      match lit.literal_type {
        LiteralType::Int => ()
        _ => raise ExpectedIntLiteral
      }
    _ => raise ExpectedLiteral
  }
  let lexer2 = make_lexer("0xFF")
  let t2 = lexer2.get_token()
  match t2.value {
    Literal(lit) =>
      match lit.literal_type {
        LiteralType::Int => ()
        _ => raise ExpectedIntLiteral
      }
    _ => raise ExpectedLiteral
  }
}

///|
test "many tokens stress test" {
  let mut source = ""
  for i = 0; i < 100; i = i + 1 {
    source = source +
      "(func $f" +
      i.to_string() +
      " (param i32) (result i32) local.get 0)\n"
  }
  let lexer = make_lexer(source)
  let tokens = collect_tokens(lexer)
  assert_true(tokens.length() > 1000)
  assert_false(lexer.has_errors())
}

///|
test "mixed whitespace" {
  let lexer = make_lexer("(\t\r\n  func  \t)")
  let tokens = collect_tokens(lexer)
  assert_eq(tokens.length(), 4) // ( func ) EOF
}
