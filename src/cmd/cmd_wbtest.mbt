///|
using @binary {trait Decode}

///|
using @lib {type Func, type CodeSec}

///|
fn bytes_from_string(text : String) -> Bytes {
  let buf = @buffer.new(size_hint=text.length())
  for c in text {
    buf.write_byte(c.to_int().to_byte())
  }
  buf.to_bytes()
}

///|
fn bytes_to_ascii_string(bytes : Bytes) -> String {
  let out = StringBuilder::new()
  for b in bytes {
    let i = b.to_int()
    if i >= 0 && i <= 127 {
      out.write_char(i.unsafe_to_char())
    } else {
      out.write_char('?')
    }
  }
  out.to_string()
}

///|
fn bytes_from_ints(values : Array[Int]) -> Bytes {
  let out = @buffer.new(size_hint=values.length())
  for value in values {
    out.write_byte(value.to_byte())
  }
  out.to_bytes()
}

///|
fn encode_module_fixture_bytes(mod : Module) -> Bytes {
  match @binary.encode_module(mod) {
    Ok(bytes) => bytes
    Err(e) => abort("unexpected cmd fixture encode failure: \{e}")
  }
}

///|
fn concat_ascii_bytes(chunks : Array[Bytes]) -> String {
  let out = StringBuilder::new()
  for chunk in chunks {
    out.write_string(bytes_to_ascii_string(chunk))
  }
  out.to_string()
}

///|
fn assert_strings_appear_in_order(
  text : String,
  needles : Array[String],
) -> Unit raise {
  let mut start = 0
  for needle in needles {
    let mut found : Int? = None
    let limit = text.length() - needle.length()
    let mut i = start
    while i <= limit {
      if text.sub(start=i, end=i + needle.length()).to_owned() == needle {
        found = Some(i)
        break
      }
      i += 1
    }
    match found {
      Some(idx) => start = idx + needle.length()
      None =>
        fail("expected `\{needle}` after byte offset \{start} in `\{text}`")
    }
  }
}

///|
fn encode_module_bytes(mod : Module) -> Bytes {
  let buf = @buffer.new()
  match Encode::encode(mod, buf) {
    Ok(_) => buf.to_bytes()
    Err(e) => abort("unexpected module encode failure in test fixture: \{e}")
  }
}

///|
fn decode_module_bytes(bytes : Bytes) -> Module {
  match Decode::decode(bytes, 0) {
    Ok((mod, idx)) => {
      if idx != bytes.length() {
        abort(
          "unexpected trailing bytes while decoding fixture module: decoded \{idx}, total \{bytes.length()}",
        )
      }
      mod
    }
    Err(e) => abort("unexpected module decode failure in test fixture: \{e}")
  }
}

///|
fn encode_pipeline_roundtrip_for_test(mod_ : Module) -> Module {
  let bytes = match
    encode_module_for_pipeline(
      CmdIO::new(),
      "encoding-label-fixture.wasm",
      mod_,
    ) {
    Ok(bytes) => bytes
    Err(err) => abort("unexpected pipeline encode failure: \{err}")
  }
  decode_module_bytes(bytes)
}

///|
fn encoding_label_fixture(body : Array[@lib.Instruction]) -> Module {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  Module::new()
  .with_type_sec(@lib.TypeSec::new([func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    ]),
  )
}

///|
fn assert_encoding_pipeline_roundtrip_valid(mod_ : Module) -> Module raise {
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) => fail("expected encoding fixture to validate, got \{err}")
  }
  let roundtripped = encode_pipeline_roundtrip_for_test(mod_)
  match @validate.validate_module(roundtripped) {
    Ok(_) => roundtripped
    Err(err) => fail("expected encoded roundtrip to validate, got \{err}")
  }
}

///|
fn count_substring(text : String, needle : String) -> Int {
  if needle.length() == 0 {
    return 0
  }
  let mut count = 0
  let limit = text.length() - needle.length()
  let mut i = 0
  while i <= limit {
    if text.sub(start=i, end=i + needle.length()).to_owned() == needle {
      count += 1
      i += needle.length()
    } else {
      i += 1
    }
  }
  count
}

///|
fn module_with_label_names(mod_ : Module, label_count : Int) -> Module {
  let label_entries : Array[@lib.NameAssoc] = []
  for i = 0; i < label_count; i = i + 1 {
    label_entries.push(
      @lib.NameAssoc::new(i.reinterpret_as_uint(), @lib.Name::new("label\{i}")),
    )
  }
  mod_.with_name_sec(
    @lib.NameSec::new(
      label_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(0U, @lib.NameMap::new(label_entries)),
        ]),
      ),
    ),
  )
}

///|
fn name_map_order_error(label : String, names : @lib.NameMap) -> String? {
  let @lib.NameMap(entries) = names
  let mut prev_idx : UInt? = None
  for entry in entries {
    let @lib.NameAssoc(idx, _) = entry
    match prev_idx {
      Some(prev) if idx <= prev =>
        return Some("\{label} out of order: \{prev} then \{idx}")
      _ => prev_idx = Some(idx)
    }
  }
  None
}

///|
fn indirect_name_map_order_error(
  label : String,
  names : @lib.IndirectNameMap,
) -> String? {
  let @lib.IndirectNameMap(entries) = names
  let mut prev_idx : UInt? = None
  for entry in entries {
    let @lib.IndirectNameAssoc(idx, inner) = entry
    match prev_idx {
      Some(prev) if idx <= prev =>
        return Some("\{label} out of order: \{prev} then \{idx}")
      _ => ()
    }
    prev_idx = Some(idx)
    match name_map_order_error("\{label}[\{idx}]", inner) {
      Some(err) => return Some(err)
      None => ()
    }
  }
  None
}

///|
fn module_name_section_order_error(mod : Module) -> String? {
  match mod.name_sec {
    Some(name_sec) => {
      let {
        func_names,
        local_names,
        label_names,
        type_names,
        table_names,
        memory_names,
        global_names,
        elem_names,
        data_names,
        field_names,
        tag_names,
        ..,
      } = name_sec
      for
        check in [
          match func_names {
            Some(names) => name_map_order_error("func_names", names)
            None => None
          },
          match local_names {
            Some(names) => indirect_name_map_order_error("local_names", names)
            None => None
          },
          match label_names {
            Some(names) => indirect_name_map_order_error("label_names", names)
            None => None
          },
          match type_names {
            Some(names) => name_map_order_error("type_names", names)
            None => None
          },
          match table_names {
            Some(names) => name_map_order_error("table_names", names)
            None => None
          },
          match memory_names {
            Some(names) => name_map_order_error("memory_names", names)
            None => None
          },
          match global_names {
            Some(names) => name_map_order_error("global_names", names)
            None => None
          },
          match elem_names {
            Some(names) => name_map_order_error("elem_names", names)
            None => None
          },
          match data_names {
            Some(names) => name_map_order_error("data_names", names)
            None => None
          },
          match field_names {
            Some(names) => indirect_name_map_order_error("field_names", names)
            None => None
          },
          match tag_names {
            Some(names) => name_map_order_error("tag_names", names)
            None => None
          },
        ] {
        match check {
          Some(err) => return Some(err)
          None => ()
        }
      }
      None
    }
    None => None
  }
}

///|
fn fixture_i32_const_module(value : Int) -> Module {
  let t_i32 = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  Module::new()
  .with_code_sec(
    CodeSec::new([
      Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(value))]),
      ),
    ]),
  )
  .with_type_sec(@lib.TypeSec::new([t_i32]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0)]))
}

///|
fn fixture_f32_nan_module() -> Module {
  let nan_bits : UInt = 0x7FC00001
  let nan = @lib.F32(Float::reinterpret_from_uint(nan_bits))
  let t_f32 = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::f32()])),
  )
  Module::new()
  .with_code_sec(
    CodeSec::new([
      Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::f32_const(nan)]),
      ),
    ]),
  )
  .with_type_sec(@lib.TypeSec::new([t_f32]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0)]))
}

///|
fn fixture_f64_nan_module() -> Module {
  let nan = @lib.F64(0x7FF8000000000001UL.reinterpret_as_double())
  let t_f64 = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::f64()])),
  )
  Module::new()
  .with_code_sec(
    CodeSec::new([
      Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::f64_const(nan)]),
      ),
    ]),
  )
  .with_type_sec(@lib.TypeSec::new([t_f64]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0)]))
}

///|
fn fixture_invalid_i32_result_module() -> Module {
  let t_i32 = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  Module::new()
  .with_code_sec(
    CodeSec::new([Func::new(@lib.Locals::empty(), @lib.Expr::new([]))]),
  )
  .with_type_sec(@lib.TypeSec::new([t_i32]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0)]))
}

///|
fn fixture_print_log_module() -> Module {
  let t_i32 = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  Module::new()
  .with_type_sec(@lib.TypeSec::new([t_i32]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0)]))
  .with_code_sec(
    CodeSec::new([
      Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(5)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        ]),
      ),
    ]),
  )
  .with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        @lib.TableType::new(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
          @lib.Limits::i32(1U, Some(1U)),
        ),
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
        @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
      ),
    ]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::new("main"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
      ),
    ]),
  )
  .with_name_sec(
    @lib.NameSec::new(
      func_names=Some(
        @lib.NameMap::new([@lib.NameAssoc::new(0U, @lib.Name::new("main"))]),
      ),
      type_names=Some(
        @lib.NameMap::new([@lib.NameAssoc::new(0U, @lib.Name::new("t0"))]),
      ),
      elem_names=Some(
        @lib.NameMap::new([@lib.NameAssoc::new(0U, @lib.Name::new("elist"))]),
      ),
    ),
  )
}

///|
fn fixture_extract_functions_module() -> Module {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let table_type = @lib.TableType::new(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
    @lib.Limits::i32(1U, None),
  )
  let mem_type = @lib.MemType::new(@lib.Limits::i32(1U, None))
  Module::new()
  .with_type_sec(@lib.TypeSec::new([func_type]))
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("keep_import"),
        @lib.ExternType::func(@lib.TypeIdx::new(0U)),
      ),
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("dead_import"),
        @lib.ExternType::func(@lib.TypeIdx::new(0U)),
      ),
    ]),
  )
  .with_func_sec(
    @lib.FuncSec::new([
      @lib.TypeIdx::new(0U),
      @lib.TypeIdx::new(0U),
      @lib.TypeIdx::new(0U),
    ]),
  )
  .with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(table_type, None),
      @lib.Table::new(table_type, None),
    ]),
  )
  .with_mem_sec(@lib.MemSec::new([mem_type, mem_type]))
  .with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), false),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
      ),
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), false),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(2))]),
      ),
    ]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::new("dead"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(2U)),
      ),
      @lib.Export::new(
        @lib.Name::new("keep"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(3U)),
      ),
      @lib.Export::new(
        @lib.Name::new("deadmem"),
        @lib.ExternIdx::mem(@lib.MemIdx::new(0U)),
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
        @lib.ElemKind::funcs([@lib.FuncIdx::new(2U)]),
      ),
      @lib.Elem::new(
        @lib.ElemMode::active(
          @lib.TableIdx::new(1U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(4U)]),
      ),
    ]),
  )
  .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(2U)))
  .with_data_sec(
    @lib.DataSec::new([
      @lib.Data::new(
        @lib.DataMode::active(
          @lib.MemIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        bytes_from_ints([0]),
      ),
      @lib.Data::new(
        @lib.DataMode::active(
          @lib.MemIdx::new(1U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        bytes_from_ints([1]),
      ),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(99))]),
      ),
      Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
          @lib.Instruction::drop(),
          @lib.Instruction::memory_size(@lib.MemIdx::new(1U)),
          @lib.Instruction::drop(),
          @lib.Instruction::table_size(@lib.TableIdx::new(1U)),
          @lib.Instruction::drop(),
          @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        ]),
      ),
      Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(7)),
        ]),
      ),
    ]),
  )
  .with_name_sec(
    @lib.NameSec::new(
      func_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::new("keep_import")),
          @lib.NameAssoc::new(1U, @lib.Name::new("dead_import")),
          @lib.NameAssoc::new(2U, @lib.Name::new("dead")),
          @lib.NameAssoc::new(3U, @lib.Name::new("keep")),
          @lib.NameAssoc::new(4U, @lib.Name::new("helper")),
        ]),
      ),
      table_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::new("dead_table")),
          @lib.NameAssoc::new(1U, @lib.Name::new("live_table")),
        ]),
      ),
      memory_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::new("dead_mem")),
          @lib.NameAssoc::new(1U, @lib.Name::new("live_mem")),
        ]),
      ),
      global_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::new("dead_global")),
          @lib.NameAssoc::new(1U, @lib.Name::new("live_global")),
        ]),
      ),
      elem_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::new("dead_elem")),
          @lib.NameAssoc::new(1U, @lib.Name::new("live_elem")),
        ]),
      ),
      data_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::new("dead_data")),
          @lib.NameAssoc::new(1U, @lib.Name::new("live_data")),
        ]),
      ),
    ),
  )
}

///|
fn fixture_hso_struct_fields(field_count : Int) -> Array[@lib.FieldType] {
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
fn fixture_hso_nonlocal_readonly_prefix_module() -> Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(fixture_hso_struct_fields(1)),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      Func::new(
        @lib.Locals::from_types([ref_type]),
        @lib.Expr::new([
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
        ]),
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
}

///|
fn fixture_hso_tee_nonlocal_readonly_prefix_module() -> Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(fixture_hso_struct_fields(1)),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      Func::new(
        @lib.Locals::from_types([ref_type]),
        @lib.Expr::new([
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
        ]),
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
}

///|
fn fixture_hso_tee_pure_block_prefix_module() -> Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(fixture_hso_struct_fields(1)),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      Func::new(
        @lib.Locals::from_types([ref_type]),
        @lib.Expr::new([
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
        ]),
      ),
    ]),
  )
}

///|
fn fixture_hso_tee_pure_block_prefix_ref_result_module() -> Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(fixture_hso_struct_fields(1)),
    ),
  )
  let pair = @lib.TypeIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [ref_type])),
  )
  let local0 = @lib.LocalIdx::new(0U)
  Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      Func::new(
        @lib.Locals::from_types([ref_type]),
        @lib.Expr::new([
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
        ]),
      ),
    ]),
  )
}

///|
fn fixture_hso_direct_pure_block_prefix_module() -> Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(fixture_hso_struct_fields(1)),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      Func::new(
        @lib.Locals::from_types([ref_type]),
        @lib.Expr::new([
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
        ]),
      ),
    ]),
  )
}

///|
fn fixture_hso_direct_pure_block_prefix_ref_result_module() -> Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(fixture_hso_struct_fields(1)),
    ),
  )
  let pair = @lib.TypeIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [ref_type])),
  )
  let local0 = @lib.LocalIdx::new(0U)
  Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      Func::new(
        @lib.Locals::from_types([ref_type]),
        @lib.Expr::new([
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
        ]),
      ),
    ]),
  )
}

///|
fn fixture_hso_branch_fold_module() -> Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(fixture_hso_struct_fields(1)),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      Func::new(
        @lib.Locals::from_types([ref_type]),
        @lib.Expr::new([
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
        ]),
      ),
    ]),
  )
}

///|
fn fixture_hso_local_branch_trim_module() -> Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(fixture_hso_struct_fields(1)),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      Func::new(
        @lib.Locals::from_types([ref_type]),
        @lib.Expr::new([
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
        ]),
      ),
    ]),
  )
}

///|
fn fixture_hso_memory_branch_fold_module() -> Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(fixture_hso_struct_fields(1)),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      Func::new(
        @lib.Locals::from_types([ref_type]),
        @lib.Expr::new([
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
        ]),
      ),
    ]),
  )
  .with_mem_sec(
    @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
  )
}

///|
fn fixture_hso_tee_memory_branch_fold_ref_result_module() -> Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(fixture_hso_struct_fields(1)),
    ),
  )
  let pair = @lib.TypeIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [ref_type])),
  )
  let local0 = @lib.LocalIdx::new(0U)
  Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      Func::new(
        @lib.Locals::from_types([ref_type]),
        @lib.Expr::new([
          @lib.Instruction::struct_new_default(pair),
          @lib.Instruction::local_tee(local0),
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
        ]),
      ),
    ]),
  )
  .with_mem_sec(
    @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
  )
}

///|
fn fixture_hso_nested_branch_trim_ref_result_module() -> Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(fixture_hso_struct_fields(1)),
    ),
  )
  let pair = @lib.TypeIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [ref_type])),
  )
  let local0 = @lib.LocalIdx::new(0U)
  Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      Func::new(
        @lib.Locals::from_types([ref_type]),
        @lib.Expr::new([
          @lib.Instruction::struct_new_default(pair),
          @lib.Instruction::local_set(local0),
          @lib.Instruction::local_get(local0),
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
          @lib.Instruction::local_get(local0),
        ]),
      ),
    ]),
  )
}

///|
fn fixture_hso_loop_exit_trim_ref_result_module() -> Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(fixture_hso_struct_fields(1)),
    ),
  )
  let pair = @lib.TypeIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [ref_type])),
  )
  let local0 = @lib.LocalIdx::new(0U)
  Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      Func::new(
        @lib.Locals::from_types([ref_type]),
        @lib.Expr::new([
          @lib.Instruction::struct_new_default(pair),
          @lib.Instruction::local_set(local0),
          @lib.Instruction::local_get(local0),
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
          @lib.Instruction::local_get(local0),
        ]),
      ),
    ]),
  )
}

///|
fn fixture_hso_swapped_nonlocal_readonly_prefix_module() -> Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(fixture_hso_struct_fields(1)),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      Func::new(
        @lib.Locals::from_types([ref_type]),
        @lib.Expr::new([
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
        ]),
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
}

///|
fn fixture_hso_memory_size_value_prefix_module() -> Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(fixture_hso_struct_fields(1)),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let pair = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      Func::new(
        @lib.Locals::from_types([ref_type]),
        @lib.Expr::new([
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
        ]),
      ),
    ]),
  )
  .with_mem_sec(
    @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
  )
}

///|
fn fixture_hso_memory_size_ref_prefix_wasm() -> Bytes {
  bytes_from_ints([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 9, 2, 95, 1, 127, 1, 96, 0, 1, 127, 3, 2, 1,
    1, 5, 3, 1, 0, 1, 7, 5, 1, 1, 102, 0, 0, 10, 29, 1, 27, 1, 1, 99, 0, 251, 1,
    0, 33, 0, 32, 0, 63, 0, 26, 65, 7, 251, 5, 0, 0, 32, 0, 251, 2, 0, 0, 11,
  ])
}

///|
fn fixture_hso_pure_ref_prefix_ref_result_wasm() -> Bytes {
  bytes_from_ints([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 10, 2, 95, 1, 127, 1, 96, 0, 1, 99, 0, 3, 2,
    1, 1, 10, 25, 1, 23, 1, 1, 99, 0, 251, 1, 0, 33, 0, 32, 0, 65, 0, 26, 65, 7,
    251, 5, 0, 0, 32, 0, 11,
  ])
}

///|
fn fixture_hso_tee_pure_ref_prefix_ref_result_wasm() -> Bytes {
  bytes_from_ints([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 10, 2, 95, 1, 127, 1, 96, 0, 1, 99, 0, 3, 2,
    1, 1, 10, 23, 1, 21, 1, 1, 99, 0, 251, 1, 0, 34, 0, 65, 0, 26, 65, 7, 251, 5,
    0, 0, 32, 0, 11,
  ])
}

///|
fn fixture_hso_swapped_inner_branch_prefix_ref_result_wasm() -> Bytes {
  bytes_from_ints([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 10, 2, 95, 1, 127, 1, 96, 0, 1, 99, 0, 3, 2,
    1, 1, 7, 5, 1, 1, 102, 0, 0, 10, 44, 1, 42, 2, 1, 99, 0, 1, 127, 251, 1, 0, 33,
    0, 2, 64, 65, 9, 33, 1, 11, 32, 0, 2, 127, 65, 0, 26, 2, 127, 65, 7, 12, 0, 65,
    8, 11, 11, 251, 5, 0, 0, 32, 0, 11, 0, 26, 4, 110, 97, 109, 101, 3, 13, 1, 0,
    2, 1, 1, 118, 2, 5, 105, 110, 110, 101, 114, 4, 4, 1, 0, 1, 115,
  ])
}

///|
fn fixture_hso_nested_if_tail_ref_result_wasm() -> Bytes {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(fixture_hso_struct_fields(1)),
    ),
  )
  let pair = @lib.TypeIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [ref_type])),
  )
  let local0 = @lib.LocalIdx::new(0U)
  encode_module_fixture_bytes(
    Module::new()
    .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::new("f"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        Func::new(
          @lib.Locals::from_types([ref_type]),
          @lib.Expr::new([
            @lib.Instruction::struct_new_default(pair),
            @lib.Instruction::local_set(local0),
            @lib.Instruction::local_get(local0),
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
            @lib.Instruction::struct_set(pair, @lib.U32(0U)),
            @lib.Instruction::local_get(local0),
          ]),
        ),
      ]),
    ),
  )
}

///|
fn fixture_hso_wrapped_ref_if_branch_prefix_ref_result_wasm() -> Bytes {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_(fixture_hso_struct_fields(1)),
    ),
  )
  let pair = @lib.TypeIdx::new(0U)
  let ref_type = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [ref_type])),
  )
  let local0 = @lib.LocalIdx::new(0U)
  encode_module_fixture_bytes(
    Module::new()
    .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::new("f"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        Func::new(
          @lib.Locals::from_types([ref_type]),
          @lib.Expr::new([
            @lib.Instruction::struct_new_default(pair),
            @lib.Instruction::local_set(local0),
            @lib.Instruction::block(
              @lib.BlockType::val_type(ref_type),
              @lib.Expr::new([@lib.Instruction::local_get(local0)]),
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32(0)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32(1)),
                @lib.Instruction::if_(
                  @lib.BlockType::val_type(@lib.ValType::i32()),
                  [@lib.Instruction::i32_const(@lib.I32(7))],
                  Some([@lib.Instruction::i32_const(@lib.I32(9))]),
                ),
              ]),
            ),
            @lib.Instruction::struct_set(pair, @lib.U32(0U)),
            @lib.Instruction::local_get(local0),
          ]),
        ),
      ]),
    ),
  )
}

///|
fn fixture_hso_table_size_value_prefix_wasm() -> Bytes {
  bytes_from_ints([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 9, 2, 95, 1, 127, 1, 96, 0, 1, 127, 3, 2, 1,
    1, 4, 4, 1, 112, 0, 1, 7, 5, 1, 1, 102, 0, 0, 10, 30, 1, 28, 1, 1, 99, 0, 251,
    1, 0, 33, 0, 32, 0, 252, 16, 0, 26, 65, 7, 251, 5, 0, 0, 32, 0, 251, 2, 0, 0,
    11,
  ])
}

///|
fn fixture_hso_local_value_prefix_wasm() -> Bytes {
  bytes_from_ints([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 9, 2, 95, 1, 127, 1, 96, 0, 1, 127, 3, 2, 1,
    1, 7, 5, 1, 1, 102, 0, 0, 10, 39, 1, 37, 2, 1, 99, 0, 2, 127, 65, 5, 33, 1, 65,
    6, 33, 2, 251, 1, 0, 33, 0, 32, 0, 32, 1, 26, 32, 2, 251, 5, 0, 0, 32, 0, 251,
    2, 0, 0, 11,
  ])
}

///|
fn fixture_hso_immutable_global_value_prefix_wasm() -> Bytes {
  bytes_from_ints([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 9, 2, 95, 1, 127, 1, 96, 0, 1, 127, 3, 2, 1,
    1, 6, 6, 1, 127, 0, 65, 0, 11, 7, 5, 1, 1, 102, 0, 0, 10, 29, 1, 27, 1, 1, 99,
    0, 251, 1, 0, 33, 0, 32, 0, 35, 0, 26, 65, 7, 251, 5, 0, 0, 32, 0, 251, 2, 0,
    0, 11,
  ])
}

///|
fn fixture_hso_mutable_global_value_prefix_wasm() -> Bytes {
  bytes_from_ints([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 9, 2, 95, 1, 127, 1, 96, 0, 1, 127, 3, 2, 1,
    1, 6, 6, 1, 127, 1, 65, 0, 11, 7, 5, 1, 1, 102, 0, 0, 10, 29, 1, 27, 1, 1, 99,
    0, 251, 1, 0, 33, 0, 32, 0, 35, 0, 26, 65, 7, 251, 5, 0, 0, 32, 0, 251, 2, 0,
    0, 11,
  ])
}

///|
fn fixture_mergeable_block_module() -> Module {
  let t_void = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  Module::new()
  .with_code_sec(
    CodeSec::new([
      Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32::new(9)),
              @lib.Instruction::drop(),
              @lib.Instruction::nop(),
            ]),
          ),
        ]),
      ),
    ]),
  )
  .with_type_sec(@lib.TypeSec::new([t_void]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0)]))
}

///|
fn fixture_duplicate_function_module() -> Module {
  let t_void = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  Module::new()
  .with_type_sec(@lib.TypeSec::new([t_void, t_void, t_void]))
  .with_func_sec(
    @lib.FuncSec::new([
      @lib.TypeIdx::new(0U),
      @lib.TypeIdx::new(1U),
      @lib.TypeIdx::new(2U),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
      ),
      Func::new(@lib.Locals::empty(), @lib.Expr::new([@lib.Instruction::nop()])),
      Func::new(@lib.Locals::empty(), @lib.Expr::new([@lib.Instruction::nop()])),
    ]),
  )
}

///|
fn fixture_remove_unused_module_elements_module() -> Module {
  let t_void = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  Module::new()
  .with_type_sec(@lib.TypeSec::new([t_void]))
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("run"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
    ]),
  )
}

///|
fn fixture_rume_noop_module() -> Module {
  let t_void = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  Module::new()
  .with_type_sec(@lib.TypeSec::new([t_void]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("run"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
    ]),
  )
}

///|
fn run_optimize_wat_fixture_regression(
  path : String,
  wat_text : String,
  lowered_wasm? : Bytes? = None,
) -> Unit raise {
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(candidate) { candidate == path },
    list_candidates=fn() { [path] },
    read_file=fn(candidate) {
      if candidate == path {
        Ok(bytes_from_string(wat_text))
      } else {
        Err("missing fixture")
      }
    },
    lower_text_module=fn(candidate, _, _) {
      match lowered_wasm {
        Some(wasm) if candidate == path => Ok(wasm)
        _ => Err("text lowering not configured")
      }
    },
    write_file=fn(out_path, bytes) {
      writes.push((out_path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(["--optimize", "--out", "out.wasm", path], io) {
    Ok(v) => v
    Err(e) => fail("expected --optimize success for \{path}, got \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["optimize"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, "out.wasm")
  ignore(decode_module_bytes(writes[0].1))
}

///|
test "run_cmd_with_adapter --optimize handles examples/modules/simple.wat" {
  let wat =
    #|(module
    #|  (func (export "add_then_shift") (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    i32.add
    #|    i32.const 1
    #|    i32.shl))
  run_optimize_wat_fixture_regression("examples/modules/simple.wat", wat)
}

///|
test "run_cmd_with_adapter --optimize handles structured control fixture" {
  let wat =
    #|(module
    #|  (func (export "select_const") (param i32) (result i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 1
    #|    else
    #|      i32.const 2
    #|    end))
  run_optimize_wat_fixture_regression("examples/modules/branching.wat", wat)
}

///|
test "run_cmd_with_adapter --optimize handles examples/modules/table_dispatch.wat" {
  let wat =
    #|(module
    #|  (type $unary (func (param i32) (result i32)))
    #|  (table 2 funcref)
    #|
    #|  (func $inc (type $unary) (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add)
    #|
    #|  (func $dec (type $unary) (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 1
    #|    i32.sub)
    #|
    #|  (elem (i32.const 0) func $inc $dec)
    #|
    #|  (func (export "dispatch") (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    call_indirect (type $unary)))
  run_optimize_wat_fixture_regression(
    "examples/modules/table_dispatch.wat", wat,
  )
}

///|
test "run_cmd_with_adapter --optimize removes nop-heavy arithmetic fixtures" {
  let wat =
    #|(module
    #|  (func (export "sum") (result i32)
    #|    nop
    #|    i32.const 2
    #|    i32.const 5
    #|    i32.add))
  run_optimize_wat_fixture_regression("examples/modules/nop_cleanup.wat", wat)
}

///|
fn has_string(values : Array[String], needle : String) -> Bool {
  values.contains(needle)
}

///|
test "run_cmd_with_adapter infers optimize preset from -O level flags" {
  let wasm = encode_module_bytes(fixture_i32_const_module(31))
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(["-O3", "--out", "out.wasm", "a.wasm"], io) {
    Ok(v) => v
    Err(e) => fail("expected -O3 success, got \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["optimize"])
  @debug.assert_eq(summary.optimize_level, 3)
  @debug.assert_eq(summary.shrink_level, 0)
  @debug.assert_eq(summary.output_files, ["out.wasm"])
  @debug.assert_eq(writes.length(), 1)
  ignore(decode_module_bytes(writes[0].1))
}

///|
test "run_cmd_with_adapter infers shrink preset from -O level with z bias" {
  let wasm = encode_module_bytes(fixture_i32_const_module(32))
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(["-O3z", "--out", "out.wasm", "a.wasm"], io) {
    Ok(v) => v
    Err(e) => fail("expected -O3z success, got \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["shrink"])
  @debug.assert_eq(summary.optimize_level, 3)
  @debug.assert_eq(summary.shrink_level, 3)
  @debug.assert_eq(summary.output_files, ["out.wasm"])
  @debug.assert_eq(writes.length(), 1)
  ignore(decode_module_bytes(writes[0].1))
}

///|
test "run_cmd_with_adapter O4z preserves transitive function type equivalence" {
  let wat =
    #|(module
    #|  (type $s0 (func (param i32)))
    #|  (type $s1 (func (param i32 (ref $s0))))
    #|  (type $s2 (func (param i32 (ref $s0))))
    #|  (type $t1 (func (param (ref $s1))))
    #|  (type $t2 (func (param (ref $s2))))
    #|  (table 4 4 funcref)
    #|  (elem (i32.const 0) func $f1 $f2 $s1 $s2)
    #|  (func $s1 (type $s1) (param i32 (ref $s0)))
    #|  (func $s2 (type $s2) (param i32 (ref $s0)))
    #|  (func $f1 (type $t1) (param (ref $s1)))
    #|  (func $f2 (type $t2) (param (ref $s2)))
    #|  (func (export "run")
    #|    ref.func $s1
    #|    i32.const 0
    #|    call_indirect (type $t1)
    #|    ref.func $s1
    #|    i32.const 1
    #|    call_indirect (type $t1)
    #|    ref.func $s2
    #|    i32.const 0
    #|    call_indirect (type $t1)
    #|    ref.func $s2
    #|    i32.const 1
    #|    call_indirect (type $t1)
    #|    ref.func $s1
    #|    i32.const 0
    #|    call_indirect (type $t2)
    #|    ref.func $s1
    #|    i32.const 1
    #|    call_indirect (type $t2)
    #|    ref.func $s2
    #|    i32.const 0
    #|    call_indirect (type $t2)
    #|    ref.func $s2
    #|    i32.const 1
    #|    call_indirect (type $t2)))
  let input = @passes.pass_test_module_from_wat(wat)
  let wasm = encode_module_bytes(input)
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match run_cmd_with_adapter(["-O4z", "--out", "out.wasm", "a.wasm"], io) {
    Ok(_) => ()
    Err(err) =>
      fail("expected transitive type-equivalence O4z success, got \{err}")
  }
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected valid transitive type-equivalence output: \{err}")
  }
  let run = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(run.contains("unreachable"), msg=run)
  match optimized.code_sec {
    Some(@lib.CodeSec([_])) => ()
    _ => fail("expected one returning function after O4z")
  }
}

///|
test "O4z final cleanup removes explicit empty void else arms" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], []),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [@lib.Instruction::nop()],
              Some([]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr([@lib.LocalGet(_), @lib.If(_, [@lib.Nop], None)])
          ),
        ]
      )
    ) => ()
    _ =>
      fail(
        "expected empty void else arm to be omitted: \{optimized.pretty_print_func(@lib.FuncIdx::new(0U))}",
      )
  }
}

///|
test "O4z finish reuse follows the canonicalizer changed bit" {
  assert_true(cmd_o4z_can_reuse_precanonical_finish(false))
  assert_false(cmd_o4z_can_reuse_precanonical_finish(true))
}

///|
test "O4z finish reuse skips the second finish roster for unchanged NaN candidates" {
  for input in [fixture_f32_nan_module(), fixture_f64_nan_module()] {
    let (finish_input, changed) = @passes.o4z_canonicalize_final_size_candidate_with_changed(
      input,
    )
    assert_false(changed)
    let mut finish_invocations = 0
    let selected = cmd_o4z_choose_precanonical_finish(
      finish_input,
      changed,
      Some(input),
      fn(candidate) {
        finish_invocations = finish_invocations + 1
        Some(candidate)
      },
    )
    @debug.assert_eq(finish_invocations, 0)
    assert_true(selected is Some(_))
  }
}

///|
test "O4z canonicalizer reports real final-candidate mutations" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (export \"f\") nop))",
  )
  let (_, changed) = @passes.o4z_canonicalize_final_size_candidate_with_changed(
    input,
  )
  assert_true(changed)
}

