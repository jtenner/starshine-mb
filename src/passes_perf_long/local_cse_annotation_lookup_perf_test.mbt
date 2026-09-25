///|
fn lcse_annotation_lookup_fixture(count : Int) -> @lib.Module {
  let type_idxs : Array[@lib.TypeIdx] = []
  let funcs : Array[@lib.Func] = []
  let entries : Array[@lib.FuncAnnotationAssoc] = []
  for idx in 0..<count {
    type_idxs.push(@lib.TypeIdx::new(0U))
    funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])))
    entries.push(
      @lib.FuncAnnotationAssoc::new(idx.to_uint(), [
        @lib.FuncAnnotation::new("binaryen.js.called"),
      ]),
    )
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new(type_idxs))
  .with_code_sec(@lib.CodeSec::new(funcs))
  .with_func_annotation_sec(@lib.FuncAnnotationSec::new(entries))
}

///|
fn lcse_annotation_lookup_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = lcse_annotation_lookup_fixture(count)
  match
    @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [
      "local-cse",
    ]) {
    Ok(_) => ()
    Err(err) => abort("local-cse annotation fixture invalid: \{err}")
  }
  it.bench(fn() { it.keep(@passes.local_cse_run_module_pass(fixture)) })
}

///|
test "bench local-cse annotation lookup funcs=512" (it : @bench.T) {
  lcse_annotation_lookup_bench(it, 512)
}

///|
test "bench local-cse annotation lookup funcs=1024" (it : @bench.T) {
  lcse_annotation_lookup_bench(it, 1024)
}
