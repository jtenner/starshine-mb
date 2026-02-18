///|
fn pretty_from_show(value : &Show, ctx : PrettyPrintContext) -> String {
  apply_pretty_context(value.to_string(), ctx)
}

///|
pub impl PrettyPrint for AbsHeapType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for BinaryOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for BlockType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for CastOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Catch with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for CodeSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for CompType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for CustomSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Data with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DataCntSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DataIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DataMode with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DataSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DefType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Elem with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ElemIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ElemKind with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ElemMode with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ElemSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Export with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ExportSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Expr with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ExternIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ExternType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ExtractLaneOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for F32 with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for F64 with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for FieldType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Func with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for FuncIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for FuncSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for FuncType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Global with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for GlobalIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for GlobalSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for GlobalType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for HeapType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for I32 with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for I64 with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Import with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ImportSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Instruction with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for LabelIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for LaneIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Limits with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for LoadOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for LocalIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Locals with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for MemArg with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for MemIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for MemSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for MemType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Module with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Mut with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Name with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for NumType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for PackType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for RecType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for RefType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ReplaceLaneOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for S33 with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for StartSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for StorageType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for StoreOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for SubType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TExpr with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TInstr with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Table with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TableIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TableSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TableType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TagIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TagSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TagType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TypeIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TypeSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for U32 with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for U64 with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for UnaryOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for V128LoadLaneOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for V128ShiftOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for V128StoreLaneOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for V128TernaryOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ValType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}
