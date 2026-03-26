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
fn hso_test_module(
  field_count : Int,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let struct_type_idx = @lib.TypeIdx::new(0U)
  let struct_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(struct_type_idx),
  )
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
      @lib.Func::new(
        @lib.Locals::from_types([struct_ref_type]),
        @lib.Expr::new(body),
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
