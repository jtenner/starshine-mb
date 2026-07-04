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
    Some(@lib.CodeSec([@lib.Func(locals, _), ..])) => locals[0]
    other =>
      abort(
        "expected first function with one body local, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn ls_test_first_body_locals(mod_ : @lib.Module) -> Array[@lib.ValType] {
  match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(locals, _), ..])) => {
      let result : Array[@lib.ValType] = []
      for idx = 0; idx < locals.length(); idx = idx + 1 {
        result.push(locals[idx])
      }
      result
    }
    other =>
      abort(
        "expected first function with body locals, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn ls_test_first_func_params(mod_ : @lib.Module) -> Array[@lib.ValType] {
  match mod_.type_sec {
    Some(@lib.TypeSec(types)) =>
      match types[2] {
        @lib.SingleRecType(subtype) =>
          match subtype.get_comptype() {
            @lib.FuncCompType(params, _) => params
            other =>
              abort("expected function type, got \{@debug.to_string(other)}")
          }
        other =>
          abort("expected single rec type, got \{@debug.to_string(other)}")
      }
    other => abort("expected type section, got \{@debug.to_string(other)}")
  }
}

///|
fn ls_test_module_with_base_param(
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
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([base_ref], [])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([base, child, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::from_types([]), @lib.Expr::new(body)),
    ]),
  )
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
fn ls_test_module_with_child_param_and_tag(
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
  let tag_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let child_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([child_ref], [])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([base, child, tag_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(3U)]))
  .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(2U))]))
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
fn ls_test_module_with_child_and_exn_params(
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
  let exn_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::exn())),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([child_ref, exn_ref], [])),
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
fn ls_test_module_with_child_param_and_callee(
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
  let main_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([child_ref], [])),
  )
  let callee_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([base, child, main_type, callee_type]))
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(2U), @lib.TypeIdx::new(3U)]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([body_local_type]),
        @lib.Expr::new(body),
      ),
      @lib.Func::new(@lib.Locals::from_types([]), @lib.Expr::new([])),
    ]),
  )
}

///|
fn ls_test_module_with_child_param_and_tail_refs(
  body_local_type : @lib.ValType,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  ls_test_module_with_child_param_callee_locals_and_tail_refs(
    [body_local_type],
    body,
  )
}

///|
fn ls_test_module_with_child_param_callee_locals_and_tail_refs(
  body_local_types : Array[@lib.ValType],
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
  let main_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([child_ref], [])),
  )
  let callee_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let func_ref_type = @lib.RefType::new(
    true,
    @lib.HeapType::abs(@lib.AbsHeapType::func()),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([base, child, main_type, callee_type]))
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(2U), @lib.TypeIdx::new(3U)]),
  )
  .with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        @lib.TableType::new(func_ref_type, @lib.Limits::i32(1U, Some(1U))),
        None,
      ),
    ]),
  )
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::active(
          @lib.TableIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types(body_local_types),
        @lib.Expr::new(body),
      ),
      @lib.Func::new(@lib.Locals::from_types([]), @lib.Expr::new([])),
    ]),
  )
}

///|
fn ls_test_module_with_child_param_tag_and_tail_refs(
  body_local_type : @lib.ValType,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  ls_test_module_with_child_param_and_tail_refs(body_local_type, body).with_tag_sec(
    @lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(3U))]),
  )
}

