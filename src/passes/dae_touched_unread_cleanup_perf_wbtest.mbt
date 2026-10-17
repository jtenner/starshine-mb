///|
fn dae_touched_unread_cleanup_reference(
  mod_ : @lib.Module,
  touched : Array[Bool],
) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.copy()
    None => return mod_
  }
  let imported = dae_imported_func_count(mod_)
  let mut changed = false
  for i = 0; i < funcs.length(); i = i + 1 {
    if i < touched.length() && touched[i] {
      let params = run_hot_pipeline_defined_func_params_from_sections(
        mod_,
        @lib.FuncIdx::new((imported + i).reinterpret_as_uint()),
      )
      if params is Some(params) {
        let (next, func_changed) = dae_cleanup_unread_locals(funcs[i], params)
        if func_changed {
          funcs[i] = next
          changed = true
        }
      }
    }
  }
  if changed {
    mod_.with_code_sec(@lib.CodeSec::new(funcs)).without_name_sec()
  } else {
    mod_
  }
}

///|
fn dae_touched_unread_cleanup_bench(
  it : @bench.T,
  count : Int32,
  touched_count : Int32,
  active : Bool,
  reference : Bool,
) -> Unit {
  let input = dae_signature_fixture(count)
  let input = if active {
    input.with_code_sec(
      @lib.CodeSec::new(
        input.code_sec.unwrap().0.map(fn(_) {
          @lib.Func::new(
            @lib.Locals::from_types([@lib.ValType::i32()]),
            @lib.Expr::new([
              @lib.Instruction::i32_const(7),
              @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
            ]),
          )
        }),
      ),
    )
  } else {
    input
  }
  let touched = Array::makei(count, fn(i) { i < touched_count })
  let expected = dae_touched_unread_cleanup_reference(input, touched)
  let actual = dae_cleanup_touched_unread_locals(input, touched)
  if actual != expected {
    abort("DAE touched unread cleanup differs from reference")
  }
  @validate.validate_module(actual).unwrap()
  it.bench(fn() {
    it.keep(
      if reference {
        dae_touched_unread_cleanup_reference(input, touched)
      } else {
        dae_cleanup_touched_unread_locals(input, touched)
      },
    )
  })
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae touched unread empty functions=1024 reference" (it : @bench.T) {
  dae_touched_unread_cleanup_bench(it, 1024, 0, false, true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae touched unread empty functions=1024 indexed" (it : @bench.T) {
  dae_touched_unread_cleanup_bench(it, 1024, 0, false, false)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae touched unread sparse functions=1024 reference" (it : @bench.T) {
  dae_touched_unread_cleanup_bench(it, 1024, 1, true, true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae touched unread sparse functions=1024 indexed" (it : @bench.T) {
  dae_touched_unread_cleanup_bench(it, 1024, 1, true, false)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae touched unread dense functions=64 reference" (it : @bench.T) {
  dae_touched_unread_cleanup_bench(it, 64, 64, true, true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae touched unread dense functions=64 indexed" (it : @bench.T) {
  dae_touched_unread_cleanup_bench(it, 64, 64, true, false)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae touched unread dense functions=1024 reference" (it : @bench.T) {
  dae_touched_unread_cleanup_bench(it, 1024, 1024, true, true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae touched unread dense functions=1024 indexed" (it : @bench.T) {
  dae_touched_unread_cleanup_bench(it, 1024, 1024, true, false)
}
