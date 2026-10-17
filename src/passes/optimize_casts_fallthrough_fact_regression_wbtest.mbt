///|
fn oc_fallthrough_fact_cast() -> Array[@lib.Instruction] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
    @lib.Instruction::drop(),
  ]
}

///|
fn oc_fallthrough_fact_if(
  then_body : Array[@lib.Instruction],
  else_body : Array[@lib.Instruction],
) -> Array[@lib.Instruction] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::if_(@lib.BlockType::void_(), then_body, Some(else_body)),
  ]
}

///|
fn oc_fallthrough_fact_run(body : Array[@lib.Instruction]) -> @ir.HotFunc {
  let base = pass_test_module_from_wat(
    "(module (type $s (struct)) (tag $e) (global (mut i32) (i32.const 0)) (func (param (ref null struct) i32 (ref null struct))))",
  )
  let input = base.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    ]),
  )
  ignore(@validate.validate_module(input).unwrap())
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-casts",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(0U))
  @ir.hot_verify_core(hot).unwrap()
  @ir.hot_verify_control(hot).unwrap()
  hot
}

///|
fn oc_fallthrough_fact_count_casts(hot : @ir.HotFunc) -> Int32 {
  let mut count = 0
  for node in 0..<@ir.hot_node_count(hot) {
    if !@ir.hot_node_is_live(hot, node) {
      continue
    }
    match @ir.hot_node_exact_instr(hot, node) {
      Some(@lib.RefCast(_, _, _)) => count += 1
      _ => ()
    }
  }
  count
}

///|
test "optimize casts reuses a dominating cast after a dynamic fallthrough if" {
  let body = oc_fallthrough_fact_cast()
  body.append(
    oc_fallthrough_fact_if(
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
      ],
      [
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
      ],
    ),
  )
  body.append(oc_fallthrough_fact_cast())
  let output = oc_fallthrough_fact_run(body)
  assert_eq(oc_fallthrough_fact_count_casts(output), 1)
  let mut captures = 0
  let mut arm_writes = 0
  let mut dynamic_ifs = 0
  for node in 0..<@ir.hot_node_count(output) {
    if @ir.hot_node_is_live(output, node) &&
      @ir.hot_node_get(output, node).op is @ir.HotOp::LocalTee {
      captures += 1
    }
    if @ir.hot_node_is_live(output, node) {
      match @ir.hot_node_get(output, node).op {
        @ir.HotOp::GlobalSet => arm_writes += 1
        @ir.HotOp::If => dynamic_ifs += 1
        _ => ()
      }
    }
  }
  assert_eq(arm_writes, 2)
  assert_eq(dynamic_ifs, 1)
  assert_eq(captures, 0)
  assert_eq(@ir.hot_local_count(output), 3)
}

///|
test "optimize casts invalidates fallthrough facts for writes in either if arm" {
  let write = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  ]
  for write_then in [false, true] {
    let body = oc_fallthrough_fact_cast()
    body.append(
      oc_fallthrough_fact_if(
        if write_then {
          write
        } else {
          [@lib.Instruction::nop()]
        },
        if write_then {
          [@lib.Instruction::nop()]
        } else {
          write
        },
      ),
    )
    body.append(oc_fallthrough_fact_cast())
    assert_eq(oc_fallthrough_fact_count_casts(oc_fallthrough_fact_run(body)), 2)
  }
}

///|
test "optimize casts does not publish a cast from only one if arm" {
  for cast_then in [false, true] {
    let body = oc_fallthrough_fact_if(
      if cast_then {
        oc_fallthrough_fact_cast()
      } else {
        [@lib.Instruction::nop()]
      },
      if cast_then {
        [@lib.Instruction::nop()]
      } else {
        oc_fallthrough_fact_cast()
      },
    )
    body.append(oc_fallthrough_fact_cast())
    assert_eq(oc_fallthrough_fact_count_casts(oc_fallthrough_fact_run(body)), 2)
  }
}

///|
test "optimize casts retains the nonlinear control rejection after a cast" {
  // This optimization intentionally excludes exits and exception handlers.
  // Keep the existing nonlinear boundary until a separate path proof is added.
  let controls : Array[@lib.Instruction] = [
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::return_()],
      None,
    ),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
        ),
      ],
      Some([@lib.Instruction::nop()]),
    ),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::try_(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::throw_(@lib.TagIdx::new(0U))]),
          [@lib.LegacyCatch::all(@lib.Expr::new([@lib.Instruction::nop()]))],
        ),
      ],
      Some([@lib.Instruction::nop()]),
    ),
  ]
  for control in controls {
    let body = oc_fallthrough_fact_cast()
    body.append([@lib.Instruction::local_get(@lib.LocalIdx::new(1U)), control])
    body.append(oc_fallthrough_fact_cast())
    assert_eq(oc_fallthrough_fact_count_casts(oc_fallthrough_fact_run(body)), 2)
  }
}

///|
test "optimize casts invalidates facts for writes while computing the if condition" {
  let body = oc_fallthrough_fact_cast()
  body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_is_null(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::nop()],
      Some([@lib.Instruction::nop()]),
    ),
  ])
  body.append(oc_fallthrough_fact_cast())
  let output = oc_fallthrough_fact_run(body)
  assert_eq(oc_fallthrough_fact_count_casts(output), 2)
  let mut predicate_writes = 0
  for node in 0..<@ir.hot_node_count(output) {
    if @ir.hot_node_is_live(output, node) {
      let value = @ir.hot_node_get(output, node)
      if value.op is @ir.HotOp::LocalTee && value.imm0 == 0 {
        predicate_writes += 1
      }
    }
  }
  assert_eq(predicate_writes, 1)
}

///|
test "optimize casts keeps the first proof site when dropped cast roots are shared" {
  let body = oc_fallthrough_fact_cast()
  body.append(
    oc_fallthrough_fact_if([@lib.Instruction::nop()], [@lib.Instruction::nop()]),
  )
  body.append(oc_fallthrough_fact_cast())
  let base = pass_test_module_from_wat(
    "(module (type $s (struct)) (tag $e) (func (param (ref null struct) i32 (ref null struct))))",
  )
  let input = base.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    ]),
  )
  ignore(@validate.validate_module(input).unwrap())
  let hot = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let first_drop = @ir.hot_root_get(hot, 0)
  let first_cast = @ir.hot_child_get(hot, first_drop, 0)
  @ir.hot_root_set(hot, 2, first_drop)
  @ir.hot_verify_core(hot).unwrap()
  @ir.hot_verify_control(hot).unwrap()
  let ctx = HotPassContext::new(
    optimize_casts_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(input)),
  )
  ignore(optimize_casts_run(ctx, hot))
  @ir.hot_verify_core(hot).unwrap()
  @ir.hot_verify_control(hot).unwrap()
  // Removing only the last root occurrence must keep the dominating trap.
  assert_true(
    @ir.hot_node_exact_instr(hot, first_cast) is Some(@lib.RefCast(_, _, _)),
  )
  assert_eq(@ir.hot_root_get(hot, 0), first_drop)
  assert_true(
    @ir.hot_node_get(hot, @ir.hot_root_get(hot, 2)).op is @ir.HotOp::Nop,
  )
  ignore(
    @validate.validate_module(
      input.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(hot)])),
    ).unwrap(),
  )
}
