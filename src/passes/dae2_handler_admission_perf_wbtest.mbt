///|
fn dae2_handler_admission_fixture(
  count : Int,
  active : Bool,
  legacy : Bool,
) -> @lib.Module {
  let wat = ["(module (tag $t (param i32))"]
  for index in 0..<count {
    wat.push(
      "(func (export \"keep\{index}\") (param i32) (result i32) block (result i32) loop (result i32) block (result i32) local.get 0 end end end)",
    )
  }
  if active {
    wat.push(
      if legacy {
        "(func (export \"run\") (result i32) (try (result i32) (do (throw $t (i32.const 42))) (catch $t) (catch_all (i32.const 0))))"
      } else {
        "(func (export \"run\") (result i32) block $out (result i32) try_table (catch $t $out) i32.const 42 throw $t end i32.const 0 end)"
      },
    )
  }
  wat.push(")")
  pass_test_module_from_wat(wat.join(""))
}

///|
fn dae2_handler_admission_bench(
  it : @bench.T,
  count : Int,
  active : Bool,
  legacy : Bool,
  reference : Bool,
) -> Unit {
  let input = dae2_handler_admission_fixture(count, active, legacy)
  let original = @binary.encode_module(input).unwrap()
  let before = if legacy {
    dae2_prepare_legacy_handlers_reference(input).unwrap()
  } else {
    dae2_fold_known_local_throws_reference(input)
  }
  let after = if legacy {
    dae2_prepare_legacy_handlers(input).unwrap()
  } else {
    dae2_fold_known_local_throws(input)
  }
  let bytes = @binary.encode_module(after).unwrap()
  if @binary.encode_module(before).unwrap() != bytes ||
    @binary.encode_module(input).unwrap() != original ||
    (bytes != original) != active {
    abort("handler admission changed transform or ownership")
  }
  @validate.validate_module(after).unwrap()
  it.bench(fn() {
    it.keep(
      if legacy {
        if reference {
          dae2_prepare_legacy_handlers_reference(input).unwrap()
        } else {
          dae2_prepare_legacy_handlers(input).unwrap()
        }
      } else if reference {
        dae2_fold_known_local_throws_reference(input)
      } else {
        dae2_fold_known_local_throws(input)
      },
    )
  })
}

///|
test "bench DAE2 handler admission functions=16 active=false legacy reference" (
  it : @bench.T,
) {
  dae2_handler_admission_bench(it, 16, false, true, true)
}

///|
test "bench DAE2 handler admission functions=16 active=false legacy selective" (
  it : @bench.T,
) {
  dae2_handler_admission_bench(it, 16, false, true, false)
}

///|
test "bench DAE2 handler admission functions=16 active=false fold reference" (
  it : @bench.T,
) {
  dae2_handler_admission_bench(it, 16, false, false, true)
}

///|
test "bench DAE2 handler admission functions=16 active=false fold selective" (
  it : @bench.T,
) {
  dae2_handler_admission_bench(it, 16, false, false, false)
}

///|
test "bench DAE2 handler admission functions=128 active=false legacy reference" (
  it : @bench.T,
) {
  dae2_handler_admission_bench(it, 128, false, true, true)
}

///|
test "bench DAE2 handler admission functions=128 active=false legacy selective" (
  it : @bench.T,
) {
  dae2_handler_admission_bench(it, 128, false, true, false)
}

///|
test "bench DAE2 handler admission functions=128 active=false fold reference" (
  it : @bench.T,
) {
  dae2_handler_admission_bench(it, 128, false, false, true)
}

///|
test "bench DAE2 handler admission functions=128 active=false fold selective" (
  it : @bench.T,
) {
  dae2_handler_admission_bench(it, 128, false, false, false)
}

///|
test "bench DAE2 handler admission functions=1024 active=false legacy reference" (
  it : @bench.T,
) {
  dae2_handler_admission_bench(it, 1024, false, true, true)
}

///|
test "bench DAE2 handler admission functions=1024 active=false legacy selective" (
  it : @bench.T,
) {
  dae2_handler_admission_bench(it, 1024, false, true, false)
}

///|
test "bench DAE2 handler admission functions=1024 active=false fold reference" (
  it : @bench.T,
) {
  dae2_handler_admission_bench(it, 1024, false, false, true)
}

///|
test "bench DAE2 handler admission functions=1024 active=false fold selective" (
  it : @bench.T,
) {
  dae2_handler_admission_bench(it, 1024, false, false, false)
}

///|
test "bench DAE2 handler admission functions=128 active=true legacy reference" (
  it : @bench.T,
) {
  dae2_handler_admission_bench(it, 128, true, true, true)
}

///|
test "bench DAE2 handler admission functions=128 active=true legacy selective" (
  it : @bench.T,
) {
  dae2_handler_admission_bench(it, 128, true, true, false)
}

///|
test "bench DAE2 handler admission functions=128 active=true fold reference" (
  it : @bench.T,
) {
  dae2_handler_admission_bench(it, 128, true, false, true)
}

///|
test "bench DAE2 handler admission functions=128 active=true fold selective" (
  it : @bench.T,
) {
  dae2_handler_admission_bench(it, 128, true, false, false)
}
