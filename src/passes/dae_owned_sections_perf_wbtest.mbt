///|
fn dae_owned_sections_bench(
  it : @bench.T,
  count : Int,
  mode : Int,
  reference : Bool,
) -> Unit {
  let groups = Array::makei(count, fn(_) {
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], [])))
  })
  let types = @lib.TypeSec::new(groups)
  let original = @lib.Module::new().with_type_sec(types)
  let copy = if mode == 1 {
    original.with_type_sec(@lib.TypeSec::new(groups.copy()))
  } else {
    original.with_type_sec(types)
  }
  let copy = if mode == 2 {
    copy.with_export_sec(@lib.ExportSec::new([]))
  } else {
    copy
  }
  @validate.validate_module(original).unwrap()
  @validate.validate_module(copy).unwrap()
  let expected = mode != 2
  if (original == copy) != expected ||
    dae_snapshot_module_unchanged(original, copy) != expected {
    abort("owned section guard accepted changed metadata")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        original == copy
      } else {
        dae_snapshot_module_unchanged(original, copy)
      },
    )
  })
}

///|
test "bench DAE metadata types=4 shared reference" (it : @bench.T) {
  dae_owned_sections_bench(it, 4, 0, true)
}

///|
test "bench DAE metadata types=4 shared owned" (it : @bench.T) {
  dae_owned_sections_bench(it, 4, 0, false)
}

///|
test "bench DAE metadata types=4096 shared reference" (it : @bench.T) {
  dae_owned_sections_bench(it, 4096, 0, true)
}

///|
test "bench DAE metadata types=4096 shared owned" (it : @bench.T) {
  dae_owned_sections_bench(it, 4096, 0, false)
}

///|
test "bench DAE metadata types=4096 distinct reference" (it : @bench.T) {
  dae_owned_sections_bench(it, 4096, 1, true)
}

///|
test "bench DAE metadata types=4096 distinct owned" (it : @bench.T) {
  dae_owned_sections_bench(it, 4096, 1, false)
}

///|
test "bench DAE metadata types=4096 changed reference" (it : @bench.T) {
  dae_owned_sections_bench(it, 4096, 2, true)
}

///|
test "bench DAE metadata types=4096 changed owned" (it : @bench.T) {
  dae_owned_sections_bench(it, 4096, 2, false)
}
