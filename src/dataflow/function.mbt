// ============================================================================
// dataflow/function.mbt - Function representation
// ============================================================================

///|
/// Local variable information
pub struct LocalInfo {
  local_type : WasmType
  is_param : Bool
  name : String?
} derive(Show)

///|
/// Function representation
pub struct Function {
  name : String
  params : Array[WasmType]
  results : Array[WasmType]
  locals : Array[LocalInfo]
  mut body : ExprId?
  expressions : ExpressionStore
} derive(Show)

///|
pub fn Function::new(name : String) -> Function {
  {
    name,
    params: [],
    results: [],
    locals: [],
    body: None,
    expressions: ExpressionStore::new(),
  }
}

pub fn Function::set_body(self : Function, body : ExprId) -> Unit {
  self.body = Some(body)
}

///|
pub fn Function::get_num_locals(self : Function) -> Int {
  self.locals.length()
}

///|
pub fn Function::get_local_type(self : Function, index : Int) -> WasmType {
  if index >= 0 && index < self.locals.length() {
    self.locals[index].local_type
  } else {
    Unreachable
  }
}

///|
pub fn Function::is_param(self : Function, index : Int) -> Bool {
  if index >= 0 && index < self.locals.length() {
    self.locals[index].is_param
  } else {
    false
  }
}

///|
pub fn Function::add_param(self : Function, param_type : WasmType) -> Int {
  let index = self.locals.length()
  self.locals.push({ local_type: param_type, is_param: true, name: None })
  self.params.push(param_type)
  index
}

///|
pub fn Function::add_local(
  self : Function,
  local_type : WasmType,
  name : String?,
) -> Int {
  let index = self.locals.length()
  self.locals.push({ local_type, is_param: false, name })
  index
}

///|
/// Module representation
pub struct Module {
  functions : Map[String, Function]
  name : String?
} derive(Show)

///|
pub fn Module::new() -> Module {
  { functions: {}, name: None }
}

///|
pub fn Module::add_function(self : Module, func : Function) -> Unit {
  self.functions[func.name] = func
}
