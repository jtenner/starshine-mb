///|
fn pretty_from_show(value : &Show, ctx : PrettyPrintContext) -> String {
  apply_pretty_context(value.to_string(), ctx)
}

///|
pub impl PrettyPrint for Module with pretty_print(self, ctx) {
  match module_to_wast_with_context(self, ctx) {
    Ok(text) => text
    Err(msg) => "(module ;; \{msg})"
  }
}

///|
pub impl PrettyPrint for WastScript with pretty_print(self, ctx) {
  match script_to_wast_with_context(self, ctx) {
    Ok(text) => text
    Err(msg) => ";; \{msg}"
  }
}

///|
pub impl PrettyPrint for Index with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Limits with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for FuncType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TypeUse with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for InlineExport with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ImportDesc with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Import with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ExportDesc with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Export with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TableType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for MemoryType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for GlobalType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Local with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Func with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Global with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Table with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Memory with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TypeDef with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DataSegment with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ElemSegment with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Start with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ModuleField with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for MemArg with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for BlockType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for V128Const with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for SimdShape with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ShuffleLanes with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Instruction with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for WastValue with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for WastResult with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for WastAction with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for WastActionType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for WastCommand with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for WastModuleDef with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ParseError with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ParserError with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for LiteralType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ErrorLevel with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Location with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Literal with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Token with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for LexerError with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ValueType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Opcode with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TokenType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TokenValue with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}
