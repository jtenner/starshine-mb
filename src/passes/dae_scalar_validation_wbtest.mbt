///|
fn dae_scalar_validation_test_chain(
  options~ : HotPipelineOptions = HotPipelineOptions::new(),
) -> DaeScalarValidationChain {
  dae_scalar_validation_chain_new(
    options.trace,
    options.perf,
    hot_pipeline_dae_no_callback_trace(options),
  )
}

///|
fn dae_scalar_validation_test_input() -> @lib.Module {
  pass_test_module_from_wat(
    (
      #|(module
      #|  (func $a (param i32) (result i32) local.get 0 i32.const 1 i32.add)
      #|  (func (export "a") (result i32) i32.const 7 call $a)
      #|  (func $b (param i32) (result i32) local.get 0 i32.const 2 i32.add)
      #|  (func (export "b") (result i32) i32.const 9 call $b)
      #|  (func (param i32) (result i32) local.get 0)
      #|  (func (result i32) i32.const 3)
      #|  (func (result i32) i32.const 4))
    ),
  )
}

///|
fn dae_scalar_validation_test_plan(
  input : @lib.Module,
  target : Int32,
  caller : Int32,
  value : Int32,
) -> (DaeCurrentBoundaryGraph, DaeRewritePlan) {
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let plan = dae_build_scalar_unused_param_rewrite_plan(
    input,
    original,
    graph,
    target,
    [true],
    dae_local_use_for_callee(graph.snapshot.funcs[target], 1, target, 1),
    1,
    [caller],
    materialized_params=Some([
      Some(@lib.Instruction::i32_const(@lib.I32(value))),
    ]),
  ).unwrap()
  (graph, plan)
}

///|
fn dae_scalar_validation_test_two_steps(
  input : @lib.Module,
  chain : DaeScalarValidationChain?,
  work : DaeScalarValidationWork,
) -> (@lib.Module, Array[DaeCommitEffects]) raise {
  let effects : Array[DaeCommitEffects] = []
  let mut current = input
  for (target, caller, value) in [(0, 1, 7), (2, 3, 9)] {
    let saved = @binary.encode_module(current).unwrap()
    let (graph, plan) = dae_scalar_validation_test_plan(
      current, target, caller, value,
    )
    assert_eq(plan.candidate.type_sec, current.type_sec)
    let application = dae_apply_rewrite_plan(
      current,
      graph,
      plan,
      scalar_validation_chain=chain,
      scalar_validation_work=Some(work),
    )
    assert_true(application.applied && application.result.changed)
    assert_eq(dae_wb_param_count(application.result.mod_out, target), 0)
    assert_true(application.result.touched[target])
    assert_true(application.result.touched[caller])
    assert_true(application.effects.body_materialized[target])
    assert_eq(@binary.encode_module(current).unwrap(), saved)
    effects.push(application.effects)
    current = application.result.mod_out
  }
  (current, effects)
}

///|
test "scalar validation chain checks two real literal rewrites without repeating unrelated bodies" {
  let input = dae_scalar_validation_test_input()
  let saved = @binary.encode_module(input).unwrap()
  let reference_work = DaeScalarValidationWork::new()
  let (expected, expected_effects) = dae_scalar_validation_test_two_steps(
    input,
    None,
    reference_work,
  )
  let work = DaeScalarValidationWork::new()
  let (actual, effects) = dae_scalar_validation_test_two_steps(
    input,
    Some(dae_scalar_validation_test_chain()),
    work,
  )
  assert_eq(effects, expected_effects)
  assert_eq(
    @binary.encode_module(actual).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  @validate.validate_module(actual).unwrap()
  assert_eq(dae_wb_param_count(actual, 0), 0)
  assert_eq(dae_wb_param_count(actual, 2), 0)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  let bodies = input.code_sec.unwrap().0.length()
  // The first full gate checks every body. The next gate must check the two
  // changed bodies, using independently complete source dependency coverage.
  assert_eq(work.full_bodies, bodies)
  assert_eq(work.partial_bodies, 2)
  assert_eq(work.full_gates, 1)
}

///|
test "scalar validation retains full gates for user trace and perf routes" {
  let input = dae_scalar_validation_test_input()
  let expected = dae_scalar_validation_test_two_steps(
      input,
      None,
      DaeScalarValidationWork::new(),
    ).0
  for
    options in [
      HotPipelineOptions::new(trace=Some(fn(_ : String) { () })),
      HotPipelineOptions::new(perf=Some(HotPerfSession::new())),
    ] {
    let chain = dae_scalar_validation_test_chain(options~)
    let work = DaeScalarValidationWork::new()
    let (actual, _) = dae_scalar_validation_test_two_steps(
      input,
      Some(chain),
      work,
    )
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(expected).unwrap(),
    )
    assert_true(chain.checked_source is None)
    assert_eq(work.full_gates, 2)
    assert_eq(work.full_bodies, input.code_sec.unwrap().0.length() * 2)
    assert_eq(work.partial_bodies, 0)
  }
}

