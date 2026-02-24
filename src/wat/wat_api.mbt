///|
pub fn lookup_keyword(text : String) -> TokenType? {
  @wast.lookup_keyword(text)
}

///|
pub fn wat_to_module(
  source : String,
  filename? : String = "<input>",
) -> Result[Module, String] {
  @wast.wast_to_module(source, filename~)
}

///|
pub fn module_to_wat(mod : Module) -> Result[String, String] {
  @wast.module_to_wast(mod)
}

///|
pub fn module_to_wat_with_context(
  mod : Module,
  ctx : PrettyPrintContext,
) -> Result[String, String] {
  @wast.module_to_wast_with_context(mod, ctx)
}

///|
pub fn wat_to_script(
  source : String,
  filename? : String = "<input>",
) -> Result[WastScript, String] {
  @wast.wast_to_script(source, filename~)
}

///|
pub fn script_to_wat(script : WastScript) -> Result[String, String] {
  @wast.script_to_wast(script)
}

///|
pub fn script_to_wat_with_context(
  script : WastScript,
  ctx : PrettyPrintContext,
) -> Result[String, String] {
  @wast.script_to_wast_with_context(script, ctx)
}
