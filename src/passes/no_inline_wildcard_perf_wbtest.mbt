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
test "bench no-inline wildcard size=256" (it : @bench.T) {
  no_inline_wildcard_bench(it, 256)
}

///|
test "bench no-inline wildcard size=512" (it : @bench.T) {
  no_inline_wildcard_bench(it, 512)
}
