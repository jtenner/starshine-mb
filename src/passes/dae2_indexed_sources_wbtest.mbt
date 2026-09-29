///|
test "DAE2 source lookup retains branch entry and write dependencies while pruning unused arguments" {
  let input = pass_test_module_from_wat(
    "(module (func $helper (param i32 i32 i32 i32) (result i32) local.get 0 if local.get 1 local.set 2 end local.get 2) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i32.const 9 call $helper))",
  )
  for pass in ["dae2", "dae2-optimizing"] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @ir.hot_module_resolve_func_type(
        @ir.hot_module_context_from_module(output),
        @lib.FuncIdx::new(0U),
      ),
      Some(
        @lib.FuncType::new(
          [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
          [@lib.ValType::i32()],
        ),
      ),
    )
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_eq(
      body,
      if pass == "dae2" {
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
              @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            ],
            None,
          ),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        ]
      } else {
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::select(),
        ]
      },
    )
    let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[1]
    assert_eq(caller, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ])
  }
}
