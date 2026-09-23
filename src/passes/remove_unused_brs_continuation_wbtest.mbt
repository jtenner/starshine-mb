///|
fn remove_unused_brs_continuation_test_input() -> @lib.Module {
  let input = pass_test_module_from_wat(
    "(module (type $s (func)) (type $c (func)) (tag $e) (func (param (ref $c))))",
  )
  let types = input.type_sec.unwrap().0.copy()
  types[1] = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(0U))),
  )
  let cont = @lib.TypeIdx::new(1U)
  let cont_ref = @lib.ValType::ref_null(@lib.HeapType::new(cont))
  let block = @lib.Instruction::block(
    @lib.BlockType::val_type(cont_ref),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::resume_(cont, [
        @lib.ResumeHandler::on_label(
          @lib.TagIdx::new(0U),
          @lib.LabelIdx::new(0U),
        ),
      ]),
      @lib.Instruction::ref_null(
        @lib.HeapType::abs(@lib.AbsHeapType::no_cont()),
      ),
    ]),
  )
  let input = input
    .with_type_sec(@lib.TypeSec::new(types))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([block, @lib.Instruction::drop()]),
        ),
      ]),
    )
  match @validate.validate_module(input) {
    Ok(_) => input
    Err(err) => abort("invalid RUB continuation target fixture: \{err}")
  }
}

///|
test "remove-unused-brs preserves continuation handler result type" {
  let input = remove_unused_brs_continuation_test_input()
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let drop_id = @ir.hot_root_get(func, 0)
  let block_id = @ir.hot_child_get(func, drop_id, 0)
  assert_true(@ir.hot_node_get(func, block_id).op is @ir.HotOp::Block)
  assert_eq(@ir.hot_type_results(func, @ir.hot_node_type(func, block_id)), [
    @lib.ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(1U))),
  ])

  ignore(remove_unused_brs_run(remove_unused_brs_wbtest_ctx(), func))

  assert_true(
    @ir.hot_node_is_live(func, block_id),
    msg="continuation handler target owner must remain live",
  )
  assert_eq(@ir.hot_type_results(func, @ir.hot_node_type(func, block_id)), [
    @lib.ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(1U))),
  ])
  let lowered = @ir.hot_lower_func(func)
  let optimized = input.with_code_sec(@lib.CodeSec::new([lowered]))
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected valid RUB continuation output, got \{err}")
  }
}
