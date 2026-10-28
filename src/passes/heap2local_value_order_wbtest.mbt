///|
test "heap2local forwarding retains array and struct initializer snapshots" {
  for shape in [0, 1, 2] {
    for global_source in [false, true] {
      let input = h2l_control_owner_parse(
        "(module " +
        (if shape == 2 {
          "(type $T (struct (field i32))) "
        } else {
          "(type $T (array i32)) "
        }) +
        "(global (mut i32) (i32.const 0)) " +
        "(func (result i32) (local i32) i32.const 0))",
      )
      let read = if global_source {
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U))
      } else {
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
      }
      let write = if global_source {
        @lib.Instruction::global_set(@lib.GlobalIdx::new(0U))
      } else {
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U))
      }
      let body = [
        @lib.Instruction::i32_const(7),
        write,
        read,
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::i32_const(9), write]),
        ),
      ]
      let ty = @lib.TypeIdx::new(0U)
      if shape == 2 {
        body.append([
          @lib.Instruction::struct_new(ty),
          @lib.Instruction::struct_get(ty, @lib.U32::new(0U)),
        ])
      } else {
        if shape == 0 {
          body.append([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::array_new(ty),
          ])
        } else {
          body.push(@lib.Instruction::array_new_fixed(ty, @lib.U32::new(1U)))
        }
        body.append([
          @lib.Instruction::i32_const(0),
          @lib.Instruction::array_get(ty),
        ])
      }
      let input = input.with_code_sec(
        @lib.CodeSec::new([
          @lib.Func::new(
            @lib.Locals::single(1U, @lib.ValType::i32()),
            @lib.Expr::new(body),
          ),
        ]),
      )
      @validate.validate_module(input).unwrap()
      let expected = (true, [7], if global_source { 9 } else { 0 })
      assert_eq(h2l_control_owner_observe(input), expected)
      let hot = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
      let lower = fn() {
        input.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(hot)]))
      }
      assert_eq(h2l_control_owner_observe(lower()), expected)
      let ctx = HotPassContext::new(
        heap2local_descriptor(),
        @ir.HotAnalysisCache::new(),
        HotPipelineVerifyPolicy::after_each_pass(),
        false,
        fn(_) { () },
        module_ctx=Some(@ir.hot_module_context_from_module(input)),
      )
      assert_true(heap2local_run(ctx, hot).changed)
      pass_verify_before_after(ctx, hot).unwrap()
      let direct = lower()
      @validate.validate_module(direct).unwrap()
      assert_eq(h2l_control_owner_observe(direct), expected)
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
        "heap2local",
      ]).unwrap()
      @validate.validate_module(output).unwrap()
      assert_eq(h2l_control_owner_observe(output), expected)
    }
  }
}
