///|
fn cl_clique_reference(
  interferences : CLCfgSparseInterferences,
  live_members : Array[Int],
) -> Int {
  let mut pair_checks = 0
  for lhs_idx = 0; lhs_idx < live_members.length(); lhs_idx = lhs_idx + 1 {
    for rhs_idx = lhs_idx + 1
        rhs_idx < live_members.length()
        rhs_idx = rhs_idx + 1 {
      pair_checks += 1
      cl_cfg_sparse_add_interference(
        interferences,
        live_members[lhs_idx],
        live_members[rhs_idx],
      )
    }
  }
  pair_checks
}
