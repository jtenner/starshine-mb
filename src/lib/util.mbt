///|
pub fn expand_locals(decls : Array[Locals]) -> Result[Array[ValType], String] {
  let out : Array[ValType] = []
  for d in decls {
    let Locals(n, vt) = d
    let count = n.reinterpret_as_int()
    if count < 0 {
      return Err("locals: negative count")
    }
    for _ in 0..<count {
      out.push(vt)
    }
  }
  Ok(out)
}

///|
pub struct FunctionLocals {
  params : Array[ValType]
  body_locals : Array[ValType]
  all_locals : Array[ValType]
} derive(Eq, Hash, Debug)

///|
pub fn FunctionLocals::new(
  params : Array[ValType],
  body_locals : Array[ValType],
) -> FunctionLocals {
  let all_locals = params.copy()
  for vt in body_locals {
    all_locals.push(vt)
  }
  { params: params.copy(), body_locals: body_locals.copy(), all_locals }
}

///|
pub fn FunctionLocals::from_typed_func(
  declared_params : Array[ValType],
  typed_params : Array[ValType],
  typed_body_locals : Array[ValType],
) -> Result[FunctionLocals, String] {
  if typed_params != declared_params {
    return Err("typed function params must match declared signature exactly")
  }
  Ok(FunctionLocals::new(typed_params, typed_body_locals))
}

///|
pub fn FunctionLocals::from_typed_func_for_pass(
  declared_params : Array[ValType],
  typed_params : Array[ValType],
  typed_body_locals : Array[ValType],
) -> Result[FunctionLocals, String] {
  let params = if typed_params.is_empty() {
    declared_params
  } else {
    typed_params
  }
  Ok(FunctionLocals::new(params, typed_body_locals))
}

///|
pub fn FunctionLocals::from_local_decls(
  params : Array[ValType],
  local_decls : Array[Locals],
) -> Result[FunctionLocals, String] {
  let body_locals = match expand_locals(local_decls) {
    Ok(locals) => locals
    Err(e) => return Err(e)
  }
  for vt in body_locals {
    if !has_default(vt) {
      return Err("local type has no default value")
    }
  }
  Ok(FunctionLocals::new(params, body_locals))
}

///|
pub fn FunctionLocals::params(self : FunctionLocals) -> Array[ValType] {
  self.params.copy()
}

///|
pub fn FunctionLocals::body_locals(self : FunctionLocals) -> Array[ValType] {
  self.body_locals.copy()
}

///|
pub fn FunctionLocals::all_locals(self : FunctionLocals) -> Array[ValType] {
  self.all_locals.copy()
}

///|
pub fn FunctionLocals::param_count(self : FunctionLocals) -> Int {
  self.params.length()
}

///|
pub fn FunctionLocals::local_type(
  self : FunctionLocals,
  idx : LocalIdx,
) -> ValType? {
  let LocalIdx(raw) = idx
  self.all_locals.get(raw.reinterpret_as_int())
}
