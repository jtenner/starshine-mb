///|
fn dae_restore_admission_bench(
  it : @bench.T,
  helpers : Int,
  width : Int,
  reference : Bool,
) -> Unit {
  let wat = ["(module"]
  for i in 0..<helpers {
    wat.push(
      "(func $f\{i} (export \"f\{i}\") (param f64) (result f64) local.get 0",
    )
    for _ in 0..<width {
      wat.push("f64.const 7 f64.add")
    }
    wat.push(")")
  }
  wat.push(")")
  let input = pass_test_module_from_wat(wat.join(" "))
  let saved = @binary.encode_module(input).unwrap()
  let output = dae_restore_dead_suffix_self_operand_params(input, input)
  let before = dae_restore_admission_reference(input, input)
  if output.changed != before.changed ||
    @binary.encode_module(output.mod_out).unwrap() !=
    @binary.encode_module(before.mod_out).unwrap() {
    abort("restoration admission changed a noncandidate's output")
  }
  @validate.validate_module(output.mod_out).unwrap()
  it.bench(fn() {
    it.keep(
      if reference {
        dae_restore_admission_reference(input, input)
      } else {
        dae_restore_dead_suffix_self_operand_params(input, input)
      },
    )
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("restoration benchmark mutated input")
  }
}

///|
test "bench DAE restoration helpers=1 width=1 reference" (it : @bench.T) {
  dae_restore_admission_bench(it, 1, 1, true)
}

///|
test "bench DAE restoration helpers=1 width=1 admitted" (it : @bench.T) {
  dae_restore_admission_bench(it, 1, 1, false)
}

///|
test "bench DAE restoration helpers=32 width=128 reference" (it : @bench.T) {
  dae_restore_admission_bench(it, 32, 128, true)
}

///|
test "bench DAE restoration helpers=32 width=128 admitted" (it : @bench.T) {
  dae_restore_admission_bench(it, 32, 128, false)
}
