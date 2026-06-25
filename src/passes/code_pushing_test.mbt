///|
fn code_pushing_large_jsonas_like_fixture() -> String {
  let out = StringBuilder::new()
  out.write_string("(module (func (local i32")
  for i = 0; i < 129; i = i + 1 {
    let _ = i
    out.write_string(" i32")
  }
  out.write_string(")")
  for i = 0; i < 1001; i = i + 1 {
    let _ = i
    out.write_string(" nop")
  }
  out.write_string("))")
  out.to_string()
}

///|
test "code-pushing skips large local-heavy json-as shaped functions" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      code_pushing_large_jsonas_like_fixture(),
      ["code-pushing"],
      options=HotPipelineOptions::new(
        optimize_level=4,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected large code-pushing skip success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[code-pushing]:skip-raw reason=large-local-code-pushing-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "code-pushing skips O4z raw pass until self-opt decoder hazards are safe" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      "(module (func (param i32) (if (local.get 0) (then))))",
      ["code-pushing"],
      options=HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=1,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected O4z code-pushing skip success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[code-pushing]:skip-raw reason=o4z-code-pushing-noop")
    }),
  )
}

///|
fn code_pushing_test_run_hot_func(func : @ir.HotFunc) -> @ir.HotFunc {
  let ctx = HotPassContext::new(
    code_pushing_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => func
    Err(err) => abort("expected code-pushing hot pass success, got \{err}")
  }
}

///|
fn code_pushing_test_run_hot(text : String) -> @ir.HotFunc {
  code_pushing_test_run_hot_func(pass_test_lift_first_func(text))
}

///|
fn code_pushing_expect_op(
  func : @ir.HotFunc,
  node_id : Int,
  expected : String,
) -> Unit {
  let op = @ir.hot_node_get(func, node_id).op
  match expected {
    "nop" =>
      match op {
        @ir.HotOp::Nop => ()
        _ => abort("expected nop")
      }
    "if" =>
      match op {
        @ir.HotOp::If => ()
        _ => abort("expected if")
      }
    "local.set" =>
      match op {
        @ir.HotOp::LocalSet => ()
        _ => abort("expected local.set")
      }
    "local.get" =>
      match op {
        @ir.HotOp::LocalGet => ()
        _ => abort("expected local.get, got \{op}")
      }
    "const" =>
      match op {
        @ir.HotOp::Const => ()
        _ => abort("expected const")
      }
    "block" =>
      match op {
        @ir.HotOp::Block => ()
        other => abort("expected block, got \{other}")
      }
    "loop" =>
      match op {
        @ir.HotOp::Loop => ()
        other => abort("expected loop, got \{other}")
      }
    "unreachable" =>
      match op {
        @ir.HotOp::Unreachable => ()
        _ => abort("expected unreachable")
      }
    "drop" =>
      match op {
        @ir.HotOp::Drop => ()
        _ => abort("expected drop")
      }
    "br_if" =>
      match op {
        @ir.HotOp::BrIf => ()
        _ => abort("expected br_if")
      }
    "br_on_null" =>
      match op {
        @ir.HotOp::BrOnNull => ()
        _ => abort("expected br_on_null")
      }
    "br_on_non_null" =>
      match op {
        @ir.HotOp::BrOnNonNull => ()
        _ => abort("expected br_on_non_null")
      }
    "br_on_cast" =>
      match op {
        @ir.HotOp::BrOnCast => ()
        _ => abort("expected br_on_cast")
      }
    "br_on_cast_fail" =>
      match op {
        @ir.HotOp::BrOnCastFail => ()
        _ => abort("expected br_on_cast_fail")
      }
    "br_table" =>
      match op {
        @ir.HotOp::BrTable => ()
        _ => abort("expected br_table")
      }
    "call" =>
      match op {
        @ir.HotOp::Call => ()
        _ => abort("expected call")
      }
    "throw" =>
      match op {
        @ir.HotOp::Throw => ()
        _ => abort("expected throw")
      }
    "try_table" =>
      match op {
        @ir.HotOp::TryTable => ()
        _ => abort("expected try_table")
      }
    "atomic" =>
      match op {
        @ir.HotOp::Atomic => ()
        _ => abort("expected atomic")
      }
    "heap" =>
      match op {
        @ir.HotOp::Heap => ()
        _ => abort("expected heap")
      }
    _ => abort("unknown expected hot op")
  }
}

///|
test "code-pushing sinks const local.set into the only using if arm" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if local.get 1 drop end))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  let if_id = @ir.hot_root_get(func, 1)
  code_pushing_expect_op(func, if_id, "if")
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 2)
  let pushed_set = @ir.hot_region_get(func, then_ref, 0)
  code_pushing_expect_op(func, pushed_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, pushed_set).imm0, 1)
  let kept_use = @ir.hot_region_get(func, then_ref, 1)
  code_pushing_expect_op(func, kept_use, "drop")
  let kept_get = @ir.hot_child_get(func, kept_use, 0)
  code_pushing_expect_op(func, kept_get, "local.get")
  @debug.assert_eq(@ir.hot_node_get(func, kept_get).imm0, 1)
}

///|
test "code-pushing sinks const local.set into the only using else arm" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if nop else local.get 1 drop end))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  let if_id = @ir.hot_root_get(func, 1)
  code_pushing_expect_op(func, if_id, "if")
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 1)
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, else_ref), 2)
  let pushed_set = @ir.hot_region_get(func, else_ref, 0)
  code_pushing_expect_op(func, pushed_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, pushed_set).imm0, 1)
  let kept_use = @ir.hot_region_get(func, else_ref, 1)
  code_pushing_expect_op(func, kept_use, "drop")
  let kept_get = @ir.hot_child_get(func, kept_use, 0)
  code_pushing_expect_op(func, kept_get, "local.get")
  @debug.assert_eq(@ir.hot_node_get(func, kept_get).imm0, 1)
}

///|
test "code-pushing sinks pure computed local.set into the only using if arm" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 3 i32.const 4 i32.add local.set 1 local.get 0 if local.get 1 drop end))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  let if_id = @ir.hot_root_get(func, 1)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 2)
  let pushed_set = @ir.hot_region_get(func, then_ref, 0)
  code_pushing_expect_op(func, pushed_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, pushed_set).imm0, 1)
  let value_id = @ir.hot_child_get(func, pushed_set, 0)
  match @ir.hot_node_get(func, value_id).op {
    @ir.HotOp::Binary => ()
    other => abort("expected pushed computed value, got \{other}")
  }
}

///|
test "code-pushing keeps const local.set when both if arms use it" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if local.get 1 drop else local.get 1 drop end))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  let kept_set = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, kept_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, kept_set).imm0, 1)
  let if_id = @ir.hot_root_get(func, 1)
  code_pushing_expect_op(func, if_id, "if")
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 1)
  @debug.assert_eq(@ir.hot_region_root_count(func, else_ref), 1)
  let then_drop = @ir.hot_region_get(func, then_ref, 0)
  let else_drop = @ir.hot_region_get(func, else_ref, 0)
  code_pushing_expect_op(func, then_drop, "drop")
  code_pushing_expect_op(func, else_drop, "drop")
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, then_drop, 0),
    "local.get",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, else_drop, 0),
    "local.get",
  )
}

///|
test "code-pushing keeps local.set before if when the local is used after the if" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) i32.const 7 local.set 1 local.get 0 if local.get 1 drop end local.get 1))",
      ["code-pushing"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected guarded code-pushing success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(
    trace.any(fn(line) { line.contains("pass[code-pushing]:mutated") }),
    msg=trace.to_string(),
  )
}

///|
test "code-pushing sinks if-arm local.set when the opposite arm cannot fall through to a later use" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (result i32) (local i32)
      #|    i32.const 7
      #|    local.set 1
      #|    local.get 0
      #|    if
      #|      local.get 1
      #|      drop
      #|    else
      #|      unreachable
      #|    end
      #|    local.get 1))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 3)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  let if_id = @ir.hot_root_get(func, 1)
  code_pushing_expect_op(func, if_id, "if")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 2), "local.get")
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 2)
  let pushed_set = @ir.hot_region_get(func, then_ref, 0)
  code_pushing_expect_op(func, pushed_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, pushed_set).imm0, 1)
}

///|
test "code-pushing moves pure SFA set after harmless if before later use" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32)
      #|    i32.const 7
      #|    local.set 1
      #|    local.get 0
      #|    if
      #|      nop
      #|    end
      #|    local.get 1
      #|    drop))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 4)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "if")
  let moved_set = @ir.hot_root_get(func, 2)
  code_pushing_expect_op(func, moved_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, moved_set).imm0, 1)
  match @ir.hot_node_get(func, @ir.hot_child_get(func, moved_set, 0)).op {
    @ir.HotOp::Const => ()
    other => abort("expected moved const value, got \{other}")
  }
  code_pushing_expect_op(func, @ir.hot_root_get(func, 3), "drop")
}

///|
test "code-pushing preserves order when moving multiple SFA sets after if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32 i32)
      #|    i32.const 7
      #|    local.set 1
      #|    i32.const 9
      #|    local.set 2
      #|    local.get 0
      #|    if
      #|      nop
      #|    end
      #|    local.get 1
      #|    drop
      #|    local.get 2
      #|    drop))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 7)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 2), "if")
  let first_moved = @ir.hot_root_get(func, 3)
  let second_moved = @ir.hot_root_get(func, 4)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 5), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 6), "drop")
}

///|
test "code-pushing preserves order through nop-separated multi-set window after if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32 i32)
      #|    i32.const 7
      #|    local.set 1
      #|    nop
      #|    i32.const 9
      #|    local.set 2
      #|    local.get 0
      #|    if
      #|      nop
      #|    end
      #|    local.get 1
      #|    drop
      #|    local.get 2
      #|    drop))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 8)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 2), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 3), "if")
  let first_moved = @ir.hot_root_get(func, 4)
  let second_moved = @ir.hot_root_get(func, 5)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 6), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 7), "drop")
}

