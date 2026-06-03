///|
pub impl Show for HotTypeInfo with fn output(self, logger) {
  match self {
    HotTypeInfo::VoidType => logger.write_string("VoidType")
    HotTypeInfo::BlockResult(block_type) => {
      logger.write_string("BlockResult(")
      block_type.output(logger)
      logger.write_char(')')
    }
    HotTypeInfo::BlockResultResolved(block_type, params, values) => {
      logger.write_string("BlockResultResolved(")
      block_type.output(logger)
      logger.write_string(", ")
      params.output(logger)
      logger.write_string(", ")
      values.output(logger)
      logger.write_char(')')
    }
    HotTypeInfo::Value(ty) => {
      logger.write_string("Value(")
      ty.output(logger)
      logger.write_char(')')
    }
    HotTypeInfo::Results(types) => {
      logger.write_string("Results(")
      types.output(logger)
      logger.write_char(')')
    }
  }
}

///|
pub impl Show for HotLabelKind with fn output(self, logger) {
  match self {
    HotLabelKind::BlockLabel => logger.write_string("BlockLabel")
    HotLabelKind::LoopLabel => logger.write_string("LoopLabel")
    HotLabelKind::IfLabel => logger.write_string("IfLabel")
    HotLabelKind::RegionLabel => logger.write_string("RegionLabel")
    HotLabelKind::TryLabel => logger.write_string("TryLabel")
    HotLabelKind::TryTableLabel => logger.write_string("TryTableLabel")
  }
}

///|
pub impl Show for HotSideTableKind with fn output(self, logger) {
  match self {
    HotSideTableKind::ConstPayloadTable =>
      logger.write_string("ConstPayloadTable")
    HotSideTableKind::MemArgTable => logger.write_string("MemArgTable")
    HotSideTableKind::BranchTableTable =>
      logger.write_string("BranchTableTable")
    HotSideTableKind::CatchInfoTable => logger.write_string("CatchInfoTable")
    HotSideTableKind::CallSigTable => logger.write_string("CallSigTable")
    HotSideTableKind::InstrPayloadTable =>
      logger.write_string("InstrPayloadTable")
  }
}

///|
pub impl Show for HotLiftError with fn output(self, logger) {
  match self {
    HotLiftError::InvalidLabelDepth(raw) => {
      logger.write_string("InvalidLabelDepth(")
      raw.output(logger)
      logger.write_char(')')
    }
    HotLiftError::InvalidFunctionIndex(idx) => {
      logger.write_string("InvalidFunctionIndex(")
      idx.output(logger)
      logger.write_char(')')
    }
    HotLiftError::MissingFunctionBody(idx) => {
      logger.write_string("MissingFunctionBody(")
      idx.output(logger)
      logger.write_char(')')
    }
    HotLiftError::MissingFunctionType(idx) => {
      logger.write_string("MissingFunctionType(")
      idx.output(logger)
      logger.write_char(')')
    }
    HotLiftError::InvalidBodyState(msg) => {
      logger.write_string("InvalidBodyState(")
      logger.write_string(msg)
      logger.write_char(')')
    }
    HotLiftError::TypecheckFailure(value, msg) => {
      logger.write_string("TypecheckFailure(")
      value.output(logger)
      logger.write_string(", ")
      logger.write_string(msg)
      logger.write_char(')')
    }
    HotLiftError::UnsupportedInstruction(instr) => {
      logger.write_string("UnsupportedInstruction(")
      logger.write_string(instr)
      logger.write_char(')')
    }
  }
}

