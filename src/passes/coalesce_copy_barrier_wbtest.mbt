///|
fn cl_copy_barrier_full_matrix(size : Int) -> CLBitMatrix {
  let matrix = CLBitMatrix::new(size)
  for lhs in 0..<size {
    for rhs in (lhs + 1)..<size {
      cl_bit_matrix_set_symmetric(matrix, lhs, rhs, true)
    }
  }
  matrix
}

///|
fn cl_copy_barrier_assert_same(
  instrs : Array[@lib.Instruction],
  types : Array[@lib.ValType],
  weights : CLCopyWeights,
) -> CLBitMatrix raise {
  let before = cl_copy_barrier_full_matrix(types.length())
  let after = cl_copy_barrier_full_matrix(types.length())
  let saved = weights.rows.map(fn(row) { row.copy() })
  cl_copy_barrier_reference_remove(instrs, types, 1, before, weights)
  cl_remove_safe_copy_forward_interferences(instrs, types, 1, after, weights)
  for lhs in 0..<types.length() {
    for rhs in (lhs + 1)..<types.length() {
      assert_eq(
        cl_bit_matrix_get(after, lhs, rhs),
        cl_bit_matrix_get(before, lhs, rhs),
      )
    }
  }
  assert_eq(weights.rows, saved)
  after
}

///|
test "coalesce global rejection preserves all copy-forward matrix answers" {
  let label = @lib.LabelIdx::new(0U)
  // These are region fragments for the existing pair-proof contract: crossing
  // these control barriers is intentionally unsupported by this proof alone.
  let barriers : Array[@lib.Instruction] = [
    @lib.Instruction::br(label),
    @lib.Instruction::br_if(label),
    @lib.Instruction::br_table([label], label),
    @lib.Instruction::return_(),
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new([])),
    @lib.Instruction::try_table(@lib.BlockType::void_(), [], @lib.Expr::new([])),
  ]
  let weights = CLCopyWeights::new(4)
  cl_copy_weight_add(weights, 1, 2, 1)
  cl_copy_weight_add(weights, 2, 3, 1)
  for barrier in barriers {
    for
      shell in [
        barrier,
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([barrier]),
        ),
        @lib.Instruction::if_(@lib.BlockType::void_(), [barrier], Some([])),
        @lib.Instruction::if_(@lib.BlockType::void_(), [], Some([barrier])),
      ] {
      let instrs = [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
        shell,
      ]
      assert_false(cl_copy_forward_pair_safe(instrs, 1, 3))
      let after = cl_copy_barrier_assert_same(
        instrs,
        Array::make(4, @lib.ValType::i32()),
        weights,
      )
      assert_true(cl_bit_matrix_get(after, 1, 3))
    }
  }
}

///|
test "coalesce barrier-free chained copies still remove proven conflicts" {
  let instrs = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
  ]
  let weights = CLCopyWeights::new(4)
  cl_copy_weight_add(weights, 1, 2, 1)
  cl_copy_weight_add(weights, 2, 3, 1)
  let after = cl_copy_barrier_assert_same(
    instrs,
    Array::make(4, @lib.ValType::i32()),
    weights,
  )
  assert_false(cl_bit_matrix_get(after, 1, 2))
  assert_false(cl_bit_matrix_get(after, 1, 3))
  assert_false(cl_bit_matrix_get(after, 2, 3))
  assert_true(cl_bit_matrix_get(after, 0, 1))
}

///|
test "coalesce copy preflight retains pending failures and type boundaries" {
  let weights = CLCopyWeights::new(4)
  cl_copy_weight_add(weights, 1, 2, 1)
  cl_copy_weight_add(weights, 2, 3, 1)
  for
    instrs in [
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ],
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      ],
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      ],
    ] {
    let after = cl_copy_barrier_assert_same(
      instrs,
      [
        @lib.ValType::i32(),
        @lib.ValType::i32(),
        @lib.ValType::i64(),
        @lib.ValType::i32(),
      ],
      weights,
    )
    assert_true(cl_bit_matrix_get(after, 1, 2))
  }
}
