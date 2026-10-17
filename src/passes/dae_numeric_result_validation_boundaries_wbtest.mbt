///| A real result-removal constructor and signature plan, with its full source

///|
/// graph and active call identities. No validation token is manually minted.
fn dae_numeric_result_v2_plan(
  source : @lib.Module,
  graph : DaeCurrentBoundaryGraph,
  target : Int32,
) -> DaeRewritePlan raise {
  let original = dae_collect_original_boundary_snapshot(source)
  let candidate = dae_try_remove_dropped_result_def_with_facts(
    source,
    target,
    graph.snapshot.call_facts,
    boundary_facts=Some({
      original,
      graph,
      incoming_param_live_by_def: [],
      incoming_param_live_body_epochs: [],
    }),
  )
  assert_true(candidate.changed)
  let item = dae_nonforwarding_work_item_new(
    graph,
    target,
    DaeDroppedResultWork,
  )
  let effects = dae_work_item_candidate_effects(source, graph, item, candidate)
  dae_build_signature_rewrite_plan_from_candidate(
    original, source, graph, target, candidate, effects,
  ).unwrap()
}

///|
/// Behavior assertions precede every resource requirement in the callers.
fn dae_numeric_result_v2_application_equal(
  source : @lib.Module,
  expected : DaeRewritePlanApplication,
  actual : DaeRewritePlanApplication,
  saved : Bytes,
) -> Unit raise {
  assert_true(expected.applied && actual.applied)
  assert_true(expected.result.changed && actual.result.changed)
  assert_eq(actual.effects, expected.effects)
  assert_eq(actual.result.touched, expected.result.touched)
  assert_eq(
    @binary.encode_module(actual.result.mod_out).unwrap(),
    @binary.encode_module(expected.result.mod_out).unwrap(),
  )
  @validate.validate_module(actual.result.mod_out).unwrap()
  assert_eq(@binary.encode_module(source).unwrap(), saved)
}

///| The same private constructor and final committed-candidate gate used by

///|
/// the core run, bounded to one productive target for precise controls.
fn dae_numeric_result_v2_step(
  source : @lib.Module,
  target : Int32,
  chain : DaeScalarValidationChain,
  work : DaeScalarValidationWork,
) -> DaeRewritePlanApplication raise {
  let saved = @binary.encode_module(source).unwrap()
  let graph = dae_current_boundary_graph_new(source)
  dae_numeric_result_validation_before_producer(Some(chain), graph, target)
  let plan = dae_numeric_result_v2_plan(source, graph, target)
  let expected = dae_apply_rewrite_plan(source, graph, plan)
  let actual = dae_apply_rewrite_plan(
    source,
    graph,
    plan,
    numeric_result_validation_chain=Some(chain),
    numeric_result_validation_work=Some(work),
  )
  dae_numeric_result_v2_application_equal(source, expected, actual, saved)
  assert_eq(
    dae_numeric_result_validation_results(actual.result.mod_out, target),
    0,
  )
  assert_true(actual.effects.result_removed[target])
  assert_true(actual.effects.result_changed[target])
  assert_true(actual.result.touched[target])
  assert_eq(
    dae_wb_param_count(actual.result.mod_out, target),
    dae_wb_param_count(source, target),
  )
  let @lib.Func(_, @lib.Expr(body)) = actual.result.mod_out.code_sec.unwrap().0[target]
  assert_true(
    body.contains(@lib.Instruction::global_set(@lib.GlobalIdx::new(0U))),
  )
  actual
}

///| Every child is syntactically present after an explicit unreachable root.

