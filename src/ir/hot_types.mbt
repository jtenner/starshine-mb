///|
fn hot_intern_type(
  func : HotFunc,
  info : HotTypeInfo,
  key_formats? : Array[Int]? = None,
) -> TypeId {
  // Common functions have only a few result shapes. Structural comparison
  // avoids allocating a rendered key on repeated tuple/control queries.
  // Keep the existing indexed lookup for larger heterogeneous type tables.
  if func.types.length() <= 16 {
    for id = 0; id < func.types.length(); id = id + 1 {
      if func.types[id] == info {
        return id
      }
    }
  }
  if key_formats is Some(count) {
    count[0] += 1
  }
  let key = info.to_string()
  match func.type_ids.get(key) {
    Some(id) => id
    None => {
      let id = func.types.length()
      // Caller rows can be scratch or mutable module metadata. Own them only
      // on an intern miss; repeated type queries must not copy another row.
      let owned = match info {
        HotTypeInfo::Results(values) => HotTypeInfo::Results(values.copy())
        HotTypeInfo::BlockResultResolved(block_type, params, results) =>
          HotTypeInfo::BlockResultResolved(
            block_type,
            params.copy(),
            results.copy(),
          )
        _ => info
      }
      func.types.push(owned)
      func.type_ids.set(key, id)
      id
    }
  }
}

///|
pub fn hot_type_intern_void(_func : HotFunc) -> TypeId {
  0
}

///|
pub fn hot_type_intern_value(func : HotFunc, val_type : ValType) -> TypeId {
  for idx = 0; idx < func.value_types.length(); idx = idx + 1 {
    if func.value_types[idx] == val_type {
      return func.value_type_ids[idx]
    }
  }
  let info = HotTypeInfo::Value(val_type)
  let id = func.types.length()
  func.types.push(info)
  func.type_ids.set(info.to_string(), id)
  func.value_types.push(val_type)
  func.value_type_ids.push(id)
  id
}

///|
pub fn hot_type_intern_block_result(
  func : HotFunc,
  block_type : BlockType,
) -> TypeId {
  for idx = 0; idx < func.block_types.length(); idx = idx + 1 {
    if func.block_types[idx] == block_type {
      return func.block_type_ids[idx]
    }
  }
  let info = HotTypeInfo::BlockResult(block_type)
  let id = func.types.length()
  func.types.push(info)
  func.type_ids.set(info.to_string(), id)
  func.block_types.push(block_type)
  func.block_type_ids.push(id)
  id
}

///|
pub fn hot_type_intern_resolved_block_result(
  func : HotFunc,
  block_type : BlockType,
  params : Array[ValType],
  results : Array[ValType],
) -> TypeId {
  hot_intern_type(
    func,
    HotTypeInfo::BlockResultResolved(block_type, params, results),
  )
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
  hot_type_result_arity_impl(func, type_id, None)
}

///|
#inline
fn hot_type_result_arity_impl(
  func : HotFunc,
  type_id : TypeId,
  copied_values : Array[Int]?,
) -> Int {
  // Counting results does not require the owned arrays returned by
  // hot_type_results. Keep its unresolved-block error behavior unchanged.
  ignore(copied_values)
  match hot_type_get(func, type_id) {
    VoidType => 0
    Value(_) => 1
    BlockResult(block_type) =>
      match block_type {
        VoidBlockType => 0
        ValTypeBlockType(_) => 1
        TypeIdxBlockType(_) =>
          abort(
            "type-index block types are not supported by the current hot type queries",
          )
      }
    BlockResultResolved(_, _, values) | Results(values) => values.length()
  }
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
    BlockResultResolved(_, _, values) => values.copy()
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
