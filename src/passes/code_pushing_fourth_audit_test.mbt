///|
test "fourth audit code pushing preserves copy before exceptional exit" {
  let output = audit_run(
    "(module (tag $e) (func (export \"f\") (param $v i32) (param $cond i32) (result i32) (local $x i32) (block $handler (try_table (catch_all $handler) (local.set $x (local.get $v)) (if (local.get $cond) (then (throw $e))))) (local.get $x)))",
    "code-pushing",
  )
  let body = match audit_body(output)[0] {
    @lib.Block(_, @lib.Expr([@lib.TryTable(_, _, @lib.Expr(body))])) => body
    _ => fail("expected block and handler")
  }
  assert_true(body[1] is @lib.LocalSet(_))
}

///|
test "fourth audit code pushing preserves copy before ordinary exit" {
  let output = audit_run(
    "(module (func (param $v i32) (param $c i32) (result i32) (local $x i32) (block $out (local.set $x (local.get $v)) (br_if $out (local.get $c)) (if (local.get $c) (then (nop)))) (local.get $x)))",
    "code-pushing",
  )
  let body = match audit_body(output)[0] {
    @lib.Block(_, @lib.Expr(body)) => body
    _ => fail("expected block")
  }
  assert_true(body[1] is @lib.LocalSet(_))
}