///|
/// The source and final function result remain valid for all ten scopes.
fn dae_numeric_result_v2_dead_scopes(
  dead : Array[@lib.Instruction],
) -> Array[Array[@lib.Instruction]] {
  let void_ = @lib.BlockType::void_()
  let no_dependency = [@lib.Instruction::unreachable_()]
  [
    dead,
    [
      @lib.Instruction::unreachable_(),
      @lib.Instruction::block(void_, @lib.Expr::new(dead)),
    ],
    [
      @lib.Instruction::unreachable_(),
      @lib.Instruction::loop_(void_, @lib.Expr::new(dead)),
    ],
    [
      @lib.Instruction::unreachable_(),
      @lib.Instruction::if_(void_, dead, Some(no_dependency)),
    ],
    [
      @lib.Instruction::unreachable_(),
      @lib.Instruction::if_(void_, no_dependency, Some(dead)),
    ],
    [@lib.Instruction::unreachable_(), @lib.Instruction::if_(void_, dead, None)],
    [
      @lib.Instruction::unreachable_(),
      @lib.Instruction::try_table(void_, [], @lib.Expr::new(dead)),
    ],
    [
      @lib.Instruction::unreachable_(),
      @lib.Instruction::try_(void_, @lib.Expr::new(dead), [
        @lib.LegacyCatch::all(@lib.Expr::new(no_dependency)),
      ]),
    ],
    [
      @lib.Instruction::unreachable_(),
      @lib.Instruction::try_(void_, @lib.Expr::new(no_dependency), [
        @lib.LegacyCatch::all(@lib.Expr::new(dead)),
      ]),
    ],
    [
      @lib.Instruction::unreachable_(),
      @lib.Instruction::try_(void_, @lib.Expr::new(no_dependency), [
        @lib.LegacyCatch::tagged(@lib.TagIdx::new(0U), @lib.Expr::new(dead)),
      ]),
    ],
  ]
}

///|
fn dae_numeric_result_v2_with_observer(
  base : @lib.Module,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let funcs = base.code_sec.unwrap().0.copy()
  let types = base.func_sec.unwrap().0.copy()
  funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)))
  types.push(types[3])
  let tagged = base.with_tag_sec(
    @lib.TagSec::new([@lib.TagType::new(types[2])]),
  )
  tagged
  .with_func_sec(@lib.FuncSec::new(types))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
