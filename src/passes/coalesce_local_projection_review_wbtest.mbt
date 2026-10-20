///|
fn cl_local_projection_dense_access_review_bench(
  it : @bench.T,
  repetitions : Int32,
  indexed : Bool,
) -> Unit {
  let local_count = 4
  let body : Array[@lib.Instruction] = []
  for _ in 0..<repetitions {
    for local in 0..<local_count {
      body.push(@lib.Instruction::i32_const(@lib.I32(7)))
      body.push(
        @lib.Instruction::local_set(@lib.LocalIdx::new(local.to_uint())),
      )
      body.push(
        @lib.Instruction::local_get(@lib.LocalIdx::new(local.to_uint())),
      )
      body.push(@lib.Instruction::drop())
    }
  }
  it.bench(fn() {
    let cache = CLLocalProofCache::new(local_count~)
    let mut safe = 0
    for source in 0..<local_count {
      for dest in 0..<local_count {
        if source == dest {
          continue
        }
        let pair_safe = if indexed && local_count > 8 {
          cache.path_pair_safe(body, source, dest)
        } else {
          cl_path_disjoint_branch_result_pair_safe(body, source, dest)
        }
        if pair_safe {
          safe += 1
        }
      }
    }
    it.keep(safe)
  })
}

///|
test "bench coalesce projection dense pair fallback raw" (it : @bench.T) {
  cl_local_projection_dense_access_review_bench(it, 256, false)
}

///|
test "bench coalesce projection dense pair fallback indexed" (it : @bench.T) {
  cl_local_projection_dense_access_review_bench(it, 256, true)
}

///|
test "coalesce sparse local proofs preserve pair states and original copy adjacency" {
  let local = fn(i : Int32) { @lib.LocalIdx::new(i.to_uint()) }
  let base = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(local(0)),
    @lib.Instruction::local_get(local(0)),
    @lib.Instruction::nop(),
    @lib.Instruction::local_set(local(1)),
    @lib.Instruction::local_get(local(0)),
    @lib.Instruction::local_set(local(2)),
    @lib.Instruction::local_get(local(1)),
    @lib.Instruction::local_tee(local(0)),
    @lib.Instruction::local_get(local(2)),
    @lib.Instruction::drop(),
  ]
  for shape in 0..<6 {
    let body = match shape {
      0 => base
      1 =>
        [@lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(base))]
      2 =>
        [
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            base,
            Some(base.copy()),
          ),
        ]
      3 =>
        [
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(@lib.BlockType::void_(), base, None),
        ] +
        base
      4 => base + [@lib.Instruction::br(@lib.LabelIdx::new(0U))]
      _ =>
        [
          @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(base)),
          @lib.Instruction::if_(@lib.BlockType::void_(), [], Some(base.copy())),
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

///|
fn cl_local_projection_review_fixture(width : Int32) -> Array[@lib.Instruction] {
  let body : Array[@lib.Instruction] = []
  for local in 0..<width {
    body.push(@lib.Instruction::i32_const(@lib.I32(local)))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(local.to_uint())))
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(local.to_uint())))
    body.push(@lib.Instruction::drop())
  }
  body
}

///|
fn cl_local_projection_review_bench(
  it : @bench.T,
  width : Int32,
  dense : Bool,
  consume : Bool,
  indexed : Bool,
  verify_pairs~ : Bool = true,
) -> Unit {
  let local_count = if dense { width } else { width * 2 }
  let body = cl_local_projection_review_fixture(local_count)
  if verify_pairs {
    let cache = CLLocalProofCache::new(local_count~)
    // Check each observed decision before timing either control.
    for source in 0..<width {
      let destinations = if dense {
        Array::makei(width - source - 1, fn(i) { source + i + 1 })
      } else {
        [source + width]
      }
      for dest in destinations {
        if consume {
          if cache.consume_pair_safe(body, source, dest) !=
            cl_consume_forward_pair_safe(body, source, dest) {
            abort("consume sparse proof changed a pair decision")
          }
        } else if cache.path_pair_safe(body, source, dest) !=
          cl_path_disjoint_branch_result_pair_safe(body, source, dest) {
          abort("path sparse proof changed a pair decision")
        }
      }
    }
  }
  it.bench(fn() {
    let cache = CLLocalProofCache::new(local_count~)
    let mut safe = 0
    for source in 0..<width {
      let destinations = if dense {
        Array::makei(width - source - 1, fn(i) { source + i + 1 })
      } else {
        [source + width]
      }
      for dest in destinations {
        let pair_safe = if indexed && local_count > 8 {
          if consume {
            cache.consume_pair_safe(body, source, dest)
          } else {
            cache.path_pair_safe(body, source, dest)
          }
        } else if consume {
          cl_consume_forward_pair_safe(body, source, dest)
        } else {
          cl_path_disjoint_branch_result_pair_safe(body, source, dest)
        }
        if pair_safe {
          safe += 1
        }
      }
    }
    it.keep(safe)
  })
}

///|
test "bench coalesce consume sparse 256 raw" (it : @bench.T) {
  cl_local_projection_review_bench(it, 256, false, true, false)
}

///|
test "bench coalesce consume sparse 256 indexed" (it : @bench.T) {
  cl_local_projection_review_bench(it, 256, false, true, true)
}

///|
test "bench coalesce consume sparse 512 raw" (it : @bench.T) {
  cl_local_projection_review_bench(it, 512, false, true, false)
}

///|
test "bench coalesce consume sparse 512 indexed" (it : @bench.T) {
  cl_local_projection_review_bench(it, 512, false, true, true)
}

///|
test "bench coalesce consume dense 64 raw" (it : @bench.T) {
  cl_local_projection_review_bench(it, 64, true, true, false)
}

///|
test "bench coalesce consume dense 64 indexed" (it : @bench.T) {
  cl_local_projection_review_bench(it, 64, true, true, true)
}

///|
test "bench coalesce consume dense 128 raw" (it : @bench.T) {
  cl_local_projection_review_bench(it, 128, true, true, false)
}

///|
test "bench coalesce consume dense 128 indexed" (it : @bench.T) {
  cl_local_projection_review_bench(it, 128, true, true, true)
}

///|
test "bench coalesce path sparse 256 raw" (it : @bench.T) {
  cl_local_projection_review_bench(it, 256, false, false, false)
}

///|
test "bench coalesce path sparse 256 indexed" (it : @bench.T) {
  cl_local_projection_review_bench(it, 256, false, false, true)
}

///|
test "bench coalesce path sparse 512 raw" (it : @bench.T) {
  cl_local_projection_review_bench(it, 512, false, false, false)
}

///|
test "bench coalesce path sparse 512 indexed" (it : @bench.T) {
  cl_local_projection_review_bench(it, 512, false, false, true)
}

///|
test "bench coalesce path dense 64 raw" (it : @bench.T) {
  cl_local_projection_review_bench(it, 64, true, false, false)
}

///|
test "bench coalesce path dense 64 indexed" (it : @bench.T) {
  cl_local_projection_review_bench(it, 64, true, false, true)
}

///|
test "bench coalesce path dense 128 raw" (it : @bench.T) {
  cl_local_projection_review_bench(it, 128, true, false, false)
}

///|
test "bench coalesce path dense 128 indexed" (it : @bench.T) {
  cl_local_projection_review_bench(it, 128, true, false, true)
}
