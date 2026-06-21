///|
using @binary {trait Decode}

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
fn hso_decode_fixture_module(bytes : Bytes) -> @lib.Module {
  match Decode::decode(bytes, 0) {
    Ok((mod_, idx)) => {
      if idx != bytes.length() {
        abort(
          "unexpected trailing bytes while decoding HSO fixture: decoded \{idx}, total \{bytes.length()}",
        )
      }
      mod_
    }
    Err(err) => abort("unexpected HSO fixture decode failure: \{err}")
  }
}

///|
fn hso_bytes_from_ints(values : Array[Int]) -> Bytes {
  let out = @buffer.new(size_hint=values.length())
  for value in values {
    out.write_byte(value.to_byte())
  }
  out.to_bytes()
}

///|
fn hso_test_index_of(text : String, needle : String) -> Int? {
  if needle.length() == 0 || needle.length() > text.length() {
    return None
  }
  let limit = text.length() - needle.length()
  let mut idx = 0
  while idx <= limit {
    if text.sub(start=idx, end=idx + needle.length()).to_owned() == needle {
      return Some(idx)
    }
    idx = idx + 1
  }
  None
}

///|
fn hso_test_count_occurrences(text : String, needle : String) -> Int {
  if needle.length() == 0 || needle.length() > text.length() {
    return 0
  }
  let limit = text.length() - needle.length()
  let mut idx = 0
  let mut count = 0
  while idx <= limit {
    if text.sub(start=idx, end=idx + needle.length()).to_owned() == needle {
      count = count + 1
      idx = idx + needle.length()
    } else {
      idx = idx + 1
    }
  }
  count
}

///|
fn hso_test_block_wrap(
  body : Array[@lib.Instruction],
) -> Array[@lib.Instruction] {
  [@lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(body))]
}

///|
fn hso_test_if_wrap(body : Array[@lib.Instruction]) -> Array[@lib.Instruction] {
  [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(@lib.BlockType::void_(), body, None),
  ]
}

///|
fn hso_test_loop_wrap(
  body : Array[@lib.Instruction],
) -> Array[@lib.Instruction] {
  [@lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(body))]
}

///|
fn hso_test_branch_containing_wraps(
  body : Array[@lib.Instruction],
) -> Array[Array[@lib.Instruction]] {
  [
    hso_test_block_wrap([..body, @lib.Instruction::br(@lib.LabelIdx::new(0U))]),
    hso_test_block_wrap([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [..body, @lib.Instruction::br(@lib.LabelIdx::new(1U))],
        None,
      ),
    ]),
    hso_test_block_wrap([
      @lib.Instruction::loop_(
        @lib.BlockType::void_(),
        @lib.Expr::new([..body, @lib.Instruction::br(@lib.LabelIdx::new(1U))]),
      ),
    ]),
  ]
}

///|
fn hso_test_memory_init_body() -> Array[@lib.Instruction] {
  [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::memory_init(@lib.DataIdx::new(0U), @lib.MemIdx::new(0U)),
  ]
}

///|
fn hso_test_data_drop_body() -> Array[@lib.Instruction] {
  [@lib.Instruction::data_drop(@lib.DataIdx::new(0U))]
}

///|
fn hso_test_memory_fill_body() -> Array[@lib.Instruction] {
  [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::memory_fill(@lib.MemIdx::new(0U)),
  ]
}

///|
fn hso_test_memory_copy_body() -> Array[@lib.Instruction] {
  [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::memory_copy(@lib.MemIdx::new(0U), @lib.MemIdx::new(0U)),
  ]
}

///|
fn hso_test_table_init_body() -> Array[@lib.Instruction] {
  [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::table_init(@lib.ElemIdx::new(0U), @lib.TableIdx::new(0U)),
  ]
}

///|
fn hso_test_elem_drop_body() -> Array[@lib.Instruction] {
  [@lib.Instruction::elem_drop(@lib.ElemIdx::new(0U))]
}

///|
fn hso_test_table_fill_body() -> Array[@lib.Instruction] {
  [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::table_fill(@lib.TableIdx::new(0U)),
  ]
}

///|
fn hso_test_table_copy_body() -> Array[@lib.Instruction] {
  [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::table_copy(@lib.TableIdx::new(0U), @lib.TableIdx::new(0U)),
  ]
}

///|
fn hso_assert_memory_size_wrapped_passive_boundary(
  roots : Array[@lib.Instruction],
  marker : String,
  label : String,
) -> Unit raise {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::struct_new(pair),
    @lib.Instruction::local_set(local0),
  ]
  for root in roots {
    body.push(root)
  }
  body.push(@lib.Instruction::local_get(local0))
  body.push(@lib.Instruction::i32_const(@lib.I32(7)))
  body.push(@lib.Instruction::struct_set(pair, @lib.U32(1U)))
  body.push(@lib.Instruction::local_get(local0))
  body.push(@lib.Instruction::struct_get(pair, @lib.U32(1U)))
  let optimized = match hso_memory_data_test_run(body, 2) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected \{label} heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains(marker), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
fn hso_assert_table_size_wrapped_passive_boundary(
  roots : Array[@lib.Instruction],
  marker : String,
  label : String,
) -> Unit raise {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::struct_new(pair),
    @lib.Instruction::local_set(local0),
  ]
  for root in roots {
    body.push(root)
  }
  body.push(@lib.Instruction::local_get(local0))
  body.push(@lib.Instruction::i32_const(@lib.I32(7)))
  body.push(@lib.Instruction::struct_set(pair, @lib.U32(1U)))
  body.push(@lib.Instruction::local_get(local0))
  body.push(@lib.Instruction::struct_get(pair, @lib.U32(1U)))
  let optimized = match hso_table_elem_test_run(body, 2) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected \{label} heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains(marker), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
fn hso_assert_memory_grow_wrapped_passive_boundary(
  roots : Array[@lib.Instruction],
  marker : String,
  label : String,
) -> Unit raise {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::memory_grow(@lib.MemIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::struct_new(pair),
    @lib.Instruction::local_set(local0),
  ]
  for root in roots {
    body.push(root)
  }
  body.push(@lib.Instruction::local_get(local0))
  body.push(@lib.Instruction::i32_const(@lib.I32(7)))
  body.push(@lib.Instruction::struct_set(pair, @lib.U32(1U)))
  body.push(@lib.Instruction::local_get(local0))
  body.push(@lib.Instruction::struct_get(pair, @lib.U32(1U)))
  let optimized = match hso_memory_data_test_run(body, 2) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected \{label} heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains(marker), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
fn hso_assert_table_grow_wrapped_passive_boundary(
  roots : Array[@lib.Instruction],
  marker : String,
  label : String,
) -> Unit raise {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::table_grow(@lib.TableIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::struct_new(pair),
    @lib.Instruction::local_set(local0),
  ]
  for root in roots {
    body.push(root)
  }
  body.push(@lib.Instruction::local_get(local0))
  body.push(@lib.Instruction::i32_const(@lib.I32(7)))
  body.push(@lib.Instruction::struct_set(pair, @lib.U32(1U)))
  body.push(@lib.Instruction::local_get(local0))
  body.push(@lib.Instruction::struct_get(pair, @lib.U32(1U)))
  let optimized = match hso_table_elem_test_run(body, 2) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected \{label} heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains(marker), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
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
fn hso_i32_array_type() -> @lib.RecType {
  @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
}

///|
fn hso_array_test_module(body : Array[@lib.Instruction]) -> @lib.Module {
  let array_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let func_type_idx = @lib.TypeIdx::new(1U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([hso_i32_array_type(), func_type]))
  .with_func_sec(@lib.FuncSec::new([func_type_idx]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([array_ref_type]),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
fn hso_ref_result_test_module(
  field_count : Int,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let struct_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(hso_struct_fields(field_count)),
    ),
  )
  let func_type_idx = @lib.TypeIdx::new(1U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [struct_ref_type])),
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
fn hso_memory_test_module(
  field_count : Int,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  hso_test_module(field_count, body).with_mem_sec(
    @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
  )
}

///|
fn hso_two_memory_test_module(
  field_count : Int,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  hso_test_module(field_count, body).with_mem_sec(
    @lib.MemSec::new([
      @lib.MemType::new(@lib.Limits::i32(1U, None)),
      @lib.MemType::new(@lib.Limits::i32(1U, None)),
    ]),
  )
}

///|
fn hso_memory_table_test_module(
  field_count : Int,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  hso_memory_test_module(field_count, body).with_table_sec(
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
fn hso_memory_global_test_module(
  field_count : Int,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  hso_memory_test_module(field_count, body).with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
      ),
    ]),
  )
}

///|
fn hso_memory_ref_result_test_module(
  field_count : Int,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  hso_ref_result_test_module(field_count, body).with_mem_sec(
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
fn hso_two_table_test_module(
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
fn hso_table_global_test_module(
  field_count : Int,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  hso_table_test_module(field_count, body).with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
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
fn hso_two_global_test_module(
  field_count : Int,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  hso_test_module(field_count, body).with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
      ),
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
      ),
    ]),
  )
}

///|
fn hso_immutable_global_test_module(
  field_count : Int,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  hso_test_module(field_count, body).with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), false),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
      ),
    ]),
  )
}

