///|
test "remove-unused-brs removes trailing branch to the enclosing block" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) block (result i32) i32.const 7 br 0 end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected remove-unused-brs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "remove-unused-brs removes trailing return at function exit" {
  let optimized = match
    pass_test_run_pipeline("(module (func (result i32) i32.const 9 return))", [
      "remove-unused-brs",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected remove-unused-brs return success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "remove-unused-brs removes trailing multi-value branch to the enclosing block" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32 i64) block (result i32 i64) i32.const 7 i64.const 8 br 0 end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs multi-value br success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("I64(8)"), msg=pretty)
}

///|
test "remove-unused-brs removes trailing multi-value return at function exit" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32 i64) i32.const 9 i64.const 10 return))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs multi-value return success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
  assert_true(pretty.contains("I64(10)"), msg=pretty)
}

///|
test "remove-unused-brs rewrites one-armed if break into br_if" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) block local.get 0 if br 1 end end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected remove-unused-brs if success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
}

///|
test "remove-unused-brs flattens block-local if-else break chains into br_if" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) block $exit local.get 0 if br $exit else local.get 1 if br $exit end end end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs block chain success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
}

///|
test "remove-unused-brs rewrites pure value if into select" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (if (result i32) (local.get 0) (then (i32.const 1)) (else (i32.const 0)))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected remove-unused-brs select success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
}

///|
test "remove-unused-brs rewrites pure const ifs into select" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (if (result i32) (local.get 0) (then (i32.const 11)) (else (i32.const 22)))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs const-select success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_true(pretty.contains("I32(11)"), msg=pretty)
  assert_true(pretty.contains("I32(22)"), msg=pretty)
}

///|
test "remove-unused-brs rewrites const-arm ifs into select even with local.tee conditions" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) (if (result i32) (i32.eq (local.tee 1 (local.get 0)) (i32.const 1)) (then (i32.const 1)) (else (i32.const 0)))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs local.tee const-select success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
}

///|
test "remove-unused-brs rewrites pure local.get ifs into select" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32 i32) (result i32) (if (result i32) (local.get 0) (then (local.get 1)) (else (local.get 2)))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs local-select success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 1))"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 2))"), msg=pretty)
}

///|
test "remove-unused-brs merges nested one-armed if conditions before branching" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) block $exit local.get 0 if local.get 1 if br $exit end end end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs nested-if branch success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
}

///|
test "remove-unused-brs rewrites nested condition if expressions under branches" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) block $exit local.get 0 if (result i32) local.get 1 else i32.const 0 end if br $exit end end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs nested condition success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
}

///|
test "remove-unused-brs flattens else-if ladders with embedded value-if conditions" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) block $exit local.get 0 i32.const 10 i32.ge_s if (result i32) local.get 0 i32.const 20 i32.le_s else i32.const 0 end if br $exit else local.get 0 i32.const 30 i32.ge_s if (result i32) local.get 0 i32.const 40 i32.le_s else i32.const 0 end if br $exit else local.get 0 i32.const 50 i32.eq if br $exit end end end end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected remove-unused-brs ladder success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
}

///|
test "remove-unused-brs descends into control ladders nested under drop" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (drop (block (result i32) (block $exit (if (local.get 0) (then (br $exit)) (else (if (local.get 1) (then (br $exit)))))) (i32.const 0)))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs nested-drop success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
}

///|
test "remove-unused-brs rewrites local.set if copy arms into one-armed ifs" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32) (local.set 1 (i32.const 0)) (local.set 1 (if (result i32) (local.get 0) (then (i32.const 1)) (else (local.get 1))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs local.set copy-arm success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(if (Void)"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 1))"), msg=pretty)
  assert_false(pretty.contains("(local.get (Local 1))"), msg=pretty)
}

///|
test "remove-unused-brs rewrites local.set if break arms into br_if plus set" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32) block $exit (local.set 1 (if (result i32) (local.get 0) (then (br $exit)) (else (i32.const 7)))) end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs local.set br-arm success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 1))"), msg=pretty)
  assert_false(pretty.contains("(if (I32)"), msg=pretty)
}

///|
test "remove-unused-brs flattens block-local if chains when the else arm breaks" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) block $exit local.get 0 if local.get 1 drop else br $exit end end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs flipped block chain success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
}

///|
test "remove-unused-brs rewrites two-armed branch exits into br_if plus branch" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (block $outer (block $inner (if (local.get 0) (then (br $outer)) (else (br $inner))) unreachable))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs two-arm br success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
}

///|
test "remove-unused-brs rewrites branch-exit ifs even when neither target is the immediate holder" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (block $outer (block $other (block (if (local.get 0) (then (br $outer)) (else (br $other))) unreachable)))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs non-holder two-arm br success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
}