///|
test "O4z size portfolio selects the shortest encoded candidate stably" {
  let first = bytes_from_ints([0, 1, 2])
  let second = bytes_from_ints([3, 4])
  let tied = bytes_from_ints([5, 6])
  let (label, selected) = cmd_choose_smallest_encoded_candidate([
    ("first", first),
    ("second", second),
    ("tied", tied),
  ])
  @debug.assert_eq(label, "second")
  @debug.assert_eq(selected, second)
}

///|
test "O4z size portfolio is limited to Wasm shrink presets" {
  assert_true(
    cmd_o4z_size_portfolio_enabled(CliInputFormat::wasm(), 4, 4, ["shrink"]),
  )
  assert_false(
    cmd_o4z_size_portfolio_enabled(CliInputFormat::wat(), 4, 4, ["shrink"]),
  )
  assert_false(
    cmd_o4z_size_portfolio_enabled(CliInputFormat::wasm(), 3, 3, ["shrink"]),
  )
  assert_false(
    cmd_o4z_size_portfolio_enabled(CliInputFormat::wasm(), 4, 4, ["vacuum"]),
  )
  assert_true(
    cmd_o4z_size_portfolio_enabled(CliInputFormat::wasm(), 4, 4, [
      "optimize", "shrink",
    ]),
  )
  assert_false(
    cmd_o4z_size_portfolio_enabled(CliInputFormat::wasm(), 4, 4, [
      "shrink", "vacuum",
    ]),
  )
  assert_false(
    cmd_o4z_size_portfolio_enabled(CliInputFormat::wasm(), 4, 4, [
      "optimize", "coalesce-locals",
    ]),
  )
}

///|
test "O4z size portfolio bounds late cleanup on compressed and artifact-scale modules" {
  assert_false(cmd_o4z_late_cleanup_candidate_enabled(837, 118, 1))
  assert_true(cmd_o4z_late_cleanup_candidate_enabled(626, 420, 1))
  assert_true(cmd_o4z_late_cleanup_candidate_enabled(28208, 25407, 50))
  assert_false(cmd_o4z_late_cleanup_candidate_enabled(4977401, 5000000, 2000))
  assert_false(cmd_o4z_late_cleanup_candidate_enabled(4977401, 5000000, 9264))
}

///|
test "run_cmd_with_adapter O4z keeps a smaller valid input candidate" {
  let wasm = encode_module_bytes(fixture_i32_const_module(32))
  let inflated = bytes_from_ints([
    0, 97, 115, 109, 1, 0, 0, 0, 0, 10, 8, 105, 110, 102, 108, 97, 116, 101, 100,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ])
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    encode_module=fn(_) { Ok(inflated) },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match run_cmd_with_adapter(["-O4z", "--out", "out.wasm", "a.wasm"], io) {
    Ok(_) => ()
    Err(err) => fail("expected O4z portfolio success, got \{err}")
  }
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].1, wasm)
}

///|
test "run_cmd_with_adapter mixed O4z queues do not enable the size portfolio" {
  let input = @passes.pass_test_module_from_wat("(module (func nop))")
  let wasm = encode_module_bytes(input)
  let inflated = bytes_from_ints([
    0, 97, 115, 109, 1, 0, 0, 0, 0, 12, 10, 109, 105, 120, 101, 100, 45, 113, 117,
    101, 117, 101, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ])
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    encode_module=fn(_) { Ok(inflated) },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["-O4z", "--shrink", "--vacuum", "--out", "out.wasm", "a.wasm"],
      io,
    ) {
    Ok(summary) => summary
    Err(err) => fail("expected mixed O4z queue success, got \{err}")
  }
  @debug.assert_eq(summary.resolved_passes, ["shrink", "vacuum"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].1, inflated)
}

///|
test "O4z size portfolio admits validated global-refining cleanup" {
  let input = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (type $f_t (func (param i32) (result i32)))
      #|  (import "M" "f" (func $f (type $f_t)))
      #|  (table 1 funcref)
      #|  (global $g (mut funcref) (ref.func $f))
      #|  (func $other (type $f_t) (param i32) (result i32)
      #|    local.get 0 i32.const 1 i32.add)
      #|  (elem declare func $f $other)
      #|  (func $zero (export "zero") (result i32) i32.const 0)
      #|  (func $is-null (export "is-null") (result i32)
      #|    global.get $g ref.is_null)
      #|  (func (export "set-f") ref.func $f global.set $g)
      #|  (func (export "set-other") ref.func $other global.set $g))
      #|,
    ),
  )
  let wasm = encode_module_bytes(input)
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match run_cmd_with_adapter(["-O4z", "--out", "out.wasm", "a.wasm"], io) {
    Ok(_) => ()
    Err(err) => fail("expected global-refining O4z cleanup, got \{err}")
  }
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  match optimized.global_sec {
    Some(@lib.GlobalSec([@lib.Global(global_type, _)])) =>
      @debug.assert_eq(
        global_type,
        @lib.GlobalType::new(
          @lib.ValType::ref_type(
            @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
          ),
          true,
        ),
      )
    other => fail("expected one refined global, got \{other}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => @debug.assert_eq(funcs.length(), 4)
    None => fail("expected optimized functions")
  }
  let text = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(text.contains("global.get"), msg=text)
  assert_false(text.contains("ref.is_null"), msg=text)
  assert_true(text.contains("I32(0)"), msg=text)
}

///|
test "O4z size portfolio canonicalizes unbranched block wrappers" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) (result i32) block local.get 0 drop end block (result i32) local.get 0 end))",
  )
  let before = encode_module_bytes(input)
  let canonical = @passes.o4z_canonicalize_final_size_candidate(input)
  match @validate.validate_module(canonical) {
    Ok(_) => ()
    Err(err) =>
      fail("expected block-canonicalized candidate to validate, got \{err}")
  }
  let after = encode_module_bytes(canonical)
  assert_true(after.length() < before.length())
  match canonical.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ])
    other =>
      fail("expected flattened size candidate, got \{@debug.to_string(other)}")
  }
}

///|
test "O4z size portfolio preserves branch-targeted blocks" {
  let input = @passes.pass_test_module_from_wat("(module (func (block br 0)))")
  let canonical = @passes.o4z_canonicalize_final_size_candidate(input)
  @debug.assert_eq(canonical, input)
}

///|
test "O4z size portfolio removes dead suffixes after unconditional branches" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) block local.get 0 drop br 0 i32.const 99 drop end))",
  )
  let canonical = @passes.o4z_canonicalize_final_size_candidate(input)
  let pretty = canonical.pretty_print_defined_func(0U)
  assert_true(pretty.contains("br (Label 0)"), msg=pretty)
  assert_false(pretty.contains("I32(99)"), msg=pretty)
}

///|
test "O4z size portfolio preserves fallthrough after conditional branches" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) block local.get 0 br_if 0 i32.const 99 drop end))",
  )
  let canonical = @passes.o4z_canonicalize_final_size_candidate(input)
  let pretty = canonical.pretty_print_defined_func(0U)
  assert_true(pretty.contains("br_if (Label 0)"), msg=pretty)
  assert_true(pretty.contains("I32(99)"), msg=pretty)
}

///|
test "O4z size portfolio carries repeated local reads across an exact store shell" {
  let input = @passes.pass_test_module_from_wat(
    "(module (memory 1) (func (param i32 i32) (result i32) (local i32) i32.const 7 local.set 2 local.get 0 local.get 1 i32.const 4 i32.add i32.store local.get 2 local.get 2 i32.add))",
  )
  let canonical = @passes.o4z_canonicalize_final_size_candidate(input)
  match @validate.validate_module(canonical) {
    Ok(_) => ()
    Err(err) => fail("expected carried-store candidate to validate, got \{err}")
  }
  let pretty = canonical.pretty_print_defined_func(0U)
  assert_true(pretty.contains("local.tee (Local 2)"), msg=pretty)
  @debug.assert_eq(
    count_substring(pretty, "local.get (Local 2)"),
    1,
    msg=pretty,
  )
  assert_true(
    encode_module_bytes(canonical).length() <
    encode_module_bytes(input).length(),
  )
}

///|
test "O4z size portfolio combines bounded consecutive constant shifts" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 i32.const 1 i32.shl i32.const 2 i32.shl) (func (param i32) (result i32) local.get 0 i32.const 31 i32.shl i32.const 1 i32.shl))",
  )
  let canonical = @passes.o4z_canonicalize_final_size_candidate(input)
  match canonical.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(first)), _])) =>
      @debug.assert_eq(first, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(3),
        @lib.Instruction::i32_shl(),
      ])
    other =>
      fail(
        "expected bounded consecutive-shift canonicalization, got \{@debug.to_string(other)}",
      )
  }
  let second_text = canonical.pretty_print_defined_func(1U)
  @debug.assert_eq(count_substring(second_text, "i32.shl"), 2)
  assert_true(
    encode_module_bytes(canonical).length() <
    encode_module_bytes(input).length(),
  )
}

///|
test "O4z size portfolio folds exact same-local and negated integer comparisons" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32 i32 i64) (result i32) local.get 0 local.get 0 i32.ne drop local.get 2 local.get 2 i64.ge_u drop local.get 0 local.get 1 i32.gt_u i32.eqz drop local.get 0 local.get 1 i32.eq))",
  )
  let canonical = @passes.o4z_canonicalize_final_size_candidate(input)
  let pretty = canonical.pretty_print_defined_func(0U)
  assert_false(pretty.contains("i32.ne"), msg=pretty)
  assert_false(pretty.contains("i64.ge_u"), msg=pretty)
  assert_false(pretty.contains("i32.gt_u"), msg=pretty)
  assert_false(pretty.contains("i32.eqz"), msg=pretty)
  assert_true(pretty.contains("i32.le_u"), msg=pretty)
  assert_true(pretty.contains("i32.eq"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(
    encode_module_bytes(canonical).length() <
    encode_module_bytes(input).length(),
  )
}

///|
test "O4z size portfolio removes zero-ne booleanization at control consumers" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) block local.get 0 i32.const 0 i32.ne br_if 0 local.get 0 i32.const 0 i32.ne if i32.const 1 drop end end))",
  )
  let canonical = @passes.o4z_canonicalize_final_size_candidate(input)
  let pretty = canonical.pretty_print_defined_func(0U)
  assert_false(pretty.contains("i32.ne"), msg=pretty)
  assert_false(pretty.contains("I32(0)"), msg=pretty)
  assert_true(pretty.contains("br_if (Label 0)"), msg=pretty)
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_true(
    encode_module_bytes(canonical).length() <
    encode_module_bytes(input).length(),
  )
}

///|
test "O4z size portfolio removes dropped nontrapping integer shells" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32 i64) (local i32) local.get 0 i32.const -4 i32.and drop local.get 1 i64.const 7 i64.or drop local.get 0 local.tee 2 i32.const 3 i32.and drop local.get 2 drop))",
  )
  let canonical = @passes.o4z_canonicalize_final_size_candidate(input)
  let pretty = canonical.pretty_print_defined_func(0U)
  assert_false(pretty.contains("i32.and"), msg=pretty)
  assert_false(pretty.contains("i64.or"), msg=pretty)
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_true(
    encode_module_bytes(canonical).length() <
    encode_module_bytes(input).length(),
  )
}

///|
test "O4z size portfolio preserves dropped trapping integer division" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) local.get 0 i32.const 0 i32.div_s drop))",
  )
  let canonical = @passes.o4z_canonicalize_final_size_candidate(input)
  assert_eq(canonical, input)
}

///|
test "O4z size portfolio collapses dropped result-block select shells" {
  let input = @passes.pass_test_module_from_wat(
    "(module (memory 1) (func (param i32) block (result i32) i32.const 0 local.get 0 i32.eqz br_if 0 drop i32.const 0 local.get 0 local.get 0 i32.load8_u i32.const 1 i32.and select end drop))",
  )
  let canonical = @passes.o4z_canonicalize_final_size_candidate(input)
  let pretty = canonical.pretty_print_defined_func(0U)
  assert_false(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("i32.and"), msg=pretty)
  assert_true(pretty.contains("i32.load8u"), msg=pretty)
  assert_true(pretty.contains("br_if (Label 0)"), msg=pretty)
  assert_true(
    encode_module_bytes(canonical).length() <
    encode_module_bytes(input).length(),
  )
}

///|
test "O4z size portfolio preserves observable result-block select shells" {
  let input = @passes.pass_test_module_from_wat(
    "(module (memory 1) (func (param i32) (result i32) block (result i32) i32.const 0 local.get 0 i32.eqz br_if 0 drop i32.const 0 local.get 0 local.get 0 i32.load8_u i32.const 1 i32.and select end))",
  )
  let canonical = @passes.o4z_canonicalize_final_size_candidate(input)
  assert_eq(canonical, input)
}

///|
test "O4z size portfolio defers dropped integer shells for 37-function stateful Emscripten candidates" {
  let wat = StringBuilder::new()
  wat.write_string(
    "(module (func (export \"_main\") (param i32) local.get 0 i32.const -4 i32.and drop) (func (export \"runPostSets\")) (func (export \"stackAlloc\")) (func (export \"stackSave\")) (func (export \"stackRestore\"))",
  )
  for idx = 5; idx < 37; idx = idx + 1 {
    wat.write_string(" (func)")
  }
  wat.write_string(")")
  let input = @passes.pass_test_module_from_wat(wat.to_string())
  let canonical = @passes.o4z_canonicalize_final_size_candidate(input)
  assert_eq(canonical, input)
}

///|
test "O4z size portfolio folds shift sign extensions in the final candidate" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 i32.const 24 i32.shl i32.const 24 i32.shr_s))",
  )
  let canonical = @passes.o4z_canonicalize_final_size_candidate(input)
  match canonical.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_extend8s(),
      ])
    other =>
      fail(
        "expected final sign-extension canonicalization, got \{@debug.to_string(other)}",
      )
  }
  assert_true(
    encode_module_bytes(canonical).length() <
    encode_module_bytes(input).length(),
  )
}

///|
test "O4z size portfolio folds boolean xor and terminal return shells" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 i32.const 1 i32.and i32.const 1 i32.xor return))",
  )
  let canonical = @passes.o4z_canonicalize_final_size_candidate(input)
  match canonical.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(1),
        @lib.Instruction::i32_and(),
        @lib.Instruction::i32_eqz(),
      ])
    other =>
      fail(
        "expected boolean and terminal-return canonicalization, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "O4z size portfolio inverts integer comparisons for empty then arms" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) (local i32) local.get 0 i32.const 7 i32.gt_u if else i32.const 1 local.set 1 end))",
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) => {
      assert_true(instrs.any(fn(instr) { instr is @lib.I32LeU }))
      match instrs.last() {
        Some(@lib.If(_, then_body, None)) => assert_false(then_body.is_empty())
        other => fail("expected inverted no-else if, got \{other}")
      }
    }
    other => fail("expected one inverted comparison function, got \{other}")
  }
}

///|
test "O4z final canonicalizer preserves nested tees read by the continuation" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.tee 1 drop end local.get 1))",
  )
  let canonical = @passes.o4z_canonicalize_final_size_candidate(input)
  let pretty = canonical.pretty_print_defined_func(0U)
  assert_true(pretty.contains("local.tee (Local 1)"), msg=pretty)
}

///|
test "O4z size portfolio removes dead intermediate local tees" {
  let removable = @passes.pass_test_module_from_wat(
    "(module (func (result i32) (local $x i32) i32.const 1 local.tee $x i32.const 2 i32.add local.set $x local.get $x))",
  )
  let removable = @passes.o4z_canonicalize_final_size_candidate(removable)
  let removable_text = removable.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(removable_text.contains("local.tee"), msg=removable_text)

  let observed = @passes.pass_test_module_from_wat(
    "(module (func (result i32) (local $x i32) i32.const 1 local.tee $x local.get $x i32.add local.set $x local.get $x))",
  )
  let observed = @passes.o4z_canonicalize_final_size_candidate(observed)
  let observed_text = observed.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(observed_text.contains("local.tee"), msg=observed_text)
}

///|
test "O4z size portfolio folds exact fresh array set and packed get" {
  let input = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x5e, 0x78,
      0x01, 0x60, 0x00, 0x01, 0x7f, 0x03, 0x02, 0x01, 0x01, 0x0a, 0x1d, 0x01, 0x1b,
      0x01, 0x01, 0x63, 0x00, 0x41, 0x01, 0xfb, 0x07, 0x00, 0x22, 0x00, 0x41, 0x00,
      0x41, 0xff, 0x01, 0xfb, 0x0e, 0x00, 0x20, 0x00, 0x41, 0x00, 0xfb, 0x0c, 0x00,
      0x0b,
    ]),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [@lib.Instruction::i32_const(@lib.I32::new(-1))])
    other => fail("expected exact packed array constant, got \{other}")
  }
}

///|
test "O4z final cleanup sign-extends positive packed bit patterns" {
  let fixtures = [
    (@lib.PackType::i8(), @lib.I32(128), @lib.I32(-128)),
    (@lib.PackType::i16(), @lib.I32(32768), @lib.I32(-32768)),
  ]
  for fixture in fixtures {
    let array = @lib.TypeIdx::new(0U)
    let func_type = @lib.TypeIdx::new(1U)
    let input = @lib.Module::new()
      .with_type_sec(
        @lib.TypeSec::new([
          @lib.RecType::new(
            @lib.SubType::comp_type(
              @lib.CompType::array(
                @lib.FieldType::new(
                  @lib.StorageType::pack_type(fixture.0),
                  @lib.Mut::var_(),
                ),
              ),
            ),
          ),
          @lib.RecType::new(
            @lib.SubType::comp_type(
              @lib.CompType::func([], [@lib.ValType::i32()]),
            ),
          ),
        ]),
      )
      .with_func_sec(@lib.FuncSec::new([func_type]))
      .with_code_sec(
        @lib.CodeSec::new([
          @lib.Func::new(
            @lib.Locals::from_types([
              @lib.ValType::ref_null(@lib.HeapType::new(array)),
            ]),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::array_new_default(array),
              @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
              @lib.Instruction::i32_const(@lib.I32(0)),
              @lib.Instruction::i32_const(fixture.1),
              @lib.Instruction::array_set(array),
              @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
              @lib.Instruction::i32_const(@lib.I32(0)),
              @lib.Instruction::array_get_s(array),
            ]),
          ),
        ]),
      )
    let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
    match optimized.code_sec {
      Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
        @debug.assert_eq(instrs, [@lib.Instruction::i32_const(fixture.2)])
      other => fail("expected signed packed constant, got \{other}")
    }
  }
}

///|
test "O4z size portfolio removes proven-success constant assert calls" {
  let input = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (func $assert (param i32 i32)
      #|    local.get 0 local.get 1 i32.eq
      #|    if return end
      #|    unreachable)
      #|  (func
      #|    i32.const 1 i32.const 1 call $assert
      #|    i32.const 0 i32.const 0 call $assert))
      #|,
    ),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([_, @lib.Func(_, @lib.Expr(instrs))])) =>
      assert_false(instrs.any(fn(instr) { instr is @lib.Call(_) }))
    other => fail("expected constant assert fixture, got \{other}")
  }
}

///|
test "Wasm encoding recursively strips semantic nops" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func nop block i32.const 1 drop nop end loop i32.const 2 drop nop end i32.const 1 if nop else nop end))",
  )
  let normalized = cmd_strip_nops_for_encoding(input)
  let pretty = normalized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("nop"), msg=pretty)
  assert_false(pretty.contains("(block"), msg=pretty)
  assert_false(pretty.contains("(loop"), msg=pretty)
}

///|
test "Wasm encoding shell scan covers catch and continuation label metadata" {
  let tag = @lib.TagIdx::new(0U)
  let target = @lib.LabelIdx::new(0U)
  let catch_forms : Array[@lib.Catch] = [
    @lib.Catch::new(tag, target),
    @lib.Catch::ref_(tag, target),
    @lib.Catch::all(target),
    @lib.Catch::all_ref(target),
  ]
  for catch_ in catch_forms {
    assert_true(
      cmd_instrs_reference_control_shell_for_encoding([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [catch_],
          @lib.Expr::new([]),
        ),
      ]),
    )
  }
  assert_false(
    cmd_instrs_reference_control_shell_for_encoding([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::try_table(
            @lib.BlockType::void_(),
            [@lib.Catch::all(target)],
            @lib.Expr::new([]),
          ),
        ]),
      ),
    ]),
  )
  assert_true(
    cmd_instrs_reference_control_shell_for_encoding([
      @lib.Instruction::resume_(@lib.TypeIdx::new(0U), [
        @lib.ResumeHandler::on_label(tag, target),
      ]),
    ]),
  )
  assert_false(
    cmd_instrs_reference_control_shell_for_encoding([
      @lib.Instruction::resume_(@lib.TypeIdx::new(0U), [
        @lib.ResumeHandler::on_switch(tag),
      ]),
    ]),
  )
}

///|
test "Wasm encoding nop normalization reuses unchanged instruction arrays" {
  let instrs = [
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::drop()],
      None,
    ),
  ]
  let (rewritten, changed) = cmd_strip_nops_in_instrs_for_encoding(instrs)
  assert_false(changed)
  rewritten[0] = @lib.Instruction::i32_const(@lib.I32::new(2))
  @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(@lib.I32::new(2)))
}

///|
test "Wasm encoding preserves a block targeted by try_table catch metadata" {
  let input = encoding_label_fixture([
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::all(@lib.LabelIdx::new(0U))],
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32::new(7)),
  ])
  let output = assert_encoding_pipeline_roundtrip_valid(input)
  match output.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.Block(
                  _,
                  @lib.Expr(
                    [@lib.TryTable(_, [@lib.CatchAll(@lib.LabelIdx(0U))], _)]
                  )
                ),
                @lib.I32Const(@lib.I32(7)),
              ]
            )
          ),
        ]
      )
    ) => ()
    other =>
      fail("expected catch-targeted block to survive encoding, got \{other}")
  }
}

///|
test "Wasm encoding preserves a loop targeted by try_table catch metadata" {
  let input = encoding_label_fixture([
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::all(@lib.LabelIdx::new(0U))],
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32::new(7)),
  ])
  let output = assert_encoding_pipeline_roundtrip_valid(input)
  match output.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.Loop(
                  _,
                  @lib.Expr(
                    [@lib.TryTable(_, [@lib.CatchAll(@lib.LabelIdx(0U))], _)]
                  )
                ),
                @lib.I32Const(@lib.I32(7)),
              ]
            )
          ),
        ]
      )
    ) => ()
    other =>
      fail("expected catch-targeted loop to survive encoding, got \{other}")
  }
}

///|
test "Wasm encoding preserves nested shells crossed by a try_table catch target" {
  let input = encoding_label_fixture([
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::try_table(
              @lib.BlockType::void_(),
              [@lib.Catch::all(@lib.LabelIdx::new(1U))],
              @lib.Expr::new([@lib.Instruction::nop()]),
            ),
          ]),
        ),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32::new(7)),
  ])
  let output = assert_encoding_pipeline_roundtrip_valid(input)
  match output.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.Block(
                  _,
                  @lib.Expr(
                    [
                      @lib.Block(
                        _,
                        @lib.Expr(
                          [
                            @lib.TryTable(
                              _,
                              [@lib.CatchAll(@lib.LabelIdx(1U))],
                              _
                            ),
                          ]
                        )
                      ),
                    ]
                  )
                ),
                @lib.I32Const(@lib.I32(7)),
              ]
            )
          ),
        ]
      )
    ) => ()
    other =>
      fail("expected both crossed shells to survive encoding, got \{other}")
  }
}

///|
test "Wasm encoding preserves shells containing legacy EH branches" {
  let input = encoding_label_fixture([
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(1U))]),
          [@lib.LegacyCatch::all(@lib.Expr::new([@lib.Instruction::nop()]))],
        ),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32::new(7)),
  ])
  let output = assert_encoding_pipeline_roundtrip_valid(input)
  match output.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.Block(_, @lib.Expr([@lib.Try(_, _, _, _)])),
                @lib.I32Const(@lib.I32(7)),
              ]
            )
          ),
        ]
      )
    ) => ()
    other => fail("expected legacy-EH shell to survive encoding, got \{other}")
  }
}

///|
test "Wasm encoding strips redundant terminal function returns" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (result i32) i32.const 1 return))",
  )
  let normalized = cmd_strip_terminal_returns_for_encoding(input)
  match normalized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr([@lib.I32Const(@lib.I32(1))]))])) =>
      ()
    other => fail("expected terminal return removal, got \{other}")
  }
}

///|
test "Wasm encoding strips empty data and zero data count sections" {
  let input = @lib.Module::new(
    data_cnt_sec=Some(@lib.DataCntSec::new(@lib.U32(0U))),
    data_sec=Some(@lib.DataSec::new([])),
  )
  let normalized = cmd_strip_empty_data_sections_for_encoding(input)
  @debug.assert_eq(normalized.data_cnt_sec, None)
  @debug.assert_eq(normalized.data_sec, None)
}

///|
test "Wasm encoding strips an empty type-only standard section" {
  let input = @lib.Module::new(type_sec=Some(@lib.TypeSec::new([])))
  let normalized = cmd_strip_type_only_empty_module_for_encoding(input)
  @debug.assert_eq(normalized.type_sec, None)
}

///|
test "O4z size portfolio removes type-only empty module debris" {
  let input = @passes.pass_test_module_from_wat(
    "(module (rec (type (func)) (type (func))))",
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  @debug.assert_eq(optimized.type_sec, None)
}

///|
test "O4z size portfolio outlines constant-step recurrence siblings" {
  let input = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (func (param i32) (result i32) (local i32)
      #|    loop local.get 0 if local.get 1 i32.const 16 i32.add local.set 1 local.get 0 i32.const 1 i32.sub local.set 0 br 1 end end local.get 1)
      #|  (func (param i32) (result i32) (local i32)
      #|    loop local.get 0 if local.get 1 i32.const 32 i32.add local.set 1 local.get 0 i32.const 1 i32.sub local.set 0 br 1 end end local.get 1)
      #|  (func (param i32) (result i32) (local i32)
      #|    loop local.get 0 if local.get 1 i32.const 48 i32.add local.set 1 local.get 0 i32.const 1 i32.sub local.set 0 br 1 end end local.get 1)
      #|  (func (param i32) (result i32) (local i32)
      #|    loop local.get 0 if local.get 1 i32.const 64 i32.add local.set 1 local.get 0 i32.const 1 i32.sub local.set 0 br 1 end end local.get 1))
      #|,
    ),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), 5)
      let @lib.Func(_, @lib.Expr(first)) = funcs[0]
      assert_true(first.last() is Some(@lib.ReturnCall(_)), msg="\{first}")
    }
    None => fail("expected outlined recurrence code")
  }
}

///|
test "O4z size portfolio outlines bulk-memory constant siblings" {
  let input = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (memory 2)
      #|  (func (param i32) (result i32) loop local.get 0 if i32.const 8192 i32.const 0 i32.const 64 memory.copy local.get 0 i32.const 1 i32.sub local.set 0 br 1 end end i32.const 8192 i32.load8_u)
      #|  (func (param i32) (result i32) loop local.get 0 if i32.const 32784 i32.const 32768 i32.const 64 memory.copy local.get 0 i32.const 1 i32.sub local.set 0 br 1 end end i32.const 32784 i32.load8_u)
      #|  (func (param i32) (result i32) loop local.get 0 if i32.const 49152 i32.const 165 i32.const 64 memory.fill local.get 0 i32.const 1 i32.sub local.set 0 br 1 end end i32.const 49152 i32.load8_u)
      #|  (func (param i32) (result i32) loop local.get 0 if i32.const 8192 i32.const 0 i32.const 256 memory.copy local.get 0 i32.const 1 i32.sub local.set 0 br 1 end end i32.const 8192 i32.load8_u)
      #|  (func (param i32) (result i32) loop local.get 0 if i32.const 32784 i32.const 32768 i32.const 256 memory.copy local.get 0 i32.const 1 i32.sub local.set 0 br 1 end end i32.const 32784 i32.load8_u)
      #|  (func (param i32) (result i32) loop local.get 0 if i32.const 49152 i32.const 165 i32.const 256 memory.fill local.get 0 i32.const 1 i32.sub local.set 0 br 1 end end i32.const 49152 i32.load8_u)
      #|  (func (param i32) (result i32) loop local.get 0 if i32.const 8192 i32.const 0 i32.const 4096 memory.copy local.get 0 i32.const 1 i32.sub local.set 0 br 1 end end i32.const 8192 i32.load8_u)
      #|  (func (param i32) (result i32) loop local.get 0 if i32.const 32784 i32.const 32768 i32.const 4096 memory.copy local.get 0 i32.const 1 i32.sub local.set 0 br 1 end end i32.const 32784 i32.load8_u)
      #|  (func (param i32) (result i32) loop local.get 0 if i32.const 49152 i32.const 165 i32.const 4096 memory.fill local.get 0 i32.const 1 i32.sub local.set 0 br 1 end end i32.const 49152 i32.load8_u))
      #|,
    ),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), 11)
      let @lib.Func(_, @lib.Expr(copy_wrapper)) = funcs[0]
      let @lib.Func(_, @lib.Expr(fill_wrapper)) = funcs[2]
      assert_true(
        copy_wrapper.last() is Some(@lib.ReturnCall(_)),
        msg="\{copy_wrapper}",
      )
      assert_true(
        fill_wrapper.last() is Some(@lib.ReturnCall(_)),
        msg="\{fill_wrapper}",
      )
    }
    None => fail("expected outlined bulk-memory code")
  }
}