///|
test "non audited producer barrier ends the scalar source proof" {
  let input = dae_scalar_validation_test_input()
  let saved = @binary.encode_module(input).unwrap()
  let chain = dae_scalar_validation_test_chain()
  let work = DaeScalarValidationWork::new()
  let (graph, plan) = dae_scalar_validation_test_plan(input, 0, 1, 7)
  let first = dae_apply_rewrite_plan(
    input,
    graph,
    plan,
    scalar_validation_chain=Some(chain),
    scalar_validation_work=Some(work),
  )
  assert_true(first.applied)
  // Every producer outside the audited scalar path must execute this barrier,
  // even when it reports no change or returns a shared outer module wrapper.
  dae_scalar_validation_barrier(chain)
  assert_true(chain.checked_source is None)
  let source = first.result.mod_out
  let (graph, plan) = dae_scalar_validation_test_plan(source, 2, 3, 9)
  let second = dae_apply_rewrite_plan(
    source,
    graph,
    plan,
    scalar_validation_chain=Some(chain),
    scalar_validation_work=Some(work),
  )
  assert_true(second.applied)
  assert_eq(dae_wb_param_count(second.result.mod_out, 0), 0)
  assert_eq(dae_wb_param_count(second.result.mod_out, 2), 0)
  @validate.validate_module(second.result.mod_out).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(work.full_gates, 2)
  assert_eq(work.full_bodies, input.code_sec.unwrap().0.length() * 2)
  assert_eq(work.partial_bodies, 0)
}

///|
test "same type backing with nested external mutation cannot retain the scalar proof" {
  let input = dae_scalar_validation_test_input()
  let chain = dae_scalar_validation_test_chain()
  let (graph, plan) = dae_scalar_validation_test_plan(input, 0, 1, 7)
  let first = dae_apply_rewrite_plan(
    input,
    graph,
    plan,
    scalar_validation_chain=Some(chain),
  )
  assert_true(first.applied)
  let source = first.result.mod_out
  let (_, next_plan) = dae_scalar_validation_test_plan(source, 2, 3, 9)
  let candidate = next_plan.candidate
  let @lib.TypeSec(before_types) = source.type_sec.unwrap()
  let @lib.TypeSec(candidate_types) = candidate.type_sec.unwrap()
  assert_true(physical_equal(before_types, candidate_types))
  // This intentionally invalid external write models a non-audited producer.
  // TypeSec identity alone cannot prove that its nested params remain fixed.
  dae_scalar_validation_barrier(chain)
  let target_type = source.func_sec.unwrap().0[2]
  let @lib.FuncType(params, _) = dae_type_sec_func_type(
    source.type_sec.unwrap(),
    target_type,
  ).unwrap()
  params[0] = @lib.ValType::i64()
  assert_true(physical_equal(before_types, source.type_sec.unwrap().0))
  let expected = @validate.validate_module(candidate).unwrap_err()
  let work = DaeScalarValidationWork::new()
  let actual = dae_scalar_validation_check_candidate(
    chain,
    source,
    candidate,
    work=Some(work),
  ).unwrap_err()
  assert_eq(actual, expected)
  assert_eq(
    @validate.validation_error_func_idx(actual),
    Some(@lib.FuncIdx::new(4U)),
  )
  assert_true(chain.checked_source is None)
  assert_eq(work.full_gates, 1)
  assert_eq(work.partial_bodies, 0)
}

