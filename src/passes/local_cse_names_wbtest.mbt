///|
test "local-cse keeps local names in rewritten and untouched functions" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0) (func (param i32 i32) (drop (i32.add (local.get 0) (local.get 1))) (drop (i32.add (local.get 0) (local.get 1)))))",
  )
  let names = @lib.NameSec::new(
    local_names=Some(
      @lib.IndirectNameMap::new([
        @lib.IndirectNameAssoc::new(
          0U,
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("kept_param")),
          ]),
        ),
        @lib.IndirectNameAssoc::new(
          1U,
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("left")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("right")),
          ]),
        ),
      ]),
    ),
  )
  let input = input.with_name_sec(names)
  let output = local_cse_run_module_pass(input)
  let funcs = output.code_sec.unwrap().0
  let @lib.Func(new_locals, _) = funcs[1]
  @debug.assert_eq(new_locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(output.name_sec, input.name_sec)
  @validate.validate_module(output).unwrap()
  let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
  @debug.assert_eq(decoded.name_sec, input.name_sec)
}