///|
fn hso_call_test_module(
  field_count : Int,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let struct_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(hso_struct_fields(field_count)),
    ),
  )
  let helper_type_idx = @lib.TypeIdx::new(1U)
  let helper_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let func_type_idx = @lib.TypeIdx::new(2U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, helper_type, func_type]))
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("helper"),
        @lib.ExternType::func(helper_type_idx),
      ),
    ]),
  )
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
fn hso_call_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_call_test_module(field_count, body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid call heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_call_catch_test_module(
  field_count : Int,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let struct_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(hso_struct_fields(field_count)),
    ),
  )
  let helper_type_idx = @lib.TypeIdx::new(1U)
  let helper_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let tag_type_idx = @lib.TypeIdx::new(2U)
  let tag_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let func_type_idx = @lib.TypeIdx::new(3U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([struct_type, helper_type, tag_type, func_type]),
  )
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("helper"),
        @lib.ExternType::func(helper_type_idx),
      ),
    ]),
  )
  .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(tag_type_idx)]))
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
fn hso_call_catch_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_call_catch_test_module(field_count, body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid call/catch heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
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
fn hso_array_test_run(
  body : Array[@lib.Instruction],
) -> Result[@lib.Module, String] {
  let mod_ = hso_array_test_module(body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid array heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_ref_result_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_ref_result_test_module(field_count, body)
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
fn hso_two_memory_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_two_memory_test_module(field_count, body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid two-memory heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_memory_table_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_memory_table_test_module(field_count, body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid memory+table heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_memory_data_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_memory_test_module(field_count, body)
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32::new(1U)))
    .with_data_sec(
      @lib.DataSec::new([@lib.Data::new(@lib.DataMode::passive(), b"abcd")]),
    )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid memory+data heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_memory_test_run_with_locals(
  body : Array[@lib.Instruction],
  field_count : Int,
  local_types : Array[@lib.ValType],
) -> Result[@lib.Module, String] {
  let mod_ = hso_test_module_with_locals(field_count, local_types, body).with_mem_sec(
    @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
  )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid memory+locals heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_memory_global_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_memory_global_test_module(field_count, body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid memory+global heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_test_run_module(mod_ : @lib.Module) -> Result[@lib.Module, String] {
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort("unexpected invalid heap-store-optimization module fixture: \{err}")
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_memory_ref_result_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_memory_ref_result_test_module(field_count, body)
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
fn hso_two_table_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_two_table_test_module(field_count, body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid two-table heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_table_elem_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_table_test_module(field_count, body).with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::passive(),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
      ),
    ]),
  )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid table+elem heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_table_global_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_table_global_test_module(field_count, body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid table+global heap-store-optimization test fixture: \{err}",
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
fn hso_two_global_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_two_global_test_module(field_count, body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid two-global heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_immutable_global_test_run(
  body : Array[@lib.Instruction],
  field_count : Int,
) -> Result[@lib.Module, String] {
  let mod_ = hso_immutable_global_test_module(field_count, body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid immutable-global heap-store-optimization test fixture: \{err}",
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
fn hso_desc_i32_global_test_module(
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let descriptor_group = @lib.RecType::group([
    @lib.SubType::comp_type(
      @lib.CompType::struct_(hso_struct_fields(1)),
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
                false,
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
  .with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
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
fn hso_desc_i32_global_test_run(
  body : Array[@lib.Instruction],
) -> Result[@lib.Module, String] {
  let mod_ = hso_desc_i32_global_test_module(body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid descriptor+i32-global heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_desc_two_i32_global_test_module(
  body : Array[@lib.Instruction],
) -> @lib.Module {
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
  .with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
      ),
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
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
fn hso_desc_two_i32_global_test_run(
  body : Array[@lib.Instruction],
) -> Result[@lib.Module, String] {
  let mod_ = hso_desc_two_i32_global_test_module(body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid descriptor+two-i32-global heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_exact_desc_ref_type(nullable : Bool) -> @lib.ValType {
  @lib.ValType::ref_type(
    @lib.RefType::new(
      nullable,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
}

///|
fn hso_desc_call_test_module(
  body : Array[@lib.Instruction],
  mutable_desc : Bool,
) -> @lib.Module {
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
  let helper_type_idx = @lib.TypeIdx::new(2U)
  let helper_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let func_type_idx = @lib.TypeIdx::new(3U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let pair_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([descriptor_group, helper_type, func_type]))
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("desc"),
        @lib.ExternType::global(
          @lib.GlobalType::new(hso_exact_desc_ref_type(false), mutable_desc),
        ),
      ),
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("helper"),
        @lib.ExternType::func(helper_type_idx),
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
fn hso_desc_call_test_run(
  body : Array[@lib.Instruction],
  mutable_desc : Bool,
) -> Result[@lib.Module, String] {
  let mod_ = hso_desc_call_test_module(body, mutable_desc)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid descriptor-call heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_desc_memory_call_test_run(
  body : Array[@lib.Instruction],
  mutable_desc : Bool,
) -> Result[@lib.Module, String] {
  let mod_ = hso_desc_call_test_module(body, mutable_desc).with_mem_sec(
    @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
  )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid descriptor-memory-call heap-store-optimization test fixture: \{err}",
      )
  }
  run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap-store-optimization"])
}

///|
fn hso_desc_local_call_test_module(
  body : Array[@lib.Instruction],
) -> @lib.Module {
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
  let helper_type_idx = @lib.TypeIdx::new(2U)
  let helper_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let func_type_idx = @lib.TypeIdx::new(3U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let pair_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([descriptor_group, helper_type, func_type]))
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("desc"),
        @lib.ExternType::global(
          @lib.GlobalType::new(hso_exact_desc_ref_type(true), false),
        ),
      ),
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("helper"),
        @lib.ExternType::func(helper_type_idx),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([func_type_idx]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([pair_ref_type, hso_exact_desc_ref_type(true)]),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
fn hso_desc_local_call_test_run(
  body : Array[@lib.Instruction],
) -> Result[@lib.Module, String] {
  let mod_ = hso_desc_local_call_test_module(body)
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort(
        "unexpected invalid descriptor-local-call heap-store-optimization test fixture: \{err}",
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
test "heap-store-optimization folds tee plus later local-get struct.set chain" {
  let triple = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::i32_const(@lib.I32(20)),
        @lib.Instruction::i32_const(@lib.I32(30)),
        @lib.Instruction::struct_new(triple),
        @lib.Instruction::local_tee(local0),
        @lib.Instruction::i32_const(@lib.I32(40)),
        @lib.Instruction::struct_set(triple, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(50)),
        @lib.Instruction::struct_set(triple, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(60)),
        @lib.Instruction::struct_set(triple, @lib.U32(2U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(triple, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(triple, @lib.U32(1U)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(triple, @lib.U32(2U)),
        @lib.Instruction::i32_add(),
      ],
      3,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected tee-plus-later-chain heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(40)"), msg=pretty)
  assert_true(pretty.contains("I32(50)"), msg=pretty)
  assert_true(pretty.contains("I32(60)"), msg=pretty)
  assert_false(pretty.contains("I32(10)"), msg=pretty)
  assert_false(pretty.contains("I32(20)"), msg=pretty)
  assert_false(pretty.contains("I32(30)"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_false(pretty.contains("local.tee"), msg=pretty)
}

///|
test "heap-store-optimization folds Binaryen many-fields tee roots independently" {
  let triple = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::i32_const(@lib.I32(20)),
        @lib.Instruction::i32_const(@lib.I32(30)),
        @lib.Instruction::struct_new(triple),
        @lib.Instruction::local_tee(local0),
        @lib.Instruction::i32_const(@lib.I32(40)),
        @lib.Instruction::struct_set(triple, @lib.U32(0U)),
        @lib.Instruction::i32_const(@lib.I32(100)),
        @lib.Instruction::i32_const(@lib.I32(200)),
        @lib.Instruction::i32_const(@lib.I32(300)),
        @lib.Instruction::struct_new(triple),
        @lib.Instruction::local_tee(local0),
        @lib.Instruction::i32_const(@lib.I32(600)),
        @lib.Instruction::struct_set(triple, @lib.U32(2U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(triple, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(triple, @lib.U32(2U)),
        @lib.Instruction::i32_add(),
      ],
      3,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected many-fields heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(40)"), msg=pretty)
  assert_true(pretty.contains("I32(600)"), msg=pretty)
  assert_false(pretty.contains("I32(10)"), msg=pretty)
  assert_false(pretty.contains("I32(300)"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_false(pretty.contains("local.tee"), msg=pretty)
}

///|
test "heap-store-optimization folds Binaryen many-news independent chains" {
  let triple = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(triple))
  let optimized = match
    hso_test_run_with_locals(
      [
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::i32_const(@lib.I32(20)),
        @lib.Instruction::i32_const(@lib.I32(30)),
        @lib.Instruction::struct_new(triple),
        @lib.Instruction::local_tee(local0),
        @lib.Instruction::i32_const(@lib.I32(40)),
        @lib.Instruction::struct_set(triple, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(50)),
        @lib.Instruction::struct_set(triple, @lib.U32(1U)),
        @lib.Instruction::nop(),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(60)),
        @lib.Instruction::struct_set(triple, @lib.U32(2U)),
        @lib.Instruction::nop(),
        @lib.Instruction::i32_const(@lib.I32(100)),
        @lib.Instruction::i32_const(@lib.I32(200)),
        @lib.Instruction::i32_const(@lib.I32(300)),
        @lib.Instruction::struct_new(triple),
        @lib.Instruction::local_tee(local0),
        @lib.Instruction::i32_const(@lib.I32(400)),
        @lib.Instruction::struct_set(triple, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(500)),
        @lib.Instruction::struct_set(triple, @lib.U32(2U)),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(10)),
            @lib.Instruction::i32_const(@lib.I32(20)),
            @lib.Instruction::i32_const(@lib.I32(30)),
            @lib.Instruction::struct_new(triple),
            @lib.Instruction::local_tee(local0),
            @lib.Instruction::i32_const(@lib.I32(40)),
            @lib.Instruction::struct_set(triple, @lib.U32(0U)),
            @lib.Instruction::i32_const(@lib.I32(100)),
            @lib.Instruction::i32_const(@lib.I32(200)),
            @lib.Instruction::i32_const(@lib.I32(300)),
            @lib.Instruction::struct_new(triple),
            @lib.Instruction::local_tee(local1),
            @lib.Instruction::i32_const(@lib.I32(400)),
            @lib.Instruction::struct_set(triple, @lib.U32(0U)),
            @lib.Instruction::local_get(local1),
            @lib.Instruction::i32_const(@lib.I32(500)),
            @lib.Instruction::struct_set(triple, @lib.U32(2U)),
            @lib.Instruction::local_get(local1),
            @lib.Instruction::i32_const(@lib.I32(600)),
            @lib.Instruction::struct_set(triple, @lib.U32(1U)),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(triple, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(triple, @lib.U32(2U)),
        @lib.Instruction::i32_add(),
      ],
      3,
      [ref_type, ref_type],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected many-news heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(40)"), msg=pretty)
  assert_true(pretty.contains("I32(50)"), msg=pretty)
  assert_true(pretty.contains("I32(60)"), msg=pretty)
  assert_true(pretty.contains("I32(400)"), msg=pretty)
  assert_true(pretty.contains("I32(500)"), msg=pretty)
  assert_true(pretty.contains("I32(600)"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_false(pretty.contains("local.tee"), msg=pretty)
}

///|
test "heap-store-optimization keeps Binaryen pattern-breaker local copy chains" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  let optimized = match
    hso_test_run_with_locals(
      [
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::local_set(local1),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(20)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
      [ref_type, ref_type],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected pattern-breaker heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("I32(20)"), msg=pretty)
}

///|
test "heap-store-optimization folds repeated stores with the last value in the constructor" {
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
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected repeated-store heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(8)"), msg=pretty)
  assert_false(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set for a different target local" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  let optimized = match
    hso_test_run_with_locals(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local1),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      2,
      [ref_type, ref_type],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected wrong-local heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "heap-store-optimization leaves array stores as an explicit non-goal" {
  let array = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_array_test_run([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::array_new_default(array),
      @lib.Instruction::local_set(local0),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::array_set(array),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::array_get(array),
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected array non-goal heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("array.new_default"), msg=pretty)
  assert_true(pretty.contains("array.set"), msg=pretty)
  assert_true(pretty.contains("array.get"), msg=pretty)
}

///|
test "heap-store-optimization does not do generic struct dead-store elimination" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let pair_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let optimized = match
    hso_test_run_with_locals(
      [
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
      ],
      1,
      [pair_ref_type],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected generic dead-store non-goal heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_eq(hso_test_count_occurrences(pretty, "struct.set"), 2, msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(2)"), msg=pretty)
}

///|
test "heap-store-optimization does not do generic struct load forwarding" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let pair_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let optimized = match
    hso_test_run_with_locals(
      [
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
      [pair_ref_type],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected generic load-forwarding non-goal heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("struct.get"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "heap-store-optimization leaves unreachable constructors to later DCE" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::unreachable_(),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected unreachable-new heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("I32(10)"), msg=pretty)
}

///|
test "heap-store-optimization leaves unreachable set values to later DCE" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(20)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        ),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected unreachable-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("I32(20)"), msg=pretty)
}

///|
test "heap-store-optimization folds through ordinary memory stores" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(99)),
        @lib.Instruction::i32_store(@lib.MemArg::new(0U, None, 0UL)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected memory-store heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds through ordinary table stores" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        @lib.Instruction::table_set(@lib.TableIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected table-store heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds memory.size constructors across table stores" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_table_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        @lib.Instruction::table_set(@lib.TableIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory.size/table-store heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds memory.size constructors across br_table-wrapped table stores" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_table_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Instruction::table_set(@lib.TableIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::br_table(
              [@lib.LabelIdx::new(0U)],
              @lib.LabelIdx::new(0U),
            ),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory.size/br_table-table-store heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_true(pretty.contains("br_table"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds table.size constructors across memory stores" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_table_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(99)),
        @lib.Instruction::i32_store(@lib.MemArg::new(0U, None, 0UL)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table.size/memory-store heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds table.size constructors across br_table-wrapped memory stores" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_table_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(99)),
            @lib.Instruction::i32_store(@lib.MemArg::new(0U, None, 0UL)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::br_table(
              [@lib.LabelIdx::new(0U)],
              @lib.LabelIdx::new(0U),
            ),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table.size/br_table-memory-store heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_true(pretty.contains("br_table"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table-growing constructors before br_table-wrapped memory stores" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_table_test_run(
      [
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_grow(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(99)),
            @lib.Instruction::i32_store(@lib.MemArg::new(0U, None, 0UL)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::br_table(
              [@lib.LabelIdx::new(0U)],
              @lib.LabelIdx::new(0U),
            ),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table.grow/br_table-memory-store heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_true(pretty.contains("br_table"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
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
test "heap-store-optimization folds default descriptor chain stores and preserves moved call" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::struct_new_default_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected default-desc old-field heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("struct.new_default_desc"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds store across mutable descriptor global when moved value is pure" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      true,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected mutable descriptor pure-value heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps descriptor store when mutable descriptor global orders before moved call" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      true,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected mutable descriptor call barrier heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps descriptor struct.set when later field call orders before moved call" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected descriptor later-field-call barrier heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
}

///|
test "heap-store-optimization folds descriptor store despite later field target-local read" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::local_get(local0),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(2)),
          ]),
        ),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected descriptor later-field target-local read heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds descriptor store across unrelated later-field global read" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_two_i32_global_test_run([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::struct_new_desc(pair),
      @lib.Instruction::local_set(local0),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::global_set(@lib.GlobalIdx::new(2U)),
          @lib.Instruction::i32_const(@lib.I32(9)),
        ]),
      ),
      @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::struct_get(pair, @lib.U32(0U)),
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected descriptor unrelated later-field global-read heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps descriptor store before same later-field global read" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_two_i32_global_test_run([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::struct_new_desc(pair),
      @lib.Instruction::local_set(local0),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::global_set(@lib.GlobalIdx::new(1U)),
          @lib.Instruction::i32_const(@lib.I32(9)),
        ]),
      ),
      @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::struct_get(pair, @lib.U32(0U)),
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected descriptor same later-field global-read heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds descriptor store across unrelated later-field global write" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_two_i32_global_test_run([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::global_set(@lib.GlobalIdx::new(1U)),
          @lib.Instruction::i32_const(@lib.I32(3)),
        ]),
      ),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::struct_new_desc(pair),
      @lib.Instruction::local_set(local0),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(2U)),
      @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::struct_get(pair, @lib.U32(0U)),
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected descriptor unrelated later-field global-write/read heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps descriptor store before same later-field global write and read" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_two_i32_global_test_run([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::global_set(@lib.GlobalIdx::new(1U)),
          @lib.Instruction::i32_const(@lib.I32(3)),
        ]),
      ),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::struct_new_desc(pair),
      @lib.Instruction::local_set(local0),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
      @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::struct_get(pair, @lib.U32(0U)),
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected descriptor same later-field global-write/read heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds descriptor store across unrelated later-field and moved global writes" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_two_i32_global_test_run([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::global_set(@lib.GlobalIdx::new(1U)),
          @lib.Instruction::i32_const(@lib.I32(3)),
        ]),
      ),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::struct_new_desc(pair),
      @lib.Instruction::local_set(local0),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(9)),
          @lib.Instruction::global_set(@lib.GlobalIdx::new(2U)),
          @lib.Instruction::i32_const(@lib.I32(11)),
        ]),
      ),
      @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::struct_get(pair, @lib.U32(0U)),
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected descriptor unrelated later-field and moved global writes heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps descriptor store before same later-field and moved global writes" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_two_i32_global_test_run([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::global_set(@lib.GlobalIdx::new(1U)),
          @lib.Instruction::i32_const(@lib.I32(3)),
        ]),
      ),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::struct_new_desc(pair),
      @lib.Instruction::local_set(local0),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(9)),
          @lib.Instruction::global_set(@lib.GlobalIdx::new(1U)),
          @lib.Instruction::i32_const(@lib.I32(11)),
        ]),
      ),
      @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::struct_get(pair, @lib.U32(0U)),
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected descriptor same later-field and moved global writes heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps descriptor store when moved value reads target local" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_test_run([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_const(@lib.I32(2)),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::struct_new_desc(pair),
      @lib.Instruction::local_set(local0),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::local_get(local0),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(9)),
        ]),
      ),
      @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::struct_get(pair, @lib.U32(0U)),
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected descriptor target-local-read heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "heap-store-optimization keeps descriptor store when moved value writes target local" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_test_run([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_const(@lib.I32(2)),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::struct_new_desc(pair),
      @lib.Instruction::local_set(local0),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::i32_const(@lib.I32(8)),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::struct_new_desc(pair),
          @lib.Instruction::local_set(local0),
          @lib.Instruction::i32_const(@lib.I32(9)),
        ]),
      ),
      @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::struct_get(pair, @lib.U32(0U)),
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected descriptor target-local-write heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "heap-store-optimization moves call value before immutable descriptor global" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected immutable-descriptor-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set before mutable descriptor global and moved call" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      true,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected mutable-descriptor-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
}

///|
test "heap-store-optimization moves call value before block-wrapped immutable descriptor global" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::block(
          @lib.BlockType::val_type(hso_exact_desc_ref_type(false)),
          @lib.Expr::new([@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))]),
        ),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected block-descriptor-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization moves call value before block-branch immutable descriptor global" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::block(
          @lib.BlockType::val_type(hso_exact_desc_ref_type(false)),
          @lib.Expr::new([
            @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
            @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected block-branch-descriptor-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization moves call value before loop-wrapped immutable descriptor global" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::loop_(
          @lib.BlockType::val_type(hso_exact_desc_ref_type(false)),
          @lib.Expr::new([@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))]),
        ),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected loop-descriptor-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("loop"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization moves call before descriptor loop branch to outer block" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::block(
          @lib.BlockType::val_type(hso_exact_desc_ref_type(false)),
          @lib.Expr::new([
            @lib.Instruction::loop_(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected outer-branch loop descriptor-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("loop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set when descriptor loop branches to itself" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::loop_(
          @lib.BlockType::val_type(hso_exact_desc_ref_type(false)),
          @lib.Expr::new([
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
            @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected self-branching loop descriptor-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("loop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization moves call value before descriptor local.get" {
  let pair = @lib.TypeIdx::new(0U)
  let ref_local = @lib.LocalIdx::new(0U)
  let desc_local = @lib.LocalIdx::new(1U)
  let optimized = match
    hso_desc_local_call_test_run([
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::local_set(desc_local),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_const(@lib.I32(10)),
      @lib.Instruction::local_get(desc_local),
      @lib.Instruction::struct_new_desc(pair),
      @lib.Instruction::local_set(ref_local),
      @lib.Instruction::local_get(ref_local),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::struct_set(pair, @lib.U32(0U)),
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected local descriptor-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization moves call value before if-wrapped immutable descriptor globals" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::val_type(hso_exact_desc_ref_type(false)),
          [@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))],
          Some([@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))]),
        ),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected if-descriptor-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization moves call value before select-wrapped immutable descriptor globals" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::select(types=Some([hso_exact_desc_ref_type(false)])),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected select-descriptor-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set when descriptor select condition calls" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(99)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::select(types=Some([hso_exact_desc_ref_type(false)])),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected select-condition-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set when descriptor select condition may trap" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_memory_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(
          @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(0UL)),
        ),
        @lib.Instruction::select(types=Some([hso_exact_desc_ref_type(false)])),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected descriptor-select-trap heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set when later field select condition calls" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::i32_const(@lib.I32(3)),
        @lib.Instruction::i32_const(@lib.I32(99)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::select(types=Some([@lib.ValType::i32()])),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected later-field-select-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set when later field select condition may trap" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_memory_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::i32_const(@lib.I32(3)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(
          @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(0UL)),
        ),
        @lib.Instruction::select(types=Some([@lib.ValType::i32()])),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected later-field-select-trap heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set when later field if condition calls" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(99)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::if_(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          [@lib.Instruction::i32_const(@lib.I32(2))],
          Some([@lib.Instruction::i32_const(@lib.I32(3))]),
        ),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected later-field-if-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set when later field if condition may trap" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_memory_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(
          @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(0UL)),
        ),
        @lib.Instruction::if_(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          [@lib.Instruction::i32_const(@lib.I32(2))],
          Some([@lib.Instruction::i32_const(@lib.I32(3))]),
        ),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected later-field-if-trap heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set when later field block br_if condition calls" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::i32_const(@lib.I32(99)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(3)),
          ]),
        ),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected later-field-block-br-if-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("block"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
}

