///|
pub enum MetamorphicValidTransform {
  AddNonNameCustomSection
  AddLeadingNonNameCustomSection
  AddModuleNameSection
  AddUnusedPassiveDataSegment
  AddUnusedImmutableI32Global
  AddUnusedEmptyFunction
  AddUnusedEmptyFunctionType
  AddUnusedFuncrefTable
  AddUnusedPassiveFuncrefElementSegment
  AddFunctionNamesSection
  AddLocalNamesSection
  AddLabelNamesSection
  AddTypeNamesSection
  AddGlobalNamesSection
  AddTableNamesSection
  AddMemoryNamesSection
  AddDataNamesSection
  AddElemNamesSection
  AddTagNamesSection
  AddFieldNamesSection
  AddUnusedI32LocalToDefinedFunctions
  AddLeadingNopToDefinedFunctions
  AddTrailingNopToDefinedFunctions
  AddLeadingI32ConstDropToDefinedFunctions
} derive(Eq, Debug)

///|
pub fn metamorphic_valid_transform_id(
  transform : MetamorphicValidTransform,
) -> String {
  match transform {
    AddNonNameCustomSection => "add-non-name-custom-section"
    AddLeadingNonNameCustomSection => "add-leading-non-name-custom-section"
    AddModuleNameSection => "add-module-name-section"
    AddUnusedPassiveDataSegment => "add-unused-passive-data-segment"
    AddUnusedImmutableI32Global => "add-unused-immutable-i32-global"
    AddUnusedEmptyFunction => "add-unused-empty-function"
    AddUnusedEmptyFunctionType => "add-unused-empty-function-type"
    AddUnusedFuncrefTable => "add-unused-funcref-table"
    AddUnusedPassiveFuncrefElementSegment =>
      "add-unused-passive-funcref-element-segment"
    AddFunctionNamesSection => "add-function-names-section"
    AddLocalNamesSection => "add-local-names-section"
    AddLabelNamesSection => "add-label-names-section"
    AddTypeNamesSection => "add-type-names-section"
    AddGlobalNamesSection => "add-global-names-section"
    AddTableNamesSection => "add-table-names-section"
    AddMemoryNamesSection => "add-memory-names-section"
    AddDataNamesSection => "add-data-names-section"
    AddElemNamesSection => "add-elem-names-section"
    AddTagNamesSection => "add-tag-names-section"
    AddFieldNamesSection => "add-field-names-section"
    AddUnusedI32LocalToDefinedFunctions =>
      "add-unused-i32-local-to-defined-functions"
    AddLeadingNopToDefinedFunctions => "add-leading-nop-to-defined-functions"
    AddTrailingNopToDefinedFunctions => "add-trailing-nop-to-defined-functions"
    AddLeadingI32ConstDropToDefinedFunctions =>
      "add-leading-i32-const-drop-to-defined-functions"
  }
}

///|
pub struct MetamorphicValidTransformResult {
  transform_id : String
  wasm_module : @lib.Module
} derive(Eq, Debug)

///|
pub struct ValidateValidMetamorphicFuzzStats {
  profile : String
  attempts : Int
  generated : Int
  transformed : Int
  validated : Int
  transform_ids : Array[String]
} derive(Eq, Debug)

///|
fn metamorphic_add_non_name_custom_section(mod : @lib.Module) -> @lib.Module {
  let custom_secs = []
  for sec in mod.custom_secs {
    custom_secs.push(sec)
  }
  custom_secs.push(
    @lib.CustomSec::new(
      @lib.Name::from_string(
        "starshine.metamorphic.add-non-name-custom-section",
      ),
      b"semantics-preserving custom payload",
    ),
  )
  mod.with_custom_secs(custom_secs)
}

