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
test "glob_match keeps drive and absolute path scopes distinct" {
  assert_true(glob_match("C:/src/*.wasm", "C:/src/a.wasm"))
  assert_false(glob_match("C:/src/*.wasm", "D:/src/a.wasm"))
  assert_false(glob_match("/src/*.wasm", "src/a.wasm"))
}

///|
test "expand_globs keeps scoped pattern order across drive and absolute buckets" {
  let out = expand_globs(["C:/src/*.wasm", "/root/**/*.wat"], [
    "D:/src/a.wasm", "/root/b.wat", "C:/src/c.wasm", "/other/x.wat", "C:/src/a.wasm",
    "/root/deep/nested/z.wat",
  ])
  assert_eq(out, [
    "C:/src/a.wasm", "C:/src/c.wasm", "/root/b.wat", "/root/deep/nested/z.wat",
  ])
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

///|
test "expand_globs_with_adapter expands matches from filesystem candidates" {
  let out = expand_globs_with_adapter(["src/**/*.wasm"], fn() {
    ["src\\\\b.wasm", "src/a.wat", "src/nested/c.wasm", "src/b.wasm"]
  })
  assert_eq(out, ["src/b.wasm", "src/nested/c.wasm"])
}

///|
test "expand_globs_with_adapter preserves first-pattern match order semantics" {
  let out = expand_globs_with_adapter(["src/*.wasm", "src/**/*.wasm"], fn() {
    ["src/c.wasm", "src/nested/z.wasm", "src/a.wasm", "src/b.wasm"]
  })
  assert_eq(out, ["src/a.wasm", "src/b.wasm", "src/c.wasm", "src/nested/z.wasm"])
}
