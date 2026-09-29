///|
priv struct SimplifyLocalsEffectScanWorkspace {
  marks : Array[Int]
  mut epoch : Int
}

///|
fn SimplifyLocalsEffectScanWorkspace::new() -> SimplifyLocalsEffectScanWorkspace {
  { marks: [], epoch: 0, }
}

///|
// Each query gets a new epoch; only visitation storage is shared. No effect
// fact survives a query, so replacements, detached nodes and region edits are
// observed immediately without a revision cache.
fn SimplifyLocalsEffectScanWorkspace::begin(
  self : SimplifyLocalsEffectScanWorkspace,
  func : @ir.HotFunc,
) -> Array[Int] {
  let nodes = @ir.hot_node_count(func)
  while self.marks.length() < nodes {
    self.marks.push(0)
  }
  if self.epoch >= 0x3fffffff {
    for index in 0..<self.marks.length() {
      self.marks[index] = 0
    }
    self.epoch = 1
  } else {
    self.epoch += 1
  }
  self.marks
}