///|
test "O4z size portfolio outlines five-byte memory comparator siblings" {
  let input = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (type $compare (func (param i32 i32) (result i32)))
      #|  (type $check (func (param i32) (result i32)))
      #|  (memory 1)
      #|  (func $compare (type $compare) (param i32 i32) (result i32)
      #|    local.get 1 local.get 0 i32.load8_u i32.eq)
      #|  (func (type $check) (param i32) (result i32)
      #|    local.get 0 i32.const 104 call $compare
      #|    local.get 0 i32.const 1 i32.add i32.const 101 call $compare
      #|    local.get 0 i32.const 2 i32.add i32.const 108 call $compare
      #|    local.get 0 i32.const 3 i32.add i32.const 108 call $compare
      #|    local.get 0 i32.const 4 i32.add i32.const 111 call $compare
      #|    i32.and i32.and i32.and i32.and)
      #|  (func (type $check) (param i32) (result i32)
      #|    local.get 0 i32.const 111 call $compare
      #|    local.get 0 i32.const 1 i32.add i32.const 108 call $compare
      #|    local.get 0 i32.const 2 i32.add i32.const 108 call $compare
      #|    local.get 0 i32.const 3 i32.add i32.const 101 call $compare
      #|    local.get 0 i32.const 4 i32.add i32.const 104 call $compare
      #|    i32.and i32.and i32.and i32.and))
      #|,
    ),
  )
  let optimized = @passes.o4z_outline_similar_size_functions(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), 3)
      let @lib.Func(_, @lib.Expr(first_wrapper)) = funcs[1]
      let @lib.Func(_, @lib.Expr(second_wrapper)) = funcs[2]
      @debug.assert_eq(first_wrapper, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(104)),
        @lib.Instruction::i32_const(@lib.I32(101)),
        @lib.Instruction::i32_const(@lib.I32(108)),
        @lib.Instruction::i32_const(@lib.I32(111)),
        @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
      ])
      @debug.assert_eq(second_wrapper, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(111)),
        @lib.Instruction::i32_const(@lib.I32(108)),
        @lib.Instruction::i32_const(@lib.I32(101)),
        @lib.Instruction::i32_const(@lib.I32(104)),
        @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
      ])
    }
    None => fail("expected outlined memory comparators")
  }
}

///|
test "O4z final cleanup removes fences without shared state" {
  let func_type = @lib.TypeIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::atomic_fence()]),
        ),
      ]),
    )
  assert_true(@passes.o4z_size_candidate_has_unobservable_atomic_fence(input))
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) =>
      @debug.assert_eq(body, [])
    _ => fail("expected one fence-free function")
  }
}

///|
test "O4z final cleanup defaults one-field nullable structs" {
  let input = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (type $s (struct (field (ref null func))))
      #|  (func (result (ref $s)) ref.null nofunc struct.new $s))
      #|,
    ),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) =>
      @debug.assert_eq(body, [
        @lib.Instruction::struct_new_default(@lib.TypeIdx::new(0U)),
      ])
    _ => fail("expected one defaulted struct function")
  }
}

///|
test "O4z final cleanup combines split local-add constants" {
  let input = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (func (param i32) (result i32)
      #|    local.get 0
      #|    local.get 0 i32.const 150 i32.add
      #|    local.get 0 i32.const 299 i32.add
      #|    i32.add i32.add))
      #|,
    ),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) =>
      @debug.assert_eq(body, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::i32_const(@lib.I32(449)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::i32_add(),
      ])
    _ => fail("expected one reassociated add function")
  }
}

///|
test "O4z final cleanup folds constant i31 roundtrips" {
  let input = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (func (result i32) i32.const 1073741824 ref.i31 i31.get_s)
      #|  (func (result i32) i32.const -1 ref.i31 i31.get_u))
      #|,
    ),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [@lib.Func(_, @lib.Expr(signed)), @lib.Func(_, @lib.Expr(unsigned))]
      )
    ) => {
      @debug.assert_eq(signed, [
        @lib.Instruction::i32_const(@lib.I32(-1073741824)),
      ])
      @debug.assert_eq(unsigned, [
        @lib.Instruction::i32_const(@lib.I32(2147483647)),
      ])
    }
    _ => fail("expected two folded i31 functions")
  }
}

///|
test "O4z final cleanup respells positive signed-LEB additions" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 i32.const 64 i32.add))",
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) =>
      @debug.assert_eq(body, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(-64)),
        @lib.Instruction::i32_sub(),
      ])
    _ => fail("expected one signed-LEB optimized function")
  }
}

///|
test "O4z final cleanup removes overwritten ref.func local initialization" {
  let input = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (type $grow (func (param i32) (result i32)))
      #|  (type $check (func (param i32 i32) (result funcref)))
      #|  (table 10 funcref)
      #|  (func (type $grow) (param i32) (result i32)
      #|    ref.null func local.get 0 table.grow)
      #|  (func $check (type $check) (param i32 i32) (result funcref)
      #|    (local funcref)
      #|    ref.func $check local.set 2
      #|    block
      #|      loop
      #|        local.get 0 table.get
      #|        local.tee 2 ref.is_null i32.eqz
      #|        local.get 0 local.get 1 i32.ge_u i32.or
      #|        br_if 1
      #|        local.get 1
      #|        local.get 0 i32.const 1 i32.add local.tee 0
      #|        i32.ge_u br_if 0
      #|      end
      #|    end
      #|    local.get 2)
      #|  (elem declare func $check))
      #|,
    ),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([_, @lib.Func(_, @lib.Expr(body))])) =>
      match body {
        [@lib.Block(_, _), ..] => ()
        _ => fail("expected overwritten initializer removal: \{body}")
      }
    _ => fail("expected two optimized functions")
  }
  @debug.assert_eq(optimized.elem_sec, None)
}

///|
test "O4z size portfolio folds proven taken two-result function exits" {
  let input = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x06, 0x01, 0x60, 0x00,
      0x02, 0x7f, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x07, 0x08, 0x01, 0x04, 0x6d, 0x61,
      0x69, 0x6e, 0x00, 0x00, 0x0a, 0x33, 0x01, 0x31, 0x00, 0x03, 0x7f, 0x41, 0x00,
      0x41, 0x01, 0x41, 0x00, 0x41, 0x01, 0x0d, 0x01, 0x0d, 0x00, 0x02, 0x7f, 0x10,
      0x00, 0x1a, 0x03, 0x00, 0x41, 0x00, 0x41, 0x01, 0x02, 0x00, 0x10, 0x00, 0x41,
      0x00, 0x0e, 0x01, 0x00, 0x04, 0x0b, 0x1a, 0x1a, 0x0b, 0x1a, 0x1a, 0x0b, 0x1a,
      0x1a, 0x0b, 0x41, 0x00, 0x0b,
    ]),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_const(@lib.I32(0)),
      ])
    other => fail("expected constant two-result function body, got \{other}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected folded two-result function to validate, got \{err}")
  }
  let cleaned = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x06, 0x01, 0x60, 0x00,
      0x02, 0x7f, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x07, 0x08, 0x01, 0x04, 0x6d, 0x61,
      0x69, 0x6e, 0x00, 0x00, 0x0a, 0x3a, 0x01, 0x38, 0x01, 0x02, 0x7f, 0x03, 0x7f,
      0x41, 0x01, 0x41, 0x00, 0x41, 0x01, 0x0d, 0x01, 0x0d, 0x00, 0x10, 0x00, 0x1a,
      0x03, 0x00, 0x41, 0x00, 0x41, 0x01, 0x02, 0x00, 0x10, 0x00, 0x41, 0x00, 0x0e,
      0x01, 0x00, 0x03, 0x0b, 0x21, 0x00, 0x21, 0x01, 0x1a, 0x1a, 0x20, 0x01, 0x20,
      0x00, 0x0b, 0x1a, 0x1a, 0x1a, 0x1a, 0x41, 0x00, 0x0b, 0x41, 0x00, 0x0b,
    ]),
  )
  let cleaned = @passes.o4z_canonicalize_final_size_candidate(cleaned)
  match cleaned.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_const(@lib.I32(0)),
      ])
    other => fail("expected cleaned constant two-result body, got \{other}")
  }
}

///|
test "O4z size portfolio folds pure-selector constant-result br_table blocks" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) (result i32) block (result i32) i32.const 2 i32.const 2 i32.const 3 local.get 0 select br_table 0 end))",
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [@lib.Instruction::i32_const(@lib.I32(2))])
    other => fail("expected constant br_table result, got \{other}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected constant br_table result to validate, got \{err}")
  }
}

///|
test "O4z size portfolio folds exact function result block spills" {
  let input = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x60, 0x00,
      0x01, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x06, 0x06, 0x01, 0x7f, 0x01, 0x41, 0x00,
      0x0b, 0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x00, 0x0a, 0x11, 0x01, 0x0f, 0x01,
      0x01, 0x7f, 0x02, 0x40, 0x23, 0x00, 0x21, 0x00, 0x0c, 0x00, 0x0b, 0x20, 0x00,
      0x0b,
    ]),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      ])
    other =>
      fail("expected exact function result block spill fold, got \{other}")
  }
}

///|
test "O4z size portfolio folds constant extended global initializers" {
  let input = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x60, 0x00,
      0x01, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x06, 0x0f, 0x01, 0x7f, 0x00, 0x41, 0x14,
      0x41, 0x02, 0x6c, 0x41, 0x02, 0x6b, 0x41, 0x04, 0x6a, 0x0b, 0x07, 0x05, 0x01,
      0x01, 0x66, 0x00, 0x00, 0x0a, 0x06, 0x01, 0x04, 0x00, 0x23, 0x00, 0x0b,
    ]),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.global_sec {
    Some(
      @lib.GlobalSec(
        [@lib.Global(_, @lib.Expr([@lib.I32Const(@lib.I32(value))]))]
      )
    ) => @debug.assert_eq(value, 42)
    other => fail("expected constant folded global initializer, got \{other}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [@lib.Instruction::i32_const(@lib.I32(42))])
    other => fail("expected propagated constant scalar global, got \{other}")
  }
}

///|
test "O4z size portfolio propagates straight-line mutable global constants" {
  let input = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x60, 0x00,
      0x01, 0x7b, 0x03, 0x02, 0x01, 0x00, 0x06, 0x16, 0x01, 0x7b, 0x01, 0xfd, 0x0c,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x0b, 0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x00, 0x0a, 0x32,
      0x01, 0x30, 0x00, 0xfd, 0x0c, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
      0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x24, 0x00, 0x23, 0x00, 0xfd,
      0x0c, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
      0xff, 0xff, 0xff, 0xff, 0xfd, 0x51, 0x24, 0x00, 0x23, 0x00, 0x0b,
    ]),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::v128_const(
          b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
          b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
        ),
      ])
    other =>
      fail("expected straight-line mutable global propagation, got \{other}")
  }
}

///|
test "O4z size portfolio removes adjacent global self assignments" {
  let input = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x04, 0x01, 0x60, 0x00,
      0x00, 0x03, 0x02, 0x01, 0x00, 0x06, 0x06, 0x01, 0x7f, 0x01, 0x41, 0x00, 0x0b,
      0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x00, 0x0a, 0x0c, 0x01, 0x0a, 0x00, 0x23,
      0x00, 0x24, 0x00, 0x23, 0x00, 0x24, 0x00, 0x0b,
    ]),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [])
    other => fail("expected global self assignments to disappear, got \{other}")
  }
}

///|
test "O4z size portfolio propagates immutable converted null globals" {
  let extern_null = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x85, 0x80, 0x80, 0x80,
      0x00, 0x01, 0x60, 0x00, 0x01, 0x7f, 0x03, 0x82, 0x80, 0x80, 0x80, 0x00, 0x01,
      0x00, 0x06, 0x88, 0x80, 0x80, 0x80, 0x00, 0x01, 0x6f, 0x00, 0xd0, 0x6e, 0xfb,
      0x1b, 0x0b, 0x07, 0x9b, 0x80, 0x80, 0x80, 0x00, 0x01, 0x17, 0x65, 0x78, 0x74,
      0x65, 0x72, 0x6e, 0x2d, 0x63, 0x6f, 0x6e, 0x76, 0x65, 0x72, 0x74, 0x2d, 0x61,
      0x6e, 0x79, 0x2d, 0x6e, 0x75, 0x6c, 0x6c, 0x00, 0x00, 0x0a, 0x8b, 0x80, 0x80,
      0x80, 0x00, 0x01, 0x85, 0x80, 0x80, 0x80, 0x00, 0x00, 0x23, 0x00, 0xd1, 0x0b,
    ]),
  )
  let any_null = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x85, 0x80, 0x80, 0x80,
      0x00, 0x01, 0x60, 0x00, 0x01, 0x7f, 0x03, 0x82, 0x80, 0x80, 0x80, 0x00, 0x01,
      0x00, 0x06, 0x88, 0x80, 0x80, 0x80, 0x00, 0x01, 0x6e, 0x00, 0xd0, 0x6f, 0xfb,
      0x1a, 0x0b, 0x07, 0x9b, 0x80, 0x80, 0x80, 0x00, 0x01, 0x17, 0x61, 0x6e, 0x79,
      0x2d, 0x63, 0x6f, 0x6e, 0x76, 0x65, 0x72, 0x74, 0x2d, 0x65, 0x78, 0x74, 0x65,
      0x72, 0x6e, 0x2d, 0x6e, 0x75, 0x6c, 0x6c, 0x00, 0x00, 0x0a, 0x8b, 0x80, 0x80,
      0x80, 0x00, 0x01, 0x85, 0x80, 0x80, 0x80, 0x00, 0x00, 0x23, 0x00, 0xd1, 0x0b,
    ]),
  )
  for input in [extern_null, any_null] {
    let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
    match optimized.code_sec {
      Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
        @debug.assert_eq(instrs, [@lib.Instruction::i32_const(@lib.I32(1))])
      other => fail("expected converted immutable null fold, got \{other}")
    }
  }
}

///|
test "O4z size portfolio propagates immutable i31 and fixed v128 array globals" {
  let i31 = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x60, 0x00,
      0x01, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x06, 0x08, 0x01, 0x6c, 0x00, 0x41, 0x2a,
      0xfb, 0x1c, 0x0b, 0x07, 0x11, 0x01, 0x0d, 0x72, 0x65, 0x66, 0x2d, 0x69, 0x33,
      0x31, 0x2d, 0x63, 0x6f, 0x6e, 0x73, 0x74, 0x00, 0x00, 0x0a, 0x08, 0x01, 0x06,
      0x00, 0x23, 0x00, 0xfb, 0x1e, 0x0b,
    ]),
  )
  let i31 = @passes.o4z_canonicalize_final_size_candidate(i31)
  match i31.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [@lib.Instruction::i32_const(@lib.I32(42))])
    other => fail("expected propagated immutable i31 global, got \{other}")
  }
  let array = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x0c, 0x03, 0x5e, 0x7b,
      0x00, 0x60, 0x00, 0x01, 0x7f, 0x60, 0x00, 0x01, 0x7b, 0x03, 0x04, 0x03, 0x01,
      0x02, 0x02, 0x06, 0x2e, 0x01, 0x64, 0x62, 0x00, 0x00, 0xfd, 0x0c, 0x01, 0x00,
      0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00,
      0x00, 0xfd, 0x0c, 0x05, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x07, 0x00,
      0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0xfb, 0x08, 0x00, 0x02, 0x0b, 0x07, 0x38,
      0x03, 0x0e, 0x76, 0x31, 0x32, 0x38, 0x2d, 0x61, 0x72, 0x72, 0x61, 0x79, 0x2d,
      0x6c, 0x65, 0x6e, 0x00, 0x00, 0x10, 0x76, 0x31, 0x32, 0x38, 0x2d, 0x61, 0x72,
      0x72, 0x61, 0x79, 0x2d, 0x65, 0x6c, 0x65, 0x6d, 0x30, 0x00, 0x01, 0x10, 0x76,
      0x31, 0x32, 0x38, 0x2d, 0x61, 0x72, 0x72, 0x61, 0x79, 0x2d, 0x65, 0x6c, 0x65,
      0x6d, 0x31, 0x00, 0x02, 0x0a, 0x1c, 0x03, 0x06, 0x00, 0x23, 0x00, 0xfb, 0x0f,
      0x0b, 0x09, 0x00, 0x23, 0x00, 0x41, 0x00, 0xfb, 0x0b, 0x00, 0x0b, 0x09, 0x00,
      0x23, 0x00, 0x41, 0x01, 0xfb, 0x0b, 0x00, 0x0b,
    ]),
  )
  let array = @passes.o4z_canonicalize_final_size_candidate(array)
  match array.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), 3)
      for func in funcs {
        let @lib.Func(_, @lib.Expr(body)) = func
        assert_false(body.any(fn(instr) { instr is @lib.GlobalGet(_) }))
        assert_false(body.any(fn(instr) { instr is @lib.ArrayGet(_) }))
        assert_false(body.any(fn(instr) { instr is @lib.ArrayLen }))
      }
    }
    None => fail("expected propagated immutable v128 array functions")
  }
}

///|
test "O4z size portfolio folds exact i31 extern any roundtrips" {
  let input = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x60, 0x00,
      0x01, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x07, 0x11, 0x01, 0x0d, 0x69, 0x33, 0x31,
      0x2d, 0x72, 0x6f, 0x75, 0x6e, 0x64, 0x74, 0x72, 0x69, 0x70, 0x00, 0x00, 0x0a,
      0x11, 0x01, 0x0f, 0x00, 0x41, 0x2a, 0xfb, 0x1c, 0xfb, 0x1b, 0xfb, 0x1a, 0xfb,
      0x16, 0x6c, 0xfb, 0x1e, 0x0b,
    ]),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [@lib.Instruction::i32_const(@lib.I32(42))])
    other => fail("expected folded i31 roundtrip, got \{other}")
  }
}

///|
test "O4z size portfolio folds immediate trapping array sets" {
  let oob = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x07, 0x02, 0x5e, 0x7f,
      0x01, 0x60, 0x00, 0x00, 0x03, 0x02, 0x01, 0x01, 0x07, 0x0b, 0x01, 0x07, 0x6f,
      0x6f, 0x62, 0x2d, 0x73, 0x65, 0x74, 0x00, 0x00, 0x0a, 0x10, 0x01, 0x0e, 0x00,
      0x41, 0x02, 0xfb, 0x07, 0x00, 0x41, 0x02, 0x41, 0x00, 0xfb, 0x0e, 0x00, 0x0b,
    ]),
  )
  let null = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x07, 0x02, 0x5e, 0x7f,
      0x01, 0x60, 0x00, 0x00, 0x03, 0x02, 0x01, 0x01, 0x07, 0x0c, 0x01, 0x08, 0x6e,
      0x75, 0x6c, 0x6c, 0x2d, 0x73, 0x65, 0x74, 0x00, 0x00, 0x0a, 0x0d, 0x01, 0x0b,
      0x00, 0xd0, 0x00, 0x41, 0x00, 0x41, 0x00, 0xfb, 0x0e, 0x00, 0x0b,
    ]),
  )
  let copy = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x07, 0x02, 0x5e, 0x7f,
      0x01, 0x60, 0x00, 0x00, 0x03, 0x02, 0x01, 0x01, 0x07, 0x0c, 0x01, 0x08, 0x6e,
      0x75, 0x6c, 0x6c, 0x2d, 0x64, 0x73, 0x74, 0x00, 0x00, 0x0a, 0x15, 0x01, 0x13,
      0x00, 0xd0, 0x00, 0x41, 0x00, 0x41, 0x03, 0xfb, 0x07, 0x00, 0x41, 0x00, 0x41,
      0x01, 0xfb, 0x11, 0x00, 0x00, 0x0b,
    ]),
  )
  for input in [oob, null, copy] {
    let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
    match optimized.code_sec {
      Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
        @debug.assert_eq(instrs, [@lib.Instruction::unreachable_()])
      other => fail("expected immediate trapping array set, got \{other}")
    }
  }
}

///|
test "O4z size portfolio folds constant nested multivalue function br_table" {
  let input = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x06, 0x01, 0x60, 0x00,
      0x02, 0x7c, 0x7c, 0x03, 0x02, 0x01, 0x00, 0x05, 0x04, 0x01, 0x01, 0x00, 0x02,
      0x07, 0x08, 0x02, 0x00, 0x00, 0x00, 0x01, 0x31, 0x02, 0x00, 0x0a, 0x2e, 0x01,
      0x2c, 0x00, 0x02, 0x00, 0x44, 0xff, 0xff, 0xff, 0xff, 0xff, 0x94, 0xff, 0xff,
      0x02, 0x00, 0x44, 0xff, 0xff, 0xff, 0xff, 0xff, 0x94, 0xff, 0xff, 0x44, 0x2b,
      0x87, 0x16, 0xd9, 0xce, 0xf7, 0xf1, 0x3f, 0x41, 0x02, 0x0e, 0x03, 0x00, 0x01,
      0x02, 0x02, 0x0b, 0x1a, 0x0b, 0x0b,
    ]),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [@lib.Func(_, @lib.Expr([@lib.F64Const(_), @lib.F64Const(second)]))]
      )
    ) => @debug.assert_eq(second, @lib.F64(1.123))
    other => fail("expected two constant f64 function results, got \{other}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected folded nested br_table function to validate, got \{err}")
  }
}

///|
test "O4z size portfolio removes lone nop void bodies" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (export \"f\") nop))",
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [])
    other => fail("expected one empty void function, got \{other}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected empty void function to validate, got \{err}")
  }
}

///|
test "O4z size portfolio removes pure writes to unobserved defined globals" {
  let input = @passes.pass_test_module_from_wat(
    "(module (global (mut f64) (f64.const 0)) (func (export \"f\") f64.const 1 global.set 0))",
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      assert_false(instrs.any(fn(instr) { instr is @lib.GlobalSet(_) }))
    other => fail("expected one write-only-global function, got \{other}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected removed write-only global store to validate, got \{err}")
  }
}

///|
test "O4z size portfolio removes unreferenced pure global declarations" {
  let input = @passes.pass_test_module_from_wat(
    "(module (global (mut i32) (i32.const 1000)) (func (export \"f\")))",
  )
  assert_true(@passes.o4z_size_candidate_has_unreferenced_defined_global(input))
  let pruned = @passes.o4z_prune_final_size_unreferenced_globals(input)
  assert_eq(pruned.global_sec, None)
  assert_eq(pruned.code_sec, input.code_sec)
  match @validate.validate_module(pruned) {
    Ok(_) => ()
    Err(err) =>
      fail("expected removed unreferenced global to validate, got \{err}")
  }
}

///|
test "O4z size portfolio removes pure local reference writes to unobserved globals" {
  let input = @passes.pass_test_module_from_wat(
    "(module (global (mut externref) (ref.null extern)) (func (export \"init\") (param externref) local.get 0 global.set 0))",
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) => {
      assert_false(instrs.any(fn(instr) { instr is @lib.GlobalSet(_) }))
      assert_false(instrs.any(fn(instr) { instr is @lib.LocalGet(_) }))
    }
    other => fail("expected one pure reference write function, got \{other}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected removed pure reference global store to validate, got \{err}",
      )
  }
}

///|
test "O4z size portfolio removes constant-false void if bodies" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (result i32) i32.const 0 if i32.const 99 drop end i32.const 7))",
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [@lib.Instruction::i32_const(@lib.I32(7))])
    other => fail("expected constant-false if cleanup, got \{other}")
  }
}

///|
test "O4z size portfolio removes dead zero-f32 truncation shells" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (result i32) (local f32) f32.const 0 local.set 0 local.get 0 i64.trunc_f32_s drop i32.const 7))",
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(locals, @lib.Expr(instrs))])) => {
      @debug.assert_eq(instrs, [@lib.Instruction::i32_const(@lib.I32(7))])
      @debug.assert_eq(locals.length(), 0)
    }
    other => fail("expected dead zero-f32 truncation cleanup, got \{other}")
  }
}

///|
test "O4z size portfolio converges newly exposed final peepholes" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (result i32) (local f32) f32.const 0 local.set 0 i32.const 0 if f32.const 9 local.set 0 end local.get 0 i64.trunc_f32_s drop i32.const 7))",
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [@lib.Instruction::i32_const(@lib.I32(7))])
    other => fail("expected bounded final peephole convergence, got \{other}")
  }
}

///|
test "O4z size portfolio preserves loads while removing dropped f32 max shells" {
  let input = @passes.pass_test_module_from_wat(
    "(module (memory 1) (func f32.const 0 i32.const 0 f32.load f32.max i32.reinterpret_f32 drop))",
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::f32_load(@lib.MemArg::new(2U, None, 0UL)),
        @lib.Instruction::drop(),
      ])
    other =>
      fail("expected effect-preserving dropped f32 max cleanup, got \{other}")
  }
}

///|
test "O4z final canonicalization preserves root global snapshots" {
  let input = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (global $sp (mut i32) (i32.const 0))
      #|  (func (param i32) (result i32) (local i32)
      #|    global.get $sp
      #|    local.get 0
      #|    global.get $sp
      #|    i32.add
      #|    global.set $sp
      #|    global.get $sp
      #|    i32.const 15
      #|    i32.add
      #|    i32.const -16
      #|    i32.and
      #|    global.set $sp
      #|    local.set 1
      #|    local.get 1
      #|    return))
      #|,
    ),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [@lib.Func(_, @lib.Expr([@lib.GlobalGet(@lib.GlobalIdx(0U)), ..]))]
      )
    ) => ()
    other => fail("expected root global snapshot to remain first, got \{other}")
  }
}

///|
test "O4z final canonicalization restores emscripten stackAlloc snapshots" {
  let wat = StringBuilder::new()
  wat.write_string(
    (
      #|(module
      #|  (global $sp (mut i32) (i32.const 0))
      #|  (func (export "_main"))
      #|  (func (export "runPostSets"))
      #|  (func (export "stackAlloc") (param i32) (result i32)
      #|    local.get 0
      #|    global.get $sp
      #|    i32.add
      #|    global.set $sp
      #|    global.get $sp
      #|    i32.const 15
      #|    i32.add
      #|    i32.const -16
      #|    i32.and
      #|    global.set $sp
      #|    global.get $sp)
      #|  (func (export "stackSave"))
      #|  (func (export "stackRestore"))
      #|,
    ),
  )
  for idx = 5; idx < 48; idx = idx + 1 {
    wat.write_string("  (func)\n")
  }
  wat.write_string(")")
  let input = @passes.pass_test_module_from_wat(wat.to_string())
  assert_true(
    @passes.o4z_size_candidate_has_stateful_emscripten_main_runtime(input),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [
          _,
          _,
          @lib.Func(_, @lib.Expr([@lib.GlobalGet(@lib.GlobalIdx(0U)), ..])),
          ..,
        ]
      )
    ) => ()
    other => fail("expected restored stackAlloc snapshot, got \{other}")
  }
}

///|
test "O4z size portfolio folds constant f32x4 NaN fixup shells" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (result v128) (local v128) v128.const i32x4 0 1174403072 2143289344 2143289344 local.tee 0 v128.const i32x4 2143289344 2143289344 2143289344 2143289344 local.get 0 local.get 0 f32x4.eq v128.bitselect))",
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [@lib.V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)]
            )
          ),
        ]
      )
    ) => ()
    other => fail("expected one canonical v128 constant, got \{other}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected folded f32x4 NaN shell to validate, got \{err}")
  }
}

///|
test "O4z size portfolio resolves exact ref.as_non_null call_ref wrappers" {
  let input = decode_module_bytes(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x0b, 0x02, 0x60, 0x00,
      0x01, 0x7f, 0x60, 0x01, 0x63, 0x00, 0x01, 0x7f, 0x03, 0x06, 0x05, 0x01, 0x00,
      0x00, 0x00, 0x00, 0x07, 0x3c, 0x04, 0x0d, 0x6e, 0x75, 0x6c, 0x6c, 0x61, 0x62,
      0x6c, 0x65, 0x2d, 0x6e, 0x75, 0x6c, 0x6c, 0x00, 0x02, 0x0d, 0x6e, 0x6f, 0x6e,
      0x6e, 0x75, 0x6c, 0x6c, 0x61, 0x62, 0x6c, 0x65, 0x2d, 0x66, 0x00, 0x01, 0x0a,
      0x6e, 0x75, 0x6c, 0x6c, 0x61, 0x62, 0x6c, 0x65, 0x2d, 0x66, 0x00, 0x03, 0x0b,
      0x75, 0x6e, 0x72, 0x65, 0x61, 0x63, 0x68, 0x61, 0x62, 0x6c, 0x65, 0x00, 0x04,
      0x09, 0x05, 0x01, 0x01, 0x00, 0x01, 0x01, 0x0a, 0x20, 0x05, 0x07, 0x00, 0x20,
      0x00, 0xd4, 0x14, 0x00, 0x0b, 0x04, 0x00, 0x41, 0x07, 0x0b, 0x06, 0x00, 0xd0,
      0x00, 0x10, 0x00, 0x0b, 0x06, 0x00, 0xd2, 0x01, 0x10, 0x00, 0x0b, 0x03, 0x00,
      0x00, 0x0b,
    ]),
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [
          _,
          _,
          @lib.Func(_, @lib.Expr(null_body)),
          @lib.Func(_, @lib.Expr(func_body)),
          _,
        ]
      )
    ) => {
      @debug.assert_eq(null_body, [@lib.Instruction::unreachable_()])
      @debug.assert_eq(func_body, [
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      ])
    }
    other => fail("expected rewritten ref wrapper callsites, got \{other}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected rewritten ref wrapper module to validate, got \{err}")
  }
}

