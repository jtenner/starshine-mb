///|
fn cl_tee_control_fixture(depth : Int) -> @lib.Module {
  let mut body = [
    @lib.Instruction::i32_const(7),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::return_(),
  ]
  for _ in 0..<depth {
    body = [
      @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(body)),
    ]
  }
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  body.push(@lib.Instruction::drop())
  pass_test_module_from_wat("(module (func (local i32)))").with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::single(1U, @lib.ValType::i32()),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
test "Coalesce tee cleanup shares control facts and retains dead action ordinals" {
  let input = cl_tee_control_fixture(24)
  @validate.validate_module(input).unwrap()
  let bytes = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(original)) = input.code_sec.unwrap().0[0]
  let output = @binary.decode_module(bytes).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let visits = [0]
  let cursor = [0]
  assert_true(
    cl_remove_ineffective_tees(
      body,
      original,
      [false],
      cursor,
      control_visits=Some(visits),
    ),
  )
  assert_eq(cursor[0], 1)
  assert_eq(body[1:], original[1:])
  let mut leaf = body
  for _ in 0..<24 {
    match leaf[0] {
      @lib.Block(_, @lib.Expr(child)) => leaf = child
      _ => fail("expected retained block")
    }
  }
  assert_eq(leaf, [
    @lib.Instruction::i32_const(7),
    @lib.Instruction::drop(),
    @lib.Instruction::return_(),
  ])
  @validate.validate_module(output).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), bytes)
  assert_true(
    visits[0] <= 80,
    msg="tee cleanup rescanned nested control subtrees",
  )
}

///|
test "Coalesce tee cleanup keeps branch and catch reachability ordinals" {
  let fixtures = [
    "(module (func (param i32) (local i32) local.get 0 if i32.const 7 local.tee 1 drop return else i32.const 9 local.tee 1 drop return end local.get 1 drop))",
    "(module (tag) (func (local i32) block try_table (catch_all 0) i32.const 9 local.tee 0 drop return end end i32.const 5 local.tee 0 drop))",
  ]
  for wat in fixtures {
    let input = pass_test_module_from_wat(wat)
    @validate.validate_module(input).unwrap()
    let bytes = @binary.encode_module(input).unwrap()
    let @lib.Func(_, @lib.Expr(original)) = input.code_sec.unwrap().0[0]
    let output = @binary.decode_module(bytes).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    let actions : Array[CLAction] = []
    cl_collect_instrs(original, actions, 2)
    let effective = actions.map(fn(action) { action.kind is CLActionKind::Get })
    let index = CLControlIndex::new()
    ignore(
      cl_control_body_boundary(original, [], None, control_index=Some(index)),
    )
    let cursor = [0]
    assert_true(
      cl_remove_ineffective_tees(
        body,
        original,
        effective,
        cursor,
        control_index=Some(index),
      ),
    )
    assert_eq(cursor[0], actions.length())
    @validate.validate_module(output).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), bytes)
  }
}

///|
test "Coalesce backward liveness shares nested terminal control facts" {
  let input = cl_tee_control_fixture(24)
  @validate.validate_module(input).unwrap()
  let bytes = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let actions : Array[CLAction] = []
  cl_collect_instrs(body, actions, 1)
  let effective = Array::make(actions.length(), false)
  let visited = [0]
  let cursor = [actions.length() - 1]
  let visits = [0]
  let live = cl_mark_structured_liveness_backward(
    body,
    actions,
    effective,
    CLBitMatrix::new(1),
    visited,
    [false],
    [],
    cursor,
    control_visits=Some(visits),
  )
  assert_eq(actions.length(), 1)
  assert_eq(effective, [false])
  assert_eq(live, [false])
  assert_eq(visited[0], 1)
  assert_eq(cursor[0], -1)
  assert_eq(@binary.encode_module(input).unwrap(), bytes)
  assert_true(
    visits[0] <= 80,
    msg="backward liveness rescanned nested control subtrees",
  )
}
