///|
fn dae_review_unused_parameter_plan(
  input : @lib.Module,
  target : Int32,
  caller : Int32,
) -> (DaeCurrentBoundaryGraph, DaeRewritePlan) {
  let graph = dae_current_boundary_graph_new(input)
  let plan = dae_build_scalar_unused_param_rewrite_plan(
    input,
    dae_collect_original_boundary_snapshot(input),
    graph,
    target,
    [true],
    dae_local_use_for_callee(graph.snapshot.funcs[target], 1, target, 1),
    1,
    [caller],
  ).unwrap()
  (graph, plan)
}

///|
fn dae_review_unused_parameter_input() -> @lib.Module {
  pass_test_module_from_wat(
    (
      #| (module
      #|   (func $a (param i32) (result i32) i32.const 11)
      #|   (func (export "a") (param i32) (result i32) local.get 0 call $a)
      #|   (func $b (param i32) (result i32) i32.const 22)
      #|   (func (export "b") (param i32) (result i32) local.get 0 call $b)
      #|   (func (result i32) i32.const 33))
    ),
  )
}

///|
test "DAE ordinary numeric parameter removal retains checked-source validation" {
  let input = dae_review_unused_parameter_input()
  let chain = dae_scalar_validation_test_chain()
  let work = DaeScalarValidationWork::new()
  let mut current = input
  for (target, caller) in [(0, 1), (2, 3)] {
    let (graph, plan) = dae_review_unused_parameter_plan(
      current, target, caller,
    )
    let result = dae_apply_rewrite_plan(
      current,
      graph,
      plan,
      scalar_validation_chain=Some(chain),
      scalar_validation_work=Some(work),
    )
    assert_true(result.applied)
    current = result.result.mod_out
    assert_eq(dae_wb_param_count(current, target), 0)
    @validate.validate_module(current).unwrap()
  }
  assert_eq(work.full_gates, 1)
  assert_eq(work.partial_gates, 1)
  assert_eq(work.full_bodies, 5)
  assert_eq(work.partial_bodies, 2)
}

///|
test "DAE ordinary parameter validation rejects an invalid untouched body" {
  let input = dae_review_unused_parameter_input()
  let funcs = input.code_sec.unwrap().0.copy()
  funcs[4] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(99U))]),
  )
  let invalid = input.with_code_sec(@lib.CodeSec::new(funcs))
  let (graph, plan) = dae_review_unused_parameter_plan(invalid, 0, 1)
  let result = dae_apply_rewrite_plan(
    invalid,
    graph,
    plan,
    scalar_validation_chain=Some(dae_scalar_validation_test_chain()),
  )
  assert_false(result.applied)
  assert_eq(result.reason, DaeValidationRollback)
  assert_true(physical_equal(result.result.mod_out, invalid))
}

///|
test "DAE ordinary parameter validation retains full gates for appended types" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (func $a (param i32) (result i32) i32.const 11)
      #|   (func (export "a") (param i32) (result i32) local.get 0 call $a)
      #|   (func $b (param i64) (result i64) i64.const 22)
      #|   (func (export "b") (param i64) (result i64) local.get 0 call $b))
    ),
  )
  let chain = dae_scalar_validation_test_chain()
  let work = DaeScalarValidationWork::new()
  let mut current = input
  for (target, caller) in [(0, 1), (2, 3)] {
    let (graph, plan) = dae_review_unused_parameter_plan(
      current, target, caller,
    )
    assert_true(plan.candidate.type_sec != current.type_sec)
    let result = dae_apply_rewrite_plan(
      current,
      graph,
      plan,
      scalar_validation_chain=Some(chain),
      scalar_validation_work=Some(work),
    )
    assert_true(result.applied)
    current = result.result.mod_out
    assert_eq(dae_wb_param_count(current, target), 0)
    @validate.validate_module(current).unwrap()
  }
  assert_eq(work.full_gates, 2)
  assert_eq(work.partial_gates, 0)
}

///|
fn dae_review_parameter_validation_bench(
  it : @bench.T,
  reference : Bool,
) -> Unit raise {
  let base = dae_review_unused_parameter_input()
  let funcs = base.code_sec.unwrap().0.copy()
  let types = base.func_sec.unwrap().0.copy()
  for _ in 0..<128 {
    funcs.push(funcs[4])
    types.push(types[4])
  }
  let input = base
    .with_func_sec(@lib.FuncSec::new(types))
    .with_code_sec(@lib.CodeSec::new(funcs))
  let steps : Array[(@lib.Module, DaeCurrentBoundaryGraph, DaeRewritePlan)] = []
  let mut current = input
  for (target, caller) in [(0, 1), (2, 3)] {
    let (graph, plan) = dae_review_unused_parameter_plan(
      current, target, caller,
    )
    steps.push((current, graph, plan))
    current = dae_apply_rewrite_plan(current, graph, plan).result.mod_out
  }
  @validate.validate_module(current).unwrap()
  assert_eq(dae_wb_param_count(current, 0), 0)
  assert_eq(dae_wb_param_count(current, 2), 0)
  it.bench(fn() {
    let chain = if reference {
      None
    } else {
      Some(dae_scalar_validation_test_chain())
    }
    for (source, graph, plan) in steps {
      it.keep(
        dae_apply_rewrite_plan(
          source,
          graph,
          plan,
          scalar_validation_chain=chain,
        ),
      )
    }
  })
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE ordinary parameter validation pre-review full gates" (
  it : @bench.T,
) {
  dae_review_parameter_validation_bench(it, true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE ordinary parameter validation checked-source reuse" (
  it : @bench.T,
) {
  dae_review_parameter_validation_bench(it, false)
}