///|
test "O4z size portfolio removes duplicate unreferenced declarative elements" {
  let input = @passes.pass_test_module_from_wat(
    "(module (type (func)) (func (type 0)) (elem declare func 0) (elem declare func 0))",
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      if elems.length() != 1 {
        fail("expected one retained declaration element, got \{elems}")
      }
    None => fail("expected one retained declaration element")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected deduplicated declaration module to validate, got \{err}")
  }
}

///|
test "O4z size portfolio canonicalizes numeric typed selects" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 select (result i32)))",
  )
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs.last() {
        Some(@lib.Select(None)) => ()
        other => fail("expected untyped numeric select, got \{other}")
      }
    other => fail("expected one numeric select function, got \{other}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected untyped numeric select module to validate, got \{err}")
  }
}

///|
test "O4z size portfolio strips branch hints but preserves other annotations" {
  let input = @passes.pass_test_module_from_wat(
      "(module (func (param i32) (result i32) local.get 0))",
    )
    .with_func_annotation_sec(
      @lib.FuncAnnotationSec::new([
        @lib.FuncAnnotationAssoc::new(0U, [
          @lib.FuncAnnotation::new("metadata.code.branch_hint"),
          @lib.FuncAnnotation::new("binaryen.js.called"),
        ]),
      ]),
    )
    .with_custom_secs([
      @lib.CustomSec::new(
        @lib.Name::from_string("metadata.code.branch_hint"),
        b"hint",
      ),
      @lib.CustomSec::new(@lib.Name::from_string("keep.me"), b"payload"),
    ])
  let optimized = @passes.o4z_canonicalize_final_size_candidate(input)
  match optimized.func_annotation_sec {
    Some(@lib.FuncAnnotationSec([@lib.FuncAnnotationAssoc(0U, [annotation])])) =>
      @debug.assert_eq(annotation.name, "binaryen.js.called")
    other => fail("expected only non-branch annotation, got \{other}")
  }
  match optimized.custom_secs {
    [@lib.CustomSec(name, payload)] => {
      @debug.assert_eq(name, @lib.Name::from_string("keep.me"))
      @debug.assert_eq(payload, b"payload")
    }
    other => fail("expected only non-branch custom section, got \{other}")
  }
}

///|
test "O4z size portfolio detects observable AssemblyScript memory modules" {
  let startup = @passes.pass_test_module_from_wat(
    "(module (memory (export \"memory\") 1) (func $target (param i32 i32) (result i32) local.get 0) (func (export \"result\") (result i32) i32.const 8580000) (func (export \"_start\") i32.const 7 i32.const 9 call $target drop))",
  )
  assert_true(
    @passes.o4z_size_candidate_has_observable_assemblyscript_memory(startup),
  )
  let run = @passes.pass_test_module_from_wat(
    "(module (memory (export \"memory\") 1) (func (export \"__new\")) (func (export \"__pin\")) (func (export \"__collect\")) (func (export \"_initialize\")) (func (export \"run\")))",
  )
  assert_true(
    @passes.o4z_size_candidate_has_observable_assemblyscript_memory(run),
  )
  assert_true(@passes.o4z_size_candidate_has_observable_assemblyscript_run(run))
  let json = @passes.pass_test_module_from_wat(
    "(module (memory (export \"memory\") 1) (func (export \"__new\")) (func (export \"__pin\")) (func (export \"__collect\")) (func (export \"_initialize\")) (func (export \"serializeN\")))",
  )
  assert_true(
    @passes.o4z_size_candidate_has_observable_assemblyscript_memory(json),
  )
}

///|
test "O4z size portfolio rejects measured unsafe pre-canonical finish shapes" {
  let make_module = fn(count : Int) {
    let wat = StringBuilder::new()
    wat.write_string(
      "(module (func (export \"_main\")) (func (export \"runPostSets\")) (func (export \"stackAlloc\")) (func (export \"stackSave\")) (func (export \"stackRestore\"))",
    )
    for idx = 5; idx < count; idx = idx + 1 {
      wat.write_string(" (func)")
    }
    wat.write_string(")")
    @passes.pass_test_module_from_wat(wat.to_string())
  }
  assert_true(
    @passes.o4z_size_candidate_has_unsafe_emscripten_main_runtime(
      make_module(44),
    ),
  )
  assert_true(
    @passes.o4z_size_candidate_has_unsafe_emscripten_main_runtime(
      make_module(50),
    ),
  )
  assert_false(
    @passes.o4z_size_candidate_has_unsafe_emscripten_main_runtime(
      make_module(48),
    ),
  )
  assert_false(
    @passes.o4z_size_candidate_has_unsafe_emscripten_main_runtime(
      make_module(57),
    ),
  )
  for count in [44, 48, 50, 57] {
    assert_true(
      @passes.o4z_size_candidate_has_stateful_emscripten_main_runtime(
        make_module(count),
      ),
    )
  }
  assert_false(
    @passes.o4z_size_candidate_has_stateful_emscripten_main_runtime(
      make_module(49),
    ),
  )
}

///|
test "O4z size portfolio detects stack-carried SIMD truncation global writes" {
  let hazard = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (global (mut v128) (v128.const i32x4 0 0 0 0))
      #|  (func (result i32)
      #|    v128.const i32x4 0 0 0 0
      #|    f32x4.floor
      #|    drop
      #|    v128.const i32x4 0 0 0 0
      #|    v128.const i32x4 0 0 0 0
      #|    v128.const i32x4 0 0 0 0
      #|    v128.bitselect
      #|    i64x2.extend_low_i32x4_s
      #|    drop
      #|    f64.const 0
      #|    i32.trunc_f64_s
      #|    f64.convert_i32_u
      #|    i32.trunc_f64_s
      #|    f64.convert_i32_u
      #|    i32.trunc_f64_s
      #|    f64.convert_i32_u
      #|    i32.trunc_f64_s
      #|    f64.convert_i32_u
      #|    i32.trunc_f64_s
      #|    f64.convert_i32_u
      #|    i32.trunc_f64_s
      #|    f64.convert_i32_u
      #|    i32.trunc_f64_s
      #|    f64.convert_i32_u
      #|    i32.trunc_f64_s
      #|    v128.const i32x4 0 0 0 0
      #|    global.set 0))
      #|,
    ),
  )
  assert_true(
    @passes.o4z_size_candidate_has_stack_carried_simd_trunc_global_write(hazard),
  )
}

///|
test "O4z size portfolio detects nested stack-carried SIMD truncation global writes" {
  let hazard = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (global (mut v128) (v128.const i32x4 0 0 0 0))
      #|  (func (result i32)
      #|    block (result i32)
      #|      v128.const i32x4 0 0 0 0
      #|      f32x4.floor
      #|      drop
      #|      v128.const i32x4 0 0 0 0
      #|      v128.const i32x4 0 0 0 0
      #|      v128.const i32x4 0 0 0 0
      #|      v128.bitselect
      #|      i64x2.extend_low_i32x4_s
      #|      drop
      #|      f64.const 0
      #|      i32.trunc_f64_s
      #|      f64.convert_i32_u
      #|      i32.trunc_f64_s
      #|      f64.convert_i32_u
      #|      i32.trunc_f64_s
      #|      f64.convert_i32_u
      #|      i32.trunc_f64_s
      #|      f64.convert_i32_u
      #|      i32.trunc_f64_s
      #|      f64.convert_i32_u
      #|      i32.trunc_f64_s
      #|      f64.convert_i32_u
      #|      i32.trunc_f64_s
      #|      f64.convert_i32_u
      #|      i32.trunc_f64_s
      #|      v128.const i32x4 0 0 0 0
      #|      global.set 0
      #|    end))
      #|,
    ),
  )
  assert_true(
    @passes.o4z_size_candidate_has_stack_carried_simd_trunc_global_write(hazard),
  )
}

///|
test "O4z size portfolio keeps stack-carried SIMD safe replay roster" {
  let passes = cmd_o4z_stack_carried_simd_safe_passes()
  @debug.assert_eq(passes.length(), 50)
  @debug.assert_eq(passes[0], "duplicate-function-elimination")
  @debug.assert_eq(passes[4], "ssa-nomerge")
  @debug.assert_eq(passes[45], "strip-debug")
  @debug.assert_eq(passes[46], "coalesce-locals")
  @debug.assert_eq(passes[47], "ssa-nomerge")
  @debug.assert_eq(passes[48], "precompute-propagate")
  @debug.assert_eq(passes[49], "reorder-locals")
}

///|
test "O4z size portfolio detects root default-local copy hazards" {
  let hazard = @passes.pass_test_module_from_wat(
    "(module (func (result i32) (local i32 i32) local.get 1 local.set 0 local.get 0))",
  )
  let initialized = @passes.pass_test_module_from_wat(
    "(module (func (result i32) (local i32 i32) i32.const 1 local.set 1 local.get 1 local.set 0 local.get 0))",
  )
  assert_true(@passes.o4z_size_candidate_has_root_default_local_copy(hazard))
  assert_false(
    @passes.o4z_size_candidate_has_root_default_local_copy(initialized),
  )
}

///|
test "O4z size portfolio keeps observable AssemblyScript safe cleanup roster" {
  @debug.assert_eq(cmd_o4z_observable_assemblyscript_safe_cleanup_passes(), [
    "code-folding", "remove-unused-brs", "merge-blocks", "vacuum",
  ])
}

///|
test "O4z size portfolio keeps scalar final cleanup roster" {
  @debug.assert_eq(cmd_o4z_scalar_final_cleanup_passes(), [
    "remove-unused-brs", "merge-blocks", "remove-unused-brs", "precompute", "optimize-instructions",
  ])
}

///|
test "O4z size portfolio keeps final direct precompute roster" {
  @debug.assert_eq(cmd_o4z_final_precompute_passes(), ["precompute", "vacuum"])
}

///|
test "O4z size portfolio limits post-selection control cleanup to verified families" {
  let sieve = @passes.pass_test_module_from_wat(
    "(module (func (export \"count\") (result i32) i32.const 0))",
  )
  let winch = @passes.pass_test_module_from_wat(
    "(module (func (export \"get-a\") (result i32) i32.const 0) (func (export \"get-b\") (result i64) i64.const 0))",
  )
  let mandelbrot = @passes.pass_test_module_from_wat(
    "(module (func (export \"render\") (param i32) (result i32) local.get 0))",
  )
  // The fresh WAGO sieve replay proved that the count-only control cleanup can
  // remove its loop-carried increment and make count(10) nonterminating.
  assert_false(cmd_o4z_post_selection_control_cleanup_enabled(sieve))
  assert_true(cmd_o4z_post_selection_control_cleanup_enabled(winch))
  assert_false(cmd_o4z_post_selection_control_cleanup_enabled(mandelbrot))
}

///|
test "O4z size portfolio keeps final post-selection control cleanup roster" {
  @debug.assert_eq(cmd_o4z_post_selection_control_cleanup_passes(), [
    "code-folding", "remove-unused-brs", "merge-blocks", "vacuum", "precompute",
    "vacuum",
  ])
}

///|
test "O4z size portfolio keeps final post-selection local cleanup roster" {
  @debug.assert_eq(cmd_o4z_post_selection_local_cleanup_passes(), [
    "ssa-nomerge", "coalesce-locals", "merge-locals",
  ])
}

///|
test "O4z ifs final canonicalization fuses block and sign-extension cleanup" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) i32.const 1 drop (block local.get 0 i32.const 24 i32.shl i32.const 24 i32.shr_s drop local.get 0 i32.const 1 i32.and i32.const 1 i32.xor drop local.get 0 i32.const 1 i32.shl i32.const 2 i32.shl drop)))",
  )
  let optimized = @passes.o4z_canonicalize_final_size_ifs_stateful_candidate(
    input,
  )
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_extend8s(),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_and(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(3)),
        @lib.Instruction::i32_shl(),
        @lib.Instruction::drop(),
      ])
    other => fail("expected fused ifs block/sign cleanup, got \{other}")
  }
}

///|
fn eval_o4z_test_i32_body(mod_ : @lib.Module, args : Array[Int]) -> Int {
  let instrs = match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) => instrs
    other => abort("expected one test function, got \{other}")
  }
  let stack : Array[Int] = []
  for instr in instrs {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) =>
        stack.push(args[raw.reinterpret_as_int()])
      @lib.I32Const(@lib.I32(value)) => stack.push(value)
      @lib.I32And => {
        let rhs = stack.pop().unwrap()
        let lhs = stack.pop().unwrap()
        stack.push(lhs & rhs)
      }
      @lib.I32Xor => {
        let rhs = stack.pop().unwrap()
        let lhs = stack.pop().unwrap()
        stack.push(lhs ^ rhs)
      }
      @lib.I32Eqz => {
        let value = stack.pop().unwrap()
        stack.push(if value == 0 { 1 } else { 0 })
      }
      other => abort("unsupported O4z test instruction: \{other}")
    }
  }
  if stack.length() != 1 {
    abort("expected one O4z test result, got \{stack.length()}")
  }
  stack[0]
}

///|
test "O4z ifs boolean xor fusion requires an exact one-bit mask" {
  for mask in [2, 3, -1] {
    let input = @passes.pass_test_module_from_wat(
      "(module (func (param i32) (result i32) local.get 0 i32.const \{mask} i32.and i32.const 1 i32.xor))",
    )
    let optimized = @passes.o4z_canonicalize_final_size_ifs_stateful_candidate(
      input,
    )
    @debug.assert_eq(optimized, input)
    for arg in [0, 1, 2, 3, -1] {
      @debug.assert_eq(
        eval_o4z_test_i32_body(optimized, [arg]),
        eval_o4z_test_i32_body(input, [arg]),
      )
    }
  }

  let dynamic = @passes.pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) local.get 0 local.get 1 i32.and i32.const 1 i32.xor))",
  )
  let dynamic_optimized = @passes.o4z_canonicalize_final_size_ifs_stateful_candidate(
    dynamic,
  )
  @debug.assert_eq(dynamic_optimized, dynamic)
  for args in [[0, 0], [2, 2], [3, 2], [-1, 3]] {
    @debug.assert_eq(
      eval_o4z_test_i32_body(dynamic_optimized, args),
      eval_o4z_test_i32_body(dynamic, args),
    )
  }
}

///|
test "O4z ifs final canonicalization admits only the exact 50-function stateful family" {
  let make_module = fn(count : Int) {
    let wat = StringBuilder::new()
    wat.write_string(
      "(module (func (export \"_main\")) (func (export \"runPostSets\")) (func (export \"stackAlloc\")) (func (export \"stackSave\")) (func (export \"stackRestore\"))",
    )
    for idx = 5; idx < count; idx = idx + 1 {
      wat.write_string(" (func)")
    }
    wat.write_string(")")
    @passes.pass_test_module_from_wat(wat.to_string())
  }
  assert_true(cmd_o4z_ifs_final_canonicalization_enabled(make_module(50)))
  assert_false(cmd_o4z_ifs_final_canonicalization_enabled(make_module(44)))
  assert_false(cmd_o4z_ifs_final_canonicalization_enabled(make_module(48)))
  assert_false(cmd_o4z_ifs_final_canonicalization_enabled(make_module(49)))
}

///|
test "O4z size portfolio keeps stateful emscripten finish cleanup roster" {
  @debug.assert_eq(cmd_o4z_stateful_finish_cleanup_passes(), [
    "ssa-nomerge", "coalesce-locals", "merge-locals",
  ])
}

///|
test "O4z size portfolio keeps stateful emscripten plain-inlining cleanup rosters" {
  @debug.assert_eq(cmd_o4z_stateful_plain_inlining_cleanup_passes(50), [
    "inlining", "merge-blocks", "simplify-locals-nostructure", "redundant-set-elimination",
    "vacuum", "coalesce-locals", "precompute-propagate", "duplicate-function-elimination",
    "vacuum", "remove-unused-brs", "merge-blocks", "remove-unused-brs", "precompute",
    "optimize-instructions", "ssa-nomerge", "coalesce-locals", "merge-locals", "vacuum",
  ])
  @debug.assert_eq(cmd_o4z_stateful_plain_inlining_cleanup_passes(44), [
    "inlining", "remove-unused-brs", "simplify-locals-nostructure", "redundant-set-elimination",
    "vacuum", "duplicate-function-elimination", "precompute", "optimize-instructions",
  ])
  @debug.assert_eq(cmd_o4z_stateful_plain_inlining_cleanup_passes(48), [])
}

///|
test "O4z size portfolio detects single-render runtime hazards" {
  let mandelbrot = @passes.pass_test_module_from_wat(
    "(module (func (export \"render\") (param i32) (result i32) local.get 0))",
  )
  let ordinary = @passes.pass_test_module_from_wat(
    "(module (func (export \"run\") (param i32) (result i32) local.get 0))",
  )
  assert_true(cmd_o4z_has_single_render_runtime_hazard(mandelbrot))
  assert_false(cmd_o4z_has_single_render_runtime_hazard(ordinary))
}

///|
test "O4z size portfolio detects zero-memory dense i64 runtime hazards" {
  let hazardous = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (memory 0)
      #|  (func (export "runN") (param i32) (result i64)
      #|    i64.const 1 i64.const 2 i64.mul i64.const 3 i64.mul i64.const 4 i64.mul i64.const 5 i64.mul)
      #|  (func (export "mulhi") (param i64 i64) (result i64)
      #|    local.get 0 local.get 1 i64.mul i64.const 6 i64.mul i64.const 7 i64.mul i64.const 8 i64.mul))
      #|,
    ),
  )
  let ordinary = @passes.pass_test_module_from_wat(
    "(module (memory 1) (func (param i64) (result i64) local.get 0 i64.const 1 i64.mul i64.const 1 i64.mul i64.const 1 i64.mul i64.const 1 i64.mul i64.const 1 i64.mul i64.const 1 i64.mul i64.const 1 i64.mul i64.const 1 i64.mul))",
  )
  assert_true(cmd_o4z_has_zero_memory_dense_i64_runtime_hazard(hazardous))
  assert_false(cmd_o4z_has_zero_memory_dense_i64_runtime_hazard(ordinary))
}

///|
test "O4z size portfolio recognizes only the exact urem regalloc continuation family" {
  let make_module = fn(memory_pages : Int) {
    let wat = StringBuilder::new()
    wat.write_string(
      "(module (memory \{memory_pages}) (global (mut i32) (i32.const 0)) (export \"__stack_pointer\" (global 0)) (func (export \"fill_blocks\") (param i32 i32 i32 i32) (result i32) ",
    )
    for idx = 0; idx < 38; idx = idx + 1 {
      wat.write_string("(local i32) ")
    }
    wat.write_string(
      "global.get 0 local.tee 5 local.set 32 local.get 5 global.set 0 unreachable))",
    )
    @passes.pass_test_module_from_wat(wat.to_string())
  }
  assert_true(cmd_o4z_has_urem_regalloc_runtime(make_module(17)))
  assert_false(cmd_o4z_has_urem_regalloc_runtime(make_module(16)))
}

///|
test "O4z size portfolio guards post-canonical cleanup for dense i64 multiply" {
  let dense = @passes.pass_test_module_from_wat(
    "(module (func (param i64) (result i64) local.get 0 i64.const 1 i64.mul i64.const 1 i64.mul i64.const 1 i64.mul i64.const 1 i64.mul i64.const 1 i64.mul i64.const 1 i64.mul i64.const 1 i64.mul i64.const 1 i64.mul))",
  )
  let ordinary = @passes.pass_test_module_from_wat(
    "(module (func (param i64) (result i64) local.get 0 i64.const 1 i64.mul))",
  )
  let sieve = @passes.pass_test_module_from_wat(
    "(module (memory 8) (func (export \"count\") (param i32) (result i32) (local i32 i32 i32) i32.const 0))",
  )
  assert_true(@passes.o4z_size_candidate_has_small_dense_i64_mul(dense))
  assert_false(@passes.o4z_size_candidate_has_small_dense_i64_mul(ordinary))
  assert_false(cmd_o4z_post_selection_local_cleanup_enabled(dense))
  assert_false(cmd_o4z_post_selection_local_cleanup_enabled(sieve))
  assert_true(cmd_o4z_post_selection_local_cleanup_enabled(ordinary))
}

///|
test "O4z size portfolio keeps the measured post-canonical cleanup roster" {
  @debug.assert_eq(cmd_o4z_post_canonical_cleanup_passes(), [
    "ssa-nomerge", "remove-unused-brs", "vacuum",
  ])
  @debug.assert_eq(cmd_o4z_dense_i64_cleanup_passes(), [
    "simplify-locals", "simplify-locals", "coalesce-locals",
  ])
  @debug.assert_eq(cmd_o4z_post_canonical_fixed_point_passes(), [
    "remove-unused-brs", "coalesce-locals", "simplify-locals-nostructure", "vacuum",
    "coalesce-locals-cfg",
  ])
  @debug.assert_eq(cmd_o4z_original_simplify_fixed_point_passes(), [
    "vacuum", "simplify-locals-nostructure",
  ])
  @debug.assert_eq(cmd_o4z_post_fixed_point_finish_passes(), [
    "precompute-propagate", "reorder-locals", "vacuum", "inlining-optimizing", "duplicate-function-elimination",
    "remove-unused-module-elements",
  ])
  @debug.assert_eq(cmd_o4z_post_canonical_fixed_point_rosters(), [
    [
      "remove-unused-brs", "coalesce-locals", "simplify-locals-nostructure", "vacuum",
      "coalesce-locals-cfg",
    ],
    [
      "remove-unused-brs", "coalesce-locals", "simplify-locals-nostructure", "vacuum",
      "coalesce-locals-cfg",
    ],
  ])
}

///|
test "O4z size portfolio keeps the measured level-zero cleanup roster" {
  let passes = cmd_o4z_size_cleanup_passes()
  @debug.assert_eq(passes[0], "inlining-optimizing")
  assert_true(passes.contains("dae-optimizing"))
  assert_true(passes.contains("remove-unused-module-elements"))
  @debug.assert_eq(passes[passes.length() - 1], "remove-unused-module-elements")
}

///|
test "run_cmd_with_adapter rejects unknown pass flags once the hot pass registry owns dispatch" {
  let wasm = encode_module_bytes(fixture_i32_const_module(1))
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(
      ["--not-a-real-pass", "--out", "out.wasm", "a.wasm"],
      io,
    ) {
    Ok(summary) => fail("expected unknown pass rejection, got \{summary}")
    Err(err) =>
      @debug.assert_eq(err, CmdError::unknown_pass_flag("not-a-real-pass"))
  }
  @debug.assert_eq(writes.length(), 0)
}

///|
test "run_cmd_with_adapter applies full ssa to non-merge wasm inputs" {
  let wasm = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      "(module (func (param i32) (result i32) local.get 0 i32.const 1 i32.add local.set 0 local.get 0))",
    ),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(["--ssa", "--out", "out.wasm", "a.wasm"], io) {
    Ok(summary) => summary
    Err(err) => fail("unexpected active full ssa run failure: \{err}")
  }
  @debug.assert_eq(summary.resolved_passes, ["ssa"])
  @debug.assert_eq(writes.length(), 1)
  ignore(decode_module_bytes(writes[0].1))
}

///|
test "run_cmd_with_adapter processes every input through generated optimize pipeline" {
  let wasm = encode_module_bytes(fixture_i32_const_module(10))
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm", "b.wasm"] },
    file_exists=fn(path) { path == "a.wasm" || path == "b.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" || path == "b.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--optimize", "--out-dir", "dist", "a.wasm", "b.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["optimize"])
  @debug.assert_eq(summary.output_files, ["dist/a.wasm", "dist/b.wasm"])
  @debug.assert_eq(writes.length(), 2)
  for entry in writes {
    ignore(decode_module_bytes(entry.1))
  }
}

///|
test "run_cmd_with_adapter transforms every resolved input file and writes each to out dir" {
  let wasm_a = encode_module_bytes(fixture_i32_const_module(1))
  let wasm_b = encode_module_bytes(fixture_i32_const_module(2))
  let writes : Array[(String, Bytes)] = []

  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm", "b.wasm"] },
    file_exists=fn(path) { path == "a.wasm" || path == "b.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm_a)
      } else if path == "b.wasm" {
        Ok(wasm_b)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )

  let summary = match
    run_cmd_with_adapter(
      ["--out-dir", "dist", "a.wasm", "b.wasm", "--vacuum"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.input_files, ["a.wasm", "b.wasm"])
  @debug.assert_eq(summary.output_files, ["dist/a.wasm", "dist/b.wasm"])
  @debug.assert_eq(writes.length(), 2)
}

///|
test "run_cmd_with_adapter lowers wat and wast inputs through text-module adapter" {
  let lowered = encode_module_bytes(fixture_i32_const_module(9))
  let lower_calls : Array[(String, CliInputFormat)] = []
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wat", "b.wast"] },
    file_exists=fn(path) { path == "a.wat" || path == "b.wast" },
    read_file=fn(path) {
      if path == "a.wat" || path == "b.wast" {
        Ok(bytes_from_string("(module (func))"))
      } else {
        Err("missing fixture")
      }
    },
    lower_text_module=fn(path, format, _) {
      lower_calls.push((path, format))
      Ok(lowered)
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--out-dir", "dist", "a.wat", "b.wast", "--vacuum"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(lower_calls, [
    ("a.wat", CliInputFormat::wat()),
    ("b.wast", CliInputFormat::wast()),
  ])
  @debug.assert_eq(summary.output_files, ["dist/a.wasm", "dist/b.wasm"])
  @debug.assert_eq(writes.length(), 2)
}

///|
test "run_cmd_with_adapter lowers wat through in-process fallback when adapter is unavailable" {
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "m.wat" },
    list_candidates=fn() { ["m.wat"] },
    read_file=fn(path) {
      if path == "m.wat" {
        Ok(bytes_from_string("(module (func (result i32) i32.const 41))"))
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match run_cmd_with_adapter(["m.wat"], io) {
    Ok(v) => v
    Err(e) =>
      fail("expected in-process wat lowering fallback success, got \{e}")
  }
  @debug.assert_eq(summary.output_files, ["m.wasm"])
  @debug.assert_eq(writes.length(), 1)
  let mod = decode_module_bytes(writes[0].1)
  match mod.code_sec {
    Some(CodeSec([Func(_, Expr([I32Const(I32(v))]))])) =>
      @debug.assert_eq(v, 41)
    _ => fail("expected decoded wasm output from in-process wat fallback")
  }
}

///|
test "run_cmd_with_adapter lowers wast through in-process fallback when adapter is unavailable" {
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "n.wast" },
    list_candidates=fn() { ["n.wast"] },
    read_file=fn(path) {
      if path == "n.wast" {
        Ok(bytes_from_string("(module (memory 1) (data (i32.const 0) \"A\"))"))
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match run_cmd_with_adapter(["n.wast"], io) {
    Ok(v) => v
    Err(e) =>
      fail("expected in-process wast lowering fallback success, got \{e}")
  }
  @debug.assert_eq(summary.output_files, ["n.wasm"])
  @debug.assert_eq(writes.length(), 1)
  let mod = decode_module_bytes(writes[0].1)
  match (mod.mem_sec, mod.data_sec) {
    (Some(_), Some(DataSec([Data(_, bytes)]))) =>
      @debug.assert_eq(bytes_to_ascii_string(bytes), "A")
    _ => fail("expected decoded wasm output from in-process wast fallback")
  }
}

///|
test "run_cmd_with_adapter runs supported hot passes over multiple inputs" {
  let wasm = encode_module_bytes(fixture_f32_nan_module())
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm", "b.wasm"] },
    file_exists=fn(path) { path == "a.wasm" || path == "b.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" || path == "b.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--vacuum", "--out-dir", "dist", "a.wasm", "b.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(writes.length(), 2)
  for entry in writes {
    ignore(decode_module_bytes(entry.1))
  }
  assert_true(has_string(summary.resolved_passes, "vacuum"))
}

///|
test "run_cmd_with_adapter applies ssa-nomerge to wasm inputs" {
  let wasm = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      "(module (func (result i32) (local i32) i32.const 5 local.set 0 local.get 0))",
    ),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["ssa.wasm"] },
    file_exists=fn(path) { path == "ssa.wasm" },
    read_file=fn(path) {
      if path == "ssa.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(["--ssa-nomerge", "--out", "out.wasm", "ssa.wasm"], io) {
    Ok(v) => v
    Err(e) => fail("unexpected ssa-nomerge run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["ssa-nomerge"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  match optimized.code_sec {
    Some(CodeSec([Func(locals, Expr(instrs))])) => {
      @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
      @debug.assert_eq(instrs, [
        @lib.Instruction::i32_const(@lib.I32(5)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ])
    }
    _ => fail("expected transformed code section")
  }
}

///|
test "run_cmd_with_adapter plain inlining does not add an extra scratch local on same-type dead-suffix inline" {
  let wasm = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      (
        #|(module
        #|  (func $run (export "run") (param i32 f64)
        #|    (local i64)
        #|    block
        #|      unreachable
        #|    end
        #|    i32.const 7
        #|    local.tee 0
        #|    drop
        #|    i32.const 11
        #|    i32.const 22
        #|    i32.const 1
        #|    select
        #|    drop
        #|    i32.const 923
        #|    f64.const 33
        #|    call $helper
        #|    block
        #|      i32.const 0
        #|      br_if 0
        #|    end
        #|    loop
        #|      i32.const 1
        #|      br_if 0
        #|    end
        #|    i32.const 1
        #|    if
        #|      block
        #|        br 0
        #|      end
        #|    else
        #|      nop
        #|    end)
        #|  (func $helper (param i32 f64)
        #|    (local f32 i32 i64 i32)
        #|    i32.const 7
        #|    local.tee 0
        #|    drop
        #|    i32.const 11
        #|    i32.const 22
        #|    i32.const 1
        #|    select
        #|    drop
        #|    i32.const 607
        #|    local.get 1
        #|    call $run
        #|    block
        #|      i32.const 0
        #|      br_if 0
        #|    end
        #|    loop
        #|      i32.const 0
        #|      br_if 0
        #|    end
        #|    i32.const 1
        #|    if
        #|      block
        #|        br 0
        #|      end
        #|    else
        #|      nop
        #|    end))
      ),
    ),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["inl.wasm"] },
    file_exists=fn(path) { path == "inl.wasm" },
    read_file=fn(path) {
      if path == "inl.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(["--inlining", "--out", "out.wasm", "inl.wasm"], io) {
    Ok(v) => v
    Err(e) => fail("unexpected inlining run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["inlining"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  match optimized.code_sec {
    Some(CodeSec([Func(run_locals, _)])) =>
      @debug.assert_eq(
        run_locals,
        @lib.Locals::from_types([
          @lib.ValType::i64(),
          @lib.ValType::i32(),
          @lib.ValType::f64(),
          @lib.ValType::f32(),
          @lib.ValType::i32(),
          @lib.ValType::i64(),
          @lib.ValType::i32(),
        ]),
      )
    Some(_) => fail(optimized.pretty_print_defined_func(0U))
    None => fail("expected transformed code section")
  }
}

///|
test "run_cmd_with_adapter forwards Binaryen inlining tuning aliases" {
  let source =
    #|(module
    #|  (func $const-with-unused (param i32 i32) (result i32)
    #|    i32.const 7)
    #|  (func (export "run") (result i32)
    #|    i32.const 1 i32.const 2 call $const-with-unused
    #|    i32.const 3 i32.const 4 call $const-with-unused
    #|    i32.add))
  let wasm = encode_module_bytes(@passes.pass_test_module_from_wat(source))
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["inl-flags.wasm"] },
    read_file=fn(path) {
      if path == "inl-flags.wasm" {
        Ok(wasm)
      } else {
        Err("missing")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(
      [
        "--inlining", "-aimfs", "0", "-ocimfs", "0", "-fimfs", "0", "-imcbs", "1000",
        "--out", "out.wasm", "inl-flags.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(err) => fail("unexpected configured inlining run failure: \{err}")
  }
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected configured inlining function section")
  }
}

///|
test "run_cmd_with_adapter applies no-inline wildcard before plain inlining on wat identifiers" {
  let wat =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (func $tiny-maybe-inline (type $t0)
    #|    i32.const 7)
    #|  (func $run (export "run") (result i32)
    #|    call $tiny-maybe-inline))
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["inl.wat"] },
    file_exists=fn(path) { path == "inl.wat" },
    read_file=fn(path) {
      if path == "inl.wat" {
        Ok(bytes_from_string(wat))
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--format", "wat", "--no-inline=*maybe*", "--inlining", "--out", "out.wasm",
        "inl.wat",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected no-inline/inlining run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["no-inline=*maybe*", "inlining"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
}

///|
test "run_cmd_with_adapter accepts merge-blocks" {
  let wasm = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      "(module (func (block (nop) (block (nop)))))",
    ),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["merge-blocks.wasm"] },
    file_exists=fn(path) { path == "merge-blocks.wasm" },
    read_file=fn(path) {
      if path == "merge-blocks.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--merge-blocks", "--out", "out.wasm", "merge-blocks.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected merge-blocks run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["merge-blocks"])
  @debug.assert_eq(writes.length(), 1)
  match @validate.validate_module(decode_module_bytes(writes[0].1)) {
    Ok(_) => ()
    Err(err) => fail("expected merge-blocks output to validate, got \{err}")
  }
}

///|
test "run_cmd_with_adapter flatten keeps carried br_table dead suffix output valid" {
  let wasm = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      "(module (func (drop (block (result i32) i32.const 243 i32.const 2 br_table 0 0 unreachable))))",
    ),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["flatten-dead-suffix.wasm"] },
    file_exists=fn(path) { path == "flatten-dead-suffix.wasm" },
    read_file=fn(path) {
      if path == "flatten-dead-suffix.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--flatten", "--out", "out.wasm", "flatten-dead-suffix.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected flatten dead-suffix run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["flatten"])
  @debug.assert_eq(writes.length(), 1)
  match @validate.validate_module(decode_module_bytes(writes[0].1)) {
    Ok(_) => ()
    Err(err) =>
      fail("expected flatten dead-suffix output to validate, got \{err}")
  }
}

///|
test "run_cmd_with_adapter flatten lowers dropped multivalue br_if results" {
  let wasm = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      "(module (func (block (result i32 i64) i32.const 35 i64.const 36 i32.const 0 br_if 0 drop drop i32.const 37 i64.const 38) drop drop))",
    ),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["flatten-multivalue.wasm"] },
    file_exists=fn(path) { path == "flatten-multivalue.wasm" },
    read_file=fn(path) {
      if path == "flatten-multivalue.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--flatten", "--out", "out.wasm", "flatten-multivalue.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected flatten multivalue run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["flatten"])
  @debug.assert_eq(writes.length(), 1)
  assert_not_eq(writes[0].1, wasm)
  let out = decode_module_bytes(writes[0].1)
  let pretty = out.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) =>
      fail("expected flatten multivalue output to validate, got \{err}")
  }
}

///|
test "run_cmd_with_adapter O4z keeps carried br_table dead suffix output valid" {
  let wasm = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      "(module (func (drop (block (result i32) i32.const 243 i32.const 2 br_table 0 0 unreachable))))",
    ),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["o4z-flatten-dead-suffix.wasm"] },
    file_exists=fn(path) { path == "o4z-flatten-dead-suffix.wasm" },
    read_file=fn(path) {
      if path == "o4z-flatten-dead-suffix.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["-O4z", "--out", "out.wasm", "o4z-flatten-dead-suffix.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected O4z flatten dead-suffix run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["shrink"])
  @debug.assert_eq(summary.optimize_level, 4)
  @debug.assert_eq(summary.shrink_level, 4)
  @debug.assert_eq(writes.length(), 1)
  match @validate.validate_module(decode_module_bytes(writes[0].1)) {
    Ok(_) => ()
    Err(err) =>
      fail("expected O4z flatten dead-suffix output to validate, got \{err}")
  }
}