///|
fn metamorphic_add_leading_non_name_custom_section(
  mod : @lib.Module,
) -> @lib.Module {
  let custom_secs = [
    @lib.CustomSec::new(
      @lib.Name::from_string(
        "starshine.metamorphic.add-leading-non-name-custom-section",
      ),
      b"semantics-preserving leading custom payload",
    ),
  ]
  for sec in mod.custom_secs {
    custom_secs.push(sec)
  }
  mod.with_custom_secs(custom_secs)
}

///|
fn metamorphic_with_name_sec_func_names(
  mod : @lib.Module,
  func_names : @lib.NameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=Some(func_names),
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(func_names=Some(func_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_local_names(
  mod : @lib.Module,
  local_names : @lib.IndirectNameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=Some(local_names),
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(local_names=Some(local_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_label_names(
  mod : @lib.Module,
  label_names : @lib.IndirectNameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=Some(label_names),
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(label_names=Some(label_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_type_names(
  mod : @lib.Module,
  type_names : @lib.NameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=Some(type_names),
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(type_names=Some(type_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_global_names(
  mod : @lib.Module,
  global_names : @lib.NameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=Some(global_names),
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(global_names=Some(global_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_table_names(
  mod : @lib.Module,
  table_names : @lib.NameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=Some(table_names),
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(table_names=Some(table_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_memory_names(
  mod : @lib.Module,
  memory_names : @lib.NameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=Some(memory_names),
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(memory_names=Some(memory_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_data_names(
  mod : @lib.Module,
  data_names : @lib.NameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=Some(data_names),
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(data_names=Some(data_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_elem_names(
  mod : @lib.Module,
  elem_names : @lib.NameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=Some(elem_names),
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(elem_names=Some(elem_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_tag_names(
  mod : @lib.Module,
  tag_names : @lib.NameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=Some(tag_names),
      )
    None => @lib.NameSec::new(tag_names=Some(tag_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_field_names(
  mod : @lib.Module,
  field_names : @lib.IndirectNameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=Some(field_names),
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(field_names=Some(field_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_add_module_name_section(mod : @lib.Module) -> @lib.Module {
  mod.with_name_sec(
    @lib.NameSec::new(
      module_name=Some(@lib.Name::from_string("starshine.metamorphic.module")),
    ),
  )
}

///|
fn metamorphic_total_func_count(mod : @lib.Module) -> Int {
  let mut count = 0
  match mod.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  match mod.func_sec {
    Some(@lib.FuncSec(type_idxs)) => count += type_idxs.length()
    None => ()
  }
  count
}

///|
fn metamorphic_add_function_names_section(mod : @lib.Module) -> @lib.Module {
  let names = []
  let count = metamorphic_total_func_count(mod)
  for i = 0; i < count; i = i + 1 {
    names.push(
      @lib.NameAssoc::new(
        i.reinterpret_as_uint(),
        @lib.Name::from_string("metamorphic_func_\{i}"),
      ),
    )
  }
  metamorphic_with_name_sec_func_names(mod, @lib.NameMap::new(names))
}

///|
fn metamorphic_flatten_types(mod : @lib.Module) -> Array[@lib.SubType] {
  let subtypes : Array[@lib.SubType] = []
  match mod.type_sec {
    Some(@lib.TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          @lib.SingleRecType(sub_type) => subtypes.push(sub_type)
          @lib.GroupRecType(group) =>
            for sub_type in group {
              subtypes.push(sub_type)
            }
        }
      }
    None => ()
  }
  subtypes
}

///|
fn metamorphic_func_param_count(
  subtypes : Array[@lib.SubType],
  type_idx : @lib.TypeIdx,
) -> Int {
  match type_idx {
    @lib.TypeIdx(i) =>
      match subtypes.get(i.reinterpret_as_int()) {
        Some(sub_type) =>
          match sub_type.get_comptype() {
            @lib.FuncCompType(params, _) => params.length()
            _ => 0
          }
        None => 0
      }
    @lib.RecIdx(_) => 0
  }
}

///|
fn metamorphic_add_type_names_section(mod : @lib.Module) -> @lib.Module {
  let names = []
  let subtypes = metamorphic_flatten_types(mod)
  for i = 0; i < subtypes.length(); i = i + 1 {
    names.push(
      @lib.NameAssoc::new(
        i.reinterpret_as_uint(),
        @lib.Name::from_string("metamorphic_type_\{i}"),
      ),
    )
  }
  metamorphic_with_name_sec_type_names(mod, @lib.NameMap::new(names))
}

///|
fn metamorphic_add_global_names_section(mod : @lib.Module) -> @lib.Module {
  let names = []
  let mut count = 0
  match mod.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.GlobalExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  match mod.global_sec {
    Some(@lib.GlobalSec(globals)) => count += globals.length()
    None => ()
  }
  for i = 0; i < count; i = i + 1 {
    names.push(
      @lib.NameAssoc::new(
        i.reinterpret_as_uint(),
        @lib.Name::from_string("metamorphic_global_\{i}"),
      ),
    )
  }
  metamorphic_with_name_sec_global_names(mod, @lib.NameMap::new(names))
}

///|
fn metamorphic_add_table_names_section(mod : @lib.Module) -> @lib.Module {
  let names = []
  let mut count = 0
  match mod.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.TableExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  match mod.table_sec {
    Some(@lib.TableSec(tables)) => count += tables.length()
    None => ()
  }
  for i = 0; i < count; i = i + 1 {
    names.push(
      @lib.NameAssoc::new(
        i.reinterpret_as_uint(),
        @lib.Name::from_string("metamorphic_table_\{i}"),
      ),
    )
  }
  metamorphic_with_name_sec_table_names(mod, @lib.NameMap::new(names))
}

///|
fn metamorphic_add_memory_names_section(mod : @lib.Module) -> @lib.Module {
  let names = []
  let mut count = 0
  match mod.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.MemExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  match mod.mem_sec {
    Some(@lib.MemSec(mems)) => count += mems.length()
    None => ()
  }
  for i = 0; i < count; i = i + 1 {
    names.push(
      @lib.NameAssoc::new(
        i.reinterpret_as_uint(),
        @lib.Name::from_string("metamorphic_memory_\{i}"),
      ),
    )
  }
  metamorphic_with_name_sec_memory_names(mod, @lib.NameMap::new(names))
}

///|
fn metamorphic_add_data_names_section(mod : @lib.Module) -> @lib.Module {
  let names = []
  let count = match mod.data_sec {
    Some(@lib.DataSec(datas)) => datas.length()
    None => 0
  }
  for i = 0; i < count; i = i + 1 {
    names.push(
      @lib.NameAssoc::new(
        i.reinterpret_as_uint(),
        @lib.Name::from_string("metamorphic_data_\{i}"),
      ),
    )
  }
  metamorphic_with_name_sec_data_names(mod, @lib.NameMap::new(names))
}

///|
fn metamorphic_add_elem_names_section(mod : @lib.Module) -> @lib.Module {
  let names = []
  let count = match mod.elem_sec {
    Some(@lib.ElemSec(elems)) => elems.length()
    None => 0
  }
  for i = 0; i < count; i = i + 1 {
    names.push(
      @lib.NameAssoc::new(
        i.reinterpret_as_uint(),
        @lib.Name::from_string("metamorphic_elem_\{i}"),
      ),
    )
  }
  metamorphic_with_name_sec_elem_names(mod, @lib.NameMap::new(names))
}

///|
fn metamorphic_add_tag_names_section(mod : @lib.Module) -> @lib.Module {
  let names = []
  let mut count = 0
  match mod.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.TagExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  match mod.tag_sec {
    Some(@lib.TagSec(tags)) => count += tags.length()
    None => ()
  }
  for i = 0; i < count; i = i + 1 {
    names.push(
      @lib.NameAssoc::new(
        i.reinterpret_as_uint(),
        @lib.Name::from_string("metamorphic_tag_\{i}"),
      ),
    )
  }
  metamorphic_with_name_sec_tag_names(mod, @lib.NameMap::new(names))
}

///|
fn metamorphic_add_field_names_section(mod : @lib.Module) -> @lib.Module {
  let entries : Array[@lib.IndirectNameAssoc] = []
  let subtypes = metamorphic_flatten_types(mod)
  for type_idx = 0; type_idx < subtypes.length(); type_idx = type_idx + 1 {
    match subtypes[type_idx].get_comptype() {
      @lib.StructCompType(fields) => {
        let field_entries : Array[@lib.NameAssoc] = []
        for field_idx = 0
            field_idx < fields.length()
            field_idx = field_idx + 1 {
          field_entries.push(
            @lib.NameAssoc::new(
              field_idx.reinterpret_as_uint(),
              @lib.Name::from_string(
                "metamorphic_field_\{type_idx}_\{field_idx}",
              ),
            ),
          )
        }
        entries.push(
          @lib.IndirectNameAssoc::new(
            type_idx.reinterpret_as_uint(),
            @lib.NameMap::new(field_entries),
          ),
        )
      }
      _ => ()
    }
  }
  metamorphic_with_name_sec_field_names(mod, @lib.IndirectNameMap::new(entries))
}

///|
fn metamorphic_instr_label_count(instr : @lib.Instruction) -> Int {
  match instr {
    @lib.Block(_, body) | @lib.Loop(_, body) | @lib.TryTable(_, _, body) =>
      1 + metamorphic_expr_label_count(body)
    @lib.If(_, then_instrs, else_instrs) => {
      let else_count = match else_instrs {
        Some(instrs) => metamorphic_instrs_label_count(instrs)
        None => 0
      }
      1 + metamorphic_instrs_label_count(then_instrs) + else_count
    }
    _ => 0
  }
}

///|
fn metamorphic_instrs_label_count(instrs : Array[@lib.Instruction]) -> Int {
  let mut total = 0
  for instr in instrs {
    total += metamorphic_instr_label_count(instr)
  }
  total
}

///|
fn metamorphic_expr_label_count(expr : @lib.Expr) -> Int {
  let @lib.Expr(instrs) = expr
  metamorphic_instrs_label_count(instrs)
}

///|
fn metamorphic_add_label_names_section(mod : @lib.Module) -> @lib.Module {
  let entries : Array[@lib.IndirectNameAssoc] = []
  let mut abs_func_idx = 0
  match mod.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => abs_func_idx += 1
          _ => ()
        }
      }
    None => ()
  }
  match mod.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let label_entries : Array[@lib.NameAssoc] = []
        let label_count = match func {
          @lib.Func(_, expr) => metamorphic_expr_label_count(expr)
        }
        for label_idx = 0; label_idx < label_count; label_idx = label_idx + 1 {
          label_entries.push(
            @lib.NameAssoc::new(
              label_idx.reinterpret_as_uint(),
              @lib.Name::from_string(
                "metamorphic_label_\{abs_func_idx}_\{label_idx}",
              ),
            ),
          )
        }
        if label_entries.length() > 0 {
          entries.push(
            @lib.IndirectNameAssoc::new(
              abs_func_idx.reinterpret_as_uint(),
              @lib.NameMap::new(label_entries),
            ),
          )
        }
        abs_func_idx += 1
      }
    None => ()
  }
  metamorphic_with_name_sec_label_names(mod, @lib.IndirectNameMap::new(entries))
}

///|
fn metamorphic_add_local_names_section(mod : @lib.Module) -> @lib.Module {
  let subtypes = metamorphic_flatten_types(mod)
  let entries : Array[@lib.IndirectNameAssoc] = []
  let mut abs_func_idx = 0
  match mod.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(type_idx)) => {
            let local_entries : Array[@lib.NameAssoc] = []
            let count = metamorphic_func_param_count(subtypes, type_idx)
            for local_idx = 0; local_idx < count; local_idx = local_idx + 1 {
              local_entries.push(
                @lib.NameAssoc::new(
                  local_idx.reinterpret_as_uint(),
                  @lib.Name::from_string(
                    "metamorphic_local_\{abs_func_idx}_\{local_idx}",
                  ),
                ),
              )
            }
            entries.push(
              @lib.IndirectNameAssoc::new(
                abs_func_idx.reinterpret_as_uint(),
                @lib.NameMap::new(local_entries),
              ),
            )
            abs_func_idx += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  match (mod.func_sec, mod.code_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs))) => {
      let count = if type_idxs.length() < funcs.length() {
        type_idxs.length()
      } else {
        funcs.length()
      }
      for def_idx = 0; def_idx < count; def_idx = def_idx + 1 {
        let param_count = metamorphic_func_param_count(
          subtypes,
          type_idxs[def_idx],
        )
        let local_count = match funcs[def_idx] {
          @lib.Func(locals, _) => param_count + locals.length()
        }
        let local_entries : Array[@lib.NameAssoc] = []
        for local_idx = 0; local_idx < local_count; local_idx = local_idx + 1 {
          local_entries.push(
            @lib.NameAssoc::new(
              local_idx.reinterpret_as_uint(),
              @lib.Name::from_string(
                "metamorphic_local_\{abs_func_idx}_\{local_idx}",
              ),
            ),
          )
        }
        entries.push(
          @lib.IndirectNameAssoc::new(
            abs_func_idx.reinterpret_as_uint(),
            @lib.NameMap::new(local_entries),
          ),
        )
        abs_func_idx += 1
      }
    }
    _ => ()
  }
  metamorphic_with_name_sec_local_names(mod, @lib.IndirectNameMap::new(entries))
}

///|
fn metamorphic_add_unused_passive_data_segment(
  mod : @lib.Module,
) -> @lib.Module {
  let datas = []
  match mod.data_sec {
    Some(@lib.DataSec(existing)) =>
      for data in existing {
        datas.push(data)
      }
    None => ()
  }
  datas.push(
    @lib.Data::new(
      @lib.DataMode::passive(),
      b"starshine metamorphic passive data",
    ),
  )
  mod
  .with_data_cnt_sec(
    @lib.DataCntSec::new(@lib.U32(datas.length().reinterpret_as_uint())),
  )
  .with_data_sec(@lib.DataSec::new(datas))
}

///|
fn metamorphic_add_unused_immutable_i32_global(
  mod : @lib.Module,
) -> @lib.Module {
  let globals = []
  match mod.global_sec {
    Some(@lib.GlobalSec(existing)) =>
      for global in existing {
        globals.push(global)
      }
    None => ()
  }
  globals.push(
    @lib.Global::new(
      @lib.GlobalType::new(@lib.ValType::i32(), false),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    ),
  )
  mod.with_global_sec(@lib.GlobalSec::new(globals))
}

///|
fn metamorphic_count_flat_types(rec_types : Array[@lib.RecType]) -> Int {
  let mut count = 0
  for rec_type in rec_types {
    match rec_type {
      @lib.SingleRecType(_) => count += 1
      @lib.GroupRecType(group) => count += group.length()
    }
  }
  count
}

///|
fn metamorphic_add_unused_funcref_table(mod : @lib.Module) -> @lib.Module {
  let tables = []
  match mod.table_sec {
    Some(@lib.TableSec(existing)) =>
      for table in existing {
        tables.push(table)
      }
    None => ()
  }
  tables.push(
    @lib.Table::new(
      @lib.TableType::new(
        @lib.RefType::abs(@lib.AbsHeapType::func()),
        @lib.Limits::i32(0U, Some(0U)),
      ),
      None,
    ),
  )
  mod.with_table_sec(@lib.TableSec::new(tables))
}

///|
fn metamorphic_add_unused_passive_funcref_element_segment(
  mod : @lib.Module,
) -> @lib.Module {
  let elems = []
  match mod.elem_sec {
    Some(@lib.ElemSec(existing)) =>
      for elem in existing {
        elems.push(elem)
      }
    None => ()
  }
  elems.push(@lib.Elem::new(@lib.ElemMode::passive(), @lib.ElemKind::funcs([])))
  mod.with_elem_sec(@lib.ElemSec::new(elems))
}

///|
fn metamorphic_add_unused_empty_function_type(mod : @lib.Module) -> @lib.Module {
  let types = []
  match mod.type_sec {
    Some(@lib.TypeSec(existing)) =>
      for rec_type in existing {
        types.push(rec_type)
      }
    None => ()
  }
  types.push(
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  )
  mod.with_type_sec(@lib.TypeSec::new(types))
}

///|
fn metamorphic_add_unused_i32_local_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, expr) => {
            let next_locals = locals.copy()
            next_locals.push(@lib.ValType::i32())
            funcs.push(@lib.Func::new(next_locals, expr))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_leading_nop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = [@lib.Instruction::nop()]
            for instr in instrs {
              next_instrs.push(instr)
            }
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_trailing_nop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = []
            for instr in instrs {
              next_instrs.push(instr)
            }
            next_instrs.push(@lib.Instruction::nop())
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_leading_i32_const_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = [
              @lib.Instruction::i32_const(0),
              @lib.Instruction::drop(),
            ]
            for instr in instrs {
              next_instrs.push(instr)
            }
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_unused_empty_function(mod : @lib.Module) -> @lib.Module {
  let types = []
  match mod.type_sec {
    Some(@lib.TypeSec(existing)) =>
      for rec_type in existing {
        types.push(rec_type)
      }
    None => ()
  }
  let empty_func_type_idx = @lib.TypeIdx::new(
    metamorphic_count_flat_types(types).reinterpret_as_uint(),
  )
  types.push(
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  )
  let func_type_idxs = []
  match mod.func_sec {
    Some(@lib.FuncSec(existing)) =>
      for type_idx in existing {
        func_type_idxs.push(type_idx)
      }
    None => ()
  }
  func_type_idxs.push(empty_func_type_idx)
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        funcs.push(func)
      }
    None => ()
  }
  funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])))
  mod
  .with_type_sec(@lib.TypeSec::new(types))
  .with_func_sec(@lib.FuncSec::new(func_type_idxs))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_valid_transforms() -> Array[MetamorphicValidTransform] {
  [
    AddNonNameCustomSection,
    AddLeadingNonNameCustomSection,
    AddModuleNameSection,
    AddUnusedPassiveDataSegment,
    AddUnusedImmutableI32Global,
    AddUnusedEmptyFunction,
    AddUnusedEmptyFunctionType,
    AddUnusedFuncrefTable,
    AddUnusedPassiveFuncrefElementSegment,
    AddFunctionNamesSection,
    AddLocalNamesSection,
    AddLabelNamesSection,
    AddTypeNamesSection,
    AddGlobalNamesSection,
    AddTableNamesSection,
    AddMemoryNamesSection,
    AddDataNamesSection,
    AddElemNamesSection,
    AddTagNamesSection,
    AddFieldNamesSection,
    AddUnusedI32LocalToDefinedFunctions,
    AddLeadingNopToDefinedFunctions,
    AddTrailingNopToDefinedFunctions,
    AddLeadingI32ConstDropToDefinedFunctions,
  ]
}

///|
pub fn metamorphic_apply_transform(
  mod : @lib.Module,
  transform : MetamorphicValidTransform,
) -> Result[MetamorphicValidTransformResult, String] {
  let transformed = match transform {
    AddNonNameCustomSection => metamorphic_add_non_name_custom_section(mod)
    AddLeadingNonNameCustomSection =>
      metamorphic_add_leading_non_name_custom_section(mod)
    AddModuleNameSection => metamorphic_add_module_name_section(mod)
    AddUnusedPassiveDataSegment =>
      metamorphic_add_unused_passive_data_segment(mod)
    AddUnusedImmutableI32Global =>
      metamorphic_add_unused_immutable_i32_global(mod)
    AddUnusedEmptyFunction => metamorphic_add_unused_empty_function(mod)
    AddUnusedEmptyFunctionType =>
      metamorphic_add_unused_empty_function_type(mod)
    AddUnusedFuncrefTable => metamorphic_add_unused_funcref_table(mod)
    AddUnusedPassiveFuncrefElementSegment =>
      metamorphic_add_unused_passive_funcref_element_segment(mod)
    AddFunctionNamesSection => metamorphic_add_function_names_section(mod)
    AddLocalNamesSection => metamorphic_add_local_names_section(mod)
    AddLabelNamesSection => metamorphic_add_label_names_section(mod)
    AddTypeNamesSection => metamorphic_add_type_names_section(mod)
    AddGlobalNamesSection => metamorphic_add_global_names_section(mod)
    AddTableNamesSection => metamorphic_add_table_names_section(mod)
    AddMemoryNamesSection => metamorphic_add_memory_names_section(mod)
    AddDataNamesSection => metamorphic_add_data_names_section(mod)
    AddElemNamesSection => metamorphic_add_elem_names_section(mod)
    AddTagNamesSection => metamorphic_add_tag_names_section(mod)
    AddFieldNamesSection => metamorphic_add_field_names_section(mod)
    AddUnusedI32LocalToDefinedFunctions =>
      metamorphic_add_unused_i32_local_to_defined_functions(mod)
    AddLeadingNopToDefinedFunctions =>
      metamorphic_add_leading_nop_to_defined_functions(mod)
    AddTrailingNopToDefinedFunctions =>
      metamorphic_add_trailing_nop_to_defined_functions(mod)
    AddLeadingI32ConstDropToDefinedFunctions =>
      metamorphic_add_leading_i32_const_drop_to_defined_functions(mod)
  }
  match validate_module(transformed) {
    Ok(_) =>
      Ok({
        transform_id: metamorphic_valid_transform_id(transform),
        wasm_module: transformed,
      })
    Err(err) =>
      Err(
        "metamorphic transform \{metamorphic_valid_transform_id(transform)} produced invalid module: \{validation_error_message(err)}",
      )
  }
}

///|
fn metamorphic_profile_config(
  profile : String,
) -> Result[GenValidConfig, String] {
  match profile {
    "smoke" | "ci" | "stress" => Ok(GenValidConfig::natural_default())
    _ => Err("unknown validate-valid-metamorphic profile: \{profile}")
  }
}

///|
fn metamorphic_profile_case_count(profile : String) -> Result[Int, String] {
  match profile {
    "smoke" => Ok(1)
    "ci" => Ok(10)
    "stress" => Ok(100)
    _ => Err("unknown validate-valid-metamorphic profile: \{profile}")
  }
}

///|
pub fn run_validate_valid_metamorphic_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[ValidateValidMetamorphicFuzzStats, String] {
  let config = match metamorphic_profile_config(profile) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let case_count = match metamorphic_profile_case_count(profile) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let transforms = metamorphic_valid_transforms()
  let transform_ids = transforms.map(metamorphic_valid_transform_id)
  let mut attempts = 0
  let mut generated_count = 0
  let mut transformed_count = 0
  let mut validated_count = 0
  let mut i = 0
  while i < case_count {
    let generated = match
      gen_valid_module_result_from_seed(seed ^ i.to_uint64(), config) {
      Ok(v) => v
      Err(e) =>
        return Err("GenValid source failed: \{e.validation_error_message}")
    }
    attempts += generated.attempts
    generated_count += 1
    for transform in transforms {
      match metamorphic_apply_transform(generated.wasm_module, transform) {
        Ok(_) => {
          transformed_count += 1
          validated_count += 1
        }
        Err(msg) => return Err(msg)
      }
    }
    i += 1
  }
  Ok({
    profile,
    attempts,
    generated: generated_count,
    transformed: transformed_count,
    validated: validated_count,
    transform_ids,
  })
}
