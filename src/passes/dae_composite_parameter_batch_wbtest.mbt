///|
test "dae composite literal batch keeps both rewrites in a shared caller" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $left (param i32) (result i32) local.get 0)
      #|  (func $right (param i64) (result i64) local.get 0)
      #|  (func (export "run") (result i64)
      #|    i32.const 7 call $left drop
      #|    i64.const 9 call $right))
    ),
  )
  let before = @binary.encode_module(mod_).unwrap()
  let application = dae_apply_composite_exact_literal_batch(
    dae_collect_original_boundary_snapshot(mod_),
    mod_,
    [],
    false,
    dae_current_boundary_graph_new(mod_),
    [0, 1],
  )
  assert_eq(application.productive_defs, [0, 1])
  assert_eq(application.effects.parameter_changed, [true, true, false])
  assert_eq(application.effects.body_materialized, [true, true, false])
  assert_eq(application.effects.worth_optimizing, [true, true, false])
  assert_eq(application.effects.candidates_produced, 2)
  assert_eq(application.effects.candidates_applied, 2)
  let diagnostics = dae_diagnostics_new()
  dae_diagnostics_record_commit_effects(diagnostics, application.effects)
  dae_diagnostics_record_applied_effects(diagnostics, application.effects)
  assert_eq(diagnostics.candidates_produced, 2)
  assert_eq(diagnostics.candidates_applied, 2)
  assert_eq(dae_diagnostics_reason_count(diagnostics, DaeCandidateProduced), 2)
  assert_eq(dae_diagnostics_reason_count(diagnostics, DaeCandidateApplied), 2)
  let indices = dae_collect_func_type_indices(application.mod_out)
  assert_eq(
    dae_resolve_func_type(application.mod_out, indices, 0),
    Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
  )
  assert_eq(
    dae_resolve_func_type(application.mod_out, indices, 1),
    Some(@lib.FuncType::new([], [@lib.ValType::i64()])),
  )
  match application.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(body)) = funcs[2]
      assert_eq(body, [
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::drop(),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      ])
    }
    None => fail("expected caller code")
  }
  assert_eq(@binary.encode_module(mod_).unwrap(), before)
  match @validate.validate_module(application.mod_out) {
    Ok(_) => ()
    Err(err) => fail("composite output must validate: \{err}")
  }
}

///|
fn dae_partial_then_literal_suffix_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    (
      #|(module
      #|  (func $partial (param i32 i32) (result i32)
      #|    local.get 0 local.get 1 i32.add)
      #|  (func $later (param i32) (result i32)
      #|    local.get 0 i32.const 0 call $partial)
      #|  (func $last (param i64) (result i64) local.get 0)
      #|  (func (export "run") (param i32) (result i64)
      #|    local.get 0 i32.const 0 call $partial drop
      #|    i32.const 7 call $later drop i64.const 9 call $last))
    ),
  )
}

