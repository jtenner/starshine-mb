///|
test "LocalCSE dependency rows isolate children from ancestor local writes" {
  for tee_parent in [false, true] {
    let body : Array[@lib.Instruction] = [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_const(@lib.I32(3)),
      @lib.Instruction::i32_add(),
    ]
    if tee_parent {
      body.push(@lib.Instruction::local_tee(@lib.LocalIdx::new(1U)))
    } else {
      body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
      body.push(@lib.Instruction::i32_mul())
    }
    body.push(@lib.Instruction::drop())
    body.push(@lib.Instruction::i32_const(@lib.I32(99)))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    body.push(@lib.Instruction::i32_const(@lib.I32(3)))
    body.push(@lib.Instruction::i32_add())
    body.push(@lib.Instruction::drop())
    let params = [@lib.ValType::i32(), @lib.ValType::i32()]
    let input = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
    let (output, changed) = local_cse_run_raw_func_with_params(input, params)
    assert_true(changed)
    let @lib.Func(locals, @lib.Expr(instrs)) = output
    assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
    let mut add_count = 0
    let mut multiply_count = 0
    let mut source_tee_count = 0
    let mut source_set_count = 0
    let mut cache_tee_count = 0
    let mut cache_get_count = 0
    for instr in instrs {
      match instr {
        @lib.I32Add => add_count += 1
        @lib.I32Mul => multiply_count += 1
        @lib.LocalTee(@lib.LocalIdx(1U)) => source_tee_count += 1
        @lib.LocalSet(@lib.LocalIdx(1U)) => source_set_count += 1
        @lib.LocalTee(@lib.LocalIdx(2U)) => cache_tee_count += 1
        @lib.LocalGet(@lib.LocalIdx(2U)) => cache_get_count += 1
        _ => ()
      }
    }
    // The earlier x + 3 does not depend on the parent's local 1. Keep the
    // parent and the later write, while reusing the earlier x + 3.
    assert_eq(add_count, 1)
    assert_eq(multiply_count, if tee_parent { 0 } else { 1 })
    assert_eq(source_tee_count, if tee_parent { 1 } else { 0 })
    assert_eq(source_set_count, 1)
    assert_eq(cache_tee_count, 1)
    assert_eq(cache_get_count, 1)
    let module_ = @lib.Module::new()
      .with_type_sec(
        @lib.TypeSec::new([
          @lib.RecType::new(
            @lib.SubType::comp_type(@lib.CompType::func(params, [])),
          ),
        ]),
      )
      .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
      .with_code_sec(@lib.CodeSec::new([output]))
    @validate.validate_module(
      @binary.decode_module(@binary.encode_module(module_).unwrap()).unwrap(),
    ).unwrap()
  }
}
