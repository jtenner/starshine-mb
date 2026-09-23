///|
test "descriptor branches retain their owner during raw block cleanup" {
  let ref_ = @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U)))
  for
    branch in [
      @lib.Instruction::br_on_cast_desc_eq(@lib.LabelIdx::new(0U), ref_, ref_),
      @lib.Instruction::br_on_cast_desc_eq_fail(
        @lib.LabelIdx::new(0U),
        ref_,
        ref_,
      ),
    ] {
    let body = [branch]
    assert_true(pass_raw_instr_is_branch_control(branch))
    assert_true(run_hot_pipeline_raw_instrs_have_branch(body))
    assert_true(run_hot_pipeline_dae_copy_retarget_is_control_boundary(branch))
    assert_false(
      o4z_canonicalize_final_size_local_tee_is_dead_before_read(
        [branch, @lib.Instruction::local_set(@lib.LocalIdx::new(0U))],
        0,
        @lib.LocalIdx::new(0U),
      ),
    )
    assert_true(run_hot_pipeline_raw_vacuum_body_targets_owner(body, 0))
    let input = [
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::ref_type(ref_)),
        @lib.Expr::new(body),
      ),
    ]
    let (output, changed) = run_hot_pipeline_raw_vacuum_flatten_unbranched_result_blocks(
      input, false, false,
    )
    assert_false(changed)
    @debug.assert_eq(output, input)
  }
}

///|
test "descriptor branches terminate straight-line local ownership proofs" {
  let ref_ = @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U)))
  for
    branch in [
      @lib.Instruction::br_on_cast_desc_eq(@lib.LabelIdx::new(0U), ref_, ref_),
      @lib.Instruction::br_on_cast_desc_eq_fail(
        @lib.LabelIdx::new(0U),
        ref_,
        ref_,
      ),
    ] {
    // These raw specializations require straight-line control. The complete
    // HOT pass remains responsible for optimizing a descriptor branch.
    assert_false(
      run_hot_pipeline_raw_ssa_nomerge_ordinary_set_supported_control([branch]),
    )
    assert_false(
      run_hot_pipeline_raw_ssa_nomerge_multisource_merge_supported_control([
        branch,
      ]),
    )
    assert_false(
      run_hot_pipeline_raw_ssa_nomerge_loop_backedge_decoration_supported_control([
          branch,
        ],
      ),
    )
    assert_false(
      run_hot_pipeline_raw_ssa_nomerge_default_materialize_supported_control([
        branch,
      ]),
    )
    assert_true(run_hot_pipeline_raw_ssa_nomerge_has_non_plain_branch([branch]))
    assert_true(
      RawOiRootFlowFact::from_instr(branch).blocks_branch_free_value_region(),
    )
    assert_true(run_hot_pipeline_raw_optimize_casts_has_candidate([branch]))
    assert_false(
      run_hot_pipeline_raw_instrs_current_loop_backedges_are_plain_br(
        [branch],
        0U,
      ),
    )
    @debug.assert_eq(
      run_hot_pipeline_raw_ssa_nomerge_branch_free_value_block_tee_local([
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        branch,
      ]),
      None,
    )
    assert_eq(
      o4z_canonicalize_final_size_first_local_access(
        [branch, @lib.Instruction::local_set(@lib.LocalIdx::new(0U))],
        @lib.LocalIdx::new(0U),
      ),
      1,
    )
  }
}

///|
test "descriptor branches rebase outer targets when an unused wrapper disappears" {
  let ref_ = @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U)))
  for fail_branch in [false, true] {
    let branch = fn(depth : UInt) {
      if fail_branch {
        @lib.Instruction::br_on_cast_desc_eq_fail(
          @lib.LabelIdx::new(depth),
          ref_,
          ref_,
        )
      } else {
        @lib.Instruction::br_on_cast_desc_eq(
          @lib.LabelIdx::new(depth),
          ref_,
          ref_,
        )
      }
    }
    let body = [
      branch(1U),
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([branch(2U), branch(0U)]),
      ),
    ]
    let rebased = run_hot_pipeline_raw_vacuum_rebase_outer_body(body, 0)
    @debug.assert_eq(rebased, [
      branch(0U),
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([branch(1U), branch(0U)]),
      ),
    ])
  }
}

///|
test "vacuum block flattening retains and rebases continuation handler labels" {
  let type_idx = @lib.TypeIdx::new(0U)
  let tag_idx = @lib.TagIdx::new(0U)
  let owner_handlers = [
    @lib.ResumeHandler::on_label(tag_idx, @lib.LabelIdx::new(0U)),
  ]
  let outer_handlers = [
    @lib.ResumeHandler::on_label(tag_idx, @lib.LabelIdx::new(1U)),
  ]
  for
    case in [
      (
        @lib.Instruction::resume_(type_idx, owner_handlers),
        @lib.Instruction::resume_(type_idx, outer_handlers),
        @lib.Instruction::resume_(type_idx, owner_handlers),
      ),
      (
        @lib.Instruction::resume_throw(type_idx, tag_idx, owner_handlers),
        @lib.Instruction::resume_throw(type_idx, tag_idx, outer_handlers),
        @lib.Instruction::resume_throw(type_idx, tag_idx, owner_handlers),
      ),
      (
        @lib.Instruction::resume_throw_ref(type_idx, owner_handlers),
        @lib.Instruction::resume_throw_ref(type_idx, outer_handlers),
        @lib.Instruction::resume_throw_ref(type_idx, owner_handlers),
      ),
    ] {
    let (owner_resume, outer_resume, expected_rebased) = case
    let owner_body = [owner_resume]
    assert_true(run_hot_pipeline_raw_vacuum_body_targets_owner(owner_body, 0))
    let input = [
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new(owner_body),
      ),
    ]
    let (output, changed) = run_hot_pipeline_raw_vacuum_flatten_unbranched_result_blocks(
      input, false, false,
    )
    assert_false(changed)
    @debug.assert_eq(output, input)
    @debug.assert_eq(
      run_hot_pipeline_raw_vacuum_rebase_outer_body([outer_resume], 0),
      [expected_rebased],
    )
  }
}