///|
test "heap-store-optimization folds through later field block br_if with pure condition" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(3)),
          ]),
        ),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected later-field-block-br-if-pure-condition heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("block"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds through descriptor block br_if with pure condition" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::block(
          @lib.BlockType::val_type(hso_exact_desc_ref_type(false)),
          @lib.Expr::new([
            @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected descriptor-block-br-if-pure-condition heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("block"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set when descriptor block br_if condition calls" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::block(
          @lib.BlockType::val_type(hso_exact_desc_ref_type(false)),
          @lib.Expr::new([
            @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(99)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected descriptor-block-br-if-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("block"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
}

///|
test "heap-store-optimization keeps descriptor store when descriptor ref.as_non_null may trap" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_local_call_test_run([
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_const(@lib.I32(10)),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::ref_as_non_null(),
      @lib.Instruction::struct_new_desc(pair),
      @lib.Instruction::local_set(local0),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::struct_set(pair, @lib.U32(0U)),
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref.as_non_null descriptor heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("ref.as_non_null"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set when descriptor if condition calls" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::i32_const(@lib.I32(99)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::if_(
          @lib.BlockType::val_type(hso_exact_desc_ref_type(false)),
          [@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))],
          Some([@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))]),
        ),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected if-condition-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set when descriptor if condition may trap" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_memory_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(
          @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(0UL)),
        ),
        @lib.Instruction::if_(
          @lib.BlockType::val_type(hso_exact_desc_ref_type(false)),
          [@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))],
          Some([@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))]),
        ),
        @lib.Instruction::struct_new_desc(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      false,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected descriptor-if-trap heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
}

