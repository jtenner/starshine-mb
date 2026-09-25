///|
fn mp_full_cover_perf_datas(count : Int) -> Array[@lib.Data] {
  let payload = Bytes::from_array(Array::make(64, (65).to_byte()))
  let datas : Array[@lib.Data] = []
  for _ in 0..<count {
    datas.push(
      @lib.Data::new(
        @lib.DataMode::active(
          @lib.MemIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        payload,
      ),
    )
  }
  datas
}

///|
fn mp_full_cover_perf_bench(it : @bench.T, count : Int) -> Unit {
  let preflight = mp_full_cover_perf_datas(count)
  mp_zero_out_trampled_data(preflight)
  let @lib.Data(_, first) = preflight[0]
  let @lib.Data(_, last) = preflight[count - 1]
  if first != Bytes::from_array(Array::make(64, (0).to_byte())) ||
    last != Bytes::from_array(Array::make(64, (65).to_byte())) {
    abort("MemoryPacking full-cover fixture changed overwrite order")
  }
  it.bench(fn() {
    let datas = mp_full_cover_perf_datas(count)
    mp_zero_out_trampled_data(datas)
    it.keep(datas)
  })
}

///|
test "bench MemoryPacking full cover segments=256" (it : @bench.T) {
  mp_full_cover_perf_bench(it, 256)
}

///|
test "bench MemoryPacking full cover segments=512" (it : @bench.T) {
  mp_full_cover_perf_bench(it, 512)
}
