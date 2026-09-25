///|
fn msf_targets_bench_fixture(count : Int) -> (@lib.Module, Array[@lib.FuncIdx]) {
  let targets : Array[@lib.FuncIdx] = []
  let funcs : Array[@lib.Func] = []
  let type_idxs : Array[@lib.TypeIdx] = []
  for idx in 0..<count {
    targets.push(@lib.FuncIdx::new(idx.to_uint()))
    funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])))
    type_idxs.push(@lib.TypeIdx::new(0U))
  }
  (
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new(type_idxs))
    .with_code_sec(@lib.CodeSec::new(funcs)),
    targets,
  )
}

///|
fn msf_targets_bench(it : @bench.T, count : Int) -> Unit {
  let (mod_, targets) = msf_targets_bench_fixture(count)
  let prepared = msf_append_declarative_targets(mod_, targets)
  match prepared.elem_sec {
    Some(@lib.ElemSec(elems)) if elems.length() == 1 => ()
    _ => abort("merge-similar target fixture was not appended")
  }
  it.bench(fn() { it.keep(msf_append_declarative_targets(mod_, targets)) })
}

///|
test "MergeSimilarFunctions declarative targets preserve first-seen order" {
  let (mod_, _) = msf_targets_bench_fixture(3)
  let rewritten = msf_append_declarative_targets(mod_, [
    @lib.FuncIdx::new(2U),
    @lib.FuncIdx::new(0U),
    @lib.FuncIdx::new(2U),
    @lib.FuncIdx::new(1U),
    @lib.FuncIdx::new(0U),
  ])
  match rewritten.elem_sec {
    Some(@lib.ElemSec([@lib.Elem(_, @lib.FuncsElemKind(funcs))])) =>
      assert_eq(funcs, [
        @lib.FuncIdx::new(2U),
        @lib.FuncIdx::new(0U),
        @lib.FuncIdx::new(1U),
      ])
    _ => fail("expected one declarative function element segment")
  }
}

///|
test "bench merge-similar targets count=1024" (it : @bench.T) {
  msf_targets_bench(it, 1024)
}

///|
test "bench merge-similar targets count=2048" (it : @bench.T) {
  msf_targets_bench(it, 2048)
}
