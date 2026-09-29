///|
test "DFE unchanged function remaps retain the original body and declarations" {
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
    ),
    @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
  ]
  let func = @lib.Func::new(
    @lib.Locals::single(1U, @lib.ValType::i32()),
    @lib.Expr::new(body),
  )
  let rewritten = dfe_rewrite_func_func_idxs(func, [0U, 1U])
  let @lib.Func(old_locals, old_expr) = func
  let @lib.Func(new_locals, new_expr) = rewritten
  assert_true(physical_equal(rewritten, func))
  assert_true(physical_equal(new_expr, old_expr))
  assert_true(physical_equal(new_locals, old_locals))
  assert_eq(rewritten, func)
}

///|
test "DFE changed remaps preserve unaffected nested bodies and input ownership" {
  let source = pass_test_module_from_wat(
    "(module (type (func)) (import \"env\" \"f\" (func)) (tag) (func) (elem declare func 0 1) (func (param i32) block nop end local.get 0 if call 0 else try_table (catch_all 0) call 1 end end ref.func 1 drop return_call 0))",
  )
  @validate.validate_module(source).unwrap()
  let before = @binary.encode_module(source)
  let funcs = source.code_sec.unwrap().0
  let original = funcs[1]
  let rewritten = dfe_rewrite_func_func_idxs(original, [0U, 0U, 2U])
  let @lib.Func(_, @lib.Expr(old_body)) = original
  let @lib.Func(_, @lib.Expr(body)) = rewritten
  assert_true(physical_equal(body[0], old_body[0]))
  assert_eq(
    body[2],
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::call(@lib.FuncIdx::new(0U))],
      Some([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::all(@lib.LabelIdx::new(0U))],
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
        ),
      ]),
    ),
  )
  assert_eq(body[3], @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)))
  assert_true(physical_equal(body[5], old_body[5]))
  let rewritten_funcs = funcs.copy()
  rewritten_funcs[1] = rewritten
  let output = source.with_code_sec(@lib.CodeSec::new(rewritten_funcs))
  @validate.validate_module(output).unwrap()
  assert_eq(@binary.encode_module(source), before)
}
