///|
fn ssa_test_first_defined_func(
  mod_ : @lib.Module,
) -> (@lib.Locals, Array[@lib.Instruction]) raise {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs.get(0) {
        Some(@lib.Func(locals, @lib.Expr(instrs))) => (locals, instrs)
        None => fail("expected first defined function")
      }
    None => fail("expected code section")
  }
}

///|
test "ssa-nomerge rewrites straight-line local traffic onto a unique def local" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 5 local.set 0 local.get 0))",
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge lowers branch joins through predecessor copies" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     i32.const 1
    #|     local.set 0
    #|     i32.const 1
    #|     if
    #|       i32.const 7
    #|       local.set 0
    #|     else
    #|       nop
    #|     end
    #|     local.get 0))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected branch-join ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      ],
      Some([
        @lib.Instruction::nop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "ssa-nomerge lowers loop-carried locals before the backedge" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     i32.const 1
    #|     local.set 0
    #|     block
    #|       loop
    #|         local.get 0
    #|         drop
    #|         i32.const 2
    #|         local.set 0
    #|         i32.const 1
    #|         br_if 0
    #|       end
    #|     end
    #|     local.get 0))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected loop-carried ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
          ]),
        ),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ])
}
