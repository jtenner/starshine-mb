// This fixture keeps each allocation's use in a separate straight-line epoch.
// Setup validates the input and output; timing measures the pass invocation.

///|
fn heap2local_root_slot_fixture(epoch_count : Int) -> @lib.Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let owner = @lib.LocalIdx::new(0U)
  let body : Array[@lib.Instruction] = []
  for index = 0; index < epoch_count; index = index + 1 {
    body.push(@lib.Instruction::i32_const(@lib.I32(index)))
    body.push(@lib.Instruction::struct_new(@lib.TypeIdx::new(0U)))
    body.push(@lib.Instruction::local_set(owner))
    body.push(@lib.Instruction::local_get(owner))
    body.push(@lib.Instruction::struct_get(@lib.TypeIdx::new(0U), @lib.U32(0U)))
    body.push(@lib.Instruction::drop())
  }
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([
          @lib.ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(0U))),
        ]),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
fn heap2local_root_slot_bench(it : @bench.T, epochs : Int) -> Unit {
  let fixture = heap2local_root_slot_fixture(epochs)
  let expected = opportunity_run(fixture, "heap2local", true)
  let original_code = fixture.code_sec
  it.bench(fn() { it.keep(opportunity_run(fixture, "heap2local", false)) })
  if opportunity_run(fixture, "heap2local", false) != expected ||
    fixture.code_sec != original_code {
    abort("heap2local root-slot fixture changed across runs")
  }
}

///|
test "bench heap2local root slots epochs=16" (it : @bench.T) {
  heap2local_root_slot_bench(it, 16)
}

///|
test "bench heap2local root slots epochs=32" (it : @bench.T) {
  heap2local_root_slot_bench(it, 32)
}
