///|
fn hso_struct_fields(field_count : Int) -> Array[@lib.FieldType] {
  let fields : Array[@lib.FieldType] = []
  for _ in 0..<field_count {
    fields.push(
      @lib.FieldType::new(
        @lib.StorageType::val_type(@lib.ValType::i32()),
        @lib.Mut::var_(),
      ),
    )
  }
  fields
}

///|
fn hso_test_module_with_locals(
  field_count : Int,
  local_types : Array[@lib.ValType],
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(hso_struct_fields(field_count)),
    ),
  )
  let func_type_idx = @lib.TypeIdx::new(1U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([func_type_idx]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::from_types(local_types), @lib.Expr::new(body)),
    ]),
  )
}

///|
fn hso_test_module(
  field_count : Int,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let struct_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  hso_test_module_with_locals(field_count, [struct_ref_type], body)
}

///|
fn hso_memory_test_module(
  field_count : Int,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  hso_test_module(field_count, body).with_mem_sec(
    @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
  )
}

///|
fn hso_table_test_module(
  field_count : Int,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  hso_test_module(field_count, body).with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        @lib.TableType::new(
          @lib.RefType::abs(@lib.AbsHeapType::func()),
          @lib.Limits::i32(1U, None),
        ),
        None,
      ),
    ]),
  )
}

///|
fn hso_global_test_module(
  field_count : Int,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  hso_test_module(field_count, body).with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
      ),
    ]),
  )
}

