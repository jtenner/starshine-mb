///|
fn cl_path_scan_value_fields(
  scan : CLPathDisjointScan,
) -> (Bool, Bool, Bool, Bool, Bool) {
  (
    scan.ok,
    scan.saw_source_write,
    scan.source_initialized,
    scan.source_clobbers_dest,
    scan.dest_clobbers_source,
  )
}

///|
test "path-disjoint result keeps all incoming facts and retained scan fields" {
  for initialized in [false, true] {
    for source_clobbers in [false, true] {
      for dest_clobbers in [false, true] {
        let held = cl_scan_path_disjoint_branch_result_instrs(
          [],
          1,
          0,
          initialized,
          source_clobbers,
          dest_clobbers,
        )
        let failed = cl_scan_path_disjoint_branch_result_instrs(
          [@lib.Instruction::return_()],
          1,
          0,
          false,
          false,
          false,
        )
        assert_eq(
          cl_path_scan_value_fields(failed),
          (false, false, false, false, false),
        )
        assert_eq(
          cl_path_scan_value_fields(held),
          (true, false, initialized, source_clobbers, dest_clobbers),
        )
      }
    }
  }
}

///|
test "path-disjoint result distinguishes one-arm and two-arm initialization" {
  let write = [
    @lib.Instruction::i32_const(@lib.I32::new(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let two_arms = [
    @lib.Instruction::if_(@lib.BlockType::void_(), write, Some(write)),
  ]
  let one_arm = [@lib.Instruction::if_(@lib.BlockType::void_(), write, None)]
  let both = cl_scan_path_disjoint_branch_result_instrs(
    two_arms, 1, 0, false, false, false,
  )
  let one = cl_scan_path_disjoint_branch_result_instrs(
    one_arm, 1, 0, false, false, false,
  )
  assert_eq(cl_path_scan_value_fields(both), (true, true, true, true, false))
  assert_eq(cl_path_scan_value_fields(one), (true, true, false, true, false))
  two_arms.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  one_arm.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  assert_true(
    cl_scan_path_disjoint_branch_result_instrs(
      two_arms, 1, 0, false, false, false,
    ).ok,
  )
  assert_false(
    cl_scan_path_disjoint_branch_result_instrs(
      one_arm, 1, 0, false, false, false,
    ).ok,
  )
}

///|
test "path-disjoint result preserves copy and clobber decisions through nested blocks" {
  let copy = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ]
  let body = [
    @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(copy)),
  ]
  assert_eq(
    cl_path_scan_value_fields(
      cl_scan_path_disjoint_branch_result_instrs(
        body, 1, 0, false, false, false,
      ),
    ),
    (true, true, true, false, false),
  )
  let clobber = [
    @lib.Instruction::i32_const(@lib.I32::new(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ]
  assert_false(
    cl_scan_path_disjoint_branch_result_instrs(
      clobber, 1, 0, false, false, false,
    ).ok,
  )
  let dest_clobber = [
    @lib.Instruction::i32_const(@lib.I32::new(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ]
  assert_false(
    cl_scan_path_disjoint_branch_result_instrs(
      dest_clobber, 1, 0, true, false, false,
    ).ok,
  )
}

///|
test "path-disjoint scan intentionally rejects unsupported escaping and loop control" {
  for
    instr in [
      @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
      @lib.Instruction::return_(),
      @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new([])),
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [],
        @lib.Expr::new([]),
      ),
    ] {
    assert_eq(
      cl_path_scan_value_fields(
        cl_scan_path_disjoint_branch_result_instrs(
          [instr],
          1,
          0,
          true,
          true,
          true,
        ),
      ),
      (false, false, false, false, false),
    )
  }
}
