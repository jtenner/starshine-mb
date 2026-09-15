///|
test "local-subtyping type parity prunes unused signatures and GC definitions" {
  let input = pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (type (func)) (type (struct (field (mut i32)) (field eqref))) (type (struct (field i8) (field i16))) (func (type 0) (local anyref) struct.new_default 3 local.set 0 local.get 0 drop))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "local-subtyping",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 2)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(
    body[0],
    @lib.Instruction::struct_new_default(@lib.TypeIdx::new(1U)),
  )
}

///|
test "local-subtyping type parity removes an unused recursive hierarchy" {
  let input = pass_test_module_from_wat(
    "(module (type (func)) (rec (type (struct)) (type (sub (struct))) (type (sub 2 (struct)))) (type (sub 3 (struct))) (type (struct (field (ref null 4)))) (type (struct (field (mut i32)) (field eqref))) (func (type 0) (local anyref) struct.new_default 6 local.set 0 local.get 0 drop))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "local-subtyping",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 2)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(
    body[0],
    @lib.Instruction::struct_new_default(@lib.TypeIdx::new(1U)),
  )
}

///|
test "local-subtyping type parity preserves whole live recursive groups" {
  let input = pass_test_module_from_wat(
    "(module (type (func (param i32))) (type (func)) (rec (type (struct (field (ref null 3)))) (type (struct (field (ref null 2))))) (func (type 1) (local anyref) struct.new_default 2 local.set 0 local.get 0 drop))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "local-subtyping",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let types = output.type_sec.unwrap().0
  @debug.assert_eq(types.length(), 2)
  match types[1] {
    @lib.GroupRecType(members) => @debug.assert_eq(members.length(), 2)
    _ => fail("live recursive group was split")
  }
  @debug.assert_eq(output.func_sec.unwrap().0[0], @lib.TypeIdx::new(0U))
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(
    body[0],
    @lib.Instruction::struct_new_default(@lib.TypeIdx::new(1U)),
  )
}

///|
test "local-subtyping type parity remaps retained type and field names" {
  let input = pass_test_module_from_wat(
    "(module (type (struct)) (type (func)) (type (struct (field i32))) (func (type 1) (local anyref) struct.new_default 2 local.set 0 local.get 0 drop))",
  ).with_name_sec(
    @lib.NameSec::new(
      type_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("dead")),
          @lib.NameAssoc::new(2U, @lib.Name::from_string("live")),
        ]),
      ),
      field_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            2U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("value")),
            ]),
          ),
        ]),
      ),
    ),
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "local-subtyping",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 2)
  let names = output.name_sec.unwrap()
  @debug.assert_eq(
    names.type_names,
    Some(
      @lib.NameMap::new([
        @lib.NameAssoc::new(1U, @lib.Name::from_string("live")),
      ]),
    ),
  )
  @debug.assert_eq(names.field_names.unwrap().0[0].0, 1U)
}
