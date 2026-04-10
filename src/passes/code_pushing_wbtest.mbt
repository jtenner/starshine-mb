///|
test "code-pushing whitebox rejects a mixed terminal and parent-escape explicit-exit local.set carrier" {
  let source =
    #|(module
    #|  (func $side (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    (local.set 2
    #|      (block $block1 (result i32)
    #|        (block $block
    #|          (br $block1
    #|            (block $carrier (result i32)
    #|              (block $work
    #|                (if (result i32)
    #|                  (local.get 0)
    #|                  (then
    #|                    (local.set 5 (local.get 1))
    #|                    (local.set 6 (local.get 1))
    #|                    (local.set 7
    #|                      (block (result i32)
    #|                        (local.set 8 (local.get 5))
    #|                        (local.set 9 (local.get 6))
    #|                        (local.get 8)))
    #|                    (br $work))
    #|                  (else
    #|                    (local.set 10 (local.get 1))
    #|                    (br $block)))
    #|                unreachable)
    #|              (local.set 11 (local.get 7))
    #|              (local.get 9))))
    #|        (return (i32.const 99))))
    #|    (local.get 1)
    #|    (local.set 3)
    #|    (local.get 1)
    #|    (local.set 4)
    #|    (local.get 4)
    #|    (if
    #|      (then
    #|        (call $side (local.get 4))))
    #|    (local.get 3))
    #|)
  let fixture = @ir.ir_test_build_hot_from_wat(source, code_idx=1)
  let func = fixture.hot_func
  let cache = cp_new_summary_cache(func)
  let root_id = @ir.hot_root_get(func, 0)
  let value_id = @ir.hot_child_get(func, root_id, 0)
  let summary = {
    has_owner_exit: false,
    has_dropped_owner_exit: false,
    has_terminal_exit: false,
    has_inner_owner_exit: false,
    has_unsafe_branch_exit: false,
  }
  let active_owner_marks = cache.owner_exit_active_marks
  active_owner_marks[value_id] = true
  cp_collect_local_set_value_exit_summary(
    cache, func, value_id, value_id, active_owner_marks, -1, summary,
  )
  active_owner_marks[value_id] = false

  assert_true(summary.has_owner_exit)
  assert_true(summary.has_terminal_exit)
  assert_true(summary.has_inner_owner_exit)
  assert_false(
    cp_root_is_simple_explicit_exit_local_set(cache, func, root_id, -1),
  )
}

///|
test "code-pushing whitebox sees explicit exits inside a block body region" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (func (result i32) (block $done (br $done)) (i32.const 0)))",
  )
  let func = fixture.hot_func
  let cache = cp_new_summary_cache(func)
  let root_id = @ir.hot_root_get(func, 0)

  match @ir.hot_node_get(func, root_id).op {
    @ir.HotOp::Block => ()
    op => fail("expected root block, got \{op}")
  }

  assert_true(cp_node_has_explicit_exit(cache, func, root_id))
}

///|
test "code-pushing whitebox keeps a writeback-valid terminal-owner parent-escape carrier despite the suspicious-carrier heuristic" {
  let source =
    #|(module
    #|  (func $side (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    (local.set 2
    #|      (block $block1 (result i32)
    #|        (block $block
    #|          (br $block1
    #|            (block $carrier (result i32)
    #|              (block $work
    #|                (if (result i32)
    #|                  (local.get 0)
    #|                  (then
    #|                    (local.set 5 (local.get 1))
    #|                    (local.set 6 (local.get 1))
    #|                    (local.set 7
    #|                      (block (result i32)
    #|                        (local.set 8 (local.get 5))
    #|                        (local.set 9 (local.get 6))
    #|                        (local.get 8)))
    #|                    (br $work))
    #|                  (else
    #|                    (local.set 10 (local.get 1))
    #|                    (br $block)))
    #|                unreachable)
    #|              (local.set 11 (local.get 7))
    #|              (local.get 9))))
    #|        (return (i32.const 99))))
    #|    (local.get 1)
    #|    (local.set 3)
    #|    (local.get 1)
    #|    (local.set 4)
    #|    (local.get 4)
    #|    (if
    #|      (then
    #|        (call $side (local.get 4))))
    #|    (local.get 3))
    #|)
  let fixture = @ir.ir_test_build_hot_from_wat(source, code_idx=1)
  let func = fixture.hot_func
  let ctx = HotPassContext::new(
    code_pushing_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected code-pushing parent-escape carrier repro success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }

  assert_true(
    run_hot_pipeline_lowered_func_has_suspicious_escape_carrier(lowered),
    msg=out.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
  assert_eq(
    run_hot_pipeline_precompute_writeback_validation_error(
      fixture.mod_,
      fixture.code_idx,
      lowered,
    ),
    None,
  )

  let trace = match pass_test_capture_trace(source, ["code-pushing"]) {
    Ok(lines) => lines
    Err(err) =>
      fail(
        "expected code-pushing parent-escape carrier trace capture success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains("pass[code-pushing]:skip-invalid-lower")
    }),
    msg=trace.to_string(),
  )
}
