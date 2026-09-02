///|
test "coalesce-locals dense relations use indexed bitset rows" {
  let relations = CLBitMatrix::new(4096)
  cl_bit_matrix_set(relations, 3, 4095, true)
  cl_bit_matrix_set(relations, 4095, 3, true)
  assert_true(cl_bit_matrix_get(relations, 3, 4095))
  assert_true(cl_bit_matrix_get(relations, 4095, 3))
  assert_false(cl_bit_matrix_get(relations, 3, 4094))
  @debug.assert_eq(relations.size, 4096)
  @debug.assert_eq(relations.bits.length(), 4096 * 4095 / 2)
}

///|
test "coalesce-locals evaluates each exact coloring order once" {
  let (distinct, visited) = cl_distinct_coloring_orders_with_visits([
    [2, 3, 4],
    [4, 3, 2],
    [2, 3, 4],
    [2, 4, 3],
    [4, 3, 2],
  ])
  @debug.assert_eq(distinct, [[2, 3, 4], [4, 3, 2], [2, 4, 3]])
  @debug.assert_eq(visited, 5)
}

///|
test "coalesce-locals summarizes deep interval control once" {
  let nested : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
  ]
  for _ in 0..<256 {
    let then_body = nested.copy()
    nested.clear()
    nested.push(
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        then_body,
        Some([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
      ),
    )
  }
  let visited = cl_mark_structured_local_intervals_with_visits(
    nested,
    Array::make(1, -1),
    Array::make(1, -1),
    Array::make(1, false),
    Array::make(1, false),
    true,
    [0],
  )
  assert_true(visited <= 520)
}

///|
test "coalesce-locals interval summary stops after a block-level parent escape" {
  let first = Array::make(1, -1)
  ignore(
    cl_mark_structured_local_intervals_with_visits(
      [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(1U))]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ],
      first,
      Array::make(1, -1),
      Array::make(1, false),
      Array::make(1, false),
      true,
      [0],
    ),
  )
  @debug.assert_eq(first[0], -1)
}

///|
test "coalesce-locals control summaries match escape predicates" {
  let br0 = @lib.Instruction::br(@lib.LabelIdx::new(0U))
  let br1 = @lib.Instruction::br(@lib.LabelIdx::new(1U))
  let cases = [
    br0,
    br1,
    @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new([br0])),
    @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new([br1])),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([br1, @lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::if_(@lib.BlockType::void_(), [br1], Some([br1])),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::return_()]),
    ),
  ]
  for instr in cases {
    let summary = cl_mark_structured_interval_instruction(
      instr,
      [],
      [],
      [],
      [],
      false,
      [0],
      false,
      [0],
    )
    @debug.assert_eq(
      summary.never_falls_through,
      cl_instr_never_falls_through(instr),
    )
    for boundary in 0..<4 {
      @debug.assert_eq(
        summary.max_escape_boundary >= boundary,
        cl_instr_escapes_past_depth(instr, boundary),
      )
    }
  }
}

///|
test "coalesce-locals sparse CFG interference scales with live locals" {
  let interferences = CLCfgSparseInterferences::new(4096)
  let pair_checks = cl_cfg_sparse_add_live_member_interferences(interferences, [
    3, 1024, 4095,
  ])
  assert_true(cl_cfg_sparse_interferes(interferences, 3, 1024))
  assert_true(cl_cfg_sparse_interferes(interferences, 3, 4095))
  assert_true(cl_cfg_sparse_interferes(interferences, 1024, 4095))
  assert_false(cl_cfg_sparse_interferes(interferences, 3, 4))
  @debug.assert_eq(pair_checks, 3)
}

