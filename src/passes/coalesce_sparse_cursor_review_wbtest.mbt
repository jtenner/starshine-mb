///|
test "coalesce sparse cursors preserve adjacency and scoped pair decisions" {
  let local = fn(index : Int32) { @lib.LocalIdx::new(index.to_uint()) }
  let patterns = [
    [
      @lib.Instruction::local_set(local(0)),
      @lib.Instruction::local_get(local(0)),
      @lib.Instruction::local_set(local(1)),
    ],
    [
      @lib.Instruction::local_set(local(0)),
      @lib.Instruction::local_get(local(0)),
      @lib.Instruction::nop(),
      @lib.Instruction::local_set(local(1)),
      @lib.Instruction::local_get(local(0)),
    ],
    [
      @lib.Instruction::local_get(local(1)),
      @lib.Instruction::local_set(local(0)),
      @lib.Instruction::local_get(local(0)),
      @lib.Instruction::local_tee(local(1)),
      @lib.Instruction::local_get(local(1)),
    ],
    [
      @lib.Instruction::local_set(local(0)),
      @lib.Instruction::local_get(local(2)),
      @lib.Instruction::local_set(local(1)),
      @lib.Instruction::local_get(local(0)),
    ],
  ]
  for base in patterns {
    for shape in 0..<7 {
      let body = match shape {
        0 => base
        1 =>
          [
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new(base),
            ),
          ]
        2 =>
          [
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              base,
              Some(base.copy()),
            ),
          ]
        3 => base + [@lib.Instruction::if_(@lib.BlockType::void_(), base, None)]
        4 =>
          [
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  base,
                  Some(base.copy()),
                ),
              ]),
            ),
          ]
        5 => base + [@lib.Instruction::br(@lib.LabelIdx::new(0U))]
        _ =>
          base +
          [
            @lib.Instruction::loop_(
              @lib.BlockType::void_(),
              @lib.Expr::new(base),
            ),
          ]
      }
      let index = cl_local_proof_index(body)
      for source in 0..<4 {
        for dest in 0..<4 {
          if source == dest {
            continue
          }
          assert_eq(
            index.consume_pair_safe(source, dest),
            cl_consume_forward_pair_safe(body, source, dest),
            msg="consume shape=\{shape} source=\{source} dest=\{dest}",
          )
          assert_eq(
            index.path_pair_safe(source, dest),
            cl_path_disjoint_branch_result_pair_safe(body, source, dest),
            msg="path shape=\{shape} source=\{source} dest=\{dest}",
          )
        }
      }
    }
  }
}

///|
test "coalesce sparse cursors keep empty rows and cached queries exact" {
  let body = Array::make(128, @lib.Instruction::nop())
  body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
  let empty = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([]),
  )
  body.push(
    @lib.Instruction::if_(@lib.BlockType::void_(), [empty], Some([empty])),
  )
  let index = cl_local_proof_index(body, local_count=12)
  for source in 0..<12 {
    for dest in 0..<12 {
      assert_eq(
        index.consume_pair_safe(source, dest),
        cl_consume_forward_pair_safe(body, source, dest),
      )
      assert_eq(
        index.path_pair_safe(source, dest),
        cl_path_disjoint_branch_result_pair_safe(body, source, dest),
      )
    }
  }
  let cache = CLLocalProofCache::new(local_count=12)
  for _ in 0..<8 {
    assert_eq(
      cache.consume_pair_safe(body, 0, 1),
      cl_consume_forward_pair_safe(body, 0, 1),
    )
    assert_eq(
      cache.path_pair_safe(body, 0, 1),
      cl_path_disjoint_branch_result_pair_safe(body, 0, 1),
    )
  }
}