///|
test "heap-store-optimization preserves old field call effects when folding tee stores" {
  let pair = @lib.TypeIdx::new(0U)
  let optimized = match
    hso_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(20)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected old-field-effect heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("I32(20)"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds subsequent call store when only earlier field has effects" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected subsequent old-field-effect heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps subsequent struct.set when later field call orders before moved call" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected subsequent later-field-call barrier heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set when later field call orders before moved call" {
  let pair = @lib.TypeIdx::new(0U)
  let optimized = match
    hso_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected later-field-call barrier heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
}

///|
test "heap-store-optimization folds moved call when only the replaced old field has effects" {
  let pair = @lib.TypeIdx::new(0U)
  let optimized = match
    hso_call_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected old-field-only effect heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization moves local-only set value before later trapping load" {
  let pair = @lib.TypeIdx::new(0U)
  let local_ref = @lib.LocalIdx::new(0U)
  let local_tmp = @lib.LocalIdx::new(1U)
  let pair_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let optimized = match
    hso_memory_test_run_with_locals(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(
          @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(0UL)),
        ),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local_ref),
        @lib.Instruction::local_get(local_ref),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::local_set(local_tmp),
            @lib.Instruction::i32_const(@lib.I32(2)),
          ]),
        ),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local_ref),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local_tmp),
        @lib.Instruction::i32_add(),
      ],
      2,
      [pair_ref_type, @lib.ValType::i32()],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected trap-local directional heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("I32(2)"), msg=pretty)
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
test "heap-store-optimization folds non-branching pure prefix blocks into struct.new" {
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
            @lib.Instruction::i32_const(@lib.I32(0)),
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
        "expected pure-prefix fold heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
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
  assert_false(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "heap-store-optimization trims unreachable tails in non-folded local branch values" {
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
            @lib.Instruction::local_get(local0),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(7)),
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
      fail("expected local-branch heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_false(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "heap-store-optimization folds memory.size branches into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(7)),
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
      fail("expected memory-branch heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_false(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "heap-store-optimization folds function-return set values into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          [
            @lib.Instruction::i32_const(@lib.I32(42)),
            @lib.Instruction::return_(),
          ],
          Some([@lib.Instruction::i32_const(@lib.I32(7))]),
        ),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected return-value heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds safe external call values into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_call_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_tee(local0),
        @lib.Instruction::i32_const(@lib.I32(42)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::drop(),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected safe external-call heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds external throw branches into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_call_catch_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_tee(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::if_(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          [@lib.Instruction::throw_(@lib.TagIdx::new(0U))],
          Some([@lib.Instruction::i32_const(@lib.I32(42))]),
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
        "expected external-throw branch heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("throw"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds external return-call branches into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_call_catch_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_tee(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::if_(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          [
            @lib.Instruction::i32_const(@lib.I32(42)),
            @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
          ],
          Some([@lib.Instruction::i32_const(@lib.I32(42))]),
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
        "expected return-call branch heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds return-call branches inside active catches" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_call_catch_test_run(
      [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::try_table(
              @lib.BlockType::void_(),
              [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
              @lib.Expr::new([
                @lib.Instruction::struct_new_default(pair),
                @lib.Instruction::local_tee(local0),
                @lib.Instruction::i32_const(@lib.I32(0)),
                @lib.Instruction::if_(
                  @lib.BlockType::val_type(@lib.ValType::i32()),
                  [
                    @lib.Instruction::i32_const(@lib.I32(42)),
                    @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
                  ],
                  Some([@lib.Instruction::i32_const(@lib.I32(42))]),
                ),
                @lib.Instruction::struct_set(pair, @lib.U32(0U)),
              ]),
            ),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected caught return-call branch heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds first safe set before unsafe escaping branch values" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::struct_new_default(pair),
            @lib.Instruction::local_set(local0),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::struct_set(pair, @lib.U32(0U)),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
            @lib.Instruction::struct_set(pair, @lib.U32(0U)),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::struct_get(pair, @lib.U32(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(42)),
          ]),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected branch-sequence heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.new_default"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds branch values when later bad local reads disappear" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::struct_new_default(pair),
            @lib.Instruction::local_set(local0),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::struct_set(pair, @lib.U32(0U)),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
            @lib.Instruction::struct_set(pair, @lib.U32(0U)),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::struct_get(pair, @lib.U32(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(42)),
          ]),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(1337)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected disappearing-bad-get heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.new_default"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps branch values when the target local escapes later" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_ref_result_test_run(
      [
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::struct_new_default(pair),
            @lib.Instruction::local_set(local0),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
            @lib.Instruction::struct_set(pair, @lib.U32(0U)),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::i32_const(@lib.I32(4)),
            @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
            @lib.Instruction::struct_set(pair, @lib.U32(0U)),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::i32_const(@lib.I32(5)),
            @lib.Instruction::i32_const(@lib.I32(6)),
            @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
            @lib.Instruction::struct_set(pair, @lib.U32(0U)),
            @lib.Instruction::i32_const(@lib.I32(42)),
          ]),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(local0),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected escaping-local branch heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps br_table branch values inside escaping local blocks" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_ref_result_test_run(
      [
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::struct_new_default(pair),
            @lib.Instruction::local_set(local0),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::br_table(
              [@lib.LabelIdx::new(0U)],
              @lib.LabelIdx::new(0U),
            ),
            @lib.Instruction::struct_set(pair, @lib.U32(0U)),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::br_table(
              [@lib.LabelIdx::new(0U)],
              @lib.LabelIdx::new(0U),
            ),
            @lib.Instruction::struct_set(pair, @lib.U32(0U)),
            @lib.Instruction::i32_const(@lib.I32(42)),
          ]),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(local0),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected escaping-local br_table heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br_table"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds br_table branch values when later local reads disappear" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::struct_new_default(pair),
            @lib.Instruction::local_set(local0),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::br_table(
              [@lib.LabelIdx::new(0U)],
              @lib.LabelIdx::new(0U),
            ),
            @lib.Instruction::struct_set(pair, @lib.U32(0U)),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::br_table(
              [@lib.LabelIdx::new(0U)],
              @lib.LabelIdx::new(0U),
            ),
            @lib.Instruction::struct_set(pair, @lib.U32(0U)),
            @lib.Instruction::i32_const(@lib.I32(42)),
          ]),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(1337)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected br_table disappearing-local heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br_table"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps loop backedge values before prior local reads" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let optimized = match
    hso_test_run_with_locals(
      [
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::loop_(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::local_get(local0),
                @lib.Instruction::drop(),
                @lib.Instruction::struct_new_default(pair),
                @lib.Instruction::local_set(local0),
                @lib.Instruction::local_get(local0),
                @lib.Instruction::block(
                  @lib.BlockType::val_type(@lib.ValType::i32()),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(local1),
                    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::i32_const(@lib.I32(7)),
                  ]),
                ),
                @lib.Instruction::struct_set(pair, @lib.U32(0U)),
              ]),
            ),
            @lib.Instruction::i32_const(@lib.I32(42)),
          ]),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
      [@lib.ValType::ref_null(@lib.HeapType::new(pair)), @lib.ValType::i32()],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected loop-backedge heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("loop"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set for calls caught inside the function" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_call_catch_test_run(
      [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::try_table(
              @lib.BlockType::void_(),
              [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
              @lib.Expr::new([
                @lib.Instruction::struct_new_default(pair),
                @lib.Instruction::local_tee(local0),
                @lib.Instruction::i32_const(@lib.I32(42)),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::struct_set(pair, @lib.U32(0U)),
              ]),
            ),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected call/catch heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set for throws caught inside the function" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_call_catch_test_run(
      [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::try_table(
              @lib.BlockType::void_(),
              [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
              @lib.Expr::new([
                @lib.Instruction::struct_new_default(pair),
                @lib.Instruction::local_tee(local0),
                @lib.Instruction::i32_const(@lib.I32(0)),
                @lib.Instruction::if_(
                  @lib.BlockType::val_type(@lib.ValType::i32()),
                  [@lib.Instruction::throw_(@lib.TagIdx::new(0U))],
                  Some([@lib.Instruction::i32_const(@lib.I32(42))]),
                ),
                @lib.Instruction::struct_set(pair, @lib.U32(0U)),
              ]),
            ),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected throw/catch heap-store-optimization success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("throw"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds tee memory.size branches into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let optimized = match
    hso_memory_ref_result_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(8)),
          ]),
        ),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected tee memory-branch heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_false(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "heap-store-optimization trims tails after nested blocks branch out of folded values" {
  let pair = @lib.TypeIdx::new(0U)
  let optimized = match
    hso_ref_result_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::drop(),
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32(7)),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::i32_const(@lib.I32(8)),
          ]),
        ),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested-branch fold heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_false(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "heap-store-optimization trims loop tails after folded exits to the outer block" {
  let pair = @lib.TypeIdx::new(0U)
  let optimized = match
    hso_ref_result_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::loop_(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32(7)),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::i32_const(@lib.I32(8)),
          ]),
        ),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected loop-exit fold heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_false(pretty.contains("I32(8)"), msg=pretty)
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
test "heap-store-optimization folds drop-wrapped readonly local block values into struct.new" {
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
        "expected drop-wrapped readonly fold heap-store-optimization success, got \{err}",
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
test "heap-store-optimization folds immutable global readonly block prefixes into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_immutable_global_test_run(
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
        "expected immutable-global readonly-prefix fold heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds memory.size readonly block prefixes into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
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
        "expected memory-size readonly-prefix fold heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set when the ref child is wrapped in a readonly prefix block" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  let optimized = match
    hso_memory_test_run_with_locals(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::block(
          @lib.BlockType::val_type(ref_type),
          @lib.Expr::new([
            @lib.Instruction::local_get(local0),
            @lib.Instruction::local_set(local1),
            @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(local1),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
      [ref_type, ref_type],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected readonly-ref-prefix non-fold heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set for decoded raw wasm memory-size ref prefixes" {
  let optimized = match
    hso_test_run_module(
      hso_decode_fixture_module(
        hso_bytes_from_ints([
          0, 97, 115, 109, 1, 0, 0, 0, 1, 9, 2, 95, 1, 127, 1, 96, 0, 1, 127, 3,
          2, 1, 1, 5, 3, 1, 0, 1, 7, 5, 1, 1, 102, 0, 0, 10, 29, 1, 27, 1, 1, 99,
          0, 251, 1, 0, 33, 0, 32, 0, 63, 0, 26, 65, 7, 251, 5, 0, 0, 32, 0, 251,
          2, 0, 0, 11,
        ]),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected decoded-raw memory-prefix heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set for decoded raw wasm pure ref-prefix ref results" {
  let optimized = match
    hso_test_run_module(
      hso_decode_fixture_module(
        hso_bytes_from_ints([
          0, 97, 115, 109, 1, 0, 0, 0, 1, 10, 2, 95, 1, 127, 1, 96, 0, 1, 99, 0,
          3, 2, 1, 1, 10, 25, 1, 23, 1, 1, 99, 0, 251, 1, 0, 33, 0, 32, 0, 65, 0,
          26, 65, 7, 251, 5, 0, 0, 32, 0, 11,
        ]),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected decoded-raw pure ref-prefix ref-result heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps struct.set for decoded raw wasm tee pure ref-prefix ref results" {
  let optimized = match
    hso_test_run_module(
      hso_decode_fixture_module(
        hso_bytes_from_ints([
          0, 97, 115, 109, 1, 0, 0, 0, 1, 10, 2, 95, 1, 127, 1, 96, 0, 1, 99, 0,
          3, 2, 1, 1, 10, 23, 1, 21, 1, 1, 99, 0, 251, 1, 0, 34, 0, 65, 0, 26, 65,
          7, 251, 5, 0, 0, 32, 0, 11,
        ]),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected decoded-raw tee pure ref-prefix ref-result heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("local.tee"), msg=pretty)
}

///|

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
test "heap-store-optimization does not swap the fresh local.set with the final root" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(42)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected final-root no-swap heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let local_set_idx = match hso_test_index_of(pretty, "local.set") {
    Some(idx) => idx
    None => fail("expected local.set in final-root no-swap output: \{pretty}")
  }
  let final_value_idx = match hso_test_index_of(pretty, "I32(42)") {
    Some(idx) => idx
    None => fail("expected final i32.const in no-swap output: \{pretty}")
  }
  assert_true(local_set_idx < final_value_idx, msg=pretty)
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
test "heap-store-optimization folds immutable descriptor global across unrelated global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_desc_i32_global_test_run([
      @lib.Instruction::i32_const(@lib.I32(2)),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::struct_new_desc(pair),
      @lib.Instruction::local_set(local0),
      @lib.Instruction::i32_const(@lib.I32(9)),
      @lib.Instruction::global_set(@lib.GlobalIdx::new(1U)),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      @lib.Instruction::local_get(local0),
      @lib.Instruction::struct_get(pair, @lib.U32(0U)),
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected immutable descriptor/global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds memory.size constructor operands across unrelated global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_global_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size/global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds memory.size constructor operands across block-wrapped global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_global_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size/block-global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps call constructor operands before unrelated global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let mod_ = hso_call_test_module(2, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::struct_new(pair),
    @lib.Instruction::local_set(local0),
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::local_get(local0),
    @lib.Instruction::i32_const(@lib.I32(42)),
    @lib.Instruction::struct_set(pair, @lib.U32(0U)),
    @lib.Instruction::local_get(local0),
    @lib.Instruction::struct_get(pair, @lib.U32(0U)),
    @lib.Instruction::drop(),
  ]).with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
      ),
    ]),
  )
  let optimized = match hso_test_run_module(mod_) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected call/global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  let global_set_idx = match hso_test_index_of(pretty, "global.set") {
    Some(idx) => idx
    None => fail("expected global.set in call/global-set output: \{pretty}")
  }
  let struct_set_idx = match hso_test_index_of(pretty, "struct.set") {
    Some(idx) => idx
    None => fail("expected struct.set in call/global-set output: \{pretty}")
  }
  assert_true(global_set_idx < struct_set_idx, msg=pretty)
}

///|
test "heap-store-optimization folds memory.grow constructor operands across unrelated global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_global_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_grow(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-grow/global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds memory.grow constructor operands across block-wrapped global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_global_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_grow(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-grow/block-global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds memory.grow constructor operands across if-wrapped global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_global_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_grow(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          ],
          None,
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-grow/if-global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds table.size constructor operands across unrelated global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_global_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size/global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds table.grow constructor operands across unrelated global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_global_test_run(
      [
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_grow(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-grow/global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds table.grow constructor operands across block-wrapped global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_global_test_run(
      [
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_grow(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-grow/block-global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds table.size constructor operands across if-wrapped global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_global_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          ],
          None,
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size/if-global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds table.size constructor operands across loop-wrapped global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_global_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size/loop-global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("loop"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds table.grow constructor operands across loop-wrapped global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_global_test_run(
      [
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_grow(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-grow/loop-global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("loop"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds memory.grow constructor operands across loop-wrapped global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_global_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_grow(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-grow/loop-global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("loop"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds table.grow constructor operands across if-wrapped global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_global_test_run(
      [
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_grow(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          ],
          None,
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-grow/if-global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds memory.grow constructor operands across nested wrapped global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let nested_roots = [
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::i32_const(@lib.I32(9)),
              @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
            ],
            None,
          ),
        ]),
      ),
    ],
    [
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(9)),
              @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
            ]),
          ),
        ],
        None,
      ),
    ],
    [
      @lib.Instruction::loop_(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(9)),
              @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
            ]),
          ),
        ]),
      ),
    ],
  ]
  for roots in nested_roots {
    let optimized = match
      hso_memory_global_test_run(
        [
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::memory_grow(@lib.MemIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::struct_new(pair),
          @lib.Instruction::local_set(local0),
          ..roots,
          @lib.Instruction::local_get(local0),
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::struct_set(pair, @lib.U32(1U)),
          @lib.Instruction::local_get(local0),
          @lib.Instruction::struct_get(pair, @lib.U32(1U)),
        ],
        2,
      ) {
      Ok(mod_) => mod_
      Err(err) =>
        fail(
          "expected memory-grow/nested-wrapper-global-set heap-store-optimization success, got \{err}",
        )
    }

    let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
    assert_true(pretty.contains("memory.grow"), msg=pretty)
    assert_true(pretty.contains("global.set"), msg=pretty)
    assert_false(pretty.contains("struct.set"), msg=pretty)
  }
}

