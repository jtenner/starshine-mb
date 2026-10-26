///|
test "spec runner removes argv zero and preserves ordinary paths" {
  assert_eq(
    spec_runner_normalize_args(["spec_runner", "case.wast", "dir/file.wast"]),
    ["case.wast", "dir/file.wast"],
  )
}

///|
test "spec runner preserves a file name with a leading space" {
  assert_eq(
    spec_runner_normalize_args(["spec_runner", " case.wast"]),
    [" case.wast"],
  )
}

///|
test "spec runner preserves a file name with a trailing space" {
  assert_eq(
    spec_runner_normalize_args(["spec_runner", "case.wast "]),
    ["case.wast "],
  )
}

///|
test "spec runner preserves a valid file name made only of spaces" {
  assert_eq(spec_runner_normalize_args(["spec_runner", " "]), [" "])
}