///|
test "dae composite suffix follows a required partial scalar rewrite" {
  let input = dae_partial_then_literal_suffix_fixture()
  let saved = @binary.encode_module(input).unwrap()
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let initial = dae_apply_composite_exact_literal_batch(
    original,
    input,
    [],
    false,
    graph,
    [0, 1, 2],
  )
  // Partial literal masks are intentionally outside composite admission.
  assert_eq(initial.productive_defs, [])
  assert_eq(@binary.encode_module(initial.mod_out).unwrap(), saved)
  let checkpoint = dae_run_exact_literal_candidate_worklist_with_facts(
    input,
    [],
    false,
    [0],
    original=Some(original),
    graph=Some(graph),
    allow_composite_batch=false,
  )
  assert_eq(checkpoint.productive_defs, [0])
  let indices = dae_collect_func_type_indices(checkpoint.mod_out)
  assert_eq(
    dae_resolve_func_type(checkpoint.mod_out, indices, 0),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
  let checkpoint_bytes = @binary.encode_module(checkpoint.mod_out).unwrap()
  let suffix = dae_apply_composite_literal_suffix_after_scalar(
    original,
    checkpoint.mod_out,
    checkpoint.touched,
    checkpoint.changed,
    graph,
    [0, 1, 2],
    0,
  )
  assert_eq(suffix.productive_defs, [1, 2])
  let indices = dae_collect_func_type_indices(suffix.mod_out)
  assert_eq(
    dae_resolve_func_type(suffix.mod_out, indices, 0),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
  assert_eq(
    dae_resolve_func_type(suffix.mod_out, indices, 1),
    Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
  )
  assert_eq(
    dae_resolve_func_type(suffix.mod_out, indices, 2),
    Some(@lib.FuncType::new([], [@lib.ValType::i64()])),
  )
  let scalar = dae_run_exact_literal_candidate_worklist_with_facts(
    input,
    [],
    false,
    [0, 1, 2],
    allow_composite_batch=false,
  )
  assert_eq(suffix.mod_out.code_sec, scalar.mod_out.code_sec)
  assert_eq(suffix.mod_out.type_sec, scalar.mod_out.type_sec)
  assert_eq(suffix.mod_out.func_sec, scalar.mod_out.func_sec)
  assert_eq(
    @binary.encode_module(suffix.mod_out).unwrap(),
    @binary.encode_module(scalar.mod_out).unwrap(),
  )
  let combined = dae_commit_effects_merge(checkpoint.effects, suffix.effects)
  assert_eq(combined.structurally_touched, scalar.effects.structurally_touched)
  assert_eq(combined.parameter_changed, scalar.effects.parameter_changed)
  assert_eq(combined.body_materialized, scalar.effects.body_materialized)
  assert_eq(combined.candidates_produced, scalar.effects.candidates_produced)
  assert_eq(combined.candidates_applied, scalar.effects.candidates_applied)
  assert_eq(
    combined.type_entries_appended,
    scalar.effects.type_entries_appended,
  )
  assert_eq(combined.type_entries_reused, scalar.effects.type_entries_reused)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(
    @binary.encode_module(checkpoint.mod_out).unwrap(),
    checkpoint_bytes,
  )
  @validate.validate_module(suffix.mod_out).unwrap()
}

///|
test "dae literal suffix dispatcher matches scalar order effects and ownership" {
  for candidates in [[0, 1, 2], [0, 2, 1], [0, 1, 1, 2]] {
    let input = dae_partial_then_literal_suffix_fixture()
    let saved = @binary.encode_module(input).unwrap()
    let scalar = dae_run_exact_literal_candidate_worklist_with_facts(
      input,
      [],
      false,
      candidates,
      allow_composite_batch=false,
    )
    let batch = dae_run_exact_literal_candidate_worklist_with_facts(
      input,
      [],
      false,
      candidates,
    )
    assert_eq(batch.productive_defs, scalar.productive_defs)
    assert_eq(batch.mod_out.code_sec, scalar.mod_out.code_sec)
    assert_eq(batch.mod_out.type_sec, scalar.mod_out.type_sec)
    assert_eq(batch.mod_out.func_sec, scalar.mod_out.func_sec)
    assert_eq(
      batch.effects.structurally_touched,
      scalar.effects.structurally_touched,
    )
    assert_eq(batch.effects.parameter_changed, scalar.effects.parameter_changed)
    assert_eq(batch.effects.body_materialized, scalar.effects.body_materialized)
    assert_eq(
      batch.effects.candidates_produced,
      scalar.effects.candidates_produced,
    )
    assert_eq(
      batch.effects.candidates_applied,
      scalar.effects.candidates_applied,
    )
    assert_eq(
      batch.effects.type_entries_appended,
      scalar.effects.type_entries_appended,
    )
    assert_eq(
      batch.effects.type_entries_reused,
      scalar.effects.type_entries_reused,
    )
    assert_eq(
      @binary.encode_module(batch.mod_out).unwrap(),
      @binary.encode_module(scalar.mod_out).unwrap(),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    @validate.validate_module(batch.mod_out).unwrap()
  }
}

///|
test "dae composite literal batch retains a changed callee caller" {
  for
    source in [
      (
        #|(module
        #|  (func $leaf (param i32) (result i32) local.get 0)
        #|  (func $middle (param i32) (result i32)
        #|    local.get 0 drop i32.const 8 call $leaf)
        #|  (func (export "run") (result i32) i32.const 7 call $middle))
      ),
      (
        #|(module
        #|  (func $middle (param i32) (result i32)
        #|    local.get 0 drop i32.const 8 call $leaf)
        #|  (func $leaf (param i32) (result i32) local.get 0)
        #|  (func (export "run") (result i32) i32.const 7 call $middle))
      ),
    ] {
    let mod_ = pass_test_module_from_wat(source)
    let application = dae_apply_composite_exact_literal_batch(
      dae_collect_original_boundary_snapshot(mod_),
      mod_,
      [],
      false,
      dae_current_boundary_graph_new(mod_),
      [0, 1],
    )
    assert_eq(application.productive_defs, [0, 1])
    let indices = dae_collect_func_type_indices(application.mod_out)
    for def_idx in [0, 1] {
      assert_eq(
        dae_resolve_func_type(application.mod_out, indices, def_idx),
        Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
      )
    }
    match @validate.validate_module(application.mod_out) {
      Ok(_) => ()
      Err(err) => fail("changed caller/callee must validate: \{err}")
    }
  }
}

///|
test "dae composite literal batch checks original ownership for every target" {
  let original = pass_test_module_from_wat(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (elem (i32.const 0) func $escaped)
      #|  (func $private (param i32) (result i32) local.get 0)
      #|  (func $escaped (param i32) (result i32) local.get 0)
      #|  (func (export "run") (result i32)
      #|    i32.const 7 call $private drop
      #|    i32.const 8 call $escaped))
    ),
  )
  let current = original.with_elem_sec(@lib.ElemSec::new([]))
  let application = dae_apply_composite_exact_literal_batch(
    dae_collect_original_boundary_snapshot(original),
    current,
    [],
    false,
    dae_current_boundary_graph_new(current),
    [0, 1],
  )
  assert_eq(application.productive_defs, [0])
  let indices = dae_collect_func_type_indices(application.mod_out)
  assert_eq(
    dae_resolve_func_type(application.mod_out, indices, 0),
    Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
  )
  assert_eq(
    dae_resolve_func_type(application.mod_out, indices, 1),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
}

///|
test "dae composite literal batch keeps unsupported literals on the scalar path" {
  for
    source in [
      (
        #|(module
        #|  (func $target (param externref) (result i32)
        #|    local.get 0 ref.is_null)
        #|  (func (export "run") (result i32)
        #|    ref.null extern call $target))
      ),
      (
        #|(module
        #|  (global $value i32 (i32.const 7))
        #|  (func $target (param i32) (result i32) local.get 0)
        #|  (func (export "run") (result i32)
        #|    global.get $value call $target))
      ),
    ] {
    let mod_ = pass_test_module_from_wat(source)
    let original = dae_collect_original_boundary_snapshot(mod_)
    let batch = dae_apply_composite_exact_literal_batch(
      original,
      mod_,
      [],
      false,
      dae_current_boundary_graph_new(mod_),
      [0],
    )
    // These operand kinds are intentionally left to the existing scalar path.
    assert_eq(batch.productive_defs, [])
    let scalar = dae_run_exact_literal_candidate_worklist_with_facts(
      batch.mod_out,
      batch.touched,
      batch.changed,
      [0],
      original=Some(original),
      allow_immutable_global_get=true,
    )
    assert_eq(scalar.productive_defs, [0])
    let indices = dae_collect_func_type_indices(scalar.mod_out)
    assert_eq(
      dae_resolve_func_type(scalar.mod_out, indices, 0),
      Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
    )
    match @validate.validate_module(scalar.mod_out) {
      Ok(_) => ()
      Err(err) => fail("scalar fallback must validate: \{err}")
    }
  }
}

///|
test "dae composite parameter commit rolls back the complete invalid candidate" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $left (param i32) (result i32) local.get 0)
      #|  (func $right (param i32) (result i32) local.get 0)
      #|  (func (export "run") (result i32)
      #|    i32.const 7 call $left drop i32.const 9 call $right))
    ),
  )
  let saved = @binary.encode_module(mod_).unwrap()
  let graph = dae_current_boundary_graph_new(mod_)
  let candidate = dae_try_apply_unread_param_batch(
    mod_,
    active_defs=Some([true, true, false]),
    allow_uniform_params=true,
    boundary_snapshot=Some(graph.snapshot),
  )
  assert_true(candidate.changed)
  let broken_funcs = match candidate.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.copy()
    None => fail("expected candidate code")
  }
  // Invalid output is intentionally unsupported: neither target can commit.
  broken_funcs[1] = @lib.Func::new(
    @lib.Locals::from_types([]),
    @lib.Expr::new([@lib.Instruction::i64_const(@lib.I64(9L))]),
  )
  let application = dae_commit_composite_parameter_batch(
    dae_collect_original_boundary_snapshot(mod_),
    mod_,
    [],
    false,
    graph,
    {
      ..candidate,
      mod_out: candidate.mod_out.with_code_sec(@lib.CodeSec::new(broken_funcs)),
    },
    [true, true, false],
  )
  assert_eq(application.productive_defs, [])
  assert_false(application.changed)
  assert_eq(@binary.encode_module(application.mod_out).unwrap(), saved)
  assert_eq(@binary.encode_module(mod_).unwrap(), saved)
}

