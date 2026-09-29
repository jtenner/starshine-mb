///|
fn dae_count_only_facts_fixture(calls : Int, params : Int) -> @lib.Module {
  let wat : Array[String] = ["(module (func $helper (param"]
  for _ in 0..<params {
    wat.push(" i32")
  }
  wat.push(") (result i32) i32.const 7) (func (export \"run\")")
  for _ in 0..<calls {
    wat.push(" block ")
    for param in 0..<params {
      wat.push("i32.const \{param + 7} ")
    }
    wat.push("call $helper drop end ")
  }
  wat.push("))")
  pass_test_module_from_wat(wat.join(""))
}

///|
fn dae_count_only_facts_bench(
  it : @bench.T,
  calls : Int,
  params : Int,
  reference : Bool,
) -> Unit {
  let input = dae_count_only_facts_fixture(calls, params)
  let expected = dae_collect_current_function_analysis(input, 2).call_facts
  let actual = dae_collect_current_call_facts(input, 2)
  if !dae_current_call_facts_equal(actual, expected) ||
    actual.direct_calls[0] != calls ||
    actual.dropped_calls[0] != calls {
    abort("count-only query changed call facts")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        dae_collect_current_function_analysis(input, 2).call_facts
      } else {
        dae_collect_current_call_facts(input, 2)
      },
    )
  })
}

///|
test "bench DAE count facts calls=32 params=0 reference" (it : @bench.T) {
  dae_count_only_facts_bench(it, 32, 0, true)
}

///|
test "bench DAE count facts calls=32 params=0 counts" (it : @bench.T) {
  dae_count_only_facts_bench(it, 32, 0, false)
}

///|
test "bench DAE count facts calls=32 params=2 reference" (it : @bench.T) {
  dae_count_only_facts_bench(it, 32, 2, true)
}

///|
test "bench DAE count facts calls=32 params=2 counts" (it : @bench.T) {
  dae_count_only_facts_bench(it, 32, 2, false)
}

///|
test "bench DAE count facts calls=32 params=16 reference" (it : @bench.T) {
  dae_count_only_facts_bench(it, 32, 16, true)
}

///|
test "bench DAE count facts calls=32 params=16 counts" (it : @bench.T) {
  dae_count_only_facts_bench(it, 32, 16, false)
}

///|
test "bench DAE count facts calls=128 params=0 reference" (it : @bench.T) {
  dae_count_only_facts_bench(it, 128, 0, true)
}

///|
test "bench DAE count facts calls=128 params=0 counts" (it : @bench.T) {
  dae_count_only_facts_bench(it, 128, 0, false)
}

///|
test "bench DAE count facts calls=128 params=2 reference" (it : @bench.T) {
  dae_count_only_facts_bench(it, 128, 2, true)
}

///|
test "bench DAE count facts calls=128 params=2 counts" (it : @bench.T) {
  dae_count_only_facts_bench(it, 128, 2, false)
}

///|
test "bench DAE count facts calls=128 params=16 reference" (it : @bench.T) {
  dae_count_only_facts_bench(it, 128, 16, true)
}

///|
test "bench DAE count facts calls=128 params=16 counts" (it : @bench.T) {
  dae_count_only_facts_bench(it, 128, 16, false)
}

///|
test "bench DAE count facts calls=512 params=0 reference" (it : @bench.T) {
  dae_count_only_facts_bench(it, 512, 0, true)
}

///|
test "bench DAE count facts calls=512 params=0 counts" (it : @bench.T) {
  dae_count_only_facts_bench(it, 512, 0, false)
}

///|
test "bench DAE count facts calls=512 params=2 reference" (it : @bench.T) {
  dae_count_only_facts_bench(it, 512, 2, true)
}

///|
test "bench DAE count facts calls=512 params=2 counts" (it : @bench.T) {
  dae_count_only_facts_bench(it, 512, 2, false)
}

///|
test "bench DAE count facts calls=512 params=16 reference" (it : @bench.T) {
  dae_count_only_facts_bench(it, 512, 16, true)
}

///|
test "bench DAE count facts calls=512 params=16 counts" (it : @bench.T) {
  dae_count_only_facts_bench(it, 512, 16, false)
}
