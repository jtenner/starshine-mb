///|
test "myers_diff groups replacements and trailing insertions" {
  let lhs = "a\nb\nc"
  let rhs = "a\nx\nc\nz"
  let changes = myers_diff(lhs, rhs)
  assert_eq(changes.length(), 2)
  assert_eq(changes[0].lhs_at, 1)
  assert_eq(changes[0].lhs_del, 1)
  assert_eq(changes[0].rhs_at, 1)
  assert_eq(changes[0].rhs_add, 1)
  assert_eq(changes[1].lhs_at, 3)
  assert_eq(changes[1].lhs_del, 0)
  assert_eq(changes[1].rhs_at, 3)
  assert_eq(changes[1].rhs_add, 1)
}

///|
test "myers_diff respects ignore case and whitespace options" {
  let lhs = "A   b\nC"
  let rhs = "ab\nc"
  let options = DiffOptions::new(ignore_whitespace=true, ignore_case=true)
  let changes = myers_diff(lhs, rhs, options~)
  assert_eq(changes.length(), 0)
}

///|
test "render_line_diff includes minus and plus lines" {
  let lhs = "func\n  drop\n  nop"
  let rhs = "func\n  local.get 0\n  nop\n  end"
  let rendered = render_line_diff(lhs, rhs)
  assert_true(rendered.contains("-  drop"), msg=rendered)
  assert_true(rendered.contains("+  local.get 0"), msg=rendered)
  assert_true(rendered.contains("+  end"), msg=rendered)
}

///|
test "render_line_diff includes unchanged context around replacements" {
  let lhs = "line0\nline1\nline2\nline3\nline4"
  let rhs = "line0\nline1\nchanged\nline3\nline4"
  let rendered = render_line_diff(lhs, rhs)
  assert_true(rendered.contains(" line1"), msg=rendered)
  assert_true(rendered.contains("-line2"), msg=rendered)
  assert_true(rendered.contains("+changed"), msg=rendered)
  assert_true(rendered.contains(" line3"), msg=rendered)
}

///|
test "render_line_diff includes unchanged context around insertions" {
  let lhs = "top\nmiddle\nbottom"
  let rhs = "top\nmiddle\nnew\nbottom"
  let rendered = render_line_diff(lhs, rhs)
  assert_true(rendered.contains(" middle"), msg=rendered)
  assert_true(rendered.contains("+new"), msg=rendered)
  assert_true(rendered.contains(" bottom"), msg=rendered)
}
