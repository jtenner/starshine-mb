///|
fn inl_called_planning_fixture(count : Int, active : Bool) -> @lib.Module {
  let wat : Array[String] = ["(module"]
  if active {
    wat.push(
      "(func $helper (param i32 i32) (result i32) local.get 0 local.get 1 i32.add)",
    )
  }
  for _ in 0..<count {
    wat.push("(func (param i32) (result i32) local.get 0 i32.const 3 i32.add ")
    if active {
      wat.push("i32.const 7 call $helper i32.const 7 i32.mul)")
    } else {
      wat.push("i32.const 7 i32.mul)")
    }
  }
  wat.push(")")
  pass_test_module_from_wat(wat.join(""))
}

///|
fn inl_called_planning_bench(
  it : @bench.T,
  count : Int,
  active : Bool,
  full : Bool,
) -> Unit {
  let input = inl_called_planning_fixture(count, active)
  @validate.validate_module(input).unwrap()
  let original = @binary.encode_module(input).unwrap()
  let expected = inl_rewrite_all_calls(input, inl_build_function_infos(input))
  let actual = inl_rewrite_all_calls(
    input,
    inl_build_function_infos(input, classify_uncalled=false),
  )
  if @binary.encode_module(actual.mod_out).unwrap() !=
    @binary.encode_module(expected.mod_out).unwrap() ||
    actual.changed != active ||
    @binary.encode_module(input).unwrap() != original {
    abort("called planning changed the active rewrite or mutated its input")
  }
  @validate.validate_module(actual.mod_out).unwrap()
  if active {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["inlining"]).unwrap()
    @validate.validate_module(output).unwrap()
    if output.code_sec.unwrap().0.length() != count {
      abort("called planning lost active helper removal")
    }
  }
  it.bench(fn() {
    it.keep(inl_build_function_infos(input, classify_uncalled=full))
  })
}

///|
test "bench inlining called planning functions=16 uncalled full" (it : @bench.T) {
  inl_called_planning_bench(it, 16, false, true)
}

///|
test "bench inlining called planning functions=16 uncalled selective" (
  it : @bench.T,
) {
  inl_called_planning_bench(it, 16, false, false)
}

///|
test "bench inlining called planning functions=16 active full" (it : @bench.T) {
  inl_called_planning_bench(it, 16, true, true)
}

///|
test "bench inlining called planning functions=16 active selective" (
  it : @bench.T,
) {
  inl_called_planning_bench(it, 16, true, false)
}

///|
test "bench inlining called planning functions=128 uncalled full" (
  it : @bench.T,
) {
  inl_called_planning_bench(it, 128, false, true)
}

///|
test "bench inlining called planning functions=128 uncalled selective" (
  it : @bench.T,
) {
  inl_called_planning_bench(it, 128, false, false)
}

///|
test "bench inlining called planning functions=128 active full" (it : @bench.T) {
  inl_called_planning_bench(it, 128, true, true)
}

///|
test "bench inlining called planning functions=128 active selective" (
  it : @bench.T,
) {
  inl_called_planning_bench(it, 128, true, false)
}

///|
test "bench inlining called planning functions=1024 uncalled full" (
  it : @bench.T,
) {
  inl_called_planning_bench(it, 1024, false, true)
}

///|
test "bench inlining called planning functions=1024 uncalled selective" (
  it : @bench.T,
) {
  inl_called_planning_bench(it, 1024, false, false)
}

///|
test "bench inlining called planning functions=1024 active full" (it : @bench.T) {
  inl_called_planning_bench(it, 1024, true, true)
}

///|
test "bench inlining called planning functions=1024 active selective" (
  it : @bench.T,
) {
  inl_called_planning_bench(it, 1024, true, false)
}
