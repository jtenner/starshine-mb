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
test "remove-unused-brs rewrites reorder-safe condition ladders into select" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (local i32) (if (if (result i32) (i32.eqz (local.tee 2 (local.get 0))) (then (i32.const 1)) (else (i32.le_s (local.get 1) (i32.const 0)))) (then (return (i32.const 0)))) (i32.const 1)))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs condition-ladder select success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("(if (I32)"), msg=pretty)
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
test "remove-unused-brs flattens multi-root then arms before block exits" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (block $exit (if (local.get 0) (then (drop (i32.const 0)) (drop (i32.const 1))) (else (br $exit))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs multi-root block-exit success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("(i32.const I32(0))"), msg=pretty)
  assert_true(pretty.contains("(i32.const I32(1))"), msg=pretty)
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
  assert_false(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("(if "), msg=pretty)
  assert_false(pretty.contains("(if (Void)"), msg=pretty)
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
  assert_false(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("(if "), msg=pretty)
  assert_false(pretty.contains("(if (Void)"), msg=pretty)
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
  assert_false(pretty.contains("(if (Void)"), msg=pretty)
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
test "remove-unused-brs lifts scalar returned ladders through return and holder blocks" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32 i32) (result i32) (local i32) (block (result i32) (return (if (result i32) (local.get 0) (then (local.set 2 (i32.const 7)) (return (local.get 2))) (else (return (block (result i32) (if (result i32) (local.get 1) (then (i32.const 1)) (else (i32.const 2)))))))))))",
  )
  let root = @ir.hot_region_get(func, @ir.HotRegionRef::root(), 0)
  let root_body = @ir.hot_region_body_ref(func, root)
  let tail = @ir.hot_region_get(func, root_body, 0)
  let outer_if = @ir.hot_child_get(func, tail, 0)
  let then_ref = @ir.hot_region_then_ref(func, outer_if)
  let else_ref = @ir.hot_region_else_ref(func, outer_if).unwrap()
  let then_holder = then_ref.holder
  let else_holder = else_ref.holder
  let else_return = @ir.hot_region_get(func, else_ref, 0)
  let nested_block = @ir.hot_child_get(func, else_return, 0)

  assert_eq(@ir.hot_node_result_arity(func, root), 1)
  match @ir.hot_node_get(func, tail).op {
    @ir.HotOp::Return => ()
    _ => fail("expected lifted root body tail to be a return")
  }
  match @ir.hot_node_get(func, outer_if).op {
    @ir.HotOp::If => ()
    _ => fail("expected lifted return child to be an if")
  }
  assert_eq(@ir.hot_node_result_arity(func, outer_if), 1)
  match @ir.hot_node_get(func, then_holder).op {
    @ir.HotOp::Block => ()
    _ => fail("expected lifted then holder to stay a block")
  }
  match @ir.hot_node_get(func, else_holder).op {
    @ir.HotOp::Block => ()
    _ => fail("expected lifted else holder to stay a block")
  }
  match @ir.hot_node_get(func, else_return).op {
    @ir.HotOp::Return => ()
    _ => fail("expected lifted else arm root to be a return")
  }
  match @ir.hot_node_get(func, nested_block).op {
    @ir.HotOp::Block => ()
    _ => fail("expected nested returned value region to be wrapped in a block")
  }
  assert_eq(@ir.hot_node_result_arity(func, nested_block), 1)
}

