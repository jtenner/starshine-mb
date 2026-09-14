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
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        count += merge_locals_test_count_gets(body, local_idx)
        for catch_ in catches {
          let @lib.Expr(catch_body) = match catch_ {
            @lib.LegacyCatch(_, catch_expr) | @lib.LegacyCatchAll(catch_expr) =>
              catch_expr
          }
          count += merge_locals_test_count_gets(catch_body, local_idx)
        }
      }
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
test "merge-locals defers call and store local-copy meshes" {
  let input =
    #|(module
    #|  (memory 1)
    #|  (func $use (param i32))
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    local.set 1
    #|    i32.const 0
    #|    local.get 1
    #|    i32.store
    #|    local.get 1
    #|    call $use))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["merge-locals"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected call-store copy success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=call-store-local-copy-merge-locals-noop")
    }),
    msg=trace.to_string(),
  )
}

///|
test "merge-locals preserves copies after early returns" {
  let input =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 0
    #|      return
    #|    end
    #|    local.get 0
    #|    local.set 1
    #|    local.get 1))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["merge-locals"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected early-return copy success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=early-return-local-copy-merge-locals-noop")
    }),
    msg=trace.to_string(),
  )
}

///|
test "merge-locals owns the exact O4z slot after heap2local" {
  for
    passes in [
      optimize_preset_passes(
        HotPipelineOptions::new(optimize_level=4, shrink_level=4),
      ),
      shrink_preset_passes(
        HotPipelineOptions::new(optimize_level=4, shrink_level=4),
      ),
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
test "merge-locals preserves source reads evaluated before a later copy" {
  let input =
    #|(module
    #|  (func (export "fib") (param i32) (result i64) (local i64 i64)
    #|    i64.const 0
    #|    local.set 1
    #|    i64.const 1
    #|    local.set 2
    #|    loop
    #|      block
    #|        block
    #|          local.get 0
    #|          i32.eqz
    #|          br_if 1
    #|          local.get 1
    #|          local.get 2
    #|          i64.add
    #|          local.get 2
    #|          local.set 1
    #|          local.set 2
    #|          local.get 0
    #|          i32.const 1
    #|          i32.sub
    #|          local.set 0
    #|          br 2
    #|        end
    #|        unreachable
    #|      end
    #|    end
    #|    local.get 1))
  let optimized = match pass_test_run_pipeline(input, ["merge-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected stack-carried copy preservation, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  // Execute the local updates through ten iterations. Capture temporaries
  // may change the spelling, but must not turn the old sum into twice b.
  let storage = Array::make(locals.length() + 1, 0)
  storage[0] = 10
  let stack : Array[Int] = []
  let mut loop_body : Array[@lib.Instruction] = []
  fn step(instrs : Array[@lib.Instruction]) -> Bool raise {
    for instr in instrs {
      match instr {
        @lib.I32Const(@lib.I32(value)) => stack.push(value)
        @lib.I64Const(@lib.I64(value)) => stack.push(value.to_int())
        @lib.LocalGet(@lib.LocalIdx(raw)) =>
          stack.push(storage[raw.reinterpret_as_int()])
        @lib.LocalSet(@lib.LocalIdx(raw)) =>
          storage[raw.reinterpret_as_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(raw)) =>
          storage[raw.reinterpret_as_int()] = stack[stack.length() - 1]
        @lib.I64Add => {
          let right = stack.pop().unwrap()
          let left = stack.pop().unwrap()
          stack.push(left + right)
        }
        @lib.I32Sub => {
          let right = stack.pop().unwrap()
          let left = stack.pop().unwrap()
          stack.push(left - right)
        }
        @lib.I32Eqz => stack.push(if stack.pop().unwrap() == 0 { 1 } else { 0 })
        @lib.Block(_, @lib.Expr(nested)) => if step(nested) { return true }
        @lib.Loop(_, @lib.Expr(nested)) => {
          loop_body = nested
          if step(nested) {
            return true
          }
        }
        @lib.BrIf(_) => if stack.pop().unwrap() != 0 { return true }
        @lib.Br(_) => return true
        _ => fail("unexpected Fibonacci local-update instruction: \{instr}")
      }
    }
    false
  }
  assert_true(step(body))
  assert_false(loop_body.is_empty())
  for remaining = 9; remaining > 0; remaining = remaining - 1 {
    @debug.assert_eq(storage[0], remaining)
    assert_true(step(loop_body))
  }
  @debug.assert_eq(storage[0], 0)
  @debug.assert_eq(storage[1], 55)
  @debug.assert_eq(storage[2], 89)
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

///|
test "merge-locals retargets source influences inside legacy try bodies" {
  let input =
    #| (module
    #|   (tag $e)
    #|   (func (param $src i32) (result i32) (local $dst i32)
    #|     (try (result i32)
    #|       (do
    #|         (local.set $dst (local.get $src))
    #|         (drop (local.get $src))
    #|         (local.get $dst))
    #|       (catch $e
    #|         (i32.const 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["merge-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-locals legacy try success, got \{err}")
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
    2,
  )
}

///|
test "merge-locals preserves stack-carried tee aliases written to parameters" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param i32 i32) (local i32)
        #|    local.get 1
        #|    local.get 0 i32.const 4 i32.add local.tee 2
        #|    i32.load
        #|    i32.eq
        #|    local.get 2 local.set 1
        #|    if
        #|      local.get 1 drop
        #|    end))
      ),
      ["merge-locals"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected stack-carried parameter alias boundary, got \{err}")
  }
  let _ = optimized
  assert_true(
    trace.any(fn(line) {
      line.contains("stack-carried-tee-parameter-alias-merge-locals-noop")
    }),
    msg=trace.join("\n"),
  )
}

///|
test "merge-locals preserves old reads across a carried result block write" {
  let source =
    #|(module
    #|  (global $seen (mut i32) (i32.const 0))
    #|  (func $sink (param i32) local.get 0 global.set $seen)
    #|  (func $inc (param i32) (result i32) local.get 0 i32.const 6 i32.add)
    #|  (func (export "main") (result i32) (local i32 i32 i32)
    #|    i32.const 1 local.tee 1 local.tee 0 call $sink
    #|    local.get 1 local.tee 0 call $sink
    #|    block (result i32)
    #|      local.get 0 call $inc local.tee 0 call $sink
    #|      local.get 0 br 0
    #|    end
    #|    local.tee 0
    #|    local.get 1 local.tee 2 call $sink
    #|    local.get 2 call $sink
    #|    local.tee 2 drop
    #|    global.get $seen))
  let output = pass_test_run_pipeline(source, ["merge-locals"]).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[2]
  // The first read after the result block must still read the untouched source.
  let mut saw_block = false
  let mut checked = false
  for instr in body {
    if instr is @lib.Block(_, _) {
      saw_block = true
    }
    if saw_block && !checked {
      match instr {
        @lib.LocalGet(index) => {
          @debug.assert_eq(index, @lib.LocalIdx::new(1U))
          checked = true
        }
        _ => ()
      }
    }
  }
  assert_true(checked)
  ignore(@validate.validate_module(output).unwrap())
}

///|
test "merge-locals sparse influences preserve unused sources and repeated reads" {
  for
    suffix in [
      "local.get 0 local.get 0 i32.add", "local.get 1 local.get 1 i32.add", "i32.const 9 local.set 1 local.get 0 local.get 1 i32.add",
    ] {
    let source = "(module (func (result i32) (local i32 i32) i32.const 1 local.set 0 local.get 0 local.set 1 i32.const 7 drop " +
      suffix +
      "))"
    let original = pass_test_module_from_wat(source).code_sec.unwrap().0[0]
    let optimized = match pass_test_run_pipeline(source, ["merge-locals"]) {
      Ok(mod_) => mod_.code_sec.unwrap().0[0]
      Err(err) => fail(err)
    }
    assert_eq(
      scalar_fixture_run(optimized, []),
      scalar_fixture_run(original, []),
    )
  }
}