///|
fn ls_test_module_with_i32_param_and_imported_func_refs(
  body_local_types : Array[@lib.ValType],
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let i32_func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let i64_func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i64()])),
  )
  let main_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([i32_func_type, i64_func_type, main_type]))
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::new("out"),
        @lib.Name::new("i32"),
        @lib.ExternType::func(@lib.TypeIdx::new(0U)),
      ),
      @lib.Import::new(
        @lib.Name::new("out"),
        @lib.Name::new("i64"),
        @lib.ExternType::func(@lib.TypeIdx::new(1U)),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::declarative(),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types(body_local_types),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
fn ls_test_module_with_ret_any_and_i31_call_ref(
  body_local_types : Array[@lib.ValType],
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let ret_any_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::anyref()])),
  )
  let ret_i31_type = @lib.RecType::new(
    @lib.SubType::new(
      false,
      [@lib.TypeIdx::new(0U)],
      @lib.CompType::func([], [@lib.ValType::i31ref()]),
    ),
  )
  let main_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([ret_any_type, ret_i31_type, main_type]))
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(2U), @lib.TypeIdx::new(1U)]),
  )
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::declarative(),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types(body_local_types),
        @lib.Expr::new(body),
      ),
      @lib.Func::new(
        @lib.Locals::from_types([]),
        @lib.Expr::new([@lib.Instruction::unreachable_()]),
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
test "local-subtyping iterates after local.get assignment refinalization" {
  let funcref_nullable = @lib.ValType::funcref()
  let callee_nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(3U)),
      exact=true,
    ),
  )
  let mod_ = ls_test_module_with_child_param_callee_locals_and_tail_refs(
    [funcref_nullable, funcref_nullable],
    [
      @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::drop(),
    ],
  )
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_locals(optimized), [
    callee_nonnull, callee_nonnull,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected iterated local-subtyping module to validate, got \{err}")
  }
}

///|
test "local-subtyping iterates after select LUB refinalization" {
  let funcref_nullable = @lib.ValType::funcref()
  let i32_func_nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      exact=true,
    ),
  )
  let i64_func_nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  let func_nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::func())),
  )
  let mod_ = ls_test_module_with_i32_param_and_imported_func_refs(
    [funcref_nullable, funcref_nullable, funcref_nullable],
    [
      @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::select(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
      @lib.Instruction::drop(),
    ],
  )
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_locals(optimized), [
    i32_func_nonnull, i64_func_nonnull, func_nonnull,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected iterated select-LUB local-subtyping module to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping iterates after call_ref result refinalization" {
  let ret_any_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let ret_i31_nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  let mod_ = ls_test_module_with_ret_any_and_i31_call_ref(
    [ret_any_nullable, @lib.ValType::anyref()],
    [
      @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call_ref(@lib.TypeIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::drop(),
    ],
  )
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_locals(optimized), [
    ret_i31_nonnull,
    @lib.ValType::i31ref(),
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected iterated call_ref local-subtyping module to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping replaces bottom call_ref refinalization with unreachable value" {
  let ret_any_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let nullfuncref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::no_func())),
  )
  let mod_ = ls_test_module_with_ret_any_and_i31_call_ref(
    [ret_any_nullable, @lib.ValType::anyref()],
    [
      @lib.Instruction::ref_null(
        @lib.HeapType::abs(@lib.AbsHeapType::no_func()),
      ),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call_ref(@lib.TypeIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ],
  )
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_locals(optimized), [
    nullfuncref,
    @lib.ValType::ref_type(
      @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::none())),
    ),
  ])
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call_ref"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected bottom call_ref local-subtyping module to validate, got \{err}: \{pretty}",
      )
  }
}

///|
test "local-subtyping retag representation validates tee parent after narrowing" {
  let funcref_nullable = @lib.ValType::funcref()
  let callee_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(3U)),
    exact=true,
  )
  let callee_nonnull = @lib.ValType::ref_type(callee_ref)
  let mod_ = ls_test_module_with_child_param_and_tail_refs(funcref_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::val_type(funcref_nullable),
      @lib.Expr::new([
        @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), callee_nonnull)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tee-parent narrowed module to validate without retag repair, got \{err}",
      )
  }
}

