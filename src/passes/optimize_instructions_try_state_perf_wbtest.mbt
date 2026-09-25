///|
fn oi_try_state_fixture(count : Int) -> (@ir.HotFunc, Array[Int]) {
  let func = @ir.HotFunc::new()
  let try_ids : Array[Int] = []
  for idx in 0..<count {
    try_ids.push(
      @ir.hot_build_try(
        func,
        @lib.BlockType::val_type(@lib.ValType::i32()),
        [@ir.hot_build_const_i32(func, @lib.I32(idx))],
        catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(0))]),
      ),
    )
  }
  (func, try_ids)
}

///|
fn oi_try_state_bench(it : @bench.T, count : Int) -> Unit {
  let (func, try_ids) = oi_try_state_fixture(count)
  for try_id in try_ids {
    match OiBooleanTryBodyThrowFact::from_try_operand(func, try_id) {
      Some(fact) if fact.proves_nonthrowing() => ()
      _ => abort("nonthrowing try fixture was rejected")
    }
  }
  it.bench(fn() {
    for try_id in try_ids {
      it.keep(OiBooleanTryBodyThrowFact::from_try_operand(func, try_id))
    }
  })
}

///|
test "bench optimize-instructions try state count=256" (it : @bench.T) {
  oi_try_state_bench(it, 256)
}

///|
test "bench optimize-instructions try state count=512" (it : @bench.T) {
  oi_try_state_bench(it, 512)
}