///|
test "coalesce-locals indexes retained copy destinations in one action scan" {
  let actions : Array[CLAction] = []
  for _ in 0..<4096 {
    actions.push({
      kind: CLActionKind::Set,
      local_idx: 3,
      source: CLValueSource::Local(2),
    })
  }
  actions.push({
    kind: CLActionKind::Set,
    local_idx: 2,
    source: CLValueSource::Unique,
  })
  actions.push({
    kind: CLActionKind::Get,
    local_idx: 3,
    source: CLValueSource::Unique,
  })
  let (preferred, visited_actions) = cl_retained_copy_destination_flags_with_visits(
    actions,
    [
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ],
    2,
  )
  assert_true(preferred[3])
  @debug.assert_eq(visited_actions, actions.length())
}

///|
test "coalesce-locals copy-forward candidates follow sparse weighted edges" {
  let weights = CLCopyWeights::new(64)
  for edge in [(2, 3), (3, 4), (4, 5), (5, 6), (6, 7)] {
    let (lhs, rhs) = edge
    cl_copy_weight_add(weights, lhs, rhs, 1)
  }
  let (reachable, visited_edges) = cl_copy_weight_reachable_destinations(
    weights, 2, 4,
  )
  assert_true(reachable[3])
  assert_true(reachable[4])
  assert_true(reachable[5])
  assert_true(reachable[6])
  assert_false(reachable[7])
  assert_false(reachable[63])
  assert_true(visited_edges <= 10)
}

///|
test "coalesce-locals indexes tail reuse facts in two action scans" {
  let actions : Array[CLAction] = [
    { kind: CLActionKind::Get, local_idx: 0, source: CLValueSource::Unique, },
    { kind: CLActionKind::Set, local_idx: 2, source: CLValueSource::Unique, },
    { kind: CLActionKind::Get, local_idx: 2, source: CLValueSource::Unique, },
  ]
  for _ in 0..<4096 {
    actions.push({
      kind: CLActionKind::Get,
      local_idx: 3,
      source: CLValueSource::Unique,
    })
  }
  let effective = Array::make(actions.length(), true)
  let depths = Array::make(actions.length(), 0)
  let (facts, visited_actions) = cl_tail_reuse_facts_with_visits(
    actions, effective, depths, 4,
  )
  assert_true(cl_tail_reuse_pair_safe_from_facts(facts, 2, 0))
  assert_true(visited_actions <= actions.length() * 2)
}

