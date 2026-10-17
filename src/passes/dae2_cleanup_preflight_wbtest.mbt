///|
test "dae2 capture cleanup returns the original candidate-free module" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (func (export "run") (local i32)
      #|     i32.const 1
      #|     local.set 0
      #|     local.get 0
      #|     drop
      #|     i32.const 2
      #|     local.set 0
      #|     local.get 0
      #|     drop))
      #|
    ),
  )
  assert_true(physical_equal(dae2_cleanup_captures(input), input))
}

///|
test "dae2 capture cleanup preserves inactive sibling bodies and names" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (func $active (result i32) (local $capture i32)
      #|     i32.const 7 local.set $capture local.get $capture)
      #|   (func $retained (export "run") (param $value i32) (local $slot i32)
      #|     block $scope
      #|       local.get $value local.set $slot local.get $slot drop
      #|       local.get $value local.set $slot local.get $slot drop
      #|     end))
    ),
  )
  let names = @lib.IndirectNameMap::new([
    @lib.IndirectNameAssoc::new(
      1U,
      @lib.NameMap::new([
        @lib.NameAssoc::new(0U, @lib.Name::from_string("value")),
        @lib.NameAssoc::new(1U, @lib.Name::from_string("slot")),
      ]),
    ),
  ])
  let labels = @lib.IndirectNameMap::new([
    @lib.IndirectNameAssoc::new(
      1U,
      @lib.NameMap::new([
        @lib.NameAssoc::new(0U, @lib.Name::from_string("scope")),
      ]),
    ),
  ])
  let input = input.with_name_sec(
    @lib.NameSec::new(local_names=Some(names), label_names=Some(labels)),
  )
  let before = input.code_sec.unwrap().0[1]
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let bodies = output.code_sec.unwrap().0
  assert_true(physical_equal(bodies[1], before))
  assert_eq(bodies[1], before)
  let @lib.Func(locals, @lib.Expr(body)) = bodies[0]
  assert_eq(locals.length(), 0)
  assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(7))])
  assert_eq(output.name_sec.unwrap().local_names, Some(names))
  assert_eq(output.name_sec.unwrap().label_names, Some(labels))
  assert_eq(input.code_sec.unwrap().0[1], before)
}
