///|
fn mp_staircase_overlap_fixture(
  segments : Int,
  bytes_per_segment : Int,
) -> @lib.Module {
  let payload = Bytes::from_array(
    Array::make(bytes_per_segment, (65).to_byte()),
  )
  let datas : Array[@lib.Data] = []
  for offset in 0..<segments {
    datas.push(
      @lib.Data::new(
        @lib.DataMode::active(
          @lib.MemIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(offset))]),
        ),
        payload,
      ),
    )
  }
  @lib.Module::new()
  .with_mem_sec(
    @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, Some(1U)))]),
  )
  .with_data_sec(@lib.DataSec::new(datas))
}

///|
fn mp_staircase_overlap_bench(it : @bench.T, segments : Int) -> Unit {
  let fixture = mp_staircase_overlap_fixture(segments, 4096)
  let original_data = fixture.data_sec
  let expected = opportunity_run(fixture, "memory-packing", true)
  if expected == fixture || fixture.data_sec != original_data {
    abort("MemoryPacking staircase fixture did not rewrite independently")
  }
  it.bench(fn() { it.keep(@passes.memory_packing_run_module_pass(fixture)) })
}

///|
test "bench memory-packing staircase overlap segments=16" (it : @bench.T) {
  mp_staircase_overlap_bench(it, 16)
}

///|
test "bench memory-packing staircase overlap segments=32" (it : @bench.T) {
  mp_staircase_overlap_bench(it, 32)
}