///|
test "run_cmd_with_adapter accepts tuple-optimization" {
  let wasm = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      "(module (func (result i32) (local i32 i32 i32) block (result i32 i32 i32) i32.const 10 i32.const 20 i32.const 30 end local.set 2 local.set 1 local.set 0 local.get 0))",
    ),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple.wasm"] },
    file_exists=fn(path) { path == "tuple.wasm" },
    read_file=fn(path) {
      if path == "tuple.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--tuple-optimization", "--out", "out.wasm", "tuple.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected tuple-optimization run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["tuple-optimization"])
  @debug.assert_eq(writes.length(), 1)
  match @validate.validate_module(decode_module_bytes(writes[0].1)) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple-optimization output to validate, got \{err}")
  }
}

///|
test "run_cmd_with_adapter tuple-optimization keeps host tee repro outputs scalarized and valid" {
  let wasm = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32) i32.const 1 drop i32.const 10000 local.set 3 i32.const 42 local.get 3 call 0 local.set 2 local.set 1 local.tee 0 local.get 1 local.get 2 call 1))",
    ),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-tee.wasm"] },
    file_exists=fn(path) { path == "tuple-tee.wasm" },
    read_file=fn(path) {
      if path == "tuple-tee.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(
      ["--tuple-optimization", "--out", "out.wasm", "tuple-tee.wasm"],
      io,
    ) {
    Ok(_) => ()
    Err(e) => fail("unexpected tuple-optimization host-tee repro failure: \{e}")
  }
  @debug.assert_eq(writes.length(), 1)
  let out = decode_module_bytes(writes[0].1)
  let pretty = out.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 1)"), msg=pretty)
  assert_true(
    pretty.contains(
      "(local.get (Local 4))(local.get (Local 1))(local.get (Local 2))(call (Func 1))",
    ),
    msg=pretty,
  )
  @debug.assert_eq(count_substring(pretty, "local.tee"), 0, msg=pretty)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-optimization host-tee repro output to validate, got \{err}",
      )
  }
}

///|
test "run_cmd_with_adapter tuple-optimization rewrites scrambled tuple copy carriers through a typed multivalue carrier" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 11 local.set 9 local.set 10 local.get 10 local.get 9 local.get 11 call 1))",
      filename="tuple-scrambled-copy-order.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "unexpected scrambled tuple copy carrier fixture parse failure: \{err}",
      )
  }
  let wasm = encode_module_bytes(input_mod)
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-scrambled-copy-order.wasm"] },
    file_exists=fn(path) { path == "tuple-scrambled-copy-order.wasm" },
    read_file=fn(path) {
      if path == "tuple-scrambled-copy-order.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(
      [
        "--tuple-optimization", "--out", "out.wasm", "tuple-scrambled-copy-order.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "unexpected tuple-optimization scrambled tuple copy carrier failure: \{e}",
      )
  }
  @debug.assert_eq(writes.length(), 1)
  let out = decode_module_bytes(writes[0].1)
  let pretty = out.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_not_eq(pretty, input_mod.pretty_print_func(@lib.FuncIdx::new(2U)))
  match out.type_sec {
    Some(@lib.TypeSec(types)) => @debug.assert_eq(types.length(), 4)
    None => fail("expected scrambled tuple copy carrier output type sec")
  }
  assert_true(pretty.contains("(block (Type 3)"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 8))"), msg=pretty)
  assert_false(
    pretty.contains("(local.set (Local 14))(local.get (Local 6))"),
    msg=pretty,
  )
}

///|
test "run_cmd_with_adapter tuple-optimization rewrites root local.set copy groups through a typed multivalue carrier" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 2 local.set 1 local.set 0 local.get 0 local.get 1 local.get 2 call 1 local.set 9 local.get 9))",
      filename="tuple-root-copy-order.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "unexpected root local.set tuple copy carrier fixture parse failure: \{err}",
      )
  }
  let wasm = encode_module_bytes(input_mod)
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-root-copy-order.wasm"] },
    file_exists=fn(path) { path == "tuple-root-copy-order.wasm" },
    read_file=fn(path) {
      if path == "tuple-root-copy-order.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(
      [
        "--tuple-optimization", "--out", "out.wasm", "tuple-root-copy-order.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "unexpected tuple-optimization root local.set tuple copy carrier failure: \{e}",
      )
  }
  @debug.assert_eq(writes.length(), 1)
  let out = decode_module_bytes(writes[0].1)
  let pretty = out.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_not_eq(pretty, input_mod.pretty_print_func(@lib.FuncIdx::new(2U)))
  match out.type_sec {
    Some(@lib.TypeSec(types)) => @debug.assert_eq(types.length(), 4)
    None => fail("expected root local.set tuple copy carrier output type sec")
  }
  assert_true(pretty.contains("(block (Type 3)"), msg=pretty)
  assert_false(
    pretty.contains(
      "(local.get (Local 6))(local.set (Local 2))(local.get (Local 7))(local.set (Local 1))(local.get (Local 8))(local.set (Local 0))",
    ),
    msg=pretty,
  )
}

///|
test "run_cmd_with_adapter tuple-optimization keeps mixed scalar-forward bridges from direct producers on scalar locals" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 local.get 8 local.get 7 local.get 6 call 1 local.set 0 local.get 0))",
      filename="tuple-direct-mixed-forward.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "unexpected mixed direct-producer tuple bridge fixture parse failure: \{err}",
      )
  }
  let wasm = encode_module_bytes(input_mod)
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-direct-mixed-forward.wasm"] },
    file_exists=fn(path) { path == "tuple-direct-mixed-forward.wasm" },
    read_file=fn(path) {
      if path == "tuple-direct-mixed-forward.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(
      [
        "--tuple-optimization", "--out", "out.wasm", "tuple-direct-mixed-forward.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "unexpected tuple-optimization mixed direct-producer bridge failure: \{e}",
      )
  }
  @debug.assert_eq(writes.length(), 1)
  let out = decode_module_bytes(writes[0].1)
  let pretty = out.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("call (Func 1)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 8)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 7)"), msg=pretty)
  assert_false(pretty.contains("tuple.make"), msg=pretty)
  assert_false(pretty.contains("tuple.extract"), msg=pretty)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected mixed direct-producer scalar bridge output to validate, got \{err}",
      )
  }
}

///|
test "run_cmd_with_adapter tuple-optimization keeps chained mixed scalar-forward bridges on scalar locals" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 local.get 7 local.set 9 local.get 8 local.get 9 local.get 6 call 1 local.set 0 local.get 0))",
      filename="tuple-direct-chained-forward.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "unexpected chained direct-producer tuple bridge fixture parse failure: \{err}",
      )
  }
  let wasm = encode_module_bytes(input_mod)
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-direct-chained-forward.wasm"] },
    file_exists=fn(path) { path == "tuple-direct-chained-forward.wasm" },
    read_file=fn(path) {
      if path == "tuple-direct-chained-forward.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(
      [
        "--tuple-optimization", "--out", "out.wasm", "tuple-direct-chained-forward.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "unexpected tuple-optimization chained direct-producer bridge failure: \{e}",
      )
  }
  @debug.assert_eq(writes.length(), 1)
  let out = decode_module_bytes(writes[0].1)
  let pretty = out.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("call (Func 1)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 8)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 9)"), msg=pretty)
  assert_false(pretty.contains("tuple.make"), msg=pretty)
  assert_false(pretty.contains("tuple.extract"), msg=pretty)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected chained direct-producer scalar bridge output to validate, got \{err}",
      )
  }
}

///|
test "run_cmd_with_adapter tuple-optimization stages chained host-copy tail-live0 repro through typed carriers" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.tee 6 local.set 11 local.get 7 local.set 10 block (result i32 i32 i32) local.get 11 local.get 10 local.get 8 end local.set 5 local.set 4 local.tee 3 block (result i32 i32 i32) local.get 3 local.get 4 local.get 5 end local.set 2 local.set 1 local.tee 0 drop drop local.get 0))",
      filename="tuple-host-tail-live0.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "unexpected tuple-optimization chained host-copy repro fixture parse failure: \{err}",
      )
  }
  let wasm = encode_module_bytes(input_mod)
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-host-tail-live0.wasm"] },
    file_exists=fn(path) { path == "tuple-host-tail-live0.wasm" },
    read_file=fn(path) {
      if path == "tuple-host-tail-live0.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(
      [
        "--tuple-optimization", "--out", "out.wasm", "tuple-host-tail-live0.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "unexpected tuple-optimization chained host-copy repro failure: \{e}",
      )
  }
  @debug.assert_eq(writes.length(), 1)
  let out = decode_module_bytes(writes[0].1)
  let pretty = out.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(count_substring(pretty, "local.tee") >= 2, msg=pretty)
  assert_true(pretty.contains("(local.set (Local 15))"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 15))"), msg=pretty)
  assert_false(
    pretty.contains(
      "(local.get (Local 8))(local.set (Local 14))(local.get (Local 10))(local.set (Local 13))(local.get (Local 11))(local.set (Local 12))",
    ),
    msg=pretty,
  )
  assert_false(
    pretty.contains(
      "(local.get (Local 5))(local.set (Local 17))(local.get (Local 4))(local.set (Local 16))(local.get (Local 3))(local.set (Local 15))",
    ),
    msg=pretty,
  )
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter validates ssa-nomerge on debug artifact" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--ssa-nomerge", "--out", output_path, input_path],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("expected ssa-nomerge artifact replay success, got \{e}")
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  ignore(decode_module_bytes(writes[0].1))
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter ssa-nomerge extracted func 523 avoids writeback type-mismatch skips" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let stderr_chunks : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
    write_stderr=fn(bytes) {
      stderr_chunks.push(bytes)
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--extract-functions=523", "--tracing", "pass", "--ssa-nomerge", "--out",
        output_path, input_path,
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected extracted func 523 ssa-nomerge replay success, got \{e}")
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, [
    "extract-functions=523", "ssa-nomerge",
  ])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected extracted func 523 replay output to validate, got \{err}")
  }
  let stderr = concat_ascii_bytes(stderr_chunks)
  assert_false(
    stderr.contains(
      "pass[ssa-nomerge]:skip-invalid-lower func=(Func 15) reason=writeback-validate:type mismatch",
    ),
    msg=stderr,
  )
}

