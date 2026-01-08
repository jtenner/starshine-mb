using @lib {
  type Env,
  expr_to_texpr,
  expand_locals,
  change,
  unchanged,
  type ModuleTransformer,
  type TransformerResult,
  type TInstr,
  type LocalIdx,
  type ValType,
  type Func,
  type LoadOp,
  type StoreOp,
  type V128LoadLaneOp,
  type MemArg,
  type MemType,
}

using @binary {
  size_signed,
}