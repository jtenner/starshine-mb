///|
fn compiler_facts_safety_module() -> Module {
  Module::new().with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(),
    ),
  )
}

///|
test "index and body section rewrites conservatively drop compiler facts" {
  let module_ = compiler_facts_safety_module()
  @debug.assert_eq(
    module_.with_type_sec(TypeSec::new([])).compiler_fact_custom_section,
    None,
  )
  @debug.assert_eq(
    module_.with_import_sec(ImportSec::new([])).compiler_fact_custom_section,
    None,
  )
  @debug.assert_eq(
    module_.with_func_sec(FuncSec::new([])).compiler_fact_custom_section,
    None,
  )
  @debug.assert_eq(
    module_.with_table_sec(TableSec::new([])).compiler_fact_custom_section,
    None,
  )
  @debug.assert_eq(
    module_.with_mem_sec(MemSec::new([])).compiler_fact_custom_section,
    None,
  )
  @debug.assert_eq(
    module_.with_global_sec(GlobalSec::new([])).compiler_fact_custom_section,
    None,
  )
  @debug.assert_eq(
    module_.with_code_sec(CodeSec::new([])).compiler_fact_custom_section,
    None,
  )
  @debug.assert_eq(
    module_.with_stringrefs_sec(StringRefsSec::new([])).compiler_fact_custom_section,
    None,
  )
}

///|
test "unrelated module metadata rewrites preserve compiler facts" {
  let module_ = compiler_facts_safety_module()
  assert_true(
    module_.with_custom_secs([]).compiler_fact_custom_section is Some(_),
  )
  assert_true(
    module_.with_name_sec(NameSec::new()).compiler_fact_custom_section
    is Some(_),
  )
  assert_true(
    module_.with_export_sec(ExportSec::new([])).compiler_fact_custom_section
    is Some(_),
  )
}