///|
test "code-pushing preserves order through drop-const-separated multi-set window after if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32 i32)
      #|    i32.const 7
      #|    local.set 1
      #|    i32.const 99
      #|    drop
      #|    i32.const 9
      #|    local.set 2
      #|    local.get 0
      #|    if
      #|      nop
      #|    end
      #|    local.get 1
      #|    drop
      #|    local.get 2
      #|    drop))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 8)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 2), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 3), "if")
  let first_moved = @ir.hot_root_get(func, 4)
  let second_moved = @ir.hot_root_get(func, 5)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 6), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 7), "drop")
}

///|
test "code-pushing preserves order when moving multiple local-copy SFA sets after if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32 i32 i32) (local i32 i32)
      #|    local.get 1
      #|    local.set 3
      #|    local.get 2
      #|    local.set 4
      #|    local.get 0
      #|    if
      #|      nop
      #|    end
      #|    local.get 3
      #|    drop
      #|    local.get 4
      #|    drop))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 7)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 2), "if")
  let first_moved = @ir.hot_root_get(func, 3)
  let second_moved = @ir.hot_root_get(func, 4)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 3)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 4)
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, first_moved, 0),
    "local.get",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, second_moved, 0),
    "local.get",
  )
  code_pushing_expect_op(func, @ir.hot_root_get(func, 5), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 6), "drop")
}

///|
test "code-pushing preserves order when moving multiple SFA sets after dropped value if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32 i32)
      #|    i32.const 7
      #|    local.set 1
      #|    i32.const 9
      #|    local.set 2
      #|    local.get 0
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      i32.const 2
      #|    end
      #|    drop
      #|    local.get 1
      #|    drop
      #|    local.get 2
      #|    drop))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 7)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "nop")
  let dropped_if = @ir.hot_root_get(func, 2)
  code_pushing_expect_op(func, dropped_if, "drop")
  code_pushing_expect_op(func, @ir.hot_child_get(func, dropped_if, 0), "if")
  let first_moved = @ir.hot_root_get(func, 3)
  let second_moved = @ir.hot_root_get(func, 4)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 5), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 6), "drop")
}

///|
test "code-pushing preserves order through nop-separated multi-set window after dropped value if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32 i32)
      #|    i32.const 7
      #|    local.set 1
      #|    nop
      #|    i32.const 9
      #|    local.set 2
      #|    local.get 0
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      i32.const 2
      #|    end
      #|    drop
      #|    local.get 1
      #|    drop
      #|    local.get 2
      #|    drop))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 8)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 2), "nop")
  let dropped_if = @ir.hot_root_get(func, 3)
  code_pushing_expect_op(func, dropped_if, "drop")
  code_pushing_expect_op(func, @ir.hot_child_get(func, dropped_if, 0), "if")
  let first_moved = @ir.hot_root_get(func, 4)
  let second_moved = @ir.hot_root_get(func, 5)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 6), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 7), "drop")
}

///|
test "code-pushing preserves order through drop-const-separated multi-set window after dropped value if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32 i32)
      #|    i32.const 7
      #|    local.set 1
      #|    i32.const 99
      #|    drop
      #|    i32.const 9
      #|    local.set 2
      #|    local.get 0
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      i32.const 2
      #|    end
      #|    drop
      #|    local.get 1
      #|    drop
      #|    local.get 2
      #|    drop))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 8)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 2), "nop")
  let dropped_if = @ir.hot_root_get(func, 3)
  code_pushing_expect_op(func, dropped_if, "drop")
  code_pushing_expect_op(func, @ir.hot_child_get(func, dropped_if, 0), "if")
  let first_moved = @ir.hot_root_get(func, 4)
  let second_moved = @ir.hot_root_get(func, 5)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 6), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 7), "drop")
}

///|
test "code-pushing preserves order when moving multiple local-copy SFA sets after dropped value if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32 i32 i32) (local i32 i32)
      #|    local.get 1
      #|    local.set 3
      #|    local.get 2
      #|    local.set 4
      #|    local.get 0
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      i32.const 2
      #|    end
      #|    drop
      #|    local.get 3
      #|    drop
      #|    local.get 4
      #|    drop))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 7)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "nop")
  let dropped_if = @ir.hot_root_get(func, 2)
  code_pushing_expect_op(func, dropped_if, "drop")
  code_pushing_expect_op(func, @ir.hot_child_get(func, dropped_if, 0), "if")
  let first_moved = @ir.hot_root_get(func, 3)
  let second_moved = @ir.hot_root_get(func, 4)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 3)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 4)
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, first_moved, 0),
    "local.get",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, second_moved, 0),
    "local.get",
  )
  code_pushing_expect_op(func, @ir.hot_root_get(func, 5), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 6), "drop")
}

///|
test "code-pushing moves pure SFA set after dropped value if before later use" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32)
      #|    i32.const 7
      #|    local.set 1
      #|    local.get 0
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      i32.const 2
      #|    end
      #|    drop
      #|    local.get 1
      #|    drop))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 4)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  let dropped_if = @ir.hot_root_get(func, 1)
  code_pushing_expect_op(func, dropped_if, "drop")
  code_pushing_expect_op(func, @ir.hot_child_get(func, dropped_if, 0), "if")
  let moved_set = @ir.hot_root_get(func, 2)
  code_pushing_expect_op(func, moved_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, moved_set).imm0, 1)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 3), "drop")
}

///|
test "code-pushing keeps SFA set before dropped if when the dropped if reads it" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (local i32)
        #|    i32.const 7
        #|    local.set 0
        #|    local.get 0
        #|    if (result i32)
        #|      i32.const 1
        #|    else
        #|      i32.const 2
        #|    end
        #|    drop
        #|    local.get 0
        #|    drop))
        #|
      ),
      ["code-pushing"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected guarded dropped-if success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(
    pretty.contains("(local.set (Local 0))(local.get (Local 0))(if"),
    msg=pretty,
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[code-pushing]:mutated") }),
    msg=trace.to_string(),
  )
}

///|
test "code-pushing moves pure SFA set after br_if before later same-block use" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 1
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "br_if")
  let moved_set = @ir.hot_region_get(func, body_ref, 2)
  code_pushing_expect_op(func, moved_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, moved_set).imm0, 1)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "drop")
}

///|
test "code-pushing moves pure SFA set after loop-target br_if before later same-loop use" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32)
      #|    (loop $top
      #|      i32.const 7
      #|      local.set 1
      #|      local.get 0
      #|      br_if $top
      #|      local.get 1
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let loop_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, loop_id, "loop")
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "br_if")
  let moved_set = @ir.hot_region_get(func, body_ref, 2)
  code_pushing_expect_op(func, moved_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, moved_set).imm0, 1)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "drop")
}

///|
test "code-pushing preserves order when moving multiple SFA sets after loop-target br_if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32 i32)
      #|    (loop $top
      #|      i32.const 7
      #|      local.set 1
      #|      i32.const 9
      #|      local.set 2
      #|      local.get 0
      #|      br_if $top
      #|      local.get 1
      #|      drop
      #|      local.get 2
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let loop_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, loop_id, "loop")
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 7)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  let first_moved = @ir.hot_region_get(func, body_ref, 3)
  let second_moved = @ir.hot_region_get(func, body_ref, 4)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 5), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 6), "drop")
}

///|
test "code-pushing preserves order through drop-const-separated multi-set window after loop-target br_if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32 i32)
      #|    (loop $top
      #|      i32.const 7
      #|      local.set 1
      #|      i32.const 99
      #|      drop
      #|      i32.const 9
      #|      local.set 2
      #|      local.get 0
      #|      br_if $top
      #|      local.get 1
      #|      drop
      #|      local.get 2
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let loop_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, loop_id, "loop")
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 8)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "br_if")
  let first_moved = @ir.hot_region_get(func, body_ref, 4)
  let second_moved = @ir.hot_region_get(func, body_ref, 5)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 6), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 7), "drop")
}

///|
test "code-pushing preserves order when moving multiple local-copy SFA sets after loop-target br_if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32 i32 i32) (local i32 i32)
      #|    (loop $top
      #|      local.get 1
      #|      local.set 3
      #|      local.get 2
      #|      local.set 4
      #|      local.get 0
      #|      br_if $top
      #|      local.get 3
      #|      drop
      #|      local.get 4
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let loop_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, loop_id, "loop")
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 7)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  let first_moved = @ir.hot_region_get(func, body_ref, 3)
  let second_moved = @ir.hot_region_get(func, body_ref, 4)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 3)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 4)
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, first_moved, 0),
    "local.get",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, second_moved, 0),
    "local.get",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 5), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 6), "drop")
}

///|
test "code-pushing preserves order when moving multiple SFA sets after br_if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32 i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      i32.const 9
      #|      local.set 2
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 1
      #|      drop
      #|      local.get 2
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 7)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  let first_moved = @ir.hot_region_get(func, body_ref, 3)
  let second_moved = @ir.hot_region_get(func, body_ref, 4)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 5), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 6), "drop")
}

///|
test "code-pushing preserves order through nop-separated multi-set window after br_if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32 i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      nop
      #|      i32.const 9
      #|      local.set 2
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 1
      #|      drop
      #|      local.get 2
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 8)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "br_if")
  let first_moved = @ir.hot_region_get(func, body_ref, 4)
  let second_moved = @ir.hot_region_get(func, body_ref, 5)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 6), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 7), "drop")
}

///|
test "code-pushing preserves order through drop-const-separated multi-set window after br_if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32 i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      i32.const 99
      #|      drop
      #|      i32.const 9
      #|      local.set 2
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 1
      #|      drop
      #|      local.get 2
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 8)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "br_if")
  let first_moved = @ir.hot_region_get(func, body_ref, 4)
  let second_moved = @ir.hot_region_get(func, body_ref, 5)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 6), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 7), "drop")
}

///|
test "code-pushing preserves order through local-get-separated multi-set window after if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32 i32) (local i32 i32)
      #|    i32.const 7
      #|    local.set 2
      #|    local.get 0
      #|    drop
      #|    i32.const 9
      #|    local.set 3
      #|    local.get 1
      #|    if
      #|      nop
      #|    end
      #|    local.get 2
      #|    drop
      #|    local.get 3
      #|    drop))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 8)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 2), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 3), "if")
  let first_moved = @ir.hot_root_get(func, 4)
  let second_moved = @ir.hot_root_get(func, 5)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 2)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 3)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 6), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 7), "drop")
}

