// ============================================================================
// dataflow/expression.mbt - Expression AST
// ============================================================================

///|
/// Unique identifier for expressions
pub struct ExprId(Int) derive(Eq, Hash, Show, Compare)

///|
pub fn ExprId::new(id : Int) -> ExprId {
  ExprId(id)
}

///|
/// Memory load operations
pub enum LoadOp {
  // i32 loads
  LoadI32
  Load8SI32 // sign-extend i8 to i32
  Load8UI32 // zero-extend i8 to i32
  Load16SI32 // sign-extend i16 to i32
  Load16UI32 // zero-extend i16 to i32
  // i64 loads
  LoadI64
  Load8SI64
  Load8UI64
  Load16SI64
  Load16UI64
  Load32SI64
  Load32UI64
  // float loads
  LoadF32
  LoadF64
} derive(Eq, Show)

///|
pub fn LoadOp::load_i32() -> LoadOp {
  LoadI32
}

///|
pub fn LoadOp::load8si32() -> LoadOp {
  Load8SI32
}

///|
pub fn LoadOp::load8ui32() -> LoadOp {
  Load8UI32
}

///|
pub fn LoadOp::load16si32() -> LoadOp {
  Load16SI32
}

///|
pub fn LoadOp::load16ui32() -> LoadOp {
  Load16UI32
}

///|
pub fn LoadOp::load_i64() -> LoadOp {
  LoadI64
}

///|
pub fn LoadOp::load8si64() -> LoadOp {
  Load8SI64
}

///|
pub fn LoadOp::load8ui64() -> LoadOp {
  Load8UI64
}

///|
pub fn LoadOp::load16si64() -> LoadOp {
  Load16SI64
}

///|
pub fn LoadOp::load16ui64() -> LoadOp {
  Load16UI64
}

///|
pub fn LoadOp::load32si64() -> LoadOp {
  Load32SI64
}

///|
pub fn LoadOp::load32ui64() -> LoadOp {
  Load32UI64
}

///|
pub fn LoadOp::load_f32() -> LoadOp {
  LoadF32
}

///|
pub fn LoadOp::load_f64() -> LoadOp {
  LoadF64
}

///|
/// Memory store operations
pub enum StoreOp {
  // i32 stores
  StoreI32
  Store8I32 // truncate i32 to i8
  Store16I32 // truncate i32 to i16
  // i64 stores
  StoreI64
  Store8I64
  Store16I64
  Store32I64
  // float stores
  StoreF32
  StoreF64
} derive(Eq, Show)

///|
pub fn StoreOp::store_i32() -> StoreOp {
  StoreI32
}

///|
pub fn StoreOp::store8_i32() -> StoreOp {
  Store8I32
}

///|
pub fn StoreOp::store16_i32() -> StoreOp {
  Store16I32
}

///|
pub fn StoreOp::store_i64() -> StoreOp {
  StoreI64
}

///|
pub fn StoreOp::store_8i64() -> StoreOp {
  Store8I64
}

///|
pub fn StoreOp::store16_i64() -> StoreOp {
  Store16I64
}

///|
pub fn StoreOp::store32_i64() -> StoreOp {
  Store32I64
}

///|
pub fn StoreOp::store_f32() -> StoreOp {
  StoreF32
}

///|
pub fn StoreOp::store_f64() -> StoreOp {
  StoreF64
}

///|
pub struct LoadExpr {
  op : LoadOp
  ptr : ExprId
  offset : Int // static offset added to ptr
  align : Int // alignment (power of 2)
  result_type : WasmType
} derive(Eq, Show)

///|
pub fn LoadExpr::new(
  op : LoadOp,
  ptr : ExprId,
  offset : Int,
  align : Int,
  result_type : WasmType,
) -> LoadExpr {
  { op, ptr, offset, align, result_type }
}

///|
pub struct StoreExpr {
  op : StoreOp
  ptr : ExprId
  value : ExprId
  offset : Int
  align : Int
} derive(Eq, Show)

///|
pub fn StoreExpr::new(
  op : StoreOp,
  ptr : ExprId,
  value : ExprId,
  offset : Int,
  align : Int,
) -> StoreExpr {
  { op, ptr, value, offset, align }
}

///|
pub struct MemorySizeExpr {
  memory_index : Int // usually 0 for single-memory modules
} derive(Eq, Show)

///|
pub fn MemorySizeExpr::new(memory_index : Int) -> MemorySizeExpr {
  { memory_index, }
}

///|
pub struct MemoryGrowExpr {
  memory_index : Int
  delta : ExprId // number of pages to grow
} derive(Eq, Show)