///|
test "run_cmd_with_adapter folds HSO readonly mutable-global prefixes into struct.new" {
  let wasm = encode_module_bytes(fixture_hso_nonlocal_readonly_prefix_module())
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso.wasm"] },
    file_exists=fn(path) { path == "hso.wasm" },
    read_file=fn(path) {
      if path == "hso.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--heap-store-optimization", "--out", "out.wasm", "hso.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected heap-store-optimization run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter folds tee HSO readonly mutable-global prefixes into struct.new" {
  let wasm = encode_module_bytes(
    fixture_hso_tee_nonlocal_readonly_prefix_module(),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-tee.wasm"] },
    file_exists=fn(path) { path == "hso-tee.wasm" },
    read_file=fn(path) {
      if path == "hso-tee.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--heap-store-optimization", "--out", "out.wasm", "hso-tee.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected tee heap-store-optimization run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter folds tee HSO pure multi-root block values into struct.new" {
  let wasm = encode_module_bytes(fixture_hso_tee_pure_block_prefix_module())
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-tee-pure.wasm"] },
    file_exists=fn(path) { path == "hso-tee-pure.wasm" },
    read_file=fn(path) {
      if path == "hso-tee-pure.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--heap-store-optimization", "--out", "out.wasm", "hso-tee-pure.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "unexpected tee pure-block heap-store-optimization run failure: \{e}",
      )
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter folds tee HSO pure multi-root block ref results into struct.new" {
  let wasm = encode_module_bytes(
    fixture_hso_tee_pure_block_prefix_ref_result_module(),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-tee-pure-ref.wasm"] },
    file_exists=fn(path) { path == "hso-tee-pure-ref.wasm" },
    read_file=fn(path) {
      if path == "hso-tee-pure-ref.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--heap-store-optimization", "--out", "out.wasm", "hso-tee-pure-ref.wasm",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "unexpected tee pure-block ref-result heap-store-optimization run failure: \{e}",
      )
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter folds direct HSO pure prefix blocks into struct.new" {
  let wasm = encode_module_bytes(fixture_hso_direct_pure_block_prefix_module())
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-direct-pure.wasm"] },
    file_exists=fn(path) { path == "hso-direct-pure.wasm" },
    read_file=fn(path) {
      if path == "hso-direct-pure.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--heap-store-optimization", "--out", "out.wasm", "hso-direct-pure.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "unexpected direct pure-prefix heap-store-optimization run failure: \{e}",
      )
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter folds direct HSO pure prefix ref results into struct.new" {
  let wasm = encode_module_bytes(
    fixture_hso_direct_pure_block_prefix_ref_result_module(),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-direct-pure-ref.wasm"] },
    file_exists=fn(path) { path == "hso-direct-pure-ref.wasm" },
    read_file=fn(path) {
      if path == "hso-direct-pure-ref.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--heap-store-optimization", "--out", "out.wasm", "hso-direct-pure-ref.wasm",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "unexpected direct pure-prefix ref-result heap-store-optimization run failure: \{e}",
      )
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter trims unreachable tails in folded HSO branch values" {
  let wasm = encode_module_bytes(fixture_hso_branch_fold_module())
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-branch-fold.wasm"] },
    file_exists=fn(path) { path == "hso-branch-fold.wasm" },
    read_file=fn(path) {
      if path == "hso-branch-fold.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--heap-store-optimization", "--out", "out.wasm", "hso-branch-fold.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected branch-fold HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_false(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "run_cmd_with_adapter trims unreachable tails in non-folded HSO local branch values" {
  let wasm = encode_module_bytes(fixture_hso_local_branch_trim_module())
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-local-branch.wasm"] },
    file_exists=fn(path) { path == "hso-local-branch.wasm" },
    read_file=fn(path) {
      if path == "hso-local-branch.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--heap-store-optimization", "--out", "out.wasm", "hso-local-branch.wasm",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected local-branch HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_false(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "run_cmd_with_adapter folds HSO memory-size branch values" {
  let wasm = encode_module_bytes(fixture_hso_memory_branch_fold_module())
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-memory-branch.wasm"] },
    file_exists=fn(path) { path == "hso-memory-branch.wasm" },
    read_file=fn(path) {
      if path == "hso-memory-branch.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--heap-store-optimization", "--out", "out.wasm", "hso-memory-branch.wasm",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected memory-branch HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_false(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "run_cmd_with_adapter folds tee HSO memory-size branch values" {
  let wasm = encode_module_bytes(
    fixture_hso_tee_memory_branch_fold_ref_result_module(),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-tee-memory-branch.wasm"] },
    file_exists=fn(path) { path == "hso-tee-memory-branch.wasm" },
    read_file=fn(path) {
      if path == "hso-tee-memory-branch.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--heap-store-optimization", "--out", "out.wasm", "hso-tee-memory-branch.wasm",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected tee memory-branch HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_false(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "run_cmd_with_adapter trims tails after nested branch exits in folded HSO values" {
  let wasm = encode_module_bytes(
    fixture_hso_nested_branch_trim_ref_result_module(),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-nested-branch.wasm"] },
    file_exists=fn(path) { path == "hso-nested-branch.wasm" },
    read_file=fn(path) {
      if path == "hso-nested-branch.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--heap-store-optimization", "--out", "out.wasm", "hso-nested-branch.wasm",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected nested-branch HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_false(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "run_cmd_with_adapter trims loop tails after folded HSO exits to the outer block" {
  let wasm = encode_module_bytes(fixture_hso_loop_exit_trim_ref_result_module())
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-loop-exit.wasm"] },
    file_exists=fn(path) { path == "hso-loop-exit.wasm" },
    read_file=fn(path) {
      if path == "hso-loop-exit.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--heap-store-optimization", "--out", "out.wasm", "hso-loop-exit.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected loop-exit HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_false(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "run_cmd_with_adapter drops stale label names after HSO relowers named control" {
  let wasm = encode_module_bytes(
    module_with_label_names(fixture_hso_loop_exit_trim_ref_result_module(), 2),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-loop-names.wasm"] },
    file_exists=fn(path) { path == "hso-loop-names.wasm" },
    read_file=fn(path) {
      if path == "hso-loop-names.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--heap-store-optimization", "--out", "out.wasm", "hso-loop-names.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected named-label HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  match optimized.name_sec {
    Some(name_sec) => assert_true(name_sec.label_names is None)
    None => ()
  }
}

///|
test "run_cmd_with_adapter preserves label names when HSO raw-skips every function" {
  let wasm = encode_module_bytes(
    module_with_label_names(fixture_mergeable_block_module(), 1),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-skip-names.wasm"] },
    file_exists=fn(path) { path == "hso-skip-names.wasm" },
    read_file=fn(path) {
      if path == "hso-skip-names.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--heap-store-optimization", "--out", "out.wasm", "hso-skip-names.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected raw-skip named-label HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  match optimized.name_sec {
    Some(name_sec) => assert_true(name_sec.label_names is Some(_))
    None => fail("expected preserved name section after raw-skip HSO")
  }
}

///|
test "run_cmd_with_adapter folds swapped-root HSO readonly mutable-global prefixes into struct.new" {
  let wasm = encode_module_bytes(
    fixture_hso_swapped_nonlocal_readonly_prefix_module(),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-swap.wasm"] },
    file_exists=fn(path) { path == "hso-swap.wasm" },
    read_file=fn(path) {
      if path == "hso-swap.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--heap-store-optimization", "--out", "out.wasm", "hso-swap.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail("unexpected swapped heap-store-optimization run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter keeps swapped HSO peeled prefix roots valid after nop cleanup" {
  let wasm = fixture_hso_swapped_inner_branch_prefix_ref_result_wasm()
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-swap-nop.wasm"] },
    file_exists=fn(path) { path == "hso-swap-nop.wasm" },
    read_file=fn(path) {
      if path == "hso-swap-nop.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--heap-store-optimization", "--out", "out.wasm", "hso-swap-nop.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected swapped-nop HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected swapped-nop HSO output to validate after cleanup, got \{err}",
      )
  }
}

///|
test "run_cmd_with_adapter flattens nested if-tail wrappers inside folded HSO values" {
  let wasm = fixture_hso_nested_if_tail_ref_result_wasm()
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-nested-if.wasm"] },
    file_exists=fn(path) { path == "hso-nested-if.wasm" },
    read_file=fn(path) {
      if path == "hso-nested-if.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--heap-store-optimization", "--out", "out.wasm", "hso-nested-if.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected nested-if-tail HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected flattened nested if-tail HSO output to validate, got \{err}",
      )
  }
}

///|
test "run_cmd_with_adapter keeps wrapped-ref if conditions outside HSO scratch blocks" {
  let wasm = fixture_hso_wrapped_ref_if_branch_prefix_ref_result_wasm()
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-wrapped-ref-if.wasm"] },
    file_exists=fn(path) { path == "hso-wrapped-ref-if.wasm" },
    read_file=fn(path) {
      if path == "hso-wrapped-ref-if.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--heap-store-optimization", "--out", "out.wasm", "hso-wrapped-ref-if.wasm",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected wrapped-ref if-branch HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("block"), msg=pretty)
}

///|
test "run_cmd_with_adapter folds HSO readonly ref-prefix memory.size as a size win" {
  let wasm = fixture_hso_memory_size_ref_prefix_wasm()
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-mem-ref.wasm"] },
    file_exists=fn(path) { path == "hso-mem-ref.wasm" },
    read_file=fn(path) {
      if path == "hso-mem-ref.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--heap-store-optimization", "--out", "out.wasm", "hso-mem-ref.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected memory ref-prefix HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  // Binaryen v131 keeps 61 stripped bytes; Starshine emits 60.
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter folds HSO pure ref-prefix ref-result as a size win" {
  let wasm = fixture_hso_pure_ref_prefix_ref_result_wasm()
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-pure-ref-result.wasm"] },
    file_exists=fn(path) { path == "hso-pure-ref-result.wasm" },
    read_file=fn(path) {
      if path == "hso-pure-ref-result.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--heap-store-optimization", "--out", "out.wasm", "hso-pure-ref-result.wasm",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected pure ref-result HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  // Binaryen v131 keeps 46 stripped bytes; Starshine emits 45.
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter keeps struct.set for HSO tee pure ref-prefix ref-result wasm inputs" {
  let wasm = fixture_hso_tee_pure_ref_prefix_ref_result_wasm()
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-tee-pure-ref-result.wasm"] },
    file_exists=fn(path) { path == "hso-tee-pure-ref-result.wasm" },
    read_file=fn(path) {
      if path == "hso-tee-pure-ref-result.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--heap-store-optimization", "--out", "out.wasm", "hso-tee-pure-ref-result.wasm",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected tee pure ref-result HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("local.tee"), msg=pretty)
}

///|
test "run_cmd_with_adapter folds HSO readonly value-prefix memory.size wasm inputs" {
  let wasm = encode_module_bytes(fixture_hso_memory_size_value_prefix_module())
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-mem-value.wasm"] },
    file_exists=fn(path) { path == "hso-mem-value.wasm" },
    read_file=fn(path) {
      if path == "hso-mem-value.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--heap-store-optimization", "--out", "out.wasm", "hso-mem-value.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected memory value-prefix HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter folds HSO table.size value prefixes as a size win" {
  let wasm = fixture_hso_table_size_value_prefix_wasm()
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-table-value.wasm"] },
    file_exists=fn(path) { path == "hso-table-value.wasm" },
    read_file=fn(path) {
      if path == "hso-table-value.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--heap-store-optimization", "--out", "out.wasm", "hso-table-value.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected table value-prefix HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  // Binaryen v131 keeps 63 stripped bytes; Starshine emits 62.
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter folds HSO local.get value prefixes as a size win" {
  let wasm = fixture_hso_local_value_prefix_wasm()
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-local-value.wasm"] },
    file_exists=fn(path) { path == "hso-local-value.wasm" },
    read_file=fn(path) {
      if path == "hso-local-value.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--heap-store-optimization", "--out", "out.wasm", "hso-local-value.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected local value-prefix HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  // Binaryen v131 keeps 66 stripped bytes; Starshine emits 65.
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter folds HSO immutable-global value prefixes as a size win" {
  let wasm = fixture_hso_immutable_global_value_prefix_wasm()
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-immut-global-value.wasm"] },
    file_exists=fn(path) { path == "hso-immut-global-value.wasm" },
    read_file=fn(path) {
      if path == "hso-immut-global-value.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--heap-store-optimization", "--out", "out.wasm", "hso-immut-global-value.wasm",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail("unexpected immutable-global value-prefix HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  // Binaryen v131 keeps 64 stripped bytes; Starshine emits 63.
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter folds HSO mutable-global value prefixes as a size win" {
  let wasm = fixture_hso_mutable_global_value_prefix_wasm()
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["hso-mut-global-value.wasm"] },
    file_exists=fn(path) { path == "hso-mut-global-value.wasm" },
    read_file=fn(path) {
      if path == "hso-mut-global-value.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--heap-store-optimization", "--out", "out.wasm", "hso-mut-global-value.wasm",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail("unexpected mutable-global value-prefix HSO run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  // Binaryen v131 keeps 64 stripped bytes; Starshine emits 63.
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter interleaves dump validate and optimize steps in cli order" {
  let wasm = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      "(module (func (result i32) (local i32) i32.const 5 local.set 0 local.get 0))",
    ),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["ssa.wasm"] },
    file_exists=fn(path) { path == "ssa.wasm" },
    read_file=fn(path) {
      if path == "ssa.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--dump", "before.wasm", "--ssa-nomerge", "--dump", "after.wasm", "--validate",
        "--out", "out.wasm", "ssa.wasm",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected dump/validate pipeline failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, [
    "dump=before.wasm", "ssa-nomerge", "dump=after.wasm", "validate",
  ])
  @debug.assert_eq(writes.length(), 3)
  @debug.assert_eq(writes[0].0, "before.wasm")
  @debug.assert_eq(writes[1].0, "after.wasm")
  @debug.assert_eq(writes[2].0, "out.wasm")

  let before = decode_module_bytes(writes[0].1)
  match before.code_sec {
    Some(CodeSec([Func(locals, Expr(instrs))])) => {
      @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
      @debug.assert_eq(instrs, [
        @lib.Instruction::i32_const(@lib.I32(5)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ])
    }
    _ => fail("expected original code section in before dump")
  }

  let after = decode_module_bytes(writes[1].1)
  match after.code_sec {
    Some(CodeSec([Func(locals, Expr(instrs))])) => {
      @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
      @debug.assert_eq(instrs, [
        @lib.Instruction::i32_const(@lib.I32(5)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ])
    }
    _ => fail("expected transformed code section in after dump")
  }

  let final_mod = decode_module_bytes(writes[2].1)
  @debug.assert_eq(final_mod, after)
}

///|
test "run_cmd_with_adapter extracts requested functions into a safe minimal module" {
  let wasm = encode_module_bytes(fixture_extract_functions_module())
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["extract.wasm"] },
    file_exists=fn(path) { path == "extract.wasm" },
    read_file=fn(path) {
      if path == "extract.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--extract-functions=4,3", "--out", "out.wasm", "extract.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected extract-functions pipeline failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["extract-functions=4,3"])
  @debug.assert_eq(writes.length(), 1)

  let optimized = decode_module_bytes(writes[0].1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected extracted module to validate, got \{err}")
  }

  match optimized.import_sec {
    Some(@lib.ImportSec(imports)) => {
      @debug.assert_eq(imports.length(), 1)
      match imports[0] {
        @lib.Import(module_name, field_name, @lib.FuncExternType(type_idx)) => {
          @debug.assert_eq(module_name, @lib.Name::new("env"))
          @debug.assert_eq(field_name, @lib.Name::new("keep_import"))
          @debug.assert_eq(type_idx, @lib.TypeIdx::new(0U))
        }
        other => fail("expected single live func import, got \{other}")
      }
    }
    other =>
      fail(
        "expected extracted module to keep one func import, got \{@debug.to_string(other)}",
      )
  }

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) =>
      @debug.assert_eq(type_idxs, [@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)])
    other =>
      fail(
        "expected two extracted defined functions, got \{@debug.to_string(other)}",
      )
  }
  match optimized.export_sec {
    Some(@lib.ExportSec(exports)) => {
      @debug.assert_eq(exports.length(), 2)
      @debug.assert_eq(exports, [
        @lib.Export::new(
          @lib.Name::new("helper"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
        ),
        @lib.Export::new(
          @lib.Name::new("keep"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(2U)),
        ),
      ])
    }
    other =>
      fail(
        "expected extracted function exports, got \{@debug.to_string(other)}",
      )
  }
  @debug.assert_eq(optimized.start_sec, None)
  @debug.assert_eq(
    optimized.table_sec,
    Some(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, None),
          ),
          None,
        ),
      ]),
    ),
  )
  @debug.assert_eq(
    optimized.mem_sec,
    Some(@lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))])),
  )
  match optimized.global_sec {
    Some(@lib.GlobalSec(globals)) => @debug.assert_eq(globals.length(), 1)
    other => fail("expected single live global, got \{@debug.to_string(other)}")
  }
  match optimized.elem_sec {
    Some(@lib.ElemSec(elems)) => @debug.assert_eq(elems.length(), 1)
    other =>
      fail("expected single live elem segment, got \{@debug.to_string(other)}")
  }
  @debug.assert_eq(
    optimized.data_cnt_sec,
    Some(@lib.DataCntSec::new(@lib.U32(1U))),
  )
  match optimized.data_sec {
    Some(@lib.DataSec(datas)) => @debug.assert_eq(datas.length(), 1)
    other =>
      fail("expected single live data segment, got \{@debug.to_string(other)}")
  }

  let helper_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(helper_pretty.contains("(Func 0)"), msg=helper_pretty)
  let keep_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(keep_pretty.contains("(Global 0)"), msg=keep_pretty)
  assert_true(keep_pretty.contains("(Mem 0)"), msg=keep_pretty)
  assert_true(keep_pretty.contains("(Table 0)"), msg=keep_pretty)
  assert_true(keep_pretty.contains("(Func 1)"), msg=keep_pretty)

  match module_name_section_order_error(optimized) {
    Some(err) => fail(err)
    None => ()
  }
}

///|
test "run_cmd_with_adapter writes wat dumps as text" {
  let wasm = encode_module_bytes(fixture_i32_const_module(41))
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    print_text_module=fn(_) {
      Ok(bytes_from_string("(module (func (result i32) i32.const 41))\n"))
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--dump", "snapshot.wat", "--out", "out.wasm", "a.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected wat dump failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["dump=snapshot.wat"])
  @debug.assert_eq(writes.length(), 2)
  @debug.assert_eq(writes[0].0, "snapshot.wat")
  let wat = bytes_to_ascii_string(writes[0].1)
  assert_true(wat.contains("(module"))
  assert_true(wat.contains("i32.const 41"))
  ignore(decode_module_bytes(writes[1].1))
}

///|
test "run_cmd_with_adapter dumps current module before explicit validate fails" {
  let wasm = encode_module_bytes(fixture_invalid_i32_result_module())
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["broken.wasm"] },
    file_exists=fn(path) { path == "broken.wasm" },
    read_file=fn(path) {
      if path == "broken.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(
      [
        "--dump", "before-invalid.wasm", "--validate", "--out", "out.wasm", "broken.wasm",
      ],
      io,
    ) {
    Ok(summary) => fail("expected validate failure after dump, got \{summary}")
    Err(CmdError::OptimizeFailed(msg)) =>
      assert_true(msg.contains("validate"), msg~)
    Err(err) => fail("expected validate failure, got \{err}")
  }
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, "before-invalid.wasm")
  ignore(decode_module_bytes(writes[0].1))
}

///|
test "run_cmd_with_adapter prints ordered log entries to stderr and sees post-pass state" {
  let wasm = encode_module_bytes(fixture_print_log_module())
  let writes : Array[(String, Bytes)] = []
  let stderr_writes : Array[Bytes] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["printable.wasm"] },
    file_exists=fn(path) { path == "printable.wasm" },
    read_file=fn(path) {
      if path == "printable.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
    write_stderr=fn(bytes) {
      stderr_writes.push(bytes)
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--print-type", "(0)", "--ssa-nomerge", "--print-func", "main", "--print-elem",
        "elist", "--out", "out.wasm", "printable.wasm",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected print pipeline failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, [
    "print-type=(0)", "ssa-nomerge", "print-func=main", "print-elem=elist",
  ])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, "out.wasm")

  let stderr_text = concat_ascii_bytes(stderr_writes)
  assert_true(stderr_text.contains("Log: printable.wasm"), msg=stderr_text)
  assert_strings_appear_in_order(stderr_text, [
    "0: Type[0", "1: Func[0", "2: Elem[0",
  ])
  assert_true(
    stderr_text.contains("(Sub Final (Func [] [I32]))"),
    msg=stderr_text,
  )
  assert_true(stderr_text.contains("local.set (Local 0)"), msg=stderr_text)
  assert_true(stderr_text.contains("(Elem "), msg=stderr_text)
}

///|
test "run_cmd_with_adapter rejects removed compatibility-only pass names" {
  let input_mod = fixture_mergeable_block_module()
  let input_wasm = encode_module_bytes(input_mod)
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(input_wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(["--re-reloop", "--out", "out.wasm", "a.wasm"], io) {
    Ok(summary) => fail("expected removed pass rejection, got \{summary}")
    Err(err) => @debug.assert_eq(err, CmdError::unknown_pass_flag("re-reloop"))
  }
  @debug.assert_eq(writes.length(), 0)
}

///|
test "run_cmd_with_adapter accepts remove-unused-brs" {
  let input_mod = fixture_mergeable_block_module()
  let input_wasm = encode_module_bytes(input_mod)
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(input_wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--remove-unused-brs", "--out", "out.wasm", "a.wasm"],
      io,
    ) {
    Ok(summary) => summary
    Err(err) => fail("expected remove-unused-brs cli success, got \{err}")
  }
  @debug.assert_eq(summary.resolved_passes, ["remove-unused-brs"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, "out.wasm")
}

///|
test "run_cmd_with_adapter accepts code-pushing" {
  let input_mod = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (func (param i32) (local i32)
      #|    i32.const 7 local.set 1
      #|    local.get 0 if nop end
      #|    i32.const 0 drop)
      #|  (func (param i32) (local i32)
      #|    i32.const 8 local.set 1
      #|    local.get 0 if (result i32) i32.const 1 else i32.const 2 end drop
      #|    i32.const 0 drop)
      #|  (func (param i32) (local i32)
      #|    block
      #|      i32.const 9 local.set 1
      #|      local.get 0 br_if 0
      #|      i32.const 0 drop
      #|    end))
      #|
    ),
  )
  let input_wasm = encode_module_bytes(input_mod)
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(input_wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )

  let summary = match
    run_cmd_with_adapter(["--code-pushing", "--out", "out.wasm", "a.wasm"], io) {
    Ok(summary) => summary
    Err(err) => fail("expected code-pushing cli success, got \{err}")
  }
  @debug.assert_eq(summary.resolved_passes, ["code-pushing"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, "out.wasm")
  let optimized = decode_module_bytes(writes[0].1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected code-pushing output to validate, got \{err}")
  }
  let funcs = match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("expected code-pushing output functions")
  }
  @debug.assert_eq(funcs.length(), 3)
  let first_body = match funcs[0] {
    @lib.Func(_, @lib.Expr(body)) => body
  }
  match (first_body[1], first_body[3]) {
    (@lib.If(_, _, _), @lib.LocalSet(@lib.LocalIdx(1U))) => ()
    other =>
      fail(
        "expected zero-read set after ordinary if, got \{@debug.to_string(other)}",
      )
  }
  let second_body = match funcs[1] {
    @lib.Func(_, @lib.Expr(body)) => body
  }
  match (second_body[1], second_body[2], second_body[4]) {
    (@lib.If(_, _, _), @lib.Drop, @lib.LocalSet(@lib.LocalIdx(1U))) => ()
    other =>
      fail(
        "expected zero-read set after dropped if, got \{@debug.to_string(other)}",
      )
  }
  let third_body = match funcs[2] {
    @lib.Func(_, @lib.Expr(body)) => body
  }
  match third_body {
    [@lib.Block(_, @lib.Expr(block_body))] =>
      match (block_body[1], block_body[3]) {
        (@lib.BrIf(@lib.LabelIdx(0U)), @lib.LocalSet(@lib.LocalIdx(1U))) => ()
        other =>
          fail(
            "expected zero-read set after br_if, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected block-wrapped br_if output, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "run_cmd_with_adapter accepts redundant-set-elimination" {
  let input_mod = @passes.pass_test_module_from_wat(
    "(module (func (local i32) i32.const 1 local.set 0 i32.const 1 local.set 0))",
  )
  let input_wasm = encode_module_bytes(input_mod)
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(input_wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )

  let summary = match
    run_cmd_with_adapter(
      ["--redundant-set-elimination", "--out", "out.wasm", "a.wasm"],
      io,
    ) {
    Ok(summary) => summary
    Err(err) =>
      fail("expected redundant-set-elimination cli success, got \{err}")
  }
  @debug.assert_eq(summary.resolved_passes, ["redundant-set-elimination"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, "out.wasm")
  match @validate.validate_module(decode_module_bytes(writes[0].1)) {
    Ok(_) => ()
    Err(err) =>
      fail("expected redundant-set-elimination output to validate, got \{err}")
  }
}

///|
#cfg(target="native")
test "run_cmd_with_adapter keeps lowered remove-unused-brs carried guard branches valid" {
  let source =
    #|(module
    #|  (func (param i32)
    #|    (drop
    #|      (local.get 0)))
    #|  (func (param i32 i32) (result i32)
    #|    (local.get 0))
    #|  (func (param i32 i32 i32 i32) (result i32)
    #|    (local i32 i32 i32 i32 i32)
    #|    (block (result i32)
    #|      (if
    #|        (local.get 0)
    #|        (then
    #|          (local.set 1
    #|            (local.get 1))
    #|          (drop
    #|            (block (result i32)
    #|              (block
    #|                (br_if 0
    #|                  (if (result i32)
    #|                    (local.get 0)
    #|                    (then
    #|                      (i32.const 1))
    #|                    (else
    #|                      (local.set 2
    #|                        (local.get 2))
    #|                      (local.set 3
    #|                        (local.get 3))
    #|                      (i32.le_s
    #|                        (local.get 2)
    #|                        (local.get 3)))))
    #|                (call 0
    #|                  (local.get 1))
    #|                (drop
    #|                  (i32.const 0))
    #|                (local.set 2
    #|                  (local.get 2))
    #|                (call 0
    #|                  (local.get 0))
    #|                (local.set 3
    #|                  (call 1
    #|                    (local.get 0)
    #|                    (local.get 2))))
    #|              (br 1
    #|                (local.tee 4
    #|                  (i32.add
    #|                    (local.get 1)
    #|                    (i32.const 1)))))))
    #|        (else
    #|          (call 0
    #|            (local.get 2))
    #|          (call 0
    #|            (local.get 3))))
    #|      (i32.const 0))))
  let input_wasm = match native_wat_to_wasm_bytes_for_test(source) {
    Ok(bytes) => bytes
    Err(err) =>
      fail(
        "expected carried guard wrapper fixture lowering success, got \{err}",
      )
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(input_wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--remove-unused-brs", "--out", "out.wasm", "a.wasm"],
      io,
    ) {
    Ok(summary) => summary
    Err(err) =>
      fail(
        "expected carried guard wrapper remove-unused-brs cli success, got \{err}",
      )
  }
  @debug.assert_eq(summary.resolved_passes, ["remove-unused-brs"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, "out.wasm")
  let wat = match native_normalize_wasm_bytes_to_wat_for_test(writes[0].1) {
    Ok(text) => text
    Err(err) =>
      fail("expected carried guard wrapper normalization success, got \{err}")
  }
  assert_true(wat.contains("(br_if $block"), msg=wat)
  match @validate.validate_module(decode_module_bytes(writes[0].1)) {
    Ok(_) => ()
    Err(err) =>
      fail("expected carried guard branch output to validate, got \{err}")
  }
}

///|
test "run_cmd_with_adapter preserves repeated pass flags in cli order" {
  let wasm = encode_module_bytes(fixture_i32_const_module(4))
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = match
    run_cmd_with_adapter(["--vacuum", "--optimize", "--vacuum", "a.wasm"], io) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["vacuum", "optimize", "vacuum"])
}

///|
test "run_cmd_with_adapter applies duplicate-function-elimination to wasm inputs" {
  let wasm = encode_module_bytes(fixture_duplicate_function_module())
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["dup.wasm"] },
    file_exists=fn(path) { path == "dup.wasm" },
    read_file=fn(path) {
      if path == "dup.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--duplicate-function-elimination", "--out", "out.wasm", "dup.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["duplicate-function-elimination"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  match optimized.code_sec {
    Some(CodeSec(funcs)) => @debug.assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
}

///|
test "run_cmd_with_adapter applies duplicate-import-elimination to wasm inputs" {
  let source =
    #|(module
    #|  (type $v (func))
    #|  (import "env" "waka" (func $foo (type $v)))
    #|  (import "env" "waka" (func $bar (type $v)))
    #|  (func (call $bar))
    #|)
    #|,
  let wasm = encode_module_bytes(@passes.pass_test_module_from_wat(source))
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["die.wasm"] },
    file_exists=fn(path) { path == "die.wasm" },
    read_file=fn(path) {
      if path == "die.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--duplicate-import-elimination", "--out", "out.wasm", "die.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["duplicate-import-elimination"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  match optimized.import_sec {
    Some(ImportSec([Import(_, _, FuncExternType(_))])) => ()
    other =>
      fail(
        "expected one surviving function import, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "run_cmd_with_adapter accepts string-gathering as an active module pass" {
  let source =
    #|(module
    #|  (func (result i32) i32.const 7)
    #|)
    #|,
  let wasm = encode_module_bytes(@passes.pass_test_module_from_wat(source))
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["sg.wasm"] },
    file_exists=fn(path) { path == "sg.wasm" },
    read_file=fn(path) {
      if path == "sg.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--string-gathering", "--out", "out.wasm", "sg.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["string-gathering"])
  @debug.assert_eq(writes.length(), 1)
}

///|
test "run_cmd_with_adapter accepts reorder-globals as an active module pass" {
  let source =
    #|(module
    #|  (global $a i32 (i32.const 1))
    #|  (global $b i32 (i32.const 2))
    #|  (func (drop (global.get $b)))
    #|)
    #|,
  let wasm = encode_module_bytes(@passes.pass_test_module_from_wat(source))
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["rg.wasm"] },
    file_exists=fn(path) { path == "rg.wasm" },
    read_file=fn(path) {
      if path == "rg.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--reorder-globals", "--out", "out.wasm", "rg.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["reorder-globals"])
  @debug.assert_eq(writes.length(), 1)
}

///|
test "run_cmd_with_adapter applies remove-unused-module-elements to wasm inputs" {
  let wasm = encode_module_bytes(fixture_remove_unused_module_elements_module())
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["rume.wasm"] },
    file_exists=fn(path) { path == "rume.wasm" },
    read_file=fn(path) {
      if path == "rume.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--remove-unused-module-elements", "--out", "out.wasm", "rume.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["remove-unused-module-elements"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  match optimized.code_sec {
    Some(CodeSec(funcs)) => @debug.assert_eq(funcs.length(), 1)
    None => fail("expected code section")
  }
}

///|
test "run_cmd_with_adapter accepts untee as an active module pass" {
  let wasm = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      "(module (func (result i32) (local i32) i32.const 7 local.tee 0))",
    ),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["untee.wasm"] },
    file_exists=fn(path) { path == "untee.wasm" },
    read_file=fn(path) {
      if path == "untee.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(["--untee", "--out", "out.wasm", "untee.wasm"], io) {
    Ok(v) => v
    Err(e) => fail("unexpected untee run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["untee"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.I32Const(_),
                @lib.LocalSet(@lib.LocalIdx(0U)),
                @lib.LocalGet(@lib.LocalIdx(0U)),
              ]
            )
          ),
        ]
      )
    ) => ()
    other =>
      fail("expected untee-expanded output, got \{@debug.to_string(other)}")
  }
}

///|
test "run_cmd_with_adapter applies reorder-locals to wasm inputs" {
  let wasm = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      "(module (func (result i32) (local i32 i64) i64.const 11 local.set 1 i32.const 7))",
    ),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["rl.wasm"] },
    file_exists=fn(path) { path == "rl.wasm" },
    read_file=fn(path) {
      if path == "rl.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--reorder-locals", "--out", "out.wasm", "rl.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["reorder-locals"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  match optimized.code_sec {
    Some(CodeSec([Func(locals, Expr(instrs))])) => {
      @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i64()]))
      @debug.assert_eq(
        instrs[1],
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      )
    }
    Some(_) => fail("expected single defined function")
    None => fail("expected code section")
  }
}

///|
test "run_cmd_with_adapter encodes reorder-locals same-type index remaps" {
  let wasm = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      "(module (func (result i32) (local i32 i32) i32.const 10 local.set 0 i32.const 20 local.set 1 local.get 1 drop local.get 1))",
    ),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["rl-same-type.wasm"] },
    file_exists=fn(path) { path == "rl-same-type.wasm" },
    read_file=fn(path) {
      if path == "rl-same-type.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--reorder-locals", "--out", "out.wasm", "rl-same-type.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["reorder-locals"])
  @debug.assert_eq(writes.length(), 1)
  assert_false(writes[0].1 == wasm)
  let optimized = decode_module_bytes(writes[0].1)
  match optimized.code_sec {
    Some(CodeSec([Func(locals, Expr(instrs))])) => {
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
    }
    Some(_) => fail("expected single defined function")
    None => fail("expected code section")
  }
}

///|
test "run_cmd_with_adapter applies local-subtyping to wasm inputs" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_nullable_ref = @lib.RefType::new(
    true,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let child_nullable = @lib.ValType::ref_type(child_nullable_ref)
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
  let mod_ = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([base, child, func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([base_nullable]),
          @lib.Expr::new([
            @lib.Instruction::ref_null_type(child_nullable_ref),
            @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let wasm = encode_module_bytes(mod_)
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["ls.wasm"] },
    file_exists=fn(path) { path == "ls.wasm" },
    read_file=fn(path) {
      if path == "ls.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--local-subtyping", "--out", "out.wasm", "ls.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["local-subtyping"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  match optimized.code_sec {
    Some(CodeSec([Func(locals, _)])) =>
      @debug.assert_eq(locals, @lib.Locals::from_types([child_nullable]))
    Some(_) => fail("expected single defined function")
    None => fail("expected code section")
  }
}

///|
test "run_cmd_with_adapter applies coalesce-locals to wasm inputs" {
  let wasm = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      "(module (func (result i32) (local i32 i32) i32.const 11 local.set 0 local.get 0 drop i32.const 22 local.set 1 local.get 1))",
    ),
  )
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["cl.wasm"] },
    file_exists=fn(path) { path == "cl.wasm" },
    read_file=fn(path) {
      if path == "cl.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--coalesce-locals", "--out", "out.wasm", "cl.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["coalesce-locals"])
  @debug.assert_eq(writes.length(), 1)
  let optimized = decode_module_bytes(writes[0].1)
  match optimized.code_sec {
    Some(CodeSec([Func(locals, Expr(instrs))])) => {
      @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
      @debug.assert_eq(
        instrs[5],
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      )
      @debug.assert_eq(
        instrs[6],
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      )
    }
    Some(_) => fail("expected single defined function")
    None => fail("expected code section")
  }
}

///|
test "run_cmd_with_adapter reuses original wasm bytes when RUME is unchanged" {
  let wasm = encode_module_bytes(fixture_rume_noop_module())
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    encode_module=fn(_) {
      abort(
        "encode_module should not run when unchanged wasm bytes can pass through",
      )
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--remove-unused-module-elements", "--out", "out.wasm", "a.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("expected unchanged RUME success, got \{e}")
  }
  @debug.assert_eq(summary.output_files, ["out.wasm"])
  @debug.assert_eq(writes, [("out.wasm", wasm)])
}

///|
test "run_cmd_with_adapter still encodes changed RUME outputs" {
  let wasm = encode_module_bytes(fixture_remove_unused_module_elements_module())
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    encode_module=fn(_) { Ok(b"encoded-changed-rume") },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--remove-unused-module-elements", "--out", "out.wasm", "a.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("expected changed RUME success, got \{e}")
  }
  @debug.assert_eq(summary.output_files, ["out.wasm"])
  @debug.assert_eq(writes, [("out.wasm", b"encoded-changed-rume")])
}

///|
test "config and optimize option construction preserve Binaryen inlining tuning" {
  let config =
    #|{
    #|  "options": {
    #|    "alwaysInlineMaxFunctionSize": 3,
    #|    "one-caller-inline-max-function-size": -1,
    #|    "flexibleInlineMaxFunctionSize": 31,
    #|    "inline-max-combined-binary-size": 500000,
    #|    "inlineFunctionsWithLoops": true,
    #|    "partial-inlining-ifs": 4
    #|  }
    #|}
  let parsed = match parse_config_json(config) {
    Ok(value) => value
    Err(err) => fail("unexpected inlining config parse failure: \{err}")
  }
  @debug.assert_eq(parsed.inlining_always_inline_max_size, Some(3))
  @debug.assert_eq(parsed.inlining_one_caller_inline_max_size, Some(-1))
  @debug.assert_eq(parsed.inlining_flexible_inline_max_size, Some(31))
  @debug.assert_eq(parsed.inlining_max_combined_binary_size, Some(500000))
  @debug.assert_eq(parsed.inlining_allow_functions_with_loops, Some(true))
  @debug.assert_eq(parsed.inlining_partial_inlining_ifs, Some(4))
  let options = make_optimize_options(
    3, 0, false, false, 5, 3, -1, 31, 500000, true, 4, false, false, false, 1024UL,
    false,
  )
  @debug.assert_eq(options.inlining.always_inline_max_size, 3)
  @debug.assert_eq(options.inlining.one_caller_inline_max_size, -1)
  @debug.assert_eq(options.inlining.flexible_inline_max_size, 31)
  @debug.assert_eq(options.inlining.max_combined_binary_size, 500000)
  assert_true(options.inlining.allow_functions_with_loops)
  @debug.assert_eq(options.inlining.partial_inlining_ifs, 4)
}

///|
test "run_cmd_with_adapter uses config passes when cli does not provide pass flags" {
  let config_json =
    #|{
    #|  "inputs": { "globs": ["cfg.wasm", "cli.wasm"] },
    #|  "outputs": { "outDir": "cfg-dist" },
    #|  "passes": ["vacuum"],
    #|  "optimize": { "trapMode": "never", "olevel": "O3" },
    #|  "options": {
    #|    "monomorphizeMinBenefit": 2,
    #|    "closedWorld": true,
    #|    "lowMemoryUnused": true,
    #|    "lowMemoryBound": 4096
    #|  }
    #|}
  let wasm = encode_module_bytes(fixture_i32_const_module(5))
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["cfg.wasm", "cli.wasm"] },
    file_exists=fn(path) {
      path == "cfg.json" || path == "cfg.wasm" || path == "cli.wasm"
    },
    read_file=fn(path) {
      match path {
        "cfg.json" => Ok(bytes_from_string(config_json))
        "cfg.wasm" | "cli.wasm" => Ok(wasm)
        _ => Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--config", "cfg.json", "--out-dir", "cli-dist", "-O1", "--trap-mode", "allow",
        "--monomorphize-min-benefit", "11", "--no-low-memory-unused", "--low-memory-bound",
        "2048", "--no-closed-world", "cli.wasm",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  assert_true(has_string(summary.input_files, "cfg.wasm"))
  assert_true(has_string(summary.input_files, "cli.wasm"))
  assert_true(has_string(summary.resolved_passes, "vacuum"))
  @debug.assert_eq(summary.resolved_passes, ["vacuum"])
  @debug.assert_eq(summary.optimize_level, 1)
  @debug.assert_eq(summary.traps_never_happen, false)
  @debug.assert_eq(summary.monomorphize_min_benefit, 11)
  @debug.assert_eq(summary.closed_world, false)
  @debug.assert_eq(summary.low_memory_unused, false)
  @debug.assert_eq(summary.low_memory_bound, 2048UL)
  for entry in writes {
    let (path, _) = entry
    assert_true(path.has_prefix("cli-dist/"))
  }
}

///|
test "run_cmd_with_adapter lets cli pass flags override config pass lists" {
  let config_json =
    #|{
    #|  "inputs": { "globs": ["a.wasm"] },
    #|  "passes": ["vacuum", "remove-unused-names"]
    #|}
  let wasm = encode_module_bytes(fixture_i32_const_module(6))
  let io = CmdIO::new(
    file_exists=fn(path) { path == "cfg.json" || path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      match path {
        "cfg.json" => Ok(bytes_from_string(config_json))
        "a.wasm" => Ok(wasm)
        _ => Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = match
    run_cmd_with_adapter(["--config", "cfg.json", "--vacuum", "a.wasm"], io) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["vacuum"])
}

///|
test "run_cmd_with_adapter ignores unknown config pass flags when cli pass flags are present" {
  let config_json =
    #|{
    #|  "inputs": { "globs": ["a.wasm"] },
    #|  "passes": ["not-a-real-pass"]
    #|}
  let wasm = encode_module_bytes(fixture_i32_const_module(8))
  let io = CmdIO::new(
    file_exists=fn(path) { path == "cfg.json" || path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      match path {
        "cfg.json" => Ok(bytes_from_string(config_json))
        "a.wasm" => Ok(wasm)
        _ => Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = match
    run_cmd_with_adapter(["--config", "cfg.json", "--vacuum", "a.wasm"], io) {
    Ok(v) => v
    Err(e) =>
      fail(
        "config pass list should be ignored once cli pass flags are set, got error \{e}",
      )
  }
  @debug.assert_eq(summary.resolved_passes, ["vacuum"])
}

///|
test "run_cmd_with_adapter uses input paths when no explicit outputs are set" {
  let wasm = encode_module_bytes(fixture_i32_const_module(7))
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match run_cmd_with_adapter(["a.wasm", "--vacuum"], io) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.output_files, ["a.wasm"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, "a.wasm")
}

///|
test "run_cmd_with_adapter rejects a single --out target for multiple inputs" {
  let wasm = encode_module_bytes(fixture_i32_const_module(11))
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm", "b.wasm"] },
    file_exists=fn(path) { path == "a.wasm" || path == "b.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" || path == "b.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
  )
  match run_cmd_with_adapter(["--out", "one.wasm", "a.wasm", "b.wasm"], io) {
    Ok(summary) => fail("expected ambiguous output error, got \{summary}")
    Err(err) =>
      @debug.assert_eq(err, CmdError::ambiguous_output_file("one.wasm"))
  }
}

///|
test "run_cmd_with_adapter loads default config path when present" {
  let config_json =
    #|{
    #|  "inputs": { "globs": ["cfg.wasm"] },
    #|  "outputs": { "outDir": "cfg-out" },
    #|  "passes": ["vacuum"]
    #|}
  let wasm = encode_module_bytes(fixture_i32_const_module(3))
  let io = CmdIO::new(
    list_candidates=fn() { ["cfg.wasm"] },
    file_exists=fn(path) {
      path == @cli.DEFAULT_CONFIG_PATH || path == "cfg.wasm"
    },
    read_file=fn(path) {
      if path == @cli.DEFAULT_CONFIG_PATH {
        Ok(bytes_from_string(config_json))
      } else if path == "cfg.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = match run_cmd_with_adapter([], io) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.input_files, ["cfg.wasm"])
  @debug.assert_eq(summary.output_files, ["cfg-out/cfg.wasm"])
  assert_true(has_string(summary.resolved_passes, "vacuum"))
}

///|
test "run_cmd_with_adapter accepts optional inline json config in the same call" {
  let config_json =
    #|{
    #|  "inputs": { "globs": ["a.wasm"] },
    #|  "outputs": { "outDir": "inline-out" },
    #|  "passes": ["vacuum"],
    #|  "options": { "trapsNeverHappen": true }
    #|}
  let wasm = encode_module_bytes(fixture_i32_const_module(12))
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = match
    run_cmd_with_adapter([], io, config_json=Some(config_json)) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.output_files, ["inline-out/a.wasm"])
  @debug.assert_eq(summary.resolved_passes, ["vacuum"])
  assert_true(summary.traps_never_happen)
}

///|
test "run_cmd_with_adapter reports config read failures with ConfigReadFailed" {
  let io = CmdIO::new(file_exists=fn(path) { path == "cfg.json" }, read_file=fn(
    path,
  ) {
    if path == "cfg.json" {
      Err("permission denied")
    } else {
      Err("missing fixture")
    }
  })
  match run_cmd_with_adapter(["--config", "cfg.json"], io) {
    Ok(summary) => fail("expected config read failure, got summary \{summary}")
    Err(CmdError::ConfigReadFailed(msg)) => {
      assert_true(msg.contains("cfg.json"))
      assert_true(msg.contains("permission denied"))
    }
    Err(err) => fail("expected ConfigReadFailed, got \{err}")
  }
}

///|
test "run_cmd_with_adapter copies wasm no-op bytes without decoding or encoding" {
  let invalid_wasm = bytes_from_string("not-wasm")
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "bad.wasm" },
    list_candidates=fn() { ["bad.wasm"] },
    read_file=fn(path) {
      if path == "bad.wasm" {
        Ok(invalid_wasm)
      } else {
        Err("missing fixture")
      }
    },
    encode_module=fn(_) {
      abort("encode_module should not run for wasm no-op copy")
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match run_cmd_with_adapter(["-o", "out.wasm", "bad.wasm"], io) {
    Ok(summary) => {
      @debug.assert_eq(summary.resolved_passes, [])
      @debug.assert_eq(summary.output_files, ["out.wasm"])
      @debug.assert_eq(writes.length(), 1)
      @debug.assert_eq(writes[0].0, "out.wasm")
      @debug.assert_eq(writes[0].1, invalid_wasm)
    }
    Err(err) => fail("expected wasm no-op raw copy success, got \{err}")
  }
}

///|
test "run_cmd_with_adapter reports decode failures when a pipeline step needs the module" {
  let io = CmdIO::new(
    file_exists=fn(path) { path == "bad.wasm" },
    list_candidates=fn() { ["bad.wasm"] },
    read_file=fn(path) {
      if path == "bad.wasm" {
        Ok(bytes_from_string("not-wasm"))
      } else {
        Err("missing fixture")
      }
    },
  )
  match run_cmd_with_adapter(["--validate", "bad.wasm"], io) {
    Ok(summary) => fail("expected decode failure, got summary \{summary}")
    Err(CmdError::DecodeFailed(path, err)) => {
      @debug.assert_eq(path, "bad.wasm")
      match err {
        @binary.DecodeError::Decode(
          @binary.BinaryDecodeError::InvalidMagicHeader
        ) => ()
        _ => fail("expected typed decode cause, got \{err}")
      }
    }
    Err(err) => fail("expected DecodeFailed, got \{err}")
  }
}

///|
test "run_cmd_with_adapter reports input read failures with InputReadFailed" {
  let io = CmdIO::new(
    file_exists=fn(path) { path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      if path == "a.wasm" {
        Err("io timeout")
      } else {
        Err("missing fixture")
      }
    },
  )
  match run_cmd_with_adapter(["a.wasm"], io) {
    Ok(summary) => fail("expected input read failure, got summary \{summary}")
    Err(CmdError::InputReadFailed(msg)) => {
      assert_true(msg.contains("a.wasm"))
      assert_true(msg.contains("io timeout"))
    }
    Err(err) => fail("expected InputReadFailed, got \{err}")
  }
}

///|
test "run_cmd_with_adapter reports encode failures with EncodeFailed" {
  let wasm = encode_module_bytes(fixture_i32_const_module(8))
  let io = CmdIO::new(
    file_exists=fn(path) { path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    encode_module=fn(_) {
      Err(CmdEncodeError::adapter("forced encode failure"))
    },
  )
  match run_cmd_with_adapter(["--validate", "a.wasm"], io) {
    Ok(summary) => fail("expected encode failure, got summary \{summary}")
    Err(CmdError::EncodeFailed(path, err)) => {
      @debug.assert_eq(path, "a.wasm")
      @debug.assert_eq(err, CmdEncodeError::adapter("forced encode failure"))
    }
    Err(err) => fail("expected EncodeFailed, got \{err}")
  }
}

///|
test "run_cmd_with_adapter skips post-encode validation outside debug mode" {
  let wasm = encode_module_bytes(fixture_i32_const_module(8))
  let invalid_bytes = bytes_from_string("not a wasm module")
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    encode_module=fn(_) { Ok(invalid_bytes) },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match run_cmd_with_adapter(["--validate", "-o", "out.wasm", "a.wasm"], io) {
    Ok(summary) => {
      @debug.assert_eq(summary.output_files, ["out.wasm"])
      @debug.assert_eq(writes.length(), 1)
      @debug.assert_eq(writes[0].0, "out.wasm")
      @debug.assert_eq(writes[0].1, invalid_bytes)
    }
    Err(err) =>
      fail("expected success without debug post-encode validation, got \{err}")
  }
}

///|
test "run_cmd_with_adapter keeps post-encode validation in debug mode" {
  let wasm = encode_module_bytes(fixture_i32_const_module(8))
  let invalid_bytes = bytes_from_string("not a wasm module")
  let io = CmdIO::new(
    file_exists=fn(path) { path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    encode_module=fn(_) { Ok(invalid_bytes) },
    write_file=fn(_, _) {
      abort("write_file should not run after debug validation failure")
    },
  )
  match
    run_cmd_with_adapter(
      ["--debug-serial-passes", "-o", "out.wasm", "a.wasm"],
      io,
    ) {
    Ok(summary) =>
      fail("expected debug post-encode validation failure, got \{summary}")
    Err(CmdError::EncodeFailed(path, Adapter(msg))) => {
      @debug.assert_eq(path, "a.wasm")
      assert_true(msg.contains("post-encode decode failed"))
    }
    Err(err) => fail("expected EncodeFailed in debug mode, got \{err}")
  }
}

///|
test "config pass flags take precedence over env pass overlays when cli pass flags are absent" {
  let config_json =
    #|{
    #|  "inputs": { "globs": ["a.wasm"] },
    #|  "passes": ["vacuum"]
    #|}
  let wasm = encode_module_bytes(fixture_i32_const_module(17))
  let io = CmdIO::new(
    get_env=fn(name) {
      if name == "STARSHINE_PASSES" {
        Some("vacuum")
      } else {
        None
      }
    },
    file_exists=fn(path) { path == "cfg.json" || path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      match path {
        "cfg.json" => Ok(bytes_from_string(config_json))
        "a.wasm" => Ok(wasm)
        _ => Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = match run_cmd_with_adapter(["--config", "cfg.json"], io) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["vacuum"])
}

///|
test "env optimize and trap overlays take precedence over config values when cli omits options" {
  let config_json =
    #|{
    #|  "inputs": { "globs": ["a.wasm"] },
    #|  "optimize": { "olevel": "O1", "trapMode": "allow" }
    #|}
  let wasm = encode_module_bytes(fixture_i32_const_module(18))
  let io = CmdIO::new(
    get_env=fn(name) {
      match name {
        "STARSHINE_OLEVEL" => Some("O3")
        "STARSHINE_TRAP_MODE" => Some("never")
        "STARSHINE_CLOSED_WORLD" => Some("true")
        _ => None
      }
    },
    file_exists=fn(path) { path == "cfg.json" || path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      match path {
        "cfg.json" => Ok(bytes_from_string(config_json))
        "a.wasm" => Ok(wasm)
        _ => Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = match run_cmd_with_adapter(["--config", "cfg.json"], io) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["optimize"])
  @debug.assert_eq(summary.optimize_level, 3)
  assert_true(summary.traps_never_happen)
  assert_true(summary.closed_world)
}

///|
test "env olevel overlay accepts dash-prefixed trimmed text" {
  let wasm = encode_module_bytes(fixture_i32_const_module(19))
  let io = CmdIO::new(
    get_env=fn(name) {
      match name {
        "STARSHINE_OLEVEL" => Some("  -Oz  ")
        _ => None
      }
    },
    file_exists=fn(path) { path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      match path {
        "a.wasm" => Ok(wasm)
        _ => Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = match run_cmd_with_adapter(["a.wasm"], io) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["shrink"])
  @debug.assert_eq(summary.optimize_level, 2)
  @debug.assert_eq(summary.shrink_level, 2)
}

///|
test "run_cmd_with_adapter prints help text and exits successfully for --help" {
  let stdout_writes : Array[Bytes] = []
  let io = CmdIO::new(write_stdout=fn(bytes) {
    stdout_writes.push(bytes)
    Ok(())
  })
  let summary = match run_cmd_with_adapter(["--help"], io) {
    Ok(v) => v
    Err(e) => fail("expected help success, got \{e}")
  }
  @debug.assert_eq(summary.input_files, [])
  @debug.assert_eq(summary.output_files, [])
  @debug.assert_eq(stdout_writes.length(), 1)
  let help = bytes_to_ascii_string(stdout_writes[0])
  assert_true(help.contains("Starshine Wasm Binary Toolkit"))
  assert_true(help.contains("v0.1.0"))
  assert_true(help.contains("Usage:"))
  assert_true(help.contains("--help"))
  assert_true(help.contains("--version"))
  assert_true(help.contains("--glob"))
  assert_true(help.contains("--dump <PATH>"))
  assert_true(help.contains("--extract-functions <index,index,...>"))
  assert_true(help.contains("--validate"))
  assert_true(help.contains("--print-func <name|index>"))
  assert_true(help.contains("--print-type <name|index>"))
  assert_true(help.contains("--print-elem <name|index>"))
  assert_true(help.contains("--ssa-nomerge"))
  assert_true(help.contains("--vacuum"))
  assert_true(help.contains("--optimize"))
  assert_true(help.contains("--closed-world"))
  assert_true(help.contains("--zero-filled-memory"))
  assert_true(help.contains("--always-inline-max-function-size, -aimfs <N>"))
  assert_true(
    help.contains("--one-caller-inline-max-function-size, -ocimfs <N|-1>"),
  )
  assert_true(help.contains("--inline-functions-with-loops, -ifwl"))
  assert_true(help.contains("--partial-inlining-ifs, -pii <N>"))
  assert_false(help.contains("--memory-packing"))
  assert_false(help.contains("--re-reloop"))
}

///|
test "run_cmd_with_adapter fast-paths bare --help without env probing" {
  let stdout_writes : Array[Bytes] = []
  let env_lookups : Array[String] = []
  let io = CmdIO::new(
    get_env=fn(name) {
      env_lookups.push(name)
      None
    },
    write_stdout=fn(bytes) {
      stdout_writes.push(bytes)
      Ok(())
    },
  )
  match run_cmd_with_adapter(["--help"], io) {
    Ok(_) => ()
    Err(e) => fail("expected help success, got \{e}")
  }
  @debug.assert_eq(env_lookups, [])
  @debug.assert_eq(stdout_writes.length(), 1)
}

///|
test "run_cmd_with_adapter exits on parsed help before STARSHINE_INPUT probing" {
  let stdout_writes : Array[Bytes] = []
  let env_lookups : Array[String] = []
  let io = CmdIO::new(
    get_env=fn(name) {
      env_lookups.push(name)
      None
    },
    write_stdout=fn(bytes) {
      stdout_writes.push(bytes)
      Ok(())
    },
  )
  match run_cmd_with_adapter(["--help", "--stdin"], io) {
    Ok(_) => ()
    Err(e) => fail("expected parsed help success, got \{e}")
  }
  @debug.assert_eq(env_lookups, [])
  @debug.assert_eq(stdout_writes.length(), 1)
}

///|
test "run_cmd_with_adapter skips irrelevant env overlay probes when cli already fixes startup mode" {
  let env_lookups : Array[String] = []
  let wasm = encode_module_bytes(fixture_i32_const_module(20))
  let io = CmdIO::new(
    get_env=fn(name) {
      env_lookups.push(name)
      None
    },
    file_exists=fn(path) { path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      match path {
        "a.wasm" => Ok(wasm)
        _ => Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--format", "wasm", "--out", "out.wasm", "--trap-mode", "never", "--optimize-level",
        "2", "--monomorphize-min-benefit", "7", "--low-memory-unused", "--low-memory-bound",
        "64", "--closed-world", "--zero-filled-memory", "--tracing", "helper", "--debug-serial-passes",
        "--vacuum", "a.wasm",
      ],
      io,
      config_json=Some("{}"),
    ) {
    Ok(v) => v
    Err(e) => fail("expected run success, got \{e}")
  }
  @debug.assert_eq(summary.resolved_passes, ["vacuum"])
  @debug.assert_eq(summary.output_files, ["out.wasm"])
  @debug.assert_eq(env_lookups, [
    "STARSHINE_INPUT", "STARSHINE_OPTIMIZE_MAX_PASSES",
  ])
}

///|
test "run_cmd_with_adapter prints version and exits successfully for --version" {
  let stdout_writes : Array[Bytes] = []
  let io = CmdIO::new(write_stdout=fn(bytes) {
    stdout_writes.push(bytes)
    Ok(())
  })
  let summary = match run_cmd_with_adapter(["--version"], io) {
    Ok(v) => v
    Err(e) => fail("expected version success, got \{e}")
  }
  @debug.assert_eq(summary.input_files, [])
  @debug.assert_eq(summary.output_files, [])
  @debug.assert_eq(stdout_writes.length(), 1)
  @debug.assert_eq(bytes_to_ascii_string(stdout_writes[0]), "v0.1.0\n")
}

///|
test "run_cmd_with_adapter fast-paths bare --version without env probing" {
  let stdout_writes : Array[Bytes] = []
  let env_lookups : Array[String] = []
  let io = CmdIO::new(
    get_env=fn(name) {
      env_lookups.push(name)
      None
    },
    write_stdout=fn(bytes) {
      stdout_writes.push(bytes)
      Ok(())
    },
  )
  match run_cmd_with_adapter(["--version"], io) {
    Ok(_) => ()
    Err(e) => fail("expected version success, got \{e}")
  }
  @debug.assert_eq(env_lookups, [])
  @debug.assert_eq(stdout_writes.length(), 1)
}

///|
test "run_cmd_with_adapter prints version and exits successfully for -V" {
  let stdout_writes : Array[Bytes] = []
  let io = CmdIO::new(write_stdout=fn(bytes) {
    stdout_writes.push(bytes)
    Ok(())
  })
  let summary = match run_cmd_with_adapter(["-V"], io) {
    Ok(v) => v
    Err(e) => fail("expected version success, got \{e}")
  }
  @debug.assert_eq(summary.input_files, [])
  @debug.assert_eq(summary.output_files, [])
  @debug.assert_eq(stdout_writes.length(), 1)
  @debug.assert_eq(bytes_to_ascii_string(stdout_writes[0]), "v0.1.0\n")
}

///|
test "run_cmd_with_adapter spec subcommand runs wast spec suite" {
  let stdout_writes : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "ok.wast" },
    list_candidates=fn() { ["ok.wast"] },
    read_file=fn(path) {
      if path == "ok.wast" {
        Ok(bytes_from_string("(module)"))
      } else {
        Err("missing fixture")
      }
    },
    write_stdout=fn(bytes) {
      stdout_writes.push(bytes)
      Ok(())
    },
  )
  let summary = match run_cmd_with_adapter(["spec", "ok.wast"], io) {
    Ok(v) => v
    Err(e) => fail("expected spec run success, got \{e}")
  }
  @debug.assert_eq(summary.input_files, ["ok.wast"])
  @debug.assert_eq(summary.resolved_passes, ["spec"])
  @debug.assert_eq(stdout_writes.length(), 1)
  assert_true(bytes_to_ascii_string(stdout_writes[0]).contains("failed=0"))
}

///|
test "run_cmd_with_adapter spec subcommand only expands wildcard inputs with --glob" {
  let io = CmdIO::new(
    file_exists=fn(path) { path == "ok.wast" },
    list_candidates=fn() { ["ok.wast"] },
    read_file=fn(path) {
      if path == "ok.wast" {
        Ok(bytes_from_string("(module)"))
      } else {
        Err("missing fixture")
      }
    },
  )

  match run_cmd_with_adapter(["spec", "ok*.wast"], io) {
    Ok(summary) =>
      fail("expected literal wildcard path failure, got \{summary}")
    Err(CmdError::InputReadFailed(msg)) => assert_true(msg.contains("ok*.wast"))
    Err(err) => fail("expected InputReadFailed, got \{err}")
  }

  let summary = match run_cmd_with_adapter(["spec", "--glob", "ok*.wast"], io) {
    Ok(v) => v
    Err(e) => fail("expected glob-enabled spec success, got \{e}")
  }
  @debug.assert_eq(summary.input_files, ["ok.wast"])
}

///|
test "run_cmd_with_adapter spec subcommand reports failures" {
  let stdout_writes : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "broken.wast" },
    list_candidates=fn() { ["broken.wast"] },
    read_file=fn(path) {
      if path == "broken.wast" {
        Ok(bytes_from_string("(assert_invalid (module) \"must fail\")"))
      } else {
        Err("missing fixture")
      }
    },
    write_stdout=fn(bytes) {
      stdout_writes.push(bytes)
      Ok(())
    },
  )
  match run_cmd_with_adapter(["spec", "broken.wast"], io) {
    Ok(summary) => fail("expected spec failure, got \{summary}")
    Err(CmdError::SpecFailed(msg)) => assert_true(msg.contains("broken.wast"))
    Err(err) => fail("expected SpecFailed, got \{err}")
  }
  @debug.assert_eq(stdout_writes.length(), 2)
  assert_true(bytes_to_ascii_string(stdout_writes[0]).contains("failed=1"))
}

///|
test "run_cmd_exit_code_with_adapter returns zero for successful runs" {
  let wasm = encode_module_bytes(fixture_i32_const_module(21))
  let io = CmdIO::new(
    file_exists=fn(path) { path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let code = run_cmd_exit_code_with_adapter(["a.wasm"], io)
  @debug.assert_eq(code, 0)
}

///|
test "run_cmd_exit_code_with_adapter returns zero for --help" {
  let io = CmdIO::new(write_stdout=fn(_) { Ok(()) })
  let code = run_cmd_exit_code_with_adapter(["--help"], io)
  @debug.assert_eq(code, 0)
}

///|
test "run_cmd_exit_code_with_adapter returns zero for --version" {
  let io = CmdIO::new(write_stdout=fn(_) { Ok(()) })
  let code = run_cmd_exit_code_with_adapter(["--version"], io)
  @debug.assert_eq(code, 0)
}

///|
test "run_cmd_exit_code_with_adapter returns non-zero for failures" {
  let wasm = encode_module_bytes(fixture_i32_const_module(22))
  let io = CmdIO::new(
    file_exists=fn(path) { path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let code = run_cmd_exit_code_with_adapter(["--stdin"], io)
  @debug.assert_eq(code, 1)
}

///|
test "run_cmd_exit_code_with_adapter writes CmdError details to stderr on parse failures" {
  let wasm = encode_module_bytes(fixture_i32_const_module(122))
  let stderr_writes : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
    write_stderr=fn(bytes) {
      stderr_writes.push(bytes)
      Ok(())
    },
  )
  let code = run_cmd_exit_code_with_adapter(["--stdin"], io)
  @debug.assert_eq(code, 1)
  @debug.assert_eq(stderr_writes.length(), 1)
  let stderr_text = bytes_to_ascii_string(stderr_writes[0])
  assert_true(stderr_text.contains("error:"))
  assert_true(stderr_text.contains("stdin requires"))
}

///|
test "run_cmd_exit_code_with_adapter does not write stderr on success" {
  let wasm = encode_module_bytes(fixture_i32_const_module(123))
  let stderr_writes : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
    write_stderr=fn(bytes) {
      stderr_writes.push(bytes)
      Ok(())
    },
  )
  let code = run_cmd_exit_code_with_adapter(["a.wasm"], io)
  @debug.assert_eq(code, 0)
  @debug.assert_eq(stderr_writes.length(), 0)
}

///|
#cfg(target="native")
fn native_c_string(text : String) -> Bytes {
  let out = @buffer.new(size_hint=text.length() + 1)
  for c in text {
    let code = c.to_int()
    if code >= 0 && code <= 255 {
      out.write_byte(code.to_byte())
    } else {
      out.write_byte('?'.to_int().to_byte())
    }
  }
  out.write_byte(0)
  out.to_bytes()
}

///|
#cfg(target="native")
#borrow(path, mode)
extern "c" fn native_fopen(path : Bytes, mode : Bytes) -> UInt64 = "fopen"

///|
#cfg(target="native")
extern "c" fn native_fclose(stream : UInt64) -> Int = "fclose"

///|
#cfg(target="native")
extern "c" fn native_fseek(stream : UInt64, offset : Int, whence : Int) -> Int = "fseek"

///|
#cfg(target="native")
extern "c" fn native_ftell(stream : UInt64) -> Int64 = "ftell"

///|
#cfg(target="native")
#borrow(ptr)
extern "c" fn native_fread(
  ptr : Bytes,
  size : UInt64,
  count : UInt64,
  stream : UInt64,
) -> UInt64 = "fread"

///|
#cfg(target="native")
#borrow(ptr)
extern "c" fn native_fwrite(
  ptr : Bytes,
  size : UInt64,
  count : UInt64,
  stream : UInt64,
) -> UInt64 = "moonbit_fwrite_ffi"

///|
#cfg(target="native")
#borrow(path)
extern "c" fn native_remove(path : Bytes) -> Int = "remove"

///|
#cfg(target="native")
#borrow(name, value)
extern "c" fn native_setenv(
  name : Bytes,
  value : Bytes,
  overwrite : Int,
) -> Int = "setenv"

///|
#cfg(target="native")
#borrow(name)
extern "c" fn native_unsetenv(name : Bytes) -> Int = "unsetenv"

///|
#cfg(target="native")
extern "c" fn native_dup(fd : Int) -> Int = "dup"

///|
#cfg(target="native")
extern "c" fn native_dup2(old_fd : Int, new_fd : Int) -> Int = "dup2"

///|
#cfg(target="native")
extern "c" fn native_close(fd : Int) -> Int = "close"

///|
#cfg(target="native")
extern "c" fn native_fflush(stream : UInt64) -> Int = "fflush"

///|
#cfg(target="native")
extern "c" fn native_fork() -> Int = "fork"

///|
#cfg(target="native")
#borrow(status)
extern "c" fn native_waitpid(pid : Int, status : Bytes, options : Int) -> Int = "waitpid"

///|
#cfg(target="native")
extern "c" fn native_exit(code : Int) -> Unit = "quick_exit"

///|
#cfg(target="native")
#borrow(tv)
extern "c" fn native_gettimeofday(tv : Bytes, tz : UInt64) -> Int = "gettimeofday"

///|
#cfg(target="native")
fn native_read_u64_timeval(bytes : Bytes, start : Int) -> UInt64 {
  let mut out = 0UL
  let mut i = 0
  while i < 8 {
    out = out | (bytes[start + i].to_uint64() << (i * 8))
    i += 1
  }
  out
}

///|
#cfg(target="native")
fn native_now_ms() -> UInt64 {
  let tv = Bytes::new(16)
  if native_gettimeofday(tv, 0UL) != 0 {
    return @env.now()
  }
  let sec = native_read_u64_timeval(tv, 0)
  let usec = native_read_u64_timeval(tv, 8)
  sec * 1000UL + usec / 1000UL
}

///|
#cfg(target="native")
fn native_remove_if_exists(path : String) -> Unit {
  let c_path = native_c_string(path)
  ignore(native_remove(c_path))
}

///|
#cfg(target="native")
fn native_tmp_file(name : String) -> String {
  "/tmp/starshine-cmd-\{name}-\{native_now_ms()}.wasm"
}

///|
#cfg(target="native")
fn native_tmp_path(name : String, ext : String) -> String {
  "/tmp/starshine-cmd-\{name}-\{native_now_ms()}\{ext}"
}

///|
#cfg(target="native")
fn native_write_bytes(path : String, bytes : Bytes) -> Bool {
  let c_path = native_c_string(path)
  let c_mode = native_c_string("wb")
  let file = native_fopen(c_path, c_mode)
  if file == 0UL {
    return false
  }
  let expected = bytes.length()
  let wrote = if expected == 0 {
    0UL
  } else {
    native_fwrite(bytes, 1UL, expected.to_uint64(), file)
  }
  let close_code = native_fclose(file)
  if expected == 0 {
    close_code == 0
  } else {
    wrote == expected.to_uint64() && close_code == 0
  }
}

///|
#cfg(target="native")
#borrow(command)
extern "c" fn native_system(command : Bytes) -> Int = "system"

///|
#cfg(target="native")
fn native_read_bytes(path : String) -> Bytes? {
  let c_path = native_c_string(path)
  let c_mode = native_c_string("rb")
  let file = native_fopen(c_path, c_mode)
  if file == 0UL {
    return None
  }
  if native_fseek(file, 0, 2) != 0 {
    ignore(native_fclose(file))
    return None
  }
  let size_i64 = native_ftell(file)
  if size_i64 < 0L {
    ignore(native_fclose(file))
    return None
  }
  let size_u = size_i64.reinterpret_as_uint64()
  if size_u > 2147483647UL {
    ignore(native_fclose(file))
    return None
  }
  let size = size_i64.to_int()
  if native_fseek(file, 0, 0) != 0 {
    ignore(native_fclose(file))
    return None
  }
  let out = Bytes::new(size)
  if size > 0 {
    let read = native_fread(out, 1UL, size_u, file)
    if read != size_u {
      ignore(native_fclose(file))
      return None
    }
  }
  if native_fclose(file) != 0 {
    return None
  }
  Some(out)
}

///|
#cfg(target="native")
fn native_normalize_wasm_bytes_to_wat_for_test(
  bytes : Bytes,
) -> Result[String, String] {
  let in_path = native_tmp_path("normalize-in", ".wasm")
  let out_path = native_tmp_path("normalize-out", ".wat")
  if !native_write_bytes(in_path, bytes) {
    return Err("failed to stage wasm normalization input")
  }
  let command = native_c_string(
    "wasm-opt \{in_path} -S --strip-debug -o \{out_path}",
  )
  let code = native_system(command)
  let result = if code == 0 {
    match native_read_bytes(out_path) {
      Some(text) => Ok(bytes_to_ascii_string(text))
      None => Err("failed to read normalized wat output")
    }
  } else {
    Err("failed to normalize wasm via wasm-opt")
  }
  native_remove_if_exists(in_path)
  native_remove_if_exists(out_path)
  result
}

///|
#cfg(target="native")
fn native_wat_to_wasm_bytes_for_test(source : String) -> Result[Bytes, String] {
  let wat_path = native_tmp_path("fixture-in", ".wat")
  let wasm_path = native_tmp_path("fixture-out", ".wasm")
  if !native_write_bytes(wat_path, bytes_from_string(source)) {
    return Err("failed to stage wat fixture input")
  }
  let command = native_c_string("wasm-opt \{wat_path} -o \{wasm_path}")
  let code = native_system(command)
  let result = if code == 0 {
    match native_read_bytes(wasm_path) {
      Some(bytes) => Ok(bytes)
      None => Err("failed to read lowered wasm fixture")
    }
  } else {
    Err("failed to lower wat fixture via wasm-opt")
  }
  native_remove_if_exists(wat_path)
  native_remove_if_exists(wasm_path)
  result
}

///|
#cfg(target="native")
fn native_validate_wasm_bytes_with_wasm_tools(
  bytes : Bytes,
) -> Result[Unit, String] {
  let wasm_path = native_tmp_path("validate-in", ".wasm")
  let log_path = native_tmp_path("validate-log", ".txt")
  if !native_write_bytes(wasm_path, bytes) {
    return Err("failed to stage wasm validation input")
  }
  let command = native_c_string(
    "wasm-tools validate \{wasm_path} > \{log_path} 2>&1",
  )
  let code = native_system(command)
  let result = if code == 0 {
    Ok(())
  } else {
    match native_read_bytes(log_path) {
      Some(log) => Err(bytes_to_ascii_string(log))
      None => Err("wasm-tools validate failed")
    }
  }
  native_remove_if_exists(wasm_path)
  native_remove_if_exists(log_path)
  result
}

///|
#cfg(target="native")
fn native_set_env(name : String, value : String) -> Bool {
  let c_name = native_c_string(name)
  let c_value = native_c_string(value)
  native_setenv(c_name, c_value, 1) == 0
}

///|
#cfg(target="native")
fn native_unset_env(name : String) -> Unit {
  let c_name = native_c_string(name)
  ignore(native_unsetenv(c_name))
}

///|
#cfg(target="native")
fn native_wait_status_raw(status : Bytes) -> Int {
  let mut raw = 0
  let mut shift = 0
  let mut i = 0
  while i < status.length() {
    raw = raw | (status[i].to_int() << shift)
    i += 1
    shift += 8
  }
  raw
}

///|
#cfg(target="native")
fn native_run_cmd_exit_status(args : Array[String]) -> (Bool, Int) {
  let pid = native_fork()
  if pid < 0 {
    abort("failed to fork child process for run_cmd integration test")
  }
  if pid == 0 {
    let code = run_cmd_exit_code(args)
    native_exit(code)
    abort("native_exit should not return")
  }
  let status = Bytes::new(4)
  let waited = native_waitpid(pid, status, 0)
  if waited != pid {
    abort(
      "waitpid returned unexpected pid \{waited}; expected child pid \{pid}",
    )
  }
  let raw = native_wait_status_raw(status)
  let signal = raw & 0x7F
  if signal != 0 && signal != 0x7F {
    return (true, signal)
  }
  let code = (raw >> 8) & 0xFF
  (false, code)
}

///|
#cfg(target="native")
test "run_cmd native child process does not crash for file rewrite" {
  let input_path = native_tmp_file("child-io-input")
  let output_path = native_tmp_file("child-io-output")
  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)

  let wasm = encode_module_bytes(fixture_i32_const_module(31))
  assert_true(native_write_bytes(input_path, wasm))

  let (signaled, status) = native_run_cmd_exit_status([
    "--vacuum", "--out", output_path, input_path,
  ])
  if signaled {
    native_remove_if_exists(input_path)
    native_remove_if_exists(output_path)
    fail("expected child to exit normally, got signal \{status}")
  }
  @debug.assert_eq(status, 0)
  match native_read_bytes(output_path) {
    Some(bytes) => ignore(decode_module_bytes(bytes))
    None => fail("expected native output file at \{output_path}")
  }

  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)
}

///|
#cfg(target="native")
test "run_cmd native child process does not crash for --optimize" {
  let input_path = native_tmp_file("child-opt-input")
  let output_path = native_tmp_file("child-opt-output")
  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)

  let wasm = encode_module_bytes(fixture_i32_const_module(32))
  assert_true(native_write_bytes(input_path, wasm))

  let (signaled, status) = native_run_cmd_exit_status([
    "--optimize", "--out", output_path, input_path,
  ])
  if signaled {
    native_remove_if_exists(input_path)
    native_remove_if_exists(output_path)
    fail("expected child to exit normally, got signal \{status}")
  }
  @debug.assert_eq(status, 0)
  match native_read_bytes(output_path) {
    Some(bytes) => ignore(decode_module_bytes(bytes))
    None => fail("expected optimized output file at \{output_path}")
  }

  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)
}

///|
#cfg(target="native")
test "run_cmd native child process dumps final-invalid module on validate failure" {
  let input_path = native_tmp_file("child-invalid-input")
  let output_path = native_tmp_file("child-invalid-output")
  let invalid_dump_path = "/tmp/starshine-invalid-final.wasm"
  let invalid_func_dump_path = "/tmp/starshine-invalid-final-func.txt"
  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)
  native_remove_if_exists(invalid_dump_path)
  native_remove_if_exists(invalid_func_dump_path)

  let wasm = encode_module_bytes(fixture_invalid_i32_result_module())
  assert_true(native_write_bytes(input_path, wasm))

  let (signaled, status) = native_run_cmd_exit_status([
    "--vacuum", "--out", output_path, input_path,
  ])
  if signaled {
    native_remove_if_exists(input_path)
    native_remove_if_exists(output_path)
    native_remove_if_exists(invalid_dump_path)
    native_remove_if_exists(invalid_func_dump_path)
    fail("expected child to exit normally, got signal \{status}")
  }
  @debug.assert_eq(status, 1)
  match native_read_bytes(invalid_dump_path) {
    Some(bytes) => ignore(decode_module_bytes(bytes))
    None => fail("expected invalid final-module dump at \{invalid_dump_path}")
  }
  match native_read_bytes(invalid_func_dump_path) {
    Some(bytes) => assert_true(bytes.length() > 0)
    None =>
      fail("expected invalid final-function dump at \{invalid_func_dump_path}")
  }

  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)
  native_remove_if_exists(invalid_dump_path)
  native_remove_if_exists(invalid_func_dump_path)
}

///|
#cfg(target="native")
test "run_cmd uses native default io to read inputs and write outputs" {
  let input_path = native_tmp_file("io-input")
  let output_path = native_tmp_file("io-output")
  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)

  let wasm = encode_module_bytes(fixture_i32_const_module(13))
  assert_true(native_write_bytes(input_path, wasm))

  let summary = match run_cmd(["--vacuum", "--out", output_path, input_path]) {
    Ok(v) => v
    Err(e) => fail("expected native run_cmd success, got \{e}")
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])

  match native_read_bytes(output_path) {
    Some(bytes) => ignore(decode_module_bytes(bytes))
    None => fail("expected native output file at \{output_path}")
  }

  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)
}

///|
#cfg(target="native")
test "run_cmd reads STARSHINE_INPUT from native environment" {
  let input_path = native_tmp_file("env-input")
  let output_path = native_tmp_file("env-output")
  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)

  let wasm = encode_module_bytes(fixture_i32_const_module(14))
  assert_true(native_write_bytes(input_path, wasm))
  assert_true(native_set_env("STARSHINE_INPUT", input_path))

  let result = run_cmd(["--vacuum", "--out", output_path])
  native_unset_env("STARSHINE_INPUT")
  let summary = match result {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected native STARSHINE_INPUT wiring to provide inputs, got error \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])

  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)
}

///|
#cfg(target="native")
test "run_cmd uses native stdout wiring and surfaces write failures" {
  let input_path = native_tmp_file("stdout-input")
  native_remove_if_exists(input_path)
  let wasm = encode_module_bytes(fixture_i32_const_module(15))
  assert_true(native_write_bytes(input_path, wasm))

  let saved_stdout = native_dup(1)
  if saved_stdout < 0 {
    native_remove_if_exists(input_path)
    fail("failed to duplicate stdout fd")
  }
  ignore(native_close(1))
  let result = run_cmd(["--stdout", "--vacuum", input_path])
  ignore(native_dup2(saved_stdout, 1))
  ignore(native_close(saved_stdout))
  ignore(native_fflush(0UL))

  native_remove_if_exists(input_path)

  match result {
    Err(CmdError::OutputWriteFailed(msg)) =>
      assert_true(msg.contains("stdout for"))
    Ok(summary) =>
      fail(
        "expected stdout write failure with closed fd, got summary \{summary}",
      )
    Err(err) =>
      fail("expected OutputWriteFailed when stdout is closed, got \{err}")
  }
}

///|
#cfg(target="native")
test "run_cmd uses native default candidate enumeration for wildcard input globs" {
  let prefix = "tmp-starshine-cmd-glob-\{native_now_ms()}"
  let input_path = "\{prefix}.wasm"
  native_remove_if_exists(input_path)

  let wasm = encode_module_bytes(fixture_i32_const_module(16))
  assert_true(native_write_bytes(input_path, wasm))

  match run_cmd(["--vacuum", "\{prefix}*.wasm"]) {
    Ok(summary) =>
      fail(
        "expected literal wildcard path to stay literal without --glob, got \{summary}",
      )
    Err(CmdError::InputReadFailed(msg)) =>
      assert_true(msg.contains("\{prefix}*.wasm"))
    Err(e) => {
      native_remove_if_exists(input_path)
      fail("expected InputReadFailed without --glob, got \{e}")
    }
  }

  let summary = match run_cmd(["--glob", "--vacuum", "\{prefix}*.wasm"]) {
    Ok(v) => v
    Err(e) => {
      native_remove_if_exists(input_path)
      fail(
        "expected wildcard input to resolve via native list_candidates with --glob, got \{e}",
      )
    }
  }
  @debug.assert_eq(summary.input_files, [input_path])

  native_remove_if_exists(input_path)
}

///|
#cfg(target="native")
test "run_cmd wires native default text-lowering hook for wat inputs" {
  let base = "tmp-starshine-cmd-wat-\{native_now_ms()}"
  let wat_path = "\{base}.wat"
  let out_path = "\{base}.wasm"
  native_remove_if_exists(wat_path)
  native_remove_if_exists(out_path)
  assert_true(native_write_bytes(wat_path, bytes_from_string("(module)")))

  let result = run_cmd([wat_path])
  match result {
    Ok(summary) => {
      @debug.assert_eq(summary.input_files, [wat_path])
      @debug.assert_eq(summary.output_files, [out_path])
      match native_read_bytes(out_path) {
        Some(bytes) => ignore(decode_module_bytes(bytes))
        None => fail("expected lowered wasm output at \{out_path}")
      }
    }
    Err(CmdError::TextLoweringFailed(msg)) =>
      assert_false(msg.contains("text lowering not configured"))
    Err(e) => fail("unexpected native wat run_cmd failure: \{e}")
  }

  native_remove_if_exists(wat_path)
  native_remove_if_exists(out_path)
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter validates dead-code-elimination on debug artifact" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--dead-code-elimination", "--out", output_path, input_path],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected dead-code-elimination artifact replay success, got \{e}")
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  ignore(decode_module_bytes(writes[0].1))
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd pre-skips dead-code-elimination suspicious original carriers" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let stderr_chunks : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
    write_stderr=fn(bytes) {
      stderr_chunks.push(bytes)
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--extract-functions=950", "--tracing", "pass", "--dead-code-elimination",
        "--out", output_path, input_path,
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected extracted suspicious-carrier DCE replay success, got \{e}")
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, [
    "extract-functions=950", "dead-code-elimination",
  ])
  @debug.assert_eq(writes.length(), 1)
  ignore(decode_module_bytes(writes[0].1))
  let stderr = concat_ascii_bytes(stderr_chunks)
  assert_true(
    stderr.contains("reason=suspicious-escape-carrier-original"),
    msg=stderr,
  )
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd pre-skips dead-code-elimination large local artifact noops" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let stderr_chunks : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
    write_stderr=fn(bytes) {
      stderr_chunks.push(bytes)
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--extract-functions=517", "--tracing", "pass", "--dead-code-elimination",
        "--out", output_path, input_path,
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected extracted large-local DCE replay success, got \{e}")
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, [
    "extract-functions=517", "dead-code-elimination",
  ])
  @debug.assert_eq(writes.length(), 1)
  ignore(decode_module_bytes(writes[0].1))
  let stderr = concat_ascii_bytes(stderr_chunks)
  assert_true(stderr.contains("reason=large-local-dce-noop"), msg=stderr)
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd reports dead-code-elimination native default-io blocker on debug artifact" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = native_tmp_file("dce-native-default-io-output")
  let invalid_dump_path = "/tmp/starshine-invalid-final.wasm"
  let invalid_func_dump_path = "/tmp/starshine-invalid-final-func.txt"
  native_remove_if_exists(output_path)
  native_remove_if_exists(invalid_dump_path)
  native_remove_if_exists(invalid_func_dump_path)

  match run_cmd(["--dead-code-elimination", "--out", output_path, input_path]) {
    Ok(summary) =>
      fail(
        "expected native default-io replay to hit the known Func 1730 blocker, got \{summary}",
      )
    Err(CmdError::OptimizeFailed(msg)) => {
      assert_true(msg.contains("final module validate"), msg~)
      assert_true(msg.contains("(Func 1730)"), msg~)
    }
    Err(err) =>
      fail(
        "expected native default-io optimize failure for the known blocker, got \{err}",
      )
  }
  match native_read_bytes(invalid_dump_path) {
    Some(bytes) => ignore(decode_module_bytes(bytes))
    None => fail("expected invalid final-module dump at \{invalid_dump_path}")
  }
  match native_read_bytes(invalid_func_dump_path) {
    Some(bytes) => {
      let text = bytes_to_ascii_string(bytes)
      assert_true(text.contains("func code[1711]"))
    }
    None =>
      fail("expected invalid final-function dump at \{invalid_func_dump_path}")
  }

  native_remove_if_exists(output_path)
  native_remove_if_exists(invalid_dump_path)
  native_remove_if_exists(invalid_func_dump_path)
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd native child process validates extracted optimize-instructions debug-artifact func523 replay" {
  let fixture_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let input_path = native_tmp_file("oi-f523-native-child-input")
  let output_path = native_tmp_file("oi-f523-native-child-output")
  let invalid_dump_path = "/tmp/starshine-invalid-final.wasm"
  let invalid_func_dump_path = "/tmp/starshine-invalid-final-func.txt"
  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)
  native_remove_if_exists(invalid_dump_path)
  native_remove_if_exists(invalid_func_dump_path)

  let wasm = match native_read_bytes(fixture_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{fixture_path}")
  }
  assert_true(native_write_bytes(input_path, wasm))

  let (signaled, status) = native_run_cmd_exit_status([
    "--extract-functions=523", "--optimize-instructions", "--out", output_path, input_path,
  ])
  if signaled {
    native_remove_if_exists(input_path)
    native_remove_if_exists(output_path)
    native_remove_if_exists(invalid_dump_path)
    native_remove_if_exists(invalid_func_dump_path)
    fail("expected child to exit normally, got signal \{status}")
  }
  @debug.assert_eq(status, 0)
  match native_read_bytes(output_path) {
    Some(bytes) => ignore(decode_module_bytes(bytes))
    None => fail("expected optimized output at \{output_path}")
  }
  match native_read_bytes(invalid_dump_path) {
    Some(_) =>
      fail("did not expect invalid final-module dump at \{invalid_dump_path}")
    None => ()
  }
  match native_read_bytes(invalid_func_dump_path) {
    Some(_) =>
      fail(
        "did not expect invalid final-function dump at \{invalid_func_dump_path}",
      )
    None => ()
  }

  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)
  native_remove_if_exists(invalid_dump_path)
  native_remove_if_exists(invalid_func_dump_path)
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd validates early remove-unused-brs optimize-prefix on debug artifact" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = native_tmp_file("rub-prefix-native-default-io-output")
  let invalid_dump_path = "/tmp/starshine-invalid-final.wasm"
  let invalid_func_dump_path = "/tmp/starshine-invalid-final-func.txt"
  native_remove_if_exists(output_path)
  native_remove_if_exists(invalid_dump_path)
  native_remove_if_exists(invalid_func_dump_path)

  match
    run_cmd([
      "--memory-packing", "--once-reduction", "--global-refining", "--global-struct-inference",
      "--ssa-nomerge", "--dead-code-elimination", "--remove-unused-names", "--remove-unused-brs",
      "-O4z", "--out", output_path, input_path,
    ]) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected native default-io optimize-prefix replay to validate, got \{err}",
      )
  }
  match native_read_bytes(output_path) {
    Some(bytes) => ignore(decode_module_bytes(bytes))
    None => fail("expected optimized output at \{output_path}")
  }
  match native_read_bytes(invalid_dump_path) {
    Some(_) =>
      fail("did not expect invalid final-module dump at \{invalid_dump_path}")
    None => ()
  }
  match native_read_bytes(invalid_func_dump_path) {
    Some(_) =>
      fail(
        "did not expect invalid final-function dump at \{invalid_func_dump_path}",
      )
    None => ()
  }

  native_remove_if_exists(output_path)
  native_remove_if_exists(invalid_dump_path)
  native_remove_if_exists(invalid_func_dump_path)
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd validates remove-unused-brs on generated O4z slot14 predecessor" {
  let input_path = ".artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/10-slot13-remove-unused-names/binaryen.wasm"
  let output_path = native_tmp_file("rub-slot14-predecessor-output")
  let invalid_dump_path = "/tmp/starshine-invalid-final.wasm"
  let invalid_func_dump_path = "/tmp/starshine-invalid-final-func.txt"
  native_remove_if_exists(output_path)
  native_remove_if_exists(invalid_dump_path)
  native_remove_if_exists(invalid_func_dump_path)

  match run_cmd(["--remove-unused-brs", "--out", output_path, input_path]) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected native remove-unused-brs slot14 predecessor replay to validate, got \{err}",
      )
  }
  match native_read_bytes(output_path) {
    Some(bytes) => ignore(decode_module_bytes(bytes))
    None => fail("expected optimized output at \{output_path}")
  }
  match native_read_bytes(invalid_dump_path) {
    Some(_) =>
      fail("did not expect invalid final-module dump at \{invalid_dump_path}")
    None => ()
  }
  match native_read_bytes(invalid_func_dump_path) {
    Some(_) =>
      fail(
        "did not expect invalid final-function dump at \{invalid_func_dump_path}",
      )
    None => ()
  }

  native_remove_if_exists(output_path)
  native_remove_if_exists(invalid_dump_path)
  native_remove_if_exists(invalid_func_dump_path)
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter validates remove-unused-brs on debug artifact" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--remove-unused-brs", "--out", output_path, input_path],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected remove-unused-brs artifact replay success, got \{e}")
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  ignore(decode_module_bytes(writes[0].1))
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter validates remove-unused-brs on generated O4z slot14 predecessor" {
  let input_path = ".artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/10-slot13-remove-unused-names/binaryen.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected saved ordered O4z predecessor at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--remove-unused-brs", "--out", output_path, input_path],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected remove-unused-brs ordered O4z predecessor replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  ignore(decode_module_bytes(writes[0].1))
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter keeps extracted generated O4z slot14 remove-unused-brs output wasm-tools-valid" {
  let input_path = ".artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/10-slot13-remove-unused-names/binaryen.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected saved ordered O4z predecessor at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--extract-functions=1354", "--remove-unused-brs", "--out", output_path,
        input_path,
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected extracted remove-unused-brs ordered O4z predecessor replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, [
    "extract-functions=1354", "remove-unused-brs",
  ])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  match native_validate_wasm_bytes_with_wasm_tools(writes[0].1) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected extracted generated O4z slot14 remove-unused-brs output to stay wasm-tools-valid, got \{err}",
      )
  }
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter keeps extracted debug artifact func 2244 remove-unused-brs output wasm-tools-valid" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--extract-functions=2244", "--remove-unused-brs", "--out", output_path,
        input_path,
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected extracted debug artifact func 2244 remove-unused-brs replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, [
    "extract-functions=2244", "remove-unused-brs",
  ])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  match native_validate_wasm_bytes_with_wasm_tools(writes[0].1) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected extracted debug artifact func 2244 remove-unused-brs output to stay wasm-tools-valid, got \{err}",
      )
  }
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter keeps extracted generated O4z slot40 remove-unused-brs output wasm-tools-valid" {
  let input_path = ".artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/26-slot37-vacuum/binaryen.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected saved ordered O4z predecessor at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--extract-functions=3863", "--remove-unused-brs", "--out", output_path,
        input_path,
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected extracted remove-unused-brs ordered O4z slot40 replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, [
    "extract-functions=3863", "remove-unused-brs",
  ])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  match native_validate_wasm_bytes_with_wasm_tools(writes[0].1) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected extracted generated O4z slot40 remove-unused-brs output to stay wasm-tools-valid, got \{err}",
      )
  }
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter traces remove-unused-brs medium branchy hot skip on extracted debug artifact func 1547" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let stderr_chunks : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
    write_stderr=fn(bytes) {
      stderr_chunks.push(bytes)
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--extract-functions=1547", "--tracing", "pass", "--remove-unused-brs", "--out",
        output_path, input_path,
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected extracted func 1547 remove-unused-brs replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, [
    "extract-functions=1547", "remove-unused-brs",
  ])
  @debug.assert_eq(writes.length(), 1)
  ignore(decode_module_bytes(writes[0].1))
  let stderr = concat_ascii_bytes(stderr_chunks)
  assert_true(
    stderr.contains(
      "pass[remove-unused-brs]:skip-hot reason=medium-branchy-block-ladder-noop",
    ),
    msg=stderr,
  )
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter traces remove-unused-brs call-heavy mixed-if mesh hot skip on extracted debug artifact func 408" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let stderr_chunks : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
    write_stderr=fn(bytes) {
      stderr_chunks.push(bytes)
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--extract-functions=408", "--tracing", "pass", "--remove-unused-brs", "--out",
        output_path, input_path,
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected extracted func 408 remove-unused-brs replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, [
    "extract-functions=408", "remove-unused-brs",
  ])
  @debug.assert_eq(writes.length(), 1)
  ignore(decode_module_bytes(writes[0].1))
  let stderr = concat_ascii_bytes(stderr_chunks)
  assert_true(
    stderr.contains(
      "pass[remove-unused-brs]:skip-hot reason=call-heavy-mixed-if-mesh-noop",
    ),
    msg=stderr,
  )
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter traces remove-unused-brs localset-heavy value-if mesh hot skip on extracted debug artifact func 3021" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let stderr_chunks : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
    write_stderr=fn(bytes) {
      stderr_chunks.push(bytes)
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--extract-functions=3021", "--tracing", "pass", "--remove-unused-brs", "--out",
        output_path, input_path,
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected extracted func 3021 remove-unused-brs replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, [
    "extract-functions=3021", "remove-unused-brs",
  ])
  @debug.assert_eq(writes.length(), 1)
  ignore(decode_module_bytes(writes[0].1))
  let stderr = concat_ascii_bytes(stderr_chunks)
  assert_true(
    stderr.contains(
      "pass[remove-unused-brs]:skip-hot reason=localset-heavy-value-if-mesh-noop",
    ),
    msg=stderr,
  )
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter validates optimize-instructions on debug artifact" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--optimize-instructions", "--out", output_path, input_path],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected optimize-instructions artifact replay success, got \{e}")
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, ["optimize-instructions"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  let optimized = decode_module_bytes(writes[0].1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(29U))
  @debug.assert_eq(count_substring(pretty, "unreachable"), 4, msg=pretty)
  assert_true(pretty.contains("(br (Label 2))"), msg=pretty)
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter validates optimize-instructions on generated O4z slot16 predecessor" {
  let input_path = ".artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected saved ordered O4z predecessor at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--optimize-instructions", "--out", output_path, input_path],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected optimize-instructions ordered O4z slot16 predecessor replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, ["optimize-instructions"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  match native_validate_wasm_bytes_with_wasm_tools(writes[0].1) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected generated O4z slot16 optimize-instructions output to stay wasm-tools-valid, got \{err}",
      )
  }
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter keeps extracted generated O4z slot16 optimize-instructions func1818 output wasm-tools-valid" {
  let input_path = ".artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected saved ordered O4z predecessor at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--extract-functions=1818", "--optimize-instructions", "--out", output_path,
        input_path,
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected extracted generated O4z slot16 optimize-instructions func1818 replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, [
    "extract-functions=1818", "optimize-instructions",
  ])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  match native_validate_wasm_bytes_with_wasm_tools(writes[0].1) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected extracted generated O4z slot16 optimize-instructions func1818 output to stay wasm-tools-valid, got \{err}",
      )
  }
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter validates optimize-instructions on generated O4z slot44 predecessor" {
  let input_path = ".artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/29-slot43-precompute/binaryen.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected saved ordered O4z predecessor at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--optimize-instructions", "--out", output_path, input_path],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected optimize-instructions ordered O4z slot44 predecessor replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, ["optimize-instructions"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  match native_validate_wasm_bytes_with_wasm_tools(writes[0].1) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected generated O4z slot44 optimize-instructions output to stay wasm-tools-valid, got \{err}",
      )
  }
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter keeps extracted generated O4z slot44 optimize-instructions func1818 output wasm-tools-valid" {
  let input_path = ".artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/29-slot43-precompute/binaryen.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected saved ordered O4z predecessor at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--extract-functions=1818", "--optimize-instructions", "--out", output_path,
        input_path,
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected extracted generated O4z slot44 optimize-instructions func1818 replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, [
    "extract-functions=1818", "optimize-instructions",
  ])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  match native_validate_wasm_bytes_with_wasm_tools(writes[0].1) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected extracted generated O4z slot44 optimize-instructions func1818 output to stay wasm-tools-valid, got \{err}",
      )
  }
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter validates heap-store-optimization on debug artifact" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--heap-store-optimization", "--out", output_path, input_path],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected heap-store-optimization artifact replay success, got \{e}")
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, ["heap-store-optimization"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  ignore(decode_module_bytes(writes[0].1))
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter validates pick-load-signs on debug artifact" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--pick-load-signs", "--out", output_path, input_path],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("expected pick-load-signs artifact replay success, got \{e}")
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, ["pick-load-signs"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  ignore(decode_module_bytes(writes[0].1))
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter validates precompute on generated O4z slot19 predecessor" {
  let input_path = ".artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/15-slot18-pick-load-signs/binaryen.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected saved ordered O4z predecessor at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(["--precompute", "--out", output_path, input_path], io) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected precompute ordered O4z slot19 predecessor replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, ["precompute"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  match native_validate_wasm_bytes_with_wasm_tools(writes[0].1) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected generated O4z slot19 precompute output to stay wasm-tools-valid, got \{err}",
      )
  }
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter keeps extracted generated O4z slot19 precompute func108 output wasm-tools-valid" {
  let input_path = ".artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/15-slot18-pick-load-signs/binaryen.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected saved ordered O4z predecessor at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--extract-functions=108", "--precompute", "--out", output_path, input_path,
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected extracted precompute ordered O4z slot19 func108 replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, [
    "extract-functions=108", "precompute",
  ])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  match native_validate_wasm_bytes_with_wasm_tools(writes[0].1) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected extracted generated O4z slot19 precompute func108 output to stay wasm-tools-valid, got \{err}",
      )
  }
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter validates vacuum on generated O4z slot23 predecessor" {
  let input_path = ".artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/17-slot21-tuple-optimization/binaryen.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected saved ordered O4z predecessor at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(["--vacuum", "--out", output_path, input_path], io) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected vacuum ordered O4z slot23 predecessor replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, ["vacuum"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  match native_validate_wasm_bytes_with_wasm_tools(writes[0].1) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected generated O4z slot23 vacuum output to stay wasm-tools-valid, got \{err}",
      )
  }
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter keeps extracted generated O4z slot23 vacuum func652 output wasm-tools-valid" {
  let input_path = ".artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/17-slot21-tuple-optimization/binaryen.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected saved ordered O4z predecessor at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--extract-functions=652", "--vacuum", "--out", output_path, input_path],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected extracted generated O4z slot23 vacuum func652 replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, ["extract-functions=652", "vacuum"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  match native_validate_wasm_bytes_with_wasm_tools(writes[0].1) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected extracted generated O4z slot23 vacuum func652 output to stay wasm-tools-valid, got \{err}",
      )
  }
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter validates vacuum on generated O4z slot33 predecessor" {
  let input_path = ".artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/22-slot32-simplify-locals/binaryen.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected saved ordered O4z predecessor at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(["--vacuum", "--out", output_path, input_path], io) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected vacuum ordered O4z slot33 predecessor replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, ["vacuum"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  match native_validate_wasm_bytes_with_wasm_tools(writes[0].1) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected generated O4z slot33 vacuum output to stay wasm-tools-valid, got \{err}",
      )
  }
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter keeps extracted generated O4z slot33 vacuum func4142 output wasm-tools-valid" {
  let input_path = ".artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/22-slot32-simplify-locals/binaryen.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected saved ordered O4z predecessor at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--extract-functions=4142", "--vacuum", "--out", output_path, input_path],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected extracted generated O4z slot33 vacuum func4142 replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, ["extract-functions=4142", "vacuum"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  match native_validate_wasm_bytes_with_wasm_tools(writes[0].1) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected extracted generated O4z slot33 vacuum func4142 output to stay wasm-tools-valid, got \{err}",
      )
  }
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter validates precompute on debug artifact" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(["--precompute", "--out", output_path, input_path], io) {
    Ok(v) => v
    Err(e) => fail("expected precompute artifact replay success, got \{e}")
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, ["precompute"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  ignore(decode_module_bytes(writes[0].1))
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter validates post-ssa cleanup mini-chain on debug artifact" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--dead-code-elimination", "--vacuum", "--optimize-instructions", "--simplify-locals",
        "--out", output_path, input_path,
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected post-ssa cleanup mini-chain artifact replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, [
    "dead-code-elimination", "vacuum", "optimize-instructions", "simplify-locals",
  ])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  ignore(decode_module_bytes(writes[0].1))
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter validates modeled post-ssa cleanup prefix on debug artifact" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let passes = [
    "--dead-code-elimination", "--remove-unused-names", "--remove-unused-brs", "--remove-unused-names",
    "--vacuum", "--remove-unused-brs", "--optimize-instructions", "--heap-store-optimization",
    "--pick-load-signs", "--simplify-locals",
  ]
  let argv = passes.copy()
  argv.push("--out")
  argv.push(output_path)
  argv.push(input_path)
  let summary = match run_cmd_with_adapter(argv, io) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected modeled post-ssa cleanup prefix artifact replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, [
    "dead-code-elimination", "remove-unused-names", "remove-unused-brs", "remove-unused-names",
    "vacuum", "remove-unused-brs", "optimize-instructions", "heap-store-optimization",
    "pick-load-signs", "simplify-locals",
  ])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)
  ignore(decode_module_bytes(writes[0].1))
}