///|
test "code-pushing preserves order through local-get-separated multi-set window after dropped value if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32 i32) (local i32 i32)
      #|    i32.const 7
      #|    local.set 2
      #|    local.get 0
      #|    drop
      #|    i32.const 9
      #|    local.set 3
      #|    local.get 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      i32.const 2
      #|    end
      #|    drop
      #|    local.get 2
      #|    drop
      #|    local.get 3
      #|    drop))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 8)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 2), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 3), "drop")
  let first_moved = @ir.hot_root_get(func, 4)
  let second_moved = @ir.hot_root_get(func, 5)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 2)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 3)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 6), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 7), "drop")
}

///|
test "code-pushing preserves order through local-get-separated multi-set window after loop-target br_if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32 i32) (local i32 i32)
      #|    (loop $top
      #|      i32.const 7
      #|      local.set 2
      #|      local.get 0
      #|      drop
      #|      i32.const 9
      #|      local.set 3
      #|      local.get 1
      #|      br_if $top
      #|      local.get 2
      #|      drop
      #|      local.get 3
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let loop_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, loop_id, "loop")
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 8)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "br_if")
  let first_moved = @ir.hot_region_get(func, body_ref, 4)
  let second_moved = @ir.hot_region_get(func, body_ref, 5)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 2)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 3)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 6), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 7), "drop")
}

///|
test "code-pushing preserves order through local-get-separated multi-set window after br_if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32 i32) (local i32 i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 2
      #|      local.get 0
      #|      drop
      #|      i32.const 9
      #|      local.set 3
      #|      local.get 1
      #|      br_if $exit
      #|      local.get 2
      #|      drop
      #|      local.get 3
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 8)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "br_if")
  let first_moved = @ir.hot_region_get(func, body_ref, 4)
  let second_moved = @ir.hot_region_get(func, body_ref, 5)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 2)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 3)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 6), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 7), "drop")
}

///|
test "code-pushing preserves order through global-get-separated multi-set window after if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (global i32 (i32.const 42))
      #|  (func (param i32) (local i32 i32)
      #|    i32.const 7
      #|    local.set 1
      #|    global.get 0
      #|    drop
      #|    i32.const 9
      #|    local.set 2
      #|    local.get 0
      #|    if
      #|      nop
      #|    end
      #|    local.get 1
      #|    drop
      #|    local.get 2
      #|    drop))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 8)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 2), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 3), "if")
  let first_moved = @ir.hot_root_get(func, 4)
  let second_moved = @ir.hot_root_get(func, 5)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 6), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 7), "drop")
}

///|
test "code-pushing preserves order through global-get-separated multi-set window after dropped value if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (global i32 (i32.const 42))
      #|  (func (param i32) (local i32 i32)
      #|    i32.const 7
      #|    local.set 1
      #|    global.get 0
      #|    drop
      #|    i32.const 9
      #|    local.set 2
      #|    local.get 0
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      i32.const 2
      #|    end
      #|    drop
      #|    local.get 1
      #|    drop
      #|    local.get 2
      #|    drop))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 8)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 2), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 3), "drop")
  let first_moved = @ir.hot_root_get(func, 4)
  let second_moved = @ir.hot_root_get(func, 5)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 6), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 7), "drop")
}

///|
test "code-pushing keeps global-get-separated multi-set window before br_if boundary" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (global i32 (i32.const 42))
      #|  (func (param i32) (local i32 i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      global.get 0
      #|      drop
      #|      i32.const 9
      #|      local.set 2
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 1
      #|      drop
      #|      local.get 2
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 6)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "drop")
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 2),
    "local.set",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "br_if")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 4), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 5), "drop")
}

///|
test "code-pushing moves pure SFA set after dropped br_if with branch value" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (result i32) (local i32)
      #|    (block $exit (result i32)
      #|      i32.const 7
      #|      local.set 1
      #|      (drop
      #|        (br_if $exit
      #|          (i32.const 42)
      #|          (local.get 0)))
      #|      local.get 1))
      #|)
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  let mut branch_idx = -1
  let mut moved_idx = -1
  for idx = 0; idx < @ir.hot_region_root_count(func, body_ref); idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, body_ref, idx)
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::BrIf => branch_idx = idx
      @ir.HotOp::Drop if @ir.hot_child_count(func, root_id) == 1 => {
        let child_id = @ir.hot_child_get(func, root_id, 0)
        match @ir.hot_node_get(func, child_id).op {
          @ir.HotOp::BrIf => branch_idx = idx
          _ => ()
        }
      }
      @ir.HotOp::LocalSet if @ir.hot_node_get(func, root_id).imm0 == 1 =>
        moved_idx = idx
      _ => ()
    }
  }
  assert_true(branch_idx > 0, msg="expected branch after original nop")
  assert_true(moved_idx > branch_idx, msg="expected local.set after br_if")
}

///|
test "code-pushing keeps pure SFA set before dropped br_if branch value that reads it" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (result i32) (local i32)
      #|    (block $exit (result i32)
      #|      i32.const 7
      #|      local.set 1
      #|      (drop
      #|        (br_if $exit
      #|          (local.get 1)
      #|          (local.get 0)))
      #|      local.get 1))
      #|)
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  let mut branch_idx = -1
  let mut set_idx = -1
  for idx = 0; idx < @ir.hot_region_root_count(func, body_ref); idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, body_ref, idx)
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::BrIf => branch_idx = idx
      @ir.HotOp::LocalSet if @ir.hot_node_get(func, root_id).imm0 == 1 =>
        set_idx = idx
      _ => ()
    }
  }
  assert_true(set_idx >= 0 && branch_idx > set_idx)
}

///|
test "code-pushing preserves order moving multiple SFA sets after dropped br_if branch value" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (result i32) (local i32 i32)
      #|    (block $exit (result i32)
      #|      i32.const 2
      #|      local.set 1
      #|      i32.const 3
      #|      local.set 2
      #|      (drop
      #|        (br_if $exit
      #|          (i32.const 7)
      #|          (local.get 0)))
      #|      local.get 1
      #|      drop
      #|      local.get 2
      #|      drop
      #|      i32.const 0))
      #|)
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "nop")
  let mut branch_idx = -1
  let first_moved = @ir.hot_region_get(func, body_ref, 3)
  let second_moved = @ir.hot_region_get(func, body_ref, 4)
  for idx = 0; idx < @ir.hot_region_root_count(func, body_ref); idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, body_ref, idx)
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::BrIf => branch_idx = idx
      @ir.HotOp::Drop if @ir.hot_child_count(func, root_id) == 1 => {
        let child_id = @ir.hot_child_get(func, root_id, 0)
        match @ir.hot_node_get(func, child_id).op {
          @ir.HotOp::BrIf => branch_idx = idx
          _ => ()
        }
      }
      _ => ()
    }
  }
  assert_true(branch_idx == 2, msg="expected branch-value br_if after nops")
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
}

///|
fn code_pushing_br_on_null_fixture(
  multi_set : Bool,
  operand_reads_moved : Bool,
) -> @ir.HotFunc {
  let extern_ref = @lib.ValType::externref()
  let func = if operand_reads_moved {
    @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[extern_ref]))
  } else {
    @ir.HotFunc::new(
      locals=@ir.HotLocals::new(
        params=[extern_ref],
        locals=if multi_set {
          [@lib.ValType::i32(), @lib.ValType::i32()]
        } else {
          [@lib.ValType::i32()]
        },
      ),
    )
  }
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let target = @ir.hot_control_node_label(func, block_id)
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let nullable_extern = @lib.RefType::new(true, extern_heap)
  let nonnull_extern = @lib.ValType::ref_type(
    @lib.RefType::new(false, extern_heap),
  )
  let body : Array[Int] = []
  if operand_reads_moved {
    body.push(
      @ir.hot_build_local_set(
        func,
        0,
        @ir.hot_build_ref_null(func, nullable_extern),
      ),
    )
  } else {
    body.push(
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(7)),
      ),
    )
    if multi_set {
      body.push(
        @ir.hot_build_local_set(
          func,
          2,
          @ir.hot_build_const_i32(func, @lib.I32(9)),
        ),
      )
    }
  }
  let branch_input = @ir.hot_build_local_get(
    func,
    if operand_reads_moved {
      0
    } else {
      0
    },
  )
  let br_on_null = @ir.hot_build_node(
    func,
    @ir.HotOp::br_on_null(),
    @ir.hot_type_intern_value(func, nonnull_extern),
    imm0=target,
    children=[branch_input],
  )
  body.push(@ir.hot_build_drop(func, br_on_null))
  if operand_reads_moved {
    body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 0)))
  } else {
    body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)))
    if multi_set {
      body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 2)))
    }
  }
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, block_id),
    body,
  )
  @ir.hot_root_append(func, block_id)
  code_pushing_test_run_hot_func(func)
}

///|
test "code-pushing moves pure SFA set after dropped br_on_null before later same-block use" {
  let func = code_pushing_br_on_null_fixture(false, false)

  let block_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  let branch_drop = @ir.hot_region_get(func, body_ref, 1)
  code_pushing_expect_op(func, branch_drop, "drop")
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_null",
  )
  let moved_set = @ir.hot_region_get(func, body_ref, 2)
  code_pushing_expect_op(func, moved_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, moved_set).imm0, 1)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "drop")
}

///|
test "code-pushing preserves order moving multiple SFA sets after dropped br_on_null" {
  let func = code_pushing_br_on_null_fixture(true, false)

  let block_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 7)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "nop")
  let branch_drop = @ir.hot_region_get(func, body_ref, 2)
  code_pushing_expect_op(func, branch_drop, "drop")
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_null",
  )
  let first_moved = @ir.hot_region_get(func, body_ref, 3)
  let second_moved = @ir.hot_region_get(func, body_ref, 4)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 5), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 6), "drop")
}

