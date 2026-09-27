///|
fn dae_signature_fixture(count : Int) -> @lib.Module {
  let source = StringBuilder::new()
  source.write_string("(module")
  for _ in 0..<count {
    source.write_string(" (type (func))")
  }
  for _ in 0..<count {
    source.write_string(" (func (type \{count - 1}))")
  }
  source.write_string(")")
  pass_test_module_from_wat(source.to_string())
}

///|
test "dae snapshot signatures preserve recursive group positions and non-function holes" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #| (type (struct (field i32)))
      #| (rec (type (func (param i32))) (type (array i32)))
      #| (type (func (result i64)))
      #| (func (type 1)) (func (type 3) i64.const 7))
    ),
  )
  let indices = [
    @lib.TypeIdx::new(0U),
    @lib.TypeIdx::new(1U),
    @lib.TypeIdx::new(2U),
    @lib.TypeIdx::new(3U),
    @lib.TypeIdx::new(99U),
  ]
  let actual = dae_snapshot_function_types(input, indices)
  let expected = indices.mapi(fn(index, _) {
    dae_resolve_func_type(input, indices, index)
  })
  assert_eq(actual, expected)
  assert_eq(actual[0], None)
  assert_eq(actual[2], None)
  assert_eq(actual[4], None)
  assert_eq(
    dae_snapshot_function_types(@lib.Module::new(), indices),
    Array::make(5, None),
  )
}

///|
test "dae snapshot avoids unused type tails while preserving indexed signatures" {
  let input = dae_signature_fixture(8)
  let visits = [0]
  let indices = [@lib.TypeIdx::new(0U)]
  let actual = dae_snapshot_function_types(
    input,
    indices,
    visited_types=Some(visits),
  )
  assert_eq(actual, [dae_resolve_func_type(input, indices, 0)])
  assert_eq(visits[0], 1)
  visits[0] = 0
  assert_eq(
    dae_snapshot_function_types(input, [], visited_types=Some(visits)),
    [],
  )
  assert_eq(visits[0], 0)
}
