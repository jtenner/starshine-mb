pub enum Token {
  KeywordToken(ArrayView[Char])
  IntegerToken(UInt64)
  FloatToken(Double)
  StringToken(StringView)
  IdentifierToken(StringView)
  OpenParenToken
  CloseParenToken
  WhitespaceToken(ArrayView[Char])
  CommentToken(ArrayView[Char])
  AnnotationToken(Identifier, Array[Token])
}

pub enum Identifier {
  Name(StringView)
  ID(ArrayView[Char])
}

fn to_chars(str: String) -> Array[Char] {
  str.iter().collect()
}

fn to_tokens(chars: Array[Char]) -> Result[Array[Token], String] {
  ...
}

fn is_whitespace(c : Char) -> Bool {
  match c {
    ' ' | '\u{09}' | '\u{0A}' | '\u{0D}' => true
    _ => false
  }
}

fn take_token(chars : Array[Char], i : Int) -> (Option[Token], Int) {
  ...
}

enum CommentState {
  StartCommentState
  StartMultilineCommentState
  StartLineCommentState
  ContinueMultilineCommentState(Int)
  ContinueLineCommentState(Int)
  MaybeEndMultilineCommentState(Int, Int)
}

fn take_comment(chars : Array[Char], i : Int) -> (Option[Token], Int) {
  loop (i, StartCommentState, chars.get(i)) {
    // if we are continuing a line comment and hit eof
    (i, ContinueLineCommentState(start), None) => break (Some(CommentToken(chars[start:i - 1])), i + 1)

    // if we hit eof in any state other than continuing a line comment
    (_, _, None) => break (None, i)

    // if we are starting any kind of comment
    (i, StartCommentState, Some('(')) => continue (i + 1, StartMultilineCommentState, chars.get(i + 1))
    (i, StartCommentState, Some(';')) => continue (i + 1, StartLineCommentState, chars.get(i + 1))
    (_, StartCommentState, Some(_)) => break (None, i)

    // if we are starting to lex a single line
    (i, StartLineCommentState, Some(';')) => continue (i + 1, ContinueLineCommentState(i + 1), chars.get(i + 1))
    (_, StartLineCommentState, Some(_)) => break (None, i)

    // if we are continuing a single line comment
    (i, ContinueLineCommentState(start), Some('\n')) => break (Some(CommentToken(chars[start:i - 1])), i + 1)
    (i, ContinueLineCommentState(start), Some(_)) => continue (i + 1, ContinueLineCommentState(start), chars.get(i + 1))

    // if we are starting to lex a multiline comment
    (i, StartMultilineCommentState, Some(';')) => continue (i + 1, ContinueMultilineCommentState(i + 1), chars.get(i + 1))
    (_, StartMultilineCommentState, Some(_)) => break (None, i) // not continuing

    // If we hit ';' during a multiline comment, the following character may be ')' which ends the comment.
    // In the case where two ';'s follow each other, ignore the previous one
    (i, ContinueMultilineCommentState(start), Some(';')) | (i, MaybeEndMultilineCommentState(start, _), Some(';'))
      => continue (i + 1, MaybeEndMultilineCommentState(start, i - 1), chars.get(i + 1))
    (i, ContinueMultilineCommentState(start), Some(_)) => continue (i + 1, ContinueMultilineCommentState(start), chars.get(i + 1))

    (i, MaybeEndMultilineCommentState(start, end), Some(')')) => break (Some(CommentToken(chars[start:end])), i)
    (i, MaybeEndMultilineCommentState(start, _), Some(_)) => continue (i + 1, ContinueMultilineCommentState(start), chars.get(i + 1))   
  }
}

fn take_whitespace(chars : Array[Char], i : Int) -> (Option[Token], Int) {
  match chars.get(i) {
    Some(n) if is_whitespace(n) => {
      let start = i
      loop i + 1 {
        i if chars.get(i) is Some(n) && is_whitespace(n) => continue i + 1
        i => break (Some(WhitespaceToken(chars[start : i - 1])), i)
      }
    }
    _ => (None, i)
  }
}

fn is_lower_ascii(char : Char) -> Bool {
  'a' <= char && char <= 'z'
}

fn is_idchar(char : Char) -> Bool {
  match char {
    c if '0' <= c && c <= '9' => true
    c if 'A' <= c && c <= 'Z' => true
    c if 'a' <= c && c <= 'z' => true
    '!'  |  '#'  |  '$'  |  '%'  |  '&' | '\'' |  '*'  |  '+'  |  '-'  |  '.'  |  '/' | ':' |  '<'  |  '='  |  '>'  |  '?'  |  '@'  |  '\\'  |  '^' |  '_'  | '`' | '|'  |  '~' => true
    _ => false

  }
}

fn take_keyword(chars : Array[Char], i : Int) -> (Option[Token], Int) {
  match chars.get(i) {
    Some(n) if is_lower_ascii(n) => {
      let start = i
      loop i + 1 {
        i if chars.get(i) is Some(c) && is_idchar(c) => continue i + 1
        i => break (Some(KeywordToken(chars[start : i - 1])), i)
      }
    }
    _ => (None, i)
  }
}

fn take_annotation(chars : Array[Char], i : Int) -> (Option[Token], Int) {
  ...
}