///|
test "code-pushing keeps SFA set before dropped br_on_null operand that reads it" {
  let func = code_pushing_br_on_null_fixture(false, true)

  let block_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 3)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  let branch_drop = @ir.hot_region_get(func, body_ref, 1)
  code_pushing_expect_op(func, branch_drop, "drop")
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_null",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "drop")
}

///|
fn code_pushing_br_on_non_null_fixture(
  multi_set : Bool,
  operand_reads_moved : Bool,
) -> @ir.HotFunc {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::externref()
  let nullable_extern = @lib.RefType::new(true, extern_heap)
  let func = if operand_reads_moved {
    @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[extern_ref]))
  } else {
    @ir.HotFunc::new(
      locals=@ir.HotLocals::new(
        params=[extern_ref],
        locals=if multi_set {
          [@lib.ValType::i32(), @lib.ValType::i32()]
        } else {
          [@lib.ValType::i32()]
        },
      ),
    )
  }
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, extern_ref),
  )
  let block_id = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(extern_ref),
    [],
  )
  let target = @ir.hot_control_node_label(func, block_id)
  let body : Array[Int] = []
  if operand_reads_moved {
    body.push(
      @ir.hot_build_local_set(
        func,
        0,
        @ir.hot_build_ref_null(func, nullable_extern),
      ),
    )
  } else {
    body.push(
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(7)),
      ),
    )
    if multi_set {
      body.push(
        @ir.hot_build_local_set(
          func,
          2,
          @ir.hot_build_const_i32(func, @lib.I32(9)),
        ),
      )
    }
  }
  let branch_input = @ir.hot_build_local_get(
    func,
    if operand_reads_moved {
      0
    } else {
      0
    },
  )
  body.push(
    @ir.hot_build_node(
      func,
      @ir.HotOp::br_on_non_null(),
      @ir.hot_type_void(func),
      imm0=target,
      children=[branch_input],
    ),
  )
  if operand_reads_moved {
    body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 0)))
  } else {
    body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)))
    if multi_set {
      body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 2)))
    }
  }
  body.push(@ir.hot_build_ref_null(func, nullable_extern))
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, block_id),
    body,
  )
  @ir.hot_root_append(func, block_id)
  code_pushing_test_run_hot_func(func)
}

///|
test "code-pushing moves pure SFA set after br_on_non_null before later same-block use" {
  let func = code_pushing_br_on_non_null_fixture(false, false)

  let block_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 1),
    "br_on_non_null",
  )
  let moved_set = @ir.hot_region_get(func, body_ref, 2)
  code_pushing_expect_op(func, moved_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, moved_set).imm0, 1)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "drop")
}

///|
test "code-pushing preserves order moving multiple SFA sets after br_on_non_null" {
  let func = code_pushing_br_on_non_null_fixture(true, false)

  let block_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 8)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "nop")
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 2),
    "br_on_non_null",
  )
  let first_moved = @ir.hot_region_get(func, body_ref, 3)
  let second_moved = @ir.hot_region_get(func, body_ref, 4)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 5), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 6), "drop")
}

///|
test "code-pushing keeps SFA set before br_on_non_null operand that reads it" {
  let func = code_pushing_br_on_non_null_fixture(false, true)

  let block_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 1),
    "br_on_non_null",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "drop")
}

///|
fn code_pushing_br_on_non_null_loop_boundary_fixture() -> @ir.HotFunc {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::externref()
  let nullable_extern = @lib.RefType::new(true, extern_heap)
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[extern_ref], locals=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, extern_ref),
  )
  let loop_id = @ir.hot_build_loop(func, @lib.BlockType::val_type(extern_ref), [])
  let target = @ir.hot_control_node_label(func, loop_id)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, loop_id), [
    @ir.hot_build_local_set(func, 1, @ir.hot_build_const_i32(func, @lib.I32(7))),
    @ir.hot_build_node(
      func,
      @ir.HotOp::br_on_non_null(),
      @ir.hot_type_void(func),
      imm0=target,
      children=[@ir.hot_build_local_get(func, 0)],
    ),
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
    @ir.hot_build_ref_null(func, nullable_extern),
  ])
  @ir.hot_root_append(func, loop_id)
  code_pushing_test_run_hot_func(func)
}

///|
test "code-pushing keeps loop-label br_on_non_null window stationary" {
  let func = code_pushing_br_on_non_null_loop_boundary_fixture()

  let loop_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 1),
    "br_on_non_null",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "drop")
}

///|
fn code_pushing_br_on_cast_loop_boundary_fixture() -> @ir.HotFunc {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let nullable_i31 = @lib.RefType::new(true, i31_heap)
  let nullable_i31_val = @lib.ValType::ref_type(nullable_i31)
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[any_ref], locals=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, nullable_i31_val),
  )
  let loop_id = @ir.hot_build_loop(
    func,
    @lib.BlockType::val_type(nullable_i31_val),
    [],
  )
  let target = @ir.hot_control_node_label(func, loop_id)
  let branch_payload = @ir.hot_alloc_instr_payload(
    func,
    @ir.HotInstrPayload::new(
      @lib.Instruction::br_on_cast(
        @lib.LabelIdx::new(0U),
        true,
        any_heap,
        true,
        i31_heap,
      ),
    ),
  )
  let br_on_cast = @ir.hot_build_node(
    func,
    @ir.HotOp::br_on_cast(),
    @ir.hot_type_intern_value(func, any_ref),
    imm0=target,
    imm1=branch_payload,
    children=[@ir.hot_build_local_get(func, 0)],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, loop_id), [
    @ir.hot_build_local_set(func, 1, @ir.hot_build_const_i32(func, @lib.I32(7))),
    @ir.hot_build_drop(func, br_on_cast),
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
    @ir.hot_build_ref_null(func, nullable_i31),
  ])
  @ir.hot_root_append(func, loop_id)
  code_pushing_test_run_hot_func(func)
}

///|
test "code-pushing keeps loop-label br_on_cast window stationary" {
  let func = code_pushing_br_on_cast_loop_boundary_fixture()

  let loop_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  let branch_drop = @ir.hot_region_get(func, body_ref, 1)
  code_pushing_expect_op(func, branch_drop, "drop")
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_cast",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "drop")
}

///|
fn code_pushing_br_on_cast_fail_loop_boundary_fixture() -> @ir.HotFunc {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let nullable_i31 = @lib.RefType::new(true, i31_heap)
  let nullable_i31_val = @lib.ValType::ref_type(nullable_i31)
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[any_ref], locals=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, any_ref))
  let loop_id = @ir.hot_build_loop(func, @lib.BlockType::val_type(any_ref), [])
  let target = @ir.hot_control_node_label(func, loop_id)
  let branch_payload = @ir.hot_alloc_instr_payload(
    func,
    @ir.HotInstrPayload::new(
      @lib.Instruction::br_on_cast_fail(
        @lib.LabelIdx::new(0U),
        true,
        any_heap,
        true,
        i31_heap,
      ),
    ),
  )
  let br_on_cast_fail = @ir.hot_build_node(
    func,
    @ir.HotOp::br_on_cast_fail(),
    @ir.hot_type_intern_value(func, nullable_i31_val),
    imm0=target,
    imm1=branch_payload,
    children=[@ir.hot_build_local_get(func, 0)],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, loop_id), [
    @ir.hot_build_local_set(func, 1, @ir.hot_build_const_i32(func, @lib.I32(7))),
    @ir.hot_build_drop(func, br_on_cast_fail),
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
    @ir.hot_build_ref_null(func, @lib.RefType::new(true, any_heap)),
  ])
  @ir.hot_root_append(func, loop_id)
  code_pushing_test_run_hot_func(func)
}

///|
test "code-pushing keeps loop-label br_on_cast_fail window stationary" {
  let func = code_pushing_br_on_cast_fail_loop_boundary_fixture()

  let loop_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  let branch_drop = @ir.hot_region_get(func, body_ref, 1)
  code_pushing_expect_op(func, branch_drop, "drop")
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_cast_fail",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "drop")
}

///|
fn code_pushing_br_on_cast_fixture(
  multi_set : Bool,
  operand_reads_moved : Bool,
) -> @ir.HotFunc {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let nullable_i31 = @lib.RefType::new(true, i31_heap)
  let nullable_i31_val = @lib.ValType::ref_type(nullable_i31)
  let func = if operand_reads_moved {
    @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[any_ref]))
  } else {
    @ir.HotFunc::new(
      locals=@ir.HotLocals::new(
        params=[any_ref],
        locals=if multi_set {
          [@lib.ValType::i32(), @lib.ValType::i32()]
        } else {
          [@lib.ValType::i32()]
        },
      ),
    )
  }
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, nullable_i31_val),
  )
  let block_id = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(nullable_i31_val),
    [],
  )
  let target = @ir.hot_control_node_label(func, block_id)
  let body : Array[Int] = []
  if operand_reads_moved {
    body.push(
      @ir.hot_build_local_set(
        func,
        0,
        @ir.hot_build_ref_null(func, @lib.RefType::new(true, any_heap)),
      ),
    )
  } else {
    body.push(
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(7)),
      ),
    )
    if multi_set {
      body.push(
        @ir.hot_build_local_set(
          func,
          2,
          @ir.hot_build_const_i32(func, @lib.I32(9)),
        ),
      )
    }
  }
  let branch_input = @ir.hot_build_local_get(
    func,
    if operand_reads_moved {
      0
    } else {
      0
    },
  )
  let branch_payload = @ir.hot_alloc_instr_payload(
    func,
    @ir.HotInstrPayload::new(
      @lib.Instruction::br_on_cast(
        @lib.LabelIdx::new(0U),
        true,
        any_heap,
        true,
        i31_heap,
      ),
    ),
  )
  let br_on_cast = @ir.hot_build_node(
    func,
    @ir.HotOp::br_on_cast(),
    @ir.hot_type_intern_value(func, any_ref),
    imm0=target,
    imm1=branch_payload,
    children=[branch_input],
  )
  body.push(@ir.hot_build_drop(func, br_on_cast))
  if operand_reads_moved {
    body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 0)))
  } else {
    body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)))
    if multi_set {
      body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 2)))
    }
  }
  body.push(@ir.hot_build_ref_null(func, nullable_i31))
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, block_id),
    body,
  )
  @ir.hot_root_append(func, block_id)
  code_pushing_test_run_hot_func(func)
}

