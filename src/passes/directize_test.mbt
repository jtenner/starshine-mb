///|
test "directize rewrites a constant table target to a direct call" {
  let source =
    #|(module
    #|  (type (func (param i32) (result i32)))
    #|  (table 1 funcref)
    #|  (func $target (type 0) (param i32) (result i32)
    #|    local.get 0)
    #|  (elem (i32.const 0) $target)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 0
    #|    call_indirect (type 0)))
  let input = pass_test_module_from_wat(source)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["directize"]) {
    Ok(mod) => mod
    Err(err) => fail("expected directize pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected directized module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("(call (Func 0))"), msg=pretty)
  assert_false(pretty.contains("call_indirect"), msg=pretty)
}

///|
test "directize leaves mutable tables indirect" {
  let source =
    #|(module
    #|  (type (func (param i32) (result i32)))
    #|  (table 1 funcref)
    #|  (func $target (type 0) (param i32) (result i32)
    #|    local.get 0)
    #|  (elem (i32.const 0) $target)
    #|  (func (export "run") (param funcref) (param i32) (result i32)
    #|    i32.const 0
    #|    local.get 0
    #|    table.set 0
    #|    local.get 1
    #|    i32.const 0
    #|    call_indirect (type 0)))
  let input = pass_test_module_from_wat(source)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["directize"]) {
    Ok(mod) => mod
    Err(err) => fail("expected mutable-table directize success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected mutable-table module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call_indirect"), msg=pretty)
  assert_false(pretty.contains("(call (Func 0))"), msg=pretty)
}

///|
test "directize lowers select of known targets to direct-call branches" {
  let source =
    #|(module
    #|  (type (func (param i32) (result i32)))
    #|  (table 2 funcref)
    #|  (func $a (type 0) (param i32) (result i32) local.get 0)
    #|  (func $b (type 0) (param i32) (result i32) local.get 0 i32.const 1 i32.add)
    #|  (elem (i32.const 0) $a $b)
    #|  (func (export "run") (param i32 i32) (result i32)
    #|    local.get 0
    #|    i32.const 0
    #|    i32.const 1
    #|    local.get 1
    #|    select
    #|    call_indirect (type 0)))
  let input = pass_test_module_from_wat(source)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["directize"]) {
    Ok(mod) => mod
    Err(err) => fail("expected select directize success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected select-directized module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("(call (Func 0))"), msg=pretty)
  assert_true(pretty.contains("(call (Func 1))"), msg=pretty)
  assert_false(pretty.contains("call_indirect"), msg=pretty)
}

///|
test "directize lowers return-call select of known targets" {
  let source =
    #|(module
    #|  (type (func (param i32) (result i32)))
    #|  (table 2 funcref)
    #|  (func $a (type 0) (param i32) (result i32) local.get 0)
    #|  (func $b (type 0) (param i32) (result i32) local.get 0 i32.const 1 i32.add)
    #|  (elem (i32.const 0) $a $b)
    #|  (func (export "run") (param i32 i32) (result i32)
    #|    local.get 0
    #|    i32.const 0
    #|    i32.const 1
    #|    local.get 1
    #|    select
    #|    return_call_indirect (type 0)))
  let input = pass_test_module_from_wat(source)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["directize"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected return-call select directize success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected return-call select-directized module to validate, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("return_call_indirect"), msg=pretty)
}

///|
test "directize rewrites known holes to unreachable" {
  let source =
    #|(module
    #|  (type (func (param i32) (result i32)))
    #|  (table 2 funcref)
    #|  (func $target (type 0) (param i32) (result i32)
    #|    local.get 0)
    #|  (elem (i32.const 1) $target)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 0
    #|    call_indirect (type 0)))
  let input = pass_test_module_from_wat(source)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["directize"]) {
    Ok(mod) => mod
    Err(err) => fail("expected known-hole directize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("call_indirect"), msg=pretty)
}
