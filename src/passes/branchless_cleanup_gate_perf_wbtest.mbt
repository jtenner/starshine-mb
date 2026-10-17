///|
fn branchless_cleanup_gate_bench(
  it : @bench.T,
  width : Int32,
  active : Bool,
  reference : Bool,
  early~ : Bool = false,
) -> Unit raise {
  let leaves = Array::make(width, "local.get 0 drop").join(" ")
  let body = if early {
    "local.get 0 if block nop end \{leaves} else \{leaves} end"
  } else if active {
    "block \{leaves} end"
  } else {
    "loop local.get 0 if \{leaves} else \{leaves} end end"
  }
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") (param i32) (result i32) \{body} local.get 0))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let func = input.code_sec.unwrap().0[0]
  let env = @validate.Env::new().with_module(input)
  let expected = branchless_cleanup_gate_reference(
    func,
    input,
    module_env=Some(env),
  )
  let actual = pass_lower_cleanup_branchless_blocks(
    func,
    input,
    module_env=Some(env),
  )
  assert_eq(actual, expected)
  assert_eq(actual.1, active)
  let output = input.with_code_sec(@lib.CodeSec::new([actual.0]))
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(input.with_code_sec(@lib.CodeSec::new([expected.0]))).unwrap(),
  )
  it.bench(fn() {
    it.keep(
      if reference {
        branchless_cleanup_gate_reference(func, input, module_env=Some(env))
      } else {
        pass_lower_cleanup_branchless_blocks(func, input, module_env=Some(env))
      },
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("paired native branchless cleanup cost")
test "bench branchless gate cold16 reference" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 16, false, true)
}

///|
#skip("paired native branchless cleanup cost")
test "bench branchless gate cold16 candidate" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 16, false, false)
}

///|
#skip("paired native branchless cleanup cost")
test "bench branchless gate cold128 reference" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 128, false, true)
}

///|
#skip("paired native branchless cleanup cost")
test "bench branchless gate cold128 candidate" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 128, false, false)
}

///|
#skip("paired native branchless cleanup cost")
test "bench branchless gate cold1024 reference" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 1024, false, true)
}

///|
#skip("paired native branchless cleanup cost")
test "bench branchless gate cold1024 candidate" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 1024, false, false)
}

///|
#skip("paired native branchless cleanup cost")
test "bench branchless gate active16 reference" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 16, true, true)
}

///|
#skip("paired native branchless cleanup cost")
test "bench branchless gate active16 candidate" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 16, true, false)
}

///|
#skip("paired native branchless cleanup cost")
test "bench branchless gate active128 reference" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 128, true, true)
}

///|
#skip("paired native branchless cleanup cost")
test "bench branchless gate active128 candidate" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 128, true, false)
}

///|
#skip("paired native branchless cleanup cost")
test "bench branchless gate active1024 reference" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 1024, true, true)
}

///|
#skip("paired native branchless cleanup cost")
test "bench branchless gate active1024 candidate" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 1024, true, false)
}

///|
#skip("paired native branchless early candidate cost")
test "bench branchless gate early16 reference" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 16, true, true, early=true)
}

///|
#skip("paired native branchless early candidate cost")
test "bench branchless gate early16 candidate" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 16, true, false, early=true)
}

///|
#skip("paired native branchless early candidate cost")
test "bench branchless gate early128 reference" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 128, true, true, early=true)
}

///|
#skip("paired native branchless early candidate cost")
test "bench branchless gate early128 candidate" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 128, true, false, early=true)
}

///|
#skip("paired native branchless early candidate cost")
test "bench branchless gate early1024 reference" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 1024, true, true, early=true)
}

///|
#skip("paired native branchless early candidate cost")
test "bench branchless gate early1024 candidate" (it : @bench.T) {
  branchless_cleanup_gate_bench(it, 1024, true, false, early=true)
}
