///|
fn tc_fork_initialized_for_body(
  initialized : Array[Bool],
  _body : Array[Instruction],
) -> Array[Bool] {
  // Each expression owner copies its inherited mask before the first write.
  // Forks can share the entry mask, including nested handlers and loops.
  initialized
}