///|
test "dae composite literal batch retains calls and traps between literal operands" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "env" "mark" (func $mark (param i32)))
      #|  (memory 1)
      #|  (func $left (param i32) (result i32) local.get 0)
      #|  (func $right (param i32) (result i32) local.get 0)
      #|  (func (export "run") (result i32)
      #|    i32.const 1 call $mark
      #|    i32.const 0 i32.load drop
      #|    i32.const 7 call $left drop
      #|    i32.const 2 call $mark
      #|    i32.const 9 call $right))
    ),
  )
  let batch = dae_apply_composite_exact_literal_batch(
    dae_collect_original_boundary_snapshot(mod_),
    mod_,
    [],
    false,
    dae_current_boundary_graph_new(mod_),
    [0, 1],
  )
  assert_eq(batch.productive_defs, [0, 1])
  let scalar = dae_run_exact_literal_candidate_worklist_with_facts(
    mod_,
    [],
    false,
    [0, 1],
    allow_composite_batch=false,
  )
  assert_eq(
    @binary.encode_module(batch.mod_out).unwrap(),
    @binary.encode_module(scalar.mod_out).unwrap(),
  )
  match batch.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(body)) = funcs[2]
      assert_eq(body[0], @lib.Instruction::i32_const(@lib.I32(1)))
      assert_eq(body[1], @lib.Instruction::call(@lib.FuncIdx::new(0U)))
      assert_true(body[3] is @lib.I32Load(_))
      assert_eq(
        body[body.length() - 2],
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      )
      assert_eq(
        body[body.length() - 1],
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
      )
    }
    None => fail("expected caller code")
  }
}

