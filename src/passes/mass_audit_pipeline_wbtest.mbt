///|
// The parent runs these tests after all eight audit agents finish.
test "mass pipeline audit heap2local keeps a shared allocation after null folding" {
  let heap_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
  let function_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let module_ = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([heap_type, function_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::struct_new_default(@lib.TypeIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::struct_new_default(@lib.TypeIdx::new(0U)),
            @lib.Instruction::ref_is_null(),
          ]),
        ),
      ]),
    )
  @validate.validate_module(module_).unwrap()
  let func = @ir.hot_lift_func(module_, @lib.FuncIdx::new(0U))
  assert_eq(@ir.hot_root_count(func), 2)
  let drop = @ir.hot_root_get(func, 0)
  let predicate = @ir.hot_root_get(func, 1)
  let shared = @ir.hot_child_get(func, drop, 0)
  let unused = @ir.hot_child_get(func, predicate, 0)
  @ir.hot_child_set(func, predicate, 0, shared)
  @ir.hot_delete_node(func, unused)
  @ir.hot_verify_core(func).unwrap()
  @ir.hot_verify_control(func).unwrap()
  let ctx = HotPassContext::new(
    heap2local_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(module_)),
  )
  let _ = heap2local_run(ctx, func)
  assert_true(@ir.hot_node_is_live(func, shared))
  assert_eq(@ir.hot_child_get(func, drop, 0), shared)
  let folded = @ir.hot_node_get(func, predicate)
  assert_true(folded.op is @ir.HotOp::Const)
  assert_eq(
    @ir.hot_const_get(func, folded.imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
  @ir.hot_verify_core(func).unwrap()
  @ir.hot_verify_control(func).unwrap()
  @validate.validate_module(
    module_.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)])),
  ).unwrap()
}

///|
// The parent runs these tests after all eight audit agents finish.
test "mass pipeline audit heap store flattens a self-targeting inner block" {
  let module_ = pass_test_module_from_wat(
    "(module (func (result i32) block $outer (result i32) block $inner (result i32) i32.const 7 br $inner end end))",
  )
  @validate.validate_module(module_).unwrap()
  let func = @ir.hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let outer = @ir.hot_root_get(func, 0)
  let inner = @ir.hot_region_get(func, @ir.hot_region_body_ref(func, outer), 0)
  let branch = @ir.hot_region_get(func, @ir.hot_region_body_ref(func, inner), 0)
  assert_eq(
    @ir.hot_branch_target(func, branch),
    Some(@ir.hot_control_node_label(func, inner)),
  )
  assert_true(hso_try_flatten_block_wrapper(func, outer))
  let body = @ir.hot_region_body_ref(func, outer)
  assert_eq(@ir.hot_region_root_count(func, body), 1)
  assert_eq(@ir.hot_region_get(func, body, 0), branch)
  assert_eq(
    @ir.hot_branch_target(func, branch),
    Some(@ir.hot_control_node_label(func, outer)),
  )
  @ir.hot_verify_core(func).unwrap()
  @ir.hot_verify_control(func).unwrap()
  @validate.validate_module(
    module_.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)])),
  ).unwrap()
}