///|
test "scalar validation retains first errors for invalid siblings and changed bodies" {
  let input = dae_scalar_validation_test_input()
  let (_, plan) = dae_scalar_validation_test_plan(input, 0, 1, 7)
  let valid_candidate = plan.candidate
  for invalid_changed_body in [false, true] {
    let funcs = valid_candidate.code_sec.unwrap().0.copy()
    funcs[if invalid_changed_body { 0 } else { 4 }] = @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(99U))]),
    )
    // A second invalid body must not displace the first body diagnostic.
    funcs[6] = @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::i64_const(@lib.I64(9L))]),
    )
    let candidate = valid_candidate.with_code_sec(@lib.CodeSec::new(funcs))
    let saved = @binary.encode_module(candidate).unwrap()
    let expected = @validate.validate_module(candidate).unwrap_err()
    let chain = dae_scalar_validation_test_chain()
    dae_scalar_validation_check_candidate(chain, input, input).unwrap()
    let work = DaeScalarValidationWork::new()
    let actual = dae_scalar_validation_check_candidate(
      chain,
      input,
      candidate,
      work=Some(work),
    ).unwrap_err()
    assert_eq(actual, expected)
    assert_eq(
      @validate.validation_error_func_idx(actual),
      Some(@lib.FuncIdx::new(if invalid_changed_body { 0U } else { 4U })),
    )
    assert_eq(@binary.encode_module(candidate).unwrap(), saved)
    assert_true(chain.checked_source is None)
    assert_eq(work.full_gates, 1)
  }
}

///|
test "scalar validation keeps earlier section errors before invalid code" {
  let input = dae_scalar_validation_test_input()
  let (_, plan) = dae_scalar_validation_test_plan(input, 0, 1, 7)
  let funcs = plan.candidate.code_sec.unwrap().0.copy()
  funcs[0] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(99U))]),
  )
  let exports = plan.candidate.export_sec.unwrap().0
  let candidate = plan.candidate
    .with_code_sec(@lib.CodeSec::new(funcs))
    .with_export_sec(@lib.ExportSec::new([exports[0], exports[0]]))
  let expected = @validate.validate_module(candidate).unwrap_err()
  let work = DaeScalarValidationWork::new()
  let actual = dae_scalar_validation_check_candidate(
    dae_scalar_validation_test_chain(),
    input,
    candidate,
    work=Some(work),
  ).unwrap_err()
  assert_eq(actual, expected)
  assert_true(
    @validate.validation_error_message(actual).contains("duplicate export name"),
  )
  assert_eq(work.full_gates, 1)
  assert_eq(work.full_bodies, 0)
}

///|
test "scalar validation preserves invalid removable name repair through the complete candidate gate" {
  let input = dae_scalar_validation_test_input().with_name_sec(
    @lib.NameSec::new(
      func_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(99U, @lib.Name::new("invalid-index")),
        ]),
      ),
    ),
  )
  assert_true(@validate.validate_module(input) is Err(_))
  let saved = @binary.encode_module(input).unwrap()
  let (graph, plan) = dae_scalar_validation_test_plan(input, 0, 1, 7)
  let reference = dae_apply_rewrite_plan(input, graph, plan)
  let work = DaeScalarValidationWork::new()
  let actual = dae_apply_rewrite_plan(
    input,
    graph,
    plan,
    scalar_validation_chain=Some(dae_scalar_validation_test_chain()),
    scalar_validation_work=Some(work),
  )
  assert_true(actual.applied && reference.applied)
  assert_true(actual.result.mod_out.name_sec is None)
  assert_eq(actual.effects, reference.effects)
  assert_eq(
    @binary.encode_module(actual.result.mod_out).unwrap(),
    @binary.encode_module(reference.result.mod_out).unwrap(),
  )
  @validate.validate_module(actual.result.mod_out).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(work.full_gates, 1)
  assert_eq(work.full_bodies, input.code_sec.unwrap().0.length())
  assert_eq(work.partial_bodies, 0)
}