///|
test "heap-store-optimization folds memory.grow across branch-containing global.set wrappers" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let branch_roots = [
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(9)),
          @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        ]),
      ),
    ],
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::i32_const(@lib.I32(9)),
              @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ],
            None,
          ),
        ]),
      ),
    ],
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::loop_(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(9)),
              @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ]),
          ),
        ]),
      ),
    ],
  ]
  for roots in branch_roots {
    let optimized = match
      hso_memory_global_test_run(
        [
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::memory_grow(@lib.MemIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::struct_new(pair),
          @lib.Instruction::local_set(local0),
          ..roots,
          @lib.Instruction::local_get(local0),
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::struct_set(pair, @lib.U32(1U)),
          @lib.Instruction::local_get(local0),
          @lib.Instruction::struct_get(pair, @lib.U32(1U)),
        ],
        2,
      ) {
      Ok(mod_) => mod_
      Err(err) =>
        fail(
          "expected memory-grow/branch-wrapper-global-set heap-store-optimization success, got \{err}",
        )
    }

    let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
    assert_true(pretty.contains("memory.grow"), msg=pretty)
    assert_true(pretty.contains("global.set"), msg=pretty)
    assert_false(pretty.contains("struct.set"), msg=pretty)
  }
}

///|
test "heap-store-optimization folds table.size across branch-containing global.set wrappers" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let branch_roots = [
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(9)),
          @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        ]),
      ),
    ],
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::i32_const(@lib.I32(9)),
              @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ],
            None,
          ),
        ]),
      ),
    ],
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::loop_(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(9)),
              @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ]),
          ),
        ]),
      ),
    ],
  ]
  for roots in branch_roots {
    let optimized = match
      hso_table_global_test_run(
        [
          @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::struct_new(pair),
          @lib.Instruction::local_set(local0),
          ..roots,
          @lib.Instruction::local_get(local0),
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::struct_set(pair, @lib.U32(1U)),
          @lib.Instruction::local_get(local0),
          @lib.Instruction::struct_get(pair, @lib.U32(1U)),
        ],
        2,
      ) {
      Ok(mod_) => mod_
      Err(err) =>
        fail(
          "expected table-size/branch-wrapper-global-set heap-store-optimization success, got \{err}",
        )
    }

    let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
    assert_true(pretty.contains("table.size"), msg=pretty)
    assert_true(pretty.contains("global.set"), msg=pretty)
    assert_false(pretty.contains("struct.set"), msg=pretty)
  }
}

///|
test "heap-store-optimization folds table.grow across branch-containing global.set wrappers" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let branch_roots = [
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(9)),
          @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        ]),
      ),
    ],
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::i32_const(@lib.I32(9)),
              @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ],
            None,
          ),
        ]),
      ),
    ],
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::loop_(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(9)),
              @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ]),
          ),
        ]),
      ),
    ],
  ]
  for roots in branch_roots {
    let optimized = match
      hso_table_global_test_run(
        [
          @lib.Instruction::ref_null(
            @lib.HeapType::abs(@lib.AbsHeapType::func()),
          ),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::table_grow(@lib.TableIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::struct_new(pair),
          @lib.Instruction::local_set(local0),
          ..roots,
          @lib.Instruction::local_get(local0),
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::struct_set(pair, @lib.U32(1U)),
          @lib.Instruction::local_get(local0),
          @lib.Instruction::struct_get(pair, @lib.U32(1U)),
        ],
        2,
      ) {
      Ok(mod_) => mod_
      Err(err) =>
        fail(
          "expected table-grow/branch-wrapper-global-set heap-store-optimization success, got \{err}",
        )
    }

    let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
    assert_true(pretty.contains("table.grow"), msg=pretty)
    assert_true(pretty.contains("global.set"), msg=pretty)
    assert_false(pretty.contains("struct.set"), msg=pretty)
  }
}

