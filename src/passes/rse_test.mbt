///|
fn rse_test_run_hot(text : String) -> @ir.HotFunc {
  let func = pass_test_lift_first_func(text)
  let ctx = HotPassContext::new(
    rse_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => func
    Err(err) => abort("expected rse hot pass success, got \{err}")
  }
}

///|
fn rse_expect_op(func : @ir.HotFunc, node_id : Int, expected : String) -> Unit {
  let op = @ir.hot_node_get(func, node_id).op
  match expected {
    "local.set" =>
      match op {
        @ir.HotOp::LocalSet => ()
        other => abort("expected local.set, got \{other}")
      }
    "drop" =>
      match op {
        @ir.HotOp::Drop => ()
        other => abort("expected drop, got \{other}")
      }
    "const" =>
      match op {
        @ir.HotOp::Const => ()
        other => abort("expected const, got \{other}")
      }
    "local.get" =>
      match op {
        @ir.HotOp::LocalGet => ()
        other => abort("expected local.get, got \{other}")
      }
    _ => abort("unknown expected op")
  }
}

///|
test "rse replaces same-value local.set shell with drop" {
  let func = rse_test_run_hot(
    "(module (func (local i32) i32.const 1 local.set 0 i32.const 1 local.set 0))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  rse_expect_op(func, @ir.hot_root_get(func, 0), "local.set")
  let rewritten = @ir.hot_root_get(func, 1)
  rse_expect_op(func, rewritten, "drop")
  rse_expect_op(func, @ir.hot_child_get(func, rewritten, 0), "const")
}

///|
test "rse replaces same-value local.tee shell with its value" {
  let func = rse_test_run_hot(
    "(module (func (local i32) i32.const 1 local.set 0 i32.const 1 local.tee 0 drop))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  rse_expect_op(func, @ir.hot_root_get(func, 0), "local.set")
  let drop = @ir.hot_root_get(func, 1)
  rse_expect_op(func, drop, "drop")
  rse_expect_op(func, @ir.hot_child_get(func, drop, 0), "const")
}

///|
test "rse keeps different overwritten values" {
  let func = rse_test_run_hot(
    "(module (func (local i32) i32.const 1 local.set 0 i32.const 2 local.set 0))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  rse_expect_op(func, @ir.hot_root_get(func, 0), "local.set")
  rse_expect_op(func, @ir.hot_root_get(func, 1), "local.set")
}

///|
test "rse treats branch disagreement as a merge value for self sets" {
  let func = rse_test_run_hot(
    "(module (func (param i32) (local i32) local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end local.get 1 local.set 1))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  let rewritten = @ir.hot_root_get(func, 1)
  rse_expect_op(func, rewritten, "drop")
  rse_expect_op(func, @ir.hot_child_get(func, rewritten, 0), "local.get")
}

///|
fn rse_test_first_defined_func(mod_ : @lib.Module) -> @lib.Func {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs.get(0) {
        Some(func) => func
        None => abort("expected first defined function")
      }
    None => abort("expected code section")
  }
}

///|
test "rse removes body-local default same-value set shells" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (local i32) i32.const 0 local.set 0))",
      ["redundant-set-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected rse default local fixture success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [@lib.Instruction::I32Const(_), @lib.Instruction::Drop] => ()
    other =>
      fail(
        "expected default local set shell to become drop, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse retargets equivalent local.get to strict subtype local" {
  let input =
    #|(module
    #|  (func (local anyref eqref)
    #|    ref.null eq
    #|    local.set 1
    #|    local.get 1
    #|    local.set 0
    #|    local.get 0
    #|    drop))
    #|
  let optimized = match
    pass_test_run_pipeline(input, ["redundant-set-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected rse refined get fixture success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::RefNull(_),
      @lib.Instruction::Drop,
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::LocalSet(_),
      @lib.Instruction::LocalGet(@lib.LocalIdx(raw)),
      @lib.Instruction::Drop,
    ] => @debug.assert_eq(raw, 1U)
    other =>
      fail(
        "expected retargeted local.get lowered shape, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse removes default local tee in loop conditions" {
  let input =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (if (local.get 0) (then unreachable))
    #|    (loop
    #|      (if
    #|        (i32.lt_u
    #|          (local.tee 1 (i32.const 0))
    #|          (i32.const 1)
    #|        )
    #|        (then br 0)
    #|      )
    #|    )
    #|  )
    #|)
  let optimized = match
    pass_test_run_pipeline(input, ["redundant-set-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected rse loop default tee fixture success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
}

///|
test "rse raw path preserves branch disagreement as a merge value for self sets" {
  let input =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 1
    #|      local.set 1
    #|    else
    #|      i32.const 2
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    local.set 1))
    #|
  let optimized = match
    pass_test_run_pipeline(input, ["redundant-set-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected rse branch merge fixture success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::If(_, _, _),
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::Drop,
    ] => ()
    other =>
      fail(
        "expected self-set shell to become drop after branch merge, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse raw path keeps block-exit disagreement final const set" {
  let input =
    #|(module
    #|  (func (param i32) (local i32)
    #|    block
    #|      local.get 0
    #|      br_if 0
    #|      i32.const 1
    #|      local.set 1
    #|    end
    #|    i32.const 1
    #|    local.set 1))
    #|
  let optimized = match
    pass_test_run_pipeline(input, ["redundant-set-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected rse block-exit merge fixture success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::Block(_, _),
      @lib.Instruction::I32Const(_),
      @lib.Instruction::LocalSet(_),
    ] => ()
    other =>
      fail(
        "expected final const set to survive block-exit disagreement, got \{@debug.to_string(other)}",
      )
  }
}