test "numeric result mode checks inactive calls in root block loop if and EH scopes" {
  let observed : Array[(Int32, Int32, Int32, Int32)] = []
  let dead = [
    @lib.Instruction::unreachable_(),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::unreachable_(),
  ]
  for body in dae_numeric_result_v2_dead_scopes(dead) {
    let input = dae_numeric_result_v2_with_observer(
      dae_numeric_result_validation_fixture(),
      body,
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let graph = dae_current_boundary_graph_new(input)
    // Active counts exclude this use, but the producer's complete caller row
    // includes it and will normalize its unreachable suffix during rewriting.
    assert_eq(graph.snapshot.call_facts.direct_calls[1], 1)
    assert_eq(graph.snapshot.call_facts.direct_callers[1], [2, 4])
    let chain = dae_scalar_validation_test_chain()
    let work = DaeScalarValidationWork::new()
    let first = dae_numeric_result_v2_step(input, 0, chain, work)
    let observer_reference = dae_numeric_result_v2_plan(
      first.result.mod_out,
      dae_current_boundary_graph_new(first.result.mod_out),
      1,
    )
    let second = dae_numeric_result_v2_step(
      first.result.mod_out,
      1,
      chain,
      work,
    )
    // Trap normalization differs by control family, including legacy Try.
    // Keep each exact old producer result rather than prescribing a new shape.
    assert_eq(
      second.result.mod_out.code_sec.unwrap().0[4],
      observer_reference.candidate.code_sec.unwrap().0[4],
    )
    assert_eq(second.result.touched, observer_reference.touched_functions)
    assert_eq(
      dae_numeric_result_validation_results(second.result.mod_out, 0),
      0,
    )
    assert_eq(
      dae_numeric_result_validation_results(second.result.mod_out, 1),
      0,
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    @validate.validate_module(second.result.mod_out).unwrap()
    // The actual producer above cleans this inactive caller. Independently
    // probe a valid final candidate which retains the old observer physically,
    // so the complete syntax index must still select its unchanged Call user.
    // This probe checks validation coverage, not producer cleanup policy.
    let probe_chain = dae_scalar_validation_test_chain()
    let probe_work = DaeScalarValidationWork::new()
    let probe_first = dae_numeric_result_v2_step(
      input, 0, probe_chain, probe_work,
    )
    let probe_source = probe_first.result.mod_out
    let probe_saved = @binary.encode_module(probe_source).unwrap()
    let probe_graph = dae_current_boundary_graph_new(probe_source)
    dae_numeric_result_validation_before_producer(
      Some(probe_chain),
      probe_graph,
      1,
    )
    let probe_plan = dae_numeric_result_v2_plan(probe_source, probe_graph, 1)
    let probe_funcs = probe_plan.candidate.code_sec.unwrap().0.copy()
    probe_funcs[4] = probe_source.code_sec.unwrap().0[4]
    let probe_candidate = probe_plan.candidate.with_code_sec(
      @lib.CodeSec::new(probe_funcs),
    )
    let probe_candidate_saved = @binary.encode_module(probe_candidate).unwrap()
    assert_true(
      physical_equal(
        probe_candidate.code_sec.unwrap().0[4],
        probe_source.code_sec.unwrap().0[4],
      ),
    )
    assert_eq(dae_numeric_result_validation_results(probe_candidate, 0), 0)
    assert_eq(dae_numeric_result_validation_results(probe_candidate, 1), 0)
    @validate.validate_module(probe_candidate).unwrap()
    dae_numeric_result_validation_check_candidate(
      probe_chain,
      probe_source,
      probe_candidate,
      probe_plan,
      work=Some(probe_work),
    ).unwrap()
    assert_eq(@binary.encode_module(probe_source).unwrap(), probe_saved)
    assert_eq(
      @binary.encode_module(probe_candidate).unwrap(),
      probe_candidate_saved,
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    observed.push(
      (
        work.full_gates,
        work.full_bodies,
        work.partial_gates,
        work.partial_bodies,
      ),
    )
    observed.push(
      (
        probe_work.full_gates,
        probe_work.full_bodies,
        probe_work.partial_gates,
        probe_work.partial_bodies,
      ),
    )
  }
  // All ten actual transactions and ten unchanged-user probes run before RED.
  assert_eq(observed.length(), 20)
  for (full, bodies, partial, selected) in observed {
    assert_eq(full, 1)
    assert_eq(bodies, 5)
    assert_eq(partial, 1)
    assert_eq(selected, 3)
  }
}

///| Result mismatch in an inactive return_call is intentionally unsupported:

///|
/// the producer candidate must fail the old full gate with its exact error.
test "numeric result mode preserves inactive return call errors in every child scope" {
  let dead = [
    @lib.Instruction::unreachable_(),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::return_call(@lib.FuncIdx::new(1U)),
  ]
  for body in dae_numeric_result_v2_dead_scopes(dead) {
    let input = dae_numeric_result_v2_with_observer(
      dae_numeric_result_validation_fixture(),
      body,
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let chain = dae_scalar_validation_test_chain()
    let first_work = DaeScalarValidationWork::new()
    let first = dae_numeric_result_v2_step(input, 0, chain, first_work)
    let source = first.result.mod_out
    let source_saved = @binary.encode_module(source).unwrap()
    let graph = dae_current_boundary_graph_new(source)
    assert_eq(graph.snapshot.call_facts.direct_calls[1], 1)
    assert_false(graph.snapshot.call_facts.tail_calls[1])
    dae_numeric_result_validation_before_producer(Some(chain), graph, 1)
    let plan = dae_numeric_result_v2_plan(source, graph, 1)
    let expected = dae_apply_rewrite_plan(source, graph, plan)
    let error = @validate.validate_module(plan.candidate).unwrap_err()
    let work = DaeScalarValidationWork::new()
    let actual = dae_apply_rewrite_plan(
      source,
      graph,
      plan,
      numeric_result_validation_chain=Some(chain),
      numeric_result_validation_work=Some(work),
    )
    assert_false(expected.applied || actual.applied)
    assert_eq(actual.reason, expected.reason)
    assert_eq(actual.effects, expected.effects)
    assert_eq(actual.result.touched, expected.result.touched)
    assert_eq(
      @binary.encode_module(actual.result.mod_out).unwrap(),
      source_saved,
    )
    assert_eq(
      @validate.validation_error_func_idx(error),
      Some(@lib.FuncIdx::new(4U)),
    )
    assert_eq(
      dae_numeric_result_validation_results(actual.result.mod_out, 0),
      0,
    )
    assert_eq(
      dae_numeric_result_validation_results(actual.result.mod_out, 1),
      1,
    )
    @validate.validate_module(actual.result.mod_out).unwrap()
    assert_eq(@binary.encode_module(source).unwrap(), source_saved)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    // Check the validator boundary directly too: rollback reason alone does not
    // expose the diagnostic, and must not hide an incomplete dependency row.
    let exact = dae_numeric_result_validation_check_candidate(
      chain,
      source,
      plan.candidate,
      plan,
    ).unwrap_err()
    assert_eq(exact, error)
    // These counts measure selected-path coverage, not false acceptance:
    // unwrap_err and exact diagnostics above remain the correctness checks.
    assert_eq(work.matched_sources, 1)
    assert_eq(work.envelope_matches, 1)
    assert_eq(work.index_builds, 1)
    assert_eq(work.partial_bodies, 3)
    assert_eq(work.full_gates, 1)
    assert_eq(work.full_errors, 1)
    assert_eq(work.partial_gates, 0)
  }
}

///|
fn dae_numeric_result_v2_ref_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    (
      #|(module
      #| (type $old (func (param i32) (result i32)))
      #| (global $seen (mut i32) (i32.const 0))
      #| (func $a (type $old) local.get 0 global.set $seen local.get 0)
      #| (func $b (type $old) local.get 0 i32.const 1 i32.add global.set $seen local.get 0)
      #| (func (export "run") (param i32)
      #|  local.get 0 call $a drop local.get 0 call $b drop)
      #| (func (result i32) i32.const 31)
      #| (func (result (ref $old)) ref.func $b)
      #| (elem declare func $b))
    ),
  )
}

///| A twin without function-index exposure supplies a real constructor plan.

///| It shares TypeSec backing with the exposed fixture. Its plan is never

///|
/// committed to the exposed module: only the independent checker is probed.
fn dae_numeric_result_v2_unexposed_twin(input : @lib.Module) -> @lib.Module {
  let funcs = input.code_sec.unwrap().0.copy()
  funcs[4] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::unreachable_()]),
  )
  input
  .with_code_sec(@lib.CodeSec::new(funcs))
  .with_elem_sec(@lib.ElemSec::new([]))
}