///|
#cfg(target="native")
#skip("manual repository artifact replay; bounded command tests stay active")
test "run_cmd_with_adapter print-func sees simplify-locals remove debug artifact Func 71 const fanout webs" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let output_path = "out.wasm"
  let wasm = match native_read_bytes(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let writes : Array[(String, Bytes)] = []
  let stderr_writes : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == input_path },
    list_candidates=fn() { [input_path] },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
    write_stderr=fn(bytes) {
      stderr_writes.push(bytes)
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--simplify-locals", "--print-func", "71", "--out", output_path, input_path,
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected simplify-locals print-func artifact replay success, got \{e}",
      )
  }
  @debug.assert_eq(summary.input_files, [input_path])
  @debug.assert_eq(summary.output_files, [output_path])
  @debug.assert_eq(summary.resolved_passes, ["simplify-locals", "print-func=71"])
  @debug.assert_eq(writes.length(), 1)
  @debug.assert_eq(writes[0].0, output_path)

  let stderr_text = concat_ascii_bytes(stderr_writes)
  assert_true(stderr_text.contains("Func[71 "), msg=stderr_text)
  assert_false(stderr_text.contains("local.set (Local 557)"), msg=stderr_text)
  assert_false(stderr_text.contains("local.set (Local 558)"), msg=stderr_text)
  assert_false(stderr_text.contains("local.set (Local 559)"), msg=stderr_text)
  assert_false(stderr_text.contains("local.set (Local 560)"), msg=stderr_text)
  assert_false(stderr_text.contains("local.set (Local 561)"), msg=stderr_text)
  assert_false(stderr_text.contains("local.set (Local 562)"), msg=stderr_text)
  assert_false(stderr_text.contains("local.set (Local 563)"), msg=stderr_text)
  assert_false(stderr_text.contains("local.set (Local 564)"), msg=stderr_text)
  assert_false(stderr_text.contains("local.set (Local 540)"), msg=stderr_text)
  assert_false(stderr_text.contains("local.set (Local 541)"), msg=stderr_text)
  assert_false(stderr_text.contains("local.set (Local 542)"), msg=stderr_text)
  assert_false(stderr_text.contains("local.set (Local 543)"), msg=stderr_text)
  assert_false(stderr_text.contains("local.set (Local 544)"), msg=stderr_text)
  assert_false(stderr_text.contains("local.set (Local 545)"), msg=stderr_text)
  assert_false(stderr_text.contains("local.set (Local 546)"), msg=stderr_text)
  assert_false(stderr_text.contains("local.set (Local 547)"), msg=stderr_text)
}

