///|
test "coalesce transitive copy proofs retain their nested region scope" {
  let local = fn(i : Int32) { @lib.LocalIdx::new(i.to_uint()) }
  let nested = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(local(0)),
    @lib.Instruction::local_get(local(0)),
    @lib.Instruction::local_set(local(1)),
    @lib.Instruction::local_get(local(1)),
    @lib.Instruction::local_set(local(2)),
  ]
  let body = [
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::local_set(local(1)),
    @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(nested)),
  ]
  assert_true(cl_copy_forward_pair_safe(body, 0, 2))
  let facts = cl_copy_forward_facts(body, 3)
  facts.epoch += 1
  assert_true(facts.pair_safe(0, 2, 4))
}

///|
test "coalesce consume copy propagation keeps the original five-edge limit" {
  for shape in 0..<8 {
    let weights = CLCopyWeights::new(9)
    for local in 0..<8 {
      cl_copy_weight_add(weights, local, local + 1, 1)
    }
    if shape % 2 != 0 {
      cl_copy_weight_add(weights, 0, 4, 1)
    }
    if shape / 2 % 2 != 0 {
      cl_copy_weight_add(weights, 1, 7, 1)
    }
    if shape / 4 % 2 != 0 {
      cl_copy_weight_add(weights, 3, 8, 1)
    }
    for source in 0..<9 {
      let (reachable, _) = cl_copy_weight_reachable_destinations(
        weights, source, 5,
      )
      for dest in 0..<9 {
        if source != dest {
          assert_eq(
            reachable[dest],
            cl_copy_weight_reaches(weights, source, dest, 4),
          )
        }
      }
    }
  }
}

///|
fn cl_copy_forward_review_reference(
  instrs : Array[@lib.Instruction],
  types : Array[@lib.ValType],
  param_count : Int32,
  interferences : CLBitMatrix,
  weights : CLCopyWeights,
) -> Unit {
  // Every pair scan rejects these barriers unconditionally, including inside
  // both Block/If arms. Prove that once before repeating the same failed walk.
  // Barrier-free candidates still use the complete original pair proof.
  let mut checked_barriers = false
  for source = param_count; source < types.length(); source = source + 1 {
    if weights.rows[source].length() == 0 {
      continue
    }
    if !checked_barriers {
      if cl_pair_forward_scans_have_global_barrier(instrs) {
        return
      }
      checked_barriers = true
    }
    let (reachable, _) = cl_copy_weight_reachable_destinations(
      weights, source, 4,
    )
    for dest = 0; dest < types.length(); dest = dest + 1 {
      if reachable[dest] &&
        types[source] == types[dest] &&
        cl_copy_forward_pair_safe(instrs, source, dest) {
        cl_bit_matrix_set_symmetric(interferences, source, dest, false)
      }
    }
  }
}

///|
fn cl_copy_forward_review_fixture(
  width : Int32,
  dense : Bool,
) -> (Array[@lib.Instruction], Array[@lib.ValType], CLCopyWeights) {
  let total = if dense { width } else { width * 2 }
  let types = Array::make(total, @lib.ValType::i32())
  let weights = CLCopyWeights::new(total)
  let body : Array[@lib.Instruction] = []
  for source in 0..<width {
    let destinations = if dense {
      Array::makei(width, fn(i) { i })
    } else {
      [source + width]
    }
    for dest in destinations {
      if source == dest {
        continue
      }
      body.push(@lib.Instruction::i32_const(@lib.I32(source)))
      body.push(
        @lib.Instruction::local_set(@lib.LocalIdx::new(source.to_uint())),
      )
      body.push(
        @lib.Instruction::local_get(@lib.LocalIdx::new(source.to_uint())),
      )
      body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(dest.to_uint())))
      cl_copy_weight_add(weights, source, dest, 1)
    }
  }
  (body, types, weights)
}

