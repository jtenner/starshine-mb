///|
fn gsi_propagation_perf_fixture(
  depth : Int,
  global_count : Int,
) -> (@validate.Env, Array[Array[@lib.GlobalIdx]]) {
  let source = StringBuilder::new()
  source.write_string("(module\n")
  for slot in 0..<depth {
    if slot == 0 {
      source.write_string("(type $t0 (sub (struct (field i32))))\n")
    } else {
      source.write_string(
        "(type $t\{slot} (sub $t\{slot - 1} (struct (field i32))))\n",
      )
    }
  }
  for _ in 0..<global_count {
    source.write_string(
      "(global (ref $t\{depth - 1}) (struct.new $t\{depth - 1} (i32.const 0)))\n",
    )
  }
  source.write_string(")")
  let mod_ = pass_test_module_from_wat(source.to_string())
  let env = @validate.Env::new().with_module(mod_)
  let candidates : Array[Array[@lib.GlobalIdx]] = []
  for _ in 0..<depth {
    candidates.push([])
  }
  for idx in 0..<global_count {
    candidates[depth - 1].push(@lib.GlobalIdx::new(idx.reinterpret_as_uint()))
  }
  (env, candidates)
}

///|
fn gsi_propagation_perf_bench(
  it : @bench.T,
  depth : Int,
  global_count : Int,
) -> Unit {
  let (env, initial) = gsi_propagation_perf_fixture(depth, global_count)
  let copy_candidates = fn() {
    let out : Array[Array[@lib.GlobalIdx]] = []
    for candidates in initial {
      out.push(candidates.copy())
    }
    out
  }
  let preflight = copy_candidates()
  gsi_propagate_closed_world_subtype_facts(
    env,
    Array::make(depth, false),
    preflight,
  )
  if preflight[0].length() != global_count {
    abort("GSI subtype-chain fixture did not propagate candidates")
  }
  it.bench(fn() {
    let candidates = copy_candidates()
    let poisoned = Array::make(depth, false)
    gsi_propagate_closed_world_subtype_facts(env, poisoned, candidates)
    it.keep(candidates)
  })
}

///|
test "bench GSI subtype propagation depth=16 globals=64" (it : @bench.T) {
  gsi_propagation_perf_bench(it, 16, 64)
}

///|
test "bench GSI subtype propagation depth=32 globals=128" (it : @bench.T) {
  gsi_propagation_perf_bench(it, 32, 128)
}

///|
test "GSI subtype worklist propagates poison and unique candidates" {
  let (env, candidates) = gsi_propagation_perf_fixture(3, 2)
  candidates[2].push(@lib.GlobalIdx::new(0U))
  let poisoned = [false, false, false]
  gsi_propagate_closed_world_subtype_facts(env, poisoned, candidates)
  @debug.assert_eq(poisoned, [false, false, false])
  @debug.assert_eq(candidates[0], [
    @lib.GlobalIdx::new(0U),
    @lib.GlobalIdx::new(1U),
  ])
  let (env, candidates) = gsi_propagation_perf_fixture(3, 2)
  let poisoned = [false, false, true]
  gsi_propagate_closed_world_subtype_facts(env, poisoned, candidates)
  @debug.assert_eq(poisoned, [true, true, true])
  for slot_candidates in candidates {
    assert_true(slot_candidates.is_empty())
  }
}

///|
test "bench GSI empty candidate propagation depth=32" (it : @bench.T) {
  let (env, initial) = gsi_propagation_perf_fixture(32, 0)
  it.bench(fn() {
    let candidates : Array[Array[@lib.GlobalIdx]] = []
    for row in initial {
      candidates.push(row.copy())
    }
    let poisoned = Array::make(32, false)
    gsi_propagate_closed_world_subtype_facts(env, poisoned, candidates)
    it.keep(candidates)
  })
}