///|
test "dae literal dispatcher keeps mixed literal work and source ownership" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $first (param i32) (result i32) local.get 0)
      #|  (func $reference (param externref) (result i32)
      #|    local.get 0 ref.is_null)
      #|  (func $last (param i64) (result i64) local.get 0)
      #|  (func (export "run") (result i64)
      #|    i32.const 7 call $first drop
      #|    ref.null extern call $reference drop
      #|    i64.const 9 call $last))
    ),
  )
  let saved = @binary.encode_module(mod_).unwrap()
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let application = dae_run_exact_literal_candidate_worklist_with_facts(
    mod_,
    [],
    false,
    [0, 1, 2],
    original=Some(original),
    graph=Some(graph),
  )
  assert_eq(application.productive_defs, [0, 1, 2])
  assert_eq(application.effects.parameter_changed, [true, true, true, false])
  assert_eq(application.effects.body_materialized, [true, true, true, false])
  assert_eq(application.effects.candidates_produced, 3)
  assert_eq(application.effects.candidates_applied, 3)
  assert_eq(
    graph.snapshot.function_types,
    dae_snapshot_function_types(
      application.mod_out,
      dae_collect_func_type_indices(application.mod_out),
    ),
  )
  match application.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(body)) = funcs[3]
      assert_eq(body, [
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::drop(),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::drop(),
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
      ])
    }
    None => fail("expected mixed literal caller code")
  }
  assert_eq(@binary.encode_module(mod_).unwrap(), saved)
  match @validate.validate_module(application.mod_out) {
    Ok(_) => ()
    Err(err) => fail("mixed literal dispatcher must validate: \{err}")
  }
}

