///|
fn merge_locals_test_first_func(mod_ : @lib.Module) -> @lib.Func {
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
fn merge_locals_test_count_gets(
  instrs : Array[@lib.Instruction],
  local_idx : @lib.LocalIdx,
) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.LocalGet(idx) => if idx == local_idx { count += 1 }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        count += merge_locals_test_count_gets(body, local_idx)
      @lib.If(_, then_body, else_body) => {
        count += merge_locals_test_count_gets(then_body, local_idx)
        match else_body {
          Some(body) => count += merge_locals_test_count_gets(body, local_idx)
          None => ()
        }
      }
      _ => ()
    }
  }
  count
}

///|
fn merge_locals_test_index_of(passes : Array[String], name : String) -> Int {
  for idx = 0; idx < passes.length(); idx = idx + 1 {
    if passes[idx] == name {
      return idx
    }
  }
  -1
}

///|
test "merge-locals owns the exact O4z slot after heap2local" {
  for
    passes in [
      optimize_preset_passes(HotPipelineOptions::new()),
      shrink_preset_passes(HotPipelineOptions::new()),
    ] {
    let idx = merge_locals_test_index_of(passes, "merge-locals")
    assert_true(idx > 0)
    @debug.assert_eq(passes[idx - 1], "heap2local")
    @debug.assert_eq(passes[idx + 1], "optimize-casts")
  }
}

///|
test "merge-locals accepts the O4z copy-balancing pass spelling" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 local.get 1))",
      ["merge-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "merge-locals retargets same-typed source gets after copy" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32 i32) i32.const 1 local.set 0 local.get 0 local.set 1 local.get 0 local.get 1 i32.add))",
      ["merge-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(
    pretty.contains("local.get (Local 0))(local.get (Local 1)"),
    msg=pretty,
  )
  assert_true(
    pretty.contains("local.get (Local 1))(local.get (Local 1)"),
    msg=pretty,
  )
}

///|
test "merge-locals retargets source influences across if control" {
  let input =
    #| (module
    #|   (func (param i32) (result i32) (local i32 i32)
    #|     i32.const 7
    #|     local.set 1
    #|     local.get 1
    #|     local.set 2
    #|     local.get 0
    #|     if
    #|       local.get 1
    #|       drop
    #|     else
    #|       local.get 1
    #|       drop
    #|     end
    #|     local.get 2))
    #|
  let optimized = match pass_test_run_pipeline(input, ["merge-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-locals success, got \{err}")
  }

  let @lib.Func(_locals, @lib.Expr(instrs)) = merge_locals_test_first_func(
    optimized,
  )
  @debug.assert_eq(
    merge_locals_test_count_gets(instrs, @lib.LocalIdx::new(1U)),
    1,
  )
  @debug.assert_eq(
    merge_locals_test_count_gets(instrs, @lib.LocalIdx::new(2U)),
    3,
  )
}

///|
test "merge-locals uses reverse orientation when source has a merge influence" {
  let input =
    #| (module
    #|   (func (param i32) (result i32) (local i32 i32)
    #|     i32.const 7
    #|     local.set 1
    #|     local.get 1
    #|     local.set 2
    #|     local.get 2
    #|     drop
    #|     local.get 0
    #|     if
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["merge-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-locals success, got \{err}")
  }

  let @lib.Func(_locals, @lib.Expr(instrs)) = merge_locals_test_first_func(
    optimized,
  )
  @debug.assert_eq(
    merge_locals_test_count_gets(instrs, @lib.LocalIdx::new(1U)),
    3,
  )
  @debug.assert_eq(
    merge_locals_test_count_gets(instrs, @lib.LocalIdx::new(2U)),
    0,
  )
}

///|
test "merge-locals instruments local tee copies like Binaryen" {
  let input =
    #| (module
    #|   (func (result i32) (local i32 i32)
    #|     i32.const 7
    #|     local.set 0
    #|     local.get 0
    #|     local.tee 1
    #|     drop
    #|     local.get 0))
    #|
  let optimized = match pass_test_run_pipeline(input, ["merge-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-locals success, got \{err}")
  }

  let @lib.Func(_locals, @lib.Expr(instrs)) = merge_locals_test_first_func(
    optimized,
  )
  @debug.assert_eq(
    merge_locals_test_count_gets(instrs, @lib.LocalIdx::new(0U)),
    1,
  )
  @debug.assert_eq(
    merge_locals_test_count_gets(instrs, @lib.LocalIdx::new(1U)),
    1,
  )
}

///|
test "merge-locals stops retargeting across control that writes destination" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 loop local.get 1 i32.const 1 i32.add local.set 1 end local.get 0))",
      ["merge-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(end))(local.get (Local 0))(end)"), msg=pretty)
}

///|
test "merge-locals preserves raw unreachable debris when no copy candidate exists" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     i64.const 0
    #|     block (result i64)
    #|       f64.const 0
    #|       unreachable
    #|     end
    #|     unreachable))
    #|
  let baseline = match pass_test_run_pipeline(input, []) {
    Ok(mod_) => mod_
    Err(err) => fail("expected baseline pipeline success, got \{err}")
  }
  let optimized = match pass_test_run_pipeline(input, ["merge-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-locals success, got \{err}")
  }
  @debug.assert_eq(optimized, baseline)
}

///|
test "merge-locals stops retargeting after destination write" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32 i32) i32.const 1 local.set 0 local.get 0 local.set 1 i32.const 2 local.set 1 local.get 0))",
      ["merge-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}