///|
test "code-pushing moves pure SFA set after br_on_cast before later same-block use" {
  let func = code_pushing_br_on_cast_fixture(false, false)

  let block_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  let branch_drop = @ir.hot_region_get(func, body_ref, 1)
  code_pushing_expect_op(func, branch_drop, "drop")
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_cast",
  )
  let moved_set = @ir.hot_region_get(func, body_ref, 2)
  code_pushing_expect_op(func, moved_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, moved_set).imm0, 1)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "drop")
}

///|
test "code-pushing preserves order moving multiple SFA sets after br_on_cast" {
  let func = code_pushing_br_on_cast_fixture(true, false)

  let block_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 8)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "nop")
  let branch_drop = @ir.hot_region_get(func, body_ref, 2)
  code_pushing_expect_op(func, branch_drop, "drop")
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_cast",
  )
  let first_moved = @ir.hot_region_get(func, body_ref, 3)
  let second_moved = @ir.hot_region_get(func, body_ref, 4)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 5), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 6), "drop")
}

///|
test "code-pushing keeps SFA set before br_on_cast operand that reads it" {
  let func = code_pushing_br_on_cast_fixture(false, true)

  let block_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  let branch_drop = @ir.hot_region_get(func, body_ref, 1)
  code_pushing_expect_op(func, branch_drop, "drop")
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_cast",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "drop")
}

///|
fn code_pushing_br_on_cast_fail_fixture(
  multi_set : Bool,
  operand_reads_moved : Bool,
) -> @ir.HotFunc {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let nullable_i31 = @lib.RefType::new(true, i31_heap)
  let nullable_i31_val = @lib.ValType::ref_type(nullable_i31)
  let func = if operand_reads_moved {
    @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[any_ref]))
  } else {
    @ir.HotFunc::new(
      locals=@ir.HotLocals::new(
        params=[any_ref],
        locals=if multi_set {
          [@lib.ValType::i32(), @lib.ValType::i32()]
        } else {
          [@lib.ValType::i32()]
        },
      ),
    )
  }
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, any_ref))
  let block_id = @ir.hot_build_block(func, @lib.BlockType::val_type(any_ref), [])
  let target = @ir.hot_control_node_label(func, block_id)
  let body : Array[Int] = []
  if operand_reads_moved {
    body.push(
      @ir.hot_build_local_set(
        func,
        0,
        @ir.hot_build_ref_null(func, @lib.RefType::new(true, any_heap)),
      ),
    )
  } else {
    body.push(
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(7)),
      ),
    )
    if multi_set {
      body.push(
        @ir.hot_build_local_set(
          func,
          2,
          @ir.hot_build_const_i32(func, @lib.I32(9)),
        ),
      )
    }
  }
  let branch_input = @ir.hot_build_local_get(func, 0)
  let branch_payload = @ir.hot_alloc_instr_payload(
    func,
    @ir.HotInstrPayload::new(
      @lib.Instruction::br_on_cast_fail(
        @lib.LabelIdx::new(0U),
        true,
        any_heap,
        true,
        i31_heap,
      ),
    ),
  )
  let br_on_cast_fail = @ir.hot_build_node(
    func,
    @ir.HotOp::br_on_cast_fail(),
    @ir.hot_type_intern_value(func, nullable_i31_val),
    imm0=target,
    imm1=branch_payload,
    children=[branch_input],
  )
  body.push(@ir.hot_build_drop(func, br_on_cast_fail))
  if operand_reads_moved {
    body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 0)))
  } else {
    body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)))
    if multi_set {
      body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 2)))
    }
  }
  body.push(@ir.hot_build_ref_null(func, @lib.RefType::new(true, any_heap)))
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, block_id),
    body,
  )
  @ir.hot_root_append(func, block_id)
  code_pushing_test_run_hot_func(func)
}

///|
test "code-pushing moves pure SFA set after br_on_cast_fail before later same-block use" {
  let func = code_pushing_br_on_cast_fail_fixture(false, false)

  let block_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  let branch_drop = @ir.hot_region_get(func, body_ref, 1)
  code_pushing_expect_op(func, branch_drop, "drop")
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_cast_fail",
  )
  let moved_set = @ir.hot_region_get(func, body_ref, 2)
  code_pushing_expect_op(func, moved_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, moved_set).imm0, 1)
}

///|
test "code-pushing preserves order moving multiple SFA sets after br_on_cast_fail" {
  let func = code_pushing_br_on_cast_fail_fixture(true, false)

  let block_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 8)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "nop")
  let branch_drop = @ir.hot_region_get(func, body_ref, 2)
  code_pushing_expect_op(func, branch_drop, "drop")
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_cast_fail",
  )
  let first_moved = @ir.hot_region_get(func, body_ref, 3)
  let second_moved = @ir.hot_region_get(func, body_ref, 4)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 2)
}

///|
test "code-pushing keeps SFA set before br_on_cast_fail operand that reads it" {
  let func = code_pushing_br_on_cast_fail_fixture(false, true)

  let block_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  let branch_drop = @ir.hot_region_get(func, body_ref, 1)
  code_pushing_expect_op(func, branch_drop, "drop")
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_cast_fail",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "drop")
}

///|
fn code_pushing_br_on_cast_prefix_boundary_fixture(fail : Bool) -> @ir.HotFunc {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let nullable_i31 = @lib.RefType::new(true, i31_heap)
  let nullable_i31_val = @lib.ValType::ref_type(nullable_i31)
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[any_ref], locals=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [@lib.ValType::i32(), any_ref]),
  )
  let block_id = @ir.hot_build_resolved_block(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    [],
    [@lib.ValType::i32(), any_ref],
    [],
  )
  let target = @ir.hot_control_node_label(func, block_id)
  let branch_payload = @ir.hot_alloc_instr_payload(
    func,
    @ir.HotInstrPayload::new(
      if fail {
        @lib.Instruction::br_on_cast_fail(
          @lib.LabelIdx::new(0U),
          true,
          any_heap,
          true,
          i31_heap,
        )
      } else {
        @lib.Instruction::br_on_cast(
          @lib.LabelIdx::new(0U),
          true,
          any_heap,
          true,
          i31_heap,
        )
      },
    ),
  )
  let branch = @ir.hot_build_node(
    func,
    if fail {
      @ir.HotOp::br_on_cast_fail()
    } else {
      @ir.HotOp::br_on_cast()
    },
    @ir.hot_type_intern_value(
      func,
      if fail {
        nullable_i31_val
      } else {
        any_ref
      },
    ),
    imm0=target,
    imm1=branch_payload,
    children=[
      @ir.hot_build_const_i32(func, @lib.I32(42)),
      @ir.hot_build_local_get(func, 0),
    ],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block_id), [
    @ir.hot_build_local_set(func, 1, @ir.hot_build_const_i32(func, @lib.I32(7))),
    @ir.hot_build_drop(func, branch),
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
    @ir.hot_build_const_i32(func, @lib.I32(13)),
    @ir.hot_build_ref_null(func, @lib.RefType::new(true, any_heap)),
  ])
  @ir.hot_root_append(func, block_id)
  code_pushing_test_run_hot_func(func)
}

///|
test "code-pushing boundary keeps SFA set before br_on_cast prefix payload" {
  // Intentionally unsupported/Binaryen-stationary boundary: local Binaryen v130
  // keeps the pure set before a prefix-payload br_on_cast to a result block.
  let func = code_pushing_br_on_cast_prefix_boundary_fixture(false)

  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  let branch_drop = @ir.hot_region_get(func, body_ref, 1)
  code_pushing_expect_op(func, branch_drop, "drop")
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_cast",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "drop")
}

///|
test "code-pushing boundary keeps SFA set before br_on_cast_fail prefix payload" {
  // Intentionally unsupported/Binaryen-stationary boundary: local Binaryen v130
  // keeps the pure set before a prefix-payload br_on_cast_fail to a result block.
  let func = code_pushing_br_on_cast_prefix_boundary_fixture(true)

  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  let branch_drop = @ir.hot_region_get(func, body_ref, 1)
  code_pushing_expect_op(func, branch_drop, "drop")
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_cast_fail",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "drop")
}

///|
test "code-pushing boundary keeps pure SFA set before br_table switch push point" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      local.get 0
      #|      br_table $exit $exit
      #|      local.get 1
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 3)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 1),
    "br_table",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "drop")
}

///|
test "code-pushing boundary keeps SFA set before value br_table switch push point" {
  // Intentionally unsupported/Binaryen-stationary boundary: local Binaryen v130
  // keeps the pure set before a value-carrying br_table to a result block.
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (result i32) (local i32)
      #|    (block $exit (result i32)
      #|      i32.const 42
      #|      local.set 1
      #|      i32.const 7
      #|      local.get 0
      #|      br_table $exit $exit
      #|      local.get 1
      #|      drop
      #|      i32.const 9)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 1),
    "br_table",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "drop")
}

///|
test "code-pushing boundary keeps SFA set before multi-label br_table switch push point" {
  // Intentionally unsupported/Binaryen-stationary boundary: local Binaryen v130
  // keeps the pure set before a multi-target br_table window, even when one target
  // falls through to a later suffix read and another exits the outer block.
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32)
      #|    (block $outer
      #|      (block $inner
      #|        i32.const 7
      #|        local.set 1
      #|        local.get 0
      #|        br_table $inner $outer $inner
      #|        local.get 1
      #|        drop)
      #|      local.get 1
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let outer_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, outer_id, "block")
  let outer_body_ref = @ir.hot_region_body_ref(func, outer_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, outer_body_ref), 2)
  let inner_id = @ir.hot_region_get(func, outer_body_ref, 0)
  code_pushing_expect_op(func, inner_id, "block")
  let inner_body_ref = @ir.hot_region_body_ref(func, inner_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, inner_body_ref), 3)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, inner_body_ref, 0),
    "local.set",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, inner_body_ref, 1),
    "br_table",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, inner_body_ref, 2),
    "drop",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, outer_body_ref, 1),
    "drop",
  )
}

