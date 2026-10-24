///|
test "command local-cse keeps local names after a repeated expression" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0) (func (param i32 i32) (drop (i32.add (local.get 0) (local.get 1))) (drop (i32.add (local.get 0) (local.get 1)))))",
  ).with_name_sec(
    @lib.NameSec::new(
      local_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            0U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("kept")),
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
    ),
  )
  let output = cmd_deep_audit_run_module(input, "local-cse")
  @debug.assert_eq(output.name_sec, input.name_sec)
  @validate.validate_module(output).unwrap()
}
