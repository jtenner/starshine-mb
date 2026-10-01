///|
fn sl_root_constant_test(
  wat : String,
) -> (Array[@lib.Instruction], Array[@lib.Instruction]) raise {
  let input = pass_test_module_from_wat(wat)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let next = sl_inline_root_constants(body)
  let output = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(next))]),
  )
  @validate.validate_module(output).unwrap()
  assert_true(@binary.encode_module(output).unwrap().length() <= saved.length())
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  (body, next)
}

///|
test "sole root literal replaces a nested read across side effects and traps" {
  for scalar in ["i32", "i64", "f32", "f64"] {
    let (body, next) = sl_root_constant_test(
      "(module (import \"env\" \"effect\" (func $effect)) (memory 1) (func (param \{scalar}) (result \{scalar}) \{scalar}.const 99 local.tee 0 drop call $effect i32.const 0 i32.load drop block (result \{scalar}) local.get 0 end))",
    )
    assert_eq(next.length(), body.length() - 3)
    assert_eq(next[0], body[3])
    let @lib.Block(_, @lib.Expr(nested)) = next[next.length() - 1]
    assert_eq(nested, [body[0]])
  }
}

///|
test "sole root literal replaces legacy body tagged catch and catch-all reads" {
  for handler in ["catch $e", "catch_all"] {
    let (body, next) = sl_root_constant_test(
      "(module (tag $e) (func (param i32) (result i32) i32.const 99 local.set 0 (try (result i32) (do local.get 0 drop throw $e) (\{handler} local.get 0))))",
    )
    assert_eq(next.length(), 1)
    let @lib.Try(_, @lib.Expr(nested), catches, _) = next[0]
    assert_eq(nested[0], body[0])
    let @lib.Expr(handler_body) = match catches[0] {
      @lib.LegacyCatch(_, expr) | @lib.LegacyCatchAll(expr) => expr
    }
    assert_eq(handler_body, [body[0]])
  }
}

///|
test "root literal propagation preserves earlier reads float bits and GC siblings" {
  let (body, next) = sl_root_constant_test(
    "(module (type $t (struct (field i32))) (func (param f64 (ref $t)) (result f64) local.get 0 drop f64.const -0 local.set 0 local.get 1 drop local.get 0))",
  )
  assert_eq(next, [body[0], body[1], body[4], body[5], body[2]])
  let (body, next) = sl_root_constant_test(
    "(module (func (param f32) (result f32) f32.const nan:0x412345 local.set 0 local.get 0))",
  )
  assert_true(physical_equal(next[0], body[0]))
}

///|
test "root literal propagation intentionally rejects other writers and size growth" {
  for
    tail in [
      "i32.const 13 local.set 0 local.get 0", "(try (result i32) (do local.get 0) (catch_all i32.const 13 local.tee 0))",
      "block i32.const 13 local.set 0 end local.get 0", "loop i32.const 13 local.set 0 end local.get 0",
      "local.get 0 return i32.const 13 local.set 0 local.get 0",
    ] {
    let (body, next) = sl_root_constant_test(
      "(module (func (param i32) (result i32) i32.const 99 local.set 0 \{tail}))",
    )
    assert_true(physical_equal(next, body))
  }
  let (body, next) = sl_root_constant_test(
    "(module (func (param f64) (result f64) f64.const 1 local.set 0 local.get 0 local.get 0 f64.add local.get 0 f64.add))",
  )
  assert_true(physical_equal(next, body))
}

///|
test "root literal propagation preserves loops branches and independent arm ownership" {
  let (body, next) = sl_root_constant_test(
    "(module (func (param i32 i32) (result i32) i32.const 7 local.set 0 local.get 1 if (result i32) loop (result i32) local.get 0 end else local.get 0 end))",
  )
  assert_eq(next.length(), 2)
  let @lib.If(_, yes, no) = next[1]
  let @lib.Loop(_, @lib.Expr(nested)) = yes[0]
  assert_eq(nested, [body[0]])
  assert_eq(no.unwrap(), [body[0]])
  let (body, next) = sl_root_constant_test(
    "(module (func (param i32) i32.const 7 local.set 0))",
  )
  assert_true(physical_equal(next, body))
}

///|
test "root constant propagation retains precise float representations" {
  for
    literal in [
      @lib.Instruction::f32_const(
        @lib.F32((0x7fc12345 : Int).reinterpret_as_float()),
      ),
      @lib.Instruction::f32_const(
        @lib.F32((-2147483648 : Int).reinterpret_as_float()),
      ),
      @lib.Instruction::f64_const(
        @lib.F64((0x7ff8123456789abcL : Int64).reinterpret_as_double()),
      ),
      @lib.Instruction::f64_const(
        @lib.F64((-9223372036854775808L : Int64).reinterpret_as_double()),
      ),
    ] {
    let body = [
      literal,
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    ]
    let next = sl_inline_root_constants(body)
    assert_eq(next.length(), 1)
    assert_true(physical_equal(next[0], literal))
  }
}

///|
test "root constant encoded budgets cover signed and unsigned LEB boundaries" {
  for value in ["63", "64", "-64", "-65", "2147483647", "-2147483648"] {
    let (body, next) = sl_root_constant_test(
      "(module (func (param i32) (result i32) i32.const \{value} local.set 0 local.get 0))",
    )
    assert_eq(next, [body[0]])
  }
  for value in ["9223372036854775807", "-9223372036854775808"] {
    let (body, next) = sl_root_constant_test(
      "(module (func (param i64) (result i64) i64.const \{value} local.set 0 local.get 0))",
    )
    assert_eq(next, [body[0]])
  }
  let locals = Array::make(129, "i32").join(" ")
  let (body, next) = sl_root_constant_test(
    "(module (func (result i32) (local \{locals}) i32.const 64 local.set 128 block (result i32) local.get 128 end))",
  )
  assert_eq(next.length(), 1)
  let @lib.Block(_, @lib.Expr(nested)) = next[0]
  assert_eq(nested, [body[0]])
}

///|
test "root constant propagation supports exact wrapped literals and try-table descendants" {
  let (body, next) = sl_root_constant_test(
    "(module (func (param i32) (result i32) block i32.const 99 local.set 0 end block (result i32) try_table (result i32) local.get 0 end end))",
  )
  assert_eq(next.length(), 1)
  let @lib.Block(_, @lib.Expr(nested)) = next[0]
  let @lib.TryTable(_, _, @lib.Expr(nested)) = nested[0]
  let @lib.Block(_, @lib.Expr(original)) = body[0]
  assert_eq(nested, [original[0]])
  let (body, next) = sl_root_constant_test(
    "(module (func (param (ref null struct)) (result (ref null struct)) ref.null struct local.set 0 local.get 0))",
  )
  assert_true(physical_equal(next, body))
}
