///|
fn encoded_local_remap_bench(
  it : @bench.T,
  count : Int,
  width : Int,
  mode : Int,
  reference : Bool,
) -> Unit {
  let before = encoded_local_remap_fixture(width, 127U, mode == 2)
  let after = if mode == 0 {
    before
  } else if mode == 3 {
    let Func(locals, Expr(body)) = before
    let body = body.copy()
    body[width - 1] = Instruction::block(BlockType::void_(), Expr::new([]))
    Func::new(locals, Expr::new(body))
  } else {
    encoded_local_remap_fixture(width, 128U, mode == 2)
  }
  let old_funcs = Array::make(count, before)
  let new_funcs = Array::make(count, after)
  for funcs in [old_funcs, new_funcs] {
    let mod_ = encoded_local_remap_module(before)
      .with_func_sec(FuncSec::new(Array::make(count, TypeIdx::new(0U))))
      .with_code_sec(CodeSec::new(funcs))
    @validate.validate_module(mod_).unwrap()
  }
  let old_state = EncodedModuleSizeState::new(None)
  measure_module_code(old_funcs, [], old_state).unwrap()
  let candidate = EncodedModuleSizeState::new(Some(old_state))
  let expected = EncodedModuleSizeState::new(Some(old_state))
  measure_module_code(new_funcs, [], candidate).unwrap()
  measure_module_code_before_local_remap(new_funcs, [], expected).unwrap()
  if candidate.code_size != expected.code_size ||
    candidate.sizes != expected.sizes {
    abort("local remap measurement differs from complete body encoding")
  }
  it.bench(fn() {
    let first = EncodedModuleSizeState::new(None)
    let second = EncodedModuleSizeState::new(Some(first))
    if reference {
      it.keep(measure_module_code_before_local_remap(old_funcs, [], first))
      it.keep(measure_module_code_before_local_remap(new_funcs, [], second))
    } else {
      it.keep(measure_module_code(old_funcs, [], first))
      it.keep(measure_module_code(new_funcs, [], second))
    }
    it.keep(second.code_size)
  })
}

///|
test "bench size pair shared funcs=1 width=4 reference" (it : @bench.T) {
  encoded_local_remap_bench(it, 1, 4, 0, true)
}

///|
test "bench size pair shared funcs=1 width=4 reuse" (it : @bench.T) {
  encoded_local_remap_bench(it, 1, 4, 0, false)
}

///|
test "bench size pair local-remap funcs=1 width=4 reference" (it : @bench.T) {
  encoded_local_remap_bench(it, 1, 4, 1, true)
}

///|
test "bench size pair local-remap funcs=1 width=4 reuse" (it : @bench.T) {
  encoded_local_remap_bench(it, 1, 4, 1, false)
}

///|
test "bench size pair nested-remap funcs=1 width=4 reference" (it : @bench.T) {
  encoded_local_remap_bench(it, 1, 4, 2, true)
}

///|
test "bench size pair nested-remap funcs=1 width=4 reuse" (it : @bench.T) {
  encoded_local_remap_bench(it, 1, 4, 2, false)
}

///|
test "bench size pair late-fallback funcs=1 width=4 reference" (it : @bench.T) {
  encoded_local_remap_bench(it, 1, 4, 3, true)
}

///|
test "bench size pair late-fallback funcs=1 width=4 reuse" (it : @bench.T) {
  encoded_local_remap_bench(it, 1, 4, 3, false)
}

///|
test "bench size pair shared funcs=32 width=128 reference" (it : @bench.T) {
  encoded_local_remap_bench(it, 32, 128, 0, true)
}

///|
test "bench size pair shared funcs=32 width=128 reuse" (it : @bench.T) {
  encoded_local_remap_bench(it, 32, 128, 0, false)
}

///|
test "bench size pair local-remap funcs=32 width=128 reference" (it : @bench.T) {
  encoded_local_remap_bench(it, 32, 128, 1, true)
}

///|
test "bench size pair local-remap funcs=32 width=128 reuse" (it : @bench.T) {
  encoded_local_remap_bench(it, 32, 128, 1, false)
}

///|
test "bench size pair nested-remap funcs=32 width=128 reference" (it : @bench.T) {
  encoded_local_remap_bench(it, 32, 128, 2, true)
}

///|
test "bench size pair nested-remap funcs=32 width=128 reuse" (it : @bench.T) {
  encoded_local_remap_bench(it, 32, 128, 2, false)
}

///|
test "bench size pair late-fallback funcs=32 width=128 reference" (
  it : @bench.T,
) {
  encoded_local_remap_bench(it, 32, 128, 3, true)
}

///|
test "bench size pair late-fallback funcs=32 width=128 reuse" (it : @bench.T) {
  encoded_local_remap_bench(it, 32, 128, 3, false)
}

///|
test "bench size pair shared funcs=32 width=4096 reference" (it : @bench.T) {
  encoded_local_remap_bench(it, 32, 4096, 0, true)
}

///|
test "bench size pair shared funcs=32 width=4096 reuse" (it : @bench.T) {
  encoded_local_remap_bench(it, 32, 4096, 0, false)
}

///|
test "bench size pair local-remap funcs=32 width=4096 reference" (it : @bench.T) {
  encoded_local_remap_bench(it, 32, 4096, 1, true)
}

///|
test "bench size pair local-remap funcs=32 width=4096 reuse" (it : @bench.T) {
  encoded_local_remap_bench(it, 32, 4096, 1, false)
}

///|
test "bench size pair nested-remap funcs=32 width=4096 reference" (
  it : @bench.T,
) {
  encoded_local_remap_bench(it, 32, 4096, 2, true)
}

///|
test "bench size pair nested-remap funcs=32 width=4096 reuse" (it : @bench.T) {
  encoded_local_remap_bench(it, 32, 4096, 2, false)
}

///|
test "bench size pair late-fallback funcs=32 width=4096 reference" (
  it : @bench.T,
) {
  encoded_local_remap_bench(it, 32, 4096, 3, true)
}

///|
test "bench size pair late-fallback funcs=32 width=4096 reuse" (it : @bench.T) {
  encoded_local_remap_bench(it, 32, 4096, 3, false)
}
