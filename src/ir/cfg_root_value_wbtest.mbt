///|
test "CFG root records retain scalar fields and independent array copies" {
  for count in [0, 1, 31, 65] {
    let func = HotFunc::new()
    for _ in 0..<count {
      hot_root_append(func, hot_build_nop(func))
    }
    for expanded in [false, true] {
      let cfg = cfg_build(func, expand_operand_control=expanded)
      cfg_verify(cfg)
      hot_verify_cfg(func, cfg).unwrap()
      let held = cfg.region_roots.copy()
      assert_eq(held.length(), count)
      for index, entry in held {
        assert_eq(entry.region_holder, HOT_NONE_NODE)
        assert_eq(entry.slot, index)
        assert_true(entry.block >= 0 && entry.block < cfg.blocks.length())
        assert_eq(cfg.region_roots[index], entry)
      }
      if count > 0 {
        let original = held[0]
        held[0] = { ..original, slot: count, }
        assert_eq(original.slot, 0)
        assert_eq(cfg.region_roots[0].slot, 0)
        hot_verify_cfg(func, cfg).unwrap()
      }
    }
  }
}