///|
test "remove-unused-brs lifts multi-value returned ladders through repeated holder blocks" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32 i32 i32 i32) (result i32 i32) (if (result i32 i32) (local.get 3) (then (block $out (result i32 i32) (block $mid (result i32 i32) (if (local.get 0) (then (drop (i32.const 9)) (drop (i32.const 8)) (br $mid (if (result i32 i32) (local.get 1) (then (i32.const 1) (i32.const 2)) (else (i32.const 3) (i32.const 4)))))) (i32.const 5) (i32.const 6)))) (else (i32.const 7) (i32.const 8)))))",
  )
  let root0 = @ir.hot_region_get(func, @ir.HotRegionRef::root(), 0)
  let root1 = @ir.hot_region_get(func, @ir.HotRegionRef::root(), 1)
  let then_ref = @ir.hot_region_then_ref(func, root0)
  let else_ref = @ir.hot_region_else_ref(func, root0).unwrap()
  let then_root0 = @ir.hot_region_get(func, then_ref, 0)
  let then_root0_body = @ir.hot_region_body_ref(func, then_root0)
  let body0 = @ir.hot_region_get(func, then_root0_body, 0)
  let body1 = @ir.hot_region_get(func, then_root0_body, 1)
  let body0_body = @ir.hot_region_body_ref(func, body0)
  let nested0 = @ir.hot_region_get(func, body0_body, 0)
  let nested1 = @ir.hot_region_get(func, body0_body, 1)
  let nested0_then = @ir.hot_region_then_ref(func, nested0)
  let nested0_then2 = @ir.hot_region_get(func, nested0_then, 2)
  let payload_if = @ir.hot_child_get(func, nested0_then2, 0)

  match @ir.hot_node_get(func, root0).op {
    @ir.HotOp::If => ()
    _ => fail("expected first lifted root to stay an if")
  }
  match @ir.hot_node_get(func, root1).op {
    @ir.HotOp::If => ()
    _ => fail("expected repeated multi-value root to stay an if")
  }
  match @ir.hot_node_get(func, then_ref.holder).op {
    @ir.HotOp::Block => ()
    _ => fail("expected lifted then holder to be a block")
  }
  match @ir.hot_node_get(func, else_ref.holder).op {
    @ir.HotOp::Block => ()
    _ => fail("expected lifted else holder to be a block")
  }
  assert_eq(@ir.hot_region_root_count(func, then_ref), 2)
  assert_eq(@ir.hot_region_root_count(func, else_ref), 2)
  match @ir.hot_node_get(func, then_root0).op {
    @ir.HotOp::Block => ()
    _ => fail("expected returned then root to be a result block")
  }
  assert_eq(@ir.hot_region_root_count(func, then_root0_body), 2)
  match @ir.hot_node_get(func, body0).op {
    @ir.HotOp::Block => ()
    _ => fail("expected nested returned ladder wrapper block")
  }
  match @ir.hot_node_get(func, body1).op {
    @ir.HotOp::Block => ()
    _ => fail("expected repeated returned ladder wrapper block")
  }
  assert_eq(@ir.hot_region_root_count(func, body0_body), 3)
  match @ir.hot_node_get(func, nested0).op {
    @ir.HotOp::If => ()
    _ => fail("expected leading nested guard to stay an if")
  }
  match @ir.hot_node_get(func, nested1).op {
    @ir.HotOp::Const => ()
    _ => fail("expected trailing fallthrough value root to stay a const")
  }
  match @ir.hot_node_get(func, nested0_then.holder).op {
    @ir.HotOp::Block => ()
    _ => fail("expected nested guard then holder to stay a block")
  }
  assert_eq(@ir.hot_region_root_count(func, nested0_then), 3)
  match @ir.hot_node_get(func, nested0_then2).op {
    @ir.HotOp::Br => ()
    _ => fail("expected nested then tail to stay a branch")
  }
  match @ir.hot_node_get(func, payload_if).op {
    @ir.HotOp::If => ()
    _ => fail("expected branch payload to stay a repeated result if")
  }
  assert_eq(@ir.hot_node_get(func, nested0_then2).child_count, 2)
}