///|
test "code-pushing boundary keeps adjacent multi-set window before br_table switch push point" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32 i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      i32.const 9
      #|      local.set 2
      #|      local.get 0
      #|      br_table $exit $exit
      #|      local.get 1
      #|      drop
      #|      local.get 2
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 1),
    "local.set",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 2),
    "br_table",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 4), "drop")
}

///|
test "code-pushing moves pure SFA set past global.set before br_if push point" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (param i32) (local i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      i32.const 1
      #|      global.set $g
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 1
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  match @ir.hot_node_get(func, @ir.hot_region_get(func, body_ref, 1)).op {
    @ir.HotOp::GlobalSet => ()
    other => abort("expected global.set, got \{other}")
  }
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 3),
    "local.set",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 4), "drop")
}

///|
test "code-pushing moves pure SFA set past table.set before br_if push point" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (func (param i32) (local i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      i32.const 0
      #|      ref.null func
      #|      table.set 0
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 1
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  match @ir.hot_node_get(func, @ir.hot_region_get(func, body_ref, 1)).op {
    @ir.HotOp::TableSet => ()
    other => abort("expected table.set, got \{other}")
  }
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 3),
    "local.set",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 4), "drop")
}

///|
test "code-pushing moves pure SFA set past memory.store before br_if push point" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (memory 1)
      #|  (func (param i32) (local i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      i32.const 0
      #|      i32.const 42
      #|      i32.store
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 1
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  match @ir.hot_node_get(func, @ir.hot_region_get(func, body_ref, 1)).op {
    @ir.HotOp::Store => ()
    other => abort("expected store, got \{other}")
  }
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 3),
    "local.set",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 4), "drop")
}

///|
test "code-pushing moves pure SFA set past memory.grow before br_if push point" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (memory 1)
      #|  (func (param i32) (local i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      i32.const 1
      #|      memory.grow
      #|      drop
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 1
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  match @ir.hot_node_get(func, @ir.hot_region_get(func, body_ref, 1)).op {
    @ir.HotOp::Drop => ()
    other => abort("expected drop(memory.grow), got \{other}")
  }
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 3),
    "local.set",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 4), "drop")
}

///|
test "code-pushing moves pure SFA set past table.grow before br_if push point" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (func (param i32) (local i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      ref.null func
      #|      i32.const 1
      #|      table.grow 0
      #|      drop
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 1
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  match @ir.hot_node_get(func, @ir.hot_region_get(func, body_ref, 1)).op {
    @ir.HotOp::Drop => ()
    other => abort("expected drop(table.grow), got \{other}")
  }
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 3),
    "local.set",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 4), "drop")
}

///|
test "code-pushing moves pure SFA set past table.copy before br_if push point" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (table 2 funcref)
      #|  (func (param i32) (local i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      i32.const 1
      #|      i32.const 0
      #|      i32.const 1
      #|      table.copy 0 0
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 1
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  match @ir.hot_node_get(func, @ir.hot_region_get(func, body_ref, 1)).op {
    @ir.HotOp::TableCopy => ()
    other => abort("expected table.copy, got \{other}")
  }
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 3),
    "local.set",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 4), "drop")
}

///|
test "code-pushing moves pure SFA set past table.fill before br_if push point" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (table 2 funcref)
      #|  (func (param i32) (local i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      i32.const 0
      #|      ref.null func
      #|      i32.const 1
      #|      table.fill 0
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 1
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  match @ir.hot_node_get(func, @ir.hot_region_get(func, body_ref, 1)).op {
    @ir.HotOp::TableFill => ()
    other => abort("expected table.fill, got \{other}")
  }
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 3),
    "local.set",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 4), "drop")
}

///|
test "code-pushing moves pure SFA set past memory.fill before br_if push point" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (memory 1)
      #|  (func (param i32) (local i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      i32.const 0
      #|      i32.const 1
      #|      i32.const 4
      #|      memory.fill
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 1
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  match @ir.hot_node_get(func, @ir.hot_region_get(func, body_ref, 1)).op {
    @ir.HotOp::MemoryFill => ()
    other => abort("expected memory.fill, got \{other}")
  }
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 3),
    "local.set",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 4), "drop")
}

///|
test "code-pushing moves pure SFA set past memory.copy before br_if push point" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (memory 1)
      #|  (func (param i32) (local i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      i32.const 8
      #|      i32.const 0
      #|      i32.const 4
      #|      memory.copy
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 1
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  match @ir.hot_node_get(func, @ir.hot_region_get(func, body_ref, 1)).op {
    @ir.HotOp::MemoryCopy => ()
    other => abort("expected memory.copy, got \{other}")
  }
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 3),
    "local.set",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 4), "drop")
}

///|
test "code-pushing boundary keeps SFA set before call barrier and br_if push point" {
  // Intentionally unsupported/Binaryen-stationary boundary: local Binaryen v130
  // keeps the pure set before an intervening call that may observe ordered-before
  // effects before a later br_if push point.
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (local i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 0
      #|      call $callee
      #|      i32.const 1
      #|      br_if $exit
      #|      local.get 0
      #|      drop))
      #|  (func $callee))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "call")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "drop")
}

///|
test "code-pushing moves pure SFA set after throw_ref before later br_if push point" {
  // Binaryen-positive movement: local Binaryen v130 moves the pure set after
  // the later br_if even when an intervening throw_ref root cannot fall through.
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (local i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 0
      #|      ref.null exn
      #|      throw_ref
      #|      i32.const 1
      #|      drop
      #|      i32.const 2
      #|      br_if $exit
      #|      local.get 0
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 6)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "br_if")
  let moved_set = @ir.hot_region_get(func, body_ref, 4)
  code_pushing_expect_op(func, moved_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, moved_set).imm0, 0)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 5), "drop")
}

///|
test "code-pushing boundary keeps SFA set before plain throw and br_if push point" {
  // Intentionally unsupported/Binaryen-stationary boundary: local Binaryen v130
  // keeps the pure set before an intervening tag-based throw, unlike throw_ref.
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (tag $e)
      #|  (func (local i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 0
      #|      throw $e
      #|      i32.const 1
      #|      drop
      #|      i32.const 2
      #|      br_if $exit
      #|      local.get 0
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "throw")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "br_if")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 4), "drop")
}

///|
test "code-pushing boundary keeps SFA set before payload throw and br_if push point" {
  // Intentionally unsupported/Binaryen-stationary boundary: local Binaryen v130
  // keeps the pure set before an intervening tag-based throw with a payload.
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (tag $e (param i32))
      #|  (func (param i32) (local i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      i32.const 42
      #|      throw $e
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 1
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "throw")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "drop")
}

///|
test "code-pushing boundary keeps SFA set before rethrowing legacy try and br_if push point" {
  // Intentionally unsupported/Binaryen-stationary boundary: local Binaryen v130
  // keeps the pure set before a legacy try/catch root that can rethrow. The WAT
  // lifter currently lowers legacy rethrow to unreachable, so this fixture uses
  // direct HOT to keep the rethrow barrier visible to the pass.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let target = @ir.hot_control_node_label(func, block_id)
  let rethrow_block = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let rethrow_id = @ir.hot_build_node(
    func,
    @ir.HotOp::rethrow(),
    @ir.hot_type_intern_void(func),
    imm0=0,
    children=[],
  )
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, rethrow_block),
    [rethrow_id],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block_id), [
    @ir.hot_build_local_set(func, 1, @ir.hot_build_const_i32(func, @lib.I32(7))),
    rethrow_block,
    @ir.hot_build_br_if(func, target, @ir.hot_build_local_get(func, 0)),
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  ])
  @ir.hot_root_append(func, block_id)
  let func = code_pushing_test_run_hot_func(func)

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "block")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "drop")
}

///|
test "code-pushing boundary keeps SFA set before try_table and br_if push point" {
  // Intentionally unsupported/Binaryen-stationary boundary: local Binaryen v130
  // keeps the pure set before an intervening try_table with a catch target.
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (local i32)
      #|    (block $handler
      #|      (block $exit
      #|        i32.const 7
      #|        local.set 0
      #|        try_table (catch_all $handler)
      #|          i32.const 0
      #|          drop
      #|        end
      #|        i32.const 1
      #|        drop
      #|        i32.const 2
      #|        br_if $exit
      #|        local.get 0
      #|        drop))))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let handler_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, handler_id, "block")
  let handler_body_ref = @ir.hot_region_body_ref(func, handler_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, handler_body_ref), 1)
  let block_id = @ir.hot_region_get(func, handler_body_ref, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 1),
    "try_table",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "br_if")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 4), "drop")
}

///|
test "code-pushing boundary keeps SFA set before catch_all_ref try_table and br_if push point" {
  // Intentionally unsupported/Binaryen-stationary boundary: local Binaryen v130
  // keeps the pure set before an intervening try_table catch_all_ref target.
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32) (local i32)
      #|    (block $done
      #|      (block $handler (result exnref)
      #|        (block $exit
      #|          i32.const 7
      #|          local.set 1
      #|          try_table (catch_all_ref $handler)
      #|            i32.const 0
      #|            drop
      #|          end
      #|          local.get 0
      #|          br_if $exit
      #|          local.get 1
      #|          drop)
      #|        ref.null exn)
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let done_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, done_id, "block")
  let done_body_ref = @ir.hot_region_body_ref(func, done_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, done_body_ref), 1)
  let drop_id = @ir.hot_region_get(func, done_body_ref, 0)
  code_pushing_expect_op(func, drop_id, "drop")
  let handler_id = @ir.hot_child_get(func, drop_id, 0)
  code_pushing_expect_op(func, handler_id, "block")
  let handler_body_ref = @ir.hot_region_body_ref(func, handler_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, handler_body_ref), 2)
  let block_id = @ir.hot_region_get(func, handler_body_ref, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 1),
    "try_table",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "drop")
}

