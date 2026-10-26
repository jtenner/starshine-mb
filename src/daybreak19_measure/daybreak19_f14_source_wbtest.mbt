///|
fn spec_runner_normalize_args(argv : Array[String]) -> Array[String] {
  let out : Array[String] = []
  let mut i = 1
  while i < argv.length() {
    out.push(argv[i])
    i += 1
  }
  out
}
