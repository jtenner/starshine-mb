///| The imported effect keeps the active prefix observable. Each numeric

///|
/// parameter rewrite must remove its inactive call to the shared hub.
fn dae_scalar_trim_input(width : Int32) -> @lib.Module {
  let wat = [
    "(module (import \"env\" \"tick\" (func $tick (param i32))) (func $hub)",
  ]
  for idx in 0..<width {
    wat.push(
      "(func $h\{idx} (param i32) local.get 0 call $tick unreachable call $hub)",
    )
  }
  for idx in 0..<width {
    wat.push("(func (export \"run\{idx}\") i32.const 7 call $h\{idx})")
  }
  wat.push(")")
  pass_test_module_from_wat(wat.join("\n")).without_name_sec()
}

///|
/// Every step uses the real scalar producer and its complete reference gate.
fn dae_scalar_trim_steps(
  input : @lib.Module,
  width : Int32,
) -> Array[DaeScalarValidationBenchStep] raise {
  let steps : Array[DaeScalarValidationBenchStep] = []
  let mut current = input
  for idx in 0..<width {
    let target_def = 1 + idx
    let target_abs = 1 + target_def
    let caller_def = 1 + width + idx
    let original = dae_collect_original_boundary_snapshot(current)
    let graph = dae_current_boundary_graph_new(current)
    let plan = dae_build_scalar_unused_param_rewrite_plan(
      current,
      original,
      graph,
      target_abs,
      [true],
      dae_local_use_for_callee(
        graph.snapshot.funcs[target_def],
        1,
        target_abs,
        1,
      ),
      1,
      [caller_def],
      materialized_params=Some([Some(@lib.Instruction::i32_const(@lib.I32(7)))]),
    ).unwrap()
    assert_true(
      physical_equal(
        current.type_sec.unwrap().0,
        plan.candidate.type_sec.unwrap().0,
      ),
    )
    let @lib.Func(_, @lib.Expr(before)) = current.code_sec.unwrap().0[target_def]
    let @lib.Func(_, @lib.Expr(after)) = plan.candidate.code_sec.unwrap().0[target_def]
    assert_true(
      before.any(fn(instr) {
        instr == @lib.Instruction::call(@lib.FuncIdx::new(1U))
      }),
    )
    assert_true(
      !after.any(fn(instr) {
        instr == @lib.Instruction::call(@lib.FuncIdx::new(1U))
      }),
    )
    assert_true(
      after.any(fn(instr) {
        instr == @lib.Instruction::call(@lib.FuncIdx::new(0U))
      }),
    )
    let application = dae_apply_rewrite_plan(current, graph, plan)
    assert_true(application.applied && application.result.changed)
    assert_true(application.effects.parameter_changed[target_def])
    assert_true(application.effects.body_materialized[target_def])
    steps.push({ source: current, graph, plan, })
    current = application.result.mod_out
  }
  steps
}

