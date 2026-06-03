///|
fn pretty_from_show(value : &Show, ctx : PrettyPrintContext) -> String {
  apply_pretty_context(value.to_string(), ctx)
}

///|
pub impl PrettyPrint for Module with fn pretty_print(self, ctx) {
  match module_to_wast_with_context(self, ctx) {
    Ok(text) => text
    Err(msg) => "(module ;; \{msg})"
  }
}

///|
pub impl PrettyPrint for WastScript with fn pretty_print(self, ctx) {
  match script_to_wast_with_context(self, ctx) {
    Ok(text) => text
    Err(msg) => ";; \{msg}"
  }
}

///|
pub impl PrettyPrint for Index with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Limits with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for FuncType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TypeUse with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for InlineExport with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ImportDesc with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Import with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ExportDesc with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Export with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TableType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for MemoryType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for GlobalType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Local with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Func with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Global with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Table with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Memory with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TypeDef with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DataSegment with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ElemSegment with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Start with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ModuleField with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for MemArg with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for BlockType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for V128Const with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for SimdShape with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ShuffleLanes with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Instruction with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for WastValue with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for WastResult with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for WastAction with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for WastActionType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for WastCommand with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for WastModuleDef with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ParseError with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ParserError with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for LiteralType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ErrorLevel with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Location with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Literal with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Token with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for LexerError with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ValueType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Opcode with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TokenType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TokenValue with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}
