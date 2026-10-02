///|
test "cleanup read collection preserves encounter order with bounded membership work" {
  let nested = Array::makei(32, fn(index) {
    @lib.Instruction::local_get(@lib.LocalIdx::new(index.to_uint()))
  })
  let body = [
    @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(nested)),
  ]
  let saved = sl_leaf_bytes(body)
  let reads : Array[Int] = []
  let probes = [0]
  run_hot_pipeline_simplify_locals_lowered_collect_local_reads(
    body,
    reads,
    membership_probes=Some(probes),
  )
  assert_eq(reads, Array::makei(32, fn(index) { index }))
  assert_eq(sl_leaf_bytes(body), saved)
  assert_true(probes[0] <= 64, msg="membership work: \{probes[0]}")
}

///|
test "wide inherited liveout keeps local captures and sibling read ordering" {
  let capture = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
  ]
  let inherited = Array::makei(32, fn(index) { index })
  let saved = inherited.copy()
  let output = run_hot_pipeline_simplify_locals_lowered_drop_dead_adjacent_local_set_get_pairs_with_liveout(
    capture, inherited,
  )
  assert_eq(output, capture)
  assert_eq(inherited, saved)
}

///|
test "cleanup read sets keep tiny scans, sparse membership and independent copies" {
  let tiny = SlCleanupReadSet::new([])
  for index in 0..<8 {
    tiny.insert(index)
  }
  assert_true(tiny.members is None)
  assert_true(tiny.contains(7))
  assert_true(tiny.members is None)
  tiny.insert(2147483647)
  assert_true(tiny.contains(2147483647))
  assert_true(tiny.members is Some(_))
  assert_false(tiny.contains(-1))
  let sibling = tiny.copy()
  assert_true(sibling.members is Some(_))
  sibling.insert(-1)
  assert_true(sibling.contains(-1))
  assert_false(tiny.contains(-1))
  tiny.insert(1000)
  assert_true(tiny.contains(1000))
  assert_false(sibling.contains(1000))
  assert_eq(tiny.reads, [0, 1, 2, 3, 4, 5, 6, 7, 2147483647, 1000])
  assert_eq(sibling.reads, [0, 1, 2, 3, 4, 5, 6, 7, 2147483647, -1])
  let duplicates = [4, 4]
  let set = SlCleanupReadSet::new(duplicates)
  set.insert(4)
  set.insert(6)
  assert_eq(duplicates, [4, 4, 6])
}

///|
test "wide loop reads do not leak into following sibling cleanup" {
  let capture = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
  ]
  let reads : Array[@lib.Instruction] = []
  for index in 0..<32 {
    reads.push(@lib.Instruction::local_get(@lib.LocalIdx::new(index.to_uint())))
    reads.push(@lib.Instruction::drop())
  }
  let loop_body = reads.copy()
  loop_body.append(capture)
  let body = [
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(loop_body)),
    @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(capture)),
  ]
  let saved = sl_leaf_bytes(body)
  let output = run_hot_pipeline_simplify_locals_lowered_drop_dead_adjacent_local_set_get_pairs(
    body,
  )
  assert_eq(output[0], body[0])
  assert_eq(
    output[1],
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::drop(),
      ]),
    ),
  )
  assert_eq(sl_leaf_bytes(body), saved)
}

///|
test "cleanup wide read membership packs adjacent locals without conflating word boundaries" {
  let reads = Array::makei(32, fn(index) { index })
  let set = SlCleanupReadSet::new(reads)
  for index in 0..<32 {
    assert_true(set.contains(index))
  }
  assert_false(set.contains(32))
  assert_true(set.members is None)
  assert_eq(set.bits, 0xffffffffUL)
  set.insert(32)
  assert_true(set.contains(32))
  assert_false(set.contains(63))
  set.insert(63)
  assert_true(set.contains(63))
  assert_false(set.contains(64))
  assert_true(set.members is None)
  set.insert(64)
  assert_true(set.contains(64))
  assert_false(set.contains(65))
  assert_eq(set.members.unwrap().length(), 1)
  assert_eq(reads, Array::makei(32, fn(index) { index }) + [32, 63, 64])
}

///|
test "cleanup overflow membership uses bounded words across unsigned sign bits" {
  let set = SlCleanupReadSet::new(Array::makei(9, fn(index) { index }))
  let overflow = [64, 95, 96, 127, 2147483647, -1]
  for local_id in overflow {
    set.insert(local_id)
  }
  for local_id in overflow {
    assert_true(set.contains(local_id))
  }
  for absent in [63, 65, 94, 97, 126, 128, 2147483646, -2] {
    assert_false(set.contains(absent))
  }
  let members = set.members.unwrap()
  assert_eq(members.get(2).unwrap_or(0).to_int64(), 2147483649L)
  assert_eq(members.get(3).unwrap_or(0).to_int64(), 2147483649L)
  assert_eq(set.reads, Array::makei(9, fn(index) { index }) + overflow)
}
