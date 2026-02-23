///|
test "normalize_cli_path canonicalizes separators and dot segments" {
  assert_eq(
    normalize_cli_path("./src\\\\foo//bar/../main.wasm"),
    "src/foo/main.wasm",
  )
}

///|
test "normalize_cli_path preserves drive prefixes and removes redundant separators" {
  assert_eq(
    normalize_cli_path("C:\\\\repo\\src\\..\\test\\\\a.wat"),
    "C:/repo/test/a.wat",
  )
}

///|
test "glob_match handles single-segment wildcard" {
  assert_true(glob_match("src/*.wasm", "src/main.wasm"))
  assert_false(glob_match("src/*.wasm", "src/nested/main.wasm"))
}

///|
test "glob_match handles recursive wildcard" {
  assert_true(glob_match("src/**/*.wat", "src/a.wat"))
  assert_true(glob_match("src/**/*.wat", "src/deep/nested/b.wat"))
  assert_false(glob_match("src/**/*.wat", "lib/a.wat"))
}

///|
test "glob_match handles question-mark and mixed wildcard segments" {
  assert_true(glob_match("tests/file-?.wast", "tests/file-a.wast"))
  assert_false(glob_match("tests/file-?.wast", "tests/file-aa.wast"))
  assert_true(glob_match("**/*.wasm", "mod/a.wasm"))
}

///|
test "expand_globs returns deterministic sorted normalized matches" {
  let out = expand_globs(["src/**/*.wasm"], [
    "src\\\\b.wasm", "src/a.wasm", "src/nested/c.wasm", "src/a.wasm",
  ])
  assert_eq(out, ["src/a.wasm", "src/b.wasm", "src/nested/c.wasm"])
}

///|
test "expand_globs keeps first-match stability while deduplicating overlaps" {
  let out = expand_globs(["src/*.wasm", "src/**/*.wasm"], [
    "src/c.wasm", "src/nested/z.wasm", "src/a.wasm", "src/b.wasm",
  ])
  assert_eq(out, ["src/a.wasm", "src/b.wasm", "src/c.wasm", "src/nested/z.wasm"])
}
