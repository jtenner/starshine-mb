///|
test "DAE touched unread cleanup keeps unchanged module and name identity" {
  let input = pass_test_module_from_wat(
    "(module (func $keep (export \"keep\") (param $value i64) (result i64) local.get $value))",
  ).with_name_sec(
    @lib.NameSec::new(module_name=Some(@lib.Name::from_string("keep-names"))),
  )
  assert_true(input.name_sec is Some(_))
  for touched in [[], [false], [true], [true, true]] {
    let output = dae_cleanup_touched_unread_locals(input, touched)
    assert_true(physical_equal(output, input))
    assert_true(physical_equal(output.name_sec, input.name_sec))
  }
}

///|
test "DAE touched unread cleanup preserves grouped signatures effects and untouched bodies" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (rec
      #|     (type $wide (func (param i64) (result i64)))
      #|     (type $narrow (func (param i32) (result i32))))
      #|   (import "host" "effect" (func $effect (result i32)))
      #|   (func $keep (type $wide) local.get 0)
      #|   (func $change (type $wide) (local i32 i64)
      #|     call $effect local.set 1
      #|     local.get 0 local.set 2 local.get 2)
      #|   (func $untouched (type $narrow) (local i64) local.get 0))
    ),
  ).with_name_sec(
    @lib.NameSec::new(module_name=Some(@lib.Name::from_string("changed-names"))),
  )
  @validate.validate_module(input).unwrap()
  let before = input.code_sec.unwrap().0
  let output = dae_cleanup_touched_unread_locals(input, [true, true, false])
  @validate.validate_module(output).unwrap()
  let after = output.code_sec.unwrap().0
  assert_true(physical_equal(after[0], before[0]))
  assert_true(physical_equal(after[2], before[2]))
  assert_true(physical_equal(output.type_sec, input.type_sec))
  assert_true(physical_equal(output.func_sec, input.func_sec))
  assert_true(physical_equal(output.import_sec, input.import_sec))
  assert_true(output.name_sec is None)
  let @lib.Func(locals, @lib.Expr(body)) = after[1]
  assert_eq(locals.length(), 1)
  assert_eq(locals.get(0), @lib.ValType::i64())
  assert_eq(body, [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
  let @lib.Func(original_locals, @lib.Expr(original_body)) = before[1]
  assert_eq(original_locals.length(), 2)
  assert_eq(original_body.length(), 5)
  assert_true(input.name_sec is Some(_))
}

///|
test "DAE touched unread cleanup retains missing section behavior" {
  let input = pass_test_module_from_wat("(module (func))")
  let no_code = @lib.Module::new()
  assert_true(
    physical_equal(dae_cleanup_touched_unread_locals(no_code, [true]), no_code),
  )
  let no_types = @lib.Module::new().with_code_sec(input.code_sec.unwrap())
  assert_true(
    physical_equal(
      dae_cleanup_touched_unread_locals(no_types, [true]),
      no_types,
    ),
  )
}