///|
test "code-pushing boundary keeps SFA set before payload catch try_table and br_if push point" {
  // Intentionally unsupported/Binaryen-stationary boundary: local Binaryen v130
  // keeps the pure set before an intervening try_table catch target that carries
  // a tag payload to its handler.
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (tag $e (param i32))
      #|  (func (param i32) (local i32)
      #|    (block $done
      #|      (block $handler (result i32)
      #|        (block $exit
      #|          i32.const 7
      #|          local.set 1
      #|          try_table (catch $e $handler)
      #|            i32.const 0
      #|            drop
      #|          end
      #|          local.get 0
      #|          br_if $exit
      #|          local.get 1
      #|          drop)
      #|        i32.const 0)
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let done_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, done_id, "block")
  let done_body_ref = @ir.hot_region_body_ref(func, done_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, done_body_ref), 1)
  let drop_id = @ir.hot_region_get(func, done_body_ref, 0)
  code_pushing_expect_op(func, drop_id, "drop")
  let handler_id = @ir.hot_child_get(func, drop_id, 0)
  code_pushing_expect_op(func, handler_id, "block")
  let handler_body_ref = @ir.hot_region_body_ref(func, handler_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, handler_body_ref), 2)
  let block_id = @ir.hot_region_get(func, handler_body_ref, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 1),
    "try_table",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "drop")
}

///|
test "code-pushing boundary keeps SFA set before catch_ref try_table and br_if push point" {
  // Intentionally unsupported/Binaryen-stationary boundary: local Binaryen v130
  // keeps the pure set before an intervening try_table catch_ref target that
  // carries both the tag payload and exception reference to its handler.
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (tag $e (param i32))
      #|  (func (param i32) (local i32)
      #|    (block $done
      #|      (block $handler (result i32 exnref)
      #|        (block $exit
      #|          i32.const 7
      #|          local.set 1
      #|          try_table (catch_ref $e $handler)
      #|            i32.const 0
      #|            drop
      #|          end
      #|          local.get 0
      #|          br_if $exit
      #|          local.get 1
      #|          drop)
      #|        i32.const 0
      #|        ref.null exn)
      #|      drop
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let done_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, done_id, "block")
  let done_body_ref = @ir.hot_region_body_ref(func, done_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, done_body_ref), 2)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, done_body_ref, 0),
    "drop",
  )
  let outer_drop_id = @ir.hot_region_get(func, done_body_ref, 1)
  code_pushing_expect_op(func, outer_drop_id, "drop")
  let handler_id = @ir.hot_child_get(func, outer_drop_id, 0)
  code_pushing_expect_op(func, handler_id, "block")
  let handler_body_ref = @ir.hot_region_body_ref(func, handler_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, handler_body_ref), 3)
  let block_id = @ir.hot_region_get(func, handler_body_ref, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 1),
    "try_table",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "drop")
}

///|
test "code-pushing boundary keeps SFA set before multi-catch try_table and br_if push point" {
  // Intentionally unsupported/Binaryen-stationary boundary: local Binaryen v130
  // keeps the pure set before an intervening try_table with multiple catch
  // clauses sharing a zero-arity handler.
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (tag $e)
      #|  (func (param i32) (local i32)
      #|    (block $handler
      #|      (block $exit
      #|        i32.const 7
      #|        local.set 1
      #|        try_table (catch $e $handler) (catch_all $handler)
      #|          i32.const 0
      #|          drop
      #|        end
      #|        local.get 0
      #|        br_if $exit
      #|        local.get 1
      #|        drop))))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let handler_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, handler_id, "block")
  let handler_body_ref = @ir.hot_region_body_ref(func, handler_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, handler_body_ref), 1)
  let block_id = @ir.hot_region_get(func, handler_body_ref, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 4)
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 1),
    "try_table",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 3), "drop")
}

///|
test "code-pushing moves pure SFA set after legacy try-lowered block before later br_if" {
  // Binaryen-positive movement: local Binaryen v130 moves the pure set after
  // a legacy try/catch root and the later br_if push point. The local WAT
  // fixture currently lowers this legacy try to a HOT block, so this guards the
  // observable movement but does not claim native HotOp::Try barrier coverage.
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (tag $e)
      #|  (func (param i32) (local i32)
      #|    (block $exit
      #|      i32.const 7
      #|      local.set 1
      #|      (try
      #|        (do
      #|          i32.const 0
      #|          drop)
      #|        (catch $e
      #|          i32.const 1
      #|          drop))
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 1
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "block")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  let moved_set = @ir.hot_region_get(func, body_ref, 3)
  code_pushing_expect_op(func, moved_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, moved_set).imm0, 1)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 4), "drop")
}

///|
test "code-pushing preserves order when moving multiple local-copy SFA sets after br_if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32 i32 i32) (local i32 i32)
      #|    (block $exit
      #|      local.get 1
      #|      local.set 3
      #|      local.get 2
      #|      local.set 4
      #|      local.get 0
      #|      br_if $exit
      #|      local.get 3
      #|      drop
      #|      local.get 4
      #|      drop)))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  let block_id = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, block_id, "block")
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 7)
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 1), "nop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 2), "br_if")
  let first_moved = @ir.hot_region_get(func, body_ref, 3)
  let second_moved = @ir.hot_region_get(func, body_ref, 4)
  code_pushing_expect_op(func, first_moved, "local.set")
  code_pushing_expect_op(func, second_moved, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved).imm0, 3)
  @debug.assert_eq(@ir.hot_node_get(func, second_moved).imm0, 4)
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, first_moved, 0),
    "local.get",
  )
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, second_moved, 0),
    "local.get",
  )
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 5), "drop")
  code_pushing_expect_op(func, @ir.hot_region_get(func, body_ref, 6), "drop")
}

///|
test "code-pushing keeps source-written local-copy set before if but moves independent copy" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (param i32 i32 i32) (local i32 i32)
      #|    local.get 1
      #|    local.set 3
      #|    local.get 2
      #|    local.set 4
      #|    local.get 0
      #|    if
      #|      i32.const 99
      #|      local.set 1
      #|    end
      #|    local.get 3
      #|    drop
      #|    local.get 4
      #|    drop))
      #|
    ),
  )

  @debug.assert_eq(@ir.hot_root_count(func), 6)
  let kept_source_sensitive_set = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, kept_source_sensitive_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, kept_source_sensitive_set).imm0, 3)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 2), "if")
  let moved_independent_set = @ir.hot_root_get(func, 3)
  code_pushing_expect_op(func, moved_independent_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, moved_independent_set).imm0, 4)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 4), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 5), "drop")
}

///|
test "code-pushing keeps SFA set before br_if when the br_if reads it" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (local i32)
        #|    (block $exit
        #|      i32.const 7
        #|      local.set 0
        #|      local.get 0
        #|      br_if $exit
        #|      local.get 0
        #|      drop)))
        #|
      ),
      ["code-pushing"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected guarded br_if success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(
    pretty.contains("(local.set (Local 0))(local.get (Local 0))(br_if"),
    msg=pretty,
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[code-pushing]:mutated") }),
    msg=trace.to_string(),
  )
}

///|
test "code-pushing keeps SFA set before if when the local is used before the if" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (param i32) (local i32)
        #|    i32.const 7
        #|    local.set 1
        #|    local.get 1
        #|    drop
        #|    local.get 0
        #|    if
        #|      nop
        #|    end
        #|    local.get 1
        #|    drop))
        #|
      ),
      ["code-pushing"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected guarded code-pushing success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(
    trace.any(fn(line) { line.contains("pass[code-pushing]:mutated") }),
    msg=trace.to_string(),
  )
}

///|
test "code-pushing keeps SFA set before if across an ordered-before barrier" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (global i32 (i32.const 9))
        #|  (memory 1)
        #|  (func (param i32) (local i32)
        #|    global.get 0
        #|    local.set 1
        #|    i32.const 0
        #|    i32.const 1
        #|    i32.store
        #|    local.get 0
        #|    if
        #|      nop
        #|    end
        #|    local.get 1
        #|    drop))
        #|
      ),
      ["code-pushing"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected guarded code-pushing success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(
    pretty.contains(
      "(global.get (Global 0))(local.set (Local 1))(i32.const I32(0))(i32.const I32(1))(i32.store",
    ),
    msg=pretty,
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[code-pushing]:mutated") }),
    msg=trace.to_string(),
  )
}

///|
test "code-pushing flattens dead typed block before unreachable" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (func (result i32)
      #|    i32.const 0
      #|    (block (result i32)
      #|      (f64.const 0)
      #|      unreachable)
      #|    unreachable))
      #|,
    ),
  )

  let ops : Array[String] = []
  for idx = 0; idx < @ir.hot_root_count(func); idx = idx + 1 {
    ops.push(@ir.hot_node_get(func, @ir.hot_root_get(func, idx)).op.to_string())
  }
  @debug.assert_eq(ops, ["Unreachable", "Const", "Const", "Unreachable"])
}

///|
test "code-pushing keeps unreachable block without dead parent context" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (block unreachable) nop))",
      ["code-pushing"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected guarded code-pushing success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("block"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(
    trace.any(fn(line) { line.contains("pass[code-pushing]:mutated") }),
    msg=trace.to_string(),
  )
}

///|
test "code-pushing keeps dead block with branch before unreachable" {
  let func = code_pushing_test_run_hot(
    "(module (func (block br 0 unreachable) unreachable))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "block")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "unreachable")
}

///|
test "code-pushing moves const local.set after if before nested later use" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if nop end (block local.get 1 drop)))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 4)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "if")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 2), "local.set")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 3), "block")
}

///|
test "code-pushing sinks global get past local-only setup into sole using if arm" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (global i32 (i32.const 9))
      #|  (func (param i32) (local i32 i32)
      #|    global.get 0
      #|    local.set 1
      #|    i32.const 4
      #|    local.set 2
      #|    local.get 0
      #|    if
      #|      local.get 2
      #|      drop
      #|      local.get 1
      #|      drop
      #|    end))
      #|,
    ),
  )

  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  let if_id = @ir.hot_root_get(func, @ir.hot_root_count(func) - 1)
  code_pushing_expect_op(func, if_id, "if")
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let mut saw_global_set = false
  for idx = 0; idx < @ir.hot_region_root_count(func, then_ref); idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, then_ref, idx)
    if @ir.hot_node_get(func, root_id).imm0 == 1 {
      code_pushing_expect_op(func, root_id, "local.set")
      match @ir.hot_node_get(func, @ir.hot_child_get(func, root_id, 0)).op {
        @ir.HotOp::GlobalGet => saw_global_set = true
        _ => ()
      }
    }
  }
  assert_true(saw_global_set)
}