///|
test "raw name and compiler facts keep full validation and exact late errors" {
  let input = dae_scalar_validation_test_input()
  let (_, plan) = dae_scalar_validation_test_plan(input, 0, 1, 7)
  for name in ["name", "compiler.facts"] {
    let chain = dae_scalar_validation_test_chain()
    dae_scalar_validation_check_candidate(chain, input, input).unwrap()
    let candidate = plan.candidate.with_custom_secs([
      @lib.CustomSec::new(@lib.Name::new(name), b""),
    ])
    let expected = @validate.validate_module(candidate).unwrap_err()
    let work = DaeScalarValidationWork::new()
    let actual = dae_scalar_validation_check_candidate(
      chain,
      input,
      candidate,
      work=Some(work),
    ).unwrap_err()
    assert_eq(actual, expected)
    assert_eq(work.full_gates, 1)
    assert_eq(work.full_bodies, input.code_sec.unwrap().0.length())
    assert_eq(work.partial_bodies, 0)
    assert_true(chain.checked_source is None)
  }
}

///|
test "scalar validation preserves early stale plan gates before candidate validation" {
  let input = dae_scalar_validation_test_input()
  let saved = @binary.encode_module(input).unwrap()
  let (graph, plan) = dae_scalar_validation_test_plan(input, 0, 1, 7)
  graph.module_epoch += 1
  let work = DaeScalarValidationWork::new()
  let actual = dae_apply_rewrite_plan(
    input,
    graph,
    plan,
    scalar_validation_chain=Some(dae_scalar_validation_test_chain()),
    scalar_validation_work=Some(work),
  )
  assert_false(actual.applied)
  assert_eq(actual.reason, DaeStaleCandidateFacts)
  assert_true(physical_equal(actual.result.mod_out, input))
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(work.full_gates, 0)
  assert_eq(work.full_bodies, 0)
  assert_eq(work.partial_bodies, 0)
}

///|
test "main core keeps two scalar optimizations and checks unchanged siblings only once" {
  let input = dae_scalar_validation_test_input()
  let saved = @binary.encode_module(input).unwrap()
  let expected_options = HotPipelineOptions::new()
  let expected = dae_run_core(input, expected_options.trace)
  let options = HotPipelineOptions::new()
  let work = DaeScalarValidationWork::new()
  let actual = dae_run_core(
    input,
    options.trace,
    no_callback_trace=hot_pipeline_dae_no_callback_trace(options),
    scalar_validation_work=Some(work),
  )
  assert_true(actual.changed && expected.changed)
  assert_eq(dae_wb_param_count(actual.mod_out, 0), 0)
  assert_eq(dae_wb_param_count(actual.mod_out, 2), 0)
  assert_eq(actual.effects, expected.effects)
  assert_eq(actual.touched, expected.touched)
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  @validate.validate_module(actual.mod_out).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(work.full_gates, 1)
  assert_eq(work.full_bodies, input.code_sec.unwrap().0.length())
  assert_eq(work.partial_bodies, 2)
}

