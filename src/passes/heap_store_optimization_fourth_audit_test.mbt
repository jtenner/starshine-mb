///|
test "fourth audit heap store motion preserves constructor global read order" {
  let input = pass_test_module_from_wat(
    "(module (type $S (struct (field (mut i32)) (field (mut i32)))) (global (mut i32) (i32.const 7)) (global (mut i32) (i32.const 0)) (func (result i32) (local (ref null $S)) i32.const 0))",
  )
  let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
  let t = @lib.TypeIdx::new(0U)
  let l = @lib.LocalIdx::new(0U)
  let g = @lib.GlobalIdx::new(0U)
  let out = @lib.GlobalIdx::new(1U)
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        locals,
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::global_get(g),
              @lib.Instruction::i32_const(@lib.I32(0)),
              @lib.Instruction::struct_new(t),
              @lib.Instruction::local_set(l),
              @lib.Instruction::i32_const(@lib.I32(9)),
              @lib.Instruction::global_set(g),
              @lib.Instruction::local_get(l),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::struct_set(t, @lib.U32(1U)),
              @lib.Instruction::local_get(l),
              @lib.Instruction::struct_get(t, @lib.U32(0U)),
              @lib.Instruction::global_set(out),
            ]),
          ),
          @lib.Instruction::global_get(out),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "heap-store-optimization")
  @debug.assert_eq(
    fourth_audit_heap_eval(output, [], field_count=2, globals=[7, 0]),
    [7],
  )
  let body = audit_body(output)
  let nested = match body[0] {
    @lib.Block(_, @lib.Expr(nested)) => nested
    _ => fail("expected block")
  }
  let mut saw_read = false
  for instr in nested {
    if instr is @lib.GlobalGet(@lib.GlobalIdx(0U)) {
      saw_read = true
    }
    if instr is @lib.GlobalSet(@lib.GlobalIdx(0U)) {
      assert_true(saw_read)
    }
  }
}

///|
test "fourth audit heap store branch preserves constructor call" {
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field (mut i32)) (field (mut i32)))) (import \"env\" \"effect\" (func (result i32))) (func (param i32) (local (ref null $s))))",
  )
  let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
  let t = @lib.TypeIdx::new(0U)
  let l = @lib.LocalIdx::new(1U)
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        locals,
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::call(@lib.FuncIdx::new(0U)),
              @lib.Instruction::i32_const(@lib.I32(0)),
              @lib.Instruction::struct_new(t),
              @lib.Instruction::local_set(l),
              @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
              @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
              @lib.Instruction::local_get(l),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::struct_set(t, @lib.U32(1U)),
            ]),
          ),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "heap-store-optimization")
  let body = match audit_body(output)[0] {
    @lib.Block(_, @lib.Expr(nested)) => nested
    _ => fail("expected branch block")
  }
  let mut saw_call = false
  for instr in body {
    if instr is @lib.Call(_) {
      saw_call = true
    }
    if instr is @lib.BrIf(_) {
      assert_true(saw_call)
    }
  }
}