///| Build the COW validation-adversarial candidate from a real plan's changed

///| target/caller bodies. Non-code fields and the exposed observer are borrowed

///|
/// unchanged from the actual checked source, never from the unexposed twin.
fn dae_numeric_result_v2_probe_candidate(
  source : @lib.Module,
  template : DaeRewritePlan,
) -> @lib.Module {
  let funcs = template.candidate.code_sec.unwrap().0.copy()
  for def_idx in 0..<funcs.length() {
    if def_idx != 1 && def_idx != 2 {
      funcs[def_idx] = source.code_sec.unwrap().0[def_idx]
    }
  }
  source
  .with_func_sec(template.candidate.func_sec.unwrap())
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///| RefFunc exposure is intentionally unsupported by the result producer.

///|
/// A real preceding result removal must not override this ownership guard.
test "numeric result mode preserves inactive ref func exposure and typed uses in every child scope" {
  let dead = [
    @lib.Instruction::unreachable_(),
    @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(1U)),
    @lib.Instruction::unreachable_(),
  ]
  for body in dae_numeric_result_v2_dead_scopes(dead) {
    let base = dae_numeric_result_v2_ref_fixture()
    let stub_funcs = base.code_sec.unwrap().0.copy()
    stub_funcs[4] = @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    )
    let old_type = base.func_sec.unwrap().0[1]
    let old_ref = @lib.RefType::new(true, @lib.HeapType::new(old_type))
    let globals = base.global_sec.unwrap().0.copy()
    globals.push(
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::ref_type(old_ref), true),
        @lib.Expr::new([
          @lib.Instruction::ref_null(@lib.HeapType::new(old_type)),
        ]),
      ),
    )
    let input = dae_numeric_result_v2_with_observer(
      base
      .with_code_sec(@lib.CodeSec::new(stub_funcs))
      .with_global_sec(@lib.GlobalSec::new(globals)),
      body,
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    // The plan twin has no function-index reference. The only RefFunc in
    // actual code is in this case's isolated inactive observer child.
    let twin_funcs = input.code_sec.unwrap().0.copy()
    twin_funcs[5] = @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    )
    let twin = input
      .with_code_sec(@lib.CodeSec::new(twin_funcs))
      .with_elem_sec(@lib.ElemSec::new([]))
    let twin_first = dae_numeric_result_v2_step(
      twin,
      0,
      dae_scalar_validation_test_chain(),
      DaeScalarValidationWork::new(),
    )
    let template_source = twin_first.result.mod_out
    let template = dae_numeric_result_v2_plan(
      template_source,
      dae_current_boundary_graph_new(template_source),
      1,
    )
    let chain = dae_scalar_validation_test_chain()
    let first_work = DaeScalarValidationWork::new()
    let first = dae_numeric_result_v2_step(input, 0, chain, first_work)
    let source = first.result.mod_out
    let source_saved = @binary.encode_module(source).unwrap()
    let graph = dae_current_boundary_graph_new(source)
    assert_eq(graph.snapshot.call_facts.direct_calls[1], 1)
    assert_eq(graph.snapshot.call_facts.dropped_calls[1], 1)
    let declined = dae_try_remove_dropped_result_def_with_facts(
      source,
      1,
      graph.snapshot.call_facts,
    )
    assert_false(declined.changed)
    assert_eq(declined.touched, [])
    assert_eq(@binary.encode_module(declined.mod_out).unwrap(), source_saved)
    assert_eq(dae_numeric_result_validation_results(source, 0), 0)
    assert_eq(dae_numeric_result_validation_results(source, 1), 1)
    assert_eq(source.code_sec.unwrap().0[5], input.code_sec.unwrap().0[5])
    @validate.validate_module(source).unwrap()
    // The adversarial candidate keeps that observer physically unchanged.
    // Its concrete ref.func value no longer matches the typed global.set,
    // even though the containing scope is unreachable.
    let candidate = dae_numeric_result_v2_probe_candidate(source, template)
    let candidate_saved = @binary.encode_module(candidate).unwrap()
    assert_true(
      physical_equal(
        candidate.code_sec.unwrap().0[5],
        source.code_sec.unwrap().0[5],
      ),
    )
    let error = @validate.validate_module(candidate).unwrap_err()
    assert_eq(
      @validate.validation_error_func_idx(error),
      Some(@lib.FuncIdx::new(5U)),
    )
    let work = DaeScalarValidationWork::new()
    let actual = dae_numeric_result_validation_check_candidate(
      chain,
      source,
      candidate,
      template,
      work=Some(work),
    ).unwrap_err()
    assert_eq(actual, error)
    assert_eq(@binary.encode_module(candidate).unwrap(), candidate_saved)
    assert_eq(@binary.encode_module(source).unwrap(), source_saved)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    assert_eq(first_work.full_gates, 1)
    assert_eq(first_work.partial_gates, 0)
    // These counts measure selected-path coverage, not false acceptance:
    // unwrap_err and exact diagnostics above remain the correctness checks.
    assert_eq(work.matched_sources, 1)
    assert_eq(work.envelope_matches, 1)
    assert_eq(work.index_builds, 1)
    assert_eq(work.partial_bodies, 3)
    assert_eq(work.full_gates, 1)
    assert_eq(work.full_errors, 1)
    assert_eq(work.partial_gates, 0)
  }
}