///|
test "scalar validation checks inactive tail calls in every structured child scope" {
  let base = dae_scalar_validation_test_input()
  let dead = [
    @lib.Instruction::unreachable_(),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
  ]
  let block_type = @lib.BlockType::void_()
  let scopes = [
    dead,
    [
      @lib.Instruction::unreachable_(),
      @lib.Instruction::block(block_type, @lib.Expr::new(dead)),
    ],
    [
      @lib.Instruction::unreachable_(),
      @lib.Instruction::loop_(block_type, @lib.Expr::new(dead)),
    ],
    [
      @lib.Instruction::unreachable_(),
      @lib.Instruction::if_(block_type, dead, Some(dead)),
    ],
    [
      @lib.Instruction::unreachable_(),
      @lib.Instruction::try_table(block_type, [], @lib.Expr::new(dead)),
    ],
    [
      @lib.Instruction::unreachable_(),
      @lib.Instruction::try_(block_type, @lib.Expr::new(dead), [
        @lib.LegacyCatch::all(@lib.Expr::new(dead)),
      ]),
    ],
  ]
  let funcs = base.code_sec.unwrap().0.copy()
  let types = base.func_sec.unwrap().0.copy()
  for body in scopes {
    funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)))
    types.push(types[1])
  }
  let input = base
    .with_func_sec(@lib.FuncSec::new(types))
    .with_code_sec(@lib.CodeSec::new(funcs))
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let chain = dae_scalar_validation_test_chain()
  let work = DaeScalarValidationWork::new()
  let mut current = input
  for (target, caller, value) in [(2, 3, 9), (0, 1, 7)] {
    let (graph, plan) = dae_scalar_validation_test_plan(
      current, target, caller, value,
    )
    let reference = dae_apply_rewrite_plan(current, graph, plan)
    let actual = dae_apply_rewrite_plan(
      current,
      graph,
      plan,
      scalar_validation_chain=Some(chain),
      scalar_validation_work=Some(work),
    )
    assert_true(actual.applied && reference.applied)
    assert_eq(actual.effects, reference.effects)
    assert_eq(
      @binary.encode_module(actual.result.mod_out).unwrap(),
      @binary.encode_module(reference.result.mod_out).unwrap(),
    )
    current = actual.result.mod_out
  }
  @validate.validate_module(current).unwrap()
  assert_eq(dae_wb_param_count(current, 0), 0)
  assert_eq(dae_wb_param_count(current, 2), 0)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(work.full_gates, 1)
  assert_eq(work.full_bodies, funcs.length())
  assert_eq(work.partial_bodies, 2 + scopes.length())
}

///|
test "unchanged ref func users keep exact function reference type errors" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #| (type $old (func (param i32) (result i32)))
      #| (type $new (func (result i32)))
      #| (type $observer (func (result (ref $old))))
      #| (func $a (type $old) local.get 0)
      #| (func (export "a") (type $new) i32.const 7 call $a)
      #| (func (type $observer) ref.func $a)
      #| (elem declare func $a))
    ),
  )
  @validate.validate_module(input).unwrap()
  let funcs = input.code_sec.unwrap().0.copy()
  funcs[0] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
  )
  funcs[1] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
  )
  let types = input.func_sec.unwrap().0.copy()
  types[0] = types[1]
  let candidate = input
    .with_func_sec(@lib.FuncSec::new(types))
    .with_code_sec(@lib.CodeSec::new(funcs))
  let saved = @binary.encode_module(input).unwrap()
  let expected = @validate.validate_module(candidate).unwrap_err()
  let chain = dae_scalar_validation_test_chain()
  dae_scalar_validation_check_candidate(chain, input, input).unwrap()
  let actual = dae_scalar_validation_check_candidate(chain, input, candidate).unwrap_err()
  assert_eq(actual, expected)
  assert_eq(
    @validate.validation_error_func_idx(actual),
    Some(@lib.FuncIdx::new(2U)),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_true(chain.checked_source is None)
}

