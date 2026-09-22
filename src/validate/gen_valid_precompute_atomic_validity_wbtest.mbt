///|
test "precompute GC atomic boundary uses independently supported load orders" {
  let input = gen_valid_precompute_profile_module(
    GenValidConfig::for_profile(PrecomputeGcAtomicBoundaryProfile),
  )
  let body = match input.code_sec {
    Some(CodeSec([Func(_, Expr(body))])) => body
    _ => fail("expected one precompute GC atomic boundary function")
  }
  let mut seq_cst_loads = 0
  let mut acq_rel_loads = 0
  for instruction in body {
    match instruction {
      StructAtomicGetS(order, _, _) =>
        match order {
          SeqCst => seq_cst_loads += 1
          AcqRel => acq_rel_loads += 1
          Relaxed =>
            fail("independent validator rejects Relaxed aggregate atomic reads")
        }
      _ => ()
    }
  }
  assert_true(seq_cst_loads > 0)
  assert_true(acq_rel_loads > 0)
}
