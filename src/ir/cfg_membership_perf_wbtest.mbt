///|
fn cfg_membership_reference(cfg : HotCfg) -> Unit {
  for block_id = 0; block_id < cfg.blocks.length(); block_id = block_id + 1 {
    let block = cfg.blocks[block_id]
    if block.id != block_id {
      abort("cfg block ids must match their storage index")
    }
    for succ in block.succs {
      if succ.block < 0 || succ.block >= cfg.blocks.length() {
        abort("cfg successor target must reference a valid block id")
      }
      let mut found = false
      for pred in cfg.blocks[succ.block].preds {
        if pred.block == block_id && pred.kind == succ.kind {
          found = true
          break
        }
      }
      if !found {
        abort("cfg successors and predecessors must stay symmetric")
      }
    }
    for pred in block.preds {
      if pred.block < 0 || pred.block >= cfg.blocks.length() {
        abort("cfg predecessor source must reference a valid block id")
      }
      let mut found = false
      for succ in cfg.blocks[pred.block].succs {
        if succ.block == block_id && succ.kind == pred.kind {
          found = true
          break
        }
      }
      if !found {
        abort("cfg predecessors and successors must stay symmetric")
      }
    }
  }
  for node_id = 0; node_id < cfg.node_to_block.length(); node_id = node_id + 1 {
    let block_id = cfg.node_to_block[node_id]
    if block_id < 0 {
      continue
    }
    if block_id >= cfg.blocks.length() {
      abort("cfg node-to-block mapping must reference a valid block")
    }
    let mut found = false
    for mapped in cfg.blocks[block_id].nodes {
      if mapped == node_id {
        found = true
        break
      }
    }
    if !found {
      abort("cfg node-to-block mapping must match the owning block node list")
    }
  }
  for entry in cfg.region_roots {
    if entry.block < 0 || entry.block >= cfg.blocks.length() {
      abort("cfg region-root mapping must reference a valid block")
    }
  }
}

///|
fn cfg_membership_bench(it : @bench.T, count : Int, reference : Bool) -> Unit {
  let func = HotFunc::new()
  for _ in 0..<count {
    hot_root_append(func, hot_build_nop(func))
  }
  let cfg = cfg_build(func)
  cfg_membership_reference(cfg)
  cfg_verify(cfg)
  it.bench(fn() {
    if reference {
      cfg_membership_reference(cfg)
    } else {
      cfg_verify(cfg)
    }
    it.keep(cfg)
  })
}

///|
test "bench CFG flat membership nodes=16 reference" (it : @bench.T) {
  cfg_membership_bench(it, 16, true)
}

///|
test "bench CFG flat membership nodes=16 indexed" (it : @bench.T) {
  cfg_membership_bench(it, 16, false)
}

///|
test "bench CFG flat membership nodes=256 reference" (it : @bench.T) {
  cfg_membership_bench(it, 256, true)
}

///|
test "bench CFG flat membership nodes=256 indexed" (it : @bench.T) {
  cfg_membership_bench(it, 256, false)
}

///|
test "bench CFG flat membership nodes=4096 reference" (it : @bench.T) {
  cfg_membership_bench(it, 4096, true)
}

///|
test "bench CFG flat membership nodes=4096 indexed" (it : @bench.T) {
  cfg_membership_bench(it, 4096, false)
}
