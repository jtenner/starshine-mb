///|
fn sl_first_use_minimum_bench(
  it : @bench.T,
  width : Int,
  hazard : Bool,
  reference : Bool,
) -> Unit {
  let func = sl_first_use_minimum_fixture(width, hazard)
  let cache = SimplifyLocalsValueOrderMinimums::new()
  let expected = simplify_locals_set_first_use_crosses_intervening_local_write(
    func,
    @ir.HotRegionRef::root(),
    0,
    1,
  )
  let actual = simplify_locals_set_first_use_crosses_intervening_local_write(
    func,
    @ir.HotRegionRef::root(),
    0,
    1,
    minimums=Some(cache),
  )
  if actual != expected || actual != hazard {
    abort("minimum-order benchmark lost first-use/older-stack hazard semantics")
  }
  let revision = @ir.hot_revision_current(func)
  it.bench(fn() {
    let cache = if reference {
      None
    } else {
      Some(SimplifyLocalsValueOrderMinimums::new())
    }
    it.keep(
      simplify_locals_set_first_use_crosses_intervening_local_write(
        func,
        @ir.HotRegionRef::root(),
        0,
        1,
        minimums=cache,
      ),
    )
  })
  if @ir.hot_revision_current(func) != revision {
    abort("minimum-order benchmark mutated the function")
  }
  @ir.hot_verify_all(func).unwrap()
}

///|
test "bench SL first-use width=1 independent reference" (it : @bench.T) {
  sl_first_use_minimum_bench(it, 1, false, true)
}

///|
test "bench SL first-use width=1 independent minimum" (it : @bench.T) {
  sl_first_use_minimum_bench(it, 1, false, false)
}

///|
test "bench SL first-use width=1 hazard reference" (it : @bench.T) {
  sl_first_use_minimum_bench(it, 1, true, true)
}

///|
test "bench SL first-use width=1 hazard minimum" (it : @bench.T) {
  sl_first_use_minimum_bench(it, 1, true, false)
}

///|
test "bench SL first-use width=128 independent reference" (it : @bench.T) {
  sl_first_use_minimum_bench(it, 128, false, true)
}

///|
test "bench SL first-use width=128 independent minimum" (it : @bench.T) {
  sl_first_use_minimum_bench(it, 128, false, false)
}

///|
test "bench SL first-use width=128 hazard reference" (it : @bench.T) {
  sl_first_use_minimum_bench(it, 128, true, true)
}

///|
test "bench SL first-use width=128 hazard minimum" (it : @bench.T) {
  sl_first_use_minimum_bench(it, 128, true, false)
}