///|
test "remove-unused-brs flattens nested returned ladder branch exits" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (local i32) (block $exit (return (if (result i32) (local.get 0) (then (local.set 2 (i32.const 9)) (if (result i32) (local.get 1) (then (local.get 2)) (else (br $exit)))) (else (i32.const 4)))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs nested returned ladder branch-exit success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_false(
    pretty.contains("(if (result i32)\n      (local.get 1)"),
    msg=pretty,
  )
}

///|
test "remove-unused-brs preserves result ifs for nested multi-value root return blocks" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32 i32) (local i32) (block (result i32 i32) (return (if (result i32 i32) (local.get 0) (then (local.set 2 (i32.const 7)) (if (result i32 i32) (local.get 1) (then (return (i32.const 1) (local.get 2))) (else (return (i32.const 2) (i32.const 3))))) (else (return (i32.const 4) (i32.const 5))))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs nested multi-value root return block success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("(if"), msg=pretty)
  assert_false(pretty.contains("(if (Void)"), msg=pretty)
}

///|
test "remove-unused-brs preserves scalar root return ifs with returned block arms" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (local i32) (block (result i32) (return (if (result i32) (local.get 0) (then (local.set 2 (i32.const 7)) (return (local.get 2))) (else (return (block (result i32) (if (result i32) (local.get 1) (then (i32.const 1)) (else (i32.const 2)))))))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs scalar returned-block arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("(if (Void)"), msg=pretty)
}

///|
test "remove-unused-brs preserves scalar root return ifs with nested returned block ladders" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (return (if (result i32) (local.get 0) (then (i32.const 7)) (else (block (result i32) (if (result i32) (local.get 1) (then (return (i32.const 1))) (else (return (i32.const 2))))))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs scalar nested returned-block ladder success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("(if (Void)"), msg=pretty)
}

///|
test "remove-unused-brs preserves result ifs for nested scalar root return blocks" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (local i32) (block (result i32) (return (if (result i32) (local.get 0) (then (local.set 2 (i32.const 7)) (if (result i32) (local.get 1) (then (return (local.get 2))) (else (return (i32.const 3))))) (else (return (i32.const 4))))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs nested scalar root return block success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("(if "), msg=pretty)
}

///|
test "remove-unused-brs preserves scalar root return ifs with direct return arms" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (local i32) (block (result i32) (return (if (result i32) (local.get 0) (then (local.set 2 (i32.const 7)) (return (local.get 2))) (else (return (if (result i32) (local.get 1) (then (i32.const 1)) (else (i32.const 2))))))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs scalar direct-return arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("(if "), msg=pretty)
}

///|
test "remove-unused-brs strips nested returned scalar wrapper blocks" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (return (block (result i32) (block (result i32) (local.get 0))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs nested returned wrapper success, got \{err}",
      )
  }

  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [@lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0U))]))]
      )
    ) => ()
    _ =>
      fail(
        "expected nested returned scalar wrapper blocks to lower to a bare local.get",
      )
  }
}

///|
test "remove-unused-brs lowers scalar returned ladders with side-effect arms to select" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (block (result i32) (return (if (result i32) (local.get 0) (then (return (i32.const 1))) (else (drop (i32.const 9)) (return (i32.const 0))))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs scalar side-effect ladder success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("(if (Void)"), msg=pretty)
}

///|
test "remove-unused-brs lowers nested scalar returned ladders with side-effect arms" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (local i32) (block (result i32) (return (if (result i32) (local.get 0) (then (local.set 2 (i32.const 7)) (return (local.get 2))) (else (return (block (result i32) (if (result i32) (local.get 1) (then (drop (i32.const 9)) (return (i32.const 1))) (else (drop (i32.const 8)) (return (i32.const 2)))))))))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs nested scalar side-effect ladder success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("(if (Void)"), msg=pretty)
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
test "remove-unused-brs rewrites one-arm payload branch ladders into br_if plus fallthrough" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (block $exit (result i32) (if (if (result i32) (local.get 0) (then (i32.const 1)) (else (local.get 1))) (then (br $exit (i32.const 7))) (else (drop (i32.const 0)))) (i32.const 9))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-brs one-arm payload branch success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_false(pretty.contains("(if (Void)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
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