///|
pub fn MemoryGrowExpr::new(
  memory_index : Int,
  delta : ExprId,
) -> MemoryGrowExpr {
  { memory_index, delta }
}

///|
/// Expression types in the Wasm IR
pub enum Expression {
  Nop
  Block(BlockExpr)
  If(IfExpr)
  Loop(LoopExpr)
  Break(BreakExpr)
  Switch(SwitchExpr)
  LocalGet(LocalGetExpr)
  LocalSet(LocalSetExpr)
  Const(ConstExpr)
  Unary(UnaryExpr)
  Binary(BinaryExpr)
  Select(SelectExpr)
  Drop(DropExpr)
  Unreachable
  Call(CallExpr)
  Return(ReturnExpr)
  Generic(GenericExpr)
  // Memory operations
  Load(LoadExpr)
  Store(StoreExpr)
  MemorySize(MemorySizeExpr)
  MemoryGrow(MemoryGrowExpr)
} derive(Eq, Show)

///|
pub struct BlockExpr {
  name : String?
  list : Array[ExprId]
  result_type : WasmType
} derive(Eq, Show)

///|
pub fn BlockExpr::new(
  name : String?,
  list : Array[ExprId],
  result_type : WasmType,
) -> BlockExpr {
  { name, list, result_type }
}

///|
pub struct IfExpr {
  condition : ExprId
  if_true : ExprId
  if_false : ExprId?
  result_type : WasmType
} derive(Eq, Show)

///|
pub fn IfExpr::new(
  condition : ExprId,
  if_true : ExprId,
  if_false : ExprId?,
  result_type : WasmType,
) -> IfExpr {
  { condition, if_true, if_false, result_type }
}

///|
pub struct LoopExpr {
  name : String?
  body : ExprId
  result_type : WasmType
} derive(Eq, Show)

///|
pub fn LoopExpr::new(
  name : String?,
  body : ExprId,
  result_type : WasmType,
) -> LoopExpr {
  { name, body, result_type }
}

///|
pub struct BreakExpr {
  name : String
  value : ExprId?
  condition : ExprId?
} derive(Eq, Show)

///|
pub fn BreakExpr::new(
  name : String,
  value : ExprId?,
  condition : ExprId?,
) -> BreakExpr {
  { name, value, condition }
}

///|
pub struct SwitchExpr {
  condition : ExprId
  targets : Array[String]
  default : String
} derive(Eq, Show)

///|
pub fn SwitchExpr::new(
  condition : ExprId,
  targets : Array[String],
  default : String,
) -> SwitchExpr {
  { condition, targets, default }
}

///|
pub struct LocalGetExpr {
  index : Int
} derive(Eq, Show)

///|
pub fn LocalGetExpr::new(index : Int) -> LocalGetExpr {
  { index, }
}

///|
pub struct LocalSetExpr {
  index : Int
  value : ExprId
  is_tee : Bool
} derive(Eq, Show)

///|
pub fn LocalSetExpr::new(
  index : Int,
  value : ExprId,
  is_tee : Bool,
) -> LocalSetExpr {
  { index, value, is_tee }
}

///|
pub struct ConstExpr {
  value : Literal
} derive(Eq, Show)

pub fn ConstExpr::new(value : Literal) -> ConstExpr {
  ConstExpr::{ value }
}

///|
pub struct UnaryExpr {
  op : UnaryOp
  value : ExprId
  result_type : WasmType
} derive(Eq, Show)

///|
pub fn UnaryExpr::new(
  op : UnaryOp,
  value : ExprId,
  result_type : WasmType,
) -> UnaryExpr {
  { op, value, result_type }
}

///|
pub struct BinaryExpr {
  op : BinaryOp
  left : ExprId
  right : ExprId
  result_type : WasmType
} derive(Eq, Show)

///|
pub fn BinaryExpr::new(
  op : BinaryOp,
  left : ExprId,
  right : ExprId,
  result_type : WasmType,
) -> BinaryExpr {
  { op, left, right, result_type }
}

///|
pub struct SelectExpr {
  if_true : ExprId
  if_false : ExprId
  condition : ExprId
  result_type : WasmType
} derive(Eq, Show)

///|
pub fn SelectExpr::new(
  if_true : ExprId,
  if_false : ExprId,
  condition : ExprId,
  result_type : WasmType,
) -> SelectExpr {
  { if_true, if_false, condition, result_type }
}

///|
pub struct DropExpr {
  value : ExprId
} derive(Eq, Show)

///|
pub fn DropExpr::new(value : ExprId) -> DropExpr {
  { value, }
}

///|
pub struct CallExpr {
  target : String
  operands : Array[ExprId]
  result_type : WasmType
} derive(Eq, Show)

