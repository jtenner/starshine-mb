///|
fn cl_loop_shared_body_fixture() -> @lib.Module {
  let parsed = pass_test_module_from_wat(
    (
      #|(module
      #| (func (export "producer") (param i32) (result i32)
      #|   (local i32 i32)
      #|   (loop (result i32)
      #|     i32.const 7 local.set 2 local.get 2))
      #| (func (export "observer") (param i32 i32) (result i32)
      #|   (local i32)
      #|   (loop (result i32)
      #|     i32.const 7 local.set 2 local.get 2)
      #|   drop local.get 1))
    ),
  )
  let funcs = parsed.code_sec.unwrap().0
  let @lib.Func(_, @lib.Expr(producer_body)) = funcs[0]
  let @lib.Func(observer_locals, @lib.Expr(observer_body)) = funcs[1]
  // These are two valid functions with different parameter prefixes. A shared
  // nested expression is still caller-owned input, not rewrite scratch.
  let shared_observer = @lib.Func::new(
    observer_locals,
    @lib.Expr::new([producer_body[0], observer_body[1], observer_body[2]]),
  )
  parsed.with_code_sec(@lib.CodeSec::new([funcs[0], shared_observer]))
}

///|
test "coalesce loop local remapping preserves its caller-owned nested body" {
  let input = cl_loop_shared_body_fixture()
  @validate.validate_module(input).unwrap()
  let original_bytes = @binary.encode_module(input).unwrap()
  let funcs = input.code_sec.unwrap().0
  let rewrite = cl_rewrite_func(funcs[0], [@lib.ValType::i32()])
  assert_true(rewrite.changed)
  let candidate = input.with_code_sec(
    @lib.CodeSec::new([rewrite.func, funcs[1]]),
  )
  @validate.validate_module(candidate).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), original_bytes)
}

///|
test "coalesce loop remapping cannot change another function's parameter" {
  let input = cl_loop_shared_body_fixture()
  @validate.validate_module(input).unwrap()
  let funcs = input.code_sec.unwrap().0
  let @lib.Func(_, @lib.Expr(observer_body)) = funcs[1]
  let rewrite = cl_rewrite_func(funcs[0], [@lib.ValType::i32()])
  assert_true(rewrite.changed)
  let candidate = input.with_code_sec(
    @lib.CodeSec::new([rewrite.func, funcs[1]]),
  )
  @validate.validate_module(candidate).unwrap()
  let @lib.Func(producer_locals, @lib.Expr(producer_body)) = rewrite.func
  assert_eq(producer_locals.length(), 1)
  match producer_body[0] {
    @lib.Loop(_, @lib.Expr(body)) => {
      assert_eq(body[1], @lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
      assert_eq(body[2], @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
    }
    _ => fail("expected the retained producer loop")
  }
  // The observer returns its second parameter after the loop. Its local 2
  // must receive 7; writing local 1 would instead replace that parameter.
  match observer_body[0] {
    @lib.Loop(_, @lib.Expr(body)) => {
      assert_eq(body[1], @lib.Instruction::local_set(@lib.LocalIdx::new(2U)))
      assert_eq(body[2], @lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
    }
    _ => fail("expected the retained observer loop")
  }
  assert_eq(
    observer_body[2],
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  )
}
