///|
fn ls_test_module(
  body_local_type : @lib.ValType,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let base = @lib.RecType::new(
    @lib.SubType::new(false, [], @lib.CompType::struct_([])),
  )
  let child = @lib.RecType::new(
    @lib.SubType::new(
      false,
      [@lib.TypeIdx::new(0U)],
      @lib.CompType::struct_([]),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([base, child, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([body_local_type]),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
fn ls_test_first_body_local(mod_ : @lib.Module) -> @lib.ValType {
  match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(locals, _)])) => locals[0]
    other => abort("expected one function with one body local, got \{other}")
  }
}

///|
test "local-subtyping registers as an active module pass" {
  match pass_registry_lookup("local-subtyping") {
    Some(entry) => {
      @debug.assert_eq(entry.category, HotPassRegistryCategory::module_pass())
      @debug.assert_eq(entry.descriptor, None)
    }
    None => fail("expected local-subtyping registry entry")
  }
}

///|
test "local-subtyping narrows body locals to assigned child heap type" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let mod_ = ls_test_module(base_nullable, [
    @lib.Instruction::ref_null_type(
      @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
    ),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), child_nullable)
}

///|
test "local-subtyping keeps common supertype for mixed sibling assignments" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let mod_ = ls_test_module(base_nullable, [
    @lib.Instruction::ref_null_type(
      @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
    ),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_null_type(
      @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
    ),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), base_nullable)
}
