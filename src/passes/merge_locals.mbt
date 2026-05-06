///|
pub fn merge_locals_summary() -> String {
  "Retarget copy-shaped local traffic for the O4z merge-locals cleanup slot."
}

///|
fn merge_locals_module_subtypes(mod_ : @lib.Module) -> Array[@lib.SubType] {
  let subtypes : Array[@lib.SubType] = match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => Array::new(capacity=rec_types.length())
    None => []
  }
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          @lib.SingleRecType(subtype) => subtypes.push(subtype)
          @lib.GroupRecType(group) =>
            for subtype in group {
              subtypes.push(subtype)
            }
        }
      }
    None => ()
  }
  subtypes
}

///|
fn merge_locals_params_for_type_idx(
  subtypes : Array[@lib.SubType],
  type_idx : @lib.TypeIdx,
) -> Array[@lib.ValType] {
  let subtype = match type_idx {
    @lib.TypeIdx(type_pos) =>
      match subtypes.get(type_pos.reinterpret_as_int()) {
        Some(subtype) => subtype
        None => abort("merge-locals missing function subtype")
      }
    @lib.RecIdx(_) =>
      abort("merge-locals unsupported recursive function type index")
  }
  match subtype.get_comptype() {
    @lib.FuncCompType(params, _) => params
    _ => abort("merge-locals expected function type")
  }
}

///|
fn merge_locals_flatten_locals(
  locals : @lib.Locals,
  local_count : Int,
) -> Array[@lib.ValType] {
  let out : Array[@lib.ValType] = Array::new(capacity=local_count)
  for run in locals.runs() {
    let ty = run.val_type()
    let run_len = run.count().reinterpret_as_int()
    for _idx = 0; _idx < run_len; _idx = _idx + 1 {
      out.push(ty)
    }
  }
  out
}

///|
fn merge_locals_all_local_types(
  params : Array[@lib.ValType],
  body_locals : @lib.Locals,
) -> Array[@lib.ValType] {
  let body_count = body_locals.length()
  let out : Array[@lib.ValType] = Array::new(
    capacity=params.length() + body_count,
  )
  for param in params {
    out.push(param)
  }
  for body_ty in merge_locals_flatten_locals(body_locals, body_count) {
    out.push(body_ty)
  }
  out
}

///|
fn merge_locals_local_idx_raw(idx : @lib.LocalIdx) -> Int {
  let @lib.LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn merge_locals_local_idx_from_int(idx : Int) -> @lib.LocalIdx {
  @lib.LocalIdx::new(idx.reinterpret_as_uint())
}

///|
fn merge_locals_same_local_type(
  local_types : Array[@lib.ValType],
  lhs : Int,
  rhs : Int,
) -> Bool {
  lhs >= 0 &&
  rhs >= 0 &&
  lhs < local_types.length() &&
  rhs < local_types.length() &&
  local_types[lhs] == local_types[rhs]
}

///|
fn merge_locals_rewrite_expr(
  instrs : Array[@lib.Instruction],
  local_types : Array[@lib.ValType],
) -> Bool {
  let mut changed = false
  let alias_to : Array[Int] = Array::make(local_types.length(), -1)
  let alias_target_epoch : Array[Int] = Array::make(local_types.length(), -1)
  let local_epoch : Array[Int] = Array::make(local_types.length(), 0)
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.Block(ty, @lib.Expr(body)) =>
        if merge_locals_rewrite_expr(body, local_types) {
          instrs[idx] = @lib.Instruction::block(ty, @lib.Expr::new(body))
          changed = true
        }
      @lib.Loop(ty, @lib.Expr(body)) =>
        if merge_locals_rewrite_expr(body, local_types) {
          instrs[idx] = @lib.Instruction::loop_(ty, @lib.Expr::new(body))
          changed = true
        }
      @lib.If(ty, then_body, else_body) => {
        let then_changed = merge_locals_rewrite_expr(then_body, local_types)
        let else_changed = match else_body {
          Some(body) => merge_locals_rewrite_expr(body, local_types)
          None => false
        }
        if then_changed || else_changed {
          instrs[idx] = @lib.Instruction::if_(ty, then_body, else_body)
          changed = true
        }
      }
      @lib.TryTable(ty, catches, @lib.Expr(body)) =>
        if merge_locals_rewrite_expr(body, local_types) {
          instrs[idx] = @lib.Instruction::try_table(
            ty,
            catches,
            @lib.Expr::new(body),
          )
          changed = true
        }
      @lib.LocalGet(local_idx) => {
        let raw = merge_locals_local_idx_raw(local_idx)
        if raw >= 0 && raw < alias_to.length() && alias_to[raw] >= 0 {
          let target = alias_to[raw]
          if target >= 0 &&
            target < local_epoch.length() &&
            alias_target_epoch[raw] == local_epoch[target] {
            instrs[idx] = @lib.Instruction::local_get(
              merge_locals_local_idx_from_int(target),
            )
            changed = true
          } else {
            alias_to[raw] = -1
            alias_target_epoch[raw] = -1
          }
        }
      }
      @lib.LocalSet(local_idx) => {
        let dst = merge_locals_local_idx_raw(local_idx)
        if dst >= 0 && dst < alias_to.length() {
          local_epoch[dst] += 1
          alias_to[dst] = -1
          alias_target_epoch[dst] = -1
          if idx >= 1 {
            match instrs[idx - 1] {
              @lib.LocalGet(source_idx) => {
                let source = merge_locals_local_idx_raw(source_idx)
                if source != dst &&
                  merge_locals_same_local_type(local_types, source, dst) {
                  alias_to[source] = dst
                  alias_target_epoch[source] = local_epoch[dst]
                }
              }
              _ => ()
            }
          }
        }
      }
      @lib.LocalTee(local_idx) => {
        let raw = merge_locals_local_idx_raw(local_idx)
        if raw >= 0 && raw < alias_to.length() {
          local_epoch[raw] += 1
          alias_to[raw] = -1
          alias_target_epoch[raw] = -1
        }
      }
      _ => ()
    }
  }
  changed
}

///|
fn merge_locals_run_func(
  func : @lib.Func,
  params : Array[@lib.ValType],
) -> @lib.Func? {
  match func {
    @lib.Func(locals, @lib.Expr(body)) => {
      let local_types = merge_locals_all_local_types(params, locals)
      if merge_locals_rewrite_expr(body, local_types) {
        Some(@lib.Func::new(locals, @lib.Expr::new(body)))
      } else {
        None
      }
    }
  }
}

///|
pub fn merge_locals_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let code_sec = match mod_.code_sec {
    Some(sec) => sec
    None => return mod_
  }
  let func_types = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs
    None => return mod_
  }
  let @lib.CodeSec(funcs) = code_sec
  if funcs.length() != func_types.length() {
    return mod_
  }
  let subtypes = merge_locals_module_subtypes(mod_)
  let rewritten = funcs.copy()
  let mut changed = false
  for idx = 0; idx < funcs.length(); idx = idx + 1 {
    let params = merge_locals_params_for_type_idx(subtypes, func_types[idx])
    match merge_locals_run_func(funcs[idx], params) {
      Some(func) => {
        rewritten[idx] = func
        changed = true
      }
      None => ()
    }
  }
  if changed {
    mod_.with_code_sec(@lib.CodeSec::new(rewritten))
  } else {
    mod_
  }
}
