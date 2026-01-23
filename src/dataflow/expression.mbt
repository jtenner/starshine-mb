// ============================================================================
// dataflow/expression.mbt - Expression AST
// ============================================================================

/// Unique identifier for expressions
pub struct ExprId(Int) derive(Eq, Hash, Show, Compare)

pub fn ExprId::new(id : Int) -> ExprId {
  ExprId(id)
}

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
} derive(Eq, Show)

pub struct BlockExpr {
  name : String?
  list : Array[ExprId]
  result_type : WasmType
} derive(Eq, Show)

pub fn BlockExpr::new(name : String?, list : Array[ExprId], result_type : WasmType) -> BlockExpr {
  { name, list, result_type }
}

pub struct IfExpr {
  condition : ExprId
  if_true : ExprId
  if_false : ExprId?
  result_type : WasmType
} derive(Eq, Show)

pub fn IfExpr::new(condition : ExprId, if_true : ExprId, if_false : ExprId?, result_type : WasmType) -> IfExpr {
  { condition, if_true, if_false, result_type }
}

pub struct LoopExpr {
  name : String?
  body : ExprId
  result_type : WasmType
} derive(Eq, Show)

pub fn LoopExpr::new(name : String?, body : ExprId, result_type : WasmType) -> LoopExpr {
  { name, body, result_type }
}

pub struct BreakExpr {
  name : String
  value : ExprId?
  condition : ExprId?
} derive(Eq, Show)

pub fn BreakExpr::new(name : String, value : ExprId?, condition : ExprId?) -> BreakExpr {
  { name, value, condition }
}

pub struct SwitchExpr {
  condition : ExprId
  targets : Array[String]
  default : String
} derive(Eq, Show)

pub fn SwitchExpr::new(condition : ExprId, targets : Array[String], default : String) -> SwitchExpr {
  { condition, targets, default }
}

pub struct LocalGetExpr {
  index : Int
} derive(Eq, Show)

pub fn LocalGetExpr::new(index : Int) -> LocalGetExpr {
  { index }
}

pub struct LocalSetExpr {
  index : Int
  value : ExprId
  is_tee : Bool
} derive(Eq, Show)

pub fn LocalSetExpr::new(index : Int, value : ExprId, is_tee : Bool) -> LocalSetExpr {
  { index, value, is_tee }
}

pub struct ConstExpr {
  value : Literal
} derive(Eq, Show)

pub struct UnaryExpr {
  op : UnaryOp
  value : ExprId
  result_type : WasmType
} derive(Eq, Show)

pub fn UnaryExpr::new(op : UnaryOp, value : ExprId, result_type : WasmType) -> UnaryExpr {
  { op, value, result_type }
}

pub struct BinaryExpr {
  op : BinaryOp
  left : ExprId
  right : ExprId
  result_type : WasmType
} derive(Eq, Show)

pub fn BinaryExpr::new(op : BinaryOp, left : ExprId, right : ExprId, result_type : WasmType) -> BinaryExpr {
  { op, left, right, result_type }
}

pub struct SelectExpr {
  if_true : ExprId
  if_false : ExprId
  condition : ExprId
  result_type : WasmType
} derive(Eq, Show)

pub fn SelectExpr::new(if_true : ExprId, if_false : ExprId, condition : ExprId, result_type : WasmType) -> SelectExpr {
  { if_true, if_false, condition, result_type }
}

pub struct DropExpr {
  value : ExprId
} derive(Eq, Show)

pub fn DropExpr::new(value : ExprId) -> DropExpr {
  { value }
}

pub struct CallExpr {
  target : String
  operands : Array[ExprId]
  result_type : WasmType
} derive(Eq, Show)

pub fn CallExpr::new(target : String, operands : Array[ExprId], result_type : WasmType) -> CallExpr {
  { target, operands, result_type }
}

pub struct ReturnExpr {
  value : ExprId?
} derive(Eq, Show)

pub fn ReturnExpr::new(value : ExprId?) -> ReturnExpr {
  { value }
}

pub struct GenericExpr {
  children : Array[ExprId]
  result_type : WasmType
} derive(Eq, Show)

pub fn GenericExpr::new(children : Array[ExprId], result_type : WasmType) -> GenericExpr {
  { children, result_type }
}

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
  }
}

/// Expression storage with ID-based references
pub struct ExpressionStore {
  expressions : Array[Expression]
  types : Array[WasmType]
}

pub fn ExpressionStore::new() -> ExpressionStore {
  { expressions: [], types: [] }
}

pub fn ExpressionStore::add(
  self : ExpressionStore,
  expr : Expression,
  wasm_type : WasmType
) -> ExprId {
  let id = ExprId(self.expressions.length())
  self.expressions.push(expr)
  self.types.push(wasm_type)
  id
}

pub fn ExpressionStore::get(self : ExpressionStore, id : ExprId) -> Expression? {
  let ExprId(idx) = id
  if idx >= 0 && idx < self.expressions.length() {
    Some(self.expressions[idx])
  } else {
    None
  }
}

pub fn ExpressionStore::get_type(
  self : ExpressionStore,
  id : ExprId
) -> WasmType {
  let ExprId(idx) = id
  if idx >= 0 && idx < self.types.length() {
    self.types[idx]
  } else {
    Unreachable
  }
}



pub fn Expression::nop() -> Expression {
  Nop
}
pub fn Expression::block(e : BlockExpr) -> Expression {
  Block(e)
}
pub fn Expression::if_(e : IfExpr) -> Expression {
  If(e)
}
pub fn Expression::loop_(e : LoopExpr) -> Expression {
  Loop(e)
}
pub fn Expression::break_(e : BreakExpr) -> Expression {
  Break(e)
}
pub fn Expression::switch(e : SwitchExpr) -> Expression {
  Switch(e)
}
pub fn Expression::local_get(e : LocalGetExpr) -> Expression {
  LocalGet(e)
}
pub fn Expression::local_set(e : LocalSetExpr) -> Expression {
  LocalSet(e)
}
pub fn Expression::const_(e : ConstExpr) -> Expression {
  Const(e)
}
pub fn Expression::unary(e : UnaryExpr) -> Expression {
  Unary(e)
}
pub fn Expression::binary(e : BinaryExpr) -> Expression {
  Binary(e)
}
pub fn Expression::select(e : SelectExpr) -> Expression {
  Select(e)
}
pub fn Expression::drop(e : DropExpr) -> Expression {
  Drop(e)
}
pub fn Expression::unreachable_() -> Expression {
  Unreachable
}
pub fn Expression::call(e : CallExpr) -> Expression {
  Call(e)
}
pub fn Expression::return_(e : ReturnExpr) -> Expression {
  Return(e)
}
pub fn Expression::generic(e : GenericExpr) -> Expression {
  Generic(e)
}