///|
test "local-subtyping keeps nullable for unreachable-before-write tee boundary" {
  let funcref_nullable = @lib.ValType::funcref()
  let callee_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(
      true,
      @lib.HeapType::new(@lib.TypeIdx::new(3U)),
      exact=true,
    ),
  )
  let mod_ = ls_test_module_with_child_param_and_tail_refs(funcref_nullable, [
    @lib.Instruction::unreachable_(),
    @lib.Instruction::block(
      @lib.BlockType::val_type(funcref_nullable),
      @lib.Expr::new([
        @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), callee_nullable)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected unreachable-before-write tee/get boundary to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping narrows local.tee non-null assignment to non-null" {
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
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
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
    Err(err) =>
      fail("expected non-null tee-narrowed local to validate, got \{err}")
  }
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
test "local-subtyping keeps source-backed nullable parameter after write" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let mod_ = ls_test_module_with_base_param([
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
  @debug.assert_eq(ls_test_first_func_params(optimized), [base_nullable])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected parameter-preserving module to validate, got \{err}")
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
test "local-subtyping propagates branch-free block write to following get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
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
    Err(err) =>
      fail("expected block-propagated narrowed local to validate, got \{err}")
  }
}

///|
test "local-subtyping accepts terminal branch after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
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
      fail("expected terminal-branch narrowed local to validate, got \{err}")
  }
}

///|
test "local-subtyping accepts terminal br_table after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32::new(0)),
        @lib.Instruction::br_table(
          [@lib.LabelIdx::new(0U)],
          @lib.LabelIdx::new(0U),
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
      fail("expected terminal-br_table narrowed local to validate, got \{err}")
  }
}

///|
test "local-subtyping keeps nullable block post-state with branch flow" {
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
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), child_nullable)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected branch-flow block-post-state fallback to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping keeps nullable direct block return flow until validator support" {
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
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::return_(),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), child_nullable)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nullable direct-return boundary to validate, got \{err}")
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
test "local-subtyping accepts branch-free loop gets dominated by earlier write" {
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
    @lib.Instruction::loop_(
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
      fail("expected loop-dominated narrowed local to validate, got \{err}")
  }
}

///|
test "local-subtyping accepts loop backedge gets dominated by earlier write" {
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
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32::new(0)),
        @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
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
        "expected loop-backedge dominated narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping keeps nullable when br_if can skip block write" {
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
        @lib.Instruction::i32_const(@lib.I32::new(1)),
        @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), child_nullable)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected br_if-skipped write fallback to validate, got \{err}")
  }
}

///|
test "local-subtyping keeps nullable after branch-free loop write before outside get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let mod_ = ls_test_module_with_child_param(base_nullable, [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), child_nullable)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected loop-post-state fallback to validate, got \{err}")
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
test "local-subtyping accepts root terminal throw after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_tag(base_nullable, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::throw_(@lib.TagIdx::new(0U)),
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
      fail("expected terminal-throw narrowed local to validate, got \{err}")
  }
}

///|
test "local-subtyping accepts root terminal throw_ref after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_and_exn_params(base_nullable, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::throw_ref(),
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
      fail("expected terminal-throw_ref narrowed local to validate, got \{err}")
  }
}

///|
test "local-subtyping accepts block terminal throw_ref after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_and_exn_params(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::throw_ref(),
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
        "expected block-terminal-throw_ref narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts throw_ref-skipped path before dominating write" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_and_exn_params(base_nullable, [
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::throw_ref(),
      ],
      None,
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
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
    Err(err) =>
      fail("expected throw_ref-skipped narrowed local to validate, got \{err}")
  }
}

