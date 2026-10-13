// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Conservative attribution from pinned Binaryen version_130 counterpart:
// Copyright 2016 WebAssembly Community Group participants
// Counterpart: src/passes/RemoveUnusedModuleElements.cpp (5d704ad5); origin remains unconfirmed.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

///|
pub fn rume_summary() -> String {
  @rume.rume_summary()
}

///|
pub fn rume_nonfunction_summary() -> String {
  @rume.rume_nonfunction_summary()
}

///|
fn rume_imported_global_count(mod_ : @lib.Module) -> Int {
  @rume.rume_imported_global_count(mod_)
}

///|
fn rume_rewrite_instruction(
  instr : @lib.Instruction,
  func_remap : Array[Int],
  global_remap : Array[Int],
  table_remap : Array[Int],
  mem_remap : Array[Int],
  tag_remap : Array[Int],
  elem_remap : Array[Int],
  data_remap : Array[Int],
) -> @lib.Instruction {
  @rume.rume_rewrite_instruction(
    instr, func_remap, global_remap, table_remap, mem_remap, tag_remap, elem_remap,
    data_remap,
  )
}

///|
pub fn rume_extract_functions(
  mod_ : @lib.Module,
  roots : Array[@lib.FuncIdx],
) -> Result[@lib.Module, String] {
  @rume.rume_extract_functions(mod_, roots)
}

///|
pub fn rume_run_module_pass(
  mod_ : @lib.Module,
  traps_never_happen? : Bool = false,
  closed_world? : Bool = false,
) -> @lib.Module {
  @rume.rume_run_module_pass(mod_, traps_never_happen~, closed_world~)
}

///|
pub fn rume_run_nonfunction_module_pass(
  mod_ : @lib.Module,
  traps_never_happen? : Bool = false,
  closed_world? : Bool = false,
) -> @lib.Module {
  @rume.rume_run_nonfunction_module_pass(
    mod_,
    traps_never_happen~,
    closed_world~,
  )
}

///|
/// Apply the application's exact export roots as the final mutating transform.
/// Preserve exposed function names/identity relative to this input module.
pub fn rume_run_host_roots_module_pass(
  mod_ : @lib.Module,
  roots : Array[String],
) -> Result[@lib.Module, String] {
  @rume.rume_run_host_roots_module_pass(mod_, roots)
}