///|
#cfg(target="wasm")
test "run_cmd uses wasm default io to read and write wasm files" {
  let dir = "tmp-starshine-cmd-wasm-default-io-\{@env.now()}"
  let input_path = "\{dir}/in.wasm"
  let output_path = "\{dir}/out.wasm"
  ignore(@sfs.remove_file(input_path))
  ignore(@sfs.remove_file(output_path))
  ignore(@sfs.remove_dir(dir))
  match @sfs.create_dir(dir) {
    Ok(_) => ()
    Err(e) => fail("expected wasm default io test dir creation, got \{e}")
  }
  let wasm = encode_module_bytes(fixture_i32_const_module(77))
  match @sfs.write_file_bytes(input_path, wasm) {
    Ok(_) => ()
    Err(e) => fail("expected wasm default io input write, got \{e}")
  }

  let code = run_cmd_exit_code(["--out", output_path, input_path])
  @debug.assert_eq(code, 0)
  match @sfs.read_file_bytes(output_path) {
    Ok(bytes) => {
      let _decoded = decode_module_bytes(bytes)
      assert_true(bytes.length() > 0)
    }
    Err(e) => fail("expected wasm default io output read, got \{e}")
  }

  ignore(@sfs.remove_file(input_path))
  ignore(@sfs.remove_file(output_path))
  ignore(@sfs.remove_dir(dir))
}

///|
#cfg(target="wasm")
test "run_cmd uses wasm default io for --help" {
  match run_cmd(["--help"]) {
    Ok(_) => ()
    Err(e) => fail("expected wasm --help success with default io, got \{e}")
  }
}

///|
#cfg(target="wasm")
test "run_cmd uses wasm default io for --version" {
  match run_cmd(["--version"]) {
    Ok(_) => ()
    Err(e) => fail("expected wasm --version success with default io, got \{e}")
  }
}

///|
test "phase tracing emits compact pass transitions" {
  let lines : Array[String] = []
  let trace = cmd_phase_trace_callback(fn(line) { lines.push(line) })
  trace("pipeline:start requested=1")
  trace("pass[merge-blocks]:start")
  trace("pass[merge-blocks]:func func_idx=(Func 0)")
  trace("pass[merge-blocks]:done changed=false")
  trace("perf:timer name=pass:merge-blocks elapsed_us=10 total_us=10")
  trace("pass[coalesce-locals-cfg]:start")
  trace(
    "pass[coalesce-locals-cfg]:skip reason=artifact-scale-defined-functions count=12000",
  )
  trace("pipeline:done changed=true")
  @debug.assert_eq(lines, [
    "pipeline:start requested=1", "phase pass=merge-blocks", "phase pass=coalesce-locals-cfg",
    "pipeline:done changed=true",
  ])
}
