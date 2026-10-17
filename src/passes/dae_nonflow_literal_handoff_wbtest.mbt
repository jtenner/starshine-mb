///|
fn dae_nonflow_literal_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    (
      #|(module
      #| (func $target (param i32) (result i32) local.get 0 i32.const 1 i32.add)
      #| (func (export "run") (result i32) i32.const 7 call $target)
      #| (func (result i32) i32.const 9)
      #| (func (result i32) i32.const 10))
    ),
  )
}

///| The reference retains the original inner and outer complete gates.

///|
/// The actual route executes the scheduler's non-flow literal branch.
fn dae_nonflow_literal_round(
  input : @lib.Module,
  target_def : Int32,
  reference : Bool,
  counts : Array[Int32],
  suffix~ : Bool = false,
  immutable_global~ : Bool = false,
) -> (DaePassResult, DaeCommitEffects, Int32) {
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let item = {
    ..dae_work_item_new(graph, dependencies, target_def, DaeUniformActualWork),
    allow_immutable_global_get: immutable_global,
    allow_immediate_i32_suffix_fallback: suffix,
  }
  let empty : DaePassResult = {
    mod_out: input,
    touched: [],
    changed: false,
    primary_def: -1,
  }
  if reference {
    let candidate = dae_try_rewrite_exact_literal_def_with_facts_once(
      input,
      target_def,
      graph.snapshot.call_facts,
      allow_immutable_global_get=immutable_global,
      allow_immediate_i32_suffix_fallback=suffix,
      original=Some(original),
      graph=Some(graph),
      rewrite_validation_counts=Some(counts),
    )
    if !candidate.changed {
      return (empty, dae_commit_effects_empty(graph.snapshot.defined), 0)
    }
    let effects = dae_work_item_candidate_effects(input, graph, item, candidate)
    let plan = dae_build_signature_rewrite_plan_from_candidate(
      original, input, graph, target_def, candidate, effects,
    ).unwrap()
    let applied = dae_apply_rewrite_plan(
      input,
      graph,
      plan,
      rewrite_validation_counts=Some(counts),
    )
    return (
      applied.result,
      applied.effects,
      if applied.applied {
        0
      } else {
        1
      },
    )
  }
  let diagnostics = dae_diagnostics_new()
  match
    dae_process_work_item(
      original,
      input,
      [],
      false,
      graph,
      dependencies,
      item,
      diagnostics,
      rewrite_validation_counts=Some(counts),
    ) {
    DaeWorkCommitted(application) =>
      (
        {
          mod_out: application.mod_out,
          touched: application.touched,
          changed: application.changed,
          primary_def: application.primary_def,
        },
        application.effects,
        diagnostics.validation_rollbacks,
      )
    _ =>
      (
        empty,
        dae_commit_effects_empty(graph.snapshot.defined),
        diagnostics.validation_rollbacks,
      )
  }
}

///|
test "non flow literal scheduler retains one complete gate for the exact checked candidate" {
  let input = dae_nonflow_literal_fixture()
  let saved = @binary.encode_module(input).unwrap()
  let reference_counts = [0, 0]
  let (expected, expected_effects, expected_rollbacks) = dae_nonflow_literal_round(
    input, 0, true, reference_counts,
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  let counts = [0, 0]
  let (actual, effects, rollbacks) = dae_nonflow_literal_round(
    input, 0, false, counts,
  )
  assert_true(actual.changed)
  assert_eq(actual.touched, expected.touched)
  assert_eq(actual.primary_def, expected.primary_def)
  assert_eq(effects, expected_effects)
  assert_eq(rollbacks, expected_rollbacks)
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  assert_eq(dae_wb_param_count(actual.mod_out, 0), 0)
  assert_true(effects.parameter_changed[0] && effects.body_materialized[0])
  @validate.validate_module(actual.mod_out).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  // Both counters are recorded at actual complete-gate/reuse sites.
  assert_eq(reference_counts, [2, 0])
  assert_eq(counts, [1, 1])
}

///|
test "non flow immediate suffix handoff retains the older argument and imported side effect" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #| (import "env" "side" (func $side))
      #| (func $target (param i32 i32) (result i32) local.get 0 local.get 1 i32.add)
      #| (func (export "run") (param i32) (result i32)
      #|   local.get 0 call $side i32.const 7 call $target))
    ),
  )
  let saved = @binary.encode_module(input).unwrap()
  let reference_counts = [0, 0]
  let (expected, expected_effects, _) = dae_nonflow_literal_round(
    input,
    0,
    true,
    reference_counts,
    suffix=true,
  )
  let counts = [0, 0]
  let (actual, effects, rollbacks) = dae_nonflow_literal_round(
    input,
    0,
    false,
    counts,
    suffix=true,
  )
  assert_true(actual.changed)
  assert_eq(actual.touched, expected.touched)
  assert_eq(effects, expected_effects)
  assert_eq(rollbacks, 0)
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  assert_eq(dae_wb_param_count(actual.mod_out, 1), 1)
  let @lib.Func(_, @lib.Expr(body)) = actual.mod_out.code_sec.unwrap().0[1]
  assert_eq(body, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ])
  @validate.validate_module(actual.mod_out).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(reference_counts, [2, 0])
  assert_eq(counts, [1, 1])
}

