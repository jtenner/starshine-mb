///|
fn ca_module_env_fixture(count : Int) -> @lib.Module {
  let wat = ["(module (type $result (func (result i32)))"]
  for index in 0..<count {
    wat.push(
      "(func (export \"run\{index}\") (result i32) block (type $result) i32.const 7 end)",
    )
  }
  wat.push(")")
  pass_test_module_from_wat(wat.join(""))
}

///|
fn ca_module_env_outputs(
  input : @lib.Module,
  refinalize : Bool,
  shared : Bool,
) -> Array[@lib.Func] {
  let env = if shared {
    Some(@validate.Env::new().with_module(input))
  } else {
    None
  }
  let output : Array[@lib.Func] = []
  let funcs = input.code_sec.unwrap().0
  for index in 0..<funcs.length() {
    output.push(
      if refinalize {
        if shared {
          ca_lower_refinalize(
            funcs[index],
            input,
            @lib.FuncIdx::new(index.to_uint()),
            module_env=env,
          )
        } else {
          ca_lower_refinalize_reference(
            funcs[index],
            input,
            @lib.FuncIdx::new(index.to_uint()),
          )
        }
      } else if shared {
        ca_lower_cleanup_raw(funcs[index], input, module_env=env).0
      } else {
        ca_lower_cleanup_raw_reference(funcs[index], input).0
      },
    )
  }
  output
}

///|
fn ca_module_env_bench(
  it : @bench.T,
  count : Int,
  refinalize : Bool,
  shared : Bool,
) -> Unit {
  let input = ca_module_env_fixture(count)
  let original = @binary.encode_module(input).unwrap()
  let before = ca_module_env_outputs(input, refinalize, false)
  let after = ca_module_env_outputs(input, refinalize, true)
  let result = input.with_code_sec(@lib.CodeSec::new(after))
  @validate.validate_module(result).unwrap()
  if @binary.encode_module(result).unwrap() !=
    @binary.encode_module(input.with_code_sec(@lib.CodeSec::new(before))).unwrap() ||
    @binary.encode_module(input).unwrap() != original {
    abort("constraint cleanup environment changed bytes or ownership")
  }
  for func in after {
    let @lib.Func(_, @lib.Expr(body)) = func
    if body != [@lib.Instruction::i32_const(@lib.I32(7))] {
      abort("typed block cleanup did not trigger")
    }
  }
  it.bench(fn() { it.keep(ca_module_env_outputs(input, refinalize, shared)) })
}

///|
test "bench constraint cleanup functions=1 refinalize reference" (it : @bench.T) {
  ca_module_env_bench(it, 1, true, false)
}

///|
test "bench constraint cleanup functions=1 refinalize shared" (it : @bench.T) {
  ca_module_env_bench(it, 1, true, true)
}

///|
test "bench constraint cleanup functions=1 raw reference" (it : @bench.T) {
  ca_module_env_bench(it, 1, false, false)
}

///|
test "bench constraint cleanup functions=1 raw shared" (it : @bench.T) {
  ca_module_env_bench(it, 1, false, true)
}

///|
test "bench constraint cleanup functions=16 refinalize reference" (
  it : @bench.T,
) {
  ca_module_env_bench(it, 16, true, false)
}

///|
test "bench constraint cleanup functions=16 refinalize shared" (it : @bench.T) {
  ca_module_env_bench(it, 16, true, true)
}

///|
test "bench constraint cleanup functions=16 raw reference" (it : @bench.T) {
  ca_module_env_bench(it, 16, false, false)
}

///|
test "bench constraint cleanup functions=16 raw shared" (it : @bench.T) {
  ca_module_env_bench(it, 16, false, true)
}

///|
test "bench constraint cleanup functions=128 refinalize reference" (
  it : @bench.T,
) {
  ca_module_env_bench(it, 128, true, false)
}

///|
test "bench constraint cleanup functions=128 refinalize shared" (it : @bench.T) {
  ca_module_env_bench(it, 128, true, true)
}

///|
test "bench constraint cleanup functions=128 raw reference" (it : @bench.T) {
  ca_module_env_bench(it, 128, false, false)
}

///|
test "bench constraint cleanup functions=128 raw shared" (it : @bench.T) {
  ca_module_env_bench(it, 128, false, true)
}

///|
test "bench constraint cleanup functions=1024 refinalize reference" (
  it : @bench.T,
) {
  ca_module_env_bench(it, 1024, true, false)
}

///|
test "bench constraint cleanup functions=1024 refinalize shared" (it : @bench.T) {
  ca_module_env_bench(it, 1024, true, true)
}

///|
test "bench constraint cleanup functions=1024 raw reference" (it : @bench.T) {
  ca_module_env_bench(it, 1024, false, false)
}

///|
test "bench constraint cleanup functions=1024 raw shared" (it : @bench.T) {
  ca_module_env_bench(it, 1024, false, true)
}
