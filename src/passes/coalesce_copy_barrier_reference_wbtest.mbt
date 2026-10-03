///|
// Frozen before the single global-barrier preflight. Scanner answers and
// sparse candidate discovery stay unchanged in this pilot.
fn cl_copy_barrier_reference_remove(
  instrs : Array[@lib.Instruction],
  types : Array[@lib.ValType],
  param_count : Int,
  interferences : CLBitMatrix,
  weights : CLCopyWeights,
) -> Unit {
  for source = param_count; source < types.length(); source = source + 1 {
    if weights.rows[source].length() == 0 {
      continue
    }
    let (reachable, _) = cl_copy_weight_reachable_destinations(
      weights, source, 4,
    )
    for dest = 0; dest < types.length(); dest = dest + 1 {
      if reachable[dest] &&
        types[source] == types[dest] &&
        cl_copy_forward_pair_safe(instrs, source, dest) {
        cl_bit_matrix_set_symmetric(interferences, source, dest, false)
      }
    }
  }
}
