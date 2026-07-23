///|
fn dae_wbtest_call_summary_fixture() -> @lib.Module {
  let void_type = @lib.TypeIdx::new(0U)
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([void_type, void_type, void_type]))
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("entry"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          @lib.Instruction::call(@lib.FuncIdx::new(2U)),
          @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        ]),
      ),
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
    ]),
  )
}

///|
fn dae_original_result_removal_prune_row(
  def_idx : Int,
  original_param_counts : Array[Int],
  original_call_counts : Array[Int],
  original_active_nonself_call_counts : Array[Int],
  original_active_parameterized_nonself_call_counts : Array[Int],
  original_active_parameterized_result_nonself_call_counts : Array[Int],
  original_nonself_undropped_call_counts : Array[Int],
  original_self_call_counts : Array[Int],
  original_escaped_dead_suffix_call_counts : Array[Int],
  original_dead_suffix_undropped_self_calls : Array[Bool],
  original_dead_suffix_dropped_self_calls : Array[Bool],
  original_dead_suffix_block_undropped_self_calls : Array[Bool],
  original_dead_suffix_same_self_result_operand_calls : Array[Bool],
  original_dead_suffix_dropped_self_call_full_param_forwards : Array[Bool],
  original_dead_suffix_dropped_escaped_result_calls : Array[Bool],
  original_dead_suffix_dropped_earlier_result_calls : Array[Bool],
  original_later_dead_suffix_dropped_call_counts : Array[Int],
  original_dead_suffix_mutual_calls : Array[Bool],
  original_private_result_dead_suffix_call_counts : Array[Int],
  original_dead_suffix_result_other_calls : Array[Bool],
  original_dead_suffix_dropped_calls_from_no_param_result_callers : Array[Int],
  original_dead_suffix_mixed_dropped_undropped_call_counts : Array[Int],
) -> DaeOriginalResultRemovalPruneRow {
  {
    param_count: dae_original_int_fact_at(original_param_counts, def_idx),
    call_count: dae_original_int_fact_at(original_call_counts, def_idx),
    active_nonself_call_count: dae_original_int_fact_at(
      original_active_nonself_call_counts, def_idx,
    ),
    active_parameterized_nonself_call_count: dae_original_int_fact_at(
      original_active_parameterized_nonself_call_counts, def_idx,
    ),
    active_parameterized_result_nonself_call_count: dae_original_int_fact_at(
      original_active_parameterized_result_nonself_call_counts, def_idx,
    ),
    nonself_undropped_call_count: dae_original_int_fact_at(
      original_nonself_undropped_call_counts, def_idx,
    ),
    self_call_count: dae_original_int_fact_at(
      original_self_call_counts, def_idx,
    ),
    escaped_dead_suffix_call_count: dae_original_int_fact_at(
      original_escaped_dead_suffix_call_counts, def_idx,
    ),
    dead_suffix_undropped_self_call: dae_original_bool_fact_at(
      original_dead_suffix_undropped_self_calls, def_idx,
    ),
    dead_suffix_dropped_self_call: dae_original_bool_fact_at(
      original_dead_suffix_dropped_self_calls, def_idx,
    ),
    dead_suffix_block_undropped_self_call: dae_original_bool_fact_at(
      original_dead_suffix_block_undropped_self_calls, def_idx,
    ),
    dead_suffix_same_self_result_operand_call: dae_original_bool_fact_at(
      original_dead_suffix_same_self_result_operand_calls, def_idx,
    ),
    dead_suffix_dropped_self_call_full_param_forward: dae_original_bool_fact_at(
      original_dead_suffix_dropped_self_call_full_param_forwards, def_idx,
    ),
    dead_suffix_dropped_escaped_result_call: dae_original_bool_fact_at(
      original_dead_suffix_dropped_escaped_result_calls, def_idx,
    ),
    dead_suffix_dropped_earlier_result_call: dae_original_bool_fact_at(
      original_dead_suffix_dropped_earlier_result_calls, def_idx,
    ),
    later_dead_suffix_dropped_call_count: dae_original_int_fact_at(
      original_later_dead_suffix_dropped_call_counts, def_idx,
    ),
    dead_suffix_mutual_call: dae_original_bool_fact_at(
      original_dead_suffix_mutual_calls, def_idx,
    ),
    private_result_dead_suffix_call_count: dae_original_int_fact_at(
      original_private_result_dead_suffix_call_counts, def_idx,
    ),
    dead_suffix_result_other_call: dae_original_bool_fact_at(
      original_dead_suffix_result_other_calls, def_idx,
    ),
    dead_suffix_dropped_calls_from_no_param_result_caller: dae_original_int_fact_at(
      original_dead_suffix_dropped_calls_from_no_param_result_callers, def_idx,
    ),
    dead_suffix_mixed_dropped_undropped_call_count: dae_original_int_fact_at(
      original_dead_suffix_mixed_dropped_undropped_call_counts, def_idx,
    ),
  }
}

///|
test "dae core result application installs changes and preserves scheduler state" {
  let current = dae_wbtest_call_summary_fixture()
  let rewritten = @lib.Module::new()
  let changed_result : DaePassResult = {
    mod_out: rewritten,
    touched: [false, true, true],
    changed: true,
    primary_def: 2,
  }
  let adopted = dae_apply_core_result(current, [], false, changed_result)
  assert_true(adopted.applied)
  assert_eq(adopted.mod_out, rewritten)
  assert_eq(adopted.touched, [false, true, true])
  assert_true(adopted.changed)
  assert_eq(adopted.primary_def, 2)
  let merged = dae_apply_core_result(
    current,
    [true, false, false],
    true,
    changed_result,
  )
  assert_true(merged.applied)
  assert_eq(merged.mod_out, rewritten)
  assert_eq(merged.touched, [true, true, true])
  assert_true(merged.changed)
  assert_eq(merged.primary_def, 2)
  let no_change_result : DaePassResult = {
    mod_out: rewritten,
    touched: [false, true, true],
    changed: false,
    primary_def: 2,
  }
  let preserved = dae_apply_core_result(
    current,
    [true, false, false],
    true,
    no_change_result,
  )
  assert_false(preserved.applied)
  assert_eq(preserved.mod_out, current)
  assert_eq(preserved.touched, [true, false, false])
  assert_true(preserved.changed)
  assert_eq(preserved.primary_def, -1)
}

///|
test "dae cleanup result application preserves scheduler touched ownership" {
  let current = dae_wbtest_call_summary_fixture()
  let rewritten = @lib.Module::new()
  let cleanup_result : DaePassResult = {
    mod_out: rewritten,
    touched: [false, true, true],
    changed: true,
    primary_def: 2,
  }
  let applied = dae_apply_cleanup_result_preserving_touched(
    current,
    [true, false, false],
    false,
    cleanup_result,
  )
  assert_true(applied.applied)
  assert_eq(applied.mod_out, rewritten)
  assert_eq(applied.touched, [true, false, false])
  assert_true(applied.changed)
  assert_eq(applied.primary_def, 2)
  let no_change_result : DaePassResult = {
    mod_out: rewritten,
    touched: [false, true, true],
    changed: false,
    primary_def: 2,
  }
  let preserved = dae_apply_cleanup_result_preserving_touched(
    current,
    applied.touched,
    true,
    no_change_result,
  )
  assert_false(preserved.applied)
  assert_eq(preserved.mod_out, current)
  assert_eq(preserved.touched, [true, false, false])
  assert_true(preserved.changed)
  assert_eq(preserved.primary_def, -1)
}

///|
test "dae selected core result application clears the consumed selection" {
  let current = dae_wbtest_call_summary_fixture()
  let rewritten = @lib.Module::new()
  let selected = [true, true, false]
  let changed_result : DaePassResult = {
    mod_out: rewritten,
    touched: [false, true, false],
    changed: true,
    primary_def: 1,
  }
  let applied = dae_apply_selected_core_result(
    current,
    [true, false, false],
    false,
    selected,
    1,
    changed_result,
  )
  assert_eq(selected, [true, false, false])
  assert_true(applied.applied)
  assert_eq(applied.mod_out, rewritten)
  assert_eq(applied.touched, [true, true, false])
  assert_true(applied.changed)
  assert_eq(applied.primary_def, 1)
  selected[2] = true
  let no_change_result : DaePassResult = {
    mod_out: rewritten,
    touched: [false, false, true],
    changed: false,
    primary_def: 2,
  }
  let preserved = dae_apply_selected_core_result(
    current,
    applied.touched,
    true,
    selected,
    2,
    no_change_result,
  )
  assert_eq(selected, [true, false, false])
  assert_false(preserved.applied)
  assert_eq(preserved.mod_out, current)
  assert_eq(preserved.touched, [true, true, false])
  assert_true(preserved.changed)
  assert_eq(preserved.primary_def, -1)
}

///|
test "dae singleton-selected core rewrite owns selection and result application" {
  let current = dae_wbtest_call_summary_fixture()
  let rewritten = @lib.Module::new()
  let selected = [true, false, true]
  let observed_current : Array[Bool] = []
  let observed_selection : Array[Bool] = []
  let productive_rewrite = fn(
    active : @lib.Module,
    active_selected : Array[Bool],
  ) -> DaePassResult {
    observed_current.push(active == current)
    observed_selection.push(active_selected[1])
    {
      mod_out: rewritten,
      touched: [false, true, false],
      changed: true,
      primary_def: 1,
    }
  }
  let applied = dae_run_singleton_selected_core_rewrite(
    current,
    [true, false, false],
    false,
    selected,
    1,
    productive_rewrite,
  )
  assert_eq(observed_current, [true])
  assert_eq(observed_selection, [true])
  assert_eq(selected, [true, false, true])
  assert_true(applied.applied)
  assert_eq(applied.mod_out, rewritten)
  assert_eq(applied.touched, [true, true, false])
  assert_true(applied.changed)
  assert_eq(applied.primary_def, 1)
  let no_change_rewrite = fn(
    active : @lib.Module,
    active_selected : Array[Bool],
  ) -> DaePassResult {
    observed_current.push(active == current)
    observed_selection.push(active_selected[1])
    { mod_out: rewritten, touched: [], changed: false, primary_def: -1 }
  }
  let preserved = dae_run_singleton_selected_core_rewrite(
    current,
    applied.touched,
    true,
    selected,
    1,
    no_change_rewrite,
  )
  assert_eq(observed_current, [true, true])
  assert_eq(observed_selection, [true, true])
  assert_eq(selected, [true, false, true])
  assert_false(preserved.applied)
  assert_eq(preserved.mod_out, current)
  assert_eq(preserved.touched, [true, true, false])
  assert_true(preserved.changed)
  assert_eq(preserved.primary_def, -1)
}

///|
test "dae bounded singleton-selected core rewrite stops after first no-op" {
  let current = dae_wbtest_call_summary_fixture()
  let rewritten_once = @lib.Module::new().with_data_cnt_sec(
    @lib.DataCntSec::new(@lib.U32(0U)),
  )
  let rewritten_twice = @lib.Module::new().with_data_cnt_sec(
    @lib.DataCntSec::new(@lib.U32(1U)),
  )
  let selected = [true, false, true]
  let mut producer_calls = 0
  let observed_active_modules : Array[Bool] = []
  let observed_selection : Array[Bool] = []
  let productive_iterations : Array[Int] = []
  let productive_primary_defs : Array[Int] = []
  let rewrite = fn(
    active : @lib.Module,
    active_selected : Array[Bool],
  ) -> DaePassResult {
    observed_selection.push(active_selected[1])
    producer_calls += 1
    if producer_calls == 1 {
      observed_active_modules.push(active == current)
      return {
        mod_out: rewritten_once,
        touched: [false, true, false],
        changed: true,
        primary_def: 1,
      }
    }
    if producer_calls == 2 {
      observed_active_modules.push(active == rewritten_once)
      return {
        mod_out: rewritten_twice,
        touched: [false, false, true],
        changed: true,
        primary_def: 2,
      }
    }
    observed_active_modules.push(active == rewritten_twice)
    { mod_out: active, touched: [], changed: false, primary_def: -1 }
  }
  let on_applied = fn(
    iteration : Int,
    application : DaeCoreResultApplication,
  ) -> Unit {
    productive_iterations.push(iteration)
    productive_primary_defs.push(application.primary_def)
  }
  let application = dae_run_bounded_singleton_selected_core_rewrite(
    current,
    [true, false, false],
    false,
    selected,
    1,
    8,
    rewrite,
    on_applied,
  )
  assert_eq(producer_calls, 3)
  assert_eq(observed_active_modules, [true, true, true])
  assert_eq(observed_selection, [true, true, true])
  assert_eq(productive_iterations, [0, 1])
  assert_eq(productive_primary_defs, [1, 2])
  assert_eq(selected, [true, false, true])
  assert_eq(application.mod_out, rewritten_twice)
  assert_eq(application.touched, [true, true, true])
  assert_true(application.changed)
  assert_false(application.applied)
  assert_eq(application.primary_def, -1)
}

///|
test "dae primary-selected core result application clears only the applied primary" {
  let current = dae_wbtest_call_summary_fixture()
  let rewritten = @lib.Module::new()
  let selected = [true, true, true]
  let changed_result : DaePassResult = {
    mod_out: rewritten,
    touched: [false, true, false],
    changed: true,
    primary_def: 1,
  }
  let applied = dae_apply_primary_selected_core_result(
    current,
    [true, false, false],
    false,
    selected,
    changed_result,
  )
  assert_eq(selected, [true, false, true])
  assert_true(applied.applied)
  assert_eq(applied.mod_out, rewritten)
  assert_eq(applied.touched, [true, true, false])
  assert_true(applied.changed)
  assert_eq(applied.primary_def, 1)
  let no_change_result : DaePassResult = {
    mod_out: rewritten,
    touched: [false, false, true],
    changed: false,
    primary_def: 2,
  }
  let preserved = dae_apply_primary_selected_core_result(
    current,
    applied.touched,
    true,
    selected,
    no_change_result,
  )
  assert_eq(selected, [true, false, true])
  assert_false(preserved.applied)
  assert_eq(preserved.mod_out, current)
  assert_eq(preserved.touched, [true, true, false])
  assert_true(preserved.changed)
  assert_eq(preserved.primary_def, -1)
}

///|
test "dae selected function rewrite applies locals and body at the chosen boundary" {
  let current = dae_wbtest_call_summary_fixture().with_name_sec(
    @lib.NameSec::new(module_name=Some(@lib.Name::from_string("dae-fixture"))),
  )
  let selected = [false, true, true]
  let rewrite_func = fn(
    func : @lib.Func,
    type_sec : @lib.TypeSec?,
  ) -> @lib.Func? {
    if type_sec is None {
      return None
    }
    let @lib.Func(_, @lib.Expr(body)) = func
    let rewritten_body = body.copy()
    rewritten_body.push(@lib.Instruction::nop())
    Some(
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new(rewritten_body),
      ),
    )
  }
  let skipped = dae_try_apply_selected_def_func_rewrite_once(
    current, selected, 0, rewrite_func,
  )
  assert_false(skipped.changed)
  assert_eq(skipped.mod_out, current)
  assert_eq(skipped.touched, [])
  assert_eq(skipped.primary_def, -1)
  let applied = dae_try_apply_selected_def_func_rewrite_once(
    current, selected, 1, rewrite_func,
  )
  assert_true(applied.changed)
  assert_eq(applied.touched, [false, true, false])
  assert_eq(applied.primary_def, 1)
  @debug.assert_eq(applied.mod_out.name_sec, None)
  match applied.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      assert_eq(
        funcs[0],
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
        ),
      )
      assert_eq(
        funcs[1],
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::nop(),
          ]),
        ),
      )
      assert_eq(
        funcs[2],
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      )
    }
    None =>
      fail("expected selected function rewrite to retain the code section")
  }
  let unchanged = dae_try_apply_selected_def_func_rewrite_once(
    current,
    selected,
    2,
    fn(func, _) { Some(func) },
  )
  assert_false(unchanged.changed)
  assert_eq(unchanged.mod_out, current)
  assert_eq(unchanged.touched, [])
  assert_eq(unchanged.primary_def, -1)
}

///|
test "dae selected typed function rewrite resolves the current signature" {
  let current = dae_wbtest_call_summary_fixture().with_name_sec(
    @lib.NameSec::new(module_name=Some(@lib.Name::from_string("dae-fixture"))),
  )
  let selected = [false, true, true]
  let mut visits = 0
  let mut saw_current_signature = false
  let mut saw_current_types = false
  let rewrite_func = fn(
    func : @lib.Func,
    func_type : @lib.FuncType,
    type_sec : @lib.TypeSec?,
  ) -> @lib.Func? {
    visits += 1
    saw_current_signature = func_type == @lib.FuncType::new([], [])
    saw_current_types = type_sec is Some(_)
    if !saw_current_signature || !saw_current_types {
      return None
    }
    let @lib.Func(_, @lib.Expr(body)) = func
    let rewritten_body = body.copy()
    rewritten_body.push(@lib.Instruction::nop())
    Some(
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i64()]),
        @lib.Expr::new(rewritten_body),
      ),
    )
  }
  let skipped = dae_try_apply_selected_def_typed_func_rewrite_once(
    current, selected, 0, rewrite_func,
  )
  assert_false(skipped.changed)
  assert_eq(visits, 0)
  let applied = dae_try_apply_selected_def_typed_func_rewrite_once(
    current, selected, 1, rewrite_func,
  )
  assert_eq(visits, 1)
  assert_true(saw_current_signature)
  assert_true(saw_current_types)
  assert_true(applied.changed)
  assert_eq(applied.touched, [false, true, false])
  assert_eq(applied.primary_def, 1)
  @debug.assert_eq(applied.mod_out.name_sec, None)
  match applied.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      assert_eq(
        funcs[0],
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
        ),
      )
      assert_eq(
        funcs[1],
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i64()]),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::nop(),
          ]),
        ),
      )
      assert_eq(
        funcs[2],
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      )
    }
    None => fail("expected selected typed function rewrite")
  }
}

///|
test "dae selected FuncSec rewrite reuses the current signature boundary" {
  let void_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let current = dae_wbtest_call_summary_fixture()
    .with_type_sec(@lib.TypeSec::new([void_type, void_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(1U),
        @lib.TypeIdx::new(0U),
      ]),
    )
    .with_name_sec(
      @lib.NameSec::new(module_name=Some(@lib.Name::from_string("dae-fixture"))),
    )
  let selected = [false, true, true]
  let mut visits = 0
  let rewrite_func = fn(
    func : @lib.Func,
    func_type : @lib.FuncType,
    type_sec : @lib.TypeSec,
  ) -> @lib.Func? {
    visits += 1
    if func_type != @lib.FuncType::new([], []) ||
      type_sec != @lib.TypeSec::new([void_type, void_type]) {
      return None
    }
    let @lib.Func(_, @lib.Expr(body)) = func
    let rewritten_body = body.copy()
    rewritten_body.push(@lib.Instruction::nop())
    Some(
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new(rewritten_body),
      ),
    )
  }
  let skipped = dae_try_apply_selected_def_funcsec_func_rewrite_once(
    current, selected, 0, rewrite_func,
  )
  assert_false(skipped.changed)
  assert_eq(skipped.mod_out, current)
  assert_eq(visits, 0)
  let applied = dae_try_apply_selected_def_funcsec_func_rewrite_once(
    current, selected, 1, rewrite_func,
  )
  assert_eq(visits, 1)
  assert_true(applied.changed)
  assert_eq(applied.touched, [false, true, false])
  assert_eq(applied.primary_def, 1)
  @debug.assert_eq(applied.mod_out.name_sec, None)
  match applied.mod_out.func_sec {
    Some(@lib.FuncSec(type_idxs)) =>
      assert_eq(type_idxs, [
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(0U),
      ])
    None =>
      fail("expected selected FuncSec rewrite to retain the function section")
  }
  match applied.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      assert_eq(
        funcs[0],
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
        ),
      )
      assert_eq(
        funcs[1],
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::nop(),
          ]),
        ),
      )
      assert_eq(
        funcs[2],
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      )
    }
    None => fail("expected selected FuncSec rewrite to retain the code section")
  }
  let unchanged = dae_try_apply_selected_def_funcsec_func_rewrite_once(
    current,
    selected,
    2,
    fn(func, _, _) { Some(func) },
  )
  assert_false(unchanged.changed)
  assert_eq(unchanged.mod_out, current)
  assert_eq(unchanged.touched, [])
  assert_eq(unchanged.primary_def, -1)
}

///|
test "dae first productive selected function rewrite preserves scan order" {
  let current = dae_wbtest_call_summary_fixture().with_name_sec(
    @lib.NameSec::new(module_name=Some(@lib.Name::from_string("dae-fixture"))),
  )
  let selected = [true, true, true]
  let visited : Array[Int] = []
  let rewrite_func = fn(
    func : @lib.Func,
    def_idx : Int,
    type_sec : @lib.TypeSec?,
  ) -> @lib.Func? {
    visited.push(def_idx)
    if type_sec is None || def_idx == 0 {
      return None
    }
    let @lib.Func(_, @lib.Expr(body)) = func
    let rewritten_body = body.copy()
    rewritten_body.push(@lib.Instruction::nop())
    Some(
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new(rewritten_body),
      ),
    )
  }
  let applied = dae_try_apply_first_selected_func_rewrite_once(
    current, selected, rewrite_func,
  )
  assert_eq(visited, [0, 1])
  assert_true(applied.changed)
  assert_eq(applied.touched, [false, true, false])
  assert_eq(applied.primary_def, 1)
  @debug.assert_eq(applied.mod_out.name_sec, None)
  match applied.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      assert_eq(
        funcs[0],
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
        ),
      )
      assert_eq(
        funcs[1],
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::nop(),
          ]),
        ),
      )
      assert_eq(
        funcs[2],
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      )
    }
    None => fail("expected first productive selected function rewrite")
  }
}

///|
test "dae selected Func288 return wrapper rejects an unselected boundary" {
  let funcs = Array::make(
    289,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  )
  let original = @lib.Func::new(
    @lib.Locals::single(3U, @lib.ValType::i32()),
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        ]),
      ),
      @lib.Instruction::return_(),
    ]),
  )
  funcs[288] = original
  let current = @lib.Module::new()
    .with_code_sec(@lib.CodeSec::new(funcs))
    .with_name_sec(
      @lib.NameSec::new(module_name=Some(@lib.Name::from_string("dae-fixture"))),
    )
  let selected = Array::make(289, false)
  let skipped = dae_try_flatten_selected_func288_return_wrapper_once(
    current, selected,
  )
  assert_false(skipped.changed)
  assert_eq(skipped.mod_out, current)
  assert_eq(skipped.touched, [])
  assert_eq(skipped.primary_def, -1)
  selected[288] = true
  let applied = dae_try_flatten_selected_func288_return_wrapper_once(
    current, selected,
  )
  assert_true(applied.changed)
  assert_eq(applied.touched, Array::make(288, false) + [true])
  assert_eq(applied.primary_def, 288)
  @debug.assert_eq(applied.mod_out.name_sec, None)
  match applied.mod_out.code_sec {
    Some(@lib.CodeSec(rewritten_funcs)) => {
      assert_eq(rewritten_funcs.length(), 289)
      assert_eq(
        rewritten_funcs[0],
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      )
      assert_eq(
        rewritten_funcs[288],
        @lib.Func::new(
          @lib.Locals::single(3U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::return_(),
          ]),
        ),
      )
    }
    None => fail("expected selected Func288 return-wrapper rewrite")
  }
}

///|
test "dae selected body rewrite applies only the chosen function boundary" {
  let current = dae_wbtest_call_summary_fixture().with_name_sec(
    @lib.NameSec::new(module_name=Some(@lib.Name::from_string("dae-fixture"))),
  )
  let selected = [false, true, true]
  let rewrite_body = fn(
    body : Array[@lib.Instruction],
    type_sec : @lib.TypeSec?,
  ) -> Array[@lib.Instruction]? {
    if type_sec is None {
      return None
    }
    let rewritten = body.copy()
    rewritten.push(@lib.Instruction::nop())
    Some(rewritten)
  }
  let skipped = dae_try_apply_selected_def_body_rewrite_once(
    current, selected, 0, rewrite_body,
  )
  assert_false(skipped.changed)
  assert_eq(skipped.mod_out, current)
  assert_eq(skipped.touched, [])
  assert_eq(skipped.primary_def, -1)
  let applied = dae_try_apply_selected_def_body_rewrite_once(
    current, selected, 1, rewrite_body,
  )
  assert_true(applied.changed)
  assert_eq(applied.touched, [false, true, false])
  assert_eq(applied.primary_def, 1)
  @debug.assert_eq(applied.mod_out.name_sec, None)
  match applied.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(first_body)) = funcs[0]
      let @lib.Func(_, @lib.Expr(rewritten_body)) = funcs[1]
      let @lib.Func(_, @lib.Expr(last_body)) = funcs[2]
      assert_eq(first_body, [@lib.Instruction::call(@lib.FuncIdx::new(1U))])
      assert_eq(rewritten_body, [
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::nop(),
      ])
      assert_eq(last_body, [])
    }
    None => fail("expected selected body rewrite to retain the code section")
  }
  let unchanged = dae_try_apply_selected_def_body_rewrite_once(
    current,
    selected,
    2,
    fn(body, _) { Some(body) },
  )
  assert_false(unchanged.changed)
  assert_eq(unchanged.mod_out, current)
  assert_eq(unchanged.touched, [])
  assert_eq(unchanged.primary_def, -1)
}

///|
test "dae call boundary facts expose reusable forwarding gates" {
  let facts = dae_make_call_boundary_facts(
    [false, true, false],
    [false, false, true],
    [[1], [0, 2], []],
  )
  assert_true(dae_call_boundary_allows_forwarding(facts, 0))
  assert_false(dae_call_boundary_allows_forwarding(facts, 1))
  assert_false(dae_call_boundary_allows_forwarding(facts, 2))
  assert_eq(dae_call_boundary_direct_callers(facts, 1), [0, 2])
  assert_eq(dae_call_boundary_direct_callers(facts, 4), [])
}

///|
test "dae target callsite evidence centralizes direct and return-call matching" {
  let direct = @lib.Instruction::call(@lib.FuncIdx::new(2U))
  let tail = @lib.Instruction::return_call(@lib.FuncIdx::new(2U))
  match dae_target_callsite_evidence(direct, 2, DaeTargetDirectCallOnly) {
    Some(evidence) => {
      assert_eq(evidence.callee_abs, 2)
      assert_false(evidence.is_return_call)
    }
    None => fail("expected direct-call target evidence")
  }
  match dae_target_callsite_evidence(tail, 2, DaeTargetDirectCallOnly) {
    Some(_) => fail("direct-only target evidence should reject return_call")
    None => ()
  }
  match dae_target_callsite_evidence(tail, 2, DaeTargetDirectOrReturnCall) {
    Some(evidence) => {
      assert_eq(evidence.callee_abs, 2)
      assert_true(evidence.is_return_call)
    }
    None => fail("expected return-call target evidence in tail-aware mode")
  }
  match dae_target_callsite_evidence(direct, 3, DaeTargetDirectOrReturnCall) {
    Some(_) => fail("wrong callee must not match target evidence")
    None => ()
  }
  match dae_target_callsite_evidence(direct, -1, DaeTargetDirectOrReturnCall) {
    Some(_) => fail("negative callee must not match target evidence")
    None => ()
  }
}

///|
test "dae adjacent param forward evidence centralizes operand ranges" {
  let get0 = @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
  let get1 = @lib.Instruction::local_get(@lib.LocalIdx::new(1U))
  let call4 = @lib.Instruction::call(@lib.FuncIdx::new(4U))
  let valid = [@lib.Instruction::i32_const(@lib.I32(9)), get0, get1, call4]
  match dae_adjacent_param_forward_evidence(valid, 3, 2) {
    Some(evidence) => {
      assert_eq(evidence.start, 1)
      assert_eq(evidence.end, 3)
      assert_eq(evidence.param_count, 2)
    }
    None => fail("expected adjacent forwarding evidence")
  }
  match dae_adjacent_param_forward_evidence([get0, get0, call4], 2, 2) {
    Some(_) => fail("wrong forwarded local must be rejected")
    None => ()
  }
  match dae_adjacent_param_forward_evidence([get1, get0, call4], 2, 2) {
    Some(_) => fail("reordered forwarded locals must be rejected")
    None => ()
  }
  match dae_adjacent_param_forward_evidence([get0, call4], 1, 2) {
    Some(_) => fail("insufficient forwarded prefix must be rejected")
    None => ()
  }
  match dae_adjacent_param_forward_evidence([call4], 0, 0) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 0)
    }
    None => fail("empty adjacent forwarding evidence should stay available")
  }
  let ignored = Array::make(valid.length(), false)
  dae_mark_self_forwarded_param_gets(valid, 4, 2, ignored)
  assert_eq(ignored, [false, true, true, false])
  assert_true(dae_self_call_has_adjacent_param_forward(valid, 3, 2))
  assert_true(
    dae_dead_suffix_has_dropped_self_call_full_param_forward(
      [
        @lib.Instruction::unreachable_(),
        get0,
        get1,
        call4,
        @lib.Instruction::drop(),
      ],
      4,
      2,
    ),
  )
  assert_false(
    dae_dead_suffix_has_dropped_self_call_full_param_forward(
      [
        get0,
        @lib.Instruction::unreachable_(),
        get1,
        call4,
        @lib.Instruction::drop(),
      ],
      4,
      2,
    ),
  )
  assert_false(
    dae_dead_suffix_has_dropped_self_call_full_param_forward(
      [@lib.Instruction::unreachable_(), call4, @lib.Instruction::drop()],
      4,
      0,
    ),
  )
}

///|
test "dae call boundary candidate centralizes owned callee counts" {
  let current : DaeCurrentCallFacts = {
    direct_calls: [2, 0, 1, 4],
    tail_calls: [false, false, true, false],
    direct_callers: [[1, 3], [], [0], [0, 1, 2]],
    dropped_calls: [1, 0, 0, 3],
    escaped: [false, true, false, false],
  }
  let facts = dae_call_boundary_facts_from_current(current)
  match dae_call_boundary_candidate(facts, 0, def_idx=2) {
    Some(candidate) => {
      assert_true(candidate.owned)
      assert_eq(candidate.direct_call_count, 2)
      assert_eq(candidate.dropped_call_count, 1)
      assert_eq(candidate.direct_callers, [1, 3])
      assert_false(candidate.has_self_direct_caller)
      assert_true(candidate.allows_nonself_direct_rewrite)
    }
    None => fail("expected owned boundary candidate")
  }
  match dae_call_boundary_candidate(facts, 3, def_idx=1) {
    Some(candidate) => {
      assert_true(candidate.owned)
      assert_true(candidate.has_self_direct_caller)
      assert_false(candidate.allows_nonself_direct_rewrite)
    }
    None => fail("expected self-caller boundary candidate")
  }
  match dae_call_boundary_candidate(facts, 1) {
    Some(candidate) => assert_false(candidate.owned)
    None => fail("expected escaped boundary candidate")
  }
  match dae_call_boundary_candidate(facts, 2) {
    Some(candidate) => {
      assert_true(candidate.owned)
      assert_true(candidate.tail_callee)
      match dae_dropped_result_candidate_from_boundary_facts(facts, 2) {
        Some(result_candidate) =>
          assert_false(result_candidate.owned_dropped_result_candidate)
        None => fail("expected tail-callee result candidate evidence")
      }
    }
    None => fail("expected tail-call boundary candidate")
  }
  match dae_call_boundary_candidate(facts, 6) {
    Some(_) => fail("out-of-range boundary candidate must be rejected")
    None => ()
  }
}

///|
test "dae exact-literal worklist batches multiple candidates from one call-fact snapshot" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $leaf (sub final (struct)))
      #|  (func $first (param i32) (result i32)
      #|    local.get 0)
      #|  (func $second (param (ref null $leaf)) (result i32)
      #|    local.get 0
      #|    ref.is_null)
      #|  (func (export "run") (result i32)
      #|    i32.const 7
      #|    call $first
      #|    drop
      #|    ref.null $leaf
      #|    call $second))
    ),
  )
  let total = dae_imported_func_count(mod_) + dae_defined_func_count(mod_)
  let call_facts = dae_collect_current_call_facts(mod_, total)
  let candidates = dae_collect_exact_literal_candidate_defs_with_facts(
    mod_, call_facts, 2,
  )
  assert_eq(candidates, [0, 1])
  let application = dae_run_exact_literal_candidate_worklist_with_facts(
    mod_,
    [],
    false,
    candidates,
  )
  assert_eq(application.productive_defs, [0, 1])
  @debug.assert_eq(application.effects.worth_optimizing, [true, true, false])
  @debug.assert_eq(application.effects.body_materialized, [true, true, false])
  @debug.assert_eq(application.effects.parameter_changed, [true, true, false])
  let type_indices = dae_collect_func_type_indices(application.mod_out)
  match dae_resolve_func_type(application.mod_out, type_indices, 0) {
    Some(@lib.FuncType(params, _)) => assert_eq(params.length(), 0)
    None => fail("expected rewritten first candidate type")
  }
  match dae_resolve_func_type(application.mod_out, type_indices, 1) {
    Some(@lib.FuncType(params, _)) => assert_eq(params.length(), 0)
    None => fail("expected rewritten second candidate type")
  }
}

///|
test "dae exact-literal worklist owns immutable-global materialization effects" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (global $constant i32 (i32.const 7))
      #|  (func $target (param i32) (result i32)
      #|    local.get 0)
      #|  (func (export "run") (result i32)
      #|    global.get $constant
      #|    call $target))
    ),
  )
  let application = dae_run_exact_literal_candidate_worklist_with_facts(
    mod_,
    [],
    false,
    [0],
    allow_immutable_global_get=true,
    original=Some(dae_collect_original_boundary_snapshot(mod_)),
  )
  assert_eq(application.productive_defs, [0])
  @debug.assert_eq(application.effects.structurally_touched, [true, true])
  @debug.assert_eq(application.effects.worth_optimizing, [true, false])
  @debug.assert_eq(application.effects.body_materialized, [true, false])
  @debug.assert_eq(application.effects.parameter_changed, [true, false])
  let type_indices = dae_collect_func_type_indices(application.mod_out)
  match dae_resolve_func_type(application.mod_out, type_indices, 0) {
    Some(@lib.FuncType(params, _)) => assert_eq(params.length(), 0)
    None => fail("expected immutable-global target type")
  }
}

///|
test "dae exact-literal candidate worklist admits every semantic parameter shape" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $leaf (sub final (struct)))
      #|  (func $wide
      #|    (param (ref null $leaf) (ref null $leaf) (ref null $leaf) (ref null $leaf))
      #|    (param (ref null $leaf) (ref null $leaf) (ref null $leaf) (ref null $leaf))
      #|    (result i32)
      #|    local.get 0 ref.is_null drop
      #|    local.get 1 ref.is_null drop
      #|    local.get 2 ref.is_null drop
      #|    local.get 3 ref.is_null drop
      #|    local.get 4 ref.is_null drop
      #|    local.get 5 ref.is_null drop
      #|    local.get 6 ref.is_null drop
      #|    local.get 7 ref.is_null)
      #|  (func $mixed
      #|    (param (ref null $leaf) (ref null $leaf) (ref null $leaf) (ref null $leaf))
      #|    (param (ref null $leaf) (ref null $leaf) (ref null $leaf) i32)
      #|    (result i32)
      #|    local.get 0 ref.is_null drop
      #|    local.get 1 ref.is_null drop
      #|    local.get 2 ref.is_null drop
      #|    local.get 3 ref.is_null drop
      #|    local.get 4 ref.is_null drop
      #|    local.get 5 ref.is_null drop
      #|    local.get 6 ref.is_null drop
      #|    local.get 7)
      #|  (func (export "run") (result i32)
      #|    ref.null $leaf ref.null $leaf ref.null $leaf ref.null $leaf
      #|    ref.null $leaf ref.null $leaf ref.null $leaf ref.null $leaf
      #|    call $wide
      #|    drop
      #|    ref.null $leaf ref.null $leaf ref.null $leaf ref.null $leaf
      #|    ref.null $leaf ref.null $leaf ref.null $leaf i32.const 0
      #|    call $mixed))
    ),
  )
  let total = dae_imported_func_count(mod_) + dae_defined_func_count(mod_)
  let call_facts = dae_collect_current_call_facts(mod_, total)
  assert_eq(
    dae_collect_post_revisit_exact_literal_candidates(mod_, call_facts, 2),
    [0, 1],
  )
}

///|
test "dae dropped result candidate centralizes call facts and owned eligibility" {
  let current : DaeCurrentCallFacts = {
    direct_calls: [2, 1, 3],
    tail_calls: [false, false, true],
    direct_callers: [[0, 1], [2], [1, 2]],
    dropped_calls: [2, 1, 3],
    escaped: [false, true, false],
  }
  match dae_dropped_result_candidate_from_current_call_facts(current, 0) {
    Some(candidate) => {
      assert_eq(candidate.callee_abs, 0)
      assert_eq(candidate.direct_call_count, 2)
      assert_eq(candidate.dropped_call_count, 2)
      assert_eq(candidate.direct_callers, [0, 1])
      assert_true(candidate.owned)
      assert_true(candidate.all_direct_calls_dropped)
      assert_true(candidate.owned_dropped_result_candidate)
    }
    None => fail("expected dropped-result candidate")
  }
  match dae_dropped_result_candidate_from_current_call_facts(current, 1) {
    Some(candidate) => {
      assert_false(candidate.owned)
      assert_true(candidate.all_direct_calls_dropped)
      assert_false(candidate.owned_dropped_result_candidate)
    }
    None => fail("expected escaped dropped-result facts")
  }
  match dae_dropped_result_candidate_from_current_call_facts(current, 2) {
    Some(candidate) => {
      assert_false(candidate.owned)
      assert_true(candidate.all_direct_calls_dropped)
      assert_false(candidate.owned_dropped_result_candidate)
    }
    None => fail("expected tail-call dropped-result facts")
  }
  match dae_dropped_result_candidate_from_current_call_facts(current, 4) {
    Some(_) => fail("out-of-range dropped-result candidate must be rejected")
    None => ()
  }
}

///|
test "dae dropped result candidate reuses boundary candidate facts" {
  let current : DaeCurrentCallFacts = {
    direct_calls: [2, 0, 1, 4],
    tail_calls: [false, false, true, false],
    direct_callers: [[1, 3], [], [0], [0, 1, 2]],
    dropped_calls: [2, 0, 1, 3],
    escaped: [false, true, false, false],
  }
  let boundary_facts = dae_call_boundary_facts_from_current(current)
  match dae_dropped_result_candidate_from_boundary_facts(boundary_facts, 0) {
    Some(candidate) => {
      assert_eq(candidate.direct_call_count, 2)
      assert_eq(candidate.dropped_call_count, 2)
      assert_eq(candidate.direct_callers, [1, 3])
      assert_true(candidate.owned)
      assert_true(candidate.all_direct_calls_dropped)
      assert_true(candidate.owned_dropped_result_candidate)
    }
    None => fail("expected dropped-result candidate from boundary facts")
  }
  match dae_dropped_result_candidate_from_boundary_facts(boundary_facts, 3) {
    Some(candidate) => {
      assert_true(candidate.owned)
      assert_false(candidate.all_direct_calls_dropped)
      assert_false(candidate.owned_dropped_result_candidate)
    }
    None => fail("expected partial dropped-result boundary candidate")
  }
  match dae_dropped_result_candidate_from_boundary_facts(boundary_facts, 2) {
    Some(candidate) => {
      assert_false(candidate.owned)
      assert_true(candidate.all_direct_calls_dropped)
      assert_false(candidate.owned_dropped_result_candidate)
    }
    None => fail("expected tail-call dropped-result boundary facts")
  }
  match dae_dropped_result_candidate_from_boundary_facts(boundary_facts, 6) {
    Some(_) => fail("out-of-range boundary candidate must be rejected")
    None => ()
  }
}

///|
test "dae module boundary snapshot carries counts facts and type indices" {
  let void_type = @lib.TypeIdx::new(0U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("imp"),
          @lib.ExternType::func(void_type),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([void_type, void_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  let snapshot = dae_collect_module_boundary_snapshot(mod_)
  assert_eq(snapshot.imported, 1)
  assert_eq(snapshot.defined, 2)
  assert_eq(snapshot.total, 3)
  assert_eq(snapshot.type_indices.length(), 3)
  assert_eq(snapshot.call_facts.direct_calls[2], 1)
  match dae_call_boundary_candidate(snapshot.boundary_facts, 2) {
    Some(candidate) => {
      assert_true(candidate.owned)
      assert_eq(candidate.direct_call_count, 1)
      assert_eq(candidate.direct_callers, [0])
    }
    None => fail("expected boundary candidate from snapshot facts")
  }
}

///|
test "dae original boundary snapshot carries original counts escapes and call summaries" {
  let void_type = @lib.TypeIdx::new(0U)
  let param_type = @lib.TypeIdx::new(1U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], []),
          ),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("imp"),
          @lib.ExternType::func(void_type),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([param_type, void_type]))
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("entry"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  let snapshot = dae_collect_original_boundary_snapshot(mod_)
  assert_eq(snapshot.imported, 1)
  assert_eq(snapshot.defined, 2)
  assert_eq(snapshot.total, 3)
  assert_eq(snapshot.type_indices.length(), 3)
  assert_eq(snapshot.param_counts, [1, 0])
  assert_true(snapshot.escaped[1])
  assert_false(snapshot.escaped[2])
  assert_true(snapshot.exposure[0].imported)
  assert_true(snapshot.exposure[1].exported)
  assert_false(snapshot.exposure[2].exported)
  assert_eq(snapshot.call_summary.call_counts, [0, 1])
  assert_eq(snapshot.call_summary.prior_call_counts, [0, 1])
  assert_eq(snapshot.call_summary.nonself_undropped_call_counts, [0, 1])
  assert_eq(snapshot.large_unreachable_prefixes, [false, false])
  assert_eq(snapshot.private_result_dead_suffix_call_counts, [0, 0])
  assert_eq(snapshot.private_result_same_operand_call_counts, [0, 0])
  assert_eq(
    snapshot.escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts,
    [0, 0],
  )
  assert_eq(snapshot.dead_suffix_other_calls, [false, false])
  assert_eq(snapshot.dead_suffix_undropped_self_calls, [false, false])
  assert_eq(snapshot.dead_suffix_mutual_calls, [false, false])
}

///|
test "dae original result preservation evidence centralizes shared guards" {
  let context = dae_original_result_preservation_context(
    [0, 1, 0],
    [0, 3, 1],
    [0, 1, 0],
    [0, 1, 0],
    [0, 2, 0],
    [0, 2, 0],
    [0, 0, 4],
    [0, 0, 0],
    [false, true, false],
    [false, true, false],
    [false, false, false],
    [0, 0, 0],
    [0, 0, 0],
    [false, true, false],
    [false, true, false],
    [false, true, false],
    [false, false, false],
    [false, false, false],
    [0, 5, 0],
    [0, 7, 0],
    [0, 0, 0],
  )
  let evidence = dae_original_result_preservation_evidence_from_context(
    1, context,
  )
  assert_true(evidence.same_self_result_operand)
  assert_false(evidence.result_from_undropped_self_caller)
  assert_true(evidence.escaped_result_operand_chain)
  assert_true(evidence.mixed_self_result)
  assert_false(evidence.escaped_block_self_result)
  assert_true(evidence.param_operand_self_result_side_callee)
  assert_false(evidence.undropped_self_result_from_no_param_dropped_caller)
  assert_false(evidence.dropped_escaped_result_under_self_caller)
  assert_true(evidence.parameterized_undropped_self_side_chain)
  assert_true(evidence.result_side_chain_cleanup_preservation)
  assert_true(dae_original_result_preservation_any(evidence))
  let paramless_evidence = dae_original_result_preservation_evidence_from_context(
    2, context,
  )
  assert_true(paramless_evidence.escaped_result_operand_chain)
  assert_false(paramless_evidence.mixed_self_result)
}

///|
test "dae original result preservation row centralizes indexed guard facts" {
  let context = dae_original_result_preservation_context(
    [0, 1, 0],
    [0, 3, 1],
    [0, 1, 0],
    [0, 1, 0],
    [0, 2, 0],
    [0, 2, 0],
    [0, 0, 4],
    [0, 0, 0],
    [false, true, false],
    [false, true, false],
    [false, false, false],
    [0, 0, 0],
    [0, 0, 0],
    [false, true, false],
    [false, true, false],
    [false, true, false],
    [false, false, false],
    [false, false, false],
    [0, 5, 0],
    [0, 7, 0],
    [0, 0, 0],
  )
  let row = dae_original_result_preservation_row_from_context(1, context)
  assert_eq(row.param_count, 1)
  assert_eq(row.call_count, 3)
  assert_eq(row.active_nonself_call_count, 1)
  assert_eq(row.nonself_undropped_call_count, 2)
  assert_eq(row.self_call_count, 2)
  assert_true(row.dead_suffix_same_self_result_operand_call)
  assert_true(row.dead_suffix_undropped_self_call_param_operand)
  assert_eq(row.dead_suffix_calls_from_param_operand_self_result_caller, 5)
  assert_eq(row.dead_suffix_escaped_result_operand_call_count, 7)
  let row_evidence = dae_original_result_preservation_evidence_from_row(row)
  assert_true(row_evidence.same_self_result_operand)
  assert_true(row_evidence.escaped_result_operand_chain)
  assert_true(row_evidence.param_operand_self_result_side_callee)
  assert_true(row_evidence.parameterized_undropped_self_side_chain)
  assert_true(row_evidence.result_side_chain_cleanup_preservation)
  let no_param_guard = dae_original_no_param_dropped_caller_guard_evidence_from_row(
    row,
  )
  assert_false(
    dae_should_preserve_undropped_self_result_from_no_param_dropped_caller_evidence(
      no_param_guard,
    ),
  )
  let side_chain = dae_original_parameterized_undropped_self_side_chain_evidence_from_row(
    row,
  )
  assert_true(
    dae_should_preserve_parameterized_undropped_self_side_chain_evidence(
      side_chain,
    ),
  )
  let empty_row = dae_original_result_preservation_row_from_context(9, context)
  assert_eq(empty_row.param_count, 0)
  assert_eq(empty_row.call_count, 0)
  assert_false(empty_row.dead_suffix_undropped_self_call)
  assert_false(
    dae_original_result_preservation_any(
      dae_original_result_preservation_evidence_from_row(empty_row),
    ),
  )
}

///|
test "dae original result boundary row shares preservation and prune facts" {
  let preservation = dae_original_result_preservation_context(
    [0, 1, 0],
    [0, 3, 1],
    [0, 2, 0],
    [0, 1, 0],
    [0, 1, 0],
    [0, 2, 0],
    [0, 0, 4],
    [0, 0, 0],
    [false, true, false],
    [false, true, false],
    [false, true, false],
    [0, 0, 0],
    [0, 0, 0],
    [false, true, false],
    [false, true, false],
    [false, true, false],
    [false, false, false],
    [false, false, false],
    [0, 5, 0],
    [0, 7, 0],
    [0, 0, 0],
  )
  let context = dae_original_result_boundary_context(
    preservation,
    [0, 11, 0],
    [false, true, false],
    [false, true, false],
    [false, true, false],
    [false, false, true],
    [0, 0, 0],
    [false, false, false],
    [false, true, false],
    [0, 4, 0],
    [0, 6, 0],
    [0, 8, 0],
    [0, 9, 0],
  )
  let row = dae_original_result_boundary_row_from_context(1, context)
  assert_eq(row.preservation.param_count, 1)
  assert_eq(row.prune.param_count, row.preservation.param_count)
  assert_eq(row.prune.call_count, row.preservation.call_count)
  assert_eq(
    row.prune.active_nonself_call_count,
    row.preservation.active_nonself_call_count,
  )
  assert_eq(
    row.prune.active_parameterized_nonself_call_count,
    row.preservation.active_parameterized_nonself_call_count,
  )
  assert_eq(
    row.prune.nonself_undropped_call_count,
    row.preservation.nonself_undropped_call_count,
  )
  assert_eq(row.prune.self_call_count, row.preservation.self_call_count)
  assert_eq(
    row.prune.escaped_dead_suffix_call_count,
    row.preservation.escaped_dead_suffix_call_count,
  )
  assert_eq(
    row.prune.dead_suffix_undropped_self_call,
    row.preservation.dead_suffix_undropped_self_call,
  )
  assert_eq(
    row.prune.dead_suffix_dropped_self_call,
    row.preservation.dead_suffix_dropped_self_call,
  )
  assert_eq(
    row.prune.dead_suffix_block_undropped_self_call,
    row.preservation.dead_suffix_block_undropped_self_call,
  )
  assert_eq(
    row.prune.dead_suffix_same_self_result_operand_call,
    row.preservation.dead_suffix_same_self_result_operand_call,
  )
  assert_eq(
    row.prune.dead_suffix_dropped_escaped_result_call,
    row.preservation.dead_suffix_dropped_escaped_result_call,
  )
  assert_eq(
    row.prune.dead_suffix_mutual_call,
    row.preservation.dead_suffix_mutual_call,
  )
  assert_eq(row.escape.private_result_escaped_operand_call_count, 11)
  assert_true(row.escape.dead_suffix_undropped_escaped_result_call)
  assert_false(row.preservation.dead_suffix_dropped_escaped_result_call)
  assert_eq(
    row.escape.private_result_dead_suffix_calls_from_escaped_operand_callees,
    row.preservation.private_result_dead_suffix_calls_from_escaped_operand_callees,
  )
  assert_eq(
    row.escape.escaped_dead_suffix_call_count,
    row.preservation.escaped_dead_suffix_call_count,
  )
  assert_eq(
    row.escape.dead_suffix_result_calls_from_undropped_self_caller,
    row.preservation.dead_suffix_result_calls_from_undropped_self_caller,
  )
  assert_eq(
    row.escape.dead_suffix_result_calls_from_no_param_undropped_self_caller,
    row.preservation.dead_suffix_result_calls_from_no_param_undropped_self_caller,
  )
  assert_eq(
    row.escape.dead_suffix_calls_from_param_operand_self_result_caller,
    row.preservation.dead_suffix_calls_from_param_operand_self_result_caller,
  )
  assert_eq(
    row.escape.dead_suffix_escaped_result_operand_call_count,
    row.preservation.dead_suffix_escaped_result_operand_call_count,
  )
  assert_true(row.side_call.dead_suffix_other_call)
  assert_eq(
    row.side_call.dead_suffix_result_other_call,
    row.preservation.dead_suffix_result_other_call,
  )
  assert_eq(
    row.side_call.dead_suffix_mutual_call,
    row.preservation.dead_suffix_mutual_call,
  )
  assert_true(row.side_call.dead_suffix_self_recursive_void_side_call)
  assert_false(row.side_call.dead_suffix_self_recursive_result_side_call)
  assert_eq(row.prune.later_dead_suffix_dropped_call_count, 4)
  assert_eq(row.prune.private_result_dead_suffix_call_count, 6)
  assert_eq(row.prune.dead_suffix_dropped_calls_from_no_param_result_caller, 8)
  assert_eq(row.prune.dead_suffix_mixed_dropped_undropped_call_count, 9)
  let evidence = dae_original_result_boundary_evidence_from_row(row)
  assert_true(evidence.preservation.same_self_result_operand)
  assert_false(evidence.prune.dropped_self_result_with_void_side_callers)
  let empty = dae_original_result_boundary_row_from_context(9, context)
  assert_eq(empty.preservation.param_count, 0)
  assert_eq(empty.prune.param_count, 0)
  assert_eq(empty.escape.private_result_escaped_operand_call_count, 0)
  assert_eq(empty.escape.dead_suffix_escaped_result_operand_call_count, 0)
  assert_false(empty.escape.dead_suffix_undropped_escaped_result_call)
  assert_false(empty.side_call.dead_suffix_other_call)
  assert_false(empty.side_call.dead_suffix_result_other_call)
  assert_false(empty.side_call.dead_suffix_mutual_call)
  assert_false(empty.side_call.dead_suffix_self_recursive_void_side_call)
  assert_false(empty.side_call.dead_suffix_self_recursive_result_side_call)
  assert_false(
    dae_original_result_preservation_any(
      dae_original_result_boundary_evidence_from_row(empty).preservation,
    ),
  )
}

///|
test "dae original result removal prune row centralizes indexed guard facts" {
  let later_row = dae_original_result_removal_prune_row(
    1,
    [0, 1, 1],
    [0, 1, 3],
    [0, 0, 1],
    [0, 0, 1],
    [0, 0, 0],
    [0, 0, 0],
    [0, 0, 1],
    [0, 0, 0],
    [false, false, false],
    [false, false, true],
    [false, false, false],
    [false, false, false],
    [false, false, false],
    [false, false, false],
    [false, true, false],
    [0, 2, 0],
    [false, false, false],
    [0, 0, 3],
    [false, false, true],
    [0, 0, 4],
    [0, 5, 0],
  )
  assert_eq(later_row.param_count, 1)
  assert_eq(later_row.self_call_count, 0)
  assert_true(later_row.dead_suffix_dropped_earlier_result_call)
  assert_eq(later_row.later_dead_suffix_dropped_call_count, 2)
  assert_eq(later_row.dead_suffix_mixed_dropped_undropped_call_count, 5)
  assert_true(dae_should_prune_later_mutual_dropped_result_from_row(later_row))
  assert_false(
    dae_should_prune_mixed_dropped_undropped_caller_from_row(later_row),
  )
  assert_false(
    dae_should_prune_dropped_self_result_with_void_side_callers_from_row(
      later_row,
    ),
  )
  assert_false(
    dae_should_prune_dropped_only_private_result_side_caller_from_row(later_row),
  )
  let mixed_row = dae_original_result_removal_prune_row(
    1,
    [0, 1],
    [0, 1],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 1],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [0, 0],
    [false, false],
    [0, 0],
    [false, false],
    [0, 0],
    [0, 1],
  )
  assert_true(
    dae_should_prune_mixed_dropped_undropped_caller_from_row(mixed_row),
  )
  assert_false(dae_should_preserve_mixed_self_suffix_from_row(mixed_row))
  let mixed_self_row = dae_original_result_removal_prune_row(
    1,
    [0, 1],
    [0, 2],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 1],
    [0, 2],
    [0, 0],
    [false, true],
    [false, true],
    [false, false],
    [false, true],
    [false, false],
    [false, false],
    [false, false],
    [0, 0],
    [false, false],
    [0, 0],
    [false, false],
    [0, 0],
    [0, 0],
  )
  assert_true(dae_should_preserve_mixed_self_suffix_from_row(mixed_self_row))
  assert_true(
    dae_should_preserve_same_self_result_operand_from_row(mixed_self_row),
  )
  assert_false(
    dae_should_preserve_escaped_block_self_result_from_row(mixed_self_row, true),
  )
  let escaped_block_row = dae_original_result_removal_prune_row(
    1,
    [0, 1],
    [0, 2],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 1],
    [0, 1],
    [false, true],
    [false, true],
    [false, true],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [0, 0],
    [false, false],
    [0, 0],
    [false, false],
    [0, 0],
    [0, 0],
  )
  assert_true(
    dae_should_preserve_escaped_block_self_result_from_row(
      escaped_block_row, true,
    ),
  )
  let void_side_row = dae_original_result_removal_prune_row(
    2,
    [0, 1, 1],
    [0, 1, 3],
    [0, 0, 1],
    [0, 0, 1],
    [0, 0, 0],
    [0, 0, 0],
    [0, 0, 1],
    [0, 0, 0],
    [false, false, false],
    [false, false, true],
    [false, false, false],
    [false, false, false],
    [false, false, false],
    [false, false, false],
    [false, true, false],
    [0, 2, 0],
    [false, false, false],
    [0, 0, 3],
    [false, false, true],
    [0, 0, 4],
    [0, 5, 0],
  )
  assert_true(void_side_row.dead_suffix_dropped_self_call)
  assert_false(void_side_row.dead_suffix_dropped_self_call_full_param_forward)
  assert_true(
    dae_should_prune_dropped_self_result_with_void_side_callers_from_row(
      void_side_row,
    ),
  )
  assert_false(
    dae_should_prune_later_mutual_dropped_result_from_row(void_side_row),
  )
  assert_false(
    dae_should_prune_dropped_only_private_result_side_caller_from_row(
      void_side_row,
    ),
  )
  assert_false(
    dae_should_prune_dropped_only_no_param_result_side_caller_from_row(
      void_side_row,
    ),
  )
  let dropped_only_row = dae_original_result_removal_prune_row(
    1,
    [0, 1],
    [0, 1],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 0],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [0, 0],
    [false, false],
    [0, 1],
    [false, true],
    [0, 1],
    [0, 0],
  )
  assert_true(
    dae_should_prune_dropped_only_private_result_side_caller_from_row(
      dropped_only_row,
    ),
  )
  assert_true(
    dae_should_prune_dropped_only_no_param_result_side_caller_from_row(
      dropped_only_row,
    ),
  )
  let dropped_only_prune = dae_original_result_removal_prune_evidence_from_row(
    dropped_only_row,
  )
  assert_false(dropped_only_prune.dropped_self_result_with_void_side_callers)
  assert_false(dropped_only_prune.later_mutual_dropped_result)
  assert_false(dropped_only_prune.mixed_dropped_undropped_caller)
  assert_true(dropped_only_prune.dropped_only_private_result_side_caller)
  assert_true(dropped_only_prune.dropped_only_no_param_result_side_caller)
  assert_true(dropped_only_prune.params_absent_result_cleanup_prune)
  assert_true(dropped_only_prune.uncalled_after_param_cleanup_prune)
  assert_true(dae_should_prune_params_absent_result_cleanup(dropped_only_prune))
  assert_true(
    dae_should_block_uncalled_after_param_cleanup_from_prune_evidence(
      dropped_only_prune,
    ),
  )
  let empty_row = dae_original_result_removal_prune_row(
    9,
    [1],
    [1],
    [1],
    [1],
    [1],
    [1],
    [1],
    [1],
    [true],
    [true],
    [true],
    [true],
    [true],
    [true],
    [true],
    [1],
    [true],
    [1],
    [true],
    [1],
    [1],
  )
  assert_eq(empty_row.param_count, 0)
  assert_eq(empty_row.call_count, 0)
  assert_false(empty_row.dead_suffix_dropped_self_call)
  assert_false(dae_should_prune_later_mutual_dropped_result_from_row(empty_row))
  assert_false(
    dae_should_prune_dropped_self_result_with_void_side_callers_from_row(
      empty_row,
    ),
  )
  assert_false(
    dae_should_prune_mixed_dropped_undropped_caller_from_row(empty_row),
  )
  assert_false(
    dae_should_prune_dropped_only_private_result_side_caller_from_row(empty_row),
  )
  assert_false(
    dae_should_prune_dropped_only_no_param_result_side_caller_from_row(
      empty_row,
    ),
  )
  assert_false(dae_should_preserve_mixed_self_suffix_from_row(empty_row))
  assert_false(dae_should_preserve_same_self_result_operand_from_row(empty_row))
  assert_false(
    dae_should_preserve_escaped_block_self_result_from_row(empty_row, false),
  )
  let empty_prune = dae_original_result_removal_prune_evidence_from_row(
    empty_row,
  )
  assert_false(empty_prune.params_absent_result_cleanup_prune)
  assert_false(empty_prune.uncalled_after_param_cleanup_prune)
  assert_false(dae_should_prune_params_absent_result_cleanup(empty_prune))
  assert_false(
    dae_should_block_uncalled_after_param_cleanup_from_prune_evidence(
      empty_prune,
    ),
  )
}

///|
test "dae original dead-suffix side-call evidence centralizes cleanup gates" {
  let result_side_row = dae_original_result_removal_prune_row(
    1,
    [0, 1],
    [0, 3],
    [0, 2],
    [0, 0],
    [0, 0],
    [0, 2],
    [0, 1],
    [0, 0],
    [false, true],
    [false, false],
    [false, false],
    [false, true],
    [false, false],
    [false, false],
    [false, false],
    [0, 0],
    [false, true],
    [0, 0],
    [false, false],
    [0, 0],
    [0, 0],
  )
  let result_side_call : DaeOriginalResultSideCallRow = {
    dead_suffix_other_call: true,
    dead_suffix_result_other_call: false,
    dead_suffix_self_recursive_void_side_call: false,
    dead_suffix_self_recursive_result_side_call: true,
    dead_suffix_mutual_call: result_side_row.dead_suffix_mutual_call,
  }
  let result_side = dae_original_dead_suffix_side_call_evidence(
    result_side_row, result_side_call,
  )
  assert_false(result_side.void_side_cleanup_preservation)
  assert_true(result_side.result_side_chain_preservation)
  assert_true(result_side.same_self_result_operand_preservation)
  let void_side_row = dae_original_result_removal_prune_row(
    1,
    [0, 1],
    [0, 2],
    [0, 1],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 0],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [0, 0],
    [false, false],
    [0, 0],
    [false, false],
    [0, 0],
    [0, 0],
  )
  let void_side_call : DaeOriginalResultSideCallRow = {
    dead_suffix_other_call: true,
    dead_suffix_result_other_call: false,
    dead_suffix_self_recursive_void_side_call: true,
    dead_suffix_self_recursive_result_side_call: false,
    dead_suffix_mutual_call: void_side_row.dead_suffix_mutual_call,
  }
  let void_side = dae_original_dead_suffix_side_call_evidence(
    void_side_row, void_side_call,
  )
  assert_true(void_side.void_side_cleanup_preservation)
  assert_false(void_side.result_side_chain_preservation)
  assert_false(void_side.same_self_result_operand_preservation)
}

///|
test "dae original no-param dropped caller guard centralizes indexed facts" {
  let evidence = dae_original_no_param_dropped_caller_guard_evidence(
    1,
    [0, 1],
    [0, 3],
    [0, 2],
    [0, 0],
    [0, 0],
    [0, 1],
    [0, 0],
    [false, true],
    [false, true],
    [false, true],
    [false, false],
  )
  assert_eq(evidence.param_count, 1)
  assert_eq(evidence.call_count, 3)
  assert_eq(evidence.active_nonself_call_count, 2)
  assert_eq(evidence.active_parameterized_nonself_call_count, 0)
  assert_eq(evidence.nonself_undropped_call_count, 0)
  assert_eq(evidence.self_call_count, 1)
  assert_eq(evidence.escaped_dead_suffix_call_count, 0)
  assert_true(evidence.dead_suffix_undropped_self_call)
  assert_true(evidence.dead_suffix_undropped_self_call_param_operand)
  assert_true(evidence.dead_suffix_result_other_call)
  assert_false(evidence.dead_suffix_mutual_call)
  assert_true(
    dae_should_preserve_undropped_self_result_from_no_param_dropped_caller_evidence(
      evidence,
    ),
  )
  let out_of_range = dae_original_no_param_dropped_caller_guard_evidence(
    3,
    [1],
    [2],
    [3],
    [4],
    [5],
    [6],
    [7],
    [true],
    [true],
    [true],
    [true],
  )
  assert_eq(out_of_range.param_count, 0)
  assert_eq(out_of_range.call_count, 0)
  assert_false(out_of_range.dead_suffix_undropped_self_call)
  assert_false(
    dae_should_preserve_undropped_self_result_from_no_param_dropped_caller_evidence(
      out_of_range,
    ),
  )
}

///|
test "dae original parameterized self side-chain guard centralizes indexed facts" {
  let context = dae_original_result_preservation_context(
    [0, 1],
    [0, 3],
    [0, 2],
    [0, 2],
    [0, 0],
    [0, 1],
    [0, 0],
    [0, 0],
    [false, true],
    [false, false],
    [false, false],
    [0, 0],
    [0, 0],
    [false, false],
    [false, false],
    [false, true],
    [false, false],
    [false, false],
    [0, 0],
    [0, 0],
    [0, 0],
  )
  let evidence = dae_original_parameterized_undropped_self_side_chain_evidence_from_row(
    dae_original_result_preservation_row_from_context(1, context),
  )
  assert_eq(evidence.param_count, 1)
  assert_eq(evidence.call_count, 3)
  assert_eq(evidence.active_parameterized_nonself_call_count, 2)
  assert_eq(evidence.self_call_count, 1)
  assert_eq(evidence.escaped_dead_suffix_call_count, 0)
  assert_true(evidence.dead_suffix_undropped_self_call)
  assert_true(evidence.dead_suffix_result_other_call)
  assert_true(
    dae_should_preserve_parameterized_undropped_self_side_chain_evidence(
      evidence,
    ),
  )
  let out_of_range = dae_original_parameterized_undropped_self_side_chain_evidence_from_row(
    dae_original_result_preservation_row_from_context(4, context),
  )
  assert_eq(out_of_range.param_count, 0)
  assert_eq(out_of_range.call_count, 0)
  assert_false(out_of_range.dead_suffix_undropped_self_call)
  assert_false(
    dae_should_preserve_parameterized_undropped_self_side_chain_evidence(
      out_of_range,
    ),
  )
}

///|
test "dae original result cleanup preservation centralizes shared core decisions" {
  let row : DaeOriginalResultRemovalPruneRow = {
    param_count: 1,
    call_count: 1,
    active_nonself_call_count: 0,
    active_parameterized_nonself_call_count: 0,
    active_parameterized_result_nonself_call_count: 0,
    nonself_undropped_call_count: 0,
    self_call_count: 1,
    escaped_dead_suffix_call_count: 0,
    dead_suffix_undropped_self_call: true,
    dead_suffix_dropped_self_call: true,
    dead_suffix_block_undropped_self_call: false,
    dead_suffix_same_self_result_operand_call: false,
    dead_suffix_dropped_self_call_full_param_forward: false,
    dead_suffix_dropped_escaped_result_call: false,
    dead_suffix_dropped_earlier_result_call: false,
    later_dead_suffix_dropped_call_count: 0,
    dead_suffix_mutual_call: false,
    private_result_dead_suffix_call_count: 0,
    dead_suffix_result_other_call: false,
    dead_suffix_dropped_calls_from_no_param_result_caller: 0,
    dead_suffix_mixed_dropped_undropped_call_count: 0,
  }
  let preservation : DaeOriginalResultPreservationEvidence = {
    same_self_result_operand: false,
    result_from_undropped_self_caller: false,
    escaped_result_operand_chain: false,
    mixed_self_result: true,
    escaped_block_self_result: false,
    param_operand_self_result_side_callee: false,
    undropped_self_result_from_no_param_dropped_caller: true,
    dropped_escaped_result_under_self_caller: false,
    parameterized_undropped_self_side_chain: false,
    result_side_chain_cleanup_preservation: true,
  }
  let evidence = dae_original_result_cleanup_preservation_evidence(
    row, preservation,
  )
  assert_true(evidence.mixed_self_suffix)
  assert_true(evidence.result_side_chain_cleanup_preservation)
  assert_true(dae_original_result_cleanup_preservation_any(evidence))
  let clear : DaeOriginalResultCleanupPreservationEvidence = {
    mixed_self_suffix: false,
    result_side_chain_cleanup_preservation: false,
  }
  assert_false(dae_original_result_cleanup_preservation_any(clear))
}

///|
test "dae original result preservation repair gate reuses shared evidence" {
  let clear = {
    same_self_result_operand: false,
    result_from_undropped_self_caller: false,
    escaped_result_operand_chain: false,
    mixed_self_result: false,
    escaped_block_self_result: false,
    param_operand_self_result_side_callee: false,
    undropped_self_result_from_no_param_dropped_caller: false,
    dropped_escaped_result_under_self_caller: false,
    parameterized_undropped_self_side_chain: false,
    result_side_chain_cleanup_preservation: false,
  }
  assert_false(
    dae_original_result_preservation_blocks_argument_side_result_repair(
      clear, true,
    ),
  )
  let param_operand_only = {
    same_self_result_operand: false,
    result_from_undropped_self_caller: false,
    escaped_result_operand_chain: false,
    mixed_self_result: false,
    escaped_block_self_result: false,
    param_operand_self_result_side_callee: true,
    undropped_self_result_from_no_param_dropped_caller: false,
    dropped_escaped_result_under_self_caller: false,
    parameterized_undropped_self_side_chain: false,
    result_side_chain_cleanup_preservation: false,
  }
  assert_false(
    dae_original_result_preservation_blocks_argument_side_result_repair(
      param_operand_only, true,
    ),
  )
  let parameterized_only = {
    same_self_result_operand: false,
    result_from_undropped_self_caller: false,
    escaped_result_operand_chain: false,
    mixed_self_result: false,
    escaped_block_self_result: false,
    param_operand_self_result_side_callee: false,
    undropped_self_result_from_no_param_dropped_caller: false,
    dropped_escaped_result_under_self_caller: false,
    parameterized_undropped_self_side_chain: true,
    result_side_chain_cleanup_preservation: true,
  }
  assert_true(
    dae_original_result_preservation_blocks_argument_side_result_repair(
      parameterized_only, true,
    ),
  )
  assert_false(
    dae_original_result_preservation_blocks_argument_side_result_repair(
      parameterized_only, false,
    ),
  )
}

///|
test "dae dropped result call rewrite policy centralizes dead suffix handling" {
  let callee = @lib.FuncIdx::new(1U)
  let body = [
    @lib.Instruction::call(callee),
    @lib.Instruction::drop(),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(callee),
    @lib.Instruction::drop(),
  ]
  let (stop_body, stop_rewrites) = dae_rewrite_dropped_result_calls_with_policy_instrs(
    body, 1, true,
  )
  assert_eq(stop_body, [
    @lib.Instruction::call(callee),
    @lib.Instruction::unreachable_(),
  ])
  assert_eq(stop_rewrites, 1)
  let (anywhere_body, anywhere_rewrites) = dae_rewrite_dropped_result_calls_with_policy_instrs(
    body, 1, false,
  )
  assert_eq(anywhere_body, [
    @lib.Instruction::call(callee),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(callee),
  ])
  assert_eq(anywhere_rewrites, 2)
}

///|
test "dae dropped result rewrite scope centralizes selected caller handling" {
  let callee = @lib.FuncIdx::new(2U)
  let all_scope = dae_dropped_result_scope_from_optional(3, None)
  assert_eq(all_scope.caller_defs, [0, 1, 2])
  let selected_scope = dae_dropped_result_scope_from_optional(
    3,
    Some([1, -1, 99]),
  )
  assert_eq(selected_scope.caller_defs, [1, -1, 99])
  let funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee), @lib.Instruction::drop()]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee), @lib.Instruction::drop()]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee)]),
    ),
  ]
  assert_true(
    dae_dropped_result_scope_direct_call_evidence(funcs, all_scope, 2, -1).has_live_undropped_direct_call,
  )
  assert_false(
    dae_dropped_result_scope_direct_call_evidence(funcs, selected_scope, 2, -1).has_live_undropped_direct_call,
  )
  let selected_funcs = funcs.copy()
  let rewrites = dae_rewrite_dropped_result_calls_in_scope(
    selected_funcs, selected_scope, 2,
  )
  assert_eq(rewrites, 1)
  assert_eq(selected_funcs[0], funcs[0])
  assert_eq(
    selected_funcs[1],
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee)]),
    ),
  )
  assert_eq(selected_funcs[2], funcs[2])
}

///|
test "dae dropped result module context centralizes section scope and legality facts" {
  let result_type = @lib.TypeIdx::new(0U)
  let callee = @lib.FuncIdx::new(1U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([result_type, result_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(callee),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(1)]),
        ),
      ]),
    )
  match dae_dropped_result_module_context(mod_, 1, caller_defs=Some([0])) {
    Some(context) => {
      assert_eq(context.imported, 0)
      assert_eq(context.signature.def_idx, 1)
      assert_eq(context.type_indices.length(), 2)
      assert_eq(context.signature.type_idxs.length(), 2)
      assert_eq(context.signature.funcs.length(), 2)
      assert_eq(context.scope.caller_defs, [0])
      assert_eq(context.params.length(), 0)
      assert_eq(context.results, [@lib.ValType::i32()])
      assert_eq(context.result_removal_legality.result_count, 1)
      assert_false(context.result_removal_legality.has_live_tail_call)
      assert_false(context.result_removal_legality.has_undropped_direct_call)
      assert_false(
        dae_dropped_result_removal_legality_blocks(
          context.result_removal_legality,
        ),
      )
    }
    None => fail("expected dropped-result module context")
  }
  match dae_dropped_result_module_context(mod_, 4) {
    Some(_) => fail("out-of-range dropped-result module context must reject")
    None => ()
  }
}

///|
test "dae dropped result removal legality centralizes result blockers" {
  let callee = @lib.FuncIdx::new(2U)
  let blocked_funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee), @lib.Instruction::drop()]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee)]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::return_call(callee)]),
    ),
  ]
  let full_scope = dae_dropped_result_scope_from_optional(3, None)
  let result_evidence = dae_dropped_result_removal_legality_evidence(
    blocked_funcs,
    full_scope,
    2,
    -1,
    [@lib.ValType::i32()],
  )
  assert_eq(result_evidence.result_count, 1)
  assert_false(result_evidence.skip_large_result_cleanup)
  assert_true(result_evidence.has_live_tail_call)
  assert_true(result_evidence.has_undropped_direct_call)
  assert_true(result_evidence.blocks_result_removal)
  let void_evidence = dae_dropped_result_removal_legality_evidence(
    blocked_funcs,
    full_scope,
    2,
    -1,
    [],
  )
  assert_eq(void_evidence.result_count, 0)
  assert_false(void_evidence.has_live_tail_call)
  assert_false(void_evidence.has_undropped_direct_call)
  assert_false(void_evidence.blocks_result_removal)
  let dropped_only_funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee), @lib.Instruction::drop()]),
    ),
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  ]
  let selected_scope = dae_dropped_result_scope_from_optional(3, Some([0]))
  let dropped_only_evidence = dae_dropped_result_removal_legality_evidence(
    dropped_only_funcs,
    selected_scope,
    2,
    -1,
    [@lib.ValType::i32()],
  )
  assert_false(dropped_only_evidence.has_live_tail_call)
  assert_false(dropped_only_evidence.has_undropped_direct_call)
  assert_false(dropped_only_evidence.blocks_result_removal)
}

///|
test "dae dropped result callee rewrite evidence centralizes suffix and legality facts" {
  let callee = @lib.FuncIdx::new(1U)
  let result_type = [@lib.ValType::i32()]
  let clear_legality : DaeDroppedResultRemovalLegalityEvidence = {
    result_count: 1,
    skip_large_result_cleanup: false,
    has_live_tail_call: false,
    has_undropped_direct_call: false,
    blocks_result_removal: false,
  }
  let unreachable_with_suffix = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::unreachable_(),
      @lib.Instruction::call(callee),
      @lib.Instruction::drop(),
    ]),
  )
  let dropped_evidence = dae_dropped_result_callee_rewrite_evidence(
    unreachable_with_suffix,
    [],
    result_type,
    clear_legality,
    1,
  )
  assert_eq(dropped_evidence.param_count, 0)
  assert_eq(dropped_evidence.result_count, 1)
  assert_false(dropped_evidence.original_unreachable_only)
  assert_true(dropped_evidence.simplified_unreachable_only)
  assert_true(dropped_evidence.has_dropped_dead_suffix_call)
  assert_false(dropped_evidence.has_undropped_dead_suffix_call)
  assert_false(dropped_evidence.missing_dropped_dead_suffix_call)
  assert_true(dropped_evidence.missing_undropped_dead_suffix_call)
  assert_false(dropped_evidence.blocks_result_removal)
  let undropped_evidence = dae_dropped_result_callee_rewrite_evidence(
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::unreachable_(),
        @lib.Instruction::call(callee),
      ]),
    ),
    [@lib.ValType::i32()],
    result_type,
    clear_legality,
    1,
  )
  assert_eq(undropped_evidence.param_count, 1)
  assert_true(undropped_evidence.has_undropped_dead_suffix_call)
  assert_true(undropped_evidence.missing_dropped_dead_suffix_call)
  assert_false(undropped_evidence.missing_undropped_dead_suffix_call)
  let blocked_legality : DaeDroppedResultRemovalLegalityEvidence = {
    result_count: 1,
    skip_large_result_cleanup: false,
    has_live_tail_call: true,
    has_undropped_direct_call: false,
    blocks_result_removal: true,
  }
  let blocked_evidence = dae_dropped_result_callee_rewrite_evidence(
    unreachable_with_suffix,
    [],
    result_type,
    blocked_legality,
    1,
  )
  assert_true(blocked_evidence.blocks_result_removal)
}

///|
test "dae escaped result direct call evidence centralizes dropped and undropped suffix facts" {
  let result_type = @lib.TypeIdx::new(0U)
  let void_type = @lib.TypeIdx::new(1U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([result_type, result_type, void_type]))
  let type_indices = dae_collect_func_type_indices(mod_)
  let escaped = [true, true, true]
  let body = [
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
    ),
    @lib.Instruction::call(@lib.FuncIdx::new(2U)),
    @lib.Instruction::drop(),
  ]
  let evidence = dae_escaped_result_direct_call_evidence(
    body, mod_, type_indices, escaped,
  )
  assert_true(evidence.has_dropped_escaped_result_call)
  assert_true(evidence.has_undropped_escaped_result_call)
  match
    dae_dead_suffix_escaped_result_direct_call_evidence(
      body, mod_, type_indices, escaped,
    ) {
    Some(suffix_evidence) => {
      assert_true(suffix_evidence.has_dropped_escaped_result_call)
      assert_true(suffix_evidence.has_undropped_escaped_result_call)
    }
    None => fail("expected escaped-result dead-suffix direct-call evidence")
  }
  let void_only = dae_escaped_result_direct_call_evidence(
    [@lib.Instruction::call(@lib.FuncIdx::new(2U)), @lib.Instruction::drop()],
    mod_,
    type_indices,
    escaped,
  )
  assert_false(void_only.has_dropped_escaped_result_call)
  assert_false(void_only.has_undropped_escaped_result_call)
  match
    dae_dead_suffix_escaped_result_direct_call_evidence(
      [@lib.Instruction::call(@lib.FuncIdx::new(1U))],
      mod_,
      type_indices,
      escaped,
    ) {
    Some(_) => fail("dead-suffix escaped result evidence requires suffix")
    None => ()
  }
}

///|
test "dae original escaped result operand call facts share one module scan" {
  let source_type = @lib.TypeIdx::new(0U)
  let target_type = @lib.TypeIdx::new(1U)
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
      ),
    ),
  ])
  let mod_ = @lib.Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(
      @lib.FuncSec::new([source_type, target_type, source_type, source_type]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::unreachable_(),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::unreachable_(),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::unreachable_(),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let escaped = [true, false, true, false]
  let escaped_result_calls = dae_collect_original_dead_suffix_escaped_result_call_facts_with_escaped(
    mod_, escaped,
  )
  let facts = dae_collect_original_escaped_result_operand_call_facts_with_escaped(
    mod_, escaped, escaped_result_calls,
  )
  assert_eq(facts.dead_suffix_escaped_result_operand_call_counts, [0, 1, 0, 0])
  assert_eq(facts.private_result_escaped_operand_call_counts, [0, 1, 0, 0])
  let no_code_mod = @lib.Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(
      @lib.FuncSec::new([source_type, target_type, source_type, source_type]),
    )
  let no_code = dae_collect_original_escaped_result_operand_call_facts_with_escaped(
    no_code_mod,
    escaped,
    dae_collect_original_dead_suffix_escaped_result_call_facts_with_escaped(
      no_code_mod, escaped,
    ),
  )
  assert_eq(no_code.dead_suffix_escaped_result_operand_call_counts, [0, 0, 0, 0])
  assert_eq(no_code.private_result_escaped_operand_call_counts, [0, 0, 0, 0])
}

///|
test "dae original dead suffix escaped result call facts share one module scan" {
  let result_type = @lib.TypeIdx::new(0U)
  let void_type = @lib.TypeIdx::new(1U)
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
    ),
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  ])
  let mod_ = @lib.Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(@lib.FuncSec::new([result_type, result_type, void_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::unreachable_(),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
            ),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::unreachable_(),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let facts = dae_collect_original_dead_suffix_escaped_result_call_facts_with_escaped(
    mod_,
    [true, true, true],
  )
  assert_eq(facts.dropped_calls, [true, false, false])
  assert_eq(facts.undropped_calls, [true, false, false])
  let no_code_mod = @lib.Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(@lib.FuncSec::new([result_type, result_type, void_type]))
  let no_code = dae_collect_original_dead_suffix_escaped_result_call_facts_with_escaped(
    no_code_mod,
    [true, true, true],
  )
  assert_eq(no_code.dropped_calls, [false, false, false])
  assert_eq(no_code.undropped_calls, [false, false, false])
}

///|
test "dae dead suffix direct target evidence centralizes dropped and undropped target lists" {
  let imported = 1
  let defined = 5
  let body = [
    @lib.Instruction::call(@lib.FuncIdx::new(4U)),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::call(@lib.FuncIdx::new(3U)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::return_call(@lib.FuncIdx::new(5U)),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
  ]
  match dae_dead_suffix_direct_target_evidence(body, imported, defined) {
    Some(evidence) => {
      assert_eq(evidence.direct_targets, [0, 1, 2, 2])
      assert_eq(evidence.dropped_direct_targets, [0])
      assert_eq(evidence.undropped_direct_targets, [1, 4, 2])
    }
    None => fail("expected dead-suffix direct target evidence")
  }
  match
    dae_dead_suffix_direct_target_evidence(
      [@lib.Instruction::call(@lib.FuncIdx::new(1U))],
      imported,
      defined,
    ) {
    Some(_) => fail("dead-suffix direct target evidence requires suffix")
    None => ()
  }
}

///|
test "dae dropped result scope direct call evidence centralizes selected caller facts" {
  let callee = @lib.FuncIdx::new(2U)
  let funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee), @lib.Instruction::drop()]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee)]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::unreachable_(),
        @lib.Instruction::call(callee),
      ]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::unreachable_(),
        @lib.Instruction::return_call(callee),
      ]),
    ),
  ]
  let scope = dae_dropped_result_scope_from_optional(
    funcs.length(),
    Some([0, 1, 2, 3, -1, 99]),
  )
  let live_evidence = dae_dropped_result_scope_direct_call_evidence(
    funcs, scope, 2, -1,
  )
  assert_eq(live_evidence.direct_call_count, 3)
  assert_eq(live_evidence.dropped_direct_call_count, 1)
  assert_true(live_evidence.has_direct_call)
  assert_true(live_evidence.has_undropped_direct_call)
  assert_true(live_evidence.has_live_undropped_direct_call)
  let skipped_live_evidence = dae_dropped_result_scope_direct_call_evidence(
    funcs, scope, 2, 1,
  )
  assert_eq(skipped_live_evidence.direct_call_count, 2)
  assert_eq(skipped_live_evidence.dropped_direct_call_count, 1)
  assert_true(skipped_live_evidence.has_direct_call)
  assert_true(skipped_live_evidence.has_undropped_direct_call)
  assert_false(skipped_live_evidence.has_live_undropped_direct_call)
}

///|
test "dae tail call boundary evidence centralizes rewrite and result blockers" {
  let direct_callee = @lib.FuncIdx::new(1U)
  let type_idx = @lib.TypeIdx::new(0U)
  let direct_only = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::return_call(direct_callee)]),
    ),
  ]
  let direct_evidence = dae_tail_call_boundary_evidence(direct_only)
  assert_true(direct_evidence.has_direct_tail_call)
  assert_false(direct_evidence.has_indirect_tail_call)
  assert_false(direct_evidence.blocks_direct_call_rewrite)
  assert_true(direct_evidence.blocks_result_removal)
  let indirect_nested = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::return_call_ref(type_idx)]),
        ),
      ]),
    ),
  ]
  let indirect_evidence = dae_tail_call_boundary_evidence(indirect_nested)
  assert_false(indirect_evidence.has_direct_tail_call)
  assert_true(indirect_evidence.has_indirect_tail_call)
  assert_true(indirect_evidence.blocks_direct_call_rewrite)
  assert_true(indirect_evidence.blocks_result_removal)
  let clear_evidence = dae_tail_call_boundary_evidence([])
  assert_false(clear_evidence.has_direct_tail_call)
  assert_false(clear_evidence.has_indirect_tail_call)
  assert_false(clear_evidence.blocks_direct_call_rewrite)
  assert_false(clear_evidence.blocks_result_removal)
}

///|
test "dae dropped result repair plan centralizes dead suffix cleanup" {
  let callee = @lib.FuncIdx::new(2U)
  let scope = dae_dropped_result_scope_from_optional(3, Some([0, 1, 2]))
  let no_param_type = @lib.TypeIdx::new(0U)
  let one_param_type = @lib.TypeIdx::new(1U)
  let type_indices = [no_param_type, one_param_type, no_param_type]
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
  ])
  let funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::unreachable_(),
        @lib.Instruction::call(callee),
      ]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::unreachable_(),
        @lib.Instruction::call(callee),
      ]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee), @lib.Instruction::drop()]),
    ),
  ]
  let no_param_plan = dae_dropped_result_repair_plan(
    scope,
    2,
    2,
    DaeRepairDeadSuffixNoParamCallers,
    remove_dropped_call_drops=true,
    remove_dropped_call_drops_before_repair=false,
  )
  assert_true(dae_dropped_result_repair_plan_removes_call_drops(no_param_plan))
  let no_param_funcs = funcs.copy()
  dae_apply_dropped_result_repair_plan(
    no_param_funcs, type_indices, type_sec, 0, no_param_plan,
  )
  assert_eq(
    no_param_funcs[0],
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
  )
  assert_eq(no_param_funcs[1], funcs[1])
  assert_eq(
    no_param_funcs[2],
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee)]),
    ),
  )
  let all_callers_plan = dae_dropped_result_repair_plan(
    scope,
    2,
    1,
    DaeRepairDeadSuffixAllCallers,
    remove_dropped_call_drops=false,
    remove_dropped_call_drops_before_repair=false,
  )
  assert_false(
    dae_dropped_result_repair_plan_removes_call_drops(all_callers_plan),
  )
  let all_callers_funcs = funcs.copy()
  dae_apply_dropped_result_repair_plan(
    all_callers_funcs, type_indices, type_sec, 0, all_callers_plan,
  )
  assert_eq(
    all_callers_funcs[0],
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
  )
  assert_eq(all_callers_funcs[1], funcs[1])
  assert_eq(all_callers_funcs[2], funcs[2])
}

///|
test "dae dropped-result callee application centralizes repair and finalization" {
  let result_type = @lib.TypeIdx::new(0U)
  let callee = @lib.FuncIdx::new(2U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([result_type, result_type, result_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::unreachable_(),
            @lib.Instruction::call(callee),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(callee),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
        ),
      ]),
    )
  let context = match dae_module_signature_context(mod_, 2, copy_funcs=true) {
    Some(context) => context
    None => fail("expected module signature context")
  }
  let scope = dae_dropped_result_scope_from_optional(3, None)
  let repair = dae_dropped_result_repair_plan(
    scope,
    2,
    2,
    DaeRepairDeadSuffixNoParamCallers,
    remove_dropped_call_drops=true,
    remove_dropped_call_drops_before_repair=false,
  )
  let finalization = dae_module_code_finalization_plan(
    [],
    [],
    DaeTouchModuleCodeChangedFuncs,
  )
  let rewritten_callee = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::drop(),
    ]),
  )
  let result = dae_apply_dropped_result_callee_rewrite(
    mod_,
    context,
    dae_collect_func_type_indices(mod_),
    0,
    context.funcs.copy(),
    rewritten_callee,
    repair,
    finalization,
  )
  assert_true(result.changed)
  assert_eq(result.primary_def, 2)
  assert_eq(result.touched, [true, true, true])
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(dead_suffix_caller)) = funcs[0]
      let @lib.Func(_, @lib.Expr(dropped_caller)) = funcs[1]
      assert_eq(dead_suffix_caller, [@lib.Instruction::unreachable_()])
      assert_eq(dropped_caller, [@lib.Instruction::call(callee)])
      assert_eq(funcs[2], rewritten_callee)
    }
    None => fail("expected rewritten code section")
  }
  let rewritten_type_indices = dae_collect_func_type_indices(result.mod_out)
  match dae_resolve_func_type(result.mod_out, rewritten_type_indices, 2) {
    Some(@lib.FuncType(params, results)) => {
      assert_eq(params, [])
      assert_eq(results, [])
    }
    None => fail("expected rewritten callee type")
  }
}

///|
test "dae dropped result unreachable callee rewrite centralizes application" {
  let result_type = @lib.TypeIdx::new(0U)
  let callee = @lib.FuncIdx::new(1U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([result_type, result_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::unreachable_(),
            @lib.Instruction::call(callee),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
        ),
      ]),
    )
  let context = match dae_dropped_result_module_context(mod_, 1) {
    Some(context) => context
    None => fail("expected dropped-result module context")
  }
  let plan = dae_dropped_result_unreachable_callee_rewrite_plan(
    context,
    DaeRepairDeadSuffixNoParamCallers,
    [],
  )
  assert_eq(plan.finalization.next_params, [])
  assert_eq(plan.finalization.next_results, [])
  assert_true(dae_dropped_result_repair_plan_removes_call_drops(plan.repair))
  let result = dae_apply_dropped_result_unreachable_callee_rewrite(
    mod_, context, plan,
  )
  assert_true(result.changed)
  assert_eq(result.primary_def, 1)
  assert_eq(result.touched, [false, true])
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(caller_body)) = funcs[0]
      let @lib.Func(callee_locals, @lib.Expr(callee_body)) = funcs[1]
      assert_eq(caller_body, [@lib.Instruction::unreachable_()])
      assert_eq(callee_locals, @lib.Locals::empty())
      assert_eq(callee_body, [@lib.Instruction::unreachable_()])
    }
    None => fail("expected rewritten code section")
  }
  let rewritten_type_indices = dae_collect_func_type_indices(result.mod_out)
  match dae_resolve_func_type(result.mod_out, rewritten_type_indices, 1) {
    Some(@lib.FuncType(params, results)) => {
      assert_eq(params, [])
      assert_eq(results, [])
    }
    None => fail("expected rewritten callee type")
  }
}

///|
test "dae module signature finalization preserves code reconstruction boundary" {
  let result_type = @lib.TypeIdx::new(0U)
  let callee = @lib.FuncIdx::new(1U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([result_type, result_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(callee),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
        ),
      ]),
    )
  let context = match dae_module_signature_context(mod_, 1, copy_funcs=false) {
    Some(context) => context
    None => fail("expected module signature context")
  }
  let result = dae_apply_module_signature_finalization(mod_, context, [], [])
  assert_true(result.changed)
  assert_eq(result.primary_def, 1)
  assert_eq(result.touched, [false, true])
  assert_eq(result.mod_out.code_sec, mod_.code_sec)
  let rewritten_type_indices = dae_collect_func_type_indices(result.mod_out)
  match dae_resolve_func_type(result.mod_out, rewritten_type_indices, 1) {
    Some(@lib.FuncType(params, results)) => {
      assert_eq(params, [])
      assert_eq(results, [])
    }
    None => fail("expected finalized callee type")
  }
}

///|
test "dae module code finalization installs code with explicit touched policy" {
  let result_type = @lib.TypeIdx::new(0U)
  let callee = @lib.FuncIdx::new(1U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([result_type, result_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(callee),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
        ),
      ]),
    )
  let context = match dae_module_signature_context(mod_, 1, copy_funcs=false) {
    Some(context) => context
    None => fail("expected module signature context")
  }
  let rewritten_funcs = context.funcs.copy()
  rewritten_funcs[0] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::call(callee)]),
  )
  rewritten_funcs[1] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::drop(),
    ]),
  )
  let plan = dae_module_code_finalization_plan(
    [],
    [],
    DaeTouchModuleCodeChangedFuncs,
  )
  let result = dae_apply_module_code_finalization(
    mod_, context, rewritten_funcs, plan,
  )
  assert_true(result.changed)
  assert_eq(result.primary_def, 1)
  assert_eq(result.touched, [true, true])
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_eq(funcs, rewritten_funcs)
    None => fail("expected finalized code section")
  }
  let rewritten_type_indices = dae_collect_func_type_indices(result.mod_out)
  match dae_resolve_func_type(result.mod_out, rewritten_type_indices, 1) {
    Some(@lib.FuncType(params, results)) => {
      assert_eq(params, [])
      assert_eq(results, [])
    }
    None => fail("expected finalized callee type")
  }
}

///|
test "dae verified uniform-constant candidate uses shared boundary rewrite transactionally" {
  let caller_type = @lib.TypeIdx::new(0U)
  let callee_type = @lib.TypeIdx::new(1U)
  let callee = @lib.FuncIdx::new(1U)
  let params = [@lib.ValType::i32(), @lib.ValType::i32()]
  let caller = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(5)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::i32_const(@lib.I32(9)),
      @lib.Instruction::call(callee),
    ]),
  )
  let callee_func = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::drop(),
    ]),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func(params, [])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([caller_type, callee_type]))
    .with_code_sec(@lib.CodeSec::new([caller, callee_func]))
  let local_use = dae_local_use_for_callee(callee_func, 2, 1, 2)
  let remove = [false, true]
  let expected : Array[@lib.Instruction?] = [
    None,
    Some(@lib.Instruction::i32_const(@lib.I32(9))),
  ]
  let result = dae_try_rewrite_verified_uniform_const_candidate(
    mod_,
    1,
    params,
    remove,
    expected,
    local_use,
    1,
    [0],
  )
  assert_true(result.changed)
  assert_eq(result.primary_def, 1)
  assert_eq(result.touched, [true, true])
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(caller_body)) = funcs[0]
      assert_eq(caller_body, [
        @lib.Instruction::i32_const(@lib.I32(5)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::call(callee),
      ])
    }
    None => fail("expected rewritten code section")
  }
  let rewritten_type_indices = dae_collect_func_type_indices(result.mod_out)
  match dae_resolve_func_type(result.mod_out, rewritten_type_indices, 1) {
    Some(@lib.FuncType(rewritten_params, results)) => {
      assert_eq(rewritten_params, [@lib.ValType::i32()])
      assert_eq(results, [])
    }
    None => fail("expected rewritten callee type")
  }
  let mismatched : Array[@lib.Instruction?] = [
    None,
    Some(@lib.Instruction::i32_const(@lib.I32(8))),
  ]
  let rejected = dae_try_rewrite_verified_uniform_const_candidate(
    mod_,
    1,
    params,
    remove,
    mismatched,
    local_use,
    1,
    [0],
  )
  assert_false(rejected.changed)
  assert_eq(rejected.primary_def, -1)
  assert_eq(rejected.touched, [])
  assert_eq(rejected.mod_out, mod_)
  let forwarded_params = [
    @lib.ValType::i32(),
    @lib.ValType::i32(),
    @lib.ValType::i32(),
    @lib.ValType::i32(),
  ]
  let forwarded_caller = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::i32_const(@lib.I32(9)),
      @lib.Instruction::call(callee),
      @lib.Instruction::i32_const(@lib.I32(1)),
    ]),
  )
  let forwarded_callee = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(2)),
    ]),
  )
  let forwarded_mod = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
              [@lib.ValType::i32(), @lib.ValType::i32()],
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(forwarded_params, [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([caller_type, callee_type]))
    .with_code_sec(@lib.CodeSec::new([forwarded_caller, forwarded_callee]))
  let forwarded_local_use = dae_local_use_for_callee(forwarded_callee, 4, 1, 4)
  let forwarded_remove = [false, false, false, true]
  let forwarded_expected : Array[@lib.Instruction?] = [
    None,
    None,
    None,
    Some(@lib.Instruction::i32_const(@lib.I32(9))),
  ]
  let forwarded_result = dae_try_rewrite_verified_uniform_const_candidate(
    forwarded_mod,
    1,
    forwarded_params,
    forwarded_remove,
    forwarded_expected,
    forwarded_local_use,
    1,
    [0],
  )
  assert_true(forwarded_result.changed)
}

///|
test "dae verified constant suffix candidate preserves ambient multivalue call operands transactionally" {
  let caller_type = @lib.TypeIdx::new(0U)
  let callee_type = @lib.TypeIdx::new(1U)
  let block_type = @lib.TypeIdx::new(2U)
  let callee = @lib.FuncIdx::new(1U)
  let params = [
    @lib.ValType::i32(),
    @lib.ValType::i32(),
    @lib.ValType::i32(),
    @lib.ValType::i32(),
  ]
  let block_body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::i32_const(@lib.I32(1024)),
    @lib.Instruction::call(callee),
  ]
  let caller = @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::type_idx(block_type),
        @lib.Expr::new(block_body),
      ),
      @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    ]),
  )
  let callee_func = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_const(@lib.I32(2)),
    ]),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
              [@lib.ValType::i32()],
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(params, [
              @lib.ValType::i32(),
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([caller_type, callee_type]))
    .with_code_sec(@lib.CodeSec::new([caller, callee_func]))
  let local_use = dae_local_use_for_callee(callee_func, 4, 1, 4)
  let result = dae_try_rewrite_verified_materialized_const_suffix_candidate(
    mod_,
    1,
    params,
    [@lib.Instruction::i32_const(@lib.I32(1024))],
    local_use,
    1,
    [0],
  )
  assert_true(result.changed)
  assert_eq(result.primary_def, 1)
  assert_eq(result.touched, [true, true])
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(caller_body)) = funcs[0]
      match caller_body[0] {
        @lib.Block(_, @lib.Expr(rewritten_block)) => {
          let expected = block_body.copy()
          ignore(expected.remove(expected.length() - 2))
          assert_eq(rewritten_block, expected)
        }
        _ => fail("expected preserved multivalue block caller")
      }
    }
    None => fail("expected rewritten code section")
  }
  let rewritten_type_indices = dae_collect_func_type_indices(result.mod_out)
  match dae_resolve_func_type(result.mod_out, rewritten_type_indices, 1) {
    Some(@lib.FuncType(rewritten_params, results)) => {
      assert_eq(rewritten_params, [
        @lib.ValType::i32(),
        @lib.ValType::i32(),
        @lib.ValType::i32(),
      ])
      assert_eq(results, [@lib.ValType::i32(), @lib.ValType::i32()])
    }
    None => fail("expected rewritten callee type")
  }
  let rejected = dae_try_rewrite_verified_materialized_const_suffix_candidate(
    mod_,
    1,
    params,
    [@lib.Instruction::i32_const(@lib.I32(9))],
    local_use,
    1,
    [0],
  )
  assert_false(rejected.changed)
  assert_eq(rejected.primary_def, -1)
  assert_eq(rejected.touched, [])
  assert_eq(rejected.mod_out, mod_)
}

///|
test "dae module code rewrite finalization uses current sections transactionally" {
  let result_type = @lib.TypeIdx::new(0U)
  let void_type = @lib.TypeIdx::new(1U)
  let callee = @lib.FuncIdx::new(1U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([result_type, result_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(callee),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
        ),
      ]),
    )
  let rewritten_funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee)]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::nop()]),
    ),
  ]
  let result = dae_finalize_module_code_rewrite(
    mod_,
    1,
    rewritten_funcs,
    [],
    [],
    DaeTouchModuleCodeChangedFuncs,
  )
  assert_true(result.changed)
  assert_eq(result.primary_def, 1)
  assert_eq(result.touched, [true, true])
  assert_eq(result.mod_out.type_sec, mod_.type_sec)
  match result.mod_out.func_sec {
    Some(@lib.FuncSec(type_idxs)) =>
      assert_eq(type_idxs, [result_type, void_type])
    None => fail("expected finalized function section")
  }
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_eq(funcs, rewritten_funcs)
    None => fail("expected finalized code section")
  }
  let rejected = dae_finalize_module_code_rewrite(
    mod_,
    1,
    [rewritten_funcs[0]],
    [],
    [],
    DaeTouchModuleCodeChangedFuncs,
  )
  assert_false(rejected.changed)
  assert_eq(rejected.primary_def, -1)
  assert_eq(rejected.touched, [])
  assert_eq(rejected.mod_out, mod_)
}

///|
test "dae dropped-result scope application centralizes live and anywhere policies" {
  let callee = @lib.FuncIdx::new(2U)
  let original_body = [
    @lib.Instruction::call(callee),
    @lib.Instruction::drop(),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(callee),
    @lib.Instruction::drop(),
  ]
  let untouched = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new(original_body.copy()),
  )
  let live_funcs = [
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(original_body.copy())),
    untouched,
  ]
  let scope = DaeDroppedResultScope::{ caller_defs: [0] }
  let live_rewrites = dae_rewrite_dropped_result_calls_in_scope_with_policy(
    live_funcs,
    scope,
    2,
    stop_at_unreachable_root=true,
  )
  assert_eq(live_rewrites, 1)
  let @lib.Func(_, @lib.Expr(live_body)) = live_funcs[0]
  assert_eq(live_body, [
    @lib.Instruction::call(callee),
    @lib.Instruction::unreachable_(),
  ])
  assert_eq(live_funcs[1], untouched)
  let anywhere_funcs = [
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(original_body.copy())),
    untouched,
  ]
  let anywhere_rewrites = dae_rewrite_dropped_result_calls_in_scope_with_policy(
    anywhere_funcs,
    scope,
    2,
    stop_at_unreachable_root=false,
  )
  assert_eq(anywhere_rewrites, 2)
  let @lib.Func(_, @lib.Expr(anywhere_body)) = anywhere_funcs[0]
  assert_eq(anywhere_body, [
    @lib.Instruction::call(callee),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(callee),
  ])
  assert_eq(anywhere_funcs[1], untouched)
}

///|
test "dae direct-caller scope application is transactional and count verified" {
  let callee = @lib.FuncIdx::new(3U)
  let original_funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee)]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::nop()]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
  ]
  let visited : Array[Int] = []
  let rewrite = fn(func, def_idx) {
    visited.push(def_idx)
    if def_idx == 0 {
      {
        func: @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(callee),
            @lib.Instruction::drop(),
          ]),
        ),
        calls_rewritten: 2,
        changed: true,
        ok: true,
      }
    } else {
      { func, calls_rewritten: 0, changed: false, ok: true }
    }
  }
  let application = dae_apply_direct_caller_scope_rewrite(
    original_funcs,
    [-1, 0, 1, 4],
    rewrite,
  )
  assert_true(application.ok)
  assert_true(application.changed)
  assert_eq(application.calls_rewritten, 2)
  assert_eq(application.changed_defs, [true, false, false])
  assert_eq(visited, [0, 1])
  assert_eq(application.funcs[1], original_funcs[1])
  assert_eq(application.funcs[2], original_funcs[2])
  let failed = dae_apply_direct_caller_scope_rewrite(original_funcs, [0, 1], fn(
    func,
    def_idx,
  ) {
    if def_idx == 0 {
      {
        func: @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::drop()]),
        ),
        calls_rewritten: 1,
        changed: true,
        ok: true,
      }
    } else {
      { func, calls_rewritten: 0, changed: false, ok: false }
    }
  })
  assert_false(failed.ok)
  assert_false(failed.changed)
  assert_eq(failed.calls_rewritten, 0)
  assert_eq(failed.changed_defs, [false, false, false])
  assert_eq(failed.funcs, original_funcs)
}

///|
test "dae scalar materialization plan centralizes cleanup and finalization" {
  let source =
    #|(module
    #|  (func $target (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 0
    #|    i32.add)
    #|  (func (export "run") (result i32)
    #|    i32.const 4
    #|    call $target))
  let mod_ = pass_test_module_from_wat(source)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("expected code section")
  }
  let local_use = dae_local_use_for_callee(funcs[0], 1, 0, 1)
  let result = dae_try_rewrite_candidate(
    mod_,
    0,
    [true],
    [Some(@lib.Instruction::i32_const(4))],
    local_use,
    1,
    [1],
  )
  assert_true(result.changed)
  assert_eq(result.primary_def, 0)
  assert_eq(result.touched, [true, true])
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(callee_body)) = funcs[0]
      let @lib.Func(_, @lib.Expr(caller_body)) = funcs[1]
      assert_eq(callee_body, [@lib.Instruction::i32_const(4)])
      assert_eq(caller_body, [@lib.Instruction::call(@lib.FuncIdx::new(0U))])
    }
    None => fail("expected finalized code section")
  }
  let rewritten_type_indices = dae_collect_func_type_indices(result.mod_out)
  match dae_resolve_func_type(result.mod_out, rewritten_type_indices, 0) {
    Some(@lib.FuncType(params, results)) => {
      assert_eq(params, [])
      assert_eq(results, [@lib.ValType::i32()])
    }
    None => fail("expected finalized callee type")
  }
}

///|
test "dae dropped result module finalization preserves touched policy" {
  let result_type = @lib.TypeIdx::new(0U)
  let callee = @lib.FuncIdx::new(1U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([result_type, result_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(callee),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
        ),
      ]),
    )
  let context = match dae_dropped_result_module_context(mod_, 1) {
    Some(context) => context
    None => fail("expected dropped-result module context")
  }
  let rewritten_funcs = context.signature.funcs.copy()
  rewritten_funcs[0] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::call(callee)]),
  )
  rewritten_funcs[1] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::drop(),
    ]),
  )
  let plan = dae_module_code_finalization_plan(
    [],
    [],
    DaeTouchModuleCodeChangedFuncs,
  )
  assert_eq(plan.next_params, [])
  assert_eq(plan.next_results, [])
  let result = dae_apply_module_code_finalization(
    mod_,
    context.signature,
    rewritten_funcs,
    plan,
  )
  assert_true(result.changed)
  assert_eq(result.primary_def, 1)
  assert_eq(result.touched, [true, true])
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_eq(funcs, rewritten_funcs)
    None => fail("expected finalized code section")
  }
  let rewritten_type_indices = dae_collect_func_type_indices(result.mod_out)
  match dae_resolve_func_type(result.mod_out, rewritten_type_indices, 1) {
    Some(@lib.FuncType(params, results)) => {
      assert_eq(params, [])
      assert_eq(results, [])
    }
    None => fail("expected finalized callee type")
  }
}

///|
test "dae uniform const boundary facts carry direct caller evidence" {
  let caller_type = @lib.TypeIdx::new(0U)
  let callee_type = @lib.TypeIdx::new(1U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], []),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([caller_type, callee_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(42)),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let boundary_facts = dae_make_call_boundary_facts(
    [false, false],
    [false, false],
    [[], [0]],
  )
  match
    dae_collect_uniform_const_actuals_from_boundary_facts(
      mod_,
      1,
      1,
      [caller_type, callee_type],
      boundary_facts,
    ) {
    Some(values) =>
      match values[0] {
        Some(@lib.I32Const(@lib.I32(value))) => assert_eq(value, 42)
        Some(_) => fail("expected i32.const uniform actual")
        None => fail("expected uniform actual from boundary direct caller")
      }
    None => fail("expected boundary-carried uniform actual collection")
  }
}

///|
test "dae uniform const candidate recorder centralizes merge invalidation" {
  let seen = Array::make(2, false)
  let invalid = Array::make(2, false)
  let candidates : Array[@lib.Instruction?] = Array::make(2, None)
  let one = @lib.Instruction::i32_const(@lib.I32(1))
  let two = @lib.Instruction::i32_const(@lib.I32(2))
  let seven = @lib.Instruction::i64_const(@lib.I64(7L))
  dae_record_uniform_const_candidate(seen, invalid, candidates, 0, one)
  assert_true(seen[0])
  assert_false(invalid[0])
  match candidates[0] {
    Some(candidate) => assert_true(dae_materialized_const_equal(candidate, one))
    None => fail("expected first candidate to be recorded")
  }
  dae_record_uniform_const_candidate(seen, invalid, candidates, 0, one)
  assert_false(invalid[0])
  dae_record_uniform_const_candidate(seen, invalid, candidates, 0, two)
  assert_true(invalid[0])
  dae_record_uniform_const_candidate(seen, invalid, candidates, 1, seven)
  assert_true(seen[1])
  assert_false(invalid[1])
  match candidates[1] {
    Some(candidate) =>
      assert_true(dae_materialized_const_equal(candidate, seven))
    None => fail("expected independent candidate lane to be recorded")
  }
}

///|
test "dae materialized v128 constants compare all bytes" {
  let first = @lib.Instruction::v128_const(
    b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08', b'\x09',
    b'\x0a', b'\x0b', b'\x0c', b'\x0d', b'\x0e', b'\x0f', b'\x10',
  )
  let same = @lib.Instruction::v128_const(
    b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08', b'\x09',
    b'\x0a', b'\x0b', b'\x0c', b'\x0d', b'\x0e', b'\x0f', b'\x10',
  )
  let different = @lib.Instruction::v128_const(
    b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08', b'\x09',
    b'\x0a', b'\x0b', b'\x0c', b'\x0d', b'\x0e', b'\x0f', b'\x11',
  )
  assert_true(dae_materialized_const_equal(first, same))
  assert_false(dae_materialized_const_equal(first, different))
}

///|
test "dae materialized ref.func constants compare function identity" {
  let first = @lib.Instruction::ref_func(@lib.FuncIdx::new(1U))
  let same = @lib.Instruction::ref_func(@lib.FuncIdx::new(1U))
  let different = @lib.Instruction::ref_func(@lib.FuncIdx::new(2U))
  assert_true(dae_materialized_const_equal(first, same))
  assert_false(dae_materialized_const_equal(first, different))
}

///|
test "dae materialized reference conversion expressions compare exact identity" {
  let first_body = [
    @lib.Instruction::i32_const(@lib.I32::new(7)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::extern_convert_any(),
  ]
  let same_body = first_body.copy()
  let different_body = [
    @lib.Instruction::i32_const(@lib.I32::new(8)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::extern_convert_any(),
  ]
  assert_true(dae_instrs_are_materializable_ref_const_expr(first_body))
  assert_false(
    dae_instrs_are_materializable_ref_const_expr([
      @lib.Instruction::i32_const(@lib.I32::new(7)),
      @lib.Instruction::ref_i31(),
      @lib.Instruction::drop(),
    ]),
  )
  let first = @lib.Instruction::block(
    @lib.BlockType::val_type(@lib.ValType::externref()),
    @lib.Expr::new(first_body),
  )
  let same = @lib.Instruction::block(
    @lib.BlockType::val_type(@lib.ValType::externref()),
    @lib.Expr::new(same_body),
  )
  let different = @lib.Instruction::block(
    @lib.BlockType::val_type(@lib.ValType::externref()),
    @lib.Expr::new(different_body),
  )
  assert_true(dae_materialized_const_equal(first, same))
  assert_false(dae_materialized_const_equal(first, different))
}

///|
test "dae control result slices centralize flat and return arm bounds" {
  let pair_type = @lib.TypeIdx::new(0U)
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i64()]),
        ),
      ),
    ]),
  )
  let block_arm = [
    @lib.Instruction::block(
      @lib.BlockType::type_idx(pair_type),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i64_const(@lib.I64(2L)),
      ]),
    ),
  ]
  match dae_single_block_result_carrier_evidence(mod_, block_arm, 2) {
    Some(evidence) => {
      assert_eq(evidence.result_count, 2)
      assert_eq(evidence.body.length(), 2)
      assert_false(evidence.body_has_effect_or_branch)
      assert_true(evidence.effect_free_body.effect_free)
      assert_eq(evidence.effect_free_body.body_length, 2)
    }
    None => fail("expected shared single-block result carrier evidence")
  }
  match
    dae_flat_multi_result_suffix_evidence(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i64_const(@lib.I64(2L)),
      ],
      2,
      false,
    ) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 2)
      assert_eq(evidence.result_count, 2)
      assert_false(evidence.has_terminal_return)
    }
    None => fail("expected shared flat result suffix evidence")
  }
  match dae_find_multi_result_control_slice(mod_, block_arm, 2) {
    Some(slice) => {
      assert_eq(slice.slice.start, 0)
      assert_eq(slice.slice.end, 2)
      assert_eq(slice.result_count, 2)
      assert_eq(slice.carrier_kind, 1)
      assert_true(slice.flattened)
      assert_false(slice.terminal_return)
      assert_false(slice.slice.has_effect_or_branch)
    }
    None => fail("expected reusable flattened block result slice")
  }
  let return_arm = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i64_const(@lib.I64(2L)),
    @lib.Instruction::return_(),
  ]
  match dae_flat_multi_result_suffix_evidence(return_arm, 2, true) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 2)
      assert_eq(evidence.result_count, 2)
      assert_true(evidence.has_terminal_return)
    }
    None => fail("expected shared terminal-return result suffix evidence")
  }
  match
    dae_find_multi_result_control_slice(
      mod_,
      return_arm,
      2,
      require_terminal_return=true,
    ) {
    Some(slice) => {
      assert_eq(slice.slice.start, 0)
      assert_eq(slice.slice.end, 2)
      assert_eq(slice.result_count, 2)
      assert_eq(slice.carrier_kind, 0)
      assert_false(slice.flattened)
      assert_true(slice.terminal_return)
      assert_false(slice.slice.has_effect_or_branch)
    }
    None => fail("expected reusable terminal-return result slice")
  }
}

///|
test "dae control result GC evidence centralizes lane candidates and rewrites" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let body = [
    @lib.Instruction::struct_new_default(leaf_type),
    @lib.Instruction::block(
      @lib.BlockType::val_type(base_ref),
      @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
    ),
  ]
  let slice = match
    dae_make_multi_result_control_slice(body, 0, 2, 0, false, false) {
    Some(slice) => slice
    None => fail("expected valid multi-result control slice")
  }
  match
    dae_control_result_slice_gc_evidence(
      mod_,
      [],
      None,
      slice,
      [base_ref, base_ref],
      require_refined=true,
    ) {
    Some(evidence) => {
      assert_true(evidence.saw_candidate)
      assert_true(evidence.body_changed)
      assert_eq(evidence.candidates[0], Some(expected_leaf_ref))
      assert_eq(evidence.candidates[1], Some(expected_leaf_ref))
      assert_eq(evidence.refined_candidates[0], Some(expected_leaf_ref))
      assert_eq(evidence.refined_candidates[1], Some(expected_leaf_ref))
      assert_eq(evidence.rewritten_body[0], body[0])
      assert_eq(
        evidence.rewritten_body[1],
        @lib.Instruction::block(
          @lib.BlockType::val_type(expected_leaf_ref),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
        ),
      )
    }
    None => fail("expected reusable per-lane control GC evidence")
  }
}

///|
test "dae single-result control pair GC evidence centralizes LUB rewrites" {
  let base_type = @lib.TypeIdx::new(0U)
  let left_type = @lib.TypeIdx::new(1U)
  let right_type = @lib.TypeIdx::new(2U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_common_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(base_type)),
  )
  let expected_left_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(left_type), exact=true),
  )
  let expected_right_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(right_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let then_body = [@lib.Instruction::struct_new_default(left_type)]
  let else_body = [@lib.Instruction::struct_new_default(right_type)]
  let then_rewrite = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(expected_left_ref),
      @lib.Expr::new([@lib.Instruction::struct_new_default(left_type)]),
    ),
  ]
  let else_rewrite = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(expected_right_ref),
      @lib.Expr::new([@lib.Instruction::struct_new_default(right_type)]),
    ),
  ]
  match
    dae_single_result_control_pair_gc_evidence(
      mod_,
      then_body,
      expected_left_ref,
      Some(then_rewrite),
      else_body,
      expected_right_ref,
      Some(else_rewrite),
      base_ref,
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, expected_common_ref)
      assert_eq(evidence.rewritten_then_body[0], then_rewrite[0])
      assert_eq(evidence.rewritten_else_body[0], else_rewrite[0])
    }
    None => fail("expected reusable single-result control pair GC evidence")
  }
  match
    dae_single_result_control_pair_gc_evidence(
      mod_,
      then_body,
      expected_left_ref,
      None,
      else_body,
      expected_right_ref,
      None,
      base_ref,
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, expected_common_ref)
      assert_eq(evidence.rewritten_then_body[0], then_body[0])
      assert_eq(evidence.rewritten_else_body[0], else_body[0])
    }
    None => fail("expected no-rewrite single-result control pair evidence")
  }
}

///|
test "dae single-result control pair application centralizes if rewrites" {
  let leaf_type = @lib.TypeIdx::new(1U)
  let candidate = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let then_body = [@lib.Instruction::struct_new_default(leaf_type)]
  let else_body = [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]
  let evidence : DaeSingleResultControlPairGcEvidence = {
    candidate,
    rewritten_then_body: then_body,
    rewritten_else_body: else_body,
  }
  match dae_apply_single_result_control_pair_gc_evidence(evidence, false) {
    Some((rewritten, application)) => {
      assert_false(application.result_is_void)
      assert_eq(application.then_body_length, then_body.length())
      assert_eq(application.else_body_length, else_body.length())
      assert_eq(
        rewritten,
        @lib.Instruction::if_(
          @lib.BlockType::val_type(candidate),
          then_body,
          Some(else_body),
        ),
      )
    }
    None => fail("expected value-result if application evidence")
  }
  match dae_apply_single_result_control_pair_gc_evidence(evidence, true) {
    Some((rewritten, application)) => {
      assert_true(application.result_is_void)
      assert_eq(
        rewritten,
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          then_body,
          Some(else_body),
        ),
      )
    }
    None => fail("expected void-result if application evidence")
  }
}

///|
test "dae single-result control pair repair evidence gathers arm candidates" {
  let base_type = @lib.TypeIdx::new(0U)
  let left_type = @lib.TypeIdx::new(1U)
  let right_type = @lib.TypeIdx::new(2U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_common_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(base_type)),
  )
  let expected_left_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(left_type), exact=true),
  )
  let expected_right_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(right_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let then_body = [@lib.Instruction::struct_new_default(left_type)]
  let else_body = [@lib.Instruction::struct_new_default(right_type)]
  let then_rewrite = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(expected_left_ref),
      @lib.Expr::new(then_body),
    ),
  ]
  let else_rewrite = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(expected_right_ref),
      @lib.Expr::new(else_body),
    ),
  ]
  match
    dae_single_result_control_pair_repair_evidence(
      mod_,
      then_body,
      else_body,
      base_ref,
      false,
      fn(body) {
        if body == then_body {
          Some((expected_left_ref, Some(then_rewrite)))
        } else if body == else_body {
          Some((expected_right_ref, Some(else_rewrite)))
        } else {
          None
        }
      },
    ) {
    Some(evidence) => {
      assert_eq(evidence.pair.candidate, expected_common_ref)
      assert_false(evidence.application.result_is_void)
      assert_eq(evidence.application.then_body_length, then_rewrite.length())
      assert_eq(evidence.application.else_body_length, else_rewrite.length())
      assert_eq(
        evidence.rewritten,
        @lib.Instruction::if_(
          @lib.BlockType::val_type(expected_common_ref),
          then_rewrite,
          Some(else_rewrite),
        ),
      )
    }
    None => fail("expected request-backed if-arm repair evidence")
  }
  match
    dae_single_result_control_pair_repair_evidence(
      mod_,
      then_body,
      else_body,
      base_ref,
      true,
      fn(body) {
        if body == then_body {
          Some((expected_left_ref, None))
        } else if body == else_body {
          Some((expected_right_ref, None))
        } else {
          None
        }
      },
    ) {
    Some(evidence) => {
      assert_true(evidence.application.result_is_void)
      assert_eq(
        evidence.rewritten,
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          then_body,
          Some(else_body),
        ),
      )
    }
    None => fail("expected void-result if-arm repair evidence")
  }
}

///|
test "dae control result pair GC evidence centralizes terminal arm LUB rewrites" {
  let base_type = @lib.TypeIdx::new(0U)
  let left_type = @lib.TypeIdx::new(1U)
  let right_type = @lib.TypeIdx::new(2U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_common_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(base_type)),
  )
  let expected_left_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(left_type), exact=true),
  )
  let expected_right_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(right_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let then_body = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(base_ref),
      @lib.Expr::new([@lib.Instruction::struct_new_default(left_type)]),
    ),
  ]
  let else_body = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(base_ref),
      @lib.Expr::new([@lib.Instruction::struct_new_default(right_type)]),
    ),
  ]
  let then_slice = match
    dae_make_multi_result_control_slice(then_body, 0, 1, 0, false, false) {
    Some(slice) => slice
    None => fail("expected valid then result slice")
  }
  let else_slice = match
    dae_make_multi_result_control_slice(else_body, 0, 1, 0, false, false) {
    Some(slice) => slice
    None => fail("expected valid else result slice")
  }
  let then_evidence = match
    dae_control_result_slice_gc_evidence(mod_, [], None, then_slice, [base_ref]) {
    Some(evidence) => evidence
    None => fail("expected then control-result evidence")
  }
  let else_evidence = match
    dae_control_result_slice_gc_evidence(mod_, [], None, else_slice, [base_ref]) {
    Some(evidence) => evidence
    None => fail("expected else control-result evidence")
  }
  match
    dae_control_result_pair_gc_evidence(mod_, then_evidence, else_evidence, [
      base_ref,
    ]) {
    Some(evidence) => {
      assert_true(evidence.saw_refinement)
      assert_true(evidence.then_body_changed)
      assert_true(evidence.else_body_changed)
      assert_eq(evidence.refined_results[0], expected_common_ref)
      let application_next_results = [base_ref]
      let application_refined_results = [base_ref]
      match
        dae_apply_control_result_pair_refinements(
          evidence,
          application_next_results,
          refined_results=Some(application_refined_results),
        ) {
        Some(application) => {
          assert_eq(application.result_count, 1)
          assert_eq(application.next_results_length, 1)
          assert_eq(application.refined_results_length, 1)
          assert_true(application.saw_refinement)
          assert_eq(application_next_results[0], expected_common_ref)
          assert_eq(application_refined_results[0], expected_common_ref)
        }
        None => fail("expected paired refinement application evidence")
      }
      assert_eq(
        evidence.rewritten_then_body[0],
        @lib.Instruction::block(
          @lib.BlockType::val_type(expected_left_ref),
          @lib.Expr::new([@lib.Instruction::struct_new_default(left_type)]),
        ),
      )
      assert_eq(
        evidence.rewritten_else_body[0],
        @lib.Instruction::block(
          @lib.BlockType::val_type(expected_right_ref),
          @lib.Expr::new([@lib.Instruction::struct_new_default(right_type)]),
        ),
      )
    }
    None => fail("expected paired control-result GC evidence")
  }
  match
    dae_multi_result_if_pair_gc_refinement_evidence(
      mod_,
      [],
      None,
      then_body,
      else_body,
      [base_ref],
    ) {
    Some(evidence) => {
      assert_true(evidence.if_body_changed)
      assert_eq(evidence.pair.refined_results[0], expected_common_ref)
      assert_eq(evidence.pair.rewritten_then_body.length(), 1)
      assert_eq(evidence.pair.rewritten_else_body.length(), 1)
    }
    None => fail("expected fallthrough if-pair refinement evidence")
  }
  let terminal_then_body = [then_body[0], @lib.Instruction::return_()]
  let terminal_else_body = [else_body[0], @lib.Instruction::return_()]
  match
    dae_multi_result_if_pair_gc_refinement_evidence(
      mod_,
      [],
      None,
      terminal_then_body,
      terminal_else_body,
      [base_ref],
      require_terminal_return=true,
    ) {
    Some(evidence) => {
      assert_true(evidence.if_body_changed)
      assert_eq(evidence.pair.refined_results[0], expected_common_ref)
      assert_eq(evidence.pair.rewritten_then_body.length(), 2)
      assert_eq(evidence.pair.rewritten_else_body.length(), 2)
    }
    None => fail("expected terminal-return if-pair refinement evidence")
  }
}

///|
test "dae terminal-return body evidence centralizes return-carrier guards" {
  let terminal_arm = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::drop(),
    @lib.Instruction::return_(),
  ]
  match dae_terminal_return_body_evidence(terminal_arm) {
    Some(evidence) => {
      assert_eq(evidence.body.length(), 3)
      assert_eq(evidence.body_length, 3)
      assert_eq(evidence.return_idx, 2)
      assert_eq(evidence.prefix_length, 2)
      assert_false(evidence.prefix_has_observable_effect_or_branch)
      assert_true(evidence.terminal_return_only)
      assert_true(dae_terminal_return_body_evidence_is_consistent(evidence))
    }
    None => fail("expected terminal-return body evidence")
  }
  let effectful_terminal_arm = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::return_(),
  ]
  match dae_terminal_return_body_evidence(effectful_terminal_arm) {
    Some(_) => fail("effectful terminal-return prefix should not be accepted")
    None => ()
  }
}

///|
test "dae effect-free body evidence centralizes carrier and fallthrough guards" {
  let effect_free_arm = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::drop(),
  ]
  match dae_effect_free_body_evidence(effect_free_arm) {
    Some(evidence) => {
      assert_eq(evidence.body.length(), 2)
      assert_eq(evidence.body_length, 2)
      assert_false(evidence.has_observable_effect_or_branch)
      assert_true(evidence.effect_free)
      assert_true(dae_effect_free_body_evidence_is_consistent(evidence))
    }
    None => fail("expected effect-free body evidence")
  }
  match dae_effect_free_fallthrough_evidence(effect_free_arm) {
    Some(evidence) => {
      assert_eq(evidence.body.length(), 2)
      assert_eq(evidence.body_length, 2)
      assert_false(evidence.has_observable_effect_or_branch)
      assert_true(evidence.effect_free_fallthrough)
      assert_true(dae_effect_free_fallthrough_evidence_is_consistent(evidence))
    }
    None => fail("expected effect-free fallthrough evidence")
  }
  let effectful_arm = [@lib.Instruction::call(@lib.FuncIdx::new(0U))]
  match dae_effect_free_body_evidence(effectful_arm) {
    Some(_) => fail("effectful body should not be accepted")
    None => ()
  }
  match dae_effect_free_fallthrough_evidence(effectful_arm) {
    Some(_) =>
      fail("effectful arm should not be accepted as fallthrough evidence")
    None => ()
  }
}

///|
test "dae mixed single-result fallthrough arm evidence centralizes LUB and effect-free arms" {
  let base_type = @lib.TypeIdx::new(0U)
  let left_type = @lib.TypeIdx::new(1U)
  let right_type = @lib.TypeIdx::new(2U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_left_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(left_type), exact=true),
  )
  let expected_common_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(base_type)),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let return_arm = [
    @lib.Instruction::struct_new_default(right_type),
    @lib.Instruction::return_(),
  ]
  match
    dae_mixed_single_result_return_arm_gc_evidence(
      mod_,
      [],
      None,
      return_arm,
      base_ref,
      expected_left_ref,
    ) {
    Some(evidence) => {
      assert_true(evidence.has_return)
      assert_false(evidence.effect_free_fallthrough)
      assert_false(evidence.body_changed)
      assert_eq(evidence.candidate, expected_common_ref)
    }
    None => fail("expected mixed single-result return arm evidence")
  }
  let effect_free_arm = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::drop(),
  ]
  match
    dae_mixed_single_result_return_arm_gc_evidence(
      mod_,
      [],
      None,
      effect_free_arm,
      base_ref,
      expected_left_ref,
    ) {
    Some(evidence) => {
      assert_false(evidence.has_return)
      assert_true(evidence.effect_free_fallthrough)
      assert_false(evidence.body_changed)
      assert_eq(evidence.candidate, expected_left_ref)
    }
    None => fail("expected effect-free single-result fallthrough arm evidence")
  }
  let effectful_arm = [@lib.Instruction::call(@lib.FuncIdx::new(0U))]
  match
    dae_mixed_single_result_return_arm_gc_evidence(
      mod_,
      [],
      None,
      effectful_arm,
      base_ref,
      expected_left_ref,
    ) {
    Some(_) => fail("effectful fallthrough arm should be rejected")
    None => ()
  }
}

///|
test "dae mixed multi-result return arm evidence centralizes LUB and effect-free arms" {
  let base_type = @lib.TypeIdx::new(0U)
  let left_type = @lib.TypeIdx::new(1U)
  let right_type = @lib.TypeIdx::new(2U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_left_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(left_type), exact=true),
  )
  let expected_common_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(base_type)),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let combined_candidates : Array[@lib.ValType?] = [Some(expected_left_ref)]
  let rejected = [false]
  let return_arm = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(base_ref),
      @lib.Expr::new([@lib.Instruction::struct_new_default(right_type)]),
    ),
    @lib.Instruction::return_(),
  ]
  match
    dae_mixed_multi_result_return_arm_gc_evidence(
      mod_,
      [],
      None,
      return_arm,
      [base_ref],
      combined_candidates,
      rejected,
    ) {
    Some(evidence) => {
      assert_true(evidence.has_return)
      assert_false(evidence.effect_free_fallthrough)
      assert_eq(evidence.result_start, 0)
      match evidence.control_result {
        Some(control_result) => {
          assert_eq(control_result.result_start, 0)
          assert_eq(control_result.candidates.length(), 1)
          assert_eq(control_result.rewrites.length(), 1)
        }
        None => fail("expected captured shared control-result evidence")
      }
      assert_eq(combined_candidates[0], Some(expected_common_ref))
      assert_false(rejected[0])
    }
    None => fail("expected mixed multi-result return arm evidence")
  }
  let effect_free_arm = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::drop(),
  ]
  match
    dae_mixed_multi_result_return_arm_gc_evidence(
      mod_,
      [],
      None,
      effect_free_arm,
      [base_ref],
      combined_candidates,
      rejected,
    ) {
    Some(evidence) => {
      assert_false(evidence.has_return)
      assert_true(evidence.effect_free_fallthrough)
      assert_eq(evidence.result_start, -1)
      assert_true(evidence.control_result.is_none())
      assert_eq(evidence.body.length(), 2)
    }
    None => fail("expected effect-free fallthrough arm evidence")
  }
}

///|
test "dae refined result projection applies sparse slots transactionally" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let next_results = [base_ref, base_ref]
  let refined_results = [base_ref, base_ref]
  match
    dae_apply_optional_refined_result_slots(
      [Some(leaf_ref), None],
      next_results,
      refined_results=Some(refined_results),
    ) {
    Some(application) => {
      assert_eq(application.result_count, 2)
      assert_eq(application.applied_count, 1)
      assert_eq(application.next_results_length, 2)
      assert_eq(application.refined_results_length, 2)
      assert_eq(next_results, [leaf_ref, base_ref])
      assert_eq(refined_results, [leaf_ref, base_ref])
    }
    None => fail("expected sparse refined-result projection")
  }
  let rejected_next = [base_ref, base_ref]
  let rejected_refined = [base_ref]
  match
    dae_apply_optional_refined_result_slots(
      [Some(leaf_ref), None],
      rejected_next,
      refined_results=Some(rejected_refined),
    ) {
    Some(_) => fail("mismatched mirror length must reject")
    None => {
      assert_eq(rejected_next, [base_ref, base_ref])
      assert_eq(rejected_refined, [base_ref])
    }
  }
}

///|
test "dae control result single refinement application centralizes next-result repair" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let body = [@lib.Instruction::struct_new_default(leaf_type)]
  let slice = match
    dae_make_multi_result_control_slice(body, 0, 1, 0, false, false) {
    Some(slice) => slice
    None => fail("expected one-slot control-result slice")
  }
  let evidence = match
    dae_control_result_slice_gc_evidence(mod_, [], None, slice, [base_ref]) {
    Some(evidence) => evidence
    None => fail("expected control-result GC evidence")
  }
  let next_results = [base_ref]
  let refined_results = [base_ref]
  match
    dae_apply_control_result_single_refinements(
      evidence,
      next_results,
      refined_results=Some(refined_results),
    ) {
    Some(application) => {
      assert_eq(application.result_count, 1)
      assert_true(application.saw_refinement)
      assert_eq(application.next_results_length, 1)
      assert_eq(application.refined_results_length, 1)
      assert_eq(application.body_changed, false)
      assert_eq(next_results[0], leaf_ref)
      assert_eq(refined_results[0], leaf_ref)
    }
    None => fail("expected single refinement application evidence")
  }
}

///|
test "dae parametric typeidx arm evidence reuses control result GC carrier" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let arm_body = [
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::val_type(base_ref),
      @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
    ),
    @lib.Instruction::struct_new_default(leaf_type),
  ]
  match
    dae_parametric_typeidx_multi_result_arm_gc_evidence(
      mod_,
      [],
      None,
      arm_body,
      1,
      [base_ref, base_ref],
    ) {
    Some(evidence) => {
      assert_true(evidence.saw_candidate)
      assert_true(evidence.body_changed)
      assert_eq(evidence.result_start, 1)
      assert_eq(evidence.candidates[0], Some(expected_leaf_ref))
      assert_eq(evidence.candidates[1], Some(expected_leaf_ref))
      assert_eq(evidence.refined_candidates[0], Some(expected_leaf_ref))
      assert_eq(evidence.refined_candidates[1], Some(expected_leaf_ref))
      assert_eq(evidence.body, arm_body)
      assert_eq(
        evidence.rewritten_body[1],
        @lib.Instruction::block(
          @lib.BlockType::val_type(expected_leaf_ref),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
        ),
      )
      assert_eq(evidence.rewritten_body[2], arm_body[2])
    }
    None => fail("expected parametric typeidx arm evidence carrier")
  }
}

///|
test "dae typeidx control rewrite plan centralizes type installation and reconstruction" {
  let params = [@lib.ValType::i32()]
  let results = [@lib.ValType::i64(), @lib.ValType::f32()]
  let body = [@lib.Instruction::drop()]
  let else_body = [@lib.Instruction::nop()]
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func(params, results)),
    ),
  ])
  let block_plan = match
    dae_typeidx_control_rewrite_plan(0, params, results, body, None) {
    Some(plan) => plan
    None => fail("expected block typeidx rewrite plan")
  }
  assert_eq(block_plan.control_kind, 0)
  assert_eq(block_plan.params, params)
  assert_eq(block_plan.results, results)
  assert_eq(block_plan.body, body)
  match block_plan.else_body {
    Some(_) => fail("block plan must not retain an else body")
    None => ()
  }
  let block_application = match
    dae_apply_typeidx_control_rewrite(type_sec, block_plan) {
    Some(application) => application
    None => fail("expected block typeidx rewrite application")
  }
  assert_eq(block_application.type_sec, type_sec)
  assert_eq(
    block_application.rewritten,
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new(body),
    ),
  )
  let loop_plan = match
    dae_typeidx_control_rewrite_plan(1, params, results, body, None) {
    Some(plan) => plan
    None => fail("expected loop typeidx rewrite plan")
  }
  let loop_application = match
    dae_apply_typeidx_control_rewrite(type_sec, loop_plan) {
    Some(application) => application
    None => fail("expected loop typeidx rewrite application")
  }
  assert_eq(
    loop_application.rewritten,
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new(body),
    ),
  )
  let if_plan = match
    dae_typeidx_control_rewrite_plan(2, params, results, body, Some(else_body)) {
    Some(plan) => plan
    None => fail("expected if typeidx rewrite plan")
  }
  let if_application = match
    dae_apply_typeidx_control_rewrite(type_sec, if_plan) {
    Some(application) => application
    None => fail("expected if typeidx rewrite application")
  }
  assert_eq(
    if_application.rewritten,
    @lib.Instruction::if_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      body,
      Some(else_body),
    ),
  )
  match dae_typeidx_control_rewrite_plan(2, params, results, body, None) {
    Some(_) => fail("if plan without an else body must reject")
    None => ()
  }
  match dae_typeidx_control_rewrite_plan(3, params, results, body, None) {
    Some(_) => fail("unknown control kind must reject")
    None => ()
  }
}

///|
test "dae typeidx control rebuild preserves active type section timing" {
  let params = [@lib.ValType::i32()]
  let results = [@lib.ValType::i64()]
  let body = [
    @lib.Instruction::drop(),
    @lib.Instruction::i64_const(@lib.I64(1L)),
  ]
  let empty_type_sec = @lib.TypeSec::new([])
  let first = match
    dae_rebuild_typeidx_control(empty_type_sec, 0, params, results, body, None) {
    Some(application) => application
    None => fail("expected first typeidx control rebuild")
  }
  let @lib.TypeSec(first_types) = first.type_sec
  assert_eq(first_types.length(), 1)
  assert_eq(
    first.rewritten,
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new(body),
    ),
  )
  let second = match
    dae_rebuild_typeidx_control(first.type_sec, 1, params, results, body, None) {
    Some(application) => application
    None => fail("expected second typeidx control rebuild")
  }
  assert_eq(second.type_sec, first.type_sec)
  assert_eq(
    second.rewritten,
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new(body),
    ),
  )
  match
    dae_rebuild_typeidx_control(second.type_sec, 2, params, results, body, None) {
    Some(_) => fail("if rebuild without else must reject before type mutation")
    None => ()
  }
}

///|
test "dae typeidx control body installation is transactional and reuses active types" {
  let params = [@lib.ValType::i32()]
  let results = [@lib.ValType::i64()]
  let control_body = [
    @lib.Instruction::drop(),
    @lib.Instruction::i64_const(@lib.I64(1L)),
  ]
  let outer_body = [@lib.Instruction::nop(), @lib.Instruction::unreachable_()]
  let first = match
    dae_rebuild_typeidx_control_in_body(
      @lib.TypeSec::new([]),
      outer_body,
      1,
      0,
      params,
      results,
      control_body,
      None,
    ) {
    Some(application) => application
    None => fail("expected transactional typeidx control body installation")
  }
  assert_eq(outer_body[1], @lib.Instruction::unreachable_())
  assert_eq(first.body[0], @lib.Instruction::nop())
  assert_eq(
    first.body[1],
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new(control_body),
    ),
  )
  let @lib.TypeSec(first_types) = first.type_sec
  assert_eq(first_types.length(), 1)
  let second = match
    dae_rebuild_typeidx_control_in_body(
      first.type_sec,
      first.body,
      0,
      1,
      params,
      results,
      control_body,
      None,
    ) {
    Some(application) => application
    None => fail("expected active type reuse for second body installation")
  }
  assert_eq(second.type_sec, first.type_sec)
  assert_eq(
    second.body[0],
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new(control_body),
    ),
  )
  match
    dae_rebuild_typeidx_control_in_body(
      first.type_sec,
      outer_body,
      outer_body.length(),
      0,
      params,
      [@lib.ValType::f32()],
      control_body,
      None,
    ) {
    Some(_) =>
      fail("out-of-range control slot must reject before body installation")
    None => assert_eq(outer_body[1], @lib.Instruction::unreachable_())
  }
}

///|
test "dae single-body control rewrite evidence centralizes reconstruction" {
  let original_body = [@lib.Instruction::nop()]
  let rewritten_body = [@lib.Instruction::drop()]
  let block = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new(original_body),
  )
  let loop_instr = @lib.Instruction::loop_(
    @lib.BlockType::void_(),
    @lib.Expr::new(original_body),
  )
  let replacement_type = @lib.BlockType::val_type(@lib.ValType::i32())
  let block_shape = match dae_single_body_control_shape_evidence(block) {
    Some(evidence) => evidence
    None => fail("expected block control shape evidence")
  }
  assert_eq(block_shape.control_kind, 0)
  assert_eq(block_shape.block_type, @lib.BlockType::void_())
  assert_eq(block_shape.body, original_body)
  let unchanged = dae_single_body_control_rewrite_evidence(
    block_shape,
    replacement_type,
    None,
  )
  assert_false(unchanged.body_changed)
  assert_eq(unchanged.rewritten_body, original_body)
  assert_eq(
    dae_apply_single_body_control_rewrite_evidence(unchanged),
    Some(
      @lib.Instruction::block(replacement_type, @lib.Expr::new(original_body)),
    ),
  )
  let loop_shape = match dae_single_body_control_shape_evidence(loop_instr) {
    Some(evidence) => evidence
    None => fail("expected loop control shape evidence")
  }
  assert_eq(loop_shape.control_kind, 1)
  let rewritten = dae_single_body_control_rewrite_evidence(
    loop_shape,
    @lib.BlockType::void_(),
    Some(rewritten_body),
  )
  assert_true(rewritten.body_changed)
  assert_eq(
    dae_apply_single_body_control_rewrite_evidence(rewritten),
    Some(
      @lib.Instruction::loop_(
        @lib.BlockType::void_(),
        @lib.Expr::new(rewritten_body),
      ),
    ),
  )
  match
    dae_single_body_control_shape_evidence(
      @lib.Instruction::if_(@lib.BlockType::void_(), [], Some([])),
    ) {
    Some(_) => fail("paired-arm if must not use single-body control evidence")
    None => ()
  }
  match dae_single_body_control_shape_evidence(@lib.Instruction::drop()) {
    Some(_) => fail("non-control instruction must not produce shape evidence")
    None => ()
  }
}

///|
test "dae single-result control GC evidence centralizes block and loop rewrites" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let nested_old_block = @lib.Instruction::block(
    @lib.BlockType::val_type(base_ref),
    @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
  )
  let body = [nested_old_block]
  let evidence = match
    dae_single_result_control_gc_candidate_evidence(
      mod_,
      [],
      None,
      @lib.Instruction::block(
        @lib.BlockType::val_type(base_ref),
        @lib.Expr::new(body),
      ),
      base_ref,
    ) {
    Some(evidence) => evidence
    None => fail("expected single-result control GC candidate evidence")
  }
  assert_eq(evidence.candidate, expected_leaf_ref)
  assert_true(evidence.rewrite.body_changed)
  assert_eq(evidence.rewrite.shape.body, body)
  assert_eq(
    evidence.rewrite.rewritten_body[0],
    @lib.Instruction::struct_new_default(leaf_type),
  )
  let expected_rewritten_block = @lib.Instruction::block(
    @lib.BlockType::val_type(expected_leaf_ref),
    @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
  )
  let expected_rewritten_loop = @lib.Instruction::loop_(
    @lib.BlockType::val_type(expected_leaf_ref),
    @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
  )
  match dae_apply_single_body_control_rewrite_evidence(evidence.rewrite) {
    Some(rewritten_block) =>
      assert_eq(rewritten_block, expected_rewritten_block)
    None => fail("expected block rewrite from control GC candidate evidence")
  }
  let loop_evidence = match
    dae_single_result_control_gc_candidate_evidence(
      mod_,
      [],
      None,
      @lib.Instruction::loop_(
        @lib.BlockType::val_type(base_ref),
        @lib.Expr::new(body),
      ),
      base_ref,
    ) {
    Some(evidence) => evidence
    None => fail("expected loop control GC candidate evidence")
  }
  match dae_apply_single_body_control_rewrite_evidence(loop_evidence.rewrite) {
    Some(rewritten_loop) => assert_eq(rewritten_loop, expected_rewritten_loop)
    None => fail("expected loop rewrite from control GC candidate evidence")
  }
  match
    dae_single_result_control_gc_candidate_instr_evidence(
      mod_,
      [],
      None,
      expected_rewritten_block,
      base_ref,
    ) {
    Some((candidate, Some(rewritten))) => {
      assert_eq(candidate, expected_leaf_ref)
      assert_eq(rewritten, expected_rewritten_block)
    }
    _ => fail("expected block instruction GC candidate evidence")
  }
  match
    dae_single_result_control_gc_candidate_instr_evidence(
      mod_,
      [],
      None,
      expected_rewritten_loop,
      base_ref,
    ) {
    Some((candidate, Some(rewritten))) => {
      assert_eq(candidate, expected_leaf_ref)
      assert_eq(rewritten, expected_rewritten_loop)
    }
    _ => fail("expected loop instruction GC candidate evidence")
  }
  match
    dae_single_result_control_gc_candidate_instr_evidence(
      mod_,
      [],
      None,
      @lib.Instruction::drop(),
      base_ref,
    ) {
    Some(_) =>
      fail("non-control instruction must not produce GC candidate evidence")
    None => ()
  }
}

///|
test "dae multi-result operand slot evidence centralizes suffix scan fallback" {
  let mod_ = @lib.Module::new()
  let body = [
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::drop(),
    @lib.Instruction::i64_const(@lib.I64(10L)),
    @lib.Instruction::i32_const(@lib.I32(1)),
  ]
  let prefix = match
    dae_multi_result_operand_slot_prefix_evidence(body, 0, body.length()) {
    Some(evidence) => evidence
    None => fail("expected skipped dropped-pair slot prefix evidence")
  }
  assert_eq(prefix.start, 0)
  assert_eq(prefix.end, body.length())
  assert_eq(prefix.operand_start, 2)
  assert_eq(prefix.next, 2)
  assert_eq(prefix.skipped_pairs, 1)
  assert_false(prefix.consumed_single_producer)
  match dae_trivially_dropped_prefix_evidence(body, 2) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 2)
      assert_eq(evidence.next, 2)
      assert_eq(evidence.skipped_pairs, 1)
    }
    None => fail("expected dropped-prefix evidence")
  }
  match dae_trivially_dropped_prefix_evidence(body, 3) {
    Some(_) => fail("dropped-prefix evidence must reject partial operands")
    None => ()
  }
  match
    dae_multi_result_operand_slot_single_producer_evidence(
      mod_,
      [],
      body,
      prefix,
    ) {
    Some(evidence) => {
      assert_eq(evidence.operand_start, 2)
      assert_eq(evidence.next, 3)
      assert_eq(evidence.skipped_pairs, 1)
      assert_true(evidence.consumed_single_producer)
    }
    None => fail("expected single-producer fallback slot evidence")
  }
  match dae_multi_result_operand_slot_prefix_evidence(body, 0, 2) {
    Some(_) => fail("slot prefix evidence must reject exhausted suffixes")
    None => ()
  }
  match dae_multi_result_operand_slot_prefix_evidence(body, -1, body.length()) {
    Some(_) => fail("slot prefix evidence must reject out-of-range starts")
    None => ()
  }
}

///|
test "dae indexed instruction rewrite evidence centralizes shared body edits" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_const(@lib.I32(3)),
  ]
  let rewrites : Array[@lib.Instruction?] = [
    Some(@lib.Instruction::i32_const(@lib.I32(10))),
    None,
    Some(@lib.Instruction::i32_const(@lib.I32(30))),
  ]
  match
    dae_apply_indexed_instruction_rewrites_to_body(body, [0, 1, 2], rewrites) {
    Some((rewritten, evidence)) => {
      assert_true(evidence.body_changed)
      assert_eq(evidence.target_count, 3)
      assert_eq(evidence.rewrite_count, 2)
      assert_eq(rewritten[0], @lib.Instruction::i32_const(@lib.I32(10)))
      assert_eq(rewritten[1], body[1])
      assert_eq(rewritten[2], @lib.Instruction::i32_const(@lib.I32(30)))
    }
    None => fail("expected shared indexed rewrite evidence")
  }
  match
    dae_apply_indexed_instruction_rewrites_to_body(body, [0, 1, 1], rewrites) {
    Some(_) => fail("indexed rewrite evidence must reject duplicate targets")
    None => ()
  }
  match
    dae_apply_indexed_instruction_rewrites_to_body(body, [0, 3], [None, None]) {
    Some(_) => fail("indexed rewrite evidence must reject out-of-range targets")
    None => ()
  }
}

///|
test "dae first instruction rewrite evidence centralizes body repair scans" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_const(@lib.I32(3)),
  ]
  let rewrite_second = fn(instr : @lib.Instruction) -> @lib.Instruction? {
    match instr {
      @lib.I32Const(@lib.I32(2)) =>
        Some(@lib.Instruction::i32_const(@lib.I32(20)))
      _ => None
    }
  }
  match dae_apply_first_instruction_rewrite_to_body(body, rewrite_second) {
    Some((rewritten, evidence)) => {
      assert_true(evidence.body_changed)
      assert_eq(evidence.target_count, 1)
      assert_eq(evidence.rewrite_count, 1)
      assert_eq(rewritten[0], body[0])
      assert_eq(rewritten[1], @lib.Instruction::i32_const(@lib.I32(20)))
      assert_eq(rewritten[2], body[2])
    }
    None => fail("expected first-instruction rewrite evidence")
  }
  let no_rewrite = fn(_instr : @lib.Instruction) -> @lib.Instruction? { None }
  match dae_apply_first_instruction_rewrite_to_body(body, no_rewrite) {
    Some(_) => fail("first-instruction rewrite should reject no-match bodies")
    None => ()
  }
}

///|
test "dae control child rewrite helper centralizes recursive body repair" {
  let then_body = [@lib.Instruction::i32_const(@lib.I32(1))]
  let else_body = [@lib.Instruction::i32_const(@lib.I32(2))]
  let rewrite_else = fn(
    body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    if body == else_body {
      Some([@lib.Instruction::i32_const(@lib.I32(20))])
    } else {
      None
    }
  }
  match
    dae_try_rewrite_first_control_child_body(
      @lib.Instruction::if_(@lib.BlockType::void_(), then_body, Some(else_body)),
      rewrite_else,
    ) {
    Some(@lib.If(_, rewritten_then, Some(rewritten_else))) => {
      assert_eq(rewritten_then, then_body)
      assert_eq(rewritten_else, [@lib.Instruction::i32_const(@lib.I32(20))])
    }
    _ => fail("expected if else-child rewrite")
  }
  let rewrite_any_single = fn(
    body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    if body.length() == 1 {
      Some([@lib.Instruction::i32_const(@lib.I32(99))])
    } else {
      None
    }
  }
  match
    dae_try_rewrite_first_control_child_body(
      @lib.Instruction::if_(@lib.BlockType::void_(), then_body, Some(else_body)),
      rewrite_any_single,
    ) {
    Some(@lib.If(_, rewritten_then, Some(rewritten_else))) => {
      assert_eq(rewritten_then, [@lib.Instruction::i32_const(@lib.I32(99))])
      assert_eq(rewritten_else, else_body)
    }
    _ => fail("expected helper to rewrite the first eligible control child")
  }
  match
    dae_try_rewrite_first_control_child_body(
      @lib.Instruction::i32_const(@lib.I32(3)),
      rewrite_any_single,
    ) {
    Some(_) => fail("non-control instructions should not rewrite children")
    None => ()
  }
}

///|
test "dae recursive body rewrite helper centralizes current and child repair scans" {
  let root_body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
  ]
  let rewrite_current = fn(
    body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    if body == root_body {
      Some([@lib.Instruction::i32_const(@lib.I32(10))])
    } else {
      None
    }
  }
  let rewrite_child_never = fn(
    _body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    Some([@lib.Instruction::i32_const(@lib.I32(99))])
  }
  match
    dae_apply_first_current_or_control_child_body_rewrite(
      root_body, rewrite_current, rewrite_child_never,
    ) {
    Some(rewritten) =>
      assert_eq(rewritten, [@lib.Instruction::i32_const(@lib.I32(10))])
    None => fail("expected current body rewrite to win")
  }

  let then_body = [@lib.Instruction::i32_const(@lib.I32(3))]
  let else_body = [@lib.Instruction::i32_const(@lib.I32(4))]
  let outer_body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::if_(@lib.BlockType::void_(), then_body, Some(else_body)),
  ]
  let no_current = fn(
    _body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    None
  }
  let rewrite_else = fn(
    body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    if body == else_body {
      Some([@lib.Instruction::i32_const(@lib.I32(40))])
    } else {
      None
    }
  }
  match
    dae_apply_first_current_or_control_child_body_rewrite(
      outer_body, no_current, rewrite_else,
    ) {
    Some(rewritten) =>
      match rewritten[1] {
        @lib.If(_, rewritten_then, Some(rewritten_else)) => {
          assert_eq(rewritten[0], outer_body[0])
          assert_eq(rewritten_then, then_body)
          assert_eq(rewritten_else, [@lib.Instruction::i32_const(@lib.I32(40))])
        }
        _ => fail("expected nested control child rewrite")
      }
    None => fail("expected child body rewrite")
  }
}

///|
test "dae recursive body rewrite application evidence centralizes repair planning" {
  let root_body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
  ]
  let rewrite_current = fn(
    body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    if body == root_body {
      Some([@lib.Instruction::i32_const(@lib.I32(10))])
    } else {
      None
    }
  }
  let rewrite_child_never = fn(
    _body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    Some([@lib.Instruction::i32_const(@lib.I32(99))])
  }
  match
    dae_apply_first_recursive_body_rewrite(
      root_body, rewrite_current, rewrite_child_never,
    ) {
    Some((rewritten, evidence)) => {
      assert_eq(rewritten, [@lib.Instruction::i32_const(@lib.I32(10))])
      assert_true(evidence.applied_to_current_body)
      assert_eq(evidence.target_count, 0)
      assert_eq(evidence.rewrite_count, 1)
      assert_true(evidence.body_changed)
    }
    None => fail("expected current body rewrite application evidence")
  }

  let then_body = [@lib.Instruction::i32_const(@lib.I32(3))]
  let else_body = [@lib.Instruction::i32_const(@lib.I32(4))]
  let outer_body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::if_(@lib.BlockType::void_(), then_body, Some(else_body)),
  ]
  let no_current = fn(
    _body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    None
  }
  let rewrite_else = fn(
    body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    if body == else_body {
      Some([@lib.Instruction::i32_const(@lib.I32(40))])
    } else {
      None
    }
  }
  match
    dae_apply_first_recursive_body_rewrite(outer_body, no_current, rewrite_else) {
    Some((rewritten, evidence)) => {
      assert_false(evidence.applied_to_current_body)
      assert_eq(evidence.target_count, 1)
      assert_eq(evidence.rewrite_count, 1)
      assert_true(evidence.body_changed)
      match rewritten[1] {
        @lib.If(_, rewritten_then, Some(rewritten_else)) => {
          assert_eq(rewritten[0], outer_body[0])
          assert_eq(rewritten_then, then_body)
          assert_eq(rewritten_else, [@lib.Instruction::i32_const(@lib.I32(40))])
        }
        _ => fail("expected nested control child rewrite")
      }
    }
    None => fail("expected child body rewrite application evidence")
  }

  match
    dae_apply_first_recursive_control_child_body_rewrite(
      outer_body, rewrite_else,
    ) {
    Some((rewritten, evidence)) => {
      assert_false(evidence.applied_to_current_body)
      assert_eq(evidence.target_count, 1)
      assert_eq(evidence.rewrite_count, 1)
      assert_true(evidence.body_changed)
      match rewritten[1] {
        @lib.If(_, rewritten_then, Some(rewritten_else)) => {
          assert_eq(rewritten[0], outer_body[0])
          assert_eq(rewritten_then, then_body)
          assert_eq(rewritten_else, [@lib.Instruction::i32_const(@lib.I32(40))])
        }
        _ => fail("expected control-child-only recursive body rewrite")
      }
    }
    None => fail("expected control-child-only application evidence")
  }
  match
    dae_apply_first_recursive_control_child_body_rewrite(
      root_body, rewrite_else,
    ) {
    Some(_) =>
      fail(
        "control-child-only rewrite should reject bodies without rewritten control children",
      )
    None => ()
  }

  let rewrite_second_instr = fn(instr : @lib.Instruction) -> @lib.Instruction? {
    match instr {
      @lib.I32Const(@lib.I32(2)) =>
        Some(@lib.Instruction::i32_const(@lib.I32(22)))
      _ => None
    }
  }
  match
    dae_apply_first_recursive_instruction_body_rewrite_to_body(
      root_body, rewrite_second_instr,
    ) {
    Some(rewritten) => {
      assert_eq(rewritten[0], root_body[0])
      assert_eq(rewritten[1], @lib.Instruction::i32_const(@lib.I32(22)))
    }
    None =>
      fail("expected instruction rewrite adapter to return rewritten body")
  }
  let rewrite_no_instr = fn(_instr : @lib.Instruction) -> @lib.Instruction? {
    None
  }
  match
    dae_apply_first_recursive_instruction_body_rewrite_to_body(
      root_body, rewrite_no_instr,
    ) {
    Some(_) => fail("instruction rewrite adapter should reject no-match bodies")
    None => ()
  }
}

///|
test "dae body rewrite fixpoint evidence centralizes bounded convergence" {
  let start_body = [@lib.Instruction::i32_const(@lib.I32(0))]
  let rewrite_until_three = fn(
    body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    if body.length() != 1 {
      return None
    }
    match body[0] {
      @lib.I32Const(@lib.I32(value)) if value < 3 =>
        Some([@lib.Instruction::i32_const(@lib.I32(value + 1))])
      _ => None
    }
  }
  match
    dae_apply_body_rewrite_until_stable(start_body, rewrite_until_three, 8) {
    Some((rewritten, evidence)) => {
      assert_eq(rewritten, [@lib.Instruction::i32_const(@lib.I32(3))])
      assert_eq(evidence.max_iters, 8)
      assert_eq(evidence.iteration_count, 3)
      assert_false(evidence.reached_limit)
      assert_true(evidence.body_changed)
    }
    None => fail("expected bounded fixpoint evidence")
  }
  match
    dae_apply_body_rewrite_until_stable(start_body, rewrite_until_three, 2) {
    Some((rewritten, evidence)) => {
      assert_eq(rewritten, [@lib.Instruction::i32_const(@lib.I32(2))])
      assert_eq(evidence.iteration_count, 2)
      assert_true(evidence.reached_limit)
      assert_true(evidence.body_changed)
    }
    None => fail("expected bounded limit evidence")
  }
  match
    dae_apply_body_rewrite_until_stable(
      [@lib.Instruction::i32_const(@lib.I32(3))],
      rewrite_until_three,
      8,
    ) {
    Some(_) => fail("unchanged fixpoint should not report a rewrite")
    None => ()
  }
}

///|
test "dae body rewrite fixpoint projection replaces scanner-local convergence loops" {
  let start_body = [@lib.Instruction::i32_const(@lib.I32(0))]
  let rewrite_until_two = fn(
    body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    match body {
      [@lib.I32Const(@lib.I32(value))] if value < 2 =>
        Some([@lib.Instruction::i32_const(@lib.I32(value + 1))])
      _ => None
    }
  }
  assert_eq(
    dae_apply_body_rewrite_until_stable_or_original(
      start_body, rewrite_until_two, 8,
    ),
    [@lib.Instruction::i32_const(@lib.I32(2))],
  )
  let stable_body = [@lib.Instruction::i32_const(@lib.I32(2))]
  assert_eq(
    dae_apply_body_rewrite_until_stable_or_original(
      stable_body, rewrite_until_two, 8,
    ),
    stable_body,
  )
  assert_eq(
    dae_apply_body_rewrite_until_stable_or_original(
      start_body, rewrite_until_two, 1,
    ),
    [@lib.Instruction::i32_const(@lib.I32(1))],
  )
}

///|
test "dae result rewrite application evidence centralizes masked slot repairs" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_const(@lib.I32(3)),
  ]
  let rewrites : Array[@lib.Instruction?] = [
    None,
    Some(@lib.Instruction::i32_const(@lib.I32(20))),
    Some(@lib.Instruction::i32_const(@lib.I32(30))),
  ]
  match dae_apply_result_rewrites_to_body(body, 0, rewrites) {
    Some((rewritten, evidence)) => {
      assert_true(evidence.body_changed)
      assert_eq(evidence.start, 0)
      assert_eq(evidence.result_count, 3)
      assert_eq(evidence.rewrite_count, 2)
      assert_eq(rewritten[0], body[0])
      assert_eq(rewritten[1], @lib.Instruction::i32_const(@lib.I32(20)))
      assert_eq(rewritten[2], @lib.Instruction::i32_const(@lib.I32(30)))
    }
    None => fail("expected unmasked result rewrite evidence")
  }
  match
    dae_apply_result_rewrites_to_body(
      body,
      0,
      rewrites,
      active=Some([true, false, true]),
    ) {
    Some((rewritten, evidence)) => {
      assert_true(evidence.body_changed)
      assert_eq(evidence.start, 0)
      assert_eq(evidence.result_count, 3)
      assert_eq(evidence.rewrite_count, 1)
      assert_eq(rewritten[0], body[0])
      assert_eq(rewritten[1], body[1])
      assert_eq(rewritten[2], @lib.Instruction::i32_const(@lib.I32(30)))
    }
    None => fail("expected masked result rewrite evidence")
  }
  match
    dae_apply_result_rewrites_to_body(
      body,
      1,
      rewrites,
      active=Some([true, false]),
    ) {
    Some(_) =>
      fail("mismatched active mask must reject result rewrite evidence")
    None => ()
  }
  match dae_apply_result_rewrites_to_body(body, 2, rewrites) {
    Some(_) => fail("out-of-range rewrite window must reject")
    None => ()
  }
}

///|
test "dae select value rewrite application evidence centralizes select repairs" {
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let refined_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let body = [
    @lib.Instruction::ref_null_type(
      @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
    ),
    @lib.Instruction::ref_null_type(
      @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::select(types=Some([base_ref])),
  ]
  let rewritten_left = @lib.Instruction::ref_null_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let rewritten_select = @lib.Instruction::select(types=Some([refined_ref]))
  match
    dae_apply_select_value_rewrites_to_body(
      body,
      0,
      1,
      3,
      Some(rewritten_left),
      None,
      Some(rewritten_select),
    ) {
    Some((rewritten, evidence)) => {
      assert_true(evidence.body_changed)
      assert_eq(evidence.left_idx, 0)
      assert_eq(evidence.right_idx, 1)
      assert_eq(evidence.select_idx, 3)
      assert_eq(evidence.rewrite_count, 2)
      assert_eq(rewritten[0], rewritten_left)
      assert_eq(rewritten[1], body[1])
      assert_eq(rewritten[3], rewritten_select)
    }
    None => fail("expected select rewrite application evidence")
  }
  match
    dae_apply_select_value_rewrites_to_body(body, 0, 1, 3, None, None, None) {
    Some((rewritten, evidence)) => {
      assert_false(evidence.body_changed)
      assert_eq(evidence.rewrite_count, 0)
      assert_eq(rewritten, body)
    }
    None => fail("expected unchanged select rewrite application evidence")
  }
  match
    dae_apply_select_value_rewrites_to_body(
      body,
      0,
      3,
      1,
      None,
      None,
      Some(rewritten_select),
    ) {
    Some(_) => fail("select rewrite application must reject unsorted slots")
    None => ()
  }
  match
    dae_apply_select_value_rewrites_to_body(
      body,
      0,
      1,
      4,
      None,
      None,
      Some(rewritten_select),
    ) {
    Some(_) => fail("select rewrite application must reject out-of-range slots")
    None => ()
  }
}

///|
test "dae mixed return-arm rewrite evidence centralizes refined slot repairs" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let old_slot = @lib.Instruction::block(
    @lib.BlockType::val_type(base_ref),
    @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
  )
  let scalar_slot = @lib.Instruction::i32_const(@lib.I32(7))
  let result_body = [old_slot, scalar_slot]
  let result_slice = match
    dae_make_multi_result_control_slice(result_body, 0, 2, 0, false, false) {
    Some(slice) => slice
    None => fail("expected mixed return-arm result slice")
  }
  let control_result = match
    dae_control_result_slice_gc_evidence(mod_, [], None, result_slice, [
      base_ref,
      @lib.ValType::i32(),
    ]) {
    Some(evidence) => evidence
    None => fail("expected shared mixed return-arm control evidence")
  }
  let evidence : DaeMixedMultiResultReturnArmGcEvidence = {
    body: control_result.body,
    result_start: control_result.result_start,
    flattened: false,
    has_return: true,
    effect_free_fallthrough: false,
    control_result: Some(control_result),
  }
  match
    dae_apply_mixed_multi_result_return_arm_refinements(evidence, [true, false]) {
    Some(rewrite) => {
      assert_true(rewrite.body_changed)
      assert_eq(
        rewrite.body[0],
        @lib.Instruction::block(
          @lib.BlockType::val_type(leaf_ref),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
        ),
      )
      assert_eq(rewrite.body[1], scalar_slot)
    }
    None => fail("expected mixed return-arm rewrite evidence")
  }
  let fallthrough : DaeMixedMultiResultReturnArmGcEvidence = {
    body: [scalar_slot],
    result_start: -1,
    flattened: false,
    has_return: false,
    effect_free_fallthrough: true,
    control_result: None,
  }
  match
    dae_apply_mixed_multi_result_return_arm_refinements(fallthrough, [true]) {
    Some(rewrite) => {
      assert_false(rewrite.body_changed)
      assert_eq(rewrite.body[0], scalar_slot)
    }
    None => fail("expected fallthrough arm rewrite evidence")
  }
}

///|
test "dae GC actual shape evidence centralizes control and select repairs" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let expected_nullable_leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(leaf_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let control_body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::block(
      @lib.BlockType::val_type(expected_leaf_ref),
      @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
    ),
  ]
  let control_shape = match
    dae_gc_actual_shape_discovery_evidence(
      control_body,
      { start: 0, end: 2, pure: true },
      mod_,
      [],
    ) {
    Some(evidence) => evidence
    None => fail("expected control actual shape discovery")
  }
  match
    dae_gc_actual_type_evidence(control_body, control_shape, mod_, base_ref, []) {
    Some(evidence) => {
      assert_eq(evidence.candidate, expected_leaf_ref)
      assert_eq(evidence.refined_candidate, Some(expected_leaf_ref))
      assert_true(evidence.select is None)
      assert_eq(evidence.terminal_rewrite, None)
    }
    None => fail("expected control actual type evidence")
  }
  let select_body = [
    @lib.Instruction::ref_null_type(
      @lib.RefType::new(true, @lib.HeapType::new(base_type)),
    ),
    @lib.Instruction::struct_new_default(leaf_type),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::select(types=Some([base_ref])),
  ]
  let select_shape = match
    dae_gc_actual_shape_discovery_evidence(
      select_body,
      { start: 0, end: 6, pure: true },
      mod_,
      [],
    ) {
    Some(evidence) => evidence
    None => fail("expected select actual shape discovery")
  }
  match
    dae_gc_actual_type_evidence(
      select_body,
      select_shape,
      mod_,
      expected_nullable_leaf_ref,
      [],
      rewrite_type=Some(expected_nullable_leaf_ref),
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, expected_nullable_leaf_ref)
      assert_eq(evidence.refined_candidate, None)
      let select = match evidence.select {
        Some(select) => select
        None => fail("expected retained select slice evidence")
      }
      assert_eq(select.slices.left.start, 0)
      assert_eq(select.slices.right.start, 1)
      assert_eq(select.slices.condition.start, 2)
      assert_eq(select.slices.condition.end, 5)
      assert_eq(select.slices.select_idx, 5)
      assert_eq(
        select.gc.left_rewrite,
        Some(
          @lib.Instruction::ref_null_type(
            @lib.RefType::new(true, @lib.HeapType::new(leaf_type), exact=true),
          ),
        ),
      )
      assert_eq(select.gc.right_rewrite, None)
      assert_eq(
        evidence.terminal_rewrite,
        Some(@lib.Instruction::select(types=Some([expected_nullable_leaf_ref]))),
      )
    }
    None => fail("expected select actual type rewrite evidence")
  }
}

///|
test "dae GC actual shape discovery separates target refinement" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let unrelated_type = @lib.TypeIdx::new(2U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let nullable_leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(leaf_type), exact=true),
  )
  let unrelated_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(unrelated_type)),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let direct_body = [@lib.Instruction::struct_new_default(leaf_type)]
  let direct_shape = match
    dae_gc_actual_shape_discovery_evidence(
      direct_body,
      { start: 0, end: 1, pure: true },
      mod_,
      [],
    ) {
    Some(evidence) => evidence
    None => fail("expected direct actual shape discovery")
  }
  match direct_shape.kind {
    DaeDirectGcActualShape => ()
    _ => fail("expected direct actual shape kind")
  }
  let direct_type = match
    dae_gc_actual_type_evidence(
      direct_body,
      direct_shape,
      mod_,
      base_ref,
      [],
      require_refined=true,
    ) {
    Some(evidence) => evidence
    None => fail("expected direct target-specific GC evidence")
  }
  assert_eq(direct_type.refined_candidate, Some(direct_type.candidate))
  assert_true(direct_type.select is None)
  assert_eq(direct_type.terminal_rewrite, None)

  let control_body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::block(
      @lib.BlockType::val_type(direct_type.candidate),
      @lib.Expr::new(direct_body),
    ),
  ]
  let control_shape = match
    dae_gc_actual_shape_discovery_evidence(
      control_body,
      { start: 0, end: 2, pure: true },
      mod_,
      [],
    ) {
    Some(evidence) => evidence
    None => fail("expected control actual shape discovery")
  }
  match control_shape.kind {
    DaeBlockGcActualShape => ()
    _ => fail("expected block actual shape kind")
  }
  match
    dae_gc_actual_type_evidence(
      control_body,
      control_shape,
      mod_,
      base_ref,
      [],
      require_refined=true,
    ) {
    Some(evidence) => assert_eq(evidence.candidate, direct_type.candidate)
    None => fail("expected current-body control candidate evidence")
  }

  let select_body = [
    @lib.Instruction::ref_null_type(
      @lib.RefType::new(true, @lib.HeapType::new(base_type)),
    ),
    @lib.Instruction::struct_new_default(leaf_type),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::select(types=Some([base_ref])),
  ]
  let select_shape = match
    dae_gc_actual_shape_discovery_evidence(
      select_body,
      { start: 0, end: 4, pure: true },
      mod_,
      [],
    ) {
    Some(evidence) => evidence
    None => fail("expected select actual shape discovery")
  }
  match select_shape.kind {
    DaeSelectGcActualShape(slices) => {
      assert_eq(slices.left.start, 0)
      assert_eq(slices.right.start, 1)
      assert_eq(slices.select_idx, 3)
    }
    _ => fail("expected select actual shape kind")
  }
  let candidate_only = match
    dae_gc_actual_type_evidence(
      select_body,
      select_shape,
      mod_,
      nullable_leaf_ref,
      [],
    ) {
    Some(evidence) => evidence
    None => fail("expected candidate-only select evidence")
  }
  assert_eq(candidate_only.candidate, nullable_leaf_ref)
  assert_eq(candidate_only.refined_candidate, None)
  assert_eq(candidate_only.terminal_rewrite, None)
  let rewrite = match
    dae_gc_actual_type_evidence(
      select_body,
      select_shape,
      mod_,
      nullable_leaf_ref,
      [],
      rewrite_type=Some(nullable_leaf_ref),
    ) {
    Some(evidence) => evidence
    None => fail("expected nullable select rewrite evidence")
  }
  assert_true(rewrite.select is Some(_))
  assert_eq(
    rewrite.terminal_rewrite,
    Some(@lib.Instruction::select(types=Some([nullable_leaf_ref]))),
  )
  match
    dae_gc_actual_type_evidence(
      select_body,
      select_shape,
      mod_,
      unrelated_ref,
      [],
      require_refined=true,
    ) {
    Some(_) => fail("wrong target type must reject retained select shape")
    None => ()
  }
  let stale_body = select_body.copy()
  stale_body[3] = @lib.Instruction::drop()
  match
    dae_gc_actual_type_evidence(
      stale_body,
      select_shape,
      mod_,
      nullable_leaf_ref,
      [],
    ) {
    Some(_) => fail("stale select shape must reject a changed terminal body")
    None => ()
  }
}

///|
test "dae select value slices centralize operand and condition bounds" {
  let ref_type = @lib.TypeIdx::new(0U)
  let ref_val = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(ref_type)),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let body = [
    @lib.Instruction::struct_new_default(ref_type),
    @lib.Instruction::block(
      @lib.BlockType::val_type(ref_val),
      @lib.Expr::new([@lib.Instruction::struct_new_default(ref_type)]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::select(types=Some([ref_val])),
  ]
  match dae_find_select_value_slices(mod_, [], body, 3) {
    Some(slices) => {
      assert_eq(slices.left.start, 0)
      assert_eq(slices.left.end, 1)
      assert_eq(slices.right.start, 1)
      assert_eq(slices.right.end, 2)
      assert_eq(slices.condition.start, 2)
      assert_eq(slices.condition.end, 3)
      assert_eq(slices.condition.instr_count, 1)
      assert_eq(slices.select_idx, 3)
      assert_false(slices.left.has_effect_or_branch)
      assert_false(slices.right.has_effect_or_branch)
      assert_true(dae_select_value_slices_are_consistent(slices, 3))
    }
    None => fail("expected reusable select value slice bounds")
  }
  match dae_find_select_value_slices(mod_, [], body, 3, required_left_start=1) {
    Some(_) => fail("expected required left-start mismatch to reject slices")
    None => ()
  }
  let stacked_condition_body = [
    @lib.Instruction::struct_new_default(ref_type),
    @lib.Instruction::block(
      @lib.BlockType::val_type(ref_val),
      @lib.Expr::new([@lib.Instruction::struct_new_default(ref_type)]),
    ),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::select(types=Some([ref_val])),
  ]
  match dae_find_select_value_slices(mod_, [], stacked_condition_body, 4) {
    Some(slices) => {
      assert_eq(slices.condition.start, 2)
      assert_eq(slices.condition.end, 4)
      assert_eq(slices.condition.instr_count, 2)
      assert_true(slices.condition.stack_slice is Some(_))
      assert_true(dae_select_value_slices_are_consistent(slices, 4))
    }
    None => fail("expected stack-slice condition evidence on select slices")
  }
}

///|
test "dae multi-result suffix bounds centralize terminal result scans" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i64_const(@lib.I64(3L)),
  ]
  let bounds = dae_multi_result_suffix_bounds_evidence(body, 2, 1)
  assert_eq(bounds.length(), 2)
  assert_eq(bounds[0].suffix_start, 0)
  assert_eq(bounds[0].operand_end, 4)
  assert_false(bounds[0].has_terminal_return)
  assert_eq(bounds[1].suffix_start, 2)
  assert_eq(bounds[1].operand_end, 4)
  assert_false(bounds[1].has_terminal_return)

  let terminal_body = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::i64_const(@lib.I64(6L)),
    @lib.Instruction::return_(),
  ]
  let terminal_bounds = dae_multi_result_suffix_bounds_evidence(
    terminal_body, 2, 1,
  )
  assert_eq(terminal_bounds.length(), 4)
  assert_eq(terminal_bounds[2].suffix_start, 0)
  assert_eq(terminal_bounds[2].operand_end, 4)
  assert_true(terminal_bounds[2].has_terminal_return)
  assert_eq(terminal_bounds[3].suffix_start, 2)
  assert_eq(terminal_bounds[3].operand_end, 4)
  assert_true(terminal_bounds[3].has_terminal_return)

  let too_short_select = dae_multi_result_suffix_bounds_evidence(body, 2, 3)
  assert_eq(too_short_select.length(), 0)
}

///|
test "dae operand disposition centralizes removed operand repair" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ]
  let pure_disp = match dae_operand_disposition_from_range(body, 0, 2) {
    Some(disposition) => disposition
    None => fail("expected pure operand disposition")
  }
  assert_true(pure_disp.droppable_without_repair)
  assert_false(pure_disp.preserve_effects_on_removal)
  assert_false(pure_disp.has_effect_or_branch)
  let call_disp = match dae_operand_disposition_from_range(body, 2, 3) {
    Some(disposition) => disposition
    None => fail("expected effectful operand disposition")
  }
  assert_false(call_disp.droppable_without_repair)
  assert_true(call_disp.preserve_effects_on_removal)
  assert_true(call_disp.has_effect_or_branch)
  let pure_rewrite = dae_operand_rewrite_disposition(
    pure_disp,
    localization_available=false,
    has_escaping_branch=false,
  )
  let call_rewrite = dae_operand_rewrite_disposition(
    call_disp,
    localization_available=false,
    has_escaping_branch=false,
  )
  assert_true(dae_operand_rewrite_drops_directly(pure_rewrite))
  assert_true(
    dae_operand_rewrite_preserves_effects_and_drops_value(call_rewrite),
  )
  let branch_body = [@lib.Instruction::br(@lib.LabelIdx::new(0U))]
  let branch_disp = match
    dae_operand_disposition_from_range(branch_body, 0, 1) {
    Some(disposition) => disposition
    None => fail("expected branch operand disposition")
  }
  let branch_rewrite = dae_operand_rewrite_disposition(
    branch_disp,
    localization_available=false,
    has_escaping_branch=true,
  )
  assert_true(dae_operand_rewrite_rejects_escaping_branch(branch_rewrite))
  assert_false(
    dae_operand_rewrite_preserves_effects_and_drops_value(branch_rewrite),
  )
  let dropped : Array[@lib.Instruction] = []
  dae_append_operand_with_removal_plan(
    dropped,
    body,
    dae_operand_removal_plan(call_rewrite, false),
  )
  assert_eq(dropped, [body[2], @lib.Instruction::drop()])
  let kept : Array[@lib.Instruction] = []
  dae_append_operand_with_removal_plan(
    kept,
    body,
    dae_operand_removal_plan(pure_rewrite, true),
  )
  assert_eq(kept, [body[0], body[1]])
}

///|
test "dae operand rewrite disposition separates removal localization and rejection" {
  let pure_body = [@lib.Instruction::i32_const(@lib.I32(7))]
  let pure = match dae_operand_disposition_from_range(pure_body, 0, 1) {
    Some(disposition) => disposition
    None => fail("expected pure operand disposition")
  }
  let direct_drop = dae_operand_rewrite_disposition(
    pure,
    localization_available=false,
    has_escaping_branch=false,
  )
  assert_true(dae_operand_rewrite_drops_directly(direct_drop))
  assert_true(dae_operand_rewrite_disposition_is_consistent(direct_drop))

  let effectful_body = [@lib.Instruction::call(@lib.FuncIdx::new(0U))]
  let effectful = match
    dae_operand_disposition_from_range(effectful_body, 0, 1) {
    Some(disposition) => disposition
    None => fail("expected effectful operand disposition")
  }
  let preserve = dae_operand_rewrite_disposition(
    effectful,
    localization_available=false,
    has_escaping_branch=false,
  )
  assert_true(dae_operand_rewrite_preserves_effects_and_drops_value(preserve))
  let preserve_plan = dae_operand_removal_plan(preserve, false)
  assert_true(dae_operand_removal_plan_is_consistent(preserve, preserve_plan))
  assert_true(preserve_plan.replay_operand)
  assert_true(preserve_plan.append_drop)

  let localize = dae_operand_rewrite_disposition(
    effectful,
    localization_available=true,
    has_escaping_branch=false,
  )
  assert_true(dae_operand_rewrite_localizes_and_retries(localize))
  assert_true(dae_operand_rewrite_disposition_is_consistent(localize))
  let localize_plan = dae_operand_removal_plan(localize, false)
  assert_true(dae_operand_removal_plan_is_consistent(localize, localize_plan))
  assert_true(localize_plan.requires_localization_retry)
  assert_false(localize_plan.replay_operand)
  assert_false(localize_plan.append_drop)

  let branch_body = [@lib.Instruction::br(@lib.LabelIdx::new(0U))]
  let branch = match dae_operand_disposition_from_range(branch_body, 0, 1) {
    Some(disposition) => disposition
    None => fail("expected branching operand disposition")
  }
  let reject = dae_operand_rewrite_disposition(
    branch,
    localization_available=true,
    has_escaping_branch=true,
  )
  assert_true(dae_operand_rewrite_rejects_escaping_branch(reject))
  assert_true(dae_operand_rewrite_disposition_is_consistent(reject))
  let reject_plan = dae_operand_removal_plan(reject, false)
  assert_true(dae_operand_removal_plan_is_consistent(reject, reject_plan))
  assert_true(reject_plan.rejects_direct_removal)
  assert_false(reject_plan.requires_localization_retry)
}

///|
test "dae instruction observability evidence blocks effects branches and traps" {
  let pure = dae_instruction_observability_evidence(
    @lib.Instruction::i32_const(@lib.I32(1)),
  )
  assert_false(pure.has_observable_effect)
  assert_false(pure.has_branch_control)
  assert_false(pure.may_trap_or_unknown)
  assert_true(pure.erasable_before_unreachable)
  assert_true(dae_instruction_observability_evidence_is_consistent(pure))

  let effect = dae_instruction_observability_evidence(
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  )
  assert_true(effect.has_observable_effect)
  assert_false(effect.erasable_before_unreachable)
  assert_true(dae_instruction_observability_evidence_is_consistent(effect))

  let branch = dae_instruction_observability_evidence(
    @lib.Instruction::return_(),
  )
  assert_true(branch.has_branch_control)
  assert_false(branch.erasable_before_unreachable)
  assert_true(dae_instruction_observability_evidence_is_consistent(branch))

  let trap = dae_instruction_observability_evidence(
    @lib.Instruction::i32_div_s(),
  )
  assert_true(trap.may_trap_or_unknown)
  assert_false(trap.erasable_before_unreachable)
  assert_true(dae_instruction_observability_evidence_is_consistent(trap))
}

///|
test "dae dead suffix evidence centralizes unreachable tails" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(@lib.FuncIdx::new(2U)),
    @lib.Instruction::drop(),
  ]
  match dae_dead_suffix_evidence(body) {
    Some(evidence) => {
      assert_eq(evidence.root_idx, 1)
      assert_eq(evidence.suffix_start, 2)
      assert_eq(evidence.suffix, [body[2], body[3]])
    }
    None => fail("expected dead suffix evidence")
  }
  match dae_dead_suffix_evidence([@lib.Instruction::nop()]) {
    Some(_) => fail("non-terminal bodies must not expose dead suffix evidence")
    None => ()
  }
}

///|
test "dae direct call target evidence centralizes count and live undropped facts" {
  let callee = @lib.FuncIdx::new(2U)
  let block_type = @lib.BlockType::void_()
  let body = [
    @lib.Instruction::call(callee),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      block_type,
      @lib.Expr::new([@lib.Instruction::call(callee)]),
    ),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(callee),
    @lib.Instruction::return_call(callee),
  ]
  let evidence = dae_direct_call_target_evidence(body, 2)
  assert_eq(evidence.direct_call_count, 3)
  assert_eq(evidence.dropped_direct_call_count, 1)
  assert_true(evidence.has_direct_call)
  assert_true(evidence.has_undropped_direct_call)
  assert_true(evidence.has_live_undropped_direct_call)

  let dead_suffix_only = [
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(callee),
  ]
  let dead_evidence = dae_direct_call_target_evidence(dead_suffix_only, 2)
  assert_eq(dead_evidence.direct_call_count, 1)
  assert_true(dead_evidence.has_undropped_direct_call)
  assert_false(dead_evidence.has_live_undropped_direct_call)
  assert_eq(dae_count_direct_call_anywhere_to(dead_suffix_only, 2), 1)
  assert_false(
    dae_direct_call_target_evidence(dead_suffix_only, 2).has_live_undropped_direct_call,
  )
}

///|
test "dae dead suffix direct call evidence centralizes dropped and undropped facts" {
  let callee = @lib.FuncIdx::new(2U)
  let block_type = @lib.BlockType::void_()
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(callee),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      block_type,
      @lib.Expr::new([@lib.Instruction::call(callee)]),
    ),
    @lib.Instruction::return_call(callee),
  ]
  match dae_dead_suffix_direct_call_evidence(body, 2) {
    Some(evidence) => {
      assert_true(evidence.has_dropped_direct_call)
      assert_true(evidence.has_undropped_direct_call)
    }
    None => fail("expected reusable dead-suffix direct-call evidence")
  }
  match dae_dead_suffix_direct_call_evidence([@lib.Instruction::nop()], 2) {
    Some(_) => fail("non-dead suffix body must not expose target facts")
    None => ()
  }
}

///|
test "dae control-result undropped direct-call evidence centralizes suffix block scans" {
  let callee = @lib.FuncIdx::new(2U)
  let result_block = @lib.Instruction::block(
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @lib.Expr::new([@lib.Instruction::call(callee)]),
  )
  match dae_control_result_undropped_direct_call_evidence(result_block, 2) {
    Some(evidence) => {
      assert_true(evidence.result_arity_known)
      assert_eq(evidence.result_arity, 1)
      assert_true(evidence.has_result)
      assert_true(evidence.primary_has_undropped_direct_call)
      assert_false(evidence.secondary_has_undropped_direct_call)
      assert_true(evidence.has_undropped_direct_call)
      assert_true(evidence.blocks_result_removal)
    }
    None => fail("expected result block evidence")
  }

  let void_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [@lib.Instruction::call(callee)],
    Some([@lib.Instruction::call(callee)]),
  )
  match dae_control_result_undropped_direct_call_evidence(void_if, 2) {
    Some(evidence) => {
      assert_true(evidence.result_arity_known)
      assert_eq(evidence.result_arity, 0)
      assert_false(evidence.has_result)
      assert_true(evidence.primary_has_undropped_direct_call)
      assert_true(evidence.secondary_has_undropped_direct_call)
      assert_true(evidence.has_undropped_direct_call)
      assert_false(evidence.blocks_result_removal)
    }
    None => fail("expected void if evidence")
  }

  let typeidx_if = @lib.Instruction::if_(
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    [],
    Some([@lib.Instruction::call(callee)]),
  )
  match dae_control_result_undropped_direct_call_evidence(typeidx_if, 2) {
    Some(evidence) => {
      assert_false(evidence.result_arity_known)
      assert_eq(evidence.result_arity, 0)
      assert_true(evidence.has_result)
      assert_false(evidence.primary_has_undropped_direct_call)
      assert_true(evidence.secondary_has_undropped_direct_call)
      assert_true(evidence.blocks_result_removal)
    }
    None => fail("expected typeidx if evidence")
  }

  match
    dae_control_result_undropped_direct_call_evidence(
      @lib.Instruction::call(callee),
      2,
    ) {
    Some(_) => fail("non-control instruction must not expose control evidence")
    None => ()
  }
}

///|
test "dae stack operand evidence centralizes source slices and updates" {
  let bool_stack = [false, true, true, false]
  let window = match dae_stack_operand_window_evidence(bool_stack.length(), 2) {
    Some(window) => window
    None => fail("expected reusable top-of-stack operand window")
  }
  assert_eq(window.start, 2)
  assert_eq(window.end, 4)
  assert_eq(window.requested_operands, 2)
  assert_eq(window.available_operands, 2)
  let underfull = match dae_stack_operand_window_evidence(1, 3) {
    Some(window) => window
    None => fail("expected underfull stack window to keep available operands")
  }
  assert_eq(underfull.start, 0)
  assert_eq(underfull.end, 1)
  assert_eq(underfull.requested_operands, 3)
  assert_eq(underfull.available_operands, 1)
  assert_true(dae_stack_bool_has_true_operand(bool_stack, 2))
  assert_false(dae_stack_bool_has_true_operand(bool_stack, 1))
  dae_stack_bool_apply_effect(bool_stack, 2, 3, true)
  assert_eq(bool_stack, [false, true, true, true, true])

  let int_stack = [-1, 2, 3, 2]
  assert_true(dae_stack_int_has_known_operand(int_stack, 2))
  assert_true(dae_stack_int_has_operand_value(int_stack, 2, 3))
  assert_false(dae_stack_int_has_operand_value(int_stack, 1, 3))
  dae_stack_int_apply_effect(int_stack, 3, 2, -1)
  assert_eq(int_stack, [-1, -1, -1])
}

///|
test "dae stack effect evidence centralizes provenance updates" {
  let mod_ = @lib.Module::new()
  match dae_stack_effect_evidence(@lib.Instruction::i32_add(), mod_, []) {
    Some(evidence) => {
      assert_eq(evidence.inputs, 2)
      assert_eq(evidence.outputs, 1)
    }
    None => fail("expected reusable stack-effect evidence")
  }

  match
    dae_stack_single_value_producer_evidence(
      @lib.Instruction::i32_const(@lib.I32(7)),
      mod_,
      [],
    ) {
    Some(evidence) => {
      assert_eq(evidence.inputs, 0)
      assert_eq(evidence.outputs, 1)
    }
    None => fail("expected reusable stack single-value producer evidence")
  }
  match
    dae_stack_single_value_producer_evidence(
      @lib.Instruction::i32_add(),
      mod_,
      [],
    ) {
    Some(_) => fail("binary op consumes operands before producing one value")
    None => ()
  }

  let bool_stack = [true, false]
  assert_true(
    dae_stack_bool_apply_instr_effect(
      bool_stack,
      @lib.Instruction::i32_add(),
      mod_,
      [],
      true,
    ),
  )
  assert_eq(bool_stack, [true])
  assert_false(
    dae_stack_bool_apply_instr_effect(
      bool_stack,
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      mod_,
      [],
      false,
    ),
  )
  assert_eq(bool_stack, [true])

  let int_stack = [1, 2]
  assert_true(
    dae_stack_int_apply_instr_effect(
      int_stack,
      @lib.Instruction::i32_add(),
      mod_,
      [],
      -1,
    ),
  )
  assert_eq(int_stack, [-1])
  assert_true(
    dae_stack_int_apply_instr_effect(
      int_stack,
      @lib.Instruction::i32_const(@lib.I32(7)),
      mod_,
      [],
      7,
    ),
  )
  assert_eq(int_stack, [-1, 7])
}

///|
test "dae escaping branch evidence centralizes localization blockers" {
  let local_block = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
  )
  match dae_escaping_branch_evidence([local_block], 0) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 1)
      assert_eq(evidence.depth, 0)
      assert_eq(evidence.instr_count, 1)
      assert_false(evidence.has_escaping_branch)
    }
    None => fail("expected reusable no-escaping-branch evidence")
  }
  match dae_no_escaping_branch_evidence([local_block], 0) {
    Some(evidence) => assert_false(evidence.has_escaping_branch)
    None => fail("local branch should be accepted by no-escape evidence")
  }
  match
    dae_escaping_branch_evidence(
      [@lib.Instruction::br(@lib.LabelIdx::new(0U))],
      0,
    ) {
    Some(evidence) => assert_true(evidence.has_escaping_branch)
    None => fail("expected escaping branch evidence")
  }
  match
    dae_no_escaping_branch_evidence(
      [@lib.Instruction::br(@lib.LabelIdx::new(0U))],
      0,
    ) {
    Some(_) => fail("top-level branch should escape depth zero")
    None => ()
  }
  let mixed_instrs = [local_block, @lib.Instruction::br(@lib.LabelIdx::new(0U))]
  match dae_no_escaping_branch_prefix_evidence(mixed_instrs, 1, 0) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 1)
      assert_false(evidence.has_escaping_branch)
    }
    None => fail("local branch prefix should be accepted by prefix evidence")
  }
  match dae_no_escaping_branch_range_evidence(mixed_instrs, 0, 1, 0) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 1)
      assert_false(evidence.has_escaping_branch)
    }
    None => fail("local branch prefix should be accepted by range evidence")
  }
  match dae_no_escaping_branch_copied_slice_evidence(mixed_instrs, 0, 1, 0) {
    Some(evidence) => {
      assert_eq(evidence.branch.start, 0)
      assert_eq(evidence.branch.end, 1)
      assert_false(evidence.branch.has_escaping_branch)
      assert_eq(evidence.instrs.length(), 1)
      assert_eq(evidence.instrs[0], local_block)
    }
    None =>
      fail("local branch prefix should be copied by shared slice evidence")
  }
  match dae_no_escaping_branch_copied_slice_evidence(mixed_instrs, 1, 2, 0) {
    Some(_) => fail("top-level branch slice should not be copied")
    None => ()
  }
  match dae_no_escaping_branch_copied_range_evidence(mixed_instrs, 0, 1, 0) {
    Some(evidence) => {
      assert_eq(evidence.branch.start, 0)
      assert_eq(evidence.branch.end, 1)
      assert_false(evidence.branch.has_escaping_branch)
      assert_eq(evidence.instrs.length(), 1)
      assert_eq(evidence.instrs[0], local_block)
    }
    None => fail("local branch prefix should be copied by range evidence")
  }
  match dae_no_escaping_branch_copied_prefix_evidence(mixed_instrs, 1, 0) {
    Some(evidence) => {
      assert_eq(evidence.branch.start, 0)
      assert_eq(evidence.branch.end, 1)
      assert_false(evidence.branch.has_escaping_branch)
      assert_eq(evidence.instrs.length(), 1)
      assert_eq(evidence.instrs[0], local_block)
    }
    None => fail("local branch prefix should be copied by prefix evidence")
  }
  match dae_no_escaping_branch_copied_suffix_evidence(mixed_instrs, 1, 0) {
    Some(_) => fail("top-level branch suffix should not be copied")
    None => ()
  }
  match dae_terminal_no_escape_prefix_evidence(mixed_instrs, 0) {
    Some(evidence) => {
      assert_eq(evidence.terminal_idx, 1)
      assert_eq(evidence.prefix.branch.start, 0)
      assert_eq(evidence.prefix.branch.end, 1)
      assert_eq(evidence.prefix.instrs, [local_block])
      assert_eq(evidence.terminal, @lib.Instruction::br(@lib.LabelIdx::new(0U)))
    }
    None => fail("terminal no-escape prefix should copy only the safe prefix")
  }
  match
    dae_terminal_no_escape_prefix_evidence(
      [@lib.Instruction::br(@lib.LabelIdx::new(0U)), @lib.Instruction::drop()],
      0,
    ) {
    Some(_) => fail("terminal no-escape prefix should reject escaping prefixes")
    None => ()
  }
  match dae_terminal_no_escape_prefix_evidence([], 0) {
    Some(_) => fail("terminal no-escape prefix should reject empty bodies")
    None => ()
  }
  let terminal_then = [@lib.Instruction::br(@lib.LabelIdx::new(1U))]
  let terminal_else = [local_block]
  let terminal_loop_body = [
    local_block,
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      terminal_then,
      Some(terminal_else),
    ),
  ]
  match
    dae_terminal_if_no_escape_carrier_evidence(terminal_loop_body, 1, None) {
    Some(evidence) => {
      assert_eq(evidence.condition_prefix.branch.start, 0)
      assert_eq(evidence.condition_prefix.branch.end, 1)
      assert_eq(evidence.condition_prefix.instrs, [local_block])
      assert_eq(evidence.then_body, terminal_then)
      match evidence.else_body {
        Some(else_evidence) => {
          assert_eq(else_evidence.branch.start, 0)
          assert_eq(else_evidence.branch.end, 1)
          assert_eq(else_evidence.instrs, terminal_else)
        }
        None => fail("terminal if carrier should copy no-escape else body")
      }
    }
    None => fail("terminal if carrier should accept no-escape prefix and else")
  }
  let escaping_else_loop_body = [
    local_block,
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      terminal_then,
      Some([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
    ),
  ]
  match
    dae_terminal_if_no_escape_carrier_evidence(escaping_else_loop_body, 1, None) {
    Some(_) => fail("terminal if carrier should reject escaping else body")
    None => ()
  }
  match dae_escaping_branch_range_evidence(mixed_instrs, 1, 2, 0) {
    Some(evidence) => {
      assert_eq(evidence.start, 1)
      assert_eq(evidence.end, 2)
      assert_true(evidence.has_escaping_branch)
    }
    None => fail("top-level branch range should produce escaping evidence")
  }
  match dae_no_escaping_branch_range_evidence(mixed_instrs, 1, 2, 0) {
    Some(_) =>
      fail("top-level branch range should be rejected by no-escape evidence")
    None => ()
  }
  match dae_no_escaping_branch_suffix_evidence(mixed_instrs, 1, 0) {
    Some(_) =>
      fail("top-level branch suffix should be rejected by no-escape evidence")
    None => ()
  }
  match dae_no_escaping_branch_prefix_evidence(mixed_instrs, 3, 0) {
    Some(_) => fail("oversized prefix should be rejected by prefix evidence")
    None => ()
  }
  match dae_escaping_branch_range_evidence(mixed_instrs, -1, 1, 0) {
    Some(_) => fail("negative branch range start should be rejected")
    None => ()
  }
  match dae_escaping_branch_evidence([], -1) {
    Some(_) => fail("negative branch depth should be rejected")
    None => ()
  }
}

///|
test "dae multi result carrier chain evidence centralizes fallthrough and return slices" {
  let pair_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i64()]),
    ),
  )
  let mod_ = @lib.Module::new().with_type_sec(@lib.TypeSec::new([pair_type]))
  let pair_carrier = @lib.Instruction::block(
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::i64_const(@lib.I64(9L)),
    ]),
  )
  match
    dae_multi_result_control_carrier_chain_slice(
      mod_,
      [pair_carrier],
      2,
      terminal_return=false,
      match_terminal_return=false,
      append_terminal_return=false,
    ) {
    Some(evidence) => {
      assert_true(evidence.flattened)
      assert_false(evidence.terminal_return)
      assert_eq(evidence.carrier_kind, 1)
      assert_eq(evidence.slice.start, 0)
      assert_eq(evidence.slice.end, 2)
      assert_eq(evidence.body.length(), 2)
    }
    None => fail("expected fallthrough carrier-chain slice evidence")
  }
  match
    dae_multi_result_control_carrier_chain_slice(
      mod_,
      [pair_carrier],
      2,
      terminal_return=true,
      match_terminal_return=false,
      append_terminal_return=true,
    ) {
    Some(evidence) => {
      assert_true(evidence.flattened)
      assert_true(evidence.terminal_return)
      assert_eq(evidence.carrier_kind, 1)
      assert_eq(evidence.slice.start, 0)
      assert_eq(evidence.slice.end, 2)
      assert_eq(evidence.body.length(), 3)
      match evidence.body[2] {
        @lib.Return => ()
        _ => fail("expected appended terminal return")
      }
    }
    None => fail("expected terminal carrier-chain slice evidence")
  }
  match
    dae_multi_result_control_carrier_chain_slice(
      mod_,
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i64_const(@lib.I64(2L)),
        @lib.Instruction::return_(),
      ],
      2,
      terminal_return=true,
      match_terminal_return=true,
      append_terminal_return=false,
    ) {
    Some(evidence) => {
      assert_false(evidence.flattened)
      assert_true(evidence.terminal_return)
      assert_eq(evidence.carrier_kind, 0)
      assert_eq(evidence.slice.start, 0)
      assert_eq(evidence.slice.end, 2)
    }
    None => fail("expected direct terminal-return slice evidence")
  }
}

///|
test "dae multi result operand sequence evidence shares specialized and fallback slots" {
  let mod_ = @lib.Module::new()
  let body = [
    @lib.Instruction::i32_const(@lib.I32(99)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i64_const(@lib.I64(9L)),
    @lib.Instruction::return_(),
  ]
  let specialize = fn(
    _ : Array[@lib.Instruction],
    operand_start : Int,
    operand_end : Int,
    result_idx : Int,
  ) -> (Int, Int)? {
    if result_idx == 0 && operand_start < operand_end {
      Some((operand_start, operand_start + 1))
    } else {
      None
    }
  }
  match
    dae_multi_result_operand_sequence_evidence(mod_, [], body, 2, 1, specialize) {
    Some(evidence) => {
      assert_eq(evidence.bounds.suffix_start, 0)
      assert_eq(evidence.bounds.operand_end, 4)
      assert_true(evidence.bounds.has_terminal_return)
      assert_eq(evidence.operand_starts, [2, 3])
      assert_eq(evidence.value_instr_indices, [2, 3])
      assert_eq(evidence.specialized_slots, [true, false])
    }
    None => fail("expected shared specialized/fallback operand sequence")
  }
  let reject_all = fn(
    _ : Array[@lib.Instruction],
    _ : Int,
    _ : Int,
    _ : Int,
  ) -> (Int, Int)? {
    None
  }
  match
    dae_multi_result_operand_sequence_evidence(mod_, [], body, 2, 1, reject_all) {
    Some(_) => fail("sequence must contain at least one specialized slot")
    None => ()
  }
}

///|
test "dae stack slice localization evidence carries transition escape and rewrite disposition" {
  let mod_ = @lib.Module::new()
  let body = [@lib.Instruction::i32_const(@lib.I32(7))]
  let request = dae_stack_slice_localization_request(
    body,
    0,
    body.length(),
    0,
    1,
    0,
    fn(instr) { !dae_instr_has_branch(instr) },
  )
  match dae_stack_slice_localization_evidence_from_request(mod_, [], request) {
    Some(evidence) => {
      assert_eq(evidence.transition.simulation.start, 0)
      assert_eq(evidence.transition.simulation.end, body.length())
      assert_eq(evidence.transition.simulation.final_stack_values, 1)
      assert_eq(evidence.transition.expected_final_stack_values, 1)
      assert_eq(evidence.no_escape_branch.start, 0)
      assert_eq(evidence.no_escape_branch.end, body.length())
      assert_eq(evidence.no_escape_branch.depth, 0)
      assert_false(evidence.no_escape_branch.has_escaping_branch)
      assert_eq(evidence.copied_slice.branch.start, 0)
      assert_eq(evidence.copied_slice.branch.end, body.length())
      assert_eq(evidence.copied_slice.instrs.length(), body.length())
      assert_eq(evidence.disposition.start, 0)
      assert_eq(evidence.disposition.end, body.length())
      assert_eq(evidence.rewrite_disposition.operand.start, 0)
      assert_eq(evidence.rewrite_disposition.operand.end, body.length())
      assert_true(
        dae_operand_rewrite_drops_directly(evidence.rewrite_disposition),
      )
      assert_true(
        dae_operand_rewrite_disposition_is_consistent(
          evidence.rewrite_disposition,
        ),
      )
    }
    None => fail("expected request-backed localization evidence")
  }
  let wrong_final_request = dae_stack_slice_localization_request(
    body,
    0,
    body.length(),
    0,
    0,
    0,
    fn(instr) { !dae_instr_has_branch(instr) },
  )
  match
    dae_stack_slice_localization_evidence_from_request(
      mod_,
      [],
      wrong_final_request,
    ) {
    Some(_) => fail("localization evidence should reject wrong final stack")
    None => ()
  }
  let escaping_request = dae_stack_slice_localization_request(
    [@lib.Instruction::br(@lib.LabelIdx::new(0U))],
    0,
    1,
    0,
    0,
    0,
    fn(_) { true },
  )
  match
    dae_stack_slice_localization_evidence_from_request(
      mod_,
      [],
      escaping_request,
    ) {
    Some(_) => fail("localization evidence should reject escaping branches")
    None => ()
  }
  let parametric_request = dae_stack_slice_localization_request(
    [@lib.Instruction::i32_add(), @lib.Instruction::drop()],
    0,
    2,
    2,
    0,
    0,
    dae_parametric_typeidx_stack_slice_instr_allowed,
  )
  match
    dae_stack_slice_localization_evidence_from_request(
      mod_,
      [],
      parametric_request,
    ) {
    Some(evidence) => {
      assert_eq(evidence.transition.simulation.initial_stack_values, 2)
      assert_eq(evidence.transition.simulation.final_stack_values, 0)
      assert_true(
        dae_operand_rewrite_localizes_and_retries(evidence.rewrite_disposition),
      )
    }
    None => fail("expected parametric request-backed localization evidence")
  }
  let select_policy = dae_select_condition_localization_policy()
  match
    dae_stack_slice_localization_evidence_from_policy(
      mod_,
      [],
      body,
      0,
      body.length(),
      select_policy,
    ) {
    Some(evidence) => {
      assert_eq(evidence.transition.simulation.initial_stack_values, 0)
      assert_eq(evidence.transition.simulation.final_stack_values, 1)
      assert_eq(evidence.no_escape_branch.depth, 0)
      assert_true(
        dae_operand_rewrite_drops_directly(evidence.rewrite_disposition),
      )
    }
    None => fail("expected select policy localization evidence")
  }
  assert_true(
    dae_stack_slice_localization_policy_accepts(
      mod_,
      [],
      body,
      0,
      body.length(),
      select_policy,
    ),
  )
  let parametric_policy = dae_parametric_typeidx_prefix_localization_policy(2)
  match
    dae_stack_slice_localization_evidence_from_policy(
      mod_,
      [],
      [@lib.Instruction::i32_add(), @lib.Instruction::drop()],
      0,
      2,
      parametric_policy,
    ) {
    Some(evidence) => {
      assert_eq(evidence.transition.simulation.initial_stack_values, 2)
      assert_eq(evidence.transition.simulation.final_stack_values, 0)
      assert_true(
        dae_operand_rewrite_localizes_and_retries(evidence.rewrite_disposition),
      )
    }
    None => fail("expected parametric policy localization evidence")
  }
  assert_true(
    dae_stack_slice_localization_policy_accepts(
      mod_,
      [],
      [@lib.Instruction::i32_add(), @lib.Instruction::drop()],
      0,
      2,
      parametric_policy,
    ),
  )
}

///|
test "dae select condition localization evidence unifies singleton and stack slices" {
  let mod_ = @lib.Module::new()
  let singleton = [@lib.Instruction::i32_const(@lib.I32(7))]
  match dae_select_condition_localization_evidence(mod_, singleton, 0, 1, []) {
    Some(evidence) => {
      assert_true(
        dae_select_condition_localization_evidence_is_consistent(evidence),
      )
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 1)
      assert_eq(evidence.instr_count, 1)
      assert_true(evidence.singleton_trivially_droppable)
      match evidence.singleton_producer {
        Some(producer) => {
          assert_eq(producer.inputs, 0)
          assert_eq(producer.outputs, 1)
        }
        None => fail("expected singleton producer evidence")
      }
      match evidence.stack_slice {
        Some(_) =>
          fail(
            "singleton condition should not carry multi-instruction evidence",
          )
        None => ()
      }
    }
    None => fail("expected singleton select-condition localization evidence")
  }
  let multi = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
  ]
  match dae_select_condition_localization_evidence(mod_, multi, 0, 3, []) {
    Some(evidence) => {
      assert_true(
        dae_select_condition_localization_evidence_is_consistent(evidence),
      )
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 3)
      assert_eq(evidence.instr_count, 3)
      assert_false(evidence.singleton_trivially_droppable)
      match evidence.singleton_producer {
        Some(_) =>
          fail(
            "multi-instruction condition should not carry singleton evidence",
          )
        None => ()
      }
      match evidence.stack_slice {
        Some(slice) => {
          assert_eq(slice.transition.simulation.final_stack_values, 1)
          assert_eq(slice.copied_slice.instrs.length(), 3)
          assert_true(
            dae_operand_rewrite_localizes_and_retries(slice.rewrite_disposition),
          )
        }
        None => fail("expected multi-instruction stack-slice evidence")
      }
    }
    None =>
      fail("expected multi-instruction select-condition localization evidence")
  }
  match
    dae_select_condition_localization_evidence(
      mod_,
      [@lib.Instruction::br(@lib.LabelIdx::new(0U))],
      0,
      1,
      [],
    ) {
    Some(_) => fail("branching singleton condition should be rejected")
    None => ()
  }
  match dae_select_condition_localization_evidence(mod_, multi, 2, 2, []) {
    Some(_) => fail("empty condition range should be rejected")
    None => ()
  }
}

///|
test "dae stack slice simulation centralizes condition and typeidx scans" {
  let mod_ = @lib.Module::new()
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
  ]
  let evidence = match
    dae_stack_slice_simulation_evidence(mod_, [], body, 0, body.length(), 0, fn(
      instr,
    ) {
      !dae_instr_has_branch(instr)
    }) {
    Some(evidence) => evidence
    None => fail("expected reusable stack-slice simulation evidence")
  }
  assert_eq(evidence.start, 0)
  assert_eq(evidence.end, body.length())
  assert_eq(evidence.initial_stack_values, 0)
  assert_eq(evidence.final_stack_values, 1)
  assert_eq(evidence.max_stack_values, 2)
  assert_false(evidence.saw_effect_or_branch)
  let transition = match
    dae_stack_slice_transition_evidence(
      mod_,
      [],
      body,
      0,
      body.length(),
      0,
      1,
      fn(instr) { !dae_instr_has_branch(instr) },
    ) {
    Some(evidence) => evidence
    None => fail("expected reusable stack-slice transition evidence")
  }
  assert_eq(transition.expected_final_stack_values, 1)
  assert_eq(transition.simulation.final_stack_values, 1)
  match
    dae_stack_slice_transition_evidence(
      mod_,
      [],
      body,
      0,
      body.length(),
      0,
      0,
      fn(instr) { !dae_instr_has_branch(instr) },
    ) {
    Some(_) => fail("mismatched final stack count should be rejected")
    None => ()
  }
  assert_true(
    dae_select_condition_localization_evidence(mod_, body, 0, 3, []).is_some(),
  )

  match
    dae_stack_slice_simulation_evidence(
      mod_,
      [],
      [@lib.Instruction::i32_add()],
      0,
      1,
      1,
      fn(_) { true },
    ) {
    Some(_) => fail("underfull stack slices should be rejected")
    None => ()
  }
  match
    dae_stack_slice_simulation_evidence(
      mod_,
      [],
      [@lib.Instruction::local_set(@lib.LocalIdx::new(0U))],
      0,
      1,
      1,
      fn(_) { false },
    ) {
    Some(_) => fail("policy-rejected instructions should be rejected")
    None => ()
  }

  assert_true(
    dae_parametric_typeidx_prefix_consumes_params_stack_safe(
      mod_,
      [],
      [@lib.Instruction::i32_add(), @lib.Instruction::drop()],
      2,
      2,
    ),
  )

  let dropped_pairs = [
    @lib.Instruction::i32_const(@lib.I32(99)),
    @lib.Instruction::drop(),
    @lib.Instruction::i64_const(@lib.I64(11L)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ]
  match
    dae_dropped_operand_pair_skip_evidence(
      dropped_pairs,
      0,
      dropped_pairs.length(),
    ) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, dropped_pairs.length())
      assert_eq(evidence.next, 4)
      assert_eq(evidence.skipped_pairs, 2)
    }
    None => fail("expected dropped operand-pair skip evidence")
  }
  match dae_dropped_operand_pair_skip_evidence(dropped_pairs, 4, 2) {
    Some(_) => fail("invalid dropped operand-pair ranges should be rejected")
    None => ()
  }
}

///|
test "dae callsite value evidence centralizes cursor and operand dispositions" {
  let mod_ = @lib.Module::new()
  let body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ]
  match dae_callsite_value_slice_evidence(body, 2, 2, 0, mod_, []) {
    Some(evidence) => {
      assert_eq(evidence.call_idx, 2)
      assert_eq(evidence.arg_count, 2)
      assert_eq(evidence.cursor, 0)
      assert_eq(evidence.entry_stack_values, 0)
      assert_true(
        dae_callsite_value_slice_evidence_is_consistent(evidence, 2, 2, 0),
      )
      assert_eq(evidence.slices.length(), 2)
      assert_eq(evidence.slices[0].start, 0)
      assert_eq(evidence.slices[0].end, 1)
      assert_eq(evidence.slices[1].start, 1)
      assert_eq(evidence.slices[1].end, 2)
      assert_true(
        dae_operand_rewrite_drops_directly(
          dae_operand_rewrite_disposition(
            evidence.slices[0].disposition,
            localization_available=false,
            has_escaping_branch=false,
          ),
        ),
      )
      assert_true(
        dae_operand_rewrite_drops_directly(
          dae_operand_rewrite_disposition(
            evidence.slices[1].disposition,
            localization_available=false,
            has_escaping_branch=false,
          ),
        ),
      )
      assert_true(dae_value_slice_disposition_is_consistent(evidence.slices[0]))
      assert_true(dae_value_slice_disposition_is_consistent(evidence.slices[1]))
    }
    None => fail("expected reusable callsite value evidence")
  }
}

///|
test "dae callsite single instruction actual evidence centralizes slice lookup" {
  let mod_ = @lib.Module::new()
  let body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ]
  let evidence = match
    dae_callsite_value_slice_evidence(body, 2, 2, 0, mod_, []) {
    Some(evidence) => evidence
    None => fail("expected reusable callsite value evidence")
  }
  match dae_callsite_single_instruction_actual(evidence, 0, body) {
    Some(actual) => {
      assert_eq(actual.param_idx, 0)
      assert_eq(actual.actual_idx, 0)
      assert_eq(actual.instr, body[0])
      assert_true(
        dae_callsite_single_instruction_actual_is_consistent(actual, 0, body),
      )
    }
    None => fail("expected first single-instruction actual evidence")
  }
  match dae_callsite_single_instruction_actual(evidence, 1, body) {
    Some(actual) => {
      assert_eq(actual.param_idx, 1)
      assert_eq(actual.actual_idx, 1)
      assert_eq(actual.instr, body[1])
    }
    None => fail("expected second single-instruction actual evidence")
  }
  match dae_callsite_single_instruction_actual(evidence, 2, body) {
    Some(_) => fail("expected out-of-range actual lookup to reject")
    None => ()
  }
}

///|
test "dae value slices carry reusable operand disposition" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ]
  let disposition = match dae_operand_disposition_from_range(body, 0, 2) {
    Some(disposition) => disposition
    None => fail("expected value-slice operand disposition")
  }
  let slice = dae_value_slice_from_operand_disposition(disposition)
  assert_eq(slice.start, 0)
  assert_eq(slice.end, 2)
  assert_false(slice.pure)
  assert_true(slice.has_effect_or_branch)
  assert_eq(slice.disposition.start, disposition.start)
  assert_eq(slice.disposition.end, disposition.end)
  assert_eq(
    slice.disposition.preserve_effects_on_removal,
    disposition.preserve_effects_on_removal,
  )
  let computed_body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
  ]
  let computed_slice = dae_value_slice_from_range(computed_body, 0, 3)
  assert_true(computed_slice.pure)
  assert_false(computed_slice.disposition.droppable_without_repair)
  assert_true(computed_slice.disposition.preserve_effects_on_removal)
}

///|
test "dae callsite value slice exposes reusable single-instruction evidence" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ]
  let computed = dae_value_slice_from_range(body, 0, 3)
  let single = dae_value_slice_from_range(body, 3, 4)
  match dae_value_slice_single_instruction_index(computed) {
    Some(_) => fail("computed range is not a single actual instruction")
    None => ()
  }
  match dae_value_slice_single_instruction_index(single) {
    Some(idx) => assert_eq(idx, 3)
    None => fail("expected single-instruction actual evidence")
  }
}

///|
test "dae control entry stack evidence centralizes nested block inputs" {
  let typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i64()], [
        @lib.ValType::f32(),
      ]),
    ),
  )
  let single_result_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i64()])),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([typeidx_block_type, single_result_type]),
  )
  let typeidx_signature = match
    dae_control_block_type_signature_evidence(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      mod_,
    ) {
    Some(evidence) => evidence
    None => fail("expected typeidx block signature evidence")
  }
  assert_eq(typeidx_signature.input_count, 2)
  assert_eq(typeidx_signature.output_count, 1)
  assert_eq(typeidx_signature.params.length(), 2)
  assert_eq(typeidx_signature.results.length(), 1)
  match
    dae_control_block_type_stack_shape_evidence(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      mod_.type_sec,
      2,
      1,
    ) {
    Some(shape) => {
      assert_eq(shape.input_count, 2)
      assert_eq(shape.output_count, 1)
    }
    None => fail("expected shared typeidx stack-shape evidence")
  }
  assert_true(
    dae_control_block_type_exact_signature_accepts(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      mod_.type_sec,
      [@lib.ValType::i32(), @lib.ValType::i64()],
      [@lib.ValType::f32()],
    ),
  )
  assert_false(
    dae_control_block_type_exact_signature_accepts(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      mod_.type_sec,
      [@lib.ValType::i64(), @lib.ValType::i32()],
      [@lib.ValType::f32()],
    ),
  )
  match typeidx_signature.type_idx {
    Some(type_idx) => assert_eq(type_idx, @lib.TypeIdx::new(0U))
    None => fail("expected typeidx signature to retain control typeidx")
  }
  match
    dae_control_single_result_block_type_evidence(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      mod_,
    ) {
    Some(_) =>
      fail("typeidx block with params is not a stack single-result producer")
    None => ()
  }
  let typeidx_single_result = match
    dae_control_single_result_block_type_evidence(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      mod_,
    ) {
    Some(evidence) => evidence
    None => fail("expected zero-param typeidx single-result evidence")
  }
  assert_eq(typeidx_single_result.input_count, 0)
  assert_eq(typeidx_single_result.output_count, 1)
  match typeidx_single_result.type_idx {
    Some(type_idx) => assert_eq(type_idx, @lib.TypeIdx::new(1U))
    None => fail("expected typeidx single-result evidence to retain typeidx")
  }

  let typeidx_evidence = match
    dae_control_entry_stack_evidence(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      mod_,
    ) {
    Some(evidence) => evidence
    None => fail("expected typeidx block stack evidence")
  }
  assert_eq(typeidx_evidence.entry_stack_values, 2)
  assert_eq(typeidx_evidence.result_stack_values, 1)

  let valtype_single_result = match
    dae_control_single_result_block_type_evidence(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      mod_,
    ) {
    Some(evidence) => evidence
    None => fail("expected valtype single-result block evidence")
  }
  assert_eq(valtype_single_result.input_count, 0)
  assert_eq(valtype_single_result.output_count, 1)

  let valtype_evidence = match
    dae_control_entry_stack_evidence(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      mod_,
    ) {
    Some(evidence) => evidence
    None => fail("expected valtype block stack evidence")
  }
  assert_eq(valtype_evidence.entry_stack_values, 0)
  assert_eq(valtype_evidence.result_stack_values, 1)

  match
    dae_control_single_result_block_type_evidence(@lib.BlockType::void_(), mod_) {
    Some(_) => fail("void block type is not a stack single-result producer")
    None => ()
  }

  match
    dae_control_entry_stack_evidence(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(9U)),
      mod_,
    ) {
    Some(_) => fail("out-of-range typeidx should not produce stack evidence")
    None => ()
  }

  match
    dae_control_entry_stack_values(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      mod_,
    ) {
    Some(entry_stack_values) => assert_eq(entry_stack_values, 2)
    None => fail("expected shared control entry stack value")
  }
  match
    dae_control_entry_stack_values(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(9U)),
      mod_,
    ) {
    Some(_) => fail("out-of-range helper lookup should reject")
    None => ()
  }

  let block_instr = @lib.Instruction::block(
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    @lib.Expr::new([]),
  )
  match dae_nested_control_entry_evidence(block_instr, mod_) {
    Some(evidence) => {
      assert_eq(evidence.entry_stack_values, 2)
      assert_eq(evidence.result_stack_values, 1)
      assert_eq(evidence.control_kind, 0)
      assert_false(evidence.has_else_arm)
    }
    None => fail("expected reusable nested block entry evidence")
  }

  let if_instr = @lib.Instruction::if_(
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
    Some([]),
  )
  match dae_nested_control_entry_evidence(if_instr, mod_) {
    Some(evidence) => {
      assert_eq(evidence.entry_stack_values, 0)
      assert_eq(evidence.result_stack_values, 1)
      assert_eq(evidence.control_kind, 3)
      assert_true(evidence.has_else_arm)
    }
    None => fail("expected reusable nested if entry evidence")
  }
  match dae_nested_control_children_evidence(if_instr, mod_) {
    Some(evidence) => {
      assert_eq(evidence.entry_stack_values, 0)
      assert_eq(evidence.result_stack_values, 1)
      assert_eq(evidence.control_kind, 3)
      assert_true(evidence.has_else_arm)
      assert_eq(evidence.primary_body.length(), 0)
      match evidence.secondary_body {
        Some(body) => assert_eq(body.length(), 0)
        None => fail("expected else body in nested-control child evidence")
      }
    }
    None => fail("expected reusable nested if child evidence")
  }
  match dae_nested_control_children_evidence(block_instr, mod_) {
    Some(evidence) => {
      assert_eq(evidence.entry_stack_values, 2)
      assert_eq(evidence.result_stack_values, 1)
      assert_eq(evidence.control_kind, 0)
      assert_false(evidence.has_else_arm)
      assert_eq(evidence.primary_body.length(), 0)
      match evidence.secondary_body {
        Some(_) => fail("plain block should not expose secondary body")
        None => ()
      }
    }
    None => fail("expected reusable nested block child evidence")
  }

  let try_instr = @lib.Instruction::try_table(
    @lib.BlockType::void_(),
    [@lib.Catch::all(@lib.LabelIdx::new(0U))],
    @lib.Expr::new([@lib.Instruction::nop()]),
  )
  match dae_nested_control_children_evidence(try_instr, mod_) {
    Some(evidence) => {
      match
        dae_rebuild_nested_control_children(
          try_instr,
          evidence,
          [@lib.Instruction::i32_const(@lib.I32(3))],
          None,
        ) {
        Some(rebuilt) =>
          assert_eq(
            rebuilt,
            @lib.Instruction::try_table(
              @lib.BlockType::void_(),
              [@lib.Catch::all(@lib.LabelIdx::new(0U))],
              @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(3))]),
            ),
          )
        None => fail("expected reusable nested try_table rebuild evidence")
      }
      match
        dae_rebuild_nested_control_children(
          try_instr,
          evidence,
          [@lib.Instruction::nop()],
          Some([]),
        ) {
        Some(_) => fail("non-if nested rebuild should reject secondary body")
        None => ()
      }
    }
    None => fail("expected reusable nested try_table child evidence")
  }
  match dae_nested_control_children_evidence(if_instr, mod_) {
    Some(evidence) =>
      match
        dae_rebuild_nested_control_children(
          if_instr,
          evidence,
          [@lib.Instruction::nop()],
          None,
        ) {
        Some(_) => fail("if-with-else rebuild should preserve secondary body")
        None => ()
      }
    None => fail("expected reusable nested if child evidence")
  }

  match dae_nested_control_entry_evidence(@lib.Instruction::nop(), mod_) {
    Some(_) => fail("non-control instructions must not expose entry evidence")
    None => ()
  }
}

///|
test "dae callsite value slices expose reusable repair disposition" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ]
  let (slices, cursor) = match
    dae_collect_callsite_value_slices(body, 3, 2, 0, @lib.Module::new(), []) {
    Some(result) => result
    None => fail("expected callsite value slices")
  }
  assert_eq(cursor, 0)
  assert_eq(slices[0].start, 0)
  assert_eq(slices[0].end, 2)
  assert_false(slices[0].pure)
  assert_true(slices[0].disposition.preserve_effects_on_removal)
  assert_false(slices[0].has_effect_or_branch)
  assert_eq(slices[1].start, 2)
  assert_eq(slices[1].end, 3)
  assert_true(slices[1].pure)
  assert_false(slices[1].disposition.preserve_effects_on_removal)
  let repaired : Array[@lib.Instruction] = []
  dae_append_operand_with_removal_plan(
    repaired,
    body,
    dae_operand_removal_plan(
      dae_operand_rewrite_disposition(
        slices[0].disposition,
        localization_available=false,
        has_escaping_branch=false,
      ),
      false,
    ),
  )
  assert_eq(repaired, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::drop(),
  ])
}

///|
test "dae callsite localization application replaces hard removed operands with typed scratch writes" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ]
  match
    dae_rewrite_callsite_with_localization_at(
      body,
      3,
      [true, false],
      [@lib.ValType::i32(), @lib.ValType::i32()],
      0,
      3,
      @lib.Module::new(),
      [],
    ) {
    Some(evidence) => {
      assert_eq(evidence.new_call_idx, 4)
      assert_eq(evidence.localization_count, 1)
      assert_eq(evidence.localized_params, [true, false])
      assert_eq(evidence.scratch_local_types, [@lib.ValType::i32()])
      assert_eq(evidence.instrs, [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      ])
    }
    None => fail("expected effectful removed operand localization")
  }
  let scratch_heap_type = @lib.HeapType::new(@lib.TypeIdx::new(0U))
  let non_null_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, scratch_heap_type),
  )
  let nullable_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, scratch_heap_type),
  )
  assert_eq(dae_localization_scratch_type(non_null_ref), Some(nullable_ref))
  match
    dae_rewrite_callsite_with_localization_at(
      [
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      ],
      2,
      [true, false],
      [@lib.ValType::i32(), @lib.ValType::i32()],
      0,
      3,
      @lib.Module::new(),
      [],
    ) {
    Some(_) =>
      fail("escaping removed operands must reject scratch localization")
    None => ()
  }
}

///|
test "dae callsite rewrite application centralizes replay and localization" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ]
  let evidence = match
    dae_callsite_value_slice_evidence(body, 3, 2, 0, @lib.Module::new(), []) {
    Some(evidence) => evidence
    None => fail("expected callsite value-slice evidence")
  }
  let replay_plan = match
    dae_callsite_rewrite_plan(evidence, [true, false], None) {
    Some(plan) => plan
    None => fail("expected effect-preserving replay plan")
  }
  let replay = match dae_apply_callsite_rewrite_plan(body, replay_plan, 0) {
    Some(application) => application
    None => fail("expected shared replay application")
  }
  assert_eq(replay.localization_count, 0)
  assert_eq(replay.scratch_local_types, [])
  assert_eq(replay.localized_params, [false, false])
  assert_eq(replay.new_call_idx, 4)
  assert_eq(replay.instrs, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
  let localized_plan = match
    dae_callsite_rewrite_plan(
      evidence,
      [true, false],
      Some([@lib.ValType::i32(), @lib.ValType::i32()]),
    ) {
    Some(plan) => plan
    None => fail("expected typed localization plan")
  }
  let localized = match
    dae_apply_callsite_rewrite_plan(body, localized_plan, 3) {
    Some(application) => application
    None => fail("expected shared localization application")
  }
  assert_eq(localized.localization_count, 1)
  assert_eq(localized.scratch_local_types, [@lib.ValType::i32()])
  assert_eq(localized.localized_params, [true, false])
  assert_eq(localized.new_call_idx, 4)
  assert_eq(localized.instrs, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
}

///|
test "dae localization scratch pool reuses exact defaultable types" {
  let scratch_heap_type = @lib.HeapType::new(@lib.TypeIdx::new(0U))
  let nullable_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, scratch_heap_type),
  )
  let scratch_local_types = [@lib.ValType::i32(), @lib.ValType::f64()]
  assert_eq(
    dae_localization_scratch_slot(5, scratch_local_types, @lib.ValType::i32()),
    5,
  )
  assert_eq(scratch_local_types.length(), 2)
  assert_eq(
    dae_localization_scratch_slot(5, scratch_local_types, nullable_ref),
    7,
  )
  assert_eq(scratch_local_types, [
    @lib.ValType::i32(),
    @lib.ValType::f64(),
    nullable_ref,
  ])
  assert_eq(
    dae_localization_scratch_slot(5, scratch_local_types, nullable_ref),
    7,
  )
  assert_eq(scratch_local_types.length(), 3)
}

///|
test "dae removed-param local projection distinguishes elided written and localized slots" {
  let dead = dae_removed_param_local_projection_evidence(
    @lib.ValType::i32(),
    written=false,
    localized=false,
  )
  assert_true(dead.valid)
  assert_false(dead.preserve_as_body_local)
  assert_eq(dead.body_local_type, None)
  let written = dae_removed_param_local_projection_evidence(
    @lib.ValType::i32(),
    written=true,
    localized=false,
  )
  assert_true(written.valid)
  assert_true(written.preserve_as_body_local)
  assert_eq(written.body_local_type, Some(@lib.ValType::i32()))
  let scratch_heap_type = @lib.HeapType::new(@lib.TypeIdx::new(0U))
  let non_null_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, scratch_heap_type),
  )
  let nullable_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, scratch_heap_type),
  )
  let localized = dae_removed_param_local_projection_evidence(
    non_null_ref,
    written=false,
    localized=true,
  )
  assert_true(localized.valid)
  assert_true(localized.preserve_as_body_local)
  assert_eq(localized.body_local_type, Some(nullable_ref))
}

///|
test "dae removed-param callee rewrite preserves mapped locals and constants" {
  let func = @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::f32()]),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    ]),
  )
  let evidence = match
    dae_removed_param_callee_rewrite_evidence(
      func,
      [@lib.ValType::i32(), @lib.ValType::i64(), @lib.ValType::i32()],
      [false, true, true],
      [
        None,
        Some(@lib.Instruction::i64_const(@lib.I64(9L))),
        Some(@lib.Instruction::i32_const(@lib.I32(7))),
      ],
      { gets: [true, true, true, true], writes: [false, true, false, false] },
      [false, false, false],
    ) {
    Some(evidence) => evidence
    None => fail("expected removed-param callee rewrite evidence")
  }
  assert_eq(evidence.kept_params, [@lib.ValType::i32()])
  assert_eq(
    evidence.locals,
    @lib.Locals::from_types([@lib.ValType::i64(), @lib.ValType::f32()]),
  )
  assert_eq(evidence.body, [
    @lib.Instruction::i64_const(@lib.I64(9L)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ])
}

///|
test "dae removed-param callee rewrite rejects stale read evidence without replacement" {
  let func = @lib.Func::new(
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::drop(),
    ]),
  )
  let evidence = dae_removed_param_callee_rewrite_evidence(
    func,
    [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i64()],
    [true, true, true],
    [None, None, None],
    { gets: [false, false, false], writes: [false, false, false] },
    [false, false, false],
  )
  match evidence {
    None => ()
    Some(_) => fail("expected stale removed-slot read evidence to reject")
  }
}

///|
test "dae removed-param callee rewrite rejects invalid out-of-range local input" {
  let invalid = @lib.Func::new(
    @lib.Locals::new([]),
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let evidence = dae_removed_param_callee_rewrite_evidence(
    invalid,
    [@lib.ValType::i32(), @lib.ValType::i32()],
    [false, true],
    [None, Some(@lib.Instruction::i32_const(@lib.I32(7)))],
    { gets: [false, false], writes: [false, false] },
    [false, false],
  )
  match evidence {
    None => ()
    Some(_) => fail("expected invalid out-of-range local rewrite rejection")
  }
}

///|
test "dae localization scratch floor stays above transient body local indexes" {
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::drop(),
      ]),
    ),
  ]
  assert_eq(dae_next_free_local_idx(body, 2), 4)
  assert_eq(dae_next_free_local_idx(body, 6), 6)
}

///|
test "dae callsite removal plan centralizes keep replay and drop repair" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ]
  let evidence = match
    dae_callsite_value_slice_evidence(body, 3, 2, 0, @lib.Module::new(), []) {
    Some(evidence) => evidence
    None => fail("expected callsite value-slice evidence")
  }
  let effectful_removed = match
    dae_callsite_operand_removal_plan(evidence, 0, true) {
    Some(plan) => plan
    None => fail("expected effectful removed-operand repair plan")
  }
  assert_false(effectful_removed.keep_operand)
  assert_true(effectful_removed.replay_operand)
  assert_true(effectful_removed.append_drop)
  assert_false(effectful_removed.rejects_direct_removal)
  let kept = match dae_callsite_operand_removal_plan(evidence, 1, false) {
    Some(plan) => plan
    None => fail("expected kept-operand plan")
  }
  assert_true(kept.keep_operand)
  assert_true(kept.replay_operand)
  assert_false(kept.append_drop)
  let pure_removed = match
    dae_callsite_operand_removal_plan(evidence, 1, true) {
    Some(plan) => plan
    None => fail("expected pure removed-operand plan")
  }
  assert_false(pure_removed.keep_operand)
  assert_false(pure_removed.replay_operand)
  assert_false(pure_removed.append_drop)
  match dae_callsite_operand_removal_plan(evidence, 2, true) {
    Some(_) => fail("out-of-range param should not produce a repair plan")
    None => ()
  }
}

///|
test "dae control block input evidence centralizes zero-input control checks" {
  let ref_type = @lib.TypeIdx::new(0U)
  let zero_multi_type = @lib.TypeIdx::new(1U)
  let param_type = @lib.TypeIdx::new(2U)
  let concrete_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(ref_type), exact=true),
  )
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::new(false, [], @lib.CompType::struct_([]))),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([], [@lib.ValType::i32(), concrete_ref]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32()], [concrete_ref]),
      ),
    ),
  ])
  match
    dae_control_block_type_zero_input_evidence(
      @lib.BlockType::type_idx(zero_multi_type),
      Some(type_sec),
    ) {
    Some(evidence) => {
      assert_eq(evidence.input_count, 0)
      assert_eq(evidence.output_count, 2)
      assert_eq(evidence.results[1], concrete_ref)
    }
    None => fail("expected zero-input typeidx control evidence")
  }
  match
    dae_control_block_type_zero_input_output_count_evidence(
      @lib.BlockType::type_idx(zero_multi_type),
      Some(type_sec),
      2,
    ) {
    Some(evidence) => {
      assert_eq(evidence.input_count, 0)
      assert_eq(evidence.output_count, 2)
      assert_eq(evidence.results[1], concrete_ref)
    }
    None => fail("expected zero-input/output-count typeidx evidence")
  }
  match
    dae_control_block_type_zero_input_evidence(
      @lib.BlockType::val_type(concrete_ref),
      Some(type_sec),
    ) {
    Some(evidence) => {
      assert_eq(evidence.input_count, 0)
      assert_eq(evidence.output_count, 1)
      assert_eq(evidence.results[0], concrete_ref)
    }
    None => fail("expected valtype zero-input control evidence")
  }
  match
    dae_control_block_type_zero_input_evidence(
      @lib.BlockType::type_idx(param_type),
      Some(type_sec),
    ) {
    Some(_) => fail("parametric typeidx control must not be zero-input")
    None => ()
  }
  match
    dae_control_block_type_zero_input_output_count_evidence(
      @lib.BlockType::type_idx(zero_multi_type),
      Some(type_sec),
      1,
    ) {
    Some(_) => fail("wrong output-count control must not produce evidence")
    None => ()
  }
  match
    dae_control_block_type_zero_input_evidence(
      @lib.BlockType::type_idx(zero_multi_type),
      None,
    ) {
    Some(_) =>
      fail("typeidx control without type section must not produce evidence")
    None => ()
  }
}

///|
test "dae control block GC result evidence centralizes single and trailing slots" {
  let ref_type = @lib.TypeIdx::new(0U)
  let pair_type = @lib.TypeIdx::new(1U)
  let nullable_type = @lib.TypeIdx::new(2U)
  let concrete_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(ref_type), exact=true),
  )
  let nullable_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(ref_type)),
  )
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::new(false, [], @lib.CompType::struct_([]))),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32()], [
          @lib.ValType::i64(),
          concrete_ref,
        ]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([], [nullable_ref])),
    ),
  ])
  match
    dae_control_block_type_non_null_concrete_gc_result_evidence(
      @lib.BlockType::type_idx(pair_type),
      Some(type_sec),
      1,
    ) {
    Some(evidence) => {
      assert_eq(evidence.result_index, 1)
      assert_eq(evidence.signature.input_count, 1)
      assert_eq(evidence.signature.output_count, 2)
      assert_eq(evidence.candidate, concrete_ref)
    }
    None => fail("expected trailing concrete GC result evidence")
  }
  match
    dae_control_block_type_non_null_concrete_gc_result_evidence(
      @lib.BlockType::type_idx(pair_type),
      Some(type_sec),
      0,
    ) {
    Some(_) => fail("non-GC leading result must not produce GC evidence")
    None => ()
  }
  match
    dae_control_block_type_non_null_concrete_gc_result_evidence(
      @lib.BlockType::type_idx(pair_type),
      Some(type_sec),
      2,
    ) {
    Some(_) => fail("out-of-range result slot must not produce evidence")
    None => ()
  }
  match
    dae_control_block_type_non_null_concrete_gc_result_slot_evidence(
      @lib.BlockType::val_type(concrete_ref),
      Some(type_sec),
      DaeSingleControlGcResultSlot,
    ) {
    Some(evidence) => {
      assert_eq(evidence.result_index, 0)
      assert_eq(evidence.signature.output_count, 1)
      assert_eq(evidence.candidate, concrete_ref)
    }
    None => fail("expected single-slot concrete GC result evidence")
  }
  match
    dae_control_block_type_single_non_null_concrete_gc_result_evidence(
      @lib.BlockType::val_type(concrete_ref),
      Some(type_sec),
    ) {
    Some(evidence) => {
      assert_eq(evidence.result_index, 0)
      assert_eq(evidence.signature.output_count, 1)
      assert_eq(evidence.candidate, concrete_ref)
    }
    None => fail("expected single valtype concrete GC result evidence")
  }
  match
    dae_control_block_type_single_non_null_concrete_gc_result_evidence(
      @lib.BlockType::type_idx(pair_type),
      Some(type_sec),
    ) {
    Some(_) => fail("multi-result typeidx is not single-result evidence")
    None => ()
  }
  match
    dae_control_block_type_non_null_concrete_gc_result_slot_evidence(
      @lib.BlockType::type_idx(pair_type),
      Some(type_sec),
      DaeLastControlGcResultSlot,
    ) {
    Some(evidence) => {
      assert_eq(evidence.result_index, 1)
      assert_eq(evidence.candidate, concrete_ref)
    }
    None => fail("expected trailing slot GC result evidence")
  }
  match
    dae_control_block_type_last_non_null_concrete_gc_result_evidence(
      @lib.BlockType::type_idx(pair_type),
      Some(type_sec),
    ) {
    Some(evidence) => {
      assert_eq(evidence.result_index, 1)
      assert_eq(evidence.candidate, concrete_ref)
    }
    None => fail("expected trailing GC result evidence")
  }
  match
    dae_control_block_type_last_non_null_concrete_gc_result_evidence(
      @lib.BlockType::type_idx(nullable_type),
      Some(type_sec),
    ) {
    Some(_) => fail("nullable GC result must not produce non-null evidence")
    None => ()
  }
}

///|
test "dae GC select value evidence computes reusable LUB and refined candidates" {
  let base_type = @lib.TypeIdx::new(0U)
  let mid_type = @lib.TypeIdx::new(1U)
  let leaf1_type = @lib.TypeIdx::new(2U)
  let leaf2_type = @lib.TypeIdx::new(3U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_mid_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(mid_type)),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [mid_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [mid_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let body = [
    @lib.Instruction::struct_new_default(leaf1_type),
    @lib.Instruction::struct_new_default(leaf2_type),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::select(types=Some([base_ref])),
  ]
  match
    dae_gc_select_value_slices_candidate_evidence(
      mod_,
      [],
      None,
      body,
      4,
      base_ref,
      require_refined=true,
    ) {
    Some(evidence) => {
      assert_eq(evidence.slices.left.start, 0)
      assert_eq(evidence.slices.right.start, 1)
      assert_eq(evidence.slices.condition.start, 2)
      assert_eq(evidence.slices.condition.end, 4)
      assert_eq(evidence.slices.condition.instr_count, 2)
      assert_true(evidence.slices.condition.stack_slice is Some(_))
      assert_eq(evidence.gc.candidate, expected_mid_ref)
      assert_eq(evidence.gc.refined_candidate, Some(expected_mid_ref))
      assert_eq(evidence.gc.left_rewrite, None)
      assert_eq(evidence.gc.right_rewrite, None)
    }
    None => fail("expected reusable GC select value-slices candidate evidence")
  }
}

///|
test "dae indirect GC result slice evidence centralizes call_ref and call_indirect operands" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let callee_type = @lib.TypeIdx::new(2U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type)),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([@lib.ValType::i32()], [expected_leaf_ref]),
        ),
      ),
    ]),
  )
  let call_ref_body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call_ref(callee_type),
  ]
  match
    dae_indirect_call_gc_result_slice_evidence(
      mod_,
      [],
      call_ref_body,
      0,
      1,
      1,
      callee_type,
      base_ref,
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, expected_leaf_ref)
      assert_eq(evidence.param_count, 1)
      assert_eq(evidence.stack_value_count, 1)
    }
    None => fail("expected reusable call_ref GC result evidence")
  }
  let call_indirect_body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::call_indirect(callee_type, @lib.TableIdx::new(0U)),
  ]
  match
    dae_indirect_call_gc_result_slice_evidence(
      mod_,
      [],
      call_indirect_body,
      0,
      1,
      2,
      callee_type,
      base_ref,
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, expected_leaf_ref)
      assert_eq(evidence.param_count, 1)
      assert_eq(evidence.stack_value_count, 2)
    }
    None => fail("expected reusable call_indirect GC result evidence")
  }
  let effectful_table_body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::call_indirect(callee_type, @lib.TableIdx::new(0U)),
  ]
  match
    dae_indirect_call_gc_result_slice_evidence(
      mod_,
      [],
      effectful_table_body,
      0,
      1,
      2,
      callee_type,
      base_ref,
    ) {
    Some(_) =>
      fail("expected effectful call_indirect table operand to be rejected")
    None => ()
  }
}

///|
test "dae GC result slot evidence centralizes candidate refinement and rewrite" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let block_instr = @lib.Instruction::block(
    @lib.BlockType::val_type(base_ref),
    @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
  )
  match
    dae_gc_result_slot_evidence(
      mod_,
      [],
      None,
      block_instr,
      base_ref,
      require_refined=true,
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, leaf_ref)
      assert_eq(evidence.refined_candidate, Some(leaf_ref))
      assert_eq(
        evidence.rewrite,
        Some(
          @lib.Instruction::block(
            @lib.BlockType::val_type(leaf_ref),
            @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
          ),
        ),
      )
    }
    None => fail("expected reusable GC result slot evidence")
  }
  match
    dae_gc_result_slot_evidence(
      mod_,
      [],
      None,
      @lib.Instruction::struct_new_default(leaf_type),
      leaf_ref,
      require_refined=true,
    ) {
    Some(_) => fail("expected unchanged slot evidence to be rejected")
    None => ()
  }
}

///|
test "dae direct call GC result evidence centralizes signature and refinement" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let callee_type = @lib.TypeIdx::new(2U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type)),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([@lib.ValType::i32()], [leaf_ref]),
        ),
      ),
    ]),
  )
  let func_type_indices = [callee_type]
  match
    dae_direct_call_gc_result_signature_evidence(
      mod_,
      func_type_indices,
      @lib.FuncIdx::new(0U),
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, leaf_ref)
      assert_eq(evidence.refined_candidate, None)
      assert_eq(evidence.param_count, 1)
    }
    None => fail("expected direct-call GC result signature evidence")
  }
  match
    dae_direct_call_gc_result_refinement_evidence(
      mod_,
      func_type_indices,
      @lib.FuncIdx::new(0U),
      base_ref,
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, leaf_ref)
      assert_eq(evidence.refined_candidate, Some(leaf_ref))
      assert_eq(evidence.param_count, 1)
    }
    None => fail("expected direct-call GC result refinement evidence")
  }
  let exact_old_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type)),
  )
  match
    dae_direct_call_gc_result_refinement_evidence(
      mod_,
      func_type_indices,
      @lib.FuncIdx::new(0U),
      exact_old_ref,
    ) {
    Some(_) =>
      fail("expected unchanged direct-call result evidence to be rejected")
    None => ()
  }
}

///|
test "dae GC select actual evidence centralizes nullable refinement and rewrites" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(leaf_type), exact=true),
  )
  let expected_leaf_rt = @lib.RefType::new(
    true,
    @lib.HeapType::new(leaf_type),
    exact=true,
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let body = [
    @lib.Instruction::ref_null(@lib.HeapType::new(base_type)),
    @lib.Instruction::struct_new_default(leaf_type),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::select(types=Some([base_ref])),
  ]
  let slices = match dae_find_select_value_slices(mod_, [], body, 5) {
    Some(slices) => slices
    None => fail("expected reusable select value slices")
  }
  match
    dae_gc_select_actual_value_slices_evidence(
      mod_,
      [],
      body,
      slices,
      base_ref,
      rewrite_type=Some(expected_leaf_ref),
    ) {
    Some(evidence) => {
      assert_eq(evidence.slices.condition.start, 2)
      assert_eq(evidence.slices.condition.end, 5)
      assert_eq(evidence.gc.candidate, expected_leaf_ref)
      assert_eq(evidence.gc.refined_candidate, Some(expected_leaf_ref))
      assert_eq(
        evidence.gc.left_rewrite,
        Some(@lib.Instruction::ref_null_type(expected_leaf_rt)),
      )
      assert_eq(evidence.gc.right_rewrite, None)
    }
    None => fail("expected reusable GC select actual slice evidence")
  }
}

///|
test "dae original call summary counts repeated undropped callees once per caller" {
  let mod_ = dae_wbtest_call_summary_fixture()
  let summary = dae_collect_original_boundary_snapshot(mod_).call_summary
  assert_eq(summary.call_counts, [0, 2, 2])
  assert_eq(summary.prior_call_counts, [0, 1, 2])
  assert_eq(summary.self_call_counts, [0, 1, 0])
  assert_eq(summary.nonself_undropped_call_counts, [0, 1, 1])
  assert_eq(summary.prior_undropped_call_counts, [0, 1, 1])
  assert_eq(summary.active_nonself_call_counts, [0, 1, 2])
}

///|
test "dae rewritten-control cleanup preserves Binaryen zero-tee shape" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  assert_eq(dae_simplify_rewritten_control_instrs(body, true), body)
}

///|
test "dae broad exact-literal seed recognizes pure single-parameter expressions" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func)
      #|  (func $pure (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $trapping (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.div_s))
      #|,
    ),
  )
  assert_true(
    dae_exact_literal_candidate_is_single_param_pure_expression(mod_, 1),
  )
  assert_false(
    dae_exact_literal_candidate_is_single_param_pure_expression(mod_, 2),
  )
}

///|
test "dae shifted forwarding wrapper order is derived without definition identities" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $wa (param i32 i32) local.get 1 call $ta)
      #|  (func)
      #|  (func $wb (param i32 i32) local.get 1 call $tb)
      #|  (func $wa2 (param i32 i32) local.get 1 call $ta)
      #|  (func $ta (param i32) local.get 0 drop)
      #|  (func $tb (param i32) local.get 0 drop))
      #|,
    ),
  )
  assert_eq(dae_collect_shifted_forward_wrapper_callee_order(mod_, 0, 4), [4, 5])
}

///|
test "dae raw cleanup preserves nops and strips selected dropped pure leaves after any DAE touch" {
  let v128_zero = @lib.Instruction::v128_const(
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  )
  let v128_ones = @lib.Instruction::v128_const(
    b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
    b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
  )
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let pure_typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let param_typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let pure_void_typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let param_void_typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let shuffle_low_lanes = @lib.Instruction::i8x16_shuffle(
    @lib.LaneIdx::new(b'\x00'),
    @lib.LaneIdx::new(b'\x01'),
    @lib.LaneIdx::new(b'\x02'),
    @lib.LaneIdx::new(b'\x03'),
    @lib.LaneIdx::new(b'\x04'),
    @lib.LaneIdx::new(b'\x05'),
    @lib.LaneIdx::new(b'\x06'),
    @lib.LaneIdx::new(b'\x07'),
    @lib.LaneIdx::new(b'\x08'),
    @lib.LaneIdx::new(b'\x09'),
    @lib.LaneIdx::new(b'\x0a'),
    @lib.LaneIdx::new(b'\x0b'),
    @lib.LaneIdx::new(b'\x0c'),
    @lib.LaneIdx::new(b'\x0d'),
    @lib.LaneIdx::new(b'\x0e'),
    @lib.LaneIdx::new(b'\x0f'),
  )
  let noisy_body = [
    @lib.Instruction::nop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::drop(),
    @lib.Instruction::i64_const(@lib.I64(9L)),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(1.5)),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(2.25)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i8x16_splat(),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(2.5)),
    @lib.Instruction::f64x2_splat(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32x4_extract_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f64x2_extract_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::i8x16_replace_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f64_const(@lib.F64(3.5)),
    @lib.Instruction::f64x2_replace_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i8x16_shl(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i32x4_shr_u(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i16x8_extend_low_i8x16s(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32x4_extadd_pairwise_i16x8u(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i8x16_narrow_i16x8s(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i16x8_narrow_i32x4u(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i16x8_extmul_low_i8x16s(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i32x4_extmul_high_i16x8u(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i64x2_extmul_low_i32x4u(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i32x4_dot_i16x8s(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f32x4_demote_f64x2_zero(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f64x2_promote_low_f32x4(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32x4_trunc_sat_f32x4s(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32x4_trunc_sat_f64x2u_zero(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f32x4_convert_i32x4u(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f64x2_convert_low_i32x4s(),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(11)),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(16.75)),
    @lib.Instruction::f64_sqrt(),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(1.5)),
    @lib.Instruction::i32_trunc_sat_f32s(),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(1.5)),
    @lib.Instruction::i32_trunc_f32s(),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(2.5)),
    @lib.Instruction::i32_trunc_f32s(),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(42.0)),
    @lib.Instruction::i64_trunc_sat_f64u(),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(9.25)),
    @lib.Instruction::f32_const(@lib.F32(2.5)),
    @lib.Instruction::f32_max(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(41)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_add(),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    ),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(12)),
        @lib.Instruction::i32_const(@lib.I32(30)),
        @lib.Instruction::i32_add(),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    ),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_mul(),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(71)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      @lib.Expr::new([
        @lib.Instruction::i64_const(@lib.I64(72L)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(100)),
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
      @lib.Expr::new([@lib.Instruction::drop()]),
    ),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(73)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      @lib.Expr::new([
        @lib.Instruction::i64_const(@lib.I64(74L)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(101)),
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
      @lib.Expr::new([@lib.Instruction::drop()]),
    ),
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::i32_const(@lib.I32(75)), @lib.Instruction::drop()],
      None,
    ),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::if_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      [@lib.Instruction::i64_const(@lib.I64(76L)), @lib.Instruction::drop()],
      Some([]),
    ),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::if_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      [],
      Some([@lib.Instruction::i32_const(@lib.I32(77)), @lib.Instruction::drop()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(102)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
      [@lib.Instruction::drop()],
      Some([@lib.Instruction::drop()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    @lib.Instruction::try_table(
      @lib.BlockType::void_(),
      [],
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(78)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::try_table(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      [],
      @lib.Expr::new([
        @lib.Instruction::i64_const(@lib.I64(79L)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(103)),
    @lib.Instruction::try_table(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
      [],
      @lib.Expr::new([@lib.Instruction::drop()]),
    ),
    @lib.Instruction::try_table(
      @lib.BlockType::void_(),
      [],
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::select(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::v128_not(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::v128_any_true(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i8x16_abs(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i8x16_bitmask(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f32x4_sqrt(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f64x2_nearest(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::v128_and(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i8x16_add(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i32x4_eq(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::f32x4_div(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    shuffle_low_lanes,
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i8x16_swizzle(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    v128_zero,
    @lib.Instruction::v128_bitselect(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_is_null(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_eq(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(123)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(321)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(654)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::ref_cast(
      false,
      @lib.HeapType::abs(@lib.AbsHeapType::i31()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(656)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::ref_cast(
      false,
      @lib.HeapType::abs(@lib.AbsHeapType::eq()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(657)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::ref_cast(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::any()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(655)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::ref_cast(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::i31()),
    ),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(456)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::i31_get_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::any_convert_extern(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_test(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::ref_test_desc(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::eq()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::extern_convert_any(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::ref_cast(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::ref_cast(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::ref_test(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::i31())),
    @lib.Instruction::i31_get_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::extern_convert_any(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::ref_test(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::ref_test_desc(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::eq()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_eq(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::i31())),
    @lib.Instruction::ref_cast(
      false,
      @lib.HeapType::abs(@lib.AbsHeapType::i31()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::ref_cast(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(84)),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_div_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(84)),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_div_s(),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::i64_const(@lib.I64(84L)),
    @lib.Instruction::i64_const(@lib.I64(3L)),
    @lib.Instruction::i64_div_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(84)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_div_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(99)),
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      @lib.Expr::new([]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::i64_const(@lib.I64(-9223372036854775808L)),
    @lib.Instruction::i64_const(@lib.I64(-1L)),
    @lib.Instruction::i64_div_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(4294967296.0)),
    @lib.Instruction::i32_trunc_f64u(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::i32_const(@lib.I32(84)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_div_s(),
    @lib.Instruction::select(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::i8x16_splat(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i8x16_abs(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i32x4_extract_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::i8x16_replace_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::i8x16_replace_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i8x16_shl(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::i8x16_shl(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i16x8_extend_low_i8x16s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i32x4_extadd_pairwise_i16x8u(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    @lib.Instruction::i8x16_narrow_i16x8s(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i16x8_extmul_low_i8x16s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    @lib.Instruction::i32x4_dot_i16x8s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::f32x4_demote_f64x2_zero(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i32x4_trunc_sat_f32x4s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::f64x2_convert_low_i32x4s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    @lib.Instruction::i8x16_add(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    shuffle_low_lanes,
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    @lib.Instruction::i8x16_swizzle(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    v128_ones,
    @lib.Instruction::v128_bitselect(),
    @lib.Instruction::drop(),
    @lib.Instruction::return_(),
  ]
  let table_type = @lib.TableType::new(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
    @lib.Limits::i32(1U, None),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        pure_typeidx_block_type, param_typeidx_block_type, pure_void_typeidx_block_type,
        param_void_typeidx_block_type,
      ]),
    )
    .with_table_sec(@lib.TableSec::new([@lib.Table::new(table_type, None)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(noisy_body)),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(noisy_body)),
      ]),
    )
  let no_touch_result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [
    false, false,
  ])
  assert_false(no_touch_result.changed)
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [
    true, false,
  ])
  assert_true(result.changed)
  assert_eq(result.primary_def, 0)
  assert_eq(result.touched, [true, false])
  let no_return_touched_result = dae_strip_module_nops_and_dropped_pure_leaf_once(
    mod_,
    [true, false],
    return_touched=false,
  )
  assert_true(no_return_touched_result.changed)
  assert_eq(no_return_touched_result.primary_def, 0)
  assert_eq(no_return_touched_result.touched, [])
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned0)) = funcs[0]
      let @lib.Func(_, @lib.Expr(cleaned1)) = funcs[1]
      let preserved_trapping = [
        @lib.Instruction::nop(),
        @lib.Instruction::i32_const(@lib.I32(100)),
        @lib.Instruction::block(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
          @lib.Expr::new([@lib.Instruction::drop()]),
        ),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        ),
        @lib.Instruction::i32_const(@lib.I32(101)),
        @lib.Instruction::loop_(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
          @lib.Expr::new([@lib.Instruction::drop()]),
        ),
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        ),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(102)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
          [@lib.Instruction::drop()],
          Some([@lib.Instruction::drop()]),
        ),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::unreachable_()],
          None,
        ),
        @lib.Instruction::i32_const(@lib.I32(103)),
        @lib.Instruction::try_table(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
          [],
          @lib.Expr::new([@lib.Instruction::drop()]),
        ),
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [],
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        ),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::i31())),
        @lib.Instruction::i31_get_s(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
        ),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::eq())),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
        ),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
        ),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::i31())),
        @lib.Instruction::ref_cast(
          false,
          @lib.HeapType::abs(@lib.AbsHeapType::i31()),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
        @lib.Instruction::ref_cast(
          true,
          @lib.HeapType::abs(@lib.AbsHeapType::eq()),
        ),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(84)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_div_s(),
        @lib.Instruction::drop(),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(99)),
        @lib.Instruction::block(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
          @lib.Expr::new([]),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::i64_const(@lib.I64(-9223372036854775808L)),
        @lib.Instruction::i64_const(@lib.I64(-1L)),
        @lib.Instruction::i64_div_s(),
        @lib.Instruction::drop(),
        @lib.Instruction::f64_const(@lib.F64(4294967296.0)),
        @lib.Instruction::i32_trunc_f64u(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::i32_const(@lib.I32(5)),
        @lib.Instruction::i32_const(@lib.I32(84)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_div_s(),
        @lib.Instruction::select(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        v128_zero,
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i8x16_replace_lane(@lib.LaneIdx::new(b'\x00')),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        v128_zero,
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i8x16_shl(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        v128_zero,
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::i16x8_extmul_low_i8x16s(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        v128_zero,
        v128_ones,
        @lib.Instruction::v128_bitselect(),
        @lib.Instruction::drop(),
        @lib.Instruction::return_(),
      ]
      assert_eq(cleaned0, preserved_trapping)
      assert_eq(cleaned1, preserved_trapping)
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae direct pass flattens no-normal result block before hard unreachable" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (result i32)
    #|     memory.size
    #|     (block (result i64)
    #|       f64.const 0
    #|       unreachable)
    #|     unreachable))
    #|
  let optimized = match
    pass_test_run_pipeline(input, ["dead-argument-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead-argument-elimination success, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(instrs)) = funcs[0]
      assert_eq(instrs, [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::f64_const(@lib.F64(0.0)),
        @lib.Instruction::unreachable_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips dropped unreachable debris before hard unreachable" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
          @lib.Instruction::drop(),
          @lib.Instruction::f64_const(@lib.F64(7.52804e-317)),
          @lib.Instruction::drop(),
          @lib.Instruction::unreachable_(),
          @lib.Instruction::drop(),
          @lib.Instruction::unreachable_(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [@lib.Instruction::unreachable_()])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup preserves dropped local get binary expressions" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::i32_const(@lib.I32(3)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::drop(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips local and global self assignments and tees" {
  let same_global_set = [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  ]
  let different_global_set = [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(1U)),
  ]
  let same_global_set_read_drop = [
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::drop(),
  ]
  let same_global_set_read_drop_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  ]
  let same_global_set_read_set = [
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  ]
  let same_global_set_read_set_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  ]
  let different_global_set_read = [
    @lib.Instruction::i32_const(@lib.I32(10)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
  ]
  let same_local_set = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  ]
  let same_local_tee_drop = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ]
  let same_local_tee_pure_use_drop = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
  ]
  let same_local_tee_set = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let same_local_tee_used = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let same_local_tee_used_cleaned = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let same_local_set_read = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
  ]
  let same_local_set_read_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
  ]
  let same_local_tee_set_from_const = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let same_local_tee_set_from_const_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let local_tee_drop_from_effect = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
  ]
  let local_tee_drop_from_effect_cleaned = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let same_local_set_read_drop = [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
  ]
  let same_local_set_read_drop_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let same_local_set_read_set = [
    @lib.Instruction::i32_const(@lib.I32(6)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let same_local_set_read_set_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(6)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let effect_local_set_read_drop = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
  ]
  let effect_local_set_read_drop_cleaned = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
  ]
  let different_local_set_read = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
  ]
  let different_local_set = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let different_local_tee_drop = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ]
  let different_local_tee_drop_cleaned = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let mod_ = @lib.Module::new()
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::i32(), true),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
        ),
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::i32(), true),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(2))]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new(
            [
              ..same_global_set,
              ..same_local_set,
              ..same_local_tee_drop,
              ..same_local_tee_pure_use_drop,
              ..same_local_tee_set,
              ..same_local_tee_used,
              ..same_local_set_read,
              ..same_local_tee_set_from_const,
              ..local_tee_drop_from_effect,
              ..same_local_set_read_drop,
              ..same_local_set_read_set,
              ..effect_local_set_read_drop,
              ..same_global_set_read_drop,
              ..same_global_set_read_set,
              ..different_global_set_read,
              ..different_local_set_read,
              ..different_global_set,
              ..different_local_set,
              ..different_local_tee_drop,
              @lib.Instruction::return_(),
            ],
          ),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(
        cleaned,
        [
          ..same_local_tee_used_cleaned,
          ..same_local_set_read_cleaned,
          ..same_local_tee_set_from_const_cleaned,
          ..local_tee_drop_from_effect_cleaned,
          ..same_local_set_read_drop_cleaned,
          ..same_local_set_read_set_cleaned,
          ..effect_local_set_read_drop_cleaned,
          ..same_global_set_read_drop_cleaned,
          ..same_global_set_read_set_cleaned,
          ..different_global_set_read,
          ..different_local_set_read,
          ..different_global_set,
          ..different_local_set,
          ..different_local_tee_drop_cleaned,
          @lib.Instruction::return_(),
        ],
      )
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips live integer constant identities" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let mod_ = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_or(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_xor(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_shl(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_shr_s(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_shr_u(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_rotl(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_rotr(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_mul(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::i32_and(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::i64_add(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::i64_sub(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::i64_shr_u(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(1L)),
            @lib.Instruction::i64_mul(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(-1L)),
            @lib.Instruction::i64_and(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_load(memarg),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_load(memarg),
            @lib.Instruction::i32_add(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_mul(),
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_and(),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_xor(),
            @lib.Instruction::i64_const(@lib.I64(1L)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_mul(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_shl(),
            @lib.Instruction::return_(),
          ]),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i32_add(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_sub(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_shl(),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup canonicalizes live integer zero comparisons" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let mod_ = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_ne(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::i64_eq(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::i64_ne(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_ne(),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_eq(),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_ne(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_load(memarg),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::return_(),
          ]),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i64_const(@lib.I64(0L)),
        @lib.Instruction::i64_eq(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i64_eqz(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i64_const(@lib.I64(0L)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i64_eq(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i64_eqz(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips double eqz from live if conditions" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let then_body = [@lib.Instruction::unreachable_()]
  let mod_ = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::if_(@lib.BlockType::void_(), then_body, None),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_load(memarg),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::if_(@lib.BlockType::void_(), then_body, None),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::return_(),
          ]),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_ne(),
        @lib.Instruction::if_(@lib.BlockType::void_(), then_body, None),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_ne(),
        @lib.Instruction::if_(@lib.BlockType::void_(), then_body, None),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup canonicalizes live integer and ref self comparisons" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_eq(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_ne(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_le_s(),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::i64_gt_u(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::ref_eq(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_eq(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::f32_eq(),
          @lib.Instruction::return_(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::f32_eq(),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup folds live integer self binary operations" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_and(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_or(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_xor(),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::i64_sub(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_xor(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::f32_sub(),
          @lib.Instruction::return_(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i64_const(@lib.I64(0L)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_xor(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::f32_sub(),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae droppable pure control value evidence centralizes control cleanup proof" {
  let result_block = @lib.BlockType::val_type(@lib.ValType::i32())
  let value_body = [@lib.Instruction::i32_const(@lib.I32(7))]
  match
    dae_droppable_pure_control_value_evidence(
      @lib.Instruction::block(result_block, @lib.Expr::new(value_body)),
      None,
    ) {
    Some(evidence) => {
      assert_true(
        dae_droppable_pure_control_value_evidence_is_consistent(evidence),
      )
      assert_eq(evidence.input_count, 0)
      assert_eq(evidence.output_count, 1)
      assert_eq(evidence.condition_arity, 0)
      assert_eq(evidence.body_count, 1)
      assert_eq(evidence.primary_body_length, 1)
      assert_eq(evidence.secondary_body_length, 0)
      assert_eq(evidence.catch_count, 0)
    }
    None => fail("expected pure block value evidence")
  }
  match
    dae_droppable_pure_control_value_evidence(
      @lib.Instruction::if_(
        result_block,
        value_body,
        Some([@lib.Instruction::i32_const(@lib.I32(8))]),
      ),
      None,
    ) {
    Some(evidence) => {
      assert_eq(evidence.condition_arity, 1)
      assert_eq(evidence.body_count, 2)
      assert_eq(evidence.primary_body_length, 1)
      assert_eq(evidence.secondary_body_length, 1)
      assert_true(
        dae_instr_droppable_pure_if_value(
          @lib.Instruction::if_(
            result_block,
            value_body,
            Some([@lib.Instruction::i32_const(@lib.I32(8))]),
          ),
          None,
        ),
      )
    }
    None => fail("expected pure if value evidence")
  }
  match
    dae_droppable_pure_control_value_evidence(
      @lib.Instruction::try_table(result_block, [], @lib.Expr::new(value_body)),
      None,
    ) {
    Some(evidence) => {
      assert_eq(evidence.condition_arity, 0)
      assert_eq(evidence.catch_count, 0)
    }
    None => fail("expected catch-free pure try_table value evidence")
  }
  match
    dae_droppable_pure_control_value_evidence(
      @lib.Instruction::if_(
        result_block,
        value_body,
        Some([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
      ),
      None,
    ) {
    Some(_) => fail("effectful if arm must not produce pure value evidence")
    None => ()
  }
  match
    dae_droppable_pure_control_value_evidence(
      @lib.Instruction::if_(
        result_block,
        value_body,
        Some([@lib.Instruction::i32_const(@lib.I32(8))]),
      ),
      None,
    ) {
    Some(evidence) => assert_eq(evidence.condition_arity, 1)
    None => fail("expected pure if evidence for condition-arity check")
  }
}

///|
test "dae redundant access cleanup evidence centralizes adjacent pair rewrites" {
  let slot = @lib.LocalIdx::new(1U)
  let other = @lib.LocalIdx::new(2U)
  match
    dae_redundant_access_cleanup_evidence(
      @lib.Instruction::local_get(slot),
      @lib.Instruction::local_set(slot),
    ) {
    Some(evidence) => {
      assert_eq(evidence.cleanup_kind, 0)
      assert_true(evidence.pop_previous)
      assert_true(evidence.skip_current)
      assert_eq(evidence.replacement, [])
      assert_true(dae_redundant_access_cleanup_evidence_is_consistent(evidence))
    }
    None => fail("expected local.get/local.set cleanup evidence")
  }
  match
    dae_redundant_access_cleanup_evidence(
      @lib.Instruction::local_get(slot),
      @lib.Instruction::local_tee(slot),
    ) {
    Some(evidence) => {
      assert_eq(evidence.cleanup_kind, 1)
      assert_false(evidence.pop_previous)
      assert_true(evidence.skip_current)
      assert_eq(evidence.replacement, [])
    }
    None => fail("expected local.get/local.tee cleanup evidence")
  }
  match
    dae_redundant_access_cleanup_evidence(
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    ) {
    Some(evidence) => {
      assert_eq(evidence.cleanup_kind, 2)
      assert_true(evidence.pop_previous)
      assert_eq(evidence.replacement, [])
    }
    None => fail("expected global.get/global.set cleanup evidence")
  }
  match
    dae_redundant_access_cleanup_evidence(
      @lib.Instruction::local_tee(slot),
      @lib.Instruction::local_set(slot),
    ) {
    Some(evidence) => {
      assert_eq(evidence.cleanup_kind, 3)
      assert_true(evidence.pop_previous)
      assert_eq(evidence.replacement, [@lib.Instruction::local_set(slot)])
    }
    None => fail("expected local.tee/local.set cleanup evidence")
  }
  match
    dae_redundant_access_cleanup_evidence(
      @lib.Instruction::local_get(slot),
      @lib.Instruction::local_set(other),
    ) {
    Some(_) => fail("different locals must not produce cleanup evidence")
    None => ()
  }
}

///|
test "dae dropped local tee suffix cleanup evidence centralizes pure suffix rewrites" {
  let slot = @lib.LocalIdx::new(1U)
  let direct_drop = [
    @lib.Instruction::local_tee(slot),
    @lib.Instruction::drop(),
  ]
  match dae_dropped_local_tee_suffix_cleanup_evidence(direct_drop, 0) {
    Some(evidence) => {
      assert_eq(evidence.cleanup_kind, 0)
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 2)
      assert_eq(evidence.next_idx, 2)
      assert_eq(evidence.replacement, [@lib.Instruction::local_set(slot)])
      assert_true(
        dae_dropped_local_tee_suffix_cleanup_evidence_is_consistent(evidence),
      )
    }
    None => fail("expected direct local.tee/drop cleanup evidence")
  }
  let unary_drop = [
    @lib.Instruction::local_tee(slot),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
  ]
  match dae_dropped_local_tee_suffix_cleanup_evidence(unary_drop, 0) {
    Some(evidence) => {
      assert_eq(evidence.cleanup_kind, 1)
      assert_eq(evidence.next_idx, 3)
      assert_eq(evidence.replacement, [@lib.Instruction::local_set(slot)])
    }
    None => fail("expected unary local.tee suffix cleanup evidence")
  }
  let binary_drop = [
    @lib.Instruction::local_tee(slot),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::drop(),
  ]
  match dae_dropped_local_tee_suffix_cleanup_evidence(binary_drop, 0) {
    Some(evidence) => {
      assert_eq(evidence.cleanup_kind, 2)
      assert_eq(evidence.end, 4)
    }
    None => fail("expected binary local.tee suffix cleanup evidence")
  }
  let double_binary_drop = [
    @lib.Instruction::local_tee(slot),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_mul(),
    @lib.Instruction::drop(),
  ]
  match dae_dropped_local_tee_suffix_cleanup_evidence(double_binary_drop, 0) {
    Some(evidence) => {
      assert_eq(evidence.cleanup_kind, 3)
      assert_eq(evidence.next_idx, 6)
    }
    None => fail("expected double-binary local.tee suffix cleanup evidence")
  }
  let trapping_drop = [
    @lib.Instruction::local_tee(slot),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_div_s(),
    @lib.Instruction::drop(),
  ]
  match dae_dropped_local_tee_suffix_cleanup_evidence(trapping_drop, 0) {
    Some(_) =>
      fail("trapping suffix must not produce local.tee cleanup evidence")
    None => ()
  }
}

///|
test "dae local-get range evidence centralizes cleanup local proof" {
  let tmp = @lib.LocalIdx::new(1U)
  let singleton_local = [@lib.Instruction::local_get(tmp)]
  match dae_local_get_range_evidence(singleton_local, 0) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 1)
      assert_true(evidence.has_local_get)
      assert_false(evidence.local_free)
      assert_true(evidence.singleton)
      assert_true(evidence.range_allows_cleanup)
      assert_true(dae_local_get_range_evidence_is_consistent(evidence))
    }
    None => fail("expected singleton local-get range evidence")
  }
  let local_suffix = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_get(tmp),
  ]
  match dae_local_get_range_evidence(local_suffix, 0) {
    Some(evidence) => {
      assert_false(evidence.singleton)
      assert_true(evidence.has_local_get)
      assert_false(evidence.local_free)
      assert_false(evidence.range_allows_cleanup)
      assert_true(dae_local_get_range_evidence_is_consistent(evidence))
    }
    None => fail("expected local suffix evidence")
  }
  let local_free_suffix = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
  ]
  match dae_local_get_range_evidence(local_free_suffix, 0) {
    Some(evidence) => {
      assert_false(evidence.has_local_get)
      assert_true(evidence.local_free)
      assert_true(evidence.range_allows_cleanup)
    }
    None => fail("expected local-free suffix evidence")
  }
  match dae_local_get_range_evidence(local_suffix, -1) {
    Some(_) => fail("negative start must not produce range evidence")
    None => ()
  }
}

///|
test "dae droppable pure stack evidence centralizes local-free cleanup proof" {
  let pure_stack = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
  ]
  let pure_evidence = match
    dae_droppable_pure_stack_evidence(pure_stack, None) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 3)
      assert_false(evidence.has_local_get)
      assert_true(evidence.local_free)
      assert_true(evidence.local_range.local_free)
      assert_true(evidence.local_range.range_allows_cleanup)
      assert_true(
        dae_droppable_pure_stack_evidence_allows_live_local_copy_cleanup(
          Some(evidence),
        ),
      )
      evidence
    }
    None => fail("expected trailing pure stack evidence")
  }
  let local_stack = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
  ]
  let local_evidence = match
    dae_droppable_pure_stack_evidence(local_stack, None) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 3)
      assert_true(evidence.has_local_get)
      assert_false(evidence.local_free)
      assert_false(evidence.local_range.local_free)
      assert_false(evidence.local_range.range_allows_cleanup)
      assert_false(
        dae_droppable_pure_stack_evidence_allows_live_local_copy_cleanup(
          Some(evidence),
        ),
      )
      evidence
    }
    None => fail("expected local-carried pure stack evidence")
  }
  assert_false(
    dae_droppable_pure_stack_evidence_allows_live_local_copy_cleanup(None),
  )
  let first = @lib.LocalIdx::new(1U)
  let second = @lib.LocalIdx::new(2U)
  let third = @lib.LocalIdx::new(3U)
  let triple_copy = [
    @lib.Instruction::local_set(first),
    @lib.Instruction::local_get(first),
    @lib.Instruction::local_set(second),
    @lib.Instruction::local_get(second),
    @lib.Instruction::local_set(third),
  ]
  match
    dae_live_local_copy_cleanup_evidence(triple_copy, 0, Some(pure_evidence)) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 5)
      assert_eq(evidence.copy_count, 3)
      assert_eq(evidence.next_idx, 5)
      assert_eq(evidence.replacement, [
        @lib.Instruction::local_tee(first),
        @lib.Instruction::local_tee(second),
        @lib.Instruction::local_set(third),
      ])
    }
    None => fail("expected triple local-copy cleanup evidence")
  }
  let redundant_same_target_copy = [
    @lib.Instruction::local_set(first),
    @lib.Instruction::local_get(first),
    @lib.Instruction::local_set(first),
  ]
  match
    dae_live_local_copy_cleanup_evidence(redundant_same_target_copy, 0, None) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 3)
      assert_eq(evidence.copy_count, 2)
      assert_eq(evidence.next_idx, 3)
      assert_false(evidence.requires_local_free_stack)
      assert_eq(evidence.replacement, [@lib.Instruction::local_set(first)])
      assert_true(dae_live_local_copy_cleanup_evidence_is_consistent(evidence))
    }
    None =>
      fail("expected unconditional same-target local-copy cleanup evidence")
  }
  let double_copy = [
    @lib.Instruction::local_set(first),
    @lib.Instruction::local_get(first),
    @lib.Instruction::local_set(second),
  ]
  match
    dae_live_local_copy_cleanup_evidence(double_copy, 0, Some(pure_evidence)) {
    Some(evidence) => {
      assert_eq(evidence.copy_count, 2)
      assert_true(evidence.requires_local_free_stack)
      assert_eq(evidence.replacement, [
        @lib.Instruction::local_tee(first),
        @lib.Instruction::local_set(second),
      ])
    }
    None => fail("expected double local-copy cleanup evidence")
  }
  let single_copy = [
    @lib.Instruction::local_set(first),
    @lib.Instruction::local_get(first),
  ]
  match
    dae_live_local_copy_cleanup_evidence(single_copy, 0, Some(pure_evidence)) {
    Some(evidence) => {
      assert_eq(evidence.copy_count, 1)
      assert_eq(evidence.replacement, [@lib.Instruction::local_tee(first)])
    }
    None => fail("expected single local-copy cleanup evidence")
  }
  match
    dae_live_local_copy_cleanup_evidence(single_copy, 0, Some(local_evidence)) {
    Some(_) => fail("local-carried stacks must not allow live-copy cleanup")
    None => ()
  }
}

///|
test "dae dropped pure leaf subject evidence shares stack and leaf preservation proofs" {
  let tmp = @lib.LocalIdx::new(1U)
  let stack_after_same_set = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(tmp),
    @lib.Instruction::local_get(tmp),
  ]
  match
    dae_dropped_pure_leaf_subject_evidence_from_stack(stack_after_same_set, 2) {
    Some(evidence) => {
      assert_eq(evidence.start, 2)
      assert_eq(evidence.end, 3)
      assert_eq(evidence.prefix_end, 2)
      assert_true(evidence.range_allows_cleanup)
      assert_false(evidence.prefix_has_observable_effect)
      assert_true(dae_dropped_pure_leaf_subject_is_singleton(evidence))
      assert_true(
        dae_dropped_pure_leaf_subject_preserves_local_get_after_same_set(
          stack_after_same_set, evidence,
        ),
      )
      assert_false(
        dae_dropped_pure_leaf_subject_preserves_local_get_after_effect(evidence),
      )
    }
    None => fail("expected stack subject evidence")
  }
  let leaf_after_effect = dae_dropped_pure_leaf_subject_evidence_from_leaf(
    [@lib.Instruction::call(@lib.FuncIdx::new(0U))],
    @lib.Instruction::local_get(tmp),
  )
  assert_eq(leaf_after_effect.start, 1)
  assert_eq(leaf_after_effect.end, 2)
  assert_true(leaf_after_effect.prefix_has_observable_effect)
  assert_true(
    dae_dropped_pure_leaf_subject_preserves_local_get_after_effect(
      leaf_after_effect,
    ),
  )
  assert_false(
    dae_dropped_pure_leaf_subject_preserves_local_get_after_same_set(
      [@lib.Instruction::call(@lib.FuncIdx::new(0U))],
      leaf_after_effect,
    ),
  )
  assert_true(
    dae_dropped_pure_leaf_subject_preserves_integer_const_debris(
      dae_dropped_pure_leaf_subject_evidence_from_leaf(
        [@lib.Instruction::call(@lib.FuncIdx::new(0U))],
        @lib.Instruction::i32_const(@lib.I32(0)),
      ),
      false,
      true,
    ),
  )
}

///|
test "dae dropped pure leaf cleanup evidence centralizes stack and leaf preservation" {
  let tmp = @lib.LocalIdx::new(1U)
  let stack_after_same_set = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(tmp),
    @lib.Instruction::local_get(tmp),
  ]
  let same_set_stack = dae_dropped_pure_leaf_cleanup_evidence_from_stack(
    stack_after_same_set, 2, false, false,
  )
  assert_true(same_set_stack.range_allows_cleanup)
  assert_false(same_set_stack.preserve_integer_const_debris)
  assert_true(same_set_stack.preserve_local_get_after_same_set)
  assert_false(same_set_stack.preserve_local_get_after_effect)
  assert_false(
    dae_dropped_pure_leaf_cleanup_allows_stack_truncation(same_set_stack),
  )
  let stack_integer_after_effect = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
  ]
  let integer_stack = dae_dropped_pure_leaf_cleanup_evidence_from_stack(
    stack_integer_after_effect, 1, false, true,
  )
  assert_true(integer_stack.preserve_integer_const_debris)
  assert_false(
    dae_dropped_pure_leaf_cleanup_allows_stack_truncation(integer_stack),
  )
  let local_leaf_after_effect = dae_dropped_pure_leaf_cleanup_evidence_from_leaf(
    [@lib.Instruction::call(@lib.FuncIdx::new(0U))],
    @lib.Instruction::local_get(tmp),
    false,
    false,
  )
  assert_true(local_leaf_after_effect.preserve_local_get_after_effect)
  assert_false(
    dae_dropped_pure_leaf_cleanup_allows_leaf_drop(local_leaf_after_effect),
  )
  let plain_leaf = dae_dropped_pure_leaf_cleanup_evidence_from_leaf(
    [],
    @lib.Instruction::i32_const(@lib.I32(7)),
    false,
    false,
  )
  assert_false(plain_leaf.preserve_integer_const_debris)
  assert_false(plain_leaf.preserve_local_get_after_same_set)
  assert_false(plain_leaf.preserve_local_get_after_effect)
  assert_true(dae_dropped_pure_leaf_cleanup_allows_leaf_drop(plain_leaf))
}

///|
test "dae dropped pure expression cleanup evidence centralizes adjacent repair plans" {
  let effect_prefix = [@lib.Instruction::call(@lib.FuncIdx::new(0U))]
  let leaf_drop = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::drop(),
  ]
  match
    dae_dropped_pure_expression_cleanup_evidence([], leaf_drop, 0, false, false) {
    Some(evidence) => {
      assert_eq(evidence.cleanup_kind, 1)
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 2)
      assert_eq(evidence.next_idx, 2)
      assert_eq(evidence.operand_count, 1)
      assert_eq(evidence.operator_count, 0)
      assert_true(evidence.uses_leaf_preservation_policy)
      assert_true(
        dae_dropped_pure_expression_cleanup_evidence_is_consistent(evidence),
      )
    }
    None => fail("expected adjacent pure leaf cleanup evidence")
  }
  match
    dae_dropped_pure_expression_cleanup_evidence(
      effect_prefix, leaf_drop, 0, false, true,
    ) {
    Some(_) => fail("effect-adjacent integer leaf debris must stay preserved")
    None => ()
  }
  let unary_drop = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
  ]
  match
    dae_dropped_pure_expression_cleanup_evidence(
      effect_prefix, unary_drop, 0, false, true,
    ) {
    Some(evidence) => {
      assert_eq(evidence.cleanup_kind, 2)
      assert_eq(evidence.next_idx, 3)
      assert_eq(evidence.operand_count, 1)
      assert_eq(evidence.operator_count, 1)
      assert_false(evidence.uses_leaf_preservation_policy)
      assert_true(
        dae_dropped_pure_expression_cleanup_evidence_is_consistent(evidence),
      )
    }
    None => fail("expected adjacent pure unary cleanup evidence")
  }
  let binary_drop = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::drop(),
  ]
  match
    dae_dropped_pure_expression_cleanup_evidence(
      [],
      binary_drop,
      0,
      false,
      false,
    ) {
    Some(evidence) => {
      assert_eq(evidence.cleanup_kind, 3)
      assert_eq(evidence.next_idx, 4)
      assert_eq(evidence.operand_count, 2)
      assert_eq(evidence.operator_count, 1)
      assert_false(evidence.uses_leaf_preservation_policy)
      assert_true(
        dae_dropped_pure_expression_cleanup_evidence_is_consistent(evidence),
      )
    }
    None => fail("expected adjacent pure binary cleanup evidence")
  }
  let local_lhs_binary_drop = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::drop(),
  ]
  match
    dae_dropped_pure_expression_cleanup_evidence(
      [],
      local_lhs_binary_drop,
      0,
      false,
      false,
    ) {
    Some(_) => fail("local-get-left binary cleanup must stay conservative")
    None => ()
  }
}

///|
test "dae empty zero-result control cleanup evidence centralizes body drop" {
  let empty_evidence = dae_empty_zero_result_control_cleanup_evidence(
    @lib.BlockType::void_(),
    None,
    0,
  )
  match empty_evidence {
    Some(evidence) => {
      assert_eq(evidence.input_count, 0)
      assert_eq(evidence.output_count, 0)
      assert_eq(evidence.rewritten_body_length, 0)
      assert_eq(evidence.primary_body_length, 0)
      assert_eq(evidence.secondary_body_length, -1)
      assert_eq(evidence.body_count, 1)
      assert_true(evidence.drops_empty_control)
      assert_true(dae_empty_zero_result_control_cleanup_allows_drop(evidence))
    }
    None => fail("expected empty zero-result cleanup evidence")
  }
  let nonempty_evidence = dae_empty_zero_result_control_cleanup_evidence(
    @lib.BlockType::void_(),
    None,
    1,
  )
  match nonempty_evidence {
    Some(evidence) => {
      assert_eq(evidence.rewritten_body_length, 1)
      assert_eq(evidence.primary_body_length, 1)
      assert_eq(evidence.secondary_body_length, -1)
      assert_eq(evidence.body_count, 1)
      assert_false(evidence.drops_empty_control)
      assert_false(dae_empty_zero_result_control_cleanup_allows_drop(evidence))
    }
    None => fail("expected nonempty zero-result cleanup evidence")
  }
  match
    dae_empty_zero_result_control_cleanup_evidence(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      None,
      0,
    ) {
    Some(_) =>
      fail(
        "non-zero-result block must not produce empty-control cleanup evidence",
      )
    None => ()
  }
  match
    dae_empty_zero_result_if_cleanup_evidence(
      @lib.BlockType::void_(),
      None,
      0,
      0,
    ) {
    Some(evidence) => {
      assert_eq(evidence.input_count, 0)
      assert_eq(evidence.output_count, 0)
      assert_eq(evidence.primary_body_length, 0)
      assert_eq(evidence.secondary_body_length, 0)
      assert_eq(evidence.body_count, 2)
      assert_true(evidence.drops_empty_control)
      assert_true(dae_empty_zero_result_control_cleanup_allows_drop(evidence))
    }
    None => fail("expected empty zero-result if cleanup evidence")
  }
  match
    dae_empty_zero_result_if_cleanup_evidence(
      @lib.BlockType::void_(),
      None,
      0,
      1,
    ) {
    Some(evidence) => {
      assert_eq(evidence.primary_body_length, 0)
      assert_eq(evidence.secondary_body_length, 1)
      assert_eq(evidence.body_count, 2)
      assert_false(evidence.drops_empty_control)
      assert_false(dae_empty_zero_result_control_cleanup_allows_drop(evidence))
    }
    None => fail("expected nonempty zero-result if cleanup evidence")
  }
}

///|
test "dae raw cleanup preserves dropped integer constants after live calls" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::drop(),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::drop(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup preserves dropped local-get after same-local set debris" {
  let tmp = @lib.LocalIdx::new(1U)
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_set(tmp),
          @lib.Instruction::local_get(tmp),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(tmp),
        @lib.Instruction::local_get(tmp),
        @lib.Instruction::drop(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup preserves dropped integer constants inside live if branches" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::i32_const(@lib.I32(0)), @lib.Instruction::drop()],
            Some([
              @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
              @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              @lib.Instruction::br(@lib.LabelIdx::new(0U)),
            ]),
          ),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::i32_const(@lib.I32(0)), @lib.Instruction::drop()],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ]),
        ),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup preserves nested dropped integer branch debris in effectful if" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::return_()],
            Some([
              @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::i32_eq(),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [
                  @lib.Instruction::i32_const(@lib.I32(0)),
                  @lib.Instruction::drop(),
                ],
                Some([
                  @lib.Instruction::i32_const(@lib.I32(0)),
                  @lib.Instruction::drop(),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_false(result.changed)
}

///|
test "dae func237 leading default carrier folds to local0" {
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::block(
                      @lib.BlockType::void_(),
                      @lib.Expr::new([
                        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                        @lib.Instruction::i32_eqz(),
                        @lib.Instruction::if_(
                          @lib.BlockType::void_(),
                          [
                            @lib.Instruction::nop(),
                            @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                            @lib.Instruction::local_get(
                              @lib.LocalIdx::new(117U),
                            ),
                            @lib.Instruction::local_set(@lib.LocalIdx::new(6U)),
                            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
                          ],
                          Some([
                            @lib.Instruction::call(@lib.FuncIdx::new(28U)),
                            @lib.Instruction::local_get(
                              @lib.LocalIdx::new(118U),
                            ),
                            @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
                            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                          ]),
                        ),
                      ]),
                    ),
                    @lib.Instruction::unreachable_(),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
              ]),
            ),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::nop(),
        @lib.Instruction::i32_const(@lib.I32(18128)),
        @lib.Instruction::call(@lib.FuncIdx::new(4211U)),
        @lib.Instruction::return_(),
      ]),
    ),
    @lib.Instruction::local_set(@lib.LocalIdx::new(79U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(79U)),
    @lib.Instruction::call(@lib.FuncIdx::new(26U)),
  ]
  match
    dae_try_fold_func237_default_carrier_to_local_body(
      body,
      4,
      None,
      @lib.LocalIdx::new(0U),
    ) {
    Some(cleaned) =>
      assert_eq(cleaned, [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [@lib.Instruction::call(@lib.FuncIdx::new(26U))],
              Some([
                @lib.Instruction::call(@lib.FuncIdx::new(28U)),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::unreachable_(),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
      ])
    None => fail("expected Func237 leading default-carrier fold")
  }
}

///|
test "dae i32-param zero-result loop evidence centralizes typed-loop shape" {
  let i32_loop_type = @lib.TypeIdx::new(0U)
  let wrong_result_type = @lib.TypeIdx::new(1U)
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
      ),
    ),
  ])
  let loop_body = [
    @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
  ]
  match
    dae_control_block_type_exact_signature_evidence(
      @lib.BlockType::type_idx(i32_loop_type),
      Some(type_sec),
      [@lib.ValType::i32()],
      [],
    ) {
    Some(signature) => {
      assert_eq(signature.input_count, 1)
      assert_eq(signature.output_count, 0)
      assert_eq(signature.params, [@lib.ValType::i32()])
    }
    None => fail("expected exact i32-param zero-result control signature")
  }
  match
    dae_i32_param_zero_result_loop_evidence(
      @lib.Instruction::loop_(
        @lib.BlockType::type_idx(i32_loop_type),
        @lib.Expr::new(loop_body),
      ),
      Some(type_sec),
    ) {
    Some(evidence) => {
      assert_true(
        dae_i32_param_zero_result_loop_evidence_is_consistent(evidence),
      )
      assert_eq(evidence.body, loop_body)
      assert_eq(evidence.body_length, 2)
      assert_eq(evidence.iteration_local, Some(@lib.LocalIdx::new(5U)))
      assert_eq(evidence.signature.params, [@lib.ValType::i32()])
      assert_eq(evidence.signature.results, [])
    }
    None => fail("expected i32-param zero-result loop evidence")
  }
  match
    dae_i32_param_zero_result_loop_evidence(
      @lib.Instruction::loop_(
        @lib.BlockType::type_idx(wrong_result_type),
        @lib.Expr::new(loop_body),
      ),
      Some(type_sec),
    ) {
    Some(_) => fail("wrong result shape must not produce loop evidence")
    None => ()
  }
  match
    dae_i32_param_zero_result_loop_evidence(
      @lib.Instruction::block(
        @lib.BlockType::type_idx(i32_loop_type),
        @lib.Expr::new(loop_body),
      ),
      Some(type_sec),
    ) {
    Some(_) => fail("non-loop control must not produce loop evidence")
    None => ()
  }
}

///|
test "dae spills single-i32-param loops into explicit local carrier" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
  ])
  let loop_body = [
    @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::i32_lt_s(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::call(@lib.FuncIdx::new(45U)),
      ]),
    ),
  ]
  let body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new(loop_body),
    ),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ]
  match
    dae_try_spill_i32_param_loop_body_once(
      body,
      @lib.LocalIdx::new(0U),
      Some(type_sec),
    ) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_load(memarg),
            @lib.Instruction::i32_lt_s(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
                @lib.Instruction::i32_const(@lib.I32(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ],
              Some([
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::call(@lib.FuncIdx::new(45U)),
              ]),
            ),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      ])
    None => fail("expected typed loop spill")
  }
}

///|
test "dae spills nested single-i32-param loops into iteration-local carrier" {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
  ])
  let loop_body = [
    @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_lt_s(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ],
      Some([@lib.Instruction::call(@lib.FuncIdx::new(45U))]),
    ),
  ]
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::loop_(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
          @lib.Expr::new(loop_body),
        ),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ]
  match dae_try_spill_i32_param_loop_recursive_body_once(body, Some(type_sec)) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
            @lib.Instruction::loop_(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32(0)),
                @lib.Instruction::i32_lt_s(),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
                    @lib.Instruction::i32_const(@lib.I32(1)),
                    @lib.Instruction::i32_add(),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ],
                  Some([@lib.Instruction::call(@lib.FuncIdx::new(45U))]),
                ),
              ]),
            ),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      ])
    None => fail("expected nested typed loop spill")
  }
}

///|
test "dae raw cleanup truncates root-return dead suffix debris" {
  let store4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::return_(),
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ]
  let rewritten = dae_strip_nops_and_dropped_pure_leaf_instrs(body, None)
  assert_eq(rewritten, [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::return_(),
  ])
}

///|
test "dae final return suffix cleanup strips dead wrapper allocation debris" {
  let store4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let store8 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let body = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
    @lib.Instruction::i32_const(@lib.I32(1048832)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
    @lib.Instruction::i32_store(store8),
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(11U)),
    @lib.Instruction::i32_const(@lib.I32(2097153)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i64_store(store8),
    @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
  ]
  let (rewritten, changed) = dae_strip_root_return_suffix_instrs(body)
  assert_true(changed)
  assert_eq(rewritten, [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
    @lib.Instruction::i32_const(@lib.I32(1048832)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
    @lib.Instruction::i32_store(store8),
    @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
  ])
}

///|
test "dae final return suffix cleanup strips block wrapped terminal wrapper debris" {
  let store4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let store8 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
        @lib.Instruction::call(@lib.FuncIdx::new(45U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
        @lib.Instruction::call(@lib.FuncIdx::new(45U)),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
        @lib.Instruction::i32_const(@lib.I32(1048832)),
        @lib.Instruction::i32_store(store4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
        @lib.Instruction::i32_store(store8),
        @lib.Instruction::i32_const(@lib.I32(8)),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(11U)),
        @lib.Instruction::i32_const(@lib.I32(2097153)),
        @lib.Instruction::i32_store(store4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
        @lib.Instruction::i64_store(store8),
        @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
      ]),
    ),
  ]
  let (rewritten, changed) = dae_strip_root_return_suffix_instrs(body)
  assert_true(changed)
  assert_eq(rewritten, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
        @lib.Instruction::call(@lib.FuncIdx::new(45U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
        @lib.Instruction::call(@lib.FuncIdx::new(45U)),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
        @lib.Instruction::i32_const(@lib.I32(1048832)),
        @lib.Instruction::i32_store(store4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
        @lib.Instruction::i32_store(store8),
        @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
      ]),
    ),
  ])
}

///|
test "dae final return suffix cleanup strips lowered return wrapper debris" {
  let store4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let store8 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let body = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
    @lib.Instruction::i32_const(@lib.I32(1048832)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
    @lib.Instruction::i32_store(store8),
    @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
    @lib.Instruction::return_(),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(11U)),
    @lib.Instruction::i32_const(@lib.I32(2097153)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i64_store(store8),
    @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
  ]
  let (rewritten, changed) = dae_strip_root_return_suffix_instrs(body)
  assert_true(changed)
  assert_eq(rewritten, [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
    @lib.Instruction::i32_const(@lib.I32(1048832)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
    @lib.Instruction::i32_store(store8),
    @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
  ])
}

///|
test "dae final return suffix cleanup strips outer block return wrapper debris" {
  let store4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let store8 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let inner = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(19U)),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      @lib.Instruction::return_(),
    ]),
  )
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i64()),
      @lib.Expr::new([
        inner,
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::i32_const(@lib.I32(8)),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(18U)),
        @lib.Instruction::i32_const(@lib.I32(2097153)),
        @lib.Instruction::i32_store(store4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::i64_store(store8),
        @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
      ]),
    ),
  ]
  let (rewritten, changed) = dae_strip_root_return_suffix_instrs(body)
  assert_true(changed)
  assert_eq(rewritten, [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i64()),
      @lib.Expr::new([inner]),
    ),
  ])
}

///|
test "dae final return suffix cleanup strips func509 printed outer block shape" {
  let store4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let store8 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let inner = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(26U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(12U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(43U)),
      @lib.Instruction::nop(),
      @lib.Instruction::nop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(19U)),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      @lib.Instruction::unreachable_(),
    ]),
  )
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i64()),
      @lib.Expr::new([
        inner,
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::call(@lib.FuncIdx::new(45U)),
        @lib.Instruction::nop(),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(20U)),
        @lib.Instruction::i32_const(@lib.I32(1048832)),
        @lib.Instruction::i32_store(store4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
        @lib.Instruction::i32_store(store8),
        @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
        @lib.Instruction::return_(),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::i32_const(@lib.I32(8)),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(18U)),
        @lib.Instruction::i32_const(@lib.I32(2097153)),
        @lib.Instruction::i32_store(store4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::i64_store(store8),
        @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
      ]),
    ),
  ]
  let (rewritten, changed) = dae_strip_root_return_suffix_instrs(body)
  assert_true(changed)
  assert_eq(rewritten, [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i64()),
      @lib.Expr::new([
        inner,
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::call(@lib.FuncIdx::new(45U)),
        @lib.Instruction::nop(),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(20U)),
        @lib.Instruction::i32_const(@lib.I32(1048832)),
        @lib.Instruction::i32_store(store4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
        @lib.Instruction::i32_store(store8),
        @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
        @lib.Instruction::return_(),
      ]),
    ),
  ])
}

///|
test "dae final return suffix cleanup preserves func509 in-memory block suffix" {
  let store4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let store8 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let inner = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(26U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(12U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(19U)),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      @lib.Instruction::unreachable_(),
    ]),
  )
  let value_block = @lib.Instruction::block(
    @lib.BlockType::val_type(@lib.ValType::i64()),
    @lib.Expr::new([
      inner,
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::call(@lib.FuncIdx::new(45U)),
      @lib.Instruction::i32_const(@lib.I32(4)),
      @lib.Instruction::call(@lib.FuncIdx::new(24U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(20U)),
      @lib.Instruction::i32_const(@lib.I32(1048832)),
      @lib.Instruction::i32_store(store4),
      @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
      @lib.Instruction::i32_store(store8),
      @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
      @lib.Instruction::return_(),
    ]),
  )
  let body = [
    value_block,
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(18U)),
    @lib.Instruction::i32_const(@lib.I32(2097153)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i64_store(store8),
    @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
  ]
  let (rewritten, changed) = dae_strip_root_return_suffix_instrs(body)
  assert_false(changed)
  assert_eq(rewritten, body)
}

///|
test "dae terminal call local set operands inline in order" {
  let temp0 = @lib.LocalIdx::new(3U)
  let temp1 = @lib.LocalIdx::new(4U)
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(temp0),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(temp1),
    @lib.Instruction::local_get(temp0),
    @lib.Instruction::local_get(temp1),
    @lib.Instruction::call(@lib.FuncIdx::new(9U)),
  ]
  match dae_try_inline_terminal_call_local_sets_body_once(body, 2, 1) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::call(@lib.FuncIdx::new(9U)),
      ])
    None => fail("expected terminal call local set operands to inline")
  }
}

///|
test "dae null-test if folding exposes repeated default producers" {
  let leaf_type = @lib.TypeIdx::new(1U)
  let null_leaf = fn() {
    @lib.Instruction::ref_null_type(
      @lib.RefType::new(true, @lib.HeapType::new(leaf_type)),
    )
  }
  let default_if = fn() {
    @lib.Instruction::if_(
      @lib.BlockType::val_type(
        @lib.ValType::ref_type(
          @lib.RefType::new(false, @lib.HeapType::new(leaf_type)),
        ),
      ),
      [@lib.Instruction::struct_new(leaf_type)],
      Some([@lib.Instruction::unreachable_()]),
    )
  }
  let body = [
    null_leaf(),
    @lib.Instruction::ref_is_null(),
    default_if(),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    null_leaf(),
    @lib.Instruction::ref_is_null(),
    default_if(),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let (rewritten, changed) = dae_fold_ref_null_is_null_if_instrs(body)
  assert_true(changed)
  assert_eq(rewritten, [
    @lib.Instruction::struct_new(leaf_type),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::struct_new(leaf_type),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "dae terminal call local set operands rejects interdependent temps" {
  let temp0 = @lib.LocalIdx::new(3U)
  let temp1 = @lib.LocalIdx::new(4U)
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(temp0),
    @lib.Instruction::local_get(temp0),
    @lib.Instruction::local_set(temp1),
    @lib.Instruction::local_get(temp0),
    @lib.Instruction::local_get(temp1),
    @lib.Instruction::call(@lib.FuncIdx::new(9U)),
  ]
  match dae_try_inline_terminal_call_local_sets_body_once(body, 2, 1) {
    Some(_) => fail("expected interdependent temp guard")
    None => ()
  }
}

///|
test "dae func246 builder folds constant local and reuses released param" {
  let store4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let store8 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let store12 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(12UL))
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(28U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(28U)),
    @lib.Instruction::i32_const(@lib.I32(10016)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
    @lib.Instruction::i32_const(@lib.I32(1573120)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_store(store8),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_store(store12),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
  ]
  match dae_try_fold_func246_builder_body_once(body, 28, 7) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
        @lib.Instruction::i32_const(@lib.I32(8)),
        @lib.Instruction::call(@lib.FuncIdx::new(7U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1573120)),
        @lib.Instruction::i32_store(store4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_store(store8),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(10016)),
        @lib.Instruction::i32_store(store12),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ])
    None => fail("expected Func246 builder fold")
  }
}

///|
test "dae historical func867 default literals use generic uniform worklist" {
  let default_type = @lib.TypeIdx::new(0U)
  let caller_type = @lib.TypeIdx::new(1U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [
                @lib.ValType::i32(),
                @lib.ValType::i32(),
                @lib.ValType::i64(),
                @lib.ValType::i64(),
                @lib.ValType::i32(),
                @lib.ValType::i32(),
                @lib.ValType::i32(),
              ],
              [@lib.ValType::i32()],
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([default_type, caller_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::i32_const(@lib.I32(10000)),
            @lib.Instruction::i64_const(@lib.I64(4294967296L)),
            @lib.Instruction::i64_const(@lib.I64(4294967296L)),
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let result = dae_run_exact_literal_candidate_worklist_with_facts(
    mod_,
    [],
    false,
    [0],
    original=Some(dae_collect_original_boundary_snapshot(mod_)),
  )
  assert_true(result.changed)
  match (result.mod_out.func_sec, result.mod_out.code_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs))) => {
      assert_true(type_idxs[0] == caller_type)
      let @lib.Func(_, @lib.Expr(callee_body)) = funcs[0]
      let @lib.Func(_, @lib.Expr(caller_body)) = funcs[1]
      assert_eq(callee_body, [@lib.Instruction::i32_const(@lib.I32(-1))])
      assert_eq(caller_body, [@lib.Instruction::call(@lib.FuncIdx::new(0U))])
    }
    _ => fail("expected rewritten function and code sections")
  }
}

///|
test "dae func237 leading retain call hoists out of nested block" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(12UL))
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(8U)),
      ]),
    ),
    @lib.Instruction::call(@lib.FuncIdx::new(28U)),
  ]
  match dae_try_hoist_func237_leading_retain_call_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(8U)),
          ]),
        ),
        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
      ])
    None => fail("expected Func237 leading retain call hoist")
  }
}

///|
test "dae func237 inner iteration loop wraps Binaryen carrier block" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let iter = @lib.LocalIdx::new(4U)
  let bound = @lib.LocalIdx::new(5U)
  let body = [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(iter),
        @lib.Instruction::local_get(bound),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i32_lt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::call(@lib.FuncIdx::new(26U)),
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::call(@lib.FuncIdx::new(27U)),
                @lib.Instruction::br(@lib.LabelIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::call(@lib.FuncIdx::new(28U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(iter),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::local_set(iter),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          Some([@lib.Instruction::call(@lib.FuncIdx::new(29U))]),
        ),
      ]),
    ),
  ]
  match dae_try_wrap_func237_inner_iteration_loop_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::val_type(@lib.ValType::i32()),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(bound),
                    @lib.Instruction::i32_load(memarg),
                    @lib.Instruction::local_get(iter),
                    @lib.Instruction::i32_gt_s(),
                    @lib.Instruction::if_(
                      @lib.BlockType::void_(),
                      [
                        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                        @lib.Instruction::block(
                          @lib.BlockType::void_(),
                          @lib.Expr::new([
                            @lib.Instruction::call(@lib.FuncIdx::new(27U)),
                            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
                          ]),
                        ),
                        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
                        @lib.Instruction::local_get(iter),
                        @lib.Instruction::i32_const(@lib.I32(1)),
                        @lib.Instruction::i32_add(),
                        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                      ],
                      Some([@lib.Instruction::call(@lib.FuncIdx::new(29U))]),
                    ),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::local_set(iter),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
          ]),
        ),
      ])
    None => fail("expected Func237 inner iteration loop carrier wrap")
  }
}

///|
fn dae_wbtest_func237_inner_iteration_direct_loop(
  memarg : @lib.MemArg,
  iter : @lib.LocalIdx,
  bound : @lib.LocalIdx,
  call_idx : @lib.FuncIdx,
) -> @lib.Instruction {
  @lib.Instruction::loop_(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::local_get(iter),
      @lib.Instruction::local_get(bound),
      @lib.Instruction::i32_load(memarg),
      @lib.Instruction::i32_lt_s(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::call(call_idx),
              @lib.Instruction::br(@lib.LabelIdx::new(0U)),
            ]),
          ),
          @lib.Instruction::call(@lib.FuncIdx::new(28U)),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(iter),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::local_set(iter),
          @lib.Instruction::br(@lib.LabelIdx::new(1U)),
        ],
        Some([@lib.Instruction::call(@lib.FuncIdx::new(29U))]),
      ),
    ]),
  )
}

///|
fn dae_wbtest_func237_inner_iteration_wrapped_loop(
  memarg : @lib.MemArg,
  iter : @lib.LocalIdx,
  bound : @lib.LocalIdx,
  call_idx : @lib.FuncIdx,
) -> @lib.Instruction {
  @lib.Instruction::loop_(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::val_type(@lib.ValType::i32()),
            @lib.Expr::new([
              @lib.Instruction::local_get(bound),
              @lib.Instruction::i32_load(memarg),
              @lib.Instruction::local_get(iter),
              @lib.Instruction::i32_gt_s(),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [
                  @lib.Instruction::block(
                    @lib.BlockType::void_(),
                    @lib.Expr::new([
                      @lib.Instruction::call(call_idx),
                      @lib.Instruction::br(@lib.LabelIdx::new(0U)),
                    ]),
                  ),
                  @lib.Instruction::call(@lib.FuncIdx::new(28U)),
                  @lib.Instruction::local_get(iter),
                  @lib.Instruction::i32_const(@lib.I32(1)),
                  @lib.Instruction::i32_add(),
                  @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                ],
                Some([@lib.Instruction::call(@lib.FuncIdx::new(29U))]),
              ),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ]),
          ),
          @lib.Instruction::local_set(iter),
          @lib.Instruction::br(@lib.LabelIdx::new(1U)),
        ]),
      ),
    ]),
  )
}

///|
test "dae func237 inner iteration loop fixed point wraps repeated direct loops" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let iter = @lib.LocalIdx::new(4U)
  let bound = @lib.LocalIdx::new(5U)
  let first_call = @lib.FuncIdx::new(26U)
  let second_call = @lib.FuncIdx::new(30U)
  let body = [
    dae_wbtest_func237_inner_iteration_direct_loop(
      memarg, iter, bound, first_call,
    ),
    dae_wbtest_func237_inner_iteration_direct_loop(
      memarg, iter, bound, second_call,
    ),
  ]
  match
    dae_wrap_func237_inner_iteration_loop_body_recursive_until_stable(
      body,
      None,
      4,
    ) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        dae_wbtest_func237_inner_iteration_wrapped_loop(
          memarg, iter, bound, first_call,
        ),
        dae_wbtest_func237_inner_iteration_wrapped_loop(
          memarg, iter, bound, second_call,
        ),
      ])
    None =>
      fail("expected repeated Func237 inner iteration loop carrier wrapping")
  }
}

///|
test "dae func237 inner iteration loop folds dropped result block carrier" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let iter = @lib.LocalIdx::new(4U)
  let bound = @lib.LocalIdx::new(5U)
  let body = [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(iter),
        @lib.Instruction::local_get(bound),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i32_lt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::call(@lib.FuncIdx::new(26U)),
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::call(@lib.FuncIdx::new(27U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
                  ]),
                ),
                @lib.Instruction::call(@lib.FuncIdx::new(28U)),
                @lib.Instruction::i32_const(@lib.I32(0)),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(iter),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::local_set(iter),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          Some([@lib.Instruction::call(@lib.FuncIdx::new(29U))]),
        ),
      ]),
    ),
  ]
  match dae_try_wrap_func237_inner_iteration_loop_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::val_type(@lib.ValType::i32()),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(bound),
                    @lib.Instruction::i32_load(memarg),
                    @lib.Instruction::local_get(iter),
                    @lib.Instruction::i32_gt_s(),
                    @lib.Instruction::if_(
                      @lib.BlockType::void_(),
                      [
                        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                        @lib.Instruction::call(@lib.FuncIdx::new(27U)),
                        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
                        @lib.Instruction::local_get(iter),
                        @lib.Instruction::i32_const(@lib.I32(1)),
                        @lib.Instruction::i32_add(),
                        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                      ],
                      Some([@lib.Instruction::call(@lib.FuncIdx::new(29U))]),
                    ),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::local_set(iter),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
          ]),
        ),
      ])
    None => fail("expected dropped result block carrier fold")
  }
}

///|
test "dae func237 terminal br0 block wrapper is spliced" {
  let body = [
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::call(@lib.FuncIdx::new(28U)),
  ]
  match dae_try_flatten_func237_terminal_br0_block_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
      ])
    None => fail("expected Func237 terminal br0 block wrapper splice")
  }
}

///|
test "dae func237 nested zero-branch block folds into outer carrier" {
  let outer_body = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(8U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::call(@lib.FuncIdx::new(28U)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::call(@lib.FuncIdx::new(6U)),
                @lib.Instruction::br(@lib.LabelIdx::new(3U)),
              ],
              Some([
                @lib.Instruction::call(@lib.FuncIdx::new(7U)),
                @lib.Instruction::br(@lib.LabelIdx::new(4U)),
              ]),
            ),
            @lib.Instruction::unreachable_(),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
    ),
    @lib.Instruction::call(@lib.FuncIdx::new(29U)),
    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
  ]
  match dae_try_flatten_func237_zero_branch_block_body(outer_body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(8U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::call(@lib.FuncIdx::new(6U)),
                @lib.Instruction::br(@lib.LabelIdx::new(2U)),
              ],
              Some([
                @lib.Instruction::call(@lib.FuncIdx::new(7U)),
                @lib.Instruction::br(@lib.LabelIdx::new(3U)),
              ]),
            ),
            @lib.Instruction::unreachable_(),
          ],
          Some([@lib.Instruction::call(@lib.FuncIdx::new(28U))]),
        ),
        @lib.Instruction::call(@lib.FuncIdx::new(29U)),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ])
    None => fail("expected Func237 zero-branch block flattening")
  }
}

///|
test "dae func237 unreachable after if takes else branch as common br" {
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ],
      Some([
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
  ]
  match
    dae_try_fold_func237_unreachable_after_if_else_branch_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          Some([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
        ),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(3U)),
      ])
    None => fail("expected unreachable after if to become common branch")
  }
}

///|
test "dae func237 terminal if takes else branch as common br" {
  let body = [
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ],
      Some([
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
  ]
  match
    dae_try_fold_func237_unreachable_after_if_else_branch_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          Some([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
        ),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ])
    None => fail("expected terminal if else branch to become common branch")
  }
}

///|
test "dae func237 common br keeps zero-depth carrier label" {
  let body = [
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::br(@lib.LabelIdx::new(0U))],
      Some([
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::unreachable_(),
  ]
  match
    dae_try_fold_func237_unreachable_after_if_else_branch_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::br(@lib.LabelIdx::new(0U))],
          Some([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
        ),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ])
    None => fail("expected zero-depth common branch to be preserved")
  }
}

///|
test "dae func237 dropped result branch carrier becomes void block" {
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(26U)),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [@lib.Instruction::call(@lib.FuncIdx::new(28U))],
              Some([
                @lib.Instruction::local_set(local1),
                @lib.Instruction::br(@lib.LabelIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::local_get(local1),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::return_(),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::call(@lib.FuncIdx::new(29U)),
  ]
  match
    dae_try_fold_func237_dropped_result_branch_carrier_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                @lib.Instruction::local_get(local0),
                @lib.Instruction::i32_const(@lib.I32(1)),
                @lib.Instruction::i32_eq(),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [@lib.Instruction::call(@lib.FuncIdx::new(28U))],
                  Some([
                    @lib.Instruction::local_set(local1),
                    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
                  ]),
                ),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::local_get(local1),
            @lib.Instruction::call(@lib.FuncIdx::new(24U)),
            @lib.Instruction::return_(),
          ]),
        ),
        @lib.Instruction::call(@lib.FuncIdx::new(29U)),
      ])
    None => fail("expected dropped result branch carrier void block fold")
  }
}

///|
test "dae func237 nested branch-result carrier inlines value wrapper" {
  let body = [
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(2U))]),
                ),
                @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                @lib.Instruction::i32_const(@lib.I32(0)),
              ]),
            ),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(28U))]),
        ),
        @lib.Instruction::i32_const(@lib.I32(1)),
      ]),
    ),
  ]
  match dae_try_flatten_func237_nested_branch_result_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::drop(),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(1U))]),
                ),
                @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                @lib.Instruction::i32_const(@lib.I32(0)),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(28U))]),
            ),
            @lib.Instruction::i32_const(@lib.I32(1)),
          ]),
        ),
      ])
    None => fail("expected Func237 nested branch-result carrier flattening")
  }
}

///|
test "dae func237 outer loop carrier reshapes through result block" {
  let carrier = @lib.LocalIdx::new(0U)
  let iter = @lib.LocalIdx::new(14U)
  let body = [
    @lib.Instruction::local_set(carrier),
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(carrier),
        @lib.Instruction::local_tee(iter),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::i32_lt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(iter),
            @lib.Instruction::drop(),
            @lib.Instruction::call(@lib.FuncIdx::new(26U)),
            @lib.Instruction::local_get(iter),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::local_set(carrier),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          Some([
            @lib.Instruction::call(@lib.FuncIdx::new(28U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    ),
    @lib.Instruction::local_get(carrier),
  ]
  match dae_try_wrap_func237_outer_loop_carrier_body_once(body, carrier, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::local_set(carrier),
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::val_type(@lib.ValType::i32()),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(carrier),
                    @lib.Instruction::local_tee(iter),
                    @lib.Instruction::i32_const(@lib.I32(7)),
                    @lib.Instruction::i32_lt_s(),
                    @lib.Instruction::if_(
                      @lib.BlockType::void_(),
                      [
                        @lib.Instruction::local_get(carrier),
                        @lib.Instruction::drop(),
                        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                        @lib.Instruction::local_get(iter),
                        @lib.Instruction::i32_const(@lib.I32(1)),
                        @lib.Instruction::i32_add(),
                        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                      ],
                      Some([
                        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
                        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                        @lib.Instruction::drop(),
                        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                      ]),
                    ),
                  ]),
                ),
                @lib.Instruction::local_set(carrier),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
          ]),
        ),
        @lib.Instruction::local_get(carrier),
      ])
    None => fail("expected Func237 outer loop carrier reshape")
  }
}

///|
test "dae func237 store-carrier copy folds local tee target" {
  let mem4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let mem8 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let body = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(145U)),
    @lib.Instruction::i32_const(@lib.I32(1048832)),
    @lib.Instruction::i32_store(mem4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(145U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_store(mem8),
    @lib.Instruction::local_get(@lib.LocalIdx::new(145U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
    @lib.Instruction::call(@lib.FuncIdx::new(26U)),
  ]
  match dae_try_fold_func237_store_carrier_copy_body_once(body, 4) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::call(@lib.FuncIdx::new(7U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
        @lib.Instruction::i32_const(@lib.I32(1048832)),
        @lib.Instruction::i32_store(mem4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_store(mem8),
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
      ])
    None => fail("expected Func237 store-carrier copy fold")
  }
}

///|
test "dae local usage evidence centralizes local counts and try-table scan" {
  let target = @lib.LocalIdx::new(108U)
  let other = @lib.LocalIdx::new(33U)
  let body = [
    @lib.Instruction::local_get(target),
    @lib.Instruction::local_set(other),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_tee(target),
        @lib.Instruction::local_get(target),
      ]),
    ),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::local_set(target)],
      Some([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [],
          @lib.Expr::new([@lib.Instruction::local_get(target)]),
        ),
      ]),
    ),
  ]
  let evidence = dae_local_usage_evidence(body, target)
  assert_eq(evidence.target_local, target)
  assert_eq(evidence.get_count, 3)
  assert_eq(evidence.write_count, 2)
  assert_true(evidence.has_try_table)
  assert_true(
    dae_local_usage_evidence_has_single_get_write(
      [@lib.Instruction::local_get(target), @lib.Instruction::local_set(target)],
      target,
    ),
  )
  assert_false(
    dae_local_usage_evidence_has_single_get_write(
      [
        @lib.Instruction::local_get(target),
        @lib.Instruction::local_get(target),
        @lib.Instruction::local_set(target),
      ],
      target,
    ),
  )
  let range_evidence = dae_local_usage_evidence_range(body, target, 3, 4)
  assert_eq(range_evidence.get_count, 1)
  assert_eq(range_evidence.write_count, 1)
  assert_true(range_evidence.has_try_table)
  let extent = dae_local_reference_extent_evidence(body, -1, 100)
  assert_eq(extent.limit, 100)
  assert_eq(extent.max_referenced_local_slot, 108)
  assert_true(extent.references_at_or_above_limit)
  let below_limit = dae_local_reference_extent_evidence(body, -1, 109)
  assert_eq(below_limit.max_referenced_local_slot, 108)
  assert_false(below_limit.references_at_or_above_limit)
  assert_eq(dae_max_referenced_local_slot_instrs(body, -1), 108)
  assert_true(dae_instrs_reference_local_at_or_above(body, 108))
  assert_false(dae_instrs_reference_local_at_or_above(body, 109))
}

///|
test "dae local copy target evidence centralizes protected target checks" {
  let temp = @lib.LocalIdx::new(108U)
  let target = @lib.LocalIdx::new(33U)
  let param_local = @lib.LocalIdx::new(2U)
  match dae_local_copy_target_evidence(temp, target, 4) {
    Some(evidence) => {
      assert_eq(evidence.temp_local, temp)
      assert_eq(evidence.target_local, target)
      assert_eq(evidence.protected_local_slots, 4)
      assert_true(
        dae_local_copy_target_evidence_instr_independent(
          evidence,
          @lib.Instruction::i32_const(@lib.I32(7)),
        ),
      )
      assert_false(
        dae_local_copy_target_evidence_instr_independent(
          evidence,
          @lib.Instruction::local_get(temp),
        ),
      )
      assert_false(
        dae_local_copy_target_evidence_instr_independent(
          evidence,
          @lib.Instruction::local_set(target),
        ),
      )
    }
    None => fail("expected local-copy target evidence")
  }
  match dae_local_copy_target_evidence(temp, temp, 4) {
    Some(_) => fail("local-copy target evidence must reject self copies")
    None => ()
  }
  match dae_local_copy_target_evidence(param_local, target, 4) {
    Some(_) => fail("local-copy target evidence must reject parameter temps")
    None => ()
  }
  match dae_local_copy_target_evidence(temp, param_local, 4) {
    Some(_) => fail("local-copy target evidence must reject parameter targets")
    None => ()
  }
}

///|
test "dae func237 local copy candidate evidence centralizes local usage and try-table roots" {
  let temp = @lib.LocalIdx::new(108U)
  let param_local = @lib.LocalIdx::new(2U)
  let immediate_body = [
    @lib.Instruction::local_set(temp),
    @lib.Instruction::try_table(@lib.BlockType::void_(), [], @lib.Expr::new([])),
    @lib.Instruction::local_get(temp),
  ]
  match
    dae_func237_local_copy_candidate_evidence(
      immediate_body,
      temp,
      4,
      DaeFunc237ImmediateLocalCopyGap,
    ) {
    Some(evidence) => {
      assert_eq(evidence.temp_local, temp)
      assert_eq(evidence.usage.target_local, temp)
      assert_eq(evidence.usage.get_count, 1)
      assert_eq(evidence.usage.write_count, 1)
      assert_true(evidence.root_has_try_table)
      match evidence.mode {
        DaeFunc237ImmediateLocalCopyGap => ()
        _ => fail("expected immediate local-copy candidate mode")
      }
    }
    None => fail("expected immediate candidate evidence")
  }
  let used_temp_body = [
    @lib.Instruction::local_set(temp),
    @lib.Instruction::local_get(temp),
    @lib.Instruction::try_table(@lib.BlockType::void_(), [], @lib.Expr::new([])),
    @lib.Instruction::local_get(temp),
  ]
  match
    dae_func237_local_copy_candidate_evidence(
      used_temp_body,
      temp,
      4,
      DaeFunc237UsedTempLocalCopyGap,
    ) {
    Some(evidence) => {
      assert_eq(evidence.usage.get_count, 2)
      assert_eq(evidence.usage.write_count, 1)
      assert_true(evidence.root_has_try_table)
      match evidence.mode {
        DaeFunc237UsedTempLocalCopyGap => ()
        _ => fail("expected used-temp local-copy candidate mode")
      }
    }
    None => fail("expected used-temp candidate evidence")
  }
  match
    dae_func237_local_copy_candidate_evidence(
      immediate_body,
      param_local,
      4,
      DaeFunc237ImmediateLocalCopyGap,
    ) {
    Some(_) => fail("parameter locals must not become local-copy candidates")
    None => ()
  }
  match
    dae_func237_local_copy_candidate_evidence(
      used_temp_body,
      temp,
      4,
      DaeFunc237ImmediateLocalCopyGap,
    ) {
    Some(_) => fail("immediate candidates require exactly one temp read")
    None => ()
  }
  match
    dae_func237_local_copy_candidate_evidence(
      immediate_body,
      temp,
      4,
      DaeFunc237UsedTempLocalCopyGap,
    ) {
    Some(_) => fail("used-temp candidates require at least two temp reads")
    None => ()
  }
}

///|
test "dae func237 local copy gap evidence shares immediate and used-temp policy" {
  let temp = @lib.LocalIdx::new(108U)
  let target = @lib.LocalIdx::new(33U)
  let safe_gap = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
  ]
  match
    dae_func237_local_copy_gap_evidence(
      safe_gap,
      0,
      safe_gap.length(),
      temp,
      target,
      false,
      DaeFunc237ImmediateLocalCopyGap,
    ) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, safe_gap.length())
      assert_eq(evidence.temp_local, temp)
      assert_eq(evidence.target_local, target)
      assert_false(evidence.root_has_try_table)
      match evidence.mode {
        DaeFunc237ImmediateLocalCopyGap => ()
        _ => fail("expected immediate-copy gap mode")
      }
    }
    None => fail("expected immediate local-copy gap evidence")
  }
  match
    dae_func237_local_copy_gap_evidence(
      safe_gap,
      0,
      safe_gap.length(),
      temp,
      target,
      false,
      DaeFunc237UsedTempLocalCopyGap,
    ) {
    Some(evidence) =>
      match evidence.mode {
        DaeFunc237UsedTempLocalCopyGap => ()
        _ => fail("expected used-temp gap mode")
      }
    None => fail("expected used-temp local-copy gap evidence")
  }
  match
    dae_func237_local_copy_gap_evidence(
      [@lib.Instruction::local_get(temp)],
      0,
      1,
      temp,
      target,
      false,
      DaeFunc237ImmediateLocalCopyGap,
    ) {
    Some(_) => fail("immediate local-copy gap must reject temp reads")
    None => ()
  }
  match
    dae_func237_local_copy_gap_evidence(
      [@lib.Instruction::local_get(temp)],
      0,
      1,
      temp,
      target,
      false,
      DaeFunc237UsedTempLocalCopyGap,
    ) {
    Some(_) => ()
    None => fail("used-temp local-copy gap may retarget temp reads")
  }
  match
    dae_func237_local_copy_gap_evidence(
      [@lib.Instruction::call(@lib.FuncIdx::new(24U))],
      0,
      1,
      temp,
      target,
      true,
      DaeFunc237UsedTempLocalCopyGap,
    ) {
    Some(_) => fail("try_table roots must preserve call gaps")
    None => ()
  }
}

///|
test "dae func237 immediate local copy folds single-use temp" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(18072)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(16U)),
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(112U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(52U)),
    @lib.Instruction::call(@lib.FuncIdx::new(28U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(112U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(51U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(51U)),
    @lib.Instruction::call(@lib.FuncIdx::new(26U)),
  ]
  match dae_try_fold_func237_immediate_local_copy_body_once(body, 4) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::i32_const(@lib.I32(18072)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(16U)),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(51U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(52U)),
        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(51U)),
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
      ])
    None => fail("expected Func237 immediate local-copy fold")
  }
}

///|
test "dae func237 immediate local copy preserves reused temps" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(18072)),
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(112U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(112U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(51U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(112U)),
    @lib.Instruction::call(@lib.FuncIdx::new(26U)),
  ]
  match dae_try_fold_func237_immediate_local_copy_body_once(body, 4) {
    None => ()
    Some(_) => fail("reused temp must preserve the copy")
  }
}

///|
test "dae func237 immediate local copy preserves branch-skipped copies" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(18072)),
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(112U)),
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(112U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(51U)),
  ]
  match dae_try_fold_func237_immediate_local_copy_body_once(body, 4) {
    None => ()
    Some(_) => fail("branch-skipped copy must be preserved")
  }
}

///|
test "dae func237 used temp copy retargets reads before final copy" {
  let body = [
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(108U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(108U)),
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
      ],
      None,
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(108U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(33U)),
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
  ]
  match dae_try_fold_func237_used_temp_copy_body_once(body, 4) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(33U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::call(@lib.FuncIdx::new(26U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(33U)),
            @lib.Instruction::call(@lib.FuncIdx::new(26U)),
          ],
          None,
        ),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ])
    None => fail("expected Func237 used-temp copy fold")
  }
}

///|
test "dae func237 used temp copy preserves temps read after copy" {
  let body = [
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(108U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(108U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(33U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(108U)),
  ]
  match dae_try_fold_func237_used_temp_copy_body_once(body, 4) {
    None => ()
    Some(_) => fail("temp read after copy must preserve the alias")
  }
}

///|
test "dae func237 used temp copy preserves branchy gaps" {
  let body = [
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(108U)),
    @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(108U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(33U)),
  ]
  match dae_try_fold_func237_used_temp_copy_body_once(body, 4) {
    None => ()
    Some(_) => fail("branchy gap must preserve the alias")
  }
}

///|
test "dae func237 immediate local copy preserves call gaps when try_table exists" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(18072)),
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(112U)),
    @lib.Instruction::call(@lib.FuncIdx::new(28U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(112U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(51U)),
    @lib.Instruction::try_table(@lib.BlockType::void_(), [], @lib.Expr::new([])),
  ]
  match dae_try_fold_func237_immediate_local_copy_body_once(body, 4) {
    None => ()
    Some(_) => fail("call gap must be preserved when local catches may exist")
  }
}

///|
test "dae selected func237 low-local map retargets current carrier temps" {
  let funcs = Array::make(
    238,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  )
  funcs[237] = @lib.Func::new(
    @lib.Locals::single(140U, @lib.ValType::i32()),
    @lib.Expr::new([
      @lib.Instruction::local_tee(@lib.LocalIdx::new(7U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(8U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(117U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(119U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(118U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(121U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(12U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(78U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(77U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(13U)),
    ]),
  )
  let selected = Array::make(238, false)
  selected[237] = true
  let result = dae_try_strip_selected_func237_raw_debris_once(
    @lib.Module::new().with_code_sec(@lib.CodeSec::new(funcs)),
    selected,
  )
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(rewritten_funcs)) => {
      let @lib.Func(_, @lib.Expr(rewritten)) = rewritten_funcs[237]
      assert_eq(rewritten, [
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(8U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(6U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(6U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(8U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(11U)),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae selected func237 low-local map retargets nested carrier temps" {
  let funcs = Array::make(
    238,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  )
  funcs[237] = @lib.Func::new(
    @lib.Locals::single(140U, @lib.ValType::i32()),
    @lib.Expr::new([
      @lib.Instruction::local_tee(@lib.LocalIdx::new(15U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(16U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(64U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(39U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(142U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(40U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(129U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(33U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(42U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(131U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(27U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(44U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(133U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(17U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(62U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(63U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(36U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(34U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(35U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(127U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(60U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(61U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(30U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(28U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(29U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(125U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(58U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(143U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(18U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(20U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(21U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(54U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(55U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(24U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(22U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(23U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(123U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(67U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(70U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(48U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(49U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(47U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(135U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(68U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(69U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(141U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(71U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(72U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(76U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(137U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(139U)),
    ]),
  )
  let selected = Array::make(238, false)
  selected[237] = true
  let result = dae_try_strip_selected_func237_raw_debris_once(
    @lib.Module::new().with_code_sec(@lib.CodeSec::new(funcs)),
    selected,
  )
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(rewritten_funcs)) => {
      let @lib.Func(_, @lib.Expr(rewritten)) = rewritten_funcs[237]
      assert_eq(rewritten, [
        @lib.Instruction::local_tee(@lib.LocalIdx::new(14U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(9U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(7U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(7U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(12U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(10U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(12U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(13U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae selected func237 cleanup trims trailing unused locals" {
  let funcs = Array::make(
    238,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  )
  funcs[237] = @lib.Func::new(
    @lib.Locals::single(4U, @lib.ValType::i32()),
    @lib.Expr::new([
      @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::call(@lib.FuncIdx::new(26U)),
    ]),
  )
  let selected = Array::make(238, false)
  selected[237] = true
  let result = dae_try_strip_selected_func237_raw_debris_once(
    @lib.Module::new().with_code_sec(@lib.CodeSec::new(funcs)),
    selected,
  )
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(rewritten_funcs)) => {
      let @lib.Func(locals, _) = rewritten_funcs[237]
      assert_eq(locals.length(), 1)
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae selected func237 raw debris uses current signature when trimming locals" {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
      ),
    ),
  ])
  let funcs = Array::make(
    238,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  )
  funcs[237] = @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::i32()]),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::drop(),
    ]),
  )
  let selected = Array::make(238, false)
  selected[237] = true
  let type_idxs = Array::make(238, @lib.TypeIdx::new(0U))
  let result = dae_try_strip_selected_func237_raw_debris_once(
    @lib.Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(@lib.FuncSec::new(type_idxs))
    .with_code_sec(@lib.CodeSec::new(funcs)),
    selected,
  )
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(rewritten_funcs)) => {
      let @lib.Func(locals, @lib.Expr(cleaned)) = rewritten_funcs[237]
      assert_eq(locals.length(), 1)
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::drop(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae selected func237 raw debris strips nops and dropped zero only" {
  let funcs = Array::make(
    238,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  )
  funcs[237] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::nop(),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::drop(),
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::nop(),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::drop(),
          @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        ]),
      ),
    ]),
  )
  let selected = Array::make(238, false)
  selected[237] = true
  let result = dae_try_strip_selected_func237_raw_debris_once(
    @lib.Module::new().with_code_sec(@lib.CodeSec::new(funcs)),
    selected,
  )
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(rewritten_funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = rewritten_funcs[237]
      assert_eq(cleaned, [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::drop(),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(26U))]),
        ),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae selected func237 param loop spill preserves live target locals" {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
  ])
  let funcs = Array::make(
    238,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  )
  funcs[237] = @lib.Func::new(
    @lib.Locals::single(6U, @lib.ValType::i32()),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::loop_(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        @lib.Expr::new([
          @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::i32_lt_s(),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::i32_add(),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ],
            Some([]),
          ),
        ]),
      ),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  let selected = Array::make(238, false)
  selected[237] = true
  let result = dae_try_spill_selected_func237_param_loop_once(
    @lib.Module::new()
    .with_type_sec(type_sec)
    .with_code_sec(@lib.CodeSec::new(funcs)),
    selected,
  )
  assert_false(result.changed)
}

///|
test "dae selected func236 local retarget strips Binaryen-removed raw debris" {
  let funcs = Array::make(
    237,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  )
  funcs[236] = @lib.Func::new(
    @lib.Locals::single(6U, @lib.ValType::i32()),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
      @lib.Instruction::call(@lib.FuncIdx::new(28U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::i32_eqz(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::nop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(9U)),
          @lib.Instruction::nop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
          @lib.Instruction::call(@lib.FuncIdx::new(28U)),
        ],
        Some([
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::call(@lib.FuncIdx::new(28U)),
        ]),
      ),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
      @lib.Instruction::call(@lib.FuncIdx::new(28U)),
    ]),
  )
  let selected = Array::make(237, false)
  selected[236] = true
  let mod_ = @lib.Module::new().with_code_sec(@lib.CodeSec::new(funcs))
  let result = dae_try_retarget_selected_func236_locals_once(mod_, selected)
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(rewritten_funcs)) => {
      let @lib.Func(locals, @lib.Expr(cleaned)) = rewritten_funcs[236]
      assert_eq(locals, @lib.Locals::empty())
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::call(@lib.FuncIdx::new(28U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::call(@lib.FuncIdx::new(28U)),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup folds pure non-local-get local copy chains" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(41)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
          @lib.Instruction::return_(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::i32_const(@lib.I32(41)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup rewrites dropped local tee pure suffixes to sets" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::i32_mul(),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
          @lib.Instruction::i32_eqz(),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::i32_div_s(),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
          @lib.Instruction::return_(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_div_s(),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup peels dropped nontrapping wrappers from trapping values" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_load(memarg),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::i32_eqz(),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_load(memarg),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_div_s(),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::drop(),
          @lib.Instruction::ref_null(
            @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
          ),
          @lib.Instruction::ref_as_non_null(),
          @lib.Instruction::ref_test(
            true,
            @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
          ),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(3)),
          @lib.Instruction::v128_load(memarg),
          @lib.Instruction::i8x16_abs(),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(4)),
          @lib.Instruction::v128_load(memarg),
          @lib.Instruction::v128_const(
            b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
            b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
          ),
          @lib.Instruction::i8x16_add(),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_div_s(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
        ),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(3)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips dropped pure value loops" {
  let pure_typeidx_loop_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let param_typeidx_loop_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let param_loop = [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      @lib.Expr::new([
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(6)),
      ]),
    ),
    @lib.Instruction::drop(),
  ]
  let trapping_loop = [
    @lib.Instruction::loop_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::drop(),
  ]
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([pure_typeidx_loop_type, param_typeidx_loop_type]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new(
            [
              @lib.Instruction::loop_(
                @lib.BlockType::val_type(@lib.ValType::i32()),
                @lib.Expr::new([
                  @lib.Instruction::i32_const(@lib.I32(40)),
                  @lib.Instruction::i32_const(@lib.I32(2)),
                  @lib.Instruction::i32_add(),
                ]),
              ),
              @lib.Instruction::drop(),
              @lib.Instruction::loop_(
                @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
                @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
              ),
              @lib.Instruction::i32_eqz(),
              @lib.Instruction::drop(),
              ..param_loop,
              ..trapping_loop,
              @lib.Instruction::return_(),
            ],
          ),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(
        cleaned,
        [..param_loop, ..trapping_loop, @lib.Instruction::return_()],
      )
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips dropped pure value ifs" {
  let pure_typeidx_if_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i64()])),
  )
  let param_typeidx_if_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let effectful_condition_if = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [@lib.Instruction::i32_const(@lib.I32(1))],
      Some([@lib.Instruction::i32_const(@lib.I32(2))]),
    ),
    @lib.Instruction::drop(),
  ]
  let effectful_condition_drop = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::drop(),
  ]
  let trapping_branch_if = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [@lib.Instruction::unreachable_()],
      Some([@lib.Instruction::i32_const(@lib.I32(3))]),
    ),
    @lib.Instruction::drop(),
  ]
  let param_if = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [@lib.Instruction::drop(), @lib.Instruction::i32_const(@lib.I32(5))],
      Some([@lib.Instruction::drop(), @lib.Instruction::i32_const(@lib.I32(6))]),
    ),
    @lib.Instruction::drop(),
  ]
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([pure_typeidx_if_type, param_typeidx_if_type]),
    )
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new(
            [
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::if_(
                @lib.BlockType::val_type(@lib.ValType::i32()),
                [
                  @lib.Instruction::i32_const(@lib.I32(40)),
                  @lib.Instruction::i32_const(@lib.I32(2)),
                  @lib.Instruction::i32_add(),
                ],
                Some([@lib.Instruction::i32_const(@lib.I32(7))]),
              ),
              @lib.Instruction::drop(),
              @lib.Instruction::i32_const(@lib.I32(0)),
              @lib.Instruction::if_(
                @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
                [@lib.Instruction::i64_const(@lib.I64(8L))],
                Some([@lib.Instruction::i64_const(@lib.I64(9L))]),
              ),
              @lib.Instruction::i64_eqz(),
              @lib.Instruction::drop(),
              ..effectful_condition_if,
              ..trapping_branch_if,
              ..param_if,
              @lib.Instruction::return_(),
            ],
          ),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(
        cleaned,
        [
          ..effectful_condition_drop,
          ..trapping_branch_if,
          ..param_if,
          @lib.Instruction::return_(),
        ],
      )
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips dropped pure value try_tables without catches" {
  let pure_typeidx_try_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let param_typeidx_try_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let caught_tag_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i64()], [])),
  )
  let param_try = [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::try_table(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [],
      @lib.Expr::new([
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(6)),
      ]),
    ),
    @lib.Instruction::drop(),
  ]
  let trapping_try = [
    @lib.Instruction::try_table(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [],
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::drop(),
  ]
  let caught_pure_try = @lib.Instruction::block(
    @lib.BlockType::val_type(@lib.ValType::i64()),
    @lib.Expr::new([
      @lib.Instruction::try_table(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(8))]),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::i64_const(@lib.I64(9L)),
    ]),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        pure_typeidx_try_type, param_typeidx_try_type, caught_tag_type,
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(2U))]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new(
            [
              @lib.Instruction::try_table(
                @lib.BlockType::val_type(@lib.ValType::i32()),
                [],
                @lib.Expr::new([
                  @lib.Instruction::i32_const(@lib.I32(40)),
                  @lib.Instruction::i32_const(@lib.I32(2)),
                  @lib.Instruction::i32_add(),
                ]),
              ),
              @lib.Instruction::drop(),
              @lib.Instruction::try_table(
                @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
                [],
                @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
              ),
              @lib.Instruction::i32_eqz(),
              @lib.Instruction::drop(),
              ..param_try,
              ..trapping_try,
              caught_pure_try,
              @lib.Instruction::drop(),
              @lib.Instruction::return_(),
            ],
          ),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(
        cleaned,
        [
          ..param_try,
          ..trapping_try,
          caught_pure_try,
          @lib.Instruction::drop(),
          @lib.Instruction::return_(),
        ],
      )
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae resolves flattened function type indexes inside rec groups" {
  let group_first = @lib.SubType::comp_type(
    @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i64()]),
  )
  let expected_params = [
    @lib.ValType::ref_type(
      @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::func())),
    ),
  ]
  let expected_results = [@lib.ValType::i32()]
  let group_second = @lib.SubType::comp_type(
    @lib.CompType::func(expected_params, expected_results),
  )
  let misleading_entry = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([], [@lib.ValType::f64(), @lib.ValType::i64()]),
    ),
  )
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::group([group_first, group_second]),
    misleading_entry,
  ])
  match dae_type_sec_func_type(type_sec, @lib.TypeIdx::new(1U)) {
    Some(@lib.FuncType(params, results)) => {
      assert_eq(params, expected_params)
      assert_eq(results, expected_results)
    }
    None => fail("expected flattened rec-group function type")
  }
}

///|
test "dae appends function types after flattened rec-group members" {
  let grouped = @lib.RecType::group([
    @lib.SubType::comp_type(@lib.CompType::struct_([])),
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i64()]),
    ),
  ])
  let single = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let (next, appended_idx) = dae_append_new_func_type(
    @lib.TypeSec::new([grouped, single]),
    [],
    [@lib.ValType::i32()],
  )
  assert_eq(appended_idx, @lib.TypeIdx::new(3U))
  match dae_type_sec_func_type(next, appended_idx) {
    Some(@lib.FuncType(params, results)) => {
      assert_eq(params, [])
      assert_eq(results, [@lib.ValType::i32()])
    }
    None => fail("expected appended flattened function type")
  }
}

///|
test "dae raw cleanup strips empty zero-result try_tables even with catches" {
  let param_void_typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let catching_empty_body = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [@lib.Catch::all(@lib.LabelIdx::new(0U))],
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(12)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let catching_trapping_body = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [@lib.Catch::all(@lib.LabelIdx::new(0U))],
        @lib.Expr::new([@lib.Instruction::unreachable_()]),
      ),
    ]),
  )
  let catching_param_body = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(13)),
      @lib.Instruction::try_table(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        [@lib.Catch::all(@lib.LabelIdx::new(0U))],
        @lib.Expr::new([]),
      ),
    ]),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([param_void_typeidx_block_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            catching_empty_body,
            catching_trapping_body,
            catching_param_body,
            @lib.Instruction::return_(),
          ]),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        catching_trapping_body,
        catching_param_body,
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae forwarded-cycle collection converges beyond the old eight-component limit" {
  let mut funcs = ""
  let mut pair = 0
  while pair < 9 {
    let first = pair * 2
    let second = first + 1
    funcs = funcs +
      "  (func $f\{first} (param i32) local.get 0 call $f\{second})\n" +
      "  (func $f\{second} (param i32) local.get 0 call $f\{first})\n"
    pair += 1
  }
  let mod_ = pass_test_module_from_wat("(module\n" + funcs + ")")
  let touched = Array::make(18, true)
  let cycle_batches = dae_collect_forwarded_param_cycle_batches(mod_, touched)
  assert_eq(cycle_batches.length(), 9)
  assert_eq(cycle_batches[0], [0, 1])
  assert_eq(cycle_batches[8], [16, 17])
}

///|
test "dae forwarded-cycle collection prioritizes explicitly selected definitions" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $early_a (param i32)
      #|    local.get 0
      #|    call $early_b)
      #|  (func $early_b (param i32)
      #|    local.get 0
      #|    call $early_a)
      #|  (func $selected_a (param i32)
      #|    local.get 0
      #|    call $selected_b)
      #|  (func $selected_b (param i32)
      #|    local.get 0
      #|    call $selected_a))
    ),
  )
  let touched = Array::make(4, true)
  let cycle_batches = dae_collect_forwarded_param_cycle_batches(
    mod_,
    touched,
    preferred_defs=[2, 3],
    limit=2,
  )
  @debug.assert_eq(cycle_batches, [[2, 3], [0, 1]])
}

///|
test "dae hot entry liveness distinguishes forwarded and overwritten incoming values" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func (export "run") (result i32)
      #|    i32.const 7
      #|    call $a)
      #|  (func $a (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 9
      #|    call $b)
      #|  (func $b (param i32 i32) (result i32)
      #|    i32.const 4
      #|    local.set 0
      #|    local.get 0
      #|    call $a))
    ),
  )
  assert_eq(dae_hot_param_entry_liveness(mod_, 1, 1), Some([true]))
  assert_eq(dae_hot_param_entry_liveness(mod_, 2, 2), Some([false, false]))
}

///|
test "dae hot entry liveness follows try-table exceptional exits" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (tag $e)
      #|  (func $target (param i32)
      #|    block $caught
      #|      try_table (catch $e $caught)
      #|        i32.const 9
      #|        local.set 0
      #|        throw $e
      #|      end
      #|    end
      #|    local.get 0
      #|    drop)
      #|  (func (export "run")
      #|    i32.const 7
      #|    call $target))
    ),
  )
  assert_eq(dae_hot_param_entry_liveness(mod_, 0, 1), Some([false]))
}

///|
test "dae current call facts record direct tail callees inside structured bodies" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func (export "run")
      #|    block
      #|      call $dropped
      #|      drop
      #|    end
      #|    i32.const 0
      #|    if
      #|      return_call $tail
      #|    end)
      #|  (func $dropped (result i32)
      #|    i32.const 1)
      #|  (func $tail))
    ),
  )
  let analysis = dae_collect_current_function_analysis(mod_, 3)
  let facts = analysis.call_facts
  assert_eq(facts.direct_calls, [0, 1, 1])
  assert_eq(facts.dropped_calls, [0, 1, 0])
  assert_eq(facts.direct_callers, [[], [0], [0]])
  assert_eq(facts.tail_calls, [false, false, true])
  let caller = analysis.function_infos[0]
  assert_true(caller.stale)
  assert_eq(caller.unused_params, [])
  assert_true(caller.has_tail_calls)
  assert_eq(caller.tail_callees, [2])
  assert_true(caller.has_unseen_calls)
  let dropped = analysis.function_infos[1]
  assert_eq(dropped.calls.length(), 1)
  assert_eq(dropped.dropped_calls.length(), 1)
  assert_eq(dropped.calls[0].caller_def, 0)
  assert_eq(dropped.calls[0].callee_abs, 1)
  assert_eq(dropped.calls[0].path, [0, 0, 0])
  assert_true(dropped.calls[0].active)
  assert_true(dropped.calls[0].dropped)
  assert_false(dropped.calls[0].tail)
  let tail = analysis.function_infos[2]
  assert_eq(tail.calls.length(), 1)
  assert_eq(tail.calls[0].path, [2, 2, 0])
  assert_true(tail.calls[0].tail)
}

///|
test "dae stable callsites ignore inactive conflicting uniform actuals" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target (param i32) (result i32)
      #|    local.get 0)
      #|  (func (export "run") (result i32)
      #|    i32.const 7
      #|    call $target
      #|    unreachable
      #|    i32.const 8
      #|    call $target))
    ),
  )
  let snapshot = dae_collect_module_boundary_snapshot(mod_)
  assert_eq(snapshot.function_infos[0].calls.length(), 2)
  assert_false(snapshot.function_infos[0].calls[1].active)
  let values = dae_collect_uniform_const_actuals_from_function_infos(
    mod_,
    0,
    1,
    snapshot.type_indices,
    snapshot.boundary_facts,
    snapshot.function_infos,
  )
  match values {
    Some([Some(@lib.I32Const(value))]) => assert_eq(value, 7)
    _ => fail("expected only the active stable callsite literal")
  }
}

///|
fn dae_scalar_rewrite_plan_fixture(
  tail_call? : Bool = false,
) -> (
  @lib.Module,
  DaeOriginalBoundarySnapshot,
  DaeCurrentBoundaryGraph,
  DaeRewritePlan,
) {
  let target_type = @lib.TypeIdx::new(0U)
  let caller_type = @lib.TypeIdx::new(1U)
  let replacement_type = @lib.TypeIdx::new(2U)
  let call_instr = if tail_call {
    @lib.Instruction::return_call(@lib.FuncIdx::new(0U))
  } else {
    @lib.Instruction::call(@lib.FuncIdx::new(0U))
  }
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([target_type, caller_type, caller_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(10)),
            @lib.Instruction::i32_const(@lib.I32(20)),
            call_instr,
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(9))]),
        ),
      ]),
    )
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let local_use = dae_local_use_for_callee(graph.snapshot.funcs[0], 2, 0, 2)
  let plan = dae_build_scalar_unused_param_rewrite_plan(
    mod_,
    original,
    graph,
    0,
    [true, false],
    local_use,
    1,
    [1],
  ).unwrap()
  ignore(replacement_type)
  (mod_, original, graph, plan)
}

///|
test "dae scalar rewrite plan commits caller callee type and touched transaction" {
  let (mod_, _, graph, plan) = dae_scalar_rewrite_plan_fixture()
  assert_eq(
    plan.type_section_rewrite.replacement_type_idx,
    @lib.TypeIdx::new(2U),
  )
  assert_eq(plan.expected_direct_call_count, 1)
  assert_eq(plan.expected_return_call_count, 0)
  assert_eq(plan.expected_call_identities.length(), 1)
  assert_eq(plan.expected_call_identities[0].caller_def, 1)
  assert_eq(plan.expected_call_identities[0].path, [2])
  assert_eq(plan.expected_call_identities[0].call_kind, DaeDirectCall)
  assert_eq(plan.caller_rewrites.length(), 1)
  assert_eq(plan.local_projection.preserved_removed_params, [false, false])
  match @validate.validate_module(plan.candidate) {
    Ok(_) => ()
    Err(err) =>
      fail("preconstructed scalar candidate must validate, got \{err}")
  }
  let application = dae_apply_rewrite_plan(mod_, graph, plan)
  assert_true(application.applied)
  assert_eq(dae_decision_reason_code(application.reason), "candidate-applied")
  assert_true(application.result.touched[0])
  assert_true(application.result.touched[1])
  assert_false(application.result.touched[2])
  assert_eq(application.effects.structurally_touched, [true, true, false])
  assert_eq(application.effects.worth_optimizing, [true, false, false])
  assert_eq(application.effects.parameter_changed, [true, false, false])
  assert_eq(application.effects.body_materialized, [false, false, false])
  assert_eq(application.effects.body_localized, [false, false, false])
  assert_true(application.effects.type_section_changed)
  assert_true(application.effects.metadata_changed)
  assert_eq(
    application.result.mod_out.pretty_print_func(@lib.FuncIdx::new(2U)),
    mod_.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
  let next_types = dae_collect_func_type_indices(application.result.mod_out)
  match dae_resolve_func_type(application.result.mod_out, next_types, 0) {
    Some(@lib.FuncType(params, results)) => {
      assert_eq(params, [@lib.ValType::i32()])
      assert_eq(results, [@lib.ValType::i32()])
    }
    None => fail("expected rewritten target signature")
  }
}

///|
test "dae scalar rewrite plan localizes nested call operands atomically" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $side (result i32)
      #|    i32.const 7)
      #|  (func $target (param i32)
      #|    nop)
      #|  (func (export "run")
      #|    call $side
      #|    call $target))
    ),
  )
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let local_use = dae_local_use_for_callee(graph.snapshot.funcs[1], 1, 1, 1)
  let plan = match
    dae_build_scalar_unused_param_rewrite_plan(
      mod_,
      original,
      graph,
      1,
      [true],
      local_use,
      1,
      [2],
    ) {
    Some(plan) => plan
    None => fail("expected localization-aware scalar rewrite plan")
  }
  assert_eq(plan.parameter_actions, [DaeLocalizeParameterAndRetry])
  assert_eq(plan.local_projection.preserved_removed_params, [true])
  match plan.candidate.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(callee_locals, _) = funcs[1]
      let @lib.Func(caller_locals, @lib.Expr(caller_body)) = funcs[2]
      assert_eq(callee_locals.length(), 1)
      assert_eq(caller_locals.length(), 1)
      assert_eq(caller_locals.get(0), @lib.ValType::i32())
      assert_eq(caller_body, [
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      ])
    }
    None => fail("expected candidate code section")
  }
  match @validate.validate_module(plan.candidate) {
    Ok(_) => ()
    Err(err) => fail("localized scalar candidate must validate, got \{err}")
  }
  let application = dae_apply_rewrite_plan(mod_, graph, plan)
  assert_true(application.applied)
  assert_true(application.result.touched[1])
  assert_true(application.result.touched[2])
  assert_eq(application.effects.worth_optimizing, [false, true, true])
  assert_eq(application.effects.parameter_changed, [false, true, false])
  assert_eq(application.effects.body_localized, [false, false, true])
  assert_eq(application.effects.local_projection_changed, [false, true, false])
}

///|
test "dae scalar rewrite plan materializes a uniform constant atomically" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target (param i32) (result i32)
      #|    local.get 0)
      #|  (func (export "run") (result i32)
      #|    i32.const 42
      #|    call $target))
    ),
  )
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let local_use = dae_local_use_for_callee(graph.snapshot.funcs[0], 1, 0, 1)
  let plan = match
    dae_build_scalar_unused_param_rewrite_plan(
      mod_,
      original,
      graph,
      0,
      [true],
      local_use,
      1,
      [1],
      materialized_params=Some([Some(@lib.Instruction::i32_const(@lib.I32(42)))]),
    ) {
    Some(plan) => plan
    None => fail("expected constant-materializing scalar rewrite plan")
  }
  assert_eq(plan.parameter_actions, [
    DaeMaterializeConstantParameter(@lib.Instruction::i32_const(@lib.I32(42))),
  ])
  assert_eq(
    plan.replacement_signature,
    @lib.FuncType::new([], [@lib.ValType::i32()]),
  )
  match plan.candidate.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(callee_body)) = funcs[0]
      let @lib.Func(_, @lib.Expr(caller_body)) = funcs[1]
      assert_eq(callee_body, [@lib.Instruction::i32_const(@lib.I32(42))])
      assert_eq(caller_body, [@lib.Instruction::call(@lib.FuncIdx::new(0U))])
    }
    None => fail("expected candidate code section")
  }
  let application = dae_apply_rewrite_plan(mod_, graph, plan)
  assert_true(application.applied)
  assert_eq(application.effects.worth_optimizing, [true, false])
  assert_eq(application.effects.parameter_changed, [true, false])
  assert_eq(application.effects.body_materialized, [true, false])
  assert_eq(application.effects.body_localized, [false, false])
}

///|
test "dae localized scalar candidate reaches a bounded common-core fixed point" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $s (struct))
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func $make (result (ref $s))
      #|    i32.const 1
      #|    global.set $g
      #|    struct.new_default $s)
      #|  (func $side (result i32)
      #|    i32.const 2
      #|    global.set $g
      #|    i32.const 7)
      #|  (func $target (param (ref $s) i32) (result i32)
      #|    local.get 0
      #|    ref.is_null)
      #|  (func (export "run") (result i32)
      #|    call $make
      #|    block (result i32)
      #|      call $side
      #|    end
      #|    call $target))
    ),
  )
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let mut current = mod_
  let productive_defs : Array[Int] = []
  for iteration = 0; iteration < 16; iteration = iteration + 1 {
    let call_counts = match current.code_sec {
      Some(@lib.CodeSec(funcs)) =>
        dae_collect_module_call_counts_anywhere(
          funcs,
          original.imported,
          original.defined,
        )
      None => Array::make(original.defined, 0)
    }
    let result = dae_run_core_once(
      current,
      [],
      call_counts,
      false,
      false,
      original,
      graph,
      expected_call_epoch=graph.call_epoch,
    )
    let application = dae_apply_core_result(current, [], false, result)
    if !application.applied {
      match @validate.validate_module(current) {
        Ok(_) => ()
        Err(err) => fail("fixed-point candidate must validate, got \{err}")
      }
      let final_types = dae_collect_func_type_indices(current)
      match dae_resolve_func_type(current, final_types, 2) {
        Some(@lib.FuncType(params, _)) => assert_eq(params.length(), 1)
        None => fail("expected final target signature")
      }
      return
    }
    productive_defs.push(application.primary_def)
    current = application.mod_out
    dae_current_boundary_graph_refresh(graph, current)
  }
  fail("localized common core did not converge; defs=\{productive_defs}")
}

///|
test "dae scalar rewrite plan rejects stale target and caller epochs" {
  let (mod_, _, signature_graph, signature_plan) = dae_scalar_rewrite_plan_fixture()
  signature_graph.function_epochs[0].signature_epoch += 1
  let signature_rejection = dae_apply_rewrite_plan(
    mod_, signature_graph, signature_plan,
  )
  assert_false(signature_rejection.applied)
  assert_eq(
    dae_decision_reason_code(signature_rejection.reason),
    "stale-candidate-facts",
  )

  let (mod_, _, body_graph, body_plan) = dae_scalar_rewrite_plan_fixture()
  body_graph.function_epochs[0].body_epoch += 1
  let body_rejection = dae_apply_rewrite_plan(mod_, body_graph, body_plan)
  assert_false(body_rejection.applied)
  assert_eq(
    dae_decision_reason_code(body_rejection.reason),
    "stale-candidate-facts",
  )

  let (mod_, _, caller_graph, caller_plan) = dae_scalar_rewrite_plan_fixture()
  caller_graph.function_epochs[1].body_epoch += 1
  let caller_rejection = dae_apply_rewrite_plan(mod_, caller_graph, caller_plan)
  assert_false(caller_rejection.applied)
  assert_eq(
    dae_decision_reason_code(caller_rejection.reason),
    "stale-candidate-facts",
  )

  let (mod_, _, type_graph, type_plan) = dae_scalar_rewrite_plan_fixture()
  type_graph.type_epoch += 1
  let type_rejection = dae_apply_rewrite_plan(mod_, type_graph, type_plan)
  assert_false(type_rejection.applied)
  assert_eq(
    dae_decision_reason_code(type_rejection.reason),
    "stale-candidate-facts",
  )
}

///|
test "dae scalar rewrite plan rejects stale calls and call composition" {
  let (mod_, _, call_graph, call_plan) = dae_scalar_rewrite_plan_fixture()
  call_graph.call_epoch += 1
  let call_rejection = dae_apply_rewrite_plan(mod_, call_graph, call_plan)
  assert_false(call_rejection.applied)
  assert_eq(
    dae_decision_reason_code(call_rejection.reason),
    "call-count-changed",
  )

  let (mod_, _, count_graph, count_plan) = dae_scalar_rewrite_plan_fixture()
  let @lib.Func(locals, @lib.Expr(body)) = count_graph.snapshot.funcs[1]
  let changed_body = body.copy()
  changed_body.insert(0, @lib.Instruction::i32_const(@lib.I32(30)))
  changed_body.insert(1, @lib.Instruction::i32_const(@lib.I32(40)))
  changed_body.insert(2, @lib.Instruction::call(@lib.FuncIdx::new(0U)))
  count_graph.snapshot.funcs[1] = @lib.Func::new(
    locals,
    @lib.Expr::new(changed_body),
  )
  let count_rejection = dae_apply_rewrite_plan(mod_, count_graph, count_plan)
  assert_false(count_rejection.applied)
  assert_eq(
    dae_decision_reason_code(count_rejection.reason),
    "call-count-changed",
  )

  let (mod_, _, tail_graph, tail_plan) = dae_scalar_rewrite_plan_fixture()
  tail_graph.snapshot.funcs[1] = match tail_graph.snapshot.funcs[1] {
    @lib.Func(locals, @lib.Expr(body)) => {
      let changed_body = body.copy()
      changed_body[changed_body.length() - 1] = @lib.Instruction::return_call(
        @lib.FuncIdx::new(0U),
      )
      @lib.Func::new(locals, @lib.Expr::new(changed_body))
    }
  }
  let tail_rejection = dae_apply_rewrite_plan(mod_, tail_graph, tail_plan)
  assert_false(tail_rejection.applied)
  assert_eq(
    dae_decision_reason_code(tail_rejection.reason),
    "call-count-changed",
  )
}

///|
test "dae scalar rewrite plan rejects moved call identities at equal counts" {
  let (mod_, _, _, plan) = dae_scalar_rewrite_plan_fixture()
  let moved = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let next = funcs.copy()
      let @lib.Func(locals, @lib.Expr(body)) = next[1]
      let shifted = body.copy()
      shifted.insert(0, @lib.Instruction::nop())
      next[1] = @lib.Func::new(locals, @lib.Expr::new(shifted))
      mod_.with_code_sec(@lib.CodeSec::new(next))
    }
    None => fail("expected code section")
  }
  let moved_graph = dae_current_boundary_graph_new(moved)
  let rejection = dae_apply_rewrite_plan(moved, moved_graph, plan)
  assert_false(rejection.applied)
  assert_eq(dae_decision_reason_code(rejection.reason), "call-count-changed")
  assert_eq(rejection.result.mod_out, moved)
}

///|
test "dae scalar rewrite plan rejects changed type resolution and invalid candidate" {
  let (mod_, _, graph, plan) = dae_scalar_rewrite_plan_fixture()
  let changed_type_mod = mod_.with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  let type_rejection = dae_apply_rewrite_plan(changed_type_mod, graph, plan)
  assert_false(type_rejection.applied)
  assert_eq(
    dae_decision_reason_code(type_rejection.reason),
    "type-reconstruction-unavailable",
  )

  let (mod_, _, graph, plan) = dae_scalar_rewrite_plan_fixture()
  let invalid_plan = dae_rewrite_plan_with_callee(
    plan,
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(99U))]),
    ),
  )
  let validation_rejection = dae_apply_rewrite_plan(mod_, graph, invalid_plan)
  assert_false(validation_rejection.applied)
  assert_eq(
    dae_decision_reason_code(validation_rejection.reason),
    "validation-rollback",
  )
  assert_eq(validation_rejection.result.mod_out, mod_)
}

///|
test "dae scalar rewrite plan records direct return_call composition" {
  let (mod_, _, graph, plan) = dae_scalar_rewrite_plan_fixture(tail_call=true)
  assert_eq(plan.expected_direct_call_count, 1)
  assert_eq(plan.expected_return_call_count, 1)
  assert_eq(plan.caller_rewrites[0].return_calls_rewritten, 1)
  let application = dae_apply_rewrite_plan(mod_, graph, plan)
  assert_true(application.applied)
}

///|
test "dae scalar rewrite plan appends missing type and preserves written removed slot" {
  let (base, _, _, _) = dae_scalar_rewrite_plan_fixture()
  let @lib.TypeSec(types) = base.type_sec.unwrap()
  let no_replacement_type = base
    .with_type_sec(@lib.TypeSec::new([types[0], types[1]]))
    .with_func_sec(
      @lib.FuncSec::new([
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(1U),
        @lib.TypeIdx::new(0U),
      ]),
    )
  let original = dae_collect_original_boundary_snapshot(no_replacement_type)
  let graph = dae_current_boundary_graph_new(no_replacement_type)
  let local_use = dae_local_use_for_callee(graph.snapshot.funcs[0], 2, 0, 2)
  let append_plan = dae_build_scalar_unused_param_rewrite_plan(
    no_replacement_type,
    original,
    graph,
    0,
    [true, false],
    local_use,
    1,
    [1],
  ).unwrap()
  assert_eq(
    dae_type_idx_slot(append_plan.type_section_rewrite.replacement_type_idx),
    Some(2),
  )
  assert_true(
    dae_apply_rewrite_plan(no_replacement_type, graph, append_plan).applied,
  )

  let written_mod = base.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(4)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        ]),
      ),
      graph.snapshot.funcs[1],
      graph.snapshot.funcs[2],
    ]),
  )
  let written_original = dae_collect_original_boundary_snapshot(written_mod)
  let written_graph = dae_current_boundary_graph_new(written_mod)
  let written_use = dae_local_use_for_callee(
    written_graph.snapshot.funcs[0],
    2,
    0,
    2,
  )
  let written_plan = dae_build_scalar_unused_param_rewrite_plan(
    written_mod,
    written_original,
    written_graph,
    0,
    [true, false],
    written_use,
    1,
    [1],
  ).unwrap()
  assert_eq(written_plan.local_projection.preserved_removed_params, [
    true, false,
  ])
  let written_application = dae_apply_rewrite_plan(
    written_mod, written_graph, written_plan,
  )
  assert_true(written_application.applied)
  match written_application.result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(locals, _) = funcs[0]
      assert_eq(locals.length(), 1)
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae scalar rewrite plan handles imports multiple callers and repeated calls" {
  let imported_type = @lib.TypeIdx::new(0U)
  let target_type = @lib.TypeIdx::new(1U)
  let caller_type = @lib.TypeIdx::new(2U)
  let replacement_type = @lib.TypeIdx::new(3U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("imp"),
          @lib.ExternType::func(imported_type),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([target_type, caller_type, caller_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::i32_const(@lib.I32(4)),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(5)),
            @lib.Instruction::i32_const(@lib.I32(6)),
            @lib.Instruction::return_call(@lib.FuncIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let local_use = dae_local_use_for_callee(graph.snapshot.funcs[0], 2, 1, 2)
  let plan = dae_build_scalar_unused_param_rewrite_plan(
    mod_,
    original,
    graph,
    1,
    [true, false],
    local_use,
    3,
    [1, 2],
  ).unwrap()
  assert_eq(plan.target_def, 0)
  assert_eq(plan.expected_direct_call_count, 3)
  assert_eq(plan.expected_return_call_count, 1)
  assert_eq(plan.caller_rewrites.length(), 2)
  assert_eq(plan.type_section_rewrite.replacement_type_idx, replacement_type)
  let application = dae_apply_rewrite_plan(mod_, graph, plan)
  assert_true(application.applied)
  assert_true(application.result.touched[0])
  assert_true(application.result.touched[1])
  assert_true(application.result.touched[2])
}

///|
test "dae exact unread-parameter candidate uses one current definition" {
  let (mod_, _, _, _) = dae_scalar_rewrite_plan_fixture()
  let facts = dae_collect_current_call_facts(
    mod_,
    dae_imported_func_count(mod_) + dae_defined_func_count(mod_),
  )
  let result = dae_try_rewrite_unread_params_for_def_with_facts(
    mod_,
    0,
    facts,
    allow_stack_carried_void_effects=true,
  )
  assert_true(result.changed)
  assert_eq(result.primary_def, 0)
  assert_true(result.touched[0])
  assert_true(result.touched[1])
}

///|
test "dae boundary dependency graph records callers callees and self edges" {
  let void_type = @lib.TypeIdx::new(0U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([void_type, void_type, void_type, void_type]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  let graph = dae_boundary_dependency_graph_new(
    dae_current_boundary_graph_new(mod_),
  )
  assert_eq(graph.callees_by_def, [[1, 2], [2], [2], []])
  assert_eq(graph.callers_by_def, [[], [0], [0, 1, 2], []])
  assert_eq(
    dae_boundary_dependency_invalidations(
      graph,
      graph,
      [false, true, false, false],
      1,
    ),
    [0, 1, 2],
  )
}

///|
test "dae dependency graph separates dropped observers from result forwarding" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target (result i32)
      #|    i32.const 7)
      #|  (func (export "dropped")
      #|    call $target
      #|    drop)
      #|  (func (export "observed") (result i32)
      #|    call $target)
      #|  (func (export "tail") (result i32)
      #|    return_call $target))
    ),
  )
  let graph = dae_boundary_dependency_graph_new(
    dae_current_boundary_graph_new(mod_),
  )
  assert_eq(graph.callers_by_def[0], [1, 2, 3])
  assert_eq(graph.result_observers_by_def[0], [2])
  assert_eq(graph.return_callers_by_def[0], [3])
  assert_eq(graph.tail_result_dependencies_by_def[0], [3])
  assert_eq(graph.result_forwarders_by_def[0], [2, 3])
}

///|
test "dae dependency invalidation follows producer-owned result domains" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target (result i32)
      #|    i32.const 7)
      #|  (func
      #|    call $target
      #|    drop)
      #|  (func (result i32)
      #|    call $target)
      #|  (func (result i32)
      #|    return_call $target))
    ),
  )
  let graph = dae_boundary_dependency_graph_new(
    dae_current_boundary_graph_new(mod_),
  )
  let base = dae_commit_effects_empty(4)
  let effects = { ..base, invalidation_domains: [DaeInvalidateResult] }
  assert_eq(
    dae_boundary_dependency_invalidations(
      graph,
      graph,
      [true, false, false, false],
      0,
      effects=Some(effects),
    ),
    [0, 2, 3],
  )
}

///|
test "dae dependency invalidation keeps metadata-only changes local" {
  let void_type = @lib.TypeIdx::new(0U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([void_type, void_type, void_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  let graph = dae_boundary_dependency_graph_new(
    dae_current_boundary_graph_new(mod_),
  )
  let base = dae_commit_effects_empty(3)
  let effects = { ..base, invalidation_domains: [DaeInvalidateMetadata] }
  assert_eq(
    dae_boundary_dependency_invalidations(
      graph,
      graph,
      [false, true, false],
      1,
      effects=Some(effects),
    ),
    [1],
  )
}

///|
test "dae work families publish narrow semantic invalidation domains" {
  assert_eq(dae_invalidation_domains_for_work_family(DaeUnusedParameterWork), [
    DaeInvalidateCalls,
    DaeInvalidateSignature,
    DaeInvalidateBody,
    DaeInvalidateLocals,
    DaeInvalidateTypes,
    DaeInvalidateMetadata,
    DaeInvalidateNestedCleanup,
  ])
  assert_eq(
    dae_invalidation_domains_for_work_family(DaeGcResultRefinementWork),
    [
      DaeInvalidateCalls,
      DaeInvalidateSignature,
      DaeInvalidateResult,
      DaeInvalidateBody,
      DaeInvalidateControl,
      DaeInvalidateTypes,
      DaeInvalidateMetadata,
      DaeInvalidateNestedCleanup,
    ],
  )
  assert_eq(dae_invalidation_domains_for_work_family(DaeDroppedResultWork), [
    DaeInvalidateCalls,
    DaeInvalidateSignature,
    DaeInvalidateResult,
    DaeInvalidateBody,
    DaeInvalidateControl,
    DaeInvalidateTypes,
    DaeInvalidateMetadata,
    DaeInvalidateNestedCleanup,
  ])
  assert_eq(
    dae_invalidation_domains_for_work_family(DaeControlReconstructionWork),
    [
      DaeInvalidateBody,
      DaeInvalidateControl,
      DaeInvalidateMetadata,
      DaeInvalidateNestedCleanup,
    ],
  )
}

///|
test "dae dependency graph distinguishes exact parameter forwarding from constant calls" {
  let unary = @lib.TypeIdx::new(0U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], []),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([unary, unary, unary]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::i32_const(7),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
          ]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  let graph = dae_boundary_dependency_graph_new(
    dae_current_boundary_graph_new(mod_),
  )
  assert_eq(graph.parameter_forwarders_by_def, [[], [0], []])
  assert_eq(graph.uniform_value_forwarders_by_def, [[], [0], [0]])
}

///|
test "dae parameter flow records exact reordered forwarding slots and tail composition" {
  let pair = @lib.TypeIdx::new(0U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i64()], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i64(), @lib.ValType::i32()], []),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([pair, @lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let current = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(current)
  assert_eq(dependencies.parameter_forwarding_edges.length(), 2)
  assert_eq(dependencies.parameter_forwarding_edges[0].caller_def, 1)
  assert_eq(dependencies.parameter_forwarding_edges[0].caller_param_idx, 1)
  assert_eq(dependencies.parameter_forwarding_edges[0].callee_def, 0)
  assert_eq(dependencies.parameter_forwarding_edges[0].callee_param_idx, 0)
  assert_true(dependencies.parameter_forwarding_edges[0].direct_tail)
  assert_eq(
    dependencies.parameter_forwarding_edges[0].source_type,
    @lib.ValType::i32(),
  )
  assert_eq(dependencies.parameter_forwarding_edges[1].caller_param_idx, 0)
  assert_eq(dependencies.parameter_forwarding_edges[1].callee_param_idx, 1)
  assert_true(dependencies.parameter_forwarding_edges[1].direct_tail)
  assert_eq(
    dependencies.parameter_forwarding_edges[1].source_type,
    @lib.ValType::i64(),
  )
  assert_eq(
    dependencies.parameter_forwarding_edges[0].caller_body_epoch,
    current.function_epochs[1].body_epoch,
  )
  assert_eq(
    dependencies.parameter_forwarding_edges[0].callee_signature_epoch,
    current.function_epochs[0].signature_epoch,
  )
}

///|
test "dae scalar parameter candidates do not defer cycles by module size" {
  for defined in [2, 1024, 4096] {
    assert_true(
      dae_should_run_scalar_parameter_candidate(
        defined,
        has_direct_caller_cycle=true,
      ),
    )
  }
}

///|
test "dae computed unread dependency worklist admission is module-size independent" {
  for defined in [2, 1024, 4096] {
    assert_true(
      dae_should_run_computed_unread_dependency_worklist(defined, optimize=true),
    )
    assert_false(
      dae_should_run_computed_unread_dependency_worklist(
        defined,
        optimize=false,
      ),
    )
  }
}

///|
test "dae forwarded constant revisit admission is module-size independent" {
  for defined in [2, 4096, 4097, 8192] {
    assert_true(dae_should_run_forwarded_constant_revisit(defined))
  }
}

///|
test "dae exact-uniform phase ownership is variant based, not module-size based" {
  for defined in [2, 1024, 1025, 4096] {
    assert_true(
      dae_should_run_broad_uniform_parameter_flow(defined, optimize=false),
    )
    assert_false(
      dae_should_run_reverse_exact_literal_phase(defined, optimize=false),
    )
    assert_false(
      dae_should_run_broad_uniform_parameter_flow(defined, optimize=true),
    )
    assert_true(
      dae_should_run_reverse_exact_literal_phase(defined, optimize=true),
    )
  }
}

///|
test "dae uniform collection admission is module-size independent and cycle aware" {
  for defined in [2, 1024, 4096] {
    assert_true(
      dae_should_collect_phase_local_uniform_constants(
        defined,
        optimize=true,
        allow_written_uniform_const=false,
        self_calls_anywhere=0,
        has_collect_const_param=true,
        has_direct_caller_cycle=false,
      ),
    )
    assert_false(
      dae_should_collect_phase_local_uniform_constants(
        defined,
        optimize=true,
        allow_written_uniform_const=false,
        self_calls_anywhere=0,
        has_collect_const_param=true,
        has_direct_caller_cycle=true,
      ),
    )
  }
}

///|
test "dae parameter flow lattice distinguishes unseen forwarded uniform conflict and blocked" {
  let facts : Array[DaeParameterFlowFact] = []
  let empty = { facts, }
  assert_eq(dae_parameter_flow_state_at(empty, 0, 0), DaeParameterUnseen)

  dae_parameter_flow_record(facts, 0, 0, DaeParameterUnseen)
  dae_parameter_flow_record(facts, 0, 0, DaeParameterForwardedOnly)
  assert_eq(
    dae_parameter_flow_state_at({ facts, }, 0, 0),
    DaeParameterForwardedOnly,
  )

  dae_parameter_flow_record(
    facts,
    0,
    0,
    DaeParameterUniform(@lib.Instruction::i32_const(@lib.I32(7))),
  )
  assert_eq(
    dae_parameter_flow_state_at({ facts, }, 0, 0),
    DaeParameterUniform(@lib.Instruction::i32_const(@lib.I32(7))),
  )
  dae_parameter_flow_record(
    facts,
    0,
    0,
    DaeParameterUniform(@lib.Instruction::i32_const(@lib.I32(9))),
  )
  assert_eq(dae_parameter_flow_state_at({ facts, }, 0, 0), DaeParameterConflict)
  dae_parameter_flow_record(facts, 0, 0, DaeParameterBlocked)
  assert_eq(dae_parameter_flow_state_at({ facts, }, 0, 0), DaeParameterBlocked)
}

///|
test "dae parameter flow solves reordered multi-parameter uniforms across a recursive component" {
  let source =
    #|(module
    #|  (func $a (param i32 i64)
    #|    local.get 0
    #|    local.get 1
    #|    call $b)
    #|  (func $b (param i32 i64)
    #|    local.get 0
    #|    local.get 1
    #|    call $a)
    #|  (func (export "run")
    #|    i32.const 7
    #|    i64.const 11
    #|    call $a))
  let mod_ = pass_test_module_from_wat(source)
  let current = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(current)
  let solution = dae_solve_parameter_flow(current, dependencies)
  match dae_parameter_flow_state_at(solution, 0, 0) {
    DaeParameterUniform(value) =>
      assert_eq(value, @lib.Instruction::i32_const(@lib.I32(7)))
    _ => fail("expected a.param0 to converge to i32.const 7")
  }
  match dae_parameter_flow_state_at(solution, 0, 1) {
    DaeParameterUniform(value) =>
      assert_eq(value, @lib.Instruction::i64_const(@lib.I64(11L)))
    _ => fail("expected a.param1 to converge to i64.const 11")
  }
  match dae_parameter_flow_state_at(solution, 1, 0) {
    DaeParameterUniform(value) =>
      assert_eq(value, @lib.Instruction::i32_const(@lib.I32(7)))
    _ => fail("expected b.param0 to converge through a.param0")
  }
  match dae_parameter_flow_state_at(solution, 1, 1) {
    DaeParameterUniform(value) =>
      assert_eq(value, @lib.Instruction::i64_const(@lib.I64(11L)))
    _ => fail("expected b.param1 to converge through a.param1")
  }
}

///|
test "dae uniform dispatcher consumes solved forwarding values" {
  let source =
    #|(module
    #|  (func $target (param i32) (result i32)
    #|    local.get 0)
    #|  (func $wrapper (param i32) (result i32)
    #|    local.get 0
    #|    call $target)
    #|  (func (export "run") (result i32)
    #|    i32.const 7
    #|    call $wrapper))
  let mod_ = pass_test_module_from_wat(source)
  let original = dae_collect_original_boundary_snapshot(mod_)
  let current = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(current)
  let solution = dae_solve_parameter_flow(current, dependencies)
  let value = match dae_parameter_flow_state_at(solution, 0, 0) {
    DaeParameterUniform(value) => value
    _ => fail("expected target uniform value through wrapper forwarding")
  }
  let item = {
    ..dae_work_item_new(current, dependencies, 0, DaeUniformActualWork),
    uniform_values: [Some(value)],
  }
  match
    dae_process_work_item(
      original,
      mod_,
      [],
      false,
      current,
      dependencies,
      item,
      dae_diagnostics_new(),
    ) {
    DaeWorkCommitted(application) => {
      let type_indices = dae_collect_func_type_indices(application.mod_out)
      match dae_resolve_func_type(application.mod_out, type_indices, 0) {
        Some(@lib.FuncType(params, [result])) => {
          assert_eq(params.length(), 0)
          assert_eq(result, @lib.ValType::i32())
        }
        _ => fail("expected nullary target after solved uniform dispatch")
      }
      match @validate.validate_module(application.mod_out) {
        Ok(_) => ()
        Err(err) => fail("expected valid solved uniform rewrite, got \{err}")
      }
    }
    _ => fail("expected solved uniform value to commit through dispatcher")
  }
}

///|
test "dae single-caller wave classification rejects mixed boundary changes" {
  let before = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $left (param i32 i32) (result i32)
      #|    local.get 0)
      #|  (func $right (param i32 i32) (result i32)
      #|    local.get 0)
      #|  (func (export "run") (param i32 i32) (result i32)
      #|    local.get 0
      #|    local.get 1
      #|    call $left
      #|    drop
      #|    local.get 0
      #|    local.get 1
      #|    call $right))
    ),
  )
  let single = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $left (param i32) (result i32)
      #|    local.get 0)
      #|  (func $right (param i32 i32) (result i32)
      #|    local.get 0)
      #|  (func (export "run") (param i32 i32) (result i32)
      #|    local.get 0
      #|    call $left
      #|    drop
      #|    local.get 0
      #|    local.get 1
      #|    call $right))
    ),
  )
  let mixed = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $left (param i32) (result i32)
      #|    local.get 0)
      #|  (func $right (param i32) (result i32)
      #|    local.get 0)
      #|  (func (export "run") (param i32 i32) (result i32)
      #|    local.get 0
      #|    call $left
      #|    drop
      #|    local.get 0
      #|    call $right))
    ),
  )
  assert_true(dae_modules_form_single_caller_param_wave(before, single))
  assert_false(dae_modules_form_single_caller_param_wave(before, mixed))
}

///|
test "dae core preserves a consumed single-caller throttle across cleanup reentry" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target (param i32 i32) (result i32)
      #|    local.get 0)
      #|  (func (export "run") (param i32 i32) (result i32)
      #|    local.get 0
      #|    local.get 1
      #|    call $target))
    ),
  )
  let result = dae_run_core(
    mod_,
    fn(_) { () },
    optimize=true,
    single_caller_throttle_consumed=true,
  )
  assert_true(result.single_caller_throttle_consumed)
  let type_indices = dae_collect_func_type_indices(result.mod_out)
  match dae_resolve_func_type(result.mod_out, type_indices, 0) {
    Some(@lib.FuncType(params, _)) => @debug.assert_eq(params.length(), 2)
    None => fail("expected target signature")
  }
}

///|
test "dae post-cleanup boundary revisit commits through dispatcher" {
  let (mod_, _, _, _) = dae_scalar_rewrite_plan_fixture()
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let item = dae_work_item_new(
    graph,
    dependencies,
    0,
    DaePostCleanupBoundaryRevisitWork,
  )
  match
    dae_process_work_item(
      original,
      mod_,
      [],
      false,
      graph,
      dependencies,
      item,
      dae_diagnostics_new(),
    ) {
    DaeWorkCommitted(application) => {
      assert_eq(application.primary_def, 0)
      match @validate.validate_module(application.mod_out) {
        Ok(_) => ()
        Err(err) => fail("expected valid post-cleanup revisit, got \{err}")
      }
    }
    _ => fail("expected post-cleanup boundary revisit to commit")
  }
}

///|
test "dae dropped-result work commits through dispatcher" {
  let source =
    #|(module
    #|  (func $target (result i32)
    #|    i32.const 7)
    #|  (func (export "run")
    #|    call $target
    #|    drop))
  let mod_ = pass_test_module_from_wat(source)
  let original = dae_collect_original_boundary_snapshot(mod_)
  let current = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(current)
  let item = dae_work_item_new(current, dependencies, 0, DaeDroppedResultWork)
  match
    dae_process_work_item(
      original,
      mod_,
      [],
      false,
      current,
      dependencies,
      item,
      dae_diagnostics_new(),
    ) {
    DaeWorkCommitted(application) => {
      let type_indices = dae_collect_func_type_indices(application.mod_out)
      match dae_resolve_func_type(application.mod_out, type_indices, 0) {
        Some(@lib.FuncType([], results)) => assert_eq(results.length(), 0)
        _ => fail("expected dropped result to be removed")
      }
      match @validate.validate_module(application.mod_out) {
        Ok(_) => ()
        Err(err) => fail("expected valid dropped-result dispatch, got \{err}")
      }
    }
    _ => fail("expected dropped-result work to commit")
  }
}

///|
test "dae GC parameter refinement work commits through dispatcher" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $target (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    struct.new_default $leaf
    #|    call $target))
  let mod_ = pass_test_module_from_wat(source)
  let original = dae_collect_original_boundary_snapshot(mod_)
  let current = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(current)
  let item = dae_work_item_new(
    current,
    dependencies,
    0,
    DaeGcParameterRefinementWork,
  )
  match
    dae_process_work_item(
      original,
      mod_,
      [],
      false,
      current,
      dependencies,
      item,
      dae_diagnostics_new(),
    ) {
    DaeWorkCommitted(application) => {
      let expected = @lib.ValType::ref_type(
        @lib.RefType::new(
          false,
          @lib.HeapType::new(@lib.TypeIdx::new(1U)),
          exact=true,
        ),
      )
      let type_indices = dae_collect_func_type_indices(application.mod_out)
      match dae_resolve_func_type(application.mod_out, type_indices, 0) {
        Some(@lib.FuncType([param], [result])) => {
          assert_eq(param, expected)
          assert_eq(result, @lib.ValType::i32())
        }
        _ => fail("expected exact GC parameter refinement")
      }
      match @validate.validate_module(application.mod_out) {
        Ok(_) => ()
        Err(err) => fail("expected valid GC parameter dispatch, got \{err}")
      }
    }
    _ => fail("expected GC parameter refinement work to commit")
  }
}

///|
test "dae GC parameter actual collection is shared and fail closed" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $target (param (ref null $base))
    #|    local.get 0
    #|    drop)
    #|  (func
    #|    struct.new_default $leaf
    #|    call $target)
    #|  (func
    #|    struct.new_default $leaf
    #|    call $target))
  let mod_ = pass_test_module_from_wat(source)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("expected code")
  }
  let type_indices = dae_collect_func_type_indices(mod_)
  let @lib.FuncType(params, _) = match
    dae_resolve_func_type(mod_, type_indices, 0) {
    Some(func_type) => func_type
    None => fail("expected target type")
  }
  let @lib.Func(locals, _) = funcs[0]
  let local_use = dae_local_use_for_callee(
    funcs[0],
    params.length() + locals.length(),
    0,
    params.length(),
  )
  let collection = dae_collect_gc_parameter_lub_actuals_for_callers(
    mod_,
    funcs,
    [1, 2],
    type_indices,
    0,
    0,
    params,
    local_use,
  )
  assert_true(collection.collect_ok)
  assert_eq(collection.calls_seen, 2)
  assert_eq(collection.rejected, [false])
  assert_eq(collection.candidates, [
    Some(
      @lib.ValType::ref_type(
        @lib.RefType::new(
          false,
          @lib.HeapType::new(@lib.TypeIdx::new(1U)),
          exact=true,
        ),
      ),
    ),
  ])
  let invalid = dae_collect_gc_parameter_lub_actuals_for_callers(
    mod_,
    funcs,
    [1, 99],
    type_indices,
    0,
    0,
    params,
    local_use,
  )
  assert_false(invalid.collect_ok)
}

///|
test "dae GC parameter LUB evidence is complete and fail closed" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func (param (ref null $base) i32)))
  let mod_ = pass_test_module_from_wat(source)
  let base = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  let evidence = dae_apply_gc_parameter_lub_evidence(
    mod_,
    [base, @lib.ValType::i32()],
    [Some(leaf), None],
    [false, false],
    2,
    2,
  )
  assert_true(evidence.complete)
  assert_true(evidence.changed)
  assert_eq(evidence.next_params, [leaf, @lib.ValType::i32()])
  assert_eq(evidence.refined_params, [true, false])
  let incomplete = dae_apply_gc_parameter_lub_evidence(
    mod_,
    [base, @lib.ValType::i32()],
    [Some(leaf), None],
    [false, false],
    1,
    2,
  )
  assert_false(incomplete.complete)
  assert_false(incomplete.changed)
  assert_eq(incomplete.next_params, [base, @lib.ValType::i32()])
  assert_eq(incomplete.refined_params, [false, false])
}

///|
test "dae GC parameter refinement repairs reused old-type parameters with a local" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $target (param (ref null $base)) (result i32)
    #|    ref.null $base
    #|    local.set 0
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    struct.new_default $leaf
    #|    call $target))
  let mod_ = pass_test_module_from_wat(source)
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let item = dae_work_item_new(
    graph,
    dependencies,
    0,
    DaeGcParameterRefinementWork,
  )
  match
    dae_process_work_item(
      dae_collect_original_boundary_snapshot(mod_),
      mod_,
      [],
      false,
      graph,
      dependencies,
      item,
      dae_diagnostics_new(),
    ) {
    DaeWorkCommitted(application) => {
      let type_indices = dae_collect_func_type_indices(application.mod_out)
      match dae_resolve_func_type(application.mod_out, type_indices, 0) {
        Some(@lib.FuncType([param], [result])) => {
          assert_eq(
            param,
            @lib.ValType::ref_type(
              @lib.RefType::new(
                false,
                @lib.HeapType::new(@lib.TypeIdx::new(1U)),
                exact=true,
              ),
            ),
          )
          assert_eq(result, @lib.ValType::i32())
        }
        _ => fail("expected refined reused parameter signature")
      }
      let funcs = match application.mod_out.code_sec {
        Some(@lib.CodeSec(funcs)) => funcs
        None => fail("expected rewritten code")
      }
      let @lib.Func(locals, @lib.Expr(body)) = funcs[0]
      assert_eq(locals.length(), 1)
      let local_runs = locals.runs()
      assert_eq(local_runs.length(), 1)
      assert_eq(local_runs[0].count(), 1U)
      assert_eq(
        local_runs[0].val_type(),
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
        ),
      )
      assert_eq(body[0], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
      assert_eq(body[1], @lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
      assert_eq(body[3], @lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
      assert_eq(body[4], @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
      match @validate.validate_module(application.mod_out) {
        Ok(_) => ()
        Err(err) => fail("expected valid reused parameter repair, got \{err}")
      }
    }
    _ => fail("expected reused GC parameter refinement to commit")
  }
}

///|
test "dae GC parameter refinement repairs nondefaultable reused parameter locals" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $target (param (ref $base)) (result i32)
    #|    struct.new_default $base
    #|    local.set 0
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    struct.new_default $leaf
    #|    call $target))
  let mod_ = pass_test_module_from_wat(source)
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  match
    dae_process_work_item(
      dae_collect_original_boundary_snapshot(mod_),
      mod_,
      [],
      false,
      graph,
      dependencies,
      dae_work_item_new(graph, dependencies, 0, DaeGcParameterRefinementWork),
      dae_diagnostics_new(),
    ) {
    DaeWorkCommitted(application) => {
      let funcs = match application.mod_out.code_sec {
        Some(@lib.CodeSec(funcs)) => funcs
        None => fail("expected rewritten code")
      }
      let @lib.Func(locals, @lib.Expr(body)) = funcs[0]
      let local_runs = locals.runs()
      assert_eq(local_runs.length(), 1)
      assert_eq(
        local_runs[0].val_type(),
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
        ),
      )
      assert_eq(body[0], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
      assert_eq(body[1], @lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
      assert_eq(body[4], @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
      assert_eq(body[5], @lib.Instruction::ref_as_non_null())
      match @validate.validate_module(application.mod_out) {
        Ok(_) => ()
        Err(err) => fail("expected valid nondefaultable fixup, got \{err}")
      }
    }
    _ => fail("expected nondefaultable reused GC parameter refinement")
  }
}

///|
test "dae core scalar localization reports producer-owned effects" {
  let source =
    #|(module
    #|  (import "m" "read" (func $read (result i32)))
    #|  (func $target (param i32)
    #|    nop)
    #|  (func (export "run")
    #|    call $read
    #|    call $target))
  let mod_ = pass_test_module_from_wat(source)
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("expected code section")
  }
  let effects_report : Array[DaeCommitEffects] = []
  let result = dae_run_core_once(
    mod_,
    Array::make(2, false),
    dae_collect_module_call_counts_anywhere(funcs, 1, 2),
    false,
    false,
    original,
    graph,
    max_def_exclusive=1,
    producer_effects_report=effects_report,
  )
  assert_true(result.changed)
  @debug.assert_eq(effects_report.length(), 1)
  assert_true(effects_report[0].worth_decided[0])
  assert_true(effects_report[0].worth_decided[1])
  assert_true(effects_report[0].parameter_changed[0])
  assert_true(effects_report[0].body_localized[1])
  assert_true(effects_report[0].worth_optimizing[0])
  assert_true(effects_report[0].worth_optimizing[1])
}

///|
test "dae scalar plan owns stack-carried void-effect localization" {
  let source =
    #|(module
    #|  (global $g (mut i32) (i32.const 0))
    #|  (func $target (param i32 i32) (result i32)
    #|    local.get 1)
    #|  (func (export "run") (result i32)
    #|    i32.const 1
    #|    i32.const 99
    #|    global.set $g
    #|    i32.const 7
    #|    call $target))
  let mod_ = pass_test_module_from_wat(source)
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("expected code section")
  }
  let local_use = dae_local_use_for_callee(funcs[0], 2, 0, 2)
  let application = dae_try_rewrite_scalar_unused_param_candidate(
    mod_,
    original,
    graph,
    0,
    [true, false],
    local_use,
    1,
    [1],
    allow_stack_carried_void_effects=true,
  )
  assert_true(application.applied)
  assert_true(application.effects.parameter_changed[0])
  assert_true(application.effects.body_localized[1])
  assert_true(application.effects.worth_optimizing[0])
  assert_true(application.effects.worth_optimizing[1])
  match @validate.validate_module(application.result.mod_out) {
    Ok(_) => ()
    Err(err) => fail("expected valid stack-carried scalar plan, got \{err}")
  }
}

///|
test "dae core GC parameter refinement reports producer-owned effects" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $target (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    struct.new_default $leaf
    #|    call $target))
  let mod_ = pass_test_module_from_wat(source)
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("expected code section")
  }
  let effects_report : Array[DaeCommitEffects] = []
  let result = dae_run_core_once(
    mod_,
    Array::make(2, false),
    dae_collect_module_call_counts_anywhere(funcs, 0, 2),
    false,
    false,
    original,
    graph,
    max_def_exclusive=1,
    producer_effects_report=effects_report,
  )
  assert_true(result.changed)
  @debug.assert_eq(effects_report.length(), 1)
  assert_true(effects_report[0].parameter_type_refined[0])
  assert_true(effects_report[0].worth_optimizing[0])
}

///|
test "dae core dropped-result removal reports producer-owned effects" {
  let source =
    #|(module
    #|  (func $target (result i32)
    #|    i32.const 7)
    #|  (func (export "run")
    #|    call $target
    #|    drop))
  let mod_ = pass_test_module_from_wat(source)
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("expected code section")
  }
  let effects_report : Array[DaeCommitEffects] = []
  let result = dae_run_core_once(
    mod_,
    Array::make(2, false),
    dae_collect_module_call_counts_anywhere(funcs, 0, 2),
    false,
    false,
    original,
    graph,
    max_def_exclusive=1,
    producer_effects_report=effects_report,
  )
  assert_true(result.changed)
  @debug.assert_eq(effects_report.length(), 1)
  assert_true(effects_report[0].worth_decided[0])
  assert_true(effects_report[0].worth_decided[1])
  assert_true(effects_report[0].result_removed[0])
  assert_true(effects_report[0].worth_optimizing[0])
  assert_true(effects_report[0].caller_drop_removed[1])
}

///|
test "dae core argument-side dropped-result repair reports producer-owned effects" {
  let source =
    #|(module
    #|  (import "m" "id" (func $id (param i32) (result i32)))
    #|  (func $target (param i32) (result i32)
    #|    local.get 0
    #|    call $id)
    #|  (func (export "run")
    #|    i32.const 7
    #|    call $target
    #|    drop))
  let mod_ = pass_test_module_from_wat(source)
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("expected code section")
  }
  let effects_report : Array[DaeCommitEffects] = []
  let result = dae_run_core_once(
    mod_,
    Array::make(2, false),
    dae_collect_module_call_counts_anywhere(funcs, 1, 3),
    false,
    false,
    original,
    graph,
    max_def_exclusive=1,
    producer_effects_report=effects_report,
  )
  assert_true(result.changed)
  @debug.assert_eq(effects_report.length(), 1)
  assert_true(effects_report[0].result_removed[0])
  assert_true(effects_report[0].caller_drop_removed[1])
}

///|
test "dae unread parameter batch is definition-count independent" {
  let source =
    #|(module
    #|  (func $target (param i32 i64) (result i64)
    #|    local.get 1)
    #|  (func (export "run") (result i64)
    #|    i32.const 7
    #|    i64.const 9
    #|    call $target))
  let mod_ = pass_test_module_from_wat(source)
  let result = dae_try_apply_unread_param_batch(mod_)
  assert_true(result.changed)
  let type_indices = dae_collect_func_type_indices(result.mod_out)
  match dae_resolve_func_type(result.mod_out, type_indices, 0) {
    Some(@lib.FuncType([param], [result_type])) => {
      assert_eq(param, @lib.ValType::i64())
      assert_eq(result_type, @lib.ValType::i64())
    }
    _ => fail("expected compact unread batch parameter removal")
  }
  match @validate.validate_module(result.mod_out) {
    Ok(_) => ()
    Err(err) => fail("expected valid compact unread batch, got \{err}")
  }
}

///|
test "dae dropped result batch is definition-count independent" {
  let source =
    #|(module
    #|  (func $target (result i32)
    #|    i32.const 7)
    #|  (func (export "run") (result i32)
    #|    call $target
    #|    drop
    #|    i32.const 9))
  let mod_ = pass_test_module_from_wat(source)
  let result = dae_try_apply_dropped_result_batch(mod_)
  assert_true(result.changed)
  let type_indices = dae_collect_func_type_indices(result.mod_out)
  match dae_resolve_func_type(result.mod_out, type_indices, 0) {
    Some(@lib.FuncType([], results)) => assert_eq(results.length(), 0)
    _ => fail("expected compact dropped-result batch removal")
  }
  match @validate.validate_module(result.mod_out) {
    Ok(_) => ()
    Err(err) => fail("expected valid compact dropped-result batch, got \{err}")
  }
}

///|
test "dae specialized uncalled result removal preserves exported boundary" {
  let source =
    #|(module
    #|  (func $target (export "target") (result i32)
    #|    unreachable))
  let mod_ = pass_test_module_from_wat(source)
  let result = dae_try_remove_uncalled_results(mod_, 0)
  assert_false(result.changed)
  assert_eq(result.mod_out, mod_)
}

///|
test "dae specialized result facts preserve ref.func and element exposure" {
  let ref_func_mod = pass_test_module_from_wat(
    (
      #|(module
      #|  (elem declare func $target)
      #|  (func $target (result i32)
      #|    unreachable)
      #|  (func (result funcref)
      #|    ref.func $target))
    ),
  )
  let ref_func_original = dae_collect_original_boundary_snapshot(ref_func_mod)
  let ref_func_graph = dae_current_boundary_graph_new(ref_func_mod)
  match dae_specialized_result_facts_new(ref_func_original, ref_func_graph, 0) {
    Some(facts) => {
      assert_false(facts.original_owned)
      assert_true(dae_specialized_result_facts_block_change(facts))
    }
    None => fail("expected ref.func specialized result facts")
  }

  let element_mod = pass_test_module_from_wat(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (elem (i32.const 0) func $target)
      #|  (func $target (result i32)
      #|    unreachable))
    ),
  )
  let element_original = dae_collect_original_boundary_snapshot(element_mod)
  let element_graph = dae_current_boundary_graph_new(element_mod)
  match dae_specialized_result_facts_new(element_original, element_graph, 0) {
    Some(facts) => {
      assert_false(facts.original_owned)
      assert_true(dae_specialized_result_facts_block_change(facts))
    }
    None => fail("expected element-exposed specialized result facts")
  }
}

///|
test "dae specialized dead suffix facts retain dead-chain observers" {
  let source =
    #|(module
    #|  (func $dead (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $dead
    #|    drop
    #|    f64.const 1)
    #|  (func (export "run")))
  let mod_ = pass_test_module_from_wat(source)
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let facts = match dae_specialized_result_facts_new(original, graph, 0) {
    Some(facts) => facts
    None => fail("expected dead-suffix specialized result facts")
  }
  assert_true(facts.original_owned)
  assert_eq(facts.result_observers, [])
  assert_false(facts.has_outgoing_tail)
  assert_false(facts.direct_tail_callee)
  assert_false(dae_specialized_result_facts_block_change(facts))
  let candidate = dae_try_remove_dead_self_suffix_result_with_facts(mod_, facts)
  assert_true(candidate.changed)
  let application = dae_apply_specialized_result_family_plan(
    mod_, graph, facts, candidate,
  )
  assert_true(application.applied)
  match @validate.validate_module(application.result.mod_out) {
    Ok(_) => ()
    Err(err) =>
      fail("expected valid specialized dead-chain candidate, got \{err}")
  }
}

///|
test "dae specialized result facts ignore unrelated tails and block target tails" {
  let unrelated = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target (result i32)
      #|    unreachable)
      #|  (func $tail_target)
      #|  (func
      #|    return_call $tail_target))
    ),
  )
  let unrelated_original = dae_collect_original_boundary_snapshot(unrelated)
  let unrelated_graph = dae_current_boundary_graph_new(unrelated)
  match
    dae_specialized_result_facts_new(unrelated_original, unrelated_graph, 0) {
    Some(facts) => {
      assert_false(facts.has_outgoing_tail)
      assert_false(facts.direct_tail_callee)
      assert_false(dae_specialized_result_facts_block_change(facts))
    }
    None => fail("expected unrelated-tail specialized result facts")
  }

  let target_tail = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target (result i32)
      #|    return_call $tail_target)
      #|  (func $tail_target (result i32)
      #|    i32.const 0))
    ),
  )
  let target_original = dae_collect_original_boundary_snapshot(target_tail)
  let target_graph = dae_current_boundary_graph_new(target_tail)
  match dae_specialized_result_facts_new(target_original, target_graph, 0) {
    Some(facts) => {
      assert_true(facts.has_outgoing_tail)
      assert_true(dae_specialized_result_facts_block_change(facts))
    }
    None => fail("expected target-tail specialized result facts")
  }
}

///|
test "dae specialized result family plan rejects stale identity and result epoch" {
  let source =
    #|(module
    #|  (func $dead (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $dead
    #|    drop
    #|    f64.const 1)
    #|  (func (export "run")))
  let mod_ = pass_test_module_from_wat(source)
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let facts = match dae_specialized_result_facts_new(original, graph, 0) {
    Some(facts) => facts
    None => fail("expected specialized result facts")
  }
  let candidate = dae_try_remove_dead_self_suffix_result_with_facts(mod_, facts)
  assert_true(candidate.changed)

  let stale_identity = {
    ..facts,
    active_call_identities: [
      { caller_def: 0, path: [99], call_kind: DaeDirectCall, callee_abs: 0 },
    ],
  }
  let identity_application = dae_apply_specialized_result_family_plan(
    mod_, graph, stale_identity, candidate,
  )
  assert_false(identity_application.applied)
  assert_eq(identity_application.result.mod_out, mod_)
  assert_eq(identity_application.reason, DaeStaleCandidateFacts)

  let stale_result = { ..facts, result_epoch: facts.result_epoch + 1 }
  let result_application = dae_apply_specialized_result_family_plan(
    mod_, graph, stale_result, candidate,
  )
  assert_false(result_application.applied)
  assert_eq(result_application.result.mod_out, mod_)
  assert_eq(result_application.reason, DaeStaleCandidateFacts)
}

///|
test "dae specialized result effects publish exact result invalidations" {
  let source =
    #|(module
    #|  (func $target (result i32)
    #|    unreachable)
    #|  (func
    #|    call $target
    #|    drop))
  let mod_ = pass_test_module_from_wat(source)
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let facts = match dae_specialized_result_facts_new(original, graph, 0) {
    Some(facts) => facts
    None => fail("expected specialized result facts")
  }
  let candidate = dae_try_remove_dropped_results(
    mod_,
    0,
    1,
    1,
    caller_defs=Some([1]),
  )
  assert_true(candidate.changed)
  let effects = dae_specialized_result_commit_effects(facts, candidate)
  assert_eq(effects.structurally_touched, candidate.touched)
  assert_true(effects.result_changed[0])
  assert_true(effects.result_removed[0])
  assert_true(effects.worth_optimizing[0])
  assert_true(effects.caller_drop_removed[1])
  assert_eq(effects.invalidation_domains, [
    DaeInvalidateCalls,
    DaeInvalidateSignature,
    DaeInvalidateResult,
    DaeInvalidateBody,
    DaeInvalidateControl,
    DaeInvalidateTypes,
    DaeInvalidateMetadata,
    DaeInvalidateNestedCleanup,
  ])
}

///|
test "dae dropped result batch ignores unrelated direct tails" {
  let source =
    #|(module
    #|  (func $target (result i32)
    #|    i32.const 7)
    #|  (func $tail_target)
    #|  (func (export "run")
    #|    call $target
    #|    drop)
    #|  (func (export "tail")
    #|    return_call $tail_target))
  let mod_ = pass_test_module_from_wat(source)
  let result = dae_try_apply_dropped_result_batch(mod_)
  assert_true(result.changed)
  let type_indices = dae_collect_func_type_indices(result.mod_out)
  match dae_resolve_func_type(result.mod_out, type_indices, 0) {
    Some(@lib.FuncType([], results)) => assert_eq(results.length(), 0)
    _ => fail("expected exact-target dropped-result batch removal")
  }
  match @validate.validate_module(result.mod_out) {
    Ok(_) => ()
    Err(err) =>
      fail("expected valid exact-target dropped-result batch, got \{err}")
  }
}

///|
test "dae direct GC batch is definition-count independent" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $target (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    struct.new_default $leaf
    #|    call $target))
  let mod_ = pass_test_module_from_wat(source)
  let result = dae_try_apply_direct_gc_batch(mod_)
  assert_true(result.changed)
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  let type_indices = dae_collect_func_type_indices(result.mod_out)
  match dae_resolve_func_type(result.mod_out, type_indices, 0) {
    Some(@lib.FuncType([param], [result_type])) => {
      assert_eq(param, expected)
      assert_eq(result_type, @lib.ValType::i32())
    }
    _ => fail("expected compact direct-GC batch refinement")
  }
  match @validate.validate_module(result.mod_out) {
    Ok(_) => ()
    Err(err) => fail("expected valid compact direct-GC batch, got \{err}")
  }
}

///|
test "dae direct GC batch repairs reused parameter locals" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $target (param (ref null $base)) (result i32)
    #|    ref.null $base
    #|    local.set 0
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    struct.new_default $leaf
    #|    call $target))
  let result = dae_try_apply_direct_gc_batch(pass_test_module_from_wat(source))
  assert_true(result.changed)
  let funcs = match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("expected rewritten batch code")
  }
  let @lib.Func(locals, @lib.Expr(body)) = funcs[0]
  assert_eq(locals.length(), 1)
  assert_eq(body[0], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  assert_eq(body[1], @lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
  assert_eq(body[3], @lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
  assert_eq(body[4], @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  match @validate.validate_module(result.mod_out) {
    Ok(_) => ()
    Err(err) => fail("expected valid reused direct-GC batch, got \{err}")
  }
}

///|
test "dae direct GC batch transaction retains original escaped ownership" {
  let escaped_source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (table 1 funcref)
    #|  (elem (i32.const 0) func $target)
    #|  (func $target (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    struct.new_default $leaf
    #|    call $target))
  let current_source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $target (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    struct.new_default $leaf
    #|    call $target))
  let escaped = pass_test_module_from_wat(escaped_source)
  let current_mod = pass_test_module_from_wat(current_source)
  let application = dae_apply_direct_gc_batch_transaction(
    dae_collect_original_boundary_snapshot(escaped),
    current_mod,
    [],
    false,
  )
  assert_false(application.applied)
  assert_eq(application.mod_out, current_mod)
}

///|
test "dae GC refinement dispatcher honors original escaped ownership" {
  let escaped_source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (table 1 funcref)
    #|  (elem (i32.const 0) func $target)
    #|  (func $target (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    struct.new_default $leaf
    #|    call $target))
  let current_source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $target (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    struct.new_default $leaf
    #|    call $target))
  let escaped = pass_test_module_from_wat(escaped_source)
  let current_mod = pass_test_module_from_wat(current_source)
  let original = dae_collect_original_boundary_snapshot(escaped)
  let graph = dae_current_boundary_graph_new(current_mod)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let item = dae_work_item_new(
    graph,
    dependencies,
    0,
    DaeGcParameterRefinementWork,
  )
  match
    dae_process_work_item(
      original,
      current_mod,
      [],
      false,
      graph,
      dependencies,
      item,
      dae_diagnostics_new(),
    ) {
    DaeWorkCommitted(_) =>
      fail("expected original escaped GC boundary to reject transaction")
    _ => ()
  }
}

///|
test "dae GC result refinement work commits through dispatcher" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $target (result (ref null $base))
    #|    struct.new_default $leaf)
    #|  (func (export "run") (result i32)
    #|    call $target
    #|    ref.is_null))
  let mod_ = pass_test_module_from_wat(source)
  let original = dae_collect_original_boundary_snapshot(mod_)
  let current = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(current)
  for
    family in [
      DaeGcResultRefinementWork,
      DaeControlReconstructionWork,
      DaeTypeRepairRetryWork,
    ] {
    let item = dae_work_item_new(current, dependencies, 0, family)
    match
      dae_process_work_item(
        original,
        mod_,
        [],
        false,
        current,
        dependencies,
        item,
        dae_diagnostics_new(),
      ) {
      DaeWorkCommitted(application) => {
        let expected = @lib.ValType::ref_type(
          @lib.RefType::new(
            false,
            @lib.HeapType::new(@lib.TypeIdx::new(1U)),
            exact=true,
          ),
        )
        let type_indices = dae_collect_func_type_indices(application.mod_out)
        match dae_resolve_func_type(application.mod_out, type_indices, 0) {
          Some(@lib.FuncType([], [result])) => assert_eq(result, expected)
          _ => fail("expected exact GC result refinement")
        }
        match @validate.validate_module(application.mod_out) {
          Ok(_) => ()
          Err(err) => fail("expected valid GC result dispatch, got \{err}")
        }
      }
      _ => fail("expected result/control/type refinement work to commit")
    }
  }
}

///|
test "dae GC result refinement joins multiple explicit returns and fallthrough" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $target (result (ref null $base))
    #|    (local $temp (ref null $base))
    #|    (local $leaf (ref null $leaf))
    #|    call $target
    #|    local.set $temp
    #|    i32.const 1
    #|    if
    #|      local.get $leaf
    #|      return
    #|    end
    #|    i32.const 2
    #|    if
    #|      local.get $leaf
    #|      return
    #|    end
    #|    local.get $leaf)
    #|  (func (export "run") (result i32)
    #|    call $target
    #|    ref.is_null))
  let mod_ = pass_test_module_from_wat(source)
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let item = dae_work_item_new(
    graph,
    dependencies,
    0,
    DaeGcResultRefinementWork,
  )
  match
    dae_process_work_item(
      dae_collect_original_boundary_snapshot(mod_),
      mod_,
      [],
      false,
      graph,
      dependencies,
      item,
      dae_diagnostics_new(),
    ) {
    DaeWorkCommitted(application) => {
      let expected = @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
      )
      let type_indices = dae_collect_func_type_indices(application.mod_out)
      match dae_resolve_func_type(application.mod_out, type_indices, 0) {
        Some(@lib.FuncType([], [result])) => assert_eq(result, expected)
        _ => fail("expected joined explicit-return GC result refinement")
      }
      match @validate.validate_module(application.mod_out) {
        Ok(_) => ()
        Err(err) => fail("expected valid joined result refinement, got \{err}")
      }
    }
    _ => fail("expected multiple-return GC result work to commit")
  }
}

///|
test "dae GC result refinement joins null-bottom explicit returns" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $target (result (ref null $base))
    #|    (local $leaf (ref null $leaf))
    #|    i32.const 1
    #|    if
    #|      ref.null none
    #|      return
    #|    end
    #|    local.get $leaf)
    #|  (func (export "run") (result i32)
    #|    call $target
    #|    ref.is_null))
  let mod_ = pass_test_module_from_wat(source)
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  match
    dae_process_work_item(
      dae_collect_original_boundary_snapshot(mod_),
      mod_,
      [],
      false,
      graph,
      dependencies,
      dae_work_item_new(graph, dependencies, 0, DaeGcResultRefinementWork),
      dae_diagnostics_new(),
    ) {
    DaeWorkCommitted(application) => {
      let expected = @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
      )
      let type_indices = dae_collect_func_type_indices(application.mod_out)
      match dae_resolve_func_type(application.mod_out, type_indices, 0) {
        Some(@lib.FuncType([], [result])) => assert_eq(result, expected)
        _ => fail("expected nullable leaf result refinement")
      }
      match @validate.validate_module(application.mod_out) {
        Ok(_) => ()
        Err(err) => fail("expected valid null-bottom result refinement: \{err}")
      }
    }
    _ => fail("expected null-bottom explicit-return GC result work to commit")
  }
}

///|
test "dae GC result refinement joins abstract heap returns" {
  let source =
    #|(module
    #|  (func $target (result (ref null any))
    #|    (local $temp (ref null any))
    #|    (local $i31 (ref null i31))
    #|    call $target
    #|    local.set $temp
    #|    i32.const 1
    #|    if
    #|      local.get $i31
    #|      return
    #|    end
    #|    local.get $i31)
    #|  (func (export "run") (result i32)
    #|    call $target
    #|    ref.is_null))
  let mod_ = pass_test_module_from_wat(source)
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  match
    dae_process_work_item(
      dae_collect_original_boundary_snapshot(mod_),
      mod_,
      [],
      false,
      graph,
      dependencies,
      dae_work_item_new(graph, dependencies, 0, DaeGcResultRefinementWork),
      dae_diagnostics_new(),
    ) {
    DaeWorkCommitted(application) => {
      let expected = @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::i31())),
      )
      let type_indices = dae_collect_func_type_indices(application.mod_out)
      match dae_resolve_func_type(application.mod_out, type_indices, 0) {
        Some(@lib.FuncType([], [result])) => assert_eq(result, expected)
        _ => fail("expected abstract i31 result refinement")
      }
      match @validate.validate_module(application.mod_out) {
        Ok(_) => ()
        Err(err) =>
          fail("expected valid abstract result refinement, got \{err}")
      }
    }
    _ => fail("expected abstract multiple-return GC result work to commit")
  }
  let encoded = match @binary.encode_module(mod_) {
    Ok(bytes) => bytes
    Err(err) => fail("expected abstract return fixture encode, got \{err}")
  }
  let decoded = match @binary.decode_module(encoded) {
    Ok(decoded) => decoded
    Err(err) => fail("expected abstract return fixture decode, got \{err}")
  }
  let core = dae_run_core(decoded, fn(_) { () })
  let core_type_indices = dae_collect_func_type_indices(core.mod_out)
  match dae_resolve_func_type(core.mod_out, core_type_indices, 0) {
    Some(@lib.FuncType([], [result])) =>
      assert_eq(
        result,
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::i31())),
        ),
      )
    _ => fail("expected production core abstract result refinement")
  }
}

///|
test "dae GC result refinement follows direct tail calls" {
  let mod_ = match
    @binary.decode_module(
      Bytes::from_array([
        0, 97, 115, 109, 1, 0, 0, 0, 1, 24, 5, 80, 0, 95, 0, 80, 1, 0, 95, 0, 96,
        0, 1, 99, 1, 96, 0, 1, 99, 0, 96, 0, 1, 127, 3, 4, 3, 2, 3, 4, 7, 7, 1, 3,
        114, 117, 110, 0, 2, 10, 16, 3, 3, 0, 0, 11, 4, 0, 18, 0, 11, 5, 0, 16, 1,
        209, 11,
      ]),
    ) {
    Ok(decoded) => decoded
    Err(err) => fail("expected tail result fixture decode, got \{err}")
  }
  let result = dae_run_core(mod_, fn(_) { () })
  let type_indices = dae_collect_func_type_indices(result.mod_out)
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  match dae_resolve_func_type(result.mod_out, type_indices, 1) {
    Some(@lib.FuncType([], [actual])) => assert_eq(actual, expected)
    _ => fail("expected refined direct tail caller")
  }
  let old_type = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  for
    instr in [
      @lib.Instruction::return_call_indirect(
        @lib.TypeIdx::new(2U),
        @lib.TableIdx::new(0U),
      ),
      @lib.Instruction::return_call_ref(@lib.TypeIdx::new(2U)),
    ] {
    match
      dae_direct_gc_result_candidate_instr(
        mod_,
        type_indices,
        None,
        instr,
        old_type,
      ) {
      Some((actual, None)) => assert_eq(actual, expected)
      _ => fail("expected typed tail result evidence")
    }
  }
  match @validate.validate_module(result.mod_out) {
    Ok(_) => ()
    Err(err) => fail("expected valid tail result refinement, got \{err}")
  }
}

///|
test "dae GC result refinement derives exact ref.func return types" {
  let source =
    #|(module
    #|  (type $sig (func (result funcref)))
    #|  (elem declare func $escaped)
    #|  (func $escaped (type $sig) (result funcref)
    #|    ref.null func)
    #|  (func $producer (result funcref)
    #|    ref.func $escaped)
    #|  (func (export "run") (result funcref)
    #|    call $producer))
  let parsed = pass_test_module_from_wat(source)
  let encoded = match @binary.encode_module(parsed) {
    Ok(bytes) => bytes
    Err(err) => fail("expected ref.func result fixture encode, got \{err}")
  }
  let mod_ = match @binary.decode_module(encoded) {
    Ok(decoded) => decoded
    Err(err) => fail("expected ref.func result fixture decode, got \{err}")
  }
  let result = dae_run_core(mod_, fn(_) { () })
  let type_indices = dae_collect_func_type_indices(result.mod_out)
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      exact=true,
    ),
  )
  match dae_resolve_func_type(result.mod_out, type_indices, 1) {
    Some(@lib.FuncType([], [actual])) => assert_eq(actual, expected)
    _ => fail("expected exact ref.func producer result")
  }
  match @validate.validate_module(result.mod_out) {
    Ok(_) => ()
    Err(err) => fail("expected valid exact ref.func result, got \{err}")
  }
}

///|
test "dae GC result refinement narrows one multivalue tuple lane" {
  let source =
    #|(module
    #|  (global $ref_sink (mut anyref) (ref.null any))
    #|  (global $i32_sink (mut i32) (i32.const 0))
    #|  (func $producer (result anyref i32)
    #|    (local $value i31ref)
    #|    local.get $value
    #|    i32.const 1)
    #|  (func (export "run")
    #|    call $producer
    #|    global.set $i32_sink
    #|    global.set $ref_sink))
  let parsed = pass_test_module_from_wat(source)
  let encoded = match @binary.encode_module(parsed) {
    Ok(bytes) => bytes
    Err(err) => fail("expected multivalue result fixture encode, got \{err}")
  }
  let mod_ = match @binary.decode_module(encoded) {
    Ok(decoded) => decoded
    Err(err) => fail("expected multivalue result fixture decode, got \{err}")
  }
  let result = dae_run_core(mod_, fn(_) { () })
  let type_indices = dae_collect_func_type_indices(result.mod_out)
  match dae_resolve_func_type(result.mod_out, type_indices, 0) {
    Some(@lib.FuncType(_, results)) => {
      assert_eq(results.length(), 2)
      assert_eq(results[0], @lib.ValType::i31ref_nullable())
      assert_eq(results[1], @lib.ValType::i32())
    }
    _ => fail("expected refined multivalue result signature")
  }
  match @validate.validate_module(result.mod_out) {
    Ok(_) => ()
    Err(err) => fail("expected valid refined multivalue result, got \{err}")
  }
}

///|
test "dae GC result refinement joins nullable explicit-return branches" {
  let source =
    #|(module
    #|  (type $struct (struct))
    #|  (global $sink (mut anyref) (ref.null any))
    #|  (func $producer (param i32 i32) (result anyref)
    #|    local.get 0
    #|    if (result anyref)
    #|      local.get 1
    #|      if (result anyref)
    #|        struct.new_default $struct
    #|      else
    #|        ref.null any
    #|      end
    #|    else
    #|      struct.new_default $struct
    #|    end)
    #|  (func (export "run")
    #|    i32.const 1
    #|    i32.const 1
    #|    call $producer
    #|    global.set $sink
    #|    i32.const 1
    #|    i32.const 0
    #|    call $producer
    #|    global.set $sink
    #|    i32.const 0
    #|    i32.const 0
    #|    call $producer
    #|    global.set $sink))
  let parsed = pass_test_module_from_wat(source)
  let encoded = match @binary.encode_module(parsed) {
    Ok(bytes) => bytes
    Err(err) => fail("expected nullable result fixture encode, got \{err}")
  }
  let mod_ = match @binary.decode_module(encoded) {
    Ok(decoded) => decoded
    Err(err) => fail("expected nullable result fixture decode, got \{err}")
  }
  let result = dae_run_core(mod_, fn(_) { () })
  let type_indices = dae_collect_func_type_indices(result.mod_out)
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(
      true,
      @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      exact=true,
    ),
  )
  match dae_resolve_func_type(result.mod_out, type_indices, 0) {
    Some(@lib.FuncType(_, results)) => {
      assert_eq(results.length(), 1)
      assert_eq(results[0], expected)
    }
    _ => fail("expected nullable joined result refinement")
  }
  match @validate.validate_module(result.mod_out) {
    Ok(_) => ()
    Err(err) => fail("expected valid nullable joined result, got \{err}")
  }
}

///|
test "dae GC parameter refinement derives exact ref.func actual types" {
  let source =
    #|(module
    #|  (type $sig (func))
    #|  (elem declare func $target $target2)
    #|  (global $sink (mut funcref) (ref.null func))
    #|  (func $target (type $sig))
    #|  (func $target2 (type $sig))
    #|  (func $callee (param funcref) (result i32)
    #|    local.get 0
    #|    global.set $sink
    #|    i32.const 0)
    #|  (func (export "run") (result i32)
    #|    ref.func $target
    #|    call $callee
    #|    drop
    #|    ref.func $target2
    #|    call $callee))
  let parsed = pass_test_module_from_wat(source)
  let encoded = match @binary.encode_module(parsed) {
    Ok(bytes) => bytes
    Err(err) => fail("expected ref.func actual fixture encode, got \{err}")
  }
  let mod_ = match @binary.decode_module(encoded) {
    Ok(decoded) => decoded
    Err(err) => fail("expected ref.func actual fixture decode, got \{err}")
  }
  let result = dae_run_core(mod_, fn(_) { () })
  let type_indices = dae_collect_func_type_indices(result.mod_out)
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      exact=true,
    ),
  )
  match dae_resolve_func_type(result.mod_out, type_indices, 2) {
    Some(@lib.FuncType(params, results)) => {
      assert_eq(params.length(), 1)
      assert_eq(results.length(), 1)
      assert_eq(params[0], expected)
      assert_eq(results[0], @lib.ValType::i32())
    }
    _ => fail("expected exact ref.func parameter refinement")
  }
  match @validate.validate_module(result.mod_out) {
    Ok(_) => ()
    Err(err) => fail("expected valid exact ref.func parameter, got \{err}")
  }
}

///|
test "dae GC result worklist traverses terminal dependencies beyond sixteen" {
  let function_count = 20
  let out = StringBuilder::new()
  out.write_string(
    (
      #|(module
      #|  (type $base (sub (struct)))
      #|  (type $leaf (sub $base (struct)))
      #|  (func $f0 (result (ref null $base))
      #|    struct.new_default $leaf)
    ),
  )
  let mut def_idx = 1
  while def_idx < function_count {
    out.write_string(
      "  (func $f\{def_idx} (result (ref null $base)) call $f\{def_idx - 1})\n",
    )
    def_idx += 1
  }
  out.write_string(
    "  (func (export \"run\") (result i32) call $f\{function_count - 1} ref.is_null))",
  )
  let mod_ = pass_test_module_from_wat(out.to_string())
  let application = dae_run_direct_gc_result_refinement_dependency_closure(
    mod_,
    [],
    false,
    [function_count - 1],
  )
  assert_eq(application.productive_defs.length(), function_count)
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  let type_indices = dae_collect_func_type_indices(application.mod_out)
  def_idx = 0
  while def_idx < function_count {
    match dae_resolve_func_type(application.mod_out, type_indices, def_idx) {
      Some(@lib.FuncType([], [result])) => assert_eq(result, expected)
      _ => fail("expected exact result at dependency definition \{def_idx}")
    }
    def_idx += 1
  }
  match @validate.validate_module(application.mod_out) {
    Ok(_) => ()
    Err(err) => fail("expected valid deep GC result worklist, got \{err}")
  }
}

///|
test "dae GC result worklist follows nested exact result dependencies" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $source (result (ref null $base))
    #|    struct.new_default $leaf)
    #|  (func $forward (result (ref null $base))
    #|    block (result (ref null $base))
    #|      call $source
    #|    end)
    #|  (func (export "run") (result i32)
    #|    call $forward
    #|    ref.is_null))
  let mod_ = pass_test_module_from_wat(source)
  let application = dae_run_direct_gc_result_refinement_dependency_closure(
    mod_,
    [],
    false,
    [1],
  )
  assert_eq(application.productive_defs, [0, 1])
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  let type_indices = dae_collect_func_type_indices(application.mod_out)
  for def_idx = 0; def_idx < 2; def_idx = def_idx + 1 {
    match dae_resolve_func_type(application.mod_out, type_indices, def_idx) {
      Some(@lib.FuncType([], [result])) => assert_eq(result, expected)
      _ =>
        fail("expected exact nested result at dependency definition \{def_idx}")
    }
  }
  match @validate.validate_module(application.mod_out) {
    Ok(_) => ()
    Err(err) => fail("expected valid nested GC result worklist, got \{err}")
  }
}

///|
test "dae uniform dispatcher carries immutable-global specialization policy" {
  let source =
    #|(module
    #|  (global $value i32 (i32.const 7))
    #|  (func $target (param i32) (result i32)
    #|    local.get 0)
    #|  (func (export "run") (result i32)
    #|    global.get $value
    #|    call $target))
  let mod_ = pass_test_module_from_wat(source)
  let original = dae_collect_original_boundary_snapshot(mod_)
  let current = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(current)
  let item = {
    ..dae_work_item_new(current, dependencies, 0, DaeUniformActualWork),
    allow_immutable_global_get: true,
  }
  match
    dae_process_work_item(
      original,
      mod_,
      [],
      false,
      current,
      dependencies,
      item,
      dae_diagnostics_new(),
    ) {
    DaeWorkCommitted(application) => {
      let type_indices = dae_collect_func_type_indices(application.mod_out)
      match dae_resolve_func_type(application.mod_out, type_indices, 0) {
        Some(@lib.FuncType(params, [result])) => {
          assert_eq(params.length(), 0)
          assert_eq(result, @lib.ValType::i32())
        }
        _ =>
          fail("expected immutable-global specialization to remove parameter")
      }
      match @validate.validate_module(application.mod_out) {
        Ok(_) => ()
        Err(err) => fail("expected valid immutable-global dispatch, got \{err}")
      }
    }
    _ => fail("expected immutable-global policy work item to commit")
  }
}

///|
test "dae general remove candidate rejects an element-exposed boundary" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (elem (i32.const 0) func $target)
      #|  (func $target (param i32) (result i32)
      #|    i32.const 1)
      #|  (func (export "run") (result i32)
      #|    i32.const 7
      #|    call $target))
    ),
  )
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("expected code section")
  }
  let local_use = dae_local_use_for_callee(funcs[0], 1, 0, 1)
  let result = dae_try_rewrite_candidate(
    mod_,
    0,
    [true],
    [None],
    local_use,
    1,
    [1],
  )
  assert_false(result.changed)
  assert_eq(result.mod_out, mod_)
}

///|
test "dae exact-literal transaction rejects original escaped ownership" {
  let escaped_source =
    #|(module
    #|  (table 1 funcref)
    #|  (elem (i32.const 0) func $target)
    #|  (func $target (param i32) (result i32)
    #|    local.get 0)
    #|  (func (export "run") (result i32)
    #|    i32.const 7
    #|    call $target))
  let current_source =
    #|(module
    #|  (func $target (param i32) (result i32)
    #|    local.get 0)
    #|  (func (export "run") (result i32)
    #|    i32.const 7
    #|    call $target))
  let escaped = pass_test_module_from_wat(escaped_source)
  let current_mod = pass_test_module_from_wat(current_source)
  let original = dae_collect_original_boundary_snapshot(escaped)
  let graph = dae_current_boundary_graph_new(current_mod)
  let result = dae_try_rewrite_exact_literal_def_with_facts_once(
    current_mod,
    0,
    graph.snapshot.call_facts,
    original=Some(original),
    graph=Some(graph),
  )
  assert_false(result.changed)
  assert_eq(result.mod_out, current_mod)
}

///|
test "dae exact-literal family entry retains original escaped ownership" {
  let escaped = pass_test_module_from_wat(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (elem (i32.const 0) func $target)
      #|  (func $target (param i32) (result i32)
      #|    local.get 0)
      #|  (func (export "run") (result i32)
      #|    i32.const 7
      #|    call $target))
    ),
  )
  let current_mod = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target (param i32) (result i32)
      #|    local.get 0)
      #|  (func (export "run") (result i32)
      #|    i32.const 7
      #|    call $target))
    ),
  )
  let application = dae_apply_exact_literal_family_once(
    escaped,
    current_mod,
    0,
    [],
    false,
  )
  assert_false(application.applied)
  assert_eq(application.mod_out, current_mod)
}

///|
test "dae immediate-suffix transaction rejects original escaped ownership" {
  let escaped_source =
    #|(module
    #|  (table 1 funcref)
    #|  (elem (i32.const 0) func $target)
    #|  (func $side)
    #|  (func $target (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    i32.add)
    #|  (func (export "run") (result i32)
    #|    i32.const 5
    #|    call $side
    #|    i32.const 7
    #|    call $target))
  let current_source =
    #|(module
    #|  (func $side)
    #|  (func $target (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    i32.add)
    #|  (func (export "run") (result i32)
    #|    i32.const 5
    #|    call $side
    #|    i32.const 7
    #|    call $target))
  let escaped = pass_test_module_from_wat(escaped_source)
  let current_mod = pass_test_module_from_wat(current_source)
  let original = dae_collect_original_boundary_snapshot(escaped)
  let graph = dae_current_boundary_graph_new(current_mod)
  let result = dae_try_rewrite_exact_literal_def_with_facts_once(
    current_mod,
    1,
    graph.snapshot.call_facts,
    allow_immediate_i32_suffix_fallback=true,
    original=Some(original),
    graph=Some(graph),
  )
  assert_false(result.changed)
  assert_eq(result.mod_out, current_mod)
}

///|
test "dae direct immediate-suffix helper rejects an exposed boundary" {
  let source =
    #|(module
    #|  (table 1 funcref)
    #|  (elem (i32.const 0) func $target)
    #|  (func $target (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    i32.add)
    #|  (func (export "run") (result i32)
    #|    i32.const 5
    #|    i32.const 7
    #|    call $target))
  let mod_ = pass_test_module_from_wat(source)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("expected code section")
  }
  let local_use = dae_local_use_for_callee(funcs[0], 2, 0, 2)
  let result = dae_try_rewrite_verified_materialized_const_suffix_candidate(
    mod_,
    0,
    [@lib.ValType::i32(), @lib.ValType::i32()],
    [@lib.Instruction::i32_const(7)],
    local_use,
    1,
    [1],
  )
  assert_false(result.changed)
  assert_eq(result.mod_out, mod_)
}

///|
test "dae selected global suffix uses family plan and rejects original exposure" {
  let original_source =
    #|(module
    #|  (global $g i32 (i32.const 169472))
    #|  (table 1 funcref)
    #|  (elem (i32.const 0) func $callee)
    #|  (func $caller (param i32 i32 i32 i32 i32 i32 i32) (result i32)
    #|    nop
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    local.get 3
    #|    local.get 4
    #|    local.get 5
    #|    local.get 6
    #|    global.get $g
    #|    if (result i32)
    #|      i32.const 1
    #|    else
    #|      i32.const 2
    #|    end
    #|    i32.const 0
    #|    if
    #|      i32.const 0
    #|      call $release
    #|    end
    #|    i32.const 35864
    #|    call $callee)
    #|  (func $callee (param i32 i32 i32 i32 i32 i32 i32 i32 i32) (result i32)
    #|    local.get 7
    #|    local.get 8
    #|    i32.add)
    #|  (func $release (param i32)))
  let current_source =
    #|(module
    #|  (global $g i32 (i32.const 169472))
    #|  (func $caller (param i32 i32 i32 i32 i32 i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    local.get 3
    #|    local.get 4
    #|    local.get 5
    #|    local.get 6
    #|    global.get $g
    #|    if (result i32)
    #|      i32.const 1
    #|    else
    #|      i32.const 2
    #|    end
    #|    i32.const 0
    #|    if
    #|      i32.const 0
    #|      call $release
    #|    end
    #|    i32.const 35864
    #|    call $callee)
    #|  (func $callee (param i32 i32 i32 i32 i32 i32 i32 i32 i32) (result i32)
    #|    local.get 7
    #|    local.get 8
    #|    i32.add)
    #|  (func $release (param i32)))
  let exposed_original = pass_test_module_from_wat(original_source)
  let current = pass_test_module_from_wat(current_source)
  let owned_original = match current.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let original_funcs = funcs.copy()
      let @lib.Func(locals, @lib.Expr(body)) = original_funcs[0]
      original_funcs[0] = @lib.Func::new(
        locals,
        @lib.Expr::new([@lib.Instruction::nop()] + body),
      )
      current.with_code_sec(@lib.CodeSec::new(original_funcs))
    }
    None => fail("expected code section")
  }
  let effects_report : Array[DaeCommitEffects] = []
  let committed = dae_try_rewrite_selected_func323_global_suffix_once(
    owned_original,
    current,
    [false, true, false],
    fn(_) { () },
    producer_effects_report=effects_report,
  )
  assert_true(committed.changed)
  assert_eq(committed.primary_def, 1)
  assert_eq(committed.touched, [true, true, false])
  match effects_report.get(0) {
    Some(effects) => {
      assert_eq(effects.worth_optimizing, [true, true, false])
      assert_eq(effects.parameter_changed, [false, true, false])
      assert_eq(effects.body_materialized, [false, true, false])
      assert_false(effects.type_section_changed)
      assert_true(effects.invalidation_domains.contains(DaeInvalidateSignature))
    }
    None => fail("expected producer-owned global-suffix effects")
  }
  let rejected = dae_try_rewrite_selected_func323_global_suffix_once(
    exposed_original,
    current,
    [false, true, false],
    fn(_) { () },
  )
  assert_false(rejected.changed)
  assert_eq(rejected.mod_out, current)
}

///|
test "dae immediate-suffix materialization commits through scalar plan" {
  let source =
    #|(module
    #|  (func $side)
    #|  (func $target (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    i32.add)
    #|  (func (export "run") (result i32)
    #|    i32.const 5
    #|    call $side
    #|    i32.const 7
    #|    call $target))
  let mod_ = pass_test_module_from_wat(source)
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let result = dae_try_rewrite_exact_literal_def_with_facts_once(
    mod_,
    1,
    graph.snapshot.call_facts,
    allow_immediate_i32_suffix_fallback=true,
    original=Some(original),
    graph=Some(graph),
  )
  assert_true(result.changed)
  let type_indices = dae_collect_func_type_indices(result.mod_out)
  match dae_resolve_func_type(result.mod_out, type_indices, 1) {
    Some(@lib.FuncType([param], [result_type])) => {
      assert_eq(param, @lib.ValType::i32())
      assert_eq(result_type, @lib.ValType::i32())
    }
    _ => fail("expected suffix transaction to remove exactly one parameter")
  }
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(run_body)) = funcs[2]
      assert_eq(run_body, [
        @lib.Instruction::i32_const(5),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      ])
    }
    None => fail("expected rewritten code section")
  }
  match @validate.validate_module(result.mod_out) {
    Ok(_) => ()
    Err(err) => fail("expected valid suffix transaction, got \{err}")
  }
}

///|
test "dae uniform candidate worklist solves forwarded values before direct literal exposure" {
  let source =
    #|(module
    #|  (func $target (param i32) (result i32)
    #|    local.get 0)
    #|  (func $wrapper (param i32) (result i32)
    #|    local.get 0
    #|    call $target)
    #|  (func (export "run") (result i32)
    #|    i32.const 7
    #|    call $wrapper))
  let mod_ = pass_test_module_from_wat(source)
  let application = dae_run_exact_literal_candidate_worklist_with_facts(
    mod_,
    [],
    false,
    [0],
  )
  assert_eq(application.productive_defs, [0])
  let type_indices = dae_collect_func_type_indices(application.mod_out)
  match dae_resolve_func_type(application.mod_out, type_indices, 0) {
    Some(@lib.FuncType(params, [result])) => {
      assert_eq(params.length(), 0)
      assert_eq(result, @lib.ValType::i32())
    }
    _ => fail("expected candidate worklist to materialize solved target value")
  }
  match @validate.validate_module(application.mod_out) {
    Ok(_) => ()
    Err(err) => fail("expected valid solved worklist output, got \{err}")
  }
}

///|
test "dae boundary dependency graph assigns deterministic direct-call components" {
  let void_type = @lib.TypeIdx::new(0U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([
        void_type, void_type, void_type, void_type, void_type, void_type,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(3U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(4U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::return_call(@lib.FuncIdx::new(2U))]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  let graph = dae_boundary_dependency_graph_new(
    dae_current_boundary_graph_new(mod_),
  )
  assert_eq(graph.component_by_def, [0, 0, 1, 1, 1, 2])
  assert_eq(graph.component_members, [[0, 1], [2, 3, 4], [5]])
  assert_eq(graph.return_callers_by_def[2], [4])
}

///|
test "dae family worklist is epoch aware component ordered and duplicate resistant" {
  let void_type = @lib.TypeIdx::new(0U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([void_type, void_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  let boundary = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(boundary)
  let worklist = dae_boundary_worklist_families(boundary, dependencies, [
    DaeUnusedParameterWork,
    DaeUniformActualWork,
  ])
  let first = dae_boundary_worklist_take_item(worklist).unwrap()
  let second = dae_boundary_worklist_take_item(worklist).unwrap()
  assert_eq(first.target_def, 0)
  assert_eq(first.family, DaeUnusedParameterWork)
  assert_eq(second.target_def, 0)
  assert_eq(second.family, DaeUniformActualWork)
  assert_true(dae_work_item_epoch_is_current(boundary, first))
  while dae_boundary_worklist_take_item(worklist) is Some(_) {

  }
  assert_eq(dae_boundary_worklist_requeue_items(worklist, [first, first]), 1)
  assert_eq(dae_boundary_worklist_take_item(worklist), Some(first))
  assert_eq(dae_boundary_worklist_take_item(worklist), None)
  let changed = mod_.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          @lib.Instruction::nop(),
        ]),
      ),
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
    ]),
  )
  dae_current_boundary_graph_refresh(boundary, changed)
  assert_false(dae_work_item_epoch_is_current(boundary, first))
}

///|
test "dae GC commits schedule control reconstruction and type repair followups" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 0))",
  )
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let effects = dae_commit_effects_empty(1)
  effects.control_refinalization_required[0] = true
  let followups = dae_followup_work_items_for_commit(
    graph,
    dependencies,
    dae_work_item_new(graph, dependencies, 0, DaeGcResultRefinementWork),
    { ..effects, type_section_changed: true },
  )
  assert_eq(followups.length(), 2)
  assert_eq(followups[0].family, DaeControlReconstructionWork)
  assert_eq(followups[1].family, DaeTypeRepairRetryWork)
  assert_eq(followups[0].target_def, 0)
  assert_eq(followups[1].target_def, 0)
  let diagnostics = dae_diagnostics_new()
  let settled = dae_apply_commit_followups(
    dae_collect_original_boundary_snapshot(mod_),
    {
      mod_out: mod_,
      touched: [true],
      changed: true,
      applied: true,
      primary_def: 0,
      effects: { ..effects, type_section_changed: true },
    },
    dae_work_item_new(graph, dependencies, 0, DaeGcResultRefinementWork),
    diagnostics,
  )
  assert_eq(diagnostics.boundaries_analyzed, 2)
  assert_eq(settled.mod_out, mod_)
  assert_eq(
    dae_followup_work_items_for_commit(
      graph,
      dependencies,
      dae_work_item_new(graph, dependencies, 0, DaeControlReconstructionWork),
      { ..effects, type_section_changed: false },
    ),
    [],
  )
}

///|
fn dae_forwarded_component_plan_fixture() -> @lib.Module {
  let param_type = @lib.TypeIdx::new(0U)
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([param_type, param_type]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        ]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        ]),
      ),
    ]),
  )
}

///|
test "dae component rewrite plan validates and commits every forwarding member" {
  let mod_ = dae_forwarded_component_plan_fixture()
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let boundary_facts = graph.snapshot.boundary_facts
  let nodes = dae_collect_forwarded_param_component(
    mod_,
    [0, 1],
    graph.snapshot.type_indices,
    boundary_facts,
  )
  assert_eq(nodes.length(), 2)
  let plan = dae_build_forwarded_param_component_rewrite_plan(
    mod_,
    graph,
    dependencies,
    [],
    nodes,
    boundary_facts,
  ).unwrap()
  assert_eq(plan.member_defs, [0, 1])
  match dae_apply_component_rewrite_plan(mod_, graph, plan) {
    DaeComponentPlanCommitted(application) => {
      assert_eq(application.candidate.defs, [0, 1])
      assert_eq(application.candidate.param_count, 2)
      assert_eq(application.effects.structurally_touched, [true, true])
      assert_eq(application.effects.worth_optimizing, [true, true])
      assert_eq(application.effects.parameter_changed, [true, true])
      assert_eq(application.effects.body_materialized, [false, false])
      assert_eq(application.effects.body_localized, [false, false])
      match @validate.validate_module(application.candidate.mod_out) {
        Ok(_) => ()
        Err(err) => fail("expected valid component commit, got \{err}")
      }
    }
    _ => fail("expected atomic component commit")
  }
}

///|
test "dae component rewrite plan rejects stale member and rolls back all members" {
  let mod_ = dae_forwarded_component_plan_fixture()
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let boundary_facts = graph.snapshot.boundary_facts
  let nodes = dae_collect_forwarded_param_component(
    mod_,
    [0, 1],
    graph.snapshot.type_indices,
    boundary_facts,
  )
  let plan = dae_build_forwarded_param_component_rewrite_plan(
    mod_,
    graph,
    dependencies,
    [],
    nodes,
    boundary_facts,
  ).unwrap()
  graph.function_epochs[1].body_epoch += 1
  match dae_apply_component_rewrite_plan(mod_, graph, plan) {
    DaeComponentPlanRejected(unchanged, DaeStaleCandidateFacts) =>
      assert_eq(unchanged, mod_)
    _ => fail("expected stale component rollback")
  }
}

///|
test "dae component rewrite plan rejects a stale type epoch atomically" {
  let mod_ = dae_forwarded_component_plan_fixture()
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let boundary_facts = graph.snapshot.boundary_facts
  let nodes = dae_collect_forwarded_param_component(
    mod_,
    [0, 1],
    graph.snapshot.type_indices,
    boundary_facts,
  )
  let plan = dae_build_forwarded_param_component_rewrite_plan(
    mod_,
    graph,
    dependencies,
    [],
    nodes,
    boundary_facts,
  ).unwrap()
  graph.type_epoch += 1
  match dae_apply_component_rewrite_plan(mod_, graph, plan) {
    DaeComponentPlanRejected(unchanged, DaeStaleCandidateFacts) =>
      assert_eq(unchanged, mod_)
    _ => fail("expected stale component type epoch to roll back every member")
  }
}

///|
test "dae component rewrite plan rejects changed exact call identity" {
  let mod_ = dae_forwarded_component_plan_fixture()
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let boundary_facts = graph.snapshot.boundary_facts
  let nodes = dae_collect_forwarded_param_component(
    mod_,
    [0, 1],
    graph.snapshot.type_indices,
    boundary_facts,
  )
  let plan = dae_build_forwarded_param_component_rewrite_plan(
    mod_,
    graph,
    dependencies,
    [],
    nodes,
    boundary_facts,
  ).unwrap()
  let identities = plan.expected_call_identities.copy()
  assert_true(identities.length() > 0)
  identities[0] = { ..identities[0], path: [99] }
  let stale_plan = { ..plan, expected_call_identities: identities }
  match dae_apply_component_rewrite_plan(mod_, graph, stale_plan) {
    DaeComponentPlanRejected(unchanged, DaeCallCountChanged) =>
      assert_eq(unchanged, mod_)
    _ => fail("expected changed component call identity to roll back")
  }
}

///|
test "dae forwarding dispatcher honors original escaped ownership" {
  let escaped_source =
    #|(module
    #|  (table 1 funcref)
    #|  (elem (i32.const 0) func $a)
    #|  (func $a (param i32)
    #|    local.get 0
    #|    call $b)
    #|  (func $b (param i32)
    #|    local.get 0
    #|    call $a))
  let current_source =
    #|(module
    #|  (func $a (param i32)
    #|    local.get 0
    #|    call $b)
    #|  (func $b (param i32)
    #|    local.get 0
    #|    call $a))
  let escaped = pass_test_module_from_wat(escaped_source)
  let current = pass_test_module_from_wat(current_source)
  let original = dae_collect_original_boundary_snapshot(escaped)
  let graph = dae_current_boundary_graph_new(current)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let item = dae_work_item_new(graph, dependencies, 0, DaeForwardingWork)
  match
    dae_process_work_item(
      original,
      current,
      [],
      false,
      graph,
      dependencies,
      item,
      dae_diagnostics_new(),
    ) {
    DaeWorkCommitted(_) =>
      fail("expected original escaped ownership to reject the whole component")
    _ => ()
  }
}

///|
test "dae component rewrite plan validation failure restores the complete module" {
  let mod_ = dae_forwarded_component_plan_fixture()
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let boundary_facts = graph.snapshot.boundary_facts
  let nodes = dae_collect_forwarded_param_component(
    mod_,
    [0, 1],
    graph.snapshot.type_indices,
    boundary_facts,
  )
  let plan = dae_build_forwarded_param_component_rewrite_plan(
    mod_,
    graph,
    dependencies,
    [],
    nodes,
    boundary_facts,
  ).unwrap()
  let invalid_funcs = match plan.candidate.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.copy()
    None => []
  }
  invalid_funcs[0] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::i32_const(1)]),
  )
  let invalid_candidate = {
    ..plan.candidate,
    mod_out: plan.candidate.mod_out.with_code_sec(
      @lib.CodeSec::new(invalid_funcs),
    ),
  }
  let invalid_plan = { ..plan, candidate: invalid_candidate }
  match dae_apply_component_rewrite_plan(mod_, graph, invalid_plan) {
    DaeComponentPlanRejected(unchanged, DaeValidationRollback) =>
      assert_eq(unchanged, mod_)
    _ => fail("expected validation rollback for every component member")
  }
}

///|
test "dae family dispatcher commits uniform literal work" {
  let source =
    #|(module
    #|  (func $identity (param i32) (result i32)
    #|    local.get 0)
    #|  (func (export "run") (result i32)
    #|    i32.const 7
    #|    call $identity))
  let mod_ = pass_test_module_from_wat(source)
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let diagnostics = dae_diagnostics_new()
  let item = dae_work_item_new(graph, dependencies, 0, DaeUniformActualWork)
  match
    dae_process_work_item(
      original,
      mod_,
      [],
      false,
      graph,
      dependencies,
      item,
      diagnostics,
    ) {
    DaeWorkCommitted(application) => {
      assert_true(application.applied)
      assert_eq(application.primary_def, 0)
      let type_indices = dae_collect_func_type_indices(application.mod_out)
      match dae_resolve_func_type(application.mod_out, type_indices, 0) {
        Some(@lib.FuncType(params, [result])) => {
          assert_eq(params, [])
          assert_eq(result, @lib.ValType::i32())
        }
        _ => fail("expected rewritten nullary i32 identity")
      }
      match @validate.validate_module(application.mod_out) {
        Ok(_) => ()
        Err(err) => fail("expected valid uniform literal commit, got \{err}")
      }
    }
    _ => fail("expected uniform literal family to commit")
  }
  assert_eq(diagnostics.candidates_produced, 1)
  assert_eq(diagnostics.candidates_applied, 1)
  assert_eq(diagnostics.parameters_removed, 1)
  assert_eq(diagnostics.parameters_materialized, 1)
  assert_eq(dae_diagnostics_reason_count(diagnostics, DaeCandidateProduced), 1)
}

///|
test "dae forwarding component plan includes ref-null follow-up atomically" {
  let source =
    #|(module
    #|  (type $box (struct))
    #|  (func $a (param i32)
    #|    local.get 0
    #|    call $b
    #|    ref.null $box
    #|    call $target
    #|    drop)
    #|  (func $b (param i32)
    #|    local.get 0
    #|    call $a)
    #|  (func $target (param (ref null $box)) (result i32)
    #|    local.get 0
    #|    ref.is_null))
  let mod_ = pass_test_module_from_wat(source)
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let nodes = dae_collect_forwarded_param_component(
    mod_,
    [0, 1],
    graph.snapshot.type_indices,
    graph.snapshot.boundary_facts,
  )
  let plan = dae_build_forwarded_param_component_rewrite_plan(
    mod_,
    graph,
    dependencies,
    [],
    nodes,
    graph.snapshot.boundary_facts,
    original=Some(original),
  ).unwrap()
  assert_true(plan.candidate.touched[0])
  assert_true(plan.candidate.touched[1])
  assert_true(plan.candidate.touched[2])
  let candidate_types = dae_collect_func_type_indices(plan.candidate.mod_out)
  match dae_resolve_func_type(plan.candidate.mod_out, candidate_types, 2) {
    Some(@lib.FuncType([], [result])) => assert_eq(result, @lib.ValType::i32())
    _ => fail("expected ref-null follow-up inside component candidate")
  }
  match @validate.validate_module(plan.candidate.mod_out) {
    Ok(_) => ()
    Err(err) => fail("expected valid complete forwarding candidate, got \{err}")
  }
}

///|
test "dae forwarding family component includes exact one-way parameter forwarders" {
  let source =
    #|(module
    #|  (func $a (param i32 i32)
    #|    local.get 0
    #|    call $b)
    #|  (func $b (param i32)
    #|    local.get 0
    #|    i32.const 9
    #|    call $a)
    #|  (func $bridge (param i32)
    #|    local.get 0
    #|    i32.const 9
    #|    call $a))
  let mod_ = pass_test_module_from_wat(source)
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  assert_eq(dependencies.component_members, [[0, 1], [2]])
  assert_eq(dependencies.forwarding_component_by_def, [0, 0, 0])
  assert_eq(dependencies.forwarding_component_members, [[0, 1, 2]])
  let original = dae_collect_original_boundary_snapshot(mod_)
  let diagnostics = dae_diagnostics_new()
  let forwarding = dae_work_item_new(graph, dependencies, 0, DaeForwardingWork)
  match
    dae_process_work_item(
      original,
      mod_,
      [],
      false,
      graph,
      dependencies,
      forwarding,
      diagnostics,
    ) {
    DaeWorkCommitted(application) => {
      assert_true(application.touched[0])
      assert_true(application.touched[1])
      assert_true(application.touched[2])
      match @validate.validate_module(application.mod_out) {
        Ok(_) => ()
        Err(err) => fail("expected valid forwarding-family commit, got \{err}")
      }
    }
    _ => fail("expected exact forwarding-family component to commit")
  }
}

///|
test "dae family dispatcher commits a forwarding component atomically" {
  let mod_ = dae_forwarded_component_plan_fixture()
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let diagnostics = dae_diagnostics_new()
  let forwarding = dae_work_item_new(graph, dependencies, 0, DaeForwardingWork)
  match
    dae_process_work_item(
      original,
      mod_,
      [],
      false,
      graph,
      dependencies,
      forwarding,
      diagnostics,
    ) {
    DaeWorkCommitted(application) => {
      assert_true(application.applied)
      assert_true(application.changed)
      assert_eq(application.primary_def, 0)
      assert_true(application.touched[0])
      assert_true(application.touched[1])
      match @validate.validate_module(application.mod_out) {
        Ok(_) => ()
        Err(err) =>
          fail("expected valid forwarding dispatch commit, got \{err}")
      }
    }
    _ => fail("expected forwarding family to commit its complete component")
  }
  assert_eq(diagnostics.candidates_applied, 1)
}

///|
test "dae family dispatcher commits unread parameter work and terminates no-op families" {
  let (mod_, _, _, _) = dae_scalar_rewrite_plan_fixture()
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let diagnostics = dae_diagnostics_new()
  let unused = dae_work_item_new(graph, dependencies, 0, DaeUnusedParameterWork)
  match
    dae_process_work_item(
      original,
      mod_,
      [],
      false,
      graph,
      dependencies,
      unused,
      diagnostics,
    ) {
    DaeWorkCommitted(application) => {
      assert_true(application.applied)
      assert_eq(application.primary_def, 0)
    }
    _ => fail("expected unread parameter work to commit")
  }
  let deferred = dae_work_item_new(
    graph,
    dependencies,
    0,
    DaeControlReconstructionWork,
  )
  match
    dae_process_work_item(
      original,
      mod_,
      [],
      false,
      graph,
      dependencies,
      deferred,
      diagnostics,
    ) {
    DaeWorkNoChange(DaeNoStrictImprovement) => ()
    _ => fail("expected inapplicable control-reconstruction work to terminate")
  }
  assert_eq(diagnostics.boundaries_analyzed, 2)
  assert_eq(dae_diagnostics_reason_count(diagnostics, DaeCandidateApplied), 1)
  assert_eq(
    dae_diagnostics_reason_count(diagnostics, DaeNoStrictImprovement),
    1,
  )
}

///|
test "dae family dispatcher refreshes productive stale work and drops dead targets" {
  let (mod_, _, _, _) = dae_scalar_rewrite_plan_fixture()
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let diagnostics = dae_diagnostics_new()
  let stale = dae_work_item_new(
    graph,
    dependencies,
    0,
    DaeLocalizationRetryWork,
  )
  graph.module_epoch += 1
  match
    dae_process_work_item(
      original,
      mod_,
      [],
      false,
      graph,
      dependencies,
      stale,
      diagnostics,
    ) {
    DaeWorkRequeue(items) => {
      assert_eq(items.length(), 1)
      assert_eq(items[0].target_def, 0)
      assert_eq(items[0].family, DaeLocalizationRetryWork)
      assert_true(dae_work_item_epoch_is_current(graph, items[0]))
    }
    _ => fail("expected stale productive work to refresh")
  }
  let removed_target : DaeWorkItem = { ..stale, target_def: 99 }
  match
    dae_process_work_item(
      original,
      mod_,
      [],
      false,
      graph,
      dependencies,
      removed_target,
      diagnostics,
    ) {
    DaeWorkNoChange(DaeStaleCandidateFacts) => ()
    _ => fail("expected stale removed target to terminate")
  }
  assert_eq(diagnostics.candidate_stale_retries, 1)
  assert_eq(diagnostics.candidate_requeues, 1)
}

///|
test "dae boundary worklist requeues invalidated dependencies deterministically" {
  let worklist = dae_boundary_worklist_all(4)
  assert_eq(dae_boundary_worklist_take(worklist), Some(0))
  assert_eq(dae_boundary_worklist_requeue(worklist, [2, 0, 2, 3]), 1)
  assert_eq(dae_boundary_worklist_take(worklist), Some(1))
  assert_eq(dae_boundary_worklist_take(worklist), Some(2))
  assert_eq(dae_boundary_worklist_take(worklist), Some(3))
  assert_eq(dae_boundary_worklist_take(worklist), Some(0))
  assert_eq(dae_boundary_worklist_take(worklist), None)
}

///|
test "dae current boundary graph advances signature body and call epochs" {
  let void_type = @lib.TypeIdx::new(0U)
  let param_type = @lib.TypeIdx::new(1U)
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
  ])
  let original = @lib.Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(@lib.FuncSec::new([void_type, void_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  let graph = dae_current_boundary_graph_new(original)
  let def0_epoch = dae_boundary_candidate_epoch(graph, 0)
  let def1_epoch = dae_boundary_candidate_epoch(graph, 1)
  assert_true(dae_candidate_epoch_is_current(graph, def0_epoch))
  assert_true(dae_candidate_epoch_is_current(graph, def1_epoch))
  let changed = original
    .with_func_sec(@lib.FuncSec::new([param_type, void_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    )
  dae_current_boundary_graph_refresh(graph, changed)
  assert_eq(graph.module_epoch, 1)
  assert_eq(graph.call_epoch, 0)
  assert_eq(graph.function_epochs[0].signature_epoch, 1)
  assert_eq(graph.function_epochs[0].body_epoch, 0)
  assert_eq(graph.function_epochs[1].signature_epoch, 0)
  assert_eq(graph.function_epochs[1].body_epoch, 1)
  assert_false(dae_candidate_epoch_is_current(graph, def0_epoch))
  assert_false(dae_candidate_epoch_is_current(graph, def1_epoch))
  let before_call_epoch = dae_boundary_candidate_epoch(graph, 1)
  let before_call_boundary = graph.snapshot.boundary_facts
  let before_call_graph_epoch = graph.call_epoch
  let with_call = changed.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
      ),
    ]),
  )
  dae_current_boundary_graph_refresh(graph, with_call)
  assert_eq(graph.module_epoch, 2)
  assert_eq(graph.call_epoch, 1)
  assert_eq(graph.function_epochs[1].body_epoch, 2)
  assert_false(dae_candidate_epoch_is_current(graph, before_call_epoch))
  let refreshed_boundary = dae_boundary_facts_for_epoch(
    graph,
    before_call_graph_epoch,
    Some(before_call_boundary),
  )
  assert_eq(refreshed_boundary.direct_calls[0], 1)
}

///|
test "dae reason codes classify boundary visibility and tail surfaces" {
  let cases = [
    (DaePrivateDirectBoundary, "candidate-produced"),
    (DaeExportedBoundary, "exported-function"),
    (DaeImportedBoundary, "visible-boundary"),
    (DaeStartBoundary, "start-function"),
    (DaeRefFuncBoundary, "escaped-through-ref.func"),
    (DaeActiveElementBoundary, "active-element-table-exposure"),
    (DaePassiveElementBoundary, "passive-element-exposure"),
    (DaeUnknownIndirectBoundary, "unknown-indirect-caller"),
    (DaeUnknownCallRefBoundary, "unknown-call_ref-caller"),
    (DaeDirectReturnCallBoundary, "direct-tail-dependency"),
    (DaeIndirectReturnCallBoundary, "indirect-tail-dependency"),
    (DaeReferenceReturnCallBoundary, "reference-tail-dependency"),
  ]
  for case in cases {
    let (surface, expected) = case
    assert_eq(
      dae_decision_reason_code(dae_boundary_surface_reason(surface)),
      expected,
    )
  }
}

///|
test "dae reason codes classify operand preservation decisions" {
  let pure : DaeOperandDisposition = {
    start: 0,
    end: 1,
    droppable_without_repair: true,
    preserve_effects_on_removal: false,
    has_branch: false,
    has_effect_or_branch: false,
  }
  let effectful : DaeOperandDisposition = {
    start: 0,
    end: 1,
    droppable_without_repair: false,
    preserve_effects_on_removal: true,
    has_branch: false,
    has_effect_or_branch: true,
  }
  let branchful : DaeOperandDisposition = {
    start: 0,
    end: 1,
    droppable_without_repair: false,
    preserve_effects_on_removal: false,
    has_branch: true,
    has_effect_or_branch: true,
  }
  assert_eq(
    dae_decision_reason_code(dae_operand_decision_reason(pure, false, false)),
    "operand-directly-droppable",
  )
  assert_eq(
    dae_decision_reason_code(
      dae_operand_decision_reason(effectful, true, false),
    ),
    "operand-effects-must-be-replayed",
  )
  assert_eq(
    dae_decision_reason_code(
      dae_operand_decision_reason(effectful, false, true),
    ),
    "operand-may-trap",
  )
  assert_eq(
    dae_decision_reason_code(
      dae_operand_decision_reason(branchful, false, false),
    ),
    "operand-contains-escaping-control",
  )
}

///|
test "dae reason codes distinguish strict and non-strict GC refinement" {
  assert_eq(
    dae_decision_reason_code(dae_gc_refinement_decision_reason(true, true)),
    "candidate-applied",
  )
  assert_eq(
    dae_decision_reason_code(dae_gc_refinement_decision_reason(true, false)),
    "gc-refinement-not-strict",
  )
  assert_eq(
    dae_decision_reason_code(dae_gc_refinement_decision_reason(false, false)),
    "gc-lub-unavailable",
  )
}

///|
test "dae diagnostic counters aggregate stable reason events" {
  let diagnostics = dae_diagnostics_new()
  dae_diagnostics_record_reason(diagnostics, DaeCandidateApplied)
  dae_diagnostics_record_reason(diagnostics, DaeCandidateApplied)
  dae_diagnostics_record_reason(diagnostics, DaeValidationRollback)
  diagnostics.boundaries_analyzed += 3
  diagnostics.parameters_removed += 2
  dae_diagnostics_record_return_callsite_rewrite(diagnostics)
  assert_eq(diagnostics.boundaries_analyzed, 3)
  assert_eq(diagnostics.parameters_removed, 2)
  assert_eq(diagnostics.return_call_sites_rewritten, 1)
  assert_eq(dae_diagnostics_reason_count(diagnostics, DaeCandidateApplied), 2)
  assert_eq(dae_diagnostics_reason_count(diagnostics, DaeValidationRollback), 1)
}

///|
fn dae_wb_param_count(mod_ : @lib.Module, func_abs : Int) -> Int {
  let type_indices = dae_collect_func_type_indices(mod_)
  match dae_resolve_func_type(mod_, type_indices, func_abs) {
    Some(@lib.FuncType(params, _)) => params.length()
    None => -1
  }
}

///|
test "dae boundary facts mark overwritten incoming params dead" {
  // Cases 1-4: incoming value dead under set/if/unreachable/loop overwrite.
  let set_before_read = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad)
      #|  (func $target (param i32)
      #|    i32.const 1
      #|    local.set 0
      #|    local.get 0
      #|    drop)
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $target))
    ),
  )
  assert_eq(dae_incoming_parameter_liveness(set_before_read, 1, 1), [false])

  let both_arms = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad1)
      #|  (func $pad2)
      #|  (func $target (param i32)
      #|    i32.const 0
      #|    if
      #|      i32.const 1
      #|      local.set 0
      #|    else
      #|      i32.const 2
      #|      local.set 0
      #|    end
      #|    local.get 0
      #|    drop)
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $target))
    ),
  )
  assert_eq(dae_incoming_parameter_liveness(both_arms, 2, 1), [false])

  let unreachable_only = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target (param i32)
      #|    unreachable
      #|    local.get 0
      #|    drop)
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $target))
    ),
  )
  assert_eq(dae_incoming_parameter_liveness(unreachable_only, 0, 1), [false])

  let loop_overwritten = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad)
      #|  (func $target (param i32)
      #|    i32.const 9
      #|    local.set 0
      #|    loop
      #|      local.get 0
      #|      drop
      #|      br 0
      #|    end)
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $target))
    ),
  )
  assert_eq(dae_incoming_parameter_liveness(loop_overwritten, 1, 1), [false])
}

///|
test "dae boundary facts mark reachable incoming params live" {
  // Cases 5-8: if-arm, loop first iter, br_if, br_table.
  let if_arm_live = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target (param i32)
      #|    i32.const 0
      #|    if
      #|      local.get 0
      #|      drop
      #|      i32.const 1
      #|      local.set 0
      #|    else
      #|      i32.const 2
      #|      local.set 0
      #|    end)
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $target))
    ),
  )
  assert_eq(dae_incoming_parameter_liveness(if_arm_live, 0, 1), [true])

  let loop_first = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad)
      #|  (func $target (param i32)
      #|    loop
      #|      local.get 0
      #|      drop
      #|      i32.const 1
      #|      local.set 0
      #|      br 0
      #|    end)
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $target))
    ),
  )
  assert_eq(dae_incoming_parameter_liveness(loop_first, 1, 1), [true])

  let br_if_cond = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target (param i32)
      #|    block
      #|      local.get 0
      #|      br_if 0
      #|    end)
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $target))
    ),
  )
  assert_eq(dae_incoming_parameter_liveness(br_if_cond, 0, 1), [true])

  let br_table_sel = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad1)
      #|  (func $pad2)
      #|  (func $target (param i32)
      #|    block
      #|      block
      #|        local.get 0
      #|        br_table 0 1
      #|      end
      #|    end)
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $target))
    ),
  )
  assert_eq(dae_incoming_parameter_liveness(br_table_sel, 2, 1), [true])
}

///|
test "dae boundary facts keep try_table and legacy-try reads live or fail closed" {
  // Cases 9-14.
  let try_table_body = pass_test_module_from_wat(
    (
      #|(module
      #|  (tag $e)
      #|  (func $target (param i32)
      #|    block $caught
      #|      try_table (catch $e $caught)
      #|        local.get 0
      #|        drop
      #|      end
      #|    end)
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $target))
    ),
  )
  assert_eq(dae_incoming_parameter_liveness(try_table_body, 0, 1), [true])

  let try_table_handler = pass_test_module_from_wat(
    (
      #|(module
      #|  (tag $e)
      #|  (func $pad)
      #|  (func $target (param i32)
      #|    block $caught
      #|      try_table (catch $e $caught)
      #|        throw $e
      #|      end
      #|    end
      #|    local.get 0
      #|    drop)
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $target))
    ),
  )
  assert_eq(dae_incoming_parameter_liveness(try_table_handler, 1, 1), [true])

  let legacy_body = pass_test_module_from_wat(
    (
      #|(module
      #|  (tag $e)
      #|  (func $target (param i32)
      #|    (try
      #|      (do
      #|        local.get 0
      #|        drop)
      #|      (catch $e)))
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $target))
    ),
  )
  // Legacy try is not HOT-lifted; fail-closed marks live.
  assert_eq(dae_incoming_parameter_liveness(legacy_body, 0, 1), [true])

  let legacy_catch = pass_test_module_from_wat(
    (
      #|(module
      #|  (tag $e (param i32))
      #|  (func $pad)
      #|  (func $target (param i32)
      #|    (try
      #|      (do
      #|        i32.const 1
      #|        throw $e)
      #|      (catch $e
      #|        local.get 0
      #|        drop
      #|        drop)))
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $target))
    ),
  )
  assert_eq(dae_incoming_parameter_liveness(legacy_catch, 1, 1), [true])

  let legacy_catch_all = pass_test_module_from_wat(
    (
      #|(module
      #|  (tag $e)
      #|  (func $target (param i32)
      #|    (try
      #|      (do
      #|        throw $e)
      #|      (catch_all
      #|        local.get 0
      #|        drop)))
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $target))
    ),
  )
  assert_eq(dae_incoming_parameter_liveness(legacy_catch_all, 0, 1), [true])

  let legacy_delegate = pass_test_module_from_wat(
    (
      #|(module
      #|  (tag $e)
      #|  (func $target (param i32)
      #|    (try $outer
      #|      (do
      #|        (try
      #|          (do
      #|            local.get 0
      #|            drop
      #|            throw $e)
      #|          (delegate $outer)))
      #|      (catch $e)))
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $target))
    ),
  )
  assert_eq(dae_incoming_parameter_liveness(legacy_delegate, 0, 1), [true])
}

///|
test "dae boundary facts protect exact export start ref.func and element surfaces" {
  let exported = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad)
      #|  (func $target (export "t") (param i32)
      #|    local.get 0
      #|    drop)
      #|  (func $caller
      #|    i32.const 0
      #|    call $target))
    ),
  )
  let exported_facts = dae_boundary_facts_new(exported)
  assert_true(dae_boundary_facts_exposure(exported_facts)[1].exported)
  assert_false(dae_can_change_parameters(exported_facts, 1))

  let started = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad)
      #|  (func $target
      #|    nop)
      #|  (start $target)
      #|  (func $caller
      #|    call $target))
    ),
  )
  let started_facts = dae_boundary_facts_new(started)
  assert_true(dae_boundary_facts_exposure(started_facts)[1].start)
  assert_false(dae_can_change_parameters(started_facts, 1))

  let ref_func_body = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $ty (func (param i32)))
      #|  (elem declare func $target)
      #|  (func $pad)
      #|  (func $target (type $ty)
      #|    local.get 0
      #|    drop)
      #|  (func $holder (result (ref null $ty))
      #|    ref.func $target)
      #|  (func $caller
      #|    i32.const 0
      #|    call $target))
    ),
  )
  let ref_body_facts = dae_boundary_facts_new(ref_func_body)
  assert_true(dae_boundary_facts_exposure(ref_body_facts)[1].ref_func_body)
  assert_false(dae_can_change_parameters(ref_body_facts, 1))

  let ref_func_module = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $ty (func (param i32)))
      #|  (elem declare func $target)
      #|  (func $pad)
      #|  (func $target (type $ty)
      #|    local.get 0
      #|    drop)
      #|  (global (ref null $ty) (ref.func $target))
      #|  (func $caller
      #|    i32.const 0
      #|    call $target))
    ),
  )
  let ref_mod_facts = dae_boundary_facts_new(ref_func_module)
  assert_true(dae_boundary_facts_exposure(ref_mod_facts)[1].ref_func_module)
  assert_false(dae_can_change_parameters(ref_mod_facts, 1))

  let active_elem = pass_test_module_from_wat(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (func $pad)
      #|  (func $target (param i32)
      #|    local.get 0
      #|    drop)
      #|  (elem (i32.const 0) $target)
      #|  (func $caller
      #|    i32.const 0
      #|    call $target))
    ),
  )
  let active_facts = dae_boundary_facts_new(active_elem)
  assert_true(dae_boundary_facts_exposure(active_facts)[1].active_element)
  assert_false(dae_can_change_parameters(active_facts, 1))

  let passive_elem = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad)
      #|  (func $target (param i32)
      #|    local.get 0
      #|    drop)
      #|  (elem func $target)
      #|  (func $caller
      #|    i32.const 0
      #|    call $target))
    ),
  )
  let passive_facts = dae_boundary_facts_new(passive_elem)
  assert_true(dae_boundary_facts_exposure(passive_facts)[1].passive_element)
  assert_false(dae_can_change_parameters(passive_facts, 1))

  // WAST lowers `elem declare` as passive; build declarative mode directly.
  let declarative_only = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad1)
      #|  (func $pad2)
      #|  (func $target (param i32)
      #|    local.get 0
      #|    drop)
      #|  (func $caller
      #|    i32.const 0
      #|    call $target))
    ),
  ).with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::declarative(),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(2U)]),
      ),
    ]),
  )
  let decl_facts = dae_boundary_facts_new(declarative_only)
  assert_true(dae_boundary_facts_exposure(decl_facts)[2].declarative_element)
  assert_false(dae_can_change_parameters(decl_facts, 2))
}

///|
test "dae type-only tag table indirect and call_ref surfaces stay parameter-eligible" {
  let tag_carrier = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $shared (func (param i32)))
      #|  (tag $e (type $shared))
      #|  (func $pad)
      #|  (func $target (type $shared)
      #|    nop)
      #|  (func $caller
      #|    i32.const 0
      #|    call $target))
    ),
  )
  let tag_facts = dae_boundary_facts_new(tag_carrier)
  assert_true(dae_can_change_parameters(tag_facts, 1))
  assert_false(dae_is_incoming_parameter_live(tag_facts, 1, 0))

  let table_only = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $ty (func (param i32)))
      #|  (table 1 funcref)
      #|  (func $pad)
      #|  (func $target (type $ty)
      #|    nop)
      #|  (func $caller
      #|    i32.const 0
      #|    call $target))
    ),
  )
  let table_facts = dae_boundary_facts_new(table_only)
  assert_true(dae_can_change_parameters(table_facts, 1))

  let unrelated_indirect = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $ty (func (param i32)))
      #|  (table 1 funcref)
      #|  (func $pad)
      #|  (func $target (type $ty)
      #|    nop)
      #|  (func $indirectLeaf (type $ty)
      #|    local.get 0
      #|    drop)
      #|  (elem (i32.const 0) $indirectLeaf)
      #|  (func $indirectCaller
      #|    i32.const 0
      #|    i32.const 0
      #|    call_indirect (type $ty))
      #|  (func $caller
      #|    i32.const 0
      #|    call $target))
    ),
  )
  let indirect_facts = dae_boundary_facts_new(unrelated_indirect)
  assert_true(dae_can_change_parameters(indirect_facts, 1))
  assert_false(dae_can_change_parameters(indirect_facts, 2))
  assert_true(
    dae_boundary_facts_topology(indirect_facts).has_outgoing_call_indirect[3],
  )

  let unrelated_call_ref = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $ty (func (param i32)))
      #|  (elem declare func $refLeaf)
      #|  (func $pad)
      #|  (func $target (type $ty)
      #|    nop)
      #|  (func $refLeaf (type $ty)
      #|    local.get 0
      #|    drop)
      #|  (func $caller
      #|    i32.const 0
      #|    call $target))
    ),
  )
  let unrelated_call_ref = match unrelated_call_ref.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let next = funcs.copy()
      next[3] = @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::ref_func(@lib.FuncIdx::new(2U)),
          @lib.Instruction::call_ref(@lib.TypeIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        ]),
      )
      unrelated_call_ref.with_code_sec(@lib.CodeSec::new(next))
    }
    None => fail("expected code section")
  }
  let call_ref_facts = dae_boundary_facts_new(unrelated_call_ref)
  assert_true(dae_can_change_parameters(call_ref_facts, 1))
  assert_false(dae_can_change_parameters(call_ref_facts, 2))
  assert_true(
    dae_boundary_facts_topology(call_ref_facts).has_outgoing_call_ref[3],
  )
}

///|
test "dae dropped-result legality ignores unrelated direct tails" {
  let source =
    #|(module
    #|  (func $target (result i32)
    #|    i32.const 1)
    #|  (func $caller
    #|    call $target
    #|    drop)
    #|  (func $leaf (result i32)
    #|    i32.const 2)
    #|  (func $unrelated-tail (result i32)
    #|    return_call $leaf)
    #|  (func (export "run") (result i32)
    #|    call $unrelated-tail))
  let mod_ = pass_test_module_from_wat(source)
  let total = dae_imported_func_count(mod_) + dae_defined_func_count(mod_)
  let result = dae_try_remove_dropped_result_def_with_facts(
    mod_,
    0,
    dae_collect_current_call_facts(mod_, total),
  )
  assert_true(result.changed)
  let type_indices = dae_collect_func_type_indices(result.mod_out)
  match dae_resolve_func_type(result.mod_out, type_indices, 0) {
    Some(@lib.FuncType([], results)) => assert_eq(results, [])
    _ => fail("expected target result removal")
  }
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(caller_body)) = funcs[1]
      assert_eq(caller_body, [@lib.Instruction::call(@lib.FuncIdx::new(0U))])
      let @lib.Func(_, @lib.Expr(tail_body)) = funcs[3]
      assert_eq(tail_body, [
        @lib.Instruction::return_call(@lib.FuncIdx::new(2U)),
      ])
    }
    None => fail("expected code section")
  }
  match @validate.validate_module(result.mod_out) {
    Ok(_) => ()
    Err(err) => fail("expected valid exact result-tail legality, got \{err}")
  }
}

///|
test "dae outgoing tails block result removal not parameter removal" {
  let indirect_tail = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $ty (func))
      #|  (table 1 funcref)
      #|  (func $pad)
      #|  (func $target (param i32)
      #|    i32.const 0
      #|    return_call_indirect (type $ty))
      #|  (func $caller
      #|    i32.const 0
      #|    call $target))
    ),
  )
  let tail_facts = dae_boundary_facts_new(indirect_tail)
  assert_true(
    dae_boundary_facts_topology(tail_facts).has_outgoing_return_call_indirect[1],
  )
  assert_true(dae_can_change_parameters(tail_facts, 1))
  assert_false(dae_can_remove_function_result(tail_facts, 1))

  let ref_tail = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $ty (func))
      #|  (elem declare func $leaf)
      #|  (func $pad)
      #|  (func $leaf)
      #|  (func $target (param i32)
      #|    local.get 0
      #|    drop)
      #|  (func $caller
      #|    i32.const 0
      #|    call $target))
    ),
  )
  let ref_tail = match ref_tail.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let next = funcs.copy()
      next[2] = @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
          @lib.Instruction::return_call_ref(@lib.TypeIdx::new(0U)),
        ]),
      )
      ref_tail.with_code_sec(@lib.CodeSec::new(next))
    }
    None => fail("expected code section")
  }
  let ref_tail_facts = dae_boundary_facts_new(ref_tail)
  assert_true(
    dae_boundary_facts_topology(ref_tail_facts).has_outgoing_return_call_ref[2],
  )
  assert_true(dae_can_change_parameters(ref_tail_facts, 2))
  assert_false(dae_can_remove_function_result(ref_tail_facts, 2))

  let dropped_result_tail = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $ty (func (result i32)))
      #|  (table 1 funcref)
      #|  (func $pad)
      #|  (func $leaf (result i32)
      #|    i32.const 1)
      #|  (func $wrapper (param i32) (result i32)
      #|    i32.const 0
      #|    return_call_indirect (type $ty))
      #|  (func $caller
      #|    i32.const 0
      #|    call $wrapper
      #|    drop))
    ),
  )
  let dropped_facts = dae_boundary_facts_new(dropped_result_tail)
  assert_true(dae_can_change_parameters(dropped_facts, 2))
  assert_false(dae_can_remove_function_result(dropped_facts, 2))
}

///|
test "dae current topology separates return_call dropped observers and stale epochs" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad)
      #|  (func $target (param i32) (result i32)
      #|    local.get 0)
      #|  (func $ordinary
      #|    i32.const 1
      #|    call $target
      #|    drop)
      #|  (func $tail (param i32) (result i32)
      #|    local.get 0
      #|    return_call $target)
      #|  (func (export "run") (result i32)
      #|    i32.const 2
      #|    call $tail))
    ),
  )
  let facts = dae_boundary_facts_new(mod_)
  assert_eq(facts.graph.snapshot.call_facts.direct_calls[1], 2)
  assert_eq(facts.graph.snapshot.call_facts.dropped_calls[1], 1)
  assert_true(facts.graph.snapshot.call_facts.tail_calls[1])
  // Absolute caller indices in both directions.
  assert_eq(dae_boundary_facts_topology(facts).direct_return_callers[1], [3])
  assert_true(
    dae_boundary_facts_topology(facts).direct_return_callees_by_caller[3].contains(
      1,
    ),
  )
  assert_true(dae_boundary_facts_topology(facts).has_outgoing_return_call[3])
  assert_false(dae_can_remove_function_result(facts, 1))

  let before_epoch = dae_boundary_candidate_epoch(facts.graph, 1)
  let before_calls = facts.graph.snapshot.call_facts.direct_calls[1]
  let with_extra_call = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(locals, @lib.Expr(body)) = funcs[2]
      let next_body = body.copy()
      next_body.push(@lib.Instruction::i32_const(@lib.I32(3)))
      next_body.push(@lib.Instruction::call(@lib.FuncIdx::new(1U)))
      next_body.push(@lib.Instruction::drop())
      let next_funcs = funcs.copy()
      next_funcs[2] = @lib.Func::new(locals, @lib.Expr::new(next_body))
      mod_.with_code_sec(@lib.CodeSec::new(next_funcs))
    }
    None => fail("expected code section")
  }
  dae_boundary_facts_refresh_current(facts, with_extra_call)
  assert_true(
    facts.graph.call_epoch > before_epoch.call_epoch ||
    facts.graph.module_epoch > before_epoch.module_epoch,
  )
  assert_true(facts.graph.snapshot.call_facts.direct_calls[1] > before_calls)
  assert_false(dae_candidate_epoch_is_current(facts.graph, before_epoch))
  assert_eq(dae_wb_param_count(with_extra_call, 1), 1)
}

///|
test "dae imported-function offsets keep absolute topology and definition liveness" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "env" "imp0" (func $imp0 (param i32)))
      #|  (import "env" "imp1" (func $imp1 (param i32) (result i32)))
      #|  (func $pad)
      #|  (func $target (param i32) (result i32)
      #|    local.get 0)
      #|  (func $ordinary
      #|    i32.const 1
      #|    call $target
      #|    drop)
      #|  (func $tail (param i32) (result i32)
      #|    local.get 0
      #|    return_call $target)
      #|  (func (export "run") (result i32)
      #|    i32.const 2
      #|    call $tail))
    ),
  )
  let facts = dae_boundary_facts_new(mod_)
  let imported = facts.graph.snapshot.imported
  assert_eq(imported, 2)
  let target_def = 1
  let target_abs = dae_abs_func_idx(imported, target_def)
  assert_eq(target_abs, 3)
  assert_eq(dae_def_idx_of_abs(imported, target_abs), Some(target_def))
  assert_true(dae_boundary_facts_exposure(facts)[0].imported)
  assert_true(dae_boundary_facts_exposure(facts)[1].imported)
  assert_false(dae_boundary_facts_exposure(facts)[target_abs].imported)
  assert_eq(facts.graph.snapshot.call_facts.direct_calls[target_abs], 2)
  assert_eq(facts.graph.snapshot.call_facts.dropped_calls[target_abs], 1)
  assert_true(facts.graph.snapshot.call_facts.tail_calls[target_abs])
  let tail_caller_abs = dae_abs_func_idx(imported, 3)
  assert_eq(
    dae_boundary_facts_topology(facts).direct_return_callers[target_abs],
    [tail_caller_abs],
  )
  assert_true(
    dae_boundary_facts_topology(facts).direct_return_callees_by_caller[tail_caller_abs].contains(
      target_abs,
    ),
  )
  // Fail closed if a caller definition index is stored where abs is required.
  assert_false(
    dae_boundary_facts_topology(facts).direct_return_callers[target_abs].contains(
      3,
    ),
  )
  assert_true(dae_is_incoming_parameter_live(facts, target_abs, 0))
  assert_eq(facts.incoming_param_live_by_def[target_def], [true])
}

///|
test "dae dispatcher rejects stale call body signature and module epochs without mutation" {
  let (mod_, _, _, _) = dae_scalar_rewrite_plan_fixture()
  let original = dae_collect_original_boundary_snapshot(mod_)
  let graph = dae_current_boundary_graph_new(mod_)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let before_params = dae_wb_param_count(mod_, 0)

  // Call-epoch stale item: bump call_epoch only and submit through dispatcher.
  let call_item = dae_work_item_new(
    graph,
    dependencies,
    0,
    DaeUnusedParameterWork,
  )
  graph.call_epoch += 1
  let call_diagnostics = dae_diagnostics_new()
  match
    dae_process_work_item(
      original,
      mod_,
      [],
      false,
      graph,
      dependencies,
      call_item,
      call_diagnostics,
    ) {
    DaeWorkRequeue(_) | DaeWorkNoChange(DaeStaleCandidateFacts) => ()
    _ => fail("expected stale call-epoch outcome")
  }
  assert_eq(dae_wb_param_count(mod_, 0), before_params)
  assert_false(dae_work_item_epoch_is_current(graph, call_item))

  // Body-epoch stale item after a real body rewrite refresh.
  let graph2 = dae_current_boundary_graph_new(mod_)
  let dependencies2 = dae_boundary_dependency_graph_new(graph2)
  let body_item = dae_work_item_new(
    graph2,
    dependencies2,
    0,
    DaeUnusedParameterWork,
  )
  let changed_body = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(locals, @lib.Expr(body)) = funcs[0]
      let next_body = body.copy()
      next_body.push(@lib.Instruction::nop())
      let next_funcs = funcs.copy()
      next_funcs[0] = @lib.Func::new(locals, @lib.Expr::new(next_body))
      mod_.with_code_sec(@lib.CodeSec::new(next_funcs))
    }
    None => fail("expected code section")
  }
  dae_current_boundary_graph_refresh(graph2, changed_body)
  let body_diagnostics = dae_diagnostics_new()
  match
    dae_process_work_item(
      original,
      changed_body,
      [],
      false,
      graph2,
      dependencies2,
      body_item,
      body_diagnostics,
    ) {
    DaeWorkRequeue(_) | DaeWorkNoChange(DaeStaleCandidateFacts) => ()
    _ => fail("expected stale body-epoch outcome")
  }
  assert_eq(dae_wb_param_count(changed_body, 0), before_params)
  assert_false(dae_work_item_epoch_is_current(graph2, body_item))

  // Signature-epoch stale item after a signature change refresh.
  let graph3 = dae_current_boundary_graph_new(mod_)
  let dependencies3 = dae_boundary_dependency_graph_new(graph3)
  let sig_item = dae_work_item_new(
    graph3,
    dependencies3,
    0,
    DaeUnusedParameterWork,
  )
  let changed_sig = match (mod_.func_sec, mod_.type_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.TypeSec(rec_types))) => {
      let next_types = rec_types.copy()
      let new_type_idx = next_types.length()
      next_types.push(
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
          ),
        ),
      )
      let next_idxs = type_idxs.copy()
      next_idxs[0] = @lib.TypeIdx::new(new_type_idx.reinterpret_as_uint())
      mod_
      .with_type_sec(@lib.TypeSec::new(next_types))
      .with_func_sec(@lib.FuncSec::new(next_idxs))
    }
    _ => fail("expected type and func sections")
  }
  dae_current_boundary_graph_refresh(graph3, changed_sig)
  let sig_diagnostics = dae_diagnostics_new()
  match
    dae_process_work_item(
      original,
      changed_sig,
      [],
      false,
      graph3,
      dependencies3,
      sig_item,
      sig_diagnostics,
    ) {
    DaeWorkRequeue(_) | DaeWorkNoChange(DaeStaleCandidateFacts) => ()
    _ => fail("expected stale signature-epoch outcome")
  }
  assert_false(dae_work_item_epoch_is_current(graph3, sig_item))

  // Module-epoch / type-domain stale via module_epoch bump (type edits advance
  // module epoch together with signature facts in the shared graph).
  let graph4 = dae_current_boundary_graph_new(mod_)
  let dependencies4 = dae_boundary_dependency_graph_new(graph4)
  let type_item = dae_work_item_new(
    graph4,
    dependencies4,
    0,
    DaeUnusedParameterWork,
  )
  graph4.module_epoch += 1
  let type_diagnostics = dae_diagnostics_new()
  match
    dae_process_work_item(
      original,
      mod_,
      [],
      false,
      graph4,
      dependencies4,
      type_item,
      type_diagnostics,
    ) {
    DaeWorkRequeue(_) | DaeWorkNoChange(DaeStaleCandidateFacts) => ()
    _ => fail("expected stale module/type-epoch outcome")
  }
  assert_eq(dae_wb_param_count(mod_, 0), before_params)
  assert_false(dae_work_item_epoch_is_current(graph4, type_item))
}

///|
test "dae shared live-in drives unread removal without local.get equivalence" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad)
      #|  (func $target (param i32) (result i32)
      #|    i32.const 4
      #|    local.set 0
      #|    local.get 0)
      #|  (func (export "run") (result i32)
      #|    i32.const 9
      #|    call $target))
    ),
  )
  let facts = dae_boundary_facts_new(mod_)
  assert_false(dae_is_incoming_parameter_live(facts, 1, 0))
  assert_true(dae_can_change_parameters(facts, 1))
  let optimized = dae_run_module_pass(mod_)
  assert_eq(dae_wb_param_count(optimized, 1), 0)
}

///|
test "dae shared boundary guard blocks signature change on protected targets" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad)
      #|  (func $target (export "t") (param i32)
      #|    i32.const 1
      #|    local.set 0
      #|    local.get 0
      #|    drop)
      #|  (func $caller
      #|    i32.const 0
      #|    call $target))
    ),
  )
  let before = dae_wb_param_count(mod_, 1)
  let optimized = dae_run_module_pass(mod_)
  assert_eq(dae_wb_param_count(optimized, 1), before)
}

///|
fn dae_wb_defined_body(
  mod_ : @lib.Module,
  def_idx : Int,
) -> Array[@lib.Instruction] {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
      body
    }
    None => abort("missing code section")
  }
}

///|
fn dae_wb_find_direct_call(
  body : Array[@lib.Instruction],
  callee_abs : Int,
) -> Int {
  let mut idx = 0
  while idx < body.length() {
    match body[idx] {
      @lib.Call(func_idx) if dae_func_idx_slot(func_idx) == callee_abs =>
        return idx
      @lib.ReturnCall(func_idx) if dae_func_idx_slot(func_idx) == callee_abs =>
        return idx
      _ => ()
    }
    idx += 1
  }
  -1
}

///|
fn dae_wb_call_slices(
  mod_ : @lib.Module,
  caller_def : Int,
  callee_abs : Int,
  param_types : Array[@lib.ValType],
  call_kind : DaeDirectCallKind,
) -> DaeDirectCallOperandSlices {
  let facts = dae_boundary_facts_new(mod_)
  let body = dae_wb_defined_body(mod_, caller_def)
  let call_idx = dae_wb_find_direct_call(body, callee_abs)
  if call_idx < 0 {
    abort("expected direct call in caller body")
  }
  let epoch = dae_boundary_candidate_epoch(facts.graph, caller_def)
  match
    dae_direct_call_operand_slices(
      mod_,
      body,
      call_idx,
      callee_abs,
      param_types,
      call_kind,
      facts.graph.snapshot.type_indices,
      epoch,
    ) {
    Some(slices) => slices
    None => abort("expected direct-call operand slices")
  }
}

///|
test "dae direct-call operand slices recover exact pure and mixed actuals" {
  // Cases 1-2, 33: pure i32.const; mixed types; parameter order not reverse.
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad)
      #|  (func $target (param i32 i64 f32)
      #|    nop)
      #|  (func (export "run")
      #|    i32.const 1
      #|    i64.const 2
      #|    f32.const 3
      #|    call $target))
    ),
  )
  let slices = dae_wb_call_slices(
    mod_,
    2,
    1,
    [@lib.ValType::i32(), @lib.ValType::i64(), @lib.ValType::f32()],
    DaeDirectCall,
  )
  assert_eq(slices.slices.length(), 3)
  assert_eq(slices.slices[0].start, 0)
  assert_eq(slices.slices[0].end, 1)
  assert_eq(slices.slices[0].producer_kind, DaeProducerConstantOrPureLeaf)
  assert_eq(slices.slices[0].caller_def, 2)
  assert_eq(slices.slices[0].value_type, Some(@lib.ValType::i32()))
  assert_eq(slices.slices[1].start, 1)
  assert_eq(slices.slices[1].end, 2)
  assert_eq(slices.slices[1].value_type, Some(@lib.ValType::i64()))
  assert_eq(slices.slices[2].start, 2)
  assert_eq(slices.slices[2].end, 3)
  assert_eq(slices.slices[2].value_type, Some(@lib.ValType::f32()))
  assert_true(
    dae_direct_call_operand_slices_are_ordered(
      slices.slices,
      slices.call_idx,
      slices.cursor,
    ),
  )
  assert_true(slices.slices[0].end <= slices.slices[1].start)
  assert_true(slices.slices[1].end <= slices.slices[2].start)
}

///|
test "dae direct-call operand slices cover multiple callsites and imported offsets" {
  // Cases 3-4: multiple callsites; two imports shift absolute indices.
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "e" "a" (func))
      #|  (import "e" "b" (func))
      #|  (func $target (param i32)
      #|    nop)
      #|  (func $c0
      #|    i32.const 1
      #|    call $target)
      #|  (func $c1
      #|    i32.const 2
      #|    call $target))
    ),
  )
  let facts = dae_boundary_facts_new(mod_)
  let callee_abs = 2
  let collected = match
    dae_collect_owned_callsite_param_slices(
      facts,
      mod_,
      callee_abs,
      [@lib.ValType::i32()],
      [1, 2],
      0,
    ) {
    Some(slices) => slices
    None => fail("expected owned callsite slices")
  }
  assert_eq(collected.length(), 2)
  assert_eq(collected[0].producer_kind, DaeProducerConstantOrPureLeaf)
  assert_eq(collected[1].producer_kind, DaeProducerConstantOrPureLeaf)
  assert_eq(collected[0].caller_def, 1)
  assert_eq(collected[1].caller_def, 2)
  assert_eq(collected[0].callee_abs, callee_abs)
  assert_eq(collected[1].callee_abs, callee_abs)
}

///|
test "dae direct-call operand slices support return_call and reject stale call kind" {
  // Cases 5, 10: return_call recovery; stale call-kind fails closed.
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad)
      #|  (func $target (param i32) (result i32)
      #|    i32.const 0)
      #|  (func $wrap (param i32) (result i32)
      #|    local.get 0
      #|    return_call $target))
    ),
  )
  let body = dae_wb_defined_body(mod_, 2)
  let call_idx = dae_wb_find_direct_call(body, 1)
  let facts = dae_boundary_facts_new(mod_)
  let epoch = dae_boundary_candidate_epoch(facts.graph, 2)
  match
    dae_direct_call_operand_slices(
      mod_,
      body,
      call_idx,
      1,
      [@lib.ValType::i32()],
      DaeDirectReturnCall,
      facts.graph.snapshot.type_indices,
      epoch,
    ) {
    Some(slices) => {
      assert_eq(slices.call_kind, DaeDirectReturnCall)
      assert_eq(slices.slices.length(), 1)
      assert_eq(slices.slices[0].call_kind, Some(DaeDirectReturnCall))
      assert_eq(slices.slices[0].caller_def, 2)
      assert_eq(slices.slices[0].producer_kind, DaeProducerLocalRead)
    }
    None => fail("expected return_call operand slices")
  }
  match
    dae_direct_call_operand_slices(
      mod_,
      body,
      call_idx,
      1,
      [@lib.ValType::i32()],
      DaeDirectCall,
      facts.graph.snapshot.type_indices,
      epoch,
    ) {
    Some(_) => fail("stale call kind must fail closed")
    None => ()
  }
}

///|
test "dae direct-call operand slices exclude ambient stack and multi-instr producers" {
  // Cases 6-8, 31-32: ambient stack; multi-instr producer; non-overlap.
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (memory 1)
      #|  (func $pad)
      #|  (func $target (param i32)
      #|    nop)
      #|  (func (export "run")
      #|    i32.const 99
      #|    i32.const 0
      #|    i32.load
      #|    call $target
      #|    drop))
    ),
  )
  let slices = dae_wb_call_slices(
    mod_,
    2,
    1,
    [@lib.ValType::i32()],
    DaeDirectCall,
  )
  assert_eq(slices.cursor, 1)
  assert_eq(slices.slices.length(), 1)
  assert_eq(slices.slices[0].start, 1)
  assert_eq(slices.slices[0].end, 3)
  assert_true(slices.slices[0].start > 0)
  assert_true(slices.slices[0].end <= slices.call_idx)
  assert_eq(slices.slices[0].producer_kind, DaeProducerOrdinaryExpression)
  assert_true(slices.slices[0].may_trap)
}

///|
test "dae direct-call operand slices recover scalar operand from multivalue block" {
  // Case 8: supported multivalue context with exact scalar recovery.
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad)
      #|  (func $target (param i32)
      #|    nop)
      #|  (func (export "run")
      #|    block (result i32)
      #|      i32.const 4
      #|    end
      #|    call $target))
    ),
  )
  let slices = dae_wb_call_slices(
    mod_,
    2,
    1,
    [@lib.ValType::i32()],
    DaeDirectCall,
  )
  assert_eq(slices.slices.length(), 1)
  assert_eq(slices.slices[0].producer_kind, DaeProducerStructuredControl)
  assert_eq(slices.slices[0].output_arity, 1)
}

///|
test "dae direct-call operand slices fail closed on underflow and signature mismatch" {
  // Case 9: stack underflow / malformed range fails closed.
  let body = [@lib.Instruction::call(@lib.FuncIdx::new(0U))]
  let epoch = {
    def_idx: 0,
    module_epoch: 0,
    call_epoch: 0,
    type_epoch: 0,
    signature_epoch: 0,
    body_epoch: 0,
  }
  match
    dae_direct_call_operand_slices(
      @lib.Module::new(),
      body,
      0,
      0,
      [@lib.ValType::i32()],
      DaeDirectCall,
      [],
      epoch,
    ) {
    Some(_) => fail("underflow must fail closed")
    None => ()
  }
}

///|
test "dae value producer kinds classify leaf and call producers" {
  // Cases 11-16, 21: producer-kind enum coverage and unknown fail-closed.
  assert_eq(
    dae_instr_producer_kind(@lib.Instruction::i32_const(@lib.I32(1))),
    DaeProducerConstantOrPureLeaf,
  )
  assert_eq(
    dae_instr_producer_kind(@lib.Instruction::local_get(@lib.LocalIdx::new(0U))),
    DaeProducerLocalRead,
  )
  assert_eq(
    dae_instr_producer_kind(
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    ),
    DaeProducerGlobalRead,
  )
  assert_eq(
    dae_instr_producer_kind(@lib.Instruction::call(@lib.FuncIdx::new(0U))),
    DaeProducerDirectCall,
  )
  assert_eq(
    dae_instr_producer_kind(
      @lib.Instruction::call_indirect(
        @lib.TypeIdx::new(0U),
        @lib.TableIdx::new(0U),
      ),
    ),
    DaeProducerIndirectCall,
  )
  assert_eq(
    dae_instr_producer_kind(@lib.Instruction::call_ref(@lib.TypeIdx::new(0U))),
    DaeProducerCallRef,
  )
  assert_eq(dae_value_producer_kind_from_range([], 0, 0), DaeProducerUnknown)
}

///|
test "dae value producer kinds classify trap control and unreachable producers" {
  // Cases 17-20: trapping load; structured; branchful; unreachable.
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let load_body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
  ]
  let load_slice = dae_value_slice_from_range(load_body, 0, 2)
  assert_eq(load_slice.producer_kind, DaeProducerOrdinaryExpression)
  assert_true(load_slice.may_trap)

  let structured = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
    ),
  ]
  assert_eq(
    dae_value_producer_kind_from_range(structured, 0, 1),
    DaeProducerStructuredControl,
  )

  let branchful = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ]),
    ),
  ]
  let branch_slice = dae_value_slice_from_range(branchful, 0, 1)
  assert_eq(branch_slice.producer_kind, DaeProducerStructuredControl)
  assert_true(branch_slice.has_branch || branch_slice.has_escaping_branch)

  assert_eq(
    dae_instr_producer_kind(@lib.Instruction::unreachable_()),
    DaeProducerUnreachable,
  )
}

///|
test "dae classify parameter slot keep remove-pure replay and localize" {
  // Cases 22-28: slot actions from shared liveness + canonical slices.
  let pure_mod = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad)
      #|  (func $target (param i32)
      #|    i32.const 1
      #|    local.set 0)
      #|  (func (export "run")
      #|    i32.const 9
      #|    call $target))
    ),
  )
  let pure_facts = dae_boundary_facts_new(pure_mod)
  let pure_slices = match
    dae_collect_owned_callsite_param_slices(
      pure_facts,
      pure_mod,
      1,
      [@lib.ValType::i32()],
      [2],
      0,
    ) {
    Some(slices) => slices
    None => fail("expected pure callsite slices")
  }
  assert_eq(
    dae_classify_parameter_slot(pure_facts, 1, 0, true, pure_slices),
    DaeKeepParameter,
  )
  assert_eq(
    dae_classify_parameter_slot(pure_facts, 1, 0, false, pure_slices),
    DaeRemovePureParameter,
  )
  assert_eq(
    dae_classify_parameter_slot(pure_facts, 1, 0, false, []),
    DaeKeepParameter,
  )

  let effect_mod = pass_test_module_from_wat(
    (
      #|(module
      #|  (memory 1)
      #|  (func $pad)
      #|  (func $target (param i32)
      #|    nop)
      #|  (func (export "run")
      #|    i32.const 0
      #|    i32.load
      #|    call $target))
    ),
  )
  let effect_facts = dae_boundary_facts_new(effect_mod)
  let effect_slices = match
    dae_collect_owned_callsite_param_slices(
      effect_facts,
      effect_mod,
      1,
      [@lib.ValType::i32()],
      [2],
      0,
    ) {
    Some(slices) => slices
    None => fail("expected effectful callsite slices")
  }
  assert_eq(
    dae_classify_parameter_slot(effect_facts, 1, 0, false, effect_slices),
    DaeRemoveParameterReplayEffects,
  )

  let nested_mod = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad)
      #|  (func $side (result i32)
      #|    i32.const 7)
      #|  (func $target (param i32)
      #|    nop)
      #|  (func (export "run")
      #|    call $side
      #|    call $target))
    ),
  )
  let nested_facts = dae_boundary_facts_new(nested_mod)
  let nested_slices = match
    dae_collect_owned_callsite_param_slices(
      nested_facts,
      nested_mod,
      2,
      [@lib.ValType::i32()],
      [3],
      0,
    ) {
    Some(slices) => slices
    None => fail("expected nested-call slices")
  }
  assert_eq(
    dae_classify_parameter_slot(nested_facts, 2, 0, false, nested_slices),
    DaeLocalizeParameterAndRetry,
  )

  let protected = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pad)
      #|  (func $target (export "t") (param i32)
      #|    nop)
      #|  (func $caller
      #|    i32.const 0
      #|    call $target))
    ),
  )
  let protected_facts = dae_boundary_facts_new(protected)
  let protected_slices = match
    dae_collect_owned_callsite_param_slices(
      protected_facts,
      protected,
      1,
      [@lib.ValType::i32()],
      [2],
      0,
    ) {
    Some(slices) => slices
    None => fail("expected protected callsite slices")
  }
  assert_eq(
    dae_classify_parameter_slot(protected_facts, 1, 0, false, protected_slices),
    DaeKeepParameter,
  )

  // Case 28: stale epoch on an enriched slice produces Keep.
  let stale = {
    ..pure_slices[0],
    module_epoch: 0,
    call_epoch: 0,
    signature_epoch: 0,
    body_epoch: 0,
  }
  let bumped = {
    ..pure_facts,
    graph: {
      ..pure_facts.graph,
      module_epoch: pure_facts.graph.module_epoch + 1,
    },
  }
  assert_eq(
    dae_classify_parameter_slot(bumped, 1, 0, false, [stale]),
    DaeKeepParameter,
  )
}

///|
test "dae classify unused parameter actions retain mixed slot source order" {
  // Cases 29-30: mixed keep / pure-remove / replay retain parameter order.
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (memory 1)
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func $pad)
      #|  (func $target (param i32 i32 i32 i32)
      #|    local.get 1
      #|    drop)
      #|  (func (export "run")
      #|    i32.const 0
      #|    i32.load
      #|    i32.const 1
      #|    i32.const 2
      #|    i32.const 0
      #|    i32.load
      #|    call $target))
    ),
  )
  let facts = dae_boundary_facts_new(mod_)
  let entry_live = dae_incoming_parameter_liveness(mod_, 1, 4)
  assert_eq(entry_live, [false, true, false, false])
  let actions = match
    dae_classify_unused_parameter_actions(
      facts,
      mod_,
      1,
      1,
      [
        @lib.ValType::i32(),
        @lib.ValType::i32(),
        @lib.ValType::i32(),
        @lib.ValType::i32(),
      ],
      entry_live,
      [2],
    ) {
    Some(actions) => actions
    None => fail("expected classified unused-parameter actions")
  }
  assert_eq(actions.length(), 4)
  assert_eq(actions[0], DaeRemoveParameterReplayEffects)
  assert_eq(actions[1], DaeKeepParameter)
  assert_eq(actions[2], DaeRemovePureParameter)
  assert_eq(actions[3], DaeRemoveParameterReplayEffects)
  let all_slices = dae_wb_call_slices(
    mod_,
    2,
    1,
    [
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ],
    DaeDirectCall,
  )
  assert_true(all_slices.slices[0].end <= all_slices.slices[1].start)
  assert_true(all_slices.slices[1].end <= all_slices.slices[2].start)
  assert_true(all_slices.slices[2].end <= all_slices.slices[3].start)
  assert_true(all_slices.slices[0].start < all_slices.slices[3].start)
}

///|
test "dae ordinary unused-parameter path uses classified actions publicly" {
  // Cases 34-37: pure removal, effectful replay, return_call, live keep.
  let pure = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "e" "x" (func))
      #|  (import "e" "y" (func))
      #|  (func $target (param i32)
      #|    nop)
      #|  (func (export "run")
      #|    i32.const 3
      #|    call $target))
    ),
  )
  let pure_out = dae_run_module_pass(pure)
  assert_eq(dae_wb_param_count(pure_out, 2), 0)
  match @validate.validate_module(pure_out) {
    Ok(_) => ()
    Err(err) => fail("pure unused-parameter output must validate, got \{err}")
  }

  let effectful = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "e" "pad0" (func))
      #|  (memory 1)
      #|  (func $target (param i32)
      #|    nop)
      #|  (func (export "run")
      #|    i32.const 0
      #|    i32.load
      #|    call $target))
    ),
  )
  let effect_out = dae_run_module_pass(effectful)
  assert_eq(dae_wb_param_count(effect_out, 1), 0)
  let effect_caller = effect_out.pretty_print_defined_func(1U)
  assert_true(effect_caller.contains("i32.load"), msg=effect_caller)
  match @validate.validate_module(effect_out) {
    Ok(_) => ()
    Err(err) =>
      fail("effectful unused-parameter output must validate, got \{err}")
  }

  let ret = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "e" "pad0" (func))
      #|  (func $target (param i32 i32) (result i32)
      #|    local.get 1)
      #|  (func $wrap (result i32)
      #|    i32.const 31
      #|    i32.const 41
      #|    return_call $target)
      #|  (func (export "run") (result i32)
      #|    call $wrap))
    ),
  )
  let ret_out = dae_run_module_pass(ret)
  assert_eq(dae_wb_param_count(ret_out, 1), 1)
  match @validate.validate_module(ret_out) {
    Ok(_) => ()
    Err(err) =>
      fail("return_call unused-parameter output must validate, got \{err}")
  }

  let live = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "e" "pad0" (func))
      #|  (func $target (param i32 i32) (result i32)
      #|    local.get 1
      #|    if (result i32)
      #|      local.get 0
      #|    else
      #|      i32.const 2
      #|    end)
      #|  (func (export "run") (param i32 i32) (result i32)
      #|    local.get 0
      #|    local.get 1
      #|    call $target))
    ),
  )
  let live_out = dae_run_module_pass(live)
  assert_eq(dae_wb_param_count(live_out, 1), 2)
  match @validate.validate_module(live_out) {
    Ok(_) => ()
    Err(err) => fail("live parameter output must validate, got \{err}")
  }
}

///|
test "dae ordinary unused-parameter path preserves exposure and type-only non-blockers" {
  // Cases 38-40: legacy try fail-closed; ref.func exposure; type-only tag.
  let legacy = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "e" "pad0" (func))
      #|  (tag $e)
      #|  (func $target (param i32) (result i32)
      #|    (try (result i32)
      #|      (do
      #|        local.get 0)
      #|      (catch $e
      #|        i32.const 0)))
      #|  (func (export "run") (param i32) (result i32)
      #|    local.get 0
      #|    call $target))
    ),
  )
  let legacy_before = dae_wb_param_count(legacy, 1)
  let legacy_out = dae_run_module_pass(legacy)
  assert_eq(dae_wb_param_count(legacy_out, 1), legacy_before)
  assert_eq(legacy_before, 1)
  match @validate.validate_module(legacy_out) {
    Ok(_) => ()
    Err(err) => fail("legacy try DAE output must validate, got \{err}")
  }

  let exposed = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "e" "pad0" (func))
      #|  (type $ty (func (param i32)))
      #|  (elem declare func $target)
      #|  (func $target (type $ty)
      #|    nop)
      #|  (func $holder (result (ref null $ty))
      #|    ref.func $target)
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $target
      #|    call $holder
      #|    drop))
    ),
  )
  let exposed_out = dae_run_module_pass(exposed)
  assert_eq(dae_wb_param_count(exposed_out, 1), 1)
  match @validate.validate_module(exposed_out) {
    Ok(_) => ()
    Err(err) => fail("ref.func exposure DAE output must validate, got \{err}")
  }

  let tag_only = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "e" "pad0" (func))
      #|  (type $shared (func (param i32)))
      #|  (tag $e (type $shared))
      #|  (func $target (type $shared)
      #|    nop)
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $target))
    ),
  )
  let tag_out = dae_run_module_pass(tag_only)
  assert_eq(dae_wb_param_count(tag_out, 1), 0)
  match @validate.validate_module(tag_out) {
    Ok(_) => ()
    Err(err) => fail("type-only tag DAE output must validate, got \{err}")
  }
}

///|
test "dae dead-suffix parameter restoration commits through family transaction" {
  let original = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $side (export "side") (param f64) (result f64)
      #|    local.get 0)
      #|  (func $dead (param f64)
      #|    unreachable
      #|    local.get 0
      #|    call $side
      #|    call $dead))
    ),
  )
  let current = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $side (export "side") (param f64) (result f64)
      #|    local.get 0)
      #|  (func $dead
      #|    unreachable))
    ),
  )
  let application = dae_apply_dead_suffix_self_operand_restore_transaction(
    original,
    current,
    [],
    false,
  )
  assert_true(application.applied)
  assert_eq(application.primary_def, 1)
  assert_eq(dae_wb_param_count(application.mod_out, 1), 1)
  match @validate.validate_module(application.mod_out) {
    Ok(_) => ()
    Err(err) => fail("restored family transaction must validate, got \{err}")
  }
}

///|
test "dae call identities exclude inactive suffix calls" {
  let source = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target (param i32)
      #|    nop)
      #|  (func (export "run")
      #|    i32.const 7
      #|    call $target
      #|    unreachable
      #|    i32.const 8
      #|    call $target))
    ),
  )
  let graph = dae_current_boundary_graph_new(source)
  let identities = dae_collect_target_call_identities(graph.snapshot, 0)
  assert_eq(identities.length(), 1)
  assert_eq(identities[0].caller_def, 1)
  assert_eq(identities[0].call_kind, DaeDirectCall)
}

///|
test "dae family transaction derives exact touched ownership" {
  let current = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target (param i32)
      #|    nop)
      #|  (func (export "run")
      #|    i32.const 7
      #|    call $target))
    ),
  )
  let candidate_mod = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target
      #|    nop)
      #|  (func (export "run")
      #|    call $target))
    ),
  )
  let original = dae_collect_original_boundary_snapshot(current)
  let graph = dae_current_boundary_graph_new(current)
  let effects = dae_commit_effects_parameter_change(2, 0, [0, 1], false, [])
  let application = dae_apply_family_result_transaction(
    original,
    current,
    [],
    false,
    graph,
    { mod_out: candidate_mod, touched: [], changed: true, primary_def: -1 },
    effects=Some(effects),
  )
  assert_true(application.applied)
  assert_eq(application.primary_def, 0)
  assert_eq(application.touched.length(), 2)
  assert_true(application.touched[0])
  assert_true(application.touched[1])
  assert_eq(application.effects.structurally_touched, [true, true])
  assert_eq(application.effects.worth_optimizing, [true, false])
  assert_eq(application.effects.parameter_changed, [true, false])
  assert_eq(application.effects.body_materialized, [false, false])
  assert_eq(application.effects.body_localized, [false, false])
  match @validate.validate_module(application.mod_out) {
    Ok(_) => ()
    Err(err) => fail("family transaction output must validate, got \{err}")
  }
}