///|
pub impl Show for HotVerifyError with fn output(self, logger) {
  match self {
    HotVerifyError::InvalidBodyResultType(type_id) => {
      logger.write_string("InvalidBodyResultType(")
      type_id.output(logger)
      logger.write_char(')')
    }
    HotVerifyError::MissingTypeKey(type_id, key) => {
      logger.write_string("MissingTypeKey(")
      type_id.output(logger)
      logger.write_string(", ")
      logger.write_string(key)
      logger.write_char(')')
    }
    HotVerifyError::MismatchedTypeKey(type_id, key, mapped) => {
      logger.write_string("MismatchedTypeKey(")
      type_id.output(logger)
      logger.write_string(", ")
      logger.write_string(key)
      logger.write_string(", ")
      mapped.output(logger)
      logger.write_char(')')
    }
    HotVerifyError::InvalidRoot(root_id, node_id) => {
      logger.write_string("InvalidRoot(")
      root_id.output(logger)
      logger.write_string(", ")
      node_id.output(logger)
      logger.write_char(')')
    }
    HotVerifyError::InvalidNodeType(node_id, type_id) => {
      logger.write_string("InvalidNodeType(")
      node_id.output(logger)
      logger.write_string(", ")
      type_id.output(logger)
      logger.write_char(')')
    }
    HotVerifyError::InvalidNodeFlags(node_id, flags, expected_flags) => {
      logger.write_string("InvalidNodeFlags(")
      node_id.output(logger)
      logger.write_string(", ")
      flags.output(logger)
      logger.write_string(", ")
      expected_flags.output(logger)
      logger.write_char(')')
    }
    HotVerifyError::InvalidChildSpan(node_id, expected, actual) => {
      logger.write_string("InvalidChildSpan(")
      node_id.output(logger)
      logger.write_string(", ")
      expected.output(logger)
      logger.write_string(", ")
      actual.output(logger)
      logger.write_char(')')
    }
    HotVerifyError::InvalidChildRef(node_id, slot, child_id) => {
      logger.write_string("InvalidChildRef(")
      node_id.output(logger)
      logger.write_string(", ")
      slot.output(logger)
      logger.write_string(", ")
      child_id.output(logger)
      logger.write_char(')')
    }
    HotVerifyError::InvalidLabelResultType(label_id, type_id) => {
      logger.write_string("InvalidLabelResultType(")
      label_id.output(logger)
      logger.write_string(", ")
      type_id.output(logger)
      logger.write_char(')')
    }
    HotVerifyError::InvalidLabelOwner(label_id, owner) => {
      logger.write_string("InvalidLabelOwner(")
      label_id.output(logger)
      logger.write_string(", ")
      owner.output(logger)
      logger.write_char(')')
    }
    HotVerifyError::InvalidLabelOwnerKind(label_id, kind, op) => {
      logger.write_string("InvalidLabelOwnerKind(")
      label_id.output(logger)
      logger.write_string(", ")
      kind.output(logger)
      logger.write_string(", ")
      op.output(logger)
      logger.write_char(')')
    }
    HotVerifyError::InvalidControlLabel(node_id, label_id) => {
      logger.write_string("InvalidControlLabel(")
      node_id.output(logger)
      logger.write_string(", ")
      label_id.output(logger)
      logger.write_char(')')
    }
    HotVerifyError::InvalidSideTableRef(node_id, kind, table_id) => {
      logger.write_string("InvalidSideTableRef(")
      node_id.output(logger)
      logger.write_string(", ")
      kind.output(logger)
      logger.write_string(", ")
      table_id.output(logger)
      logger.write_char(')')
    }
    HotVerifyError::InvalidControlChildCount(node_id, expected, actual) => {
      logger.write_string("InvalidControlChildCount(")
      node_id.output(logger)
      logger.write_string(", ")
      expected.output(logger)
      logger.write_string(", ")
      actual.output(logger)
      logger.write_char(')')
    }
    HotVerifyError::InvalidControlChild(node_id, slot, child_id) => {
      logger.write_string("InvalidControlChild(")
      node_id.output(logger)
      logger.write_string(", ")
      slot.output(logger)
      logger.write_string(", ")
      child_id.output(logger)
      logger.write_char(')')
    }
    HotVerifyError::InvalidBranchTarget(node_id, label_id) => {
      logger.write_string("InvalidBranchTarget(")
      node_id.output(logger)
      logger.write_string(", ")
      label_id.output(logger)
      logger.write_char(')')
    }
    HotVerifyError::InvalidBranchArity(node_id, label_id, actual, expected) => {
      logger.write_string("InvalidBranchArity(")
      node_id.output(logger)
      logger.write_string(", ")
      label_id.output(logger)
      logger.write_string(", ")
      actual.output(logger)
      logger.write_string(", ")
      expected.output(logger)
      logger.write_char(')')
    }
  }
}

///|
fn bitset_debug_dump(bits : Bitset) -> String {
  let out = StringBuilder::new()
  out.write_string("[")
  let mut first = true
  bitset_for_each_set_bit(bits, fn(bit) {
    if !first {
      out.write_string(", ")
    }
    first = false
    out.write_string(bit.to_string())
  })
  out.write_string("]")
  out.to_string()
}

///|
fn bitset_array_debug_dump(values : Array[Bitset]) -> String {
  let out = StringBuilder::new()
  out.write_string("[")
  let mut first = true
  for value in values {
    if !first {
      out.write_string(", ")
    }
    first = false
    out.write_string(bitset_debug_dump(value))
  }
  out.write_string("]")
  out.to_string()
}

