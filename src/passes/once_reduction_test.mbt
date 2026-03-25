///|
fn or_test_defined_func_instrs(
  mod_ : @lib.Module,
  defined_idx : Int,
) -> Array[@lib.Instruction] raise {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs.get(defined_idx) {
        Some(@lib.Func(_, @lib.Expr(instrs))) => instrs
        None => fail("expected defined function \{defined_idx}")
      }
    None => fail("expected code section")
  }
}

///|
test "run_hot_pipeline applies once-reduction to repeated once calls" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func $once
    #|     global.get $g
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g)
    #|   (func (export "run")
    #|     call $once
    #|     call $once))
    #|
  let optimized = match pass_test_run_pipeline(input, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected once-reduction pipeline success, got \{err}")
  }

  assert_eq(try! or_test_defined_func_instrs(optimized, 1), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::nop(),
  ])
}

///|
test "once-reduction keeps globals that are externally visible" {
  let wat =
    #| (module
    #|   (global $g (export "g") (mut i32) (i32.const 0))
    #|   (func $once
    #|     global.get $g
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g)
    #|   (func (export "run")
    #|     call $once
    #|     call $once))
    #|
  let input = pass_test_module_from_wat(wat)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected exported-global once-reduction success, got \{err}")
  }

  assert_eq(try! or_test_defined_func_instrs(optimized, 1), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
}

///|
test "once-reduction collapses trivial once bodies after call optimization" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func (export "run")
    #|     global.get $g
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g))
    #|
  let optimized = match pass_test_run_pipeline(input, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected once body reduction success, got \{err}")
  }

  assert_eq(try! or_test_defined_func_instrs(optimized, 0), [
    @lib.Instruction::nop(),
  ])
}

///|
test "once-reduction tracks multiple independent once globals" {
  let input =
    #| (module
    #|   (global $g0 (mut i32) (i32.const 0))
    #|   (global $g1 (mut i32) (i32.const 0))
    #|   (func $once0
    #|     global.get $g0
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g0)
    #|   (func $once1
    #|     global.get $g1
    #|     if
    #|       return
    #|     end
    #|     i32.const 1
    #|     global.set $g1)
    #|   (func (export "run")
    #|     call $once0
    #|     call $once1
    #|     call $once0
    #|     call $once1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["once-reduction"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected multi-once reduction success, got \{err}")
  }

  assert_eq(try! or_test_defined_func_instrs(optimized, 2), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::nop(),
    @lib.Instruction::nop(),
  ])
}
