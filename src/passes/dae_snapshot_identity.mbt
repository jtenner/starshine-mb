///|
fn dae_snapshot_module_unchanged(
  left : @lib.Module,
  right : @lib.Module,
) -> Bool {
  // Snapshot identity proves no replacement occurred, including for NaNs whose
  // numeric Eq is non-reflexive. Distinct snapshots retain structural checks.
  physical_equal(left, right) || left == right
}

///|
fn dae_snapshot_func_unchanged(left : @lib.Func, right : @lib.Func) -> Bool {
  if physical_equal(left, right) {
    return true
  }
  let @lib.Func(left_locals, left_expr) = left
  let @lib.Func(right_locals, right_expr) = right
  left_locals == right_locals &&
  dae_snapshot_expr_unchanged(left_expr, right_expr)
}

///|
fn dae_snapshot_expr_unchanged(left : @lib.Expr, right : @lib.Expr) -> Bool {
  let @lib.Expr(left_body) = left
  let @lib.Expr(right_body) = right
  physical_equal(left_body, right_body) || left == right
}
