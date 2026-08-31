///|
test "Module compiler facts field defaults to none and constructor preserves it" {
  let empty = Module::new()
  @debug.assert_eq(empty.compiler_fact_custom_section, None)
  let facts = @representation.CompilerFactCustomSection::new(
    @representation.OptimizationFactsSec::new(),
  )
  let populated = Module::new(compiler_fact_custom_section=Some(facts))
  @debug.assert_eq(populated.compiler_fact_custom_section, Some(facts))
}

///|
test "Module compiler facts helpers replace and remove explicit metadata" {
  let facts = @representation.CompilerFactCustomSection::new(
    @representation.OptimizationFactsSec::new(),
    module_fingerprint=Some(b"opaque"),
  )
  let populated = Module::new().with_compiler_fact_custom_section(facts)
  @debug.assert_eq(populated.compiler_fact_custom_section, Some(facts))
  @debug.assert_eq(
    populated.without_compiler_fact_custom_section().compiler_fact_custom_section,
    None,
  )
}
