pub enum Token {
  // Structural
  LParen
  RParen

  // Identifiers and keywords
  Keyword(String)
  Identifier(String)

  // Literals
  UIntLiteral(String)    // u
  SIntLiteral(String)    // s
  FloatLiteral(String)   // f
  StringLiteral(String)

  // Invalid / forbidden
  Reserved(String)

  // Explicit WhiteSpace, ignored
  WhiteSpace
} derive(Eq, Show)

pub struct SpannedToken {
  token : Token
  span : (UInt, UInt)
} derive(Eq, Show)

pub fn Token::l_paren() -> Token {
  LParen
}
pub fn Token::r_paren() -> Token {
  RParen
}
pub fn Token::keyword(val : (String)) -> Token {
  Keyword(val)
}
pub fn Token::identifier(val : (String)) -> Token {
  Identifier(val)
}
pub fn Token::u_int_literal(val : (String)) -> Token {
  UIntLiteral(val)
}
pub fn Token::s_int_literal(val : (String)) -> Token {
  SIntLiteral(val)
}
pub fn Token::float_literal(val : (String)) -> Token {
  FloatLiteral(val)
}
pub fn Token::string_literal(val : (String)) -> Token {
  StringLiteral(val)
}
pub fn Token::reserved(val : (String)) -> Token {
  Reserved(val)
}
pub fn Token::whitespace() -> Token {
  WhiteSpace
}
pub fn SpannedToken::new(token : Token, span : (UInt, UInt)) -> SpannedToken {
  SpannedToken::{ token, span }
}

fn consume_string_literal(
  chars : Array[Char],
  i : Int
) -> Option[(Token, Int)] {

  let mut i = i
  let len = chars.length()
  let buf = @buffer.new()

  loop () {
    _ => {
      if i >= len {
        // EOF before closing quote
        return Some((
          Token::reserved("(unterminated string)"),
          i
        ))
      }

      match chars.get(i) {
        // Closing quote
        Some('"') => {
          i += 1
          return Some((
            Token::string_literal(buf.to_string()),
            i
          ))
        }

        // Escape sequence
        Some('\\') => {
          i += 1
          if i >= len {
            return Some((
              Token::reserved("(unterminated string)"),
              i
            ))
          }

          match chars.get(i) {
            Some('"') => {
              buf.write_char('"')
              i += 1
            }
            Some('\\') => {
              buf.write_char('\\')
              i += 1
            }
            Some('n') => {
              buf.write_char('\n')
              i += 1
            }
            Some('t') => {
              buf.write_char('\t')
              i += 1
            }
            Some('r') => {
              buf.write_char('\r')
              i += 1
            }
            _ => {
              return Some((
                Token::reserved("(invalid escape sequence)"),
                i
              ))
            }
          }
        }

        // Raw newline is invalid
        Some('\n') | Some('\r') => {
          return Some((
            Token::reserved("(invalid string literal)"),
            i
          ))
        }

        // Ordinary character
        Some(c) => {
          buf.write_char(c)
          i += 1
        }

        // Should be unreachable
        None => {
          return Some((
            Token::reserved("(unterminated string)"),
            i
          ))
        }
      }
      continue ()
    }
  }
}

fn consume(chars : Array[Char], i0 : Int) -> Option[(Token, Int)] {
  let mut i = i0
  let len = chars.length()

  fn bump_newline() -> Int {
    if i + 1 < chars.length() && chars[i] == '\r' && chars[i + 1] == '\n' {
      i + 2
    } else {
      i + 1
    }
  }

  match chars.get(i) {
    Some('"') => consume_string_literal(chars, i + 1)
    Some(' ') | Some('\t') | Some('\n') | Some('\r') => {
      i += 1

      loop () {
        _ if i < len => {
          match chars.get(i) {
            Some('\r') => {
              i = bump_newline()
              continue ()
            }
            Some(' ') | Some('\t') | Some('\n') => {
              i += 1
              continue ()
            }
            _ => {
              return Some((Token::whitespace(), i))
            }
          }
        }
        _ => {
          return Some((Token::whitespace(), i))
        }
      }
    }


    // Line comment ;;
    Some(';') if chars.get(i + 1) == Some(';') => {
      i += 2

      loop () {
        _ if i < len => match chars.get(i) {
          Some('\n') => return Some((Token::whitespace(), i))
          Some('\r') => {
            i = bump_newline()
            return Some((Token::whitespace(), i))
          }
          _ => {
            i += 1
            continue ()
          }
        }
        _ => return Some((Token::whitespace(), i)) 
      }
    }

    // Block comment (; or annotation (@
    Some('(') if chars.get(i + 1) == Some(';') => {
      i += 2
      let mut depth = 1

      loop () {
        _ if i < len => {
          match chars.get(i) {
            Some('(') if chars.get(i + 1) == Some(';') => {
              depth += 1
              i += 2
              continue ()
            }
            Some(';') if chars.get(i + 1) == Some(')') => {
              depth -= 1
              i += 2
              if depth == 0 {
                return Some((Token::whitespace(),i))
              }
              continue ()
            }
            None => {
              return Some((
                Token::reserved("(unterminated comment)"),
                i
              ))
            }
            _ => {
              i += 1
              continue ()
            }
          }
        }
        _ => return Some((Token::reserved("(unterminated comment)"), i))
      }
    }

    Some('(') => {
      i += 1
      return Some((Token::l_paren(), i))
    }

    Some(')') => {
      i += 1
      return Some((Token::r_paren(), i))
    }

    _ => None
  }
}

