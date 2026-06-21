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
fn code_pushing_test_run_hot(text : String) -> @ir.HotFunc {
  let func = pass_test_lift_first_func(text)
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
        _ => abort("expected local.get")
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
