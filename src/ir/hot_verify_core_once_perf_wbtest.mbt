///|
fn core_once_perf_run(
  it : @bench.T,
  roots : Int,
  with_catch : Bool,
  original : Bool,
) -> Unit {
  let func = catch_layout_perf_fixture(roots, with_catch)
  hot_verify_all_or_abort(func)
  it.bench(fn() {
    it.keep(
      if original {
        core_once_reference_all(func)
      } else {
        hot_verify_all(func)
      },
    )
  })
}

///|
test "bench all verification roots=128 catch=false duplicate" (it : @bench.T) {
  core_once_perf_run(it, 128, false, true)
}

///|
test "bench all verification roots=128 catch=false once" (it : @bench.T) {
  core_once_perf_run(it, 128, false, false)
}

///|
test "bench all verification roots=128 catch=true duplicate" (it : @bench.T) {
  core_once_perf_run(it, 128, true, true)
}

///|
test "bench all verification roots=128 catch=true once" (it : @bench.T) {
  core_once_perf_run(it, 128, true, false)
}

///|
test "bench all verification roots=4096 catch=false duplicate" (it : @bench.T) {
  core_once_perf_run(it, 4096, false, true)
}

///|
test "bench all verification roots=4096 catch=false once" (it : @bench.T) {
  core_once_perf_run(it, 4096, false, false)
}

///|
test "bench all verification roots=4096 catch=true duplicate" (it : @bench.T) {
  core_once_perf_run(it, 4096, true, true)
}

///|
test "bench all verification roots=4096 catch=true once" (it : @bench.T) {
  core_once_perf_run(it, 4096, true, false)
}
