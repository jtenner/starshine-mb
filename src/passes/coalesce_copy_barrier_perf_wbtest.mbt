///|
fn cl_copy_barrier_bench(
  it : @bench.T,
  width : Int,
  kind : Int,
  before : Bool,
) -> Unit raise {
  let text = StringBuilder::new()
  text.write_string("(module (func (param i32) (local ")
  for _ in 0..<64 {
    text.write_string("i32 ")
  }
  text.write_string(") ")
  for source in 1..<33 {
    text.write_string("i32.const 7 local.set ")
    text.write_string(source.to_string())
    text.write_string(" local.get ")
    text.write_string(source.to_string())
    text.write_string(" local.set ")
    text.write_string((source + 32).to_string())
    text.write_string(" ")
  }
  for _ in 0..<width {
    text.write_string("nop ")
  }
  if kind == 1 {
    text.write_string("return ")
  }
  if kind == 2 {
    text.write_string("block i32.const 0 if nop else return end end ")
  }
  text.write_string("))")
  // Full fixture validation is outside timing. The pair pass sees the same
  // immutable body and weights; repeated false edge writes are idempotent.
  let mod_ = pass_test_module_from_wat(text.to_string())
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => abort("missing code")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = funcs[0]
  let types = cl_all_local_types([@lib.ValType::i32()], locals)
  let weights = CLCopyWeights::new(types.length())
  if kind != 3 {
    for source in 1..<33 {
      cl_copy_weight_add(weights, source, source + 32, 1)
    }
  }
  let before_matrix = cl_copy_barrier_full_matrix(types.length())
  let after_matrix = cl_copy_barrier_assert_same(instrs, types, weights)
  cl_copy_barrier_reference_remove(instrs, types, 1, before_matrix, weights)
  it.bench(fn() {
    if before {
      cl_copy_barrier_reference_remove(instrs, types, 1, before_matrix, weights)
      it.keep(before_matrix)
    } else {
      cl_remove_safe_copy_forward_interferences(
        instrs, types, 1, after_matrix, weights,
      )
      it.keep(after_matrix)
    }
  })
}

///|
test "bench copy barrier flat128 before" (it : @bench.T) {
  cl_copy_barrier_bench(it, 128, 1, true)
}

///|
test "bench copy barrier flat128 current" (it : @bench.T) {
  cl_copy_barrier_bench(it, 128, 1, false)
}

///|
test "bench copy barrier nested512 before" (it : @bench.T) {
  cl_copy_barrier_bench(it, 512, 2, true)
}

///|
test "bench copy barrier nested512 current" (it : @bench.T) {
  cl_copy_barrier_bench(it, 512, 2, false)
}

///|
test "bench copy barrier clear8 before" (it : @bench.T) {
  cl_copy_barrier_bench(it, 8, 0, true)
}

///|
test "bench copy barrier clear8 current" (it : @bench.T) {
  cl_copy_barrier_bench(it, 8, 0, false)
}

///|
test "bench copy barrier clear512 before" (it : @bench.T) {
  cl_copy_barrier_bench(it, 512, 0, true)
}

///|
test "bench copy barrier clear512 current" (it : @bench.T) {
  cl_copy_barrier_bench(it, 512, 0, false)
}

///|
test "bench copy barrier no-edges512 before" (it : @bench.T) {
  cl_copy_barrier_bench(it, 512, 3, true)
}

///|
test "bench copy barrier no-edges512 current" (it : @bench.T) {
  cl_copy_barrier_bench(it, 512, 3, false)
}
