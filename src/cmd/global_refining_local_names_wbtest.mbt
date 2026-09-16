///|
test "global-refining command local grouping remaps names and keeps parameter names" {
  let input = @passes.pass_test_module_from_wat(
    "(module (import \"host\" \"f\" (func)) (func (param i32) (result i64) (local i64 i32 i64) i64.const 17 local.set 3 local.get 3))",
  ).with_name_sec(
    @lib.NameSec::new(
      local_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            1U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("parameter")),
              @lib.NameAssoc::new(1U, @lib.Name::from_string("wide-first")),
              @lib.NameAssoc::new(2U, @lib.Name::from_string("narrow")),
              @lib.NameAssoc::new(3U, @lib.Name::from_string("wide-second")),
            ]),
          ),
        ]),
      ),
    ),
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["global-refining"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(locals.get(1), @lib.ValType::i64())
  @debug.assert_eq(
    body.last(),
    Some(@lib.Instruction::local_get(@lib.LocalIdx::new(2U))),
  )
  @debug.assert_eq(
    output.name_sec.unwrap().local_names.unwrap().0[0],
    @lib.IndirectNameAssoc::new(
      1U,
      @lib.NameMap::new([
        @lib.NameAssoc::new(0U, @lib.Name::from_string("parameter")),
        @lib.NameAssoc::new(1U, @lib.Name::from_string("wide-first")),
        @lib.NameAssoc::new(2U, @lib.Name::from_string("wide-second")),
        @lib.NameAssoc::new(3U, @lib.Name::from_string("narrow")),
      ]),
    ),
  )
}
