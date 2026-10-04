///|
test "CFG drop gate preserves segment fields for scalar control reference and handler operands" {
  for
    source in [
      "(module (func (param i32) local.get 0 drop nop local.get 0 drop nop))", "(module (func (param i32) local.get 0 if (result i32) i32.const 7 else i32.const 9 end drop nop))",
      "(module (func block (result i32) i32.const 7 end drop nop))", "(module (func (param externref) block local.get 0 br_on_null 0 drop nop end nop))",
      "(module (tag $e) (func block try_table (catch $e 0) throw $e end nop end nop))",
    ] {
    let module_ = ir_test_module_from_wat(source)
    @validate.validate_module(module_).unwrap()
    let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
    let revision = hot_revision_current(func)
    for expanded in [false, true] {
      let actual_builder = cfg_builder_new(func, true, expanded)
      let reference_builder = cfg_builder_new(func, true, expanded)
      let actual = cfg_builder_region_segments(
        actual_builder,
        func,
        HotRegionRef::root(),
      )
      let expected = cfg_segment_storage_reference(
        reference_builder,
        func,
        HotRegionRef::root(),
      )
      assert_eq(actual_builder.cfg, reference_builder.cfg)
      assert_eq(actual.length(), expected.length())
      for i in 0..<actual.length() {
        let row = actual.get(i)
        assert_eq(row.block_id, expected[i].block_id)
        assert_eq(row.end_slot, expected[i].end_slot)
        assert_eq(row.last_node, expected[i].last_node)
      }
      cfg_verify(cfg_build(func, expand_operand_control=expanded))
    }
    assert_eq(hot_revision_current(func), revision)
  }
}
