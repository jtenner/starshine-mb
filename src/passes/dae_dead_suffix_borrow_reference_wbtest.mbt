///|
fn dae_dead_suffix_before_borrow(
  instrs : Array[@lib.Instruction],
) -> DaeDeadSuffixEvidence? {
  let mut idx = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      let suffix : Array[@lib.Instruction] = []
      let mut suffix_idx = idx + 1
      while suffix_idx < instrs.length() {
        suffix.push(instrs[suffix_idx])
        suffix_idx += 1
      }
      return Some({ root_idx: idx, suffix_start: idx + 1, body: suffix, })
    }
    idx += 1
  }
  None
}
