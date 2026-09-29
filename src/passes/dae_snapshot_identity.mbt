///|
fn dae_snapshot_module_unchanged(
  left : @lib.Module,
  right : @lib.Module,
) -> Bool {
  // Shared owned code storage proves that its bytes did not change, including
  // NaNs whose numeric Eq is non-reflexive. Check every other field under the
  // encoded identity contract without revisiting those same bodies.
  if physical_equal(left, right) {
    return true
  }
  if !dae_snapshot_code_unchanged(left.code_sec, right.code_sec) {
    return false
  }
  dae_snapshot_non_code_unchanged(left, right)
}

///|
fn dae_snapshot_code_unchanged(
  left : @lib.CodeSec?,
  right : @lib.CodeSec?,
) -> Bool {
  match (left, right) {
    (Some(@lib.CodeSec(lhs)), Some(@lib.CodeSec(rhs))) =>
      dae_snapshot_funcs_unchanged(lhs, rhs)
    (None, None) => true
    _ => false
  }
}

///|
fn dae_snapshot_funcs_unchanged(
  left : Array[@lib.Func],
  right : Array[@lib.Func],
) -> Bool {
  if physical_equal(left, right) {
    return true
  }
  if left.length() != right.length() {
    return false
  }
  for index = 0; index < left.length(); index = index + 1 {
    if !dae_snapshot_func_unchanged(left[index], right[index]) {
      return false
    }
  }
  true
}

///|
fn dae_snapshot_func_unchanged(left : @lib.Func, right : @lib.Func) -> Bool {
  if physical_equal(left, right) {
    return true
  }
  let @lib.Func(left_locals, left_expr) = left
  let @lib.Func(right_locals, right_expr) = right
  (physical_equal(left_locals, right_locals) || left_locals == right_locals) &&
  dae_snapshot_expr_unchanged(left_expr, right_expr)
}

///|
fn dae_snapshot_expr_unchanged(left : @lib.Expr, right : @lib.Expr) -> Bool {
  let @lib.Expr(left_body) = left
  let @lib.Expr(right_body) = right
  dae_snapshot_array_unchanged(
    left_body, right_body, dae_snapshot_instr_unchanged,
  )
}

///|
#inline
fn[T] dae_snapshot_array_unchanged(
  left : Array[T],
  right : Array[T],
  equal : (T, T) -> Bool,
) -> Bool {
  if physical_equal(left, right) {
    return true
  }
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    if !equal(left[i], right[i]) {
      return false
    }
  }
  true
}

///|
#inline
fn[T] dae_snapshot_optional_unchanged(
  left : T?,
  right : T?,
  equal : (T, T) -> Bool,
) -> Bool {
  match (left, right) {
    (Some(left), Some(right)) =>
      physical_equal(left, right) || equal(left, right)
    (None, None) => true
    _ => false
  }
}

///|
fn dae_snapshot_instr_unchanged(
  left : @lib.Instruction,
  right : @lib.Instruction,
) -> Bool {
  if physical_equal(left, right) {
    return true
  }
  match (left, right) {
    (@lib.F32Const(@lib.F32(a)), @lib.F32Const(@lib.F32(b))) =>
      a.reinterpret_as_int() == b.reinterpret_as_int()
    (@lib.F64Const(@lib.F64(a)), @lib.F64Const(@lib.F64(b))) =>
      a.reinterpret_as_int64() == b.reinterpret_as_int64()
    (@lib.Block(a, x), @lib.Block(b, y)) | (@lib.Loop(a, x), @lib.Loop(b, y)) =>
      a == b && dae_snapshot_expr_unchanged(x, y)
    (@lib.If(a, x, tx), @lib.If(b, y, ty)) =>
      a == b &&
      dae_snapshot_array_unchanged(x, y, dae_snapshot_instr_unchanged) &&
      dae_snapshot_optional_unchanged(tx, ty, fn(x, y) {
        dae_snapshot_array_unchanged(x, y, dae_snapshot_instr_unchanged)
      })
    (@lib.TryTable(a, cx, x), @lib.TryTable(b, cy, y)) =>
      a == b && cx == cy && dae_snapshot_expr_unchanged(x, y)
    (@lib.Try(a, x, cx, dx), @lib.Try(b, y, cy, dy)) =>
      a == b &&
      dx == dy &&
      dae_snapshot_expr_unchanged(x, y) &&
      dae_snapshot_array_unchanged(cx, cy, fn(l, r) {
        match (l, r) {
          (
            @lib.LegacyCatch::LegacyCatch(a, x),
            @lib.LegacyCatch::LegacyCatch(b, y),
          ) => a == b && dae_snapshot_expr_unchanged(x, y)
          (
            @lib.LegacyCatch::LegacyCatchAll(x),
            @lib.LegacyCatch::LegacyCatchAll(y),
          ) => dae_snapshot_expr_unchanged(x, y)
          _ => false
        }
      })
    _ => left == right
  }
}

///|
fn dae_snapshot_globals_unchanged(
  left : @lib.GlobalSec,
  right : @lib.GlobalSec,
) -> Bool {
  dae_snapshot_array_unchanged(left.0, right.0, fn(l, r) {
    let @lib.Global(a, x) = l
    let @lib.Global(b, y) = r
    a == b && dae_snapshot_expr_unchanged(x, y)
  })
}

