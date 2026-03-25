///|
fn hot_intern_type(func : HotFunc, info : HotTypeInfo) -> TypeId {
  let key = info.to_string()
  match func.type_ids.get(key) {
    Some(id) => id
    None => {
      let id = func.types.length()
      func.types.push(info)
      func.type_ids.set(key, id)
      id
    }
  }
}

///|
pub fn hot_type_intern_void(func : HotFunc) -> TypeId {
  hot_intern_type(func, HotTypeInfo::VoidType)
}

///|
pub fn hot_type_intern_value(func : HotFunc, val_type : ValType) -> TypeId {
  hot_intern_type(func, HotTypeInfo::Value(val_type))
}

///|
pub fn hot_type_intern_block_result(
  func : HotFunc,
  block_type : BlockType,
) -> TypeId {
  hot_intern_type(func, HotTypeInfo::BlockResult(block_type))
}

///|
pub fn hot_type_intern_resolved_block_result(
  func : HotFunc,
  block_type : BlockType,
  results : Array[ValType],
) -> TypeId {
  hot_intern_type(func, HotTypeInfo::BlockResultResolved(block_type, results))
}

///|
pub fn hot_type_intern_results(
  func : HotFunc,
  result_types : Array[ValType],
) -> TypeId {
  hot_intern_type(func, HotTypeInfo::Results(result_types))
}

///|
pub fn hot_type_void(func : HotFunc) -> TypeId {
  hot_type_intern_void(func)
}

///|
pub fn hot_type_get(func : HotFunc, type_id : TypeId) -> HotTypeInfo {
  func.types[type_id]
}

///|
fn hot_type_block_result_values(block_type : BlockType) -> Array[ValType] {
  match block_type {
    VoidBlockType => []
    ValTypeBlockType(val_type) => [val_type]
    TypeIdxBlockType(_) =>
      abort(
        "type-index block types are not supported by the current hot type queries",
      )
  }
}

///|
pub fn hot_type_result_arity(func : HotFunc, type_id : TypeId) -> Int {
  hot_type_results(func, type_id).length()
}

///|
pub fn hot_type_is_void(func : HotFunc, type_id : TypeId) -> Bool {
  match hot_type_get(func, type_id) {
    VoidType => true
    _ => false
  }
}

///|
pub fn hot_type_results(func : HotFunc, type_id : TypeId) -> Array[ValType] {
  match hot_type_get(func, type_id) {
    VoidType => []
    BlockResult(block_type) => hot_type_block_result_values(block_type)
    BlockResultResolved(_, values) => values.copy()
    Value(val_type) => [val_type]
    Results(values) => values.copy()
  }
}

///|
pub fn hot_param_count(func : HotFunc) -> Int {
  func.locals.param_count
}

///|
pub fn hot_local_count(func : HotFunc) -> Int {
  hot_param_count(func) + func.locals.locals.length()
}

///|
pub fn hot_local_type(func : HotFunc, local_id : Int) -> ValType? {
  if local_id < 0 {
    return None
  }
  if local_id < func.locals.params.length() {
    return Some(func.locals.params[local_id])
  }
  let body_local_id = local_id - hot_param_count(func)
  if body_local_id < 0 || body_local_id >= func.locals.locals.length() {
    None
  } else {
    Some(func.locals.locals[body_local_id])
  }
}
