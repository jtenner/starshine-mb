///|
/// Prepared outside clocks with the real scalar planner and old commit gate.
priv struct DaeScalarValidationBenchStep {
  source : @lib.Module
  graph : DaeCurrentBoundaryGraph
  plan : DaeRewritePlan
}

///|
fn dae_scalar_certificate_bench_input(
  siblings : Int32,
  append_type : Bool,
) -> @lib.Module {
  let base = if append_type {
    pass_test_module_from_wat(
      (
        #|(module
        #| (func $a (param i32) (result i32) local.get 0 i32.const 1 i32.add)
        #| (func (export "a") (result i32) i32.const 7 call $a)
        #| (func $b (param i64 i32) (result i32) local.get 0 i32.wrap_i64 local.get 1 i32.add)
        #| (func (export "b") (param i64) (result i64) local.get 0 i32.const 9 call $b i64.extend_i32_s)
        #| (func (param i64 i32) (result i32) local.get 1))
      ),
    )
  } else {
    pass_test_module_from_wat(
      (
        #|(module
        #| (func $a (param i32) (result i32) local.get 0 i32.const 1 i32.add)
        #| (func (export "a") (result i32) i32.const 7 call $a)
        #| (func $b (param i32) (result i32) local.get 0 i32.const 2 i32.add)
        #| (func (export "b") (result i32) i32.const 9 call $b)
        #| (func (param i32) (result i32) local.get 0)
        #| (func (result i32) i32.const 3)
        #| (func (result i32) i32.const 4))
      ),
    )
  }
  let base = base.without_name_sec()
  let funcs = base.code_sec.unwrap().0.copy()
  let types = base.func_sec.unwrap().0.copy()
  for _ in 0..<siblings {
    funcs.push(funcs[4])
    types.push(types[4])
  }
  base
  .with_func_sec(@lib.FuncSec::new(types))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn dae_scalar_certificate_bench_steps(
  input : @lib.Module,
  repeated : Bool,
  append_type : Bool,
) -> Array[DaeScalarValidationBenchStep] raise {
  let steps : Array[DaeScalarValidationBenchStep] = []
  let mut current = input
  let targets = if repeated { [(0, 1, 7), (2, 3, 9)] } else { [(0, 1, 7)] }
  for (target, caller, value) in targets {
    let original = dae_collect_original_boundary_snapshot(current)
    let graph = dae_current_boundary_graph_new(current)
    let append_step = append_type && target == 2
    let remove = if append_step { [false, true] } else { [true] }
    let values = if append_step {
      [None, Some(@lib.Instruction::i32_const(@lib.I32(value)))]
    } else {
      [Some(@lib.Instruction::i32_const(@lib.I32(value)))]
    }
    let plan = dae_build_scalar_unused_param_rewrite_plan(
      current,
      original,
      graph,
      target,
      remove,
      dae_local_use_for_callee(
        graph.snapshot.funcs[target],
        remove.length(),
        target,
        1,
      ),
      1,
      [caller],
      materialized_params=Some(values),
    ).unwrap()
    if append_step {
      assert_eq(
        dae_type_sec_flattened_length(plan.candidate.type_sec.unwrap()),
        dae_type_sec_flattened_length(current.type_sec.unwrap()) + 1,
      )
    } else {
      assert_true(
        physical_equal(
          current.type_sec.unwrap().0,
          plan.candidate.type_sec.unwrap().0,
        ),
      )
    }
    let application = dae_apply_rewrite_plan(current, graph, plan)
    assert_true(application.applied)
    steps.push({ source: current, graph, plan, })
    current = application.result.mod_out
  }
  steps
}

///|
/// The proof is local to this round. No work recorder is used during clocks.
fn dae_scalar_certificate_bench_round(
  steps : Array[DaeScalarValidationBenchStep],
  options : HotPipelineOptions,
  reference : Bool,
  work~ : DaeScalarValidationWork? = None,
) -> (@lib.Module, Array[DaeCommitEffects]) {
  let chain = if reference {
    None
  } else {
    Some(
      dae_scalar_validation_chain_new(
        options.trace,
        options.perf,
        hot_pipeline_dae_no_callback_trace(options),
      ),
    )
  }
  let effects : Array[DaeCommitEffects] = []
  let mut current = steps[0].source
  for step in steps {
    let application = dae_apply_rewrite_plan(
      step.source,
      step.graph,
      step.plan,
      scalar_validation_chain=chain,
      scalar_validation_work=work,
    )
    if !application.applied {
      abort("scalar certificate native control did not commit")
    }
    effects.push(application.effects)
    current = application.result.mod_out
  }
  dae_scalar_validation_barrier_opt(chain)
  (current, effects)
}

///|
/// Plan setup, bytes, complete validation and ownership checks are outside clocks.
fn dae_scalar_certificate_bench(
  it : @bench.T,
  siblings : Int32,
  repeated : Bool,
  append_type : Bool,
  route : Int32,
  reference : Bool,
) -> Unit raise {
  let input = dae_scalar_certificate_bench_input(siblings, append_type)
  let saved = @binary.encode_module(input).unwrap()
  @validate.validate_module(input).unwrap()
  let steps = dae_scalar_certificate_bench_steps(input, repeated, append_type)
  let options = match route {
    1 => HotPipelineOptions::new(trace=Some(fn(_ : String) { () }))
    2 => HotPipelineOptions::new(perf=Some(HotPerfSession::new()))
    _ => HotPipelineOptions::new()
  }
  let (expected, expected_effects) = dae_scalar_certificate_bench_round(
    steps, options, true,
  )
  let preflight_work = DaeScalarValidationWork::new()
  let (actual, effects) = dae_scalar_certificate_bench_round(
    steps,
    options,
    reference,
    work=if reference { None } else { Some(preflight_work) },
  )
  assert_eq(effects, expected_effects)
  assert_eq(
    @binary.encode_module(actual).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  @validate.validate_module(actual).unwrap()
  let actual_types = dae_collect_func_type_indices(actual)
  let @lib.FuncType(params, _) = dae_resolve_func_type(actual, actual_types, 0).unwrap()
  assert_eq(params.length(), 0)
  if repeated {
    let @lib.FuncType(params, _) = dae_resolve_func_type(
      actual, actual_types, 2,
    ).unwrap()
    assert_eq(params.length(), if append_type { 1 } else { 0 })
  }
  if !reference {
    let fast_second = repeated && !append_type && route == 0
    assert_eq(
      preflight_work.full_gates,
      if fast_second {
        1
      } else {
        steps.length()
      },
    )
    assert_eq(preflight_work.partial_gates, if fast_second { 1 } else { 0 })
    assert_eq(preflight_work.index_builds, if fast_second { 1 } else { 0 })
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  it.bench(fn() {
    it.keep(dae_scalar_certificate_bench_round(steps, options, reference))
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("manual native scalar certificate paired cost control")
test "bench scalar certificate small first full reference" (it : @bench.T) {
  dae_scalar_certificate_bench(it, 0, false, false, 0, true)
}

///|
#skip("manual native scalar certificate paired cost control")
test "bench scalar certificate small first private certificate" (it : @bench.T) {
  dae_scalar_certificate_bench(it, 0, false, false, 0, false)
}

///|
#skip("manual native scalar certificate paired cost control")
test "bench scalar certificate small repeated full reference" (it : @bench.T) {
  dae_scalar_certificate_bench(it, 0, true, false, 0, true)
}

///|
#skip("manual native scalar certificate paired cost control")
test "bench scalar certificate small repeated private certificate" (
  it : @bench.T,
) {
  dae_scalar_certificate_bench(it, 0, true, false, 0, false)
}

///|
#skip("manual native scalar certificate paired cost control")
test "bench scalar certificate 13000 siblings first full reference" (
  it : @bench.T,
) {
  dae_scalar_certificate_bench(it, 13000, false, false, 0, true)
}

///|
#skip("manual native scalar certificate paired cost control")
test "bench scalar certificate 13000 siblings first private certificate" (
  it : @bench.T,
) {
  dae_scalar_certificate_bench(it, 13000, false, false, 0, false)
}

///|
#skip("manual native scalar certificate paired cost control")
test "bench scalar certificate 13000 siblings repeated full reference" (
  it : @bench.T,
) {
  dae_scalar_certificate_bench(it, 13000, true, false, 0, true)
}

///|
#skip("manual native scalar certificate paired cost control")
test "bench scalar certificate 13000 siblings repeated private certificate" (
  it : @bench.T,
) {
  dae_scalar_certificate_bench(it, 13000, true, false, 0, false)
}

///|
#skip("manual native scalar certificate paired cost control")
test "bench scalar certificate append fallback full reference" (it : @bench.T) {
  dae_scalar_certificate_bench(it, 0, true, true, 0, true)
}

///|
#skip("manual native scalar certificate paired cost control")
test "bench scalar certificate append fallback private certificate" (
  it : @bench.T,
) {
  dae_scalar_certificate_bench(it, 0, true, true, 0, false)
}

///|
#skip("manual native scalar certificate paired cost control")
test "bench scalar certificate user trace exclusion full reference" (
  it : @bench.T,
) {
  dae_scalar_certificate_bench(it, 0, true, false, 1, true)
}

///|
#skip("manual native scalar certificate paired cost control")
test "bench scalar certificate user trace exclusion private certificate" (
  it : @bench.T,
) {
  dae_scalar_certificate_bench(it, 0, true, false, 1, false)
}

///|
#skip("manual native scalar certificate paired cost control")
test "bench scalar certificate perf exclusion full reference" (it : @bench.T) {
  dae_scalar_certificate_bench(it, 0, true, false, 2, true)
}

///|
#skip("manual native scalar certificate paired cost control")
test "bench scalar certificate perf exclusion private certificate" (
  it : @bench.T,
) {
  dae_scalar_certificate_bench(it, 0, true, false, 2, false)
}
