///|
fn no_inline_wildcard_bench_inputs(size : Int) -> (String, String) {
  let pattern = StringBuilder::new()
  let text = StringBuilder::new()
  for _ in 0..<size {
    pattern.write_string("*a")
    text.write_string("a")
  }
  (pattern.to_string(), text.to_string())
}

///|
fn no_inline_wildcard_adversarial_inputs(size : Int) -> (String, String) {
  let pattern = StringBuilder::new()
  let text = StringBuilder::new()
  pattern.write_char('*')
  for _ in 0..<size {
    pattern.write_char('a')
    text.write_char('a')
    text.write_char('a')
  }
  pattern.write_char('b')
  (pattern.to_string(), text.to_string())
}

///|
fn no_inline_wildcard_reference(pattern : String, text : String) -> Bool {
  let width = text.length() + 1
  let mut previous = Array::make(width, false)
  let mut current = Array::make(width, false)
  previous[0] = true
  for pattern_idx = 0
      pattern_idx < pattern.length()
      pattern_idx = pattern_idx + 1 {
    let pattern_byte = pattern[pattern_idx]
    for text_idx = 0; text_idx <= text.length(); text_idx = text_idx + 1 {
      if pattern_byte == '*' {
        current[text_idx] = previous[text_idx] ||
          (text_idx > 0 && current[text_idx - 1])
      } else {
        current[text_idx] = text_idx > 0 &&
          (pattern_byte == '?' || pattern_byte == text[text_idx - 1]) &&
          previous[text_idx - 1]
      }
    }
    let old = previous
    previous = current
    current = old
  }
  previous[text.length()]
}

///|
fn no_inline_wildcard_enumerated_string(
  encoded : Int,
  length : Int,
  alphabet : String,
) -> String {
  let out = StringBuilder::new()
  let mut code = encoded
  for _ in 0..<length {
    out.write_char(alphabet[code % alphabet.length()].to_int().unsafe_to_char())
    code /= alphabet.length()
  }
  out.to_string()
}

///|
fn no_inline_wildcard_power(base : Int, exponent : Int) -> Int {
  let mut value = 1
  for _ in 0..<exponent {
    value *= base
  }
  value
}

///|
fn no_inline_wildcard_bench(it : @bench.T, size : Int) -> Unit {
  let (pattern, name) = no_inline_wildcard_bench_inputs(size)
  if !no_inline_wildcard_match(pattern, name) {
    abort("wildcard benchmark must match")
  }
  it.bench(fn() { it.keep(no_inline_wildcard_match(pattern, name)) })
}

///|
test "NoInline wildcard rolling rows preserve empty and mixed patterns" {
  assert_true(no_inline_wildcard_match("", ""))
  assert_false(no_inline_wildcard_match("", "a"))
  assert_true(no_inline_wildcard_match("*", ""))
  assert_false(no_inline_wildcard_match("?", ""))
  assert_true(no_inline_wildcard_match("a*?c", "abbbc"))
  assert_true(no_inline_wildcard_match("*a*b", "zzaxxb"))
  assert_false(no_inline_wildcard_match("a*b", "ac"))
}

///|
test "NoInline wildcard matching advances without a quadratic DP grid" {
  let (pattern, name) = no_inline_wildcard_bench_inputs(512)
  let visits = [0]
  assert_true(no_inline_wildcard_match_with_visits(pattern, name, visits))
  let word_count = (pattern.length() + 64) / 64
  assert_true(visits[0] <= name.length() * word_count)
}

///|
test "NoInline wildcard matching bounds repeated long-suffix failures" {
  let (pattern, name) = no_inline_wildcard_adversarial_inputs(256)
  let visits = [0]
  assert_false(no_inline_wildcard_match_with_visits(pattern, name, visits))
  let word_count = (pattern.length() + 64) / 64
  assert_true(visits[0] <= name.length() * word_count)
}

///|
test "NoInline wildcard word-parallel matcher preserves glob semantics" {
  for pattern_length = 0
      pattern_length <= 4
      pattern_length = pattern_length + 1 {
    let pattern_count = no_inline_wildcard_power(4, pattern_length)
    for pattern_code = 0
        pattern_code < pattern_count
        pattern_code = pattern_code + 1 {
      let pattern = no_inline_wildcard_enumerated_string(
        pattern_code, pattern_length, "ab?*",
      )
      for text_length = 0; text_length <= 4; text_length = text_length + 1 {
        let text_count = no_inline_wildcard_power(2, text_length)
        for text_code = 0; text_code < text_count; text_code = text_code + 1 {
          let text = no_inline_wildcard_enumerated_string(
            text_code, text_length, "ab",
          )
          let expected = no_inline_wildcard_reference(pattern, text)
          let actual = no_inline_wildcard_match(pattern, text)
          if actual != expected {
            abort(
              "wildcard mismatch pattern=\{pattern} text=\{text} expected=\{expected} actual=\{actual}",
            )
          }
        }
      }
    }
  }
}

///|
test "bench no-inline wildcard size=256" (it : @bench.T) {
  no_inline_wildcard_bench(it, 256)
}

///|
test "bench no-inline wildcard size=512" (it : @bench.T) {
  no_inline_wildcard_bench(it, 512)
}