///| The exposed target cannot be offered by production. This adversarial COW

///| candidate still requires the independent checker to find its unchanged

///|
/// RefFunc user and run the original full gate for the exact body error.
test "numeric result checker retains an unchanged typed ref func body error" {
  let input = dae_numeric_result_v2_ref_fixture()
  let saved = @binary.encode_module(input).unwrap()
  let twin = dae_numeric_result_v2_unexposed_twin(input)
  @validate.validate_module(twin).unwrap()
  let twin_first = dae_numeric_result_v2_step(
    twin,
    0,
    dae_scalar_validation_test_chain(),
    DaeScalarValidationWork::new(),
  )
  let template_source = twin_first.result.mod_out
  let template = dae_numeric_result_v2_plan(
    template_source,
    dae_current_boundary_graph_new(template_source),
    1,
  )
  let chain = dae_scalar_validation_test_chain()
  let first = dae_numeric_result_v2_step(
    input,
    0,
    chain,
    DaeScalarValidationWork::new(),
  )
  let source = first.result.mod_out
  let source_saved = @binary.encode_module(source).unwrap()
  let candidate = dae_numeric_result_v2_probe_candidate(source, template)
  let candidate_saved = @binary.encode_module(candidate).unwrap()
  let error = @validate.validate_module(candidate).unwrap_err()
  assert_eq(
    @validate.validation_error_func_idx(error),
    Some(@lib.FuncIdx::new(4U)),
  )
  let work = DaeScalarValidationWork::new()
  let actual = dae_numeric_result_validation_check_candidate(
    chain,
    source,
    candidate,
    template,
    work=Some(work),
  ).unwrap_err()
  assert_eq(actual, error)
  assert_eq(@binary.encode_module(candidate).unwrap(), candidate_saved)
  assert_eq(@binary.encode_module(source).unwrap(), source_saved)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  @validate.validate_module(source).unwrap()
  assert_eq(dae_numeric_result_validation_results(source, 0), 0)
  assert_eq(dae_numeric_result_validation_results(source, 1), 1)
  // These counts measure selected-path coverage, not false acceptance:
  // unwrap_err and exact diagnostics above remain the correctness checks.
  assert_eq(work.matched_sources, 1)
  assert_eq(work.envelope_matches, 1)
  assert_eq(work.index_builds, 1)
  assert_eq(work.partial_bodies, 3)
  assert_eq(work.full_gates, 1)
  assert_eq(work.full_errors, 1)
  assert_eq(work.partial_gates, 0)
}