///|
fn hso_desc_test_module(body : Array[@lib.Instruction]) -> @lib.Module {
  let descriptor_group = @lib.RecType::group([
    @lib.SubType::comp_type(
      @lib.CompType::struct_(hso_struct_fields(2)),
      metadata=@lib.TypeMetadata::new(descriptor=Some(@lib.TypeIdx::new(1U))),
    ),
    @lib.SubType::comp_type(
      @lib.CompType::struct_([]),
      metadata=@lib.TypeMetadata::new(describes=Some(@lib.TypeIdx::new(0U))),
    ),
  ])
  let pair_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let func_type_idx = @lib.TypeIdx::new(2U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([descriptor_group, func_type]))
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("desc"),
        @lib.ExternType::global(
          @lib.GlobalType::new(
            @lib.ValType::ref_type(
              @lib.RefType::new(
                true,
                @lib.HeapType::new(@lib.TypeIdx::new(1U)),
                exact=true,
              ),
            ),
            false,
          ),
        ),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([func_type_idx]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([pair_ref_type]),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
fn hso_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_test_module(field_count, body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort("unexpected invalid heap-store-optimization test fixture: \{err}")
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_test_run_with_locals(
  body : Array[@lib.Instruction],
  field_count : Int,
  local_types : Array[@lib.ValType],
) -> Result[@lib.Module, String] {
  let mod_ = hso_test_module_with_locals(field_count, local_types, body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort("unexpected invalid heap-store-optimization test fixture: \{err}")
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_memory_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_memory_test_module(field_count, body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid memory heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_table_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_table_test_module(field_count, body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid table heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_global_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_global_test_module(field_count, body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid global heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_desc_test_run(
  body : Array[@lib.Instruction],
) -> Result[@lib.Module, String] {
  let mod_ = hso_desc_test_module(body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid descriptor heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
test "heap-store-optimization folds tee-wrapped struct.set into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_tee(local0),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_false(pretty.contains("local.tee"), msg=pretty)
}

///|
test "heap-store-optimization folds consecutive struct.set roots on the same local" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(8)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
        @lib.Instruction::i32_add(),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("I32(8)"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization swaps across pure roots to reach a later struct.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds struct.new_default stores into explicit struct.new operands" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
  assert_false(pretty.contains("struct.new_default"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds struct.new_desc stores into the allocation" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_test_run([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_const(@lib.I32(4)),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::struct_new_desc(pair),
      @lib.Instruction::local_set(local0),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::i32_const(@lib.I32(9)),
      @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::struct_get(pair, @lib.U32(0U)),
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds struct.new_default_desc stores into explicit struct.new_desc operands" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_test_run([
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::struct_new_default_desc(pair),
      @lib.Instruction::local_set(local0),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::i32_const(@lib.I32(9)),
      @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::struct_get(pair, @lib.U32(0U)),
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
  assert_false(pretty.contains("struct.new_default_desc"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds pure block-wrapped struct.set values into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(9))]),
        ),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected pure-block-value heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds value branches that stay inside the moved subtree" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(8)),
          ]),
        ),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected inner-branch heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds unrelated local.get values into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let optimized = match
    hso_test_run_with_locals(
      [
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(local1),
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::local_get(local1),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
      [@lib.ValType::ref_null(@lib.HeapType::new(pair)), @lib.ValType::i32()],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected unrelated-local heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization reorders unrelated local.get field values within struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let local2 = @lib.LocalIdx::new(2U)
  let optimized = match
    hso_test_run_with_locals(
      [
        @lib.Instruction::i32_const(@lib.I32(5)),
        @lib.Instruction::local_set(local1),
        @lib.Instruction::i32_const(@lib.I32(6)),
        @lib.Instruction::local_set(local2),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::local_get(local1),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::local_get(local2),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
        @lib.Instruction::i32_add(),
      ],
      2,
      [
        @lib.ValType::ref_null(@lib.HeapType::new(pair)),
        @lib.ValType::i32(),
        @lib.ValType::i32(),
      ],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected unrelated-local reorder heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds drop-wrapped readonly local values into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let local2 = @lib.LocalIdx::new(2U)
  let optimized = match
    hso_test_run_with_locals(
      [
        @lib.Instruction::i32_const(@lib.I32(5)),
        @lib.Instruction::local_set(local1),
        @lib.Instruction::i32_const(@lib.I32(6)),
        @lib.Instruction::local_set(local2),
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::local_get(local1),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(local2),
          ]),
        ),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
      [
        @lib.ValType::ref_null(@lib.HeapType::new(pair)),
        @lib.ValType::i32(),
        @lib.ValType::i32(),
      ],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected drop-wrapped readonly heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds memory.size values into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected memory.size heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds table.size values into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected table.size heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization swaps across unrelated local.set roots" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let optimized = match
    hso_test_run_with_locals(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(local1),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
      [@lib.ValType::ref_null(@lib.HeapType::new(pair)), @lib.ValType::i32()],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected unrelated-local-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization swaps across unrelated global.set roots" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_global_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected unrelated-global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps folded nops after the rewritten local.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_global_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nop-order heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(local.set (Local 0))nop"), msg=pretty)
  assert_false(pretty.contains("nop(local.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization peels readonly block prefixes out of folded values" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_global_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(7)),
          ]),
        ),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected readonly-prefix peel heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("block"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization swaps across drop(memory.size) roots" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size-root heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization swaps across drop(table.size) roots" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size-root heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization swaps across block-wrapped unrelated local.set roots" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let optimized = match
    hso_test_run_with_locals(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::local_set(local1),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
      [@lib.ValType::ref_null(@lib.HeapType::new(pair)), @lib.ValType::i32()],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected block-local-set-root heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("block"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization swaps across block-wrapped readonly roots" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected block-readonly-root heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps branching struct.set values when the target local is read later" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::struct_new_default(pair),
            @lib.Instruction::local_set(local0),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32(9)),
              ]),
            ),
            @lib.Instruction::struct_set(pair, @lib.U32(0U)),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::ref_is_null(),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected later-read branching heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set when the moved value reads the target local inside a nested block" {
  let box = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::struct_new(box),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::local_get(local0),
            @lib.Instruction::struct_get(box, @lib.U32(0U)),
          ]),
        ),
        @lib.Instruction::struct_set(box, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(box, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested-block local-read heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set when the moved value reads the target local" {
  let box = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::struct_new(box),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(box, @lib.U32(0U)),
        @lib.Instruction::struct_set(box, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(box, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.set"), msg=pretty)
}
