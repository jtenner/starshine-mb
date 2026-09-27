///|
fn structured_lifetime_summary_fixture(count : Int) -> Array[@lib.Instruction] {
  let body : Array[@lib.Instruction] = []
  for local in 0..<count {
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
    body.push(
      @lib.Instruction::local_set(
        @lib.LocalIdx::new(local.reinterpret_as_uint()),
      ),
    )
  }
  for _ in 0..<count {
    body.push(
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::local_get(
            @lib.LocalIdx::new(count.reinterpret_as_uint()),
          ),
          @lib.Instruction::drop(),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::drop(),
        ]),
      ),
    )
  }
  body
}

///|
test "structured lifetime summaries bound candidate-rich prefixes without losing hazards" {
  let body = structured_lifetime_summary_fixture(32)
  let original = body.copy()
  let visits = [0]
  assert_false(
    run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
      body,
      visits=Some(visits),
    ),
  )
  assert_eq(body, original)
  assert_true(visits[0] <= 512, msg="structured prefix visits: \{visits[0]}")
  body.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::drop(),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::drop(),
      ]),
    ),
  )
  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
      body,
    ),
  )
}

///|
fn structured_lifetime_candidate_free_fixture(
  count : Int,
) -> Array[@lib.Instruction] {
  let body : Array[@lib.Instruction] = []
  for local in 0..<count {
    body.push(
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::local_get(
            @lib.LocalIdx::new(local.reinterpret_as_uint()),
          ),
          @lib.Instruction::drop(),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::drop(),
        ]),
      ),
    )
  }
  body
}

///|
test "structured lifetime avoids summaries without captures and retains nested hazards" {
  let body = structured_lifetime_candidate_free_fixture(32)
  let original = body.copy()
  let summaries = [0]
  assert_false(
    run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
      body,
      summaries=Some(summaries),
    ),
  )
  assert_eq(body, original)
  assert_eq(summaries[0], 0)
  let nested = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  ]
  for instr in body {
    nested.push(instr)
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
      [@lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(nested))],
      summaries=Some(summaries),
    ),
  )
  assert_eq(summaries[0], 1)
  summaries[0] = 0
  body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
  body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  assert_false(
    run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
      body,
      summaries=Some(summaries),
    ),
  )
  assert_eq(summaries[0], 0)
}

///|
test "structured lifetime visits a late nested capture without resummarizing preceding bodies" {
  let body = structured_lifetime_candidate_free_fixture(32)
  body.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        body[0],
      ]),
    ),
  )
  let original = body.copy()
  let visits = [0]
  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
      body,
      visits=Some(visits),
    ),
  )
  assert_eq(body, original)
  assert_true(visits[0] <= 300, msg="late-capture visits: \{visits[0]}")
}