///|
test "local-subtyping accepts try_table terminal throw_ref after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_and_exn_params(base_nullable, [
    @lib.Instruction::try_table(
      @lib.BlockType::void_(),
      [],
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::throw_ref(),
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
        "expected try_table terminal-throw_ref narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts try_table throw_ref before unreachable tail get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_and_exn_params(base_nullable, [
    @lib.Instruction::try_table(
      @lib.BlockType::void_(),
      [],
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::throw_ref(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
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
      fail(
        "expected try_table throw_ref before unreachable get to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts try_table body dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_tag(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
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
      fail("expected try_table-body narrowed local to validate, got \{err}")
  }
}

///|
test "local-subtyping accepts try_table terminal throw after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_tag(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::throw_(@lib.TagIdx::new(0U)),
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
        "expected try_table terminal-throw narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts try_table throw with trailing unreachable after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_tag(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::throw_(@lib.TagIdx::new(0U)),
            @lib.Instruction::unreachable_(),
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
        "expected try_table throw plus unreachable narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts try_table throw before unreachable tail get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_tag(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::throw_(@lib.TagIdx::new(0U)),
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
        "expected try_table throw before unreachable get to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts try_table terminal return after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let mod_ = ls_test_module_with_child_param_and_tag(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::return_(),
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
        "expected try_table terminal-return narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts try_table return with trailing unreachable after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let mod_ = ls_test_module_with_child_param_and_tag(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::return_(),
            @lib.Instruction::unreachable_(),
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
        "expected try_table return plus unreachable narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts try_table return before unreachable tail get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let mod_ = ls_test_module_with_child_param_and_tag(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::return_(),
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
        "expected try_table return before unreachable get to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts try_table terminal return_call after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let mod_ = ls_test_module_with_child_param_tag_and_tail_refs(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::return_call(@lib.FuncIdx::new(1U)),
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
        "expected try_table terminal-return_call narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts try_table terminal return_call_indirect after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let mod_ = ls_test_module_with_child_param_tag_and_tail_refs(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::return_call_indirect(
              @lib.TypeIdx::new(3U),
              @lib.TableIdx::new(0U),
            ),
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
        "expected try_table terminal-return_call_indirect narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts try_table terminal return_call_ref after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let mod_ = ls_test_module_with_child_param_tag_and_tail_refs(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::return_call_ref(@lib.TypeIdx::new(3U)),
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
        "expected try_table terminal-return_call_ref narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts try_table return_call before unreachable tail get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let mod_ = ls_test_module_with_child_param_tag_and_tail_refs(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::return_call(@lib.FuncIdx::new(1U)),
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
        "expected try_table return_call before unreachable get to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts try_table return_call_indirect before unreachable tail get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let mod_ = ls_test_module_with_child_param_tag_and_tail_refs(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::return_call_indirect(
              @lib.TypeIdx::new(3U),
              @lib.TableIdx::new(0U),
            ),
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
        "expected try_table return_call_indirect before unreachable get to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts try_table return_call_ref before unreachable tail get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_nonnull = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let mod_ = ls_test_module_with_child_param_tag_and_tail_refs(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::return_call_ref(@lib.TypeIdx::new(3U)),
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
        "expected try_table return_call_ref before unreachable get to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping keeps try_table body write nullable before outside get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let mod_ = ls_test_module_with_child_param_and_tag(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), child_nullable)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected try_table nullable post-state fallback to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts block terminal return after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
        @lib.Instruction::return_(),
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
        "expected block-terminal-return narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts block terminal throw after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_tag(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
        @lib.Instruction::throw_(@lib.TagIdx::new(0U)),
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
        "expected block-terminal-throw narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts root terminal return after dominated get" {
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
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::return_(),
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
      fail("expected terminal-return narrowed local to validate, got \{err}")
  }
}

