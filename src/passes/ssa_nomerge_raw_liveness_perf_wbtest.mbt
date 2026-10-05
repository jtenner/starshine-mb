///|
fn ssa_nomerge_raw_loop_live_fixed_point_reference(
  body : Array[@lib.Instruction],
  live_after : @bitset.BitSet,
  labels : Array[@bitset.BitSet],
) -> @bitset.BitSet {
  let mut header = @bitset.BitSet::new(live_after.length())
  while true {
    let nested_labels = labels.copy()
    nested_labels.push(header)
    let next = ssa_nomerge_raw_live_before(body, 0, live_after, nested_labels)
    if next == header {
      return header
    }
    header = next
  }
  abort("unreachable raw liveness reference exit")
}

///|
test "ssa-nomerge raw loop liveness converges in one body scan" {
  let loop_label = @lib.LabelIdx::new(0U)
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::br(loop_label)],
      None,
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::br_if(loop_label),
  ]
  let labels : Array[@bitset.BitSet] = []
  let scans = [0]
  let live_after = @bitset.BitSet::new(3)
  let expected = ssa_nomerge_raw_loop_live_fixed_point_reference(
    body, live_after, labels,
  )

  let live = ssa_nomerge_raw_loop_live(
    body,
    live_after,
    labels,
    body_scans=Some(scans),
  )

  assert_eq(scans[0], 1)
  assert_eq(live, expected)
  assert_true(live[0])
  assert_true(live[1])
  assert_true(live[2])
}