///| Typed non-code references are intentionally unsupported after the callee

///|
/// result context changes. Identical non-code field references are not proof.
test "numeric result checker retains typed global table and element error priority" {
  let base = dae_numeric_result_v2_unexposed_twin(
    dae_numeric_result_v2_ref_fixture(),
  )
  let old_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(base.func_sec.unwrap().0[1]),
  )
  let expr = @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))])
  let globals = base.global_sec.unwrap().0.copy()
  globals.push(
    @lib.Global::new(
      @lib.GlobalType::new(@lib.ValType::ref_type(old_ref), false),
      expr,
    ),
  )
  let inputs = [
    base.with_global_sec(@lib.GlobalSec::new(globals)),
    base.with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(old_ref, @lib.Limits::i32(1U, None)),
          Some(expr),
        ),
      ]),
    ),
    base.with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::typed_exprs(old_ref, [expr]),
        ),
      ]),
    ),
  ]
  let twin_first = dae_numeric_result_v2_step(
    base,
    0,
    dae_scalar_validation_test_chain(),
    DaeScalarValidationWork::new(),
  )
  let template_source = twin_first.result.mod_out
  let template = dae_numeric_result_v2_plan(
    template_source,
    dae_current_boundary_graph_new(template_source),
    1,
  )
  for input in inputs {
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let chain = dae_scalar_validation_test_chain()
    let first = dae_numeric_result_v2_step(
      input,
      0,
      chain,
      DaeScalarValidationWork::new(),
    )
    let source = first.result.mod_out
    let source_saved = @binary.encode_module(source).unwrap()
    let candidate = dae_numeric_result_v2_probe_candidate(source, template)
    let candidate_saved = @binary.encode_module(candidate).unwrap()
    let error = @validate.validate_module(candidate).unwrap_err()
    assert_true(@validate.validation_error_func_idx(error) is None)
    let work = DaeScalarValidationWork::new()
    let actual = dae_numeric_result_validation_check_candidate(
      chain,
      source,
      candidate,
      template,
      work=Some(work),
    ).unwrap_err()
    assert_eq(actual, error)
    assert_eq(@binary.encode_module(source).unwrap(), source_saved)
    assert_eq(@binary.encode_module(candidate).unwrap(), candidate_saved)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    @validate.validate_module(source).unwrap()
    assert_eq(dae_numeric_result_validation_results(source, 0), 0)
    assert_eq(dae_numeric_result_validation_results(source, 1), 1)
    // These counts measure selected-path coverage, not false acceptance:
    // unwrap_err and exact diagnostics above remain the correctness checks.
    assert_eq(work.matched_sources, 1)
    assert_eq(work.envelope_matches, 1)
    assert_eq(work.index_builds, 1)
    assert_eq(work.partial_bodies, 0)
    assert_eq(work.full_gates, 1)
    assert_eq(work.full_errors, 1)
    assert_eq(work.full_bodies, 0)
    assert_eq(work.partial_gates, 0)
  }
}