///|
test "coalesce-locals source-write hazards scan only missing edges" {
  let interferences = CLBitMatrix::new(4)
  for lhs in 0..<4 {
    for rhs in 0..<4 {
      cl_bit_matrix_set(interferences, lhs, rhs, true)
    }
  }
  cl_bit_matrix_set_symmetric(interferences, 2, 0, false)
  cl_bit_matrix_set_symmetric(interferences, 2, 3, false)
  let candidates = cl_source_write_dest_read_candidate_dests(
    2,
    [true, true, true, true],
    [
      @lib.ValType::i32(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ],
    interferences,
    [-1, -1, 4, -1],
    [3, -1, -1, 5],
  )
  @debug.assert_eq(candidates, [3])
}

///|
test "coalesce-locals path-disjoint scans only existing interference edges" {
  let interferences = CLBitMatrix::new(5)
  cl_bit_matrix_set_symmetric(interferences, 2, 4, true)
  let candidates = cl_path_disjoint_candidate_dests(
    2,
    [false, false, true, true, true],
    [
      @lib.ValType::i32(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ],
    interferences,
  )
  @debug.assert_eq(candidates, [4])
}

///|
test "coalesce-locals consume-forward candidates require temporal overlap" {
  let interferences = CLBitMatrix::new(5)
  for lhs in 0..<5 {
    for rhs in 0..<5 {
      cl_bit_matrix_set(interferences, lhs, rhs, true)
    }
  }
  let syntactic_candidates : Array[@bitset.BitSet] = []
  for _ in 0..<5 {
    syntactic_candidates.push(@bitset.BitSet::make(5, true))
  }
  let candidates = cl_consume_forward_candidate_dests(
    2,
    [false, false, true, false, false],
    [false, false, true, true, true],
    [
      @lib.ValType::i32(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ],
    interferences,
    [-1, -1, 4, -1, -1],
    [-1, -1, 3, 5, 2],
    syntactic_candidates,
  )
  @debug.assert_eq(candidates, [3])
}

///|
test "coalesce-locals structured liveness collects write-live hazards once" {
  let source = @lib.LocalIdx::new(2U)
  let dest = @lib.LocalIdx::new(1U)
  let copied_dest = @lib.LocalIdx::new(3U)
  let instrs = [
    @lib.Instruction::local_get(copied_dest),
    @lib.Instruction::local_set(source),
    @lib.Instruction::i32_const(@lib.I32(11)),
    @lib.Instruction::local_set(source),
    @lib.Instruction::local_get(source),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(dest),
    @lib.Instruction::drop(),
  ]
  let actions : Array[CLAction] = []
  cl_collect_instrs(instrs, actions, 4)
  let (_, hazards, visited_actions) = cl_compute_structured_liveness_with_write_hazards(
    instrs, actions, 4,
  )
  assert_true(cl_bit_matrix_get(hazards, 2, 1))
  assert_false(cl_bit_matrix_get(hazards, 2, 3))
  @debug.assert_eq(visited_actions, actions.length())
}

///|
test "coalesce-locals pair-forward scans reject nested global barriers once" {
  assert_true(
    cl_pair_forward_scans_have_global_barrier([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
      ),
    ]),
  )
  assert_false(
    cl_pair_forward_scans_have_global_barrier([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
    ]),
  )
}

///|
test "coalesce-locals consume-forward candidates stay within one direct region" {
  let source = @lib.LocalIdx::new(2U)
  let direct_dest = @lib.LocalIdx::new(3U)
  let separated_dest = @lib.LocalIdx::new(4U)
  let candidates = cl_consume_forward_syntactic_candidates(
    [
      @lib.Instruction::local_get(source),
      @lib.Instruction::local_set(direct_dest),
      @lib.Instruction::local_get(source),
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
      @lib.Instruction::local_set(separated_dest),
    ],
    5,
  )
  assert_true(candidates[2][3])
  assert_false(candidates[2][4])
}

///|
test "coalesce-locals reuses one body local across deep control linearly" {
  let nested : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ]
  for _ in 0..<512 {
    let body = nested.copy()
    nested.clear()
    nested.push(
      @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(body)),
    )
  }
  let func = @lib.Func::new(
    @lib.Locals::single(1U, @lib.ValType::i32()),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::drop(),
      nested[0],
    ]),
  )
  let (rewrite, visited_instrs) = cl_rewrite_single_body_local_param_fast(
    func,
    [@lib.ValType::i32()],
  )
  match rewrite {
    Some(rewrite) => {
      let @lib.Func(locals, @lib.Expr(instrs)) = rewrite.func
      @debug.assert_eq(locals.length(), 0)
      assert_true(
        instrs[0] == @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      )
      assert_true(instrs[1] == @lib.Instruction::i32_const(@lib.I32(0)))
    }
    None => fail("expected one-local parameter reuse")
  }
  assert_true(visited_instrs <= 520)
}

///|
test "coalesce-locals one-local fast path prefers the copied parameter" {
  let func = @lib.Func::new(
    @lib.Locals::single(1U, @lib.ValType::i32()),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    ]),
  )
  let (rewrite, _) = cl_rewrite_single_body_local_param_fast(func, [
    @lib.ValType::i32(),
    @lib.ValType::i32(),
    @lib.ValType::i32(),
  ])
  match rewrite {
    Some(rewrite) => {
      let @lib.Func(_, @lib.Expr(instrs)) = rewrite.func
      @debug.assert_eq(instrs, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ])
    }
    None => fail("expected copied parameter reuse")
  }
}

///|
test "coalesce-locals one-local fast path rejects partial parameter overwrite" {
  let func = @lib.Func::new(
    @lib.Locals::single(1U, @lib.ValType::i32()),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::drop(),
        ],
        Some([]),
      ),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::drop(),
    ]),
  )
  let (rewrite, _) = cl_rewrite_single_body_local_param_fast(func, [
    @lib.ValType::i32(),
    @lib.ValType::i32(),
  ])
  assert_true(rewrite is None)
}

