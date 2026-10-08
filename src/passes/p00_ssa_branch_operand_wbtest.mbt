///|
fn p00_ssa_branch_operand_fixture() -> (@ir.HotFunc, Int, Int, Int, Int, Int) {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let initial_set = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  let independent_set = @ir.hot_build_local_set(
    func,
    2,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
  )
  let block = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let label = @ir.hot_control_node_label(func, block)
  let first_branch = @ir.hot_build_br_if(
    func,
    label,
    @ir.hot_build_local_get(func, 0),
  )
  let branch_tee = @ir.hot_build_local_tee(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  let second_branch = @ir.hot_build_br_if(func, label, branch_tee)
  let fallthrough_set = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(5)),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block), [
    first_branch, second_branch, fallthrough_set,
  ])
  let independent_get = @ir.hot_build_local_get(func, 2)
  let merge_get = @ir.hot_build_local_get(func, 1)
  for
    root in [
      initial_set,
      independent_set,
      block,
      @ir.hot_build_drop(func, independent_get),
      merge_get,
    ] {
    @ir.hot_root_append(func, root)
  }
  @ir.hot_verify_all_or_abort(func)
  (func, branch_tee, second_branch, merge_get, independent_set, independent_get)
}

///|
test "SSA no-merge preserves a body-local branch operand tee that feeds a merge" {
  let (
    func,
    branch_tee,
    second_branch,
    merge_get,
    independent_set,
    independent_get,
  ) = p00_ssa_branch_operand_fixture()
  let ctx = HotPassContext::new(
    ssa_nomerge_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  ignore(hot_pass_run(ctx, func).unwrap())
  @ir.hot_verify_all_or_abort(func)

  // The tee runs inside the branch condition. A phi copy before this branch
  // cannot read its fresh SSA local: that local has not been written yet.
  // Keep this merge input in the merge local. The two exits then return 3 and 1.
  assert_true(@ir.hot_node_get(func, branch_tee).op is @ir.HotOp::LocalTee)
  assert_eq(@ir.hot_child_get(func, second_branch, 0), branch_tee)
  assert_eq(@ir.hot_node_get(func, branch_tee).imm0, 1)
  assert_eq(@ir.hot_node_get(func, merge_get).imm0, 1)

  // An affected merge local must not prevent work on independent locals.
  let independent_local = @ir.hot_node_get(func, independent_set).imm0
  assert_true(@ir.hot_node_get(func, independent_set).op is @ir.HotOp::LocalSet)
  assert_true(independent_local != 2)
  assert_eq(@ir.hot_node_get(func, independent_get).imm0, independent_local)

  let module = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32) i32.const 0))",
  )
  let output = module.with_code_sec(
    @lib.CodeSec::new([@ir.hot_lower_func(func)]),
  )
  assert_true(@validate.validate_module(output).is_ok())
}