///|
test "coalesce indexed copy proofs preserve every bounded-depth pair decision" {
  for shape in 0..<5 {
    let (base, types, _) = cl_copy_forward_review_fixture(4, false)
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
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
        ] +
        base
      _ =>
        [
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        ]
    }
    let facts = cl_copy_forward_facts(body, types.length())
    for dest in 0..<types.length() {
      facts.epoch += 1
      for source in 0..<types.length() {
        if source == dest {
          continue
        }
        for depth in 0..<5 {
          assert_eq(
            facts.pair_safe(source, dest, depth),
            cl_copy_forward_pair_safe_depth(body, source, dest, depth),
            msg="shape=\{shape} source=\{source} dest=\{dest} depth=\{depth}",
          )
        }
      }
    }
  }
}

///|
test "coalesce destination-indexed queries preserve sparse and dense interference removal" {
  for dense in [false, true] {
    let (body, types, weights) = cl_copy_forward_review_fixture(8, dense)
    for params in [0, 2] {
      let before = CLBitMatrix::new(types.length())
      let after = CLBitMatrix::new(types.length())
      before.bits.fill(true)
      after.bits.fill(true)
      cl_copy_forward_review_reference(body, types, params, before, weights)
      cl_remove_safe_copy_forward_interferences_indexed(
        body, types, params, after, weights,
      )
      assert_eq(after.bits, before.bits)
    }
  }
}

///|
fn cl_copy_forward_review_bench(
  it : @bench.T,
  width : Int32,
  dense : Bool,
  reference : Bool,
  verify_matrix~ : Bool = true,
) -> Unit {
  let (body, types, weights) = cl_copy_forward_review_fixture(width, dense)
  if verify_matrix {
    let before = CLBitMatrix::new(types.length())
    let after = CLBitMatrix::new(types.length())
    before.bits.fill(true)
    after.bits.fill(true)
    cl_copy_forward_review_reference(body, types, 0, before, weights)
    cl_remove_safe_copy_forward_interferences_indexed(
      body, types, 0, after, weights,
    )
    if before.bits != after.bits {
      abort("copy-forward interference relations changed")
    }
  }
  it.bench(fn() {
    let matrix = CLBitMatrix::new(types.length())
    matrix.bits.fill(true)
    if reference {
      cl_copy_forward_review_reference(body, types, 0, matrix, weights)
    } else {
      cl_remove_safe_copy_forward_interferences_indexed(
        body, types, 0, matrix, weights,
      )
    }
    it.keep(matrix)
  })
}

///|
test "bench coalesce copy proof sparse scans 256" (it : @bench.T) {
  cl_copy_forward_review_bench(it, 256, false, true)
}

///|
test "bench coalesce copy proof sparse indexed 256" (it : @bench.T) {
  cl_copy_forward_review_bench(it, 256, false, false)
}

///|
test "bench coalesce copy proof sparse scans 512" (it : @bench.T) {
  cl_copy_forward_review_bench(it, 512, false, true)
}

///|
test "bench coalesce copy proof sparse indexed 512" (it : @bench.T) {
  cl_copy_forward_review_bench(it, 512, false, false)
}

///|
test "bench coalesce copy proof sparse scans 1024" (it : @bench.T) {
  cl_copy_forward_review_bench(it, 1024, false, true)
}

///|
test "bench coalesce copy proof sparse indexed 1024" (it : @bench.T) {
  cl_copy_forward_review_bench(it, 1024, false, false)
}

///|
test "bench coalesce copy proof dense scans 32" (it : @bench.T) {
  cl_copy_forward_review_bench(it, 32, true, true)
}

///|
test "bench coalesce copy proof dense indexed 32" (it : @bench.T) {
  cl_copy_forward_review_bench(it, 32, true, false)
}

///|
test "bench coalesce copy proof dense scans 64" (it : @bench.T) {
  cl_copy_forward_review_bench(it, 64, true, true)
}

///|
test "bench coalesce copy proof dense indexed 64" (it : @bench.T) {
  cl_copy_forward_review_bench(it, 64, true, false)
}

///|
test "bench coalesce copy proof dense scans 128" (it : @bench.T) {
  cl_copy_forward_review_bench(it, 128, true, true)
}

///|
test "bench coalesce copy proof dense indexed 128" (it : @bench.T) {
  cl_copy_forward_review_bench(it, 128, true, false)
}
