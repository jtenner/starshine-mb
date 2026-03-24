///|
test "hot verify core reports root child span label owner and side-table corruption" {
  let invalid_root = HotFunc::new()
  invalid_root.roots.push(3)
  match hot_verify_core(invalid_root) {
    Err(HotVerifyError::InvalidRoot(0, 3)) => ()
    other => fail("expected invalid root error, got \{other}")
  }

  let invalid_child_span = HotFunc::new()
  invalid_child_span.nodes.push({
    op: HotOp::Nop,
    ty: hot_type_void(invalid_child_span),
    flags: hot_default_flags_for_op(HotOp::Nop),
    imm0: 0,
    imm1: 0,
    child_base: 1,
    child_count: 1,
  })
  match hot_verify_core(invalid_child_span) {
    Err(HotVerifyError::InvalidChildSpan(0, 1, 1)) => ()
    other => fail("expected invalid child span error, got \{other}")
  }

  let invalid_label_owner = HotFunc::new()
  let label_id = hot_label_alloc(
    invalid_label_owner,
    HotLabelKind::BlockLabel,
    hot_type_void(invalid_label_owner),
    99,
    0,
  )
  match hot_verify_core(invalid_label_owner) {
    Err(HotVerifyError::InvalidLabelOwner(owner_label, owner)) => {
      assert_eq(owner_label, label_id)
      assert_eq(owner, 99)
    }
    other => fail("expected invalid label owner, got \{other}")
  }

  let invalid_side_table = HotFunc::new()
  let selector = hot_build_const_i32(invalid_side_table, @lib.I32(0))
  let br_table = hot_build_node(
    invalid_side_table,
    HotOp::BrTable,
    hot_type_void(invalid_side_table),
    imm0=17,
    children=[selector],
  )
  hot_root_append(invalid_side_table, br_table)
  match hot_verify_core(invalid_side_table) {
    Err(
      HotVerifyError::InvalidSideTableRef(
        node_id,
        HotSideTableKind::BranchTableTable,
        table_id
      )
    ) => {
      assert_eq(node_id, br_table)
      assert_eq(table_id, 17)
    }
    other => fail("expected invalid branch-table side table ref, got \{other}")
  }
}