///|
pub impl Show for HotCfg with fn output(self, logger) {
  logger.write_string("HotCfg(")
  logger.write_string("blocks=")
  self.blocks.length().output(logger)
  logger.write_string(", ")
  logger.write_string("node_to_block=")
  self.node_to_block.output(logger)
  logger.write_string(", ")
  logger.write_string("region_roots=")
  self.region_roots.length().output(logger)
  logger.write_string(", ")
  logger.write_string("entry_block=")
  self.entry_block.output(logger)
  logger.write_string(", ")
  logger.write_string("exit_block=")
  self.exit_block.output(logger)
  logger.write_string(", ")
  logger.write_string("exceptional_exit_block=")
  match self.exceptional_exit_block {
    Some(block_id) => block_id.output(logger)
    None => logger.write_string("None")
  }
  logger.write_char(')')
}

///|
pub impl Show for HotCfgOrders with fn output(self, logger) {
  logger.write_string("HotCfgOrders(")
  logger.write_string("preorder=")
  self.preorder.output(logger)
  logger.write_string(", ")
  logger.write_string("postorder=")
  self.postorder.output(logger)
  logger.write_string(", ")
  logger.write_string("reverse_postorder=")
  self.reverse_postorder.output(logger)
  logger.write_string(", ")
  logger.write_string("reverse_postorder_with_exceptions=")
  self.reverse_postorder_with_exceptions.output(logger)
  logger.write_string(", ")
  logger.write_string("reverse_exit_postorder=")
  self.reverse_exit_postorder.output(logger)
  logger.write_string(", ")
  logger.write_string("reverse_exit_postorder_with_exceptions=")
  self.reverse_exit_postorder_with_exceptions.output(logger)
  logger.write_string(", ")
  logger.write_string("worklist_seed=")
  self.worklist_seed.output(logger)
  logger.write_char(')')
}

///|
pub impl Show for HotDominators with fn output(self, logger) {
  logger.write_string("HotDominators(")
  logger.write_string("entry_block=")
  self.entry_block.output(logger)
  logger.write_string(", ")
  logger.write_string("reachable=")
  logger.write_string(bitset_debug_dump(self.reachable))
  logger.write_string(", ")
  logger.write_string("idoms=")
  self.idoms.output(logger)
  logger.write_string(", ")
  logger.write_string("children=")
  self.children.output(logger)
  logger.write_string(", ")
  logger.write_string("frontiers=")
  self.frontiers.output(logger)
  logger.write_string(", ")
  logger.write_string("dom_preorder=")
  self.dom_preorder.output(logger)
  logger.write_string(", ")
  logger.write_string("dom_postorder=")
  self.dom_postorder.output(logger)
  logger.write_char(')')
}

///|
pub impl Show for HotPostDominators with fn output(self, logger) {
  logger.write_string("HotPostDominators(")
  logger.write_string("roots=")
  self.roots.output(logger)
  logger.write_string(", ")
  logger.write_string("reachable=")
  logger.write_string(bitset_debug_dump(self.reachable))
  logger.write_string(", ")
  logger.write_string("postdom_sets=")
  logger.write_string(bitset_array_debug_dump(self.postdom_sets))
  logger.write_string(", ")
  logger.write_string("ipdoms=")
  self.ipdoms.output(logger)
  logger.write_string(", ")
  logger.write_string("children=")
  self.children.output(logger)
  logger.write_string(", ")
  logger.write_string("frontiers=")
  self.frontiers.output(logger)
  logger.write_char(')')
}

///|
pub impl Show for HotEffectsSummary with fn output(self, logger) {
  logger.write_string("HotEffectsSummary(")
  logger.write_string("node_masks=")
  self.node_masks.output(logger)
  logger.write_string(", ")
  logger.write_string("block_masks=")
  self.block_masks.output(logger)
  logger.write_string(", ")
  logger.write_string("root_region_mask=")
  self.root_region_mask.output(logger)
  logger.write_char(')')
}

///|
pub impl Show for HotLiveness with fn output(self, logger) {
  logger.write_string("HotLiveness(")
  logger.write_string("include_exceptional_edges=")
  self.include_exceptional_edges.output(logger)
  logger.write_string(", ")
  logger.write_string("live_in_sets=")
  logger.write_string(bitset_array_debug_dump(self.live_in_sets))
  logger.write_string(", ")
  logger.write_string("live_out_sets=")
  logger.write_string(bitset_array_debug_dump(self.live_out_sets))
  logger.write_char(')')
}

///|
pub impl Show for HotLoopInfo with fn output(self, logger) {
  logger.write_string("HotLoopInfo(")
  logger.write_string("loops=")
  self.loops.length().output(logger)
  logger.write_string(", ")
  logger.write_string("block_to_loop=")
  self.block_to_loop.output(logger)
  logger.write_string(", ")
  logger.write_string("block_depth=")
  self.block_depth.output(logger)
  logger.write_char(')')
}

///|
pub impl[T] Show for HotCacheEntry[T] with fn output(self, logger) {
  logger.write_string("HotCacheEntry(")
  self.built_at_revision.output(logger)
  logger.write_string(")")
}
