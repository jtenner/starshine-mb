///|
test "dispatcher global packing combines name-only index savings" {
  let input = @lib.Module::new()
    .with_global_sec(
      @lib.GlobalSec::new(
        Array::makei(130, fn(index) {
          @lib.Global::new(
            @lib.GlobalType::new(@lib.ValType::i32(), false),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(index))]),
          )
        }),
      ),
    )
    .with_name_sec(
      @lib.NameSec::new(
        global_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(128U, @lib.Name::new("first")),
            @lib.NameAssoc::new(129U, @lib.Name::new("second")),
          ]),
        ),
      ),
    )
  let bytes = @binary.encode_module(input).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["reorder-globals"],
    OptimizeOptions::new(),
  ).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  @debug.assert_eq(
    @binary.encode_module(output).unwrap().length(),
    bytes.length() - 2,
  )
  for entry in output.name_sec.unwrap().global_names.unwrap().0 {
    let @lib.NameAssoc(index, name) = entry
    assert_true(index < 128U)
    let @lib.Global(_, @lib.Expr(init)) = output.global_sec.unwrap().0[index.to_int()]
    @debug.assert_eq(init, [
      @lib.Instruction::i32_const(
        @lib.I32(if name == @lib.Name::new("first") { 128 } else { 129 }),
      ),
    ])
  }
  @debug.assert_eq(@binary.encode_module(input).unwrap(), bytes)
}