///|
test "remove-unused-brs rewrites branch-exit ifs nested in dropped multi-value blocks" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (block $outer (block $other (block (result i32 i64) (if (result i32 i64) (local.get 0) (then (br $outer)) (else (br $other))) unreachable) drop drop) (i32.const 9) (return)) (i32.const 7)))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs dropped multi-value br success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
}

///|
test "remove-unused-brs drains long runs of two-armed branch exits in one region" {
  let input = {
    let out = StringBuilder::new()
    out.write_string("(module (func (param i32) (block $exit")
    for idx = 0; idx < 300; idx = idx + 1 {
      out.write_string(
        " (block $inner\{idx} (if (local.get 0) (then (br $exit)) (else (br $inner\{idx}))) unreachable)",
      )
    }
    out.write_string(")))")
    out.to_string()
  }
  let optimized = match pass_test_run_pipeline(input, ["remove-unused-brs"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected remove-unused-brs long-run success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
}

///|
test "remove-unused-brs voidifies tail return-wrapped ifs whose arms already break away" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) (block $outer (block $inner (return (if (result i32) (local.get 0) (then (local.set 1 (i32.const 1)) (br $inner)) (else (local.set 1 (i32.const 2)) (br $outer))))) (i32.const 9) (return)) (local.get 1)))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs tail return-if success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(if (Void)"), msg=pretty)
  assert_false(pretty.contains("(if (I32)"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "remove-unused-brs voidifies multi-value tail return-wrapped ifs" {
  let input = "(module (func (param i32) (result i32 i64) (block $outer (block $inner (return (if (result i32 i64) (local.get 0) (then (br $inner)) (else (br $outer))))) (i32.const 9) (i64.const 10) (return)) (i32.const 7) (i64.const 8)))"
  let optimized = match pass_test_run_pipeline(input, ["remove-unused-brs"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs multi-value tail return-if success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "remove-unused-brs voidifies nested tail return-wrapped if ladders" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (block $outer (block $inner (return (if (result i32) (local.get 0) (then (if (result i32) (local.get 1) (then (br $inner)) (else (br $outer)))) (else (br $outer))))) (i32.const 9) (return)) (i32.const 7)))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs nested tail return-if success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(if (Void)"), msg=pretty)
  assert_false(pretty.contains("(if (I32)"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "remove-unused-brs rewrites tail return ifs with simple payload arms" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) (return (if (result i32) (local.get 0) (then (i32.const 1)) (else (local.set 1 (i32.const 9)) (i32.const 2))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs tail return simple-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(if (Void)"), msg=pretty)
  assert_false(pretty.contains("(if (I32)"), msg=pretty)
  assert_true(pretty.contains("return"), msg=pretty)
}

///|
test "remove-unused-brs rewrites payload ifs inside returned loop bodies" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) (return (loop (result i32) (if (result i32) (local.get 0) (then (i32.const 1)) (else (local.set 1 (i32.const 9)) (i32.const 2)))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs returned-loop payload success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if (I32)"), msg=pretty)
  assert_true(pretty.contains("(if (Void)"), msg=pretty)
  assert_true(pretty.contains("loop"), msg=pretty)
}

///|
test "remove-unused-brs strips nested returns inside root returned loops" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (local i32) (if (result i32) (local.get 0) (then (loop $l (result i32) (if (result i32) (local.get 1) (then (local.set 2 (i32.const 7)) (br $l (i32.const 1))) (else (return (i32.const 2)))))) (else (return (i32.const 3))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs returned-loop nested-return success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("loop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
}

///|
test "remove-unused-brs strips nested multi-value returns in root return context" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32 i32) (if (result i32 i32) (local.get 0) (then (if (result i32 i32) (local.get 1) (then (return (block (result i32 i32) (i32.const 1) (i32.const 2)))) (else (return (block (result i32 i32) (i32.const 3) (i32.const 4)))))) (else (return (block (result i32 i32) (i32.const 5) (i32.const 6)))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs nested multi-value return success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("(if "), msg=pretty)
}

///|
test "remove-unused-brs detects nested multi-value root return context" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32 i32) (result i32 i32) (if (result i32 i32) (local.get 0) (then (if (result i32 i32) (local.get 1) (then (return (block (result i32 i32) (i32.const 1) (i32.const 2)))) (else (return (block (result i32 i32) (i32.const 3) (i32.const 4)))))) (else (return (block (result i32 i32) (i32.const 5) (i32.const 6)))))))",
  )
  let outer_if = @ir.hot_region_get(func, @ir.HotRegionRef::root(), 0)
  let then_ref = @ir.hot_region_then_ref(func, outer_if)
  let inner_if = @ir.hot_region_get(func, then_ref, 1)
  let inner_then_ref = @ir.hot_region_then_ref(func, inner_if)
  let tail = @ir.hot_region_get(func, inner_then_ref, 0)
  let child = @ir.hot_child_get(func, tail, 0)
  assert_eq(@ir.hot_region_result_arity(func, inner_then_ref), 2)
  assert_eq(@ir.hot_node_get(func, tail).child_count, 2)
  assert_eq(@ir.hot_child_get(func, tail, 1), child)
  assert_eq(@ir.hot_node_result_arity(func, child), 2)
}

///|
test "remove-unused-brs rewrites branch payload ifs with branching else arms" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (block $exit (result i32) (block $other (br $exit (if (result i32) (local.get 0) (then (i32.const 1)) (else (br $other)))) unreachable) (i32.const 9))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs branch-payload success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_false(pretty.contains("(if (I32)"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "remove-unused-brs rewrites multi-value branch payload ifs" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32 i64) (block $exit (result i32 i64) (block $other (br $exit (if (result i32 i64) (local.get 0) (then (i32.const 1) (i64.const 2)) (else (br $other)))) unreachable) (i32.const 9) (i64.const 10))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs multi-value branch-payload success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_false(pretty.contains("(if (I32, I64)"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "remove-unused-brs strips stack-style branch exits from tail value if arms" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (block $exit (result i32) (if (result i32) (local.get 0) (then (i32.const 1) (br $exit)) (else (i32.const 2) (br $exit))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs stack-style branch-exit success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(2)"), msg=pretty)
}

///|
test "remove-unused-brs rewrites one-sided stack-style tail branch ifs into select" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (block $exit (result i32) (if (result i32) (local.get 0) (then (i32.const 1)) (else (i32.const 2) (br $exit))) (br $exit))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs one-sided stack-style branch success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
}

///|
test "remove-unused-brs rewrites one-sided tail return ifs into select" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (if (result i32) (local.get 0) (then (i32.const 1)) (else (return (i32.const 2))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs one-sided return success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
}

///|
test "remove-unused-brs strips stack-style returns from tail value if arms" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (if (result i32) (local.get 0) (then (i32.const 1) (return)) (else (i32.const 2) (return)))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs stack-style return success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(2)"), msg=pretty)
}

///|
test "remove-unused-brs rewrites nested simple payload ifs under branch payload arms" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (local i32) (block $out (result i32) (br $out (if (result i32) (local.get 0) (then (i32.const 1)) (else (local.set 2 (i32.const 9)) (if (result i32) (local.get 1) (then (i32.const 2)) (else (i32.const 3)))))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested branch payload rewrite success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if (I32) (local.get (Local 1))"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
}

///|
test "remove-unused-brs voidifies nested branch-exit ifs inside branch payload arms" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (local i32) (block $exit (result i32) (block $other (br $exit (if (result i32) (local.get 0) (then (i32.const 1)) (else (local.set 2 (i32.const 7)) (if (result i32) (local.get 1) (then (br $other)) (else (local.get 2)))))) unreachable) (i32.const 9))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs nested branch-payload inner-if success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let mut typed_if_parts = 0
  for _ in pretty.split("if I32") {
    typed_if_parts += 1
  }
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_eq(typed_if_parts, 2, msg=pretty)
  assert_true(pretty.contains("(local.set (Local 2))"), msg=pretty)
}

///|
test "remove-unused-brs voidifies nested branch-exit ifs inside local.set payload arms" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (local i32) (block $exit (local.set 2 (if (result i32) (local.get 0) (then (i32.const 1)) (else (local.set 2 (i32.const 7)) (if (result i32) (local.get 1) (then (br $exit)) (else (local.get 2))))))) (local.get 2)))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs nested local.set payload inner-if success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let mut typed_if_parts = 0
  for _ in pretty.split("if I32") {
    typed_if_parts += 1
  }
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_eq(typed_if_parts, 2, msg=pretty)
  assert_true(pretty.contains("(local.set (Local 2))"), msg=pretty)
}

///|
test "remove-unused-brs voidifies result ifs whose arms only return under drop" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (drop (if (result i32) (local.get 0) (then (return (i32.const 1))) (else (return (i32.const 2))))) (i32.const 0)))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs dropped exit-only value-if success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if (I32)"), msg=pretty)
  assert_true(pretty.contains("(if (Void)"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "remove-unused-brs voidifies dropped exit-only ifs through local.tee wrappers" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) (drop (local.tee 1 (if (result i32) (local.get 0) (then (return (i32.const 1))) (else (return (i32.const 2)))))) (i32.const 0)))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs dropped local.tee exit-only if success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if (I32)"), msg=pretty)
  assert_true(pretty.contains("(if (Void)"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}
