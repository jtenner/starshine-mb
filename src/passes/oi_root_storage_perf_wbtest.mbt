///|
// Both paths construct and consume every root, retaining identical classifiers.
fn oi_root_storage_bench(
  it : @bench.T,
  width : Int,
  mixed : Bool,
  before : Bool,
) -> Unit raise {
  let body = Array::make(
    width,
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
  if mixed {
    for index in 0..<width {
      if index % 4 == 1 {
        body[index] = @lib.Instruction::call(@lib.FuncIdx::new(0U))
      }
      if index % 4 == 2 {
        body[index] = @lib.Instruction::unreachable_()
      }
      if index % 4 == 3 {
        body[index] = @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([]),
        )
      }
    }
  }
  let expected = body.mapi(fn(position, instr) {
    OiBoxedRootStorageReference::from_instr(position, instr)
  })
  let actual = RawOiInstructionRegionFact::from_instrs(body)
  for index in 0..<width {
    assert_eq(actual.roots[index].position, expected[index].position)
    assert_true(
      physical_equal(actual.roots[index].instr, expected[index].instr),
    )
    assert_true(
      RawOiFunctionRevisionFactIndex::root_kind_matches(
        actual.roots[index].kind,
        expected[index].kind,
      ),
    )
    assert_eq(
      actual.roots[index].flow.blocks_branch_free_value_region(),
      expected[index].flow.blocks_branch_free_value_region(),
    )
  }
  it.bench(fn() {
    let mut sum = 0
    if before {
      let region = OiBoxedRegionStorageReference::from_instrs(body)
      for root in region.roots {
        if root.flow.blocks_branch_free_value_region() {
          sum += root.position
        }
      }
      it.keep(region)
    } else {
      let region = RawOiInstructionRegionFact::from_instrs(body)
      for root in region.roots {
        if root.flow.blocks_branch_free_value_region() {
          sum += root.position
        }
      }
      it.keep(region)
    }
    it.keep(sum)
  })
}

///|
test "bench OI root storage width=4 flat before" (it : @bench.T) {
  oi_root_storage_bench(it, 4, false, true)
}

///|
test "bench OI root storage width=4 flat current" (it : @bench.T) {
  oi_root_storage_bench(it, 4, false, false)
}

///|
test "bench OI root storage width=4 mixed before" (it : @bench.T) {
  oi_root_storage_bench(it, 4, true, true)
}

///|
test "bench OI root storage width=4 mixed current" (it : @bench.T) {
  oi_root_storage_bench(it, 4, true, false)
}

///|
test "bench OI root storage width=128 flat before" (it : @bench.T) {
  oi_root_storage_bench(it, 128, false, true)
}

///|
test "bench OI root storage width=128 flat current" (it : @bench.T) {
  oi_root_storage_bench(it, 128, false, false)
}

///|
test "bench OI root storage width=128 mixed before" (it : @bench.T) {
  oi_root_storage_bench(it, 128, true, true)
}

///|
test "bench OI root storage width=128 mixed current" (it : @bench.T) {
  oi_root_storage_bench(it, 128, true, false)
}
