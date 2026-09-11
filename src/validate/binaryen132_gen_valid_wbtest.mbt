///|
test "Binaryen 132 precompute aggregate includes all atomic orders" {
  let mod_ = gen_valid_precompute_profile_module(
    GenValidConfig::for_profile(PrecomputeGcAtomicBoundaryProfile),
  )
  match validate_module(mod_) {
    Ok(_) => ()
    Err(err) => fail("expected a valid atomic profile: \{err}")
  }
  let body = match mod_.code_sec {
    Some(CodeSec([Func(_, Expr(body))])) => body
    _ => fail("expected one aggregate boundary function")
  }
  for
    order in [
      AtomicOrder::seq_cst(),
      AtomicOrder::acq_rel(),
      AtomicOrder::relaxed(),
    ] {
    assert_true(
      body.contains(
        Instruction::struct_atomic_get_s(order, TypeIdx::new(0U), U32(0U)),
      ),
    )
  }
}
