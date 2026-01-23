///|
pub fn Module::with_custom_secs(
  self : Module,
  custom_secs : Array[CustomSec],
) -> Module {
  Module::{ ..self, custom_secs, }
}

///|
pub fn Module::with_type_sec(self : Module, type_sec : TypeSec) -> Module {
  Module::{ ..self, type_sec: Some(type_sec) }
}

///|
pub fn Module::with_import_sec(self : Module, import_sec : ImportSec) -> Module {
  Module::{ ..self, import_sec: Some(import_sec) }
}

///|
pub fn Module::with_func_sec(self : Module, func_sec : FuncSec) -> Module {
  Module::{ ..self, func_sec: Some(func_sec) }
}

///|
pub fn Module::with_table_sec(self : Module, table_sec : TableSec) -> Module {
  Module::{ ..self, table_sec: Some(table_sec) }
}

///|
pub fn Module::with_mem_sec(self : Module, mem_sec : MemSec) -> Module {
  Module::{ ..self, mem_sec: Some(mem_sec) }
}

///|
pub fn Module::with_tag_sec(self : Module, tag_sec : TagSec) -> Module {
  Module::{ ..self, tag_sec: Some(tag_sec) }
}

///|
pub fn Module::with_global_sec(self : Module, global_sec : GlobalSec) -> Module {
  Module::{ ..self, global_sec: Some(global_sec) }
}

///|
pub fn Module::with_export_sec(self : Module, export_sec : ExportSec) -> Module {
  Module::{ ..self, export_sec: Some(export_sec) }
}

///|
pub fn Module::with_start_sec(self : Module, start_sec : StartSec) -> Module {
  Module::{ ..self, start_sec: Some(start_sec) }
}

///|
pub fn Module::with_elem_sec(self : Module, elem_sec : ElemSec) -> Module {
  Module::{ ..self, elem_sec: Some(elem_sec) }
}

///|
pub fn Module::with_data_cnt_sec(
  self : Module,
  data_cnt_sec : DataCntSec,
) -> Module {
  Module::{ ..self, data_cnt_sec: Some(data_cnt_sec) }
}

///|
pub fn Module::with_code_sec(self : Module, code_sec : CodeSec) -> Module {
  Module::{ ..self, code_sec: Some(code_sec) }
}

///|
pub fn Module::with_data_sec(self : Module, data_sec : DataSec) -> Module {
  Module::{ ..self, data_sec: Some(data_sec) }
}