///|
test "coalesce-locals keeps copied destinations live across later slot writes" {
  let module_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func (result i32) (local i32 i32 i32)
      #|    i32.const 11
      #|    local.set 0
      #|    local.get 0
      #|    local.set 1
      #|    i32.const 22
      #|    local.set 2
      #|    local.get 2
      #|    drop
      #|    local.get 1))
    ),
  )
  let @lib.Func(body_locals, @lib.Expr(instrs)) = match module_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs[0]
    None => fail("expected code section")
  }
  let types = cl_all_local_types([], body_locals)
  let actions : Array[CLAction] = []
  cl_collect_instrs(instrs, actions, types.length())
  let liveness = cl_compute_liveness(actions, types.length())
  let interferences = cl_compute_linear_interferences(
    instrs, actions, liveness, types, 0,
  )
  assert_true(
    cl_bit_matrix_get(interferences, 2, 1),
    msg="later local write must interfere with the still-live copied destination",
  )
}

///|
test "coalesce-locals scans memory-size snapshots across parameter writes linearly" {
  let instrs : Array[@lib.Instruction] = []
  let parameter = @lib.LocalIdx::new(0U)
  let snapshot = @lib.LocalIdx::new(1U)
  for value = 0; value < 4096; value = value + 1 {
    instrs.push(@lib.Instruction::memory_size(@lib.MemIdx::new(0U)))
    instrs.push(@lib.Instruction::local_tee(snapshot))
    instrs.push(@lib.Instruction::drop())
    instrs.push(@lib.Instruction::i32_const(@lib.I32(value)))
    instrs.push(@lib.Instruction::local_set(parameter))
  }
  assert_false(cl_instrs_have_local_snapshot_across_parameter_write(instrs, 1))
}

///|
test "coalesce-locals indexes only effective writers and observed readers for copied-destination hazards" {
  let instrs = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ]
  let actions : Array[CLAction] = []
  cl_collect_instrs(instrs, actions, 4)
  let (writers, readers) = cl_source_write_dest_read_active_flags(
    actions,
    [true, true],
    4,
  )
  assert_false(writers[0])
  assert_false(writers[1])
  assert_true(writers[2])
  assert_false(writers[3])
  assert_false(readers[0])
  assert_true(readers[1])
  assert_false(readers[2])
  assert_false(readers[3])
  let (syntactic_reads, syntactic_writes) = cl_local_read_write_flags(
    actions, 4,
  )
  assert_false(syntactic_reads[0])
  assert_true(syntactic_reads[1])
  assert_false(syntactic_reads[2])
  assert_false(syntactic_reads[3])
  assert_false(syntactic_writes[0])
  assert_false(syntactic_writes[1])
  assert_true(syntactic_writes[2])
  assert_false(syntactic_writes[3])
}

///|
test "coalesce-locals computes all copied-destination hazards in one source scan" {
  let source = @lib.LocalIdx::new(2U)
  let clobbered_dest = @lib.LocalIdx::new(1U)
  let copied_dest = @lib.LocalIdx::new(3U)
  let instrs = [
    @lib.Instruction::local_get(copied_dest),
    @lib.Instruction::local_set(source),
    @lib.Instruction::local_get(copied_dest),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(11)),
    @lib.Instruction::local_set(source),
    @lib.Instruction::local_get(clobbered_dest),
    @lib.Instruction::drop(),
  ]
  let actions : Array[CLAction] = []
  cl_collect_instrs(instrs, actions, 4)
  let effective = Array::make(actions.length(), true)
  let hazards = cl_source_write_dest_read_hazards(
    instrs,
    effective,
    2,
    [0, 1, 3],
    4,
  )
  assert_false(hazards[0])
  assert_true(hazards[1])
  assert_false(hazards[2])
  assert_false(hazards[3])
}
