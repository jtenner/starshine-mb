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
fn cl_test_ref_base_nullable() -> @lib.ValType {
  @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
}

///|
fn cl_test_ref_child_nullable() -> @lib.ValType {
  @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
}

///|
fn cl_test_local_subtyping_fixture() -> @lib.Module {
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
    @lib.SubType::comp_type(
      @lib.CompType::func([], [cl_test_ref_child_nullable()]),
    ),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([base, child, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([
          cl_test_ref_base_nullable(),
          cl_test_ref_child_nullable(),
        ]),
        @lib.Expr::new([
          @lib.Instruction::ref_null_type(
            @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
          ),
          @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
          @lib.Instruction::ref_null_type(
            @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
          ),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        ]),
      ),
    ]),
  )
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

///|
test "coalesce-locals uses local-subtyping's exact slot before local-cse and simplify-locals" {
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      cl_test_local_subtyping_fixture(),
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["local-subtyping", "coalesce-locals", "local-cse", "simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected local-subtyping/coalesce-locals/local-cse/simplify-locals success, got \{err}",
      )
  }
  let starts = trace.filter(fn(line) {
    line.contains("pass[") && line.contains(":start")
  })
  let mut ls_idx = -1
  let mut cl_idx = -1
  let mut cse_idx = -1
  let mut sl_idx = -1
  for idx = 0; idx < starts.length(); idx = idx + 1 {
    if starts[idx].contains("pass[local-subtyping]:start") {
      ls_idx = idx
    }
    if starts[idx].contains("pass[coalesce-locals]:start") {
      cl_idx = idx
    }
    if starts[idx].contains("pass[local-cse]:start") {
      cse_idx = idx
    }
    if starts[idx].contains("pass[simplify-locals]:start") {
      sl_idx = idx
    }
  }
  assert_eq(ls_idx, 0, msg=starts.to_string())
  assert_eq(cl_idx, 1, msg=starts.to_string())
  assert_eq(cse_idx, 2, msg=starts.to_string())
  assert_eq(sl_idx, 3, msg=starts.to_string())
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected exact coalesce-locals cleanup neighborhood to validate, got \{err}",
      )
  }
}

///|
test "coalesce-locals narrows a base ref local to the child slot before merging" {
  let optimized = match
    run_hot_pipeline(
      cl_test_local_subtyping_fixture(),
      HotPipelineOptions::new(),
      ["local-subtyping", "coalesce-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected local-subtyping/coalesce-locals success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  assert_eq(locals, @lib.Locals::from_types([cl_test_ref_child_nullable()]))
  assert_eq(instrs[1], @lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  assert_eq(instrs[2], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  assert_eq(instrs[5], @lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  assert_eq(instrs[6], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
}

///|
test "coalesce-locals replays the reorder-locals sandwich and reorders the merged slot" {
  let trace : Array[String] = []
  let input =
    #| (module
    #|   (func (result i32) (local i32 i32 i32)
    #|     i32.const 1
    #|     local.set 0
    #|     i32.const 2
    #|     local.set 1
    #|     local.get 1
    #|     drop
    #|     local.get 1
    #|     drop
    #|     local.get 0
    #|     drop
    #|     i32.const 3
    #|     local.set 2
    #|     local.get 2))
    #|
  let optimized = match
    run_hot_pipeline(
      pass_test_module_from_wat(input),
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["reorder-locals", "coalesce-locals", "reorder-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected reorder-locals/coalesce-locals/reorder-locals success, got \{err}",
      )
  }
  let starts = trace.filter(fn(line) {
    line.contains("pass[") && line.contains(":start")
  })
  assert_true(
    starts.length() >= 3 &&
    starts[0].contains("pass[reorder-locals]:start") &&
    starts[1].contains("pass[coalesce-locals]:start") &&
    starts[2].contains("pass[reorder-locals]:start"),
    msg=starts.to_string(),
  )
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  assert_eq(instrs[1], @lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
  assert_eq(instrs[3], @lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  assert_eq(instrs[4], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  assert_eq(instrs[6], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  assert_eq(instrs[8], @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  assert_eq(instrs[11], @lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  assert_eq(instrs[12], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
}
