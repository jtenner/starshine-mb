///|
fn heap2local_pair_fields(field_count : Int) -> Array[@lib.FieldType] {
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
fn heap2local_module_with_locals(
  result_types : Array[@lib.ValType],
  local_types : Array[@lib.ValType],
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::struct_(heap2local_pair_fields(2))),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], result_types)),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::from_types(local_types), @lib.Expr::new(body)),
    ]),
  )
}

///|
fn heap2local_run_module(mod_ : @lib.Module) -> @lib.Module {
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) => abort("unexpected invalid heap2local fixture: \{err}")
  }
  match run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap2local"]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected heap2local pipeline success, got \{err}")
  }
}

///|
test "heap2local rewrites a non-escaping struct local into scalar locals" {
  let pair = @lib.TypeIdx::new(0U)
  let owner_local = @lib.LocalIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_locals(
      [@lib.ValType::i32()],
      [@lib.ValType::ref_null(@lib.HeapType::new(pair))],
      [
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::i32_const(@lib.I32(20)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(owner_local),
        @lib.Instruction::local_get(owner_local),
        @lib.Instruction::i32_const(@lib.I32(30)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(owner_local),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
    ),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected heap2local output to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
}

///|
test "heap2local leaves escaping struct locals unchanged" {
  let pair = @lib.TypeIdx::new(0U)
  let owner_local = @lib.LocalIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_locals(
      [@lib.ValType::ref_null(@lib.HeapType::new(pair))],
      [@lib.ValType::ref_null(@lib.HeapType::new(pair))],
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::i32_const(@lib.I32(8)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(owner_local),
        @lib.Instruction::local_get(owner_local),
      ],
    ),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected heap2local escape fixture to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
}
