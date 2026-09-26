///|
test "simplify-locals flat cleanup removes a dead capture without child liveout scans" {
  let body : Array[@lib.Instruction] = []
  for value = 0; value < 128; value = value + 1 {
    body.push(@lib.Instruction::i32_const(@lib.I32(value)))
    body.push(@lib.Instruction::drop())
  }
  body.push(@lib.Instruction::i32_const(@lib.I32(7)))
  body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  let scans = [0]
  let out = run_hot_pipeline_simplify_locals_lowered_drop_dead_adjacent_local_set_get_pairs_with_liveout(
    body,
    [],
    child_liveout_contexts=Some(scans),
  )
  assert_eq(out.length(), 258)
  for idx = 0; idx < 257; idx = idx + 1 {
    assert_eq(out[idx], body[idx])
  }
  assert_eq(out[257], @lib.Instruction::nop())
  assert_eq(scans[0], 0)
}

///|
test "simplify-locals child cleanup preserves captures read by later siblings" {
  let capture = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
  ]
  let body = [
    @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(capture)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ]
  let scans = [0]
  let out = run_hot_pipeline_simplify_locals_lowered_drop_dead_adjacent_local_set_get_pairs_with_liveout(
    body,
    [],
    child_liveout_contexts=Some(scans),
  )
  assert_eq(out, body)
  assert_eq(scans[0], 1)
}

///|
test "simplify-locals structured siblings preserve captures with one suffix walk" {
  let body : Array[@lib.Instruction] = []
  for value = 0; value < 128; value = value + 1 {
    body.push(
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(value)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
        ]),
      ),
    )
  }
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  body.push(@lib.Instruction::drop())
  let visits = [0]
  let out = run_hot_pipeline_simplify_locals_lowered_drop_dead_adjacent_local_set_get_pairs_with_liveout(
    body,
    [],
    suffix_root_visits=Some(visits),
  )
  assert_eq(out, body)
  assert_true(
    visits[0] <= body.length(),
    msg="suffix roots visited: \{visits[0]}",
  )
}

///|
test "simplify-locals liveout uses original sibling reads before child cleanup" {
  let capture = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
  ]
  let first = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new(capture),
  )
  let out = run_hot_pipeline_simplify_locals_lowered_drop_dead_adjacent_local_set_get_pairs_with_liveout(
    [first, first],
    [],
  )
  assert_eq(out[0], first)
  assert_eq(
    out[1],
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::drop(),
      ]),
    ),
  )
}
