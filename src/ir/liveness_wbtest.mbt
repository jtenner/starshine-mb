///|
test "liveness update_block_words computes in-place live-in and live-out" {
  let succ_live_in = bitset_new(130)
  ignore(bitset_set(succ_live_in, 1))
  ignore(bitset_set(succ_live_in, 64))
  ignore(bitset_set(succ_live_in, 129))

  let defs = bitset_new(130)
  ignore(bitset_set(defs, 64))

  let uses = bitset_new(130)
  ignore(bitset_set(uses, 3))

  let live_out = bitset_new(130)
  let live_in = bitset_new(130)
  ignore(bitset_set(live_in, 9))

  let (out_changed, in_changed) = liveness_update_block_words(
    [{ kind: CfgEdgeKind::FallthroughEdge, block: 0 }],
    [succ_live_in],
    defs,
    uses,
    live_out,
    live_in,
    false,
  )

  assert_true(out_changed)
  assert_true(in_changed)
  assert_true(bitset_contains(live_out, 1))
  assert_true(bitset_contains(live_out, 64))
  assert_true(bitset_contains(live_out, 129))
  assert_true(bitset_contains(live_in, 1))
  assert_true(bitset_contains(live_in, 3))
  assert_false(bitset_contains(live_in, 64))
  assert_true(bitset_contains(live_in, 129))
  assert_false(bitset_contains(live_in, 9))
}
