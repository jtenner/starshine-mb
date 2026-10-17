///|
test "DAE func327 remap requires a definite temp write before the read" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i64()),
      [@lib.Instruction::local_get(@lib.LocalIdx::new(25U))],
      Some([@lib.Instruction::i64_const(@lib.I64(0L))]),
    ),
  ]
  assert_false(dae_func327_can_remap_i64_temp25_to_param0(body))
}

///|
test "DAE2 recognizes shared abstract funcref tables" {
  let table_type = @lib.TableType::new(
    @lib.RefType::new(true, @lib.HeapType::shared_abs(@lib.AbsHeapType::func())),
    @lib.Limits::i32(1U, None),
  )
  assert_true(dae2_is_abstract_funcref_table(table_type))
}

///|
test "global-struct-inference poisons nested external struct origins" {
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field i32))) (type $box (struct (field (ref $s)))))",
  )
  let env = @validate.Env::new().with_module(input)
  let poisoned = Array::make(2, false)
  gsi_mark_external_struct_origins(
    env,
    @lib.ValType::ref_type(
      @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
    ),
    poisoned,
    [],
    [],
  )
  assert_true(poisoned[1], msg="the external box type must be poisoned")
  assert_true(poisoned[0], msg="the nested struct field type must be poisoned")
}

///|
test "raw optimize-instructions marks legacy try as nested control" {
  let instr = @lib.Instruction::try_(
    @lib.BlockType::void_(),
    @lib.Expr::new([]),
    [@lib.LegacyCatch::all(@lib.Expr::new([]))],
  )
  assert_true(RawOiRootFlowFact::from_instr(instr).has_nested_control)
}

///|
test "touched local-CSE keeps memory64 expression types" {
  let input = pass_test_module_from_wat(
    (
      #|(module (memory i64 1)
      #|  (func (param i32) (result i64)
      #|    (drop (select (memory.size) (memory.size) (local.get 0)))
      #|    (select (memory.size) (memory.size) (local.get 0))))
    ),
  )
  let output = run_hot_pipeline_apply_local_cse_to_touched(
    input,
    [true],
    HotPipelineOptions::new(),
  ).unwrap()
  assert_true(output != input, msg="expected touched local-CSE to rewrite")
  match @validate.validate_module(output) {
    Ok(_) => ()
    Err(err) =>
      fail("touched local-CSE produced invalid memory64 output: \{err}")
  }
}

///|
test "raw SSA consumes legacy try get decisions before following roots" {
  let func = @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::i32()]),
    @lib.Expr::new([
      @lib.Instruction::try_(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
        ]),
        [@lib.LegacyCatch::all(@lib.Expr::new([]))],
      ),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  let plan : SsaNoMergeRewritePlan = {
    write_rewrites: [],
    get_rewrites: [
      {
        get_id: 0,
        original_local: 0,
        decision: SsaNoMergeGetDecision::KeepCanonical,
      },
      {
        get_id: 1,
        original_local: 0,
        decision: SsaNoMergeGetDecision::MaterializeDefault,
      },
    ],
  }
  let (rewritten, changed) = run_hot_pipeline_raw_ssa_nomerge_planned_structured(
    func,
    [],
    plan,
  )
  assert_true(changed)
  let @lib.Func(_, @lib.Expr(body)) = rewritten
  assert_eq(body[1], @lib.Instruction::i32_const(@lib.I32(0)))
}

///|
test "precompute exact-cast refinalization sees continuation handler targets" {
  let input = pass_test_module_from_wat(
    "(module (type $s (func)) (type $c (func)) (tag $e) (func (param (ref $c))))",
  )
  let types = input.type_sec.unwrap().0.copy()
  types[1] = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(0U))),
  )
  let cont = @lib.TypeIdx::new(1U)
  let heap = @lib.HeapType::new(cont)
  let ref_ = @lib.ValType::ref_type(@lib.RefType::new(true, heap))
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(ref_),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::val_type(ref_),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::resume_(cont, [
              @lib.ResumeHandler::on_label(
                @lib.TagIdx::new(0U),
                @lib.LabelIdx::new(1U),
              ),
            ]),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::br_on_cast(
          @lib.LabelIdx::new(0U),
          true,
          heap,
          true,
          heap,
          source_exact=false,
          target_exact=true,
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::unreachable_(),
      ]),
    ),
    @lib.Instruction::drop(),
  ])
  let input = input
    .with_type_sec(@lib.TypeSec::new(types))
    .with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(@lib.Locals::empty(), body)]),
    )
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("invalid precompute continuation fixture: \{err}")
  }
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let drop_id = @ir.hot_root_get(func, 0)
  let block_id = @ir.hot_child_get(func, drop_id, 0)
  let ctx = HotPassContext::new(
    precompute_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(input)),
  )
  assert_false(precompute_try_refinalize_exact_cast_block(ctx, func, block_id))
  match @ir.hot_type_results(func, @ir.hot_node_type(func, block_id)) {
    [@lib.RefTypeValType(result)] => assert_false(result.is_exact())
    results => fail("expected one reference block result, got \{results}")
  }
}
