///|
fn flatten_scaling_call_count(instr : @lib.Instruction) -> Int32 {
  match instr {
    @lib.Call(_) => 1
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
      body.fold(init=0, fn(total, child) {
        total + flatten_scaling_call_count(child)
      })
    _ => 0
  }
}

///|
// Full transformation benchmark. Run only in the dedicated native perf lane.
#skip("manual native full-pass scaling and allocation benchmark")
test "flatten independent multivalue controls full-pass scaling" {
  for count in [64, 128, 256, 512] {
    let text = StringBuilder()
    text.write_string(
      "(module (import \"env\" \"pair\" (func $pair (param i32) (result i32 i32))) (func (export \"run\") (param i32) (result i32) ",
    )
    for _ in 0..<count {
      text.write_string(
        "block (result i32 i32) local.get 0 call $pair end i32.add drop ",
      )
    }
    text.write_string("i32.const 0))")
    let input = pass_test_module_from_wat(text.to_string())
    let module_ctx = @ir.hot_module_context_from_module(input)
    for sample in 0..<9 {
      let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(1U))
      let ctx = HotPassContext::new(
        flatten_descriptor(),
        @ir.HotAnalysisCache::new(),
        HotPipelineVerifyPolicy::after_each_pass(),
        false,
        fn(_) { () },
        module_ctx=Some(module_ctx),
      )
      let start = @lib.trace_now_us()
      assert_true(flatten_run(ctx, func).changed)
      let elapsed = @lib.trace_elapsed_us_since(start)
      let output = input.with_code_sec(
        @lib.CodeSec::new([@ir.hot_lower_func(func)]),
      )
      @validate.validate_module(output).unwrap()
      let @lib.Func(locals, @lib.Expr(instrs)) = output.code_sec.unwrap().0[0]
      assert_eq(locals.length(), count * 3 + 1)
      assert_eq(
        instrs.fold(init=0, fn(total, instr) {
          total + flatten_scaling_call_count(instr)
        }),
        count,
      )
      println(
        "flatten-size count=\{count} bytes=\{@binary.encode_module(output).unwrap().length()}",
      )
      println(
        "flatten-full count=\{count} sample=\{sample} us=\{elapsed} nodes=\{@ir.hot_node_count(func)} locals=\{@ir.hot_local_count(func)}",
      )
    }
  }
}

///|
#skip("manual native full-pass cold and rejected certificate controls")
test "flatten small scalar and branch EH fallback controls" {
  for
    count, source in [
      "(module (func (param i32) (result i32) local.get 0 i32.const 1 i32.add))",
      "(module (func (param i32) (result i32) block (result i32) local.get 0 end))",
      "(module (func (result i32) block (result i32 i32) i32.const 1 i32.const 2 br 0 end i32.add))",
      "(module (type (func (result i32 i32))) (func (result i32) i32.const 0))",
    ] {
    let parsed = pass_test_module_from_wat(source)
    let input = if count == 3 {
      parsed.with_code_sec(
        @lib.CodeSec::new([
          @lib.Func::new(
            @lib.Locals::empty(),
            @lib.Expr::new([
              @lib.Instruction::try_(
                @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
                @lib.Expr::new([
                  @lib.Instruction::i32_const(@lib.I32::new(1)),
                  @lib.Instruction::i32_const(@lib.I32::new(2)),
                ]),
                [
                  @lib.LegacyCatch::all(
                    @lib.Expr::new([
                      @lib.Instruction::i32_const(@lib.I32::new(3)),
                      @lib.Instruction::i32_const(@lib.I32::new(4)),
                    ]),
                  ),
                ],
              ),
              @lib.Instruction::i32_add(),
            ]),
          ),
        ]),
      )
    } else {
      parsed
    }
    @validate.validate_module(input).unwrap()
    let module_ctx = @ir.hot_module_context_from_module(input)
    for sample in 0..<9 {
      let funcs = Array::makei(64, fn(_) {
        @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
      })
      let ctx = HotPassContext::new(
        flatten_descriptor(),
        @ir.HotAnalysisCache::new(),
        HotPipelineVerifyPolicy::after_each_pass(),
        false,
        fn(_) { () },
        module_ctx=Some(module_ctx),
      )
      let start = @lib.trace_now_us()
      for func in funcs {
        ignore(flatten_run(ctx, func))
      }
      let elapsed = @lib.trace_elapsed_us_since(start)
      for func in funcs {
        @validate.validate_module(
          input.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)])),
        ).unwrap()
      }
      println(
        "flatten-control count=\{count} sample=\{sample} iterations=64 us=\{elapsed}",
      )
    }
  }
}
