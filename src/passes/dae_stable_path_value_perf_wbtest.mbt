///|
fn dae_stable_path_value_bench(
  it : @bench.T,
  count : Int32,
  branching : Bool,
) -> Unit {
  it.bench(fn() {
    let mut prefix = DaeStablePath::empty()
    let paths : Array[DaeStablePath] = []
    for value in 0..<count {
      if branching {
        paths.push(prefix.append(0).append(value))
      } else {
        paths.push(prefix.append(value))
      }
      prefix = prefix.append(1)
    }
    it.keep(paths)
  })
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE stable path values prefixes=32" (it : @bench.T) {
  dae_stable_path_value_bench(it, 32, false)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE stable path values prefixes=1024" (it : @bench.T) {
  dae_stable_path_value_bench(it, 1024, false)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE stable path values branches=32" (it : @bench.T) {
  dae_stable_path_value_bench(it, 32, true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE stable path values branches=1024" (it : @bench.T) {
  dae_stable_path_value_bench(it, 1024, true)
}
