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
    other =>
      abort(
        "expected one function with one body local, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn ls_test_module_with_child_param(
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
  let child_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([child_ref], [])),
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

///|
test "local-subtyping narrows body locals from local.tee assignments" {
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
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), child_nullable)
}

///|
test "local-subtyping narrows nullable local to non-null after dominating write" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module(base_nullable, [
    @lib.Instruction::ref_null_type(
      @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
    ),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), child_nonnull)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected narrowed non-null local to validate, got \{err}")
  }
}

///|
test "local-subtyping keeps nullable fallback for get before non-null write" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let mod_ = ls_test_module(base_nullable, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null_type(
      @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
    ),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), child_nullable)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected nullable fallback local to validate, got \{err}")
  }
}

///|
test "local-subtyping accepts branch-free block gets dominated by earlier write" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param(base_nullable, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
      ]),
    ),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), child_nonnull)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected block-dominated narrowed local to validate, got \{err}")
  }
}

///|
test "local-subtyping keeps nullable fallback for get inside block before write" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let mod_ = ls_test_module_with_child_param(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), child_nullable)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected block fallback local to validate, got \{err}")
  }
}

///|
test "local-subtyping accepts nested branch-free if inside dominated block" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param(base_nullable, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32::new(1)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    ),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), child_nonnull)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nested-if dominated narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts branch-free if gets dominated by earlier write" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param(base_nullable, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
      ]),
    ),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), child_nonnull)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected if-dominated narrowed local to validate, got \{err}")
  }
}

///|
test "local-subtyping keeps nullable fallback for get inside if before write" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let mod_ = ls_test_module_with_child_param(base_nullable, [
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
      ],
      Some([@lib.Instruction::nop()]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), child_nullable)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected if fallback local to validate, got \{err}")
  }
}
