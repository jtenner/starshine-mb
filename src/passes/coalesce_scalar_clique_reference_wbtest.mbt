///|
// Frozen1c8485122 worker, including sparse and existing dense-word guards.
fn cl_scalar_clique_original(
  interferences : CLCfgSparseInterferences,
  live_members : Array[Int],
) -> Int {
  // Sparse small sets avoid allocating a mask. Larger cliques update each
  // valid row a word at a time; source membership order does not affect bits.
  if live_members.length() >= 16 {
    let size = interferences.rows.length()
    let mask = @bitset.BitSet::new(size)
    let words : Array[Int] = []
    for member in live_members {
      if member >= 0 && member < size {
        let word = member / 64
        if mask.words[word] == 0UL {
          words.push(word)
        }
        mask[member] = true
      }
    }
    for member in live_members {
      if member >= 0 && member < size {
        let row = interferences.rows[member]
        for word in words {
          row.words[word] = row.words[word] | mask.words[word]
        }
        row[member] = false
      }
    }
    return 0
  }
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