///|
test "local-subtyping accepts root terminal return_call after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_callee(base_nullable, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::return_call(@lib.FuncIdx::new(1U)),
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
        "expected terminal-return_call narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts root return before unreachable tail get" {
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
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::return_(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
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
    Err(err) =>
      fail(
        "expected root-return unreachable-tail narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts root return_call before unreachable tail get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_callee(base_nullable, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::return_call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
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
    Err(err) =>
      fail(
        "expected root-return_call unreachable-tail narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts root return_call_indirect before unreachable tail get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_tail_refs(base_nullable, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::return_call_indirect(
      @lib.TypeIdx::new(3U),
      @lib.TableIdx::new(0U),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
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
    Err(err) =>
      fail(
        "expected root-return_call_indirect unreachable-tail narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts root return_call_ref before unreachable tail get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_tail_refs(base_nullable, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
    @lib.Instruction::return_call_ref(@lib.TypeIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
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
    Err(err) =>
      fail(
        "expected root-return_call_ref unreachable-tail narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts root terminal return_call_indirect after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_tail_refs(base_nullable, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::return_call_indirect(
      @lib.TypeIdx::new(3U),
      @lib.TableIdx::new(0U),
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
        "expected terminal-return_call_indirect narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts root terminal return_call_ref after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_tail_refs(base_nullable, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
    @lib.Instruction::return_call_ref(@lib.TypeIdx::new(3U)),
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
        "expected terminal-return_call_ref narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts block terminal return_call_indirect after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_tail_refs(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::return_call_indirect(
          @lib.TypeIdx::new(3U),
          @lib.TableIdx::new(0U),
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
        "expected block-terminal-return_call_indirect narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts block terminal return_call_ref after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_tail_refs(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
        @lib.Instruction::return_call_ref(@lib.TypeIdx::new(3U)),
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
        "expected block-terminal-return_call_ref narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts block terminal return_call after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_callee(base_nullable, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
        @lib.Instruction::return_call(@lib.FuncIdx::new(1U)),
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
        "expected block-terminal-return_call narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts return-skipped path before dominating write" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param(base_nullable, [
    @lib.Instruction::i32_const(@lib.I32::new(0)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::return_()],
      None,
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
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
    Err(err) =>
      fail("expected return-skipped narrowed local to validate, got \{err}")
  }
}

///|
test "local-subtyping accepts return_call-skipped path before dominating write" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_callee(base_nullable, [
    @lib.Instruction::i32_const(@lib.I32::new(0)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::return_call(@lib.FuncIdx::new(1U))],
      None,
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
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
    Err(err) =>
      fail(
        "expected return_call-skipped narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts return_call_indirect-skipped path before dominating write" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_tail_refs(base_nullable, [
    @lib.Instruction::i32_const(@lib.I32::new(0)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::return_call_indirect(
          @lib.TypeIdx::new(3U),
          @lib.TableIdx::new(0U),
        ),
      ],
      None,
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
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
    Err(err) =>
      fail(
        "expected return_call_indirect-skipped narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts return_call_ref-skipped path before dominating write" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_tail_refs(base_nullable, [
    @lib.Instruction::i32_const(@lib.I32::new(0)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
        @lib.Instruction::return_call_ref(@lib.TypeIdx::new(3U)),
      ],
      None,
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
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
    Err(err) =>
      fail(
        "expected return_call_ref-skipped narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts throw-skipped path before dominating write" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_tag(base_nullable, [
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::throw_(@lib.TagIdx::new(0U))],
      Some([@lib.Instruction::nop()]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
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
    Err(err) =>
      fail("expected throw-skipped narrowed local to validate, got \{err}")
  }
}

///|
test "local-subtyping accepts if-arm block terminal return after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param(base_nullable, [
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::return_(),
          ]),
        ),
      ],
      Some([@lib.Instruction::nop()]),
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
        "expected if-arm block-terminal-return narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping accepts if-arm block terminal throw after dominated get" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nonnull = @lib.ValType::ref_type(child_ref)
  let mod_ = ls_test_module_with_child_param_and_tag(base_nullable, [
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::throw_(@lib.TagIdx::new(0U)),
          ]),
        ),
      ],
      Some([@lib.Instruction::nop()]),
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
        "expected if-arm block-terminal-throw narrowed local to validate, got \{err}",
      )
  }
}

///|
test "local-subtyping keeps nullable after all if arms write before outside get" {
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
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ])
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-subtyping pipeline success, got \{err}")
  }
  @debug.assert_eq(ls_test_first_body_local(optimized), child_nullable)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected if-post-state fallback local to validate, got \{err}")
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