///|
test "non flow literal handoff retains the first complete invalid sibling and metadata gates" {
  let valid = dae_nonflow_literal_fixture()
  let funcs = valid.code_sec.unwrap().0.copy()
  funcs[2] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(99U))]),
  )
  let exports = valid.export_sec.unwrap().0.copy()
  exports.push(exports[0])
  // These inputs are intentionally invalid outside the rewritten boundary.
  // The duplicate export precedes the invalid sibling in diagnostic order.
  for
    input in [
      valid.with_code_sec(@lib.CodeSec::new(funcs)),
      valid
      .with_export_sec(@lib.ExportSec::new(exports))
      .with_code_sec(@lib.CodeSec::new(funcs)),
      valid.with_start_sec(@lib.StartSec::new(@lib.FuncIdx::new(1U))),
      valid.with_custom_secs([@lib.CustomSec::new(@lib.Name::new("name"), b"")]),
      valid.with_custom_secs([
        @lib.CustomSec::new(@lib.Name::new("compiler.facts"), b""),
      ]),
    ] {
    // Reserved raw metadata is intentionally unencodable. Check both its
    // exact encoder result and the complete remaining module bytes.
    let saved_encoding = @binary.encode_module(input)
    let saved_customs = input.custom_secs.copy()
    let saved = @binary.encode_module(input.with_custom_secs([])).unwrap()
    let first_validation = @validate.validate_module(input)
    assert_true(first_validation is Err(_))
    let reference_counts = [0, 0]
    let (expected, expected_effects, expected_rollbacks) = dae_nonflow_literal_round(
      input, 0, true, reference_counts,
    )
    let counts = [0, 0]
    let (actual, effects, rollbacks) = dae_nonflow_literal_round(
      input, 0, false, counts,
    )
    assert_false(expected.changed || actual.changed)
    assert_true(physical_equal(actual.mod_out, input))
    assert_eq(actual.touched, expected.touched)
    assert_eq(effects, expected_effects)
    assert_eq(rollbacks, expected_rollbacks)
    assert_eq(counts, reference_counts)
    assert_eq(counts, [1, 0])
    assert_eq(@validate.validate_module(actual.mod_out), first_validation)
    assert_eq(@binary.encode_module(input), saved_encoding)
    assert_eq(input.custom_secs, saved_customs)
    assert_eq(@binary.encode_module(input.with_custom_secs([])).unwrap(), saved)
  }
}

///|
test "non flow literal handoff checks the repaired candidate while preserving invalid input names" {
  let input = dae_nonflow_literal_fixture().with_name_sec(
    @lib.NameSec::new(
      func_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(99U, @lib.Name::new("invalid-index")),
        ]),
      ),
    ),
  )
  let saved = @binary.encode_module(input).unwrap()
  assert_true(@validate.validate_module(input) is Err(_))
  let reference_counts = [0, 0]
  let (expected, expected_effects, _) = dae_nonflow_literal_round(
    input, 0, true, reference_counts,
  )
  let counts = [0, 0]
  let (actual, effects, rollbacks) = dae_nonflow_literal_round(
    input, 0, false, counts,
  )
  assert_true(actual.changed)
  assert_eq(actual.touched, expected.touched)
  assert_eq(effects, expected_effects)
  assert_eq(rollbacks, 0)
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  assert_true(input.name_sec is Some(_))
  assert_true(actual.mod_out.name_sec is None)
  @validate.validate_module(actual.mod_out).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(reference_counts, [2, 0])
  assert_eq(counts, [1, 1])
}

///|
test "non flow literal scheduler rejects stale epochs before either complete gate" {
  let input = dae_nonflow_literal_fixture()
  let saved = @binary.encode_module(input).unwrap()
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let item = dae_work_item_new(graph, dependencies, 0, DaeUniformActualWork)
  graph.module_epoch += 1
  let counts = [0, 0]
  let outcome = dae_process_work_item(
    original,
    input,
    [],
    false,
    graph,
    dependencies,
    item,
    dae_diagnostics_new(),
    rewrite_validation_counts=Some(counts),
  )
  assert_true(outcome is DaeWorkRequeue(_))
  assert_eq(counts, [0, 0])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
