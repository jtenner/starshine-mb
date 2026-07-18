///|
test "precompute-propagate folds local-carried constants that plain precompute leaves" {
  let source = "(module (func (result i32) (local i32) i32.const 10 local.set 0 local.get 0 local.get 0 i32.add))"
  let plain = match pass_test_run_pipeline(source, ["precompute"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected plain precompute success, got \{err}")
  }
  assert_true(plain.contains("local.get"), msg=plain)

  let propagated = match
    pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected precompute-propagate success, got \{err}")
  }
  assert_true(propagated.contains("I32(20)"), msg=propagated)
  assert_false(propagated.contains("i32.add"), msg=propagated)
}

///|
test "precompute-propagate folds identical reaching-set constants" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 10
    #|      local.set 1
    #|    else
    #|      i32.const 10
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    local.get 1
    #|    i32.add))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected identical-merge propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(20)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute-propagate preserves differing reaching-set values" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 10
    #|      local.set 1
    #|    else
    #|      i32.const 20
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    local.get 1
    #|    i32.add))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected differing-merge propagation success, got \{err}")
  }
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute-propagate merges defaultable local entry zero with explicit zero" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 0
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    local.get 1
    #|    i32.add))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected default-entry propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute-propagate reasons through tee and block fallthrough values" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    block (result i32)
    #|      nop
    #|      i32.const 7
    #|      local.tee 1
    #|    end
    #|    local.set 0
    #|    local.get 0
    #|    local.get 1
    #|    i32.add))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected fallthrough propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(14)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute-propagate preserves branch-written local after nested result if" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32) (local i32 i32)
    #|    local.get 0
    #|    if (result i32)
    #|      local.get 1
    #|      local.set 2
    #|      i32.const 0
    #|    else
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.set 2
    #|      i32.const 1
    #|    end
    #|    local.set 3
    #|    local.get 2))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected nested-result-if boundary success, got \{err}")
  }
  assert_true(pretty.contains("(local.get (Local 2))"), msg=pretty)
  assert_false(pretty.contains("I32(0))(end)"), msg=pretty)
}

///|
test "precompute-propagate preserves prior fact across branch writes in nested result if" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32) (local i32 i32)
    #|    i32.const 42
    #|    local.set 2
    #|    local.get 0
    #|    if (result i32)
    #|      local.get 1
    #|      local.set 2
    #|      i32.const 0
    #|    else
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.set 2
    #|      i32.const 1
    #|    end
    #|    local.set 3
    #|    local.get 2))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected stale-prior-fact boundary success, got \{err}")
  }
  assert_true(pretty.contains("(local.get (Local 2))"), msg=pretty)
  assert_false(pretty.contains("I32(42))(end)"), msg=pretty)
}

///|
test "precompute-propagate folds constants in high-local large lowered functions" {
  let source = StringBuilder::new()
  source.write_string("(module (func (result i32) (local")
  for _idx = 0; _idx < 65; _idx = _idx + 1 {
    source.write_string(" i32")
  }
  source.write_string(") i32.const 10 local.set 0")
  for _idx = 0; _idx < 501; _idx = _idx + 1 {
    source.write_string(" nop")
  }
  source.write_string(" local.get 0 local.get 0 i32.add))")
  let pretty = match
    pass_test_run_pipeline(source.to_string(), ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected large-function propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(20)"), msg=pretty)
  assert_false(pretty.contains("local.get"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute-propagate performs one propagation solve and one evaluator rerun" {
  let source =
    #|(module
    #|  (func (param i32 i32 i32) (result i32) (local i32)
    #|    local.get 3
    #|    if
    #|      i32.const 24
    #|      local.set 3
    #|    end
    #|    local.get 3
    #|    if
    #|      i32.const 0
    #|      local.set 2
    #|    end
    #|    local.get 2))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected bounded propagation success, got \{err}")
  }
  assert_true(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 3))"), msg=pretty)
}

///|
test "precompute-propagate merges agreeing writes from result if arms" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      i32.const 0
    #|    else
    #|      i32.const 7
    #|      local.set 1
    #|      i32.const 1
    #|    end
    #|    drop
    #|    local.get 1))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected result-if merge propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("(local.get (Local 1))"), msg=pretty)
}

