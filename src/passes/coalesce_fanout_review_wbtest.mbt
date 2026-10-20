///|
fn cl_fanout_reference(
  instrs : Array[@lib.Instruction],
  types : Array[@lib.ValType],
  param_count : Int32,
  interferences : CLBitMatrix,
) -> Unit {
  let gets = Array::make(types.length(), 0)
  let sets = Array::make(types.length(), 0)
  let tees = Array::make(types.length(), 0)
  cl_count_syntactic_local_accesses(instrs, gets, sets, tees)
  for source = param_count; source < types.length(); source = source + 1 {
    let destinations : Array[Int32] = []
    for idx = 0; idx + 1 < instrs.length(); idx = idx + 1 {
      match (instrs[idx], instrs[idx + 1]) {
        (@lib.LocalGet(source_idx), @lib.LocalSet(dest_idx)) => {
          if cl_local_idx_raw(source_idx) != source {
            continue
          }
          let dest = cl_local_idx_raw(dest_idx)
          if dest < param_count ||
            dest >= types.length() ||
            dest == source ||
            types[dest] != types[source] ||
            sets[dest] != 1 ||
            tees[dest] != 0 ||
            cl_instrs_suffix_writes_local(instrs, idx + 2, source) {
            continue
          }
          let mut accessed_before_copy = false
          for before = 0; before < idx; before = before + 1 {
            if cl_instr_tree_accesses_local(instrs[before], dest) {
              accessed_before_copy = true
            }
          }
          if !accessed_before_copy {
            destinations.push(dest)
          }
        }
        _ => ()
      }
    }
    if destinations.length() < 2 {
      continue
    }
    for dest in destinations {
      cl_bit_matrix_set_symmetric(interferences, source, dest, false)
    }
    for lhs = 0; lhs < destinations.length(); lhs = lhs + 1 {
      for rhs = lhs + 1; rhs < destinations.length(); rhs = rhs + 1 {
        let left = destinations[lhs]
        let right = destinations[rhs]
        cl_bit_matrix_set_symmetric(interferences, left, right, false)
      }
    }
  }
}

///|
fn cl_fanout_review_fixture(groups : Int32) -> Array[@lib.Instruction] {
  let body : Array[@lib.Instruction] = []
  for group in 0..<groups {
    let source = group * 3
    body.push(@lib.Instruction::i32_const(@lib.I32(source)))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(source.to_uint())))
    for dest in [source + 1, source + 2] {
      body.push(
        @lib.Instruction::local_get(@lib.LocalIdx::new(source.to_uint())),
      )
      body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(dest.to_uint())))
    }
  }
  body
}

///|
test "coalesce fanout relation preserves prefix reads and nested source writes" {
  for variant in 0..<4 {
    let body = cl_fanout_review_fixture(8)
    if variant == 1 {
      body.insert(0, @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
      body.insert(1, @lib.Instruction::drop())
    }
    if variant == 2 || variant == 3 {
      let write = @lib.Instruction::local_set(@lib.LocalIdx::new(0U))
      let nested = if variant == 2 {
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7)), write]),
        )
      } else {
        @lib.Instruction::try_(@lib.BlockType::void_(), @lib.Expr::new([]), [
          @lib.LegacyCatch::all(
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7)), write]),
          ),
        ])
      }
      body.push(nested)
    }
    let expected = CLBitMatrix::new(24)
    let actual = CLBitMatrix::new(24)
    expected.bits.fill(true)
    actual.bits.fill(true)
    let types = Array::make(24, @lib.ValType::i32())
    cl_fanout_reference(body, types, 0, expected)
    cl_remove_same_source_fanout_interferences(body, types, 0, actual)
    assert_eq(actual.bits, expected.bits)
    assert_false(cl_bit_matrix_get(actual, 3, 4))
    assert_eq(cl_bit_matrix_get(actual, 0, 1), variant != 0)
  }
}

///|
fn cl_fanout_review_bench(
  it : @bench.T,
  groups : Int32,
  reference : Bool,
) -> Unit {
  let body = cl_fanout_review_fixture(groups)
  let types = Array::make(groups * 3, @lib.ValType::i32())
  let expected = CLBitMatrix::new(types.length())
  let actual = CLBitMatrix::new(types.length())
  expected.bits.fill(true)
  actual.bits.fill(true)
  cl_fanout_reference(body, types, 0, expected)
  cl_remove_same_source_fanout_interferences(body, types, 0, actual)
  if actual.bits != expected.bits {
    abort("fanout relations changed")
  }
  it.bench(fn() {
    let matrix = CLBitMatrix::new(types.length())
    matrix.bits.fill(true)
    if reference {
      cl_fanout_reference(body, types, 0, matrix)
    } else {
      cl_remove_same_source_fanout_interferences(body, types, 0, matrix)
    }
    it.keep(matrix)
  })
}

///|
test "bench coalesce fanout repeated scans 8" (it : @bench.T) {
  cl_fanout_review_bench(it, 8, true)
}

///|
test "bench coalesce fanout indexed scans 8" (it : @bench.T) {
  cl_fanout_review_bench(it, 8, false)
}

///|
test "bench coalesce fanout repeated scans 256" (it : @bench.T) {
  cl_fanout_review_bench(it, 256, true)
}

///|
test "bench coalesce fanout indexed scans 256" (it : @bench.T) {
  cl_fanout_review_bench(it, 256, false)
}