///|
/// External type-array writes are intentionally outside the audited lifetime.
/// This test documents the explicit barrier protocol. It does not prove that
/// an omitted production barrier or an in-lifetime alias write is detected.
test "numeric result external type array writes require an explicit barrier protocol" {
  for mutate_results in [false, true] {
    let base = dae_numeric_result_validation_fixture()
    let funcs = base.code_sec.unwrap().0.copy()
    let types = base.func_sec.unwrap().0.copy()
    funcs.push(
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
      ),
    )
    types.push(types[1])
    let input = base
      .with_func_sec(@lib.FuncSec::new(types))
      .with_code_sec(@lib.CodeSec::new(funcs))
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let chain = dae_scalar_validation_test_chain()
    let first = dae_numeric_result_v2_step(
      input,
      0,
      chain,
      DaeScalarValidationWork::new(),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    let source = first.result.mod_out
    let graph = dae_current_boundary_graph_new(source)
    let plan = dae_numeric_result_v2_plan(source, graph, 1)
    let candidate = plan.candidate
    let @lib.TypeSec(source_types) = source.type_sec.unwrap()
    let @lib.TypeSec(candidate_types) = candidate.type_sec.unwrap()
    assert_true(physical_equal(source_types, candidate_types))
    // This real external write invalidates an unchanged sibling. Reference
    // identity is deliberately unchanged; only the explicit boundary is safe.
    dae_scalar_validation_barrier(chain)
    let @lib.FuncType(params, results) = dae_type_sec_func_type(
      source.type_sec.unwrap(),
      source.func_sec.unwrap().0[1],
    ).unwrap()
    if mutate_results {
      results[0] = @lib.ValType::i64()
    } else {
      params[0] = @lib.ValType::i64()
    }
    assert_true(physical_equal(source_types, source.type_sec.unwrap().0))
    assert_true(physical_equal(source_types, candidate.type_sec.unwrap().0))
    let input_after_external_write = @binary.encode_module(input).unwrap()
    let source_after_external_write = @binary.encode_module(source).unwrap()
    let candidate_after_external_write = @binary.encode_module(candidate).unwrap()
    let error = @validate.validate_module(candidate).unwrap_err()
    assert_eq(
      @validate.validation_error_func_idx(error),
      Some(@lib.FuncIdx::new(4U)),
    )
    let work = DaeScalarValidationWork::new()
    let actual = dae_numeric_result_validation_check_candidate(
      chain,
      source,
      candidate,
      plan,
      work=Some(work),
    ).unwrap_err()
    assert_eq(actual, error)
    assert_eq(@binary.encode_module(input).unwrap(), input_after_external_write)
    assert_eq(
      @binary.encode_module(source).unwrap(),
      source_after_external_write,
    )
    assert_eq(
      @binary.encode_module(candidate).unwrap(),
      candidate_after_external_write,
    )
    assert_eq(dae_numeric_result_validation_results(source, 0), 0)
    assert_eq(dae_numeric_result_validation_results(source, 1), 1)
    assert_eq(work.full_gates, 1)
    assert_eq(work.full_errors, 1)
    assert_eq(work.partial_gates, 0)
    assert_eq(work.partial_bodies, 0)
  }
}

///|
fn dae_numeric_result_v2_interleaved_fixture(
  unused_middle : Bool,
) -> @lib.Module {
  let middle_body = if unused_middle {
    "i32.const 17"
  } else {
    "local.get 0 i32.const 1 i32.add"
  }
  let argument = if unused_middle { "local.get 0" } else { "i32.const 7" }
  pass_test_module_from_wat(
    "(module (global $seen (mut i32) (i32.const 0)) " +
    "(func $a (param i32) (result i32) local.get 0 global.set $seen local.get 0) " +
    "(func $middle (param i32) (result i32) " +
    middle_body +
    ") " +
    "(func $b (param i32) (result i32) local.get 0 i32.const 1 i32.add global.set $seen local.get 0) " +
    "(func (export \"run\") (param i32) local.get 0 call $a drop " +
    argument +
    " call $middle drop local.get 0 call $b drop) " +
    "(func (result i32) i32.const 31))",
  )
}

///| Both transitions are productive: result -> scalar -> result. Keeping the