///|
test "scalar validation uses complete fallback for unsupported changes to all module fields" {
  let input = dae_scalar_validation_test_input()
  let (_, plan) = dae_scalar_validation_test_plan(input, 0, 1, 7)
  let base = plan.candidate
  let func_types = base.func_sec.unwrap().0.copy()
  func_types.push(func_types[0])
  let funcs = base.code_sec.unwrap().0.copy()
  funcs.push(funcs[0])
  // Every case changes exactly one of the 19 Module fields. FuncSec/CodeSec
  // length changes are intentionally unsupported, unlike scalar slot updates.
  let candidates = [
    base.with_custom_secs([@lib.CustomSec::new(@lib.Name::new("probe"), b"x")]),
    base.with_name_sec(@lib.NameSec::new()),
    base.with_raw_name_sec_payload(b""),
    base.with_compiler_fact_custom_section(
      @representation.CompilerFactCustomSection::new(
        @representation.OptimizationFactsSec::new(),
      ),
    ),
    base.with_type_sec(@lib.TypeSec::new(base.type_sec.unwrap().0.copy())),
    base.with_import_sec(@lib.ImportSec::new([])),
    base.with_func_annotation_sec(@lib.FuncAnnotationSec::new([])),
    base.with_func_sec(@lib.FuncSec::new(func_types)),
    base.with_table_sec(@lib.TableSec::new([])),
    base.with_mem_sec(@lib.MemSec::new([])),
    base.with_tag_sec(@lib.TagSec::new([])),
    base.with_stringrefs_sec(@lib.StringRefsSec::new([])),
    base.with_global_sec(@lib.GlobalSec::new([])),
    base.with_export_sec(@lib.ExportSec::new(base.export_sec.unwrap().0.copy())),
    base.with_start_sec(@lib.StartSec::new(@lib.FuncIdx::new(0U))),
    base.with_elem_sec(@lib.ElemSec::new([])),
    base.with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(0U))),
    base.with_code_sec(@lib.CodeSec::new(funcs)),
    base.with_data_sec(@lib.DataSec::new([])),
  ]
  assert_eq(candidates.length(), 19)
  let saved = @binary.encode_module(input).unwrap()
  for candidate in candidates {
    let expected = @validate.validate_module(candidate)
    let chain = dae_scalar_validation_test_chain()
    dae_scalar_validation_check_candidate(chain, input, input).unwrap()
    let work = DaeScalarValidationWork::new()
    let actual = dae_scalar_validation_check_candidate(
      chain,
      input,
      candidate,
      work=Some(work),
    )
    assert_eq(actual, expected)
    assert_eq(work.full_gates, 1)
    assert_eq(work.partial_bodies, 0)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "scalar append and in place type changes still transform through the old complete gate" {
  for shared_old_type in [false, true] {
    let input = if shared_old_type {
      pass_test_module_from_wat(
        (
          #|(module
          #| (func $a (param i32 i32) (result i32) local.get 0 local.get 1 i32.add)
          #| (func (export "caller") (param i32) (result i64) local.get 0 i32.const 7 call $a i64.extend_i32_s)
          #| (func (param i32 i32) (result i32) local.get 0))
        ),
      )
    } else {
      pass_test_module_from_wat(
        (
          #|(module
          #| (func $a (param i32 i32) (result i32) local.get 0 local.get 1 i32.add)
          #| (func (export "caller") (param i32) (result i64) local.get 0 i32.const 7 call $a i64.extend_i32_s))
        ),
      )
    }
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let original = dae_collect_original_boundary_snapshot(input)
    let graph = dae_current_boundary_graph_new(input)
    let plan = dae_build_scalar_unused_param_rewrite_plan(
      input,
      original,
      graph,
      0,
      [false, true],
      dae_local_use_for_callee(graph.snapshot.funcs[0], 2, 0, 1),
      1,
      [1],
      materialized_params=Some([
        None,
        Some(@lib.Instruction::i32_const(@lib.I32(7))),
      ]),
    ).unwrap()
    assert_false(
      physical_equal(
        input.type_sec.unwrap().0,
        plan.candidate.type_sec.unwrap().0,
      ),
    )
    let old_count = dae_type_sec_flattened_length(input.type_sec.unwrap())
    let new_count = dae_type_sec_flattened_length(
      plan.candidate.type_sec.unwrap(),
    )
    assert_eq(new_count, old_count + (if shared_old_type { 1 } else { 0 }))
    let reference = dae_apply_rewrite_plan(input, graph, plan)
    let chain = dae_scalar_validation_test_chain()
    dae_scalar_validation_check_candidate(chain, input, input).unwrap()
    let work = DaeScalarValidationWork::new()
    let actual = dae_apply_rewrite_plan(
      input,
      graph,
      plan,
      scalar_validation_chain=Some(chain),
      scalar_validation_work=Some(work),
    )
    assert_true(actual.applied && reference.applied)
    assert_eq(dae_wb_param_count(actual.result.mod_out, 0), 1)
    assert_eq(actual.effects, reference.effects)
    assert_eq(
      @binary.encode_module(actual.result.mod_out).unwrap(),
      @binary.encode_module(reference.result.mod_out).unwrap(),
    )
    @validate.validate_module(actual.result.mod_out).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    assert_eq(work.full_gates, 1)
    assert_eq(work.full_bodies, input.code_sec.unwrap().0.length())
    assert_eq(work.partial_bodies, 0)
  }
}

///|
test "unchanged global table and typed element references retain earlier section errors" {
  let base = pass_test_module_from_wat(
    (
      #|(module
      #| (type $old (func (param i32) (result i32)))
      #| (type $new (func (result i32)))
      #| (func $a (type $old) local.get 0)
      #| (func (export "a") (type $new) i32.const 7 call $a)
      #| (elem declare func $a))
    ),
  )
  let old_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(base.func_sec.unwrap().0[0]),
  )
  let expr = @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0U))])
  let inputs = [
    base.with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::ref_type(old_ref), false),
          expr,
        ),
      ]),
    ),
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
  for input in inputs {
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let funcs = input.code_sec.unwrap().0.copy()
    funcs[0] = @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
    )
    funcs[1] = @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
    )
    let types = input.func_sec.unwrap().0.copy()
    types[0] = types[1]
    let candidate = input
      .with_func_sec(@lib.FuncSec::new(types))
      .with_code_sec(@lib.CodeSec::new(funcs))
    let expected = @validate.validate_module(candidate).unwrap_err()
    let chain = dae_scalar_validation_test_chain()
    dae_scalar_validation_check_candidate(chain, input, input).unwrap()
    let work = DaeScalarValidationWork::new()
    let actual = dae_scalar_validation_check_candidate(
      chain,
      input,
      candidate,
      work=Some(work),
    ).unwrap_err()
    assert_eq(actual, expected)
    assert_true(@validate.validation_error_func_idx(actual) is None)
    assert_true(chain.checked_source is None)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    assert_eq(work.full_gates, 1)
    assert_eq(work.full_bodies, 0)
    assert_eq(work.partial_bodies, 0)
  }
}