///|
test "precompute-propagate carries tee constants into selected result if arms" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    local.get 0
    #|    local.tee 1
    #|    i32.const 5
    #|    local.tee 2
    #|    i32.lt_s
    #|    if (result i32)
    #|      local.get 2
    #|      local.get 1
    #|      i32.sub
    #|    else
    #|      i32.const 0
    #|    end))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected tee fact propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(5)"), msg=pretty)
  assert_false(pretty.contains("(local.get (Local 2))"), msg=pretty)
}

///|
test "precompute-propagate raw-cleans supported values around unsupported atomic fences" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::atomic_fence(),
            @lib.Instruction::i32_const(@lib.I32(84)),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::i32_div_s(),
            @lib.Instruction::drop(),
            @lib.Instruction::f64_const(@lib.F64(1.5)),
            @lib.Instruction::f64_const(@lib.F64(2.25)),
            @lib.Instruction::f64_add(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let pretty = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected atomic raw cleanup success, got \{err}")
  }
  assert_true(pretty.contains("atomic.fence"), msg=pretty)
  assert_false(pretty.contains("i32.div_s"), msg=pretty)
  assert_false(pretty.contains("f64.add"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
}

///|
test "precompute-propagate preserves legacy catch-all try flow" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::try_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
              [
                @lib.LegacyCatch::all(
                  @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(2))]),
                ),
              ],
            ),
          ]),
        ),
      ]),
    )
  let pretty = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected legacy try preservation success, got \{err}")
  }
  assert_true(pretty.contains("(try"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(2)"), msg=pretty)
}

///|
test "precompute-propagate keeps condition tee facts despite unrelated result-if arm writes" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32 i32 i32)
    #|    local.get 0
    #|    i32.const 5
    #|    local.tee 2
    #|    i32.lt_s
    #|    if (result i32)
    #|      local.get 2
    #|    else
    #|      i32.const 0
    #|    end
    #|    local.set 3
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 2
    #|      i32.const 0
    #|    else
    #|      i32.const 9
    #|      local.set 2
    #|      i32.const 1
    #|    end
    #|    local.set 1
    #|    local.get 3))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected condition tee propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(5)"), msg=pretty)
  assert_false(pretty.contains("(local.get (Local 2))"), msg=pretty)
}

///|
test "precompute-propagate raw control propagation keeps loop invariants" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $sink (param i32))
    #|  (func (param i32) (local i32 i32)
    #|    i32.const 290192
    #|    local.set 1
    #|    memory.size
    #|    drop
    #|    loop
    #|      local.get 1
    #|      drop
    #|      local.get 0
    #|      br_if 0
    #|    end
    #|    local.get 1
    #|    call $sink))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(1U))
    Err(err) =>
      fail("expected raw loop-invariant propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(290192)"), msg=pretty)
  assert_false(pretty.contains("(local.get (Local 1))"), msg=pretty)
}

///|
test "precompute-propagate raw control propagation does not fold loop-carried locals" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $sink)
    #|  (func (local i32)
    #|    i32.const 0
    #|    local.set 0
    #|    loop
    #|      local.get 0
    #|      i32.const 1
    #|      i32.add
    #|      local.set 0
    #|      local.get 0
    #|      i32.const 3
    #|      i32.lt_s
    #|      br_if 0
    #|    end
    #|    i32.const 0
    #|    i32.load
    #|    drop
    #|    call $sink))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(1U))
    Err(err) => fail("expected loop-carried local preservation, got \{err}")
  }
  assert_true(pretty.contains("i32.lt_s"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 0))"), msg=pretty)
}
