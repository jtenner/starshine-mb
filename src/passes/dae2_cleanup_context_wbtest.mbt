///|
test "DAE2 cleanup uses defined signatures after mixed imports" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "env" "first" (func (param i64 i64)))
      #|  (import "env" "memory" (memory 1))
      #|  (import "env" "global" (global i32))
      #|  (import "env" "second" (func (param f32)))
      #|  (func (export "left") (param i32) (result i32) (local i32)
      #|    local.get 0 local.set 1 local.get 1)
      #|  (func (export "right") (param f64 i64) (result i64) (local i64)
      #|    local.get 1 local.set 2 local.get 2))
    ),
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.CodeSec(funcs) = output.code_sec.unwrap()
  for index in [0, 1] {
    let @lib.Func(locals, @lib.Expr(body)) = funcs[index]
    assert_eq(locals.length(), 0)
    assert_eq(body, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(index.to_uint())),
    ])
  }
  assert_eq(output.func_sec, input.func_sec)
  assert_eq(output.type_sec, input.type_sec)
  assert_eq(output.import_sec, input.import_sec)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  // The dispatcher must retain the same public signatures and valid bodies.
  let dispatched = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "dae2-optimizing",
  ]).unwrap()
  @validate.validate_module(dispatched).unwrap()
  assert_eq(dispatched.code_sec, output.code_sec)
}

///|
test "DAE2 cleanup resolves absolute declarations in recursive type groups" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (rec
      #|    (type $node (struct (field (ref null $node))))
      #|    (type $id (func (param (ref null $node)) (result (ref null $node))))
      #|    (type $number (func (param i64 i32) (result i32))))
      #|  (import "env" "identity" (func (type $id)))
      #|  (func (type $number) (param i64 i32) (result i32) (local i32)
      #|    local.get 1 local.set 2 local.get 2)
      #|  (func (type $id) (param (ref null $node)) (result (ref null $node))
      #|    (local (ref null $node))
      #|    local.get 0 local.set 1 local.get 1))
    ),
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.CodeSec(funcs) = output.code_sec.unwrap()
  for (index, local) in [(0, 1U), (1, 0U)] {
    let @lib.Func(locals, @lib.Expr(body)) = funcs[index]
    assert_eq(locals.length(), 0)
    assert_eq(body, [@lib.Instruction::local_get(@lib.LocalIdx::new(local))])
  }
  assert_eq(output.type_sec, input.type_sec)
  assert_eq(output.func_sec, input.func_sec)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 cleanup preserves a bounded no-op cohort with many declarations" {
  let mut wat = "(module (import \"env\" \"f\" (func (param f64)))"
  for _ in 0..<24 {
    wat += "(type (func (param i64 i32 f32)))"
  }
  for _ in 0..<24 {
    wat += "(func (param i32 i64 f64) local.get 2 drop)"
  }
  wat += ")"
  let input = pass_test_module_from_wat(wat)
  let saved = @binary.encode_module(input).unwrap()
  assert_true(physical_equal(dae2_cleanup_captures(input), input))
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
// Intentionally invalid direct input: a declaration must resolve to a subtype.
test "panic DAE2 cleanup rejects an unresolved function declaration" {
  let input = pass_test_module_from_wat("(module (func))")
  let _ = dae2_cleanup_captures(
    input.with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(99U)])),
  )
}

///|
// Intentionally invalid direct input: a struct cannot declare a function.
test "panic DAE2 cleanup rejects a non-function declaration" {
  let input = pass_test_module_from_wat("(module (type (struct)) (func))")
  let _ = dae2_cleanup_captures(
    input.with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)])),
  )
}

///|
// Intentionally invalid direct input: RecIdx must not escape a recursive group.
test "panic DAE2 cleanup rejects a recursive-local declaration index" {
  let input = pass_test_module_from_wat("(module (func))")
  let _ = dae2_cleanup_captures(
    input.with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::rec(0U)])),
  )
}