///|
test "code-pushing sinks global get through value if before later side effect" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (global i32 (i32.const 9))
      #|  (memory 1)
      #|  (func (param i32) (local i32 i32)
      #|    global.get 0
      #|    local.set 2
      #|    local.get 0
      #|    i32.const 4
      #|    i32.sub
      #|    local.set 1
      #|    local.get 0
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      local.get 1
      #|    end
      #|    if
      #|      unreachable
      #|    end
      #|    i32.const 0
      #|    i32.const 1
      #|    i32.store
      #|    local.get 2
      #|    drop))
      #|,
    ),
  )

  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  let mut saw_moved_set = false
  for idx = 1; idx < @ir.hot_root_count(func); idx = idx + 1 {
    let root_id = @ir.hot_root_get(func, idx)
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::LocalSet if @ir.hot_node_get(func, root_id).imm0 == 2 =>
        saw_moved_set = true
      _ => ()
    }
  }
  assert_true(saw_moved_set)
}

///|
test "code-pushing sinks local.get set after unrelated effectful if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (memory 1)
      #|  (func (param i32) (local i32 i32 i32)
      #|    i32.const 9
      #|    local.set 3
      #|    local.get 3
      #|    local.set 1
      #|    i32.const 7
      #|    local.set 2
      #|    local.get 0
      #|    if
      #|      i32.const 0
      #|      i32.const 1
      #|      i32.store
      #|    end
      #|    local.get 1
      #|    drop))
      #|,
    ),
  )

  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "nop")
  let mut moved_set_idx = -1
  let mut if_idx = -1
  for idx = 0; idx < @ir.hot_root_count(func); idx = idx + 1 {
    let root_id = @ir.hot_root_get(func, idx)
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::If => if_idx = idx
      @ir.HotOp::LocalSet if @ir.hot_node_get(func, root_id).imm0 == 1 =>
        moved_set_idx = idx
      _ => ()
    }
  }
  assert_true(if_idx >= 0, msg="expected if root")
  assert_true(moved_set_idx > if_idx, msg="expected moved set after if")
}

///|
test "code-pushing sinks local.get set when source write is nested in previous root" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (memory 1)
      #|  (func (param i32) (local i32 i32 i32)
      #|    block (result i32)
      #|      i32.const 11
      #|      local.set 1
      #|      i32.const 22
      #|    end
      #|    local.set 3
      #|    local.get 1
      #|    local.set 2
      #|    local.get 0
      #|    if
      #|      i32.const 0
      #|      i32.const 1
      #|      i32.store
      #|    end
      #|    local.get 2
      #|    drop))
      #|,
    ),
  )

  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 3), "local.set")
}

///|
test "code-pushing sinks local.get set after immediately following effectful if" {
  let func = code_pushing_test_run_hot(
    (
      #|(module
      #|  (memory 1)
      #|  (func (param i32 i32) (local i32 i32)
      #|    local.get 0
      #|    local.set 3
      #|    local.get 3
      #|    local.set 2
      #|    local.get 1
      #|    if
      #|      i32.const 0
      #|      i32.const 1
      #|      i32.store
      #|    end
      #|    local.get 2
      #|    drop))
      #|,
    ),
  )

  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 3), "local.set")
}

///|
test "code-pushing keeps local.get set before multivalue value if" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (import "env" "triple" (func (param i32 i32) (result i32 i32 i32)))
        #|  (func (param i32 i32) (local i32 i32)
        #|    local.get 0
        #|    local.set 3
        #|    local.get 3
        #|    local.set 2
        #|    local.get 0
        #|    i32.const 10000
        #|    call 0
        #|    local.get 0
        #|    i32.const 10000
        #|    call 0
        #|    local.get 1
        #|    if (result i32)
        #|      i32.const 20
        #|    else
        #|      i32.const 30
        #|    end
        #|    drop
        #|    drop
        #|    drop
        #|    drop
        #|    drop
        #|    drop
        #|    drop
        #|    local.get 2
        #|    drop))
        #|,
      ),
      ["code-pushing"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected code-pushing pipeline success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(
    pretty.contains(
      "(local.get (Local 3))(local.set (Local 2))(local.get (Local 0))(i32.const I32(10000))(call (Func 0))",
    ),
    msg=pretty,
  )
}

///|
fn code_pushing_atomic_struct_get_fixture(
  use_atomic_store : Bool,
  use_if_arm : Bool,
) -> @ir.HotFunc {
  // Starshine's WAT surface cannot currently parse Binaryen's shared GC type
  // syntax from `code-pushing-atomics.wast`, so this fixture builds the HOT
  // shape directly: a non-null `struct.get` sourced from `local.get` before a
  // linear-memory atomic load/store.
  let nonnull_struct = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[nonnull_struct, @lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let source_ref = @ir.hot_build_local_get(func, 0)
  let struct_get = @ir.hot_build_heap(
    func,
    [@lib.ValType::i32()],
    @lib.Instruction::struct_get(@lib.TypeIdx::new(0U), @lib.U32::new(0U)),
    [source_ref],
  )
  let set_field = @ir.hot_build_local_set(func, 2, struct_get)
  let addr = @ir.hot_build_const_i32(func, @lib.I32(0))
  let memarg = @lib.MemArg::new(2U, None, 0UL)
  let atomic_memarg = @ir.hot_alloc_memarg(func, @ir.HotMemArg::new(memarg))
  let atomic_payload = @ir.hot_alloc_instr_payload(
    func,
    @ir.HotInstrPayload::new(
      if use_atomic_store {
        @lib.Instruction::i32_atomic_store(memarg)
      } else {
        @lib.Instruction::i32_atomic_load(memarg)
      },
    ),
  )
  let atomic_node = if use_atomic_store {
    @ir.hot_build_node(
      func,
      @ir.HotOp::atomic_op(),
      @ir.hot_type_void(func),
      imm0=atomic_memarg,
      imm1=atomic_payload,
      children=[addr, @ir.hot_build_const_i32(func, @lib.I32(42))],
    )
  } else {
    @ir.hot_build_node(
      func,
      @ir.HotOp::atomic_op(),
      @ir.hot_type_intern_value(func, @lib.ValType::i32()),
      imm0=atomic_memarg,
      imm1=atomic_payload,
      children=[addr],
    )
  }
  let atomic_root = if use_atomic_store {
    atomic_node
  } else {
    @ir.hot_build_drop(func, atomic_node)
  }
  let cond = @ir.hot_build_local_get(func, 1)
  let if_id = if use_if_arm {
    @ir.hot_build_if(func, @lib.BlockType::void_(), cond, [
      @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 2)),
    ])
  } else {
    @ir.hot_build_if(func, @lib.BlockType::void_(), cond, [
      @ir.hot_build_nop(func),
    ])
  }
  @ir.hot_root_append(func, set_field)
  @ir.hot_root_append(func, atomic_root)
  @ir.hot_root_append(func, if_id)
  if !use_if_arm {
    @ir.hot_root_append(
      func,
      @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 2)),
    )
  }
  code_pushing_test_run_hot_func(func)
}

///|
test "code-pushing sinks nonnull struct.get past atomic load into sole using if arm" {
  let func = code_pushing_atomic_struct_get_fixture(false, true)

  @debug.assert_eq(@ir.hot_root_count(func), 3)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  let atomic_drop = @ir.hot_root_get(func, 1)
  code_pushing_expect_op(func, atomic_drop, "drop")
  code_pushing_expect_op(
    func,
    @ir.hot_child_get(func, atomic_drop, 0),
    "atomic",
  )
  let if_id = @ir.hot_root_get(func, 2)
  code_pushing_expect_op(func, if_id, "if")
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 2)
  let moved_set = @ir.hot_region_get(func, then_ref, 0)
  code_pushing_expect_op(func, moved_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, moved_set).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_child_get(func, moved_set, 0), "heap")
  code_pushing_expect_op(func, @ir.hot_region_get(func, then_ref, 1), "drop")
}

///|
test "code-pushing keeps nonnull struct.get before atomic store into-if boundary" {
  // Binaryen v130's shared-struct atomics lit keeps this before the release
  // store; Starshine approximates that source-backed boundary in HOT.
  let func = code_pushing_atomic_struct_get_fixture(true, true)

  @debug.assert_eq(@ir.hot_root_count(func), 3)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "local.set")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "atomic")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 2), "if")
}

///|
test "code-pushing moves nonnull struct.get after atomic load segment push point" {
  let func = code_pushing_atomic_struct_get_fixture(false, false)

  @debug.assert_eq(@ir.hot_root_count(func), 5)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "drop")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 2), "if")
  let moved_set = @ir.hot_root_get(func, 3)
  code_pushing_expect_op(func, moved_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, moved_set).imm0, 2)
  code_pushing_expect_op(func, @ir.hot_child_get(func, moved_set, 0), "heap")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 4), "drop")
}

///|
test "code-pushing keeps nonnull struct.get before atomic store segment boundary" {
  // Binaryen v130's shared-struct atomics lit keeps this before the release
  // store even when the use is after the if push point.
  let func = code_pushing_atomic_struct_get_fixture(true, false)

  @debug.assert_eq(@ir.hot_root_count(func), 4)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "local.set")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 1), "atomic")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 2), "if")
  code_pushing_expect_op(func, @ir.hot_root_get(func, 3), "drop")
}

///|
test "code-pushing does not sink trapping computations" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32) i32.const 1 i32.const 0 i32.div_s local.set 1 local.get 0 if local.get 1 drop end))",
      ["code-pushing"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected trapping guard code-pushing success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.div_s"), msg=pretty)
  assert_false(
    trace.any(fn(line) { line.contains("pass[code-pushing]:mutated") }),
    msg=trace.to_string(),
  )
}
