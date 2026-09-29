///|
fn perf_long_dae2_joined_readers(count : Int) -> @lib.Module {
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      ]),
    ),
  ]
  fn append_sum(reads : Int) -> Unit {
    if reads == 1 {
      body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
    } else {
      let left = reads / 2
      append_sum(left)
      append_sum(reads - left)
      body.push(@lib.Instruction::i32_add())
    }
  }
  append_sum(count)
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
            @lib.ValType::i32(),
          ]),
        ),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
        ),
      ),
    ]),
  )
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new(body),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(42)),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        ]),
      ),
    ]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("run"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
      ),
    ]),
  )
}

///|
fn perf_long_dae2_joined_params(module_ : @lib.Module) -> Array[@lib.ValType] {
  let index = match module_.func_sec.unwrap().0[0] {
    @lib.TypeIdx(raw) => raw.to_int()
    _ => abort("expected absolute worker type")
  }
  match
    module_.type_sec.unwrap().0[index].get_subtype(0U).unwrap().get_comptype() {
    @lib.FuncCompType(params, results) if results == [@lib.ValType::i32()] =>
      params
    _ => abort("expected scalar worker signature")
  }
}

///|
test "DAE2 joined-reader fixture actively removes its unused argument" {
  let fixture = perf_long_dae2_joined_readers(8)
  for pass in ["dae2", "dae2-optimizing"] {
    let output = opportunity_run(fixture, pass, true)
    assert_eq(perf_long_dae2_joined_params(output), [@lib.ValType::i32()])
    assert_eq(perf_long_dae2_joined_params(fixture), [
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ])
  }
}

///|
fn perf_long_dae2_joined_bench(
  it : @bench.T,
  count : Int,
  pass : String,
) -> Unit {
  // Balanced operands isolate reader fanout from deep-recursion costs.
  let fixture = perf_long_dae2_joined_readers(count)
  let output = opportunity_run(fixture, pass, true)
  if perf_long_dae2_joined_params(output) != [@lib.ValType::i32()] {
    abort("joined-reader benchmark failed to eliminate its unused argument")
  }
  // Match the dedicated lane's pass-local timing contract: validate setup,
  // and avoid adding another final wrapper validation to each timed sample.
  it.bench(fn() { it.keep(opportunity_run(fixture, pass, false)) })
}

///|
test "bench dae2 joined readers=512" (it : @bench.T) {
  perf_long_dae2_joined_bench(it, 512, "dae2")
}

///|
test "bench dae2 joined readers=8192" (it : @bench.T) {
  perf_long_dae2_joined_bench(it, 8192, "dae2")
}

///|
test "bench dae2-optimizing joined readers=512" (it : @bench.T) {
  perf_long_dae2_joined_bench(it, 512, "dae2-optimizing")
}

///|
test "bench dae2-optimizing joined readers=8192" (it : @bench.T) {
  perf_long_dae2_joined_bench(it, 8192, "dae2-optimizing")
}
