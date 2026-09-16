///|
test "global-refining local grouping remaps names and keeps parameter names" {
  let input = pass_test_module_from_wat(
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
  let output = global_refining_run_module_pass(input)
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

///|
test "global-refining local grouping preserves intentionally opaque name payload" {
  let parsed = pass_test_module_from_wat(
    "(module (func (result i64) (local i64 i32 i64) i64.const 17 local.set 2 local.get 2))",
  )
  // Undecoded name payloads are intentionally unsupported by local remapping.
  let input = @lib.Module::new(
    type_sec=parsed.type_sec,
    func_sec=parsed.func_sec,
    code_sec=parsed.code_sec,
    raw_name_sec_payload=Some(b"\x02\x0b\x01\x00\x01\x01\x06narrow"),
  )
  let output = global_refining_run_module_pass(input)
  @debug.assert_eq(output.code_sec, input.code_sec)
  @debug.assert_eq(output.raw_name_sec_payload, input.raw_name_sec_payload)
}