///|
test "scalar productive trims remove actual inactive hub edges from the retained certificate" {
  let width = 16
  let input = dae_scalar_trim_input(width)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let steps = dae_scalar_trim_steps(input, width)
  let options = HotPipelineOptions::new()
  let (expected, expected_effects) = dae_scalar_certificate_bench_round(
    steps, options, true,
  )
  let chain = dae_scalar_validation_test_chain()
  let work = DaeScalarValidationWork::new()
  let effects : Array[DaeCommitEffects] = []
  let mut actual = input
  for idx in 0..<steps.length() {
    let step = steps[idx]
    let source_saved = @binary.encode_module(step.source).unwrap()
    let application = dae_apply_rewrite_plan(
      step.source,
      step.graph,
      step.plan,
      scalar_validation_chain=Some(chain),
      scalar_validation_work=Some(work),
    )
    assert_true(application.applied && application.result.changed)
    effects.push(application.effects)
    actual = application.result.mod_out
    assert_eq(dae_wb_param_count(actual, 2 + idx), 0)
    assert_eq(@binary.encode_module(step.source).unwrap(), source_saved)
    if idx == 0 {
      assert_true(chain.syntax_index is None)
    } else {
      let index = chain.syntax_index.unwrap()
      // Hub is defined function zero. These assertions inspect the retained
      // index after each actual productive transaction, not a cost model.
      assert_eq(index.users[0].length(), width - idx - 1)
      for removed in 0..<(idx + 1) {
        assert_true(!index.rows[1 + removed].contains(0))
        assert_true(!index.users[0].contains(1 + removed))
      }
    }
  }
  assert_eq(effects, expected_effects)
  assert_eq(
    @binary.encode_module(actual).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  @validate.validate_module(actual).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(work.full_gates, 1)
  assert_eq(work.partial_gates, width - 1)
  assert_eq(work.index_builds, 1)
  assert_eq(work.removed_dependencies, width - 1)
  assert_true(work.reverse_comparisons > work.removed_dependencies)
  assert_eq(work.full_bodies, 1 + 2 * width)
  assert_eq(work.partial_bodies, 2 * (width - 1))
  dae_scalar_validation_barrier(chain)
}

///|
test "main scalar core uses the post core literal worklist for observable void trims without retaining a certificate" {
  let width = 8
  let input = dae_scalar_trim_input(width)
  let saved = @binary.encode_module(input).unwrap()
  @validate.validate_module(input).unwrap()
  let options = HotPipelineOptions::new()
  let reference_trace : Array[String] = []
  let expected = dae_run_core(input, fn(line) { reference_trace.push(line) })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  let work = DaeScalarValidationWork::new()
  let actual = dae_run_core(
    input,
    options.trace,
    no_callback_trace=hot_pipeline_dae_no_callback_trace(options),
    scalar_validation_work=Some(work),
  )
  assert_true(actual.changed)
  assert_eq(actual.effects, expected.effects)
  assert_eq(actual.touched, expected.touched)
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  @validate.validate_module(actual.mod_out).unwrap()
  for idx in 0..<width {
    assert_eq(dae_wb_param_count(actual.mod_out, 2 + idx), 0)
    let @lib.Func(_, @lib.Expr(body)) = actual.mod_out.code_sec.unwrap().0[1 +
      idx]
    assert_true(
      body.any(fn(instr) {
        instr == @lib.Instruction::call(@lib.FuncIdx::new(0U))
      }),
    )
    assert_true(
      !body.any(fn(instr) {
        instr == @lib.Instruction::call(@lib.FuncIdx::new(1U))
      }),
    )
  }
  // The public scheduler does not choose the retained scalar path for this
  // observable void fixture. Its post-core literal worklist commits all eight
  // productive trims after the private scalar certificate lifetime has ended.
  assert_eq(
    reference_trace
    .filter(fn(line) {
      line.has_prefix("pass[dae-optimizing]:low-exact-literal-worklist iter=")
    })
    .length(),
    width,
  )
  assert_eq(work.offered, 0)
  assert_eq(work.full_gates, 0)
  assert_eq(work.partial_gates, 0)
  assert_eq(work.index_builds, 0)
  assert_eq(work.removed_dependencies, 0)
  assert_eq(work.reverse_comparisons, 0)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///| Direct transaction stress only: the public scheduler uses the post-core

///| literal worklist for this fixture and does not retain a scalar certificate.

///| Setup, exact output, validation and ownership checks are outside clocks.

///|
/// Reference processes do not construct the certificate index in preflight.
fn dae_scalar_trim_bench(
  it : @bench.T,
  width : Int32,
  reference : Bool,
) -> Unit raise {
  let input = dae_scalar_trim_input(width)
  let saved = @binary.encode_module(input).unwrap()
  @validate.validate_module(input).unwrap()
  let steps = dae_scalar_trim_steps(input, width)
  let options = HotPipelineOptions::new()
  let (expected, expected_effects) = dae_scalar_certificate_bench_round(
    steps, options, true,
  )
  let work = DaeScalarValidationWork::new()
  let (actual, effects) = dae_scalar_certificate_bench_round(
    steps,
    options,
    reference,
    work=if reference { None } else { Some(work) },
  )
  assert_eq(effects, expected_effects)
  assert_eq(
    @binary.encode_module(actual).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  @validate.validate_module(actual).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  if !reference {
    assert_eq(work.full_gates, 1)
    assert_eq(work.partial_gates, width - 1)
    assert_eq(work.index_builds, 1)
    assert_eq(work.removed_dependencies, width - 1)
    println(
      "scalar-trim preflight width=\{width} removed_dependencies=\{work.removed_dependencies} reverse_comparisons=\{work.reverse_comparisons}",
    )
  }
  it.bench(fn() {
    it.keep(dae_scalar_certificate_bench_round(steps, options, reference))
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("manual native productive inactive-edge trim paired cost control")
test "bench scalar trim 64 helpers full reference" (it : @bench.T) {
  dae_scalar_trim_bench(it, 64, true)
}

///|
#skip("manual native productive inactive-edge trim paired cost control")
test "bench scalar trim 64 helpers private certificate" (it : @bench.T) {
  dae_scalar_trim_bench(it, 64, false)
}

///|
#skip("manual native productive inactive-edge trim paired cost control")
test "bench scalar trim 512 helpers full reference" (it : @bench.T) {
  dae_scalar_trim_bench(it, 512, true)
}

///|
#skip("manual native productive inactive-edge trim paired cost control")
test "bench scalar trim 512 helpers private certificate" (it : @bench.T) {
  dae_scalar_trim_bench(it, 512, false)
}
