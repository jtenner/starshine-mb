///|
fn dead_code_elimination_label_targets_test_ctx() -> HotPassContext {
  HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
}

///|
test "dead-code-elimination keeps block targeted only by try_table catch" {
  let source =
    #|(module
    #|  (import "env" "side" (func $side))
    #|  (tag $e)
    #|  (func
    #|    block $handler
    #|      call $side
    #|      try_table (catch_all $handler)
    #|        call $side
    #|      end
    #|      call $side
    #|    end))
  let fixture = @ir.ir_test_build_hot_from_wat(source)
  let func = fixture.hot_func
  let block_id = @ir.hot_root_get(func, 0)
  assert_true(@ir.hot_node_get(func, block_id).op is @ir.HotOp::Block)

  ignore(
    dead_code_elimination_run(
      dead_code_elimination_label_targets_test_ctx(),
      func,
    ),
  )

  assert_true(
    @ir.hot_node_is_live(func, block_id),
    msg="try_table catch target owner must remain live",
  )
  assert_eq(@ir.hot_root_count(func), 1)
  assert_eq(@ir.hot_root_get(func, 0), block_id)
  let optimized = @ir.ir_test_assert_verify_and_lower(fixture)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("block"), msg=pretty)
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("catch_all"), msg=pretty)
}

///|
fn dead_code_elimination_continuation_target_input() -> @lib.Module {
  let input = pass_test_module_from_wat(
    "(module (type $s (func)) (type $c (func)) (tag $e) (func (param (ref $c))))",
  )
  let types = input.type_sec.unwrap().0.copy()
  types[1] = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(0U))),
  )
  let cont = @lib.TypeIdx::new(1U)
  let ref_ = @lib.ValType::ref_null(@lib.HeapType::new(cont))
  let block = @lib.Instruction::block(
    @lib.BlockType::val_type(ref_),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::resume_(cont, [
        @lib.ResumeHandler::on_label(
          @lib.TagIdx::new(0U),
          @lib.LabelIdx::new(0U),
        ),
      ]),
      @lib.Instruction::unreachable_(),
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
    Err(err) => abort("invalid continuation target fixture: \{err}")
  }
}

///|
test "dead-code-elimination keeps block targeted only by continuation handler" {
  let input = dead_code_elimination_continuation_target_input()
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let drop_id = @ir.hot_root_get(func, 0)
  let block_id = @ir.hot_child_get(func, drop_id, 0)
  assert_true(@ir.hot_node_get(func, block_id).op is @ir.HotOp::Block)

  ignore(
    dead_code_elimination_run(
      dead_code_elimination_label_targets_test_ctx(),
      func,
    ),
  )

  assert_true(
    @ir.hot_node_is_live(func, block_id),
    msg="continuation handler target owner must remain live",
  )
  assert_eq(@ir.hot_node_result_arity(func, block_id), 1)
  assert_eq(@ir.hot_root_count(func), 1)
  assert_eq(@ir.hot_root_get(func, 0), drop_id)
  let lowered = @ir.hot_lower_func(func)
  let optimized = input.with_code_sec(@lib.CodeSec::new([lowered]))
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected valid continuation target output, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("block"), msg=pretty)
  assert_true(pretty.contains("resume"), msg=pretty)
}

///|
test "BURN-009 DCE retains mixed ordinary and continuation incoming results" {
  let input = dead_code_elimination_continuation_target_input()
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let dropped = @ir.hot_root_get(func, 0)
  let target = @ir.hot_child_get(func, dropped, 0)
  let body = @ir.hot_region_body_ref(func, target)
  let resume_id = @ir.hot_region_get(func, body, 0)
  let terminal = @ir.hot_region_get(func, body, 1)
  let branch = @ir.hot_build_br(
    func,
    @ir.hot_control_node_label(func, target),
    values=[
      @ir.hot_build_ref_null(
        func,
        @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
      ),
    ],
  )
  let conditional = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [branch],
  )
  @ir.hot_region_replace_body(func, body, [conditional, resume_id, terminal])
  let before = input.with_code_sec(
    @lib.CodeSec::new([@ir.hot_lower_func(func)]),
  )
  match @validate.validate_module(before) {
    Ok(_) => ()
    Err(err) => fail("mixed continuation input invalid: \{err}")
  }
  ignore(
    pipeline_verify_checkpoint(
      HotPipelineVerifyPolicy::after_each_pass(),
      "before",
      HotPipelineVerifyTarget::HotFuncTarget(func),
    ).unwrap(),
  )
  let ctx = dead_code_elimination_label_targets_test_ctx()
  ignore(hot_pass_run(ctx, func).unwrap())
  let after = input.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)]))
  match @validate.validate_module(after) {
    Ok(_) => ()
    Err(err) => fail("mixed continuation output invalid: \{err}")
  }
  assert_eq(@ir.hot_node_result_arity(func, target), 1)
  assert_eq(@ir.hot_child_count(func, branch), 1)
}