///|
test "main core non audited producer between numeric candidates ends the source proof" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #| (func $a (param i32) (result i32) local.get 0 i32.const 1 i32.add)
      #| (func (export "a") (result i32) i32.const 7 call $a)
      #| (func (param i32) (result i32) local.get 0)
      #| (func $b (param i32) (result i32) local.get 0 i32.const 2 i32.add)
      #| (func (export "b") (result i32) i32.const 9 call $b))
    ),
  )
  let saved = @binary.encode_module(input).unwrap()
  let reference_options = HotPipelineOptions::new()
  let expected = dae_run_core(input, reference_options.trace)
  let options = HotPipelineOptions::new()
  let work = DaeScalarValidationWork::new()
  let actual = dae_run_core(
    input,
    options.trace,
    no_callback_trace=hot_pipeline_dae_no_callback_trace(options),
    scalar_validation_work=Some(work),
  )
  assert_true(actual.changed && expected.changed)
  assert_eq(dae_wb_param_count(actual.mod_out, 0), 0)
  assert_eq(dae_wb_param_count(actual.mod_out, 3), 0)
  assert_eq(actual.effects, expected.effects)
  assert_eq(actual.touched, expected.touched)
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  @validate.validate_module(actual.mod_out).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  // The uncalled function between a and b enters the non-audited dead-suffix
  // producer before it reports no change. That call ends source lifetime.
  assert_eq(work.full_gates, 2)
  assert_eq(work.full_bodies, input.code_sec.unwrap().0.length() * 2)
  assert_eq(work.partial_bodies, 0)
}