///|
fn dae_snapshot_tables_unchanged(
  left : @lib.TableSec,
  right : @lib.TableSec,
) -> Bool {
  dae_snapshot_array_unchanged(left.0, right.0, fn(l, r) {
    let @lib.Table(a, x) = l
    let @lib.Table(b, y) = r
    a == b && dae_snapshot_optional_unchanged(x, y, dae_snapshot_expr_unchanged)
  })
}

///|
fn dae_snapshot_elements_unchanged(
  left : @lib.ElemSec,
  right : @lib.ElemSec,
) -> Bool {
  dae_snapshot_array_unchanged(left.0, right.0, fn(l, r) {
    let @lib.Elem(lm, lk) = l
    let @lib.Elem(rm, rk) = r
    let mode = match (lm, rm) {
      (@lib.ElemMode::Active(a, x), @lib.ElemMode::Active(b, y)) =>
        a == b && dae_snapshot_expr_unchanged(x, y)
      _ => lm == rm
    }
    mode &&
    (match (lk, rk) {
      (@lib.ElemKind::FuncExprsElemKind(x), @lib.ElemKind::FuncExprsElemKind(y)) =>
        dae_snapshot_array_unchanged(x, y, dae_snapshot_expr_unchanged)
      (
        @lib.ElemKind::TypedExprsElemKind(a, x),
        @lib.ElemKind::TypedExprsElemKind(b, y),
      ) =>
        a == b &&
        dae_snapshot_array_unchanged(x, y, dae_snapshot_expr_unchanged)
      _ => lk == rk
    })
  })
}

///|
fn dae_snapshot_data_unchanged(
  left : @lib.DataSec,
  right : @lib.DataSec,
) -> Bool {
  dae_snapshot_array_unchanged(left.0, right.0, fn(l, r) {
    let @lib.Data(lm, lb) = l
    let @lib.Data(rm, rb) = r
    lb == rb &&
    (match (lm, rm) {
      (@lib.DataMode::Active(a, x), @lib.DataMode::Active(b, y)) =>
        a == b && dae_snapshot_expr_unchanged(x, y)
      _ => lm == rm
    })
  })
}

///|
#inline
fn[T : Eq] dae_snapshot_owned_optional_unchanged(left : T?, right : T?) -> Bool {
  match (left, right) {
    (Some(left), Some(right)) => physical_equal(left, right) || left == right
    (None, None) => true
    _ => false
  }
}

///|
// Keep these fields aligned with Module::equal in src/lib/eq.mbt. Shared owned
// fields prove bit identity, including NaN initializers. Distinct expressions
// compare float bits; other fields retain Module's equality contract, including
// unordered custom-section membership.
fn dae_snapshot_non_code_unchanged(l : @lib.Module, r : @lib.Module) -> Bool {
  let l_custom = l.custom_secs
  let r_custom = r.custom_secs
  if !physical_equal(l_custom, r_custom) {
    if l_custom.length() != r_custom.length() {
      return false
    }
    for lc in l_custom {
      if !r_custom.contains(lc) {
        return false
      }
    }
    for rc in r_custom {
      if !l_custom.contains(rc) {
        return false
      }
    }
  }
  dae_snapshot_owned_optional_unchanged(l.type_sec, r.type_sec) &&
  dae_snapshot_owned_optional_unchanged(l.name_sec, r.name_sec) &&
  dae_snapshot_owned_optional_unchanged(
    l.compiler_fact_custom_section,
    r.compiler_fact_custom_section,
  ) &&
  dae_snapshot_owned_optional_unchanged(l.import_sec, r.import_sec) &&
  dae_snapshot_owned_optional_unchanged(
    l.func_annotation_sec,
    r.func_annotation_sec,
  ) &&
  dae_snapshot_owned_optional_unchanged(l.func_sec, r.func_sec) &&
  dae_snapshot_optional_unchanged(
    l.table_sec,
    r.table_sec,
    dae_snapshot_tables_unchanged,
  ) &&
  dae_snapshot_owned_optional_unchanged(l.mem_sec, r.mem_sec) &&
  dae_snapshot_owned_optional_unchanged(l.tag_sec, r.tag_sec) &&
  dae_snapshot_owned_optional_unchanged(l.stringrefs_sec, r.stringrefs_sec) &&
  dae_snapshot_optional_unchanged(
    l.global_sec,
    r.global_sec,
    dae_snapshot_globals_unchanged,
  ) &&
  dae_snapshot_owned_optional_unchanged(l.export_sec, r.export_sec) &&
  dae_snapshot_owned_optional_unchanged(l.start_sec, r.start_sec) &&
  dae_snapshot_optional_unchanged(
    l.elem_sec,
    r.elem_sec,
    dae_snapshot_elements_unchanged,
  ) &&
  dae_snapshot_owned_optional_unchanged(l.data_cnt_sec, r.data_cnt_sec) &&
  dae_snapshot_optional_unchanged(
    l.data_sec,
    r.data_sec,
    dae_snapshot_data_unchanged,
  )
}
