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
  let nan_bits : UInt = 0x7FC00000
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
test "run_cmd_with_adapter keeps struct.set for HSO readonly ref-prefix memory.size wasm inputs" {
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
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter keeps struct.set for HSO pure ref-prefix ref-result wasm inputs" {
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
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
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
test "run_cmd_with_adapter keeps struct.set for HSO decoded value-prefix table.size wasm inputs" {
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
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter keeps struct.set for HSO decoded value-prefix local.get wasm inputs" {
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
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter keeps struct.set for HSO decoded value-prefix immutable global wasm inputs" {
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
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
}

///|
test "run_cmd_with_adapter keeps struct.set for HSO decoded value-prefix mutable global wasm inputs" {
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
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("struct.set"), msg=pretty)
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
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if local.get 1 drop end))",
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
test "run_cmd_with_adapter dumps lowered remove-unused-brs carried guard wrappers without br_if" {
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
  assert_false(wat.contains("br_if"), msg=wat)
  ignore(decode_module_bytes(writes[0].1))
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
        "64", "--closed-world", "--tracing", "helper", "--debug-serial-passes", "--vacuum",
        "a.wasm",
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