///|
test "dae literal dispatcher retains immutable global and suffix options" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (global $value i32 (i32.const 11))
      #|  (func $literal (param i32) (result i32) local.get 0)
      #|  (func $global (param i32) (result i32) local.get 0)
      #|  (func (export "run") (result i32)
      #|    i32.const 7 call $literal drop
      #|    global.get $value call $global))
    ),
  )
  let application = dae_run_exact_literal_candidate_worklist_with_facts(
    mod_,
    [],
    false,
    [0, 1],
    allow_immutable_global_get=true,
    allow_immediate_i32_suffix_fallback=true,
  )
  assert_eq(application.productive_defs, [0, 1])
  assert_eq(application.effects.parameter_changed, [true, true, false])
  let indices = dae_collect_func_type_indices(application.mod_out)
  for def_idx in [0, 1] {
    assert_eq(
      dae_resolve_func_type(application.mod_out, indices, def_idx),
      Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
    )
  }
  match @validate.validate_module(application.mod_out) {
    Ok(_) => ()
    Err(err) => fail("literal options must retain valid output: \{err}")
  }
}

///|
test "dae literal dispatcher retains mixed direct and forwarded flow constants" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target (param i32 i64) (result i64)
      #|    local.get 0 drop local.get 1)
      #|  (func $a (param i64)
      #|    i32.const 7 local.get 0 call $target drop
      #|    local.get 0 call $b)
      #|  (func $b (param i64) local.get 0 drop)
      #|  (func (export "run") i64.const 11 call $a))
    ),
  )
  let scalar = dae_run_exact_literal_candidate_worklist_with_facts(
    mod_,
    [],
    false,
    [0, 1, 2],
    allow_composite_batch=false,
  )
  let batch = dae_run_exact_literal_candidate_worklist_with_facts(
    mod_,
    [],
    false,
    [0, 1, 2],
  )
  assert_true(scalar.productive_defs.contains(0))
  let indices = dae_collect_func_type_indices(scalar.mod_out)
  assert_eq(
    dae_resolve_func_type(scalar.mod_out, indices, 0),
    Some(@lib.FuncType::new([], [@lib.ValType::i64()])),
  )
  assert_eq(batch.productive_defs, scalar.productive_defs)
  assert_eq(batch.mod_out.code_sec, scalar.mod_out.code_sec)
  assert_eq(batch.mod_out.type_sec, scalar.mod_out.type_sec)
  assert_eq(batch.mod_out.func_sec, scalar.mod_out.func_sec)
  assert_eq(
    batch.effects.type_entries_reused,
    scalar.effects.type_entries_reused,
  )
  assert_eq(
    batch.effects.type_entries_appended,
    scalar.effects.type_entries_appended,
  )
  assert_eq(
    @binary.encode_module(batch.mod_out).unwrap(),
    @binary.encode_module(scalar.mod_out).unwrap(),
  )
}

///|
test "dae literal dispatcher retains earlier residual rewrites of later batch callers" {
  for
    source in [
      (
        #|(module
        #|  (func $reference (param externref) (result i32)
        #|    local.get 0 ref.is_null)
        #|  (func $later (param i32) (result i64)
        #|    local.get 0 drop ref.null extern call $reference i64.extend_i32_s)
        #|  (func (export "run") i32.const 7 call $later drop))
      ),
      (
        #|(module
        #|  (global $value i32 (i32.const 11))
        #|  (func $global (param i32) (result i32) local.get 0)
        #|  (func $later (param i32) (result i64)
        #|    local.get 0 drop global.get $value call $global i64.extend_i32_s)
        #|  (func (export "run") i32.const 7 call $later drop))
      ),
    ] {
    let mod_ = pass_test_module_from_wat(source)
    let saved = @binary.encode_module(mod_).unwrap()
    let scalar = dae_run_exact_literal_candidate_worklist_with_facts(
      mod_,
      [],
      false,
      [0, 1],
      allow_composite_batch=false,
      allow_immutable_global_get=true,
      allow_immediate_i32_suffix_fallback=true,
    )
    let batch = dae_run_exact_literal_candidate_worklist_with_facts(
      mod_,
      [],
      false,
      [0, 1],
      allow_immutable_global_get=true,
      allow_immediate_i32_suffix_fallback=true,
    )
    assert_eq(batch.productive_defs, [0, 1])
    assert_eq(batch.productive_defs, scalar.productive_defs)
    assert_eq(
      @binary.encode_module(batch.mod_out).unwrap(),
      @binary.encode_module(scalar.mod_out).unwrap(),
    )
    assert_eq(@binary.encode_module(mod_).unwrap(), saved)
  }
}

