///|
fn cl_test_first_defined_func(mod_ : @lib.Module) -> @lib.Func {
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
test "coalesce-locals registers as an active module pass" {
  match pass_registry_lookup("coalesce-locals") {
    Some(entry) => {
      assert_eq(entry.category, HotPassRegistryCategory::module_pass())
      assert_eq(entry.descriptor, None)
    }
    None => fail("expected coalesce-locals registry entry")
  }
}

///|
test "coalesce-locals merges non-overlapping same-typed body locals" {
  let input =
    #| (module
    #|   (func (result i32) (local i32 i32)
    #|     i32.const 11
    #|     local.set 0
    #|     local.get 0
    #|     drop
    #|     i32.const 22
    #|     local.set 1
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_eq(instrs[1], @lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  assert_eq(instrs[2], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  assert_eq(instrs[5], @lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  assert_eq(instrs[6], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
}

///|
test "coalesce-locals keeps overlapping different values separate" {
  let input =
    #| (module
    #|   (func (result i32) (local i32 i32)
    #|     i32.const 11
    #|     local.set 0
    #|     i32.const 22
    #|     local.set 1
    #|     local.get 0
    #|     drop
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  assert_eq(instrs[1], @lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  assert_eq(instrs[3], @lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
  assert_eq(instrs[4], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  assert_eq(instrs[6], @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
}

///|
test "coalesce-locals keeps locals live after an early read when read again later" {
  let input =
    #| (module
    #|   (func (result i32) (local i32 i32)
    #|     i32.const 11
    #|     local.set 0
    #|     local.get 0
    #|     drop
    #|     i32.const 22
    #|     local.set 1
    #|     local.get 0
    #|     local.get 1
    #|     i32.add))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  assert_eq(instrs[1], @lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  assert_eq(instrs[2], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  assert_eq(instrs[5], @lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
  assert_eq(instrs[6], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  assert_eq(instrs[7], @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
}

///|
test "coalesce-locals removes redundant copies after index sharing" {
  let input =
    #| (module
    #|   (func (result i32) (local i32 i32)
    #|     i32.const 11
    #|     local.set 0
    #|     local.get 0
    #|     local.set 1
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(11)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "coalesce-locals drops ineffective sets but preserves values" {
  let input =
    #| (module
    #|   (func (result i32) (local i32)
    #|     i32.const 11
    #|     local.set 0
    #|     i32.const 7))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(11)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(7)),
  ])
}
