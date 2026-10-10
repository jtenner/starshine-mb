// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

///|
// One immutable analysis snapshot. DAE2 already resolves unwritten locals and
// proven entry/sole-write reads without LocalGraph; keep every unresolved read,
// including unrepresented control reads which need the existing fallback.
fn dae2_unresolved_flow_reads(
  func : @ir.HotFunc,
  written : Array[Int],
  entry_sources : Array[Int]?,
) -> Array[Bool] {
  Array::makei(@ir.hot_node_count(func), fn(node) {
    if !@ir.hot_node_is_live(func, node) {
      return false
    }
    if entry_sources is Some(sources) && sources[node] >= -1 {
      return false
    }
    let data = @ir.hot_node_get(func, node)
    data.op is @ir.LocalGet && written[data.imm0] != -1
  })
}
