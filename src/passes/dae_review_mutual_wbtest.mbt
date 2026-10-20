///|
test "DAE mutual dead-suffix edges retain direct-call semantics" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (func $a unreachable call $b call $b call $a)
      #|   (func $b block call $a end)
      #|   (func $c unreachable call $d)
      #|   (func $d return_call $c)
      #|   (func $e unreachable call $f)
      #|   (func $f i32.const 0 if call $e end)
      #|   (func $g unreachable call $g))
    ),
  )
  assert_eq(dae_collect_original_dead_suffix_mutual_calls(input), [
    true, false, false, false, true, false, false,
  ])
  assert_eq(
    dae_collect_original_dead_suffix_mutual_calls(input),
    dae_review_mutual_reference(input),
  )
}

///|
fn dae_review_mutual_bench(
  it : @bench.T,
  reference : Bool,
  acyclic~ : Bool = false,
) -> Unit raise {
  let funcs = Array::makei(64, fn(caller) {
    let targets = Array::makei(64, fn(target) {
      if !acyclic || target > caller {
        "call $f\{target}"
      } else {
        ""
      }
    }).join(" ")
    "(func $f\{caller} unreachable \{targets})"
  }).join(" ")
  let input = pass_test_module_from_wat("(module \{funcs})")
  assert_eq(
    dae_collect_original_dead_suffix_mutual_calls(input),
    dae_review_mutual_reference(input),
  )
  it.bench(fn() {
    it.keep(
      if reference {
        dae_review_mutual_reference(input)
      } else {
        dae_collect_original_dead_suffix_mutual_calls(input)
      },
    )
  })
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE mutual dense 64 pre-review reference" (it : @bench.T) {
  dae_review_mutual_bench(it, true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE mutual dense 64 indexed" (it : @bench.T) {
  dae_review_mutual_bench(it, false)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE mutual acyclic 64 pre-review reference" (it : @bench.T) {
  dae_review_mutual_bench(it, true, acyclic=true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE mutual acyclic 64 indexed" (it : @bench.T) {
  dae_review_mutual_bench(it, false, acyclic=true)
}
