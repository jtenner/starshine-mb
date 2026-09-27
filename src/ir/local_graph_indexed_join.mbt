///|
// Keep source encounter order in the output, using membership hashing only for
// large joins. Published source arrays remain immutable, including subset joins.
fn local_graph_join_indexed_sources(
  lhs : Array[Int],
  rhs : Array[Int],
  membership_builds? : Array[Int]? = None,
) -> Array[Int] {
  if rhs.is_empty() {
    return lhs
  }
  let mut start = 0
  while start < lhs.length() && lhs[start] != rhs[0] {
    start += 1
  }
  if rhs.length() <= lhs.length() - start {
    let mut contiguous = true
    for index = 1; index < rhs.length(); index = index + 1 {
      if lhs[start + index] != rhs[index] {
        contiguous = false
        break
      }
    }
    if contiguous {
      return lhs
    }
  }
  // Keep the original allocation-free subset path for arbitrary source order.
  if rhs.all(fn(source) { local_graph_array_contains(lhs, source) }) {
    return lhs
  }
  match membership_builds {
    Some(count) => count[0] += 1
    None => ()
  }
  let present : @set.Set[Int] = @set.Set([])
  for source in lhs {
    present.add(source)
  }
  let mut merged : Array[Int]? = None
  for source in rhs {
    if !present.contains(source) {
      present.add(source)
      let output = match merged {
        Some(output) => output
        None => {
          let output = lhs.copy()
          merged = Some(output)
          output
        }
      }
      output.push(source)
    }
  }
  match merged {
    Some(output) => output
    None => lhs
  }
}