pub fn SpannedToken::tokenize(text : String) -> Iter[SpannedToken] {
  let mut start = 0
  let chars = text.iter().collect()
  Iter::new(fn () -> Option[SpannedToken] {
    let result = consume(chars, start)

    match result {
      None => None
      Some((token, end)) => {
        let out = SpannedToken::new(token, (start.reinterpret_as_uint(), end.reinterpret_as_uint()))
        start = end
        Some(out)
      }
    }
  })
}

fn token_test(text : String, expected : Array[(Token, UInt, UInt)]) -> Unit raise {
  let tokens = SpannedToken::tokenize(text).collect()
  assert_eq(tokens.length(), expected.length())
  for i in 0..<tokens.length() {
    assert_eq(tokens[i].token, expected[i].0)
    assert_eq(tokens[i].span.0, expected[i].1)
    assert_eq(tokens[i].span.1, expected[i].2)
  }
}

test "single space is whitespace" {
  token_test(" ", [(Token::whitespace(), 0U, 1U)])
}

test "mixed whitespace collapses into one token" {
  token_test(" \t\r\n\n", [(Token::whitespace(), 0U, 5U)])
}

test "CRLF counts as one newline" {
  token_test("\r\n", [(Token::whitespace(), 0U, 2U)])
}

test "simple block comment" {
  token_test("(; abc ;)", [(Token::whitespace(), 0U, 9U)])
}

test "nested block comments" {
  token_test("(; (; ;) ;)", [(Token::whitespace(), 0U, 11U)])
}

test "unterminated block comment is reserved" {
  let text = "(; abc"
  let expected = [(Token::reserved("(unterminated comment)"), 0U, 6U)]
  token_test(text, expected)
}

test "whitespace stops before token" {
  let text = "  ("
  let expected = [(Token::whitespace(), 0U, 2U), (Token::l_paren(), 2U, 3U)]
  token_test(text, expected)
}

test "empty string literal" {
  token_test(
    "\"\"",
    [(Token::string_literal(""), 0U, 2U)]
  )
}

test "simple string literal" {
  token_test(
    "\"abc\"",
    [(Token::string_literal("abc"), 0U, 5U)]
  )
}

test "string with spaces" {
  token_test(
    "\"a b c\"",
    [(Token::string_literal("a b c"), 0U, 7U)]
  )
}

test "escaped quote" {
  token_test(
    "\"a\\\"b\"",
    [(Token::string_literal("a\"b"), 0U, 6U)]
  )
}

test "escaped backslash" {
  token_test(
    "\"a\\\\b\"",
    [(Token::string_literal("a\\b"), 0U, 6U)]
  )
}

test "escaped newline" {
  token_test(
    "\"a\\nb\"",
    [(Token::string_literal("a\nb"), 0U, 6U)]
  )
}

test "mixed escapes" {
  token_test(
    "\"\\\\\\\"\\n\\t\"",
    [(Token::string_literal("\\\"\n\t"), 0U, 8U)]
  )
}

test "unterminated string literal" {
  token_test(
    "\"abc",
    [(Token::reserved("(unterminated string)"), 0U, 4U)]
  )
}

test "string ends after escape" {
  token_test(
    "\"abc\\",
    [(Token::reserved("(unterminated string)"), 0U, 5U)]
  )
}

test "raw newline inside string is invalid" {
  let text = "\"a\nb\""
  token_test(
    text,
    [(Token::reserved("(invalid string literal)"), 0U, 5U)]
  )
}

test "string followed by token" {
  token_test(
    "\"a\"(",
    [
      (Token::string_literal("a"), 0U, 3U),
      (Token::l_paren(), 3U, 4U)
    ]
  )
}

test "whitespace before string" {
  token_test(
    "  \"a\"",
    [
      (Token::whitespace(), 0U, 2U),
      (Token::string_literal("a"), 2U, 5U)
    ]
  )
}

test "string after line comment" {
  token_test(
    ";;x\n\"a\"",
    [
      (Token::whitespace(), 0U, 4U),
      (Token::string_literal("a"), 4U, 7U)
    ]
  )
}