///|
/// existing scalar lifetime separate is an intentional first-tier boundary.
test "numeric result scalar result commits keep both cross family gates complete" {
  let input = dae_numeric_result_v2_interleaved_fixture(false)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let chain = dae_scalar_validation_test_chain()
  let result_work = DaeScalarValidationWork::new()
  let scalar_work = DaeScalarValidationWork::new()
  let first = dae_numeric_result_v2_step(input, 0, chain, result_work)
  let source = first.result.mod_out
  let source_saved = @binary.encode_module(source).unwrap()
  let (graph, plan) = dae_scalar_validation_test_plan(source, 1, 3, 7)
  let expected_middle = dae_apply_rewrite_plan(source, graph, plan)
  let middle = dae_apply_rewrite_plan(
    source,
    graph,
    plan,
    scalar_validation_chain=Some(chain),
    scalar_validation_work=Some(scalar_work),
  )
  dae_numeric_result_v2_application_equal(
    source, expected_middle, middle, source_saved,
  )
  assert_eq(dae_wb_param_count(middle.result.mod_out, 1), 0)
  assert_true(middle.effects.parameter_changed[1])
  assert_true(middle.effects.body_materialized[1])
  assert_true(middle.result.touched[1] && middle.result.touched[3])
  let @lib.Func(_, @lib.Expr(middle_body)) = middle.result.mod_out.code_sec.unwrap().0[1]
  assert_true(middle_body.contains(@lib.Instruction::i32_const(@lib.I32(7))))
  assert_false(
    middle_body.contains(@lib.Instruction::local_get(@lib.LocalIdx::new(0U))),
  )
  assert_eq(dae_numeric_result_validation_results(middle.result.mod_out, 0), 0)
  assert_eq(dae_numeric_result_validation_results(middle.result.mod_out, 2), 1)
  let last = dae_numeric_result_v2_step(
    middle.result.mod_out,
    2,
    chain,
    result_work,
  )
  assert_eq(dae_numeric_result_validation_results(last.result.mod_out, 0), 0)
  assert_eq(dae_numeric_result_validation_results(last.result.mod_out, 2), 0)
  assert_eq(dae_wb_param_count(last.result.mod_out, 1), 0)
  @validate.validate_module(last.result.mod_out).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(result_work.full_gates, 2)
  assert_eq(result_work.full_bodies, 10)
  assert_eq(result_work.partial_gates, 0)
  assert_eq(scalar_work.full_gates, 1)
  assert_eq(scalar_work.full_bodies, 5)
  assert_eq(scalar_work.partial_gates, 0)
}

///|
/// The middle producer really removes an unused parameter and returns a new
/// module object. This explicit barrier protocol also loses exact source
/// identity; it cannot detect removal of the production barrier on its own.
test "numeric result explicit barrier keeps full gates around a productive new object producer" {
  let input = dae_numeric_result_v2_interleaved_fixture(true)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let chain = dae_scalar_validation_test_chain()
  let work = DaeScalarValidationWork::new()
  let first = dae_numeric_result_v2_step(input, 0, chain, work)
  let source = first.result.mod_out
  let source_saved = @binary.encode_module(source).unwrap()
  let graph = dae_current_boundary_graph_new(source)
  let original = dae_collect_original_boundary_snapshot(source)
  dae_scalar_validation_barrier(chain)
  let expected_middle = dae_try_process_core_work_item(
    original,
    source,
    graph,
    1,
    DaeUnusedParameterWork,
    apply_followups=false,
  ).unwrap()
  let middle = dae_try_process_core_work_item(
    original,
    source,
    graph,
    1,
    DaeUnusedParameterWork,
    apply_followups=false,
  ).unwrap()
  assert_true(expected_middle.applied && middle.applied)
  assert_true(expected_middle.changed && middle.changed)
  assert_eq(middle.effects, expected_middle.effects)
  assert_eq(middle.touched, expected_middle.touched)
  assert_eq(
    @binary.encode_module(middle.mod_out).unwrap(),
    @binary.encode_module(expected_middle.mod_out).unwrap(),
  )
  assert_eq(dae_wb_param_count(middle.mod_out, 1), 0)
  assert_true(middle.effects.parameter_changed[1])
  assert_false(physical_equal(middle.mod_out, source))
  assert_true(middle.touched[1] && middle.touched[3])
  let @lib.Func(_, @lib.Expr(middle_body)) = middle.mod_out.code_sec.unwrap().0[1]
  assert_true(middle_body.contains(@lib.Instruction::i32_const(@lib.I32(17))))
  @validate.validate_module(middle.mod_out).unwrap()
  assert_eq(@binary.encode_module(source).unwrap(), source_saved)
  let last = dae_numeric_result_v2_step(middle.mod_out, 2, chain, work)
  assert_eq(dae_numeric_result_validation_results(last.result.mod_out, 0), 0)
  assert_eq(dae_numeric_result_validation_results(last.result.mod_out, 2), 0)
  assert_eq(dae_wb_param_count(last.result.mod_out, 1), 0)
  @validate.validate_module(last.result.mod_out).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  // Counts below concern the two result gates. The middle producer retains
  // its separate existing complete gate, which this result recorder does not count.
  assert_eq(work.full_gates, 2)
  assert_eq(work.full_bodies, 10)
  assert_eq(work.partial_gates, 0)
}
