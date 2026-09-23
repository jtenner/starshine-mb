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
