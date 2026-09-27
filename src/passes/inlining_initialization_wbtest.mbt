///|
test "inlining initialization visits the body once for all callee locals" {
  let body : Array[@lib.Instruction] = []
  for index in 0..<64 {
    body.push(@lib.Instruction::i32_const(index))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(index.to_uint())))
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(index.to_uint())))
    body.push(@lib.Instruction::drop())
  }
  let visits = [0]
  let actual = inl_locals_read_before_write(body, 0, 64, visits=Some(visits))
  assert_eq(actual, Array::make(64, false))
  assert_true(
    visits[0] <= body.length(),
    msg="initialization instruction visits: \{visits[0]}",
  )
}

///|
test "inlining initialization preserves branch handler and loop write boundaries" {
  let get = fn(index : Int) {
    @lib.Instruction::local_get(@lib.LocalIdx::new(index.to_uint()))
  }
  let set = fn(index : Int) {
    @lib.Instruction::local_set(@lib.LocalIdx::new(index.to_uint()))
  }
  let fixtures = [
    [set(1), get(1), get(2)],
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([set(1), get(1)]),
      ),
      get(1),
    ],
    [
      set(1),
      @lib.Instruction::loop_(
        @lib.BlockType::void_(),
        @lib.Expr::new([get(1), get(2), set(2)]),
      ),
    ],
    [@lib.Instruction::if_(@lib.BlockType::void_(), [set(1)], Some([get(1)]))],
    [
      @lib.Instruction::if_(@lib.BlockType::void_(), [set(1)], Some([set(1)])),
      get(1),
    ],
    [
      @lib.Instruction::try_(
        @lib.BlockType::void_(),
        @lib.Expr::new([set(1)]),
        [@lib.LegacyCatch::all(@lib.Expr::new([get(1), set(2)]))],
      ),
      get(2),
    ],
    [
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [],
        @lib.Expr::new([set(1)]),
      ),
      get(1),
    ],
    [
      @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
      get(1),
      @lib.Instruction::return_(),
      get(2),
    ],
  ]
  for body in fixtures {
    let actual = inl_locals_read_before_write(body, 1, 3)
    for offset in 0..<3 {
      assert_eq(
        actual[offset],
        inl_local_may_read_before_write(body, 1 + offset),
      )
    }
  }
  assert_eq(inl_locals_read_before_write([get(0), set(1), get(1)], 1, 2), [
    false, false,
  ])
  assert_eq(inl_locals_read_before_write([get(1)], 1, 0), [])
}
