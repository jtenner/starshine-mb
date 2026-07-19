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
fn cl_test_instrs_contain_local_set(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      @lib.LocalSet(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn cl_test_instrs_contain_drop(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Drop => return true
      _ => ()
    }
  }
  false
}

///|
fn cl_test_instrs_contain_local_tee(
  instrs : Array[@lib.Instruction],
  expected : @lib.LocalIdx,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.LocalTee(local_idx) => if local_idx == expected { return true }
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if cl_test_instrs_contain_local_tee(body, expected) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if cl_test_instrs_contain_local_tee(then_body, expected) {
          return true
        }
        match else_body {
          Some(body) =>
            if cl_test_instrs_contain_local_tee(body, expected) {
              return true
            }
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if cl_test_instrs_contain_local_tee(body, expected) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn cl_test_local_idx_raw(idx : @lib.LocalIdx) -> Int {
  let @lib.LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn cl_test_instrs_contain_body_to_body_copy_set(
  instrs : Array[@lib.Instruction],
  param_count : Int,
) -> Bool {
  let mut idx = 0
  while idx + 1 < instrs.length() {
    match (instrs[idx], instrs[idx + 1]) {
      (@lib.LocalGet(src), @lib.LocalSet(dest)) =>
        if src != dest &&
          cl_test_local_idx_raw(src) >= param_count &&
          cl_test_local_idx_raw(dest) >= param_count {
          return true
        }
      _ => ()
    }
    idx += 1
  }
  false
}

///|
fn cl_test_first_if_instr(
  instrs : Array[@lib.Instruction],
) -> @lib.Instruction raise {
  for instr in instrs {
    match instr {
      @lib.If(_, _, _) => return instr
      _ => ()
    }
  }
  fail("expected structured if")
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
      @debug.assert_eq(entry.category, HotPassRegistryCategory::module_pass())
      @debug.assert_eq(entry.descriptor, None)
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
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(
    instrs[1],
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[2],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[5],
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[6],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
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
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(
    instrs[1],
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[3],
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  )
  @debug.assert_eq(
    instrs[4],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[6],
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  )
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
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(
    instrs[1],
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[2],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[5],
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  )
  @debug.assert_eq(
    instrs[6],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[7],
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  )
}

///|
test "coalesce-locals reuses structured param slots after conditions die" {
  let input =
    #| (module
    #|   (func (param i32) (result i32) (local i32 i32)
    #|     local.get 0
    #|     if
    #|       i32.const 11
    #|       local.set 1
    #|       local.get 1
    #|       drop
    #|     end
    #|     i32.const 22
    #|     local.set 2
    #|     local.get 2))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, _) = cl_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
}

///|
test "coalesce-locals keeps preserved structured dead sets from clobbering live locals" {
  let input =
    #| (module
    #|   (func (param i32) (result i32) (local i32 i32)
    #|     i32.const 11
    #|     local.set 1
    #|     local.get 0
    #|     if
    #|       i32.const 22
    #|       local.set 2
    #|     end
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(
    instrs[instrs.length() - 1],
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  )
}

///|
test "coalesce-locals can reuse a dead structured param slot without moving params" {
  let input =
    #| (module
    #|   (func (param i32) (param i64) (result i32) (local i64 i32)
    #|     local.get 0
    #|     if
    #|       nop
    #|     end
    #|     i64.const 11
    #|     local.set 2
    #|     i32.const 7
    #|     local.set 3
    #|     local.get 3))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(instrs[3], @lib.Instruction::drop())
  @debug.assert_eq(
    instrs[5],
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[6],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
}

///|
test "coalesce-locals keeps accessed loop locals conservative" {
  let input =
    #| (module
    #|   (func (param i32) (result i32) (local i32 i32)
    #|     i32.const 11
    #|     local.set 1
    #|     loop
    #|       local.get 0
    #|       br_if 0
    #|     end
    #|     i32.const 22
    #|     local.set 2
    #|     local.get 2))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, _) = cl_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
}

///|
test "coalesce-locals coalesces syntactically unused locals in loop functions" {
  let input =
    #| (module
    #|   (func (param i64) (local i64 i64 i32 i64)
    #|     block
    #|       i32.const 0
    #|       br_if 0
    #|     end
    #|     loop
    #|       i32.const 0
    #|       br_if 0
    #|     end))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, _) = cl_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
}

///|
test "coalesce-locals coalesces adjacent loop copy chains" {
  // Reduced from the O4z startup-map function 18 size-losing loop family:
  // single-use locals that only shuttle a value through adjacent copy pairs do
  // not need distinct loop-carrier slots. The final read local remains distinct.
  let input =
    #| (module
    #|   (func (param i32) (result i32) (local i32 i32 i32)
    #|     i32.const 11
    #|     local.set 1
    #|     local.get 1
    #|     local.set 2
    #|     local.get 2
    #|     local.set 3
    #|     loop
    #|       local.get 0
    #|       br_if 0
    #|     end
    #|     local.get 3))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(
    instrs[instrs.length() - 1],
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  )
}

///|
test "coalesce-locals coalesces non-adjacent loop copy-through locals" {
  // A single-use loop-function shuttle local can be assigned to the final
  // destination slot even when independent stack work sits between the set and
  // the copy. The destination is not read in that window, so moving the local
  // overwrite earlier does not change loop-carried values.
  let input =
    #| (module
    #|   (func (param i32) (result i32) (local i32 i32)
    #|     local.get 0
    #|     local.set 1
    #|     i32.const 7
    #|     drop
    #|     local.get 1
    #|     local.set 2
    #|     loop
    #|       local.get 0
    #|       br_if 0
    #|     end
    #|     local.get 2))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(
    instrs[instrs.length() - 1],
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  )
}

///|
test "coalesce-locals coalesces unread loop locals without clobbering live locals" {
  // Reduced from the O4z startup-map function 18 size-losing loop family:
  // locals that are written in a loop but never read from the local slot do not
  // need one slot each. They may share a dead scratch slot, but not a live local
  // or param slot that is read after the loop.
  let input =
    #| (module
    #|   (func (param i32) (result i32) (local i32 i32 i32)
    #|     loop
    #|       i32.const 1
    #|       local.set 1
    #|       i32.const 2
    #|       local.tee 2
    #|       drop
    #|       local.get 0
    #|       br_if 0
    #|     end
    #|     i32.const 3
    #|     local.set 3
    #|     local.get 3))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(
    instrs[instrs.length() - 1],
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  )
}

///|
test "coalesce-locals packs accessed GC refs before unused leading locals" {
  // Reduced from random-all-profiles heap2local-struct case 000006: the only
  // used local is a nullable struct ref after unused scalar/function-ref locals.
  // Binaryen assigns the used ref to the first compatible body slot and leaves
  // the unused declarations after it; keep Starshine's local numbering aligned
  // instead of preserving unused leading local debris.
  let func_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
              @lib.FieldType::new(
                @lib.StorageType::val_type(
                  @lib.ValType::ref_type(
                    @lib.RefType::new(
                      true,
                      @lib.HeapType::abs(@lib.AbsHeapType::eq()),
                    ),
                  ),
                ),
                @lib.Mut::const_(),
              ),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), func_ref, struct_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(10)),
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::eq()),
            ),
            @lib.Instruction::struct_new(@lib.TypeIdx::new(1U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::i32_const(@lib.I32(30)),
            @lib.Instruction::struct_set(@lib.TypeIdx::new(1U), @lib.U32(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::struct_get(@lib.TypeIdx::new(1U), @lib.U32(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::struct_new_default(@lib.TypeIdx::new(1U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::struct_get(@lib.TypeIdx::new(1U), @lib.U32(0U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([struct_ref, func_ref, @lib.ValType::i32()]),
  )
  @debug.assert_eq(
    instrs[3],
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[4],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[11],
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(instrs[12], @lib.Instruction::nop())
  @debug.assert_eq(
    instrs[13],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
}

///|
test "coalesce-locals packs accessed GC refs before unused trailing refs" {
  // Reduced from random-all-profiles heap2local-struct case 000022: a used
  // nullable struct ref sits between unused function-ref and array-ref locals.
  // Binaryen still lets the accessed concrete struct ref claim body slot 0,
  // then leaves the unused typed-ref debris in natural order behind it.
  let func_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(2U))),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
              @lib.FieldType::new(
                @lib.StorageType::val_type(
                  @lib.ValType::ref_type(
                    @lib.RefType::new(
                      true,
                      @lib.HeapType::abs(@lib.AbsHeapType::eq()),
                    ),
                  ),
                ),
                @lib.Mut::const_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [],
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::i32(),
            func_ref,
            struct_ref,
            array_ref,
          ]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(10)),
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::eq()),
            ),
            @lib.Instruction::struct_new(@lib.TypeIdx::new(1U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::i32_const(@lib.I32(30)),
            @lib.Instruction::struct_set(@lib.TypeIdx::new(1U), @lib.U32(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::struct_get(@lib.TypeIdx::new(1U), @lib.U32(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::struct_new_default(@lib.TypeIdx::new(1U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::struct_get(@lib.TypeIdx::new(1U), @lib.U32(0U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      struct_ref,
      func_ref,
      array_ref,
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(
    instrs[3],
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[4],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[11],
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(instrs[12], @lib.Instruction::nop())
  @debug.assert_eq(
    instrs[13],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
}

///|
test "coalesce-locals intentionally skips dense coloring above local-count guard" {
  // Boundary test: dense coloring is intentionally not run for very large
  // non-loop functions because the interference/copy matrices are quadratic in
  // the flattened local count. Smaller functions keep the Binaryen-compatible
  // coalescing path; large functions are left unchanged until a sparse coloring
  // representation lands.
  let input = StringBuilder::new()
  input.write_string("(module (func (result i32) (local")
  for _idx = 0; _idx < 4097; _idx = _idx + 1 {
    input.write_string(" i32")
  }
  input.write_string(") i32.const 0))")
  let optimized = match
    pass_test_run_pipeline(input.to_string(), ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals.length(), 4097)
  @debug.assert_eq(instrs, [@lib.Instruction::i32_const(@lib.I32(0))])
}

///|
test "coalesce-locals drops structured ineffective copy sets" {
  let input =
    #| (module
    #|   (func (param i32) (param i32) (result i32) (local i32)
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 1
    #|     else
    #|       i32.const 0
    #|       local.set 0
    #|       local.get 2
    #|       local.set 1
    #|       local.get 0
    #|     end))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  match instrs[1] {
    @lib.If(_, _, Some(else_body)) => {
      @debug.assert_eq(
        else_body[1],
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      )
      @debug.assert_eq(
        else_body[2],
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      )
      @debug.assert_eq(else_body[3], @lib.Instruction::drop())
      @debug.assert_eq(
        else_body[4],
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      )
    }
    other => fail("expected structured if, got \{@debug.to_string(other)}")
  }
}

///|
test "coalesce-locals forwards structured branch copies into dead param slots" {
  let input =
    #| (module
    #|   (func (param i32) (param i32) (result i32) (local i32 i32 i32)
    #|     local.get 1
    #|     i32.const 256
    #|     i32.lt_u
    #|     if (result i32)
    #|       local.get 1
    #|       i32.const 4
    #|       i32.shr_u
    #|       local.set 3
    #|       i32.const 0
    #|       local.set 2
    #|       local.get 3
    #|       local.set 1
    #|       local.get 2
    #|     else
    #|       local.get 1
    #|       i32.const 16
    #|       i32.xor
    #|       local.set 3
    #|       i32.const 7
    #|       local.set 2
    #|       local.get 3
    #|       local.set 1
    #|       local.get 2
    #|     end))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  match instrs[3] {
    @lib.If(_, then_body, Some(else_body)) => {
      @debug.assert_eq(
        then_body[3],
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      )
      @debug.assert_eq(then_body[6], @lib.Instruction::nop())
      @debug.assert_eq(
        then_body[7],
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      )
      @debug.assert_eq(
        else_body[3],
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      )
      @debug.assert_eq(else_body[6], @lib.Instruction::nop())
      @debug.assert_eq(
        else_body[7],
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      )
    }
    other => fail("expected structured if, got \{@debug.to_string(other)}")
  }
}

///|
test "coalesce-locals keeps structured destination reads after source writes" {
  // Regression for the O4z startup-map residual first-diff family: a body
  // local written from a parameter cannot share that parameter slot while the
  // parameter is read again before the body value is explicitly copied back.
  let input =
    #| (module
    #|   (func (param i32) (param i32) (result i32) (local i32)
    #|     local.get 0
    #|     if (result i32)
    #|       local.get 1
    #|       i32.clz
    #|       local.tee 2
    #|       local.get 0
    #|       local.get 1
    #|       i32.add
    #|       i32.add
    #|       local.get 2
    #|       local.set 1
    #|       local.get 1
    #|       i32.add
    #|     else
    #|       i32.const 0
    #|     end))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  match instrs[1] {
    @lib.If(_, then_body, Some(_)) => {
      @debug.assert_eq(
        then_body[2],
        @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
      )
      @debug.assert_eq(
        then_body[3],
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      )
      @debug.assert_eq(
        then_body[4],
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      )
      @debug.assert_eq(
        then_body[7],
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      )
    }
    other => fail("expected structured if, got \{@debug.to_string(other)}")
  }
}

///|
test "coalesce-locals preserves structured side-carrier writes across branch arms" {
  // Reduced from the O4z startup-map defined=2 residual: a value written in
  // each mutually-exclusive arm is consumed after the if, while the if result
  // itself is a separate carrier. The structured liveness model must mark the
  // then-arm side-carrier write effective even though a flattened scan sees the
  // else-arm write later.
  let input =
    #| (module
    #|   (func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32)
    #|     local.get 0
    #|     local.tee 4
    #|     i32.const 256
    #|     i32.lt_u
    #|     if (result i32)
    #|       local.get 4
    #|       i32.const 4
    #|       i32.shr_u
    #|       local.set 1
    #|       i32.const 0
    #|       local.set 2
    #|       local.get 4
    #|       local.set 5
    #|       local.get 1
    #|       local.set 6
    #|       local.get 2
    #|     else
    #|       local.get 4
    #|       i32.const 16
    #|       i32.xor
    #|       local.set 1
    #|       i32.const 7
    #|       local.set 2
    #|       local.get 4
    #|       local.set 5
    #|       local.get 1
    #|       local.set 6
    #|       local.get 2
    #|     end
    #|     local.set 3
    #|     local.get 3
    #|     i32.const 4
    #|     i32.shl
    #|     local.get 6
    #|     i32.add))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = cl_test_first_defined_func(optimized)
  match cl_test_first_if_instr(instrs) {
    @lib.If(_, then_body, Some(else_body)) => {
      assert_false(
        cl_test_instrs_contain_drop(then_body),
        msg="then-arm live side-carrier write must not be rewritten to drop",
      )
      assert_true(
        cl_test_instrs_contain_local_set(else_body),
        msg="else-arm side-carrier write must stay effective",
      )
    }
    other => fail("expected structured if, got \{@debug.to_string(other)}")
  }
}

///|
test "coalesce-locals colors structured side-carrier copy chains before unrelated locals" {
  // Reduced from the O4z startup-map defined=2 residual after the branch-aware
  // effective-write fix. The final side-carrier (`25`) is copied from branch-
  // local index carriers (`21`/`23`) and then lives across an unrelated local
  // (`15`) after the if. Coloring the unrelated local into the carrier source
  // slot first leaves a cross-local branch copy and matches the active Binaryen
  // size-losing drift; copy-connected branch carriers should get first choice.
  let input =
    #| (module
    #|   (func (param i32) (param i32) (result i32)
    #|     (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|     local.get 1
    #|     local.tee 6
    #|     i32.const 256
    #|     i32.lt_u
    #|     if (result i32)
    #|       local.get 6
    #|       i32.const 4
    #|       i32.shr_u
    #|       local.set 7
    #|       i32.const 0
    #|       local.set 13
    #|       local.get 6
    #|       local.set 20
    #|       local.get 7
    #|       local.set 21
    #|       local.get 13
    #|       local.set 26
    #|       local.get 20
    #|       local.set 24
    #|       local.get 21
    #|       local.set 25
    #|       local.get 26
    #|     else
    #|       local.get 6
    #|       local.tee 8
    #|       i32.clz
    #|       local.set 9
    #|       local.get 8
    #|       i32.const 16
    #|       i32.xor
    #|       local.set 10
    #|       local.get 9
    #|       i32.const 7
    #|       i32.sub
    #|       local.set 14
    #|       local.get 9
    #|       local.set 22
    #|       local.get 10
    #|       local.set 23
    #|       local.get 14
    #|       local.set 27
    #|       local.get 22
    #|       local.set 24
    #|       local.get 23
    #|       local.set 25
    #|       local.get 27
    #|     end
    #|     local.set 5
    #|     i32.const 99
    #|     local.set 15
    #|     local.get 5
    #|     local.get 25
    #|     i32.add
    #|     local.get 15
    #|     i32.add
    #|     local.get 1
    #|     i32.add))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = cl_test_first_defined_func(optimized)
  match cl_test_first_if_instr(instrs) {
    @lib.If(_, then_body, Some(else_body)) => {
      assert_false(
        cl_test_instrs_contain_body_to_body_copy_set(then_body, 2),
        msg="then-arm side-carrier copy chain should coalesce before unrelated locals claim the slot",
      )
      assert_false(
        cl_test_instrs_contain_body_to_body_copy_set(else_body, 2),
        msg="else-arm side-carrier copy chain should coalesce before unrelated locals claim the slot",
      )
    }
    other => fail("expected structured if, got \{@debug.to_string(other)}")
  }
}

///|
test "coalesce-locals reuses param slots across exclusive branch result writes" {
  // The then/else scratch locals are written only after their corresponding
  // branch has consumed the original param value. Reads of the param in the
  // opposite branch are mutually exclusive, so they must not force an extra
  // body slot for the branch result carriers.
  let input =
    #| (module
    #|   (func (param i32) (result i32) (local i32 i32)
    #|     local.get 0
    #|     i32.const 1
    #|     i32.and
    #|     if (result i32)
    #|       local.get 0
    #|       i32.const 4
    #|       i32.add
    #|       local.set 1
    #|       local.get 1
    #|     else
    #|       local.get 0
    #|       i32.const 8
    #|       i32.add
    #|       local.set 2
    #|       local.get 2
    #|     end))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  match instrs[3] {
    @lib.If(_, then_body, Some(else_body)) => {
      @debug.assert_eq(
        then_body[3],
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      )
      @debug.assert_eq(
        then_body[4],
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      )
      @debug.assert_eq(
        else_body[3],
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      )
      @debug.assert_eq(
        else_body[4],
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      )
    }
    other => fail("expected structured if, got \{@debug.to_string(other)}")
  }
}

///|
test "coalesce-locals coalesces structured derived branch carriers" {
  // Reduced from the remaining O4z startup-map first-diff family. Binaryen
  // safely reuses one i32 body slot for branch-local values that are consumed
  // into derived branch carriers before the old value is read again.
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (param i32) (param i32) (result i32)
    #|     (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|     local.get 0
    #|     local.get 1
    #|     i32.const 256
    #|     i32.lt_u
    #|     if (result i32)
    #|       local.get 1
    #|       i32.const 4
    #|       i32.shr_u
    #|       local.set 3
    #|       i32.const 0
    #|       local.set 6
    #|       local.get 3
    #|       local.set 15
    #|       local.get 6
    #|       local.set 17
    #|       local.get 15
    #|       local.set 1
    #|       local.get 17
    #|     else
    #|       nop
    #|       nop
    #|       local.get 1
    #|       i32.const 536870910
    #|       i32.lt_u
    #|       if (result i32)
    #|         local.get 1
    #|         i32.const 1
    #|         i32.const 27
    #|         local.get 1
    #|         i32.clz
    #|         i32.sub
    #|         i32.shl
    #|         i32.add
    #|         i32.const 1
    #|         i32.sub
    #|       else
    #|         local.get 1
    #|       end
    #|       local.tee 4
    #|       i32.const 31
    #|       local.get 4
    #|       i32.clz
    #|       i32.sub
    #|       local.tee 2
    #|       i32.const 4
    #|       i32.sub
    #|       i32.shr_u
    #|       i32.const 16
    #|       i32.xor
    #|       local.set 5
    #|       local.get 2
    #|       i32.const 7
    #|       i32.sub
    #|       local.set 7
    #|       local.get 5
    #|       local.set 16
    #|       local.get 7
    #|       local.set 18
    #|       local.get 16
    #|       local.set 1
    #|       local.get 18
    #|     end
    #|     local.tee 2
    #|     i32.const 2
    #|     i32.shl
    #|     i32.add
    #|     i32.load offset=4 align=1
    #|     i32.const -1
    #|     local.get 1
    #|     i32.shl
    #|     i32.and
    #|     local.tee 8
    #|     if (result i32)
    #|       local.get 0
    #|       local.get 8
    #|       i32.ctz
    #|       local.get 2
    #|       i32.const 4
    #|       i32.shl
    #|       i32.add
    #|       i32.const 2
    #|       i32.shl
    #|       i32.add
    #|       i32.load offset=96 align=1
    #|       local.set 13
    #|       local.get 8
    #|       local.set 19
    #|       local.get 13
    #|       local.set 24
    #|       local.get 19
    #|       local.set 1
    #|       local.get 24
    #|     else
    #|       local.get 0
    #|       i32.load align=1
    #|       i32.const -1
    #|       local.get 2
    #|       i32.const 1
    #|       i32.add
    #|       i32.shl
    #|       i32.and
    #|       local.tee 9
    #|       if (result i32)
    #|         local.get 0
    #|         local.get 0
    #|         local.get 9
    #|         i32.ctz
    #|         local.tee 10
    #|         i32.const 2
    #|         i32.shl
    #|         i32.add
    #|         i32.load offset=4 align=1
    #|         i32.ctz
    #|         local.get 10
    #|         i32.const 4
    #|         i32.shl
    #|         i32.add
    #|         i32.const 2
    #|         i32.shl
    #|         i32.add
    #|         i32.load offset=96 align=1
    #|         local.set 11
    #|         local.get 10
    #|         local.set 20
    #|         local.get 11
    #|         local.set 22
    #|         local.get 20
    #|         local.set 1
    #|         local.get 22
    #|       else
    #|         i32.const 0
    #|         local.set 12
    #|         local.get 9
    #|         local.set 21
    #|         local.get 12
    #|         local.set 23
    #|         local.get 21
    #|         local.set 1
    #|         local.get 23
    #|       end
    #|       local.set 14
    #|       local.get 14
    #|       local.set 25
    #|       local.get 25
    #|     end))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(
    instrs[5],
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
  )
  match instrs[15] {
    @lib.If(_, then_body, Some(_)) =>
      @debug.assert_eq(
        then_body[3],
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      )
    other =>
      fail("expected outer structured if, got \{@debug.to_string(other)}")
  }
}

///|
test "coalesce-locals removes structured self-copy debris after coalescing" {
  let input =
    #| (module
    #|   (func (param i32) (result i32) (local i32 i32)
    #|     local.get 0
    #|     if
    #|       local.get 1
    #|       local.set 2
    #|     end
    #|     local.get 2))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(
    instrs[0],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
  match instrs[1] {
    @lib.If(_, then_body, None) =>
      @debug.assert_eq(then_body, [@lib.Instruction::nop()])
    other => fail("expected structured if, got \{@debug.to_string(other)}")
  }
  @debug.assert_eq(
    instrs[2],
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  )
}

///|
test "coalesce-locals coalesces structured local-tee branch slots" {
  let input =
    #| (module
    #|   (func (result i32) (local i32 i32 i32)
    #|     i32.const 1
    #|     local.tee 0
    #|     if (result i32)
    #|       i32.const 10
    #|       local.set 1
    #|       local.get 1
    #|     else
    #|       i32.const 20
    #|       local.set 2
    #|       local.get 2
    #|     end))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(@lib.I32(1)))
  @debug.assert_eq(instrs[1], @lib.Instruction::nop())
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
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
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
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(11)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(7)),
  ])
}

///|
test "coalesce-locals drops writes that only reach return" {
  // Reduced from random-all-profiles ssa-nomerge-smoke case 000007. The write
  // immediately before `return` does not flow to the post-if read, so it should
  // be treated as ineffective while preserving the produced value with `drop`.
  let input =
    #| (module
    #|   (func (param i32) (local i32)
    #|     local.get 0
    #|     if
    #|       i32.const 7
    #|       local.set 1
    #|       return
    #|     else
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1
    #|     drop))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = cl_test_first_defined_func(optimized)
  match cl_test_first_if_instr(instrs) {
    @lib.If(_, then_body, Some(_)) =>
      @debug.assert_eq(then_body[1], @lib.Instruction::drop())
    other => fail("expected if with else, got \{@debug.to_string(other)}")
  }
}

///|
test "coalesce-locals preserves writes before branch to outer block continuation" {
  // Reduced from random-all-profiles ssa-nomerge-smoke case 000007. The branch
  // skips the block tail write and flows to the post-block read, so this write
  // remains live even though the fallthrough tail writes the same local.
  let input =
    #| (module
    #|   (func (param i32) (local i32)
    #|     block
    #|       local.get 0
    #|       if
    #|         i32.const 7
    #|         local.set 1
    #|         br 1
    #|       end
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1
    #|     drop))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = cl_test_first_defined_func(optimized)
  match instrs[0] {
    @lib.Block(_, @lib.Expr(block_body)) =>
      match block_body[1] {
        @lib.If(_, then_body, _) =>
          match then_body[1] {
            @lib.LocalSet(_) => ()
            other =>
              fail(
                "expected branch-to-block-continuation write to remain local.set, got \{@debug.to_string(other)}",
              )
          }
        other => fail("expected inner if, got \{@debug.to_string(other)}")
      }
    other => fail("expected outer block, got \{@debug.to_string(other)}")
  }
}

///|
test "coalesce-locals preserves branch-carrier writes before nested block escape" {
  // Reduced from random-all-profiles ssa-nomerge-smoke case 000007. The
  // nested `block { br 1 }` skips the following tail write, so the preceding
  // branch writes are still live at the outer block exit and must not be
  // rewritten to drops by the structured ineffective-write cleanup.
  let input =
    #| (module
    #|   (func (param i32) (local i32)
    #|     block
    #|       local.get 0
    #|       if
    #|         i32.const 37
    #|         local.set 1
    #|       else
    #|         i32.const 38
    #|         local.set 1
    #|       end
    #|       block
    #|         br 1
    #|       end
    #|       i32.const 39
    #|       local.set 1
    #|     end
    #|     local.get 1
    #|     drop))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = cl_test_first_defined_func(optimized)
  match instrs[0] {
    @lib.Block(_, @lib.Expr(block_body)) =>
      match block_body[1] {
        @lib.If(_, then_body, Some(else_body)) =>
          match (then_body[1], else_body[1]) {
            (@lib.LocalSet(then_idx), @lib.LocalSet(else_idx)) =>
              @debug.assert_eq(then_idx, else_idx)
            other =>
              fail(
                "expected live branch writes to remain local.set, got \{@debug.to_string(other)}",
              )
          }
        other => fail("expected inner if, got \{@debug.to_string(other)}")
      }
    other => fail("expected outer block, got \{@debug.to_string(other)}")
  }
}

///|
test "coalesce-locals ignores dead structured writes when reusing param slots" {
  // Reduced from random-all-profiles ssa-nomerge-smoke case 000007. A dead
  // early body-local write is rewritten to `drop`, so it must not keep a later
  // effective tee of the same original local from reusing an exact-typed param
  // slot after the param value is no longer read.
  let input =
    #| (module
    #|   (func (param i32) (local i32)
    #|     i32.const 10
    #|     local.set 1
    #|     local.get 0
    #|     if
    #|       nop
    #|     end
    #|     i32.const 20
    #|     local.tee 1
    #|     i32.const 1
    #|     i32.add
    #|     drop
    #|     local.get 1
    #|     drop))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(instrs[1], @lib.Instruction::drop())
  match instrs[5] {
    @lib.LocalTee(idx) => @debug.assert_eq(idx, @lib.LocalIdx::new(0U))
    other =>
      fail(
        "expected later tee to reuse param slot, got \{@debug.to_string(other)}",
      )
  }
  @debug.assert_eq(
    instrs[9],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
}

///|
test "coalesce-locals prefers structured scalar scratch before simple early scratch" {
  // Reduced from random-all-profiles ssa-nomerge-smoke case 000007 after the
  // tail param-reuse fix. Binaryen gives the structured scalar scratch used by
  // branch conditions and local.tee the lower body slot, while an earlier simple
  // set/get scratch takes the higher slot. The branch-to-outer-block tails keep
  // the coloring tie realistic without making this a cleanup-debris assertion.
  let input =
    #| (module
    #|   (func (param i32) (local i32 i32 i32 i32 i32 f64 f32 i64)
    #|     local.get 0
    #|     drop
    #|     i32.const 101
    #|     local.set 4
    #|     local.get 4
    #|     drop
    #|     i32.const 1
    #|     if
    #|       i32.const 103
    #|       local.set 3
    #|     end
    #|     local.get 3
    #|     drop
    #|     local.get 0
    #|     if
    #|       i32.const 104
    #|       local.set 0
    #|     end
    #|     local.get 0
    #|     drop
    #|     i32.const 102
    #|     local.set 5
    #|     block
    #|       br 0
    #|     end
    #|     local.get 1
    #|     drop
    #|     i32.const 1
    #|     local.set 1
    #|     local.get 1
    #|     drop
    #|     i32.const 2
    #|     local.set 1
    #|     local.get 1
    #|     drop
    #|     i32.const 7
    #|     local.tee 1
    #|     drop
    #|     local.get 1
    #|     drop
    #|     i32.const 9
    #|     local.set 0
    #|     local.get 0
    #|     drop
    #|     i32.const 0
    #|     local.set 1
    #|     local.get 1
    #|     if
    #|       i32.const 1
    #|       local.set 1
    #|     else
    #|       i32.const 2
    #|       local.set 1
    #|     end
    #|     local.get 1
    #|     drop
    #|     local.get 1
    #|     if
    #|       i32.const 7
    #|       local.set 1
    #|     end
    #|     local.get 1
    #|     drop
    #|     local.get 0
    #|     if
    #|       i32.const 7
    #|       local.set 1
    #|       return
    #|     else
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1
    #|     drop
    #|     i32.const 0
    #|     local.set 1
    #|     block
    #|       local.get 0
    #|       if
    #|         i32.const 7
    #|         local.set 1
    #|         br 1
    #|       end
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1
    #|     drop
    #|     i32.const 7
    #|     local.set 1
    #|     block
    #|       local.get 0
    #|       br_if 0
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1
    #|     drop
    #|     local.get 0
    #|     if
    #|       nop
    #|     end
    #|     i32.const 12
    #|     local.set 1
    #|     local.get 1
    #|     drop
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 7
    #|       local.set 0
    #|       i32.const 1
    #|     else
    #|       i32.const 9
    #|       local.set 0
    #|       i32.const 2
    #|     end
    #|     drop
    #|     local.get 0
    #|     drop
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 20
    #|       local.set 2
    #|       i32.const 2
    #|     else
    #|       i32.const 30
    #|       local.set 3
    #|       i32.const 3
    #|     end
    #|     drop
    #|     block
    #|       local.get 0
    #|       if
    #|         i32.const 37
    #|         local.set 1
    #|       else
    #|         i32.const 38
    #|         local.set 1
    #|       end
    #|       block
    #|         br 1
    #|       end
    #|       i32.const 39
    #|       local.set 1
    #|     end
    #|     local.get 1
    #|     drop
    #|     block
    #|       local.get 0
    #|       if
    #|         i32.const 80
    #|         local.set 1
    #|       else
    #|         i32.const 82
    #|         local.set 1
    #|       end
    #|       block
    #|         br 1
    #|       end
    #|       i32.const 84
    #|       local.set 1
    #|     end
    #|     local.get 1
    #|     drop
    #|     i32.const 0
    #|     local.set 3
    #|     local.get 3
    #|     if
    #|       i32.const 120
    #|       local.tee 3
    #|       drop
    #|     end
    #|     local.get 3
    #|     drop))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = cl_test_first_defined_func(optimized)
  @debug.assert_eq(
    instrs[3],
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
  )
  @debug.assert_eq(
    instrs[4],
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
  )
  match instrs[7] {
    @lib.If(_, then_body, _) =>
      @debug.assert_eq(
        then_body[1],
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      )
    other => fail("expected structured write, got \{@debug.to_string(other)}")
  }
  @debug.assert_eq(
    instrs[8],
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  )
  let mut saw_tail_set = false
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.LocalSet(local_idx) =>
        if idx > 0 &&
          instrs[idx - 1] == @lib.Instruction::i32_const(@lib.I32(0)) {
          saw_tail_set = saw_tail_set || local_idx == @lib.LocalIdx::new(2U)
        }
      _ => ()
    }
  }
  assert_true(saw_tail_set, msg="expected tail zero set to use structured slot")
  assert_true(
    cl_test_instrs_contain_local_tee(instrs, @lib.LocalIdx::new(2U)),
    msg="expected tail tee to use structured slot",
  )
}

///|
test "coalesce-locals removes ineffective tee debris before immediate drop" {
  // Reduced from random-all-profiles ssa-nomerge-smoke case 000007. An
  // ineffective tee that is immediately dropped should become a direct drop;
  // leaving `nop` between the producer and drop forces the Starshine encoder to
  // introduce a scratch local, producing a direct-pass local-declaration drift.
  let input =
    #| (module
    #|   (func (local i32)
    #|     i32.const 122
    #|     local.tee 0
    #|     drop))
    #|
  let optimized = match pass_test_run_pipeline(input, ["coalesce-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(122)),
    @lib.Instruction::drop(),
  ])
}

///|

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
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([cl_test_ref_child_nullable()]),
  )
  @debug.assert_eq(
    instrs[1],
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[2],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[5],
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[6],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
}

///|
test "coalesce-locals can merge through reorder-locals cleanup" {
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
      HotPipelineOptions::new(),
      ["reorder-locals", "coalesce-locals", "reorder-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected reorder-locals/coalesce-locals/reorder-locals success, got \{err}",
      )
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = cl_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(
    instrs[1],
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  )
  @debug.assert_eq(
    instrs[3],
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[4],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[6],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[8],
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  )
  @debug.assert_eq(
    instrs[11],
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    instrs[12],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
}

///|
test "coalesce-locals drops a never-read structured write before unreachable" {
  let input =
    #| (module
    #|   (type $s (struct))
    #|   (func (result (ref null $s)) (local (ref null $s))
    #|     block
    #|       ref.null $s
    #|       local.set 0
    #|       unreachable
    #|     end
    #|     unreachable))
    #|
  let optimized = match
    run_hot_pipeline(
      pass_test_module_from_wat(input),
      HotPipelineOptions::new(),
      ["coalesce-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected structured dead-write coalescing success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = cl_test_first_defined_func(optimized)
  assert_false(cl_test_instrs_contain_local_set(instrs), msg=instrs.to_string())
  assert_true(cl_test_instrs_contain_drop(instrs), msg=instrs.to_string())
  assert_false(
    instrs.any(fn(instr) {
      match instr {
        @lib.Block(_, _) => true
        _ => false
      }
    }),
    msg=instrs.to_string(),
  )
}
