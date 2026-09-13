///|
test "audit once summaries include implicit function branch returns" {
  let once = @bitset.BitSet::new(1)
  once[0] = true
  let singleton = @bitset.BitSet::new(1)
  singleton[0] = true
  let summary = or_analyze_instrs(
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ],
    @bitset.BitSet::new(1),
    [],
    [0],
    [once],
    singleton,
    true,
  )
  assert_false(summary[0])
}