///|
test "heap-store-optimization keeps memory-growing constructors before memory stores" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_global_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_grow(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::i32_store(@lib.MemArg::new(0U, None, 0UL)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-grow/memory-store heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory-growing constructors before memory.fill" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_grow(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_fill(@lib.MemIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-grow/memory-fill heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory-growing constructors before memory.copy" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_grow(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_copy(
          @lib.MemIdx::new(0U),
          @lib.MemIdx::new(0U),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-grow/memory-copy heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory-growing constructors before nested wrapped memory.fill" {
  let nested_roots = [
    hso_test_block_wrap(hso_test_if_wrap(hso_test_memory_fill_body())),
    hso_test_if_wrap(hso_test_block_wrap(hso_test_memory_fill_body())),
    hso_test_loop_wrap(hso_test_block_wrap(hso_test_memory_fill_body())),
  ]
  for roots in nested_roots {
    hso_assert_memory_grow_wrapped_passive_boundary(
      roots, "memory.fill", "memory-grow/nested-memory-fill",
    )
  }
}

///|
test "heap-store-optimization keeps memory-growing constructors before nested wrapped memory.copy" {
  let nested_roots = [
    hso_test_block_wrap(hso_test_if_wrap(hso_test_memory_copy_body())),
    hso_test_if_wrap(hso_test_block_wrap(hso_test_memory_copy_body())),
    hso_test_loop_wrap(hso_test_block_wrap(hso_test_memory_copy_body())),
  ]
  for roots in nested_roots {
    hso_assert_memory_grow_wrapped_passive_boundary(
      roots, "memory.copy", "memory-grow/nested-memory-copy",
    )
  }
}

///|
test "heap-store-optimization keeps memory-growing constructors before deep nested wrapped memory.fill" {
  let nested_roots = [
    hso_test_block_wrap(
      hso_test_block_wrap(hso_test_if_wrap(hso_test_memory_fill_body())),
    ),
    hso_test_if_wrap(
      hso_test_block_wrap(hso_test_block_wrap(hso_test_memory_fill_body())),
    ),
    hso_test_loop_wrap(
      hso_test_block_wrap(hso_test_block_wrap(hso_test_memory_fill_body())),
    ),
  ]
  for roots in nested_roots {
    hso_assert_memory_grow_wrapped_passive_boundary(
      roots, "memory.fill", "memory-grow/deep-nested-memory-fill",
    )
  }
}

///|
test "heap-store-optimization keeps memory-growing constructors before deep nested wrapped memory.copy" {
  let nested_roots = [
    hso_test_block_wrap(
      hso_test_block_wrap(hso_test_if_wrap(hso_test_memory_copy_body())),
    ),
    hso_test_if_wrap(
      hso_test_block_wrap(hso_test_block_wrap(hso_test_memory_copy_body())),
    ),
    hso_test_loop_wrap(
      hso_test_block_wrap(hso_test_block_wrap(hso_test_memory_copy_body())),
    ),
  ]
  for roots in nested_roots {
    hso_assert_memory_grow_wrapped_passive_boundary(
      roots, "memory.copy", "memory-grow/deep-nested-memory-copy",
    )
  }
}

///|
test "heap-store-optimization keeps table-growing constructors before nested wrapped table.fill" {
  let nested_roots = [
    hso_test_block_wrap(hso_test_if_wrap(hso_test_table_fill_body())),
    hso_test_if_wrap(hso_test_block_wrap(hso_test_table_fill_body())),
    hso_test_loop_wrap(hso_test_block_wrap(hso_test_table_fill_body())),
  ]
  for roots in nested_roots {
    hso_assert_table_grow_wrapped_passive_boundary(
      roots, "table.fill", "table-grow/nested-table-fill",
    )
  }
}

///|
test "heap-store-optimization keeps table-growing constructors before nested wrapped table.copy" {
  let nested_roots = [
    hso_test_block_wrap(hso_test_if_wrap(hso_test_table_copy_body())),
    hso_test_if_wrap(hso_test_block_wrap(hso_test_table_copy_body())),
    hso_test_loop_wrap(hso_test_block_wrap(hso_test_table_copy_body())),
  ]
  for roots in nested_roots {
    hso_assert_table_grow_wrapped_passive_boundary(
      roots, "table.copy", "table-grow/nested-table-copy",
    )
  }
}

///|
test "heap-store-optimization keeps table-growing constructors before deep nested wrapped table.fill" {
  let nested_roots = [
    hso_test_block_wrap(
      hso_test_block_wrap(hso_test_if_wrap(hso_test_table_fill_body())),
    ),
    hso_test_if_wrap(
      hso_test_block_wrap(hso_test_block_wrap(hso_test_table_fill_body())),
    ),
    hso_test_loop_wrap(
      hso_test_block_wrap(hso_test_block_wrap(hso_test_table_fill_body())),
    ),
  ]
  for roots in nested_roots {
    hso_assert_table_grow_wrapped_passive_boundary(
      roots, "table.fill", "table-grow/deep-nested-table-fill",
    )
  }
}

///|
test "heap-store-optimization keeps table-growing constructors before deep nested wrapped table.copy" {
  let nested_roots = [
    hso_test_block_wrap(
      hso_test_block_wrap(hso_test_if_wrap(hso_test_table_copy_body())),
    ),
    hso_test_if_wrap(
      hso_test_block_wrap(hso_test_block_wrap(hso_test_table_copy_body())),
    ),
    hso_test_loop_wrap(
      hso_test_block_wrap(hso_test_block_wrap(hso_test_table_copy_body())),
    ),
  ]
  for roots in nested_roots {
    hso_assert_table_grow_wrapped_passive_boundary(
      roots, "table.copy", "table-grow/deep-nested-table-copy",
    )
  }
}

///|
test "heap-store-optimization keeps memory.size constructors before memory.fill" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_fill(@lib.MemIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size/memory-fill heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory.size constructors before block-wrapped memory.fill" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::memory_fill(@lib.MemIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size/block-memory-fill heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory.size constructors before if-wrapped memory.fill" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::memory_fill(@lib.MemIdx::new(0U)),
          ],
          None,
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size/if-memory-fill heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory.size constructors before loop-wrapped memory.fill" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::memory_fill(@lib.MemIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size/loop-memory-fill heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory.size constructors before br_table-wrapped memory.fill" {
  hso_assert_memory_size_wrapped_passive_boundary(
    hso_test_block_wrap(
      [
        ..hso_test_memory_fill_body(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::br_table(
          [@lib.LabelIdx::new(0U)],
          @lib.LabelIdx::new(0U),
        ),
      ],
    ),
    "memory.fill",
    "memory-size/br-table-memory-fill",
  )
}

///|
test "heap-store-optimization keeps memory.size constructors before branch-containing memory.fill wrappers" {
  let branch_roots = [
    hso_test_block_wrap(
      [
        ..hso_test_memory_fill_body(),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ],
    ),
    hso_test_block_wrap([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          ..hso_test_memory_fill_body(),
          @lib.Instruction::br(@lib.LabelIdx::new(1U)),
        ],
        None,
      ),
    ]),
    hso_test_block_wrap([
      @lib.Instruction::loop_(
        @lib.BlockType::void_(),
        @lib.Expr::new(
          [
            ..hso_test_memory_fill_body(),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
        ),
      ),
    ]),
  ]
  for roots in branch_roots {
    hso_assert_memory_size_wrapped_passive_boundary(
      roots, "memory.fill", "memory-size/branch-wrapper-memory-fill",
    )
  }
}

///|
test "heap-store-optimization keeps memory.size constructors before branch-containing memory.copy wrappers" {
  for roots in hso_test_branch_containing_wraps(hso_test_memory_copy_body()) {
    hso_assert_memory_size_wrapped_passive_boundary(
      roots, "memory.copy", "memory-size/branch-wrapper-memory-copy",
    )
  }
}

///|
test "heap-store-optimization keeps memory.size constructors before branch-containing passive data wrappers" {
  for roots in hso_test_branch_containing_wraps(hso_test_memory_init_body()) {
    hso_assert_memory_size_wrapped_passive_boundary(
      roots, "memory.init", "memory-size/branch-wrapper-memory-init",
    )
  }
  for roots in hso_test_branch_containing_wraps(hso_test_data_drop_body()) {
    hso_assert_memory_size_wrapped_passive_boundary(
      roots, "data.drop", "memory-size/branch-wrapper-data-drop",
    )
  }
}

///|
test "heap-store-optimization keeps memory.grow constructors before branch-containing memory roots" {
  for roots in hso_test_branch_containing_wraps(hso_test_memory_fill_body()) {
    hso_assert_memory_grow_wrapped_passive_boundary(
      roots, "memory.fill", "memory-grow/branch-wrapper-memory-fill",
    )
  }
  for roots in hso_test_branch_containing_wraps(hso_test_memory_copy_body()) {
    hso_assert_memory_grow_wrapped_passive_boundary(
      roots, "memory.copy", "memory-grow/branch-wrapper-memory-copy",
    )
  }
  for roots in hso_test_branch_containing_wraps(hso_test_memory_init_body()) {
    hso_assert_memory_grow_wrapped_passive_boundary(
      roots, "memory.init", "memory-grow/branch-wrapper-memory-init",
    )
  }
  for roots in hso_test_branch_containing_wraps(hso_test_data_drop_body()) {
    hso_assert_memory_grow_wrapped_passive_boundary(
      roots, "data.drop", "memory-grow/branch-wrapper-data-drop",
    )
  }
}

///|
test "heap-store-optimization keeps memory.size constructors before memory.copy" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_copy(
          @lib.MemIdx::new(0U),
          @lib.MemIdx::new(0U),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size/memory-copy heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory.size constructors before block-wrapped memory.copy" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(4)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::memory_copy(
              @lib.MemIdx::new(0U),
              @lib.MemIdx::new(0U),
            ),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size/block-memory-copy heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory.size constructors before if-wrapped memory.copy" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(4)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::memory_copy(
              @lib.MemIdx::new(0U),
              @lib.MemIdx::new(0U),
            ),
          ],
          None,
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size/if-memory-copy heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory.size constructors before loop-wrapped memory.copy" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(4)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::memory_copy(
              @lib.MemIdx::new(0U),
              @lib.MemIdx::new(0U),
            ),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size/loop-memory-copy heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory.size constructors before different-memory fill" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_two_memory_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_fill(@lib.MemIdx::new(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size/different-memory-fill heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory.size constructors before different-memory copy" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_two_memory_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_copy(
          @lib.MemIdx::new(1U),
          @lib.MemIdx::new(1U),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size/different-memory-copy heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory.size constructors before mixed-destination memory copy" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_two_memory_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_copy(
          @lib.MemIdx::new(1U),
          @lib.MemIdx::new(0U),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size/mixed-destination-memory-copy heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory.size constructors before mixed-source memory copy" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_two_memory_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_copy(
          @lib.MemIdx::new(0U),
          @lib.MemIdx::new(1U),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size/mixed-source-memory-copy heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory.size constructors before memory.init" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_data_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_init(
          @lib.DataIdx::new(0U),
          @lib.MemIdx::new(0U),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size/memory-init heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("memory.init"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory.size constructors before data.drop" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_data_test_run(
      [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::data_drop(@lib.DataIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-size/data-drop heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("data.drop"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory.size constructors before block-wrapped memory.init" {
  hso_assert_memory_size_wrapped_passive_boundary(
    hso_test_block_wrap(hso_test_memory_init_body()),
    "memory.init",
    "memory-size/block-memory-init",
  )
}

///|
test "heap-store-optimization keeps memory.size constructors before if-wrapped memory.init" {
  hso_assert_memory_size_wrapped_passive_boundary(
    hso_test_if_wrap(hso_test_memory_init_body()),
    "memory.init",
    "memory-size/if-memory-init",
  )
}

///|
test "heap-store-optimization keeps memory.size constructors before loop-wrapped memory.init" {
  hso_assert_memory_size_wrapped_passive_boundary(
    hso_test_loop_wrap(hso_test_memory_init_body()),
    "memory.init",
    "memory-size/loop-memory-init",
  )
}

///|
test "heap-store-optimization keeps memory.size constructors before block-wrapped data.drop" {
  hso_assert_memory_size_wrapped_passive_boundary(
    hso_test_block_wrap(hso_test_data_drop_body()),
    "data.drop",
    "memory-size/block-data-drop",
  )
}

///|
test "heap-store-optimization keeps memory.size constructors before if-wrapped data.drop" {
  hso_assert_memory_size_wrapped_passive_boundary(
    hso_test_if_wrap(hso_test_data_drop_body()),
    "data.drop",
    "memory-size/if-data-drop",
  )
}

///|
test "heap-store-optimization keeps memory.size constructors before loop-wrapped data.drop" {
  hso_assert_memory_size_wrapped_passive_boundary(
    hso_test_loop_wrap(hso_test_data_drop_body()),
    "data.drop",
    "memory-size/loop-data-drop",
  )
}

///|
test "heap-store-optimization keeps memory-growing constructors before memory.init" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_data_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_grow(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_init(
          @lib.DataIdx::new(0U),
          @lib.MemIdx::new(0U),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-grow/memory-init heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("memory.init"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory-growing constructors before data.drop" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_data_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_grow(@lib.MemIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::data_drop(@lib.DataIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-grow/data-drop heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("data.drop"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps memory-growing constructors before block-wrapped memory.init" {
  hso_assert_memory_grow_wrapped_passive_boundary(
    hso_test_block_wrap(hso_test_memory_init_body()),
    "memory.init",
    "memory-grow/block-memory-init",
  )
}

///|
test "heap-store-optimization keeps memory-growing constructors before if-wrapped memory.init" {
  hso_assert_memory_grow_wrapped_passive_boundary(
    hso_test_if_wrap(hso_test_memory_init_body()),
    "memory.init",
    "memory-grow/if-memory-init",
  )
}

///|
test "heap-store-optimization keeps memory-growing constructors before loop-wrapped memory.init" {
  hso_assert_memory_grow_wrapped_passive_boundary(
    hso_test_loop_wrap(hso_test_memory_init_body()),
    "memory.init",
    "memory-grow/loop-memory-init",
  )
}

///|
test "heap-store-optimization keeps memory-growing constructors before block-wrapped data.drop" {
  hso_assert_memory_grow_wrapped_passive_boundary(
    hso_test_block_wrap(hso_test_data_drop_body()),
    "data.drop",
    "memory-grow/block-data-drop",
  )
}

///|
test "heap-store-optimization keeps memory-growing constructors before if-wrapped data.drop" {
  hso_assert_memory_grow_wrapped_passive_boundary(
    hso_test_if_wrap(hso_test_data_drop_body()),
    "data.drop",
    "memory-grow/if-data-drop",
  )
}

///|
test "heap-store-optimization keeps memory-growing constructors before loop-wrapped data.drop" {
  hso_assert_memory_grow_wrapped_passive_boundary(
    hso_test_loop_wrap(hso_test_data_drop_body()),
    "data.drop",
    "memory-grow/loop-data-drop",
  )
}

///|
test "heap-store-optimization keeps memory-growing constructors before block-if-wrapped memory.init" {
  hso_assert_memory_grow_wrapped_passive_boundary(
    hso_test_block_wrap(hso_test_if_wrap(hso_test_memory_init_body())),
    "memory.init",
    "memory-grow/block-if-memory-init",
  )
}

///|
test "heap-store-optimization keeps memory-growing constructors before if-block-wrapped memory.init" {
  hso_assert_memory_grow_wrapped_passive_boundary(
    hso_test_if_wrap(hso_test_block_wrap(hso_test_memory_init_body())),
    "memory.init",
    "memory-grow/if-block-memory-init",
  )
}

///|
test "heap-store-optimization keeps memory-growing constructors before loop-block-wrapped memory.init" {
  hso_assert_memory_grow_wrapped_passive_boundary(
    hso_test_loop_wrap(hso_test_block_wrap(hso_test_memory_init_body())),
    "memory.init",
    "memory-grow/loop-block-memory-init",
  )
}

///|
test "heap-store-optimization keeps memory-growing constructors before block-if-wrapped data.drop" {
  hso_assert_memory_grow_wrapped_passive_boundary(
    hso_test_block_wrap(hso_test_if_wrap(hso_test_data_drop_body())),
    "data.drop",
    "memory-grow/block-if-data-drop",
  )
}

///|
test "heap-store-optimization keeps memory-growing constructors before if-block-wrapped data.drop" {
  hso_assert_memory_grow_wrapped_passive_boundary(
    hso_test_if_wrap(hso_test_block_wrap(hso_test_data_drop_body())),
    "data.drop",
    "memory-grow/if-block-data-drop",
  )
}

///|
test "heap-store-optimization keeps memory-growing constructors before loop-block-wrapped data.drop" {
  hso_assert_memory_grow_wrapped_passive_boundary(
    hso_test_loop_wrap(hso_test_block_wrap(hso_test_data_drop_body())),
    "data.drop",
    "memory-grow/loop-block-data-drop",
  )
}

///|
test "heap-store-optimization keeps table.size constructors before table.init" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_elem_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_init(
          @lib.ElemIdx::new(0U),
          @lib.TableIdx::new(0U),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size/table-init heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("table.init"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table.size constructors before elem.drop" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_elem_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::elem_drop(@lib.ElemIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size/elem-drop heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("elem.drop"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table.size constructors before block-wrapped table.init" {
  hso_assert_table_size_wrapped_passive_boundary(
    hso_test_block_wrap(hso_test_table_init_body()),
    "table.init",
    "table-size/block-table-init",
  )
}

///|
test "heap-store-optimization keeps table.size constructors before if-wrapped table.init" {
  hso_assert_table_size_wrapped_passive_boundary(
    hso_test_if_wrap(hso_test_table_init_body()),
    "table.init",
    "table-size/if-table-init",
  )
}

///|
test "heap-store-optimization keeps table.size constructors before loop-wrapped table.init" {
  hso_assert_table_size_wrapped_passive_boundary(
    hso_test_loop_wrap(hso_test_table_init_body()),
    "table.init",
    "table-size/loop-table-init",
  )
}

///|
test "heap-store-optimization keeps table.size constructors before block-wrapped elem.drop" {
  hso_assert_table_size_wrapped_passive_boundary(
    hso_test_block_wrap(hso_test_elem_drop_body()),
    "elem.drop",
    "table-size/block-elem-drop",
  )
}

///|
test "heap-store-optimization keeps table.size constructors before if-wrapped elem.drop" {
  hso_assert_table_size_wrapped_passive_boundary(
    hso_test_if_wrap(hso_test_elem_drop_body()),
    "elem.drop",
    "table-size/if-elem-drop",
  )
}

///|
test "heap-store-optimization keeps table.size constructors before loop-wrapped elem.drop" {
  hso_assert_table_size_wrapped_passive_boundary(
    hso_test_loop_wrap(hso_test_elem_drop_body()),
    "elem.drop",
    "table-size/loop-elem-drop",
  )
}

///|
test "heap-store-optimization keeps table-growing constructors before table.init" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_elem_test_run(
      [
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_grow(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_init(
          @lib.ElemIdx::new(0U),
          @lib.TableIdx::new(0U),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-grow/table-init heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("table.init"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table-growing constructors before elem.drop" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_elem_test_run(
      [
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_grow(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::elem_drop(@lib.ElemIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-grow/elem-drop heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("elem.drop"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table-growing constructors before block-wrapped table.init" {
  hso_assert_table_grow_wrapped_passive_boundary(
    hso_test_block_wrap(hso_test_table_init_body()),
    "table.init",
    "table-grow/block-table-init",
  )
}

///|
test "heap-store-optimization keeps table-growing constructors before if-wrapped table.init" {
  hso_assert_table_grow_wrapped_passive_boundary(
    hso_test_if_wrap(hso_test_table_init_body()),
    "table.init",
    "table-grow/if-table-init",
  )
}

///|
test "heap-store-optimization keeps table-growing constructors before loop-wrapped table.init" {
  hso_assert_table_grow_wrapped_passive_boundary(
    hso_test_loop_wrap(hso_test_table_init_body()),
    "table.init",
    "table-grow/loop-table-init",
  )
}

///|
test "heap-store-optimization keeps table-growing constructors before block-wrapped elem.drop" {
  hso_assert_table_grow_wrapped_passive_boundary(
    hso_test_block_wrap(hso_test_elem_drop_body()),
    "elem.drop",
    "table-grow/block-elem-drop",
  )
}

///|
test "heap-store-optimization keeps table-growing constructors before if-wrapped elem.drop" {
  hso_assert_table_grow_wrapped_passive_boundary(
    hso_test_if_wrap(hso_test_elem_drop_body()),
    "elem.drop",
    "table-grow/if-elem-drop",
  )
}

///|
test "heap-store-optimization keeps table-growing constructors before loop-wrapped elem.drop" {
  hso_assert_table_grow_wrapped_passive_boundary(
    hso_test_loop_wrap(hso_test_elem_drop_body()),
    "elem.drop",
    "table-grow/loop-elem-drop",
  )
}

///|
test "heap-store-optimization keeps table-growing constructors before block-if-wrapped table.init" {
  hso_assert_table_grow_wrapped_passive_boundary(
    hso_test_block_wrap(hso_test_if_wrap(hso_test_table_init_body())),
    "table.init",
    "table-grow/block-if-table-init",
  )
}

///|
test "heap-store-optimization keeps table-growing constructors before if-block-wrapped table.init" {
  hso_assert_table_grow_wrapped_passive_boundary(
    hso_test_if_wrap(hso_test_block_wrap(hso_test_table_init_body())),
    "table.init",
    "table-grow/if-block-table-init",
  )
}

///|
test "heap-store-optimization keeps table-growing constructors before loop-block-wrapped table.init" {
  hso_assert_table_grow_wrapped_passive_boundary(
    hso_test_loop_wrap(hso_test_block_wrap(hso_test_table_init_body())),
    "table.init",
    "table-grow/loop-block-table-init",
  )
}

///|
test "heap-store-optimization keeps table-growing constructors before block-if-wrapped elem.drop" {
  hso_assert_table_grow_wrapped_passive_boundary(
    hso_test_block_wrap(hso_test_if_wrap(hso_test_elem_drop_body())),
    "elem.drop",
    "table-grow/block-if-elem-drop",
  )
}

///|
test "heap-store-optimization keeps table-growing constructors before if-block-wrapped elem.drop" {
  hso_assert_table_grow_wrapped_passive_boundary(
    hso_test_if_wrap(hso_test_block_wrap(hso_test_elem_drop_body())),
    "elem.drop",
    "table-grow/if-block-elem-drop",
  )
}

///|
test "heap-store-optimization keeps table-growing constructors before loop-block-wrapped elem.drop" {
  hso_assert_table_grow_wrapped_passive_boundary(
    hso_test_loop_wrap(hso_test_block_wrap(hso_test_elem_drop_body())),
    "elem.drop",
    "table-grow/loop-block-elem-drop",
  )
}

///|
test "heap-store-optimization keeps table-growing constructors before table.fill" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_test_run(
      [
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_grow(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_fill(@lib.TableIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-grow/table-fill heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("table.fill"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table-growing constructors before table.copy" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_test_run(
      [
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_grow(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_copy(
          @lib.TableIdx::new(0U),
          @lib.TableIdx::new(0U),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-grow/table-copy heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("table.copy"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table.size constructors before block-wrapped table.fill" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::table_fill(@lib.TableIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size/block-table-fill heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("table.fill"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table.size constructors before if-wrapped table.fill" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::table_fill(@lib.TableIdx::new(0U)),
          ],
          None,
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size/if-table-fill heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("table.fill"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table.size constructors before loop-wrapped table.fill" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::table_fill(@lib.TableIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size/loop-table-fill heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("table.fill"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table.size constructors before branch-containing table.fill wrappers" {
  let branch_roots = [
    hso_test_block_wrap(
      [
        ..hso_test_table_fill_body(),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ],
    ),
    hso_test_block_wrap([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          ..hso_test_table_fill_body(),
          @lib.Instruction::br(@lib.LabelIdx::new(1U)),
        ],
        None,
      ),
    ]),
    hso_test_block_wrap([
      @lib.Instruction::loop_(
        @lib.BlockType::void_(),
        @lib.Expr::new(
          [
            ..hso_test_table_fill_body(),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
        ),
      ),
    ]),
  ]
  for roots in branch_roots {
    hso_assert_table_size_wrapped_passive_boundary(
      roots, "table.fill", "table-size/branch-wrapper-table-fill",
    )
  }
}

///|
test "heap-store-optimization keeps table.size constructors before branch-containing table.copy wrappers" {
  for roots in hso_test_branch_containing_wraps(hso_test_table_copy_body()) {
    hso_assert_table_size_wrapped_passive_boundary(
      roots, "table.copy", "table-size/branch-wrapper-table-copy",
    )
  }
}

///|
test "heap-store-optimization keeps table.size constructors before branch-containing passive element wrappers" {
  for roots in hso_test_branch_containing_wraps(hso_test_table_init_body()) {
    hso_assert_table_size_wrapped_passive_boundary(
      roots, "table.init", "table-size/branch-wrapper-table-init",
    )
  }
  for roots in hso_test_branch_containing_wraps(hso_test_elem_drop_body()) {
    hso_assert_table_size_wrapped_passive_boundary(
      roots, "elem.drop", "table-size/branch-wrapper-elem-drop",
    )
  }
}

///|
test "heap-store-optimization keeps table.grow constructors before branch-containing table roots" {
  for roots in hso_test_branch_containing_wraps(hso_test_table_fill_body()) {
    hso_assert_table_grow_wrapped_passive_boundary(
      roots, "table.fill", "table-grow/branch-wrapper-table-fill",
    )
  }
  for roots in hso_test_branch_containing_wraps(hso_test_table_copy_body()) {
    hso_assert_table_grow_wrapped_passive_boundary(
      roots, "table.copy", "table-grow/branch-wrapper-table-copy",
    )
  }
  for roots in hso_test_branch_containing_wraps(hso_test_table_init_body()) {
    hso_assert_table_grow_wrapped_passive_boundary(
      roots, "table.init", "table-grow/branch-wrapper-table-init",
    )
  }
  for roots in hso_test_branch_containing_wraps(hso_test_elem_drop_body()) {
    hso_assert_table_grow_wrapped_passive_boundary(
      roots, "elem.drop", "table-grow/branch-wrapper-elem-drop",
    )
  }
}

///|
test "heap-store-optimization keeps table.size constructors before different-table fill" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_two_table_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_fill(@lib.TableIdx::new(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size/different-table-fill heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("table.fill"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table.size constructors before block-wrapped table.copy" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::table_copy(
              @lib.TableIdx::new(0U),
              @lib.TableIdx::new(0U),
            ),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size/block-table-copy heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("table.copy"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table.size constructors before if-wrapped table.copy" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::table_copy(
              @lib.TableIdx::new(0U),
              @lib.TableIdx::new(0U),
            ),
          ],
          None,
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size/if-table-copy heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("table.copy"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table.size constructors before loop-wrapped table.copy" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::table_copy(
              @lib.TableIdx::new(0U),
              @lib.TableIdx::new(0U),
            ),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size/loop-table-copy heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("table.copy"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table.size constructors before different-table copy" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_two_table_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_copy(
          @lib.TableIdx::new(1U),
          @lib.TableIdx::new(1U),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size/different-table-copy heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("table.copy"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table.size constructors before mixed-destination table copy" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_two_table_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_copy(
          @lib.TableIdx::new(1U),
          @lib.TableIdx::new(0U),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size/mixed-destination-table-copy heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("table.copy"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table.size constructors before mixed-source table copy" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_two_table_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_copy(
          @lib.TableIdx::new(0U),
          @lib.TableIdx::new(1U),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size/mixed-source-table-copy heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("table.copy"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table.size constructors before table stores" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_test_run(
      [
        @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        @lib.Instruction::table_set(@lib.TableIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-size/table-store heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps table-growing constructors before table stores" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_table_test_run(
      [
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::table_grow(@lib.TableIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        @lib.Instruction::table_set(@lib.TableIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table-grow/table-store heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps trapping memory loads before unrelated global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_global_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-load/global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization does not fold through an intervening constructor local.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let optimized = match
    hso_test_run_with_locals(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local1),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
      [
        @lib.ValType::ref_null(@lib.HeapType::new(pair)),
        @lib.ValType::ref_null(@lib.HeapType::new(pair)),
      ],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected constructor-local-set barrier heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds across wrapped constructor local.set roots" {
  let pair = @lib.TypeIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let wrapped_roots = [
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::struct_new_default(pair),
          @lib.Instruction::local_set(local1),
        ]),
      ),
    ],
    [
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::struct_new_default(pair),
          @lib.Instruction::local_set(local1),
        ],
        None,
      ),
    ],
    [
      @lib.Instruction::loop_(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::struct_new_default(pair),
          @lib.Instruction::local_set(local1),
        ]),
      ),
    ],
  ]
  for roots in wrapped_roots {
    let optimized = match
      hso_test_run_with_locals(
        [
          @lib.Instruction::struct_new_default(pair),
          @lib.Instruction::local_set(local0),
          ..roots,
          @lib.Instruction::local_get(local0),
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::struct_set(pair, @lib.U32(0U)),
          @lib.Instruction::local_get(local0),
          @lib.Instruction::struct_get(pair, @lib.U32(0U)),
        ],
        1,
        [ref_type, ref_type],
      ) {
      Ok(mod_) => mod_
      Err(err) =>
        fail(
          "expected wrapped constructor-local-set heap-store-optimization success, got \{err}",
        )
    }

    let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
    assert_true(pretty.contains("local.set"), msg=pretty)
    assert_false(pretty.contains("struct.set"), msg=pretty)
  }
}

///|
test "heap-store-optimization folds across branch-containing constructor local.set wrappers" {
  let pair = @lib.TypeIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let branch_roots = [
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::struct_new_default(pair),
          @lib.Instruction::local_set(local1),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        ]),
      ),
    ],
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::struct_new_default(pair),
              @lib.Instruction::local_set(local1),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ],
            None,
          ),
        ]),
      ),
    ],
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::loop_(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::struct_new_default(pair),
              @lib.Instruction::local_set(local1),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ]),
          ),
        ]),
      ),
    ],
  ]
  for roots in branch_roots {
    let optimized = match
      hso_test_run_with_locals(
        [
          @lib.Instruction::struct_new_default(pair),
          @lib.Instruction::local_set(local0),
          ..roots,
          @lib.Instruction::local_get(local0),
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::struct_set(pair, @lib.U32(0U)),
          @lib.Instruction::local_get(local0),
          @lib.Instruction::struct_get(pair, @lib.U32(0U)),
        ],
        1,
        [ref_type, ref_type],
      ) {
      Ok(mod_) => mod_
      Err(err) =>
        fail(
          "expected branch-wrapper constructor-local-set heap-store-optimization success, got \{err}",
        )
    }

    let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
    assert_true(pretty.contains("struct.new_default"), msg=pretty)
    assert_true(pretty.contains("local.set"), msg=pretty)
    assert_true(pretty.contains("br"), msg=pretty)
    assert_false(pretty.contains("struct.set"), msg=pretty)
  }
}

///|
test "heap-store-optimization keeps global.set before constructor global.get" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_global_test_run(
      [
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected global-set barrier heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds constructor global.get across unrelated global.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_two_global_test_run(
      [
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::global_set(@lib.GlobalIdx::new(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected unrelated-global-set heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds constructor global.get across unrelated global.set value read" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_two_global_test_run(
      [
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::global_set(@lib.GlobalIdx::new(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
      2,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected unrelated-global-set value-read heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps the rewritten local.set valid after nop cleanup" {
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
  assert_true(pretty.contains("(local.set (Local 0))"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds readonly block-prefix values into struct.new" {
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
        "expected readonly-prefix fold heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds tee readonly block-prefix values into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_global_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_tee(local0),
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
        "expected tee readonly-prefix fold heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
}

///|
test "heap-store-optimization folds tee multi-root pure block values into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_tee(local0),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
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
        "expected tee multi-root pure-block fold heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
}

///|
test "heap-store-optimization folds tee memory.size block values into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_tee(local0),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
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
        "expected tee memory-size block fold heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
}

///|
test "heap-store-optimization folds tee pure block ref results into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_ref_result_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_tee(local0),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(7)),
          ]),
        ),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected tee pure-block ref-result fold heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
}

///|
test "heap-store-optimization folds tee memory.size ref results into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_memory_ref_result_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_tee(local0),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(7)),
          ]),
        ),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected tee memory-size ref-result fold heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
}

///|
test "heap-store-optimization folds swapped readonly block values into struct.new" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_global_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          ]),
        ),
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
        "expected swapped-prefix fold heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization folds nested readonly tail blocks into struct.new" {
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
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
            ),
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
        "expected nested-tail fold heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization flattens swapped block roots before the folded local.set" {
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_global_test_run(
      [
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(11)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected swapped-block-root heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
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
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_false(pretty.contains("block"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps swapped peeled prefix roots valid after nop cleanup" {
  let optimized = match
    run_hot_pipeline(
      hso_decode_fixture_module(
        hso_bytes_from_ints([
          0, 97, 115, 109, 1, 0, 0, 0, 1, 10, 2, 95, 1, 127, 1, 96, 0, 1, 99, 0,
          3, 2, 1, 1, 7, 5, 1, 1, 102, 0, 0, 10, 44, 1, 42, 2, 1, 99, 0, 1, 127,
          251, 1, 0, 33, 0, 2, 64, 65, 9, 33, 1, 11, 32, 0, 2, 127, 65, 0, 26, 2,
          127, 65, 7, 12, 0, 65, 8, 11, 11, 251, 5, 0, 0, 32, 0, 11, 0, 26, 4, 110,
          97, 109, 101, 3, 13, 1, 0, 2, 1, 1, 118, 2, 5, 105, 110, 110, 101, 114,
          4, 4, 1, 0, 1, 115,
        ]),
      ),
      HotPipelineOptions::new(),
      ["heap-store-optimization"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected swapped nop-order heap-store-optimization success, got \{err}",
      )
  }

  match optimized.code_sec {
    Some(_) => ()
    None => fail("expected optimized decoded fixture code")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization flattens nested if-tail wrappers inside folded values" {
  let optimized = match
    hso_ref_result_test_run(
      [
        @lib.Instruction::struct_new_default(@lib.TypeIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::drop(),
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32(1)),
                @lib.Instruction::if_(
                  @lib.BlockType::val_type(@lib.ValType::i32()),
                  [
                    @lib.Instruction::i32_const(@lib.I32(7)),
                    @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                  ],
                  Some([@lib.Instruction::i32_const(@lib.I32(9))]),
                ),
              ]),
            ),
          ]),
        ),
        @lib.Instruction::struct_set(@lib.TypeIdx::new(0U), @lib.U32(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested-if-tail heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
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

///|
test "heap-store-optimization keeps struct.set when the moved value writes the target local" {
  let box = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::struct_new(box),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::struct_new(box),
            @lib.Instruction::local_set(local0),
            @lib.Instruction::i32_const(@lib.I32(1)),
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
        "expected target-local write heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap-store-optimization keeps chain stores when a moved value writes the target local" {
  let box = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::struct_new(box),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::struct_new(box),
            @lib.Instruction::local_set(local0),
            @lib.Instruction::i32_const(@lib.I32(1)),
          ]),
        ),
        @lib.Instruction::struct_set(box, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::struct_set(box, @lib.U32(0U)),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::struct_get(box, @lib.U32(0U)),
      ],
      1,
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected target-local write chain heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_eq(hso_test_count_occurrences(pretty, "struct.set"), 2, msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(2)"), msg=pretty)
}

///|
test "heap-store-optimization folds earlier chain stores before a later target-local read hazard" {
  let box = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let optimized = match
    hso_test_run(
      [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::struct_new(box),
        @lib.Instruction::local_set(local0),
        @lib.Instruction::local_get(local0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::struct_set(box, @lib.U32(0U)),
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
    Err(err) =>
      fail(
        "expected target-local read chain heap-store-optimization success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_eq(hso_test_count_occurrences(pretty, "struct.set"), 1, msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
}