///|
pub fn CallExpr::new(
  target : String,
  operands : Array[ExprId],
  result_type : WasmType,
) -> CallExpr {
  { target, operands, result_type }
}

///|
pub struct ReturnExpr {
  value : ExprId?
} derive(Eq, Show)

///|
pub fn ReturnExpr::new(value : ExprId?) -> ReturnExpr {
  { value, }
}

///|
pub struct GenericExpr {
  children : Array[ExprId]
  result_type : WasmType
} derive(Eq, Show)

///|
pub fn GenericExpr::new(
  children : Array[ExprId],
  result_type : WasmType,
) -> GenericExpr {
  { children, result_type }
}

///|
pub fn Expression::get_type(self : Expression) -> WasmType {
  match self {
    Nop => None
    Block(b) => b.result_type
    If(i) => i.result_type
    Loop(l) => l.result_type
    Break(_) => Unreachable
    Switch(_) => Unreachable
    LocalGet(_) => None // Resolved during processing
    LocalSet(s) => if s.is_tee { None } else { None }
    Const(c) => c.value.get_type()
    Unary(u) => u.result_type
    Binary(b) => b.result_type
    Select(s) => s.result_type
    Drop(_) => None
    Unreachable => WasmType::Unreachable
    Call(c) => c.result_type
    Return(_) => WasmType::Unreachable
    Generic(g) => g.result_type
    Load(l) => l.result_type
    Store(_) => None
    MemorySize(_) => I32
    MemoryGrow(_) => I32
  }
}

///|
/// Expression storage with ID-based references
pub struct ExpressionStore {
  expressions : Array[Expression]
  types : Array[WasmType]
}

///|
pub fn ExpressionStore::new() -> ExpressionStore {
  { expressions: [], types: [] }
}

///|
pub fn ExpressionStore::add(
  self : ExpressionStore,
  expr : Expression,
  wasm_type : WasmType,
) -> ExprId {
  let id = ExprId(self.expressions.length())
  self.expressions.push(expr)
  self.types.push(wasm_type)
  id
}

///|
pub fn ExpressionStore::get(self : ExpressionStore, id : ExprId) -> Expression? {
  let ExprId(idx) = id
  if idx >= 0 && idx < self.expressions.length() {
    Some(self.expressions[idx])
  } else {
    None
  }
}

///|
pub fn ExpressionStore::get_type(
  self : ExpressionStore,
  id : ExprId,
) -> WasmType {
  let ExprId(idx) = id
  if idx >= 0 && idx < self.types.length() {
    self.types[idx]
  } else {
    Unreachable
  }
}

///|
pub fn Expression::nop() -> Expression {
  Nop
}

///|
pub fn Expression::block(e : BlockExpr) -> Expression {
  Block(e)
}

///|
pub fn Expression::if_(e : IfExpr) -> Expression {
  If(e)
}

///|
pub fn Expression::loop_(e : LoopExpr) -> Expression {
  Loop(e)
}

///|
pub fn Expression::break_(e : BreakExpr) -> Expression {
  Break(e)
}

///|
pub fn Expression::switch(e : SwitchExpr) -> Expression {
  Switch(e)
}

///|
pub fn Expression::local_get(e : LocalGetExpr) -> Expression {
  LocalGet(e)
}

///|
pub fn Expression::local_set(e : LocalSetExpr) -> Expression {
  LocalSet(e)
}

///|
pub fn Expression::const_(e : ConstExpr) -> Expression {
  Const(e)
}

///|
pub fn Expression::unary(e : UnaryExpr) -> Expression {
  Unary(e)
}

///|
pub fn Expression::binary(e : BinaryExpr) -> Expression {
  Binary(e)
}

///|
pub fn Expression::select(e : SelectExpr) -> Expression {
  Select(e)
}

///|
pub fn Expression::drop(e : DropExpr) -> Expression {
  Drop(e)
}

///|
pub fn Expression::unreachable_() -> Expression {
  Unreachable
}

///|
pub fn Expression::call(e : CallExpr) -> Expression {
  Call(e)
}

///|
pub fn Expression::return_(e : ReturnExpr) -> Expression {
  Return(e)
}

///|
pub fn Expression::generic(e : GenericExpr) -> Expression {
  Generic(e)
}

///|
pub fn Expression::load(arg : LoadExpr) -> Expression {
  Load(arg)
}

///|
pub fn Expression::store(arg : StoreExpr) -> Expression {
  Store(arg)
}

///|
pub fn Expression::memory_size(arg : MemorySizeExpr) -> Expression {
  MemorySize(arg)
}

///|
pub fn Expression::memory_grow(arg : MemoryGrowExpr) -> Expression {
  MemoryGrow(arg)
}
