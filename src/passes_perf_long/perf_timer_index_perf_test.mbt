// Names are built outside timing. Each timed run uses a fresh session and
// records the same distinct per-function timer names as traced raw passes.

///|
fn perf_timer_index_names(count : Int) -> Array[String] {
  let names : Array[String] = []
  for idx = 0; idx < count; idx = idx + 1 {
    names.push("raw:ssa-nomerge:func:\{idx}")
  }
  names
}

///|
fn perf_timer_index_run(names : Array[String]) -> @passes.HotPerfSession {
  let session = @passes.HotPerfSession::new()
  for name in names {
    @passes.perf_stop_timer(session, name, 0UL)
  }
  session
}

///|
fn perf_timer_index_bench(it : @bench.T, count : Int) -> Unit {
  let names = perf_timer_index_names(count)
  let lines : Array[String] = []
  let checked = @passes.HotPerfSession::new(trace=fn(line) { lines.push(line) })
  for name in names {
    @passes.perf_stop_timer(checked, name, 0UL)
  }
  if lines.length() != count {
    abort("timer fixture did not record each name")
  }
  it.bench(fn() { it.keep(perf_timer_index_run(names)) })
}

///|
test "bench timer index distinct names=128" (it : @bench.T) {
  perf_timer_index_bench(it, 128)
}

///|
test "bench timer index distinct names=512" (it : @bench.T) {
  perf_timer_index_bench(it, 512)
}
