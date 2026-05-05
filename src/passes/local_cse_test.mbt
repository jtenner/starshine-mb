///|
fn lcse_test_first_defined_func(mod_ : @lib.Module) -> @lib.Func {
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
test "local-cse registers as an active module pass" {
  match pass_registry_lookup("local-cse") {
    Some(entry) => {
      assert_eq(entry.category, HotPassRegistryCategory::module_pass())
      assert_eq(entry.descriptor, None)
    }
    None => fail("expected local-cse registry entry")
  }
}

///|
test "local-cse reuses repeated same-window arithmetic trees" {
  let input =
    #| (module
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_true(
    instrs.contains(@lib.Instruction::local_tee(@lib.LocalIdx::new(2U))),
  )
  assert_true(
    instrs.contains(@lib.Instruction::local_get(@lib.LocalIdx::new(2U))),
  )
}

///|
test "local-cse clears the reuse window across local writes" {
  let input =
    #| (module
    #|   (func (param i32 i32) (local i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (local.set 2 (i32.const 7))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_false(
    instrs.contains(@lib.Instruction::local_tee(@lib.LocalIdx::new(3U))),
  )
}