///|
test "dae literal dispatcher preserves reverse and repeated candidate order" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $first (param i32) (result i32) local.get 0)
      #|  (func $second (param i64) (result i64) local.get 0)
      #|  (func (export "run")
      #|    i32.const 7 call $first drop
      #|    i64.const 9 call $second drop))
    ),
  )
  for candidates in [[1, 0], [0, 0, 1]] {
    let scalar = dae_run_exact_literal_candidate_worklist_with_facts(
      mod_,
      [],
      false,
      candidates,
      allow_composite_batch=false,
    )
    let batch = dae_run_exact_literal_candidate_worklist_with_facts(
      mod_,
      [],
      false,
      candidates,
    )
    assert_eq(
      batch.productive_defs,
      if candidates[0] == 1 {
        [1, 0]
      } else {
        [0, 1]
      },
    )
    assert_eq(batch.productive_defs, scalar.productive_defs)
    assert_eq(batch.effects.candidates_applied, 2)
    assert_eq(
      @binary.encode_module(batch.mod_out).unwrap(),
      @binary.encode_module(scalar.mod_out).unwrap(),
    )
  }
}

///|
test "dae literal dispatcher keeps scalar dynamic equality cleanup" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (memory 1)
      #|  (func $target (param i32) (result i32)
      #|    local.get 0 drop
      #|    i32.const 0 i32.load
      #|    i32.const 0 i32.eq
      #|    if (result i32)
      #|      i32.const 3
      #|    else
      #|      i32.const 4
      #|    end)
      #|  (func $other (param i64) (result i64) local.get 0)
      #|  (func (export "run")
      #|    i32.const 7 call $target drop
      #|    i64.const 9 call $other drop))
    ),
  )
  let saved = @binary.encode_module(mod_).unwrap()
  let scalar = dae_run_exact_literal_candidate_worklist_with_facts(
    mod_,
    [],
    false,
    [0, 1],
    allow_composite_batch=false,
  )
  let batch = dae_run_exact_literal_candidate_worklist_with_facts(
    mod_,
    [],
    false,
    [0, 1],
  )
  assert_eq(batch.productive_defs, scalar.productive_defs)
  let scalar_body = match scalar.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs[0]
    None => fail("expected scalar target code")
  }
  let batch_body = match batch.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs[0]
    None => fail("expected composite target code")
  }
  assert_eq(batch_body, scalar_body)
  assert_eq(batch.mod_out.code_sec, scalar.mod_out.code_sec)
  assert_eq(batch.mod_out.type_sec, scalar.mod_out.type_sec)
  assert_eq(batch.mod_out.func_sec, scalar.mod_out.func_sec)
  assert_eq(
    batch.effects.type_entries_reused,
    scalar.effects.type_entries_reused,
  )
  assert_eq(
    batch.effects.type_entries_appended,
    scalar.effects.type_entries_appended,
  )
  assert_eq(
    @binary.encode_module(batch.mod_out).unwrap(),
    @binary.encode_module(scalar.mod_out).unwrap(),
  )
  assert_eq(@binary.encode_module(mod_).unwrap(), saved)
}

///|
test "dae composite literal batch retains untouched NaN function ownership" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $first (param i32) (result i32) local.get 0)
      #|  (func $second (param i64) (result i64) local.get 0)
      #|  (func (export "nan") (result f64) f64.const nan)
      #|  (func (export "run")
      #|    i32.const 7 call $first drop
      #|    i64.const 9 call $second drop))
    ),
  )
  let graph = dae_current_boundary_graph_new(mod_)
  let saved_nan = graph.snapshot.funcs[2]
  let batch = dae_apply_composite_exact_literal_batch(
    dae_collect_original_boundary_snapshot(mod_),
    mod_,
    [],
    false,
    graph,
    [0, 1],
  )
  assert_eq(batch.productive_defs, [0, 1])
  assert_false(batch.effects.structurally_touched[2])
  assert_false(batch.touched[2])
  match batch.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      assert_true(dae_snapshot_func_unchanged(saved_nan, funcs[2]))
    None => fail("expected retained NaN function")
  }
}
