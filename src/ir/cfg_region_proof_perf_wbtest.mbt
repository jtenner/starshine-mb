///|
fn cfg_region_proof_bench(
  it : @bench.T,
  siblings : Int32,
  width : Int32,
  reference : Bool,
) -> Unit {
  let (func, regions) = cfg_region_proof_fixture(siblings, width)
  let run = fn(old) {
    let builder = cfg_builder_new(func, true, true)
    for region in regions {
      if old {
        ignore(cfg_region_proof_reference(builder, func, region))
      } else {
        ignore(cfg_builder_region_segments(builder, func, region))
      }
    }
    builder.cfg
  }
  if run(true) != run(false) {
    abort("per-region source-order proof changed CFG fields")
  }
  it.bench(fn() { it.keep(run(reference)) })
}

///|
test "bench CFG warm facts siblings=4 roots=16 reference" (it : @bench.T) {
  cfg_region_proof_bench(it, 4, 8, true)
}

///|
test "bench CFG warm facts siblings=4 roots=16 selected" (it : @bench.T) {
  cfg_region_proof_bench(it, 4, 8, false)
}

///|
test "bench CFG warm facts siblings=64 roots=32 reference" (it : @bench.T) {
  cfg_region_proof_bench(it, 64, 16, true)
}

///|
test "bench CFG warm facts siblings=64 roots=32 selected" (it : @bench.T) {
  cfg_region_proof_bench(it, 64, 16, false)
}

///|
test "bench CFG warm facts siblings=4 roots=128 reference" (it : @bench.T) {
  cfg_region_proof_bench(it, 4, 64, true)
}

///|
test "bench CFG warm facts siblings=4 roots=128 selected" (it : @bench.T) {
  cfg_region_proof_bench(it, 4, 64, false)
}
